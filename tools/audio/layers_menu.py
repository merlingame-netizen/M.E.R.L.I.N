#!/usr/bin/env python3
"""
Surcouches contextuelles — douze couches identifiees, activables a la volee.

L'IDEE
------
Les quatre stems (base / rhythm / melody / climax) decoupent le morceau par
INTENSITE : ils s'empilent quand la tension monte. Ce fichier ajoute un second
decoupage, orthogonal, par CONTEXTE : la meteo, la saison, le moment du jour,
la situation. Chaque couche est un fichier audio independant, cale sur la meme
boucle et la meme harmonie, qu'on allume ou eteint sans toucher au reste.

    pluie      -> oud + tambour ocean
    orage      -> didgeridoo + tambour a fente
    brume      -> verres frottes
    neige      -> clochettes a main + arbre a cloches
    beau temps -> arbre a clochettes
    printemps  -> kalimba
    ete        -> mbira + strumstick
    automne    -> harmonica
    hiver      -> psalterion a l'archet
    aube       -> ocarina
    nuit       -> dan tranh
    sacre      -> cloches nepalaises

LES TROIS REGLES QUI FONT QUE CA MARCHE
---------------------------------------
1. TOUT SORT DE LA GRILLE. Aucune couche n'a de notes ecrites en dur : chacune
   lit `CHORDS[PROGRESSION[mesure]]` et n'y prend que des notes de l'accord en
   cours. N'importe quelle combinaison des douze reste donc consonante avec le
   mix de base et avec les autres — il n'y a pas de paire interdite a tester.
2. UN INSTRUMENT PAR COUCHE, ET UN SEUL. Aucun instrument n'apparait dans deux
   couches (a une exception pres, documentee plus bas), et aucun n'apparait
   dans le mix de base. C'est ce qui rend une couche IDENTIFIABLE : quand la
   pluie tombe, on entend arriver un oud, pas "un peu plus de cordes".
3. TRES PEU DE NOTES. De 3 (les cloches nepalaises) a 54 (la pluie, qui compte
   ses quatre longues tenues de tambour ocean) pour 165 s de boucle. La mediane
   est a 16 : une note toutes les dix secondes. Une couche est une couleur
   ajoutee, pas une voix de plus, et c'est ce qui permet d'en empiler trois ou
   quatre sans que le mix s'epaississe.

L'EXCEPTION : `hiver` et `brume` emploient tous deux des instruments a son
glace et tenu (psalterion, verres). Ils ne partagent aucun echantillon, mais si
on active les deux ensemble la lecture est "froid" et non "froid + froid". C'est
voulu : ce sont les seules couches qui se renforcent au lieu de s'ajouter.

    python3 tools/audio/layers_menu.py            # inventaire + comptage
"""

from __future__ import annotations

import numpy as np

from score_menu import BEAT, CHORDS, LOOP_LEN, N_BARS, PROGRESSION, dyn, t_of

_hum = np.random.default_rng(90210)


# ═══════════════════════════════════════════════════════════════════════════════
# AXES DE CONTEXTE
# ═══════════════════════════════════════════════════════════════════════════════

AXES = {
    "meteo":     ["clair", "couvert", "pluie", "orage", "brume", "neige"],
    "saison":    ["printemps", "ete", "automne", "hiver"],
    "moment":    ["aube", "jour", "crepuscule", "nuit"],
    "situation": ["neutre", "sacre"],
}


def _ev(inst, midi, at, dur, vel, seed=0, jitter=0.03):
    """Les couches flottent plus que l'orchestre : elles ne sont pas dirigees."""
    at += float(_hum.normal(0.0, jitter))
    vel *= float(np.clip(_hum.normal(1.0, 0.07), 0.6, 1.3))
    return {"inst": inst, "stem": "layer", "midi": int(round(midi)), "at": max(0.0, at),
            "dur": dur, "vel": float(np.clip(vel, 0.05, 1.0)), "seed": seed}


def _tones(bar: int, lo: int, hi: int) -> list[int]:
    """Les notes de l'accord de la mesure, dans une tessiture donnee."""
    pcs, _root = CHORDS[PROGRESSION[bar - 1]]
    return sorted({o * 12 + pc for pc in pcs for o in range(lo // 12, hi // 12 + 2)
                   if lo <= o * 12 + pc <= hi})


def _root(bar: int) -> int:
    return CHORDS[PROGRESSION[bar - 1]][1]


# ═══════════════════════════════════════════════════════════════════════════════
# METEO
# ═══════════════════════════════════════════════════════════════════════════════

def _pluie() -> list[dict]:
    """OUD + TAMBOUR OCEAN — la couche demandee explicitement.

    Le tambour ocean est un cercle de billes roulant sur une peau : c'est
    litteralement l'instrument du bruit de pluie, et il tient tout le morceau en
    fond, tres bas, sans jamais rien articuler.

    L'oud, lui, joue par-dessus une phrase toutes les quatre mesures. Il descend
    — un oud descend, c'est ce que sa tessiture et son jeu au risha appellent —
    en s'appuyant sur les notes de l'accord, avec une note de passage entre deux
    degres. Il ne double jamais Tri Martolod : il commente.
    """
    ev = []
    # la nappe de pluie : quatre longues tenues qui se recouvrent
    for bar in (1, 11, 21, 31):
        ev.append(_ev("ocean_drum", 60, t_of(bar, 1.0), 46.0, 0.30 + 0.12 * dyn(bar),
                      bar * 3, jitter=0.0))
    # les phrases d'oud
    for bar in range(3, N_BARS, 4):
        d = dyn(bar)
        tones = _tones(bar, 45, 69)
        if len(tones) < 3:
            continue
        line = [tones[-1], tones[-1] - 1, tones[-2], tones[-3]]     # note de passage
        for k, m in enumerate(line):
            ev.append(_ev("oud", m, t_of(bar, 1.0) + k * BEAT * 0.75,
                          BEAT * 1.6, (0.34 + 0.30 * d) * (1.0 - 0.12 * k), bar * 7 + k))
        # la basse a vide qui referme la phrase
        ev.append(_ev("oud", _root(bar) - 12, t_of(bar, 3.5), BEAT * 3.0,
                      0.30 + 0.24 * d, bar * 11))
    return ev


def _orage() -> list[dict]:
    """DIDGERIDOO + TAMBOUR A FENTE — l'orage par en dessous.

    Un orage ne s'ecrit pas avec des cymbales : ca donne une bande-annonce. Il
    s'ecrit avec du grondement continu et des chocs de bois secs et espaces. Le
    didgeridoo tient un re grave immobile (l'echantillon est en re, c'est la
    tonique de la piece — coincidence commode), le tambour a fente ponctue.
    """
    ev = []
    # Les bourdons se relaient toutes les 8 mesures et le DERNIER S'ARRETE AU
    # POINT DE BOUCLE. Avec 38 s partout, celui de la mesure 33 debordait de 5 s
    # et le repli de queue posait sa fin par-dessus l'attaque du premier : un
    # ressaut de niveau que le test de pente attrapait (0,0041 contre 0,0037 de
    # pente locale). Sur un bourdon a 38 Hz les ecarts entre echantillons voisins
    # sont minuscules, donc le moindre palier ressort.
    for bar in (1, 9, 17, 25, 33):
        span = 34.0 if bar < 33 else (LOOP_LEN - t_of(bar, 1.0))
        ev.append(_ev("didgeridoo", 38, t_of(bar, 1.0), span, 0.34 + 0.22 * dyn(bar),
                      bar * 13, jitter=0.0))
    for bar in range(2, N_BARS + 1, 3):
        d = dyn(bar)
        for beat in (1.0, 2.75):
            ev.append(_ev("slit_drum", 55 + (bar % 3) * 2, t_of(bar, beat), 1.4,
                          0.22 + 0.30 * d, bar * 17 + int(beat)))
    return ev


def _brume() -> list[dict]:
    """VERRES FROTTES — quatre verres accordes, rien d'autre.

    La bibliotheque n'en a que quatre (re#4, fa#4, la#4, re5). C'est peu, et
    c'est parfait ici : on ne demande a cette couche qu'une seule chose, tenir
    une note tres longtemps et disparaitre. Elle ne joue que la tierce ou la
    quinte de l'accord — jamais la fondamentale, qui la ferait entendre comme
    une nappe d'harmonie au lieu d'un halo.
    """
    ev = []
    for bar in range(1, N_BARS + 1, 5):
        tones = _tones(bar, 62, 76)
        if len(tones) < 2:
            continue
        for k, m in enumerate(tones[1:3]):
            ev.append(_ev("wine_glasses", m, t_of(bar, 1.0) + k * BEAT * 2.0, 21.0,
                          0.26 + 0.16 * dyn(bar), bar * 19 + k, jitter=0.12))
    return ev


def _neige() -> list[dict]:
    """CLOCHETTES A MAIN + ARBRE A CLOCHES — des points, jamais une ligne.

    La neige ne fait aucun bruit ; ce qu'on met sous l'image, c'est le froid et
    l'immobilite. Donc : des attaques isolees dans l'aigu, tres espacees, et
    aucune tenue. Une seule glissade d'arbre a cloches sur toute la boucle, parce
    que deux en feraient un effet.
    """
    ev = []
    for k, bar in enumerate(range(2, N_BARS + 1, 6)):
        tones = _tones(bar, 72, 88)
        for j, m in enumerate(tones[:2]):
            ev.append(_ev("hand_chimes", m, t_of(bar, 1.0 + j * 2.5), 6.0,
                          0.22 + 0.18 * dyn(bar), bar * 23 + j, jitter=0.09))
    ev.append(_ev("bell_tree", 84, t_of(29, 1.0), 5.0, 0.30, 991, jitter=0.0))
    return ev


def _clair() -> list[dict]:
    """ARBRE A CLOCHETTES — la couche la plus legere du lot.

    Beau temps : quatre glissades, une par section. Rien de plus. Elle existe
    surtout pour que l'axe meteo ait une valeur "positive" qui ne soit pas le
    silence — le silence se lit comme un bug, pas comme du beau temps.
    """
    return [_ev("mark_tree", 84, t_of(bar, 1.0), 6.5, 0.24 + 0.16 * dyn(bar),
                bar * 29, jitter=0.05)
            for bar in (5, 17, 29, 37)]


# ═══════════════════════════════════════════════════════════════════════════════
# SAISON
# ═══════════════════════════════════════════════════════════════════════════════

def _printemps() -> list[dict]:
    """KALIMBA — un motif de trois notes qui remonte.

    Toutes les autres figures de la piece descendent (Tri Martolod descend, l'oud
    descend, le contrechant monte mais il est dans le mix de base). Celle-ci
    monte, et c'est tout ce qu'il faut pour qu'elle se lise comme un printemps.
    """
    ev = []
    for bar in range(1, N_BARS + 1, 3):
        tones = _tones(bar, 60, 84)
        if len(tones) < 3:
            continue
        d = dyn(bar)
        for k, idx in enumerate((0, 2, 4)):
            ev.append(_ev("kalimba", tones[idx % len(tones)], t_of(bar, 1.0 + k * 1.25),
                          3.0, 0.22 + 0.26 * d, bar * 31 + k))
    return ev


def _ete() -> list[dict]:
    """MBIRA + STRUMSTICK — deux cycles qui ne tombent pas ensemble.

    La mbira se joue en motifs entrelaces qui se decalent : ici son cycle fait
    3 mesures et celui du strumstick 5, si bien qu'ils ne coincident qu'une fois
    toutes les 15 mesures. C'est ce decalage lent qui donne la chaleur — deux
    cycles synchrones auraient donne une boite a rythme.
    """
    ev = []
    for bar in range(1, N_BARS + 1, 4):
        tones = _tones(bar, 55, 79)
        d = dyn(bar)
        for k, idx in enumerate((2, 0, 3, 1)):
            ev.append(_ev("mbira", tones[idx % len(tones)], t_of(bar, 1.0 + k * 0.9),
                          2.6, 0.20 + 0.24 * d, bar * 37 + k))
    for bar in range(2, N_BARS + 1, 6):
        tones = _tones(bar, 50, 67)
        ev.append(_ev("strumstick", tones[0], t_of(bar, 1.0), 4.5,
                      0.24 + 0.24 * dyn(bar), bar * 41))
        ev.append(_ev("strumstick", tones[min(2, len(tones) - 1)], t_of(bar, 3.0), 4.0,
                      0.20 + 0.22 * dyn(bar), bar * 43))
    return ev


def _automne() -> list[dict]:
    """HARMONICA — de longues tenues, une par section.

    Le Hohner Super64 est un harmonica chromatique : son timbre porte une plainte
    que ni la flute ni le hautbois n'ont. Il tient la quinte ou la septieme de
    l'accord pendant huit temps, et se tait pendant quatre mesures.
    """
    ev = []
    for bar in range(4, N_BARS + 1, 6):
        tones = _tones(bar, 58, 76)
        if len(tones) < 2:
            continue
        ev.append(_ev("harmonica", tones[-2], t_of(bar, 1.0), 9.0,
                      0.28 + 0.22 * dyn(bar), bar * 47, jitter=0.07))
    return ev


def _hiver() -> list[dict]:
    """PSALTERION A L'ARCHET — l'instrument le plus glacant des deux bibliotheques.

    Un psalterion frotte a l'archet sonne comme une scie musicale : une sinusoide
    presque pure, avec un archet audible dessus. Deux notes tenues par section,
    a la quinte, sans vibrato.
    """
    ev = []
    for bar in range(1, N_BARS + 1, 8):
        tones = _tones(bar, 60, 78)
        if len(tones) < 3:
            continue
        for k, m in enumerate((tones[0], tones[2])):
            ev.append(_ev("psaltery", m, t_of(bar, 1.0) + k * BEAT * 3.0, 14.0,
                          0.24 + 0.18 * dyn(bar), bar * 53 + k, jitter=0.1))
    return ev


# ═══════════════════════════════════════════════════════════════════════════════
# MOMENT DU JOUR
# ═══════════════════════════════════════════════════════════════════════════════

def _aube() -> list[dict]:
    """OCARINA — une note tenue, tres haut, qui monte d'un degre puis se tait."""
    ev = []
    for bar in range(6, N_BARS + 1, 9):
        tones = _tones(bar, 64, 78)
        if len(tones) < 2:
            continue
        ev.append(_ev("ocarina", tones[0], t_of(bar, 1.0), 5.5,
                      0.26 + 0.20 * dyn(bar), bar * 59, jitter=0.08))
        ev.append(_ev("ocarina", tones[1], t_of(bar, 4.0), 7.0,
                      0.24 + 0.20 * dyn(bar), bar * 61, jitter=0.08))
    return ev


def _nuit() -> list[dict]:
    """DAN TRANH — cithare vietnamienne, notes isolees avec leur vibrato.

    Ce n'est pas un instrument celtique, et c'est assume : la couche "nuit" doit
    depayser. Elle joue tres peu, dans le medium-aigu, avec de longs silences.
    """
    ev = []
    for bar in range(3, N_BARS + 1, 7):
        tones = _tones(bar, 62, 83)
        d = dyn(bar)
        for k, idx in enumerate((3, 1, 4)):
            ev.append(_ev("dan_tranh", tones[idx % len(tones)],
                          t_of(bar, 1.0 + k * 1.75), 4.0,
                          0.24 + 0.22 * d, bar * 67 + k, jitter=0.06))
    return ev


# ═══════════════════════════════════════════════════════════════════════════════
# SITUATION
# ═══════════════════════════════════════════════════════════════════════════════

def _sacre() -> list[dict]:
    """CLOCHES NEPALAISES — trois frappes sur toute la boucle.

    Pour les moments rituels (rencontre druidique, promesse, fin de run). Trois
    frappes en 165 s : c'est le taux d'evenement le plus bas de tout le systeme,
    et c'est ce qui fait qu'on les remarque.
    """
    return [_ev("hand_bells", 67, t_of(bar, 1.0), 12.0, 0.30 + 0.20 * dyn(bar),
                bar * 71, jitter=0.0)
            for bar in (1, 17, 33)]


# ═══════════════════════════════════════════════════════════════════════════════
# INVENTAIRE
# ═══════════════════════════════════════════════════════════════════════════════

LAYERS = [
    # id, libelle, axe, valeurs declenchantes, instruments, gain, generateur
    ("pluie",     "Pluie",         "meteo",     ["pluie", "orage"],
     ["oud", "ocean_drum"],           1.00, _pluie),
    ("orage",     "Orage",         "meteo",     ["orage"],
     ["didgeridoo", "slit_drum"],     0.92, _orage),
    ("brume",     "Brume",         "meteo",     ["brume", "couvert"],
     ["wine_glasses"],                0.95, _brume),
    ("neige",     "Neige",         "meteo",     ["neige"],
     ["hand_chimes", "bell_tree"],    0.95, _neige),
    ("clair",     "Beau temps",    "meteo",     ["clair"],
     ["mark_tree"],                   0.85, _clair),
    ("printemps", "Printemps",     "saison",    ["printemps"],
     ["kalimba"],                     0.95, _printemps),
    ("ete",       "Ete",           "saison",    ["ete"],
     ["mbira", "strumstick"],         0.90, _ete),
    ("automne",   "Automne",       "saison",    ["automne"],
     ["harmonica"],                   0.88, _automne),
    ("hiver",     "Hiver",         "saison",    ["hiver"],
     ["psaltery"],                    0.92, _hiver),
    ("aube",      "Aube",          "moment",    ["aube"],
     ["ocarina"],                     0.90, _aube),
    ("nuit",      "Nuit",          "moment",    ["nuit"],
     ["dan_tranh"],                   0.92, _nuit),
    ("sacre",     "Sacre",         "situation", ["sacre"],
     ["hand_bells"],                  1.00, _sacre),
]

LAYER_IDS = [layer[0] for layer in LAYERS]
# Reverbe et delai par couche : les couches lointaines et tenues s'etalent
# beaucoup, les percussives presque pas.
LAYER_SEND = {
    "pluie": (0.42, 0.18), "orage": (0.34, 0.06), "brume": (0.72, 0.30),
    "neige": (0.62, 0.34), "clair": (0.58, 0.28), "printemps": (0.44, 0.22),
    "ete": (0.40, 0.16), "automne": (0.56, 0.26), "hiver": (0.66, 0.24),
    "aube": (0.58, 0.30), "nuit": (0.50, 0.34), "sacre": (0.70, 0.26),
}


def build_layers() -> dict[str, list[dict]]:
    """{id de couche: evenements}. Les instruments sont ceux du moteur."""
    return {lid: gen() for (lid, _lab, _ax, _vals, _ins, _g, gen) in LAYERS}


def layer_instruments() -> list[str]:
    out: list[str] = []
    for (_lid, _lab, _ax, _vals, instruments, _g, _gen) in LAYERS:
        for i in instruments:
            if i not in out:
                out.append(i)
    return out


def manifest() -> dict:
    """Ce que le jeu doit connaitre pour choisir ses couches, en JSON."""
    ev = build_layers()
    return {
        "axes": AXES,
        "layers": [
            {"id": lid, "label": label, "axis": axis, "when": vals,
             "instruments": instruments, "gain": gain,
             "file": f"layer_{lid}.ogg", "events": len(ev[lid])}
            for (lid, label, axis, vals, instruments, gain, _gen) in LAYERS
        ],
    }


def main() -> int:
    import json
    m = manifest()
    ev = build_layers()
    print(f"{len(LAYERS)} surcouches, {sum(len(v) for v in ev.values())} evenements, "
          f"{len(layer_instruments())} instruments dedies\n")
    for entry in m["layers"]:
        print(f"  {entry['id']:10s} {entry['axis']:10s} "
              f"si {'/'.join(entry['when']):16s} "
              f"{entry['events']:3d} notes  {', '.join(entry['instruments'])}")
    # aucun instrument ne doit servir dans deux couches : c'est ce qui les rend
    # identifiables a l'oreille
    seen: dict[str, str] = {}
    for entry in m["layers"]:
        for i in entry["instruments"]:
            if i in seen:
                print(f"\n  ! {i} sert dans {seen[i]} ET {entry['id']}")
            seen[i] = entry["id"]
    print()
    print(json.dumps(m["axes"], ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
