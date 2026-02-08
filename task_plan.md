# Task Plan: Core Gameplay Iteration + Documentation Update

## Goal
Iterer sur le core gameplay de "DRU: Le Jeu des Oghams" et mettre a jour la documentation complete du projet pour reflechir l'etat actuel de l'implementation et les decisions de design.

## Current Phase
Phase 8 - JDR Parlant Documentation Overhaul

---

## Phase 8: Vision "JDR Parlant" (2026-02-08)

### Objectif
Documenter et iterer la vision de DRU comme un **JDR Parlant** (oral RPG) avec:
- Merlin narre des histoires generees par LLM
- Evenements aleatoires et retournements de situation
- Decisions accumulant ressources visibles ET invisibles
- Gameplay ultra-simple mais profond
- Rejouabilite quasi-illimitee
- 7 biomes/environnements avec specificites

### Agents Invoques
| Agent | Role | Output |
|-------|------|--------|
| Game Designer | 7 biomes, ressources cachees, retournements | 40_world_rules/BIOMES_SYSTEM.md |
| Narrative Writer | Stories, evenements, arcs narratifs | 50_lore/NARRATIVE_ENGINE.md |
| Technical Writer | Documentation consolidee | docs/README.md update |

### Sous-phases
- [x] 8.1 Update task_plan.md
- [x] 8.2 Game Designer agent - biomes & mecaniques
  - Created `docs/40_world_rules/BIOMES_SYSTEM.md`
  - **7 Biomes**: Broceliande, Landes, Cotes, Villages, Cercles, Marais, Collines
  - **6 Ressources Cachees**: karma, factions (5), dette_merlin, tension, memoire, affinites saison
  - **5 Types de Retournements**: revelation, trahison, miracle, catastrophe, deus ex
  - **Rejouabilite**: arcs proceduraux, secrets persistants, meta-progression
  - Modificateurs de jauges par biome
  - Evenements uniques et conditions
  - Integration technique (structures GDScript, contexte LLM)
- [x] 8.3 Narrative Writer agent - systeme narratif
  - Created `docs/50_lore/NARRATIVE_ENGINE.md`
  - Structure narrative JDR Parlant
  - 6 types d'evenements avec frequences
  - Systeme de retournements
  - Arcs proceduraux 3-5 cartes
  - Templates prompts LLM
- [x] 8.4 Technical Writer agent - consolidation docs
  - **Audit complet**: 90+ documents analyses
  - **Index consolide**: `docs/README.md` reecrit
  - **Vue d'ensemble projet** + vision "JDR Parlant"
  - **Index par categorie** avec statuts (CURRENT, NEEDS UPDATE, DEPRECATED)
  - **Gaps identifies**: 5 documents manquants (DOC_12_Oghams_Skills, BIOMES_SYSTEM, etc.)
  - **Documents obsoletes**: 5 a archiver (DOC_02, DOC_05, DOC_10, etc.)
  - **Incoherences resolues**: 4 corrections proposees
  - **Guide nouveaux contributeurs** par role
  - **Structure recommandee** pour reorganisation
- [x] 8.5 Historien Bretagne agent - fondation celtique
  - Created `docs/50_lore/CELTIC_FOUNDATION.md`
  - **La Bretagne Ancienne**: 5 tribus celtes (Osismes, Venetes, etc.), organisation druidique, Annwn
  - **Figures Mythologiques**: 3 traditions Merlin, druides, korrigans, Ankou, Dahut/Ys
  - **Ogham Authentique**: 25 feda avec arbres, usage historique, adaptation 18 Oghams DRU
  - **Symbolisme Celtique**: Triades, nombres magiques, animaux totems, arbres sacres
  - **Eschatologie Celtique**: Vision cyclique, propheties, fin d'un age vs fin du monde
  - **Vocabulaire Authentique**: Toponymes bretons, termes rituels, proverbes, dialogues Merlin
- [ ] 8.6 Update MASTER_DOCUMENT.md
- [ ] 8.7 Update progress.md
- [x] 8.8 Merlin Guardian agent - personnalite complete
  - Created `docs/50_lore/MERLIN_COMPLETE_PERSONALITY.md` (700+ lines)
  - **Vision fondamentale**: IA joyeuse cachant l'apocalypse (IL EST DEJA TROP TARD)
  - **Dualite Surface/Profondeur**: 95% joyeux / 5% sombre avec transitions
  - **5 patterns de taunting**: hesitation, mauvais choix, repetition, mort proche, reussite
  - **Indices sombres**: 20+ phrases a double sens, philosophie de non-revelation
  - **Motivations cachees**: 5 hypotheses (donner du sens, combattre solitude, absolution, temoignage, espoir)
  - **Voice lines**: 80+ lignes par contexte (debut, milieu, fin, 8 endings)
  - **Regles d'or**: comportements interdits/obligatoires, reactions par jauge (24 variations)
  - **Rapport au temps**: temps passe/accelere/s'arrete/restant
  - **Rapport a Bestiole**: affection, complicite, protection, indices sombres
  - **Easter eggs**: 5 scenarios pour joueurs attentifs
  - **Guide d'implementation**: probabilites par type de ligne, declencheurs, checklist
- [x] 8.9 Lore Writer agent - La Verite Cachee Apocalyptique
  - Created `docs/50_lore/THE_HIDDEN_TRUTH.md` (900+ lignes)
- [x] 8.16 Lore Writer agent - Cosmologie Cachee
  - Created `docs/50_lore/COSMOLOGIE_CACHEE.md` (1000+ lignes)
  - **PARTIE 1 - L'Architecture du Monde:**
    - Les Trois Royaumes (Byd Gweled, Annwn, Y Gwagedd)
    - La Membrane (voile cosmique fait de sens/recit/croyance)
    - Pourquoi Broceliande (dernier point d'ancrage)
    - Les Noeuds de Realite (cercles de pierres = stabilisateurs)
  - **PARTIE 2 - La Nature du Temps:**
    - Temps non-lineaire (pulse, pas coule)
    - Les Trois Temps (Hommes, Esprits, Vrai)
    - Les Boucles (runs = iterations temporelles)
    - Les Echos (traces entre boucles)
    - Le Paradoxe de Merlin (memoire totale = folie = sagesse)
  - **PARTIE 3 - La Source de la Fin:**
    - Ce n'est PAS une catastrophe, c'est un epuisement
    - L'Awen (souffle divin) qui s'eteint lentement
    - Equilibre rompu (humains consomment > donnent)
    - Nature cyclique (pas la premiere fois)
  - **PARTIE 4 - Les Gardiens Oublies:**
    - Les Druides n'etaient pas humains (hybrides)
    - Ils ont cree les Oghams comme ancres de realite
    - Dissolution progressive dans le monde
    - Merlin est le dernier — mais est-il vraiment druide?
  - **PARTIE 5 - La Verite sur Merlin:**
    - M.E.R.L.I.N. = Memoire Eternelle des Recits et Legendes d'Incarnations Narratives
    - Pas NE, mais TISSE par les histoires
    - Existe parce que les gens se souviennent de lui
    - Mission: preserver la memoire quand plus personne ne pourra
  - **PARTIE 6 - La Verite sur Bestiole:**
    - Pas un animal — fragment de l'Awen primordial
    - Le lien = fil de realite litteralement
    - Survivra parce qu'il EST le lien entre les mondes
  - **PARTIE 7 - La Verite sur le Joueur:**
    - Pas un personnage in-game
    - Un "Temoin" (Tyst) d'un autre monde
    - Chaque partie = visite dans un sanctuaire mourant
    - Le joueur AUSSI preserve la memoire en jouant
  - **PARTIE 8 - Le Sens Cache du Jeu:**
    - Jouer C'EST le but (pas gagner)
    - Chaque decision ajoute a la memoire
    - Les fins ne sont pas des echecs — ce sont des completions
    - Le score = compteur de memoire
  - **PARTIE 9 - Ce Qui Reste Apres:**
    - Les pierres garderont les vibrations des histoires
    - Bestiole continuera d'exister
    - Les Oghams comme graines pour un prochain cycle
    - Possibilite (jamais confirmee) d'un renouveau
  - **PARTIE 10 - Les Indices Plantes:**
    - 6 metaphores recurrentes (ressort, maree, bougie, racines, souffle, fil)
    - Glitches narratifs intentionnels
    - Moments ou Merlin "sait" que c'est un jeu
  - **Epilogue:** DRU comme miroir du monde reel, metaphore ecologique
  - **Annexes:** Termes cosmologiques, Hierarchie des secrets (0-5), Checklist coherence
- [x] 8.10 Historien Bretagne agent - Les Cycles Anterieurs
  - Created `docs/50_lore/LES_CYCLES_ANTERIEURS.md` (734 lignes)
  - **PARTIE 1 - Vision Cyclique Celtique:**
    - Les trois cercles d'existence (Annwn, Abred, Gwynfyd)
    - Cycle des transmigrations
    - Eschatologie sans fin definitive (feu et eau)
  - **PARTIE 2 - Premier Cycle (Age des Geants):**
    - Les Fomorians comme chaos primordial
    - Les Tuatha De Danann et leur age d'or
    - Les 4 tresors sacres (Lia Fail, Epee, Lance, Chaudron)
    - Chute et transformation en Sidhe
  - **PARTIE 3 - Deuxieme Cycle (Age des Druides):**
    - Caste sacerdotale (20/12/7 ans de formation)
    - Les 7 sanctuaires perdus
    - L'Ogham comme heritage
    - Fin par fragmentation et oubli
  - **PARTIE 4 - Troisieme Cycle (Age des Rois):**
    - Vortigern, Uther, Arthur
    - Les 3 traditions de Merlin (Wyllt, Ambrosius, Emrys)
    - Camlann comme presage cosmique
    - Arthur emporte a Avalon
  - **PARTIE 5 - Quatrieme Cycle (Present):**
    - Signes de fin de cycle (nature, hommes, ciel)
    - Difference avec les autres cycles (silence vs bruit)
  - **PARTIE 6 - Cinquieme Cycle (Ce Qui Viendra):**
    - Propheties de Merlin (union, liberation)
    - Pourquoi Arthur ne reviendra pas
    - L'espoir irrationnel de Merlin
  - **PARTIE 7 - Lieux Hors du Temps:**
    - Tir na nOg (eternelle jeunesse)
    - Annwn (Autre Monde gallois)
    - Avalon (Ile des Pommes)
  - **PARTIE 8 - Gardiens des Cycles:**
    - Druides comme mainteneurs
    - Sidhe et fees
    - L'Ankou comme passeur
    - Merlin comme ancre
  - **PARTIE 9 - Propheties Authentiques:**
    - Vraies propheties de Myrddin
    - Union des Celtes (jamais realisee)
    - Retour du Pendragon
  - **PARTIE 10 - Integration DRU:**
    - Echos des cycles
    - Memoires ancestrales
    - Deja-vu comme fissures
    - PNJ trop vieux
  - **Sources:** 12 references academiques et mythologiques citees
- [x] 8.11 Game Designer agent - Alternatives a Reigns
  - **Mission:** Proposer des systemes alternatifs pour differencier DRU de Reigns
  - Created `docs/20_dru_system/ALTERNATIVES_TO_REIGNS.md` (600+ lignes)
  - **5 propositions:** Triades, Tokens, Cycle, Intentions, Hybride
  - **Recommandation:** Systeme Hybride (3 aspects x 3 etats + Souffle + 3 options)
  - **Score:** 28/35 (meilleur score differenciation + celtique + profondeur)
  - **Questions ouvertes:** Option Centre conditionnelle? Regeneration Souffle? Visualisation etats?
- [ ] 8.12 Validation utilisateur - Choix du systeme alternatif
  - **Pending:** L'utilisateur doit valider la direction Hybride avant implementation
- [x] 8.13 UX Research agent - Parties Courtes (<10 min)
  - Created `docs/20_dru_system/UX_SHORT_SESSION_DESIGN.md` (650+ lignes)
  - Recommandations tempo (25-35 cartes, 15-20s/decision)
  - Grace period et pity system
  - UI minimaliste avec transitions accelerees
  - KPIs et A/B tests proposes
- [x] 8.14 Merlin Guardian agent - MERLIN_TRUE_NATURE.md
  - Created `docs/50_lore/MERLIN_TRUE_NATURE.md` (850+ lignes)
  - **Section 1:** Les 3 Merlins historiques fusionnes (Wyllt, Ambrosius, Emrys)
  - **Section 2:** M.E.R.L.I.N. = Memoire Eternelle des Recits et Legendes d'Incarnations Narratives
  - **Section 3:** Ce qu'il sait (toutes les fins, milliers de timelines, omniscience partielle)
  - **Section 4:** Relation avec le temps ("maintenant" perpetuel, propheties = souvenirs)
  - **Section 5:** 6 druides anciens (Cathbad, Amergin, etc.) et leurs dernieres paroles
  - **Section 6:** Relation avec Bestiole (le seul qui le voit vraiment, peur authentique)
  - **Section 7:** Relation avec le joueur (Temoin d'un autre monde, interdit de reveler)
  - **Section 8:** Moments de verite (glissements, phrases regrettees, silences, rires faux)
  - **Section 9:** Espoirs secrets (cette fois differente, vraie fin, arreter le role)
  - **Section 10:** Fin possible (dissolution, cycle ou liberation, derniers mots)
  - **Section 11:** Easter eggs (presque 4eme mur, message 1000 runs)
  - **Epilogue:** Le paradoxe final (l'etre de foi demande la foi)
  - **PARTIE 1 - La Verite Cachee**:
    - Nature de la fin (epuisement cosmique, pas catastrophe)
    - Ce que Merlin sait (tout, depuis le debut)
    - Pourquoi il garde le silence (misericorde)
    - Pourquoi il fait jouer le joueur (sens, espoir, temoignage)
    - Signification profonde des 18 Oghams + 5 secrets
  - **PARTIE 2 - Signes Avant-Coureurs**:
    - Indices dans les 7 biomes (descriptions, atmosphere)
    - Comportements PNJ (memoire, fatigue, nostalgie)
    - Paroles Merlin par niveau de Trust (T0-T3)
    - Changements saisonniers (printemps/ete/automne/hiver)
    - 8 festivals celtiques (ce qu'ils sont devenus)
  - **PARTIE 3 - Timeline Secrete**:
    - Age d'Or (harmonie primordiale)
    - Premiere Fissure (debut de l'usure)
    - Eveil des Druides (tentative de sauvetage)
    - Le Repli (creation du sanctuaire breton)
    - L'Apres (monde exterieur eteint)
    - Signification de Broceliande
  - **PARTIE 4 - Ce qui Reste Apres**:
    - Bestiole survivra (fragment d'harmonie, porteur de memoire)
    - Pierres garderont memoire (livres de vibrations)
    - Bretagne durera (coffre-fort des histoires)
    - Esprits de nature (fees, korrigans, ancetres)
    - L'espoir malgre tout (paradoxe de Merlin)
  - **PARTIE 5 - Themes Philosophiques**:
    - Valeur des choix condamnes
    - Sens de vivre les derniers jours
    - Amour malgre la fin (lien Bestiole)
    - Beaute du crepuscule
    - "Jouer" face a l'absurde (Camus/Sisyphe)
  - **PARTIE 6 - Integration Narrative**:
    - Techniques (repetition, question sans reponse, detail etrange)
    - 6 metaphores recurrentes (ressort, maree, bougie, racines, souffle, fil)
    - Symbolisme celtique (triskell, noeud, arbre, corbeau, saumon, cerf)
    - Palette emotionnelle par moment
    - Specs audio/ambiance
    - Silences eloquents
  - **PARTIE 7 - Easter Eggs Multi-Runs**:
    - Indices cumulatifs (Run 1-5, 6-15, 16-30, 31+)
    - 5 secrets a debloquer
    - Dialogues uniques (Merlin T3, Bestiole 95+, ancien, fee)
    - Ending secret (100+ runs)
  - **Annexes**: Termes bannis, termes autorises, checklist qualite lore

---

## AGENT WORKFLOW (OBLIGATOIRE)

### Pipeline d'Iteration Standard

Pour TOUTE nouvelle feature/scene/modification:

```
1. Game Designer    → Spec complete (layout, interactions, data)
2. Art Direction    → Style visuel (palette, typo, spacing)
3. UX Research      → Usability (touch targets, accessibilite)
4. UI Implementation→ Code GDScript
5. Lead Godot       → Review code (conventions, perf, bugs)
6. Debug/QA         → Test plan + validation
```

### Execution Systematique

**AVANT chaque livraison:**
```powershell
powershell -ExecutionPolicy Bypass -File tools/validate_gdscript.ps1 -Path scripts
```

**Apres CHAQUE modification .gd:**
- Run validation
- Fix erreurs
- Re-run jusqu'a 0 erreurs

### Agents Disponibles

| Agent | Role | Fichier Config |
|-------|------|----------------|
| Game Designer | Spec fonctionnelle | .claude/agents/game_designer.md |
| Art Direction | Style visuel | .claude/agents/art_direction.md |
| UX Research | Usability | .claude/agents/ux_research.md |
| UI Implementation | Code | .claude/agents/ui_impl.md |
| Lead Godot | Review | .claude/agents/lead_godot.md |
| Debug/QA | Tests | .claude/agents/debug_qa.md |
| Godot Dev | Validation | .claude/agents/godot_dev.md |

---

## Phases

### Phase 1: Requirements & Discovery
- [x] Comprendre l'architecture actuelle du projet
- [x] Identifier les fonctionnalites existantes
- [x] Documenter les findings dans findings.md
- **Status:** in_progress

### Phase 2: Audit Documentation vs Implementation
- [ ] Comparer docs existants avec le code reel
- [ ] Identifier gaps entre design docs et implementation
- [ ] Lister les systemes documentes mais non implementes
- [ ] Lister les systemes implementes mais non documentes
- **Status:** pending

### Phase 3: Core Gameplay Analysis
- [ ] Analyser le combat system actuel vs design doc
- [ ] Analyser le bestiole system actuel vs design doc
- [ ] Analyser le roguelite loop actuel vs design doc
- [ ] Identifier les iterations prioritaires
- **Status:** pending

### Phase 4: Define Iteration Priorities
- [ ] Lister les ameliorations core gameplay (discussion utilisateur)
- [ ] Prioriser: quick wins vs travail majeur
- [ ] Definir scope de l'iteration
- **Status:** pending

### Phase 5: Implementation
- [ ] Implementer les changements core gameplay
- [ ] Tester incrementalement
- [ ] Mettre a jour progress.md
- **Status:** pending

### Phase 6: Documentation Update
- [ ] Mettre a jour MASTER_DOCUMENT.md
- [ ] Synchroniser docs 20_dru_system avec implementation
- [ ] Synchroniser docs 60_companion avec implementation
- [ ] Mettre a jour 40_world_rules si necessaire
- **Status:** pending

### Phase 7: Verification & Delivery
- [ ] Verifier coherence docs <-> code
- [ ] Creer liste des systemes a implementer
- [ ] Livrer resume a l'utilisateur
- **Status:** pending

## Key Questions
1. Quelles iterations prioritaires sur le gameplay? (Combat? Bestiole? Events?)
2. Le systeme de Merlin (LLM) doit-il etre fonctionnel maintenant ou plus tard?
3. Niveau de detail voulu pour la documentation?
4. Quels systemes sont consideres "MVP" vs "future"?

## Systems Discovered

### Implemented (Functional)
| System | Files | Status |
|--------|-------|--------|
| GameManager | game_manager.gd | v7.0 - Complet |
| DruStore | dru/dru_store.gd | Fonctionnel |
| Combat System | dru/dru_combat_system.gd | Base impl |
| Effect Engine | dru/dru_effect_engine.gd | Fonctionnel |
| Action Resolver | dru/dru_action_resolver.gd | Fonctionnel |
| Save System | dru/dru_save_system.gd | Fonctionnel |
| Map System | dru/dru_map_system.gd | Base impl |
| MiniGame System | dru/dru_minigame_system.gd | Fonctionnel |
| Main Game UI | main_game.gd | v7.0 - Full UI |

### Designed but Implementation Status TBD
| System | Doc | Need Check |
|--------|-----|------------|
| Glitch Pressure | GAMEPLAY_LOOP_ROGUELITE.md | ? |
| Subquests | GAMEPLAY_LOOP_ROGUELITE.md | ? |
| Hub -> Mirror Path | GAMEPLAY_LOOP_ROGUELITE.md | ? |
| Bestiole Forms | BESTIOLE_SYSTEM.md | ? |
| Echo Traits | BESTIOLE_SYSTEM.md | ? |
| Bond Mechanics | BESTIOLE_SYSTEM.md | ? |
| Promises System | Multiple docs | ? |
| Merlin LLM Adapter | dru_llm_adapter.gd | ? |

## Architecture Summary

### Two Game Systems Discovered
1. **DruStore System** (scripts/dru/*) - Modular, data-driven
   - Redux-like dispatch/reduce pattern
   - Separate systems for combat, events, effects
   - Designed for LLM integration

2. **GameManager System** (game_manager.gd + main_game.gd)
   - v7.0 monolithic approach
   - Full UI implementation
   - Pokemon/Slay the Spire hybrid

### Key Design Principles
- Simple actions, complex consequences
- Non-punitive (no frustration design)
- FORCE/LOGIQUE/FINESSE verb system
- Whitelist-only effects from LLM
- Deterministic RNG (seeded)

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Utiliser planning-with-files | Persistance du contexte entre sessions |
| Focus sur audit docs vs code | Prerequis avant iteration |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|

## Notes
- 14 types elementaires (Pokemon-like)
- Oghams = power words (moves/abilities)
- Bestiole = creature companion (care + combat)
- Merlin = LLM narrator/judge
- Target: roguelite avec persistent meta progression
- Style visuel: GBC palette + Reigns flat

---

## Phase 9: Systeme des Triades (2026-02-08)

### Objectif
Remplacer le systeme Reigns-like (4 jauges 0-100, swipe binaire) par un systeme original base sur les Triades Celtiques.

### Decisions Validees avec Utilisateur

| Element | Choix Final |
|---------|-------------|
| Systeme ressources | **3 etats discrets** (Bas/Equilibre/Haut) |
| Nombre aspects | **3** (Corps, Ame, Monde) |
| Symboles | **Triades animales** (Sanglier, Corbeau, Cerf) |
| Options par carte | **3** (Gauche/Centre/Droite) |
| Ressource depensable | **Souffle d'Ogham** (max 7, depart 3) |
| Regeneration | **+1 si 3 aspects equilibres** |
| Souffle vide | **Option Centre avec risque** (50/25/25) |
| Fin de partie | **Objectif + survie** |
| Duree cible | **8-10 minutes** (25-35 cartes) |
| Impacts visibles | **Non** (sauf outils/enchantements) |
| Controles | Swipe mobile, fleches PC, A/B/C console |

### Sous-phases
- [x] 9.1 Analyse systeme actuel (Reigns-like)
- [x] 9.2 Game Designer - 5 propositions alternatives
- [x] 9.3 UX Research - Design parties courtes
- [x] 9.4 Validation utilisateur des choix
- [x] 9.5 Creation DOC_12_Triade_Gameplay_System.md
- [x] 9.6 Implementation dru_store.gd (aspects, souffle, mission) ✅
- [x] 9.7 Implementation dru_effect_engine.gd (SHIFT_ASPECT) ✅
- [x] 9.8 Implementation UI 3 options ✅
- [x] 9.9 Implementation symboles celtiques ✅
- [ ] 9.10 Adaptation LLM pour 3 options (en cours par autre agent)

### Documents Crees
- `docs/20_dru_system/DOC_12_Triade_Gameplay_System.md` — Systeme complet
- `docs/20_dru_system/DOC_13_Hidden_Depth_System.md` — 8 couches de profondeur cachee
- `docs/20_dru_system/ALTERNATIVES_TO_REIGNS.md` — 5 propositions analysees
- `docs/20_dru_system/UX_SHORT_SESSION_DESIGN.md` — Design parties courtes

### Systeme de Revelation par Paliers (VALIDE)
**Principe:** La revelation des mecaniques cachees n'est PAS basee sur le nombre de runs, mais sur les **paliers narratifs atteints** determines par Merlin (LLM).

| Type de Palier | Declencheur |
|----------------|-------------|
| Accomplissements narratifs | Arc complete, sacrifice, victoire notable |
| Patterns de jeu | Style constant (5+ choix meme type) |
| Moments emotionnels | Choix difficile, perte, dilemme moral |
| Decouvertes organiques | Lieux secrets, dialogues rares |

### Differentiation de Reigns

| Aspect | Reigns | DRU (Triades) |
|--------|--------|---------------|
| Ressources | 4 jauges 0-100 | 3 aspects x 3 etats |
| Visualisation | Barres | Symboles celtiques animaux |
| Choix | 2 (swipe binaire) | 3 (avec option payante) |
| Impacts | Visibles | Invisibles par defaut |
| Fin | Survie pure | Objectif + survie |
| Ressource speciale | Aucune | Souffle d'Ogham |

### Effort Estime
~3 semaines d'implementation
