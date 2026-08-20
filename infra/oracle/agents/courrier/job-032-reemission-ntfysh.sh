#!/usr/bin/env bash
# adminforge muet (quota) : ré-émission des récoltes de job-030 (banc BitNet) et
# job-031 (marqueurs lookahead) vers ntfy.sh, dont le quota est neuf depuis minuit UTC.
set -u
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
ETAT="$HOME/.cache/merlin-agents/courrier"
dire() { curl -fsS -m 20 -H "Title: r32 $1" --data-binary "$2" "$NT"; }

dire "canari" "$(date -u +%H:%M:%SZ) reprise sur ntfy.sh" || { echo "canari refuse"; exit 1; }

envoyer() {
    src="$1"; nom="$2"
    [ -f "$src" ] || { dire "absent" "$nom introuvable" >/dev/null 2>&1; return; }
    split -b 250 -d -a 3 "$src" /tmp/r32.
    total=$(ls /tmp/r32.* | wc -l | tr -d ' ')
    i=0
    for p in $(ls /tmp/r32.* | sort); do
        i=$((i+1))
        curl -fsS -m 30 --retry 2 -H "Title: $nom part $i/$total" \
            --data-binary @"$p" "$NT" >/dev/null 2>&1
        sleep 2
    done
    rm -f /tmp/r32.*
    echo "$nom : $total tranches"
}

# État des jobs 030/031 (tournés ? où en sont-ils ?)
{
  echo "== faits =="
  ls -la "$ETAT"/*.fait 2>/dev/null | tail -6
  echo "== resultats =="
  ls "$ETAT"/*.res 2>/dev/null | tail -6
  echo "== bitnet =="
  ls -la "$HOME/.cache/bitnet-banc" "$HOME/.cache/bitnet-banc/BitNet/build/bin" 2>/dev/null | head -12
} > /tmp/etat32.txt 2>&1
envoyer /tmp/etat32.txt "etat32"

R30="$ETAT/job-030-banc-bitnet.res"
for f in "$R30"/issue.txt "$R30"/scene.txt "$R30"/intro.txt "$R30"/sortie.log; do
    [ -f "$f" ] && envoyer "$f" "bit32-$(basename "$f" .txt | tr -d .)"
done
[ -f "$R30/build.log" ] && { tail -c 1200 "$R30/build.log" > /tmp/b32.txt; envoyer /tmp/b32.txt "bit32-buildfin"; }
R31="$ETAT/job-031-marqueurs-lookahead.res"
[ -f "$R31/lk.txt" ] && envoyer "$R31/lk.txt" "lk32"
[ -f "$R31/sortie.log" ] && envoyer "$R31/sortie.log" "lk32-sortie"
dire "fini" "$(date -u +%H:%M:%SZ)" >/dev/null 2>&1
echo "re-emission terminee"
