#!/usr/bin/env python3
"""Patch v35.2 — la sonde lit comme un humain (35 s par défaut, overridable).

p34 : la scène lookahead n'a pour elle que la fenêtre de LECTURE (vif libre) — 18 s
chez la sonde, irréaliste. Leçon v30 : un harnais qui joue plus vite qu'un humain
mesure un jeu que personne ne vit."""
import pathlib
import sys


def exact(texte: str, vieux: str, neuf: str, nom: str) -> str:
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


p = pathlib.Path("tools/probe_partie_journal.gd")
t = p.read_text(encoding="utf-8")
if "LECTURE_S: float = 18.0" in t:
    t = exact(t,
        "LECTURE_S: float = 18.0",
        "LECTURE_S: float = 35.0  # v35.2 : rythme de lecture HUMAIN (leçon v30) — la fenêtre du lookahead",
        "L1")
elif "LECTURE_S = 18.0" in t:
    t = exact(t, "LECTURE_S = 18.0", "LECTURE_S = 35.0", "L1b")
else:
    sys.exit("ECHEC : constante LECTURE_S introuvable")
p.write_text(t, encoding="utf-8")
print("OK probe_partie_journal.gd")
print("v35.2 applique")
