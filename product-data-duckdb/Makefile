DB := product_pipeline.duckdb
DUCKDB := duckdb

.PHONY: samples run postgres-up postgres-run minio-up minio-seed s3-read serve-output http-read quality check-json check-node report profile advanced friendly-sql nested-json asof-join export-lab perf-lab notebook-check test test-advanced test-local-ecosystem export clean check-duckdb

samples:
	python3 scripts/create_excel_sample.py
	python3 scripts/create_sqlite_master.py

run: samples check-duckdb
	$(DUCKDB) $(DB) < sql/01_create_schemas.sql
	$(DUCKDB) $(DB) < sql/02_load_raw.sql
	$(DUCKDB) $(DB) < sql/03_normalize.sql
	$(DUCKDB) $(DB) < sql/04_quality_checks.sql
	$(DUCKDB) $(DB) < sql/05_export_parquet.sql

postgres-up:
	docker-compose up -d postgres
	python3 scripts/wait_for_port.py 127.0.0.1 55433

postgres-run: samples postgres-up check-duckdb
	$(DUCKDB) $(DB) < sql/01_create_schemas.sql
	$(DUCKDB) $(DB) < sql/02_load_raw_postgres.sql
	$(DUCKDB) $(DB) < sql/03_normalize.sql
	$(DUCKDB) $(DB) < sql/04_quality_checks.sql
	$(DUCKDB) $(DB) < sql/05_export_parquet.sql

minio-up:
	docker-compose up -d minio
	python3 scripts/wait_for_port.py 127.0.0.1 9000

minio-seed: minio-up
	docker-compose run --rm minio-seed

s3-read: minio-seed check-duckdb
	$(DUCKDB) $(DB) < sql/08_read_s3_parquet.sql

serve-output:
	python3 scripts/serve_output.py

http-read: check-duckdb
	$(DUCKDB) $(DB) < sql/07_read_http_parquet.sql

quality: check-duckdb
	$(DUCKDB) $(DB) -c "SELECT * FROM mart.quality_report ORDER BY check_name;"

check-json: check-duckdb
	python3 scripts/check_quality.py --db $(DB)

check-node: check-duckdb
	node scripts/check-quality.mjs --db $(DB)

report:
	python3 scripts/create_quality_report.py

profile: check-duckdb
	$(DUCKDB) $(DB) < sql/06_explain_parquet.sql > reports/parquet_explain.txt

advanced: check-duckdb
	$(DUCKDB) $(DB) < sql/09_advanced_analytics.sql
	$(DUCKDB) $(DB) < sql/10_dimensional_model.sql
	$(DUCKDB) $(DB) < sql/12_tax_normalization_example.sql

friendly-sql: check-duckdb
	$(DUCKDB) $(DB) < sql/13_friendly_sql.sql

nested-json: check-duckdb
	$(DUCKDB) $(DB) < sql/14_nested_json_unnest.sql

asof-join: check-duckdb
	$(DUCKDB) $(DB) < sql/15_asof_join.sql

export-lab: check-duckdb
	$(DUCKDB) $(DB) < sql/16_export_options.sql

perf-lab: check-duckdb
	$(DUCKDB) $(DB) < sql/11_performance_lab.sql > reports/perf_lab.txt

notebook-check:
	python3 scripts/check_notebook.py

test: check-duckdb
	$(DUCKDB) $(DB) < tests/test_pipeline.sql

test-advanced: check-duckdb
	$(DUCKDB) $(DB) < tests/test_advanced_topics.sql

test-local-ecosystem: check-duckdb
	$(DUCKDB) $(DB) < tests/test_local_advanced_sql.sql

export: check-duckdb
	$(DUCKDB) $(DB) < sql/05_export_parquet.sql

clean:
	rm -f $(DB) $(DB).wal reports/*.csv reports/*.html reports/*.txt output/*.parquet
	rm -f data/master/master.sqlite
	rm -rf output/products_by_category
	rm -rf output/products_by_ingest_date
	rm -rf output/products_per_thread

check-duckdb:
	@command -v $(DUCKDB) >/dev/null 2>&1 || { \
		echo "duckdb CLI is not installed. Install it with: brew install duckdb"; \
		exit 1; \
	}
