#!/usr/bin/env bash
# La VAGUE D'AGENTS — dev testing + perf du modèle, en une passe (Maxime 2026-08-25 :
# « continue avec le dispositif d'agents multiples de dev testing, d'amélioration du
# modèle et de ses performances »). Le Courrier est SÉQUENTIEL : ce job passe après
# job-066 — la vague lit donc une partie p66 fraîche quand elle a pu se jouer.
#
# 1) BANC DE PERF : micro-bench Ollama (tok/s d'évaluation et d'écriture des modèles
#    résidents — le chiffre qui gouverne le chat et le Sage), puis llm-bench et
#    native-bench (agents existants — le moteur du jeu).
# 2) VAGUE DESIGN : gd-audit, gd-balance, gd-pacing, design-council — leurs
#    propositions remontent dans Décider comme d'habitude ; ici on capture leurs sorties.
# 3) 0 € : billing — rc SEUL dans le digest, jamais sa sortie brute (elle peut porter
#    des identifiants ocid, que la liaison montante retiendrait de toute façon).
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari067-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    if curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok"; then
        NT="$base/merlin-courrier-vX9k2Qf7Lw3s"
        break
    fi
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: v67 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

dire "depart" "$(date -u +%H:%M:%SZ) vague : bancs de perf + design + 0EUR"
DIG="$COURRIER_RES/digest67.txt"
: > "$DIG"

# ── micro-bench Ollama : le chiffre le plus utile, en ~1 min ──
python3 - "$OLLAMA" >> "$DIG" 2>&1 <<'PY'
import json, sys, urllib.request
base = sys.argv[1]
try:
    ps = json.load(urllib.request.urlopen(base + "/api/ps", timeout=5)).get("models") or []
except Exception:
    ps = []
modeles = [m.get("name") for m in ps if m.get("name")] or ["gemma4:e4b-it-qat"]
for m in modeles[:2]:
    try:
        req = urllib.request.Request(base + "/api/generate", data=json.dumps({
            "model": m, "prompt": "Broceliande, la nuit. Une phrase.", "stream": False,
            "options": {"num_predict": 48}}).encode(),
            headers={"Content-Type": "application/json"})
        d = json.load(urllib.request.urlopen(req, timeout=300))
        ev = d.get("eval_count", 0); ed = d.get("eval_duration", 1)
        pe = d.get("prompt_eval_count", 0); pd = d.get("prompt_eval_duration", 1)
        print("bench %s : eval %.1f tok/s (%d tok) - ecriture %.1f tok/s (%d tok)" % (
            m, pe / (pd / 1e9 or 1), pe, ev / (ed / 1e9 or 1), ev))
    except Exception as e:
        print("bench %s : KO (%s)" % (m, str(e)[:80]))
PY

# ── les agents, un par un, budget 600 s chacun (cap Courrier : 5400 s au total) ──
for a in llm-bench native-bench gd-audit gd-balance gd-pacing design-council; do
    timeout 600 bash "$AGENTS/agent-run.sh" "$a" > "$COURRIER_RES/$a.log" 2>&1
    rc=$?
    echo "$a rc=$rc : $(tail -c 220 "$COURRIER_RES/$a.log" | tr '\n' ' ')" >> "$DIG"
done

# ── 0 € — rc seul, la sortie brute ne quitte jamais la VM ──
timeout 300 bash "$AGENTS/agent-run.sh" billing > "$COURRIER_RES/billing.log" 2>&1
echo "billing rc=$? (sortie non remontee : peut porter des identifiants)" >> "$DIG"
rm -f "$COURRIER_RES/billing.log"

dire "verdict" "$(head -c 900 "$DIG")"
echo "v67 : vague terminee, digest envoye via $NT"
""
