#!/usr/bin/env bash
# Synchro du jeu (secours du webhook, toutes les 15 min) : si la branche suivie
# a bougé sur GitHub, on délègue TOUT à la CI de commit (sync + import + smoke
# + capture + relance si le jeu tournait) — une seule source de vérité.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

[ -d "$GAME_DIR/.git" ] || { echo "jeu pas encore cloné — rien à faire"; exit 0; }

git -C "$GAME_DIR" fetch origin "$GAME_REF" --quiet 2>/dev/null || {
    echo "fetch impossible (réseau ?)"; exit 1; }

LOCAL="$(git -C "$GAME_DIR" rev-parse HEAD 2>/dev/null)"
REMOTE="$(git -C "$GAME_DIR" rev-parse "origin/$GAME_REF" 2>/dev/null)"
if [ "$LOCAL" = "$REMOTE" ]; then
    echo "à jour ($GAME_REF @ $(git -C "$GAME_DIR" rev-parse --short HEAD))"; exit 0
fi

echo "nouveau commit sur $GAME_REF — passage de main à la CI" >&2
exec bash "$HERE/agent-run.sh" ci-commit
