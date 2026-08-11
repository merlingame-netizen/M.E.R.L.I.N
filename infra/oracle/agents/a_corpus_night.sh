#!/usr/bin/env bash
# Usine à corpus : génère des cartes Gemma 4 filtrées par le validateur.
# Boxée par le temps (35 min de budget pour une cadence de 45 min), gate
# jeu/RAM dans control_loops, verrou LLM partagé avec les agents gd.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"
exec 8>"$HOME/.cache/merlin-agents/llm.lock"
flock -w 60 8 || { echo "LLM occupé — on passe ce tour"; exit 0; }
cd "$TOOLS_REPO" && exec nice -n 10 python3 tools/cockpit/control_loops.py gen \
    --backend gemma --count 30 --max-secs 2100
