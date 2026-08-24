#!/usr/bin/env python3
"""Patch v39 — l'arc s'efface devant toute ISSUE en vol.

p56 : issue du beat 1 à 2,7 tok/s pendant les tranches d'arc (péage 73-148 s),
8-9 tok/s seule dès le beat 2. La règle de repatience de l'arc s'étend aux issues."""
import pathlib
import sys


def exact(texte, vieux, neuf, nom):
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_scenario.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    "\t\t\tif _scene_jit_qn != -1 \\\n"
    "\t\t\t\t\tor mn_a == null or not mn_a.is_ready() \\\n"
    '\t\t\t\t\tor (mn_a.est_occupe("conteur") if mn_a.has_method("est_occupe") else mn_a.is_busy()):\n'
    "\t\t\t\tawait get_tree().create_timer(1.0).timeout\n"
    "\t\t\t\tcontinue  # scène lookahead en attente ou voie occupée : on repatiente\n",
    "\t\t\t# v39 — L'ARC S'EFFACE devant toute ISSUE en vol : le joueur attend l'issue, pas\n"
    "\t\t\t# l'arc. En duo les deux voies rampent (p56 : issue du beat 1 à 2,7 tok/s pendant\n"
    "\t\t\t# les tranches, 8-9 tok/s seule dès le beat 2) : l'arc repatiente aussi tant que\n"
    "\t\t\t# le Vif écrit — il rattrape pendant les lectures, son budget d'horloge le couvre.\n"
    "\t\t\tif _scene_jit_qn != -1 \\\n"
    "\t\t\t\t\tor mn_a == null or not mn_a.is_ready() \\\n"
    '\t\t\t\t\tor (mn_a.est_occupe("conteur") if mn_a.has_method("est_occupe") else mn_a.is_busy()) \\\n'
    '\t\t\t\t\tor _reso_state == "running" \\\n'
    '\t\t\t\t\tor (mn_a.has_method("est_occupe") and mn_a.est_occupe("vif")):\n'
    "\t\t\t\tawait get_tree().create_timer(1.0).timeout\n"
    "\t\t\t\tcontinue  # scène lookahead, issue en vol ou voie occupée : on repatiente\n",
    "A1-arc-cede")

p.write_text(t, encoding="utf-8")
print("OK merlin_scenario.gd")
print("v39 applique")
"""marqueur: v39"""
