"""Connection routes — /api/connect, /api/disconnect, /api/status."""

from __future__ import annotations

import threading
import time

from flask import Blueprint, current_app, jsonify, request

from connections.bigquery import BigQueryConnection
from connections.edh import EDHConnection
from services.credentials import delete_credentials, load_credentials, save_credentials

connection_bp = Blueprint("connection", __name__)

# Per-source locks to allow parallel EDH + GCP connections
_locks = {
    "edh": threading.Lock(),
    "bigquery": threading.Lock(),
}


def _envelope(status: str, data=None, error: str | None = None) -> dict:
    return {"status": status, "data": data, "error": error, "timestamp": time.time()}


def _get_conns() -> dict:
    return current_app.config["connections"]


def _get_or_create_service(source: str):
    """Get existing service instance or create a new one."""
    conns = _get_conns()
    instance = conns[source].get("instance")
    if instance is None:
        if source == "edh":
            instance = EDHConnection()
        else:
            instance = BigQueryConnection()
        conns[source]["instance"] = instance
    return instance


@connection_bp.route("/api/status")
def api_status():
    conns = _get_conns()
    data = {}
    for source in ("edh", "bigquery"):
        inst = conns[source].get("instance")
        connected = inst.is_connected() if inst else False
        conns[source]["connected"] = connected
        info = inst.info() if inst else {}
        data[source] = {"connected": connected, **info}
    return jsonify(_envelope("ok", data))


@connection_bp.route("/api/connect/edh", methods=["POST"])
def connect_edh():
    lock = _locks["edh"]
    if not lock.acquire(blocking=False):
        return jsonify(_envelope("error", error="Connexion EDH deja en cours, patientez..."))
    try:
        body = request.get_json(silent=True) or {}
        user = body.get("user", "")
        password = body.get("password", "")

        # Try stored credentials if none provided
        if not user:
            stored = load_credentials("edh")
            if stored:
                user = stored.get("user", "")
                password = stored.get("password", "")

        service = _get_or_create_service("edh")
        result = service.connect(user=user, password=password)

        conns = _get_conns()
        conns["edh"]["connected"] = result.get("connected", False)
        conns["edh"]["info"] = {"dsn": service._dsn, "schema": service._schema}

        # Save credentials on success
        if result["connected"] and user:
            save_credentials("edh", {"user": user, "password": password})

        if result["connected"]:
            return jsonify(_envelope("ok", result))
        return jsonify(_envelope("error", result, error=result.get("info", "Connexion echouee")))
    finally:
        lock.release()


@connection_bp.route("/api/connect/bigquery", methods=["POST"])
def connect_bigquery():
    lock = _locks["bigquery"]
    if not lock.acquire(blocking=False):
        return jsonify(_envelope("error", error="Connexion GCP deja en cours, patientez..."))
    try:
        body = request.get_json(silent=True) or {}
        project = body.get("project", "")

        service = _get_or_create_service("bigquery")
        result = service.connect(project=project)

        conns = _get_conns()
        conns["bigquery"]["connected"] = result.get("connected", False)
        conns["bigquery"]["info"] = {"project": service._project, "dataset": service._dataset}

        if result["connected"]:
            return jsonify(_envelope("ok", result))
        return jsonify(_envelope("error", result, error=result.get("info", "Connexion echouee")))
    finally:
        lock.release()


@connection_bp.route("/api/disconnect/<source>", methods=["POST"])
def disconnect(source: str):
    if source not in ("edh", "bigquery"):
        return jsonify(_envelope("error", error=f"Source inconnue: {source}"))

    conns = _get_conns()
    inst = conns[source].get("instance")
    if inst:
        inst.disconnect()
    conns[source]["connected"] = False

    if source == "edh":
        delete_credentials("edh")

    return jsonify(_envelope("ok", {"connected": False}))
