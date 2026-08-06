#!/usr/bin/env python3
"""
Banque d'echantillons — joue des samples reels a la place des fonts synthetisees.

Branche la sortie de `musyx_extract.py` sur `synth_palette.py` : meme composition,
memes stems, meme timing — seule la matiere sonore change.

Le fichier `palette_map.json` de la banque decide QUELS samples servent a QUEL role.
C'est le fichier a editer pour ne garder que les fonts voulus.

    {
      "pad_fm":  {"file": "TestGroup/0x1000.wav", "base_note": 60, ...},
      "bell":    {"file": "TestGroup/0x1004.wav", "base_note": 72, ...},
      ...
    }

S'il est absent, une proposition est generee par heuristique (et ecrite sur disque)
pour servir de point de depart.
"""

from __future__ import annotations

import json
import os
import sys
import wave

import numpy as np

SR = 44100
ROLES = ["pad_fm", "sub", "bell", "harp", "taiko", "choir", "whistle"]

# Enveloppes par role — identiques a celles des fonts synthetisees, pour que la
# composition garde exactement la meme forme quelle que soit la matiere.
ENVELOPES = {
    "pad_fm":  dict(a=2.6, d=1.0, s=0.78, r=3.2, loop=True),
    "sub":     dict(a=0.9, d=0.6, s=0.80, r=1.8, loop=True),
    "bell":    dict(a=0.002, d=0.0, s=1.0, r=0.25, loop=False),
    "harp":    dict(a=0.001, d=0.05, s=0.90, r=0.5, loop=False),
    "taiko":   dict(a=0.001, d=0.0, s=1.0, r=0.12, loop=False),
    "choir":   dict(a=1.8, d=0.8, s=0.80, r=2.4, loop=True),
    "whistle": dict(a=0.12, d=0.15, s=0.85, r=0.35, loop=True),
}


def midi_hz(m: float) -> float:
    return 440.0 * (2.0 ** ((m - 69.0) / 12.0))


def _adsr(n: int, a: float, d: float, s: float, r: float) -> np.ndarray:
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    if na + nd + nr > n:
        k = n / max(1, na + nd + nr)
        na, nd, nr = int(na * k), int(nd * k), int(nr * k)
    ns = max(0, n - na - nd - nr)
    env = np.concatenate([
        np.linspace(0, 1, na, endpoint=False) ** 1.6 if na else np.empty(0),
        np.linspace(1, s, nd, endpoint=False) if nd else np.empty(0),
        np.full(ns, s),
        np.linspace(s, 0, nr) ** 1.5 if nr else np.empty(0),
    ])
    if len(env) < n:
        env = np.concatenate([env, np.zeros(n - len(env))])
    return env[:n]


def read_wav_mono(path: str) -> tuple[np.ndarray, int]:
    with wave.open(path, "rb") as w:
        rate = w.getframerate()
        nch = w.getnchannels()
        width = w.getsampwidth()
        raw = w.readframes(w.getnframes())
    if width != 2:
        raise ValueError(f"{path}: seuls les WAV 16 bits sont geres (trouve {width*8})")
    x = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    if nch > 1:
        x = x.reshape(-1, nch).mean(axis=1)
    return x, rate


def propose_map(manifest: list[dict]) -> dict:
    """Heuristique de premier jet : a relire et corriger a la main."""
    if not manifest:
        return {}
    looped = [m for m in manifest if m.get("looped")]
    oneshot = [m for m in manifest if not m.get("looped")]
    by_note = lambda xs: sorted(xs, key=lambda m: m.get("base_note", 60))
    by_dur = lambda xs: sorted(xs, key=lambda m: m.get("duration_s", 0))
    pick = {}

    def take(pool, key=None, default_pool=None):
        pool = pool or default_pool or manifest
        return (key(pool) if key else pool)[0] if pool else None

    if looped:
        ln = by_note(looped)
        pick["sub"] = ln[0]                                   # le plus grave
        pick["pad_fm"] = by_dur(looped)[-1]                   # le plus long
        pick["choir"] = ln[len(ln) // 2]
        pick["whistle"] = ln[-1]                              # le plus aigu
    if oneshot:
        od = by_dur(oneshot)
        low = [m for m in oneshot if m.get("base_note", 60) < 52]
        pick["taiko"] = (by_dur(low)[0] if low else od[0])    # court et grave
        pick["bell"] = od[-1]                                 # le plus long
        mid = [m for m in oneshot if 0.2 < m.get("duration_s", 0) < 3.0]
        pick["harp"] = (mid[len(mid) // 2] if mid else od[len(od) // 2])
    for r in ROLES:
        pick.setdefault(r, manifest[0])
    return pick


class SampleBank:
    """Lecteur d'echantillons : transposition, bouclage, enveloppe par role."""

    def __init__(self, path: str, verbose: bool = True):
        self.path = path
        man_file = os.path.join(path, "manifest.json")
        if not os.path.exists(man_file):
            raise FileNotFoundError(
                f"{man_file} introuvable. Lancez d'abord :\n"
                f"  python3 tools/audio/musyx_extract.py iso --input <votre.iso> --out {path}")
        with open(man_file, encoding="utf-8") as fh:
            raw = json.load(fh)
        # manifest v1.1 : dict avec bloc source ; v1.0 : simple liste
        if isinstance(raw, dict):
            self.manifest = raw.get("samples", [])
            self.source = raw.get("source")
            self.extracted_at = raw.get("extracted_at")
        else:
            self.manifest = raw
            self.source = None
            self.extracted_at = None

        map_file = os.path.join(path, "palette_map.json")
        if os.path.exists(map_file):
            with open(map_file, encoding="utf-8") as fh:
                self.map = json.load(fh)
            src = "palette_map.json"
        else:
            self.map = propose_map(self.manifest)
            with open(map_file, "w", encoding="utf-8") as fh:
                json.dump(self.map, fh, indent=2, ensure_ascii=False)
            src = "proposition heuristique (ecrite dans palette_map.json)"

        self._cache: dict[str, tuple[np.ndarray, int]] = {}
        if verbose:
            print(f"[bank] {len(self.manifest)} samples disponibles — mapping : {src}")
            for role in ROLES:
                e = self.map.get(role)
                if e:
                    print(f"  {role:8s} <- {e['file']}  note={e.get('base_note', 60)} "
                          f"rate={e.get('sample_rate', SR)} "
                          f"{'boucle' if e.get('looped') else 'one-shot'}")

    def _load(self, entry: dict) -> tuple[np.ndarray, int]:
        key = entry["file"]
        if key not in self._cache:
            self._cache[key] = read_wav_mono(os.path.join(self.path, key))
        return self._cache[key]

    def render(self, role: str, freq: float, dur: float) -> np.ndarray:
        """Rejoue le sample du role a la hauteur demandee, sur la duree demandee."""
        entry = self.map.get(role)
        n = int(dur * SR)
        if not entry or n <= 0:
            return np.zeros(max(0, n))
        data, file_rate = self._load(entry)
        if len(data) < 2:
            return np.zeros(n)

        rate = entry.get("sample_rate") or file_rate
        base = midi_hz(entry.get("base_note", 60))
        step = (rate / SR) * (freq / max(base, 1e-6))     # transposition + reechantillonnage

        env_cfg = ENVELOPES.get(role, ENVELOPES["bell"])
        pos = np.arange(n, dtype=np.float64) * step

        loop_start = int(entry.get("loop_start", 0))
        loop_len = int(entry.get("loop_length", 0))
        if env_cfg["loop"] and loop_len > 1 and loop_start + loop_len <= len(data):
            loop_end = loop_start + loop_len
            over = pos >= loop_end
            pos = np.where(over, loop_start + np.mod(pos - loop_start, loop_len), pos)
        else:
            # one-shot : on laisse mourir le sample, silence ensuite
            pos = np.clip(pos, 0, len(data) - 1.001)

        i0 = pos.astype(np.int64)
        frac = pos - i0
        i1 = np.minimum(i0 + 1, len(data) - 1)
        sig = data[i0] * (1.0 - frac) + data[i1] * frac      # interpolation lineaire

        if not (env_cfg["loop"] and loop_len > 1):
            played = np.arange(n, dtype=np.float64) * step
            sig = np.where(played >= len(data) - 1, 0.0, sig)

        return sig * _adsr(n, env_cfg["a"], env_cfg["d"], env_cfg["s"], env_cfg["r"])


# ═══════════════════════════════════════════════════════════════════════════════

def selftest() -> int:
    """Valide le chemin echantillonne sur une banque fabriquee a la volee."""
    import tempfile
    print("── autotest de la banque ──")
    ok = True
    with tempfile.TemporaryDirectory() as td:
        manifest = []
        specs = [("loop_a", 60, 22050, 8000, True), ("loop_b", 43, 16000, 6000, True),
                 ("hit_a", 40, 22050, 3000, False), ("hit_b", 74, 32000, 9000, False)]
        for name, note, rate, n, looped in specs:
            t = np.arange(n) / rate
            x = np.sin(2 * np.pi * midi_hz(note) * t) * (1.0 if looped else np.exp(-t * 6))
            p = os.path.join(td, f"{name}.wav")
            with wave.open(p, "wb") as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
                w.writeframes((x * 20000).astype("<i2").tobytes())
            manifest.append({"file": f"{name}.wav", "base_note": note, "sample_rate": rate,
                             "num_samples": n, "looped": looped,
                             "loop_start": n // 4 if looped else 0,
                             "loop_length": n // 2 if looped else 0,
                             "duration_s": round(n / rate, 4)})
        with open(os.path.join(td, "manifest.json"), "w") as fh:
            json.dump(manifest, fh)

        bank = SampleBank(td)
        if not os.path.exists(os.path.join(td, "palette_map.json")):
            print("  ECHEC : palette_map.json non genere"); ok = False

        for role in ROLES:
            for freq, dur in ((110.0, 3.0), (440.0, 0.8), (880.0, 6.0)):
                y = bank.render(role, freq, dur)
                exp = int(dur * SR)
                if len(y) != exp:
                    print(f"  ECHEC {role} {freq}Hz : {len(y)} ech. au lieu de {exp}")
                    ok = False; continue
                if not np.all(np.isfinite(y)):
                    print(f"  ECHEC {role} : valeurs non finies"); ok = False; continue
                if np.abs(y).max() > 1.5:
                    print(f"  ECHEC {role} : crete {np.abs(y).max():.2f}"); ok = False

        # une note tenue au-dela de la longueur du sample doit rester sonore si bouclee
        long_pad = bank.render("pad_fm", 220.0, 9.0)
        tail = long_pad[int(7.0 * SR):int(8.0 * SR)]
        rms_tail = float(np.sqrt((tail ** 2).mean()))
        print(f"  nappe bouclee 9 s : RMS de la queue a 7-8 s = {rms_tail:.4f}")
        if rms_tail < 1e-3:
            print("  ECHEC : la boucle ne tient pas la note"); ok = False

        # un one-shot doit s'eteindre, pas se repeter
        hit = bank.render("taiko", 82.0, 4.0)
        late = hit[int(3.0 * SR):]
        print(f"  one-shot 4 s : RMS apres 3 s = {float(np.sqrt((late**2).mean())):.5f}")
        if float(np.sqrt((late ** 2).mean())) > 5e-3:
            print("  ECHEC : le one-shot boucle alors qu'il ne devrait pas"); ok = False

        # transposition : l'octave doit doubler la frequence lue
        a = bank.render("whistle", 220.0, 1.0)
        b = bank.render("whistle", 440.0, 1.0)
        fa = np.argmax(np.abs(np.fft.rfft(a * np.hanning(len(a)))))
        fb = np.argmax(np.abs(np.fft.rfft(b * np.hanning(len(b)))))
        ratio = fb / max(fa, 1)
        print(f"  transposition octave : rapport des pics = {ratio:.2f} (attendu ~2)")
        if not (1.7 < ratio < 2.3):
            print("  ECHEC : la transposition ne suit pas la hauteur demandee"); ok = False

    print("── AUTOTEST OK ──" if ok else "── AUTOTEST EN ECHEC ──")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(selftest())


# ═══════════════════════════════════════════════════════════════════════════════
# BANQUE MULTI-ECHANTILLONS — instruments reellement enregistres
# ═══════════════════════════════════════════════════════════════════════════════

class MultiSampleBank:
    """Un enregistrement par note, et non un seul sample transpose partout.

    C'est LA difference qui fait qu'un violon reste un violon. Transposer un
    echantillon d'une octave deplace ses formants avec la hauteur : la caisse
    de resonance semble changer de taille, et l'oreille entend immediatement
    l'artifice. Ici chaque note demandee va chercher l'enregistrement le plus
    proche et ne se transpose que de quelques demi-tons.

    Manifeste attendu : `kind: multisample`, entrees portant `instrument`,
    `base_note`, `sample_rate`, `loop_start`, `loop_length`.
    """

    # Enveloppes appliquees par-dessus l'echantillon. Volontairement discretes :
    # l'attaque et le corps sont deja dans l'enregistrement, on ne fait que
    # gerer la duree demandee et la fin de note.
    ENV = {
        "sustained": dict(a=0.06, d=0.10, s=0.94, r=0.45),
        "plucked":   dict(a=0.001, d=0.02, s=0.97, r=0.25),
        "struck":    dict(a=0.001, d=0.0, s=1.0, r=0.10),
    }
    KIND = {
        "harp": "plucked", "celtic_guitar": "plucked", "pizzicato": "plucked",
        "glockenspiel": "struck", "celesta": "struck", "celesta_bell": "struck",
        "timpani": "struck", "taiko": "struck", "bodhran": "struck",
        "cymbal": "struck", "tam_tam": "struck", "snare_roll": "struck",
    }

    def __init__(self, path: str, verbose: bool = True):
        self.path = path
        with open(os.path.join(path, "manifest.json"), encoding="utf-8") as fh:
            man = json.load(fh)
        self.libraries = man.get("libraries", [])
        self.gains = man.get("gains", {})
        self.by_inst: dict[str, list[dict]] = {}
        for e in man.get("samples", []):
            self.by_inst.setdefault(e["instrument"], []).append(e)
        for lst in self.by_inst.values():
            lst.sort(key=lambda e: e["base_note"])
        self._cache: dict[str, tuple[np.ndarray, int]] = {}
        if verbose:
            print(f"[samples] {len(self.by_inst)} instruments reels, "
                  f"{man.get('sample_count', 0)} echantillons — "
                  + ", ".join(lib["license"] for lib in self.libraries))

    def has(self, inst: str) -> bool:
        return inst in self.by_inst

    def _pick(self, inst: str, midi: float) -> dict:
        lst = self.by_inst[inst]
        return min(lst, key=lambda e: abs(e["base_note"] - midi))

    def _load(self, entry: dict) -> tuple[np.ndarray, int]:
        key = entry["file"]
        if key not in self._cache:
            self._cache[key] = read_wav_mono(os.path.join(self.path, key))
        return self._cache[key]

    def render(self, inst: str, midi: float, dur: float, vel: float = 0.7) -> np.ndarray:
        n = int(dur * SR)
        if n <= 0 or inst not in self.by_inst:
            return np.zeros(max(0, n))
        entry = self._pick(inst, midi)
        data, file_rate = self._load(entry)
        if len(data) < 2:
            return np.zeros(n)

        rate = entry.get("sample_rate") or file_rate
        semis = midi - entry["base_note"]
        step = (rate / SR) * (2.0 ** (semis / 12.0))

        kind = self.KIND.get(inst, "sustained")
        cfg = self.ENV[kind]
        pos = np.arange(n, dtype=np.float64) * step
        ls, ll = int(entry.get("loop_start", 0)), int(entry.get("loop_length", 0))
        if entry.get("looped") and ll > 1 and ls + ll <= len(data):
            over = pos >= ls + ll
            pos = np.where(over, ls + np.mod(pos - ls, ll), pos)
        else:
            pos = np.clip(pos, 0, len(data) - 1.001)

        i0 = pos.astype(np.int64)
        frac = pos - i0
        i1 = np.minimum(i0 + 1, len(data) - 1)
        sig = data[i0] * (1.0 - frac) + data[i1] * frac
        if not (entry.get("looped") and ll > 1):
            played = np.arange(n, dtype=np.float64) * step
            sig = np.where(played >= len(data) - 1, 0.0, sig)

        # la velocite ouvre legerement le spectre, comme sur un vrai instrument
        if kind == "sustained" and vel < 0.75:
            sig = _soft_lowpass(sig, 2200.0 + 9000.0 * vel)
        g = self.gains.get(inst, 1.0)
        return sig * _adsr(n, cfg["a"], cfg["d"], cfg["s"], cfg["r"]) * (0.35 + 0.65 * vel) * g


def _soft_lowpass(x: np.ndarray, fc: float) -> np.ndarray:
    n = len(x)
    if n < 32:
        return x
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    return np.fft.irfft(spec / (1.0 + (f / max(fc, 1.0)) ** 2), n)
