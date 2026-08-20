#!/usr/bin/env bash
# Rendez-vous LONG (3 h) — la VM est muette depuis 12:24 : quand l'automatisation
# revit, ce job doit trouver le poste de pilotage même s'il n'écoute pas à la minute.
# POST tuyau tenu 120 s puis pause 60 s pendant 3 h ; une ligne ntfy toutes les 15 min
# au cas où ce canal serait revenu. Résultats de jeu uniquement, chemins non devinables.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
B="$HOME/.cache/merlin-partie"
ETAT="$HOME/.cache/merlin-agents/courrier"
PIPE="https://ppng.io/merlin-p42-vX9k2Qf7Lw3s-r1"
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"

PAY="$COURRIER_RES/payload.txt"
{
    echo "== p42 rendez-vous $(date -u +%Y-%m-%dT%H:%M:%SZ) =="
    echo "sha_jeu=$(git -C "$GD" rev-parse --short HEAD 2>/dev/null || echo '?')"
    echo "sha_outillage=$(git -C "${REPO:-$HOME/workspace/M.E.R.L.I.N}" rev-parse --short HEAD 2>/dev/null || echo '?')"
    echo "v35.4_deploye=$(grep -q 'v35.4' "$GD/scripts/game/merlin_game.gd" 2>/dev/null && echo oui || echo non)"
    echo "godot_vivant=$( (pgrep -x godot >/dev/null || pgrep -f 'bin/godot' >/dev/null) && echo oui || echo non)"
    echo "mem_dispo_ko=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)"
    echo "uptime=$(uptime 2>/dev/null)"
    echo "-- marqueurs .fait recents --"
    ls -lt "$ETAT"/*.fait 2>/dev/null | head -8
    for j in job-042-partie6-scene-au-resolve job-043-rapport-p42 job-044-rapport-p42-pipe; do
        for f in sortie.log partie.log sel1.log sel2.log; do
            p="$AGENTS/courrier/resultats/$j/$f"
            if [ -f "$p" ]; then
                echo "-- $j/$f (1500 derniers octets) --"
                tail -c 1500 "$p"
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

fin=$(( $(date +%s) + 10800 ))
dernier_ntfy=0
ok=non
while [ "$(date +%s)" -lt "$fin" ]; do
    if curl -fsS -m 120 -X POST --data-binary @"$PAY" "$PIPE" >/dev/null 2>&1; then
        ok=oui
        break
    fi
    now=$(date +%s)
    if [ $(( now - dernier_ntfy )) -ge 900 ]; then
        dernier_ntfy=$now
        curl -fsS -m 15 -H "Title: p45 vivant" \
            -d "$(head -c 220 "$PAY" | tr '\n' ' ')" "$NT" >/dev/null 2>&1 || true
    fi
    sleep 60
done
echo "remise_tuyau=$ok taille=$(wc -c < "$PAY")"
[ "$ok" = "oui" ]
