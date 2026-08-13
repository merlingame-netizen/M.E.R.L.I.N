#!/usr/bin/env bash
# Le Braséro — garde le modèle de conversation CHAUD.
#
# Le problème mesuré : Ollama décharge un modèle inactif au bout de son
# keep_alive. Le premier message de Maxime après une heure de silence payait donc
# le chargement complet (6,1 Go lus sur disque, ~40 s sur cette ARM) avant même
# que le modèle ne commence à répondre. Vu du téléphone, ça ressemble à une
# panne, et c'est ce qui l'a fait écrire « je perds souvent le signal ».
#
# Le remède tient en un appel : demander UN token au modèle en annonçant un
# keep_alive long. Ollama recharge s'il le faut, puis garde le modèle en RAM.
# Coût réel : quelques secondes de CPU toutes les 20 minutes, zéro token utile,
# zéro euro — la VM est déjà allumée et le calcul est local.
#
# UN SEUL modèle est maintenu, délibérément. L'orchestrateur du studio et le
# MERLIN du jeu ne diffèrent que par leur PROMPT, pas par leur modèle : en
# garder deux résidents coûterait ~12 Go des 22, en concurrence directe avec le
# jeu. Si la voix de Merlin se voit un jour attribuer son propre modèle
# (merlin_jeu.json → "modele"), le braséro le chauffe aussi.
#
# Écrit UNE ligne de résumé sur stdout : c'est le contrat d'agent-run.sh.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
CONF="$HOME/.config/merlin-llm.env"
[ -f "$CONF" ] && . "$CONF"

# Le modèle du CHAT, résolu exactement comme chat_reply.py le fait : COPILOT_MODEL,
# repli e4b. Surtout PAS TRIAGE_MODEL — mesuré sur la VM, celui-ci vaut 12b ou
# e2b selon le bench, et le braséro a chauffé un modèle que la conversation
# n'utilise jamais. Chauffer le mauvais modèle coûte la RAM sans rien accélérer :
# c'est pire que ne rien chauffer du tout.
MODEL="${COPILOT_MODEL:-gemma4:e4b-it-qat}"
[ "$MODEL" = "AUTO" ] && MODEL="gemma4:e4b-it-qat"

# Le jeu passe AVANT le confort du chat : quand Maxime joue, les 4 cœurs lui
# reviennent et on ne réveille rien.
if ! python3 "$TOOLS_REPO/tools/gd_agents/gates.py" >/dev/null 2>&1; then
    echo "jeu en cours — le braséro attend son tour"
    exit 0
fi

# La voix du jeu peut avoir choisi son propre modèle. Dans ce cas il y en a deux
# à chauffer, et on le DIT — c'est de la RAM qui ne sera plus disponible ailleurs.
VOIX="$(python3 - <<'PY' 2>/dev/null || true
import json, pathlib
p = pathlib.Path.home() / "merlin-memory" / "voix_merlin.json"
try:
    print((json.loads(p.read_text(encoding="utf-8")).get("modele") or "").strip())
except Exception:
    print("")
PY
)"

chauffe() {
    # `--predict 1` : un seul token. On ne veut pas une réponse, on veut que le
    # modèle soit en RAM. `think:false` est obligatoire sur Gemma 4, sinon tout
    # le budget part en réflexion interne et l'appel rend du vide.
    curl -fsS -m 300 "$OLLAMA/api/generate" -H 'content-type: application/json' \
        -d "{\"model\":\"$1\",\"prompt\":\"ok\",\"stream\":false,\"think\":false,
             \"keep_alive\":\"${OLLAMA_KEEP_ALIVE:-2h}\",
             \"options\":{\"num_predict\":1,\"num_thread\":2}}" >/dev/null 2>&1
}

# Le verrou LLM partagé, en NON BLOQUANT : si une analyse charge déjà un modèle,
# on ne fait pas la queue — le braséro est un confort, jamais une priorité.
exec 8>"$HOME/.cache/merlin-agents/llm.lock"
if ! flock -n 8; then
    echo "modèle occupé par un agent — rien à faire, il est déjà chaud"
    exit 0
fi

DEBUT="$(date +%s)"
OK=0
chauffe "$MODEL" && OK=1
[ -n "$VOIX" ] && [ "$VOIX" != "$MODEL" ] && chauffe "$VOIX"
SECS=$(( $(date +%s) - DEBUT ))

# La preuve, pas la promesse : on relit ce qu'Ollama dit avoir en mémoire.
RESIDENTS="$(curl -fsS -m 5 "$OLLAMA/api/ps" 2>/dev/null | python3 -c "
import json, sys
try:
    m = json.load(sys.stdin).get('models') or []
    print(', '.join(x.get('name', '?') for x in m) or 'aucun')
except Exception:
    print('injoignable')")"

# On vérifie que c'est BIEN le modèle du chat qui est résident, pas un autre.
# Dire « modèle chaud » sans le contrôler, c'est transformer une absence en
# fausse certitude — le travers que ce projet traque partout ailleurs.
case "$RESIDENTS" in
    *"$MODEL"*) CHAUD="oui" ;;
    *)          CHAUD="non" ;;
esac

if [ "$OK" = "1" ] && [ "$CHAUD" = "oui" ]; then
    echo "$MODEL chaud en ${SECS}s — résidents : $RESIDENTS"
elif [ "$OK" = "1" ]; then
    echo "$MODEL appelé (${SECS}s) mais absent de la RAM — résidents : $RESIDENTS"
else
    echo "$MODEL n'a pas répondu (${SECS}s) — résidents : $RESIDENTS"
fi
exit 0
