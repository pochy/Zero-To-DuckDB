# Part 8: パフォーマンスとチューニング

## このPartでできるようになること

DuckDBの実行モデルを理解し、`EXPLAIN`、Parquet設計、メモリ、スレッド、一時領域の観点から遅い処理を調査できるようになります。

このPartの目的は、速くするための設定を暗記することではありません。遅い処理に対して、先に観察し、原因を仮説化し、変更前後を比較する姿勢を身につけることです。

パフォーマンス改善で最も危険なのは、理由を見ずに設定やファイル形式を変えることです。偶然速くなっただけの変更は、データ量や条件が変わるとすぐに壊れます。

## このPartの設計思想

パフォーマンスの思想は、「速くする」ことではなく、「なぜ遅いのかを説明してから変える」ことです。

DuckDBは速いエンジンですが、SQL、ファイル形式、partition、外部ソース、メモリ、CPUの影響を受けます。遅い処理に対して設定を増やす前に、何を読んでいるのか、どの列が必要なのか、どこで絞れるのか、どのファイル構成が合っているのかを見ます。

## なぜこの考え方が必要なのか

性能改善は、偶然うまくいくことがあります。しかし、偶然速くなった変更は、データ量やクエリパターンが変わると通用しません。

`EXPLAIN` と `EXPLAIN ANALYZE` は、単なる調査コマンドではありません。改善の理由を説明するための道具です。変更前後の計画を比較できて初めて、設計としての改善になります。

## 初心者が誤解しやすいこと

初心者は「Parquetなら速い」「partitionすれば速い」「threadsを増やせば速い」と考えがちです。これらは条件付きで正しいだけです。

Parquetは必要列だけ読むときに強い。partitionはよく絞る軸に対して強い。threadsはCPUを使える処理で効く。小さいデータ、全列全行読み、小ファイル過多、外部ネットワーク待ちでは、期待した効果が出ないことがあります。

## プロはどう判断するか

プロは、最初にデータ量とクエリパターンを見ます。何度も読むならParquet化する。特定の日付でよく読むなら日付partitionを検討する。全列を読んでいるなら列を減らす。JOIN前に絞れるなら先に絞る。

設定変更は最後です。メモリやスレッドを増やす前に、読むデータを減らす。これがDuckDBに限らず、分析処理の基本です。

## 背景にある設計原則

パフォーマンス設計の背景にある原則は、計算を増やす前に無駄を減らすことです。速いエンジンを使っても、不要な列、不要な行、不要なファイルを読んでいれば遅くなります。まず読む量を減らす。次にファイル形式やpartitionを見直す。最後にリソース設定を考えます。

Parquet、pushdown、partitionは、すべて「読まなくてよいものを読まない」ための設計です。単に速い形式や高度な機能ではありません。どのクエリで、どの列を、どの条件で読むのかが分からなければ、適切な設計はできません。

ここでのトレードオフは、将来の読み方に合わせてデータを配置することです。partitionを増やせば特定条件では速くなりますが、小ファイル問題が起きます。圧縮を強くすればサイズは減りますが、CPU負荷が増える場合があります。性能設計は、単一の正解ではなく、クエリパターンとの対話です。

## まず知るべき言葉

- columnar: 列単位で読む・処理する方式
- predicate pushdown: 条件に合う範囲だけ読む最適化
- projection pushdown: 必要な列だけ読む最適化
- EXPLAIN: 実行計画を見る命令
- EXPLAIN ANALYZE: 実際に実行して時間も見る命令
- partition pruning: partition情報を使って読む範囲を減らすこと
- small files problem: 小さなファイルが多すぎて遅くなる問題
- materialization: 中間結果や出力をファイル・テーブルとして固定すること

## パフォーマンスを見る前の前提

DuckDBは高速ですが、すべてのSQLが自動的に最速になるわけではありません。

遅いと感じたとき、まず次を確認します。

- どのファイルやテーブルを読んでいるか
- 全列を読んでいないか
- 全行を読んでいないか
- JOIN前に絞れる条件はないか
- CSVではなくParquetにできるか
- partitionが効く形になっているか
- 小さなファイルを増やしすぎていないか
- メモリや一時領域が足りているか

初心者は、すぐ `SET threads` や `SET memory_limit` を変えがちです。しかし、最初に見るべきなのはSQLとデータ設計です。

## 手順1: Parquetを列指向として見る

CSVは行テキストです。Parquetは列指向です。カテゴリ別集計で `category_name` と `price` だけ必要な場合、Parquetなら必要な列だけ読みやすくなります。

```bash
cd product-data-duckdb
make run
duckdb product_pipeline.duckdb
```

```sql
SELECT category_name, avg(price) AS avg_price
FROM read_parquet('output/products.parquet')
GROUP BY category_name;
```

このSQLで必要なのは、主に `category_name` と `price` です。Parquetは列単位でデータを持つため、必要な列だけを読む最適化が効きやすくなります。これをprojection pushdownと呼びます。

CSVの場合、基本的には行テキストを読み、パースしてから列として扱います。小さいファイルでは差が目立たないこともありますが、大きなデータではParquetの利点が出やすくなります。

## projection pushdownとpredicate pushdown

pushdownは、できるだけ読み込み元に近い場所で不要なデータを減らす考え方です。

projection pushdownは、必要な列だけ読むことです。

```sql
SELECT category_name, price
FROM read_parquet('output/products.parquet');
```

このSQLでは、`product_name` や `source_file` は不要です。Parquetでは列単位で読むため、不要な列を読まずに済む可能性があります。

predicate pushdownは、条件に合う範囲だけ読むことです。

```sql
SELECT category_name, price
FROM read_parquet('output/products.parquet')
WHERE category_name = 'food';
```

条件がファイル形式やメタデータにうまく効くと、読むデータ量を減らせます。

ただし、pushdownが常に劇的に効くとは限りません。データ量、ファイル構成、列の統計情報、条件の書き方によって変わります。だからこそ、`EXPLAIN` で観察します。

## 手順2: EXPLAINを見る

```sql
EXPLAIN
SELECT category_name, avg(price) AS avg_price
FROM read_parquet('output/products.parquet')
WHERE category_name = 'food'
GROUP BY category_name;
```

実行計画は、DuckDBがどのように読み、絞り、集計するかを示します。最初は全部理解しなくて構いません。どのファイルを読んでいるか、フィルタがどこにあるかを見ます。

見るポイント:

- 入力が `READ_PARQUET` になっているか
- `category_name = 'food'` のフィルタが見えるか
- 集計がどの段階で行われているか
- 不要なJOINやソートが入っていないか
- 想定より大きな行数を読んでいないか

`EXPLAIN` はSQLを実行せず、計画を見ます。重いSQLをいきなり実行する前に、どのように実行されそうかを確認できます。

## 手順3: EXPLAIN ANALYZEを記録する

完成例にはプロファイル用SQLがあります。

```bash
make profile
sed -n '1,120p' reports/parquet_explain.txt
```

`make profile` は、`sql/06_explain_parquet.sql` を実行し、結果を `reports/parquet_explain.txt` に保存します。

`sql/06_explain_parquet.sql` では、次のようなSQLを分析しています。

```sql
EXPLAIN ANALYZE
SELECT
  category_name,
  count(*) AS product_count,
  avg(price) AS avg_price
FROM read_parquet(
  'output/products_by_category/**/*.parquet',
  hive_partitioning = true
)
WHERE category_name = 'food'
GROUP BY category_name;
```

`EXPLAIN ANALYZE` は、実際にSQLを実行し、時間や実行の詳細を見ます。`EXPLAIN` より重いですが、実測に近い情報が得られます。

実務では、遅いSQLを直す前に実行計画を保存します。変更前後で比較できない最適化は、偶然速くなっただけかもしれません。

## EXPLAINとEXPLAIN ANALYZEの違い

| 命令 | 何を見るか | 使う場面 |
| --- | --- | --- |
| `EXPLAIN` | 実行予定の計画 | 重いSQLを実行する前、構造を確認する |
| `EXPLAIN ANALYZE` | 実際に実行した計画と時間 | 改善前後の比較、ボトルネック調査 |

最初は `EXPLAIN` で構造を見ます。実際の時間を知りたい場合に `EXPLAIN ANALYZE` を使います。

注意点として、`EXPLAIN ANALYZE` は実際に実行します。更新を含むSQLや重い処理では、実行対象を理解してから使います。

## 手順4: partitioned datasetを読む

```sql
SELECT category_name, count(*) AS rows
FROM read_parquet('output/products_by_category/**/*.parquet', hive_partitioning = true)
GROUP BY category_name;
```

partitionは、必要な範囲だけ読むためのディレクトリ設計です。

このチュートリアルでは、`sql/05_export_parquet.sql` で次の2つのpartitioned datasetを出力しています。

```text
output/products_by_category/
output/products_by_ingest_date/
```

カテゴリでよく絞るなら、`category_name` でpartitionする価値があります。取り込み日でよく再処理や比較をするなら、`ingest_date` を含める価値があります。

ただし、partitionは増やせば増やすほどよいわけではありません。

## partition設計の考え方

partitionは、よく絞る軸に対して効きます。

良い候補:

- 日付
- カテゴリ
- 地域
- テナント
- 大きなデータ量を自然に分ける業務軸

慎重に扱う候補:

- 値の種類が多すぎる列
- ほとんど絞り込みに使わない列
- 頻繁に値が変わる列
- 1partitionあたりの行数が少なすぎる列

たとえば `maker_name` でpartitionすると、メーカー数が少なく、メーカー別に読むことが多いなら有効です。しかし、メーカー数が多く、各ファイルが小さくなりすぎるなら、小ファイル問題が起きます。

partition設計では、次の問いを使います。

- その列でWHEREすることが多いか
- 1partitionあたり十分なデータ量があるか
- partition数が増えすぎないか
- ディレクトリ構造を人間が理解できるか
- 後続システムもそのpartitionを活用できるか

## small files problem

Parquetは分析に強い形式ですが、小さなParquetファイルが大量にあると遅くなることがあります。

理由は、ファイルを開く、メタデータを読む、一覧する、といった固定コストが増えるからです。データ本体が小さくても、ファイル数が多いだけで遅くなることがあります。

よくある失敗:

- 日付、カテゴリ、メーカー、店舗などで細かくpartitionしすぎる
- 1ファイルあたり数行しか入っていない
- バッチごとに小さなファイルを追記し続ける
- S3上で大量の小ファイルを毎回listする

小ファイル問題を避けるには、partition軸を絞り、1ファイルあたりのサイズや行数を意識します。

このチュートリアルのデータは小さいため、性能差そのものよりも設計思想を学ぶ目的でpartitionを扱っています。

## 手順5: メモリとスレッドを考える

DuckDBはローカルプロセス内で動くため、マシンのメモリとCPUに影響されます。

```sql
SET memory_limit = '4GB';
SET threads = 4;
```

設定は万能ではありません。まずSQL、読み込み列、フィルタ、ファイル形式、partition設計を見直します。

メモリやスレッド設定を考えるのは、次のような場合です。

- 大きなJOINやソートでメモリ不足になる
- ローカルPCの他プロセスに影響を与えたくない
- 並列度を制御したい
- 一時領域のI/Oが増えている

しかし、全列全行を読んでいるSQLをそのままにして、メモリだけ増やすのは根本解決ではありません。まず読むデータを減らします。

## チューニングの順番

遅いSQLに出会ったら、次の順番で見ます。

1. SQLの目的と期待行数を確認する
2. `EXPLAIN` で実行計画を見る
3. 読む列を減らせるか確認する
4. WHERE条件を早く効かせられるか確認する
5. CSVではなくParquetにできるか確認する
6. partitionが効く設計か確認する
7. JOIN前に入力を絞れるか確認する
8. `EXPLAIN ANALYZE` で実測する
9. 必要ならメモリ、スレッド、一時領域を調整する

この順番を守ると、設定変更に飛びつかず、データ量を減らす方向から考えられます。

## Parquet出力設計

完成実装の `sql/05_export_parquet.sql` では、正常データだけをParquetへ出力しています。

```sql
COPY (
  SELECT
    jan_code,
    product_name,
    price,
    category_id,
    category_name,
    maker_name,
    updated_at,
    source_file,
    batch_id,
    ingest_date
  FROM staging.latest_products
  WHERE product_name IS NOT NULL
    AND price IS NOT NULL
    AND price >= 0
    AND category_id IS NOT NULL
)
TO 'output/products.parquet'
(FORMAT parquet, COMPRESSION zstd);
```

この出力は、単なる保存ではありません。品質チェックを通した後続用データセットを作っています。

出力設計で見るべき点:

- 重複排除後の `staging.latest_products` を使っている
- 商品名、価格、カテゴリIDの不正を除外している
- `source_file`、`batch_id`、`ingest_date` を残している
- Parquetの圧縮に `zstd` を使っている
- 単一ファイルとpartitioned datasetの両方を出している

`source_file` や `batch_id` は、出力後のトレーサビリティに役立ちます。正常データだけを出しても、どこから来たかを完全に捨てるべきではありません。

## 遅いSQLを調査する実務手順

パフォーマンス問題は、感覚で直すと危険です。実務では、次のように調査します。

```text
1. 遅いSQLを特定する
2. 入力データ量を確認する
3. 実行計画を見る
4. 読んでいる列と行を確認する
5. JOINやGROUP BYの粒度を確認する
6. ファイル形式とpartitionを確認する
7. 変更を1つだけ入れる
8. 変更前後を比較する
```

悪いチューニング:

```text
何となくParquetにした
何となくthreadsを増やした
何となくpartitionを増やした
速くなった気がする
```

良いチューニング:

```text
EXPLAIN ANALYZEを保存した
全列読みが原因だと分かった
必要列だけにした
変更前後の実行計画を比較した
```

チューニングでは、変更内容よりも、なぜその変更をしたかが重要です。

## データ量が小さい時の注意

このチュートリアルのサンプルデータは小さいです。そのため、Parquet、partition、pushdownの性能差は大きく見えないことがあります。

小さいデータでは、次のようなことが起きます。

- CSVでも十分速い
- Parquetの利点が見えにくい
- partitionの固定コストの方が目立つ
- EXPLAIN ANALYZEの時間差が小さい
- OSキャッシュの影響が大きい

ここで学ぶべきなのは、ベンチマーク結果そのものではありません。データが大きくなったときに効く設計の考え方です。

たとえば、10行のデータではpartitionは不要です。しかし、日次で数千万行のデータを扱い、特定日のみ読むなら、日付partitionは意味を持ちます。

学習用データで性能差が小さくても、設計判断の練習として見ることが重要です。

## CSVからParquetへ変える判断

Parquetは便利ですが、すべてのCSVをすぐParquetにすべきとは限りません。

CSVのままでよい場面:

- データが小さい
- 人間が直接編集・確認する
- 受け渡し形式としてCSVが指定されている
- 一度しか読まない

Parquetにする価値がある場面:

- 何度も読む
- 列数が多い
- 必要列だけ読むことが多い
- データ量が大きい
- 型情報を安定させたい
- S3やHTTPで分析用に配布したい

このチュートリアルでは、入力はCSV/Excel/JSONでも、出力はParquetにしています。入力元の都合と、後続分析の都合を分けているからです。

## partition設計の失敗例

partition設計では、よく次の失敗が起きます。

失敗例1: 高カーディナリティ列でpartitionする

```text
product_id=...
jan_code=...
```

商品IDやJANコードのように値の種類が非常に多い列でpartitionすると、小さなファイルが大量にできます。これは分析に向きません。

失敗例2: 使わない列でpartitionする

```text
maker_name=...
```

メーカーで絞る分析がほとんどないなら、maker partitionはあまり役に立ちません。partitionは、WHERE条件でよく使う列に対して意味があります。

失敗例3: partitionを深くしすぎる

```text
ingest_date=.../category_name=.../maker_name=.../source_file=...
```

ディレクトリが深くなりすぎ、ファイルが細かくなりすぎると、読み取り前の一覧やメタデータ処理が重くなります。

良いpartition設計は、よく使う絞り込み軸を少数選ぶことです。

## パフォーマンスレビューの観点

パフォーマンス改善案をレビューするときは、次を確認します。

- 変更前の実行計画を保存しているか
- 遅い理由の仮説があるか
- 変更を1つずつ試しているか
- 読む列を減らせるか
- 読む行を減らせるか
- JOIN前に絞れるか
- CSVをParquetへ変える理由があるか
- partitionの軸はクエリパターンに合っているか
- 小ファイル問題を起こしていないか
- メモリやスレッド設定に逃げていないか

「速くなった」だけではレビューとして弱いです。「なぜ速くなったか」「別のデータ量でも効くか」を説明します。

## 本番運用で見る追加指標

本番運用では、SQL単体の時間だけでなく、周辺の指標も見ます。

- 入力ファイル数
- 入力行数
- 出力行数
- エラー行数
- Parquetファイル数
- 1ファイルあたりのサイズ
- 実行時間
- メモリ使用量
- 外部ソースの応答時間
- S3やHTTPの読み取り失敗回数

これらを記録すると、突然遅くなった原因を追いやすくなります。

たとえば、実行時間が伸びたとき、入力行数は同じなのにParquetファイル数だけ増えていれば、小ファイル問題を疑えます。入力行数が増えていれば、単純にデータ量増加かもしれません。外部ソース応答が遅ければ、DuckDBではなくネットワークが原因かもしれません。

## よくあるつまずき

「Parquetにすれば必ず速い」と考えるのは危険です。列選択や条件絞り込みが効く処理では強いですが、小さいデータや全列全行を読む処理では差が小さいこともあります。

partitionを日付、カテゴリ、メーカーなどで増やしすぎると、小ファイル問題が出ます。よく絞る軸だけを選びます。

`EXPLAIN ANALYZE` を見ずにチューニングすると、改善理由が分かりません。変更前後の計画や時間を残します。

メモリやスレッド設定を最初に変えると、SQLやデータ設計の問題を見逃します。まず読む列、読む行、ファイル形式、partitionを見直します。

## blocking operatorとspillを観察する

DuckDBは列指向とベクトル化実行で効率よく処理しますが、すべての処理が行を流しながら完了するわけではありません。

たとえば、次の処理は一定量のデータを保持する必要があります。

- `GROUP BY`
- `ORDER BY`
- JOIN
- window function

このような処理はblocking operatorになりやすく、入力全体やグループ単位の情報を待つ必要があります。データが大きく、メモリに収まらない場合は、一時領域へspillして処理することがあります。

完成実装では、次で小さな性能実験を実行できます。

```bash
cd product-data-duckdb
make run
make perf-lab
```

`make perf-lab` は `sql/11_performance_lab.sql` を実行し、`reports/perf_lab.txt` に `EXPLAIN ANALYZE` を保存します。

このSQLでは、次の設定も明示しています。

```sql
SET preserve_insertion_order = false;
SET threads = 4;
SET memory_limit = '1GB';
```

`preserve_insertion_order = false` は、入力順序を厳密に保つ必要がない分析処理で、DuckDBがより自由に最適化しやすくするための設定です。ただし、順序に意味がある処理では使い方に注意します。

重要なのは、設定を暗記することではありません。まず `EXPLAIN ANALYZE` を残し、遅さの原因がSQL、データレイアウト、メモリ、ファイル数、ネットワークのどこにあるかを分けて考えます。

## このPartに対応する実装ファイル

- `product-data-duckdb/sql/05_export_parquet.sql`: Parquetとpartitioned datasetの出力
- `product-data-duckdb/sql/06_explain_parquet.sql`: `EXPLAIN ANALYZE` の記録
- `product-data-duckdb/sql/11_performance_lab.sql`: blocking operator、window処理、設定変更を観察する性能実験
- `product-data-duckdb/reports/parquet_explain.txt`: 実行後に生成されるプロファイル結果
- `product-data-duckdb/reports/perf_lab.txt`: `make perf-lab` の実行結果

## 次のPartに進む条件

- `EXPLAIN` と `EXPLAIN ANALYZE` の違いを説明できる
- Parquetが列指向である利点を説明できる
- projection pushdownとpredicate pushdownの考え方を説明できる
- partitionを増やしすぎる危険を説明できる
- `memory_limit`、`threads`、`preserve_insertion_order` を測定なしに変えない理由を説明できる
- 遅いSQLに対して、先に実行計画を見てから改善案を出せる

## 公式docsで確認する箇所

- Performance Guide: https://duckdb.org/docs/current/guides/performance/overview.html
- EXPLAIN: https://duckdb.org/docs/current/guides/meta/explain.html
- Configuration: https://duckdb.org/docs/current/configuration/overview.html
- Parquet: https://duckdb.org/docs/current/data/parquet/overview.html
