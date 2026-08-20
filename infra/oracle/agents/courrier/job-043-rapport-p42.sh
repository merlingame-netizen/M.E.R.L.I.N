#!/usr/bin/env bash
# Rapport p42 — la partie témoin v35.4 est restée MUETTE (aucun message, pas même un ko).
# Suspect n°1 : quota ntfy.sh par IP épuisé (~170 messages VM aujourd'hui) — les envois
# meurent en silence (leçon v33 violée par job-042 : instance unique, pas de canari).
# Ce job NE REJOUE RIEN : il retrouve l'état de job-042 sur le disque et le rapporte
# par la PREMIÈRE instance ntfy qui répond à un canari (rotation adminforge → envs → sh).
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
B="$HOME/.cache/merlin-partie"
ETAT="$HOME/.cache/merlin-agents/courrier"
J42="job-042-partie6-scene-au-resolve"
R42="$AGENTS/courrier/resultats/$J42"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.envs.net https://ntfy.sh; do
    tok="canari043-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    if curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok"; then
        NT="$base/merlin-courrier-vX9k2Qf7Lw3s"
        break
    fi
done
[ -n "$NT" ] || NT="https://ntfy.envs.net/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: p42r $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

dire "canal" "instance=$NT $(date -u +%H:%M:%SZ)"
FAIT="?"; [ -f "$ETAT/$J42.fait" ] && FAIT="$(cat "$ETAT/$J42.fait")"
SHA="$(git -C "$GD" rev-parse --short HEAD 2>/dev/null || echo '?')"
MARQ="non"; grep -q "v35.4" "$GD/scripts/game/merlin_game.gd" 2>/dev/null && MARQ="oui"
JMT="absent"; [ -f "$B/journal.json" ] && JMT="$(date -u -r "$B/journal.json" +%H:%M:%SZ)"
dire "etat" "fait=$FAIT sha=$SHA v35.4=$MARQ journal_mtime=$JMT godot=$(pgrep -x godot >/dev/null && echo vivant || echo aucun)"

for f in sortie.log partie.log sel1.log sel2.log autosync.log; do
    [ -f "$R42/$f" ] && dire "$f (fin)" "$(tail -c 700 "$R42/$f" | tr '\n' ' | ')"
done

if [ -f "$B/journal.json" ] && [ -f "$ETAT/$J42.fait" ] && [ "$B/journal.json" -nt "$ETAT/$J42.fait" ]; then
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
    dire "verdict" "$VERDICT"
    split -b 250 -d -a 3 "$B/journal.json" /tmp/j43.
    total=$(ls /tmp/j43.* | wc -l | tr -d ' ')
    i=0
    for p in $(ls /tmp/j43.* | sort); do
        i=$((i+1))
        curl -fsS -m 30 --retry 2 -H "Title: journal43 part $i/$total" \
            --data-binary @"$p" "$NT" >/dev/null 2>&1
        sleep 3
    done
    rm -f /tmp/j43.*
    dire "journal" "envoye en $total tranches"
else
    dire "verdict" "PAS de journal posterieur au depart de job-042 — la partie n'a pas produit de journal"
fi
echo "rapport p42 envoye via $NT"
