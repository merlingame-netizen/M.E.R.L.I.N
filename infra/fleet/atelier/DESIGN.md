# AtelierIAIdrac — off-Firebase backend (design)

Make the static app (`maximebabonneau/AtelierIAIdrac`, GitHub Pages) run **without Firebase**,
100% free, keeping real-time. Strategy: a **Firebase-compat shim** in the browser talking to a
**generic RTDB-like backend** on the free GCP VM, exposed over HTTPS/WSS via a **Cloudflare Tunnel**.

```
GitHub Pages (static front, unchanged except shim)
  → Cloudflare Tunnel (free HTTPS/WSS)
  → GCP e2-micro: Node backend (REST + WebSocket) over SQLite tree store
```

## Firebase API surface to reproduce (inventory of the 31 modules, 18.7k LOC)

RTDB: `ref` ×156 · `once` ×46 · `on('value')` ×19 + `on('child_added')` ×1 · `set` ×44 ·
`update` ×13 · `push` ×104 · `remove` ×66 · `transaction` ×8 · `child` ×3 ·
`orderByChild`+`equalTo`+`limitToLast` (a few) · `onDisconnect` ×1.
Storage: `put` ×4 · `getDownloadURL` ×4 (avatars / livebattle media).
Auth: `signInAnonymously` ×1 · `onAuthStateChanged` ×1 · `currentUser` ×2 (just needs a stable uid).
`ServerValue.TIMESTAMP`: not used (app uses `Date.now()` client-side).

Paths touched (root segments): promptmon, students, states, accounts, livebattle(+_content,+current),
config(dayLocks/unlocks/caseStudy), inbox, feedback, duel_queue/duel_notify/duels, votes, pvp,
avatarforge, announcements, activity_feed, submissions, reviews, highlight_scores, boss_scores,
owners, notifications, cases. → **arbitrary nested paths**, schemaless ⇒ backend must be a generic tree.

## Backend storage model (SQLite, generic RTDB tree)

Table `kv(path TEXT PRIMARY KEY, val TEXT, ver INTEGER)` storing **leaf** values only (path = full
`a/b/c`). A "node" = all rows with prefix `a/b/%`.
- **get(path)**: leaf → value; else reconstruct subtree from `path = p` OR `path LIKE p/%`.
- **set(path,obj)**: delete subtree, insert all leaves of `obj` (bump `ver`).
- **update(path,partial)**: set each child key.
- **push(path,val)**: `set(path/<pushId>, val)`, return pushId (Firebase chronological id).
- **remove(path)**: delete subtree.
- **transaction**: done in the **shim** (read → run client fn → conditional set via `ver` CAS);
  backend exposes a CAS write (`If-Match: ver`).
- **query** (`orderByChild(k).equalTo(v).limitToLast(n)`): read children, filter/sort/limit in JS (rare).

## Realtime (WebSocket)

Client subscribes `{op:'on', path, event:'value'|'child_added'}`. Server keeps subscriptions per
connection; on any write, notify subs whose `path` is an **ancestor-or-equal** of (or equal prefix
to) the changed path, sending the fresh value (or new child). `onDisconnect(path).set(v)`: server
records pending ops per connection and applies them on socket close (presence/online=false).

## Auth

`signInAnonymously()` → server returns a stable device uid (used by `owners/<key>` transaction to
claim the device). The real login is **client-side** (SHA-256 of `aia2|key|pw` vs `accounts/<key>.
passwordHash`) — unchanged; the shim just reads `accounts/...` like any path.

## Storage

`ref(p).put(blob)` → `POST /storage/<p>` (store file on VM disk under `/opt/atelier/storage`, or R2
if enabled). `getDownloadURL()` → `GET <tunnel>/storage/<p>`.

## Components (in this folder)

- `server/server.js` + `package.json` — the Node backend (REST + WS + SQLite tree + storage).
- `server/import-rtdb.js` — load the RTDB JSON export into the `kv` tree store.
- `web/firebase-shim.js` — browser drop-in implementing the surface above over REST+WS.
- `deploy/` — systemd unit + Cloudflare Tunnel (`cloudflared`) setup for the VM.
- Front wiring: in `index.html`, replace the 4 `firebase-*.js` scripts + init with `firebase-shim.js`
  pointing at the tunnel URL; add the tunnel host to the domain allowlist.

## Phases
1. ✅ API inventory (this doc).  2. Backend core (tree store + REST + WS + import).  3. Shim + local
test (login + chat).  4. Tunnel + VM deploy.  5. Full front switch + real-time tests.  6. Storage media.

## Free-tier
VM e2-micro (always-on) + GitHub Pages + Cloudflare Tunnel = 0 €. ~25 students → trivial load.
