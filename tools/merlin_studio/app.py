"""MERLIN Studio — VM-local dev dashboard for the personal Oracle ARM A1 host.

Sibling of the GCP fleet cockpit, but a SEPARATE extension with its own scope: this box
exists to work on the MERLIN game, so the panes are Run (Godot) / Contenu / Jobs / LLM /
Repo / Hôte instead of fleet+quota.

Run:      python3 tools/merlin_studio/app.py --port 8790
Env:      STUDIO_TOKEN (Basic-auth password; required once exposed via tunnel)
          STUDIO_USER (default "merlin"), STUDIO_HOST (default 127.0.0.1)
          OLLAMA_URL / TTS_URL / ASR_URL / GODOT_BIN
Deploy:   infra/oracle/studio/deploy-studio.sh (systemd + Cloudflare tunnel)
"""
from __future__ import annotations

import argparse
import hmac
import os
import sys
from pathlib import Path

from flask import Flask, Response, jsonify, render_template, request

# Allow both `python3 tools/merlin_studio/app.py` and `python3 -m tools.merlin_studio.app`.
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from merlin_studio import actions, probes  # type: ignore
else:
    from . import actions, probes

_HERE = Path(__file__).resolve().parent


def _auth_ok() -> bool:
    token = os.environ.get("STUDIO_TOKEN", "")
    if not token:
        return True  # local mode (loopback), no auth
    auth = request.authorization
    if not auth or auth.password is None:
        return False
    return hmac.compare_digest(auth.password, token)


def build_app() -> Flask:
    app = Flask(__name__, template_folder=str(_HERE / "templates"))

    @app.before_request
    def _gate():
        if request.path == "/healthz":
            return None
        if not _auth_ok():
            return Response("Authentication required.\n", 401,
                            {"WWW-Authenticate": 'Basic realm="MERLIN Studio"'})

    @app.route("/")
    def index():
        return render_template("index.html")

    @app.route("/healthz")
    def healthz():
        return jsonify({"ok": True, "app": "merlin-studio"})

    # ── read-only panes ──────────────────────────────────────────────────────
    @app.route("/api/overview")
    def api_overview():
        return jsonify(probes.overview())

    @app.route("/api/godot")
    def api_godot():
        return jsonify({"godot": probes.godot_info(), "runs": probes.last_runs()})

    @app.route("/api/content")
    def api_content():
        return jsonify({"canon": probes.canon(), "corpus": probes.corpus(),
                        "loops": probes.loops()})

    @app.route("/api/llm")
    def api_llm():
        return jsonify({"ollama": probes.ollama(), "voice": probes.voice()})

    @app.route("/api/repo")
    def api_repo():
        return jsonify(probes.repo())

    @app.route("/api/host")
    def api_host():
        return jsonify(probes.host())

    # ── actions ──────────────────────────────────────────────────────────────
    @app.route("/api/launchers")
    def api_launchers():
        return jsonify(actions.catalog())

    @app.route("/api/launch", methods=["POST"])
    def api_launch():
        body = request.get_json(silent=True) or {}
        rec = actions.launch(str(body.get("kind", "")), body.get("params") or {})
        return jsonify(rec), (400 if rec.get("error") else 200)

    @app.route("/api/jobs")
    def api_jobs():
        return jsonify(actions.jobs())

    @app.route("/api/job/<jid>")
    def api_job(jid):
        return Response(actions.job_log(jid) or "(vide)", mimetype="text/plain")

    @app.route("/api/job/<jid>/stop", methods=["POST"])
    def api_job_stop(jid):
        return jsonify(actions.stop(jid))

    return app


def main() -> int:
    ap = argparse.ArgumentParser(description="MERLIN Studio (VM-local dev dashboard)")
    ap.add_argument("--port", type=int, default=int(os.environ.get("STUDIO_PORT", "8790")))
    ap.add_argument("--host", default=os.environ.get("STUDIO_HOST", "127.0.0.1"))
    a = ap.parse_args()
    if os.environ.get("STUDIO_TOKEN"):
        print(f"[studio] auth ENABLED (Basic, user={os.environ.get('STUDIO_USER', 'merlin')})")
    else:
        print("[studio] auth DISABLED (local only — set STUDIO_TOKEN before exposing)")
    print(f"[studio] http://{a.host}:{a.port}  repo={probes.ROOT}")
    build_app().run(host=a.host, port=a.port, threaded=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
