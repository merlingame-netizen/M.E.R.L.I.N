#!/usr/bin/env bash
# Notification push téléphone via ntfy.sh — usage : notify.sh <prio> <titre> <message>
# prio : urgent | default | low.  Silencieux (no-op, rc=0) si NTFY_TOPIC absent
# de ~/.config/merlin-game.env : les agents n'échouent JAMAIS à cause d'une notif.
set -uo pipefail
CONF="$HOME/.config/merlin-game.env"
[ -f "$CONF" ] && . "$CONF"
[ -n "${NTFY_TOPIC:-}" ] || exit 0

PRIO="${1:-default}"; TITLE="${2:-MERLIN}"; MSG="${3:-}"
case "$PRIO" in urgent) TAGS="rotating_light" ;; low) TAGS="scroll" ;; *) TAGS="crystal_ball" ;; esac

curl -fsS -m 10 --retry 2 \
    -H "Title: $TITLE" -H "Priority: $PRIO" -H "Tags: $TAGS" \
    -d "$MSG" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1 || true
exit 0
