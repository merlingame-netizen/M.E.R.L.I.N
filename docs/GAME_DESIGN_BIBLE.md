# GAME DESIGN BIBLE — M.E.R.L.I.N. : Le Jeu des Oghams v2.0

> **Source de verite unique** pour le game design de M.E.R.L.I.N.
> Remplace et supersede : MASTER_DOCUMENT.md, DOC_12, DOC_13, DOC_11, NEW_MECHANICS_DESIGN.md
> Date de creation : 2026-03-12 | Derniere mise a jour : 2026-03-12

---

## 1. Vision & Core Loop

### 1.1 Pitch

M.E.R.L.I.N. est un **jeu de cartes narratif roguelite** ancre dans la mythologie celtique de Broceliande. Le joueur explore des biomes enchantes, fait des choix narratifs, et resout des minigames lies a ses actions. Chaque run est une aventure unique generee par un LLM local. La rejouabilite est le moteur principal.

### 1.2 Piliers de design

| Pilier | Description |
|--------|-------------|
| **Exploration** | Decouvrir des Oghams, des fins, des cartes rares, des biomes. La rejouabilite est le plaisir principal. |
| **Narration generative** | Chaque run raconte une histoire unique, generee par IA locale (Qwen 3.5). |
| **Minigames comme verbes** | Chaque choix narratif se traduit en un defi ludique lie au verbe d'action. |
| **Progression permanente** | Entre les runs, debloquer des Oghams et bonus via un arbre de talents. |

### 1.3 Core Loop

```
┌─────────────────────────────────────────────────────────────┐
│                    BOUCLE D'UN RUN                          │
│                                                             │
│  [LLM genere trame + cartes] → Carte affichee               │
│         ↓                                                    │
│  Joueur lit le texte narratif                                │
│         ↓                                                    │
│  Joueur choisit un VERBE D'ACTION (1-4 options)              │
│         ↓                                                    │
│  MINIGAME declenche (lie au champ lexical du verbe)          │
│         ↓                                                    │
│  Resultat 0-100 → Effets appliques (intensite proportionnelle)│
│         ↓                                                    │
│  Mise a jour : vie, factions, monnaie, progression           │
│         ↓                                                    │
│  Verification fin de run (vie=0, narration converge, etc.)   │
│         ↓                                                    │
│  Carte suivante (generee dynamiquement selon choix)          │
└─────────────────────────────────────────────────────────────┘
```

### 1.4 Meta Loop (entre les runs)

```
[Fin de run] → Gains : Essences + reputation factions
       ↓
[Hub / Antre] → Arbre de talents (depenser Essences)
       ↓
[Choisir biome] → Debloque selon progression
       ↓
[Nouveau run] → Scenario genere par LLM
```

---

## 2. Systemes de jeu

### 2.1 Vie (barre unique)

Une seule barre de vie remplace tous les anciens systemes (4 jauges, Triade, Life Essence).

| Parametre | Valeur |
|-----------|--------|
| Maximum | 100 |
| Depart | 100 |
| Drain de base | -1 par carte (pression de survie) |
| Degats echec critique | -10 |
| Degats evenement rate | -6 |
| Soin succes critique | +5 |
| Soin noeud REST | +18 |
| Seuil alerte UI | 25 |
| A 0 | Fin de run (avec narration, pas "game over") |

### 2.2 Oghams — 18 pouvoirs hybrides

Les 18 Oghams sont des pouvoirs du joueur (pas d'un compagnon). Certains sont **actifs** (pouvoir a activer pendant le run), d'autres sont des **cles narratives** (debloquent du contenu).

Le joueur **equipe 1 Ogham actif** a la fois, affiche comme icone sur le HUD. Cliquer l'active. Cooldown apres usage.

#### Catalogue des 18 Oghams

| # | Clé | Nom | Arbre | Categorie | Effet | Cooldown |
|---|-----|-----|-------|-----------|-------|----------|
| 1 | `beith` | Bouleau | Betula | Reveal | Revele l'effet d'une option | 3 |
| 2 | `coll` | Noisetier | Corylus | Reveal | Revele les effets de toutes les options | 5 |
| 3 | `ailm` | Sapin | Abies | Reveal | Predit le theme de la prochaine carte | 4 |
| 4 | `luis` | Sorbier | Sorbus | Protection | Bloque le prochain effet negatif | 4 |
| 5 | `gort` | Lierre | Hedera | Protection | Absorbe un impact extreme | 6 |
| 6 | `eadhadh` | Tremble | Populus | Protection | Annule tous les negatifs de la carte | 8 |
| 7 | `duir` | Chene | Quercus | Boost | Bonus de soin immediat | 4 |
| 8 | `tinne` | Houx | Ilex | Boost | Double les effets positifs | 5 |
| 9 | `onn` | Ajonc | Ulex | Boost | Regenere de la monnaie biome | 7 |
| 10 | `nuin` | Frene | Fraxinus | Narratif | Ajoute une option supplementaire | 6 |
| 11 | `huath` | Aubepine | Crataegus | Narratif | Remplace la carte actuelle | 5 |
| 12 | `straif` | Prunellier | Prunus | Narratif | Force un retournement de situation | 10 |
| 13 | `quert` | Pommier | Malus | Recovery | Soigne la barre de vie | 4 |
| 14 | `ruis` | Sureau | Sambucus | Recovery | Soin massif (equilibre) | 8 |
| 15 | `saille` | Saule | Salix | Recovery | Regenere des ressources | 6 |
| 16 | `muin` | Vigne | Vitis | Special | Inverse les effets positifs/negatifs | 7 |
| 17 | `ioho` | If | Taxus | Special | Regenere une carte completement nouvelle | 12 |
| 18 | `ur` | Bruyere | Calluna | Special | Sacrifice vie pour bonus massif | 10 |

> **Note** : Les descriptions d'effets ci-dessus sont adaptees au nouveau systeme (sans Triade/Souffle/Bestiole). Les effets exacts seront redefinis lors de l'implementation.

#### Starters

Le joueur commence avec 3 Oghams debloques : `beith`, `luis`, `quert` (1 reveal, 1 protection, 1 recovery).

### 2.3 Factions — 5 reputations

| Faction | Theme | Mots-cles | Seuil Contenu | Seuil Fin |
|---------|-------|-----------|:---:|:---:|
| **Druides** | Connaissance, nature, rituels | druide, ogham, nemeton, chene, barde | 50 | 80 |
| **Anciens** | Traditions, ancetres, magie ancienne | ancien, ancetre, tradition, sagesse | 50 | 80 |
| **Korrigans** | Chaos, fees, malice | korrigan, fee, feu follet, farce, tresor | 50 | 80 |
| **Niamh** | Amour, Tir na nOg, nostalgie | niamh, eau, lac, amour, nostalgie | 50 | 80 |
| **Ankou** | Mort, passage, nuit | ankou, mort, passage, nuit, ombre | 50 | 80 |

**Echelle** : 0.0 a 100.0 par faction.

**Effets des seuils** :
- **≥ 50** : Cartes speciales de la faction debloquees dans le pool
- **≥ 80** : Fin narrative de la faction disponible (declenchee en fin de run)

**Persistance cross-run** : Oui, avec decay de 8% de la valeur absolue par run.

**Affichage** : PAS dans le HUD — ecran stats dedie accessible via menu.

### 2.4 Monnaies

#### Essences magiques (cross-run)

| Propriete | Detail |
|-----------|--------|
| Nom | A definir (celtique court : "Nwyvre" ? "Anam" ? "Bri" ?) |
| Persistance | Cross-run (permanente) |
| Sources | Fin de run (base + bonus), recompenses speciales |
| Usage | Arbre de talents : debloquer Oghams + bonus passifs |

#### Monnaie biome (per-run)

| Propriete | Detail |
|-----------|--------|
| Type | Different selon le biome (herbes, coquillages, runes, etc.) |
| Persistance | Per-run uniquement (perdue en fin de run) |
| Sources | Recompense de minigames, evenements narratifs, **ramassee physiquement au sol dans la balade 3D** (clic) |
| Usages | Faciliter les minigames, interactions PNJ, bonus temporaires |

### 2.5 Minigames — Le coeur du gameplay

**Regle fondamentale** : Chaque choix narratif declenche un minigame lie au champ lexical du verbe d'action choisi.

#### Flow

```
Joueur choisit option "Escalader la falaise"
       ↓
Code detecte le verbe "escalader" dans la liste fermee
       ↓
Mapping deterministe : "escalader" → minigame "equilibre"
       ↓
Minigame "equilibre" se lance (difficulte = contexte narratif)
       ↓
Score 0-100 → effets proportionnels
```

#### Catalogue des minigames (14 types, objectif 15+)

| Minigame | Description | Verbes déclencheurs |
|----------|-------------|---------------------|
| **Traces** | Suivre des empreintes sans quitter le chemin | piste, trace, empreinte, pas, sentier |
| **Runes** | Dechiffrer un ogham dans la pierre | rune, ogham, symbole, gravure, inscription |
| **Equilibre** | Maintenir l'equilibre sur un passage instable | pont, equilibre, vertige, gouffre, precipice |
| **Herboristerie** | Identifier la bonne plante parmi les toxiques | plante, herbe, champignon, racine, cueillir, potion |
| **Negociation** | Convaincre un esprit par les mots justes | esprit, fae, parler, negocier, korrigan, convaincre, marchander |
| **Combat Rituel** | Esquiver dans un cercle sacre | combat, defi, guerrier, lame, epee, duel |
| **Apaisement** | Calmer un gardien par le rythme | apaiser, calmer, respir, gardien, rage, colere |
| **Sang-froid** | Curseur stable malgre les pulsations | piege, danger, froid, sang, approcher, appat |
| **Course** | QTE pour maintenir la poursuite ou fuir | courir, pourchasser, fuir, sprint, trouee, course |
| **Fouille** | Trouver l'indice cache en temps limite | fouille, chercher, indice, recueillir, ruban, preuve |
| **Ombres** | Se deplacer entre couvertures sans etre vu | cacher, ombre, discret, invisible, embuscade |
| **Volonte** | Tenir le focus malgre les murmures | douter, murmure, resister, volonte, doute, hesiter |
| **Regard** | Memoriser puis reproduire une sequence | vision, forme, memoriser, fixer, apparition, spectr |
| **Echo** | Suivre l'intensite sonore vers la bonne direction | voix, appel, son, echo, ecouter, cri, chant |

**Objectif** : 40+ verbes dans la liste fermee, 15+ types de minigames.

**Responsabilite** :
- Le **LLM** choisit un verbe dans la liste fermee (dans son texte narratif + les labels d'options)
- Le **code** mappe le verbe vers le minigame (deterministe, pas le LLM)
- Le **code** determine la difficulte (selon contexte narratif, biome, progression)

#### Resultat du minigame

| Score | Label | Multiplicateur d'effets |
|-------|-------|------------------------|
| 0-20 | Echec critique | Effets negatifs x1.5 |
| 21-50 | Echec | Effets negatifs x1.0 |
| 51-79 | Reussite partielle | Effets positifs x0.5 |
| 80-100 | Reussite | Effets positifs x1.0 |
| 95-100 | Reussite critique | Effets positifs x1.5 + bonus |

---

## 3. Structure d'un run

### 3.1 Demarrage

1. Joueur choisit un biome dans le Hub (parmi ceux debloques)
2. Ecran de transition / balade 3D dans le biome (collecte de monnaie biome)
3. LLM genere une **trame narrative** (outline + premières cartes)
4. Run demarre : vie=100, monnaie biome=collectee, Ogham actif=equipe

### 3.2 Scenario hybride

- Le LLM genere un **outline/trame** au debut (pitch du scenario, arc narratif, personnages)
- Les **premieres cartes** sont pre-generees a partir de la trame
- Les **choix du joueur** influencent les cartes suivantes (generees dynamiquement)
- **Longueur variable** selon le scenario (pas le biome) — certains courts (10 cartes), d'autres longs (40+)
- Le run **se termine** quand la narration converge vers une fin

### 3.3 Carte — structure

```
{
  "text": String,              // Texte narratif (genere par LLM Narrator)
  "speaker": String,           // "Merlin" ou NPC
  "options": [
    {
      "label": String,         // Verbe d'action (de la liste fermee)
      "effects": [Dictionary], // Effets suggeres par LLM GM, valides par code
    },
    // ... 1 a 4 options
  ],
  "type": "narrative" | "event" | "promise" | "merlin_direct",
  "tags": Array,               // Tags narratifs pour contexte
}
```

### 3.4 Types de cartes

| Type | Poids | Description |
|------|:---:|-------------|
| Narrative | 80% | Carte de choix standard |
| Evenement | 10% | Evenement contextuel (apres carte 3) |
| Promesse | 5% | Quete avec delai (max 2 actives) |
| Merlin Direct | 5% | Intervention directe de Merlin |

### 3.5 Conditions de fin

| Condition | Fin |
|-----------|-----|
| Vie = 0 | Fin narrative "mort" (pas un game over — le LLM personalise) |
| Faction ≥ 80 en fin de scenario | Fin de faction disponible |
| Scenario termine (narration converge) | Fin naturelle |
| Conditions speciales (cartes, combinaisons) | Fins secretes |

**Principe** : Il n'y a pas de "mauvaise fin". Toute fin est narrativement valide.

---

## 4. Biomes — 8 mondes celtiques

### 4.1 Vue d'ensemble

| # | Cle | Nom | Sous-titre | Saison | Difficulte | Unlock |
|---|-----|-----|------------|--------|:---:|--------|
| 1 | `foret_broceliande` | Foret de Broceliande | Ou les arbres ont des yeux | Printemps | 0 | Starter |
| 2 | `landes_bruyere` | Landes de Bruyere | L'horizon sans fin | Automne | 1 | 2 runs |
| 3 | `cotes_sauvages` | Cotes Sauvages | L'ocean murmurant | Ete | 0 | 3 runs |
| 4 | `villages_celtes` | Villages Celtes | Flammes obstinees | Ete | -1 | 5 runs |
| 5 | `cercles_pierres` | Cercles de Pierres | Ou le temps hesite | Hiver | 1 | 8 runs + 2 fins |
| 6 | `marais_korrigans` | Marais des Korrigans | Deception et feux follets | Automne | 2 | 10 runs + fin "harmonie" |
| 7 | `collines_dolmens` | Collines aux Dolmens | Les os de la terre | Printemps | 0 | 15 runs + 5 fins |
| 8 | `iles_mystiques` | Iles Mystiques | Au-dela des brumes | Samhain | 3 | 20 runs + 5 fins + fin "transcendance" |

### 4.2 Detail par biome

#### Foret de Broceliande (starter)
- **Theme** : Nature ancienne, mystere vegetal, brume enchantee, korrigans
- **Creatures** : Fees, korrigans, loups anciens, arbres animes
- **Atmosphere** : Brume perpetuelle, lumiere filtree, echos de voix anciennes
- **Oghams bonus** : quert, huath, coll
- **Monnaie biome** : Herbes / Baies enchantees

#### Landes de Bruyere
- **Theme** : Survie, solitude, endurance, vent hurlant
- **Creatures** : Rapaces, lievres, ermites, esprits du vent
- **Atmosphere** : Landes balayees par le vent, ciel immense, bruyere violette
- **Oghams bonus** : luis, onn, saille
- **Monnaie biome** : Brins de bruyere / Plumes de rapace

#### Cotes Sauvages
- **Theme** : Commerce, exploration, danger maritime, tempetes
- **Creatures** : Phoques, mouettes, marchands etrangers, sirenes
- **Atmosphere** : Falaises battues par les vagues, sel et algues, ports de peche
- **Oghams bonus** : muin, nuin, tinne
- **Monnaie biome** : Coquillages / Perles de brume

#### Villages Celtes
- **Theme** : Politique, social, intrigues, assemblee tribale
- **Creatures** : Villageois, chefs de clan, druides, forgerons
- **Atmosphere** : Huttes rondes, feux de camp, assemblees, rumeurs
- **Oghams bonus** : duir, coll, beith
- **Monnaie biome** : Pieces de cuivre / Faveurs de clan

#### Cercles de Pierres
- **Theme** : Magie, spirituel, liminal, rituels druidiques
- **Creatures** : Esprits ancestraux, druides anciens, ombres du passe
- **Atmosphere** : Menhirs millenaires, energie palpable, etoiles differentes
- **Oghams bonus** : ioho, straif, ruis
- **Monnaie biome** : Fragments de rune / Eclats de menhir

#### Marais des Korrigans
- **Theme** : Danger, mystere, tentation, tresors caches
- **Creatures** : Korrigans, feux follets, creatures des tourbieres, morts-vivants
- **Atmosphere** : Eaux stagnantes, brume epaisse, lumieres trompeuses
- **Oghams bonus** : gort, eadhadh, luis
- **Monnaie biome** : Pierres phosphorescentes / Gouttes de marais

#### Collines aux Dolmens
- **Theme** : Sagesse, ancestral, memoire, paix profonde
- **Creatures** : Esprits d'anciens rois, sages, animaux paisibles
- **Atmosphere** : Collines douces, dolmens et tumulus, air paisible et lourd de memoire
- **Oghams bonus** : quert, ailm, coll
- **Monnaie biome** : Os graves / Cailloux de sagesse

#### Iles Mystiques
- **Theme** : Transcendance, passage, monde invisible, liminalite absolue
- **Creatures** : Selkies, banshees, fees des vagues, esprits anciens, gardienne Morgane
- **Atmosphere** : Brume eternelle, vagues phosphorescentes, chants lointains, tour en ruines
- **Oghams bonus** : ailm, ruis, ioho
- **Monnaie biome** : Ecume solidifiee / Larmes de Morgane

### 4.3 Balade 3D dans le biome

Chaque biome a une **scene 3D explorable** (style FPS contemplatif). Le joueur s'y promene :
- Avant le run (transition, collecte de monnaie biome)
- La monnaie biome est **physiquement presente au sol** — le joueur clique dessus pour la ramasser
- L'ambiance visuelle (lumiere, couleurs) depend de l'heure reelle et de la saison in-game

---

## 5. Progression meta

### 5.1 Arbre de talents

Debloque avec les **Essences magiques** (cross-run).

**Structure** : Branches thematiques par faction + branche centrale.

```
                    [CENTRAL]
                   /    |    \
            [DRUIDES] [NEUTRE] [ANCIENS]
              /                    \
       [KORRIGANS]            [NIAMH]
              \                    /
                    [ANKOU]
```

**Contenu des branches** :
- **Oghams** (actifs + narratifs) — chaque branche contient 3-4 Oghams thematiques
- **Bonus passifs** — ex: +10% reputation Druides, -5% difficulte minigames nature, +vie max
- **Prerequis** — certains Oghams necessitent d'en avoir deja debloques d'autres

### 5.2 Fins — catalogue + LLM

**~10-15 fins cataloguees** :

| Type | Condition | Description |
|------|-----------|-------------|
| Fin Druides | Rep Druides ≥ 80 | Le joueur est accueilli par le cercle des druides |
| Fin Anciens | Rep Anciens ≥ 80 | Les ancetres reconnaissent le joueur |
| Fin Korrigans | Rep Korrigans ≥ 80 | Le joueur entre dans le monde des fees |
| Fin Niamh | Rep Niamh ≥ 80 | Niamh invite le joueur a Tir na nOg |
| Fin Ankou | Rep Ankou ≥ 80 | Le joueur devient passeur entre les mondes |
| Fin Mort | Vie = 0 | Fin narrative liee au contexte du moment |
| Fin Naturelle | Scenario termine | Le run s'acheve paisiblement |
| Fin Harmonie | Conditions speciales | Equilibre parfait entre factions |
| Fin Transcendance | Conditions speciales | Acces aux Iles Mystiques |
| Fins Secretes | Combinaisons rares | Decouvertes par exploration |

**Personnalisation LLM** : Le LLM genere le texte de chaque fin en fonction du contexte specifique du run (choix faits, biome, factions, evenements). Deux "Fin Druides" ne seront jamais identiques.

**Pas de hierarchie** : Toute fin est narrativement valide. Finir tot n'est pas un echec.

### 5.3 Ce qui persiste entre les runs

| Persiste | Perdu |
|----------|-------|
| Essences magiques | Vie |
| Reputation factions (x0.92 decay) | Monnaie biome |
| Oghams debloques | Cartes jouees |
| Arbre de talents | Scenario/trame |
| Nombre de runs, fins debloquees | Tags actifs, promesses |

---

## 6. Architecture LLM

### 6.1 Multi-Brain (Qwen 3.5 via Ollama)

| Cerveau | Modele | RAM | Role | Temperature |
|---------|--------|-----|------|:-----------:|
| **Narrator** | Qwen 3.5 4B | ~3.2 GB | Texte narratif + verbes d'action | 0.70 |
| **Game Master** | Qwen 3.5 2B | ~1.8 GB | Effets JSON (suggeres) | 0.15 |
| **Judge** | Qwen 3.5 0.8B | ~0.8 GB | Scoring qualite du Narrator | 0.30 |

### 6.2 Profils hardware

| Profil | RAM | Mode | Cerveaux |
|--------|-----|------|----------|
| NANO | 4 GB | Resident | 1 (0.8B tout) |
| SINGLE | 6 GB | Resident | 1 (2B tout) |
| SINGLE+ | 7 GB | Time-sharing | 2 (4B Narrator + 2B GM) |
| DUAL | 12 GB | Parallele | 2 (4B + 2B simultane) |
| TRIPLE | 14 GB | Parallele | 3 (4B + 2B + 0.8B) |
| QUAD | 16 GB | Parallele | 4 (4B + 2B + 0.8B Judge + 0.8B Worker) |

### 6.3 Pipeline de generation de carte

```
1. CODE construit le contexte (etat du jeu, biome, heure, factions)
2. NARRATOR/4B genere le TEXTE (~6-8s, 200 tokens, T=0.70)
   → Texte narratif + options avec verbes de la liste fermee
3. GAME MASTER/2B genere les EFFETS JSON (~2-3s, 120 tokens, T=0.15)
   → Effets suggeres par option
4. CODE valide les effets (whitelist, caps, guardrails)
5. CODE mappe les verbes vers les minigames
6. JUDGE/0.8B evalue la qualite du texte Narrator
7. AFFICHAGE de la carte au joueur
```

### 6.4 Contrat LLM — ce que le Narrator doit produire

Le Narrator genere un JSON contenant :
- `text` : texte narratif en francais (1-4 phrases)
- `speaker` : "Merlin" ou nom de PNJ
- `options` : 1 a 4 options, chacune avec un `label` (verbe d'action de la liste fermee)

**Contraintes** :
- Francais uniquement, sans anglicismes
- Verbes d'action exclusivement dans la **liste fermee** (40+ verbes)
- Jamais de meta-references (pas de "simulation", "algorithme", "token", "IA")
- Vocabulaire celtique encourage (brume, ogham, nemeton, menhir, dolmen, etc.)

### 6.5 Contrat LLM — ce que le Game Master doit produire

Le GM produit un JSON d'effets par option :
```json
{
  "option_0": [
    {"type": "ADD_REPUTATION", "faction": "druides", "amount": 15},
    {"type": "DAMAGE_LIFE", "amount": 5}
  ],
  "option_1": [
    {"type": "HEAL_LIFE", "amount": 10},
    {"type": "UNLOCK_OGHAM", "ogham": "duir"}
  ]
}
```

**Effets autorises (whitelist)** :

| Effet | Format | Description |
|-------|--------|-------------|
| `ADD_REPUTATION` | faction + amount | Modifier reputation faction |
| `HEAL_LIFE` | amount | Soigner la barre de vie |
| `DAMAGE_LIFE` | amount | Infliger des degats |
| `UNLOCK_OGHAM` | ogham_name | Debloquer un Ogham |
| `ADD_TAG` | tag_name | Ajouter un tag narratif |
| `REMOVE_TAG` | tag_name | Retirer un tag |
| `TRIGGER_EVENT` | event_id | Declencher un evenement |
| `PROMISE` | promise_id | Creer une promesse/quete |
| `PLAY_SFX` | sound_id | Jouer un son |
| `SHOW_DIALOG` | dialog_id | Afficher un dialogue |

Le CODE valide, ajuste (caps), et peut rejeter des effets proposes par le GM.

### 6.6 RAG — contexte injecte

Budget par cerveau :
- Narrator : 800 tokens (contexte 8192)
- GM : 400 tokens (contexte 4096)
- Judge/Worker : 200 tokens (contexte 2048)

Priorite des sections de contexte :
1. Detection de crise (CRITIQUE)
2. Contrat de scene
3. Narration recente
4. Arcs actifs
5. Biome + ambiance
6. Ton
7. Profil joueur
8. Promesses actives
9. Niveau de danger

### 6.7 Fallback

Si le LLM echoue ou timeout : **FastRoute** — pool de cartes pre-calculees adapte au biome. Objectif : reduire le taux de fallback de ~30% a <5%.

---

## 7. Calendrier & temps

### 7.1 Hybride : reel + in-game

| Composante | Source | Impact |
|------------|--------|--------|
| Ambiance visuelle (lumiere 3D) | **Heure reelle** du joueur | Visuel uniquement |
| Bonus mecaniques (factions) | **Cycle in-game** (avance avec les cartes) | Gameplay |
| Festivals | **Cycle in-game** | Contenu special |

### 7.2 Periodes (cycle in-game)

| Periode | Effet |
|---------|-------|
| Aube | Druides actifs (+10% reputation) |
| Jour | Cartes equilibrees |
| Crepuscule | Korrigans actifs (+10%) |
| Nuit | Ankou actif (+15% reputation) |

### 7.3 Saisons & festivals

| Saison | Mois | Festival | Effet |
|--------|------|----------|-------|
| Hiver | Dec-Fev | Imbolc (Fev) | Pool Niamh +20% |
| Printemps | Mar-Mai | Beltane (Mai) | Pool Druides +20% |
| Ete | Jun-Aout | Lughnasadh (Aout) | Pool Anciens +20% |
| Automne | Sep-Nov | Samhain (Oct) | Pool Ankou +30% |

---

## 8. HUD & UI

### 8.1 HUD en jeu

```
┌──────────────────────────────────────────┐
│ [♥ VIE ████████░░ 75/100]    [🌿 x12]   │  ← Vie + Monnaie biome
│                              [⚬ Beith]   │  ← Ogham actif (cliquable)
│                                           │
│                                           │
│     [TEXTE NARRATIF DE LA CARTE]          │
│                                           │
│                                           │
│  [Option A: Escalader]  [Option B: Parler]│  ← Verbes d'action
│  [Option C: Observer]                     │
└──────────────────────────────────────────┘
```

### 8.2 Ecrans separés

- **Stats** : 5 factions (jauges de reputation), Essences, nombre de runs
- **Oghams** : Collection des 18, equiper l'Ogham actif
- **Arbre de talents** : Depenser les Essences
- **Journal** : Fins debloquees, biomes decouverts

---

## 9. Systemes SUPPRIMES (reference historique)

> Ces systemes ont ete retires du design. Ils peuvent encore exister dans le code (nettoyage en cours).

| Systeme | Raison de suppression | Date |
|---------|-----------------------|------|
| **Triade** (Corps/Ame/Monde) | Remplace par Factions | 2026-03-11 |
| **Souffle d'Ogham** (0-7) | Plus de cout — options gratuites | 2026-03-11 |
| **4 Jauges** (Vigueur/Esprit/Faveur/Ressources) | Remplace par 1 barre de vie | 2026-03-12 |
| **Bestiole** (compagnon + bond + besoins) | Supprime — Oghams sont du joueur | 2026-03-12 |
| **Awen** (0-5, ressource bestiole) | Supprime avec la bestiole | 2026-03-12 |
| **D20 / dice roll** | Remplace par minigames systematiques | 2026-03-12 |
| **3 options fixes (G/C/D)** | Remplace par 1-4 options variables | 2026-03-11 |

---

## 10. Glossaire

| Terme | Definition |
|-------|------------|
| **Ogham** | Pouvoir du joueur (18 au total), lie a un arbre celtique |
| **Faction** | L'un des 5 groupes de reputation (Druides, Anciens, Korrigans, Niamh, Ankou) |
| **Essence** | Monnaie cross-run pour l'arbre de talents |
| **Monnaie biome** | Ressource per-run, specifique au biome, collectible en 3D |
| **Run** | Une partie complete (depart → fin narrative) |
| **Trame** | Scenario narratif genere par le LLM au debut du run |
| **Verbe d'action** | Mot de la liste fermee choisi par le LLM pour les options de carte |
| **Minigame** | Epreuve ludique declenchee par le verbe d'action choisi |
| **Hub / Antre** | Menu principal entre les runs (arbre de talents, choix de biome) |
| **FastRoute** | Pool de cartes de secours si le LLM echoue |
| **Narrator** | Cerveau LLM 4B qui genere le texte narratif |
| **Game Master** | Cerveau LLM 2B qui genere les effets JSON |
| **Judge** | Cerveau LLM 0.8B qui evalue la qualite des textes |

---

## 11. Ecarts code vs design (inventaire)

> Liste des systemes presents dans le code qui ne correspondent plus a ce design. A nettoyer.

| Systeme dans le code | Fichiers | Action |
|---------------------|----------|--------|
| 4 Gauges (ADD_GAUGE, REMOVE_GAUGE, SET_GAUGE) | merlin_store.gd, merlin_effect_engine.gd, merlin_card_system.gd | Supprimer, remplacer par HEAL_LIFE/DAMAGE_LIFE |
| Bestiole (bond, needs, skills, awen) | merlin_constants.gd (BOND_TIERS, OGHAM_STARTER_SKILLS), merlin_store.gd | Supprimer entierement |
| aspect_bias (Corps/Ame/Monde) dans biomes | merlin_biome_system.gd | Remplacer par faction_bias |
| D20 / DC system | merlin_constants.gd (DC_BASE, DC_DIFFICULTY_LABELS, ARCHETYPE_DC_BONUS) | Remplacer par minigame difficulty |
| Souffle refs | merlin_constants.gd (REWARD_TYPES), merlin_effect_engine.gd | Supprimer |
| TRIADE_LLM_PARAMS, TRIADE_GRAMMAR_PATH | merlin_llm_adapter.gd | Renommer |
| Flux system (terre/esprit/lien) | merlin_constants.gd (FLUX_*) | Evaluer : garder comme systeme cache ? |
| Awen references | merlin_constants.gd (awen_cost dans OGHAM_FULL_SPECS) | Remplacer par cooldown seul |
| bond_required dans Oghams | merlin_constants.gd | Remplacer par prerequis dans arbre de talents |
| left/center/right options | merlin_constants.gd (CardOption enum, FLUX_CHOICE_DELTA) | Remplacer par options variables 1-4 |

---

*Ce document est la source de verite unique pour le game design de M.E.R.L.I.N. v2.0.*
*Toute divergence entre ce document et le code doit etre resolue en faveur de ce document.*
*Co-ecrit entre l'utilisateur (vision) et Claude Code (structuration).*
