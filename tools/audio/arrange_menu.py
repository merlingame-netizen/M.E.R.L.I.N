#!/usr/bin/env python3
"""
Orchestration — repartit Tri Martolod sur 34 pupitres et 4 stems.

PLAN DE L'ARRANGEMENT

  1-4    Intro          celesta, harpe, cloches froides, bourdon de contrebasses.
                        Le bourdon du biniou s'installe deja, tres bas.
  5-8    Air nu         COR ANGLAIS seul. Plus grave et plus plaintif que le
                        hautbois : c'est la voix qui convient a une gwerz.
  9-12   Air double     hautbois + flute, altos et violoncelles dessous.
  13-16  COUPLE BRETON  bombarde et biniou, avec bourdon et bodhran. C'est ainsi
                        qu'on joue cet air en Bretagne, et l'orchestre se tait
                        pour les laisser passer.
  17-20  Air harmonise  cordes completes, cor, basson, contrechant de clarinette.
  21-28  Developpement  tremolos, choeur, violon solo, tin whistle. Roulements de
                        timbales et de caisse claire. Crescendo jusqu'au LA MAJEUR
                        de la mesure 28, marque au tam-tam.
  29-36  Tutti          tout : bois a l'unisson (flute, piccolo, hautbois,
                        bombarde), cuivres au complet, glockenspiel, percussions.
  37-40  Coda           tout se retire. Celesta, cloches, bourdon. On boucle.

Stems, conformes a stems_music_manager.gd :
  base    cordes graves, altos, cors, trombone, tuba, basson, nappes, bourdon
  rhythm  timbales, taiko, bodhran, pizzicati, cymbales, tam-tam, caisse claire
  melody  cor anglais, hautbois, flute, piccolo, bombarde, biniou, tin whistle,
          harpe, glockenspiel, celesta, cloches, violon solo
  climax  choeur, cuivres tutti, trompettes, violons, tremolos, clarinette
"""

from __future__ import annotations

import numpy as np

from score_menu import (BAR, BEAT, CHORDS, COUNTER, N_BARS, PROGRESSION, REFRAIN,
                        TRI_MARTOLOD, build_voicings, dyn, place_phrase, t_of)

_hum = np.random.default_rng(4242)

# Qui porte l'air, ou, a quelle octave, a quel niveau relatif
AIR_AT = [
    (5,  "cor_anglais", 0,   1.00),                      # nu
    (9,  "oboe",  0,   0.95), (9,  "flute", 0, 0.70),    # double
    # Le couple breton : la bombarde mene, le biniou repond une octave au-dessus.
    (13, "bombarde", 0, 1.00), (13, "biniou", 12, 0.62),
    (17, "flute", 0, 1.00), (17, "cor_anglais", -12, 0.55),
    # Au tutti, quatre bois a l'unisson : c'est ce qu'il faut pour traverser
    # des cuivres au complet. Une flute seule ne pesait que 1 % du medium.
    (29, "flute", 0, 1.45), (29, "oboe", 0, 0.95),
    (29, "piccolo", 12, 0.60), (29, "bombarde", 0, 0.70),
    (33, "flute", 0, 1.45), (33, "oboe", 0, 0.95),
    (33, "piccolo", 12, 0.60), (33, "bombarde", 0, 0.70),
]
REFRAIN_AT = [(21, "tin_whistle", 0, 0.85), (25, "violin_solo", 0, 0.95)]


def _ev(inst, stem, midi, at, dur, vel, seed=0, humanize=True):
    if humanize:
        at += float(_hum.normal(0.0, 0.011))              # flottement d'attaque
        vel *= float(np.clip(_hum.normal(1.0, 0.055), 0.6, 1.3))
    return {"inst": inst, "stem": stem, "midi": midi, "at": max(0.0, at),
            "dur": dur, "vel": float(np.clip(vel, 0.05, 1.0)), "seed": seed}


def _chord_groups() -> list[tuple[int, int, str]]:
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
    BRETON = range(13, 17)                                # l'orchestre se tait pour le couple

    # ── SOCLE ────────────────────────────────────────────────────────────────
    for (b0, b1, name) in groups:
        t0 = t_of(b0, 1.0)
        span = (b1 - b0 + 1) * BAR
        d = dyn(b0)
        bass, upper = voicings[b0 - 1][0], voicings[b0 - 1][1:]
        breton = b0 in BRETON

        ev.append(_ev("sub", "base", bass - 12, t0, span + 1.0, 0.26 + 0.20 * d, b0))
        ev.append(_ev("contrabass", "base", bass - 12, t0, span + 0.8, 0.28 + 0.44 * d, b0 * 3))
        if not breton:
            ev.append(_ev("pad_fm", "base", upper[0] + 12, t0, span + 1.4, 0.22 + 0.18 * d, b0))
            ev.append(_ev("strings_low", "base", bass, t0, span + 0.7, 0.24 + 0.44 * d, b0))
        if b0 >= 9 and not breton:
            ev.append(_ev("viola", "base", upper[0], t0, span + 0.7, 0.24 + 0.44 * d, b0 * 5))
            ev.append(_ev("strings_mid", "base", upper[1], t0, span + 0.6, 0.24 + 0.46 * d, b0 * 7))
        if b0 >= 17 and not breton:
            ev.append(_ev("horn", "base", upper[1], t0, span + 0.5, 0.22 + 0.42 * d, b0 * 11))
            ev.append(_ev("bassoon", "base", bass + 12, t0, span + 0.5, 0.20 + 0.36 * d, b0 * 13))
            ev.append(_ev("strings_high", "climax", upper[2], t0, span + 0.5,
                          0.24 + 0.48 * d, b0 * 17))
        if 23 <= b0 <= 28:
            for k, m in enumerate(upper):
                ev.append(_ev("strings_tremolo", "climax", m + 12, t0, span + 0.3,
                              0.20 + 0.45 * d, b0 * 19 + k))
        if b0 >= 21:
            for k, m in enumerate(upper):
                ev.append(_ev("choir", "climax", m + 12, t0, span + 1.0,
                              0.13 + 0.25 * d, b0 * 23 + k))
        if 29 <= b0 <= 36:                                # les cuivres : le tutti seulement
            ev.append(_ev("tuba", "base", bass - 12, t0, span + 0.4, 0.24 + 0.42 * d, b0 * 29))
            ev.append(_ev("trombone", "base", bass + 12, t0, span + 0.4, 0.22 + 0.40 * d, b0 * 31))
            for k, m in enumerate(upper[:2]):
                ev.append(_ev("brass_ff", "climax", m, t0, span + 0.4,
                              0.18 + 0.30 * d, b0 * 37 + k))
            ev.append(_ev("trumpet", "climax", upper[2] + 12, t0, span + 0.35,
                          0.20 + 0.34 * d, b0 * 41))

    # ── BOURDON DU BINIOU — il ne bouge jamais, c'est le principe ────────────
    for (b0, b1) in ((1, 4), (13, 16), (37, 40)):
        ev.append(_ev("biniou_drone", "base", 50, t_of(b0, 1.0),
                      (b1 - b0 + 1) * BAR + 1.0, 0.5 + 0.4 * dyn(b0), b0 * 43))

    # ── L'AIR ────────────────────────────────────────────────────────────────
    for (bar0, inst, tr, gain) in AIR_AT:
        for (bar, beat, midi, nb) in place_phrase(TRI_MARTOLOD, bar0, tr):
            ev.append(_ev(inst, "melody", midi, t_of(bar, beat), max(0.12, nb * BEAT * 0.94),
                          gain * (0.34 + 0.52 * dyn(bar)), bar * 47 + midi))
    for (bar0, inst, tr, gain) in REFRAIN_AT:
        for (bar, beat, midi, nb) in place_phrase(REFRAIN, bar0, tr):
            ev.append(_ev(inst, "melody", midi, t_of(bar, beat), max(0.12, nb * BEAT * 0.94),
                          gain * (0.34 + 0.50 * dyn(bar)), bar * 53 + midi))
    for bar0 in (29, 33):                                 # violons a l'octave inferieure
        for (bar, beat, midi, nb) in place_phrase(TRI_MARTOLOD, bar0, -12):
            ev.append(_ev("strings_high", "melody", midi, t_of(bar, beat),
                          max(0.14, nb * BEAT * 0.96), 0.30 + 0.50 * dyn(bar), bar * 59 + midi))

    # ── CONTRECHANT ──────────────────────────────────────────────────────────
    for (bar, beat, midi, nb) in COUNTER:
        ev.append(_ev("clarinet", "climax", midi, t_of(bar, beat), nb * BEAT * 0.92,
                      0.26 + 0.40 * dyn(bar), bar * 61))

    # ── HARPE ────────────────────────────────────────────────────────────────
    for (b0, _b1, name) in groups:
        pcs, _ = CHORDS[name]
        d = dyn(b0)
        for k, m in enumerate(sorted({o * 12 + pc for pc in pcs for o in (4, 5, 6)
                                      if 55 <= o * 12 + pc <= 86})[:7]):
            ev.append(_ev("harp", "melody", m, t_of(b0, 1.0) + k * 0.062, 2.6,
                          0.26 + 0.42 * d, b0 * 67 + k))
    for bar in list(range(1, 5)) + list(range(9, 13)) + list(range(17, 29)) + list(range(37, 41)):
        pcs, _ = CHORDS[PROGRESSION[bar - 1]]
        d = dyn(bar)
        tones = sorted({o * 12 + pc for pc in pcs for o in (4, 5) if 60 <= o * 12 + pc <= 79})
        # deux notes par mesure au lieu de quatre : le genre ambiant se joue dans
        # l'espace entre les notes, pas dans leur nombre
        for j, beat in enumerate((2.5, 4.5)):
            ev.append(_ev("harp", "melody", tones[(j * 3) % len(tones)], t_of(bar, beat),
                          2.4, 0.12 + 0.20 * d, bar * 71 + j))

    # ── GUITARE CELTIQUE — arpeges au doigt, accordage DADGAD ────────────────
    # Elle joue peu de notes mais elles sonnent longtemps : c'est le liant du
    # morceau, ce qui remplit l'espace entre les phrases sans le saturer.
    for bar in list(range(1, 13)) + list(range(17, 29)) + list(range(33, 41)):
        pcs, _ = CHORDS[PROGRESSION[bar - 1]]
        d = dyn(bar)
        tones = sorted({o * 12 + pc for pc in pcs for o in (3, 4, 5) if 50 <= o * 12 + pc <= 76})
        pattern = ((1.0, 0), (2.0, 2), (2.75, 4), (3.5, 1), (4.25, 3))
        for j, (beat, idx) in enumerate(pattern):
            ev.append(_ev("celtic_guitar", "melody", tones[idx % len(tones)],
                          t_of(bar, beat), 3.4, 0.24 + 0.34 * d, bar * 131 + j))
        if bar % 4 == 1:                                   # basse a vide sur l'appui
            ev.append(_ev("celtic_guitar", "melody", tones[0] - 12, t_of(bar, 1.0),
                          4.2, 0.28 + 0.32 * d, bar * 137))

    # ── CLOCHES ET CELESTA — les extremites froides ──────────────────────────
    for bar in list(range(1, 9)) + list(range(37, 41)):
        pcs, _ = CHORDS[PROGRESSION[bar - 1]]
        d = dyn(bar)
        for j, beat in enumerate((1.0, 3.0)):
            ev.append(_ev("celesta_bell", "melody", 72 + pcs[(bar + j) % len(pcs)] % 12,
                          t_of(bar, beat), 3.2, 0.20 + 0.32 * d, bar * 73 + j))
    for bar in list(range(1, 5)) + list(range(37, 41)):
        pcs, _ = CHORDS[PROGRESSION[bar - 1]]
        d = dyn(bar)
        for j, beat in enumerate((2.0, 3.5, 4.5)):
            ev.append(_ev("celesta", "melody", 79 + pcs[(j + bar) % len(pcs)] % 12,
                          t_of(bar, beat), 2.2, 0.20 + 0.30 * d, bar * 79 + j))
    for bar in range(29, 37):
        pcs, _ = CHORDS[PROGRESSION[bar - 1]]
        for j, beat in enumerate((1.0, 2.5, 4.0)):
            ev.append(_ev("glockenspiel", "melody", 84 + pcs[(j + bar) % len(pcs)] % 12,
                          t_of(bar, beat), 1.8, 0.26 + 0.38 * dyn(bar), bar * 83 + j))

    # ── PERCUSSIONS ──────────────────────────────────────────────────────────
    for bar in range(1, N_BARS + 1):
        d = dyn(bar)
        _pcs, root = CHORDS[PROGRESSION[bar - 1]]
        breton = bar in BRETON
        if (bar % 4 == 1 and bar >= 17) or bar in (28, 29):
            ev.append(_ev("timpani", "rhythm", root - 24, t_of(bar, 1.0), 3.0,
                          0.28 + 0.56 * d, bar * 89))
        if bar in (27, 28):
            for j in range(8):
                ev.append(_ev("timpani", "rhythm", root - 24, t_of(bar, 1.0) + j * BEAT / 2,
                              0.7, 0.12 + 0.30 * d * (j + 3) / 10, bar * 97 + j))
        # bodhran : la pulsation celtique. Seul avec le couple breton, puis partout.
        if breton or bar >= 21:
            for beat, g in ((1.0, 1.0), (2.5, 0.5), (3.0, 0.7), (4.5, 0.45)):
                ev.append(_ev("bodhran", "rhythm", 45, t_of(bar, beat), 1.1,
                              g * (0.26 + 0.44 * d), bar * 101 + int(beat * 2)))
        if bar >= 17 and not breton:
            ev.append(_ev("taiko", "rhythm", 40, t_of(bar, 1.0), 1.7, 0.26 + 0.48 * d, bar * 103))
            ev.append(_ev("taiko", "rhythm", 47, t_of(bar, 3.5), 1.0, 0.16 + 0.34 * d, bar * 107))
        if 17 <= bar <= 20:                                # pizzicati
            pcs2, _ = CHORDS[PROGRESSION[bar - 1]]
            tones = sorted({o * 12 + pc for pc in pcs2 for o in (3, 4) if 45 <= o * 12 + pc <= 64})
            for j, beat in enumerate((1.0, 2.0, 3.0, 4.0)):
                ev.append(_ev("pizzicato", "rhythm", tones[j % len(tones)], t_of(bar, beat),
                              1.1, 0.22 + 0.36 * d, bar * 109 + j))
        if bar in (26, 27, 28):                            # caisse claire : la montee
            ev.append(_ev("snare_roll", "rhythm", 0, t_of(bar, 1.0), BAR * 0.98,
                          0.18 + 0.42 * ((bar - 25) / 3.0), bar * 113, humanize=False))
    for bar, gain in ((12, 0.4), (20, 0.55), (28, 1.0), (36, 0.5)):
        ev.append(_ev("cymbal", "rhythm", 0, t_of(bar, 1.0), BAR * 0.98,
                      0.28 + 0.50 * gain, bar * 127, humanize=False))
    ev.append(_ev("tam_tam", "rhythm", 0, t_of(28, 1.0), BAR * 2.4, 0.85, 911, humanize=False))

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
