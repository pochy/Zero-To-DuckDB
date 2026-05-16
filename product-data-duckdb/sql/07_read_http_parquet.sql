INSTALL httpfs;
LOAD httpfs;

CREATE OR REPLACE VIEW mart.http_products AS
SELECT *
FROM read_parquet([
  'http://127.0.0.1:8000/products_by_category/category_name=beauty/data_0.parquet',
  'http://127.0.0.1:8000/products_by_category/category_name=electronics/data_0.parquet',
  'http://127.0.0.1:8000/products_by_category/category_name=food/data_0.parquet',
  'http://127.0.0.1:8000/products_by_category/category_name=stationery/data_0.parquet'
], hive_partitioning = true);

SELECT
  category_name,
  count(*) AS product_count,
  avg(price) AS avg_price
FROM mart.http_products
GROUP BY category_name
ORDER BY category_name;

SELECT
  CASE
    WHEN count(*) = 11 THEN 'PASS: HTTP Parquet dataset row count is 11'
    ELSE error('FAIL: HTTP Parquet dataset row count expected 11 actual ' || count(*))
  END AS result
FROM mart.http_products;

CREATE OR REPLACE VIEW mart.http_products_by_ingest_date AS
SELECT *
FROM read_parquet([
  'http://127.0.0.1:8000/products_by_ingest_date/ingest_date=2026-05-10/category_name=beauty/data_0.parquet',
  'http://127.0.0.1:8000/products_by_ingest_date/ingest_date=2026-05-10/category_name=electronics/data_0.parquet',
  'http://127.0.0.1:8000/products_by_ingest_date/ingest_date=2026-05-10/category_name=food/data_0.parquet',
  'http://127.0.0.1:8000/products_by_ingest_date/ingest_date=2026-05-10/category_name=stationery/data_0.parquet'
], hive_partitioning = true);

SELECT
  ingest_date,
  category_name,
  count(*) AS product_count
FROM mart.http_products_by_ingest_date
GROUP BY ingest_date, category_name
ORDER BY ingest_date, category_name;
