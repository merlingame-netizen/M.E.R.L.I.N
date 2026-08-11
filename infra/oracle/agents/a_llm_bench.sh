#!/usr/bin/env bash
# Bench LLM : mesure chaque modèle installé sur la VRAIE tâche (triage d'un log
# d'erreur GDScript) — latence totale + tokens/s — puis fige TRIAGE_MODEL :
# le plus GROS modèle qui répond en moins de 60 s (qualité d'abord, dans le
# budget). Ne réécrit le choix que s'il est encore sur AUTO (respect du manuel).
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

def api(path, payload=None, timeout=180):
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
                "keep_alive": "0", "options": {"num_thread": 4, "num_ctx": 2048}})
        wall = round(time.time() - t0, 1)
        toks = round(d.get("eval_count", 0) / max(d.get("eval_duration", 1) / 1e9, .001), 1)
        rows.append({"model": m, "wall_s": wall, "tok_s": toks,
                     "sample": d.get("response", "")[:160]})
        print(f"  {m}: {wall}s · {toks} tok/s", file=sys.stderr)
    except Exception as e:
        rows.append({"model": m, "error": str(e)[:100]})

json.dump({"t": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "rows": rows},
          open(out, "w"), ensure_ascii=False, indent=1)
# champion triage : le plus lourd sous 60 s de mur (les noms qwen trient par taille)
ok = [r for r in rows if r.get("wall_s", 999) < 60]
ok.sort(key=lambda r: (float((r["model"].split(":")[1] or "0").rstrip("b").split("-")[0] or 0)
                       if ":" in r["model"] and r["model"].split(":")[1][:1].isdigit() else 0))
print(ok[-1]["model"] if ok else "")
PY
CHAMP="$(python3 -c "
import json
r=[x for x in json.load(open('$OUT')).get('rows',[]) if x.get('wall_s',999)<60]
r.sort(key=lambda x:x['wall_s'])
print(r[-1]['model'] if r else '')")"
if [ -n "$CHAMP" ] && grep -q '^export TRIAGE_MODEL=AUTO$' "$CONF"; then
    sed -i "s|^export TRIAGE_MODEL=AUTO$|export TRIAGE_MODEL=$CHAMP|" "$CONF"
    echo "TRIAGE_MODEL figé sur $CHAMP (le plus lent sous 60 s = le plus gros utilisable)"
else
    echo "champion: ${CHAMP:-aucun} · TRIAGE_MODEL actuel conservé"
fi
