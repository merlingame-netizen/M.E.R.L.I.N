#!/usr/bin/env bash
# Trois démarrages refusés en 0-1 s, godot.log jamais touché : signature de
# require_import (.godot/imported vide) — l'import du commit 40cb5188 a dû échouer
# ou être interrompu. Constat chiffré, re-import si nécessaire, puis sélection.
set -u
OUTIL="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
AGENTS="$OUTIL/infra/oracle/agents"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
SEL="$HOME/.cache/merlin-partie/selection.json"
dire() { curl -fsS -m 20 -H "Title: diag7 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }

NIMP=$(find "$GD/.godot/imported" -type f 2>/dev/null | wc -l | tr -d ' ')
dire "etat" "$(date -u +%H:%M:%SZ) imported=$NIMP sha=$(git -C "$GD" rev-parse --short HEAD 2>/dev/null)"
dire "ci-queue" "$(tail -c 650 "$HOME/.cache/merlin-agents/logs/ci-commit.log" 2>/dev/null | tr '\n' ' ')"

if [ "$NIMP" = "0" ]; then
    dire "reimport" "lancement de game-sync"
    bash "$OUTIL/infra/oracle/game/game-sync.sh" > "$RES/gamesync.log" 2>&1
    RCI=$?
    dire "reimport-fin" "rc=$RCI imported=$(find "$GD/.godot/imported" -type f 2>/dev/null | wc -l) : $(tail -c 500 "$RES/gamesync.log" | tr '\n' ' ')"
fi

bash "$AGENTS/a_partie_journal.sh" selection > "$RES/selection_run.log" 2>&1
RCS=$?
if [ -s "$SEL" ]; then
    split -b 3000 -d -a 2 "$SEL" /tmp/sl.
    total=$(ls /tmp/sl.* | wc -l | tr -d ' ')
    i=0
    for p in $(ls /tmp/sl.* | sort); do
        i=$((i+1))
        curl -fsS -m 30 --retry 2 -H "Title: selection10 part $i/$total" \
            --data-binary @"$p" "$NT" >/dev/null 2>&1
        sleep 2
    done
    rm -f /tmp/sl.*
    echo "selection OK ($total tranches)"
else
    dire "selection-ko" "rc=$RCS : $(head -c 600 "$RES/selection_run.log" | tr '\n' ' ')"
    echo "selection encore absente (rc=$RCS)"
    exit 1
fi
