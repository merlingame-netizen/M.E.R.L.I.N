#!/usr/bin/env python3
"""
One-command launcher for the local TTS server — NO .bat / .ps1 needed.

On this machine .bat files can't be run, so this is the canonical way to start
Merlin's voice server. It:
  1. installs missing Python deps (Piper engine by default — fast on CPU, no torch),
  2. downloads the French Merlin voice if absent,
  3. opens the test page in your browser,
  4. starts the server.

Usage (from anywhere):
    python tools/voxcpm/serve.py
    python tools/voxcpm/serve.py --port 8810 --no-robot --no-open
    python tools/voxcpm/serve.py --voice fr_FR-gilles-low
    python tools/voxcpm/serve.py --engine voxcpm        # optional cloning engine

Stop with Ctrl+C.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import threading
import time
import webbrowser
from pathlib import Path

_HERE = Path(__file__).resolve().parent

# Deps for the default Piper engine (no torch).
_PIPER_DEPS = {
    "piper": "piper-tts",
    "fastapi": "fastapi",
    "uvicorn": "uvicorn",
    "soundfile": "soundfile",
    "numpy": "numpy",
}


def _log(msg: str) -> None:
    print(f"[serve] {msg}", flush=True)


def _pip_install(packages: list[str]) -> None:
    cmd = [sys.executable, "-m", "pip", "install", *packages]
    _log("pip install " + " ".join(packages) + " …")
    try:
        subprocess.check_call(cmd)
    except subprocess.CalledProcessError:
        _log("retry with --user …")
        subprocess.check_call([*cmd, "--user"])


def _ensure_deps(engine: str) -> None:
    missing = []
    for mod, pkg in _PIPER_DEPS.items():
        try:
            __import__(mod)
        except Exception:
            missing.append(pkg)
    if missing:
        _pip_install(missing)
    if engine == "voxcpm":
        try:
            __import__("voxcpm")
        except Exception:
            _log("Installing voxcpm (heavy — CPU is slow; GPU recommended) …")
            _pip_install(["voxcpm"])


def _ensure_piper_voice(voice: str) -> None:
    voices_dir = _HERE / "piper_voices"
    voices_dir.mkdir(parents=True, exist_ok=True)
    onnx = voices_dir / f"{voice}.onnx"
    if onnx.exists():
        _log(f"voice {voice} present.")
        return
    _log(f"downloading Piper voice {voice} …")
    try:
        subprocess.check_call([
            sys.executable, "-m", "piper.download_voices", voice,
            "--download-dir", str(voices_dir),
        ])
    except Exception as exc:  # noqa: BLE001
        _log(f"WARNING: voice download failed ({exc}).")
        _log("The server will still start and serve the page; synthesis needs the voice.")


def _open_browser_later(url: str, delay: float = 4.0) -> None:
    def _go() -> None:
        time.sleep(delay)
        try:
            webbrowser.open(url)
        except Exception:
            pass
    threading.Thread(target=_go, daemon=True).start()


def main() -> int:
    ap = argparse.ArgumentParser(description="Launch the local TTS server (no .bat).")
    ap.add_argument("--engine", choices=["piper", "voxcpm"], default=os.environ.get("VOXCPM_ENGINE", "piper"))
    ap.add_argument("--voice", default=os.environ.get("PIPER_MODEL", "fr_FR-tom-medium"))
    ap.add_argument("--port", type=int, default=int(os.environ.get("VOXCPM_PORT", "8808")))
    ap.add_argument("--host", default=os.environ.get("VOXCPM_HOST", "127.0.0.1"))
    ap.add_argument("--no-robot", action="store_true", help="disable the robot voice FX")
    ap.add_argument("--no-open", action="store_true", help="don't open the browser")
    args = ap.parse_args()

    # Configure the server via env BEFORE importing it (it reads env at import).
    os.environ["VOXCPM_ENGINE"] = args.engine
    os.environ["VOXCPM_PORT"] = str(args.port)
    os.environ["VOXCPM_HOST"] = args.host
    os.environ["PIPER_MODEL"] = args.voice
    if args.no_robot:
        os.environ["VOXCPM_ROBOT"] = "0"

    _log(f"engine={args.engine} voice={args.voice} host={args.host} port={args.port}")
    _ensure_deps(args.engine)
    if args.engine == "piper":
        _ensure_piper_voice(args.voice)

    url = f"http://{args.host}:{args.port}/"
    if not args.no_open:
        _log(f"opening {url} (in ~4s)")
        _open_browser_later(url)

    # Import after deps are guaranteed + env is set.
    sys.path.insert(0, str(_HERE))
    import server  # noqa: PLC0415

    _log("starting server — press Ctrl+C to stop.")
    try:
        server.main()
    except KeyboardInterrupt:
        _log("stopped.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
