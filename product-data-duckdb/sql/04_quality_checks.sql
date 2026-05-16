CREATE OR REPLACE TABLE mart.quality_report AS
SELECT 'missing_jan_code' AS check_name, count(*) AS error_count
FROM staging.products_with_category
WHERE jan_code IS NULL

UNION ALL

SELECT 'missing_product_name' AS check_name, count(*) AS error_count
FROM staging.products_with_category
WHERE product_name IS NULL

UNION ALL

SELECT 'invalid_price' AS check_name, count(*) AS error_count
FROM staging.products_with_category
WHERE price IS NULL OR price < 0

UNION ALL

SELECT 'unknown_category' AS check_name, count(*) AS error_count
FROM staging.products_with_category
WHERE category_id IS NULL

UNION ALL

SELECT 'duplicate_jan_code' AS check_name, count(*) AS error_count
FROM (
  SELECT jan_code
  FROM staging.products_with_category
  WHERE jan_code IS NOT NULL
  GROUP BY jan_code
  HAVING count(*) > 1
)

UNION ALL

SELECT 'low_ocr_confidence' AS check_name, count(*) AS error_count
FROM staging.products_with_category
WHERE ocr_confidence IS NOT NULL
  AND ocr_confidence < 0.80;

CREATE OR REPLACE TABLE mart.product_errors AS
SELECT
  *,
  concat_ws(
    ',',
    CASE WHEN jan_code IS NULL THEN 'missing_jan_code' END,
    CASE WHEN product_name IS NULL THEN 'missing_product_name' END,
    CASE WHEN price IS NULL OR price < 0 THEN 'invalid_price' END,
    CASE WHEN category_id IS NULL THEN 'unknown_category' END
  ) AS error_reasons
FROM staging.products_with_category
WHERE jan_code IS NULL
   OR product_name IS NULL
   OR price IS NULL
   OR price < 0
   OR category_id IS NULL;
