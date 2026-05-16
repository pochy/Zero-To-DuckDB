# DuckDB Product Data Pipeline

This is the first runnable slice of the DuckDB tutorial. It ingests messy product CSV, Excel, and JSON Lines files, normalizes them, runs quality checks, and exports clean data to Parquet.
The default category master is generated as a SQLite database and attached from DuckDB to demonstrate external database ingestion without running a server. A PostgreSQL-backed variant is also included for the next step toward production-style master data.

Tutorial links:

- Start from `../START_HERE.md` if this is your first run.
- Read `../parts/part_11_final_project/README.md` for the final project walkthrough.
- Use `../TUTORIAL.md` as the full curriculum index.

## Prerequisites

Install the DuckDB CLI:

```bash
brew install duckdb
```

## Run

```bash
make run
make quality
make check-json
make check-node
make report
make profile
make advanced
make friendly-sql
make nested-json
make asof-join
make export-lab
make perf-lab
make notebook-check
make test
make test-advanced
make test-local-ecosystem
```

Recommended reading order after the first run:

1. `Makefile`
2. `sql/01_create_schemas.sql`
3. `sql/02_load_raw.sql`
4. `sql/03_normalize.sql`
5. `sql/04_quality_checks.sql`
6. `sql/05_export_parquet.sql`
7. `sql/09_advanced_analytics.sql`
8. `sql/10_dimensional_model.sql`
9. `sql/13_friendly_sql.sql`
10. `sql/14_nested_json_unnest.sql`
11. `sql/15_asof_join.sql`
12. `sql/16_export_options.sql`
13. `tests/test_pipeline.sql`
14. `tests/test_advanced_topics.sql`
15. `tests/test_local_advanced_sql.sql`
16. `scripts/check_quality.py`
17. `scripts/check-quality.mjs`

Open the analysis notebook after generating outputs:

```bash
jupyter notebook notebooks/quality_analysis.ipynb
```

Read the exported Parquet dataset over HTTP:

```bash
make serve-output
```

In another terminal:

```bash
make http-read
```

Read the exported Parquet dataset from local S3-compatible object storage:

```bash
make s3-read
```

This starts MinIO on `localhost:9000`, mirrors the exported Parquet datasets into `s3://duckdb-tutorial/`, and reads them with DuckDB `httpfs`.

## PostgreSQL Master Variant

Run the same pipeline with the category master loaded from PostgreSQL:

```bash
make postgres-run
make quality
make test
```

This starts `postgres:16-alpine` on local port `55433`, seeds `categories`, and reads it from DuckDB with:

```sql
ATTACH 'dbname=duckdb_tutorial user=duckdb password=duckdb host=localhost port=55433'
AS master_pg (TYPE postgres, READ_ONLY);
```

Generated files:

- `product_pipeline.duckdb`
- `data/master/master.sqlite`
- `reports/quality_report.csv`
- `reports/product_errors.csv`
- `reports/quality_report.html`
- `reports/parquet_explain.txt`
- `output/products.parquet`
- `output/products_by_category/`
- `output/products_by_ingest_date/`
- `notebooks/quality_analysis.ipynb`

## Quality CLI

Return quality checks as JSON:

```bash
python3 scripts/check_quality.py
```

Fail when any quality check has errors:

```bash
python3 scripts/check_quality.py --fail-on-any-error
```

Fail when total reported errors exceed a threshold:

```bash
python3 scripts/check_quality.py --max-errors 20
```

The same check is also available from Node.js for application integration:

```bash
node scripts/check-quality.mjs
node scripts/check-quality.mjs --max-errors 20
```

## Advanced Topics

Run the optional advanced SQL examples after `make run`:

```bash
make advanced
make friendly-sql
make nested-json
make asof-join
make export-lab
make test-advanced
make test-local-ecosystem
make perf-lab
```

`make advanced` creates example mart tables for `ANTI JOIN`, `SEMI JOIN`, ranking, `lag`, `lead`, moving average, `UNPIVOT`, dimensional modeling, SCD-style history, and tax normalization review. `make perf-lab` writes `reports/perf_lab.txt` with `EXPLAIN ANALYZE` output over a synthetic Parquet workload.

The local ecosystem targets add DuckDB-specific SQL examples for auto readers, `SELECT * EXCLUDE`, `SELECT * REPLACE`, `COLUMNS`, `GROUP BY ALL`, `FILTER`, `SUMMARIZE`, `UNNEST`, `ASOF JOIN`, Snappy Parquet, and `PER_THREAD_OUTPUT true`.

## What This Covers

- Read multiple CSV files with `read_csv`
- Inspect files quickly with `read_csv_auto` and `read_json_auto`
- Read Excel files with `read_xlsx`
- Read nested JSON Lines files with `read_json`
- Attach a SQLite master database with `ATTACH ... TYPE sqlite`
- Attach a PostgreSQL master database with `ATTACH ... TYPE postgres`
- Preserve the source filename
- Normalize strings, categories, dates, and prices
- Detect missing JAN codes, invalid prices, unknown categories, duplicate JAN codes, and low OCR confidence
- Keep the latest row per JAN code
- Preserve OCR confidence as a warning signal without excluding otherwise valid products
- Export valid data to compressed Parquet
- Export a partitioned Parquet dataset by `category_name`
- Export an ingest-date partitioned dataset for batch-oriented processing
- Inspect partitioned Parquet reads with `EXPLAIN ANALYZE`
- Read the exported Parquet dataset over HTTP with `httpfs`
- Read the exported Parquet dataset from S3-compatible storage with `httpfs`
- Fail fast when expected quality counts or exported rows drift
- Generate a dependency-free HTML quality report from exported CSV files
- Inspect the generated reports and Parquet outputs in a notebook
- Return quality results as JSON for CLI or application integration
- Call the same quality checks from Node.js without extra npm packages
- Explore advanced SQL and dimensional modeling with optional Makefile targets
- Explore local-only DuckDB SQL conveniences and export options without cloud services

## Intended Next Extensions

Add one source type at a time:

1. Multiple input batches with different `batch_id` values
2. More realistic PostgreSQL product and price history tables
3. Web API wrapper around the quality CLI
4. Direct `@duckdb/node-api` integration for applications that want an in-process Node.js client
