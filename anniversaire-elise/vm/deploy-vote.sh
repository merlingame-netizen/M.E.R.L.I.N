#!/usr/bin/env bash
# Déploie le serveur de vote sur la VM Oracle ARM A1, avec une URL publique.
#
#   À exécuter SUR LA VM :
#     cd ~/workspace/M.E.R.L.I.N && bash anniversaire-elise/vm/deploy-vote.sh
#
#   [invité] --HTTPS--> Cloudflare --tunnel sortant--> cloudflared (VM)
#                                                          |
#                                            gunicorn 127.0.0.1:8792
#                                                          |
#                                              SQLite /var/lib/anniv-vote
#
# Aucun port entrant ouvert : ni ufw, ni security list OCI, ni Terraform à
# toucher. Contrairement au site statique, la page est ici PUBLIQUE et sans
# mot de passe — c'est le but : les invités votent sans compte.
#
# Idempotent. Le jeton d'administration n'est généré qu'une fois.
set -euo pipefail

PORT=8792
APP_DIR=/opt/anniv-vote
DATA_DIR=/var/lib/anniv-vote
VENV=$APP_DIR/.venv
ENV_FILE=/etc/anniv-vote.env
UNIT=/etc/systemd/system/anniv-vote.service
TUNNEL_UNIT=/etc/systemd/system/anniv-vote-tunnel.service
LOG=/var/log/anniv-vote-tunnel.log

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_USER="$(id -un)"

say(){ printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }
die(){ printf '\n\033[1;31mERREUR: %s\033[0m\n' "$*" >&2; exit 1; }

[ -f "$SRC/app.py" ] || die "app.py introuvable dans $SRC"

# ── 1. Régénérer le template depuis la page source ──────────────────────────
say "Template"
python3 "$SRC/build_template.py" || die "build_template.py a échoué"

# ── 2. Fichiers ─────────────────────────────────────────────────────────────
say "Installation dans $APP_DIR"
sudo mkdir -p "$APP_DIR/templates" "$DATA_DIR"
# valeurs.json est la liste des reponses acceptees, relevee dans la page :
# sans lui le serveur refuse de demarrer, et c'est voulu.
sudo cp "$SRC/app.py" "$SRC/requirements.txt" "$SRC/valeurs.json" "$APP_DIR/"
sudo cp "$SRC/templates/index.html" "$APP_DIR/templates/"
sudo chown -R "$RUN_USER:$RUN_USER" "$APP_DIR" "$DATA_DIR"

# ── 3. Environnement Python ─────────────────────────────────────────────────
say "Environnement Python"
if [ ! -x "$VENV/bin/python" ]; then
  sudo apt-get install -y python3-venv >/dev/null 2>&1 || true
  python3 -m venv "$VENV"
fi
"$VENV/bin/pip" install -q --upgrade pip >/dev/null 2>&1 || true
"$VENV/bin/pip" install -q -r "$APP_DIR/requirements.txt"
echo "    $("$VENV/bin/python" -c 'import flask,sys;print("flask ok, python",sys.version.split()[0])')"

# ── 4. Jeton d'administration (une seule fois) ──────────────────────────────
say "Configuration"
if [ ! -f "$ENV_FILE" ]; then
  TOKEN="$(openssl rand -hex 20 2>/dev/null || head -c 40 /dev/urandom | base64 | tr -dc 'a-f0-9' | head -c 40)"
  printf 'ANNIV_DB=%s/reponses.db\nANNIV_ADMIN_TOKEN=%s\n' "$DATA_DIR" "$TOKEN" \
    | sudo tee "$ENV_FILE" >/dev/null
  sudo chmod 640 "$ENV_FILE"
  sudo chown root:"$RUN_USER" "$ENV_FILE"
  echo "    jeton d'administration généré"
else
  echo "    réutilise $ENV_FILE"
fi
ADMIN_TOKEN="$(sudo sed -n 's/^ANNIV_ADMIN_TOKEN=//p' "$ENV_FILE")"

# ── 5. Service ──────────────────────────────────────────────────────────────
say "Service systemd"
sudo sed -e "s#__USER__#$RUN_USER#g" -e "s#__APP_DIR__#$APP_DIR#g" \
         -e "s#__VENV__#$VENV#g"     -e "s#__DATA_DIR__#$DATA_DIR#g" \
    "$SRC/anniv-vote.service" | sudo tee "$UNIT" >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now anniv-vote.service >/dev/null 2>&1 || true
sudo systemctl restart anniv-vote.service
sleep 3

say "Vérification"
CODE="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" || echo 000)"
HEALTH="$(curl -s "http://127.0.0.1:$PORT/healthz" || echo '{}')"
echo "    page d'accueil : HTTP $CODE"
echo "    santé          : $HEALTH"
[ "$CODE" = "200" ] || die "le service ne répond pas (HTTP $CODE) — sudo journalctl -u anniv-vote -n 40"

ADMIN_CODE="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/admin" || echo 000)"
[ "$ADMIN_CODE" = "403" ] || die "/admin n'est pas protégé (HTTP $ADMIN_CODE) — ne diffuse pas l'URL"
echo "    /admin sans jeton : HTTP 403, correctement protégé"

# ── 6. Tunnel ───────────────────────────────────────────────────────────────
say "Tunnel Cloudflare"
if ! command -v cloudflared >/dev/null 2>&1; then
  sudo mkdir -p --mode=0755 /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
    | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
    | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
  sudo apt-get update -qq && sudo apt-get install -y cloudflared >/dev/null
fi

sudo tee "$TUNNEL_UNIT" >/dev/null <<UNIT
[Unit]
Description=Tunnel Cloudflare — vote anniversaire Elise
After=anniv-vote.service network-online.target
Requires=anniv-vote.service

[Service]
Type=simple
ExecStart=/usr/bin/cloudflared tunnel --no-autoupdate --url http://127.0.0.1:$PORT
Restart=always
RestartSec=10s
StandardOutput=append:$LOG
StandardError=append:$LOG

[Install]
WantedBy=multi-user.target
UNIT

sudo touch "$LOG"; sudo truncate -s 0 "$LOG"
sudo systemctl daemon-reload
sudo systemctl enable --now anniv-vote-tunnel.service >/dev/null 2>&1 || true
sudo systemctl restart anniv-vote-tunnel.service

echo "    attente de l'URL publique…"
URL=""
for _ in $(seq 1 30); do
  sleep 2
  URL="$(sudo grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG" 2>/dev/null | head -1 || true)"
  [ -n "$URL" ] && break
done

# ── 8. Les messages WhatsApp, avec la vraie URL dedans ──────────────────────
if [ -n "$URL" ] && [ -f "$SRC/../whatsapp/build_messages.py" ]; then
  say "Messages WhatsApp"
  python3 "$SRC/../whatsapp/build_messages.py" --url "$URL" || true
fi

cat <<RECAP

╔══════════════════════════════════════════════════════════════════════╗
║  LE SITE EST EN LIGNE                                                ║
╚══════════════════════════════════════════════════════════════════════╝

  URL publique   ${URL:-<voir $LOG>}
  Aucun mot de passe : les invités répondent sans compte, et leurs
  réponses sont gardées sur le serveur — chacun voit les compteurs.

  Le bloc WhatsApp prêt à coller, avec cette URL dedans :
      anniversaire-elise/whatsapp/messages_prets.md
  Les contacts à importer sur iPhone :
      anniversaire-elise/whatsapp/contacts.vcf

  Suivi des réponses (garde ce lien pour toi) :
      ${URL:-<URL>}/admin?token=$ADMIN_TOKEN
  Export CSV :
      ${URL:-<URL>}/admin?token=$ADMIN_TOKEN&format=csv

  ⚠️  L'URL en *.trycloudflare.com change à chaque redémarrage du tunnel.
      Ne redémarre pas le service jusqu'au 15 septembre, ou passe en
      tunnel nommé (voir vm/README.md).

  Les réponses sont dans $DATA_DIR/reponses.db — sauvegarde-le avant tout
  redéploiement. Mettre à jour après modification de la page :
      bash anniversaire-elise/vm/deploy-vote.sh

  État :   systemctl status anniv-vote anniv-vote-tunnel
  Logs :   sudo journalctl -u anniv-vote -f
  Arrêt :  sudo systemctl disable --now anniv-vote anniv-vote-tunnel

RECAP
