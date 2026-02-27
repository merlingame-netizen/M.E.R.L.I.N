#!/usr/bin/env python3
"""
M.E.R.L.I.N. — Training Watcher
Monitors CPU/RAM usage of the LoRA training process.
Supports pause/resume and auto-throttle if resources exceed thresholds.

Usage:
  python train_watcher.py                                # Auto-detect training
  python train_watcher.py --output-dir ./merlin-lora-cpu-output
  python train_watcher.py --max-cpu 60 --max-ram 80      # Alert thresholds (%)
  python train_watcher.py --auto-pause                   # Auto-pause if thresholds exceeded

Requirements:
  pip install psutil
"""

import argparse
import json
import os
import signal
import sys
import time
from pathlib import Path

try:
    import psutil
except ImportError:
    print("ERREUR: psutil requis — pip install psutil")
    sys.exit(1)


def find_progress_file(output_dir: str) -> str:
    """Locate progress.json from training output dir."""
    candidates = [
        Path(output_dir) / "progress.json",
        Path("merlin-lora-cpu-output") / "progress.json",
        Path(__file__).parent.parent.parent / "merlin-lora-cpu-output" / "progress.json",
    ]
    for p in candidates:
        if p.exists():
            return str(p.resolve())
    return ""


def read_progress(path: str) -> dict:
    """Read progress.json safely (atomic write from trainer)."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, FileNotFoundError, PermissionError):
        return {}


def fetch_remote_progress(url: str) -> dict:
    """Fetch progress from remote HTTP endpoint (Colab ngrok)."""
    try:
        import urllib.request
        req = urllib.request.Request(url, headers={"ngrok-skip-browser-warning": "1"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception:
        return {}


def find_training_process() -> psutil.Process | None:
    """Find the running train_qwen_cpu.py process."""
    for proc in psutil.process_iter(["pid", "name", "cmdline"]):
        try:
            cmdline = proc.info.get("cmdline") or []
            if any("train_qwen_cpu" in str(c) for c in cmdline):
                return proc
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return None


def format_duration(seconds: float) -> str:
    """Format seconds to human-readable HhMM."""
    if seconds <= 0:
        return "--"
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    if h > 0:
        return f"{h}h{m:02d}min"
    return f"{m}min"


def bar(pct: float, width: int = 30) -> str:
    """ASCII progress bar."""
    filled = int(width * pct / 100)
    return f"[{'#' * filled}{'.' * (width - filled)}] {pct:.1f}%"


def clear_line():
    """Clear current terminal line."""
    sys.stdout.write("\r" + " " * 100 + "\r")
    sys.stdout.flush()


def main():
    parser = argparse.ArgumentParser(description="M.E.R.L.I.N. Training Watcher")
    parser.add_argument("--output-dir", type=str, default="./merlin-lora-cpu-output",
                        help="Training output dir (contains progress.json)")
    parser.add_argument("--max-cpu", type=float, default=70.0,
                        help="CPU %% alert threshold (default 70)")
    parser.add_argument("--max-ram", type=float, default=85.0,
                        help="RAM %% alert threshold (default 85)")
    parser.add_argument("--interval", type=float, default=10.0,
                        help="Refresh interval in seconds (default 10)")
    parser.add_argument("--auto-pause", action="store_true",
                        help="Auto-pause training if CPU/RAM exceed thresholds")
    parser.add_argument("--url", type=str, default="",
                        help="Remote progress URL (e.g. https://XXXX.ngrok-free.app/progress)")
    args = parser.parse_args()

    remote_mode = bool(args.url)
    progress_path = "" if remote_mode else find_progress_file(args.output_dir)
    paused = False
    pause_count = 0
    alert_count = 0

    print(f"{'=' * 64}")
    print(f"  M.E.R.L.I.N. Training Watcher {'(REMOTE)' if remote_mode else '(LOCAL)'}")
    if remote_mode:
        print(f"  URL: {args.url}")
        print(f"  Auto-pause: N/A (remote)")
    else:
        print(f"  Auto-pause: {'ON' if args.auto_pause else 'OFF'}")
    print(f"  CPU threshold: {args.max_cpu}% | RAM threshold: {args.max_ram}%")
    print(f"  Interval: {args.interval}s | Press Ctrl+C to quit")
    if not remote_mode:
        if progress_path:
            print(f"  Progress: {progress_path}")
        else:
            print(f"  Progress: waiting for {args.output_dir}/progress.json ...")
    print(f"{'=' * 64}\n")

    try:
        while True:
            # --- Find training process ---
            proc = find_training_process()
            if not proc:
                print(f"  [{time.strftime('%H:%M:%S')}] Training process not found — waiting...")
                time.sleep(args.interval)
                # Re-check progress file
                if not progress_path:
                    progress_path = find_progress_file(args.output_dir)
                continue

            # --- System metrics ---
            try:
                cpu_pct = proc.cpu_percent(interval=1.0)
                mem_info = proc.memory_info()
                ram_mb = mem_info.rss / 1e6
                sys_ram = psutil.virtual_memory()
                sys_ram_pct = sys_ram.percent
                sys_cpu_pct = psutil.cpu_percent(interval=0)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                print(f"  [{time.strftime('%H:%M:%S')}] Process lost — waiting...")
                time.sleep(args.interval)
                continue

            # --- Training progress ---
            progress = {}
            if not progress_path:
                progress_path = find_progress_file(args.output_dir)
            if progress_path:
                progress = read_progress(progress_path)

            step = progress.get("step", "?")
            total = progress.get("total_steps", "?")
            pct = progress.get("pct", 0)
            epoch = progress.get("epoch", "?")
            total_epochs = progress.get("total_epochs", "?")
            loss = progress.get("loss", 0)
            eta_sec = progress.get("eta_sec", 0)
            status = progress.get("status", "unknown")

            # --- Display ---
            ts = time.strftime("%H:%M:%S")
            print(f"  [{ts}] {status.upper():<10} Step {step}/{total} (Epoch {epoch}/{total_epochs})")
            print(f"           {bar(pct)}")
            print(f"           Loss: {loss:.4f} | ETA: {format_duration(eta_sec)}")
            print(f"           Process CPU: {cpu_pct:.0f}% | RAM: {ram_mb:.0f} MB")
            print(f"           System  CPU: {sys_cpu_pct:.0f}% | RAM: {sys_ram_pct:.0f}% ({sys_ram.available / 1e9:.1f} GB free)")

            # --- Alerts ---
            cpu_alert = sys_cpu_pct > args.max_cpu
            ram_alert = sys_ram_pct > args.max_ram

            if cpu_alert or ram_alert:
                alert_count += 1
                reasons = []
                if cpu_alert:
                    reasons.append(f"CPU {sys_cpu_pct:.0f}% > {args.max_cpu}%")
                if ram_alert:
                    reasons.append(f"RAM {sys_ram_pct:.0f}% > {args.max_ram}%")
                msg = " + ".join(reasons)
                print(f"    !! ALERT #{alert_count}: {msg}")

                if args.auto_pause and not paused:
                    try:
                        proc.suspend()
                        paused = True
                        pause_count += 1
                        print(f"    >> PAUSED (auto-pause #{pause_count}) — will resume when resources drop")
                    except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
                        print(f"    >> Could not pause: {e}")
            elif paused:
                # Resources back to normal — resume
                try:
                    proc.resume()
                    paused = False
                    print(f"    >> RESUMED (resources back to normal)")
                except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
                    print(f"    >> Could not resume: {e}")
                    paused = False

            if status == "done":
                print(f"\n  Training COMPLETE! Elapsed: {format_duration(progress.get('elapsed_sec', 0))}")
                break

            print()  # Blank line between updates
            time.sleep(args.interval)

    except KeyboardInterrupt:
        print(f"\n\n  Watcher stopped. Training continues in background.")
        if paused:
            try:
                proc = find_training_process()
                if proc:
                    proc.resume()
                    print(f"  Training RESUMED before exit.")
            except Exception:
                pass
        print(f"  Alerts: {alert_count} | Auto-pauses: {pause_count}")


if __name__ == "__main__":
    main()
