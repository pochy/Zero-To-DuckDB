#!/usr/bin/env python3
import json
from pathlib import Path


NOTEBOOK = Path("notebooks/quality_analysis.ipynb")


def main() -> None:
    data = json.loads(NOTEBOOK.read_text(encoding="utf-8"))
    if data.get("nbformat") != 4:
        raise SystemExit("notebook nbformat must be 4")

    cells = data.get("cells", [])
    if len(cells) < 6:
        raise SystemExit("notebook should contain at least 6 cells")

    code_cells = [cell for cell in cells if cell.get("cell_type") == "code"]
    if not code_cells:
        raise SystemExit("notebook should contain code cells")

    source = "\n".join(
        "".join(cell.get("source", []))
        for cell in code_cells
    )
    required_terms = [
        "quality_report.csv",
        "product_errors.csv",
        "read_parquet",
        "products_by_ingest_date",
        "duckdb_json",
    ]
    missing = [term for term in required_terms if term not in source]
    if missing:
        raise SystemExit(f"notebook is missing expected terms: {', '.join(missing)}")

    print(f"PASS: {NOTEBOOK} has {len(cells)} cells and {len(code_cells)} code cells")


if __name__ == "__main__":
    main()
