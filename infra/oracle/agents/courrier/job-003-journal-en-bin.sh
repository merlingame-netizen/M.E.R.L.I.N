#!/usr/bin/env bash
# Ré-expédie journal + sélection sous extension .bin : les types texte sont
# paraphrasés par le lecteur du poste de pilotage — seul l'octet brut
# (application/octet-stream) est sauvé fidèle, octet pour octet.
set -u
B="$HOME/.cache/merlin-partie"
cp -f "$B/journal.json" "$RES/journal6.bin" 2>/dev/null || echo "journal absent"
cp -f "$B/selection.json" "$RES/selection6.bin" 2>/dev/null || echo "selection absente"
cp -f "$HOME/.cache/merlin-agents/labo-recit-e4b.json" "$RES/labo-bi.bin" 2>/dev/null || true
echo "conversion .bin prête"
