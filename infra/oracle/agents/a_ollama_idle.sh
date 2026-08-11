#!/usr/bin/env bash
# Décharge des modèles LLM inactifs (DÉSACTIVÉ par défaut dans agents.json).
# Cette VM est un atelier : l'IA doit pouvoir tourner en continu. À n'activer
# que si la RAM manque pendant les sessions de jeu.
set -uo pipefail
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
IDLE_MIN="${OLLAMA_IDLE_MIN:-20}"
MARK="$HOME/.cache/merlin-agents/ollama-last-busy"

LOADED="$(curl -fsS -m 5 "$OLLAMA/api/ps" 2>/dev/null | python3 -c "
import json,sys
try: print(len(json.load(sys.stdin).get('models') or []))
except Exception: print(-1)")"

[ "$LOADED" = "-1" ] && { echo "ollama injoignable"; exit 0; }
[ "$LOADED" = "0" ]  && { echo "aucun modèle chargé"; exit 0; }

date -u +%s > "$MARK.now"
LAST="$(cat "$MARK" 2>/dev/null || echo 0)"
NOW="$(date -u +%s)"
[ "$LAST" = "0" ] && { cp "$MARK.now" "$MARK"; echo "$LOADED modèle(s) — début de la fenêtre d'inactivité"; exit 0; }

IDLE_S=$(( NOW - LAST ))
if [ "$IDLE_S" -lt $(( IDLE_MIN * 60 )) ]; then
    echo "$LOADED modèle(s) chargé(s), inactifs depuis $(( IDLE_S / 60 )) min (seuil ${IDLE_MIN})"
    exit 0
fi

# keep_alive=0 demande à Ollama de libérer immédiatement le modèle.
for m in $(curl -fsS -m 5 "$OLLAMA/api/ps" | python3 -c "
import json,sys
for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))"); do
    curl -fsS -m 10 "$OLLAMA/api/generate" \
        -d "{\"model\":\"$m\",\"prompt\":\"\",\"keep_alive\":0}" >/dev/null 2>&1
done
: > "$MARK"
echo "$LOADED modèle(s) déchargé(s) après $(( IDLE_S / 60 )) min d'inactivité"
