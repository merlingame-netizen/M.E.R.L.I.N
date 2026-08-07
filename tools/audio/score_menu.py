#!/usr/bin/env python3
"""
Partition — « Tri Martolod / Broceliande », theme de menu M.E.R.L.I.N.

40 mesures a 49 BPM (195,9 s), RE DORIEN, forme Intro / A A / Refrain A / Dev / Plein / Coda.

LA MELODIE
----------
Tri Martolod est une chanson traditionnelle bretonne du XVIIIe siecle (Basse-Bretagne),
popularisee par l'arrangement d'Alan Stivell en 1971. L'air lui-meme est traditionnel :
c'est cet air-la qui est repris ici, dans un arrangement original — pas celui de Stivell.

Transcription croisee entre deux relevés publics — thesession.org et le Nine-Note
Tunebook de Jack Campin. Les deux concordent sur l'essentiel : la phrase chantee descend
par degres depuis la quinte. Seul l'air est repris ; l'arrangement est entierement
original et la piece est purement instrumentale.

CE QUI TOMBE BIEN : transposee en re, la melodie porte un SI NATUREL (la ligne
« D C B A » de la deuxieme mesure). En re mineur la sixte serait si bemol — ce si
naturel signe le MODE DORIEN. C'est exactement le mode dans lequel la piece etait
deja ecrite. Le theme traditionnel et l'harmonisation froide parlent la meme langue.

LA REVISITE
-----------
L'air est traite tres lentement (49 BPM la ou on le danse vers 120), harmonise
modalement, et pose sur les cloches metalliques de la palette Prime. Le developpement
l'eloigne vers le majeur avant qu'un LA MAJEUR — seule note etrangere au mode de
toute la piece — ne ramene le theme en tutti.

LE TEMPO ET LA COULEUR
----------------------
76 BPM au depart, puis 58, maintenant 49. A 76 la piece restait une marche : les notes
se succedent assez vite pour qu'on entende une suite, pas un etat. A 49 la noire dure
1,22 s et la mesure 4,90 s — il y a enfin de la place ENTRE les notes, qui est le seul
endroit ou le feerique puisse se loger.

Ce qui a ete RETIRE compte autant que le tempo. Trois familles sont sorties :
  - les anches synthetisees (bombarde, biniou, bourdon, tin whistle) : une anche
    double se reconnait a sa crudite, et synthetisee elle n'est que crue ;
  - les cuivres au complet (tutti, trompettes, trombone, tuba) : c'est ce qui
    rendait le sommet claquant plutot que lumineux ;
  - les percussions franches (taiko, cymbale, tam-tam, caisse claire) et les
    nappes electroniques (nappe FM, sub, choeur).
Restent des instruments reellement enregistres, plus les timbres cristallins —
celesta, cloches, verres, psalterion — qui portent le registre feerique.

L'AIR EST ORNE. Voir ornament() : appoggiatures, notes de passage, cadences brodees.
Le premier enonce reste nu — un ornement n'orne que ce qu'on a deja entendu simple.
"""

from __future__ import annotations

from itertools import combinations, permutations

import numpy as np

# ═══════════════════════════════════════════════════════════════════════════════

N_BARS = 40

# LA BOUCLE EST DEFINIE EN ECHANTILLONS, PAS EN SECONDES — et le tempo en decoule.
#
# C'est contre-intuitif pour une partition, et c'est pourtant ce qui fait la
# difference entre un rendu de dix minutes et un rendu de deux heures. Tout le
# moteur filtre par FFT sur des tableaux de la longueur de la boucle. A 58,000 BPM
# exactement, cette longueur valait 7 299 299 echantillons, dont la factorisation
# est 7 x 239 x 4363 : numpy tombe alors sur son chemin lent et une seule FFT
# coute 3,8 s au lieu de 0,35. Avec une quinzaine de filtrages par stem et
# seize rendus, la difference se compte en heures.
#
# 8 640 000 = 2^7 x 3^3 x 5^4. Tous les facteurs sont petits, la FFT est rapide —
# et le tempo qui en decoule tombe sur 49,000 BPM tout rond.
SR = 44100
# MERLIN_TEMPO_SCALE : rendu a un AUTRE tempo reel (v7). La nuit est rendue a
# 0,8 — la boucle passe a 10 800 000 = 2^4 x 3^3 x 5^5, TOUJOURS 5-lisse (la
# division par 4/5 multiplie par 5/4). C'est ce qui donne une boite a musique
# LENTE A HAUTEUR NORMALE : aucun etirement, aucun varispeed, un vrai rendu.
import os as _os
TEMPO_SCALE = float(_os.environ.get("MERLIN_TEMPO_SCALE", "1.0"))
LOOP_SAMPLES = int(round(8_640_000 / TEMPO_SCALE))
LOOP_LEN = LOOP_SAMPLES / SR                # 195,918 s a l'echelle 1,0
BPM = N_BARS * 4 * 60.0 / LOOP_LEN          # 49,000 tout rond a l'echelle 1,0
BEAT = 60.0 / BPM
BAR = 4 * BEAT

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
    "F", "C", "Dm", "G",                            # 21-24  developpement
    "F", "C", "G", "Am",                            # 25-28  ... suspension modale
    "Dm", "G", "F", "Dm",                           # 29-32  tutti
    "Dm", "G", "C", "Am",                           # 33-36  tutti, variante
    "Dm", "C", "Am", "Am",                          # 37-40  coda, retour a la boucle
]

# Arc encore rabote. Il culminait a 1,00 sur six mesures, puis a 0,84 ; il monte
# maintenant a 0,70 et redescend aussitot. Un sommet, dans une piece feerique, ne
# se fabrique pas en montant le volume mais en ouvrant le registre — c'est le
# glockenspiel et les verres qui marquent la mesure 29, pas la force.
DYNAMICS = [.16, .18, .20, .22,                     # intro : presque rien
            .28, .30, .32, .30,                     # l'air, nu
            .36, .38, .40, .38,                     # l'air, double et orne
            .42, .44, .46, .44,                     # refrain
            .48, .50, .52, .49,                     # l'air harmonise
            .52, .55, .58, .61,                     # developpement
            .64, .66, .68, .70,                     # ... jusqu'a la dominante
            .70, .68, .66, .64,                     # plein — cristallin, pas fort
            .60, .56, .48, .40,                     # retrait
            .32, .26, .21, .16]                     # coda

assert len(PROGRESSION) == N_BARS and len(DYNAMICS) == N_BARS


# ═══════════════════════════════════════════════════════════════════════════════
# TRI MARTOLOD — l'air, en re dorien
# ═══════════════════════════════════════════════════════════════════════════════

_T = 1.0 / 3.0                                       # triolet dans un temps
_S = 1.0 / 6.0                                       # triolet de doubles

# La phrase chantee, 4 mesures. (mesure relative, temps, midi, duree en temps)
TRI_MARTOLOD = [
    # premiere phrase
    (0, 1.0, 74, 1.0),
    (0, 2.0, 74, _T), (0, 2.0 + _T, 76, _T), (0, 2.0 + 2 * _T, 74, _T),
    (0, 3.0, 72, 1.0), (0, 4.0, 77, 0.5), (0, 4.5, 76, 0.5),
    # la descente RE DO SI LA, avec le SI NATUREL qui signe le mode
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

def ornament(phrase: list, seed: int = 0, amount: float = 1.0) -> list:
    """Version ornee de l'air — c'est ce qui separe une melodie d'une suite de notes.

    Trois ornements, tous pris au repertoire celtique et places la ou un joueur
    les placerait :

      - APPOGGIATURE : sur une note longue precedee d'un saut ascendant, on
        attaque un degre au-dessus et on retombe. Coute un tiers de la note.
      - NOTE DE PASSAGE : entre deux notes distantes d'une tierce, on remplit
        le trou. C'est ce qui rend la ligne conjointe donc chantante.
      - CADENCE BRODEE : la derniere note d'une phrase est precedee de sa
        voisine superieure, tres bref.

    On n'orne PAS le premier enonce : l'air doit d'abord etre entendu nu, sinon
    l'ornement n'orne rien. Les reprises seules sont brodees.

    amount (v7) : la DOSE d'ornementation, 0..1. « La partition doit etre
    fidele avec quelques twists mais le motif garde a 100 % » — a 0,35 chaque
    ornement ne se produit qu'une fois sur trois : la ligne traditionnelle
    domine, la broderie est l'exception. Toute note ornee retombe sur les
    notes ECRITES du motif : un ornement decore, il ne remplace jamais.
    """
    rng = np.random.default_rng(seed + 5150)
    # degres du mode de re dorien, pour que tout ornement reste dans le mode :
    # une broderie chromatique sonnerait comme une fausse note, pas comme un ornement
    SCALE = (2, 4, 5, 7, 9, 11, 0)                   # re mi fa sol la si do

    def up(m: int) -> int:
        k = 1
        while (m + k) % 12 not in SCALE:
            k += 1
        return m + k

    def down(m: int) -> int:
        k = 1
        while (m - k) % 12 not in SCALE:
            k += 1
        return m - k

    out: list = []
    for i, (bar, beat, midi, dur) in enumerate(phrase):
        nxt = phrase[i + 1] if i + 1 < len(phrase) else None
        prev = phrase[i - 1] if i else None
        gap = (nxt[2] - midi) if nxt else 0

        # 1. NOTE DE PASSAGE — comble un saut de tierce, dans le mode.
        #    C'est l'ornement qui rend la ligne conjointe, donc chantante.
        if nxt and abs(gap) in (3, 4) and dur >= 0.5 and rng.random() < amount:
            mid = up(midi) if gap > 0 else down(midi)
            out.append((bar, beat, midi, dur * 0.6))
            out.append((bar, beat + dur * 0.6, mid, dur * 0.4))
            continue

        # 2. APPOGGIATURE — sur une longue abordee par saut : on attaque au-dessus.
        if dur >= 1.0 and prev and abs(midi - prev[2]) >= 3 and rng.random() < amount * 0.8:
            out.append((bar, beat, up(midi), dur * 0.28))
            out.append((bar, beat + dur * 0.28, midi, dur * 0.72))
            continue

        # 3. GRUPETTO — sur une longue tenue sans saut : note, voisine, note.
        #    Trois notes la ou il y en avait une : c'est le coeur du « plus melodique ».
        if dur >= 1.0 and rng.random() < 0.55 * amount:
            out.append((bar, beat, midi, dur * 0.45))
            out.append((bar, beat + dur * 0.45, up(midi), dur * 0.2))
            out.append((bar, beat + dur * 0.65, midi, dur * 0.35))
            continue

        # 4. CADENCE BRODEE — la voisine superieure, tres brievement, avant la fin.
        if nxt is None and dur >= 0.5 and rng.random() < max(amount, 0.3):
            out.append((bar, beat, up(midi), dur * 0.22))
            out.append((bar, beat + dur * 0.22, midi, dur * 0.78))
            continue

        out.append((bar, beat, midi, dur))
    return out


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
