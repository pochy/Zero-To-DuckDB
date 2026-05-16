# Part 4 Exercises

## 1. カテゴリ別価格統計

カテゴリ別に件数、平均価格、最高価格、最低価格を出してください。

## 2. メーカー別カテゴリ数

メーカーごとに、扱っているカテゴリ数を出してください。

## 3. 粒度を説明する

`staging.normalized_products` と `staging.latest_products` のどちらを使うべきか、分析目的ごとに説明してください。

## 4. 高度な分析SQLを実行する

`make advanced` を実行し、次のmartテーブルが何を表しているか説明してください。

- `mart.products_missing_category_anti`
- `mart.products_known_category_semi`
- `mart.product_price_rankings`
- `mart.monthly_price_long_example`

## 5. ローカル発展SQLを実行する

`make friendly-sql`、`make nested-json`、`make asof-join` を実行し、次を説明してください。

- `GROUP BY ALL` と `FILTER` が品質集計をどう読みやすくするか
- `UNNEST` がネストしたJSON配列をどう行へ展開するか
- `ASOF JOIN` が通常の等価JOINとどう違うか

## 提出物

- 2つの集計SQL
- 使うテーブルを選ぶ理由
- 高度な分析SQLの観察メモ
- ローカル発展SQLの観察メモ

## 進級チェック

分析SQLを書く前に、行の粒度、JOINの目的、横持ち/縦持ち、ネスト展開、時点結合の違いを確認できれば合格です。
