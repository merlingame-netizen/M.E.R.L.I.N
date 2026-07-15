# -*- coding: utf-8 -*-
"""Melody forge M.E.R.L.I.N. — compositeur celtique MELODIQUE (BIBLE §22).

Pas un synthe : une COUCHE DE COMPOSITION symbolique (modes celtiques, contour
melodique contraint, cadences, structure AABB) qui PILOTE les synthes physiques
existants (`tools/sfx_forge.py` : Karplus-Strong harpe, membrane bodhran) + une
voix tin-whistle additive band-limitee ecrite ici. 100% pur-numpy, headless,
GPO-safe, seed FIXE -> generation rejouable.

Diagnostic : les timbres de sfx_forge sonnent bien ; ce qui manquait aux nappes
de gameplay (music_forge = drone + cloches aleatoires), c'est une LIGNE MELODIQUE
vraiment ecrite. C'est ce que ce module ajoute.

Qualite melodique GARANTIE PAR CONSTRUCTION :
  - mode-snap : on ne choisit QUE des notes du mode (couleur celtique certaine)
  - contour ~70% conjoint (marche +/-1 degre), sauts occasionnels vers quinte/octave
  - ambitus borne (tin-whistle D4-A5)
  - attraction cadentielle CROISSANTE vers tonique/quinte en fin de phrase
  - structure AABB (A ouverte sur 2e/5e degre, B fermee sur tonique)
  - `--seed` fige une bonne graine ; `--motif` amorce la grammaire de variation

Rendu (2 backends, `--render`) :
  - `sf2` (DEFAUT) : chaque evenement-note est joue par un VRAI echantillon d'instrument
    via un SoundFont General MIDI (GeneralUser GS, tinysoundfont). Voix -> programme GM :
    melodie -> Flute (73, `--whistle-prog` pour Recorder/PanFlute/Whistle), arpeges ->
    Orchestral Harp (46), bourdon -> Slow Strings (49), bodhran -> toms graves du kit GM
    (41/47 — GM n'a pas de vrai bodhran). Boucle SEAMLESS : on rend 3 boucles et on
    extrait celle du MILIEU (regime permanent) ; reverb CIRCULAIRE periodique.
  - `physical` (FALLBACK GPO-safe) : synthes purs (Karplus harpe + tin-whistle additif +
    drone/vent synthetises), aucune dependance. Utilise si le SF2/tinysoundfont manque.
Normalisation loudness -24 LUFS / true-peak -12 dBFS via sfx_normalize (identique).

Usage :
    python tools/melody_forge.py --list
    python tools/melody_forge.py --variants          # 2 defauts + variantes A/B
    python tools/melody_forge.py --biome foret --out output/gen_music/test.wav
    python tools/melody_forge.py --mode mixolydien --bpm 96 --beats on --pattern jig
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import dataclass, replace
from pathlib import Path

import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from tools import sfx_forge as sfx       # noqa: E402  (ks_pluck harpe, membrane bodhran)
from tools import sfx_normalize as norm  # noqa: E402

SR = norm.SR

# ── Cibles de mastering (identiques a music_forge / musique de jeu actuelle) ────
MUSIC_TARGET_LUFS = -24.0
MUSIC_PEAK_CEILING = -12.0

GEN_DIR = ROOT / "output" / "gen_music"
GAMEPLAY_DIR = ROOT / "music" / "gameplay"

# ── Backend de rendu SF2 (vrais echantillons d'instruments) ─────────────────────
# GeneralUser GS v2.0.3 (License v2.0, S. Christian Collins) : banque GM 100%
# echantillons reels (harpe/flute/cordes/percussion), usage libre commercial. Le
# SF2 est GITIGNORE (~32 Mo) ; le re-telecharger via `python tools/fetch_soundfont.py`.
SOUNDFONT = ROOT / "resources" / "soundfonts" / "GeneralUser-GS.sf2"

# Programmes General MIDI (bank 0) — vrais instruments.
GM_HARP = 46          # Orchestral Harp (melodie pincee + arpeges)
GM_STRINGS = 49       # Slow Strings (lit/bourdon soutenu — remplace le drone synthe)
GM_FLUTE = 73         # Flute (defaut voix "tin-whistle" : timbre de flute reel, chaud)
GM_RECORDER = 74      # Recorder (fipple flute, plus proche du tin-whistle baroque)
GM_PANFLUTE = 75      # Pan Flute (souffle andin)
GM_WHISTLE = 78       # Whistle GM (sifflet — timbre plus mince)
GM_PIZZ = 45          # Pizzicato Strings (alternative cordes)
# GM n'a PAS de vrai bodhran : on approxime le tambour a cadre par les toms graves
# du kit de batterie GM (canal percussion). Grave = Low Floor Tom, aigu = Low-Mid Tom.
GM_DRUM_LOW = 41      # Low Floor Tom (frappe grave/centre)
GM_DRUM_HIGH = 47     # Low-Mid Tom (frappe plus claire/bord)

# Canaux MIDI dedies (9 = canal 10 GM = percussion).
_CH_MEL, _CH_HARP, _CH_STR, _CH_DRUM = 0, 1, 2, 9

# tinysoundfont : import paresseux (fallback physical si absent/GPO).
try:
    import tinysoundfont as _tsf  # type: ignore
    _HAS_TSF = True
except Exception:  # pragma: no cover
    _tsf = None
    _HAS_TSF = False

# ── Modes celtiques (masques demi-tons depuis la tonique) ───────────────────────
MODES: dict[str, list[int]] = {
    "dorien":     [0, 2, 3, 5, 7, 9, 10],
    "mixolydien": [0, 2, 4, 5, 7, 9, 10],
    "eolien":     [0, 2, 3, 5, 7, 8, 10],
    "penta":      [0, 2, 4, 7, 9],
}

# Classe de hauteur (pitch class) par tonalite.
NOTE_PC = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5,
           "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}

# Ambitus tin-whistle : D4 (MIDI 62) .. A5 (MIDI 81).
WHISTLE_LO, WHISTLE_HI = 62, 81

# Motifs rythmiques (durees en croches, somme = pulsations/mesure) par famille.
RHYTHM_BANK: dict[str, list[list[int]]] = {
    "jig": [[1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 2], [1, 1, 2, 2], [2, 2, 2],
            [3, 3], [1, 2, 1, 2], [2, 1, 2, 1], [1, 1, 1, 3]],
    "reel": [[1, 1, 1, 1, 1, 1, 1, 1], [2, 1, 1, 2, 1, 1], [2, 2, 2, 2],
             [1, 1, 2, 1, 1, 2], [1, 1, 1, 1, 2, 2], [2, 1, 1, 1, 1, 2], [4, 2, 2]],
    # air : longues notes mais PAS de mesure d'une seule note (trop statique) ; on
    # garde 2-4 notes/mesure pour qu'une vraie ligne melodique respire (lent, rubato).
    "air": [[4, 4], [4, 2, 2], [2, 4, 2], [3, 3, 2], [2, 2, 2, 2], [4, 3, 1], [6, 2]],
}
# Poids (favorise le flux de croches en jig/reel, un chant lent mais mobile en air).
RHYTHM_W = {
    "jig": [0.26, 0.16, 0.14, 0.10, 0.08, 0.10, 0.08, 0.08],
    "reel": [0.22, 0.18, 0.12, 0.16, 0.12, 0.12, 0.08],
    "air": [0.20, 0.22, 0.16, 0.16, 0.14, 0.08, 0.04],
}
BAR_PULSES = {"jig": 6, "reel": 8, "air": 8}
BARS_PER_PHRASE = 2  # AABB => 8 mesures / cycle

# Bodhran : (position croche -> (force, aigu?)) par pattern. Force 0 = silence.
# jig « DUD udU » : temps forts 0 et 3 (croche), remplissage doux entre.
BODHRAN = {
    "jig": [(1.0, False), (0.45, True), (0.6, False), (0.85, False), (0.4, True), (0.6, True)],
    "reel": [(1.0, False), (0.0, True), (0.0, False), (0.45, True), (0.85, False), (0.0, True), (0.0, False), (0.45, True)],
    "air": [(0.9, False), (0.0, True), (0.0, False), (0.0, True), (0.35, False), (0.0, True), (0.0, False), (0.0, True)],
}


# ═══════════════════════════════════════════════════════════════════════════
#  Config
# ═══════════════════════════════════════════════════════════════════════════

@dataclass(frozen=True)
class Cfg:
    bpm: int = 84
    mode: str = "dorien"
    key: str = "D"
    mood: str = "sain"           # sain | trouble
    timbre: str = "both"         # harp | whistle | both
    beats: bool = True
    pattern: str = "jig"         # jig | reel | air
    density: float = 0.35        # 0..1 densite bodhran (defaut bas = pulsation discrete)
    bars: int = 0                # 0 => derive de la duree cible
    target_s: float = 44.0
    motif: str = ""              # ex "1 2 3 5" (degres du mode)
    seed: int = 41
    wind: bool = False
    biome: str = ""
    render: str = "sf2"          # sf2 (vrais echantillons, defaut) | physical (fallback synthe)
    melody_prog: int = GM_FLUTE  # programme GM de la voix melodique (whistle/flute)


def midi_to_freq(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


def _tonic_midi(key: str) -> int:
    pc = NOTE_PC.get(key.upper(), 2)
    m = 60 + pc                         # C4..B4
    if m < 62:                           # garde la tonique dans un octave chantant
        m += 12
    return m


def build_scale(mode: str, key: str) -> tuple[list[int], int]:
    """Notes MIDI du mode dans l'ambitus whistle + index de la tonique de base."""
    mask = MODES[mode]
    tonic = _tonic_midi(key)
    tonic_pc = tonic % 12
    lo = max(WHISTLE_LO, tonic)
    hi = min(WHISTLE_HI, tonic + 19)
    notes = [m for m in range(lo, hi + 1) if ((m - tonic_pc) % 12) in mask]
    if not notes:
        notes = [tonic]
    # index de la tonique de reference (la plus grave) dans le tableau
    t0 = next((i for i, m in enumerate(notes) if m % 12 == tonic_pc), 0)
    return notes, t0


# ═══════════════════════════════════════════════════════════════════════════
#  Couche de composition symbolique
# ═══════════════════════════════════════════════════════════════════════════

def _bar_rhythm(rng: np.random.Generator, pattern: str) -> list[int]:
    bank = RHYTHM_BANK[pattern]
    w = np.asarray(RHYTHM_W[pattern], dtype=float)
    w /= w.sum()
    return list(bank[int(rng.choice(len(bank), p=w))])


def _phrase_rhythm(rng: np.random.Generator, pattern: str) -> list[int]:
    r: list[int] = []
    for _ in range(BARS_PER_PHRASE):
        r += _bar_rhythm(rng, pattern)
    return r


def _clamp(i: int, lo: int, hi: int) -> int:
    return lo if i < lo else hi if i > hi else i


def _walk(rng: np.random.Generator, rhythm: list[int], scale_len: int,
          start_idx: int, cad_targets: list[int], motif_idx: list[int] | None) -> tuple[list[int], int]:
    """Contour melodique contraint -> liste d'index de gamme (1 par evenement).

    ~70% mouvement conjoint (+/-1), sauts occasionnels vers tierce/quinte/octave,
    arche (biais vers le centre de l'ambitus), attraction cadentielle CROISSANTE
    vers `cad_targets` (tonique/quinte) et atterrissage GARANTI sur la derniere note.
    `motif_idx` (si fourni) impose les premieres notes (grammaire de variation).
    """
    n = len(rhythm)
    idx = start_idx
    out: list[int] = []
    lo_zone, hi_zone = scale_len * 0.30, scale_len * 0.70
    prev_dir = 0
    run = 0                                         # nb de pas consecutifs meme sens
    for k in range(n):
        remaining = n - 1 - k
        if motif_idx is not None and k < len(motif_idx):
            idx = _clamp(motif_idx[k], 0, scale_len - 1)
        elif remaining == 0:                       # cadence : atterrissage exact garanti
            idx = min(cad_targets, key=lambda t: abs(t - idx))
        else:
            r = rng.random()
            if r < 0.70:
                step = int(rng.choice([-1, 1]))            # conjoint (~70%)
            elif r < 0.87:
                step = int(rng.choice([-2, 2]))            # tierce
            else:
                step = int(rng.choice([-4, 4, 4, 7]))      # quinte / octave
            # arche : rappel vers le centre de l'ambitus (evite les gammes montantes)
            if idx > hi_zone:
                step = -abs(step)
            elif idx < lo_zone:
                step = abs(step)
            # anti-monotonie : apres 2 pas de suite dans le meme sens, favorise le retour
            if np.sign(step) == prev_dir and run >= 2 and rng.random() < 0.6:
                step = -step
            # attraction cadentielle CROISSANTE : sur la derniere note libre, tire vers
            # la cible ; sinon proba douce et grandissante en fin de phrase.
            if remaining == 1 or (remaining <= 3 and rng.random() < (1.0 - remaining / 4.0)):
                target = min(cad_targets, key=lambda t: abs(t - idx))
                d = target - idx
                if d != 0:
                    step = int(np.sign(d)) * int(min(abs(d), 2))
            new_dir = int(np.sign(step))
            run = run + 1 if new_dir == prev_dir else 1
            prev_dir = new_dir
            idx += step
        idx = _clamp(idx, 0, scale_len - 1)
        out.append(idx)
    return out, idx


@dataclass(frozen=True)
class Note:
    t: float          # debut (s)
    dur: float        # duree (s)
    freq: float
    vel: float
    grace: bool = False


def compose(cfg: Cfg) -> tuple[list[Note], list[tuple[float, bool, float]], list[tuple[float, int]], float, tuple[list[int], int]]:
    """Genere l'ossature symbolique complete.

    Retourne (notes melodiques, hits bodhran [(t, aigu, vel)], accords harpe
    [(t, root_idx)], duree musicale L (s), (scale, t0)).
    """
    rng = np.random.default_rng(cfg.seed)
    scale, t0 = build_scale(cfg.mode, cfg.key)
    slen = len(scale)
    tonic_pc = scale[t0] % 12
    fifth_pc = (tonic_pc + 7) % 12
    tonic_idx = [i for i, m in enumerate(scale) if m % 12 == tonic_pc]
    fifth_idx = [i for i, m in enumerate(scale) if m % 12 == fifth_pc]
    open_targets = fifth_idx + [_clamp(t0 + 1, 0, slen - 1)]   # 2e / 5e degre
    close_targets = tonic_idx or [t0]

    # Motif (degres 1-based du mode) -> index de gamme depuis la tonique de base.
    motif_idx: list[int] | None = None
    if cfg.motif.strip():
        degs = [int(x) for x in cfg.motif.replace(",", " ").split() if x.strip().lstrip("-").isdigit()]
        motif_idx = [_clamp(t0 + (d - 1), 0, slen - 1) for d in degs] or None

    pattern = cfg.pattern
    bar_pulses = BAR_PULSES[pattern]
    eighth = 30.0 / cfg.bpm                       # duree d'une croche (s)

    # Granularite = PHRASE (coupe sur frontiere de phrase entiere -> seamless), pour
    # coller a la duree cible ~40-48s sans etre force au cycle AABB complet (grossier).
    phrase_pulses = BARS_PER_PHRASE * bar_pulses
    phrase_s = phrase_pulses * eighth
    if cfg.bars > 0:
        n_phrases = max(4, round(cfg.bars / BARS_PER_PHRASE))
    else:
        n_phrases = max(4, round(cfg.target_s / phrase_s))
    total_pulses = n_phrases * phrase_pulses
    L = total_pulses * eighth

    # Rythmes A / B (une fois), puis tune = A A B B (tuilee jusqu'a n_phrases).
    rhythm_a = _phrase_rhythm(rng, pattern)
    rhythm_b = _phrase_rhythm(rng, pattern)
    start_a = _clamp(t0 + int(rng.integers(1, 4)), 0, slen - 1)
    pitches_a, end_a = _walk(rng, rhythm_a, slen, start_a, open_targets, motif_idx)
    # B : ouverture = inversion du motif (miroir autour de la tonique), cadence fermee.
    inv = [_clamp(2 * t0 - i, 0, slen - 1) for i in (motif_idx or pitches_a[:3])]
    pitches_b, _ = _walk(rng, rhythm_b, slen, end_a, close_targets, inv)

    aabb = [(rhythm_a, pitches_a), (rhythm_a, pitches_a),
            (rhythm_b, pitches_b), (rhythm_b, pitches_b)]
    phrase_seq = [aabb[i % 4] for i in range(n_phrases)]

    notes: list[Note] = []
    harp: list[tuple[float, int]] = []
    beats: list[tuple[float, bool, float]] = []
    pulse = 0                                     # position en croches depuis le debut
    orn_rng = np.random.default_rng(cfg.seed + 777)
    for rhythm, pitches in phrase_seq:
        phrase_start_pulse = pulse
        for dur_p, sidx in zip(rhythm, pitches):
            t = pulse * eighth
            # velocite par position dans la mesure (temps fort accentue)
            pos_in_bar = (pulse - phrase_start_pulse) % bar_pulses
            strong = (pos_in_bar == 0) or (pattern == "jig" and pos_in_bar == 3)
            vel = 1.0 if strong else 0.62 + 0.12 * orn_rng.random()
            freq = midi_to_freq(scale[sidx])
            ndur = dur_p * eighth
            # Ornement (cut/roll) sur notes longues : micro grace-note au-dessus.
            if dur_p >= 2 and orn_rng.random() < 0.22 and sidx + 1 < slen:
                g = 0.055
                notes.append(Note(max(0.0, t - g), g, midi_to_freq(scale[sidx + 1]), 0.5 * vel, grace=True))
            notes.append(Note(t, ndur * 0.96, freq, vel))
            # accord de harpe sur les debuts de mesure (harmonie douce)
            if pos_in_bar == 0:
                harp.append((t, sidx))
            pulse += dur_p
        # recale sur la frontiere de phrase (2 mesures) contre toute derive de somme
        pulse = phrase_start_pulse + phrase_pulses

    # Percussion bodhran : quantisee sur la grille, densite reglable.
    if cfg.beats:
        pat = BODHRAN[pattern]
        n_bars = total_pulses // bar_pulses
        for b in range(n_bars):
            for p, (force, high) in enumerate(pat):
                if force <= 0.0:
                    continue
                # densite : ne garde que les temps forts quand density est basse
                keep = force >= 0.9 or rng.random() < cfg.density * force + 0.05
                if not keep:
                    continue
                t = (b * bar_pulses + p) * eighth
                beats.append((t, high, force))

    return notes, beats, harp, L, (scale, t0)


# ═══════════════════════════════════════════════════════════════════════════
#  Voix tin-whistle (additive band-limitee : souffle + harmoniques + vibrato)
# ═══════════════════════════════════════════════════════════════════════════

def tin_whistle(freq: float, dur: float, seed: int, vel: float = 1.0,
                breath: float = 0.30, vib_rate: float = 5.2,
                vib_depth: float = 0.005) -> np.ndarray:
    """Tin-whistle : harmoniques band-limitees (zero repliement) + chiff de souffle
    + vibrato a onset retarde. Choix DELIBERE de l'additif band-limite plutot que
    d'un waveguide non-lineaire (risque d'aliasing/sifflement) — timbre de flute
    propre garanti. Toutes les composantes sous Nyquist par construction.
    """
    n = max(2, int(SR * dur))
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    nyq = 0.45 * SR
    # vibrato : entre apres l'attaque (comme un souffleur qui pose la note)
    vib_env = np.clip((t - 0.12) / 0.20, 0.0, 1.0)
    vib = vib_depth * vib_env * np.sin(2.0 * np.pi * vib_rate * t + rng.uniform(0, 2 * np.pi))
    phase = 2.0 * np.pi * np.cumsum(freq * (1.0 + vib)) / SR
    # spectre whistle : fondamentale dominante, 2e faible, aigus tenus
    harm = [1.0, 0.26, 0.11, 0.055, 0.028, 0.014]
    tone = np.zeros(n)
    used = 0.0
    for k, a in enumerate(harm, start=1):
        if freq * k >= nyq:
            break
        tone += a * np.sin(k * phase)
        used += a
    tone /= max(used, 1e-9)
    # souffle band-passe autour de la note (chiff d'attaque + air continu)
    hi = min(freq * 3.2, nyq)
    sos = signal.butter(2, [min(freq * 0.85, hi * 0.5) / (SR * 0.5), hi / (SR * 0.5)],
                        btype="band", output="sos")
    air = signal.sosfilt(sos, rng.standard_normal(n))
    air /= (np.max(np.abs(air)) + 1e-9)
    chiff = np.exp(-t / 0.035)                     # bouffee d'attaque
    breath_sig = air * (breath * (0.35 + 0.9 * chiff))
    # enveloppe amplitude : attaque douce ~18 ms, sustain, release ~50 ms
    env = np.ones(n)
    atk = min(int(0.018 * SR), n)
    rel = min(int(0.05 * SR), n)
    if atk > 1:
        env[:atk] = 0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, atk))
    if rel > 1:
        env[-rel:] *= np.linspace(1.0, 0.0, rel)
    out = (tone * 0.88 + breath_sig) * env * vel
    peak = np.max(np.abs(out))
    return out / peak * vel if peak > 1e-9 else out


# ═══════════════════════════════════════════════════════════════════════════
#  Lits (bed) STRICTEMENT PERIODIQUES -> boucle seamless par construction
# ═══════════════════════════════════════════════════════════════════════════

def _snap_freq(f: float, ln: int) -> float:
    """Retune f pour qu'un nombre ENTIER de cycles tienne dans ln echantillons
    (drone strictement periodique -> aucun clic au raccord de boucle)."""
    k = max(1, round(f * ln / SR))
    return k * SR / ln


def drone_bed(tonic_f: float, fifth_f: float, ln: int, seed: int, mood: str,
              level: float) -> np.ndarray:
    """Bourdon tonique+quinte SOUTENU (additif, snappe -> loop-safe). Evoque la
    corde frottee (vielle/archet) via partiels detunes battants + tremolo lent.
    Le bowed_drone de sfx_forge a un swell integre non-bouclable ; ce lit garde
    l'intention tonique+quinte en restant strictement periodique."""
    t = np.arange(ln) / SR
    rng = np.random.default_rng(seed)
    partials = [(tonic_f, 1.00, 0.000), (fifth_f, 0.55, 0.004),
                (tonic_f * 2, 0.32, 0.000), (tonic_f * 3, 0.10, 0.006),
                (fifth_f * 2, 0.16, 0.005)]
    if mood == "trouble":
        # teinte merveilleux-inquietant : quinte battante + tritone tres bas
        partials.append((tonic_f * (1.0 + 0.020), 0.28, 0.0))
        partials.append((tonic_f * 2.0 ** (6 / 12), 0.07, 0.008))
    out = np.zeros(ln)
    for f, a, det in partials:
        fs = _snap_freq(f * (1.0 + det), ln)
        out += a * np.sin(2.0 * np.pi * fs * t + rng.uniform(0, 2 * np.pi))
    lfo = _snap_freq(0.08, ln)                    # tremolo lent (respiration)
    trem = 1.0 - 0.10 * (0.5 - 0.5 * np.cos(2.0 * np.pi * lfo * t))
    out *= trem
    peak = np.max(np.abs(out))
    return out / peak * level if peak > 1e-9 else out


def _periodic_band_noise(ln: int, seed: int, lo: float, hi: float) -> np.ndarray:
    """Bruit band-passe STRICTEMENT periodique (mise en forme dans le domaine
    frequentiel -> irfft periodique). Loop-safe, pour le vent des falaises."""
    rng = np.random.default_rng(seed)
    w = rng.standard_normal(ln)
    W = np.fft.rfft(w)
    freqs = np.fft.rfftfreq(ln, 1.0 / SR)
    # fenetre douce (roll-off gaussien de part et d'autre de la bande)
    mask = np.ones_like(freqs)
    lo_r = np.clip((freqs - lo) / (lo * 0.5 + 1e-9), 0.0, 1.0)
    hi_r = np.clip((hi - freqs) / (hi * 0.5 + 1e-9), 0.0, 1.0)
    mask = lo_r * hi_r
    out = np.fft.irfft(W * mask, n=ln)
    peak = np.max(np.abs(out))
    return out / peak if peak > 1e-9 else out


def wind_bed(ln: int, seed: int, intensity: float) -> np.ndarray:
    t = np.arange(ln) / SR
    w = _periodic_band_noise(ln, seed, 260.0, 1700.0)
    lfo1 = _snap_freq(0.09, ln)
    lfo2 = _snap_freq(0.13, ln)
    gust = 0.55 + 0.28 * np.sin(2.0 * np.pi * lfo1 * t) + 0.17 * np.sin(2.0 * np.pi * lfo2 * t + 1.0)
    return w * gust * intensity


def circular_reverb(x: np.ndarray, seed: int, room: float = 0.55,
                    wet: float = 0.20, damp_hz: float = 3600.0) -> np.ndarray:
    """Reverb par convolution CIRCULAIRE (IR = bruit amorti band-limite).

    La convolution circulaire est periodique : la traine de reverb de la FIN
    reboucle sur le DEBUT -> raccord de boucle continu, sans clic ni coupure.
    C'est le pilier de la boucle seamless pour du contenu melodique."""
    n = x.size
    rng = np.random.default_rng(seed)
    ir_len = min(int(room * SR), n // 2)
    it = np.arange(ir_len) / SR
    ir = rng.standard_normal(ir_len) * np.exp(-it / (room * 0.4))
    sos = signal.butter(2, damp_hz / (SR * 0.5), btype="lowpass", output="sos")
    ir = signal.sosfilt(sos, ir)
    ir /= (np.max(np.abs(ir)) + 1e-9)
    H = np.fft.rfft(ir, n=n)
    wet_sig = np.fft.irfft(np.fft.rfft(x) * H, n=n)
    wet_sig /= (np.max(np.abs(wet_sig)) + 1e-9)
    return x * (1.0 - wet) + wet_sig * wet * (np.max(np.abs(x)) + 1e-9)


# ═══════════════════════════════════════════════════════════════════════════
#  Rendu
# ═══════════════════════════════════════════════════════════════════════════

def _seam_xfade(x: np.ndarray, fade_s: float) -> np.ndarray:
    """Fondu enchaine equal-power au raccord de boucle (etend l'idee de
    music_forge._make_seamless). Melange la fin dans le debut puis rogne la
    queue -> x[0] enchaine continument sur x[-1]. Fade court (contenu au repos)."""
    n = x.size
    nf = int(SR * fade_s)
    if nf < 2 or nf * 2 >= n:
        return x
    blend = np.arange(nf) / nf
    head = np.sqrt(1.0 - blend)
    tail = np.sqrt(blend)
    x = x.copy()
    x[:nf] = x[:nf] * tail + x[n - nf:] * head
    return x[:n - nf]


def _add(buf: np.ndarray, start_s: float, seg: np.ndarray) -> None:
    start = int(start_s * SR)
    if start >= buf.size or seg.size == 0:
        return
    end = min(buf.size, start + seg.size)
    buf[start:end] += seg[:end - start]


def _harp_chord(scale: list[int], root_idx: int, seed: int, level: float) -> np.ndarray:
    """Petit arpege ascendant (tonique+tierce+quinte du mode) via ks_pluck harpe."""
    slen = len(scale)
    idxs = [root_idx, _clamp(root_idx + 2, 0, slen - 1), _clamp(root_idx + 4, 0, slen - 1)]
    spacing = int(0.055 * SR)
    dur = 1.1
    n = int(SR * (dur + 0.15))
    out = np.zeros(n)
    for k, si in enumerate(idxs):
        pl = sfx.ks_pluck(midi_to_freq(scale[si] - 12), dur, seed + k,
                          damping=0.992, brightness=0.42, pick_pos=0.3, level=1.0 - 0.1 * k)
        s = k * spacing
        e = min(n, s + pl.size)
        out[s:e] += pl[:e - s]
    return out * level


def render_physical(cfg: Cfg) -> tuple[np.ndarray, dict]:
    """Backend historique : synthes physiques (Karplus harpe + tin-whistle additif
    + drone/vent synthetises). Conserve comme FALLBACK GPO-safe (aucune dependance)."""
    notes, beats, harp, L, (scale, t0) = compose(cfg)
    ln = int(round(SR * L))
    dry = np.zeros(ln)

    tonic_low = midi_to_freq(scale[t0] - 24)          # bourdon grave (tonique -2 octaves)
    fifth_low = tonic_low * 2.0 ** (7 / 12)

    melody_is_whistle = cfg.timbre in ("whistle", "both")
    double_harp = cfg.timbre == "both"

    # 1) melodie
    for i, nt in enumerate(notes):
        if melody_is_whistle and not nt.grace:
            seg = tin_whistle(nt.freq, max(nt.dur, 0.12), cfg.seed + 1000 + i,
                              vel=nt.vel, breath=0.34 if cfg.mood == "trouble" else 0.26,
                              vib_depth=0.006 if cfg.mood == "trouble" else 0.0045)
            _add(dry, nt.t, 0.55 * seg)
            if double_harp and nt.vel >= 0.95:       # double harpe sur temps forts
                pl = sfx.ks_pluck(nt.freq, min(nt.dur + 0.4, 1.4), cfg.seed + 5000 + i,
                                  damping=0.99, brightness=0.5, level=1.0)
                _add(dry, nt.t, 0.20 * pl)
        elif nt.grace and melody_is_whistle:
            seg = tin_whistle(nt.freq, nt.dur, cfg.seed + 1000 + i, vel=nt.vel, breath=0.2)
            _add(dry, nt.t, 0.35 * seg)
        else:                                         # timbre harpe : melodie pincee
            pl = sfx.ks_pluck(nt.freq, min(nt.dur + 0.5, 1.6), cfg.seed + 1000 + i,
                              damping=0.992, brightness=0.55, level=nt.vel)
            _add(dry, nt.t, (0.30 if nt.grace else 0.5) * pl)

    # 2) harmonie harpe (accords sur debut de mesure)
    harp_lvl = 0.22 if cfg.timbre == "harp" else 0.30
    for i, (t, ridx) in enumerate(harp):
        _add(dry, t, _harp_chord(scale, ridx, cfg.seed + 200 + i, harp_lvl))

    # 3) percussion bodhran
    for i, (t, high, force) in enumerate(beats):
        base = 132.0 if high else 92.0
        hit = sfx.membrane(0.34, base, cfg.seed + 400 + i, strike=0.006, metal=0.0)
        _add(dry, t, (0.20 * force) * hit)

    # 4) lits periodiques (ajoutes APRES, non reverberes en circulaire avec le reste
    #    -> mais on les inclut dans le mix avant reverb ; ils sont deja periodiques)
    drone_lvl = 0.40 if (cfg.wind or cfg.timbre == "whistle") else 0.32
    bed = drone_bed(tonic_low, fifth_low, ln, cfg.seed + 90, cfg.mood, drone_lvl)
    dry[:ln] += bed
    if cfg.wind:
        dry[:ln] += wind_bed(ln, cfg.seed + 91, 0.11)

    # 5) reverb circulaire (seamless) + soft lowpass selon l'ambiance
    damp = 2900.0 if cfg.mood == "trouble" else 3800.0
    wet = 0.24 if (cfg.mood == "trouble" or cfg.wind) else 0.19
    room = 0.7 if cfg.wind else 0.55
    wetmix = circular_reverb(dry, cfg.seed + 33, room=room, wet=wet, damp_hz=damp)

    meta = {"backend": "physical", "mode": cfg.mode, "key": cfg.key, "bpm": cfg.bpm,
            "pattern": cfg.pattern, "mood": cfg.mood, "timbre": cfg.timbre, "seed": cfg.seed,
            "bars": int(round(L / (30.0 / cfg.bpm) / BAR_PULSES[cfg.pattern])),
            "n_notes": len([n for n in notes if not n.grace]), "loop_s": round(L, 2)}
    return wetmix, meta


# ═══════════════════════════════════════════════════════════════════════════
#  Backend SF2 (vrais echantillons — GeneralUser GS via tinysoundfont)
# ═══════════════════════════════════════════════════════════════════════════

def _freq_to_key(f: float) -> int:
    """Frequence -> numero de note MIDI (69 = A4 440 Hz)."""
    return int(round(69.0 + 12.0 * math.log2(f / 440.0)))


def render_sf2(cfg: Cfg) -> tuple[np.ndarray, dict]:
    """Rendu par ECHANTILLONS REELS : route les note-events de la composition
    (identique au backend physical) vers un SoundFont GM via tinysoundfont.

    Boucle SEAMLESS par construction : on rend 3 boucles consecutives et on extrait
    celle du MILIEU. La boucle centrale est en REGIME PERMANENT (les queues de notes
    de la boucle 1 alimentent sa tete, les attaques de la boucle 3 alimentent sa fin,
    le bourdon cordes est tenu en continu sans re-attaque) -> x[L+k] ~= x[2L+k].
    Reverb CIRCULAIRE (periodique) + micro-fondu equal-power finalisent le raccord.
    """
    notes, beats, harp, L, (scale, t0) = compose(cfg)
    Lsamp = int(round(SR * L))
    n_loops = 3
    total = n_loops * Lsamp

    syn = _tsf.Synth(samplerate=SR, gain=-6.0)   # -6 dB : headroom anti-clip (voix empilees)
    sfid = syn.sfload(str(SOUNDFONT))
    if sfid < 0:
        raise RuntimeError(f"echec sfload : {SOUNDFONT}")
    syn.program_select(_CH_MEL, sfid, 0, cfg.melody_prog)
    syn.program_select(_CH_HARP, sfid, 0, GM_HARP)
    syn.program_select(_CH_STR, sfid, 0, GM_STRINGS)
    syn.program_select(_CH_DRUM, sfid, 128, 0, is_drums=True)
    # Balance des voix (CC7 volume canal) : melodie devant, cordes discretes en lit.
    syn.control_change(_CH_MEL, 7, 112)
    syn.control_change(_CH_HARP, 7, 90 if cfg.timbre == "both" else 76)
    syn.control_change(_CH_STR, 7, 52)
    syn.control_change(_CH_DRUM, 7, 74)
    if cfg.mood == "trouble":
        syn.set_tuning(_CH_STR, -0.08)           # cordes ~8 cents bas : battement inquietant

    # Construction des evenements MIDI (samp, kind[on=0/off=1], chan, key, vel).
    ev: list[tuple[int, int, int, int, int]] = []

    def _on(t: float, ch: int, key: int, vel: float) -> None:
        ev.append((int(t * SR), 0, ch, int(_clamp(key, 0, 127)), int(np.clip(vel, 1, 127))))

    def _off(t: float, ch: int, key: int) -> None:
        ev.append((int(t * SR), 1, ch, int(_clamp(key, 0, 127)), 0))

    melody_on_mel = cfg.timbre in ("whistle", "both")
    tonic_key = scale[t0] - 24
    fifth_key = tonic_key + 7
    slen = len(scale)

    for loop in range(n_loops):
        base = loop * L
        for nt in notes:
            key = _freq_to_key(nt.freq)
            if melody_on_mel:
                vel = 30 + nt.vel * 70 if nt.grace else 46 + nt.vel * 72
                _on(base + nt.t, _CH_MEL, key, vel)
                _off(base + nt.t + max(nt.dur, 0.10), _CH_MEL, key)
                # double harpe discrete sur les temps forts (timbre "both")
                if not nt.grace and nt.vel >= 0.95 and cfg.timbre == "both":
                    _on(base + nt.t, _CH_HARP, key, 52)
                    _off(base + nt.t + min(nt.dur + 0.4, 1.4), _CH_HARP, key)
            else:                                # timbre harpe : melodie pincee reelle
                _on(base + nt.t, _CH_HARP, key, 40 + nt.vel * 74)
                _off(base + nt.t + min(nt.dur + 0.5, 1.6), _CH_HARP, key)
        # arpeges de harpe sur les debuts de mesure (harmonie)
        if cfg.timbre != "whistle":
            for (t, ridx) in harp:
                for j, di in enumerate((0, 2, 4)):
                    si = _clamp(ridx + di, 0, slen - 1)
                    _on(base + t + j * 0.055, _CH_HARP, scale[si] - 12, 68 - j * 6)
                    _off(base + t + 1.1, _CH_HARP, scale[si] - 12)
        # percussion bodhran -> toms graves du kit GM
        for (t, high, force) in beats:
            key = GM_DRUM_HIGH if high else GM_DRUM_LOW
            _on(base + t, _CH_DRUM, key, 38 + force * 74)
            _off(base + t + 0.16, _CH_DRUM, key)

    # Bourdon cordes TENU en continu sur les 3 boucles (aucune re-attaque aux raccords).
    _on(0.0, _CH_STR, tonic_key, 78)
    _on(0.0, _CH_STR, fifth_key, 60)
    _off(n_loops * L, _CH_STR, tonic_key)
    _off(n_loops * L, _CH_STR, fifth_key)

    ev.sort(key=lambda e: (e[0], e[1]))

    # Rendu par blocs entre evenements ; stereo float32 interleaved -> mono.
    out = np.empty(total, dtype=np.float64)
    pos = 0
    for samp, kind, ch, key, vel in ev:
        s = min(samp, total)
        if s > pos:
            buf = np.frombuffer(syn.generate(s - pos), dtype=np.float32).reshape(-1, 2)
            out[pos:s] = buf.mean(axis=1)
            pos = s
        if kind == 0:
            syn.noteon(ch, key, vel)
        else:
            syn.noteoff(ch, key)
    if pos < total:
        buf = np.frombuffer(syn.generate(total - pos), dtype=np.float32).reshape(-1, 2)
        out[pos:total] = buf.mean(axis=1)

    dry_peak = float(np.max(np.abs(out)) + 1e-12)

    # Boucle du MILIEU (regime permanent) = boucle seamless.
    loopseg = out[Lsamp:2 * Lsamp].copy()

    # Ambiance de vent (bruit procedural STRICTEMENT periodique — pas un instrument).
    if cfg.wind:
        loopseg += wind_bed(loopseg.size, cfg.seed + 91, 0.09)

    # Reverb circulaire (periodique -> queue de reverb qui reboucle proprement).
    damp = 2900.0 if cfg.mood == "trouble" else 3800.0
    wet = 0.24 if (cfg.mood == "trouble" or cfg.wind) else 0.18
    room = 0.7 if cfg.wind else 0.5
    wetmix = circular_reverb(loopseg, cfg.seed + 33, room=room, wet=wet, damp_hz=damp)

    meta = {"backend": "sf2", "soundfont": SOUNDFONT.name, "mode": cfg.mode,
            "key": cfg.key, "bpm": cfg.bpm, "pattern": cfg.pattern, "mood": cfg.mood,
            "timbre": cfg.timbre, "melody_prog": cfg.melody_prog, "seed": cfg.seed,
            "bars": int(round(L / (30.0 / cfg.bpm) / BAR_PULSES[cfg.pattern])),
            "n_notes": len([n for n in notes if not n.grace]), "loop_s": round(L, 2),
            "dry_peak": round(dry_peak, 3)}
    return wetmix, meta


def render(cfg: Cfg) -> tuple[np.ndarray, dict]:
    """Dispatcher de rendu : SF2 (vrais echantillons, defaut) ou physical (fallback).

    Si le backend SF2 est demande mais indisponible (tinysoundfont absent ou SF2
    manquant), bascule sur le backend physical avec un avertissement explicite."""
    if cfg.render == "sf2":
        if not _HAS_TSF:
            print("[WARN] tinysoundfont absent -> fallback backend 'physical'. "
                  "pip install tinysoundfont pour le rendu par echantillons reels.")
        elif not SOUNDFONT.exists():
            print(f"[WARN] SoundFont introuvable ({SOUNDFONT}) -> fallback 'physical'. "
                  "Recuperer via: python tools/fetch_soundfont.py")
        else:
            return render_sf2(cfg)
    return render_physical(cfg)


def write_track(cfg: Cfg, out: Path) -> dict:
    samples, meta = render(cfg)
    audio, stats = norm.normalize(samples, target_lufs=MUSIC_TARGET_LUFS,
                                  peak_ceiling_db=MUSIC_PEAK_CEILING,
                                  trim=False, crest_cap_db=None, fade_edges=False)
    # Raccord de boucle POST-master : le highpass de normalize peut rouvrir un micro
    # pas au bord ; un fondu equal-power tout a la fin fait coincider x[0]~x[-1] a un
    # pas d'echantillon interieur pres, robuste pour TOUTES les pistes. Le backend SF2
    # a un bourdon cordes dont la boucle interne d'echantillon n'est pas alignee sur L
    # (leger dephasage au raccord) -> fondu plus long (25 ms) pour le lisser.
    seam_s = 0.025 if meta.get("backend") == "sf2" else 0.008
    audio = _seam_xfade(audio, seam_s)
    stats["duration_s"] = round(audio.size / SR, 3)
    norm.write_wav16(audio, out)
    meta.update(stats)
    print(f"OK [{meta.get('backend','?'):8s}] {out.name:26s} {meta['mode']:10s} {cfg.key} "
          f"{cfg.bpm}bpm {cfg.pattern:4s} seed={cfg.seed:<4d} {stats['duration_s']:.1f}s "
          f"LUFS {stats['lufs']:+.1f} TP {stats['true_peak_db']:+.1f}")
    return meta


# ═══════════════════════════════════════════════════════════════════════════
#  Presets biome + batch de variantes
# ═══════════════════════════════════════════════════════════════════════════

PRESETS: dict[str, Cfg] = {
    # Foret : air melodique + bodhran discret (jig doux), dorien lumineux.
    # seed=3 -> arche large (montee a +14 st puis retour), 8 hauteurs distinctes.
    "foret": Cfg(bpm=84, mode="dorien", key="D", mood="sain", timbre="both",
                 beats=True, pattern="jig", density=0.30, target_s=44.0, seed=3, biome="foret"),
    # Falaises : melancolie eolienne, whistle + cordes/drone + vent, air rubato.
    # seed=11 -> descente melodique sur une octave (feel "bout du monde").
    "falaises": Cfg(bpm=64, mode="eolien", key="D", mood="trouble", timbre="whistle",
                    beats=True, pattern="air", density=0.18, target_s=46.0, seed=11,
                    wind=True, biome="falaises"),
}

# (id de sortie, cfg, drop-in vers music/gameplay ?)
# Backend SF2 par defaut -> vrais echantillons. Les variantes couvrent 3 axes de
# choix : graine (melodie), mode, et TIMBRE DE LA VOIX (flute vs recorder vs pan-
# flute — GM n'a pas de vrai tin-whistle, on laisse l'utilisateur choisir a l'oreille).
VARIANTS: list[tuple[str, Cfg, bool]] = [
    ("gameplay_calm", PRESETS["foret"], True),
    ("gameplay_falaises", PRESETS["falaises"], True),
    ("gameplay_calm__v2", replace(PRESETS["foret"], seed=7), False),
    ("gameplay_calm__mixo", replace(PRESETS["foret"], mode="mixolydien", seed=12, bpm=80), False),
    # A/B de timbre de voix melodique (meme air foret, whistle seul) :
    ("gameplay_calm__recorder", replace(PRESETS["foret"], timbre="whistle", melody_prog=GM_RECORDER, seed=3), False),
    ("gameplay_falaises__panflute", replace(PRESETS["falaises"], melody_prog=GM_PANFLUTE, seed=11), False),
    ("gameplay_falaises__v2", replace(PRESETS["falaises"], seed=53, bpm=60, mode="eolien"), False),
]


def gen_variants() -> None:
    GEN_DIR.mkdir(parents=True, exist_ok=True)
    manifest: dict = {}
    for vid, cfg, dropin in VARIANTS:
        meta = write_track(cfg, GEN_DIR / f"{vid}.wav")
        manifest[vid] = meta
        if dropin:
            drop = GAMEPLAY_DIR / f"{vid}.wav"
            # ecrit aussi la version drop-in dans music/gameplay (byte-identique)
            import shutil
            shutil.copyfile(GEN_DIR / f"{vid}.wav", drop)
            print(f"   drop-in -> {drop}")
    (GEN_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\n{len(VARIANTS)} pistes -> {GEN_DIR}\n2 defauts drop-in -> {GAMEPLAY_DIR}")


def _cfg_from_args(a: argparse.Namespace) -> Cfg:
    base = PRESETS.get(a.biome, Cfg()) if a.biome else Cfg()
    kw = {}
    if a.bpm is not None: kw["bpm"] = a.bpm
    if a.mode is not None: kw["mode"] = a.mode
    if a.key is not None: kw["key"] = a.key
    if a.mood is not None: kw["mood"] = a.mood
    if a.timbre is not None: kw["timbre"] = a.timbre
    if a.beats is not None: kw["beats"] = (a.beats == "on")
    if a.pattern is not None: kw["pattern"] = a.pattern
    if a.density is not None: kw["density"] = a.density
    if a.bars is not None: kw["bars"] = a.bars
    if a.motif is not None: kw["motif"] = a.motif
    if a.seed is not None: kw["seed"] = a.seed
    if a.wind is not None: kw["wind"] = (a.wind == "on")
    if a.render is not None: kw["render"] = a.render
    if a.whistle_prog is not None: kw["melody_prog"] = a.whistle_prog
    return replace(base, **kw)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(description="Melody forge M.E.R.L.I.N. — compositeur celtique (BIBLE §22)")
    p.add_argument("--list", action="store_true", help="lister modes/patterns/biomes")
    p.add_argument("--variants", action="store_true", help="generer 2 defauts + variantes A/B")
    p.add_argument("--biome", choices=list(PRESETS.keys()), help="preset de biome")
    p.add_argument("--bpm", type=int)
    p.add_argument("--mode", choices=list(MODES.keys()))
    p.add_argument("--key")
    p.add_argument("--mood", choices=["sain", "trouble"])
    p.add_argument("--timbre", choices=["harp", "whistle", "both"])
    p.add_argument("--beats", choices=["on", "off"])
    p.add_argument("--pattern", choices=["jig", "reel", "air"])
    p.add_argument("--density", type=float)
    p.add_argument("--bars", type=int)
    p.add_argument("--motif", help='degres du mode, ex "1 2 3 5"')
    p.add_argument("--seed", type=int)
    p.add_argument("--wind", choices=["on", "off"])
    p.add_argument("--render", choices=["sf2", "physical"],
                   help="backend de rendu : sf2 (vrais echantillons, defaut) | physical (fallback synthe)")
    p.add_argument("--whistle-prog", type=int, dest="whistle_prog",
                   help=f"programme GM de la voix melodique (defaut {GM_FLUTE}=Flute ; "
                        f"{GM_RECORDER}=Recorder, {GM_PANFLUTE}=PanFlute, {GM_WHISTLE}=Whistle)")
    p.add_argument("--out", help="chemin WAV de sortie")
    args = p.parse_args()

    if args.list:
        print("Modes    :", ", ".join(MODES))
        print("Patterns :", ", ".join(RHYTHM_BANK))
        print("Biomes   :", ", ".join(PRESETS))
        print("Timbres  : harp, whistle, both   Mood: sain, trouble")
        print(f"Backends : sf2 (defaut, {SOUNDFONT.name}, {'OK' if SOUNDFONT.exists() else 'ABSENT -> fetch_soundfont.py'}), physical")
        print(f"Whistle  : {GM_FLUTE}=Flute {GM_RECORDER}=Recorder {GM_PANFLUTE}=PanFlute {GM_WHISTLE}=Whistle")
        return 0
    if args.variants:
        gen_variants()
        return 0

    cfg = _cfg_from_args(args)
    out = Path(args.out) if args.out else (GEN_DIR / "melody_custom.wav")
    out.parent.mkdir(parents=True, exist_ok=True)
    write_track(cfg, out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
