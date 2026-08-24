#!/usr/bin/env python3
"""Patch v45 — le trait donne la manière, et l'issue ouvre la suite.

v36 avait donné une règle dure au VERBE ; le TRAIT restait une évocation libre, d'où
« OBSERVER + Le Pressentiment » rendu par des mains qui poussent une pierre. Et rien
n'obligeait l'issue à enchaîner : d'où le récit haché."""
import pathlib
import sys


def exact(texte, vieux, neuf, nom):
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return texte.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")

# ── T1 : la règle du TRAIT, juste après celle du verbe (tête stable = quasi gratuite) ──
t = exact(t,
    "Une premiere phrase qui ne joue pas ce verbe est HORS-SUJET.",
    "Une premiere phrase qui ne joue pas ce verbe est HORS-SUJET. LE TRAIT DONNE LA MANIERE, et elle se voit dans le MEME geste : un trait de PERCEPTION (voir, sentir, pressentir, se souvenir, ecouter) ne touche RIEN et n'ajoute AUCUN geste physique — il regarde, il ecoute, il devine ; un trait de PAROLE se prononce ; un trait de FORCE ou d'AGILITE engage le corps ; un trait d'OMBRE appelle une force trouble. INTERDIT d'inventer un geste (des mains posees, un fer, un pas, une main tendue) que NI le verbe NI le trait ne portent : c'est la faute la plus grave.",
    "T1-trait")

# ── T2 : l'OUTRO — la dernière phrase ouvre la suite ──
t = exact(t,
    "Pas de liste ni de chiffres. Termine sur une phrase complete.",
    "Pas de liste ni de chiffres. TERMINE par UNE derniere phrase qui OUVRE LA SUITE : ce que le Voyageur fait maintenant, ou ce qui l'attend au pas suivant. Elle ne resume RIEN et ne commente RIEN — elle relance, et elle est courte. Termine sur une phrase complete.",
    "T2-outro")

# ── T3 : la cible de phrases annonce l'outro (sinon le modèle sacrifie la conséquence) ──
t = exact(t,
    '\tvar cible_phrases: String = "2 a 3 phrases (3 a 4 si le moment est un Climax ou une reussite eclatante)"\n'
    '\tif richesse == 1:\n'
    '\t\tcible_phrases = "2 a 3 phrases (3 a 4 si le moment est un Climax ou une reussite eclatante)"\n',
    '\tvar cible_phrases: String = "2 a 3 phrases PUIS la phrase de suite (3 a 4 plus la suite si le moment est un Climax ou une reussite eclatante)"\n'
    '\tif richesse == 1:\n'
    '\t\tcible_phrases = "2 a 3 phrases PUIS la phrase de suite (3 a 4 plus la suite si le moment est un Climax ou une reussite eclatante)"\n',
    "T3-cible")

# ── T4 : de quoi loger l'outro (~20 tokens) sans rogner la conséquence ──
t = exact(t,
    '\tvar tok_budget: int = 140 if long_form else 105\n'
    '\tif richesse == 1:\n'
    '\t\ttok_budget = 160 if long_form else 115\n',
    "\t# v45 — +20 tokens : la phrase de suite doit tenir SANS rogner la consequence.\n"
    '\tvar tok_budget: int = 160 if long_form else 125\n'
    '\tif richesse == 1:\n'
    '\t\ttok_budget = 180 if long_form else 135\n',
    "T4-budget")

p.write_text(t, encoding="utf-8")
print("OK merlin_prompt_builder.gd")
print("v45 applique")
"""marqueur: v45"""
