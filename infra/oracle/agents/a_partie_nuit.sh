#!/usr/bin/env bash
# L'ATELIER DE NUIT — une partie, PUIS une quête, dans cet ordre, par un seul agent.
#
# POURQUOI UN SEUL AGENT. Les deux premières nuits (05 et 06/09), la partie de 4 h 05 tenait
# encore le jeu à 4 h 40 : la quête voyait « occupé » et sortait en 0 sans rien écrire, deux nuits
# de suite, sans qu'aucun compte le dise. Le moteur est mono-place : l'ordre se garantit en
# ENCHAÎNANT, pas en espaçant. (Le banc de 4 h 25, lui, se reportait bien : x11vnc du harnais.)
#
# CE QU'IL PRODUIT, daté sous ~/.cache/merlin-partie/nuit/<date>/ :
#   journal.json, selection.json, cliches/, verdict.txt, partie.log   (la partie, vue du dehors)
#   et, par a_quete_nuit.sh, ~/.cache/merlin-quete/nuit/<date>/        (la quête et sa grille)
# et UNE LIGNE par nuit dans ~/.cache/merlin-partie/nuits.jsonl — MÊME quand il renonce : une
# nuit reportée est un point de la courbe, pas un trou qu'on découvre trois semaines plus tard.
# C'est la courbe que le Studio trace, et la seule réponse mesurable à « le jeu s'améliore-t-il ? ».
#
# LE BOT JOUE COUVRANT. Sans MERLIN_BOT_COUVRANT=1 le bot cycle ses cartes à l'aveugle : avec un
# DC de 9 la réussite tombe à 28 % sans tag couvert contre 72 % avec un seul, et la cible
# « réussite » mesure alors les dés, pas le jeu (crible du 06/09 : covNone sur les onze partiels).
#
# LE VERROU LLM EST TENU TOUT DU LONG. Entre la partie et la quête, aucun godot ne tourne et le
# marqueur de harnais est vide : sans le verrou, gd-content-gap (*/30) passait la porte et
# chargeait un modèle pendant que la quête chargeait le sien (relecture du 06/09).
#
# CE QU'IL NE FAIT PAS : il ne joue pas si quelqu'un est devant, ni si un autre harnais VIVANT
# tient le jeu. Un renoncement sort en 75 (« reporté ») et le dit : ni un succès, ni un échec.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"
GS="$HERE/../game/game-stack.sh"
B="$HOME/.cache/merlin-partie"
NUIT="$(date -u +%Y-%m-%d)"
GARDE="$B/nuit/$NUIT"
JOURNAL="$B/journal.json"
SEL="$B/selection.json"
NUITS="$B/nuits.jsonl"
QUETE_JSON="$HOME/.cache/merlin-quete/nuit/$NUIT/quete.json"
mkdir -p "$B"

# ── UNE LIGNE PAR NUIT. Appelée à la fin, et avant chaque renoncement. Le contrat de la quête
#    se lit dans verdict.txt (la source), pas dans un code de retour : au rejeu du même jour,
#    « déjà écrite » sort 0 et aurait blanchi une quête refusée.
ligne_de_nuit() {
    # $1 résumé partie · $2 résumé quête · $3 reportée (oui|non)
    python3 - "$NUITS" "$NUIT" "$GARDE/journal.json" "$QUETE_JSON" "$(dirname "$QUETE_JSON")" \
            "$1" "$2" "$3" "$HERE/courrier/verdict_partie.py" <<'PYX'
import json, os, re, subprocess, sys
nuits, nuit, journal, quete, dquete, rp, rq, reportee, verdict = sys.argv[1:10]
ligne = {"nuit": nuit, "reportee": reportee == "oui", "partie": None, "quete": None,
         "resume_partie": rp, "resume_quete": rq}
if os.path.isfile(journal):
    try:
        out = subprocess.run([sys.executable, verdict, "--json", journal],
                             capture_output=True, text=True, timeout=60).stdout
        ligne["partie"] = json.loads(out.strip().splitlines()[-1])
    except Exception as exc:
        ligne["partie"] = {"erreur": str(exc)[:120]}
if os.path.isfile(quete):
    q = {}
    try:
        v = open(os.path.join(dquete, "verdict.txt"), encoding="utf-8").read()
        q["contrat"] = "REFUSE" if re.search(r"^\s*REFUS", v, re.M) else "PASSE"
    except Exception:
        q["contrat"] = "?"
    try:
        b = json.load(open(quete, encoding="utf-8")).get("beats") or []
        q["beats"] = len(b)
        q["signes"] = sum(len(str(x.get("scene", "")) + str(x.get("issue", ""))) for x in b)
        g = open(os.path.join(dquete, "grille.txt"), encoding="utf-8").read()
        m = re.search(r"adresse\s+tu=(\d+)\s+vous=(\d+)\s+3e pers\.=(\d+)", g)
        if m:
            q["tu"], q["vous"], q["troisieme"] = int(m.group(1)), int(m.group(2)), int(m.group(3))
    except Exception as exc:
        q["erreur"] = str(exc)[:120]
    ligne["quete"] = q
# La ligne de cette nuit remplace la précédente du même jour : rejouer la nuit ne double pas le point.
lignes = []
if os.path.isfile(nuits):
    for l in open(nuits, encoding="utf-8"):
        try:
            d = json.loads(l)
            if d.get("nuit") != nuit:
                lignes.append(l.rstrip("\n"))
        except Exception:
            pass
lignes.append(json.dumps(ligne, ensure_ascii=False))
open(nuits, "w", encoding="utf-8").write("\n".join(lignes) + "\n")
PYX
}

reporter() {
    # $1 raison
    ligne_de_nuit "reportée : $1" "" oui
    echo "$1 — atelier de nuit reporté"
    exit 75
}

# ── PERSONNE DEVANT, AUCUN AUTRE HARNAIS VIVANT. `desired` dit si Maxime a demandé le jeu ;
#    `merlin_harnais` dit si une sonde le tient ENCORE (un marqueur rassis est effacé au passage).
STATUT="$(bash "$GS" status 2>/dev/null | tail -1)"
DESIRED="$(cat "$HOME/.cache/merlin-game/desired" 2>/dev/null || echo stopped)"
HARNAIS="$(merlin_harnais)"
[ -z "$HARNAIS" ] || reporter "un autre harnais tient le jeu ($HARNAIS)"
[ "$DESIRED" != "running" ] || reporter "le jeu est demandé par quelqu'un"
printf '%s' "$STATUT" | grep -q '"vnc_open":true' && reporter "un spectateur est connecté"

# ── LE VERROU LLM, pour toute la durée. Fermé pour les enfants (8>&-) : un godot qui survivrait
#    ne doit pas le garder.
exec 8>"$HOME/.cache/merlin-agents/llm.lock"
flock -w 900 8 || reporter "le LLM est occupé depuis plus de 15 min"

decharger_ollama() {
    # La RAM et les cœurs reviennent au moteur du jeu (a_ollama_serve.sh ne rechargera pas le
    # copilote sous harnais ni avant 6 h).
    for m in $(curl -fsS -m 5 "${OLLAMA_URL:-http://127.0.0.1:11434}/api/ps" 2>/dev/null | python3 -c "import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
        curl -fsS -m 60 "${OLLAMA_URL:-http://127.0.0.1:11434}/api/generate" \
            -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
    done
}

# ── LA PARTIE
RESUME_PARTIE=""
if [ -s "$GARDE/journal.json" ]; then
    RESUME_PARTIE="déjà jouée"
else
    decharger_ollama
    DISPO=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    [ "${DISPO:-0}" -ge 12000000 ] || reporter "mémoire insuffisante (${DISPO} ko disponibles)"
    mkdir -p "$GARDE"
    rm -f "$SEL" "$JOURNAL"
    export MERLIN_BOT_COUVRANT=1
    # LA SORTIE EST GARDÉE (partie.log) : les deux premières nuits l'envoyaient dans /dev/null, et
    # une partie morte n'aurait laissé aucune explication.
    etape 1 3 "la partie de la nuit" 2>/dev/null || true
    env -u RES bash "$HERE/a_partie_journal.sh" selection >"$GARDE/partie.log" 2>&1 8>&- || true
    if [ ! -s "$SEL" ]; then
        RESUME_PARTIE="sélection des sentiers impossible (voir partie.log)"
    else
        env -u RES bash "$HERE/a_partie_journal.sh" partie 0 \
            "partie de la nuit : longueur libre, bot couvrant, sentier pris au premier sans arbitrage" \
            >>"$GARDE/partie.log" 2>&1 8>&- || true
        if [ -s "$JOURNAL" ]; then
            cp "$JOURNAL" "$GARDE/journal.json"
            [ -s "$SEL" ] && cp "$SEL" "$GARDE/selection.json"
            if [ -d "$B/cliches" ]; then
                mkdir -p "$GARDE/cliches"
                cp "$B/cliches/"*.png "$GARDE/cliches/" 2>/dev/null || true
            fi
            python3 "$HERE/courrier/verdict_partie.py" "$GARDE/journal.json" > "$GARDE/verdict.txt" 2>&1 || true
            RESUME_PARTIE="$(python3 - "$GARDE/journal.json" <<'PYX'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
b = d.get("beats") or []
fin = (d.get("fin") or {}).get("type", "?")
banc = {x.get("index") for x in b if x.get("provenance") == "secours" or x.get("secours")} - {None}
print("%d beats · fin %s · %d au banc · bot %s" % (
    len(b), fin, len(banc), "couvrant" if any(x.get("choix_du_bot") for x in b) else "AVEUGLE"))
PYX
)"
        else
            RESUME_PARTIE="aucun journal produit (voir partie.log)"
        fi
    fi
fi

# ── LA QUÊTE, APRÈS LA PARTIE, QUOI QU'IL SOIT ARRIVÉ À LA PARTIE. a_partie_journal.sh a remis
#    desired=stopped et game-stack a effacé le marqueur : la quête trouve le moteur libre.
etape 2 3 "la quête de la nuit" 2>/dev/null || true
mkdir -p "$GARDE"
SORTIE_QUETE="$(env -u RES bash "$HERE/a_quete_nuit.sh" 2>>"$GARDE/quete.log" 8>&-)"
RC_QUETE=$?
RESUME_QUETE="$(printf '%s\n' "$SORTIE_QUETE" | tail -1)"

etape 3 3 "la ligne de la nuit" 2>/dev/null || true
ligne_de_nuit "$RESUME_PARTIE" "$RESUME_QUETE" non

# ── NE PAS REMPLIR LE DISQUE : trente nuits gardées, les lignes de nuits.jsonl restent.
find "$B/nuit" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | head -n -30 | while read -r vieux; do
    rm -rf "$vieux"
done

echo "partie : $RESUME_PARTIE · quête : $RESUME_QUETE"
# Le code de retour porte la quête : un contrat refusé (1) reste un échec visible, une quête
# reportée (75) un report, et une nuit sans journal un échec.
[ -s "$GARDE/journal.json" ] || exit 1
[ "$RC_QUETE" = 75 ] && exit 75
[ "$RC_QUETE" = 0 ] && exit 0
exit 1
