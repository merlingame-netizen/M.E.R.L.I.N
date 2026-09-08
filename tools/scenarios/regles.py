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


CARTES = MOTEUR.parent / "merlin_card.gd"


def _bloc(src: str, entete: str) -> str:
    """Le corps d'une fonction GDScript, de son entete a la prochaine declaration de meme niveau."""
    i = src.index(entete)
    j = src.find("\nstatic func ", i + 1)
    k = src.find("\nfunc ", i + 1)
    fins = [x for x in (j, k) if x != -1]
    return src[i:min(fins)] if fins else src[i:]


def traits() -> dict:
    """Les traits du jeu, LUS DANS LE CODE : {nom vu par le joueur: nom de rune celte}.

    POURQUOI. Une carte porte TROIS noms — « Le Geste Ancien » dans les donnees, « Coutume » en
    haut de la carte, « Henwaz » sous le glyphe — et la bible en ajoutait un quatrieme (« La
    Patience »). Le corpus employait celui de la bible : un cout de choix nomme « La Franchise » ne
    trouvait aucune carte et ne prelevait rien, en silence (08/09). Le corpus emploie desormais le
    nom que le JOUEUR VOIT, et cette fonction est ce qui permet de le verifier plutot que d'y croire.
    """
    src = CARTES.read_text(encoding="utf-8")
    # LES SEIZE DE DEPART, PAS LES QUARANTE-SEPT. La table des noms couvre toutes les cartes du jeu,
    # greffes comprises ; le paquet d'une traversee ne contient que ce que `starter_traits()`
    # fabrique. Une quete qui declarerait « Vigueur » nommerait une carte reelle mais absente du
    # paquet : la main affichee ne correspondrait a rien.
    ids = re.findall(r'make\("([a-z_]+)"', _bloc(src, "static func starter_traits"))
    noms = dict(re.findall(r'"([a-z_]+)"\s*:\s*\["([^"]+)",\s*"([^"]+)",\s*\d+\]', src)
                and [(m[0], (m[1], m[2])) for m in
                     re.findall(r'"([a-z_]+)"\s*:\s*\["([^"]+)",\s*"([^"]+)",\s*\d+\]', src)])
    out = {}
    for i in ids:
        if i in noms:
            out[noms[i][0]] = noms[i][1]
    if len(out) < 10:
        raise RuntimeError(
            "regles.py : la table des traits de %s est illisible (%d trouve(s)). Le corpus ne peut "
            "pas etre verifie contre un vocabulaire qu'on ne sait plus lire." % (CARTES, len(out)))
    return out


if __name__ == "__main__":
    print("lues dans %s :" % MOTEUR)
    print("  eclatante a partir de la marge %d" % ECLAT_MARGIN)
    print("  partiel jusqu'a la marge -%d" % PARTIEL_LOW)
    print("  +%d par tag requis couvert" % COVER_PER_TAG)
    print("  atouts propres plafonnes a +%d" % ATOUTS_PROPRES_CAP)
    print("  planchers durs : de 12 -> eclatante, de 2 -> echec")
    t = traits()
    print("  %d traits du jeu : %s" % (len(t), ", ".join(sorted(t))))
