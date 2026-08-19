#!/usr/bin/env python3
"""Patch v34.1 — cap de FRÉQUENCE des pactes + seuils d'achat de la sonde.

Journal de la partie v34 : 16/18 points de corruption = les pactes, UN PAR BEAT (prix
capé à +3 mais rythme libre — 3+3+3 en fin de quête). Esprit de la décision Maxime
(« pente gérable ») : 2 conversions max PAR QUÊTE, comme le Coup de Pouce.
Échec fort si ancre non unique — rien n'est écrit.
"""
import pathlib
import sys


def exact(texte: str, vieux: str, neuf: str, nom: str) -> str:
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


p = pathlib.Path("scripts/game/merlin_run.gd")
t = p.read_text(encoding="utf-8")
t = exact(t,
    "func can_convert() -> bool:\n"
    "\treturn not convert_used_this_beat\n",
    "func can_convert() -> bool:\n"
    "\t# v34.1 — cap de FRÉQUENCE : 2 conversions par QUÊTE (mesuré journal v34 : un pacte par\n"
    "\t# beat = 16/18 points de corruption — le prix était capé, pas le rythme). Le compteur\n"
    "\t# conversions_this_quest se remet à zéro à chaque quête (advance_beat).\n"
    "\treturn not convert_used_this_beat and conversions_this_quest < 2\n",
    "R1-can-convert")
p.write_text(t, encoding="utf-8")
print("OK merlin_run.gd")

p = pathlib.Path("tools/probe_partie_journal.gd")
t = p.read_text(encoding="utf-8")
t = exact(t,
    "\t\tif int(run.integrite) <= 6 and game._merchant_items.has(\"shop_heal\"):\n",
    "\t\tif int(run.integrite) <= 8 and game._merchant_items.has(\"shop_heal\"):\n",
    "S1-seuil-soin")
t = exact(t,
    "\t\telif int(run.corruption) >= 10 and game._merchant_items.has(\"shop_purge\"):\n",
    "\t\telif int(run.corruption) >= 8 and game._merchant_items.has(\"shop_purge\"):\n",
    "S2-seuil-purge")
p.write_text(t, encoding="utf-8")
print("OK probe_partie_journal.gd")
print("v34.1 applique")
