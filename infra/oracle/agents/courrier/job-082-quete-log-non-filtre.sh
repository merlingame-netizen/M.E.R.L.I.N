#!/usr/bin/env bash
# job-082 — LA GENERATION, ET UN LOG QU'ON NE FILTRE PLUS.
#
# q81 : sept beats sur huit a 58 s/beat, puis plus rien. Le generateur imprimait « ecriture
# impossible » et mon grep ne le cherchait pas. On ne filtre plus, et on cherche la quete aux deux
# endroits ou elle peut etre.
set -u
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
GS="$RP/infra/oracle/game/game-stack.sh"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
ETAT="$HOME/.cache/merlin-agents/courrier"
BOITE="$RP/infra/oracle/agents/courrier"
BASE="$HOME/.cache/merlin-quete"; mkdir -p "$BASE"; chmod 777 "$BASE" 2>/dev/null
OUT="$BASE/quete_generee.json"
LOG="$HOME/.cache/merlin-game/godot.log"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari082-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: q82 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

relancer_la_file() {
    local reste
    reste=$(cd "$BOITE" 2>/dev/null && for f in job-*.sh; do [ -f "$ETAT/${f%.sh}.fait" ] || echo "${f%.sh}"; done | head -1)
    [ -n "$reste" ] || return 0
    setsid nohup env -u RES bash "$RP/infra/oracle/agents/a_courrier.sh" > "$HOME/.cache/courrier-suite.log" 2>&1 &
}
trap relancer_la_file EXIT

deadline=$(( $(date +%s) + 5400 ))
while true; do
    A=0; B=0
    grep -q 'ÉCRITURE IMPOSSIBLE' "$GD/tools/generer_quete.gd" 2>/dev/null && A=1
    grep -q '_beat_entier' "$GD/tools/generer_quete.gd" 2>/dev/null && B=1
    [ "$A$B" = "11" ] && break
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "incomplet : repli_ecriture=$A un_appel=$B"; exit 1; }
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
    dispo=$(sed -n 's/^MemAvailable:[[:space:]]*\([0-9]*\).*/\1/p' /proc/meminfo)
    if ! pgrep -x godot >/dev/null 2>&1 && [ "${dispo:-0}" -gt 14000000 ]; then bon=$((bon+1)); else bon=0; fi
    sleep 30
done
T_DEPART=$(date +%s)
dire "depart" "$(date -u +%H:%M:%SZ) sha=$SHA — ch1, 8 beats"

env -u RES bash "$GS" stop >/dev/null 2>&1
sleep 5
rm -f "$OUT"
MERLIN_SCRIPT="res://tools/generer_quete.gd" \
  MERLIN_CHAPITRE=1 MERLIN_BEATS_Q=8 MERLIN_QUETE_OUT="$OUT" \
  MERLIN_QUIT_AFTER_S=3300 \
  env -u RES bash "$GS" start > "$COURRIER_RES/lancement.log" 2>&1

T0=$(date +%s); BUDGET=2400; VU=0; MANQUES=0
while [ $(( $(date +%s) - T0 )) -lt "$BUDGET" ]; do
    if pgrep -f "godot.*generer_quete" >/dev/null 2>&1; then
        [ "$VU" = 0 ] && dire "en-vol" "le jeu tourne"
        VU=1; MANQUES=0
    elif [ "$VU" = 1 ]; then
        MANQUES=$(( MANQUES + 1 )); [ "$MANQUES" -ge 2 ] && break
    elif [ -s "$OUT" ]; then sleep 3; break
    elif [ $(( $(date +%s) - T0 )) -ge 300 ]; then break
    fi
    sleep 10
done
sleep 8
env -u RES bash "$GS" stop >/dev/null 2>&1
DUREE=$(( $(date +%s) - T_DEPART ))

# LA QUETE PEUT ETRE A DEUX ENDROITS : le chemin demande, ou le repli user:// du generateur.
TROUVE=""
[ -s "$OUT" ] && TROUVE="$OUT"
if [ -z "$TROUVE" ]; then
    CAND=$(find "$HOME/.local/share/godot" "$HOME/.godot" -name 'quete_generee.json' -newermt "-2 hours" 2>/dev/null | head -1)
    [ -n "$CAND" ] && TROUVE="$CAND"
fi

# ON NE FILTRE PLUS : les quarante dernieres lignes du harnais, quelles qu'elles soient.
tail -40 "$LOG" 2>/dev/null > "$COURRIER_RES/q82_log.txt"

if [ -z "$TROUVE" ]; then
    dire "ko" "pas de quete apres ${DUREE}s (vu=$VU) — log en piece jointe, non filtre"
    curl -fsS -m 90 -T "$COURRIER_RES/q82_log.txt" -H "Filename: q82_log.txt" -H "Title: q82 log" "$NT" >/dev/null 2>&1
    exit 1
fi

cp "$TROUVE" "$COURRIER_RES/quete_generee.json"
python3 "$GD/tools/scenarios/valider.py" "$TROUVE" > "$COURRIER_RES/verdict82.txt" 2>&1
VERDICT=$?
DIAG=$(python3 - "$TROUVE" <<'PY' 2>/dev/null
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
e=d.get('_erreurs_moteur') or {}
b=d.get('beats') or []
chars=sum(len(str(x.get('scene',''))+str(x.get('issue',''))) for x in b)
vides=[x['n'] for x in b if len(str(x.get('scene','')).strip())<40]
print("%d beats · %d car. de prose · vides: %s · ERREURS: %s" % (len(b), chars, vides or 'aucun',
  "; ".join("%dx %s" % (v,k) for k,v in e.items()) if e else 'AUCUNE'))
PY
)
dire "verdict" "sha=$SHA · ${DUREE}s · trouvee: $TROUVE · $DIAG · CONTRAT $([ "$VERDICT" = 0 ] && echo PASSE || echo REFUSE)"
for f in "$TROUVE:q82_quete.json" "$COURRIER_RES/verdict82.txt:q82_verdict.txt" "$COURRIER_RES/q82_log.txt:q82_log.txt"; do
    curl -fsS -m 90 --retry 2 -T "${f%%:*}" -H "Filename: ${f##*:}" -H "Title: q82 ${f##*:}" "$NT" >/dev/null 2>&1
    sleep 2
done
echo "job-082 : ${DUREE}s, $DIAG"
