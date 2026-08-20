#!/usr/bin/env python3
"""Patch v35.3 — garde sur les sentiers vides dans la sonde.

Crash p36 : probe_partie_journal.gd:175, `sentiers[_pick]` sur tableau VIDE — la phase
sélection écrit son JSON même en échec (ok:false, sentiers:[]). Sortie propre."""
import pathlib
import sys


def exact(texte: str, vieux: str, neuf: str, nom: str) -> str:
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


p = pathlib.Path("tools/probe_partie_journal.gd")
t = p.read_text(encoding="utf-8")
t = exact(t,
    '\tvar sentiers: Array = (sel as Dictionary)["sentiers"]\n'
    '\t_pick = clampi(int(OS.get_environment("MERLIN_PICK")), 0, maxi(sentiers.size() - 1, 0))\n'
    "\tvar choisi: Dictionary = sentiers[_pick]\n",
    '\tvar sentiers: Array = (sel as Dictionary)["sentiers"]\n'
    "\t# v35.3 — la phase A écrit son JSON MÊME en échec (ok:false, sentiers:[]) : sans cette\n"
    "\t# garde, sentiers[_pick] crashait (p36, Out of bounds probe:175) et le harnais se figeait.\n"
    "\tif sentiers.is_empty() or not bool((sel as Dictionary).get(\"ok\", false)):\n"
    '\t\tprint("[JOURNAL] sélection en échec (ok=false ou sentiers vides) — rejouer la phase A")\n'
    "\t\tquit(2)\n"
    "\t\treturn\n"
    '\t_pick = clampi(int(OS.get_environment("MERLIN_PICK")), 0, maxi(sentiers.size() - 1, 0))\n'
    "\tvar choisi: Dictionary = sentiers[_pick]\n",
    "G1-garde")
p.write_text(t, encoding="utf-8")
print("OK probe_partie_journal.gd")
print("v35.3 applique")
