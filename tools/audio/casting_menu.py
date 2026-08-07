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
        # Pupitres VPO a tenues bouclees — tessitures relevees dans le manifeste
        "violon":      ("violin_solo", 1.00, (55, 94), "Violon"),
        "hautbois":    ("oboe",        1.00, (58, 84), "Hautbois"),
        "clarinette":  ("clarinet",    1.00, (53, 91), "Clarinette"),
        "basson":      ("bassoon",     1.00, (34, 70), "Basson"),
    },
    "corde": {
        "celtic_guitar": ("celtic_guitar", 1.00, (24, 80), "Guitare celtique"),
        "oud":           ("oud",           0.95, (40, 76), "Oud"),
        "dan_tranh":     ("dan_tranh",     1.00, (35, 71), "Đàn tranh"),
        "kalimba":       ("kalimba",       0.95, (31, 85), "Kalimba"),
        "psaltery":      ("psaltery",      0.90, (58, 78), "Psaltérion"),
        "harpe":         ("harp",          1.00, (38, 101), "Harpe"),
        "mbira":         ("mbira",         1.00, (34, 73),  "Mbira"),
    },
    "halo": {
        "celesta":      ("celesta",      1.00, (67, 96), "Célesta"),
        "wine_glasses": ("wine_glasses", 1.05, (63, 74), "Verres frottés"),
        "hand_chimes":  ("hand_chimes",  0.95, (48, 84), "Clochettes à main"),
        "glockenspiel": ("glockenspiel", 0.95, (79, 108), "Glockenspiel"),
    },
    # Le POULS — sorti du socle pour devenir remplacable. Un tambour d'orage
    # doit REMPLACER la frappe calme, jamais s'y ajouter.
    # Chaque titulaire du pouls est une ECRITURE differente, pas seulement un
    # autre tambour : la substitution de rythme passe par la. Le tempo, lui, ne
    # bouge jamais — c'est la condition pour que la boucle reste calee.
    "pulse": {
        "calme":  ("bodhran",    1.00, (36, 60), "Calme"),
        "danse":  ("bodhran",    1.00, (36, 60), "Danse"),
        "orage":  ("bodhran",    1.10, (36, 60), "Orage"),
        "ondee":  ("ocean_drum", 1.00, (48, 72), "Ondée"),
        "sourd":  ("taiko",      1.00, (33, 57), "Sourd"),
        "nuit":   ("slit_drum",  1.00, (33, 72), "Nuit"),
        "aucun":  ("bodhran",    1.00, (36, 60), "Aucun"),
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

DEFAULT = {
    "pulse": "calme", "chant": "cor_anglais", "corde": "celtic_guitar", "halo": "celesta"}

# ═══════════════════════════════════════════════════════════════════════════════
# LES CONTEXTES
# ═══════════════════════════════════════════════════════════════════════════════
# Un contexte ne redistribue que ce qu'il a une raison de redistribuer. Les roles
# absents d'une entree gardent leur titulaire — c'est ce qui permet de cumuler
# les trois axes sans qu'ils se contredisent : la meteo prend la main sur la
# saison, qui prend la main sur le moment, role par role.

AXES = {
    "meteo":  ["clair", "couvert", "pluie", "orage", "brume", "neige"],
    "saison": ["printemps", "ete", "automne", "hiver"],
    "moment": ["aube", "jour", "crepuscule", "nuit"],
}

# ordre de priorite : le premier qui se prononce sur un role l'emporte
PRIORITY = ["meteo", "saison", "moment"]

CONTEXT = {
    # ── meteo ────────────────────────────────────────────────────────────────
    # REGLE UTILISATEUR (2026-08-08) : quand il pleut, c'est LA HARPE.
    # L'oud etait mon choix ; la decision est revenue et elle est claire.
    "pluie":     {"corde": "harpe", "pulse": "calme"},
    # L'orage : tambours denses, basson sombre au chant.
    "orage":     {"corde": "oud", "chant": "basson", "pulse": "orage",
                  "halo": "hand_chimes"},
    "brume":     {"halo": "wine_glasses", "chant": "clarinette", "pulse": "aucun"},
    # La neige : cristallin (psalterion, clochettes), flute froide, pouls rarefie.
    "neige":     {"halo": "hand_chimes", "corde": "psaltery", "chant": "flute",
                  "pulse": "nuit"},
    "couvert":   {"chant": "hautbois"},
    "clair":     {"halo": "glockenspiel"},
    # ── saison ───────────────────────────────────────────────────────────────
    "printemps": {"corde": "kalimba", "chant": "flute", "halo": "hand_chimes",
                  "pulse": "danse"},
    "ete":       {"chant": "violon", "corde": "celtic_guitar", "pulse": "danse"},
    "automne":   {"chant": "harmonica", "corde": "harpe", "pulse": "calme"},
    "hiver":     {"corde": "psaltery", "halo": "wine_glasses", "pulse": "sourd"},
    # ── moment ───────────────────────────────────────────────────────────────
    "aube":      {"chant": "ocarina", "halo": "glockenspiel", "pulse": "aucun"},
    "jour":      {},
    "crepuscule": {"chant": "harmonica", "corde": "harpe"},
    # La nuit ralentit le pouls : une frappe toutes les deux mesures,
    # tambour a fente sourd. Le tempo ne change pas — c'est l'ecriture
    # qui respire, sans quoi la boucle se decalerait.
    "nuit":      {"corde": "dan_tranh", "halo": "hand_chimes", "chant": "clarinette",
                  "pulse": "nuit"},
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


# ═══════════════════════════════════════════════════════════════════════════════
# LE MIX PAR CONTEXTE
# ═══════════════════════════════════════════════════════════════════════════════
# Changer d'instrument ne suffit pas a changer de milieu. Ce qui fait entendre un
# monde gele, ce n'est pas seulement un carillon plutot qu'une celesta : c'est un
# aigu clairsemme, une queue de reverbe longue et sombre, un grave retire.
#
# Voir docs/80_sound/30_music/MUSICOLOGIE_PRIME.md §4. Le principe emprunte a la
# trilogie Prime est une REGLE — un milieu se traduit par un traitement — et non
# un materiau : aucune melodie n'est reprise. L'espace y est un parametre
# d'ecriture, pas un effet ajoute apres coup.
#
# Ces valeurs sont appliquees A LA LECTURE, pas au rendu : le navigateur les
# applique en direct sur le bus principal. On entend donc le milieu changer sans
# re-rendre quoi que ce soit.
#
#   low / high : shelfs en dB (grave sous 220 Hz, aigu au-dessus de 4200 Hz)
#   space      : dosage de la reverbe, 0 = sec
#   decay      : duree de la queue en secondes (RT60)
#   damp       : coupure du passe-bas sur la queue, en Hz — plus bas, plus sombre
MIX_NEUTRAL = {"low": 0.0, "high": 0.0, "space": 0.16, "decay": 2.6, "damp": 5200}

MIX = {
    # ── gele : l'archetype Phendrana. Aigu ouvert, queue longue et sombre,
    #    grave retire — le froid s'entend a ce qui MANQUE dans le bas.
    "neige":      {"low": -4.5, "high": +3.0, "space": 0.42, "decay": 6.4, "damp": 2600},
    "hiver":      {"low": -3.0, "high": +1.5, "space": 0.34, "decay": 5.2, "damp": 3000},
    # ── voile : la brume mange l'aigu mais garde la profondeur
    "orage":      {"low": +3.0, "high": -1.0, "space": 0.30, "decay": 3.6, "damp": 3400},
    "brume":      {"low": -1.5, "high": -4.0, "space": 0.50, "decay": 5.8, "damp": 1900},
    # ── vegetal : proche, median, peu de queue
    "pluie":      {"low": +1.0, "high": -1.5, "space": 0.24, "decay": 3.0, "damp": 4200},
    "printemps":  {"low": 0.0,  "high": +1.0, "space": 0.18, "decay": 2.4, "damp": 6000},
    "aube":       {"low": -1.0, "high": +2.0, "space": 0.14, "decay": 2.2, "damp": 6800},
    "ete":        {"low": +0.5, "high": +0.5, "space": 0.16, "decay": 2.4, "damp": 6200},
    # ── ruines : tenu, tres long, sans transitoire
    "couvert":    {"low": +0.5, "high": -2.0, "space": 0.36, "decay": 5.0, "damp": 3200},
    "automne":    {"low": +1.5, "high": -1.5, "space": 0.30, "decay": 4.2, "damp": 3600},
    "nuit":       {"low": +2.0, "high": -2.5, "space": 0.46, "decay": 7.0, "damp": 2400},
    "crepuscule": {"low": +1.0, "high": -0.5, "space": 0.30, "decay": 4.0, "damp": 3800},
    # ── ouvert : le plus sec, spectre neutre
    "clair":      {"low": 0.0,  "high": +1.5, "space": 0.12, "decay": 2.0, "damp": 7000},
    "jour":       {"low": 0.0,  "high": 0.0,  "space": 0.14, "decay": 2.2, "damp": 6500},
}


def resolve_mix(context: dict) -> dict:
    """Le mix suit la meme priorite que la distribution : meteo > saison >
    moment. Le premier axe qui se prononce donne le milieu — un seul gagne,
    car deux traitements d'espace superposes ne veulent plus rien dire."""
    for axis in PRIORITY:
        value = context.get(axis)
        if value and value in MIX:
            return dict(MIX[value], source=value)
    return dict(MIX_NEUTRAL, source="neutre")


def manifest() -> dict:
    return {
        "roles": list(CANDIDATES),
        "default": DEFAULT,
        "axes": AXES,
        "priority": PRIORITY,
        "context": CONTEXT,
        "mix": MIX,
        "mix_neutral": MIX_NEUTRAL,
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
