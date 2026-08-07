#!/usr/bin/env python3
"""Banque hybride : Virtual Playing Orchestra pour le coeur orchestral,
banque VSCO/VCSL existante pour les instruments folk.

POURQUOI VPO. Les memes sources brutes (VSCO2-CE, Sonatina, Iowa, NoBudgetOrch)
mais preparees par un tiers qui a fait le travail que notre constructeur ne
faisait pas : sustains BOUCLES (chunk smpl dans les WAV), zones de clavier
cartographiees, accord corrige au cent (opcode tune), articulations separees.
Nos tenues VSCO brutes s'eteignaient au bout de l'enregistrement ; celles de
VPO tiennent aussi longtemps que la partition le demande.

CE QUE VPO NE COUVRE PAS : guitare celtique, oud, dan tranh, kalimba,
psalterion, ocarina, harmonica, verres, clochettes, bodhran, didgeridoo...
Tous ces instruments restent copies de la banque existante — c'est une fusion,
pas un remplacement.

Licence VPO : libre y compris usage commercial ; redistribution avec
attribution (sources CC0 / CC-BY-SA / Sampling Plus). https://virtualplaying.com

Usage :
    python3 tools/audio/build_vpo_bank.py --vpo <dossier VPO3> \\
        --base <banque existante> --out <banque hybride>
    python3 tools/audio/build_vpo_bank.py --selftest
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import struct
import sys

import numpy as np

# ── quels instruments viennent de VPO ────────────────────────────────────────
# nom moteur -> script sfz. Sustain partout ou le socle tient des notes ;
# accent pour les coups de cuivres ; pizzicato/tremolo pour leurs pupitres.
VPO_MAP = {
    "strings_high":    "Strings/1st-violin-SEC-sustain.sfz",
    "strings_mid":     "Strings/viola-SEC-sustain.sfz",
    "strings_low":     "Strings/cello-SEC-sustain.sfz",
    "contrabass":      "Strings/bass-SEC-sustain.sfz",
    "strings_tremolo": "Strings/1st-violin-SEC-tremolo.sfz",
    "pizzicato":       "Strings/all-strings-SEC-pizzicato.sfz",
    "violin_solo":     "Strings/1st-violin-SOLO-sustain.sfz",
    "viola":           "Strings/viola-SOLO-sustain.sfz",
    "harp":            "Strings/harp-sustain.sfz",
    "flute":           "Woodwinds/flute-SOLO-sustain.sfz",
    "piccolo":         "Woodwinds/piccolo-SOLO-sustain.sfz",
    "oboe":            "Woodwinds/oboe-SOLO-sustain.sfz",
    "cor_anglais":     "Woodwinds/english-horn-SOLO-sustain.sfz",
    "clarinet":        "Woodwinds/clarinet-SOLO-sustain.sfz",
    "bassoon":         "Woodwinds/bassoon-SOLO-sustain.sfz",
    "horn":            "Brass/french-horn-SEC-sustain.sfz",
    "trumpet":         "Brass/trumpet-SOLO-sustain.sfz",
    "trombone":        "Brass/trombone-SEC-sustain.sfz",
    "tuba":            "Brass/tuba-SOLO-sustain.sfz",
    "brass_ff":        "Brass/all-brass-SEC-accent.sfz",
    "timpani":         "Percussion/timpani-hit.sfz",
    "glockenspiel":    "Percussion/glockenspiel.sfz",
    "celesta":         "Keys/celesta.sfz",
}

# Cibles de calibration — MEMES valeurs que build_sample_bank.py, pour que les
# instruments VPO tombent au meme niveau percu que les folk conserves.
TARGET = {
    "strings_high": -13.0, "strings_mid": -15.0, "strings_low": -15.0,
    "strings_tremolo": -15.5, "viola": -15.0, "contrabass": -16.0,
    "violin_solo": -11.0, "pizzicato": -16.0,
    "horn": -15.0, "brass_ff": -13.0, "trumpet": -12.5, "trombone": -14.0,
    "tuba": -15.0, "flute": -9.5, "piccolo": -11.0, "oboe": -9.5,
    "cor_anglais": -11.0, "clarinet": -13.0, "bassoon": -14.5,
    "harp": -15.0, "glockenspiel": -14.0, "celesta": -14.0, "timpani": -13.5,
}

VPO_LIBS = [
    {"name": "Virtual Playing Orchestra 3", "author": "Paul Battersby",
     "license": "libre (sources CC0 / CC-BY-SA / Sampling Plus)",
     "url": "https://virtualplaying.com/virtual-playing-orchestra/"},
]


# ═══════════════════════════════════════════════════════════════════════════════
# SFZ — le sous-ensemble dont VPO a besoin
# ═══════════════════════════════════════════════════════════════════════════════

_NOTE = re.compile(r"^([a-gA-G])([#b]?)(-?\d+)$")
_SEMI = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}


def note_to_midi(v: str) -> float:
    """'g3' -> 55. Convention SFZ : do central = c4 = 60."""
    m = _NOTE.match(v.strip())
    if not m:
        return float(v)                      # deja numerique
    letter, acc, octave = m.groups()
    n = _SEMI[letter.lower()] + (1 if acc == "#" else -1 if acc == "b" else 0)
    return float(n + (int(octave) + 1) * 12)


# Un opcode vaut tout ce qui suit '=' jusqu'au prochain 'mot=' — les chemins de
# samples contiennent des espaces ("1st Violins"), on ne peut pas couper aux
# blancs.
_OPCODE = re.compile(r"([A-Za-z0-9_]+)=((?:(?!\s+[A-Za-z0-9_]+=).)*)")


def parse_sfz(path: str) -> list[dict]:
    """Retourne les regions, heritage <global>/<group> applique."""
    scopes = {"global": {}, "group": {}, "control": {}}
    current = None
    regions: list[dict] = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            line = raw.split("//")[0].strip()
            if not line:
                continue
            pos = 0
            for header in re.finditer(r"<(\w+)>", line):
                # opcodes entre l'entete precedente et celle-ci
                seg = line[pos:header.start()]
                _apply(seg, scopes, current, regions)
                tag = header.group(1)
                if tag == "control":
                    current = "control"
                elif tag == "global":
                    scopes["global"] = {}; scopes["group"] = {}; current = "global"
                elif tag == "group":
                    scopes["group"] = {}; current = "group"
                elif tag == "region":
                    regions.append(dict(scopes["global"], **scopes["group"]))
                    current = "region"
                else:
                    current = None           # <curve>, <effect>... ignores
                pos = header.end()
            _apply(line[pos:], scopes, current, regions)
    for r in regions:
        r.setdefault("_default_path", scopes["control"].get("default_path", ""))
    return regions


def _apply(segment: str, scopes: dict, current: str | None, regions: list) -> None:
    for k, v in _OPCODE.findall(segment):
        v = v.strip()
        if current == "region" and regions:
            regions[-1][k] = v
        elif current in ("group", "global", "control"):
            scopes[current][k] = v


def region_zones(regions: list[dict], default_path: str = "") -> list[dict]:
    """Regions -> zones exploitables : note de base effective, bornes, couche."""
    zones = []
    for r in regions:
        if "sample" not in r:
            continue
        # les regions conditionnees a un controleur (molette) ou declenchees au
        # relachement ne correspondent a rien dans notre moteur
        if r.get("trigger", "attack") != "attack":
            continue
        if any(k.startswith("locc") and float(r[k]) > 0 for k in r):
            continue
        key = r.get("key")
        lo = note_to_midi(r.get("lokey", key or "c-1"))
        hi = note_to_midi(r.get("hikey", key or "g9"))
        center = note_to_midi(r.get("pitch_keycenter", key or r.get("lokey", "c4")))
        tune = float(r.get("tune", 0.0))
        # L'opcode tune corrige un enregistrement faux de quelques cents : le
        # lecteur doit jouer tune cents plus haut/bas. Dans notre moteur la
        # transposition vaut midi - base_note : on encaisse la correction dans
        # une note de base FRACTIONNAIRE (base' = centre - tune/100).
        zones.append({
            "sample": (default_path + r["sample"]).replace("\\", "/"),
            "lokey": lo, "hikey": hi,
            "base_note": center - tune / 100.0,
            "volume_db": float(r.get("volume", 0.0)),
            "lovel": int(float(r.get("lovel", 0))),
            "seq": int(float(r.get("seq_position", 1))),
        })
    return zones


# ═══════════════════════════════════════════════════════════════════════════════
# WAV — lecture (16/24/32 bits + flottant), boucle smpl, ecriture mono 16 bits
# ═══════════════════════════════════════════════════════════════════════════════

def read_wav_full(path: str) -> tuple[np.ndarray, int, tuple[int, int] | None]:
    """(mono float -1..1, frequence, boucle (debut, longueur) ou None)."""
    d = open(path, "rb").read()
    if d[:4] != b"RIFF" or d[8:12] != b"WAVE":
        raise ValueError(f"pas un WAV : {path}")
    fmt = None; data = None; loop = None
    i = 12
    while i + 8 <= len(d):
        cid = d[i:i + 4]; sz = struct.unpack("<I", d[i + 4:i + 8])[0]
        body = d[i + 8:i + 8 + sz]
        if cid == b"fmt ":
            tag, ch, rate = struct.unpack("<HHI", body[:8])
            bits = struct.unpack("<H", body[14:16])[0]
            fmt = (tag, ch, rate, bits)
        elif cid == b"data":
            data = body
        elif cid == b"smpl" and len(body) >= 60:
            n_loops = struct.unpack("<I", body[28:32])[0]
            if n_loops >= 1:
                st, en = struct.unpack("<II", body[44:52])
                # smpl : 'en' est la DERNIERE frame incluse dans la boucle
                loop = (int(st), int(en) - int(st) + 1)
        i += 8 + sz + (sz & 1)
    if fmt is None or data is None:
        raise ValueError(f"WAV incomplet : {path}")
    tag, ch, rate, bits = fmt
    if tag == 3 or bits == 32 and tag == 3:
        x = np.frombuffer(data, dtype="<f4").astype(np.float64)
    elif bits == 16:
        x = np.frombuffer(data, dtype="<i2").astype(np.float64) / 32768.0
    elif bits == 24:
        b = np.frombuffer(data, dtype=np.uint8)
        b = b[: (len(b) // 3) * 3].reshape(-1, 3)
        x = ((b[:, 0].astype(np.int32)) | (b[:, 1].astype(np.int32) << 8)
             | (b[:, 2].astype(np.int32) << 16))
        x = np.where(x >= 1 << 23, x - (1 << 24), x).astype(np.float64) / (1 << 23)
    elif bits == 32:
        x = np.frombuffer(data, dtype="<i4").astype(np.float64) / (1 << 31)
    else:
        raise ValueError(f"{bits} bits non gere : {path}")
    if ch > 1:
        x = x[: (len(x) // ch) * ch].reshape(-1, ch).mean(1)
    return x, rate, loop


def write_wav_mono16(path: str, x: np.ndarray, rate: int,
                     loop: tuple[int, int] | None) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2").tobytes()
    chunks = [b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, rate, rate * 2, 2, 16),
              b"data" + struct.pack("<I", len(pcm)) + pcm + (b"\x00" if len(pcm) & 1 else b"")]
    if loop:
        st, ln = loop
        smpl = struct.pack("<9I", 0, 0, int(1e9 / rate), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, st, st + ln - 1, 0, 0)
        chunks.append(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
    body = b"WAVE" + b"".join(chunks)
    with open(path, "wb") as fh:
        fh.write(b"RIFF" + struct.pack("<I", len(body)) + body)


# ═══════════════════════════════════════════════════════════════════════════════
# CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════════════

def build_instrument(inst: str, sfz_path: str, vpo_root: str,
                     out_dir: str) -> list[dict]:
    regions = parse_sfz(sfz_path)
    dp = regions[0].get("_default_path", "") if regions else ""
    zones = region_zones(regions, dp)
    if not zones:
        raise ValueError(f"{sfz_path} : aucune zone exploitable")
    # couche de velocite : ordre des lovel puis des round-robins dans une zone
    by_zone: dict[tuple, list[dict]] = {}
    for z in zones:
        by_zone.setdefault((z["lokey"], z["hikey"]), []).append(z)
    entries = []
    for _k, zs in sorted(by_zone.items()):
        zs.sort(key=lambda z: (z["lovel"], z["seq"]))
        for vi, z in enumerate(zs, start=1):
            src = os.path.normpath(os.path.join(os.path.dirname(sfz_path), z["sample"]))
            x, rate, loop = read_wav_full(src)
            if z["volume_db"]:
                x = x * (10 ** (z["volume_db"] / 20.0))
            note = int(round(z["base_note"]))
            rel = f"{inst}/{inst}_{note:03d}_v{vi}.wav"
            if loop and loop[0] + loop[1] > len(x):
                loop = None                          # boucle hors du fichier : on jette
            write_wav_mono16(os.path.join(out_dir, rel), x, rate, loop)
            e = {"file": rel, "instrument": inst, "group": "vpo",
                 "base_note": round(z["base_note"], 3), "velocity": vi,
                 "sample_rate": rate, "num_samples": len(x),
                 "looped": bool(loop), "duration_s": round(len(x) / rate, 4),
                 "format": 1,
                 "source_file": os.path.relpath(src, vpo_root)}
            if loop:
                e["loop_start"], e["loop_length"] = int(loop[0]), int(loop[1])
            entries.append(e)
    return entries


def calibrate(entries: list[dict], out_dir: str) -> float:
    """Meme regle que build_sample_bank : RMS de la fenetre de 200 ms la plus
    forte, mesuree sur un echantillon median, ramenee a la cible."""
    inst = entries[0]["instrument"]
    mid = entries[len(entries) // 2]
    x, rate, _l = read_wav_full(os.path.join(out_dir, mid["file"]))
    w = int(0.2 * rate)
    if len(x) > w:
        e = np.convolve(x ** 2, np.ones(w) / w, mode="valid")
        lvl = 20 * np.log10(np.sqrt(e.max()) + 1e-12)
    else:
        lvl = 20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-12)
    return round(float(10 ** ((TARGET.get(inst, -14.0) - lvl) / 20.0)), 4)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--vpo"); ap.add_argument("--base"); ap.add_argument("--out")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if not (a.vpo and a.base and a.out):
        print("--vpo, --base et --out requis", file=sys.stderr); return 1

    with open(os.path.join(a.base, "manifest.json"), encoding="utf-8") as fh:
        base_man = json.load(fh)

    os.makedirs(a.out, exist_ok=True)
    samples: list[dict] = []
    gains: dict[str, float] = {}

    # 1. instruments VPO
    for inst, rel in sorted(VPO_MAP.items()):
        sfz = os.path.join(a.vpo, rel)
        entries = build_instrument(inst, sfz, a.vpo, a.out)
        gains[inst] = calibrate(entries, a.out)
        samples.extend(entries)
        looped = sum(1 for e in entries if e["looped"])
        print(f"  vpo   {inst:16s} {len(entries):3d} zones, {looped:3d} bouclees "
              f"— {os.path.basename(rel)}")

    # 2. instruments folk conserves de la banque existante
    kept = 0
    for e in base_man["samples"]:
        if e["instrument"] in VPO_MAP:
            continue
        src = os.path.join(a.base, e["file"])
        dst = os.path.join(a.out, e["file"])
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if not os.path.exists(dst):
            try:
                os.link(src, dst)
            except OSError:
                shutil.copy2(src, dst)
        samples.append(e)
        kept += 1
    for inst, g in base_man.get("gains", {}).items():
        if inst not in VPO_MAP:
            gains[inst] = g
    print(f"  base  {kept} echantillons folk conserves")

    insts = sorted({e["instrument"] for e in samples})
    manifest = {
        "kind": "multisample",
        "gains": gains,
        "libraries": base_man.get("libraries", []) + VPO_LIBS,
        "instrument_count": len(insts),
        "sample_count": len(samples),
        "per_instrument": {i: sum(1 for e in samples if e["instrument"] == i)
                           for i in insts},
        "samples": samples,
    }
    with open(os.path.join(a.out, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=1, ensure_ascii=False)
    total_looped = sum(1 for e in samples if e.get("looped"))
    print(f"[vpo-bank] {len(samples)} echantillons, {len(insts)} instruments, "
          f"{total_looped} boucles — {a.out}")
    return 0


def selftest() -> int:
    print("── autotest du parseur SFZ ──")
    ok = True
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        sfz = os.path.join(td, "t.sfz")
        open(sfz, "w").write("""
<group>
ampeg_attack=0.4
tune=-10
<region>
sample=sub dir\\my sample.wav
lokey=g3 hikey=g#3 pitch_keycenter=g3
<region>
sample=x.wav
key=c4
lovel=64 hivel=127
// commentaire <region> piege
<region>
sample=y.wav
lokey=36 hikey=39 pitch_keycenter=37 tune=25
""")
        zs = region_zones(parse_sfz(sfz))
        checks = [
            (len(zs) == 3, f"3 zones attendues, {len(zs)}"),
            (zs[0]["sample"] == "sub dir/my sample.wav", f"chemin: {zs[0]['sample']}"),
            (abs(zs[0]["base_note"] - 55.1) < 1e-6,
             f"tune -10 herite du groupe: {zs[0]['base_note']}"),
            (zs[1]["lokey"] == 60 and zs[1]["hikey"] == 60,
             f"key= : {zs[1]['lokey']}..{zs[1]['hikey']}"),
            (zs[1]["lovel"] == 64, f"lovel: {zs[1]['lovel']}"),
            (abs(zs[2]["base_note"] - 36.75) < 1e-6,
             f"tune region prioritaire: {zs[2]['base_note']}"),
        ]
        for good, msg in checks:
            print(("  ok  " if good else "  ECHEC  ") + msg)
            ok &= good
        # aller-retour WAV avec boucle
        x = np.sin(np.arange(8000) * 0.05) * 0.5
        p = os.path.join(td, "loop.wav")
        write_wav_mono16(p, x, 22050, (1000, 4000))
        y, rate, loop = read_wav_full(p)
        good = rate == 22050 and loop == (1000, 4000) and abs(len(y) - 8000) == 0
        print(("  ok  " if good else "  ECHEC  ") + f"wav: rate={rate} loop={loop}")
        ok &= good
    print("── AUTOTEST OK ──" if ok else "── AUTOTEST EN ECHEC ──")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
