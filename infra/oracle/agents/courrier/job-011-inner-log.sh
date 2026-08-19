#!/usr/bin/env bash
# godot.log muet depuis 11:00 malgré quatre boots : la mort est dans la pile AVANT
# godot. inner.log porte l'erreur — en tranches de corps (les pièces jointes sont
# rationnées 429 côté poste).
set -u
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
RUN="$HOME/.cache/merlin-game/run"
D="$RES/pile.txt"
{
  echo "== $(date -u +%H:%M:%SZ) =="
  echo "== run dir =="
  ls -la "$RUN" 2>/dev/null | head -12
  echo "== inner.log (fin) =="
  tail -c 1200 "$RUN/inner.log" 2>/dev/null
  echo
  echo "== xvfb.log (fin) =="
  tail -c 400 "$RUN/xvfb.log" 2>/dev/null
  echo
  echo "== godot.log mtime =="
  stat -c '%y %s' "$HOME/.cache/merlin-game/godot.log" "$RUN/godot.log" 2>/dev/null
} > "$D" 2>&1
split -b 250 -d -a 3 "$D" /tmp/pl.
total=$(ls /tmp/pl.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/pl.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: pile11 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 1.2
done
rm -f /tmp/pl.*
echo "pile envoyee en $total tranches"
