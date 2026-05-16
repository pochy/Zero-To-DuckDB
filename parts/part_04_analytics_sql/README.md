# Part 4: 分析SQLを極める

## このPartでできるようになること

JOIN、集計、ウィンドウ関数、PIVOT/UNPIVOTを使い、商品データを分析できるようになります。

このPartの目的は、SQL文法を増やすことではありません。分析SQLを書く前に「どの粒度の表を読んでいるか」「重複を含むか」「NULLをどう扱うか」「分析結果をどこまで正本として扱うか」を判断できるようになることです。

Part 3では、rawデータをstagingへ正規化し、品質チェックへつなげました。Part 4では、そのstagingデータを使って、分析に耐えるSQLの考え方を学びます。

## このPartの設計思想

分析SQLの思想は、「数字を出す」ことではなく、「数字の意味を定義する」ことです。

同じ `count(*)` でも、rawの行数、stagingの候補数、重複排除後の商品数、正常出力対象の商品数では意味が違います。分析SQLで最も危険なのは、正しく実行されたSQLから、意味の曖昧な数字が出ることです。

このPartでは、JOIN、集計、ウィンドウ関数、PIVOTを、文法としてではなく、粒度と定義を固定する道具として扱います。

## なぜこの考え方が必要なのか

実務で使われる数字は、誰かの判断に使われます。カテゴリ別商品数、平均価格、品質エラー件数、メーカー別分布。これらは会議、レポート、アプリ、MLの入力になります。

もし数字の定義が曖昧なら、後続の判断も曖昧になります。分析SQLは、データを読む処理であると同時に、組織内で「この数字は何を意味するか」を固定する行為です。

## 初心者が誤解しやすいこと

初心者は、SQLの結果が表として出ると、それをそのまま事実として扱いがちです。しかし、集計元の表、JOINの粒度、NULLの扱い、重複の有無によって結果の意味は変わります。

PIVOTも同じです。見やすい横持ち表はレポートには便利ですが、データモデルの正本にするとカテゴリ追加に弱くなります。見せ方と保存の形を分ける必要があります。

## プロはどう判断するか

プロは、分析SQLを書く前に問いを立てます。この数字はどの粒度か。エラー行を含むか。重複排除後か。NULLを除外してよいか。後続がこの結果に依存してよいか。

martに置く集計は、単なる便利SQLではありません。後続が依存する契約です。だからこそ、分析SQLでは関数よりも、定義、粒度、責務を先に確認します。

## 背景にある設計原則

分析SQLの背景にある原則は、数字は定義なしには意味を持たない、ということです。`count(*)` は正確に行数を返します。しかし、その行が入力候補なのか、重複排除後の商品なのか、正常出力対象なのかを説明できなければ、その数字は意思決定に使えません。

分析SQLは、技術的にはSELECT文ですが、実務的には指標定義です。どの表を元にし、どの条件で除外し、どの粒度で集計するかを決めることで、組織内の共通言語を作ります。

ここでのトレードオフは、見やすさとモデルの安定性です。PIVOTした表は見やすいですが、カテゴリが増えると構造が変わります。縦持ちは少し読みにくいですが、データモデルとして安定します。分析SQLでは、見るための形と保存するための形を分けて考えます。

## まず知るべき言葉

- JOIN: 複数テーブルを結合する
- aggregate: `count`、`sum`、`avg` などの集計
- window function: 行を残したまま順位や累計を計算する
- PIVOT: 行の値を列へ展開する
- UNPIVOT: 列を行へ戻す
- grain: 1行が何を表すかという粒度
- mart: アプリ、BI、レポートが読むための安定した出力層
- dimensional thinking: 商品、カテゴリ、メーカー、日付などの切り口で分析を考えること

## 分析SQLで最初に確認すること

分析SQLで最初に確認するべきなのは、関数でもJOIN句でもありません。表の粒度です。

同じ商品データでも、次の表は意味が違います。

| 表 | 1行の意味 | 主な用途 |
| --- | --- | --- |
| `raw.products` | 入力ファイルから来た商品候補1行 | 入力の痕跡、原因調査 |
| `staging.normalized_products` | 型と表記を整えた商品候補1行 | 品質チェック、変換結果確認 |
| `staging.products_with_category` | カテゴリマスタ照合後の商品候補1行 | 未知カテゴリ検出 |
| `staging.latest_products` | JANコードごとに優先行を選んだ商品1行 | 重複排除後の分析、出力 |
| `mart.quality_report` | 品質チェック1種類につき1行 | 検証結果の契約 |

たとえば「カテゴリ別商品数」を出す場合、`staging.normalized_products` を使うと、重複を含む入力候補の件数になります。`staging.latest_products` を使うと、JANコード単位で重複排除した後の商品数になります。

どちらが正しいかは、分析目的によります。入力ファイルの品質を調べたいなら前者、後続システムへ渡す商品数を知りたいなら後者です。

## 手順1: JOINでマスタ情報を付ける

まずパイプラインを実行し、DuckDBを開きます。

```bash
cd product-data-duckdb
make run
duckdb product_pipeline.duckdb
```

カテゴリマスタ照合後の表を確認します。

```sql
SELECT
  p.jan_code,
  p.product_name,
  p.category_name,
  p.category_id
FROM staging.products_with_category p
ORDER BY p.jan_code
LIMIT 10;
```

カテゴリIDが `NULL` の行は、マスタにないカテゴリです。JOINは、情報を付け足すためだけのものではありません。不一致を見つけるための検査にもなります。

Part 3では `LEFT JOIN` を使う理由を学びました。ここでは、JOIN後の表を分析対象として読む練習をします。

JOIN結果を見るときは、次を確認します。

- JOIN前後で行数が意図せず増えていないか
- JOIN前後で行数が意図せず減っていないか
- `category_id IS NULL` の行が何件あるか
- マスタ側の1カテゴリに複数IDがないか
- JOINキーに空白や大文字小文字の揺れが残っていないか

JOINは便利ですが、間違えると結果を大きく歪めます。特に、マスタ側に重複キーがあると、1商品が複数行に増えることがあります。分析前には行数の変化を確認します。

```sql
SELECT count(*) AS rows
FROM staging.normalized_products;

SELECT count(*) AS rows
FROM staging.products_with_category;
```

この2つの件数が違う場合は、JOINの設計を疑います。今回のカテゴリマスタ照合では、入力側の商品候補を落とさず、増やさず、カテゴリIDだけを付けるのが期待です。

## 手順2: 集計する

カテゴリ別に件数と価格統計を出します。

```sql
SELECT
  category_name,
  count(*) AS product_count,
  avg(price) AS avg_price,
  min(price) AS min_price,
  max(price) AS max_price
FROM staging.normalized_products
GROUP BY category_name
ORDER BY product_count DESC;
```

このSQLの結果を読むとき、まず考えるべきことは「この件数は何の件数か」です。

`staging.normalized_products` は、重複排除前の商品候補です。したがって `product_count` は、厳密には「入力候補行数」です。重複JANコードがある場合、最終出力の商品数とは一致しません。

重複排除後の商品数を見たいなら、次のようにします。

```sql
SELECT
  category_name,
  count(*) AS product_count,
  avg(price) AS avg_price
FROM staging.latest_products
WHERE product_name IS NOT NULL
  AND price IS NOT NULL
  AND price >= 0
  AND category_id IS NOT NULL
GROUP BY category_name
ORDER BY product_count DESC;
```

このSQLは、出力対象に近い条件を入れています。`sql/05_export_parquet.sql` でも同じ考え方で、正常データだけをParquetへ出力します。

分析SQLでは、`count(*)` が簡単に書ける分、意味を取り違えやすくなります。

- `count(*)`: 行数
- `count(jan_code)`: JANコードがNULLでない行数
- `count(DISTINCT jan_code)`: JANコードの種類数
- `count(DISTINCT source_file)`: 入力ファイルの種類数

「商品数」と言いたいなら、どのカウントが商品数なのかを説明できる必要があります。

## NULLと集計

SQLの集計では、NULLの扱いにも注意します。

`avg(price)` は、NULLの価格を平均から除外します。これは便利ですが、価格不正が多いデータでは、平均価格が「正常に数値化できた行だけの平均」になります。

価格不正を含む品質も同時に見たいなら、次のように集計します。

```sql
SELECT
  category_name,
  count(*) AS rows,
  count(price) AS priced_rows,
  count(*) - count(price) AS missing_or_invalid_price_rows,
  avg(price) AS avg_price
FROM staging.normalized_products
GROUP BY category_name
ORDER BY category_name;
```

このSQLでは、平均価格だけでなく、価格が有効だった行数も見ています。分析結果を説明するときは、平均の母数を説明できることが重要です。

## 手順3: ウィンドウ関数で順位を付ける

カテゴリごとに価格が高い商品を上位3件だけ見ます。

```sql
SELECT
  category_name,
  product_name,
  price,
  row_number() OVER (
    PARTITION BY category_name
    ORDER BY price DESC
  ) AS price_rank
FROM staging.normalized_products
WHERE price IS NOT NULL
QUALIFY price_rank <= 3
ORDER BY category_name, price_rank;
```

`GROUP BY` は行をまとめます。ウィンドウ関数は、行を残したまま、グループ内順位や累計を足します。

この違いは重要です。

| 目的 | 使うもの | 結果 |
| --- | --- | --- |
| カテゴリごとの平均価格を1行で出す | `GROUP BY` | カテゴリごとに1行 |
| 商品行を残しつつカテゴリ内順位を付ける | window function | 商品行が残る |

`row_number()` は、重複排除でも使いました。Part 3の `staging.latest_products` では、JANコードごとに優先順位を付けて1件を選んでいます。Part 4では、カテゴリごとの価格順位として使います。

同じ関数でも、設計の意図が違います。

- 重複排除: どの行を正とするか決める
- 分析順位: グループ内でどの行が上位か見る

SQLを読むときは、関数名だけでなく、`PARTITION BY` と `ORDER BY` が何を意味しているかを見ます。

## QUALIFYの考え方

`QUALIFY` は、ウィンドウ関数の結果に対して絞り込むための句です。

通常の `WHERE` は、ウィンドウ関数が計算される前に行を絞ります。一方、`QUALIFY` は `price_rank` のようなウィンドウ関数の結果を使って絞ります。

次の流れで考えると分かりやすいです。

```text
FROMで読む
WHEREで先に絞る
window functionで順位を付ける
QUALIFYで順位を使って絞る
ORDER BYで表示順を整える
```

この順序を意識すると、なぜ `WHERE price_rank <= 3` ではなく `QUALIFY price_rank <= 3` を使うのかが理解できます。

## 手順4: PIVOTで見やすくする

メーカーごと、カテゴリごとの件数を横持ちにします。

```sql
SELECT *
FROM (
  SELECT maker_name, category_name, 1 AS item
  FROM staging.normalized_products
)
PIVOT (
  count(item)
  FOR category_name IN ('food', 'kitchen', 'daily')
);
```

PIVOTは、人間がレポートとして見るには便利です。カテゴリが列になっていると、メーカーごとの分布を横に比較できます。

しかし、PIVOTした表をパイプラインの正本にするのは危険です。

- カテゴリが増えるたびに列が増える
- 未知カテゴリを列にできない
- 後続処理で集計し直しにくい
- BIやアプリ側で列変更への対応が必要になる

基本は、保存する表は縦持ち、表示する時だけ横持ちです。

縦持ちは次のような形です。

```text
maker_name | category_name | product_count
```

横持ちは次のような形です。

```text
maker_name | food | kitchen | daily
```

縦持ちはデータモデルとして安定し、横持ちはレポートとして見やすい。どちらが優れているかではなく、用途が違います。

## 手順5: 分析結果をmartに置く

実務では、頻繁に使う集計を `mart` 層に保存します。

```sql
CREATE OR REPLACE TABLE mart.category_summary AS
SELECT
  category_name,
  count(*) AS product_count,
  avg(price) AS avg_price
FROM staging.latest_products
GROUP BY category_name;
```

martは、アプリやBIが読む層です。rawやstagingよりも意味が安定している必要があります。

ただし、何でもmartに置けばよいわけではありません。martに置くということは、その集計の意味をチームや後続システムに約束することです。

martに置いてよいもの:

- 品質チェック結果
- 最終出力対象の商品テーブル
- よく使うカテゴリ別サマリ
- BIが毎回読む安定した集計

martに置く前に慎重になるもの:

- 一時的な調査SQL
- 仮説検証だけのPIVOT結果
- 粒度が曖昧な集計
- 入力品質に大きく影響される未確定指標

このチュートリアルでは、`mart.quality_report` と `mart.product_errors` を安定した契約として扱っています。カテゴリ別集計をmartに置く場合も、どの表を元にし、どの条件で正常データとみなすかを明記します。

## 分析SQLのチェックリスト

分析SQLを書く前に、次を確認します。

- 1行の粒度は何か
- 重複を含むか、重複排除後か
- NULLは除外されるのか、件数として見るのか
- 不正データを含めるのか、正常データだけを見るのか
- JOINで行数が増減していないか
- 出力は一時的な観察か、martとして契約するものか

このチェックをせずにSQLを書くと、正しそうに見える数字が出ます。しかし、その数字が何を意味しているか説明できません。

分析で価値があるのは、数字そのものではなく、数字の定義を説明できることです。

## 分析依頼をSQLに落とす手順

実務では、「カテゴリ別の商品数を出して」のような曖昧な依頼がよく来ます。この依頼をそのままSQLにすると、後で認識違いが起きます。

まず、依頼を分解します。

```text
カテゴリ別の商品数を出して
```

確認すべきこと:

- 商品数とは、入力行数か、JANコードの種類数か
- 重複排除後の商品だけを見るのか
- 価格不正や未知カテゴリの商品を含めるのか
- カテゴリ不明の商品はどこに入れるのか
- 対象batchはどれか
- 出力は一時分析か、martとして保存するのか

同じ依頼でも、SQLは複数あり得ます。

入力品質を見たい場合:

```sql
SELECT category_name, count(*) AS input_rows
FROM staging.normalized_products
GROUP BY category_name;
```

出力対象の商品数を見たい場合:

```sql
SELECT category_name, count(*) AS exported_product_count
FROM staging.latest_products
WHERE product_name IS NOT NULL
  AND price IS NOT NULL
  AND price >= 0
  AND category_id IS NOT NULL
GROUP BY category_name;
```

JANコード種類数を見たい場合:

```sql
SELECT category_name, count(DISTINCT jan_code) AS distinct_jan_codes
FROM staging.products_with_category
WHERE jan_code IS NOT NULL
GROUP BY category_name;
```

どれも「カテゴリ別の商品数」に見えますが、意味は違います。プロは、SQLを書く前に言葉の定義を合わせます。

## 分析SQLの失敗例

次のSQLは、一見すると問題なさそうです。

```sql
SELECT
  category_name,
  count(*) AS product_count,
  avg(price) AS avg_price
FROM staging.normalized_products
GROUP BY category_name;
```

しかし、レビューでは次の疑問が出ます。

- 重複JANコードを含んでいないか
- `price IS NULL` の行が平均から除外されていることを説明できるか
- `category_name IS NULL` の行はどう表示されるか
- 未知カテゴリを含めるべきか
- 負数価格を平均に含めてよいか

このSQLが悪いわけではありません。問題は、目的が書かれていないことです。

品質調査用なら、次のようにNULLや不正も同時に見ます。

```sql
SELECT
  category_name,
  count(*) AS rows,
  count(price) AS valid_price_rows,
  sum(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS invalid_price_rows,
  sum(CASE WHEN price < 0 THEN 1 ELSE 0 END) AS negative_price_rows,
  avg(price) AS avg_price_for_valid_prices
FROM staging.normalized_products
GROUP BY category_name;
```

出力対象のレポートなら、次のように正常データに絞ります。

```sql
SELECT
  category_name,
  count(*) AS product_count,
  avg(price) AS avg_price
FROM staging.latest_products
WHERE product_name IS NOT NULL
  AND price IS NOT NULL
  AND price >= 0
  AND category_id IS NOT NULL
GROUP BY category_name;
```

目的が変われば、SQLも変わります。

## JOIN分析で起きる件数の爆発

JOINでよくある重大な失敗は、行数が意図せず増えることです。

たとえばカテゴリマスタに同じ `category_name` が2行あるとします。商品側で `food` が10行ある場合、JOIN後に20行へ増える可能性があります。

JOIN前後の件数確認は必須です。

```sql
SELECT count(*) AS before_join
FROM staging.normalized_products;

SELECT count(*) AS after_join
FROM staging.products_with_category;
```

さらに、マスタ側の重複も確認します。

```sql
SELECT
  category_name,
  count(*) AS rows
FROM master.categories
GROUP BY category_name
HAVING count(*) > 1;
```

JOINは情報を増やす操作ですが、行数も増やしてしまうことがあります。分析結果がおかしいとき、集計関数より先にJOINの粒度を疑います。

## mart化する前のレビュー観点

一時分析SQLをmartに昇格する前には、レビューが必要です。

mart化する前に確認すること:

- 元テーブルはどれか
- 粒度は何か
- 正常データだけか、エラー行も含むか
- batchをまたぐか、単一batchか
- NULLの扱いは明確か
- 指標名は誤解を生まないか
- 後続システムが依存してよいか
- 変更時にテストを追加するか

たとえば `product_count` という列名は便利ですが、入力行数なのか、重複排除後の商品数なのか、JANコード種類数なのか分かりません。必要なら `input_row_count`、`latest_product_count`、`distinct_jan_count` のように名前で意味を狭めます。

martは「見やすい表」ではなく「他者が依存してよい契約」です。この意識がないと、便利な集計が後で壊しにくい負債になります。

## よくあるつまずき

`GROUP BY` 後の件数を「商品数」と呼ぶ前に、重複を含むか確認してください。JANコード重複がある場合、raw/stagingの行数と商品数は違います。

`avg(price)` はNULLを除外します。価格不正が多いデータでは、平均価格だけを見ると品質問題を見逃します。

PIVOTした表を正本にすると、カテゴリが増えるたびに列が増えます。データモデルとしては縦持ちを保つ方が扱いやすいです。

## SEMI JOINとANTI JOINを品質調査に使う

`INNER JOIN` や `LEFT JOIN` は、相手テーブルの列を付け足すときによく使います。一方、分析や品質調査では「相手に存在するかどうか」だけを知りたいことがあります。

その時に使いやすいのが `SEMI JOIN` と `ANTI JOIN` です。

`SEMI JOIN` は、相手に一致する行だけを残します。カテゴリマスタに存在する商品候補だけを見たい時に使えます。

`ANTI JOIN` は、相手に一致しない行だけを残します。カテゴリマスタに存在しないカテゴリを検出する時に使えます。

完成実装では、次を実行すると例を作れます。

```bash
cd product-data-duckdb
make run
make advanced
```

`sql/09_advanced_analytics.sql` は、`mart.products_missing_category_anti` と `mart.products_known_category_semi` を作ります。

この2つは、単なる文法練習ではありません。品質調査では、問題のある行を「落とす」のではなく、「検出する」必要があります。`ANTI JOIN` は、マスタに存在しない入力を明示的に取り出すための道具です。

## rank、lag、lead、moving average

ウィンドウ関数は `row_number()` だけではありません。

- `rank()`: 同順位を許して順位を付ける
- `lag()`: 前の行の値を見る
- `lead()`: 次の行の値を見る
- moving average: 直近数行の平均を見る

商品データでは、カテゴリ内の価格順位、前回価格との差分、価格変化の流れを見る時に使えます。

ただし、ウィンドウ関数は便利な反面、並び順を間違えると意味のない結果になります。`ORDER BY updated_at` なのか、`ORDER BY ingest_date` なのか、`ORDER BY price` なのかで、答えの意味が変わります。

## UNPIVOTで横持ちを縦持ちに戻す

Excel由来のデータでは、次のような横持ち表がよくあります。

```text
jan_code | price_202601 | price_202602 | price_202603
```

人間には見やすいですが、SQLで集計したり、月を条件にしたり、月が増えるたびに処理を変えたりする必要が出ます。

`UNPIVOT` を使うと、次の縦持ちへ戻せます。

```text
jan_code | price_month | price
```

完成実装の `mart.monthly_price_long_example` は、この変換例です。横持ちは表示に向き、縦持ちは処理に向きます。プロは、入力やレポートの形と、内部モデルの形を分けて考えます。

## GROUP BY ALLとFILTERで品質集計を読みやすくする

DuckDBでは、`GROUP BY ALL` を使うと、集計関数ではないSELECT列をまとめてグループ化できます。列を追加した時に `GROUP BY` 側の更新漏れを減らせます。

また、集計関数に `FILTER` を付けると、同じグループ内で条件付き件数を複数出せます。

完成実装では、`make friendly-sql` で `mart.category_quality_summary` を作ります。

```sql
count(*) FILTER (WHERE price IS NULL OR price < 0) AS invalid_price_rows
```

これは「カテゴリ別件数」と「カテゴリ別エラー件数」を同じ粒度で見るための書き方です。

## UNNESTでネストした構造を表に戻す

JSONやAPIレスポンスでは、1件の注文の中に複数の商品明細が入ることがあります。表として分析するには、配列を行へ展開する必要があります。

```bash
make nested-json
```

`sql/14_nested_json_unnest.sql` は、注文に含まれる商品明細配列を `UNNEST` で `mart.order_items_unnested` に展開します。

ここでの考え方は、JSONを無理にそのまま分析しないことです。rawでは構造を残し、martでは分析しやすい行と列へ寄せます。

## ASOF JOINで時点が完全一致しないデータを結合する

実務では、イベント日と価格改定日が完全には一致しないことがあります。その時、「イベント日時点で有効だった最新価格」を結合したい場合があります。

```bash
make asof-join
```

`sql/15_asof_join.sql` は、価格確認イベントと価格履歴を `ASOF JOIN` で結合します。

通常の等価JOINは、キーが一致する行だけを結合します。`ASOF JOIN` は、同じJANコードの中で、イベント日以前のもっとも近い価格履歴を拾います。

これは便利ですが、時系列の意味を理解せずに使うと危険です。価格改定の有効開始日、タイムゾーン、同時刻の複数更新、履歴欠損をどう扱うかを決める必要があります。

JOIN後に行数を確認しないと、マスタ側の重複で行が増えていても気づきにくくなります。

## このPartに対応する実装ファイル

- `product-data-duckdb/sql/03_normalize.sql`: `row_number()` による最新商品選択
- `product-data-duckdb/sql/04_quality_checks.sql`: 集計による品質レポート
- `product-data-duckdb/sql/09_advanced_analytics.sql`: `ANTI JOIN`、`SEMI JOIN`、高度なウィンドウ関数、`UNPIVOT`
- `product-data-duckdb/sql/13_friendly_sql.sql`: `GROUP BY ALL` と `FILTER` による品質集計
- `product-data-duckdb/sql/14_nested_json_unnest.sql`: `UNNEST` によるネスト構造の展開
- `product-data-duckdb/sql/15_asof_join.sql`: `ASOF JOIN` による時点結合
- `product-data-duckdb/notebooks/quality_analysis.ipynb`: 集計結果を観察するNotebook

## 次のPartに進む条件

- JOINでマスタ不一致を検出できる
- 集計の粒度を説明できる
- `GROUP BY` とウィンドウ関数の違いを説明できる
- `staging.normalized_products` と `staging.latest_products` の使い分けを説明できる
- martに置いてよい集計と、一時観察に留める集計を分けられる
- `ANTI JOIN` と `SEMI JOIN` を品質調査の道具として説明できる
- 横持ち表を `UNPIVOT` で縦持ちに戻す理由を説明できる
- `GROUP BY ALL`、`FILTER`、`UNNEST`、`ASOF JOIN` を使うべき場面を説明できる

## 公式docsで確認する箇所

- SELECT: https://duckdb.org/docs/current/sql/query_syntax/select.html
- Window Functions: https://duckdb.org/docs/current/sql/functions/window_functions.html
- PIVOT: https://duckdb.org/docs/current/sql/statements/pivot.html
- UNNEST: https://duckdb.org/docs/current/sql/query_syntax/unnest.html
- ASOF JOIN: https://duckdb.org/docs/current/guides/sql_features/asof_join.html
