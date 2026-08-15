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

REF="$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null)"
[ -n "$REF" ] && [ "$REF" != "HEAD" ] || { echo "outillage en HEAD détachée — synchro refusée"; exit 0; }

git -C "$REPO" fetch origin "$REF" --quiet 2>/dev/null || {
    echo "fetch impossible (réseau ?)"; exit 1; }

LOCAL="$(git -C "$REPO" rev-parse HEAD 2>/dev/null)"
REMOTE="$(git -C "$REPO" rev-parse "origin/$REF" 2>/dev/null)"
if [ "$LOCAL" = "$REMOTE" ]; then
    echo "à jour ($REF @ $(git -C "$REPO" rev-parse --short HEAD))"
    exit 0
fi

# Des modifs locales non commitées seraient écrasées par le pull : on préfère RENONCER et le
# dire. Un agent qui détruit du travail humain pour « rester à jour » est pire que pas d'agent.
#
# `core.fileMode=false` n'est PAS une commodité : install-agents.sh fait `chmod +x` sur tous les
# scripts d'agents, git enregistre le bit exécutable, et un script arrivé non exécutable depuis
# GitHub apparaît donc modifié — sans une ligne de différence. Sans cette option, le premier
# agent ajouté rendait la synchro définitivement bloquée, par sa propre installation. (Vécu ici
# même : ce fichier s'est auto-condamné à sa première exécution.) On ne compare que le CONTENU.
if ! git -C "$REPO" -c core.fileMode=false diff --quiet \
		|| ! git -C "$REPO" -c core.fileMode=false diff --cached --quiet; then
    echo "modifs locales non commitées sur $REF — synchro refusée (rien n'est écrasé)"
    exit 1
fi

# `exec` avec un script INLINE : bash lit un fichier au fur et à mesure, et le pull qui suit
# réécrit CE fichier-ci. Poursuivre sa lecture après coup exécuterait un mélange d'ancien et
# de nouveau. On sort donc du fichier avant d'y toucher.
exec /bin/bash -c '
set -uo pipefail
REPO="$1"; REF="$2"; HERE="$3"
git -C "$REPO" pull --ff-only origin "$REF" --quiet 2>&1 | tail -2
NEW="$(git -C "$REPO" rev-parse --short HEAD)"

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
