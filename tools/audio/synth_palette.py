#!/usr/bin/env python3
"""
Synthetiseur de palette MERLIN — "Broceliande cold" (inspiration Metroid Prime).

Aucun sample externe : toute la matiere sonore est SYNTHETISEE ici (FM, Karplus-Strong,
bruit filtre). C'est le chemin "reconstruction legale" decrit dans
docs/80_sound/30_music/MUSIC_TOOLCHAIN_PALETTE_PRIME.md §5 : on reproduit la *methode*
Kenji Yamamoto (FM froide, cloches inharmoniques, percussion seche en contrepoint,
nappes tres reverberees) sans reutiliser un seul octet appartenant a Nintendo.

PALETTE (6 fonts, fermee) :
  1. pad_fm       — nappe FM froide, ratio inharmonique leger, attaque lente
  2. sub          — basse sinus + saturation douce
  3. bell         — cloche FM inharmonique (ratio sqrt(2)), decay exponentiel
  4. harp         — corde pincee Karplus-Strong (couleur celtique)
  5. taiko        — percussion tribale seche (sinus descendant + transitoire bruite)
  6. choir/whistle— nappe chorale large + flute (sinus + souffle + vibrato)

SORTIE : mix complet + 4 stems (base / rhythm / melody / climax) alignes en phase,
directement consommables par scripts/audio/stems_music_manager.gd.

Usage :
    python3 tools/audio/synth_palette.py --out audio/music/menu
"""

from __future__ import annotations

import argparse
import math
import os
import struct
import subprocess
import sys
import wave

import numpy as np

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTES MUSICALES
# ═══════════════════════════════════════════════════════════════════════════════

SR = 44100
BPM = 66.0
BEAT = 60.0 / BPM              # 0.909 s
BAR = 4 * BEAT                 # 3.636 s
N_BARS = 16
LOOP_LEN = N_BARS * BAR        # 58.18 s
TAIL = 4.5                     # queue de reverb repliee sur le debut (loop seamless)

# Accords, 1 entree par mesure. D dorien + emprunt Bb (lift) + Am (retour).
#   bass_midi = fondamentale jouee par le sub, tones = triade pour les nappes
CHORDS = {
    "Dm": {"bass": 50, "tones": [50, 53, 57]},   # D  F  A
    "C":  {"bass": 48, "tones": [48, 52, 55]},   # C  E  G
    "G":  {"bass": 55, "tones": [55, 59, 62]},   # G  B  D   <- B naturel = couleur dorienne
    "Bb": {"bass": 46, "tones": [46, 50, 53]},   # Bb D  F   <- emprunt eolien, le "lift"
    "Am": {"bass": 45, "tones": [45, 48, 52]},   # A  C  E
}
PROGRESSION = ["Dm", "Dm", "C", "C", "Dm", "Dm", "G", "G",
               "Dm", "Dm", "C", "C", "Bb", "Bb", "Am", "Am"]

# Melodie de flute (mesure 1-indexee, temps 1-indexe, midi, duree en temps)
MELODY = [
    (2, 3.0, 69, 2.0),   (3, 1.0, 72, 1.5),  (3, 3.0, 71, 1.0),  (3, 4.0, 69, 2.0),
    (4, 3.0, 67, 2.0),   (5, 1.0, 65, 3.0),  (5, 4.0, 62, 1.0),  (6, 1.0, 64, 2.0),
    (6, 3.5, 65, 1.5),   (7, 1.0, 67, 4.0),  (8, 1.0, 71, 2.0),  (8, 3.0, 69, 2.0),
    (10, 3.0, 74, 2.0),  (11, 1.0, 72, 1.5), (11, 3.0, 74, 1.0), (11, 4.0, 71, 2.0),
    (12, 3.0, 69, 2.0),  (13, 1.0, 77, 3.0), (13, 4.0, 74, 1.0), (14, 1.0, 72, 2.5),
    (14, 4.0, 71, 1.0),  (15, 1.0, 69, 3.0), (15, 4.0, 67, 1.0), (16, 1.0, 65, 2.0),
    (16, 3.0, 62, 2.0),
]

# Motif de cloches : temps (1-indexes) frappes dans chaque mesure, + index de l'accord
BELL_BEATS = [1.0, 1.5, 2.5, 3.0, 4.0, 4.5]
BELL_DEGREES = [0, 2, 1, 2, 0, 1]


def midi_hz(m: float) -> float:
    return 440.0 * (2.0 ** ((m - 69.0) / 12.0))


def t_of(bar: int, beat: float) -> float:
    """Mesure/temps 1-indexes -> secondes depuis le debut de la boucle."""
    return (bar - 1) * BAR + (beat - 1.0) * BEAT


# ═══════════════════════════════════════════════════════════════════════════════
# DSP — helpers
# ═══════════════════════════════════════════════════════════════════════════════

def lowpass(x: np.ndarray, fc: float, order: float = 2.0) -> np.ndarray:
    """Passe-bas zero-phase par FFT (suffisant pour du shaping de timbre)."""
    n = len(x)
    if n == 0:
        return x
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    mag = 1.0 / (1.0 + (freqs / max(fc, 1.0)) ** order)
    return np.fft.irfft(spec * mag, n)


def highpass(x: np.ndarray, fc: float) -> np.ndarray:
    n = len(x)
    if n == 0:
        return x
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    mag = (freqs / max(fc, 1.0)) / np.sqrt(1.0 + (freqs / max(fc, 1.0)) ** 2)
    return np.fft.irfft(spec * mag, n)


def adsr(n: int, a: float, d: float, s: float, r: float) -> np.ndarray:
    """Enveloppe ADSR, durees en secondes, s = niveau de sustain (0-1)."""
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    ns = max(0, n - na - nd - nr)
    if na + nd + nr > n:  # note trop courte : on compresse
        scale = n / max(1, na + nd + nr)
        na, nd, nr = int(na * scale), int(nd * scale), int(nr * scale)
        ns = max(0, n - na - nd - nr)
    env = np.concatenate([
        np.linspace(0.0, 1.0, na, endpoint=False) ** 1.6 if na else np.array([]),
        np.linspace(1.0, s, nd, endpoint=False) if nd else np.array([]),
        np.full(ns, s),
        np.linspace(s, 0.0, nr) ** 1.5 if nr else np.array([]),
    ])
    if len(env) < n:
        env = np.concatenate([env, np.zeros(n - len(env))])
    return env[:n]


def make_ir(seconds: float, decay: float, damp: float, seed: int) -> np.ndarray:
    """Reponse impulsionnelle synthetique : bruit a decroissance exponentielle,
    assombri progressivement (les aigus meurent plus vite — comme une vraie salle)."""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    noise = rng.standard_normal(n)
    env = np.exp(-np.linspace(0.0, decay, n))
    ir = noise * env
    # assombrissement : on melange une version filtree ponderee par le temps
    dark = lowpass(ir, damp)
    w = np.linspace(0.0, 1.0, n)
    ir = ir * (1.0 - w) + dark * w
    ir[: int(0.004 * SR)] *= np.linspace(0.0, 1.0, int(0.004 * SR))  # pre-delay doux
    return ir / (np.abs(ir).max() + 1e-9)


def stereo_ir(seconds: float, decay: float, damp: float, seed: int,
              width: float = 0.28) -> tuple[np.ndarray, np.ndarray]:
    """Paire d'IR partageant un tronc commun.

    Deux IR de bruit independantes donnent une reverb tres large mais qui s'annule
    en mono (corr L/R ~ 0). On garde donc un tronc commun majoritaire : large a
    l'ecoute au casque, ET compatible mono (corr ~ 0.85)."""
    common = make_ir(seconds, decay, damp, seed)
    side_l = make_ir(seconds, decay * 1.03, damp * 1.08, seed + 101)
    side_r = make_ir(seconds, decay * 0.97, damp * 0.92, seed + 202)
    k = 1.0 - width
    return k * common + width * side_l, k * common + width * side_r


def convolve(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    """Convolution rapide par FFT, tronquee a la longueur d'entree."""
    n = len(x) + len(ir) - 1
    nfft = 1 << (n - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[: len(x)]
    return y


# ═══════════════════════════════════════════════════════════════════════════════
# PALETTE — les 6 "fonts"
# ═══════════════════════════════════════════════════════════════════════════════

def font_pad_fm(freq: float, dur: float, detune: float = 0.0) -> np.ndarray:
    """1. Nappe FM froide. Modulateur legerement inharmonique -> battements lents."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = freq * (1.0 + detune)
    drift = 1.0 + 0.0015 * np.sin(2 * np.pi * 0.07 * t + freq)   # derive organique
    mod = np.sin(2 * np.pi * f * 2.005 * t) * (1.4 + 0.6 * np.sin(2 * np.pi * 0.05 * t))
    car = np.sin(2 * np.pi * f * t * drift + mod)
    car += 0.16 * np.sin(2 * np.pi * f * 0.5 * t)                # sous-octave, corps
    env = adsr(n, a=2.6, d=1.0, s=0.78, r=3.2)
    return lowpass(car * env, 3100.0)


def font_sub(freq: float, dur: float) -> np.ndarray:
    """2. Basse sinus + saturation douce (tanh) pour qu'elle survive aux petits HP."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * freq * t) + 0.18 * np.sin(2 * np.pi * freq * 2 * t)
    sig = np.tanh(sig * 1.05) * 0.46
    env = adsr(n, a=0.9, d=0.6, s=0.8, r=1.8)
    return lowpass(sig * env, 320.0)


def font_bell(freq: float, dur: float) -> np.ndarray:
    """3. Cloche FM inharmonique — ratio sqrt(2), index qui s'effondre : metal froid."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    idx = 5.5 * np.exp(-t * 3.4)
    mod = np.sin(2 * np.pi * freq * 1.4142 * t) * idx
    sig = np.sin(2 * np.pi * freq * t + mod)
    sig += 0.28 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t * 7.0)  # partiel metal
    sig += 0.11 * np.sin(2 * np.pi * freq * 5.43 * t) * np.exp(-t * 13.0)  # scintillement
    env = np.exp(-t * 1.55) * (1.0 - np.exp(-t * 400.0))
    return sig * env * 0.5


def font_harp(freq: float, dur: float, bright: float = 0.5) -> np.ndarray:
    """4. Corde pincee Karplus-Strong, traitee par blocs (vectorise)."""
    n = int(dur * SR)
    d = max(2, int(SR / freq))
    rng = np.random.default_rng(int(freq * 100) % 99991)
    off = 1                      # 1 echantillon de garde : le filtre lit y[n-d-1]
    buf = np.zeros(off + n + d + 2)
    exc = rng.standard_normal(d) * np.hanning(d)
    exc = lowpass(exc, 1200.0 + 5200.0 * bright)
    buf[off: off + d] = exc
    damp = 0.9945 - 0.00035 * (freq / 220.0)
    i = off + d
    end = off + n
    while i < end:
        blk = min(d, end - i)
        a = buf[i - d: i - d + blk]
        b = buf[i - d - 1: i - d - 1 + blk]
        buf[i: i + blk] = damp * 0.5 * (a + b)
        i += blk
    sig = buf[off: off + n]
    env = adsr(n, a=0.001, d=0.05, s=0.9, r=min(0.5, dur * 0.4))
    return sig * env * 0.72


def font_taiko(dur: float, pitch: float = 82.0, power: float = 1.0) -> np.ndarray:
    """5. Percussion tribale seche : sinus descendant + transitoire bruite."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = pitch * np.exp(-t * 5.5) + pitch * 0.55
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6.0)
    rng = np.random.default_rng(int(pitch * 7))
    crack = rng.standard_normal(n) * np.exp(-t * 38.0)
    # bande passante : sans le passe-bas, le transitoire monte a 19 kHz et claque
    # comme un clic au lieu de sonner comme une peau frappee
    crack = lowpass(highpass(crack, 700.0), 6500.0) * 0.20
    skin = lowpass(rng.standard_normal(n) * np.exp(-t * 22.0), 2600.0) * 0.16
    return (body * 0.95 + crack + skin) * power


def font_choir(freq: float, dur: float, voices: int = 5) -> np.ndarray:
    """6a. Nappe chorale : voix desaccordees + creux formantiques, tres large."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    rng = np.random.default_rng(int(freq) % 7919)
    for v in range(voices):
        det = (v - (voices - 1) / 2.0) * 0.0042
        vib = 0.004 * np.sin(2 * np.pi * (4.1 + 0.6 * v) * t + rng.random() * 6.28)
        f = freq * (1.0 + det + vib)
        ph = rng.random() * 6.28
        # dents de scie douces = somme de quelques harmoniques
        for h, amp in ((1, 1.0), (2, 0.42), (3, 0.22), (4, 0.11), (5, 0.07)):
            sig += amp * np.sin(2 * np.pi * f * h * t + ph * h) / voices
    breath = lowpass(rng.standard_normal(n), 2400.0) * 0.05
    env = adsr(n, a=1.8, d=0.8, s=0.8, r=2.4)
    return lowpass((sig * 0.32 + breath) * env, 3900.0)


def font_whistle(freq: float, dur: float) -> np.ndarray:
    """6b. Flute / tin whistle : sinus + harmoniques + vibrato retarde + souffle."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib_depth = 0.006 * np.clip((t - 0.35) / 0.5, 0.0, 1.0)
    vib = vib_depth * np.sin(2 * np.pi * 5.2 * t)
    f = freq * (1.0 + vib)
    ph = 2 * np.pi * np.cumsum(f) / SR
    sig = np.sin(ph) + 0.16 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
    rng = np.random.default_rng(int(freq * 3) % 6197)
    air = lowpass(rng.standard_normal(n), 5200.0) * 0.07 * np.exp(-t * 5.0)
    env = adsr(n, a=0.12, d=0.15, s=0.85, r=0.35)
    return (sig * 0.42 + air) * env


# ═══════════════════════════════════════════════════════════════════════════════
# MOTEUR DE RENDU
# ═══════════════════════════════════════════════════════════════════════════════

class Track:
    """Piste stereo avec placement d'evenements et repli de queue (loop seamless)."""

    def __init__(self) -> None:
        self.n = int((LOOP_LEN + TAIL) * SR)
        self.buf = np.zeros((2, self.n))

    def add(self, sig: np.ndarray, at: float, gain: float = 1.0, pan: float = 0.0) -> None:
        i = int(at * SR)
        if i >= self.n:
            return
        seg = sig[: self.n - i]
        l = math.sqrt(0.5 * (1.0 - pan))
        r = math.sqrt(0.5 * (1.0 + pan))
        self.buf[0, i: i + len(seg)] += seg * gain * l * 1.4142
        self.buf[1, i: i + len(seg)] += seg * gain * r * 1.4142

    def finish(self, ir_l: np.ndarray, ir_r: np.ndarray, wet: float) -> np.ndarray:
        """Reverb + repli de la queue sur le debut => boucle sans couture."""
        out = self.buf.copy()
        if wet > 0.0:
            out[0] = out[0] * (1.0 - wet * 0.45) + convolve(self.buf[0], ir_l) * wet
            out[1] = out[1] * (1.0 - wet * 0.45) + convolve(self.buf[1], ir_r) * wet
        loop_n = int(LOOP_LEN * SR)
        tail_n = self.n - loop_n
        head = out[:, :loop_n].copy()
        head[:, :tail_n] += out[:, loop_n:]          # <- le secret du loop parfait
        return head


def build_stems() -> dict[str, np.ndarray]:
    ir_l, ir_r = stereo_ir(3.4, decay=6.2, damp=3000.0, seed=11, width=0.26)
    ir_dry_l, ir_dry_r = stereo_ir(1.1, decay=9.0, damp=3600.0, seed=41, width=0.20)

    # ── BASE : nappe FM + sub ─────────────────────────────────────────────────
    base = Track()
    for bar in range(1, N_BARS + 1, 2):                 # 1 accord toutes les 2 mesures
        ch = CHORDS[PROGRESSION[bar - 1]]
        t0 = t_of(bar, 1.0)
        dur = 2 * BAR + 1.2
        for k, note in enumerate(ch["tones"]):
            pan = -0.5 + 0.5 * k
            base.add(font_pad_fm(midi_hz(note + 12), dur, detune=0.001 * (k - 1)),
                     t0, gain=0.26, pan=pan)
        base.add(font_pad_fm(midi_hz(ch["tones"][0] + 24), dur, detune=-0.0008),
                 t0, gain=0.13, pan=0.15)
        base.add(font_sub(midi_hz(ch["bass"] - 12), dur), t0, gain=0.30, pan=0.0)

    # ── MELODY : cloches + harpe celtique ─────────────────────────────────────
    melody = Track()
    for bar in range(1, N_BARS + 1):
        ch = CHORDS[PROGRESSION[bar - 1]]
        for j, beat in enumerate(BELL_BEATS):
            if bar % 4 == 1 and j > 3:                   # respiration en debut de phrase
                continue
            deg = BELL_DEGREES[j % len(BELL_DEGREES)]
            oct_up = 24 if (j % 3 == 0) else 12
            note = ch["tones"][deg] + oct_up
            g = 0.30 if j % 2 == 0 else 0.20
            melody.add(font_bell(midi_hz(note), 3.0), t_of(bar, beat),
                       gain=g, pan=-0.35 + 0.14 * j)
    # roulements de harpe a chaque changement d'accord
    for bar in range(1, N_BARS + 1, 2):
        ch = CHORDS[PROGRESSION[bar - 1]]
        notes = [ch["tones"][0], ch["tones"][1], ch["tones"][2],
                 ch["tones"][0] + 12, ch["tones"][1] + 12, ch["tones"][2] + 12]
        for k, note in enumerate(notes):
            melody.add(font_harp(midi_hz(note), 2.2, bright=0.45 + 0.05 * k),
                       t_of(bar, 1.0) + k * 0.075, gain=0.32, pan=-0.3 + 0.12 * k)
    # descente finale, mesure 16 : signe la boucle
    ch = CHORDS[PROGRESSION[15]]
    for k, note in enumerate([ch["tones"][2] + 24, ch["tones"][1] + 12,
                              ch["tones"][0] + 12, ch["tones"][2], ch["tones"][0]]):
        melody.add(font_harp(midi_hz(note), 2.4, bright=0.5),
                   t_of(16, 3.0) + k * 0.11, gain=0.30, pan=0.35 - 0.16 * k)

    # ── RHYTHM : percussion tribale seche ─────────────────────────────────────
    rhythm = Track()
    for bar in range(1, N_BARS + 1):
        rhythm.add(font_taiko(1.6, pitch=78.0, power=1.0), t_of(bar, 1.0),
                   gain=0.92, pan=0.0)
        rhythm.add(font_taiko(0.9, pitch=112.0, power=0.42), t_of(bar, 3.5),
                   gain=0.60, pan=-0.32)
        if bar % 4 == 0:                                  # relance de fin de phrase
            rhythm.add(font_taiko(0.8, pitch=126.0, power=0.36), t_of(bar, 4.5),
                       gain=0.52, pan=0.34)
            rhythm.add(font_taiko(0.7, pitch=150.0, power=0.28), t_of(bar, 4.75),
                       gain=0.42, pan=0.20)
        if bar % 8 == 0:
            rhythm.add(font_taiko(2.2, pitch=62.0, power=1.15), t_of(bar, 4.0),
                       gain=0.80, pan=0.0)

    # ── CLIMAX : choeur + flute (la melodie) ──────────────────────────────────
    climax = Track()
    for bar in range(9, N_BARS + 1, 2):                   # le choeur n'entre qu'en 2e moitie
        ch = CHORDS[PROGRESSION[bar - 1]]
        for k, note in enumerate(ch["tones"]):
            climax.add(font_choir(midi_hz(note + 12), 2 * BAR + 1.0),
                       t_of(bar, 1.0), gain=0.17, pan=-0.6 + 0.6 * k)
    for (bar, beat, note, dur_beats) in MELODY:
        climax.add(font_whistle(midi_hz(note), dur_beats * BEAT * 0.96),
                   t_of(bar, beat), gain=0.38, pan=0.10)

    return {
        "base":   base.finish(ir_l, ir_r, wet=0.62),
        "melody": melody.finish(ir_l, ir_r, wet=0.55),
        "rhythm": rhythm.finish(ir_dry_l, ir_dry_r, wet=0.22),   # seche = contrepoint Prime
        "climax": climax.finish(ir_l, ir_r, wet=0.68),
    }


# ═══════════════════════════════════════════════════════════════════════════════
# SORTIE
# ═══════════════════════════════════════════════════════════════════════════════

def stem_offset_db(name: str, stems: dict, gains: dict) -> float:
    """Ecart RMS entre ce stem et le mix complet, pour preserver l'equilibre relatif."""
    mix_rms = float(np.sqrt((sum(s * gains[n] for n, s in stems.items()) ** 2).mean()))
    stem_rms = float(np.sqrt(((stems[name] * gains[name]) ** 2).mean()))
    return 20.0 * math.log10(max(stem_rms, 1e-9) / max(mix_rms, 1e-9))


def air(x: np.ndarray, gain_db: float = 5.0, fc: float = 4500.0) -> np.ndarray:
    """Shelf haut doux : rend la brillance mangee par les passe-bas de timbre."""
    n = x.shape[-1]
    spec = np.fft.rfft(x, axis=-1)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    shelf = 1.0 + (10 ** (gain_db / 20.0) - 1.0) * (freqs / fc) ** 2 / (1.0 + (freqs / fc) ** 2)
    return np.fft.irfft(spec * shelf, n, axis=-1)


def limit(x: np.ndarray, ceiling: float = 0.72, target_rms_db: float = -18.0) -> np.ndarray:
    """Cale le RMS sur une cible, PUIS protege le peak.

    Vorbis depasse le niveau du PCM source de ~1-2 dB (le decodeur reconstruit des
    pics inter-echantillons). On garde donc une vraie marge : un master a 0.89 est
    ressorti a 1.44 apres encodage => ca clippait a la lecture."""
    rms = float(np.sqrt((x ** 2).mean()))
    if rms > 0:
        x = x * (10 ** (target_rms_db / 20.0) / rms)
    y = np.tanh(x * 1.9) / 1.9          # seulement les cretes touchent la courbe
    peak = float(np.abs(y).max())
    if peak > ceiling:
        y = y * (ceiling / peak)
    return y


def write_wav(path: str, stereo: np.ndarray) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    data = np.clip(stereo.T, -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def to_ogg(wav_path: str, ogg_path: str, quality: str = "4") -> None:
    import imageio_ffmpeg
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    subprocess.run(
        [ff, "-y", "-loglevel", "error", "-i", wav_path,
         "-c:a", "libvorbis", "-q:a", quality, ogg_path],
        check=True,
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="audio/music/menu", help="dossier de sortie")
    ap.add_argument("--keep-wav", action="store_true")
    args = ap.parse_args()

    print(f"[synth] {N_BARS} mesures @ {BPM:.0f} BPM = {LOOP_LEN:.2f}s (loop seamless)")
    stems = build_stems()

    mix = np.zeros_like(stems["base"])
    gains = {"base": 1.0, "rhythm": 0.92, "melody": 0.88, "climax": 0.95}
    for name, sig in stems.items():
        mix += sig * gains[name]

    os.makedirs(args.out, exist_ok=True)
    outputs = {"menu_theme": limit(air(mix))}
    for name, sig in stems.items():
        # les stems gardent leur niveau RELATIF au mix : la somme des 4 doit
        # redonner le mix, sinon stems_music_manager.gd ne sonne pas comme la preview
        outputs[name] = limit(air(sig * gains[name]), ceiling=0.72,
                              target_rms_db=-18.0 + stem_offset_db(name, stems, gains))

    for name, sig in outputs.items():
        wav = os.path.join(args.out, f"{name}.wav")
        ogg = os.path.join(args.out, f"{name}.ogg")
        write_wav(wav, sig)
        to_ogg(wav, ogg)
        size = os.path.getsize(ogg) / 1024.0
        if not args.keep_wav:
            os.remove(wav)
        print(f"[synth] {ogg}  ({size:.0f} KB)")

    print(f"[synth] OK — loop point : 0.000s -> {LOOP_LEN:.3f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
