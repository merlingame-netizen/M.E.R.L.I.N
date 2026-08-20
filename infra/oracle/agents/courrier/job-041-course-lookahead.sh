#!/usr/bin/env bash
# La course du lookahead sur p40 : tout ce que le log en dit, en tranches.
set -u
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
L="$HOME/.cache/merlin-game/godot.log"
D="$COURRIER_RES/course.txt"
{
  echo "== $(date -u +%H:%M:%SZ) log=$(stat -c %y "$L" 2>/dev/null | cut -c1-19) =="
  echo "== lookahead (tout) =="
  grep -an "lookahead" "$L" 2>/dev/null | head -30
  echo "== scene gen (natif) =="
  grep -a "\[MerlinNative\]" "$L" 2>/dev/null | grep -a "scène" | head -12
  echo "== arc =="
  grep -an "arc tranche\|arc :" "$L" 2>/dev/null | head -12
  echo "== issues (vif) =="
  grep -a "issue (combinaison)" "$L" 2>/dev/null | head -8
} > "$D" 2>&1
split -b 250 -d -a 3 "$D" /tmp/co.
total=$(ls /tmp/co.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/co.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: course41 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 2
done
rm -f /tmp/co.*
echo "course envoyee en $total tranches"
