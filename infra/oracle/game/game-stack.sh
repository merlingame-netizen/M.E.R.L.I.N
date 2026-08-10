#!/usr/bin/env bash
# Cycle de vie du jeu natif dans son conteneur podman rootless (VM Oracle, user ocarun).
# Usage : game-stack.sh start|stop|restart|status [--res 1280x720]
# Idempotent : start relance proprement un conteneur existant (--replace).
set -euo pipefail

REPO="${MERLIN_REPO:-$HOME/workspace/M.E.R.L.I.N}"
GODOT_BIN="${GODOT_BIN:-$HOME/bin/godot}"
IMAGE="localhost/merlin-game"
NAME="merlin-game"
RES="${RES:-1280x720}"

# Config optionnelle écrite par provision-game-user.sh (ex: USERNS_FLAG=--userns=host).
CONF="$HOME/.config/merlin-game.env"
[ -f "$CONF" ] && . "$CONF"
USERNS_FLAG="${USERNS_FLAG:---userns=keep-id}"

port_open() {
    (exec 3<>/dev/tcp/127.0.0.1/5900) 2>/dev/null && { exec 3>&-; return 0; }
    return 1
}

status_json() {
    local state="absent" vnc=false
    if podman container exists "$NAME" 2>/dev/null; then
        state="$(podman inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || echo unknown)"
    fi
    port_open && vnc=true
    printf '{"container":"%s","vnc_open":%s,"res":"%s"}\n' "$state" "$vnc" "$RES"
}

start() {
    if ! podman image exists "$IMAGE"; then
        echo "FATAL: image $IMAGE absente — lancer provision-game-user.sh" >&2
        exit 1
    fi
    podman rm -f "$NAME" >/dev/null 2>&1 || true

    # Limites best-effort : en rootless sans délégation cgroups v2, --memory/--cpus
    # sont refusés ; on retente alors sans.
    local common=(-d --name "$NAME" --replace --network=host "$USERNS_FLAG"
                  --shm-size=1g
                  -v "$REPO:/game"
                  -v "$GODOT_BIN:/opt/godot:ro"
                  -e "RES=$RES")
    if ! podman run "${common[@]}" --memory=8g --cpus=3 "$IMAGE" >/dev/null 2>&1; then
        echo "info: limites memory/cpus refusées (cgroups non délégués), retry sans" >&2
        podman run "${common[@]}" "$IMAGE" >/dev/null
    fi

    # Attendre le VNC (Xvfb + x11vnc + boot godot) — max 30 s.
    for _ in $(seq 1 60); do
        port_open && { status_json; return 0; }
        # Conteneur mort pendant le boot -> échec immédiat avec les logs.
        local st
        st="$(podman inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || echo absent)"
        if [ "$st" != "running" ]; then
            echo "FATAL: conteneur $st pendant le boot — logs :" >&2
            podman logs --tail 40 "$NAME" >&2 || true
            exit 1
        fi
        sleep 0.5
    done
    echo "FATAL: port 5900 injoignable après 30 s — logs :" >&2
    podman logs --tail 40 "$NAME" >&2 || true
    exit 1
}

stop() {
    podman stop -t 5 "$NAME" >/dev/null 2>&1 || true
    podman rm -f "$NAME" >/dev/null 2>&1 || true
    status_json
}

case "${1:-status}" in
    start)   shift; [ "${1:-}" = "--res" ] && RES="$2"; start ;;
    stop)    stop ;;
    restart) shift || true; [ "${1:-}" = "--res" ] && RES="$2"; stop >/dev/null; start ;;
    status)  status_json ;;
    *) echo "usage: $0 start|stop|restart|status [--res LxH]" >&2; exit 2 ;;
esac
