#!/usr/bin/env python3
"""
asset_ledger/watchdog.py - M.E.R.L.I.N. disk pressure watchdog.

Monitors free disk space on the drive hosting the project root and reacts by
tiered thresholds: warn (log + report), critical (quarantine orphan assets
via cleanup.py, purge expired trash, purge the regenerable .godot/imported
cache). Independently, .godot/imported is purged whenever it grows past a
configurable size cap, regardless of the free-space tier.

Safety:
  - Defaults to dry-run (no destructive action) unless --enforce is passed.
  - --report never performs any action, only prints current state.
  - node_modules is NEVER auto-purged (needs `npm install` to restore); it is
    only ever reported as a manual suggestion.

Pure stdlib (Python 3.12).
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCAN_PY = HERE / "scan.py"
CLEANUP_PY = HERE / "cleanup.py"

CONFIG_DEFAULTS: dict[str, float] = {
    "warn_gb": 20,
    "critical_gb": 5,
    "godot_cache_gb": 2,
    "retention_days": 30,
}


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #

def human(n: int) -> str:
    f = float(n)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if f < 1024 or unit == "TB":
            return f"{f:.1f} {unit}" if unit != "B" else f"{int(f)} B"
        f /= 1024
    return f"{f:.1f} TB"


def drive_root(path: Path) -> Path:
    resolved = path.resolve()
    anchor = resolved.anchor or "C:\\"
    return Path(anchor)


def compute_dir_size(path: Path, budget_s: float = 8.0) -> tuple[int, bool]:
    """Time-bounded recursive size. Returns (bytes, complete?)."""
    total = 0
    start = time.time()
    complete = True
    for dp, _dn, fn in os_walk_safe(path):
        if time.time() - start > budget_s:
            complete = False
            break
        for f in fn:
            try:
                total += (Path(dp) / f).stat().st_size
            except OSError:
                pass
    return total, complete


def os_walk_safe(path: Path):
    import os
    if not path.exists():
        return []
    return os.walk(path)


# --------------------------------------------------------------------------- #
# Config
# --------------------------------------------------------------------------- #

def load_config(config_path: Path) -> dict[str, float]:
    cfg = dict(CONFIG_DEFAULTS)
    if config_path.exists():
        try:
            data = json.loads(config_path.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                for key in CONFIG_DEFAULTS:
                    if key in data:
                        cfg[key] = data[key]
        except (OSError, json.JSONDecodeError) as exc:
            print(f"WARNING: could not read {config_path}: {exc}", file=sys.stderr)
    else:
        config_path.parent.mkdir(parents=True, exist_ok=True)
        config_path.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")
        print(f"[watchdog] wrote default config to {config_path}", file=sys.stderr)
    return cfg


def classify_tier(free_gb: float, cfg: dict[str, float]) -> str:
    if free_gb < cfg["critical_gb"]:
        return "critical"
    if free_gb < cfg["warn_gb"]:
        return "warn"
    return "ok"


def load_disk_pressure(graph_path: Path, limit: int = 10) -> list[dict]:
    if not graph_path.exists():
        return []
    try:
        data = json.loads(graph_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    return data.get("disk_pressure", [])[:limit]


# --------------------------------------------------------------------------- #
# ALERTS.md logging
# --------------------------------------------------------------------------- #

def append_alert(root: Path, header: str, lines: list[str]) -> None:
    alerts_path = root / "docs" / "asset-ledger" / "ALERTS.md"
    alerts_path.parent.mkdir(parents=True, exist_ok=True)
    if not alerts_path.exists():
        alerts_path.write_text("# Asset Ledger Watchdog Alerts\n", encoding="utf-8")
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    block = [f"\n## {ts} - {header}\n"] + [f"- {line}" for line in lines] + [""]
    with open(alerts_path, "a", encoding="utf-8") as fh:
        fh.write("\n".join(block) + "\n")


# --------------------------------------------------------------------------- #
# Actions
# --------------------------------------------------------------------------- #

def purge_dir_contents(path: Path, dry_run: bool) -> tuple[int, list[str]]:
    """Delete the CONTENTS of path (never the folder itself). Regenerable
    caches only (e.g. .godot/imported)."""
    freed = 0
    actions: list[str] = []
    # Self-guard: this primitive may ONLY empty known regenerable caches, so a
    # future miscall cannot nuke an arbitrary directory.
    ALLOWED_SUFFIXES = (".godot/imported",)
    norm = str(path).replace("\\", "/").rstrip("/")
    if not any(norm.endswith(s) for s in ALLOWED_SUFFIXES):
        return 0, [f"REFUSED: purge_dir_contents only operates on {ALLOWED_SUFFIXES}, got {path}"]
    if not path.exists():
        return freed, actions
    count = 0
    failed = 0
    for child in sorted(path.iterdir()):
        try:
            if child.is_file():
                size = child.stat().st_size
            else:
                size = sum(f.stat().st_size for f in child.rglob("*") if f.is_file())
        except OSError:
            size = 0
        if dry_run:
            freed += size
            count += 1
            continue
        try:
            if child.is_dir():
                shutil.rmtree(child)
            else:
                child.unlink()
            freed += size
            count += 1
        except OSError as exc:
            failed += 1
            actions.append(f"FAILED to purge {child}: {exc}")
    # One summary line instead of one line per child (avoids huge logs).
    verb = "would purge" if dry_run else "purged"
    actions.insert(0, f"[{'dry-run' if dry_run else 'apply'}] {verb} {count} entries "
                      f"in {path} (~{human(freed)}){f', {failed} failed' if failed else ''}")
    return freed, actions


def run_subprocess_step(args: list[str], dry_run: bool) -> tuple[bool, str]:
    if dry_run:
        return True, f"[dry-run] would run: {' '.join(args)}"
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=600)
        output = (result.stdout[-1500:] + result.stderr[-1500:]).strip()
        return result.returncode == 0, output
    except (OSError, subprocess.SubprocessError) as exc:
        return False, str(exc)


def do_critical_actions(root: Path, retention_days: int, dry_run: bool) -> list[str]:
    log: list[str] = []
    py_exe = sys.executable

    ok, out = run_subprocess_step([py_exe, str(SCAN_PY), "--root", str(root)], dry_run)
    log.append(f"scan.py: {'OK' if ok else 'FAILED'} - {out[:300]}")

    ok, out = run_subprocess_step(
        [py_exe, str(CLEANUP_PY), "--root", str(root), "--auto"], dry_run
    )
    log.append(f"cleanup.py --auto: {'OK' if ok else 'FAILED'} - {out[:300]}")

    ok, out = run_subprocess_step(
        [py_exe, str(CLEANUP_PY), "--root", str(root),
         "--purge-trash", "--retention-days", str(retention_days)], dry_run
    )
    log.append(f"cleanup.py --purge-trash: {'OK' if ok else 'FAILED'} - {out[:300]}")

    freed, actions = purge_dir_contents(root / ".godot" / "imported", dry_run)
    log.append(f".godot/imported purge: freed~{human(freed)}")
    log.extend(actions)
    return log


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #

def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Disk pressure watchdog for the M.E.R.L.I.N. project (tiered response)."
    )
    parser.add_argument("--root", default=".", help="Project root (default: cwd)")
    parser.add_argument(
        "--config", default=None,
        help="Path to watchdog.config.json (default: <root>/docs/asset-ledger/watchdog.config.json)",
    )
    parser.add_argument("--report", action="store_true", help="Print state only, no action")
    parser.add_argument(
        "--enforce", action="store_true",
        help="Actually perform destructive actions (default is dry-run preview only)",
    )
    parser.add_argument("--dry-run", action="store_true", help="Explicit dry-run (default behavior)")
    parser.add_argument("--warn-gb", type=float, default=None)
    parser.add_argument("--critical-gb", type=float, default=None)
    parser.add_argument("--godot-cache-gb", type=float, default=None)
    parser.add_argument("--retention-days", type=int, default=None)
    return parser


def resolve_config(args: argparse.Namespace, config_path: Path) -> dict[str, float]:
    cfg = load_config(config_path)
    overrides = {
        "warn_gb": args.warn_gb,
        "critical_gb": args.critical_gb,
        "godot_cache_gb": args.godot_cache_gb,
        "retention_days": args.retention_days,
    }
    for key, value in overrides.items():
        if value is not None:
            cfg[key] = value
    return cfg


def print_report(root: Path, drive: Path, free_gb: float, tier: str, pressure: list[dict]) -> None:
    print(f"[watchdog] root={root}")
    print(f"[watchdog] drive={drive} free={free_gb:.2f} GB tier={tier}")
    if pressure:
        print("[watchdog] top disk_pressure entries (from graph.json):")
        for entry in pressure:
            print(
                f"  - {entry['path']}: {human(entry['size_bytes'])} "
                f"(regenerable={entry.get('regenerable')})"
            )
    else:
        print("[watchdog] no disk_pressure data available (run scan.py first)")


def main(argv: list[str] | None = None) -> int:
    args = build_arg_parser().parse_args(argv)
    root = Path(args.root).resolve()
    config_path = (
        Path(args.config).resolve() if args.config
        else root / "docs" / "asset-ledger" / "watchdog.config.json"
    )
    cfg = resolve_config(args, config_path)

    drive = drive_root(root)
    free_bytes = shutil.disk_usage(str(drive)).free
    free_gb = free_bytes / (1024 ** 3)
    tier = classify_tier(free_gb, cfg)

    graph_path = root / "docs" / "asset-ledger" / "graph.json"
    pressure = load_disk_pressure(graph_path)

    if args.report:
        print_report(root, drive, free_gb, tier, pressure)
        return 0

    # --dry-run always wins over --enforce (a safety flag must never be a no-op).
    dry_run = args.dry_run or not args.enforce
    print(
        f"[watchdog] drive={drive} free={free_gb:.2f} GB tier={tier} "
        f"dry_run={dry_run}", file=sys.stderr,
    )

    if tier in ("warn", "critical"):
        lines = [f"Free space {free_gb:.2f} GB below warn threshold {cfg['warn_gb']} GB"]
        for entry in pressure:
            lines.append(f"{entry['path']}: {human(entry['size_bytes'])}")
        append_alert(root, "WARNING" if tier == "warn" else "CRITICAL", lines)
        for line in lines:
            print(f"[watchdog] {line}", file=sys.stderr)

    if tier == "critical":
        print("[watchdog] CRITICAL tier: initiating remediation", file=sys.stderr)
        crit_log = do_critical_actions(root, int(cfg["retention_days"]), dry_run)
        for line in crit_log:
            print(f"[watchdog] {line}", file=sys.stderr)
        append_alert(root, "CRITICAL ACTIONS", crit_log)
        suggestion = (
            "node_modules directories are large but are NEVER auto-purged "
            "(restore requires `npm install`). Consider manual cleanup if still critical."
        )
        print(f"[watchdog] SUGGESTION: {suggestion}", file=sys.stderr)
        append_alert(root, "MANUAL SUGGESTION", [suggestion])

    godot_imported = root / ".godot" / "imported"
    if godot_imported.exists():
        size, _complete = compute_dir_size(godot_imported)
        cache_limit_bytes = cfg["godot_cache_gb"] * (1024 ** 3)
        if size > cache_limit_bytes:
            freed, actions = purge_dir_contents(godot_imported, dry_run)
            print(
                f"[watchdog] .godot/imported size {human(size)} > limit "
                f"{cfg['godot_cache_gb']} GB -> purge (freed~{human(freed)})",
                file=sys.stderr,
            )
            append_alert(
                root, ".godot/imported purge",
                [f"size={human(size)} limit={cfg['godot_cache_gb']}GB"] + actions,
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
