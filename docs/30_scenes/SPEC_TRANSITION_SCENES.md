# SPEC: Scenes de Transition — Eveil, Antre, Biome
## Specification Complete d'Interaction et de Gameplay

*Version: 1.0 — 2026-02-08*
*Auteur: Game Designer Agent*

---

> *"Tu n'es pas d'ici. Et pourtant, d'ou tu viens n'a aucune importance.*
> *Ce qui compte, c'est que tu sois venu."*
> — Merlin, Trust T0

---

## VUE D'ENSEMBLE

### Probleme

Le flux actuel saute directement de `IntroMerlinDialogue` (questionnaire) vers `TriadeGame` (gameplay). Le joueur recoit sa classe, puis se retrouve immediatement en jeu sans comprendre:
- Ou il est
- Pourquoi il est la
- Qui est Bestiole
- Quel est son objectif
- Dans quel biome il va jouer

### Solution: 3 scenes de transition

```
IntroMerlinDialogue ──► SceneEveil ──► SceneAntreMerlin ──► TransitionBiome ──► TriadeGame
   (questionnaire)     (arrivee)     (briefing/compagnon)   (voyage/carte)     (gameplay)
```

### Durees cibles

| Scene | Duree min | Duree typique | Duree max | Skippable |
|-------|-----------|---------------|-----------|-----------|
| SceneEveil | 20s | 45s | 90s | Apres 1ere visite (flag) |
| SceneAntreMerlin | 60s | 120s | 180s | Non (interactions requises) |
| TransitionBiome | 8s | 15s | 25s | Tap pour accelerer |

**Duree totale transition: ~3 minutes** (premiere fois), ~1 minute (revisites).

---

## DONNEES ENTRANTS / SORTANTS

### Ce qui arrive de IntroMerlinDialogue

```gdscript
# Deja stocke dans GameManager.run par IntroMerlinDialogue._end_demo()
{
    "chronicle_name": String,          # Nom choisi par le joueur
    "traveler_profile": {
        "verb_affinity": {"FORCE": int, "LOGIQUE": int, "FINESSE": int},
        "traits": {
            "courage": int, "curiosite": int, "compassion": int,
            "orgueil": int, "verite": int, "controle": int
        },
        "class_scores": {"druide": int, "guerrier": int, "barde": int, "eclaireur": int},
        "class": String,               # "druide"|"guerrier"|"barde"|"eclaireur"
        "hooks": Array[String],
        "answers": Array[Dictionary]
    },
    "merlin_memory": Array[String]     # 8 derniers hooks narratifs
}
```

### Ce que les 3 scenes ajoutent a GameManager.run

```gdscript
# Nouveau: ajoute par les scenes de transition
GameManager.run["biome"] = {
    "id": String,                      # ex: "broceliande"
    "name": String,                    # ex: "Foret de Broceliande"
    "assigned_by_class": bool,         # true si auto-assigne, false si choisi
    "ogham_dominant": String,          # ex: "duir"
    "gardien": String,                 # ex: "Maelgwn"
    "season_forte": String,            # ex: "automne"
}
GameManager.run["bestiole_met"] = true
GameManager.run["mission_briefing"] = String    # texte court de la mission
GameManager.run["eveil_timestamp"] = int        # moment d'arrivee (pour duree totale)
GameManager.run["traveler_profile"]["aspect_dominant"] = String  # "Corps"|"Ame"|"Monde"
```

### Ce que TriadeGame recoit

TriadeGame lit `GameManager.run` au demarrage. Les nouvelles donnees sont:
- `biome` — pour theming des cartes, couleurs, atmosphere
- `bestiole_met` — pour sauter l'intro Bestiole si deja vue
- `mission_briefing` — pour afficher en UI
- `aspect_dominant` — pour orienter la generation LLM des premieres cartes

---

## SCENE 1: SceneEveil

### Concept Narratif

Ecran noir. Le joueur "traverse la Membrane" et arrive dans le monde de Broceliande. Merlin parle dans le noir avant que la lumiere ne revienne. C'est l'equivalent d'un "reveil" — le Voyageur ouvre les yeux pour la premiere fois.

**Ton**: Mysterieux, intime, desorientant puis rassurant.

### Fichier scene

`res://scenes/SceneEveil.tscn` — root: `Control` (plein ecran)

### Structure de nodes

```
SceneEveil (Control, PRESET_FULL_RECT)
├── Background (ColorRect, noir #000000)
├── VoiceText (RichTextLabel, centre vertical)
├── SkipHint (Label, coin bas-droit, "Toucher pour continuer")
├── LightOverlay (ColorRect, blanc, alpha=0)
├── Audio
│   ├── AmbianceDrone (AudioStreamPlayer)
│   ├── VoiceBlip (AudioStreamPlayer)
│   └── SfxAwaken (AudioStreamPlayer)
└── Particles (GPUParticles2D, particules flottantes subtiles)
```

### Sequence d'evenements

```
PHASE 1: LE NOIR (0s - 10s)
─────────────────────────────
[0.0s] Ecran completement noir
[0.5s] Drone ambiant demarre (son grave, distant)
[2.0s] Particules tres subtiles apparaissent (lucioles dans le noir)
[3.0s] Texte typewriter: dialogue_merlin_eveil[0] (adapte a la classe)
[---]  Joueur tape → texte suivant (ou auto-avance apres 5s)

PHASE 2: LA MEMBRANE (10s - 25s)
─────────────────────────────────
[---]  Texte typewriter: dialogue_merlin_eveil[1..3]
[---]  Effet visuel: ondulation subtile du fond (shader wave)
[---]  Les particules s'intensifient progressivement
[---]  Le drone ambiant monte en intensite

PHASE 3: L'EVEIL (25s - 45s)
─────────────────────────────
[---]  Dernier texte de Merlin
[---]  Flash blanc progressif (LightOverlay alpha: 0 → 0.8 en 2s)
[---]  Son de "traversee" (SfxAwaken)
[---]  Flash retombe (alpha 0.8 → 0 en 1s)
[---]  Transition vers SceneAntreMerlin
```

### Dialogues de Merlin (adaptes a la classe)

```gdscript
const EVEIL_DIALOGUES := {
    "druide": [
        "...Tu sens ca?",
        "La brume te reconnait. Elle t'a deja vu, je crois.",
        "Les pierres murmurent ton nom. Ou un nom qui te ressemble.",
        "Ouvre les yeux, Voyageur. Le monde t'attendait."
    ],
    "guerrier": [
        "...Quelqu'un approche.",
        "La Membrane tremble. Quelque chose de solide la traverse.",
        "Pas subtil, hein? Tant mieux. La subtilite est surestimee.",
        "Ouvre les yeux, Voyageur. Le monde avait besoin de force."
    ],
    "barde": [
        "...Ecoute.",
        "Il y a un son, la. Entre les mondes. Tu l'entends?",
        "C'est la Membrane qui vibre. Ou c'est toi qui chantes sans le savoir.",
        "Ouvre les yeux, Voyageur. Le monde avait besoin d'une voix."
    ],
    "eclaireur": [
        "...Ne bouge pas.",
        "La brume est dense ici. Mais tu vois deja les contours, n'est-ce pas?",
        "Toujours a observer avant d'agir. C'est pour ca que tu es la.",
        "Ouvre les yeux, Voyageur. Le monde avait besoin d'un regard."
    ]
}
```

### Interactions joueur

| Input | Condition | Action |
|-------|-----------|--------|
| Tap / Clic | Texte en cours de typewrite | Skip typewriter (affiche tout le texte) |
| Tap / Clic | Texte affiche complet | Avance au texte suivant |
| Tap / Clic | Dernier texte affiche | Declenche Phase 3 (Eveil) |
| Swipe | N'importe quand | Ignore (pas de swipe ici) |
| Long press (2s) | Flag `intro_seen == true` | Skip toute la scene |

### Game State Changes

```gdscript
# Au debut de SceneEveil
GameManager.run["eveil_timestamp"] = int(Time.get_unix_time_from_system())
GameManager.flags["eveil_started"] = true

# A la fin de SceneEveil
GameManager.flags["eveil_seen"] = true
```

### Skip Mechanic

- **Premiere visite**: Non skippable (aucun hint de skip)
- **Revisites** (`GameManager.flags["eveil_seen"] == true`):
  - Affiche "Toucher 2s pour passer" en bas
  - Long press 2s → fade to white → transition directe

### Timing et Pacing

| Element | Duree |
|---------|-------|
| Delai initial (noir pur) | 2.0s |
| Typewriter speed | 0.03s/char (plus lent que questionnaire) |
| Pause ponctuation | 0.12s |
| Pause entre lignes | 1.5s (auto) ou tap (instant) |
| Flash blanc montee | 2.0s |
| Flash blanc descente | 1.0s |
| Fade vers scene suivante | 0.8s |

---

## SCENE 2: SceneAntreMerlin

### Concept Narratif

L'antre de Merlin. Lieu chaud, intime, encombre de livres et d'artefacts. C'est ici que le joueur:
1. Voit Merlin pour la premiere fois "en vrai"
2. Rencontre Bestiole
3. Decouvre la carte des 7 biomes
4. Recoit sa mission

**Ton**: Chaleureux, emerveille, puis solennel (mission).

### Fichier scene

`res://scenes/SceneAntreMerlin.tscn` — root: `Control` (plein ecran)

### Structure de nodes

```
SceneAntreMerlin (Control, PRESET_FULL_RECT)
├── Background (TextureRect, illustration antre)
├── CharacterLayer
│   ├── MerlinSprite (TextureRect ou AnimatedSprite2D)
│   └── BestioleSprite (TextureRect ou AnimatedSprite2D)
├── DialogueCard (Panel, meme style que IntroMerlinDialogue)
│   ├── SpeakerName (Label)
│   ├── DialogueText (RichTextLabel, typewriter)
│   └── ContinueHint (Label, "Toucher pour continuer")
├── MapOverlay (Control, invisible au debut)
│   ├── MapBackground (TextureRect, carte Broceliande stylisee)
│   ├── BiomeNodes (Control)
│   │   ├── BiomeDot_broceliande (TextureButton)
│   │   ├── BiomeDot_landes (TextureButton)
│   │   ├── BiomeDot_cotes (TextureButton)
│   │   ├── BiomeDot_villages (TextureButton)
│   │   ├── BiomeDot_cercles (TextureButton)
│   │   ├── BiomeDot_marais (TextureButton)
│   │   └── BiomeDot_collines (TextureButton)
│   ├── BiomeInfoPanel (Panel, detail du biome selectionne)
│   │   ├── BiomeName (Label)
│   │   ├── BiomeDescription (RichTextLabel)
│   │   └── BiomeConfirmButton (Button, "Partir vers...")
│   └── AssignedBiomeHighlight (Sprite2D, halo dore)
├── MissionCard (Panel, invisible au debut)
│   ├── MissionTitle (Label)
│   ├── MissionText (RichTextLabel)
│   └── MissionAcceptButton (Button)
├── Audio
│   ├── AmbianceAntre (AudioStreamPlayer, feu de cheminee)
│   ├── SfxBestioleAppear (AudioStreamPlayer)
│   ├── SfxMapReveal (AudioStreamPlayer)
│   └── VoiceBlip (AudioStreamPlayer)
└── AspectReveal (Control, invisible)
    ├── AspectIcon (TextureRect)
    ├── AspectName (Label)
    └── AspectDescription (RichTextLabel)
```

### Phases de la scene

```
PHASE A: ACCUEIL MERLIN (0s - 30s)
───────────────────────────────────
[0.0s]  Fade in sur l'antre de Merlin
[1.0s]  MerlinSprite idle animation
[2.0s]  Dialogue Merlin: accueil personnalise (utilise chronicle_name + classe)
[---]   3-4 lignes de dialogue, tap pour avancer

PHASE B: RENCONTRE BESTIOLE (30s - 60s)
────────────────────────────────────────
[---]   Merlin annonce Bestiole
[---]   SfxBestioleAppear joue
[---]   BestioleSprite entre en scene (animation: timide, puis approche)
[---]   Dialogue Merlin: presente Bestiole
[---]   Dialogue Merlin: explique les 3 Oghams de depart (beith, luis, quert)
[---]   Bestiole reagit (petit bounce ou trille)

PHASE C: ASPECT DOMINANT (60s - 80s)
─────────────────────────────────────
[---]   Merlin observe le Voyageur
[---]   AspectReveal apparait avec animation
[---]   Revele l'aspect dominant (Corps/Ame/Monde) base sur le profil
[---]   Explication courte de ce que cela signifie pour le gameplay
[---]   Merlin: "Ton [animal] guide tes pas."

PHASE D: CARTE DES BIOMES (80s - 140s)
───────────────────────────────────────
[---]   Merlin: "Laisse-moi te montrer ce qui reste..."
[---]   MapOverlay fade in (animation reveal de la carte)
[---]   Les 7 biomes apparaissent un par un (stagger 0.3s chacun)
[---]   Le biome assigne par la classe pulse/brille
[---]   Joueur peut explorer les biomes (tap sur chaque point)
[---]   Le biome assigne est pre-selectionne
[---]   Joueur PEUT choisir un autre biome (voir mecanique ci-dessous)
[---]   Confirmation du biome

PHASE E: MISSION BRIEFING (140s - 170s)
────────────────────────────────────────
[---]   MapOverlay fade out
[---]   MissionCard fade in
[---]   Merlin donne la mission (adaptee au biome choisi)
[---]   Joueur accepte (bouton "Je pars")
[---]   Transition vers TransitionBiome
```

### Dialogues de Merlin (Phase A — Accueil)

```gdscript
# %s = chronicle_name, classe determinee
const ACCUEIL_DIALOGUES := {
    "druide": [
        "Ah, %s. La brume m'avait prevenu de ton arrivee.",
        "Un druide... cela faisait longtemps. Les pierres vont se souvenir de toi.",
        "Bienvenue dans mon antre. C'est modeste, mais c'est... eh bien, c'est tout ce qu'il reste."
    ],
    "guerrier": [
        "%s. Tu frappes fort aux portes de la realite, tu sais.",
        "Un guerrier traverse ma Membrane. Les echos n'ont pas fini de vibrer.",
        "Installe-toi. Mon antre est en desordre, mais il tient debout. C'est deja beaucoup."
    ],
    "barde": [
        "%s... ce nom chante bien, tu ne trouves pas?",
        "Un barde! Enfin quelqu'un qui sait que les mots sont plus tranchants que les epees.",
        "Mon antre manquait de musique. Les livres sont silencieux depuis trop longtemps."
    ],
    "eclaireur": [
        "Je te voyais venir, %s. Mais toi, tu m'avais deja repere, hein?",
        "Un eclaireur. Tes yeux verront des choses que les autres manquent.",
        "Mon antre cache plus qu'il ne montre. Tu t'en rendras compte."
    ]
}
```

### Dialogues de Merlin (Phase B — Bestiole)

```gdscript
const BESTIOLE_DIALOGUES := [
    "Oh, et... il y a quelqu'un que tu dois rencontrer.",
    "N'aie pas peur. Elle est timide, mais elle te sent deja.",
    "Voici Bestiole. Ne lui demande pas ce qu'elle est. Personne ne sait vraiment.",
    "Elle porte en elle trois Oghams: Beith le Bouleau, Luis le Sorbier, et Quert le Pommier.",
    "Prends-en soin. Elle est... plus importante que tu ne le crois."
]
```

### Dialogues de Merlin (Phase C — Aspect Dominant)

```gdscript
const ASPECT_DIALOGUES := {
    "Corps": {
        "animal": "Sanglier",
        "symbol": "spirale",
        "lines": [
            "Je vois quelque chose en toi...",
            "Le Sanglier te guide. Force, endurance, le poids du reel.",
            "Ton Corps parle avant ton esprit. C'est un don."
        ]
    },
    "Ame": {
        "animal": "Corbeau",
        "symbol": "triskell",
        "lines": [
            "Hmm... interessant.",
            "Le Corbeau plane au-dessus de toi. Esprit, vision, les choses cachees.",
            "Ton Ame voit au-dela du visible. Mefie-toi de ce qu'elle trouve."
        ]
    },
    "Monde": {
        "animal": "Cerf",
        "symbol": "croix_celtique",
        "lines": [
            "Ah, je comprends maintenant.",
            "Le Cerf marche a tes cotes. Liens, harmonie, la place parmi les autres.",
            "Ton Monde est ta force. Les gens te suivront. Ou te craindront."
        ]
    }
}
```

### Mecanique: Determination de l'Aspect Dominant

```gdscript
func _determine_aspect_dominant(profile: Dictionary) -> String:
    var traits := profile.get("traits", {})
    var verb := profile.get("verb_affinity", {})

    # Corps = FORCE + courage + controle
    var corps_score: int = int(verb.get("FORCE", 0)) + int(traits.get("courage", 0)) + int(traits.get("controle", 0))

    # Ame = LOGIQUE + curiosite + verite
    var ame_score: int = int(verb.get("LOGIQUE", 0)) + int(traits.get("curiosite", 0)) + int(traits.get("verite", 0))

    # Monde = FINESSE + compassion + orgueil (oui, l'orgueil est social)
    var monde_score: int = int(verb.get("FINESSE", 0)) + int(traits.get("compassion", 0)) + int(traits.get("orgueil", 0))

    if corps_score >= ame_score and corps_score >= monde_score:
        return "Corps"
    elif ame_score >= monde_score:
        return "Ame"
    else:
        return "Monde"
```

### Mecanique: Attribution de Biome par Classe

Chaque classe a un biome "naturel" assigne, mais le joueur peut le changer.

```gdscript
const CLASS_TO_BIOME := {
    "druide": "broceliande",
    "guerrier": "landes",
    "barde": "villages",
    "eclaireur": "cotes"
}

const BIOMES := {
    "broceliande": {
        "id": "broceliande",
        "name": "Foret de Broceliande",
        "subtitle": "Le Coeur Qui Bat Encore",
        "ogham_dominant": "duir",
        "gardien": "Maelgwn",
        "season_forte": "automne",
        "description": "Le centre du monde. Brume doree, arbres millenaires, le dernier lieu ou l'Awen coule encore.",
        "color": Color(0.2, 0.45, 0.15),    # vert profond
        "map_position": Vector2(0.5, 0.4),   # position relative sur la carte
        "aspect_lie": "Vigueur"
    },
    "landes": {
        "id": "landes",
        "name": "Landes de Bruyere",
        "subtitle": "Le Souffle Qui S'Essouffle",
        "ogham_dominant": "onn",
        "gardien": "Talwen",
        "season_forte": "hiver",
        "description": "L'immensite de bruyere et de granite. Le vent ne s'arrete jamais, mais il faiblit.",
        "color": Color(0.55, 0.3, 0.55),    # mauve bruyere
        "map_position": Vector2(0.25, 0.2),
        "aspect_lie": "Esprit"
    },
    "cotes": {
        "id": "cotes",
        "name": "Cotes Sauvages",
        "subtitle": "La Mer Qui Se Retire",
        "ogham_dominant": "nuin",
        "gardien": "Bran",
        "season_forte": "ete",
        "description": "La frontiere entre la terre et l'inconnu. La mer EST la Membrane, rendue visible.",
        "color": Color(0.25, 0.4, 0.6),     # bleu-gris
        "map_position": Vector2(0.1, 0.5),
        "aspect_lie": "Ressources"
    },
    "villages": {
        "id": "villages",
        "name": "Villages Celtes",
        "subtitle": "La Derniere Chaleur",
        "ogham_dominant": "gort",
        "gardien": "Azenor",
        "season_forte": "printemps",
        "description": "Ce qui reste de l'humanite. Des maisons de pierre, des feux qui brulent, la vie qui s'obstine.",
        "color": Color(0.6, 0.45, 0.25),    # ocre
        "map_position": Vector2(0.65, 0.6),
        "aspect_lie": "Faveur"
    },
    "cercles": {
        "id": "cercles",
        "name": "Cercles de Pierres",
        "subtitle": "Le Temps Qui Hesite",
        "ogham_dominant": "huath",
        "gardien": "Keridwen",
        "season_forte": "samhain",
        "description": "3000 menhirs formant un clavier cosmique. Le temps y hesitent et les druides oublient.",
        "color": Color(0.5, 0.45, 0.5),     # gris-rose
        "map_position": Vector2(0.35, 0.7),
        "aspect_lie": "Esprit"
    },
    "marais": {
        "id": "marais",
        "name": "Marais des Korrigans",
        "subtitle": "Ce Qui Attend en Dessous",
        "ogham_dominant": "muin",
        "gardien": "Gwydion",
        "season_forte": "lughnasadh",
        "description": "Le lieu le plus dangereux. La Membrane y est la plus fine. Le Vide pousse.",
        "color": Color(0.15, 0.25, 0.15),   # vert sombre
        "map_position": Vector2(0.8, 0.35),
        "aspect_lie": "Vigueur"
    },
    "collines": {
        "id": "collines",
        "name": "Collines aux Dolmens",
        "subtitle": "La Memoire Qui S'Effrite",
        "ogham_dominant": "ioho",
        "gardien": "Elouan",
        "season_forte": "yule",
        "description": "Le lieu le plus ancien. Les os de la terre. Les dolmens captent les echos de l'Annwn.",
        "color": Color(0.4, 0.5, 0.3),      # vert pale
        "map_position": Vector2(0.7, 0.15),
        "aspect_lie": "Faveur"
    }
}
```

### Mecanique: Selection de Biome (Phase D)

**Comportement par defaut:**
1. La carte s'affiche avec les 7 biomes
2. Le biome assigne par la classe est pre-selectionne (halo dore, pulse animation)
3. Merlin dit: "La [biome name] t'appelle. C'est la que ta voie mene."

**Exploration libre:**
1. Le joueur peut taper sur n'importe quel biome
2. Un panel d'info apparait avec: nom, sous-titre, description (2 lignes), gardien
3. Le biome assigne reste marque (icone etoile ou halo)

**Changement de biome:**
1. Si le joueur tape sur un biome different du biome assigne
2. Le BiomeInfoPanel affiche le detail + bouton "Partir vers [biome]"
3. Merlin reagit: "Hmm. [biome] au lieu de [biome_assigne]? Ton choix, Voyageur."
4. Le joueur confirme → le biome change
5. **Note**: aucun malus/bonus. Le choix est purement narratif.

**Confirmation:**
1. Le joueur appuie sur "Partir vers [biome choisi]"
2. La carte se replie (animation)
3. Le biome est enregistre dans GameManager.run

```gdscript
# Quand le joueur confirme le biome
func _on_biome_confirmed(biome_id: String) -> void:
    var biome_data: Dictionary = BIOMES[biome_id]
    var was_assigned: bool = (biome_id == CLASS_TO_BIOME.get(player_class, ""))

    GameManager.run["biome"] = {
        "id": biome_data["id"],
        "name": biome_data["name"],
        "assigned_by_class": was_assigned,
        "ogham_dominant": biome_data["ogham_dominant"],
        "gardien": biome_data["gardien"],
        "season_forte": biome_data["season_forte"],
    }
```

### Mecanique: Oghams de Depart (Bestiole)

Les 3 Oghams starter (beith, luis, quert) sont deja definis dans `MerlinConstants.OGHAM_STARTER_SKILLS`. La scene ne modifie pas les skills — elle les **presente** narrativement.

**Presentation visuelle:**

```
┌──────────────────────────────────────┐
│  Bestiole porte 3 Oghams:           │
│                                      │
│  ◆ Beith (Bouleau)  — Revelation    │
│    "Revele les effets d'un choix"    │
│                                      │
│  ◆ Luis (Sorbier)   — Protection    │
│    "Reduit les degats de 30%"        │
│                                      │
│  ◆ Quert (Pommier)  — Guerison      │
│    "Soigne l'aspect le plus bas"     │
│                                      │
│  [Compris]                           │
└──────────────────────────────────────┘
```

Ce n'est qu'un affichage informatif. Pas de choix. Les skills sont deja equipes dans `state.bestiole.skills_equipped`.

### Mecanique: Mission Briefing (Phase E)

La mission est generee en fonction du biome choisi et de la classe.

```gdscript
const MISSION_TEMPLATES := {
    "broceliande": {
        "title": "Le Souffle de Barenton",
        "text": "La Fontaine de Barenton s'assombrit. Trouve ce qui la trouble et ramene la clarte.",
        "mission_type": "restore",
        "total_steps": 5,
    },
    "landes": {
        "title": "Le Chant des Cairns",
        "text": "Les cairns du vent se taisent. Retrouve la melodie perdue avant que le silence ne gagne.",
        "mission_type": "find",
        "total_steps": 4,
    },
    "cotes": {
        "title": "Le Signal de Sein",
        "text": "L'ile de Sein ne repond plus. Navigue jusqu'au phare et decouvre pourquoi.",
        "mission_type": "reach",
        "total_steps": 5,
    },
    "villages": {
        "title": "Le Puits des Souhaits",
        "text": "L'eau du puits sacre est tarie. Aide le village a retrouver sa source.",
        "mission_type": "restore",
        "total_steps": 4,
    },
    "cercles": {
        "title": "L'Alignement Perdu",
        "text": "Les menhirs de Carnac sont desalignes. Le temps se detraque. Restaure l'accord.",
        "mission_type": "align",
        "total_steps": 6,
    },
    "marais": {
        "title": "Le Tertre du Silence",
        "text": "Le chef des korrigans ne rit plus. Descends dans le tertre et affronte le Vide.",
        "mission_type": "confront",
        "total_steps": 5,
    },
    "collines": {
        "title": "La Voix de l'If",
        "text": "L'if millenaire perd ses branches. Ecoute ses dernieres paroles avant qu'il ne se taise.",
        "mission_type": "listen",
        "total_steps": 4,
    }
}
```

**Quand le joueur accepte la mission:**

```gdscript
func _on_mission_accepted() -> void:
    var biome_id: String = GameManager.run["biome"]["id"]
    var template: Dictionary = MISSION_TEMPLATES[biome_id]

    GameManager.run["mission_briefing"] = template["text"]

    # Pre-configure la mission dans le store pour TriadeGame
    # (sera formellement lancee par TRIADE_START_RUN)
    GameManager.run["mission_template"] = {
        "type": template["mission_type"],
        "title": template["title"],
        "total": template["total_steps"],
    }
```

### Game State Changes (complet, Phase A → E)

```gdscript
# Phase A
GameManager.flags["antre_visited"] = true

# Phase B
GameManager.run["bestiole_met"] = true

# Phase C
GameManager.run["traveler_profile"]["aspect_dominant"] = "Corps"|"Ame"|"Monde"

# Phase D
GameManager.run["biome"] = { ... }  # voir ci-dessus

# Phase E
GameManager.run["mission_briefing"] = String
GameManager.run["mission_template"] = { ... }
```

### Interactions joueur (resume)

| Phase | Input | Action |
|-------|-------|--------|
| A (Accueil) | Tap | Avance dialogue / Skip typewriter |
| B (Bestiole) | Tap | Avance dialogue |
| B (Bestiole) | Tap sur Bestiole sprite | Animation react (trille, bounce) |
| C (Aspect) | Tap | Avance dialogue |
| D (Carte) | Tap sur biome dot | Affiche info du biome |
| D (Carte) | Tap "Partir vers..." | Confirme le biome |
| D (Carte) | Tap ailleurs | Ferme le panel info |
| E (Mission) | Tap | Avance dialogue mission |
| E (Mission) | Tap "Je pars" | Accepte mission, transition |

---

## SCENE 3: TransitionBiome

### Concept Narratif

Animation de voyage entre l'antre de Merlin et le biome choisi. La camera "survole" la carte de Broceliande, montrant le chemin parcouru, avec un texte narratif qui introduit le biome.

**Ton**: Epique mais melancolique, suspense.

### Fichier scene

`res://scenes/TransitionBiome.tscn` — root: `Control` (plein ecran)

### Structure de nodes

```
TransitionBiome (Control, PRESET_FULL_RECT)
├── MapCanvas (TextureRect, carte de Broceliande vue d'en haut)
├── TravelPath (Line2D, trace du chemin)
├── TravelerIcon (Sprite2D, petite icone qui se deplace sur la carte)
├── NarrativeOverlay (Panel, en bas de l'ecran)
│   ├── NarrativeText (RichTextLabel)
│   └── BiomeArrivalName (Label, apparait a la fin)
├── FogOfWar (ColorRect + shader, brume autour du chemin)
├── Audio
│   ├── TravelMusic (AudioStreamPlayer, theme de voyage)
│   └── SfxArrival (AudioStreamPlayer)
└── SkipHint (Label, "Toucher pour accelerer")
```

### Sequence d'evenements

```
PHASE 1: DEPART (0s - 3s)
─────────────────────────
[0.0s]  Carte visible, zoom sur l'antre de Merlin (centre)
[0.5s]  TravelerIcon apparait a la position de l'antre
[1.0s]  TravelMusic demarre (theme doux, celtique)
[2.0s]  Camera commence a zoomer out doucement

PHASE 2: VOYAGE (3s - 12s)
──────────────────────────
[---]   TravelerIcon se deplace le long de TravelPath
[---]   TravelPath se dessine progressivement (Line2D animated)
[---]   FogOfWar s'ecarte sur le passage du voyageur
[---]   NarrativeText affiche 2-3 lignes en typewriter
[---]   Camera suit le TravelerIcon avec un leger lag

PHASE 3: ARRIVEE (12s - 15s)
─────────────────────────────
[---]   TravelerIcon arrive au biome
[---]   Camera zoom sur le biome
[---]   SfxArrival joue
[---]   BiomeArrivalName apparait en grand (fade in + scale)
[---]   Ecran fade vers le biome (couleur dominante du biome)
[---]   Transition vers TriadeGame
```

### Textes Narratifs de Voyage

```gdscript
const TRAVEL_NARRATIVES := {
    "broceliande": [
        "La brume s'ecarte devant toi.",
        "Les arbres murmurent. Ils savent que tu approches.",
        "Broceliande t'attend."
    ],
    "landes": [
        "Le vent se leve. Il vient de loin.",
        "La bruyere ondule comme une mer terrestre.",
        "Les Landes t'appellent par ton silence."
    ],
    "cotes": [
        "L'air change. Le sel. L'embruns.",
        "L'horizon s'ouvre. Ou finit la terre? Ou commence le mystere?",
        "Les Cotes Sauvages t'attendent au bord du monde."
    ],
    "villages": [
        "De la fumee, au loin. Des voix.",
        "La pierre chaude. Le feu qui craque. La vie qui s'obstine.",
        "Les Villages Celtes gardent encore une braise."
    ],
    "cercles": [
        "Le silence se densifie. Comme si l'air ecoutait.",
        "Les pierres emergent du sol. Elles t'attendaient.",
        "Les Cercles de Pierres vibrent a ton approche."
    ],
    "marais": [
        "La brume s'epaissit. Le sol mollit.",
        "Des lueurs dansent. Les feux follets hesitent.",
        "Les Marais des Korrigans te laissent entrer. Pour l'instant."
    ],
    "collines": [
        "Le terrain monte. L'herbe rase sous tes pieds.",
        "Les dolmens apparaissent, sentinelles silencieuses.",
        "Les Collines aux Dolmens se souviennent de ceux qui passent."
    ]
}
```

### Path Generation (chemin de voyage)

Le chemin est genere entre la position de l'antre (centre de la carte) et la position du biome cible.

```gdscript
func _generate_travel_path(biome_id: String) -> PackedVector2Array:
    var map_size: Vector2 = MapCanvas.size
    var start: Vector2 = map_size * Vector2(0.5, 0.45)  # Antre de Merlin (centre)
    var end: Vector2 = map_size * BIOMES[biome_id]["map_position"]

    # Generer un chemin courbe avec 2-3 points intermediaires
    var points: PackedVector2Array = []
    points.append(start)

    var mid1: Vector2 = start.lerp(end, 0.33) + Vector2(
        randf_range(-40, 40), randf_range(-40, 40)
    )
    var mid2: Vector2 = start.lerp(end, 0.66) + Vector2(
        randf_range(-40, 40), randf_range(-40, 40)
    )
    points.append(mid1)
    points.append(mid2)
    points.append(end)

    return points
```

### Interactions joueur

| Input | Condition | Action |
|-------|-----------|--------|
| Tap | Voyage en cours | Accelere l'animation (x2 speed) |
| Tap | Deja accelere | Saute directement a l'arrivee |
| Swipe | N'importe quand | Ignore |

### Game State Changes

```gdscript
# Aucun changement d'etat ici — tout est visuel
# La scene ne fait que transitionner vers TriadeGame

func _on_transition_complete() -> void:
    get_tree().change_scene_to_file("res://scenes/TriadeGame.tscn")
```

### Timing et Pacing

| Element | Duree normale | Duree acceleree |
|---------|---------------|-----------------|
| Depart (zoom out) | 3.0s | 1.5s |
| Voyage (path) | 8.0s | 3.0s |
| Arrivee (zoom in + fade) | 4.0s | 2.0s |
| **Total** | **15.0s** | **6.5s** |

---

## FLUX DE SCENE COMPLET

### Scene Routing

```gdscript
# Dans IntroMerlinDialogue._end_demo() — MODIFIER:
# Ancien: NEXT_SCENE := "res://scenes/TriadeGame.tscn"
# Nouveau:
const NEXT_SCENE := "res://scenes/SceneEveil.tscn"

# Dans SceneEveil._on_eveil_complete():
get_tree().change_scene_to_file("res://scenes/SceneAntreMerlin.tscn")

# Dans SceneAntreMerlin._on_mission_accepted():
get_tree().change_scene_to_file("res://scenes/TransitionBiome.tscn")

# Dans TransitionBiome._on_transition_complete():
get_tree().change_scene_to_file("res://scenes/TriadeGame.tscn")
```

### Data Flow Diagram

```
IntroMerlinDialogue
│
│  Ecrit dans GameManager.run:
│  - chronicle_name
│  - traveler_profile (class, traits, verbs, hooks)
│  - merlin_memory
│
▼
SceneEveil
│
│  Ecrit dans GameManager:
│  - run.eveil_timestamp
│  - flags.eveil_seen
│
▼
SceneAntreMerlin
│
│  Ecrit dans GameManager:
│  - run.bestiole_met
│  - run.traveler_profile.aspect_dominant
│  - run.biome (id, name, gardien, ogham, season)
│  - run.mission_briefing
│  - run.mission_template
│  - flags.antre_visited
│
▼
TransitionBiome
│
│  Lit depuis GameManager.run:
│  - biome (pour position, couleur, textes)
│
│  N'ecrit rien.
│
▼
TriadeGame
│
│  Lit depuis GameManager.run:
│  - biome → theming, card generation, atmosphere
│  - mission_template → init mission dans MerlinStore
│  - aspect_dominant → oriente les premieres cartes LLM
│  - chronicle_name → affichage UI
```

---

## CONSIDERATIONS TECHNIQUES

### Performance

- **SceneEveil**: Tres legere. Que du texte et des particules simples. Pas de textures lourdes.
- **SceneAntreMerlin**: Moyenne. Une illustration de fond + sprites. La carte des biomes peut etre une texture unique avec des hotspots.
- **TransitionBiome**: Legere. Une texture de carte + Line2D + sprite. Le shader de brume est le plus couteux.

### Audio

| Scene | Ambiance | SFX |
|-------|----------|-----|
| SceneEveil | Drone grave (loop) | Blips voix, flash d'eveil |
| SceneAntreMerlin | Feu de cheminee (loop) | Bestiole trille, map reveal, mission accept |
| TransitionBiome | Theme voyage (one-shot) | Arrivee |

**Note**: Utiliser ACVoicebox pour tous les textes de Merlin si disponible (meme preset que IntroMerlinDialogue: robotic, low pitch 2.5).

### Mobile / Touch

- Tous les taps fonctionnent sur mobile
- Les biome dots sur la carte doivent avoir une zone de tap minimum de 48x48px
- Le skip par long press (SceneEveil) utilise `Input.is_action_pressed` avec timer
- Pas de swipe dans ces scenes (eviter confusion avec le gameplay Triade)

### Accessibilite

- Tout texte est dans des RichTextLabel (supporte les tailles custom)
- Les couleurs de biome respectent un contraste minimum sur le fond de carte
- Le skip existe pour les revisites
- L'auto-avance (5s timeout) permet de traverser sans interaction active

---

## PLAN D'IMPLEMENTATION

### Phase 1: SceneEveil (1-2h)
1. Creer la scene `.tscn` avec la structure de nodes
2. Script GDScript avec la sequence temporelle
3. Dialogues adaptes a la classe
4. Shader simple pour l'ondulation
5. Particules (lucioles)
6. Audio (drone + blip)

### Phase 2: SceneAntreMerlin (3-4h)
1. Scene `.tscn` avec toutes les layers
2. Phase A: Dialogues Merlin (reutiliser typewriter de IntroMerlinDialogue)
3. Phase B: Animation Bestiole + presentation Oghams
4. Phase C: Calcul et affichage aspect dominant
5. Phase D: Carte interactive des biomes (7 hotspots + panel info)
6. Phase E: Mission briefing + accept
7. Audio (ambiance + SFX)

### Phase 3: TransitionBiome (1-2h)
1. Scene `.tscn` avec carte et path
2. Animation du voyage (Line2D + tween)
3. Textes narratifs en typewriter
4. Camera suivie
5. Fade de transition

### Phase 4: Integration (1h)
1. Modifier `IntroMerlinDialogue.NEXT_SCENE`
2. Verifier le data flow GameManager.run
3. Ajouter lecture des nouvelles donnees dans TriadeGameController
4. Tester le flux complet bout en bout

---

## OPEN QUESTIONS

1. **Assets visuels**: L'illustration de l'antre de Merlin et la carte de Broceliande existent-elles deja, ou faut-il les creer / utiliser des placeholders?

2. **Animation Bestiole**: Quel est le design visuel actuel de Bestiole? AnimatedSprite2D avec spritesheet, ou simple TextureRect?

3. **Sauvegarde mid-transition**: Si le joueur quitte pendant SceneAntreMerlin, doit-on sauvegarder la progression des phases (A/B/C/D/E) ou recommencer la scene?

4. **Revisites (New Game+)**: Lors d'un second run, le joueur passe-t-il par les 3 scenes a nouveau, ou seulement par une version abregee?

5. **Biome override par difficulte**: Certains biomes (marais, collines) pourraient-ils etre "verrouilles" pour les premiers runs et debloques progressivement?

---

*Document de specification — M.E.R.L.I.N.*
*Game Designer Agent*
*Version: 1.0 — 2026-02-08*
