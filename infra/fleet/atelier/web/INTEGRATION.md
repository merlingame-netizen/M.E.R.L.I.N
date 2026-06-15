# Front wiring — AtelierIAIdrac off Firebase

The app (`maximebabonneau/AtelierIAIdrac`, branch `master`, GitHub Pages) is static
client-side: `index.html` + 31 vanilla JS modules + Firebase **compat SDK v10.12**
(RTDB + Auth anon + Storage). `js/app.js > initFirebase()` does:

```js
if (!firebase.apps.length) firebase.initializeApp(CONFIG.firebaseConfig);
db = firebase.database();
window.AIA.db = db;
try { if (firebase.storage) window.AIA.storage = firebase.storage(); } catch (e) {}
if (firebase.auth) firebase.auth().signInAnonymously().catch(...);
```

`firebase-shim.js` exposes the **same** `firebase.database()/auth()/storage()` surface,
so **none of the 31 modules change**. Only `index.html` changes, and `app.js` keeps
working unmodified (the shim ignores `CONFIG.firebaseConfig` and uses `window.AIA_BACKEND`).

## The only edit: `index.html`

Find the four Firebase CDN tags near the end of `<body>` (just before `js/app.js`):

```html
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-database-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-auth-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-storage-compat.js"></script>
```

Replace those four lines with:

```html
<!-- Off-Firebase: self-hosted backend (REST + WebSocket over SQLite) via Cloudflare Tunnel -->
<script>window.AIA_BACKEND = "https://atelier.<your-domain-or-trycloudflare-host>";</script>
<script src="js/firebase-shim.js"></script>
```

Then copy `firebase-shim.js` into the app's `js/` folder:

```
cp infra/fleet/atelier/web/firebase-shim.js  <AtelierIAIdrac>/js/firebase-shim.js
```

That's it. `app.js` and the other 30 modules are untouched.

## Notes

- **Order matters**: the `window.AIA_BACKEND` `<script>` must come *before* `firebase-shim.js`,
  and the shim must come *before* `js/app.js` (same position the SDK held).
- **CORS**: the backend sends `Access-Control-Allow-Origin: *` (tighten to the Pages origin
  later if wanted). WebSocket isn't subject to CORS.
- **ServerValue.TIMESTAMP**: the shim sets it to `Date.now()` at load; the app already uses
  `Date.now()` for timestamps, so behaviour is unchanged.
- **Auth**: anonymous `uid` is generated client-side and persisted in `localStorage`
  (`aia_uid`). The app's own SHA-256 account auth (accounts in the DB) is unchanged — it
  reads/writes through the same RTDB paths.
- **Quick test first**: run `deploy/tunnel.sh quick` to get an instant
  `https://<random>.trycloudflare.com` URL, drop it into `window.AIA_BACKEND`, load the Pages
  site, and verify chat/presence/votes go live. Then switch to a `named` tunnel for a stable URL.

## Verifying real-time features

| Feature        | RTDB path (typical)        | Listener                 |
|----------------|----------------------------|--------------------------|
| Chat           | `chat/<room>/messages`     | `on('child_added')`      |
| Presence       | `presence/<uid>`           | `onDisconnect().remove()`|
| Livebattle     | `livebattle/<id>`          | `on('value')`            |
| Votes          | `livebattle/<id>/votes`    | `on('value')` / transaction |
| Activity/leaderboard | `activity`, `leaderboard` | `orderByChild().limitToLast()` |

All of these are covered by `server/shimtest.js` (15/15 pass).
