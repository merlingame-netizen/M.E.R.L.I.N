#!/usr/bin/env bash
# cmd-024 (pont OCI) — OU EN EST LA GENERATION ?
#
# Trois jobs de generation ont echoue et le quatrieme n'a pas demarre trente minutes apres avoir
# ete pousse. On demande plutot que d'attendre : le depot a-t-il tire le job, la file est-elle
# saine, et un Godot traine-t-il en vol ?
set -u
echo "A depart $(date -u +%H:%M:%SZ)"
RP="${REPO:-/var/lib/ocarun/workspace/M.E.R.L.I.N}"
GD="${GAME_DIR:-/var/lib/ocarun/workspace/merlin-game}"
[ -d "$RP" ] || RP="$HOME/workspace/M.E.R.L.I.N"
[ -d "$GD" ] || GD="$HOME/workspace/merlin-game"
ETAT="$HOME/.cache/merlin-agents/courrier"
BOITE="$RP/infra/oracle/agents/courrier"

for d in "$RP" "$GD"; do
  git -C "$d" config core.fileMode false 2>/dev/null
  av=$(git -C "$d" rev-parse --short HEAD 2>/dev/null || echo '?')
  git -C "$d" pull --ff-only >/dev/null 2>&1
  echo "B $(basename "$d") $av -> $(git -C "$d" rev-parse --short HEAD 2>/dev/null || echo '?')"
done

echo "C job-078 present=$([ -f "$BOITE/job-078-quete-generee.sh" ] && echo oui || echo NON) fait=$([ -f "$ETAT/job-078-quete-generee.fait" ] && echo pose || echo non)"
echo "C en attente : $(cd "$BOITE" 2>/dev/null && for f in job-*.sh; do [ -f "$ETAT/${f%.sh}.fait" ] || echo "${f%.sh}"; done | tr '\n' ' ' | head -c 200)"

echo "D correctifs de rig : listeblanche=$(grep -c 'MERLIN_CHAPITRE=' "$RP/infra/oracle/game/game-stack.sh" 2>/dev/null) gardefou=$(grep -c "n'est pas une resolution" "$RP/infra/oracle/game/game-stack.sh" 2>/dev/null)"
echo "D outils du jeu : generateur=$([ -f "$GD/tools/generer_quete.gd" ] && echo oui || echo NON) contrat=$([ -f "$GD/tools/scenarios/valider.py" ] && echo oui || echo NON)"

echo "E godot en vol : $(pgrep -af 'godot' 2>/dev/null | head -2 | cut -c1-110 | tr '\n' '|')"
echo "E memoire dispo : $(awk '/MemAvailable/ {printf \"%.1f\", $2/1048576}' /proc/meminfo)Go"
echo "E agent courrier : $(systemctl --user is-active merlin-courrier.timer 2>/dev/null || echo '?') / $(systemctl --user is-active merlin-courrier.service 2>/dev/null || echo '?')"
echo "E derniere sortie de job : $(ls -t "$BOITE/resultats"/*/sortie.log 2>/dev/null | head -1 | xargs -r tail -3 | tr '\n' ' ' | head -c 220)"
echo "Z fin cmd-024"
