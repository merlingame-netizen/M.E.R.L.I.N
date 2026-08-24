#!/usr/bin/env python3
"""Patch v41 — l'arc se tait pendant le premier beat.

p58 : issue du beat 1 à 1,83 tok/s (70 tok en 38,2 s), beat1=68 s contre 40 s de moyenne.
v39 empêche de LANCER une tranche pendant une issue ; une tranche déjà en vol continue."""
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
    "\t\tvar precedent: String = _resume_arc(arc_complet)\n"
    "\t\t# PATIENCE, ET NON ABANDON.",
    "\t\tvar precedent: String = _resume_arc(arc_complet)\n"
    "\t\t# v41 — L'ARC SE TAIT PENDANT LE PREMIER BEAT. v39 empêche de LANCER une tranche\n"
    "\t\t# pendant une issue, mais une tranche DÉJÀ EN VOL continue : au beat 1 elle démarre\n"
    "\t\t# pendant la pose et l'issue tombe dedans (p58 : 70 tok en 38,2 s = 1,83 tok/s contre\n"
    "\t\t# 8+ seule, beat 1 à 68 s contre 40 s de moyenne). L'ouverture garde sa priorité\n"
    "\t\t# (debut == 0) ; ensuite l'arc attend la résolution du premier beat — aucune\n"
    "\t\t# annulation (leçon v31.1), et il lui reste cinq beats pour rattraper.\n"
    "\t\tif debut > 0:\n"
    '\t\t\tvar run_a: Node = get_node_or_null("/root/MerlinRun")\n'
    "\t\t\tvar dl_b1: int = Time.get_ticks_msec() + 180000\n"
    "\t\t\twhile run_a != null and is_instance_valid(run_a) and not run_a.ended \\\n"
    "\t\t\t\t\tand int(run_a.beat_index) <= 0 and Time.get_ticks_msec() < dl_b1:\n"
    "\t\t\t\tawait get_tree().create_timer(1.0).timeout\n"
    '\t\t\tif str(_run_thread.get("title", "")) != title:\n'
    "\t\t\t\treturn  # nouvelle partie pendant l'attente du premier beat\n"
    "\t\t# PATIENCE, ET NON ABANDON.",
    "A1-arc-beat1")

p.write_text(t, encoding="utf-8")
print("OK merlin_scenario.gd")
print("v41 applique")
"""marqueur: v41"""
