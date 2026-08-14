#!/usr/bin/env bash
# Le Délesteur — rend la RAM à l'atelier d'écriture.
#
# Le contexte, mesuré sur la VM : 14 Go de modèles résidents (12b = 8 Go pour le
# triage, e4b = 6 Go pour la conversation), 6,1 Go libres, et la boucle de corpus
# qui exige 8 Go — elle a été sautée toute la nuit. Le 12b ne sert qu'en LOT,
# deux fois par jour ; entre deux passages il occupe un tiers de la machine sans
# servir personne.
#
# La version précédente déchargeait TOUS les modèles après N minutes : c'est
# pour ça qu'elle n'a jamais pu être activée sans casser la conversation. Elle
# est maintenant CIBLÉE :
#
#   · le modèle de conversation n'est JAMAIS déchargé — c'est lui que le braséro
#     garde au chaud pour que Parler réponde tout de suite ;
#   · rien n'est déchargé tant que le verrou LLM partagé est pris : un modèle en
#     train de servir une analyse n'est pas inactif, quelle que soit l'horloge.
#     C'est plus juste qu'un compteur de minutes, et ça réutilise le verrou qui
#     existe déjà.
#
# Écrit UNE ligne de résumé sur stdout : c'est le contrat d'agent-run.sh.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
CONF="$HOME/.config/merlin-llm.env"
[ -f "$CONF" ] && . "$CONF"

# Le modèle de la conversation, résolu comme dans chat_reply.py et a_brasero.sh.
GARDE="${COPILOT_MODEL:-gemma4:e4b-it-qat}"
[ "$GARDE" = "AUTO" ] && GARDE="gemma4:e4b-it-qat"

CHARGES="$(curl -fsS -m 5 "$OLLAMA/api/ps" 2>/dev/null | python3 -c "
import json, sys
try:
    for m in json.load(sys.stdin).get('models') or []:
        print(m.get('name', ''))
except Exception:
    pass")"

[ -n "$CHARGES" ] || { echo "aucun modèle chargé — rien à libérer"; exit 0; }

# Le verrou partagé, en NON BLOQUANT : s'il est pris, un agent travaille et on
# ne touche à rien. On ne le garde PAS pendant les déchargements — les libérer
# est instantané, et bloquer la file pour ça n'aurait aucun sens.
exec 8>"$HOME/.cache/merlin-agents/llm.lock"
if ! flock -n 8; then
    echo "un agent utilise le modèle — rien déchargé"
    exit 0
fi
flock -u 8

LIBERES=""
GARDES=""
for m in $CHARGES; do
    if [ "$m" = "$GARDE" ]; then
        GARDES="${GARDES:+$GARDES, }$m"
        continue
    fi
    # keep_alive=0 demande à Ollama de rendre la mémoire immédiatement.
    if curl -fsS -m 20 "$OLLAMA/api/generate" -H 'content-type: application/json' \
        -d "{\"model\":\"$m\",\"prompt\":\"\",\"keep_alive\":0}" >/dev/null 2>&1; then
        LIBERES="${LIBERES:+$LIBERES, }$m"
    fi
done

# La preuve, pas la promesse : on relit la RAM après coup.
LIBRE="$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo '?')"

if [ -n "$LIBERES" ]; then
    echo "libéré $LIBERES · gardé ${GARDES:-aucun} · ${LIBRE} Mo disponibles"
else
    echo "rien à libérer (gardé ${GARDES:-aucun}) · ${LIBRE} Mo disponibles"
fi
exit 0
