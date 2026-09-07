"""Les regles de resolution, LUES DANS LE MOTEUR — jamais recopiees.

POURQUOI CE FICHIER EXISTE. Le seuil de l'eclatante vivait en CINQ endroits : la constante du
moteur, la variable du moteur, `rendre.py`, `valider.py` et `generer_quete.gd`. Le 07/09, v55 l'a
passe de 8 a 7 dans le moteur seul : le contrat et le rendu ont continue d'appeler « reussite » ce
que le jeu appelle « eclatante », et le generateur, qui tourne chaque nuit, ecrivait la note du
beat et la consigne au modele a contresens sur 8,3 % des beats a DC 9.

Un chiffre qui decide se lit a UN endroit. Ici on lit `scripts/game/merlin_resolution.gd` — la
source qui fait foi — et si elle devient illisible, on le DIT et on s'arrete, plutot que de retomber
en silence sur une valeur perimee.

CE QUE LE MOTEUR FAIT ET QUE LA BIBLE OUBLIAIT : deux planchers durs. Un 12 aux deux des est
eclatant et un 2 est un echec, quels que soient les atouts (R158, « boxcars » et « snake eyes »).
"""
from __future__ import annotations

import pathlib
import re

MOTEUR = pathlib.Path(__file__).resolve().parents[2] / "scripts" / "game" / "merlin_resolution.gd"

ECHEC, PARTIEL, REUSSITE, ECLATANTE = "echec", "partiel", "reussite", "eclatante"


def _lire(nom: str) -> int:
    """La valeur d'une constante ou d'une variable statique entiere du moteur."""
    src = MOTEUR.read_text(encoding="utf-8")
    m = re.search(r"^(?:const|static var)\s+%s(?:\s*:\s*int)?\s*=\s*(-?\d+)" % re.escape(nom),
                  src, re.M)
    if not m:
        raise RuntimeError(
            "regles.py : %r est introuvable dans %s. Le moteur a change de forme : corriger ICI "
            "plutot que de recopier un chiffre ailleurs." % (nom, MOTEUR))
    return int(m.group(1))


ECLAT_MARGIN = _lire("eclat_margin")     # v55 : 7
PARTIEL_LOW = _lire("PARTIEL_LOW")       # 5
COVER_PER_TAG = _lire("COVER_PER_TAG")   # 3
ATOUTS_PROPRES_CAP = _lire("atouts_propres_cap")   # v55 : 2


def degre(marge: int, de: int | None = None) -> str:
    """Le degre, marge et planchers durs compris. `de` = somme des 2d6 (None = pas de jet)."""
    if de == 12:
        return ECLATANTE
    if de == 2:
        return ECHEC
    if marge >= ECLAT_MARGIN:
        return ECLATANTE
    if marge >= 0:
        return REUSSITE
    if marge >= -PARTIEL_LOW:
        return PARTIEL
    return ECHEC


if __name__ == "__main__":
    print("lues dans %s :" % MOTEUR)
    print("  eclatante a partir de la marge %d" % ECLAT_MARGIN)
    print("  partiel jusqu'a la marge -%d" % PARTIEL_LOW)
    print("  +%d par tag requis couvert" % COVER_PER_TAG)
    print("  atouts propres plafonnes a +%d" % ATOUTS_PROPRES_CAP)
    print("  planchers durs : de 12 -> eclatante, de 2 -> echec")
