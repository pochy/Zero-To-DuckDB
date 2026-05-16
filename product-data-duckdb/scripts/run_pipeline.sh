#!/usr/bin/env sh
set -eu

duckdb product_pipeline.duckdb < sql/01_create_schemas.sql
duckdb product_pipeline.duckdb < sql/02_load_raw.sql
duckdb product_pipeline.duckdb < sql/03_normalize.sql
duckdb product_pipeline.duckdb < sql/04_quality_checks.sql
duckdb product_pipeline.duckdb < sql/05_export_parquet.sql
