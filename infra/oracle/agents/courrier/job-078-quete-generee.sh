#!/usr/bin/env bash
# job-078 — LA PREMIERE QUETE GENEREE. Quatrieme tentative, et les trois echecs ont la meme cause :
# j'ai reimplemente ce que le depot faisait deja, sans lire pourquoi il le faisait ainsi.
#
#   job-075  `godot` lance a la main : rc=127, pas dans le PATH, et pas de sysroot pour le moteur.
#   job-076  `game-stack` appele sans `env -u RES` : Xvfb recoit le dossier de resultats comme
#            resolution d'ecran et meurt. Tous les jobs qui marchent ecrivent ce `env -u RES`.
#   job-077  le rig DEMARRE correctement, et ma porte a 40 s tue un lancement sain. a_partie_journal
#            documente l'incident depuis le 2026-08-21 et s'en protege par une grace de 300 s.
#
# Ici, le motif d'attente est copie de la sonde, pas reinvente.
set -u
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
GS="$RP/infra/oracle/game/game-stack.sh"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
BASE="$HOME/.cache/merlin-quete"; mkdir -p "$BASE"
OUT="$BASE/quete_generee.json"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari078-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: q78 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

deadline=$(( $(date +%s) + 5400 ))
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
dire "depart" "$(date -u +%H:%M:%SZ) sha=$SHA — chapitre 1, 8 beats"

env -u RES bash "$GS" stop >/dev/null 2>&1
sleep 5
rm -f "$OUT"
MERLIN_SCRIPT="res://tools/generer_quete.gd" \
  MERLIN_CHAPITRE=1 MERLIN_BEATS_Q=8 MERLIN_QUETE_OUT="$OUT" \
  MERLIN_QUIT_AFTER_S=3300 \
  env -u RES bash "$GS" start > "$COURRIER_RES/lancement.log" 2>&1

# ── L'ATTENTE, copiee de a_partie_journal.sh. Grace de 300 s pendant laquelle « jamais vu » ne
#    conclut rien, et DEUX absences consecutives pour conclure : sous la charge du modele, un
#    passage peut rater un processus bien vivant.
T0=$(date +%s); BUDGET=3400; VU=0; MANQUES=0
while [ $(( $(date +%s) - T0 )) -lt "$BUDGET" ]; do
    if pgrep -f "godot.*generer_quete" >/dev/null 2>&1; then
        [ "$VU" = 0 ] && dire "en-vol" "le jeu tourne depuis $(( $(date +%s) - T0 ))s"
        VU=1; MANQUES=0
    elif [ "$VU" = 1 ]; then
        MANQUES=$(( MANQUES + 1 ))
        [ "$MANQUES" -ge 2 ] && break
    elif [ -s "$OUT" ]; then
        sleep 3; break
    elif [ $(( $(date +%s) - T0 )) -ge 300 ]; then
        break
    fi
    sleep 10
done
sleep 5
env -u RES bash "$GS" stop >/dev/null 2>&1

if [ ! -s "$OUT" ]; then
    { echo "vu=$VU apres $(( $(date +%s) - T0 ))s"
      echo "-- lancement --"; tail -12 "$COURRIER_RES/lancement.log" 2>/dev/null
      echo "-- godot --"; grep -a "GENERATION\|beat \|preambule\|ecrit\|SCRIPT ERROR\|Parse Error\|moteur" "$HOME/.cache/merlin-game/godot.log" 2>/dev/null | tail -40
      echo "-- inner --"; tail -20 "$HOME/.cache/merlin-game/inner.log" 2>/dev/null
    } > "$COURRIER_RES/pourquoi78.txt"
    dire "ko" "pas de quete (vu=$VU) : $(tail -c 300 "$COURRIER_RES/pourquoi78.txt" | tr '\n' ' ')"
    curl -fsS -m 90 -T "$COURRIER_RES/pourquoi78.txt" -H "Filename: q78_pourquoi.txt" -H "Title: q78 pourquoi" "$NT" >/dev/null 2>&1
    exit 1
fi

cp "$OUT" "$COURRIER_RES/quete_generee.json"
python3 "$GD/tools/scenarios/valider.py" "$OUT" > "$COURRIER_RES/verdict78.txt" 2>&1
VERDICT=$?
RESUME=$(python3 - "$OUT" <<'PY' 2>/dev/null
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
b=d.get('beats') or []
o=[x for x in b if not x.get('special')]
chars=sum(len(str(x.get('scene',''))+str(x.get('issue',''))) for x in b)
print("ch%s · %d beats (%d spec.) · tuiles %s · %d car. de prose" % (
  d.get('chapitre'), len(b), len(b)-len(o), ','.join(sorted({x['action'][:3] for x in o})), chars))
PY
)
dire "verdict" "sha=$SHA · $RESUME · CONTRAT $([ "$VERDICT" = 0 ] && echo PASSE || echo REFUSE) · $(head -c 360 "$COURRIER_RES/verdict78.txt")"
for f in "$OUT:q78_quete.json" "$COURRIER_RES/verdict78.txt:q78_verdict.txt"; do
    curl -fsS -m 90 --retry 2 -T "${f%%:*}" -H "Filename: ${f##*:}" -H "Title: q78 ${f##*:}" "$NT" >/dev/null 2>&1
    sleep 2
done
echo "job-078 : quete generee, contrat $([ "$VERDICT" = 0 ] && echo passe || echo refuse)."
