#!/usr/bin/env bash
# La partie temoin de v46 : le geste se DIT (phrase composee par le code), et le de se dispense
# (maitrise du verbe / rarete du trait). Elle doit aussi prouver le harnais repare (p65 : la
# cloture tuait un jeu en pleine charge des modeles, journal absent).
#
# Elle doit clore TROIS versions d'un coup, parce que le temoin de v44 est brule (job-065 est
# marque fait : il ne rejouera jamais) et que v45 n'a jamais ete regardee en partie :
#   v44 — le banc du pacte : pactes >= 1 ET SECOURS=0 (sans pacte, le cas fautif n'est pas rejoue)
#   v45 — l'issue ouvre la suite : lisible dans gestes66 (issue de chaque beat)
#   v46 — le geste se dit : phrases = 6/6 et incoherences = 0
# Cibles chiffrees : SECOURS=0, incoherences=0, pactes>=1, prompt_max<=1600, passe=0,
# duree_moy <= 45 s. Chaque cible manquee est dite avec son compte exact.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
B="$HOME/.cache/merlin-partie"
L="$HOME/.cache/merlin-game/godot.log"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari066-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    if curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok"; then
        NT="$base/merlin-courrier-vX9k2Qf7Lw3s"
        break
    fi
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: p66 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }
tranches() {
    split -b 250 -d -a 3 "$2" /tmp/t66.
    local total i p
    total=$(ls /tmp/t66.* | wc -l | tr -d ' ')
    i=0
    for p in $(ls /tmp/t66.* | sort); do
        i=$((i+1))
        curl -fsS -m 30 --retry 2 -H "Title: $1 part $i/$total" --data-binary @"$p" "$NT" >/dev/null 2>&1
        sleep 3
    done
    rm -f /tmp/t66.*
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

deadline=$(( $(date +%s) + 2700 ))
# v46 dans le JEU, et le harnais repare dans l'OUTILLAGE : les deux, sinon on ne mesure rien.
while ! grep -q "phrase_du_geste" "$GD/scripts/game/merlin_resolution.gd" 2>/dev/null \
     || ! grep -q "FANTOME DE LA PHASE PRECEDENTE" "$AGENTS/a_partie_journal.sh" 2>/dev/null; do
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "v46 ou le harnais jamais deployes"; exit 1; }
    sleep 30
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
dire "depart" "$(date -u +%H:%M:%SZ) sha=$(git -C "$GD" rev-parse --short HEAD)"
essais=0
while :; do
    essais=$((essais+1))
    env -u RES bash "$AGENTS/a_partie_journal.sh" selection > "$COURRIER_RES/sel$essais.log" 2>&1
    if [ -s "$B/selection.json" ] && sel_valide; then
        break
    fi
    [ "$essais" -ge 2 ] && { dire "ko" "selection invalide apres 2 essais : $(tail -c 300 "$COURRIER_RES/sel$essais.log" | tr '\n' ' ')"; exit 1; }
    sleep 20
done
MERLIN_BEATS=6 env -u RES bash "$AGENTS/a_partie_journal.sh" partie 0 \
    "temoin v46 : le geste se dit" > "$COURRIER_RES/partie.log" 2>&1
RCP=$?
if [ ! -s "$B/journal.json" ]; then
    # p65 avait renvoye douze lignes de llama_model_loader : rien d'exploitable. Le harnais
    # dit maintenant la memoire, le verdict du noyau et l'enveloppe — on remonte TOUT.
    sed -n '/aucun résultat après/,$p' "$COURRIER_RES/partie.log" > "$COURRIER_RES/pourquoi66.txt" 2>/dev/null
    [ -s "$COURRIER_RES/pourquoi66.txt" ] || tail -40 "$COURRIER_RES/partie.log" > "$COURRIER_RES/pourquoi66.txt"
    dire "ko" "journal absent rc=$RCP — diagnostic en tranches pourquoi66"
    tranches "pourquoi66" "$COURRIER_RES/pourquoi66.txt"
    exit 1
fi

python3 - "$B/journal.json" "$COURRIER_RES/passe66.txt" "$COURRIER_RES/gestes66.txt" <<'PY' > "$COURRIER_RES/verdict66.txt"
import json, re, sys
d = json.load(open(sys.argv[1]))
bs = d.get("beats") or []
resolus = [b for b in bs if "degre" in b]
MOTIFS = [
    r"enfreint", r"je t'ai (vu|déjà|deja)", r"te reconna", r"vous reconna",
    r"tes (longs )?voyages", r"de retour", r"tu es revenu", r"la dernière fois",
    r"autrefois,? (tu|vous)", r"tu te souviens", r"ton (ancien|serment|pacte)",
    r"ta (dette|faute|promesse) ", r"que tu as (jur|promis|trahi|laiss)",
]
RX = re.compile("|".join(MOTIFS), re.IGNORECASE)
textes = [("intro", str(d.get("intro", "")))]
for i, b in enumerate(bs, 1):
    textes.append(("beat%d/scene" % i, str(b.get("narration", ""))))
    textes.append(("beat%d/issue" % i, str(b.get("resolution", ""))))
fautes = []
for ou, txt in textes:
    for m in RX.finditer(txt):
        a, z = max(0, m.start() - 45), min(len(txt), m.end() + 45)
        fautes.append("%s : ...%s..." % (ou, txt[a:z].replace("\n", " ")))
open(sys.argv[2], "w").write("\n".join(fautes) if fautes else "aucune allusion au passe")

# LA mesure de v46 : le verbe joue ne doit JAMAIS produire un geste physique invente dans l'issue.
SANS_CONTACT = {"OBSERVER", "RÉVÉLER", "PARLER"}
CONTACT = re.compile(
    r"vos mains|votre main|vous posez (la|le|vos|votre)|vous saisissez|vous empoignez"
    r"|vous frappez|votre lame|votre fer|vous poussez|vous touchez|vous agrippez"
    r"|vous tirez sur|vous plaquez|du bout des doigts", re.IGNORECASE)
incoh, lignes = [], []
for i, b in enumerate(bs, 1):
    g = b.get("geste") or {}
    act, tr = str(g.get("action", "?")), str(g.get("trait", "?"))
    ph = str(b.get("phrase_geste", ""))
    mi = str(b.get("mise", ""))
    iss = str(b.get("resolution", "")).replace("\n", " ").strip()
    lignes.append("beat%d %s + %s [%s]\n  geste : %s\n  issue : %s" % (i, act, tr, mi, ph or "(aucune)", iss[:180]))
    if act in SANS_CONTACT:
        m = CONTACT.search(iss)
        if m:
            a, z = max(0, m.start() - 40), min(len(iss), m.end() + 40)
            incoh.append("beat%d %s : ...%s..." % (i, act, iss[a:z]))
open(sys.argv[3], "w").write("\n".join(lignes))

# v44 : le banc tombait au beat du PACTE (accepte apres le prefetch -> signature changee).
# Sans pacte joue, la partie ne rejoue pas le cas fautif et ne prouve donc rien de v44.
pactes = [i for i in (d.get("incidents") or []) if "pacte" in str(i.get("quoi", ""))]
beats_pacte = sorted({int(i.get("beat", -1)) + 1 for i in pactes})
sans_jet = [b.get("index", "?") for b in resolus if b.get("geste_sur")]
sec_beats = [b.get("index", "?") for b in resolus if b.get("secours")]
prov = {}
for b in bs:
    p = b.get("provenance", "?")
    prov[p] = prov.get(p, 0) + 1
durees = [float(b.get("duree_beat_s", 0)) for b in resolus if b.get("duree_beat_s")]
prompts = [int((b.get("gen") or {}).get("prompt_tokens", 0)) for b in resolus if b.get("gen")]
avec_phrase = sum(1 for b in resolus if str(b.get("phrase_geste", "")).strip())
fin = d.get("fin") or {}
print("beats=%d phrases=%d/%d incoherences=%d pactes=%d(beats %s) sansjet=%d(%s) SECOURS=%d(%s) prompt_max=%d passe=%d prov=%s beat1=%.0fs duree_moy=%.0fs fin=%s corr=%s titre=%s" % (
    len(bs), avec_phrase, len(resolus), len(incoh),
    len(pactes), ",".join(str(x) for x in beats_pacte) or "-",
    len(sans_jet), ",".join(str(x) for x in sans_jet) or "-",
    len(sec_beats), ",".join(str(x) for x in sec_beats) or "-",
    max(prompts) if prompts else 0, len(fautes),
    ",".join("%s:%d" % kv for kv in sorted(prov.items())),
    durees[0] if durees else 0,
    (sum(durees) / len(durees)) if durees else 0,
    fin.get("type", "?"), fin.get("corruption", "?"),
    ((d.get("choisi") or {}).get("titre", "?"))))
if not pactes:
    print("v44 NON PROUVEE : aucun pacte joue — le cas fautif n a pas ete rejoue.")
elif not sec_beats:
    print("v44 PROUVEE : %d pacte(s) aux beats %s, et zero banc de secours." % (
        len(pactes), ",".join(str(x) for x in beats_pacte)))
if incoh:
    print("INCOHERENCES :")
    for x in incoh:
        print("  " + x)
PY
dire "verdict" "rc=$RCP $(head -c 900 "$COURRIER_RES/verdict66.txt")"
tranches "gestes66" "$COURRIER_RES/gestes66.txt"
tranches "passe66" "$COURRIER_RES/passe66.txt"
tranches "journal66" "$B/journal.json"
echo "p66 : verdict + gestes + allusions + journal envoyes via $NT"
[ "$RCP" -eq 0 ]
