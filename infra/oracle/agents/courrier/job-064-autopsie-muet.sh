#!/usr/bin/env bash
# Autopsie du MOTEUR MUET (3e occurrence : p40, p59, p63). Le log de p63 est encore
# chaud. Motifs PRECIS cette fois : le grep de job-063 attrapait sched_reserve.
set -u
L="$HOME/.cache/merlin-game/godot.log"
D="$COURRIER_RES/muet.txt"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari064-$(date +%s)"
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
  echo "lancees=$(grep -ac 'génération lancée' "$L" 2>/dev/null)"
  echo "pretes=$(grep -ac 'prête au cache' "$L" 2>/dev/null)"
  echo "vides=$(grep -ac 'génération VIDE' "$L" 2>/dev/null)"
  echo "reessais=$(grep -ac 're-essai' "$L" 2>/dev/null)"
  echo "reserve_servie=$(grep -ac 'la réserve est servie' "$L" 2>/dev/null)"
  echo "cache_vide=$(grep -ac 'cache VIDE' "$L" 2>/dev/null)"
  echo "attente_vaine=$(grep -ac 'attente VAINE' "$L" 2>/dev/null)"
  echo "== la sequence, dans l'ordre du log =="
  grep -an 'génération lancée\|prête au cache\|génération VIDE\|re-essai\|réserve est servie\|cache VIDE\|attente VAINE\|cédée' "$L" 2>/dev/null | head -26
  echo "== issues natives (tok/s reels) =="
  grep -a 'issue (combinaison)' "$L" 2>/dev/null | head -8
} > "$D" 2>&1

split -b 250 -d -a 3 "$D" /tmp/t64.
total=$(ls /tmp/t64.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/t64.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: muet64 part $i/$total" --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 3
done
rm -f /tmp/t64.*
cp -f "$D" "$HOME/.cache/merlin-agents/muet64.copie.txt" 2>/dev/null || true
echo "autopsie muet envoyee en $total tranches via $NT"
