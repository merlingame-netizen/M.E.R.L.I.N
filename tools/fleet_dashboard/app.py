"""Admin cockpit for the multi-cloud fleet (Flask).

Launched via:  python tools/cli.py fleet serve [--port 8765]
Serves tiles per machine/service with up/down + CPU/RAM/disk, polling the
FleetAdapter health checks, plus the Jobs panel (run buttons).

Hosting modes:
  - Local (PC): bound to 127.0.0.1, no auth (COCKPIT_TOKEN unset).
  - 24/7 on a VM behind Cloudflare Tunnel: set COCKPIT_TOKEN -> the whole cockpit
    (page + every /api route, especially the job-launch POSTs) requires HTTP Basic
    auth (password == COCKPIT_TOKEN). The browser caches it after one prompt.
Env:
  COCKPIT_TOKEN    if set, require Basic auth (password == token) on all routes.
  COCKPIT_USER     Basic-auth username (default "merlin"; the password is what matters).
  COCKPIT_NO_OPEN  if set (or no DISPLAY), don't try to open a browser (headless VM).
  COCKPIT_HOST     bind host (default 127.0.0.1; keep loopback even on the VM — the
                   tunnel reaches 127.0.0.1, so never expose the port directly).
"""
from __future__ import annotations

import hmac
import os
import threading
import webbrowser
from pathlib import Path

from flask import Flask, Response, jsonify, render_template, request

try:  # works whether imported as a package (fleet_dashboard.app) or a top-level module
    from . import control
except ImportError:  # pragma: no cover
    import control  # type: ignore

_HERE = Path(__file__).resolve().parent


def _auth_ok() -> bool:
    """True if request carries valid Basic auth, or no token is configured."""
    token = os.environ.get("COCKPIT_TOKEN", "")
    if not token:
        return True  # local mode, no auth
    auth = request.authorization
    if not auth or auth.password is None:
        return False
    # constant-time compare; username is advisory only
    return hmac.compare_digest(auth.password, token)


def build_app(adapter) -> Flask:
    """Create the cockpit Flask app (testable without binding a port)."""
    app = Flask(__name__, template_folder=str(_HERE / "templates"))

    @app.before_request
    def _gate():
        if not _auth_ok():
            return Response(
                "Authentication required.\n", 401,
                {"WWW-Authenticate": 'Basic realm="MERLIN Cockpit"'},
            )

    @app.route("/")
    def index():
        return render_template("index.html")

    @app.route("/healthz")
    def healthz():  # unauthenticated-friendly only when no token; used by tunnel/uptime
        return jsonify({"ok": True})

    @app.route("/api/status")
    def api_status():
        return jsonify(adapter.execute("status").get("data", {}))

    @app.route("/api/jobs")
    def api_jobs():
        return jsonify(adapter.execute("jobs").get("data", {}))

    @app.route("/api/quota")
    def api_quota():
        return jsonify(adapter.execute("quota").get("data", {}))

    @app.route("/api/run/<job>", methods=["POST"])
    def api_run(job):
        r = adapter.execute("run", job=job)
        return jsonify({"status": r.get("status"), "data": r.get("data"), "error": r.get("error")})

    # ── MERLIN dev visibility + dev/model launchers ──────────────────────────
    @app.route("/api/dev")
    def api_dev():
        return jsonify(control.dev_status())

    @app.route("/api/launchers")
    def api_launchers():
        return jsonify(control.launchers_catalog())

    @app.route("/api/launch", methods=["POST"])
    def api_launch():
        body = request.get_json(silent=True) or {}
        kind = body.get("kind", "")
        rec = control.launch(kind, body.get("params") or {})
        return jsonify(rec), (400 if rec.get("error") else 200)

    @app.route("/api/launches")
    def api_launches():
        return jsonify(control.launches())

    @app.route("/api/loops")
    def api_loops():
        return jsonify(control.loops_status())

    @app.route("/api/launch/<jid>/stop", methods=["POST"])
    def api_launch_stop(jid):
        return jsonify(control.stop(jid))

    return app


def _headless() -> bool:
    return bool(os.environ.get("COCKPIT_NO_OPEN")) or (
        os.name != "nt" and not os.environ.get("DISPLAY")
    )


def run_dashboard(adapter, port: int = 8765) -> None:
    app = build_app(adapter)
    host = os.environ.get("COCKPIT_HOST", "127.0.0.1")
    if not _headless():
        url = f"http://{host}:{port}"
        threading.Timer(1.0, lambda: webbrowser.open(url)).start()
    if os.environ.get("COCKPIT_TOKEN"):
        print(f"[cockpit] auth ENABLED (Basic, user={os.environ.get('COCKPIT_USER','merlin')})")
    else:
        print("[cockpit] auth DISABLED (local mode — set COCKPIT_TOKEN to protect)")
    # threaded so concurrent SSH probes don't block the page
    app.run(host=host, port=port, threaded=True, debug=False)
