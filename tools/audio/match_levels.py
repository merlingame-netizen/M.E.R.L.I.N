#!/usr/bin/env python3
"""
Apparie le niveau des titulaires d'un meme role — mesure sur les fichiers RENDUS.

POURQUOI CE PASSAGE EXISTE, ET POURQUOI IL EST SEPARE DU RENDU
--------------------------------------------------------------
Changer de titulaire ne doit pas s'entendre comme un changement de volume. Deux
tentatives d'appariement AVANT le master ont echoue, chacune pour une raison
qu'il fallait mesurer pour voir :

  - apparier la CRETE (fenetre de 500 ms la plus forte) : le master recale
    ensuite chaque sortie sur une RMS cible, et cette renormalisation defait une
    partie de l'appariement. Ecart mesure sur le role `corde` : 2,52 dB.
  - apparier la RMS : le master la conserve exactement, mais deux instruments de
    facteurs de crete differents a RMS egale ne sont pas percus au meme niveau.
    Le meme ecart est monte a 5,11 dB — c'est PIRE, et c'etait previsible :
    un psalterion tenu et une kalimba percussive n'ont rien du meme profil.

La seule mesure qui compte est donc celle prise SUR LE FICHIER FINAL, apres
master. D'ou ce passage separe : il lit les .ogg produits, mesure leur niveau
percu, et ecrit le correctif dans le champ `gain` de casting.json — champ que
la page et menu_casting.gd appliquent a la lecture.

Aucun re-encodage : corriger l'audio lui-meme imposerait un second passage
lossy, alors qu'un gain de lecture est exact et gratuit.

    python3 tools/audio/match_levels.py --dir audio/music/menu
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess

import numpy as np

SR = 44100


def load(path: str) -> np.ndarray:
    import imageio_ffmpeg
    raw = subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-loglevel", "error",
                          "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).T.astype(np.float64)


def peak_rms(x: np.ndarray, win: float = 0.5) -> float:
    """RMS de la fenetre la plus forte : le niveau QUAND LA PARTIE SONNE.

    Une partie de role est sparse — le halo joue 48 notes en 196 s — et sa RMS
    globale est dominee par le silence. C'est cette mesure-la, et non la RMS,
    qui suit ce que l'oreille appelle « aussi fort »."""
    m = x.mean(axis=0) if x.ndim > 1 else x
    n = int(win * SR)
    if len(m) <= n:
        return float(np.sqrt((m ** 2).mean()))
    e = np.cumsum(np.concatenate([[0.0], m ** 2]))
    starts = np.arange(0, len(m) - n, max(1, n // 8))
    return float(np.sqrt(np.max((e[starts + n] - e[starts]) / n)))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="audio/music/menu")
    ap.add_argument("--max-trim", type=float, default=9.0,
                    help="correction maximale en dB. Au-dela, c'est que la partie "
                         "elle-meme est mal ecrite pour cet instrument — mieux vaut "
                         "le signaler que le rattraper au gain.")
    args = ap.parse_args()

    path = os.path.join(args.dir, "casting.json")
    with open(path, encoding="utf-8") as fh:
        cast = json.load(fh)

    print("Appariement des titulaires, mesure sur les fichiers rendus :\n")
    worst = 0.0
    for role, cands in cast["candidates"].items():
        default = cast["default"][role]
        level = {}
        for c in cands:
            f = os.path.join(args.dir, c["file"])
            if not os.path.exists(f):
                print(f"  ! {c['file']} absent")
                continue
            level[c["id"]] = peak_rms(load(f))
        if default not in level:
            continue
        ref = level[default]
        for c in cands:
            if c["id"] not in level:
                continue
            trim_db = 20.0 * np.log10(ref / max(level[c["id"]], 1e-12))
            clipped = float(np.clip(trim_db, -args.max_trim, args.max_trim))
            if abs(trim_db - clipped) > 0.01:
                print(f"  ! {role}/{c['id']} demande {trim_db:+.1f} dB, "
                      f"borne a {clipped:+.1f}")
            c["gain"] = round(float(10 ** (clipped / 20.0)), 4)
            c["measured_db"] = round(20.0 * np.log10(level[c["id"]]), 2)
            c["trim_db"] = round(clipped, 2)
        after = [level[c["id"]] * c["gain"] for c in cands if c["id"] in level]
        spread = 20 * np.log10(max(after) / min(after))
        worst = max(worst, spread)
        print(f"  {role:6s} " + "  ".join(
            f"{c['id']}={c['trim_db']:+.1f}dB" for c in cands if "trim_db" in c))
        print(f"         ecart residuel apres correction : {spread:.2f} dB")

    cast["level_matching"] = {
        "metric": "peak_rms(500 ms) mesure sur les .ogg rendus",
        "applied_as": "champ `gain` par candidat, applique a la lecture",
        "max_trim_db": args.max_trim,
    }
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(cast, fh, indent=2, ensure_ascii=False)
    print(f"\n  pire ecart residuel, tous roles : {worst:.2f} dB")
    print(f"  ecrit dans {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
