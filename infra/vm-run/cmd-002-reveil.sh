#!/usr/bin/env bash
# cmd-002 — pourquoi les agents se sont-ils taus ? (la VM, elle, REPOND : cmd-001 l'a prouve)
#
# cmd-001 a etabli que sshd repond sur 141.253.124.75 : la machine tourne. Le silence depuis
# 20:45Z le 2026-08-24 vient donc de la couche AGENTS (cron, Courrier, autosync), pas d'une
# panne materielle. Cette commande cherche la cause exacte, puis remet la chaine en marche.
#
# DISCIPLINE DE SORTIE : la sortie est COMMITEE dans un depot PUBLIC. Que de l'operationnel —
# jamais un fichier d'identifiants, jamais authorized_keys, jamais une variable d'environnement.
set -u
REPO="$HOME/workspace/M.E.R.L.I.N"
cd "$REPO" 2>/dev/null || { echo "KO : depot outillage introuvable sous $HOME"; exit 1; }

echo "== identite =="
echo "utilisateur=$(whoami) home=$HOME hote=$(hostname) date=$(date -u +%FT%TZ)"

echo "== depuis quand la machine tourne-t-elle ? =="
uptime
echo "demarrage : $(uptime -s 2>/dev/null || echo inconnu)"

echo "== memoire (Mio) =="
free -m | head -2

echo "== le noyau a-t-il tue quelque chose ? =="
{ dmesg -T 2>/dev/null || journalctl -k -n 500 --no-pager 2>/dev/null; } \
  | grep -iE "out of memory|oom-kill|killed process" | tail -6
echo "(fin du bloc noyau — vide = aucune trace lisible depuis ce compte)"

echo "== LE CRON EST-IL ENCORE LA ? (la question qui decide) =="
echo "lignes actives : $(crontab -l 2>/dev/null | grep -cv '^[[:space:]]*#')"
crontab -l 2>/dev/null | grep -E 'courrier|tools-autosync|game-autosync|keepalive' | head -6
echo "-- service cron --"
(systemctl is-active crond 2>/dev/null || systemctl --user is-active crond 2>/dev/null || echo "etat crond illisible depuis ce compte")
pgrep -c crond 2>/dev/null | sed 's/^/processus crond : /' || echo "processus crond : 0"

echo "== quand les agents ont-ils tourne pour la derniere fois ? =="
ls -lt "$HOME/.cache/merlin-agents" 2>/dev/null | head -12

echo "== marqueurs du Courrier (job deja fait = ne rejouera pas) =="
ls -lt "$HOME/.cache/merlin-agents/courrier" 2>/dev/null | head -8

echo "== depot outillage AVANT synchro =="
git rev-parse --short HEAD
echo "-- arbre sale ? (vide = propre ; un arbre sale FAIT REFUSER l'autosync) --"
git status --porcelain | head -12

echo "== SYNCHRO DE L'OUTILLAGE =="
bash infra/oracle/agents/agent-run.sh tools-autosync 2>&1 | tail -10

echo "== depot outillage APRES synchro =="
git rev-parse --short HEAD
ls infra/oracle/agents/courrier/job-066* infra/oracle/agents/courrier/job-067* 2>/dev/null \
  || echo "KO : jobs 066/067 absents — la synchro n'a pas pris"

echo "== le jeu est-il a jour ? (v47 + Bible v2.1) =="
GD="$HOME/workspace/merlin-game"
if [ -d "$GD/.git" ]; then
  git -C "$GD" fetch origin feat/practices-docs --quiet 2>/dev/null
  echo "local  : $(git -C "$GD" rev-parse --short HEAD)"
  echo "origin : $(git -C "$GD" rev-parse --short origin/feat/practices-docs 2>/dev/null || echo '?')"
else
  echo "depot du jeu absent sous $GD"
fi

echo "== REVEIL DU COURRIER (detache : job-066 dure ~15-20 min) =="
# Detache expres : la partie temoin ne doit pas tenir la session SSH ouverte. Ses verdicts
# arrivent par ntfy comme d'habitude ; ici on ne garde que le demarrage.
setsid nohup bash infra/oracle/agents/agent-run.sh courrier > /tmp/courrier-cmd002.log 2>&1 &
sleep 30
echo "-- 30 premieres secondes du Courrier --"
head -25 /tmp/courrier-cmd002.log 2>/dev/null || echo "(rien encore)"
echo "-- processus en vol --"
pgrep -fa "a_courrier|job-06|godot" 2>/dev/null | head -5 || echo "(aucun)"

echo "== fin cmd-002 =="
