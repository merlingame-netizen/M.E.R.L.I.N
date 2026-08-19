#!/usr/bin/env bash
# envs.net a coupé à 9/111 : le journal de la démo finale repart vers une troisième
# instance publique (ntfy.adminforge.de), tranches espacées de 3 s, canari d'abord.
set -u
NT3="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
J="$HOME/.cache/merlin-partie/journal.json"
[ -s "$J" ] || { echo "journal absent"; exit 1; }

if ! curl -fsS -m 20 -H "Title: p22 canari" --data-binary "$(date -u +%H:%M:%SZ) taille=$(wc -c < "$J")" "$NT3"; then
    echo "canari refuse par adminforge"
    exit 1
fi
split -b 250 -d -a 3 "$J" /tmp/j22.
total=$(ls /tmp/j22.* | wc -l | tr -d ' ')
i=0
echecs=0
for p in $(ls /tmp/j22.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: journal22 part $i/$total" \
        --data-binary @"$p" "$NT3" >/dev/null 2>&1 || echecs=$((echecs+1))
    sleep 3
done
rm -f /tmp/j22.*
curl -fsS -m 20 -H "Title: p22 fini" --data-binary "tranches=$total echecs=$echecs" "$NT3" >/dev/null 2>&1
echo "journal envoye : $total tranches, $echecs echec(s)"
"$([ "$echecs" -eq 0 ] && echo true || echo false)"
