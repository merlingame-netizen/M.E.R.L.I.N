#!/usr/bin/env python3
"""Patch v49.2 — UN BON FIL, OU PAS DE FIL.

v49 a fait passer la continuite de 0 a 5 sur 5 : chaque scene s'ouvre desormais sur ce que
l'issue precedente a laisse. Mais la partie temoin p73 montre que le compteur ne dit pas tout,
et trois defauts sautent aux yeux dans le texte :

  - DES SCORIES DE MISE EN FORME. Deux fils sur cinq commencent par une asterisque : « * Le
    Chevalier tend sa main gantee vers vous. » Le modele en seme dans sa prose, et le fil les
    transporte telles quelles en TETE de la scene suivante.
  - LA PHRASE DU GESTE PRISE POUR UN CROCHET. Le beat 2 s'ouvrait sur « Vous plantez vos appuis
    dans la terre molle et vous frappez avec le poing ferme sur l'objet oublie. » — c'est la
    PREMIERE phrase de l'issue, celle du geste, en italique. Elle raconte ce que le Voyageur
    vient de faire, pas ce qui l'attend : transplantee en ouverture, elle rejoue le passe.
  - LE FIL PARLE DU VOYAGEUR AU LIEU DU MONDE. « Vous sentez l'humidite sur vos vetements. »
    ouvrait le Climax. Un fil doit nommer ce qui REAGIT — un etre, une bete, un objet — pas
    l'etat du heros.

TROIS REGLES DE PLUS, et le principe qui les gouverne : mieux vaut PAS DE FIL qu'un mauvais fil.
Un refus rend simplement le pont mecanique d'avant, qui n'a jamais rien casse.

MESURE sur les cinq enchainements reels de p73 : la regle actuelle rend 5 fils dont 3 fautifs ;
la regle stricte en rend 4, tous propres, et le cinquieme retombe sur le pont mecanique. Le
beat 6 s'ouvrirait sur « Le sentier etroit sous la voute s'impose comme seul passage » au lieu de
« Vous sentez l'humidite sur vos vetements ».
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return t.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_scenario.gd")
t = p.read_text(encoding="utf-8")

t = exact(
    t,
    '''func _extraire_fil(prose: String) -> String:
	var txt: String = prose.replace("[i]", "").replace("[/i]", "").strip_edges()
	var phrases: Array = MerlinProse.split_sentences(txt)
	for i in range(phrases.size() - 1, -1, -1):
		var s: String = str(phrases[i]).strip_edges()''',
    '''func _extraire_fil(prose: String) -> String:
	var txt: String = prose.replace("[i]", "").replace("[/i]", "").strip_edges()
	# v49.2 — LES SCORIES DE MISE EN FORME. Le modele seme des asterisques et des soulignes
	# dans sa prose ; le fil les transportait tels quels en TETE de la scene suivante (p73,
	# deux enchainements sur cinq : « * Le Chevalier tend sa main gantee vers vous. »).
	for _sc in ["*", "_", "`", "#"]:
		txt = txt.replace(str(_sc), "")
	txt = txt.strip_edges()
	var phrases: Array = MerlinProse.split_sentences(txt)
	# v49.2 — JAMAIS LA PHRASE DU GESTE. La premiere phrase de l'issue est, par contrat, celle
	# du geste (en italique) : elle dit ce que le Voyageur vient de FAIRE, pas ce qui l'attend.
	# Transplantee en ouverture du beat suivant, elle rejoue le passe au lieu de l'ouvrir —
	# p73 beat 2 : « Vous plantez vos appuis dans la terre molle et vous frappez... »
	var _premiere: int = 1 if phrases.size() > 1 else 0
	for i in range(phrases.size() - 1, _premiere - 1, -1):
		var s: String = str(phrases[i]).strip_edges()''',
    "les scories et la phrase du geste",
)

t = exact(
    t,
    '''		if bas.begins_with("tu ") or bas.contains(" tu ") or bas.contains(" t'"):
			continue  # voix cassee une fois transplantee''',
    '''		if bas.begins_with("tu ") or bas.contains(" tu ") or bas.contains(" t'"):
			continue  # voix cassee une fois transplantee
		# v49.2 — LE FIL DIT LE MONDE, PAS LE VOYAGEUR. « Vous sentez l'humidite sur vos
		# vetements. » ouvrait le Climax de p73 : c'est l'etat du heros, pas ce qui l'attend.
		# Un fil doit NOMMER ce qui reagit — un etre, une bete, un objet.
		if bas.begins_with("vous "):
			continue''',
    "le fil dit le monde",
)

p.write_text(t, encoding="utf-8")
print("v49.2 applique : plus de scories, jamais la phrase du geste, et le fil nomme le MONDE.")
print("Un refus rend le pont mecanique : mieux vaut pas de fil qu'un mauvais fil.")
