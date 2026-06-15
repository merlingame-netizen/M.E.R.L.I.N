# Deploy — AtelierIAIdrac off-Firebase backend on the free GCP e2-micro VM

End-to-end runbook to make AtelierIAIdrac run **without Firebase**, 100 % free, keeping
real-time (chat, presence, livebattle + votes, activity/leaderboard).

```
Front (GitHub Pages, static, only index.html changed)
   │  https / wss
   ▼  Cloudflare Tunnel (free, HTTPS/WSS, no open port, no cert)
   ▼  GCP e2-micro (free, always-on):
       systemd: atelier-backend  =  Node REST + WebSocket over SQLite tree
       data: /var/lib/atelier (tree DB built from the RTDB JSON export + uploaded media)
```

## Why the sandbox can't do this for you

The container's egress blocks SSH (port 22) to the VM, so the agent cannot deploy directly.
Everything below runs **on the VM via the GCP Console browser SSH** (which bypasses the
corporate port-22 block). All artifacts are prepared and tested here — the steps are turnkey.

## Prerequisites on the VM

- The MERLIN repo cloned on the VM (for `server.js` / `store.js` / this `deploy/`):
  ```
  git clone https://github.com/merlingame-netizen/M.E.R.L.I.N.git ~/merlin
  cd ~/merlin/infra/fleet/atelier
  ```
- The **RTDB JSON export** on the VM (the same `idrac-...-rtdb-export.json` already fetched
  during the data migration — `~/idrac-rtdb-export.json`). The backend's tree DB is built
  from this, **not** from the relational `atelier-idrac.db` made for the D1 migration.

## 1. Backend (Node + SQLite + systemd)

```bash
cd ~/merlin/infra/fleet/atelier
bash deploy/deploy-vm.sh ~/idrac-rtdb-export.json
```

Installs Node 22 if needed, copies the server to `/opt/atelier`, builds
`/var/lib/atelier/atelier-idrac-tree.db`, installs+starts the `atelier-backend` service on
`127.0.0.1:8787`, and curls `/health`. Re-runnable (idempotent).

Check it any time:
```bash
systemctl status atelier-backend
curl -s http://127.0.0.1:8787/health        # -> {"ok":true,"store":"sqlite-tree"}
journalctl -u atelier-backend -n 50 --no-pager
```

## 2. Public HTTPS/WSS (Cloudflare Tunnel)

Quick test (instant, no login, ephemeral URL):
```bash
bash deploy/tunnel.sh quick
# -> prints https://<random>.trycloudflare.com  (keep this terminal open)
```

Stable production URL (one-time browser login, then headless + auto-start):
```bash
cloudflared tunnel login                      # opens a browser link once
bash deploy/tunnel.sh named atelier
cloudflared tunnel route dns atelier atelier.<your-domain>
```

## 3. Front wiring (AtelierIAIdrac repo)

See [`../web/INTEGRATION.md`](../web/INTEGRATION.md). One edit in `index.html` (swap the 4
Firebase CDN scripts for `window.AIA_BACKEND` + `js/firebase-shim.js`) and copy
`firebase-shim.js` into `js/`. Commit + push → GitHub Pages redeploys.

## 4. Verify

- Open the Pages site. DevTools console: no Firebase CDN, WS connects to your tunnel host.
- Two browsers: chat message appears live; presence toggles on tab close (`onDisconnect`);
  a livebattle vote updates both; leaderboard/activity refresh.
- `journalctl -u atelier-backend -f` shows the REST writes / WS subs.

## Cost & safety (stay free, always)

- e2-micro (us-west1/us-central1/us-east1) + Pages + Cloudflare Tunnel are all $0.
- Tunnel = no inbound port open on the VM; the backend binds loopback only.
- The `google_billing_budget` (1-unit alert) from `infra/fleet/gcp` guards against any spend.
- **Clean up the Firebase admin key** left on the VM from the migration:
  ```bash
  rm -f ~/*firebase-adminsdk*.json
  ```

## Files

| File | Role |
|---|---|
| `deploy/deploy-vm.sh` | Node 22 + deps + tree-DB import + systemd service |
| `deploy/atelier-backend.service` | systemd unit (loopback :8787, hardened) |
| `deploy/tunnel.sh` | Cloudflare Tunnel — `quick` (ephemeral) or `named` (stable) |
| `server/{server.js,store.js,import-rtdb.js}` | backend (tested) |
| `web/firebase-shim.js` | drop-in Firebase-compat client (15/15 shimtest) |
| `web/INTEGRATION.md` | exact `index.html` edit |
