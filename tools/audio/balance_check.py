#!/usr/bin/env python3
"""Mesure l'equilibre du pupitre : niveau percu et brillance de chaque instrument.

Le niveau est la RMS de la fenetre de 200 ms la plus forte, pas celle de la note
entiere : sur un son a decroissance rapide (harpe, glockenspiel) la RMS globale
s'effondre avec la duree et pousserait a sur-amplifier.

    python3 tools/audio/balance_check.py
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import orchestra as orc

SR = orc.SR
TESTS = [("strings_low", 50, 4.0), ("strings_mid", 62, 4.0), ("strings_high", 69, 4.0),
         ("strings_tremolo", 69, 4.0), ("pizzicato", 50, 1.1), ("horn", 57, 4.0),
         ("brass_ff", 57, 3.0), ("flute", 74, 1.5), ("oboe", 74, 1.5),
         ("clarinet", 60, 1.5), ("harp", 67, 2.5), ("glockenspiel", 88, 1.8),
         ("celesta_bell", 76, 3.0), ("timpani", 26, 3.0), ("taiko", 40, 1.7),
         ("choir", 67, 4.0), ("pad_fm", 74, 4.0), ("sub", 38, 4.0)]
F = {n: getattr(orc, n) for n, _, _ in TESTS}


def peak_rms_db(x, win=0.2):
    w = int(win * SR)
    if len(x) <= w:
        return 20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-12)
    e = np.convolve(x ** 2, np.ones(w) / w, mode="valid")
    return 20 * np.log10(np.sqrt(e.max()) + 1e-12)


def main():
    hz = lambda m: 440.0 * (2.0 ** ((m - 69) / 12))
    print(f"{'instrument':16s} {'niveau':>9s} {'crete':>7s} {'centroide':>10s} {'>2kHz':>7s}")
    lv = {}
    for name, midi, dur in TESTS:
        x = F[name](hz(midi), dur, vel=0.7, seed=1) * orc.GAIN.get(name, 1.0)
        S = np.abs(np.fft.rfft(x))
        f = np.fft.rfftfreq(len(x), 1 / SR)
        cen = float((S * f).sum() / max(S.sum(), 1e-9))
        hi = float(S[f > 2000].sum() / max(S.sum(), 1e-9))
        lv[name] = peak_rms_db(x)
        print(f"{name:16s} {lv[name]:8.1f}dB {np.abs(x).max():7.3f} {cen:9.0f}Hz {hi*100:6.1f}%")
    x = orc.cymbal_swell(3.0, vel=0.7, seed=1) * orc.GAIN.get("cymbal", 1.0)
    lv["cymbal"] = peak_rms_db(x)
    print(f"{'cymbal':16s} {lv['cymbal']:8.1f}dB {np.abs(x).max():7.3f}")
    print(f"\nEcart entre pupitres : {max(lv.values())-min(lv.values()):.1f} dB "
          f"(le plus fort : {max(lv, key=lv.get)}, le plus faible : {min(lv, key=lv.get)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
