#!/usr/bin/env bash
# LA COMMANDE DE RELANCE — a coller dans une Run Command (console OCI) quand la VM se tait.
#
# POURQUOI ELLE SUFFIT. La boucle autonome n'a jamais eu besoin de SSH :
#   moi -> push sur GitHub (depot PUBLIC, donc tirable sans identifiant)
#       -> tools-autosync tire l'outillage (cron, toutes les 15 min)
#       -> le Courrier execute les jobs (cron, toutes les 2 min)
#       -> les resultats reviennent par ntfy, que je lis
# Le seul maillon casse le 2026-08-24 a 20:45Z, c'est le CRON. Cette commande le remet en
# marche : des lors, la boucle tourne toute seule et je n'ai plus besoin de toi.
#
# SORTIE VOLONTAIREMENT COURTE (lignes A a J) : Run Command tronque l'affichage vers 2 Ko,
# c'est ce qui a fait echouer trois diagnostics d'affilee.

cd ~/workspace/M.E.R.L.I.N || { echo "KO depot introuvable"; exit 1; }
echo "A cron_avant=$(crontab -l 2>/dev/null | grep -cv '^[[:space:]]*#')"
echo "B crond=$(systemctl is-active crond 2>/dev/null || echo illisible)"
echo "C git_avant=$(git rev-parse --short HEAD)"
echo "D fichiers_sales=$(git status --porcelain | wc -l)"
bash infra/oracle/agents/agent-run.sh tools-autosync > /tmp/a.log 2>&1
echo "E sync=$(tail -1 /tmp/a.log | cut -c1-90)"
echo "F git_apres=$(git rev-parse --short HEAD)"
echo "G jobs_0667=$(ls infra/oracle/agents/courrier/job-06[67]* 2>/dev/null | wc -l)"
echo "H cron_apres=$(crontab -l 2>/dev/null | grep -cv '^[[:space:]]*#')"
setsid nohup bash infra/oracle/agents/agent-run.sh courrier > /tmp/c.log 2>&1 &
sleep 20
echo "I courrier=$(head -3 /tmp/c.log | tr '\n' ' ' | cut -c1-110)"
echo "J procs=$(pgrep -c -f 'a_courrier|job-06' 2>/dev/null || echo 0)"
echo "K uptime=$(uptime -p 2>/dev/null | cut -c1-40)"
