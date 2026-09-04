#!/usr/bin/env bash
# job-096 — LE REGIME EST-IL VRAIMENT APPLIQUE ? On regarde la crontab, pas le manifeste.
#
# `agents.json` est une intention ; la crontab est ce qui reveille vraiment la machine. Entre les
# deux il y a `install-agents.sh`, appele par tools-autosync — et un fichier de surcharges hors
# depot (~/.config/merlin-agent-overrides.json) qui peut ecraser une cadence sans qu'on le voie.
# Ce job lit les trois et dit s'ils s'accordent. Il verifie aussi que les deux agents de nuit sont
# executables et passent leur garde « quelqu'un joue » — le seul chemin qu'on peut essayer de jour
# sans lancer une partie d'une demi-heure.
set -u
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari096-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: s96 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

# La crontab ne se regenere qu'au passage de tools-autosync (4 fois par heure). On attend le sien.
deadline=$(( $(date +%s) + 3000 ))
while ! grep -q "agent-run.sh partie-nuit" <(crontab -l 2>/dev/null); do
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "la crontab n'a pas repris le regime en 50 min — tools-autosync bloque ? sha outillage=$(git -C "$RP" rev-parse --short HEAD 2>/dev/null)"; exit 1; }
    sleep 60
done

OUT="$COURRIER_RES/regime.txt"
{
echo "== SHA DE L'OUTILLAGE SUR LA VM =="
git -C "$RP" rev-parse --short HEAD 2>/dev/null
echo
echo "== LA CRONTAB REELLE, cadence par agent =="
crontab -l 2>/dev/null | grep agent-run.sh | sed 's#.*agent-run.sh ##; s# >>.*##' | paste -d' ' \
  <(crontab -l 2>/dev/null | grep agent-run.sh | awk '{print $1" "$2}') - | sort -k3
echo
echo "== LES SURCHARGES HORS DEPOT (elles gagnent sur le manifeste) =="
cat "$HOME/.config/merlin-agent-overrides.json" 2>/dev/null || echo "  (aucune)"
echo
echo "== ACCORD MANIFESTE <-> CRONTAB =="
python3 - "$RP" <<'PY'
import json, subprocess, sys, os
rp = sys.argv[1]
sys.path.insert(0, os.path.join(rp, "infra/oracle/agents"))
try:
    from overrides import agents as _a; ags = _a()
except Exception:
    ags = json.load(open(os.path.join(rp, "infra/oracle/agents/agents.json")))["agents"]
cron = {}
for l in subprocess.run(["crontab","-l"], capture_output=True, text=True).stdout.splitlines():
    if "agent-run.sh" not in l: continue
    ch = l.split(); cron[l.split("agent-run.sh ")[1].split()[0]] = " ".join(ch[:5])
ecarts = 0
for a in ags:
    if not a.get("enabled"): continue
    s = a.get("schedule",""); 
    if len(s.split()) != 5: continue
    c = cron.get(a["id"])
    if c != s:
        ecarts += 1; print("  ECART %-16s manifeste=%r crontab=%r" % (a["id"], s, c))
print("  %d ecart(s) · %d agents dans la crontab" % (ecarts, len(cron)))
PY
echo
echo "== LES DEUX AGENTS DE NUIT, essayes de jour =="
for ag in a_partie_nuit.sh a_quete_nuit.sh; do
    F="$RP/infra/oracle/agents/$ag"
    printf "  %-20s present=%s executable=%s · " "$ag" "$([ -f "$F" ] && echo oui || echo NON)" "$([ -x "$F" ] && echo oui || echo non)"
    # De jour le jeu peut tourner : la garde doit alors REFUSER proprement, sans rien casser.
    timeout 120 bash "$F" 2>&1 | tail -1
done
echo
echo "== LE RAPPORT DU SMOKE (epreuves incluses ?) =="
python3 -c "
import json
d = json.load(open('$HOME/.cache/merlin-agents/smoke-scenes.json'))
print('  scenes=%s en erreur=%s · epreuves=%s echouees=%s' % (d.get('total'), d.get('failing'),
      [e.get('epreuve')+':'+e.get('etat') for e in d.get('epreuves') or []] or 'PAS ENCORE (smoke pas rejoue depuis le regime)',
      d.get('epreuves_echouees','?')))" 2>/dev/null || echo "  (pas de rapport lisible)"
echo
echo "== CE QUE LA NUIT A DEJA GARDE =="
ls -d "$HOME/.cache/merlin-partie/nuit"/* 2>/dev/null | tail -3 | sed 's/^/  partie : /'
ls -d "$HOME/.cache/merlin-quete/nuit"/* 2>/dev/null | tail -3 | sed 's/^/  quete  : /'
[ -d "$HOME/.cache/merlin-partie/nuit" ] || echo "  (aucune nuit encore — la premiere est cette nuit a 4 h 05)"
} > "$OUT" 2>&1

dire "regime" "$(grep -A3 'ACCORD MANIFESTE' "$OUT" | tail -2 | tr '\n' ' ' | cut -c1-400)"
curl -fsS -m 90 --retry 2 -T "$OUT" -H "Filename: s96_regime.txt" -H "Title: s96 regime" "$NT" >/dev/null 2>&1
echo "job-096 : regime verifie"
