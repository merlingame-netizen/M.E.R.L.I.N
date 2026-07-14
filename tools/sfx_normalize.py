# -*- coding: utf-8 -*-
"""Normalisation audio DETERMINISTE, pur-Python (BIBLE §22 — Chantier 2).

Remplace la normalisation "peak-only" (-14 dBFS) par une chaine de mastering
mesurable et rejouable, partagee par sfx_forge.py et music_forge.py :

    1. rendu interne float64 (jamais de quantif 16-bit avant la fin)
    2. retrait DC + rumble : highpass Butterworth ~25 Hz (scipy, filtfilt)
    3. trim des silences tete/queue (sous un seuil relatif)
    4. loudness integree ITU-R BS.1770-4 / EBU R128 (pyloudnorm, sinon fallback vendorise)
    5. loudness-match par CATEGORIE (cible LUFS reglable)
    6. plafond true-peak (4x oversampling) — jamais de clipping
    7. WAV 44.1 kHz mono 16-bit + stats (LUFS integre, true-peak, duree, DC)

100% numpy/scipy (+ pyloudnorm si dispo). Aucune dependance native, headless,
octet-reproductible : memes entrees -> memes octets (R119).
"""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SR = 44100

# ── Mesure de loudness : pyloudnorm si dispo, sinon fallback vendorise ─────────
try:
    import pyloudnorm as _pyln  # type: ignore

    _METER = _pyln.Meter(SR)
    _HAS_PYLN = True
except Exception:  # pragma: no cover — filet de securite si pip bloque (GPO/reseau)
    _METER = None
    _HAS_PYLN = False


# ── Filtres de base ───────────────────────────────────────────────────────────

def highpass(x: np.ndarray, hz: float = 25.0, order: int = 2) -> np.ndarray:
    """Retrait DC + rumble : Butterworth passe-haut a phase nulle (filtfilt)."""
    if x.size < 3 * order + 1:
        return x - float(np.mean(x))
    sos = signal.butter(order, hz / (SR * 0.5), btype="highpass", output="sos")
    return signal.sosfiltfilt(sos, x).astype(np.float64)


def _k_weight(x: np.ndarray) -> np.ndarray:
    """K-weighting BS.1770 (fallback) : shelf +4 dB @ ~1.5k + highpass ~38 Hz."""
    # Stage 1 — high-shelf (coeffs BS.1770-4 @ 48k re-derives ici pour SR)
    # On approxime via un shelf numerique stable ; le fallback vise ±1 LU.
    # Shelf haute-frequence (~+4 dB au-dessus de ~1.5 kHz)
    b1, a1 = signal.iirfilter(2, 1500.0 / (SR * 0.5), btype="highpass",
                              ftype="butter", output="ba")
    hi = signal.lfilter(b1, a1, x)
    shelved = x + (10 ** (4.0 / 20.0) - 1.0) * hi
    # Stage 2 — highpass RLB ~38 Hz
    b2, a2 = signal.butter(2, 38.0 / (SR * 0.5), btype="highpass")
    return signal.lfilter(b2, a2, shelved)


def _lufs_fallback(x: np.ndarray) -> float:
    """Loudness integree gatee BS.1770 pure-numpy (si pyloudnorm absent)."""
    y = _k_weight(x)
    block = int(0.4 * SR)
    step = int(0.1 * SR)
    if y.size < block:
        y = np.concatenate([y, np.zeros(block - y.size)])
    starts = range(0, y.size - block + 1, step)
    powers = np.array([np.mean(y[s:s + block] ** 2) for s in starts])
    powers = np.maximum(powers, 1e-12)
    loud = -0.691 + 10.0 * np.log10(powers)
    # Gate absolu -70 LUFS
    g1 = loud > -70.0
    if not np.any(g1):
        return -70.0
    mean_pow = np.mean(powers[g1])
    rel = -0.691 + 10.0 * np.log10(mean_pow) - 10.0
    g2 = g1 & (loud > rel)
    if not np.any(g2):
        return -70.0
    return float(-0.691 + 10.0 * np.log10(np.mean(powers[g2])))


def measure_lufs(x: np.ndarray) -> float:
    """Loudness integree (LUFS). Pad si plus court que le bloc de 400 ms."""
    if x.size == 0:
        return -70.0
    buf = x
    min_len = int(0.5 * SR)
    if buf.size < min_len:
        buf = np.concatenate([buf, np.zeros(min_len - buf.size)])
    if _HAS_PYLN:
        try:
            val = _METER.integrated_loudness(buf)
        except Exception:
            val = _lufs_fallback(buf)
    else:
        val = _lufs_fallback(buf)
    if not math.isfinite(val):
        return -70.0
    return float(val)


def _oversample(x: np.ndarray, factor: int = 4) -> np.ndarray:
    return signal.resample_poly(x, factor, 1)


def true_peak_dbfs(x: np.ndarray, oversample: int = 4) -> float:
    """True-peak inter-echantillon (4x oversampling)."""
    if x.size == 0:
        return -120.0
    up = _oversample(x, oversample)
    peak = float(np.max(np.abs(up)))
    if peak <= 1e-9:
        return -120.0
    return 20.0 * math.log10(peak)


def peak_dbfs(x: np.ndarray) -> float:
    peak = float(np.max(np.abs(x))) if x.size else 0.0
    return 20.0 * math.log10(peak) if peak > 1e-9 else -120.0


def dc_offset(x: np.ndarray) -> float:
    return float(np.mean(x)) if x.size else 0.0


def trim_silence(x: np.ndarray, thr_db: float = -60.0,
                 head_pad_ms: float = 3.0, tail_pad_ms: float = 20.0) -> np.ndarray:
    """Rogne les silences tete/queue sous `thr_db` relatif au peak, avec pad."""
    if x.size == 0:
        return x
    peak = float(np.max(np.abs(x)))
    if peak <= 1e-9:
        return x
    thr = peak * (10 ** (thr_db / 20.0))
    above = np.abs(x) > thr
    idx = np.flatnonzero(above)
    if idx.size == 0:
        return x
    head = max(0, idx[0] - int(head_pad_ms * SR / 1000.0))
    tail = min(x.size, idx[-1] + int(tail_pad_ms * SR / 1000.0) + 1)
    return x[head:tail]


def _soft_limit(x: np.ndarray, ceiling_db: float, oversample: int = 4) -> np.ndarray:
    """Limiteur true-peak doux (tanh) au taux suréchantillonné, puis décimation.

    Transparent tant que |x| << ceiling (tanh ~ lineaire), sature en douceur au
    plafond. Le sur-echantillonnage + le filtre de resample_poly evitent tout
    repliement introduit par la non-linearite.
    """
    ceil_lin = 10 ** (ceiling_db / 20.0)
    up = _oversample(x, oversample)
    shaped = ceil_lin * np.tanh(up / ceil_lin)
    down = signal.resample_poly(shaped, 1, oversample)
    return down.astype(np.float64)


def reduce_crest(x: np.ndarray, cap_db: float, oversample: int = 4) -> np.ndarray:
    """Réduit le facteur de crête (true-peak − LUFS) vers `cap_db`.

    Limiteur doux (tanh) au taux suréchantillonné : rabote les transitoires pour
    homogeneiser la crete au sein d'une categorie (loudness-match sous plafond
    true-peak). Iteratif, converge en ~3 passes, click-free (decimation filtree).
    """
    for _ in range(5):
        lufs = measure_lufs(x)
        crest = true_peak_dbfs(x) - lufs
        if crest <= cap_db + 0.3:
            break
        thr = 10 ** ((lufs + cap_db) / 20.0)   # peak vise ~ LUFS + cap
        up = _oversample(x, oversample)
        shaped = thr * np.tanh(up / thr)
        x = signal.resample_poly(shaped, 1, oversample).astype(np.float64)
    return x


def normalize(x: np.ndarray, target_lufs: float, peak_ceiling_db: float = -14.0,
              trim: bool = True, hp_hz: float = 25.0,
              crest_cap_db: float | None = None,
              fade_edges: bool = True) -> tuple[np.ndarray, dict]:
    """Chaine complete. Retourne (audio float64, stats).

    `crest_cap_db` : si fourni, rabote la crete a cette valeur AVANT le loudness-
    match (homogeneise l'intra-categorie sous le plafond true-peak).
    `fade_edges` : micro-fade anti-click tete/queue. A DESACTIVER pour une boucle
    seamless (musique) — sinon on rouvre une discontinuite au raccord.
    """
    x = np.asarray(x, dtype=np.float64)
    x = highpass(x, hp_hz)
    if trim:
        x = trim_silence(x)
    # micro-fade anti-click (2 ms) apres trim
    fade = int(0.002 * SR)
    if fade_edges and x.size > 2 * fade:
        ramp = np.linspace(0.0, 1.0, fade)
        x[:fade] *= ramp
        x[-fade:] *= ramp[::-1]

    if crest_cap_db is not None:
        x = reduce_crest(x, crest_cap_db)

    lufs = measure_lufs(x)
    x = x * (10 ** ((target_lufs - lufs) / 20.0))

    # Plafond true-peak : limiteur doux + makeup iteratif (converge en ~3 passes)
    for _ in range(4):
        tp = true_peak_dbfs(x)
        if tp <= peak_ceiling_db + 0.1:
            break
        x = _soft_limit(x, peak_ceiling_db)
        l2 = measure_lufs(x)
        makeup = target_lufs - l2
        if makeup > 0.05:
            x = x * (10 ** (makeup / 20.0))
    # garde-fou final : plafond dur (pur gain) si le limiteur n'a pas suffi
    tp = true_peak_dbfs(x)
    if tp > peak_ceiling_db:
        x = x * (10 ** ((peak_ceiling_db - tp) / 20.0))

    stats = {
        "lufs": round(measure_lufs(x), 2),
        "true_peak_db": round(true_peak_dbfs(x), 2),
        "peak_db": round(peak_dbfs(x), 2),
        "dc": round(dc_offset(x), 6),
        "duration_s": round(x.size / SR, 3),
        "samples": int(x.size),
    }
    return x, stats


def write_wav16(x: np.ndarray, path: Path) -> None:
    """Ecrit un WAV mono 16-bit deterministe (round-half-to-even numpy)."""
    clipped = np.clip(x, -1.0, 1.0)
    ints = np.round(clipped * 32767.0).astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(ints.tobytes())


def loudness_backend() -> str:
    return "pyloudnorm" if _HAS_PYLN else "vendored-bs1770"
