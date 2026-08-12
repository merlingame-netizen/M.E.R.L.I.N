#!/usr/bin/env bash
# Bench LLM : mesure chaque modèle installé sur la VRAIE tâche (triage d'un log
# d'erreur GDScript) — génération, lecture de prompt et chargement, séparément —
# puis fige TRIAGE_MODEL sur le plus GROS modèle qui écrit à ≥ 3 tok/s.
# Sortie bornée à 200 tokens : sans cela le modèle discourt et fausse la mesure.
set -uo pipefail
CONF="$HOME/.config/merlin-llm.env"
[ -f "$CONF" ] || { echo "llm non installé"; exit 0; }
. "$CONF"
# PAS llm-bench.json : agent-run écrit son état sous ce nom (collision).
OUT="$HOME/.cache/merlin-agents/llm-bench-results.json"
mkdir -p "$(dirname "$OUT")"

curl -fsS -m 3 "http://$OLLAMA_HOST/api/version" >/dev/null 2>&1 || { echo "serveur ollama mort"; exit 1; }

PROMPT='Voici un extrait de log Godot 4 :
SCRIPT ERROR: Parse Error: Identifier "card_pool" not declared in the current scope.
          at: GDScript::reload (res://scripts/merlin/merlin_card_system.gd:112)
En 2 phrases en français : quel est le bug et où corriger ?'

python3 - "$OLLAMA_HOST" "$PROMPT" "$OUT" <<'PY'
import json, sys, time, urllib.request
host, prompt, out = sys.argv[1:4]

def api(path, payload=None, timeout=420):
    req = urllib.request.Request(f"http://{host}{path}",
        data=json.dumps(payload).encode() if payload else None,
        headers={"content-type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)

models = [m["name"] for m in api("/api/tags")["models"]]
rows = []
for m in models:
    if "embed" in m: continue
    try:
        t0 = time.time()
        d = api("/api/generate", {"model": m, "prompt": prompt, "stream": False,
                "keep_alive": "0", "think": False, "options": {"num_thread": 4, "num_ctx": 2048, "num_predict": 200}})
        wall = round(time.time() - t0, 1)
        toks = round(d.get("eval_count", 0) / max(d.get("eval_duration", 1) / 1e9, .001), 1)
        # Le débit de LECTURE du prompt est distinct de celui de génération et
        # pèse lourd pour un agent qui envoie des preuves : on le mesure aussi.
        p_toks = round(d.get("prompt_eval_count", 0)
                       / max(d.get("prompt_eval_duration", 1) / 1e9, .001), 1)
        load_s = round(d.get("load_duration", 0) / 1e9, 1)
        rows.append({"model": m, "wall_s": wall, "tok_s": toks,
                     "prompt_eval_tok_s": p_toks, "load_s": load_s,
                     "sample": d.get("response", "")[:160]})
        print(f"  {m}: {wall}s · gen {toks} tok/s · prompt {p_toks} tok/s · load {load_s}s",
              file=sys.stderr)
    except Exception as e:
        rows.append({"model": m, "error": str(e)[:100]})

peval = [r["prompt_eval_tok_s"] for r in rows if r.get("prompt_eval_tok_s")]
json.dump({"t": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "rows": rows,
           "prompt_eval_tok_s": round(sum(peval) / len(peval), 1) if peval else None},
          open(out, "w"), ensure_ascii=False, indent=1)
# Champion : le plus gros modèle dont la génération est utilisable (≥ 3 tok/s).
ok = [r for r in rows if r.get("tok_s", 0) >= 3.0]
ok.sort(key=lambda r: (float((r["model"].split(":")[1] or "0").rstrip("b").split("-")[0] or 0)
                       if ":" in r["model"] and r["model"].split(":")[1][:1].isdigit() else 0))
print(ok[-1]["model"] if ok else "")
PY
# Champion = le plus GROS modèle dont la GÉNÉRATION est utilisable (≥ 3 tok/s).
# Le temps de mur est un mauvais critère : il inclut le chargement du modèle
# (87 à 110 s mesurés), qui ne dit rien de la vitesse d'écriture.
# La taille se lit dans le tag ; e2b/e4b comptent pour leur nombre effectif.
CHAMP="$(python3 -c "
import json, re
def size(m):
    g = re.search(r':e?(\d+(?:\.\d+)?)b', m)
    return float(g.group(1)) if g else 0.0
r = [x for x in json.load(open('$OUT')).get('rows', []) if x.get('tok_s', 0) >= 3.0]
r.sort(key=lambda x: size(x['model']))
print(r[-1]['model'] if r else '')")"
if [ -n "$CHAMP" ] && grep -q '^export TRIAGE_MODEL=' "$CONF" \
        && ! grep -q "^export TRIAGE_MODEL=$CHAMP$" "$CONF"; then
    sed -i "s|^export TRIAGE_MODEL=.*$|export TRIAGE_MODEL=$CHAMP|" "$CONF"
    echo "TRIAGE_MODEL figé sur $CHAMP (le plus gros à >= 3 tok/s)"
else
    echo "champion: ${CHAMP:-aucun} · TRIAGE_MODEL inchangé"
fi
