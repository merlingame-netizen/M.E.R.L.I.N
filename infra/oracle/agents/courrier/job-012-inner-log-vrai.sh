#!/usr/bin/env bash
# job-011 visait ~/.cache/merlin-game/run/ qui n'existe pas (RUNDIR est le dossier
# lui-même) et son 2>/dev/null avalait l'erreur. Les bons chemins, sans bâillon.
set -u
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
RUN="$HOME/.cache/merlin-game"
D="$RES/pile.txt"
{
  echo "== $(date -u +%H:%M:%SZ) =="
  echo "== inventaire =="
  ls -la "$RUN" | head -16
  echo "== inner.log (fin) =="
  tail -c 1100 "$RUN/inner.log"
  echo
  echo "== xvfb.log (fin) =="
  tail -c 300 "$RUN/xvfb.log"
  echo
} > "$D" 2>&1
split -b 250 -d -a 3 "$D" /tmp/pl.
total=$(ls /tmp/pl.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/pl.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: pile12 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 1.2
done
rm -f /tmp/pl.*
echo "pile envoyee en $total tranches"
