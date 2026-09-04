#!/usr/bin/env bash
# job-095 — L'ETAT DE LA VM, MESURE ET NON SUPPOSE.
#
# Maxime trouve la VM « trop fournie » et demande ce qu'elle fait en autonomie et ce qu'on peut
# lui demander realistement. La reponse honnete se mesure sur place : quels agents ont vraiment
# tourne ces 24 h, combien de temps, ce que la machine a comme coeurs, memoire, disque, ce qui
# occupe le processeur maintenant, et ce que les caches pesent. Rien n'est modifie : ce job LIT.
set -u
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari095-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: s95 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

OUT="$COURRIER_RES/etat_vm.txt"
{
echo "== MACHINE =="
echo "coeurs=$(nproc) · $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //')"
awk '/MemTotal|MemAvailable|SwapTotal|SwapFree/{printf "%s %d Mo\n",$1,$2/1024}' /proc/meminfo
echo "charge (1,5,15 min) : $(cut -d' ' -f1-3 /proc/loadavg) · $(uptime -p 2>/dev/null)"
df -h "$HOME" / 2>/dev/null | awk 'NR>1{printf "disque %s : %s utilises sur %s (%s)\n",$6,$3,$2,$5}'
echo
echo "== CE QUI OCCUPE LE PROCESSEUR MAINTENANT (top 8) =="
ps -eo pcpu,pmem,rss,etimes,comm,args --sort=-pcpu 2>/dev/null | head -9 | cut -c1-150
echo
echo "== MEMOIRE RESIDENTE PAR FAMILLE (Mo) =="
ps -eo rss,comm 2>/dev/null | awk 'NR>1{r[$2]+=$1} END{for(k in r) if(r[k]>50000) printf "%-24s %6d\n",k,r[k]/1024}' | sort -k2 -nr | head -10
echo
echo "== MODELES CHARGES PAR OLLAMA =="
curl -fsS -m 5 http://127.0.0.1:11434/api/ps 2>/dev/null | python3 -c "import json,sys
try:
    for m in (json.load(sys.stdin).get('models') or []): print('  %s · %.1f Go · expire %s' % (m.get('name'), (m.get('size') or 0)/1e9, m.get('expires_at','?')[:19]))
except Exception as e: print('  (ollama muet)')"
echo
echo "== LA CRONTAB REELLE =="
crontab -l 2>/dev/null | grep -v '^#' | grep -c agent-run.sh | sed 's/^/agents planifies : /'
crontab -l 2>/dev/null | grep -v '^#' | grep -v agent-run.sh | grep -v '^$' | sed 's/^/  hors agents : /'
echo
echo "== LES 24 DERNIERES HEURES, AGENT PAR AGENT (courses, duree totale, dernier rc) =="
python3 - <<'PY'
import json, glob, os, time, collections
now = time.time(); since = now - 86400
runs = collections.defaultdict(lambda: [0, 0.0, None, 0])
base = os.path.expanduser("~/.cache/merlin-agents")
for f in glob.glob(base + "/state/*.run.json") + glob.glob(base + "/state/*.json"):
    try: d = json.load(open(f))
    except Exception: continue
    aid = os.path.basename(f).split(".")[0]
    t = d.get("ended_at") or d.get("started_at") or d.get("ts") or 0
    try: t = float(t)
    except Exception:
        try: t = time.mktime(time.strptime(str(t)[:19], "%Y-%m-%dT%H:%M:%S"))
        except Exception: t = 0
    if t >= since:
        r = runs[aid]; r[0] += 1; r[1] += float(d.get("duration_s") or d.get("duree_s") or 0); r[2] = d.get("rc", d.get("exit"))
# les journaux d'agents, quand l'etat ne suffit pas : nombre de lignes datees d'aujourd'hui
for f in glob.glob(base + "/logs/*.log"):
    aid = os.path.basename(f)[:-4]
    try:
        n = sum(1 for l in open(f, errors="ignore") if l[:10] == time.strftime("%Y-%m-%d"))
    except Exception: n = 0
    runs[aid][3] = n
if not runs: print("  (aucun etat lisible sous ~/.cache/merlin-agents/state ni logs/)")
for aid, (n, dur, rc, nlog) in sorted(runs.items(), key=lambda kv: -kv[1][1]):
    print("  %-18s courses=%-3d duree=%6.0fs dernier_rc=%s lignes_log_aujourdhui=%d" % (aid, n, dur, rc, nlog))
PY
echo
echo "== LE CRON.LOG : qui a tourne le plus (24 h) =="
tail -n 4000 "$HOME/.cache/merlin-agents/cron.log" 2>/dev/null | grep -oE "agent-run.sh [a-z-]+|\[[a-z-]+\]" | sort | uniq -c | sort -nr | head -15
echo
echo "== CE QUE PESENT LES CACHES ET LE TRAVAIL =="
du -sh "$HOME/.cache/merlin-agents" "$HOME/.cache/merlin-game" "$HOME/.cache/merlin-partie" "$HOME/.cache/merlin-quete" "$HOME/.ollama" "$HOME/workspace" "$HOME/logs" 2>/dev/null | sort -hr
echo "chroniques du jeu : $(ls "$HOME"/.local/share/godot/app_userdata/MERLIN/chroniques/*.json 2>/dev/null | grep -vc index)"
echo "resultats du Courrier gardes : $(ls -d "$HOME"/.cache/merlin-agents/courrier/*.res 2>/dev/null | wc -l)"
echo
echo "== CE QUE LE JEU FAIT EN CE MOMENT =="
pgrep -af "godot|xvfb|x11vnc|cloudflared|merlin_studio" 2>/dev/null | cut -c1-120
cat "$HOME/.cache/merlin-game/desired" 2>/dev/null | sed 's/^/etat desire du jeu : /'; echo
} > "$OUT" 2>&1

dire "etat" "$(sed -n '2,6p' "$OUT" | tr '\n' ' ' | cut -c1-600)"
curl -fsS -m 90 --retry 2 -T "$OUT" -H "Filename: s95_etat_vm.txt" -H "Title: s95 etat_vm" "$NT" >/dev/null 2>&1
echo "job-095 : etat mesure ($(wc -l < "$OUT") lignes)"
