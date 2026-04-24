#!/usr/bin/env bash
# M.E.R.L.I.N. Local Dev Launcher
# Starts Mission Control + optionally Godot Editor

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MC_DIR="$SCRIPT_DIR/mission-control"

cleanup() {
  echo ""
  echo "[MERLIN] Shutting down..."
  kill $MC_PID 2>/dev/null
  [ -n "$GODOT_PID" ] && kill $GODOT_PID 2>/dev/null
  exit 0
}

trap cleanup INT TERM

echo "╔══════════════════════════════════════╗"
echo "║   M.E.R.L.I.N. — Local Dev Setup    ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Start Mission Control
echo "[MC] Starting Mission Control..."
cd "$MC_DIR"
if [ ! -d "node_modules" ]; then
  echo "[MC] Installing dependencies..."
  npm install
fi
npm run dev &
MC_PID=$!
echo "[MC] Mission Control PID: $MC_PID"
echo "[MC] Dashboard: http://localhost:4200"
echo ""

# Optionally launch Godot
if [[ "$1" == "--godot" ]] || [[ "$1" == "-g" ]]; then
  echo "[GODOT] Launching Godot Editor..."
  cd "$PROJECT_ROOT"
  godot --editor --path . &
  GODOT_PID=$!
  echo "[GODOT] Editor PID: $GODOT_PID"
  echo ""
fi

echo "[MERLIN] All systems online."
echo "[MERLIN] Press Ctrl+C to stop."
echo ""

wait $MC_PID
