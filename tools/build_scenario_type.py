#!/usr/bin/env python3
"""Scénario type de référence — canon bible v4.0.

Remplace `build_golden_scenario.py`, bâti sur les 3 routes isométriques
abandonnées le 2026-07-26. Ce qu'un scénario type est désormais :

  LONGUEUR VARIABLE    11 / 15 / 17 / 21 / 25 selon l'archétype. Toutes les
                       règles chiffrées se projettent sur N, jamais sur 25.
  LINÉAIRE             une seule séquence de cartes pour tous les joueurs.
  BRANCHEMENT NARRATIF ce sont la résolution et le texte qui varient selon
                       l'état accumulé — pas le chemin.
  GRAMMAIRE COMPLÈTE   chaque carte : situation → 3 choix → résolution de
                       chacun → suite. La résolution est obligatoire et ne
                       contient jamais de chiffre.
  ÉTAT VISIBLE         les 5 réputations sont affichées au joueur.

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
# Tirée par ScenarioVariation : c'est elle qui garantit qu'aucun scénario ne
# ressemble au précédent. Elle est conservée ici pour montrer le lien entre
# la contrainte imposée au LLM et le scénario obtenu.
GRAINE = {
    "lieu": "tourbiere",
    "entite_centrale": "un vivant qu'on croit mort",
    "pression": "une dette a honorer",
    "registre_sensoriel": "odeur",
    "mecanisme_du_twist": "identite (qui est vraiment la)",
}

TITRE = "La Dette de Tourbe"
ARCHETYPE = "mist_wanderer"
LONGUEUR = 11

INTRO = (
    "Il y a un an, Maël Kerlan s'est enfoncé dans la tourbière du Yeun et n'en est pas "
    "ressorti. Tu lui devais trois pièces et une promesse, et on ne laisse pas une dette "
    "à un mort. Sa veuve vit encore au bord du marais, dans une maison qui sent la fumée "
    "froide. Tu marches depuis l'aube avec les pièces cousues dans ta manche. L'odeur te "
    "prévient avant le paysage : la tourbe ne sent pas la vase, elle sent le pain brûlé "
    "et le fer. On dit que le Yeun garde ce qu'il prend et ne le rend jamais entier. Tu "
    "vas apprendre que ce n'est pas tout à fait vrai."
)

HOOK = ("La tourbe ne sent pas la vase : elle sent le pain brûlé, et cette odeur te suit "
        "depuis l'aube.")
ESSENCE = "Tu viens payer ta dette à un noyé, et le noyé respire encore."

# ── Les 11 cartes ─────────────────────────────────────────────────────────
# Chaque option porte : libellé, verbe, faction, gradient, épreuve, effets et
# RÉSOLUTION. Certaines résolutions ont des variantes conditionnées par l'état
# accumulé : c'est le branchement narratif, seul branchement retenu.
#
# Deux règles d'équilibrage tiennent tout le reste ensemble :
#
#   1. Les `effects` sont le GAIN en cas de réussite ; le coût du risque vit
#      exclusivement dans `fail_damage`. Aucune option ne porte de DAMAGE_LIFE
#      dans ses effets — sinon l'audace est facturée deux fois et l'écart d'EV
#      entre les trois options explose.
#   2. Une carte compte pour son épreuve la plus dure (bible §26.2, colonne
#      « % cards »). Sur 11 cartes : 8 blanches, 2 contextuelles (c6, c10),
#      1 rouge (c7, acte III, télégraphiée). Le gradient d'une carte blanche
#      s'exprime par la marche 3/4/5 de dégâts d'échec et un gain croissant.
CARTES = [
 {"n": 1, "type": "NARRATIVE", "rarity": "COMMUNE", "emotion": "curiosite",
  "resume": "Arrivee chez la veuve : des bottes d'homme seches attendent sur le seuil.",
  "situation": "La maison de la veuve fume sans feu. Sur le seuil, une paire de bottes "
               "d'homme, seches, tournees vers la porte comme si quelqu'un venait de rentrer.",
  "options": [
   {"label": "Frapper et attendre", "verb": "frapper", "faction": "anciens",
    "gradient": "prudente", "stat": "volonte", "check": "white", "fail_damage": 3,
    "effects": [{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 6}],
    "outcome": "Tu frappes trois coups et le silence dure assez pour que tu comptes tes "
               "battements. La porte s'ouvre sur une femme qui n'a pas l'air surprise. "
               "« Tu es en retard d'un an », dit-elle sans reproche."},
   {"label": "Examiner les bottes", "verb": "examiner", "faction": "druides",
    "gradient": "equilibree", "stat": "logic", "check": "white", "fail_damage": 4,
    "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 8},
                {"type": "ADD_TAG", "tag": "bottes_seches"}],
    "outcome": "Le cuir est sec et la semelle propre. La tourbe ne pardonne pas : personne "
               "n'a marche dans le marais avec ces bottes. Elles ont ete posees la pour "
               "etre vues."},
   {"label": "Entrer sans annoncer", "verb": "entrer", "faction": "korrigans",
    "gradient": "audacieuse", "stat": "instinct", "check": "white", "fail_damage": 5,
    "effects": [{"type": "ADD_REPUTATION", "faction": "korrigans", "amount": 10}],
    "outcome": "Tu pousses la porte. La piece est tiede, la table mise pour deux, et une "
               "main referme derriere toi. « Il vaut mieux que personne ne t'ait vu "
               "entrer », dit la veuve."}]},

 {"n": 2, "type": "NARRATIVE", "rarity": "COMMUNE", "emotion": "fascination",
  "resume": "La veuve refuse les trois pieces : ce n'est pas la dette qu'on attend de toi.",
  "situation": "La veuve pose les trois pieces sur la table sans les compter et les repousse "
               "vers toi. « Ce n'est pas ca qu'il attend », dit-elle en regardant la fenetre.",
  "options": [
   {"label": "Demander ce qu'il attend", "verb": "demander", "faction": "niamh",
    "gradient": "prudente", "stat": "empathie", "check": "white", "fail_damage": 3,
    "effects": [{"type": "ADD_REPUTATION", "faction": "niamh", "amount": 6}],
    "outcome": "Elle met longtemps a repondre. « Qu'on le sorte », finit-elle par dire, et "
               "elle ne precise pas d'ou. Tu comprends que la question etait la bonne et "
               "que la reponse ne t'aidera pas."},
   {"label": "Reposer les pieces sur la table", "verb": "reposer", "faction": "anciens",
    "gradient": "equilibree", "stat": "volonte", "check": "white", "fail_damage": 4,
    "effects": [{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 8}],
    "outcome": "Tu remets les pieces au milieu de la table. Elle ne les touche pas, mais "
               "quelque chose se detend dans ses epaules : la dette existe encore, et tant "
               "qu'elle existe, il y a une raison de te garder."},
   {"label": "Suivre son regard", "verb": "suivre", "faction": "druides",
    "gradient": "audacieuse", "stat": "logic", "check": "white", "fail_damage": 5,
    "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 10},
                {"type": "ADD_TAG", "tag": "vu_la_fenetre"}],
    "outcome": "Par la fenetre, la tourbiere fume au ras du sol. A deux cents pas, une "
               "planche a ete jetee en travers d'une fosse — recemment, le bois est encore "
               "clair. Quelqu'un traverse regulierement."}]},

 {"n": 3, "type": "EVENT", "rarity": "COMMUNE", "emotion": "tension",
  "resume": "Dehors, l'odeur s'epaissit et trois oiseaux se levent sans raison.",
  "situation": "Dehors, l'odeur de pain brule s'epaissit d'un coup. Trois oiseaux partent "
               "ensemble de la meme touffe de bruyere, sans qu'aucun bruit ne les ait leves.",
  "options": [
   {"label": "Rester immobile", "verb": "attendre", "faction": "anciens",
    "gradient": "prudente", "stat": "volonte", "check": "white", "fail_damage": 3,
    "effects": [{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 6},
                {"type": "HEAL_LIFE", "amount": 2}],
    "outcome": "Tu ne bouges pas. Au bout d'un moment, la bruyere se referme et l'odeur "
               "reflue. Ce qui passait est passe sans te voir, et tu respires mieux d'avoir "
               "su ne rien faire."},
   {"label": "Chercher l'origine de l'odeur", "verb": "flairer", "faction": "korrigans",
    "gradient": "equilibree", "stat": "instinct", "check": "white", "fail_damage": 4,
    "effects": [{"type": "ADD_REPUTATION", "faction": "korrigans", "amount": 8},
                {"type": "ADD_TAG", "tag": "trace_fumee"}],
    "outcome": "Tu remontes l'odeur a contre-vent. Elle vient d'un trou dans la tourbe ou "
               "quelque chose a brule lentement, longtemps, et sous les cendres il y a du "
               "tissu qui n'a pas fini de se consumer."},
   {"label": "Appeler le nom du mort", "verb": "appeler", "faction": "ankou",
    "gradient": "audacieuse", "stat": "volonte", "check": "white", "fail_damage": 5,
    "effects": [{"type": "ADD_REPUTATION", "faction": "ankou", "amount": 10}],
    "outcome": "Tu cries « Mael ». La tourbiere avale le son sans echo, puis te le rend — "
               "une seule fois, de beaucoup plus loin, et ce n'est pas ta voix. Quelque chose "
               "dans le marais vient d'apprendre le tien."}]},

 {"n": 4, "type": "SHOP", "rarity": "RARE", "emotion": "fascination",
  "resume": "Un tourbier vend au bord du chemin ce que le marais lui rend.",
  "situation": "Un tourbier charge sa brouette au bord du chemin. Il vend ce qu'il trouve "
               "dans le marais : de la corde grasse, une lampe a huile, un couteau a lame courte.",
  "options": [
   {"label": "Acheter la corde", "verb": "acheter", "faction": "anciens",
    "gradient": "prudente", "stat": "volonte", "check": "white", "fail_damage": 3,
    "effects": [{"type": "ADD_ESSENCE", "amount": 6},
                {"type": "ADD_TAG", "tag": "corde"}],
    "outcome": "Il te tend une corde epaisse de graisse de mouton. « Elle ne pourrit pas "
               "dans la tourbe », dit-il. « Et si tu tombes, elle ne te lachera pas — c'est "
               "toi qui la lacheras. »"},
   {"label": "Acheter la lampe", "verb": "acheter", "faction": "druides",
    "gradient": "equilibree", "stat": "logic", "check": "white", "fail_damage": 4,
    "effects": [{"type": "ADD_ESSENCE", "amount": 8},
                {"type": "ADD_TAG", "tag": "lampe"}],
    "outcome": "La lampe est cabossee et son verre fume. Il la remplit devant toi et te "
               "previent : « Dans le Yeun, elle ne t'eclaire pas, elle te signale. A toi "
               "de savoir a qui. »"},
   {"label": "Lui demander qui traverse", "verb": "questionner", "faction": "korrigans",
    "gradient": "audacieuse", "stat": "instinct", "check": "white", "fail_damage": 5,
    "effects": [{"type": "ADD_REPUTATION", "faction": "korrigans", "amount": 12},
                {"type": "ADD_TAG", "tag": "tourbier_parle"}],
    "outcome": "Il arrete de charger. « Personne ne traverse », dit-il trop vite, puis il "
               "reprend sa brouette et ajoute sans se retourner : « Et si quelqu'un "
               "traversait, il vaudrait mieux ne pas l'avoir vu. »"}]},

 {"n": 5, "type": "NARRATIVE", "rarity": "COMMUNE", "emotion": "tension",
  "resume": "Une planche recente franchit une fosse d'eau noire d'ou monte l'odeur.",
  "situation": "La planche jetee en travers de la fosse tient a peine. Dessous, l'eau noire "
               "ne bouge pas, et l'odeur de pain brule monte de la, pas du reste du marais.",
  "options": [
   {"label": "Sonder avant de passer", "verb": "sonder", "faction": "druides",
    "gradient": "prudente", "stat": "logic", "check": "white", "fail_damage": 3,
    "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 6}],
    "outcome": "Tu enfonces ton baton. Il descend d'une brasse, puis butte sur quelque chose "
               "qui n'est ni pierre ni racine — quelque chose qui cede un peu, puis resiste. "
               "Tu ne recommences pas."},
   {"label": "Traverser en courant", "verb": "traverser", "faction": "korrigans",
    "gradient": "equilibree", "stat": "instinct", "check": "white", "fail_damage": 4,
    "effects": [{"type": "ADD_REPUTATION", "faction": "korrigans", "amount": 8}],
    "outcome": "Tu passes en trois enjambees. La planche plie au milieu et te lache juste "
               "apres ; tu t'etales de l'autre cote, les mains dans la tourbe tiede, et "
               "quelque chose sous la surface te rend ta poussee."},
   {"label": "Retirer la planche", "verb": "retirer", "faction": "ankou",
    "gradient": "audacieuse", "stat": "volonte", "check": "white", "fail_damage": 5,
    "effects": [{"type": "ADD_REPUTATION", "faction": "ankou", "amount": 10}],
    "outcome": "Tu tires la planche et la jettes dans la bruyere. Celui qui traverse ne "
               "traversera plus — mais toi non plus, et il te faudra contourner par le nord, "
               "ou la tourbe est plus molle et te prend jusqu'aux genoux."}]},

 {"n": 6, "type": "MERLIN_DIRECT", "rarity": "EPIQUE", "emotion": "peur",
  "resume": "Merlin intervient : la fosse n'est pas une tombe, c'est une cachette occupee.",
  "situation": "Merlin parle sans que tu l'aies appele. « Regarde mieux la fosse, voyageur. "
               "On n'y a rien jete. On y a amenage une place, et elle est occupee. »",
  "options": [
   {"label": "Demander qui est en bas", "verb": "demander", "faction": "druides",
    "gradient": "prudente", "stat": "logic", "check": "white", "fail_damage": 4,
    "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 8}],
    "outcome": "« Celui a qui tu dois trois pieces », repond Merlin. « Il n'est pas mort "
               "dans le Yeun. Il s'y cache depuis un an, et quelqu'un le nourrit. »",
    "variantes": [
     {"si_marqueur": "bottes_seches",
      "texte": "« Tu as deja la reponse », dit Merlin. « Des bottes seches devant une "
               "maison au bord d'un marais. Tu savais avant moi que Mael Kerlan marche "
               "encore ; tu attendais seulement qu'on te le dise. »"}]},
   {"label": "Refuser d'ecouter", "verb": "refuser", "faction": "anciens",
    "gradient": "equilibree", "stat": "volonte", "check": "contextuel", "fail_damage": 8,
    "effects": [{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 11}],
    "outcome": "Tu lui dis de se taire. Il se tait — et le silence qu'il laisse est pire "
               "que ce qu'il allait dire, parce qu'il te laisse le remplir tout seul."},
   {"label": "Descendre voir", "verb": "descendre", "faction": "ankou",
    "gradient": "audacieuse", "stat": "instinct", "check": "contextuel", "fail_damage": 9,
    "effects": [{"type": "ADD_REPUTATION", "faction": "ankou", "amount": 13}],
    "outcome": "Tu te laisses glisser dans la fosse. L'eau t'arrive a la taille et sent le "
               "pain brule de tres pres. Une main sort de la tourbe et se referme sur ton "
               "poignet — pas pour te noyer : pour te retenir."}]},

 {"n": 7, "type": "NARRATIVE", "rarity": "COMMUNE", "emotion": "tension",
  "resume": "Mael Kerlan est vivant au fond de la fosse et supplie ton silence.",
  "situation": "L'homme dans la fosse est vivant, maigre, et il te reconnait. « Ne le dis "
               "pas a elle », souffle Mael Kerlan. « Tant qu'elle me croit noye, elle est "
               "en vie. »",
  "options": [
   {"label": "Ecouter son histoire", "verb": "ecouter", "faction": "niamh",
    "gradient": "prudente", "stat": "empathie", "check": "white", "fail_damage": 4,
    "effects": [{"type": "ADD_REPUTATION", "faction": "niamh", "amount": 10}],
    "outcome": "Il parle bas et vite. Ce n'est pas le marais qui l'a pris, c'est un homme "
               "du bourg a qui il devait plus que trois pieces — et cet homme a promis de "
               "prendre la veuve si le mari reparaissait."},
   {"label": "Le sortir de la", "verb": "extraire", "faction": "anciens",
    "gradient": "equilibree", "stat": "volonte", "check": "contextuel", "fail_damage": 8,
    "effects": [{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 12}],
    "outcome": "Tu le hisses par les aisselles. Il pese le poids d'un an de tourbe et ses "
               "jambes ne le portent plus. Une fois dehors, il regarde la maison qui fume "
               "au loin et se met a trembler — de froid, ou d'autre chose."},
   {"label": "Le laisser et partir", "verb": "abandonner", "faction": "ankou",
    "gradient": "audacieuse", "stat": "instinct", "check": "red", "fail_damage": 13,
    "telegraphie": True,
    "effects": [{"type": "ADD_REPUTATION", "faction": "ankou", "amount": 16},
                {"type": "ADD_ESSENCE", "amount": 4}],
    "outcome": "Tu remontes seul. Derriere toi, il ne crie pas, ne supplie pas, ne dit rien "
               "du tout — et c'est ce rien que tu emportes, plus lourd que trois pieces, "
               "et qui te suivra jusqu'au bout du marais."}]},

 {"n": 8, "type": "PROMISE", "rarity": "RARE", "emotion": "fascination",
  "resume": "Il demande trois jours de silence, jures sur la tourbe.",
  "situation": "Il te demande de jurer. « Trois jours », dit-il. « Donne-moi trois jours "
               "pour partir loin, et ensuite dis-lui ce que tu voudras. »",
  "options": [
   {"label": "Jurer les trois jours", "verb": "jurer", "faction": "anciens",
    "gradient": "prudente", "stat": "volonte", "check": "white", "fail_damage": 4,
    "effects": [{"type": "CREATE_PROMISE", "promise_id": "trois_jours",
                 "deadline_cards": 3, "description": "Taire que Mael Kerlan est vivant"},
                {"type": "ADD_REPUTATION", "faction": "anciens", "amount": 8}],
    "outcome": "Tu jures, et il te fait repeter le serment avec ses mots a lui. Le marais "
               "n'a pas d'oreilles, mais les Anciens en ont, et un serment prononce sur la "
               "tourbe ne s'efface pas."},
   {"label": "Promettre de revenir", "verb": "promettre", "faction": "niamh",
    "gradient": "equilibree", "stat": "empathie", "check": "white", "fail_damage": 4,
    "effects": [{"type": "CREATE_PROMISE", "promise_id": "revenir",
                 "deadline_cards": 4, "description": "Revenir le chercher"},
                {"type": "ADD_REPUTATION", "faction": "niamh", "amount": 10}],
    "outcome": "Tu ne promets pas le silence, tu promets le retour — ce qui n'est pas la "
               "meme chose et il le sait. Il accepte quand meme, parce qu'un homme dans une "
               "fosse accepte ce qu'on lui donne."},
   {"label": "Ne rien jurer", "verb": "refuser", "faction": "korrigans",
    "gradient": "audacieuse", "stat": "instinct", "check": "white", "fail_damage": 5,
    "effects": [{"type": "ADD_REPUTATION", "faction": "korrigans", "amount": 12}],
    "outcome": "Tu refuses de jurer quoi que ce soit. Il hoche la tete lentement : « Alors "
               "tu es honnete, ou tu es dangereux. » Il ne te tourne pas le dos en "
               "remontant vers la bruyere."}]},

 {"n": 9, "type": "NARRATIVE", "rarity": "COMMUNE", "emotion": "peur",
  "resume": "Sur le retour, un homme du bourg sent le pain brule sans avoir marche.",
  "situation": "Sur le chemin du retour, un homme du bourg vient a ta rencontre. Il sourit, "
               "et il sent le pain brule alors qu'il n'a pas mis un pied dans la tourbe.",
  "options": [
   {"label": "Le saluer sans t'arreter", "verb": "saluer", "faction": "druides",
    "gradient": "prudente", "stat": "logic", "check": "white", "fail_damage": 4,
    "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 6}],
    "outcome": "Tu le depasses en inclinant la tete. Il se retourne pour te regarder partir "
               "— tu ne le vois pas, tu l'entends : ses pas s'arretent quand les tiens "
               "continuent."},
   {"label": "Lui demander son nom", "verb": "questionner", "faction": "niamh",
    "gradient": "equilibree", "stat": "empathie", "check": "white", "fail_damage": 4,
    "effects": [{"type": "ADD_REPUTATION", "faction": "niamh", "amount": 8}],
    "outcome": "« Kerlan », repond-il. « Comme le noye. C'etait mon frere. » Il dit « etait » "
               "avec beaucoup de soin, comme un mot qu'on a beaucoup repete pour s'y habituer."},
   {"label": "Lui barrer le chemin", "verb": "barrer", "faction": "ankou",
    "gradient": "audacieuse", "stat": "volonte", "check": "white", "fail_damage": 5,
    "effects": [{"type": "ADD_REPUTATION", "faction": "ankou", "amount": 10}],
    "outcome": "Tu te mets en travers. Il ne recule pas et ne contourne pas : il attend, "
               "tres calme, que tu comprennes que tu n'as aucune raison de le retenir — "
               "aucune que tu puisses dire a voix haute."}]},

 {"n": 10, "type": "NARRATIVE", "rarity": "COMMUNE", "emotion": "tension",
  "resume": "La veuve attend sur le seuil, les trois pieces en main, et demande.",
  "situation": "La veuve t'attend sur le seuil, les trois pieces dans la main. Elle a vu "
               "d'ou tu reviens. « Alors ? » demande-t-elle, et sa voix ne tremble pas.",
  "options": [
   {"label": "Dire que la dette est payee", "verb": "mentir", "faction": "korrigans",
    "gradient": "prudente", "stat": "instinct", "check": "white", "fail_damage": 4,
    "effects": [{"type": "ADD_REPUTATION", "faction": "korrigans", "amount": 8}],
    "outcome": "Tu dis que tu as porte les pieces au marais et que c'est fini. Elle te "
               "regarde longtemps, referme la main sur les pieces, et ne te demande pas "
               "pourquoi tes bottes sont propres."},
   {"label": "Lui parler de son beau-frere", "verb": "avertir", "faction": "druides",
    "gradient": "equilibree", "stat": "logic", "check": "contextuel", "fail_damage": 8,
    "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 12}],
    "outcome": "Tu ne parles pas du vivant, tu parles de celui qui sent le pain brule sans "
               "avoir marche dans la tourbe. Elle blemit — non pas de surprise, mais parce "
               "que quelqu'un d'autre le sait enfin."},
   {"label": "Tout lui dire", "verb": "avouer", "faction": "niamh",
    "gradient": "audacieuse", "stat": "empathie", "check": "contextuel", "fail_damage": 9,
    "effects": [{"type": "ADD_REPUTATION", "faction": "niamh", "amount": 14}],
    "outcome": "Tu dis tout, y compris le serment que tu viens de rompre. Elle s'assoit sur "
               "le seuil, les pieces toujours dans la main, et ne pleure pas : elle calcule "
               "combien d'annees elle a passees a porter un deuil qu'on lui avait vendu."}]},

 {"n": 11, "type": "MERLIN_DIRECT", "rarity": "LEGENDAIRE", "emotion": "sagesse",
  "resume": "Merlin, assis sur la borne, demande ce que tu dois vraiment.",
  "situation": "Merlin est assis sur la borne, au bout du chemin. « Trois pieces », dit-il. "
               "« Voila ce que tu croyais devoir. Dis-moi ce que tu dois maintenant. »",
  "options": [
   {"label": "Payer et partir", "verb": "payer", "faction": "anciens",
    "gradient": "prudente", "stat": "volonte", "check": "white", "fail_damage": 4,
    "effects": [{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 12},
                {"type": "ADD_ANAM", "amount": 4}],
    "outcome": "Tu poses les pieces sur la borne et tu t'en vas. Merlin ne les ramasse pas. "
               "« Une dette payee au mauvais creancier reste une dette », dit-il dans ton "
               "dos, mais tu marches deja."},
   {"label": "Nommer ta vraie dette", "verb": "nommer", "faction": "druides",
    "gradient": "equilibree", "stat": "logic", "check": "white", "fail_damage": 5,
    "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 13},
                {"type": "ADD_ANAM", "amount": 5}],
    "outcome": "Tu dis que tu dois la verite a une femme et trois jours a un homme, et que "
               "les deux ne tiennent pas ensemble. Merlin hoche la tete. « Voila. C'est la "
               "premiere chose juste que tu dis depuis l'aube. »",
    "variantes": [
     {"si_promesse_rompue": "trois_jours",
      "texte": "Tu dis ce que tu dois, et Merlin t'arrete a mi-phrase. « Tu as jure trois "
               "jours et tu n'en as pas tenu un. Ce que tu dois maintenant, ce n'est plus "
               "a eux — c'est a ta propre parole, et elle est plus chere. »"}]},
   {"label": "Retourner au marais", "verb": "retourner", "faction": "ankou",
    "gradient": "audacieuse", "stat": "instinct", "check": "white", "fail_damage": 5,
    "effects": [{"type": "ADD_REPUTATION", "faction": "ankou", "amount": 15},
                {"type": "ADD_ANAM", "amount": 5}],
    "outcome": "Tu fais demi-tour sans repondre. Merlin ne te retient pas ; il te regarde "
               "reprendre le chemin de la tourbiere et murmure, pour lui seul : « Celui-la "
               "finira par comprendre ce qu'il est venu chercher. »"}]},
]


def acte(n: int, total: int) -> int:
    return min(1 + (n - 1) * 5 // total, 5)


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
        "id": "type_broc_tourbe_11", "title": TITRE,
        "archetype_id": ARCHETYPE, "archetype_name": "Le Vagabond de Brume",
        "pole_dominant": "Liminal", "twist_pattern": "lost_then_found",
        "biome": "marais_korrigans", "length": LONGUEUR, "pool_size": len(cards),
        "graine_de_variation": GRAINE,
        "emotional_arc": [c["emotion"] for c in CARTES],
        "intro": INTRO, "essence": ESSENCE, "hook": HOOK,
        "twist_card_id": "c6", "cards": cards,
        "branchement": "narratif — sequence unique, resolutions variables selon l'etat",
    }


# Taux de conversion bible §30 : tout effet se ramene a une unite commune, le
# PV-equivalent, pour comparer trois options entre elles.
PV_EQ = {"HEAL_LIFE": 1.0, "DAMAGE_LIFE": -1.0, "ADD_REPUTATION": 0.4,
         "ADD_ESSENCE": 0.8, "ADD_ANAM": 2.0}
P_SUCCES = 0.6  # stat 1 au premier run : 50% + 10% × stat (bible §26.1)


def ev(option: dict) -> float:
    """Espérance d'une option bâtie, en PV-équivalent, au premier run (stat 1)."""
    gain = sum(PV_EQ.get(e["type"], 0.0) * e.get("amount", 0) for e in option["effects"])
    return P_SUCCES * gain - (1 - P_SUCCES) * option["check"]["fail_damage"]


def render_markdown(s: dict) -> str:
    from collections import Counter
    L = [f"# ᚛ {s['title']} ᚜", ""]
    L.append(f"> **Scénario type de référence — canon bible v4.0.** Archétype "
             f"`{s['archetype_id']}` · pôle {s['pole_dominant']} · twist "
             f"`{s['twist_pattern']}` · **{s['length']} cartes** · branchement narratif.")
    L.append(">")
    L.append("> Écrit à la main : c'est la **cible** que la génération LLM doit atteindre, "
             "pas un échantillon de ce qu'elle produit. Jamais injecté comme modèle de contenu.")
    L.append("")
    L.append("## La graine qui l'a produit")
    L.append("")
    L.append("Ce sont les cinq contraintes tirées avant génération. Elles seules garantissent "
             "qu'aucun scénario ne ressemble au précédent.")
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
    L.append("| Acte | Cartes | Types | Émotions |")
    L.append("|---|---|---|---|")
    for a in range(1, 6):
        cs = [c for c in s["cards"] if c["act"] == a]
        if not cs:
            continue
        L.append(f"| {a} | {cs[0]['n']}–{cs[-1]['n']} | "
                 f"{', '.join(f'{n}×{t}' for t, n in Counter(c['type'] for c in cs).most_common())} | "
                 f"{', '.join(c['emotion'] for c in cs)} |")
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
                     + (" · **télégraphiée**" if ck.get("telegraphed") else ""))
            L.append("")
            L.append(f"> {o['outcome']}")
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
    nvar = sum(len(o.get('outcome_variants', [])) for c in s['cards'] for o in c['options'])
    print(f"  résolutions : {nres}/{sum(len(c['options']) for c in s['cards'])} "
          f"(+{nvar} variantes d'état)")

    if args.markdown:
        Path(args.markdown).write_text(render_markdown(s), encoding="utf-8")
        print(f"Rendu lisible : {args.markdown}")
    if args.out:
        Path(args.out).write_text(json.dumps([s], ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"Scénario écrit : {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
