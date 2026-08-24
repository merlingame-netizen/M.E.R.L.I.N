#!/usr/bin/env python3
"""Patch v44 — le banc du pacte : l'annulation n'avait que 4 s pour prendre.

Autopsie job-064 : vides=0 (aucun moteur muet), mais
« cache VIDE pour ...::reussite (etat=running, vol pour ...::partiel) ».
Le pacte accepté change le degré donc la signature ; la relance doit annuler la
génération en vol, et 4 s ne suffisent pas quand elle évalue 976 tokens."""
import pathlib
import sys


def exact(texte, vieux, neuf, nom):
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return texte.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_scenario.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    '\t\tvar free_dl: int = Time.get_ticks_msec() + 4000\n',
    "\t\t# v44 — VINGT SECONDES, PAS QUATRE. Ce drain sert surtout au cas du PACTE : la\n"
    "\t\t# conversion acceptée change la couverture, donc le degré, donc la signature de\n"
    "\t\t# l'issue — il faut annuler le texte en cours et réécrire. Or une annulation ne\n"
    "\t\t# prend qu'entre deux tokens : en pleine évaluation de prompt (976 tokens, 94 s\n"
    "\t\t# mesurés à p63) la voie reste occupée bien au-delà de 4 s, le drain expirait, et\n"
    "\t\t# PLUS RIEN n'était relancé : le banc servait. Trois parties, trois bancs, toujours\n"
    "\t\t# au beat du pacte (p40, p59, p63). Le prefetch est en fond : attendre ne coûte\n"
    "\t\t# rien au joueur, le stream reste sa garantie d'affichage.\n"
    '\t\tvar free_dl: int = Time.get_ticks_msec() + 20000\n',
    "D1-drain")

p.write_text(t, encoding="utf-8")
print("OK merlin_scenario.gd")
print("v44 applique")
"""marqueur: v44"""
