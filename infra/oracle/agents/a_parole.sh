#!/usr/bin/env bash
# Les agents t'interpellent — balayage des déclencheurs, zéro appel au modèle.
# Chaque agent parle avec le texte français qu'il produit déjà (son résumé, son
# diagnostic, le motif du validateur) : ouvrir un fil ne coûte pas un token.
# Quota dur de 2 fils par jour, tenu dans ~/merlin-memory/parole.json.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"
cd "$TOOLS_REPO" || { echo "dépôt d'outillage introuvable"; exit 1; }
OUT="$(python3 tools/gd_agents/parole.py 2>&1 | tail -1)"
RC=$?
echo "$OUT"
exit $RC
