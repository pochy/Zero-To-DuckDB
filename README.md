# DuckDB実践チュートリアル

このリポジトリは、DuckDBを「SQLを実行できる便利ツール」としてではなく、実務のデータ処理基盤を小さく作るための分析エンジンとして学ぶチュートリアルです。

最終的には、メーカーから届くCSV、Excel、JSON、外部DB、S3互換ストレージ上のParquetをDuckDBで統合し、品質チェックし、標準スキーマのParquet datasetへ出力するパイプラインを作ります。

最初に読むファイル:

- [START_HERE.md](START_HERE.md): 今日最初にやること
- [TUTORIAL.md](TUTORIAL.md): 全体設計と学習順
- [glossary.md](glossary.md): 用語集
- [parts/README.md](parts/README.md): Part別チュートリアル一覧
- [EXPERT.md](EXPERT.md): Part 0-11完了後のエキスパート編

## 学習ロードマップ

| Part | 内容 | 進める条件 |
| --- | --- | --- |
| 0 | DuckDBの位置づけ、OLTP/OLAP、環境構築 | DuckDBを使う場面と使わない場面を説明できる |
| 1 | CLI、基本SQL、CSVを直接読む | CSVをSQLで読み、集計できる |
| 2 | CSV/Excel/JSON/Parquet取り込み | ファイル形式ごとの読み方と注意点を説明できる |
| 3 | クリーニングと正規化 | raw/staging/martを分けて考えられる |
| 4 | 分析SQL | JOIN、集計、ウィンドウ関数、PIVOT/UNPIVOTを使える |
| 5 | Python連携 | Notebookやpandas/Polarsとの境界を説明できる |
| 6 | Node.js/アプリ組み込み | 品質チェックをCLI/アプリから呼べる |
| 7 | 外部DB/クラウドストレージ連携 | SQLite/PostgreSQL/HTTP/S3上のデータを扱える |
| 8 | パフォーマンス | EXPLAINとParquet設計を使って調査できる |
| 9 | 運用・設計・テスト | ローカルで再現可能なパイプラインを作れる |
| 10 | 専門家向け判断 | DuckDBの限界と他基盤との使い分けを説明できる |
| 11 | 最終課題 | 商品情報統合パイプラインを実行・説明できる |

## 最初の実行

DuckDB CLIをインストールしてから、完成例を動かします。

```bash
cd product-data-duckdb
make run
make quality
make test
make advanced
make test-advanced
```

期待すること:

- `product_pipeline.duckdb` が作られる
- `reports/quality_report.csv` と `reports/product_errors.csv` が作られる
- `output/products.parquet` と partitioned Parquet dataset が作られる
- `make test` が成功する
- 発展演習のmartテーブルが作られ、`make test-advanced` が成功する
- ローカル発展SQLを試す場合は `make friendly-sql`、`make nested-json`、`make asof-join`、`make export-lab`、`make test-local-ecosystem` が成功する

## このチュートリアルの立場

DuckDBはWebアプリのメインDBとして使うものではありません。強いのは、ローカルまたはアプリ内での分析、ファイル処理、前処理、品質チェック、Parquet化、Notebook/CLI/バッチ処理です。

このチュートリアルでは、APIの暗記よりも「どこにDuckDBを置くべきか」「どこから別のDBやDWHを使うべきか」を判断できる状態を目指します。

Part 0-11を完了したあと、業務での実運用を見越してさらに深める場合は [EXPERT.md](EXPERT.md) を読んでください。内部構造、性能設計、本番パイプライン、Lakehouse/DWHとの責務分担、セキュリティ、運用経験までをエキスパート編として整理しています。
