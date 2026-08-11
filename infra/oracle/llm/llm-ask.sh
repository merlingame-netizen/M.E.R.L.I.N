#!/usr/bin/env bash
# Interroger le LLM local en une commande : le prompt arrive sur STDIN, la
# réponse sort sur STDOUT (texte brut). Options figées pour l'ARM 4 cœurs.
#   usage : echo "prompt" | llm-ask.sh [--model M] [--timeout S] [--ctx N]
# Sortie vide + rc!=0 si le serveur ou le modèle est indisponible : les
# appelants DOIVENT avoir un repli (jamais bloquer un agent sur le LLM).
set -uo pipefail
CONF="$HOME/.config/merlin-llm.env"
[ -f "$CONF" ] && . "$CONF"
MODEL="${TRIAGE_MODEL:-qwen2.5:3b}"; [ "$MODEL" = "AUTO" ] && MODEL="${COPILOT_MODEL:-qwen2.5:1.5b}"
TIMEOUT=120; CTX="${LLM_NUM_CTX:-2048}"

while [ $# -gt 0 ]; do case "$1" in
    --model)   MODEL="$2";   shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --ctx)     CTX="$2";     shift 2 ;;
    *) echo "option inconnue: $1" >&2; exit 2 ;;
esac; done

PROMPT="$(cat)"
[ -n "$PROMPT" ] || { echo "prompt vide" >&2; exit 2; }

export _LLM_PROMPT="$PROMPT"
python3 - "$MODEL" "$TIMEOUT" "$CTX" <<'PY'
import json, os, sys, urllib.request
model, timeout, ctx = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
prompt = os.environ["_LLM_PROMPT"]
host = os.environ.get("OLLAMA_HOST", "127.0.0.1:11434")
req = urllib.request.Request(
    f"http://{host}/api/generate",
    data=json.dumps({
        "model": model, "prompt": prompt, "stream": False,
        "keep_alive": os.environ.get("OLLAMA_KEEP_ALIVE", "30m"),
        "options": {"num_thread": 4, "num_ctx": ctx, "temperature": 0.2},
    }).encode(),
    headers={"content-type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=timeout) as r:
        d = json.load(r)
    print(d.get("response", "").strip())
except Exception as e:
    print(f"llm indisponible: {e}", file=sys.stderr); sys.exit(1)
PY
