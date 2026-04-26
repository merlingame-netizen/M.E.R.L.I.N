"""Aggregate the last N MerlinMetrics run JSONs and print a 5-dimension
adherence summary in the console. See docs/PLAYER_ADHERENCE_MATRIX.md.

Usage:
    python tools/merlin_metrics_summary.py [--last N] [--dir PATH]

Reads *.json from the user-data dir (default
%APPDATA%/Godot/app_userdata/MERLIN/run_metrics/) and emits a star-rated
report against the matrix targets.
"""

from __future__ import annotations

import argparse
import io
import json
import os
import statistics
import sys
from pathlib import Path
from typing import Any

# Force UTF-8 stdout on Windows so any unicode chars (em-dash etc.) survive cp1252.
if sys.platform == "win32" and hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

# -- Adherence matrix targets (mirror docs/PLAYER_ADHERENCE_MATRIX.md) --
TARGETS: dict[str, dict[str, tuple[float, float, float]]] = {
    "rythm": {
        "avg_card_duration_s": (35.0, 20.0, 60.0),
        "avg_encounter_interval_s": (90.0, 60.0, 150.0),
    },
    "clarity": {
        "avg_choice_latency_s": (6.0, 2.0, 15.0),
        "axis_diversity_avg": (3.0, 2.0, 3.0),
        "cards_with_risk_hint_pct": (95.0, 80.0, 100.0),
    },
    "tension": {
        "critical_pct": (0.30, 0.10, 0.40),
        "success_pct": (0.40, 0.30, 0.55),
        "failure_pct": (0.20, 0.10, 0.40),
        "critical_failure_pct": (0.10, 0.0, 0.25),
    },
    "progression": {
        "xp_gained_total": (60.0, 30.0, 120.0),
    },
    "performance": {
        "fps_avg": (60.0, 45.0, 60.0),
        "fps_p99": (45.0, 30.0, 60.0),
        "frame_time_max_ms": (22.0, 0.0, 50.0),
    },
}


def _default_metrics_dir() -> Path:
    if sys.platform == "win32":
        appdata = os.environ.get("APPDATA", "")
        if appdata:
            return Path(appdata) / "Godot" / "app_userdata" / "MERLIN" / "run_metrics"
    return Path.home() / ".local" / "share" / "godot" / "app_userdata" / "MERLIN" / "run_metrics"


def _load_recent(metrics_dir: Path, n: int) -> list[dict]:
    if not metrics_dir.exists():
        return []
    files = sorted(metrics_dir.glob("run_metrics_*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    runs: list[dict] = []
    for f in files[:n]:
        try:
            with open(f, encoding="utf-8") as fh:
                runs.append(json.load(fh))
        except (OSError, json.JSONDecodeError) as exc:
            print(f"  !  skipping {f.name}: {exc}")
    return runs


def _avg(vals: list[float]) -> float:
    return statistics.mean(vals) if vals else 0.0


def _score(value: float, target: float, lo: float, hi: float) -> int:
    """Return star rating 1-5 based on closeness to target within [lo, hi]."""
    if value < lo or value > hi:
        return 1
    if abs(value - target) <= (hi - lo) * 0.10:
        return 5
    if abs(value - target) <= (hi - lo) * 0.20:
        return 4
    if abs(value - target) <= (hi - lo) * 0.35:
        return 3
    return 2


def _stars(rating: int) -> str:
    return "*" * rating + "." * (5 - rating)


def _aggregate(runs: list[dict]) -> dict[str, dict[str, float]]:
    out: dict[str, dict[str, float]] = {}
    for dim in TARGETS:
        out[dim] = {}
        for metric in TARGETS[dim]:
            vals: list[float] = []
            for r in runs:
                section = r.get(dim, {})
                if metric.endswith("_pct"):
                    base_key = metric[:-4]
                    dist = (section.get("resolution_distribution") or {}) if dim == "tension" else {}
                    vals.append(float(dist.get(base_key, 0)))
                else:
                    vals.append(float(section.get(metric, 0)))
            out[dim][metric] = _avg(vals)
    return out


def _emit_report(runs: list[dict], metrics_dir: Path) -> None:
    print(f"[METRICS] Run Adherence — last {len(runs)} runs ({metrics_dir})")
    print("-" * 65)
    if not runs:
        print("  No runs found. Play a Brocéliande run with MerlinMetrics autoload.")
        return
    aggregates = _aggregate(runs)
    issues: list[str] = []
    for dim, metrics in TARGETS.items():
        ratings: list[int] = []
        details: list[str] = []
        for metric, (target, lo, hi) in metrics.items():
            value = aggregates[dim][metric]
            rating = _score(value, target, lo, hi)
            ratings.append(rating)
            if rating <= 2:
                issues.append(f"{dim}.{metric} = {value:.2f} (target {target}, range [{lo}..{hi}])")
            details.append(f"{metric}={value:.2f}")
        avg_rating = round(_avg([float(r) for r in ratings]))
        print(f"{dim.capitalize():<12} : {_stars(avg_rating)} ({avg_rating}/5)  —  {' • '.join(details)}")
    if issues:
        print("\n!  Action items:")
        for issue in issues:
            print(f"  • {issue}")
    else:
        print("\n[OK] All dimensions on target.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--last", type=int, default=5, help="Number of most recent runs to aggregate (default 5)")
    parser.add_argument("--dir", type=str, default="", help="Metrics directory (default: %APPDATA%/Godot/MERLIN/run_metrics/)")
    args = parser.parse_args()
    metrics_dir = Path(args.dir) if args.dir else _default_metrics_dir()
    runs = _load_recent(metrics_dir, args.last)
    _emit_report(runs, metrics_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
