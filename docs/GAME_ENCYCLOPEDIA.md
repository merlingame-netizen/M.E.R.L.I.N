# M.E.R.L.I.N. — ENCYCLOPEDIE EXHAUSTIVE DU JEU

> **Version**: 1.0 | **Date**: 2026-03-14
> **Source de verite**: Ce document consolide TOUTES les informations du jeu.
> **Game Design Bible**: `docs/GAME_DESIGN_BIBLE.md` v2.4 reste la reference design.

---

## TABLE DES MATIERES

1. [Vue d'ensemble](#1-vue-densemble)
2. [Scene Flow complet](#2-scene-flow-complet)
3. [Scenes detaillees](#3-scenes-detaillees)
4. [Systeme de vie](#4-systeme-de-vie)
5. [Les 5 Factions](#5-les-5-factions)
6. [Les 18 Oghams](#6-les-18-oghams)
7. [Systeme de cartes](#7-systeme-de-cartes)
8. [Les 8 champs lexicaux et minigames](#8-les-8-champs-lexicaux-et-minigames)
9. [Les 8 biomes](#9-les-8-biomes)
10. [PNJ recurrents](#10-pnj-recurrents)
11. [Systeme de promesses](#11-systeme-de-promesses)
12. [MOS — Merlin Omniscient System](#12-mos--merlin-omniscient-system)
13. [Pipeline d'effets](#13-pipeline-deffets)
14. [Arbre de talents (Arbre de Vie)](#14-arbre-de-talents-arbre-de-vie)
15. [Anam — Monnaie cross-run](#15-anam--monnaie-cross-run)
16. [Evenements calendaires](#16-evenements-calendaires)
17. [Fins du jeu (~10-15)](#17-fins-du-jeu-10-15)
18. [Merlin — Personnage et dialogue](#18-merlin--personnage-et-dialogue)
19. [Profil joueur](#19-profil-joueur)
20. [Systeme de sauvegarde](#20-systeme-de-sauvegarde)
21. [Map/Run System](#21-maprun-system)
22. [Difficulte](#22-difficulte)
23. [Pipeline LLM Multi-Brain](#23-pipeline-llm-multi-brain)
24. [Systeme visuel](#24-systeme-visuel)
25. [Systeme audio](#25-systeme-audio)
26. [Shaders](#26-shaders)
27. [Autoloads](#27-autoloads)
28. [Architecture technique](#28-architecture-technique)
29. [Controles et inputs](#29-controles-et-inputs)

---

## 1. VUE D'ENSEMBLE

**M.E.R.L.I.N.** (Memoire Eternelle des Recits et Legendes d'Incarnations Narratives) est un roguelite narratif a cartes dans l'univers celtique breton. Chaque run est unique, pilotee par un LLM local (Qwen 3.5 via Ollama).

- **Genre**: Roguelite narratif a cartes
- **Moteur**: Godot 4.5 (GL Compatibility)
- **Esthetique**: Terminal CRT phosphore vert sur fond noir
- **Audio**: 100% procedural (zero fichiers audio sauf musique)
- **IA**: Multi-Brain LLM heterogene (Narrator 4B + GM 2B + Judge 0.8B)
- **Langue**: Francais uniquement

### Core Loop
```
Hub 2D → Biome → 3D rail (5-15s collecte) → [fondu] → Carte (3 options) → Ogham? → Choix → Minigame overlay → Score → Effets → [fondu] → 3D → [repeter] → Fin → Hub
```

### Philosophie
- Le joueur n'est PAS un heros sauvant le monde — c'est un voyageur observant un monde en flux
- Merlin est ancien, fatigue, et emotionnellement investi
- Chaque choix a un poids narratif — Merlin se souvient
- Les factions representent des visions du monde legitimes — pas de "bonne" fin
- Les Oghams sont des mysteres, pas juste des power-ups

---

## 2. SCENE FLOW COMPLET

```
START
  ↓
IntroCeltOS (Boot CRT, 6-10s)
  ↓ pixel_transition
MenuPrincipal (New Game / Continue / Options)
  ├─→ NEW GAME:
  │    IntroPersonalityQuiz (10 questions, 30-60s)
  │      ↓
  │    SceneRencontreMerlin (1ere rencontre Merlin, JAMAIS repetee)
  │      ↓
  │    HubAntre
  │
  ├─→ CONTINUE:
  │    SelectionSauvegarde (3 slots)
  │      ↓
  │    HubAntre
  │
  ├─→ OPTIONS: MenuOptions
  ├─→ CALENDAR: Calendar
  └─→ COLLECTION: Collection

HubAntre (Hub central 2D)
  ├─→ ArbreDeVie (Arbre de talents/Oghams)
  ├─→ Calendar (Evenements)
  ├─→ Collection (Codex cartes)
  ├─→ MapMonde (Carte du monde, progression)
  └─→ PARTIR (bouton):
       BiomeRadial (selection biome)
         ↓
       TransitionBiome (6 phases, 15-20s, prefetch LLM)
         ↓
       MerlinGame (boucle de gameplay, 8-40 cartes)
         ↓ (fin de run: victoire ou mort)
       [Ecran de fin / resultats]
         ↓
       HubAntre (retour au hub)
```

### Scenes legacy/speciales
- `BroceliandeForest3D.tscn` — Marche 3D on-rails (en cours d'integration)
- `IntroTutorial.tscn` — Tutoriel diegetique
- `PixelArtShowcase.tscn` — Scene de reference debug
- `ScreenshotRunner.tscn` — Outil de screenshots batch

---

## 3. SCENES DETAILLEES

### 3.1 IntroCeltOS — Boot CRT
**Script**: `scripts/IntroCeltOS.gd`

3 phases:
1. **Phase 1** (6s): 8 lignes de boot en cascade, stagger 0.06s, SFX `boot_line`
2. **Phase 2** (3-4s): Logo CeltOS en blocs Tetris tombants, SFX `block_land`
3. **Phase 3** (2s): Barre de chargement + warmup LLM async

- ESC: skip vers MenuPrincipal
- Musique: Tri Martolod (intro)
- Couleurs: `phosphor_dim` → `amber` transition

### 3.2 MenuPrincipal
**Script**: `scripts/MenuPrincipalMerlin.gd`

Elements:
- **Titre**: "M  E  R  L  I  N" (VT323, espacement)
- **3 boutons principaux**: New Game → Quiz | Continue → Sauvegarde | Options
- **4 boutons coin** (52×52): Calendar, Collections, Map, LLM Status
- **Particules saisonnieres**: Neige (hiver), Feuilles (automne), Pluie (ete)
- **12 lucioles** ambiantes (phase-based drift)
- **Horloge** (coin haut-gauche, maj 1s)
- **Indicateur LLM** (connectivite Ollama)
- **Esthetique**: Parchemin Mystique Breton (paper 0.96/0.945/0.905, encre 0.22/0.18/0.14)

Animations: hover → scale 1.1 + color shift (200ms), mist pulsing

### 3.3 IntroPersonalityQuiz
**Script**: `scripts/IntroPersonalityQuiz.gd`

Style Pokemon Mystery Dungeon:
- **10 questions** avec 4 choix chacune
- **4 axes**: Approche (prudent↔audacieux), Relation (solitaire↔social), Esprit (analytique↔intuitif), Coeur (pragmatique↔compassionnel)
- **8 archetypes resultants**: Gardien, Explorateur, Sage, Heros, Guerisseur, Stratege, Mystique, Guide
- Chaque choix modifie les axes (ex: {"approche": +2, "esprit": -1})
- Animation: questions fade-in 0.8s, choix cascade 0.15s stagger
- Clavier: 1/2/3/4 pour les choix, ESC retour menu

### 3.4 SceneRencontreMerlin
**Script**: `scripts/SceneRencontreMerlin.gd`

- Premiere et UNIQUE rencontre avec Merlin
- Dialogue adapte a l'archetype du quiz
- Etablit le contexte narratif
- Typewriter effect pour revelation du texte
- Mene au hub (jamais repetee)

### 3.5 HubAntre
**Script**: `scripts/HubAntre.gd`

Elements:
- **Pixel art 2D** en fond
- **4 hotspots** interactifs: Merlin (dialogue), Arbre de Vie, Calendar, Collection
- **Bulle Merlin**: Greeting contextuel (premiere visite vs retours)
- **Bouton PARTIR** → BiomeRadial (selection de biome)
- **8 biomes** avec donnees: nom, sous-titre, couleur GBC, Ogham associe, gardien, saison, difficulte
- **Missions procedurales**: discovery, alliance, recovery, survival

Greetings Merlin:
- Premiere visite: "Bienvenue, %s. Le feu t'attendait."
- Retours: Messages contextuels par biome/saison

### 3.6 TransitionBiome
**Script**: `scripts/TransitionBiome.gd`

6 phases d'animation:
1. **Brume**: Fade depuis la brume, titre du biome
2. **Emergence**: Paysage pixel-art en cascade (grille 32×16, cellules 10px)
3. **Revelation**: Titre + sous-titre complets
4. **Sentier**: Texte narratif "Suis le chemin..."
5. **Voix**: Monologue Merlin + preparation quete
6. **Dissolution**: Fade vers MerlinGame

Features:
- **Meteo**: CLEAR/CLOUDY/RAIN/STORM/MIST/SNOW (overlay visuel)
- **Horloge solaire**: Affiche l'heure (0-23)
- **Prefetch LLM**: Genere monologue + 5 premieres cartes pendant l'animation
- **Arbre de quete** anime (10×14 pixels)

### 3.7 MerlinGame — Boucle de jeu principale
**Scripts**: `scripts/ui/merlin_game_controller.gd`, `scripts/ui/merlin_game_ui.gd`

Layout:
```
┌─────────────────────────────────────────┐
│ [Horloge]                    [Status]   │
│                                         │
│  Pioche │      CARTE        │ Defausse  │
│  (deck) │  ┌─────────────┐  │ (discard) │
│   24    │  │ Illustration │  │    5      │
│         │  │              │  │           │
│         │  │ Speaker Name │  │           │
│         │  │ Texte narr.  │  │           │
│         │  └─────────────┘  │           │
│                                         │
│  [Vie: 75/100]  [Souffle: 3/7]  [Anam] │
│                                         │
│  [A] Option 1  [B] Option 2  [C] Opt 3 │
└─────────────────────────────────────────┘
```

**Timeline par carte**:
1. Pioche carte (0.5s delay)
2. Illustration apparait (1s fade)
3. Titre + nom du speaker (0.5s + 0.3s)
4. Texte narratif en typewriter (3-8s)
5. 3 options apparaissent (0.5s stagger)
6. Joueur lit (~5s) et choisit
7. Minigame (si declenche, 10-30s)
8. Resolution effets (2s animation)
9. Carte vers la defausse
10. Prochaine carte

Controles: A/1, B/2, C/3, ESC (pause), P (pause), J (journal), M (dialogue Merlin)

---

## 4. SYSTEME DE VIE

| Parametre | Valeur |
|-----------|--------|
| **Plage** | 0-100 |
| **Depart** | 100 |
| **Drain passif** | **AUCUN** (supprime) |
| **HEAL_LIFE max** | +18/carte |
| **DAMAGE_LIFE max** | -15/carte (critique: -22) |
| **REST node** | +18 vie, -5 tension |
| **Echec critique** (score 0-20) | -10 vie supplementaire |
| **Reussite critique** (score 95-100) | +5 vie bonus |
| **Seuil bas** (UI warning) | ≤25 |
| **Mort** | vie ≤ 0 → fin de run |

La pression vient des effets de cartes et promesses brisees, PAS d'un drain automatique.

Verification mort: APRES application de tous les effets (Step 9 du pipeline).

---

## 5. LES 5 FACTIONS

Chaque faction a une reputation 0-100, **persistante cross-run**, **sans decay**, **independantes** (pas d'antagonisme automatique).

### Seuils
- **≥50**: Cartes faction-specifiques debloquees
- **≥80**: Fin faction disponible

### Labels de tier
| Rep | Label |
|-----|-------|
| ≥80 | Venere |
| ≥60 | Honore |
| ≥40 | Sympathisant |
| ≥20 | Neutre |
| <20 | Hostile |

### DRUIDES — Sagesse & Nature
- **Theme**: Connaissance, nature, rituels, sagesse ancienne
- **Mots-cles**: druide, ogham, nemeton, chene, barde
- **Oghams associes**: Coll (Reveal), Duir (Boost), Nuin (Narrative)
- **Biomes affinitaires**: Foret de Broceliande, Cercles de Pierres
- **Lore**: Gardiens des anciennes voies. Lisent les oghams graves dans la pierre. Croient que le monde parle a travers la nature.
- **Relation Merlin**: Merlin parle leur langue. Il fut drude lui-meme (fortement implique). A 50+ rep, il devient plus reflexif, citant la philosophie druidique.
- **Role narratif**: Illumination intellectuelle. Choisir la sagesse plutot que l'action.
- **Fin**: "Cercle des Druides" — Accepte dans le cercle eternel. +5 Anam bonus runs futurs.

### ANCIENS — Tradition & Heritage
- **Theme**: Tradition, ancetres, magie ancienne, pouvoir primordial
- **Mots-cles**: ancien, ancetre, tradition, sagesse, menhir, dolmen, eternite
- **Oghams associes**: Ailm (Reveal), Tinne (Boost), Straif (Narrative)
- **Biomes affinitaires**: Collines aux Dolmens, Villages Celtes
- **Lore**: Voix du passe. Se souviennent quand le monde etait jeune. Les menhirs marquent leurs tombes.
- **Relation Merlin**: Merlin se mefie d'eux — ils connaissent des secrets qu'il cache. Mais il les respecte. A 50+ rep: "C'etait comme ca avant."
- **Role narratif**: Devoir envers l'heritage. Respect de l'ordre ancien.
- **Fin**: "Voix des Ancetres" — Les ancetres parlent directement. Gardien de memoire.

### KORRIGANS — Chaos & Malice
- **Theme**: Chaos, malice, tresors caches, tromperie, magie sauvage
- **Mots-cles**: korrigan, fee, feu follet, farce, tresor, lutin
- **Oghams associes**: Onn (Boost), Muin (Special), Huath (Narrative)
- **Biomes affinitaires**: Marais des Korrigans, Cotes Sauvages
- **Lore**: Chaos incarne. Volent, trichent, cachent des tresors dans les tourbières. Mais honorent les accords. Nature sauvage — chaotique mais pas malfaisante.
- **Relation Merlin**: Histoire compliquee avec les Korrigans. A 50+ rep: "Un accord est un accord. Mais lis les petits caracteres."
- **Role narratif**: Liberte hors des regles. Embrasser le risque et le chaos.
- **Fin**: "Monde des Fees" — Entre les mondes. Ni mourir ni vieillir. Ambigue.

### NIAMH — Amour & Autre Monde
- **Theme**: Amour, beaute, nostalgie, Tir na nOg (Autre Monde), guerison
- **Mots-cles**: niamh, eau, lac, amour, nostalgie, sirene, guerison
- **Oghams associes**: Saille (Recovery), Ruis (Recovery), Gort (Protection)
- **Biomes affinitaires**: Iles Mystiques, Cotes Sauvages
- **Lore**: Figure de deesse. Represente l'attrait de l'Autre Monde — beau, eternel, mais alien. Ceux qui l'aiment se perdent souvent dans la nostalgie.
- **Relation Merlin**: Parle d'elle avec affection douce-amere. Il l'a aimee (fortement implique). A 50+ rep: "Elle est belle. Mais la beaute a un prix."
- **Role narratif**: Verite emotionnelle. Honorer l'amour, la compassion, le sacrifice.
- **Fin**: "Tir na nOg" — Invitation a l'Autre Monde. Temps arrete. Eternellement jeune. La voix de Merlin s'estompe: "Au revoir, voyageur."

### ANKOU — Mort & Passage
- **Theme**: Mort, passage, mortalite, nuit, ombres
- **Mots-cles**: ankou, mort, faucheuse, ame, trepas, ombre, passage
- **Oghams associes**: Eadhadh (Protection), Ioho (Special), Ur (Special)
- **Biomes affinitaires**: Collines aux Dolmens, Marais des Korrigans
- **Lore**: Pas malfaisant — inevitable. Collecte les ames, les juge, les guide. Befriender Ankou = accepter la mortalite et trouver la paix.
- **Relation Merlin**: Relation cordiale. Merlin est ancien, comprend la mort. A 50+ rep: "Il vient pour nous tous. Mieux vaut le connaitre."
- **Role narratif**: Acceptation. Embrasser la mort, le sacrifice, le cycle fin/renaissance.
- **Fin**: "Passeur entre les Mondes" — Devenir successeur d'Ankou. Ni vivre ni mourir — exister en transition.

### Periodes in-run (bonus faction)
| Periode | Cartes | Bonus |
|---------|--------|-------|
| Aube | 1-5 | Druides +10% |
| Jour | 6-10 | Anciens, Niamh +10% |
| Crepuscule | 11-15 | Korrigans +10% |
| Nuit | 16-20 | Ankou +15% |

---

## 6. LES 18 OGHAMS

### Regles generales
- **1 seul Ogham active par carte**
- **Cooldown**: Decremente de 1 apres chaque carte
- **3 starters gratuits**: Beith, Luis, Quert (Tier 0, cout 0)
- **Ogham deja possede en run**: +5 Anam
- **Activation**: Step 3 du pipeline (avant choix)
- **Protection**: Step 8 (apres effets, filtre negatifs)

### Tableau complet

#### Starters (Tier 0, Gratuits, Branche Centrale)

| # | Cle | Nom | Arbre | Cat. | Effet | CD | Cout | Lore |
|---|-----|-----|-------|------|-------|----|------|------|
| 1 | `beith` | Bouleau (Birch) | Betula | Reveal | Revele l'effet complet d'1 option | 3 | 0 | Le bouleau ouvre la voie, revelant les chemins caches. Symbole de commencements et protection. |
| 13 | `luis` | Sorbier (Rowan) | Sorbus | Protection | Bloque le 1er effet negatif | 4 | 0 | Le sorbier garde contre la malice. Protege le premier pas du voyageur. |
| 3 | `quert` | Pommier (Apple) | Malus | Recovery | Soin immediat +8 PV | 4 | 0 | La pomme nourrit. De l'Autre Monde, elle apporte subsistance et espoir. |

#### Branche Reveal (Affinite Druides & Anciens)

| # | Cle | Nom | Arbre | Effet | CD | Cout | Faction | Tier | Lore |
|---|-----|-----|-------|-------|----|------|---------|------|------|
| 2 | `coll` | Noisetier (Hazel) | Corylus | Revele les effets des **3 options** | 5 | 80 | Druides | 1 | Le noisetier est gardien de sagesse. Ses noisettes contiennent tout savoir. |
| 5 | `ailm` | Sapin (Fir) | Abies | Predit le **theme + champ lexical** de la prochaine carte | 4 | 60 | Anciens | 1 | Le sapin voit a travers le temps. Les anciens gravaient leurs propheties dans l'ecorce. |

#### Branche Protection (Affinite Niamh & Ankou)

| # | Cle | Nom | Arbre | Effet | CD | Cout | Faction | Tier | Lore |
|---|-----|-----|-------|-------|----|------|---------|------|------|
| 6 | `gort` | Lierre (Ivy) | Hedera | Reduit dommages >10 PV a 5 PV (1 instance) | 6 | 100 | Niamh | 2 | Le lierre s'accroche, enveloppe, protege. Adoucit les coups durs. "L'amour protege." |
| 7 | `eadhadh` | Tremble (Aspen) | Populus | Annule **tous les effets negatifs** de la carte courante | 8 | 150 | Ankou | 1 | Le tremble tremble au moindre vent — mais reste enracine. Pacte avec la Mort. "Accepte tout, ne refuse rien." |

#### Branche Boost (Affinite Druides, Anciens & Korrigans)

| # | Cle | Nom | Arbre | Effet | CD | Cout | Faction | Tier | Lore |
|---|-----|-----|-------|-------|----|------|---------|------|------|
| 8 | `duir` | Chene (Oak) | Quercus | Soin immediat +12 PV | 4 | 70 | Druides | 2 | Le chene est roi des arbres. Les druides s'asseyent sous les chenes pour recevoir des visions. "Le pouvoir guerit." |
| 9 | `tinne` | Houx (Holly) | Ilex | **Double les effets positifs** de l'option choisie | 5 | 120 | Anciens | 2 | Le houx reste vert en hiver. Amplifie, concentre, magnifie. "Le respect multiplie." |
| 11 | `onn` | Ajonc (Gorse) | Ulex | Genere +10 monnaie de biome instantanement | 7 | 90 | Korrigans | 1 | L'ajonc fleurit jaune meme en hiver. Multiplie l'abondance. "Le chaos enrichit." |

#### Branche Narrative (La plus puissante, Tier 3)

| # | Cle | Nom | Arbre | Effet | CD | Cout | Faction | Tier | Lore |
|---|-----|-----|-------|-------|----|------|---------|------|------|
| 10 | `nuin` | Frene (Ash) | Fraxinus | Remplace la **pire option** par une nouvelle (LLM) | 6 | 80 | Druides | 3 | Le frene est l'arbre-monde. Il reecrit le destin. "Le destin plie." |
| 12 | `huath` | Aubepine (Hawthorn) | Crataegus | **Regenere les 3 options** (nouvel appel LLM/FastRoute) | 5 | 100 | Korrigans | 3 | L'aubepine fleurit blanc puis rouge — vie et mort entrelacees. "Le chaos reinitialise." |
| 14 | `straif` | Prunellier (Blackthorn) | Prunus | **Force un twist narratif majeur** dans la prochaine carte via MOS | 10 | 140 | Anciens | 3 | Le prunellier perce le voile. Ses epines blessent la realite. "La verite blesse." |

#### Branche Recovery (Affinite Niamh)

| # | Cle | Nom | Arbre | Effet | CD | Cout | Faction | Tier | Lore |
|---|-----|-----|-------|-------|----|------|---------|------|------|
| 15 | `ruis` | Sureau (Elder) | Sambucus | Soin massif +18 PV **mais** coute 5 monnaie biome | 8 | 130 | Niamh | 3 | Le sureau guerit profondement mais exige paiement. "L'amour coute." |
| 16 | `saille` | Saule (Willow) | Salix | Regenere +8 monnaie biome **et** +3 PV | 6 | 90 | Niamh | 1 | Le saule plie pres de l'eau, flexible et resilient. "La compassion soutient." |

#### Branche Special (Korrigans & Ankou — Chaos & Mort)

| # | Cle | Nom | Arbre | Effet | CD | Cout | Faction | Tier | Lore |
|---|-----|-----|-------|-------|----|------|---------|------|------|
| 17 | `muin` | Vigne (Vine) | Vitis | **Inverse positif/negatif** de l'option. Echec crit = x1.5 bonus; reussite crit = x1.5 malus | 7 | 110 | Korrigans | 2 | La vigne tord, emmele, inverse. Les korrigans venerent cet ogham. "Le chaos inverse." |
| 19 | `ioho` | If (Yew) | Taxus | **Defausse la carte entiere**, genere une nouvelle (appel LLM complet) | 12 | 160 | Ankou | 2 | L'if est la mort ancienne elle-meme. Efface, reinitialise, oblitere. "La mort reinitialise." |
| 20 | `ur` | Bruyere (Heather) | Calluna | Sacrifie 15 PV → gagne +20 monnaie biome **et** x1.3 score buff prochain minigame | 10 | 140 | Ankou | 3 | La bruyere fleurit sur terrain aride. Prospere sur la souffrance. "Le sacrifice eleve." |

### Edge Case: Muin + Echec Critique
Oui, les negatifs deviennent positifs x1.5 — c'est voulu et documente.

---

## 7. SYSTEME DE CARTES

### 4 types de cartes
| Type | Poids | Conditions |
|------|-------|------------|
| `narrative` | 80% | Toujours disponible |
| `event` | 10% | min 3 cartes jouees d'abord |
| `promise` | 5% | min 5 cartes jouees d'abord |
| `merlin_direct` | 5% | Pas de minigame, effets x1.0 |

### Structure d'une carte
```json
{
  "id": "card_broceliande_5",
  "type": "narrative",
  "text": "Au coeur de la foret...",
  "speaker": "KORIGAN",
  "options": [
    {
      "label": "Suivre l'etrange lueur",
      "verb": "suivre",
      "field": "perception",
      "minigame": "traces",
      "effects": [
        {"type": "ADD_REPUTATION", "faction": "druides", "amount": 10}
      ]
    },
    // ... exactement 3 options
  ],
  "tags": ["foret", "mystere"]
}
```

### Pipeline de generation
1. **LLM** (MerlinLlmAdapter.generate_card()) avec contexte complet
2. **Fallback Pool** (FastRoute, 500+ cartes pre-generees)
3. **Emergency** (carte default safe si tout echoue)

### Regles
- **3 options fixes** par carte
- **Max 3 effets** par option
- **Texte**: 30-800 caracteres
- **Validation**: langue FR, longueur, repetition (memoire 15 cartes)

---

## 8. LES 8 CHAMPS LEXICAUX ET MINIGAMES

Le texte de chaque carte est analyse pour detecter des **verbes d'action** (45 verbes en liste fermee) qui mappent vers un champ lexical et son minigame.

### Mapping champ → minigame

| Champ | Verbes | Minigame(s) | Description |
|-------|--------|-------------|-------------|
| **Chance** | cueillir, chercher au hasard, tenter sa chance, deviner | Herboristerie | Identifier la bonne herbe parmi les toxiques |
| **Bluff** | marchander, convaincre, mentir, negocier, charmer | Negociation | Choisir la bonne reponse de persuasion |
| **Observation** | observer, scruter, memoriser, examiner, fixer | Fouille / Regard | Trouver objet cache (temps limite) / Memoriser sequence |
| **Logique** | dechiffrer, analyser, resoudre, decoder, interpreter | Runes | Decoder symbole/puzzle |
| **Finesse** | se faufiler, esquiver, contourner, se cacher, escalader | Ombres / Equilibre | Se deplacer entre couvertures / Equilibre sur chemin etroit |
| **Vigueur** | combattre, courir, fuir, forcer, pousser, resister | Combat Rituel / Course | Duel sacre dodge / Sprint QTE |
| **Esprit** | calmer, apaiser, mediter, resister, se concentrer | Apaisement / Volonte / Sang-Froid | Rythme respiratoire / Curseur stable / Resistance mentale |
| **Perception** | ecouter, suivre, pister, sentir, flairer | Traces / Echo | Suivre pistes / Suivre intensite sonore vers source |

**Fallback**: Si verbe non reconnu → champ = "esprit"

### Score et multiplicateurs

| Score | Label | Multiplicateur effets positifs | Multiplicateur effets negatifs |
|-------|-------|-------------------------------|-------------------------------|
| 0-20 | Echec critique | x0 | x1.5 |
| 21-50 | Echec | x0 | x1.0 |
| 51-79 | Reussite partielle | x0.5 | x0 |
| 80-94 | Reussite | x1.0 (+2 Anam bonus) | x0 |
| 95-100 | Reussite critique | x1.5 + bonus special | x0 |

### 25 implementations de minigames
`mg_apaisement.gd`, `mg_bluff_druide.gd`, `mg_combat_rituel.gd`, `mg_course.gd`, `mg_echo.gd`, `mg_enigme_ogham.gd`, `mg_joute_verbale.gd`, `mg_lame_druide.gd`, `mg_meditation.gd`, `mg_negociation.gd`, `mg_noeud_celtique.gd`, `mg_oeil_corbeau.gd`, `mg_ombres.gd`, `mg_pas_renard.gd`, `mg_pierre_feuille_racine.gd`, `mg_pile_ou_face.gd`, `mg_traces.gd`, `mg_runes.gd`, `mg_herboristerie.gd`, `mg_fouille.gd`, `mg_volonte.gd`, `mg_regard.gd`, `mg_sang_froid.gd`, + variantes

---

## 9. LES 8 BIOMES

Score maturite = runs×2 + fins×5 + oghams×3 + max_rep×1

### 1. FORET DE BROCELIANDE (Starter)
- **Sous-titre**: "Ou les arbres ont des yeux"
- **Saison**: Printemps | **Difficulte**: 0
- **Deblocage**: Gratuit (starter)
- **Affinites faction**: Korrigans 1.2, Druides 1.0, Anciens 0.8
- **Passif**: Tous les 5 cartes, Korrigans rep UP
- **Monnaie**: Herbes enchantees / Baies magiques
- **Rythme**: Lent & meditatif (12-15s)
- **Creatures**: Fees, korrigans, loups anciens, arbres sentients
- **Gardien**: Maelgwn | **Ogham**: Duir
- **Arc narratif**: "Le Chene Chantant" (3 cartes, trigger Druides ≥30)
- **Lore**: Primordiale. Les arbres se souviennent. Les korrigans nichent ici. La brume est vivante. Ou Merlin est ne (fortement implique).

### 2. LANDES DE BRUYERE
- **Sous-titre**: "Ou le vent raconte des histoires"
- **Saison**: Automne | **Difficulte**: 1
- **Deblocage**: Maturite ≥15 (~5 runs + 2 oghams)
- **Affinites faction**: Anciens 1.2, Ankou 1.0, Druides 0.8
- **Passif**: Tous les 6 cartes, Anciens rep DOWN
- **Monnaie**: Brins de bruyere / Plumes de rapace
- **Rythme**: Modere (8-10s)
- **Creatures**: Rapaces, lievres, ermites, esprits du vent
- **Gardien**: Talwen | **Ogham**: Onn
- **Arc narratif**: "L'Ermite du Vent" (4 cartes, trigger 3+ runs dans ce biome)
- **Lore**: Les landes sont rudes. Seuls les forts ou les sages survivent ici.

### 3. COTES SAUVAGES
- **Sous-titre**: "Ou la mer defie la terre"
- **Saison**: Ete | **Difficulte**: 1 (tuning.json: 0)
- **Deblocage**: Maturite ≥15
- **Affinites faction**: Niamh 1.2, Korrigans 1.0, Druides 0.8
- **Passif**: Tous les 5 cartes, Niamh rep UP
- **Monnaie**: Coquillages / Perles de brume
- **Rythme**: Rythmique comme les vagues (6-8s)
- **Creatures**: Phoques, selkies, marchands, sirenes, fantomes marins
- **Gardien**: Bran | **Ogham**: Nuin
- **Arc narratif**: "Le Phoque d'Argent" (3 cartes, trigger Niamh ≥30)

### 4. VILLAGES CELTES
- **Sous-titre**: "Ou les humains forgent le destin"
- **Saison**: Ete | **Difficulte**: -1 (le plus facile)
- **Deblocage**: Maturite ≥25 (~8 runs, 2-3 oghams)
- **Affinites faction**: Druides 1.2, Niamh 1.0, Anciens 0.8
- **Passif**: Tous les 4 cartes, Druides rep UP
- **Monnaie**: Pieces de cuivre / Faveurs de clan
- **Rythme**: Social (8-10s, interrompu par fetes)
- **Creatures**: Villageois, chefs de clan, forgerons, bardes
- **Gardien**: Azenor | **Ogham**: Gort
- **Arc narratif**: "L'Assemblee Secrete" (5 cartes, trigger Anciens ≥40)

### 5. CERCLES DE PIERRES
- **Sous-titre**: "Ou le temps hesite"
- **Saison**: Hiver | **Difficulte**: 1
- **Deblocage**: Maturite ≥30 (~10 runs, 4+ oghams)
- **Affinites faction**: Druides 1.4, Anciens 1.0, Korrigans 0.8
- **Passif**: Tous les 4 cartes, Druides rep UP
- **Monnaie**: Fragments de rune / Eclats de menhir
- **Rythme**: Lent & spirituel (10-12s)
- **Creatures**: Esprits ancestraux, druides anciens, gardiens de pierre
- **Gardien**: Keridwen | **Ogham**: Huath
- **Arc narratif**: "Le Rituel Oublie" (4 cartes, trigger 2+ Oghams debloques)
- **Lore**: Espaces liminaux. La magie vibre. Frontiere la plus fine entre les mondes. Merlin craint cet endroit (subtilement).

### 6. MARAIS DES KORRIGANS
- **Sous-titre**: "Ou la lumiere trompe"
- **Saison**: Automne | **Difficulte**: 2
- **Deblocage**: Maturite ≥40 (~12 runs, 5+ oghams)
- **Affinites faction**: Korrigans 1.4, Ankou 1.0, Druides 0.8
- **Passif**: Tous les 5 cartes, Korrigans rep DOWN
- **Monnaie**: Pierres phosphorescentes / Gouttes du marais
- **Rythme**: Frenetique (4-6s, a peine le temps de respirer)
- **Creatures**: Korrigans, feux follets, creatures de tourbiere
- **Gardien**: Gwydion | **Ogham**: Muin
- **Arc narratif**: "Le Tresor des Feux" (4 cartes, trigger Korrigans ≥40)

### 7. COLLINES AUX DOLMENS
- **Sous-titre**: "Ou les morts regardent"
- **Saison**: Printemps | **Difficulte**: 0
- **Deblocage**: Maturite ≥50 (~15 runs, 6+ oghams, 4 fins vues)
- **Affinites faction**: Druides 1.0, Anciens 1.0, Korrigans 1.0 (equilibre)
- **Passif**: Tous les 7 cartes, faction RANDOM direction RANDOM
- **Monnaie**: Os graves / Cailloux de sagesse
- **Rythme**: Paisible (10-12s)
- **Creatures**: Esprits de rois anciens, sages, animaux doux
- **Gardien**: Elouan | **Ogham**: Ioho
- **Arc narratif**: "La Voix des Rois" (3 cartes, trigger 5+ fins vues)

### 8. ILES MYSTIQUES (Endgame)
- **Sous-titre**: "Ou le monde visible s'arrete"
- **Saison**: Samhain (crepuscule permanent) | **Difficulte**: 5 (max)
- **Deblocage**: Maturite ≥75 (~25 runs, 8+ oghams, 6 fins vues)
- **Creatures**: Selkies, banshees, fees de l'Autre Monde, Morgane
- **Gardien**: Morgane | **Ogham**: Ailm
- **Monnaie**: Ecume solidifiee / Larmes de Morgane
- **Rythme**: Imprevisible (3-15s, la realite plie)
- **Arc narratif**: "Le Passage d'Avalon" (6 cartes, trigger Niamh ≥60)
- **Lore**: Ou le monde se dissout. Les iles ne sont pas entierement dans votre realite. Merlin ne parle pas de cet endroit — il ne peut pas. Ou ne veut pas.

---

## 10. PNJ RECURRENTS

| Biome | PNJ | Role | Faction | Personnalite | Replique signature |
|-------|-----|------|---------|-------------|-------------------|
| Broceliande | Gwenn la Cueilleuse | Herboriste & guide | Druides | Sage, maternelle | "La foret parle a ceux qui ecoutent." |
| Landes | Aedan l'Ermite | Sage ermite | Neutre | Cryptique, patient, enigmes | "Le vent pose des questions que tu n'as pas appris a repondre." |
| Cotes | Bran le Passeur | Marchand maritime | Anciens | Ruse, bien voyage | "La mer garde les secrets. Moi, je les collecte." |
| Villages | Morwenna la Forge | Forgeronne | Neutre | Pratique, forte | "L'acier se souvient de qui l'a forge." |
| Cercles | Seren l'Etoilee | Druidesse mystique | Druides | Etheree, ritualiste | "Les pierres parlent a ceux qui sont morts avant." |
| Marais | Puck le Lutin | Marchand farceur | Korrigans | Malicieux, prix flous | "Tout a un prix. Mais le prix n'est pas toujours ce que tu attends." |
| Dolmens | Taliesin le Barde | Barde legendaire | Anciens | Chante propheties | "Chaque chanson est un sort. Chaque histoire est vraie." |
| Iles | Branwen la Spectrale | Esprit enigmatique | Ankou | Enigmes, tests | "Tu es un fantome. Tu l'as toujours ete." |

---

## 11. SYSTEME DE PROMESSES

Max **2 promesses actives** simultanement. Le MOS ne genere pas de 3eme.

### 7 types de promesses

| Promesse | Deadline | Condition | Recompense succes | Penalite echec |
|----------|----------|-----------|-------------------|----------------|
| Survivre 8 cartes | 8 cartes | Vie >25 pendant 8 tours | +10 trust Merlin, buff "Endurci" | -15 trust Merlin |
| Gagner 15 Rep (Faction) | 6 cartes | +15 rep d'une faction | +10 trust, carte faction debloquee | -15 trust |
| Gagner 3 Minigames | 8 cartes | Score ≥60 sur 3 minigames | +10 trust, buff "Habile" | -15 trust |
| Aucun choix sur | 5 cartes | Ne jamais choisir l'option la plus sure | +10 trust, +5 Anciens rep | -15 trust |
| Marche Korrigan | 4 cartes | Trouver tresor korrigan | +10 trust, +5 Korrigans rep | -15 trust |
| Marcher avec la Mort | 6 cartes | Accepter 3 effets negatifs sans bloquer | +10 trust, +5 Ankou rep | -15 trust |
| Guerir la Terre | 7 cartes | Restaurer 20 PV total | +10 trust, +5 Niamh rep | -15 trust |

### Mecaniques
- Promesse brisee: +10 tension, -15 rep faction associee
- Merlin propose les tests comme des defis de caractere
- Countdown -1 a chaque carte (Step 10 du pipeline)
- Pas de bris delibere — pas d'option pour ca

---

## 12. MOS — MERLIN OMNISCIENT SYSTEM

### 6 Registres

#### 1. Player Profile Registry (PPR)
- **Style de jeu**: Agression (0-1), Altruisme, Curiosite, Patience, Trust Merlin
- **Competences**: Gestion jauges, reconnaissance patterns, evaluation risque
- **Preferences**: Biome favori, types PNJ, themes evites, receptivite humour
- Maj toutes les 5 cartes

#### 2. Decision History Registry (DHR)
- Log 200+ cartes jouees
- Detection patterns: "aide_toujours_etrangers" (85%), "evite_promesses" (70%)
- Resume compresse: total choix, ratios, etats moyens a la mort

#### 3. Relationship Registry (RR)
- Trust tier (T0-T3): 0-100 points
- Rapport: Respect, Chaleur, Complicite, Crainte (0-1 chaque)
- Flags speciaux: has_seen_melancholy, questioned_merlin, thanked_merlin, defied_merlin

#### 4. Narrative Registry (NR)
- Arcs actifs & completes (etape 1=intro, 4=resolution)
- Foreshadowing: indices plantes avec fenetres de revelation
- PNJs: rencontres, relations, secrets connus
- Etat monde: biome, jour, saison, tags actifs, tension globale
- Fatigue thematique: themes recents ont poids reduit

#### 5. Session Registry (SR)
- Session actuelle: temps, cartes jouees, pauses, temps decision moyen
- Signaux engagement: vitesse lecture, taux usage oghams
- Flags bien-etre: avertissement longue session, frustration detectee

#### 6. Hidden Resource Registry (HRR)
- **Karma** (-100 a +100): moralite globale
- **Tension** (0-100): niveau crise monde. Haute = plus de twists, convergence rapide
- **Score decouverte**: fragments lore trouves. Gate fins cachees
- Influence eligibilite fins et ton narratif sans que le joueur les voie

### Convergence MOS

| Parametre | Valeur |
|-----------|--------|
| Soft min | 8 cartes |
| Target zone | 20-25 cartes |
| Soft max | 40 cartes |
| Hard max | 50 cartes |
| Triggers convergence | tension ≥ 0.7, arc resolu, faction ≥ 80 |

### Detection danger
- Vie < 15 (CRITIQUE): Signal "desespoir" au LLM
- Vie < 25 (BAS): Reduit difficulte
- Vie < 50 (BLESSE): Signal blesse

---

## 13. PIPELINE D'EFFETS (REFERENCE)

```
 1. AFFICHAGE CARTE (pas de drain passif)
 3. ACTIVATION OGHAM (optionnel, avant choix)
 4. CHOIX OPTION
 5. MINIGAME (sauf Merlin Direct)
 6. SCORE 0-100
 7. APPLICATION EFFETS (multiplicateur)
 8. OGHAM PROTECTION filtre negatifs
 9. VERIFICATION VIE = 0
10. VERIFICATION PROMESSES (countdown -1)
11. COOLDOWN OGHAM -1
12. RETOUR 3D
```

### Types d'effets valides

| Code | Params | Description | Cap |
|------|--------|-------------|-----|
| `HEAL_LIFE` | amount | Restaure PV | +18 max |
| `DAMAGE_LIFE` | amount | Inflige degats | -15 max (critique -22) |
| `ADD_REPUTATION` | faction, amount | Modifie rep faction | ±20/faction/carte |
| `ADD_ANAM` | amount | Ajoute monnaie cross-run | Pas de cap |
| `ADD_TENSION` | amount | Modifie tension cachee | Clamp 0-100 |
| `CREATE_PROMISE` | promise_id, deadline, desc | Cree promesse | Max 2 actives |
| `FULFILL_PROMISE` | promise_id | Complete promesse | — |
| `BREAK_PROMISE` | promise_id | Brise promesse | — |
| `ADD_KARMA` | amount | Modifie karma cache | Pas de cap |
| `PROGRESS_MISSION` | amount | Avance mission | — |
| `SET_FLAG` | flag, value | Set flag narratif | — |
| `ADD_TAG` | tag | Ajoute tag narratif | — |
| `UNLOCK_OGHAM` | name | Debloque ogham | 1/carte |
| `ADD_BIOME_CURRENCY` | amount | Ajoute monnaie biome | +10 max |
| `ADD_NARRATIVE_DEBT` | type, desc | Ajoute dette narrative | — |
| `QUEUE_CARD` | card_id | Force prochaine carte | — |
| `TRIGGER_ARC` | arc_id | Declenche arc narratif | — |
| `PLAY_SFX` | name | Joue son | — |
| `SHOW_DIALOG` | text | Affiche dialogue | — |

### Ogham Protection (Step 8)
- `luis`: Supprime 1er effet negatif
- `gort`: Degats >10 → 5 (1 instance)
- `eadhadh`: Supprime TOUS les effets negatifs

### Formules
- Scale: `scaled = int(float(raw_amount) * abs(multiplier))`
- Si multiplicateur < 0: `scaled = -scaled`
- Score bonus: additifs, cap global x2.0
- Confiance Merlin: clamp(0, 100)

---

## 14. ARBRE DE TALENTS (ARBRE DE VIE)

34 noeuds au total: 5 branches faction × 5 tiers + 5 speciaux + 4 central

### Structure par noeud
```json
{
  "branch": "druides|anciens|korrigans|niamh|ankou|central",
  "tier": 1-5,
  "name": "string",
  "cost": "int (Anam)",
  "prerequisites": ["node_ids"],
  "effect": {"type": "modify_start|cooldown_reduction|minigame_bonus|..."},
  "description": "string",
  "lore": "string"
}
```

### Exemples de noeuds

**Branche Druides:**
| Tier | Cout | Effet |
|------|------|-------|
| 1 | 20 | +10 vie depart |
| 2 | 25 | -1 cooldown oghams nature |
| 3 | 50 | +15% minigames logique |
| 4 | 80 | x2 effets soin oghams |
| 5 | 120 | Supprime drain vie (1→0/carte) |

**Branche Centrale (universelle):**
| Tier | Cout | Effet |
|------|------|-------|
| 1 | 20 | +10 vie max (100→110) |
| 2 | 25 | -1 cooldown global |
| 3 | 50 | Affiche karma+tension dans HUD |
| 4 | 80 | +10% tous minigames |

**Noeuds speciaux (cross-faction):**
- Calendrier des Brumes (30): Revele 7 prochains evenements
- Harmonie Factions (60): +5 Anam/run si toutes factions ≥50
- Eveil Ogham (35): Equipe 2 Oghams au lieu d'1
- Boucle Eternelle (150, NG+): x1.5 Anam

### Echelle des couts
- Tier 1: 20-50 Anam
- Tier 2: 25-80 Anam
- Tier 3: 50-120 Anam
- Tier 4: 80-150 Anam
- Tier 5: 120-250 Anam

---

## 15. ANAM — MONNAIE CROSS-RUN

Du gaelique "ame". Monnaie cumulative persistante entre les runs.

### Recompenses Anam
| Source | Montant |
|--------|---------|
| Completion run (base) | +10 |
| Victoire (atteint la fin) | +15 bonus |
| Minigame score ≥80 | +2 par minigame |
| Ogham active ce run | +1 par utilisation |
| Faction "Honore" (≥80) | +5 par faction |
| Ogham deja possede en run | +5 |

### Formule mort
- `Anam × min(cartes/30, 1.0)` → cap 100% (pas de bonus au-dela de 30 cartes)
- Si cartes < 30: penalite proportionnelle

### Depenses
- Debloquer Oghams: 60-160 Anam
- Noeuds arbre de talents: 20-250 Anam

---

## 16. EVENEMENTS CALENDAIRES

32+ evenements en 4 categories.

### Transitions saisonnieres (4)
| Evenement | Date | Effet |
|-----------|------|-------|
| Eveil du Printemps | 1 Mars | +5 PV, +5 Druides rep |
| Soleil de l'Ete | 1 Juin | +5 PV, +5 Niamh rep |
| Souffle d'Automne | 1 Sep | +5 Druides rep, +3 Karma |
| Nuit de l'Hiver | 1 Dec | -5 PV, +10 Tension |

### Sabbats celtiques (8)
| Sabbat | Date | Lore | Effets principaux |
|--------|------|------|-------------------|
| **Imbolc** | 1 Fev | Brigid benit les sources sacrees | +8 Druides, +5 Karma |
| **Ostara** | 21 Mars | Equinoxe. Les druides tracent des cercles dans la rosee | +8 Druides, +5 PV |
| **Beltane** | 1 Mai | Feux sur les collines. Fertilite de la terre | +5 Niamh, +5 Karma, +8 PV |
| **Litha** | 21 Juin | Nuit la plus courte. Les fees dansent | +5 Karma, +10 PV |
| **Lughnasadh** | 1 Aout | Moisson & jeux du dieu Lugh | +5 Anciens, +5 PV |
| **Mabon** | 21 Sep | Equinoxe d'automne. Gratitude | +5 Niamh, +5 Karma, +5 PV |
| **Samhain** | 31 Oct | Voile le plus fin. Morts murmurent | +10 Druides, +10 Karma, +5 PV |
| **Yule** | 21 Dec | Solstice d'hiver. Feu sacre | +5 Anciens, +5 Karma, +8 PV |

### Evenements consequences (18+)
Exemples cles:
- **Brume de l'Ankou** (21 Jan): +5 Ankou, +15 Tension. "Malheur a qui croise sa route."
- **Nuit des Fees** (23 Juin): +8 Korrigans, +5 PV. Voeu exauce — mais a quel prix.
- **Chasse Sauvage** (15 Oct - 15 Nov): -10 PV, +20 Tension, flag "survived_wild_hunt"
- **Lune de Sang** (pleine lune + haute tension): +25 Tension, -8 PV, flag "blood_moon_witnessed"

### Evenements secrets (6)
| Secret | Condition | Effet |
|--------|-----------|-------|
| **Graal Breton** | Karma ≥30, 20+ cartes | +20 PV, +15 Druides, +20 Karma, unlock fin "Vase Sacre" |
| **Voix des Ancetres** | Druides ≥70, promesse tenue | +15 PV, +10 Anciens, mission +2 |
| **Chaudron du Dagda** | Vie ≥70, 15+ cartes | +20 PV, +10 Anciens |
| **Arbre-Monde** | Druides ≥60 ET Anciens ≥60, 15+ cartes | +20 PV, +25 Karma |
| **Memoire de Merlin** | Trust ≥50, 3+ fins vues, 20+ cartes | +15 PV, +30 Karma, +10 Druides, flag "merlin_remembers" |

---

## 17. FINS DU JEU (~10-15)

### 5 Fins faction (rep ≥80)

| Faction | Titre | Resume | Meta-recompense |
|---------|-------|--------|-----------------|
| **Druides** | Cercle des Druides | Accepte dans le cercle eternel. Merlin sourit sans tristesse. | +5 Anam bonus |
| **Anciens** | Voix des Ancetres | Les ancetres parlent. Gardien de memoire. | +30% gain rep Anciens prochain run |
| **Korrigans** | Monde des Fees | Entre les mondes. Ni mourir ni vieillir. Ambigue. | Carte "Marche Fae" (haut risque/recompense) |
| **Niamh** | Tir na nOg | Autre Monde. Temps arrete. Eternellement jeune. Merlin: "Au revoir." | +10 PV max prochain run |
| **Ankou** | Passeur entre les Mondes | Successeur d'Ankou. Ni vivre ni mourir. | Carte "Peage du Passeur" |

### Fins speciales

| Fin | Condition | Description |
|-----|-----------|-------------|
| **Mort** | Vie = 0 | Pas un echec. Narrativement valide. Anam proportionnel. Titre contextuel par biome. |
| **Harmonie** (L'Equilibre Parfait) | Toutes factions ≥60 | "Tu as fait ce que je n'ai jamais pu. Tu as embrasse la contradiction." Titre "Harmoniste" (+5 rep depart toutes factions). |
| **Transcendance** | Arc "Le Murmure des Oghams" complete | Les oghams sont vivants — fragments d'un etre ancien. Vous devenez un conduit. -30% cout Anam, acces 9eme biome secret. |

### Mort — Variantes narratives par biome
- Broceliande: "La Derniere Feuille" — Les arbres pleurent.
- Cotes: "Le Dernier Voyage" — La maree vous ramene.
- Marais: "L'Ombre Eternelle" — Vous devenez un feu follet.

---

## 18. MERLIN — PERSONNAGE ET DIALOGUE

### Identite
- **Age**: Indetermine (ancien, mais intemporel)
- **Personnalite**: 95% joueur & taquin; 5% melancolie profonde
- **Parole**: Francais moderne (pas d'archaisme), phrases courtes, touches poetiques
- **Role**: Narrateur, guide, maitre de jeu, et personnage

### Tiers de confiance (T0-T3)

| Tier | Points | Etiquette | Ton | Exemple |
|------|--------|-----------|-----|---------|
| **T0** | 0-24 | Cryptique | Reserve, mysterieux, enigmatique | "Le chemin. Tu le connais ? Non. Personne ne le connait." |
| **T1** | 25-49 | Indices | Test, occasionnellement utile | "Tu choisis bien. Ou par chance. Difficile a dire." |
| **T2** | 50-74 | Avertissements | Reflexif, comprehension partagee | "Je vois. Tu comprends les implications. Les druides t'auraient approuve." |
| **T3** | 75-100 | Secrets | Chaleureux, vulnerable, moments rares | "Mon ami, tu sais quoi ? Je suis fatigue. Mais toi, tu continues. C'est beau." |

### Deltas de confiance
- Promesse tenue: +10
- Promesse brisee: -15
- Choix courageux: +3 a +5
- Run longue (100+ cartes): +5
- Mort rapide (<20 cartes): -2
- Joueur suit indice: +3
- Joueur ignore avertissement (mais survit): +5 respect
- Lore decouverte: +2

### Revelations par tier
- T1: "J'etais un druide, autrefois."
- T2: "J'ai vecu de nombreuses vies."
- T3: "Bestiole est la seule chose qui m'importe." / "Je suis fatigue. Si fatigue. Mais je ne peux pas arreter de regarder."

### Dialogues cles

**Eveil (1er contact)**:
```
MERLIN (vulnerable): "... Tu es la."
[2 secondes de silence]
MERLIN: "J'ai attendu. Longtemps. Si longtemps que j'ai oublie si c'etait du temps ou autre chose."
MERLIN (joueur): "La brume t'a laisse passer. C'est bon signe. Enfin... elle laisse passer tout le monde, meme les gens sans aucun sens de l'orientation."
```

**Post-Run** (selon resultat):
- Survie: "Tu as tenu le coup. Bien."
- Mort: "La mort te tenait bien. Ne lui fais pas trop confiance la prochaine fois."
- Gain Druides: "Les druides remarquent. Ils s'en souviendront."
- Promesse brisee: "... Tu sais ce que tu as fait, non ?"

### Rapport (dimensions 0-1)
- **Respect**: Reconnaissance des competences du joueur
- **Chaleur**: Connexion emotionnelle
- **Complicite**: Blagues/moments partages
- **Crainte**: Reverence saine pour le pouvoir de Merlin

### Flags speciaux
- `has_seen_melancholy`: Quand Merlin montre sa vulnerabilite (T2+)
- `questioned_merlin`: Le joueur demande "Qui es-tu vraiment ?"
- `thanked_merlin`: Gratitude sincere exprimee
- `defied_merlin`: Opposition deliberee aux conseils de Merlin

---

## 19. PROFIL JOUEUR

### Tracking prudence/audace
- **Prudence** (choix surs, noeuds REST, options low-risk) → scaling conservateur
- **Audace** (choix risques, options high-damage, minigames dangereux) → scaling agressif
- **Tracke en interne uniquement** — pas d'affichage joueur

### Influence sur Merlin
- Haute prudence → Merlin previent tot, suggere chemins surs
- Haute audace → Merlin defie, presente options plus dures
- Merlin commente le style de jeu (depend du tier de confiance)

### Autres dimensions trackees
- Affinite faction (historique choix)
- Preference type carte (events vs narrative vs promise)
- Performance minigame (quel champ excelle)
- Duree session moyenne (cartes par run)
- Inclination tonale (heroique vs introspectif vs sombre)

---

## 20. SYSTEME DE SAUVEGARDE

### Profil unique, auto-continue
- **1 fichier**: `user://merlin_profile.json`
- **Backup**: `.bak` auto-cree
- **Run state**: null (efface apres fin) ou dict (mid-run, auto-save si interruption)
- **Pas de save manuelle** — sauvegarde auto apres evenements majeurs

### Ce qui persiste (cross-run)
- faction_rep (0-100 par faction)
- anam (monnaie cumulative)
- trust_merlin (tier T0-T3)
- talent_tree (noeuds debloques)
- oghams possedes & equipes
- endings_seen (liste des fins vues)
- total_runs, biome_runs, stats

### Ce qui reset par run
- life_essence (repart a 100)
- card_index (repart a 0)
- biome_currency (repart a 0)
- cooldowns (tous reset)
- promesses actives (effacees)
- tags actifs (effaces)

### Format save (v1.0.0)
```json
{
  "version": "1.0.0",
  "timestamp": 1234567890,
  "meta": {
    "anam": 150,
    "total_runs": 5,
    "faction_rep": {"druides": 50, "anciens": 40, "korrigans": 30, "niamh": 25, "ankou": 15},
    "trust_merlin": 35,
    "talent_tree": {"unlocked": ["root", "druides_1"]},
    "oghams": {"owned": ["beith", "luis", "quert", "coll"], "equipped": "beith"},
    "endings_seen": ["mort_broceliande"],
    "biome_runs": {"foret_broceliande": 3, "landes_bruyere": 1},
    "stats": {"total_cards": 87, "total_minigames_won": 12, "total_deaths": 2}
  },
  "run_state": null
}
```

---

## 21. MAP/RUN SYSTEM

### Types de noeuds (STS-like)

| Type | Poids | Cartes | Description |
|------|-------|--------|-------------|
| NARRATIVE | 0.40 | 2-4 | Cartes narratives standard |
| EVENT | 0.15 | 1-2 | Evenements aleatoires |
| PROMISE | 0.08 | 1-1 | Proposition de promesse |
| REST | 0.12 | 0 | +18 PV, -5 tension |
| MERCHANT | 0.08 | 0 | 3 offres: vie (15 Anam), ogham (30 Anam) |
| MYSTERY | 0.10 | 1-3 | Contenu mystere |
| MERLIN | 0.07 | 3-5 | Noeud final force |

### Generation de map
- Etages: min 3, typiquement 8-10
- Premier etage: 1 noeud NARRATIVE
- Dernier etage: 1 noeud MERLIN
- Etages intermediaires: 2-3 noeuds (type random pondere)
- Milieu: force REST ou MERCHANT
- Connexions: ≥1 parent/enfant, max 3, 45% chance extra connexion

---

## 22. DIFFICULTE

### Scaling par etage
- Base danger: 0.3
- Par etage: +0.05
- Poids difficulte biome: ×0.1

### Difficulte par biome
| Biome | Modifier |
|-------|----------|
| Foret Broceliande | 0 |
| Landes Bruyere | +1 |
| Cotes Sauvages | 0 |
| Villages Celtes | -1 |
| Cercles Pierres | +1 |
| Marais Korrigans | +2 |
| Collines Dolmens | 0 |
| Iles Mystiques | +3-5 |

### Semi-adaptive
La difficulte depend du **contexte narratif**, PAS de la performance du joueur.

---

## 23. PIPELINE LLM MULTI-BRAIN

### Architecture
- **Narrator** (4B): Generation texte narratif (cartes, monologues)
- **GM** (2B): Enforcement regles mecaniques (equilibre, limites)
- **Judge** (0.8B): Scoring qualite + controle dommages (guardrails, repetition, longueur)

### Backend
- Ollama HTTP API (local)
- Modele: Qwen 3.5 (via LoRA fine-tune)
- Timeout: 300s (genereux pour inference CPU)
- Max retries: 2

### RAG v3.0 — Contexte prioritise
1. 5-10 dernières cartes
2. Promesses actives (contraintes deadline)
3. Contexte faction (alignements actuels)
4. Contexte biome (atmosphere, creatures, theme)
5. Compteurs caches (karma, tension, dette narrative)
6. Historique decisions (patterns joueur)

### Budget contexte
- Narrator: 2000 tokens
- GM: 1500 tokens
- Judge: 1000 tokens
- Fenetre totale: ~8000 tokens (Qwen 3.5-4B)

### Validation carte (post-generation)
- Champ `text` present + 30-800 chars
- Array `options` present + taille ≥2 (padded a 3)
- Chaque option a un label non-vide
- Detection langue FR (mots-cles)
- Check repetition (similarite < 0.5 vs 15 dernieres cartes)
- Filtre mots interdits (guardrails persona)

### FastRoute (Fallback)
- 500+ cartes pre-generees par LLM cloud
- Variantes par tier de confiance
- Utilisees si LLM local echoue

---

## 24. SYSTEME VISUEL

### Palette CRT (theme actif)
```
bg_deep:         #050A05    (fond le plus sombre)
bg_dark:         #0A140A
bg_panel:        #0F1F0F
bg_highlight:    #142914    (fond le plus clair)

phosphor:        #33FF66    (texte principal)
phosphor_dim:    #1F993D    (texte attenue)
phosphor_bright: #66FF99    (emphasis)
phosphor_glow:   #33FF6626  (lueur transparente)

amber:           #FFBF33    (boutons hover)
amber_dim:       #997320
amber_bright:    #FFD966

cyan:            #4DD9CC    (magic/special)
cyan_bright:     #80FFF2
cyan_dim:        #266B66

danger:          #FF3326    (rouge)
success:         #33FF66    (vert)
warning:         #FFBF33    (ambre)

border:          #1F4D24    (bordures panels)
scanline:        #00000026  (scanlines CRT)
```

### Systeme de polices
- **VT323** (monospace terminal)
- Tailles: TITLE (28), BODY (14), CAPTION_LARGE (12), CAPTION_SMALL (10)
- Outline: 2px

### Palettes additionnelles
- **GBC**: Game Boy Color (vert fonce → vert clair)
- **Jugdral21**: 21 couleurs pour pixel art biomes
- **Parchemin** (legacy): paper tones + encre

---

## 25. SYSTEME AUDIO

### 100% procedural (SFXManager)
Tous les sons sont generes au demarrage — aucun fichier audio pour SFX.

### Categories et volumes
| Categorie | Volume | Sons |
|-----------|--------|------|
| UI | 0.25 | hover, click, slider_tick, button_appear |
| Transition | 0.22 | whoosh, card_draw, card_swipe, scene_transition |
| Impact | 0.30 | block_land, pixel_land, dice_land, accum_explode |
| Magic | 0.20 | ogham_chime, ogham_unlock, eye_open, critical_alert |
| Ambient | 0.15 | path_scratch, landmark_pop, mist_breath, amb_* |

### Pool audio: 6 joueurs simultanes, round-robin fallback

### Musique (fichiers .wav)
- Tri Martolod (intro + loop)
- Chas Donz Part 1 (intro + loop)
- Systeme crossfade entre morceaux

---

## 26. SHADERS

17 shaders dans `shaders/`:

| Shader | Usage |
|--------|-------|
| `crt_terminal.gdshader` | Grille phosphore CRT + scanlines |
| `crt_static.gdshader` | Neige/statique TV |
| `screen_distortion.gdshader` | Vagues/ondulations |
| `screen_dither.gdshader` | Dithering Bayer post-process |
| `color_dither.gdshader` | Dithering couleur |
| `pixelate.gdshader` | Pixelisation |
| `ps1_material.gdshader` | Warping polygones PS1 |
| `merlin_paper.gdshader` | Texture parchemin overlay |
| `card_silhouette.gdshader` | Ombre/contour carte |
| `card_sky.gdshader` | Gradient ciel pour illustrations |
| `palette_swap.gdshader` | Swap palette (remapping couleur) |
| `iridescent_border.gdshader` | Effet bordure arc-en-ciel |
| `screen_vfx.gdshader` | Compositeur multi-effets |
| `grass_wind_sway.gdshader` | Animation herbe |
| `seasonal_particles.gdshader` | Sprites particules procedurales |
| `seasonal_snow.gdshader` | Neige avec accumulation |
| `bestiole_squish.gdshader` | Squash/stretch personnage |

---

## 27. AUTOLOADS

14 singletons autoloads:

| Autoload | Script | Role |
|----------|--------|------|
| GameManager | `scripts/game_manager.gd` | Etat jeu, PRNG, types, oghams, ennemis |
| MerlinAI | `addons/merlin_ai/merlin_ai.gd` | Interface LLM, multi-brain |
| MerlinBackdrop | `scripts/merlin_backdrop.gd` | Systeme couches fond |
| ScreenFrame | `scripts/autoload/screen_frame.gd` | Gestion viewport |
| ScreenEffects | `scripts/autoload/ScreenEffects.gd` | VFX ecran global |
| SceneSelector | `scripts/autoload/SceneSelector.gd` | Routage navigation scenes |
| LocaleManager | `scripts/autoload/LocaleManager.gd` | i18n, switch locale |
| SFXManager | `scripts/autoload/SFXManager.gd` | Sons proceduraux, pool 6 joueurs |
| MerlinVisual | `scripts/autoload/merlin_visual.gd` | Constantes visuelles centralisees |
| PixelTransition | `scripts/autoload/pixel_transition.gd` | Transitions pixel-dissolve |
| PixelContentAnimator | `scripts/autoload/pixel_content_animator.gd` | Effets cascade/scatter |
| WorldMapSystem | `scripts/autoload/world_map_system.gd` | Etat map monde, jauges |
| MusicManager | `scripts/autoload/music_manager.gd` | Musique persistante, crossfade |
| GameTimeManager | `scripts/autoload/game_time_manager.gd` | Eclairage jour/nuit, saisons, meteo |

---

## 28. ARCHITECTURE TECHNIQUE

### Scripts principaux (`scripts/merlin/`)
| Fichier | Lignes | Role |
|---------|--------|------|
| `merlin_store.gd` | ~1400 | State central (Redux-like), signaux, factions |
| `merlin_card_system.gd` | ~800 | Moteur cartes, fallback pool, generation LLM |
| `merlin_effect_engine.gd` | ~600 | HEAL_LIFE, DAMAGE_LIFE, ADD_REPUTATION, etc. |
| `merlin_llm_adapter.gd` | ~500 | Contrat LLM, reparation JSON, factions |
| `merlin_constants.gd` | ~900 | 18 Oghams, biomes, minigames, factions |
| `merlin_reputation_system.gd` | ~300 | 5 factions, 0-100, seuils 50/80 |
| `merlin_save_system.gd` | ~400 | 1 profil JSON, migration |

### UI Layer (`scripts/ui/`)
| Fichier | Role |
|---------|------|
| `merlin_game_controller.gd` | Bridge Store-UI, flow run, wiring LLM |
| `merlin_game_ui.gd` | Rendu UI cartes, barres, options |

### AI Layer (`addons/merlin_ai/`)
| Fichier | Role |
|---------|------|
| `merlin_ai.gd` | Multi-Brain, time-sharing, routing |
| `ollama_backend.gd` | API HTTP Ollama |
| `brain_swarm_config.gd` | Profils hardware NANO/SINGLE/DUAL/QUAD |
| `merlin_omniscient.gd` | Orchestrateur IA, guardrails |
| `rag_manager.gd` | RAG v3.0, budget contexte par brain |

### Donnees (`data/`)
| Fichier | Contenu |
|---------|---------|
| `balance/tuning.json` | Distribution cartes, biomes, promesses, difficulte |
| `calendar_events.json` | 32+ evenements avec lore et effets |
| `ai/config/merlin_persona.json` | Voix Merlin, regles dialogue |
| `ai/promise_cards.json` | 7 templates promesses |
| `dialogues/scene_dialogues.json` | Systeme dialogue Merlin |

---

## 29. CONTROLES ET INPUTS

### MerlinGame
| Touche | Action |
|--------|--------|
| A / 1 | Option A |
| B / 2 | Option B |
| C / 3 | Option C |
| ESC | Menu pause |
| P | Pause |
| J | Journal / Log histoire |
| M | Dialogue Merlin (question custom) |

### Menus
- Clic souris sur boutons
- 1/2/3/4 pour choix quiz
- ESC retour menu precedent

### Pendant fondus (1-2s)
- **Inputs desactives** via `set_process_unhandled_input(false)`
- Minigames consomment l'input jusqu'a completion

### Resolution
- Mode stretch: `canvas_items`
- Renderer: GL Compatibility
- Cible: 1920×1080 (reference), s'adapte a toutes tailles

---

## ANNEXE: SYSTEMES SUPPRIMES

Ces systemes ont ete retires du design:
- ~~Triade (Corps/Ame/Monde)~~ — Remplace par 1 barre de vie unique
- ~~Souffle d'Ogham~~ — Remplace par cooldown/carte
- ~~4 Jauges~~ — Remplace par 5 factions
- ~~Bestiole~~ — Retiree du gameplay
- ~~Awen~~ — Remplace par Anam
- ~~D20~~ — Remplace par score 0-100
- ~~Flux System~~ — Retire
- ~~Run Typologies~~ — Retirees
- ~~Decay reputation~~ — Retire (persistant sans perte)
- ~~Auto-run pre-run~~ — Retire
- ~~Options variables~~ — Fixe a 3 options
- ~~Drain vie passif~~ — Retire (pression via effets/promesses)

---

*Document genere le 2026-03-14 par exploration exhaustive du codebase.*
*Sources: merlin_constants.gd, merlin_store.gd, merlin_effect_engine.gd, GAME_DESIGN_BIBLE.md v2.4, calendar_events.json, merlin_persona.json, promise_cards.json, scene_dialogues.json, MOS docs, et tous les scripts de scenes.*
