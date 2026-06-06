"""Drive MERLIN Godot window via Win32 SendInput + screenshot bursts to catch the
v10.2 cinematic fusion animation. (user 2026-06-06 "test toi meme et donne moi le rendu")"""
from __future__ import annotations

import argparse
import time
from pathlib import Path

import win32api
import win32con
import win32gui
from PIL import ImageGrab

OUT_DIR = Path("C:/Users/PGNK2128/Downloads")


def focus_merlin() -> int:
    """Return the MERLIN window handle, focused. Raises if not found.

    Windows refuses cross-process SetForegroundWindow without an input event since the
    foreground lock. The Alt-tap trick releases the lock for the duration of the call.
    """
    hwnds: list[tuple[int, str]] = []

    def cb(hwnd: int, _: object) -> None:
        title = win32gui.GetWindowText(hwnd)
        if "MERLIN" in title and win32gui.IsWindowVisible(hwnd):
            hwnds.append((hwnd, title))

    win32gui.EnumWindows(cb, None)
    if not hwnds:
        raise RuntimeError("MERLIN window not found")
    hwnd = hwnds[0][0]
    win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
    # Alt-tap trick: triggers the foreground-lock release for this thread.
    win32api.keybd_event(0x12, 0, 0, 0)  # Alt down
    win32api.keybd_event(0x12, 0, win32con.KEYEVENTF_KEYUP, 0)
    try:
        win32gui.SetForegroundWindow(hwnd)
    except Exception:  # GPO can still block, we still try the click
        pass
    time.sleep(0.20)
    return hwnd


def click(x: int, y: int) -> None:
    """Move cursor to (x, y) and left-click."""
    win32api.SetCursorPos((x, y))
    time.sleep(0.06)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(0.04)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)


def snap(name: str) -> Path:
    """Grab the primary screen, save to Downloads as <name>.png, return path."""
    out = OUT_DIR / f"{name}.png"
    ImageGrab.grab().save(out)
    return out


def burst(prefix: str, count: int, interval: float) -> list[Path]:
    """Take `count` screenshots spaced by `interval` seconds; return all paths."""
    paths: list[Path] = []
    for i in range(count):
        paths.append(snap(f"{prefix}_{i:02d}"))
        if i < count - 1:
            time.sleep(interval)
    return paths


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("action", choices=["snap", "click", "burst", "focus"])
    ap.add_argument("--x", type=int, default=0)
    ap.add_argument("--y", type=int, default=0)
    ap.add_argument("--name", default="merlin_snap")
    ap.add_argument("--count", type=int, default=6)
    ap.add_argument("--interval", type=float, default=0.35)
    args = ap.parse_args()

    if args.action == "focus":
        focus_merlin()
        print("focused")
    elif args.action == "snap":
        focus_merlin()
        time.sleep(0.4)
        p = snap(args.name)
        print(p)
    elif args.action == "click":
        focus_merlin()
        time.sleep(0.4)
        click(args.x, args.y)
        print(f"clicked ({args.x}, {args.y})")
    elif args.action == "burst":
        focus_merlin()
        time.sleep(0.3)
        paths = burst(args.name, args.count, args.interval)
        for p in paths:
            print(p)


if __name__ == "__main__":
    main()
