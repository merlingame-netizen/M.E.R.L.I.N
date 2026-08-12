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
OUT="$(nice -n 10 python3 tools/gd_agents/journal.py --ecrire --gabarits 2>&1 | tail -1)"
RC=$?
echo "$OUT"
exit $RC
