#!/usr/bin/env bash
# Cycle de vie du jeu natif sur la VM Oracle (user ocarun, sans root).
# Usage : game-stack.sh start|stop|restart|status [--res 1280x720]
# Deux modes, choisis automatiquement :
#   container — podman rootless (image localhost/merlin-game, Containerfile ici)
#   native    — sysroot userland ~/opt/gamestack (RPM extraits, native-stack-setup.sh)
set -uo pipefail

REPO="${MERLIN_REPO:-$HOME/workspace/M.E.R.L.I.N}"
GODOT_BIN="${GODOT_BIN:-$HOME/bin/godot}"
IMAGE="localhost/merlin-game"
NAME="merlin-game"
RES="${RES:-1280x720}"
SYSROOT="$HOME/opt/gamestack/sysroot"
RUNDIR="$HOME/.cache/merlin-game"

# Config optionnelle écrite par provision-game-user.sh (GAME_MODE, USERNS_FLAG…).
CONF="$HOME/.config/merlin-game.env"
[ -f "$CONF" ] && . "$CONF"
USERNS_FLAG="${USERNS_FLAG:---userns=keep-id}"

if [ -z "${GAME_MODE:-}" ]; then
    if command -v podman >/dev/null 2>&1; then GAME_MODE=container
    elif [ -f "$SYSROOT/.merlin-ready" ];  then GAME_MODE=native
    else GAME_MODE=none; fi
fi

port_open() {
    (exec 3<>/dev/tcp/127.0.0.1/5900) 2>/dev/null && { exec 3>&-; return 0; }
    return 1
}

pid_alive() { [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null; }

status_json() {
    local state="absent" vnc=false
    if [ "$GAME_MODE" = "container" ]; then
        if podman container exists "$NAME" 2>/dev/null; then
            state="$(podman inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || echo unknown)"
        fi
    elif [ "$GAME_MODE" = "native" ]; then
        if pid_alive "$(cat "$RUNDIR/godot.pid" 2>/dev/null)"; then state="running"
        elif [ -f "$RUNDIR/godot.pid" ]; then state="exited"
        fi
    fi
    port_open && vnc=true
    printf '{"mode":"%s","container":"%s","vnc_open":%s,"res":"%s"}\n' \
        "$GAME_MODE" "$state" "$vnc" "$RES"
}

wait_vnc() {  # $1 = "check-cmd de vie" (retourne 0 si le process principal vit encore)
    for _ in $(seq 1 60); do
        port_open && { status_json; return 0; }
        if ! eval "$1"; then
            echo "FATAL: le jeu est mort pendant le boot — logs :" >&2
            eval "${2:-true}" >&2 || true
            exit 1
        fi
        sleep 0.5
    done
    echo "FATAL: port 5900 injoignable après 30 s — logs :" >&2
    eval "${2:-true}" >&2 || true
    exit 1
}

# ── mode container ───────────────────────────────────────────────────────────
start_container() {
    if ! podman image exists "$IMAGE"; then
        echo "FATAL: image $IMAGE absente — lancer provision-game-user.sh" >&2
        exit 1
    fi
    podman rm -f "$NAME" >/dev/null 2>&1 || true
    local common=(-d --name "$NAME" --replace --network=host "$USERNS_FLAG"
                  --shm-size=1g
                  -v "$REPO:/game"
                  -v "$GODOT_BIN:/opt/godot:ro"
                  -e "RES=$RES")
    if ! podman run "${common[@]}" --memory=8g --cpus=3 "$IMAGE" >/dev/null 2>&1; then
        echo "info: limites memory/cpus refusées (cgroups non délégués), retry sans" >&2
        podman run "${common[@]}" "$IMAGE" >/dev/null
    fi
    wait_vnc '[ "$(podman inspect -f "{{.State.Status}}" "$NAME" 2>/dev/null)" = running ]' \
             'podman logs --tail 40 "$NAME"'
}

stop_container() {
    podman stop -t 5 "$NAME" >/dev/null 2>&1 || true
    podman rm -f "$NAME" >/dev/null 2>&1 || true
}

# ── mode native (sysroot userland) ───────────────────────────────────────────
native_env() {
    export LD_LIBRARY_PATH="$SYSROOT/usr/lib64:$SYSROOT/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export PATH="$SYSROOT/usr/bin:$PATH"
    export XKB_BINDIR="$SYSROOT/usr/bin"            # xkbcomp pour Xvfb
    export LIBGL_DRIVERS_PATH="$SYSROOT/usr/lib64/dri"
    export LIBGL_ALWAYS_SOFTWARE=1
    export GALLIUM_DRIVER=llvmpipe
    export DISPLAY=:99
}

start_native() {
    [ -f "$SYSROOT/.merlin-ready" ] || {
        echo "FATAL: sysroot absent — lancer provision-game-user.sh" >&2; exit 1; }
    stop_native
    mkdir -p "$RUNDIR"
    native_env

    "$SYSROOT/usr/bin/Xvfb" :99 -screen 0 "${RES}x24" -nolisten tcp \
        -fp built-ins -xkbdir "$SYSROOT/usr/share/X11/xkb" \
        > "$RUNDIR/xvfb.log" 2>&1 &
    echo $! > "$RUNDIR/xvfb.pid"
    for _ in $(seq 1 50); do [ -e /tmp/.X11-unix/X99 ] && break; sleep 0.2; done
    [ -e /tmp/.X11-unix/X99 ] || {
        echo "FATAL: Xvfb n'a pas démarré — $RUNDIR/xvfb.log :" >&2
        tail -20 "$RUNDIR/xvfb.log" >&2; exit 1; }

    "$SYSROOT/usr/bin/x11vnc" -display :99 -localhost -rfbport 5900 -forever \
        -shared -nopw -noxdamage -defer 20 -wait 20 -quiet \
        > "$RUNDIR/x11vnc.log" 2>&1 &
    echo $! > "$RUNDIR/x11vnc.pid"

    ( cd "$REPO" && exec "$GODOT_BIN" --path . --rendering-driver opengl3 \
        --audio-driver Dummy --resolution "$RES" ) \
        > "$RUNDIR/godot.log" 2>&1 &
    echo $! > "$RUNDIR/godot.pid"

    wait_vnc 'pid_alive "$(cat "$RUNDIR/godot.pid" 2>/dev/null)"' \
             'tail -30 "$RUNDIR/godot.log" "$RUNDIR/x11vnc.log"'
}

stop_native() {
    for p in godot x11vnc xvfb; do
        local pid; pid="$(cat "$RUNDIR/$p.pid" 2>/dev/null || true)"
        if pid_alive "$pid"; then kill "$pid" 2>/dev/null; fi
        rm -f "$RUNDIR/$p.pid"
    done
    # laisser le temps aux sockets de se libérer
    sleep 0.5
}

# ── dispatch ─────────────────────────────────────────────────────────────────
[ "$GAME_MODE" = "none" ] && {
    echo "FATAL: ni podman ni sysroot — lancer provision-game-user.sh" >&2; exit 1; }

do_start() { if [ "$GAME_MODE" = "container" ]; then start_container; else start_native; fi; }
do_stop()  { if [ "$GAME_MODE" = "container" ]; then stop_container;  else stop_native;  fi; }

case "${1:-status}" in
    start)   shift || true; [ "${1:-}" = "--res" ] && RES="$2"; do_start ;;
    stop)    do_stop; status_json ;;
    restart) shift || true; [ "${1:-}" = "--res" ] && RES="$2"; do_stop; do_start ;;
    status)  status_json ;;
    *) echo "usage: $0 start|stop|restart|status [--res LxH]" >&2; exit 2 ;;
esac
