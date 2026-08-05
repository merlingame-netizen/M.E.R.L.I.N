#!/usr/bin/env python3
"""
Partition — « Broceliande », theme de menu M.E.R.L.I.N.

32 mesures a 66 BPM (116,4 s), re dorien, forme A A' B A''.

CE QUI EST ECRIT ICI, ET POURQUOI :

  CONDUITE DES VOIX — les accords ne sont pas plaques en position fondamentale.
  Chaque voix rejoint la note la plus proche de l'accord suivant. C'est la
  difference entre un orchestre et un clavier : les lignes interieures bougent
  peu, et cette immobilite relative est ce qui rend l'harmonie fluide.

  ARC DYNAMIQUE — une courbe de nuance par mesure, de 0,34 (intro) a 1,0
  (tutti mesure 25) puis retour a 0,36 pour boucler. La velocite ne pilote pas
  que le volume : elle ouvre aussi le spectre de chaque instrument.

  ORCHESTRATION PAR SECTION — A : cordes seules et hautbois. A' : pizzicati,
  harpe, cor. B : developpement, tremolos, choeur, crescendo. A'' : tutti,
  cuivres et glockenspiel, puis desagregation jusqu'au point de boucle.

  LE MOMENT DRAMATIQUE — mesure 24, un LA MAJEUR. Le do diese est etranger au
  mode dorien : c'est la seule note hors-mode de la piece, et elle sert de
  dominante pour ramener au retour du theme. Tout converge la.
"""

from __future__ import annotations

from itertools import combinations, permutations

# ═══════════════════════════════════════════════════════════════════════════════

BPM = 66.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
N_BARS = 32
LOOP_LEN = N_BARS * BAR                     # 116,36 s

# Accords : (classes de hauteur, fondamentale midi de reference)
CHORDS = {
    "Dm":  ([2, 5, 9], 50),
    "Dm7": ([2, 5, 9, 0], 50),
    "C":   ([0, 4, 7], 48),
    "G":   ([7, 11, 2], 55),
    "Bb":  ([10, 2, 5], 46),
    "Am":  ([9, 0, 4], 45),
    "F":   ([5, 9, 0], 53),
    "A":   ([9, 1, 4], 45),                 # LA MAJEUR — le do diese, hors mode
}

#            A (1-8)                          A' (9-16)
PROGRESSION = ["Dm", "Dm", "C", "C", "Dm", "Dm", "G", "G",
               "Dm", "Dm7", "C", "C", "Bb", "Bb", "Am", "Am",
               # B (17-24) — region majeure, puis la dominante
               "F", "F", "C", "C", "Dm", "Dm", "Bb", "A",
               # A'' (25-32) — retour tutti puis desagregation
               "Dm", "Dm", "C", "G", "Dm", "Bb", "Am", "Am"]

# Nuance par mesure. C'est la respiration de la piece.
DYNAMICS = [.34, .38, .42, .44, .46, .50, .54, .50,      # A   — s'installe
            .56, .58, .60, .62, .66, .68, .64, .60,      # A'  — s'etoffe
            .62, .66, .70, .74, .80, .86, .92, .97,      # B   — crescendo continu
            1.0, .98, .94, .96, .88, .74, .56, .36]      # A'' — tutti puis retrait

# ── THEME ────────────────────────────────────────────────────────────────────
# (mesure, temps, midi, duree en temps). Mesures et temps 1-indexes.
THEME_A = [
    (2, 4.0, 69, 1.0),
    (3, 1.0, 74, 2.0), (3, 3.0, 72, 1.0), (3, 4.0, 71, 1.0),
    (4, 1.0, 69, 3.0), (4, 4.0, 67, 1.0),
    (5, 1.0, 65, 2.0), (5, 3.0, 67, 1.0), (5, 4.0, 69, 1.0),
    (6, 1.0, 69, 4.0),
    (7, 1.0, 71, 2.0), (7, 3.0, 74, 2.0),
    (8, 1.0, 72, 3.0), (8, 4.0, 69, 1.0),
]
# Reprise ornementee, un ton plus haut dans la tessiture
THEME_A2 = [
    (10, 3.0, 74, 1.0), (10, 4.0, 76, 1.0),
    (11, 1.0, 77, 2.0), (11, 3.0, 76, 1.0), (11, 4.0, 74, 1.0),
    (12, 1.0, 72, 3.0), (12, 4.0, 74, 1.0),
    (13, 1.0, 77, 2.0), (13, 3.0, 74, 1.0), (13, 4.0, 72, 1.0),
    (14, 1.0, 74, 4.0),
    (15, 1.0, 72, 2.0), (15, 3.0, 69, 1.5), (15, 4.5, 67, 1.5),
    (16, 2.0, 69, 3.0),
]
# Developpement : montee continue vers le do diese
THEME_B = [
    (17, 1.0, 69, 2.0), (17, 3.0, 72, 2.0),
    (18, 1.0, 74, 3.0), (18, 4.0, 72, 1.0),
    (19, 1.0, 76, 2.0), (19, 3.0, 74, 1.0), (19, 4.0, 72, 1.0),
    (20, 1.0, 67, 4.0),
    (21, 1.0, 77, 2.0), (21, 3.0, 76, 2.0),
    (22, 1.0, 74, 4.0),
    (23, 1.0, 77, 2.0), (23, 3.0, 74, 2.0),
    (24, 1.0, 73, 4.0),                                   # do diese — le point de bascule
]
# Retour, puis effacement
THEME_A3 = [
    (25, 1.0, 74, 2.0), (25, 3.0, 72, 1.0), (25, 4.0, 71, 1.0),
    (26, 1.0, 69, 4.0),
    (27, 1.0, 67, 2.0), (27, 3.0, 69, 2.0),
    (28, 1.0, 71, 4.0),
    (29, 1.0, 69, 3.0), (29, 4.0, 67, 1.0),
    (30, 1.0, 65, 4.0),
    (31, 1.0, 69, 3.0), (31, 4.0, 67, 1.0),
    (32, 1.0, 64, 2.0),
]

# ── CONTRECHANT — mouvement contraire au theme, entre en B ───────────────────
COUNTER = [
    (17, 3.0, 57, 2.0), (18, 1.0, 60, 2.0), (18, 3.0, 59, 2.0),
    (19, 1.0, 57, 4.0), (20, 1.0, 55, 3.0), (20, 4.0, 57, 1.0),
    (21, 1.0, 58, 2.0), (21, 3.0, 57, 2.0), (22, 1.0, 55, 4.0),
    (23, 1.0, 58, 2.0), (23, 3.0, 57, 2.0), (24, 1.0, 61, 4.0),
    (25, 1.0, 62, 2.0), (25, 3.0, 65, 2.0), (26, 1.0, 64, 4.0),
    (27, 1.0, 64, 2.0), (27, 3.0, 62, 2.0), (28, 1.0, 59, 4.0),
    (29, 1.0, 62, 4.0), (30, 1.0, 58, 4.0),
]


# ═══════════════════════════════════════════════════════════════════════════════
# CONDUITE DES VOIX
# ═══════════════════════════════════════════════════════════════════════════════

def lead_voices(prev: list[int], pcs: list[int], lo: int, hi: int) -> list[int]:
    """Chaque voix rejoint la note la plus proche de l'accord suivant.

    Une simple recherche gloutonne (chaque voix prend son plus proche) parait
    suffisante mais ne l'est pas : sur un SOL majeur elle sortait G-G-D-G, sans
    si naturel. Or ce si est la signature du mode dorien — perdre la tierce vide
    l'accord de son sens. On enumere donc les affectations completes des notes
    de l'accord aux voix, et on retient la moins couteuse en mouvement, avec une
    penalite forte si la tierce manque et un bonus si la septieme est prise."""
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
    prev = [57, 62, 65]                                   # position de depart (A3 D4 F4)
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
