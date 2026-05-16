# Part 3 Exercises

## 1. 価格変換を確認する

`staging.normalized_products` から `price IS NULL` の行を抽出し、元ファイルを確認してください。

## 2. 未知カテゴリを調べる

`category_id IS NULL` の行を抽出し、どのカテゴリ名がマスタと一致していないか集計してください。

## 3. 重複ルールを説明する

JANコードが重複したとき、なぜ `ingest_date`、`updated_at`、`source_file` の順で優先するのか説明してください。

## 4. OCR confidenceを確認する

`mart.quality_report` の `low_ocr_confidence` を確認し、なぜ `mart.product_errors` には入れていないのか説明してください。

## 提出物

- 価格不正行の確認SQL
- 未知カテゴリの集計SQL
- 重複排除ルールの説明
- OCR confidenceの扱いに関する説明

## 進級チェック

不正データと警告信号を分けて説明できれば合格です。
