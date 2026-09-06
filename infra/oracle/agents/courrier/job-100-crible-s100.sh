#!/usr/bin/env bash
# job-100 — s100 : APPLIQUER le crible du 06/09 sur la VM, puis lire l'etat reel avec le nouvel
# agent a_crible.sh (celui qui tournera chaque matin).
#
# Trois choses qu'un pull ne fait pas tout seul :
#   1. le verrou d'ollama-serve, tenu par un descripteur herite : dire QUI le tient, puis le retirer
#      (rm suffit : agent-run ouvre le verrou PAR CHEMIN, un nouvel inode se verrouille librement) ;
#   2. la surcharge gd-content-gap hors depot : sa cadence vit desormais dans agents.json ;
#   3. la crontab : regeneree tout de suite (tools-autosync l'aurait fait dans le quart d'heure).
# Puis le crible, dont le texte entier part en piece jointe et les premieres lignes en message.
set -u
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
AG="$RP/infra/oracle/agents"
NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari100-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: s100 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

OUT="$COURRIER_RES/s100_application.txt"
{
echo "== 0. L'OUTILLAGE EST-IL A JOUR ? =="
echo "outillage : $(cd "$RP" && git log --oneline -1 | cut -c1-80)"
echo "agent-run ferme le verrou pour l'enfant : $(grep -c '9>&-' "$AG/agent-run.sh") (attendu 1)"
echo "a_crible.sh present : $([ -x "$AG/a_crible.sh" ] && echo oui || echo NON)"
echo
echo "== 1. LE VERROU D'OLLAMA-SERVE =="
L="$HOME/.cache/merlin-agents/ollama-serve.lock"
if [ -f "$L" ]; then
    INO="$(stat -c %i "$L")"
    echo "porteurs : $(for f in /proc/[0-9]*/fd/*; do [ "$(stat -Lc %i "$f" 2>/dev/null)" = "$INO" ] && echo "$(cat "/proc/$(echo "$f" | cut -d/ -f3)/comm" 2>/dev/null)($(echo "$f" | cut -d/ -f3))"; done 2>/dev/null | sort -u | tr '\n' ' ')"
    echo "etat avant : $(cat "$HOME/.cache/merlin-agents/state/ollama-serve.json" 2>/dev/null | cut -c1-160)"
    rm -f "$L" && echo "verrou retire"
else
    echo "pas de fichier de verrou"
fi
echo "derniers [ollama-serve] dans cron.log : $(grep -a 'ollama-serve' "$HOME/.cache/merlin-agents/cron.log" 2>/dev/null | tail -2 | tr '\n' '|' | cut -c1-200)"
echo
echo "== 2. LA SURCHARGE gd-content-gap =="
python3 - <<'PYX'
import json, pathlib
p = pathlib.Path.home() / ".config" / "merlin-agent-overrides.json"
try:
    ov = json.loads(p.read_text(encoding="utf-8"))
except Exception:
    ov = {}
print("avant :", json.dumps(ov, ensure_ascii=False))
if "gd-content-gap" in ov:
    ov.pop("gd-content-gap")
    p.write_text(json.dumps(ov, ensure_ascii=False, indent=1), encoding="utf-8")
    print("retiree — la cadence */30 vit dans agents.json, sous gates.py")
print("apres :", json.dumps(ov, ensure_ascii=False))
PYX
echo
echo "== 3. LA CRONTAB =="
bash "$AG/install-agents.sh" >/dev/null 2>&1 && echo "crontab regeneree" || echo "crontab NON regeneree"
crontab -l 2>/dev/null | grep -E "partie-nuit|quete-nuit|native-bench|gd-content-gap|crible" | sed 's/>>.*//' | sed 's/^/  /'
echo
echo "== 4. LE CRIBLE (a_crible.sh) =="
bash "$AG/agent-run.sh" crible 2>&1 | tail -3
} > "$OUT" 2>&1

C="$(ls -1t "$HOME/.cache/merlin-agents/crible"/*.txt 2>/dev/null | head -1)"
[ -n "$C" ] && cp "$C" "$COURRIER_RES/s100_crible.txt"
dire "application" "$(cat "$OUT")"
[ -n "$C" ] && dire "crible" "$(head -c 3800 "$C")"
echo "s100 : application faite, crible $(basename "${C:-aucun}")"
