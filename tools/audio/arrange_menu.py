#!/usr/bin/env python3
"""
Orchestration — repartit la partition sur les pupitres et les 4 stems.

Chaque evenement porte : instrument, hauteur, instant, duree, nuance, stem.
L'humanisation (leger flottement d'attaque et de nuance) est appliquee ici :
sans elle, un orchestre synthetise sonne comme une boite a rythmes.

Stems, conformes a stems_music_manager.gd :
  base    cordes graves et medium, cor, nappe FM, sub        (toujours)
  rhythm  timbales, taiko, pizzicati, cymbales               (tension > 0.2)
  melody  hautbois, flute, harpe, glockenspiel, cloches      (tension > 0.4)
  climax  choeur, cuivres, violons, tremolos, clarinette     (tension > 0.6)
"""

from __future__ import annotations

import numpy as np

from score_menu import (BAR, BEAT, CHORDS, COUNTER, LOOP_LEN, N_BARS, PROGRESSION,
                        THEME_A, THEME_A2, THEME_A3, THEME_B, build_voicings, dyn, t_of)

_hum = np.random.default_rng(4242)


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

    # ── SOCLE : nappe froide, sub, cordes graves et medium, cor ──────────────
    for (b0, b1, name) in groups:
        t0 = t_of(b0, 1.0)
        span = (b1 - b0 + 1) * BAR
        d = dyn(b0)
        v = voicings[b0 - 1]
        bass, upper = v[0], v[1:]

        ev.append(_ev("sub", "base", bass - 12, t0, span + 1.0, 0.30 + 0.24 * d, b0))
        ev.append(_ev("pad_fm", "base", upper[0] + 12, t0, span + 1.4, 0.20 + 0.16 * d, b0))
        ev.append(_ev("strings_low", "base", bass, t0, span + 0.7, 0.24 + 0.44 * d, b0))
        # l'octave superieure de la basse etait jouee par les cordes graves : elle
        # empilait de l'energie sous 300 Hz sans rien apporter. Confiee aux altos.
        ev.append(_ev("strings_mid", "base", bass + 12, t0, span + 0.7, 0.14 + 0.26 * d, b0 + 5))
        for k, m in enumerate(upper[:2]):
            ev.append(_ev("strings_mid", "base", m, t0, span + 0.6,
                          0.26 + 0.50 * d, b0 * 7 + k))
        if b0 >= 9:                                        # le cor entre en A'
            ev.append(_ev("horn", "base", upper[1], t0, span + 0.5, 0.22 + 0.42 * d, b0 * 3))

        # ── VIOLONS : voix superieure, a partir de A' ────────────────────────
        if b0 >= 9:
            ev.append(_ev("strings_high", "climax", upper[2], t0, span + 0.5,
                          0.24 + 0.48 * d, b0 * 11))
        # ── TREMOLOS : la montee de B ───────────────────────────────────────
        if 21 <= b0 <= 24:
            for k, m in enumerate(upper):
                ev.append(_ev("strings_tremolo", "climax", m + 12, t0, span + 0.3,
                              0.20 + 0.45 * d, b0 * 13 + k))
        # ── CHOEUR : de B jusqu'a la fin ────────────────────────────────────
        if b0 >= 17:
            for k, m in enumerate(upper):
                ev.append(_ev("choir", "climax", m + 12, t0, span + 1.0,
                              0.16 + 0.34 * d, b0 * 17 + k))
        # ── CUIVRES TUTTI : uniquement le sommet, mesures 25-28 ─────────────
        if 25 <= b0 <= 28:
            for k, m in enumerate([bass + 12] + upper[:2]):
                ev.append(_ev("brass_ff", "climax", m, t0, span + 0.4,
                              0.30 + 0.55 * d, b0 * 19 + k))

    # ── HARPE : roulement a chaque changement d'accord ───────────────────────
    for (b0, _b1, name) in groups:
        pcs, root = CHORDS[name]
        d = dyn(b0)
        notes = sorted({o * 12 + pc for pc in pcs for o in (4, 5, 6)
                        if 55 <= o * 12 + pc <= 86})[:7]
        for k, m in enumerate(notes):
            ev.append(_ev("harp", "melody", m, t_of(b0, 1.0) + k * 0.068,
                          2.6, 0.28 + 0.45 * d, b0 * 23 + k))
    # arpeges continus en A' et B
    for bar in range(9, 25):
        pcs, _ = CHORDS[PROGRESSION[bar - 1]]
        d = dyn(bar)
        tones = sorted({o * 12 + pc for pc in pcs for o in (4, 5) if 60 <= o * 12 + pc <= 79})
        for j, beat in enumerate((1.5, 2.5, 3.5, 4.5)):
            m = tones[(j * 2) % len(tones)]
            ev.append(_ev("harp", "melody", m, t_of(bar, beat), 1.6,
                          0.16 + 0.28 * d, bar * 29 + j))

    # ── CLOCHES FROIDES : l'identite Prime, aux extremites ───────────────────
    for bar in list(range(1, 9)) + list(range(29, 33)):
        pcs, _ = CHORDS[PROGRESSION[bar - 1]]
        d = dyn(bar)
        for j, beat in enumerate((1.0, 3.0)):
            m = 72 + pcs[(bar + j) % len(pcs)] % 12
            ev.append(_ev("celesta_bell", "melody", m, t_of(bar, beat), 3.2,
                          0.20 + 0.30 * d, bar * 31 + j))

    # ── THEME ────────────────────────────────────────────────────────────────
    for (bar, beat, midi, nb) in THEME_A:                 # hautbois, solo
        ev.append(_ev("oboe", "melody", midi, t_of(bar, beat), nb * BEAT * 0.94,
                      0.34 + 0.50 * dyn(bar), bar * 37))
    for (bar, beat, midi, nb) in THEME_A2:                # flute
        ev.append(_ev("flute", "melody", midi, t_of(bar, beat), nb * BEAT * 0.94,
                      0.36 + 0.52 * dyn(bar), bar * 41))
    for (bar, beat, midi, nb) in THEME_B:                 # flute, doublee au hautbois
        d = dyn(bar)
        ev.append(_ev("flute", "melody", midi, t_of(bar, beat), nb * BEAT * 0.94,
                      0.36 + 0.54 * d, bar * 43))
        if bar >= 21:
            ev.append(_ev("oboe", "melody", midi - 12, t_of(bar, beat), nb * BEAT * 0.9,
                          0.22 + 0.40 * d, bar * 47))
    for (bar, beat, midi, nb) in THEME_A3:                # tutti : flute + violons
        d = dyn(bar)
        ev.append(_ev("flute", "melody", midi, t_of(bar, beat), nb * BEAT * 0.94,
                      0.36 + 0.54 * d, bar * 53))
        if bar <= 28:
            ev.append(_ev("strings_high", "climax", midi - 12, t_of(bar, beat),
                          nb * BEAT * 0.96, 0.26 + 0.46 * d, bar * 59))

    # ── CONTRECHANT : clarinette, en mouvement contraire ─────────────────────
    for (bar, beat, midi, nb) in COUNTER:
        ev.append(_ev("clarinet", "climax", midi, t_of(bar, beat), nb * BEAT * 0.92,
                      0.26 + 0.40 * dyn(bar), bar * 61))

    # ── GLOCKENSPIEL : le scintillement du sommet ────────────────────────────
    for bar in range(25, 29):
        pcs, _ = CHORDS[PROGRESSION[bar - 1]]
        for j, beat in enumerate((1.0, 2.5, 4.0)):
            m = 84 + pcs[(j + bar) % len(pcs)] % 12
            ev.append(_ev("glockenspiel", "melody", m, t_of(bar, beat), 1.8,
                          0.28 + 0.40 * dyn(bar), bar * 67 + j))

    # ── PERCUSSIONS ──────────────────────────────────────────────────────────
    for bar in range(1, N_BARS + 1):
        d = dyn(bar)
        _pcs, root = CHORDS[PROGRESSION[bar - 1]]
        # timbales : appuis de structure, accordees sur la fondamentale
        if bar % 4 == 1 or bar in (24, 25):
            ev.append(_ev("timpani", "rhythm", root - 24, t_of(bar, 1.0), 3.0,
                          0.30 + 0.60 * d, bar * 71))
        if bar in (23, 24):                                # roulement d'approche
            for j in range(8):
                ev.append(_ev("timpani", "rhythm", root - 24, t_of(bar, 1.0) + j * BEAT / 2,
                              0.7, 0.14 + 0.34 * d * (j + 3) / 10, bar * 73 + j))
        # taiko : la pulsation tribale
        if bar >= 5:
            ev.append(_ev("taiko", "rhythm", 40, t_of(bar, 1.0), 1.7, 0.30 + 0.55 * d, bar * 79))
            ev.append(_ev("taiko", "rhythm", 47, t_of(bar, 3.5), 1.0, 0.18 + 0.38 * d, bar * 83))
        if bar >= 17 and bar % 2 == 0:
            ev.append(_ev("taiko", "rhythm", 52, t_of(bar, 4.5), 0.8, 0.14 + 0.30 * d, bar * 89))
        # pizzicati : la section A'
        if 9 <= bar <= 16:
            pcs2, _ = CHORDS[PROGRESSION[bar - 1]]
            tones = sorted({o * 12 + pc for pc in pcs2 for o in (3, 4) if 45 <= o * 12 + pc <= 64})
            for j, beat in enumerate((1.0, 2.0, 3.0, 4.0)):
                ev.append(_ev("pizzicato", "rhythm", tones[j % len(tones)], t_of(bar, beat),
                              1.1, 0.24 + 0.40 * d, bar * 97 + j))
    # cymbales : elles annoncent chaque section
    for bar, gain in ((8, 0.5), (16, 0.6), (24, 1.0), (28, 0.55)):
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
