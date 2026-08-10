#!/usr/bin/env bash
# Corps du mode natif — s'exécute DANS un namespace user+mount non privilégié
# (lancé par game-stack.sh via `unshare --user --map-root-user --mount`).
# Monte le sysroot par-dessus /usr/bin et /usr/share/X11 (Xvfb spawn
# /usr/bin/xkbcomp en chemin absolu compilé en dur — voir provision), puis
# lance Xvfb -> x11vnc -> godot (avant-plan : sa mort termine le namespace).
set -euo pipefail

RES="${1:-1280x720}"
REPO="${MERLIN_REPO:-$HOME/workspace/M.E.R.L.I.N}"
GODOT_BIN="${GODOT_BIN:-$HOME/bin/godot}"
SYSROOT="$HOME/opt/gamestack/sysroot"
MERGED="$HOME/opt/gamestack/merged"
RUNDIR="$HOME/.cache/merlin-game"

overlay_or_bind() {  # $1 = sous-chemin (ex: usr/bin)
    if mount -t overlay overlay -o "lowerdir=$SYSROOT/$1:/$1" "/$1" 2>/dev/null; then
        return 0
    fi
    # Fallback tout-noyau : répertoire fusionné de symlinks préparé par
    # native-stack-setup.sh, simple bind (toujours permis en userns).
    [ -d "$MERGED/$1" ] || { echo "FATAL: ni overlay ni $MERGED/$1" >&2; exit 1; }
    mount --bind "$MERGED/$1" "/$1"
}

overlay_or_bind usr/bin
mkdir -p /usr/share/X11 2>/dev/null || true
overlay_or_bind usr/share/X11

export LD_LIBRARY_PATH="$SYSROOT/usr/lib64:$SYSROOT/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LIBGL_DRIVERS_PATH="$SYSROOT/usr/lib64/dri"
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export DISPLAY=:99

Xvfb :99 -screen 0 "${RES}x24" -nolisten tcp -fp built-ins \
    > "$RUNDIR/xvfb.log" 2>&1 &
for _ in $(seq 1 50); do [ -e /tmp/.X11-unix/X99 ] && break; sleep 0.2; done
[ -e /tmp/.X11-unix/X99 ] || {
    echo "FATAL: Xvfb n'a pas démarré :" >&2; tail -20 "$RUNDIR/xvfb.log" >&2; exit 1; }

x11vnc -display :99 -localhost -rfbport 5900 -forever -shared -nopw \
    -noxdamage -defer 20 -wait 20 -quiet > "$RUNDIR/x11vnc.log" 2>&1 &

cd "$REPO"
exec "$GODOT_BIN" --path . --rendering-driver opengl3 --audio-driver Dummy \
    --resolution "$RES" > "$RUNDIR/godot.log" 2>&1
