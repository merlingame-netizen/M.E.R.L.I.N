#!/usr/bin/env bash
# Codeur local : applique les missions acceptées (before/after) sur auto/nightly.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"
exec 8>"$HOME/.cache/merlin-agents/llm.lock"
flock -w 900 8 || { echo "LLM occupé — on passe"; exit 0; }
cd "$TOOLS_REPO" && exec nice -n 10 python3 tools/gd_agents/coder_local.py
