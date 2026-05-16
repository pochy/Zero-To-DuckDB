#!/usr/bin/env node
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";

const DEFAULT_DB = "product_pipeline.duckdb";

function parseArgs(argv) {
  const args = {
    db: DEFAULT_DB,
    maxErrors: null,
    failOnAnyError: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--db") {
      args.db = argv[++i];
    } else if (arg === "--max-errors") {
      args.maxErrors = Number.parseInt(argv[++i], 10);
      if (Number.isNaN(args.maxErrors)) {
        throw new Error("--max-errors must be an integer");
      }
    } else if (arg === "--fail-on-any-error") {
      args.failOnAnyError = true;
    } else if (arg === "--help" || arg === "-h") {
      args.help = true;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return args;
}

function printHelp() {
  console.log(`Usage: node scripts/check-quality.mjs [options]

Options:
  --db <path>             Path to the DuckDB database file
  --max-errors <number>   Exit 1 when total reported errors exceed this value
  --fail-on-any-error     Exit 1 when any quality check has errors
  -h, --help              Show this help message`);
}

function runDuckDBJson(dbPath, sql) {
  const result = spawnSync("duckdb", ["-json", dbPath, "-c", sql], {
    encoding: "utf8",
  });
  if (result.error) {
    throw new Error(`Failed to run duckdb: ${result.error.message}`);
  }
  if (result.status !== 0) {
    throw new Error(result.stderr.trim());
  }
  return JSON.parse(result.stdout);
}

function buildPayload({ db, maxErrors, failOnAnyError }) {
  const qualityRows = runDuckDBJson(
    db,
    "SELECT check_name, error_count FROM mart.quality_report ORDER BY check_name;",
  );
  const [{ exported_rows: exportedRows }] = runDuckDBJson(
    db,
    "SELECT count(*) AS exported_rows FROM read_parquet('output/products.parquet');",
  );
  const [{ dataset_rows: datasetRows }] = runDuckDBJson(
    db,
    "SELECT count(*) AS dataset_rows FROM read_parquet('output/products_by_category/**/*.parquet', hive_partitioning = true);",
  );
  const [{ ingest_dataset_rows: ingestDatasetRows }] = runDuckDBJson(
    db,
    "SELECT count(*) AS ingest_dataset_rows FROM read_parquet('output/products_by_ingest_date/**/*.parquet', hive_partitioning = true);",
  );

  const checks = Object.fromEntries(
    qualityRows.map((row) => [row.check_name, Number(row.error_count)]),
  );
  const totalErrors = Object.values(checks).reduce((sum, count) => sum + count, 0);
  const failingChecks = Object.fromEntries(
    Object.entries(checks).filter(([, count]) => count > 0),
  );

  const failureReasons = [];
  if (failOnAnyError && totalErrors > 0) {
    failureReasons.push("quality_errors_present");
  }
  if (maxErrors !== null && totalErrors > maxErrors) {
    failureReasons.push("max_errors_exceeded");
  }

  return {
    ok: failureReasons.length === 0,
    totalErrors,
    failingCheckCount: Object.keys(failingChecks).length,
    exportedRows,
    datasetRows,
    ingestDatasetRows,
    checks,
    failingChecks,
    failureReasons,
  };
}

try {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    printHelp();
    process.exit(0);
  }
  if (!existsSync(args.db)) {
    throw new Error(`Database not found: ${args.db}. Run make run first.`);
  }

  const payload = buildPayload(args);
  console.log(JSON.stringify(payload, null, 2));
  process.exit(payload.ok ? 0 : 1);
} catch (error) {
  console.error(error.message);
  process.exit(2);
}
