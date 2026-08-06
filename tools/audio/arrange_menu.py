#!/usr/bin/env python3
"""
Orchestration — un SOCLE fixe, plus trois roles dont le contexte change le titulaire.

    socle    ce qui ne bouge jamais : cordes, bois d'harmonie, harpe, percussion
             douce, contrechant, dessus. Un seul fichier, toujours audible.
    chant    qui porte Tri Martolod          -> casting_menu.CANDIDATES["chant"]
    corde    l'accompagnement pince          -> ... ["corde"]
    halo     le scintillement de l'aigu      -> ... ["halo"]

Un role est ecrit UNE FOIS et rendu une fois par candidat, aux memes notes et aux
memes instants. Basculer de la guitare celtique a l'oud est donc un fondu croise,
pas un rearrangement — voir casting_menu.py.

PLAN, 40 mesures a 49 BPM (4,90 s la mesure)

  1-4    Ouverture      cloches froides, harpe, halo. Cordes a peine posees.
  5-8    L'air nu       le chant enonce Tri Martolod SANS ornement. Il faut
                        l'entendre simple avant de l'entendre brode.
  9-12   L'air orne     meme air, orne. Hautbois en dessous, contrechant entre.
  13-16  Refrain        la phrase instrumentale, ornee. Bodhran tres doux.
  17-20  Harmonise      cordes completes, cor, basson. Le contrechant s'installe.
  21-24  Developpement  violon solo, tremolos. Le chant se tait — c'est ce silence
                        qui fait qu'on l'attend.
  25-28  Refrain        le chant revient sur le refrain, monte vers le LA MAJEUR.
  29-36  Plein          l'air orne, dessus au piccolo, glockenspiel, cordes hautes.
                        Aucun cuivre : le sommet s'ouvre en registre, pas en force.
  37-40  Coda           tout se retire. Cloches, harpe, halo. On boucle.

CE QUI A DISPARU
Les anches synthetisees (bombarde, biniou, bourdon, tin whistle), les cuivres au
complet, les percussions franches (taiko, cymbale, tam-tam, caisse claire) et les
nappes electroniques (nappe FM, sub, choeur). Il ne reste que des pupitres
reellement enregistres — plus l'oud, seul modele synthetise reste, faute de source
libre pour un luth arabe.
"""

from __future__ import annotations

import numpy as np

from casting_menu import CANDIDATES, fold
from score_menu import (BAR, BEAT, CHORDS, LOOP_LEN, N_BARS, PROGRESSION, REFRAIN,
                        TRI_MARTOLOD, build_voicings, dyn, ornament, place_phrase, t_of)

def _jitter(seed: int) -> tuple[float, float]:
    """Flottement d'attaque et de velocite, FONCTION PURE DU SEED DE LA NOTE.

    C'est la propriete sur laquelle repose tout le systeme de distribution. Avec
    un generateur partage au niveau du module, `build_role("halo", "celesta")` et
    `build_role("halo", "wine_glasses")` consommaient le flux dans des ordres
    differents : les deux parties portaient les memes notes, mais decalees de
    quelques millisecondes les unes des autres. Un fondu croise entre elles se
    serait entendu comme un flanger, et deux notes censees etre la meme note
    auraient double.

    Ici le flottement ne depend que du seed de l'evenement, et aucun seed ne
    depend de l'instrument : tous les candidats d'un role sont donc rigoureusement
    synchrones. Verifie dans __main__."""
    rng = np.random.default_rng(4242 + seed)
    return (float(rng.normal(0.0, 0.013)),
            float(np.clip(rng.normal(1.0, 0.055), 0.6, 1.3)))

AIR = TRI_MARTOLOD
AIR_ORNE = ornament(TRI_MARTOLOD, seed=1)
REFRAIN_ORNE = ornament(REFRAIN, seed=2)

# Ou le chant se pose : (mesure, phrase, transposition, niveau relatif)
CHANT_AT = [
    (5,  AIR,          0, 1.00),      # nu — l'air doit d'abord etre entendu simple
    (9,  AIR_ORNE,     0, 1.00),
    (13, REFRAIN_ORNE, 0, 0.92),
    (17, AIR_ORNE,     0, 1.00),
    #  21-24 : silence du chant
    (25, REFRAIN_ORNE, 0, 0.95),
    (29, AIR_ORNE,     0, 1.00),
    (33, AIR_ORNE,     0, 0.96),
]

# Dessus — une ligne haute, ecrite au-dessus de l'air pendant le plein.
# Elle ne double pas la melodie : elle plane dessus en valeurs longues.
DESCANT = [
    (29, 1.0, 86, 3.0), (29, 4.0, 84, 2.0),
    (30, 2.0, 83, 3.0), (31, 1.0, 81, 2.0), (31, 3.0, 83, 2.0),
    (32, 1.0, 86, 4.0),
    (33, 1.0, 84, 3.0), (33, 4.0, 86, 2.0),
    (34, 2.0, 88, 3.0), (35, 1.0, 86, 4.0), (36, 1.0, 81, 4.0),
]


def _ev(inst, stem, midi, at, dur, vel, seed=0, humanize=True):
    if humanize:
        d_at, k_vel = _jitter(seed)
        at += d_at
        vel *= k_vel
    return {"inst": inst, "stem": stem, "midi": int(round(midi)), "at": max(0.0, at),
            "dur": dur, "vel": float(np.clip(vel, 0.05, 1.0)), "seed": seed}


def _chord_groups() -> list[tuple[int, int, str]]:
    groups, start = [], 0
    for i in range(1, N_BARS + 1):
        if i == N_BARS or PROGRESSION[i] != PROGRESSION[start]:
            groups.append((start + 1, i, PROGRESSION[start]))
            start = i
    return groups


def _tones(bar: int, lo: int, hi: int) -> list[int]:
    pcs, _root = CHORDS[PROGRESSION[bar - 1]]
    return sorted({o * 12 + pc for pc in pcs for o in range(lo // 12, hi // 12 + 2)
                   if lo <= o * 12 + pc <= hi})


# ═══════════════════════════════════════════════════════════════════════════════
# LE SOCLE
# ═══════════════════════════════════════════════════════════════════════════════

def build_bed() -> list[dict]:
    ev: list[dict] = []
    voicings = build_voicings()
    groups = _chord_groups()

    # ── HARMONIE TENUE ───────────────────────────────────────────────────────
    for (b0, b1, _name) in groups:
        t0 = t_of(b0, 1.0)
        span = (b1 - b0 + 1) * BAR
        d = dyn(b0)
        bass, upper = voicings[b0 - 1][0], voicings[b0 - 1][1:]

        ev.append(_ev("contrabass", "bed", bass - 12, t0, span + 0.9, 0.26 + 0.40 * d, b0 * 3))
        ev.append(_ev("strings_low", "bed", bass, t0, span + 0.8, 0.24 + 0.42 * d, b0 * 5))
        if b0 >= 9:
            ev.append(_ev("viola", "bed", upper[0], t0, span + 0.8, 0.22 + 0.40 * d, b0 * 7))
            ev.append(_ev("strings_mid", "bed", upper[1], t0, span + 0.7, 0.22 + 0.42 * d, b0 * 11))
        if b0 >= 17:
            ev.append(_ev("horn", "bed", upper[1] - 12, t0, span + 0.6, 0.18 + 0.30 * d, b0 * 13))
            ev.append(_ev("bassoon", "bed", bass + 12, t0, span + 0.6, 0.16 + 0.28 * d, b0 * 17))
        if b0 >= 21:
            ev.append(_ev("strings_high", "bed", upper[2], t0, span + 0.6, 0.20 + 0.40 * d, b0 * 19))
        if 23 <= b0 <= 28:
            for k, m in enumerate(upper[:2]):
                ev.append(_ev("strings_tremolo", "bed", m + 12, t0, span + 0.4,
                              0.14 + 0.30 * d, b0 * 23 + k))
        # Le hautbois double l'air une octave dessous pendant les enonces ornes :
        # c'est ce qui donne du corps au chant sans lui disputer sa ligne.
        if b0 in (9, 10, 11, 12, 17, 18, 19, 20):
            ev.append(_ev("oboe", "bed", upper[0], t0, span + 0.4, 0.14 + 0.24 * d, b0 * 29))

    # ── CONTRECHANT — en mouvement contraire, sur presque toute la piece ──────
    # Il monte quand l'air descend. C'est ce qui evite l'effet « melodie + tapis »,
    # et c'est la moitie de ce qu'on entend comme « melodique ».
    counter = [
        (9, 1.0, 57, 2.0), (9, 3.0, 60, 2.0), (10, 1.0, 62, 3.0), (10, 4.0, 60, 1.0),
        (11, 1.0, 57, 2.0), (11, 3.0, 62, 2.0), (12, 1.0, 58, 4.0),
        (13, 1.0, 60, 2.0), (13, 3.0, 62, 2.0), (14, 1.0, 64, 4.0),
        (15, 1.0, 62, 2.0), (15, 3.0, 59, 2.0), (16, 1.0, 57, 4.0),
        (17, 1.0, 62, 2.0), (17, 3.0, 65, 2.0), (18, 1.0, 59, 4.0),
        (19, 1.0, 57, 2.0), (19, 3.0, 60, 2.0), (20, 1.0, 62, 4.0),
        (21, 1.0, 65, 2.0), (21, 3.0, 64, 2.0), (22, 1.0, 62, 4.0),
        (23, 1.0, 58, 4.0), (24, 1.0, 57, 4.0),
        (25, 1.0, 60, 2.0), (25, 3.0, 62, 2.0), (26, 1.0, 64, 4.0),
        (27, 1.0, 62, 2.0), (27, 3.0, 59, 2.0),
        (28, 1.0, 61, 4.0),                                  # do diese : la dominante
        (29, 1.0, 62, 2.0), (29, 3.0, 65, 2.0), (30, 1.0, 59, 4.0),
        (31, 1.0, 57, 2.0), (31, 3.0, 60, 2.0), (32, 1.0, 62, 4.0),
        (33, 1.0, 65, 2.0), (33, 3.0, 64, 2.0), (34, 1.0, 62, 4.0),
        (35, 1.0, 58, 4.0), (36, 1.0, 57, 4.0),
    ]
    for (bar, beat, midi, nb) in counter:
        ev.append(_ev("clarinet", "bed", midi, t_of(bar, beat), nb * BEAT * 0.94,
                      0.20 + 0.30 * dyn(bar), bar * 31))

    # ── DESSUS — au piccolo, pendant le plein ────────────────────────────────
    for (bar, beat, midi, nb) in DESCANT:
        ev.append(_ev("piccolo", "bed", midi, t_of(bar, beat), nb * BEAT * 0.96,
                      0.16 + 0.24 * dyn(bar), bar * 37 + midi))

    # ── VIOLON SOLO — le developpement lui appartient ────────────────────────
    for (bar, beat, midi, nb) in place_phrase(REFRAIN_ORNE, 21, -12):
        ev.append(_ev("violin_solo", "bed", midi, t_of(bar, beat),
                      max(0.2, nb * BEAT * 0.94), 0.22 + 0.34 * dyn(bar), bar * 41 + midi))

    # ── HARPE — elle fait partie du socle, elle ne se remplace pas ───────────
    for (b0, _b1, name) in groups:
        pcs, _ = CHORDS[name]
        d = dyn(b0)
        for k, m in enumerate(sorted({o * 12 + pc for pc in pcs for o in (4, 5, 6)
                                      if 57 <= o * 12 + pc <= 86})[:5]):
            ev.append(_ev("harp", "bed", m, t_of(b0, 1.0) + k * 0.16, 4.2,
                          0.22 + 0.34 * d, b0 * 43 + k))
    for bar in range(1, N_BARS + 1, 2):
        tones = _tones(bar, 62, 81)
        ev.append(_ev("harp", "bed", tones[(bar * 3) % len(tones)], t_of(bar, 3.5),
                      3.6, 0.10 + 0.18 * dyn(bar), bar * 47))

    # ── CLOCHES FROIDES — les extremites ─────────────────────────────────────
    for bar in list(range(1, 9)) + list(range(37, 41)):
        pcs, _ = CHORDS[PROGRESSION[bar - 1]]
        d = dyn(bar)
        for j, beat in enumerate((1.0, 3.0)):
            ev.append(_ev("celesta_bell", "bed", 72 + pcs[(bar + j) % len(pcs)] % 12,
                          t_of(bar, beat), 4.4, 0.16 + 0.26 * d, bar * 53 + j))
    for bar in range(29, 37):
        pcs, _ = CHORDS[PROGRESSION[bar - 1]]
        for j, beat in enumerate((1.0, 3.5)):
            ev.append(_ev("glockenspiel", "bed", 84 + pcs[(j + bar) % len(pcs)] % 12,
                          t_of(bar, beat), 3.2, 0.18 + 0.28 * dyn(bar), bar * 59 + j))

    # La PERCUSSION n'est plus dans le socle : elle est devenue le role "pulse"
    # (voir build_role). Un tambour d'orage devait pouvoir REMPLACER la frappe
    # calme, pas s'ajouter par-dessus — sans quoi on retombe sur l'empilement.
    for bar in range(17, 21):                                # pizzicati
        tones = _tones(bar, 45, 64)
        for j, beat in enumerate((1.0, 3.0)):
            ev.append(_ev("pizzicato", "bed", tones[j % len(tones)], t_of(bar, beat),
                          1.8, 0.16 + 0.26 * dyn(bar), bar * 71 + j))

    ev.sort(key=lambda e: e["at"])
    return ev


# ═══════════════════════════════════════════════════════════════════════════════
# LES ROLES
# ═══════════════════════════════════════════════════════════════════════════════

def build_role(role: str, candidate: str) -> list[dict]:
    """Les memes notes aux memes instants, quel que soit le candidat.

    Seuls changent l'instrument, le gain, et le repli dans sa tessiture.
    C'est cette identite rythmique et melodique qui rend le fondu croise
    transparent : on entend un instrument en remplacer un autre, pas la piece
    changer."""
    inst, gain, span, _label = CANDIDATES[role][candidate]
    ev: list[dict] = []

    if role == "chant":
        for (bar0, phrase, tr, lvl) in CHANT_AT:
            for (bar, beat, midi, nb) in place_phrase(phrase, bar0, tr):
                ev.append(_ev(inst, "chant", fold(midi, span), t_of(bar, beat),
                              max(0.18, nb * BEAT * 0.92),
                              gain * lvl * (0.30 + 0.46 * dyn(bar)), bar * 73 + midi))

    elif role == "corde":
        # Trois notes par mesure, tenues cinq secondes : elles se recouvrent d'une
        # mesure sur l'autre et forment une nappe de cordes pincees.
        for bar in range(1, N_BARS + 1):
            tones = _tones(bar, 55, 74)
            d = dyn(bar)
            # Rien ne deborde le point de boucle — meme raison que pour le halo.
            # Une guitare ou un oud sont quasi eteints au bout de 5 s, donc le
            # repli de queue passait inapercu ; un psalterion FROTTE, lui, sonne
            # encore a plein niveau, et sa fin se repliait sur l'attaque de la
            # mesure 1. Seul des quatorze fichiers a produire un vrai clic :
            # +2,82 points d'exces haute frequence au raccord, pour un seuil de 2.
            for j, (beat, idx) in enumerate(((1.0, 0), (2.5, 2), (4.0, 4))):
                at = t_of(bar, beat)
                dur = min(5.6, LOOP_LEN - at - 0.06)
                if dur < 0.4:
                    continue
                ev.append(_ev(inst, "corde", fold(tones[idx % len(tones)], span),
                              at, dur, gain * (0.22 + 0.30 * d), bar * 79 + j))
            if bar % 4 == 1:                                  # basse a vide sur l'appui
                at = t_of(bar, 1.0)
                dur = min(6.4, LOOP_LEN - at - 0.06)
                if dur >= 0.4:
                    ev.append(_ev(inst, "corde", fold(tones[0] - 12, span), at,
                                  dur, gain * (0.24 + 0.28 * d), bar * 83))

    elif role == "halo":
        # Tres peu de notes, tres haut, tres longues. C'est le registre qui fait
        # le feerique, pas la quantite.
        for bar in list(range(1, 9)) + list(range(13, 17)) + list(range(29, 41)):
            tones = _tones(bar, 76, 88)
            if not tones:
                continue
            d = dyn(bar)
            for j, beat in enumerate((2.0, 4.0)):
                at = t_of(bar, beat)
                # Rien ne doit deborder le point de boucle. Une tenue de verre
                # frotte qui depassait de 2,8 s voyait sa fin repliee par-dessus
                # l'attaque de la mesure 1 : un ressaut que le test de pente
                # attrapait (0,0035 contre 0,0034), sur un signal quasi sinusoidal
                # ou les ecarts entre echantillons voisins sont minuscules.
                # marge : le flottement d'attaque peut encore decaler de ~13 ms
                dur = min(4.0, LOOP_LEN - at - 0.06)
                if dur < 0.4:
                    continue
                ev.append(_ev(inst, "halo", fold(tones[(bar + j) % len(tones)], span),
                              at, dur, gain * (0.18 + 0.26 * d), bar * 89 + j))

    if role == "pulse":
        # ── LE POULS ────────────────────────────────────────────────────────
        # Quatre facons de battre la meme mesure. Les instants sont IDENTIQUES
        # d'un titulaire a l'autre pour les frappes communes : c'est ce qui rend
        # la bascule inaudible comme changement de tempo.
        #
        #   aucun  : rien. Le silence est un titulaire a part entiere.
        #   calme  : la frappe douce d'origine, bodhran seul, 2 par mesure
        #   orage  : dense et franc — bodhran double, taiko sur les temps forts
        #   nuit   : demi-tempo, une frappe par mesure, tambour sourd
        inst, gain, span, _lab = CANDIDATES["pulse"][candidate]
        if candidate == "aucun":
            return []
        for bar in range(13, N_BARS + 1):
            d = dyn(bar)
            if candidate == "nuit":
                # une seule frappe toutes les deux mesures : le rythme respire
                if bar % 2:
                    continue
                ev.append(_ev(inst, "pulse", fold(38, span), t_of(bar, 1.0), 3.4,
                              gain * (0.13 + 0.18 * d), bar * 61))
            elif candidate == "orage":
                for beat, g in ((1.0, 1.0), (2.5, 0.5), (3.0, 0.8), (4.5, 0.45)):
                    at = t_of(bar, beat)
                    # Rien ne franchit le point de boucle : une frappe qui
                    # depassait de 0,87 s voyait sa queue repliee sur l'attaque
                    # de la mesure 1 — le meme ressaut que sur les tenues.
                    dur = min(1.5, LOOP_LEN - at - 0.06)
                    if dur < 0.25:
                        continue
                    ev.append(_ev(inst, "pulse", fold(45, span), at, dur,
                                  g * (0.20 + 0.30 * d), bar * 61 + int(beat * 2)))
                if bar % 2 == 1:                       # appui grave sur deux mesures
                    at = t_of(bar, 1.0)
                    dur = min(2.4, LOOP_LEN - at - 0.06)
                    if dur >= 0.4:
                        ev.append(_ev("taiko", "pulse", 33, at, dur,
                                      0.22 + 0.26 * d, bar * 73))
            else:                                       # calme
                for beat, g in ((1.0, 1.0), (3.0, 0.55)):
                    ev.append(_ev(inst, "pulse", fold(45, span), t_of(bar, beat), 1.8,
                                  g * (0.16 + 0.26 * d), bar * 61 + int(beat)))
        # les timbales restent liees au pouls, sauf la nuit et par temps calme
        if candidate in ("calme", "orage"):
            for bar in range(17, N_BARS - 3, 4):
                _pcs, root = CHORDS[PROGRESSION[bar - 1]]
                ev.append(_ev("timpani", "pulse", root - 24, t_of(bar, 1.0), 3.6,
                              0.16 + 0.30 * dyn(bar), bar * 67))

    ev.sort(key=lambda e: e["at"])
    return ev


def build_events() -> list[dict]:
    """Le mix par defaut : socle + les trois titulaires."""
    from casting_menu import DEFAULT
    ev = build_bed()
    for role, cand in DEFAULT.items():
        ev += build_role(role, cand)
    ev.sort(key=lambda e: e["at"])
    return ev


def summary(events: list[dict]) -> dict:
    per_inst: dict[str, int] = {}
    per_stem: dict[str, int] = {}
    for e in events:
        per_inst[e["inst"]] = per_inst.get(e["inst"], 0) + 1
        per_stem[e["stem"]] = per_stem.get(e["stem"], 0) + 1
    return {"events": len(events), "instruments": len(per_inst),
            "per_instrument": dict(sorted(per_inst.items())),
            "per_stem": dict(sorted(per_stem.items()))}


if __name__ == "__main__":
    import json
    from casting_menu import all_parts
    print(json.dumps(summary(build_events()), indent=2, ensure_ascii=False))
    print()
    for role, cand in all_parts():
        e = build_role(role, cand)
        lo = min(x["midi"] for x in e)
        hi = max(x["midi"] for x in e)
        over = sum(1 for x in e if x["at"] + x["dur"] > LOOP_LEN + 1e-6)
        print(f"  {role:6s} {cand:14s} {len(e):3d} notes  ambitus {lo}-{hi}"
              f"  debordements {over}")

    # LA propriete du systeme : tous les candidats d'un role doivent porter les
    # memes notes aux memes instants. Sans ca, un fondu croise flangerait.
    print()
    for role, cands in CANDIDATES.items():
        ref = None
        ok = True
        for cand in cands:
            sig = [(round(x["at"], 6), round(x["dur"], 6)) for x in build_role(role, cand)]
            if ref is None:
                ref = sig
            elif sig != ref:
                ok = False
                print(f"  ! {role}/{cand} n'est PAS synchrone avec le titulaire")
        print(f"  {role:6s} : {len(cands)} candidats "
              f"{'rigoureusement synchrones' if ok else 'DESYNCHRONISES'}")
