#!/usr/bin/env bash
# Synchro du jeu : si la branche suivie a bougé sur GitHub, on récupère,
# on réimporte les assets, et on relance le jeu s'il était en train de tourner.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

GAME_SH="$HERE/../game/game-sync.sh"
GS="$HERE/../game/game-stack.sh"

[ -d "$GAME_DIR/.git" ] || { echo "jeu pas encore cloné — rien à faire"; exit 0; }

git -C "$GAME_DIR" fetch origin "$GAME_REF" --quiet 2>/dev/null || {
    echo "fetch impossible (réseau ?)"; exit 1; }

LOCAL="$(git -C "$GAME_DIR" rev-parse HEAD 2>/dev/null)"
REMOTE="$(git -C "$GAME_DIR" rev-parse "origin/$GAME_REF" 2>/dev/null)"

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "à jour ($GAME_REF @ $(git -C "$GAME_DIR" rev-parse --short HEAD))"
    exit 0
fi

WAS_RUNNING=false
bash "$GS" status 2>/dev/null | grep -q '"vnc_open":true' && WAS_RUNNING=true

echo "nouveau commit détecté sur $GAME_REF — synchro + réimport" >&2
bash "$GAME_SH" >&2 || { echo "synchro ÉCHOUÉE"; exit 1; }

SHORT="$(git -C "$GAME_DIR" rev-parse --short HEAD)"
if [ "$WAS_RUNNING" = true ]; then
    RES="$(cat "$HOME/.cache/merlin-game/last-res" 2>/dev/null || echo 960x540)"
    bash "$GS" restart --res "$RES" >&2 && echo "synchro $SHORT + jeu relancé" \
        || { echo "synchro $SHORT mais relance ÉCHOUÉE"; exit 1; }
else
    echo "synchro $SHORT (jeu à l'arrêt, pas de relance)"
fi
