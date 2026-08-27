#!/usr/bin/env python3
"""Patch v48.1f — LA LOI DE LA BOUCLE SE DIT, AU LIEU DE SE SAVOIR.

LE SEUL POINT D'EMPREINTE ENCORE MANQUE. v48 a grave dans LORE_CANON la signature du monde :
Broceliande est une foret-REVE qui BOUCLE sur elle-meme, les etres REJOUENT sans fin la meme
scene, et SEUL le Voyageur avance. C'est ce qui distingue ce jeu d'un decor celtique
passe-partout — et c'est ce qui explique, dans la fiction, pourquoi les druides repetent un rite
vide et pourquoi le chevalier rejoue sa defaite.

Deux parties temoins l'ont mesure, et la reponse est la meme : `boucle=0`. Zero occurrence de
boucl / rejou / repet / sans fin / meme scene / tourne en rond, dans TOUTE la prose de p68 (cinq
beats plus l'intro) comme dans celle de p69. Les lieux du canon passent, les figures propres
passent, les interdits tiennent a 3/3 — la boucle, jamais.

POURQUOI. Elle etait ecrite comme du CONTEXTE (« voici le monde »), pas comme une CONSIGNE
(« ecris ceci »). Un modele de 2 milliards de parametres suit ce qu'on lui demande de faire ; ce
qu'on lui raconte du decor, il l'utilise s'il en a l'occasion, et il n'en a jamais eu l'occasion
parce que rien ne la lui reclamait.

LE CORRECTIF. Une phrase imperative, courte, dans les DEUX generateurs de scene — le just-in-time
et la tranche d'arc. Elle ne demande pas d'expliquer la boucle (ce serait de la meta) mais de la
MONTRER par un detail concret : un etre qui refait un geste deja fait, une trace qui revient, une
parole redite. Le merveilleux du jeu est concret et inquietant ; sa loi doit l'etre aussi.

Cout : ~35 tokens par prompt de scene, en TETE STABLE (la formulation ne varie pas d'un beat a
l'autre), donc amortis par le cache de prefixe des la deuxieme scene. L'issue (le Vif, le
contexte tendu) n'est PAS touchee : la boucle appartient au decor, et le decor appartient au
Conteur.
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return t.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")

BOUCLE = (
    " UN DETAIL, UN SEUL, montre que ces bois REJOUENT : un etre qui refait un geste deja fait, "
    "une trace qui revient, une parole redite comme si c'etait la premiere fois. Montre-le, ne "
    "l'explique JAMAIS."
)

# ------------------------------------------------------------------ 1. la scene just-in-time
t = exact(
    t,
    "\\nLa scene = 1 a 2 phrases COURTES et CONCRETES (qui, quoi, ou ; AUCUNE image, AUCUN "
    "lyrisme, AUCUNE comparaison) avec un MONDE VIVANT (un personnage qui AGIT ou une presence "
    "qui reagit), SANS abstraction, qui FINIT sur un instant SUSPENDU : VARIE la chute, "
    "n'utilise JAMAIS « que faire », « que decidez-vous », « vous vous demandez ». Rien d'autre "
    "que la scene.",
    "\\nLa scene = 1 a 2 phrases COURTES et CONCRETES (qui, quoi, ou ; AUCUNE image, AUCUN "
    "lyrisme, AUCUNE comparaison) avec un MONDE VIVANT (un personnage qui AGIT ou une presence "
    "qui reagit), SANS abstraction, qui FINIT sur un instant SUSPENDU : VARIE la chute, "
    "n'utilise JAMAIS « que faire », « que decidez-vous », « vous vous demandez »." + BOUCLE +
    " Rien d'autre que la scene.",
    "la boucle dans scene_jit",
)

# ------------------------------------------------------------------ 2. les DEUX arcs
# Le meme texte de consigne existe a deux endroits : arc_tranche (les tranches de 4-5 etapes) et
# l'arc en 5 etapes d'un seul bloc. La boucle doit valoir pour tout ce que le Conteur ecrit comme
# scene, donc on patche les deux — en desambiguant par ce qui SUIT chacun.
ARC_COMMUN = (
    "\\nChaque etape = 3 a 4 phrases COURTES et CONCRETES (qui, quoi, ou ; AUCUNE image, AUCUN "
    "lyrisme, AUCUNE comparaison) avec un MONDE VIVANT (un personnage qui AGIT et PARLE, une "
    "presence qui reagit), SANS abstraction, qui FINIT sur un instant SUSPENDU : VARIE la "
    "chute, n'utilise JAMAIS « que faire », « que decidez-vous », « vous vous demandez »."
)
ARC_BOUCLE = ARC_COMMUN + "\\nDANS AU MOINS UNE etape de cette tranche," + BOUCLE[1:]

# a) arc_tranche : suivi de la ligne de format a deux %d
t = exact(
    t,
    ARC_COMMUN + '" \\\n\t\t+ "\\nFormat STRICT : une etape par ligne, prefixee « %d. »',
    ARC_BOUCLE + '" \\\n\t\t+ "\\nFormat STRICT : une etape par ligne, prefixee « %d. »',
    "la boucle dans arc_tranche",
)

# b) l'arc en 5 etapes d'un bloc : suivi de son EXEMPLE de maniere
t = exact(
    t,
    ARC_COMMUN + "\\nEXEMPLE de MANIERE (pas le contenu)",
    ARC_BOUCLE + "\\nEXEMPLE de MANIERE (pas le contenu)",
    "la boucle dans l'arc en 5 etapes",
)

p.write_text(t, encoding="utf-8")
print("v48.1f applique : la loi de la boucle passe du contexte a la consigne, dans les deux")
print("generateurs de scene. L'issue n'est pas touchee — le decor appartient au Conteur.")
