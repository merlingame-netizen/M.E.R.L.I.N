#!/usr/bin/env bash
# cmd-017 (pont OCI) — ARMER job-070.
#
# Les CINQ marqueurs de v48.1 sont sur feat/practices-docs (091d5e02). On fait descendre les deux
# depots en direct — jamais via les agents, cmd-014 est mort sans une ligne pour avoir appele
# a_tools_autosync.sh et son pkill — puis on verifie que la garde a cinq marqueurs de job-070 est
# desormais satisfaite.
#
# On regarde aussi si job-069 bloque encore le Courrier : son marqueur date de 14:38, sa date
# limite interne etait 45 min plus tard, et un job qui boucle dans un tick empeche tous les
# suivants de partir. Sans cela job-070 n'aurait aucune chance de jouer.
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

A=0; B=0; C=0; D=0; E=0
grep -q "MERLIN_BOT_COUVRANT" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && A=1
grep -q "LE GESTE T'EST DONNE EN FIN DE PROMPT" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && B=1
grep -q '"annulee"' "$GD/scripts/llm/merlin_native.gd" 2>/dev/null && C=1
grep -q "_meilleure_greffe" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && D=1
grep -q "MERLIN_BOT_COUVRANT" "$RP/infra/oracle/game/game-stack.sh" 2>/dev/null && E=1
echo "C garde070 sonde=$A place=$B annul=$C draft=$D env=$E (11111 = elle peut jouer)"

# Le Courrier est-il libre ? Un job qui boucle dans son tick bloque tous les suivants.
echo "D courrier_en_cours=$(pgrep -fc 'a_courrier.sh' 2>/dev/null || echo 0) job069_en_cours=$(pgrep -fc 'job-069' 2>/dev/null || echo 0) godot=$(pgrep -f 'godot.*probe_partie' >/dev/null 2>&1 && echo TOURNE || echo non)"
echo "D job070=$([ -f "$RP/infra/oracle/agents/courrier/job-070-partie-v48-1-complet.sh" ] && echo present || echo ABSENT) fait070=$([ -f "$ETAT/job-070-partie-v48-1-complet.fait" ] && echo pose || echo non)"
echo "D en_attente=$(cd "$RP/infra/oracle/agents/courrier" 2>/dev/null && for f in job-*.sh; do [ -f "$ETAT/${f%.sh}.fait" ] || echo "${f%.sh}"; done | tr '\n' ' ' | head -c 120)"
echo "Z fin cmd-017"
