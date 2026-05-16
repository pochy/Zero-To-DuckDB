# Part 7: 外部DB・クラウドストレージ連携

## このPartでできるようになること

SQLite、PostgreSQL、HTTP上のParquet、S3互換ストレージ上のParquetをDuckDBから読む方法を理解します。

このPartの目的は、外部ソースへ接続するコマンドを覚えることではありません。DuckDBを外部DBの代替としてではなく、読み取り、検証、変換のエンジンとして配置する判断を学ぶことです。

Part 6までで、DuckDB内の品質チェック結果をアプリ境界へ渡す方法を見ました。Part 7では、DuckDBが外部の正本データやクラウド上のファイルをどう読むかを扱います。

## このPartの設計思想

外部ソース連携の思想は、「つながるから読む」ではなく、「正本性、再現性、権限境界を意識して読む」です。

DuckDBはSQLite、PostgreSQL、HTTP、S3を読めます。しかし、外部ソースは自分のプロセス外にあります。内容が変わる、認証が切れる、ネットワークが落ちる、権限が足りない、ファイルが差し替わる。これらを前提に設計します。

## なぜこの考え方が必要なのか

外部ソースを直接読むと、最新データに触れられます。一方で、再現性は下がります。昨日と今日でPostgreSQLのマスタが変われば、同じ入力ファイルでも品質チェック結果が変わる可能性があります。

だからこそ、直接読むのか、スナップショットを作るのか、batchや取得時刻を残すのかを判断します。外部連携は接続方法の問題ではなく、データの正本性と説明責任の問題です。

## 初心者が誤解しやすいこと

初心者は、`ATTACH` できた、S3を読めた、HTTPでParquetを読めた、という接続成功をゴールにしがちです。しかし実務では、その接続をいつ使うべきか、読み取り専用か、どの権限か、失敗時に再現できるかが重要です。

また、外部DBを読めると、DuckDBから更新したくなることがあります。品質チェックで問題を見つけることと、正本DBを更新することは別の責務です。

## プロはどう判断するか

プロは、まず正本がどこかを確認します。PostgreSQLが正本なら、DuckDBは読み取りと検証に徹します。S3が配布成果物の置き場なら、DuckDBは必要な範囲を読み、分析します。

直接読むかmaterializeするかは、最新性と再現性のトレードオフで決めます。小さなマスタは直接読んでもよい。監査が必要なレポートはスナップショットを残す。大きな外部データは必要列と期間で絞る。この判断が外部連携の本質です。

## 背景にある設計原則

外部ソース連携の背景にある原則は、境界を尊重することです。PostgreSQLにはPostgreSQLの責務があり、S3にはS3の責務があります。DuckDBがそれらを読めるからといって、それらの正本性、権限管理、監査、更新責任までDuckDBへ移すわけではありません。

外部ソースは、常に変化と失敗の可能性を持ちます。接続できない、認証が切れる、ファイルが差し替わる、マスタが更新される。だから、DuckDB側では「いつ何を読んだのか」を説明できるようにします。

ここでのトレードオフは、最新性と再現性です。直接読むと最新に近づきますが、同じ結果を後で再現しにくくなります。スナップショットを作ると再現性は上がりますが、最新性は設計が必要になります。どちらを優先するかは、用途で決めます。

## まず知るべき言葉

- ATTACH: 外部DBをDuckDBへ接続する
- extension: DuckDBに機能を追加する仕組み
- httpfs: HTTP/S3上のファイルを読む拡張
- read-only: 読み取り専用接続
- object storage: S3やMinIOのようなオブジェクトストレージ
- materialize: 外部ソースをローカルテーブルやParquetとして保存すること
- source of truth: 正本となるデータの置き場所
- data locality: データが処理場所に近いかどうか

## 外部ソース連携の基本方針

DuckDBは外部DBやクラウドストレージを読めます。しかし、何でも直接読めばよいわけではありません。

基本方針は次の通りです。

```text
正本データは正本システムに置く
DuckDBは必要な範囲を読み、検証・変換する
後続処理にはParquetやJSONなどの成果物を渡す
```

たとえば、カテゴリマスタの正本がPostgreSQLにあるなら、DuckDBへ恒久的に移す必要はありません。DuckDBは読み取り専用で参照し、入力ファイルと照合します。

一方で、毎回外部DBから大量の履歴データを読むと遅くなったり、外部DBへ負荷をかけたりします。その場合は、必要な範囲をParquetへ落としてからDuckDBで分析する方がよいことがあります。

## 手順1: SQLiteマスタを読む

完成例の標準ルートではSQLiteのカテゴリマスタを読みます。

```sql
INSTALL sqlite;
LOAD sqlite;

ATTACH 'data/master/master.sqlite' AS master_db (TYPE sqlite, READ_ONLY);

CREATE OR REPLACE TABLE master.categories AS
SELECT
  category_id::INTEGER AS category_id,
  lower(trim(category_name)) AS category_name
FROM master_db.categories;
```

`READ_ONLY` を付けることで、DuckDBからマスタDBを書き換えない意図を明示します。

SQLiteマスタを読む理由は、入力ファイルだけではカテゴリの正しさを判断できないからです。カテゴリ名が `food` と書かれていても、それが許可されたカテゴリかどうかはマスタと照合しなければ分かりません。

このSQLでは、外部SQLiteを直接使い続けるのではなく、DuckDB内の `master.categories` として取り込んでいます。これにより、後続のJOINや品質チェックをDuckDB内で安定して実行できます。

## ATTACHとCOPY的な取り込みの違い

外部DBを読むときには、大きく2つの考え方があります。

| 方法 | 説明 | 向いている場面 |
| --- | --- | --- |
| 外部DBを直接参照する | `ATTACH` したDBをそのまま読む | 小さなマスタ、最新状態を見たい |
| DuckDB内へ取り込む | `CREATE TABLE AS SELECT` でコピーする | 後続処理で何度も使う、再現性を高めたい |

このチュートリアルでは、SQLiteをATTACHして読み、その結果を `master.categories` に取り込んでいます。これにより、外部DBの形式を後続処理から隠せます。

後続のSQLは、マスタがSQLite由来かPostgreSQL由来かを気にしなくてよくなります。これが境界設計です。

## 手順2: PostgreSQLマスタを読む

Dockerが使える環境では、PostgreSQL版を実行できます。

```bash
cd product-data-duckdb
make postgres-run
make quality
make test
```

使っている接続は次の形です。

```sql
ATTACH 'dbname=duckdb_tutorial user=duckdb password=duckdb host=localhost port=55433'
AS master_pg (TYPE postgres, READ_ONLY);
```

PostgreSQLは業務マスタの正本として使い、DuckDBは分析・検証用に読みます。

ここで重要なのは、PostgreSQLをDuckDBで置き換えているわけではないことです。PostgreSQLは、業務アプリが更新する正本DBとして残ります。DuckDBは、そのマスタを読み、ファイル入力と照合し、品質チェックに使います。

この分担にすると、次のような責務になります。

| コンポーネント | 責務 |
| --- | --- |
| PostgreSQL | 業務マスタの正本、更新、権限管理 |
| DuckDB | マスタ参照、ファイル検証、変換、分析 |
| Parquet | 後続分析や配布用の成果物 |

## READ_ONLYを使う理由

外部DBへ接続できると、ついDuckDBから更新もしたくなります。しかし、分析パイプラインから正本DBを書き換える設計は慎重に考える必要があります。

`READ_ONLY` を使う理由は次の通りです。

- 分析処理が正本データを壊すのを防ぐ
- 権限境界を明確にする
- パイプラインを再実行しても外部DBの状態を変えない
- 障害時の影響範囲を小さくする
- 「読むだけ」という運用上の約束をコードに残す

品質チェックの結果、マスタに追加すべきカテゴリが見つかることはあります。しかし、その追加は別の承認フローや業務アプリで行う方が安全です。

## 手順3: HTTP上のParquetを読む

別ターミナルでHTTPサーバーを起動します。

```bash
make serve-output
```

別ターミナルで読みます。

```bash
make http-read
```

SQLでは `httpfs` 拡張を使います。

```sql
INSTALL httpfs;
LOAD httpfs;
```

完成実装では、HTTP上のParquetファイルを明示的なURLリストとして読んでいます。

```sql
CREATE OR REPLACE VIEW mart.http_products AS
SELECT *
FROM read_parquet([
  'http://127.0.0.1:8000/products_by_category/category_name=beauty/data_0.parquet',
  'http://127.0.0.1:8000/products_by_category/category_name=electronics/data_0.parquet',
  'http://127.0.0.1:8000/products_by_category/category_name=food/data_0.parquet',
  'http://127.0.0.1:8000/products_by_category/category_name=stationery/data_0.parquet'
], hive_partitioning = true);
```

HTTP上のParquetを直接読めると、ファイルを事前にダウンロードしなくても分析できます。これは便利ですが、ネットワーク、認証、可用性、再現性の影響を受けます。

ローカルファイルと違い、HTTPソースは次の理由で不安定になりやすいです。

- サーバーが落ちている
- URLが変わる
- ネットワークが遅い
- ファイルが更新される
- 認証が切れる

したがって、本番パイプラインでは「直接読むか、一度ローカルやオブジェクトストレージへ固定するか」を判断します。

## 手順4: S3互換ストレージを読む

MinIOを使ったローカルS3互換ストレージを読みます。

```bash
make s3-read
```

このターゲットはMinIOを起動し、Parquet datasetをバケットへ同期してからDuckDBで読みます。

S3互換ストレージを読むSQLでは、`httpfs` に加えてS3設定を行います。

```sql
SET s3_region = 'us-east-1';
SET s3_endpoint = '127.0.0.1:9000';
SET s3_access_key_id = 'minioadmin';
SET s3_secret_access_key = 'minioadmin';
SET s3_url_style = 'path';
SET s3_use_ssl = false;
```

このチュートリアルではローカルMinIOを使うため、認証情報はサンプルです。本番S3では、資格情報の管理、権限、暗号化、ネットワーク、監査ログを考える必要があります。

重要なのは、DuckDBからS3を読めることではなく、S3上のParquet datasetを分析可能なデータ成果物として扱えることです。

## hive_partitioningの意味

`products_by_category/category_name=food/data_0.parquet` のようなディレクトリ構造では、パスにカテゴリ情報が含まれています。

`hive_partitioning = true` を付けると、DuckDBは `category_name=food` のようなディレクトリ名を列として解釈できます。

これにより、ファイル内にカテゴリ列がなくても、パーティション情報をSQLの列として扱えます。

このチュートリアルでは、次の2種類のpartitioned datasetを出力しています。

- `output/products_by_category`
- `output/products_by_ingest_date`

カテゴリ別に読む場合、前者は扱いやすいです。日付で取り込み単位を追いたい場合、後者が役立ちます。

## 手順5: 外部ソースを読む時の設計

外部DBやS3を直接読むと便利ですが、何でも毎回直接読めばよいわけではありません。

判断の目安:

| 外部ソース | 推奨方針 |
| --- | --- |
| 小さいマスタ | 毎回直接読んでもよい |
| 大きいトランザクション | 必要列と期間で絞る |
| 遅い外部ソース | 一度ローカルParquetに落とす |
| 監査が必要なデータ | `batch_id` と取得時刻を残す |
| よく再利用する分析対象 | Parquet datasetとして保存する |

直接読む利点は、最新データを見やすいことです。欠点は、外部ソースの状態に実行結果が左右されることです。

ローカルやS3にmaterializeする利点は、再現性と性能です。欠点は、最新性をどう保つかを設計する必要があることです。

実務では、次の問いで判断します。

- 最新性が最優先か
- 再実行時に同じ結果が必要か
- 外部DBへ負荷をかけてよいか
- 読むデータ量はどれくらいか
- 権限や監査の要件はあるか

## 外部ソースごとの失敗モード

外部ソース連携では、SQLが正しくても失敗することがあります。ファイルやDBが自分のプロセス外にあるためです。

SQLiteで起きやすい問題:

- ファイルパスが違う
- 生成前のSQLiteを読もうとする
- スキーマが想定と違う
- 読み取り権限がない

PostgreSQLで起きやすい問題:

- Dockerコンテナが起動していない
- ポートが違う
- 認証情報が違う
- ネットワーク到達できない
- マスタテーブルの内容が変わっている

HTTPで起きやすい問題:

- サーバーが起動していない
- URLが変わった
- ファイル一覧が取れない
- 部分的にファイルが欠けている
- レスポンスが遅い

S3互換ストレージで起きやすい問題:

- endpoint設定が違う
- path style / virtual hosted style が合わない
- 認証情報が違う
- bucketがない
- object pathが違う
- 権限はあるがlistできない

外部ソースを扱うSQLでは、DuckDBの文法だけでなく、接続先の運用状態も確認します。

## 直接読むか、スナップショットを作るか

外部ソースを直接読む設計には、最新性があります。一方で、再現性は下がります。

たとえば、PostgreSQLのカテゴリマスタを毎回直接読むと、最新のカテゴリで検証できます。しかし、昨日実行した品質チェックを今日再現しようとしたとき、マスタが変わっていれば結果も変わる可能性があります。

再現性を重視するなら、スナップショットを作ります。

```text
外部DB
  ↓
DuckDBで読み取り
  ↓
batch_id付きでローカルテーブル/Parquetへ保存
  ↓
以後の処理はスナップショットを読む
```

最新性を重視するか、再現性を重視するかは用途によります。

| 用途 | 優先 | 方針 |
| --- | --- | --- |
| 管理画面の即時確認 | 最新性 | 直接読む |
| 月次レポート | 再現性 | スナップショット化 |
| 品質チェックの監査 | 再現性 | batchと取得時刻を残す |
| 小さいカテゴリマスタ | 両立しやすい | 直接読みつつ取り込み結果を残す |

このチュートリアルでは、マスタをDuckDB内の `master.categories` へ取り込むことで、後続処理から外部ソースの違いを隠しています。

## 資格情報をどう扱うか

学習用のMinIOでは、SQLに次のような認証情報を書いています。

```sql
SET s3_access_key_id = 'minioadmin';
SET s3_secret_access_key = 'minioadmin';
```

これはローカル学習用の簡略化です。本番では、SQLファイルに秘密情報を直書きしません。

本番で検討する方法:

- 環境変数から注入する
- シークレット管理サービスを使う
- IAMロールなどの実行環境権限を使う
- 読み取り専用の限定権限を使う
- ログに秘密情報が出ないようにする

資格情報は、SQLの正しさとは別の運用責任です。DuckDBからS3を読めることと、安全に読めることは違います。

## 外部ソース連携レビューの観点

外部ソース連携をレビューするときは、次を確認します。

- 正本データはどこか
- DuckDBは読み取り専用か
- 直接読む理由があるか
- スナップショットが必要か
- batch_idや取得時刻を残しているか
- 外部DBへ過剰な負荷をかけないか
- 認証情報を安全に扱っているか
- 障害時にローカルだけで再現できるか
- 後続SQLが外部ソースの種類に依存しすぎていないか

外部連携の設計が良いと、SQLiteからPostgreSQLへ切り替えても、後続の正規化や品質チェックをほとんど変えずに済みます。

## よくあるつまずき

外部DBとのJOINは、データ転送量が大きくなることがあります。必要な列・行に絞ってからJOINします。

S3互換ストレージは認証、エンドポイント、パス形式の設定が必要です。MinIOで練習すると、本番S3に行く前に概念を分けて理解できます。

外部ソースを毎回直接読むと、再現性が下がることがあります。分析結果を説明する必要がある場合は、取得時点やbatchを残します。

DuckDBから外部DBを書き換える設計は慎重に扱います。品質チェックで問題を見つけることと、正本DBを更新することは別の責務です。

## MySQL、GCS、Azure Blob、Cloudflare R2はどう扱うか

このチュートリアルの標準演習では、SQLite、PostgreSQL、HTTP、S3互換ストレージを扱います。これはローカルで再現しやすく、外部ソース連携の基本を学びやすいからです。

実務では、MySQL、GCS、Azure Blob、Cloudflare R2を読む場面もあります。ただし、ここで重要なのは接続先の種類を増やすことではありません。

追加の外部ソースを見る時の観点:

- そのデータソースは正本か、配布用コピーか
- DuckDBから直接読むべきか、一度スナップショットすべきか
- 認証情報をどこで管理するか
- ネットワーク失敗時に再実行できるか
- 後続SQLが接続元の違いに依存しないか

MySQLを読む場合も、PostgreSQLと同じく、業務DBの正本をDuckDBへ置き換えるわけではありません。読み取り専用、負荷、スナップショット性を先に考えます。

GCS、Azure Blob、Cloudflare R2を読む場合も、S3互換ストレージと同じく、クラウド上のファイルを分析成果物として扱えるかが中心です。クラウド固有の認証や権限は、SQLとは別の運用責務です。

## このPartに対応する実装ファイル

- `product-data-duckdb/sql/02_load_raw.sql`: SQLiteマスタ読み込み
- `product-data-duckdb/sql/02_load_raw_postgres.sql`: PostgreSQLマスタ読み込み
- `product-data-duckdb/sql/07_read_http_parquet.sql`: HTTP上のParquet読み込み
- `product-data-duckdb/sql/08_read_s3_parquet.sql`: S3互換ストレージ上のParquet読み込み
- `product-data-duckdb/docker-compose.yml`: PostgreSQLとMinIOのローカル環境

## 次のPartに進む条件

- SQLite/PostgreSQLを読み取り専用でATTACHできる理由を説明できる
- HTTP/S3上のParquetを読む時に `httpfs` が必要なことを説明できる
- 外部ソースを直接読む場合とローカルに落とす場合を判断できる
- 正本DBとDuckDBの責務分担を説明できる
- `hive_partitioning` がパス情報を列として扱う仕組みを説明できる
- MySQLやクラウドストレージを追加する時も、正本性、認証、再現性を先に考えられる

## 公式docsで確認する箇所

- SQLite Extension: https://duckdb.org/docs/current/core_extensions/sqlite.html
- PostgreSQL Extension: https://duckdb.org/docs/current/core_extensions/postgres.html
- httpfs Extension: https://duckdb.org/docs/current/core_extensions/httpfs/overview.html
- S3 API Support: https://duckdb.org/docs/current/core_extensions/httpfs/s3api.html
