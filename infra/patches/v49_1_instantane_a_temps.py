#!/usr/bin/env python3
"""Patch v49.1 — L'INSTANTANE DES MECANIQUES, PRIS A TEMPS CETTE FOIS.

Le journal de la derniere partie porte encore dc=None, total=None, marge=None, geste_sur=None et
phrase_geste vide sur les SIX beats. Mon correctif v48.1a n'a donc pas marche, et la raison est
une question de PLACE dans la boucle, pas de logique.

LA CHAINE. `_pending_res` est rempli par _show_resolution et vide par _on_typewriter_done
(merlin_game.gd:2336). Or la sonde SAUTE la machine a ecrire : la branche du typewriter, dans sa
boucle, appelle game._skip_typewriter() puis `continue`. Et j'avais place l'instantane APRES
cette branche. Il n'etait donc jamais atteint tant que _pending_res avait quelque chose dedans :
au tour suivant, la variable etait deja videe.

Consequence : une partie temoin ANNONCE ses reussites sans pouvoir les PROUVER. Elle dit
« reussite » mais ne peut montrer ni le DC, ni le total, ni la marge — c'est exactement le
confort qu'il ne faut pas s'accorder quand on fonde des decisions sur ces parties.

LE CORRECTIF : l'instantane remonte TOUT EN HAUT du corps de la boucle, avant la moindre branche
susceptible de faire `continue`. C'est le seul endroit ou l'on est certain de le voir.
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return t.replace(vieux, neuf)


p = pathlib.Path("tools/probe_partie_journal.gd")
t = p.read_text(encoding="utf-8")

# --- 1. retirer l'instantane de sa place inutile -------------------------------------------
ANCIEN = """		# v48.1 — L'INSTANTANE DES MECANIQUES, pris ICI et pas a la sortie. _pending_res
		# est efface dans _on_typewriter_done (merlin_game.gd:2336), qui court AVANT que
		# `_can_advance` ne passe a vrai : _noter_sortie lisait donc un dictionnaire vide, et
		# dc=0 / total=0 / geste_sur=false / phrase_geste="" dormaient dans TOUS les journaux
		# depuis v34 — des valeurs impossibles (un DC vaut 6, 9 ou 12) que rien ne signalait.
		if _meca.is_empty() and ("_pending_res" in game) and game._pending_res is Dictionary \\
				and not (game._pending_res as Dictionary).is_empty():
			_meca = (game._pending_res as Dictionary).duplicate()

		if game._state == 1:"""
t = exact(t, ANCIEN, "		if game._state == 1:", "retirer l'instantane mal place")

# --- 2. le remettre tout en haut, avant la moindre sortie de boucle ------------------------
t = exact(
    t,
    """	while Time.get_ticks_msec() < dl:
		if not is_instance_valid(game):
			break""",
    """	while Time.get_ticks_msec() < dl:
		# v49.1 — L'INSTANTANE DES MECANIQUES, TOUT EN HAUT. `_pending_res` est rempli par
		# _show_resolution et vide par _on_typewriter_done (merlin_game.gd:2336). Or cette
		# sonde SAUTE la machine a ecrire : la branche du typewriter, plus bas, appelle
		# _skip_typewriter() puis `continue` — donc un instantane place APRES elle n'etait
		# jamais atteint tant que la variable avait quelque chose dedans. C'etait le defaut de
		# v48.1a, et c'est pourquoi dc, total, marge, geste_sur et phrase_geste sont encore
		# vides dans le journal de la derniere partie : la partie ANNONCE ses reussites sans
		# pouvoir les PROUVER. Ici, avant toute branche qui sort, on est certain de le voir.
		if _meca.is_empty() and is_instance_valid(game) and ("_pending_res" in game) \\
				and game._pending_res is Dictionary \\
				and not (game._pending_res as Dictionary).is_empty():
			_meca = (game._pending_res as Dictionary).duplicate()
		if not is_instance_valid(game):
			break""",
    "remonter l'instantane en tete de boucle",
)

p.write_text(t, encoding="utf-8")
print("v49.1 applique : l'instantane des mecaniques est pris avant toute branche qui sort de la")
print("boucle. dc, total, marge, geste_sur et phrase_geste doivent enfin remplir le journal.")
