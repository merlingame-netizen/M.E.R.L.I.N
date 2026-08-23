#!/usr/bin/env python3
"""Patch v37 — priorité scène bornée (20 s) + scène 65 tokens.

p51 : 4 scènes générées, 4 jetées « trop tard » (45,3-89,6 s) pour des fenêtres de
~40-55 s ; écriture à 1,7-2,5 tok/s en duo permanent (la pose relance l'issue pendant
la lecture — le Vif n'est presque jamais libre, le plein régime ne s'enclenche pas).
Remède : l'issue laisse d'abord finir la scène (borne 20 s), et la scène raccourcit."""
import pathlib
import sys


def exact(texte: str, vieux: str, neuf: str, nom: str) -> str:
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


# ── merlin_scenario.gd : l'issue attend la scène (borne 20 s) ──
p = pathlib.Path("scripts/llm/merlin_scenario.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    "\t_reso_epoch += 1\n"
    "\tvar epoch: int = _reso_epoch\n",
    "\t_reso_epoch += 1\n"
    "\tvar epoch: int = _reso_epoch\n"
    "\t# v37 — PRIORITÉ SCÈNE (bornée) : une scène lookahead en cours d'écriture garde la\n"
    "\t# machine pour elle — seule, elle tourne à plein régime (~25-30 s au lieu de 45-90 s\n"
    "\t# à ~2 tok/s en duo, p51 : 4 scènes jetées sur 4). L'issue est courte désormais : ce\n"
    "\t# départ différé coûte 0-20 s au beat et rend l'enchaînement au joueur.\n"
    "\tif _scene_jit_qn != -1:\n"
    "\t\tvar dl_scene: int = Time.get_ticks_msec() + 20000\n"
    "\t\twhile _scene_jit_qn != -1 and Time.get_ticks_msec() < dl_scene:\n"
    "\t\t\tawait get_tree().process_frame\n"
    "\t\tif epoch != _reso_epoch:\n"
    "\t\t\treturn  # beat/combo changé pendant l'attente — un prefetch plus récent a la main\n",
    "S1-priorite")

p.write_text(t, encoding="utf-8")
print("OK merlin_scenario.gd")

# ── merlin_prompt_builder.gd : scène 1-2 phrases, 65 tokens ──
p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    'La scene = 2 a 3 phrases COURTES et CONCRETES',
    'La scene = 1 a 2 phrases COURTES et CONCRETES',
    "P1-phrases")

t = exact(t,
    '\t\t\t"opts": {"creative": true, "max_tokens": 90, "fin_phrase": true, "plein_regime": true,\n'
    '\t\t\t"label": "scène %d (lookahead)" % [pos + 1]}}\n',
    '\t\t\t"opts": {"creative": true, "max_tokens": 65, "fin_phrase": true, "plein_regime": true,\n'
    '\t\t\t"label": "scène %d (lookahead)" % [pos + 1]}}\n',
    "P2-budget")

p.write_text(t, encoding="utf-8")
print("OK merlin_prompt_builder.gd")
print("v37 applique")
"""marqueur: v37"""
