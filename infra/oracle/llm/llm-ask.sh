#!/usr/bin/env bash
# Interroger le LLM local en une commande : le prompt arrive sur STDIN, la
# réponse sort sur STDOUT (texte brut). Options figées pour l'ARM 4 cœurs.
#   usage : echo "prompt" | llm-ask.sh [--model M] [--timeout S] [--ctx N]
# Sortie vide + rc!=0 si le serveur ou le modèle est indisponible : les
# appelants DOIVENT avoir un repli (jamais bloquer un agent sur le LLM).
set -uo pipefail
CONF="$HOME/.config/merlin-llm.env"
[ -f "$CONF" ] && . "$CONF"
MODEL="${TRIAGE_MODEL:-gemma4:e4b-it-qat}"; [ "$MODEL" = "AUTO" ] && MODEL="${COPILOT_MODEL:-gemma4:e4b-it-qat}"
TIMEOUT=120; CTX="${LLM_NUM_CTX:-2048}"
# Borne DURE de la sortie : sans elle, le modèle discourt jusqu'au timeout —
# c'est ce qui faisait exploser les échéances (mesuré : 700 tokens rendus pour
# 80 demandés). 320 tokens ≈ 33 s à 9,8 tok/s.
PREDICT="${LLM_NUM_PREDICT:-320}"

while [ $# -gt 0 ]; do case "$1" in
    --model)   MODEL="$2";   shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --ctx)     CTX="$2";     shift 2 ;;
    --predict) PREDICT="$2"; shift 2 ;;
    # 0,2 reste le défaut de l'ANALYSE (on veut des chiffres stables). Le
    # journal appelle à 0,75 avec une graine = numéro de chapitre : deux nuits
    # semblables ne produisent pas deux fois la même phrase.
    --temp)    TEMP="$2";    shift 2 ;;
    --seed)    SEED="$2";    shift 2 ;;
    # Contraint Ollama à ne produire QUE du JSON valide. Sans ça, un e4b
    # bavarde autour de son objet, la sortie est tronquée au milieu, et
    # l'appelant lit « JSON illisible » sans savoir pourquoi.
    --json)    FORMAT="json"; shift ;;
    # Parité avec le JEU (merlin_native.gd) : sans ces trois-là, le personnage
    # échantillonnait autrement dans Parler que dans le jeu. Sans défaut ici —
    # aucun autre appelant ne change de comportement.
    --top-p)   TOP_P="$2";   shift 2 ;;
    --top-k)   TOP_K="$2";   shift 2 ;;
    --repeat-penalty) REPEAT="$2"; shift 2 ;;
    # Le prompt part TEL QUEL : c'est à l'appelant d'avoir posé le gabarit de
    # chat. Sans ça Ollama applique le sien par-dessus et le gabarit est doublé.
    --raw)     RAW="1"; shift ;;
    *) echo "option inconnue: $1" >&2; exit 2 ;;
esac; done
export _LLM_TEMP="${TEMP:-0.2}" _LLM_SEED="${SEED:--1}" _LLM_FORMAT="${FORMAT:-}"
export _LLM_TOP_P="${TOP_P:-}" _LLM_TOP_K="${TOP_K:-}" _LLM_REPEAT="${REPEAT:-}" _LLM_RAW="${RAW:-}"

PROMPT="$(cat)"
[ -n "$PROMPT" ] || { echo "prompt vide" >&2; exit 2; }

export _LLM_PROMPT="$PROMPT" _LLM_PREDICT="$PREDICT"
python3 - "$MODEL" "$TIMEOUT" "$CTX" <<'PY'
import json, os, sys, urllib.request
model, timeout, ctx = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
prompt = os.environ["_LLM_PROMPT"]
host = os.environ.get("OLLAMA_HOST", "127.0.0.1:11434")
req = urllib.request.Request(
    f"http://{host}/api/generate",
    data=json.dumps({
        "model": model, "prompt": prompt, "stream": False,
        "keep_alive": os.environ.get("OLLAMA_KEEP_ALIVE", "30m"),
        # Gemma 4 RAISONNE avant de répondre. Sans think=false, le budget de
        # tokens part entièrement en réflexion interne et le champ `response`
        # revient VIDE (mesuré : eval_count=50, réponse 0 caractère) — cause
        # réelle de tous les « modèle indisponible » du chat et des agents.
        "think": False,
        # `format: "json"` force une sortie JSON valide côté Ollama : c'est le
        # remède au « JSON illisible » qui a rempli Décider.
        **({"format": os.environ["_LLM_FORMAT"]} if os.environ.get("_LLM_FORMAT") else {}),
        # `raw` : le prompt porte déjà son gabarit de chat (parité avec le jeu).
        **({"raw": True} if os.environ.get("_LLM_RAW") else {}),
        # num_thread vient du routeur : 2 quand le jeu tourne (il garde 2 cœurs).
        "options": {"num_thread": int(os.environ.get("OLLAMA_NUM_THREAD", "4")),
                    "num_ctx": ctx,
                    "temperature": float(os.environ.get("_LLM_TEMP", "0.2")),
                    "seed": int(os.environ.get("_LLM_SEED", "-1")),
                    "num_predict": int(os.environ.get("_LLM_PREDICT", "320")),
                    # Absents par défaut : Ollama garde alors les valeurs du
                    # modèle, comme avant. Seul l'appelant qui les demande change.
                    **({"top_p": float(os.environ["_LLM_TOP_P"])} if os.environ.get("_LLM_TOP_P") else {}),
                    **({"top_k": int(os.environ["_LLM_TOP_K"])} if os.environ.get("_LLM_TOP_K") else {}),
                    **({"repeat_penalty": float(os.environ["_LLM_REPEAT"])} if os.environ.get("_LLM_REPEAT") else {})},
    }).encode(),
    headers={"content-type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=timeout) as r:
        d = json.load(r)
    rep = (d.get("response") or "").strip()
    if not rep:
        # Une réponse vide n'est PAS un succès. Rendre rc=0 avec zéro caractère
        # a rempli le journal de « LLM indisponible — rc=0 » sans jamais dire
        # pourquoi. On remonte le vrai motif : le modèle a-t-il été coupé par
        # le budget de tokens (done_reason=length), a-t-il tout mis dans sa
        # réflexion interne, ou n'a-t-il rien produit du tout ?
        print(f"reponse vide (fin={d.get('done_reason')}, "
              f"tokens={d.get('eval_count')}, "
              f"reflexion={len(d.get('thinking') or '')} car)", file=sys.stderr)
        sys.exit(3)
    print(rep)
except SystemExit:
    raise
except Exception as e:
    print(f"llm indisponible: {e}", file=sys.stderr); sys.exit(1)
PY
