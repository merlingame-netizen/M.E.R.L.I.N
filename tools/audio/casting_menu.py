#!/usr/bin/env python3
"""
Distribution contextuelle — on REMPLACE un instrument, on n'en empile pas un de plus.

CE QUI CHANGE PAR RAPPORT AUX SURCOUCHES
----------------------------------------
La version precedente ajoutait douze pistes par-dessus le mix : s'il pleuvait, un oud
ARRIVAIT en plus. C'etait un empilement, et ca s'entendait comme tel — un instrument
colle sur un morceau deja complet.

Ici l'effectif ne change jamais. Trois ROLES sont tenus en permanence, et le contexte
decide seulement QUI les tient. S'il pleut, ce n'est pas qu'un oud s'ajoute : c'est
que la guitare celtique s'en va et que l'oud prend sa place, aux memes notes, au meme
moment, au meme niveau. Le morceau garde exactement la meme densite.

LES TROIS ROLES
---------------
  chant   qui porte Tri Martolod
  corde   l'accompagnement pince, celui qui remplit l'espace entre les phrases
  halo    le scintillement du registre aigu

Tout le reste — cordes, bois d'harmonie, harpe, percussion douce — est le SOCLE, qui
ne bouge jamais.

POURQUOI CA MARCHE TECHNIQUEMENT
--------------------------------
Un role est rendu une fois par candidat, avec EXACTEMENT les memes notes aux memes
instants. Basculer d'un candidat a l'autre est donc un simple fondu croise entre deux
fichiers cales sur la meme boucle : rien ne se decale, rien ne se dedouble. Un seul
candidat par role est audible a la fois — c'est ce qui fait un remplacement et non
une superposition.

Chaque candidat porte sa TESSITURE reellement enregistree, et la partie y est
repliee par octaves. Un psalterion ne descend pas ou va une guitare, et des verres
frottes ne montent pas ou va un celesta ; sans ce repli le lecteur d'echantillons
transposait jusqu'a 13 demi-tons, ce qui change la taille apparente de la caisse en
meme temps que la hauteur. Replier par octaves conserve la classe de hauteur, donc
la consonance avec le socle.

    python3 tools/audio/casting_menu.py       # inventaire + controle de couverture
"""

from __future__ import annotations

# ═══════════════════════════════════════════════════════════════════════════════
# LES CANDIDATS
# ═══════════════════════════════════════════════════════════════════════════════
# role -> id de candidat -> (instrument du moteur, gain, tessiture, libelle)
#
# LA TESSITURE N'EST PAS DECORATIVE. C'est l'etendue REELLEMENT enregistree dans
# la banque, et les parties y sont repliees par octaves avant d'etre jouees.
#
# Sans ce repli, la meme partie confiee a des instruments d'etendues differentes
# forcait le lecteur d'echantillons a transposer jusqu'a 13 demi-tons : le
# psalterion, enregistre de la#3 a fa#5, devait descendre a la2. Transposer un
# echantillon d'une octave deplace ses formants avec la hauteur — la caisse
# semble changer de taille, et l'oreille entend l'artifice immediatement.
#
# Replier par OCTAVES et non transposer d'un intervalle quelconque : la classe
# de hauteur est conservee, donc la note replieee reste consonante avec
# l'harmonie du socle. C'est ce qui permet de garder une seule ecriture pour
# tous les candidats d'un role.

CANDIDATES = {
    "chant": {
        "cor_anglais": ("cor_anglais", 1.00, (46, 77), "Cor anglais"),
        "flute":       ("flute",       0.92, (48, 84), "Flûte"),
        "ocarina":     ("ocarina",     1.05, (57, 73), "Ocarina"),
        "harmonica":   ("harmonica",   0.95, (36, 84), "Harmonica"),
    },
    "corde": {
        "celtic_guitar": ("celtic_guitar", 1.00, (24, 80), "Guitare celtique"),
        "oud":           ("oud",           0.95, (40, 76), "Oud"),
        "dan_tranh":     ("dan_tranh",     1.00, (35, 71), "Đàn tranh"),
        "kalimba":       ("kalimba",       0.95, (31, 85), "Kalimba"),
        "psaltery":      ("psaltery",      0.90, (58, 78), "Psaltérion"),
    },
    "halo": {
        "celesta":      ("celesta",      1.00, (67, 96), "Célesta"),
        "wine_glasses": ("wine_glasses", 1.05, (63, 74), "Verres frottés"),
        "hand_chimes":  ("hand_chimes",  0.95, (48, 84), "Clochettes à main"),
    },
}


def fold(midi: int, span: tuple[int, int]) -> int:
    """Ramene une note dans la tessiture d'un candidat, par octaves entieres."""
    lo, hi = span
    while midi < lo:
        midi += 12
    while midi > hi:
        midi -= 12
    return max(lo, min(hi, midi))

DEFAULT = {"chant": "cor_anglais", "corde": "celtic_guitar", "halo": "celesta"}

# ═══════════════════════════════════════════════════════════════════════════════
# LES CONTEXTES
# ═══════════════════════════════════════════════════════════════════════════════
# Un contexte ne redistribue que ce qu'il a une raison de redistribuer. Les roles
# absents d'une entree gardent leur titulaire — c'est ce qui permet de cumuler
# les trois axes sans qu'ils se contredisent : la meteo prend la main sur la
# saison, qui prend la main sur le moment, role par role.

AXES = {
    "meteo":  ["clair", "couvert", "pluie", "brume", "neige"],
    "saison": ["printemps", "ete", "automne", "hiver"],
    "moment": ["aube", "jour", "crepuscule", "nuit"],
}

# ordre de priorite : le premier qui se prononce sur un role l'emporte
PRIORITY = ["meteo", "saison", "moment"]

CONTEXT = {
    # ── meteo ────────────────────────────────────────────────────────────────
    # La pluie appelle l'oud : un luth sans frettes, corps rond, attaque au risha.
    # C'est la demande d'origine, et c'est aussi le bon choix — le glissando d'un
    # manche sans frettes fait entendre quelque chose qui coule.
    "pluie":     {"corde": "oud"},
    "brume":     {"halo": "wine_glasses"},
    "neige":     {"halo": "hand_chimes", "corde": "psaltery"},
    "couvert":   {},
    "clair":     {},
    # ── saison ───────────────────────────────────────────────────────────────
    "printemps": {"corde": "kalimba", "chant": "flute"},
    "ete":       {"chant": "flute"},
    "automne":   {"chant": "harmonica"},
    "hiver":     {"corde": "psaltery", "halo": "wine_glasses"},
    # ── moment ───────────────────────────────────────────────────────────────
    "aube":      {"chant": "ocarina"},
    "jour":      {},
    "crepuscule": {"chant": "harmonica"},
    "nuit":      {"corde": "dan_tranh", "halo": "hand_chimes"},
}


def resolve(context: dict) -> dict:
    """{'meteo': 'pluie', 'saison': 'hiver'} -> {'chant': ..., 'corde': ..., 'halo': ...}

    Role par role, le premier axe de PRIORITY qui se prononce l'emporte. Un axe
    muet sur un role laisse passer le suivant, et le titulaire par defaut ferme
    la marche — il y a donc toujours exactement un instrument par role."""
    out = dict(DEFAULT)
    decided: set = set()
    for axis in PRIORITY:
        value = context.get(axis)
        for role, cand in CONTEXT.get(value, {}).items():
            if role not in decided:
                out[role] = cand
                decided.add(role)
    return out


def all_parts() -> list[tuple[str, str]]:
    """Toutes les paires (role, candidat) a rendre."""
    return [(r, c) for r, cands in CANDIDATES.items() for c in cands]


def manifest() -> dict:
    return {
        "roles": list(CANDIDATES),
        "default": DEFAULT,
        "axes": AXES,
        "priority": PRIORITY,
        "context": CONTEXT,
        "candidates": {
            role: [{"id": cid, "label": lab, "instrument": inst,
                    "range": list(span), "gain": g, "file": f"{role}__{cid}.ogg"}
                   for cid, (inst, g, span, lab) in cands.items()]
            for role, cands in CANDIDATES.items()
        },
    }


def main() -> int:
    import json
    parts = all_parts()
    print(f"{len(CANDIDATES)} roles, {len(parts)} parties a rendre\n")
    for role, cands in CANDIDATES.items():
        d = DEFAULT[role]
        print(f"  {role:8s} " + " · ".join(
            f"{'[' + lab + ']' if cid == d else lab}"
            for cid, (_i, _g, _s, lab) in cands.items()))
    print()

    # Controle 1 : tout candidat nomme par un contexte doit exister.
    bad = [(v, r, c) for v, m in CONTEXT.items() for r, c in m.items()
           if c not in CANDIDATES.get(r, {})]
    for v, r, c in bad:
        print(f"  ! contexte '{v}' demande {r}={c}, qui n'existe pas")

    # Controle 2 : toute valeur d'axe doit avoir une entree, meme vide.
    missing = [v for vals in AXES.values() for v in vals if v not in CONTEXT]
    for v in missing:
        print(f"  ! valeur d'axe '{v}' sans entree dans CONTEXT")

    # Controle 3 : une distribution complete pour chaque combinaison d'axes.
    from itertools import product
    holes = 0
    for combo in product(*AXES.values()):
        ctx = dict(zip(AXES, combo))
        cast = resolve(ctx)
        if set(cast) != set(CANDIDATES):
            holes += 1
    print(f"  {'OK' if not (bad or missing or holes) else 'INCOMPLET'} — "
          f"{len(list(product(*AXES.values())))} combinaisons, {holes} incomplete(s)\n")

    for ctx in ({"meteo": "pluie"}, {"saison": "hiver"}, {"moment": "nuit"},
                {"meteo": "pluie", "saison": "hiver", "moment": "nuit"},
                {"meteo": "neige", "saison": "printemps"}):
        print(f"  {str(ctx):58s} -> {resolve(ctx)}")
    return 0 if not (bad or missing or holes) else 1


if __name__ == "__main__":
    raise SystemExit(main())
