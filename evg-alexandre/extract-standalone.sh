#!/usr/bin/env bash
# Crée un dépôt git autonome dont la RACINE = les fichiers du site cagnotte
# (requis pour GitHub Pages). Voir SETUP.md.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-$SRC/../cagnotte-evg-standalone}"

echo "→ Source : $SRC"
echo "→ Cible  : $DEST"

rm -rf "$DEST"
mkdir -p "$DEST"

# copie tout sauf les fichiers de dev/staging
rsync -a --exclude '.git' --exclude 'extract-standalone.sh' "$SRC"/ "$DEST"/ 2>/dev/null \
  || cp -r "$SRC"/. "$DEST"/

cd "$DEST"
# petit .gitignore + nettoyage du staging
rm -f extract-standalone.sh
git init -q
git add -A
git commit -q -m "init: site cagnotte EVG Alexandre (autonome)"

echo "✓ Dépôt prêt dans : $DEST"
echo "  Étapes suivantes (avec TON auth) : voir SETUP.md §1 (gh / SSH) puis §2 (Worker)."
