"use strict";
// AtelierIAIdrac off-Firebase backend: REST (CRUD) + WebSocket (realtime) over a
// generic RTDB-like SQLite tree. Run: node --experimental-sqlite server.js
const http = require("http");
const fs = require("fs");
const path = require("path");
const { WebSocketServer } = require("ws");
const { Store, normPath } = require("./store");

const PORT = process.env.PORT || 8787;
const DB_FILE = process.env.DB_FILE || path.join(process.env.HOME || ".", "atelier-idrac.db");
const STORAGE = process.env.STORAGE_DIR || path.join(process.env.HOME || ".", "atelier-storage");
fs.mkdirSync(STORAGE, { recursive: true });

const store = new Store(DB_FILE);

// ── realtime registry ────────────────────────────────────────────────────────
const conns = new Set(); // each: {ws, subs: Map<id,{path,event,seen:Set}>, onDisc: []}

function related(a, b) { return a === b || a.startsWith(b + "/") || b.startsWith(a + "/"); }

function notify(changedPath) {
  changedPath = normPath(changedPath);
  for (const c of conns) {
    for (const [id, s] of c.subs) {
      if (!related(s.path, changedPath)) continue;
      if (s.event === "child_added") {
        const node = store.get(s.path) || {};
        for (const k of Object.keys(node)) {
          if (!s.seen.has(k)) { s.seen.add(k); send(c.ws, { t: "child_added", id, key: k, value: node[k] }); }
        }
      } else {
        send(c.ws, { t: "val", id, value: store.get(s.path) });
      }
    }
  }
}
function send(ws, obj) { try { ws.send(JSON.stringify(obj)); } catch {} }

// ── HTTP helpers ─────────────────────────────────────────────────────────────
function cors(res, origin) {
  res.setHeader("Access-Control-Allow-Origin", origin || "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,PUT,PATCH,POST,DELETE,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "content-type,if-match");
  res.setHeader("Access-Control-Expose-Headers", "x-ver");
}
function readBody(req) {
  return new Promise((resolve) => {
    const chunks = [];
    req.on("data", (d) => chunks.push(d));
    req.on("end", () => resolve(Buffer.concat(chunks)));
  });
}
function json(res, code, obj) { res.writeHead(code, { "content-type": "application/json" }); res.end(JSON.stringify(obj)); }

const server = http.createServer(async (req, res) => {
  const origin = req.headers.origin;
  cors(res, origin);
  if (req.method === "OPTIONS") { res.writeHead(204); return res.end(); }
  const url = new URL(req.url, "http://x");
  const seg = url.pathname.split("/").filter(Boolean);
  const kind = seg.shift();
  const p = normPath(seg.map(decodeURIComponent).join("/"));

  try {
    if (kind === "health") return json(res, 200, { ok: true, store: "sqlite-tree" });

    if (kind === "db") {
      if (req.method === "GET") return json(res, 200, { value: store.get(p), ver: store.ver(p) });
      if (req.method === "PUT") {
        const body = JSON.parse((await readBody(req)).toString() || "null");
        const ifMatch = req.headers["if-match"];
        if (ifMatch !== undefined) {
          const ok = store.casSet(p, body, ifMatch);
          if (!ok) return json(res, 412, { error: "version mismatch", ver: store.ver(p) });
        } else store.set(p, body);
        notify(p); return json(res, 200, { ver: store.ver(p) });
      }
      if (req.method === "PATCH") { store.update(p, JSON.parse((await readBody(req)).toString() || "{}")); notify(p); return json(res, 200, { ok: true }); }
      if (req.method === "POST") { const id = store.push(p, JSON.parse((await readBody(req)).toString() || "null")); notify(p); return json(res, 200, { name: id }); }
      if (req.method === "DELETE") { store.remove(p); notify(p); return json(res, 200, { ok: true }); }
    }

    if (kind === "query" && req.method === "POST") {
      const q = JSON.parse((await readBody(req)).toString() || "{}");
      return json(res, 200, { value: store.query(p, q) });
    }

    if (kind === "storage") {
      const fp = path.join(STORAGE, p.replace(/\.\./g, ""));
      if (req.method === "PUT" || req.method === "POST") {
        fs.mkdirSync(path.dirname(fp), { recursive: true });
        fs.writeFileSync(fp, await readBody(req));
        return json(res, 200, { url: `/storage/${p}` });
      }
      if (req.method === "GET") {
        if (!fs.existsSync(fp)) { res.writeHead(404); return res.end(); }
        res.writeHead(200); return res.end(fs.readFileSync(fp));
      }
    }

    res.writeHead(404); res.end("not found");
  } catch (e) { json(res, 500, { error: String(e) }); }
});

// ── WebSocket realtime ───────────────────────────────────────────────────────
const wss = new WebSocketServer({ server });
wss.on("connection", (ws) => {
  const c = { ws, subs: new Map(), onDisc: [] };
  conns.add(c);
  ws.on("message", (raw) => {
    let m; try { m = JSON.parse(raw); } catch { return; }
    if (m.t === "sub") {
      const s = { path: normPath(m.path), event: m.event || "value", seen: new Set() };
      c.subs.set(m.id, s);
      if (s.event === "child_added") {
        const node = store.get(s.path) || {};
        for (const k of Object.keys(node)) { s.seen.add(k); send(ws, { t: "child_added", id: m.id, key: k, value: node[k] }); }
      } else send(ws, { t: "val", id: m.id, value: store.get(s.path) });
    } else if (m.t === "unsub") { c.subs.delete(m.id); }
    else if (m.t === "onDisconnect") { c.onDisc.push({ path: normPath(m.path), value: m.value }); }
    else if (m.t === "cancelDisconnect") { c.onDisc = []; }
  });
  ws.on("close", () => {
    for (const op of c.onDisc) {
      if (op.value === null) store.remove(op.path); else store.set(op.path, op.value);
      notify(op.path);
    }
    conns.delete(c);
  });
});

server.listen(PORT, () => console.log(`atelier backend on :${PORT}  db=${DB_FILE}  storage=${STORAGE}`));
