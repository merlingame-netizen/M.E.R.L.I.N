#!/usr/bin/env bash
# LE CRIBLE — chaque matin, l'état RÉEL de la VM, en un texte qu'on relit et qu'on compare.
#
# POURQUOI UN AGENT ET NON UN JOB. job-095 puis job-099 ont posé les mêmes questions à la main,
# chacun avec ses défauts (s95 lisait des clés inventées ; s99 lisait des états de course effacés
# en fin de course, un dossier `pending` qui s'appelle `inbox`, et titrait « 24 h » une fenêtre de
# 57 h). Un job se corrige en réécrivant un job. Un agent se corrige une fois, et tourne demain.
#
# CE QU'IL NE DIT JAMAIS : une URL, un jeton, un secret. Il part sur ntfy, sujet public.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"
ST="$HOME/.cache/merlin-agents"
OUTD="$ST/crible"
JOUR="$(date -u +%Y-%m-%d)"
OUT="$OUTD/$JOUR.txt"
mkdir -p "$OUTD"
TOK="$(grep -oE 'STUDIO_TOKEN=.*' "$HOME/.config/merlin-studio.env" 2>/dev/null | cut -d= -f2- | tr -d '"'"'"' \r')"

{
echo "== MACHINE =="
echo "date=$(date -u +%Y-%m-%dT%H:%MZ) coeurs=$(nproc) charge=$(cut -d' ' -f1-3 /proc/loadavg) $(uptime -p 2>/dev/null)"
awk '/MemTotal|MemAvailable|SwapFree/{printf "%s %d Mo  ",$1,$2/1024}' /proc/meminfo; echo
df -h / | awk 'NR>1{printf "disque : %s sur %s (%s)\n",$3,$2,$5}'
echo "modeles ollama charges : $(curl -fsS -m 5 "${OLLAMA_URL:-http://127.0.0.1:11434}/api/ps" 2>/dev/null | python3 -c "import json,sys
try: print(', '.join(m.get('name','?') for m in json.load(sys.stdin).get('models') or []) or 'aucun')
except Exception: print('injoignable')")"
G="$(pgrep -c -x godot 2>/dev/null)"   # pgrep -c imprime 0 ET sort en 1 : pas de « || echo 0 », il doublerait le zéro
echo "jeu : desire=$(cat "$HOME/.cache/merlin-game/desired" 2>/dev/null || echo ?) harnais=« $(merlin_harnais 2>/dev/null) » godot=${G:-0}"
echo
echo "== L'ATELIER DE NUIT : ce qui est garde (7 dernieres) =="
N7="$(ls -d "$HOME/.cache/merlin-partie/nuit"/*/ 2>/dev/null | sort | tail -7)"
[ -n "$N7" ] || echo "  AUCUNE partie de nuit gardee"
for d in $N7; do
    n="$(basename "$d")"
    echo "partie $n : $(python3 - "$d/journal.json" <<'PYX'
import json, sys
try:
    j = json.load(open(sys.argv[1], encoding="utf-8")); b = j.get("beats") or []
    banc = {x.get("index") for x in b if x.get("provenance") == "secours" or x.get("secours")} - {None}
    print("%d beats · fin %s · %d au banc · bot %s" % (len(b), (j.get("fin") or {}).get("type", "?"), len(banc),
          "couvrant" if any(x.get("choix_du_bot") for x in b) else "AVEUGLE"))
except Exception as e:
    print("journal illisible : %s" % e)
PYX
)"
    [ -f "$d/verdict.txt" ] && grep -aE "^CIBLE[0-9]|^BOT" "$d/verdict.txt" | cut -c1-150 | sed 's/^/     /'
done
Q7="$(ls -d "$HOME/.cache/merlin-quete/nuit"/*/ 2>/dev/null | sort | tail -7)"
[ -n "$Q7" ] || echo "  AUCUNE quete de nuit gardee"
for d in $Q7; do
    echo "quete  $(basename "$d") : $(head -1 "$d/verdict.txt" 2>/dev/null | tr -s ' ' | cut -c1-100) · $(grep -a 'adresse' "$d/grille.txt" 2>/dev/null | head -1 | tr -s ' ')"
done
echo "-- la courbe (nuits.jsonl, 7 dernieres) --"
tail -7 "$HOME/.cache/merlin-partie/nuits.jsonl" 2>/dev/null | python3 -c "
import json, sys
for l in sys.stdin:
    try: d = json.loads(l)
    except Exception: continue
    p = d.get('partie') or {}; q = d.get('quete') or {}
    print('  %s  partie: beats=%s banc=%s reussite=%s%% att_med=%ss p90=%ss bot=%s fin=%s | quete: %s beats, contrat %s, tu=%s vous=%s' % (
        d.get('nuit'), p.get('beats','-'), p.get('banc','-'), p.get('reussite_pct','-'), p.get('attente_med_s','-'),
        p.get('attente_p90_s','-'), 'couvrant' if p.get('bot_couvrant') else 'AVEUGLE', p.get('fin','-'),
        q.get('beats','-'), q.get('contrat','-'), q.get('tu','-'), q.get('vous','-')))
" 2>/dev/null || echo "  (pas encore de ligne)"
echo
echo "== LE SMOKE ET SES EPREUVES (dernier rapport) =="
python3 -c "
import json
d = json.load(open('$ST/smoke-scenes.json'))
print('  %s · commit %s · scenes %s (%s en erreur) · epreuves : %s · echouees=%s' % (d.get('t'), d.get('commit'), d.get('total'), d.get('failing'),
  ', '.join('%s=%s(%s rates)' % (e.get('epreuve'), e.get('etat'), e.get('rates')) for e in d.get('epreuves') or []) or 'ABSENTES', d.get('epreuves_echouees','?')))" 2>/dev/null || echo "  (pas de rapport)"
echo
echo "== CHAQUE AGENT : derniere course (etat final), duree, rc, resume =="
python3 - "$HERE" "$ST" <<'PYX'
import json, os, sys, time, datetime
import re
here, st = sys.argv[1], sys.argv[2]
sys.path.insert(0, here)
# MASQUER AVANT DE COUPER : une URL tronquée à 80 caractères ne matche plus aucun filtre
# (relecture du 06/09 : « …hampton-visiting.trycl » passait la garde et le Courrier).
def masque(s):
    return re.sub(r"https?://\S+|[A-Za-z0-9-]+\.trycloud\S*|ocid1\.\S+|Bearer\s+\S+", "<retiré>", str(s))
try:
    from overrides import agents as _agents
    agents = _agents()
except Exception:
    agents = json.load(open(os.path.join(here, "agents.json")))["agents"]
now = time.time()
def age(iso):
    try:
        t = datetime.datetime.strptime(iso, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc).timestamp()
        h = (now - t) / 3600
        return "%dh" % h if h < 48 else "%dj" % (h / 24)
    except Exception:
        return "?"
for a in sorted(agents, key=lambda x: x["id"]):
    aid = a["id"]
    try:
        d = json.load(open(os.path.join(st, "state", aid + ".json")))
    except Exception:
        d = None
    if not d:
        print("  %-16s %-14s %s" % (aid, a.get("schedule", "?")[:14], "JAMAIS COURU (aucun etat)" if a.get("enabled") else "desactive"))
        continue
    rc = d.get("rc")
    etat = "reporte" if d.get("reporte") or rc == 75 else ("ok" if rc == 0 else "ECHEC rc=%s" % rc)
    print("  %-16s %-14s il y a %-4s %4ss %-11s %s" % (aid, a.get("schedule", "?")[:14], age(d.get("last_run", "")),
          d.get("duration_s", "?"), etat, masque(d.get("summary", ""))[:80]))
PYX
echo
echo "== REVEILS PAR AGENT et ECHECS, sur la fenetre REELLEMENT lue dans cron.log =="
python3 - "$ST/cron.log" <<'PYX'
import re, sys, collections
try:
    lignes = open(sys.argv[1], encoding="utf-8", errors="replace").readlines()[-8000:]
except Exception:
    print("  (pas de cron.log)"); sys.exit(0)
dated = re.compile(r"^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ) \[([a-z-]+)\] rc=(\d+)")
undated = re.compile(r"^\[([a-z-]+)\] rc=(\d+)")
comptes = collections.Counter(); rep = collections.Counter(); echecs = []
premiere = derniere = None; n_dated = n_undated = 0
for l in lignes:
    m = dated.match(l)
    if m:
        n_dated += 1
        premiere = premiere or m.group(1); derniere = m.group(1)
        aid, rc = m.group(2), int(m.group(3))
    else:
        m = undated.match(l)
        if not m:
            continue
        n_undated += 1
        aid, rc = m.group(1), int(m.group(2))
    comptes[aid] += 1
    if rc == 75:
        rep[aid] += 1
    elif rc != 0:
        echecs.append(re.sub(r"https?://\S+|[A-Za-z0-9-]+\.trycloud\S*|ocid1\.\S+", "<retiré>", l.strip())[:150])
if premiere:
    print("  fenetre datee : %s → %s (%d lignes datees, %d anterieures non datees)" % (premiere, derniere, n_dated, n_undated))
else:
    print("  fenetre INCONNUE : aucune ligne datee (lanceur anterieur au 06/09) — %d lignes" % n_undated)
for aid, n in comptes.most_common(40):
    print("  %5d %-16s reportes=%d" % (n, aid, rep[aid]))
print("-- rc non nuls, hors reportes (12 derniers) --")
for e in echecs[-12:]:
    print("  " + e)
if not echecs:
    print("  aucun")
PYX
echo
echo "== VERROUS TENUS (lus dans /proc/locks, sans en prendre aucun) =="
python3 - "$ST" <<'PYX'
import glob, os, sys
st = sys.argv[1]
# Les ancêtres de cette course (agent-run → bash → python) tiennent légitimement crible.lock, et
# courrier.lock quand job-100 nous lance : on ne s'accuse pas soi-même.
anc, p = set(), os.getpid()
while p > 1:
    try:
        p = int(open("/proc/%d/stat" % p).read().rsplit(")", 1)[1].split()[1]); anc.add(p)
    except Exception:
        break
tenus = {}
try:
    for l in open("/proc/locks"):
        f = l.split()
        if len(f) >= 6 and f[1] == "FLOCK":
            maj, mi, ino = f[5].split(":")
            tenus.setdefault((int(maj, 16), int(mi, 16), int(ino)), []).append(int(f[4]))
except Exception as exc:
    print("  (/proc/locks illisible : %s)" % exc)
def comm(pid):
    try:
        return open("/proc/%d/comm" % pid).read().strip()
    except Exception:
        return "?"
def porteurs_par_fd(ino):
    out = set()
    for fdp in glob.glob("/proc/[0-9]*/fd/*"):
        try:
            if os.stat(fdp).st_ino == ino:
                pid = int(fdp.split("/")[2]); out.add(pid)
        except Exception:
            pass
    return out
n = 0
for lock in sorted(glob.glob(os.path.join(st, "*.lock"))):
    try:
        sb = os.stat(lock)
    except Exception:
        continue
    pids = set(tenus.get((os.major(sb.st_dev), os.minor(sb.st_dev), sb.st_ino), []))
    if not pids:
        continue
    # Le pid de /proc/locks est celui qui a POSÉ le verrou ; s'il est mort, le verrou vit dans un
    # descendant qui a hérité du descripteur : on le cherche par les fd.
    vivants = {q for q in pids if comm(q) != "?"} or porteurs_par_fd(sb.st_ino)
    if vivants and vivants <= anc:
        continue   # cette course même
    noms = sorted("%s(%d)" % (comm(q), q) for q in vivants) or ["porteur disparu"]
    outils = {"bash", "python3", "sh", "tail"}
    if vivants and all(comm(q) in outils for q in vivants):
        genre = "en cours (une course d'agent-run)"
    else:
        genre = "HERITE — l'agent ne tournera plus tant que ce processus vit"; n += 1
    print("  %-24s %s : %s" % (os.path.basename(lock), genre, ", ".join(noms)))
print("  %d verrou(s) herite(s)" % n)
PYX
echo
echo "== SURCHARGES HORS DEPOT =="
cat "$HOME/.config/merlin-agent-overrides.json" 2>/dev/null || echo "  aucune"
echo
echo "== LE CORPUS ET L'ATELIER DE CONTENU =="
for f in auto_corpus.jsonl curated_corpus.jsonl; do
    p="$TOOLS_REPO/data/ai/training/$f"
    if [ -f "$p" ]; then echo "  $f : $(wc -l < "$p") exemples · dernier $(date -u -r "$p" +%m-%dT%H:%M)"
    else echo "  $f : ABSENT ($p)"; fi
done
P="$HOME/.cache/merlin-proposals"
echo "  propositions : inbox $(ls "$P/inbox" 2>/dev/null | wc -l) · acceptees $(ls "$P/accepted" 2>/dev/null | wc -l) · refusees $(ls "$P/rejected" 2>/dev/null | wc -l)"
echo
echo "== LE STUDIO =="
echo "  healthz : $(curl -s -m 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:8790/healthz)"
if [ -n "$TOK" ]; then
    echo "  /api/chroniques : $(curl -s -m 10 -u "merlin:$TOK" http://127.0.0.1:8790/api/chroniques | python3 -c "import json,sys
try: p=json.load(sys.stdin).get('parties') or []; print('%d parties · %s' % (len(p), ', '.join(str(x.get('titre') or x.get('id'))[:22] for x in p[:5])))
except Exception as e: print('illisible (%s)' % e)")"
    echo "  /api/nuits : $(curl -s -m 10 -u "merlin:$TOK" http://127.0.0.1:8790/api/nuits | python3 -c "import json,sys
try: print('%d nuit(s)' % len(json.load(sys.stdin).get('nuits') or []))
except Exception as e: print('illisible (%s)' % e)")"
fi
echo "  tunnel : $( [ -f "$ST/tunnel-history.jsonl" ] && wc -l < "$ST/tunnel-history.jsonl" || echo 0 ) url(s) dans l'historique (jamais imprimees ici)"
echo
echo "== LES DEPOTS =="
echo "  jeu : $(cd "$GAME_DIR" 2>/dev/null && git log --oneline -1 2>/dev/null | cut -c1-90)"
echo "  outillage : $(cd "$TOOLS_REPO" 2>/dev/null && git log --oneline -1 2>/dev/null | cut -c1-90)"
echo "  chroniques du jeu : $(ls "$HOME/.local/share/godot/app_userdata"/*/chroniques/*.json 2>/dev/null | grep -vc index.json)"
} > "$OUT" 2>&1

# Garder trente jours, envoyer le texte (ntfy plafonne le corps : on coupe, le fichier reste entier).
ls -1t "$OUTD"/*.txt 2>/dev/null | tail -n +31 | xargs -r rm -f
if grep -qE 'https?://|trycloud|STUDIO_TOKEN=|Bearer |ocid1\.' "$OUT"; then
    echo "crible $JOUR : RETENU, il contenait une forme sensible — voir $OUT"; exit 1
fi
# SUR LE SUJET DU COURRIER, pas sur celui du téléphone : notify.sh pousse vers le téléphone de Maxime
# (NTFY_TOPIC) et 3 600 caractères chaque matin y seraient un réveil de trop. Le sujet du Courrier est
# celui que Claude lit ; Maxime peut l'ouvrir quand il veut. Trois miroirs, le premier qui répond.
# ET SEULEMENT DEPUIS LA VM : un essai local (06/09, 15h59) a posté le crible d'un bac à sable sur le
# sujet public. La configuration du jeu n'existe que sur la VM ; sans elle, on garde le fichier et
# on ne dit rien à personne. MERLIN_CRIBLE_SANS_ENVOI=1 force le silence même là-bas.
if [ -f "$HOME/.config/merlin-game.env" ] && [ "${MERLIN_CRIBLE_SANS_ENVOI:-0}" != "1" ]; then
    for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
        curl -fsS -m 20 -H "Title: crible $JOUR" --data-binary "$(head -c 3600 "$OUT")" \
            "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1 && break
    done
else
    echo "(pas d'envoi : configuration de la VM absente ou envoi désactivé)" >&2
fi
REP="$(grep -c ' reporte ' "$OUT" || true)"; ECH="$(grep -c 'ECHEC rc=' "$OUT" || true)"; HER="$(grep -c 'HERITE' "$OUT" || true)"
echo "crible $JOUR : $(wc -l < "$OUT") lignes · $ECH agent(s) en echec · $REP reporte(s) · $HER verrou(s) herite(s) · $(grep -m1 '^partie ' "$OUT" | cut -c1-70)"
