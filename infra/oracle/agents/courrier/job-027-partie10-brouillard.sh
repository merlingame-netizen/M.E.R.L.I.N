#!/usr/bin/env bash
# Démo finale v34 : « Le Retour des Marées de Brouillard » (pick 0), 10 beats.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
B="$HOME/.cache/merlin-partie"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
dire() { curl -fsS -m 20 -H "Title: p27 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }

[ -s "$B/selection.json" ] || { dire "ko" "selection.json absent"; exit 1; }
for m in $(curl -fsS -m 5 "$OLLAMA/api/ps" 2>/dev/null | python3 -c "
import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "$OLLAMA/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done
dl=$(( $(date +%s) + 120 ))
while :; do
    dispo=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    [ "$dispo" -gt 14000000 ] && break
    [ "$(date +%s)" -ge "$dl" ] && break
    sleep 3
done
dire "depart" "$(date -u +%H:%M:%SZ) beats=10 pick=0 dispo=${dispo}kB"

MERLIN_BEATS=10 env -u RES bash "$AGENTS/a_partie_journal.sh" partie 0 \
    "la Brume antagoniste actif, menace concrete (sentiers qui se referment, oubli du nom), theatre ideal du ton direct" \
    > "$COURRIER_RES/partie.log" 2>&1
RCP=$?

if [ ! -s "$B/journal.json" ]; then
    dire "ko" "journal absent rc=$RCP : $(tail -c 400 "$COURRIER_RES/partie.log" | tr '\n' ' ')"
    exit 1
fi

VERDICT="$(python3 - "$B/journal.json" <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1]))
bs = d.get("beats") or []
resolus = [b for b in bs if "degre" in b]
sec = sum(1 for b in resolus if b.get("secours"))
surs = sum(1 for b in resolus if b.get("geste_sur"))
durees = [float(b.get("duree_beat_s", 0)) for b in resolus if b.get("duree_beat_s")]
d_moy = sum(durees) / len(durees) if durees else 0.0
phr = []
for b in resolus:
    txt = re.sub(r"\[/?[a-z]+\]", "", str(b.get("resolution", "")))
    n = len([s for s in re.split(r"[.!?…]\s", txt) if s.strip()])
    if n:
        phr.append(n)
pactes_n = 0
pactes = [0]
for i in (d.get("incidents") or []):
    m = re.search(r"\+(\d+) Corruption", str(i.get("quoi", "")))
    if m:
        pactes_n += 1
        pactes.append(int(m.group(1)))
etals = d.get("etals") or []
fin = d.get("fin") or {}
print("beats=%d resolus=%d SECOURS=%d surs=%d pactes_n=%d pacte_max=%d etals=%d achats=%d duree_moy=%.0fs phrases_moy=%.1f fin=%s corr=%s pv=%s" % (
    len(bs), len(resolus), sec, surs, pactes_n, max(pactes), len(etals),
    sum(len(e.get("achats") or []) for e in etals), d_moy,
    (sum(phr) / len(phr)) if phr else 0.0, fin.get("type", "?"), fin.get("corruption", "?"), fin.get("integrite", "?")))
PY
)"
dire "verdict" "rc=$RCP $VERDICT"

split -b 250 -d -a 3 "$B/journal.json" /tmp/j27.
total=$(ls /tmp/j27.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/j27.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: journal27 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 2.5
done
rm -f /tmp/j27.*
for png in "$B"/cliches/*.png; do
    [ -f "$png" ] || continue
    curl -fsS -m 60 --retry 2 -T "$png" -H "Filename: p27-$(basename "$png")" \
        -H "Title: p27 cliche $(basename "$png")" "$NT" >/dev/null 2>&1
    sleep 2
done
echo "verdict + journal ($total tranches) + cliches envoyes"
[ "$RCP" -eq 0 ]
