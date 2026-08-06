#!/usr/bin/env python3
"""Etage MusyX — fait subir a une banque d'echantillons ce que la GameCube
faisait subir aux siens.

Une part reelle de la signature sonore des jeux MusyX ne tient pas aux
instruments mais a la machine : tout echantillon etait stocke en DSP-ADPCM
4 bits, a des frequences basses imposees par la memoire. Le codec introduit
environ 24 dB de rapport signal/bruit et comprime a ~29 % du PCM ; la frequence
reduite adoucit l'aigu. C'est un grain, et il s'entend.

Cet etage n'utilise AUCUNE donnee externe : il applique le codec de la console
a nos propres echantillons CC0.

    signal 48 kHz --> reechantillonnage 22,05 kHz --> ADPCM --> decodage
                  --> retour a 48 kHz

Usage :
    python3 tools/audio/musyx_stage.py --in samples/ --out samples_musyx/
    python3 tools/audio/musyx_stage.py --selftest
"""
from __future__ import annotations

import argparse
import os
import sys
import wave
from concurrent.futures import ProcessPoolExecutor

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from musyx_extract import dsp_decode  # noqa: E402

# Jeu de coefficients ADPCM. Sur la console ils sont calcules par sample et
# ranges dans la table B du SDIR ; ici on prend un jeu representatif, ce qui
# suffit pour le grain — c'est la quantification 4 bits qui s'entend, pas le
# choix fin du predicteur.
COEFS = [1820, -856, 3238, -1514, 2333, -550, 3336, -1287,
         2895, -1180, 1400, -400, 2700, -900, 3000, -1100]

MUSYX_RATE = 22050          # frequence d'epoque typique d'une banque MusyX


def dsp_encode_fast(samples: np.ndarray, coefs: list[int]) -> bytes:
    """Encodeur DSP-ADPCM utilisable en production.

    L'encodeur de reference (musyx_extract) balaie 8 predicteurs x 16 echelles
    par trame, soit 128 passages : mesure a 7,7 k echantillons/s, ce qui donnait
    580 minutes pour une banque de 765 fichiers. Un encodeur reel ne CHERCHE pas
    l'echelle, il la CALCULE a partir du residu maximal de la trame. On tombe a
    8 passages, et le flux produit reste un flux DSP-ADPCM valide que le
    decodeur de reference relit sans modification.

    Le format est inchange : trames de 8 octets, un octet d'entete
    (predicteur << 4 | echelle) puis 14 quartets."""
    out = bytearray()
    hist1 = hist2 = 0
    n = len(samples)
    for start in range(0, n, 14):
        block = samples[start:start + 14]
        best = None
        for c_idx in range(8):
            c1, c2 = coefs[c_idx * 2], coefs[c_idx * 2 + 1]

            # 1. residus en boucle ouverte -> echelle necessaire. Un quartet
            #    signe couvre -8..7, d'ou la division par 8.
            h1, h2 = hist1, hist2
            peak = 0
            for s in block:
                pred = (1024 + c1 * h1 + c2 * h2) >> 11
                peak = max(peak, abs(int(s) - pred))
                h2, h1 = h1, int(s)
            sc = 0
            while sc < 15 and (peak >> sc) > 7:
                sc += 1

            # 2. boucle fermee a cette echelle : l'historique repart du signal
            #    RECONSTRUIT, sans quoi l'erreur derive sur les trames tenues.
            for attempt in range(2):
                scale = 1 << sc
                h1, h2 = hist1, hist2
                nibs, err, clipped = [], 0, False
                for s in block:
                    pred = 1024 + c1 * h1 + c2 * h2
                    target = ((int(s) << 11) - pred) / (scale << 11)
                    nib = int(round(target))
                    if nib < -8 or nib > 7:
                        clipped = True
                        nib = max(-8, min(7, nib))
                    val = (((nib * scale) << 11) + pred) >> 11
                    val = max(-32768, min(32767, val))
                    err += (val - int(s)) ** 2
                    nibs.append(nib & 0x0F)
                    h2, h1 = h1, val
                if not clipped or sc >= 15:
                    break
                sc += 1                      # une seule remontee suffit en pratique
            if best is None or err < best[0]:
                best = (err, c_idx, sc, nibs, h1, h2)

        _err, c_idx, sc, nibs, h1, h2 = best
        while len(nibs) < 14:
            nibs.append(0)
        out.append((c_idx << 4) | sc)
        for i in range(0, 14, 2):
            out.append((nibs[i] << 4) | nibs[i + 1])
        hist1, hist2 = h1, h2
    return bytes(out)


def resample(x: np.ndarray, n_out: int) -> np.ndarray:
    """Reechantillonnage par le spectre. Pas de scipy sur cette machine, et
    l'interpolation lineaire ajouterait son propre repliement — on ne veut que
    celui de la console, pas celui de l'outil."""
    n_in = len(x)
    if n_in == n_out or n_in == 0:
        return x.astype(np.float64)
    spec = np.fft.rfft(x.astype(np.float64))
    keep = min(len(spec), n_out // 2 + 1)
    out = np.zeros(n_out // 2 + 1, dtype=complex)
    out[:keep] = spec[:keep]
    return np.fft.irfft(out, n_out) * (n_out / n_in)


def musyx_pass(pcm: np.ndarray, sr: int, rate: int = MUSYX_RATE) -> np.ndarray:
    """48 kHz -> frequence d'epoque -> ADPCM -> decodage -> 48 kHz."""
    if len(pcm) < 32:
        return pcm
    n_low = max(16, int(round(len(pcm) * rate / sr)))
    low = resample(pcm, n_low)
    low = np.clip(np.round(low), -32768, 32767).astype(np.int32)
    dec = np.asarray(dsp_decode(dsp_encode_fast(low, COEFS), len(low), COEFS),
                     dtype=np.float64)
    back = resample(dec, len(pcm))
    return np.clip(np.round(back), -32768, 32767).astype(np.int16)


def _read(path: str) -> tuple[np.ndarray, int, int]:
    with wave.open(path) as w:
        sr, ch, n = w.getframerate(), w.getnchannels(), w.getnframes()
        pcm = np.frombuffer(w.readframes(n), dtype="<i2")
    return (pcm.reshape(-1, ch) if ch > 1 else pcm.reshape(-1, 1)), sr, ch


def _write(path: str, data: np.ndarray, sr: int, ch: int) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(ch); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(data.astype("<i2").tobytes())


def _job(args: tuple[str, str, int]) -> tuple[str, float]:
    src, dst, rate = args
    pcm, sr, ch = _read(src)
    out = np.empty_like(pcm)
    for c in range(ch):
        out[:, c] = musyx_pass(pcm[:, c], sr, rate)
    _write(dst, out.reshape(-1) if ch == 1 else out, sr, ch)
    a = pcm.astype(np.float64).mean(1); b = out.astype(np.float64).mean(1)
    err = ((a - b) ** 2).mean()
    snr = 10 * np.log10(max((a ** 2).mean(), 1e-9) / max(err, 1e-9))
    return os.path.basename(src), float(snr)


def selftest() -> int:
    print("── autotest de l'etage MusyX ──")
    ok = True
    t = np.array([int(11000 * np.sin(2 * np.pi * 300 * i / 22050)) for i in range(2800)],
                 dtype=np.int32)

    # 1. le flux rapide doit etre relu par le decodeur de reference
    dec = np.asarray(dsp_decode(dsp_encode_fast(t, COEFS), len(t), COEFS), dtype=float)
    snr = 10 * np.log10((t ** 2).mean() / max(((t - dec) ** 2).mean(), 1e-9))
    print(f"  encodeur rapide -> decodeur de reference : SNR {snr:.1f} dB")
    if snr < 20:
        print("  ECHEC : flux invalide ou trop bruite"); ok = False

    # 2. comparaison avec l'encodeur exhaustif de reference
    from musyx_extract import dsp_encode as ref_encode
    ref = np.asarray(dsp_decode(ref_encode(list(map(int, t)), COEFS), len(t), COEFS),
                     dtype=float)
    snr_ref = 10 * np.log10((t ** 2).mean() / max(((t - ref) ** 2).mean(), 1e-9))
    print(f"  encodeur de reference (exhaustif)        : SNR {snr_ref:.1f} dB")
    print(f"  ecart : {snr - snr_ref:+.1f} dB")
    if snr < snr_ref - 6:
        print("  ECHEC : l'encodeur rapide degrade trop"); ok = False

    # 3. l'etage complet doit assombrir l'aigu, c'est tout son interet
    pcm = (np.random.default_rng(7).normal(0, 4000, 20000)).astype(np.int16)
    out = musyx_pass(pcm, 48000)
    def hf(x):
        S = np.abs(np.fft.rfft(x.astype(float))); f = np.fft.rfftfreq(len(x), 1/48000)
        return S[f > 11025].sum() / max(S.sum(), 1e-9)
    print(f"  energie au-dessus de 11 kHz : {hf(pcm)*100:.1f} % -> {hf(out)*100:.1f} %")
    if hf(out) >= hf(pcm):
        print("  ECHEC : la bande haute n'a pas ete coupee"); ok = False

    print("── AUTOTEST OK ──" if ok else "── AUTOTEST EN ECHEC ──")
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src")
    ap.add_argument("--out", dest="dst")
    ap.add_argument("--rate", type=int, default=MUSYX_RATE)
    ap.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if not a.src or not a.dst:
        print("--in et --out requis", file=sys.stderr); return 1

    jobs = []
    for root, _d, files in os.walk(a.src):
        for f in files:
            if f.lower().endswith(".wav"):
                s = os.path.join(root, f)
                jobs.append((s, os.path.join(a.dst, os.path.relpath(s, a.src)), a.rate))
    # les fichiers non-WAV (licences, manifestes) sont copies tels quels
    import shutil
    for root, _d, files in os.walk(a.src):
        for f in files:
            if not f.lower().endswith(".wav"):
                s = os.path.join(root, f)
                d = os.path.join(a.dst, os.path.relpath(s, a.src))
                os.makedirs(os.path.dirname(d), exist_ok=True); shutil.copy2(s, d)

    print(f"[musyx] {len(jobs)} echantillons -> {a.rate} Hz + ADPCM, "
          f"{a.workers} processus")
    snrs, done = [], 0
    with ProcessPoolExecutor(max_workers=a.workers) as ex:
        for name, snr in ex.map(_job, jobs, chunksize=4):
            snrs.append(snr); done += 1
            if done % 50 == 0:
                print(f"      {done}/{len(jobs)}  SNR median "
                      f"{np.median(snrs):.1f} dB", flush=True)
    print(f"[musyx] termine — {done} fichiers, SNR median {np.median(snrs):.1f} dB "
          f"(min {min(snrs):.1f}, max {max(snrs):.1f})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
