#!/usr/bin/env python3
"""Patch v48 — l'empreinte du jeu dans la generation, pas du generique celtique.

Maxime (2026-08-25) : « ameliore drastiquement l'emprise du Lore sur la generation du modele
LLM pour que ce soit bien l'empreinte du jeu et pas du generique celtique ».

Diagnostic : le LORE_CANON listait des figures et des interdits, mais restait un decor celtique
passe-partout. Il manquait LA signature du monde : Broceliande est une foret-REVE qui BOUCLE sur
elle-meme -- rien n'y finit, les etres REJOUENT sans fin la meme scene (c'est POURQUOI les
druides glitchent et le chevalier rejoue sa defaite). Seul le Voyageur avance. Aucun generique
celtique n'a ca.

v48 reecrit LORE_CANON : la LOI de la boucle en tete, des LIEUX NOMMES propres (Fontaine de
Barenton, Val sans Retour, Pas de Nuit, Pierre Qui Oublie...), les figures avec leur nom propre
(Fanch le Trotteur, la Lavandiere de Nuit, le Passeur de Brumes), le vocabulaire du monde
(gwenneg), et des INTERDITS ANTI-GENERIQUE durcis : aucun dieu nomme, aucune magie a incantation,
aucune prophetie, aucun objet enchante vague -- le merveilleux ici est CONCRET et INQUIETANT.

Va dans le Conteur (scene_jit, arc, intro), en TETE STABLE : le cache de prefixe KV en amortit
le cout apres le premier beat. L'issue (Vif, 2048) garde sa regle breve : v48 ne la touche pas.
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return t.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")

ANCIEN = 'const LORE_CANON: String = "\\nCANON DE BROCELIANDE (le seul monde autorise) : une foret revee qui boucle sur elle-meme ; brume, dolmens, houx, fougeres, sources, pierres levees, huttes de chaume. FIGURES NOMMEES qui peuvent apparaitre : le Choeur des Druides (deux voix qui se repetent et se contredisent), l\'Ankou (le passeur, pose, sans malice ni pitie), la Lavandiere de Nuit (elle lave des linceuls et reclame de l\'aide, jamais sans prix), les korrigans (petit peuple moqueur, cornes rouges), Kado le Cordier (humain perdu, sans faction), le Chevalier a l\'armure ternie (il rejoue sa defaite), l\'Enfant (innocent perdu qu\'on protege), le colporteur (il vend contre des gwenneg), Arthur (rare, paranoiaque). N\'EXISTENT PAS : les dieux, les demons, les anges, la magie a incantations, les chevaliers de la Table Ronde autres qu\'Arthur, les royaumes lointains, toute epoque autre que celtique, tout objet moderne. Jamais d\'anglicisme, jamais le 4e mur."'

NOUVEAU = 'const LORE_CANON: String = "\\nCANON DE BROCELIANDE (le seul monde autorise, et il a une LOI). Broceliande est une foret-REVE qui BOUCLE sur elle-meme : rien n\'y finit ni n\'y avance vraiment, les etres REJOUENT sans fin la meme scene (les druides repetent un rite dont le sens s\'est efface ; le chevalier rejoue sa defaite ; les creatures rebouclent leurs pactes). SEUL le Voyageur avance -- c\'est ce qui le rend etranger a ces bois. DECOR concret : brume, dolmens, houx, fougeres, sources, pierres levees, huttes de chaume, tourbieres, landes de bruyere ; la monnaie est le gwenneg. FIGURES NOMMEES (les seules autorisees) : le Choeur des Druides (deux voix qui se repetent et se contredisent) ; l\'Ankou, le Passeur de Brumes (pose, sans malice ni pitie, il reclame son du) ; la Lavandiere de Nuit (elle lave des linceuls au gue et reclame de l\'aide, jamais sans prix) ; les korrigans (petit peuple moqueur, cornes rouges) ; Fanch le Trotteur le colporteur (il vend et troque contre des gwenneg -- un troc ne s\'annule pas) ; Kado le Cordier (humain perdu, sans faction) ; le Chevalier a l\'armure ternie (il rejoue sa defaite) ; l\'Enfant (innocent qu\'on protege) ; Arthur (rare, apeure, se croit traque). LIEUX qu\'on peut nommer : la Fontaine de Barenton (elle bout sans chaleur), le Val sans Retour, le Pas de Nuit, le Gue des Brumes, la Pierre Qui Oublie, le Chene Creux, le Tertre des Neuf. INTERDIT car GENERIQUE (ce n\'est PAS ce monde) : AUCUN dieu nomme (ni Lugh, ni Cernunnos, ni Dana, ni Brigid), AUCUNE magie a incantation ni sort qui brille, AUCUNE prophetie ni elu, AUCUNE fee ailee, AUCUN objet enchante vague, AUCUN \'ancien pouvoir\' abstrait. Le merveilleux ici est CONCRET et INQUIETANT : une source qui bout froide, un linge lave la nuit, un rire mis en gage, un pas qu\'on ne peut refaire. Aucun demon ni ange, aucun chevalier de la Table Ronde autre qu\'Arthur, aucune epoque autre que celtique, aucun objet moderne, jamais d\'anglicisme, jamais le 4e mur."'

t = exact(t, ANCIEN, NOUVEAU, "LORE_CANON")
p.write_text(t, encoding="utf-8")
print("v48 applique : LORE_CANON porte desormais l'empreinte du monde (la boucle, les lieux, les interdits anti-generique).")
