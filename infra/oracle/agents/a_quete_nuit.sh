#!/usr/bin/env bash
# LA QUÊTE DE LA NUIT — un point par jour sur la prose, jugé et gardé.
#
# POURQUOI CET AGENT. Cinq tours de correction (q86 → q92) ont réglé le registre de la génération
# sans jamais bouger la narration. Pour savoir si un changement futur améliore l'écriture, il faut
# un point de mesure QUOTIDIEN et comparable, pas un job lancé à la main quand on y pense.
#
# CE QU'IL PRODUIT, chaque nuit et daté : la quête, le verdict du contrat (valider.py — ce qui est
# injouable), et la grille de lecture (relire.py — ce que le contrat ne sait pas refuser :
# l'adresse, les figures nommées, les regards, les bâtiments inventés).
#
# LA FORME DU LANCEMENT EST CELLE DE job-091, la seule qui ait abouti après six échecs
# d'infrastructure. Trois choses en viennent, et aucune n'est décorative :
#   - `env -u RES` : sans lui, Xvfb reçoit le dossier de résultats comme résolution d'écran.
#   - le contrôle de `--script` : un harnais qui ne part pas ressemble à un harnais qui échoue.
#   - la veille par le LOG et non par `pgrep` : un beat tient jusqu'à 130 s sans écrire une ligne
#     (1500 jetons à évaluer, puis 400 à écrire à 5 tok/s), et `pgrep` s'est trompé deux fois.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"
GS="$HERE/../game/game-stack.sh"
BASE="$HOME/.cache/merlin-quete"
GARDE="$BASE/nuit/$(date -u +%Y-%m-%d)"
OUT="$BASE/quete_generee.json"
LOG="$HOME/.cache/merlin-game/godot.log"
mkdir -p "$BASE"

# Depuis le 06/09 cet agent est appelé par a_partie_nuit.sh APRÈS la partie (« à la demande » dans
# le manifeste) : lancé à heure fixe, il trouvait le jeu occupé par la partie et sortait en 0 sans
# rien écrire. Un renoncement sort désormais en 75, et le dit.
DESIRED="$(cat "$HOME/.cache/merlin-game/desired" 2>/dev/null || echo stopped)"
HARNAIS="$(cat "$HOME/.cache/merlin-game/harness" 2>/dev/null || true)"
if [ -n "$HARNAIS" ] || [ "$DESIRED" = "running" ] || bash "$GS" status 2>/dev/null | grep -q '"vnc_open":true'; then
    echo "le jeu est occupé (harnais « $HARNAIS », desire=$DESIRED) — quête de la nuit reportée"; exit 75
fi
if [ -s "$GARDE/quete.json" ]; then
    echo "la quête de cette nuit est déjà écrite ($GARDE)"; exit 0
fi

for m in $(curl -fsS -m 5 "${OLLAMA_URL:-http://127.0.0.1:11434}/api/ps" 2>/dev/null | python3 -c "import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "${OLLAMA_URL:-http://127.0.0.1:11434}/api/generate" \
        -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done
DISPO=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
if [ "${DISPO:-0}" -lt 12000000 ]; then
    echo "mémoire insuffisante (${DISPO} ko) — quête de la nuit reportée"; exit 75
fi

env -u RES bash "$GS" stop >/dev/null 2>&1
sleep 5
rm -f "$OUT"
MERLIN_SCRIPT="res://tools/generer_quete.gd" \
  MERLIN_BEATS_Q=8 MERLIN_QUETE_OUT="$OUT" MERLIN_QUIT_AFTER_S=2700 \
  env -u RES bash "$GS" start >/dev/null 2>&1

sleep 12
LIGNE="$(grep -a 'native-inner. godot' "$HOME/.cache/merlin-game/inner.log" 2>/dev/null | tail -1)"
case "$LIGNE" in
    *generer_quete*) : ;;
    *) env -u RES bash "$GS" stop >/dev/null 2>&1
       echo "le jeu est parti SANS --script — quête abandonnée"; exit 1 ;;
esac

T0=$(date +%s); BUDGET=2400; SILENCE_MAX=360; VU=0; RAISON=inconnue
while :; do
    ECOULE=$(( $(date +%s) - T0 ))
    if [ -s "$OUT" ]; then RAISON="quête écrite après ${ECOULE}s"; sleep 3; break; fi
    if [ "$ECOULE" -ge "$BUDGET" ]; then RAISON="budget de ${BUDGET}s épuisé"; break; fi
    AGE=999
    [ -f "$LOG" ] && AGE=$(( $(date +%s) - $(stat -c %Y "$LOG" 2>/dev/null || echo 0) ))
    if pgrep -f "godot.*generer_quete" >/dev/null 2>&1; then
        VU=1
    elif [ "$AGE" -ge "$SILENCE_MAX" ] && [ "$VU" = 1 ]; then
        RAISON="processus absent et journal figé depuis ${AGE}s"; break
    elif [ "$VU" = 0 ] && [ "$ECOULE" -ge 300 ]; then
        RAISON="le jeu n'est jamais apparu"; break
    fi
    sleep 10
done
sleep 8
env -u RES bash "$GS" stop >/dev/null 2>&1

# La quête peut être à deux endroits : le chemin demandé, ou le repli user:// du générateur.
TROUVE=""
[ -s "$OUT" ] && TROUVE="$OUT"
if [ -z "$TROUVE" ]; then
    TROUVE="$(find "$HOME/.local/share/godot" "$HOME/.godot" -name 'quete_generee.json' \
              -newermt "-2 hours" 2>/dev/null | head -1)"
fi
if [ -z "$TROUVE" ]; then
    echo "aucune quête ($RAISON)"; exit 1
fi

mkdir -p "$GARDE"
cp "$TROUVE" "$GARDE/quete.json"
python3 "$GAME_DIR/tools/scenarios/valider.py" "$GARDE/quete.json" > "$GARDE/verdict.txt" 2>&1
VERDICT=$?
python3 "$GAME_DIR/tools/scenarios/relire.py" "$GARDE/quete.json" > "$GARDE/grille.txt" 2>&1 || true

# Trente nuits, comme la partie : au-delà on garde des quêtes qu'on ne relira pas.
find "$BASE/nuit" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | head -n -30 | while read -r vieux; do
    rm -rf "$vieux"
done

RESUME="$(python3 - "$GARDE/quete.json" <<'PY'
import json, sys
q = json.load(open(sys.argv[1], encoding="utf-8"))
b = q.get("beats") or []
signes = sum(len(str(x.get("scene", "")) + str(x.get("issue", ""))) for x in b)
print("%d beats · %d signes" % (len(b), signes))
PY
)"
ADRESSE="$(grep -a "adresse" "$GARDE/grille.txt" 2>/dev/null | head -1 | sed 's/^ *//')"
echo "$RESUME · contrat $([ "$VERDICT" = 0 ] && echo PASSÉ || echo REFUSÉ) · $ADRESSE ($RAISON)"
[ "$VERDICT" = 0 ]
