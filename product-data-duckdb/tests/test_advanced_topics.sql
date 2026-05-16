SELECT
  CASE
    WHEN (SELECT count(*) FROM mart.products_missing_category_anti) = 4
      THEN 'PASS: anti join finds unknown categories'
    ELSE error('FAIL: anti join unknown category count mismatch')
  END AS result;

SELECT
  CASE
    WHEN (SELECT count(*) FROM mart.monthly_price_long_example) = 9
      THEN 'PASS: unpivot produced monthly long rows'
    ELSE error('FAIL: unpivot row count mismatch')
  END AS result;

SELECT
  CASE
    WHEN (SELECT count(*) FROM mart.dim_product) = 15
      THEN 'PASS: dim_product has expected known-category products'
    ELSE error('FAIL: dim_product row count mismatch')
  END AS result;

SELECT
  CASE
    WHEN (SELECT count(*) FROM mart.fact_product_price) = 12
      THEN 'PASS: fact_product_price has expected valid price observations'
    ELSE error('FAIL: fact_product_price row count mismatch')
  END AS result;

SELECT
  CASE
    WHEN (
      SELECT count(*)
      FROM mart.tax_normalization_review
      WHERE review_status = 'requires_input_contract'
    ) = 1
      THEN 'PASS: tax normalization flags unknown policy'
    ELSE error('FAIL: tax normalization review mismatch')
  END AS result;
