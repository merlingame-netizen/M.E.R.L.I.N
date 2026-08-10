#!/usr/bin/env bash
# Build web du jeu MERLIN, sur la VM (headless). Installe les templates d'export 4.6
# au premier passage, puis exporte le preset "Web" vers build/web/ (servi par le
# Studio sur /play/ — jouable navigateur PC + mobile via le tunnel).
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
VER="4.6"
TPL_DIR="$HOME/.local/share/godot/export_templates/${VER}.stable"
if [ ! -d "$TPL_DIR" ]; then
  echo "==> Templates d'export ${VER} absents — telechargement (~1 Go, une seule fois)"
  TMP=$(mktemp -d)
  curl -fsSL -o "$TMP/tpl.tpz" \
    "https://github.com/godotengine/godot/releases/download/${VER}-stable/Godot_v${VER}-stable_export_templates.tpz"
  mkdir -p "$TPL_DIR"
  unzip -q "$TMP/tpl.tpz" -d "$TMP"
  mv "$TMP"/templates/* "$TPL_DIR"/
  rm -rf "$TMP"
  echo "    templates installes"
fi
cd "$REPO"
mkdir -p build/web
echo "==> Export Web (preset 'Web')"
godot --headless --path . --export-release "Web" "build/web/index.html" 2>&1 | tail -15
ls -lh build/web/ | head -8
echo "OK: build/web pret (servi par le Studio sur /play/)"
