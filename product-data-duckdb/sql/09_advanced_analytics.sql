CREATE OR REPLACE TABLE mart.products_missing_category_anti AS
SELECT
  p.jan_code,
  p.product_name,
  p.category_name,
  p.source_file
FROM staging.normalized_products p
ANTI JOIN master.categories c
  ON p.category_name = c.category_name
WHERE p.category_name IS NOT NULL;

CREATE OR REPLACE TABLE mart.products_known_category_semi AS
SELECT
  p.jan_code,
  p.product_name,
  p.category_name,
  p.price
FROM staging.normalized_products p
SEMI JOIN master.categories c
  ON p.category_name = c.category_name;

CREATE OR REPLACE TABLE mart.product_price_rankings AS
SELECT
  jan_code,
  product_name,
  category_name,
  maker_name,
  price,
  rank() OVER (
    PARTITION BY category_name
    ORDER BY price DESC NULLS LAST
  ) AS category_price_rank,
  lag(price) OVER (
    PARTITION BY category_name
    ORDER BY updated_at, product_name
  ) AS previous_price_in_category,
  lead(price) OVER (
    PARTITION BY category_name
    ORDER BY updated_at, product_name
  ) AS next_price_in_category,
  avg(price) OVER (
    PARTITION BY category_name
    ORDER BY updated_at, product_name
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ) AS moving_average_price
FROM staging.products_with_category
WHERE price IS NOT NULL
  AND price >= 0
  AND category_id IS NOT NULL;

CREATE OR REPLACE TABLE mart.monthly_price_wide_example AS
SELECT *
FROM (
  VALUES
    ('4900000000011', 1200, 1180, 1210),
    ('4900000000042', 980, 990, 970),
    ('4900000000103', 150, 155, 160)
) AS t(jan_code, price_202601, price_202602, price_202603);

CREATE OR REPLACE TABLE mart.monthly_price_long_example AS
UNPIVOT mart.monthly_price_wide_example
ON price_202601, price_202602, price_202603
INTO
  NAME price_month
  VALUE price;

SELECT 'advanced analytics tables created' AS status;
