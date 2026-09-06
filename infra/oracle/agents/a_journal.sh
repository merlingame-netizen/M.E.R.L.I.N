#!/usr/bin/env bash
# Chapitre du jour — collecte déterministe puis rédaction par gabarits.
# AUCUN appel au modèle : ce passage ne peut pas échouer parce que le LLM est
# occupé, lent ou muet. Le narrateur (étape 5) viendra plus tard embellir deux
# scènes ; le socle, lui, est toujours écrit.
#
# Écrit UNE ligne de résumé sur stdout : c'est le contrat d'agent-run.sh.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

cd "$TOOLS_REPO" || { echo "dépôt d'outillage introuvable"; exit 1; }

# Le socle d'abord, la plume ensuite — et seulement si le verrou LLM est libre
# tout de suite. On ne fait PAS la queue : à 05:50 le créneau est vide, et s'il
# ne l'est pas, c'est que l'atelier d'écriture a débordé — dans ce cas le
# chapitre gabarit est écrit et c'est très bien.
exec 8>"$HOME/.cache/merlin-agents/llm.lock"
# LA PLUME EST ÉTEINTE (2026-09-06, décision de Maxime : l'atelier mesure seulement). 375 s de
# modèle chaque matin pour un chapitre qui ne lisait jamais la partie de la nuit. Le gabarit,
# sans LLM, reste : le socle est toujours écrit. Remettre PLUME=oui pour la rallumer.
PLUME=non
if [ "$PLUME" = oui ] && python3 tools/gd_agents/gates.py >/dev/null 2>&1 && flock -w 240 8; then
    OUT="$(nice -n 10 python3 tools/gd_agents/journal_plume.py 2>&1 | tail -1)"
    RC=$?
else
    OUT="$(nice -n 10 python3 tools/gd_agents/journal.py --ecrire --gabarits 2>&1 | tail -1)"
    RC=$?
    OUT="$OUT (modèle occupé — chapitre sans plume)"
fi
echo "$OUT"
exit $RC
