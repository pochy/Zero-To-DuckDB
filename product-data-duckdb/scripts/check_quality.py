#!/usr/bin/env python3
import argparse
import json
import shutil
import subprocess
from pathlib import Path


DEFAULT_DB = Path("product_pipeline.duckdb")


def run_duckdb_json(db_path: Path, sql: str) -> list[dict[str, object]]:
    duckdb = shutil.which("duckdb")
    if duckdb is None:
        raise SystemExit("duckdb CLI is not installed. Install it with: brew install duckdb")

    result = subprocess.run(
        [duckdb, "-json", str(db_path), "-c", sql],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        raise SystemExit(result.stderr.strip())
    return json.loads(result.stdout)


def main() -> int:
    parser = argparse.ArgumentParser(description="Return DuckDB product data quality checks as JSON.")
    parser.add_argument("--db", default=str(DEFAULT_DB), help="Path to the DuckDB database file.")
    parser.add_argument(
        "--max-errors",
        type=int,
        default=None,
        help="Exit with code 1 when total reported errors exceed this value.",
    )
    parser.add_argument(
        "--fail-on-any-error",
        action="store_true",
        help="Exit with code 1 when any quality check has errors.",
    )
    args = parser.parse_args()

    db_path = Path(args.db)
    if not db_path.exists():
        raise SystemExit(f"Database not found: {db_path}. Run make run first.")

    quality_rows = run_duckdb_json(
        db_path,
        "SELECT check_name, error_count FROM mart.quality_report ORDER BY check_name;",
    )
    exported_rows = run_duckdb_json(
        db_path,
        "SELECT count(*) AS exported_rows FROM read_parquet('output/products.parquet');",
    )[0]["exported_rows"]
    dataset_rows = run_duckdb_json(
        db_path,
        "SELECT count(*) AS dataset_rows FROM read_parquet('output/products_by_category/**/*.parquet', hive_partitioning = true);",
    )[0]["dataset_rows"]
    ingest_dataset_rows = run_duckdb_json(
        db_path,
        "SELECT count(*) AS ingest_dataset_rows FROM read_parquet('output/products_by_ingest_date/**/*.parquet', hive_partitioning = true);",
    )[0]["ingest_dataset_rows"]

    checks = {
        str(row["check_name"]): int(row["error_count"])
        for row in quality_rows
    }
    total_errors = sum(checks.values())
    failing_checks = {
        check_name: count
        for check_name, count in checks.items()
        if count > 0
    }

    ok = True
    reasons = []
    if args.fail_on_any_error and total_errors > 0:
        ok = False
        reasons.append("quality_errors_present")
    if args.max_errors is not None and total_errors > args.max_errors:
        ok = False
        reasons.append("max_errors_exceeded")

    payload = {
        "ok": ok,
        "totalErrors": total_errors,
        "failingCheckCount": len(failing_checks),
        "exportedRows": exported_rows,
        "datasetRows": dataset_rows,
        "ingestDatasetRows": ingest_dataset_rows,
        "checks": checks,
        "failingChecks": failing_checks,
        "failureReasons": reasons,
    }
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
