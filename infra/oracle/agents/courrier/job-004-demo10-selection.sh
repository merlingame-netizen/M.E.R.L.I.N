#!/usr/bin/env bash
# Démo 10 beats — phase 1 : la sélection, sur le jeu patché v31.1 (40cb5188).
# On ATTEND que le clone du jeu porte le patch (webhook ou autosync) ; passé 10 min,
# on force un game-autosync nous-même. Puis la sélection, et selection.json en .bin.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
CIBLE="40cb5188cddc802c99752fc70d68f9f8b4706276"

deadline=$(( $(date +%s) + 1500 ))
force_fait=0
while ! git -C "$GD" merge-base --is-ancestor "$CIBLE" HEAD 2>/dev/null; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
        echo "jeu jamais a jour ($(git -C "$GD" rev-parse --short HEAD 2>/dev/null)) — abandon"
        exit 1
    fi
    if [ "$force_fait" -eq 0 ] && [ "$(date +%s)" -ge $(( deadline - 900 )) ]; then
        echo "10 min sans patch — game-autosync force"
        bash "$AGENTS/a_game_autosync.sh" >> "$RES/autosync.log" 2>&1 || true
        force_fait=1
    fi
    sleep 20
done
echo "jeu sur $(git -C "$GD" rev-parse --short HEAD)"

bash "$AGENTS/a_partie_journal.sh" selection > "$RES/selection_run.log" 2>&1
RCS=$?
echo "selection rc=$RCS"
cp -f "$HOME/.cache/merlin-partie/selection.json" "$RES/selection10.bin" 2>/dev/null \
    || { echo "selection.json ABSENT"; tail -c 3000 "$HOME/.cache/merlin-game/godot.log" > "$RES/godot_queue.txt" 2>/dev/null; }
tail -c 2000 "$RES/selection_run.log" > "$RES/selection_run_queue.txt" 2>/dev/null || true
exit $RCS
