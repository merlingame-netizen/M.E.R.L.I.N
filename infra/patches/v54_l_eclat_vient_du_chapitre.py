#!/usr/bin/env python3
"""Patch v54 — L'ECLAT DU GRAAL VIENT DU CHAPITRE, PAS DE LA VICTOIRE.

CE QUE LE CANON EXIGE. R180 (§26.2, deploye le 2026-08-29) fait de l'eclat la recompense d'un
CHAPITRE de la quete principale : douze chapitres, douze eclats, et chaque chapitre porte ses
conditions d'ouverture. Le README du paquet Penn ar Bed le nomme lui-meme « le premier ticket a
ouvrir ».

CE QUE LE CODE FAIT AUJOURD'HUI. `MerlinChronicle.record_end` incremente `graal_fragments` sur
TOUTE fin d'accomplissement, quelle qu'elle soit :

    if end_type == "accomplissement":
        cfg.set_value(SECTION, "graal_fragments", ... + 1)

Douze traversees libres reussies suffisent donc a terminer la quete principale sans avoir ouvert
un seul chapitre. Toute l'architecture des verrous devient decorative — et elle l'est deja
aujourd'hui, silencieusement, puisque rien ne distingue une fin de chapitre d'une fin ordinaire.

LE CORRECTIF, ET SA PRUDENCE. On ne supprime pas l'increment : on le CONDITIONNE. `record_end`
accepte un parametre `chapitre` (vide par defaut) et n'accorde l'eclat que s'il est renseigne. Tous
les appelants actuels passent donc par le defaut et n'accordent plus rien — ce qui est exactement
l'intention : aujourd'hui aucune fin n'est une fin de chapitre, puisque les chapitres ne sont pas
encore joues.

L'ECLAT NE PEUT PLUS ETRE COMPTE DEUX FOIS. Un chapitre deja recompense ne redonne rien, meme
rejoue : les chapitres acquis sont conserves dans la chronique. Sans cette liste, rejouer le
chapitre 1 douze fois rendait les verrous aussi decoratifs qu'avant.

CE QUE CE PATCH NE FAIT PAS, et il faut le savoir avant de croire la quete principale jouable :
aucun appelant ne passe encore de `chapitre`, parce que rien ne SAIT quel chapitre est en cours.
Cela demande le registre des hauts faits cross-run, nomme comme manque bloquant en §26.6. Ce patch
ferme la porte ouverte ; il ne construit pas la maison. En attendant, le compteur d'eclats reste a
sa valeur acquise et cesse simplement de monter tout seul.
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return t.replace(vieux, neuf)


p = pathlib.Path("scripts/game/merlin_chronicle.gd")
t = p.read_text(encoding="utf-8")

# 1. La signature accueille le chapitre, en dernier et avec un defaut : aucun appelant ne casse.
t = exact(
    t,
    'static func record_end(end_type: String, scenario_title: String, integrite: int, '
    'corruption: int, faction: String = "", pilier: String = "", voie: String = "", '
    'entree: Dictionary = {}) -> void:',

    '# v54 — `chapitre` : quel chapitre de la quete principale cette fin acheve. VIDE par defaut,\n'
    '# et c\'est le cas de tous les appelants actuels : une traversee libre n\'acheve aucun chapitre\n'
    '# et ne doit donc plus donner d\'eclat (R180).\n'
    'static func record_end(end_type: String, scenario_title: String, integrite: int, '
    'corruption: int, faction: String = "", pilier: String = "", voie: String = "", '
    'entree: Dictionary = {}, chapitre: String = "") -> void:',
    "la signature de record_end",
)

# 2. L'eclat ne tombe plus sur la victoire seule, et jamais deux fois pour le meme chapitre.
t = exact(
    t,
    '\t# P2 (chantier 4a) : 1 eclat du Graal par fin accomplissement (cumul cross-run, additif).\n'
    '\tif end_type == "accomplissement":\n'
    '\t\tcfg.set_value(SECTION, "graal_fragments", int(cfg.get_value(SECTION, "graal_fragments", 0)) + 1)\n',

    '\t# v54 — L\'ECLAT VIENT DU CHAPITRE, PAS DE LA VICTOIRE (R180).\n'
    '\t# Avant : toute fin « accomplissement » donnait un eclat, donc douze traversees libres\n'
    '\t# suffisaient a finir la quete principale et les verrous de chapitre ne servaient a rien.\n'
    '\t# Desormais il faut ET une fin accomplie ET un chapitre nomme. Aucun appelant n\'en passe\n'
    '\t# encore : c\'est voulu, aucune fin d\'aujourd\'hui n\'acheve un chapitre.\n'
    '\t# Un chapitre deja recompense ne redonne rien, meme rejoue — sans cette liste, rejouer le\n'
    '\t# chapitre 1 douze fois rouvrait exactement le trou qu\'on vient de fermer.\n'
    '\tif end_type == "accomplissement" and chapitre != "":\n'
    '\t\tvar acquis: Array = cfg.get_value(SECTION, "chapitres_acquis", [])\n'
    '\t\tif not acquis.has(chapitre):\n'
    '\t\t\tacquis.append(chapitre)\n'
    '\t\t\tcfg.set_value(SECTION, "chapitres_acquis", acquis)\n'
    '\t\t\tcfg.set_value(SECTION, "graal_fragments", int(cfg.get_value(SECTION, "graal_fragments", 0)) + 1)\n',
    "l'increment de graal_fragments",
)

# 3. Le defaut de la chronique porte la nouvelle cle, sinon la premiere lecture rend un type faux.
t = exact(
    t,
    '\t"graal_fragments": 0, "last_voie": "",',
    '\t"graal_fragments": 0, "last_voie": "",\n'
    '\t# v54 — les chapitres de la quete principale deja recompenses. Sans ce defaut, la premiere\n'
    '\t# lecture d\'une chronique ancienne rendrait null la ou le code attend un Array.\n'
    '\t"chapitres_acquis": [],',
    "le defaut chapitres_acquis",
)

p.write_text(t, encoding="utf-8")
print("v54 applique : l'eclat exige un chapitre nomme, et ne tombe qu'une fois par chapitre.")
