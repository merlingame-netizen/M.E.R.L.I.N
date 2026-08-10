#!/usr/bin/env bash
# Provisioning user-mode (SANS sudo) de la pile "jeu natif" sur la VM Oracle OL9.
# Exécutable à volonté via OCI Run Command (user ocarun) :
#   python infra/oracle/scripts/agent_takeover.py --cmd \
#     'bash ~/workspace/M.E.R.L.I.N/infra/oracle/game/provision-game-user.sh'
# Idempotent : chaque section teste avant d'agir.
set -uo pipefail

REPO="${MERLIN_REPO:-$HOME/workspace/M.E.R.L.I.N}"
VENV="$REPO/.venv-studio"
CONF_DIR="$HOME/.config"
GAME_ENV="$CONF_DIR/merlin-game.env"
IMAGE="localhost/merlin-game"

log()  { echo "[provision-game] $*"; }
fail() { echo "[provision-game] FATAL: $*" >&2; exit 1; }

log "=== 1/6 repo à jour ==="
git -C "$REPO" pull --ff-only 2>&1 | tail -1 || log "warn: pull impossible (offline ?)"

log "=== 2/6 podman rootless ==="
command -v podman >/dev/null 2>&1 || fail "podman absent de la VM (inattendu sur OL9)"
podman info >/dev/null 2>&1 || fail "podman info KO — voir 'podman info' à la main"
mkdir -p "$CONF_DIR"
# subuid/subgid : sans plage pour ocarun, --userns=keep-id échoue -> fallback host.
if podman unshare cat /proc/self/uid_map 2>/dev/null | awk 'NR==2{found=1} END{exit !found}'; then
    log "subuid OK -> --userns=keep-id"
    grep -q '^USERNS_FLAG=' "$GAME_ENV" 2>/dev/null && sed -i '/^USERNS_FLAG=/d' "$GAME_ENV"
else
    log "warn: pas de plage subuid pour $(id -un) -> fallback --userns=host"
    touch "$GAME_ENV"; chmod 600 "$GAME_ENV"
    grep -q '^USERNS_FLAG=--userns=host$' "$GAME_ENV" || echo 'USERNS_FLAG=--userns=host' >> "$GAME_ENV"
fi

log "=== 3/6 dépendances python (pont WebSocket) ==="
if [ -x "$VENV/bin/pip" ]; then
    PIP="$VENV/bin/pip"
else
    # provision-ol9-user.sh historique : venv à la racine du repo ou ~/.venv
    PIP="$(ls "$REPO"/.venv*/bin/pip "$HOME"/.venv*/bin/pip 2>/dev/null | head -1 || true)"
fi
[ -n "${PIP:-}" ] || fail "aucun venv pip trouvé (attendu $VENV ou ~/.venv*)"
"$PIP" install -q flask-sock simple-websocket && log "flask-sock + simple-websocket OK ($PIP)"

log "=== 4/6 image conteneur ==="
CF="$REPO/infra/oracle/game/Containerfile"
HASH="$(sha256sum "$CF" "$REPO/infra/oracle/game/entrypoint.sh" | sha256sum | cut -c1-12)"
CUR="$(podman image inspect "$IMAGE" -f '{{index .Labels "merlin.hash"}}' 2>/dev/null || true)"
if [ "$CUR" = "$HASH" ]; then
    log "image à jour (hash $HASH), build sauté"
else
    log "build de l'image (hash $CUR -> $HASH)…"
    podman build --label "merlin.hash=$HASH" -t "$IMAGE" \
        -f "$CF" "$REPO/infra/oracle/game/" || fail "podman build KO"
fi
chmod +x "$REPO/infra/oracle/game/game-stack.sh" "$REPO/infra/oracle/game/entrypoint.sh"

log "=== 5/6 restart Studio (le cron keepalive relance sous 60 s) ==="
pkill -f 'merlin_studio/app.py' 2>/dev/null && log "Studio arrêté, relance par cron" \
    || log "Studio pas en cours (le cron le lancera)"

log "=== 6/6 smoke : start -> screenshot -> stop ==="
GS="$REPO/infra/oracle/game/game-stack.sh"
bash "$GS" start || fail "game-stack start KO"
sleep 5   # laisser une frame se dessiner
podman exec merlin-game scrot -o /tmp/shot.png || fail "scrot KO"
SIZE="$(podman exec merlin-game stat -c %s /tmp/shot.png)"
log "screenshot: ${SIZE} octets (>20000 attendu pour une frame non vide)"
bash "$GS" stop >/dev/null
[ "$SIZE" -gt 20000 ] || fail "screenshot suspect (${SIZE} o) — écran probablement noir"

log "=== PROVISION OK ==="
