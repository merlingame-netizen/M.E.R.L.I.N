#!/usr/bin/env bash
# Veilleur du jeu : si l'état désiré est « running » et que le jeu est mort,
# on le relance. Ne démarre JAMAIS le jeu de sa propre initiative — l'état
# désiré est posé par les boutons PLAY / STOP du portail.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

GS="$HERE/../game/game-stack.sh"
DESIRED_FILE="$HOME/.cache/merlin-game/desired"
DESIRED="$(cat "$DESIRED_FILE" 2>/dev/null || echo stopped)"

STATUS="$(bash "$GS" status 2>/dev/null | tail -1)"
VNC="$(printf '%s' "$STATUS" | grep -o '"vnc_open":[a-z]*' | cut -d: -f2)"

if [ "$DESIRED" != "running" ]; then
    echo "état désiré=$DESIRED — rien à faire"; exit 0
fi
if [ "$VNC" = "true" ]; then
    echo "jeu en cours — OK"; exit 0
fi

RES="$(cat "$HOME/.cache/merlin-game/last-res" 2>/dev/null || echo 960x540)"
echo "jeu mort alors qu'il devait tourner — relance en $RES" >&2
if bash "$GS" start --res "$RES" >&2; then
    echo "jeu relancé ($RES)"
else
    echo "ÉCHEC de la relance — voir les journaux du jeu"; exit 1
fi
