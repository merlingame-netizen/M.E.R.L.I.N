#!/usr/bin/env bash
# Relance des fils où Maxime a parlé le dernier — le rattrapage des messages
# perdus. Cas réel : le portail écrit le message de Maxime, puis demande à la
# couche d'actions de lancer chat-reply ; si le groupe LLM est déjà occupé, le
# lancement est REFUSÉ et personne ne le sait. Le message reste sans réponse,
# pour toujours, sans la moindre trace visible.
#
# Ce passage relit la boîte, repère les fils en attente depuis plus de 3 min et
# relance la réponse. Aucun appel LLM SUPPLÉMENTAIRE : c'est l'appel qui aurait
# dû avoir lieu.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"
cd "$TOOLS_REPO" || { echo "dépôt d'outillage introuvable"; exit 1; }

FILS="$(python3 -c "
import sys; sys.path.insert(0, 'tools/gd_agents')
import boite
print(' '.join(boite.en_attente_d_agent(3)))
" 2>/dev/null)"

[ -n "${FILS// /}" ] || { echo "aucun fil en attente"; exit 0; }

N=0
for conv in $FILS; do
    # Deux au maximum par passage : on ne vide pas une file de vingt d'un coup
    # sur quatre cœurs, et la cadence de 10 min rattrapera le reste.
    [ "$N" -ge 2 ] && break
    TO="$(python3 -c "
import sys; sys.path.insert(0, 'tools/gd_agents')
import boite
print(boite.destinataire('$conv') or 'merlin')
" 2>/dev/null)"
    timeout 600 python3 tools/gd_agents/chat_reply.py "$conv" "${TO:-merlin}" >/dev/null 2>&1 \
        && N=$((N + 1))
done
echo "$N fil(s) relancé(s) sur $(echo $FILS | wc -w) en attente"
