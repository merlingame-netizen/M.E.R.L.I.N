#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# M.E.R.L.I.N. SessionStart Hook
# Runs automatically when a Claude Code session starts.
# 1. Installs Godot headless (if not present)
# 2. Logs session start to watchdog
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# ─── Setup cloud environment ─────────────────────────────────────────────────
if [ -f "tools/autodev/setup_cloud.sh" ]; then
    bash tools/autodev/setup_cloud.sh 2>&1 || true
fi

# ─── Log session start ───────────────────────────────────────────────────────
WATCHDOG="tools/autodev/status/watchdog.txt"
if [ -f "$WATCHDOG" ]; then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) session-start $(uname -s)" >> "$WATCHDOG"
fi

echo "[hook] M.E.R.L.I.N. session ready. Director agent: .claude/agents/cycle_director.md"
