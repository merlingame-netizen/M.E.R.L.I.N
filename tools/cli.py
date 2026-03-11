#!/usr/bin/env python3
"""
CLI-Anything — Game-focused CLI dispatcher (Godot, Ollama, Git).

Usage:
    python tools/cli.py <tool> <action> [options]
    python tools/cli.py --help
    python tools/cli.py godot --help
    python tools/cli.py godot validate
    python tools/cli.py godot validate_step0
    python tools/cli.py godot export web
    python tools/cli.py godot test
    python tools/cli.py godot telemetry
    python tools/cli.py godot smoke --scene res://scenes/MerlinGame.tscn
    python tools/cli.py ollama list
    python tools/cli.py ollama generate --model qwen2.5:7b --prompt "Hello"
    python tools/cli.py git status
    python tools/cli.py git commit --message "feat: ..."

Note: Orange/data adapters (powerbi, dbeaver, bigquery, outlook, office, browser)
      have been moved to ~/.claude/tools/adapters/ — use cli.py from that context.

Output: JSON by default. Use --human for pretty-printed output.
Exit code: 0 = success, 1 = error (for CI/AUTODEV integration).
"""

from __future__ import annotations

import argparse
import io
import json
import sys
from pathlib import Path
from typing import Any

# Fix Windows stdout encoding (cp1252 → utf-8) to prevent UnicodeEncodeError
if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "buffer"):
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

# Ensure project root is in sys.path regardless of invocation directory
_HERE = Path(__file__).resolve().parent        # tools/
_ROOT = _HERE.parent                           # project root
for _p in (_ROOT, _HERE):
    _s = str(_p)
    if _s not in sys.path:
        sys.path.insert(0, _s)

TOOLS = ["godot", "ollama", "git"]
SPECIAL_COMMANDS = ["health", "pipeline"]


# ── Tool loader (lazy import to avoid cross-tool dependencies) ────────────────

def _load_adapter(tool: str):
    if tool == "godot":
        from adapters.godot_adapter import GodotAdapter
        return GodotAdapter()
    if tool == "ollama":
        from adapters.ollama_adapter import OllamaAdapter
        return OllamaAdapter()
    if tool == "git":
        from adapters.git_adapter import GitAdapter
        return GitAdapter()
    raise ValueError(f"Unknown tool: {tool!r}. Available: {TOOLS}")


# ── CLI parser ────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="cli.py",
        description="CLI-Anything — Unified agent-native CLI dispatcher",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Run `cli.py <tool> --help` for tool-specific actions.",
    )
    parser.add_argument("tool", choices=TOOLS, help="Target tool")
    parser.add_argument("action", nargs="?", default="help", help="Action to execute")
    parser.add_argument("--human", action="store_true", help="Pretty-print output (default: JSON)")
    parser.add_argument("--json", dest="json_out", action="store_true", default=True,
                        help="Machine-readable JSON output (default)")
    # Godot args
    parser.add_argument("preset", nargs="?", default=None,
                        help="[godot export] Export preset name (e.g. 'web', 'windows')")
    parser.add_argument("--step", type=int, default=None, help="[godot validate] Step number (0-5)")
    parser.add_argument("--scene", default=None, help="[godot smoke] Scene path to test")
    # Ollama args
    parser.add_argument("--model", default=None, help="[ollama] Model name (default: qwen2.5:7b)")
    parser.add_argument("--prompt", default=None, help="[ollama generate/chat] Text prompt")
    parser.add_argument("--system", default=None, help="[ollama] System prompt")
    # Git args
    parser.add_argument("--message", default=None, help="[git commit] Commit message")
    parser.add_argument("--files", nargs="*", default=None, help="[git commit] Files to stage")
    parser.add_argument("--staged", action="store_true", help="[git diff] Show staged changes only")
    parser.add_argument("--number", type=int, default=None, help="[git pr-view] PR number")
    return parser


# ── Output ────────────────────────────────────────────────────────────────────

def print_result(result: dict, human: bool) -> None:
    if human:
        status = result.get("status", "?")
        tool = result.get("tool", "?")
        icon = "✓" if status == "ok" else "✗"
        print(f"{icon} [{tool}] {status.upper()}  ({result.get('duration_ms', 0)}ms)")
        data = result.get("data")
        if data:
            print(json.dumps(data, ensure_ascii=False, indent=2))
        if result.get("error"):
            print(f"  Error: {result['error']}")
        logs = result.get("logs", [])
        if logs:
            print("  Logs:")
            for line in logs:
                print(f"    {line}")
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2))


# ── Help ──────────────────────────────────────────────────────────────────────

def print_tool_help(tool: str) -> None:
    try:
        adapter = _load_adapter(tool)
        actions = adapter.list_actions()
        print(f"\n{tool.upper()} — available actions:\n")
        for action, desc in actions.items():
            print(f"  {action:<20} {desc}")
        print()
    except Exception as exc:
        print(f"Could not load {tool} adapter: {exc}")


# ── Health check ─────────────────────────────────────────────────────────────

_HEALTH_PROBES: dict[str, tuple[str, dict]] = {
    "godot":  ("list_presets", {}),
    "ollama": ("list",         {}),
    "git":    ("status",       {}),
}


def run_health(human: bool) -> int:
    """Smoke-test every adapter with a lightweight probe action."""
    import time
    results = {}
    for tool in TOOLS:
        probe_action, probe_kwargs = _HEALTH_PROBES.get(tool, ("help", {}))
        t0 = time.monotonic()
        try:
            adapter = _load_adapter(tool)
            result = adapter.execute(probe_action, **probe_kwargs)
            status = result.get("status", "error")
        except Exception as exc:
            status = "error"
            result = {"status": "error", "error": str(exc)}
        elapsed = int((time.monotonic() - t0) * 1000)
        results[tool] = {"status": status, "probe": probe_action, "ms": elapsed,
                         "error": result.get("error")}

    all_ok = all(r["status"] == "ok" for r in results.values())
    envelope = {
        "status": "ok" if all_ok else "degraded",
        "tools": results,
        "passed": sum(1 for r in results.values() if r["status"] == "ok"),
        "total": len(results),
    }
    if human:
        icon = "✓" if all_ok else "⚠"
        print(f"{icon} Health: {envelope['passed']}/{envelope['total']} tools OK\n")
        for tool, r in results.items():
            sym = "✓" if r["status"] == "ok" else "✗"
            err = f"  [{r['error']}]" if r.get("error") else ""
            print(f"  {sym} {tool:<12} {r['probe']:<20} {r['ms']}ms{err}")
        print()
    else:
        print(json.dumps(envelope, ensure_ascii=False, indent=2))
    return 0 if all_ok else 1


# ── Pipeline ──────────────────────────────────────────────────────────────────

def run_pipeline(steps: list[str], human: bool, stop_on_error: bool = True) -> int:
    """
    Execute a sequence of CLI steps.
    Each step is a string like 'godot validate' or 'git status'.
    Steps are split on whitespace and dispatched through the normal main() path.
    """
    import time
    results = []
    overall_ok = True
    for step in steps:
        parts = step.strip().split()
        if not parts:
            continue
        t0 = time.monotonic()
        exit_code = main(parts)
        elapsed = int((time.monotonic() - t0) * 1000)
        ok = exit_code == 0
        overall_ok = overall_ok and ok
        results.append({"step": step, "exit_code": exit_code, "ms": elapsed})
        if not ok and stop_on_error:
            if human:
                print(f"\n✗ Pipeline aborted at step: {step!r}\n")
            break

    if human:
        sym = "✓" if overall_ok else "✗"
        print(f"\n{sym} Pipeline finished — {sum(1 for r in results if r['exit_code']==0)}/{len(results)} steps OK")
    else:
        print(json.dumps({"status": "ok" if overall_ok else "error",
                          "steps": results, "passed": sum(1 for r in results if r["exit_code"]==0),
                          "total": len(results)}, ensure_ascii=False, indent=2))
    return 0 if overall_ok else 1


# ── Main ──────────────────────────────────────────────────────────────────────

def main(argv: list[str] | None = None) -> int:
    parser = build_parser()

    if argv is None:
        argv = sys.argv[1:]

    # Special top-level commands: health, pipeline
    if argv and argv[0] == "health":
        human = "--human" in argv
        return run_health(human)
    if argv and argv[0] == "pipeline":
        human = "--human" in argv
        stop = "--no-stop" not in argv
        steps = [a for a in argv[1:] if not a.startswith("--")]
        return run_pipeline(steps, human, stop_on_error=stop)

    # Support: cli.py godot --help (no action)
    if len(argv) >= 1 and argv[0] in TOOLS and (len(argv) == 1 or argv[1] in ("--help", "-h")):
        print_tool_help(argv[0])
        return 0

    args = parser.parse_args(argv)

    if args.action in ("help", "--help", "-h"):
        print_tool_help(args.tool)
        return 0

    # Build kwargs from parsed args (game tools only: godot, ollama, git)
    kwargs: dict[str, Any] = {
        # Godot
        "preset": getattr(args, "preset", None),
        "step":   getattr(args, "step",   None),
        "scene":  getattr(args, "scene",  None),
        # Ollama
        "model":  getattr(args, "model",  None),
        "prompt": getattr(args, "prompt", None),
        "system": getattr(args, "system", None),
        # Git
        "message": getattr(args, "message", None),
        "files":   getattr(args, "files",   None),
        "staged":  getattr(args, "staged",  False) or None,
        "number":  getattr(args, "number",  None),
    }
    # Remove None values to keep adapter signatures clean
    kwargs = {k: v for k, v in kwargs.items() if v is not None}

    try:
        adapter = _load_adapter(args.tool)
    except ValueError as exc:
        print(json.dumps({"status": "error", "error": str(exc)}))
        return 1

    result = adapter.execute(args.action, **kwargs)
    print_result(result, human=args.human)
    return 0 if result.get("status") == "ok" else 1


if __name__ == "__main__":
    sys.exit(main())
