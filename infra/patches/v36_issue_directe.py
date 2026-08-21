#!/usr/bin/env python3
"""Patch v36 — l'issue DIRECTE : 2-3 phrases sèches, verbe joué littéralement, zéro image.

Retour Maxime sur p50 : trop de texte, trop imagé, actions incohérentes avec le geste
choisi, trop long. Racine de l'incohérence : le VERBE de la tuile (played_cards[0],
contrat R20) n'entrait jamais dans le prompt d'issue."""
import pathlib
import sys


def exact(texte: str, vieux: str, neuf: str, nom: str) -> str:
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


def exact_n(texte: str, vieux: str, neuf: str, nom: str, attendu: int) -> str:
    n = texte.count(vieux)
    if n != attendu:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu %d) : %r" % (nom, n, attendu, vieux[:80]))
    return texte.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")

# T1 — cibles de phrases : 2-3 sec par defaut (richesse 0 ET 1)
t = exact(t,
    '\tvar cible_phrases: String = "2 a 4 phrases (4 a 5 si le moment est un Climax ou une reussite eclatante)"\n'
    '\tif richesse == 1:\n'
    '\t\tcible_phrases = "3 a 5 phrases (5 a 6 si le moment est un Climax ou une reussite eclatante)"\n',
    "\t# v36 (Maxime : « trop de texte, pas assez direct ») : 2-3 phrases sèches par défaut.\n"
    '\tvar cible_phrases: String = "2 a 3 phrases (3 a 4 si le moment est un Climax ou une reussite eclatante)"\n'
    '\tif richesse == 1:\n'
    '\t\tcible_phrases = "2 a 3 phrases (3 a 4 si le moment est un Climax ou une reussite eclatante)"\n',
    "T1-cibles")

# T2 — zero image dans la tete d'issue (l'exception Climax disparait)
t = exact(t,
    " UNE image concrete AU PLUS par issue ; INTERDIT les metaphores filees, le lyrisme et les comparaisons ('comme si', 'tel un', 'pareil a') — sauf UNE, breve, si le moment est un Climax.",
    " AUCUNE image, AUCUNE metaphore, AUCUNE comparaison ('comme si', 'tel un', 'pareil a') — nulle part, Climax compris : du CONCRET sec, l'ambiance vient des FAITS.",
    "T2-zero-image-issue")

# T3 — la regle du VERBE, dans la tete stable
t = exact(t,
    "Referme la balise [/i] a la fin de cette premiere phrase.",
    "Referme la balise [/i] a la fin de cette premiere phrase. Le VERBE DU GESTE t'est donne en fin de prompt : ta premiere phrase l'ACCOMPLIT LITTERALEMENT — PARLER = au moins une parole PRONONCEE ; COMBATTRE = un coup ou un affrontement REEL contre un etre nomme ; OBSERVER = un examen precis qui APPREND quelque chose ; REVELER = un cache rendu VISIBLE ou nomme ; AGIR = un geste physique precis sur un objet nomme. Une premiere phrase qui ne joue pas ce verbe est HORS-SUJET.",
    "T3-verbe-tete")

# T4 — le verbe entre dans la QUEUE du prompt
t = exact(t,
    '\tvar queue: String = "\\n" + ctx + "CE QUI SE PASSAIT : " + situ_txt + "\\n" + combo + reg_hint \\\n',
    "\t# v36 — le VERBE du geste (tuile jouee, played_cards[0] par contrat R20) entre ENFIN dans\n"
    "\t# le prompt : sans lui, COMBATTRE donnait un fer plante en terre et PARLER une main posee.\n"
    '\tvar verbe_hint: String = ""\n'
    '\tif played_cards.size() >= 1 and played_cards[0] is Object and "card_name" in played_cards[0]:\n'
    '\t\tvar _vb: String = str(played_cards[0].card_name).strip_edges()\n'
    '\t\tif _vb != "":\n'
    '\t\t\tverbe_hint = "\\nVERBE DU GESTE : " + _vb + " — ta PREMIERE phrase l\'accomplit litteralement."\n'
    '\tvar queue: String = "\\n" + ctx + "CE QUI SE PASSAIT : " + situ_txt + "\\n" + combo + reg_hint + verbe_hint \\\n',
    "T4-verbe-queue")

# T5 — budgets resserres
t = exact(t,
    '\tvar tok_budget: int = 200 if long_form else 130\n'
    '\tif richesse == 1:\n'
    '\t\ttok_budget = 280 if long_form else 200\n',
    "\t# v36 — 2-3 phrases seches : ~110 tokens suffisent, l'ecriture tombe a ~15-25 s.\n"
    '\tvar tok_budget: int = 140 if long_form else 105\n'
    '\tif richesse == 1:\n'
    '\t\ttok_budget = 160 if long_form else 115\n',
    "T5-budgets")

# T6 — zero image PARTOUT : scene lookahead + les deux variantes d'arc (3 occurrences)
t = exact_n(t,
    "une image au plus, pas de lyrisme ni de comparaisons",
    "AUCUNE image, AUCUN lyrisme, AUCUNE comparaison",
    "T6-zero-image-scenes", 3)

p.write_text(t, encoding="utf-8")
print("OK merlin_prompt_builder.gd")
print("v36 applique")
"""marqueur: v36"""
