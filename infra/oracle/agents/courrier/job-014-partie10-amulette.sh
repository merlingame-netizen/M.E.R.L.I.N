#!/usr/bin/env bash
# Démo 10 beats — phase 2 : la partie sur « L'Amulette du Vent » (pick 2).
# Trio complet : objet à reprendre, créancier incarné (Korrigans), échéance.
# env -u RES (la résolution d'écran !), décharge Ollama + attente RAM, puis la
# partie ; au retour le journal part en tranches de 250 octets, les clichés en
# pièces jointes (le courrier les envoie depuis $COURRIER_RES).
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
B="$HOME/.cache/merlin-partie"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
dire() { curl -fsS -m 20 -H "Title: partie14 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }

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
dire "depart" "$(date -u +%H:%M:%SZ) MemAvailable=${dispo}kB beats=10 pick=2"

MERLIN_BEATS=10 env -u RES bash "$AGENTS/a_partie_journal.sh" partie 2 \
    "seul sentier au trio complet : objet a reprendre, creancier incarne (Korrigans), echeance" \
    > "$COURRIER_RES/partie_run.log" 2>&1
RCP=$?
dire "fin-partie" "rc=$RCP $(tail -c 300 "$COURRIER_RES/partie_run.log" | tr '\n' ' ')"

if [ -s "$B/journal.json" ]; then
    split -b 250 -d -a 3 "$B/journal.json" /tmp/j10.
    total=$(ls /tmp/j10.* | wc -l | tr -d ' ')
    i=0
    for p in $(ls /tmp/j10.* | sort); do
        i=$((i+1))
        curl -fsS -m 30 --retry 2 -H "Title: journal10 part $i/$total" \
            --data-binary @"$p" "$NT" >/dev/null 2>&1
        sleep 1.2
    done
    rm -f /tmp/j10.*
    mkdir -p "$COURRIER_RES/cliches"
    cp -f "$B"/cliches/*.png "$COURRIER_RES/cliches/" 2>/dev/null || true
    echo "journal envoye en $total tranches"
else
    tail -c 700 "$HOME/.cache/merlin-game/inner.log" > "$COURRIER_RES/inner_queue.txt" 2>/dev/null || true
    echo "journal ABSENT (rc=$RCP)"
    exit 1
fi
