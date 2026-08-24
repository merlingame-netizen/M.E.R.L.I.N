#!/usr/bin/env bash
# Ouvre la porte d'appareil du Studio et remet le lien par canal PRIVE.
# 1) attend le deploiement du patch, 2) genere STUDIO_MAGIC si absente,
# 3) redemarre le Studio (le keepalive le relance dans la minute),
# 4) lit l'URL du tunnel, 5) remet le lien complet par TUYAU (jamais ntfy).
set -u
ENVF="$HOME/.config/merlin-studio.env"
APP="$HOME/workspace/M.E.R.L.I.N/tools/merlin_studio/app.py"
PIPE="https://ppng.io/merlin-porte-vX9k2Qf7Lw3s-r2"
NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: p62 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 2; }

deadline=$(( $(date +%s) + 1800 ))
while ! grep -q "PORTE D'APPAREIL" "$APP" 2>/dev/null; do
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "patch porte jamais deploye"; exit 1; }
    sleep 30
done

# La cle magique : longue, generee UNE fois, gardee dans le fichier d'env du Studio.
if ! grep -q "^STUDIO_MAGIC=" "$ENVF" 2>/dev/null; then
    printf 'STUDIO_MAGIC=%s\n' "$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')" >> "$ENVF"
    chmod 600 "$ENVF"
fi
MAGIC="$(grep '^STUDIO_MAGIC=' "$ENVF" | head -1 | cut -d= -f2-)"

# Redemarrage : le keepalive (cron 1 min) relance le Studio avec le nouvel env.
pkill -u "$(id -un)" -f "merlin_studio/app.py" 2>/dev/null
for _ in $(seq 1 24); do
    sleep 10
    curl -fsS -m 5 http://127.0.0.1:8790/healthz >/dev/null 2>&1 && break
done
SANTE=ko
curl -fsS -m 5 http://127.0.0.1:8790/healthz >/dev/null 2>&1 && SANTE=ok
URL="$(cat "$HOME/tunnel-url.txt" 2>/dev/null || echo '')"
PUB=000
[ -n "$URL" ] && PUB="$(curl -s -m 12 -o /dev/null -w '%{http_code}' "$URL/healthz" 2>/dev/null || echo 000)"

dire "etat" "studio=$SANTE tunnel_public=$PUB magic=$([ -n "$MAGIC" ] && echo posee || echo absente) — lien remis par canal prive"

PAY="$COURRIER_RES/lien.txt"
{
  echo "STUDIO_URL=$URL"
  echo "PORTE=$URL/entrer?cle=$MAGIC"
  echo "studio_local=$SANTE tunnel_public=$PUB"
} > "$PAY"
ok=non
for i in $(seq 1 40); do
    if curl -fsS -m 120 -X POST --data-binary @"$PAY" "$PIPE" >/dev/null 2>&1; then
        ok=oui
        break
    fi
    sleep 30
done
echo "remise_lien=$ok studio=$SANTE tunnel=$PUB"
[ "$ok" = "oui" ]
