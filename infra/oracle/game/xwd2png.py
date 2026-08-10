#!/usr/bin/env python3
"""Convertit un dump XWD (ZPixmap 24/32 bpp) en PNG — stdlib uniquement.

Usage: xwd2png.py entree.xwd sortie.png [--every N]
  --every N : sous-échantillonne (1 pixel sur N) pour produire une miniature.

Sert à la preuve visuelle des smokes du jeu natif sur la VM (xwd -root),
là où scrot n'existe pas (EPEL9 aarch64).
"""
import struct
import sys
import zlib


def _mask_shift(mask: int):
    s = 0
    while mask and not (mask & 1):
        mask >>= 1
        s += 1
    return s, mask or 1


def xwd_to_rgb(path: str, every: int = 1):
    d = open(path, "rb").read()
    hdr = struct.unpack(">25I", d[:100])
    hsz, w, h = hdr[0], hdr[4], hdr[5]
    byte_order, bpp, bpl = hdr[7], hdr[11], hdr[12]
    rm, gm, bm = hdr[14], hdr[15], hdr[16]
    ncolors = hdr[19]
    if bpp not in (24, 32):
        raise SystemExit(f"bpp {bpp} non géré (attendu 24/32)")
    off = hsz + ncolors * 12
    rs, rmax = _mask_shift(rm)
    gs, gmax = _mask_shift(gm)
    bs, bmax = _mask_shift(bm)
    step = bpp // 8
    endian = ">" if byte_order == 1 else "<"
    ow, oh = (w + every - 1) // every, (h + every - 1) // every
    out = bytearray(ow * oh * 3)
    i = 0
    for y in range(0, h, every):
        row = d[off + y * bpl: off + y * bpl + w * step]
        for x in range(0, w, every):
            px = row[x * step: x * step + step]
            if step == 3:
                px = px + b"\x00" if endian == "<" else b"\x00" + px
            v = struct.unpack(endian + "I", px)[0]
            out[i] = min(255, ((v & rm) >> rs) * 255 // rmax)
            out[i + 1] = min(255, ((v & gm) >> gs) * 255 // gmax)
            out[i + 2] = min(255, ((v & bm) >> bs) * 255 // bmax)
            i += 3
    return ow, oh, bytes(out)


def write_png(path: str, w: int, h: int, rgb: bytes):
    def chunk(tag: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    raw = b"".join(b"\x00" + rgb[y * w * 3:(y + 1) * w * 3] for y in range(h))
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    open(path, "wb").write(png)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    every = 1
    if "--every" in sys.argv:
        every = max(1, int(sys.argv[sys.argv.index("--every") + 1]))
    w, h, rgb = xwd_to_rgb(sys.argv[1], every)
    write_png(sys.argv[2], w, h, rgb)
    print(f"{sys.argv[2]}: {w}x{h}")
