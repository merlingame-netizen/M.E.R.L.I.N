#!/usr/bin/env bash
# cmd-003 — pourquoi les agents se sont-ils taus, et remise en marche.
#
# Identique a cmd-002, rejouee avec la cle d'origine de l'instance (compte `opc`) : `ocarun`
# est un compte de SERVICE en /usr/sbin/nologin, il ne pourra JAMAIS recevoir de SSH — sa cle
# etait pourtant intacte et ses permissions parfaites. La cible etait mauvaise, pas la cle.
#
# cmd-001 a etabli que sshd repond : le silence depuis 20:45Z le 2026-08-24 vient de la couche
# AGENTS (cron, Courrier, autosync), pas d'une panne materielle.
#
# DISCIPLINE DE SORTIE : la sortie est COMMITEE dans un depot PUBLIC. Que de l'operationnel —
# jamais un fichier d'identifiants, jamais authorized_keys, jamais une variable d'environnement.
set -u

echo "== identite =="
echo "utilisateur=$(whoami) home=$HOME hote=$(hostname) date=$(date -u +%FT%TZ)"

# Le depot vit sous le compte des AGENTS (ocarun, home /var/lib/ocarun), pas sous opc :
# on le cherche aux deux endroits plutot que de supposer.
REPO=""
for c in "$HOME/workspace/M.E.R.L.I.N" /var/lib/ocarun/workspace/M.E.R.L.I.N /home/opc/workspace/M.E.R.L.I.N; do
    [ -d "$c/.git" ] && { REPO="$c"; break; }
done
echo "depot outillage : ${REPO:-INTROUVABLE}"
[ -n "$REPO" ] || { echo "KO : rien a piloter, on s'arrete la"; exit 1; }
GD="$(dirname "$REPO")/merlin-game"

echo "== depuis quand la machine tourne-t-elle ? =="
uptime
echo "demarrage : $(uptime -s 2>/dev/null || echo inconnu)"

echo "== memoire (Mio) =="
free -m | head -2

echo "== le noyau a-t-il tue quelque chose ? =="
{ dmesg -T 2>/dev/null || sudo -n dmesg -T 2>/dev/null || journalctl -k -n 500 --no-pager 2>/dev/null; } \
  | grep -iE "out of memory|oom-kill|killed process" | tail -5
echo "(fin du bloc noyau — vide = aucune trace)"

echo "== LE CRON DES AGENTS EST-IL ENCORE LA ? (la question qui decide) =="
# Les agents tournent sous ocarun : c'est SON crontab qui compte, pas celui d'opc.
if [ "$(whoami)" = "ocarun" ]; then
    CRON="crontab -l"
else
    CRON="sudo -n -u ocarun crontab -l"
fi
LIGNES="$($CRON 2>/dev/null | grep -cv '^[[:space:]]*#')"
echo "lignes actives dans le crontab d'ocarun : ${LIGNES:-illisible}"
$CRON 2>/dev/null | grep -E 'courrier|tools-autosync|game-autosync|keepalive' | head -5
echo "-- service crond --"
systemctl is-active crond 2>/dev/null || echo "etat crond illisible"
echo "-- processus crond : $(pgrep -c crond 2>/dev/null || echo 0) --"

echo "== quand les agents ont-ils tourne pour la derniere fois ? =="
ls -lt /var/lib/ocarun/.cache/merlin-agents 2>/dev/null | head -10 \
  || sudo -n ls -lt /var/lib/ocarun/.cache/merlin-agents 2>/dev/null | head -10 \
  || echo "cache des agents illisible depuis $(whoami)"

echo "== depot outillage AVANT synchro =="
git -C "$REPO" rev-parse --short HEAD
echo "-- arbre sale ? (vide = propre ; un arbre sale FAIT REFUSER l'autosync) --"
git -C "$REPO" status --porcelain 2>&1 | head -10

echo "== SYNCHRO DE L'OUTILLAGE =="
# L'agent doit tourner SOUS ocarun (proprietaire du depot et du crontab) : sinon git refuse
# le repertoire (dubious ownership) et le crontab regenere serait celui du mauvais compte.
if [ "$(whoami)" = "ocarun" ]; then
    bash "$REPO/infra/oracle/agents/agent-run.sh" tools-autosync 2>&1 | tail -8
else
    sudo -n -u ocarun bash "$REPO/infra/oracle/agents/agent-run.sh" tools-autosync 2>&1 | tail -8 \
      || echo "KO : impossible de lancer l'agent sous ocarun (sudo indisponible)"
fi

echo "== depot outillage APRES synchro =="
git -C "$REPO" rev-parse --short HEAD
ls "$REPO"/infra/oracle/agents/courrier/job-066* "$REPO"/infra/oracle/agents/courrier/job-067* 2>/dev/null \
  || echo "KO : jobs 066/067 absents — la synchro n'a pas pris"

echo "== le jeu a-t-il v47 + Bible v2.1 ? =="
if [ -d "$GD/.git" ]; then
    git -C "$GD" fetch origin feat/practices-docs --quiet 2>/dev/null
    echo "local  : $(git -C "$GD" rev-parse --short HEAD 2>/dev/null)"
    echo "origin : $(git -C "$GD" rev-parse --short origin/feat/practices-docs 2>/dev/null || echo '?')"
else
    echo "depot du jeu absent sous $GD"
fi

echo "== REVEIL DU COURRIER (detache : job-066 dure ~15-20 min) =="
# Detache expres : la partie temoin ne doit pas tenir la session SSH ouverte. Ses verdicts
# arrivent par ntfy comme d'habitude ; ici on ne garde que le demarrage.
if [ "$(whoami)" = "ocarun" ]; then
    setsid nohup bash "$REPO/infra/oracle/agents/agent-run.sh" courrier > /tmp/courrier-cmd003.log 2>&1 &
else
    sudo -n -u ocarun setsid nohup bash "$REPO/infra/oracle/agents/agent-run.sh" courrier > /tmp/courrier-cmd003.log 2>&1 &
fi
sleep 30
echo "-- 30 premieres secondes du Courrier --"
head -20 /tmp/courrier-cmd003.log 2>/dev/null || echo "(rien encore)"
echo "-- processus en vol --"
pgrep -fa "a_courrier|job-06|godot" 2>/dev/null | head -4 || echo "(aucun)"

echo "== fin cmd-003 =="
