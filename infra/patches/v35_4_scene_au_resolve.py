#!/usr/bin/env python3
"""Patch v35.4 — la scène suivante part AU RESOLVE, nourrie du gist.

course41 : scènes lookahead 91-118 s (écriture à 1,9-2,2 tok/s dès que l'issue suivante
rétrograde le Conteur à 1 fil) contre ~35 s de fenêtre vif-libre. La substance de
l'issue (geste + degré + gist) est connue DÈS le resolve : le chaînage y descend, la
fenêtre passe à 90-120 s (écriture d'issue + lecture + pose suivante)."""
import pathlib
import sys


def exact(texte: str, vieux: str, neuf: str, nom: str) -> str:
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


# ── merlin_game.gd : note_outcome + prefetch AU RESOLVE (avant le stream/affichage) ──
p = pathlib.Path("scripts/game/merlin_game.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    '\tvar prose: String = str(sc.take_resolution(situ, played_cards, res))\n'
    '\tif prose.length() < 10:\n'
    "\t\t# v33 « Les Deux Mains » — le banc ne sert plus JAMAIS sur un délai : l'issue s'ÉCRIT\n",
    "\t# v35.4 — LA SCÈNE SUIVANTE PART ICI : le degré et le geste sont connus, note_outcome\n"
    "\t# pose le gist à l'instant, et la scène N+1 dispose de TOUTE la fenêtre (écriture de\n"
    "\t# l'issue + lecture + pose suivante ≈ 90-120 s) au lieu des ~35 s de lecture seule —\n"
    "\t# course41 : à 2 tok/s en duo, 95 s de scène ne passaient jamais dans 35 s.\n"
    "\tsc.note_outcome(res, situ, played_cards)\n"
    "\tsc.prefetch_scene_suivante(run)\n"
    '\tvar prose: String = str(sc.take_resolution(situ, played_cards, res))\n'
    '\tif prose.length() < 10:\n'
    "\t\t# v33 « Les Deux Mains » — le banc ne sert plus JAMAIS sur un délai : l'issue s'ÉCRIT\n",
    "G1-resolve")

t = exact(t,
    "\tsc.note_outcome(res, situ, played_cards)  # gist SPECIFIQUE (action reelle) + pont vers la situation suivante\n",
    "\t# v35.4 — note_outcome et le chaînage de scène sont désormais AU RESOLVE (plus haut).\n",
    "G2-ancien-note")

t = exact(t,
    "\tsc.note_issue_affichee(prose)\n"
    "\tsc.prefetch_scene_suivante(run)\n",
    "\tsc.note_issue_affichee(prose)\n"
    "\t# v35.4 — le prefetch de scène est parti au resolve ; ici on ne fait plus que noter l'issue.\n",
    "G3-ancien-prefetch")

p.write_text(t, encoding="utf-8")
print("OK merlin_game.gd")

# ── merlin_scenario.gd : le prompt de scène se nourrit du gist FRAIS ──
p = pathlib.Path("scripts/llm/merlin_scenario.gd")
t = p.read_text(encoding="utf-8")
t = exact(t,
    '\tvar issue_prec: String = str(_run_thread.get("last_issue", ""))\n',
    "\t# v35.4 — au resolve, l'issue n'est pas encore écrite : sa SUBSTANCE (le gist — geste\n"
    "\t# réel + résultat) vient d'être posée par note_outcome et suffit à enchaîner la scène.\n"
    '\tvar issue_prec: String = str(_run_thread.get("last_gist", ""))\n'
    '\tif issue_prec.strip_edges() == "":\n'
    '\t\tissue_prec = str(_run_thread.get("last_issue", ""))\n',
    "S1-gist")
p.write_text(t, encoding="utf-8")
print("OK merlin_scenario.gd")
print("v35.4 applique")
