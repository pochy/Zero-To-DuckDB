# Part 6 Exercises

## 1. Node.js CLIを実行する

`node scripts/check-quality.mjs --db product_pipeline.duckdb` を実行し、JSONの主なフィールドを説明してください。

## 2. 失敗条件を変える

`--max-errors` の値を変え、どの値なら成功し、どの値なら失敗するか確認してください。

## 3. APIレスポンスを設計する

品質チェックAPIのレスポンスJSONを設計してください。画面文言ではなく、アプリが判断できるフィールドにしてください。

## 提出物

- Node.js CLI出力の要約
- 成功/失敗条件の確認結果
- APIレスポンス案

## 進級チェック

アプリがDuckDBの内部SQLではなく、安定したJSON契約に依存する設計を説明できれば合格です。
