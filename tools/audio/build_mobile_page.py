#!/usr/bin/env python3
"""Edition de controle mobile v2 — meteo = l'instrument de la MELODIE,
heure = la VITESSE (+ extras, + substitution nocturne du fond).

ARCHITECTURE EN COUCHES (pivot 2026-08-07). La v1 pre-mixait un fichier par
meteo : impossible d'y croiser 6 meteos x 6 heures sans 36 mixes. Ici la page
embarque des COUCHES, jamais plus de deux ou trois audibles a la fois — la
lecon de la webview iPhone (21 elements = boutons muets) reste appliquee :

    FOND_jour   socle + corde + pouls, SANS halo (moins d'elements)
    FOND_nuit   la substitution nocturne : dan tranh, cloches tubulaires,
                tambour de nuit — le fond change, la melodie reste a la meteo
    CHANT_<meteo>  la melodie seule, par l'instrument de la meteo (6 pistes)
    ADD_<extra>    « parfois quelques instruments en plus » : guirlande de
                   glockenspiel a midi, veilleuse de celesta en soiree

La VITESSE ne demande aucun rendu : c'est playbackRate (hauteur preservee par
le navigateur), applique au meme facteur sur toutes les couches. La position
musicale reste currentTime — mesures et accords ne bougent pas.

Toutes les couches d'un role portent les memes notes aux memes instants
(arrange_menu, repli d'octave en dernier) : un changement de meteo est un
fondu croise de la seule couche CHANT, un passage a la nuit un fondu de la
seule couche FOND.

    python3 tools/audio/build_mobile_page.py --stems audio/music/menu \\
        --out artefact_mobile.html
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from score_menu import BAR, N_BARS, PROGRESSION  # noqa: E402

SR = 48_000
FOND_BITRATE = "56k"         # stereo joint — 2 fonds seulement
CHANT_BITRATE = "40k"        # mono : la melodie seule, 6 pistes
ADD_BITRATE = "32k"          # mono : halo clairseme
FX_BITRATE = "40k"


def decode(ff: str, path: str) -> np.ndarray:
    raw = subprocess.run([ff, "-loglevel", "error", "-i", path, "-f", "f32le",
                          "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).T.copy()


def encode_mp3(ff: str, sig: np.ndarray, dst: str, bitrate: str) -> None:
    """sig : (2, n) stereo ou (n,) mono."""
    if sig.ndim == 1:
        pcm = np.clip(sig, -1, 1).astype("<f4").tobytes()
        ac = "1"
    else:
        pcm = np.clip(sig.T.reshape(-1), -1, 1).astype("<f4").tobytes()
        ac = "2"
    subprocess.run([ff, "-y", "-loglevel", "error", "-f", "f32le",
                    "-ar", str(SR), "-ac", ac, "-i", "-",
                    "-c:a", "libmp3lame", "-b:a", bitrate, dst],
                   input=pcm, check=True)


def envelope_and_onsets(mono: np.ndarray, points: int = 480):
    """Courbe d'enveloppe (0-100) + marqueurs d'evenements (pics de flux).

    2,2 dB par trame de 25 ms : une vraie attaque monte de 3 a 5 dB, le
    vibrato d'une tenue moins de 1. Espacement minimal 0,8 s."""
    n = len(mono)
    hop = max(1, n // points)
    env = np.array([np.abs(mono[i * hop:(i + 1) * hop]).max()
                    for i in range(points)])
    env_db = 20 * np.log10(np.maximum(env, 1e-5))
    lo, hi = -60.0, float(env_db.max())
    curve = np.clip((env_db - lo) / max(hi - lo, 1e-9), 0, 1) * 100

    fine_hop = int(0.025 * SR)
    m = n // fine_hop
    fe = np.array([np.sqrt((mono[i * fine_hop:(i + 1) * fine_hop] ** 2).mean())
                   for i in range(m)])
    fdb = 20 * np.log10(np.maximum(fe, 1e-6))
    flux = np.maximum(0, np.diff(fdb))
    order = np.argsort(flux)[::-1]
    picked: list[tuple[float, float]] = []
    for idx in order:
        t = (idx + 1) * fine_hop / SR
        s = float(flux[idx])
        if s < 2.2 or len(picked) >= 60:
            break
        if all(abs(t - p[0]) > 0.8 for p in picked):
            picked.append((round(t, 2), round(s, 1)))
    picked.sort()
    return [int(round(v)) for v in curve], picked


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stems", default="audio/music/menu")
    ap.add_argument("--out", default="artefact_mobile.html")
    a = ap.parse_args()

    import imageio_ffmpeg
    ff = imageio_ffmpeg.get_ffmpeg_exe()

    with open(os.path.join(a.stems, "casting.json"), encoding="utf-8") as fh:
        cast = json.load(fh)
    gains = {(r, c["id"]): float(c.get("gain", 1.0))
             for r, v in cast["candidates"].items() for c in v}
    labels = {(r, c["id"]): c["label"]
              for r, v in cast["candidates"].items() for c in v}
    meteos = cast["axes"]["meteo"]
    heures = cast["axes"]["heure"]
    tempo = cast["tempo"]
    extras = cast["extras"]

    def part(key: str) -> np.ndarray:
        return decode(ff, os.path.join(a.stems, key + ".ogg"))

    # ── les couches ──────────────────────────────────────────────────────────
    print("[mobile] couches…")
    bed = decode(ff, os.path.join(a.stems, "bed.ogg"))
    n = bed.shape[1]

    def fond_sum(cast_fond: dict) -> np.ndarray:
        sig = bed.copy()
        for role, cid in cast_fond.items():
            sig += part(f"{role}__{cid}")[:, :n] * gains[(role, cid)]
        return sig

    fonds = {"jour": fond_sum(cast["fond_jour"]),
             "nuit": fond_sum(cast["fond_nuit"])}
    chants = {}
    for w in meteos:
        cid = cast["context"][w]["chant"]
        chants[w] = (part(f"chant__{cid}")[:, :n] * gains[("chant", cid)]).mean(0)
    adds = {}
    for h, x in extras.items():
        role, cid = x["part"].split("__")
        adds[x["id"]] = (part(x["part"])[:, :n]
                         * gains[(role, cid)] * float(x["gain"])).mean(0)

    # ── marge : la SOMME des couches ne doit pas ecreter cote client ────────
    worst_add = max((np.abs(s) for s in adds.values()),
                    key=lambda s: float(s.max())) if adds else 0.0
    peak = 0.0
    for f in fonds.values():
        fm = np.abs(f).max(axis=0)
        for c in chants.values():
            p = float((fm + np.abs(c) + (worst_add if f is fonds["jour"] else 0.0)).max())
            peak = max(peak, p)
    k = min(1.0, 0.985 / peak)
    print(f"[mobile] pic somme pire cas {peak:.3f} -> facteur {k:.3f}")
    for d in (fonds, chants, adds):
        for key in d:
            d[key] = d[key] * k

    # ── encodage ─────────────────────────────────────────────────────────────
    tmp = os.path.join(os.path.dirname(a.out) or ".", "_mob_tmp")
    os.makedirs(tmp, exist_ok=True)
    audio: dict = {}

    def emit(name: str, sig: np.ndarray, bitrate: str) -> None:
        dst = os.path.join(tmp, "t.mp3")
        encode_mp3(ff, sig, dst, bitrate)
        audio[name] = base64.b64encode(open(dst, "rb").read()).decode()
        os.remove(dst)
        print(f"  {name:16s} {len(audio[name]) / 1e6:5.2f} Mo b64")

    for fid, sig in fonds.items():
        emit("FOND_" + fid, sig, FOND_BITRATE)
    for w, sig in chants.items():
        emit("CHANT_" + w, sig, CHANT_BITRATE)
    for xid, sig in adds.items():
        emit("ADD_" + xid, sig, ADD_BITRATE)

    # ── courbes par combinaison fond x meteo ────────────────────────────────
    meta: dict = {"bar": BAR, "bars": N_BARS, "progression": PROGRESSION,
                  "heures": heures, "meteos": meteos, "tempo": tempo,
                  "combos": {}}
    fond_mono = {fid: f.mean(0) for fid, f in fonds.items()}
    for fid, fm in fond_mono.items():
        for w, c in chants.items():
            curve, onsets = envelope_and_onsets(fm + c)
            meta["combos"][f"{fid}|{w}"] = {"curve": curve, "onsets": onsets}
    print(f"[mobile] {len(meta['combos'])} courbes fond x meteo")

    meta["chant"] = {w: labels[("chant", cast["context"][w]["chant"])]
                     for w in meteos}
    meta["fonds"] = {
        fid: " + ".join(["socle"] + [labels[(r, c)]
                                     for r, c in cast[f"fond_{fid}"].items()])
        for fid in ("jour", "nuit")}
    meta["extras"] = {h: {"id": x["id"], "label": x["label"]}
                      for h, x in extras.items()}

    # ── effets ───────────────────────────────────────────────────────────────
    for e in cast.get("sfx", []):
        src = os.path.join(a.stems, e["file"])
        if not os.path.exists(src):
            continue
        dst = os.path.join(tmp, "fx.mp3")
        subprocess.run([ff, "-y", "-loglevel", "error", "-i", src, "-ac", "1",
                        "-ar", "32000", "-c:a", "libmp3lame",
                        "-b:a", FX_BITRATE, dst], check=True)
        audio["FX_" + e["id"]] = base64.b64encode(open(dst, "rb").read()).decode()
        os.remove(dst)
    meta["sfx"] = [{key: e[key] for key in ("id", "label", "loop", "gain", "ic")}
                   for e in cast.get("sfx", [])]
    os.rmdir(tmp)

    tpl_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "mobile_template.html")
    with open(tpl_path, encoding="utf-8") as fh:
        page = fh.read()
    page = page.replace("__AUDIO_JSON__", json.dumps(audio))
    page = page.replace("__META_JSON__", json.dumps(meta, ensure_ascii=False))
    with open(a.out, "w", encoding="utf-8") as fh:
        fh.write(page)
    print(f"[mobile] {a.out}  ({os.path.getsize(a.out) / 1024 / 1024:.2f} Mo)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
