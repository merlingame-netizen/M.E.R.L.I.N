#!/usr/bin/env bash
# Synchro de l'OUTILLAGE (ce dépôt) — le pendant de a_game_autosync.sh pour le jeu.
#
# POURQUOI. Le jeu se met à jour tout seul depuis des mois (webhook + game-autosync toutes
# les 15 min, avec CI derrière). L'outillage, LUI, n'avait AUCUN mécanisme : il ne bougeait
# que si quelqu'un tirait à la main. Or c'est lui qui porte le portail, les sondes et les
# agents — y compris cette boucle-ci. Résultat vécu le 2026-08-15 : un agent de mesure
# poussé sur GitHub restait absent de la VM, et le portail affichait une tuile qui n'existait
# pas encore côté serveur. La règle posée par Maxime — « la version à jour, c'est toujours
# celle de la VM » — ne peut pas tenir tant que la moitié du système attend un geste humain.
#
# La branche suivie n'est PAS codée en dur : on lit celle qui est sortie dans le dépôt. La VM
# suit une branche de travail, elle changera, et un nom figé ici ferait échouer la synchro en
# silence le jour où elle bougera.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${MERLIN_REPO:-$HOME/workspace/M.E.R.L.I.N}"

[ -d "$REPO/.git" ] || { echo "outillage pas un dépôt git — rien à faire"; exit 0; }

# 2026-08-25 — UNE PANNE MUETTE DE CETTE BOUCLE COUPE LE SEUL CANAL VERS LA VM. Un job pousse
# sur GitHub, la VM ne le tire jamais, et le poste de pilotage attend un verdict qui ne viendra
# pas (job-066 : une heure et quart d'attente pour rien). Toute sortie anormale SONNE desormais
# sur le telephone. Raison seule, jamais de chemin ni de configuration : c'est une alerte, pas
# un journal.
sonner() { bash "$HERE/notify.sh" urgent "Outillage bloqué" "$1 — la VM ne recevra plus rien tant que ce n'est pas leve." >/dev/null 2>&1 || true; }

# 2026-08-25, LA CAUSE DES 24 HEURES DE SILENCE. Le poste de pilotage pousse par l'API GitHub,
# qui écrit les fichiers en mode 644 ; install-agents.sh les avait passés en 755 sur la VM.
# Git voit ce seul écart de mode comme une modification locale et `git pull` REFUSE de tirer :
#
#   error: Your local changes to the following files would be overwritten by merge:
#           infra/oracle/agents/a_courrier.sh
#
# Le garde-fou ci-dessous comparait déjà le CONTENU seul (-c core.fileMode=false), mais le pull
# lui-même, non : il échouait donc à chaque passage, et son échec était avalé par `| tail -2`.
# On grave le réglage DANS le dépôt : plus aucune commande git de cette machine ne verra les
# bits d'exécution, y compris un `git pull` lancé à la main par Maxime.
git -C "$REPO" config core.fileMode false 2>/dev/null || true

REF="$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null)"
[ -n "$REF" ] && [ "$REF" != "HEAD" ] || { echo "outillage en HEAD détachée — synchro refusée"; sonner "HEAD detachee"; exit 0; }

git -C "$REPO" fetch origin "$REF" --quiet 2>/dev/null || {
    echo "fetch impossible (réseau ?)"; sonner "fetch impossible"; exit 1; }

LOCAL="$(git -C "$REPO" rev-parse HEAD 2>/dev/null)"
REMOTE="$(git -C "$REPO" rev-parse "origin/$REF" 2>/dev/null)"
if [ "$LOCAL" = "$REMOTE" ]; then
    echo "à jour ($REF @ $(git -C "$REPO" rev-parse --short HEAD))"
    exit 0
fi

# Des modifs locales non commitées seraient écrasées par le pull : on préfère RENONCER et le
# dire. Un agent qui détruit du travail humain pour « rester à jour » est pire que pas d'agent.
# (Le mode des fichiers ne compte pas : cf. core.fileMode posé plus haut.)
if ! git -C "$REPO" diff --quiet || ! git -C "$REPO" diff --cached --quiet; then
    echo "modifs locales non commitées sur $REF — synchro refusée (rien n'est écrasé)"
    sonner "modifs locales non commitees"
    exit 1
fi

# `exec` avec un script INLINE : bash lit un fichier au fur et à mesure, et le pull qui suit
# réécrit CE fichier-ci. Poursuivre sa lecture après coup exécuterait un mélange d'ancien et
# de nouveau. On sort donc du fichier avant d'y toucher.
exec /bin/bash -c '
set -uo pipefail
REPO="$1"; REF="$2"; HERE="$3"
AVANT="$(git -C "$REPO" rev-parse HEAD)"
ERR="$(git -C "$REPO" pull --ff-only origin "$REF" --quiet 2>&1 | tail -3)"
NEW="$(git -C "$REPO" rev-parse --short HEAD)"
# `| tail` avale le code de retour du pull : sans cette verification, un pull refuse laissait
# annoncer « mis a jour » avec le sha PRECEDENT, et la panne restait invisible pour toujours.
# On imprime desormais AUSSI ce que git a dit : le 2026-08-25, ce message aurait nomme la
# cause (ecart de mode 644/755) au lieu de nous couter vingt-quatre heures.
if [ "$AVANT" = "$(git -C "$REPO" rev-parse HEAD)" ]; then
    echo "pull SANS EFFET — le depot n a pas bouge (reste a $NEW)"
    [ -n "$ERR" ] && echo "git a dit : $ERR"
    bash "$HERE/notify.sh" urgent "Outillage bloque" "pull sans effet — la VM ne recevra plus rien tant que ce n est pas leve." >/dev/null 2>&1 || true
    exit 1
fi

# Le crontab est GÉNÉRÉ depuis agents.json : sans ce rappel, un agent ajouté ou re-planifié
# sur GitHub ne serait jamais programmé sur la VM.
bash "$HERE/install-agents.sh" >/dev/null 2>&1 && CRON="crontab régénéré" || CRON="crontab NON régénéré"

# Le Studio (Flask) garde son code en mémoire : sans redémarrage, un probes.py ou un
# app.py fraîchement tiré ne sert à rien. Le keepalive (cron, chaque minute) le relève seul —
# on ne le relance donc pas nous-mêmes, on le laisse simplement mourir.
#
# `[a]pp` et non `app` : ce bloc tourne via `bash -c`, donc LE TEXTE DU SCRIPT EST SA PROPRE
# LIGNE DE COMMANDE. Un motif écrit en clair se trouve lui-même, et pkill tue le shell qui
# l appelle — mesuré ici : rc=143 (SIGTERM), tout le travail fait mais la derniere ligne jamais
# atteinte, donc un agent qui reussit en se signalant en echec. Les crochets cassent
# l auto-correspondance sans changer ce qui est matche ailleurs.
pkill -u "$(id -un)" -f "merlin_studio/[a]pp.py" >/dev/null 2>&1 && STUDIO="Studio relancé" || STUDIO="Studio non actif"

echo "outillage mis à jour -> $NEW · $CRON · $STUDIO"
' _ "$REPO" "$REF" "$HERE"
