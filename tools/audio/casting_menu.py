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
    # SEPT voix de melodie, pas une de plus (« moins d'instruments au global »,
    # 2026-08-07). La table (meteo, heure) -> instrument est donnee par
    # l'utilisateur : nuit = boite a musique lente quelle que soit la meteo ;
    # le jour, clair = oud, couvert = harpe, pluie = flute.
    "chant": {
        "oud":        ("oud",        0.95, (40, 76), "Oud"),
        "harpe":      ("harp",       1.00, (36, 93), "Harpe"),
        "flute":      ("flute",      0.92, (48, 84), "Flûte"),
        "basson":     ("bassoon",    1.00, (34, 70), "Basson"),
        "flute_alto": ("alto_flute", 1.00, (58, 90), "Flûte alto"),
        # medieval-fantastique : le psalterion A L'ARCHET, glace et etrange —
        # la neige le reclame plus qu'un ocarina
        "psalterion": ("psaltery",   0.95, (58, 78), "Psaltérion"),
        # la boite a musique : les echantillons du celesta avec l'enveloppe
        # pincee (sample_bank), l'air replie dans l'aigu ou vivent les picots
        "boite":      ("music_box",  1.00, (72, 96), "Boîte à musique"),
    },
    "corde": {
        "celtic_guitar": ("celtic_guitar", 1.00, (24, 80), "Guitare celtique"),
        "oud":           ("oud",           0.95, (40, 76), "Oud"),
        "dan_tranh":     ("dan_tranh",     1.00, (35, 71), "Đàn tranh"),
        "kalimba":       ("kalimba",       0.95, (31, 85), "Kalimba"),
        "psaltery":      ("psaltery",      0.90, (58, 78), "Psaltérion"),
        # Etherealwinds Harp II CE : 34 cordes reelles, 36..93 — plus de zones
        # fantomes au-dela de l'instrument
        "harpe":         ("harp",          1.00, (36, 93),  "Harpe"),
        "mbira":         ("mbira",         1.00, (34, 73),  "Mbira"),
    },
    "halo": {
        "celesta":      ("celesta",      1.00, (67, 96), "Célesta"),
        "wine_glasses": ("wine_glasses", 1.05, (63, 74), "Verres frottés"),
        "hand_chimes":  ("hand_chimes",  0.95, (48, 84), "Clochettes à main"),
        "glockenspiel": ("glockenspiel", 0.95, (79, 108), "Glockenspiel"),
        "vibraphone":   ("vibraphone",   1.00, (40, 89),  "Vibraphone"),
        "tubulaires":   ("tubular_bells", 1.00, (57, 77), "Cloches tubulaires"),
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
    "pulse": "calme", "chant": "harpe", "corde": "celtic_guitar", "halo": "celesta"}

# ═══════════════════════════════════════════════════════════════════════════════
# LES CONTEXTES — deux axes (pivot 2026-08-07, la saison est SUPPRIMEE)
# ═══════════════════════════════════════════════════════════════════════════════
# SPEC UTILISATEUR : « c'est bien la melodie principale avec l'instrument qui
# change en fonction de la meteo, la musique doit comporter moins d'elements.
# En fonction de l'heure de la journee : aube / matinee / midi / apres-midi /
# soiree / nuit c'est la vitesse de la musique et parfois quelques instruments
# en plus voir substitution la nuit ! Pour la saison on oublie. »
#
#   meteo  -> QUI porte la melodie (chant). Rien d'autre : c'est la voix
#             principale qui change de timbre avec le temps qu'il fait.
#   heure  -> la VITESSE (TEMPO, applique a la lecture, hauteur preservee),
#             parfois un instrument EN PLUS (EXTRAS), et la nuit une
#             SUBSTITUTION du fond (corde, halo, pouls).

AXES = {
    "meteo": ["clair", "couvert", "pluie", "orage", "brume", "neige"],
    "heure": ["aube", "matinee", "midi", "apres_midi", "soiree", "nuit"],
}

# ordre de priorite : le premier qui se prononce sur un role l'emporte.
# L'HEURE D'ABORD : la nuit impose la boite a musique quelle que soit la
# meteo (table utilisateur 2026-08-07). Les autres heures sont muettes sur la
# distribution, donc la meteo garde la main le jour.
PRIORITY = ["heure", "meteo"]

CONTEXT = {
    # ── meteo : L'INSTRUMENT DE LA MELODIE le jour ───────────────────────────
    # Table utilisateur : « l'apres-midi quand le temps clair oud, l'apres-midi
    # couvert harpe et flute s'il pleut ». (Remplace l'ancien pluie=harpe.)
    "clair":   {"chant": "oud"},
    "couvert": {"chant": "harpe"},
    "pluie":   {"chant": "flute"},
    "orage":   {"chant": "basson"},
    "brume":   {"chant": "flute_alto"},
    "neige":   {"chant": "psalterion"},
    # ── heure : muette sur la distribution, sauf la nuit ─────────────────────
    "aube":       {},
    "matinee":    {},
    "midi":       {},
    "apres_midi": {},
    "soiree":     {},
    # « La nuit c'est boite a musique lente » : la melodie passe au celesta
    # replie dans l'aigu, l'accompagnement aux cloches tubulaires au loin.
    # Trois instruments, pas un de plus : socle + tubulaires + boite.
    "nuit": {"chant": "boite", "halo": "tubulaires"},
}

# ── LA VITESSE PAR HEURE (v9 : TOUT EN RENDU REEL) ───────────────────────────
# Plus aucun varispeed : chaque GROUPE d'heures est un rendu complet a son
# echelle, lu a 1,0 — hauteur normale partout, vitesses PRONONCEES. Les
# echelles sont des fractions exactes (boucles 5-lisses, voir score_menu).
#   nuit  3/4  (-25 %)   lent  5/6  (-17 %)   ref  1   vif  9/8  (+12,5 %)
SCALE_GROUPS = {
    "lent": "5/6", "ref": "1", "vif": "9/8", "nuit": "3/4",
}
GROUP_OF = {
    "aube": "lent", "matinee": "ref", "midi": "vif",
    "apres_midi": "ref", "soiree": "lent", "nuit": "nuit",
}
TEMPO = {                      # facteur AFFICHE (= vitesse reelle du rendu)
    "aube":       0.83,
    "matinee":    1.00,
    "midi":       1.13,        # le plus allant
    "apres_midi": 1.00,        # la reference
    "soiree":     0.83,
    "nuit":       0.75,        # boite a musique lente, hauteur normale
}

# ── LES PERCUSSIONS PAR GROUPE ───────────────────────────────────────────────
# Une ecriture de pouls par groupe d'heures, PREMIXEE dans le fond de son
# echelle — elle accompagne la melodie (dessins v9 : appuis sur le phrase
# de l'air, entree mesure 3).
PERC = {
    "lent": "sourd",           # taiko etouffe — aube et soiree
    "ref":  "calme",           # bodhran qui epouse l'air — matinee, apres-midi
    "vif":  "danse",           # le pas d'an dro — midi
    "nuit": "nuit",            # tambour de nuit, dans le fond lent
}

# ── EXTRAS : SUPPRIMES (regle « max 3 instruments », 2026-08-07) ─────────────
# Un extra etait une piste ajoutee a certaines heures (guirlande a midi,
# veilleuse en soiree). Avec socle + accompagnement + melodie on est deja a
# trois : tout ajout depasse la regle. L'heure ne fait plus que la VITESSE,
# et la nuit une SUBSTITUTION.
EXTRAS: dict = {}

# ── LE FOND ──────────────────────────────────────────────────────────────────
# v9 : le fond de jour = drone ADOUCI + ARPEGES DE GUITARE ACOUSTIQUE
# (« il manque de la guitare acoustique » — c'est aussi ce qui rend le fond
# melodique) + la percussion du groupe. La nuit garde son epure : drone +
# cloches tubulaires + tambour de nuit, la boite a musique seule en avant.
FOND_JOUR = {"corde": "celtic_guitar"}
FOND_NUIT = {"halo": "tubulaires", "pulse": "nuit"}


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
    # ── meteo ────────────────────────────────────────────────────────────────
    # gele : l'archetype Phendrana. Aigu ouvert, queue longue et sombre,
    # grave retire — le froid s'entend a ce qui MANQUE dans le bas.
    "neige":      {"low": -4.5, "high": +3.0, "space": 0.42, "decay": 6.4, "damp": 2600},
    # voile : la brume mange l'aigu mais garde la profondeur
    "orage":      {"low": +3.0, "high": -1.0, "space": 0.30, "decay": 3.6, "damp": 3400},
    "brume":      {"low": -1.5, "high": -4.0, "space": 0.50, "decay": 5.8, "damp": 1900},
    # vegetal : proche, median, peu de queue
    "pluie":      {"low": +1.0, "high": -1.5, "space": 0.24, "decay": 3.0, "damp": 4200},
    # ruines : tenu, tres long, sans transitoire
    "couvert":    {"low": +0.5, "high": -2.0, "space": 0.36, "decay": 5.0, "damp": 3200},
    # ouvert : le plus sec, spectre neutre
    "clair":      {"low": 0.0,  "high": +1.5, "space": 0.12, "decay": 2.0, "damp": 7000},
    # ── heure ────────────────────────────────────────────────────────────────
    "aube":       {"low": -1.0, "high": +2.0, "space": 0.14, "decay": 2.2, "damp": 6800},
    "matinee":    {"low": 0.0,  "high": +1.0, "space": 0.14, "decay": 2.2, "damp": 6500},
    "midi":       {"low": 0.0,  "high": 0.0,  "space": 0.12, "decay": 2.0, "damp": 6800},
    "apres_midi": {"low": 0.0,  "high": 0.0,  "space": 0.14, "decay": 2.2, "damp": 6500},
    "soiree":     {"low": +1.0, "high": -0.5, "space": 0.30, "decay": 4.0, "damp": 3800},
    "nuit":       {"low": +2.0, "high": -2.5, "space": 0.46, "decay": 7.0, "damp": 2400},
}


def resolve_mix(context: dict) -> dict:
    """Le mix suit la meme priorite que la distribution : meteo > heure. Le
    premier axe qui se prononce donne le milieu — un seul gagne, car deux
    traitements d'espace superposes ne veulent plus rien dire."""
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
        "tempo": TEMPO,
        "scale_groups": SCALE_GROUPS,
        "group_of": GROUP_OF,
        "perc": PERC,
        "extras": EXTRAS,
        "fond_jour": FOND_JOUR,
        "fond_nuit": FOND_NUIT,
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

    for ctx in ({"meteo": "pluie"}, {"heure": "nuit"},
                {"meteo": "pluie", "heure": "nuit"},
                {"meteo": "neige", "heure": "midi"}):
        t = TEMPO.get(ctx.get("heure", ""), 1.0)
        x = EXTRAS.get(ctx.get("heure", ""))
        print(f"  {str(ctx):40s} -> {resolve(ctx)}  tempo x{t}"
              + (f"  + {x['id']}" if x else ""))

    # Controle 4 : tempo et extras couvrent des valeurs d'heure existantes.
    for k in list(TEMPO) + list(EXTRAS):
        if k not in AXES["heure"]:
            print(f"  ! '{k}' (tempo/extras) n'est pas une heure connue")
            holes += 1
    if set(TEMPO) != set(AXES["heure"]):
        print(f"  ! TEMPO ne couvre pas toutes les heures")
        holes += 1
    return 0 if not (bad or missing or holes) else 1


if __name__ == "__main__":
    raise SystemExit(main())
