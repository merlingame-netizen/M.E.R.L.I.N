#!/usr/bin/env bash
set -euo pipefail

# Package the addon for Windows (after build)
# Usage: bash scripts/voice_robot/colab_pack_windows_addon.sh /content/Godot-MCP
REPO_ROOT="${1:-/content/Godot-MCP}"
OUT_ZIP="$REPO_ROOT/robot_voice_windows_addon.zip"

cd "$REPO_ROOT"
rm -f "$OUT_ZIP"
zip -r "$OUT_ZIP" "addons/robot_voice"

echo "Packaged: $OUT_ZIP"
