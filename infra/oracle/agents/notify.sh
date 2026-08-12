#!/usr/bin/env bash
# Notification push téléphone via ntfy.sh
#   usage : notify.sh <prio> <titre> <message> [chemin-ou-url]
# prio : urgent | default | low.  Silencieux (no-op, rc=0) si NTFY_TOPIC absent
# de ~/.config/merlin-game.env : les agents n'échouent JAMAIS à cause d'une notif.
#
# Le 4e paramètre rend la notification CLIQUABLE. On accepte un chemin relatif
# (« ?tab=talk ») : l'URL publique change à chaque redémarrage du tunnel, donc on
# la lit au moment de l'envoi dans ~/tunnel-url.txt plutôt que de la figer.
set -uo pipefail
CONF="$HOME/.config/merlin-game.env"
[ -f "$CONF" ] && . "$CONF"
[ -n "${NTFY_TOPIC:-}" ] || exit 0

PRIO="${1:-default}"; TITLE="${2:-MERLIN}"; MSG="${3:-}"; CIBLE="${4:-}"
case "$PRIO" in urgent) TAGS="rotating_light" ;; low) TAGS="scroll" ;; *) TAGS="crystal_ball" ;; esac

CLICK=""
if [ -n "$CIBLE" ]; then
    case "$CIBLE" in
        http*) CLICK="$CIBLE" ;;
        *)     BASE="$(head -1 "$HOME/tunnel-url.txt" 2>/dev/null | tr -d ' \r\n')"
               [ -n "$BASE" ] && CLICK="${BASE%/}/${CIBLE#/}" ;;
    esac
fi

curl -fsS -m 10 --retry 2 \
    -H "Title: $TITLE" -H "Priority: $PRIO" -H "Tags: $TAGS" \
    ${CLICK:+-H "Click: $CLICK"} \
    -d "$MSG" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1 || true
exit 0
