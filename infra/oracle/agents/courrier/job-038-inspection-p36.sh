#!/usr/bin/env bash
# p36 muette : où s'est-elle figée ? Dernier beat du journal partiel, queue du log,
# processus vivants — puis nettoyage de l'orphelin éventuel (le harnais est mort,
# son verrou aussi : un godot figé ne sert plus personne).
set -u
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
B="$HOME/.cache/merlin-partie"
L="$HOME/.cache/merlin-game/godot.log"
D="$COURRIER_RES/insp.txt"
{
  echo "== $(date -u +%H:%M:%SZ) =="
  echo "== godot vivants =="
  pgrep -af godot 2>/dev/null | head -4
  echo "== journal partiel =="
  python3 - "$B/journal.json" <<'PY' 2>&1
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    bs = d.get("beats") or []
    print("beats notes:", len(bs))
    if bs:
        b = bs[-1]
        print("dernier: idx=%s type=%s prov=%s degre=%s" % (
            b.get("index"), b.get("type"), b.get("provenance"), b.get("degre", "NON RESOLU")))
except Exception as e:
    print("journal illisible:", e)
PY
  echo "== log mtime =="
  stat -c '%y %s' "$L" 2>/dev/null
  echo "== log queue =="
  tail -c 1000 "$L" 2>/dev/null
  echo
  echo "== erreurs recentes =="
  grep -aE "SCRIPT ERROR|Parse Error|not declared|deadlock" "$L" 2>/dev/null | grep -av xkbcommon | tail -8
} > "$D" 2>&1
# Nettoyage : si un godot du probe traine encore (harnais mort), on le coupe proprement.
if pgrep -f "godot.*probe_partie_journal" >/dev/null 2>&1; then
    pkill -TERM -f "godot.*probe_partie_journal" 2>/dev/null
    echo "godot orphelin termine" >> "$D"
fi
split -b 250 -d -a 3 "$D" /tmp/in.
total=$(ls /tmp/in.* | wc -l | tr -d ' ')
i=0
for p in $(ls /tmp/in.* | sort); do
    i=$((i+1))
    curl -fsS -m 30 --retry 2 -H "Title: insp38 part $i/$total" \
        --data-binary @"$p" "$NT" >/dev/null 2>&1
    sleep 2
done
rm -f /tmp/in.*
echo "inspection envoyee en $total tranches"
