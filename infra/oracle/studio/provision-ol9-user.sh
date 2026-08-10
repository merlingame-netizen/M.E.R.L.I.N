#!/usr/bin/env bash
# Provisioning USER-MODE (sans root) pour la VM OL9 pilotee via Run Command (user ocarun,
# pas de sudo). Tout va dans $HOME : ~/bin/godot, ~/bin/cloudflared, venv Flask, crontab
# @reboot + keepalive. Imprime a la fin URL publique + token (pour VS Code / mobile).
#
#   curl -fsSL https://raw.githubusercontent.com/merlingame-netizen/M.E.R.L.I.N/main/infra/oracle/studio/provision-ol9-user.sh | bash
set -uo pipefail
say() { printf '%s\n' "$*"; }
say "=== provision-ol9-user: $(date -u +%H:%M:%S) $(id -un)@$(uname -m) ==="
mkdir -p "$HOME/bin" "$HOME/logs"
export PATH="$HOME/bin:$PATH"

# ── 1. Depot ───────────────────────────────────────────────────────────────
REPO="$HOME/workspace/M.E.R.L.I.N"
if [ ! -d "$REPO/.git" ]; then
  mkdir -p "$(dirname "$REPO")"
  git clone --quiet https://github.com/merlingame-netizen/M.E.R.L.I.N.git "$REPO"
fi
git -C "$REPO" pull --ff-only --quiet 2>/dev/null || true
say "repo: $(git -C "$REPO" log --oneline -1)"

# ── 2. venv + flask ────────────────────────────────────────────────────────
if [ ! -x "$REPO/.venv/bin/python" ]; then python3 -m venv "$REPO/.venv"; fi
"$REPO/.venv/bin/pip" install -q --upgrade pip flask >/dev/null 2>&1
say "flask: ok"

# ── 3. cloudflared (binaire user) ──────────────────────────────────────────
if [ ! -x "$HOME/bin/cloudflared" ]; then
  curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" \
    -o "$HOME/bin/cloudflared" && chmod 0755 "$HOME/bin/cloudflared"
fi
say "cloudflared: $("$HOME/bin/cloudflared" --version 2>/dev/null | head -1 || echo KO)"

# ── 4. godot headless arm64 (binaire user — pour smoke + export web) ───────
if [ ! -x "$HOME/bin/godot" ]; then
  GV="4.6"
  curl -fsSL "https://github.com/godotengine/godot/releases/download/${GV}-stable/Godot_v${GV}-stable_linux.arm64.zip" \
    -o /tmp/godot.zip && unzip -o -q /tmp/godot.zip -d /tmp \
    && install -m 0755 "/tmp/Godot_v${GV}-stable_linux.arm64" "$HOME/bin/godot" && rm -f /tmp/godot.zip
fi
say "godot: $("$HOME/bin/godot" --headless --version 2>/dev/null | head -1 || echo 'absent (libs manquantes ?)')"

# ── 5. crontab : @reboot + keepalive minute (persistance sans systemd) ─────
KA="$REPO/infra/oracle/studio/keepalive-user.sh"
chmod +x "$KA" 2>/dev/null || true
( crontab -l 2>/dev/null | grep -v keepalive-user.sh
  echo "@reboot sleep 30 && $KA >> $HOME/logs/keepalive.log 2>&1"
  echo "* * * * * $KA >> $HOME/logs/keepalive.log 2>&1" ) | crontab -
say "crontab: $(crontab -l | grep -c keepalive-user.sh) entrees"

# ── 6. Premier demarrage + URL ─────────────────────────────────────────────
bash "$KA"
URL=""
for _ in $(seq 1 30); do
  sleep 2
  URL="$(cat "$HOME/tunnel-url.txt" 2>/dev/null || true)"
  [ -n "$URL" ] && break
done
TOKEN="$(sed -n 's/^STUDIO_TOKEN=//p' "$HOME/.config/merlin-studio.env")"
CODE="$(curl -s -o /dev/null -w '%{http_code}' -u "merlin:$TOKEN" "http://127.0.0.1:8790/healthz" || echo 000)"
PUB="$(curl -s -o /dev/null -w '%{http_code}' -u "merlin:$TOKEN" "$URL/healthz" 2>/dev/null || echo 000)"
say ""
say "=============================================="
say " URL   : ${URL:-ECHEC-TUNNEL}"
say " User  : merlin"
say " Token : $TOKEN"
say " Health: local=$CODE public=$PUB"
say "=============================================="
say "=== provision-ol9-user: termine $(date -u +%H:%M:%S) ==="
