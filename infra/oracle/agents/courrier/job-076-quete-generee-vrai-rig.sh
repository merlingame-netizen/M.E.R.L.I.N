#!/usr/bin/env bash
# job-076 — LA PREMIERE QUETE GENEREE, par le rig qui fait tourner les parties temoins.
#
# job-075 lancait `godot` a la main : rc=127, le binaire n'est pas dans le PATH. Et meme trouve,
# un godot nu n'aurait pas le sysroot ou vit l'extension du moteur. On passe donc par game-stack,
# comme la sonde, avec MERLIN_SCRIPT.
set -u
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
GS="$RP/infra/oracle/game/game-stack.sh"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
BASE="$HOME/.cache/merlin-quete"; mkdir -p "$BASE"
OUT="$BASE/quete_generee.json"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari076-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: q76 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

deadline=$(( $(date +%s) + 4800 ))

# ── LA GARDE. La derniere ligne est celle qui a manque a job-075 : sans MERLIN_CHAPITRE dans la
#    liste blanche d'unshare, la generation tourne sur ses defauts EN SILENCE.
while true; do
    A=0; B=0; C=0; D=0; E=0
    [ -f "$GD/tools/generer_quete.gd" ] && A=1
    [ -f "$GD/tools/scenarios/valider.py" ] && B=1
    [ -f "$GD/scripts/game/merlin_quete.gd" ] && C=1
    [ -d "$GD/data/quete" ] && D=1
    grep -q 'MERLIN_CHAPITRE=' "$GS" 2>/dev/null && E=1
    [ "$A$B$C$D$E" = "11111" ] && break
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "incomplet : generateur=$A contrat=$B squelette=$C data=$D listeblanche=$E"; exit 1; }
    sleep 30
done
SHA="$(git -C "$GD" rev-parse --short HEAD)"

for m in $(curl -fsS -m 5 "$OLLAMA/api/ps" 2>/dev/null | python3 -c "import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "$OLLAMA/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done
bon=0
while [ "$bon" -lt 2 ]; do
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "jamais d'accalmie"; exit 1; }
    dispo=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    if ! pgrep -x godot >/dev/null 2>&1 && [ "$dispo" -gt 14000000 ]; then bon=$((bon+1)); else bon=0; fi
    sleep 30
done
dire "depart" "$(date -u +%H:%M:%SZ) sha=$SHA — chapitre 1, 8 beats, par game-stack"

bash "$GS" stop >/dev/null 2>&1
sleep 5
rm -f "$OUT"
MERLIN_SCRIPT="res://tools/generer_quete.gd" \
  MERLIN_CHAPITRE=1 MERLIN_BEATS_Q=8 MERLIN_QUETE_OUT="$OUT" \
  MERLIN_QUIT_AFTER_S=2700 \
  bash "$GS" start > "$COURRIER_RES/lancement.log" 2>&1

# On attend le fichier, pas la fin du processus : le harnais quitte de lui-meme.
fin=$(( $(date +%s) + 2900 ))
while [ ! -s "$OUT" ]; do
    [ "$(date +%s)" -ge "$fin" ] && break
    sleep 20
done
bash "$GS" stop >/dev/null 2>&1

if [ ! -s "$OUT" ]; then
    { echo "-- lancement --"; tail -25 "$COURRIER_RES/lancement.log" 2>/dev/null
      echo "-- inner --";     tail -40 "$HOME/.cache/merlin-game/inner.log" 2>/dev/null
      echo "-- godot --";     tail -40 "$HOME/.cache/merlin-game/godot.log" 2>/dev/null
    } > "$COURRIER_RES/pourquoi76.txt"
    dire "ko" "aucune quete produite : $(tail -c 300 "$COURRIER_RES/pourquoi76.txt" | tr '\n' ' ')"
    curl -fsS -m 90 -T "$COURRIER_RES/pourquoi76.txt" -H "Filename: q76_pourquoi.txt" -H "Title: q76 pourquoi" "$NT" >/dev/null 2>&1
    exit 1
fi

cp "$OUT" "$COURRIER_RES/quete_generee.json"
python3 "$GD/tools/scenarios/valider.py" "$OUT" > "$COURRIER_RES/verdict76.txt" 2>&1
VERDICT=$?

RESUME=$(python3 - "$OUT" <<'PY' 2>/dev/null
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
b=d.get('beats') or []
sp=[x for x in b if x.get('special')]
o=[x for x in b if not x.get('special')]
chars=sum(len(str(x.get('scene',''))+str(x.get('issue',''))) for x in b)
vide=[x['n'] for x in b if len(str(x.get('scene','')).strip())<40 or len(str(x.get('issue','')).strip())<40]
print("ch%s · %d beats (%d speciaux) · tuiles %s · %d car. de prose · beats maigres: %s" % (
  d.get('chapitre'), len(b), len(sp), ','.join(sorted({x['action'][:3] for x in o})), chars, vide or 'aucun'))
PY
)
dire "verdict" "sha=$SHA · $RESUME · CONTRAT $([ "$VERDICT" = 0 ] && echo PASSE || echo REFUSE) · $(head -c 380 "$COURRIER_RES/verdict76.txt")"

for f in "$OUT:q76_quete.json" "$COURRIER_RES/verdict76.txt:q76_verdict.txt"; do
    curl -fsS -m 90 --retry 2 -T "${f%%:*}" -H "Filename: ${f##*:}" -H "Title: q76 ${f##*:}" "$NT" >/dev/null 2>&1
    sleep 2
done
tail -80 "$HOME/.cache/merlin-game/godot.log" 2>/dev/null | grep -a "beat \|preambule\|GENERATION\|ecrit" > "$COURRIER_RES/q76_log.txt"
curl -fsS -m 90 -T "$COURRIER_RES/q76_log.txt" -H "Filename: q76_log.txt" -H "Title: q76 log" "$NT" >/dev/null 2>&1
echo "job-076 : quete generee, contrat $([ "$VERDICT" = 0 ] && echo passe || echo refuse)."
