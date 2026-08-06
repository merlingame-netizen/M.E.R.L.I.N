#!/usr/bin/env python3
"""
Construit une banque MULTI-ECHANTILLONS a partir de bibliotheques reelles.

POURQUOI
--------
Synthetiser un hautbois ou un pupitre de cordes a un plafond. On peut affiner les
formants, l'ensemble, la velocite timbrale — ca reste une imitation, et l'oreille
l'entend. Les bibliotheques orchestrales utilisent des enregistrements pour cette
raison exacte. Ce script prend des instruments REELLEMENT ENREGISTRES et les
prepare pour le moteur de rendu.

Sources gerees, toutes librement redistribuables :
  - VSCO-2 Community Edition (Versilian Studios) — cordes, bois, cuivres, harpe
  - VCSL, Versilian Community Sample Library     — percussion, harpes, cloches
Les deux sont sous CC0 : domaine public, usage commercial compris, sans attribution.

CE QUI COMPTE ICI
-----------------
1. MULTI-ECHANTILLON — un violon transpose d'une octave ne sonne plus comme un
   violon (l'effet "chipmunk" deplace les formants avec la hauteur). Chaque note
   demandee va chercher l'echantillon enregistre le plus proche, et ne se
   transpose que de quelques demi-tons.
2. BOUCLE PREPAREE — un sample tenu dure 3 a 6 s ; certaines nappes de la piece
   durent 14 s. La zone stable est reperee et son extremite fondue dans son
   debut, pour boucler sans clic.
3. VELOCITE — TOUTES les couches sont conservees, et le moteur choisit celle qui
   correspond a la nuance demandee. Un instrumentiste ne monte pas le volume
   quand il joue fort : il change de TIMBRE. Garder une seule couche revenait a
   rejouer litteralement le meme enregistrement pour toutes les nuances — c'est
   ce qui faisait « synthetique » malgre des sources reelles.

    python3 tools/audio/build_sample_bank.py --vsco <dir> --vcsl <dir> --out samples/
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import wave

import numpy as np

SR = 44100
# La note peut etre precedee d'un separateur (`sus_A#3_r01.wav`) ou ouvrir carrement
# le nom de fichier — c'est le cas du dan tranh, dont les fichiers s'appellent
# `B1_mf_1.wav`. Sans l'ancre de debut, 48 echantillons etaient silencieusement
# ignores et l'instrument n'apparaissait pas dans la banque.
NOTE_RE = re.compile(r"(?:^|[_\-])([A-Ga-g])([#b]?)(-?\d)(?=[_\-.])")
PITCH = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

# instrument du moteur -> (sous-chemin de la source, filtre de nom, tenu ?)
# Les instruments absents des bibliotheques restent synthetises : le couple
# breton (bombarde, biniou), la nappe FM froide, le sub, le choeur.
SOURCES = {
    "vsco": {
        "strings_high":    ("Strings/Violin Section/susVib", None, True),
        "strings_mid":     ("Strings/Viola Section", "sus", True),
        "viola":           ("Strings/Viola Section", "sus", True),
        "strings_low":     ("Strings/Cello Section/susvib", None, True),
        "contrabass":      ("Strings/Cello Section/susvib", None, True),
        "violin_solo":     ("Strings/Violin Section/susVib", None, True),
        "strings_tremolo": ("Strings/Violin Section/susVib", None, True),
        "pizzicato":       ("Strings/Harp", None, False),
        "flute":           ("Woodwinds/Flute/susvib", None, True),
        "piccolo":         ("Woodwinds/Flute/susvib", None, True),
        "oboe":            ("Woodwinds/Oboe/Sus", None, True),
        "cor_anglais":     ("Woodwinds/Oboe/Sus", None, True),
        "clarinet":        ("Woodwinds/Clarinet", "sus", True),
        "bassoon":         ("Woodwinds/Bassoon", None, True),
        "horn":            ("Brass/F Horn/sus", None, True),
        "trombone":        ("Brass/F Horn/sus", None, True),
        "tuba":            ("Brass/F Horn/sus", None, True),
        "brass_ff":        ("Brass/F Horn/sus", None, True),
        "trumpet":         ("Brass/F Horn/sus", None, True),
        "harp":            ("Strings/Harp", None, False),
    },
    "vcsl": {
        "celtic_guitar":   ("Chordophones/Composite Chordophones/Folk Harp", None, False),
        "celesta_bell":    ("Idiophones/Struck Idiophones/Tubular Bells 1", None, False),
        "glockenspiel":    ("Idiophones/Struck Idiophones/Glockenspiel", None, False),
        "celesta":         ("Idiophones/Struck Idiophones/Glockenspiel", None, False),
        "timpani":         ("Membranophones/Struck Membranophones/Timpani 1/Hit", None, False),
        "taiko":           ("Membranophones/Struck Membranophones/Frame Drum", "Hit_", False),
        "bodhran":         ("Membranophones/Struck Membranophones/Frame Drum", "Muted", False),
        # ── SURCOUCHES CONTEXTUELLES ─────────────────────────────────────────
        # Ces pupitres ne jouent jamais dans le mix de base. Ils n'existent que
        # dans les couches activees par la meteo, la saison ou le moment. Voir
        # layers_menu.py.
        "dan_tranh":       ("Chordophones/Zithers/Dan Tranh/Normal", "_mf_", False),
        "psaltery":        ("Chordophones/Zithers/Psaltery, Bowed and Plucked/LongBow", None, True),
        # les trois cordes du strumstick, sinon on n'obtient que re2-sol2
        "strumstick":      ("Chordophones/Composite Chordophones/Strumstick/Finger", None, False),
        "kalimba":         ("Idiophones/Plucked Idiophones/Kalimba, Tanzania", None, False),
        "mbira":           ("Idiophones/Plucked Idiophones/"
                            "Mbira dzaVadzimu Nyamaropa, Zimbabwe, Low B", None, False),
        "hand_chimes":     ("Idiophones/Struck Idiophones/Hand Chimes", None, False),
        "bell_tree":       ("Idiophones/Struck Idiophones/Bell Tree/Individual", None, False),
        "wine_glasses":    ("Idiophones/Friction Idiophones/Wine Glasses/Sustains", "Slow", True),
        "ocarina":         ("Aerophones/Edge-blown Aerophones/Ocarina, Typical/Sustains", None, True),
        "harmonica":       ("Aerophones/Free Aerophones/Harmonica-Hohner-Super64/Sustains/Normal",
                            None, True),
    },
}
# instruments sans hauteur : un seul echantillon suffit
# Ces enregistrements ne portent pas de note dans leur nom : ils sont montes sur
# une hauteur de reference et transposes par le moteur.
# (bibliotheque, sous-chemin, filtre, note de reference, tenu ?)
UNPITCHED_SRC = {
    "cymbal":     ("vcsl", "Idiophones/Struck Idiophones/Suspended Cymbal 1", "cresc", 60, False),
    "tam_tam":    ("vcsl", "Idiophones/Struck Idiophones/Gong 1", None, 60, False),
    "timpani":    ("vcsl", "Membranophones/Struck Membranophones/Timpani 1/Hit", "v2", 41, False),
    "taiko":      ("vcsl", "Membranophones/Struck Membranophones/Frame Drum",
                   "HDrumL_Hit_", 45, False),
    "bodhran":    ("vcsl", "Membranophones/Struck Membranophones/Frame Drum",
                   "HDrumS_Hit_", 50, False),
    "snare_roll": ("vcsl", "Idiophones/Struck Idiophones/Suspended Cymbal 1", "bow", 60, False),
    # ── SURCOUCHES ───────────────────────────────────────────────────────────
    # Le tambour ocean est un cercle de billes sur une peau : c'est litteralement
    # un instrument a bruit de pluie. Il est TENU, sinon il s'arrete au bout de
    # trois secondes au milieu de l'averse.
    "ocean_drum": ("vcsl", "Membranophones/Other Membranophones/Ocean Drum", "Sus", 60, True),
    "didgeridoo": ("vcsl", "Aerophones/Lip Aerophones/Didgeridoo", "Sus", 38, True),
    "slit_drum":  ("vcsl", "Idiophones/Struck Idiophones/Slit Drum", "LogDrumHi", 55, False),
    "hand_bells": ("vcsl", "Idiophones/Struck Idiophones/Hand Bells, Nepalese", None, 67, False),
    "mark_tree":  ("vcsl", "Idiophones/Struck Idiophones/Mark Trees", "asc", 84, False),
}


def parse_note(name: str) -> int | None:
    m = NOTE_RE.search(name)
    if not m:
        return None
    step, acc, octv = m.group(1).upper(), m.group(2), int(m.group(3))
    semi = PITCH[step] + (1 if acc == "#" else -1 if acc == "b" else 0)
    return (octv + 1) * 12 + semi                      # C4 = 60


def parse_velocity(name: str) -> int:
    # `_v2_` chez VSCO-2, `_vl2_` chez VCSL (strumstick)
    m = re.search(r"[_\-]vl?(\d)", name, re.I)
    return int(m.group(1)) if m else 2


def read_wav(path: str) -> tuple[np.ndarray, int]:
    with wave.open(path, "rb") as w:
        rate, nch, width = w.getframerate(), w.getnchannels(), w.getsampwidth()
        raw = w.readframes(w.getnframes())
    if width == 2:
        x = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    elif width == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        v = (b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16))
        v = np.where(v & 0x800000, v - 0x1000000, v)
        x = v.astype(np.float64) / 8388608.0
    elif width == 4:
        x = np.frombuffer(raw, dtype="<i4").astype(np.float64) / 2147483648.0
    else:
        raise ValueError(f"{path}: {width*8} bits non gere")
    if nch > 1:
        x = x.reshape(-1, nch).mean(axis=1)
    return x, rate


def write_wav(path: str, x: np.ndarray, rate: int) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


def trim(x: np.ndarray, thresh: float = 2e-4) -> np.ndarray:
    """Retire le silence de tete et de queue."""
    a = np.abs(x)
    idx = np.nonzero(a > thresh)[0]
    if len(idx) < 2:
        return x
    return x[max(0, idx[0] - 64): idx[-1] + 1]


def find_loop(x: np.ndarray, rate: int) -> tuple[int, int]:
    """Repere une zone tenue et stable, puis fond sa fin dans son debut.

    Un sample tenu dure 3 a 6 s ; certaines nappes de la piece durent 14 s. Sans
    boucle, la note se tairait au milieu."""
    n = len(x)
    if n < rate:
        return 0, 0
    start = int(n * 0.42)
    length = int(n * 0.34)
    if start + length >= n:
        length = n - start - 1
    if length < rate // 8:
        return 0, 0
    # cale la longueur sur un passage par zero, pour reduire la discontinuite
    seg = x[start + length - rate // 20: start + length]
    if len(seg) > 2:
        zc = np.nonzero(np.diff(np.signbit(seg)))[0]
        if len(zc):
            length = length - (len(seg) - zc[-1]) + 1
    return start, max(1, length)


def crossfade_loop(x: np.ndarray, start: int, length: int, ms: float = 60.0,
                   rate: int = SR) -> np.ndarray:
    """Fond l'entree de boucle avec la matiere qui la precede : plus de clic."""
    k = min(int(ms * rate / 1000), length // 3, start)
    if k < 16:
        return x
    y = x.copy()
    w = np.linspace(0.0, 1.0, k)
    y[start: start + k] = x[start: start + k] * w + x[start + length: start + length + k] * (1 - w)
    return y


def collect(root: str, sub: str, filt: str | None) -> list[str]:
    base = os.path.join(root, sub)
    out = []
    for dirpath, _dirs, files in os.walk(base):
        for f in files:
            if not f.lower().endswith(".wav"):
                continue
            if filt and filt.lower() not in os.path.join(dirpath, f).lower():
                continue
            out.append(os.path.join(dirpath, f))
    return sorted(out)


def build(vsco: str | None, vcsl: str | None, out_dir: str, verbose: bool = True) -> dict:
    roots = {"vsco": vsco, "vcsl": vcsl}
    samples: list[dict] = []
    per_inst: dict[str, int] = {}

    for lib, table in SOURCES.items():
        root = roots.get(lib)
        if not root or not os.path.isdir(root):
            continue
        for inst, (sub, filt, looped) in table.items():
            files = collect(root, sub, filt)
            if not files:
                if verbose:
                    print(f"  ! {inst}: rien trouve dans {sub}", file=sys.stderr)
                continue
            # TOUTES LES COUCHES DE VELOCITE, pas seulement la mediane.
            #
            # La version precedente n'en gardait qu'une par note — celle la plus
            # proche de v2 — et jetait les autres. Consequence : toutes les notes
            # d'une meme hauteur etaient LITTERALEMENT le meme enregistrement
            # rejoue, quelle que soit la nuance. C'est le principal aveu de
            # synthese du rendu, et il ne venait pas de la bibliotheque : VSCO-2 CE
            # fournit 2 a 4 couches (violons v1-v2, hautbois v1/v3, cor v1-v4).
            #
            # Un instrumentiste ne monte pas le volume quand il joue fort : il
            # change de TIMBRE. Aucun filtre ne simule ca de facon convaincante,
            # alors que les couches sont deja sur le disque.
            best: dict[tuple[int, int], str] = {}
            for p in files:
                note = parse_note(os.path.basename(p))
                if note is None:
                    continue
                vel = parse_velocity(os.path.basename(p))
                best.setdefault((note, vel), p)
            if not best:
                continue
            for (note, vel), src in sorted(best.items()):
                try:
                    x, rate = read_wav(src)
                except Exception as exc:
                    print(f"  ! {src}: {exc}", file=sys.stderr)
                    continue
                x = trim(x)
                if len(x) < 256:
                    continue
                peak = float(np.abs(x).max())
                if peak > 0:
                    x = x / peak * 0.85
                ls, ll = find_loop(x, rate) if looped else (0, 0)
                if ll:
                    x = crossfade_loop(x, ls, ll, rate=rate)
                rel = f"{inst}/{inst}_{note:03d}_v{vel}.wav"
                write_wav(os.path.join(out_dir, rel), x, rate)
                samples.append({
                    "file": rel, "instrument": inst, "group": lib,
                    "base_note": note, "velocity": vel,
                    "sample_rate": rate, "num_samples": len(x),
                    "looped": bool(ll), "loop_start": int(ls), "loop_length": int(ll),
                    "duration_s": round(len(x) / rate, 4), "format": 1,
                    "source_file": os.path.relpath(src, root),
                })
                per_inst[inst] = per_inst.get(inst, 0) + 1

    for inst, (lib, sub, filt, ref_note, looped) in UNPITCHED_SRC.items():
        root = roots.get(lib)
        if not root:
            continue
        files = collect(root, sub, filt)
        if not files:
            if verbose:
                print(f"  ! {inst}: rien trouve dans {sub}", file=sys.stderr)
            continue
        src = max(files, key=os.path.getsize)
        try:
            x, rate = read_wav(src)
        except Exception:
            continue
        x = trim(x)
        peak = float(np.abs(x).max())
        if peak > 0:
            x = x / peak * 0.85
        ls, ll = find_loop(x, rate) if looped else (0, 0)
        if ll:
            x = crossfade_loop(x, ls, ll, rate=rate)
        rel = f"{inst}/{inst}_{ref_note:03d}.wav"
        write_wav(os.path.join(out_dir, rel), x, rate)
        samples.append({"file": rel, "instrument": inst, "group": lib, "base_note": ref_note,
                        "sample_rate": rate, "num_samples": len(x), "looped": bool(ll),
                        "loop_start": int(ls), "loop_length": int(ll),
                        "duration_s": round(len(x) / rate, 4), "format": 1,
                        "source_file": os.path.relpath(src, root)})
        per_inst[inst] = per_inst.get(inst, 0) + 1

    # ── CALIBRATION ──────────────────────────────────────────────────────────
    # Les echantillons sont normalises en crete, mais un cor a crete 0,85 n'est
    # pas percu au meme niveau qu'un glockenspiel a crete 0,85. On mesure la RMS
    # de la fenetre de 200 ms la plus forte et on ramene chaque instrument a sa
    # place dans la hierarchie orchestrale.
    TARGET = {
        "strings_high": -13.0, "strings_mid": -15.0, "strings_low": -15.0,
        "strings_tremolo": -15.5, "viola": -15.0, "contrabass": -16.0,
        "violin_solo": -11.0, "pizzicato": -16.0,
        "horn": -15.0, "brass_ff": -13.0, "trumpet": -12.5, "trombone": -14.0, "tuba": -15.0,
        "flute": -9.5, "piccolo": -11.0, "oboe": -9.5, "cor_anglais": -11.0,
        "clarinet": -13.0, "bassoon": -14.5,
        "harp": -15.0, "celtic_guitar": -14.0,
        "glockenspiel": -14.0, "celesta": -14.0, "celesta_bell": -15.0,
        "timpani": -13.5, "taiko": -14.0, "bodhran": -14.0,
        "cymbal": -16.0, "tam_tam": -15.0, "snare_roll": -17.0,
        # Surcouches : 3 a 5 dB sous les pupitres du mix de base. Une couche est
        # une COULEUR ajoutee, pas une voix supplementaire — si on l'entend comme
        # un instrument de plus, elle est trop forte.
        "dan_tranh": -18.0, "psaltery": -18.5, "strumstick": -18.0,
        "kalimba": -18.0, "mbira": -18.5, "hand_chimes": -18.5, "bell_tree": -19.0,
        "wine_glasses": -19.0, "ocarina": -15.0, "harmonica": -17.0,
        "ocean_drum": -21.0, "didgeridoo": -17.0, "slit_drum": -18.0,
        "hand_bells": -18.5, "mark_tree": -20.0,
    }
    gains: dict[str, float] = {}
    for inst in per_inst:
        cand = [s for s in samples if s["instrument"] == inst]
        # calibrer sur une couche MEDIANE, pas sur la plus forte : sinon tout
        # l'instrument est baisse pour compenser son fortissimo
        vs = sorted({c.get("velocity", 2) for c in cand})
        mid_v = vs[len(vs) // 2]
        same = [c for c in cand if c.get("velocity", 2) == mid_v] or cand
        mid = same[len(same) // 2]
        x, rate = read_wav(os.path.join(out_dir, mid["file"]))
        w = int(0.2 * rate)
        if len(x) > w:
            e = np.convolve(x ** 2, np.ones(w) / w, mode="valid")
            lvl = 20 * np.log10(np.sqrt(e.max()) + 1e-12)
        else:
            lvl = 20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-12)
        gains[inst] = round(float(10 ** ((TARGET.get(inst, -14.0) - lvl) / 20.0)), 4)

    manifest = {
        "kind": "multisample",
        "gains": gains,
        "libraries": [
            {"name": "VSCO-2 Community Edition", "author": "Versilian Studios LLC",
             "license": "CC0-1.0", "url": "https://github.com/sgossner/VSCO-2-CE"},
            {"name": "Versilian Community Sample Library (VCSL)",
             "author": "Versilian Studios LLC", "license": "CC0-1.0",
             "url": "https://github.com/sgossner/VCSL"},
        ],
        "instrument_count": len(per_inst),
        "sample_count": len(samples),
        "per_instrument": dict(sorted(per_inst.items())),
        "samples": samples,
    }
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2, ensure_ascii=False)
    if verbose:
        print(f"[bank] {len(per_inst)} instruments, {len(samples)} echantillons -> {out_dir}")
        for k, v in sorted(per_inst.items()):
            ss = [s for s in samples if s["instrument"] == k]
            notes = [s["base_note"] for s in ss]
            nv = len({s.get("velocity", 2) for s in ss})
            print(f"  {k:16s} {len(set(notes)):3d} notes x {nv} couche(s) = {v:3d} "
                  f"({min(notes)}-{max(notes)})  gain {gains.get(k, 1.0):.2f}")
    return manifest


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--vsco", help="racine de VSCO-2-CE")
    ap.add_argument("--vcsl", help="racine de VCSL")
    ap.add_argument("--out", default="samples")
    args = ap.parse_args()
    if not args.vsco and not args.vcsl:
        ap.error("fournissez au moins --vsco ou --vcsl")
    build(args.vsco, args.vcsl, args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
