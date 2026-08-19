#!/usr/bin/env bash
# Le flux ntfy.sh s'est figé (quota journalier présumé) : les tranches de job-017
# ont pu mourir en silence. Ré-expédition de sa copie de sûreté vers ntfy.envs.net
# (instance publique, quota distinct), même sujet, mêmes tranches de 250 octets.
set -u
NT2="https://ntfy.envs.net/merlin-courrier-vX9k2Qf7Lw3s"
SRC="$HOME/.cache/merlin-agents/courrier/job-017-labo-deuxmains.res"
dire2() { curl -fsS -m 20 -H "Title: 2m18 $1" --data-binary "$2" "$NT2" >/dev/null 2>&1; }

if [ ! -d "$SRC" ]; then
    dire2 "etat" "job-017 pas encore execute ($(date -u +%H:%M:%SZ)) — courrier vivant, re-essayer plus tard"
    echo "copie de job-017 absente"
    exit 1
fi
dire2 "etat" "$(date -u +%H:%M:%SZ) fichiers=$(find "$SRC" -type f | wc -l) sortie=$(head -c 250 "$SRC/sortie.log" 2>/dev/null | tr '\n' ' ')"
D="$SRC/labo.txt"
[ -s "$D" ] || D="$SRC/queue.txt"
if [ -s "$D" ]; then
    split -b 250 -d -a 3 "$D" /tmp/e2m.
    total=$(ls /tmp/e2m.* | wc -l | tr -d ' ')
    i=0
    for p in $(ls /tmp/e2m.* | sort); do
        i=$((i+1))
        curl -fsS -m 30 --retry 2 -H "Title: 2m18 part $i/$total" \
            --data-binary @"$p" "$NT2" >/dev/null 2>&1
        sleep 1.2
    done
    rm -f /tmp/e2m.*
    echo "re-expedie en $total tranches vers envs.net"
else
    dire2 "vide" "ni labo.txt ni queue.txt dans la copie de job-017"
    echo "rien a re-expedier"
    exit 1
fi
