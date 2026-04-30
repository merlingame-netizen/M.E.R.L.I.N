#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────
# tools/octogent/start-wsl.sh
#
# No-Docker fallback for environments where Docker Desktop isn't available
# (or you don't want the container overhead). Runs Octogent natively in
# WSL Ubuntu where pnpm.cmd Group Policy doesn't apply.
#
# Prereqs:
#   - WSL2 Ubuntu (default on modern Windows)
#   - Node 22+ inside WSL    (curl -fsSL https://fnm.vercel.app/install | bash)
#   - claude CLI inside WSL  (npm install -g @anthropic-ai/claude-code)
#   - pnpm                   (npm install -g pnpm@10.4.1)
#
# Usage:
#   wsl bash tools/octogent/start-wsl.sh
#
# Dashboard becomes available at http://localhost:8787 from BOTH the WSL
# Ubuntu side and the Windows host (WSL2 forwards listening sockets).
# ────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1) Sanity checks
echo "[octogent-wsl] Checking prereqs…"

# Non-interactive bash skips ~/.bashrc, so fnm/nvm shims are absent unless
# we source them explicitly. Try both before declaring node missing.
if [ -s "$HOME/.fnm/fnm" ]; then
  export PATH="$HOME/.fnm:$PATH"
  eval "$(fnm env --use-on-cd 2>/dev/null)" || true
fi
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1 || true
fi

command -v node >/dev/null 2>&1 || {
  echo "ERROR: node not found in WSL even after sourcing fnm/nvm."
  echo "       Install Node 22+ via:  curl -fsSL https://fnm.vercel.app/install | bash"
  echo "       Then reopen WSL or rerun this script."
  exit 1
}
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "ERROR: Node $NODE_MAJOR found, Octogent requires Node 22+."
  exit 1
fi

command -v pnpm >/dev/null 2>&1 || {
  echo "[octogent-wsl] pnpm missing — installing via npm…"
  npm install -g pnpm@10.4.1
}

command -v claude >/dev/null 2>&1 || {
  echo "WARNING: claude CLI not found in WSL — Octogent can launch but"
  echo "         spawned agents will fail. Install with:"
  echo "         npm install -g @anthropic-ai/claude-code"
  echo "         then run:  claude  (and complete auth)"
}

# 2) Install dependencies if needed
if [ ! -d "node_modules" ] || [ ! -d "apps/api/node_modules" ]; then
  echo "[octogent-wsl] First-time install (this builds node-pty natively)…"
  pnpm install --frozen-lockfile
fi

# 3) Build if no dist
if [ ! -d "apps/web/dist" ] || [ ! -d "dist" ]; then
  echo "[octogent-wsl] Building…"
  pnpm build
fi

# 4) Launch
echo "[octogent-wsl] Starting on http://localhost:8787 (Ctrl+C to stop)"
export OCTOGENT_NO_OPEN=1
exec node bin/octogent
