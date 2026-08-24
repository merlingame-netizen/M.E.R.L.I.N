#!/usr/bin/env python3
"""Patch v42.1 — le canon a fait déborder le contexte de l'issue.

p61 : prompt_tokens=2045 (plafond n_ctx du Vif), tokens_ecrits=2, SECOURS=4.
L'issue ne garde qu'une règle brève ; le canon complet reste dans les prompts
qui peuplent le monde (sélection, intro, scène), où la marge existe."""
import pathlib
import sys


def exact(texte, vieux, neuf, nom):
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return texte.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")

# C1 — la version brève, posée à côté des deux autres
t = exact(t,
    'const LORE_CANON: String = ',
    '# v42.1 — L'
    "'issue vit dans un contexte de 2048 tokens : le canon complet l'a fait\n"
    "# déborder (p61 : prompt 2045 tok, 2 tokens écrits, 4 bancs). Elle raconte le geste\n"
    "# du joueur, elle ne peuple pas le monde — la règle lui suffit, en trois lignes.\n"
    'const REGLE_PASSE_BREVE: String = "\\nLE VOYAGEUR N\'A AUCUN PASSE ICI : il n\'a jamais rien jure, trahi ni laisse derriere lui, et PERSONNE ne le reconnait. Tout nait maintenant."\n'
    '\n'
    'const LORE_CANON: String = ',
    "C1-breve")

# C2 — la tête d'issue reprend sa taille
t = exact(t,
    '\treturn ex + LORE_CANON + REGLE_PASSE + "\\nREGLES : Raconte l\'issue a la 2e PERSONNE',
    '\treturn ex + REGLE_PASSE_BREVE + "\\nREGLES : Raconte l\'issue a la 2e PERSONNE',
    "C2-issue")

p.write_text(t, encoding="utf-8")
print("OK merlin_prompt_builder.gd")
print("v42.1 applique")
"""marqueur: v42.1"""
