#!/usr/bin/env bash
# MERLIN Studio : TOUT en une seule commande, a coller dans le Cloud Shell Oracle
# (ou dans un SSH sur la VM) :
#
#   curl -fsSL https://raw.githubusercontent.com/merlingame-netizen/M.E.R.L.I.N/main/infra/oracle/studio/up.sh | bash
#
# Fait : trouve (ou clone) le depot -> met a jour -> deploie le Studio (systemd, :8790)
#        -> ouvre le tunnel Cloudflare en arriere-plan -> imprime URL + identifiants,
#        prets a coller dans l'extension VS Code.
# Idempotent : relancable sans risque (reutilise le token existant, remplace le tunnel).
set -euo pipefail

PORT=8790
say() { printf '%s\n' "$*"; }

say ""
say "=============================================="
say " MERLIN Studio : mise en route complete"
say "=============================================="

# ── 1. Localiser le depot (ou le cloner) ────────────────────────────────────
REPO=""
for c in "$HOME/workspace/M.E.R.L.I.N" "$HOME/M.E.R.L.I.N" "$HOME/merlin" "$(pwd)"; do
  [ -f "$c/project.godot" ] && [ -d "$c/infra/oracle/studio" ] && REPO="$c" && break
done
if [ -z "$REPO" ]; then
  REPO="$HOME/workspace/M.E.R.L.I.N"
  say "==> Depot absent, clonage dans $REPO"
  mkdir -p "$(dirname "$REPO")"
  git clone --quiet https://github.com/merlingame-netizen/M.E.R.L.I.N.git "$REPO"
fi
say "==> Depot : $REPO"
git -C "$REPO" pull --ff-only --quiet 2>/dev/null || say "    (pull ignore : branche locale divergente)"

# ── 2. Deployer le Studio (venv + token + systemd) ──────────────────────────
say "==> Deploiement du Studio (peut prendre 1-2 min la premiere fois)"
bash "$REPO/infra/oracle/studio/deploy-studio.sh" >/tmp/merlin-studio-deploy.log 2>&1 \
  || { say "[ECHEC] deploiement — 40 dernieres lignes :"; tail -40 /tmp/merlin-studio-deploy.log; exit 1; }

TOKEN="$(sudo sed -n 's/^STUDIO_TOKEN=//p' /etc/merlin-studio.env 2>/dev/null || true)"
[ -n "$TOKEN" ] || { say "[ECHEC] token introuvable dans /etc/merlin-studio.env"; exit 1; }

# health local avant d'exposer quoi que ce soit
if ! curl -fsS "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1; then
  say "[ECHEC] le Studio ne repond pas sur 127.0.0.1:$PORT"
  say "        journalctl -u merlin-studio -n 40 --no-pager"
  exit 1
fi
say "    Studio en ligne sur 127.0.0.1:$PORT"

# ── 3. Tunnel Cloudflare (HTTPS public, aucun port ouvert) ──────────────────
say "==> Tunnel Cloudflare"
if ! command -v cloudflared >/dev/null 2>&1; then
  case "$(uname -m)" in aarch64|arm64) ca=arm64 ;; *) ca=amd64 ;; esac
  curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ca" -o /tmp/cloudflared
  sudo install -m 0755 /tmp/cloudflared /usr/local/bin/cloudflared && rm -f /tmp/cloudflared
fi
pkill -f "cloudflared.*:$PORT" 2>/dev/null || true
pkill -f "cloudflared tunnel --no-autoupdate --url http://127.0.0.1:$PORT" 2>/dev/null || true
LOG="$HOME/tunnel-studio.log"
nohup cloudflared tunnel --no-autoupdate --url "http://127.0.0.1:$PORT" >"$LOG" 2>&1 &
URL=""
for i in $(seq 1 30); do
  sleep 2
  URL="$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$LOG" 2>/dev/null | tail -1 || true)"
  [ -n "$URL" ] && break
done
[ -n "$URL" ] || { say "[ECHEC] pas d'URL de tunnel — voir $LOG"; tail -20 "$LOG"; exit 1; }

# ── 4. Verification de bout en bout (comme le fera VS Code) ─────────────────
say "==> Verification via l'URL publique"
CODE="$(curl -s -o /dev/null -w '%{http_code}' -u "merlin:$TOKEN" "$URL/healthz" || echo 000)"
NOAUTH="$(curl -s -o /dev/null -w '%{http_code}' "$URL/api/host" || echo 000)"

say ""
say "=============================================="
if [ "$CODE" = "200" ]; then
  say " PRET. Colle ceci dans VS Code :"
  say "   Ctrl+Shift+P > MERLIN: Configurer la connexion"
  say ""
  say "   URL   : $URL"
  say "   User  : merlin"
  say "   Token : $TOKEN"
  say ""
  say " (auth verifiee : /healthz=200 avec token, /api/host=$NOAUTH sans token)"
else
  say " Studio local OK mais l'URL publique repond $CODE."
  say " Reessaie dans 30 s (propagation du tunnel), URL : $URL"
fi
say "=============================================="
say "Tunnel en arriere-plan (log : $LOG). L'URL change si le tunnel redemarre."
