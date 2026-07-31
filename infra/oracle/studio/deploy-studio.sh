#!/usr/bin/env bash
# Deploy MERLIN Studio on the personal Oracle ARM A1 VM (dev dashboard for the game).
# Run ON the VM, from the cloned repo:
#   cd ~/workspace/M.E.R.L.I.N && bash infra/oracle/studio/deploy-studio.sh
#
# Idempotent: venv (flask) -> 0600 auth token -> systemd unit on 127.0.0.1:8790 -> health.
# Expose it with (tunnel Cloudflare, aucun port ouvert) :
#   TUNNEL_PORT=8790 bash infra/fleet/atelier/deploy/tunnel.sh quick
# (infra/oracle/scripts/tunnel.sh est un port-forward SSH depuis le PC : il expose
#  aussi 8790, mais exige un acces SSH sortant vers la VM.)
set -euo pipefail

REPO_DIR="$(cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || echo "$(dirname "$0")/../../..")" && pwd)"
RUN_USER="$(id -un)"
VENV="${STUDIO_VENV:-$REPO_DIR/.venv}"
ENV_FILE="/etc/merlin-studio.env"
UNIT="/etc/systemd/system/merlin-studio.service"
PORT=8790

echo "==> MERLIN Studio deploy"
echo "    repo: $REPO_DIR"
echo "    user: $RUN_USER"

# ── 1. venv + flask (reuse the cloud-init venv if present) ───────────────────
if [ ! -x "$VENV/bin/python" ]; then
  echo "==> Creating venv $VENV"
  sudo apt-get install -y python3-venv >/dev/null 2>&1 || true
  python3 -m venv "$VENV"
fi
"$VENV/bin/pip" install -q --upgrade pip >/dev/null 2>&1 || true
"$VENV/bin/pip" install -q flask >/dev/null
echo "    venv ok ($("$VENV/bin/python" -c 'import flask,sys;print("flask",flask.__version__ if hasattr(flask,"__version__") else "ok")' 2>/dev/null || echo flask))"

# ── 2. auth token (generated once, 0600) ────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
  TOKEN="$(openssl rand -hex 24 2>/dev/null || head -c 32 /dev/urandom | base64 | tr -dc 'a-f0-9' | head -c 48)"
  printf 'STUDIO_TOKEN=%s\nSTUDIO_USER=merlin\nOLLAMA_URL=http://127.0.0.1:11434\n' "$TOKEN" \
    | sudo tee "$ENV_FILE" >/dev/null
  sudo chmod 600 "$ENV_FILE"
  echo "==> Token généré -> $ENV_FILE"
else
  echo "==> Réutilise $ENV_FILE"
fi
TOKEN_SHOWN="$(sudo sed -n 's/^STUDIO_TOKEN=//p' "$ENV_FILE")"

# ── 3. systemd unit ─────────────────────────────────────────────────────────
echo "==> Installing systemd unit"
sed -e "s#__REPO_DIR__#$REPO_DIR#g" -e "s#__USER__#$RUN_USER#g" -e "s#__VENV__#$VENV#g" \
    "$REPO_DIR/infra/oracle/studio/merlin-studio.service" | sudo tee "$UNIT" >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now merlin-studio.service
sleep 2
sudo systemctl --no-pager --full status merlin-studio.service | head -n 10 || true

# ── 4. health ───────────────────────────────────────────────────────────────
echo "==> Health check"
curl -fsS "http://127.0.0.1:$PORT/healthz" && echo
echo
echo "==> Studio up on 127.0.0.1:$PORT (Basic auth, user 'merlin')."
echo "    Token: $TOKEN_SHOWN"
echo "    Exposer :  TUNNEL_PORT=$PORT bash $REPO_DIR/infra/fleet/atelier/deploy/tunnel.sh quick"
echo "    Logs    :  journalctl -u merlin-studio -f"
