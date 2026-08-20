#!/usr/bin/env python3
"""Patch v35.1 — la scène lookahead à plein régime.

Mesure lk31 (partie v35) : scènes lookahead écrites en 92-97 s (éval 604-684 tok à
11 tok/s, écriture à 3 tok/s — le Conteur étranglé) contre une fenêtre de ~58 s :
toujours perdantes. La scène tourne pendant la LECTURE, quand le Vif est libre — la
voie est seule et plein_regime lui donne les 4 fils → ~30 s, dans la fenêtre.
"""
import pathlib
import sys


def exact(texte: str, vieux: str, neuf: str, nom: str) -> str:
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")
t = exact(t,
    '\treturn {"system": SYSTEM_PREFIX, "user": usr,\n'
    '\t\t\t"opts": {"creative": true, "max_tokens": 150, "fin_phrase": true,\n'
    '\t\t\t"label": "scène %d (lookahead)" % [pos + 1]}}\n',
    '\t# v35.1 — plein_regime : la scène s\'écrit pendant la LECTURE (le Vif est libre, la voie\n'
    '\t# est seule) — à 4 fils elle tient dans la fenêtre (~30 s contre 92-97 s mesurés à 1 fil).\n'
    '\treturn {"system": SYSTEM_PREFIX, "user": usr,\n'
    '\t\t\t"opts": {"creative": true, "max_tokens": 150, "fin_phrase": true, "plein_regime": true,\n'
    '\t\t\t"label": "scène %d (lookahead)" % [pos + 1]}}\n',
    "P1-plein-regime")
p.write_text(t, encoding="utf-8")
print("OK merlin_prompt_builder.gd")
print("v35.1 applique")
