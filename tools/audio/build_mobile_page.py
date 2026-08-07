#!/usr/bin/env python3
"""Edition de controle mobile — mix PRE-RENDUS par meteo, courbe temporelle,
journal de defauts.

POURQUOI DES MIX PRE-RENDUS. Sur Claude mobile, le lecteur a 21 elements
<audio> simultanes avait les boutons muets et des bruits abrupts : la webview
iPhone etrangle les decodeurs — un decodeur affame produit exactement des
craquements, et les play() suivants meurent en silence. Ici chaque meteo est
UN SEUL fichier (socle + son quatuor, gains d'appariement appliques) : au plus
deux elements jouent pendant un fondu. C'est l'architecture qui tient sur un
telephone.

CE QU'ON Y GAGNE EN DIAGNOSTIC :
  - une courbe temporelle (enveloppe du mix) avec MARQUEURS d'evenements
    detectes (flux spectral), explorable au doigt — on saute ou on veut ;
  - un journal : « Marquer » consigne l'instant courant avec mesure, accord
    et distribution ; les erreurs des elements audio (error, stalled) s'y
    ajoutent TOUTES SEULES. Copier, envoyer — la boucle de diagnostic est la.

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
MIX_BITRATE = "56k"          # stereo joint ; 7 mixes doivent tenir sous 16 Mo
FX_BITRATE = "40k"

# les six meteos + la distribution par defaut
WEATHERS = ["clair", "couvert", "pluie", "orage", "brume", "neige"]


def decode(ff: str, path: str) -> np.ndarray:
    raw = subprocess.run([ff, "-loglevel", "error", "-i", path, "-f", "f32le",
                          "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).T.copy()


def encode_mp3(ff: str, sig: np.ndarray, dst: str, bitrate: str) -> None:
    pcm = np.clip(sig.T.reshape(-1), -1, 1).astype("<f4").tobytes()
    subprocess.run([ff, "-y", "-loglevel", "error", "-f", "f32le",
                    "-ar", str(SR), "-ac", "2", "-i", "-",
                    "-c:a", "libmp3lame", "-b:a", bitrate, dst],
                   input=pcm, check=True)


def envelope_and_onsets(mono: np.ndarray, points: int = 480):
    """Courbe d'enveloppe (0-100) + marqueurs d'evenements.

    Les marqueurs sont les pics de FLUX (montee rapide d'energie) : c'est la
    ou vivent les attaques — et les bruits abrupts. Espacement minimal 0,8 s
    pour rester lisible au doigt."""
    n = len(mono)
    hop = max(1, n // (points))
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
        # 2,2 dB par trame de 25 ms : une vraie attaque monte de 3 a 5 dB,
        # le vibrato d'une tenue moins de 1 — le premier seuil (6) ne
        # laissait rien passer du tout
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

    def resolve(meteo: str | None) -> dict:
        out = dict(cast["default"])
        if meteo:
            for role, cid in cast["context"].get(meteo, {}).items():
                out[role] = cid
        return out

    # ── un mix par meteo ─────────────────────────────────────────────────────
    print("[mobile] pre-mixage par meteo…")
    bed = decode(ff, os.path.join(a.stems, "bed.ogg"))
    part_cache: dict = {}

    def part(role: str, cid: str) -> np.ndarray:
        key = f"{role}__{cid}"
        if key not in part_cache:
            p = os.path.join(a.stems, key + ".ogg")
            part_cache[key] = decode(ff, p) if os.path.exists(p) else None
        sig = part_cache[key]
        return np.zeros_like(bed) if sig is None else sig[:, :bed.shape[1]]

    tmp = os.path.join(os.path.dirname(a.out) or ".", "_mob_tmp")
    os.makedirs(tmp, exist_ok=True)
    audio: dict = {}
    meta: dict = {"mixes": {}, "bar": BAR, "bars": N_BARS,
                  "progression": PROGRESSION}

    for wid in ["defaut"] + WEATHERS:
        castw = resolve(None if wid == "defaut" else wid)
        mix = bed.copy()
        for role, cid in castw.items():
            mix += part(role, cid) * gains.get((role, cid), 1.0)
        peak = float(np.abs(mix).max())
        if peak > 0.985:                       # garde-fou, pas un mastering
            mix *= 0.985 / peak
        dst = os.path.join(tmp, wid + ".mp3")
        encode_mp3(ff, mix, dst, MIX_BITRATE)
        audio["MIX_" + wid] = base64.b64encode(open(dst, "rb").read()).decode()
        os.remove(dst)
        curve, onsets = envelope_and_onsets(mix.mean(0))
        meta["mixes"][wid] = {
            "cast": {r: labels.get((r, c), c) for r, c in castw.items()},
            "curve": curve, "onsets": onsets,
        }
        print(f"  mix {wid:8s} {len(audio['MIX_' + wid]) / 1e6:5.2f} Mo b64, "
              f"{len(onsets)} marqueurs — " +
              ", ".join(f"{r}={labels.get((r, c), c)}" for r, c in castw.items()))

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
    meta["sfx"] = [{k: e[k] for k in ("id", "label", "loop", "gain", "ic")}
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
