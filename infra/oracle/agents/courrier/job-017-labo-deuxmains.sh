#!/usr/bin/env bash
# Labo des Deux Mains (v33) : attendre le déploiement de 104bea60, dire le verdict
# CI du refactor, puis mesurer le duo (vif seul / conteur seul / LES DEUX) et tout
# remonter en tranches de corps.
set -u
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
GODOT_BIN="${GODOT_BIN:-$HOME/bin/godot}"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
CIBLE="104bea6046dc5e30e997de7dc89cc63f7cd10324"
dire() { curl -fsS -m 20 -H "Title: 2m17 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }

deadline=$(( $(date +%s) + 1500 ))
force_fait=0
while ! git -C "$GD" merge-base --is-ancestor "$CIBLE" HEAD 2>/dev/null; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
        dire "ko" "jeu jamais sur 104bea60 ($(git -C "$GD" rev-parse --short HEAD 2>/dev/null))"
        exit 1
    fi
    if [ "$force_fait" -eq 0 ] && [ "$(date +%s)" -ge $(( deadline - 900 )) ]; then
        bash "${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents/a_game_autosync.sh" \
            >> "$COURRIER_RES/autosync.log" 2>&1 || true
        force_fait=1
    fi
    sleep 20
done
dire "ci" "$(tail -c 650 "$HOME/.cache/merlin-agents/logs/ci-commit.log" 2>/dev/null | tr '\n' ' ')"

for m in $(curl -fsS -m 5 "$OLLAMA/api/ps" 2>/dev/null | python3 -c "
import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "$OLLAMA/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done

LOG="$(MERLIN_ALLOW_HEADLESS_LLM=1 timeout 1500 nice -n 10 "$GODOT_BIN" \
       --headless --path "$GD" --script res://tools/probe_labo_deuxmains.gd 2>&1)"
RC=$?
printf '%s\n' "$LOG" | grep -aE '^\[2M\]|^\[DEUXMAINS_JSON\]|SCRIPT ERROR|Parse Error' > "$COURRIER_RES/labo.txt"
printf '%s\n' "$LOG" | tail -c 1200 > "$COURRIER_RES/queue.txt"

split -b 250 -d -a 3 "$COURRIER_RES/labo.txt" /tmp/2m.
total=$(ls /tmp/2m.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/2m.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: 2m17 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 1.2
done
rm -f /tmp/2m.*
echo "labo rc=$RC envoye en $total tranches"
[ "$RC" -eq 0 ]
