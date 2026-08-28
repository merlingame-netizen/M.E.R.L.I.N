#!/usr/bin/env bash
# cmd-022 (pont OCI) — FAIRE DESCENDRE v50 ET ARMER LA QUETE COMPLETE.
#
# On tire en direct, jamais via les agents : a_tools_autosync.sh porte un pkill qui a deja tue une
# Run Command sans laisser une seule ligne de sortie (cmd-014).
#
# Puis on verifie les ONZE marqueurs de la garde de job-074, dont les deux nouveaux : v49.1
# (l'instantane des mecaniques pris a temps, sans quoi le journal ne peut pas prouver ses
# reussites) et v50 (les captures etalees, sans quoi une quete de vingt beats ne rend que trois
# images).
#
# Et on verifie que RIEN ne force la longueur : c'est la premiere partie sans MERLIN_BEATS.
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

A=0; B1=0; C=0; D=0; E=0; F=0; G=0; H=0; I=0; J=0; K=0
grep -q "MERLIN_BOT_COUVRANT" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && A=1
grep -q "LE GESTE T'EST DONNE EN FIN DE PROMPT" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && B1=1
grep -q '"annulee"' "$GD/scripts/llm/merlin_native.gd" 2>/dev/null && C=1
grep -q "_meilleure_greffe" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && D=1
grep -q "montre que ces bois REJOUENT" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && E=1
grep -q "prompt_chars" "$GD/scripts/llm/merlin_native.gd" 2>/dev/null && F=1
grep -q "MERLIN_BOT_COUVRANT" "$RP/infra/oracle/game/game-stack.sh" 2>/dev/null && G=1
grep -q "_extraire_fil" "$GD/scripts/llm/merlin_scenario.gd" 2>/dev/null && H=1
grep -q "CE QUI ATTENDAIT LE VOYAGEUR" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && I=1
grep -q "L'INSTANTANE DES MECANIQUES, TOUT EN HAUT" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && J=1
grep -q "DES CLICHES ETALES SUR TOUTE LA QUETE" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && K=1
echo "C garde074 sonde=$A place=$B1 annul=$C draft=$D boucle=$E chars=$F env=$G fil=$H queue=$I meca=$J cliches=$K"
echo "C (11111111111 = elle peut jouer)"

# La longueur : ce que le jeu tirera, et la preuve que rien ne la force.
echo "D longueur=$(grep -oP 'QUETE_BEATS_MIN: int = \\K[0-9]+' "$GD/scripts/llm/merlin_scenario.gd" 2>/dev/null)-$(grep -oP 'QUETE_BEATS_MAX: int = \\K[0-9]+' "$GD/scripts/llm/merlin_scenario.gd" 2>/dev/null) beats"
echo "D job074_force_la_longueur=$(grep -c 'MERLIN_BEATS' "$RP/infra/oracle/agents/courrier/job-074-quete-complete.sh" 2>/dev/null) (0 = libre)"
echo "D deadline_sonde=$(grep -oP 'RUN_DEADLINE_S: float = \\K[0-9.]+' "$GD/tools/probe_partie_journal.gd" 2>/dev/null)s"

echo "E job074=$([ -f "$RP/infra/oracle/agents/courrier/job-074-quete-complete.sh" ] && echo present || echo ABSENT) fait=$([ -f "$ETAT/job-074-quete-complete.fait" ] && echo pose || echo non)"
echo "E en_attente=$(cd "$RP/infra/oracle/agents/courrier" 2>/dev/null && for f in job-*.sh; do [ -f "$ETAT/${f%.sh}.fait" ] || echo "${f%.sh}"; done | tr '\n' ' ' | head -c 120)"
echo "E godot=$(pgrep -f 'godot.*probe_partie' >/dev/null 2>&1 && echo TOURNE || echo non) mem=$(awk '/MemAvailable/ {printf "%.1f", $2/1048576}' /proc/meminfo)Go"
echo "Z fin cmd-022"
