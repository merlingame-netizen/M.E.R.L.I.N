#!/usr/bin/env bash
# La décharge Ollama est ASYNCHRONE : à 12:40:01 e4b (6,0 Go) était encore résident
# une seconde avant le boot, et le chargement bi-cerveaux (10,5 Go) mourait en OOM
# silencieux. Ici : décharge, puis ATTENTE que MemAvailable repasse 14 Go (90 s max),
# et seulement alors la sélection. Tranches de 250 octets au retour.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
SEL="$HOME/.cache/merlin-partie/selection.json"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
dire() { curl -fsS -m 20 -H "Title: sel11 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }

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
dire "ram" "$(date -u +%H:%M:%SZ) MemAvailable=${dispo}kB ollama=$(curl -fsS -m 5 "$OLLAMA/api/ps" 2>/dev/null | head -c 80)"

bash "$AGENTS/a_partie_journal.sh" selection > "$RES/selection_run.log" 2>&1
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
    dire "ko" "rc=$RCS : $(head -c 550 "$RES/selection_run.log" | tr '\n' ' ')"
    tail -c 700 "$HOME/.cache/merlin-game/run/inner.log" > "$RES/inner_queue.txt" 2>/dev/null || true
    echo "selection KO (rc=$RCS)"
    exit 1
fi
