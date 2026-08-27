#!/usr/bin/env bash
# cmd-019 (pont OCI) — TOUT FAIRE DESCENDRE, PUIS LAISSER job-071 JOUER.
#
# Ce qui a change depuis cmd-017 : v48.1f (la boucle en consigne) et v48.1g (plein regime,
# narration bornee, prompt_chars) cote jeu ; cote outillage, le budget de selection porte de 430
# a 950 s — c'est lui qui a coute p70, dont le jeu avait pourtant REUSSI — et job-071, qui lit le
# motif du refus au lieu de recopier une queue de log.
#
# On tire en direct (jamais via les agents : cmd-014 en est mort sans une ligne), on verifie les
# SEPT marqueurs de la garde de job-071, et on dit le temps mur de la derniere selection : c'est
# le chiffre qui justifie le nouveau budget.
set -u
echo "A depart $(date -u +%H:%M:%SZ)"
RP="${REPO:-/var/lib/ocarun/workspace/M.E.R.L.I.N}"
GD="${GAME_DIR:-/var/lib/ocarun/workspace/merlin-game}"
[ -d "$RP" ] || RP="$HOME/workspace/M.E.R.L.I.N"
[ -d "$GD" ] || GD="$HOME/workspace/merlin-game"
ETAT="$HOME/.cache/merlin-agents/courrier"
B="$HOME/.cache/merlin-partie"

for d in "$RP" "$GD"; do
  git -C "$d" config core.fileMode false 2>/dev/null
  av=$(git -C "$d" rev-parse --short HEAD 2>/dev/null || echo '?')
  git -C "$d" pull --ff-only >/dev/null 2>&1
  echo "B $(basename "$d") $av -> $(git -C "$d" rev-parse --short HEAD 2>/dev/null || echo '?')"
done

A=0; B1=0; C=0; D=0; E=0; F=0; G=0
grep -q "MERLIN_BOT_COUVRANT" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && A=1
grep -q "LE GESTE T'EST DONNE EN FIN DE PROMPT" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && B1=1
grep -q '"annulee"' "$GD/scripts/llm/merlin_native.gd" 2>/dev/null && C=1
grep -q "_meilleure_greffe" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && D=1
grep -q "montre que ces bois REJOUENT" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && E=1
grep -q "prompt_chars" "$GD/scripts/llm/merlin_native.gd" 2>/dev/null && F=1
grep -q "MERLIN_BOT_COUVRANT" "$RP/infra/oracle/game/game-stack.sh" 2>/dev/null && G=1
echo "C garde071 sonde=$A place=$B1 annul=$C draft=$D boucle=$E chars=$F env=$G (1111111 = elle peut jouer)"
echo "C budget_selection=$(grep -oP 'BUDGET=\K[0-9]+' "$RP/infra/oracle/agents/a_partie_journal.sh" | head -1)s quit_after=$(grep -oP 'MERLIN_QUIT_AFTER_S=\K[0-9]+' "$RP/infra/oracle/agents/a_partie_journal.sh" | head -1)s"

# le temps mur de la derniere selection : le chiffre qui justifie le nouveau budget
python3 - "$B/selection.json" <<'PY' 2>/dev/null || echo "D selection.json illisible"
import json,sys
d=json.load(open(sys.argv[1]))
print("D derniere selection : ok=%s sentiers=%d mur=%.0fs" % (
    d.get("ok"), len(d.get("sentiers") or []), (d.get("mur_ms") or 0)/1000.0))
PY

echo "E job071=$([ -f "$RP/infra/oracle/agents/courrier/job-071-partie-v48-1-complet.sh" ] && echo present || echo ABSENT) fait=$([ -f "$ETAT/job-071-partie-v48-1-complet.fait" ] && echo pose || echo non)"
echo "E en_attente=$(cd "$RP/infra/oracle/agents/courrier" 2>/dev/null && for f in job-*.sh; do [ -f "$ETAT/${f%.sh}.fait" ] || echo "${f%.sh}"; done | tr '\n' ' ' | head -c 120)"
echo "E godot=$(pgrep -f 'godot.*probe_partie' >/dev/null 2>&1 && echo TOURNE || echo non) mem=$(awk '/MemAvailable/ {printf "%.1f", $2/1048576}' /proc/meminfo)Go"
echo "Z fin cmd-019"
