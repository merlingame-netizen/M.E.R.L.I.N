"""Serveur HTTP local (127.0.0.1 uniquement) — API facon Jev pour tous les outils du poste.

  GET  /health          -> etat + decideur
  POST /v1/systemone    -> {"context", "questions"}  (voir systemone.py)
  POST /v1/route        -> {"prompt", "task_id"?, "cwd"?}   (sans cwd : decideur local)
  POST /v1/failure      -> {"task_id"}
  GET  /v1/stats
"""

from __future__ import annotations

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from router import load_config, make_backend, record_failure, route, stats
from systemone import DecisionError, decide

MAX_BODY = 512 * 1024


class _Handler(BaseHTTPRequestHandler):
    server_version = "jev-router-local/1.0"

    def _send(self, code: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _body(self) -> dict:
        length = int(self.headers.get("Content-Length") or 0)
        if not 0 <= length <= MAX_BODY:
            raise DecisionError("Content-Length invalide ou corps trop volumineux")
        data = json.loads(self.rfile.read(length) or b"{}")
        if not isinstance(data, dict):
            raise DecisionError("objet JSON attendu")
        return data

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/health":
            cfg = load_config()
            self._send(200, {"status": "ok", "decider": cfg["decider"]["model"]})
        elif self.path == "/v1/stats":
            self._send(200, stats())
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self) -> None:  # noqa: N802
        try:
            body = self._body()
            cfg = load_config()
            if self.path == "/v1/systemone":
                self._send(200, decide(body, make_backend(cfg)))
            elif self.path == "/v1/route":
                self._send(200, route(str(body.get("prompt", "")), body.get("task_id"), cfg,
                                      cwd=body.get("cwd")))
            elif self.path == "/v1/failure":
                self._send(200, record_failure(str(body.get("task_id", "")), cfg))
            else:
                self._send(404, {"error": "not found"})
        except (DecisionError, ValueError, KeyError) as exc:
            self._send(400, {"error": str(exc)})

    def log_message(self, fmt: str, *args) -> None:  # silence : pas de prompts dans les logs
        pass


def serve(port: int = 8790) -> None:
    httpd = ThreadingHTTPServer(("127.0.0.1", port), _Handler)
    print(f"jev-router local sur http://127.0.0.1:{port} (Ctrl+C pour arreter)")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()
