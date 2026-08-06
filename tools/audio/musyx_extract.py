#!/usr/bin/env python3
"""
Extracteur MusyX — Metroid Prime 1 / 2 (GameCube).

Chaine complete : ISO (GCM) -> PAK -> AGSC -> WAV + manifest.json

  ISO   : systeme de fichiers GameCube (FST a 0x424)
  PAK   : archive Retro Studios, ressources zlib
  AGSC  : 4 chunks MusyX (pool / proj / sdir / samp)
  SDIR  : table des samples (note de base, frequence, boucle, coefs ADPCM)
  SAMP  : donnees audio, DSP-ADPCM GameCube

Format d'apres la specification Retro Modding :
  https://www.metroid2002.com/retromodding/wiki/AGSC_(File_Format)

Difference MP1 / MP2, verifiee contre cette page — c'est le piege du format :
  MP1 : chaque chunk est precede de SA propre taille, taille incluse,
        et l'ordre est pool, proj, samp, sdir.
  MP2 : les quatre tailles sont en en-tete, et l'ordre est
        pool, proj, sdir, samp (sdir et samp echanges).
Lire un MP1 comme un MP2 ne leve aucune erreur : on obtient des offsets
plausibles et du bruit. L'entete MP1 est donc choisi par validation de la
table SDIR (entrees de 0x20, terminateur 0xFFFFFFFF), pas par pari.

USAGE OBLIGATOIRE : fournissez VOTRE propre copie du jeu. Cet outil ne telecharge
rien et ne contient aucune donnee appartenant a Nintendo. Les samples extraits sont
destines a l'etude et au test local — voir §5 de
docs/80_sound/30_music/MUSIC_TOOLCHAIN_PALETTE_PRIME.md.

Exemples :
    python3 tools/audio/musyx_extract.py iso   --input prime.iso  --out extract/
    python3 tools/audio/musyx_extract.py pak   --input Audio.pak  --out extract/
    python3 tools/audio/musyx_extract.py agsc  --input grp.agsc   --out extract/
    python3 tools/audio/musyx_extract.py dir   --input dossier/   --out extract/
    python3 tools/audio/musyx_extract.py selftest

Le mode `dir` accepte un dossier contenant n'importe quel melange de .iso, .pak,
.agsc, .dsp ou .wav — y compris la sortie d'un autre outil (musyx-extract de
Nisto, amuse, Prime World Editor, vgmstream). C'est le chemin le plus court
quand on a deja extrait avec autre chose.
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import math
import os
import struct
import sys
import wave
import zlib

TOOL_VERSION = "1.1.0"


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for blk in iter(lambda: fh.read(1 << 20), b""):
            h.update(blk)
    return h.hexdigest()

# ═══════════════════════════════════════════════════════════════════════════════
# DSP-ADPCM (codec GameCube)
# ═══════════════════════════════════════════════════════════════════════════════

def dsp_decode(data: bytes, n_samples: int, coefs: list[int],
               hist1: int = 0, hist2: int = 0) -> list[int]:
    """Decode le DSP-ADPCM Nintendo : trames de 8 octets -> 14 echantillons.

    Chaque trame commence par un octet d'entete : quartet bas = puissance d'echelle,
    quartet haut = index dans les 8 paires de coefficients de prediction."""
    out: list[int] = []
    n_frames = (n_samples + 13) // 14
    for f in range(n_frames):
        base = f * 8
        if base >= len(data):
            break
        header = data[base]
        scale = 1 << (header & 0x0F)
        c_idx = (header >> 4) & 0x0F
        c1 = coefs[c_idx * 2]
        c2 = coefs[c_idx * 2 + 1]
        for i in range(14):
            if len(out) >= n_samples:
                break
            byte = data[base + 1 + i // 2]
            nib = (byte >> 4) if (i % 2 == 0) else (byte & 0x0F)
            if nib >= 8:
                nib -= 16
            val = ((nib * scale) << 11) + 1024 + c1 * hist1 + c2 * hist2
            val >>= 11
            val = max(-32768, min(32767, val))
            out.append(val)
            hist2, hist1 = hist1, val
    return out


def dsp_encode(samples: list[int], coefs: list[int]) -> bytes:
    """Encodeur DSP-ADPCM minimal — sert UNIQUEMENT a fabriquer les fixtures de test.

    Recherche exhaustive (8 paires de coefs x 16 echelles) par trame. Lent et non
    optimal, mais produit un flux valide que le decodeur doit savoir relire."""
    out = bytearray()
    hist1 = hist2 = 0
    for start in range(0, len(samples), 14):
        block = samples[start:start + 14]
        best = None
        for c_idx in range(8):
            c1, c2 = coefs[c_idx * 2], coefs[c_idx * 2 + 1]
            for sc in range(16):
                scale = 1 << sc
                h1, h2 = hist1, hist2
                nibs, err = [], 0
                for s in block:
                    pred = 1024 + c1 * h1 + c2 * h2
                    target = ((s << 11) - pred) / (scale << 11)
                    nib = max(-8, min(7, int(round(target))))
                    val = ((nib * scale) << 11) + pred
                    val >>= 11
                    val = max(-32768, min(32767, val))
                    err += (val - s) ** 2
                    nibs.append(nib & 0x0F)
                    h2, h1 = h1, val
                if best is None or err < best[0]:
                    best = (err, c_idx, sc, nibs, h1, h2)
        _, c_idx, sc, nibs, hist1, hist2 = best
        while len(nibs) < 14:
            nibs.append(0)
        out.append((c_idx << 4) | sc)
        for i in range(0, 14, 2):
            out.append((nibs[i] << 4) | nibs[i + 1])
    return bytes(out)


# ═══════════════════════════════════════════════════════════════════════════════
# AGSC
# ═══════════════════════════════════════════════════════════════════════════════

SDIR_ENTRY = 0x20      # taille d'une entree table A
FMT_ADPCM, FMT_PCM16, FMT_PCM8, FMT_ADPCM2 = 0, 1, 2, 3


def _cstr(buf: bytes, pos: int) -> tuple[str, int]:
    end = buf.index(b"\x00", pos)
    return buf[pos:end].decode("ascii", "replace"), end + 1


def _plausible(buf: bytes, spans: dict) -> bool:
    """Une disposition tient-elle debout ? Bornes, tailles, et surtout la table
    SDIR : ses entrees font 0x20 octets et se terminent par 0xFFFFFFFF. C'est ce
    dernier point qui distingue vraiment une lecture juste d'un decalage."""
    n = len(buf)
    for off, sz in spans.values():
        if off < 0 or sz <= 0 or off + sz > n:
            return False
    sdir_off, sdir_sz = spans["sdir"]
    if sdir_sz < SDIR_ENTRY:
        return False
    sdir = buf[sdir_off:sdir_off + sdir_sz]
    # au moins une entree lisible, et un terminateur quelque part sur la grille
    for pos in range(0, len(sdir) - 3, SDIR_ENTRY):
        if struct.unpack_from(">I", sdir, pos)[0] == 0xFFFFFFFF:
            return pos > 0            # au moins un sample avant la fin
    return False


def _mp1_per_chunk(buf: bytes, pos: int) -> dict:
    """MP1 : chaque chunk porte sa propre taille, TAILLE INCLUSE.

    « In Metroid Prime, each chunk begins with its own size value; in Metroid
    Prime 2, every chunk instead has its size listed at the beginning of the
    file, at the end of the header. » — et « Chunk Size (note: includes the
    size value itself) ». Ordre MP1 : pool, proj, samp, sdir."""
    spans, p = {}, pos
    for tag in ("pool", "proj", "samp", "sdir"):
        (sz,) = struct.unpack_from(">I", buf, p)
        spans[tag] = (p + 4, sz - 4)
        p += sz
    return spans


def _mp1_header_sizes(buf: bytes, pos: int) -> dict:
    """Repli : 4 tailles en tete puis les donnees a la suite. Ce n'est pas ce que
    decrit la specification, mais on le garde pour ne pas casser un fichier
    produit par un autre outil qui aurait ecrit cette disposition."""
    pool_sz, proj_sz, samp_sz, sdir_sz = struct.unpack_from(">4I", buf, pos)
    p = pos + 16
    spans = {}
    for tag, sz in (("pool", pool_sz), ("proj", proj_sz),
                    ("samp", samp_sz), ("sdir", sdir_sz)):
        spans[tag] = (p, sz)
        p += sz
    return spans


def parse_agsc(buf: bytes) -> tuple[dict, bytes, bytes]:
    """Retourne (entete, chunk sdir, chunk samp). Gere MP1 et MP2."""
    # MP2 : u32 == 1, puis nom du groupe, puis 4 tailles de chunks
    if len(buf) >= 4 and struct.unpack_from(">I", buf, 0)[0] == 1:
        name, pos = _cstr(buf, 4)
        group_id = struct.unpack_from(">H", buf, pos)[0]
        pos += 2
        pool_sz, proj_sz, sdir_sz, samp_sz = struct.unpack_from(">4I", buf, pos)
        pos += 16
        pool_off = pos
        proj_off = pool_off + pool_sz
        sdir_off = proj_off + proj_sz          # MP2 : sdir AVANT samp
        samp_off = sdir_off + sdir_sz
        head = {"version": "MP2", "name": name, "group_id": group_id}
        spans = {"pool": (pool_off, pool_sz), "proj": (proj_off, proj_sz),
                 "sdir": (sdir_off, sdir_sz), "samp": (samp_off, samp_sz)}
    else:
        # MP1 : "Audio/" puis le nom du groupe. La suite se lit de deux facons
        # possibles ; on prend celle qui produit une table SDIR coherente plutot
        # que de parier. La disposition de la specification passe en premier.
        adir, pos = _cstr(buf, 0)
        name, pos = _cstr(buf, pos)
        spans = layout = None
        for tag, build in (("per_chunk", _mp1_per_chunk),
                           ("header_sizes", _mp1_header_sizes)):
            try:
                cand = build(buf, pos)
            except (struct.error, IndexError):
                continue
            if _plausible(buf, cand):
                spans, layout = cand, tag
                break
        if spans is None:
            raise ValueError(
                "AGSC MP1 illisible : aucune des deux dispositions connues ne "
                "donne une table SDIR coherente. Fichier tronque ou variante "
                "non geree.")
        head = {"version": "MP1", "name": name, "audio_dir": adir,
                "layout": layout}

    head.update(pool_size=spans["pool"][1], proj_size=spans["proj"][1],
                sdir_size=spans["sdir"][1], samp_size=spans["samp"][1])
    sdir_off, sdir_sz = spans["sdir"]
    samp_off, samp_sz = spans["samp"]
    return head, buf[sdir_off:sdir_off + sdir_sz], buf[samp_off:samp_off + samp_sz]


def parse_sdir(sdir: bytes) -> list[dict]:
    """Table A : une entree de 0x20 octets par sample, terminee par 0xFFFFFFFF."""
    entries = []
    pos = 0
    while pos + SDIR_ENTRY <= len(sdir):
        if struct.unpack_from(">I", sdir, pos)[0] == 0xFFFFFFFF:
            break
        (sid, _pad, start, _unk, base_note, _pad2,
         rate, fmt_and_n) = struct.unpack_from(">HHIIBBHI", sdir, pos)
        fmt = (fmt_and_n >> 24) & 0xFF
        n_samples = fmt_and_n & 0x00FFFFFF
        loop_start, loop_len, tbl_b = struct.unpack_from(">3I", sdir, pos + 0x14)
        e = {"id": sid, "offset": start, "base_note": base_note,
             "sample_rate": rate, "format": fmt, "num_samples": n_samples,
             "loop_start": loop_start, "loop_length": loop_len, "coef_off": tbl_b}
        # Table B : contexte ADPCM + 16 coefficients
        if tbl_b + 0x28 <= len(sdir):
            ps, lps = sdir[tbl_b + 2], sdir[tbl_b + 3]
            h2, h1 = struct.unpack_from(">hh", sdir, tbl_b + 4)
            e["coefs"] = list(struct.unpack_from(">16h", sdir, tbl_b + 8))
            e["ps"], e["loop_ps"], e["hist1"], e["hist2"] = ps, lps, h1, h2
        entries.append(e)
        pos += SDIR_ENTRY
    return entries


def decode_entry(entry: dict, samp: bytes) -> list[int]:
    fmt = entry["format"]
    n = entry["num_samples"]
    off = entry["offset"]
    if fmt in (FMT_ADPCM, FMT_ADPCM2):
        n_bytes = ((n + 13) // 14) * 8
        return dsp_decode(samp[off:off + n_bytes], n, entry.get("coefs", [0] * 16))
    if fmt == FMT_PCM16:
        raw = samp[off:off + n * 2]
        return list(struct.unpack(f">{len(raw)//2}h", raw[: (len(raw) // 2) * 2]))
    if fmt == FMT_PCM8:
        return [(b - 128) << 8 for b in samp[off:off + n]]
    raise ValueError(f"format audio inconnu : {fmt}")


def write_wav(path: str, samples: list[int], rate: int) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(max(1, rate))
        w.writeframes(struct.pack(f"<{len(samples)}h", *samples))


def extract_agsc(buf: bytes, out_dir: str, tag: str = "") -> list[dict]:
    head, sdir, samp = parse_agsc(buf)
    entries = parse_sdir(sdir)
    group = head.get("name") or tag or "group"
    manifest = []
    for e in entries:
        try:
            pcm = decode_entry(e, samp)
        except Exception as exc:                      # sample corrompu -> on continue
            print(f"  ! sample {e['id']:#06x} ignore : {exc}", file=sys.stderr)
            continue
        rel = os.path.join(group, f"{e['id']:#06x}.wav")
        write_wav(os.path.join(out_dir, rel), pcm, e["sample_rate"])
        manifest.append({
            "file": rel.replace(os.sep, "/"), "group": group,
            "agsc_version": head["version"], "samp_offset": e["offset"],
            "id": e["id"],
            "base_note": e["base_note"], "sample_rate": e["sample_rate"],
            "num_samples": e["num_samples"], "format": e["format"],
            "loop_start": e["loop_start"], "loop_length": e["loop_length"],
            "looped": e["loop_length"] > 0,
            "duration_s": round(e["num_samples"] / max(1, e["sample_rate"]), 4),
        })
    print(f"[agsc] {group} ({head['version']}) : {len(manifest)} samples")
    return manifest


# ═══════════════════════════════════════════════════════════════════════════════
# PAK (Retro Studios, Metroid Prime 1/2)
# ═══════════════════════════════════════════════════════════════════════════════

def extract_pak(buf: bytes, out_dir: str) -> list[dict]:
    ver, _unk, n_named = struct.unpack_from(">3I", buf, 0)
    pos = 12
    for _ in range(n_named):
        pos += 8                                       # fourcc + id
        (nlen,) = struct.unpack_from(">I", buf, pos)
        pos += 4 + nlen
    (n_res,) = struct.unpack_from(">I", buf, pos)
    pos += 4
    manifest = []
    for _ in range(n_res):
        comp, fourcc, rid, size, off = struct.unpack_from(">I4sIII", buf, pos)
        pos += 20
        if fourcc != b"AGSC":
            continue
        data = buf[off:off + size]
        if comp:
            (_dec_size,) = struct.unpack_from(">I", data, 0)
            data = zlib.decompress(data[4:])
        manifest += extract_agsc(data, out_dir, tag=f"{rid:#010x}")
    print(f"[pak] version {ver:#x} — {n_res} ressources, "
          f"{len(manifest)} samples extraits")
    return manifest


# ═══════════════════════════════════════════════════════════════════════════════
# ISO / GCM (systeme de fichiers GameCube)
# ═══════════════════════════════════════════════════════════════════════════════

def iso_files(buf: bytes):
    """Itere (chemin, offset, taille) sur la FST du disque."""
    fst_off, fst_size = struct.unpack_from(">II", buf, 0x424)
    fst = buf[fst_off:fst_off + fst_size]
    (n_entries,) = struct.unpack_from(">I", fst, 8)
    strings = 12 * n_entries
    for i in range(1, n_entries):
        e = 12 * i
        flags = fst[e]
        name_off = struct.unpack_from(">I", fst, e)[0] & 0x00FFFFFF
        a, b = struct.unpack_from(">II", fst, e + 4)
        end = fst.index(b"\x00", strings + name_off)
        name = fst[strings + name_off:end].decode("ascii", "replace")
        if flags == 0:
            yield name, a, b


def extract_iso(buf: bytes, out_dir: str) -> list[dict]:
    manifest = []
    found = 0
    for name, off, size in iso_files(buf):
        low = name.lower()
        if low.endswith(".pak"):
            found += 1
            try:
                manifest += extract_pak(buf[off:off + size], out_dir)
            except Exception as exc:
                print(f"  ! {name} ignore : {exc}", file=sys.stderr)
        elif low.endswith(".agsc"):
            found += 1
            manifest += extract_agsc(buf[off:off + size], out_dir, tag=name)
    print(f"[iso] {found} archives audio parcourues")
    return manifest



# ═══════════════════════════════════════════════════════════════════════════════
# DOSSIER — accepte n'importe quel melange, y compris la sortie d'un autre outil
# ═══════════════════════════════════════════════════════════════════════════════

def _wav_info(path: str) -> dict | None:
    """Lit un WAV deja extrait et devine ses parametres de banque."""
    try:
        with wave.open(path, "rb") as w:
            rate, n, nch, width = (w.getframerate(), w.getnframes(),
                                   w.getnchannels(), w.getsampwidth())
            raw = w.readframes(min(n, rate * 4))
    except Exception:
        return None
    if width != 2 or n < 64:
        return None
    # note de base estimee par autocorrelation sur le debut du sample
    import array
    pcm = array.array("h")
    pcm.frombytes(raw[: (len(raw) // (2 * nch)) * 2 * nch])
    mono = [pcm[i] for i in range(0, len(pcm), nch)]
    seg = mono[: min(len(mono), rate // 2)]
    base_note = 60
    if len(seg) > 400:
        best, best_lag = 0.0, 0
        mean = sum(seg) / len(seg)
        c = [v - mean for v in seg]
        energy = sum(v * v for v in c) or 1.0
        for lag in range(int(rate / 1200), min(int(rate / 40), len(c) // 2)):
            acc = 0.0
            for i in range(0, len(c) - lag, 8):        # sous-echantillonne : suffisant
                acc += c[i] * c[i + lag]
            acc /= energy
            if acc > best:
                best, best_lag = acc, lag
        if best_lag:
            f0 = rate / best_lag
            if 25.0 < f0 < 5000.0:
                base_note = int(round(69 + 12 * math.log2(f0 / 440.0)))
    # bouclage : un sample long et soutenu se boucle, un court ne se boucle pas
    dur = n / max(1, rate)
    looped = dur > 0.9
    return {"sample_rate": rate, "num_samples": n, "base_note": base_note,
            "looped": looped, "loop_start": int(n * 0.55) if looped else 0,
            "loop_length": int(n * 0.35) if looped else 0,
            "duration_s": round(dur, 4), "format": 1}


def extract_dir(path: str, out_dir: str) -> list[dict]:
    """Parcourt un dossier et absorbe tout ce qu'il sait lire."""
    import shutil
    manifest: list[dict] = []
    seen = {"iso": 0, "pak": 0, "agsc": 0, "wav": 0, "dsp": 0}
    for root, _dirs, files in os.walk(path):
        for name in sorted(files):
            full = os.path.join(root, name)
            low = name.lower()
            try:
                if low.endswith((".iso", ".gcm")):
                    seen["iso"] += 1
                    with open(full, "rb") as fh:
                        manifest += extract_iso(fh.read(), out_dir)
                elif low.endswith(".pak"):
                    seen["pak"] += 1
                    with open(full, "rb") as fh:
                        manifest += extract_pak(fh.read(), out_dir)
                elif low.endswith(".agsc"):
                    seen["agsc"] += 1
                    with open(full, "rb") as fh:
                        manifest += extract_agsc(fh.read(), out_dir, tag=name)
                elif low.endswith(".wav"):
                    info = _wav_info(full)
                    if not info:
                        continue
                    seen["wav"] += 1
                    rel = os.path.join("imported", name)
                    dst = os.path.join(out_dir, rel)
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    if os.path.abspath(full) != os.path.abspath(dst):
                        shutil.copyfile(full, dst)
                    info.update(file=rel.replace(os.sep, "/"), group="imported",
                                id=len(manifest), agsc_version="wav", samp_offset=0)
                    manifest.append(info)
                elif low.endswith(".dsp"):
                    seen["dsp"] += 1
            except Exception as exc:
                print(f"  ! {name} ignore : {exc}", file=sys.stderr)
    print(f"[dir] parcouru : " + ", ".join(f"{v} {k}" for k, v in seen.items() if v))
    if seen["dsp"]:
        print(f"[dir] {seen['dsp']} fichiers .dsp trouves : convertissez-les d'abord en WAV\n"
              f"      (vgmstream : vgmstream-cli -o sortie.wav entree.dsp)", file=sys.stderr)
    return manifest


# ═══════════════════════════════════════════════════════════════════════════════
# AUTOTEST — fabrique un AGSC valide au format documente et le relit
# ═══════════════════════════════════════════════════════════════════════════════

def _build_fixture(version: str = "MP2") -> tuple[bytes, list[list[int]]]:
    """Construit un AGSC synthetique : 2 samples ADPCM + 1 PCM16.

    version="MP1" produit la disposition decrite par la specification Retro
    Modding : chaque chunk precede de sa propre taille, taille incluse, et
    l'ordre pool/proj/samp/sdir. version="MP2" produit les quatre tailles en
    en-tete et l'ordre pool/proj/sdir/samp."""
    import math
    coefs = [1820, -856, 3238, -1514, 2333, -550, 3336, -1287,
             2895, -1180, 1400, -400, 2700, -900, 3000, -1100]

    def tone(f, n, rate, amp=12000):
        return [int(amp * math.sin(2 * math.pi * f * i / rate)) for i in range(n)]

    originals = [tone(440, 700, 22050), tone(180, 420, 16000), tone(880, 300, 32000)]
    fmts = [FMT_ADPCM, FMT_ADPCM, FMT_PCM16]
    rates = [22050, 16000, 32000]
    notes = [60, 48, 72]

    samp = bytearray()
    blobs = []
    for pcm, fmt in zip(originals, fmts):
        off = len(samp)
        if fmt == FMT_ADPCM:
            enc = dsp_encode(pcm, coefs)
        else:
            enc = struct.pack(f">{len(pcm)}h", *pcm)
        samp += enc
        samp += b"\x00" * ((-len(samp)) % 32)       # alignement 32 octets
        blobs.append(off)

    n = len(originals)
    tbl_a_size = SDIR_ENTRY * n + 4
    sdir = bytearray(tbl_a_size)
    for i, (pcm, fmt, rate, note) in enumerate(zip(originals, fmts, rates, notes)):
        coef_off = tbl_a_size + i * 0x28
        struct.pack_into(">HHIIBBHI", sdir, i * SDIR_ENTRY,
                         0x1000 + i, 0, blobs[i], 0, note, 0, rate,
                         (fmt << 24) | len(pcm))
        struct.pack_into(">3I", sdir, i * SDIR_ENTRY + 0x14, 0, 0, coef_off)
    struct.pack_into(">I", sdir, SDIR_ENTRY * n, 0xFFFFFFFF)
    for i in range(n):
        b = bytearray(0x28)
        struct.pack_into(">H", b, 0, 8)
        struct.pack_into(">16h", b, 8, *coefs)
        sdir += b

    name = b"TestGroup\x00"
    if version == "MP1":
        # MP1 : "Audio/" puis le nom, puis chaque chunk precede de SA taille,
        # taille incluse ; ordre pool, proj, samp, sdir (sdir EN DERNIER).
        def chunk(data: bytes) -> bytes:
            return struct.pack(">I", len(data) + 4) + data
        return (b"Audio/\x00" + name + chunk(b"POOL") + chunk(b"PROJ")
                + chunk(bytes(samp)) + chunk(bytes(sdir))), originals

    head = struct.pack(">I", 1) + name + struct.pack(">H", 0xFFFF)
    head += struct.pack(">4I", 4, 4, len(sdir), len(samp))
    body = b"POOL" + b"PROJ" + bytes(sdir) + bytes(samp)
    return head + body, originals


def selftest() -> int:
    import math
    import tempfile
    print("── autotest de l'extracteur ──")
    ok = True

    # 1. aller-retour ADPCM
    tone = [int(11000 * math.sin(2 * math.pi * 300 * i / 22050)) for i in range(560)]
    coefs = [1820, -856, 3238, -1514, 2333, -550, 3336, -1287,
             2895, -1180, 1400, -400, 2700, -900, 3000, -1100]
    dec = dsp_decode(dsp_encode(tone, coefs), len(tone), coefs)
    err = sum((a - b) ** 2 for a, b in zip(tone, dec)) / len(tone)
    sig = sum(x * x for x in tone) / len(tone)
    snr = 10 * math.log10(sig / max(err, 1e-9))
    print(f"  ADPCM aller-retour : SNR {snr:.1f} dB  ({len(dec)} echantillons)")
    if snr < 20 or len(dec) != len(tone):
        print("  ECHEC : le decodeur ADPCM ne reconstruit pas le signal"); ok = False

    # 2. conteneur AGSC complet
    blob, originals = _build_fixture()
    head, sdir, samp = parse_agsc(blob)
    entries = parse_sdir(sdir)
    print(f"  AGSC : version={head['version']} groupe={head['name']!r} "
          f"samples={len(entries)}")
    if len(entries) != 3:
        print(f"  ECHEC : {len(entries)} entrees sdir au lieu de 3"); ok = False
    expect = [(0x1000, 60, 22050, 700), (0x1001, 48, 16000, 420), (0x1002, 72, 32000, 300)]
    for e, (sid, note, rate, n) in zip(entries, expect):
        got = (e["id"], e["base_note"], e["sample_rate"], e["num_samples"])
        flag = "ok" if got == (sid, note, rate, n) else "ECHEC"
        if flag == "ECHEC":
            ok = False
        print(f"    {flag} id={e['id']:#06x} note={e['base_note']} "
              f"rate={e['sample_rate']} n={e['num_samples']} fmt={e['format']}")

    # 2bis. conteneur MP1 — disposition « une taille par chunk », taille incluse
    blob1, orig1 = _build_fixture("MP1")
    try:
        h1, sdir1, samp1 = parse_agsc(blob1)
        e1 = parse_sdir(sdir1)
        print(f"  AGSC MP1 : disposition={h1.get('layout')} groupe={h1['name']!r} "
              f"samples={len(e1)}")
        if h1["version"] != "MP1" or h1.get("layout") != "per_chunk" or len(e1) != 3:
            print("  ECHEC : en-tete MP1 mal interprete"); ok = False
        else:
            pcm1 = decode_entry(e1[0], samp1)
            if len(pcm1) != len(orig1[0]):
                print(f"  ECHEC : MP1 {len(pcm1)} echantillons au lieu de "
                      f"{len(orig1[0])}"); ok = False
            else:
                print(f"    ok premier sample decode : {len(pcm1)} echantillons")
    except Exception as exc:                                  # noqa: BLE001
        print(f"  ECHEC : AGSC MP1 illisible — {exc}"); ok = False

    # 3. decodage de chaque entree
    for e, orig in zip(entries, originals):
        pcm = decode_entry(e, samp)
        if len(pcm) != len(orig):
            print(f"  ECHEC : {len(pcm)} echantillons decodes au lieu de {len(orig)}")
            ok = False
            continue
        err = sum((a - b) ** 2 for a, b in zip(orig, pcm)) / len(orig)
        sig = sum(x * x for x in orig) / len(orig)
        snr = 10 * math.log10(sig / max(err, 1e-9))
        seuil = 60 if e["format"] == FMT_PCM16 else 20
        print(f"    sample {e['id']:#06x} : SNR {snr:.1f} dB (seuil {seuil})")
        if snr < seuil:
            print("  ECHEC : decodage trop degrade"); ok = False

    # 4. ecriture disque + manifest
    with tempfile.TemporaryDirectory() as td:
        man = extract_agsc(blob, td)
        if len(man) != 3:
            print("  ECHEC : manifest incomplet"); ok = False
        for m in man:
            p = os.path.join(td, m["file"])
            if not os.path.exists(p) or os.path.getsize(p) < 64:
                print(f"  ECHEC : {m['file']} absent ou vide"); ok = False
        print(f"  manifest : {len(man)} entrees, WAV ecrits")

    print("── AUTOTEST OK ──" if ok else "── AUTOTEST EN ECHEC ──")
    return 0 if ok else 1


# ═══════════════════════════════════════════════════════════════════════════════

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["iso", "pak", "agsc", "dir", "selftest"])
    ap.add_argument("--input")
    ap.add_argument("--out", default="extract")
    args = ap.parse_args()

    if args.mode == "selftest":
        return selftest()
    if not args.input:
        ap.error("--input est requis")
    if args.mode == "dir":
        if not os.path.isdir(args.input):
            print(f"pas un dossier : {args.input}", file=sys.stderr)
            return 2
        samples = extract_dir(args.input, args.out)
        os.makedirs(args.out, exist_ok=True)
        manifest = {
            "source": {"path": os.path.abspath(args.input),
                       "filename": os.path.basename(os.path.abspath(args.input)),
                       "sha256": "(dossier — voir les entrees individuelles)",
                       "size_bytes": 0, "mode": "dir"},
            "extracted_at": datetime.datetime.now(datetime.timezone.utc)
                                     .strftime("%Y-%m-%dT%H:%M:%SZ"),
            "tool": f"musyx_extract.py {TOOL_VERSION}",
            "sample_count": len(samples), "samples": samples,
        }
        mpath = os.path.join(args.out, "manifest.json")
        with open(mpath, "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, indent=2, ensure_ascii=False)
        print(f"[ok] {len(samples)} samples -> {args.out}/  (manifest : {mpath})")
        return 0
    if not os.path.exists(args.input):
        print(f"introuvable : {args.input}\n\n"
              "Cet outil ne fournit aucune donnee de jeu. Utilisez votre propre copie.",
              file=sys.stderr)
        return 2

    with open(args.input, "rb") as fh:
        buf = fh.read()
    samples = {"iso": extract_iso, "pak": extract_pak,
               "agsc": extract_agsc}[args.mode](buf, args.out)

    os.makedirs(args.out, exist_ok=True)
    manifest = {
        "source": {
            "path": os.path.abspath(args.input),
            "filename": os.path.basename(args.input),
            "sha256": sha256_file(args.input),
            "size_bytes": os.path.getsize(args.input),
            "mode": args.mode,
        },
        "extracted_at": datetime.datetime.now(datetime.timezone.utc)
                                 .strftime("%Y-%m-%dT%H:%M:%SZ"),
        "tool": f"musyx_extract.py {TOOL_VERSION}",
        "sample_count": len(samples),
        "samples": samples,
    }
    mpath = os.path.join(args.out, "manifest.json")
    with open(mpath, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2, ensure_ascii=False)
    print(f"[ok] {len(samples)} samples -> {args.out}/  (manifest : {mpath})")
    print(f"     source SHA-256 : {manifest['source']['sha256']}")
    print("     Choisissez vos fonts, puis :")
    print(f"       python3 tools/audio/synth_palette.py --bank {args.out} "
          "--out audio/music/menu")
    return 0


if __name__ == "__main__":
    sys.exit(main())
