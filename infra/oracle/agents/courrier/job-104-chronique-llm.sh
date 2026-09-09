#!/usr/bin/env bash
# job-104 — LA CHRONIQUE IMAGÉE D'UNE PARTIE ENTIÈREMENT GÉNÉRÉE (demande de Maxime, 09/09).
# Le modèle écrit les trois sentiers, le bot couvrant en joue un jusqu'au bout, la sonde prend un
# cliché à chaque beat (scène) et après chaque résolution (verdict, issue), et tient le journal :
# textes, gestes, dé, marge, jauges, temps de chaque beat et d'attente du moteur.
# Tout part avec ce job : selection.json, journal.json, les clichés, les journaux techniques.
set -uo pipefail
echo "=== job-104 : chronique imagée, partie 100 % générée — $(date -u +%FT%TZ) ==="
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMOIN="$HERE/../game/partie-temoin.sh"
BASE="$HOME/.cache/merlin-partie"
[ -f "$TEMOIN" ] || { echo "partie-temoin.sh absent — l'outillage n'est pas à jour"; exit 1; }

echo "--- 0. le jeu joué"
cd "${GAME_DIR:-$HOME/workspace/merlin-game}" 2>/dev/null && git log --oneline -1 && cd - >/dev/null
free -h | sed -n 2p

echo; echo "--- 1. les trois sentiers, écrits par le modèle (jusqu'à 15 min)"
T0=$(date +%s)
env -u RES MERLIN_BIOME=foret bash "$TEMOIN" selection 8>&- 2>&1 | tail -8
if [ ! -s "$BASE/selection.json" ]; then
    echo "pas de sélection : la partie ne peut pas commencer"; exit 1
fi
cp "$BASE/selection.json" "$RES/selection.json"
echo "sélection en $(( $(date +%s) - T0 )) s"

echo; echo "--- 2. la partie, longueur libre, bot couvrant, tous les clichés (détachée : elle survit à ce job)"
rm -rf "$BASE/cliches"; mkdir -p "$BASE/cliches"
rm -f "$BASE/journal.json"
setsid nohup env -u RES MERLIN_BIOME=foret MERLIN_BOT_COUVRANT=1 MERLIN_SHOTS_MAX=80 \
    bash "$TEMOIN" partie 0 "chronique imagée : sentier pris au premier, tel que le modèle l'a écrit" \
    > "$BASE/chronique.log" 2>&1 8>&- < /dev/null &
echo "partie lancée (pid $!)"

echo; echo "--- 3. attente du journal (jusqu'à 75 min dans ce job ; au-delà, un job suivant le ramassera)"
T1=$(date +%s)
FIN=0
while [ $(( $(date +%s) - T1 )) -lt 4500 ]; do
    if [ -s "$BASE/journal.json" ] && ! pgrep -f "godot.*probe_partie_journal" >/dev/null 2>&1; then
        sleep 5; FIN=1; break
    fi
    sleep 20
done
echo "attente : $(( $(date +%s) - T1 )) s · fini=$FIN"

echo; echo "--- 4. ce qui part"
[ -s "$BASE/journal.json" ] && cp "$BASE/journal.json" "$RES/journal.json"
cp "$BASE/cliches"/*.png "$RES/" 2>/dev/null
cp "$BASE/chronique.log" "$RES/chronique.log" 2>/dev/null
grep -av "^llama_model_loader\|^print_info\|^load_tensors\|^llama_kv_cache\|^ggml_" "$HOME/.cache/merlin-game/godot.log" 2>/dev/null | tail -300 > "$RES/godot.tail.log"
ls "$RES" | wc -l | sed 's/^/  fichiers : /'
python3 - "$RES/journal.json" <<'PYX' 2>/dev/null || echo "  journal absent ou illisible"
import json, sys
d = json.load(open(sys.argv[1]))
b = d.get("beats") or []
print("  beats : %d · fin : %s · clichés : %d · incidents : %d" % (len(b), (d.get("fin") or {}).get("type", "en cours"), len(d.get("cliches") or []), len(d.get("incidents") or [])))
for x in b:
    print("  b%02d %-11s %-9s dé=%-2s total=%-2s dc=%-2s %5.0fs attente %5.0fs  %s" % (
        int(x.get("index", 0)), str(x.get("type", ""))[:11], str(x.get("degre", "?"))[:9], x.get("de", "?"),
        x.get("total", "?"), x.get("dc", "?"), float(x.get("duree_beat_s", 0)), float(x.get("attente_moteur_s", 0)),
        str(x.get("narration", ""))[:50].replace("\n", " ")))
PYX
[ "$FIN" = 1 ] || echo "PARTIE ENCORE EN COURS à la fin du job : déposer job-105 pour ramasser la suite"
echo "=== job-104 fini ==="
