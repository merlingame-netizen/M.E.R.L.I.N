#!/usr/bin/env bash
# Validation v34 : sélection + partie 6 beats sur 4664c001, verdict étendu (secours,
# gestes sûrs, pactes, étals, durées, longueur des issues), journal en tranches.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
B="$HOME/.cache/merlin-partie"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
CIBLE="4664c00123fc02d41d85f282673e280ac998e0bc"
dire() { curl -fsS -m 20 -H "Title: p23 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }

deadline=$(( $(date +%s) + 1500 ))
force_fait=0
while ! git -C "$GD" merge-base --is-ancestor "$CIBLE" HEAD 2>/dev/null; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
        dire "ko" "jeu jamais sur v34 ($(git -C "$GD" rev-parse --short HEAD 2>/dev/null))"
        exit 1
    fi
    if [ "$force_fait" -eq 0 ] && [ "$(date +%s)" -ge $(( deadline - 900 )) ]; then
        bash "$AGENTS/a_game_autosync.sh" >> "$COURRIER_RES/autosync.log" 2>&1 || true
        force_fait=1
    fi
    sleep 20
done

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
dire "depart" "$(date -u +%H:%M:%SZ) sha=$(git -C "$GD" rev-parse --short HEAD)"

env -u RES bash "$AGENTS/a_partie_journal.sh" selection > "$COURRIER_RES/sel.log" 2>&1
[ -s "$B/selection.json" ] || { dire "ko" "selection absente : $(tail -c 450 "$COURRIER_RES/sel.log" | tr '\n' ' ')"; exit 1; }

MERLIN_BEATS=6 env -u RES bash "$AGENTS/a_partie_journal.sh" partie 0 \
    "validation v34 : premier sentier" > "$COURRIER_RES/partie.log" 2>&1
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
pactes = [0]
for i in (d.get("incidents") or []):
    m = re.search(r"\+(\d+) Corruption", str(i.get("quoi", "")))
    if m:
        pactes.append(int(m.group(1)))
etals = d.get("etals") or []
fin = d.get("fin") or {}
print("beats=%d resolus=%d SECOURS=%d surs=%d pacte_max=%d etals=%d achats=%d duree_moy=%.0fs phrases_moy=%.1f fin=%s corr=%s" % (
    len(bs), len(resolus), sec, surs, max(pactes), len(etals),
    sum(len(e.get("achats") or []) for e in etals), d_moy,
    (sum(phr) / len(phr)) if phr else 0.0, fin.get("type", "?"), fin.get("corruption", "?")))
PY
)"
dire "verdict" "rc=$RCP $VERDICT"

split -b 250 -d -a 3 "$B/journal.json" /tmp/j23.
total=$(ls /tmp/j23.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/j23.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: journal23 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 2.5
done
rm -f /tmp/j23.*
echo "verdict + journal ($total tranches) envoyes"
[ "$RCP" -eq 0 ]
