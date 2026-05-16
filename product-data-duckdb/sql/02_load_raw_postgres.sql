INSTALL excel;
LOAD excel;
INSTALL postgres;
LOAD postgres;

CREATE OR REPLACE TABLE raw.products_csv AS
SELECT *
FROM read_csv(
  'data/incoming/**/*.csv',
  header = true,
  union_by_name = true,
  filename = true,
  all_varchar = true
);

CREATE OR REPLACE TABLE raw.products_excel AS
SELECT
  *,
  'data/incoming/maker_c/catalog.xlsx' AS filename
FROM read_xlsx(
  'data/incoming/maker_c/catalog.xlsx',
  sheet = '商品一覧',
  header = true,
  all_varchar = true
);

CREATE OR REPLACE TABLE raw.products_json AS
SELECT
  product->>'jan_code' AS jan_code,
  product->>'name' AS product_name,
  product->>'price_text' AS price,
  product->>'category' AS category_name,
  maker->>'name' AS maker_name,
  extraction->>'confidence' AS ocr_confidence,
  extraction->>'updated_at' AS updated_at,
  filename
FROM read_json(
  'data/incoming/ai_ocr/*.jsonl',
  format = 'newline_delimited',
  filename = true
);

CREATE OR REPLACE TABLE raw.products AS
SELECT
  jan_code,
  product_name,
  price,
  category_name,
  maker_name,
  NULL AS ocr_confidence,
  updated_at,
  filename,
  'batch_2026_05_10' AS batch_id,
  DATE '2026-05-10' AS ingest_date
FROM raw.products_csv

UNION ALL

SELECT
  jan_code,
  product_name,
  price,
  category_name,
  maker_name,
  NULL AS ocr_confidence,
  updated_at,
  filename,
  'batch_2026_05_10' AS batch_id,
  DATE '2026-05-10' AS ingest_date
FROM raw.products_excel

UNION ALL

SELECT
  jan_code,
  product_name,
  price,
  category_name,
  maker_name,
  ocr_confidence,
  updated_at,
  filename,
  'batch_2026_05_10' AS batch_id,
  DATE '2026-05-10' AS ingest_date
FROM raw.products_json;

ATTACH 'dbname=duckdb_tutorial user=duckdb password=duckdb host=localhost port=55433' AS master_pg (TYPE postgres, READ_ONLY);

CREATE OR REPLACE TABLE master.categories AS
SELECT
  category_id::INTEGER AS category_id,
  lower(trim(category_name)) AS category_name
FROM master_pg.categories;
