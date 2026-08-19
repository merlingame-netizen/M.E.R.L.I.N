#!/usr/bin/env bash
# Rapatrie la partie 6 beats du 2026-08-19 matin (journal + sélection + clichés),
# le labo bi-cerveaux, et un état de santé — tout ce que la perte de Run Command
# a laissé bloqué sur la VM.
set -u
B="$HOME/.cache/merlin-partie"
cp -f "$B/journal.json" "$RES/journal6.json" 2>/dev/null || echo "journal absent"
cp -f "$B/selection.json" "$RES/selection6.json" 2>/dev/null || echo "selection absente"
mkdir -p "$RES/cliches"
cp -f "$B"/cliches/*.png "$RES/cliches/" 2>/dev/null || echo "cliches absents"
cp -f "$HOME/.cache/merlin-agents/labo-recit-e4b.json" "$RES/labo-bi.json" 2>/dev/null || true
{ echo "== date =="; date -u
  echo "== git jeu =="; git -C "${GAME_DIR:-$HOME/workspace/merlin-game}" rev-parse --short HEAD 2>/dev/null
  echo "== git outillage =="; git -C "${REPO:-$HOME/workspace/M.E.R.L.I.N}" rev-parse --short HEAD 2>/dev/null
  echo "== free =="; free -m | head -2
  echo "== contenu partie =="; ls -la "$B" "$B/cliches" 2>/dev/null
} > "$RES/etat.txt" 2>&1
echo "rapatriement terminé"
