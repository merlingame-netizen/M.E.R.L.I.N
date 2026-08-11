#!/usr/bin/env bash
# Codeur résident : consomme la file de missions (~/.cache/merlin-missions/queue)
# avec Claude Code headless dans le clone du jeu, et committe sur auto/coder.
# GARDE-FOUS : jamais de push sur la branche du jeu ; une mission à la fois
# (verrou d'agent-run) ; tours plafonnés ; journal complet par mission.
# Prérequis (une fois) : ANTHROPIC_API_KEY=... dans ~/.config/merlin-coder.env (0600).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

QUEUE="$HOME/.cache/merlin-missions/queue"
DONE="$HOME/.cache/merlin-missions/done"
LOGS="$HOME/.cache/merlin-missions/logs"
CONF="$HOME/.config/merlin-coder.env"
BRANCH="auto/coder"
mkdir -p "$QUEUE" "$DONE" "$LOGS"

# ── prérequis ────────────────────────────────────────────────────────────────
[ -f "$CONF" ] || { echo "clé API absente — écrire ANTHROPIC_API_KEY=... dans $CONF (chmod 600)"; exit 0; }
. "$CONF"
[ -n "${ANTHROPIC_API_KEY:-}" ] || { echo "ANTHROPIC_API_KEY vide dans $CONF"; exit 0; }
export ANTHROPIC_API_KEY

if ! command -v claude >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/claude" ]; then
    command -v npm >/dev/null 2>&1 || { echo "npm absent — installer node d'abord (voir README)"; exit 1; }
    echo "installation de Claude Code (une fois)…" >&2
    npm install -g --prefix "$HOME/.local" @anthropic-ai/claude-code >&2 \
        || { echo "installation de Claude Code KO"; exit 1; }
fi
export PATH="$HOME/.local/bin:$PATH"

# ── mission suivante (la plus ancienne) ─────────────────────────────────────
MISSION="$(ls -1tr "$QUEUE" 2>/dev/null | head -1)"
[ -n "$MISSION" ] || { echo "file vide — aucune mission"; exit 0; }
TEXT="$(cat "$QUEUE/$MISSION")"
MID="$(date -u +%Y%m%d-%H%M%S)-${MISSION%.md}"

# ── espace de travail : branche dédiée, jamais la branche du jeu ────────────
cd "$GAME_DIR" || { echo "clone du jeu introuvable"; exit 1; }
git fetch origin "$GAME_REF" --quiet
git checkout -B "$BRANCH" "origin/$GAME_REF" >&2 2>&1

PROMPT="Tu travailles dans le projet Godot MERLIN (branche $BRANCH, basée sur $GAME_REF).
MISSION : $TEXT
Règles : modifie uniquement ce qui sert la mission ; valide la syntaxe de ce que
tu touches ; termine par un résumé d'une ligne de ce qui a été fait."

timeout 1800 claude -p "$PROMPT" \
    --permission-mode acceptEdits --max-turns 40 \
    > "$LOGS/$MID.log" 2>&1
RC=$?

if ! git diff --quiet || ! git diff --cached --quiet; then
    git add -A
    git commit -q -m "auto(coder): $MISSION

Mission exécutée par l'agent codeur résident (journal: $MID).
Base: $GAME_REF" && git push -q -u origin "$BRANCH" >&2 2>&1
    PUSHED=oui
else
    PUSHED=non
fi
# retour sur la branche du jeu (le lanceur de jeu lit ce clone !)
git checkout "$GAME_REF" >&2 2>&1

mv "$QUEUE/$MISSION" "$DONE/$MID.md"
echo "mission '$MISSION' : rc=$RC · commit poussé sur $BRANCH: $PUSHED · journal $MID"
[ "$RC" -eq 0 ]
