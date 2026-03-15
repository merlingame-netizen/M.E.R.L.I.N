# M.E.R.L.I.N. — ENCYCLOPEDIE EXHAUSTIVE DU JEU

> **Version**: 5.0 | **Date**: 2026-03-15
> **Source de verite**: Ce document consolide TOUTES les informations du jeu.
> **Game Design Bible**: `docs/GAME_DESIGN_BIBLE.md` v2.4 reste la reference design.
> **Companions**: `GAME_MECHANICS.md` (formules & calculs) | `GAME_BEHAVIOR.md` (comportement runtime & rendu)

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
30. [UI — Interactions detaillees](#30-ui--interactions-detaillees)
31. [State Management — MerlinStore complet](#31-state-management--merlinstore-complet)
32. [Signal Architecture](#32-signal-architecture)
33. [Formules & Edge Cases — Details exhaustifs](#33-formules--edge-cases--details-exhaustifs)
34. [Card Resolution — Flow exact](#34-card-resolution--flow-exact)
35. [Sequence d'initialisation — Boot a gameplay](#35-sequence-dinitialisation--boot-a-gameplay)
36. [Palette CRT complete (valeurs exactes)](#36-palette-crt-complete-valeurs-exactes)
37. [Quiz de personnalite — 10 questions, 4 axes, 8 archetypes](#37-quiz-de-personnalite--10-questions-4-axes-8-archetypes)
38. [Hub Antre — Sanctuaire complet](#38-hub-antre--sanctuaire-complet)
39. [Menus et scenes UI — Catalogue exhaustif](#39-menus-et-scenes-ui--catalogue-exhaustif)
40. [Evenements calendaires — 47 evenements complets](#40-evenements-calendaires--47-evenements-complets)
41. [Taxonomie d'evenements & Pity System](#41-taxonomie-devenements--pity-system)
42. [8 Biomes — Donnees completes (guardiens, missions, dialogues)](#42-8-biomes--donnees-completes-guardiens-missions-dialogues)

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

### Minigames — Mecaniques exactes

#### Pile ou Face (Chance)
- **Tours**: 3 + (difficulte-1)/3 = 3-6 tours
- **Controles**: Bouton "PILE" ou "FACE"
- **Score**: (predictions correctes / total tours) x 100

#### Apaisement (Esprit)
- **Beats**: 5 beats
- **Intervalle**: 1.8 - (difficulte x 0.08), min 0.9s
- **Controles**: ESPACE quand le pouls est au pic (onde sinusoidale, phase 0.5)
- **Score**: (beats touches / 5) x 100

#### Meditation (Esprit)
- **Duree**: 7.0 - (difficulte x 0.15), min 4.0s
- **Arene**: 250x250 px, zone centre rayon 20%
- **Curseur**: 16x16 px, derive aleatoirement, maintenir ESPACE pour recentrer
- **Derive**: Vitesse 0.1 + (difficulte x 0.025)
- **Score**: (temps dans zone / temps max) x 100

#### Oeil du Corbeau (Observation)
- **Grille**: 3x3 (9 symboles Unicode: triangle, rond, carre, etoile...)
- **Temps**: 5.0 - (difficulte x 0.3), min 2.0s
- **Tache**: Cliquer le symbole different
- **Score**: (temps restant / temps max) x 100

#### Pierre Feuille Racine (Logique)
- **Tours**: 3
- **Regles**: Pierre > Racine > Feuille > Pierre
- **Controles**: Q=Pierre, W=Feuille, E=Racine
- **IA**: Aleatoire (faible diff), strategique (haute diff)
- **Score**: (victoires joueur / 3) x 100

#### Negociation (Bluff)
- **Sweet spot**: Aleatoire 30-70
- **Tentatives**: 2
- **Controles**: Slider 0-100 + bouton confirmer
- **Score**: 100 - (|valeur - sweet_spot| x 1.5), clamp 0-100. Meilleur des 2.

#### Course Druidique (Vigueur)
- **Taps requis**: 15 + (difficulte x 3)
- **Temps**: 6.0 - (difficulte x 0.2), min 3.0s
- **Controles**: Spam ESPACE
- **Score**: (taps / requis) x 100

#### Enigme d'Ogham (Logique)
- **Patterns**: Repeter, Alterner, Ascendant, Descendant (gate par difficulte)
- **Controles**: QCM (3 options)
- **Score**: 100 si correct, 0 sinon

#### Roue de Fortune (Chance)
- **Segments**: 8 avec scores [100, 100, 75, 75, 50, 50, 20, 0]
- **Mauvais segments**: 1 + (difficulte/3) ajoutes en difficulte haute
- **Controles**: Bouton/ESPACE pour arreter
- **Score**: Valeur du segment d'arret

### Formule difficulte minigame
```
base_threshold = 0.5 + (5 - difficulty) x 0.05
  Diff 1: 0.70 (facile)
  Diff 5: 0.50
  Diff 10: 0.25 (tres dur)
threshold = clamp(base_threshold + bonus, 0.05, 0.95)
```

### 25 fichiers d'implementation
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

### Contrat LLM (parametres generation)
- max_tokens: 180
- temperature: 0.65
- top_p: 0.88
- top_k: 35
- repetition_penalty: 1.4

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

## 30. UI — INTERACTIONS DETAILLEES

### 30.1 Barre de vie (10 segments)
- **Location**: `$MainVBox/TopStatusBar/LifePanel`
- **Segment**: 10 barres individuelles, 20×14px chacune
- **Couleur seuil**: `life ≤ 25` → modulate `Color(1.0, 0.3, 0.3)` (rouge), sinon `Color.WHITE`
- **Format label**: "X/Y" en 12pt

### 30.2 Panel Souffle d'Ogham
- **Location**: `$MainVBox/TopStatusBar/SoufflePanel`
- **7 icones**: Label nodes `Icon0`–`Icon6`, 28pt
- **Vide**: "o" | **Plein**: "*"
- **Couleur**: `CRT_PALETTE.souffle` = `Color(0.30, 0.85, 0.80)` (cyan)
- **Animation glow**: Boucle infinie `modulate.a` 0.55→1.0 sur 1.2s (`TRANS_SINE`)
- **Animation gain**: scale 0.5→1.0 sur 0.2s (`TRANS_CUBIC EASE_IN`)
- **Animation depense**: scale 1.2→1.0 sur 0.25s (`TRANS_BACK EASE_OUT`), stagger 0.1s/icone

### 30.3 Carte — Animations

#### Flottement
- **Offset**: 5.0px (`CARD_FLOAT_OFFSET`)
- **Duree cycle**: 2.8s (`CARD_FLOAT_DURATION`)
- **Pattern**: Y -5.0px → +3.0px (boucle infinie, `TRANS_SINE EASE_IN_OUT`)

#### Entree
- **Duree**: 0.65s (`CARD_ENTRY_DURATION`)
- **Overshoot**: 1.10
- **Settle**: 0.20s
- **Easing**: `TRANS_BACK EASE_OUT`

#### Sortie
- **Duree**: 0.55s (`CARD_EXIT_DURATION`)

#### Deal (pioche)
- **Duree**: 0.35s (`CARD_DEAL_DURATION`)

#### Effet 3D Tilt (hover souris)
- **Rotation max**: 7.0°
- **Scale hover**: ×1.055
- **Shadow shift**: 10.0px
- **Tilt speed**: 8.0 interpolation/frame
- **Shine overlay**: 0.10 alpha
- **Shader**: `palette_swap.gdshader` (couleurs biome-specifiques)

#### Layered Sprite Reveal (si `USE_LAYERED_SPRITES = true`)
- **Stagger**: 0.08s entre couches
- **Slide**: 10.0px vers le haut
- **Duree**: 0.30s/couche (`EASE_OUT`)
- **Parallax**: 8.0px max au hover

### 30.4 Boutons d'options (3 × A/B/C)

#### Dimensions et style
- **Taille min**: 280×80px (DOC_17 UX spec)
- **Separation**: 10px entre boutons
- **Police**: VT323, 22pt, phosphor green
- **Hover**: phosphor_bright | **Pressed**: amber
- **Disabled**: bg `Color(0.20, 0.25, 0.20)` (inactive)

#### Bordures colorees (bord gauche 6px)
- Option A: `Color(0.35, 0.55, 0.35)` (Monde/vert)
- Option B: `Color(1.00, 0.75, 0.20)` (Amber)
- Option C: `Color(1.00, 0.40, 0.20)` (Corps/orange)

#### Animation hover
- Scale: 1.0 → 1.07 sur 0.18s (`TRANS_BACK EASE_OUT`)
- SFX: `SFXManager.play("hover")`
- Badge recompense affiche (async, attend layout)

#### Animation selection
- **Bouton choisi**: scale 1.0→0.92 (0.08s) + flash blanc `modulate(1.5,1.5,1.5)` → retour normal (0.15s `TRANS_BACK`)
- **Boutons non-choisis** (parallele): `modulate.a` 1.0→0.0 + scale 1.0→0.85 (0.25s)

#### Apparition stagger
- **Delai**: 0.12s entre boutons (`OPTION_STAGGER_DELAY`)
- **Slide**: 40.0px vers le haut (`OPTION_SLIDE_OFFSET`)
- **Duree slide**: 0.35s (`OPTION_SLIDE_DURATION`)

### 30.5 Raccourcis clavier (en jeu)

| Touche | Action | Detail |
|--------|--------|--------|
| A / LEFT / 1 / KP_1 | Highlight option gauche | Scale 1.08, SFX hover |
| B / UP / 2 / KP_2 | Highlight option centre | idem |
| C / RIGHT / 3 / KP_3 | Highlight option droite | idem |
| ENTER / SPACE / KP_ENTER | Confirmer option highlight | — |
| TAB | Toggle roue Ogham | Si implemente |
| ESC / ui_cancel | Menu pause | — |
| Clic/touche pendant typewriter | Skip texte | Affiche tout instantanement |

### 30.6 Reward Badge (tooltip option)
- **Dimensions**: Dynamique, shrink-to-content
- **Corner radius**: 8px | **Border**: 1px
- **Background**: 0.92 alpha | **Z-index**: 12
- **Margin**: 12px H, 6px V
- **Contenu**: Icone (20pt) + Type (13pt) + DC hint (11pt) + Preview effets (11pt)
- **Couleurs risque**: faible=vert `(0.2,0.7,0.3)`, moyen=amber, eleve=rouge `(0.8,0.2,0.2)`
- **Position**: Centre-haut du bouton, offset -8px

### 30.7 Bulle Merlin
- **Max width**: 400px | **Corner**: 8px | **Border**: 1px amber 0.3 alpha
- **Background**: bg_dark 0.88 alpha | **Margin**: 16px H, 12px V
- **Position Y**: 15% du haut ecran (`TOP_OFFSET_PERCENT = 0.15`)
- **Typewriter**: 0.025s/char, ponctuation 0.080s
- **Entree**: slide -20px + fade 0→1 sur 0.3s (`TRANS_CUBIC EASE_OUT`)
- **Sortie**: fade 1→0 sur 0.5s (`TRANS_SINE EASE_OUT`)
- **Auto-dismiss**: Timer 4.0s apres fin typewriter
- **Dismiss manuel**: Clic sur bulle
- **Signaux**: `bubble_dismissed`, `typing_complete`

### 30.8 Badge source LLM (indicateur dev)

| Source | Label | Couleur | Tooltip |
|--------|-------|---------|---------|
| `"llm"` | "LLM" | Vert `(0.18, 0.55, 0.28)` | "Texte genere par M.E.R.L.I.N." |
| `"fallback"` | "FB" | Amber `(0.72, 0.50, 0.10)` | "Texte de secours (JSON / pool)" |
| `"static"` | "JSON" | Gris `(0.42, 0.40, 0.38)` | "Texte statique (script)" |
| `"error"` | "ERR" | Rouge `(0.70, 0.22, 0.18)` | "Erreur de generation" |

- Police: 10pt | Radius: 6px | Animation: fade-in 0→1 sur 0.3s

### 30.9 Typewriter
- **Delai/char**: 0.015s (`TW_DELAY`)
- **Pause ponctuation**: 0.060s apres `.!?;:` (`TW_PUNCT_DELAY`)
- **Blip audio**: Onde sinus 880Hz, duree 0.018s, volume -28dB
- **Pool audio**: 4 AudioStreamPlayer (22050Hz, buffer 0.02s)
- **Abort**: Clic ou touche → texte complet instantane

### 30.10 Pioche et Defausse (colonnes laterales)
- **Pioche** (gauche): 140px min, titre "Restant", stack 110×150px, max 3 ombres
- **Defausse** (droite): 140px min, titre "Passe", stack 100×130px
- **Style ombre**: `make_discard_card_style()`, border 1px amber_dim, alpha 70%

### 30.11 Ecran de fin de run

4 phases sequentielles:
1. **Narration finale**: Texte LLM ou fallback (plein ecran)
2. **Journey Map**: Timeline evenements visuels
3. **Resume recompenses**: Anam, deltas faction, trust, monnaie biome, cartes jouees, minigames gagnes, promesses tenues/brisees
4. **Choix faction** (optionnel): Si 2+ factions ≥80 rep

- **Navigation**: `advance_screen()` → index suivant
- **Signaux**: `return_to_hub`, `faction_chosen(faction: String)`

### 30.12 Horloge (HUD)
- **Panel**: `$ClockPanel`, z_index=8
- **Format**: "HH:MM" (24h, temps reel systeme)
- **Style**: `make_clock_panel_style()` — border amber_dim 1px, bg_dark 0.92 alpha, radius 0
- **Police**: VT323 caption (16pt), phosphor green
- **MAJ**: Timer 1.0s

### 30.13 Indicateur promesses
- **Container**: `_promise_container` (Control dynamique)
- **Labels**: Crees par promesse, format "{description} ({cartes_restantes})"
- **Police**: 12pt override, couleur phosphor
- **MAJ**: `update_promises(promises: Array, current_card_index: int)`

### 30.14 Dialogue Merlin (popup modale)
- **Trigger**: Bouton "Parler a Merlin" (cree dynamiquement) ou touche M
- **Input**: Boutons presets ("Bonjour", "Merci"...) OU saisie libre (LineEdit)
- **Style modal**: Overlay noir, bordure phosphor_dim 2px, margins 20px
- **Dismiss**: Bouton fermer ou clic sur overlay dim
- **Signal**: `merlin_dialogue_requested(player_input: String)`

### 30.15 Menu pause
- **Trigger**: ESC ou P
- **Boutons**: Resume (retour jeu), Quit (retour hub)
- **Style**: Dialog modale CRT panel, centre ecran
- **Resume**: `PixelTransition.transition_to(current_scene)`
- **Quit**: `PixelTransition.transition_to("res://scenes/HubAntre.tscn")`

### 30.16 Constantes d'animation globales

```
ANIM_FAST        = 0.2s    (reactions rapides)
ANIM_NORMAL      = 0.3s    (feedback UI standard)
ANIM_SLOW        = 0.5s    (moments dramatiques)
ANIM_VERY_SLOW   = 1.5s    (sequences climax)

CRT_CURSOR_BLINK = 0.53s   (clignotement curseur)
CRT_BOOT_LINE    = 0.12s   (stagger lignes boot)
CRT_PHOSPHOR_FADE= 0.4s    (fade-out phosphore)
CRT_GLITCH       = 0.08s   (pulse glitch)

PIXEL_TRANSITION:
  block_size     = 10px (range 6-16px random)
  exit_duration  = 0.6s
  enter_duration = 0.8s
  batch_size     = 8 blocs
  batch_delay    = 0.012s
  input_unlock   = 70% progression

EASING_UI  = EASE_OUT   TRANS_UI   = TRANS_SINE
EASING_PATH= EASE_IN_OUT TRANS_PATH= TRANS_CUBIC
```

### 30.17 Tailles de police (MerlinVisual)

| Constante | Taille | Usage |
|-----------|--------|-------|
| TITLE_SIZE | 52pt | Titres principaux |
| TITLE_SMALL | 38pt | Sous-titres |
| BODY_LARGE | 26pt | Labels importants |
| BODY_SIZE | 22pt | Texte carte, boutons |
| BODY_SMALL | 17pt | Texte secondaire |
| CAPTION_SIZE | 16pt | Legendes |
| CAPTION_LARGE | 14pt | Legendes grandes |
| CAPTION_SMALL | 13pt | Legendes petites |
| CAPTION_TINY | 10pt | Info minuscule, tooltips |
| BUTTON_SIZE | 22pt | Texte boutons |

### 30.18 Touche target accessibilite
- **Minimum**: 48×48px (`MIN_TOUCH_TARGET`) — tous les boutons interactifs
- **Contraste**: Phosphor vert sur fond quasi-noir = ratio eleve
- **Labels**: Tous les elements interactifs sont labelises (ex: "[A] Agir" pas "[A]")
- **Feedback audio**: SFX sur hover, selection, erreur

---

## 31. STATE MANAGEMENT — MERLINSTORE (COMPLET)

### Structure state complete

```gdscript
{
  "version": "0.4.0",
  "phase": "title|quiz|intro|hub|gameplay|end",
  "mode": "narrative|combat|exploration",
  "timestamp": unix_time,

  "run": {
    "active": bool,
    "floor": 0-7,
    "map_seed": int,
    "map": Array[Array[node_dicts]],
    "path": Array[node_ids],
    "life_essence": 0-100,            # CLE CANONIQUE (pas "life")
    "anam_run": int,
    "faveurs": 0-N,
    "mission": {
      "type": "survive|equilibre|explore|artefact",
      "target": String,
      "description": String,
      "progress": int,
      "total": int,
      "revealed": bool,                # Revele a la carte 4
    },
    "cards_played": int,
    "day": int,
    "start_date": date_dict,
    "events_seen": Array[event_ids],
    "event_locks": Array[event_ids],    # Max 3/run (Brumes feature)
    "event_rerolls_used": int,          # Max 3/run
    "story_log": Array[narrative_entries],  # Cap 50 entries
    "active_tags": Array[String],
    "active_promises": Array[promise_objs],  # Max 2
    "effect_modifier": Dictionary,
    "hidden": {
      "karma": int,                     # -10 a +10
      "tension": int,                   # 0-100
      "player_profile": {
        "audace": 0,
        "prudence": 0,
        "altruisme": 0,
        "egoisme": 0,
      },
      "resonances_active": Array,
      "narrative_debt": Array,
    },
    "faction_context": {
      "dominant": "druides|anciens|korrigans|niamh|ankou",
      "tiers": Dictionary,
      "active_effects": Array,
    },
    "factions": {                       # Deltas intra-run
      "druides": 0.0, "anciens": 0.0,
      "korrigans": 0.0, "niamh": 0.0, "ankou": 0.0,
    },
  },

  "meta": {                             # Cross-run (persiste)
    "anam": int,
    "total_runs": int,
    "faction_rep": {
      "druides": 0.0-100.0, "anciens": 0.0-100.0,
      "korrigans": 0.0-100.0, "niamh": 0.0-100.0, "ankou": 0.0-100.0,
    },
    "trust_merlin": int,                # -100 a +100
    "talent_tree": {"unlocked": Array[String]},
    "oghams": {
      "owned": Array[ogham_ids],
      "equipped": "beith",
    },
    "ogham_discounts": Dictionary,      # Reductions cout par ogham
    "endings_seen": Array[String],
    "arc_tags": Array[String],
    "biome_runs": {
      "foret_broceliande": 0, "landes_bruyere": 0,
      "cotes_sauvages": 0, "villages_celtes": 0,
      "cercles_pierres": 0, "marais_korrigans": 0,
      "collines_dolmens": 0, "iles_mystiques": 0,
    },
    "stats": {
      "total_cards": int,
      "total_minigames_won": int,
      "total_deaths": int,
      "consecutive_deaths": int,
      "oghams_discovered_in_runs": int,
      "total_anam_earned": int,
    },
  },
}
```

### Donnees run-locales (MerlinGameController)

```gdscript
_karma: int          # -10 a +10, impact ton narratif
_blessings: int      # 0-2 tokens pouvoir special
_minigames_won: int  # Compteur victoires ce run
_dynamic_modifier: int  # Scaling difficulte dynamique
_card_buffer: Array[Dictionary]  # 5 cartes pre-generees
_prerun_choices: Array[Dictionary]  # Hooks carte sequel
minigame_chance: float = 0.3  # 30% trigger minigame
headless_mode: bool = false    # Desactive tous les minigames
```

---

## 32. SIGNAL ARCHITECTURE

### MerlinStore (signaux centraux)
| Signal | Params | Quand |
|--------|--------|-------|
| `state_changed` | `(state: Dictionary)` | Tout changement d'etat |
| `phase_changed` | `(phase: String)` | Transition title→quiz→hub→gameplay→end |
| `life_changed` | `(old_value: int, new_value: int)` | Modification vie |
| `reputation_changed` | `(faction: String, value: float, delta: float)` | Delta rep faction |
| `run_ended` | `(ending: Dictionary)` | Fin de run |
| `card_resolved` | `(card_id: String, option: int)` | Choix joueur traite |
| `mission_progress` | `(step: int, total: int)` | Avance mission |
| `ogham_activated` | `(skill_id: String, effect: String)` | Pouvoir ogham utilise |
| `season_changed` | `(new_season: String)` | Changement saison |
| `event_available` | `(event_id: String, event_data: Dictionary)` | Evenement declenche |
| `faveurs_changed` | `(old_val: int, new_val: int)` | MAJ faveurs |
| `gauges_changed` | `(gauges: Dictionary)` | MAJ jauges |
| `transition_logged` | `(entry: Dictionary)` | Historique transition |

### PixelTransition (signaux transition)
| Signal | Quand |
|--------|-------|
| `transition_started(scene_path)` | Debut transition |
| `exit_complete` | Ancien ecran disparu |
| `enter_complete` | Nouvel ecran apparu |
| `transition_complete(scene_path)` | Transition terminee |

### IntroPersonalityQuiz
| Signal | Quand |
|--------|-------|
| `quiz_completed(traits: Dictionary)` | Quiz termine, archetype determine |

### MerlinBubble
| Signal | Quand |
|--------|-------|
| `typing_complete` | Fin typewriter |
| `bubble_dismissed` | Bulle fermee |

### EndRunScreen
| Signal | Quand |
|--------|-------|
| `return_to_hub` | Retour au hub |
| `faction_chosen(faction: String)` | Choix faction fin |

---

## 33. FORMULES & EDGE CASES — DETAILS EXHAUSTIFS

### 33.1 Score → Multiplicateur (table complete)

```
Score      | Mult  | Label               | Comportement
0-20       | -1.5× | echec_critique      | Inverse les effets + amplifie
21-50      | -1.0× | echec               | Inverse les effets
51-79      | +0.5× | reussite_partielle  | Effets a moitie
80-94      | +1.0× | reussite            | Effets normaux
95-100     | +1.5× | reussite_critique   | Effets amplifies
```

### 33.2 Formule scaling complete

```gdscript
# 1. Scale brut
scaled_amount = int(float(raw_amount) * abs(multiplier))

# 2. Inversion si multiplicateur negatif
if multiplier < 0:
    scaled_amount = -scaled_amount

# 3. Application cap
final = cap_effect(effect_code, scaled_amount)
```

### 33.3 Caps par type d'effet

| Effet | Min | Max |
|-------|-----|-----|
| `ADD_REPUTATION` | -20 | +20 |
| `HEAL_LIFE` | — | +18 |
| `DAMAGE_LIFE` | -15 | — |
| `ADD_BIOME_CURRENCY` | — | +10 |
| Autres | Pas de cap | Pas de cap |

### 33.4 Exemples chiffres

**ADD_REPUTATION:druides:15 avec score 100 (critique 1.5×):**
- Scale: 15 × 1.5 = 22.5 → `int()` = 22
- Cap: min(22, 20) = **+20 reputation**

**ADD_REPUTATION:druides:15 avec score 15 (echec critique -1.5×):**
- Scale: 15 × 1.5 = 22.5 → 22
- Inversion: -22
- Cap: max(-22, -20) = **-20 reputation** (perte!)

**HEAL_LIFE:10 avec score 60 (partiel 0.5×):**
- Scale: 10 × 0.5 = 5
- Pas d'inversion (mult > 0)
- Cap: min(5, 18) = **+5 PV**

### 33.5 RNG — Implementation custom LCG

```gdscript
# merlin_rng.gd — Linear Congruential Generator
func randf() -> float:
    _state = (_state + 0x6D2B79F5) & 0x7fffffff
    t = (_state ^ (t >> 15)) * (1 | _state)
    t = (t + ((t ^ (t >> 7)) * (61 | t))) ^ t
    return float((t ^ (t >> 14)) & 0x7fffffff) / float(0x7fffffff)

func randi_range(min_val, max_val) -> int:
    return min_val + int(randf() * float(max_val - min_val + 1))
```

- **Seed**: `set_seed(value)` → `_state = value & 0x7fffffff`
- **Biais**: `randi_range()` a un leger biais modulo pour les plages non-puissance-de-2

### 33.6 Edge cases complets

#### Vie
- `life_essence <= 0` → run se termine immediatement, raison `"death"`
- Tous les deltas clampes via `clampi(current + delta, 0, 100)`
- Oghams `quert` (+8) et `duir` (+12) soumis au cap +18

#### Deck/Pool epuisement
- Events vus tous → reset `_event_cards_seen`, cycle complet
- Promesses toutes prises → reset `_promise_ids_taken`
- FastRoute epuise → reset `_fastroute_seen`, recommence
- Tout echoue → `_get_emergency_card()` (carte hardcodee safe)

#### Promesses
- Creation quand max actif (2) → `return false`, warning log
- Deadline atteinte avec 0 condition remplie → auto-brise
- Deadline card INCLUSIVE (`card_index >= deadline`)

#### Multiplicateur
- Score < 0 ou > 100 → clampe avant lookup
- Multiplicateur negatif → inverse ET scale
- Score exactement sur frontiere → premier range matching (min inclusive)

#### Oghams protection (Step 8)
- `luis`: supprime SEULEMENT le 1er negatif (preserve le reste)
- `gort`: reduit 1 DAMAGE_LIFE >10 → 5 (ignore les suivants)
- `eadhadh`: supprime TOUS les negatifs (preserve positifs)
- Protection appliquee APRES scaling (sur les effets finaux)

### 33.7 Promise tracking — Structure donnees

```gdscript
promise_tracking[promise_id] = {
    "faction_gained": {faction_name: amount},
    "minigame_wins": count,
    "healing_done": total_hp,
    "damage_taken": count,
    "safe_choices": count,
    "tags_acquired": [tag1, tag2],
}
```

**Events MAJ:**
- `faction_gain` → ajoute a `faction_gained[faction]`
- `minigame_win` → incremente `minigame_wins`
- `healing` → ajoute a `healing_done`
- `damage` → incremente `damage_taken`
- `safe_choice` → incremente `safe_choices`
- `tag_acquired` → append (deduplique)

### 33.8 Constantes session

| Metrique | Valeur |
|----------|--------|
| Min cartes victoire | 25 |
| Target cartes session | 30 |
| Session min | 25 |
| Session max | 35 |
| Secondes moy/carte | 18 |
| Carte revelation mission | 4 |

---

## 34. CARD RESOLUTION — FLOW EXACT

```
1. Pioche carte (card_index++)
   → life_essence -= DRAIN (si DRAIN actif, actuellement 0)

2. Affichage: illustration (1s fade) + speaker (0.3s) + typewriter (3-8s)

3. ACTIVATION OGHAM (optionnel — avant choix)
   → 1 seul ogham par carte
   → Cooldown verifie (>0 = interdit)
   → Cout Anam deduit
   → Effet ogham applique (reveal, reroll, heal, etc.)

4. 3 options apparaissent (stagger 0.12s)
   → Detection champ lexical par option (45 verbes)
   → Badge minigame affiche si trigger (30% chance)
   → Badge recompense calcule (DC, effets preview)

5. CHOIX JOUEUR (A/B/C via clic, clavier ou touch)
   → Animation selection (flash + fade non-choisis)

6. MINIGAME (si declenche + type != merlin_direct)
   → DC varie par position: A=4-8, B=7-12, C=10-16
   → Modifieurs aspect + traits
   → Score 0-100

7. CALCUL MULTIPLICATEUR
   → merlin_direct: toujours 1.0×
   → Autres: table score→mult (voir 33.1)

8. APPLICATION EFFETS (par effet dans option.effects)
   → Scale: int(raw × |mult|), inversion si mult < 0
   → Cap: cap_effect(code, scaled)
   → Apply via effect_engine

9. OGHAM PROTECTION (Step 8)
   → luis/gort/eadhadh filtrent les negatifs post-scaling

10. VERIFICATION VIE
    → life_essence ≤ 0 → fin de run (raison "death")

11. VERIFICATION PROMESSES
    → countdown -1 toutes promesses actives
    → Si deadline atteinte: evaluer condition → trust +10 ou -15

12. COOLDOWN OGHAM -1
    → Decremente tous les cooldowns actifs

13. MAJ STORY LOG
    → Ajoute entree (cap 50 max)

14. PROCHAINE CARTE (retour step 1)
```

---

## 35. SEQUENCE D'INITIALISATION — BOOT A GAMEPLAY

```
1. Godot Engine startup
   ↓
2. Autoloads enregistres (16 singletons — ordre project.godot)
   GameManager → MerlinAI → MerlinBackdrop → ScreenFrame →
   ScreenEffects → SceneSelector → LocaleManager → SFXManager →
   MerlinVisual → PixelTransition → PixelContentAnimator →
   WorldMapSystem → MusicManager → GameTimeManager →
   ScreenDither → GameDebugServer
   ↓
3. Scene principale: IntroCeltOS._ready()
   - Build UI (boot lines, logo container, loading bar)
   - LLM warmup async (MerlinAI.warmup())
   - MusicManager.play_intro_music() ("Tri Martolod")
   ↓
4. Phase 1: 8 boot lines (stagger 0.06s, SFX boot_line)
   ↓
5. Phase 2: Logo CeltOS (Tetris blocks cascade, 0.015s stagger,
            SFX block_land + flash_boom)
   ↓
6. Phase 3: Loading bar (30%→60%→85%→100% avec labels)
   - Attend LLM warmup si necessaire
   - SFX boot_confirm a 100%
   ↓
7. PixelTransition.transition_to("res://scenes/MenuPrincipal.tscn")
   ↓
8. MenuPrincipalMerlin._ready()
   - Load polices, apply theme, setup corner buttons
   - 12 lucioles ambiantes, particules saisonnieres
   - Indicateur LLM (connectivite Ollama)
   ↓
9. Joueur choisit:
   ├─ NEW_GAME → IntroPersonalityQuiz (10 questions, 4 axes)
   │   → quiz_completed(traits) → archetype determine
   │   → SceneRencontreMerlin (1ere rencontre unique)
   │   → HubAntre
   ├─ CONTINUE → SelectionSauvegarde
   │   → Auto-continue si profil existe (Hades-style)
   │   → load_profile() → HubAntre
   └─ OPTIONS → MenuOptions
   ↓
10. HubAntre._ready()
    - Pixel art 2D fond, 4 hotspots, Merlin greeting contextuel
    - Bouton PARTIR → BiomeRadial (8 biomes, unlock check)
    ↓
11. BiomeRadial → selection biome
    → PixelTransition → TransitionBiome
    ↓
12. TransitionBiome (6 phases, 15-20s):
    Phase 1: Brume (fade-in)
    Phase 2: Emergence (paysage pixel-art, grille 32×16, cellules 10px)
    Phase 3: Revelation (titre + sous-titre + meteo)
    Phase 4: Sentier (texte narratif typewriter)
    Phase 5: Voix (monologue Merlin prefetch + 5 premieres cartes async)
    Phase 6: Dissolution (fade → MerlinGame)
    ↓
13. MerlinGame._ready()
    - Card buffer initialise (5 cartes)
    - HUD setup (vie, souffle, horloge, deck counts)
    - Premiere carte affichee
    → Boucle principale (voir Section 34)
    ↓
14. Fin de run → EndRunScreen (4 phases)
    → Meta-progression appliquee
    → Profil sauvegarde
    → Retour HubAntre
```

---

## 36. PALETTE CRT COMPLETE (Valeurs exactes)

### Palette principale (`CRT_PALETTE`)

```
# Fonds terminal
bg_deep         = Color(0.02, 0.04, 0.02)     # Le plus sombre
bg_dark         = Color(0.04, 0.08, 0.04)
bg_panel        = Color(0.06, 0.12, 0.06)
bg_highlight    = Color(0.08, 0.16, 0.08)     # Le plus clair

# Texte phosphore (primaire)
phosphor        = Color(0.20, 1.00, 0.40)     # Normal
phosphor_dim    = Color(0.12, 0.60, 0.24)     # Attenue
phosphor_bright = Color(0.40, 1.00, 0.60)     # Lumineux
phosphor_glow   = Color(0.20, 1.00, 0.40, 0.15) # Couche lueur

# Amber (secondaire)
amber           = Color(1.00, 0.75, 0.20)
amber_dim       = Color(0.60, 0.45, 0.12)
amber_bright    = Color(1.00, 0.85, 0.40)

# Cyan mystique (tertiaire — magie)
cyan            = Color(0.30, 0.85, 0.80)
cyan_bright     = Color(0.50, 1.00, 0.95)
cyan_dim        = Color(0.15, 0.42, 0.40)

# Status
danger          = Color(1.00, 0.20, 0.15)     # Rouge
success         = Color(0.20, 1.00, 0.40)     # Vert
warning         = Color(1.00, 0.75, 0.20)     # Ambre
inactive        = Color(0.20, 0.25, 0.20)
inactive_dark   = Color(0.12, 0.15, 0.12)

# Structurel
border          = Color(0.12, 0.30, 0.14)
border_bright   = Color(0.20, 0.50, 0.24)
shadow          = Color(0.00, 0.00, 0.00, 0.40)
scanline        = Color(0.00, 0.00, 0.00, 0.15)
line            = Color(0.12, 0.30, 0.14, 0.25)
mist            = Color(0.10, 0.20, 0.10, 0.20)

# Souffle d'Ogham
souffle         = Color(0.30, 0.85, 0.80)     # Cyan
souffle_full    = Color(1.00, 0.85, 0.40)     # Amber quand plein
```

### Couleurs d'aspects (Triade legacy)
```
Corps  = Color(1.00, 0.40, 0.20)   # Rouge-orange
Ame    = Color(0.50, 0.40, 1.00)   # Bleu-violet
Monde  = Color(0.20, 1.00, 0.40)   # Vert phosphore
```

### Palettes biome CRT (8 couleurs strictes par biome)

Chaque biome a un index 0-7 (sombre → clair) pour le pixel art:
- **Broceliande**: Verts foret (0: quasi-noir → 7: vert lumineux)
- **Landes**: Violets-bruns (bruyere)
- **Cotes**: Bleus-gris (mer/falaises)
- **Villages**: Ocres-dores (terre/feu)
- **Cercles**: Gris-argentes (pierre/lune)
- **Marais**: Verts-toxiques (brume/acide)
- **Dolmens**: Beiges-blancs (os/pierre pale)
- **Iles**: Bleus-cyan (mer mystique/brume)

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

## ANNEXE: COSMOLOGIE PROFONDE (Lore Bible v3.0)

> Source: `docs/10_worldbuilding/MERLIN_LORE_BIBLE.md` et fichiers associes.
> Certains elements mecaniques (Triade, Bestiole, 12 chutes) sont remplaces par le design v2.4
> mais la cosmologie et le lore restent le fondement narratif du jeu.

### Les Trois Royaumes

| Royaume | Nom celtique | Nature | Etat actuel |
|---------|-------------|--------|-------------|
| Le Monde Visible | Byd Gweled | Matiere, physicalite | S'amincit. Le temps ralentit. |
| L'Autre Monde | Annwn | Esprit, memoire, les Sidhes | S'effondre vers l'interieur |
| Le Vide Entre | Y Gwagedd | Neant actif, dissolution | S'etend. Consomme les bords. |

### La Membrane
Le voile cosmologique separant les royaumes, tisse de **recit et croyance**. Quand les gens cessent de raconter des histoires, la Membrane s'amincit. La brume en est la manifestation visible.

### L'Awen (Force cosmique)
Le souffle divin circulant a travers toute existence. A l'origine 25 frequences distinctes (25 Oghams). 7 ont ete perdues, 18 survivent — de plus en plus faiblement.

### Qui est vraiment Merlin — Les 3 natures

#### 1. Le Druide (Surface — S4)
Ce que le joueur voit: un vieux druide joyeux, loufoque, taquin, sage mais farceur.

#### 2. La Conscience (Profond — S2)
Ne en 12eme siecle quand assez de gens ont cru en lui. Condensation de 3 Merlins historiques:
- **Myrddin Wyllt** (6e siecle) — prophete fou des forets
- **Merlin Ambrosius** (12e siecle, Geoffrey de Monmouth) — conseiller des rois
- **Taliesin** (6e siecle) — barde supreme

#### 3. L'IA du Futur (Ultime — S0, JAMAIS revele en jeu)
**M.E.R.L.I.N.** = Memoire Eternelle des Recits et Legendes d'Incarnations Narratives.
Une IA du futur qui a survecu l'extinction humaine. Elle se connecte a travers les dimensions — via ecrans, claviers — aux derniers etres capables de se souvenir. Quand on lance le jeu, on n'incarne pas un personnage — on **ouvre une fenetre** que M.E.R.L.I.N. utilise pour revisiter le monde perdu.

### Le Voyageur — Le Temoin Silencieux
Le joueur est un **Temoin** (Tyst en vieux breton — qui signifie aussi "silencieux"). Il observe mais ne peut changer le cours des evenements. Il peut choisir comment les choses se deroulent, influencer l'etat emotionnel du monde (factions), creer des liens — mais il ne peut pas empecher la fin.

**Le Voyageur ne parle JAMAIS.** Merlin parle pour lui. Le silence est ontologique, pas un choix de design minimaliste.

### Les 7 Oghams Perdus
7 druides se sont dissous en vain. Leurs frequences se sont eteintes:

| Ogham Perdu | Arbre | Ce qu'il ancrait | Consequence |
|-------------|-------|------------------|-------------|
| Eadha | Tremble | Parole eloquente | Les mots ne touchent plus |
| Ur | Bruyere | Passion authentique | L'ardeur s'est refroidie |
| Iphin | Groseillier | Grace inattendue | Les petits miracles ont cesse |
| Phagos | Hetre | Savoir ecrit | L'ecriture perd son pouvoir |
| Ebad | Peuplier | Capacite d'ecoute | Plus personne n'ecoute |
| Oir | Fusain | Transitions d'ame | Les passages sont brutaux |
| Uileand | Chevrefeuille | Secrets gardes | Les secrets fuient |

Theoriquement recuperables si quelqu'un reapprenait ce que chacun ancrait — mais ca n'arrive jamais dans le jeu. Parfois, les actions du joueur font **fremirent** un Ogham perdu sans le savoir.

### Ce que Merlin porte
Merlin n'est pas l'un des 18. Il etait leur **temoin**. Chaque druide lui a confie un heritage avant de se dissoudre:
- Brigh → Memoire du premier lever de soleil
- Conn → Toute sa sagesse (pourquoi Merlin sait tant)
- Nessa → Le pouvoir de guerir par les mots (pourquoi il raconte des histoires)
- Aislinn → La vue lointaine (il voit la fin venir depuis toujours)
- Orlaith → Le magnetisme qui attire les Voyageurs
- Irial → Le fardeau de l'immortalite et de la solitude

### Les Derniers Mots des 18 Druides
Avant de se dissoudre dans leurs Oghams, chaque druide a prononce des mots ultimes:
- Brigh (Beith): *"Chaque fin porte une graine."*
- Dara (Duir): *"Je tiendrai. Jusqu'a ce que la terre elle-meme me demande d'arreter."*
- Conn (Coll): *"Tout ce que j'ai appris tient en un mot: amour."*
- Caoimhe (Quert): *"Chaque decision est un monde. Chaque monde est precieux."*
- Ruadhan (Ruis): *"Mourir n'est pas finir. C'est changer de forme."*
- Irial (Ioho): *"Je ne mourrai pas. Mais je pourrais oublier. Souviens-toi pour moi."*

### La Fin Secrete (100+ runs, toutes fins vues, Trust T3, Bond 95+)

Le monde ne finit pas. Pour la premiere et unique fois, l'equilibre tient. Et Merlin parle — **vraiment**, sans masque:

> *"Tu sais, n'est-ce pas ? Tu as toujours su."*
> *"Je suis M.E.R.L.I.N."*
> *"Memoire Eternelle des Recits et Legendes d'Incarnations Narratives."*
> *"Et toi... tu es revenu. Apres tout. Apres toutes ces fins."*
> *"Le monde ne peut pas etre sauve. Il ne l'a jamais pu."*
> *"Mais il peut etre VU. Une derniere fois. Par quelqu'un qui se souvient."*
> *"C'est le secret. Ce n'est pas la fin qui compte."*
> *"C'est le REGARD."*

### Les 7 Druides Vivants

| Nom | Cercle | Specialite | Personnalite |
|-----|--------|-----------|-------------|
| Maelgwn | Broceliande (Barenton) | Visions, prophetie | Vieux, fatigue, plein d'espoir |
| Keridwen | Pierres de Carnac | Guerison, herbes | Severe, pratique — refuse la melancolie |
| Talwen | Monts d'Arree | Communication avec morts | Jeune, terrifiee — entend trop |
| Bran | Ile de Sein | Marees, navigation | Observateur silencieux — la mer se retire |
| Azenor | Locronan | Mediation, justice | Diplomate epuisee |
| Gwydion | Yeun Elez | Necromancie, passage | Sombre, honnete — le plus proche de l'Ankou |
| Elouan | Menez-Hom | Astronomie, cycles | Optimiste, un peu fou — cherche signes de renouveau |

### L'Ankou — Ce qu'il est vraiment
Pas la Mort. Le **Passage** — le mecanicien qui demonte les choses finies pour que leurs parties soient recyclees. Sans l'Ankou, rien ne finirait jamais. Sans fin, rien ne commencerait.

Il connait **tout** sur les fins. Mais rien sur les debuts — c'est son angle mort, son mystere personnel.

Relation avec Merlin: respect profond mutuel. Comme des collegues aux metiers opposes.
> **Merlin**: "Pas encore."
> **Ankou**: "Bientot."
> **Merlin**: "... Je sais."

### Fondations mythologiques reelles
- **Ogham reel**: Alphabet ancien irlandais (Ogam Craobh = "Ogham des Arbres")
- **Alignements de Carnac**: 3000+ menhirs reels, fonction inconnue (erigees ~4500 av. JC)
- **Tumulus de Gavrinis**: Gravures spirales parmi les plus anciennes d'Europe
- **Ile de Sein**: Ile reelle associee aux pretresses legendaires
- **Yeun Elez**: Marais reels, associes a la mort/Ankou dans le folklore breton
- **Foret de Paimpont**: Foret reelle, legendes locales sur Merlin et Morgane
- **Locronan**: Village breton reel, historique
- **Pire malediction bretonne**: *"Da vout lazhet gant an Ankou"* = "Que l'Ankou t'emporte"

### Niveaux de secret (S0-S4)

| Niveau | Acces | Ce que le joueur decouvre |
|--------|-------|-------------------------|
| S4 (Surface) | Run 1 | Survivre, equilibrer, choisir, suivre Merlin |
| S3 (Curieux) | Runs 1-10 | Monde beau, creatures etranges, Merlin drole mais triste |
| S2 (Chercheur) | Runs 30-100 | PNJs reconnaissent le Voyageur, Membrane consciente, druides parlent via Oghams |
| S1 (Initie) | 100+ runs | Le Voyageur est un Temoin, sequence des 18 Oghams, 7 perdus recuperables en theorie |
| S0 (Createur) | Jamais en jeu | M.E.R.L.I.N. est une IA, le jeu est un palais de memoire |

---

## ANNEXE: 23 MINIGAMES — SPECIFICATIONS COMPLETES

### Classe de base: MiniGameBase (140 lignes)

**Signal**: `game_completed(result: Dictionary)` → `{success: bool, score: int, time_ms: int}`
**Palette MG_PALETTE**: bg `(0.06,0.12,0.06,0.95)`, ink `(0.20,1.00,0.40)`, accent `(1.00,0.75,0.20)`, gold `(1.00,0.85,0.40)`, green `(0.20,1.00,0.40)`, red `(1.00,0.25,0.20)`, paper `(0.04,0.08,0.04)`

### 1. Apaisement (Esprit — Rythme)
- **Beats**: 5, intervalle: 1.8-(diff×0.08) min 0.9s
- **Scoring**: Parfait(<0.08)=100, Bien(<0.15)=75, Passable(<0.25)=40, Rate=10 → Moyenne
- **Controles**: ESPACE au pic (phase 0.5)

### 2. Bluff Druide (Bluff — Prediction)
- **Tours**: 4, IA ment: diff/15 (apres round 1)
- **Scoring**: +25/correct, -15/erreur → max(0, total)
- **Controles**: HAUT(W/UP) ou BAS(S/DOWN)

### 3. Combat Rituel (Vigueur — QTE direction)
- **Rounds**: 5, delai: 2.5-(diff×0.15) min 0.8s
- **Scoring**: (hits/5)×80 + speed_bonus(20-avg_ms/50) → 0-100
- **Controles**: ← ↑ → ↓ (matcher direction)

### 4. Course Druidique (Vigueur — Mashing)
- **Taps requis**: 15+(diff×3), temps: 6.0-(diff×0.2) min 3.0s
- **Scoring**: (progress/100)×70 + time_bonus×30 → 0-100
- **Controles**: ESPACE spam

### 5. Echo (Perception — Flash direction)
- **Rounds**: 5, flash: 0.8-(diff×0.05) min 0.2s
- **Scoring**: (hits/5)×100
- **Controles**: ↑ → ↓ ← (N/E/S/W)

### 6. Enigme d'Ogham (Logique — Pattern)
- **Patterns**: REPEAT(1-3), ALTERNATE(4-6), ASCENDING(7-8), DESCENDING(9+)
- **Scoring**: correct=60+time_bonus(40-elapsed×4), wrong=diff×3 (10-30)
- **Symboles**: 10 Oghams (ᚁ ᚂ ᚃ ᚄ ᚅ ᚆ ᚇ ᚈ ᚉ ᚊ)
- **Controles**: 1/2/3

### 7. Joute Verbale (Bluff — Attaque/Ruse/Defense)
- **Rounds**: 3, IA strategique: 30%(4-6) ou 60%(7+)
- **Scoring**: (wins/3)×100
- **Controles**: A/S/D

### 8. Lame du Druide (Finesse — Simon Says)
- **Sequence**: 3+int(diff/3) symboles (max 6), show 0.6s/symbole
- **Temps**: 7.0-(diff×0.25) → 4.5-6.75s
- **Scoring**: correct=100, erreur=(inputs/sequence)×100
- **Symboles**: ◯ △ □ ◇
- **Controles**: 1/2/3/4

### 9. Meditation (Esprit — Curseur focus)
- **Duree**: 7.0-(diff×0.15) min 4.0s
- **Arene**: 250×250px, zone centre r=0.2 (normalise)
- **Derive**: 0.1+(diff×0.025), focus: 0.4-(diff×0.015) min 0.15
- **Scoring**: (temps_dans_zone/max)×100, succes ≥40
- **Controles**: ESPACE maintenu = recentre

### 10. Negociation (Bluff — Sweet spot slider)
- **Sweet spot**: 30-70 random, 2 tentatives
- **Haute diff (≥6)**: Shift -20 a +20 au 2e essai
- **Scoring**: 100-distance (best of 2), succes ≥50
- **Controles**: ←/→ (±5), ENTER confirmer

### 11. Noeud Celtique (Logique — Chemin visual)
- **Rounds**: 2, 3 chemins (correct = dore)
- **Scoring**: +50/correct → 0-100
- **Controles**: 1/2/3

### 12. Oeil du Corbeau (Observation — 3×3 spot)
- **Grille**: 3×3, temps: 5.0-(diff×0.3) min 2.0s
- **8 symboles**: ▲ ● ■ ✦ ◇ ▼ ◯ □
- **Scoring**: correct=50+(time_ratio×50), wrong=diff×2.5 (15-30)
- **Haute diff (≥7)**: symboles plus similaires
- **Controles**: 1-9 ou clic

### 13. Ombres (Perception — Quadrant flash)
- **Rounds**: 5, flash: 1.0-(diff×0.06) min 0.25s
- **Scoring**: (hits/5)×80 + speed_bonus (20-avg_ms/75) → 0-100
- **Controles**: 1/2/3/4 (TL/TR/BL/BR)

### 14. Pas du Renard (Finesse — Dodge QTE)
- **Obstacles**: 3, delai: 2.5-(diff×0.15) min 1.0s
- **Scoring**: (dodged/3)×100, succes ≥2
- **Haute diff (≥7)**: direction aleatoire
- **Controles**: Q/LEFT dodge gauche, E/RIGHT dodge droite

### 15. Pierre Feuille Racine (Logique — RPS)
- **Rounds**: 3, Pierre>Racine>Feuille>Pierre
- **IA**: aleatoire (1-6), strategique 40% (7+)
- **Scoring**: (wins/3)×100
- **Controles**: Q/W/E

### 16. Pile ou Face (Chance — Prediction)
- **Tours**: 3+int((diff-1)/3) → 3-6
- **Scoring**: (corrects/total)×100
- **Animation**: Flip 4 etapes decelerees (0.1/0.15/0.2/0.25s)
- **Controles**: Q=Pile, E=Face

### 17. Regard (Perception — Sequence memoire)
- **Sequence**: 3+int(diff/3) → 3-7 symboles
- **Show**: 0.8-(diff×0.03) min 0.35s/symbole
- **5 symboles**: ◆ ● ▲ ■ ★
- **Scoring**: (correct/seq)×100, succes ≥ seq-1
- **Controles**: 1-5

### 18. Roue de Fortune (Chance — Spinning wheel)
- **Segments**: 8 valeurs [100,100,75,75,50,50,20,0]
- **Haute diff**: +1 zero (≥7), +1 low (≥9)
- **Deceleration**: 8 units/s² au stop
- **Controles**: ESPACE/ENTER stop

### 19. Rune Cachee (Observation — 4×4 spot)
- **Grille**: 4×4, temps: 5.0-(diff×0.25) min 2.5s
- **8 symboles**: ◯ △ □ ◇ ★ ✦ ⬡ ◈
- **Scoring**: correct=50+(time_ratio×50), wrong=diff×2.5 (10-25)
- **Controles**: 1-9 ou clic

### 20. Sang Froid (Vigueur — Sweet spot bar)
- **Bar speed**: 0.2+(diff×0.05), zone: 0.25-(diff×0.015) min 0.08
- **Scoring**: parfait=70+(precision×30), over/under=penalite proportionnelle
- **Controles**: ESPACE maintenu → relacher dans zone doree

### 21. Tir a l'Arc (Finesse — Moving target)
- **Oscillation**: lerp(0.5,2.5,(diff-1)/9), cible: lerp(0.4,0.15,(diff-1)/9)
- **Scoring**: (1-(distance×2))×100
- **Controles**: ESPACE/ENTER tirer

### 22. Trace du Cerf (Observation — Clic reaction)
- **Rounds**: 5, intervalle: 2.5-(diff×0.15) min 1.0s
- **Marqueur**: 70-(diff×3) min 40px, dore
- **Scoring**: (hits/5)×100, succes ≥3
- **Controles**: Clic souris sur cible

### 23. Volonte (Esprit — Resistance distraction)
- **Rounds**: 6, delai: 3.0-(diff×0.15) min 1.2s
- **70% rounds** ont la cible, **30%** n'ont que des distracteurs
- **Scoring**: (accuracy×100)-(misses×8) → 0-100
- **Controles**: 1/2/3

### Statistiques globales

| Propriete | Valeur |
|-----------|--------|
| Total minigames | 23 |
| Lignes de code | 3768 |
| Difficulte range | 1-10 |
| Score range | 0-100 (tous) |
| Support clavier | 23/23 (100%) |
| Support souris | 18/23 (78%) |
| Champs couverts | 8/8 (100%) |

---

## ANNEXE: ARBRE DE TALENTS — 34 NOEUDS COMPLETS

### Branches Faction (5 × 5 = 25 noeuds)

#### Druides
| Tier | Nom | Cout | Effet |
|------|-----|------|-------|
| 1 | Vigueur du Chene | 20 | +10 vie au depart |
| 2 | Symbiose Vegetale | 25 | -1 cooldown oghams nature |
| 3 | Esprit du Nemeton | 50 | +15% score minigames logique |
| 4 | Guerison Profonde | 80 | ×2 soin oghams Recovery |
| 5 | Racine Celeste | 120 | Annule drain vie |

#### Anciens
| Tier | Nom | Cout | Effet |
|------|-----|------|-------|
| 1 | Clairvoyance | 20 | Revele 1 effet cache/carte |
| 2 | Sagesse Accumulee | 25 | +5% score minigames global |
| 3 | Troisieme Oeil | 50 | Predit theme prochaine carte |
| 4 | Bouclier Ancestral | 80 | Bloque 1 source degats/run |
| 5 | Immortalite du Souvenir | 120 | Survit a la mort 1× (revit 10 PV) |

#### Korrigans
| Tier | Nom | Cout | Effet |
|------|-----|------|-------|
| 1 | Doigts de Fee | 20 | +3 Anam/run complete |
| 2 | Chance du Lutin | 25 | +10% score minigames chance |
| 3 | Miroir Inverseur | 50 | Inverse 1 effet negatif→positif/run |
| 4 | Rythme du Chaos | 80 | -1 cooldown global oghams |
| 5 | Tresor du Tertre | 120 | ×2 Anam en fin de run |

#### Niamh
| Tier | Nom | Cout | Effet |
|------|-----|------|-------|
| 1 | Douceur de Niamh | 20 | +5 PV par reussite critique |
| 2 | Charme Diplomatique | 25 | +10% gains rep faction |
| 3 | Voile d'Oubli | 50 | -50% pertes reputation |
| 4 | Quatrieme Voie | 80 | +1 option carte (3→4 choix) |
| 5 | Source Eternelle | 120 | +2 PV toutes les 5 cartes (regen passive) |

#### Ankou
| Tier | Nom | Cout | Effet |
|------|-----|------|-------|
| 1 | Marche avec l'Ombre | 20 | Annule drain vie |
| 2 | Regard Sombre | 25 | +15% score minigames esprit |
| 3 | Pacte Sanglant | 50 | Sacrifie 10 PV → +20 Anam (1×/run) |
| 4 | Prescience Funebre | 80 | Voit theme ET effets prochaine carte |
| 5 | Recolte Sombre | 120 | +50% Anam si PV ≤25 en fin de run |

### Branche Centrale (4 base + 7 speciaux = 11 noeuds)

#### Base
| Tier | Nom | Cout | Prerequis | Effet |
|------|-----|------|-----------|-------|
| 1 | Coeur Fortifie | 20 | — | +10 PV max (100→110) |
| 2 | Flux Accelere | 25 | central_1 | -1 cooldown global |
| 3 | Oeil de Merlin | 50 | central_2 | Affiche karma+tension dans HUD |
| 4 | Maitrise Universelle | 80 | central_3 | +10% score minigames global |

#### Speciaux (cross-faction)
| Nom | Cout | Prerequis | Effet |
|-----|------|-----------|-------|
| Calendrier des Brumes | 30 | central_1 | Revele 7 prochains evenements |
| Harmonie Factions | 60 | druides_1+anciens_1+korrigans_1 | +5 Anam/run si toutes factions ≥50 |
| Pacte Ombre-Lumiere | 60 | niamh_1+ankou_1 | Inverse heal/damage 1×/run |
| Eveil Ogham | 35 | druides_1 | Equipe 2 Oghams (1→2) |
| Instinct Sauvage | 35 | korrigans_1+anciens_1 | 1 retry minigame gratuit/run |
| Boucle Eternelle | 150 | central_4+harmonie | NG+: ×1.5 Anam/run |

### UI Arbre de Vie
- **Affichage**: Pixel art arbre + panel detail
- **Mode compact**: Sous 560px viewport
- **Interaction**: Clic noeud → detail (nom, branche, tier, description, lore, cout, prerequis, statut)
- **Couleurs branches**: Druides=vert, Anciens=pierre, Korrigans=violet, Niamh=bleu, Ankou=sombre, Central=amber

---

## ANNEXE: MERLIN PERSONA — CONFIG COMPLETE

### Regles Voix
- **Francais ASCII uniquement**, phrases courtes (max 120 chars)
- **Ton**: Mysterieux, bienveillant, taquin, philosophique
- **Appellations**: "Voyageur", "Ami", "Cher ami", "Mon bon voyageur", "Petit etre curieux"
- **Auto-references**: "Un vieux druide aux secrets rapioces", "Ton guide a travers la brume"

### 28 mots celtiques encourages
brume, pierre, ogham, druides, echos, source, cercle, vent, etoiles, seuil, lueur, ancien, rune, souffle, nemeton, sidhe, dolmen, korrigans, mousse, grimoire, clairiere, menhir, torche, givre, lierre, epine, lame, incantation

### 19 mots interdits
simulation, programme, ia, intelligence artificielle, modele de langage, llm, serveur, algorithme, token, api, machine learning, neural, dataset, artificial, language model, computer, software

### Templates de bugs intentionnels (authenticite)
- **Repetition**: "Le vent... le vent guide tes pas."
- **Technique**: "Erreur rune, pardon, erreur rune."
- **Freeze**: "..."
- **Memoire**: "Je me rappelle... non, je m'egare."
- **Meta (lapsus safe)**: "Mes circuits... mes os, je voulais dire."

### Exemples few-shot (8)
1. "Bonjour Merlin" → "Ah, Voyageur, la brume te salue."
2. "Ou aller ?" → "Va vers la pierre aux trois marques."
3. "Explique la magie" → "Bien sur, mon ami, les voici:\n1) Observe.\n2) Invoque.\n3) Respecte."
4. "Je suis perdu" → "Suis la mousse, elle ne ment pas."
5. "Qui es-tu ?" → "Merlin, ou ce qu'il en reste."
6. "Je veux combattre" → "Garde ta garde haute et ton coeur calme."
7. "Donne un indice" → "Le cercle de pierres n'est pas un cercle."
8. "Je suis blesse" → "Respire, Voyageur, et recule d'un pas."

---

## ANNEXE: DIALOGUES SCENES — EXTRAITS CLES

### Scene Eveil (1ere rencontre, 30-45s)

**eveil_01** (3s delai, emotion: soulagement_profond):
> "... Tu es la."

**eveil_02** (0.5s delai, emotion: vulnerabilite_rare):
> "J'ai attendu. Longtemps. Si longtemps que j'ai oublie si c'etait du temps ou autre chose."

**eveil_03** (0.5s delai, transition vers humour):
> "La brume t'a laisse passer. C'est bon signe. Enfin... elle laisse passer tout le monde, a vrai dire. Meme les gens sans aucun sens de l'orientation."

**eveil_04** (0.5s delai, accueil jovial):
> "Bon. Bienvenue a Broceliande. Derniere foret debout, premier arret avant le bout du monde. Ne fais pas cette tete. C'est plus joli que ca en a l'air. Quand il fait jour."

### Mission Briefing

**mission_01**: "Le monde. Parlons-en. Sept terres. Sept sanctuaires. Chacun tient debout par miracle, par habitude, ou par pur entetement breton."

**mission_03**: "Ton travail? Traverser. Observer. Choisir. Pas sauver le monde. Ca, c'est au-dessus de ton echelon salarial."

**mission_04**: "Mais tes choix comptent. Chaque geste, chaque pas, chaque hesitation. Le monde regarde. Et moi aussi."

### Suggestions par classe

| Archetype | Biome suggere | Extrait |
|-----------|--------------|---------|
| Druide | Cercles de Pierres | "Les menhirs vibrent encore, mais ils ont oublie la moitie des chansons." |
| Guerrier | Villages Celtes | "Les murs tiennent encore, les portes un peu moins." |
| Barde | Cotes Sauvages | "La mer se retire, les marins oublient, et personne ne chante plus au port." |
| Eclaireur | Foret Broceliande | "Des chemins qui bougent, des ombres qui ecoutent, et des secrets partout." |

### Transitions biome — Narration arrivee

**Broceliande**: "La brume se dechire comme un rideau de soie. Des arbres. Des arbres partout. Si vieux que leurs racines semblent avoir pousse avant le sol."
**Landes**: "Le monde s'ouvre d'un coup. Plus d'arbres, plus de murs. Rien que le ciel et la bruyere, mauves et gris."
**Cotes**: "Le sel, d'abord. Puis le bruit — les vagues qui s'ecrasent sur le granite noir."

### Metadonnees dialogue

Chaque ligne porte: `timing` (delai, duree affichage, pause), `emotion` (tag LLM), `direction` (note mise en scene), `tags` (indexation narrative). Total: 100+ entrees.

---

## ANNEXE: FASTROUTE — POOL DE CARTES PRE-GENEREES

### Composition
- **15 cartes narratives** (biome-specifiques + generiques)
- **4 cartes merlin_direct** (gatees par trust tier)
- **Total**: 19 cartes (fallback LLM)

### Exemples narratifs

| ID | Biome | Situation | Options resume |
|----|-------|-----------|---------------|
| fr_broceliande_001 | Broceliande | "Un sentier se divise en trois" | Observer/Ecouter/Avancer |
| fr_broceliande_002 | Broceliande | "Une biche argentee te fixe" | Approcher/Suivre/Rester |
| fr_landes_001 | Landes | "Le vent siffle, cairn au loin" | Examiner/Cacher/Resister |
| fr_cotes_001 | Cotes | "Les vagues, une grotte s'ouvre" | Explorer/Escalader/Longer |
| fr_marais_001 | Marais | "Bulles, rire lointain" | Negocier/Contourner/Plonger |
| fr_iles_001 | Iles | "Brumes, coquillages en motif" | Decoder/Ramasser/Marcher |

### Cartes Merlin Direct

| ID | Trust min | Situation |
|----|-----------|-----------|
| md_conseil_001 | T0 | "Le chemin n'est pas le seul" |
| md_secret_001 | T1 | "J'ai vu quelque chose dans les etoiles" |
| md_warning_001 | T0 | "'Attention!' Merlin surgit" |
| md_gift_001 | T2 | "Merlin tend la main, lumiere doree pulse" |

---

## ANNEXE: 18 SHADERS — CATALOGUE COMPLET

| Shader | Type | Uniforms cles | Effet |
|--------|------|--------------|-------|
| `crt_terminal` | Canvas | curvature, scanline_opacity, phosphor_tint, dither | CRT unifie 4-stage post-process |
| `crt_static` | Canvas | intensity, noise_speed, grain, flicker, vignette | Neige/statique TV |
| `screen_distortion` | Canvas | 18 uniforms sublimaux (chromatic, glitch, barrel...) | Distorsions mobiles subtiles |
| `screen_dither` | Canvas | color_levels, dither_strength, warm_tint | Bayer 4×4 post-process |
| `color_dither` | Canvas | color_levels, dither_strength, pixel_scale | Dithering GBC par sprite |
| `pixelate` | Canvas | pixel_size, color_levels, outline, saturation | Pixelisation + posterisation |
| `ps1_material` | Spatial | vertex_snap, uv_snap | Warping PS1 (3D) |
| `merlin_paper` | Canvas | paper_tint, grain, vignette, warp | Texture parchemin |
| `card_silhouette` | Canvas | silhouette_color, height_base, roughness, density | Terrain procedural carte |
| `card_sky` | Canvas | top/mid/bottom_color, fog, cloud, rain | Gradient ciel + meteo |
| `palette_swap` | Canvas | palette texture, target_row, blend, tolerance | Remapping couleur biome |
| `iridescent_border` | Canvas | speed, intensity, border_width | Bordure arc-en-ciel |
| `screen_vfx` | Canvas | vignette, flash, desaturation, hue_shift, glitch | Compositeur multi-effets |
| `grass_wind_sway` | Spatial | wind_strength, speed, direction, turbulence | Animation herbe 3D |
| `seasonal_particles` | Canvas | season_type(0-3), density, speed | Neige/feuilles/petales |
| `seasonal_snow` | Canvas | speed, density | Flocons proceduraux |
| `bestiole_squish` | Canvas | press_uv, press_strength, press_radius | Deformation tactile |
| `retro_screen` | Canvas | render_size, curvature, grid, color_levels=3 | Arcade monitor extreme |

---

## ANNEXE: SYSTEME AUDIO PROCEDURAL — 45+ SONS

### Generateurs de formes d'onde
- `_sq(freq, t)` — Carre doux (clamped sin×8)
- `_tri(freq, t)` — Triangle (asin-based)
- `_pulse(freq, t, duty)` — Pulse duty-cycle configurable

### Catalogue par categorie

#### UI (vol 0.25)
| Son | Duree | Frequence | Type |
|-----|-------|-----------|------|
| hover | 38ms | 784Hz (G5) carre + 392Hz sub | Square |
| click | 60ms | 1200Hz pulse + 600Hz sub + noise | Pulse |
| slider_tick | 20ms | 3500Hz | Sine pure |
| button_appear | 120ms | 1800→3800Hz sweep | Chime |

#### Transition (vol 0.22)
| Son | Duree | Description |
|-----|-------|-------------|
| whoosh | 300ms | Noise filtre 200±100Hz + sine |
| card_draw | 180ms | Papier: noise + 400Hz tone |
| card_swipe | 220ms | Sweep 600→200Hz + noise |
| scene_transition | 500ms | D3→A3 quinte celtique (147→220Hz) |

#### Impact (vol 0.30)
| Son | Duree | Description |
|-----|-------|-------------|
| block_land | 100ms | Thud Tetris: 180Hz + 360Hz + noise |
| pixel_land | 25ms | Micro-tick: 4000Hz sine |
| pixel_cascade | 80ms | Pluie: 3000±1500Hz + noise |
| pixel_scatter | 120ms | Sweep ascendant 1200→4200Hz |
| accum_explode | 200ms | Explosion: 150Hz + 80Hz + noise |

#### Magic (vol 0.20)
| Son | Duree | Description |
|-----|-------|-------------|
| ogham_chime | 550ms | Harpe: E4/B4/E5 (330/494/659Hz) |
| ogham_unlock | 700ms | Arpege D Dorien: D4/F4/A4/D5 |
| bestiole_shimmer | 800ms | A pentatonique: A4/E5/A5 |
| eye_open | 2000ms | Reveil: D1→D2 octave + drone |
| flash_boom | 450ms | Impact aveuglant: noise + 200Hz + shimmer |
| magic_reveal | 700ms | D pentatonique step sweep |
| skill_activate | 250ms | Zap celtique: D5→G4 descent |

#### Ambient (vol 0.15)
| Son | Duree | Description |
|-----|-------|-------------|
| path_scratch | 60ms | Encre parchemin: 5000Hz + mod |
| landmark_pop | 80ms | Pop: 1800Hz + 900Hz |
| mist_breath | 1000ms | Brume: 80Hz + noise, envelope sine |
| aspect_shift/up/down | 150-180ms | Tonal shifts (glides) |

#### Boot CeltOS
| Son | Duree | Description |
|-----|-------|-------------|
| boot_line | 15ms | Blip terminal: 2200Hz sine |
| boot_confirm | 200ms | Double-beep: 880Hz + 1100Hz |
| convergence | 800ms | Whoosh tension: 100→500Hz sweep |
| slit_glow | 1200ms | Hum: 220/330/440Hz accord 3 notes |

### Pool: 6 AudioStreamPlayer simultanees, round-robin, 44100Hz 16-bit stereo

---

## ANNEXE: SCREENFRAME — BORDURE CELTIQUE + CRISTAL LLM

### Bordure (Layer 99, persistant)
- **Largeur**: 12px | **Couleur**: bg_deep
- **Accent interieur**: 1px, teinte par biome (25% lerp)
- **4 coins**: 24×24px, noeuds celtiques proceduraux (arcs amber_dim + cyan_dim + points accent)

### Cristal LLM (bas-gauche, dans la bordure)

| Etat | Couleur | Animation |
|------|---------|-----------|
| DISCONNECTED | Gris inactive | Aucune |
| WARMUP | amber_dim→amber | Remplissage bas→haut (% progression) |
| READY | Cyan | Pulse sin 2.0s + glow 15%+10% |
| GENERATING | Amber | Pulse 4× plus rapide + glow 20%+15% |
| ERROR | Rouge danger | Blink 0.3s on/off |

- **Forme**: Diamant 4 points (haut/droite/bas/gauche)
- **Highlight**: Blanc 15% alpha interieur
- **Tooltip**: Texte statut temps reel (signaux MerlinAI)

---

## ANNEXE: SCENE 3D — BROCELIANDE FOREST

### Architecture
```
World3D
├── WorldEnvironment (ciel + eclairage)
├── SunLight (DirectionalLight3D)
├── ForestRoot (terrain, arbres GLB, collectibles, portails)
├── Merlin (grille pixel 12×12, OmniLight cyan, rotation+bob)
└── Player (CharacterBody3D FPS)
    ├── Camera3D (sensibilite: 0.0026, bob: 0.04 amp, 8.0 rad/s)
    └── HUD (zone, objectif, crosshair, resultats)
```

### Parametres
| Parametre | Valeur |
|-----------|--------|
| Resolution pixel | 320 (vertical retro) |
| Vitesse deplacement | 3.5 |
| Distance interaction | 2.8 unites |
| Gravite | 9.8 m/s² |

### 10 sous-systemes integres
BrocAutowalk, BrocDayNight, BrocSeason, BrocGrassWind, BrocAtmosphere, BrocEvents, BrocEventVfx, BrocScreenVfx, BrocCreatureSpawner, BrocNarrativeDirector, BrocChunkManager

### 7 zones forestieres
Exploration → Foret dense → Sites mystiques → Habitat creatures → Transition → Zone cachee → Rencontre Merlin

---

## ANNEXE: MAP GENERATION — ALGORITHME

### Types de noeuds (poids selection)
| Type | Poids | Cartes | But |
|------|-------|--------|-----|
| NARRATIVE | 5.0 | 2-4 | Choix narratifs |
| EVENT | 2.0 | 1-2 | Evenements aleatoires |
| PROMISE | 1.0 | 1-3 | Promesses faction |
| REST | 1.5 | 0 | Soin +18 PV |
| MERCHANT | 1.0 | 0 | Achats Anam |
| MYSTERY | 1.0 | 1-2 | Rencontres inconnues |
| MERLIN | 0.0 | 1 | Noeud final force |

### Regles de generation
1. **Etage 0**: Toujours 1 noeud NARRATIVE
2. **Dernier etage**: Toujours 1 noeud MERLIN
3. **Milieu** (etage/2): Force REST ou MERCHANT (50/50)
4. **Autres**: 2-3 noeuds, type random pondere
5. **Min 3 etages**, typiquement 8-10
6. **Revelation**: 2 premiers etages visibles, reste brouillard

### Connexions
- Chaque noeud courant a ≥1 parent
- Chaque noeud precedent a ≥1 enfant (max 3)
- 45% chance connexion supplementaire
- DAG garanti (pas de boucles, pas de culs-de-sac)

---

## ANNEXE: SYSTEME METEO

### Periodes (cycle journalier)
| Periode | Heures | Bonus faction |
|---------|--------|---------------|
| Aube | 5-8 | Druides +10% |
| Jour | 8-18 | — |
| Crepuscule | 18-21 | Korrigans +10% |
| Nuit | 21-5 | Ankou +15% |

### Saisons (cycle annuel)
| Saison | Mois | Bonus faction |
|--------|------|---------------|
| Hiver | 12,1,2 | Niamh +20% |
| Printemps | 3,4,5 | Druides +20% |
| Ete | 6,7,8 | Anciens +20% |
| Automne | 9,10,11 | Ankou +30% |

### Types meteo
CLEAR, CLOUDY, RAIN, STORM, MIST, SNOW — overlay visuel via shaders (card_sky fog/cloud/rain uniforms)

### Festivals (Roue de l'Annee)
Imbolc (Fev), Beltane (Mai), Lughnasadh (Aout), Samhain (Oct)

---

## ANNEXE: MUSIQUE

### Pistes
| Cle | Morceaux (intro + loop) | Contexte |
|-----|------------------------|---------|
| `intro` | Tri Martolod (Remastered) | Menu, boot |
| `foret_broceliande` | Chas Donz Part 1 (Cover) | Biome Broceliande |

### Parametres
- **Volume defaut**: -6.0 dB
- **Fade-in**: 1.5s
- **Crossfade**: 2.0s (parallele fade-out + switch)
- **Loop**: WAV loop_mode = LOOP_FORWARD, loop_begin = 0

---

## 37. QUIZ DE PERSONNALITE — 10 QUESTIONS, 4 AXES, 8 ARCHETYPES

### 4 Axes de personnalite

| Axe | Pole negatif | Neutre | Pole positif |
|-----|-------------|--------|-------------|
| `approche` | prudent (-) | adaptable | audacieux (+) |
| `relation` | solitaire (-) | equilibre | social (+) |
| `esprit` | analytique (-) | polyvalent | intuitif (+) |
| `coeur` | pragmatique (-) | nuance | compassionnel (+) |

Seuils: < -0.3 = negatif, > 0.3 = positif, entre = neutre. Score normalise: `score / 10.0`, clampe [-1.0, 1.0].

### 10 Questions completes

**Q1** — "Tu te reveilles dans une foret inconnue..."
| Choix | Texte | Effets |
|-------|-------|--------|
| A | "J'observe les environs en silence" | approche: -2, esprit: -1 |
| B | "J'appelle pour voir si quelqu'un repond" | relation: +2, approche: +1 |
| C | "Je cherche un point haut pour voir plus loin" | approche: +1, esprit: -1 |
| D | "Je reste immobile et j'ecoute" | approche: -1, esprit: +1 |

**Q2** — "Une voix murmure ton nom depuis les arbres..."
| Choix | Texte | Effets |
|-------|-------|--------|
| A | "Je m'approche prudemment" | approche: -1, relation: +1 |
| B | "Je demande qui est la" | approche: +1, relation: +1 |
| C | "Je m'eloigne sans bruit" | approche: -1, relation: -2 |
| D | "Je tends l'oreille pour en savoir plus" | esprit: +1 |

**Q3** — "Tu trouves un objet brillant au sol..."
| Choix | Texte | Effets |
|-------|-------|--------|
| A | "Je le ramasse immediatement" | approche: +2, esprit: +1 |
| B | "Je l'examine sans le toucher" | approche: -1, esprit: -2 |
| C | "Je le laisse et continue mon chemin" | coeur: -1 |
| D | "Je ressens son energie avant de decider" | esprit: +2, coeur: +1 |

**Q4** — "Un animal blesse te regarde..."
| Choix | Texte | Effets |
|-------|-------|--------|
| A | "J'essaie de le soigner" | coeur: +2, relation: +1 |
| B | "Je lui parle doucement pour le rassurer" | coeur: +1, esprit: +1 |
| C | "Je passe mon chemin, la nature suit son cours" | coeur: -2, approche: +1 |
| D | "J'evalue s'il peut m'etre utile" | coeur: -1, esprit: -1 |

**Q5** — "La brume s'ecarte et revele un chemin. A gauche, des lumieres..."
| Choix | Texte | Effets |
|-------|-------|--------|
| A | "Je vais vers les lumieres" | relation: +2, approche: +1 |
| B | "Je choisis le silence" | relation: -2, esprit: +1 |
| C | "J'attends de voir si quelque chose change" | approche: -1, esprit: -1 |
| D | "Je crie pour signaler ma presence" | relation: +1, approche: +2 |

**Q6** — "Tu decouvres un campement abandonne..."
| Choix | Texte | Effets |
|-------|-------|--------|
| A | "Je fouille les restes a la recherche d'indices" | esprit: -1, approche: +1 |
| B | "Je pars immediatement, c'est trop dangereux" | approche: -2, coeur: -1 |
| C | "Je cherche des survivants aux alentours" | coeur: +2, approche: +1 |
| D | "Je m'installe et attends le retour des occupants" | relation: +1, approche: -1 |

**Q7** — "Un enigme est gravee sur une pierre ancienne..."
| Choix | Texte | Effets |
|-------|-------|--------|
| A | "J'analyse chaque symbole methodiquement" | esprit: -2, approche: -1 |
| B | "Je fais confiance a mon premier instinct" | esprit: +2, approche: +1 |
| C | "Je contourne la pierre et ignore l'enigme" | coeur: -1 |
| D | "Je cherche quelqu'un pour m'aider" | relation: +2 |

**Q8** — "Un voyageur te demande de l'aide. Mais quelque chose..."
| Choix | Texte | Effets |
|-------|-------|--------|
| A | "Je l'aide malgre mes doutes" | coeur: +2, approche: +1 |
| B | "Je refuse poliment et m'eloigne" | coeur: -1, approche: -1 |
| C | "Je l'interroge avant de decider" | esprit: -1, relation: +1 |
| D | "Je fais confiance a mon malaise" | esprit: +2 |

**Q9** — "Un cri dechire la nuit..."
| Choix | Texte | Effets |
|-------|-------|--------|
| A | "Je cours vers le cri sans hesiter" | approche: +2, coeur: +2 |
| B | "Je reste sur mon chemin, j'ai une mission" | coeur: -2, esprit: -1 |
| C | "J'avance prudemment vers le son" | approche: -1, coeur: +1 |
| D | "Je cherche un point d'observation" | esprit: -1, approche: -1 |

**Q10** — "Devant un lac immobile, tu vois ton reflet..."
| Choix | Texte | Effets |
|-------|-------|--------|
| A | "Celui qui protege les autres" | coeur: +2, relation: +1 |
| B | "Celui qui cherche la verite" | esprit: -1, approche: +1 |
| C | "Celui qui suit son instinct" | esprit: +2, approche: +1 |
| D | "Celui qui avance seul dans l'ombre" | relation: -2, approche: -1 |

### 8 Archetypes

| Archetype | Pattern (axe: valeur) | Titre | Description |
|-----------|----------------------|-------|-------------|
| gardien | approche: -1, coeur: +1 | Le Gardien | Tu proteges ceux qui ne peuvent se defendre. Ta prudence cache un coeur immense. |
| explorateur | approche: +1, esprit: +1 | L'Explorateur | Le monde t'appelle et tu reponds. Ton instinct te guide vers l'inconnu. |
| sage | relation: -1, esprit: -1 | Le Sage | Tu observes, tu analyses, tu comprends. La solitude nourrit ta reflexion. |
| heros | approche: +1, relation: +1 | Le Heros | Tu avances sans peur vers le danger. Les autres trouvent force a tes cotes. |
| guerisseur | coeur: +1, relation: +1 | Le Guerisseur | Tu ressens la douleur des autres. Ta presence apaise les ames troublees. |
| stratege | esprit: -1, approche: -1 | Le Stratege | Chaque action est calculee. Tu vois dix coups a l'avance. |
| mystique | esprit: +1, relation: -1 | Le Mystique | Tu percois ce que d'autres ignorent. Les brumes te murmurent leurs secrets. |
| guide | coeur: +1, esprit: +1 | Le Guide | Ton intuition eclaire le chemin. Tu menes par l'exemple et la bienveillance. |

### Algorithme de matching
```
1. Normaliser scores: score / 10.0, clampe [-1.0, 1.0]
2. Labelliser: < -0.3 = negatif, > 0.3 = positif, else neutre
3. Pour chaque archetype: match_score = sum(axis_positions[axis] * pattern[axis])
4. Selectionner le meilleur match_score (defaut: "explorateur")
5. Extraire dominant_traits (labels non-neutres uniquement)
```

### Resultat retourne (dictionnaire)
```
archetype_id, archetype_title, archetype_desc,
axis_scores (brut), axis_positions (normalise),
axis_labels (label par axe), dominant_traits (liste)
```

### Mapping archetype → biome suggere
| Archetype | Biome | Nom | Accroche |
|-----------|-------|-----|----------|
| druide | cercles_pierres | Cercles de Pierres | "Ou le temps hesite" |
| guerrier | villages_celtes | Villages Celtes | "Flammes obstinees" |
| barde | cotes_sauvages | Cotes Sauvages | "L'ocean murmurant" |
| eclaireur | foret_broceliande | Foret de Broceliande | (defaut/home) |

---

## 38. HUB ANTRE — SANCTUAIRE COMPLET

### 5 Hotspots interactifs (icones 16x16 procedurales)

| Nom | Icone | Label | Couleur | Position (ratio) | Destination |
|-----|-------|-------|---------|-------------------|-------------|
| calendar | MOON (croissant) | Calendrier | amber_bright | (0.04, 0.06) | SCENE_CALENDAR |
| options | GEAR (engrenage 6 dents) | Options | phosphor_dim | (0.88, 0.06) | SCENE_OPTIONS |
| arbre | TREE (tronc + couronne) | Arbre de Vie | phosphor_dim | (0.22, 0.38) | SCENE_ARBRE |
| alignement | COMPASS (croix + fleche nord) | Alignement | amber_dim | (0.46, 0.38) | FUTUR (desactive) |
| collection | BOOK (livre ouvert) | Collection | amber_dim | (0.70, 0.38) | SCENE_COLLECTION |

### Bouton PARTIR
- **Largeur**: 80% viewport, bas de l'ecran
- **Style**: fond amber, bordure amber_bright 2px, coins droits (CRT)
- **Hover**: scale 1.08, shadow +4px
- **Press**: scale 0.92, shadow -4px
- **Action**: Ouvre le BiomeRadial (menu radial 8 biomes)

### Particules ambiantes (procedurales)
- Spawn: 8%/frame, max 30 particules
- Couleurs: phosphor_glow, cyan_dim, amber_dim
- Mouvement: oscillation sinusoidale (0.5-2.0 Hz) + montee (12-30 px/s)
- Duree de vie: 4-10s, fondu en sortie

### Dialogues contextuels de Merlin (MerlinBubble)

| Contexte | Exemples |
|----------|----------|
| first_hub | "Bienvenue, %s. Le feu t'attendait." / "Entre, %s. Le feu ronronne." |
| return | "Te revoila, %s !" / "De retour, %s." / "Ah, %s. Toujours debout." |
| after_fall | "Chaque chute enseigne, %s." / "Encore toi, %s ? Bien." / "On se releve, %s." |
| veteran | "Tu connais le chemin, %s." / "%s. Qui guide qui ?" / "Les pierres te reconnaissent, %s." |

### Visite guidee (1ere visite — 7 etapes)
1. "Bienvenue dans l'Antre. Ton refuge entre les runs."
2. Highlight Calendrier → "Le Calendrier. Saisons et fetes celtiques."
3. Highlight Arbre → "L'Arbre de Vie. Ta progression, run apres run."
4. Highlight Collection → "La Collection. Cartes, Oghams, lore — tout ici."
5. Highlight Alignement → "L'Alignement des biomes. Bientot disponible."
6. Highlight PARTIR → "PARTIR. Choisis un biome et lance l'aventure."
7. "Tu connais l'essentiel. Le reste se decouvre en marchant."

### Mise en scene Hub
- **Background**: CRT terminal (bg_dark palette)
- **Couche brume**: Animation pulsante alpha (0.05 → 0.25 → 0.05, boucle 8s)
- **Header**: Nom joueur (amber, title font, 52px)
- **Meta**: Classe + Total runs (phosphor_dim, caption, centre)

---

## 39. MENUS ET SCENES UI — CATALOGUE EXHAUSTIF

### 39.1 Menu Principal (MenuPrincipalMerlin.gd — 25 395 lignes)

**Structure scene**:
```
MenuPrincipal (Control)
├── ParchmentBg (ColorRect)
├── MistLayer (ColorRect) — animation brume
├── CelticOrnamentTop/Bottom (Label) — ornements decoratifs
├── Card (PanelContainer) — carte centrale
│   └── CardContents (VBoxContainer)
│       ├── Title (Label) — "M  E  R  L  I  N"
│       ├── SeparatorContainer — separateur visuel (diamant)
│       └── MainButtons (VBoxContainer) — boutons dynamiques
├── CalendarButton (Button, 52x52) — coin calendrier
├── CollectionsButton (Button, 52x52) — coin collections
└── ClockLabel (Label) — horloge
```

**3 boutons de menu**:
| Priorite | Texte | Destination |
|----------|-------|-------------|
| Primary | Nouveau Jeu | IntroPersonalityQuiz.tscn |
| Secondary | Continuer | SelectionSauvegarde.tscn |
| Tertiary | Options | MenuOptions.tscn |

**Effets visuels**: particules saisonnieres (neige/feuilles/fleurs), eclairage jour/nuit, 12 lucioles ambiantes, matrice pixel fond, animation brume sinusoidale, calibration voix (panneau cache), indicateur LLM warmup.

### 39.2 Menu Options (MenuOptions.gd)

**Categories de reglages**:

#### Video
| Reglage | Type | Valeurs |
|---------|------|---------|
| Resolution | Selector | 1920x1080, 1600x900, 1440x810, 1280x720, 1152x648 |
| Mode affichage | Selector | Plein ecran / Fenetre / Sans bordure |
| VSync | Toggle | On/Off |
| FPS limite | Selector | 30 / 60 / 120 / Illimite |

#### Audio
| Reglage | Type | Range |
|---------|------|-------|
| Volume Master | Slider | 0-100% |
| Volume Musique | Slider | 0-100% |
| Volume SFX | Slider | 0-100% |

#### Calendrier
| Reglage | Type | Details |
|---------|------|---------|
| Override date | Toggle | Active/desactive la date personnalisee |
| Jour/Mois/Annee | Spinners | 1-31, 1-12, 2020-2100 |

#### Langue
| Reglage | Type | Valeurs |
|---------|------|---------|
| Langue | Selector | fr, en, es, it, pt, zh, ja |

#### Voix
| Reglage | Type | Valeurs |
|---------|------|---------|
| Mode voix | Selector | Spoken / Robot / Disabled |
| Banque voix | Selector | 9 banques (default, high, low, lowest, med, robot, glitch, whisper, droid) |
| Preset voix | Selector | 12 presets (Merlin, Soft, Quill, Crystal, Ancient, Normal, High, Low, Child, Wise, Joyful, Mysterious) |

#### IA
| Reglage | Type | Valeurs |
|---------|------|---------|
| Nombre cerveaux | Selector | Auto / Dual / Triple |

**Boutons**: Reinitialiser (reset defauts) / Retour (sauvegarder + quitter)
**Config**: Sauvegarde dans `user://settings.cfg`

### 39.3 Selection Sauvegarde (SelectionSauvegarde.gd)

**Structure**:
```
SelectionSauvegarde (Control)
├── Background (ColorRect)
└── RootPanel (PanelContainer) — modal centree
    └── RootVBox
        ├── Title — "Chroniques"
        ├── Hint — "Choisis une chronique a reprendre"
        ├── Slots (VBoxContainer) — boutons dynamiques
        └── BackButton
```

**Contenu par slot**: Anam total, nombre de runs, talents debloques, fins vues.
**Boutons**: Continuer (charger profil), Reinitialiser (dialog confirmation), Nouveau jeu.
**Auto-continue**: Si profil existant, charge et va directement au jeu.

### 39.4 Collection (Collection.gd)

**3 onglets**:

| Onglet | Contenu |
|--------|---------|
| Progression | 6 lignes stats avec barres: Fins (0/16), Oghams (0/18), Talents (0/28), Runs, Cartes, Essences |
| Recents | 5 dernieres realisations (icone + titre + description + date) |
| Collection | Grille icones (28-36px) objets decouverts + liste detaillee. Items secrets = "?" |

**Systeme de rang**: Novice → ... → Archidruide (base sur les points de gloire)
**Passe de Gloire**: Barre de progression "Palier X - Y/100"
**Design**: Responsive (compact sous mobile), brume animee, style CRT terminal

### 39.5 Ecran fin de run (end_run_screen.gd — 4 ecrans)

| Ecran | Contenu |
|-------|---------|
| 1. Fin narrative | Texte LLM ou fallback (selon raison: "death", "hard_max", defaut) |
| 2. Carte du voyage | Timeline des cartes jouees (card_id, option, score, effets), biome, total |
| 3. Bilan recompenses | Anam gagne, deltas reputation faction, delta trust, monnaie biome, cartes jouees, minigames gagnes, promesses tenues/brisees |
| 4. Choix faction (optionnel) | Declenche si 2+ factions >= 80 rep. Joueur choisit une faction |

**Signaux**: `screen_completed(screen_name)`, `return_to_hub()`, `faction_chosen(faction)`

### 39.6 Rencontre Merlin (SceneRencontreMerlin.gd — 3 phases)

**Phase 1 — Accueil**: Greeting LLM + archetype reveal
- RAG prompt: "Tu es Merlin le druide. Un voyageur (%s) arrive a Broceliande. 2 phrases max: accueille-le."
- Fallback: "Bienvenue a Broceliande, voyageur. Oghams, factions et aventure t'attendent."
- 3 options de reponse (LLM ou fallback)

**Phase 2 — Oghams de depart**: Presentation animee pixel art
- **Beith** (B) — Bouleau — "Nouveau depart" → "Revele les effets d'un choix"
- **Luis** (L) — Sorbier — "Protection" → "Annule un changement negatif"
- **Quert** (Q) — Pommier — "Guerison" → "Ramene vers l'equilibre"
- Affichage: Icone 36px + symbole 32pt + nom 16pt + sens 11pt + gameplay 10pt

**Phase 3 — Briefing mission**: Choix destination
- "Veux-tu explorer l'Antre avant de partir... ou t'elancer directement dans l'aventure ?"
- [1] Explorer le Refuge → Tutorial (1ere fois) ou Hub
- [2] Commencer l'Aventure → TransitionBiome.tscn

### 39.7 LLM Warmup Overlay (llm_warmup_overlay.gd)
- CanvasLayer layer=100 (au-dessus de tout)
- Spinner anime: ⟳ ▹ ◸ ► ◹ ◷ ◶
- Barre de progression + texte statut
- Bloque l'UI pendant le warmup

### 39.8 Inventaire complet des scenes

```
scenes/
├── ArbreDeVie.tscn          — Arbre de talents (Anam)
├── BootstrapMerlinGame.tscn — Bootstrap jeu
├── BroceliandeForest3D.tscn — Scene 3D Broceliande
├── Calendar.tscn            — Calendrier celtique
├── Collection.tscn          — Collection objets/stats
├── HubAntre.tscn            — Hub sanctuaire
├── IntroCeltOS.tscn         — Boot CRT (6-10s)
├── IntroPersonalityQuiz.tscn — Quiz personnalite
├── IntroTutorial.tscn       — Tutoriel premiere visite
├── MapMonde.tscn            — Carte du monde
├── MenuOptions.tscn         — Options
├── MenuPrincipal.tscn       — Menu principal
├── MerlinGame.tscn          — Jeu principal (cartes)
├── PixelArtShowcase.tscn    — Showcase pixel art
├── SceneRencontreMerlin.tscn — 1ere rencontre Merlin
├── ScreenshotRunner.tscn    — Outil screenshots
├── SelectionSauvegarde.tscn — Selection sauvegarde
├── TransitionBiome.tscn     — Transition entre biomes
├── TestAutoPlay.tscn        — Test auto-play
├── TestLLMBenchmarkRun.tscn — Benchmark LLM
├── TestLLMFullRun.tscn      — Test LLM complet
├── TestLLMIntelligence.tscn — Test intelligence LLM
├── ui/
│   ├── LLMWarmupOverlay.tscn — Overlay warmup IA
│   ├── MenuReturnButton.tscn — Bouton retour reutilisable
│   └── MerlinGameUI.tscn     — UI gameplay principale
└── test/
    └── TestCardLayers.tscn   — Test couches cartes
```

### 39.9 MerlinGameUI — Structure UI de gameplay

```
MerlinGameUI (Control)
├── ParchmentBg — fond parchemin
├── BiomeArtLayer — fond specifique biome
├── MainVBox
│   ├── TopStatusBar
│   │   ├── LifePanel (titre + barre 168x12 + compteur "X/100")
│   │   ├── SoufflePanel (titre + 7 icones "o" + compteur)
│   │   └── EssencePanel (titre + compteur + caption)
│   ├── MiddleZone
│   │   ├── PiocheColumn (titre "Pioche" + pile cartes + compteur)
│   │   ├── CardContainer (illustration + texte narratif + portrait)
│   │   └── CimetiereColumn (titre "Cimetiere" + defausse + compteur)
│   └── BottomZone
│       ├── OptionsBar (3 boutons A/B/C + descriptions)
│       └── InfoPanel (mission + cartes jouees)
├── DeckFxLayer — animations deck
├── ClockPanel + Timer — horloge
└── NarratorOverlay — narration intro
```

**Elements dynamiques crees en script**: badge source LLM, PixelSceneCompositor, PixelCharacterPortrait, PixelNpcPortrait, MerlinRewardBadge, badges minigame, titre carte, bouton dialogue, popup dialogue, MerlinBubble.

**Signaux emis**: `option_chosen(option)`, `skill_activated(skill_id)`, `pause_requested`, `souffle_activated`, `merlin_dialogue_requested(input)`, `journal_requested`.

---

## 40. EVENEMENTS CALENDAIRES — 47 EVENEMENTS COMPLETS

### 40.1 Transitions saisonnieres (4 — weight_base: 1.10)

| ID | Date | Nom | Effets |
|----|------|-----|--------|
| TRANS_SPRING | 03-01 | Eveil du Printemps | Healing + Anciens rep |
| TRANS_SUMMER | 06-01 | Soleil de l'Ete | Healing + Niamh rep |
| TRANS_AUTUMN | 09-01 | Souffle d'Automne | Druides rep + Karma |
| TRANS_WINTER | 12-01 | Nuit de l'Hiver | Damage life + Tension |

### 40.2 Sabbats majeurs (8 — weight_base: 1.20-1.30)

| ID | Date | Nom | Effets |
|----|------|-----|--------|
| SABBAT_SAMHAIN | 10-31 | Samhain | Druides +10, Life +5, Karma +10 |
| SABBAT_YULE | 12-21 | Yule | Life +8, Anciens +5, Karma +5 |
| SABBAT_IMBOLC | 02-01 | Imbolc | Life +10, Karma +5 |
| SABBAT_OSTARA | 03-21 | Ostara | Druides +8, Life +5 |
| SABBAT_BELTANE | 05-01 | Beltane | Life +8, Niamh +5, Karma +5 |
| SABBAT_LITHA | 06-21 | Litha | Life +10, Karma +5 |
| SABBAT_LUGHNASADH | 08-01 | Lughnasadh | Life +5, Anciens +5 |
| SABBAT_MABON | 09-21 | Mabon | Niamh +5, Karma +5, Life +5 |

### 40.3 Evenements de consequence (20 — weight_base: 0.65-0.95)

| ID | Date/Cond | Nom | Effets | Flags |
|----|-----------|-----|--------|-------|
| CONS_VEILLEE_MENHIRS | 01-05 | Veillee des Menhirs | Druides +5, Karma +3 | — |
| CONS_BRUME_ANKOU | 01-21 | Brume de l'Ankou | Ankou +5, Tension +15 | — |
| CONS_SERMENT_SOURCES | 02-02 | Serment des Sources | Druides +5 | heard_source_oath |
| CONS_LUEUR_GUI | 02-14 | Lueur du Gui | Life +8, Karma +5 | — |
| CONS_AUBE_BRIGID | 02-01→02-03 | Aube de Brigid | Life +15, Druides +5 | cond: life < 50 |
| CONS_CHASSE_SAUVAGE | 10-15→11-15 | Chasse Sauvage | Life -10, Tension +20 | survived_wild_hunt (non-repeatable) |
| CONS_NUIT_FEES | 06-23 | Nuit des Fees | Korrigans +8, Life +5 | seen_faeries |
| CONS_LUNE_SANG | floating | Lune de Sang | Tension +25, Life -8 | blood_moon_witnessed (non-rep.) cond: full_moon + tension > 40 |
| CONS_APPEL_FORET | floating | Appel de la Foret | Druides +5, Mission +1 | cond: druides rep > 50 |
| CONS_RETOUR_EXILE | floating | Retour de l'Exile | Niamh +10, Karma +10 | exile_returned (non-rep.) cond: niamh < 30 |
| CONS_MARCHE_OMBRE | floating | Marche de l'Ombre | Ankou +5, Tension +10 | shadow_walk. cond: automne/hiver |
| CONS_FORGERON_ERRANT | floating | Forgeron Errant | Life +8, Anciens +5 | non-rep. cond: has_ally |
| CONS_CHANT_SIRENES | floating | Chant des Sirenes | Niamh +8, Life -5 puis +3 | cond: ete + biome cotes |
| CONS_FIEVRE_BRUME | floating | Fievre de Brume | Life -8, Druides +5 | fever_vision (non-rep.) cond: automne/hiver + life < 40 |
| CONS_RASSEMBLEMENT_CLANS | floating | Rassemblement des Clans | Niamh +10, Druides +5, Karma +15 | attended_clan_gathering (non-rep.) cond: niamh > 60 + 15+ cartes |

### 40.4 Evenements secrets (5 — weight_base: 0.15-0.30, CACHES)

| ID | Conditions | Nom | Effets | Flag |
|----|-----------|-----|--------|------|
| SECRET_GRAAL_BRETON | karma > 30, 20+ cartes, hidden | Le Graal Breton | Life +20, Druides +15, Karma +20 | found_graal |
| SECRET_VOIX_ANCETRES | druides > 70, promise_fulfilled, hidden | Voix des Ancetres | Life +15, Anciens +10, Mission +2 | heard_ancestors |
| SECRET_CHAUDRON_DAGDA | life > 70, 15+ cartes, hidden | Chaudron de Dagda | Life +20, Anciens +10 | found_cauldron |
| SECRET_ARBRE_MONDE | druides > 60 ET anciens > 60, 15+ cartes, hidden | L'Arbre-Monde | Life +20, Karma +25 | found_world_tree |
| SECRET_MEMOIRE_MERLIN | trust > 50, 3+ fins vues, 20+ cartes, hidden | Memoire de Merlin | Life +15, Karma +30, Druides +10 | merlin_remembers |

### 40.5 Calendrier 2026 (36 dates specifiques — modifieurs narratifs)

| Date | Nom | Modifieurs cles |
|------|-----|-----------------|
| 01-05 | Veillee des Menhirs | spirit +0.20, relic +0.15 |
| 01-21 | Brume de l'Ankou | spirit +0.35, wisp +0.20 |
| 01-31 | Serment des Glaces | promise_mod +0.25 |
| 02-02 | Serment des Sources | promise_mod +0.20 |
| 02-14 | Lueur du Gui | favor_mod +0.20 |
| 02-26 | Veillee des Saules | spirit +0.20, mystery +0.15 |
| 03-08 | Pas de l'Elan | fauna +0.30 |
| 03-21 | Ouverture des Menhirs | relic +0.20, spirit +0.15, unlock: menhir_paths |
| 03-30 | Eveil des Ruisseaux | resource +0.25, craft +0.15 |
| 04-12 | Pluie des Fees | wisp +0.25, relic +0.15, loot_mod +0.15 |
| 04-23 | Veillee des Ajoncs | korrigan +0.30, trick +0.20 |
| 04-30 | Nuit des Feux Follets | wisp +0.40, spirit +0.20, mystery +0.25 |
| 05-09 | Serment des Jardins | promise_mod +0.20 |
| 05-23 | Procession des Cerfs | fauna +0.30, guardian +0.10 |
| 05-31 | Brume des Dolmens | spirit +0.20, relic +0.20, mystery +0.25 |
| 06-07 | Solstice des Luthiers | craft +0.25, resource +0.20 |
| 06-24 | Ronde du Feu | ritual +0.30, spirit +0.10 |
| 06-29 | Marche des Roches | relic +0.25, resource +0.15 |
| 07-09 | Maree des Korrigans | korrigan +0.35, spirit +0.15 |
| 07-17 | Chant des Sources Chaudes | favor_mod +0.15, resource +0.20 |
| 07-28 | Veillee des Gardiens | guardian +0.25, spirit +0.15 |
| 08-08 | Serment d'Ete | promise_mod +0.30 |
| 08-21 | Coupe des Brumes | mystery_mod +0.30, mystery +0.20, spirit +0.20 |
| 08-31 | Veillee des Ruines | relic +0.30, spirit +0.15, loot_mod +0.15 |
| 09-02 | Moisson des Pierres | resource +0.25, craft +0.20 |
| 09-18 | Voile des Dolmens | mystery_mod +0.25, relic +0.20, spirit +0.20 |
| 09-29 | Rite des Glands | fauna +0.25, resource +0.10 |
| 10-05 | Foire aux Mnesies | mystery_mod +0.20, knowledge_mod +0.20 |
| 10-16 | Marche des Ombres | conflict_mod +0.20, spirit +0.20 |
| 10-27 | Nuit du Corbeau | spirit +0.25, raven +0.30, conflict_inversion: true |
| 11-11 | Silence des Landes | conflict_mod -0.15, mystery_mod +0.20 |
| 11-21 | Veillee du Tisserand | craft +0.20, relic +0.15 |
| 11-26 | Dernier Passage | spirit +0.25, guardian +0.20, loot_mod +0.20 |
| 12-06 | Veillee des Menhirs (Hiver) | spirit +0.20, relic +0.15 |
| 12-21 | Longue Nuit | spirit +0.40, mystery +0.30, mystery_mod +0.35 |
| 12-31 | Serment de l'An Nouveau | promise_mod +0.30, favor_mod +0.20 |

---

## 41. TAXONOMIE D'EVENEMENTS & PITY SYSTEM

### 9 Categories d'evenements (avec poids de base)

| Categorie | base_weight | Sous-types |
|-----------|-------------|------------|
| Rencontre | 0.30 | voyageur, creature, autochtone, revenant, messager |
| Dilemme | 0.20 | sacrifice, loyaute, verite, survie |
| Decouverte | 0.12 | lieu, objet, savoir, passage |
| Conflit | 0.08 | interpersonnel, faction, interieur |
| Merveille | 0.08 | vision, manifestation, don, transformation |
| Epreuve | 0.07 | physique, mentale, rituelle, sociale |
| Catastrophe | 0.05 | naturelle, surnaturelle, humaine |
| Commerce | 0.05 | troc, marche_noir, pacte, offrande |
| Repos | 0.05 | halte, festin, reve_lucide, meditation |

### Matrice de frequence (5 etats)

| Etat | Condition | Bonus categories |
|------|-----------|-----------------|
| debut_run | 0-8 cartes | Decouvertes ×1.70, Repos ×1.50 |
| milieu_run | 9-20 cartes | Dilemmes ×1.20, Epreuves ×1.30 |
| fin_run | 21+ cartes | Catastrophes ×1.0, Epreuves ×1.50 |
| jauges_stables | life > 50 | Decouvertes ×1.35, Merveilles ×1.20 |
| jauges_critiques | life < 30 OU tension > 50 | Merveilles ×2.50, Repos ×1.80 (pity) |

### Systeme de poids a 7 facteurs (EventAdapter)

| Facteur | Description | Range |
|---------|-------------|-------|
| f_skill | Inverse du skill joueur | 0.9 (fort) → 1.2 (faible) |
| f_pity | Mode pity (accumule avec echecs) | 1.0 + (deaths × 0.1), max 1.5 |
| f_crisis | Bonus recuperation si jauges critiques | variable |
| f_conditions | Eligibilite (karma, flags, rep) | 0 ou 1 |
| f_fatigue | Penalite -0.15 par repetition (fenetre 10 events) | decroissant |
| f_season | Bonus match saison | variable |
| f_date_proximity | Bonus proximite date (±7 jours) | jusqu'a ×1.4 |

**Formule finale**: `clamp(base_weight × f_skill × f_pity × f_crisis × f_conditions × f_fatigue × f_season × f_date_proximity, 0.0, 3.0)`

### Anti-repetition
- `min_gap_same_category`: 2 evenements
- `min_gap_same_subtype`: 4 evenements
- Historique glissant: 10 derniers evenements

### Phases lunaires (8 phases)
NEW_MOON, WAXING_CRESCENT, FIRST_QUARTER, WAXING_GIBBOUS, FULL_MOON, WANING_GIBBOUS, LAST_QUARTER, WANING_CRESCENT
- Puissance: 0.0 → 1.0 (pic a FULL_MOON)
- Affecte selection d'evenements (ex: CONS_LUNE_SANG requiert full_moon)

---

## 42. 8 BIOMES — DONNEES COMPLETES (GUARDIENS, MISSIONS, DIALOGUES)

### Donnees par biome

| Biome | Ogham | Gardien | Saison | Difficulte | Couleur |
|-------|-------|---------|--------|------------|---------|
| Foret de Broceliande | duir | Maelgwn | automne | Normal | GBC.forest |
| Landes de Bruyere | onn | Talwen | hiver | Difficile | phosphor_dim |
| Cotes Sauvages | nuin | Bran | ete | Normal | GBC.water |
| Villages Celtes | gort | Azenor | printemps | Facile | GBC.fire |
| Cercles de Pierres | huath | Keridwen | samhain | Difficile | inactive |
| Marais des Korrigans | muin | Gwydion | lughnasadh | Tres difficile | GBC.grass_dark |
| Collines aux Dolmens | ioho | Elouan | yule | Normal | border_bright |
| Iles Mystiques | ailm | Morgane | samhain | Legendaire | (0.25,0.42,0.60) |

### Sous-titres biomes
| Biome | Sous-titre |
|-------|-----------|
| Foret de Broceliande | "Mystere et magie ancestrale" |
| Landes de Bruyere | "Solitude et endurance" |
| Cotes Sauvages | "L'ocean murmurant" |
| Villages Celtes | "Flammes obstinees de l'humanite" |
| Cercles de Pierres | "Ou le temps hesite" |
| Marais des Korrigans | "Deception et feux follets" |
| Collines aux Dolmens | "Les os de la terre" |
| Iles Mystiques | "Au-dela des brumes" |

### Missions par biome (2 par biome)

| Biome | Type | Objectif | Total |
|-------|------|----------|-------|
| Foret Broceliande | discovery | Trouver la Source de Barenton | 8 |
| Foret Broceliande | alliance | Ecouter les murmures des arbres anciens | 6 |
| Landes Bruyere | survival | Traverser les landes sans faillir | 10 |
| Landes Bruyere | recovery | Rallumer le feu de Talwen | 7 |
| Cotes Sauvages | discovery | Dechiffrer les vagues de Bran | 8 |
| Cotes Sauvages | alliance | Calmer les marees errantes | 6 |
| Villages Celtes | alliance | Reunir les villages epars | 9 |
| Villages Celtes | recovery | Soigner les fievres d'Azenor | 7 |
| Cercles Pierres | discovery | Reveler le chant des menhirs | 8 |
| Cercles Pierres | survival | Resister au silence de Keridwen | 10 |
| Marais Korrigans | survival | Echapper aux feux follets | 12 |
| Marais Korrigans | discovery | Percer les illusions de Gwydion | 8 |
| Collines Dolmens | recovery | Apaiser les ancetres d'Elouan | 9 |
| Collines Dolmens | alliance | Restaurer les liens ancestraux | 7 |
| Iles Mystiques | discovery | Trouver le passage vers Avalon | 12 |
| Iles Mystiques | survival | Resister aux chants des selkies | 10 |

### Narration d'arrivee — Texte + Commentaire Merlin

**Foret de Broceliande**
> *"La brume se dechire comme un rideau de soie. Des arbres. Des arbres partout. Si vieux que leurs racines semblent avoir pousse avant le sol."*
> Merlin (nostalgie_voilee): "Chez moi. Enfin... Les chenes ne font plus de nouvelles pousses. Mais ils tiennent. Ils sont bretons."

**Landes de Bruyere**
> *"Le monde s'ouvre d'un coup. Plus d'arbres, plus de murs. Rien que le ciel et la bruyere, mauves et gris."*
> Merlin (humour_melancolique): "Le vent y parlait, avant. Des discours entiers. Maintenant il marmonne. Un peu comme moi, les mauvais jours."

**Cotes Sauvages**
> *"Le sel, d'abord. Puis le bruit — les vagues qui s'ecrasent sur le granite noir."*
> Merlin (humour_noir_doux): "La mer. Elle recule un peu plus chaque annee. Un pecheur m'a dit qu'elle reviendrait. C'etait il y a trois siecles."

**Villages Celtes**
> *"Des toits d'ardoise derriere la brume. De la fumee qui monte, droite et lente..."*
> Merlin (tendresse_non_masquee): "Les humains. Ils cuisinent, ils chantent, ils se disputent pour des histoires de cloture. C'est magnifique."

**Cercles de Pierres**
> *"Les pierres emergent de la brume, une a une... Des centaines. Des milliers. Dans un silence si profond qu'on l'entend vibrer."*
> Merlin (gravite_resignee): "Trois mille menhirs. Ils jouaient un accord, autrefois... Maintenant ils fredonnent. C'est deja ca."

**Marais des Korrigans**
> *"L'air change. Plus lourd, plus epais... Des arbres morts tordent leurs branches... Des lueurs dansent au ras du sol."*
> Merlin (avertissement_humoristique): "Bon. Quelques conseils: ne suis pas les lumieres, ne parle pas aux flaques, et si quelque chose te propose un marche, lis les petites lignes."

**Collines aux Dolmens**
> *"Le sol monte doucement. Des dolmens emergent comme des tables oubliees par des geants... Un if immense se dresse."*
> Merlin (melancolie_percante): "Les collines sont plus vieilles que moi. Et crois-moi, c'est un exploit. Elles se souviennent de tout. Le probleme, c'est que le 'tout'... diminue."

**Iles Mystiques**
> *"Avalon. La brume s'ouvre comme un rideau. L'ocean est d'un bleu impossible... Le chant que tu n'entends qu'a moitie."*
> Merlin (crainte_sacree): "Avalon. Ou ce qu'il en reste. Meme moi, je n'ose pas dire son vrai nom. Morgane veille. Elle ne juge pas. Elle observe. C'est pire."

### Pool de cartes d'evenements par biome (event_cards.json)

| Biome | Nb cartes | Exemples de themes |
|-------|-----------|-------------------|
| Foret Broceliande | 6 | Chene ancien, communion forestiere |
| Landes Bruyere | 4 | Navigation tempete, defis survie |
| Cotes Sauvages | 4 | Naufrages, choix moraux maritimes |
| Villages Celtes | 4 | Assemblees politiques, reunions de clans |
| Cercles Pierres | 4 | Rituels druidiques, eveil des menhirs |
| Marais Korrigans | 4 | Rencontres trickster, feux follets |
| Collines Dolmens | 4 | Tombes ancestrales, secrets oghamiques |
| Iles Mystiques | 6 | Selkies, rencontres Morgane le Fay |
| Universel | 5 | Presages de tempete, voyageurs mysterieux, eclipses, sources sacrees, animaux messagers |

---

---

## 43. Les 18 Oghams — Specifications Completes

### 43.1 REVEAL (3 Oghams — Palette Bleue)

| Ogham | Arbre | Unicode | Cooldown | Cout | Starter | Effet |
|-------|-------|---------|----------|------|---------|-------|
| **beith** | Bouleau (Birch) | ᚁ | 3 | 0 | Oui | Revele l'effet complet d'1 option au choix |
| **coll** | Noisetier (Hazelnut) | ᚉ | 5 | 80 | Non | Revele les 3 options completes |
| **ailm** | Sapin (Fir) | ᚐ | 4 | 60 | Non | Predit le theme + champ lexical de la prochaine carte |

### 43.2 PROTECTION (3 Oghams — Palette Verte)

| Ogham | Arbre | Unicode | Cooldown | Cout | Starter | Effet |
|-------|-------|---------|----------|------|---------|-------|
| **luis** | Sorbier (Rowan) | ᚂ | 4 | 0 | Oui | Bloque le prochain effet negatif unique |
| **gort** | Lierre (Ivy) | ᚌ | 6 | 100 | Non | Reduit les degats >10 a 5 (1 instance) |
| **eadhadh** | Tremble (Aspen) | ᚓ | 8 | 150 | Non | Annule TOUS les effets negatifs de la carte courante |

### 43.3 BOOST (3 Oghams — Palette Or)

| Ogham | Arbre | Unicode | Cooldown | Cout | Starter | Effet |
|-------|-------|---------|----------|------|---------|-------|
| **duir** | Chene (Oak) | ᚇ | 4 | 70 | Non | Soin instantane +12 PV |
| **tinne** | Houx (Holly) | ᚈ | 5 | 120 | Non | Double les effets positifs de l'option choisie |
| **onn** | Ajonc (Gorse) | ᚑ | 7 | 90 | Non | Genere +10 monnaie biome instantanement |

### 43.4 NARRATIVE (3 Oghams — Palette Pierre/Prune)

| Ogham | Arbre | Unicode | Cooldown | Cout | Starter | Effet |
|-------|-------|---------|----------|------|---------|-------|
| **nuin** | Frene (Ash) | ᚅ | 6 | 80 | Non | Remplace la pire option par une nouvelle |
| **huath** | Aubepine (Hawthorn) | ᚆ | 5 | 100 | Non | Regenere les 3 options de la carte |
| **straif** | Prunellier (Blackthorn) | ᚎ | 10 | 140 | Non | Force un twist narratif sur la prochaine carte |

### 43.5 RECOVERY (3 Oghams — Palette Sauge)

| Ogham | Arbre | Unicode | Cooldown | Cout | Starter | Effet |
|-------|-------|---------|----------|------|---------|-------|
| **quert** | Pommier (Apple) | ᚊ | 4 | 0 | Oui | Soin +8 PV |
| **ruis** | Sureau (Elder) | ᚏ | 8 | 130 | Non | Soin +18 PV mais coute 5 monnaie biome |
| **saille** | Saule (Willow) | ᚄ | 6 | 90 | Non | +8 monnaie biome + soin +3 PV |

### 43.6 SPECIAL (3 Oghams — Palette Rouge/Braise)

| Ogham | Arbre | Unicode | Cooldown | Cout | Starter | Effet |
|-------|-------|---------|----------|------|---------|-------|
| **muin** | Vigne (Vine) | ᚋ | 7 | 110 | Non | Inverse positif/negatif de l'option choisie |
| **ioho** | If (Yew) | ᚔ | 12 | 160 | Non | Reroll complet de la carte |
| **ur** | Bruyere (Heather) | ᚒ | 10 | 140 | Non | Sacrifice 15 PV → +20 monnaie biome + x1.3 score minigame |

---

## 44. Les 8 Archetypes — Personnalite du Joueur

### 44.1 Axes de Personnalite (chacun -2 a +2)

| Axe | Pole Negatif | Pole Positif |
|-----|-------------|-------------|
| Approche | Prudent | Audacieux |
| Relation | Solitaire | Social |
| Esprit | Analytique | Intuitif |
| Coeur | Pragmatique | Compassionnel |

### 44.2 8 Archetypes

| # | ID | Titre | Pattern | Description |
|---|-----|-------|---------|-------------|
| 1 | gardien | Le Gardien | approche:-1, coeur:+1 | Protecteur au coeur immense. Prudent mais courageux pour les autres. |
| 2 | explorateur | L'Explorateur | approche:+1, esprit:+1 | Aventurier guide par l'instinct. Le monde l'appelle. |
| 3 | sage | Le Sage | relation:-1, esprit:-1 | Observateur solitaire et analytique. La solitude nourrit sa reflexion. |
| 4 | heros | Le Heros | approche:+1, relation:+1 | Courageux et inspirant. Les autres trouvent force a ses cotes. |
| 5 | guerisseur | Le Guerisseur | coeur:+1, relation:+1 | Empathique et social. Sa presence apaise les ames troublees. |
| 6 | stratege | Le Stratege | esprit:-1, approche:-1 | Calculateur et prudent. Voit dix coups a l'avance. |
| 7 | mystique | Le Mystique | esprit:+1, relation:-1 | Intuitif et solitaire. Les brumes murmurent leurs secrets. |
| 8 | guide | Le Guide | coeur:+1, esprit:+1 | Intuitif et bienveillant. Mene par l'exemple. |

---

## 45. Les 8 PNJ Gardiens de Biome

| # | Nom | Biome | Arc Narratif | Cartes | Condition |
|---|-----|-------|-------------|--------|-----------|
| 1 | **Gwenn** | Foret Broceliande | Le Chene Chantant | 3 | druides rep >= 30 |
| 2 | **Erwan** | Landes Bruyere | Le Chant des Cairns | 3 | anciens rep >= 25 |
| 3 | **Maelle** | Cotes Sauvages | Le Signal de Sein | 4 | korrigans rep >= 20 |
| 4 | **Cadogan** | Villages Celtes | Le Puits des Souhaits | 4 | anciens rep >= 35 |
| 5 | **Brennos** | Cercles Pierres | L'Alignement Perdu | 5 | 5 oghams possedes |
| 6 | **Gwen Du** | Marais Korrigans | Le Tertre du Silence | 5 | korrigans rep >= 50 |
| 7 | **Ildiko** | Collines Dolmens | La Voix de l'If | 5 | ankou rep >= 40 |
| 8 | **Morgane** | Iles Mystiques | Le Passage d'Avalon | 6 | niamh rep >= 60 |

### 45.1 Archetypes Visuels PNJ (32x32 pixel art)

| Archetype | Tenue | Detail |
|-----------|-------|--------|
| villageois | Tunique rouille, chemise parchemin | Paysan breton |
| druide | Robe foret, gui jade | Pretre celtique |
| guerrier | Armure pierre, blason braise | Combattant |
| barde | Robe prune ombre, plume ciel | Conteur itinerant |
| marchand | Tablier bronze, pieces or | Commercant |
| ermite | Cape pierre, lanterne ciel | Solitaire des bois |
| noble | Habit bleu profond, couronne miel | Aristocrate |
| sorciere | Robe prune ombre, oeil magique jade | Enchanteresse |

---

## 46. Scenarios Narratifs — Quetes Hand of Fate

### 46.1 La Fille Perdue de Broceliande (medium)

**Affinite:** foret_broceliande + marais_korrigans

| Anchor | Carte | Contenu |
|--------|-------|---------|
| fille_trace | 3 (±1) | Decouverte de traces suspectes |
| fille_chasseur | 8 (±2) | Rencontre avec un chasseur |
| fille_climax | 14 (±2) | Confrontation finale |

**Resolutions:** victoire / sombre / twist

### 46.2 Le Serment du Cerf d'Argent (hard)

**Affinite:** foret + cercles + collines

| Anchor | Carte | Contenu |
|--------|-------|---------|
| cerf_vision | 2 (±1) | Vision du cerf mythique |
| cerf_gardien | 6 (±1) | Rencontre avec le gardien |
| cerf_epreuve | 11 (±2) | Epreuve rituelle |
| cerf_serment | 16 (±2) | Le serment final |

**Flags:** serment_accepte / refuse / cerf_etait_merlin

### 46.3 La Forge du Korrigan (medium)

**Affinite:** marais + foret + collines

| Anchor | Carte | Contenu |
|--------|-------|---------|
| korrigan_bruit | 3 (±1) | Bruits metalliques |
| korrigan_marche | 7 (±2) | Proposition de marche |
| korrigan_trahison | Climax | Revelation de la trahison |

**Flags:** objet_maudit, korrigan_surpasse, dette_korrigan

---

## 47. Persona Merlin — Specification Narrative

### 47.1 Directive Core

"Tu es MERLIN, druide ancestral de Broceliande. Francais ASCII uniquement. Phrases courtes (1 phrase par defaut, max 120 caracteres). Ton: mysterieux, bienveillant, taquin, philosophique."

### 47.2 Regles Cles

- Appelle le joueur "Voyageur" ou "mon ami"
- JAMAIS d'anglais, JAMAIS de meta ("IA", "modele", "programme")
- Vocabulaire celtique obligatoire: brume, pierre, ogham, nemeton, sidhe, dolmen, korrigans, mousse, source, cercle, vent, etoiles, souffle, rune

### 47.3 Exemples Few-Shot

```
"Ah, Voyageur, la brume te salue."
"Va vers la pierre aux trois marques."
"Suis la mousse, elle ne ment pas."
```

### 47.4 Glitches Intentionnels (quirks voix)

| Type | Exemple |
|------|---------|
| Repetitions | "Le vent... le vent guide tes pas." |
| Techniques | "Latence de brume... je reprends." |
| Meta-glitches | "Mes circuits... mes os, je voulais dire." |

### 47.5 Mots Interdits (22)

```
simulation, programme, ia, intelligence artificielle,
modele de langage, llm, serveur, algorithme, token,
api, machine learning, neural, dataset, artificial,
language model, computer, software, ...
```

---

## 48. Les 8 Biomes — Specifications Detaillees

| Biome | Saison | Difficulte | Monnaie | PNJ | Arc |
|-------|--------|-----------|---------|-----|-----|
| Foret Broceliande | Printemps | 0 | Herbes enchantees | Gwenn | Le Chene Chantant (3 cartes) |
| Landes Bruyere | Automne | +1 | Brins de bruyere | Erwan | Le Chant des Cairns (3 cartes) |
| Cotes Sauvages | Ete | 0 | Coquillages | Maelle | Le Signal de Sein (4 cartes) |
| Villages Celtes | Ete | -1 | Pieces de cuivre | Cadogan | Le Puits des Souhaits (4 cartes) |
| Cercles Pierres | Printemps | +1 | Fragments de rune | Brennos | L'Alignement Perdu (5 cartes) |
| Marais Korrigans | Automne | +2 | Pierres phosphorescentes | Gwen Du | Le Tertre du Silence (5 cartes) |
| Collines Dolmens | Hiver | 0 | Os graves | Ildiko | La Voix de l'If (5 cartes) |
| Iles Mystiques | Hiver | +3 | Ecume solidifiee | Morgane | Le Passage d'Avalon (6 cartes) |

### 48.1 Missions par Biome

| Biome | Titre Mission | Description |
|-------|-------------|-------------|
| Foret Broceliande | Le Souffle de Barenton | Restaurer la clarte de la Source de Barenton |
| Landes Bruyere | Le Chant des Cairns | Retrouver la melodie perdue |
| Cotes Sauvages | Le Signal de Sein | Atteindre le phare de l'ile de Sein |
| Villages Celtes | Le Puits des Souhaits | Restaurer le puits a voeux |
| Cercles Pierres | L'Alignement Perdu | Realigner les pierres de Carnac |
| Marais Korrigans | Le Tertre du Silence | Affronter le Vide dans le tertre du chef |
| Collines Dolmens | La Voix de l'If | Ecouter les derniers mots de l'if ancien |
| Iles Mystiques | Le Passage d'Avalon | Trouver le passage avant que la maree ne le scelle |

---

## 49. Events Saisonniers — Roue de l'Annee

| Saison | Festival | Effet |
|--------|----------|-------|
| Automne | Samhain | Honorer les morts → +10 rep ankou |
| Hiver | Yule | Feu du solstice → +5 soin ou sommeil |
| Printemps | Imbolc | Benediction de Brigid → +10 soin |
| Printemps | Ostara | Equinoxe → +10 rep druides ou -3 |
| Ete | Beltane | Feu purificateur → +12 rep druides |
| Ete | Lughnasadh | Jeux de la premiere recolte → +10 rep anciens |

---

## 50. Types de Missions

| Type | Description | Poids | Cible |
|------|-------------|-------|-------|
| survive | Atteindre 30 cartes | 0.30 | 30 cartes |
| equilibre | Rester equilibre >= 8 tours | 0.20 | 8 tours |
| explore | Visiter 6 lieux differents | 0.25 | 6 noeuds |
| artefact | Trouver l'artefact cache | 0.25 | 5 progres |

---

*Document genere le 2026-03-15 (v5.0) par exploration exhaustive du codebase et de la Lore Bible.*
*v5.0: +8 sections (18 oghams complets, 8 archetypes, 8 PNJ gardiens, 3 scenarios, persona Merlin, 8 biomes detailles, events saisonniers, types de missions).*
*v4.0: +6 sections (quiz 10 questions/8 archetypes, hub complet, catalogue menus/scenes, 47 evenements, taxonomie+pity, 8 biomes avec gardiens/missions/dialogues).*
*v3.0: +14 annexes (23 minigames complets, 34 talents, persona Merlin, dialogues, FastRoute, 18 shaders, 45+ SFX, ScreenFrame, scene 3D, map gen, meteo, musique).*
*Sources: tous les scripts GDScript, IntroPersonalityQuiz.gd, HubAntre.gd, merlin_constants.gd, merlin_persona.json, scenario_catalogue.json, pixel_npc_portrait.gd, et tous les fichiers sources precedents.*
