#!/usr/bin/env bash
# Keepalive user-mode (sans root) : garantit Studio + tunnel en vie. Lance par cron
# (chaque minute + @reboot) sous ocarun — survit au nettoyage de process de Run Command.
# Ecrit l'URL publique courante dans ~/tunnel-url.txt (lisible via Run Command).
set -u
PORT=8790
REPO="${MERLIN_REPO:-$HOME/workspace/M.E.R.L.I.N}"
ENVF="$HOME/.config/merlin-studio.env"
LOGDIR="$HOME/logs"
mkdir -p "$LOGDIR" "$HOME/.config"

# ── token (genere une fois, 0600) ──────────────────────────────────────────
if [ ! -f "$ENVF" ]; then
  TOKEN="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 48)"
  printf 'STUDIO_TOKEN=%s\nSTUDIO_USER=merlin\nOLLAMA_URL=http://127.0.0.1:11434\n' "$TOKEN" > "$ENVF"
  chmod 600 "$ENVF"
fi
set -a; . "$ENVF"; set +a
export PATH="$HOME/bin:$PATH" GODOT_BIN="$HOME/bin/godot"

# ── Studio (Flask, 127.0.0.1:8790) ─────────────────────────────────────────
if ! curl -fsS "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1; then
  pkill -u "$(id -un)" -f "merlin_studio/app.py" 2>/dev/null
  nohup "$REPO/.venv/bin/python" "$REPO/tools/merlin_studio/app.py" --port "$PORT" \
    >> "$LOGDIR/studio.log" 2>&1 &
fi

# ── tunnel Cloudflare (HTTPS public, aucun port entrant) ───────────────────
# Deux modes :
#   NOMMÉ (URL stable, ex. studio.mondomaine.fr) — si ~/.config/merlin-tunnel.env
#     contient TUNNEL_TOKEN (créé dans Cloudflare Zero Trust → Tunnels) et
#     TUNNEL_HOSTNAME. Le hostname public → http://127.0.0.1:8790 se règle
#     dans le dashboard Cloudflare du tunnel.
#   QUICK (URL aléatoire *.trycloudflare.com, changeante) — repli sans config.
TUNF="$HOME/.config/merlin-tunnel.env"
[ -f "$TUNF" ] && . "$TUNF"
if ! pgrep -u "$(id -un)" -f "cloudflared.*tunnel" >/dev/null 2>&1; then
  : > "$LOGDIR/tunnel.log"
  if [ -n "${TUNNEL_TOKEN:-}" ]; then
    nohup "$HOME/bin/cloudflared" tunnel --no-autoupdate run --token "$TUNNEL_TOKEN" \
      >> "$LOGDIR/tunnel.log" 2>&1 &
  else
    nohup "$HOME/bin/cloudflared" tunnel --no-autoupdate --url "http://127.0.0.1:$PORT" \
      >> "$LOGDIR/tunnel.log" 2>&1 &
  fi
fi
if [ -n "${TUNNEL_TOKEN:-}" ]; then
  [ -n "${TUNNEL_HOSTNAME:-}" ] && printf 'https://%s\n' "$TUNNEL_HOSTNAME" > "$HOME/tunnel-url.txt"
else
  URL="$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$LOGDIR/tunnel.log" 2>/dev/null | tail -1)"
  [ -n "$URL" ] && printf '%s\n' "$URL" > "$HOME/tunnel-url.txt"
fi
exit 0
