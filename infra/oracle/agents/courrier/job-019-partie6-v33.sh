#!/usr/bin/env bash
# Validation v33 en jeu : sélection + partie 6 beats, verdict compact calculé sur la
# VM (secours/provenance/degrés/fin), puis journal en tranches — tout via envs.net.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
NT="https://ntfy.envs.net/merlin-courrier-vX9k2Qf7Lw3s"
B="$HOME/.cache/merlin-partie"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
dire() { curl -fsS -m 20 -H "Title: p19 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }

for m in $(curl -fsS -m 5 "$OLLAMA/api/ps" 2>/dev/null | python3 -c "
import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "$OLLAMA/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done
dl=$(( $(date +%s) + 90 ))
while :; do
    dispo=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    [ "$dispo" -gt 14000000 ] && break
    [ "$(date +%s)" -ge "$dl" ] && break
    sleep 3
done
dire "depart" "$(date -u +%H:%M:%SZ) sha=$(git -C \"${GAME_DIR:-$HOME/workspace/merlin-game}\" rev-parse --short HEAD 2>/dev/null) MemAvailable=${dispo}kB"

env -u RES bash "$AGENTS/a_partie_journal.sh" selection > "$COURRIER_RES/sel.log" 2>&1
[ -s "$B/selection.json" ] || { dire "ko" "selection absente : $(tail -c 500 "$COURRIER_RES/sel.log" | tr '\n' ' ')"; exit 1; }

MERLIN_BEATS=6 env -u RES bash "$AGENTS/a_partie_journal.sh" partie 0 \
    "validation v33 : premier sentier" > "$COURRIER_RES/partie.log" 2>&1
RCP=$?

if [ ! -s "$B/journal.json" ]; then
    dire "ko" "journal absent rc=$RCP : $(tail -c 450 "$COURRIER_RES/partie.log" | tr '\n' ' ')"
    exit 1
fi

VERDICT="$(python3 - "$B/journal.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
bs = d.get("beats") or []
resolus = [b for b in bs if "degre" in b]
sec = sum(1 for b in resolus if b.get("secours"))
prov = {}
for b in bs:
    p = b.get("provenance", "?")
    prov[p] = prov.get(p, 0) + 1
fin = d.get("fin") or {}
print("beats=%d resolus=%d SECOURS=%d modele=%d prov=%s fin=%s intro_modele=%s" % (
    len(bs), len(resolus), sec, len(resolus) - sec,
    ",".join("%s:%d" % kv for kv in sorted(prov.items())),
    fin.get("type", "?"), d.get("intro_du_modele")))
PY
)"
dire "verdict" "rc=$RCP $VERDICT"

split -b 250 -d -a 3 "$B/journal.json" /tmp/j19.
total=$(ls /tmp/j19.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/j19.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: journal19 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 1.5
done
rm -f /tmp/j19.*
mkdir -p "$COURRIER_RES/cliches"
cp -f "$B"/cliches/*.png "$COURRIER_RES/cliches/" 2>/dev/null || true
echo "verdict + journal ($total tranches) envoyes"
"$([ "$RCP" -eq 0 ] && echo true || echo false)"
