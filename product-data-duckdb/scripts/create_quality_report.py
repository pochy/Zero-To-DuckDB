#!/usr/bin/env python3
import csv
import html
from pathlib import Path


QUALITY_REPORT = Path("reports/quality_report.csv")
PRODUCT_ERRORS = Path("reports/product_errors.csv")
OUTPUT = Path("reports/quality_report.html")


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def render_bar(label: str, value: int, max_value: int) -> str:
    width = 0 if max_value == 0 else round((value / max_value) * 100, 1)
    label_text = html.escape(label.replace("_", " "))
    return f"""
      <div class="bar-row">
        <div class="bar-label">{label_text}</div>
        <div class="bar-track">
          <div class="bar-fill" style="width: {width}%"></div>
        </div>
        <div class="bar-value">{value}</div>
      </div>
    """


def render_error_rows(rows: list[dict[str, str]]) -> str:
    if not rows:
        return '<tr><td colspan="6">No error rows</td></tr>'

    visible_rows = rows[:12]
    table_rows = []
    for row in visible_rows:
        table_rows.append(
            "<tr>"
            f"<td>{html.escape(row.get('jan_code', ''))}</td>"
            f"<td>{html.escape(row.get('product_name', ''))}</td>"
            f"<td>{html.escape(row.get('price', ''))}</td>"
            f"<td>{html.escape(row.get('category_name', ''))}</td>"
            f"<td>{html.escape(row.get('maker_name', ''))}</td>"
            f"<td>{html.escape(row.get('error_reasons', ''))}</td>"
            "</tr>"
        )
    return "\n".join(table_rows)


def main() -> None:
    quality_rows = read_csv(QUALITY_REPORT)
    error_rows = read_csv(PRODUCT_ERRORS)

    quality = [
        (row["check_name"], int(row["error_count"]))
        for row in quality_rows
    ]
    max_error_count = max((count for _, count in quality), default=0)
    total_errors = sum(count for _, count in quality)
    failing_checks = sum(1 for _, count in quality if count > 0)

    bars = "\n".join(
        render_bar(name, count, max_error_count)
        for name, count in sorted(quality, key=lambda item: item[1], reverse=True)
    )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>DuckDB Product Data Quality Report</title>
  <style>
    :root {{
      --bg: #f7f8fa;
      --panel: #ffffff;
      --text: #1f2933;
      --muted: #61717f;
      --line: #d9e0e7;
      --accent: #0f766e;
      --accent-soft: #ccfbf1;
      --warn: #b45309;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      line-height: 1.5;
    }}
    main {{
      width: min(1120px, calc(100vw - 40px));
      margin: 32px auto;
    }}
    h1, h2 {{ margin: 0; }}
    h1 {{ font-size: 30px; }}
    h2 {{ font-size: 18px; margin-bottom: 14px; }}
    .subtitle {{ color: var(--muted); margin: 6px 0 24px; }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 16px;
      margin-bottom: 20px;
    }}
    .panel {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 18px;
    }}
    .metric-label {{ color: var(--muted); font-size: 13px; }}
    .metric-value {{ font-size: 34px; font-weight: 700; margin-top: 4px; }}
    .bar-row {{
      display: grid;
      grid-template-columns: 190px 1fr 48px;
      gap: 12px;
      align-items: center;
      margin: 12px 0;
    }}
    .bar-label {{ color: var(--muted); font-size: 14px; }}
    .bar-track {{
      height: 14px;
      background: #edf2f7;
      border-radius: 999px;
      overflow: hidden;
    }}
    .bar-fill {{
      height: 100%;
      background: var(--accent);
      border-radius: 999px;
    }}
    .bar-value {{ text-align: right; font-variant-numeric: tabular-nums; }}
    table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 14px;
    }}
    th, td {{
      border-bottom: 1px solid var(--line);
      padding: 9px 8px;
      text-align: left;
      vertical-align: top;
    }}
    th {{
      color: var(--muted);
      font-weight: 600;
      background: #fbfcfd;
    }}
    .reason {{ color: var(--warn); font-weight: 600; }}
    @media (max-width: 820px) {{
      main {{ width: min(100vw - 24px, 1120px); }}
      .grid {{ grid-template-columns: 1fr; }}
      .bar-row {{ grid-template-columns: 1fr 48px; }}
      .bar-label {{ grid-column: 1 / -1; }}
      table {{ display: block; overflow-x: auto; white-space: nowrap; }}
    }}
  </style>
</head>
<body>
  <main>
    <h1>Product Data Quality Report</h1>
    <p class="subtitle">Generated from DuckDB quality checks and exported error rows.</p>

    <section class="grid">
      <div class="panel">
        <div class="metric-label">Total reported errors</div>
        <div class="metric-value">{total_errors}</div>
      </div>
      <div class="panel">
        <div class="metric-label">Failing checks</div>
        <div class="metric-value">{failing_checks}</div>
      </div>
      <div class="panel">
        <div class="metric-label">Error rows exported</div>
        <div class="metric-value">{len(error_rows)}</div>
      </div>
    </section>

    <section class="panel">
      <h2>Quality Check Counts</h2>
      {bars}
    </section>

    <section class="panel" style="margin-top: 20px;">
      <h2>Error Row Sample</h2>
      <table>
        <thead>
          <tr>
            <th>JAN code</th>
            <th>Product</th>
            <th>Price</th>
            <th>Category</th>
            <th>Maker</th>
            <th>Reason</th>
          </tr>
        </thead>
        <tbody>
          {render_error_rows(error_rows)}
        </tbody>
      </table>
    </section>
  </main>
</body>
</html>
""",
        encoding="utf-8",
    )
    print(f"Wrote {OUTPUT}")


if __name__ == "__main__":
    main()
