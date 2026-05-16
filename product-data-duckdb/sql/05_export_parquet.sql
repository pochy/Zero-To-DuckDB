COPY (
  SELECT
    jan_code,
    product_name,
    price,
    category_id,
    category_name,
    maker_name,
    ocr_confidence,
    updated_at,
    source_file,
    batch_id,
    ingest_date
  FROM staging.latest_products
  WHERE product_name IS NOT NULL
    AND price IS NOT NULL
    AND price >= 0
    AND category_id IS NOT NULL
)
TO 'output/products.parquet'
(FORMAT parquet, COMPRESSION zstd);

COPY (
  SELECT
    jan_code,
    product_name,
    price,
    category_id,
    category_name,
    maker_name,
    ocr_confidence,
    updated_at,
    source_file,
    batch_id,
    ingest_date
  FROM staging.latest_products
  WHERE product_name IS NOT NULL
    AND price IS NOT NULL
    AND price >= 0
    AND category_id IS NOT NULL
)
TO 'output/products_by_category'
(FORMAT parquet, COMPRESSION zstd, PARTITION_BY (category_name), OVERWRITE_OR_IGNORE true);

COPY (
  SELECT
    jan_code,
    product_name,
    price,
    category_id,
    category_name,
    maker_name,
    ocr_confidence,
    updated_at,
    source_file,
    batch_id,
    ingest_date
  FROM staging.latest_products
  WHERE product_name IS NOT NULL
    AND price IS NOT NULL
    AND price >= 0
    AND category_id IS NOT NULL
)
TO 'output/products_by_ingest_date'
(FORMAT parquet, COMPRESSION zstd, PARTITION_BY (ingest_date, category_name), OVERWRITE_OR_IGNORE true);

COPY mart.quality_report
TO 'reports/quality_report.csv'
(HEADER, DELIMITER ',');

COPY mart.product_errors
TO 'reports/product_errors.csv'
(HEADER, DELIMITER ',');
