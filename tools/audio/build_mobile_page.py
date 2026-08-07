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
    CHANT_<instrument>  la melodie seule, une piste par instrument ; le choix
                   depend du COUPLE (meteo, heure) — le jour la meteo decide
                   (clair=oud, couvert=harpe, pluie=flute...), la nuit c'est
                   la boite a musique lente quelle que soit la meteo
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
# AAC (v7) : a debit egal, l'AAC-LC rend nettement mieux que le MP3 — c'est
# le levier « meilleure qualite » qui ne coute aucun octet. Conteneur .m4a,
# lu partout (iOS natif, Chromium).
FOND_BITRATE = "48k"         # stereo — drone de jour, fond de nuit
PERC_BITRATE = "32k"         # mono : percussions eparses
CHANT_BITRATE = "40k"        # mono : la melodie seule
FX_BITRATE = "24k"


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
    ap.add_argument("--stems-nuit", dest="stems_nuit",
                    default="audio/music/menu_nuit",
                    help="rendu au tempo reel x0,8 (MERLIN_TEMPO_SCALE)")
    ap.add_argument("--out", default="artefact_mobile.html")
    ap.add_argument("--codec", choices=("aac", "mp3"), default="aac",
                    help="aac pour la page publiee (meilleure qualite par bit, "
                         "lu par tous les webviews reels) ; mp3 pour la page de "
                         "test Playwright (le Chromium libre n'a pas l'AAC)")
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
    perc_by_h = cast.get("perc", {})

    def part(key: str, stems: str | None = None) -> np.ndarray:
        return decode(ff, os.path.join(stems or a.stems, key + ".ogg"))

    # ── les couches ──────────────────────────────────────────────────────────
    # v7 : DRONE de jour (bed) + PERCUSSIONS par heure en couche separee +
    # CHANT par instrument, tous au tempo 1,0 (varispeed doux a la lecture).
    # La NUIT vient d'un RENDU REEL a l'echelle 0,8 (--stems-nuit) : drone +
    # cloches + tambour premixes, boite a musique seule — hauteur normale,
    # tempo lent vrai, aucun traitement a la lecture.
    print("[mobile] couches…")
    MELODY_BOOST = 1.15          # « la musique se centre sur le motif »
    FOND_GAIN = 0.62             # « le fond doit etre moins sonore » (-4 dB)
    PERC_BOOST = 2.0             # « les percussions sont manquantes » (+6 dB)
    bed = decode(ff, os.path.join(a.stems, "bed.ogg"))
    n = bed.shape[1]

    drone = bed.copy()
    for role, cid in cast["fond_jour"].items():
        drone += part(f"{role}__{cid}")[:, :n] * gains[(role, cid)]
    drone *= FOND_GAIN

    night_cid = cast["context"]["nuit"]["chant"]
    day_cids = {w: cast["context"][w]["chant"] for w in meteos}
    chants = {}
    for cid in sorted(set(day_cids.values())):
        chants[cid] = (part(f"chant__{cid}")[:, :n]
                       * gains[("chant", cid)] * MELODY_BOOST).mean(0)
    percs = {}
    for pid in sorted({p for p in perc_by_h.values() if p}):
        percs[pid] = (part(f"pulse__{pid}")[:, :n]
                      * gains[("pulse", pid)] * PERC_BOOST).mean(0)

    # le set de nuit, rendu lent pour de vrai
    bed_n = decode(ff, os.path.join(a.stems_nuit, "bed.ogg"))
    nn = bed_n.shape[1]
    fond_nuit = bed_n.copy()
    for role, cid in cast["fond_nuit"].items():
        fond_nuit += part(f"{role}__{cid}", a.stems_nuit)[:, :nn] * gains[(role, cid)]
    fond_nuit *= FOND_GAIN
    chant_nuit = (part(f"chant__{night_cid}", a.stems_nuit)[:, :nn]
                  * gains[("chant", night_cid)] * MELODY_BOOST).mean(0)
    night_scale = nn / n

    # ── marge : la SOMME des couches ne doit pas ecreter cote client ────────
    worst_perc = max((np.abs(s) for s in percs.values()),
                     key=lambda s: float(s.max())) if percs else 0.0
    dm = np.abs(drone).max(axis=0)
    peak = max(float((dm + np.abs(c) + worst_perc).max())
               for c in chants.values())
    peak = max(peak, float((np.abs(fond_nuit).max(axis=0) + np.abs(chant_nuit)).max()))
    k = min(1.0, 0.985 / peak)
    print(f"[mobile] pic somme pire cas {peak:.3f} -> facteur {k:.3f}")
    drone *= k
    fond_nuit *= k
    chant_nuit = chant_nuit * k
    for d in (chants, percs):
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
        print(f"  {name:16s} {len(audio[name]) / 1e6:5.2f} Mo b64")

    emit("FOND_jour", drone, FOND_BITRATE)
    emit("FOND_nuit", fond_nuit, FOND_BITRATE)
    for cid, sig in chants.items():
        emit("CHANT_" + cid, sig, CHANT_BITRATE)
    emit("CHANT_" + night_cid, chant_nuit, CHANT_BITRATE)
    for pid, sig in percs.items():
        emit("PERC_" + pid, sig, PERC_BITRATE)

    # ── l'introduction : COURTE et SIMPLE (v8) ──────────────────────────────
    # Une seule mesure : le drone seul se leve depuis le silence, et la piece
    # entre. Rien d'autre — l'utilisateur a demande moins long, plus simple.
    intro_bars = 1
    ns = int(intro_bars * BAR * SR)
    fade = np.linspace(0.0, 1.0, ns, dtype=np.float32) ** 1.5
    intro = drone[:, :ns] * k * fade
    emit("INTRO", intro, FOND_BITRATE)
    meta_intro = {"dur": round(intro_bars * BAR, 3)}

    # ── courbes par combinaison reellement jouable ──────────────────────────
    # le jour : drone x chaque instrument de meteo ; la nuit : fond de nuit
    # x la boite a musique — chaque combo porte sa duree et sa mesure (la
    # nuit est 25 % plus longue : rendu reel a l'echelle 0,8)
    meta: dict = {"bar": BAR, "bars": N_BARS, "progression": PROGRESSION,
                  "heures": heures, "meteos": meteos, "tempo": tempo,
                  "perc": perc_by_h, "night_scale": round(night_scale, 4),
                  "intro": meta_intro, "combos": {}}
    dmono = drone.mean(0)
    for cid, c in chants.items():
        curve, onsets = envelope_and_onsets(dmono + c)
        meta["combos"][f"jour|{cid}"] = {
            "curve": curve, "onsets": onsets,
            "dur": round(n / SR, 3), "barsec": round(BAR, 4)}
    curve, onsets = envelope_and_onsets(fond_nuit.mean(0) + chant_nuit)
    meta["combos"][f"nuit|{night_cid}"] = {
        "curve": curve, "onsets": onsets,
        "dur": round(nn / SR, 3), "barsec": round(BAR * night_scale, 4)}
    print(f"[mobile] {len(meta['combos'])} courbes fond x melodie")

    meta["melodie"] = {
        "nuit": night_cid,
        "meteo": day_cids,
        "labels": dict({cid: labels[("chant", cid)] for cid in chants},
                       **{night_cid: labels[("chant", night_cid)]}),
    }
    meta["perclabels"] = {pid: labels[("pulse", pid)] for pid in percs}
    meta["fonds"] = {
        "jour": "drone",
        "nuit": " + ".join(["drone (lent, hauteur normale)"]
                           + [labels[(r, c)] for r, c in cast["fond_nuit"].items()]),
    }

    # ── effets ───────────────────────────────────────────────────────────────
    for e in cast.get("sfx", []):
        src = os.path.join(a.stems, e["file"])
        if not os.path.exists(src):
            continue
        dst = os.path.join(tmp, "fx." + ext)
        fxenc = (["-c:a", "aac"] if a.codec == "aac"
                 else ["-c:a", "libmp3lame"])
        subprocess.run([ff, "-y", "-loglevel", "error", "-i", src, "-ac", "1",
                        "-ar", "32000"] + fxenc +
                       ["-b:a", FX_BITRATE, dst], check=True)
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
