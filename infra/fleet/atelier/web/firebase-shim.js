/*! AtelierIAIdrac — Firebase-compat shim (RTDB + Auth + Storage) over the self-hosted
 *  backend (REST + WebSocket). Drop-in for the firebase compat SDK subset the app uses.
 *  Set window.AIA_BACKEND = "https://<tunnel-host>" BEFORE loading this file.
 *  Then call firebase.initializeApp({}) like before. */
(function (global) {
  "use strict";
  var LS = global.localStorage || { getItem: function () { return null; }, setItem: function () {} };
  var BASE = "", WSURL = "";

  function clean(p) { return String(p == null ? "" : p).replace(/^\/+|\/+$/g, "").replace(/\/+/g, "/"); }
  function join() { return clean(Array.prototype.filter.call(arguments, function (s) { return s != null && s !== ""; }).join("/")); }
  function enc(p) { return clean(p).split("/").filter(Boolean).map(encodeURIComponent).join("/"); }

  // Firebase-style chronological push id (client-side, like the real SDK).
  var PC = "-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz", lastT = 0, lastR = [];
  function pushId() {
    var now = Date.now(), dup = now === lastT; lastT = now;
    var id = "", t = new Array(8), i;
    for (i = 7; i >= 0; i--) { t[i] = PC.charAt(now % 64); now = Math.floor(now / 64); }
    id = t.join("");
    if (!dup) { for (i = 0; i < 12; i++) lastR[i] = Math.floor(Math.random() * 64); }
    else { for (i = 11; i >= 0 && lastR[i] === 63; i--) lastR[i] = 0; lastR[i]++; }
    for (i = 0; i < 12; i++) id += PC.charAt(lastR[i]);
    return id;
  }

  // ── WebSocket (shared) ──────────────────────────────────────────────────────
  var ws = null, ready = false, q = [], subs = new Map(), nextId = 1;
  function ensureWS() {
    if (ws) return;
    ws = new global.WebSocket(WSURL);
    ws.onopen = function () { ready = true; q.forEach(function (m) { ws.send(m); }); q = []; };
    ws.onclose = function () { ws = null; ready = false; setTimeout(reconnect, 1000); };
    ws.onerror = function () { try { ws.close(); } catch (e) {} };
    ws.onmessage = function (e) {
      var m; try { m = JSON.parse(e.data); } catch (x) { return; }
      var s = subs.get(m.id); if (!s) return;
      if (m.t === "val") s.cb(new Snapshot(s.path.split("/").pop() || null, m.value));
      else if (m.t === "child_added") s.cb(new Snapshot(m.key, m.value));
    };
  }
  function wsSend(o) { ensureWS(); var m = JSON.stringify(o); if (ready) ws.send(m); else q.push(m); }
  function reconnect() { if (!subs.size) { ws = null; return; } ensureWS(); subs.forEach(function (s, id) { wsSend({ t: "sub", id: id, path: s.path, event: s.event }); }); }

  // ── Snapshot ────────────────────────────────────────────────────────────────
  function Snapshot(key, value) { this.key = key; this._v = value; }
  Snapshot.prototype.val = function () { return this._v === undefined ? null : this._v; };
  Snapshot.prototype.exists = function () { return this._v != null; };
  Snapshot.prototype.child = function (k) { var v = this._v && typeof this._v === "object" ? this._v[k] : null; return new Snapshot(k, v == null ? null : v); };
  Snapshot.prototype.hasChild = function (k) { return !!(this._v && typeof this._v === "object" && k in this._v); };
  Snapshot.prototype.numChildren = function () { return this._v && typeof this._v === "object" ? Object.keys(this._v).length : 0; };
  Snapshot.prototype.forEach = function (fn) {
    if (this._v && typeof this._v === "object") {
      var ks = Object.keys(this._v);
      for (var i = 0; i < ks.length; i++) { if (fn(new Snapshot(ks[i], this._v[ks[i]])) === true) return true; }
    }
    return false;
  };

  function applyQuery(node, qy) {
    if (!node || typeof node !== "object") return node;
    var e = Object.entries(node);
    if (qy.orderByChild && qy.equalTo !== undefined) e = e.filter(function (kv) { return kv[1] && kv[1][qy.orderByChild] === qy.equalTo; });
    e.sort(function (a, b) { return a[0] < b[0] ? -1 : 1; });
    if (qy.limitToLast) e = e.slice(-qy.limitToLast);
    var o = {}; e.forEach(function (kv) { o[kv[0]] = kv[1]; }); return o;
  }

  // ── Reference / Query ───────────────────────────────────────────────────────
  function Ref(path, qy) { this.path = clean(path); this.key = this.path.split("/").pop() || null; this._q = qy || {}; }
  Ref.prototype.child = function (p) { return new Ref(join(this.path, p)); };
  Object.defineProperty(Ref.prototype, "parent", { get: function () { var pp = this.path.split("/").slice(0, -1).join("/"); return pp ? new Ref(pp) : null; } });
  Ref.prototype.orderByChild = function (k) { return new Ref(this.path, Object.assign({}, this._q, { orderByChild: k })); };
  Ref.prototype.orderByKey = function () { return new Ref(this.path, Object.assign({}, this._q, { orderByKey: true })); };
  Ref.prototype.equalTo = function (v) { return new Ref(this.path, Object.assign({}, this._q, { equalTo: v })); };
  Ref.prototype.limitToLast = function (n) { return new Ref(this.path, Object.assign({}, this._q, { limitToLast: n })); };

  Ref.prototype.set = function (v) { return fetch(BASE + "/db/" + enc(this.path), { method: "PUT", headers: { "content-type": "application/json" }, body: JSON.stringify(v === undefined ? null : v) }).then(function () {}); };
  Ref.prototype.update = function (v) { return fetch(BASE + "/db/" + enc(this.path), { method: "PATCH", headers: { "content-type": "application/json" }, body: JSON.stringify(v || {}) }).then(function () {}); };
  Ref.prototype.remove = function () { return fetch(BASE + "/db/" + enc(this.path), { method: "DELETE" }).then(function () {}); };
  Ref.prototype.push = function (v) {
    var id = pushId(), full = join(this.path, id), ref = new Ref(full);
    var p = v === undefined ? Promise.resolve() : ref.set(v);
    // Awaitable like Firebase's ThenableReference. Resolve with a *fresh* (non-thenable)
    // Ref so the Promise machinery doesn't re-assimilate `ref` (which has `.then`) forever.
    ref.then = function (res, rej) { return p.then(function () { res(new Ref(full)); }, rej); };
    ref.catch = function (rej) { return p.catch(rej); };
    return ref;
  };
  Ref.prototype.transaction = function (fn) {
    var self = this;
    function attempt(n) {
      return fetch(BASE + "/db/" + enc(self.path)).then(function (r) { return r.json(); }).then(function (j) {
        var next = fn(j.value);
        if (next === undefined) return { committed: false, snapshot: new Snapshot(self.key, j.value) };
        return fetch(BASE + "/db/" + enc(self.path), { method: "PUT", headers: { "content-type": "application/json", "if-match": String(j.ver) }, body: JSON.stringify(next) })
          .then(function (w) { if (w.status === 412) { if (n > 25) throw new Error("transaction retries"); return attempt(n + 1); } return { committed: true, snapshot: new Snapshot(self.key, next) }; });
      });
    }
    return attempt(0);
  };
  Ref.prototype.once = function (event) {
    var self = this;
    if (this._q.orderByChild || this._q.limitToLast || this._q.orderByKey) {
      return fetch(BASE + "/query/" + enc(this.path), { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(this._q) })
        .then(function (r) { return r.json(); }).then(function (j) { return new Snapshot(self.key, j.value); });
    }
    return fetch(BASE + "/db/" + enc(this.path)).then(function (r) { return r.json(); }).then(function (j) { return new Snapshot(self.key, j.value); });
  };
  Ref.prototype.on = function (event, cb) {
    var qy = this._q, id = nextId++, ev = event === "child_added" ? "child_added" : "value";
    var wrapped = (qy.orderByChild || qy.limitToLast) && ev === "value"
      ? function (snap) { cb(new Snapshot(snap.key, applyQuery(snap.val(), qy))); }
      : cb;
    subs.set(id, { path: this.path, event: ev, cb: wrapped });
    wsSend({ t: "sub", id: id, path: this.path, event: ev });
    cb._aiaSub = (cb._aiaSub || []); cb._aiaSub.push(id);
    return cb;
  };
  Ref.prototype.off = function (event, cb) {
    var self = this;
    if (cb && cb._aiaSub) { cb._aiaSub.forEach(function (id) { wsSend({ t: "unsub", id: id }); subs.delete(id); }); cb._aiaSub = []; return; }
    subs.forEach(function (s, id) { if (s.path === self.path) { wsSend({ t: "unsub", id: id }); subs.delete(id); } });
  };
  Ref.prototype.onDisconnect = function () {
    var path = this.path;
    return {
      set: function (v) { wsSend({ t: "onDisconnect", path: path, value: v }); return Promise.resolve(); },
      remove: function () { wsSend({ t: "onDisconnect", path: path, value: null }); return Promise.resolve(); },
      update: function (v) { wsSend({ t: "onDisconnect", path: path, value: v }); return Promise.resolve(); },
      cancel: function () { wsSend({ t: "cancelDisconnect" }); return Promise.resolve(); }
    };
  };

  // ── Auth (anonymous device uid) ────────────────────────────────────────────
  var uid = LS.getItem("aia_uid") || (global.crypto && global.crypto.randomUUID ? global.crypto.randomUUID() : "u" + Math.random().toString(36).slice(2));
  LS.setItem("aia_uid", uid);
  var user = { uid: uid, isAnonymous: true };
  function auth() {
    return {
      get currentUser() { return user; },
      signInAnonymously: function () { return Promise.resolve({ user: user }); },
      onAuthStateChanged: function (cb) { setTimeout(function () { cb(user); }, 0); return function () {}; }
    };
  }

  // ── Storage ────────────────────────────────────────────────────────────────
  function storageRef(p) {
    return {
      put: function (data) { return fetch(BASE + "/storage/" + enc(p), { method: "PUT", body: data }).then(function () { return { ref: storageRef(p), metadata: {} }; }); },
      putString: function (s) { return fetch(BASE + "/storage/" + enc(p), { method: "PUT", body: s }).then(function () { return { ref: storageRef(p) }; }); },
      getDownloadURL: function () { return Promise.resolve(BASE + "/storage/" + enc(p)); },
      child: function (c) { return storageRef(join(p, c)); },
      fullPath: clean(p)
    };
  }
  function storage() { return { ref: function (p) { return storageRef(p || ""); } }; }

  // ── database() + firebase global ────────────────────────────────────────────
  function database() { return { ref: function (p) { return new Ref(p || ""); }, goOnline: function () {}, goOffline: function () {} }; }
  database.ServerValue = { TIMESTAMP: Date.now() }; // app uses Date.now() anyway

  global.firebase = {
    initializeApp: function (cfg) {
      BASE = (global.AIA_BACKEND || (cfg && cfg.backendUrl) || "").replace(/\/+$/, "");
      WSURL = BASE.replace(/^http/, "ws");
      if (!BASE) console.warn("[aia-shim] set window.AIA_BACKEND to your backend URL");
      return {};
    },
    database: database, auth: auth, storage: storage,
    apps: [{}]
  };
  global.firebase.database.ServerValue = { TIMESTAMP: Date.now() };
})(typeof window !== "undefined" ? window : globalThis);
