#!/usr/bin/env python3
"""Scénario type de référence — canon bible v4.2.

Ce qu'un scénario type est, après les décisions du 2026-07-26 et du 2026-07-27 :

  LE VOYAGEUR NE SAIT RIEN  aucun passé partagé, aucune dette antérieure, aucun
                            nom su d'avance. Tout s'apprend dans le scénario.
                            (bible §33.1)
  AUCUNE ELLIPSE            deux cartes consécutives sont contiguës. Un geste se
                            décompose en ses temps : approcher, frapper,
                            attendre, qu'on ouvre, les premiers mots, entrer,
                            s'installer. (bible §33.2)
  LONGUEUR VARIABLE         11 / 15 / 17 / 21 / 25. À cette granularité, une
                            histoire tient en 21-25 cartes.
  LINÉAIRE                  une seule séquence pour tous les joueurs ; ce sont
                            les résolutions qui varient selon l'état accumulé.
  GRAMMAIRE COMPLÈTE        situation → 3 choix → résolution de réussite ET
                            d'échec → suite. Jamais de chiffre dans un texte.

Le scénario produit ici est écrit à la main : c'est la CIBLE que la génération
LLM doit atteindre, pas un échantillon de ce qu'elle produit. Il sert de
fixture au validateur et de référence de forme — jamais de modèle de contenu
à recopier (cf. generation_contract : le few-shot de contenu est interdit).

Usage :
  python tools/build_scenario_type.py --out data/ai/scenario_type_reference.json \
      --markdown docs/30_jdr/SCENARIO_TYPE_REFERENCE.md
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

# ── La graine de variation qui a produit ce scénario ──────────────────────
# Tirée par ScenarioVariation avant génération : c'est elle qui garantit
# qu'aucun scénario ne ressemble au précédent. Conservée ici pour montrer le
# lien entre la contrainte imposée et le scénario obtenu.
GRAINE = {
    "lieu": "tourbiere",
    "entite_centrale": "un vivant qu'on croit mort",
    "pression": "une dette a honorer",
    "registre_sensoriel": "odeur",
    "mecanisme_du_twist": "identite (qui est vraiment la)",
}

TITRE = "Deux Assiettes"
ARCHETYPE = "mist_wanderer"
LONGUEUR = 25

# La dette de la graine appartient AUX GENS QU'ON RENCONTRE, jamais au
# voyageur : c'est elle qui doit le silence et les repas, pas lui.
INTRO = (
    "Le jour tombe et la tourbière du Yeun ne rend pas le pied ferme. Tu marches depuis "
    "l'aube sur un chemin de planches que personne n'a l'air d'emprunter, et pourtant on "
    "l'entretient. L'odeur te prévient avant le paysage : ici la tourbe ne sent pas la "
    "vase, elle sent le pain brûlé et le fer. Il te faut un toit avant la nuit, et "
    "l'hospitalité ne se refuse pas à un voyageur, même dans le Yeun. Une fenêtre "
    "s'allume au bout des planches. Tu ne sais rien de cette maison ni de qui l'habite. "
    "Tu vas l'apprendre."
)

HOOK = ("La tourbe ne sent pas la vase : elle sent le pain brûlé, et l'odeur vient d'un "
        "point fixe.")
ESSENCE = "Tu demandes un toit pour une nuit, et l'on met deux assiettes."


# ── Fabriques d'effets ────────────────────────────────────────────────────
# Les `effects` d'une option sont le GAIN en cas de réussite. Le coût du risque
# vit exclusivement dans `fail_damage` : porter un DAMAGE_LIFE ici facturerait
# l'audace deux fois et ferait exploser l'écart d'EV (bible §32.1a).
def R(faction, amount, *extra):
    return [{"type": "ADD_REPUTATION", "faction": faction, "amount": amount}] + list(extra)


def TAG(t):
    return {"type": "ADD_TAG", "tag": t}


def ESS(n):
    return {"type": "ADD_ESSENCE", "amount": n}


def HEAL(n):
    return {"type": "HEAL_LIFE", "amount": n}


def ANAM(n):
    return {"type": "ADD_ANAM", "amount": n}


def PROM(pid, deadline, desc):
    return {"type": "CREATE_PROMISE", "promise_id": pid,
            "deadline_cards": deadline, "description": desc}


def O(label, verb, faction, gradient, stat, check, fd, effects, outcome, fail,
      variantes=None, telegraphie=False):
    """Une option : ce qu'on lit, ce qu'on risque, ce qui se produit dans les
    deux cas. `outcome` et `fail` racontent deux issues nettement différentes —
    l'échec fait avancer la scène, il ne se contente pas de refuser l'action."""
    o = {"label": label, "verb": verb, "faction": faction, "gradient": gradient,
         "stat": stat, "check": check, "fail_damage": fd, "effects": effects,
         "outcome": outcome, "outcome_fail": fail}
    if variantes:
        o["variantes"] = variantes
    if telegraphie:
        o["telegraphie"] = True
    return o


def C(n, type_, rarity, emotion, resume, situation, options):
    return {"n": n, "type": type_, "rarity": rarity, "emotion": emotion,
            "resume": resume, "situation": situation, "options": options}


# ── Les 25 cartes ─────────────────────────────────────────────────────────
# Cinq actes de cinq cartes. Chaque carte reprend exactement où la précédente
# s'est arrêtée : le chemin, le seuil, l'attente, la porte, les premiers mots,
# l'entrée, la table. Rien n'est sauté.
#
# Épreuves : 18 cartes blanches, 5 contextuelles (c10, c13, c16, c17, c24),
# 2 rouges télégraphiées (c18 acte IV, c22 acte V — quatre cartes d'écart).
# Sur une carte blanche, le gradient s'exprime par la marche 3/4/5 des dégâts
# d'échec et un gain croissant, pas par une épreuve plus dure.

CARTES = [
 # ───────────────────────── ACTE I — le chemin et le seuil ────────────────
 C(1, "NARRATIVE", "COMMUNE", "curiosite",
   "Le chemin de planches s'enfonce dans la tourbiere au crepuscule.",
   "Le chemin de planches s'enfonce dans la tourbiere au crepuscule. L'odeur qui monte "
   "n'est pas celle de la vase : ca sent le pain brule et le fer.", [
   O("Presser le pas", "presser", "anciens", "prudente", "volonte", "white", 3,
     R("anciens", 6),
     "Tu allonges la foulee. Les planches sonnent creux sous tes bottes, une sur trois "
     "bouge, et tu comprends que quelqu'un les entretient juste assez pour qu'on passe.",
     "Tu presses trop et le pied glisse. Tu finis a genoux sur le bois mouille, les "
     "paumes pleines d'echardes noires."),
   O("Lire les traces", "lire", "druides", "equilibree", "logic", "white", 4,
     R("druides", 8),
     "Deux passages recents dans le meme sens, aucun dans l'autre. Les planches neuves "
     "sont posees par-dessus les anciennes sans les remplacer : on a rallonge le chemin, "
     "on ne l'a pas repare.",
     "La tourbe garde mal les traces et le jour tombe plus vite que tu ne lis. Tu releves "
     "la tete sans savoir depuis combien de temps tu es accroupi."),
   O("Remonter l'odeur", "flairer", "korrigans", "audacieuse", "instinct", "white", 5,
     R("korrigans", 10),
     "Tu quittes les planches et suis l'odeur a contre-vent. Elle ne se disperse pas : "
     "elle vient d'un point fixe, loin devant, la ou une fenetre s'allume.",
     "Tu quittes les planches et la tourbe te prend jusqu'au mollet en deux pas. Le temps "
     "de te degager, l'odeur a change de direction.")]),

 C(2, "NARRATIVE", "COMMUNE", "fascination",
   "Une maison basse au bout des planches, fenetre allumee, cheminee froide.",
   "Au bout des planches, une maison basse. Une fenetre eclairee, et pas un fil de fumee "
   "a la cheminee alors que la nuit tombe et qu'il gele deja.", [
   O("Observer depuis la bruyere", "observer", "druides", "prudente", "logic", "white", 3,
     R("druides", 6),
     "Tu t'accroupis dans la bruyere. Une ombre passe derriere la vitre, s'arrete, "
     "revient. Elle fait le tour de la piece sans jamais s'asseoir.",
     "La bruyere est plus basse que tu ne croyais et le froid monte vite. Tu n'apprends "
     "rien, sinon que tes jambes ne te porteront pas longtemps."),
   O("Approcher franchement", "approcher", "anciens", "equilibree", "volonte", "white", 4,
     R("anciens", 8),
     "Tu marches droit, sans te cacher, en faisant sonner tes pas sur les planches. C'est "
     "ainsi qu'on approche une maison quand on n'a rien a se reprocher.",
     "Tu marches droit et la lumiere s'eteint avant que tu sois a mi-chemin. Tu finis "
     "d'avancer dans le noir, vers une maison qui a decide de ne pas te voir."),
   O("Faire le tour", "contourner", "korrigans", "audacieuse", "instinct", "white", 5,
     R("korrigans", 10),
     "Tu contournes par l'arriere. Pas de tas de tourbe, pas de bois coupe, pas de "
     "fumier : personne ne prepare l'hiver ici. Mais le seuil de la porte de derriere est "
     "use, et recemment.",
     "Tu contournes et la tourbe cede sous toi dans un bruit mou. Un chien qui n'existe "
     "pas se met a aboyer quelque part, et tu reviens devant en tremblant.")]),

 C(3, "NARRATIVE", "RARE", "tension",
   "Sur le seuil, une paire de bottes d'homme, seches, tournees vers l'interieur.",
   "Devant la porte, sur le seuil de pierre, une paire de bottes d'homme. Tournees vers "
   "l'interieur, comme si quelqu'un venait de rentrer. Elles sont seches.", [
   O("Frapper", "frapper", "anciens", "prudente", "volonte", "white", 3,
     R("anciens", 6),
     "Tu frappes trois coups nets et tu recules d'un pas, comme il se doit. A l'interieur, "
     "quelque chose s'arrete de bouger.",
     "Tu frappes plus fort que tu ne voulais et le bois sonne creux dans toute la maison. "
     "Le silence qui suit dure trop longtemps pour etre innocent."),
   O("Examiner les bottes", "examiner", "druides", "equilibree", "logic", "white", 4,
     R("druides", 8, TAG("bottes_seches")),
     "Le cuir est sec jusqu'a la couture et la semelle propre. La tourbe ne pardonne pas : "
     "personne n'a marche dans le marais avec ces bottes. On les a posees la pour qu'on "
     "les voie.",
     "Tu retournes une botte et la semelle te reste dans la main, rongee par la tourbe. Tu "
     "la reposes de travers et tu n'as pas le temps de la redresser."),
   O("Appeler", "appeler", "niamh", "audacieuse", "empathie", "white", 5,
     R("niamh", 10),
     "Tu appelles vers la porte, sans nom, juste pour dire qu'il y a quelqu'un dehors. Ta "
     "voix porte loin sur la tourbe et te revient plus petite qu'elle n'est partie.",
     "Tu appelles et ta voix se casse sur le froid. A l'interieur, la lampe se deplace "
     "vers le fond de la piece au lieu de venir vers la porte.")]),

 C(4, "EVENT", "COMMUNE", "peur",
   "Rien ne repond. Un pas de l'autre cote du bois, puis plus rien.",
   "Rien ne repond. Un pas, un seul, de l'autre cote du bois — puis plus rien. Le vent "
   "tombe d'un coup et le froid s'installe sur le seuil avec toi.", [
   O("Attendre sans bouger", "attendre", "anciens", "prudente", "volonte", "white", 3,
     R("anciens", 6, HEAL(2)),
     "Tu restes immobile, les mains visibles. Au bout d'un long moment le pas revient vers "
     "la porte, plus lentement, mais il revient. Tu respires mieux d'avoir su ne rien "
     "forcer.",
     "Tu attends, et le froid gagne avant la porte. Quand tu bouges enfin, tes doigts ne "
     "se referment plus tout a fait."),
   O("Annoncer que tu es un voyageur", "annoncer", "niamh", "equilibree", "empathie",
     "white", 4, R("niamh", 8),
     "Tu dis a voix haute que tu es un voyageur et que tu demandes le gite pour la nuit. "
     "C'est la seule phrase qui ouvre les portes ici, et tu l'entends faire son chemin de "
     "l'autre cote du bois.",
     "Tu annonces le gite d'une voix mal assuree et tu t'entends bafouiller. De l'autre "
     "cote, on ne bouge plus du tout."),
   O("Pousser la porte", "pousser", "korrigans", "audacieuse", "instinct", "white", 5,
     R("korrigans", 10),
     "Tu poses la main a plat sur le bois et pousses. La porte n'est pas verrouillee : "
     "elle est tenue, de l'interieur, par quelqu'un qui n'a pas la force de la tenir "
     "longtemps.",
     "Tu pousses et le loquet cede d'un coup sec. Le bruit fait sursauter la maison "
     "entiere, et tu restes le bras tendu comme un voleur pris.")]),

 C(5, "NARRATIVE", "COMMUNE", "curiosite",
   "La porte s'ouvre de la largeur d'une main : une lampe, puis une femme.",
   "La porte s'ouvre de la largeur d'une main. Une lampe d'abord, puis une femme derriere, "
   "qui ne dit rien et te regarde des pieds a la tete.", [
   O("Demander le gite", "demander", "niamh", "prudente", "empathie", "white", 3,
     R("niamh", 6),
     "Tu demandes un coin de sol et le feu jusqu'au jour. Elle ne repond pas tout de "
     "suite : elle regarde derriere toi, la tourbiere, avant de te regarder toi.",
     "Tu demandes le gite trop vite, presque comme un du. Sa main se referme sur le bord "
     "de la porte et l'ouverture ne s'agrandit pas."),
   O("Dire d'ou tu viens", "expliquer", "druides", "equilibree", "logic", "white", 4,
     R("druides", 8),
     "Tu nommes le chemin, les planches neuves, l'odeur. A « planches neuves » son visage "
     "change une seconde, et elle ouvre la porte un peu plus.",
     "Tu parles trop du chemin et pas assez de toi. Elle t'ecoute jusqu'au bout, poliment, "
     "et ne s'ecarte pas d'un pouce."),
   O("Attendre qu'elle parle", "patienter", "anciens", "audacieuse", "volonte", "white", 5,
     R("anciens", 10),
     "Tu ne dis rien. Le silence dure jusqu'a ce qu'elle le rompe : « Il n'y a personne "
     "d'autre que moi ici. » Elle l'a dit sans qu'on le lui demande.",
     "Tu attends et elle attend mieux que toi. Quand tu cedes enfin et parles le premier, "
     "ta phrase sort de travers.")]),

 # ───────────────────────── ACTE II — entrer, s'asseoir, manger ───────────
 C(6, "NARRATIVE", "COMMUNE", "fascination",
   "Elle regarde la tourbiere par-dessus ton epaule, puis s'efface pour te laisser passer.",
   "Elle regarde par-dessus ton epaule, longuement, la tourbiere ou la nuit finit de "
   "tomber. Puis elle s'efface contre le mur pour te laisser le passage.", [
   O("Demander si tu deranges", "demander", "niamh", "prudente", "empathie", "white", 3,
     R("niamh", 6),
     "Tu demandes si tu deranges. « On ne derange pas un voyageur », dit-elle — elle a "
     "inverse la phrase, et elle ne s'en apercoit pas.",
     "Tu demandes si tu deranges et elle repond que non, deux fois, trop vite. Le mensonge "
     "est petit mais il est la, et vous le savez tous les deux."),
   O("Entrer", "entrer", "anciens", "equilibree", "volonte", "white", 4,
     R("anciens", 8),
     "Tu entres en te baissant sous le linteau. Derriere toi elle referme, met la barre, "
     "et verifie la barre une seconde fois.",
     "Tu entres et ton epaule accroche le chambranle ; quelque chose tombe et roule sous "
     "un meuble. Elle ne va pas le ramasser."),
   O("Regarder ce qu'elle regarde", "suivre", "druides", "audacieuse", "logic", "white", 5,
     R("druides", 10, TAG("la_lueur")),
     "Tu suis son regard. Loin sur la tourbe, a hauteur d'homme, une lueur basse avance "
     "puis s'arrete. Quand tu te retournes, elle a deja baisse les yeux.",
     "Tu te retournes vers la tourbiere et ne vois que du noir. Le temps que tes yeux s'y "
     "fassent, elle t'a pris par la manche et tire a l'interieur.")]),

 C(7, "NARRATIVE", "COMMUNE", "curiosite",
   "Une piece basse, un feu eteint, et la table mise pour deux.",
   "Une piece basse, un feu eteint sous la cheminee froide, et la table mise pour deux. "
   "Une des assiettes est pleine et n'a pas ete touchee.", [
   O("T'asseoir ou elle t'indique", "asseoir", "anciens", "prudente", "volonte", "white", 3,
     R("anciens", 6),
     "Elle te montre le banc, cote porte. Tu t'assieds la et non devant l'assiette pleine, "
     "et tu vois a son epaule qui redescend que c'etait la bonne place.",
     "Tu t'assieds sans regarder ou et tu te retrouves devant l'assiette pleine. Elle ne "
     "dit rien. Elle ne s'assied pas non plus."),
   O("Rester debout", "patienter", "niamh", "equilibree", "empathie", "white", 4,
     R("niamh", 8),
     "Tu restes debout jusqu'a ce qu'elle s'assoie. Elle ne s'assoit pas. Elle finit par "
     "te pousser le banc du pied, presque en riant, et quelque chose se detend entre vous.",
     "Tu restes debout trop longtemps et la piece devient genante. Elle te sert sans te "
     "regarder, comme on sert quelqu'un qui n'entrera jamais vraiment."),
   O("Regarder l'assiette intacte", "examiner", "druides", "audacieuse", "logic", "white", 5,
     R("druides", 10, TAG("deux_assiettes")),
     "La nourriture est froide mais du jour. On l'a servie ce soir, on ne l'a pas mangee, "
     "et on ne l'a pas desservie non plus. On l'attend encore.",
     "Tu regardes l'assiette une seconde de trop. Elle la retire, la vide dans le seau, et "
     "repose l'assiette vide exactement au meme endroit.")]),

 C(8, "SHOP", "RARE", "fascination",
   "Elle sort d'un coffre des affaires d'homme et te dit de prendre ce qu'il te faut.",
   "Elle pose devant toi ce qu'elle a : du pain dur, de la tourbe seche pour le feu. Puis, "
   "d'un coffre, des affaires d'homme. « Prenez ce qu'il vous faut. »", [
   O("Prendre la corde", "prendre", "anciens", "prudente", "volonte", "white", 3,
     [ESS(6), TAG("corde")],
     "Tu prends une corde epaisse de graisse de mouton. « Elle ne pourrit pas dans la "
     "tourbe », dit-elle. Elle savait exactement ou elle etait dans le coffre.",
     "Tu tires la corde et le coffre entier bascule. Tu ramasses tout et remets tout, et "
     "elle range derriere toi sans un mot, dans un ordre qui n'est pas le tien."),
   O("Prendre la lampe", "prendre", "druides", "equilibree", "logic", "white", 4,
     [ESS(8), TAG("lampe")],
     "Une lampe a huile cabossee, le verre fume. Elle la remplit devant toi et te "
     "previent : « Dans le Yeun, elle ne vous eclaire pas. Elle vous signale. »",
     "Tu prends la lampe sans verifier la meche et elle rend une flamme basse et sale. "
     "Elle te regarde t'en apercevoir sans te le dire."),
   O("Ne rien prendre", "refuser", "korrigans", "audacieuse", "instinct", "white", 5,
     R("korrigans", 12),
     "Tu refermes le coffre toi-meme. « Gardez-les pour celui a qui elles sont. » Tu as "
     "parle au present sans le faire expres, et elle ne te corrige pas.",
     "Tu refuses tout, un peu trop noblement. Elle referme le coffre d'un coup de genou et "
     "le repousse au mur avec le pied.")]),

 C(9, "NARRATIVE", "COMMUNE", "tension",
   "Elle ne mange pas ; sa cuiller s'arrete chaque fois que la tourbe soupire dehors.",
   "Elle ne mange pas. Elle s'est assise de biais, face a la porte, et chaque fois que la "
   "tourbe soupire dehors sa cuiller s'arrete a mi-chemin.", [
   O("Manger en silence", "manger", "anciens", "prudente", "volonte", "white", 3,
     R("anciens", 6),
     "Tu manges sans rien demander. Au bout d'un moment elle parle d'elle-meme, du marais, "
     "des planches qu'il faut refaire chaque annee — et jamais de qui les refait.",
     "Tu manges en silence et le silence s'installe pour de bon. Vous finissez le repas "
     "comme deux inconnus dans une salle d'attente."),
   O("Demander qui est attendu", "demander", "niamh", "equilibree", "empathie", "white", 4,
     R("niamh", 8),
     "Tu demandes qui doit venir. Elle repose sa cuiller. « Personne. » Puis, plus bas, "
     "comme pour elle-meme : « Plus personne. »",
     "Tu demandes qui est attendu et la question tombe mal. Elle se leve, va tisonner un "
     "feu eteint depuis longtemps, et te tourne le dos."),
   O("Parler des planches neuves", "questionner", "druides", "audacieuse", "logic",
     "white", 5, R("druides", 10),
     "Tu dis que les planches neuves ne menent pas au bourg mais s'enfoncent dans le "
     "marais. Elle te laisse finir. « On rallonge le chemin quand la tourbe monte », "
     "dit-elle, et ce n'est pas une reponse.",
     "Tu parles des planches et tu vas trop loin, jusqu'a dire que quelqu'un les "
     "entretient. Elle souffle la moitie des chandelles avant de repondre, et ne repond "
     "pas.")]),

 C(10, "MERLIN_DIRECT", "EPIQUE", "peur",
    "Merlin parle depuis le feu eteint : « Deux assiettes, voyageur. Compte-les encore. »",
    "Elle se leve de table sans avoir vide sa cuiller. L'assiette pleine reste ou elle "
    "est. Dans le feu eteint, une voix que tu es seul a entendre : « Deux assiettes, "
    "voyageur. Compte-les encore. »", [
    O("Lui demander ce qu'il sait", "demander", "druides", "prudente", "logic", "white", 4,
      R("druides", 9),
      "« Ce que tu sais deja », repond Merlin. « Une table mise pour deux dans une maison "
      "ou l'on vient de te dire qu'il n'y a personne d'autre. Je ne t'apprends rien. Je "
      "t'empeche de l'oublier. »",
      "Tu poses ta question et le feu eteint ne repond plus. Tu restes un long moment a "
      "parler a des cendres, jusqu'a ce que tu t'entendes le faire.",
      variantes=[{"si_marqueur": "deux_assiettes",
                  "texte": "« Tu as compte avant moi », dit Merlin. « Servie ce soir, "
                           "jamais touchee, jamais desservie. Tu sais deja. Tu attends "
                           "seulement que quelqu'un le dise a voix haute pour ne pas avoir "
                           "a le faire toi-meme. »"}]),
    O("Lui dire de se taire", "refuser", "anciens", "equilibree", "volonte", "contextuel", 8,
      R("anciens", 11),
      "Tu lui dis de se taire. Il se tait — et le silence qu'il laisse est pire que ce "
      "qu'il allait dire, parce qu'il te laisse le remplir tout seul.",
      "Tu lui ordonnes le silence et il rit d'abord, longtemps. Quand il se tait enfin, tu "
      "n'entends plus que ta propre respiration, trop rapide."),
    O("Demander qui est mort ici", "questionner", "ankou", "audacieuse", "instinct",
      "contextuel", 9, R("ankou", 13),
      "« Personne », dit Merlin, et il laisse le mot s'installer dans la piece. « C'est "
      "exactement le probleme. »",
      "Tu demandes qui est mort ici et la question reste ouverte trop longtemps. Quelque "
      "chose, dans la piece, s'interesse a toi.")]),

 # ───────────────────────── ACTE III — la nuit et la lueur ────────────────
 C(11, "EVENT", "COMMUNE", "tension",
    "Au milieu de la nuit, trois oiseaux se levent de la meme touffe sans qu'un bruit les leve.",
    "La voix s'est tue avec les cendres. Tu dors mal sur le banc. Vers le milieu de la "
    "nuit, trois oiseaux se levent de la meme touffe de bruyere, sans qu'aucun bruit ne "
    "les ait leves.", [
    O("Ne pas bouger", "attendre", "anciens", "prudente", "volonte", "white", 3,
      R("anciens", 6),
      "Tu restes couche, les yeux ouverts. Les oiseaux se reposent plus loin. Entre les "
      "deux, quelque chose a traverse la bruyere sans faire un bruit.",
      "Tu restes couche et le sommeil te reprend malgre toi. Quand tu rouvres les yeux, la "
      "barre de la porte est retiree et posee contre le mur."),
    O("Ecouter a la porte", "ecouter", "korrigans", "equilibree", "instinct", "white", 4,
      R("korrigans", 8),
      "Tu colles l'oreille au bois. Pas de pas, pas de voix : un raclement regulier, comme "
      "une planche qu'on deplace, tres loin sur la tourbe.",
      "Tu te leves pour ecouter et le banc grince sous toi. Au fond de la piece, la "
      "respiration de la femme change de rythme : elle ne dormait pas."),
    O("Regarder par la fenetre", "observer", "druides", "audacieuse", "logic", "white", 5,
      R("druides", 10),
      "Par la vitre, la tourbe est noire jusqu'a l'horizon. Sauf a un endroit, ou une lueur "
      "basse avance a hauteur d'homme, du meme pas qu'un homme.",
      "Tu te penches a la fenetre et ton souffle la couvre de buee. Le temps que tu "
      "l'essuies, il n'y a plus rien a voir que ta propre main.")]),

 C(12, "NARRATIVE", "COMMUNE", "peur",
    "La lueur suit les planches et s'arrete ou elles s'arretent : elle connait le chemin.",
    "La lueur ne va pas droit. Elle suit les planches, s'arrete ou elles s'arretent, "
    "repart. Ce qui la porte connait le chemin par coeur.", [
    O("Compter les arrets", "compter", "druides", "prudente", "logic", "white", 3,
      R("druides", 6),
      "Tu comptes. Sept arrets au meme intervalle : c'est un homme qui sonde devant lui "
      "avant de poser le pied. Personne ne sonde un chemin qu'il ne compte pas reprendre.",
      "Tu comptes et tu perds le fil deux fois. Quand tu recommences, la lueur a change "
      "d'axe et tes chiffres ne veulent plus rien dire."),
    O("Reveiller la femme", "reveiller", "niamh", "equilibree", "empathie", "white", 4,
      R("niamh", 8),
      "Tu la touches a l'epaule. Elle est deja reveillee, assise dans le noir, et elle "
      "regardait la meme chose que toi depuis un moment.",
      "Tu la reveilles et elle sursaute si fort que la lampe tombe. Le temps de la "
      "ramasser, la lueur dehors s'est eteinte d'un coup."),
    O("Sortir sur le seuil", "sortir", "korrigans", "audacieuse", "instinct", "white", 5,
      R("korrigans", 10),
      "Tu ouvres d'un doigt et sors sur la pierre froide. L'odeur de pain brule est ici "
      "beaucoup plus forte que dans la maison, et elle vient de la lueur.",
      "Tu sors et le vent rabat la porte derriere toi. Tu restes dehors, pieds nus sur la "
      "pierre gelee, a gratter le bois pour qu'on te rouvre.")]),

 C(13, "NARRATIVE", "COMMUNE", "tension",
    "Elle souffle la lampe, te prend le poignet et te fait signe de ne plus bouger.",
    "Elle est derriere toi, pieds nus sur le plancher. Elle souffle la lampe sans un mot, "
    "te prend le poignet, et te fait signe de ne plus bouger tant que la lueur est dehors.", [
    O("Obeir", "obeir", "anciens", "prudente", "volonte", "white", 4,
      R("anciens", 8),
      "Tu ne bouges plus. La lueur passe a cent pas, ralentit devant la maison, et repart "
      "vers le marais. Sa main ne lache ton poignet qu'apres.",
      "Tu obeis mais ton pied glisse sur la pierre et racle. Dehors, la lueur s'arrete net "
      "et reste arretee tres longtemps."),
    O("Chercher son regard", "chercher", "niamh", "equilibree", "empathie", "contextuel", 8,
      R("niamh", 11),
      "Tu tournes la tete vers elle dans le noir. Elle ne te regarde pas : elle regarde la "
      "lueur, et son visage n'a pas peur. Il attend.",
      "Tu cherches son regard et elle detourne la tete si vite que la barre de la porte "
      "cogne. Dehors, quelque chose repond par un raclement."),
    O("Degager ton poignet", "degager", "korrigans", "audacieuse", "instinct", "contextuel",
      9, R("korrigans", 13),
      "Tu retires ta main et fais un pas vers la porte. Elle ne te retient pas deux fois — "
      "mais elle dit, tout bas : « Si vous sortez maintenant, il ne reviendra plus. » Elle "
      "a dit « il ».",
      "Tu te degages trop brusquement et elle recule dans le noir. Vous restez chacun d'un "
      "cote de la piece jusqu'au jour, sans un mot de plus.")]),

 C(14, "NARRATIVE", "COMMUNE", "curiosite",
    "Elle rallume la lampe : « Un feu follet. Il y en a beaucoup, ici. »",
    "La lueur s'est perdue vers le marais. Elle rallume la lampe, les mains lentes. « Un "
    "feu follet », dit-elle. « Il y en a beaucoup, ici. »", [
    O("Accepter l'explication", "acquiescer", "anciens", "prudente", "volonte", "white", 3,
      R("anciens", 6),
      "Tu dis que oui, sans doute, des feux follets. Elle te remercie d'un regard pour ne "
      "pas avoir insiste, et te rend la couverture que tu avais laissee tomber.",
      "Tu dis que oui, des feux follets, et ca sonne faux dans ta propre bouche. Elle "
      "l'entend, et la politesse retombe entre vous comme un volet."),
    O("Dire qu'un feu follet ne sonde pas", "contredire", "druides", "equilibree", "logic",
      "white", 4, R("druides", 8),
      "Tu dis qu'un feu follet ne s'arrete pas sept fois au meme intervalle. Elle ne se "
      "defend pas. Elle repose la lampe et regarde le plancher un long moment.",
      "Tu la contredis trop vite et trop bien. Elle se ferme d'un coup : « Vous etes "
      "savant, pour un homme qui dort sur mon banc. »"),
    O("Proposer de rester un jour", "offrir", "niamh", "audacieuse", "empathie", "white", 5,
      R("niamh", 10),
      "Tu dis que tu peux rester un jour de plus, si ca aide. Elle refuse de la tete — mais "
      "elle met une buche dans le feu eteint, la premiere depuis que tu es entre.",
      "Tu proposes de rester et l'offre tombe comme une pitie. Elle repond qu'elle n'a "
      "besoin de personne, et cette fois assez fort pour que ca s'entende dehors.")]),

 C(15, "NARRATIVE", "RARE", "fascination",
    "Au petit jour elle dort assise, la barre retiree, et les planches neuves partent vers le marais.",
    "Au petit jour elle dort assise, la lampe encore allumee contre elle. La barre de la "
    "porte est retiree. Dehors, les planches neuves partent vers le marais.", [
    O("Remettre la barre et attendre", "attendre", "niamh", "prudente", "empathie",
      "white", 3, R("niamh", 6),
      "Tu remets la barre et tu te rassieds. Le jour se leve sur une maison ou personne "
      "n'est entre — et ou l'assiette pleine est toujours a sa place.",
      "Tu remets la barre et le bois claque. Elle se reveille en sursaut, voit ta main sur "
      "la porte, et il te faut longtemps pour expliquer ce que tu faisais."),
    O("Suivre les planches neuves", "suivre", "druides", "equilibree", "logic", "white", 4,
      R("druides", 8),
      "Tu sors sans la reveiller. Les planches neuves sont larges d'un pied, posees droit, "
      "et elles s'enfoncent la ou aucun chemin n'a de raison d'aller.",
      "Tu sors et la porte grince sur toute sa longueur. Tu t'engages quand meme sur les "
      "planches, en sachant qu'elle t'a entendu partir."),
    O("Emporter l'assiette pleine", "emporter", "ankou", "audacieuse", "instinct", "white", 5,
      R("ankou", 10),
      "Tu emportes l'assiette froide, couverte d'un linge. Tu ne saurais pas dire pourquoi, "
      "sinon qu'on ne laisse pas un repas servi a personne.",
      "Tu prends l'assiette et le linge accroche la table ; le plat se renverse sur le banc "
      "ou tu as dormi. Tu pars en laissant ca derriere toi.")]),

 # ───────────────────────── ACTE IV — la fosse ────────────────────────────
 C(16, "NARRATIVE", "COMMUNE", "curiosite",
    "Les planches se divisent : une branche grise vers le bourg, une neuve vers le marais.",
    "A deux cents pas de la maison, les planches se divisent. Une branche va vers le bourg, "
    "grise et usee. L'autre est neuve, et elle entre dans le marais.", [
    O("Prendre la branche du bourg", "prendre", "anciens", "prudente", "volonte", "white", 4,
      R("anciens", 8),
      "Tu prends le chemin gris. Il monte, il seche, il te sort de la tourbe — et au "
      "premier tournant tu t'arretes, parce que de la-haut on voit ou mene l'autre.",
      "Tu prends le chemin du bourg et la brume se referme derriere toi. Tu marches "
      "longtemps avant de comprendre que tu t'es trompe de branche."),
    O("Sonder la branche neuve", "sonder", "druides", "equilibree", "logic", "contextuel", 8,
      R("druides", 16),
      "Tu enfonces ton baton entre deux planches neuves. Il descend d'une brasse et butte "
      "sur du bois : on a double le fond. Ce chemin a ete construit pour porter quelqu'un "
      "tous les jours.",
      "Tu sondes et le baton te reste dans la tourbe. Tu te retrouves sur les planches "
      "neuves, sans rien pour sonder, a plus d'une lieue de la maison."),
    O("Prendre la branche neuve", "avancer", "korrigans", "audacieuse", "instinct",
      "contextuel", 9, R("korrigans", 17),
      "Tu t'engages sur le bois clair. Il ne bouge pas d'un pouce sous ton poids : "
      "quelqu'un l'entretient, et pas depuis hier.",
      "Tu t'engages et la troisieme planche bascule. Tu passes a travers jusqu'a la "
      "ceinture et tu ressors couvert d'une tourbe qui sent le pain brule.")]),

 C(17, "NARRATIVE", "COMMUNE", "tension",
    "La branche neuve s'arrete sur une fosse ; une planche unique est jetee en travers.",
    "La branche neuve s'arrete net sur une fosse. Une planche unique est jetee en travers, "
    "et sous elle l'eau noire ne bouge pas du tout.", [
    O("Sonder la fosse", "sonder", "druides", "prudente", "logic", "white", 4,
      R("druides", 9),
      "Tu enfonces ton baton dans l'eau noire. Il descend, puis butte sur quelque chose qui "
      "n'est ni pierre ni racine : quelque chose qui cede un peu, puis resiste. Tu ne "
      "recommences pas.",
      "Tu sondes et l'eau se referme sur le baton comme une bouche. Tu le laches avant "
      "qu'elle te prenne le bras avec."),
    O("Traverser sur la planche", "traverser", "anciens", "equilibree", "volonte",
      "contextuel", 8, R("anciens", 12),
      "Tu passes en trois enjambees. La planche plie au milieu et tient. De l'autre cote, "
      "la berge a ete creusee de main d'homme, en marches.",
      "Tu passes et la planche tourne sous ton pied. Tu te rattrapes a plat ventre, les "
      "jambes dans l'eau noire, et il te faut longtemps pour ressortir."),
    O("Retirer la planche", "retirer", "ankou", "audacieuse", "instinct", "contextuel", 9,
      R("ankou", 13),
      "Tu tires la planche et la poses dans la bruyere. Celui qui traverse ici ne "
      "traversera plus — et toi non plus, mais tu sauras qui vient la chercher.",
      "Tu tires la planche et elle t'echappe dans la fosse. L'eau la reprend sans un "
      "bruit, et tu restes du mauvais cote.")]),

 C(18, "EVENT", "COMMUNE", "peur",
    "Sous la berge creusee, l'odeur change : ce n'est plus la tourbe, c'est de la fumee recente.",
    "De l'autre cote, sous la berge creusee, l'odeur monte d'un coup. Ce n'est plus le pain "
    "brule de la tourbe : c'est de la fumee, et elle est recente.", [
    O("Reculer et regarder", "reculer", "anciens", "prudente", "volonte", "white", 4,
      R("anciens", 10),
      "Tu recules de trois pas et tu regardes au lieu d'avancer. Sous la berge, la tourbe a "
      "ete creusee en abri, et un filet de fumee sort d'un trou d'aeration bouche de mousse.",
      "Tu recules mal et le talus cede sous ton talon. Tu descends la berge sur le dos, en "
      "raclant tout ce qui depasse."),
    O("Chercher le trou de fumee", "chercher", "druides", "equilibree", "logic",
      "contextuel", 8, R("druides", 12),
      "Tu suis le fil de fumee a contre-vent, la main devant. Il sort d'entre deux racines. "
      "En dessous il y a du vide, et dans le vide quelque chose respire.",
      "Tu cherches le trou et tu mets la main dans les braises couvertes de mousse. La "
      "brulure te fait crier, et le cri porte loin sur la tourbe."),
    O("Ouvrir l'abri", "ouvrir", "ankou", "audacieuse", "instinct", "red", 13,
      R("ankou", 16, ESS(4)),
      "Tu arraches la mousse a deux mains et le toit de l'abri cede. En dessous : de la "
      "paille seche, un quart de fer, une couverture — et deux yeux qui te regardent depuis "
      "le fond.",
      "Tu arraches la mousse et tout le toit s'effondre avec toi dedans. Tu tombes dans le "
      "noir, sur de la paille et sur quelqu'un, et une main te trouve la gorge avant que tu "
      "voies quoi que ce soit.", telegraphie=True)]),

 C(19, "NARRATIVE", "RARE", "fascination",
    "Sous la berge : de la paille seche, un quart de fer, une couverture pliee.",
    "Une place a ete amenagee sous la berge : de la paille seche, un quart de fer, une "
    "couverture pliee. Quelqu'un vit ici depuis longtemps, et pas si mal.", [
    O("Annoncer ta presence", "annoncer", "niamh", "prudente", "empathie", "white", 3,
      R("niamh", 6),
      "Tu dis a voix haute que tu es un voyageur et que tu ne viens rien prendre. Au fond de "
      "l'abri, la respiration ralentit sans s'arreter.",
      "Tu parles et ta voix resonne mal sous la berge. Au fond, la respiration s'arrete net "
      "et ne reprend pas tant que tu es la."),
    O("Regarder ce qu'il y a", "examiner", "druides", "equilibree", "logic", "white", 4,
      R("druides", 8),
      "Un quart de fer grave d'une marque, une couverture reprisee au meme fil que celle du "
      "banc ou tu as dormi. On ne survit pas ici : on est nourri ici.",
      "Tu fouilles trop vite et renverses le quart. L'eau se repand sur la paille seche, et "
      "tout ce qui restait de sec ne l'est plus."),
    O("Entrer dans l'abri", "entrer", "korrigans", "audacieuse", "instinct", "white", 5,
      R("korrigans", 10),
      "Tu te glisses sous la berge. Il fait chaud, ca sent l'homme et la fumee, et il y a "
      "quelqu'un assis contre la paroi qui ne bouge pas plus qu'une pierre.",
      "Tu te glisses sous la berge et l'entree se referme sur tes epaules. Tu recules a "
      "plat ventre, la tourbe dans la bouche, sans avoir rien vu.")]),

 C(20, "PROMISE", "EPIQUE", "tension",
    "L'homme est vivant et demande trois jours de silence a un inconnu.",
    "L'homme est vivant, maigre, et il ne te connait pas plus que tu ne le connais. « Ne "
    "dites pas que vous m'avez vu », souffle-t-il. « Trois jours. »", [
    O("Jurer les trois jours", "jurer", "anciens", "prudente", "volonte", "white", 4,
      [PROM("trois_jours", 3, "Taire qu'un homme vit sous la berge"),
       {"type": "ADD_REPUTATION", "faction": "anciens", "amount": 8}],
      "Tu jures, et il te fait repeter avec ses mots a lui. La tourbe n'a pas d'oreilles, "
      "mais les Anciens en ont, et un serment prononce dessus ne s'efface pas.",
      "Tu jures d'une voix plate, sans ses mots. Il te fait recommencer trois fois et n'y "
      "croit toujours pas : le serment tient, mais mal."),
    O("Promettre de revenir", "promettre", "niamh", "equilibree", "empathie", "white", 4,
      [PROM("revenir", 5, "Revenir le chercher"),
       {"type": "ADD_REPUTATION", "faction": "niamh", "amount": 10}],
      "Tu ne promets pas le silence : tu promets de revenir. Ce n'est pas la meme chose et "
      "il le sait. Il accepte quand meme, parce qu'un homme dans un trou accepte ce qu'on "
      "lui donne.",
      "Tu promets de revenir et tu entends toi-meme que ca sonne faux. Il detourne les yeux, "
      "accepte, et vous savez tous les deux ce que ca vaut."),
    O("Ne rien jurer", "refuser", "korrigans", "audacieuse", "instinct", "white", 5,
      R("korrigans", 12),
      "Tu refuses de jurer quoi que ce soit. Il hoche la tete lentement : « Alors vous etes "
      "honnete, ou vous etes dangereux. » Il ne te tourne pas le dos en te laissant partir.",
      "Tu refuses trop sechement. Il recule au fond de l'abri, ramene la couverture sur "
      "lui, et ne dit plus un mot quoi que tu fasses.")]),

 # ───────────────────────── ACTE V — le retour ────────────────────────────
 C(21, "SHOP", "RARE", "peur",
    "Sur le chemin gris, un homme du bourg sourit et sent la fumee sans avoir marche dans la tourbe.",
    "Sur le chemin gris du retour, un homme du bourg vient a ta rencontre. Il sourit. Il "
    "sent le pain brule alors qu'il n'a pas mis un pied dans la tourbe.", [
    O("Accepter les piecettes", "accepter", "druides", "prudente", "logic", "white", 3,
      [ESS(4)],
      "Tu prends les deux pieces et les fais disparaitre. Il a l'air content, et il continue "
      "a marcher a cote de toi comme si l'affaire etait conclue.",
      "Tu prends les pieces et l'une t'echappe dans la tourbe. Vous la cherchez a deux, "
      "tetes baissees, et il en profite pour regarder ce que tu portes."),
    O("Refuser les pieces", "refuser", "anciens", "equilibree", "volonte", "white", 4,
      R("anciens", 10),
      "Tu lui rends les piecettes sans les compter. Son sourire ne bouge pas, mais son pas "
      "ralentit : il vient d'apprendre qu'il faudra payer plus cher.",
      "Tu refuses d'un geste trop large et l'une des pieces tombe entre les planches. Il ne "
      "se baisse pas. « Elle est a vous maintenant », dit-il."),
    O("Lui demander son nom", "questionner", "niamh", "audacieuse", "empathie", "white", 5,
      R("niamh", 12, TAG("le_frere")),
      "Tu demandes son nom. « Kerlan », dit-il, et il ajoute sans qu'on lui demande : "
      "« Comme le noye. C'etait mon frere. » Il dit « etait » avec beaucoup de soin.",
      "Tu demandes son nom et il te retourne la question avant de repondre. Tu donnes le "
      "tien le premier, et le sien n'arrive jamais.")]),

 C(22, "NARRATIVE", "COMMUNE", "tension",
    "Il barre le chemin, poliment : « Qu'est-ce qu'on trouve au marais, en cette saison ? »",
    "Il s'arrete au milieu du chemin et ne s'ecarte pas. « Vous venez du marais », dit-il, "
    "toujours poliment. « Qu'est-ce qu'on y trouve, en cette saison ? »", [
    O("Mentir simplement", "mentir", "korrigans", "prudente", "instinct", "white", 4,
      R("korrigans", 10),
      "Tu dis que tu cherchais un raccourci et que tu as trouve de la tourbe. C'est court, "
      "c'est plat, et c'est exactement ce qu'un voyageur repondrait. Il te croit a moitie, "
      "ce qui suffit.",
      "Tu mens trop bien et trop longtemps. A la troisieme phrase il cesse de sourire, "
      "parce que personne n'invente autant pour un raccourci."),
    O("Retourner la question", "retourner", "druides", "equilibree", "logic", "contextuel",
      8, R("druides", 12),
      "Tu lui demandes ce que lui y cherche, puisqu'il sent la fumee sans y etre alle. Il ne "
      "repond pas — mais il s'ecarte du chemin d'un demi-pas.",
      "Tu retournes la question et il la laisse tomber entre vous. « Je vis ici », dit-il. "
      "« Pas vous. » Et il ne s'ecarte toujours pas."),
    O("Lui dire que son frere respire", "reveler", "ankou", "audacieuse", "volonte", "red",
      13, R("ankou", 16, ESS(4)),
      "Tu le dis en le regardant. Son visage ne bouge pas d'un trait — et c'est ca qui te "
      "renseigne : il le savait deja, et il attendait seulement de savoir si toi tu le "
      "savais.",
      "Tu commences la phrase et elle sort de travers, a moitie. Il comprend l'autre moitie "
      "tout seul, sourit enfin franchement, et prend le chemin du marais sans te saluer.",
      telegraphie=True)]),

 C(23, "NARRATIVE", "COMMUNE", "curiosite",
    "Elle t'attend debout sur le seuil, la porte ouverte derriere elle.",
    "Tu le laisses sur le chemin gris. La maison basse est au bout des planches, et elle "
    "t'attend debout sur le seuil, la porte ouverte derriere elle. Elle a vu d'ou tu "
    "reviens.", [
    O("La saluer et rentrer", "saluer", "anciens", "prudente", "volonte", "white", 3,
      R("anciens", 6),
      "Tu la salues comme le premier soir et tu passes le linteau. Elle referme, met la "
      "barre, et cette fois ne la verifie pas deux fois.",
      "Tu la salues et elle ne repond pas. Tu passes devant elle et la porte reste ouverte "
      "derriere toi, sur la tourbe et sur le froid."),
    O("Regarder la table avant de parler", "examiner", "druides", "equilibree", "logic",
      "white", 4, R("druides", 8),
      "Tu entres et tu regardes la table avant elle. Il y a deux assiettes. L'une est "
      "pleine. Elle a ete servie ce matin.",
      "Tu regardes la table trop ouvertement et elle te devance. Le temps que tu te "
      "retournes, l'assiette est dans le seau et la table est mise pour un."),
    O("Dire tout de suite ou tu es alle", "avouer", "niamh", "audacieuse", "empathie",
      "white", 5, R("niamh", 10),
      "Tu le dis avant qu'elle demande : la branche neuve, la fosse, la berge. Elle ne "
      "t'interrompt pas. A la fin elle s'assied, pour la premiere fois depuis que tu es "
      "entre dans cette maison.",
      "Tu commences a raconter et tu prends le probleme par le mauvais bout. A « la berge "
      "creusee », elle leve la main et te dit de ne pas continuer sur le seuil.")]),

 C(24, "NARRATIVE", "COMMUNE", "tension",
    "Les mains a plat entre les deux assiettes, elle demande : « Alors ? »",
    "Elle a pose les mains a plat sur la table, entre les deux assiettes, et elle attend. "
    "« Alors ? » demande-t-elle, et sa voix ne tremble pas.", [
    O("Ne rien dire", "taire", "ankou", "prudente", "instinct", "white", 4,
      R("ankou", 9),
      "Tu ne dis rien. Elle attend longtemps, puis retire ses mains de la table. « C'est "
      "bien », dit-elle, et tu ne sauras jamais ce qu'elle a compris.",
      "Tu ne dis rien et le silence dure trop. Elle finit par le remplir a ta place, avec ce "
      "qu'elle craint le plus, et tu ne peux plus la detromper."),
    O("Parler de l'homme du bourg", "avertir", "druides", "equilibree", "logic",
      "contextuel", 8, R("druides", 12),
      "Tu ne parles pas de la fosse. Tu parles de celui qui sent la fumee sans avoir marche "
      "dans la tourbe. Elle blemit — non pas de surprise, mais parce que quelqu'un d'autre "
      "le sait enfin.",
      "Tu t'embrouilles entre ce que tu as vu et ce que tu as deduit. Elle n'entend qu'une "
      "accusation sans preuve contre un homme du bourg, et se leve pour ouvrir la porte."),
    O("Tout lui dire", "avouer", "niamh", "audacieuse", "empathie", "contextuel", 9,
      R("niamh", 14),
      "Tu dis tout : la berge, la paille, l'homme vivant. Elle ne pleure pas. Elle calcule, "
      "a voix haute et sans s'en apercevoir, combien de matins elle a servi une assiette a "
      "quelqu'un qu'elle disait mort.",
      "Tu dis tout dans le desordre et le pire arrive en premier. Elle n'entend que "
      "l'annee de mensonge, s'assied, et ne te repond plus du tout.")]),

 C(25, "MERLIN_DIRECT", "LEGENDAIRE", "sagesse",
    "Merlin attend sur la borne, la ou le marais rend le pied ferme.",
    "Au bout des planches grises, la ou le marais rend enfin le pied ferme, une borne. "
    "Merlin est assis dessus. « Tu es entre dans cette maison pour une nuit », dit-il.", [
    O("Reprendre la route", "partir", "anciens", "prudente", "volonte", "white", 4,
      R("anciens", 12, ANAM(4)),
      "Tu passes sans t'arreter. « Un toit pour une nuit », dit-il dans ton dos. « Et tu "
      "repars en devant quelque chose a des gens que tu ne connaissais pas hier. C'est "
      "ainsi que ca commence, voyageur. »",
      "Tu passes trop vite et il ne dit rien du tout. C'est le silence de Merlin qui te suit "
      "sur la route, et il pese plus lourd que ses mots."),
    O("Lui demander ce que tu dois", "demander", "druides", "equilibree", "logic", "white", 5,
      R("druides", 13, ANAM(5)),
      "« Rien qu'on puisse payer », repond Merlin. « Tu as vu une chose que deux personnes "
      "voulaient garder, et chacune pour proteger l'autre. Tu ne dois pas d'argent. Tu dois "
      "de te taire ou de parler, et les deux coutent. »",
      "Tu poses la question et elle sort mal, comme une plainte. Merlin te laisse l'entendre "
      "resonner, puis change de sujet et parle du temps qu'il fera demain.",
      variantes=[{"si_promesse_rompue": "trois_jours",
                  "texte": "Merlin t'arrete a mi-phrase. « Tu as jure trois jours et tu n'en "
                           "as pas tenu un. Ce que tu dois maintenant n'est plus a eux : "
                           "c'est a ta propre parole, et celle-la se paie toujours au "
                           "comptant. »"}]),
    O("Faire demi-tour", "retourner", "ankou", "audacieuse", "instinct", "white", 5,
      R("ankou", 15, ANAM(5)),
      "Tu ne reponds pas et tu reprends le chemin du marais. Merlin ne te retient pas ; il "
      "te regarde repartir vers les planches neuves et murmure, pour lui seul : « Celui-la "
      "finira par comprendre pourquoi il est entre. »",
      "Tu fais demi-tour et tes jambes ne suivent pas : la tourbe t'a pris quelque chose que "
      "tu n'avais pas compte. Tu t'assieds sur la borne, a cote de lui, sans un mot.",
      variantes=[{"si_marqueur": "bottes_seches",
                  "texte": "Tu fais demi-tour. « Les bottes seches », dit Merlin derriere "
                           "toi. « Tu l'as su des le seuil, avant meme qu'on t'ouvre. Tu es "
                           "entre en le sachant. C'est pour ca que tu y retournes. »"}])]),
]


# Taux de conversion bible §30 : tout effet se ramene a une unite commune, le
# PV-equivalent, pour comparer trois options entre elles.
PV_EQ = {"HEAL_LIFE": 1.0, "DAMAGE_LIFE": -1.0, "ADD_REPUTATION": 0.4,
         "ADD_ESSENCE": 0.8, "ADD_ANAM": 2.0}
P_SUCCES = 0.6  # stat 1 au premier run : 50% + 10% × stat (bible §26.1)


def acte(n: int, total: int) -> int:
    return min(1 + (n - 1) * 5 // total, 5)


def ev(option: dict) -> float:
    """Espérance d'une option bâtie, en PV-équivalent, au premier run (stat 1)."""
    gain = sum(PV_EQ.get(e["type"], 0.0) * e.get("amount", 0) for e in option["effects"])
    return P_SUCCES * gain - (1 - P_SUCCES) * option["check"]["fail_damage"]


def build() -> dict:
    cards = []
    for c in CARTES:
        n = c["n"]
        opts = []
        for o in c["options"]:
            opt = {
                "label": o["label"], "verb": o["verb"],
                "gradient": o["gradient"], "primary_faction": o["faction"],
                "check": {"stat": o["stat"], "type": o["check"],
                          "fail_damage": o["fail_damage"],
                          "telegraphed": o.get("telegraphie", o["check"] in ("red", "fatal"))},
                "effects": o["effects"],
                "outcome": o["outcome"],
                "outcome_fail": o["outcome_fail"],
            }
            if o.get("variantes"):
                opt["outcome_variants"] = o["variantes"]
            opts.append(opt)
        cards.append({
            "n": n, "card_id": f"c{n}", "act": acte(n, LONGUEUR),
            "type": c["type"], "rarity": c["rarity"], "emotion": c["emotion"],
            # `text` est ce que le joueur lit a l'ecran (champ lu par
            # board_narration.gd) ; `summary` est l'identite courte du beat,
            # celle que manipulent le skeleton, le RAG et le validateur.
            "text": c["situation"], "summary": c["resume"], "options": opts,
        })
    return {
        "id": "type_broc_tourbe_25", "title": TITRE,
        "archetype_id": ARCHETYPE, "archetype_name": "Le Vagabond de Brume",
        "pole_dominant": "Liminal", "twist_pattern": "lost_then_found",
        "biome": "marais_korrigans", "length": LONGUEUR, "pool_size": len(cards),
        "graine_de_variation": GRAINE,
        "emotional_arc": [c["emotion"] for c in CARTES],
        "intro": INTRO, "essence": ESSENCE, "hook": HOOK,
        "twist_card_id": "c20", "cards": cards,
        "branchement": "narratif — sequence unique, resolutions variables selon l'etat",
        "continuite": "aucune ellipse : chaque carte reprend ou la precedente s'est arretee "
                      "(bible §33.2)",
    }


def render_markdown(s: dict) -> str:
    from collections import Counter
    L = [f"# ᚛ {s['title']} ᚜", ""]
    L.append(f"> **Scénario type de référence — canon bible v4.2.** Archétype "
             f"`{s['archetype_id']}` · pôle {s['pole_dominant']} · twist "
             f"`{s['twist_pattern']}` · **{s['length']} cartes** · branchement narratif.")
    L.append(">")
    L.append("> Écrit à la main : c'est la **cible** que la génération LLM doit atteindre, "
             "pas un échantillon de ce qu'elle produit. Jamais injecté comme modèle de contenu.")
    L.append(">")
    L.append("> **Le voyageur ne connaît personne** (§33.1) : aucune dette antérieure, aucun "
             "nom su d'avance. Il cherche un toit pour la nuit, et tout ce qu'il apprend, il "
             "l'apprend ici. **Aucune ellipse** (§33.2) : on approche, on frappe, on attend, "
             "on ouvre, on parle, on entre, on s'assied.")
    L.append("")
    L.append("## La graine qui l'a produit")
    L.append("")
    L.append("Ce sont les cinq contraintes tirées avant génération. Elles seules garantissent "
             "qu'aucun scénario ne ressemble au précédent. La *dette à honorer* appartient aux "
             "gens rencontrés — jamais au voyageur.")
    L.append("")
    for k, v in s["graine_de_variation"].items():
        L.append(f"- **{k.replace('_', ' ')}** — {v}")
    L.append("")
    L.append(f"*{s['essence']}*")
    L.append("")
    L.append("## Accroche")
    L.append("")
    L.append(f"> {s['hook']}")
    L.append("")
    L.append("## Intro (parchemin d'ouverture)")
    L.append("")
    L.append(s["intro"])
    L.append("")

    L.append("## Structure")
    L.append("")
    L.append("| Acte | Rôle | Cartes | Types | Ce qui s'y passe |")
    L.append("|---|---|---|---|---|")
    roles = ["ouverture", "pacte", "épreuve", "bascule", "climax"]
    resumes = ["le chemin, la maison, le seuil, l'attente, la porte qui s'ouvre",
               "entrer, s'asseoir, le coffre, le repas, Merlin compte les assiettes",
               "la nuit, la lueur qui sonde, la lampe soufflée, le petit jour",
               "les planches se divisent, la fosse, la fumée, l'abri, le serment",
               "l'homme du bourg, le chemin barré, le retour, la question, la borne"]
    for a in range(1, 6):
        cs = [c for c in s["cards"] if c["act"] == a]
        if not cs:
            continue
        L.append(f"| {a} | {roles[a-1]} | {cs[0]['n']}–{cs[-1]['n']} | "
                 f"{', '.join(f'{n}×{t}' for t, n in Counter(c['type'] for c in cs).most_common())} | "
                 f"{resumes[a-1]} |")
    L.append("")

    L.append("## Lecture d'équilibrage")
    L.append("")
    L.append("Chaque effet est converti en **PV-équivalent** (vie 1.0 · essence 0.8 · "
             "réputation 0.4/pt · Anam 2.0), puis pondéré par la chance de réussite du "
             "premier run — 60 % à stat 1. L'écart entre les trois options doit rester "
             "**sous 2.0 PV-eq** : c'est ce qui empêche une ligne de jeu d'être "
             "mécaniquement supérieure aux deux autres.")
    L.append("")
    L.append("| Carte | Acte | Épreuve de la carte | EV prudente | EV équilibrée | "
             "EV audacieuse | Écart |")
    L.append("|---|:---:|---|---:|---:|---:|---:|")
    dur = {"white": 0, "contextuel": 1, "red": 2, "fatal": 3}
    for c in s["cards"]:
        evs = [ev(o) for o in c["options"]]
        pire = max((o["check"]["type"] for o in c["options"]), key=lambda t: dur[t])
        marque = {"white": "blanche", "contextuel": "**contextuelle**",
                  "red": "**ROUGE** (télégraphiée)", "fatal": "**FATALE**"}[pire]
        L.append(f"| {c['n']}. {c['type']} | {c['act']} | {marque} | "
                 + " | ".join(f"{e:+.2f}" for e in evs)
                 + f" | {max(evs) - min(evs):.2f} |")
    L.append("")
    mix = Counter(max((o["check"]["type"] for o in c["options"]), key=lambda t: dur[t])
                  for c in s["cards"])
    n = len(s["cards"])
    L.append("**Mix d'épreuves** — "
             + " · ".join(f"{k} {v}/{n} ({v / n:.0%})"
                          for k, v in sorted(mix.items(), key=lambda kv: dur[kv[0]]))
             + ". Cible bible §26.2 : 75 / 15 / 8 / 2 %.")
    L.append("")
    L.append("Les `effects` listés sous chaque option sont le **gain en cas de réussite**. "
             "Le coût du risque vit uniquement dans les dégâts d'échec — aucune option ne "
             "facture l'audace deux fois.")
    L.append("")

    L.append("## Le déroulé complet")
    L.append("")
    for c in s["cards"]:
        L.append(f"### Carte {c['n']} — acte {c['act']} · {c['type']} · {c['rarity']} "
                 f"· *{c['emotion']}*")
        L.append("")
        L.append(f"**Situation.** {c['text']}")
        L.append("")
        for o in c["options"]:
            ck = o["check"]
            L.append(f"**{o['label']}** — *{o['gradient']}* · {o['primary_faction']} · "
                     f"épreuve {ck['stat']}/{ck['type']} · échec −{ck['fail_damage']} PV · "
                     f"EV {ev(o):+.2f}"
                     + (" · **télégraphiée**" if ck["type"] in ("red", "fatal") else ""))
            L.append("")
            L.append(f"> **Réussite.** {o['outcome']}")
            L.append("")
            if o.get("outcome_fail"):
                L.append(f"> **Échec.** {o['outcome_fail']}")
                L.append("")
            for v in o.get("outcome_variants", []):
                cond = v.get("si_marqueur") or v.get("si_promesse_rompue") or "?"
                kind = "marqueur" if "si_marqueur" in v else "promesse rompue"
                L.append(f"> **Variante** — si {kind} « {cond} » : {v['texte']}")
                L.append("")
            eff = " · ".join(
                (f"{e.get('faction','')} {e['amount']:+d}" if e["type"] == "ADD_REPUTATION" else
                 f"vie +{e['amount']}" if e["type"] == "HEAL_LIFE" else
                 f"vie −{e['amount']}" if e["type"] == "DAMAGE_LIFE" else
                 f"Anam +{e['amount']}" if e["type"] == "ADD_ANAM" else
                 f"essence +{e['amount']}" if e["type"] == "ADD_ESSENCE" else
                 f"marqueur « {e.get('tag','')} »" if e["type"] == "ADD_TAG" else
                 f"promesse « {e.get('promise_id','')} » sous {e.get('deadline_cards','?')} cartes")
                for e in o["effects"])
            L.append(f"*Effets — désormais visibles au HUD :* {eff}")
            L.append("")
        L.append("")
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=None)
    ap.add_argument("--markdown", default=None)
    args = ap.parse_args()
    s = build()

    from collections import Counter
    print(f"=== {s['title']} — {s['length']} cartes, archétype {s['archetype_id']} ===")
    print(f"  types    : {dict(Counter(c['type'] for c in s['cards']))}")
    print(f"  raretés  : {dict(Counter(c['rarity'] for c in s['cards']))}")
    print(f"  factions : {dict(Counter(o['primary_faction'] for c in s['cards'] for o in c['options']))}")
    print(f"  épreuves : {dict(Counter(o['check']['type'] for c in s['cards'] for o in c['options']))}")
    nres = sum(1 for c in s['cards'] for o in c['options'] if o.get('outcome'))
    nfail = sum(1 for c in s['cards'] for o in c['options'] if o.get('outcome_fail'))
    nvar = sum(len(o.get('outcome_variants', [])) for c in s['cards'] for o in c['options'])
    print(f"  résolutions : {nres}/{sum(len(c['options']) for c in s['cards'])} "
          f"(+{nvar} variantes d'état) · {nfail} résolutions d'échec")

    if args.markdown:
        Path(args.markdown).write_text(render_markdown(s), encoding="utf-8")
        print(f"Rendu lisible : {args.markdown}")
    if args.out:
        Path(args.out).write_text(json.dumps([s], ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"Scénario écrit : {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
