CREATE OR REPLACE TABLE mart.auto_reader_probe AS
SELECT
  'csv_auto' AS reader,
  count(*) AS row_count
FROM read_csv_auto('data/incoming/maker_a/products.csv')

UNION ALL

SELECT
  'json_auto' AS reader,
  count(*) AS row_count
FROM read_json_auto(
  'data/incoming/ai_ocr/*.jsonl',
  format = 'newline_delimited'
);

CREATE OR REPLACE TABLE mart.friendly_clean_products AS
SELECT
  * EXCLUDE (source_file)
  REPLACE (
    coalesce(price, 0) AS price,
    lower(category_name) AS category_name
  )
FROM staging.normalized_products;

CREATE OR REPLACE TABLE mart.numeric_column_profile AS
SELECT
  avg(COLUMNS('price|ocr_confidence'))
FROM staging.normalized_products;

CREATE OR REPLACE TABLE mart.category_quality_summary AS
SELECT
  category_name,
  count(*) AS row_count,
  count(*) FILTER (WHERE price IS NULL OR price < 0) AS invalid_price_rows,
  count(*) FILTER (WHERE jan_code IS NULL) AS missing_jan_rows,
  count(*) FILTER (WHERE ocr_confidence IS NOT NULL AND ocr_confidence < 0.80) AS low_ocr_confidence_rows
FROM staging.normalized_products
GROUP BY ALL;

CREATE OR REPLACE TABLE mart.normalized_profile AS
SELECT *
FROM (
  SUMMARIZE SELECT * FROM staging.normalized_products
);

SELECT 'friendly SQL examples created' AS status;
