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

# GAME_DIR = le projet effectivement lancé. Repli sur l'outillage tant que le
# dépôt du jeu n'est pas cloné (rétrocompatibilité avec l'installation d'origine).
if [ -f "$GAME_REPO_DIR/project.godot" ]; then
    GAME_DIR="$GAME_REPO_DIR"
else
    GAME_DIR="$TOOLS_REPO"
fi
