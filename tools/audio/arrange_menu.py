#!/usr/bin/env python3
"""
Orchestration — repartit Tri Martolod sur les pupitres et les 4 stems.

Chaque evenement porte : instrument, hauteur, instant, duree, nuance, stem.
L'humanisation (leger flottement d'attaque et de nuance) est appliquee ici :
sans elle, un orchestre synthetise sonne comme une boite a rythmes.

PLAN DE L'ARRANGEMENT

  1-4    Intro       harpe, cloches froides, bourdon de cordes graves. L'air n'est
                     pas encore la : on installe le mode.
  5-8    Air nu      hautbois seul. La melodie traditionnelle, sans habillage.
  9-12   Air double  flute a l'octave + cordes. On l'entend deux fois : c'est une
                     ronde, elle se repete par nature.
  13-16  Refrain     la phrase instrumentale, pizzicati et cor.
  17-20  Air harmon. cordes completes, contrechant en approche.
  21-28  Developpem. l'air s'eloigne. Tremolos, choeur, crescendo continu jusqu'au
                     LA MAJEUR de la mesure 28.
  29-36  Tutti       l'air revient a l'orchestre entier : cuivres, glockenspiel,
                     taiko, violons a l'octave inferieure.
  37-40  Coda        tout se retire, il ne reste que la harpe et les cloches.

Stems, conformes a stems_music_manager.gd :
  base    cordes graves et medium, cor, nappe FM, sub        (toujours)
  rhythm  timbales, taiko, pizzicati, cymbales               (tension > 0.2)
  melody  hautbois, flute, harpe, glockenspiel, cloches      (tension > 0.4)
  climax  choeur, cuivres, violons, tremolos, clarinette     (tension > 0.6)
"""

from __future__ import annotations

import numpy as np

from score_menu import (BAR, BEAT, CHORDS, COUNTER, N_BARS, PROGRESSION, REFRAIN,
                        TRI_MARTOLOD, build_voicings, dyn, place_phrase, t_of)

_hum = np.random.default_rng(4242)

# Ou l'air tombe, et qui le joue
AIR_AT = [
    (5,  "oboe",  0,   1.00),        # nu
    (9,  "flute", 0,   0.95),        # double : flute...
    (9,  "oboe",  -12, 0.55),        # ... et hautbois une octave dessous
    (17, "flute", 0,   1.00),
    (17, "oboe",  -12, 0.50),
    # Au tutti la flute seule etait couverte : elle ne pesait plus que 1 % du medium
    # contre 95 % pour les cuivres et le choeur. Deux bois a l'unisson traversent.
    (29, "flute", 0,   1.70), (29, "oboe", 0, 1.05),
    (33, "flute", 0,   1.70), (33, "oboe", 0, 1.05),
]
REFRAIN_AT = [(13, "flute", 0, 1.0), (13, "clarinet", -12, 0.6),
              (21, "oboe", 0, 0.85), (25, "flute", 0, 0.95)]


def _ev(inst, stem, midi, at, dur, vel, seed=0, humanize=True):
    if humanize:
        at += float(_hum.normal(0.0, 0.011))              # flottement d'attaque
        vel *= float(np.clip(_hum.normal(1.0, 0.055), 0.6, 1.3))
    return {"inst": inst, "stem": stem, "midi": midi, "at": max(0.0, at),
            "dur": dur, "vel": float(np.clip(vel, 0.05, 1.0)), "seed": seed}


def _chord_groups() -> list[tuple[int, int, str]]:
    """Regroupe les mesures consecutives portant le meme accord."""
    groups, start = [], 0
    for i in range(1, N_BARS + 1):
        if i == N_BARS or PROGRESSION[i] != PROGRESSION[start]:
            groups.append((start + 1, i, PROGRESSION[start]))
            start = i
    return groups


def build_events() -> list[dict]:
    ev: list[dict] = []
    voicings = build_voicings()
    groups = _chord_groups()

    # ── SOCLE ────────────────────────────────────────────────────────────────
    for (b0, b1, name) in groups:
        t0 = t_of(b0, 1.0)
        span = (b1 - b0 + 1) * BAR
        d = dyn(b0)
        v = voicings[b0 - 1]
        bass, upper = v[0], v[1:]

        ev.append(_ev("sub", "base", bass - 12, t0, span + 1.0, 0.30 + 0.24 * d, b0))
        ev.append(_ev("pad_fm", "base", upper[0] + 12, t0, span + 1.4, 0.20 + 0.16 * d, b0))
        ev.append(_ev("strings_low", "base", bass, t0, span + 0.7, 0.24 + 0.44 * d, b0))
        ev.append(_ev("strings_mid", "base", bass + 12, t0, span + 0.7, 0.14 + 0.26 * d, b0 + 5))
        if b0 >= 9:                                       # les cordes medium entrent avec l'air double
            for k, m in enumerate(upper[:2]):
                ev.append(_ev("strings_mid", "base", m, t0, span + 0.6,
                              0.26 + 0.50 * d, b0 * 7 + k))
        if b0 >= 13:
            ev.append(_ev("horn", "base", upper[1], t0, span + 0.5, 0.22 + 0.42 * d, b0 * 3))
        if b0 >= 17:
            ev.append(_ev("strings_high", "climax", upper[2], t0, span + 0.5,
                          0.24 + 0.48 * d, b0 * 11))
        if 23 <= b0 <= 28:                                # la montee
            for k, m in enumerate(upper):
                ev.append(_ev("strings_tremolo", "climax", m + 12, t0, span + 0.3,
                              0.20 + 0.45 * d, b0 * 13 + k))
        if b0 >= 21:
            for k, m in enumerate(upper):
                ev.append(_ev("choir", "climax", m + 12, t0, span + 1.0,
                              0.13 + 0.25 * d, b0 * 17 + k))
        if 29 <= b0 <= 34:                                # cuivres : le tutti seulement
            for k, m in enumerate([bass + 12] + upper[:2]):
                ev.append(_ev("brass_ff", "climax", m, t0, span + 0.4,
                              0.20 + 0.34 * d, b0 * 19 + k))

    # ── L'AIR ────────────────────────────────────────────────────────────────
    for (bar0, inst, tr, gain) in AIR_AT:
        for (bar, beat, midi, nb) in place_phrase(TRI_MARTOLOD, bar0, tr):
            ev.append(_ev(inst, "melody", midi, t_of(bar, beat), max(0.12, nb * BEAT * 0.94),
                          gain * (0.34 + 0.52 * dyn(bar)), bar * 37 + midi))
    for (bar0, inst, tr, gain) in REFRAIN_AT:
        for (bar, beat, midi, nb) in place_phrase(REFRAIN, bar0, tr):
            ev.append(_ev(inst, "melody", midi, t_of(bar, beat), max(0.12, nb * BEAT * 0.94),
                          gain * (0.34 + 0.50 * dyn(bar)), bar * 41 + midi))
    # au tutti, les violons doublent l'air une octave dessous
    for bar0 in (29, 33):
        for (bar, beat, midi, nb) in place_phrase(TRI_MARTOLOD, bar0, -12):
            # doubler la melodie, c'est de la melodie : ce stem-la, et pas climax
            ev.append(_ev("strings_high", "melody", midi, t_of(bar, beat),
                          max(0.14, nb * BEAT * 0.96), 0.30 + 0.50 * dyn(bar), bar * 59 + midi))

    # ── CONTRECHANT ──────────────────────────────────────────────────────────
    for (bar, beat, midi, nb) in COUNTER:
        ev.append(_ev("clarinet", "climax", midi, t_of(bar, beat), nb * BEAT * 0.92,
                      0.26 + 0.40 * dyn(bar), bar * 61))

    # ── HARPE ────────────────────────────────────────────────────────────────
    for (b0, _b1, name) in groups:
        pcs, _root = CHORDS[name]
        d = dyn(b0)
        notes = sorted({o * 12 + pc for pc in pcs for o in (4, 5, 6)
                        if 55 <= o * 12 + pc <= 86})[:7]
        for k, m in enumerate(notes):
            ev.append(_ev("harp", "melody", m, t_of(b0, 1.0) + k * 0.062,
                          2.6, 0.28 + 0.45 * d, b0 * 23 + k))
    for bar in list(range(1, 5)) + list(range(9, 29)) + list(range(37, 41)):
        pcs, _ = CHORDS[PROGRESSION[bar - 1]]
        d = dyn(bar)
        tones = sorted({o * 12 + pc for pc in pcs for o in (4, 5) if 60 <= o * 12 + pc <= 79})
        for j, beat in enumerate((1.5, 2.5, 3.5, 4.5)):
            ev.append(_ev("harp", "melody", tones[(j * 2) % len(tones)], t_of(bar, beat),
                          1.6, 0.16 + 0.28 * d, bar * 29 + j))

    # ── CLOCHES FROIDES : la palette Prime, aux deux extremites ──────────────
    for bar in list(range(1, 9)) + list(range(37, 41)):
        pcs, _ = CHORDS[PROGRESSION[bar - 1]]
        d = dyn(bar)
        for j, beat in enumerate((1.0, 3.0)):
            ev.append(_ev("celesta_bell", "melody", 72 + pcs[(bar + j) % len(pcs)] % 12,
                          t_of(bar, beat), 3.2, 0.20 + 0.32 * d, bar * 31 + j))

    # ── GLOCKENSPIEL : le sommet ─────────────────────────────────────────────
    for bar in range(29, 35):
        pcs, _ = CHORDS[PROGRESSION[bar - 1]]
        for j, beat in enumerate((1.0, 2.5, 4.0)):
            ev.append(_ev("glockenspiel", "melody", 84 + pcs[(j + bar) % len(pcs)] % 12,
                          t_of(bar, beat), 1.8, 0.28 + 0.40 * dyn(bar), bar * 67 + j))

    # ── PERCUSSIONS ──────────────────────────────────────────────────────────
    for bar in range(1, N_BARS + 1):
        d = dyn(bar)
        _pcs, root = CHORDS[PROGRESSION[bar - 1]]
        if (bar % 4 == 1 and bar >= 9) or bar in (28, 29):
            ev.append(_ev("timpani", "rhythm", root - 24, t_of(bar, 1.0), 3.0,
                          0.30 + 0.60 * d, bar * 71))
        if bar in (27, 28):                                # roulement d'approche
            for j in range(8):
                ev.append(_ev("timpani", "rhythm", root - 24, t_of(bar, 1.0) + j * BEAT / 2,
                              0.7, 0.14 + 0.34 * d * (j + 3) / 10, bar * 73 + j))
        if bar >= 13:
            ev.append(_ev("taiko", "rhythm", 40, t_of(bar, 1.0), 1.7, 0.30 + 0.55 * d, bar * 79))
            ev.append(_ev("taiko", "rhythm", 47, t_of(bar, 3.5), 1.0, 0.18 + 0.38 * d, bar * 83))
        if bar >= 21 and bar % 2 == 0:
            ev.append(_ev("taiko", "rhythm", 52, t_of(bar, 4.5), 0.8, 0.14 + 0.30 * d, bar * 89))
        if 13 <= bar <= 20:                                # pizzicati sur le refrain
            pcs2, _ = CHORDS[PROGRESSION[bar - 1]]
            tones = sorted({o * 12 + pc for pc in pcs2 for o in (3, 4) if 45 <= o * 12 + pc <= 64})
            for j, beat in enumerate((1.0, 2.0, 3.0, 4.0)):
                ev.append(_ev("pizzicato", "rhythm", tones[j % len(tones)], t_of(bar, beat),
                              1.1, 0.24 + 0.40 * d, bar * 97 + j))
    for bar, gain in ((12, 0.45), (20, 0.6), (28, 1.0), (36, 0.5)):
        ev.append(_ev("cymbal", "rhythm", 0, t_of(bar, 1.0), BAR * 0.98,
                      0.30 + 0.55 * gain, bar * 101, humanize=False))

    ev.sort(key=lambda e: e["at"])
    return ev


def summary(events: list[dict]) -> dict:
    per_inst: dict[str, int] = {}
    per_stem: dict[str, int] = {}
    for e in events:
        per_inst[e["inst"]] = per_inst.get(e["inst"], 0) + 1
        per_stem[e["stem"]] = per_stem.get(e["stem"], 0) + 1
    return {"events": len(events), "instruments": len(per_inst),
            "per_instrument": dict(sorted(per_inst.items())),
            "per_stem": dict(sorted(per_stem.items()))}


if __name__ == "__main__":
    import json
    print(json.dumps(summary(build_events()), indent=2, ensure_ascii=False))
