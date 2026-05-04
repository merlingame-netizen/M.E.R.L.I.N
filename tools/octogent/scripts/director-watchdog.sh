#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────
# tools/octogent/scripts/director-watchdog.sh
#
# 24h autonomous mode — keeps the studio-director loop alive while the user
# is away. Calls director-tick.mjs every 5 minutes. Also re-runs the
# Octogent persistent launcher if Octogent itself is down (the tick script
# itself does NOT restart Octogent — that's our job here).
#
# Behaviour:
#   - Idempotent: refuses to start if /tmp/director-watchdog.pid is alive.
#   - Periodically pokes Octogent /api/deck/tentacles. If unreachable,
#     re-runs start-persistent.sh.
#   - Calls director-tick.mjs after each health check.
#   - Sleeps INTERVAL seconds (default 300 = 5 min) between cycles.
#   - Exits cleanly on SIGTERM / SIGINT (cleans up PID file).
#
# Usage (launched detached for 24h autonomy):
#   wsl --exec bash -c '
#     setsid -f bash -c "
#       /mnt/c/Users/PGNK2128/Godot-MCP/tools/octogent/scripts/director-watchdog.sh \
#         > /tmp/director-watchdog.log 2>&1
#     "
#   '
#
# Stop:
#   wsl bash -c 'kill $(cat /tmp/director-watchdog.pid 2>/dev/null) 2>/dev/null;
#                rm -f /tmp/director-watchdog.pid'
#
# Note: SIGKILL (kill -9) cannot be trapped by bash, so the PID file is
# leaked on hard kill. The next launch's idempotency guard recovers via
# `kill -0 $EXISTING` (returns non-zero on stale PID) and proceeds.
#
# Logs:
#   wsl tail -f /tmp/director-watchdog.log
#   wsl tail -f tools/octogent/.octogent/tentacles/studio_director/cycle_log.md
# ────────────────────────────────────────────────────────────────────────

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OCTOGENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MERLIN_ROOT="$(cd "$OCTOGENT_DIR/.." && pwd)"

INTERVAL="${INTERVAL:-300}"                  # seconds between ticks
PID_FILE="${PID_FILE:-/tmp/director-watchdog.pid}"
LOG_FILE="${LOG_FILE:-/tmp/director-watchdog.log}"
OCTOGENT_BASE="${OCTOGENT_BASE:-http://localhost:8787}"
MAX_HOURS="${MAX_HOURS:-24}"

log() { printf '[watchdog %s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

# ── Idempotency ────────────────────────────────────────────────────────
if [ -f "$PID_FILE" ]; then
  EXISTING="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "$EXISTING" ] && kill -0 "$EXISTING" 2>/dev/null; then
    log "Already running (PID $EXISTING). Tail $LOG_FILE for activity."
    exit 0
  fi
fi
# HIGH FIX (post-review): use $BASHPID (current bash process) instead of
# $$ (parent shell). When invoked via `setsid -f bash -c "...sh..."`,
# $$ inside this script is the setsid'd shell — same as $BASHPID — so
# behavior is unchanged in the canonical launch path. But $BASHPID is
# unambiguous if the script is ever sourced or wrapped further.
echo "$BASHPID" > "$PID_FILE"

cleanup() {
  log "Shutting down (SIGTERM/SIGINT)."
  rm -f "$PID_FILE"
  exit 0
}
trap cleanup TERM INT

log "Director watchdog start. PID=$$ INTERVAL=${INTERVAL}s MAX_HOURS=$MAX_HOURS"
log "Tick: $SCRIPT_DIR/director-tick.mjs"
log "Cycle log: $OCTOGENT_DIR/.octogent/tentacles/studio_director/cycle_log.md"

DEADLINE=$(( $(date +%s) + MAX_HOURS * 3600 ))
CYCLE=0
HEALTH_FAILS=0      # MEDIUM FIX: 2-of-3 consecutive failures before restart

while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  CYCLE=$((CYCLE + 1))
  log "─── cycle $CYCLE ───"

  # Health check Octogent. Require 2 consecutive failures before restart
  # to absorb 1-tick network hiccups (DNS / WSL bridge stalls).
  HTTP_CODE="$(curl -fsS -o /dev/null -w '%{http_code}' --max-time 5 "$OCTOGENT_BASE/api/deck/tentacles" 2>/dev/null || echo "000")"
  if [ "$HTTP_CODE" != "200" ]; then
    HEALTH_FAILS=$((HEALTH_FAILS + 1))
    log "Octogent health=$HTTP_CODE (consecutive fails: $HEALTH_FAILS/2)"
    if [ "$HEALTH_FAILS" -ge 2 ]; then
      log "Two consecutive failures — restarting via start-persistent.sh"
      bash "$OCTOGENT_DIR/start-persistent.sh" 2>&1 | sed 's/^/[watchdog-restart] /'
      HEALTH_FAILS=0
      sleep 5
    fi
  else
    HEALTH_FAILS=0
  fi

  # Call the director tick.
  if command -v node >/dev/null 2>&1; then
    if node "$SCRIPT_DIR/director-tick.mjs" 2>&1 | sed 's/^/[tick] /'; then
      log "Tick OK."
    else
      log "Tick exited non-zero (see lines above)."
    fi
  else
    log "ERROR: node not found — cannot run tick. Sleeping anyway."
  fi

  log "Sleep ${INTERVAL}s."
  sleep "$INTERVAL" || cleanup
done

log "Reached MAX_HOURS=$MAX_HOURS — exiting cleanly."
cleanup
