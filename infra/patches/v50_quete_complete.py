#!/usr/bin/env python3
"""Patch v50 — LA QUETE COMPLETE : des captures etalees sur toute sa longueur.

LA DEMANDE. Maxime, 2026-08-28 : « on va plus loin maintenant, pas 5 beats mais des quetes
completes, duree variable ».

CE QU'IL N'Y A PAS A FAIRE. Le jeu tire DEJA la longueur au hasard entre 8 et 25 beats
(merlin_scenario.gd : QUETE_BEATS_MIN / QUETE_BEATS_MAX, tirage a la ligne 1328). C'est la
variable d'environnement MERLIN_BEATS qui la force, et le commentaire du code le dit lui-meme :
« pour le DIAGNOSTIC uniquement ». Il suffit donc de cesser de la passer — c'est l'affaire du
job, pas du code.

CE QU'IL FAUT FAIRE. La sonde ne prend que TROIS captures : l'intro, le beat 1, la fin. Sur une
quete de vingt beats, une chronique n'aurait donc rien a montrer entre le debut et la fin — trois
images pour une heure de jeu. Le plafond SHOTS_MAX=12 existe deja et sert precisement a ca : « au
dela d'une douzaine d'images le document devient un diaporama illisible ». Il n'a jamais ete
atteint parce que rien ne declenchait de capture au-dela du premier beat.

On etale : le beat 1, puis un beat sur trois. Une quete de 8 beats rend 3 captures de jeu, une
de 25 en rend 9 — plus l'intro et la fin, on reste sous le plafond dans les deux cas, sans
jamais avoir a le calculer.

Les captures portent desormais leur NUMERO DE BEAT (beat_04, beat_07...) au lieu du seul
« beat_01 » : dans une chronique de vingt beats, une image qui ne dit pas d'ou elle vient ne
sert a rien.

LES LIGNES DE BASE A COMPARER, pour que le verdict de la premiere quete longue se lise :
  CONTINUITE ... 0 sur 5 avant v49 (p71), 5 sur 5 apres (p73) — mais sur SIX beats seulement.
                 La question qu'une quete longue seule peut trancher : un fil qui tient sur cinq
                 enchainements tient-il sur vingt, ou derive-t-il ?
  ATTENTE ....... 23 s de moyenne a p71, 21 s a p73, pour une cible de 20. Les deux pics (61 s
                 et 55 s) tombent au beat ou une tranche d'arc s'ecrit en fond. Une quete de 25
                 beats en demande six au lieu de deux : la cible va probablement souffrir, et il
                 faudra le dire avec le compte exact plutot qu'avec une excuse.
  EMPREINTE ..... boucle=1 a p71, 0 a p73. La consigne de v48.1f ne produit pas de facon fiable ;
                 vingt beats donneront enfin un echantillon ou le chiffre veut dire quelque chose.
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return t.replace(vieux, neuf)


p = pathlib.Path("tools/probe_partie_journal.gd")
t = p.read_text(encoding="utf-8")

t = exact(
    t,
    """	# Un cliché au premier beat : il montre l'écran de jeu complet, ce qu'aucun texte ne remplace.
	if idx == 0:
		await _cliche("beat_01")""",
    """	# v50 — DES CLICHES ETALES SUR TOUTE LA QUETE. Le beat 1, puis un beat sur trois. La sonde
	# n'en prenait qu'UN (le premier) : sur une quete de vingt beats, une chronique n'avait rien
	# a montrer entre le debut et la fin. Le plafond SHOTS_MAX=12 existait deja pour cela et
	# n'etait jamais atteint, faute de declencheur au-dela du premier beat — 8 beats rendent 3
	# images de jeu, 25 en rendent 9, on reste sous le plafond sans avoir a le calculer.
	# Le NUMERO est dans le nom : dans une chronique longue, une image qui ne dit pas d'ou elle
	# vient ne sert a rien.
	if idx == 0 or (idx + 1) % 3 == 0:
		await _cliche("beat_%02d" % (idx + 1))""",
    "les cliches etales",
)

# La deadline de la sonde a ete calibree pour « 12-15 beats ». Une quete peut en compter 25, et
# chaque beat coute a la sonde ses poses deliberees (25 s de reflexion + 35 s de lecture) en plus
# de la generation : 25 beats a ~50 s valent deja 21 minutes, sans compter les tranches d'arc.
t = exact(
    t,
    "const RUN_DEADLINE_S: float = 3000.0   # 12-15 beats, une narration écrite par beat sur CPU",
    "const RUN_DEADLINE_S: float = 5400.0   # v50 — une QUETE COMPLETE : jusqu'a 25 beats, chacun\n"
    "                                       # portant ses poses deliberees (25 s + 35 s) en plus de\n"
    "                                       # la generation. L'ancienne borne visait 12-15 beats.",
    "la deadline de la sonde",
)

p.write_text(t, encoding="utf-8")
print("v50 applique : captures etalees (beat 1 puis un sur trois, numerotees) et deadline portee")
print("a 90 minutes pour couvrir une quete de 25 beats.")
