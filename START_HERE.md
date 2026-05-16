# START HERE

## 今日やること

最初の目標は、DuckDBで実務寄りのデータパイプラインがローカルで動くことを確認することです。まだ全Partを読む必要はありません。

## 1. DuckDB CLIを確認する

```bash
duckdb --version
```

入っていない場合は、macOSなら次のように入れます。

```bash
brew install duckdb
```

PythonパッケージとしてCLIを入れる方法もあります。

```bash
pip install duckdb
```

## 2. 完成例を動かす

```bash
cd product-data-duckdb
make run
make quality
make test
```

見るポイント:

- `make run` はCSV、Excel、JSON、SQLiteマスタを読み込み、正規化し、Parquetを書き出します。
- `make quality` は品質チェック結果を表示します。
- `make test` は期待する品質件数と出力件数が変わっていないか確認します。

## 3. Part 0から読む

最初は次の順で進めます。

1. [Part 0](parts/part_00_overview/README.md)
2. [Part 1](parts/part_01_intro/README.md)
3. [Part 2](parts/part_02_file_ingestion/README.md)
4. [Part 3](parts/part_03_cleaning_normalization/README.md)
5. [Part 11](parts/part_11_final_project/README.md)

この順番なら、細かいAPIを全部覚える前に、DuckDBの使いどころと完成形が見えます。

## 4. 学習ルートを選ぶ

最短ルート:

1. Part 0でDuckDBの位置づけを読む
2. Part 1でCLIとCSV読み込みを動かす
3. Part 2で複数ファイル取り込みを見る
4. Part 3で正規化と品質チェックを見る
5. Part 11で完成実装を動かす

じっくりルート:

1. Part 0-4でSQLとデータ設計を固める
2. Part 5-7でPython、Node.js、外部DB、HTTP/S3を確認する
3. Part 8-10で性能、運用、限界を学ぶ
4. Part 11で完成実装を読み、メーカー追加を設計する
5. [EXPERT.md](EXPERT.md) で実運用に必要な領域を確認する

完成実装から逆引きするルート:

1. `product-data-duckdb/Makefile` で実行順を見る
2. `product-data-duckdb/sql/01_create_schemas.sql` から `05_export_parquet.sql` まで読む
3. `product-data-duckdb/tests/test_pipeline.sql` で期待値を見る
4. 分からない概念に対応するPartへ戻る

## 学習時間の目安

| 範囲 | 目安 |
| --- | --- |
| Part 0-1 | 1-2時間 |
| Part 2-4 | 半日 |
| Part 5-7 | 半日 |
| Part 8-10 | 半日 |
| Part 11 | 1日 |

## よくあるつまずき

`duckdb` コマンドが見つからない場合は、インストール後にターミナルを開き直します。

Excel、SQLite、PostgreSQL、HTTP/S3連携ではDuckDB拡張機能を使います。初回実行時に `INSTALL` が走るため、ネットワーク制限がある環境では失敗することがあります。

Dockerが必要なのはPostgreSQLとMinIOを使う発展パートだけです。DuckDB CLI、CSV、Excel、JSON、Parquetの基本はDockerなしで進められます。

## 公式docsの使い方

本文を先に読み、手元で動かしてから公式docsを確認してください。公式docsは正確ですが、最初から読むと「何を判断すればよいか」が見えにくくなります。
