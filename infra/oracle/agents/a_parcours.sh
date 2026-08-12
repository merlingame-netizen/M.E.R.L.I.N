#!/usr/bin/env bash
# Carte du parcours — relit le jeu et la met à jour. ZÉRO appel au modèle.
# C'est ce que MERLIN consulte pour savoir de quel écran Maxime parle.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"
cd "$TOOLS_REPO" || { echo "dépôt d'outillage introuvable"; exit 1; }
OUT="$(nice -n 15 python3 tools/gd_agents/parcours.py 2>&1 | head -1)"
RC=$?
echo "$OUT"
exit $RC
