#!/usr/bin/env bash
# Sélection rejouée après l'élargissement du gate (fddd727d) : le braséro ne
# réchauffe plus Ollama pendant un boot. Tranches de 250 octets — chaque ligne
# du flux NDJSON passe entière au poste de pilotage.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
SEL="$HOME/.cache/merlin-partie/selection.json"
dire() { curl -fsS -m 20 -H "Title: sel9 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }

dire "avant" "$(date -u +%H:%M:%SZ) ollama=$(curl -fsS -m 5 http://127.0.0.1:11434/api/ps 2>/dev/null | head -c 120)"
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
    dire "ko" "rc=$RCS : $(head -c 600 "$RES/selection_run.log" | tr '\n' ' ')"
    echo "selection KO (rc=$RCS)"
    exit 1
fi
