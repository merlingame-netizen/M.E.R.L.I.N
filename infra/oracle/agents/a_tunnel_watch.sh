#!/usr/bin/env bash
# Veille du tunnel : le portail répond-il, et sous quelle URL publique ?
# L'URL d'un tunnel « quick » change à chaque redémarrage de cloudflared :
# on en garde l'historique pour ne jamais avoir à la chercher.
set -uo pipefail
STATE_DIR="$HOME/.cache/merlin-agents"
URL_HIST="$STATE_DIR/tunnel-history.jsonl"
mkdir -p "$STATE_DIR"

LOCAL_OK=no
curl -fsS -m 5 http://127.0.0.1:8790/healthz >/dev/null 2>&1 && LOCAL_OK=yes

URL="$(cat "$HOME/tunnel-url.txt" 2>/dev/null || echo '')"
PUB_CODE=000
[ -n "$URL" ] && PUB_CODE="$(curl -s -m 10 -o /dev/null -w '%{http_code}' "$URL/healthz" 2>/dev/null || echo 000)"

LAST_URL="$(tail -1 "$URL_HIST" 2>/dev/null | grep -o '"url":"[^"]*"' | cut -d'"' -f4)"
if [ -n "$URL" ] && [ "$URL" != "$LAST_URL" ]; then
    printf '{"t":"%s","url":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$URL" >> "$URL_HIST"
    tail -50 "$URL_HIST" > "$URL_HIST.tmp" && mv "$URL_HIST.tmp" "$URL_HIST"
fi

if [ "$LOCAL_OK" = yes ] && [ "$PUB_CODE" = "200" ]; then
    echo "portail OK · public 200 · $URL"
elif [ "$LOCAL_OK" = yes ]; then
    echo "portail OK en local mais tunnel KO (code $PUB_CODE) · $URL"; exit 1
else
    echo "PORTAIL INJOIGNABLE en local (le keepalive devrait le relancer)"; exit 1
fi
