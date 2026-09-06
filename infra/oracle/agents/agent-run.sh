#!/usr/bin/env bash
# Lanceur unique de tous les agents de la VM.
#   agent-run.sh <id>        exécute l'agent et écrit son état
#   agent-run.sh --list      liste les agents du manifeste (JSON)
#
# Chaque agent est un script isolé qui écrit UNE ligne de résumé sur stdout ;
# ce lanceur s'occupe du verrou (pas deux exécutions en parallèle), du
# chronométrage, du code retour et de l'état JSON lu par le portail.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

STATE_DIR="$HOME/.cache/merlin-agents"
LOG_DIR="$STATE_DIR/logs"
# L'état va dans un SOUS-DOSSIER : à la racine, "<id>.json" entrait en collision
# avec les fichiers de données produits par les agents eux-mêmes (déjà vu deux
# fois : llm-bench, billing). Ici, plus aucun nom d'agent ne peut en écraser un.
RUN_DIR="$STATE_DIR/state"
MANIFEST="$HERE/agents.json"
mkdir -p "$STATE_DIR" "$LOG_DIR" "$RUN_DIR"

if [ "${1:-}" = "--list" ]; then cat "$MANIFEST"; exit 0; fi

ID="${1:-}"
[ -n "$ID" ] || { echo "usage: agent-run.sh <id> | --list" >&2; exit 2; }

CMD="$(python3 -c "
import json,sys
m=json.load(open('$MANIFEST'))
a=[x for x in m['agents'] if x['id']=='$ID']
print(a[0]['cmd'] if a else '')
" 2>/dev/null)"
[ -n "$CMD" ] || { echo "agent inconnu: $ID" >&2; exit 2; }
SCRIPT="$HERE/$CMD"
[ -f "$SCRIPT" ] || { echo "script absent: $SCRIPT" >&2; exit 2; }

# rc=75 (EX_TEMPFAIL) : « REPORTÉ ». Ni un succès, ni un échec — un agent qui a renoncé en le
# disant. Le crible du 06/09 a trouvé douze renoncements sortis en 0 (« occupé », « mémoire
# insuffisante », « déjà en cours ») : impossibles à distinguer d'une course réussie dans
# cron.log, et la quête de la nuit a « réussi » deux nuits sans rien écrire. Désormais l'état
# JSON porte ok=true (rien n'a cassé) ET reporte=true, et la ligne de cron.log dit rc=75.
LOCK="$STATE_DIR/$ID.lock"
exec 9>"$LOCK"
if ! flock -n 9; then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [$ID] rc=75 déjà en cours, on passe"
    exit 75
fi

STATE="$RUN_DIR/$ID.json"
LOG="$LOG_DIR/$ID.log"
START_TS="$(date -u +%s)"
START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- ÉTAT DE COURSE (le « en direct ») ---
# `$STATE` n'est écrit qu'À LA FIN : pendant toute l'exécution il porte encore le passage
# PRÉCÉDENT. Le portail ne pouvait donc rien dire d'un agent en cours, sinon qu'il tournait.
# Ce fichier-ci vit LE TEMPS DE LA COURSE : posé maintenant, enrichi par `etape`, effacé après.
# Son absence signifie « aucune course en cours » — pas besoin d'un drapeau de plus.
RUN_STATE="$RUN_DIR/$ID.run.json"
export MERLIN_RUN_STATE="$RUN_STATE"
python3 - "$RUN_STATE" "$ID" "$START_TS" <<'PY' 2>/dev/null || true
import json, sys
chemin, aid, debut = sys.argv[1], sys.argv[2], int(sys.argv[3])
json.dump({"id": aid, "debut": debut, "etape": 0, "etapes_total": 0,
           "libelle": "démarrage", "maj": debut}, open(chemin, "w"), ensure_ascii=False)
PY

# L'agent écrit son résumé sur stdout ; tout le reste part dans le journal.
# `export -f` est INDISPENSABLE et pas décoratif : `bash "$SCRIPT"` démarre un NOUVEAU
# processus, qui n'hérite pas des fonctions du shell appelant — seulement de celles marquées
# exportées. Sans lui, tout agent appelant `etape` mourrait sur « command not found ».
# `9>&-` FERME LE VERROU POUR L'ENFANT. Sans cela, tout processus lancé par l'agent et qui lui
# survit (« nohup ollama serve & » dans a_ollama_serve.sh, le Godot de game-stack) hérite du
# descripteur 9 et GARDE le verrou : chaque réveil suivant dit « déjà en cours » — c'est ainsi
# qu'ollama-serve a disparu des comptes pendant deux semaines (crible du 06/09).
SUMMARY="$(. "$HERE/etape.sh"; export -f etape; bash "$SCRIPT" 9>&- 2>>"$LOG" | tail -1)"
RC=$?
END_TS="$(date -u +%s)"

# La course est finie : on retire l'état de course AVANT d'écrire l'état final, pour qu'aucun
# instant ne montre à la fois « une course en cours » et « un résultat ».
rm -f "$RUN_STATE" 2>/dev/null || true

# Journal borné (les agents tournent toutes les 2 minutes : sans cela le disque part).
tail -c 200000 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"

python3 - "$STATE" "$ID" "$START_ISO" "$((END_TS - START_TS))" "$RC" "$SUMMARY" <<'PY'
import json, sys
path, aid, started, dur, rc, summary = sys.argv[1:7]
json.dump({"id": aid, "last_run": started, "duration_s": int(dur),
           "rc": int(rc), "ok": int(rc) in (0, 75), "reporte": int(rc) == 75,
           "summary": summary or "(sans résumé)"},
          open(path, "w"), ensure_ascii=False)
PY
# cron.log est DATÉ : sans date, « les 6 000 dernières lignes » ne disent pas quelle fenêtre elles
# couvrent, et le crible a titré « 24 h » un comptage de 57 h.
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [$ID] rc=$RC ${SUMMARY}"
exit "$RC"
