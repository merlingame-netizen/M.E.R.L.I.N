#!/usr/bin/env bash
# Le Séquenceur — relit où en est la chaîne de dev et publie l'échelle pour le portail.
#
# Il n'exécute AUCUN agent : voir l'en-tête de sequence.py pour la raison (double exécution,
# et une chaîne qui contient des gestes humains ne s'exécute pas — elle s'observe).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

etape 1 1 "lecture de la chaîne"

# Le dépôt du jeu doit connaître l'état DISTANT des deux branches, sinon on jugerait la
# fusion sur une vue périmée et on annoncerait « en attente de toi » sur un travail déjà
# intégré. Silencieux et sans échec : hors réseau, on lit ce qu'on a plutôt que de renoncer.
if [ -d "$GAME_DIR/.git" ]; then
    git -C "$GAME_DIR" fetch origin "$GAME_REF" --quiet 2>/dev/null || true
    git -C "$GAME_DIR" fetch origin auto/nightly --quiet 2>/dev/null || true
fi

python3 "$HERE/sequence.py" "$TOOLS_REPO" "$GAME_DIR" "$GAME_REF" \
    "$HOME/.cache/merlin-agents/state/seq-dev.json"
