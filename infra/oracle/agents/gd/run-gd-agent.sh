#!/usr/bin/env bash
# Lanceur commun des agents de game design.
#   run-gd-agent.sh <id>
#
# Rôle : sérialiser les accès au LLM (un seul agent parle au modèle à la fois —
# sinon deux modèles de 6 Go se disputent 22 Go de RAM et la VM part en swap),
# céder la priorité CPU au jeu, puis déléguer à runner.py.
#
# Écrit UNE ligne de résumé sur stdout : c'est le contrat d'agent-run.sh.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../game/game-env.sh"

ID="${1:-}"
[ -n "$ID" ] || { echo "usage: run-gd-agent.sh <id>"; exit 2; }
STATE="$HOME/.cache/merlin-agents"
mkdir -p "$STATE"

# LA PORTE DU JEU, AVANT LE VERROU. gates.py existait depuis août et personne ne l'appelait ici :
# gd-content-gap tournait à 4 h 30 avec quatre fils pendant la partie de la nuit (crible du 06/09,
# beats 11-13 à 98-128 s). Un godot qui tourne, quel qu'il soit, a les quatre cœurs.
PORTE="$(cd "$TOOLS_REPO" && python3 tools/gd_agents/gates.py 2>/dev/null)"
case "$PORTE" in
    OK*) : ;;
    *)   echo "$ID reporté : ${PORTE#STOP }"; exit 75 ;;
esac

# Verrou LLM PARTAGÉ entre tous les agents de game design (celui d'agent-run.sh
# est par-id : il n'empêche pas deux agents différents de charger deux modèles).
exec 8>"$STATE/llm.lock"
if ! flock -w 1800 8; then
    echo "LLM occupé plus de 30 min — on passe ce tour"
    exit 75
fi

OUT="$(cd "$TOOLS_REPO" && nice -n 10 python3 tools/gd_agents/runner.py "$ID" 2>&1 | tail -1)"
RC=$?

# Une proposition neuve mérite une notification discrète, pas une alerte.
if printf '%s' "$OUT" | grep -q '^proposition '; then
    N="$(ls "$HOME/.cache/merlin-proposals/inbox" 2>/dev/null | wc -l)"
    bash "$HERE/../notify.sh" low "MERLIN — idée" "$ID : $OUT ($N en attente)"
fi
echo "$OUT"
exit $RC
