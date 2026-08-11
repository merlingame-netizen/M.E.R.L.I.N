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
MANIFEST="$HERE/agents.json"
mkdir -p "$STATE_DIR" "$LOG_DIR"

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

LOCK="$STATE_DIR/$ID.lock"
exec 9>"$LOCK"
if ! flock -n 9; then
    echo "[$ID] déjà en cours, on passe"
    exit 0
fi

STATE="$STATE_DIR/$ID.json"
LOG="$LOG_DIR/$ID.log"
START_TS="$(date -u +%s)"
START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# L'agent écrit son résumé sur stdout ; tout le reste part dans le journal.
SUMMARY="$(bash "$SCRIPT" 2>>"$LOG" | tail -1)"
RC=$?
END_TS="$(date -u +%s)"

# Journal borné (les agents tournent toutes les 2 minutes : sans cela le disque part).
tail -c 200000 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"

python3 - "$STATE" "$ID" "$START_ISO" "$((END_TS - START_TS))" "$RC" "$SUMMARY" <<'PY'
import json, sys
path, aid, started, dur, rc, summary = sys.argv[1:7]
json.dump({"id": aid, "last_run": started, "duration_s": int(dur),
           "rc": int(rc), "ok": int(rc) == 0, "summary": summary or "(sans résumé)"},
          open(path, "w"), ensure_ascii=False)
PY
echo "[$ID] rc=$RC ${SUMMARY}"
exit "$RC"
