# Part 8 Exercises

## 1. EXPLAINを見る

`output/products.parquet` を読む集計SQLに `EXPLAIN` を付け、実行計画を確認してください。

## 2. EXPLAIN ANALYZEを保存する

`make profile` を実行し、`reports/parquet_explain.txt` の中で読み取り対象が何か確認してください。

## 3. partition設計を考える

商品データを `category_name`、`ingest_date`、`maker_name` のどれでpartitionするべきか、用途別に判断してください。

## 4. 性能実験を実行する

`make perf-lab` を実行し、`reports/perf_lab.txt` を確認してください。集計処理とwindow処理で、どのような実行計画が出るか観察します。

## 提出物

- EXPLAIN対象SQL
- プロファイル結果の観察メモ
- partition設計の判断
- `perf_lab.txt` の観察メモ

## 進級チェック

遅い処理に対して、先に実行計画を見て、SQL、データ設計、設定値のどれを疑うか説明できれば合格です。
