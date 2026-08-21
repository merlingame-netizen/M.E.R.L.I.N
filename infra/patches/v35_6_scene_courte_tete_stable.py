#!/usr/bin/env python3
"""Patch v35.6 — scène lookahead COURTE + tête de prompt STABLE + gardes qui parlent.

course49 : 3 scènes générées et finies (94,7-107,8 s) mais pretes=0 — toutes jetées
par le « trop tard » silencieux (fenêtre réelle 53-70 s). Scène 2-3 phrases (90 tok)
+ tête stable (cache de préfixe KV) → total visé ~45-60 s, DANS la fenêtre."""
import pathlib
import sys


def exact(texte: str, vieux: str, neuf: str, nom: str) -> str:
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


# ── merlin_prompt_builder.gd : scène courte, tête stable ──
p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    '\tvar usr: String = faction_block + ("Conte la SCENE %d sur %d de la quete « %s » (%s) a %s. 2e PERSONNE (« Vous »), au PRESENT." % [\n'
    '\t\tpos + 1, total, title, pitch, lieu]) + fil \\\n'
    '\t\t+ "\\nROLE de cette scene : %s ; ecris une scene ou il faut %s (c\'est CE que le Voyageur devra faire)." % [role, cue_txt] \\\n'
    '\t\t+ pool_line \\\n'
    '\t\t+ "\\nLa scene = 3 a 5 phrases COURTES et CONCRETES (qui, quoi, ou ; une image au plus, pas de lyrisme ni de comparaisons) avec un MONDE VIVANT (un personnage qui AGIT et PARLE, une presence qui reagit), SANS abstraction, qui FINIT sur un instant SUSPENDU : VARIE la chute, n\'utilise JAMAIS « que faire », « que decidez-vous », « vous vous demandez ». Rien d\'autre que la scene."\n',
    "\t# v35.6 — TÊTE STABLE d'abord (identité de quête, règles, pool : identiques d'un beat à\n"
    "\t# l'autre → le cache de préfixe KV saute leur évaluation), le VARIABLE en queue (numéro,\n"
    "\t# rôle, fil du récit). Et 2-3 phrases : course49 — 3 scènes finies en 95-108 s pour une\n"
    "\t# fenêtre de 53-70 s, toutes jetées « trop tard ». Une scène courte est une scène SERVIE.\n"
    '\tvar usr: String = faction_block + ("Conte une SCENE de la quete « %s » (%s) a %s. 2e PERSONNE (« Vous »), au PRESENT." % [\n'
    '\t\ttitle, pitch, lieu]) \\\n'
    '\t\t+ "\\nLa scene = 2 a 3 phrases COURTES et CONCRETES (qui, quoi, ou ; une image au plus, pas de lyrisme ni de comparaisons) avec un MONDE VIVANT (un personnage qui AGIT ou une presence qui reagit), SANS abstraction, qui FINIT sur un instant SUSPENDU : VARIE la chute, n\'utilise JAMAIS « que faire », « que decidez-vous », « vous vous demandez ». Rien d\'autre que la scene." \\\n'
    '\t\t+ pool_line \\\n'
    '\t\t+ ("\\nSCENE %d sur %d." % [pos + 1, total]) \\\n'
    '\t\t+ "\\nROLE de cette scene : %s ; ecris une scene ou il faut %s (c\'est CE que le Voyageur devra faire)." % [role, cue_txt] \\\n'
    '\t\t+ fil\n',
    "P1-usr")

t = exact(t,
    '\t\t\t"opts": {"creative": true, "max_tokens": 150, "fin_phrase": true, "plein_regime": true,\n'
    '\t\t\t"label": "scène %d (lookahead)" % [pos + 1]}}\n',
    '\t\t\t"opts": {"creative": true, "max_tokens": 90, "fin_phrase": true, "plein_regime": true,\n'
    '\t\t\t"label": "scène %d (lookahead)" % [pos + 1]}}\n',
    "P2-budget")

p.write_text(t, encoding="utf-8")
print("OK merlin_prompt_builder.gd")

# ── merlin_scenario.gd : les gardes disent ce qu'elles jettent ──
p = pathlib.Path("scripts/llm/merlin_scenario.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    '\tif r.has("error"):\n'
    "\t\treturn  # annulée par une pose (priorité correcte) ou moteur en défaut : l'arc couvrira\n",
    '\tif r.has("error"):\n'
    '\t\tprint("[MerlinScenario] lookahead — scène %d ANNULÉE (%s)" % [qn, str(r.get("error", "?"))])\n'
    "\t\treturn  # annulée par une pose (priorité correcte) ou moteur en défaut : l'arc couvrira\n",
    "S1-annulee")

t = exact(t,
    '\tif texte.length() < 30:\n'
    '\t\treturn\n'
    '\tif str(_run_thread.get("title", "")) != titre:\n',
    '\tif texte.length() < 30:\n'
    '\t\tprint("[MerlinScenario] lookahead — scène %d REJETÉE (trop courte : %d car.)" % [qn, texte.length()])\n'
    '\t\treturn\n'
    '\tif str(_run_thread.get("title", "")) != titre:\n',
    "S2-rejetee")

t = exact(t,
    '\tif int(run_node.beat_index) >= qn - 1:\n'
    '\t\treturn\n',
    '\tif int(run_node.beat_index) >= qn - 1:\n'
    '\t\tprint("[MerlinScenario] lookahead — scène %d JETÉE (trop tard : beat_index=%d)" % [qn, int(run_node.beat_index)])\n'
    '\t\treturn\n',
    "S3-jetee")

p.write_text(t, encoding="utf-8")
print("OK merlin_scenario.gd")
print("v35.6 applique")
"""marqueur: v35.6"""
