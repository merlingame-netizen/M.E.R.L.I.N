#!/usr/bin/env bash
# job-075 — LA PREMIERE QUETE GENEREE PAR LE MODELE, et son passage au contrat.
#
# Le modele n'ecrit que la prose : la mecanique (longueur, types, beats speciaux, bascules, des,
# atouts, pioche) est calculee par tools/generer_quete.gd. Le contrat ne devrait donc rien avoir a
# redire. Ce qui peut etre mauvais, c'est l'ECRITURE — et aucun validateur ne sait la juger.
# Le job remonte donc la quete ENTIERE, pas seulement un verdict.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari075-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: q75 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

deadline=$(( $(date +%s) + 4200 ))

# ── LA GARDE : sans le generateur ET le contrat, il n'y a rien a faire.
while true; do
    A=0; B=0; C=0; D=0
    [ -f "$GD/tools/generer_quete.gd" ] && A=1
    [ -f "$GD/tools/scenarios/valider.py" ] && B=1
    [ -f "$GD/scripts/game/merlin_quete.gd" ] && C=1
    [ -d "$GD/data/quete" ] && D=1
    [ "$A$B$C$D" = "1111" ] && break
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "incomplet : generateur=$A contrat=$B squelette=$C data=$D (jeu=$(git -C "$GD" rev-parse --short HEAD 2>/dev/null))"; exit 1; }
    sleep 30
done
SHA="$(git -C "$GD" rev-parse --short HEAD)"

# Le moteur est mono-place : on rend la RAM avant de demander.
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
dire "depart" "$(date -u +%H:%M:%SZ) sha=$SHA — generation chapitre 1, 8 beats"

# ── LA GENERATION
OUT="$COURRIER_RES/quete_generee.json"
cd "$GD" || exit 1
MERLIN_ALLOW_HEADLESS_LLM=1 MERLIN_CHAPITRE=1 MERLIN_BEATS_Q=8 \
  MERLIN_QUETE_OUT="$OUT" \
  timeout 3000 godot --headless --path . --script res://tools/generer_quete.gd \
  > "$COURRIER_RES/generation.log" 2>&1
RC=$?

if [ ! -s "$OUT" ]; then
    tail -30 "$COURRIER_RES/generation.log" > "$COURRIER_RES/pourquoi75.txt"
    dire "ko" "aucune quete produite (rc=$RC) : $(tail -c 260 "$COURRIER_RES/generation.log" | tr '\n' ' ')"
    exit 1
fi

# ── LE CONTRAT, sur la sortie brute du modele
python3 "$GD/tools/scenarios/valider.py" "$OUT" > "$COURRIER_RES/verdict75.txt" 2>&1
VERDICT=$?

# ── CE QU'ON REMONTE : les chiffres, puis la quete entiere.
RESUME=$(python3 - "$OUT" <<'PY' 2>/dev/null
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
b=d.get('beats') or []
sp=[x for x in b if x.get('special')]
ord_=[x for x in b if not x.get('special')]
tui=sorted({x['action'] for x in ord_})
run=sorted({x['rune'] for x in ord_})
chars=sum(len(str(x.get('scene',''))+str(x.get('issue',''))) for x in b)
print("%d beats (%d speciaux) · tuiles %d/5 %s · runes %d · %d caracteres de prose" % (
  len(b), len(sp), len(tui), ','.join(t[:3] for t in tui), len(run), chars))
PY
)
dire "verdict" "sha=$SHA rc=$RC · $RESUME · CONTRAT: $([ "$VERDICT" = 0 ] && echo PASSE || echo REFUSE) · $(head -c 420 "$COURRIER_RES/verdict75.txt")"

curl -fsS -m 90 --retry 2 -T "$OUT" -H "Filename: q75_quete.json" -H "Title: q75 quete" "$NT" >/dev/null 2>&1
sleep 2
curl -fsS -m 90 --retry 2 -T "$COURRIER_RES/verdict75.txt" -H "Filename: q75_verdict.txt" -H "Title: q75 verdict" "$NT" >/dev/null 2>&1
sleep 2
tail -60 "$COURRIER_RES/generation.log" > "$COURRIER_RES/q75_log.txt"
curl -fsS -m 90 --retry 2 -T "$COURRIER_RES/q75_log.txt" -H "Filename: q75_log.txt" -H "Title: q75 log" "$NT" >/dev/null 2>&1
echo "job-075 : quete generee (rc=$RC), contrat $([ "$VERDICT" = 0 ] && echo passe || echo refuse)."
