#!/usr/bin/env bash
# Expose the backend (127.0.0.1:8787) over HTTPS/WSS with Cloudflare Tunnel — free,
# no open inbound port, no TLS cert to manage. Run ON the VM after deploy-vm.sh.
#
# Two modes:
#   bash tunnel.sh quick           # ephemeral *.trycloudflare.com URL, no login (testing)
#   bash tunnel.sh named <name>    # stable URL under your Cloudflare account (production)
#
# WebSocket (wss://) is proxied automatically — the shim derives wss from the https URL.
set -euo pipefail
MODE="${1:-quick}"
NAME="${2:-atelier}"
LOCAL_URL="http://127.0.0.1:8787"

install_cloudflared() {
  if command -v cloudflared >/dev/null 2>&1; then return; fi
  echo "==> Installing cloudflared"
  arch="$(uname -m)"; case "$arch" in x86_64) ca=amd64;; aarch64|arm64) ca=arm64;; *) echo "unsupported $arch"; exit 1;; esac
  curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ca" -o /tmp/cloudflared
  sudo install -m 0755 /tmp/cloudflared /usr/local/bin/cloudflared && rm -f /tmp/cloudflared
}

install_cloudflared
echo "    cloudflared $(cloudflared --version 2>/dev/null | head -n1)"

case "$MODE" in
  quick)
    echo "==> Ephemeral tunnel (URL changes each run). Ctrl-C to stop."
    echo "    Copy the printed https://<random>.trycloudflare.com into the front's window.AIA_BACKEND."
    exec cloudflared tunnel --no-autoupdate --url "$LOCAL_URL"
    ;;
  named)
    # Stable URL. Requires a one-time browser login (cloudflared tunnel login) on a
    # machine you can open the link from; the cert is then reused headless here.
    if [ ! -f "$HOME/.cloudflared/cert.pem" ]; then
      echo "!! Run 'cloudflared tunnel login' once (opens a browser) to authorize this VM,"
      echo "   then re-run: bash tunnel.sh named $NAME"
      exit 1
    fi
    cloudflared tunnel create "$NAME" 2>/dev/null || echo "   (tunnel '$NAME' already exists)"
    TID="$(cloudflared tunnel list -o json | node -pe 'JSON.parse(require("fs").readFileSync(0)).find(t=>t.name===process.argv[1]).id' "$NAME")"
    echo "==> Tunnel id $TID"
    echo "    Set a DNS route (once):  cloudflared tunnel route dns $NAME atelier.<your-domain>"
    cat > "$HOME/.cloudflared/config.yml" <<YAML
tunnel: $TID
credentials-file: $HOME/.cloudflared/$TID.json
ingress:
  - hostname: atelier.<your-domain>
    service: $LOCAL_URL
  - service: http_status:404
YAML
    echo "==> Installing cloudflared as a service (auto-start)"
    sudo cloudflared --config "$HOME/.cloudflared/config.yml" service install || true
    sudo systemctl enable --now cloudflared || true
    echo "==> Done. Stable URL: https://atelier.<your-domain> -> window.AIA_BACKEND"
    ;;
  *) echo "usage: tunnel.sh [quick | named <name>]"; exit 1;;
esac
