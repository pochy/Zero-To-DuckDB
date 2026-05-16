EXPLAIN ANALYZE
SELECT
  category_name,
  count(*) AS product_count,
  avg(price) AS avg_price
FROM read_parquet(
  'output/products_by_category/**/*.parquet',
  hive_partitioning = true
)
WHERE category_name = 'food'
GROUP BY category_name;

EXPLAIN ANALYZE
SELECT
  maker_name,
  count(*) AS product_count
FROM read_parquet(
  'output/products_by_category/**/*.parquet',
  hive_partitioning = true
)
WHERE price >= 1000
GROUP BY maker_name
ORDER BY product_count DESC;
