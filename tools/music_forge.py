# -*- coding: utf-8 -*-
"""Gameplay music forge — ambient celtic loops proceduraux (BIBLE §22, R117).

Genere des pistes ambiantes pour le gameplay :
- gameplay_calm.wav : exploration, pentatonique celtique, drone + harpe
Sortie : music/gameplay/<id>.wav — WAV mono 44.1 kHz 16-bit, boucle seamless.
Seed FIXE → generation 100% rejouable.

Usage:
    python tools/music_forge.py --list
    python tools/music_forge.py --id gameplay_calm
    python tools/music_forge.py --all
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
PEAK_TARGET = 10 ** (-12.0 / 20.0)  # -12 dB
DURATION = 35.0
BOOT_DURATION = 22.0  # cue d'éveil (boot) — court, en boucle seamless
CROSSFADE = 3.0
OUT_DIR = Path(__file__).resolve().parent.parent / "music" / "gameplay"
# Certaines pistes sortent ailleurs que music/gameplay (ex. l'éveil du boot).
OUT_OVERRIDE: dict[str, Path] = {
    "boot_eveil": Path(__file__).resolve().parent.parent / "music" / "intro",
}

PENTA_D = (146.83, 174.61, 196.00, 220.00, 261.63)
PENTA_D_HIGH = (293.66, 349.23, 392.00, 440.00, 523.25)
PENTA_D_LOW = (73.42, 87.31, 98.00, 110.00, 146.83)  # pentatonique grave (éveil sombre-merveilleux)


def _drone(duration: float, freq: float, detune: float = 0.003,
           mod_depth: float = 0.15, mod_rate: float = 0.07,
           mod_index: float = 0.3) -> list[float]:
    n = int(SAMPLE_RATE * duration)
    out = [0.0] * n
    c_phase = 0.0
    m_phase = 0.0
    c2_phase = 0.0
    freq2 = freq * (1.0 + detune)
    fade_in = int(SAMPLE_RATE * 3.0)
    fade_out = int(SAMPLE_RATE * 2.0)
    for i in range(n):
        t = i / SAMPLE_RATE
        amp = 1.0 - mod_depth * math.sin(2.0 * math.pi * mod_rate * t)
        if i < fade_in:
            amp *= i / fade_in
        if i > n - fade_out:
            amp *= (n - i) / fade_out
        fm = freq * 1.5
        m_phase += 2.0 * math.pi * fm / SAMPLE_RATE
        c_phase += 2.0 * math.pi * freq / SAMPLE_RATE
        c2_phase += 2.0 * math.pi * freq2 / SAMPLE_RATE
        s1 = math.sin(c_phase + mod_index * math.sin(m_phase))
        s2 = math.sin(c2_phase) * 0.5
        out[i] = (s1 + s2) * amp * 0.4
    return out


def _bell(duration: float, freq: float, attack: float = 0.08,
          decay: float = 3.0, mod_index: float = 0.4) -> list[float]:
    n = int(SAMPLE_RATE * duration)
    out = [0.0] * n
    a_s = max(1, int(SAMPLE_RATE * attack))
    c_phase = 0.0
    m_phase = 0.0
    for i in range(n):
        if i < a_s:
            env = i / a_s
        else:
            env = math.exp(-(i - a_s) / (SAMPLE_RATE * decay))
        m_phase += 2.0 * math.pi * freq * 2.5 / SAMPLE_RATE
        c_phase += 2.0 * math.pi * freq / SAMPLE_RATE
        out[i] = math.sin(c_phase + mod_index * math.sin(m_phase)) * env
    return out


def _wind(duration: float, seed: int, intensity: float = 0.25,
          sweep_period: float = 10.0) -> list[float]:
    rng = random.Random(seed)
    n = int(SAMPLE_RATE * duration)
    out = [0.0] * n
    prev = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        cutoff = 0.04 + 0.06 * (0.5 + 0.5 * math.sin(2.0 * math.pi * t / sweep_period))
        raw = rng.uniform(-1.0, 1.0)
        prev = prev + cutoff * (raw - prev)
        amp = intensity * (0.7 + 0.3 * math.sin(2.0 * math.pi * t / (sweep_period * 0.7)))
        out[i] = prev * amp
    return out


def _sequence_bells(duration: float, notes: tuple[float, ...], seed: int,
                    density: float = 0.35, decay: float = 4.0,
                    vol_range: tuple[float, float] = (0.3, 0.7)) -> list[float]:
    rng = random.Random(seed)
    n = int(SAMPLE_RATE * duration)
    out = [0.0] * n
    t = 1.5 + rng.uniform(0, 2.0)
    while t < duration - 5.0:
        freq = notes[rng.randint(0, len(notes) - 1)]
        vol = rng.uniform(vol_range[0], vol_range[1])
        bell_dur = min(decay + 1.0, duration - t)
        bell = _bell(bell_dur, freq, attack=0.06, decay=decay, mod_index=0.3)
        start = int(t * SAMPLE_RATE)
        for j, s in enumerate(bell):
            if start + j < n:
                out[start + j] += s * vol
        gap = 1.5 + rng.expovariate(density)
        t += gap
    return out


def _pad_reverb(samples: list[float], size: float = 0.6, mix: float = 0.45) -> list[float]:
    n = len(samples)
    comb_delays = [int(SAMPLE_RATE * ms / 1000.0) for ms in [37.1, 43.7, 53.0, 61.7]]
    g = min(0.98, 0.75 + 0.22 * size)
    wet = [0.0] * n
    for delay in comb_delays:
        y = [0.0] * n
        for i in range(n):
            y[i] = samples[i] + (g * y[i - delay] if i >= delay else 0.0)
        for i in range(n):
            wet[i] += y[i]
    inv = 1.0 / len(comb_delays)
    for i in range(n):
        wet[i] *= inv
    for ap_ms in [7.0, 2.3]:
        ap_d = max(1, int(SAMPLE_RATE * ap_ms / 1000.0))
        ap_g = 0.5
        nw = [0.0] * n
        for i in range(n):
            xd = wet[i - ap_d] if i >= ap_d else 0.0
            yd = nw[i - ap_d] if i >= ap_d else 0.0
            nw[i] = -ap_g * wet[i] + xd + ap_g * yd
        wet = nw
    return [samples[i] * (1.0 - mix) + wet[i] * mix for i in range(n)]


def _mix(*layers: list[float]) -> list[float]:
    n = max(len(layer) for layer in layers)
    out = [0.0] * n
    for layer in layers:
        for i, v in enumerate(layer):
            out[i] += v
    return out


def _make_seamless(samples: list[float], fade_s: float) -> list[float]:
    n = len(samples)
    n_fade = int(SAMPLE_RATE * fade_s)
    if n_fade * 2 >= n:
        return samples
    for i in range(n_fade):
        blend = i / n_fade
        g_head = math.sqrt(1.0 - blend)
        g_tail = math.sqrt(blend)
        samples[i] = samples[i] * g_tail + samples[n - n_fade + i] * g_head
    return samples[:n - n_fade]


def _lowpass_gentle(samples: list[float], hz: float = 4500.0) -> list[float]:
    alpha = 2.0 * math.pi * hz / SAMPLE_RATE
    a = alpha / (1.0 + alpha)
    prev = 0.0
    for i in range(len(samples)):
        prev += a * (samples[i] - prev)
        samples[i] = prev
    return samples


# ── Recettes ────────────────────────────────────────────────────────────────

def _gameplay_calm() -> list[float]:
    drone_lo = _drone(DURATION, 73.42, mod_depth=0.12, mod_rate=0.06, mod_index=0.2)
    drone_hi = _drone(DURATION, 110.00, detune=0.004, mod_depth=0.10, mod_rate=0.05, mod_index=0.15)
    bells = _sequence_bells(DURATION, PENTA_D, seed=301, density=0.30, decay=4.5, vol_range=(0.25, 0.55))
    shimmer = _sequence_bells(DURATION, PENTA_D_HIGH, seed=302, density=0.12, decay=3.0, vol_range=(0.10, 0.25))
    atmosphere = _wind(DURATION, seed=303, intensity=0.18, sweep_period=12.0)
    raw = _mix(drone_lo, drone_hi, bells, shimmer, atmosphere)
    wet = _pad_reverb(raw, size=0.65, mix=0.50)
    soft = _lowpass_gentle(wet, 4200.0)
    return _make_seamless(soft, CROSSFADE)


def _gameplay_falaises() -> list[float]:
    # P3 (chantier 5, CDC-NAR-02 « mélancolie du bout du monde ») — VARIANTE FALAISES de la nappe de
    # jeu. Même palette que gameplay_calm (drone + cloches pentatoniques + vent) → cohérence de biome ;
    # infléchie maritime : drone plus grave et plus désaccordé (solitude), cloches PLUS RARES (distance),
    # vent PLUS PRÉSENT (embruns/ressac), lowpass plus sombre (brume de sel), réverb plus ample (à-pic).
    # DOUCE et sans superposition brutale : play_music la cross-fade depuis le silence à l'entrée de scène.
    drone_lo = _drone(DURATION, 65.41, mod_depth=0.13, mod_rate=0.055, mod_index=0.22)   # C2, plus grave que le D2 forêt
    drone_hi = _drone(DURATION, 98.00, detune=0.007, mod_depth=0.10, mod_rate=0.048, mod_index=0.16)  # G2 désaccordé
    bells = _sequence_bells(DURATION, PENTA_D, seed=311, density=0.20, decay=5.2, vol_range=(0.20, 0.45))
    shimmer = _sequence_bells(DURATION, PENTA_D_HIGH, seed=312, density=0.08, decay=3.4, vol_range=(0.08, 0.20))
    atmosphere = _wind(DURATION, seed=313, intensity=0.30, sweep_period=9.0)  # embruns/vent du large plus soutenus
    raw = _mix(drone_lo, drone_hi, bells, shimmer, atmosphere)
    wet = _pad_reverb(raw, size=0.74, mix=0.52)
    soft = _lowpass_gentle(wet, 3800.0)  # plus sombre/feutré que la forêt (4200)
    return _make_seamless(soft, CROSSFADE)


def _boot_eveil() -> list[float]:
    # Éveil du boot : drone GRAVE qui sourd + cloches éparses basses + souffle, réverb cathédrale.
    # Sombre-merveilleux, court (boucle seamless). Enchaîne sur le thème menu (pistes différentes).
    drone_lo = _drone(BOOT_DURATION, 55.00, mod_depth=0.18, mod_rate=0.045, mod_index=0.25)  # A1
    drone_mid = _drone(BOOT_DURATION, 82.41, detune=0.005, mod_depth=0.12, mod_rate=0.06, mod_index=0.18)  # E2
    bells = _sequence_bells(BOOT_DURATION, PENTA_D_LOW, seed=701, density=0.18, decay=5.5, vol_range=(0.18, 0.45))
    shimmer = _sequence_bells(BOOT_DURATION, PENTA_D, seed=702, density=0.08, decay=4.0, vol_range=(0.08, 0.20))
    atmosphere = _wind(BOOT_DURATION, seed=703, intensity=0.22, sweep_period=14.0)
    raw = _mix(drone_lo, drone_mid, bells, shimmer, atmosphere)
    wet = _pad_reverb(raw, size=0.72, mix=0.55)  # réverb ample (caverne d'éveil)
    soft = _lowpass_gentle(wet, 3600.0)  # plus sombre que le gameplay
    return _make_seamless(soft, CROSSFADE)


# ── v10.21 Wave A — nappes SIGNÉES par pilier PNJ (BIBLE §22 + spec panel) ──────
# Boucles seamless courtes (16 s), discrètes (jouées bas volume via MerlinAudio.play_pad, canal unique).
PAD_DURATION = 16.0


def _pad_pilier(freq_lo: float, freq_hi: float, detune: float, bell_notes: tuple[float, ...],
                bell_seed: int, bell_density: float, wind_i: float, lp: float, rev_size: float) -> list[float]:
    drone_lo = _drone(PAD_DURATION, freq_lo, mod_depth=0.10, mod_rate=0.05, mod_index=0.15)
    drone_hi = _drone(PAD_DURATION, freq_hi, detune=detune, mod_depth=0.08, mod_rate=0.06, mod_index=0.12)
    bells = _sequence_bells(PAD_DURATION, bell_notes, seed=bell_seed, density=bell_density,
                            decay=4.0, vol_range=(0.10, 0.30))
    atmosphere = _wind(PAD_DURATION, seed=bell_seed + 1, intensity=wind_i, sweep_period=10.0)
    raw = _mix(drone_lo, drone_hi, bells, atmosphere)
    wet = _pad_reverb(raw, size=rev_size, mix=0.50)
    return _make_seamless(_lowpass_gentle(wet, lp), CROSSFADE)


def _pad_choeur() -> list[float]:      # chaud, druidique — A2+E3, cloches douces
    return _pad_pilier(110.00, 164.81, 0.003, PENTA_D, 801, 0.16, 0.14, 3800.0, 0.62)


def _pad_etre() -> list[float]:        # froid d'outre-monde — F#2+C#3 fortement désaccordé, réverb ample
    return _pad_pilier(92.50, 138.59, 0.009, PENTA_D_HIGH, 811, 0.10, 0.20, 3200.0, 0.75)


def _pad_chevalier() -> list[float]:   # solennel, grave — D2, cloches basses rares
    return _pad_pilier(73.42, 110.00, 0.002, PENTA_D_LOW, 821, 0.12, 0.10, 3000.0, 0.58)


def _pad_compagnon() -> list[float]:   # mélancolique — G2, battement lent
    return _pad_pilier(98.00, 146.83, 0.006, PENTA_D, 831, 0.14, 0.16, 3400.0, 0.68)


def _pad_enfant() -> list[float]:      # boîte à musique inquiète — G3 clair, clochettes denses
    return _pad_pilier(196.00, 293.66, 0.004, PENTA_D_HIGH, 841, 0.22, 0.10, 4200.0, 0.55)


TRACKS: dict[str, Callable[[], list[float]]] = {
    "gameplay_calm": _gameplay_calm,
    "gameplay_falaises": _gameplay_falaises,  # P3 (chantier 5) : variante musicale du biome falaises
    "boot_eveil": _boot_eveil,
    "pad_choeur": _pad_choeur,
    "pad_etre": _pad_etre,
    "pad_chevalier": _pad_chevalier,
    "pad_compagnon": _pad_compagnon,
    "pad_enfant": _pad_enfant,
}


# ── Ecriture WAV ─────────────────────────────────────────────────────────────

def _write_wav(samples: list[float], path: Path) -> float:
    peak = max((abs(s) for s in samples), default=0.0)
    if peak <= 0.0:
        raise ValueError(f"piste vide pour {path.name}")
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
    return 20.0 * math.log10(measured) if measured > 0 else -99.0


def forge(track_id: str) -> Path:
    if track_id not in TRACKS:
        raise KeyError(f"piste inconnue '{track_id}' — voir --list")
    print(f"Generating {track_id}... (this may take ~30s)")
    samples = TRACKS[track_id]()
    out = OUT_OVERRIDE.get(track_id, OUT_DIR) / f"{track_id}.wav"
    peak_db = _write_wav(samples, out)
    dur = len(samples) / SAMPLE_RATE
    print(f"OK {out.name}  {dur:.1f}s  peak {peak_db:.1f} dBFS")
    return out


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="Music forge M.E.R.L.I.N. (BIBLE §22)")
    parser.add_argument("--list", action="store_true", help="lister les pistes")
    parser.add_argument("--id", help="generer une piste")
    parser.add_argument("--all", action="store_true", help="generer toutes les pistes")
    args = parser.parse_args()

    if args.list:
        for name in TRACKS:
            print(name)
        print(f"\n{len(TRACKS)} piste(s)")
        return 0
    if args.id:
        forge(args.id)
        return 0
    if args.all:
        for name in TRACKS:
            forge(name)
        print(f"\n{len(TRACKS)} WAV genere(s) dans {OUT_DIR}")
        return 0
    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
