#!/usr/bin/env bash
# cmd-016 (pont OCI) — QU'A FAIT job-069, AU JUSTE ?
#
# cmd-015 a montre `job069 fait=oui` : le marqueur est pose AVANT l'execution (a_courrier.sh:36-43),
# donc le job est parti — mais possiblement AVANT que v48.1d et le correctif d'environnement
# n'atteignent la VM. Dans ce cas il aura joue une partie avec le bot couvrant INERTE, et son
# verdict ne vaut rien.
#
# On ne devine pas : on regarde. Une partie tourne-t-elle encore ? Le log dit-il « COUVRANT » ou
# « cyclage » ? Un verdict a-t-il ete ecrit, et lequel ?
#
# Aucune mutation d'etat : on n'efface aucun marqueur, on ne relance rien. job-070 est deja
# pousse pour la vraie mesure, avec une garde a cinq marqueurs.
set -u
echo "A depart $(date -u +%H:%M:%SZ)"
RP="${REPO:-/var/lib/ocarun/workspace/M.E.R.L.I.N}"
[ -d "$RP" ] || RP="$HOME/workspace/M.E.R.L.I.N"
ETAT="$HOME/.cache/merlin-agents/courrier"
RES="$HOME/.cache/merlin-agents/courrier-res"
[ -d "$RES" ] || RES=$(ls -1td "$HOME"/.cache/merlin-agents/*res* 2>/dev/null | head -1)

echo "A godot=$(pgrep -f 'godot.*probe_partie_journal' >/dev/null 2>&1 && echo TOURNE || echo non) mem=$(awk '/MemAvailable/ {printf "%.1f", $2/1048576}' /proc/meminfo)Go"
echo "A marqueur069=$(cat "$ETAT/job-069-partie-v48-1.fait" 2>/dev/null | head -c 24) marqueur070=$([ -f "$ETAT/job-070-partie-v48-1-complet.fait" ] && echo pose || echo non)"

# le dossier de resultats du job : on cherche partie.log ou qu'il soit
LOG=$(ls -1t "$RES"/*/partie.log "$RES"/partie.log 2>/dev/null | head -1)
echo "B log=${LOG:-ABSENT}"
if [ -n "${LOG:-}" ]; then
  echo "B mode=$(grep -a 'choix des cartes' "$LOG" 2>/dev/null | tail -1 | head -c 90)"
  echo "B beats=$(grep -ac '\[JOURNAL\] beat' "$LOG" 2>/dev/null) fin=$(grep -a '\[JOURNAL\] termine' "$LOG" 2>/dev/null | head -c 90)"
  echo "B derniere=$(tail -c 160 "$LOG" 2>/dev/null | tr '\n' ' ')"
fi
V=$(ls -1t "$RES"/*/verdict69.txt "$RES"/verdict69.txt 2>/dev/null | head -1)
[ -n "${V:-}" ] && { echo "C verdict69 :"; head -c 600 "$V"; echo; } || echo "C verdict69 ABSENT"
echo "Z fin cmd-016"
