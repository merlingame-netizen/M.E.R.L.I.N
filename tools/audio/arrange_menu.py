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
    """Le socle recompose : l'HARMONIE, rien qu'elle.

    La version precedente empilait 534 notes — harpe en arpeges continus
    (190 notes, alors que la harpe est devenue titulaire du role corde),
    contre-chant de clarinette, violon solo au developpement, descant de
    piccolo, cloches, glockenspiel, pizzicati. A tout instant du milieu de
    piece une quinzaine de voix sonnaient ENSEMBLE, avant meme les quatre
    roles : le reproche « trop d'instruments ensemble » decrivait
    litteralement la partition.

    Le socle ne fait plus que PORTER. Cordes graves des la premiere mesure,
    altos et seconds violons a la neuvieme, premiers violons a la vingt-et-
    unieme, cor et basson seulement dans le plein (25-32), tremolo pianissimo
    en lisiere. Tout le mouvement, le dessin et la couleur appartiennent aux
    roles — chant, corde, halo, pouls — c'est leur raison d'etre, et c'est
    la qu'on peut les remplacer.
    """
    ev: list[dict] = []
    voicings = build_voicings()
    groups = _chord_groups()

    for (b0, b1, _name) in groups:
        t0 = t_of(b0, 1.0)
        span = (b1 - b0 + 1) * BAR
        d = dyn(b0)
        bass, upper = voicings[b0 - 1][0], voicings[b0 - 1][1:]

        ev.append(_ev("contrabass", "bed", bass - 12, t0, span + 0.9,
                      0.24 + 0.36 * d, b0 * 3))
        ev.append(_ev("strings_low", "bed", bass, t0, span + 0.8,
                      0.22 + 0.40 * d, b0 * 5))
        if b0 >= 9:
            ev.append(_ev("viola", "bed", upper[0], t0, span + 0.8,
                          0.20 + 0.36 * d, b0 * 7))
            ev.append(_ev("strings_mid", "bed", upper[1], t0, span + 0.7,
                          0.20 + 0.38 * d, b0 * 11))
        if b0 >= 21:
            ev.append(_ev("strings_high", "bed", upper[2], t0, span + 0.6,
                          0.16 + 0.34 * d, b0 * 19))
        if 25 <= b0 <= 32:
            ev.append(_ev("horn", "bed", upper[1] - 12, t0, span + 0.6,
                          0.14 + 0.26 * d, b0 * 13))
            ev.append(_ev("bassoon", "bed", bass + 12, t0, span + 0.6,
                          0.12 + 0.22 * d, b0 * 17))
        if 25 <= b0 <= 28:
            ev.append(_ev("strings_tremolo", "bed", upper[1] + 12, t0, span + 0.4,
                          0.10 + 0.22 * d, b0 * 23))

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
        #   danse  : le pas d'an dro — court-court-long, taiko leger sur le 1
        #   orage  : dense et franc — bodhran double, taiko sur les temps forts
        #   ondee  : nappes de tambour d'ocean, bodhran en gouttes eparses
        #   sourd  : taiko etouffe une mesure sur deux, tam-tam au loin
        #   nuit   : demi-tempo, une frappe toutes les deux mesures
        inst, gain, span, _lab = CANDIDATES["pulse"][candidate]
        if candidate == "aucun":
            return []
        for bar in range(13, N_BARS + 1):
            d = dyn(bar)
            if candidate == "danse":
                # le pas de la danse bretonne : deux appuis courts, un long.
                # Les temps 1 et 3 coincident avec "calme" — la bascule
                # calme <-> danse ne deplace pas le pied, elle l'orne.
                for beat, g in ((1.0, 1.0), (2.0, 0.4), (2.5, 0.6),
                                (3.0, 0.85), (4.5, 0.5)):
                    at = t_of(bar, beat)
                    dur = min(1.6, LOOP_LEN - at - 0.06)
                    if dur < 0.25:
                        continue
                    ev.append(_ev(inst, "pulse", fold(45, span), at, dur,
                                  g * (0.17 + 0.27 * d), bar * 61 + int(beat * 2)))
                if bar % 4 == 1:
                    at = t_of(bar, 1.0)
                    dur = min(2.0, LOOP_LEN - at - 0.06)
                    if dur >= 0.4:
                        ev.append(_ev("taiko", "pulse", 45, at, dur,
                                      0.12 + 0.16 * d, bar * 79))
            elif candidate == "ondee":
                # Nappes une mesure sur deux mais longues de DEUX mesures et
                # demie : chacune recouvre le depart de la suivante. La version
                # precedente posait une nappe de 4,2 s par mesure de 4,9 s —
                # un trou a chaque mesure, le « bruitage qui se coupe » decrit
                # mot pour mot. Note enregistree du tambour (60) : le
                # transposer changerait la vitesse du ressac.
                if bar % 2 == 1:
                    at = t_of(bar, 1.0)
                    dur = min(2.5 * BAR, LOOP_LEN - at - 0.06)
                    if dur >= 2.0:
                        ev.append(_ev(inst, "pulse", 60, at, dur,
                                      0.13 + 0.16 * d, bar * 61))
                for beat in (2.5, 4.0):                # gouttes de bodhran
                    at = t_of(bar, beat)
                    dur = min(1.2, LOOP_LEN - at - 0.06)
                    if dur >= 0.25:
                        ev.append(_ev("bodhran", "pulse", 48, at, dur,
                                      0.10 + 0.14 * d, bar * 83 + int(beat * 2)))
            elif candidate == "sourd":
                # l'hiver : un appui etouffe une mesure sur deux, et le tam-tam
                # tres loin tous les huit — de la masse, pas du dessin.
                if bar % 2 == 0:
                    at = t_of(bar, 1.0)
                    dur = min(2.8, LOOP_LEN - at - 0.06)
                    if dur >= 0.4:
                        ev.append(_ev(inst, "pulse", fold(41, span), at, dur,
                                      0.15 + 0.20 * d, bar * 61))
                if bar % 8 == 5:
                    at = t_of(bar, 3.0)
                    dur = min(4.0, LOOP_LEN - at - 0.06)
                    if dur >= 0.8:
                        ev.append(_ev("tam_tam", "pulse", 60, at, dur,
                                      0.08 + 0.10 * d, bar * 89))
            elif candidate == "nuit":
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
        if candidate in ("calme", "orage", "danse"):
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
