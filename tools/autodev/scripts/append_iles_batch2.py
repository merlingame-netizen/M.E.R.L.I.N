"""Append 20 iles_mystiques batch2 cards to cards.json — Cycle 21 narrative agent."""
import json, sys, os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "..")
CARDS_PATH = os.path.join(ROOT, "web-demo", "public", "data", "cards.json")

NEW_CARDS = [
  {
    "narrative": "Un brouillard opalescent enveloppe l'ile d'Avalon. Niamh au Manteau d'Or t'observe depuis la rive, son regard dore comme la lumiere du soleil couchant.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "contempler", "text": "Tu laisses la beaute de la scene s'imprimer dans ton ame, recevant sa benediction silencieuse.", "effects": ["ADD_REPUTATION:niamh:16", "HEAL_LIFE:4"]},
      {"verb": "s'approcher", "text": "Tu avances vers Niamh, le coeur ouvert, offrant ta presence sans attente.", "effects": ["ADD_REPUTATION:niamh:14", "ADD_ANAM:3"]},
      {"verb": "prier", "text": "Tu prononces une invocation ancienne apprise des druides de la foret.", "effects": ["ADD_REPUTATION:druides:12", "ADD_REPUTATION:niamh:8"]}
    ]
  },
  {
    "narrative": "Des colonnes de pierre emergent de la mer comme des doigts geants. Entre elles flottent des lueurs bleutees, ames des marins perdus, murmure-t-on.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "ecouter", "text": "Tu tends l'oreille aux murmures des lueurs, cherchant un message dans leurs frequences.", "effects": ["ADD_REPUTATION:niamh:18", "ADD_ANAM:4"]},
      {"verb": "honorer", "text": "Tu deposes une offrande sur une pierre plate, respectant la memoire des anciens.", "effects": ["ADD_REPUTATION:anciens:15", "HEAL_LIFE:3"]},
      {"verb": "traverser", "text": "Tu passes entre les colonnes en chantant, laissant ta voix resonner dans la pierre.", "effects": ["ADD_REPUTATION:niamh:12", "ADD_REPUTATION:korrigans:8"]}
    ]
  },
  {
    "narrative": "Une barque sans rameur t'attend au bord de l'eau. Son fond est couvert de feuilles de chene dorees. Quelque chose t'appelle vers le large.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "embarquer", "text": "Tu montes dans la barque et te laisses porter par le courant invisible.", "effects": ["ADD_REPUTATION:niamh:20", "DAMAGE_LIFE:4"]},
      {"verb": "attendre", "text": "Tu observes la barque avec patience, guettant un signe avant d'agir.", "effects": ["ADD_REPUTATION:anciens:14", "ADD_ANAM:2"]},
      {"verb": "refuser", "text": "Tu reconnais le piege des illusions et restes sur la rive, gardant ta raison.", "effects": ["ADD_REPUTATION:druides:10", "HEAL_LIFE:5"]}
    ]
  },
  {
    "narrative": "Une fontaine de jouvence coule entre deux rochers moussus. L'eau y est d'un bleu profond, presque noir. Des runes sont gravees sur les pierres alentour.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "boire", "text": "Tu portes l'eau a tes levres, sentant une energie ancienne se repandre en toi.", "effects": ["HEAL_LIFE:5", "ADD_REPUTATION:niamh:12"]},
      {"verb": "lire", "text": "Tu dechiffres les runes et comprends l'usage sacre de cette source.", "effects": ["ADD_REPUTATION:druides:16", "ADD_ANAM:3"]},
      {"verb": "offrir", "text": "Tu deposes un Ogham sculpte dans l'eau, faisant un voeu pour les tiens.", "effects": ["ADD_REPUTATION:niamh:14", "ADD_REPUTATION:anciens:10"]}
    ]
  },
  {
    "narrative": "Niamh t'offre un fruit d'or inconnu. Sa surface luit comme une lune pleine. Elle dit : Mange, et tu verras ce qui fut avant le monde.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "accepter", "text": "Tu croques le fruit et une vision du commencement t'envahit, bouleversante et belle.", "effects": ["ADD_REPUTATION:niamh:20", "DAMAGE_LIFE:5", "ADD_ANAM:5"]},
      {"verb": "remercier", "text": "Tu acceptes le fruit avec gratitude mais choisis de le garder pour plus tard.", "effects": ["ADD_REPUTATION:niamh:15", "ADD_ANAM:2"]},
      {"verb": "decliner", "text": "Tu declines respectueusement, expliquant que ton voyage n'est pas encore termine.", "effects": ["ADD_REPUTATION:anciens:12", "HEAL_LIFE:3"]}
    ]
  },
  {
    "narrative": "Un cerf blanc au bois d'argent traverse la plage au clair de lune. Ses sabots ne laissent aucune trace dans le sable humide.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "suivre", "text": "Tu le suis en silence, sachant qu'un cerf blanc mene toujours vers un prodige.", "effects": ["ADD_REPUTATION:niamh:16", "ADD_ANAM:4"]},
      {"verb": "observer", "text": "Tu restes immobile, laissant la magie operer sans la perturber.", "effects": ["ADD_REPUTATION:anciens:14", "HEAL_LIFE:4"]},
      {"verb": "saluer", "text": "Tu t'inclines devant l'emissaire du monde invisible.", "effects": ["ADD_REPUTATION:niamh:12", "ADD_REPUTATION:druides:10"]}
    ]
  },
  {
    "narrative": "Les anciens de l'ile se reunissent en cercle autour d'un feu bleu. Ils te fixent en silence, puis l'un d'eux te tend un parchemin roule.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "lire", "text": "Tu deplies le parchemin avec soin et decouvres une carte de l'ile inconnue.", "effects": ["ADD_REPUTATION:anciens:18", "ADD_ANAM:3"]},
      {"verb": "questionner", "text": "Tu demandes aux anciens la signification du document avant de l'accepter.", "effects": ["ADD_REPUTATION:anciens:15", "ADD_REPUTATION:niamh:8"]},
      {"verb": "partager", "text": "Tu lis le parchemin a voix haute, incluant tout le cercle dans sa revelation.", "effects": ["ADD_REPUTATION:anciens:14", "ADD_REPUTATION:druides:10"]}
    ]
  },
  {
    "narrative": "Un pont de nuages relie l'ile a une haute tour invisible en temps normal. La tour s'appelle la Tour de Verre, dit une voix sans visage.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "traverser", "text": "Tu poses le pied sur le nuage avec foi et avances vers la tour.", "effects": ["ADD_REPUTATION:niamh:18", "DAMAGE_LIFE:3", "ADD_ANAM:4"]},
      {"verb": "mediter", "text": "Tu t'assieds au bord du pont et laisses la vision te parler.", "effects": ["ADD_REPUTATION:anciens:16", "ADD_ANAM:3"]},
      {"verb": "documenter", "text": "Tu graves la forme du pont dans ton baton de voyage.", "effects": ["ADD_REPUTATION:druides:12", "ADD_ANAM:2"]}
    ]
  },
  {
    "narrative": "Des dauphins argentes bondissent hors de l'eau en rythme. Leurs sauts dessinent des Oghams dans l'air avant de disparaitre en ecume.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "dechiffrer", "text": "Tu lis les Oghams traces dans l'air, recevant un message du monde aquatique.", "effects": ["ADD_REPUTATION:niamh:14", "ADD_REPUTATION:druides:10", "ADD_ANAM:2"]},
      {"verb": "chanter", "text": "Tu reponds aux dauphins avec un chant ancien, creant un dialogue inter-especes.", "effects": ["ADD_REPUTATION:niamh:18", "HEAL_LIFE:4"]},
      {"verb": "remercier", "text": "Tu salues les messagers de l'ocean avec une profonde reverence.", "effects": ["ADD_REPUTATION:anciens:12", "ADD_ANAM:3"]}
    ]
  },
  {
    "narrative": "Une harpe en os de baleine flotte sur l'eau, jouant seule une melodie qui serre le coeur. Chaque note porte le nom d'un heros oublie.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "ecouter", "text": "Tu recois chaque note comme un souvenir precieux, honorant les heros oublies.", "effects": ["ADD_REPUTATION:anciens:16", "HEAL_LIFE:5"]},
      {"verb": "jouer", "text": "Tu tends la main et ajoutes ta propre melodie, faisant resonner ton nom a leur cote.", "effects": ["ADD_REPUTATION:niamh:14", "ADD_ANAM:4"]},
      {"verb": "sauvegarder", "text": "Tu memorises la melodie pour la transmettre aux bardes du continent.", "effects": ["ADD_REPUTATION:druides:12", "ADD_REPUTATION:anciens:10"]}
    ]
  },
  {
    "narrative": "Niamh te conduit dans une salle ovale dont les murs sont faits de memoire petrifiee. Chaque pan montre une vie possible que tu n'as pas vecue.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "contempler", "text": "Tu observes chaque vie possible avec sagesse, sans regret ni desir.", "effects": ["ADD_REPUTATION:niamh:18", "ADD_ANAM:5"]},
      {"verb": "choisir", "text": "Tu touches le pan qui te ressemble le plus, absorbant sa sagesse condensee.", "effects": ["ADD_REPUTATION:niamh:15", "HEAL_LIFE:4"]},
      {"verb": "refuser", "text": "Tu detournes les yeux, sachant que la vraie vie ne se vit qu'une fois.", "effects": ["ADD_REPUTATION:anciens:14", "ADD_ANAM:3"]}
    ]
  },
  {
    "narrative": "La maree se retire, revelant un labyrinthe de pierre grave dans le fond marin. En son centre brille une gemme verte de la taille d'un poing.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "explorer", "text": "Tu descends dans le labyrinthe, guide par ton instinct vers le centre lumineux.", "effects": ["ADD_REPUTATION:niamh:16", "DAMAGE_LIFE:5", "ADD_ANAM:5"]},
      {"verb": "cartographier", "text": "Tu traces le plan du labyrinthe depuis la rive avant toute tentative.", "effects": ["ADD_REPUTATION:druides:14", "ADD_ANAM:3"]},
      {"verb": "attendre", "text": "Tu devines que la gemme appartient aux profondeurs et choisis de la laisser.", "effects": ["ADD_REPUTATION:anciens:16", "HEAL_LIFE:3"]}
    ]
  },
  {
    "narrative": "Un enfant aux cheveux blancs court sur l'eau comme sur de la terre ferme. Il rit et t'appelle par ton vrai nom, celui que tu n'as jamais dit a personne.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "courir", "text": "Tu cours vers l'enfant, laissant la foi te porter sur l'eau.", "effects": ["ADD_REPUTATION:niamh:20", "DAMAGE_LIFE:6"]},
      {"verb": "appeler", "text": "Tu cries son nom en retour, testant si lui aussi le connait.", "effects": ["ADD_REPUTATION:niamh:14", "ADD_ANAM:4"]},
      {"verb": "observer", "text": "Tu regardes avec bienveillance, sachant que les enfants de l'autre monde ne se capturent pas.", "effects": ["ADD_REPUTATION:anciens:15", "HEAL_LIFE:3"]}
    ]
  },
  {
    "narrative": "Une ancienne stele runique emergee des eaux porte un poeme en ogham que tu peux presque lire. Le sens vacille entre deux interpretations opposees.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "interpreter", "text": "Tu choisis l'interpretation qui parle de vie et de renouveau.", "effects": ["ADD_REPUTATION:druides:16", "HEAL_LIFE:5"]},
      {"verb": "copier", "text": "Tu retranscris fidelement le texte sans interpretation pour les savants.", "effects": ["ADD_REPUTATION:anciens:14", "ADD_ANAM:3"]},
      {"verb": "questionner", "text": "Tu demandes aux anciens de l'ile leur lecture de ce poeme ambigu.", "effects": ["ADD_REPUTATION:anciens:12", "ADD_REPUTATION:niamh:10"]}
    ]
  },
  {
    "narrative": "Niamh t'enseigne la danse des etoiles. Chaque pas correspond a une constellation. Apres trois tours, le ciel commence a repondre.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "danser", "text": "Tu apprends chaque pas avec devotion, laissant les etoiles choreographier tes mouvements.", "effects": ["ADD_REPUTATION:niamh:18", "ADD_ANAM:4"]},
      {"verb": "memoriser", "text": "Tu enregistres les correspondances corps-etoile pour les transmettre.", "effects": ["ADD_REPUTATION:druides:14", "ADD_REPUTATION:niamh:8"]},
      {"verb": "improviser", "text": "Tu ajoutes ta propre sequence a la danse, enrichissant le lexique stellaire.", "effects": ["ADD_REPUTATION:niamh:15", "ADD_ANAM:3"]}
    ]
  },
  {
    "narrative": "Un navire fantome ancre au large laisse filtrer de la lumiere par ses hublots. A son bord, des silhouettes dansent en silence depuis des siecles.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "nager", "text": "Tu nages vers le navire, acceptant le risque pour decouvrir son secret.", "effects": ["ADD_REPUTATION:niamh:16", "DAMAGE_LIFE:4", "ADD_ANAM:4"]},
      {"verb": "appeler", "text": "Tu cries depuis la rive, invitant les danseurs a te rejoindre sur terre.", "effects": ["ADD_REPUTATION:anciens:14", "ADD_ANAM:2"]},
      {"verb": "honorer", "text": "Tu allumes un feu sur la plage en hommage a ceux qui dansent pour l'eternite.", "effects": ["ADD_REPUTATION:anciens:16", "HEAL_LIFE:3"]}
    ]
  },
  {
    "narrative": "Une cascade coule a rebours, de la mer vers le ciel. L'eau qui monte emporte les souvenirs douloureux de quiconque la touche.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "toucher", "text": "Tu poses la main dans la cascade montante, offrant un souvenir lourd a liberer.", "effects": ["ADD_REPUTATION:niamh:16", "HEAL_LIFE:5"]},
      {"verb": "refuser", "text": "Tu gardes tes souvenirs douloureux, ce sont eux qui font ta force.", "effects": ["ADD_REPUTATION:anciens:14", "ADD_ANAM:3"]},
      {"verb": "etudier", "text": "Tu analyses le phenomene avec rigueur, cherchant la loi naturelle derriere le prodige.", "effects": ["ADD_REPUTATION:druides:14", "ADD_ANAM:2"]}
    ]
  },
  {
    "narrative": "Les anciens de l'ile organisent une veillee pour une etoile filante qui a touche l'ocean. Ils disent qu'elle porte un message pour toi seul.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "recevoir", "text": "Tu t'assieds au centre du cercle et ouvres ton esprit au message stellaire.", "effects": ["ADD_REPUTATION:anciens:18", "ADD_REPUTATION:niamh:10", "ADD_ANAM:3"]},
      {"verb": "questionner", "text": "Tu demandes comment ils savent que le message t'est destine.", "effects": ["ADD_REPUTATION:anciens:14", "ADD_ANAM:2"]},
      {"verb": "plonger", "text": "Tu plonges dans la mer pour recuperer le fragment d'etoile.", "effects": ["ADD_REPUTATION:niamh:15", "DAMAGE_LIFE:4", "ADD_ANAM:4"]}
    ]
  },
  {
    "narrative": "Niamh te montre un miroir d'eau dans lequel tu vois non pas ton reflet, mais le visage de la personne que tu pourrais devenir.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "accepter", "text": "Tu embrasses cette vision de toi-meme comme une promesse et non un fardeau.", "effects": ["ADD_REPUTATION:niamh:20", "HEAL_LIFE:4", "ADD_ANAM:3"]},
      {"verb": "questionner", "text": "Tu demandes a Niamh ce qui separe cette vision de ta realite presente.", "effects": ["ADD_REPUTATION:niamh:14", "ADD_ANAM:4"]},
      {"verb": "briser", "text": "Tu detournes les yeux, refusant de laisser un miroir definir ton destin.", "effects": ["ADD_REPUTATION:anciens:12", "HEAL_LIFE:3"]}
    ]
  },
  {
    "narrative": "Au sommet du plus haut rocher de l'ile, un druide muet grave les lois du monde depuis mille ans. Il te tend son ciseau sans lever les yeux.",
    "biome": "iles_mystiques",
    "options": [
      {"verb": "graver", "text": "Tu graves ton nom et ton voeu le plus profond dans la pierre eternelle.", "effects": ["ADD_REPUTATION:druides:16", "ADD_REPUTATION:anciens:10", "ADD_ANAM:3"]},
      {"verb": "refuser", "text": "Tu rends respectueusement l'outil, ce n'est pas encore ton heure de graver.", "effects": ["ADD_REPUTATION:anciens:15", "HEAL_LIFE:4"]},
      {"verb": "aider", "text": "Tu aides le druide a finir sa ligne en cours, en parfaite communion silencieuse.", "effects": ["ADD_REPUTATION:druides:18", "ADD_ANAM:4"]}
    ]
  }
]

def validate_cards(cards):
    errors = []
    for c in cards:
        for o in c.get("options", []):
            effs = o.get("effects", [])
            if len(effs) > 3:
                errors.append(f"TOO_MANY_EFFECTS on verb={o['verb']}")
            for e in effs:
                parts = e.split(":")
                if parts[0] == "HEAL_LIFE" and int(parts[1]) > 5:
                    errors.append(f"HEAL_LIFE_OVER_5: {e}")
                if parts[0] == "ADD_REPUTATION" and int(parts[2]) > 20:
                    errors.append(f"REP_OVER_20: {e}")
                if parts[0] == "DAMAGE_LIFE" and int(parts[1]) > 15:
                    errors.append(f"DMG_OVER_15: {e}")
    return errors

errors = validate_cards(NEW_CARDS)
if errors:
    print("CONSTRAINT ERRORS:", errors)
    sys.exit(1)

with open(CARDS_PATH, "r", encoding="utf-8") as f:
    cards = json.load(f)

before = len(cards)

# Check none already appended (idempotency guard)
existing_iles = [c for c in cards if c.get("biome") == "iles_mystiques"]
if len(existing_iles) >= 20:
    print(f"Already have {len(existing_iles)} iles_mystiques cards — skipping append")
    sys.exit(0)

cards.extend(NEW_CARDS)

with open(CARDS_PATH, "w", encoding="utf-8") as f:
    json.dump(cards, f, ensure_ascii=False, indent=2)

after = len(cards)
iles = [c for c in cards if c.get("biome") == "iles_mystiques"]
niamh_opts = sum(1 for c in iles for o in c.get("options",[]) if any("niamh" in e for e in o.get("effects",[])))
total_opts = len(iles) * 3
print(f"Cards: {before} -> {after} (+{after-before})")
print(f"iles_mystiques: {len(iles)} cards, {niamh_opts}/{total_opts} niamh options ({round(niamh_opts/total_opts*100)}%)")
print("All constraints PASS")
