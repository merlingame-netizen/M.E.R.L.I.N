#!/usr/bin/env python3
"""Gate de la chaîne auto : « 24/7 sauf quand Maxime joue, reprise 10 min après ».

Témoin : chaque appel où le jeu tourne écrit un horodatage ; la chaîne n'a le
droit de tourner que si le jeu est éteint ET que le dernier jeu vu remonte à
plus de GRACE_S secondes. Utilisé par le codeur local, le corpus nocturne et
tout agent gourmand. Stdlib seule, ne lève jamais.
"""
from __future__ import annotations

import os
import socket
import subprocess
import time
from pathlib import Path

WITNESS = Path.home() / ".cache" / "merlin-game" / "last-seen-playing"
HARNESS = Path.home() / ".cache" / "merlin-game" / "harness"
INNER_PID = Path.home() / ".cache" / "merlin-game" / "inner.pid"
GRACE_S = 600


def _inner_alive() -> bool:
    try:
        os.kill(int(INNER_PID.read_text().strip()), 0)
        return True
    except Exception:
        return False


def game_running() -> bool:
    # Un harnais (partie de la nuit, quête, sonde) tient le jeu même sans fenêtre ni port VNC :
    # game-stack.sh le note dans `harness` au lancement et l'efface à l'arrêt. On ne le croit que
    # si son processus VIT : un marqueur rassis (arrêt hors game-stack) bloquerait tout, sans fin.
    try:
        if HARNESS.is_file() and HARNESS.read_text().strip() and _inner_alive():
            return True
    except Exception:
        pass
    s = socket.socket()
    s.settimeout(0.4)
    try:
        if s.connect_ex(("127.0.0.1", 5900)) == 0:
            return True
    finally:
        s.close()
    # TOUT processus godot compte — pas seulement le headless. Le boot du jeu en
    # rendu réel charge DEUX cerveaux (6,2 + 4,3 Go) : le braséro qui réchauffe
    # e4b dans Ollama (6,1 Go) pendant ce boot l'a tué en OOM silencieux — mort
    # au milieu du chargement du Vif, trois fois de suite sur 40cb5188. Et le
    # laboratoire headless (2026-08-19 08:00) avait déjà subi le même piétinement
    # (écriture à 1,77 tok/s au lieu de 9,5). Sur cette VM, un godot qui tourne —
    # quel qu'il soit — mérite les 4 cœurs et la RAM.
    try:
        r = subprocess.run(["pgrep", "-x", "godot"], capture_output=True, timeout=3)
        if r.returncode == 0:
            return True
        r = subprocess.run(["pgrep", "-f", "bin/godot"], capture_output=True, timeout=3)
        return r.returncode == 0
    except Exception:
        return False


def chain_allowed() -> tuple[bool, str]:
    """(autorisé, raison). Écrit le témoin en passant."""
    try:
        if game_running():
            WITNESS.parent.mkdir(parents=True, exist_ok=True)
            WITNESS.write_text(str(int(time.time())))
            return False, "jeu en cours — la chaîne cède les 4 cœurs"
        last = int(WITNESS.read_text().strip()) if WITNESS.exists() else 0
        idle = int(time.time()) - last
        if idle < GRACE_S:
            return False, f"jeu quitté il y a {idle // 60} min — reprise à +10 min"
        return True, "voie libre"
    except Exception as exc:
        return True, f"gate illisible ({exc}) — on laisse passer"


if __name__ == "__main__":
    ok, why = chain_allowed()
    print(("OK " if ok else "STOP ") + why)
    raise SystemExit(0 if ok else 1)
