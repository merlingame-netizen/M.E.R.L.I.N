#!/usr/bin/env bash
# Cycle de vie du jeu natif sur la VM Oracle (user ocarun, sans root).
# Usage : game-stack.sh start|stop|restart|status [--res 1280x720]
# Deux modes, choisis automatiquement :
#   container — podman rootless (image localhost/merlin-game, Containerfile ici)
#   native    — sysroot userland ~/opt/gamestack (RPM extraits, native-stack-setup.sh)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/game-env.sh"    # TOOLS_REPO, GAME_DIR, GAME_REF, GAME_REPO_DIR

GODOT_BIN="${GODOT_BIN:-$HOME/bin/godot}"
IMAGE="localhost/merlin-game"
NAME="merlin-game"
RES="${RES:-1280x720}"
SYSROOT="$HOME/opt/gamestack/sysroot"
RUNDIR="$HOME/.cache/merlin-game"
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
        if pid_alive "$(cat "$RUNDIR/inner.pid" 2>/dev/null)"; then state="running"
        elif [ -f "$RUNDIR/inner.pid" ]; then state="exited"
        fi
    fi
    port_open && vnc=true
    # Transparence : QUEL projet est joué (dossier, branche, commit, import).
    local gbranch="?" gcommit="?" gimported=false
    if [ -d "$GAME_DIR/.git" ]; then
        gbranch="$(git -C "$GAME_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
        gcommit="$(git -C "$GAME_DIR" rev-parse --short HEAD 2>/dev/null || echo '?')"
    fi
    [ -n "$(find "$GAME_DIR/.godot/imported" -type f -print -quit 2>/dev/null)" ] && gimported=true
    printf '{"mode":"%s","container":"%s","vnc_open":%s,"res":"%s","game_dir":"%s","game_branch":"%s","game_commit":"%s","imported":%s}\n' \
        "$GAME_MODE" "$state" "$vnc" "$RES" "$GAME_DIR" "$gbranch" "$gcommit" "$gimported"
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
                  -v "$GAME_DIR:/game"
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

# ── mode native (sysroot userland dans un userns non privilégié) ─────────────
# Xvfb spawn /usr/bin/xkbcomp en chemin ABSOLU compilé en dur -> impossible en
# pur LD_LIBRARY_PATH. native-inner.sh tourne dans `unshare --user --mount` et
# monte le sysroot par-dessus /usr/bin + /usr/share/X11 (overlay, ou bind d'un
# répertoire fusionné en fallback). Le réseau reste celui de l'hôte (port 5900).
start_native() {
    [ -f "$SYSROOT/.merlin-ready" ] || {
        echo "FATAL: sysroot absent — lancer provision-game-user.sh" >&2; exit 1; }
    stop_native
    mkdir -p "$RUNDIR"
    # native-inner.sh vit avec l'OUTILLAGE (SCRIPT_DIR), pas dans le dépôt du jeu.
    # MERLIN_SCENE / MERLIN_QUIT_AFTER_S / MERLIN_E2E* transmis explicitement : `unshare` ne conserve que
    # l'environnement passé ici, donc une variable exportée par l'appelant se perdrait
    # silencieusement — le test tournerait sur la scène principale en croyant tester la sienne.
    setsid env MAX_FPS="${MAX_FPS:-30}" MERLIN_SCENE="${MERLIN_SCENE:-}" \
        MERLIN_QUIT_AFTER_S="${MERLIN_QUIT_AFTER_S:-}" MERLIN_BIOME="${MERLIN_BIOME:-}" \
        MERLIN_E2E="${MERLIN_E2E:-}" MERLIN_E2E_OUT="${MERLIN_E2E_OUT:-}" \
        unshare --user --map-root-user --mount \
        bash "$SCRIPT_DIR/native-inner.sh" "$RES" > "$RUNDIR/inner.log" 2>&1 &
    echo $! > "$RUNDIR/inner.pid"
    wait_vnc 'pid_alive "$(cat "$RUNDIR/inner.pid" 2>/dev/null)"' \
             'tail -30 "$RUNDIR/inner.log" "$RUNDIR/xvfb.log" "$RUNDIR/godot.log" 2>/dev/null'
}

stop_native() {
    local pid; pid="$(cat "$RUNDIR/inner.pid" 2>/dev/null || true)"
    if pid_alive "$pid"; then
        kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
        for _ in $(seq 1 10); do pid_alive "$pid" || break; sleep 0.3; done
        pid_alive "$pid" && kill -KILL -- "-$pid" 2>/dev/null
    fi
    rm -f "$RUNDIR/inner.pid"
    # Balayage des orphelins sur l'affichage :99 (Xvfb/x11vnc survivants d'un
    # crash godot ou d'un kill partiel — sinon le port 5900 reste faux-ouvert).
    pkill -f 'x11vnc -display :99' 2>/dev/null
    pkill -f 'Xvfb :99' 2>/dev/null
    rm -f /tmp/.X99-lock 2>/dev/null
    sleep 0.5
}

# ── dispatch ─────────────────────────────────────────────────────────────────
[ "$GAME_MODE" = "none" ] && {
    echo "FATAL: ni podman ni sysroot — lancer provision-game-user.sh" >&2; exit 1; }

require_import() {
    # Sans .godot/imported, Godot rend des placeholders méconnaissables :
    # on refuse de démarrer plutôt que d'afficher « un autre jeu ».
    if [ -z "$(find "$GAME_DIR/.godot/imported" -type f -print -quit 2>/dev/null)" ]; then
        echo "FATAL: assets jamais importés dans $GAME_DIR — lancer game-sync (bouton Sync du Studio)" >&2
        exit 1
    fi
}

# État DÉSIRÉ : le veilleur (agent game-watchdog) ne relance que si l'humain a
# demandé que le jeu tourne. Un stop explicite doit rester un stop.
desire() { mkdir -p "$RUNDIR"; printf '%s' "$1" > "$RUNDIR/desired"; }

do_start() {
    require_import
    desire running; printf '%s' "$RES" > "$RUNDIR/last-res"
    if [ "$GAME_MODE" = "container" ]; then start_container; else start_native; fi
}
do_stop() {
    desire stopped
    if [ "$GAME_MODE" = "container" ]; then stop_container; else stop_native; fi
}

case "${1:-status}" in
    start)   shift || true; [ "${1:-}" = "--res" ] && RES="$2"; do_start ;;
    stop)    do_stop; status_json ;;
    restart) shift || true; [ "${1:-}" = "--res" ] && RES="$2"; do_stop; do_start ;;
    status)  status_json ;;
    *) echo "usage: $0 start|stop|restart|status [--res LxH]" >&2; exit 2 ;;
esac
