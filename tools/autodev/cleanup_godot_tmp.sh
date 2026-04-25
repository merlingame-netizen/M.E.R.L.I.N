#!/usr/bin/env bash
# cleanup_godot_tmp.sh — Remove orphan ~*.dll~RF*.TMP files left by Godot's reloadable GDExtension
# Run this before launching Godot to ensure clean state.
# Usage: bash tools/autodev/cleanup_godot_tmp.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ADDONS="$ROOT/addons"

if [ ! -d "$ADDONS" ]; then
    echo "[cleanup_tmp] Skip: addons/ dir not found at $ADDONS"
    exit 0
fi

count=0
while IFS= read -r f; do
    rm -f "$f" && count=$((count+1))
done < <(find "$ADDONS" -name "*~*.TMP" -type f 2>/dev/null)

echo "[cleanup_tmp] Removed $count orphan ~*.dll~RF*.TMP files"
