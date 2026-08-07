#!/usr/bin/env python3
"""Effets d'ambiance proceduraux pour le lecteur — pluie, vent, oiseaux,
grillons, tonnerre.

Tout est SYNTHETISE ici : aucun enregistrement, aucune source externe. Chaque
boucle est rendue plus longue que sa duree puis repliee queue-sur-tete, comme
les stems musicaux : le point de bouclage est inaudible par construction. Le
reproche « des bruitages qui se coupent » interdit le moindre trou.

    python3 tools/audio/sfx_ambiance.py --out audio/music/menu
    python3 tools/audio/sfx_ambiance.py --selftest
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

import numpy as np

SR = 48_000


# ── outils ───────────────────────────────────────────────────────────────────

def bandpass(x: np.ndarray, lo: float, hi: float, slope: float = 0.0) -> np.ndarray:
    """Filtre par le spectre. slope < 0 penche l'energie vers le grave."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    mask = ((f >= lo) & (f <= hi)).astype(float)
    edge = np.clip((f - lo) / max(lo * 0.5, 20), 0, 1) * \
        np.clip((hi - f) / max(hi * 0.25, 50), 0, 1)
    mask = np.minimum(mask + 0.0, np.clip(edge, 0, 1))
    if slope:
        mask = mask * (1.0 + np.maximum(f, 30.0) / 100.0) ** slope
    return np.fft.irfft(spec * mask, len(x))


def fold_loop(x: np.ndarray, loop_n: int) -> np.ndarray:
    """Fond la queue DANS la tete — fondu enchaine, pas addition.

    Le repli par addition convient aux queues de reverbe qui s'eteignent :
    ajouter un residu mourant a une attaque ne cree pas de marche. Sur du
    bruit STATIONNAIRE a plein niveau (le vent), l'addition dedouble l'energie
    en tete et pose une discontinuite au raccord : mesure a 9,4 fois le pas
    typique — un clic franc. Le fondu enchaine est continu par construction :
    au premier echantillon, la boucle prolonge exactement le dernier."""
    head = x[:loop_n].copy()
    tail = x[loop_n:]
    m = len(tail)
    if m:
        w = np.linspace(0.0, 1.0, m)
        head[:m] = head[:m] * w + tail * (1.0 - w)
    return head


def norm(x: np.ndarray, peak: float) -> np.ndarray:
    m = float(np.abs(x).max()) or 1.0
    return (x / m * peak).astype(np.float64)


# ── les cinq ambiances ───────────────────────────────────────────────────────

def gen_pluie(dur: float = 12.0, seed: int = 11) -> np.ndarray:
    """Crepitement de gouttes + voile de bruine. Pas de nappe qui respire :
    la pluie reelle est statistiquement stationnaire, c'est ce qui la rend
    reposante."""
    rng = np.random.default_rng(seed)
    n = int((dur + 1.5) * SR)
    out = np.zeros(n)
    for _ in range(int(dur * 75)):                       # ~75 gouttes/s
        p = rng.integers(0, n - 400)
        ln = rng.integers(90, 320)                       # 2 a 7 ms
        burst = rng.normal(0, 1, ln) * np.hanning(ln) ** 2
        out[p:p + ln] += burst * rng.uniform(0.2, 1.0)
    out = bandpass(out, 1500, 10500, slope=-0.3)
    hiss = bandpass(rng.normal(0, 1, n), 800, 5200, slope=-0.5) * 0.5
    out = out + hiss
    return norm(fold_loop(out, int(dur * SR)), 0.34)


def gen_vent(dur: float = 16.0, seed: int = 23) -> np.ndarray:
    """Souffle grave module par deux respirations LENTES, en nombres ENTIERS
    de cycles sur la boucle — sans quoi la modulation saute au raccord."""
    rng = np.random.default_rng(seed)
    n = int((dur + 2.0) * SR)
    loop_n = int(dur * SR)
    base = bandpass(rng.normal(0, 1, n), 60, 750, slope=-0.9)
    t = np.arange(n) / loop_n                            # cycles sur LA BOUCLE
    am = 0.55 + 0.28 * np.sin(2 * np.pi * 3 * t) + 0.17 * np.sin(2 * np.pi * 7 * t + 1.3)
    gust = bandpass(rng.normal(0, 1, n), 350, 1400, slope=-0.5) * \
        np.clip(0.30 * np.sin(2 * np.pi * 5 * t + 4.0), 0, 1)
    return norm(fold_loop(base * am + gust, loop_n), 0.30)


def gen_oiseaux(dur: float = 14.0, seed: int = 37) -> np.ndarray:
    """Phrases de 2 a 5 sifflements glisses — pas d'echantillon, des sinus
    glissants a vibrato, c'est exactement ainsi que chante un merle de synthese
    honnete."""
    rng = np.random.default_rng(seed)
    n = int((dur + 1.0) * SR)
    out = np.zeros(n)
    # L'audit mesurait 70 dB de chute en 30 ms : chaque sifflement tombait
    # dans le silence ABSOLU — un bruitage qui se coupe, litteralement. Deux
    # remedes : une queue exponentielle de 120 ms par syllabe, et un fond
    # d'air continu tres bas — dans une foret, le silence n'est jamais zero.
    tail = int(0.12 * SR)
    for _ in range(11):                                   # phrases
        at = rng.integers(0, n - SR)
        for k in range(rng.integers(2, 6)):               # syllabes
            ln = rng.integers(int(0.05 * SR), int(0.16 * SR))
            f0, f1 = rng.uniform(2200, 4300), rng.uniform(2000, 4600)
            tot = ln + tail
            tt = np.arange(tot) / SR
            u = np.minimum(tt / (ln / SR), 1.0)
            freq = f0 + (f1 - f0) * u + 60 * np.sin(2 * np.pi * 38 * tt)
            ph = 2 * np.pi * np.cumsum(freq) / SR
            w = np.clip(tt * SR / (0.18 * ln), 0, 1) * \
                np.sin(np.pi * np.minimum(u, 1.0) / 2 + 1e-9)
            w = w * np.where(tt > ln / SR,
                             np.exp(-(tt - ln / SR) / 0.045), 1.0)
            syl = np.sin(ph) * w * rng.uniform(0.4, 1.0)
            p = min(int(at + k * int(ln * 1.5)), n - tot - 1)
            out[p:p + tot] += syl
    air = bandpass(rng.normal(0, 1, n), 2400, 6400, slope=-0.4) * 0.045
    return norm(fold_loop(out + air, int(dur * SR)), 0.30)


def gen_grillons(dur: float = 12.0, seed: int = 41) -> np.ndarray:
    """Deux individus legerement desaccordes, stridulation a ~26 Hz par
    bouffees — le chant reel est un train d'impulsions, pas un sifflet."""
    rng = np.random.default_rng(seed)
    n = int((dur + 1.0) * SR)
    out = np.zeros(n)
    t = np.arange(n) / SR
    # Meme lecon que les oiseaux : la stridulation coupait a zero absolu 26
    # fois par seconde (74 dB de chute mesuree). La porte garde un plancher —
    # l'aile ne s'arrete pas net — et un choeur lointain continu tient le fond.
    for carrier, trem, cyc in ((4300.0, 26.0, 0), (4520.0, 24.0, 1)):
        gate = np.clip(np.sin(2 * np.pi * trem * t), 0, 1) ** 1.6
        tone = np.sin(2 * np.pi * carrier * t) * (0.12 + 0.88 * gate)
        env = np.zeros(n)
        p = int(rng.uniform(0, 0.5) * SR)
        while p < n:
            ln = int(rng.uniform(0.35, 0.7) * SR)
            e = np.hanning(min(ln, n - p))
            env[p:p + len(e)] = np.maximum(env[p:p + len(e)], e)
            p += ln + int(rng.uniform(0.4, 1.1) * SR)
        out += tone * env * (0.8 if cyc else 1.0)
    # le choeur ne descend JAMAIS a zero : sa modulation touchait le silence
    # deux fois par boucle, et les fins de bouffees y retombaient a pic
    chorus = np.sin(2 * np.pi * 4380.0 * t) * \
        (0.68 + 0.32 * np.sin(2 * np.pi * 2 * t / (dur + 1.0))) * 0.07
    return norm(fold_loop(out + chorus, int(dur * SR)), 0.22)


def gen_tonnerre(dur: float = 5.5, seed: int = 53) -> np.ndarray:
    """Coup unique : craquement bref puis roulement grave qui s'eteint.
    PAS une boucle — il se joue une fois, a la demande."""
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    rumble = np.cumsum(rng.normal(0, 1, n)); rumble -= rumble.mean()
    rumble = bandpass(rumble, 25, 160, slope=-0.4)
    env = np.exp(-t / 1.7) * (1 + 0.5 * np.sin(2 * np.pi * 0.9 * t) ** 2)
    env[:int(0.08 * SR)] *= np.linspace(0, 1, int(0.08 * SR))
    crack = bandpass(rng.normal(0, 1, n), 300, 2400, slope=-0.3) * \
        np.exp(-t / 0.16) * 0.7
    out = rumble * env + crack
    # FIN EXACTEMENT A ZERO. La queue exponentielle laisse ~-30 dB au dernier
    # echantillon : l'arret de l'element <audio> posait une marche seche. Le
    # dernier tiers de seconde descend en cosinus jusqu'au silence vrai.
    nf = int(0.35 * SR)
    out[-nf:] *= 0.5 * (1 + np.cos(np.linspace(0, np.pi, nf)))
    return norm(out, 0.66)


SFX = [
    {"id": "pluie",    "label": "Pluie",    "loop": True,  "gain": 0.9,  "gen": gen_pluie,    "ic": "pluie"},
    {"id": "vent",     "label": "Vent",     "loop": True,  "gain": 0.9,  "gen": gen_vent,     "ic": "vent"},
    {"id": "oiseaux",  "label": "Oiseaux",  "loop": True,  "gain": 0.8,  "gen": gen_oiseaux,  "ic": "oiseau"},
    {"id": "grillons", "label": "Grillons", "loop": True,  "gain": 0.8,  "gen": gen_grillons, "ic": "grillon"},
    {"id": "tonnerre", "label": "Tonnerre", "loop": False, "gain": 1.0,  "gen": gen_tonnerre, "ic": "orage"},
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="audio/music/menu")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()

    import imageio_ffmpeg
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    fx_dir = os.path.join(a.out, "fx")
    os.makedirs(fx_dir, exist_ok=True)
    entries = []
    for e in SFX:
        x = e["gen"]()
        raw = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
        dst = os.path.join(fx_dir, e["id"] + ".ogg")
        subprocess.run([ff, "-y", "-loglevel", "error", "-f", "s16le",
                        "-ar", str(SR), "-ac", "1", "-i", "-",
                        # q6 et non q3 : sur le vent — bruit grave et lisse —
                        # q3 posait un pas de 2,6 x le pas typique AU raccord
                        # de boucle. Mesure : q3 = 2,6x, q6 = 0,7x, q8 = 0,0x.
                        "-c:a", "libvorbis", "-q:a", "6", dst],
                       input=raw, check=True)
        entries.append({"id": e["id"], "label": e["label"], "loop": e["loop"],
                        "gain": e["gain"], "ic": e["ic"],
                        "file": f"fx/{e['id']}.ogg",
                        "duration_s": round(len(x) / SR, 2)})
        print(f"  fx  {e['id']:9s} {len(x)/SR:5.1f}s  "
              f"{'boucle' if e['loop'] else 'one-shot'}  "
              f"{os.path.getsize(dst)/1024:.0f} Ko")

    cast_path = os.path.join(a.out, "casting.json")
    if os.path.exists(cast_path):
        with open(cast_path, encoding="utf-8") as fh:
            cast = json.load(fh)
        cast["sfx"] = entries
        with open(cast_path, "w", encoding="utf-8") as fh:
            json.dump(cast, fh, ensure_ascii=False, indent=1)
        print(f"[sfx] {len(entries)} effets declares dans casting.json")
    return 0


def selftest() -> int:
    print("── autotest des ambiances ──")
    ok = True
    for e in SFX:
        x = e["gen"]()
        peak = float(np.abs(x).max())
        # le raccord de boucle : difference premier/dernier echantillon comparee
        # au pas typique — meme critere que loop_check
        d = np.abs(np.diff(np.concatenate([x[-2000:], x[:2000]])))
        join = abs(float(x[-1] - x[0]))
        p90 = float(np.percentile(d, 90))
        good = peak <= 1.0 and (not e["loop"] or join <= 2 * p90 or join < 2e-3)
        print(f"  {'ok  ' if good else 'ECHEC'} {e['id']:9s} crete={peak:.2f} "
              f"raccord={join:.4f} (p90 {p90:.4f})")
        ok &= good
    print("── AUTOTEST OK ──" if ok else "── AUTOTEST EN ECHEC ──")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
