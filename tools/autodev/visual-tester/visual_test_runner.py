"""
Visual Test Runner — Launches Godot scenes and captures screenshots for AI analysis.
Usage: python visual_test_runner.py --scene scenes/MerlinGame.tscn --duration 30
"""
import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
SCREENSHOT_DIR = PROJECT_ROOT / "scene_screenshots"
GODOT_PATH = "godot"  # Assumes godot is in PATH


def run_scene(scene_path: str, duration: int = 30) -> dict:
    """Launch a Godot scene with screenshot agent and capture screenshots."""
    SCREENSHOT_DIR.mkdir(exist_ok=True)

    # Clean previous screenshots
    for f in SCREENSHOT_DIR.glob("*.png"):
        f.unlink()
    meta_file = SCREENSHOT_DIR / "session_meta.json"
    if meta_file.exists():
        meta_file.unlink()

    print(f"[VisualTest] Launching scene: {scene_path} for {duration}s")

    # Run Godot with the scene
    # The screenshot_agent.gd should be registered as autoload or injected
    cmd = [
        GODOT_PATH,
        "--path", str(PROJECT_ROOT),
        scene_path,
        "--quit-after", str(duration * 1000),  # milliseconds
    ]

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=duration + 30,
            cwd=str(PROJECT_ROOT),
        )
        print(f"[VisualTest] Godot exited with code {proc.returncode}")
        if proc.stderr:
            # Filter for errors only
            errors = [line for line in proc.stderr.splitlines()
                      if "ERROR" in line or "SCRIPT ERROR" in line]
            if errors:
                print(f"[VisualTest] Errors found: {len(errors)}")
                for e in errors[:10]:
                    print(f"  {e}")
    except subprocess.TimeoutExpired:
        print(f"[VisualTest] Timeout after {duration + 30}s")
    except FileNotFoundError:
        print(f"[VisualTest] Godot not found at: {GODOT_PATH}")
        return {"error": "Godot not found", "screenshots": []}

    # Collect results
    screenshots = sorted(SCREENSHOT_DIR.glob("*.png"))
    meta = {}
    if meta_file.exists():
        with open(meta_file) as f:
            meta = json.load(f)

    result = {
        "scene": scene_path,
        "duration": duration,
        "screenshot_count": len(screenshots),
        "screenshots": [str(s.name) for s in screenshots],
        "meta": meta,
        "godot_errors": errors if 'errors' in dir() else [],
    }

    # Save result
    result_file = SCREENSHOT_DIR / "test_result.json"
    with open(result_file, "w") as f:
        json.dump(result, f, indent=2)

    print(f"[VisualTest] Captured {len(screenshots)} screenshots")
    return result


def main():
    parser = argparse.ArgumentParser(description="Visual Test Runner for M.E.R.L.I.N.")
    parser.add_argument("--scene", required=True, help="Scene path (e.g., scenes/MerlinGame.tscn)")
    parser.add_argument("--duration", type=int, default=30, help="Duration in seconds (default: 30)")
    parser.add_argument("--godot", default="godot", help="Path to Godot executable")
    args = parser.parse_args()

    global GODOT_PATH
    GODOT_PATH = args.godot

    result = run_scene(args.scene, args.duration)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
