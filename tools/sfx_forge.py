# -*- coding: utf-8 -*-
"""SFX forge M.E.R.L.I.N. — synthese procedurale du catalogue canon (BIBLE §22, R117).

Matiere feutree-organique (R30) : bruit filtre + enveloppes, sinus amortis, accords courts.
Sortie : audio/sfx/<id>.wav — WAV mono 44.1 kHz 16-bit, peak normalise -3 dB.
Seed FIXE par recette → generation 100% rejouable (R119).

Usage:
    python tools/sfx_forge.py --list
    python tools/sfx_forge.py --id card_pick
    python tools/sfx_forge.py --all
"""
from __future__ import annotations

import argparse
import math
import random
import struct
import sys
import wave
from pathlib import Path
from typing import Callable

SAMPLE_RATE = 44100
PEAK_TARGET = 10 ** (-3.0 / 20.0)  # -3 dB
OUT_DIR = Path(__file__).resolve().parent.parent / "audio" / "sfx"


# ── Briques de synthese ──────────────────────────────────────────────────────

def _env_decay(n: int, attack: float, tau: float) -> Callable[[int], float]:
    """Enveloppe attaque lineaire courte + decroissance exponentielle."""
    a_samples = max(1, int(SAMPLE_RATE * attack))

    def env(i: int) -> float:
        if i < a_samples:
            return i / a_samples
        return math.exp(-(i - a_samples) / (SAMPLE_RATE * tau))
    return env


def _noise(duration: float, seed: int, attack: float, tau: float,
           lowpass: float = 0.2) -> list[float]:
    """Bruit blanc filtre (one-pole lowpass) + enveloppe — base 'papier/souffle'."""
    rng = random.Random(seed)
    n = int(SAMPLE_RATE * duration)
    env = _env_decay(n, attack, tau)
    out: list[float] = []
    prev = 0.0
    for i in range(n):
        prev = prev + lowpass * (rng.uniform(-1.0, 1.0) - prev)
        out.append(prev * env(i))
    return out


def _tone(duration: float, freq: float, attack: float, tau: float,
          partials: tuple[tuple[float, float], ...] = ((1.0, 1.0),),
          bend: float = 0.0) -> list[float]:
    """Sinus amorti multi-partiels — base 'bois/goutte/corde'. bend = glissando (ratio/s)."""
    n = int(SAMPLE_RATE * duration)
    env = _env_decay(n, attack, tau)
    out: list[float] = []
    phase = [0.0] * len(partials)
    for i in range(n):
        t = i / SAMPLE_RATE
        f = freq * (1.0 + bend * t)
        s = 0.0
        for k, (ratio, amp) in enumerate(partials):
            phase[k] += 2.0 * math.pi * f * ratio / SAMPLE_RATE
            s += amp * math.sin(phase[k])
        out.append(s * env(i))
    return out


def _mix(*layers: list[float]) -> list[float]:
    n = max(len(layer) for layer in layers)
    out = [0.0] * n
    for layer in layers:
        for i, v in enumerate(layer):
            out[i] += v
    return out


def _concat(*parts: list[float]) -> list[float]:
    out: list[float] = []
    for p in parts:
        out.extend(p)
    return out


def _chord(duration: float, freqs: tuple[float, ...], attack: float, tau: float) -> list[float]:
    layers = [_tone(duration, f, attack, tau,
                    partials=((1.0, 1.0), (2.0, 0.25), (3.0, 0.08))) for f in freqs]
    return _mix(*layers)


# ── Recettes du catalogue canon (ids = BIBLE §22, ne pas renommer) ───────────

RECIPES: dict[str, Callable[[], list[float]]] = {
    # papier glisse court
    "card_pick": lambda: _noise(0.14, seed=101, attack=0.005, tau=0.05, lowpass=0.35),
    # papier pose + souffle
    "card_play": lambda: _mix(
        _noise(0.22, seed=102, attack=0.002, tau=0.07, lowpass=0.30),
        _tone(0.18, 140.0, attack=0.002, tau=0.05, partials=((1.0, 0.5),))),
    # froisse doux
    "card_discard": lambda: _noise(0.30, seed=103, attack=0.01, tau=0.10, lowpass=0.45),
    # eventail de papier (3 glisses rapprochees)
    "deal": lambda: _concat(
        _noise(0.09, seed=104, attack=0.004, tau=0.035, lowpass=0.35),
        _noise(0.09, seed=105, attack=0.004, tau=0.035, lowpass=0.38),
        _noise(0.12, seed=106, attack=0.004, tau=0.045, lowpass=0.32)),
    # bois mat
    "button_tap": lambda: _tone(0.10, 220.0, attack=0.001, tau=0.025,
                                partials=((1.0, 1.0), (2.76, 0.35), (5.4, 0.12))),
    # goutte d'eau claire (pitch monte legerement)
    "gauge_up": lambda: _tone(0.28, 660.0, attack=0.002, tau=0.09,
                              partials=((1.0, 1.0), (2.0, 0.2)), bend=0.6),
    # corde sourde (descend)
    "gauge_down": lambda: _tone(0.40, 196.0, attack=0.004, tau=0.14,
                                partials=((1.0, 1.0), (2.0, 0.4), (2.99, 0.15)), bend=-0.25),
    # murmure granuleux
    "corruption_tick": lambda: _mix(
        _noise(0.35, seed=107, attack=0.03, tau=0.12, lowpass=0.12),
        _tone(0.35, 92.0, attack=0.03, tau=0.12, partials=((1.0, 0.4), (1.5, 0.2)))),
    # sceau de cire (impact mat + leger ring)
    "seal_stamp": lambda: _mix(
        _tone(0.22, 110.0, attack=0.001, tau=0.05, partials=((1.0, 1.0), (1.83, 0.3))),
        _noise(0.10, seed=108, attack=0.001, tau=0.03, lowpass=0.5)),
    # page tournee
    "beat_turn": lambda: _noise(0.45, seed=109, attack=0.06, tau=0.16, lowpass=0.28),
    # carillon feutre (tierce douce)
    "draft_reveal": lambda: _concat(
        _tone(0.30, 523.25, attack=0.004, tau=0.12, partials=((1.0, 1.0), (2.0, 0.15))),
        _tone(0.40, 659.25, attack=0.004, tau=0.16, partials=((1.0, 1.0), (2.0, 0.15)))),
    # souffle dissonant (seconde mineure battue)
    "whisper_threshold": lambda: _mix(
        _noise(0.8, seed=110, attack=0.10, tau=0.30, lowpass=0.10),
        _chord(0.8, (233.08, 246.94), attack=0.10, tau=0.30)),
    # Stingers par degre (R76/R112) — accords courts <=2.5s
    "stinger_echec": lambda: _tone(1.6, 174.61, attack=0.01, tau=0.55,
                                   partials=((1.0, 1.0), (1.19, 0.6), (2.0, 0.2)), bend=-0.12),
    "stinger_partiel": lambda: _chord(1.4, (220.0, 277.18, 329.63), attack=0.01, tau=0.50),
    "stinger_reussite": lambda: _chord(1.8, (196.0, 246.94, 293.66, 392.0), attack=0.008, tau=0.60),
    "stinger_eclatante": lambda: _mix(
        _chord(2.2, (261.63, 329.63, 392.0, 523.25), attack=0.006, tau=0.75),
        _tone(2.2, 1046.5, attack=0.15, tau=0.70, partials=((1.0, 0.25),))),
}


# ── Ecriture WAV ─────────────────────────────────────────────────────────────

def _write_wav(samples: list[float], path: Path) -> float:
    """Normalise au peak -3 dB et ecrit un WAV mono 16-bit. Retourne le peak dBFS MESURE."""
    peak = max((abs(s) for s in samples), default=0.0)
    if peak <= 0.0:
        raise ValueError(f"recette vide pour {path.name}")
    gain = PEAK_TARGET / peak
    ints = [max(-32768, min(32767, int(s * gain * 32767.0))) for s in samples]
    frames = b"".join(struct.pack("<h", v) for v in ints)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(frames)
    measured = max(abs(v) for v in ints) / 32767.0
    return 20.0 * math.log10(measured)


def forge(sfx_id: str) -> Path:
    if sfx_id not in RECIPES:
        raise KeyError(f"recette inconnue '{sfx_id}' — voir --list")
    samples = RECIPES[sfx_id]()
    out = OUT_DIR / f"{sfx_id}.wav"
    peak_db = _write_wav(samples, out)
    dur = len(samples) / SAMPLE_RATE
    print(f"OK {out.name}  {dur:.2f}s  peak {peak_db:.1f} dBFS")
    return out


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="SFX forge M.E.R.L.I.N. (BIBLE §22)")
    parser.add_argument("--list", action="store_true", help="lister les recettes")
    parser.add_argument("--id", help="generer un SFX du catalogue")
    parser.add_argument("--all", action="store_true", help="generer tout le catalogue")
    args = parser.parse_args()

    if args.list:
        for name in RECIPES:
            print(name)
        print(f"\n{len(RECIPES)} recettes (catalogue canon BIBLE §22)")
        return 0
    if args.id:
        forge(args.id)
        return 0
    if args.all:
        for name in RECIPES:
            forge(name)
        print(f"\n{len(RECIPES)} WAV generes dans {OUT_DIR}")
        return 0
    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
