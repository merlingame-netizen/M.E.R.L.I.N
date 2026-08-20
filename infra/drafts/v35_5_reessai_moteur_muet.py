#!/usr/bin/env python3
"""Patch v35.5 — UN re-essai quand le moteur est MUET (vivant mais 0 texte).

p40 beat 2 (journal40) : le Vif a rendu 1 token / 0 caractère en 33,8 s, moteur
vivant (ok:true) — première génération VIDE en 40 parties. prefetch_resolution
posait « idle », le stream ne voyait plus rien en vol → banc servi. Le filet doit
rester celui d'un moteur MORT, pas d'un raté ponctuel : un re-essai immédiat,
UNE seule fois par signature, avant que le banc n'ait le droit de servir.

DRAFT — à déplacer vers infra/patches/ (déclencheur du workflow) APRÈS le verdict
p42 : une seule variable mesurée à la fois."""
import pathlib
import sys


def exact(texte: str, vieux: str, neuf: str, nom: str) -> str:
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_scenario.gd")
t = p.read_text(encoding="utf-8")

# M1 — la variable de garde (une signature déjà re-essayée ne l'est plus jamais)
t = exact(t,
    'var _reso_epoch: int = 0\n',
    'var _reso_epoch: int = 0\n'
    'var _reso_retry_sig: String = ""  # v35.5 — signature déjà re-essayée après une gen VIDE (1 seul re-essai)\n',
    "M1-var")

# M2 — le re-essai dans la branche « génération VIDE » (moteur vivant, texte absent)
t = exact(t,
    '\telse:\n'
    '\t\t_reso_state = "idle"  # échec moteur → take_resolution génèrera (ou retombera sur fallback)\n'
    '\t\tprint("[MerlinScenario] issue — génération VIDE pour %s" % sig)\n',
    '\telse:\n'
    '\t\t_reso_state = "idle"  # échec moteur → take_resolution génèrera (ou retombera sur fallback)\n'
    '\t\tprint("[MerlinScenario] issue — génération VIDE pour %s" % sig)\n'
    "\t\t# v35.5 — moteur MUET (vivant mais 0 texte — p40 : 1 token en 33,8 s) : UN re-essai\n"
    "\t\t# immédiat avant que le banc n'ait le droit de servir. « running » est reposé dans le\n"
    "\t\t# même geste synchrone : le stream du resolve ne voit jamais passer l'« idle ».\n"
    '\t\tif _reso_retry_sig != sig and mn.is_ready():\n'
    '\t\t\t_reso_retry_sig = sig\n'
    '\t\t\tprint("[MerlinScenario] issue — re-essai (moteur muet) pour %s" % sig)\n'
    '\t\t\tprefetch_resolution(situation, played_cards, res)\n',
    "M2-reessai")

p.write_text(t, encoding="utf-8")
print("OK merlin_scenario.gd")
print("v35.5 applique")
