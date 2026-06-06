"""Lance MerlinGame, capture l'intro, clique Accepter, puis capture la situation (encart central)
et la phase de choix (cartes montées). Vérifie le flow logique intro→situation→cartes. (user 2026-06-06)
    python tools/capture_merlin_flow.py [--ax X --ay Y]   (coords du bouton Accepter)
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

import win32api
import win32con
import win32gui
from PIL import ImageGrab

GODOT = r"C:/Users/PGNK2128/Godot/Godot_v4.5.1-stable_win64_console.exe"
REPO = r"C:/Users/PGNK2128/Godot-MCP"
OUT = Path(r"C:/Users/PGNK2128/Downloads")


def focus_merlin() -> None:
    hwnds: list[int] = []

    def cb(h: int, _: object) -> None:
        if "MERLIN" in win32gui.GetWindowText(h) and win32gui.IsWindowVisible(h):
            hwnds.append(h)

    win32gui.EnumWindows(cb, None)
    if not hwnds:
        return
    win32api.keybd_event(0x12, 0, 0, 0)
    win32api.keybd_event(0x12, 0, win32con.KEYEVENTF_KEYUP, 0)
    try:
        win32gui.SetForegroundWindow(hwnds[0])
    except Exception:  # noqa: BLE001
        pass
    time.sleep(0.2)


def click(x: int, y: int) -> None:
    win32api.SetCursorPos((x, y))
    time.sleep(0.05)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(0.04)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)


def snap(name: str) -> Path:
    p = OUT / f"{name}.png"
    ImageGrab.grab().save(p)
    return p


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ax", type=int, default=1630)
    ap.add_argument("--ay", type=int, default=915)
    a = ap.parse_args()
    proc = subprocess.Popen(
        [GODOT, "--path", REPO, "res://scenes/MerlinGame.tscn"],
        cwd=REPO, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    try:
        time.sleep(9)
        print(snap("merlin_flow_1_intro"))
        focus_merlin()
        click(a.ax, a.ay)  # Accepter
        time.sleep(2.5)
        print(snap("merlin_flow_2_situation"))  # situation SEULE dans l'encart
        time.sleep(4.5)
        print(snap("merlin_flow_3_choice"))  # cartes montées pour le choix
        return 0
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except Exception:  # noqa: BLE001
            proc.kill()


if __name__ == "__main__":
    sys.exit(main())
