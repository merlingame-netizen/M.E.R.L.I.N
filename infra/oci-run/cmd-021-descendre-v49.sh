#!/usr/bin/env bash
# cmd-021 (pont OCI) — FAIRE DESCENDRE v49 ET LAISSER job-073 JOUER.
#
# v49 (le fil concret) est sur feat/practices-docs. Cote outillage : job-073, qui exige les NEUF
# marqueurs, et un verdict enrichi d'une ligne CONTINUITE qui compte les enchainements portant le
# fil du beat precedent. La ligne de base est connue : 0 sur 5 a la derniere partie.
#
# On tire en direct — jamais via les agents, cmd-014 en est mort sans une ligne pour avoir appele
# a_tools_autosync.sh et son pkill.
set -u
echo "A depart $(date -u +%H:%M:%SZ)"
RP="${REPO:-/var/lib/ocarun/workspace/M.E.R.L.I.N}"
GD="${GAME_DIR:-/var/lib/ocarun/workspace/merlin-game}"
[ -d "$RP" ] || RP="$HOME/workspace/M.E.R.L.I.N"
[ -d "$GD" ] || GD="$HOME/workspace/merlin-game"
ETAT="$HOME/.cache/merlin-agents/courrier"

for d in "$RP" "$GD"; do
  git -C "$d" config core.fileMode false 2>/dev/null
  av=$(git -C "$d" rev-parse --short HEAD 2>/dev/null || echo '?')
  git -C "$d" pull --ff-only >/dev/null 2>&1
  echo "B $(basename "$d") $av -> $(git -C "$d" rev-parse --short HEAD 2>/dev/null || echo '?')"
done

A=0; B1=0; C=0; D=0; E=0; F=0; G=0; H=0; I=0
grep -q "MERLIN_BOT_COUVRANT" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && A=1
grep -q "LE GESTE T'EST DONNE EN FIN DE PROMPT" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && B1=1
grep -q '"annulee"' "$GD/scripts/llm/merlin_native.gd" 2>/dev/null && C=1
grep -q "_meilleure_greffe" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && D=1
grep -q "montre que ces bois REJOUENT" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && E=1
grep -q "prompt_chars" "$GD/scripts/llm/merlin_native.gd" 2>/dev/null && F=1
grep -q "MERLIN_BOT_COUVRANT" "$RP/infra/oracle/game/game-stack.sh" 2>/dev/null && G=1
grep -q "_extraire_fil" "$GD/scripts/llm/merlin_scenario.gd" 2>/dev/null && H=1
grep -q "CE QUI ATTENDAIT LE VOYAGEUR" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && I=1
echo "C garde073 sonde=$A place=$B1 annul=$C draft=$D boucle=$E chars=$F env=$G fil=$H queue=$I"
echo "C (111111111 = elle peut jouer) fantome_systeme=$(grep -c 'vieil homme sort de sa hutte' "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null)"
echo "D job073=$([ -f "$RP/infra/oracle/agents/courrier/job-073-partie-v49-continuite.sh" ] && echo present || echo ABSENT) fait=$([ -f "$ETAT/job-073-partie-v49-continuite.fait" ] && echo pose || echo non)"
echo "D en_attente=$(cd "$RP/infra/oracle/agents/courrier" 2>/dev/null && for f in job-*.sh; do [ -f "$ETAT/${f%.sh}.fait" ] || echo "${f%.sh}"; done | tr '\n' ' ' | head -c 120)"
echo "D godot=$(pgrep -f 'godot.*probe_partie' >/dev/null 2>&1 && echo TOURNE || echo non) mem=$(awk '/MemAvailable/ {printf "%.1f", $2/1048576}' /proc/meminfo)Go"
echo "Z fin cmd-021"
