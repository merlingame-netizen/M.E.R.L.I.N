#!/usr/bin/env bash
# Sélection de la démo v34 : attendre le déploiement de v34.1 (le fichier porte le cap
# de fréquence), puis l'accalmie complète, puis sélection + tranches.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
SEL="$HOME/.cache/merlin-partie/selection.json"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
dire() { curl -fsS -m 20 -H "Title: s26 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }

deadline=$(( $(date +%s) + 1500 ))
force_fait=0
while ! grep -q "conversions_this_quest < 2" "$GD/scripts/game/merlin_run.gd" 2>/dev/null; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
        dire "ko" "v34.1 jamais deployee ($(git -C "$GD" rev-parse --short HEAD 2>/dev/null))"
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
bon=0
while [ "$bon" -lt 2 ]; do
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "jamais d'accalmie"; exit 1; }
    dispo=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    if ! pgrep -x godot >/dev/null 2>&1 && ! pgrep -f "bin/godot" >/dev/null 2>&1 && [ "$dispo" -gt 14000000 ]; then
        bon=$((bon+1))
    else
        bon=0
    fi
    sleep 30
done
dire "depart" "$(date -u +%H:%M:%SZ) sha=$(git -C "$GD" rev-parse --short HEAD) dispo=${dispo}kB"

env -u RES bash "$AGENTS/a_partie_journal.sh" selection > "$COURRIER_RES/sel.log" 2>&1
RCS=$?
if [ ! -s "$SEL" ]; then
    dire "ko" "rc=$RCS : $(tail -c 500 "$COURRIER_RES/sel.log" | tr '\n' ' ')"
    exit 1
fi
split -b 250 -d -a 3 "$SEL" /tmp/s26.
total=$(ls /tmp/s26.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/s26.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: sel26 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 2
done
rm -f /tmp/s26.*
echo "selection envoyee en $total tranches"
