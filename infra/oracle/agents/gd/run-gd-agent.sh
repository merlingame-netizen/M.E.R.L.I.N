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

# Verrou LLM PARTAGÉ entre tous les agents de game design (celui d'agent-run.sh
# est par-id : il n'empêche pas deux agents différents de charger deux modèles).
exec 8>"$STATE/llm.lock"
if ! flock -w 1800 8; then
    echo "LLM occupé plus de 30 min — on passe ce tour"
    exit 0
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
