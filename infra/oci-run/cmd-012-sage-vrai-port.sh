#!/usr/bin/env bash
# cmd-012 (pont OCI) — RATTRAPAGE de cmd-011, qui sondait le mauvais port.
#
# cmd-011 a conclu « Studio injoignable » en interrogeant 8787 : c'etait MON erreur, le Studio
# ecoute sur 8790 (infra/oracle/studio/keepalive-user.sh). On resonde le bon port, et surtout
# on interroge LE SAGE SANS PASSER PAR HTTP : son socle est grimoire.py (Bible + tetes de code
# source de verite), qu'on appelle directement en Python. Aucun jeton, aucune route
# authentifiee, rien de confidentiel dans la sortie -- le depot est PUBLIC.
#
# Corrige aussi le chemin des marqueurs du Courrier : ~/.cache/merlin-agents/courrier/*.fait
# (cmd-011 les cherchait dans le depot, d'ou une ligne vide trompeuse).
set -u
RP="${REPO:-/var/lib/ocarun/workspace/M.E.R.L.I.N}"
[ -d "$RP" ] || RP="$HOME/workspace/M.E.R.L.I.N"
ETAT="$HOME/.cache/merlin-agents/courrier"

# --- A. le Studio, sur le BON port ---
h=$(curl -s -o /dev/null -w '%{http_code}' -m 8 "http://127.0.0.1:8790/healthz" 2>/dev/null)
pid=$(pgrep -u "$(id -un)" -f "merlin_studio/[a]pp.py" | head -1)
echo "A studio_8790=$h pid=${pid:-aucun} keepalive_cron=$(crontab -l 2>/dev/null | grep -c keepalive-user)"

# --- B. le Courrier, au bon endroit ---
nf=$(ls -1 "$ETAT"/*.fait 2>/dev/null | wc -l | tr -d ' ')
dernier=$(ls -1t "$ETAT"/*.fait 2>/dev/null | head -1 | xargs -r basename)
echo "B courrier_faits=$nf dernier=${dernier:-aucun} a=$(cat "$ETAT/$dernier" 2>/dev/null | head -c 20)"
echo "B jobs_en_attente=$(cd "$RP/infra/oracle/agents/courrier" 2>/dev/null && for f in job-*.sh; do [ -f "$ETAT/${f%.sh}.fait" ] || echo "${f%.sh}"; done | tr '\n' ' ' | head -c 200)"

# --- C. LE SAGE, en direct, sans HTTP ni jeton ---
cd "$RP/tools/gd_agents" 2>/dev/null || { echo "C gd_agents introuvable"; echo "Z fin cmd-012"; exit 0; }
Q="Quelle est la loi de Broceliande, et qu est-ce qui distingue le Voyageur des autres etres de la foret ?"
PY="${RP}/.venv/bin/python"; [ -x "$PY" ] || PY=python3
"$PY" - "$Q" <<'PYEOF' 2>&1 | head -c 1200
import sys, pathlib
sys.path.insert(0, str(pathlib.Path.cwd()))
q = sys.argv[1]
try:
    import grimoire
except Exception as e:
    print("C grimoire illisible : %s" % e); raise SystemExit(0)
ps = grimoire.passages(q)
print("C socle : %d passage(s) trouve(s)" % len(ps))
for titre, extrait, source in ps[:4]:
    print("C   - [%s] %s (%d car.)" % (source, titre, len(extrait)))
refs = grimoire.references(q)
print("C sources : %s" % (refs[:220] if refs else "AUCUNE"))
p = grimoire.prompt(q)
print("C prompt du Sage : %d car." % len(p))
PYEOF

# la vraie reponse du modele, si le brasero local est la (borne court : Run Command tronque)
MOD=$(grep -s COPILOT_MODEL "$HOME/.config/merlin-llm.env" 2>/dev/null | cut -d= -f2 | tr -d ' ')
[ -n "${MOD:-}" ] || MOD="gemma4:e4b-it-qat"
up=$(curl -fsS -m 5 "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1 && echo oui || echo non)
echo "C ollama=$up modele=$MOD"
if [ "$up" = "oui" ]; then
  R=$("$PY" - "$Q" "$MOD" <<'PYEOF' 2>&1 | head -c 700
import sys, pathlib, json, urllib.request
sys.path.insert(0, str(pathlib.Path.cwd()))
import grimoire
q, model = sys.argv[1], sys.argv[2]
body = json.dumps({"model": model, "prompt": grimoire.prompt(q),
                   "stream": False, "options": {"temperature": 0.3, "num_predict": 220}}).encode()
try:
    r = urllib.request.urlopen(urllib.request.Request(
        "http://127.0.0.1:11434/api/generate", body,
        {"Content-Type": "application/json"}), timeout=280)
    print(json.loads(r.read()).get("response", "").strip().replace("\n", " ")[:600])
except Exception as e:
    print("(pas de reponse : %s)" % e)
PYEOF
)
  echo "C sage dit: ${R:-rien}"
fi
echo "Z fin cmd-012"
