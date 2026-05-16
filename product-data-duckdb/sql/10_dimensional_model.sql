CREATE OR REPLACE TABLE mart.dim_maker AS
SELECT
  row_number() OVER (ORDER BY maker_name) AS maker_id,
  maker_name
FROM (
  SELECT DISTINCT maker_name
  FROM staging.products_with_category
  WHERE maker_name IS NOT NULL
);

CREATE OR REPLACE TABLE mart.dim_category AS
SELECT
  category_id,
  category_name
FROM master.categories;

CREATE OR REPLACE TABLE mart.dim_product AS
SELECT
  jan_code,
  any_value(product_name) AS product_name,
  any_value(category_id) AS category_id,
  min(updated_at) AS first_seen_at,
  max(updated_at) AS last_seen_at
FROM staging.latest_products
WHERE jan_code IS NOT NULL
  AND product_name IS NOT NULL
  AND category_id IS NOT NULL
GROUP BY jan_code;

CREATE OR REPLACE TABLE mart.fact_product_price AS
SELECT
  p.jan_code,
  m.maker_id,
  p.category_id,
  p.price,
  p.updated_at,
  p.batch_id,
  p.ingest_date,
  p.source_file
FROM staging.products_with_category p
JOIN mart.dim_maker m
  ON p.maker_name = m.maker_name
WHERE p.jan_code IS NOT NULL
  AND p.product_name IS NOT NULL
  AND p.price IS NOT NULL
  AND p.price >= 0
  AND p.category_id IS NOT NULL;

CREATE OR REPLACE TABLE mart.dim_product_scd_example AS
SELECT
  jan_code,
  product_name,
  category_id,
  updated_at AS valid_from,
  lead(updated_at) OVER (
    PARTITION BY jan_code
    ORDER BY updated_at
  ) AS valid_to,
  lead(updated_at) OVER (
    PARTITION BY jan_code
    ORDER BY updated_at
  ) IS NULL AS is_current
FROM staging.products_with_category
WHERE jan_code IS NOT NULL
  AND product_name IS NOT NULL
  AND category_id IS NOT NULL;

SELECT 'dimensional model tables created' AS status;
