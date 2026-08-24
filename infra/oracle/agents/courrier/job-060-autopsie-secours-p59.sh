#!/usr/bin/env bash
# Autopsie du SECOURS de p59 : le beat 2 a rendu 1 token (moteur muet) et le banc a servi.
# Le filet v35.5 (re-essai sur generation VIDE) a-t-il mordu ? Le log est encore chaud.
set -u
L="$HOME/.cache/merlin-game/godot.log"
D="$COURRIER_RES/autopsie59.txt"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari060-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    if curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok"; then
        NT="$base/merlin-courrier-vX9k2Qf7Lw3s"
        break
    fi
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"

{
  echo "== log=$(stat -c %y "$L" 2>/dev/null | cut -c1-19) =="
  echo "vides=$(grep -ac 'génération VIDE' "$L" 2>/dev/null) reessais=$(grep -ac 're-essai' "$L" 2>/dev/null) bancs=$(grep -ac 'secours\|filet' "$L" 2>/dev/null)"
  echo "== issue : lancee / prete / vide / cache / vaine / re-essai (ordre du log) =="
  grep -an 'génération lancée\|prête au cache\|génération VIDE\|cache VIDE\|attente VAINE\|re-essai' "$L" 2>/dev/null | head -24
  echo "== issues (natif) =="
  grep -a 'issue (combinaison)' "$L" 2>/dev/null | head -10
} > "$D" 2>&1

split -b 250 -d -a 3 "$D" /tmp/t60.
total=$(ls /tmp/t60.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/t60.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: autopsie60 part $i/$total" --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 3
done
rm -f /tmp/t60.*
echo "autopsie59 envoyee en $total tranches via $NT"
