#!/usr/bin/env bash
# cmd-005 — diagnostic du silence + remise en marche (3e tentative de connexion).
#
# Historique des refus, chacun ayant appris quelque chose :
#   cmd-001/002 : cle posee sur `ocarun` — mais ce compte est en /usr/sbin/nologin, il ne
#                 recevra JAMAIS de SSH. Cle intacte, permissions parfaites : mauvaise cible.
#   cmd-003/004 : cle d'origine de l'instance posee dans le secret, refusee aussi — le pont a
#                 dissequee : corps PKCS#1 RSA-2048 complet (25 lignes) mais SANS ses lignes
#                 -----BEGIN/END RSA PRIVATE KEY-----. OpenSSH ne pouvait pas la lire.
# cmd-005 rejoue avec les deux lignes d'encadrement restaurees.
#
# DISCIPLINE DE SORTIE : sortie COMMITEE dans un depot PUBLIC. Que de l'operationnel — jamais
# un fichier d'identifiants, jamais authorized_keys, jamais une variable d'environnement.
set -u

echo "== identite =="
echo "utilisateur=$(whoami) home=$HOME hote=$(hostname) date=$(date -u +%FT%TZ)"

# Le depot vit sous le compte des AGENTS (ocarun, home /var/lib/ocarun), pas sous opc.
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
echo "(fin du bloc noyau — vide = aucune trace)"

echo "== LE CRON DES AGENTS EST-IL ENCORE LA ? (la question qui decide) =="
if [ "$(whoami)" = "ocarun" ]; then CRON="crontab -l"; else CRON="sudo -n -u ocarun crontab -l"; fi
echo "lignes actives : $($CRON 2>/dev/null | grep -cv '^[[:space:]]*#')"
$CRON 2>/dev/null | grep -E 'courrier|tools-autosync|game-autosync|keepalive' | head -5
echo "crond : $(systemctl is-active crond 2>/dev/null || echo illisible) | processus : $(pgrep -c crond 2>/dev/null || echo 0)"

echo "== derniers passages d'agents (dates = quand tout s'est arrete) =="
{ ls -lt /var/lib/ocarun/.cache/merlin-agents 2>/dev/null || sudo -n ls -lt /var/lib/ocarun/.cache/merlin-agents 2>/dev/null; } | head -10

echo "== depot outillage AVANT synchro =="
git -C "$REPO" rev-parse --short HEAD 2>&1
echo "-- arbre sale ? (vide = propre ; un arbre sale FAIT REFUSER l'autosync) --"
git -C "$REPO" status --porcelain 2>&1 | head -10

echo "== SYNCHRO DE L'OUTILLAGE =="
# Sous ocarun : proprietaire du depot et du crontab. Sinon git refuse (dubious ownership) et
# le crontab regenere serait celui du mauvais compte.
if [ "$(whoami)" = "ocarun" ]; then
    bash "$REPO/infra/oracle/agents/agent-run.sh" tools-autosync 2>&1 | tail -8
else
    sudo -n -u ocarun bash "$REPO/infra/oracle/agents/agent-run.sh" tools-autosync 2>&1 | tail -8 \
      || echo "KO : impossible de lancer l'agent sous ocarun (sudo indisponible)"
fi

echo "== depot outillage APRES synchro =="
git -C "$REPO" rev-parse --short HEAD 2>&1
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
# Detache : la partie temoin ne doit pas tenir la session SSH. Verdicts par ntfy comme d'habitude.
if [ "$(whoami)" = "ocarun" ]; then
    setsid nohup bash "$REPO/infra/oracle/agents/agent-run.sh" courrier > /tmp/courrier-cmd005.log 2>&1 &
else
    sudo -n -u ocarun setsid nohup bash "$REPO/infra/oracle/agents/agent-run.sh" courrier > /tmp/courrier-cmd005.log 2>&1 &
fi
sleep 30
echo "-- 30 premieres secondes du Courrier --"
head -20 /tmp/courrier-cmd005.log 2>/dev/null || echo "(rien encore)"
echo "-- processus en vol --"
pgrep -fa "a_courrier|job-06|godot" 2>/dev/null | head -4 || echo "(aucun)"

echo "== fin cmd-005 =="
