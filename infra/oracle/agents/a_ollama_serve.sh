#!/usr/bin/env bash
# Veilleur Ollama : garantit que le serveur LLM local tourne (userland, pas de
# systemd) et que le modèle copilote reste résident en RAM (réponse immédiate).
set -uo pipefail
CONF="$HOME/.config/merlin-llm.env"
[ -f "$CONF" ] || { echo "pas encore installé (lancer llm/ollama-setup.sh)"; exit 0; }
. "$CONF"
BIN="$HOME/opt/ollama/bin/ollama"
[ -x "$BIN" ] || { echo "binaire ollama absent"; exit 0; }

if ! curl -fsS -m 3 "http://$OLLAMA_HOST/api/version" >/dev/null 2>&1; then
    echo "serveur mort — relance" >&2
    nohup env OLLAMA_HOST="$OLLAMA_HOST" OLLAMA_KEEP_ALIVE="$OLLAMA_KEEP_ALIVE" \
        OLLAMA_NUM_PARALLEL="$OLLAMA_NUM_PARALLEL" OLLAMA_MAX_LOADED_MODELS="$OLLAMA_MAX_LOADED_MODELS" \
        "$BIN" serve > "$HOME/.cache/ollama-serve.log" 2>&1 &
    for _ in $(seq 1 20); do
        curl -fsS -m 2 "http://$OLLAMA_HOST/api/version" >/dev/null 2>&1 && break; sleep 1
    done
    curl -fsS -m 2 "http://$OLLAMA_HOST/api/version" >/dev/null 2>&1 \
        || { echo "relance KO — voir ~/.cache/ollama-serve.log"; exit 1; }
    RELANCE=oui
else
    RELANCE=non
fi

# Copilote résident : réchauffé si déchargé (keep_alive long, prompt vide = load pur).
LOADED="$(curl -fsS -m 5 "http://$OLLAMA_HOST/api/ps" 2>/dev/null | grep -c "${COPILOT_MODEL:-none}" || true)"
if [ "$LOADED" = "0" ] && [ -n "${COPILOT_MODEL:-}" ]; then
    curl -fsS -m 60 "http://$OLLAMA_HOST/api/generate" \
        -d "{\"model\":\"$COPILOT_MODEL\",\"prompt\":\"\",\"keep_alive\":\"2h\"}" >/dev/null 2>&1 \
        && WARM=rechargé || WARM=échec
else
    WARM=résident
fi
echo "serveur OK (relance=$RELANCE) · copilote $COPILOT_MODEL: $WARM"
