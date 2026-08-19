#!/usr/bin/env bash
# Contre-épreuve v31.2 : la tête d'issue en dernier + plus d'annulations. Une
# sélection puis une partie de 6 beats sur e135df92 ; le journal dira le compte.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
B="$HOME/.cache/merlin-partie"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
CIBLE="e135df92991f11f1782d415ee081df90bf2937d0"
dire() { curl -fsS -m 20 -H "Title: ce16 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }

deadline=$(( $(date +%s) + 1500 ))
force_fait=0
while ! git -C "$GD" merge-base --is-ancestor "$CIBLE" HEAD 2>/dev/null; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
        dire "ko" "jeu jamais sur v31.2 ($(git -C "$GD" rev-parse --short HEAD 2>/dev/null))"
        exit 1
    fi
    if [ "$force_fait" -eq 0 ] && [ "$(date +%s)" -ge $(( deadline - 900 )) ]; then
        bash "$AGENTS/a_game_autosync.sh" >> "$COURRIER_RES/autosync.log" 2>&1 || true
        force_fait=1
    fi
    sleep 20
done

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
dire "depart" "$(date -u +%H:%M:%SZ) sha=$(git -C "$GD" rev-parse --short HEAD)"

env -u RES bash "$AGENTS/a_partie_journal.sh" selection > "$COURRIER_RES/sel.log" 2>&1
[ -s "$B/selection.json" ] || { dire "ko" "selection absente : $(tail -c 400 "$COURRIER_RES/sel.log" | tr '\n' ' ')"; exit 1; }

MERLIN_BEATS=6 env -u RES bash "$AGENTS/a_partie_journal.sh" partie 0 \
    "contre-epreuve v31.2 : premier sentier de la selection" > "$COURRIER_RES/partie.log" 2>&1
RCP=$?
dire "fin" "rc=$RCP $(tail -c 250 "$COURRIER_RES/partie.log" | tr '\n' ' ')"

if [ -s "$B/journal.json" ]; then
    split -b 250 -d -a 3 "$B/journal.json" /tmp/j16.
    total=$(ls /tmp/j16.* | wc -l | tr -d ' ')
    i=0
    for p in $(ls /tmp/j16.* | sort); do
        i=$((i+1))
        curl -fsS -m 30 --retry 2 -H "Title: journal16 part $i/$total" \
            --data-binary @"$p" "$NT" >/dev/null 2>&1
        sleep 1.2
    done
    rm -f /tmp/j16.*
    echo "journal envoye en $total tranches"
else
    echo "journal ABSENT (rc=$RCP)"
    exit 1
fi
