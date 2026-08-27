#!/usr/bin/env bash
# cmd-014 (pont OCI) — DEUX CHOSES, une seule Run Command.
#
# A/B. FAIRE DESCENDRE v48.1 SUR LA VM. Les trois moities sont sur feat/practices-docs
#      (commit 9037bc86, run patcheur #39, toutes validations passees). job-069 attend les DEUX
#      marqueurs fonctionnels avant de jouer ; on force l'autosync du jeu et celui de l'outillage,
#      puis on VERIFIE les marqueurs plutot que de les supposer.
#
# C.   POURQUOI LE SAGE REND DU VIDE. cmd-013 a etabli le plus dur : le modele est installe ET
#      charge, il genere bien ses tokens (eval=60), mais le champ `response` revient VIDE avec
#      done_reason=length. Des tokens produits qui n'arrivent pas dans `response`, c'est la
#      signature d'une sortie captee ailleurs — typiquement un bloc de reflexion separe par les
#      versions recentes d'Ollama. On teste donc les deux hypotheses de front : lire le champ
#      `thinking`, et demander explicitement `think: false`.
set -u
RP="${REPO:-/var/lib/ocarun/workspace/M.E.R.L.I.N}"
GD="${GAME_DIR:-/var/lib/ocarun/workspace/merlin-game}"
[ -d "$RP" ] || RP="$HOME/workspace/M.E.R.L.I.N"
[ -d "$GD" ] || GD="$HOME/workspace/merlin-game"
PY="${RP}/.venv/bin/python"; [ -x "$PY" ] || PY=python3

# --- A. l'outillage d'abord (il porte job-069), puis le jeu ---
bash "$RP/infra/oracle/agents/a_tools_autosync.sh" 2>&1 | tail -2
bash "$RP/infra/oracle/agents/a_game_autosync.sh" 2>&1 | tail -2

# --- B. les marqueurs, VERIFIES et pas supposes ---
A=0; B=0; C=0
grep -q "MERLIN_BOT_COUVRANT" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && A=1
grep -q "LE GESTE T'EST DONNE EN FIN DE PROMPT" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && B=1
grep -q '"annulee"' "$GD/scripts/llm/merlin_native.gd" 2>/dev/null && C=1
echo "B jeu=$(git -C "$GD" rev-parse --short HEAD 2>/dev/null) sonde=$A place=$B annulation=$C"
echo "B outillage=$(git -C "$RP" rev-parse --short HEAD 2>/dev/null) job069=$([ -f "$RP/infra/oracle/agents/courrier/job-069-partie-v48-1.sh" ] && echo present || echo ABSENT) deja_fait=$([ -f "$HOME/.cache/merlin-agents/courrier/job-069-partie-v48-1.fait" ] && echo oui || echo non)"

# --- C. le Sage : ou passent les tokens ? ---
cd "$RP/tools/gd_agents" 2>/dev/null || { echo "C gd_agents introuvable"; echo "Z fin cmd-014"; exit 0; }
"$PY" - <<'PYEOF' 2>&1 | head -c 1100
import sys, pathlib, json, urllib.request, urllib.error
sys.path.insert(0, str(pathlib.Path.cwd()))
import grimoire
M = "gemma4:e4b-it-qat"
Q = "Quelle est la loi de Broceliande, et qu est-ce qui distingue le Voyageur des autres etres de la foret ?"

def essai(nom, payload):
    try:
        r = urllib.request.urlopen(urllib.request.Request(
            "http://127.0.0.1:11434/api/generate", json.dumps(payload).encode(),
            {"Content-Type": "application/json"}), timeout=400)
        d = json.loads(r.read())
        rep = (d.get("response") or "").strip().replace("\n", " ")
        pense = (d.get("thinking") or "").strip().replace("\n", " ")
        print("C %s: reponse=%dcar pensee=%dcar eval=%s fin=%s" % (
            nom, len(rep), len(pense), d.get("eval_count"), d.get("done_reason")))
        if rep:
            print("C %s dit: %s" % (nom, rep[:300]))
        elif pense:
            print("C %s pensait: %s" % (nom, pense[:300]))
    except Exception as e:
        print("C %s ECHEC %s: %s" % (nom, type(e).__name__, e))

# 1. le prompt du Sage, en lisant AUSSI le champ « thinking »
essai("sage", {"model": M, "prompt": grimoire.prompt(Q), "stream": False,
               "options": {"temperature": 0.3, "num_predict": 200}})
# 2. le meme, reflexion explicitement coupee
essai("sans-pensee", {"model": M, "prompt": grimoire.prompt(Q), "stream": False, "think": False,
                      "options": {"temperature": 0.3, "num_predict": 200}})
# 3. temoin minimal : si meme celui-ci rend du vide, le probleme n'est pas le prompt du Sage
essai("temoin", {"model": M, "prompt": "Reponds en une phrase : qu est-ce qu une foret ?",
                 "stream": False, "options": {"num_predict": 80}})
PYEOF
echo "Z fin cmd-014"
