#!/usr/bin/env bash
# OÙ PASSENT LES SECONDES — décompose le coût d'une sélection, et confronte le moteur du jeu
# à Ollama SUR LE MÊME PROMPT.
#
# POURQUOI. Une sélection prend 112 s dans le jeu contre 31 s sans rien dessiner, et le seul
# chiffre disponible était un total. Deux questions restaient sans réponse :
#   1. quelle part va à l'évaluation du PROMPT, quelle part à l'écriture ?
#   2. pourquoi le moteur du jeu tient 4,3 tok/s là où Ollama en fait 8,6 ?
#
# Sur la seconde, un fait établi le 2026-08-18 change tout : le GGUF du jeu est un LIEN
# SYMBOLIQUE vers le blob d'Ollama. Mêmes poids, même quantification Q4_0, même machine. Le
# modèle est donc hors de cause, et l'écart est forcément dans la construction ou le réglage de
# notre llama.cpp. Encore faut-il comparer sur la MÊME tâche : d'où le prompt déposé par la
# sonde et rejoué tel quel ici. Comparer deux prompts différents n'aurait rien prouvé.
#
# Ollama, lui, rend `prompt_eval_duration` et `eval_duration` exacts : c'est notre étalon.
#
# `pipefail` : sans lui, `X="$(… | grep …)"` suivi de `RC=$?` lit le code de grep, pas celui
# de Godot — piège déjà rencontré sur a_playtest_bot.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

# `etape` est fournie par agent-run.sh. Lancé À LA MAIN — ce qu'on fait forcément pour
# diagnostiquer — l'agent mourrait sinon sur « command not found ».
type -t etape >/dev/null 2>&1 || etape() { :; }

GODOT_BIN="${GODOT_BIN:-$HOME/bin/godot}"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
OUT="$HOME/.cache/merlin-agents/llm-decompose.json"
TMP="$HOME/.cache/merlin-agents/decompose"
BIOME="${MERLIN_DECOMP_BIOME:-foret}"
mkdir -p "$(dirname "$OUT")" "$TMP"

# Jamais pendant que Maxime joue : on lui volerait le CPU, ET la mesure serait fausse.
if bash "$HERE/../game/game-stack.sh" status 2>/dev/null | grep -q '"vnc_open":true'; then
    echo "jeu en cours d'utilisation — mesure reportée"; exit 0
fi

PROBE="$GAME_DIR/tools/probe_llm_decompose.gd"
[ -f "$PROBE" ] || { echo "sonde absente — la branche du jeu n'est pas à jour"; exit 0; }

etape 1 4 "décharger Ollama"
# La RAM ET les cœurs doivent revenir au jeu : un modèle résident double le temps de génération
# (mesuré 31,5 s contre 63,2 s le 2026-08-18). Le mesurer avec Ollama chaud reviendrait à
# mesurer autre chose que ce que vit le joueur quand la machine lui appartient.
for m in $(curl -fsS -m 5 "$OLLAMA/api/ps" | python3 -c "
import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "$OLLAMA/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done

etape 2 4 "moteur du jeu (jusqu'à 20 min)"
LOG="$(MERLIN_DECOMP_BIOME="$BIOME" MERLIN_DECOMP_OUT="$TMP" MERLIN_ALLOW_HEADLESS_LLM=1 \
       timeout 1500 nice -n 10 "$GODOT_BIN" \
       --headless --path "$GAME_DIR" --script res://tools/probe_llm_decompose.gd 2>&1)"
RC=$?
JSON="$(printf '%s\n' "$LOG" | grep -m1 '^\[DECOMP_JSON\] ' | cut -d' ' -f2-)"
if [ -z "$JSON" ]; then
    printf '{"t":"%s","ok":false,"etape":"aucune mesure (code %s)"}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$RC" > "$OUT"
    echo "aucune mesure — code $RC · dernières lignes :"
    printf '%s\n' "$LOG" | tail -8
    exit 1
fi

etape 3 4 "étalon Ollama sur le MÊME prompt"
# `raw: false` + `system` : on laisse Ollama appliquer son gabarit de conversation, comme le
# jeu applique le sien. Comparer un prompt gabarité à un prompt brut fausserait le compte de
# tokens du prompt — précisément la grandeur qu'on cherche à comparer.
OLL="$(python3 - "$TMP" "$OLLAMA" <<'PY'
import json, sys, urllib.request, pathlib
tmp, base = pathlib.Path(sys.argv[1]), sys.argv[2]
try:
    sys_txt = (tmp / "prompt_system.txt").read_text(encoding="utf-8")
    usr_txt = (tmp / "prompt_user.txt").read_text(encoding="utf-8")
except OSError as e:
    print(json.dumps({"ok": False, "motif": "prompt non depose : %s" % e})); raise SystemExit
corps = json.dumps({
    "model": "gemma4:e4b-it-qat", "system": sys_txt, "prompt": usr_txt,
    "stream": False, "keep_alive": 0,
    "options": {"num_predict": 160, "temperature": 0.7, "top_p": 0.9},
}).encode()
try:
    r = urllib.request.Request(base + "/api/generate", data=corps,
                               headers={"Content-Type": "application/json"})
    d = json.load(urllib.request.urlopen(r, timeout=600))
except Exception as e:
    print(json.dumps({"ok": False, "motif": "%s: %s" % (type(e).__name__, e)})); raise SystemExit
# Ollama compte en NANOsecondes.
pe, ev = d.get("prompt_eval_duration", 0) / 1e6, d.get("eval_duration", 0) / 1e6
npe, nev = d.get("prompt_eval_count", 0), d.get("eval_count", 0)
print(json.dumps({
    "ok": True, "prompt_ms": round(pe, 1), "prompt_tokens": npe,
    "ecriture_ms": round(ev, 1), "tokens_ecrits": nev,
    "total_ms": round(d.get("total_duration", 0) / 1e6, 1),
    "prompt_tok_s": round(npe * 1000.0 / pe, 2) if pe else 0,
    "ecriture_tok_s": round(nev * 1000.0 / ev, 2) if ev else 0,
    "extrait": (d.get("response") or "")[:160],
}, ensure_ascii=False))
PY
)"

etape 4 4 "lecture"
python3 - "$JSON" "$OLL" "$OUT" "$(git -C "$GAME_DIR" rev-parse --short HEAD 2>/dev/null || echo '?')" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
try:
    d["ollama"] = json.loads(sys.argv[2])
except Exception:
    d["ollama"] = {"ok": False, "motif": "etalon illisible"}
d["commit"] = sys.argv[4]
json.dump(d, open(sys.argv[3], "w"), ensure_ascii=False, indent=1)

l = d.get("lecture") or {}
lignes = []
if "part_prompt_pct" in l:
    lignes.append("prompt+fixe %.1f s (%d %%) · ecriture %.1f s"
                  % (l["prompt_et_fixe_ms"] / 1000, l["part_prompt_pct"], l["ecriture_ms"] / 1000))
if "surcout_blocs_ms" in l:
    lignes.append("blocs biome+anti-repetition : %+.1f s" % (l["surcout_blocs_ms"] / 1000))
o = d["ollama"]
if o.get("ok"):
    lignes.append("Ollama meme prompt : prompt %.1f s / %d tok · ecriture %.1f s / %d tok (%.2f tok/s)"
                  % (o["prompt_ms"] / 1000, o["prompt_tokens"],
                     o["ecriture_ms"] / 1000, o["tokens_ecrits"], o["ecriture_tok_s"]))
else:
    lignes.append("etalon Ollama indisponible : %s" % o.get("motif", "?"))
print(" · ".join(lignes) if lignes else "mesure ecrite")
PY
