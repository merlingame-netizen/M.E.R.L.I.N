#!/usr/bin/env bash
# cmd-001 — preuve de vie, diagnostic du silence (depuis 20:45Z le 2026-08-24), et reveil.
#
# DISCIPLINE DE SORTIE : la sortie de cette commande est COMMITEE dans le depot, qui est
# PUBLIC. On n'imprime donc que de l'operationnel — jamais un fichier d'identifiants, jamais
# une variable d'environnement, jamais authorized_keys. Meme regle que la liaison ntfy.
set -u
cd "$HOME/workspace/M.E.R.L.I.N" 2>/dev/null || { echo "KO : depot outillage introuvable"; exit 1; }

echo "== identite =="
echo "utilisateur=$(whoami) hote=$(hostname) date=$(date -u +%FT%TZ)"

echo "== uptime (un redemarrage expliquerait tout le silence) =="
uptime

echo "== memoire (Gio) =="
free -g | head -2

echo "== le noyau a-t-il tue quelque chose ? =="
{ dmesg -T 2>/dev/null || sudo -n dmesg -T 2>/dev/null || journalctl -k -n 400 --no-pager 2>/dev/null; } \
  | grep -iE "out of memory|oom-kill|killed process" | tail -6
echo "(fin du bloc noyau — vide = aucune trace d'OOM lisible)"

echo "== depot outillage AVANT synchro =="
git rev-parse --short HEAD
echo "-- arbre sale ? (vide = propre) --"
git status --porcelain | head -10

echo "== cron : nombre de lignes actives =="
crontab -l 2>/dev/null | grep -c . || echo 0

echo "== derniers marqueurs d'agents =="
ls -t "$HOME/.cache/merlin-agents" 2>/dev/null | head -8

echo "== SYNCHRO DE L'OUTILLAGE =="
bash infra/oracle/agents/agent-run.sh tools-autosync 2>&1 | tail -8

echo "== depot outillage APRES synchro =="
git rev-parse --short HEAD
ls infra/oracle/agents/courrier/job-066* infra/oracle/agents/courrier/job-067* 2>/dev/null \
  || echo "KO : jobs 066/067 absents — la synchro n'a pas pris"

echo "== REVEIL DU COURRIER (detache : job-066 dure ~15-20 min) =="
# Detache expres : la partie temoin ne doit pas tenir la session SSH ouverte. Ses verdicts
# arrivent par ntfy comme d'habitude ; ici on ne garde que le demarrage.
setsid nohup bash infra/oracle/agents/agent-run.sh courrier > /tmp/courrier-cmd001.log 2>&1 &
sleep 25
echo "-- 25 premieres secondes du Courrier --"
head -20 /tmp/courrier-cmd001.log 2>/dev/null || echo "(rien encore)"
pgrep -fa "a_courrier|job-06" | head -3 || echo "(aucun processus courrier visible)"

echo "== fin cmd-001 =="
