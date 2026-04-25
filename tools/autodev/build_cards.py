import json

cards = [
  {
    "id": "FR_B1_001",
    "text": "Dans les landes balayees par un vent froid, la bruyere fremit comme une peau de bete. Les anciens se prosternent devant une silhouette qui avance sans bruit sur la tourbe. L'Ankou arpente son domaine ; ses ossements chantent dans l'obscurite croissante.",
    "biome": "landes_bruyere",
    "champ_lexical": "mystique",
    "trust_tier": "T1",
    "tags": ["mort", "ankou", "bruyere"],
    "faction": "ankou",
    "options": [
      {
        "label": "Observer la silhouette depuis les ronces",
        "verb": "observer",
        "effects": [{"type": "HEAL_LIFE", "amount": 4}]
      },
      {
        "label": "Fuir dans la nuit avant qu'elle vous remarque",
        "verb": "fuir",
        "effects": [{"type": "DAMAGE_LIFE", "amount": 8}, {"type": "ADD_REPUTATION", "faction": "ankou", "amount": 12}]
      },
      {
        "label": "Mediter face a la presence et accepter le passage",
        "verb": "mediter",
        "effects": [{"type": "HEAL_LIFE", "amount": 6}, {"type": "ADD_REPUTATION", "faction": "ankou", "amount": 8}]
      }
    ]
  },
  {
    "id": "FR_B1_002",
    "text": "Les vagues dechiquettent les falaises grises sous un ciel de fer. Une femme aux cheveux de varech chante parmi les rochers glissants ; sa voix noie les cris des oiseaux. Un collier de coquillages graves de runes tourbillonne dans l'ecume a vos pieds.",
    "biome": "cotes_sauvages",
    "champ_lexical": "nature",
    "trust_tier": "T1",
    "tags": ["mer", "sirene", "runes"],
    "faction": "niamh",
    "options": [
      {
        "label": "Ecouter le chant depuis une roche elevee",
        "verb": "ecouter",
        "effects": [{"type": "HEAL_LIFE", "amount": 5}, {"type": "ADD_REPUTATION", "faction": "niamh", "amount": 6}]
      },
      {
        "label": "Plonger dans l'ecume pour saisir le collier",
        "verb": "prendre",
        "effects": [{"type": "DAMAGE_LIFE", "amount": 10}, {"type": "ADD_REPUTATION", "faction": "niamh", "amount": 18}]
      },
      {
        "label": "Negocier avec la chanteuse en lui offrant du pain",
        "verb": "negocier",
        "effects": [{"type": "HEAL_LIFE", "amount": 3}, {"type": "ADD_REPUTATION", "faction": "niamh", "amount": 10}]
      }
    ]
  },
  {
    "id": "FR_B1_003",
    "text": "Un druide en robe de lin blanc interpelle les passants au centre du village. Il brandit un rameau de gui fraichement coupe et reclame un sacrifice pour apaiser les esprits du carrefour. Les villageois se figent, les yeux baisses.",
    "biome": "villages_celtes",
    "champ_lexical": "social",
    "trust_tier": "T1",
    "tags": ["druide", "village", "sacrifice"],
    "faction": "druides",
    "options": [
      {
        "label": "Aider le druide a rassembler les villageois",
        "verb": "aider",
        "effects": [{"type": "HEAL_LIFE", "amount": 3}, {"type": "ADD_REPUTATION", "faction": "druides", "amount": 10}]
      },
      {
        "label": "Refuser le rite et defier l'autorite du druide",
        "verb": "refuser",
        "effects": [{"type": "DAMAGE_LIFE", "amount": 7}, {"type": "ADD_REPUTATION", "faction": "druides", "amount": -15}]
      },
      {
        "label": "Explorer les ruelles pour comprendre la peur locale",
        "verb": "explorer",
        "effects": [{"type": "HEAL_LIFE", "amount": 5}, {"type": "ADD_REPUTATION", "faction": "anciens", "amount": 7}]
      }
    ]
  },
  {
    "id": "FR_B1_004",
    "text": "La lune s'immobilise au zenith du cercle megalithique. Chaque menhir pulse d'une lueur bleue et froide. Une voix ancienne qui n'appartient a aucune gorge vivante enumere des noms oublies depuis mille ans. Votre nom est le prochain sur la liste.",
    "biome": "cercles_pierres",
    "champ_lexical": "mystique",
    "trust_tier": "T1",
    "tags": ["menhirs", "magie", "anciens"],
    "faction": "anciens",
    "options": [
      {
        "label": "Contempler les pierres et attendre la revelation",
        "verb": "contempler",
        "effects": [{"type": "HEAL_LIFE", "amount": 6}, {"type": "ADD_REPUTATION", "faction": "anciens", "amount": 8}]
      },
      {
        "label": "Invoquer un contre-rituel pour briser le cercle",
        "verb": "invoquer",
        "effects": [{"type": "DAMAGE_LIFE", "amount": 12}, {"type": "ADD_REPUTATION", "faction": "anciens", "amount": 20}]
      },
      {
        "label": "Prier en silence au centre exact du cercle",
        "verb": "prier",
        "effects": [{"type": "HEAL_LIFE", "amount": 8}, {"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}]
      }
    ]
  },
  {
    "id": "FR_B1_005",
    "text": "Une brume verte colle aux roseaux du marais. Des rires d'enfants resonnent sous la surface de l'eau noire ; des doigts palmes effleurent la berge boueuse. Les korrigans vous observent depuis les joncs, leurs yeux semblables a des feux follets.",
    "biome": "marais_korrigans",
    "champ_lexical": "mystique",
    "trust_tier": "T1",
    "tags": ["korrigans", "marais", "piege"],
    "faction": "korrigans",
    "options": [
      {
        "label": "Observer les lueurs sans bouger ni parler",
        "verb": "observer",
        "effects": [{"type": "HEAL_LIFE", "amount": 4}, {"type": "ADD_REPUTATION", "faction": "korrigans", "amount": 5}]
      },
      {
        "label": "Avancer dans la vase pour approcher les korrigans",
        "verb": "avancer",
        "effects": [{"type": "DAMAGE_LIFE", "amount": 13}, {"type": "ADD_REPUTATION", "faction": "korrigans", "amount": 15}]
      },
      {
        "label": "Chanter une comptine ancienne pour les amadouer",
        "verb": "chanter",
        "effects": [{"type": "HEAL_LIFE", "amount": 7}, {"type": "ADD_REPUTATION", "faction": "korrigans", "amount": 12}]
      }
    ]
  },
  {
    "id": "FR_B1_006",
    "text": "Un dolmen effondre couronne la colline de quartzite. Les blocs calcaires portent des gravures d'avant le temps des hommes. Une odeur de pluie ancienne monte de la chambre funeraire entrouverte. Quelque chose respire dans l'obscurite en dessous.",
    "biome": "collines_dolmens",
    "champ_lexical": "logique",
    "trust_tier": "T1",
    "tags": ["dolmen", "tombe", "anciens"],
    "faction": "anciens",
    "options": [
      {
        "label": "Dechiffrer les gravures sans approcher la chambre",
        "verb": "dechiffrer",
        "effects": [{"type": "HEAL_LIFE", "amount": 5}, {"type": "ADD_REPUTATION", "faction": "anciens", "amount": 10}]
      },
      {
        "label": "Descendre dans la chambre funeraire avec une torche",
        "verb": "explorer",
        "effects": [{"type": "DAMAGE_LIFE", "amount": 14}, {"type": "ADD_REPUTATION", "faction": "anciens", "amount": 18}]
      },
      {
        "label": "Proteger le dolmen en posant des pierres votives",
        "verb": "proteger",
        "effects": [{"type": "HEAL_LIFE", "amount": 7}, {"type": "ADD_REPUTATION", "faction": "druides", "amount": 8}]
      }
    ]
  },
  {
    "id": "FR_B1_007",
    "text": "L'ile emergee de la brume porte un verger aux fruits de lumiere. Des femmes vetues d'argent vous accueillent avec du pain dore. Mais la rive d'ou vous venez a disparu. Avalon tient ses promesses et ne libere pas ses hotes facilement.",
    "biome": "iles_mystiques",
    "champ_lexical": "nature",
    "trust_tier": "T1",
    "tags": ["avalon", "piege", "femmes_fees"],
    "faction": "niamh",
    "options": [
      {
        "label": "Accepter l'hospitalite et gouter au pain dore",
        "verb": "accepter",
        "effects": [{"type": "HEAL_LIFE", "amount": 18}, {"type": "ADD_REPUTATION", "faction": "niamh", "amount": -10}]
      },
      {
        "label": "Refuser et tenter de retrouver le chemin du retour",
        "verb": "refuser",
        "effects": [{"type": "DAMAGE_LIFE", "amount": 9}, {"type": "ADD_REPUTATION", "faction": "niamh", "amount": 15}]
      },
      {
        "label": "Negocier un echange pour garder la liberte de partir",
        "verb": "negocier",
        "effects": [{"type": "HEAL_LIFE", "amount": 8}, {"type": "ADD_REPUTATION", "faction": "niamh", "amount": 12}]
      }
    ]
  },
  {
    "id": "FR_B1_008",
    "text": "Les chenes millenaires de Broceliande tissent un plafond de jade sous lequel la lumiere n'atteint plus le sol. Un cerf blanc s'arrete devant vous, ses andouillers charges de gui en fleurs. Il vous fixe avec des yeux qui ont vu passer toutes les merveilles du monde.",
    "biome": "foret_broceliande",
    "champ_lexical": "nature",
    "trust_tier": "T1",
    "tags": ["cerf_blanc", "foret", "druides"],
    "faction": "druides",
    "options": [
      {
        "label": "Contempler le cerf sans esquisser un geste",
        "verb": "contempler",
        "effects": [{"type": "HEAL_LIFE", "amount": 10}, {"type": "ADD_REPUTATION", "faction": "druides", "amount": 8}]
      },
      {
        "label": "Suivre le cerf blanc dans les profondeurs du bois",
        "verb": "poursuivre",
        "effects": [{"type": "DAMAGE_LIFE", "amount": 6}, {"type": "ADD_REPUTATION", "faction": "druides", "amount": 20}]
      },
      {
        "label": "Mediter sous les chenes pour recevoir sa sagesse",
        "verb": "mediter",
        "effects": [{"type": "HEAL_LIFE", "amount": 12}, {"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}]
      }
    ]
  }
]

VALID_VERBS = {'observer','ecouter','toucher','gouter','sentir','avancer','reculer',
 'attendre','fuir','combattre','negocier','accepter','refuser','promettre','mentir',
 'aider','ignorer','prendre','donner','demander','invoquer','mediter','explorer',
 'cacher','montrer','chanter','prier','maudire','benir','sacrifier','trahir',
 'proteger','abandonner','poursuivre','contempler','dechiffrer','endurer','resister',
 'traverser','soigner','guider','apprivoiser','veiller','ramasser'}

VALID_BIOMES = {'foret_broceliande','landes_bruyere','cotes_sauvages','villages_celtes',
                'cercles_pierres','marais_korrigans','collines_dolmens','iles_mystiques'}
VALID_FACTIONS = {'druides','anciens','korrigans','niamh','ankou'}

errors = []
for c in cards:
    cid = c['id']
    words = len(c['text'].split())
    if words < 30 or words > 150:
        errors.append(f'{cid}: text {words} words (need 30-150)')
    if c['biome'] not in VALID_BIOMES:
        errors.append(f'{cid}: invalid biome {c["biome"]}')
    if c['faction'] not in VALID_FACTIONS:
        errors.append(f'{cid}: invalid faction {c["faction"]}')
    if len(c['options']) != 3:
        errors.append(f'{cid}: need exactly 3 options, got {len(c["options"])}')
    for opt in c['options']:
        if opt['verb'] not in VALID_VERBS:
            errors.append(f'{cid}: invalid verb "{opt["verb"]}"')
        for eff in opt['effects']:
            t = eff['type']
            amt = eff['amount']
            if t == 'HEAL_LIFE' and amt > 18:
                errors.append(f'{cid}: HEAL_LIFE {amt} > 18 cap')
            if t == 'DAMAGE_LIFE' and amt > 15:
                errors.append(f'{cid}: DAMAGE_LIFE {amt} > 15 cap')
            if t == 'ADD_REPUTATION' and abs(amt) > 20:
                errors.append(f'{cid}: ADD_REPUTATION {amt} > +-20 cap')

if errors:
    print('VALIDATION ERRORS:')
    for e in errors:
        print(' ', e)
else:
    print(f'VALIDATION PASS -- {len(cards)} cards, 0 errors')

biomes = set(c['biome'] for c in cards)
factions = set(c['faction'] for c in cards)
print(f'Biomes ({len(biomes)}): {sorted(biomes)}')
print(f'Factions ({len(factions)}): {sorted(factions)}')

out_path = 'C:/Users/PGNK2128/Godot-MCP/data/cards/fastroute_batch_20260425_visual_v3.json'
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(cards, f, ensure_ascii=False, indent=2)
print(f'Saved: {out_path}')
print(f'Cards: {len(cards)}')
