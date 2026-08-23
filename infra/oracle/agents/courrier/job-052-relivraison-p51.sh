#!/usr/bin/env bash
# Re-livraison des résultats de p51 (témoin v36) — le verdict du 21 au soir a expiré
# des relais ntfy (rétention 12 h) avant lecture. Tout est encore sur le disque.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
B="$HOME/.cache/merlin-partie"
R51="$AGENTS/courrier/resultats/job-051-partie9-v36"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari052-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    if curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok"; then
        NT="$base/merlin-courrier-vX9k2Qf7Lw3s"
        break
    fi
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: p52 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }
tranches() {
    split -b 250 -d -a 3 "$2" /tmp/t52.
    local total i p
    total=$(ls /tmp/t52.* | wc -l | tr -d ' ')
    i=0
    for p in $(ls /tmp/t52.* | sort); do
        i=$((i+1))
        curl -fsS -m 30 --retry 2 -H "Title: $1 part $i/$total" --data-binary @"$p" "$NT" >/dev/null 2>&1
        sleep 3
    done
    rm -f /tmp/t52.*
}

dire "etat" "journal_mtime=$(date -u -r "$B/journal.json" +%F_%H:%M 2>/dev/null || echo absent) sortie51=$(tail -c 200 "$R51/sortie.log" 2>/dev/null | tr '\n' ' ')"
if [ -f "$B/journal.json" ]; then
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
durees = [float(b.get("duree_beat_s", 0)) for b in resolus if b.get("duree_beat_s")]
toks = [int((b.get("gen") or {}).get("tokens_ecrits", 0)) for b in resolus if b.get("gen")]
gens = [float((b.get("gen") or {}).get("total_ms", 0)) / 1000.0 for b in resolus if b.get("gen")]
fin = d.get("fin") or {}
print("beats=%d SECOURS=%d prov=%s duree_moy=%.0fs issue_tok_moy=%.0f issue_s_moy=%.0fs fin=%s corr=%s titre=%s" % (
    len(bs), sec, ",".join("%s:%d" % kv for kv in sorted(prov.items())),
    (sum(durees) / len(durees)) if durees else 0,
    (sum(toks) / len(toks)) if toks else 0,
    (sum(gens) / len(gens)) if gens else 0,
    fin.get("type", "?"), fin.get("corruption", "?"),
    ((d.get("choisi") or {}).get("titre", "?"))))
PY
)"
    dire "verdict" "$VERDICT"
    [ -f "$R51/course51.txt" ] && tranches "course52" "$R51/course51.txt"
    tranches "journal52" "$B/journal.json"
else
    dire "ko" "journal.json absent"
fi
echo "re-livraison p51 via $NT"
