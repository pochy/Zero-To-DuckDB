# Part 11: 最終課題 実務型商品情報統合パイプライン

## このPartでできるようになること

ここまで学んだ内容を使い、CSV、Excel、JSON、SQLite/PostgreSQLマスタ、HTTP/S3上のParquetを扱う実務型パイプラインを実行・説明できるようになります。

このPartは、単なる総復習ではありません。DuckDBを「便利なSQLツール」としてではなく、実務データ処理アーキテクチャの中の部品として説明できるかを確認する最終課題です。

完成条件は、コマンドが成功することだけではありません。入力、変換、品質チェック、出力、テスト、アプリ境界、外部ソース連携、運用判断を自分の言葉で説明できることです。

## このPartの設計思想

最終課題の思想は、「完成実装を動かす」ことではなく、「なぜこの構造になっているかを説明できる」ことです。

このパイプラインは、CSVを読むSQLの集合ではありません。入力の証拠を残し、標準化し、品質を分類し、正常データを成果物にし、アプリや分析へ渡すための責務分離の例です。

## なぜこの考え方が必要なのか

実務のパイプラインは、作った本人だけが動かせても不十分です。別の人がレビューでき、失敗時に原因を追え、入力元へ差し戻せ、後続システムが契約として使える必要があります。

そのため、最終課題では `make run` の成功よりも、raw/staging/mart、品質チェック、Parquet、JSON CLI、テスト、外部ソース連携の関係を説明できることを重視します。

## 初心者が誤解しやすいこと

初心者は、最終課題を「手順の総まとめ」と考えがちです。しかし、この章の目的は手順の暗記ではありません。

たとえば、`all_varchar = true` を使っている理由、`LEFT JOIN` で未知カテゴリを残す理由、`row_number()` で重複優先順位を明示する理由、`product_errors.csv` を出す理由を説明できなければ、実務で入力が変わった時に設計を変更できません。

## プロはどう判断するか

プロは、最終課題を設計レビューとして読みます。各SQLファイルがどの責務を持つか、どの生成物が後続契約か、どの値がテストで固定されるべきか、どこから外部DBやアプリと境界を作るかを確認します。

完成とは、コマンドを実行できることではなく、変更要求に対して「どの層を変えるべきか」を判断できることです。メーカーDを追加するならraw取り込み、カテゴリ同義語を増やすならマスタ/正規化、API化するならJSON契約、性能問題ならParquet/partition/EXPLAINを見る。この判断力が最終課題の到達点です。

## 背景にある設計原則

最終課題の背景にある原則は、個別機能を1つの設計に統合することです。CSV読み込み、Excel読み込み、JSON flattening、`try_cast`、品質チェック、Parquet出力、Python CLI、Node.js CLI、外部DB連携は、それぞれ単体でも学べます。しかし実務では、それらが1つの流れとしてつながって初めて価値になります。

このパイプラインでは、入力のばらつきをrawで受け、stagingで解釈し、martで品質契約にし、ParquetとJSONで後続へ渡します。これは、データが「届く」状態から「使える」状態へ変わるまでの責務分離です。

ここでのトレードオフは、単純さと説明可能性です。小さなスクリプト1本で全部処理すれば、短く見えるかもしれません。しかし、どこで読み、どこで直し、どこで品質を判断し、どこで出力したのかが見えにくくなります。複数の層に分けるとファイル数は増えますが、変更時に見る場所が明確になります。

## 題材

小売業の商品情報統合パイプラインをDuckDBで作ります。

毎週、複数メーカーから商品情報が届きます。形式は統一されていません。

- メーカーA: CSV
- メーカーB: CSV
- メーカーC: Excel
- AI-OCR結果: JSON Lines
- 社内カテゴリマスタ: SQLiteまたはPostgreSQL
- 出力: Parquet / partitioned Parquet dataset

現実の業務では、このような入力のばらつきは珍しくありません。ファイル形式、列名、型、カテゴリ表記、更新日、欠損、重複が揃っていない状態から、後続システムが使える形へ整える必要があります。

この最終課題では、DuckDBを次の役割に置きます。

```text
バラバラな入力
  ↓
DuckDBによる取り込み・正規化・品質チェック
  ↓
Parquet / レポート / JSON契約
  ↓
BI、Notebook、Web API、ML、後続バッチ
```

## 完成実装

完成実装はリポジトリ直下の `product-data-duckdb/` です。

```text
product-data-duckdb/
  data/
  sql/
  scripts/
  tests/
  notebooks/
  reports/
  output/
  postgres/
  docker-compose.yml
  Makefile
```

このディレクトリは、チュートリアル本文のためのおまけではありません。実際に動く最終課題の実装です。

主要な責務は次の通りです。

| ディレクトリ/ファイル | 役割 |
| --- | --- |
| `data/incoming/` | 入力ファイルサンプル |
| `data/master/` | 生成されるSQLiteマスタ |
| `sql/` | パイプライン本体 |
| `scripts/` | サンプル生成、品質CLI、レポート、補助処理 |
| `tests/` | SQLによる回帰テスト |
| `notebooks/` | 生成物の観察 |
| `reports/` | 品質レポート生成先 |
| `output/` | Parquet出力先 |
| `Makefile` | 実行入口 |

## 手順1: 標準パイプラインを実行する

```bash
cd product-data-duckdb
make run
make quality
make test
```

期待する生成物:

- `product_pipeline.duckdb`
- `reports/quality_report.csv`
- `reports/product_errors.csv`
- `output/products.parquet`
- `output/products_by_category/`
- `output/products_by_ingest_date/`

この3コマンドには、それぞれ役割があります。

| コマンド | 役割 |
| --- | --- |
| `make run` | 入力生成、取り込み、正規化、品質チェック、Parquet出力 |
| `make quality` | 品質チェック結果を人間が読む表として表示 |
| `make test` | 件数、出力、partition、メタデータが期待通りか検証 |

`make run` が成功しても、パイプラインが正しいとは限りません。品質チェックとテストまで見て初めて、期待する出力になっているか判断できます。

## 手順2: SQLの流れを読む

標準ルートのSQLは次の順番で動きます。

```text
sql/01_create_schemas.sql
sql/02_load_raw.sql
sql/03_normalize.sql
sql/04_quality_checks.sql
sql/05_export_parquet.sql
```

流れ:

1. `raw`、`staging`、`master`、`mart` スキーマを作る
2. CSV、Excel、JSONをrawへ読む
3. SQLiteマスタをATTACHしてカテゴリを読む
4. stagingでtrim、`try_cast`、カテゴリ正規化を行う
5. 品質チェックをmartへ作る
6. エラー行と正常データを出力する

この流れは、Part 0〜10で学んだ考え方の集約です。

| Part | 最終課題での対応 |
| --- | --- |
| Part 0 | DuckDBを分析・前処理エンジンとして配置 |
| Part 1 | CLIとDBファイルを使った実行 |
| Part 2 | CSV、Excel、JSON、SQLiteの取り込み |
| Part 3 | raw/staging/mart、`try_cast`、品質チェック |
| Part 4 | 集計、JOIN、重複排除、mart |
| Part 5 | Python CLIとNotebook |
| Part 6 | Node.js CLIとJSON契約 |
| Part 7 | PostgreSQL、HTTP、S3互換ストレージ |
| Part 8 | Parquet、partition、EXPLAIN |
| Part 9 | Makefile、生成物、テスト、運用 |
| Part 10 | 採用判断、セキュリティ、限界 |

## 手順2.5: 実装ファイルの読み順

完成実装を理解する時は、ファイル名順に読むだけではなく、役割ごとに読みます。

1. `Makefile`: どの順番で処理が動くかを見る
2. `sql/01_create_schemas.sql`: raw/staging/master/martの置き場所を見る
3. `sql/02_load_raw.sql`: CSV、Excel、JSON、SQLiteマスタの取り込みを見る
4. `sql/03_normalize.sql`: 標準スキーマ、型変換、カテゴリJOIN、重複排除を見る
5. `sql/04_quality_checks.sql`: 品質チェックとエラー行の定義を見る
6. `sql/05_export_parquet.sql`: Parquet出力とpartition設計を見る
7. `tests/test_pipeline.sql`: 何を期待値として固定しているかを見る
8. `scripts/check_quality.py`: 品質結果をJSON契約にする方法を見る
9. `scripts/check-quality.mjs`: アプリ側から同じ契約を使う方法を見る
10. `notebooks/quality_analysis.ipynb`: 生成物を観察する方法を見る

この順番で読むと、「実行入口」「SQL本体」「品質契約」「アプリ/分析からの利用」が分かれます。

## 手順3: raw取り込みを説明する

`sql/02_load_raw.sql` では、CSV、Excel、JSON Linesをそれぞれ読み、最後に `raw.products` へ統合します。

ここで説明できるべきこと:

- なぜ `all_varchar = true` で読むのか
- なぜ `filename` を残すのか
- なぜCSV、Excel、JSONをいったん別rawテーブルにするのか
- なぜ `UNION ALL` で統合するのか
- なぜ `batch_id` と `ingest_date` を持つのか
- なぜカテゴリマスタを読み取り専用で参照するのか

raw層の目的は、きれいなデータを作ることではありません。入力の事実を失わず、後続で説明できる形にすることです。

この観点で見ると、`filename` は単なる便利列ではありません。品質エラーを入力元へ返すための根拠です。

## 手順4: 正規化と品質チェックを説明する

`sql/03_normalize.sql` では、rawからstagingへ変換します。

重要な設計:

- `trim` で余計な空白を消す
- `nullif` で空文字をNULLにする
- `try_cast` で不正な価格をNULLとして分類できるようにする
- `lower` でカテゴリ名を比較しやすくする
- `LEFT JOIN` で未知カテゴリを落とさず残す
- `row_number()` でJANコードごとの優先行を決める

`sql/04_quality_checks.sql` では、品質チェック結果を `mart.quality_report` に出し、エラー行を `mart.product_errors` に出します。

品質チェックで説明できるべきこと:

- 欠損JANコードはなぜ問題か
- 商品名欠損はなぜ出力から除くべきか
- 価格NULLや負数をどう扱うか
- 未知カテゴリをなぜエラーにするか
- 重複JANコードをなぜ件数として出すか
- エラー件数とエラー行の両方が必要な理由

最終課題では、品質エラーが存在してもパイプライン自体は動きます。これは、不正データを無視しているのではなく、不正データを分類し、正常データだけを出力する設計です。

## 手順5: 品質チェックを確認する

```bash
make quality
python3 scripts/check_quality.py --db product_pipeline.duckdb
node scripts/check-quality.mjs --db product_pipeline.duckdb
```

この3つは同じ品質情報を、別の入口から確認しています。

| 入口 | 読む人/用途 |
| --- | --- |
| `make quality` | 人間が表として確認する |
| Python CLI | バッチ、レポート、Python連携 |
| Node.js CLI | アプリ境界、JSON契約 |

期待される品質チェック件数:

| チェック | 件数 |
| --- | --- |
| `duplicate_jan_code` | 1 |
| `invalid_price` | 4 |
| `missing_jan_code` | 2 |
| `missing_product_name` | 0 |
| `unknown_category` | 4 |

この件数は、単なるサンプル値ではありません。`tests/test_pipeline.sql` で固定されているデータ契約です。変える場合は、入力データや仕様を変えた理由を説明できる必要があります。

## 手順6: Parquet出力を説明する

`sql/05_export_parquet.sql` では、正常データだけをParquetへ出力します。

出力は3種類あります。

| 出力 | 用途 |
| --- | --- |
| `output/products.parquet` | 単一ファイルとして扱いやすい正規化済み商品データ |
| `output/products_by_category/` | カテゴリで絞る分析に向くpartitioned dataset |
| `output/products_by_ingest_date/` | 取り込み日単位の処理や比較に向くpartitioned dataset |

出力対象は `staging.latest_products` です。これは、JANコードごとに優先行を選んだ後のテーブルです。

さらに、次の条件で不正データを除外します。

```sql
WHERE product_name IS NOT NULL
  AND price IS NOT NULL
  AND price >= 0
  AND category_id IS NOT NULL
```

ここで重要なのは、不正データを消して終わりにしていないことです。不正データは `reports/product_errors.csv` に残し、正常データだけをParquetへ出しています。

## 手順7: レポートとNotebookを見る

```bash
make report
make notebook-check
```

Notebookを開ける環境では次を実行します。

```bash
jupyter notebook notebooks/quality_analysis.ipynb
```

Notebookでは、品質レポートとParquet出力を観察します。本体処理はSQLとMakefileに置き、Notebookは分析・説明のために使います。

この分担は重要です。

```text
SQL/Makefile: 再実行可能な処理
Notebook: 観察と説明
HTML/CSV report: 人間向け共有
JSON CLI: アプリ/バッチ向け契約
```

Notebookだけで完結させないことが、実務パイプラインとしての条件です。

## 手順8: PostgreSQLマスタ版を実行する

Dockerが使える環境では次を実行します。

```bash
make postgres-run
make quality
make test
```

SQLiteマスタ版と同じ品質チェック結果になることを確認します。これは「マスタの置き場が変わっても、パイプラインの契約は変えない」練習です。

この設計では、後続の `sql/03_normalize.sql` や `sql/04_quality_checks.sql` は、マスタがSQLite由来かPostgreSQL由来かを気にしません。どちらの取り込みでも `master.categories` を作るからです。

これは非常に重要な境界設計です。

```text
外部ソースの違い
  ↓
load_raw SQLで吸収
  ↓
共通のmaster.categories
  ↓
後続処理は同じ
```

## 手順9: HTTP/S3上のParquetを読む

HTTP:

```bash
make serve-output
```

別ターミナル:

```bash
make http-read
```

S3互換ストレージ:

```bash
make s3-read
```

S3互換ストレージはMinIOで練習します。クラウドへ行く前に、エンドポイント、認証、bucket、object pathの考え方を分けて理解します。

ここで学ぶべきことは、S3コマンドそのものではありません。DuckDBがローカルファイルだけでなく、HTTPやS3上のParquet datasetを読む分析エンジンとして使えることです。

ただし、外部ソースを直接読むと、ネットワーク、認証、可用性、再現性の影響を受けます。本番では、直接読むか、ローカル/オブジェクトストレージに固定してから読むかを判断します。

## 手順10: 最終アーキテクチャを説明する

```text
incoming files
  -> DuckDB raw ingestion
  -> staging normalization
  -> quality checks
  -> error reports
  -> canonical product schema
  -> partitioned Parquet
  -> BI / Python / Web API / ML
```

この流れを自分の言葉で説明できれば、DuckDBを単体APIではなく、実務データ処理の部品として扱えるようになっています。

説明では、次の観点を含めます。

- DuckDBはWebアプリのメインDBではなく、分析・前処理エンジンである
- raw層では入力を落とさず、出どころを残す
- staging層では型と表記を整え、品質チェックへ渡す
- mart層では品質レポートやエラー行を契約として出す
- 正常データだけをParquetへ出力する
- Python/Node.jsはJSON契約を通して結果を使う
- 外部DBは読み取り専用で参照する
- Parquet datasetは後続分析やクラウド連携に使う

## 最終レビュー観点

完成したパイプラインをレビューするときは、次の問いを使います。

### 入力

- どの形式の入力を受けるか
- 入力元を追跡できるか
- schema driftに耐えられるか
- batch単位を説明できるか

### 変換

- raw/staging/martの責務が分かれているか
- 型変換失敗を分類できるか
- マスタ不一致を落とさず検出できるか
- 重複排除ルールが明示されているか

### 品質

- 品質チェック件数を説明できるか
- エラー行を確認できるか
- JSON契約でアプリから判断できるか
- テストで期待値を固定しているか

### 出力

- 正常データだけがParquetへ出ているか
- partition設計を説明できるか
- 出力にbatch metadataが残っているか
- 後続システムがどの成果物を読むか決まっているか

### 運用

- Makefileで実行順が固定されているか
- 生成物がGit管理から外れているか
- 失敗時にどこを見るか分かるか
- 外部依存をローカルで再現できるか

## 最終課題の提出物

この最終課題を完了したと言うためには、コマンド結果だけでなく、説明可能な成果物を用意します。

提出物:

- 実行したコマンド一覧
- `make quality` の結果
- `make test` の結果
- 品質エラー件数の説明
- `reports/product_errors.csv` の観察メモ
- `output/products.parquet` の用途説明
- partitioned datasetの設計理由
- raw/staging/martの役割説明
- Python/Node.js JSON契約の説明
- DuckDBをこのアーキテクチャに置く理由

この提出物を作ると、単に手順をなぞっただけか、設計を理解しているかが分かります。

## 設計変更課題

実務では、完成実装をそのまま使うことは少なく、要件に合わせて変更します。次の変更案を考えてください。

### 変更1: メーカーDのCSVを追加する

確認すること:

- ファイルをどこに置くか
- 既存CSVと列名が同じか
- `union_by_name` で吸収できるか
- 新しいカテゴリが出るか
- 品質チェック期待値が変わるか

### 変更2: 価格履歴を扱う

現在のパイプラインは、最新の商品候補を選ぶ設計です。価格履歴を扱う場合、JANコードごとに1行へ潰すだけでは不十分です。

考えること:

- 1行の粒度は商品か、商品価格履歴か
- `updated_at` を履歴日として使えるか
- 最新価格と過去価格を別テーブルにするか
- Parquet partitionは日付で切るべきか

### 変更3: カテゴリマスタをPostgreSQL正本にする

現在はSQLite標準ルートとPostgreSQLルートの両方があります。PostgreSQLを本番正本にするなら、次を考えます。

- 読み取り専用ユーザーを使うか
- 接続情報をどう管理するか
- マスタ変更のタイミングをどう記録するか
- 品質チェック結果がいつのマスタに基づくか説明できるか

### 変更4: 品質チェックをWeb APIから見る

Node.js CLIをWeb API化する場合、次を考えます。

- APIレスポンスのJSON契約
- batch_idやgeneratedAtの追加
- 重い処理を同期実行するか
- 生成済み結果を返すか
- 失敗時のHTTP statusをどうするか

これらの変更課題に答えられると、最終課題を「写経」ではなく、自分で設計変更できる状態に近づきます。

### 変更5: dimension/fact/SCDへmartを拡張する

`make advanced` を実行すると、`sql/10_dimensional_model.sql` がdimension/fact/SCD風のmartを作ります。

```bash
make advanced
make test-advanced
```

作られる主なテーブル:

- `mart.dim_maker`
- `mart.dim_category`
- `mart.dim_product`
- `mart.fact_product_price`
- `mart.dim_product_scd_example`

ここで学ぶべきことは、名前だけをそれらしくすることではありません。

`dim_product` は商品を分析の切り口として安定させる表です。`fact_product_price` は、メーカー、商品、カテゴリ、価格、日付という観測値を残す表です。SCD風の表は、商品属性が変わる可能性をどう表すかを考えるための教材です。

現在の実装は小さな例です。本番でSCDを扱うなら、履歴の開始日・終了日、同時刻更新、削除、マスタ変更、過去再計算の方針を決める必要があります。

### 変更6: 税込/税抜を扱う

税込/税抜の混在は、価格処理でよくある問題です。ただし、SQLだけで推測して補正するのは危険です。

`sql/12_tax_normalization_example.sql` は、税区分が宣言されている場合だけ比較用税込価格を計算し、税区分が不明な行を `requires_input_contract` として残します。

これは、価格の意味を勝手に決めないためです。税込か税抜か分からない価格を、都合よく変換すると、後続の分析や契約が壊れます。

## 評価ルーブリック

最終課題は、次の観点で評価します。

| 観点 | 不十分 | 十分 | 良い |
| --- | --- | --- | --- |
| 実行 | コマンドを一部しか実行できない | 標準ルートを実行できる | 品質、JSON、テストまで説明できる |
| 入力理解 | ファイル形式だけ説明できる | raw取り込みを説明できる | 入力契約とschema driftまで説明できる |
| 正規化 | SQL断片だけ説明できる | raw/staging/martを説明できる | どこまで直すかの判断を説明できる |
| 品質 | 件数だけ読める | エラー理由を説明できる | 次のアクションまで分類できる |
| 出力 | Parquetが出ると言える | 単一/partitionedを説明できる | 後続用途に応じて設計判断できる |
| 運用 | makeを実行できる | 生成物とテストを説明できる | 再実行、batch、失敗時対応まで説明できる |
| 採用判断 | DuckDBは便利と言える | 得意/不得意を説明できる | 他DB/DWHとの責務分担を説明できる |

目標は、すべてを暗記することではありません。設計判断の理由を説明できることです。

## 口頭説明テンプレート

最終課題を誰かに説明するときは、次の順番で話すと伝わりやすくなります。

```text
このパイプラインは、複数形式の商品入力をDuckDBで取り込み、
raw/staging/martに分けて品質チェックし、
正常データをParquetとして出力するものです。

DuckDBはWebアプリのメインDBではなく、
ファイル処理、前処理、品質検証、Parquet出力のエンジンとして使っています。

rawでは入力を落とさずsource_fileやbatch_idを残し、
stagingではtry_castやマスタJOINで標準化し、
martではquality_reportとproduct_errorsを作ります。

正常データだけをproducts.parquetとpartitioned datasetへ出力し、
Python/Node.js CLIは品質結果をJSON契約として返します。
```

この説明が自然にできれば、チュートリアルの中心思想は身についています。

## 実務へ拡張する時の次の一手

この最終課題を実務へ近づけるなら、次の順番で拡張します。

1. 複数batchを扱う
2. 入力ファイルの受領ログを作る
3. 品質チェックを設定化する
4. カテゴリ同義語マスタを作る
5. 価格履歴テーブルを追加する
6. Web APIで品質結果を返す
7. S3上に正式なParquet datasetを出す
8. 実行ログとメトリクスを保存する

いきなり全てを作る必要はありません。今の構成は、raw/staging/mart、品質チェック、Parquet出力、JSON契約という拡張の土台です。

## よくあるつまずき

`make run` の前に `make quality` を実行すると、DBやmartテーブルがないため失敗します。まずパイプラインを作ってから品質を見る順番です。

Dockerが使えない環境では、PostgreSQL、MinIO、S3互換ストレージの演習は飛ばして構いません。標準ルートはSQLiteマスタで完結します。

品質エラーがあることを、即パイプライン失敗と混同しないでください。この最終課題では、品質エラーを分類し、正常データだけを出力する設計にしています。

Notebookに本体処理を移さないでください。Notebookは観察の場であり、再実行可能な処理本体はSQLとMakefileに置きます。

## このPartに対応する実装ファイル

- `product-data-duckdb/Makefile`: 全体の実行順
- `product-data-duckdb/sql/01_create_schemas.sql`: スキーマ定義
- `product-data-duckdb/sql/02_load_raw.sql`: 標準取り込み
- `product-data-duckdb/sql/02_load_raw_postgres.sql`: PostgreSQLマスタ版
- `product-data-duckdb/sql/03_normalize.sql`: 正規化
- `product-data-duckdb/sql/04_quality_checks.sql`: 品質チェック
- `product-data-duckdb/sql/05_export_parquet.sql`: Parquet出力
- `product-data-duckdb/sql/06_explain_parquet.sql`: パフォーマンス確認
- `product-data-duckdb/sql/07_read_http_parquet.sql`: HTTP Parquet読み込み
- `product-data-duckdb/sql/08_read_s3_parquet.sql`: S3互換Parquet読み込み
- `product-data-duckdb/sql/09_advanced_analytics.sql`: 高度なJOIN、window、UNPIVOT
- `product-data-duckdb/sql/10_dimensional_model.sql`: dimension/fact/SCD風mart
- `product-data-duckdb/sql/11_performance_lab.sql`: 性能実験
- `product-data-duckdb/sql/12_tax_normalization_example.sql`: 税込/税抜の契約例
- `product-data-duckdb/tests/test_pipeline.sql`: 期待値テスト
- `product-data-duckdb/tests/test_advanced_topics.sql`: 発展トピックの期待値テスト
- `product-data-duckdb/scripts/`: CLI、レポート、補助スクリプト
- `product-data-duckdb/notebooks/quality_analysis.ipynb`: Notebook分析

## 完成条件

- `make run`、`make quality`、`make test` が成功する
- `make advanced`、`make test-advanced` が成功する
- raw/staging/martの役割を説明できる
- 品質チェックの各件数を説明できる
- Parquet出力とpartitioned datasetの違いを説明できる
- DuckDBをこのアーキテクチャのどこに置くべきか説明できる
- Python/Node.jsのJSON契約を説明できる
- dimension/fact/SCD風martと税処理例の狙いを説明できる
- 外部DBをREAD_ONLYで読む理由を説明できる
- 最終アーキテクチャを入力から後続利用まで説明できる

## 公式docsで確認する箇所

- Data Sources: https://duckdb.org/docs/current/data/data_sources.html
- Parquet: https://duckdb.org/docs/current/data/parquet/overview.html
- PostgreSQL Extension: https://duckdb.org/docs/current/core_extensions/postgres.html
- S3 API Support: https://duckdb.org/docs/current/core_extensions/httpfs/s3api.html
