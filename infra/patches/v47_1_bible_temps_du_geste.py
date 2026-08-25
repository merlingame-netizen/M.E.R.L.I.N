#!/usr/bin/env python3
"""Patch v47.1 — la Bible rattrape le code : R173, le temps du geste (v34→v47).

Cadence obligatoire (CLAUDE.md §10.3) : chaque feature complete met la Bible a jour. Or la
derniere decision datee est R172 (2026-07-31) : TOUT le cycle d'aout — geste sur, marge sure,
phrase du geste composee par le code, outro, fantome de tuile, carnet, banc du pacte — vit
dans le code sans vivre dans la Bible. Et c'est la Bible que lit LE SAGE du studio : sans R173,
il repondrait v33 a des questions v47.

Deux retouches : l'entree R173 en tete de la liste des decisions, et le bump de version du
titre (v2.0 -> v2.1)."""
import pathlib
import sys


def exact(texte, vieux, neuf, nom):
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return texte.replace(vieux, neuf)


p = pathlib.Path("docs/BIBLE.md")
t = p.read_text(encoding="utf-8")

# ── B1 : le bump de version du titre ──
t = exact(t,
    "# BIBLE — Jeu de deck-building narratif (reconstruction 2026-05-25) — **v2.0**",
    "# BIBLE — Jeu de deck-building narratif (reconstruction 2026-05-25) — **v2.1** (R173, 2026-08-25)",
    "B1-version")

# ── B2 : R173 en tete de la liste des decisions recentes ──
t = exact(t,
    "- **R168bis : CONVERSION CALIBREE EN RECOURS D'URGENCE (addendum final, 2026-07-29, 4 iterations\n",
    "- **R173 : LE TEMPS DU GESTE — resolution v34-v47 (2026-08-25, vagues d'aout, decisions Maxime\n"
    "  du 2026-08-19 au 2026-08-25)** : la resolution devient UN SEUL mouvement lisible :\n"
    "  fusion (les DEUX ensembles) -> LA PHRASE DU GESTE -> la mise -> de OU sceau -> issue ->\n"
    "  phrase de suite. Canon :\n"
    "  (1) GESTE SUR (v34) : si (2 + modificateurs) >= DC, aucun de — un sceau s'appose ;\n"
    "  l'eclatante reste reservee aux VRAIS jets (le risque est le seul chemin vers l'eclat).\n"
    "  Le sabotage par tag antagoniste s'applique MEME a un geste sur.\n"
    "  (2) LE DE SE DISPENSE (v46) : la MAITRISE du verbe (talent >= 2 donne +2) et la RARETE du\n"
    "  trait (Rare +1 / Epique +2 / Mythique +3) s'ajoutent au jet MINIMAL pour decider s'il faut\n"
    "  encore jeter — JAMAIS au Climax (le pic de quete se joue toujours au de). A talent 0 +\n"
    "  trait Commune, marge 0 : comportement v34 strictement inchange. La MISE est annoncee AVANT\n"
    "  le de (« Difficulte N - vos atouts +M », « Sans jet - maitrise du geste », « Sans jet - la\n"
    "  carte porte le geste ») — Hands of Fate montre la cible, il ne la cache pas. La ligne\n"
    "  mecanique n'annonce plus JAMAIS un 2d6 qui n'a pas roule.\n"
    "  (3) LA PHRASE DU GESTE EST COMPOSEE PAR LE CODE (v46 — supersede la voie prompt de\n"
    "  v36/v45 pour le geste lui-meme : « OBSERVER + Le Pressentiment » rendu par des mains qui\n"
    "  poussent une pierre a demontre qu'une regle de prompt ne tient pas un invariant) : socle du\n"
    "  verbe (5 verbes) + maniere du trait (les 25 concepts-coeur couverts ; le tag qui NOURRIT le\n"
    "  verbe est prioritaire), ecrite a la machine (~1,6 s + 0,35 s de tenue) entre la fusion et\n"
    "  le de. Deterministe, zero generation — ce temps est DONNE au LLM qui ecrit l'issue en fond.\n"
    "  Le modele n'ecrit plus que la SUITE du geste, jamais le geste.\n"
    "  (4) L'ISSUE OUVRE LA SUITE (v45) : sa derniere phrase RELANCE (ce que le Voyageur fait\n"
    "  maintenant, ou ce qui l'attend au pas suivant), meme generation, budgets +20 tokens ; et le\n"
    "  TRAIT donne la maniere dans le prompt d'issue (un trait de perception ne touche RIEN, un\n"
    "  trait de parole se prononce, un trait de force engage le corps).\n"
    "  (5) LE FANTOME DE TUILE (v47) : la fusion fusionne LES DEUX ensembles — une COPIE de la\n"
    "  tuile d'action (node NEUF, doctrine ghost v10.13.1, jamais un reparent) se detache d'elle,\n"
    "  converge avec le trait et eclate avec lui ; la tuile reelle pulse sur place (v11-W2 INTACT).\n"
    "  (6) MEMOIRE ET PASSE (v42-v44) : le canon du lore vit en tete STABLE des prompts (cache de\n"
    "  prefixe) ; le Voyageur est SANS passe — toute allusion a un passe doit venir de la CHRONIQUE\n"
    "  (carnet des 3 dernieres traversees, cross-run, [chronique] d'options.cfg) ; un pacte accepte\n"
    "  RE-ARME la pre-generation de l'issue (drain 20 s) — le banc de secours du beat du pacte est\n"
    "  clos par construction.\n"
    "  (7) GATE D'ANIMATION : la sonde du geste (tools/probe_fx_geste.tscn, 4 controles : sequence\n"
    "  complete, ligne mecanique sans de fantome, mouvement reduit, fantome de tuile) tourne dans\n"
    "  le patcheur CI sur Godot 4.4.1 AVANT tout push vers la branche du jeu — une animation livree\n"
    "  sans avoir jamais tourne, c'est termine.\n"
    "  Mesures de reference : phrase visible t+0,75-0,90 s, pleine t+2,35-2,50 s ; sequence\n"
    "  complete 3,7 s (sans jet) / 4,3 s (avec de) ; surcout net ~1,9 s, paye au LLM.\n"
    "\n"
    "- **R168bis : CONVERSION CALIBREE EN RECOURS D'URGENCE (addendum final, 2026-07-29, 4 iterations\n",
    "B2-R173")

p.write_text(t, encoding="utf-8")
print("v47.1 applique : R173 en tete des decisions, Bible v2.1.")
