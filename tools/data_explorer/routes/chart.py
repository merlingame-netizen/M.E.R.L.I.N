"""Chart routes — /api/chart."""

from __future__ import annotations

import time

from flask import Blueprint, jsonify, request

chart_bp = Blueprint("chart", __name__)


def _envelope(status: str, data=None, error: str | None = None) -> dict:
    return {"status": status, "data": data, "error": error, "timestamp": time.time()}


@chart_bp.route("/api/chart", methods=["POST"])
def generate_chart():
    body = request.get_json(silent=True) or {}

    chart_type = body.get("chart_type", "bar_count")
    columns = body.get("columns", [])
    rows = body.get("rows", [])
    x = body.get("x", "")
    y = body.get("y", "")
    color = body.get("color") or None
    top_n = body.get("top_n", 15)

    if not columns or not rows:
        return jsonify(_envelope("error", error="Pas de donnees. Chargez un echantillon d'abord."))

    try:
        from services.chart_service import build_chart

        fig_json = build_chart(
            chart_type=chart_type,
            columns=columns,
            rows=rows,
            x=x,
            y=y,
            color=color,
            top_n=top_n,
        )
        return jsonify(_envelope("ok", fig_json))
    except ValueError as exc:
        return jsonify(_envelope("error", error=str(exc)))
    except Exception as exc:
        return jsonify(_envelope("error", error=f"Erreur chart: {exc}"))
