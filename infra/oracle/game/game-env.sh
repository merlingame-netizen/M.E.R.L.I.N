#!/usr/bin/env bash
# Configuration commune des scripts « jeu natif » — À SOURCER, pas à exécuter.
#
# Deux dossiers DISTINCTS sur la VM (choix validé) :
#   TOOLS_REPO — l'outillage : portail Studio + scripts VNC/provisioning (ce dépôt)
#   GAME_DIR   — le PROJET GODOT réellement joué (dépôt/branche du jeu)
# Séparés parce que la branche du jeu ne contient pas infra/oracle/game : mélanger
# les deux casserait l'outillage à chaque changement de branche du jeu.
#
# Réglages dans ~/.config/merlin-game.env (facultatifs, valeurs par défaut ici) :
#   GAME_REPO_URL=https://github.com/owner/repo.git   (défaut : origin de TOOLS_REPO)
#   GAME_REF=feat/practices-docs                      (branche portant le vrai jeu)
#   GAME_REPO_DIR=$HOME/workspace/merlin-game         (où le jeu est cloné)

TOOLS_REPO="${MERLIN_REPO:-$HOME/workspace/M.E.R.L.I.N}"

_MERLIN_GAME_CONF="$HOME/.config/merlin-game.env"
[ -f "$_MERLIN_GAME_CONF" ] && . "$_MERLIN_GAME_CONF"

GAME_REPO_DIR="${GAME_REPO_DIR:-$HOME/workspace/merlin-game}"
GAME_REF="${GAME_REF:-feat/practices-docs}"
if [ -z "${GAME_REPO_URL:-}" ]; then
    GAME_REPO_URL="$(git -C "$TOOLS_REPO" remote get-url origin 2>/dev/null || echo '')"
fi

# LE HARNAIS VIVANT. game-stack écrit $RUNDIR/harness au lancement d'une sonde et l'efface à
# l'arrêt — mais un arrêt qui ne passe pas par game-stack (bouton Stop du Studio qui tue le
# groupe, reboot, kill) laisse le fichier plein pour toujours : chaque agent qui le lit renonce
# alors chaque nuit, sans fin (relecture du 06/09). Ici, un harnais ne compte que si un jeu VIT
# (inner.pid vivant, ou un godot) ; sinon le fichier est vidé, et on le dit sur stderr.
merlin_harnais() {
    local d="$HOME/.cache/merlin-game" h pid
    h="$(cat "$d/harness" 2>/dev/null || true)"
    [ -n "$h" ] || return 0
    pid="$(cat "$d/inner.pid" 2>/dev/null || true)"
    if { [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; } \
       || pgrep -x godot >/dev/null 2>&1 || pgrep -f 'bin/godot' >/dev/null 2>&1; then
        printf '%s' "$h"
        return 0
    fi
    : > "$d/harness" 2>/dev/null || true
    echo "harnais rassis « $h » effacé : aucun jeu vivant" >&2
}

# GAME_DIR = le projet effectivement lancé. Repli sur l'outillage tant que le
# dépôt du jeu n'est pas cloné (rétrocompatibilité avec l'installation d'origine).
if [ -f "$GAME_REPO_DIR/project.godot" ]; then
    GAME_DIR="$GAME_REPO_DIR"
else
    GAME_DIR="$TOOLS_REPO"
fi
