#!/usr/bin/env bash
# Course42 — autopsie du lookahead de p42 : SECOURS=0 mais prov=arc:6 (0 servie).
# Le log godot dit si les scènes ont été lancées, écrites, jetées (« Trop tard »),
# ou jamais parties (conteur jamais rendu dans les 30 s d'attente bornée).
set -u
L="$HOME/.cache/merlin-game/godot.log"
D="$COURRIER_RES/course42.txt"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.envs.net https://ntfy.sh; do
    tok="canari047-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    if curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok"; then
        NT="$base/merlin-courrier-vX9k2Qf7Lw3s"
        break
    fi
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"

{
  echo "== $(date -u +%H:%M:%SZ) log=$(stat -c %y "$L" 2>/dev/null | cut -c1-19) =="
  echo "== comptes =="
  echo "gen_scenes_lookahead=$(grep -ac 'scène.*(lookahead)' "$L" 2>/dev/null)"
  echo "pretes=$(grep -ac 'lookahead — scène.*prête' "$L" 2>/dev/null)"
  echo "== lookahead (tout, 40 lignes) =="
  grep -an "lookahead" "$L" 2>/dev/null | head -40
  echo "== scene gen (natif) =="
  grep -a "\[MerlinNative\]" "$L" 2>/dev/null | grep -a "scène" | head -12
  echo "== arc =="
  grep -an "arc tranche\|arc :" "$L" 2>/dev/null | head -12
  echo "== issues (vif) =="
  grep -a "issue (combinaison)" "$L" 2>/dev/null | head -8
  echo "== issue lancee/cache =="
  grep -an "génération lancée\|prête au cache\|cache VIDE\|attente VAINE" "$L" 2>/dev/null | head -14
} > "$D" 2>&1

split -b 250 -d -a 3 "$D" /tmp/c42.
total=$(ls /tmp/c42.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/c42.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: course42 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 3
done
rm -f /tmp/c42.*
echo "course42 envoyee en $total tranches via $NT"
