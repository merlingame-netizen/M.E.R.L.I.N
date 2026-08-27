#!/usr/bin/env bash
# cmd-007 (pont OCI) — lire le verdict de la DERNIERE partie temoin (p66 du 25, sans v48) PUIS
# relancer une partie AVEC v48, pour mesurer l'empreinte. Le journal reste sur disque apres la
# partie ; on le lit directement (plus par ntfy, qui a expire).
set -u
R=/var/lib/ocarun/workspace/M.E.R.L.I.N
B=/var/lib/ocarun/.cache/merlin-partie
cd "$R" 2>/dev/null || cd "$HOME/workspace/M.E.R.L.I.N" || { echo "KO depot"; exit 1; }

echo "A jeu=$(git -C /var/lib/ocarun/workspace/merlin-game rev-parse --short HEAD 2>/dev/null) (v48=f066757)"

echo "B == verdict de la derniere partie temoin (journal sur disque) =="
J="$B/journal.json"
if [ -s "$J" ]; then
  echo "C journal mtime=$(stat -c %y "$J" 2>/dev/null | cut -c1-19)"
  python3 - "$J" <<'PY'
import json,sys,re
d=json.load(open(sys.argv[1]))
bs=d.get("beats") or []
res=[b for b in bs if "degre" in b]
sec=sum(1 for b in res if b.get("secours"))
dur=[float(b.get("duree_beat_s",0)) for b in res if b.get("duree_beat_s")]
fin=d.get("fin") or {}
# empreinte v48 : la boucle, un lieu nomme, une figure propre
blob=" ".join(str(b.get("narration",""))+" "+str(b.get("resolution","")) for b in bs)+" "+str(d.get("intro",""))
lieux=[x for x in ["Barenton","Val sans Retour","Pas de Nuit","Gue des Brumes","Pierre Qui Oublie","Chene Creux","Tertre"] if x.lower() in blob.lower()]
fig=[x for x in ["Lavandiere","Passeur","Ankou","korrigan","Fanch","Kado","Choeur","Chevalier"] if x.lower() in blob.lower()]
boucle=bool(re.search(r"bouclе|rejou|repet|sans fin|encore et encore|tourne en rond|meme scene",blob,re.I))
gen=[float((b.get("gen") or {}).get("total_ms",0))/1000 for b in res if b.get("gen")]
print("D beats=%d SECOURS=%d fin=%s corr=%s"%(len(bs),sec,fin.get("type","?"),fin.get("corruption","?")))
print("E duree_moy=%.0fs beat1=%.0fs gen_moy=%.0fs"%((sum(dur)/len(dur)) if dur else 0, dur[0] if dur else 0, (sum(gen)/len(gen)) if gen else 0))
print("F empreinte: lieux=%s figures=%s boucle=%s"%(",".join(lieux) or "-", ",".join(fig) or "-", boucle))
PY
else
  echo "C pas de journal.json (partie jamais aboutie)"
fi

echo "G == relance d'une partie AVEC v48 =="
M=/var/lib/ocarun/.cache/merlin-agents/courrier/job-066-partie19-v46.fait
if [ -f "$M" ]; then rm -f "$M" && echo "H marqueur job-066 efface -> rejoue avec v48 (Courrier */2)"; else echo "H marqueur deja absent"; fi
echo "Z fin cmd-007"
