#!/usr/bin/env python3
"""
CLI-Anything — Unified agent-native CLI dispatcher (16 tools).

Usage:
    python tools/cli.py <tool> <action> [--key value ...]
    python tools/cli.py health [--human]
    python tools/cli.py <tool>                # list actions

Examples:
    python tools/cli.py godot validate
    python tools/cli.py ollama list
    python tools/cli.py git status
    python tools/cli.py n8n list-workflows
    python tools/cli.py figma get-file --file_key abc123
    python tools/cli.py magic logo-search --query react
    python tools/cli.py mermaid render --input "flowchart LR; A-->B"
    python tools/cli.py context7 resolve-library --query lodash
    python tools/cli.py datagouv search-datasets --query transport

Output: JSON by default. Use --human for pretty-printed output.
Exit code: 0 = success, 1 = error (for CI/AUTODEV integration).
"""

from __future__ import annotations

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

from adapters import ADAPTER_REGISTRY, load_adapter, list_tools  # noqa: E402


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
        adapter = load_adapter(tool)
        actions = adapter.list_actions()
        print(f"\n{tool.upper()} — available actions:\n")
        for action, desc in actions.items():
            print(f"  {action:<20} {desc}")
        print()
    except Exception as exc:
        print(f"Could not load {tool} adapter: {exc}")


def print_global_help() -> None:
    tools = list_tools()
    print("\nCLI-Anything — available tools:\n")
    for t in tools:
        print(f"  {t}")
    print(f"\n  Total: {len(tools)} tools")
    print("\nUsage:")
    print("  python tools/cli.py <tool>              # list actions")
    print("  python tools/cli.py <tool> <action> ...  # run action")
    print("  python tools/cli.py health [--human]     # check all tools")
    print()


# ── Health check ─────────────────────────────────────────────────────────────

def run_health(human: bool) -> int:
    """Smoke-test every adapter with its health_probe action."""
    import time

    tools = list_tools()
    results = {}
    for tool in tools:
        t0 = time.monotonic()
        try:
            adapter = load_adapter(tool)
            probe_action, probe_kwargs = adapter.health_probe()
            result = adapter.execute(probe_action, **probe_kwargs)
            status = result.get("status", "error")
        except Exception as exc:
            status = "error"
            result = {"status": "error", "error": str(exc)}
        elapsed = int((time.monotonic() - t0) * 1000)
        results[tool] = {
            "status": status,
            "probe": probe_action if "probe_action" in dir() else "load",
            "ms": elapsed,
            "error": result.get("error"),
        }

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
            print(f"  {sym} {tool:<15} {r.get('probe', '?'):<20} {r['ms']}ms{err}")
        print()
    else:
        print(json.dumps(envelope, ensure_ascii=False, indent=2))
    return 0 if all_ok else 1


# ── Pipeline ──────────────────────────────────────────────────────────────────

def run_pipeline(steps: list[str], human: bool, stop_on_error: bool = True) -> int:
    """Execute a sequence of CLI steps (e.g. 'godot validate', 'git status')."""
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
        passed = sum(1 for r in results if r["exit_code"] == 0)
        print(f"\n{sym} Pipeline finished — {passed}/{len(results)} steps OK")
    else:
        print(json.dumps({
            "status": "ok" if overall_ok else "error",
            "steps": results,
            "passed": sum(1 for r in results if r["exit_code"] == 0),
            "total": len(results),
        }, ensure_ascii=False, indent=2))
    return 0 if overall_ok else 1


# ── Arg parsing (dynamic — no hardcoded tool args) ────────────────────────────

def parse_dynamic_args(argv: list[str]) -> tuple[str, str, dict[str, Any], bool]:
    """Parse: <tool> <action> [--key value ...] [--human]

    Returns (tool, action, kwargs, human).
    """
    human = False
    filtered = []
    i = 0
    while i < len(argv):
        if argv[i] == "--human":
            human = True
            i += 1
        elif argv[i] in ("--json",):
            i += 1  # skip, JSON is default
        else:
            filtered.append(argv[i])
            i += 1

    if not filtered:
        return "", "", {}, human

    tool = filtered[0]
    action = filtered[1] if len(filtered) > 1 else "help"

    # Positional arg after action (for godot export <preset>)
    kwargs: dict[str, Any] = {}
    rest = filtered[2:]

    i = 0
    while i < len(rest):
        arg = rest[i]
        if arg.startswith("--"):
            key = arg[2:].replace("-", "_")
            # Check if next arg is a value or another flag
            if i + 1 < len(rest) and not rest[i + 1].startswith("--"):
                kwargs[key] = rest[i + 1]
                i += 2
            else:
                kwargs[key] = True
                i += 1
        else:
            # Positional: map to 'preset' for backward compat (godot export web)
            kwargs["preset"] = arg
            i += 1

    return tool, action, kwargs, human


# ── Main ──────────────────────────────────────────────────────────────────────

def main(argv: list[str] | None = None) -> int:
    if argv is None:
        argv = sys.argv[1:]

    # Special top-level commands
    if not argv or argv[0] in ("--help", "-h"):
        print_global_help()
        return 0

    if argv[0] == "health":
        return run_health("--human" in argv)

    if argv[0] == "pipeline":
        human = "--human" in argv
        stop = "--no-stop" not in argv
        steps = [a for a in argv[1:] if not a.startswith("--")]
        return run_pipeline(steps, human, stop_on_error=stop)

    tool, action, kwargs, human = parse_dynamic_args(argv)

    # Validate tool name
    available = list_tools()
    if tool not in available:
        print(json.dumps({
            "status": "error",
            "error": f"Unknown tool: {tool!r}. Available: {', '.join(available)}",
        }))
        return 1

    # Help: just tool name or explicit help
    if action in ("help", "--help", "-h"):
        print_tool_help(tool)
        return 0

    try:
        adapter = load_adapter(tool)
    except Exception as exc:
        print(json.dumps({"status": "error", "error": str(exc)}))
        return 1

    result = adapter.execute(action, **kwargs)
    print_result(result, human=human)
    return 0 if result.get("status") == "ok" else 1


if __name__ == "__main__":
    sys.exit(main())
