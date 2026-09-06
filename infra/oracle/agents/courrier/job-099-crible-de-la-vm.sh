#!/usr/bin/env bash
# job-099 — LE CRIBLE : deux nuits apres le regime, qu'a fait la VM, et qu'est-ce qui cloche ?
#
# Ce job LIT. Il rassemble ce qu'un audit ne peut pas deviner depuis le depot : les nuits gardees
# (partie et quete), le smoke avec ses epreuves, l'etat REEL de chaque agent (derniere course,
# duree, code de retour, resume), les reveils apres le regime, les echecs, les surcharges, le
# corpus, le Studio, la machine. Le parser d'agents lit les vrais champs de agent-run.sh
# (last_run, duration_s, rc, summary) — s95 lisait des cles inventees et ne voyait rien.
set -u
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
PY="$RP/.venv/bin/python"; [ -x "$PY" ] || PY=python3
NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari099-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: s99 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

OUT="$COURRIER_RES/crible.txt"
{
echo "== MACHINE =="
echo "date=$(date -u +%Y-%m-%dT%H:%MZ) coeurs=$(nproc) charge=$(cut -d' ' -f1-3 /proc/loadavg) $(uptime -p 2>/dev/null)"
awk '/MemTotal|MemAvailable|SwapFree/{printf "%s %d Mo  ",$1,$2/1024}' /proc/meminfo; echo
df -h / | awk 'NR>1{printf "disque : %s sur %s (%s)\n",$3,$2,$5}'
echo "modeles ollama charges : $(curl -fsS -m 5 http://127.0.0.1:11434/api/ps 2>/dev/null | python3 -c "import json,sys
try: print(', '.join(m.get('name','?') for m in (json.load(sys.stdin).get('models') or [])) or 'aucun')
except Exception: print('(muet)')")"
echo
echo "== L'ATELIER DE NUIT : ce qui est garde =="
for d in "$HOME/.cache/merlin-partie/nuit"/*/; do
    [ -d "$d" ] || continue
    echo "partie $(basename "$d") : $(python3 -c "
import json,sys
try:
    j=json.load(open('$d/journal.json')); b=j.get('beats') or []
    print('%d beats · fin %s · %d au banc · %d signes' % (len(b),(j.get('fin') or {}).get('type','?'),
      sum(1 for x in b if x.get('provenance')=='secours' or x.get('secours')),
      sum(len(str(x.get('narration',''))+str(x.get('resolution',''))) for x in b)))
except Exception as e: print('journal illisible : %s' % e)")"
    [ -f "$d/verdict.txt" ] && grep -oE "CIBLE[0-9] [a-z]+: [A-Z]+[^C]*" "$d/verdict.txt" | head -3 | sed 's/^/     /'
done
[ -d "$HOME/.cache/merlin-partie/nuit" ] || echo "  AUCUNE partie de nuit gardee"
for d in "$HOME/.cache/merlin-quete/nuit"/*/; do
    [ -d "$d" ] || continue
    echo "quete  $(basename "$d") : $(head -1 "$d/verdict.txt" 2>/dev/null | tr -s ' ') · $(grep -a 'adresse' "$d/grille.txt" 2>/dev/null | head -1 | tr -s ' ')"
    grep -aE "figures|regards|dialogue" "$d/grille.txt" 2>/dev/null | tr -s ' ' | sed 's/^/     /'
done
[ -d "$HOME/.cache/merlin-quete/nuit" ] || echo "  AUCUNE quete de nuit gardee"
echo
echo "== LE SMOKE ET SES EPREUVES (dernier rapport) =="
python3 -c "
import json
d=json.load(open('$HOME/.cache/merlin-agents/smoke-scenes.json'))
print('  %s · commit %s · scenes %s (%s en erreur) · epreuves : %s · echouees=%s' % (d.get('t'), d.get('commit'), d.get('total'), d.get('failing'),
  ', '.join('%s=%s(%s rates)' % (e.get('epreuve'), e.get('etat'), e.get('rates')) for e in d.get('epreuves') or []) or 'ABSENTES', d.get('epreuves_echouees','?')))" 2>/dev/null || echo "  (pas de rapport)"
echo
echo "== CHAQUE AGENT : derniere course, duree, rc, resume =="
python3 - <<'PY'
import json, glob, os, time
base = os.path.expanduser("~/.cache/merlin-agents/state")
rows = []
for f in sorted(glob.glob(base + "/*.run.json")):
    try: d = json.load(open(f))
    except Exception: continue
    rows.append((d.get("id", os.path.basename(f)), str(d.get("last_run",""))[:16], int(d.get("duration_s") or 0),
                 d.get("rc"), str(d.get("summary",""))[:70].replace("\n"," ")))
rows.sort(key=lambda r: r[1], reverse=True)
for r in rows: print("  %-16s %-16s %5ds rc=%-3s %s" % r)
if not rows: print("  (aucun etat)")
PY
echo
echo "== REVEILS PAR AGENT DEPUIS 24 H (apres le regime) et ECHECS =="
tail -n 6000 "$HOME/.cache/merlin-agents/cron.log" 2>/dev/null | grep -oE "^\[[a-z-]+\] rc=[0-9]+" | sort | uniq -c | sort -nr | head -32
echo "-- rc non nuls (24 h) --"
tail -n 6000 "$HOME/.cache/merlin-agents/cron.log" 2>/dev/null | grep -E "rc=[1-9]" | tail -12 | cut -c1-160
echo
echo "== SURCHARGES HORS DEPOT =="
cat "$HOME/.config/merlin-agent-overrides.json" 2>/dev/null || echo "  (aucune)"
echo
echo "== LE CORPUS ET L'ATELIER DE CONTENU =="
for f in auto_corpus.jsonl curated_corpus.jsonl; do C="$RP/data/ai/training/$f"; [ -f "$C" ] && echo "  $f : $(wc -l < "$C") exemples · dernier $(date -r "$C" -u +%m-%dT%H:%M)"; done
echo "  propositions gd-content-gap (48 h) : $(find "$HOME/.cache/merlin-proposals" -name '*gd-content-gap*' -newermt '-48 hours' 2>/dev/null | wc -l)"
echo "  propositions en attente (toutes) : $(ls "$HOME/.cache/merlin-proposals/pending" 2>/dev/null | wc -l) · acceptees : $(ls "$HOME/.cache/merlin-proposals/accepted" 2>/dev/null | wc -l) · refusees : $(ls "$HOME/.cache/merlin-proposals/rejected" 2>/dev/null | wc -l)"
echo
echo "== LE STUDIO =="
set -a; . "$HOME/.config/merlin-studio.env" 2>/dev/null; set +a
echo "  healthz : $(curl -s -m 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:8790/healthz)"
echo "  /api/chroniques : $(curl -s -m 15 -u "merlin:${STUDIO_TOKEN:-}" http://127.0.0.1:8790/api/chroniques | python3 -c "import json,sys
try:
    p=json.load(sys.stdin).get('parties') or []; print('%d parties · %s' % (len(p), ', '.join(x['id'] for x in p[:8])))
except Exception as e: print('illisible', e)")"
echo "  tunnel : $(cat "$HOME/tunnel-url.txt" 2>/dev/null || echo '?')"
echo
echo "== LE JEU =="
echo "  desire=$(cat "$HOME/.cache/merlin-game/desired" 2>/dev/null) harness=$(cat "$HOME/.cache/merlin-game/harness" 2>/dev/null) godot=$(pgrep -c godot 2>/dev/null || echo 0)"
echo "  chroniques du jeu : $(ls "$HOME"/.local/share/godot/app_userdata/MERLIN/chroniques/*.json 2>/dev/null | grep -vc index) fichiers"
echo "  jeu : $(git -C "$HOME/workspace/merlin-game" log -1 --format='%h %s' 2>/dev/null | cut -c1-90)"
echo "  outillage : $(git -C "$RP" log -1 --format='%h %s' 2>/dev/null | cut -c1-90)"
} > "$OUT" 2>&1

dire "crible" "$(sed -n '2,3p' "$OUT" | tr '\n' ' ' | cut -c1-300)"
curl -fsS -m 90 --retry 2 -T "$OUT" -H "Filename: s99_crible.txt" -H "Title: s99 crible" "$NT" >/dev/null 2>&1
echo "job-099 : crible fait ($(wc -l < "$OUT") lignes)"
