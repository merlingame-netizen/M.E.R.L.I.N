# -*- coding: utf-8 -*-
"""scenario_qc.py - Gate objectif de la charte des scenarios (BIBLE §25.5, R166-R169).

Controle un scenario au format JSON {title, envergure, biome, figures, html} dont le
champ html suit le markup §25 : <article> / <header> / <section class="beat"> avec
<div class="scene|bandeau|choix|geste|reaction|deltas"> / <div class="merlin"> /
<div class="epilogue"> ; mots-indices <span class="kw kw-famille"><b>..</b></span> et
familles <span class="fam fam-famille"> dans le bandeau.

CALIBRATION : chaque seuil ci-dessous a ete regle pour que les 10 sentiers etalon R169
(artefact de lecture valide par l'utilisateur, 2026-07-29) passent a 100 %. Les seuils
et leurs justifications sont documentes au niveau de chaque constante.

Usage :
    python tools/scenario_qc.py fichier.json [fichier2.json ...]
    python tools/scenario_qc.py --library data/ai/quest_library_foret.json
    python tools/scenario_qc.py --self-test          (verifie le gate sur les etalons)
Code retour : 0 = tous PASS, 1 = au moins un FAIL, 2 = erreur d'usage.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# Referentiels canon (BIBLE §6, §25, MerlinTags)
# ---------------------------------------------------------------------------

# Les 6 familles canon (scripts/game/merlin_tags.gd FAMILIES). Les scenarios de
# bibliotheque n'utilisent jamais "corrompu" en mots-indices (les etalons : 0 occurrence),
# mais la famille reste valide pour d'eventuels scenarios de la Voie corrompue.
FAMILIES: tuple[str, ...] = ("perception", "corps", "parole", "intuition", "monde", "corrompu")

# Actions jouables affichees dans la div choix. Les etalons utilisent les 5 familles
# non corrompues comme action de tete (dont "Monde", observe etalon_10 beat 6).
ACTIONS: tuple[str, ...] = ("Perception", "Corps", "Parole", "Intuition", "Monde")

# Roster nomme (§6 R166 decision 12) + piliers (§6 R127) + roles contractuels (R164).
# Chaque figure = liste d'alias detectables dans la prose (formes courtes incluses).
ROSTER_ALIASES: dict[str, list[str]] = {
    "ankou": ["Ankou"],
    "lavandiere": ["Lavandière", "Lavandiere"],
    "fanch": ["Fañch", "Fanch", "Trotteur"],
    "erwan": ["Erwan", "Veilleur"],
    "aveline": ["Aveline"],
    "chevalier_sans_nom": ["Chevalier Sans Nom", "chevalier sans nom", "chevalier sans blason"],
    "passeur": ["Passeur de Brumes", "Passeur"],
    "marcharit": ["Marc'harit", "Marc’harit", "Noyée", "Noyee"],
    "kado": ["Kado", "Cordier"],
    "ordalch": ["Ordalc'h", "Ordalc’h"],
    # piliers (§6) - reviennent par nature (R131)
    "choeur": ["Chœur des Druides", "Choeur des Druides", "Chœur", "Choeur"],
    "etre": ["Être Indéfinissable", "Etre Indefinissable", "l'Être", "l'Etre"],
    "chevalier": ["Chevalier déchu", "Chevalier dechu", "le chevalier"],
    "compagnon": ["Compagnon Perdu", "Compagnon"],
    "enfant": ["l'Enfant", "L'Enfant", "l'enfant"],
    # roles contractuels (R164)
    "marchand": ["marchand", "colporteur", "comptoir", "troc", "korrigan"],
    "creancier": ["créancier", "creancier", "la dette", "Promesse"],
}

# Noyau recurrent toujours legitime dans la prose (jamais un "nom hallucine").
CORE_NAMES: tuple[str, ...] = ("Merlin", "Voyageur", "Arthur", "Brocéliande", "Broceliande")

# Envergures (§25.3) : libelle affiche -> bornes de quetes tolerees.
# CALIBRATION : les 10 etalons utilisent "veillée" comme libelle de la breve, et leurs
# odyssees sont ecrites en 3 quetes / 9 beats (compression editoriale de l'artefact de
# lecture ; le canon §25.3 vise 4 quetes en jeu). Le gate accepte donc odyssee = 3-4
# quetes ; a resserrer a 4 exactement quand la forge generera des odyssees canon.
ENVERGURE_BOUNDS: dict[str, tuple[int, int]] = {
    "veillee": (1, 1),
    "breve": (1, 1),
    "periple": (2, 3),
    "odyssee": (3, 4),
}

# Bornes de taille d'une quete (R120, inchange par R166) : 2 a 5 beats.
QUEST_BEATS_MIN, QUEST_BEATS_MAX = 2, 5

# ---------------------------------------------------------------------------
# Registre R169 (§25.5) - seuils
# CALIBRATION sur les 10 etalons (mesure calibrate.py, 2026-07-30) :
#   longueur moyenne de phrase observee 12.5 a 18.2 mots -> bande [9, 22]
#   part de phrases < 5 mots observee 0 a 10.2 %        -> plafond 15 %
#   part de phrases > 35 mots observee 0 a 3.9 %         -> plafond 10 %
#   ratio de caracteres accentues observe ~2.4 a 3.4 %   -> plancher 1.2 %
# ---------------------------------------------------------------------------
SENT_MEAN_MIN, SENT_MEAN_MAX = 9.0, 22.0
SHORT_SENT_WORDS, SHORT_SENT_MAX_RATIO = 5, 0.15
LONG_SENT_WORDS, LONG_SENT_MAX_RATIO = 35, 0.10
ACCENT_MIN_RATIO = 0.012

# Anglicismes et vocabulaire interdit (§13 ton + §25.5). Matching par mot entier sur
# texte normalise (minuscule sans accents) : zero occurrence dans les 10 etalons.
BANNED_WORDS: tuple[str, ...] = (
    "ok", "okay", "cool", "deal", "challenge", "boost", "boss", "timing", "look",
    "flash", "level", "skill", "loot", "buff", "nerf", "spawn", "respawn", "checkpoint",
    "gameplay", "reset", "sorry", "please", "hello", "wow", "top",
)
# Bris du 4e mur (§13, filtre R61) : mots meta interdits dans la prose joueur.
# "joueur" n'est banni QU'AVEC article (le/du/au...) : l'idiome "beau joueur" est du
# francais legitime (observe etalon_06, valide par l'utilisateur).
FOURTH_WALL_WORDS: tuple[str, ...] = (
    "simulation", "modele", "algorithme", "programme", "pixel", "interface",
)
FOURTH_WALL_PATTERNS: tuple[str, ...] = (
    r"\ble joueur\b", r"\bdu joueur\b", r"\bau joueur\b", r"\bles joueurs\b",
    r"\bla joueuse\b", r"\bpartie de jeu\b",
)

# Fil causal (25.4bis) : chaque beat hors le premier doit partager au moins
# CAUSAL_MIN_SHARED mots pleins (>= 5 lettres, hors stop-words) avec l'union du texte
# des beats precedents + preambule.
# CALIBRATION : minimum observe sur les etalons = 3 mots partages -> seuil 2 (marge 1).
# LIMITE ASSUMEE de l'heuristique : c'est un detecteur de RECURRENCE LEXICALE, pas de
# causalite. Il peut laisser passer un texte incoherent au vocabulaire repetitif, et
# peut (rarement) refuser une reprise purement pronominale ("elle", "ce nom"). C'est un
# plancher objectif et mesurable, pas un juge litteraire : la relecture humaine des
# nouveaux scenarios reste la passe finale (§24).
CAUSAL_MIN_SHARED = 2

STOPWORDS: frozenset[str] = frozenset("""
le la les un une des du de d au aux et ou mais donc or ni car que qui quoi dont ce cette
ces cet il elle ils elles tu te toi vous nous je on se sa son ses leur leurs mon ma mes
ton ta tes notre votre vos pas plus moins tres bien mal tout toute tous toutes rien
quelque quelques chaque autre autres meme dans sur sous vers chez par pour avec sans
entre avant apres pendant depuis jusqu contre est sont etait etaient sera seront a ont
avait avaient aura fait faire fais vient viens venir va vas aller alle allee peut peux
pouvoir veut veux vouloir dit dire dis comme alors aussi encore deja puis quand lorsque
si ne comment pourquoi ici la-bas cela celui celle ceux celles votre notre chose choses
temps premiere premier derniere dernier autour ensuite enfin jamais toujours devant
derriere pres loin grand grande petit petite vieux vieille
""".split())

# ---------------------------------------------------------------------------
# Geste verbalise (25.4bis) - champ lexical par famille/tag + lexique des cartes canon.
# CALIBRATION : la regle et le lexique sont regles pour que les 67 beats etalon passent.
# Regle : le geste PASS si (ancre d'action ET ancre d'un trait) OU (ancres de 2 traits
# distincts) - en fiction l'action se manifeste souvent A TRAVERS le trait joue
# (Perception via Memoire des Pierres = un seul geste), observe 4 fois dans les etalons.
# LIMITE ASSUMEE : lexique fini -> une periphrase inedite peut donner un faux negatif ;
# on etend alors le champ lexical (jamais l'inverse : pas de suppression de controle).
# ---------------------------------------------------------------------------
LEXICAL_FIELD: dict[str, list[str]] = {
    # actions (familles)
    "perception": ["regard", "yeux", "oeil", "observ", "scrut", "examin", "remarqu",
                   "vois", "vue", "lire", "lis ", "memoire", "souvien", "guett", "ecout",
                   "oreille", "doigt", "retiens", "suis les"],
    "corps": ["corps", "jambe", "bras", "main", "epaule", "force", "pouss", "port",
              "soulev", "grimp", "descend", "march", "pas ", "tien", "tenir", "souffle",
              "nage", "cour", "tire", "vigueur"],
    "parole": ["parl", "dis ", "dit ", "mot", "voix", "racont", "demand", "repond",
               "nomme", "chant", "recit", "appelle", "salu", "boniment", "marchand",
               "propos", "prononc", "ton nom", "condition"],
    "intuition": ["flair", "instinct", "pressent", "sens ", "sent", "devine",
                  "confiance", "ecoute", "laisse venir"],
    "monde": ["rite", "rituel", "signe", "offrande", "offr", "salut", "salue",
              "formule", "trace", "coutume", "cercle", "don", "sang", "accepte"],
    # tags (concepts-coeur MerlinTags + synonymes de la table SYNONYMS)
    "sens": ["regard", "yeux", "oeil", "vois", "vue", "ecout", "oreille", "observ",
             "scrut", "examin", "remarqu", "doigt"],
    "savoir": ["savoir", "connai", "reconnai", "compren", "dedui"],
    "memoire": ["memoire", "souvien", "souvenir", "rappel", "retiens", "passe"],
    "vigilance": ["guet", "veille", "vigilan", "attent", "prudence", "prudent", "surveill"],
    "force": ["force", "pouss", "soulev", "bris", "frapp", "poigne", "vigueur"],
    "agilite": ["agile", "souple", "esquiv", "bond", "leste", "faufil", "equilibre"],
    "endurance": ["endur", "tien", "tenir", "tenu", "resist", "encaiss", "effort",
                  "souffle", "sans ceder", "sans lacher", "jusqu'au bout", "un pas apres"],
    "finesse": ["finesse", "delicat", "precis", "adresse", "doigt"],
    "empathie": ["douceur", "doux", "compassion", "coeur", "apais", "confiance",
                 "ecout", "soign", "sans le presser"],
    "verbe": ["parl", "mot", "voix", "verbe", "nomme", "racont", "dis ", "dit "],
    "ruse": ["ruse", "malice", "malic", "detour", "feint", "tromp", "habile", "astuce",
             "piege", "boniment", "marchand", "condition"],
    "autorite": ["autorite", "ordre", "command", "impose", "ferme"],
    "franchise": ["franc", "franch", "verite", "vrai", "sincer", "honnete", "droit",
                  "sans detour"],
    "instinct": ["instinct", "flair", "pressent", "devine", "sent"],
    "nature": ["nature", "bete", "plante", "arbre", "seve", "foret", "vivant",
               "corbeau", "oiseau"],
    "vision": ["vision", "reve", "presage", "augure"],
    # "prononcer/murmurer un nom", "runes" = incantation (synonyme canon de rituel,
    # MerlinTags.SYNONYMS) : ajoutes apres la mesure E4B (periphrases legitimes refusees).
    "rituel": ["rite", "rituel", "signe", "formule", "ceremonie", "incant",
               "prononc", "murmure le nom", "murmures le nom", "nom ancien", "rune"],
    "sacrifice": ["sacrif", "offrande", "offr", "don", "donn", "renonc", "sang", "prix"],
    "equilibre": ["equilibre", "harmonie", "paix", "balance", "mesure"],
    # "voile entre les mondes", "passage cache" : images canon du mystere observees
    # dans la prose E4B (extension post-mesure ; "voile" seul serait ambigu en falaises).
    "mystere": ["mystere", "secret", "enigme", "inconnu", "etrange",
                "voile entre les mondes", "passage cache"],
}

# Cartes canon vues dans les etalons -> ancres specifiques (completent les mots du label).
CARD_LEXICON: dict[str, list[str]] = {
    "oeil du guetteur": ["oeil", "regard", "yeux", "guett"],
    "flair ancien": ["flair", "pressent", "instinct"],
    "memoire des pierres": ["memoire", "pierre", "retiens", "lignes"],
    "regard sur": ["regard", "oeil", "yeux"],
    "parole franche": ["franc", "franch", "verite", "sincer"],
    "franc-parler": ["franc", "franch"],
    "vieux signes": ["signe", "trace", "rite"],
    "main tendue": ["main", "tend", "propos"],
    "prise ferme": ["prise", "ferme", "serr", "poigne", "tire"],
    "pas du pelerin": ["pas ", "marche", "pelerin", "un pas"],
    "pas sur": ["pas ", "pied", "appui"],
    "souffle long": ["souffle", "respir"],
    "sang donne": ["sang", "don", "goutte", "entaille", "couler"],
    "langue vive": ["langue", "mot", "repartie", "marchand"],
    "fil de memoire": ["memoire", "souvien", "fil"],
    "baume de sureau": ["baume", "soin", "onguent"],
    "rameau vert": ["rameau", "branche"],
}

# ---------------------------------------------------------------------------
# Parsing du markup §25
# ---------------------------------------------------------------------------

ITEM_RE = re.compile(
    r"<section class=\"beat\">(.*?)</section>|<div class=\"(merlin|epilogue)\">(.*?)</div>",
    re.S,
)
DIV_RE = re.compile(
    r"<div class=\"(scene|bandeau|choix|geste|reaction|deltas)\">(.*?)</div>", re.S
)
KW_RE = re.compile(r"<span class=\"kw kw-([a-z]+)\">(<b><i>|<b>)")
FAM_RE = re.compile(r"<span class=\"fam fam-([a-z]+)\">")
TAG_RE = re.compile(r"<[^>]+>")


def norm(s: str) -> str:
    """Minuscule sans accents (aligne sur MerlinTags.normalize). Les ligatures oe/ae ne
    sont PAS decomposees par NFD (compatibilite, pas canonique) : mapping explicite,
    sinon 'oeil' ne matche jamais 'œil' ni 'choeur' 'Chœur'."""
    s = s.lower().replace("œ", "oe").replace("æ", "ae")
    s = unicodedata.normalize("NFD", s)
    return "".join(c for c in s if unicodedata.category(c) != "Mn")


def strip_tags(h: str) -> str:
    return TAG_RE.sub(" ", h)


def sentences(text: str) -> list[str]:
    t = re.sub(r"\s+", " ", text).strip()
    t = t.replace("«", " ").replace("»", " ")
    parts = re.split(r"(?<=[.!?…])\s+", t)
    return [p.strip() for p in parts if p.strip() and re.search(r"[A-Za-zÀ-ſ]", p)]


def words(sent: str) -> list[str]:
    return re.findall(r"[A-Za-zÀ-ſ'’-]+", sent)


def content_words(text: str) -> set[str]:
    out: set[str] = set()
    for w in words(strip_tags(text)):
        n = norm(w)
        if len(n) >= 5 and n not in STOPWORDS:
            out.add(n)
    return out


@dataclass
class Beat:
    scene: str = ""
    bandeau: str = ""
    choix: str = ""
    geste: str = ""
    reaction: str = ""
    deltas: str = ""
    index: int = 0

    @property
    def is_epreuve(self) -> bool:
        """Beat d'epreuve = porte un bandeau. Les beats marchand/dette n'en ont pas
        (observe etalon_01 beats 5 et 8 : troc et reglement de dette, choix libre)."""
        return bool(self.bandeau.strip())


@dataclass
class Parsed:
    header_ok: bool = False
    title: str = ""
    pitch: str = ""
    envergure: str = ""
    items: list = field(default_factory=list)      # [("beat", Beat) | ("merlin", str) | ("epilogue", str)]
    beats: list = field(default_factory=list)      # [Beat]
    quests: list = field(default_factory=list)     # [[Beat, ...], ...]
    interior_merlins: int = 0


def parse_scenario_html(html: str) -> Parsed:
    p = Parsed()
    p.header_ok = bool(re.search(r"<article[^>]*>", html)) and bool(re.search(r"<header>", html))
    m = re.search(r"<h2>(.*?)</h2>", html, re.S)
    p.title = strip_tags(m.group(1)).strip() if m else ""
    m = re.search(r"<p class=\"pitch\">(.*?)</p>", html, re.S)
    p.pitch = m.group(1).strip() if m else ""
    m = re.search(r"<p class=\"envergure\">(.*?)</p>", html, re.S)
    p.envergure = strip_tags(m.group(1)).strip() if m else ""

    idx = 0
    for it in ITEM_RE.finditer(html):
        if it.group(1) is not None:
            divs = dict(DIV_RE.findall(it.group(1)))
            idx += 1
            b = Beat(index=idx, **{k: divs.get(k, "") for k in
                                   ("scene", "bandeau", "choix", "geste", "reaction", "deltas")})
            p.items.append(("beat", b))
            p.beats.append(b)
        else:
            p.items.append((it.group(2), it.group(3)))

    # Decoupage en quetes : les <div class="merlin"> INTERIEURS (entre deux beats) sont
    # les charnieres (§25.4). Le dernier merlin interieur suivi d'exactement 1 beat est
    # la veille_climax (il appartient a la DERNIERE quete, pas une frontiere) - fiable
    # car une quete fait toujours >= 2 beats (R120), donc un segment final d'1 beat ne
    # peut venir que de la veille_climax. Verifie sur les 10 etalons.
    first_beat = next((i for i, (k, _) in enumerate(p.items) if k == "beat"), None)
    last_beat = max((i for i, (k, _) in enumerate(p.items) if k == "beat"), default=None)
    segments: list[list[Beat]] = [[]]
    interior = 0
    if first_beat is not None:
        for i, (k, payload) in enumerate(p.items):
            if k == "beat":
                segments[-1].append(payload)
            elif k == "merlin" and first_beat < i < last_beat:
                interior += 1
                segments.append([])
    p.interior_merlins = interior
    segments = [s for s in segments if s]
    if len(segments) >= 2 and len(segments[-1]) == 1:
        # veille_climax : re-colle le dernier beat a la quete precedente
        segments[-2].extend(segments[-1])
        segments.pop()
    p.quests = segments
    return p


# ---------------------------------------------------------------------------
# Controles - chacun retourne une liste de (niveau, code, message)
# niveau : "FAIL" (bloque), "WARN" (a relire), "INFO"
# ---------------------------------------------------------------------------

Issue = tuple[str, str, str]


def check_structure(p: Parsed) -> list[Issue]:
    out: list[Issue] = []
    if not p.header_ok:
        out.append(("FAIL", "structure.article", "article ou header manquant"))
    if not p.title:
        out.append(("FAIL", "structure.title", "h2 (titre) manquant ou vide"))
    if not p.pitch:
        out.append(("FAIL", "structure.pitch", "p.pitch manquant ou vide"))
    if not p.envergure:
        out.append(("FAIL", "structure.envergure", "p.envergure manquant ou vide"))
    if not p.beats:
        out.append(("FAIL", "structure.beats", "aucun beat"))
        return out
    for b in p.beats:
        for div in ("scene", "choix", "geste"):
            if not getattr(b, div).strip():
                out.append(("FAIL", "structure.beat", f"beat {b.index} : div {div} manquante"))
        if b.is_epreuve:
            ch = strip_tags(b.choix)
            mm = re.match(r"\s*Geste\s*:\s*([^·]+?)(?:\s*·\s*(.+))?$", ch.strip())
            if not mm:
                out.append(("FAIL", "structure.choix",
                            f"beat {b.index} : choix illisible ({ch.strip()[:60]!r})"))
            else:
                action = mm.group(1).strip()
                if action not in ACTIONS:
                    out.append(("FAIL", "structure.choix",
                                f"beat {b.index} : action inconnue {action!r} (attendu {ACTIONS})"))
    kinds = [k for k, _ in p.items]
    if kinds.count("epilogue") != 1:
        out.append(("FAIL", "structure.epilogue",
                    f"exactement 1 epilogue attendu ({kinds.count('epilogue')} trouve)"))
    return out


def _parse_envergure_tier(envergure: str) -> tuple[str, int | None]:
    """Retourne (tier, quetes declarees explicitement ou None)."""
    n = norm(envergure)
    tier = ""
    for key in ("veillee", "breve", "periple", "odyssee"):
        if key in n:
            tier = key
            break
    m = re.search(r"(\d+)\s*quete", n)
    return tier, (int(m.group(1)) if m else None)


def check_envergure(p: Parsed) -> list[Issue]:
    out: list[Issue] = []
    tier, declared = _parse_envergure_tier(p.envergure)
    nq = len(p.quests)
    if not tier:
        out.append(("FAIL", "envergure.libelle",
                    f"envergure {p.envergure!r} : aucun tier reconnu (veillee/breve/periple/odyssee)"))
        return out
    lo, hi = ENVERGURE_BOUNDS[tier]
    if not (lo <= nq <= hi):
        out.append(("FAIL", "envergure.conformite",
                    f"envergure {tier!r} declare {lo}-{hi} quete(s), structure = {nq}"))
    if declared is not None and declared != nq:
        out.append(("FAIL", "envergure.declaree",
                    f"envergure annonce {declared} quetes, structure = {nq}"))
    for qi, q in enumerate(p.quests, 1):
        if not (QUEST_BEATS_MIN <= len(q) <= QUEST_BEATS_MAX):
            out.append(("FAIL", "envergure.quete",
                        f"quete {qi} : {len(q)} beats (borne R120 : {QUEST_BEATS_MIN}-{QUEST_BEATS_MAX})"))
    return out


def _quest_text(p: Parsed, qi: int) -> str:
    """Texte d'une quete = beats du segment + merlins adjacents (les charnieres castent
    parfois la figure : 'Kado t'attend en bas' dans le preambule, observe etalon_02)."""
    parts = [b.scene + " " + b.geste + " " + b.reaction for b in p.quests[qi]]
    merlins = [payload for k, payload in p.items if k == "merlin"]
    # preambule rattache a la quete 1 ; cloture et charnieres a toutes (approximation
    # volontairement genereuse : le casting §25.2 exige >= 1 figure par quete, la
    # figure peut etre annoncee par Merlin a la charniere).
    if qi == 0 and merlins:
        parts.append(merlins[0])
    if merlins:
        parts.extend(merlins[1:])
    return strip_tags(" ".join(parts))


def check_casting(p: Parsed, figures_field: str = "") -> list[Issue]:
    out: list[Issue] = []
    for qi in range(len(p.quests)):
        text = _quest_text(p, qi)
        ntext = norm(text)
        found = []
        for fig, aliases in ROSTER_ALIASES.items():
            for a in aliases:
                if norm(a) in ntext:
                    found.append(fig)
                    break
        if not found:
            out.append(("FAIL", "casting.quete",
                        f"quete {qi + 1} : aucune figure du Roster §6 / pilier / marchand detectee"))
    # Noms canon mal orthographies (distance d'edition 1 sur un alias long) = hallucination.
    all_text = strip_tags(" ".join(str(x) for _, x in p.items if not isinstance(x, Beat)))
    all_text += " " + " ".join(b.scene + b.geste + b.reaction for b in p.beats)
    caps = set(re.findall(r"\b[A-ZÀ-Ü][a-zà-ÿ’'-]{3,}\b", all_text))
    known = {norm(a) for al in ROSTER_ALIASES.values() for a in al}
    known |= {norm(c) for c in CORE_NAMES}
    for cap in caps:
        ncap = norm(cap)
        if ncap in known:
            continue
        for k in known:
            if len(k) >= 4 and abs(len(k) - len(ncap)) <= 1 and _edit1(ncap, k):
                out.append(("FAIL", "casting.orthographe",
                            f"nom {cap!r} : quasi-homonyme d'une figure canon ({k!r}), orthographe canon exigee"))
                break
    # Les noms inedits (figures anonymes des pools §6) sont AUTORISES : INFO seulement.
    return out


def _edit1(a: str, b: str) -> bool:
    """Distance d'edition exactement 1 (substitution/insertion/suppression)."""
    if a == b:
        return False
    la, lb = len(a), len(b)
    if abs(la - lb) > 1:
        return False
    if la == lb:
        return sum(1 for x, y in zip(a, b) if x != y) == 1
    if la > lb:
        a, b, la, lb = b, a, lb, la
    i = j = diff = 0
    while i < la and j < lb:
        if a[i] != b[j]:
            diff += 1
            if diff > 1:
                return False
            j += 1
        else:
            i += 1
            j += 1
    return True


def check_merlin(p: Parsed) -> list[Issue]:
    out: list[Issue] = []
    kinds = [k for k, _ in p.items]
    if not kinds or kinds[0] != "merlin":
        out.append(("FAIL", "merlin.preambule",
                    "le scenario doit s'ouvrir sur le preambule de Merlin (25.4bis : jamais d'entree a froid)"))
    if not kinds or kinds[-1] != "merlin":
        out.append(("FAIL", "merlin.cloture", "le scenario doit se clore sur une replique de Merlin"))
    # Charnieres : transitions (quetes - 1) + veille_climax (1) = nb de quetes.
    expected = len(p.quests)
    if p.interior_merlins != expected:
        out.append(("FAIL", "merlin.charnieres",
                    f"{p.interior_merlins} intervention(s) interieure(s), attendu {expected} "
                    f"(transitions entre quetes + veille du climax)"))
    # Reaction courte (R167) apres les resolutions marquantes. Proxy objectif calibre :
    # (a) toute perte d'Integrite est marquante -> reaction obligatoire (10/10 etalons) ;
    # (b) taux global de reactions >= 40 % des beats (minimum etalon observe : 44 %).
    for b in p.beats:
        d = strip_tags(b.deltas)
        if re.search(r"Int\S*\s*-\d", d) and not b.reaction.strip():
            out.append(("FAIL", "merlin.reaction",
                        f"beat {b.index} : perte d'Integrite ({d.strip()!r}) sans reaction de Merlin"))
    if p.beats:
        ratio = sum(1 for b in p.beats if b.reaction.strip()) / len(p.beats)
        if ratio < 0.40:
            out.append(("FAIL", "merlin.reaction_taux",
                        f"reactions sur {ratio:.0%} des beats (< 40 %, minimum etalon 44 %)"))
    for k, payload in p.items:
        if k == "merlin":
            t = strip_tags(payload).strip()
            if not t.upper().startswith("MERLIN"):
                out.append(("FAIL", "merlin.format",
                            f"intervention sans prefixe MERLIN : {t[:50]!r}"))
    for b in p.beats:
        if b.reaction.strip():
            t = strip_tags(b.reaction).strip()
            if not t.upper().startswith("MERLIN"):
                out.append(("FAIL", "merlin.format",
                            f"beat {b.index} : reaction sans prefixe MERLIN"))
    return out


def check_causal(p: Parsed) -> list[Issue]:
    out: list[Issue] = []
    merlins = [payload for k, payload in p.items if k == "merlin"]
    acc: set[str] = content_words(merlins[0]) if merlins else set()
    for i, b in enumerate(p.beats):
        cw = content_words(b.scene + " " + b.geste)
        if i > 0:
            shared = cw & acc
            if len(shared) < CAUSAL_MIN_SHARED:
                out.append(("FAIL", "causal.beat",
                            f"beat {b.index} : {len(shared)} mot(s) plein(s) partage(s) avec l'amont "
                            f"(seuil {CAUSAL_MIN_SHARED}) - aucune reprise detectable d'un nom/objet/etat"))
        acc |= cw
    return out


def _anchors_for(label: str) -> list[str]:
    key = norm(label).strip()
    key = re.sub(r"\s*\(.*\)$", "", key)  # "(payer autrement)" et autres apartes
    anchors: list[str] = []
    if key in CARD_LEXICON:
        anchors += CARD_LEXICON[key]
    if key in LEXICAL_FIELD:
        anchors += LEXICAL_FIELD[key]
    for w in re.split(r"[\s'-]+", key):
        if len(w) >= 4:
            anchors.append(w[:6])
    return anchors


def check_geste(p: Parsed) -> list[Issue]:
    out: list[Issue] = []
    for b in p.beats:
        if not b.is_epreuve:
            continue  # beats marchand/dette : choix libre, pas de combinaison a verbaliser
        ch = strip_tags(b.choix).strip()
        after = ch.split(":", 1)[-1]
        labels = [x.strip() for x in after.split("·") if x.strip()]
        if not labels:
            continue
        action, traits = labels[0], labels[1:]
        gn = norm(strip_tags(b.geste))
        act_hit = any(a in gn for a in _anchors_for(action))
        trait_hits = sum(1 for t in traits if any(a in gn for a in _anchors_for(t)))
        ok = (act_hit and (trait_hits >= 1 or not traits)) or trait_hits >= 2
        if not ok:
            out.append(("FAIL", "geste.verbalisation",
                        f"beat {b.index} : le geste ne met pas en scene la combinaison "
                        f"({action} / {', '.join(traits)}) - aucune ancre lexicale trouvee"))
    return out


def _prose_blocks(p: Parsed) -> list[str]:
    blocks = [p.pitch]
    for k, payload in p.items:
        if k == "beat":
            blocks += [payload.scene, payload.geste, payload.reaction]
        else:
            blocks.append(payload)
    return [strip_tags(x) for x in blocks if x and x.strip()]


def check_registre(p: Parsed) -> list[Issue]:
    out: list[Issue] = []
    text_all = " ".join(_prose_blocks(p))
    sents = []
    for blk in _prose_blocks(p):
        sents.extend(sentences(blk))
    if not sents:
        return [("FAIL", "registre.vide", "aucune phrase de prose")]
    lens = [len(words(s)) for s in sents]
    mean = sum(lens) / len(lens)
    short = sum(1 for x in lens if x < SHORT_SENT_WORDS) / len(lens)
    longr = sum(1 for x in lens if x > LONG_SENT_WORDS) / len(lens)
    if not (SENT_MEAN_MIN <= mean <= SENT_MEAN_MAX):
        out.append(("FAIL", "registre.moyenne",
                    f"longueur moyenne de phrase {mean:.1f} mots (bande R169 : "
                    f"{SENT_MEAN_MIN:.0f}-{SENT_MEAN_MAX:.0f})"))
    if short > SHORT_SENT_MAX_RATIO:
        out.append(("FAIL", "registre.staccato",
                    f"{short:.0%} de phrases < {SHORT_SENT_WORDS} mots "
                    f"(plafond {SHORT_SENT_MAX_RATIO:.0%} - staccato interdit R169)"))
    if longr > LONG_SENT_MAX_RATIO:
        out.append(("FAIL", "registre.periodes",
                    f"{longr:.0%} de phrases > {LONG_SENT_WORDS} mots "
                    f"(plafond {LONG_SENT_MAX_RATIO:.0%} - periode litteraire interdite R169)"))
    for bad, code in (("—", "registre.cadratin"), ("―", "registre.cadratin")):
        if bad in text_all:
            out.append(("FAIL", code, f"cadratin U+{ord(bad):04X} interdit (R157)"))
            break
    letters = sum(1 for c in text_all if c.isalpha())
    accents = sum(1 for c in text_all if c.isalpha() and unicodedata.decomposition(c))
    if letters and accents / letters < ACCENT_MIN_RATIO:
        out.append(("FAIL", "registre.accents",
                    f"ratio d'accents {accents / letters:.1%} < {ACCENT_MIN_RATIO:.1%} : "
                    f"accents francais absents ou depouilles"))
    ntext = " " + norm(text_all) + " "
    for w in BANNED_WORDS + FOURTH_WALL_WORDS:
        if re.search(r"[^a-z]" + re.escape(w) + r"[^a-z]", ntext):
            kind = "registre.anglicisme" if w in BANNED_WORDS else "registre.4e_mur"
            out.append(("FAIL", kind, f"mot interdit dans la prose : {w!r}"))
    for pat in FOURTH_WALL_PATTERNS:
        if re.search(pat, ntext):
            out.append(("FAIL", "registre.4e_mur", f"bris du 4e mur : motif {pat!r}"))
    return out


def check_indices(p: Parsed) -> list[Issue]:
    out: list[Issue] = []
    for b in p.beats:
        kws = KW_RE.findall(b.scene)
        if not b.is_epreuve:
            if kws:
                out.append(("FAIL", "indices.hors_epreuve",
                            f"beat {b.index} : mots-indices sur un beat sans bandeau"))
            continue
        if not (2 <= len(kws) <= 3):
            out.append(("FAIL", "indices.nombre",
                        f"beat {b.index} : {len(kws)} mot(s)-indice(s) (attendu 2-3, R168)"))
        fams_band = FAM_RE.findall(b.bandeau)
        band_txt = strip_tags(b.bandeau)
        mdiff = re.search(r"difficult\S*\s+(I{1,3})\b", band_txt)
        if not fams_band or not mdiff:
            out.append(("FAIL", "indices.bandeau",
                        f"beat {b.index} : bandeau illisible ({band_txt.strip()[:60]!r})"))
            continue
        diff = len(mdiff.group(1))
        for f in fams_band:
            if f not in FAMILIES:
                out.append(("FAIL", "indices.famille",
                            f"beat {b.index} : famille de bandeau inconnue {f!r}"))
        for fam, inten in kws:
            if fam not in FAMILIES:
                out.append(("FAIL", "indices.famille",
                            f"beat {b.index} : famille kw inconnue {fam!r}"))
            elif fam not in fams_band:
                out.append(("FAIL", "indices.coherence",
                            f"beat {b.index} : kw-{fam} hors des familles du bandeau {fams_band}"))
            wanted = "<b><i>" if diff >= 3 else "<b>"
            if inten != wanted:
                out.append(("FAIL", "indices.intensite",
                            f"beat {b.index} : intensite {inten!r} pour difficulte {diff} "
                            f"(attendu {wanted!r} - gras simple I/II, gras+italique III)"))
    return out


# ---------------------------------------------------------------------------
# Controles unitaires par PIECE (utilises par scenario_forge.py, auto-QC)
# Seuils relaches vs scenario complet : sur 2-5 phrases la variance est forte.
# ---------------------------------------------------------------------------

def qc_piece_prose(text: str, min_sents: int, max_sents: int,
                   mean_lo: float = 7.0, mean_hi: float = 26.0) -> list[str]:
    """Controles registre applicables a une piece isolee. Retourne les erreurs."""
    errs: list[str] = []
    t = strip_tags(text).strip()
    if not t:
        return ["piece vide"]
    if "—" in t or "―" in t:
        errs.append("cadratin interdit")
    sents = sentences(t)
    if not (min_sents <= len(sents) <= max_sents):
        errs.append(f"{len(sents)} phrase(s), attendu {min_sents}-{max_sents}")
    lens = [len(words(s)) for s in sents] or [0]
    mean = sum(lens) / len(lens)
    if not (mean_lo <= mean <= mean_hi):
        errs.append(f"longueur moyenne {mean:.1f} mots hors bande [{mean_lo:.0f}, {mean_hi:.0f}]")
    if lens and max(lens) > 45:
        errs.append(f"phrase de {max(lens)} mots (periode interdite R169)")
    # Plancher d'accents PIECE : plus bas que le plancher scenario (1,2 %) car une piece
    # de 30-50 mots peut etre legitimement pauvre en accents (observe en mesure : une
    # scene correcte a 1,03 %). On vise le francais DEPOUILLE (zero ou quasi-zero accent).
    letters = sum(1 for c in t if c.isalpha())
    accents = sum(1 for c in t if c.isalpha() and unicodedata.decomposition(c))
    if letters > 120 and accents / letters < 0.008:
        errs.append(f"accents francais quasi absents ({accents}/{letters} lettres)")
    ntext = " " + norm(t) + " "
    for w in BANNED_WORDS + FOURTH_WALL_WORDS:
        if re.search(r"[^a-z]" + re.escape(w) + r"[^a-z]", ntext):
            errs.append(f"mot interdit {w!r}")
    if re.search(r"[a-zA-Z]�|<start_of_turn|<end_of_turn", t):
        errs.append("residu de template ou caractere invalide")
    # Troncature en plein vol (budget tokens atteint) : une piece doit se refermer sur
    # une ponctuation terminale. Observe en mesure : preambule coupe sur « a oublié ».
    if not re.search(r"[.!?…»]\s*$", t):
        errs.append("piece coupee en plein vol (pas de ponctuation terminale)")
    return errs


def qc_piece_requires(text: str, required_words: list[str]) -> list[str]:
    """La piece doit contenir chacune des ancres imposees (mots-indices, reprise causale)."""
    tn = norm(strip_tags(text))
    missing = [w for w in required_words if norm(w) not in tn]
    return [f"ancre imposee absente : {w!r}" for w in missing]


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

ALL_CHECKS = (
    ("structure", check_structure),
    ("envergure", check_envergure),
    ("casting", check_casting),
    ("merlin", check_merlin),
    ("causal", check_causal),
    ("geste", check_geste),
    ("registre", check_registre),
    ("indices", check_indices),
)


def qc_scenario(doc: dict) -> dict:
    """QC complet d'un scenario {title, envergure, biome, figures, html}."""
    html = doc.get("html", "")
    if not html.strip():
        return {"title": doc.get("title", "?"), "verdict": "FAIL",
                "issues": [("FAIL", "input.html", "champ html vide")]}
    p = parse_scenario_html(html)
    issues: list[Issue] = []
    for name, fn in ALL_CHECKS:
        if fn is check_casting:
            issues.extend(fn(p, doc.get("figures", "")))
        else:
            issues.extend(fn(p))
    fails = [i for i in issues if i[0] == "FAIL"]
    return {
        "title": doc.get("title", p.title or "?"),
        "quetes": len(p.quests),
        "beats": len(p.beats),
        "verdict": "FAIL" if fails else "PASS",
        "issues": issues,
    }


def _print_report(rep: dict, verbose: bool = True) -> None:
    mark = "PASS" if rep["verdict"] == "PASS" else "FAIL"
    print(f"[{mark}] {rep['title']}  ({rep.get('quetes', '?')} quete(s), {rep.get('beats', '?')} beats)")
    for lvl, code, msg in rep["issues"]:
        if lvl == "FAIL" or verbose:
            print(f"    {lvl:4s} {code:24s} {msg}")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Gate qualite des scenarios (BIBLE §25.5)")
    ap.add_argument("files", nargs="*", help="fichiers scenario JSON")
    ap.add_argument("--library", help="fichier bibliotheque (liste d'entrees)")
    ap.add_argument("--json", dest="json_out", help="ecrit le rapport JSON ici")
    ap.add_argument("--self-test", action="store_true",
                    help="calibre : verifie que les 10 etalons R169 passent")
    args = ap.parse_args(argv)

    docs: list[dict] = []
    if args.self_test:
        base = Path(__file__).resolve().parent.parent / "data" / "ai"
        lib_files = sorted(base.glob("quest_library_*.json"))
        if not lib_files:
            print("self-test : aucune bibliotheque data/ai/quest_library_*.json")
            return 2
        for lf in lib_files:
            data = json.loads(lf.read_text(encoding="utf-8"))
            docs.extend([e for e in data.get("entries", []) if e.get("author") == "etalon"])
    if args.library:
        data = json.loads(Path(args.library).read_text(encoding="utf-8"))
        docs.extend(data.get("entries", data if isinstance(data, list) else []))
    for f in args.files:
        docs.append(json.loads(Path(f).read_text(encoding="utf-8")))
    if not docs:
        ap.print_help()
        return 2

    reports = [qc_scenario(d) for d in docs]
    n_pass = sum(1 for r in reports if r["verdict"] == "PASS")
    for r in reports:
        _print_report(r)
    print(f"\n== {n_pass}/{len(reports)} PASS ==")
    if args.json_out:
        Path(args.json_out).write_text(
            json.dumps(reports, ensure_ascii=False, indent=1), encoding="utf-8")
    return 0 if n_pass == len(reports) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
