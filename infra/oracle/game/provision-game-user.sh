#!/usr/bin/env bash
# Provisioning user-mode (SANS sudo) de la pile "jeu natif" sur la VM Oracle OL9.
# Exécutable à volonté via OCI Run Command (user ocarun) :
#   python infra/oracle/scripts/agent_takeover.py --cmd \
#     'bash ~/workspace/M.E.R.L.I.N/infra/oracle/game/provision-game-user.sh'
# Idempotent. Deux modes :
#   container — si podman est présent (image Fedora Xvfb+x11vnc+llvmpipe)
#   native    — sinon : RPM extraits en userland dans ~/opt/gamestack (OL9 + EPEL)
set -uo pipefail

REPO="${MERLIN_REPO:-$HOME/workspace/M.E.R.L.I.N}"
GAME="$REPO/infra/oracle/game"
CONF_DIR="$HOME/.config"
GAME_ENV="$CONF_DIR/merlin-game.env"
IMAGE="localhost/merlin-game"
SYSROOT="$HOME/opt/gamestack/sysroot"

log()  { echo "[provision-game] $*"; }
fail() { echo "[provision-game] FATAL: $*" >&2; exit 1; }

set_env() {  # set_env CLE VALEUR — écrit/remplace dans merlin-game.env
    mkdir -p "$CONF_DIR"; touch "$GAME_ENV"; chmod 600 "$GAME_ENV"
    sed -i "/^$1=/d" "$GAME_ENV"
    echo "$1=$2" >> "$GAME_ENV"
}

log "=== 1/6 repo à jour ==="
git -C "$REPO" pull --ff-only 2>&1 | tail -1 || log "warn: pull impossible (offline ?)"

log "=== 2/6 pile d'affichage ==="
if command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
    MODE=container
    set_env GAME_MODE container
    # subuid/subgid : sans plage pour ocarun, --userns=keep-id échoue -> fallback host.
    if podman unshare cat /proc/self/uid_map 2>/dev/null | awk 'NR==2{found=1} END{exit !found}'; then
        log "subuid OK -> --userns=keep-id"
        sed -i '/^USERNS_FLAG=/d' "$GAME_ENV"
    else
        log "warn: pas de plage subuid -> fallback --userns=host"
        set_env USERNS_FLAG --userns=host
    fi
    CF="$GAME/Containerfile"
    HASH="$(sha256sum "$CF" "$GAME/entrypoint.sh" | sha256sum | cut -c1-12)"
    CUR="$(podman image inspect "$IMAGE" -f '{{index .Labels "merlin.hash"}}' 2>/dev/null || true)"
    if [ "$CUR" = "$HASH" ]; then
        log "image à jour (hash $HASH), build sauté"
    else
        log "build de l'image (hash $CUR -> $HASH)…"
        podman build --label "merlin.hash=$HASH" -t "$IMAGE" -f "$CF" "$GAME/" \
            || fail "podman build KO"
    fi
else
    MODE=native
    log "podman absent -> mode native (sysroot userland)"
    set_env GAME_MODE native
    bash "$GAME/native-stack-setup.sh" || fail "native-stack-setup KO"
fi

log "=== 3/6 dépendances python (pont WebSocket) ==="
PIP="$(ls "$REPO"/.venv*/bin/pip "$HOME"/.venv*/bin/pip "$HOME"/venv*/bin/pip 2>/dev/null | head -1 || true)"
[ -n "${PIP:-}" ] || fail "aucun venv pip trouvé (attendu $REPO/.venv* ou ~/.venv*)"
"$PIP" install -q flask-sock simple-websocket && log "flask-sock + simple-websocket OK ($PIP)"

log "=== 4/6 scripts exécutables ==="
chmod +x "$GAME"/*.sh

log "=== 5/6 restart Studio (le cron keepalive relance sous 60 s) ==="
pkill -f 'merlin_studio/app.py' 2>/dev/null && log "Studio arrêté, relance par cron" \
    || log "Studio pas en cours (le cron le lancera)"

log "=== 6/6 smoke : start -> screenshot -> stop ==="
bash "$GAME/game-stack.sh" start || fail "game-stack start KO"
sleep 6   # laisser une frame se dessiner
if [ "$MODE" = "container" ]; then
    # PNG : un écran noir se compresse en quelques Ko -> seuil de taille suffisant.
    podman exec merlin-game scrot -o /tmp/shot.png || fail "scrot KO"
    SIZE="$(podman exec merlin-game stat -c %s /tmp/shot.png)"
    log "screenshot: ${SIZE} octets (>20000 attendu pour une frame non vide)"
    bash "$GAME/game-stack.sh" stop >/dev/null
    [ "$SIZE" -gt 20000 ] || fail "screenshot suspect (${SIZE} o) — écran probablement noir"
else
    # xwd = dump brut (taille constante) -> on mesure la part de pixels non noirs.
    env LD_LIBRARY_PATH="$SYSROOT/usr/lib64:$SYSROOT/usr/lib" DISPLAY=:99 \
        "$SYSROOT/usr/bin/xwd" -root -silent > /tmp/merlin-shot.xwd || fail "xwd KO"
    PCT="$(python3 - <<'PYEOF'
data = open("/tmp/merlin-shot.xwd", "rb").read()[4096:]
print(0 if not data else sum(1 for b in data if b) * 100 // len(data))
PYEOF
)"
    log "screenshot xwd: $(stat -c %s /tmp/merlin-shot.xwd) octets, ${PCT}% de pixels non noirs"
    bash "$GAME/game-stack.sh" stop >/dev/null
    [ "${PCT:-0}" -ge 2 ] || fail "écran quasi noir (${PCT}% non noir) — le jeu ne rend pas"
fi

log "=== PROVISION OK (mode $MODE) ==="
