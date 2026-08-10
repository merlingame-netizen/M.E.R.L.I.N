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
import secrets
import socket
import sys
import threading
import time
from pathlib import Path

from flask import Flask, Response, jsonify, render_template, request, send_from_directory

# Pont WebSocket↔VNC : optionnel — sans flask-sock le portail tourne en dégradé
# (bouton PLAY désactivé, tout le reste intact).
try:
    from flask_sock import Sock  # type: ignore
    _HAS_SOCK = True
except Exception:
    Sock = None  # type: ignore
    _HAS_SOCK = False

# Allow both `python3 tools/merlin_studio/app.py` and `python3 -m tools.merlin_studio.app`.
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from merlin_studio import actions, probes  # type: ignore
else:
    from . import actions, probes

_HERE = Path(__file__).resolve().parent

VNC_HOST = os.environ.get("VNC_HOST", "127.0.0.1")
VNC_PORT = int(os.environ.get("VNC_PORT", "5900"))

# Tickets à usage unique pour le handshake WS (mono-process : dict mémoire suffit).
_TICKET_TTL = 60.0
_tickets: dict[str, float] = {}
_tickets_lock = threading.Lock()


def _ticket_new() -> str:
    t = secrets.token_urlsafe(24)
    now = time.monotonic()
    with _tickets_lock:
        # purge au passage
        for k in [k for k, exp in _tickets.items() if exp < now]:
            del _tickets[k]
        _tickets[t] = now + _TICKET_TTL
    return t


def _ticket_ok(t: str | None) -> bool:
    if not t:
        return False
    now = time.monotonic()
    with _tickets_lock:
        exp = _tickets.pop(t, None)   # usage unique
    return exp is not None and exp >= now


def _auth_ok() -> bool:
    token = os.environ.get("STUDIO_TOKEN", "")
    if not token:
        return True  # local mode (loopback), no auth
    auth = request.authorization
    if not auth or auth.password is None:
        return False
    return hmac.compare_digest(auth.password, token)


def build_app() -> Flask:
    app = Flask(__name__, template_folder=str(_HERE / "templates"),
                static_folder=str(_HERE / "static"))

    @app.before_request
    def _gate():
        if request.path == "/healthz":
            return None
        # Handshake noVNC : un ticket frais (délivré derrière Basic auth) vaut auth.
        if request.path == "/websockify" and _ticket_ok(request.args.get("ticket")):
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

    # ── jeu natif (conteneur VNC) ────────────────────────────────────────────
    @app.route("/api/game")
    def api_game():
        info = probes.game()
        info["ws_bridge"] = _HAS_SOCK
        if not _HAS_SOCK:
            info["reason"] = (info.get("reason") or
                              "flask-sock absent — pip install flask-sock simple-websocket")
        return jsonify(info)

    @app.route("/api/vnc/ticket", methods=["POST"])
    def api_vnc_ticket():
        # Derrière le gate Basic auth : délivre un laissez-passer 60 s à usage
        # unique pour le handshake WS (jamais le STUDIO_TOKEN dans une URL).
        return jsonify({"ticket": _ticket_new(), "ttl": int(_TICKET_TTL)})

    # Police du jeu (VT323), self-hostée depuis Assets/fonts/.
    @app.route("/assets/fonts/<path:f>")
    def assets_fonts(f: str):
        if not f.lower().endswith(".ttf"):
            return Response("forbidden\n", 403)
        return send_from_directory(str(probes.ROOT / "Assets" / "fonts"), f,
                                   max_age=86400)

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

    # ── /play/ : build web du jeu, jouable navigateur (PC + mobile via tunnel) ──
    _WEB_BUILD = probes.ROOT / "build" / "web"

    @app.route("/play/")
    @app.route("/play/<path:f>")
    def play(f: str = "index.html"):
        if not (_WEB_BUILD / "index.html").exists():
            return Response(
                "Build web absent. Lancer « Build web du jeu » depuis l'onglet Run "
                "(ou: bash infra/oracle/studio/build-web.sh).\n",
                404, {"Content-Type": "text/plain; charset=utf-8"})
        resp = send_from_directory(str(_WEB_BUILD), f)
        # SharedArrayBuffer (threads Godot Web) exige l'isolation cross-origin.
        resp.headers["Cross-Origin-Opener-Policy"] = "same-origin"
        resp.headers["Cross-Origin-Embedder-Policy"] = "require-corp"
        return resp

    # ── pont WebSocket ↔ VNC (x11vnc -localhost:5900) ────────────────────────
    if _HAS_SOCK:
        sock = Sock(app)

        @sock.route("/websockify")
        def websockify(ws):
            # L'auth est déjà passée dans _gate (Basic OU ticket usage unique).
            try:
                tcp = socket.create_connection((VNC_HOST, VNC_PORT), timeout=5)
            except OSError:
                ws.close(1011, "VNC injoignable — le jeu est-il démarré ?")
                return
            tcp.settimeout(None)
            done = threading.Event()

            def pump_tcp_to_ws():
                try:
                    while not done.is_set():
                        data = tcp.recv(65536)
                        if not data:
                            break
                        ws.send(data)
                except Exception:
                    pass
                finally:
                    done.set()
                    try:
                        ws.close()
                    except Exception:
                        pass

            t = threading.Thread(target=pump_tcp_to_ws, daemon=True)
            t.start()
            try:
                while not done.is_set():
                    data = ws.receive()
                    if data is None:
                        break
                    if isinstance(data, str):
                        data = data.encode("utf-8")
                    tcp.sendall(data)
            except Exception:
                pass
            finally:
                done.set()
                try:
                    tcp.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
                tcp.close()

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
