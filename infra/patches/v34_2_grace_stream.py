#!/usr/bin/env python3
"""Patch v34.2 — grâce de démarrage du stream d'issue.

Démo 10 beats v34 : l'unique banc servi (beat 3, 30 s) — _stream_resolution testait
is_resolution_incoming PENDANT le drain du prefetch qu'il venait de relancer (état
encore « idle » quelques secondes) et concluait à tort à la mort de la génération.
Grâce de 8 s avant d'autoriser cette sortie. Échec fort si ancre non unique.
"""
import pathlib
import sys


def exact(texte: str, vieux: str, neuf: str, nom: str) -> str:
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


p = pathlib.Path("scripts/game/merlin_game.gd")
t = p.read_text(encoding="utf-8")
t = exact(t,
    "\tvar dl: int = Time.get_ticks_msec() + 180000\n"
    "\tvar finale: String = \"\"\n"
    "\twhile Time.get_ticks_msec() < dl:\n"
    "\t\tif sc.is_resolution_ready(played_cards, res):\n"
    "\t\t\tfinale = str(sc.take_resolution(situ, played_cards, res))\n"
    "\t\t\tbreak\n"
    "\t\tif not sc.is_resolution_incoming(played_cards, res):\n"
    "\t\t\tbreak  # la génération est morte (erreur moteur) et rien en cache → filet ultime\n",
    "\tvar dl: int = Time.get_ticks_msec() + 180000\n"
    "\tvar finale: String = \"\"\n"
    "\t# v34.2 — GRÂCE de démarrage : le prefetch relancé ci-dessus draine sa voie quelques\n"
    "\t# secondes avant de poser « running » — conclure à la mort pendant cette fenêtre servait\n"
    "\t# le banc à tort (démo v34 : l'unique secours de la partie, beat 3).\n"
    "\tvar grace: int = Time.get_ticks_msec() + 8000\n"
    "\twhile Time.get_ticks_msec() < dl:\n"
    "\t\tif sc.is_resolution_ready(played_cards, res):\n"
    "\t\t\tfinale = str(sc.take_resolution(situ, played_cards, res))\n"
    "\t\t\tbreak\n"
    "\t\tif not sc.is_resolution_incoming(played_cards, res) and Time.get_ticks_msec() > grace:\n"
    "\t\t\tbreak  # la génération est morte (erreur moteur) et rien en cache → filet ultime\n",
    "G1-grace")
p.write_text(t, encoding="utf-8")
print("OK merlin_game.gd")
print("v34.2 applique")
