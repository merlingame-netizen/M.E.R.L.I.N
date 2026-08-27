#!/usr/bin/env python3
"""Patch v48.1e — LA MESURE DIT ENFIN CE QU'ELLE MESURE.

Trouve par la revue adversariale, et c'est une critique de MA propre lecture : je n'aurais pas
du l'ecrire comme un fait.

LE PROBLEME. Le champ `gen` du journal — celui d'ou viennent tous les chiffres qui ont servi a
diagnostiquer p68 (prompt_tokens=2045, tokens_ecrits=2, ecriture_ms...) — est un simple
instantane de `MerlinNative.last_metrics()`, pris a la sortie du beat
(probe_partie_journal.gd). Or `_last_metrics` est ECRASE par CHAQUE generation qui se termine,
sur N'IMPORTE QUELLE voie, et le dictionnaire ne porte AUCUN nom : il a « cerveau », pas
« label ». Rien, dans le journal, ne dit si la mesure decrit l'issue du beat ou une scene que le
Conteur venait de finir en fond.

Autrement dit : le mecanisme du plafond de contexte est etabli par le CODE (n_past initialise a
la taille totale du prompt, boucle arretee a n_ctx-1) et par le comptage des caracteres du
prompt d'issue, mais l'ATTRIBUTION des cinq mesures du journal a l'issue, elle, ne l'etait pas.
Je l'ai presentee comme acquise. Elle ne l'etait pas.

LE CORRECTIF, une ligne : `met` porte desormais son `label`. Le journal dira donc « issue
(combinaison) », « scene N (lookahead) » ou « intro de quete (Merlin) », et toute mesure attribuee
a la mauvaise generation se verra d'un coup d'oeil au lieu de se deguiser en preuve.

Ce n'est pas cosmetique : c'est la difference entre un verdict de partie temoin sur lequel on
peut fonder une decision, et un verdict qui ressemble a une preuve.
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return t.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_native.gd")
t = p.read_text(encoding="utf-8")

t = exact(
    t,
    '''	var met: Dictionary = {
		"cerveau": cerveau,''',
    '''	var met: Dictionary = {
		# v48.1e — LE NOM DE LA MESURE. _last_metrics est ecrase par chaque generation qui
		# se termine, toutes voies confondues ; sans nom, un releve pris apres coup (le champ
		# « gen » du journal de la sonde) pouvait decrire une scene du Conteur en croyant
		# decrire l'issue du beat. La mesure se nomme, on ne devine plus.
		"label": str(v["label"]),
		"cerveau": cerveau,''',
    "le nom de la mesure",
)

p.write_text(t, encoding="utf-8")
print("v48.1e applique : _last_metrics porte son label — le journal dira desormais QUELLE")
print("generation il a mesuree, au lieu de laisser croire que c'est toujours l'issue.")
