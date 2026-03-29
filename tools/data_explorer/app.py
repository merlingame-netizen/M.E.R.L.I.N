"""Data Explorer — Flask entry point.

Usage:
    python tools/data_explorer/app.py
    python tools/cli.py data-explorer start
"""

from __future__ import annotations

import logging
import os
import time
import webbrowser
from pathlib import Path
from threading import Timer

from flask import Flask, jsonify, send_from_directory

from config import DATA_DIR, HOST, PORT

_log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# App factory
# ---------------------------------------------------------------------------

app = Flask(
    __name__,
    static_folder=str(Path(__file__).parent / "static"),
    static_url_path="/static",
)
def _get_secret_key() -> str:
    """Generate a secret key per installation, stored alongside credentials."""
    key_path = DATA_DIR / ".flask_secret"
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if key_path.exists():
        return key_path.read_text(encoding="utf-8")
    import secrets
    key = secrets.token_hex(32)
    key_path.write_text(key, encoding="utf-8")
    return key

app.secret_key = os.environ.get("DATA_EXPLORER_SECRET") or _get_secret_key()

# Ensure persistence directory exists
DATA_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# Connection state (single-user, in-memory)
# ---------------------------------------------------------------------------

app.config["connections"] = {
    "edh": {"connected": False, "instance": None, "info": {}},
    "bigquery": {"connected": False, "instance": None, "info": {}},
}


# ---------------------------------------------------------------------------
# Routes — static SPA
# ---------------------------------------------------------------------------

@app.route("/")
def index():
    return send_from_directory(app.static_folder, "index.html")


# ---------------------------------------------------------------------------
# API — colors (GraphFit palette export)
# ---------------------------------------------------------------------------

def _build_color_palette() -> dict:
    """Export GraphFit OrangeColors + OrangeColormaps as JSON."""
    try:
        from graphfit import OrangeColors, OrangeColormaps

        primary = {
            "orange": OrangeColors.ORANGE,
            "accessible_orange": OrangeColors.ACCESSIBLE_ORANGE,
            "black": OrangeColors.BLACK,
            "white": OrangeColors.WHITE,
        }
        greys = {f"grey_{i}00": getattr(OrangeColors, f"GREY_{i}00") for i in range(1, 10)}
        functional = {
            "info": OrangeColors.FUNC_BLUE,
            "success": OrangeColors.FUNC_GREEN,
            "warning": OrangeColors.FUNC_YELLOW,
            "danger": OrangeColors.FUNC_RED,
        }
        colormaps = {
            "categorical": OrangeColormaps.categorical_cmap(),
            "blue": OrangeColormaps.blue_cmap(),
            "green": OrangeColormaps.green_cmap(),
            "orange": OrangeColormaps.orange_cmap(),
            "tonality": OrangeColormaps.tonality_cmap(),
            "binary_func": OrangeColormaps.binary_func_cmap(),
            "diverging_blue_orange": OrangeColormaps.diverging_blue_orange_cmap(),
        }
        return {"primary": primary, "greys": greys, "functional": functional, "colormaps": colormaps}
    except ImportError:
        return {"error": "graphfit not installed"}


@app.route("/api/colors")
def api_colors():
    return jsonify(_envelope("ok", _build_color_palette()))


# ---------------------------------------------------------------------------
# API — status
# ---------------------------------------------------------------------------

@app.route("/api/status")
def api_status():
    conns = app.config["connections"]
    data = {
        "edh": {"connected": conns["edh"]["connected"], **conns["edh"]["info"]},
        "bigquery": {"connected": conns["bigquery"]["connected"], **conns["bigquery"]["info"]},
    }
    return jsonify(_envelope("ok", data))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _envelope(status: str, data=None, error: str | None = None) -> dict:
    """Standard API response envelope (matches BaseAdapter pattern)."""
    return {
        "status": status,
        "data": data,
        "error": error,
        "timestamp": time.time(),
    }


# ---------------------------------------------------------------------------
# Register blueprints (lazy — phases 1-4 add them)
# ---------------------------------------------------------------------------

def _register_blueprints():
    """Import and register route blueprints. Silently skip missing ones."""
    blueprint_modules = [
        ("routes.connection", "connection_bp"),
        ("routes.tables", "tables_bp"),
        ("routes.query", "query_bp"),
        ("routes.chart", "chart_bp"),
        ("routes.saved", "saved_bp"),
    ]
    for module_path, bp_name in blueprint_modules:
        try:
            mod = __import__(module_path, fromlist=[bp_name])
            bp = getattr(mod, bp_name)
            app.register_blueprint(bp)
        except (ImportError, AttributeError) as exc:
            _log.warning("Blueprint %s not loaded: %s", module_path, exc)


_register_blueprints()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def _open_browser():
    webbrowser.open(f"http://{HOST}:{PORT}")


if __name__ == "__main__":
    print(f"\n  Data Explorer — http://{HOST}:{PORT}\n")
    Timer(1.5, _open_browser).start()
    app.run(host=HOST, port=PORT, debug=False, threaded=True)
