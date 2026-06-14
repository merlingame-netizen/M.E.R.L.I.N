# -*- coding: utf-8 -*-
"""SFX forge M.E.R.L.I.N. — synthese procedurale soft (BIBLE §22, R117).

v3 — Soft : peak -14 dB, attaques ralenties, FM adoucie, post-traitement _soft_finish.
Matiere feutree-organique (R30) : SFX subtils, -10 dB sous la musique.
Sortie : audio/sfx/<id>.wav — WAV mono 44.1 kHz 16-bit, peak normalise -14 dB.
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
PEAK_TARGET = 10 ** (-14.0 / 20.0)  # -14 dB (SFX subtils — v3)
OUT_DIR = Path(__file__).resolve().parent.parent / "audio" / "sfx"


# ── Briques de synthese (v1 — preservees) ───────────────────────────────────

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


# ── Briques premium (v2) ────────────────────────────────────────────────────

def _reverb(samples: list[float], decay: float = 0.3, mix: float = 0.3) -> list[float]:
    """Reverb Schroeder — 4 combs paralleles + 2 allpass en serie."""
    n = len(samples)
    comb_delays = [int(SAMPLE_RATE * ms / 1000.0) for ms in [29.7, 37.1, 41.1, 43.7]]
    g_comb = min(0.98, 0.7 + 0.28 * decay)
    wet = [0.0] * n
    for delay in comb_delays:
        y = [0.0] * n
        for i in range(n):
            y[i] = samples[i] + (g_comb * y[i - delay] if i >= delay else 0.0)
        for i in range(n):
            wet[i] += y[i]
    inv = 1.0 / len(comb_delays)
    for i in range(n):
        wet[i] *= inv
    for ap_ms in [5.0, 1.7]:
        ap_d = max(1, int(SAMPLE_RATE * ap_ms / 1000.0))
        ap_g = 0.5
        nw = [0.0] * n
        for i in range(n):
            xd = wet[i - ap_d] if i >= ap_d else 0.0
            yd = nw[i - ap_d] if i >= ap_d else 0.0
            nw[i] = -ap_g * wet[i] + xd + ap_g * yd
        wet = nw
    return [samples[i] * (1.0 - mix) + wet[i] * mix for i in range(n)]


def _adsr(n: int, a: float, d: float, s_level: float, r: float) -> Callable[[int], float]:
    """Enveloppe ADSR. a/d/r en secondes, s_level 0-1."""
    a_s = max(1, int(SAMPLE_RATE * a))
    d_s = int(SAMPLE_RATE * d)
    r_s = max(1, int(SAMPLE_RATE * r))
    r_start = max(n - r_s, a_s + d_s)

    def env(i: int) -> float:
        if i < a_s:
            return i / a_s
        if i < a_s + d_s:
            return 1.0 - (1.0 - s_level) * ((i - a_s) / max(1, d_s))
        if i < r_start:
            return s_level
        return s_level * max(0.0, 1.0 - (i - r_start) / r_s)
    return env


def _fm_tone(duration: float, carrier: float, mod_ratio: float, mod_index: float,
             attack: float, tau: float, bend: float = 0.0) -> list[float]:
    """FM synthesis — timbres plus riches que les sinusoides pures."""
    n = int(SAMPLE_RATE * duration)
    env = _env_decay(n, attack, tau)
    out = [0.0] * n
    c_phase = 0.0
    m_phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        fc = carrier * (1.0 + bend * t)
        fm = fc * mod_ratio
        m_phase += 2.0 * math.pi * fm / SAMPLE_RATE
        c_phase += 2.0 * math.pi * fc / SAMPLE_RATE
        out[i] = math.sin(c_phase + mod_index * math.sin(m_phase)) * env(i)
    return out


def _warmth(samples: list[float], detune: float = 0.003, jitter_seed: int = 42) -> list[float]:
    """Chaleur analogique : chorus micro-desaccorde + saturation douce."""
    rng = random.Random(jitter_seed)
    n = len(samples)
    out = [0.0] * n
    rate = 1.0 + detune
    tanh_norm = math.tanh(1.2)
    for i in range(n):
        pos = i * rate
        idx = int(pos)
        frac = pos - idx
        if idx + 1 < n:
            det = samples[idx] * (1.0 - frac) + samples[idx + 1] * frac
        elif idx < n:
            det = samples[idx]
        else:
            det = 0.0
        mixed = 0.6 * samples[i] + 0.4 * det + rng.gauss(0, 0.002)
        out[i] = math.tanh(mixed * 1.2) / tanh_norm
    return out


def _resonant_filter(samples: list[float], cutoff: float, resonance: float = 0.5,
                     sweep_to: float = -1.0, sweep_dur: float = -1.0) -> list[float]:
    """Filtre SVF two-pole (lowpass). cutoff en Hz, resonance 0-1."""
    n = len(samples)
    out = [0.0] * n
    lp = bp = 0.0
    for i in range(n):
        if sweep_to > 0 and sweep_dur > 0:
            blend = min((i / SAMPLE_RATE) / sweep_dur, 1.0)
            f = cutoff + (sweep_to - cutoff) * blend
        else:
            f = cutoff
        fc = 2.0 * math.sin(math.pi * min(f / SAMPLE_RATE, 0.499))
        q = 1.0 - resonance * 0.95
        hp = samples[i] - lp - q * bp
        bp += fc * hp
        lp += fc * bp
        out[i] = lp
    return out


# ── Post-traitement global (v3 — soft finish) ──────────────────────────────

def _scale(samples: list[float], gain: float) -> list[float]:
    """Gain simple sur un buffer."""
    return [s * gain for s in samples]


def _soft_finish(samples: list[float], fade_ms: float = 12.0,
                 shelf_hz: float = 5500.0) -> list[float]:
    """Finition douce : fade-in/out anti-click + lowpass haute-frequence."""
    n = len(samples)
    fi = int(SAMPLE_RATE * 3.0 / 1000.0)
    for i in range(min(fi, n)):
        samples[i] *= i / fi
    fo = max(1, int(SAMPLE_RATE * fade_ms / 1000.0))
    for i in range(max(0, n - fo), n):
        samples[i] *= (n - i) / fo
    alpha = 2.0 * math.pi * shelf_hz / SAMPLE_RATE
    a = alpha / (1.0 + alpha)
    prev = 0.0
    for i in range(n):
        prev += a * (samples[i] - prev)
        samples[i] = prev
    return samples


# ── Recettes canon v3 — soft (ids = BIBLE §22, ne pas renommer) ────────────

RECIPES: dict[str, Callable[[], list[float]]] = {
    # papier glisse doux + salle chaleureuse
    "card_pick": lambda: _warmth(_reverb(
        _noise(0.16, seed=101, attack=0.015, tau=0.06, lowpass=0.18),
        decay=0.12, mix=0.40)),

    # papier pose + ton FM feutre + filtre descendant
    "card_play": lambda: _reverb(_mix(
        _resonant_filter(
            _noise(0.24, seed=102, attack=0.012, tau=0.08, lowpass=0.18),
            cutoff=2200.0, resonance=0.2, sweep_to=500.0, sweep_dur=0.18),
        _fm_tone(0.20, 140.0, 2.0, 0.35, attack=0.012, tau=0.06)),
        decay=0.15, mix=0.40),

    # froisse doux + warmth organique
    "card_discard": lambda: _reverb(_warmth(
        _noise(0.32, seed=103, attack=0.025, tau=0.12, lowpass=0.22)),
        decay=0.15, mix=0.35),

    # eventail de papier + chorus subtil
    "deal": lambda: _warmth(_reverb(_concat(
        _noise(0.10, seed=104, attack=0.012, tau=0.04, lowpass=0.16),
        _noise(0.10, seed=105, attack=0.012, tau=0.04, lowpass=0.18),
        _noise(0.13, seed=106, attack=0.012, tau=0.05, lowpass=0.15)),
        decay=0.08, mix=0.30)),

    # bois FM doux + micro-reverb
    "button_tap": lambda: _reverb(_warmth(
        _fm_tone(0.12, 220.0, 3.0, 0.6, attack=0.010, tau=0.030)),
        decay=0.08, mix=0.30),

    # goutte FM montante douce + salle
    "gauge_up": lambda: _reverb(_warmth(
        _fm_tone(0.30, 600.0, 2.0, 0.5, attack=0.015, tau=0.10, bend=0.4)),
        decay=0.18, mix=0.45),

    # corde FM descendante + filtre doux
    "gauge_down": lambda: _reverb(
        _resonant_filter(
            _fm_tone(0.42, 196.0, 1.5, 0.45, attack=0.018, tau=0.15, bend=-0.18),
            cutoff=1400.0, resonance=0.3, sweep_to=250.0, sweep_dur=0.35),
        decay=0.22, mix=0.45),

    # murmure resonant + FM basse attenuee
    "corruption_tick": lambda: _reverb(_warmth(_mix(
        _resonant_filter(
            _noise(0.38, seed=107, attack=0.04, tau=0.14, lowpass=0.10),
            cutoff=700.0, resonance=0.5, sweep_to=300.0, sweep_dur=0.28),
        _fm_tone(0.38, 92.0, 1.5, 0.9, attack=0.04, tau=0.14)),
        detune=0.006), decay=0.20, mix=0.40),

    # sceau FM impact doux + salle
    "seal_stamp": lambda: _reverb(_warmth(_mix(
        _fm_tone(0.24, 110.0, 2.0, 1.0, attack=0.012, tau=0.06),
        _noise(0.12, seed=108, attack=0.010, tau=0.04, lowpass=0.22))),
        decay=0.28, mix=0.45),

    # page + filtre descendant doux
    "beat_turn": lambda: _reverb(
        _resonant_filter(
            _noise(0.48, seed=109, attack=0.06, tau=0.18, lowpass=0.20),
            cutoff=1800.0, resonance=0.2, sweep_to=450.0, sweep_dur=0.38),
        decay=0.18, mix=0.40),

    # carillon FM doux tierce + salle ouverte
    "draft_reveal": lambda: _reverb(_warmth(_concat(
        _fm_tone(0.32, 523.25, 2.0, 0.25, attack=0.018, tau=0.14),
        _fm_tone(0.42, 659.25, 2.0, 0.25, attack=0.018, tau=0.18))),
        decay=0.35, mix=0.50),

    # souffle resonant + accord desaccorde (deja doux)
    "whisper_threshold": lambda: _reverb(_mix(
        _resonant_filter(
            _noise(0.85, seed=110, attack=0.12, tau=0.32, lowpass=0.08),
            cutoff=600.0, resonance=0.5, sweep_to=150.0, sweep_dur=0.65),
        _warmth(_chord(0.85, (233.08, 246.94), attack=0.12, tau=0.32), detune=0.005)),
        decay=0.45, mix=0.50),

    # stinger echec — FM sombre descendant doux
    "stinger_echec": lambda: _reverb(_warmth(
        _fm_tone(1.8, 174.61, 1.19, 0.7, attack=0.030, tau=0.60, bend=-0.08)),
        decay=0.55, mix=0.55),

    # stinger partiel — accord trois notes doux
    "stinger_partiel": lambda: _reverb(_warmth(
        _chord(1.5, (220.0, 277.18, 329.63), attack=0.030, tau=0.55)),
        decay=0.50, mix=0.50),

    # stinger reussite — accord ouvert doux
    "stinger_reussite": lambda: _reverb(_warmth(
        _chord(1.9, (196.0, 246.94, 293.66, 392.0), attack=0.025, tau=0.65)),
        decay=0.60, mix=0.55),

    # stinger eclatante — accord + FM aigu doux
    "stinger_eclatante": lambda: _reverb(_warmth(_mix(
        _chord(2.3, (261.63, 329.63, 392.0, 523.25), attack=0.025, tau=0.80),
        _fm_tone(2.3, 1046.5, 3.0, 0.20, attack=0.18, tau=0.75))),
        decay=0.75, mix=0.55),

    # plume grattant le parchemin — texture fibreuse, zero tonal
    "quill_tick": lambda: _reverb(_warmth(_mix(
        _resonant_filter(
            _noise(0.09, seed=121, attack=0.002, tau=0.022, lowpass=0.40),
            cutoff=3200.0, resonance=0.40, sweep_to=1500.0, sweep_dur=0.07),
        _scale(_resonant_filter(
            _noise(0.06, seed=122, attack=0.001, tau=0.015, lowpass=0.55),
            cutoff=5000.0, resonance=0.20), 0.25),
        _scale(_noise(0.07, seed=123, attack=0.005, tau=0.020, lowpass=0.10), 0.15)),
        detune=0.002, jitter_seed=121),
        decay=0.04, mix=0.18),

    # encre s'etalant sur parchemin — absorption douce, texture fibreuse
    "ink_wash": lambda: _reverb(_warmth(_mix(
        _resonant_filter(
            _noise(0.55, seed=130, attack=0.040, tau=0.22, lowpass=0.14),
            cutoff=1800.0, resonance=0.35, sweep_to=400.0, sweep_dur=0.45),
        _scale(_resonant_filter(
            _noise(0.40, seed=131, attack=0.020, tau=0.18, lowpass=0.45),
            cutoff=4000.0, resonance=0.25, sweep_to=2000.0, sweep_dur=0.30), 0.20),
        _scale(_noise(0.35, seed=132, attack=0.030, tau=0.15, lowpass=0.06), 0.12)),
        detune=0.004, jitter_seed=130),
        decay=0.30, mix=0.50),
}


# ── Ecriture WAV ─────────────────────────────────────────────────────────────

def _write_wav(samples: list[float], path: Path) -> float:
    """Normalise au peak -14 dB et ecrit un WAV mono 16-bit. Retourne le peak dBFS MESURE."""
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
    samples = _soft_finish(RECIPES[sfx_id]())
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
