#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────
# tools/octogent/scripts/quality-gates.sh
#
# Run the 4 P0 quality gates on a single commit inside a worktree:
#   1. secret pattern guard (FIRST — hardest fail)
#   2. parse-check (python tools/cli.py godot validate_step0)
#   3. smoke runtime on touched .tscn scenes (5s windowed launch each)
#   4. (TODO) code-reviewer agent — placeholder, returns PASS for now.
#
# Usage:
#   bash tools/octogent/scripts/quality-gates.sh <worktree-path> <commit-hash>
#
# Exit codes (designed for the watchdog + auto-merge logic):
#   0  → all gates PASS  (safe to merge)
#   1  → parse fail
#   2  → smoke fail
#   3  → secret leak detected (HARD STOP — do not merge, alert user)
#   4  → other / unknown error
#
# Side effect:
#   Writes per-commit JSON report to
#     .octogent/tentacles/quality_gate_runner/reports/<short-hash>.json
# ────────────────────────────────────────────────────────────────────────

set -uo pipefail

WORKTREE="${1:-}"
COMMIT="${2:-HEAD}"

if [ -z "$WORKTREE" ] || [ ! -d "$WORKTREE" ]; then
  echo "ERROR: usage: $0 <worktree-path> <commit-hash>" >&2
  exit 4
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OCTOGENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MERLIN_ROOT="$(cd "$OCTOGENT_DIR/.." && pwd)"
REPORT_DIR="$OCTOGENT_DIR/.octogent/tentacles/quality_gate_runner/reports"
mkdir -p "$REPORT_DIR"

SHORT_HASH="$(git -C "$WORKTREE" rev-parse --short "$COMMIT" 2>/dev/null || echo "unknown")"
WORKTREE_NAME="$(basename "$WORKTREE")"
START_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
START_MS="$(date +%s%3N)"

echo "[gates $START_TS] worktree=$WORKTREE_NAME commit=$SHORT_HASH"

# ── Gate 1: secret pattern guard (FIRST — hardest fail) ───────────────────
SECRET_PATTERNS='AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{48,}|sk-proj-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{82,}|xox[abpr]-[A-Za-z0-9-]{10,}|-----BEGIN (RSA |EC |OPENSSH |DSA |)PRIVATE KEY-----'
SECRET_FILENAMES='\.env$|\.env\.|\.pem$|\.key$|id_rsa$|id_ed25519$|credentials\.json$'

DIFF="$(git -C "$WORKTREE" show "$COMMIT" 2>/dev/null || true)"
DIFF_FILES="$(git -C "$WORKTREE" diff-tree --no-commit-id --name-only -r "$COMMIT" 2>/dev/null || true)"

SECRETS_MATCHES=""
if [ -n "$DIFF" ]; then
  CONTENT_HITS="$(printf '%s\n' "$DIFF" | grep -E "^\+" | grep -E "$SECRET_PATTERNS" || true)"
  if [ -n "$CONTENT_HITS" ]; then
    SECRETS_MATCHES="content_pattern_match"
  fi
fi
if [ -n "$DIFF_FILES" ]; then
  FILE_HITS="$(printf '%s\n' "$DIFF_FILES" | grep -E "$SECRET_FILENAMES" || true)"
  if [ -n "$FILE_HITS" ]; then
    SECRETS_MATCHES="${SECRETS_MATCHES:+$SECRETS_MATCHES,}suspicious_filename:$(echo "$FILE_HITS" | tr '\n' ',' | sed 's/,$//')"
  fi
fi

if [ -n "$SECRETS_MATCHES" ]; then
  echo "[gates] FAIL secret guard: $SECRETS_MATCHES"
  cat > "$REPORT_DIR/${SHORT_HASH}.json" <<EOF
{
  "commit": "$SHORT_HASH",
  "worktree": "$WORKTREE_NAME",
  "timestamp": "$START_TS",
  "passed": false,
  "gates": {
    "secrets": {"passed": false, "matches": "$SECRETS_MATCHES"},
    "parse":   {"passed": null},
    "smoke":   {"passed": null}
  },
  "duration_ms": $(( $(date +%s%3N) - START_MS ))
}
EOF
  exit 3
fi
echo "[gates] secret guard PASS"

# ── Gate 2: parse-check headless ──────────────────────────────────────────
PARSE_OUT="$(cd "$WORKTREE" && python tools/cli.py godot validate_step0 2>&1 | tail -50)"
PARSE_EXIT=$?
PARSE_OK=true
PARSE_ERRORS=0
if [ "$PARSE_EXIT" -ne 0 ]; then
  PARSE_OK=false
  PARSE_ERRORS=$(printf '%s\n' "$PARSE_OUT" | grep -cE "ERROR|Parse Error" || echo 0)
  echo "[gates] FAIL parse: $PARSE_ERRORS errors"
fi

if [ "$PARSE_OK" = false ]; then
  cat > "$REPORT_DIR/${SHORT_HASH}.json" <<EOF
{
  "commit": "$SHORT_HASH",
  "worktree": "$WORKTREE_NAME",
  "timestamp": "$START_TS",
  "passed": false,
  "gates": {
    "secrets": {"passed": true},
    "parse":   {"passed": false, "errors": $PARSE_ERRORS},
    "smoke":   {"passed": null}
  },
  "duration_ms": $(( $(date +%s%3N) - START_MS ))
}
EOF
  exit 1
fi
echo "[gates] parse PASS"

# ── Gate 3: smoke runtime on touched scenes ───────────────────────────────
TOUCHED_SCENES="$(printf '%s\n' "$DIFF_FILES" | grep -E '\.tscn$' | head -3 || true)"
SMOKE_OK=true
SMOKE_ERRORS=0
SCENES_TESTED=""

if [ -n "$TOUCHED_SCENES" ]; then
  while IFS= read -r scene; do
    [ -z "$scene" ] && continue
    SCENES_TESTED="${SCENES_TESTED}${SCENES_TESTED:+,}$scene"
    SMOKE_OUT="$(cd "$WORKTREE" && python tools/cli.py godot smoke --scene "res://$scene" --duration 5 2>&1 || true)"
    if printf '%s\n' "$SMOKE_OUT" | grep -q "passed=True"; then
      echo "[gates] smoke $scene: PASS"
    else
      SMOKE_OK=false
      THIS_ERR=$(printf '%s\n' "$SMOKE_OUT" | grep -cE "SCRIPT ERROR" || echo 0)
      SMOKE_ERRORS=$(( SMOKE_ERRORS + THIS_ERR ))
      echo "[gates] smoke $scene: FAIL ($THIS_ERR script errors)"
    fi
  done <<< "$TOUCHED_SCENES"
else
  echo "[gates] smoke skipped (no .tscn touched)"
fi

if [ "$SMOKE_OK" = false ]; then
  cat > "$REPORT_DIR/${SHORT_HASH}.json" <<EOF
{
  "commit": "$SHORT_HASH",
  "worktree": "$WORKTREE_NAME",
  "timestamp": "$START_TS",
  "passed": false,
  "gates": {
    "secrets": {"passed": true},
    "parse":   {"passed": true, "errors": 0},
    "smoke":   {"passed": false, "scenes": "$SCENES_TESTED", "script_errors": $SMOKE_ERRORS}
  },
  "duration_ms": $(( $(date +%s%3N) - START_MS ))
}
EOF
  exit 2
fi
echo "[gates] smoke PASS"

# ── Gate 4: code-reviewer (TODO — needs Claude API integration) ───────────
# Placeholder: returns PASS. The full implementation would invoke the
# everything-claude-code:code-reviewer agent via the Anthropic API on the
# commit diff and parse for HIGH/CRITICAL issues. Wire when the
# orchestration layer can spawn meta-Claude calls cleanly.

# ── All gates passed ──────────────────────────────────────────────────────
cat > "$REPORT_DIR/${SHORT_HASH}.json" <<EOF
{
  "commit": "$SHORT_HASH",
  "worktree": "$WORKTREE_NAME",
  "timestamp": "$START_TS",
  "passed": true,
  "gates": {
    "secrets":  {"passed": true},
    "parse":    {"passed": true, "errors": 0},
    "smoke":    {"passed": true, "scenes": "$SCENES_TESTED"},
    "reviewer": {"passed": null, "note": "placeholder — TODO wire Claude API"}
  },
  "duration_ms": $(( $(date +%s%3N) - START_MS ))
}
EOF
echo "[gates $(date -u +%Y-%m-%dT%H:%M:%SZ)] ALL PASS"
exit 0
