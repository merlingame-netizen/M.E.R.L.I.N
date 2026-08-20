#!/usr/bin/env bash
# Rapport p42 par TUYAU (ppng.io) — le canal ntfy est noir depuis 12:24 (pas même un ko
# de job-042, et job-043 muet à son tour) : suspicion de blocage/quota côté IP de la VM
# sur les trois instances. Le tuyau inverse la charge : le poste de pilotage TIENT un
# GET ouvert, la VM pousse UN payload unique — la remise est confirmée par le rc du POST.
# Même politique que le sujet ntfy : chemin non devinable, résultats de jeu uniquement.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
B="$HOME/.cache/merlin-partie"
ETAT="$HOME/.cache/merlin-agents/courrier"
J42="job-042-partie6-scene-au-resolve"
PIPE="https://ppng.io/merlin-p42-vX9k2Qf7Lw3s-r1"

PAY="$COURRIER_RES/payload.txt"
{
    echo "== p42 rapport tuyau $(date -u +%Y-%m-%dT%H:%M:%SZ) =="
    echo "sha_jeu=$(git -C "$GD" rev-parse --short HEAD 2>/dev/null || echo '?')"
    echo "v35.4_deploye=$(grep -q 'v35.4' "$GD/scripts/game/merlin_game.gd" 2>/dev/null && echo oui || echo non)"
    echo "godot_vivant=$( (pgrep -x godot >/dev/null || pgrep -f 'bin/godot' >/dev/null) && echo oui || echo non)"
    echo "mem_dispo_ko=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)"
    echo "-- marqueurs .fait recents --"
    ls -lt "$ETAT"/*.fait 2>/dev/null | head -6
    for j in "$J42" job-043-rapport-p42; do
        for f in sortie.log partie.log sel1.log sel2.log; do
            p="$AGENTS/courrier/resultats/$j/$f"
            if [ -f "$p" ]; then
                echo "-- $j/$f (2000 derniers octets) --"
                tail -c 2000 "$p"
                echo
            fi
        done
    done
    if [ -f "$B/journal.json" ]; then
        echo "-- journal.json (mtime $(date -u -r "$B/journal.json" +%H:%M:%SZ)) --"
        cat "$B/journal.json"
    else
        echo "-- journal.json ABSENT --"
    fi
} > "$PAY" 2>&1

# ntfy d'abord (une seule, pas cher) au cas où le canal serait revenu
curl -fsS -m 15 -H "Title: p42p signal" -d "payload pret ($(wc -c < "$PAY") o) — tuyau en cours" \
    "https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1 || true

# Le tuyau : jusqu'à 10 essais espacés de 2 min (le POST ne réussit que si le poste
# de pilotage tient son GET — rc=0 vaut REMISE confirmée).
ok=non
for i in 1 2 3 4 5 6 7 8 9 10; do
    if curl -fsS -m 120 -X POST --data-binary @"$PAY" "$PIPE" >/dev/null 2>&1; then
        ok=oui
        break
    fi
    sleep 120
done
echo "remise_tuyau=$ok taille=$(wc -c < "$PAY")"
[ "$ok" = "oui" ]
