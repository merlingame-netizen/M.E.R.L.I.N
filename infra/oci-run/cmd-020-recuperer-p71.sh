#!/usr/bin/env bash
# cmd-020 (pont OCI) — RECUPERER p71, QUE MA PROPRE GARDE A JETE.
#
# job-071 a joue la partie ENTIERE, puis l'a declaree nulle : « mode couvrant JAMAIS engage ».
# La verification cherchait « choix des cartes : COUVRANT » dans partie.log. Or a_partie_journal.sh
# lance le jeu avec `bash "$GS" start >/dev/null 2>&1` : la sortie du JEU part dans godot.log, et
# partie.log ne contient que celle du harnais. Cette ligne ne pouvait donc JAMAIS s'y trouver.
# Une garde impossible a satisfaire, comme celle de job-066 — et elle a coute une partie de plus.
#
# Le journal, lui, existe : la partie est allee jusqu'au bout. On le remonte, avec ses captures,
# avant qu'une autre partie ne l'ecrase. Et on regarde dans godot.log ce que la sonde a REELLEMENT
# imprime sur son mode de choix.
set -u
echo "A depart $(date -u +%H:%M:%SZ)"
B="$HOME/.cache/merlin-partie"
NTFY="merlin-courrier-vX9k2Qf7Lw3s"
url_of(){ python3 -c "import json,sys;d=json.load(sys.stdin);print((d.get('attachment') or {}).get('url',''))" 2>/dev/null; }

echo "A journal=$([ -s "$B/journal.json" ] && stat -c %s "$B/journal.json" || echo ABSENT)o mtime=$(stat -c %y "$B/journal.json" 2>/dev/null | cut -c1-19) png=$(ls "$B/cliches/"*.png 2>/dev/null | wc -l)"

# ce que la sonde a vraiment dit de son mode, la ou elle l'a dit
G="$HOME/.cache/merlin-game/godot.log"
echo "B mode=$(grep -a 'choix des cartes' "$G" 2>/dev/null | tail -1 | head -c 90)"
echo "B beats=$(grep -ac '\[JOURNAL\] beat' "$G" 2>/dev/null) fin=$(grep -a '\[JOURNAL\] termine' "$G" 2>/dev/null | tail -1 | head -c 90)"

# le verdict, calcule sur place avec le script unique
RP="${REPO:-/var/lib/ocarun/workspace/M.E.R.L.I.N}"; [ -d "$RP" ] || RP="$HOME/workspace/M.E.R.L.I.N"
if [ -s "$B/journal.json" ]; then
  echo "C verdict :"
  python3 "$RP/infra/oracle/agents/courrier/verdict_partie.py" "$B/journal.json" 2>&1 | head -c 1100
fi

# instance ntfy vivante, puis on remonte le materiel
NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
  tok="canari20-$(date +%s)"
  curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/$NTFY" >/dev/null 2>&1; sleep 2
  curl -fsS -m 15 "$base/$NTFY/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de"
RJ="$(curl -fsS -m 90 --retry 2 -T "$B/journal.json" -H "Filename: p71_journal.json" -H "Title: p71 journal" "$NT/$NTFY" 2>/dev/null)"
echo "D journal -> $(printf '%s' "$RJ" | url_of)"
for png in $(ls "$B/cliches/"*.png 2>/dev/null | sort | head -8); do
  nom="$(basename "$png")"
  R="$(curl -fsS -m 90 --retry 2 -T "$png" -H "Filename: $nom" -H "Title: p71 $nom" "$NT/$NTFY" 2>/dev/null)"
  echo "D $nom -> $(printf '%s' "$R" | url_of)"
  sleep 2
done
echo "Z fin cmd-020"
