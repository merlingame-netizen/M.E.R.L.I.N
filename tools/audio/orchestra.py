#!/usr/bin/env python3
"""
Palette orchestrale MERLIN — modeles d'instruments synthetises.

Aucun echantillon externe. Chaque instrument est un modele physique ou spectral :
c'est le chemin "reconstruction" de docs/80_sound/30_music/MUSIC_TOOLCHAIN_PALETTE_PRIME.md §5.

CE QUI FAIT SONNER UN ORCHESTRE (et pas un synthe empile) :

  1. ENSEMBLE — un pupitre de cordes n'est pas une note, c'est 8 instrumentistes
     legerement desaccordes, chacun avec son vibrato et sa derive. C'est cette
     decorrelation qui epaissit le son sans le rendre flou.
  2. VELOCITE TIMBRALE — jouer fort ne change pas que le volume : ca ouvre le
     spectre. Un cor piano est sourd, un cor forte est cuivre. Sans ce lien,
     les nuances sonnent comme un bouton de volume.
  3. FORMANTS — les resonances de corps (bois, cuivre, voix) sont fixes en
     frequence, independamment de la note jouee. C'est ce qui donne l'identite.
  4. PLACEMENT — chaque pupitre a une position sur scene : panoramique, mais
     surtout distance (plus de reverbe, plus d'aigus manges, leger pre-delai).

Instruments : cordes graves/medium/aigues, tremolo, pizzicato, cors, cuivres,
flute, hautbois, clarinette, harpe, timbales, cymbale, glockenspiel, choeur,
plus la nappe FM froide et le sub qui portent l'identite Prime.
"""

from __future__ import annotations

import numpy as np

SR = 44100
_rng = np.random.default_rng(20260805)
_cache: dict = {}


# Equilibre du pupitre. Chaque modele sort a son niveau naturel ; ces gains les
# ramenent a une hierarchie orchestrale voulue, mesuree sur la RMS de la fenetre
# de 200 ms la plus forte — et non sur la note entiere, sinon un son a
# decroissance rapide comme la harpe se retrouve sur-amplifie. Voir balance_check.py.
GAIN = {
    "strings_low": 0.62, "strings_mid": 0.50, "strings_high": 0.88,
    "strings_tremolo": 0.80, "pizzicato": 1.15, "horn": 0.52, "brass_ff": 0.40,
    "flute": 1.45, "oboe": 1.55, "clarinet": 1.05,
    "harp": 1.35, "glockenspiel": 1.30, "celesta_bell": 1.10,
    "timpani": 0.95, "taiko": 0.85, "cymbal": 1.20,
    "choir": 1.70, "pad_fm": 0.42, "sub": 1.15,
}


# ═══════════════════════════════════════════════════════════════════════════════
# DSP — briques communes
# ═══════════════════════════════════════════════════════════════════════════════

def lowpass(x: np.ndarray, fc: float, order: float = 2.0) -> np.ndarray:
    n = len(x)
    if n == 0:
        return x
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    return np.fft.irfft(spec / (1.0 + (f / max(fc, 1.0)) ** order), n)


def highpass(x: np.ndarray, fc: float) -> np.ndarray:
    n = len(x)
    if n == 0:
        return x
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    r = f / max(fc, 1.0)
    return np.fft.irfft(spec * (r / np.sqrt(1.0 + r * r)), n)


def bandpass(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    return lowpass(highpass(x, lo), hi)


def formants(x: np.ndarray, peaks: list[tuple[float, float, float]]) -> np.ndarray:
    """Applique des resonances fixes : [(frequence, largeur, gain_dB), ...].

    Fixes en frequence, donc independantes de la note — c'est precisement ce qui
    fait qu'un hautbois reste un hautbois sur toute sa tessiture."""
    n = len(x)
    if n == 0:
        return x
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    gain = np.ones_like(f)
    for fc, bw, db in peaks:
        gain += (10 ** (db / 20.0) - 1.0) * np.exp(-0.5 * ((f - fc) / max(bw, 1.0)) ** 2)
    return np.fft.irfft(spec * gain, n)


def adsr(n: int, a: float, d: float, s: float, r: float, curve: float = 1.6) -> np.ndarray:
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    if na + nd + nr > n:
        k = n / max(1, na + nd + nr)
        na, nd, nr = int(na * k), int(nd * k), int(nr * k)
    ns = max(0, n - na - nd - nr)
    env = np.concatenate([
        np.linspace(0.0, 1.0, na, endpoint=False) ** curve if na else np.empty(0),
        np.linspace(1.0, s, nd, endpoint=False) if nd else np.empty(0),
        np.full(ns, s),
        np.linspace(s, 0.0, nr) ** 1.5 if nr else np.empty(0),
    ])
    if len(env) < n:
        env = np.concatenate([env, np.zeros(n - len(env))])
    return env[:n]


def _phase(freq: float, n: int, detune: float, vib_depth: float, vib_rate: float,
           vib_delay: float, rng: np.random.Generator) -> np.ndarray:
    t = np.arange(n) / SR
    vib = vib_depth * np.sin(2 * np.pi * vib_rate * t + rng.random() * 6.283)
    vib *= np.clip((t - vib_delay) / 0.45, 0.0, 1.0)          # vibrato retarde
    drift = 1.0 + 0.0009 * np.sin(2 * np.pi * (0.11 + rng.random() * 0.09) * t)
    f = freq * (1.0 + detune) * (1.0 + vib) * drift
    return 2 * np.pi * np.cumsum(f) / SR + rng.random() * 6.283


def _memo(key, fn):
    if key not in _cache:
        _cache[key] = fn()
    return _cache[key]


# ═══════════════════════════════════════════════════════════════════════════════
# CORDES
# ═══════════════════════════════════════════════════════════════════════════════

def _string_core(freq: float, dur: float, voices: int, harmonics: int,
                 bright: float, vel: float, seed: int) -> np.ndarray:
    """Coeur commun des pupitres de cordes : N instrumentistes decorreles."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    rng = np.random.default_rng(seed)
    out = np.zeros(n)
    for v in range(voices):
        det = rng.normal(0.0, 0.0026)                          # justesse humaine
        ph = _phase(freq, n, det, 0.0042 + 0.0016 * rng.random(),
                    4.3 + 1.7 * rng.random(), 0.22 + 0.35 * rng.random(), rng)
        # dents de scie adoucies : 1/h^p, p pilote par la velocite (jeu appuye = plus riche)
        p = 1.52 - 0.48 * vel
        for h in range(1, harmonics + 1):
            out += (1.0 / h ** p) * np.sin(h * ph)
        # chaque archet n'entre pas exactement en meme temps
        off = int(rng.uniform(0.0, 0.028) * SR)
        if off:
            out[:off] *= np.linspace(0.0, 1.0, off)
    out /= voices
    fc = 1500.0 + 6400.0 * bright * (0.5 + 0.5 * vel)
    return lowpass(out, fc)


def strings_low(freq, dur, vel=0.7, seed=0):
    """Violoncelles + contrebasses. Corps bas, attaque ronde."""
    n = int(dur * SR)
    sig = _string_core(freq, dur, voices=6, harmonics=11, bright=0.42, vel=vel, seed=seed + 11)
    sig = formants(sig, [(240.0, 110.0, 4.0), (480.0, 180.0, 2.5)])
    return sig * adsr(n, 0.16, 0.35, 0.82, min(1.4, dur * .5)) * (0.45 + 0.55 * vel)


def strings_mid(freq, dur, vel=0.7, seed=0):
    """Altos + seconds violons. Le remplissage harmonique."""
    n = int(dur * SR)
    sig = _string_core(freq, dur, voices=7, harmonics=10, bright=0.55, vel=vel, seed=seed + 23)
    sig = formants(sig, [(430.0, 150.0, 3.5), (1100.0, 350.0, 2.0)])
    return sig * adsr(n, 0.13, 0.3, 0.84, min(1.2, dur * .5)) * (0.45 + 0.55 * vel)


def strings_high(freq, dur, vel=0.75, seed=0):
    """Premiers violons. Chantant, vibrato present."""
    n = int(dur * SR)
    sig = _string_core(freq, dur, voices=8, harmonics=9, bright=0.72, vel=vel, seed=seed + 37)
    sig = formants(sig, [(680.0, 200.0, 3.0), (2400.0, 700.0, 2.5)])
    return sig * adsr(n, 0.11, 0.25, 0.86, min(1.1, dur * .5)) * (0.45 + 0.55 * vel)


def strings_tremolo(freq, dur, vel=0.6, seed=0):
    """Tremolo : la meme matiere, hachee a ~11 Hz. Tension pure."""
    n = int(dur * SR)
    sig = _string_core(freq, dur, voices=7, harmonics=9, bright=0.62, vel=vel, seed=seed + 53)
    t = np.arange(n) / SR
    rate = 10.5 + 1.5 * np.sin(2 * np.pi * 0.3 * t)            # main pas metronomique
    trem = 0.55 + 0.45 * np.sin(2 * np.pi * np.cumsum(rate) / SR)
    return sig * trem * adsr(n, 0.09, 0.2, 0.88, 0.8) * (0.4 + 0.6 * vel)


def pizzicato(freq, dur, vel=0.8, seed=0):
    """Pizzicato : corde pincee tres amortie + coup de corps."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    d = max(2, int(SR / freq))
    rng = np.random.default_rng(seed + 71)
    off = 1
    buf = np.zeros(off + n + d + 2)
    exc = lowpass(rng.standard_normal(d) * np.hanning(d), 2200.0 + 3000.0 * vel)
    buf[off:off + d] = exc
    damp = 0.982 - 0.004 * (freq / 220.0)                      # amortissement fort = pizz
    i, end = off + d, off + n
    while i < end:
        blk = min(d, end - i)
        buf[i:i + blk] = damp * 0.5 * (buf[i - d:i - d + blk] + buf[i - d - 1:i - d - 1 + blk])
        i += blk
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * freq * 0.5 * t) * np.exp(-t * 30.0) * 0.25
    return (buf[off:off + n] + body) * np.exp(-t * 4.2) * vel * 0.8


# ═══════════════════════════════════════════════════════════════════════════════
# CUIVRES
# ═══════════════════════════════════════════════════════════════════════════════

def horn(freq, dur, vel=0.6, seed=0):
    """Cor. L'index FM monte pendant l'attaque : c'est le cuivre qui s'ouvre."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    rng = np.random.default_rng(seed + 89)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for v in range(3):                                          # petit pupitre
        ph = _phase(freq, n, rng.normal(0, 0.0018), 0.003, 4.8 + rng.random(), 0.4, rng)
        idx = (1.1 + 4.4 * vel) * (1.0 - np.exp(-t * 9.0)) * np.exp(-t * 0.45)
        out += np.sin(ph + idx * np.sin(ph))
    out /= 3
    out = formants(out, [(430.0, 160.0, 4.5), (1250.0, 420.0, 3.0)])   # pavillon
    breath = lowpass(rng.standard_normal(n), 1800.0) * 0.035 * np.exp(-t * 7.0)
    return (out + breath) * adsr(n, 0.10, 0.30, 0.80, min(1.0, dur * .45)) * (0.4 + 0.6 * vel)


def brass_ff(freq, dur, vel=0.9, seed=0):
    """Cuivres tutti : plus d'index, plus d'eclat, attaque plus mordante."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    rng = np.random.default_rng(seed + 97)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for v in range(4):
        ph = _phase(freq, n, rng.normal(0, 0.0022), 0.0025, 5.1 + rng.random(), 0.45, rng)
        idx = (2.6 + 7.0 * vel) * (1.0 - np.exp(-t * 16.0)) * np.exp(-t * 0.35)
        out += np.sin(ph + idx * np.sin(ph))
        out += 0.42 * np.sin(2 * ph + idx * 0.8 * np.sin(ph))
        out += 0.20 * np.sin(3 * ph + idx * 0.5 * np.sin(ph))
        out += 0.30 * np.sin(ph + idx * 0.55 * np.sin(3.0 * ph))   # eclat : modulateur x3
    out /= 4
    out = formants(out, [(520.0, 190.0, 3.0), (1700.0, 600.0, 5.5), (3300.0, 1100.0, 6.0)])
    return out * adsr(n, 0.055, 0.22, 0.83, min(0.9, dur * .4)) * (0.4 + 0.6 * vel)


# ═══════════════════════════════════════════════════════════════════════════════
# BOIS
# ═══════════════════════════════════════════════════════════════════════════════

def flute(freq, dur, vel=0.7, seed=0):
    """Flute : peu d'harmoniques, beaucoup de souffle."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    rng = np.random.default_rng(seed + 101)
    t = np.arange(n) / SR
    ph = _phase(freq, n, 0.0, 0.0055, 5.2, 0.3, rng)
    sig = np.sin(ph) + 0.14 * vel * np.sin(2 * ph) + 0.05 * vel * np.sin(3 * ph)
    air = lowpass(rng.standard_normal(n), 4200.0 + 2600.0 * vel)
    air *= 0.085 * (0.5 + 0.5 * vel) * (0.35 + 0.65 * np.exp(-t * 4.5))
    return (sig * 0.5 + air) * adsr(n, 0.085, 0.14, 0.88, 0.28) * (0.45 + 0.55 * vel)


def oboe(freq, dur, vel=0.7, seed=0):
    """Hautbois : anche double, spectre dense, formant nasal marque."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    rng = np.random.default_rng(seed + 103)
    ph = _phase(freq, n, 0.0, 0.0048, 5.6, 0.28, rng)
    sig = np.zeros(n)
    for h, a in ((1, .55), (2, .85), (3, 1.0), (4, .78), (5, .55), (6, .34), (7, .2), (8, .12)):
        sig += a * np.sin(h * ph)
    sig = formants(sig, [(1400.0, 380.0, 5.0), (2900.0, 700.0, 2.5)])
    return sig * 0.18 * adsr(n, 0.06, 0.12, 0.9, 0.24) * (0.45 + 0.55 * vel)


def clarinet(freq, dur, vel=0.65, seed=0):
    """Clarinette : tuyau ferme, donc harmoniques impaires dominantes."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    rng = np.random.default_rng(seed + 107)
    ph = _phase(freq, n, 0.0, 0.0035, 4.9, 0.35, rng)
    sig = np.zeros(n)
    for h, a in ((1, 1.0), (3, .42), (5, .22), (7, .12), (9, .06)):
        sig += a * np.sin(h * ph)
    sig += 0.08 * vel * np.sin(2 * ph)                          # un rien de pair
    sig = formants(sig, [(1500.0, 500.0, 2.5)])
    return sig * 0.34 * adsr(n, 0.075, 0.13, 0.9, 0.26) * (0.45 + 0.55 * vel)


# ═══════════════════════════════════════════════════════════════════════════════
# HARPE, CLAVIERS, PERCUSSIONS
# ═══════════════════════════════════════════════════════════════════════════════

def harp(freq, dur, vel=0.7, seed=0):
    """Harpe celtique : corde pincee, amortissement long."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    d = max(2, int(SR / freq))
    rng = np.random.default_rng(seed + 109)
    off = 1
    buf = np.zeros(off + n + d + 2)
    exc = lowpass(rng.standard_normal(d) * np.hanning(d), 1400.0 + 5000.0 * vel)
    buf[off:off + d] = exc
    damp = 0.9948 - 0.00034 * (freq / 220.0)
    i, end = off + d, off + n
    while i < end:
        blk = min(d, end - i)
        buf[i:i + blk] = damp * 0.5 * (buf[i - d:i - d + blk] + buf[i - d - 1:i - d - 1 + blk])
        i += blk
    sig = buf[off:off + n]
    sig = formants(sig, [(300.0, 140.0, 2.5)])                  # caisse
    return sig * adsr(n, 0.001, 0.05, 0.9, min(0.6, dur * .4)) * vel * 0.85


def glockenspiel(freq, dur, vel=0.7, seed=0):
    """Glockenspiel : FM tres inharmonique, extinction rapide. Le scintillement."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    t = np.arange(n) / SR
    idx = (2.2 + 2.0 * vel) * np.exp(-t * 12.0)
    sig = np.sin(2 * np.pi * freq * t + idx * np.sin(2 * np.pi * freq * 3.17 * t))
    sig += 0.35 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-t * 22.0)
    return sig * np.exp(-t * 3.2) * (1 - np.exp(-t * 700.0)) * vel * 0.34


def celesta_bell(freq, dur, vel=0.6, seed=0):
    """La cloche froide de la palette Prime : FM ratio racine de 2."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    t = np.arange(n) / SR
    idx = (4.0 + 2.5 * vel) * np.exp(-t * 3.4)
    sig = np.sin(2 * np.pi * freq * t + idx * np.sin(2 * np.pi * freq * 1.4142 * t))
    sig += 0.26 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t * 7.0)
    sig += 0.10 * np.sin(2 * np.pi * freq * 5.43 * t) * np.exp(-t * 13.0)
    return sig * np.exp(-t * 1.5) * (1 - np.exp(-t * 400.0)) * vel * 0.5


def timpani(freq, dur, vel=0.8, seed=0):
    """Timbale : mode fondamental + modes inharmoniques de membrane."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    rng = np.random.default_rng(seed + 113)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for r, a, dec in ((1.00, 1.0, 1.6), (1.50, .45, 2.6), (1.98, .26, 3.8),
                      (2.44, .15, 5.2), (2.89, .08, 7.0)):
        sig += a * np.sin(2 * np.pi * freq * r * t + rng.random() * 6.28) * np.exp(-t * dec)
    strike = lowpass(rng.standard_normal(n), 2600.0 + 2500.0 * vel) * np.exp(-t * 40.0) * 0.22
    skin = bandpass(rng.standard_normal(n), 120.0, 900.0) * np.exp(-t * 9.0) * 0.12
    return (sig * 0.5 + strike + skin) * vel


def taiko(freq, dur, vel=0.9, seed=0):
    """Frappe seche et grave — le contrepoint tribal aux nappes noyees."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    rng = np.random.default_rng(seed + 127)
    t = np.arange(n) / SR
    f = freq * np.exp(-t * 5.5) + freq * 0.55
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6.0)
    crack = lowpass(highpass(rng.standard_normal(n) * np.exp(-t * 38.0), 700.0), 6500.0) * 0.20
    skin = lowpass(rng.standard_normal(n) * np.exp(-t * 22.0), 2600.0) * 0.15
    return (body * 0.95 + crack + skin) * vel


def cymbal_swell(dur, vel=0.6, seed=0, reverse=True):
    """Cymbale suspendue : bruit dense qui gonfle. Ponctue les fins de phrase."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    rng = np.random.default_rng(seed + 131)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    shimmer = bandpass(noise, 2600.0, 13000.0)
    body = bandpass(noise, 700.0, 3200.0) * 0.45
    if reverse:
        env = (t / max(t[-1], 1e-6)) ** 2.4                      # crescendo
        env *= np.exp(-np.clip(t - dur * 0.86, 0, None) * 14.0)  # coupe nette a la fin
    else:
        env = np.exp(-t * 2.2)
    return (shimmer + body) * env * vel * 0.28


# ═══════════════════════════════════════════════════════════════════════════════
# VOIX ET NAPPES
# ═══════════════════════════════════════════════════════════════════════════════

def choir(freq, dur, vel=0.6, seed=0, vowel="ah"):
    """Choeur : voix decorrelees + formants de voyelle."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    rng = np.random.default_rng(seed + 137)
    F = {"ah": [(730.0, 130.0, 6.0), (1090.0, 190.0, 4.5), (2440.0, 400.0, 2.0)],
         "oo": [(300.0, 90.0, 6.0), (870.0, 160.0, 3.0), (2240.0, 380.0, 1.0)]}[vowel]
    out = np.zeros(n)
    for v in range(6):
        ph = _phase(freq, n, rng.normal(0, 0.0038), 0.0052, 4.6 + 1.4 * rng.random(),
                    0.3 + 0.3 * rng.random(), rng)
        for h, a in ((1, 1.0), (2, .5), (3, .3), (4, .18), (5, .1), (6, .06)):
            out += a * np.sin(h * ph)
    out /= 6
    out = formants(out, F)
    breath = lowpass(rng.standard_normal(n), 2600.0) * 0.045
    return (out * 0.2 + breath) * adsr(n, 1.1, 0.6, 0.84, min(2.0, dur * .5)) * (0.4 + 0.6 * vel)


def pad_fm(freq, dur, vel=0.6, seed=0, detune=0.0):
    """La nappe froide qui porte l'identite Prime sous l'orchestre."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    t = np.arange(n) / SR
    f = freq * (1.0 + detune)
    drift = 1.0 + 0.0015 * np.sin(2 * np.pi * 0.07 * t + freq)
    mod = np.sin(2 * np.pi * f * 2.005 * t) * (1.3 + 0.6 * np.sin(2 * np.pi * 0.05 * t))
    car = np.sin(2 * np.pi * f * t * drift + mod) + 0.15 * np.sin(np.pi * f * t)
    return lowpass(car, 2600.0 + 1400.0 * vel) * adsr(n, 2.4, 1.0, 0.78, min(3.0, dur * .5)) * vel


def sub(freq, dur, vel=0.7, seed=0):
    """Fondamentale saturee, pour survivre aux petits haut-parleurs."""
    n = int(dur * SR)
    if n <= 0:
        return np.zeros(0)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * freq * t) + 0.18 * np.sin(2 * np.pi * freq * 2 * t)
    sig = np.tanh(sig * 1.05) * 0.46
    return lowpass(sig, 320.0) * adsr(n, 0.7, 0.5, 0.82, min(1.6, dur * .5)) * vel


# ═══════════════════════════════════════════════════════════════════════════════
# SALLE — reverbe et placement sur scene
# ═══════════════════════════════════════════════════════════════════════════════

def make_ir(seconds: float, decay: float, damp: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    ir = rng.standard_normal(n) * np.exp(-np.linspace(0.0, decay, n))
    dark = lowpass(ir, damp)
    w = np.linspace(0.0, 1.0, n)
    ir = ir * (1.0 - w) + dark * w
    # premieres reflexions : ce sont elles qui donnent la taille de la salle
    for delay_ms, amp in ((17, .5), (23, .42), (31, .34), (43, .26), (59, .19), (73, .14)):
        i = int(delay_ms * SR / 1000)
        if i < n:
            ir[i] += amp
    ir[: int(0.006 * SR)] *= np.linspace(0.0, 1.0, int(0.006 * SR))
    return ir / (np.abs(ir).max() + 1e-9)


def stereo_hall(seconds=4.0, decay=5.4, damp=3200.0, seed=7, width=0.24):
    """Deux IR a tronc commun : large au casque, mais compatible mono."""
    c = make_ir(seconds, decay, damp, seed)
    l = make_ir(seconds, decay * 1.04, damp * 1.1, seed + 101)
    r = make_ir(seconds, decay * 0.96, damp * 0.9, seed + 202)
    k = 1.0 - width
    return k * c + width * l, k * c + width * r


def convolve(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    n = len(x) + len(ir) - 1
    nfft = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[: len(x)]


# Position de chaque pupitre : (panoramique, distance 0-1)
# La distance ajoute de la reverbe, mange les aigus et retarde legerement.
STAGE = {
    "strings_high": (-0.42, 0.30), "strings_mid": (-0.10, 0.36),
    "strings_low": (0.40, 0.38), "strings_tremolo": (-0.28, 0.34),
    "pizzicato": (0.30, 0.30), "harp": (-0.52, 0.34),
    "flute": (-0.16, 0.52), "oboe": (0.14, 0.52), "clarinet": (-0.05, 0.54),
    "horn": (0.44, 0.64), "brass_ff": (0.26, 0.68),
    "timpani": (0.16, 0.78), "cymbal": (-0.34, 0.74), "taiko": (0.0, 0.55),
    "glockenspiel": (0.50, 0.60), "celesta_bell": (-0.60, 0.44),
    "choir": (0.0, 0.80), "pad_fm": (0.0, 0.62), "sub": (0.0, 0.30),
}


def place(sig: np.ndarray, instrument: str, n_out: int, at: int) -> tuple[np.ndarray, np.ndarray, float]:
    """Applique la distance (couleur + pre-delai) et rend les deux canaux + le send."""
    pan, dist = STAGE.get(instrument, (0.0, 0.4))
    if dist > 0.05:
        sig = lowpass(sig, 18000.0 - 7000.0 * dist)            # l'air mange les aigus
    pre = int(dist * 0.012 * SR)
    if pre:
        sig = np.concatenate([np.zeros(pre), sig])[: len(sig)]
    gl = np.sqrt(0.5 * (1.0 - pan)) * 1.4142
    gr = np.sqrt(0.5 * (1.0 + pan)) * 1.4142
    return sig * gl, sig * gr, 0.18 + 0.62 * dist
