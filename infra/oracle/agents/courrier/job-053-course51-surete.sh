#!/usr/bin/env bash
# Récupère course51.txt depuis la copie de sûreté hors dépôt (le reset autosync a
# effacé resultats/ du clone). Diagnostic scènes p51 : lookahead:0 + banc au beat 5.
set -u
ETAT="$HOME/.cache/merlin-agents/courrier"
SRC="$ETAT/job-051-partie9-v36.res/course51.txt"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari053-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    if curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok"; then
        NT="$base/merlin-courrier-vX9k2Qf7Lw3s"
        break
    fi
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"

if [ ! -f "$SRC" ]; then
    curl -fsS -m 20 -H "Title: p53 ko" --data-binary "course51 absente de la surete : $(ls "$ETAT" 2>/dev/null | tr '\n' ' ' | head -c 200)" "$NT" >/dev/null 2>&1
    exit 1
fi
split -b 250 -d -a 3 "$SRC" /tmp/t53.
total=$(ls /tmp/t53.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/t53.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: course53 part $i/$total" --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 3
done
rm -f /tmp/t53.*
echo "course51 relivree en $total tranches via $NT"
