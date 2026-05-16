COPY (
  SELECT *
  FROM staging.latest_products
  WHERE product_name IS NOT NULL
    AND price IS NOT NULL
    AND price >= 0
    AND category_id IS NOT NULL
)
TO 'output/products_snappy.parquet'
(FORMAT parquet, COMPRESSION snappy);

COPY (
  SELECT *
  FROM staging.latest_products
  WHERE product_name IS NOT NULL
    AND price IS NOT NULL
    AND price >= 0
    AND category_id IS NOT NULL
)
TO 'output/products_per_thread'
(FORMAT parquet, COMPRESSION snappy, PER_THREAD_OUTPUT true, OVERWRITE_OR_IGNORE true);

CREATE OR REPLACE TABLE mart.export_option_summary AS
SELECT
  'snappy_single_file' AS export_name,
  count(*) AS row_count
FROM read_parquet('output/products_snappy.parquet')

UNION ALL

SELECT
  'snappy_per_thread' AS export_name,
  count(*) AS row_count
FROM read_parquet('output/products_per_thread/*.parquet');

SELECT 'export option examples created' AS status;
