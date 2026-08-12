#!/usr/bin/env python3
"""Playtest bot — joue RÉELLEMENT au jeu via VNC et juge par heuristiques.

Ce que personne d'autre n'a : le jeu tourne RENDU sur la VM (Xvfb + x11vnc
-nopw), donc un client RFB de ~60 lignes suffit pour injecter clics et touches,
et la chaîne xwd existante fournit les captures. Aucun LLM : les heuristiques
sont déterministes (décision Maxime) —
    NOIR    l'écran reste sombre après le boot        (luminance moyenne)
    FIGÉ    K interactions sans un pixel qui bouge    (empreinte d'écran)
    MORT    le jeu disparaît en cours de session      (socket/port)
Chaque anomalie devient une carte Décider (kind=bug) avec ses captures.
Le jugement « est-ce beau, est-ce amusant » reste humain : la pellicule de la
session est gardée dans ~/.cache/merlin-agents/playtest/.
"""
from __future__ import annotations

import hashlib
import json
import socket
import struct
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import proposals as PROP   # noqa: E402

SHOTS = Path.home() / ".cache" / "merlin-agents" / "playtest"
SYSROOT = Path.home() / "opt" / "gamestack" / "sysroot"
XWD2PNG = HERE.parents[1] / "infra" / "oracle" / "game" / "xwd2png.py"
FROZEN_K = 4          # interactions identiques avant verdict FIGÉ
BLACK_MEAN = 12       # luminance moyenne sous laquelle l'écran est « noir »


class Vnc:
    """Client RFB 3.8 minimal — injection d'événements seulement (pas de framebuffer)."""

    def __init__(self, host="127.0.0.1", port=5900):
        self.s = socket.create_connection((host, port), timeout=8)
        ver = self.s.recv(12)                                   # "RFB 003.008\n"
        self.s.sendall(ver)
        n = self.s.recv(1)[0]                                   # types de sécurité
        types = self.s.recv(n)
        if 1 not in types:
            raise RuntimeError(f"VNC exige une auth ({list(types)}) — attendu -nopw")
        self.s.sendall(b"\x01")
        if struct.unpack(">I", self.s.recv(4))[0] != 0:
            raise RuntimeError("SecurityResult != OK")
        self.s.sendall(b"\x01")                                 # ClientInit shared
        head = self.s.recv(24)
        self.w, self.h = struct.unpack(">HH", head[:4])
        self.s.recv(struct.unpack(">I", head[20:24])[0])        # nom du bureau

    def click(self, fx: float, fy: float):
        x, y = int(self.w * fx), int(self.h * fy)
        for mask in (0, 1, 0):                                  # move, press, release
            self.s.sendall(struct.pack(">BBHH", 5, mask, x, y))
            time.sleep(0.12)

    def key(self, keysym: int):
        for down in (1, 0):
            self.s.sendall(struct.pack(">BBxxI", 4, down, keysym))
            time.sleep(0.08)

    def close(self):
        try:
            self.s.close()
        except Exception:
            pass


def _game_up() -> bool:
    s = socket.socket()
    s.settimeout(0.5)
    try:
        return s.connect_ex(("127.0.0.1", 5900)) == 0
    finally:
        s.close()


def _capture(tag: str) -> tuple[Path | None, float, str]:
    """(png, luminance moyenne, empreinte). Analyse le XWD brut — zéro dépendance."""
    SHOTS.mkdir(parents=True, exist_ok=True)
    xwd = SHOTS / f"{tag}.xwd"
    png = SHOTS / f"{tag}.png"
    env = {"DISPLAY": ":99",
           "LD_LIBRARY_PATH": f"{SYSROOT}/usr/lib64:{SYSROOT}/usr/lib"}
    try:
        import os
        with xwd.open("wb") as f:
            subprocess.run([str(SYSROOT / "usr" / "bin" / "xwd"), "-root", "-silent"],
                           stdout=f, env={**os.environ, **env}, timeout=25, check=True)
        raw = xwd.read_bytes()
        hdr = struct.unpack(">I", raw[:4])[0]
        px = raw[hdr + 2048:]                    # après header + colormap éventuelle
        sample = px[::997][:12000]               # échantillon épars
        mean = sum(sample) / max(1, len(sample))
        fp = hashlib.sha1(px[::211]).hexdigest()[:16]
        subprocess.run([sys.executable, str(XWD2PNG), str(xwd), str(png), "--every", "2"],
                       capture_output=True, timeout=30)
        xwd.unlink(missing_ok=True)
        return (png if png.exists() else None), mean, fp
    except Exception:
        xwd.unlink(missing_ok=True)
        return None, -1.0, ""


# Le parcours : centre (démarrer/valider), les trois tiers bas (les 3 options),
# Entrée et Échap — les gestes universels de l'UI du jeu.
WALK = [("click", 0.5, 0.55), ("key", 0xFF0D), ("click", 0.25, 0.75),
        ("click", 0.5, 0.75), ("click", 0.75, 0.75), ("key", 0xFF1B),
        ("click", 0.5, 0.45), ("key", 0xFF0D)]


def run(steps: int = 16, session: str | None = None) -> str:
    if not _game_up():
        return "jeu éteint — le bot ne démarre pas le jeu lui-même (wrapper s'en charge)"
    tag = session or time.strftime("%Y%m%d-%H%M")
    anomalies: list[dict] = []
    v = Vnc()
    _, mean0, fp = _capture(f"{tag}-00")
    same, shots = 0, 1
    if 0 <= mean0 < BLACK_MEAN:
        time.sleep(6)                            # le boot peut être en cours
        _, mean0, fp = _capture(f"{tag}-00b")
        if 0 <= mean0 < BLACK_MEAN:
            anomalies.append({"type": "NOIR", "step": 0,
                              "detail": f"luminance {mean0:.0f} après boot",
                              "shot": f"{tag}-00b.png"})
    # La pellicule : on garde ce que chaque écran valait. L'empreinte et la
    # luminance étaient DÉJÀ calculées à chaque pas — et jetées. Les conserver
    # permet de retenir les 3 écrans qui racontent la session, au lieu du dernier
    # pris au hasard.
    pellicule = [{"i": 0, "luminance": round(mean0, 1), "empreinte": fp,
                  "change": 0.0, "png": f"{tag}-00.png"}]
    for i in range(1, steps + 1):
        kind, *args = WALK[(i - 1) % len(WALK)]
        try:
            (v.click(*args) if kind == "click" else v.key(args[0]))
        except Exception as exc:
            anomalies.append({"type": "MORT", "step": i,
                              "detail": f"connexion perdue : {exc}"[:90], "shot": ""})
            break
        time.sleep(1.8)
        _, mean, fp2 = _capture(f"{tag}-{i:02d}")
        shots += 1
        # « À quel point l'écran a-t-il changé » : distance de Hamming entre les
        # deux empreintes, normalisée. C'est ce qui repère le vrai basculement.
        saut = (sum(1 for a, b in zip(fp or "", fp2 or "") if a != b)
                / max(1, len(fp2 or "1"))) if (fp and fp2) else 1.0
        pellicule.append({"i": i, "luminance": round(mean, 1), "empreinte": fp2,
                          "change": round(saut, 3), "png": f"{tag}-{i:02d}.png"})
        if fp2 and fp2 == fp:
            same += 1
            if same == FROZEN_K:
                anomalies.append({"type": "FIGÉ", "step": i,
                                  "detail": f"{FROZEN_K} interactions sans changement",
                                  "shot": f"{tag}-{i:02d}.png"})
        else:
            same = 0
        fp = fp2 or fp
        if not _game_up():
            anomalies.append({"type": "MORT", "step": i,
                              "detail": "le port VNC a disparu en cours de session",
                              "shot": ""})
            break
    v.close()

    # ── Les 3 écrans qui racontent la session ──────────────────────────────
    # Le premier (d'où l'on part), celui du plus grand basculement (ce qui s'est
    # passé), celui de l'anomalie ou le dernier (où l'on a fini). Copiés HORS de
    # .cache : sinon le chapitre de la semaine dernière pointera vers des PNG
    # purgés à 200, et le journal montrerait des cadres vides.
    try:
        import shutil
        vues = Path.home() / "merlin-memory" / "journal" / "vues"
        vues.mkdir(parents=True, exist_ok=True)
        pivot = max(pellicule[1:], key=lambda p: p["change"], default=pellicule[0])
        fin = next((p for p in pellicule if p["png"] == (anomalies[0].get("shot") if anomalies else None)),
                   pellicule[-1])
        cles, vus = [], set()
        for p in (pellicule[0], pivot, fin):
            if p["png"] in vus:
                continue
            vus.add(p["png"])
            src = SHOTS / p["png"]
            if src.exists():
                shutil.copy2(src, vues / p["png"])
                cles.append(p["png"])
        (vues / f"{tag}.json").write_text(json.dumps(
            {"tag": tag, "pas": len(pellicule), "cles": cles,
             "anomalies": [a["type"] for a in anomalies],
             "pellicule": pellicule[:60]}, ensure_ascii=False), encoding="utf-8")
    except Exception:
        pass

    # pellicule bornée : 200 captures max
    for old in sorted(SHOTS.glob("*.png"))[:-200]:
        old.unlink(missing_ok=True)

    for a in anomalies:
        PROP.write(PROP.make(
            "playtest-bot", "bug",
            f"Playtest : {a['type']} au pas {a['step']}",
            f"Le bot a joué {shots} écran(s) ; anomalie {a['type']} — {a['detail']}.",
            {"summary": f"Session {tag}, pas {a['step']} : {a['detail']}. "
                        f"Captures : ~/.cache/merlin-agents/playtest/{tag}-*.png",
             "target": "jeu (runtime)"},
            f"Rejouer la session {tag} (captures dans playtest/), reproduire "
            f"l'anomalie {a['type']} au pas {a['step']} et corriger la cause.",
            evidence=[{"source": f"playtest/{a['shot'] or tag}",
                       "metric": f"{a['type']} @ pas {a['step']}",
                       "quote": a["detail"]}],
            impact={"axis": "stabilité", "expected": "session jouable sans blocage",
                    "risk": "high" if a["type"] == "MORT" else "med"},
            confidence=0.85))
    if anomalies:
        return f"{shots} écrans joués · {len(anomalies)} anomalie(s) → cartes Décider"
    return f"{shots} écrans joués · aucune anomalie (pellicule {tag})"


if __name__ == "__main__":
    try:
        print(run(int(sys.argv[1]) if len(sys.argv) > 1 else 16))
    except Exception as exc:
        print(f"bot KO: {type(exc).__name__}: {exc}"[:160])
        sys.exit(1)
