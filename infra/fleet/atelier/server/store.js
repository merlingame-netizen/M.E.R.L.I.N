"use strict";
// Generic Firebase-RTDB-like tree store over SQLite (node:sqlite).
// Leaf rows: kv(path PRIMARY KEY, val JSON, ver). A "node" = rows under `path/%`.
const { DatabaseSync } = require("node:sqlite");

const PUSH_CHARS = "-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz";

function normPath(p) {
  return String(p || "").replace(/^\/+|\/+$/g, "").replace(/\/+/g, "/");
}

class Store {
  constructor(file) {
    this.db = new DatabaseSync(file);
    this.db.exec(
      "CREATE TABLE IF NOT EXISTS kv (path TEXT PRIMARY KEY, val TEXT, ver INTEGER DEFAULT 1);" +
      "CREATE INDEX IF NOT EXISTS kv_prefix ON kv(path);"
    );
    this._lastPush = 0;
    this._lastRand = [];
  }

  // Firebase-style chronological push id (sortable).
  pushId() {
    let now = Date.now();
    const dup = now === this._lastPush;
    this._lastPush = now;
    const ts = new Array(8);
    for (let i = 7; i >= 0; i--) { ts[i] = PUSH_CHARS.charAt(now % 64); now = Math.floor(now / 64); }
    let id = ts.join("");
    if (!dup) { for (let i = 0; i < 12; i++) this._lastRand[i] = Math.floor(Math.random() * 64); }
    else { let i = 11; for (; i >= 0 && this._lastRand[i] === 63; i--) this._lastRand[i] = 0; this._lastRand[i]++; }
    for (let i = 0; i < 12; i++) id += PUSH_CHARS.charAt(this._lastRand[i]);
    return id;
  }

  // Read a path -> JS value (scalar leaf, or reconstructed object subtree, or null).
  get(path) {
    path = normPath(path);
    if (path === "") return this._subtree("");
    const leaf = this.db.prepare("SELECT val FROM kv WHERE path=?").get(path);
    if (leaf) return JSON.parse(leaf.val);
    return this._subtree(path);
  }

  _subtree(prefix) {
    const like = prefix === "" ? "%" : prefix + "/%";
    const rows = this.db.prepare("SELECT path,val FROM kv WHERE path LIKE ?").all(like);
    if (rows.length === 0) return null;
    const root = {};
    const cut = prefix === "" ? 0 : prefix.length + 1;
    for (const r of rows) {
      const rel = r.path.slice(cut).split("/");
      let o = root;
      for (let i = 0; i < rel.length - 1; i++) o = (o[rel[i]] ??= {});
      o[rel[rel.length - 1]] = JSON.parse(r.val);
    }
    return root;
  }

  _delSubtree(path) {
    if (path === "") { this.db.exec("DELETE FROM kv"); return; }
    this.db.prepare("DELETE FROM kv WHERE path=? OR path LIKE ?").run(path, path + "/%");
  }

  // Flatten a JS value into leaf rows under `base`, writing them.
  _writeLeaves(base, val, ver) {
    const ins = this.db.prepare("INSERT INTO kv(path,val,ver) VALUES(?,?,?) " +
      "ON CONFLICT(path) DO UPDATE SET val=excluded.val, ver=excluded.ver");
    const walk = (p, v) => {
      if (v === null || v === undefined) return;
      if (typeof v === "object" && !Array.isArray(v) && Object.keys(v).length) {
        for (const k of Object.keys(v)) walk(p ? p + "/" + k : k, v[k]);
      } else {
        ins.run(p, JSON.stringify(v), ver);
      }
    };
    walk(base, val);
  }

  set(path, val) {
    path = normPath(path);
    this._delSubtree(path);
    const ver = Date.now();
    this._writeLeaves(path, val, ver);
    return ver;
  }

  update(path, partial) {
    path = normPath(path);
    if (partial && typeof partial === "object") {
      for (const k of Object.keys(partial)) {
        const child = (path ? path + "/" : "") + k;
        if (partial[k] === null) this._delSubtree(child);
        else this.set(child, partial[k]);
      }
    }
    return Date.now();
  }

  push(path, val) {
    const id = this.pushId();
    this.set(normPath(path) + "/" + id, val);
    return id;
  }

  remove(path) { this._delSubtree(normPath(path)); return Date.now(); }

  // version of a path (max ver of its leaves) for CAS / transaction
  ver(path) {
    path = normPath(path);
    const r = this.db.prepare("SELECT MAX(ver) v FROM kv WHERE path=? OR path LIKE ?").get(path, path + "/%");
    return (r && r.v) || 0;
  }

  // conditional set (transaction commit): only write if current ver matches.
  casSet(path, val, expectedVer) {
    if (this.ver(path) !== Number(expectedVer)) return false;
    this.set(path, val);
    return true;
  }

  // minimal query: orderByChild(child).equalTo(v) / limitToLast(n) over a node's children
  query(path, { orderByChild, equalTo, limitToLast } = {}) {
    const node = this.get(path) || {};
    let entries = Object.entries(node);
    if (orderByChild !== undefined && equalTo !== undefined)
      entries = entries.filter(([, v]) => v && v[orderByChild] === equalTo);
    if (orderByChild) entries.sort((a, b) => ((a[1]?.[orderByChild] > b[1]?.[orderByChild]) ? 1 : -1));
    else entries.sort((a, b) => (a[0] > b[0] ? 1 : -1));
    if (limitToLast) entries = entries.slice(-limitToLast);
    return Object.fromEntries(entries);
  }
}

module.exports = { Store, normPath };
