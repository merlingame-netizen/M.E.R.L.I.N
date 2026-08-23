#!/usr/bin/env python3
"""Patch v37.1 — la scène lookahead part À L'AFFICHAGE de l'issue (Vif libre).

p54 : v37 (attente à la pose, chaînage au resolve) a raté — 0 lookahead servie,
issues ralenties (60 s de moyenne). Au resolve, l'issue s'écrit encore : la scène
rampe à ~2 tok/s en duo. À l'affichage, le joueur lit 35 s et le Vif est LIBRE :
scène seule à plein régime ≈ 20-25 s (65 tokens) — dans la fenêtre, enfin."""
import pathlib
import sys


def exact(texte: str, vieux: str, neuf: str, nom: str) -> str:
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


# ── merlin_game.gd : le prefetch quitte le resolve, revient à l'affichage ──
p = pathlib.Path("scripts/game/merlin_game.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    "\t# v35.4 — LA SCÈNE SUIVANTE PART ICI : le degré et le geste sont connus, note_outcome\n"
    "\t# pose le gist à l'instant, et la scène N+1 dispose de TOUTE la fenêtre (écriture de\n"
    "\t# l'issue + lecture + pose suivante ≈ 90-120 s) au lieu des ~35 s de lecture seule —\n"
    "\t# course41 : à 2 tok/s en duo, 95 s de scène ne passaient jamais dans 35 s.\n"
    "\tsc.note_outcome(res, situ, played_cards)\n"
    "\tsc.prefetch_scene_suivante(run)\n",
    "\t# v37.1 — note_outcome reste AU RESOLVE (le gist frais nourrit la scène), mais le\n"
    "\t# CHAÎNAGE repart à l'affichage : au resolve l'issue s'écrit encore et la scène\n"
    "\t# rampait à ~2 tok/s en duo (p51 : 4 jetées sur 4 ; p54 : pareil malgré v37).\n"
    "\tsc.note_outcome(res, situ, played_cards)\n",
    "G1-resolve")

t = exact(t,
    "\tsc.note_issue_affichee(prose)\n"
    "\t# v35.4 — le prefetch de scène est parti au resolve ; ici on ne fait plus que noter l'issue.\n",
    "\tsc.note_issue_affichee(prose)\n"
    "\t# v37.1 — le chaînage revient ICI : l'issue est AFFICHÉE, le joueur lit (35 s), le Vif\n"
    "\t# est libre — la scène s'écrit SEULE à plein régime (~20-25 s à 65 tokens), dans la\n"
    "\t# fenêtre de lecture. Le gist posé au resolve reste sa nourriture (v35.4 S1).\n"
    "\tsc.prefetch_scene_suivante(run)\n",
    "G2-affichage")

p.write_text(t, encoding="utf-8")
print("OK merlin_game.gd")

# ── merlin_scenario.gd : la garde de pose couvre la fin d'écriture (25 s) ──
p = pathlib.Path("scripts/llm/merlin_scenario.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    "\t\tvar dl_scene: int = Time.get_ticks_msec() + 20000\n",
    "\t\tvar dl_scene: int = Time.get_ticks_msec() + 25000  # v37.1 — couvre la scène entière (~20-25 s)\n",
    "S1-borne")

p.write_text(t, encoding="utf-8")
print("OK merlin_scenario.gd")
print("v37.1 applique")
"""marqueur: v37.1"""
