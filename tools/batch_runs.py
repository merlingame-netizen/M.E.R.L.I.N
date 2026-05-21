"""Batch-run the v731 simulator N times with different seeds, archiving
each JSON output to ~/Downloads/batch_runs/run_<seed>.json so the variety
report can compare them.

Usage:
    python tools/batch_runs.py                          # 10 runs, seeds 100..109
    python tools/batch_runs.py --count 20               # 20 runs
    python tools/batch_runs.py --count 100 --start 1000 # 100 runs, seeds 1000..1099
    python tools/batch_runs.py --stitcher 0             # no LLM stitcher (faster)
    python tools/batch_runs.py --skip-existing          # resume interrupted batch

The simulator overwrites ``~/Downloads/merlin_human_run_test_v7.7.31.{html,json}``
each run, so we copy the JSON to the archive dir immediately after each
subprocess returns. Idempotent : skips seeds whose archive already exists
when ``--skip-existing`` is set.

After the batch completes, the variety report can be generated with :
    python tools/variety_report.py
"""

from __future__ import annotations

import argparse
import logging
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

log = logging.getLogger("batch_runs")

ROOT = Path(__file__).resolve().parent.parent
V731_SCRIPT = ROOT / "tools" / "simulate_human_run_v731.py"
RUN_OUTPUT_JSON = Path.home() / "Downloads" / "merlin_human_run_test_v7.7.31.json"
ARCHIVE_DIR = Path.home() / "Downloads" / "batch_runs"


def run_one(seed: int, stitcher: bool, timeout_s: int) -> tuple[bool, float]:
    """Run v731 once with the given seed. Returns (success, wall_time_s)."""
    env = dict(os.environ)
    env["MERLIN_SEED"] = str(seed)
    env["MERLIN_STITCHER"] = "1" if stitcher else "0"
    archive_path = ARCHIVE_DIR / f"run_{seed:04d}.json"

    t0 = time.time()
    try:
        result = subprocess.run(
            [sys.executable, str(V731_SCRIPT)],
            env=env,
            cwd=str(ROOT),
            timeout=timeout_s,
            capture_output=True,
            text=True,
        )
        elapsed = time.time() - t0
        if result.returncode != 0:
            log.warning(
                "seed=%d exit=%d in %.0fs : %s",
                seed,
                result.returncode,
                elapsed,
                (result.stderr or "")[-200:],
            )
            return False, elapsed
    except subprocess.TimeoutExpired:
        log.error("seed=%d TIMED OUT after %ds", seed, timeout_s)
        return False, time.time() - t0
    except Exception as exc:  # pragma: no cover
        log.error("seed=%d crashed: %s", seed, exc)
        return False, time.time() - t0

    if not RUN_OUTPUT_JSON.exists():
        log.error("seed=%d : v731 finished but %s missing", seed, RUN_OUTPUT_JSON)
        return False, elapsed
    try:
        shutil.copyfile(RUN_OUTPUT_JSON, archive_path)
        log.info("seed=%d : archived (%.0fs, %d bytes)", seed, elapsed, archive_path.stat().st_size)
        return True, elapsed
    except OSError as exc:
        log.error("seed=%d : copy failed : %s", seed, exc)
        return False, elapsed


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="[%(asctime)s] %(levelname)s %(message)s",
        datefmt="%H:%M:%S",
    )
    parser = argparse.ArgumentParser(description="Batch v731 runs for variety analysis")
    parser.add_argument("--count", type=int, default=10, help="Number of runs (default 10)")
    parser.add_argument("--start", type=int, default=100, help="First seed (default 100)")
    parser.add_argument("--stitcher", type=int, default=1, help="1=use LLM stitcher (default), 0=skip")
    parser.add_argument("--timeout", type=int, default=900, help="Per-run timeout in seconds (default 900)")
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="Skip seeds whose archive already exists (resume mode)",
    )
    args = parser.parse_args()

    if not V731_SCRIPT.exists():
        log.error("v731 script missing: %s", V731_SCRIPT)
        return 1

    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
    log.info("Archive dir: %s", ARCHIVE_DIR)

    seeds = list(range(args.start, args.start + args.count))
    succeeded = 0
    failed = 0
    skipped = 0
    t_batch = time.time()

    for i, seed in enumerate(seeds):
        archive_path = ARCHIVE_DIR / f"run_{seed:04d}.json"
        if args.skip_existing and archive_path.exists():
            log.info("seed=%d : skipped (archive exists)", seed)
            skipped += 1
            continue
        log.info("=== run %d/%d : seed=%d ===", i + 1, len(seeds), seed)
        ok, dur = run_one(seed, stitcher=bool(args.stitcher), timeout_s=args.timeout)
        if ok:
            succeeded += 1
        else:
            failed += 1
        eta_s = (time.time() - t_batch) / (i + 1) * (len(seeds) - i - 1)
        log.info(
            "  progress : ok=%d fail=%d skip=%d  ETA %.0fs",
            succeeded, failed, skipped, eta_s,
        )

    total = time.time() - t_batch
    log.info(
        "Batch done in %.0fs : succeeded=%d failed=%d skipped=%d",
        total, succeeded, failed, skipped,
    )
    log.info("Run variety report : python tools/variety_report.py")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
