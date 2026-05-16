# Part 11 Exercises

## 1. 完成パイプラインを再実行する

`make clean`、`make run`、`make quality`、`make test` を順に実行してください。

## 2. 品質チェックを説明する

`mart.quality_report` の各チェックについて、何を検出しているのか説明してください。

## 3. 新しい入力を設計する

新しいメーカーDからCSVが届く想定で、必要なカラム、rawへの読み方、stagingでの変換、品質チェックを設計してください。

## 4. 出力利用者を想定する

Parquet出力をBI、Python、Web API、MLのどれが読むかを1つ選び、必要な列とpartition設計を説明してください。

## 5. 発展martを確認する

`make advanced` と `make test-advanced` を実行し、`mart.dim_product` と `mart.fact_product_price` の粒度の違いを説明してください。

## 6. 税込/税抜の契約を考える

`mart.tax_normalization_review` を読み、`requires_input_contract` が出る理由を説明してください。

## 提出物

- 再実行結果
- 品質チェックの説明
- メーカーD追加設計
- 出力利用者向けの設計メモ
- 発展martの粒度説明
- 税込/税抜の入力契約メモ

## 進級チェック

完成パイプラインを動かすだけでなく、入力追加、品質チェック、出力設計、発展mart、価格契約の変更を自分で説明できれば合格です。
