#!/usr/bin/env bash
# Remise PRIVÉE de la nouvelle URL du tunnel après reboot (2026-08-21).
# Le keepalive relance Studio + cloudflared tout seul (cron 1 min + @reboot) et écrit
# ~/tunnel-url.txt ; ce job attend que le portail soit SAIN (healthz 200 en local et en
# public) puis remet l'URL par TUYAU une-fois — jamais par ntfy : une URL d'accès n'est
# pas un résultat de jeu. Le poste de pilotage la consomme et la relaie en chat privé.
set -u
PIPE="https://ppng.io/merlin-tunnel-vX9k2Qf7Lw3s-r1"
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
fin=$(( $(date +%s) + 10800 ))
ok=non
while [ "$(date +%s)" -lt "$fin" ]; do
    URL="$(cat "$HOME/tunnel-url.txt" 2>/dev/null || echo '')"
    LOCAL=ko; curl -fsS -m 5 http://127.0.0.1:8790/healthz >/dev/null 2>&1 && LOCAL=ok
    PUB=000
    [ -n "$URL" ] && PUB="$(curl -s -m 10 -o /dev/null -w '%{http_code}' "$URL/healthz" 2>/dev/null || echo 000)"
    if [ "$LOCAL" = ok ] && [ "$PUB" = "200" ] && [ -n "$URL" ]; then
        # signal SANS l'URL sur ntfy (le canal public n'apprend rien d'accès)
        curl -fsS -m 15 -H "Title: p46 portail sain" -d "studio+tunnel OK, remise privee en cours" "$NT" >/dev/null 2>&1 || true
        if curl -fsS -m 120 -X POST --data-binary "URL_TUNNEL=$URL" "$PIPE" >/dev/null 2>&1; then
            ok=oui
            break
        fi
        sleep 30
    else
        sleep 60
    fi
done
echo "remise_url=$ok local=$LOCAL pub=$PUB"
[ "$ok" = "oui" ]
