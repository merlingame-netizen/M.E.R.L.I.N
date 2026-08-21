#!/usr/bin/env bash
# Partie témoin v35.4 bis + autopsie à chaud — p42 a prouvé SECOURS=0 mais arc:6,
# et son log godot a été vidé pendant le gel : cette partie-ci fournit ET le verdict
# ET les mesures natives (scènes lookahead : lancées ? finies ? jetées « Trop tard » ?).
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
B="$HOME/.cache/merlin-partie"
L="$HOME/.cache/merlin-game/godot.log"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari048-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    if curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok"; then
        NT="$base/merlin-courrier-vX9k2Qf7Lw3s"
        break
    fi
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: p48 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }
tranches() { # $1=prefixe titre  $2=fichier
    split -b 250 -d -a 3 "$2" /tmp/t48.
    local total i p
    total=$(ls /tmp/t48.* | wc -l | tr -d ' ')
    i=0
    for p in $(ls /tmp/t48.* | sort); do
        i=$((i+1))
        curl -fsS -m 30 --retry 2 -H "Title: $1 part $i/$total" --data-binary @"$p" "$NT" >/dev/null 2>&1
        sleep 3
    done
    rm -f /tmp/t48.*
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

grep -q "v35.4" "$GD/scripts/game/merlin_game.gd" 2>/dev/null || { dire "ko" "v35.4 absente du clone jeu"; exit 1; }
for m in $(curl -fsS -m 5 "$OLLAMA/api/ps" 2>/dev/null | python3 -c "
import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "$OLLAMA/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done
deadline=$(( $(date +%s) + 1200 ))
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
    "temoin v35.4 bis : autopsie a chaud" > "$COURRIER_RES/partie.log" 2>&1
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

# —— autopsie À CHAUD du log de CETTE partie ——
D="$COURRIER_RES/course48.txt"
{
  echo "== log=$(stat -c %y "$L" 2>/dev/null | cut -c1-19) =="
  echo "gen_scenes_lookahead=$(grep -ac 'scène.*(lookahead)' "$L" 2>/dev/null)"
  echo "pretes=$(grep -ac 'lookahead — scène.*prête' "$L" 2>/dev/null)"
  echo "== lookahead =="
  grep -an "lookahead" "$L" 2>/dev/null | head -40
  echo "== scene gen =="
  grep -a "\[MerlinNative\]" "$L" 2>/dev/null | grep -a "scène" | head -12
  echo "== arc =="
  grep -an "arc tranche\|arc :" "$L" 2>/dev/null | head -10
  echo "== issues =="
  grep -a "issue (combinaison)" "$L" 2>/dev/null | head -8
} > "$D" 2>&1
tranches "course48" "$D"
tranches "journal48" "$B/journal.json"
echo "p48 : verdict + course + journal envoyes via $NT"
[ "$RCP" -eq 0 ]
