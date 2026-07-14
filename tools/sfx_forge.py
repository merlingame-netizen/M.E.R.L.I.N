# -*- coding: utf-8 -*-
"""SFX forge M.E.R.L.I.N. — v4 physical-modeling (numpy/scipy) — BIBLE §22.

Remplace la synthese naive (sinus+FM+bruit universels) par de VRAIS modeles
physiques vectorises, groupes par famille du catalogue celtique :

  - FOLEY PARCHEMIN      : granulaire (trains de micro-craquements band-limites)
  - PINCE HARPE          : Karplus-Strong etendu (gamme penta D / DADGAD)
  - MODAL INHARMONIQUE   : banque de resonateurs (cloches, carillons, drift)
  - MEMBRANE + RESONANCE : bodhran (excitation-bruit + membrane modale)
  - FRICTION / BOURDON   : corde frottee (drone soutenu + souffle)
  - BOL CHANTANT          : banded-waveguide approxime (partiels battants, swell)
  - VOIX                 : FM douce anti-repliement (waveguide voyelle courte)

Anti-aliasing OBLIGATOIRE : partiels plafonnes sous Nyquist ; FM/waveshaping
suréchantillonnés 4x puis décimés ; aucune somme de partiels au-dessus de Nyquist.
Normalisation loudness deterministe (pyloudnorm two-target) via sfx_normalize.
Seed FIXE par recette -> generation octet-identique (R119). Manifest JSON par CI.

Usage:
    python tools/sfx_forge.py --list
    python tools/sfx_forge.py --id card_pick
    python tools/sfx_forge.py --all          # regenere + ecrit audio/sfx/manifest.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from scipy import signal

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from tools import sfx_normalize as norm  # noqa: E402

SR = norm.SR
OUT_DIR = Path(__file__).resolve().parent.parent / "audio" / "sfx"
MANIFEST = OUT_DIR / "manifest.json"

# Part de synthese "synth" toleree hors familles 100% acoustiques (reglable).
# 0 = harpe & bol chantant (purement modelises), 0.15 ailleurs (leger grain synth).
SYNTH_MIX = 0.15

# ── Cibles de loudness par CATEGORIE (LUFS integres) — calees empiriquement ────
# Les sons courts/percussifs (ticks) sont plafonnes true-peak -14 dBFS : leur
# LUFS "naturel" a ce plafond est bas, d'ou des cibles decroissantes.
# Sous un plafond true-peak de -14 dBFS, la loudness integree d'un one-shot
# naturel est bornee par sa crete (LOUD = crete basse = son soutenu). On rabote
# donc la crete a une valeur homogene PAR CATEGORIE (CREST_CAPS), ce qui rend la
# cible LUFS atteignable EXACTEMENT (attenuation pure) pour tous ses membres.
# Ladder monotone : ticks les plus discrets -> stingers = evenements de reference.
TARGETS = {
    "tick":    -26.5,   # UI ultra-court : quill, slider, button, voice
    "foley":   -26.5,   # parchemin/cartes
    "drone":   -25.0,   # seuils soutenus (whisper, question)
    "accent":  -25.5,   # cloches/carillons/reveal/gauge
    "impact":  -26.0,   # sceau, corruption
    "stinger": -24.5,   # stingers de degre (reference — evenement)
    "ending":  -24.5,   # stingers de fin
}
# Facteur de crete cible par categorie (true-peak - LUFS, en dB). Choisi ~= la
# crete naturelle du membre le plus soutenu -> limiting minimal sur les autres.
CREST_CAPS = {
    "tick":    12.5, "foley": 12.5, "drone": 11.0, "accent": 11.5,
    "impact":  12.0, "stinger": 11.0, "ending": 11.0,
}

# ── Gammes celtiques ──────────────────────────────────────────────────────────
# Pentatonique de RÉ (D) — coeur mélodique du jeu.
PENTA_D = np.array([146.83, 174.61, 196.00, 220.00, 261.63])          # D3 F3 G3 A3 C4
PENTA_D_HI = np.array([293.66, 349.23, 392.00, 440.00, 523.25])       # D4 F4 G4 A4 C5
DADGAD = np.array([146.83, 220.00, 293.66, 392.00, 440.00, 587.33])   # D A d g a d'


def _rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def _t(n: int) -> np.ndarray:
    return np.arange(n, dtype=np.float64) / SR


def env_exp(n: int, attack: float, tau: float) -> np.ndarray:
    """Attaque lineaire courte + decroissance exponentielle."""
    a = max(1, int(SR * attack))
    e = np.empty(n)
    a = min(a, n)
    e[:a] = np.linspace(0.0, 1.0, a, endpoint=False) if a > 1 else 1.0
    if n > a:
        e[a:] = np.exp(-np.arange(n - a) / (SR * tau))
    return e


# ═══════════════════════════════════════════════════════════════════════════
#  FAMILLE : PINCÉ HARPE — Karplus-Strong étendu (via IIR sparse lfilter)
# ═══════════════════════════════════════════════════════════════════════════

def ks_pluck(freq: float, dur: float, seed: int, damping: float = 0.996,
             brightness: float = 0.5, pick_pos: float = 0.3,
             level: float = 1.0) -> np.ndarray:
    """Corde pincee (Karplus-Strong etendu).

    Boucle de retard L = SR/freq avec filtre moyenne (amortissement/timbre) —
    implementee en IIR sparse via scipy.lfilter (rapide, deterministe, band-limite).
    `brightness` melange 1-pole passe-bas dans la boucle ; `pick_pos` filtre en
    peigne l'excitation (position de pincement) ; `damping` regle la duree.
    """
    n = int(SR * dur)
    L = max(2, int(round(SR / freq)))
    rng = _rng(seed)
    # Excitation : rafale de bruit sur une periode, adoucie (durete du mediator)
    exc = np.zeros(n)
    burst = rng.uniform(-1.0, 1.0, min(L, n))
    # filtre le bruit d'excitation selon brightness (mediator dur -> plus aigu)
    lp_a = np.clip(0.3 + 0.6 * brightness, 0.1, 0.95)
    for i in range(1, burst.size):
        burst[i] = lp_a * burst[i] + (1.0 - lp_a) * burst[i - 1]
    exc[:burst.size] = burst
    # peigne de position de pincement : annule l'harmonique ~1/pick_pos
    d = max(1, int(L * pick_pos))
    if d < n:
        exc[d:] -= exc[:-d]
    # Filtre KS : y[i] = x[i] + g*0.5*(y[i-L] + y[i-L-1])
    g = damping
    a = np.zeros(L + 2)
    a[0] = 1.0
    a[L] = -0.5 * g
    a[L + 1] = -0.5 * g
    y = signal.lfilter([1.0], a, exc)
    y *= env_exp(n, 0.001, dur * 0.5)   # enveloppe globale de securite (queue propre)
    # adoucit la toute premiere impulsion (mediator) -> crete plus naturelle
    atk = min(int(0.004 * SR), n)
    if atk > 1:
        y[:atk] *= 0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, atk))
    peak = np.max(np.abs(y))
    if peak > 1e-9:
        y = y / peak * level
    return y


def harp_arpeggio(notes: np.ndarray, dur: float, seed: int, spacing: float,
                  note_dur: float, damping: float = 0.994,
                  brightness: float = 0.55) -> np.ndarray:
    """Arpege de cordes pincees (glissando harpe montant/descendant)."""
    n = int(SR * dur)
    out = np.zeros(n)
    for k, f in enumerate(notes):
        start = int(k * spacing * SR)
        pluck = ks_pluck(float(f), note_dur, seed + k, damping=damping,
                         brightness=brightness, level=1.0 - 0.05 * k)
        end = min(n, start + pluck.size)
        if start < n:
            out[start:end] += pluck[:end - start]
    return out


# ═══════════════════════════════════════════════════════════════════════════
#  FAMILLE : MODAL INHARMONIQUE — banque de résonateurs (cloches, carillons)
# ═══════════════════════════════════════════════════════════════════════════

def modal(dur: float, base: float, partials: list[tuple[float, float, float]],
          drift: float = 0.0, beat: float = 0.0, attack: float = 0.002) -> np.ndarray:
    """Somme de partiels sinusoidaux à décroissance individuelle (anti-aliasée).

    `partials` : liste de (ratio_freq, amplitude, tau_decay). Chaque partiel
    au-dessus de 0.45*SR est ecarte (pas de repliement). `drift` applique un
    glissando lent (cloche corrompue) ; `beat` desaccorde un jumeau (battement).
    """
    n = int(SR * dur)
    t = _t(n)
    out = np.zeros(n)
    nyq = 0.45 * SR
    for ratio, amp, tau in partials:
        f = base * ratio
        if f >= nyq:
            continue
        inst = f * (1.0 + drift * t)         # drift lent (Hz proportionnel)
        phase = 2.0 * np.pi * np.cumsum(inst) / SR
        dec = np.exp(-t / tau)
        atk = np.minimum(1.0, t / max(attack, 1e-4))
        out += amp * atk * dec * np.sin(phase)
        if beat > 0.0 and f * (1.0 + beat) < nyq:
            phase2 = 2.0 * np.pi * np.cumsum(f * (1.0 + beat) * (1.0 + drift * t)) / SR
            out += amp * 0.6 * atk * dec * np.sin(phase2)
    peak = np.max(np.abs(out))
    return out / peak if peak > 1e-9 else out


# Partiels d'une petite cloche (inharmonique — hum, prime, tierce, quinte, nominale)
BELL_PARTIALS = [
    (0.56, 0.55, 1.6), (0.92, 0.42, 1.3), (1.19, 1.00, 1.1),
    (1.71, 0.38, 0.7), (2.00, 0.55, 0.6), (2.74, 0.22, 0.45),
    (3.00, 0.30, 0.35), (3.76, 0.14, 0.25),
]
# Barre/tube métallique (carillon ogham) — plus pur, partiels de barre libre
BAR_PARTIALS = [
    (1.00, 1.00, 1.4), (2.76, 0.45, 0.8), (5.40, 0.18, 0.4), (8.93, 0.08, 0.22),
]


# ═══════════════════════════════════════════════════════════════════════════
#  FAMILLE : BOL CHANTANT — banded-waveguide approximé (partiels battants)
# ═══════════════════════════════════════════════════════════════════════════

def singing_bowl(dur: float, base: float, seed: int, swell: float = 0.35,
                 partials: tuple[float, ...] = (1.0, 2.32, 3.50, 4.16)) -> np.ndarray:
    """Bol tibetain/cristal : partiels inharmoniques battants + swell d'archet.

    Chaque partiel est une PAIRE legerement desaccordee -> battement (shimmer).
    Enveloppe a montee lente (frottement du bord) + longue traine. 100% sinus
    sous Nyquist -> aucun repliement.
    """
    n = int(SR * dur)
    t = _t(n)
    out = np.zeros(n)
    rng = _rng(seed)
    nyq = 0.45 * SR
    for i, ratio in enumerate(partials):
        f = base * ratio
        if f >= nyq:
            continue
        beat_hz = 0.8 + 0.6 * i + rng.uniform(-0.2, 0.2)   # battement lent par partiel
        amp = 1.0 / (1.0 + i * 1.3)
        tau = dur * (0.7 - 0.1 * i)
        dec = np.exp(-t / max(tau, 0.3))
        s1 = np.sin(2.0 * np.pi * f * t)
        s2 = np.sin(2.0 * np.pi * (f + beat_hz) * t)
        out += amp * dec * (s1 + s2)
    # swell d'archet : montee lente puis stabilisation
    env = (1.0 - np.exp(-t / (dur * swell))) * np.exp(-t / (dur * 1.4))
    out *= env
    peak = np.max(np.abs(out))
    return out / peak if peak > 1e-9 else out


# ═══════════════════════════════════════════════════════════════════════════
#  FAMILLE : MEMBRANE + RÉSONANCE — bodhrán / sceau (excitation-bruit + modes)
# ═══════════════════════════════════════════════════════════════════════════

# Modes d'une membrane circulaire (ratios de Bessel normalisés)
MEMBRANE_RATIOS = [1.00, 1.59, 2.14, 2.30, 2.65, 2.92]


def membrane(dur: float, base: float, seed: int, strike: float = 0.006,
             metal: float = 0.0, metal_base: float = 1800.0) -> np.ndarray:
    """Frappe de membrane (bodhran) : mallet-noise -> modes membrane + thud grave.

    `metal` (0-1) ajoute une petite resonance metallique (sceau qui se presse).
    """
    n = int(SR * dur)
    t = _t(n)
    rng = _rng(seed)
    # Excitation : impulsion de mailloche = bruit tres court passe-bas
    exc = rng.uniform(-1.0, 1.0, n) * np.exp(-t / strike)
    sos = signal.butter(2, 2500.0 / (SR * 0.5), btype="lowpass", output="sos")
    exc = signal.sosfilt(sos, exc)
    # Modes de la membrane (amortissement rapide, pitch bas)
    out = np.zeros(n)
    nyq = 0.45 * SR
    for i, ratio in enumerate(MEMBRANE_RATIOS):
        f = base * ratio
        if f >= nyq:
            continue
        tau = 0.28 / (1.0 + i * 0.6)
        out += (1.0 / (1.0 + i)) * np.exp(-t / tau) * np.sin(2.0 * np.pi * f * t)
    # thud du fut (peau tendue) — sinus grave amorti
    out += 0.8 * np.exp(-t / 0.10) * np.sin(2.0 * np.pi * (base * 0.75) * t)
    body = 0.6 * out / (np.max(np.abs(out)) + 1e-9) + 0.4 * exc / (np.max(np.abs(exc)) + 1e-9)
    if metal > 0.0:
        ring = np.zeros(n)
        for ratio, amp, tau in [(1.0, 1.0, 0.22), (2.41, 0.5, 0.14), (3.9, 0.28, 0.08)]:
            f = metal_base * ratio
            if f < nyq:
                ring += amp * np.exp(-t / tau) * np.sin(2.0 * np.pi * f * t)
        ring /= (np.max(np.abs(ring)) + 1e-9)
        body = body + metal * ring
    peak = np.max(np.abs(body))
    return body / peak if peak > 1e-9 else body


# ═══════════════════════════════════════════════════════════════════════════
#  FAMILLE : FRICTION / BOURDON — corde frottée (drone soutenu + souffle)
# ═══════════════════════════════════════════════════════════════════════════

def bowed_drone(dur: float, freqs: tuple[float, ...], seed: int,
                noise_amt: float = 0.28, vibrato: float = 0.004) -> np.ndarray:
    """Bourdon frotte : resonateurs entretenus par une friction (bruit band-passe).

    Un souffle de friction (bruit filtre) excite des cordes (KS a fort feedback,
    donc quasi-soutenues) ; vibrato lent + swell. Timbre 'archet/vielle a roue'.
    """
    n = int(SR * dur)
    t = _t(n)
    rng = _rng(seed)
    out = np.zeros(n)
    _ = vibrato  # reserve : vibrato KS = delai fractionnaire (non applique pour l'instant)
    for j, f0 in enumerate(freqs):
        f = f0
        L = max(2, int(round(SR / f)))
        exc = rng.standard_normal(n) * 0.5
        # friction pulsee (dents de la roue / archet) : modulation lente
        exc *= (0.6 + 0.4 * np.abs(np.sin(2.0 * np.pi * (0.7 + 0.3 * j) * t)))
        a = np.zeros(L + 2)
        a[0] = 1.0
        a[L] = -0.5 * 0.9995
        a[L + 1] = -0.5 * 0.9995
        string = signal.lfilter([1.0], a, exc)
        out += string / (np.max(np.abs(string)) + 1e-9) / (1.0 + j)
    # souffle de friction band-passe (air/frottement)
    sos = signal.butter(2, [400.0 / (SR * 0.5), 2600.0 / (SR * 0.5)], btype="band", output="sos")
    breath = signal.sosfilt(sos, rng.standard_normal(n))
    breath /= (np.max(np.abs(breath)) + 1e-9)
    swell = (1.0 - np.exp(-t / (dur * 0.25))) * np.exp(-t / (dur * 1.6))
    mixed = (out / (np.max(np.abs(out)) + 1e-9) * (1.0 - noise_amt) + breath * noise_amt) * swell
    peak = np.max(np.abs(mixed))
    return mixed / peak if peak > 1e-9 else mixed


def breath_layer(dur: float, seed: int, lo: float, hi: float,
                 attack: float, tau: float) -> np.ndarray:
    """Souffle/vent band-passe simple (transitions, question)."""
    n = int(SR * dur)
    rng = _rng(seed)
    sos = signal.butter(2, [lo / (SR * 0.5), hi / (SR * 0.5)], btype="band", output="sos")
    b = signal.sosfilt(sos, rng.standard_normal(n))
    e = env_exp(n, attack, tau)
    b *= e
    peak = np.max(np.abs(b))
    return b / peak if peak > 1e-9 else b


# ═══════════════════════════════════════════════════════════════════════════
#  FAMILLE : FOLEY PARCHEMIN — granulaire (micro-craquements band-limités)
# ═══════════════════════════════════════════════════════════════════════════

def granular_paper(dur: float, seed: int, density: float, band: tuple[float, float],
                   grain_ms: tuple[float, float] = (2.0, 8.0),
                   attack: float = 0.01, tau: float = 0.08,
                   fibre: float = 0.12) -> np.ndarray:
    """Texture de parchemin : train de micro-craquements band-limites + fibre.

    `density` = craquements/seconde ; chaque grain est un court bruit filtre
    band-passe (fibres qui cedent). Modele GRANULAIRE (≠ one-pole lisse v3).
    """
    n = int(SR * dur)
    rng = _rng(seed)
    out = np.zeros(n)
    n_grains = max(1, int(density * dur))
    lo, hi = band
    sos = signal.butter(2, [lo / (SR * 0.5), min(hi, 0.49 * SR) / (SR * 0.5)],
                        btype="band", output="sos")
    for _ in range(n_grains):
        pos = int(rng.uniform(0, n))
        glen = int(rng.uniform(*grain_ms) * SR / 1000.0)
        if glen < 2:
            continue
        gt = np.arange(glen) / SR
        grain = rng.uniform(-1.0, 1.0, glen) * np.hanning(glen)
        grain *= np.exp(-gt / (glen / SR * 0.5)) * rng.uniform(0.3, 1.0)
        end = min(n, pos + glen)
        out[pos:end] += grain[:end - pos]
    out = signal.sosfilt(sos, out)
    # nappe de fibre continue (souffle tres bas) pour lier les grains
    if fibre > 0.0:
        soft = signal.sosfilt(
            signal.butter(2, 1200.0 / (SR * 0.5), btype="lowpass", output="sos"),
            rng.standard_normal(n))
        out += fibre * soft / (np.max(np.abs(soft)) + 1e-9)
    out *= env_exp(n, attack, tau)
    # saturation douce : rabote les grains-outliers (facteur de crete plus naturel)
    rms = np.sqrt(np.mean(out ** 2)) + 1e-9
    out = np.tanh(out / (rms * 3.0)) * (rms * 3.0)
    peak = np.max(np.abs(out))
    return out / peak if peak > 1e-9 else out


# ═══════════════════════════════════════════════════════════════════════════
#  FAMILLE : VOIX — FM douce anti-repliement (waveguide voyelle courte)
# ═══════════════════════════════════════════════════════════════════════════

def fm_voice(dur: float, carrier: float, ratio: float, index: float,
             attack: float, tau: float, seed: int = 0,
             oversample: int = 4) -> np.ndarray:
    """FM douce suréchantillonnée 4x puis décimée (zéro repliement)."""
    n = int(SR * dur)
    n_os = n * oversample
    t = np.arange(n_os, dtype=np.float64) / (SR * oversample)
    mod = np.sin(2.0 * np.pi * carrier * ratio * t)
    car = np.sin(2.0 * np.pi * carrier * t + index * mod)
    y = signal.resample_poly(car, 1, oversample)[:n]
    y *= env_exp(n, attack, tau)
    peak = np.max(np.abs(y))
    return y / peak if peak > 1e-9 else y


# ═══════════════════════════════════════════════════════════════════════════
#  Réverb PROPRE (convolution d'une petite IR synthétique) — remplace Schroeder
# ═══════════════════════════════════════════════════════════════════════════

def clean_reverb(x: np.ndarray, seed: int, room: float = 0.35,
                 wet: float = 0.22, damp_hz: float = 4200.0) -> np.ndarray:
    """Petite reverb propre : convolution avec une IR = bruit decroissant amorti.

    Bien plus naturelle que la Schroeder 'boxy' universelle. IR courte (room s),
    amortie en HF (damp_hz). Appliquee LEGEREMENT et seulement ou c'est utile.
    """
    if wet <= 0.0:
        return x
    rng = _rng(seed)
    ir_len = int(room * SR)
    it = np.arange(ir_len) / SR
    ir = rng.standard_normal(ir_len) * np.exp(-it / (room * 0.4))
    sos = signal.butter(2, damp_hz / (SR * 0.5), btype="lowpass", output="sos")
    ir = signal.sosfilt(sos, ir)
    ir /= (np.max(np.abs(ir)) + 1e-9)
    tail = signal.fftconvolve(x, ir)          # taille x.size + ir_len - 1
    out = np.zeros(tail.size)
    out[: x.size] += x * (1.0 - wet)
    out += tail / (np.max(np.abs(tail)) + 1e-9) * wet * np.max(np.abs(x))
    return out


# ── Utilitaires de mixage ─────────────────────────────────────────────────────

def mix(*layers: np.ndarray) -> np.ndarray:
    n = max(a.size for a in layers)
    out = np.zeros(n)
    for a in layers:
        out[: a.size] += a
    return out


def concat(*parts: np.ndarray) -> np.ndarray:
    return np.concatenate(parts)


def place(total: float, segs: list[tuple[float, np.ndarray]]) -> np.ndarray:
    """Place des segments (temps de debut en s, buffer) sur une timeline."""
    n = int(SR * total)
    out = np.zeros(n)
    for at, seg in segs:
        start = int(at * SR)
        end = min(n, start + seg.size)
        if start < n:
            out[start:end] += seg[: end - start]
    return out


def synth_grain(x: np.ndarray, seed: int, amt: float = SYNTH_MIX) -> np.ndarray:
    """Ajoute une legere composante 'synth' (grain FM) par-dessus l'acoustique."""
    if amt <= 0.0:
        return x
    rng = _rng(seed)
    n = x.size
    t = _t(n)
    g = np.sin(2.0 * np.pi * 110.0 * t + 0.4 * np.sin(2.0 * np.pi * 220.0 * t))
    g *= np.exp(-t / (n / SR * 0.5)) * (0.5 + 0.5 * rng.uniform(0, 1))
    return x * (1.0 - amt) + amt * g / (np.max(np.abs(g)) + 1e-9) * np.max(np.abs(x))


# ═══════════════════════════════════════════════════════════════════════════
#  RECETTES CANON (ids = BIBLE §22 — ne pas renommer)
#  chaque entree : (famille, modele, categorie, fonction)
# ═══════════════════════════════════════════════════════════════════════════

def _card_pick(seed: int = 1101):
    return granular_paper(0.15, seed, density=90, band=(1500, 6500),
                          grain_ms=(1.5, 5.0), attack=0.006, tau=0.05, fibre=0.10)


def _card_play(seed: int = 1102):
    g = granular_paper(0.22, seed, density=70, band=(900, 4200),
                       grain_ms=(2.0, 7.0), attack=0.008, tau=0.09, fibre=0.14)
    return clean_reverb(g, seed + 1, room=0.28, wet=0.16)


def _card_discard(seed: int = 1103):
    return granular_paper(0.30, seed, density=120, band=(1200, 5500),
                          grain_ms=(2.0, 9.0), attack=0.02, tau=0.13, fibre=0.16)


def _deal(seed: int = 1104):
    # eventail : 3 froissis rapproches
    segs = [(0.0, granular_paper(0.10, seed, 80, (1600, 6000), (1.2, 4.0), 0.005, 0.04, 0.08)),
            (0.06, granular_paper(0.10, seed + 1, 80, (1500, 5800), (1.2, 4.0), 0.005, 0.04, 0.08)),
            (0.12, granular_paper(0.13, seed + 2, 90, (1400, 5600), (1.2, 4.5), 0.005, 0.05, 0.08))]
    return place(0.30, segs)


def _button_tap(seed: int = 1105):
    # pincée courte très amortie (harpe, aigu doux)
    return ks_pluck(392.0, 0.14, seed, damping=0.985, brightness=0.45,
                    pick_pos=0.28, level=1.0)


def _slider_tick(seed: int = 1106):
    # pincée ultra-courte (harpe, très aiguë et sèche)
    return ks_pluck(587.33, 0.06, seed, damping=0.975, brightness=0.6,
                    pick_pos=0.2, level=1.0)


def _gauge_up(seed: int = 1107):
    return harp_arpeggio(PENTA_D_HI[:4], 0.34, seed, spacing=0.055,
                         note_dur=0.22, damping=0.992, brightness=0.6)


def _gauge_down(seed: int = 1108):
    return harp_arpeggio(PENTA_D[::-1], 0.42, seed, spacing=0.07,
                         note_dur=0.26, damping=0.99, brightness=0.5)


def _corruption_tick(seed: int = 1109):
    # cloche légèrement inharmonique + drift lent (souillure)
    m = modal(0.42, 174.61, [(0.56, 0.5, 0.9), (1.0, 1.0, 0.8), (1.47, 0.6, 0.5),
                             (2.09, 0.35, 0.35), (2.71, 0.2, 0.22)],
              drift=-0.06, beat=0.008, attack=0.004)
    return synth_grain(m, seed, amt=SYNTH_MIX)


def _seal_stamp(seed: int = 1110):
    # frappe membrane + petite résonance métallique (sceau R112)
    return membrane(0.30, 110.0, seed, strike=0.005, metal=0.45, metal_base=2100.0)


def _beat_turn(seed: int = 1111):
    return granular_paper(0.46, seed, density=60, band=(700, 4000),
                          grain_ms=(3.0, 11.0), attack=0.05, tau=0.18, fibre=0.18)


def _draft_reveal(seed: int = 1112):
    # carillon arpégé (tierce montante) — barre métallique claire
    n1 = modal(0.34, 523.25, BAR_PARTIALS, attack=0.003)
    n2 = modal(0.44, 659.25, BAR_PARTIALS, attack=0.003)
    arp = place(0.5, [(0.0, n1), (0.14, n2)])
    return clean_reverb(arp, seed, room=0.45, wet=0.28)


def _ogham_chime(seed: int = 1113):
    # carillon ogham : 3 barres métalliques (quinte + octave) qui s'égrènent
    notes = [392.0, 587.33, 784.0]
    segs = [(i * 0.11, modal(0.5 - i * 0.06, f, BAR_PARTIALS, attack=0.002))
            for i, f in enumerate(notes)]
    ch = place(0.62, segs)
    return clean_reverb(ch, seed, room=0.5, wet=0.30)


def _magic_reveal(seed: int = 1114):
    # cloche + bol chantant (révélation merveilleuse)
    bell = modal(0.8, 523.25, BELL_PARTIALS, attack=0.004)
    bowl = singing_bowl(1.1, 261.63, seed, swell=0.3, partials=(1.0, 2.32, 3.5))
    rev = clean_reverb(mix(0.7 * bell, 0.8 * bowl), seed + 1, room=0.55, wet=0.30)
    return rev


def _voice_blip(seed: int = 1120):
    # blip voyelle FM douce anti-repliement (joué en rafale)
    return fm_voice(0.085, 175.0, 2.0, 0.45, attack=0.006, tau=0.030, seed=seed)


def _whisper_threshold(seed: int = 1130):
    # palier corruption (R75) : bourdon frotté grave + souffle, dissonant
    return bowed_drone(0.9, (233.08, 246.94), seed, noise_amt=0.34, vibrato=0.006)


def _question_transition(seed: int = 1131):
    # souffle + drone sustain LLM (« Merlin réfléchit »)
    drone = bowed_drone(1.1, (196.0, 293.66), seed, noise_amt=0.22, vibrato=0.004)
    br = breath_layer(1.1, seed + 1, lo=500, hi=3000, attack=0.15, tau=0.6)
    return mix(drone, 0.35 * br)


def _ink_wash(seed: int = 1132):
    g = granular_paper(0.55, seed, density=45, band=(400, 2600),
                       grain_ms=(4.0, 14.0), attack=0.04, tau=0.24, fibre=0.20)
    return clean_reverb(g, seed + 1, room=0.4, wet=0.22)


def _quill_tick(seed: int = 1121):
    return granular_paper(0.09, seed, density=180, band=(2500, 8000),
                          grain_ms=(0.8, 3.0), attack=0.002, tau=0.022, fibre=0.06)


# ── STINGERS DE DEGRÉ (accords KS + banque modale, progression tonale) ────────

def _soft_attack(x: np.ndarray, ms: float) -> np.ndarray:
    """Enveloppe de montee (raised-cosine) : transforme une attaque seche en swell
    (baisse le facteur de crete -> le son peut etre plus fort sous le plafond TP)."""
    a = min(int(ms * SR / 1000.0), x.size)
    if a > 1:
        x = x.copy()
        x[:a] *= 0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, a))
    return x


def _stinger_chord(root_notes, dur: float, seed: int, damping: float,
                   bell_ratio: float | None = None,
                   attack_ms: float = 55.0) -> np.ndarray:
    """Accord de cordes pincees (harpe) + option cloche cristalline au sommet.

    Un swell d'attaque (attack_ms) donne un caractere d'EVENEMENT (crescendo) et
    reduit la crete pour que le stinger tienne un niveau eleve sous le plafond TP.
    """
    n = int(SR * dur)
    out = np.zeros(n)
    for k, f in enumerate(root_notes):
        pluck = ks_pluck(float(f), dur, seed + k, damping=damping,
                         brightness=0.5, level=1.0 - 0.06 * k)
        out[: pluck.size] += pluck[: n]
    # nappe soutenue (bourdon frotte) sous l'accord : SUSTAIN -> crete plus basse,
    # le stinger peut donc tenir un niveau plus fort sous le plafond true-peak.
    pad = bowed_drone(dur, (float(root_notes[0]) * 0.5, float(root_notes[0])),
                      seed + 30, noise_amt=0.12, vibrato=0.003)
    out[: pad.size] += 0.55 * pad[: n]
    if bell_ratio is not None:
        bell = singing_bowl(dur, float(root_notes[-1]) * bell_ratio, seed + 20,
                            swell=0.25, partials=(1.0, 2.32, 3.5, 4.16))
        out[: bell.size] += 0.5 * bell[: n]
    return _soft_attack(out, attack_ms)


def _stinger_echec(seed: int = 1201):
    # mineur/dissonant + drift (échec)
    ch = _stinger_chord([174.61, 207.65, 233.08], 1.8, seed, damping=0.995)
    m = modal(1.8, 174.61, [(1.0, 0.6, 1.2), (1.19, 0.4, 0.8), (2.5, 0.2, 0.4)],
              drift=-0.02, beat=0.01)
    return clean_reverb(mix(ch, 0.4 * m), seed, room=0.6, wet=0.28)


def _stinger_partiel(seed: int = 1202):
    ch = _stinger_chord([220.0, 277.18, 329.63], 1.6, seed, damping=0.994)
    return clean_reverb(ch, seed, room=0.55, wet=0.28)


def _stinger_reussite(seed: int = 1203):
    ch = _stinger_chord([196.0, 246.94, 293.66, 392.0], 1.9, seed, damping=0.993)
    return clean_reverb(ch, seed, room=0.6, wet=0.30)


def _stinger_eclatante(seed: int = 1204):
    # majeur cristallin : accord harpe + cloche + bol chantant (banded-waveguide)
    ch = _stinger_chord([261.63, 329.63, 392.0, 523.25], 2.3, seed,
                        damping=0.992, bell_ratio=2.0)
    return clean_reverb(ch, seed, room=0.7, wet=0.32)


# ── STINGERS DE FIN (2-3 s : bol chantant + bourdon frotté + nappe) ───────────

def _stinger_fin_accomplissement(seed: int = 1301):
    bowl = singing_bowl(2.8, 196.0, seed, swell=0.35, partials=(1.0, 2.0, 3.0, 4.16))
    ch = _stinger_chord([196.0, 261.63, 329.63, 392.0], 2.8, seed + 5, damping=0.994)
    drone = bowed_drone(2.8, (98.0,), seed + 9, noise_amt=0.18, vibrato=0.003)
    return clean_reverb(mix(0.9 * bowl, 0.7 * ch, 0.5 * drone), seed, room=0.8, wet=0.34)


def _stinger_fin_mort(seed: int = 1302):
    # mineur grave : bol grave + bourdon coupé + thud sourd
    bowl = singing_bowl(2.6, 130.81, seed, swell=0.4, partials=(1.0, 2.32, 3.5))
    drone = bowed_drone(2.6, (65.41, 98.0), seed + 3, noise_amt=0.24, vibrato=0.004)
    thud = membrane(0.4, 70.0, seed + 7, strike=0.006, metal=0.0)
    return clean_reverb(mix(0.8 * bowl, 0.7 * drone, place(2.6, [(0.0, 0.8 * thud)])),
                        seed, room=0.85, wet=0.36)


def _stinger_fin_corrompu(seed: int = 1303):
    # drift + inharmonicité forte : cluster désaccordé grave qui gonfle
    bowl = singing_bowl(2.7, 116.54, seed, swell=0.45, partials=(1.0, 2.13, 2.71, 3.61))
    m = modal(2.7, 174.61, [(1.0, 0.6, 1.6), (1.06, 0.5, 1.3), (1.33, 0.4, 0.9),
                            (2.09, 0.25, 0.5)], drift=-0.05, beat=0.02)
    drone = bowed_drone(2.7, (58.27, 87.31), seed + 4, noise_amt=0.3, vibrato=0.008)
    return clean_reverb(mix(0.8 * bowl, 0.6 * m, 0.6 * drone), seed, room=0.8, wet=0.36)


# ── Registre : id -> (famille, modele, categorie, fonction) ───────────────────

RECIPES = {
    # FOLEY PARCHEMIN (granulaire)
    "card_pick":  ("foley_parchemin", "granular", "foley", _card_pick),
    "card_play":  ("foley_parchemin", "granular+reverb", "foley", _card_play),
    "card_discard": ("foley_parchemin", "granular", "foley", _card_discard),
    "deal":       ("foley_parchemin", "granular x3", "foley", _deal),
    "beat_turn":  ("foley_parchemin", "granular", "foley", _beat_turn),
    "ink_wash":   ("foley_parchemin", "granular+reverb", "foley", _ink_wash),
    "quill_tick": ("foley_parchemin", "granular", "tick", _quill_tick),
    # PINCÉ HARPE (Karplus-Strong)
    "gauge_up":   ("pince_harpe", "karplus-strong arp", "accent", _gauge_up),
    "gauge_down": ("pince_harpe", "karplus-strong arp", "accent", _gauge_down),
    "button_tap": ("pince_harpe", "karplus-strong", "tick", _button_tap),
    "slider_tick": ("pince_harpe", "karplus-strong", "tick", _slider_tick),
    # MODAL INHARMONIQUE (résonateurs)
    "corruption_tick": ("modal_inharmonique", "modal+drift", "impact", _corruption_tick),
    "draft_reveal": ("modal_inharmonique", "modal arp+reverb", "accent", _draft_reveal),
    "ogham_chime": ("modal_inharmonique", "modal bar+reverb", "accent", _ogham_chime),
    "magic_reveal": ("modal_inharmonique", "modal+bol+reverb", "accent", _magic_reveal),
    # MEMBRANE + RÉSONANCE
    "seal_stamp": ("membrane_resonance", "membrane+metal", "impact", _seal_stamp),
    # FRICTION / BOURDON
    "whisper_threshold": ("friction_bourdon", "bowed drone", "drone", _whisper_threshold),
    "question_transition": ("friction_bourdon", "bowed drone+souffle", "drone", _question_transition),
    # VOIX
    "voice_blip": ("voix", "fm 4x-os", "tick", _voice_blip),
    # STINGERS DEGRÉ
    "stinger_echec": ("stinger_degre", "ks chord+modal", "stinger", _stinger_echec),
    "stinger_partiel": ("stinger_degre", "ks chord", "stinger", _stinger_partiel),
    "stinger_reussite": ("stinger_degre", "ks chord", "stinger", _stinger_reussite),
    "stinger_eclatante": ("stinger_degre", "ks chord+bol", "stinger", _stinger_eclatante),
    # STINGERS FIN
    "stinger_fin_accomplissement": ("stinger_fin", "bol+ks+bourdon", "ending", _stinger_fin_accomplissement),
    "stinger_fin_mort": ("stinger_fin", "bol grave+bourdon+thud", "ending", _stinger_fin_mort),
    "stinger_fin_corrompu": ("stinger_fin", "bol+modal drift+bourdon", "ending", _stinger_fin_corrompu),
}

# Round-robin (anti-mitraillette) : variantes baked-in, seeds derives.
ROUND_ROBIN = {
    "card_pick": [("card_pick__v2", 1141), ("card_pick__v3", 1142)],
    # _deal consomme seed, seed+1, seed+2 -> espacer les variantes de >=3 (sons distincts)
    "deal": [("deal__v2", 1151), ("deal__v3", 1161)],
}


def _build(sfx_id: str) -> np.ndarray:
    if sfx_id in RECIPES:
        return RECIPES[sfx_id][3]()
    # variantes round-robin : meme recette, seed derive
    for base, variants in ROUND_ROBIN.items():
        for vid, vseed in variants:
            if vid == sfx_id:
                fn = RECIPES[base][3]
                return fn(seed=vseed)
    raise KeyError(sfx_id)


def _category(sfx_id: str) -> str:
    if sfx_id in RECIPES:
        return RECIPES[sfx_id][2]
    for base, variants in ROUND_ROBIN.items():
        if any(vid == sfx_id for vid, _ in variants):
            return RECIPES[base][2]
    return "foley"


def all_ids() -> list[str]:
    ids = list(RECIPES.keys())
    for base, variants in ROUND_ROBIN.items():
        ids.extend(vid for vid, _ in variants)
    return ids


def forge(sfx_id: str, manifest: dict | None = None) -> Path:
    raw = _build(sfx_id)
    cat = _category(sfx_id)
    target = TARGETS[cat]
    audio, stats = norm.normalize(raw, target_lufs=target, peak_ceiling_db=-14.0,
                                  trim=True, crest_cap_db=CREST_CAPS[cat])
    out = OUT_DIR / f"{sfx_id}.wav"
    norm.write_wav16(audio, out)
    fam = RECIPES[sfx_id][0] if sfx_id in RECIPES else RECIPES[_rr_base(sfx_id)][0]
    model = RECIPES[sfx_id][1] if sfx_id in RECIPES else RECIPES[_rr_base(sfx_id)][1]
    entry = {"family": fam, "model": model, "category": cat, "target_lufs": target, **stats}
    if manifest is not None:
        manifest[sfx_id] = entry
    print(f"OK {out.name:34s} {fam:20s} {stats['duration_s']:.2f}s "
          f"LUFS {stats['lufs']:+.1f} (cible {target:+.0f}) TP {stats['true_peak_db']:+.1f}")
    return out


def _rr_base(sfx_id: str) -> str:
    for base, variants in ROUND_ROBIN.items():
        if any(vid == sfx_id for vid, _ in variants):
            return base
    return sfx_id


def forge_all() -> dict:
    manifest: dict = {}
    for sfx_id in all_ids():
        forge(sfx_id, manifest)
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\n{len(manifest)} WAV generes -> {OUT_DIR}\nmanifest -> {MANIFEST}")
    return manifest


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(description="SFX forge M.E.R.L.I.N. v4 (BIBLE §22)")
    p.add_argument("--list", action="store_true")
    p.add_argument("--id")
    p.add_argument("--all", action="store_true")
    args = p.parse_args()
    if args.list:
        for i in all_ids():
            fam = RECIPES[i][0] if i in RECIPES else RECIPES[_rr_base(i)][0] + " (variant)"
            print(f"{i:34s} {fam}")
        print(f"\n{len(all_ids())} sons (catalogue canon BIBLE §22)")
        return 0
    if args.id:
        forge(args.id)
        return 0
    if args.all:
        forge_all()
        return 0
    p.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
