#!/usr/bin/env bash
# Choisit le palier pour une tâche, puis interroge le LLM avec ses réglages.
# Le prompt arrive sur STDIN, la réponse sort sur STDOUT — même contrat que
# llm-ask.sh, dont ce script n'est qu'un aiguillage.
#
#   echo "prompt" | llm-route.sh --shape compose --out-tokens 250 --deadline 300
#
# rc≠0 si aucun palier n'est utilisable : l'appelant DOIT avoir un repli
# (les agents écrivent alors une proposition « preuves seules »).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${MERLIN_REPO:-$HOME/workspace/M.E.R.L.I.N}"
CONF="$HOME/.config/merlin-llm.env"
[ -f "$CONF" ] && . "$CONF"

PLAN="$(python3 "$REPO/tools/gd_agents/router.py" --explain "$@" 2>&1 >/dev/null)"
TAG="$(python3 "$REPO/tools/gd_agents/router.py" "$@" 2>/dev/null)"
[ -n "$TAG" ] || { echo "aucun palier utilisable: $PLAN" >&2; exit 1; }

CTX="$(printf '%s' "$PLAN"    | python3 -c "import json,sys; print(json.load(sys.stdin)['ctx'])" 2>/dev/null || echo 2048)"
THREADS="$(printf '%s' "$PLAN" | python3 -c "import json,sys; print(json.load(sys.stdin)['num_thread'])" 2>/dev/null || echo 4)"
KEEP="$(printf '%s' "$PLAN"   | python3 -c "import json,sys; print(json.load(sys.stdin)['keep_alive'])" 2>/dev/null || echo 5m)"
EST="$(printf '%s' "$PLAN"    | python3 -c "import json,sys; print(json.load(sys.stdin)['est_secs'])" 2>/dev/null || echo 180)"

echo "[route] $TAG ctx=$CTX threads=$THREADS est=${EST}s" >&2
# nice : le jeu passe avant le LLM quand les deux tournent.
OLLAMA_NUM_THREAD="$THREADS" OLLAMA_KEEP_ALIVE="$KEEP" \
    nice -n 10 bash "$HERE/llm-ask.sh" --model "$TAG" --ctx "$CTX" --predict "${OUT_TOKENS:-320}" --timeout "$((EST * 2 + 60))"
