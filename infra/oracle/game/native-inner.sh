#!/usr/bin/env bash
# Corps du mode natif — s'exécute DANS un namespace user+mount non privilégié
# (lancé par game-stack.sh via `unshare --user --map-root-user --mount`).
# Monte le sysroot par-dessus /usr/bin et /usr/share/X11 (Xvfb spawn
# /usr/bin/xkbcomp en chemin absolu compilé en dur), puis lance
# Xvfb -> x11vnc -> godot (avant-plan : sa mort termine le namespace).
set -euo pipefail

RES="${1:-1280x720}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/game-env.sh"          # fournit GAME_DIR (le projet joué)

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

# Perf : -threads sert chaque client dans son propre fil (l'encodage ne bloque
# plus la capture) ; -defer/-wait 10 double la réactivité par rapport à 20 ms ;
# -nolookup/-noxfixes/-nowf coupent des allers-retours X inutiles.
x11vnc -display :99 -localhost -rfbport 5900 -forever -shared -nopw \
    -noxdamage -threads -defer 10 -wait 10 -nolookup -noxfixes -nowf -quiet \
    > "$RUNDIR/x11vnc.log" 2>&1 &

# Son : si la pile audio userland est là, on démarre la sortie virtuelle et on
# lance Godot dessus. Sinon on garde le driver Dummy — le jeu tourne quand même.
AUDIO_DRIVER="Dummy"
if [ -x "$HOME/opt/audio/start-audio.sh" ] && [ -x "$HOME/opt/audio/sysroot/usr/bin/pulseaudio" ]; then
    # La sortie du script est CONSERVÉE : quand la porte retombe sur Dummy, il faut
    # pouvoir lire pourquoi. Sans ça le jeu se lance muet en silence — c'est ce qui
    # a laissé vivre un `start-audio.sh` périmé (LD_LIBRARY_PATH sans le dossier
    # pulseaudio/ → pactl ne démarre pas → « audio KO ») pendant des semaines.
    AUDIO_OUT="$(bash "$HOME/opt/audio/start-audio.sh" 2>>"$RUNDIR/audio.log")"
    printf '%s\n' "$AUDIO_OUT" >> "$RUNDIR/audio.log"
    if printf '%s' "$AUDIO_OUT" | grep -q "prêt"; then
        # Le dossier pulseaudio/ porte libpulsecommon et libpulsecore : sans lui,
        # aucun client Pulse ne démarre. On le résout comme start-audio.sh le fait.
        PA_LIBS="$(dirname "$(find "$HOME/opt/audio/sysroot" -name 'libpulsecommon-*.so' 2>/dev/null | head -1)")"
        export LD_LIBRARY_PATH="$HOME/opt/audio/sysroot/usr/lib64:$HOME/opt/audio/sysroot/usr/lib${PA_LIBS:+:$PA_LIBS}:${LD_LIBRARY_PATH:-}"
        export PULSE_RUNTIME_PATH="$HOME/.cache/pulse"
        export PULSE_SINK="merlin"
        AUDIO_DRIVER="PulseAudio"
        echo "[native-inner] audio activé (sortie merlin)" >&2
    else
        echo "[native-inner] SON DÉSACTIVÉ — start-audio.sh a répondu : ${AUDIO_OUT:-(rien)}" >&2
    fi
fi

cd "$GAME_DIR"
echo "[native-inner] projet joué : $GAME_DIR (max-fps=${MAX_FPS:-30}, audio=$AUDIO_DRIVER)" >&2
# Plafonner les FPS libère massivement le CPU : en rendu logiciel, viser 60 fps
# sature les 4 cœurs pour rien. 30 suffit largement à un jeu de cartes et laisse
# du CPU à l'encodage VNC — donc MOINS de latence perçue.
exec "$GODOT_BIN" --path . --rendering-driver opengl3 --audio-driver "$AUDIO_DRIVER" \
    --max-fps "${MAX_FPS:-30}" --resolution "$RES" > "$RUNDIR/godot.log" 2>&1
