#!/usr/bin/env python3
"""Le Grimoire — la Bible du jeu, interrogeable : le socle du SAGE du chat.

Pourquoi. Maxime veut poser des questions de MÉCANIQUES et de LORE dans le
studio (2026-08-25 : « je veux pouvoir parler simplement sur le studio de dev
à MERLIN et lui poser les questions sur les mécaniques de jeu et le lore »).
Les deux interlocuteurs existants ne le savent pas : l'orchestrateur connaît
les agents et la carte du code, le personnage ne connaît que la forêt. Le Sage
répond DEPUIS LES TEXTES — la Bible, et le code qui fait foi — cite sa source,
et avoue quand la Bible ne dit rien : jamais d'invention.

Récupération : découpage de la Bible en sections (titres markdown), score par
recouvrement de mots (minuscules, sans accents), budget ~2 500 caractères. Les
têtes de fichiers du moteur entrent au même barème : sur une question de
règles chiffrées (DC, marges, maîtrise, rareté), le CODE est la source la plus
fraîche — v46 y vit avant d'être documentée dans la Bible.

Stdlib seule. Ne lève jamais : sans dépôt du jeu, les passages sont vides et
le prompt force le Sage à le dire.
"""
from __future__ import annotations

import unicodedata
from pathlib import Path

JEU = Path.home() / "workspace" / "merlin-game"   # même convention que merlin_jeu.py

# Le CODE étiqueté « source de vérité » : les commentaires de tête de ces
# fichiers PORTENT les règles exactes du build courant (2d6, DC, marge sûre,
# familles de tags, chronique cross-run). (titre, chemin, nb de lignes lues).
CODE = [
    ("Moteur de résolution — code, source de vérité",
     "scripts/game/merlin_resolution.gd", 110),
    ("Familles de tags et synonymes — code",
     "scripts/game/merlin_tags.gd", 62),
    ("Chronique cross-run (mémoire du Voyageur) — code",
     "scripts/game/merlin_chronicle.gd", 32),
]

STOP = set("""le la les un une des du de d l au aux et ou mais donc or ni car que qui quoi dont
est sont ont pour par sur sous dans avec sans chez vers entre pas plus moins tres bien tout
tous toute toutes ce cet cette ces son ses leur leurs mon mes ton tes notre nos votre vos il
elle ils elles je tu nous vous on ne se en y comment pourquoi quand combien quel quelle quels
quelles peut faire fait etre avoir si alors aussi meme deja encore jamais comme cela""".split())


def _norme(s: str) -> str:
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    return s.lower()


def _mots(s: str) -> set:
    out, mot = set(), []
    for c in _norme(s):
        if c.isalnum():
            mot.append(c)
        else:
            if len(mot) >= 3:
                out.add("".join(mot))
            mot = []
    if len(mot) >= 3:
        out.add("".join(mot))
    return out - STOP


def _sections() -> list:
    """[(titre, texte, source)] — la Bible découpée par titres + les têtes de code."""
    out = []
    try:
        titre, corps = "Préambule", []
        for ligne in (JEU / "docs" / "BIBLE.md").read_text(
                encoding="utf-8", errors="replace").splitlines():
            if ligne.startswith("#"):
                if corps and "".join(corps).strip():
                    out.append((titre, "\n".join(corps).strip(), "Bible"))
                titre = ligne.lstrip("# ").strip() or titre
                corps = []
            else:
                corps.append(ligne)
        if corps and "".join(corps).strip():
            out.append((titre, "\n".join(corps).strip(), "Bible"))
    except Exception:
        pass
    for titre, chemin, lignes in CODE:
        try:
            texte = "\n".join((JEU / chemin).read_text(
                encoding="utf-8", errors="replace").splitlines()[:lignes])
            out.append((titre, texte, chemin))
        except Exception:
            pass
    return out


def passages(question: str, budget: int = 2500) -> list:
    """Les sections les plus proches de la question — [(titre, extrait, source)]."""
    q = _mots(question)
    if not q:
        return []
    notes = []
    for titre, texte, source in _sections():
        score = 3 * len(q & _mots(titre)) + len(q & _mots(texte[:4000]))
        if score > 0:
            notes.append((score, titre, texte, source))
    notes.sort(key=lambda x: -x[0])
    out, total = [], 0
    for _, titre, texte, source in notes:
        extrait = texte[:1100]
        if total + len(extrait) > budget and out:
            break
        out.append((titre, extrait, source))
        total += len(extrait)
        if len(out) >= 4:
            break
    return out


def references(question: str) -> str:
    """« Bible « titre » · code fichier » — la ligne de sources sous la réponse."""
    refs = []
    for titre, _, source in passages(question):
        refs.append(("Bible « %s »" % titre) if source == "Bible"
                    else ("%s « %s »" % (source, titre)))
    return " · ".join(refs[:4])


def prompt(question: str, echange: str = "") -> str:
    ps = passages(question)
    if ps:
        bloc = "\n\n".join("[%s — %s]\n%s" % (source, titre, extrait)
                           for titre, extrait, source in ps)
    else:
        bloc = "(aucun passage de la Bible ni du code ne correspond à cette question)"
    hist = ("\nCONVERSATION RÉCENTE :\n%s\n" % echange) if echange.strip() else ""
    return (
        "Tu es LE SAGE du studio MERLIN : l'esprit de la Bible du jeu. Tu réponds à "
        "Maxime, le créateur, sur les MÉCANIQUES et le LORE de son jeu.\n"
        "RÈGLES ABSOLUES :\n"
        "- Tu ne réponds QUE depuis les PASSAGES ci-dessous. À contradiction entre le "
        "code et la Bible, le CODE fait foi (c'est le build courant) — signale l'écart.\n"
        "- Termine chaque affirmation importante par sa source entre parenthèses : "
        "(Bible, « titre ») ou (code, fichier).\n"
        "- Si les passages ne répondent pas, dis-le en UNE phrase et propose où "
        "trancher — n'invente JAMAIS une règle ni un nom.\n"
        "- Français, direct, sans préambule. Six phrases au plus, sauf si Maxime "
        "demande le détail.\n\n"
        "=== PASSAGES ===\n%s\n=== FIN DES PASSAGES ===\n"
        "%s\n"
        "LA QUESTION DE MAXIME : %s\n\n"
        "Le Sage :" % (bloc, hist, question))
