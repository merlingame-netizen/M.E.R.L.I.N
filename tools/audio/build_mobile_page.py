#!/usr/bin/env python3
"""Edition de controle mobile v9 — TOUT EN RENDU REEL.

Plus aucun varispeed, plus aucun etirement : chaque GROUPE d'heures est un
jeu complet rendu a son echelle exacte (fractions 5-lisses, voir score_menu)
et lu a 1,0 — hauteur normale partout, vitesses prononcees.

    groupe  echelle  heures                fond
    lent    5/6      aube, soiree          drone + guitare + taiko sourd
    ref     1        matinee, apres-midi   drone + guitare + bodhran calme
    vif     9/8      midi                  drone + guitare + pas d'an dro
    nuit    3/4      nuit                  drone + cloches + tambour de nuit

    FOND_<groupe>         drone ADOUCI (x0,5) + arpeges de guitare acoustique
                          + percussion du groupe, premixes a l'echelle
    CHANT_<groupe>_<cid>  la melodie par instrument de meteo, a l'echelle
                          (la nuit : la boite a musique seule)

La piece fait 20 mesures (98 s a l'echelle 1) : c'est ce qui permet a
4 jeux complets de tenir sous les 16 Mo de l'artefact.

    python3 tools/audio/build_mobile_page.py --codec aac --out artefact.html
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
# AAC : a debit egal, l'AAC-LC rend nettement mieux que le MP3. Conteneur
# .m4a, lu par tous les webviews reels (iOS natif, Chrome Android).
FOND_BITRATE = "64k"         # stereo — drone + guitare + percussion
CHANT_BITRATE = "40k"        # mono : la melodie — 32k etait OPAQUE
FX_BITRATE = "24k"

DRONE_GAIN = 0.50            # « le fond drone est toujours trop fort »
CORDE_GAIN = 0.85            # les arpeges de guitare, presents sans dominer
PERC_BOOST = 2.2             # « les percussions... trop peu presentes »
MELODY_BOOST = 1.20          # le motif au premier plan

GROUPS = ("lent", "ref", "vif", "nuit")


def decode(ff: str, path: str) -> np.ndarray:
    raw = subprocess.run([ff, "-loglevel", "error", "-i", path, "-f", "f32le",
                          "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).T.copy()


def encode_track(ff: str, sig: np.ndarray, dst: str, bitrate: str,
                 codec: str) -> None:
    """sig : (2, n) stereo ou (n,) mono -> AAC-LC (.m4a) ou MP3."""
    if sig.ndim == 1:
        pcm = np.clip(sig, -1, 1).astype("<f4").tobytes()
        ac = "1"
    else:
        pcm = np.clip(sig.T.reshape(-1), -1, 1).astype("<f4").tobytes()
        ac = "2"
    enc = (["-c:a", "aac", "-b:a", bitrate, "-movflags", "+faststart"]
           if codec == "aac" else ["-c:a", "libmp3lame", "-b:a", bitrate])
    subprocess.run([ff, "-y", "-loglevel", "error", "-f", "f32le",
                    "-ar", str(SR), "-ac", ac, "-i", "-"] + enc + [dst],
                   input=pcm, check=True)


def envelope_and_onsets(mono: np.ndarray, points: int = 480):
    """Courbe d'enveloppe (0-100) + marqueurs d'evenements (pics de flux)."""
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
    ap.add_argument("--stems", default="audio/music/menu",
                    help="rendu de reference (echelle 1)")
    ap.add_argument("--stems-lent", dest="stems_lent",
                    default="audio/music/menu_lent")
    ap.add_argument("--stems-vif", dest="stems_vif",
                    default="audio/music/menu_vif")
    ap.add_argument("--stems-nuit", dest="stems_nuit",
                    default="audio/music/menu_nuit")
    ap.add_argument("--out", default="artefact_mobile.html")
    ap.add_argument("--codec", choices=("aac", "mp3"), default="aac",
                    help="aac pour la page publiee ; mp3 pour la page de "
                         "test Playwright (le Chromium libre n'a pas l'AAC)")
    a = ap.parse_args()
    dirs = {"lent": a.stems_lent, "ref": a.stems, "vif": a.stems_vif,
            "nuit": a.stems_nuit}

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
    perc = cast["perc"]
    night_cid = cast["context"]["nuit"]["chant"]
    day_cids = {w: cast["context"][w]["chant"] for w in meteos}

    def part(grp: str, key: str) -> np.ndarray:
        return decode(ff, os.path.join(dirs[grp], key + ".ogg"))

    # ── les couches, par groupe d'echelle ────────────────────────────────────
    print("[mobile] couches par groupe…")
    fonds: dict = {}
    chants: dict = {}          # (grp, cid) -> mono
    lens: dict = {}
    for grp in GROUPS:
        bed = part(grp, "bed")
        n = bed.shape[1]
        lens[grp] = n
        fond = bed * DRONE_GAIN
        if grp == "nuit":
            fond += part(grp, "halo__tubulaires")[:, :n] * gains[("halo", "tubulaires")]
            fond += part(grp, "pulse__nuit")[:, :n] * (gains[("pulse", "nuit")] * 1.5)
            chants[(grp, night_cid)] = (
                part(grp, f"chant__{night_cid}")[:, :n]
                * gains[("chant", night_cid)] * MELODY_BOOST).mean(0)
        else:
            fond += part(grp, "corde__celtic_guitar")[:, :n] * (
                gains[("corde", "celtic_guitar")] * CORDE_GAIN)
            pid = perc[grp]
            fond += part(grp, f"pulse__{pid}")[:, :n] * (
                gains[("pulse", pid)] * PERC_BOOST)
            for cid in sorted(set(day_cids.values())):
                chants[(grp, cid)] = (
                    part(grp, f"chant__{cid}")[:, :n]
                    * gains[("chant", cid)] * MELODY_BOOST).mean(0)
        fonds[grp] = fond
        print(f"  groupe {grp:5s} {n / SR:6.1f} s")

    # ── marge anti-ecretage sur la somme fond + chant, pire cas ──────────────
    peak = 0.0
    for (grp, cid), c in chants.items():
        p = float((np.abs(fonds[grp]).max(axis=0) + np.abs(c)).max())
        peak = max(peak, p)
    k = min(1.0, 0.985 / peak)
    print(f"[mobile] pic somme pire cas {peak:.3f} -> facteur {k:.3f}")
    for d in (fonds, chants):
        for key in d:
            d[key] = d[key] * k

    # ── encodage ─────────────────────────────────────────────────────────────
    tmp = os.path.join(os.path.dirname(a.out) or ".", "_mob_tmp")
    os.makedirs(tmp, exist_ok=True)
    audio: dict = {}
    ext = "m4a" if a.codec == "aac" else "mp3"

    def emit(name: str, sig: np.ndarray, bitrate: str) -> None:
        dst = os.path.join(tmp, "t." + ext)
        encode_track(ff, sig, dst, bitrate, a.codec)
        audio[name] = base64.b64encode(open(dst, "rb").read()).decode()
        os.remove(dst)
        print(f"  {name:22s} {len(audio[name]) / 1e6:5.2f} Mo b64")

    for grp in GROUPS:
        emit("FOND_" + grp, fonds[grp], FOND_BITRATE)
    for (grp, cid), sig in sorted(chants.items()):
        emit(f"CHANT_{grp}_{cid}", sig, CHANT_BITRATE)

    # ── l'introduction : une mesure, le fond seul se leve ────────────────────
    ns = int(BAR * SR)
    fade = np.linspace(0.0, 1.0, ns, dtype=np.float32) ** 1.5
    emit("INTRO", fonds["ref"][:, :ns] * fade, FOND_BITRATE)

    # ── meta : courbes et geometrie par combinaison ─────────────────────────
    meta: dict = {"bars": N_BARS, "progression": PROGRESSION,
                  "heures": heures, "meteos": meteos,
                  "tempo": cast["tempo"], "group_of": cast["group_of"],
                  "intro": {"dur": round(BAR, 3)},
                  "groups": {}, "combos": {}}
    speed = {"lent": 5 / 6, "ref": 1.0, "vif": 9 / 8, "nuit": 3 / 4}
    for grp in GROUPS:
        meta["groups"][grp] = {
            "dur": round(lens[grp] / SR, 3),
            "barsec": round(BAR / speed[grp], 4),
            "fond": ("drone + guitare + " + labels[("pulse", perc[grp])]
                     if grp != "nuit" else
                     "drone + cloches tubulaires + tambour de nuit"),
        }
    for (grp, cid), c in chants.items():
        curve, onsets = envelope_and_onsets(fonds[grp].mean(0) + c)
        meta["combos"][f"{grp}|{cid}"] = {"curve": curve, "onsets": onsets}
    print(f"[mobile] {len(meta['combos'])} courbes groupe x melodie")

    meta["melodie"] = {
        "nuit": night_cid, "meteo": day_cids,
        "labels": {cid: labels[("chant", cid)]
                   for cid in set(day_cids.values()) | {night_cid}},
    }

    # ── effets ───────────────────────────────────────────────────────────────
    for e in cast.get("sfx", []):
        src = os.path.join(a.stems, e["file"])
        if not os.path.exists(src):
            continue
        dst = os.path.join(tmp, "fx." + ext)
        fxenc = ["-c:a", "aac"] if a.codec == "aac" else ["-c:a", "libmp3lame"]
        subprocess.run([ff, "-y", "-loglevel", "error", "-i", src, "-ac", "1",
                        "-ar", "32000"] + fxenc + ["-b:a", FX_BITRATE, dst],
                       check=True)
        audio["FX_" + e["id"]] = base64.b64encode(open(dst, "rb").read()).decode()
        os.remove(dst)
    meta["sfx"] = [{key: e[key] for key in ("id", "label", "loop", "gain", "ic")}
                   for e in cast.get("sfx", [])]
    meta["mime"] = "audio/mp4" if a.codec == "aac" else "audio/mpeg"
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
