CREATE OR REPLACE TABLE mart.tax_normalization_example AS
SELECT *
FROM (
  VALUES
    ('4900000000011', 'Coffee Beans 200g', 1200, 'tax_included'),
    ('4900000000042', 'USB-C Cable', 980, 'tax_excluded'),
    ('4900000000103', 'Ballpoint Pen', 150, 'unknown')
) AS t(jan_code, product_name, input_price, tax_policy);

CREATE OR REPLACE TABLE mart.tax_normalization_review AS
SELECT
  jan_code,
  product_name,
  input_price,
  tax_policy,
  CASE tax_policy
    WHEN 'tax_included' THEN input_price
    WHEN 'tax_excluded' THEN round(input_price * 1.10)::INTEGER
  END AS comparable_tax_included_price,
  CASE
    WHEN tax_policy = 'unknown' THEN 'requires_input_contract'
    ELSE 'calculated_by_declared_policy'
  END AS review_status
FROM mart.tax_normalization_example;

SELECT 'tax normalization example created' AS status;
