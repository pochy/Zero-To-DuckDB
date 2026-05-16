#!/usr/bin/env python3
import csv
import sqlite3
from pathlib import Path


CSV_INPUT = Path("data/master/categories.csv")
SQLITE_OUTPUT = Path("data/master/master.sqlite")


def main() -> None:
    SQLITE_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    if SQLITE_OUTPUT.exists():
        SQLITE_OUTPUT.unlink()

    with CSV_INPUT.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    with sqlite3.connect(SQLITE_OUTPUT) as conn:
        conn.execute(
            """
            CREATE TABLE categories (
              category_id INTEGER PRIMARY KEY,
              category_name TEXT NOT NULL UNIQUE
            )
            """
        )
        conn.executemany(
            "INSERT INTO categories (category_id, category_name) VALUES (?, ?)",
            [
                (int(row["category_id"]), row["category_name"].strip().lower())
                for row in rows
            ],
        )
        conn.execute(
            """
            CREATE TABLE metadata (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
            """
        )
        conn.execute(
            "INSERT INTO metadata (key, value) VALUES ('source', 'generated from data/master/categories.csv')"
        )


if __name__ == "__main__":
    main()
