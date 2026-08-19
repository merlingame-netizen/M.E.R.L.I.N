#!/usr/bin/env bash
# Ré-expédie la récolte de job-001 : sa version du courrier n'avait que le retour
# git (mort-né — la VM ne pousse pas) ; celle-ci passe par la liaison ntfy.
# La copie de sûreté de job-001 vit dans ~/.cache/merlin-agents/courrier/.
set -u
SRC="$HOME/.cache/merlin-agents/courrier/job-001-rapatrier-partie6.res"
if [ -d "$SRC" ]; then
    cp -rf "$SRC/." "$RES/"
    echo "récolte de job-001 rechargée ($(find "$RES" -type f | wc -l) fichiers)"
else
    # job-001 n'a pas encore tourné (ou copie absente) : on refait la récolte.
    B="$HOME/.cache/merlin-partie"
    cp -f "$B/journal.json" "$RES/journal6.json" 2>/dev/null || echo "journal absent"
    cp -f "$B/selection.json" "$RES/selection6.json" 2>/dev/null || echo "selection absente"
    mkdir -p "$RES/cliches"
    cp -f "$B"/cliches/*.png "$RES/cliches/" 2>/dev/null || echo "cliches absents"
    cp -f "$HOME/.cache/merlin-agents/labo-recit-e4b.json" "$RES/labo-bi.json" 2>/dev/null || true
fi
{ echo "== date =="; date -u
  echo "== git outillage =="; git -C "${REPO:-$HOME/workspace/M.E.R.L.I.N}" rev-parse --short HEAD 2>/dev/null
  echo "== cron.log courrier (fin) =="; grep -a "courrier" "$HOME/.cache/merlin-agents/cron.log" 2>/dev/null | tail -8
} > "$RES/etat2.txt" 2>&1
echo "ré-expédition prête"
