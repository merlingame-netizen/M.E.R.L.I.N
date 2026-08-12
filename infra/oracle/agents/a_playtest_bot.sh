#!/usr/bin/env bash
# Playtest nocturne : le bot joue au jeu rendu et remonte les anomalies.
# Démarre le jeu s'il est éteint (et le rééteint après), jamais quand Maxime joue.
#
# `pipefail` est INDISPENSABLE ici : sans lui, `OUT="$(… | tail -1)"` suivi de
# `RC=$?` lit le code de retour de `tail`, qui vaut toujours 0. Un crash du bot
# était donc enregistré « ok: true », et le portail affichait un agent au vert.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"
GS="$HERE/../game/game-stack.sh"

# Si l'état désiré est "running", quelqu'un joue peut-être : on ne touche à rien.
DESIRED="$(cat "$HOME/.cache/merlin-game/desired" 2>/dev/null || echo stopped)"
if [ "$DESIRED" = "running" ]; then
    cd "$TOOLS_REPO" && python3 tools/gd_agents/gates.py >/dev/null 2>&1 \
        || { echo "session humaine possible — playtest annulé"; exit 0; }
fi

WAS=false
bash "$GS" status 2>/dev/null | grep -q '"vnc_open":true' && WAS=true
if [ "$WAS" = false ]; then
    bash "$GS" start --res 960x540 >&2 || { echo "impossible de démarrer le jeu"; exit 1; }
    sleep 12
fi
OUT="$(cd "$TOOLS_REPO" && nice -n 10 python3 tools/gd_agents/playtest_bot.py 16 2>&1 | tail -1)"
RC=$?
[ "$WAS" = false ] && bash "$GS" stop >/dev/null 2>&1
printf '%s' "$OUT" | grep -q anomalie && \
    bash "$HERE/notify.sh" default "Playtest" "$OUT"
echo "$OUT"
exit $RC
