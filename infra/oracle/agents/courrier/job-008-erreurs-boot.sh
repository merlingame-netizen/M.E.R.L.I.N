#!/usr/bin/env bash
# Le jeu meurt au boot sur 40cb5188 (CI : FATAL). Remonter les VRAIES lignes
# d'erreur : erreurs script du godot.log + section FATAL du log CI, en tranches
# de 250 octets — chaque ligne du flux passe entière au poste de pilotage.
set -u
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
D="$RES/diag.txt"
{
  echo "== date =="; date -u +%H:%M:%SZ
  echo "== godot.log erreurs =="
  grep -nE "SCRIPT ERROR|Parse Error|not declared|Cannot|Invalid|ERROR|error while|Failed" \
      "$HOME/.cache/merlin-game/godot.log" 2>/dev/null | head -25
  echo "== godot.log fin =="
  tail -c 900 "$HOME/.cache/merlin-game/godot.log" 2>/dev/null
  echo
  echo "== ci FATAL =="
  grep -a -A 25 "FATAL: le jeu est mort" "$HOME/.cache/merlin-agents/logs/ci-commit.log" 2>/dev/null | tail -30
} > "$D" 2>&1
split -b 250 -d -a 3 "$D" /tmp/dg.
total=$(ls /tmp/dg.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/dg.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: boot8 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 1.2
done
rm -f /tmp/dg.*
echo "diag envoye en $total tranches"
