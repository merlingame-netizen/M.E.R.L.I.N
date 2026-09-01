#!/usr/bin/env python3
"""La grille de lecture d'une quete. Elle ne refuse rien — elle MESURE.

    python3 tools/scenarios/relire.py data/scenarios/*.json     # les reperes du corpus
    python3 tools/scenarios/relire.py /chemin/quete_generee.json

POURQUOI, A COTE DU CONTRAT. `valider.py` dit non a ce qui est injouable. Il ne sait pas dire si
l'histoire tient : q82 est passee au contrat avec une mecanique parfaite, 23 marques de
tutoiement contre 8 de vouvoiement dans le meme texte, une maison hallucinee en pleine foret et
huit beats ou rien n'arrivait. Ces defauts-la se lisent, et je les relisais a la main a chaque
fois — donc de travers, et jamais deux fois pareil.

Ce fichier fige les nombres que je regarde, avec leurs REPERES mesures sur le corpus ecrit a la
main. Aucun n'est un verdict : un chiffre hors repere veut dire « va lire ce beat », pas « refuse ».

CE QU'IL NE SAURA JAMAIS DIRE : si les figures veulent quelque chose, si le mystere est dans
l'ambiance ou dans la confusion, si l'issue decoule vraiment du choix. Ca, il faut le lire.
"""
import json
import pathlib
import re
import sys

TU = re.compile(r"\b(?:[Tt]u|[Tt]on|[Tt]a|[Tt]es|[Tt]oi)\b")
VOUS = re.compile(r"\b(?:[Vv]ous|[Vv]otre|[Vv]os)\b")
# Un nom propre est une majuscule qui n'est PAS en tete de phrase.
NOM = re.compile(r"(?<=[a-zéèêàç,] )([A-ZÉÈÀÇ][a-zéèêàçâîôûïüë']{2,})")
FAUX_NOMS = {"Vous", "Votre", "Vos", "Elle", "Elles", "Ils", "Cela", "Merlin"}
# Les figures de style que les regles d'ecriture interdisent, et que le modele remet toujours.
IMAGES = re.compile(r"\b(?:comme si|comme un|comme une|tel un|telle une|on dirait|pareil à)\b", re.I)
# Le decor d'interieur : le defaut mesure sur q82, ou le beat 3 ouvrait une porte en chene dans
# une foret. On ne peut pas savoir si le lieu a un interieur — donc on COMPTE, on ne juge pas.
DEDANS = re.compile(r"\b(?:porte|pièce|chambre|couloir|escalier|plafond|cheminée|fenêtre)\b", re.I)


def hors_dialogue(t):
    return re.sub(r"«[^»]*»", " ", t)


def lire(q, nom):
    B = q["beats"]
    txt = " ".join(str(b.get("scene", "")) + " " + str(b.get("issue", "")) for b in B)
    nu = hors_dialogue(txt)
    tu, vs = len(TU.findall(nu)), len(VOUS.findall(nu))
    tu_beats = [b["n"] for b in B
                if TU.search(hors_dialogue(str(b.get("scene", "")) + " " + str(b.get("issue", ""))))]
    noms = sorted(set(NOM.findall(txt)) - FAUX_NOMS)
    images = IMAGES.findall(nu)
    dedans = sorted({b["n"] for b in B if DEDANS.search(str(b.get("scene", "")))})
    dialogues = txt.count("«")
    longueurs = [len(str(b.get("scene", ""))) + len(str(b.get("issue", ""))) for b in B]

    print("\n%s — %d beats" % (nom, len(B)))
    print("  adresse     tu=%-3d vous=%-3d %s" % (tu, vs,
          ("· beats qui tutoient : %s" % tu_beats) if tu_beats else "· repere corpus : tu≤1"))
    print("  figures     %d nommee(s) : %s" % (len(noms), ", ".join(noms[:10]) or "AUCUNE"))
    print("  images      %d interdite(s)%s" % (len(images),
          (" : " + ", ".join(sorted(set(x.lower() for x in images)))) if images else ""))
    print("  interieurs  beats citant porte/pièce/cheminée : %s" % (dedans or "aucun"))
    print("  dialogue    %d replique(s) entre guillemets" % dialogues)
    print("  longueurs   %d car. au total · %d le beat le plus court · %d le plus long"
          % (sum(longueurs), min(longueurs), max(longueurs)))
    return {"tu": tu, "vous": vs, "noms": len(noms), "images": len(images)}


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    tot = []
    for a in args:
        p = pathlib.Path(a)
        tot.append(lire(json.loads(p.read_text(encoding="utf-8")), p.stem))
    if len(tot) > 1:
        print("\nENSEMBLE  tu=%d vous=%d · %d figures · %d images interdites"
              % (sum(x["tu"] for x in tot), sum(x["vous"] for x in tot),
                 sum(x["noms"] for x in tot), sum(x["images"] for x in tot)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
