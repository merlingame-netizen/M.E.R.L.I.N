#!/usr/bin/env bash
set -euo pipefail

# Usage: bash scripts/voice_robot/colab_build_flite.sh /content/Godot-MCP
REPO_ROOT="${1:-/content/Godot-MCP}"

THIRD_PARTY="$REPO_ROOT/native/third_party"
FLITE_DIR="$THIRD_PARTY/flite"
OUT_DIR="$REPO_ROOT/native/third_party/flite_build"

sudo apt-get update -y
sudo apt-get install -y build-essential git

mkdir -p "$THIRD_PARTY"

if [ ! -d "$FLITE_DIR" ]; then
  echo "Cloning flite into $FLITE_DIR"
  git clone https://github.com/festvox/flite.git "$FLITE_DIR"
else
  echo "flite already present: $FLITE_DIR"
fi

mkdir -p "$OUT_DIR"

cd "$FLITE_DIR"

# Build flite (autotools)
if [ -x "./configure" ]; then
  ./configure --prefix="$OUT_DIR" --disable-shared
else
  echo "No configure script found. If flite uses autoconf, run ./configure manually." >&2
  exit 1
fi

make -j"$(nproc)"
make install

echo "Flite installed to: $OUT_DIR"
