#!/usr/bin/env bash
# Le crash « Out of bounds get index '0' » : fichier et ligne (le at: qui suit).
set -u
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
L="$HOME/.cache/merlin-game/godot.log"
D="$COURRIER_RES/crash.txt"
{
  echo "== $(date -u +%H:%M:%SZ) =="
  echo "== SCRIPT ERROR avec contexte =="
  grep -an -A 3 "SCRIPT ERROR" "$L" 2>/dev/null | grep -av xkbcommon | head -30
  echo "== autour de la 1re occurrence =="
  ln=$(grep -an "Out of bounds" "$L" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -n "$ln" ]; then
    sed -n "$(( ln > 20 ? ln - 20 : 1 )),$(( ln + 20 ))p" "$L"
  fi
} > "$D" 2>&1
split -b 250 -d -a 3 "$D" /tmp/cr.
total=$(ls /tmp/cr.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/cr.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: crash39 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 2
done
rm -f /tmp/cr.*
echo "crash localise envoye en $total tranches"
