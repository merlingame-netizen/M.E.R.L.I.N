#!/usr/bin/env bash
# Deploy the AtelierIAIdrac off-Firebase backend on the GCP e2-micro VM.
# Run ON the VM (via GCP Console SSH), as a sudo-capable user. Idempotent.
#
#   bash deploy-vm.sh /path/to/idrac-rtdb-export.json
#
# Steps: install Node 22 (if needed) + ws deps, copy server -> /opt/atelier,
# build the tree DB from the RTDB JSON export, install + start the systemd
# service (loopback :8787). Cloudflare Tunnel is set up separately (tunnel.sh).
set -euo pipefail

RTDB_JSON="${1:-}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"   # .../infra/fleet/atelier
SRC_SERVER="$REPO_DIR/server"
SRC_WEB="$REPO_DIR/web"
APP_DIR="/opt/atelier"
DATA_DIR="/var/lib/atelier"
NODE_MIN_MAJOR=22

echo "==> AtelierIAIdrac backend deploy"
echo "    repo:   $REPO_DIR"
echo "    rtdb:   ${RTDB_JSON:-<none — will reuse existing tree DB if present>}"

# ── 1. Node >= 22.5 (node:sqlite) ────────────────────────────────────────────
need_node=1
if command -v node >/dev/null 2>&1; then
  maj="$(node -p 'process.versions.node.split(".")[0]')"
  min="$(node -p 'process.versions.node.split(".")[1]')"
  if [ "$maj" -gt "$NODE_MIN_MAJOR" ] || { [ "$maj" -eq "$NODE_MIN_MAJOR" ] && [ "$min" -ge 5 ]; }; then need_node=0; fi
fi
if [ "$need_node" -eq 1 ]; then
  echo "==> Installing Node 22 (official tarball, no apt)"
  arch="$(uname -m)"; case "$arch" in x86_64) na=x64;; aarch64|arm64) na=arm64;; *) echo "unsupported arch $arch"; exit 1;; esac
  ver="v22.13.1"
  tmp="$(mktemp -d)"
  curl -fsSL "https://nodejs.org/dist/$ver/node-$ver-linux-$na.tar.xz" -o "$tmp/node.tar.xz"
  sudo mkdir -p /opt/node && sudo tar -xJf "$tmp/node.tar.xz" -C /opt/node --strip-components=1
  sudo ln -sf /opt/node/bin/node /usr/bin/node
  sudo ln -sf /opt/node/bin/npm  /usr/bin/npm
  rm -rf "$tmp"
fi
echo "    node $(node -v)"

# ── 2. Place app + install deps ──────────────────────────────────────────────
echo "==> Installing app to $APP_DIR"
sudo mkdir -p "$APP_DIR/server" "$APP_DIR/web" "$DATA_DIR/storage"
sudo cp "$SRC_SERVER"/{server.js,store.js,import-rtdb.js,package.json} "$APP_DIR/server/"
sudo cp "$SRC_WEB"/firebase-shim.js "$APP_DIR/web/"
( cd "$APP_DIR/server" && sudo npm install --omit=dev --no-audit --no-fund )

# ── 3. Build the tree DB from the RTDB JSON export ───────────────────────────
TREE_DB="$DATA_DIR/atelier-idrac-tree.db"
if [ -n "$RTDB_JSON" ]; then
  echo "==> Importing RTDB export -> $TREE_DB"
  [ -f "$RTDB_JSON" ] || { echo "RTDB JSON not found: $RTDB_JSON"; exit 1; }
  sudo node --experimental-sqlite "$APP_DIR/server/import-rtdb.js" "$RTDB_JSON" "$TREE_DB"
elif [ ! -f "$TREE_DB" ]; then
  echo "!! No RTDB JSON given and no existing tree DB at $TREE_DB."
  echo "   Re-run with the export path:  bash deploy-vm.sh ~/idrac-rtdb-export.json"
  exit 1
else
  echo "==> Reusing existing tree DB $TREE_DB"
fi

# ── 4. systemd service ───────────────────────────────────────────────────────
echo "==> Installing systemd unit"
sudo cp "$REPO_DIR/deploy/atelier-backend.service" /etc/systemd/system/atelier-backend.service
sudo systemctl daemon-reload
sudo systemctl enable --now atelier-backend.service
sleep 2
sudo systemctl --no-pager --full status atelier-backend.service | head -n 12 || true

# ── 5. Smoke ────────────────────────────────────────────────────────────────
echo "==> Local health check"
curl -fsS http://127.0.0.1:8787/health && echo
echo "==> Done. Backend on 127.0.0.1:8787. Next: bash deploy/tunnel.sh"
