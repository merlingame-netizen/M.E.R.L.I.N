#!/usr/bin/env python3
"""Patch v52 — LE LORE ENTRE DANS LA CHAINE CHAUDE.

LA MESURE. Sur les 17 249 caracteres de narration de p74, ZERO figure du canon : ni l'Ankou, ni la
Lavandiere, ni les korrigans, ni Fanch, ni le Chevalier. Un seul lieu, « Gue des Brumes », et c'est
le nom du biome, insere mecaniquement. Verifie que ce n'est PAS un defaut de mesure : neutraliser
les accents des deux cotes ne change rien.

CE QUE L'ENQUETE A ETABLI, ET QUI N'EST PAS CE QUE JE CROYAIS. Le canon n'est pas mort : il
travaille tres bien la ou il est injecte. La preuve tient dans les trois sentiers proposes au
depart de p74 :

    sentier 0  « Le Sentier Qui Se Re-tisse »  ... des corbeaux d'ocre, une boucle sans fin
    sentier 1  « Le Secret du Chene Tordu »    ... avant que FANCH ne trouve ton GWENNEG
    sentier 2  « Le Murmure du Tertre »        ... grimpe sur LE TERTRE DES NEUF

Les sentiers 1 et 2 portaient des noms canoniques. Le harnais prend toujours sentiers[0], et le 0
etait le seul des trois sans aucun nom. Le canon avait fait son travail ; on a jete le resultat.

DEUXIEME FAIT, DECISIF. LORE_CANON n'est injecte qu'a trois endroits : la selection (:220),
l'intro (:258) et scene_jit (:363). Or scene_jit n'a produit AUCUN beat de p74 (provenances : 16
« arc », 4 « secours »). La fabrique qui a ecrit seize beats sur vingt, `arc_tranche` (:387), ne
porte pas le canon du tout. Le modele ne nomme que ce que son prompt lui donne — et son prompt ne
lui donnait rien.

LES DEUX CORRECTIFS, qui visent les deux maillons et non le meme deux fois :

1. LA LOTERIE DU SENTIER 0 EST FERMEE. La consigne de pitch demandait « QUI ou QUOI s'y oppose (un
   etre, un serment, une force nommee) » — une case deja prevue pour un nom, mais jamais contrainte.
   Elle exige desormais une FIGURE ou un LIEU du canon, nomme, et different d'un pitch a l'autre.
   Quel que soit le sentier tire, le lore monte a bord. Le pitch retenu est ensuite reinjecte dans
   CHAQUE prompt d'arc (:413-416, « pour la quete "%s" (%s) »), dans l'intro et dans scene_jit :
   un nom canonique dans le pitch, c'est un nom canonique sous les yeux du modele a chaque tranche.
   Cout : ~55 tokens, UNE fois par partie.

2. LES NOMS ENTRENT DANS `arc_tranche`. Pas LORE_CANON en entier : il pese 1941 caracteres, soit
   ~561 tokens au ratio de 3,46 car/token — ratio MESURE sur p74, ou les beats 12 et 13 ont relu
   6025 et 5977 caracteres pour 1741 et 1728 tokens, les deux premieres relectures a cache vide
   jamais observees sur cette machine. A six tranches pour une quete de 25 beats, l'injecter en
   entier ajouterait ~60 s a une attente deja hors cible, et n_ctx ne vaut que 2048 sur les deux
   voies. On injecte donc la seule LISTE DES NOMS — 427 caracteres, ~123 tokens mesures — la ou le
   modele en a besoin : un vingtieme du budget, pour le seul contenu qui manquait.

CE QUE CE PATCH NE FAIT PAS. Il ne touche pas au banc de secours, qui a ecrit les quatre derniers
beats de p74 sans porter ni lore ni continuite. Un beat de banc restera muet sur le canon quoi
qu'on fasse ici : c'est le chantier du timeout (v51), pas celui-ci.
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return t.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")

# 1. Chaque pitch doit nommer le canon — plus de loterie sur l'index du sentier.
t = exact(
    t,
    "puis QUI ou QUOI s'y oppose (un etre, un serment, une force nommee), "
    "puis ce qui arrive SI TU ECHOUES.",

    "puis QUI ou QUOI s'y oppose : OBLIGATOIREMENT une FIGURE ou un LIEU du CANON ci-dessus, "
    "NOMME (l'Ankou, la Lavandiere de Nuit, les korrigans, Fanch le Trotteur, le Choeur des "
    "Druides, le Chevalier a l'armure ternie, le Val sans Retour, la Fontaine de Barenton, le "
    "Tertre des Neuf, le Chene Creux...), et JAMAIS le meme dans deux pitchs, "
    "puis ce qui arrive SI TU ECHOUES.",
    "la consigne de pitch",
)

# 2. Les noms du canon entrent dans la fabrique qui ecrit reellement les beats.
t = exact(
    t,
    "\tvar usr: String = faction_block + entete + suite + steps + pool_line \\\n",

    "\t# v52 — LES NOMS DU CANON, LA OU LES BEATS S'ECRIVENT. Mesure p74 : sur les 16 beats de\n"
    "\t# provenance « arc », le seul nom canonique qui ressort est celui que le prompt fournit\n"
    "\t# lui-meme via faction_block. Ankou, Lavandiere, korrigans, Fanch, Barenton, Val sans\n"
    "\t# Retour : ZERO occurrence. LORE_CANON n'est injecte qu'en selection (:220), intro (:258)\n"
    "\t# et scene_jit (:363) — et scene_jit n'a ecrit aucun beat. Le modele ne nomme que ce que\n"
    "\t# son prompt lui donne ; celui-ci ne lui donnait rien.\n"
    "\t# LA LISTE SEULE, PAS LE CANON ENTIER : LORE_CANON pese ~561 tokens au ratio 3,46\n"
    "\t# car/token mesure sur p74 (b12 : 6025 car. relus = 1741 tok, cache vide). A six tranches\n"
    "\t# par quete longue, l'injecter en entier ajouterait ~60 s a une attente deja hors cible,\n"
    "\t# dans un n_ctx de 2048. Cette ligne-ci en coute 123 (427 caracteres).\n"
    "\tvar noms_canon: String = (\"\\nNOMME au moins UN de ces etres ou lieux, tels quels : \"\n"
    "\t\t+ \"l'Ankou le Passeur de Brumes, la Lavandiere de Nuit, les korrigans, Fanch le \"\n"
    "\t\t+ \"Trotteur, Kado le Cordier, le Chevalier a l'armure ternie, le Choeur des Druides ; \"\n"
    "\t\t+ \"la Fontaine de Barenton, le Val sans Retour, le Pas de Nuit, le Gue des Brumes, \"\n"
    "\t\t+ \"la Pierre Qui Oublie, le Chene Creux, le Tertre des Neuf. La monnaie est le gwenneg. \"\n"
    "\t\t+ \"Aucun autre nom propre n'existe dans ces bois.\")\n"
    "\tvar usr: String = faction_block + entete + noms_canon + suite + steps + pool_line \\\n",
    "les noms dans arc_tranche",
)

p.write_text(t, encoding="utf-8")
print("v52 applique : chaque pitch nomme le canon, et arc_tranche porte enfin la liste des noms.")
