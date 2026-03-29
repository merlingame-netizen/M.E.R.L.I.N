"""Table browser routes — /api/tables, /api/describe, /api/sample, /api/profile-column."""

from __future__ import annotations

import time

from flask import Blueprint, current_app, jsonify, request
from services.sql_guard import safe_identifier

tables_bp = Blueprint("tables", __name__)


def _envelope(status: str, data=None, error: str | None = None) -> dict:
    return {"status": status, "data": data, "error": error, "timestamp": time.time()}


def _get_service(source: str):
    """Get the connected service for a source, or None."""
    conns = current_app.config["connections"]
    entry = conns.get(source, {})
    inst = entry.get("instance")
    if inst and entry.get("connected"):
        return inst
    return None


@tables_bp.route("/api/tables")
def list_tables():
    source = request.args.get("source", "edh")
    database = request.args.get("database", "")
    filter_ = request.args.get("filter", "")

    svc = _get_service(source)
    if not svc:
        return jsonify(_envelope("error", error=f"{source} non connecte"))

    try:
        tables = svc.list_tables(database=database, filter_=filter_)
        return jsonify(_envelope("ok", {"tables": tables}))
    except Exception as exc:
        return jsonify(_envelope("error", error=str(exc)))


@tables_bp.route("/api/describe/<table>")
def describe_table(table: str):
    source = request.args.get("source", "edh")

    svc = _get_service(source)
    if not svc:
        return jsonify(_envelope("error", error=f"{source} non connecte"))

    try:
        result = svc.describe_table(table)
        return jsonify(_envelope("ok", result))
    except Exception as exc:
        return jsonify(_envelope("error", error=str(exc)))


@tables_bp.route("/api/sample/<table>")
def sample_table(table: str):
    source = request.args.get("source", "edh")
    from config import MAX_ROWS
    limit = min(int(request.args.get("limit", "100")), MAX_ROWS)
    columns_raw = request.args.get("columns", "")
    columns = [c.strip() for c in columns_raw.split(",") if c.strip()] or None

    svc = _get_service(source)
    if not svc:
        return jsonify(_envelope("error", error=f"{source} non connecte"))

    try:
        result = svc.sample(table, columns=columns, limit=limit)
        if result.get("error"):
            return jsonify(_envelope("error", result, error=result["error"]))
        return jsonify(_envelope("ok", result))
    except Exception as exc:
        return jsonify(_envelope("error", error=str(exc)))


@tables_bp.route("/api/profile-column/<table>")
def profile_column(table: str):
    """Count total rows and distinct values for a specific column.

    Extracts raw data via hive-driver then aggregates in Python (Tez can't aggregate).
    Returns: {column, total, distinct_count, nulls, null_pct, values?: [...]}
    values is included only if distinct_count <= 50.
    """
    source = request.args.get("source", "edh")
    column = request.args.get("column", "")
    mode = request.args.get("mode", "count")  # "count" or "distinct"

    if not column:
        return jsonify(_envelope("error", error="Parametre 'column' requis"))

    try:
        safe_identifier(column, "colonne")
    except ValueError as exc:
        return jsonify(_envelope("error", error=str(exc)))

    svc = _get_service(source)
    if not svc:
        return jsonify(_envelope("error", error=f"{source} non connecte"))

    from config import MAX_ROWS

    try:
        # Extract raw column data (no aggregation — Tez forbidden on EDH)
        result = svc.sample(table, columns=[column], limit=MAX_ROWS)
        if result.get("error"):
            return jsonify(_envelope("error", error=result["error"]))

        rows = result.get("rows", [])
        total = len(rows)
        values_raw = [r[0] if isinstance(r, list) else r.get(column) for r in rows]
        non_null = [v for v in values_raw if v is not None and str(v).strip() not in ("", "null")]
        nulls = total - len(non_null)
        null_pct = round((nulls / total) * 100, 1) if total > 0 else 0

        unique_values = sorted(set(str(v) for v in non_null))
        distinct_count = len(unique_values)

        data = {
            "column": column,
            "total": total,
            "distinct_count": distinct_count,
            "nulls": nulls,
            "null_pct": null_pct,
            "duration_ms": result.get("duration_ms", 0),
            "capped": total >= MAX_ROWS,
        }

        # Include actual values if <= 50 distinct and mode is "distinct"
        if mode == "distinct" and distinct_count <= 50:
            # Count occurrences
            counts = {}
            for v in non_null:
                key = str(v)
                counts[key] = counts.get(key, 0) + 1
            data["values"] = sorted(
                [{"value": k, "count": c, "pct": round(c / total * 100, 1) if total > 0 else 0}
                 for k, c in counts.items()],
                key=lambda x: -x["count"],
            )
        elif mode == "distinct" and distinct_count > 50:
            # Too many — return top 50
            counts = {}
            for v in non_null:
                key = str(v)
                counts[key] = counts.get(key, 0) + 1
            top50 = sorted(counts.items(), key=lambda x: -x[1])[:50]
            data["values"] = [
                {"value": k, "count": c, "pct": round(c / total * 100, 1) if total > 0 else 0}
                for k, c in top50
            ]
            data["values_truncated"] = True

        return jsonify(_envelope("ok", data))
    except Exception as exc:
        return jsonify(_envelope("error", error=str(exc)))
