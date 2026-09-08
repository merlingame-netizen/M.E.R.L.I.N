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

# JAMAIS PAR-DESSUS UNE PARTIE TENUE : un harnais (une sonde lancée à la main par le Courrier)
# ne se fait pas tuer par une synchro. Le commit attend le prochain passage.
HARNAIS="$(merlin_harnais)"
if [ -n "$HARNAIS" ]; then
    echo "nouveau commit, mais le jeu est tenu (harnais « $HARNAIS ») — synchro reportée"; exit 75
fi
# HÉBERGEMENT SEUL (2026-09-08) : plus de CI ni de smoke sur la VM — les preuves sont faites avant
# de pousser, par la session qui développe. Ici on synchronise, on importe, et on relance le jeu
# s'il tournait, pour que Maxime joue toujours le dernier commit.
echo "nouveau commit sur $GAME_REF — synchro et import" >&2
ETAIT_OUVERT="$(bash "$HERE/../game/game-stack.sh" status 2>/dev/null | tail -1 | python3 -c 'import json,sys
try:
    print(1 if json.loads(sys.stdin.read()).get("vnc_open") else 0)
except Exception:
    print(0)')"
bash "$HERE/../game/game-sync.sh" || { echo "synchro KO" >&2; exit 1; }
if [ "$ETAIT_OUVERT" = "1" ]; then
    echo "le jeu tournait : relance sur le nouveau commit" >&2
    bash "$HERE/../game/game-stack.sh" restart >/dev/null 2>&1 || echo "relance KO" >&2
fi
echo "synchronisé : $GAME_REF @ $(git -C "$GAME_DIR" rev-parse --short HEAD)"
