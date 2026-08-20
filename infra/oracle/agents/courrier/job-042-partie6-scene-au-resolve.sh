#!/usr/bin/env bash
# Partie témoin v35.4 : le chaînage au resolve — cible : lookahead SERVIE, enfin.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
B="$HOME/.cache/merlin-partie"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
dire() { curl -fsS -m 20 -H "Title: p42 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }
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
deadline=$(( $(date +%s) + 1500 ))
force_fait=0
while ! grep -q "v35.4" "$GD/scripts/game/merlin_game.gd" 2>/dev/null; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
        dire "ko" "v35.4 jamais deployee"
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
    [ "$essais" -ge 2 ] && { dire "ko" "selection invalide apres 2 essais"; exit 1; }
    sleep 20
done
MERLIN_BEATS=6 env -u RES bash "$AGENTS/a_partie_journal.sh" partie 0 \
    "temoin v35.4 : la scene au resolve" > "$COURRIER_RES/partie.log" 2>&1
RCP=$?
[ -s "$B/journal.json" ] || { dire "ko" "journal absent rc=$RCP : $(tail -c 350 "$COURRIER_RES/partie.log" | tr '\n' ' ')"; exit 1; }
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
fin = d.get("fin") or {}
print("beats=%d SECOURS=%d prov=%s duree_moy=%.0fs fin=%s corr=%s" % (
    len(bs), sec, ",".join("%s:%d" % kv for kv in sorted(prov.items())),
    (sum(durees) / len(durees)) if durees else 0, fin.get("type", "?"), fin.get("corruption", "?")))
PY
)"
dire "verdict" "rc=$RCP $VERDICT"
split -b 250 -d -a 3 "$B/journal.json" /tmp/j42.
total=$(ls /tmp/j42.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/j42.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: journal42 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 2.5
done
rm -f /tmp/j42.*
echo "verdict + journal ($total tranches) envoyes"
[ "$RCP" -eq 0 ]
