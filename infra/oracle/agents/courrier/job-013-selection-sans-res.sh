#!/usr/bin/env bash
# LA cause des cinq boots morts : game-stack lit la résolution d'écran dans $RES,
# que le courrier exportait comme dossier de résultats — Xvfb mourait sur
# « Invalid screen configuration .../job-010-...x24 ». Ici : env -u RES pour le
# runner, décharge Ollama + attente RAM conservées, tranches de 250 octets.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
SEL="$HOME/.cache/merlin-partie/selection.json"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
dire() { curl -fsS -m 20 -H "Title: sel13 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }

for m in $(curl -fsS -m 5 "$OLLAMA/api/ps" 2>/dev/null | python3 -c "
import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "$OLLAMA/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done
dispo=0
dl=$(( $(date +%s) + 90 ))
while :; do
    dispo=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    [ "$dispo" -gt 14000000 ] && break
    [ "$(date +%s)" -ge "$dl" ] && break
    sleep 3
done
dire "pret" "$(date -u +%H:%M:%SZ) MemAvailable=${dispo}kB"

env -u RES bash "$AGENTS/a_partie_journal.sh" selection > "$COURRIER_RES/selection_run.log" 2>&1
RCS=$?
if [ -s "$SEL" ]; then
    split -b 250 -d -a 3 "$SEL" /tmp/sl.
    total=$(ls /tmp/sl.* | wc -l | tr -d ' ')
    i=0
    for p in $(ls /tmp/sl.* | sort); do
        i=$((i+1))
        curl -fsS -m 30 --retry 2 -H "Title: sel10 part $i/$total" \
            --data-binary @"$p" "$NT" >/dev/null 2>&1
        sleep 1.2
    done
    rm -f /tmp/sl.*
    echo "selection OK ($total tranches)"
else
    dire "ko" "rc=$RCS : $(head -c 550 "$COURRIER_RES/selection_run.log" | tr '\n' ' ')"
    tail -c 700 "$HOME/.cache/merlin-game/inner.log" > "$COURRIER_RES/inner_queue.txt" 2>/dev/null || true
    echo "selection KO (rc=$RCS)"
    exit 1
fi
