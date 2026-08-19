#!/usr/bin/env bash
# Démo finale 10 beats sur v33 : « La Cicatrice de la Pierre Murmurante » (pick 1).
# Enjeu intime (les souvenirs), antagoniste mystique, climax au geste évident.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
NT="https://ntfy.envs.net/merlin-courrier-vX9k2Qf7Lw3s"
B="$HOME/.cache/merlin-partie"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
dire() { curl -fsS -m 20 -H "Title: p21 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }

if [ ! -s "$B/selection.json" ]; then
    dire "ko" "selection.json absent — rejouer job-020"
    exit 1
fi
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
dire "depart" "$(date -u +%H:%M:%SZ) beats=10 pick=1 MemAvailable=${dispo}kB"

MERLIN_BEATS=10 env -u RES bash "$AGENTS/a_partie_journal.sh" partie 1 \
    "enjeu le plus intime (les souvenirs, champ Memoire), antagoniste mystique original, climax au geste evident : briser le pacte" \
    > "$COURRIER_RES/partie.log" 2>&1
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

split -b 250 -d -a 3 "$B/journal.json" /tmp/j21.
total=$(ls /tmp/j21.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/j21.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: journal21 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 1.5
done
rm -f /tmp/j21.*
mkdir -p "$COURRIER_RES/cliches"
cp -f "$B"/cliches/*.png "$COURRIER_RES/cliches/" 2>/dev/null || true
for png in "$COURRIER_RES"/cliches/*.png; do
    [ -f "$png" ] || continue
    curl -fsS -m 60 --retry 2 -T "$png" -H "Filename: p21-$(basename "$png")" \
        -H "Title: p21 cliche $(basename "$png")" "$NT" >/dev/null 2>&1
    sleep 2
done
echo "verdict + journal ($total tranches) + cliches envoyes"
[ "$RCP" -eq 0 ]
