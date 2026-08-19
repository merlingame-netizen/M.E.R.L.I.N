#!/usr/bin/env python3
"""Gate de la chaîne auto : « 24/7 sauf quand Maxime joue, reprise 10 min après ».

Témoin : chaque appel où le jeu tourne écrit un horodatage ; la chaîne n'a le
droit de tourner que si le jeu est éteint ET que le dernier jeu vu remonte à
plus de GRACE_S secondes. Utilisé par le codeur local, le corpus nocturne et
tout agent gourmand. Stdlib seule, ne lève jamais.
"""
from __future__ import annotations

import socket
import subprocess
import time
from pathlib import Path

WITNESS = Path.home() / ".cache" / "merlin-game" / "last-seen-playing"
GRACE_S = 600


def game_running() -> bool:
    s = socket.socket()
    s.settimeout(0.4)
    try:
        if s.connect_ex(("127.0.0.1", 5900)) == 0:
            return True
    finally:
        s.close()
    # Un Godot HEADLESS (laboratoire du récit, sondes) n'ouvre jamais le port
    # VNC : le braséro de 08:00 a rechargé e4b dans Ollama en plein milieu
    # d'une intro du labo — écriture mesurée à 1,77 tok/s au lieu de 9,5.
    # Tout Godot headless qui exécute un script mérite donc les 4 cœurs.
    try:
        r = subprocess.run(["pgrep", "-f", "godot.*--headless.*--script"],
                           capture_output=True, timeout=3)
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
