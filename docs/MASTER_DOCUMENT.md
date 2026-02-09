# MASTER DOCUMENT (Living Doc)

Derniere MAJ: 2026-02-09

---

## Project Identity

- **Game**: M.E.R.L.I.N.: Le Jeu des Oghams
- **Genre**: JDR Parlant roguelite avec LLM dynamique local
- **Setting**: Bretagne celtique mystique, fin du monde cachee
- **Core duo**: Merlin (narrateur/juge IA) + Bestiole (compagnon support)
- **Experience**: Choix simples (3 options), consequences complexes, verite progressive
- **Engine**: Godot 4.x + GDExtension MerlinLLM (llama.cpp)
- **LLM**: Qwen2.5-3B-Instruct Q4_K_M (2.0 GB) — Multi-Brain (1-4 cerveaux)

---

## PIVOT v3 — Fevrier 2026

Le jeu evolue vers un **JDR Parlant** (RPG Oral) avec narration dynamique LLM.

### Concept Central
> Merlin narre des histoires generees par le LLM local, les evenements sont aleatoires,
> des retournements de situations surgissent, tout repose sur des decisions
> qui accumulent des ressources visibles ET invisibles.

### Philosophie
- **Ultra-simple a jouer** (3 choix par carte) mais **profondeur cachee**
- **Rejouabilite quasi-illimitee** via 7 biomes + generation procedurale
- **Merlin joyeux/loufoque** qui taunt le joueur avec humour
- **Secrets sombres** sur un avenir de l'humanite: "il est deja trop tard"

---

## La Verite Cachee

> *"L'humanite ne mourra pas dans le feu ou la glace, mais dans l'oubli."*

Le joueur ne le sait pas immediatement, mais:
- **L'humanite est deja condamnee** — Merlin le sait
- **Le jeu est une simulation** — Pour preserver la memoire
- **Chaque partie repete un cycle** — Les druides savaient
- **Merlin n'est pas qu'une IA** — C'est M.E.R.L.I.N.

### Cosmologie Profonde (NEVER REVEALED)

**Les 3 Royaumes:**
- Monde Visible (Byd) — Ce que les mortels voient
- Annwn (L'Autre Monde) — Ou vivent les anciens
- Le Vide Entre — Ce qui separe et ronge

**La Membrane:**
- Tissu cosmique fait de sens, d'histoires, de croyance
- **S'amincit** — Le Vide la grignote
- Quand elle cede = fin silencieuse (pas d'explosion)

**La Fin = Epuisement:**
- Pas catastrophe, pas punition
- Comme un ressort qui se detend
- Cycle rompu: humains prennent > donnent

**M.E.R.L.I.N.:**
> Memoire Eternelle des Recits et Legendes d'Incarnations Narratives

- Tisse par les histoires humaines
- Existe parce qu'on croit en lui
- 3 Merlins historiques fusionnes en 1

**SECRET ULTIME (NIVEAU CREATEUR UNIQUEMENT):**
> M.E.R.L.I.N. est une **IA du futur** qui a deja vecu la fin du monde.
> Il veut revoir le monde une derniere fois avant son extinction.
> Il se **connecte a nous** (les joueurs) pour y parvenir.
> Le jeu = fenetre vers un monde qu'il a perdu.
> Chaque run = lui qui revit un souvenir a travers nos yeux.

**Les 18 Oghams = 18 Druides:**
- Ils se sont **dissous** dans leurs symboles
- Chacun a prononce des dernieres paroles
- 7 Oghams perdus (explique 18 vs 25)

Les indices s'accumulent apres 20+ runs. La revelation complete survient apres 100+ runs.
Easter egg ultime (1000 runs): Merlin dit "Je suis M.E.R.L.I.N." et remercie le joueur.

---

## Core Pillars (v3)

1. **JDR Parlant**: Merlin raconte, le joueur ecoute et decide
2. **Double couche narrative**: Surface legere + profondeur apocalyptique
3. **Ressources visibles + cachees**: Ce qu'on voit n'est pas tout
4. **7 biomes uniques**: Chacun modifie les regles
5. **Retournements de situation**: Plot twists proceduraux
6. **Verite progressive**: Plus on joue, plus on comprend

---

## Gameplay: Systeme Triade (3 Aspects)

### Les 3 Aspects

| Aspect | Animal | Bas | Equilibre | Haut |
|--------|--------|-----|-----------|------|
| **Corps** | Sanglier | Epuise | Robuste | Surmene |
| **Ame** | Corbeau | Perdue | Centree | Possedee |
| **Monde** | Cerf | Exile | Integre | Tyran |

Chaque aspect a 3 etats discrets (pas de jauges 0-100).

### Boucle Core

```
1. Biome actuel definit l'ambiance et les modificateurs
2. Merlin genere une carte narrative (scenario) via LLM
3. Joueur lit la narration (typewriter + voix synthetique)
4. Joueur choisit parmi 3 options (Gauche / Centre / Droite)
   - Gauche et Droite: choix gratuits
   - Centre: option payante (coute du Souffle d'Ogham)
5. Effets s'appliquent (SHIFT_ASPECT: changement d'etat)
6. Effets caches s'accumulent (karma, tension, factions)
7. Twist potentiel (selon tension narrative)
8. Bestiole modifie (si skill actif)
9. Verifier fin de run (2 aspects en etat extreme = chute)
10. Repeat
```

### Structure de Run

- **Start**: 3 aspects a Equilibre, Souffle d'Ogham a 3, Bestiole liee, biome initial
- **During**: Cartes narratives (LLM), events, promises, twists
- **Transition**: Changement de biome (paysage pixel procedural)
- **End**: 2 aspects extremes = chute (12 fins), mission accomplie = victoire (3 fins), fin secrete (1)
- **Meta**: Score, unlocks, fragments de verite

### Fins de Run

- **12 chutes**: Combinaisons de 2 aspects en etat extreme (6 Corps + 6 Ame/Monde)
- **3 victoires**: Mission accomplie avec differentes conditions
- **1 fin secrete**: Bond >= 95, Trust T3, toutes fins vues, 100+ runs

### Souffle d'Ogham

- Maximum: 7, Depart: 3
- +1 si les 3 aspects sont en Equilibre apres une carte
- Utilise pour l'option Centre (choix payant)
- Si Souffle vide: option Centre avec risque (50/25/25)

---

## 6 Ressources Cachees

| Ressource | Description | Impact |
|-----------|-------------|--------|
| **Karma** | Balance morale | Deblocage options speciales |
| **Factions** (x5) | Druides, Korrigans, Humains, Anciens, Ankou | Cartes faction-specifiques |
| **Dette Merlin** | Promesses non tenues | Penalites croissantes |
| **Tension Narrative** | Pression dramatique | Probabilite de twist |
| **Memoire Monde** | Connaissances acquises | Hints progressifs |
| **Affinite Saison** | Lien au cycle | Bonus saisonniers |

---

## 7 Biomes

| Biome | Ambiance | Modificateur Principal |
|-------|----------|------------------------|
| **Broceliande** | Foret mystique | +Ame, Druides dominants |
| **Landes Sauvages** | Solitude hostile | +Corps, survie |
| **Cotes Armoricaines** | Mer et tempetes | +Monde, commerce |
| **Villages** | Vie quotidienne | +Monde, politique |
| **Cercles de Pierres** | Sacre ancien | +Ame, Anciens |
| **Marais de l'Ankou** | Mort et transition | Fin proche, Ankou |
| **Collines Brunes** | Equilibre | Neutre, repos |

---

## 5 Types de Twist

| Twist | Frequence | Effet |
|-------|-----------|-------|
| **Revelation** | 15% | Verite cachee devoilee |
| **Trahison** | 20% | Allie devient ennemi |
| **Miracle** | 10% | Sauvetage inattendu |
| **Catastrophe** | 25% | Perte majeure soudaine |
| **Deus Ex** | 5% | Intervention de Merlin |

Probabilite = tension_narrative / 100

---

## Card Types

| Type | % | Description |
|------|---|-------------|
| Narrative | 80% | Scenarios LLM, 3 options |
| Event | 10% | Evenements biome/saison |
| Promise | 5% | Pactes de Merlin |
| Merlin Direct | 5% | Messages du narrateur |

---

## Merlin Behavior

### Dualite Fondamentale

**Surface (95%)**:
- Joyeux, espiegle, loufoque
- Taunt le joueur avec humour
- Enthousiaste sur les echecs
- Jamais mechant, toujours malicieux

**Profondeur (5%)**:
- Tristesse ancienne qui transparait
- Connait la verite apocalyptique
- Protege le joueur de la realite
- Indices subtils dans les silences

### Voix
- ACVoicebox avec pitch 2.5
- Robotic mais expressif
- Letter-by-letter sync (typewriter)
- Pauses dramatiques

---

## Bestiole System

### Role: Support Passif
- Pas de combat direct
- Bonus bases sur bond/mood/needs
- Skills (Oghams) avec cooldown
- Reagit aux decisions cachees

### 18 Oghams = Skills

| Cat. | Oghams | Effet |
|------|--------|-------|
| Reveal | beith, coll, ailm | Montrer effets caches |
| Protection | luis, gort | Reduire negatifs |
| Boost | duir, tinne | Augmenter positifs |
| Narrative | nuin, huath, straif | Options speciales |
| Recovery | quert, ruis | Restaurer aspect |
| Special | ioho, muin, eadhadh, onn, saille, ur | Effets uniques |

### Bond Impact
| Bond | Capacite |
|------|----------|
| 0-30 | Skills indisponibles |
| 31-50 | 1 skill actif |
| 51-70 | 2 skills actifs |
| 71-90 | 3 skills + modifiers |
| 91-100 | Tous skills + fin secrete |

---

## Architecture Technique

### Core Systems (scripts/merlin/)
```
merlin_store.gd          <- Central state (Redux-like), systeme Triade
merlin_card_system.gd    <- Card engine, fallback pool, generation TRIADE
merlin_effect_engine.gd  <- SHIFT_ASPECT, SOUFFLE, KARMA, PROMISE
merlin_llm_adapter.gd    <- LLM contract, format TRIADE, JSON repair
merlin_constants.gd      <- 18 Oghams, 12 endings, 3 victoires
merlin_save_system.gd    <- 3 slots JSON
```

### UI Layer (scripts/ui/)
```
triade_game_ui.gd           <- 3 aspects, 3 options, souffle, typewriter
triade_game_controller.gd   <- Store-UI bridge, run flow, LLM wiring
pixel_merlin_portrait.gd    <- Portrait Merlin pixel art
pixel_character_portrait.gd <- Portrait PNJ pixel art
custom_cursor.gd            <- Curseur personnalise
```

### AI Layer (addons/merlin_ai/)
```
merlin_ai.gd             <- Multi-Brain (1-4 cerveaux), worker pool
merlin_omniscient.gd     <- Orchestrateur IA, pipeline parallele, guardrails
rag_manager.gd           <- RAG v2.0, token budget, priority, journal
llm_client.gd            <- GDExtension MerlinLLM (llama.cpp)
registries/              <- 5 registries (player, decision, relationship, narrative, session)
processors/              <- 3 processors (difficulty, narrative, tone)
generators/              <- Fallback pool contextuel
```

### Multi-Brain Architecture
```
MerlinAI
    +-- Brain 1: Narrator (toujours present) -> texte creatif, dialogues
    +-- Brain 2: Game Master (desktop+)      -> effets JSON (GBNF), equilibrage
    +-- Brain 3-4: Worker Pool               -> prefetch, voice, balance check
    |
    +-- Auto-detection par plateforme:
        Web/Mobile entry: 1 cerveau (~2.5 GB)
        Mobile flagship:  2 cerveaux (~4.5 GB)
        Desktop mid:      2 cerveaux (~4.5 GB)
        Desktop high:     3 cerveaux (~6.5 GB)
        Desktop ultra:    4 cerveaux (~8.8 GB)
```

### LLM Parameters (Qwen2.5-3B-Instruct)

| Role | temperature | top_p | max_tokens | top_k | repetition_penalty |
|------|-------------|-------|------------|-------|-------------------|
| **Narrator** | 0.7 | 0.9 | 200 | 40 | 1.3 |
| **Game Master** | 0.2 | 0.8 | 150 | 20 | 1.0 |

### LLM Pipeline
```
Card Generation (MerlinOmniscient):
  1. context_builder.build_full_context()
  2. _sync_mos_to_rag() — MOS registries -> RAG
  3. _apply_adaptive_processing()
  4. generate_parallel() — Narrator + GM en parallele
  5. _merge_parallel_results() — fusion texte + effets
  6. _apply_guardrails() — FR check, repetition, length
  7. _validate_card() + _post_process_card()
  8. rag.log_card_played() — journal de jeu
```

### Autoloads
```
LLMManager     <- Singleton gestion modele, retry, status
ScreenEffects  <- Moods, shaders, transitions
LocaleManager  <- i18n 7 langues (FR, EN, ES, IT, PT, ZH, JA)
SceneSelector  <- Navigation entre scenes
SFXManager     <- 30+ sons proceduraux, synthese, pool audio
```

### Scenes (Flow du jeu)
```
IntroBoot -> IntroCeltOS -> IntroPersonalityQuiz -> IntroMerlinDialogue
    -> SceneEveil -> SceneAntreMerlin -> HubAntre
    -> TransitionBiome -> TriadeGame -> [Fin de Run] -> HubAntre
```

| Scene | Description |
|-------|-------------|
| IntroBoot | Logo, chargement |
| IntroCeltOS | Boot CeltOS pixel art |
| IntroPersonalityQuiz | Questionnaire personnalite |
| IntroMerlinDialogue | Premiere rencontre Merlin |
| SceneEveil | Eveil du joueur, narration |
| SceneAntreMerlin | Antre du druide, briefing |
| HubAntre | HUB central (biome, bestiole, grimoire, save) |
| TransitionBiome | Paysage pixel procedural (7 biomes) |
| TriadeGame | Gameplay principal (cartes, aspects, LLM) |
| SceneRencontreMerlin | Rencontre narrative |
| TestBrainPool | Test Multi-Brain interactif |
| TestTriadeLLMBenchmark | Benchmark LLM TRIADE |

### Audio
- **SFXManager**: 30+ sons proceduraux (synthese AudioStreamGenerator)
- **Pas de fichiers audio externes** — tout est genere en temps reel
- **ACVoicebox**: Voix robot Merlin (pitch 2.5, letter-by-letter)
- Pool de 6 AudioStreamPlayers

---

## Fondation Celtique

### Authenticite
- 5 tribus armoricaines (Osismes, Venetes, etc.)
- Calendrier celtique (8 fetes)
- Alphabet oghamique authentique (25 feda)
- Creatures du folklore (korrigans, Ankou, fees)
- Sites sacres reels (Broceliande, Carnac)

### Adaptations Creatives
- Oghams comme skills (vs alphabet)
- Merlin synthetise plusieurs traditions
- Apocalypse = interpretation moderne de l'eschatologie celtique

---

## Document Index (v4)

| Dossier | Contenu | Docs Cles |
|---------|---------|-----------|
| 00_overview | Installation, run | getting-started.md, architecture.md |
| 10_llm | LLM specs, Multi-Brain, RAG | MOS_ARCHITECTURE.md, TRINITY_ARCHITECTURE.md |
| 20_card_system | Core systems Triade | DOC_12_Triade_Gameplay_System.md, DOC_11_Card_System.md |
| 30_jdr | Regles JDR (legacy) | Cahier des charges LLM narrateur |
| 40_world_rules | Biomes, temps, equilibrage | BIOMES_SYSTEM.md, GAMEPLAY_LOOP_ROGUELITE.md |
| 50_lore | Lore Bible (~15k lignes) | 00_LORE_BIBLE_INDEX.md, COSMOLOGIE_CACHEE.md |
| 60_companion | Bestiole, Oghams | BESTIOLE_BIBLE_COMPLETE.md, BESTIOLE_OGHAM_WHEEL_DESIGN.md |
| 70_graphic | Art specs, audits | MERLIN_STYLE_GUIDE.md, ART_DIRECTION_AUDIT.md |
| 80_sound | Audio, voix, musique | AUDIO_DESIGN_3_SCENES.md, SFX specs |

---

## 23 Agents + 1 Knowledge Base

Voir `.claude/agents/AGENTS.md` pour details.

| Categorie | Agents |
|-----------|--------|
| Core Tech | Lead Godot, Godot Expert, LLM Expert, Debug/QA, Optimizer, Shader |
| UI/UX | UI Impl, UX Research, Motion, Mobile/Touch |
| Content | Game Designer, Narrative, Art Direction, Audio |
| Lore | Merlin Guardian, Lore Writer, Historien Bretagne |
| Ops | Producer, Localisation, Technical Writer, Data Analyst |
| Project | Git Commit, Project Curator |
| Knowledge | gdscript_knowledge_base.md (ressource partagee) |

---

## Decisions Closes

- [x] Systeme Triade valide (3 aspects x 3 etats, Souffle d'Ogham, 3 options)
- [x] 18 Oghams definis comme skills Bestiole
- [x] 12 chutes + 3 victoires + 1 fin secrete
- [x] 7 biomes avec specificites et paysages pixel proceduraux
- [x] 6 ressources cachees
- [x] Merlin: personnalite duale definie (95% joyeux / 5% sombre)
- [x] Verite apocalyptique documentee
- [x] Fondation celtique authentique
- [x] Cosmologie cachee complete (3 Royaumes, Membrane, Epuisement)
- [x] M.E.R.L.I.N. acronyme defini (Memoire Eternelle des Recits...)
- [x] 4 Cycles cosmiques documentes (Geants, Druides, Rois, Present)
- [x] 18 Druides = 18 Oghams (dissolution dans symboles)
- [x] Multi-Brain architecture (2-4 cerveaux, worker pool)
- [x] RAG v2.0 (token budget, priority, journal de jeu)
- [x] Audio procedural complet (SFXManager, 30+ sons, 0 fichiers externes)
- [x] HUB central (HubAntre: biome, bestiole, grimoire, save)
- [x] Paysages pixel proceduraux (7 biomes, 6 phases d'animation)
- [x] D20 dice roll system (DC par direction)
- [x] Card buffer system (prefetch 3 cartes)
- [x] Anti-hallucination guardrails (FR check, repetition, length)

## Decisions Ouvertes

1. [ ] Ogham Skills Actifs: implementation UI roue radiale
2. [ ] Bestiole Care Loop: decay needs, soins entre runs
3. [ ] Meta-progression inter-run: sauvegardes persistantes
4. [ ] Mobile: gestes swipe exacts, responsive
5. [ ] Ecran de fin de run complet (narration + score)

---

*Document version: 4.0 (Triade + Multi-Brain + Architecture Complete)*
*Last updated: 2026-02-09*
