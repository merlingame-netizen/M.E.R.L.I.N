#!/usr/bin/env bash
# LE LABORATOIRE DU RÉCIT — batterie de mini-tests sur les textes du modèle (/goal 2026-08-18).
#
#   a_labo_recit.sh e4b   ou   a_labo_recit.sh e2b
#
# Richesse des issues (3 paliers), enchaînement (scène écrite en connaissant l'issue précédente
# contre la même à l'aveugle), témoin de voix — textes complets + compteurs réels par item.
# Lancée pour CHAQUE modèle : c'est la comparaison qui décide de l'architecture des cerveaux.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"
type -t etape >/dev/null 2>&1 || etape() { :; }

MODELE="${1:-e4b}"
GODOT_BIN="${GODOT_BIN:-$HOME/bin/godot}"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
OUT="$HOME/.cache/merlin-agents/labo-recit-$MODELE.json"
mkdir -p "$(dirname "$OUT")"

if bash "$HERE/../game/game-stack.sh" status 2>/dev/null | grep -q '"vnc_open":true'; then
    echo "jeu en cours d'utilisation — labo reporté"; exit 0
fi

etape 1 3 "décharger Ollama"
for m in $(curl -fsS -m 5 "$OLLAMA/api/ps" | python3 -c "
import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "$OLLAMA/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done

etape 2 3 "batterie $MODELE (jusqu'à 20 min)"
LOG="$(MERLIN_ALLOW_HEADLESS_LLM=1 MERLIN_MODELE="$MODELE" timeout 1500 nice -n 10 "$GODOT_BIN" \
       --headless --path "$GAME_DIR" --script res://tools/probe_labo_recit.gd 2>&1)"
RC=$?

etape 3 3 "dépôt du résultat"
JSON="$(printf '%s\n' "$LOG" | grep -m1 '^\[LABO_JSON\] ' | cut -d' ' -f2-)"
if [ -z "$JSON" ]; then
    printf '{"ok":false,"etape":"aucune mesure (code %s)"}\n' "$RC" > "$OUT"
    echo "aucune mesure — code $RC"; printf '%s\n' "$LOG" | tail -5
    exit 1
fi
printf '%s\n' "$JSON" > "$OUT"
printf '%s\n' "$LOG" | grep '^\[LABO\] '
echo "→ $OUT"
