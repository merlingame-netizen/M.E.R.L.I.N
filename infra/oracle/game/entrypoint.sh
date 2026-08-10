#!/usr/bin/env bash
# Entrypoint du conteneur merlin-game : Xvfb -> x11vnc -> godot (avant-plan).
# Godot reste le process principal : quand le jeu quitte, le conteneur meurt,
# ce qui donne un état propre à la sonde /api/game du Studio.
set -euo pipefail

RES="${RES:-1280x720}"

# HOME inscriptible pour user:// de Godot (le montage /game peut être possédé
# par un uid différent selon le mode userns).
export HOME=/tmp/merlinhome
mkdir -p "$HOME"

export DISPLAY=:99
# Rendu logiciel forcé : la VM A1 n'a pas de GPU.
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

Xvfb :99 -screen 0 "${RES}x24" -nolisten tcp &

# Attendre que le serveur X soit prêt (socket abstrait + fichier).
for _ in $(seq 1 50); do
    [ -e /tmp/.X11-unix/X99 ] && break
    sleep 0.2
done
if [ ! -e /tmp/.X11-unix/X99 ]; then
    echo "FATAL: Xvfb n'a pas démarré (pas de /tmp/.X11-unix/X99)" >&2
    exit 1
fi

# -localhost : jamais exposé hors du netns (=hôte avec --network=host) ;
# seul le pont /websockify authentifié du Studio y accède.
# -defer/-wait 20 : lisse la charge CPU du framebuffer scraping.
x11vnc -display :99 -localhost -rfbport 5900 -forever -shared -nopw \
       -noxdamage -defer 20 -wait 20 -quiet &

cd /game
exec /opt/godot --path . --rendering-driver opengl3 --audio-driver Dummy \
     --resolution "$RES"
