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

# ═══════════════════════════════════════════════════════════════════════════════
# GARDE-FOUS HARMONIQUES — voir tools/audio/harmonic_lint.py pour les regles
# ═══════════════════════════════════════════════════════════════════════════════

_DORIAN = (0, 2, 4, 5, 7, 9, 11)


def _chord_pcs_at(t: float) -> set:
    bar = int((t + 0.06) // BAR) + 1
    pcs, _root = CHORDS[PROGRESSION[min(bar, N_BARS) - 1]]
    return {p % 12 for p in pcs}


def _harsh(pc: int, pcs: set) -> bool:
    """Seconde mineure ou triton contre une note de l'accord."""
    return any(min(abs(pc - q) % 12, 12 - abs(pc - q) % 12) in (1, 6)
               for q in pcs)


def purge_harsh(evs: list[dict]) -> list[dict]:
    """Deplace d'un degre les notes breves qui FROTTENT contre l'accord.

    L'ornementation est ecrite en re dorien pur, aveugle a l'accord du moment :
    un fa brode sur un accord de sol forme un triton avec le si. La regle du
    contrepoint tolere la dissonance breve RESOLUE ; celle qui saute est
    deplacee vers le degre voisin consonant, dans la direction de la note
    suivante — le dessin melodique est conserve, le frottement disparait."""
    line = sorted(evs, key=lambda e: e["at"])
    for i, e in enumerate(line):
        pcs = _chord_pcs_at(e["at"])
        pc = int(round(e["midi"])) % 12
        if pc in pcs or not _harsh(pc, pcs):
            continue
        nxt = line[i + 1] if i + 1 < len(line) else None
        brief = e["dur"] <= BEAT * 1.05
        resolved = nxt is not None and abs(nxt["midi"] - e["midi"]) <= 2
        if brief and resolved:
            continue                       # dissonance d'ecole, legitime
        step = 1 if (nxt and nxt["midi"] > e["midi"]) else -1
        m = int(round(e["midi"]))
        for _ in range(4):                 # au plus deux degres de deplacement
            m += step
            while m % 12 not in _DORIAN:
                m += step
            if not _harsh(m % 12, pcs):
                break
        e["midi"] = m
    return line


def damp_rings(evs: list[dict], rel_override: float | None = None) -> list[dict]:
    """Etouffe les resonances qui saliraient l'accord SUIVANT.

    Les releases longues (celesta 1,4 s, harpe 0,9 s...) sont justes — une
    cloche etouffee net est un arret brutal — mais une resonance qui traverse
    un changement d'accord avec une note en seconde mineure ou triton contre
    le nouvel accord salit l'harmonie. Regle : cette note-la, et elle seule,
    voit sa duree raccourcie pour que sa queue meure au changement. Les
    resonances consonantes traversent librement — c'est le fondu naturel.

    rel_override : pour une partie de ROLE, on damp avec la release LA PLUS
    LONGUE du role, pas celle du candidat. Sans ca, une harpe (0,9 s) et un
    cor anglais (0,45 s) ne clampaient pas les memes notes — et les candidats
    d'un meme role cessaient d'etre synchrones a l'echantillon pres, ce qui
    est LA propriete dont depend le fondu croise."""
    from sample_bank import MultiSampleBank
    KIND, ENV = MultiSampleBank.KIND, MultiSampleBank.ENV
    bounds = []
    prev = None
    for bar in range(1, N_BARS + 1):
        name = PROGRESSION[bar - 1]
        if name != prev:
            bounds.append((t_of(bar, 1.0), {p % 12 for p in CHORDS[name][0]}))
            prev = name
    for e in evs:
        rel = (rel_override if rel_override is not None
               else ENV[KIND.get(e["inst"], "sustained")]["r"])
        end = e["at"] + e["dur"] + rel
        pc = int(round(e["midi"])) % 12
        for b, npcs in bounds:
            if e["at"] < b - 0.05 and end > b + 0.60:
                if pc not in npcs and _harsh(pc, npcs):
                    e["dur"] = max(0.12, min(e["dur"], b + 0.35 - rel - e["at"]))
                break
    return evs


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

        # REGLE MAX 3 INSTRUMENTS (2026-08-07) : le socle est UN SEUL pupitre.
        # Les cordes graves tiennent basse + quinte — deux voix du meme
        # instrument. Contrebasse, alto et seconds violons sont sortis :
        # avec l'accompagnement et la melodie, on est a trois, jamais plus.
        ev.append(_ev("strings_low", "bed", bass, t0, span + 0.8,
                      0.24 + 0.40 * d, b0 * 5))
        ev.append(_ev("strings_low", "bed", bass + 7, t0, span + 0.8,
                      0.18 + 0.32 * d, b0 * 7))

    ev = damp_rings(ev)
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
                ev.append(_ev(inst, "chant", midi, t_of(bar, beat),
                              max(0.18, nb * BEAT * 0.92),
                              gain * lvl * (0.30 + 0.46 * dyn(bar)), bar * 73 + midi))

    elif role == "corde":
        # DEUX notes par mesure, tenues cinq secondes : elles se recouvrent
        # d'une mesure sur l'autre et forment une nappe discrete. C'etait
        # trois notes plus un bourdon de basse toutes les quatre mesures —
        # rabote (2026-08-07) : le motif d'abord, l'accompagnement s'efface.
        # Rien ne deborde le point de boucle (le psalterion frotte sonne
        # encore a plein niveau a 5 s, sa fin se repliait sur la mesure 1).
        for bar in range(1, N_BARS + 1):
            tones = _tones(bar, 55, 74)
            d = dyn(bar)
            for j, (beat, idx) in enumerate(((1.0, 0), (3.0, 2))):
                at = t_of(bar, beat)
                # la premiere attaque ne se pose PAS sur le point de boucle :
                # un pince a transitoire dur (mbira) exactement au raccord met
                # ses aigus dans la fenetre d'analyse du join — le detecteur
                # y voit une couture (+3,4 pts d'exces HF) alors que l'ecart
                # d'echantillon est infime. 90 ms plus tard, l'attaque est
                # entiere ET clairement apres le raccord.
                if bar == 1 and beat == 1.0:
                    at += 0.09
                # marge = release du role (0,9 s pincee) + flottement : la
                # RESONANCE aussi doit mourir avant le raccord. Avec 0,06 s
                # seulement, la queue de la mbira (attaque riche en aigus,
                # encore forte a 2,4 s) se repliait sur la mesure 1 —
                # +3,52 points d'exces HF au raccord, seul stem a cliquer.
                dur = min(5.6, LOOP_LEN - at - 0.98)
                if dur < 0.4:
                    continue
                ev.append(_ev(inst, "corde", tones[idx % len(tones)],
                              at, dur, gain * (0.22 + 0.30 * d), bar * 79 + j))

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
                ev.append(_ev(inst, "halo", tones[(bar + j) % len(tones)],
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
                    ev.append(_ev(inst, "pulse", 45, at, dur,
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
                        ev.append(_ev(inst, "pulse", 41, at, dur,
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
                ev.append(_ev(inst, "pulse", 38, t_of(bar, 1.0), 3.4,
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
                    ev.append(_ev(inst, "pulse", 45, at, dur,
                                  g * (0.20 + 0.30 * d), bar * 61 + int(beat * 2)))
                if bar % 2 == 1:                       # appui grave sur deux mesures
                    at = t_of(bar, 1.0)
                    dur = min(2.4, LOOP_LEN - at - 0.06)
                    if dur >= 0.4:
                        ev.append(_ev("taiko", "pulse", 33, at, dur,
                                      0.22 + 0.26 * d, bar * 73))
            else:                                       # calme
                for beat, g in ((1.0, 1.0), (3.0, 0.55)):
                    ev.append(_ev(inst, "pulse", 45, t_of(bar, beat), 1.8,
                                  g * (0.16 + 0.26 * d), bar * 61 + int(beat)))
        # les timbales restent liees au pouls, sauf la nuit et par temps calme
        if candidate in ("calme", "orage", "danse"):
            for bar in range(17, N_BARS - 3, 4):
                _pcs, root = CHORDS[PROGRESSION[bar - 1]]
                ev.append(_ev("timpani", "pulse", root - 24, t_of(bar, 1.0), 3.6,
                              0.16 + 0.30 * dyn(bar), bar * 67))

    # garde-fous harmoniques : melodie purgee des frottements non resolus,
    # resonances etouffees avant un accord qu'elles saliraient. Le damp d'un
    # role s'evalue avec la release la plus longue parmi SES candidats : tous
    # portent alors exactement les memes durees — condition du fondu croise.
    if role in ("chant", "corde", "halo"):
        ev = purge_harsh(ev)
    from sample_bank import MultiSampleBank
    _K, _E = MultiSampleBank.KIND, MultiSampleBank.ENV
    rel_max = max(_E[_K.get(spec[0], "sustained")]["r"]
                  for spec in CANDIDATES[role].values())
    ev = damp_rings(ev, rel_override=rel_max)
    # LE REPLI D'OCTAVE VIENT EN DERNIER. Les garde-fous ont raisonne sur la
    # ligne ECRITE, identique pour tous les candidats — replier avant eux
    # changeait les intervalles (une clarinette basse pliait 76 en 64, le pas
    # conjoint devenait un saut) et leurs decisions divergeaient d'un candidat
    # a l'autre : la synchronie du role tombait. Le repli conserve la classe
    # de hauteur, donc toutes les decisions restent valides apres coup.
    # Seules les notes du candidat se replient — taiko, timbales et autres
    # renforts du pouls gardent leur hauteur ecrite.
    for e in ev:
        if e["inst"] == inst:
            e["midi"] = fold(e["midi"], span)
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
        if not e:
            print(f"  {role:6s} {cand:14s}   0 notes  (silence titulaire)")
            continue
        lo = min(x["midi"] for x in e)
        hi = max(x["midi"] for x in e)
        over = sum(1 for x in e if x["at"] + x["dur"] > LOOP_LEN + 1e-6)
        print(f"  {role:6s} {cand:14s} {len(e):3d} notes  ambitus {lo}-{hi}"
              f"  debordements {over}")

    # LA propriete du systeme : tous les candidats d'un role doivent porter les
    # memes notes aux memes instants. Sans ca, un fondu croise flangerait.
    print()
    for role, cands in CANDIDATES.items():
        if role == "pulse":
            # chaque titulaire du pouls est une ECRITURE differente — la
            # substitution de rythme passe par la, pas par le fondu note a note
            print(f"  {role:6s} : {len(cands)} ecritures distinctes (voulu)")
            continue
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
