#!/usr/bin/env python3
"""Firebase Realtime Database (JSON export) -> SQLite / D1.

RTDB is a schemaless JSON tree. Flattening rules:
  - Each top-level node that is an object-of-records  ->  a table.
      * row id  = the record key (push id / key)
      * scalar fields  -> typed columns (union across records, missing = NULL)
      * nested objects/arrays -> stored as JSON text columns
  - Other top-level scalars/flat values -> a key/value table `_root`.

Outputs a .db (SQLite) and a .sql dump (for `wrangler d1 execute --file=...`).

Usage:
  python3 rtdb_to_sqlite.py export.json --db out.db --sql out.sql
"""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
from pathlib import Path


def sanitize(name: str) -> str:
    s = re.sub(r"[^0-9a-zA-Z_]", "_", str(name))
    if not s or s[0].isdigit():
        s = "_" + s
    return s


def col_type(values) -> str:
    seen = set()
    for v in values:
        if v is None:
            continue
        if isinstance(v, bool):
            seen.add("INTEGER")
        elif isinstance(v, int):
            seen.add("INTEGER")
        elif isinstance(v, float):
            seen.add("REAL")
        else:
            seen.add("TEXT")
    if seen == {"INTEGER"}:
        return "INTEGER"
    if seen <= {"INTEGER", "REAL"} and seen:
        return "REAL"
    return "TEXT"


def cell(v):
    if v is None:
        return None
    if isinstance(v, bool):
        return 1 if v else 0
    if isinstance(v, (int, float, str)):
        return v
    return json.dumps(v, ensure_ascii=False)  # nested object/array -> JSON text


def is_record_map(node) -> bool:
    """True if node looks like {key: {record}, ...} (a table)."""
    if not isinstance(node, dict) or not node:
        return False
    return all(isinstance(v, dict) for v in node.values())


def build(data: dict, con: sqlite3.Connection) -> dict:
    cur = con.cursor()
    summary = {}
    root_kv = {}

    for top, node in data.items():
        table = sanitize(top)
        if is_record_map(node):
            # map sanitized column name -> original field key (so values are read
            # back from the real key); collect values for type inference.
            col_orig: dict[str, str] = {}
            col_vals: dict[str, list] = {}
            for rec in node.values():
                for k, v in rec.items():
                    c = sanitize(k)
                    if c in col_orig and col_orig[c] != k:  # two keys collide -> dedupe
                        i = 2
                        while f"{c}_{i}" in col_orig and col_orig[f"{c}_{i}"] != k:
                            i += 1
                        c = f"{c}_{i}"
                    col_orig.setdefault(c, k)
                    col_vals.setdefault(c, []).append(v)
            # synthetic primary key column, collision-safe vs record fields
            keycol = "_key"
            while keycol in col_orig:
                keycol += "_"
            colnames = list(col_orig.keys())
            ddl = ", ".join(f'"{c}" {col_type(col_vals[c])}' for c in colnames)
            cur.execute(f'CREATE TABLE "{table}" ("{keycol}" TEXT PRIMARY KEY{", " + ddl if ddl else ""})')
            quoted = ", ".join('"' + c + '"' for c in colnames)
            col_list = f'"{keycol}"' + (", " + quoted if colnames else "")
            placeholders = ", ".join(["?"] * (len(colnames) + 1))
            ins = f'INSERT INTO "{table}" ({col_list}) VALUES ({placeholders})'
            rows = [[str(rid)] + [cell(rec.get(col_orig[c])) for c in colnames]
                    for rid, rec in node.items()]
            cur.executemany(ins, rows)
            summary[table] = len(rows)
        else:
            root_kv[top] = node

    if root_kv:
        cur.execute('CREATE TABLE "_root" ("key" TEXT PRIMARY KEY, "value" TEXT)')
        cur.executemany('INSERT INTO "_root" VALUES (?, ?)',
                        [(k, cell(v)) for k, v in root_kv.items()])
        summary["_root"] = len(root_kv)
    con.commit()
    return summary


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("json", help="RTDB JSON export file")
    ap.add_argument("--db", default="rtdb.db")
    ap.add_argument("--sql", default="rtdb.sql")
    args = ap.parse_args()

    data = json.loads(Path(args.json).read_text())
    if not isinstance(data, dict):
        print("Top-level RTDB export must be a JSON object.", file=sys.stderr)
        return 1

    Path(args.db).unlink(missing_ok=True)
    con = sqlite3.connect(args.db)
    summary = build(data, con)
    # SQL dump for D1 (wrangler d1 execute --file=...)
    with open(args.sql, "w", encoding="utf-8") as f:
        for line in con.iterdump():
            f.write(line + "\n")
    con.close()

    print("Migration prepared:")
    for t, n in summary.items():
        print(f"  table {t:<24} {n} rows")
    print(f"  -> {args.db}  +  {args.sql}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
