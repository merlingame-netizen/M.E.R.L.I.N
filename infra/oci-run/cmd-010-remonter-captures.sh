#!/usr/bin/env bash
# cmd-010 (pont OCI) — faire remonter le JOURNAL + les CAPTURES de la partie v48 (« Le Seuil de
# la Mousse ») sur ntfy, explicitement, pour composer la chronique. Le Courrier ne les a pas
# envoyees (course avec le job detache) ; on les pousse a coup sur.
set -u
B=/var/lib/ocarun/.cache/merlin-partie
NTFY="merlin-courrier-vX9k2Qf7Lw3s"
url_of(){ python3 -c "import json,sys;d=json.load(sys.stdin);print((d.get('attachment') or {}).get('url',''))" 2>/dev/null; }

# instance ntfy vivante
NT=""
for base in https://ntfy.sh https://ntfy.adminforge.de https://ntfy.envs.net; do
  tok="canari10-$(date +%s)"
  curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/$NTFY" >/dev/null 2>&1; sleep 2
  curl -fsS -m 15 "$base/$NTFY/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.sh"
echo "A ntfy=$NT journal=$([ -s "$B/journal.json" ] && echo oui || echo NON) png=$(ls "$B/cliches/"*.png 2>/dev/null | wc -l)"

# journal complet (le texte des 5 beats) pour la chronique
RJ="$(curl -fsS -m 60 --retry 2 -T "$B/journal.json" -H "Filename: chron_journal.json" -H "Title: CH journal" "$NT/$NTFY" 2>/dev/null)"
echo "B journal -> $(printf '%s' "$RJ" | url_of)"

# chaque capture, dans l'ordre
for png in $(ls "$B/cliches/"*.png 2>/dev/null | sort); do
  nom="$(basename "$png")"; ko=$(( $(stat -c %s "$png" 2>/dev/null || echo 0)/1024 ))
  R="$(curl -fsS -m 90 --retry 3 -T "$png" -H "Filename: $nom" -H "Title: CH $nom" "$NT/$NTFY" 2>/dev/null)"
  echo "C $nom ${ko}Ko -> $(printf '%s' "$R" | url_of)"
  sleep 2
done
echo "Z fin cmd-010"
