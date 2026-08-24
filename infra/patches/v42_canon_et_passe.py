#!/usr/bin/env python3
"""Patch v42 — le Voyageur n'a pas de passé inventé, et le canon borne le monde.

Les pitchs de sélection et l'intro prêtaient au Voyageur une faute ancienne, un retour,
des voyages — alors que rien n'est écrit nulle part. Règle stricte + roster canon,
posés en tête stable (cache de préfixe : payés une fois)."""
import pathlib
import sys


def exact(texte, vieux, neuf, nom):
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return texte.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")

# ── B0 : les deux constantes, posées avant la première fonction statique du fichier ──
t = exact(t,
    "static func scene_jit(",
    "# v42 — LE PASSÉ DU VOYAGEUR N'EXISTE PAS TANT QU'IL N'EST PAS ÉCRIT (bible §6 R166 :\n"
    "# le seul passé admis est composé depuis MerlinChronicle). Le modèle brodait des fautes\n"
    "# anciennes et des retours — « répare le pacte que tu as enfreint », « je t'ai vu revenir\n"
    "# de tes longs voyages » — sur un personnage qui n'a jamais rien vécu ici.\n"
    "const REGLE_PASSE: String = \"\\nLE VOYAGEUR N'A AUCUN PASSE ICI : il n'a jamais rien jure, rien trahi, rien enfreint, rien laisse derriere lui, et il ne revient de nulle part. INTERDIT de lui preter une faute ancienne, une dette, un serment deja pris, un retour, une reputation ou des voyages passes ; INTERDIT qu'un personnage le reconnaisse, l'ait 'deja vu' ou lui rappelle quoi que ce soit. Tout ce qui se joue NAIT MAINTENANT, sous ses yeux.\"\n"
    "\n"
    "# v42 — LE CANON (bible §6) : le monde a des bornes, et des figures qui portent des noms.\n"
    "const LORE_CANON: String = \"\\nCANON DE BROCELIANDE (le seul monde autorise) : une foret revee qui boucle sur elle-meme ; brume, dolmens, houx, fougeres, sources, pierres levees, huttes de chaume. FIGURES NOMMEES qui peuvent apparaitre : le Choeur des Druides (deux voix qui se repetent et se contredisent), l'Ankou (le passeur, pose, sans malice ni pitie), la Lavandiere de Nuit (elle lave des linceuls et reclame de l'aide, jamais sans prix), les korrigans (petit peuple moqueur, cornes rouges), Kado le Cordier (humain perdu, sans faction), le Chevalier a l'armure ternie (il rejoue sa defaite), l'Enfant (innocent perdu qu'on protege), le colporteur (il vend contre des gwenneg), Arthur (rare, paranoiaque). N'EXISTENT PAS : les dieux, les demons, les anges, la magie a incantations, les chevaliers de la Table Ronde autres qu'Arthur, les royaumes lointains, toute epoque autre que celtique, tout objet moderne. Jamais d'anglicisme, jamais le 4e mur.\"\n"
    "\n"
    "static func scene_jit(",
    "B0-constantes")

# ── B1 : la tête stable des ISSUES porte le canon et la règle (payés une fois par session) ──
t = exact(t,
    '\treturn ex + "\\nREGLES : Raconte l\'issue a la 2e PERSONNE',
    '\treturn ex + LORE_CANON + REGLE_PASSE + "\\nREGLES : Raconte l\'issue a la 2e PERSONNE',
    "B1-issue")

# ── B2 : la scène lookahead — mêmes bornes, dans son bloc fixe ──
t = exact(t,
    '\t\t+ "\\nLa scene = 1 a 2 phrases COURTES et CONCRETES',
    '\t\t+ LORE_CANON + REGLE_PASSE \\\n'
    '\t\t+ "\\nLa scene = 1 a 2 phrases COURTES et CONCRETES',
    "B2-scene")

# ── B3 : la SÉLECTION — c'est là que naissaient les pitchs à faute ancienne ──
t = exact(t,
    '\tvar usr: String = bloc + "\\nEn tant que MERLIN, propose 3 aventures au Voyageur dans %s.',
    '\tvar usr: String = bloc + LORE_CANON + REGLE_PASSE + "\\nUne quete ne REPARE JAMAIS une faute du Voyageur et ne lui RECLAME JAMAIS une dette : elle lui propose d\'aller CHERCHER, APAISER ou AFFRONTER quelque chose qui existait AVANT lui et SANS lui." \\\n'
    '\t\t+ "\\nEn tant que MERLIN, propose 3 aventures au Voyageur dans %s.',
    "B3-selection")

# ── B4 : l'INTRO contée par Merlin ──
t = exact(t,
    '\tvar usr: String = "Quete proposee au Voyageur: \\"%s\\" -- %s%s\\nEn tant que MERLIN qui conte',
    '\tvar usr: String = LORE_CANON + REGLE_PASSE + "\\nQuete proposee au Voyageur: \\"%s\\" -- %s%s\\nEn tant que MERLIN qui conte',
    "B4-intro")

p.write_text(t, encoding="utf-8")
print("OK merlin_prompt_builder.gd")
print("v42 applique")
"""marqueur: v42"""
