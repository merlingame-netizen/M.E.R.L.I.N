#!/usr/bin/env bash
# La partie qui doit PROUVER v44 : le banc tombait toujours au beat du pacte.
# Cibles : pactes >= 1 ET SECOURS=0 (sans pacte, le cas fautif n'est pas rejoue),
# prompt_max <= 1600, passe=0, duree_moy <= 45 s.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
B="$HOME/.cache/merlin-partie"
L="$HOME/.cache/merlin-game/godot.log"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari065-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    if curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok"; then
        NT="$base/merlin-courrier-vX9k2Qf7Lw3s"
        break
    fi
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: p65 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }
tranches() {
    split -b 250 -d -a 3 "$2" /tmp/t65.
    local total i p
    total=$(ls /tmp/t65.* | wc -l | tr -d ' ')
    i=0
    for p in $(ls /tmp/t65.* | sort); do
        i=$((i+1))
        curl -fsS -m 30 --retry 2 -H "Title: $1 part $i/$total" --data-binary @"$p" "$NT" >/dev/null 2>&1
        sleep 3
    done
    rm -f /tmp/t65.*
}
sel_valide() {
    python3 - "$B/selection.json" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    ok = bool(d.get("ok")) and len(d.get("sentiers") or []) >= 1
except Exception:
    ok = False
sys.exit(0 if ok else 1)
PY
}

deadline=$(( $(date +%s) + 2400 ))
while ! grep -q "VINGT SECONDES, PAS QUATRE" "$GD/scripts/llm/merlin_scenario.gd" 2>/dev/null; do
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "v44 jamais deployee"; exit 1; }
    sleep 30
done
for m in $(curl -fsS -m 5 "$OLLAMA/api/ps" 2>/dev/null | python3 -c "
import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "$OLLAMA/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done
bon=0
while [ "$bon" -lt 2 ]; do
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "jamais d'accalmie"; exit 1; }
    dispo=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    if ! pgrep -x godot >/dev/null 2>&1 && ! pgrep -f "bin/godot" >/dev/null 2>&1 && [ "$dispo" -gt 14000000 ]; then
        bon=$((bon+1))
    else
        bon=0
    fi
    sleep 30
done
dire "depart" "$(date -u +%H:%M:%SZ) sha=$(git -C "$GD" rev-parse --short HEAD)"
essais=0
while :; do
    essais=$((essais+1))
    env -u RES bash "$AGENTS/a_partie_journal.sh" selection > "$COURRIER_RES/sel$essais.log" 2>&1
    if [ -s "$B/selection.json" ] && sel_valide; then
        break
    fi
    [ "$essais" -ge 2 ] && { dire "ko" "selection invalide apres 2 essais : $(tail -c 300 "$COURRIER_RES/sel$essais.log" | tr '\n' ' ')"; exit 1; }
    sleep 20
done
MERLIN_BEATS=6 env -u RES bash "$AGENTS/a_partie_journal.sh" partie 0 \
    "preuve v44 : le beat du pacte" > "$COURRIER_RES/partie.log" 2>&1
RCP=$?
[ -s "$B/journal.json" ] || { dire "ko" "journal absent rc=$RCP : $(tail -c 350 "$COURRIER_RES/partie.log" | tr '\n' ' ')"; exit 1; }

python3 - "$B/journal.json" "$COURRIER_RES/passe65.txt" <<'PY' > "$COURRIER_RES/verdict65.txt"
import json, re, sys
d = json.load(open(sys.argv[1]))
bs = d.get("beats") or []
resolus = [b for b in bs if "degre" in b]
MOTIFS = [
    r"enfreint", r"je t'ai (vu|déjà|deja)", r"te reconna", r"vous reconna",
    r"tes (longs )?voyages", r"de retour", r"tu es revenu", r"la dernière fois",
    r"autrefois,? (tu|vous)", r"tu te souviens", r"ton (ancien|serment|pacte)",
    r"ta (dette|faute|promesse) ", r"que tu as (jur|promis|trahi|laiss)",
]
RX = re.compile("|".join(MOTIFS), re.IGNORECASE)
textes = [("pitch", str(s.get("pitch", ""))) for s in (d.get("sentiers") or [])]
textes.append(("intro", str(d.get("intro", ""))))
for i, b in enumerate(bs, 1):
    textes.append(("beat%d/scene" % i, str(b.get("narration", ""))))
    textes.append(("beat%d/issue" % i, str(b.get("resolution", ""))))
fautes = []
for ou, txt in textes:
    for m in RX.finditer(txt):
        a, z = max(0, m.start() - 45), min(len(txt), m.end() + 45)
        fautes.append("%s : ...%s..." % (ou, txt[a:z].replace("\n", " ")))
open(sys.argv[2], "w").write("\n".join(fautes) if fautes else "aucune allusion au passe")
# LE compte qui valide v44 : les pactes acceptes, et a quel beat.
pactes = [str(i.get("quoi", "")) for i in (d.get("incidents") or []) if "pacte" in str(i.get("quoi", ""))]
beats_pacte = sorted({int(i.get("beat", -1)) + 1 for i in (d.get("incidents") or []) if "pacte" in str(i.get("quoi", ""))})
sec_beats = [b.get("index", "?") for b in resolus if b.get("secours")]
sec = len(sec_beats)
prov = {}
for b in bs:
    p = b.get("provenance", "?")
    prov[p] = prov.get(p, 0) + 1
durees = [float(b.get("duree_beat_s", 0)) for b in resolus if b.get("duree_beat_s")]
gens = [float((b.get("gen") or {}).get("total_ms", 0)) / 1000.0 for b in resolus if b.get("gen")]
prompts = [int((b.get("gen") or {}).get("prompt_tokens", 0)) for b in resolus if b.get("gen")]
vous = 0
for b in resolus:
    t = re.sub(r"^[*\s]+", "", re.sub(r"^\[i\]\s*", "", str(b.get("resolution", "")).strip()))
    if t.lower().startswith("vous"):
        vous += 1
fin = d.get("fin") or {}
print("beats=%d pactes=%d(beats %s) SECOURS=%d(beats %s) prompt_max=%d passe=%d prov=%s vous=%d/%d beat1=%.0fs duree_moy=%.0fs issue_s_moy=%.0fs gw=%s fin=%s corr=%s titre=%s" % (
    len(bs), len(pactes), ",".join(str(x) for x in beats_pacte) or "-",
    sec, ",".join(str(x) for x in sec_beats) or "-",
    max(prompts) if prompts else 0, len(fautes),
    ",".join("%s:%d" % kv for kv in sorted(prov.items())),
    vous, len(resolus),
    durees[0] if durees else 0,
    (sum(durees) / len(durees)) if durees else 0,
    (sum(gens) / len(gens)) if gens else 0,
    "/".join(str(b.get("gwenneg_apres", "?")) for b in resolus),
    fin.get("type", "?"), fin.get("corruption", "?"),
    ((d.get("choisi") or {}).get("titre", "?"))))
PY
dire "verdict" "rc=$RCP $(cat "$COURRIER_RES/verdict65.txt")"
{
  echo "== la sequence des issues (motifs ancres sur des phrases completes) =="
  grep -an 'génération lancée\|prête au cache\|cache VIDE\|génération VIDE\|re-essai\|réserve est servie\|attente VAINE' "$L" 2>/dev/null | head -22
} > "$COURRIER_RES/course65.txt" 2>&1
tranches "course65" "$COURRIER_RES/course65.txt"
tranches "passe65" "$COURRIER_RES/passe65.txt"
tranches "journal65" "$B/journal.json"
echo "p65 : verdict + course + allusions + journal envoyes via $NT"
[ "$RCP" -eq 0 ]
