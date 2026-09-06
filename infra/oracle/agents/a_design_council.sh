#!/usr/bin/env bash
# Conseil de design quotidien : un conseiller ouvre la conversation du jour.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"
(cd "$TOOLS_REPO" && python3 tools/gd_agents/gates.py >/dev/null 2>&1) || { echo "jeu en cours — le conseil attendra (gates)"; exit 75; }
exec 8>"$HOME/.cache/merlin-agents/llm.lock"
flock -w 600 8 || { echo "LLM occupé — le conseil attendra demain"; exit 0; }
cd "$TOOLS_REPO" && exec nice -n 10 python3 tools/gd_agents/design_council.py
