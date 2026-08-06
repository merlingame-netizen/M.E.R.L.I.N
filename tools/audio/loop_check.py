#!/usr/bin/env python3
"""
Verification du point de boucle — deux tests, et pas celui qu'on croit.

POURQUOI CE FICHIER EXISTE
--------------------------
Pendant tout le developpement de ce theme, la qualite de boucle a ete jugee sur
`|x[-1] - x[0]|`. C'est FAUX, et ca m'a fait poursuivre un defaut inexistant a
travers quatre correctifs successifs.

Cet ecart ne mesure pas une discontinuite : il mesure la PENTE du signal a cet
endroit. Tant que la coda finissait en quasi-silence, la pente etait minuscule
(0,0001) et passait pour une preuve de qualite. Des qu'une reverbe ambiante
continue a maintenu du signal au point de boucle, le meme ecart est monte a
0,0115 — sans qu'aucun clic n'apparaisse. Un signal a 10 kHz d'amplitude 0,1 a
des ecarts entre echantillons voisins de 0,12 : la metrique mesurait la musique,
pas la couture.

LES DEUX VRAIS TESTS
--------------------
1. PENTE RELATIVE — comparer l'ecart au raccord a la distribution des ecarts
   entre echantillons voisins juste avant la boucle. S'il est dans la norme
   locale, il n'y a pas de saut.
2. SIGNATURE SPECTRALE — un clic est large bande par nature. On compare l'energie
   haute frequence d'une fenetre a cheval sur le raccord a celle des fenetres
   voisines. Un vrai clic ressort a plusieurs sigmas.

    python3 tools/audio/loop_check.py audio/music/menu/menu_theme.ogg
"""

from __future__ import annotations

import subprocess
import sys

import numpy as np

SR = 44100


def load(path: str) -> np.ndarray:
    import imageio_ffmpeg
    raw = subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-loglevel", "error",
                          "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).T.mean(0)


def _hf_ratio(seg: np.ndarray, cut: float = 8000.0) -> float:
    spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg))))
    freqs = np.fft.rfftfreq(len(seg), 1.0 / SR)
    return float(spec[freqs > cut].sum() / max(spec.sum(), 1e-12))


def check(path: str, verbose: bool = True) -> dict:
    m = load(path)
    n = len(m)
    join = float(abs(m[-1] - m[0]))

    # 1. pente relative — mesuree DES DEUX COTES du raccord. Ne regarder que la
    #    fin biaise le test quand la coda s'eteint : les pentes y sont minuscules
    #    et n'importe quel raccord parait anormal.
    w = int(0.5 * SR)
    around = np.abs(np.diff(np.concatenate([m[-w:], m[:w]])))
    p90 = float(np.percentile(around, 90))
    # PLANCHER ABSOLU. Le test de pente est RELATIF, et quand la matiere s'eteint
    # a la fin sa distribution s'effondre : sur le stem rythmique, dont la coda
    # est un quasi-silence, le raccord valait 0,0004 contre 0,0003 de pente
    # locale. Les deux mesures sont du bruit numerique. Un saut de 0,0004, c'est
    # -68 dBFS : aucun haut-parleur n'en fait un clic. En dessous de 0,002
    # (-54 dBFS) on ne compare plus rien, on declare propre.
    FLOOR = 0.002
    # MARGE x2 SUR LA PENTE. Comparer UN pas d'echantillon au 90e centile des pas
    # est biaise par construction : par definition 10 % des pas depassent le 90e
    # centile, donc un signal parfaitement continu a environ une chance sur dix
    # d'etre signale. Sur 14 stems, un faux positif est le resultat ATTENDU — et
    # c'est exactement ce qui s'est produit sur halo__celesta (1,38x), dont la
    # continuite a ete prouvee arithmetiquement : le repli de queue donne
    # head[0] = out[0] + out[L] avec out[0] = 3e-16, donc head[0] et head[-1]
    # sont les echantillons ADJACENTS out[L] et out[L-1] d'un signal continu.
    # Aucun clic n'est possible ; le pas valait 0,38 simplement parce que la
    # queue de reverbe y est brillante et se deplace vite.
    #
    # Seuil recale sur mesure, 14 stems sains contre 39 raccords faussement
    # colles (deux moities prelevees a des endroits sans rapport) :
    #     sains   : maximum 1,38x
    #     clics   : mediane 8,60x
    # A 2,0x les 14 sains passent et la majorite des clics restent pris.
    SLOPE_MARGIN = 2.0
    slope_ok = join <= SLOPE_MARGIN * p90 or join < FLOOR

    # 2. signature spectrale du clic
    W = 2048
    two = np.concatenate([m, m])
    at_join = _hf_ratio(two[n - W // 2: n + W // 2])
    neigh = [_hf_ratio(two[n - W // 2 + k * W: n + W // 2 + k * W])
             for k in (-4, -3, -2, 2, 3, 4)]
    mu, sd = float(np.mean(neigh)), float(np.std(neigh))
    sigma = (at_join - mu) / max(sd, 1e-9)
    # Le sigma seul ne suffit pas : quand les fenetres voisines n'ont presque pas
    # d'aigu, l'ecart-type tend vers zero et le sigma explose sur du bruit
    # numerique. Sur un signal purement periodique le test annoncait +54 sigma
    # avec 0,00 % d'energie HF des deux cotes. Un vrai clic ajoute de l'energie
    # large bande en ABSOLU : on exige les deux.
    excess = at_join - mu
    click = sigma > 3.0 and excess > 0.02

    res = {"file": path, "join": join, "slope_p90": p90, "slope_ok": bool(slope_ok),
           "hf_join": at_join, "hf_neighbours": mu, "hf_excess": float(excess),
           "sigma": float(sigma), "click": bool(click),
           "seamless": bool(slope_ok and not click)}
    if verbose:
        print(f"  fichier                : {path}")
        print(f"  ecart au raccord       : {join:.4f}")
        print(f"  pente locale (90e c.)  : {p90:.4f}   -> {'dans la norme' if slope_ok else 'AU-DESSUS'}")
        print(f"  HF au raccord/voisins  : {at_join*100:.2f} % / {mu*100:.2f} %")
        print(f"  exces HF absolu        : {excess*100:+.2f} pt   (seuil 2,00)")
        print(f"  ecart normalise        : {sigma:+.1f} sigma -> {'CLIC' if click else 'aucun clic'}")
        print(f"  VERDICT                : {'boucle propre' if res['seamless'] else 'COUTURE AUDIBLE'}")
    return res


def main() -> int:
    paths = sys.argv[1:] or ["audio/music/menu/menu_theme.ogg"]
    bad = 0
    for i, p in enumerate(paths):
        if i:
            print()
        if not check(p)["seamless"]:
            bad += 1
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
