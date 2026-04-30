#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────
# tools/octogent/start-persistent.sh
#
# Idempotent persistent launcher for Octogent inside WSL Ubuntu.
#
# Behaviour:
#   1. If Octogent is already running on the configured port → no-op, exit 0.
#   2. Else: ensure prereqs (node 22+, pnpm, claude CLI, build artifacts).
#   3. If `.octogent/tentacles/` is empty → run integrate-merlin-agents.mjs
#      to pre-populate the 103-agent catalog.
#   4. Launch via `setsid -f` so the process detaches from this shell and
#      survives WSL session teardown.
#   5. Wait up to 15s for the port to bind, then `curl` health-check.
#
# Usage (from anywhere):
#   wsl bash tools/octogent/start-persistent.sh
#
# Stop:
#   wsl bash -c 'pkill -f "node tools/octogent/bin/octogent"'
#
# Logs:
#   wsl tail -f /tmp/octogent.log
# ────────────────────────────────────────────────────────────────────────

set -euo pipefail

# Resolve repo root from this script's location (tools/octogent/ → ../..).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MERLIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OCTOGENT_DIR="$SCRIPT_DIR"

PORT="${PORT:-8787}"
HOST_BIND="${HOST:-0.0.0.0}"   # Bind 0.0.0.0 so Windows host can reach via localhost.
LOG_FILE="${LOG_FILE:-/tmp/octogent.log}"
PID_FILE="${PID_FILE:-/tmp/octogent.pid}"

log() { printf '[octogent-persistent] %s\n' "$*"; }

# ── 1. Already running? ───────────────────────────────────────────────────
if [ -f "$PID_FILE" ]; then
  EXISTING_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "$EXISTING_PID" ] && kill -0 "$EXISTING_PID" 2>/dev/null; then
    log "Already running (PID $EXISTING_PID)."
    log "  UI:   http://localhost:$PORT"
    log "  Logs: tail -f $LOG_FILE"
    exit 0
  fi
fi
# Stale PID file or process by name (e.g. PID file lost across reboot).
EXISTING_BY_NAME="$(pgrep -f "node tools/octogent/bin/octogent" | head -1 || true)"
if [ -n "$EXISTING_BY_NAME" ]; then
  log "Already running (PID $EXISTING_BY_NAME — discovered by name)."
  echo "$EXISTING_BY_NAME" > "$PID_FILE"
  exit 0
fi

# ── 2. Prereqs ────────────────────────────────────────────────────────────
# Source fnm / nvm if present (non-interactive bash skips ~/.bashrc).
[ -s "$HOME/.fnm/fnm" ] && export PATH="$HOME/.fnm:$PATH" && eval "$(fnm env --use-on-cd 2>/dev/null)" || true
# shellcheck disable=SC1091
[ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1 || true

command -v node >/dev/null 2>&1 || { log "ERROR: node not in PATH"; exit 1; }
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 22 ] || { log "ERROR: Node $NODE_MAJOR < 22"; exit 1; }

command -v pnpm >/dev/null 2>&1 || { log "ERROR: pnpm not in PATH (npm install -g pnpm@10.4.1)"; exit 1; }
command -v claude >/dev/null 2>&1 || log "WARN: claude CLI missing — Octogent will refuse to start."

# Build artifacts present?
if [ ! -d "$OCTOGENT_DIR/dist" ] || [ ! -d "$OCTOGENT_DIR/apps/web/dist" ]; then
  log "First-time build (dist missing) …"
  ( cd "$OCTOGENT_DIR" && pnpm install --frozen-lockfile && pnpm build ) || {
    log "ERROR: build failed"; exit 1;
  }
fi

# ── 3. Integrate 103 MERLIN agents on first run ───────────────────────────
TENTACLE_COUNT=0
if [ -d "$OCTOGENT_DIR/.octogent/tentacles" ]; then
  TENTACLE_COUNT="$(find "$OCTOGENT_DIR/.octogent/tentacles" -maxdepth 1 -mindepth 1 -type d | wc -l)"
fi
if [ "$TENTACLE_COUNT" -lt 50 ]; then
  log "Tentacles count = $TENTACLE_COUNT (< 50) — running integration."
  ( cd "$MERLIN_ROOT" && node "$OCTOGENT_DIR/integrate-merlin-agents.mjs" ) || {
    log "WARN: agent integration failed — continuing with empty deck."
  }
fi

# ── 4. Detached launch ────────────────────────────────────────────────────
# IMPORTANT: cwd MUST be the dir containing the .octogent/ state — that's
# tools/octogent/, not MERLIN_ROOT. Octogent uses `process.cwd()` as its
# workspaceCwd and reads tentacles from `<cwd>/.octogent/tentacles/`. If we
# launch from MERLIN_ROOT, the deck shows zero agents because the catalog
# lives at tools/octogent/.octogent/. project.json there already has
# displayName="MERLIN" so the dashboard still shows "MERLIN" as the
# project name.
log "Launching: HOST=$HOST_BIND PORT=$PORT, cwd=$OCTOGENT_DIR"
cd "$OCTOGENT_DIR"
setsid -f bash -c "OCTOGENT_NO_OPEN=1 HOST='$HOST_BIND' PORT='$PORT' node bin/octogent > '$LOG_FILE' 2>&1"

# ── 5. Wait for port + verify ─────────────────────────────────────────────
DEADLINE=$(( $(date +%s) + 15 ))
PID=""
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  PID="$(pgrep -f "node tools/octogent/bin/octogent" | head -1 || true)"
  if [ -n "$PID" ] && ss -tln 2>/dev/null | grep -q ":$PORT "; then
    break
  fi
  sleep 1
done

if [ -z "$PID" ] || ! ss -tln 2>/dev/null | grep -q ":$PORT "; then
  log "FAILED to bind port $PORT in 15s — last log lines:"
  tail -10 "$LOG_FILE" 2>/dev/null
  exit 2
fi
echo "$PID" > "$PID_FILE"

if curl -fsS -o /dev/null -w 'HTTP %{http_code}\n' "http://localhost:$PORT" >/dev/null 2>&1; then
  log "Octogent up. PID $PID. UI: http://localhost:$PORT"
  log "Tentacles: $(find "$OCTOGENT_DIR/.octogent/tentacles" -maxdepth 1 -mindepth 1 -type d | wc -l)"
else
  log "Bound but health-check failed. Logs: tail -f $LOG_FILE"
fi
