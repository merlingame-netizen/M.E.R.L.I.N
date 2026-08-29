#!/usr/bin/env bash
# cmd-025 (pont OCI) — LE COURRIER EST A L'ARRET : on le relance.
#
# cmd-024 : « agent courrier : inactive ». job-079 attendra donc indefiniment. On tire les depots,
# on dit l'etat reel des unites, et on lance UN tour de Courrier en tache de fond.
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

# L'awk de cmd-024 etait casse par un sur-echappement a travers le pont : on lit /proc a la main.
MEM=$(sed -n 's/^MemAvailable:[[:space:]]*\([0-9]*\).*/\1/p' /proc/meminfo)
echo "C memoire dispo : $(( ${MEM:-0} / 1024 )) Mo"
echo "C godot en vol  : $(pgrep -c godot 2>/dev/null || echo 0) processus"

# Quelles unites existent VRAIMENT ? cmd-024 en interrogeait une qui n'existe peut-etre pas.
echo "D unites systemd --user portant 'merlin' :"
systemctl --user list-units --all --no-legend --no-pager 2>/dev/null | grep -i merlin | head -8 | sed 's/^/D   /'
systemctl --user list-timers --all --no-legend --no-pager 2>/dev/null | grep -i merlin | head -4 | sed 's/^/D   timer /'
echo "D crontab : $(crontab -l 2>/dev/null | grep -ci courrier || echo 0) ligne(s) courrier"

echo "E en attente : $(cd "$BOITE" 2>/dev/null && for f in job-*.sh; do [ -f "$ETAT/${f%.sh}.fait" ] || echo "${f%.sh}"; done | tr '\n' ' ' | head -c 200)"
echo "E job-079 present=$([ -f "$BOITE/job-079-quete-generee-diagnostic.sh" ] && echo oui || echo NON)"
echo "E diagnostic dans le generateur=$(grep -c '_erreurs_moteur' "$GD/tools/generer_quete.gd" 2>/dev/null || echo 0)"

# UN TOUR DE COURRIER, en tache de fond : il prend un job et rend la main tout de suite.
# setsid + nohup pour qu'il survive a la fin de cette commande, qui ne dure que quelques secondes.
if [ -x "$RP/infra/oracle/agents/a_courrier.sh" ] || [ -f "$RP/infra/oracle/agents/a_courrier.sh" ]; then
  setsid nohup env -u RES bash "$RP/infra/oracle/agents/a_courrier.sh" \
    > "$HOME/.cache/courrier-relance.log" 2>&1 &
  echo "F un tour de Courrier lance en tache de fond (pid $!)"
else
  echo "F a_courrier.sh INTROUVABLE dans $RP/infra/oracle/agents/"
fi
echo "Z fin cmd-025"
