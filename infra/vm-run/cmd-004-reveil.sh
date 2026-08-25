#!/usr/bin/env bash
# cmd-004 — identique a cmd-003 (diagnostic du silence + remise en marche).
#
# Rejouee parce que la cle d'origine de l'instance a ete posee dans le secret. Si elle est
# refusee elle aussi, le pont publiera cette fois le TYPE, l'EMPREINTE et la CLE PUBLIQUE
# derivee de ce que contient le secret, plus le dialogue verbeux de sshd : on saura enfin si
# la cle est mal formee, protegee par passphrase, au format PuTTY, ou simplement etrangere a
# cette instance.
set -u

echo "== identite =="
echo "utilisateur=$(whoami) home=$HOME hote=$(hostname) date=$(date -u +%FT%TZ)"

REPO=""
for c in "$HOME/workspace/M.E.R.L.I.N" /var/lib/ocarun/workspace/M.E.R.L.I.N /home/opc/workspace/M.E.R.L.I.N; do
    [ -d "$c/.git" ] && { REPO="$c"; break; }
done
echo "depot outillage : ${REPO:-INTROUVABLE}"
[ -n "$REPO" ] || { echo "KO : rien a piloter"; exit 1; }
GD="$(dirname "$REPO")/merlin-game"

echo "== depuis quand la machine tourne-t-elle ? =="
uptime
echo "demarrage : $(uptime -s 2>/dev/null || echo inconnu)"

echo "== memoire (Mio) =="
free -m | head -2

echo "== le noyau a-t-il tue quelque chose ? =="
{ dmesg -T 2>/dev/null || sudo -n dmesg -T 2>/dev/null || journalctl -k -n 500 --no-pager 2>/dev/null; } \
  | grep -iE "out of memory|oom-kill|killed process" | tail -5
echo "(fin du bloc noyau)"

echo "== LE CRON DES AGENTS EST-IL ENCORE LA ? =="
if [ "$(whoami)" = "ocarun" ]; then CRON="crontab -l"; else CRON="sudo -n -u ocarun crontab -l"; fi
echo "lignes actives : $($CRON 2>/dev/null | grep -cv '^[[:space:]]*#')"
$CRON 2>/dev/null | grep -E 'courrier|tools-autosync|game-autosync|keepalive' | head -5
echo "crond : $(systemctl is-active crond 2>/dev/null || echo illisible) | processus : $(pgrep -c crond 2>/dev/null || echo 0)"

echo "== derniers passages d'agents =="
{ ls -lt /var/lib/ocarun/.cache/merlin-agents 2>/dev/null || sudo -n ls -lt /var/lib/ocarun/.cache/merlin-agents 2>/dev/null; } | head -10

echo "== depot outillage AVANT synchro =="
git -C "$REPO" rev-parse --short HEAD
git -C "$REPO" status --porcelain 2>&1 | head -10

echo "== SYNCHRO DE L'OUTILLAGE =="
if [ "$(whoami)" = "ocarun" ]; then
    bash "$REPO/infra/oracle/agents/agent-run.sh" tools-autosync 2>&1 | tail -8
else
    sudo -n -u ocarun bash "$REPO/infra/oracle/agents/agent-run.sh" tools-autosync 2>&1 | tail -8 \
      || echo "KO : impossible de lancer l'agent sous ocarun"
fi

echo "== depot outillage APRES synchro =="
git -C "$REPO" rev-parse --short HEAD
ls "$REPO"/infra/oracle/agents/courrier/job-066* "$REPO"/infra/oracle/agents/courrier/job-067* 2>/dev/null \
  || echo "KO : jobs 066/067 absents"

echo "== le jeu a-t-il v47 + Bible v2.1 ? =="
if [ -d "$GD/.git" ]; then
    git -C "$GD" fetch origin feat/practices-docs --quiet 2>/dev/null
    echo "local  : $(git -C "$GD" rev-parse --short HEAD 2>/dev/null)"
    echo "origin : $(git -C "$GD" rev-parse --short origin/feat/practices-docs 2>/dev/null || echo '?')"
else
    echo "depot du jeu absent sous $GD"
fi

echo "== REVEIL DU COURRIER (detache) =="
if [ "$(whoami)" = "ocarun" ]; then
    setsid nohup bash "$REPO/infra/oracle/agents/agent-run.sh" courrier > /tmp/courrier-cmd004.log 2>&1 &
else
    sudo -n -u ocarun setsid nohup bash "$REPO/infra/oracle/agents/agent-run.sh" courrier > /tmp/courrier-cmd004.log 2>&1 &
fi
sleep 30
head -20 /tmp/courrier-cmd004.log 2>/dev/null || echo "(rien encore)"
pgrep -fa "a_courrier|job-06|godot" 2>/dev/null | head -4 || echo "(aucun processus)"

echo "== fin cmd-004 =="
