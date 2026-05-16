# Part 2 Exercises

## 1. ファイル名を残す

複数CSVを `filename = true` で読み、ファイルごとの行数を集計してください。

## 2. JSONから列を取り出す

AI-OCRのJSON Linesから、JANコード、商品名、価格、メーカー名だけを取り出してください。

## 3. raw層の設計を説明する

なぜ最初から価格を数値にせず、raw層では文字列として受けるのか説明してください。

## 4. auto readerと明示読み込みを比較する

`make friendly-sql` を実行し、`mart.auto_reader_probe` の結果を確認してください。`read_csv_auto` / `read_json_auto` を探索用に留める理由を説明してください。

## 5. Parquet出力オプションを確認する

`make export-lab` を実行し、`mart.export_option_summary` を確認してください。単一ファイル出力と `PER_THREAD_OUTPUT true` の違いを説明してください。

## 提出物

- CSVファイル別行数のSQLと結果
- JSON抽出SQL
- raw層設計の説明
- auto readerの観察メモ
- Parquet出力オプションの観察メモ

## 進級チェック

複数形式の入力を、探索用の読み方と再現可能な読み方に分けて説明できれば合格です。
