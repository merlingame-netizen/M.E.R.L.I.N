"""Local admin dashboard for the multi-cloud fleet (Flask, 100% local).

Launched via:  python tools/cli.py fleet serve
Serves tiles per machine/service with up/down + CPU/RAM/disk, polling the
FleetAdapter health checks. Bound to 127.0.0.1 only.
"""
from __future__ import annotations

import threading
import webbrowser
from pathlib import Path

from flask import Flask, jsonify, render_template

_HERE = Path(__file__).resolve().parent


def run_dashboard(adapter, port: int = 8765) -> None:
    app = Flask(__name__, template_folder=str(_HERE / "templates"))

    @app.route("/")
    def index():
        return render_template("index.html")

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

    url = f"http://127.0.0.1:{port}"
    threading.Timer(1.0, lambda: webbrowser.open(url)).start()
    # threaded so concurrent SSH probes don't block the page
    app.run(host="127.0.0.1", port=port, threaded=True, debug=False)
