#!/usr/bin/env bash
# cmd-013 (pont OCI) — POURQUOI LE SAGE S'EST TU.
#
# cmd-012 a etabli : le Studio est vivant (8790, HTTP 200), le socle du Sage marche (grimoire
# trouve 2 sections de la Bible et les cite), le prompt fait 2604 caracteres, Ollama repond.
# Mais la generation n'a rien rendu du tout — pas meme un message d'erreur, ce qui exclut une
# exception attrapee et pointe vers un process tue ou une reponse vide.
#
# On teste par PALIERS, du plus simple au plus proche du cas reel, en disant le temps de chacun.
# Chaque palier tient sur une ligne : Run Command tronque vers 2 Ko.
set -u
RP="${REPO:-/var/lib/ocarun/workspace/M.E.R.L.I.N}"
[ -d "$RP" ] || RP="$HOME/workspace/M.E.R.L.I.N"
O="http://127.0.0.1:11434"
PY="${RP}/.venv/bin/python"; [ -x "$PY" ] || PY=python3

# A. le modele attendu existe-t-il vraiment ? (cmd-012 ne verifiait que le serveur)
MOD=$(grep -s COPILOT_MODEL "$HOME/.config/merlin-llm.env" 2>/dev/null | cut -d= -f2 | tr -d ' ')
[ -n "${MOD:-}" ] || MOD="gemma4:e4b-it-qat"
DISPO=$(curl -fsS -m 10 "$O/api/tags" 2>/dev/null | "$PY" -c "
import json,sys
try: print(' '.join(m.get('name','') for m in (json.load(sys.stdin).get('models') or [])))
except Exception as e: print('illisible')")
echo "A attendu=$MOD present=$(echo " $DISPO " | grep -qF " $MOD " && echo oui || echo NON)"
echo "A installes=$(echo "$DISPO" | head -c 220)"
echo "A charges=$(curl -fsS -m 10 "$O/api/ps" 2>/dev/null | "$PY" -c "
import json,sys
try: print(','.join(m.get('name','') for m in (json.load(sys.stdin).get('models') or [])) or 'aucun')
except Exception: print('?')")"

# B. palier 1 — generation MINIMALE (prompt court, 20 tokens). Si ceci echoue, rien d'autre ne
#    peut marcher, et la cause est le moteur, pas le prompt du Sage.
t0=$(date +%s)
R1=$(curl -sS -m 300 -w '\nHTTP=%{http_code}' "$O/api/generate" \
     -d "{\"model\":\"$MOD\",\"prompt\":\"Dis bonjour en un mot.\",\"stream\":false,\"options\":{\"num_predict\":20}}" 2>&1 \
     | tr '\n' ' ' | head -c 300)
echo "B court $(( $(date +%s) - t0 ))s :: $R1"

# C. palier 2 — le VRAI prompt du Sage, mais borne court (60 tokens). C'est le palier qui dira
#    si le probleme vient de la LONGUEUR du prompt (2604 car.) plutot que du moteur.
cd "$RP/tools/gd_agents" 2>/dev/null || { echo "C gd_agents introuvable"; echo "Z fin cmd-013"; exit 0; }
t1=$(date +%s)
"$PY" - "$MOD" <<'PYEOF' 2>&1 | head -c 800
import sys, pathlib, json, time, urllib.request, urllib.error
sys.path.insert(0, str(pathlib.Path.cwd()))
import grimoire
model = sys.argv[1]
q = "Quelle est la loi de Broceliande, et qu est-ce qui distingue le Voyageur des autres etres de la foret ?"
pr = grimoire.prompt(q)
body = json.dumps({"model": model, "prompt": pr, "stream": False,
                   "options": {"temperature": 0.3, "num_predict": 60}}).encode()
t = time.time()
try:
    r = urllib.request.urlopen(urllib.request.Request(
        "http://127.0.0.1:11434/api/generate", body,
        {"Content-Type": "application/json"}), timeout=600)
    d = json.loads(r.read())
    rep = (d.get("response") or "").strip().replace("\n", " ")
    print("C long %ds prompt=%dcar rendu=%dcar :: %s" % (time.time() - t, len(pr), len(rep), rep[:420]))
    print("C compteurs eval=%s prompt_eval=%s" % (d.get("eval_count"), d.get("prompt_eval_count")))
except urllib.error.HTTPError as e:
    print("C long %ds ECHEC HTTP %s :: %s" % (time.time() - t, e.code, e.read()[:200]))
except Exception as e:
    print("C long %ds ECHEC %s :: %s" % (time.time() - t, type(e).__name__, e))
PYEOF

echo "D memoire_libre=$(awk '/MemAvailable/ {printf "%.1f", $2/1048576}' /proc/meminfo)Go oom_recent=$(dmesg 2>/dev/null | grep -ci 'out of memory' || echo '?')"
echo "Z fin cmd-013"
