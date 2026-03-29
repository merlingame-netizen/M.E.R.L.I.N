"""Saved queries routes — /api/saved-queries CRUD."""

from __future__ import annotations

import json
import time
import uuid

from flask import Blueprint, jsonify, request

from config import DATA_DIR, SAVED_QUERIES_FILE

saved_bp = Blueprint("saved", __name__)


def _envelope(status: str, data=None, error: str | None = None) -> dict:
    return {"status": status, "data": data, "error": error, "timestamp": time.time()}


def _load_queries() -> list[dict]:
    if not SAVED_QUERIES_FILE.exists():
        return []
    try:
        return json.loads(SAVED_QUERIES_FILE.read_text(encoding="utf-8"))
    except Exception:
        return []


def _save_queries(queries: list[dict]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    SAVED_QUERIES_FILE.write_text(
        json.dumps(queries, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


@saved_bp.route("/api/saved-queries", methods=["GET"])
def list_saved():
    return jsonify(_envelope("ok", _load_queries()))


@saved_bp.route("/api/saved-queries", methods=["POST"])
def create_saved():
    body = request.get_json(silent=True) or {}
    name = body.get("name", "").strip()
    sql = body.get("sql", "").strip()
    source = body.get("source", "edh")

    if not name or not sql:
        return jsonify(_envelope("error", error="Nom et SQL requis"))

    queries = _load_queries()
    entry = {
        "id": str(uuid.uuid4())[:8],
        "name": name,
        "sql": sql,
        "source": source,
        "created_at": time.time(),
        "updated_at": time.time(),
    }
    queries.append(entry)
    _save_queries(queries)
    return jsonify(_envelope("ok", entry))


@saved_bp.route("/api/saved-queries/<query_id>", methods=["PUT"])
def update_saved(query_id: str):
    body = request.get_json(silent=True) or {}
    queries = _load_queries()

    for i, q in enumerate(queries):
        if q["id"] == query_id:
            updated = {**q, "updated_at": time.time()}
            if "name" in body:
                updated = {**updated, "name": body["name"]}
            if "sql" in body:
                updated = {**updated, "sql": body["sql"]}
            new_queries = [updated if j == i else qq for j, qq in enumerate(queries)]
            _save_queries(new_queries)
            return jsonify(_envelope("ok", updated))

    return jsonify(_envelope("error", error=f"Requete {query_id} introuvable"))


@saved_bp.route("/api/saved-queries/<query_id>", methods=["DELETE"])
def delete_saved(query_id: str):
    queries = _load_queries()
    filtered = [q for q in queries if q["id"] != query_id]

    if len(filtered) == len(queries):
        return jsonify(_envelope("error", error=f"Requete {query_id} introuvable"))

    _save_queries(filtered)
    return jsonify(_envelope("ok", {"deleted": True}))
