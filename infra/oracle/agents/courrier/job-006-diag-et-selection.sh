#!/usr/bin/env bash
# job-004 est mort sur « aucun résultat après 0s » : pgrep n'a jamais vu le probe.
# Ici : état des lieux (âge du log, desired, processus godot vivants) envoyé en CORPS
# de messages (fidèles via le flux NDJSON), puis jusqu'à TROIS essais de sélection.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
SEL="$HOME/.cache/merlin-partie/selection.json"
dire() { curl -fsS -m 20 -H "Title: diag6 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }

dire "avant" "$(date -u +%H:%M:%SZ) log_age=$(stat -c %Y "$HOME/.cache/merlin-game/godot.log" 2>/dev/null) now=$(date +%s) desired=$(cat "$HOME/.cache/merlin-game/desired" 2>/dev/null) godot=$(pgrep -c godot 2>/dev/null)"

ok=0
for essai in 1 2 3; do
    bash "$AGENTS/a_partie_journal.sh" selection > "$RES/essai$essai.log" 2>&1
    rc=$?
    if [ -s "$SEL" ]; then
        dire "essai$essai" "OK rc=$rc"
        ok=1
        break
    fi
    dire "essai$essai" "KO rc=$rc : $(head -c 600 "$RES/essai$essai.log" | tr '\n' ' ')"
    sleep 10
done

if [ "$ok" = "1" ]; then
    split -b 3000 -d -a 2 "$SEL" /tmp/sl.
    total=$(ls /tmp/sl.* | wc -l | tr -d ' ')
    i=0
    for p in $(ls /tmp/sl.* | sort); do
        i=$((i+1))
        curl -fsS -m 30 --retry 2 -H "Title: selection10 part $i/$total" \
            --data-binary @"$p" "$NT" >/dev/null 2>&1
        sleep 2
    done
    rm -f /tmp/sl.*
    echo "selection obtenue et envoyee en $total tranche(s)"
else
    tail -c 2500 "$HOME/.cache/merlin-game/godot.log" > "$RES/godot_fin.txt" 2>/dev/null
    dire "echec-final" "$(pgrep -af godot 2>/dev/null | head -3 | tr '\n' '|' | head -c 700)"
    echo "selection toujours absente apres 3 essais"
    exit 1
fi
