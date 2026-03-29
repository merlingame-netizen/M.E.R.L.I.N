"""Query execution routes — /api/query, /api/export, /api/query-history."""

from __future__ import annotations

import io
import json
import time

from flask import Blueprint, Response, current_app, jsonify, request, send_file

from config import DATA_DIR, HISTORY_FILE, MAX_HISTORY, MAX_ROWS

query_bp = Blueprint("query", __name__)


def _envelope(status: str, data=None, error: str | None = None) -> dict:
    return {"status": status, "data": data, "error": error, "timestamp": time.time()}


def _get_service(source: str):
    conns = current_app.config["connections"]
    entry = conns.get(source, {})
    inst = entry.get("instance")
    if inst and entry.get("connected"):
        return inst
    return None


def _load_history() -> list[dict]:
    if not HISTORY_FILE.exists():
        return []
    try:
        return json.loads(HISTORY_FILE.read_text(encoding="utf-8"))
    except Exception:
        return []


def _save_history(history: list[dict]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    HISTORY_FILE.write_text(json.dumps(history[-MAX_HISTORY:], ensure_ascii=False, indent=2), encoding="utf-8")


def _add_to_history(source: str, sql: str, row_count: int, duration_ms: int) -> None:
    history = _load_history()
    history.append({
        "source": source,
        "sql": sql,
        "row_count": row_count,
        "duration_ms": duration_ms,
        "timestamp": time.time(),
    })
    _save_history(history)


@query_bp.route("/api/query", methods=["POST"])
def execute_query():
    body = request.get_json(silent=True) or {}
    source = body.get("source", "edh")
    sql = body.get("sql", "").strip()
    try:
        limit = min(int(body.get("limit", 10_000)), MAX_ROWS)
    except (TypeError, ValueError):
        limit = 10_000

    if not sql:
        return jsonify(_envelope("error", error="Requete vide"))

    svc = _get_service(source)
    if not svc:
        return jsonify(_envelope("error", error=f"{source} non connecte"))

    try:
        result = svc.execute(sql, limit=limit)
        if result.get("error"):
            return jsonify(_envelope("error", result, error=result["error"]))

        _add_to_history(source, sql, result.get("row_count", 0), result.get("duration_ms", 0))
        return jsonify(_envelope("ok", result))
    except Exception as exc:
        return jsonify(_envelope("error", error=str(exc)))


@query_bp.route("/api/query-history")
def query_history():
    limit = int(request.args.get("limit", str(MAX_HISTORY)))
    history = _load_history()
    # Return most recent first
    return jsonify(_envelope("ok", list(reversed(history[-limit:]))))


@query_bp.route("/api/export", methods=["POST"])
def export_data():
    body = request.get_json(silent=True) or {}
    columns = body.get("columns", [])
    rows = body.get("rows", [])
    fmt = body.get("format", "csv")

    if not columns or not rows:
        return jsonify(_envelope("error", error="Aucune donnee a exporter"))

    import pandas as pd
    df = pd.DataFrame(rows, columns=columns)

    if fmt == "csv":
        buf = io.StringIO()
        df.to_csv(buf, index=False, encoding="utf-8")
        return Response(
            buf.getvalue(),
            mimetype="text/csv",
            headers={"Content-Disposition": "attachment; filename=data_export.csv"},
        )
    elif fmt == "xlsx":
        buf = io.BytesIO()
        df.to_excel(buf, index=False, engine="openpyxl")
        buf.seek(0)
        return send_file(
            buf,
            mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            as_attachment=True,
            download_name="data_export.xlsx",
        )
    elif fmt == "json":
        return Response(
            df.to_json(orient="records", force_ascii=False, indent=2),
            mimetype="application/json",
            headers={"Content-Disposition": "attachment; filename=data_export.json"},
        )
    else:
        return jsonify(_envelope("error", error=f"Format inconnu: {fmt}"))
