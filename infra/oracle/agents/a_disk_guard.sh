#!/usr/bin/env bash
# Garde-disque : au-delà de 80 % d'occupation, purge ce qui est reconstructible.
# Ne touche JAMAIS aux dépôts, aux sauvegardes de jeu ni aux assets importés.
set -uo pipefail
THRESHOLD=80
PCT="$(df --output=pcent "$HOME" | tail -1 | tr -dc '0-9')"

if [ "$PCT" -lt "$THRESHOLD" ]; then
    echo "disque ${PCT}% — sous le seuil de ${THRESHOLD}%, rien à purger"; exit 0
fi

FREED_BEFORE="$(df --output=avail "$HOME" | tail -1)"
# 1. journaux d'agents et de jeu de plus de 7 jours
find "$HOME/.cache/merlin-agents/logs" -type f -mtime +7 -delete 2>/dev/null
find "$HOME/.cache/merlin-game" -name '*.log' -mtime +7 -delete 2>/dev/null
# 2. journaux du Studio (les jobs gardent leur trace dans le registre)
find "$HOME/workspace/M.E.R.L.I.N/tools/autodev/status/studio_logs" -type f -mtime +14 -delete 2>/dev/null
# 3. RPM déjà extraits dans le sysroot (retéléchargeables)
rm -rf "$HOME/opt/gamestack/rpms" 2>/dev/null
# 4. caches pip/npm
rm -rf "$HOME/.cache/pip" "$HOME/.npm/_cacache" 2>/dev/null

FREED_AFTER="$(df --output=avail "$HOME" | tail -1)"
MB=$(( (FREED_AFTER - FREED_BEFORE) / 1024 ))
NEW_PCT="$(df --output=pcent "$HOME" | tail -1 | tr -dc '0-9')"
echo "disque ${PCT}% -> ${NEW_PCT}% (${MB} Mo libérés)"
