#!/usr/bin/env bash
# Deploy the MERLIN dev cockpit (fleet hub) 24/7 on the GCP e2-micro VM.
# Run ON the VM (GCP Console SSH), from a clone of the MERLIN repo:
#   cd ~/merlin && bash infra/fleet/cockpit/deploy-cockpit.sh
# Idempotent: creates a venv (flask+pyyaml), generates a Basic-auth token, installs the
# systemd service (loopback :8765), and health-checks. Expose it with deploy/tunnel.sh
# (reuse infra/fleet/atelier/deploy/tunnel.sh, pointing at 8765).
set -euo pipefail

REPO_DIR="$(cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || echo "$(dirname "$0")/../../..")" && pwd)"
RUN_USER="$(id -un)"
VENV="/opt/merlin-cockpit-venv"
ENV_FILE="/etc/merlin-cockpit.env"
UNIT="/etc/systemd/system/merlin-cockpit.service"
PORT=8765

echo "==> MERLIN cockpit deploy"
echo "    repo:   $REPO_DIR"
echo "    user:   $RUN_USER"

# ── 1. Python venv (Debian 12 blocks system pip) ─────────────────────────────
if [ ! -x "$VENV/bin/python" ]; then
  echo "==> Creating venv $VENV"
  sudo apt-get update -y >/dev/null 2>&1 || true
  sudo apt-get install -y python3-venv >/dev/null 2>&1 || true
  sudo python3 -m venv "$VENV"
  sudo chown -R "$RUN_USER":"$RUN_USER" "$VENV"
fi
"$VENV/bin/pip" install -q --upgrade pip >/dev/null
"$VENV/bin/pip" install -q flask pyyaml >/dev/null
echo "    venv ready ($("$VENV/bin/python" -c 'import flask;print("flask",flask.__version__)'))"

# ── 2. Auth token (Basic-auth password), generated once, 0600 ────────────────
if [ ! -f "$ENV_FILE" ]; then
  TOKEN="$(openssl rand -hex 24 2>/dev/null || head -c 24 /dev/urandom | base64 | tr -dc 'a-f0-9' | head -c 48)"
  printf 'COCKPIT_TOKEN=%s\nCOCKPIT_USER=merlin\n' "$TOKEN" | sudo tee "$ENV_FILE" >/dev/null
  sudo chmod 600 "$ENV_FILE"
  echo "==> Generated cockpit token -> $ENV_FILE"
else
  echo "==> Reusing existing $ENV_FILE"
fi
TOKEN_SHOWN="$(sudo sed -n 's/^COCKPIT_TOKEN=//p' "$ENV_FILE")"

# ── 3. systemd unit from the template ────────────────────────────────────────
echo "==> Installing systemd unit"
sed -e "s#__REPO_DIR__#$REPO_DIR#g" \
    -e "s#__USER__#$RUN_USER#g" \
    -e "s#__VENV__#$VENV#g" \
    "$REPO_DIR/infra/fleet/cockpit/merlin-cockpit.service" | sudo tee "$UNIT" >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now merlin-cockpit.service
sleep 2
sudo systemctl --no-pager --full status merlin-cockpit.service | head -n 10 || true

# ── 4. Smoke (with creds) ────────────────────────────────────────────────────
echo "==> Local health check"
curl -fsS -u "merlin:$TOKEN_SHOWN" "http://127.0.0.1:$PORT/healthz" && echo
echo
echo "==> Cockpit up on 127.0.0.1:$PORT (Basic auth: user 'merlin')."
echo "    Token: $TOKEN_SHOWN"
echo "    Expose it:  bash infra/fleet/atelier/deploy/tunnel.sh quick   # then point the printed URL"
echo "                (or 'named' for a stable URL). The tunnel must target http://127.0.0.1:$PORT —"
echo "                edit tunnel.sh LOCAL_URL or pass the port; see infra/fleet/cockpit/README.md."
