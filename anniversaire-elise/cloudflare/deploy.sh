#!/usr/bin/env bash
# Déploie l'invitation sur Cloudflare Pages, avec sa base D1.
#
#   bash anniversaire-elise/cloudflare/deploy.sh
#
# Palier gratuit, sans carte bancaire : 100 000 requêtes/jour, 100 000
# écritures/jour, 5 Go. Pour neuf invités, six ordres de grandeur au-dessus.
#
# Idempotent : relancer met à jour la page sans toucher aux réponses.
set -euo pipefail

ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJET=anniv-elise

say(){ printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }
die(){ printf '\n\033[1;31mERREUR: %s\033[0m\n' "$*" >&2; exit 1; }

command -v npx >/dev/null || die "npx introuvable — installe Node.js (nodejs.org)"

# ── 1. La page ──────────────────────────────────────────────────────────────
say "Construction de la page"
python3 "$ICI/build.py" || die "build.py a échoué"

# ── 2. Connexion ────────────────────────────────────────────────────────────
say "Compte Cloudflare"
if ! npx --yes wrangler@latest whoami >/dev/null 2>&1; then
  echo "    Une fenêtre va s'ouvrir pour autoriser wrangler."
  npx --yes wrangler@latest login || die "connexion refusée"
fi
npx --yes wrangler@latest whoami | sed 's/^/    /'

# ── 3. La base ──────────────────────────────────────────────────────────────
say "Base de données D1"
if grep -q '__A_REMPLIR__' "$ICI/wrangler.toml"; then
  SORTIE="$(npx --yes wrangler@latest d1 create "$PROJET" 2>&1 || true)"
  ID="$(printf '%s' "$SORTIE" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)"
  [ -n "$ID" ] || { printf '%s\n' "$SORTIE"; die "identifiant de base introuvable — la base existe peut-être déjà, récupère son id avec 'npx wrangler d1 list' et colle-le dans wrangler.toml"; }
  # sed -i diffère entre GNU et BSD : on passe par un fichier temporaire.
  sed "s/__A_REMPLIR__/$ID/" "$ICI/wrangler.toml" > "$ICI/wrangler.toml.tmp"
  mv "$ICI/wrangler.toml.tmp" "$ICI/wrangler.toml"
  echo "    base créée : $ID"
else
  echo "    déjà déclarée dans wrangler.toml"
fi

say "Schéma"
npx --yes wrangler@latest d1 execute "$PROJET" --remote --file "$ICI/schema.sql" \
  || die "le schéma n'a pas pu être appliqué"

# ── 4. Le jeton d'administration ────────────────────────────────────────────
say "Jeton d'administration"
JETON_FICHIER="$ICI/.admin-token"
if [ ! -f "$JETON_FICHIER" ]; then
  head -c 18 /dev/urandom | base64 | tr -d '/+=' > "$JETON_FICHIER"
  chmod 600 "$JETON_FICHIER"
fi
JETON="$(cat "$JETON_FICHIER")"

# ── 5. Publication ──────────────────────────────────────────────────────────
say "Publication"
cd "$ICI"
npx --yes wrangler@latest pages deploy public --project-name "$PROJET" \
  --commit-dirty=true | tee /tmp/anniv-cf.log

URL="$(grep -oE 'https://[a-z0-9.-]+\.pages\.dev' /tmp/anniv-cf.log | tail -1 || true)"
[ -n "$URL" ] || die "URL introuvable dans la sortie — regarde /tmp/anniv-cf.log"

say "Secret"
printf '%s' "$JETON" | npx --yes wrangler@latest pages secret put ADMIN_TOKEN \
  --project-name "$PROJET" >/dev/null 2>&1 \
  || echo "    (à poser à la main : wrangler pages secret put ADMIN_TOKEN)"

# ── 6. Vérification de bout en bout ─────────────────────────────────────────
say "Vérification"
# Cette vérification n'est pas une politesse. Si le binding D1 ne monte pas,
# rien ne le dit au déploiement : la page s'affiche normalement et c'est
# seulement à la première réponse que `env.DB` sort `undefined`, en 500.
# On appelle donc l'API pour de bon avant d'annoncer quoi que ce soit.
SANTE="$(curl -fsS --max-time 20 "$URL/api/etat" || true)"
if [ -z "$SANTE" ]; then
  curl -sS --max-time 20 "$URL/api/etat" | head -5 | sed 's/^/    /' || true
  die "l'API ne répond pas. Si l'erreur parle de 'prepare' ou de 'undefined',
    c'est le binding D1 : ouvre le tableau de bord Cloudflare, Pages →
    $PROJET → Settings → Bindings, et déclare D1 'DB' sur la base
    '$PROJET'. Sinon, réessaie dans une minute : $URL/api/etat"
fi
echo "    $SANTE"

# ── 7. Le lien, partout ─────────────────────────────────────────────────────
# La publication ne vaut rien tant que les messages pointent ailleurs : on
# enchaîne, plutôt que de laisser une commande à recopier.
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

  Mettre à jour la page après une modification :
      bash anniversaire-elise/cloudflare/deploy.sh
  Les réponses déjà données ne bougent pas.

  Les messages WhatsApp portent déjà ce lien : il vient d'être écrit dans
  05_post_aix.md, messages_prets.md et kit.html. Rien à recopier.
      whatsapp/messages_prets.md   les six blocs, adresse et IBAN remplis
      whatsapp/kit.html            la même chose, à copier en un clic

RECAP
