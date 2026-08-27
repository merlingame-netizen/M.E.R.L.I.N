#!/usr/bin/env bash
# job-068 — LA CHRONIQUE v48 : une VRAIE partie, en rendu reel, avec CAPTURES a l'appui.
#
# Corrige le bug qui bloquait p66 : sa garde attendait le texte « FANTOME DE LA PHASE PRECEDENTE »
# dans a_partie_journal.sh, or ce commentaire a ete renomme « DRAIN AVANT LANCEMENT » le 24/08 —
# la garde n'etait donc JAMAIS satisfaite et la partie ne jouait jamais. Ici on n'attend que le
# vrai prerequis : v48 (phrase_du_geste) dans le jeu.
#
# La partie ecrit son journal + jusqu'a 12 captures (intro, 1/beat, fin). On les COPIE dans
# COURRIER_RES : le Courrier envoie automatiquement tout le dossier sur ntfy. Je telecharge et
# je compose la chronique HTML avec les captures REELLES.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
B="$HOME/.cache/merlin-partie"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari068-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: chron $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }
sel_valide() { python3 - "$B/selection.json" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1])); ok=bool(d.get("ok")) and len(d.get("sentiers") or [])>=1
except Exception: ok=False
sys.exit(0 if ok else 1)
PY
}

deadline=$(( $(date +%s) + 2700 ))
# SEUL vrai prerequis : v48 (phrase_du_geste) dans le jeu. Le harnais est deja deploye.
while ! grep -q "phrase_du_geste" "$GD/scripts/game/merlin_resolution.gd" 2>/dev/null; do
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "v48 jamais deploye sur le jeu"; exit 1; }
    sleep 30
done
# rendre la RAM au jeu
for m in $(curl -fsS -m 5 "$OLLAMA/api/ps" 2>/dev/null | python3 -c "import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "$OLLAMA/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done
bon=0
while [ "$bon" -lt 2 ]; do
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "jamais d'accalmie"; exit 1; }
    dispo=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    if ! pgrep -x godot >/dev/null 2>&1 && ! pgrep -f "bin/godot" >/dev/null 2>&1 && [ "$dispo" -gt 14000000 ]; then bon=$((bon+1)); else bon=0; fi
    sleep 30
done
dire "depart" "$(date -u +%H:%M:%SZ) sha=$(git -C "$GD" rev-parse --short HEAD) (v48)"

essais=0
while :; do
    essais=$((essais+1))
    env -u RES bash "$AGENTS/a_partie_journal.sh" selection > "$COURRIER_RES/sel$essais.log" 2>&1
    [ -s "$B/selection.json" ] && sel_valide && break
    [ "$essais" -ge 2 ] && { dire "ko" "selection invalide : $(tail -c 250 "$COURRIER_RES/sel$essais.log" | tr '\n' ' ')"; exit 1; }
    sleep 20
done
MERLIN_BEATS=6 env -u RES bash "$AGENTS/a_partie_journal.sh" partie 0 \
    "chronique v48 : l'empreinte de Broceliande" > "$COURRIER_RES/partie.log" 2>&1
if [ ! -s "$B/journal.json" ]; then
    tail -40 "$COURRIER_RES/partie.log" > "$COURRIER_RES/pourquoi68.txt"
    dire "ko" "journal absent : $(tail -c 250 "$COURRIER_RES/partie.log" | tr '\n' ' ')"
    exit 1
fi

# LE MATERIEL DE LA CHRONIQUE : le journal + toutes les captures reelles, dans COURRIER_RES.
cp "$B/journal.json" "$COURRIER_RES/journal.json" 2>/dev/null
mkdir -p "$COURRIER_RES/cliches"
cp "$B/cliches/"*.png "$COURRIER_RES/cliches/" 2>/dev/null
npng=$(ls "$COURRIER_RES/cliches/"*.png 2>/dev/null | wc -l | tr -d ' ')

# resume de l'empreinte v48 pour cadrer la chronique
python3 - "$B/journal.json" <<'PY' > "$COURRIER_RES/verdict68.txt"
import json,sys,re
d=json.load(open(sys.argv[1])); bs=d.get("beats") or []; res=[b for b in bs if "degre" in b]
blob=" ".join(str(b.get("narration",""))+" "+str(b.get("resolution","")) for b in bs)+" "+str(d.get("intro",""))
lieux=[x for x in ["Barenton","Val sans Retour","Pas de Nuit","Gue des Brumes","Pierre Qui Oublie","Chene Creux","Tertre"] if x.lower() in blob.lower()]
fig=[x for x in ["Lavandiere","Passeur","Ankou","korrigan","Fanch","Kado","Choeur","Chevalier","Enfant","Arthur"] if x.lower() in blob.lower()]
boucle=bool(re.search(r"boucl|rejou|repet|sans fin|encore et encore|tourne en rond|meme scene",blob,re.I))
sec=sum(1 for b in res if b.get("secours")); dur=[float(b.get("duree_beat_s",0)) for b in res if b.get("duree_beat_s")]
fin=d.get("fin") or {}
print("titre=%s beats=%d SECOURS=%d fin=%s duree_moy=%.0fs"%((d.get('choisi') or {}).get('titre','?'),len(bs),sec,fin.get('type','?'),(sum(dur)/len(dur)) if dur else 0))
print("empreinte v48: lieux=[%s] figures=[%s] boucle=%s"%(",".join(lieux),",".join(fig),boucle))
PY
dire "verdict" "captures=$npng $(head -c 400 "$COURRIER_RES/verdict68.txt")"
echo "job-068 : partie jouee, $npng captures + journal dans COURRIER_RES (le Courrier les envoie)."
