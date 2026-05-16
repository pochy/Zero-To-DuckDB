INSTALL httpfs;
LOAD httpfs;

SET s3_region = 'us-east-1';
SET s3_endpoint = '127.0.0.1:9000';
SET s3_access_key_id = 'minioadmin';
SET s3_secret_access_key = 'minioadmin';
SET s3_url_style = 'path';
SET s3_use_ssl = false;

CREATE OR REPLACE VIEW mart.s3_products AS
SELECT *
FROM read_parquet([
  's3://duckdb-tutorial/products_by_category/category_name=beauty/data_0.parquet',
  's3://duckdb-tutorial/products_by_category/category_name=electronics/data_0.parquet',
  's3://duckdb-tutorial/products_by_category/category_name=food/data_0.parquet',
  's3://duckdb-tutorial/products_by_category/category_name=stationery/data_0.parquet'
], hive_partitioning = true);

SELECT
  category_name,
  count(*) AS product_count,
  avg(price) AS avg_price
FROM mart.s3_products
GROUP BY category_name
ORDER BY category_name;

SELECT
  CASE
    WHEN count(*) = 11 THEN 'PASS: S3 Parquet dataset row count is 11'
    ELSE error('FAIL: S3 Parquet dataset row count expected 11 actual ' || count(*))
  END AS result
FROM mart.s3_products;

CREATE OR REPLACE VIEW mart.s3_products_by_ingest_date AS
SELECT *
FROM read_parquet([
  's3://duckdb-tutorial/products_by_ingest_date/ingest_date=2026-05-10/category_name=beauty/data_0.parquet',
  's3://duckdb-tutorial/products_by_ingest_date/ingest_date=2026-05-10/category_name=electronics/data_0.parquet',
  's3://duckdb-tutorial/products_by_ingest_date/ingest_date=2026-05-10/category_name=food/data_0.parquet',
  's3://duckdb-tutorial/products_by_ingest_date/ingest_date=2026-05-10/category_name=stationery/data_0.parquet'
], hive_partitioning = true);

SELECT
  ingest_date,
  category_name,
  count(*) AS product_count
FROM mart.s3_products_by_ingest_date
GROUP BY ingest_date, category_name
ORDER BY ingest_date, category_name;
