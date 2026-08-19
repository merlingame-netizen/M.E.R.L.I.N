#!/usr/bin/env bash
# Les marqueurs du log Godot de la partie 10 beats : qui a amorcé quoi, quel
# cerveau a écrit chaque génération, ce que le lookahead a fait, pourquoi le
# secours a servi. Tranches de 250 octets.
set -u
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
L="$HOME/.cache/merlin-game/godot.log"
D="$COURRIER_RES/marqueurs.txt"
{
  echo "== $(date -u +%H:%M:%SZ) log=$(stat -c %y "$L" 2>/dev/null | cut -c1-19) =="
  echo "== amorcage =="
  grep -an "amorçage\|Vif charg\|Conteur\|vif_ready\|mono-cerveau" "$L" | head -12
  echo "== generations (cerveau/duree) =="
  grep -a "\[MerlinNative\]" "$L" | grep -a "prompt" | head -30
  echo "== lookahead =="
  grep -an "lookahead\|cédée" "$L" | head -15
  echo "== secours =="
  grep -an "BANC DE SECOURS\|secours" "$L" | head -12
  echo "== arc =="
  grep -an "arc tranche\|arc :" "$L" | head -12
} > "$D" 2>&1
split -b 250 -d -a 3 "$D" /tmp/mq.
total=$(ls /tmp/mq.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/mq.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: marq15 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 1.5
done
rm -f /tmp/mq.*
echo "marqueurs envoyes en $total tranches"
