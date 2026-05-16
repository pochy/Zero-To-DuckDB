CREATE OR REPLACE TABLE staging.normalized_products AS
SELECT
  nullif(trim(jan_code), '') AS jan_code,
  nullif(trim(product_name), '') AS product_name,
  try_cast(nullif(trim(price), '') AS INTEGER) AS price,
  lower(nullif(trim(category_name), '')) AS category_name,
  nullif(trim(maker_name), '') AS maker_name,
  try_cast(ocr_confidence AS DOUBLE) AS ocr_confidence,
  try_cast(updated_at AS DATE) AS updated_at,
  filename AS source_file,
  nullif(trim(batch_id), '') AS batch_id,
  ingest_date::DATE AS ingest_date
FROM raw.products;

CREATE OR REPLACE TABLE staging.products_with_category AS
SELECT
  p.*,
  c.category_id
FROM staging.normalized_products p
LEFT JOIN master.categories c
  ON p.category_name = c.category_name;

CREATE OR REPLACE TABLE staging.latest_products AS
SELECT *
FROM (
  SELECT
    *,
    row_number() OVER (
      PARTITION BY jan_code
      ORDER BY ingest_date DESC, updated_at DESC, source_file DESC
    ) AS row_priority
  FROM staging.products_with_category
  WHERE jan_code IS NOT NULL
)
WHERE row_priority = 1;
