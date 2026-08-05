#!/usr/bin/env python3
"""
Partition — « Tri Martolod / Broceliande », theme de menu M.E.R.L.I.N.

40 mesures a 76 BPM (126,3 s), RE DORIEN, forme Intro / A A / Refrain A / Dev / Tutti / Coda.

LA MELODIE
----------
Tri Martolod est une chanson traditionnelle bretonne du XVIIIe siecle (Basse-Bretagne),
popularisee par l'arrangement d'Alan Stivell en 1971. L'air lui-meme est traditionnel :
c'est cet air-la qui est repris ici, dans un arrangement original — pas celui de Stivell.

Transcription croisee entre deux sources : le releve de thesession.org (ou les paroles
bretonnes sont alignees note a note : « tri / mar-to-lod / yao-uank ») et le Nine-Note
Tunebook de Jack Campin. Les deux concordent sur l'essentiel : la phrase chantee descend
par degres depuis la quinte.

CE QUI TOMBE BIEN : transposee en re, la melodie porte un SI NATUREL (la ligne
« D C B A » de la deuxieme mesure). En re mineur la sixte serait si bemol — ce si
naturel signe le MODE DORIEN. C'est exactement le mode dans lequel la piece etait
deja ecrite. Le theme traditionnel et l'harmonisation froide parlent la meme langue.

LA REVISITE
-----------
L'air est traite lentement (76 BPM la ou on le danse vers 120), harmonise modalement,
et pose sur la nappe FM froide et les cloches metalliques de la palette Prime. Le
developpement l'eloigne vers le majeur avant qu'un LA MAJEUR — seule note etrangere
au mode de toute la piece — ne ramene le theme en tutti.
"""

from __future__ import annotations

from itertools import combinations, permutations

# ═══════════════════════════════════════════════════════════════════════════════

BPM = 76.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
N_BARS = 40
LOOP_LEN = N_BARS * BAR                     # 126,32 s

CHORDS = {
    "Dm":  ([2, 5, 9], 50),
    "Dm7": ([2, 5, 9, 0], 50),
    "C":   ([0, 4, 7], 48),
    "G":   ([7, 11, 2], 55),                # si naturel : la couleur dorienne
    "Bb":  ([10, 2, 5], 46),
    "Am":  ([9, 0, 4], 45),
    "F":   ([5, 9, 0], 53),
    "A":   ([9, 1, 4], 45),                 # LA MAJEUR — le do diese, hors mode
}

PROGRESSION = [
    "Dm", "Dm", "C", "Dm",                          # 1-4    intro
    "Dm", "G", "F", "Dm",                           # 5-8    theme, 1re fois
    "Dm", "G", "F", "Dm",                           # 9-12   theme, 2e fois
    "Dm", "C", "Dm", "C",                           # 13-16  refrain instrumental
    "Dm", "G", "F", "Am",                           # 17-20  theme, harmonise
    "F", "C", "Dm", "Bb",                           # 21-24  developpement
    "F", "C", "G", "A",                             # 25-28  ... vers la dominante
    "Dm", "G", "F", "Dm",                           # 29-32  tutti
    "Dm", "G", "Bb", "Am",                          # 33-36  tutti, variante
    "Dm", "C", "Am", "Am",                          # 37-40  coda, retour a la boucle
]

DYNAMICS = [.28, .30, .32, .34,                     # intro : presque rien
            .40, .42, .44, .42,                     # l'air, nu
            .48, .50, .52, .50,                     # l'air, double
            .56, .58, .60, .58,                     # refrain
            .62, .64, .66, .62,                     # l'air harmonise
            .68, .72, .78, .84,                     # developpement
            .88, .92, .96, 1.00,                    # ... jusqu'a la dominante
            1.00, .98, .96, .94,                    # tutti
            .90, .86, .74, .60,                     # tutti, retrait
            .48, .40, .33, .28]                     # coda

assert len(PROGRESSION) == N_BARS and len(DYNAMICS) == N_BARS


# ═══════════════════════════════════════════════════════════════════════════════
# TRI MARTOLOD — l'air, en re dorien
# ═══════════════════════════════════════════════════════════════════════════════

_T = 1.0 / 3.0                                       # triolet dans un temps
_S = 1.0 / 6.0                                       # triolet de doubles

# La phrase chantee, 4 mesures. (mesure relative, temps, midi, duree en temps)
# « tri mar-to-lod / yao-uank / tra la la la la / tri mar-to-lod o vo-ned de ve-ajiñ »
TRI_MARTOLOD = [
    # « tri mar-to-lod / yao-uank »
    (0, 1.0, 74, 1.0),
    (0, 2.0, 74, _T), (0, 2.0 + _T, 76, _T), (0, 2.0 + 2 * _T, 74, _T),
    (0, 3.0, 72, 1.0), (0, 4.0, 77, 0.5), (0, 4.5, 76, 0.5),
    # « tra la la la la » — la descente D C B A, avec le SI NATUREL
    (1, 1.0, 74, 1.0),
    (1, 2.0, 74, 0.5), (1, 2.5, 72, 0.25), (1, 2.75, 71, 0.25),
    (1, 3.0, 69, 0.5), (1, 3.5, 71, 0.5), (1, 4.0, 72, 0.5), (1, 4.5, 69, 0.5),
    # reprise de la premiere phrase
    (2, 1.0, 74, 1.0),
    (2, 2.0, 74, _T), (2, 2.0 + _T, 76, _T), (2, 2.0 + 2 * _T, 74, _T),
    (2, 3.0, 72, 0.5), (2, 3.5, 72, 0.5), (2, 4.0, 77, 0.5), (2, 4.5, 76, 0.5),
    # cadence
    (3, 1.0, 74, 0.5), (3, 1.5, 74, 0.5), (3, 2.0, 72, 0.5), (3, 2.5, 74, 1.0),
    (3, 3.5, 69, 0.5), (3, 4.0, 69, 0.5), (3, 4.5, 69, 0.5),
]

# La phrase instrumentale (le « refrain » de la ronde), 4 mesures
REFRAIN = [
    (0, 1.0, 74, 0.5), (0, 1.5, 72, 0.5), (0, 2.0, 74, 0.5), (0, 2.5, 76, 0.5),
    (0, 3.0, 77, 0.5), (0, 3.5, 77, 0.5), (0, 4.0, 76, 0.25), (0, 4.25, 77, 0.25),
    (1, 1.0, 79, 0.5), (1, 1.5, 77, 0.5), (1, 2.0, 76, 0.5), (1, 2.5, 74, 0.5),
    (1, 3.0, 77, 1.0), (1, 4.0, 76, 1.0),
    (2, 1.0, 74, 0.5), (2, 1.5, 72, 0.5), (2, 2.0, 74, 0.5), (2, 2.5, 76, 0.5),
    (2, 3.0, 77, 0.5), (2, 3.5, 77, 0.5), (2, 4.0, 76, 0.25), (2, 4.25, 77, 0.25),
    (3, 1.0, 79, 0.5), (3, 1.5, 77, 0.5),
    (3, 2.0, 76, _S), (3, 2.0 + _S, 77, _S), (3, 2.0 + 2 * _S, 76, _S),
    (3, 2.5, 74, 0.5), (3, 3.0, 77, 1.0), (3, 4.0, 76, 0.5), (3, 4.5, 79, 0.5),
]


def place_phrase(phrase: list, bar0: int, transpose: int = 0) -> list:
    """Pose une phrase a partir d'une mesure donnee. (mesure, temps, midi, duree)."""
    return [(bar0 + b, beat, midi + transpose, dur) for (b, beat, midi, dur) in phrase]


# ── CONTRECHANT — ecrit contre l'air, en mouvement contraire ─────────────────
# Il monte quand Tri Martolod descend. C'est ce qui evite l'effet "melodie + tapis".
COUNTER = [
    (21, 1.0, 57, 2.0), (21, 3.0, 60, 2.0),
    (22, 1.0, 62, 3.0), (22, 4.0, 60, 1.0),
    (23, 1.0, 57, 2.0), (23, 3.0, 62, 2.0),
    (24, 1.0, 58, 4.0),
    (25, 1.0, 60, 2.0), (25, 3.0, 62, 2.0),
    (26, 1.0, 64, 4.0),
    (27, 1.0, 62, 2.0), (27, 3.0, 59, 2.0),
    (28, 1.0, 61, 4.0),                                  # do diese : la dominante
    (29, 1.0, 62, 2.0), (29, 3.0, 65, 2.0),
    (30, 1.0, 59, 4.0),
    (31, 1.0, 57, 2.0), (31, 3.0, 60, 2.0),
    (32, 1.0, 62, 4.0),
    (33, 1.0, 65, 2.0), (33, 3.0, 64, 2.0),
    (34, 1.0, 62, 4.0),
    (35, 1.0, 58, 4.0), (36, 1.0, 57, 4.0),
]


# ═══════════════════════════════════════════════════════════════════════════════
# CONDUITE DES VOIX
# ═══════════════════════════════════════════════════════════════════════════════

def lead_voices(prev: list[int], pcs: list[int], lo: int, hi: int) -> list[int]:
    """Chaque voix rejoint la note la plus proche de l'accord suivant.

    Une simple recherche gloutonne (chaque voix prend son plus proche) parait
    suffisante mais ne l'est pas : sur un SOL majeur elle sortait G-G-D-G, sans
    si naturel. Or ce si est la signature du mode dorien — et, ici, une note de
    la melodie traditionnelle elle-meme. On enumere donc les affectations
    completes des notes de l'accord aux voix, et on retient la moins couteuse en
    mouvement, avec une penalite forte si la tierce manque."""
    n = len(prev)
    subsets = list(combinations(range(len(pcs)), n)) if len(pcs) >= n else [tuple(range(len(pcs)))]
    best = None
    for sub in subsets:
        pen = 0.0 if 1 in sub else 7.0          # la tierce doit y etre
        if len(pcs) > 3 and 3 in sub:
            pen -= 1.5                          # la septieme, si elle existe, est bienvenue
        for perm in permutations(sub):
            cand, cost, ok = [], pen, True
            for p, idx in zip(prev, perm):
                pc = pcs[idx]
                opts = [o * 12 + pc for o in range(lo // 12, hi // 12 + 2)
                        if lo <= o * 12 + pc <= hi]
                if not opts:
                    ok = False
                    break
                m = min(opts, key=lambda x: abs(x - p))
                cand.append(m)
                cost += abs(m - p)
            if not ok:
                continue
            if len(set(cand)) < n:
                cost += 5.0                     # eviter les unissons entre voix
            if best is None or cost < best[0]:
                best = (cost, sorted(cand))
    return best[1] if best else sorted(prev)


def build_voicings() -> list[list[int]]:
    """Une voix de basse + trois voix superieures conduites, par mesure."""
    voicings = []
    prev = [57, 62, 65]
    for name in PROGRESSION:
        pcs, root = CHORDS[name]
        prev = lead_voices(prev, pcs, 55, 74)
        bass = root - 12
        while bass < 33:
            bass += 12
        voicings.append([bass] + prev)
    return voicings


def t_of(bar: int, beat: float) -> float:
    return (bar - 1) * BAR + (beat - 1.0) * BEAT


def dyn(bar: int) -> float:
    return DYNAMICS[min(max(bar, 1), N_BARS) - 1]
