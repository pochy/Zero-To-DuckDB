# DuckDB実践チュートリアル 全体設計

このファイルは、チュートリアル全体の設計書と索引です。実際の本文は `parts/` 配下の各Partに分かれています。

最初に読むもの:

- [README.md](README.md)
- [START_HERE.md](START_HERE.md)
- [glossary.md](glossary.md)
- [parts/README.md](parts/README.md)
- [EXPERT.md](EXPERT.md): Part 0-11完了後に読む発展編

## 目的

このチュートリアルの目的は、DuckDBのAPIを暗記することではありません。

目標は、次の状態です。

> バラバラな実務データをDuckDBで取り込み、検証し、標準化し、Parquet化し、分析・アプリ・ML/AIパイプラインへ渡せる。

DuckDBは、WebアプリのメインDBとして使うものではなく、分析、前処理、ファイル処理、品質チェック、ローカル/組み込みSQL処理に強いエンジンとして学びます。

## 学習思想

この教材は、次の順番で進みます。

1. まず動かす
2. 用語を知る
3. メンタルモデルを作る
4. 小さなSQLを書く
5. 出力を観察する
6. 失敗や品質問題を見る
7. 実務設計へ広げる

DuckDBは「CSVを読めるSQLツール」としても便利ですが、それだけでは実務の設計力にはつながりません。このチュートリアルでは、raw/staging/mart、品質チェック、Parquet出力、外部DB連携、アプリ境界、運用まで扱います。

## このチュートリアルを貫く設計哲学

このチュートリアルの中心にある考え方は、次の一文です。

> DuckDBは、正本DBの代わりではなく、正本DBやファイルと後続利用の間に置く、検証・変換・説明のための分析エンジンである。

したがって、ここで学ぶべきことは `read_csv` のオプションや `COPY` の書き方だけではありません。重要なのは、データ処理の責務をどこで分けるかです。

- rawは、入力の証拠を残す場所
- stagingは、解釈と標準化を行う場所
- martは、他者が依存できる契約を置く場所
- Parquetは、後続分析やアプリへ渡す成果物
- JSON CLIは、アプリやバッチが判断する境界
- テストは、期待値からのズレを説明可能にする仕組み

初心者は、動くSQLを早く書くことに意識が向きがちです。しかし実務で問われるのは、なぜその処理をその層に置いたのか、なぜその不正データを落とさず残したのか、なぜその出力を後続が信頼してよいのかです。

この教材では、各Partで必ず次の問いに戻ります。

- なぜこの設計が存在するのか
- 初心者はここで何を誤解しやすいのか
- プロは何を見て判断するのか
- 本番運用ではどんなトレードオフが出るのか

APIや関数は、この判断を実現するための道具です。道具の使い方だけを覚えても、入力が汚れた時、マスタが変わった時、出力件数がズレた時、アプリから使いたい時に設計判断ができません。このチュートリアルの目的は、DuckDBを書く力ではなく、DuckDBをどこに置くべきか説明する力です。

## 設計原則

このチュートリアルでは、すべての章で次の原則を前提にします。

1つ目は、正本と作業場所を分けることです。業務の正本データは、PostgreSQLや業務システムのような管理された場所に置きます。DuckDBは、その正本や外部ファイルを読み、検証し、分析可能な成果物へ変換する作業場所として使います。正本と作業場所を混ぜると、検証中のデータと業務上の事実が混ざり、失敗時の影響範囲が広がります。

2つ目は、入力を信用しないが、入力の痕跡は失わないことです。ファイル取り込みでは、不正な価格、未知カテゴリ、欠損JANコードを最初から消してはいけません。後で説明するには、元ファイル、batch、取り込み日、元の値が必要です。品質改善は、問題を隠すことではなく、問題を追跡できる形にすることから始まります。

3つ目は、処理の層に意味を持たせることです。raw、staging、martは単なる名前ではありません。rawは証拠、stagingは解釈、martは契約です。この意味を守ると、どのSQLにどの責務を置くべきか判断できます。逆に、rawで業務判断をしたり、martに曖昧な一時集計を置いたりすると、後で変更しにくくなります。

4つ目は、後続利用者の視点で出力することです。Parquet、JSON、レポート、テストは、作った本人のためだけではありません。別のアプリ、別の分析者、将来の自分が使う契約です。後続が何を信頼してよいのか、どの値を監視すべきか、どの条件で失敗とみなすのかを明確にします。

5つ目は、変更に備えることです。実務データは変わります。列が増え、マスタが変わり、入力元が増え、品質基準が厳しくなります。良い設計は、変更が起きないことを期待する設計ではありません。変更が起きた時に、どの層を変えればよいか説明できる設計です。

## Part構成

| Part | 本文 | 演習 | 到達目標 |
| --- | --- | --- | --- |
| 0 | [DuckDBの全体像](parts/part_00_overview/README.md) | [Exercises](parts/part_00_overview/exercises.md) | DuckDBの位置づけを説明できる |
| 1 | [DuckDB入門](parts/part_01_intro/README.md) | [Exercises](parts/part_01_intro/exercises.md) | CLIでSQLとCSV読み込みができる |
| 2 | [ファイル取り込み](parts/part_02_file_ingestion/README.md) | [Exercises](parts/part_02_file_ingestion/exercises.md) | CSV/Excel/JSON/Parquetを読める |
| 3 | [クリーニングと正規化](parts/part_03_cleaning_normalization/README.md) | [Exercises](parts/part_03_cleaning_normalization/exercises.md) | 汚いデータを標準スキーマへ寄せられる |
| 4 | [分析SQL](parts/part_04_analytics_sql/README.md) | [Exercises](parts/part_04_analytics_sql/exercises.md) | JOIN/集計/ウィンドウ関数を使える |
| 5 | [Python連携](parts/part_05_python/README.md) | [Exercises](parts/part_05_python/exercises.md) | NotebookやDataFrameとの境界を説明できる |
| 6 | [Node.js/アプリ組み込み](parts/part_06_node_app/README.md) | [Exercises](parts/part_06_node_app/exercises.md) | 品質チェックをJSON契約で扱える |
| 7 | [外部DB・クラウドストレージ](parts/part_07_external_sources/README.md) | [Exercises](parts/part_07_external_sources/exercises.md) | SQLite/PostgreSQL/HTTP/S3を扱える |
| 8 | [パフォーマンス](parts/part_08_performance/README.md) | [Exercises](parts/part_08_performance/exercises.md) | EXPLAINとParquet設計で調査できる |
| 9 | [運用・設計・テスト](parts/part_09_operations_testing/README.md) | [Exercises](parts/part_09_operations_testing/exercises.md) | 再現可能なパイプラインにできる |
| 10 | [専門家向けトピック](parts/part_10_advanced/README.md) | [Exercises](parts/part_10_advanced/exercises.md) | DuckDBの限界と使い分けを判断できる |
| 11 | [最終課題](parts/part_11_final_project/README.md) | [Exercises](parts/part_11_final_project/exercises.md) | 実務型商品情報統合パイプラインを説明できる |

## 最終課題

最終課題は、メーカーから届くバラバラな商品情報ファイルを統合するパイプラインです。

扱う入力:

- CSV
- Excel
- JSON Lines
- SQLiteカテゴリマスタ
- PostgreSQLカテゴリマスタ
- HTTP上のParquet
- S3互換ストレージ上のParquet

作るもの:

- DuckDBデータベース
- raw/staging/master/martスキーマ
- 品質チェックレポート
- エラー行CSV
- 正規化済みParquet
- partitioned Parquet dataset
- Python品質チェックCLI
- Node.js品質チェックCLI
- HTMLレポート
- Notebook分析
- SQLテスト

完成実装は [product-data-duckdb](product-data-duckdb/README.md) にあります。

## 実行コマンド

標準ルート:

```bash
cd product-data-duckdb
make run
make quality
make check-json
make check-node
make report
make profile
make advanced
make friendly-sql
make nested-json
make asof-join
make export-lab
make perf-lab
make notebook-check
make test
make test-advanced
make test-local-ecosystem
```

PostgreSQLマスタ版:

```bash
make postgres-run
make quality
make test
```

HTTP上のParquet:

```bash
make serve-output
make http-read
```

S3互換ストレージ上のParquet:

```bash
make s3-read
```

## 現在の実装内容

`product-data-duckdb/` には、次の実装があります。

```text
product-data-duckdb/
  data/
    incoming/
      maker_a/products.csv
      maker_b/products.csv
      maker_c/catalog.xlsx
      ai_ocr/extractions.jsonl
    master/
      categories.csv
  sql/
    01_create_schemas.sql
    02_load_raw.sql
    02_load_raw_postgres.sql
    03_normalize.sql
    04_quality_checks.sql
    05_export_parquet.sql
    06_explain_parquet.sql
    07_read_http_parquet.sql
    08_read_s3_parquet.sql
    09_advanced_analytics.sql
    10_dimensional_model.sql
    11_performance_lab.sql
    12_tax_normalization_example.sql
    13_friendly_sql.sql
    14_nested_json_unnest.sql
    15_asof_join.sql
    16_export_options.sql
  scripts/
    create_excel_sample.py
    create_sqlite_master.py
    check_quality.py
    check-quality.mjs
    create_quality_report.py
    check_notebook.py
    serve_output.py
    wait_for_port.py
    run_pipeline.sh
  tests/
    test_pipeline.sql
    test_advanced_topics.sql
    test_local_advanced_sql.sql
  notebooks/
    quality_analysis.ipynb
  postgres/
    init/01_master.sql
  docker-compose.yml
  Makefile
```

生成物は `.gitignore` 対象です。

主な生成物:

- `product_pipeline.duckdb`
- `data/master/master.sqlite`
- `reports/quality_report.csv`
- `reports/product_errors.csv`
- `reports/quality_report.html`
- `reports/parquet_explain.txt`
- `reports/perf_lab.txt`
- `output/products.parquet`
- `output/products_by_category/`
- `output/products_by_ingest_date/`

## 公式docs参照

- Installation: https://duckdb.org/install/
- Data Sources: https://duckdb.org/docs/current/data/data_sources.html
- CSV Import: https://duckdb.org/docs/current/data/csv/overview.html
- JSON: https://duckdb.org/docs/current/data/json/overview.html
- Excel Extension: https://duckdb.org/docs/current/core_extensions/excel.html
- Parquet: https://duckdb.org/docs/current/data/parquet/overview.html
- Python API: https://duckdb.org/docs/current/clients/python/overview
- Node.js Client: https://duckdb.org/docs/current/clients/node_neo/overview.html
- PostgreSQL Extension: https://duckdb.org/docs/current/core_extensions/postgres.html
- httpfs / S3: https://duckdb.org/docs/current/core_extensions/httpfs/s3api.html
- Performance Guide: https://duckdb.org/docs/current/guides/performance/overview.html

## 推奨学習順

最初から全て深く読むより、次の3周で進めます。

1周目:

1. Part 0
2. Part 1
3. Part 2
4. Part 11で `make run`

2周目:

1. Part 3
2. Part 4
3. Part 5
4. Part 11で品質チェックとNotebook

3周目:

1. Part 6
2. Part 7
3. Part 8
4. Part 9
5. Part 10
6. Part 11を再設計する

## 完了条件

このチュートリアルは、次を説明できれば完了です。

- DuckDBを使うべき場面と避けるべき場面
- raw/staging/martの役割
- `try_cast` と品質チェックの関係
- 外部DBを読み取り専用で参照する理由
- Parquetとpartitioned datasetの違い
- `EXPLAIN` を見る理由
- `ANTI JOIN`、`SEMI JOIN`、`UNPIVOT`、ウィンドウ関数を品質調査や形変換に使う理由
- `read_csv_auto`、`read_json_auto`、`SELECT * EXCLUDE`、`SELECT * REPLACE`、`COLUMNS`、`GROUP BY ALL`、`FILTER`、`SUMMARIZE` を探索や品質集計に使う理由
- `UNNEST` と `ASOF JOIN` をネスト構造や時点結合に使う理由
- dimension/fact/SCDの基本的な使い分け
- OCR confidenceをエラーではなく警告として扱う理由
- Notebook、CLI、SQLファイル、アプリ境界の役割分担
- 最終課題のアーキテクチャ

完了後に実運用での専門性を高める場合は、[EXPERT.md](EXPERT.md) に進みます。そこでは、DuckDB内部の前提、性能調査、本番パイプライン設計、Lakehouse/DWHとの責務分担、セキュリティ、拡張機能、実データでの失敗対応を扱います。
