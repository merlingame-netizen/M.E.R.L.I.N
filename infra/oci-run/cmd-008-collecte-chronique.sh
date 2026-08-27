#!/usr/bin/env bash
# cmd-008 (pont OCI) — attendre la fin de la partie temoin v48 (en cours), puis faire remonter
# le JOURNAL + les CAPTURES REELLES sur ntfy, pour generer une chronique avec captures a l'appui.
#
# Le pont OCI ne rend que du texte tronque : les PNG passent donc par ntfy (curl -T), comme le
# Courrier l'a toujours fait. Le rapport texte liste les URLs, que je telecharge ensuite.
set -u
B=/var/lib/ocarun/.cache/merlin-partie
J="$B/journal.json"
SHOTS="$B/cliches"
NTFY="merlin-courrier-vX9k2Qf7Lw3s"

# 1) attendre la fin de la partie : plus aucun godot de sonde ET journal.json frais (< 8 min).
echo "A attente de la fin de partie..."
fin=$(( $(date +%s) + 1500 ))
while [ "$(date +%s)" -lt "$fin" ]; do
  if ! pgrep -f 'godot.*probe_partie_journal' >/dev/null 2>&1 && [ -s "$J" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$J" 2>/dev/null || echo 0) ))
    [ "$age" -lt 480 ] && { echo "B partie finie (journal age=${age}s)"; break; }
  fi
  sleep 20
done
[ -s "$J" ] || { echo "C KO : pas de journal.json"; exit 1; }

# 2) canari + choix d'instance ntfy (les quotas publics tombent en silence).
NT=""
for base in https://ntfy.sh https://ntfy.adminforge.de https://ntfy.envs.net; do
  tok="canari-chron-$(date +%s)"
  curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/$NTFY" >/dev/null 2>&1
  sleep 2
  curl -fsS -m 15 "$base/$NTFY/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.sh"
echo "D ntfy=$NT"

# 3) le journal d'abord (source du recit + liste des cliches).
url_of(){ python3 -c "import json,sys;d=json.load(sys.stdin);a=d.get('attachment') or {};print(a.get('url',''))" 2>/dev/null; }
RJ="$(curl -fsS -m 60 --retry 2 -T "$J" -H "Filename: chronique_journal.json" -H "Title: CHRON journal" "$NT/$NTFY" 2>/dev/null)"
echo "E journal -> $(printf '%s' "$RJ" | url_of)"

# 4) les captures, dans l'ordre (NN_nom.png). Une par message ; l'URL de chacune est listee.
n=0
for png in $(ls "$SHOTS"/*.png 2>/dev/null | sort); do
  nom="$(basename "$png")"
  ko=$(( $(stat -c %s "$png" 2>/dev/null || echo 0) / 1024 ))
  R="$(curl -fsS -m 90 --retry 2 -T "$png" -H "Filename: $nom" -H "Title: CHRON $nom" "$NT/$NTFY" 2>/dev/null)"
  echo "F $nom (${ko}Ko) -> $(printf '%s' "$R" | url_of)"
  n=$((n+1))
  sleep 2
done
echo "G captures_envoyees=$n"

# 5) un resume texte du journal (empreinte v48) pour cadrer la chronique.
python3 - "$J" <<'PY'
import json,sys,re
d=json.load(open(sys.argv[1]))
bs=d.get("beats") or []; res=[b for b in bs if "degre" in b]
blob=" ".join(str(b.get("narration",""))+" "+str(b.get("resolution","")) for b in bs)+" "+str(d.get("intro",""))
lieux=[x for x in ["Barenton","Val sans Retour","Pas de Nuit","Gue des Brumes","Pierre Qui Oublie","Chene Creux","Tertre"] if x.lower() in blob.lower()]
fig=[x for x in ["Lavandiere","Passeur","Ankou","korrigan","Fanch","Kado","Choeur","Chevalier","Enfant","Arthur"] if x.lower() in blob.lower()]
boucle=bool(re.search(r"boucl|rejou|repet|sans fin|encore et encore|tourne en rond|meme scene",blob,re.I))
sec=sum(1 for b in res if b.get("secours"))
dur=[float(b.get("duree_beat_s",0)) for b in res if b.get("duree_beat_s")]
fin=d.get("fin") or {}
print("H titre=%s beats=%d SECOURS=%d fin=%s duree_moy=%.0fs"%((d.get('choisi') or {}).get('titre','?'),len(bs),sec,fin.get('type','?'),(sum(dur)/len(dur)) if dur else 0))
print("I empreinte v48: lieux=%s | figures=%s | boucle=%s"%(",".join(lieux) or '-', ",".join(fig) or '-', boucle))
PY
echo "Z fin cmd-008"
