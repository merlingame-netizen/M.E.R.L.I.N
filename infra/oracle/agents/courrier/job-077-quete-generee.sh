#!/usr/bin/env bash
# job-077 — LA PREMIERE QUETE GENEREE. Troisieme tentative, et les deux echecs valaient la peine.
#
#   job-075  rc=127 : `godot` n'est pas dans le PATH, et un godot nu n'a pas le sysroot du moteur.
#   job-076  Xvfb a recu le DOSSIER DE RESULTATS comme resolution d'ecran. Le Courrier exporte RES
#            comme chemin (a_courrier.sh:41), game-stack l'utilise comme resolution (:15). Tous les
#            jobs qui marchent ecrivent `env -u RES` ; j'avais recopie ce mot sans en comprendre la
#            raison, et je l'ai omis en appelant game-stack directement.
#
# Ici : env -u RES, et une garde qui verifie que le garde-fou de game-stack est bien descendu.
set -u
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
GS="$RP/infra/oracle/game/game-stack.sh"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
BASE="$HOME/.cache/merlin-quete"; mkdir -p "$BASE"
OUT="$BASE/quete_generee.json"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari077-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: q77 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

deadline=$(( $(date +%s) + 5400 ))

# ── LA GARDE. La derniere ligne est celle qui aurait sauve job-076 : sans le garde-fou dans
#    game-stack, un seul oubli de `env -u RES` fait mourir Xvfb en deguisant la cause.
while true; do
    A=0; B=0; C=0; D=0; E=0; F=0
    [ -f "$GD/tools/generer_quete.gd" ] && A=1
    [ -f "$GD/tools/scenarios/valider.py" ] && B=1
    [ -f "$GD/scripts/game/merlin_quete.gd" ] && C=1
    [ -d "$GD/data/quete" ] && D=1
    grep -q 'MERLIN_CHAPITRE=' "$GS" 2>/dev/null && E=1
    grep -q "n'est pas une resolution" "$GS" 2>/dev/null && F=1
    [ "$A$B$C$D$E$F" = "111111" ] && break
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "incomplet : gen=$A contrat=$B squelette=$C data=$D listeblanche=$E gardefou=$F"; exit 1; }
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
dire "depart" "$(date -u +%H:%M:%SZ) sha=$SHA — chapitre 1, 8 beats, env -u RES"

env -u RES bash "$GS" stop >/dev/null 2>&1
sleep 5
rm -f "$OUT"
# env -u RES : SANS LUI, Xvfb recoit le dossier de resultats en guise de resolution et meurt.
MERLIN_SCRIPT="res://tools/generer_quete.gd" \
  MERLIN_CHAPITRE=1 MERLIN_BEATS_Q=8 MERLIN_QUETE_OUT="$OUT" \
  MERLIN_QUIT_AFTER_S=3000 \
  env -u RES bash "$GS" start > "$COURRIER_RES/lancement.log" 2>&1

# On confirme que le jeu a VRAIMENT demarre avant d'attendre trois quarts d'heure pour rien.
sleep 40
if ! pgrep -f "godot.*generer_quete" >/dev/null 2>&1; then
    { echo "-- lancement --"; tail -20 "$COURRIER_RES/lancement.log" 2>/dev/null
      echo "-- inner --";     tail -30 "$HOME/.cache/merlin-game/inner.log" 2>/dev/null
      echo "-- xvfb --";      tail -20 "$HOME/.cache/merlin-game/xvfb.log" 2>/dev/null
    } > "$COURRIER_RES/pourquoi77.txt"
    dire "ko" "le jeu n'a pas demarre : $(grep -a 'EE\|FATAL' "$COURRIER_RES/pourquoi77.txt" | head -2 | tr '\n' ' ' | head -c 300)"
    curl -fsS -m 90 -T "$COURRIER_RES/pourquoi77.txt" -H "Filename: q77_pourquoi.txt" -H "Title: q77 pourquoi" "$NT" >/dev/null 2>&1
    env -u RES bash "$GS" stop >/dev/null 2>&1
    exit 1
fi
dire "en-vol" "le jeu tourne, generation en cours"

fin=$(( $(date +%s) + 3200 ))
while [ ! -s "$OUT" ]; do
    [ "$(date +%s)" -ge "$fin" ] && break
    pgrep -f "godot.*generer_quete" >/dev/null 2>&1 || { sleep 20; break; }
    sleep 20
done
env -u RES bash "$GS" stop >/dev/null 2>&1

if [ ! -s "$OUT" ]; then
    { echo "-- godot --"; grep -a "GENERATION\|beat \|preambule\|ecrit\|SCRIPT ERROR\|Parse Error" "$HOME/.cache/merlin-game/godot.log" 2>/dev/null | tail -40
      echo "-- inner --"; tail -25 "$HOME/.cache/merlin-game/inner.log" 2>/dev/null
    } > "$COURRIER_RES/pourquoi77.txt"
    dire "ko" "pas de quete : $(tail -c 300 "$COURRIER_RES/pourquoi77.txt" | tr '\n' ' ')"
    curl -fsS -m 90 -T "$COURRIER_RES/pourquoi77.txt" -H "Filename: q77_pourquoi.txt" -H "Title: q77 pourquoi" "$NT" >/dev/null 2>&1
    exit 1
fi

cp "$OUT" "$COURRIER_RES/quete_generee.json"
python3 "$GD/tools/scenarios/valider.py" "$OUT" > "$COURRIER_RES/verdict77.txt" 2>&1
VERDICT=$?
RESUME=$(python3 - "$OUT" <<'PY' 2>/dev/null
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
b=d.get('beats') or []
o=[x for x in b if not x.get('special')]
chars=sum(len(str(x.get('scene',''))+str(x.get('issue',''))) for x in b)
maigres=[x['n'] for x in b if len(str(x.get('scene','')).strip())<40 or len(str(x.get('issue','')).strip())<40]
print("ch%s · %d beats (%d spec.) · tuiles %s · %d car. · maigres: %s" % (
  d.get('chapitre'), len(b), len(b)-len(o), ','.join(sorted({x['action'][:3] for x in o})), chars, maigres or 'aucun'))
PY
)
dire "verdict" "sha=$SHA · $RESUME · CONTRAT $([ "$VERDICT" = 0 ] && echo PASSE || echo REFUSE) · $(head -c 360 "$COURRIER_RES/verdict77.txt")"
for f in "$OUT:q77_quete.json" "$COURRIER_RES/verdict77.txt:q77_verdict.txt"; do
    curl -fsS -m 90 --retry 2 -T "${f%%:*}" -H "Filename: ${f##*:}" -H "Title: q77 ${f##*:}" "$NT" >/dev/null 2>&1
    sleep 2
done
echo "job-077 : quete generee, contrat $([ "$VERDICT" = 0 ] && echo passe || echo refuse)."
