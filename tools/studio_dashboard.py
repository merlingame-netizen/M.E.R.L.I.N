#!/usr/bin/env python3
"""M.E.R.L.I.N. Studio Dashboard — runs all studio analysis tools and prints a consolidated report.

Usage: python tools/studio_dashboard.py
"""

import json
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOLS_DIR = ROOT / "tools"
PYTHON = sys.executable

# Tool definitions: (key, script, display_name)
TOOLS = [
    ("cards", "card_audit.py", "Cards"),
    ("tradeoffs", "tradeoff_audit.py", "Trade-offs"),
    ("verbs", "verb_coverage.py", "Verb coverage"),
    ("difficulty", "difficulty_curve.py", "Difficulty"),
    ("integration", "integration_check.py", "Integration"),
    ("visual", "visual_audit.py", "Visual"),
    ("perf", "perf_audit.py", "Performance"),
]

WIDTH = 52


def run_tool(script: str) -> tuple[str, int]:
    """Run a tool as subprocess, return (stdout, returncode)."""
    path = TOOLS_DIR / script
    if not path.exists():
        return "", -1
    try:
        result = subprocess.run(
            [PYTHON, str(path)],
            capture_output=True,
            text=True,
            timeout=120,
            cwd=str(ROOT),
        )
        return result.stdout + result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        return "TIMEOUT", -2
    except OSError as e:
        return str(e), -3


def parse_cards(output: str) -> dict:
    """Extract card count and quality score from card_audit output."""
    info = {"count": "?", "score": "?", "status": "ok"}
    m = re.search(r"(\d+)\s+cards from", output)
    if m:
        info["count"] = m.group(1)
    m = re.search(r"Quality score:\s*(\d+)/100", output)
    if m:
        info["score"] = m.group(1)
        if int(m.group(1)) < 70:
            info["status"] = "warn"
    return info


def parse_tradeoffs(output: str) -> dict:
    """Extract coverage percentage and target from tradeoff_audit output."""
    info = {"coverage": "?", "target": "10%", "status": "ok"}
    m = re.search(r"Coverage:\s*([\d.]+)%", output)
    if m:
        info["coverage"] = f"{float(m.group(1)):.0f}%"
    m = re.search(r"Status:\s*(\S+)", output)
    if m:
        info["status"] = "ok" if m.group(1) == "OK" else "warn"
    return info


def parse_verbs(output: str) -> dict:
    """Extract verb coverage and unknown count from verb_coverage output."""
    info = {"coverage": "?", "unknown": "0", "status": "ok"}
    m = re.search(r"Coverage:\s*\d+/\d+.*?\((\d+)%\)", output)
    if m:
        info["coverage"] = f"{m.group(1)}%"
    m = re.search(r"UNKNOWN verbs\s*\((\d+)\)", output)
    if m:
        info["unknown"] = m.group(1)
        if int(m.group(1)) > 0:
            info["status"] = "warn"
    return info


def parse_difficulty(output: str) -> dict:
    """Extract overall average net impact from difficulty_curve output."""
    info = {"avg": "?", "target": "+/-5", "status": "ok"}
    m = re.search(r"Overall average net impact:\s*([+-]?[\d.]+)", output)
    if m:
        val = float(m.group(1))
        info["avg"] = f"{val:+.1f}"
        if abs(val) > 5:
            info["status"] = "warn"
    return info


def parse_integration(output: str) -> dict:
    """Extract pass/total and percentage from integration_check output."""
    info = {"pct": "?", "detail": "?", "status": "ok"}
    m = re.search(r"Score:\s*(\d+)/(\d+)\s*PASS.*?(\d+)\s*WARN.*?(\d+)\s*FAIL\s*\((\d+)%\)", output)
    if m:
        passed, total, warns, fails = m.group(1), m.group(2), m.group(3), m.group(4)
        info["pct"] = f"{m.group(5)}%"
        info["detail"] = f"{passed}/{total} PASS"
        if int(fails) > 0:
            info["status"] = "fail"
        elif int(warns) > 0:
            info["status"] = "warn"
    return info


def parse_json_score(output: str) -> dict:
    """Extract score from JSON output (visual_audit, perf_audit)."""
    info = {"score": "?", "status": "ok"}
    try:
        data = json.loads(output)
        summary = data.get("summary", data)
        score = summary.get("score", "?")
        info["score"] = str(score)
        if isinstance(score, (int, float)) and score < 70:
            info["status"] = "warn"
    except (json.JSONDecodeError, KeyError, TypeError):
        info["status"] = "error"
    return info


PARSERS = {
    "cards": parse_cards,
    "tradeoffs": parse_tradeoffs,
    "verbs": parse_verbs,
    "difficulty": parse_difficulty,
    "integration": parse_integration,
    "visual": parse_json_score,
    "perf": parse_json_score,
}

STATUS_ICON = {"ok": "v", "warn": "!", "fail": "X", "error": "?"}


def format_row(key: str, name: str, parsed: dict) -> str:
    """Format a single dashboard row."""
    icon = STATUS_ICON.get(parsed.get("status", "ok"), " ")
    if key == "cards":
        return f"  {name:<14s} {parsed['count']:>5s}    Quality: {parsed['score']}/100       {icon}"
    if key == "tradeoffs":
        return f"  {name:<14s} {parsed['coverage']:>5s}    Target: {parsed['target']}      {icon}"
    if key == "verbs":
        return f"  {name:<14s} {parsed['coverage']:>5s}    Unknown: {parsed['unknown']:<10s}   {icon}"
    if key == "difficulty":
        return f"  {name:<14s} {parsed['avg']:>5s}    Target: {parsed['target']}    {icon}"
    if key == "integration":
        return f"  {name:<14s} {parsed['pct']:>5s}    {parsed['detail']:<16s}  {icon}"
    if key in ("visual", "perf"):
        return f"  {name:<14s} {parsed['score']:>5s}/100                      {icon}"
    return f"  {name:<14s} ???"


def main() -> None:
    t0 = time.time()
    results: dict[str, dict] = {}
    warnings = 0
    ran = 0
    errors = 0

    for key, script, name in TOOLS:
        sys.stderr.write(f"  Running {name}...\r")
        sys.stderr.flush()
        output, rc = run_tool(script)

        if rc == -1:
            results[key] = {"status": "error", "score": "N/A"}
            errors += 1
            continue

        if rc < -1:
            results[key] = {"status": "error", "score": "ERR"}
            errors += 1
            continue

        ran += 1
        parser = PARSERS.get(key)
        parsed = parser(output) if parser else {"status": "ok"}
        results[key] = parsed

        if parsed.get("status") in ("warn", "fail"):
            warnings += 1

    elapsed = time.time() - t0
    sys.stderr.write(" " * 40 + "\r")

    # Print dashboard
    print(f"\n{'=' * WIDTH}")
    print(f"{'M.E.R.L.I.N. STUDIO DASHBOARD':^{WIDTH}}")
    print(f"{'=' * WIDTH}")

    for key, script, name in TOOLS:
        parsed = results.get(key, {})
        if parsed.get("status") == "error":
            icon = STATUS_ICON["error"]
            print(f"  {name:<14s} ERROR                            {icon}")
        else:
            print(format_row(key, name, parsed))

    print(f"{'-' * WIDTH}")
    print(f"  Ran: {ran}/{len(TOOLS)} tools  |  Warnings: {warnings}  |  "
          f"Errors: {errors}  |  {elapsed:.1f}s")
    print(f"{'=' * WIDTH}\n")

    sys.exit(1 if errors > 0 else 0)


if __name__ == "__main__":
    main()
