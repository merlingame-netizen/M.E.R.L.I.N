#!/usr/bin/env bash
# prov=arc:6 malgré le fix beat-borne : que fait VRAIMENT le prefetch de scène ?
# Marqueurs du log Godot de la partie v35, en tranches de 250 octets.
set -u
NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
L="$HOME/.cache/merlin-game/godot.log"
D="$COURRIER_RES/lk.txt"
{
  echo "== $(date -u +%H:%M:%SZ) log=$(stat -c %y "$L" 2>/dev/null | cut -c1-19) =="
  echo "== lookahead =="
  grep -an "lookahead" "$L" | head -25
  echo "== scenes (gen) =="
  grep -a "\[MerlinNative\]" "$L" | grep -a "scène\|scene" | head -15
  echo "== arc =="
  grep -an "arc tranche\|arc :" "$L" | head -15
} > "$D" 2>&1
split -b 250 -d -a 3 "$D" /tmp/lk.
total=$(ls /tmp/lk.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/lk.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: lk31 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 2
done
rm -f /tmp/lk.*
echo "marqueurs envoyes en $total tranches"
