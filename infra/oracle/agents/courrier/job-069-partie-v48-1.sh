#!/usr/bin/env bash
# job-069 — LA PARTIE TEMOIN DE v48.1, jugee sur les TROIS CIBLES DURES de Maxime :
#
#   1. SECOURS = 0            (aucun filet en dur servi)
#   2. reussite complete a chaque geste (le bot joue des combinaisons COUVRANTES)
#   3. <= 20 s par beat
#
# Chaque cible manquee est annoncee AVEC SON COMPTE EXACT. Une cible manquee n'est jamais
# arrondie, jamais tue : c'est la regle de cette maison depuis p68.
#
# Le journal remonte aussi le BUDGET DE CONTEXTE beat par beat (prompt_tokens / tokens_ecrits) :
# c'est la mesure qui a explique p68 (2045 tokens de prompt contre 2048 de contexte, 2 tokens
# de place pour ecrire) et c'est elle qui dira si v48.1 a vraiment rendu la place.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
B="$HOME/.cache/merlin-partie"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"

# --- une instance ntfy vivante (canari + rotation) ---
NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari069-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: p69 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }
sel_valide() { python3 - "$B/selection.json" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1])); ok=bool(d.get("ok")) and len(d.get("sentiers") or [])>=1
except Exception: ok=False
sys.exit(0 if ok else 1)
PY
}

deadline=$(( $(date +%s) + 2700 ))

# --- PREREQUIS : v48.1 vraiment deploye. Marqueur FONCTIONNEL, jamais un commentaire.
# (Lecon p66 : une garde ancree sur un texte de commentaire renomme n'est plus jamais satisfaite.)
while ! grep -q "MERLIN_BOT_COUVRANT\|choix_couvrant" "$GD/tools/probe_partie_journal.gd" 2>/dev/null; do
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "v48.1 jamais deploye (bot couvrant absent de la sonde)"; exit 1; }
    sleep 30
done
SHA="$(git -C "$GD" rev-parse --short HEAD)"

# --- rendre la RAM au jeu (Ollama garde ses modeles chauds sinon) ---
for m in $(curl -fsS -m 5 "$OLLAMA/api/ps" 2>/dev/null | python3 -c "import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "$OLLAMA/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done

# --- accalmie : deux releves consecutifs sans Godot et avec 14 Go libres ---
bon=0
while [ "$bon" -lt 2 ]; do
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "jamais d'accalmie"; exit 1; }
    dispo=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    if ! pgrep -x godot >/dev/null 2>&1 && ! pgrep -f "bin/godot" >/dev/null 2>&1 && [ "$dispo" -gt 14000000 ]; then bon=$((bon+1)); else bon=0; fi
    sleep 30
done
dire "depart" "$(date -u +%H:%M:%SZ) sha=$SHA (v48.1)"

# --- selection, puis la partie ---
essais=0
while :; do
    essais=$((essais+1))
    env -u RES bash "$AGENTS/a_partie_journal.sh" selection > "$COURRIER_RES/sel$essais.log" 2>&1
    [ -s "$B/selection.json" ] && sel_valide && break
    [ "$essais" -ge 2 ] && { dire "ko" "selection invalide : $(tail -c 250 "$COURRIER_RES/sel$essais.log" | tr '\n' ' ')"; exit 1; }
    sleep 20
done
MERLIN_BEATS=6 MERLIN_BOT_COUVRANT=1 env -u RES bash "$AGENTS/a_partie_journal.sh" partie 0 \
    "partie temoin v48.1 : zero secours, reussite complete, 20 s par beat" > "$COURRIER_RES/partie.log" 2>&1
if [ ! -s "$B/journal.json" ]; then
    tail -40 "$COURRIER_RES/partie.log" > "$COURRIER_RES/pourquoi69.txt"
    dire "ko" "journal absent : $(tail -c 250 "$COURRIER_RES/partie.log" | tr '\n' ' ')"
    exit 1
fi

cp "$B/journal.json" "$COURRIER_RES/journal.json" 2>/dev/null
mkdir -p "$COURRIER_RES/cliches"
cp "$B/cliches/"*.png "$COURRIER_RES/cliches/" 2>/dev/null
npng=$(ls "$COURRIER_RES/cliches/"*.png 2>/dev/null | wc -l | tr -d ' ')

# --- LE VERDICT : les trois cibles, chacune avec son compte exact ---
python3 - "$B/journal.json" <<'PY' > "$COURRIER_RES/verdict69.txt"
import json, sys, re
d = json.load(open(sys.argv[1]))
bs = d.get("beats") or []
res = [b for b in bs if "degre" in b]
fin = d.get("fin") or {}

# --- cible 1 : SECOURS = 0
sec = [b["index"] for b in res if b.get("secours")]
# --- cible 2 : reussite complete a chaque geste
deg = [str(b.get("degre", "?")) for b in res]
plein = [g for g in deg if g in ("reussite", "eclatante")]
pas_plein = [(b["index"], b.get("degre"), b.get("difficulte"), b.get("de")) for b in res
             if str(b.get("degre")) not in ("reussite", "eclatante")]
# --- cible 3 : <= 20 s par beat
dur = [(b["index"], float(b.get("duree_beat_s", 0))) for b in res if b.get("duree_beat_s")]
trop = [(i, s) for i, s in dur if s > 20.0]
moy = (sum(s for _, s in dur) / len(dur)) if dur else 0.0

c1 = "TENUE" if not sec else "MANQUEE (%d secours : beats %s)" % (len(sec), ",".join(map(str, sec)))
c2 = ("TENUE (%d/%d)" % (len(plein), len(res))) if not pas_plein else \
     "MANQUEE (%d/%d pleins ; manques: %s)" % (len(plein), len(res),
        " ".join("b%s=%s(diff%s,de%s)" % t for t in pas_plein))
c3 = ("TENUE (max %.0fs, moy %.0fs)" % (max((s for _, s in dur), default=0), moy)) if not trop else \
     "MANQUEE (%d beats > 20s : %s ; moy %.0fs)" % (len(trop), " ".join("b%d=%.0fs" % t for t in trop), moy)
print("CIBLE1 secours: %s" % c1)
print("CIBLE2 reussite: %s" % c2)
print("CIBLE3 duree: %s" % c3)

# --- le budget de contexte, la mesure qui a explique p68 ---
bud = []
for b in res:
    g = b.get("gen") or {}
    pt, te = g.get("prompt_tokens"), g.get("tokens_ecrits")
    if pt is not None:
        bud.append("b%s:p%s/e%s" % (b["index"], pt, te))
print("BUDGET %s" % " ".join(bud))
coupees = [b["index"] for b in res
           if int((b.get("gen") or {}).get("tokens_ecrits") or 0) < 40 and not b.get("secours")]
print("COUPEES %s" % (",".join(map(str, coupees)) if coupees else "aucune"))

# --- l'empreinte v48.1 : la boucle est-elle ENFIN dite ?
blob = " ".join(str(b.get("narration", "")) + " " + str(b.get("resolution", "")) for b in bs) + " " + str(d.get("intro", ""))
lieux = [x for x in ["Barenton", "Val sans Retour", "Pas de Nuit", "Gue des Brumes",
                     "Pierre Qui Oublie", "Chene Creux", "Tertre"] if x.lower() in blob.lower()]
fig = [x for x in ["Lavandiere", "Passeur", "Ankou", "korrigan", "Fanch", "Kado",
                   "Choeur", "Chevalier", "Enfant", "Arthur"] if x.lower() in blob.lower()]
boucle = re.findall(r"boucl\w*|rejou\w*|repet\w*|sans fin|encore et encore|tourne en rond|meme scene|deja vu", blob, re.I)
print("EMPREINTE lieux=[%s] figures=[%s] boucle=%d(%s)" % (
    ",".join(lieux), ",".join(fig), len(boucle), ",".join(sorted(set(x.lower() for x in boucle))[:4])))
print("FIN %s beats=%d integrite=%s corruption=%s" % (fin.get("type", "?"), len(bs),
      fin.get("integrite"), fin.get("corruption")))
PY

dire "verdict" "captures=$npng sha=$SHA $(head -c 700 "$COURRIER_RES/verdict69.txt")"

# le journal complet part aussi : c'est lui qui porte les chiffres fins.
curl -fsS -m 60 --retry 2 -T "$COURRIER_RES/journal.json" \
    -H "Filename: p69_journal.json" -H "Title: p69 journal" "$NT" >/dev/null 2>&1

echo "job-069 : partie v48.1 jouee (sha=$SHA), $npng captures + journal dans COURRIER_RES."
