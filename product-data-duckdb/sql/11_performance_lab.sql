CREATE SCHEMA IF NOT EXISTS perf;

SET preserve_insertion_order = false;
SET threads = 4;
SET memory_limit = '1GB';

CREATE OR REPLACE TABLE perf.synthetic_products AS
SELECT
  range AS product_row_id,
  'jan_' || lpad((range % 25000)::VARCHAR, 8, '0') AS jan_code,
  CASE range % 5
    WHEN 0 THEN 'food'
    WHEN 1 THEN 'electronics'
    WHEN 2 THEN 'stationery'
    WHEN 3 THEN 'beauty'
    ELSE 'household'
  END AS category_name,
  (range % 5000) + 100 AS price,
  DATE '2026-01-01' + ((range % 120)::INTEGER) AS updated_at
FROM range(100000);

COPY perf.synthetic_products
TO 'output/perf_synthetic_products.parquet'
(FORMAT parquet, COMPRESSION zstd);

EXPLAIN ANALYZE
SELECT
  category_name,
  count(*) AS row_count,
  avg(price) AS avg_price
FROM read_parquet('output/perf_synthetic_products.parquet')
WHERE category_name IN ('food', 'electronics')
GROUP BY category_name;

EXPLAIN ANALYZE
SELECT
  category_name,
  updated_at,
  sum(price) OVER (
    PARTITION BY category_name
    ORDER BY updated_at
    ROWS BETWEEN 20 PRECEDING AND CURRENT ROW
  ) AS rolling_price_sum
FROM perf.synthetic_products
QUALIFY row_number() OVER (
  PARTITION BY category_name
  ORDER BY updated_at
) <= 20;
