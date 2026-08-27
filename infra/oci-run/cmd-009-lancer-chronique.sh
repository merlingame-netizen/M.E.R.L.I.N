#!/usr/bin/env bash
# cmd-009 (pont OCI) — forcer la chaine pour lancer job-068 (la chronique) sans attendre le cron.
# 1) tools-autosync : tire l'outillage (dont job-068). 2) courrier : execute le prochain job.
# La partie tourne en detache (~20 min) ; ses captures partent sur ntfy quand elle finit.
set -u
R=/var/lib/ocarun/workspace/M.E.R.L.I.N
cd "$R" 2>/dev/null || cd "$HOME/workspace/M.E.R.L.I.N" || { echo "KO depot"; exit 1; }

echo "A avant: outillage=$(git rev-parse --short HEAD)"
bash infra/oracle/agents/agent-run.sh tools-autosync > /tmp/sync9.log 2>&1
echo "B sync: $(tail -1 /tmp/sync9.log | cut -c1-90)"
echo "C apres: outillage=$(git rev-parse --short HEAD)"
echo "D job-068 present ? $(ls infra/oracle/agents/courrier/job-068* 2>/dev/null | wc -l) | deja fait ? $(ls /var/lib/ocarun/.cache/merlin-agents/courrier/job-068*.fait 2>/dev/null | wc -l)"

# Le Courrier prend le prochain job non-fait (job-068). Detache : la partie ne doit pas tenir la session.
setsid nohup bash infra/oracle/agents/agent-run.sh courrier > /tmp/courrier9.log 2>&1 &
sleep 25
echo "E courrier demarre : $(head -3 /tmp/courrier9.log | tr '\n' ' ' | cut -c1-140)"
echo "F en vol : $(pgrep -fa 'a_courrier|job-068|godot|a_partie_journal' 2>/dev/null | head -2 | tr '\n' ' ' | cut -c1-160)"
echo "Z fin cmd-009 (la partie ~20 min ; captures sur ntfy a la fin)"
