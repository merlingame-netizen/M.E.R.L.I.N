#!/usr/bin/env bash
# Déploie l'invitation en Worker + assets + base D1, et propage le lien.
#
#     bash anniversaire-elise/cloudflare/deploy-worker.sh
#
# C'est la suite du dépôt manuel fait dans le tableau de bord : celui-ci a créé
# un Worker « assets seuls », qui sert la page mais n'a aucun code, donc aucune
# réponse ne peut lui parvenir. Ce script y ajoute le code et la base.
#
# Idempotent : relancer met la page à jour sans toucher aux réponses.
set -euo pipefail

ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$ICI/wrangler.worker.toml"
PROJET=anniv-elise
W="npx --yes wrangler@latest"

say(){ printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }
die(){ printf '\n\033[1;31mERREUR: %s\033[0m\n' "$*" >&2; exit 1; }

command -v npx >/dev/null || die "npx introuvable — installe Node.js (nodejs.org)"

say "Construction de la page"
python3 "$ICI/build.py" || die "build.py a échoué"

say "Compte Cloudflare"
if ! $W whoami >/dev/null 2>&1; then
  echo "    Une fenêtre va s'ouvrir pour autoriser wrangler."
  $W login || die "connexion refusée"
fi
$W whoami | sed 's/^/    /'

say "Base de données D1"
if grep -q '__A_REMPLIR__' "$CONF"; then
  SORTIE="$($W d1 create "$PROJET" 2>&1 || true)"
  ID="$(printf '%s' "$SORTIE" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)"
  [ -n "$ID" ] || { printf '%s\n' "$SORTIE"; die "identifiant de base introuvable. Si la base existe déjà, récupère son id avec '$W d1 list' et colle-le dans wrangler.worker.toml"; }
  # sed -i diffère entre GNU et BSD : on passe par un fichier temporaire.
  sed "s/__A_REMPLIR__/$ID/" "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
  echo "    base créée : $ID"
else
  echo "    déjà déclarée dans wrangler.worker.toml"
fi

say "Schéma"
$W d1 execute "$PROJET" --remote -c "$CONF" --file "$ICI/schema.sql" \
  || die "le schéma n'a pas pu être appliqué"

say "Jeton d'administration"
JETON_FICHIER="$ICI/.admin-token"
if [ ! -f "$JETON_FICHIER" ]; then
  head -c 18 /dev/urandom | base64 | tr -d '/+=' > "$JETON_FICHIER"
  chmod 600 "$JETON_FICHIER"
fi
JETON="$(cat "$JETON_FICHIER")"

say "Publication"
$W deploy -c "$CONF" | tee /tmp/anniv-worker.log
URL="$(grep -oE 'https://[a-z0-9.-]+\.workers\.dev' /tmp/anniv-worker.log | tail -1 || true)"
[ -n "$URL" ] || die "URL introuvable dans la sortie — regarde /tmp/anniv-worker.log"

say "Secret"
printf '%s' "$JETON" | $W secret put ADMIN_TOKEN -c "$CONF" >/dev/null 2>&1 \
  || echo "    (à poser à la main : $W secret put ADMIN_TOKEN -c $CONF)"

# Cette vérification n'est pas une politesse. Un binding qui ne monte pas ne
# se voit ni au build ni au déploiement : la page s'affiche, et c'est la
# première réponse d'un invité qui part en 500 sur env.DB undefined.
say "Vérification"
SANTE="$(curl -fsS --max-time 25 "$URL/api/etat" || true)"
if [ -z "$SANTE" ]; then
  curl -sS --max-time 25 "$URL/api/etat" | head -5 | sed 's/^/    /' || true
  die "l'API ne répond pas. Si l'erreur parle de 'prepare' ou de 'undefined',
    c'est le binding D1 : tableau de bord → Workers → $PROJET → Liaisons,
    et déclare D1 'DB' sur la base '$PROJET'. Sinon réessaie dans une
    minute : $URL/api/etat"
fi
echo "    $SANTE"

say "Propagation du lien dans les messages"
python3 "$ICI/../whatsapp/set_url.py" "$URL" | sed 's/^/    /' \
  || die "le lien n'a pas pu être propagé — lance set_url.py à la main"

cat <<RECAP

╔══════════════════════════════════════════════════════════════════════╗
║  L'INVITATION EST EN LIGNE, ET ELLE GARDE LES RÉPONSES               ║
╚══════════════════════════════════════════════════════════════════════╝

  URL publique   $URL
  Elle ne change pas d'un déploiement à l'autre.

  Suivi (garde ce lien pour toi) :
      $URL/api/admin?token=$JETON
  Export CSV :
      $URL/api/admin?token=$JETON&format=csv

  Le jeton est dans cloudflare/.admin-token, gitignoré.

  Les messages WhatsApp portent déjà ce lien : il vient d'être écrit dans
  05_post_aix.md, messages_prets.md et kit.html. Rien à recopier.

  Le Worker « little-fog-82ea » créé à la main peut être supprimé :
  tableau de bord → Workers et Pages → little-fog-82ea → Paramètres.

RECAP
