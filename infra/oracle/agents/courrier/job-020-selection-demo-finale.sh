#!/usr/bin/env bash
# Sélection de la démo finale 10 beats sur v33 — les trois sentiers remontent en
# tranches immédiates ; le pick argumenté viendra avec le job de partie.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
NT="https://ntfy.envs.net/merlin-courrier-vX9k2Qf7Lw3s"
SEL="$HOME/.cache/merlin-partie/selection.json"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
dire() { curl -fsS -m 20 -H "Title: s20 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }

for m in $(curl -fsS -m 5 "$OLLAMA/api/ps" 2>/dev/null | python3 -c "
import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "$OLLAMA/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done
dl=$(( $(date +%s) + 90 ))
while :; do
    dispo=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    [ "$dispo" -gt 14000000 ] && break
    [ "$(date +%s)" -ge "$dl" ] && break
    sleep 3
done

env -u RES bash "$AGENTS/a_partie_journal.sh" selection > "$COURRIER_RES/sel.log" 2>&1
RCS=$?
if [ ! -s "$SEL" ]; then
    dire "ko" "rc=$RCS : $(tail -c 500 "$COURRIER_RES/sel.log" | tr '\n' ' ')"
    exit 1
fi
split -b 250 -d -a 3 "$SEL" /tmp/s20.
total=$(ls /tmp/s20.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/s20.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: sel20 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 1.2
done
rm -f /tmp/s20.*
echo "selection envoyee en $total tranches"
