"""Tiny always-(re)startable service for Fly.io — stdlib only, SQLite-backed.
Routes: GET /health, GET /items, POST /items {key,value}.
Note: without a Fly volume the SQLite file is ephemeral (fine for a demo service).
"""
import json
import os
import sqlite3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DB = os.environ.get("DB_PATH", "/tmp/merlin.db")


def db():
    c = sqlite3.connect(DB)
    c.execute("CREATE TABLE IF NOT EXISTS items(key TEXT PRIMARY KEY, value TEXT, updated_at INTEGER)")
    return c


class H(BaseHTTPRequestHandler):
    def _send(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            return self._send({"ok": True, "service": "merlin-fly", "store": "sqlite"})
        if self.path == "/items":
            with db() as c:
                rows = c.execute("SELECT key,value,updated_at FROM items ORDER BY updated_at DESC LIMIT 100").fetchall()
            return self._send({"items": [{"key": k, "value": v, "updated_at": u} for k, v, u in rows]})
        return self._send({"error": "not found"}, 404)

    def do_POST(self):
        if self.path != "/items":
            return self._send({"error": "not found"}, 404)
        n = int(self.headers.get("content-length", 0))
        try:
            body = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            return self._send({"error": "invalid json"}, 400)
        if not body.get("key"):
            return self._send({"error": "key required"}, 400)
        with db() as c:
            c.execute(
                "INSERT INTO items(key,value,updated_at) VALUES(?,?,strftime('%s','now')) "
                "ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at",
                (body["key"], body.get("value", "")),
            )
        return self._send({"ok": True, "key": body["key"]})

    def log_message(self, *a):  # quiet
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
