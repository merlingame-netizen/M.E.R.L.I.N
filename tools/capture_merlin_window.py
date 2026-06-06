"""Lance MerlinGame en fenêtré, attend le pop-up d'intro, capture l'écran en PNG, puis ferme.
Permet de vérifier le rendu in-game (ouverture narrative + UI) sans pilotage Win32. (user 2026-06-06)
    python tools/capture_merlin_window.py
"""
from __future__ import annotations

import subprocess
import sys
import time
from pathlib import Path

GODOT = r"C:/Users/PGNK2128/Godot/Godot_v4.5.1-stable_win64_console.exe"
REPO = r"C:/Users/PGNK2128/Godot-MCP"
OUT = Path(r"C:/Users/PGNK2128/Downloads/merlin_ingame_intro.png")


def main() -> int:
    proc = subprocess.Popen(
        [GODOT, "--path", REPO, "res://scenes/MerlinGame.tscn"],
        cwd=REPO,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        time.sleep(9)  # laisse la scène booter + le pop-up d'intro s'animer
        try:
            from PIL import ImageGrab
        except Exception as e:  # noqa: BLE001
            print(f"NO_PIL: {e}")
            return 2
        try:
            img = ImageGrab.grab()
        except Exception as e:  # noqa: BLE001
            print(f"GRAB_FAILED (pas de display ?): {e}")
            return 3
        img.save(OUT)
        extrema = img.convert("L").getextrema()
        print(f"SAVED {OUT} size={img.size} luma_extrema={extrema}")
        if extrema[1] - extrema[0] < 8:
            print("WARNING: image quasi uniforme (probablement noir / pas de rendu reel)")
        return 0
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except Exception:  # noqa: BLE001
            proc.kill()


if __name__ == "__main__":
    sys.exit(main())
