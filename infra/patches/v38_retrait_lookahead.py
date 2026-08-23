#!/usr/bin/env python3
"""Patch v38 - retrait PROPRE du chainage lookahead, retour au rythme v36."""
import pathlib
import sys


def exact(texte, vieux, neuf, nom):
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


p = pathlib.Path("scripts/game/merlin_game.gd")
t = p.read_text(encoding="utf-8")
t = exact(t,
    "\tsc.note_issue_affichee(prose)\n"
    "\t# v37.1 — le chaînage revient ICI : l'issue est AFFICHÉE, le joueur lit (35 s), le Vif\n"
    "\t# est libre — la scène s'écrit SEULE à plein régime (~20-25 s à 65 tokens), dans la\n"
    "\t# fenêtre de lecture. Le gist posé au resolve reste sa nourriture (v35.4 S1).\n"
    "\tsc.prefetch_scene_suivante(run)\n",
    "\tsc.note_issue_affichee(prose)\n"
    "\t# v38 — le chaînage lookahead est RETIRÉ : 11 parties témoin, 1 scène servie (p50),\n"
    "\t# 0,8-2,5 tok/s dès que les deux moteurs écrivent — pas de fenêtre fiable sur cette\n"
    "\t# machine sans faire attendre le joueur. L'arc pré-écrit + le pont d'action portent\n"
    "\t# l'enchaînement. Chantier consigné, à reprendre avec un moteur plus rapide.\n",
    "G1-affichage")
p.write_text(t, encoding="utf-8")
print("OK merlin_game.gd")

p = pathlib.Path("scripts/llm/merlin_scenario.gd")
t = p.read_text(encoding="utf-8")
t = exact(t,
    "\t# v37 — PRIORITÉ SCÈNE (bornée) : une scène lookahead en cours d'écriture garde la\n"
    "\t# machine pour elle — seule, elle tourne à plein régime (~25-30 s au lieu de 45-90 s\n"
    "\t# à ~2 tok/s en duo, p51 : 4 scènes jetées sur 4). L'issue est courte désormais : ce\n"
    "\t# départ différé coûte 0-20 s au beat et rend l'enchaînement au joueur.\n"
    "\tif _scene_jit_qn != -1:\n"
    "\t\tvar dl_scene: int = Time.get_ticks_msec() + 25000  # v37.1 — couvre la scène entière (~20-25 s)\n"
    "\t\twhile _scene_jit_qn != -1 and Time.get_ticks_msec() < dl_scene:\n"
    "\t\t\tawait get_tree().process_frame\n"
    "\t\tif epoch != _reso_epoch:\n"
    "\t\t\treturn  # beat/combo changé pendant l'attente — un prefetch plus récent a la main\n",
    "\t# v38 — la garde de pose v37/v37.1 est retirée avec le chaînage lookahead : elle\n"
    "\t# retardait les issues (46-60 s, 1 SECOURS à p55) sans jamais sauver une scène.\n",
    "S1-garde")
t = exact(t,
    "\t\t# LE LOOKAHEAD S'ENCHAÎNE ICI, dès que l'issue est écrite — pas à son affichage. Lancé à\n"
    "\t\t# l'affichage, il n'avait que le temps de lecture : la première scène complète (42,9 s)\n"
    "\t\t# est arrivée APRÈS la présentation du beat suivant et a été jetée. Ici, il gagne tout le\n"
    "\t\t# temps restant de pose + le sustain + la lecture : la fenêtre maximale possible.\n"
    '\t\t_run_thread["last_issue"] = prose.strip_edges().substr(0, 420)\n'
    '\t\tvar run_n: Node = get_node_or_null("/root/MerlinRun")\n'
    "\t\tif run_n != null and not run_n.ended:\n"
    "\t\t\tprefetch_scene_suivante(run_n)\n",
    "\t\t# v38 — chaînage lookahead retiré (voir merlin_game) ; last_issue reste nourri\n"
    "\t\t# pour les ponts d'action et le fil du récit.\n"
    '\t\t_run_thread["last_issue"] = prose.strip_edges().substr(0, 420)\n',
    "S2-chainage")
p.write_text(t, encoding="utf-8")
print("OK merlin_scenario.gd")
print("v38 applique")
"""marqueur: v38"""
