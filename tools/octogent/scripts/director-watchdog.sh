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

# P0 settings
GATES_SCRIPT="$SCRIPT_DIR/quality-gates.sh"
GATE_FAILS_FILE="${GATE_FAILS_FILE:-/tmp/director-gate-fails.txt}"
HEARTBEAT_SILENCE_S="${HEARTBEAT_SILENCE_S:-600}"   # 10 min
GATE_FAILS_PAUSE_AFTER="${GATE_FAILS_PAUSE_AFTER:-3}"
GATE_FAILS_PAUSE_S="${GATE_FAILS_PAUSE_S:-3600}"    # 1h pause after 3 fails
WORKTREES_DIR="$OCTOGENT_DIR/.octogent/worktrees"
QGR_TENTACLE="$OCTOGENT_DIR/.octogent/tentacles/quality_gate_runner"
mkdir -p "$QGR_TENTACLE"

# Initialize gate fails counter if missing.
[ -f "$GATE_FAILS_FILE" ] || echo "0" > "$GATE_FAILS_FILE"

# ── P0 helper functions ──────────────────────────────────────────────────
run_gates_on_new_commits() {
  [ -d "$WORKTREES_DIR" ] || return 0
  for wt in "$WORKTREES_DIR"/*/; do
    [ -d "$wt/.git" ] || [ -f "$wt/.git" ] || continue
    local wtname; wtname="$(basename "$wt")"
    local last_file="$wt/.last-checked-hash"
    local last_hash=""
    [ -f "$last_file" ] && last_hash="$(cat "$last_file" 2>/dev/null || true)"
    local new_hashes
    if [ -n "$last_hash" ]; then
      new_hashes="$(git -C "$wt" log "${last_hash}..HEAD" --format=%H 2>/dev/null | head -5 || true)"
    else
      new_hashes="$(git -C "$wt" log -n 1 --format=%H 2>/dev/null || true)"
    fi
    [ -z "$new_hashes" ] && continue
    while IFS= read -r h; do
      [ -z "$h" ] && continue
      log "Gate run: worktree=$wtname commit=${h:0:7}"
      bash "$GATES_SCRIPT" "$wt" "$h" 2>&1 | sed 's/^/[gates] /'
      local rc=${PIPESTATUS[0]}
      case "$rc" in
        0)
          log "Gates PASS — auto-merging ${h:0:7} into main"
          ( cd "$MERLIN_ROOT" && git fetch "$wt" "+HEAD:refs/octogent/${wtname}-${h:0:7}" 2>&1 | sed 's/^/[merge-fetch] /' ) || true
          ( cd "$MERLIN_ROOT" && git merge --squash "refs/octogent/${wtname}-${h:0:7}" 2>&1 | sed 's/^/[merge-squash] /' ) || true
          ( cd "$MERLIN_ROOT" && git diff --cached --quiet || git commit -m "auto: gates PASS ${h:0:7} from $wtname" 2>&1 | sed 's/^/[merge-commit] /' ) || true
          echo "0" > "$GATE_FAILS_FILE"
          ;;
        1|2)
          log "Gates SOFT FAIL (rc=$rc) on ${h:0:7} — adding fix-todo"
          local source_tentacle
          source_tentacle="$(echo "$wtname" | sed 's/-swarm-.*$//')"
          local fix_todo="$OCTOGENT_DIR/.octogent/tentacles/$source_tentacle/todo.md"
          if [ -f "$fix_todo" ]; then
            printf -- '- [ ] Fix from gate fail (%s, rc=%d): re-check commit %s in worktree %s\n' "${h:0:7}" "$rc" "${h:0:7}" "$wtname" >> "$fix_todo"
          fi
          local fails; fails=$(($(cat "$GATE_FAILS_FILE" 2>/dev/null || echo 0) + 1))
          echo "$fails" > "$GATE_FAILS_FILE"
          log "Consecutive gate fails: $fails / $GATE_FAILS_PAUSE_AFTER"
          ;;
        3)
          log "Gates HARD FAIL (rc=3, secret leak) on ${h:0:7} — pause + blocker"
          cat > "$QGR_TENTACLE/blocker.md" <<EOF
# BLOCKER — secret pattern detected

Commit: ${h:0:7}
Worktree: $wtname
Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)

Quality-gate exit code 3: a secret pattern was matched in the commit
diff or filename. Auto-merge BLOCKED. Review manually.

Watchdog will pause until this blocker.md is removed.
EOF
          echo "$GATE_FAILS_PAUSE_AFTER" > "$GATE_FAILS_FILE"
          ;;
        *)
          log "Gates UNKNOWN rc=$rc on ${h:0:7} — counted as soft fail"
          local fails; fails=$(($(cat "$GATE_FAILS_FILE" 2>/dev/null || echo 0) + 1))
          echo "$fails" > "$GATE_FAILS_FILE"
          ;;
      esac
      echo "$h" > "$last_file"
    done <<< "$(echo "$new_hashes" | tac)"  # oldest-first
  done
}

# Heartbeat detection: kill workers silent > HEARTBEAT_SILENCE_S.
detect_silent_workers() {
  local snapshots
  snapshots="$(curl -fsS --max-time 5 "$OCTOGENT_BASE/api/terminal-snapshots" 2>/dev/null || true)"
  [ -z "$snapshots" ] && return 0
  local kills
  kills="$(printf '%s' "$snapshots" | python3 -c "
import json, sys, datetime, time
data = json.load(sys.stdin)
arr = data if isinstance(data, list) else data.get('snapshots', [])
now = time.time() * 1000
threshold_ms = $HEARTBEAT_SILENCE_S * 1000
out = []
for t in arr:
    tid = t.get('terminalId', '')
    if not (tid.startswith('studio_director-swarm-') or tid.startswith('quality_gate_runner-swarm-')):
        continue
    ts = t.get('lastOutputAt') or t.get('updatedAt') or t.get('createdAt')
    if not ts: continue
    try:
        if isinstance(ts, str):
            dt = datetime.datetime.fromisoformat(ts.replace('Z','+00:00')).timestamp() * 1000
        else:
            dt = float(ts)
    except Exception:
        continue
    if (now - dt) > threshold_ms:
        out.append(tid)
print('\n'.join(out))
" 2>/dev/null || true)"
  [ -z "$kills" ] && return 0
  while IFS= read -r tid; do
    [ -z "$tid" ] && continue
    log "Heartbeat silent (>${HEARTBEAT_SILENCE_S}s) — killing $tid"
    curl -fsS -X POST --max-time 5 "$OCTOGENT_BASE/api/terminals/$tid/kill" >/dev/null 2>&1 || true
  done <<< "$kills"
}

# Pause if blocker present or fails reached threshold.
check_pause_conditions() {
  if [ -f "$QGR_TENTACLE/blocker.md" ]; then
    log "BLOCKER present at $QGR_TENTACLE/blocker.md — pausing $GATE_FAILS_PAUSE_S s"
    sleep "$GATE_FAILS_PAUSE_S" || cleanup
    return 0
  fi
  local fails; fails="$(cat "$GATE_FAILS_FILE" 2>/dev/null || echo 0)"
  if [ "$fails" -ge "$GATE_FAILS_PAUSE_AFTER" ]; then
    log "Reached $fails consecutive gate fails (>= $GATE_FAILS_PAUSE_AFTER) — pause $GATE_FAILS_PAUSE_S s"
    sleep "$GATE_FAILS_PAUSE_S" || cleanup
  fi
}

DEADLINE=$(( $(date +%s) + MAX_HOURS * 3600 ))
CYCLE=0
HEALTH_FAILS=0      # MEDIUM FIX: 2-of-3 consecutive failures before restart

while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  CYCLE=$((CYCLE + 1))
  log "─── cycle $CYCLE ───"

  # P0: pause if blocker.md present or 3+ consecutive gate fails.
  # Honors any user-facing pause condition before doing work.
  check_pause_conditions

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

  # P0: scan worker worktrees for new commits, run quality gates,
  # auto-merge on PASS, fix-todo on soft fail, blocker on secret leak.
  run_gates_on_new_commits

  # P0: kill workers silent for more than HEARTBEAT_SILENCE_S (10 min).
  # Prevents stuck Claude sessions from consuming tokens forever.
  detect_silent_workers

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
