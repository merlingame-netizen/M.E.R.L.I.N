#!/usr/bin/env bash
# Validation v35 : attend le déploiement (le fichier porte scene_lookahead), accalmie,
# sélection + 6 beats, verdict étendu : lookahead SERVIES (cible >= 2), ponts échantillonnés
# (plus jamais « la voie franchie »), SECOURS=0, durées en baisse.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
B="$HOME/.cache/merlin-partie"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
dire() { curl -fsS -m 20 -H "Title: p29 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }

deadline=$(( $(date +%s) + 1500 ))
force_fait=0
while ! grep -q 'scene_lookahead' "$GD/scripts/llm/merlin_scenario.gd" 2>/dev/null; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
        dire "ko" "v35 jamais deployee ($(git -C "$GD" rev-parse --short HEAD 2>/dev/null))"
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
dire "depart" "$(date -u +%H:%M:%SZ) sha=$(git -C "$GD" rev-parse --short HEAD) dispo=${dispo}kB"

env -u RES bash "$AGENTS/a_partie_journal.sh" selection > "$COURRIER_RES/sel.log" 2>&1
[ -s "$B/selection.json" ] || { dire "ko" "selection absente : $(tail -c 450 "$COURRIER_RES/sel.log" | tr '\n' ' ')"; exit 1; }

MERLIN_BEATS=6 env -u RES bash "$AGENTS/a_partie_journal.sh" partie 0 \
    "validation v35 : premier sentier" > "$COURRIER_RES/partie.log" 2>&1
RCP=$?
[ -s "$B/journal.json" ] || { dire "ko" "journal absent rc=$RCP : $(tail -c 400 "$COURRIER_RES/partie.log" | tr '\n' ' ')"; exit 1; }

VERDICT="$(python3 - "$B/journal.json" <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1]))
bs = d.get("beats") or []
resolus = [b for b in bs if "degre" in b]
sec = sum(1 for b in resolus if b.get("secours"))
prov = {}
for b in bs:
    p = b.get("provenance", "?")
    prov[p] = prov.get(p, 0) + 1
durees = [float(b.get("duree_beat_s", 0)) for b in resolus if b.get("duree_beat_s")]
d_moy = sum(durees) / len(durees) if durees else 0.0
ponts_degre = 0
for b in bs:
    n = str(b.get("narration", ""))
    if any(x in n for x in ("voie franchie", "demi-gain", "moitié payé", "A moitié payé", "À moitié payé", "sans dette")):
        ponts_degre += 1
fin = d.get("fin") or {}
print("beats=%d resolus=%d SECOURS=%d prov=%s PONTS_DEGRE=%d duree_moy=%.0fs fin=%s corr=%s" % (
    len(bs), len(resolus), sec,
    ",".join("%s:%d" % kv for kv in sorted(prov.items())),
    ponts_degre, d_moy, fin.get("type", "?"), fin.get("corruption", "?")))
PY
)"
dire "verdict" "rc=$RCP $VERDICT"

split -b 250 -d -a 3 "$B/journal.json" /tmp/j29.
total=$(ls /tmp/j29.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/j29.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: journal29 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 2.5
done
rm -f /tmp/j29.*
echo "verdict + journal ($total tranches) envoyes"
[ "$RCP" -eq 0 ]
