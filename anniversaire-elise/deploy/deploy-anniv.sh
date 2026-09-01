#!/usr/bin/env bash
# Déploie le site d'anniversaire d'Elise sur la VM Oracle ARM A1.
#
#   À exécuter SUR LA VM, depuis le dépôt cloné :
#     cd ~/workspace/M.E.R.L.I.N && bash anniversaire-elise/deploy/deploy-anniv.sh
#
# Architecture, alignée sur le reste de la stack MERLIN :
#
#   [invité] --HTTPS--> Cloudflare --tunnel sortant--> cloudflared (VM)
#                                                        |
#                                                        v
#                                          Caddy 127.0.0.1:8791 + basic auth
#                                                        |
#                                                        v
#                                              /opt/anniv-elise/site
#
# Aucun port entrant n'est ouvert : ni dans ufw, ni dans la security list OCI.
# Le tunnel est sortant, ce qui évite de toucher au Terraform.
#
# Idempotent : relançable à volonté. Le mot de passe n'est généré qu'une fois.
set -euo pipefail

PORT=8791
DEST=/opt/anniv-elise
CRED_FILE=/etc/anniv-elise.cred
CADDYFILE=/etc/caddy/Caddyfile.anniv
TUNNEL_UNIT=/etc/systemd/system/anniv-elise-tunnel.service
URL_FILE=/var/lib/anniv-elise/url.txt

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_SRC="$(cd "$SRC_DIR/../site" && pwd)"

say(){ printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }
die(){ printf '\n\033[1;31mERREUR: %s\033[0m\n' "$*" >&2; exit 1; }

[ -f "$SITE_SRC/index.html" ] || die "index.html introuvable dans $SITE_SRC"

# ── 1. Caddy ────────────────────────────────────────────────────────────────
say "Caddy"
if ! command -v caddy >/dev/null 2>&1; then
  echo "    installation depuis le dépôt officiel (arm64 supporté)"
  sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg >/dev/null
  curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
    | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
    | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y caddy >/dev/null
fi
echo "    $(caddy version | head -1)"

# ── 2. cloudflared ──────────────────────────────────────────────────────────
say "cloudflared"
if ! command -v cloudflared >/dev/null 2>&1; then
  echo "    installation depuis le dépôt Cloudflare"
  sudo mkdir -p --mode=0755 /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
    | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
    | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y cloudflared >/dev/null
fi
echo "    $(cloudflared --version 2>&1 | head -1)"

# ── 3. Mot de passe (généré une seule fois, conservé entre les déploiements) ─
say "Identifiants"
if [ ! -f "$CRED_FILE" ]; then
  PASS="$(tr -dc 'a-hjkmnp-z2-9' </dev/urandom | head -c 12)"   # sans 0/O/1/l/i : dictable à voix haute
  HASH="$(caddy hash-password --plaintext "$PASS")"
  printf 'ANNIV_USER=invite\nANNIV_PASS=%s\nANNIV_HASH=%s\n' "$PASS" "$HASH" \
    | sudo tee "$CRED_FILE" >/dev/null
  sudo chmod 600 "$CRED_FILE"
  echo "    mot de passe généré"
else
  echo "    réutilise $CRED_FILE"
fi
# shellcheck disable=SC1090
ANNIV_PASS="$(sudo sed -n 's/^ANNIV_PASS=//p' "$CRED_FILE")"
ANNIV_HASH="$(sudo sed -n 's/^ANNIV_HASH=//p' "$CRED_FILE")"
[ -n "$ANNIV_HASH" ] || die "hash absent de $CRED_FILE — supprime le fichier et relance"

# ── 4. Publication des fichiers ─────────────────────────────────────────────
say "Publication du site"
sudo mkdir -p "$DEST/site" /var/log/caddy /var/lib/anniv-elise

# Le RIB n'est pas dans le dépôt Git : il vit dans deploy/rib.env (gitignoré)
# et n'est injecté dans la page qu'ici, au moment de la publication.
RIB_ENV="$SRC_DIR/rib.env"
if [ -f "$RIB_ENV" ]; then
  # shellcheck disable=SC1090
  . "$RIB_ENV"
  echo "    RIB chargé depuis rib.env (titulaire : ${RIB_TITULAIRE:-?})"
else
  RIB_TITULAIRE="RIB à venir"; RIB_IBAN="communiqué dans le groupe"
  RIB_BIC="—"; RIB_BANQUE="—"
  echo "    ⚠️  rib.env absent — la page affichera « RIB à venir »"
  echo "       cp $SRC_DIR/rib.env.example $SRC_DIR/rib.env puis remplis-le"
fi

# Substitution par python3 plutôt que sed : les valeurs peuvent contenir des
# caractères que sed interpréterait (&, /, accents selon la locale).
RIB_TITULAIRE="$RIB_TITULAIRE" RIB_IBAN="$RIB_IBAN" \
RIB_BIC="$RIB_BIC" RIB_BANQUE="$RIB_BANQUE" \
python3 - "$SITE_SRC/index.html" /tmp/anniv-index.html <<'PYSUB'
import os, sys
src, dst = sys.argv[1], sys.argv[2]
html = open(src, encoding='utf-8').read()
for key in ("RIB_TITULAIRE", "RIB_IBAN", "RIB_BIC", "RIB_BANQUE"):
    html = html.replace(f"__{key}__", os.environ[key])
open(dst, 'w', encoding='utf-8').write(html)
PYSUB

sudo cp /tmp/anniv-index.html "$DEST/site/index.html"
rm -f /tmp/anniv-index.html
[ -f "$SITE_SRC/kit.html" ] && sudo cp "$SITE_SRC/kit.html" "$DEST/site/kit.html"
[ -d "$SITE_SRC/assets" ] && sudo cp -r "$SITE_SRC/assets" "$DEST/site/"
sudo chown -R caddy:caddy "$DEST" /var/log/caddy 2>/dev/null || sudo chown -R root:root "$DEST"
sudo chmod -R a+rX "$DEST"

if sudo grep -q '__RIB_' "$DEST/site/index.html"; then
  die "des placeholders __RIB_*__ subsistent dans la page publiée"
fi
echo "    index.html + kit.html publiés dans $DEST/site"

# ── 5. Configuration Caddy ──────────────────────────────────────────────────
say "Configuration Caddy"
sudo mkdir -p /etc/caddy
# Le hash bcrypt contient des '$' et des '/' : on l'injecte via awk, pas via sed,
# pour ne pas avoir à échapper quoi que ce soit.
sudo awk -v h="$ANNIV_HASH" '{gsub(/__BCRYPT_HASH__/,h); print}' \
  "$SRC_DIR/Caddyfile" | sudo tee "$CADDYFILE" >/dev/null
sudo chmod 640 "$CADDYFILE"

# La directive s'appelle `basic_auth` depuis Caddy 2.8, `basicauth` avant.
# Plutôt que de deviner la version, on valide et on bascule si ça coince.
if ! sudo caddy validate --config "$CADDYFILE" --adapter caddyfile >/dev/null 2>&1; then
  echo "    validation échouée — tentative avec l'ancienne directive basicauth"
  sudo sed -i 's/\bbasic_auth\b/basicauth/' "$CADDYFILE"
  sudo caddy validate --config "$CADDYFILE" --adapter caddyfile >/dev/null 2>&1 \
    || die "Caddyfile invalide. Détail : sudo caddy validate --config $CADDYFILE --adapter caddyfile"
fi
echo "    Caddyfile validé"

# Service caddy dédié, pour ne pas marcher sur une éventuelle conf existante
sudo tee /etc/systemd/system/anniv-elise-web.service >/dev/null <<UNIT
[Unit]
Description=Site anniversaire Elise (Caddy, 127.0.0.1:$PORT)
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/caddy run --environ --config $CADDYFILE --adapter caddyfile
ExecReload=/usr/bin/caddy reload --config $CADDYFILE --adapter caddyfile --force
Restart=on-failure
RestartSec=5s
TimeoutStopSec=15s

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now anniv-elise-web.service >/dev/null 2>&1 || true
sudo systemctl restart anniv-elise-web.service
sleep 2

# ── 6. Vérification locale ──────────────────────────────────────────────────
say "Vérification"
CODE_ANON="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" || echo 000)"
CODE_AUTH="$(curl -s -o /dev/null -w '%{http_code}' -u "invite:$ANNIV_PASS" "http://127.0.0.1:$PORT/" || echo 000)"
echo "    sans identifiants : HTTP $CODE_ANON  (401 attendu)"
echo "    avec identifiants : HTTP $CODE_AUTH  (200 attendu)"
[ "$CODE_ANON" = "401" ] || die "la page n'est pas protégée (HTTP $CODE_ANON) — ne la diffuse pas"
[ "$CODE_AUTH" = "200" ] || die "la page ne répond pas correctement (HTTP $CODE_AUTH)"

# ── 7. Tunnel Cloudflare ────────────────────────────────────────────────────
say "Tunnel Cloudflare"
sudo tee "$TUNNEL_UNIT" >/dev/null <<UNIT
[Unit]
Description=Tunnel Cloudflare — anniversaire Elise
After=anniv-elise-web.service network-online.target
Requires=anniv-elise-web.service

[Service]
Type=simple
ExecStart=/usr/bin/cloudflared tunnel --no-autoupdate --url http://127.0.0.1:$PORT
Restart=always
RestartSec=10s
StandardOutput=append:/var/log/anniv-elise-tunnel.log
StandardError=append:/var/log/anniv-elise-tunnel.log

[Install]
WantedBy=multi-user.target
UNIT

sudo touch /var/log/anniv-elise-tunnel.log
sudo truncate -s 0 /var/log/anniv-elise-tunnel.log
sudo systemctl daemon-reload
sudo systemctl enable --now anniv-elise-tunnel.service >/dev/null 2>&1 || true
sudo systemctl restart anniv-elise-tunnel.service

echo "    attente de l'URL publique…"
PUBLIC_URL=""
for _ in $(seq 1 30); do
  sleep 2
  PUBLIC_URL="$(sudo grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /var/log/anniv-elise-tunnel.log 2>/dev/null | head -1 || true)"
  [ -n "$PUBLIC_URL" ] && break
done

if [ -n "$PUBLIC_URL" ]; then
  echo "$PUBLIC_URL" | sudo tee "$URL_FILE" >/dev/null
else
  echo "    URL non trouvée dans les logs après 60 s."
  echo "    Regarde : sudo tail -40 /var/log/anniv-elise-tunnel.log"
fi

# ── 8. Récapitulatif ────────────────────────────────────────────────────────
cat <<RECAP

╔══════════════════════════════════════════════════════════════════╗
║  SITE EN LIGNE                                                   ║
╚══════════════════════════════════════════════════════════════════╝

  URL         ${PUBLIC_URL:-<voir /var/log/anniv-elise-tunnel.log>}
  Identifiant invite
  Mot de passe $ANNIV_PASS

  Colle ces trois lignes dans le message d'accueil du groupe WhatsApp.

  Kit de copie (pour toi, non listé dans le menu des invités) :
      ${PUBLIC_URL:-<URL>}/kit.html
  Ouvre-le sur ton téléphone : chaque message a un bouton « Envoyer sur
  WhatsApp » qui ouvre l'appli avec le texte déjà écrit.

  ⚠️  L'URL en *.trycloudflare.com est éphémère : elle change à chaque
      redémarrage du tunnel. Pour une URL stable jusqu'au 3 octobre,
      ne redémarre pas le service — ou passe en tunnel nommé (voir
      README.md, section « URL stable »).

  Mettre à jour le site après une modification :
      bash anniversaire-elise/deploy/deploy-anniv.sh

  État des services :
      systemctl status anniv-elise-web anniv-elise-tunnel
      sudo tail -f /var/log/anniv-elise-tunnel.log

  Tout arrêter après la fête :
      sudo systemctl disable --now anniv-elise-web anniv-elise-tunnel

RECAP
