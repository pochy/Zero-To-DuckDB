WITH expected(check_name, expected_count) AS (
  VALUES
    ('duplicate_jan_code', 1),
    ('invalid_price', 4),
    ('low_ocr_confidence', 2),
    ('missing_jan_code', 2),
    ('missing_product_name', 0),
    ('unknown_category', 4)
),
actual AS (
  SELECT check_name, error_count
  FROM mart.quality_report
),
failures AS (
  SELECT
    e.check_name,
    e.expected_count,
    coalesce(a.error_count, -1) AS actual_count
  FROM expected e
  LEFT JOIN actual a
    ON e.check_name = a.check_name
  WHERE coalesce(a.error_count, -1) != e.expected_count
)
SELECT
  CASE
    WHEN count(*) = 0 THEN 'PASS: quality report counts match expected values'
    ELSE error(
      'FAIL: quality report mismatch: ' ||
      string_agg(check_name || ' expected ' || expected_count || ' actual ' || actual_count, '; ')
    )
  END AS result
FROM failures;

WITH exported AS (
  SELECT count(*) AS exported_rows
  FROM read_parquet('output/products.parquet')
)
SELECT
  CASE
    WHEN exported_rows = 11 THEN 'PASS: exported row count is 11'
    ELSE error('FAIL: exported row count expected 11 actual ' || exported_rows)
  END AS result
FROM exported;

WITH invalid_export AS (
  SELECT count(*) AS invalid_rows
  FROM read_parquet('output/products.parquet')
  WHERE jan_code IS NULL
     OR product_name IS NULL
     OR price IS NULL
     OR price < 0
     OR category_id IS NULL
)
SELECT
  CASE
    WHEN invalid_rows = 0 THEN 'PASS: exported Parquet contains only valid rows'
    ELSE error('FAIL: exported Parquet has invalid rows: ' || invalid_rows)
  END AS result
FROM invalid_export;

WITH batch_columns AS (
  SELECT
    count(DISTINCT batch_id) AS batch_count,
    min(ingest_date) AS min_ingest_date,
    max(ingest_date) AS max_ingest_date
  FROM read_parquet('output/products.parquet')
)
SELECT
  CASE
    WHEN batch_count = 1
     AND min_ingest_date = DATE '2026-05-10'
     AND max_ingest_date = DATE '2026-05-10'
      THEN 'PASS: exported Parquet includes expected batch metadata'
    ELSE error('FAIL: exported Parquet batch metadata mismatch')
  END AS result
FROM batch_columns;

WITH dataset_exported AS (
  SELECT count(*) AS exported_rows
  FROM read_parquet('output/products_by_category/**/*.parquet', hive_partitioning = true)
)
SELECT
  CASE
    WHEN exported_rows = 11 THEN 'PASS: partitioned dataset row count is 11'
    ELSE error('FAIL: partitioned dataset row count expected 11 actual ' || exported_rows)
  END AS result
FROM dataset_exported;

WITH dataset_categories AS (
  SELECT string_agg(category_name, ',' ORDER BY category_name) AS categories
  FROM (
    SELECT DISTINCT category_name
    FROM read_parquet('output/products_by_category/**/*.parquet', hive_partitioning = true)
  )
)
SELECT
  CASE
    WHEN categories = 'beauty,electronics,food,stationery'
      THEN 'PASS: partitioned dataset has expected categories'
    ELSE error('FAIL: partitioned dataset categories mismatch: ' || categories)
  END AS result
FROM dataset_categories;

WITH ingest_dataset_exported AS (
  SELECT
    count(*) AS exported_rows,
    count(DISTINCT ingest_date) AS ingest_date_count,
    min(ingest_date) AS min_ingest_date,
    max(ingest_date) AS max_ingest_date
  FROM read_parquet('output/products_by_ingest_date/**/*.parquet', hive_partitioning = true)
)
SELECT
  CASE
    WHEN exported_rows = 11
     AND ingest_date_count = 1
     AND min_ingest_date = DATE '2026-05-10'
     AND max_ingest_date = DATE '2026-05-10'
      THEN 'PASS: ingest-date partitioned dataset is valid'
    ELSE error('FAIL: ingest-date partitioned dataset mismatch')
  END AS result
FROM ingest_dataset_exported;
