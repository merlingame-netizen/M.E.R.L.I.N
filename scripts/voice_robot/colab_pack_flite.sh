#!/usr/bin/env bash
set -euo pipefail

# Usage: bash scripts/voice_robot/colab_pack_flite.sh /content/Godot-MCP
REPO_ROOT="${1:-/content/Godot-MCP}"

OUT_DIR="$REPO_ROOT/native/third_party/flite_build"
OUT_ZIP="$REPO_ROOT/flite_linux_build.zip"

if [ ! -d "$OUT_DIR" ]; then
  echo "Missing $OUT_DIR. Run colab_build_flite.sh first." >&2
  exit 1
fi

cd "$REPO_ROOT"
rm -f "$OUT_ZIP"
zip -r "$OUT_ZIP" "native/third_party/flite_build"

echo "Packaged: $OUT_ZIP"
