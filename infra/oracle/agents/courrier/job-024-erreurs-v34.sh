#!/usr/bin/env bash
# Premier boot v34 mort : les VRAIES lignes d'erreur (script/parse) du godot.log.
set -u
NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
L="$HOME/.cache/merlin-game/godot.log"
D="$COURRIER_RES/err.txt"
{
  echo "== $(date -u +%H:%M:%SZ) log=$(stat -c %y "$L" 2>/dev/null | cut -c1-19) =="
  echo "== erreurs script =="
  grep -anE "SCRIPT ERROR|Parse Error|Invalid|not declared|Cannot|error" "$L" | grep -av xkbcommon | head -30
  echo "== fin du log =="
  tail -c 700 "$L"
} > "$D" 2>&1
split -b 250 -d -a 3 "$D" /tmp/e24.
total=$(ls /tmp/e24.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/e24.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: err24 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 2
done
rm -f /tmp/e24.*
echo "erreurs envoyees en $total tranches"
