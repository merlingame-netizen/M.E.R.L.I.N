# Task Plan: Core Gameplay Iteration + Documentation Update

## Goal
Iterer sur le core gameplay de "DRU: Le Jeu des Oghams" et mettre a jour la documentation complete du projet pour reflechir l'etat actuel de l'implementation et les decisions de design.

## Current Phase
Phase 20 - Major Gameplay Polish (COMPLETE)

---

## Phase 20: Major Gameplay Polish (2026-02-08)

### Objectif
Refonte majeure de l'experience de jeu: suppression emojis, navigation par onglets (HubAntre), narrateur Merlin au debut de run, effet pixel cascade PNJ, branchement LLM, polish visuel.

### Sous-phases
- [x] 20.1 Remplacement emojis par symboles celtiques dessines (animaux via _draw)
- [x] 20.2 Theme parchemin sur scene de gameplay (TriadeGameUI)
- [x] 20.3 Intro narrateur Merlin au debut de chaque run (typewriter + blip)
- [x] 20.4 Effet pixel cascade PNJ (style CeltOS) dans le cadre de carte
- [x] 20.5 Branchement LLM (MerlinAI) au TriadeGameController
- [x] 20.6 HubAntre: remplacement ScrollContainer par navigation onglets (3 pages)
- [x] 20.7 Navigation gamepad/clavier (L1/R1, Q/E) pour onglets HubAntre
- [x] 20.8 Ecran de fin refait style parchemin
- [x] 20.9 Boutons options re-styles avec bordures celtiques
- [x] 20.10 Validation + documentation

---

## Phase 19: Dynamic Navigation + Typing Sound + Map Rework (2026-02-08)

### Objectif
Navigation dynamique (retour scene precedente), son typing clavier, carte biomes visuelle, nettoyage MenuPrincipalReigns.

### Sous-phases
- [x] 19.1 Ajout return_scene dans ScreenEffects (tracking scene precedente)
- [x] 19.2 Modification callers (HubAntre, MenuPrincipal) pour stocker scene avant navigation
- [x] 19.3 Modification receivers (Options, Calendar, Collection, Save) pour retour dynamique
- [x] 19.4 Nettoyage MenuPrincipalReigns (supprime .tscn, redirige vers MenuPrincipal.tscn)
- [x] 19.5 Remplacement son typing: click clavier procedural dans 4 scenes
- [x] 19.6 Carte biomes visuelle avec positions Bretagne + chemins + animations
- [x] 19.7 Affichage date/heure dans carte (Jour X — HH:MM)
- [x] 19.8 Validation + documentation

---

## Phase 18: Multi-Scene Fixes & Cleanup (2026-02-08)

### Objectif
Corriger bugs critiques (voicebox hang, flow scene), harmoniser UI, ajouter presets voix, nettoyer scenes inutiles.

### Sous-phases
- [x] 18.1 Fix SceneEveil voicebox (banque whisper, safety timeout, NEXT_SCENE → HubAntre)
- [x] 18.2 Fix SceneAntreMerlin voicebox (meme pattern)
- [x] 18.3 Fix boutons retour (Options/Calendar/Collection/Save → HubAntre)
- [x] 18.4 Ajout presets voix douces (Doux, Plume, Cristal, Ancien) dans ACVoicebox + MenuOptions
- [x] 18.5 Restyle TransitionBiome (Parchemin Mystique + ornements celtiques)
- [x] 18.6 Suppression ReignsGame.tscn + nettoyage SceneSelector
- [x] 18.7 Creation MenuPrincipalReigns.tscn (scene manquante)
- [x] 18.8 Fix narrative_registry Array type mismatch
- [x] 18.9 Validation + documentation

---

## Phase 17: HUB Scene — L'Antre du Dernier Druide (2026-02-08)

### Objectif
Creer la scene HUB persistante du jeu (camp entre les runs). Point central pour:
biome selection, Bestiole care, Ogham management, save system, grimoire, meta-progression, start adventure.

### Sous-phases
- [x] 17.1 Lecture patterns UI existants (MenuPrincipalReigns, SceneAntreMerlin, MerlinStore)
- [x] 17.2 Conception architecture HUB (layout scrollable, 7 sections, data flow)
- [x] 17.3 Implementation HubAntre.gd (~1200 lignes)
  - Merlin section (portrait + typewriter + voice)
  - Status section (3 aspects Triade + souffle + day)
  - Mission section (briefing procedural + progress bar)
  - Map section (7 biomes interactifs)
  - Bestiole section (bond + awen + needs + care + oghams)
  - Grimoire section (meta stats)
  - Adventure button (contextuel)
  - Bottom nav (Options, Calendar, Save, Menu)
- [x] 17.4 Creation scene HubAntre.tscn
- [x] 17.5 Integration game flow (SceneSelector, SceneAntreMerlin redirect)
- [x] 17.6 Validation (0 erreurs / 60 fichiers)
- [x] 17.7 Mise a jour progress.md + task_plan.md

### Decisions
- HUB positionne APRES SceneAntreMerlin (narrative intro) et APRES fin de run
- Biome selection dans HUB genere mission proceduralement (14 missions, 2/biome)
- 3 soins Bestiole par visite (limite anti-farming)
- Quick save sur slot 1 + auto-save avant aventure
- Responsive layout (mobile + desktop)

---

## Previous Phase
Phase 16 - Bug Fixes + Scene Flow + Voice Calibration (COMPLETE)

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

---

## Phase 10: Scene Dialogues (2026-02-08)

### Objectif
Ecrire tous les dialogues pour les 3 scenes narratives du jeu: SceneEveil, SceneAntreMerlin, TransitionBiome.

### Sous-phases
- [x] 10.1 Lecture complete du contexte lore (10+ documents)
- [x] 10.2 Ecriture SceneEveil (4 lignes Merlin, noir, emotion -> humour)
- [x] 10.3 Ecriture SceneAntreMerlin (Bestiole, mission, classes, reactions)
- [x] 10.4 Ecriture TransitionBiome (7 arrivees + 7 commentaires Merlin)
- [x] 10.5 Creation fichier JSON structure (`data/dialogues/scene_dialogues.json`)
- [x] 10.6 Update progress.md et task_plan.md

### Output
- `data/dialogues/scene_dialogues.json` — 32 lignes de dialogue totales
  - SceneEveil: 4 lignes
  - SceneAntreMerlin: 16 lignes (3 narration + 2 Merlin/Bestiole + 4 mission + 1 carte + 4 classes + 2 reactions)
  - TransitionBiome: 14 lignes (7 arrivees + 7 commentaires)

### Agent Utilise
- Narrative Writer (narrative_writer.md)

---

## Phase 10b: Localisation Japonaise — Scene Dialogues (2026-02-08)

### Objectif
Creer la traduction japonaise du fichier de dialogues des scenes.

### Sous-phases
- [x] 10b.1 Lecture du fichier original `data/dialogues/scene_dialogues.json`
- [x] 10b.2 Traduction des champs `text` et `direction` en japonais naturel
- [x] 10b.3 Conservation structure JSON, IDs, timing, emotion, tags, vfx, sfx, ambiance
- [x] 10b.4 Respect du style Merlin: da/de aru (だ/である), pas desu/masu
- [x] 10b.5 Noms propres: Broceliande=ブロセリアンド, Bestiole=ベスティオル, Oghams=オガム, Awen=アウェン
- [x] 10b.6 Voyageur=旅人, traduction `nom`/`sous_titre` dans transition_biome
- [x] 10b.7 Creation fichier `data/dialogues/scene_dialogues_ja.json`

### Output
- `data/dialogues/scene_dialogues_ja.json` — 32 lignes de dialogue (identique structure)

### Agent Utilise
- Localisation Agent (localisation.md)

---

## Phase 11: Redesign 3 Scenes — Style Parchemin Breton (2026-02-08)

### Objectif
Reecrire les 3 scenes narratives (SceneEveil, SceneAntreMerlin, IntroMerlinDialogue) pour adopter le **style "parchemin mystique breton"** identique au MenuPrincipal — carte centree, portrait Merlin, ornements celtiques, shader parchemin, enchainement automatique.

### Design Unifie
- **Background**: Shader `reigns_paper.gdshader` avec teinte parchemin
- **Carte centrale**: PanelContainer avec style parchemin chaud, ombre douce
- **Portrait Merlin**: TextureRect dans la carte, saisonnier
- **Texte**: Typewriter avec MorrisRomanBlack, couleur encre brune
- **Ornements**: Lignes celtiques haut/bas avec Unicode pattern
- **Brume**: ColorRect avec animation respiration douce
- **Audio**: SFX click/hover + blips typewriter

### Sous-phases
- [ ] 11.1 Reecrire SceneEveil.gd — Parchemin + carte portrait + typewriter
- [ ] 11.2 Reecrire SceneAntreMerlin.gd — Parchemin + 5 phases sequentielles
- [ ] 11.3 Reecrire IntroMerlinDialogue.gd — Parchemin + questionnaire en carte
- [ ] 11.4 Validation validate.bat
- [ ] 11.5 Update progress.md

### Agents Invoques
| Agent | Role |
|-------|------|
| Art Direction | Style parchemin, palette, cohesion |
| UI Implementation | Code GDScript des 3 scenes |
| Motion Designer | Animations entree/sortie/typewriter |
| Lead Godot | Review code |
| Debug/QA | Validation |

---

## Phase 13: Art Direction Audit — Coherence Visuelle (2026-02-08)

### Objectif
Audit visuel complet et documentation de la charte graphique. Identifier toutes les inconsistances visuelles entre scenes, shaders, palettes, typographies, animations.

### Sous-phases
- [x] 13.1 Lecture charte existante (VISUAL_SPEC, palettes, shaders, art_direction.md)
- [x] 13.2 Audit palette par scene (14+ fichiers GDScript)
- [x] 13.3 Audit typographie (fonts, tailles, fallback chains)
- [x] 13.4 Audit shaders (parametres paper, mood profiles, snow)
- [x] 13.5 Audit animations (timings, easing, mist, typewriter)
- [x] 13.6 Audit ornements celtiques
- [x] 13.7 Audit scenes gameplay (TriadeGameUI, ReignsGameUI)
- [x] 13.8 Audit couleurs biomes vs VISUAL_SPEC
- [x] 13.9 Inventaire assets (fonts, portraits, audio, shaders)
- [x] 13.10 Production rapport complet

### Output
- `docs/70_graphic/ART_DIRECTION_AUDIT.md` — 684 lignes, 14 sections, 19 issues

### Agent Utilise
- Art Direction (art_direction.md)

### Findings
- 19 inconsistances (4 P1 critiques, 6 P2 importants, 6 P3 nice-to-have)
- TriadeGameUI et ReignsGameUI n'ont aucun style parchemin
- SceneAntreMerlin manque la variante cave shader
- 4/7 biome colors incorrects dans SceneAntreMerlin
- Recommandation: MerlinVisual autoload pour palette partagee

---

## Phase 14: Design Complet Bestiole & Roue d'Oghams (2026-02-08)

### Objectif
Design complet du systeme Bestiole et de la Roue d'Oghams (Ogham Wheel) pour le gameplay Triade. Includes: apparence, animations, Bond system, Souffle d'Awen, Roue d'interaction, 18 Oghams avec specs completes, equilibrage, et specs GDScript.

### Sous-phases
- [x] 14.1 Lecture documentation existante (10+ documents)
  - DOC_11_Card_System.md (bestiole_can_help)
  - COSMOLOGIE_CACHEE.md (verite sur Bestiole = fragment Awen)
  - MERLIN_COMPLETE_PERSONALITY.md (rapport Bestiole)
  - BESTIOLE_SYSTEM.md, BESTIOLE_FORMS.md, BESTIOLE_UI.md, BESTIOLE_TRAITS.md
  - merlin_constants.gd (18 Oghams existants, Bond tiers)
  - merlin_store.gd (state structure bestiole)
  - CELTIC_FOUNDATION.md (Ogham authentique, 25 feda)
  - DOC_12_Triade_Gameplay_System.md (3 aspects, Souffle d'Ogham)
- [x] 14.2 Design Bestiole dans le jeu
  - Position UI (bas gauche), icone 64x64 pixel art
  - 8 animations (idle, content, alerte, triste, skill actif, cooldown, bond up, sommeil)
  - Expressions par Bond tier (5 niveaux)
  - Moments d'interaction (avant choix, entre cartes, fin de run)
- [x] 14.3 Design Bond system
  - 5 tiers (Etranger, Curieux, Compagnon, Lie, Ame soeur)
  - Gains/pertes par action, meta-progression entre runs
  - Starters toujours actifs + slots supplementaires par tier
- [x] 14.4 Design Souffle d'Awen (nouvelle ressource separee du Souffle d'Ogham)
  - Max 5, depart 2, regen 1/5 cartes (+1 bonus si equilibre)
  - Couts: 1 (starters), 2 (standard), 3 (puissants)
  - Justification de la separation des deux systemes de Souffle
- [x] 14.5 Design Roue d'Oghams
  - Ouverture: tap Bestiole (mobile), clic/Tab (PC)
  - Layout: 3 cercles (centre=Bestiole, interieur=3 starters, exterieur=4 equipes)
  - Selection: tap -> preview -> confirm -> animation -> application
  - Feedback: 5 phases d'animation (selection, canalisation, eclatement, application, retour)
  - Gestion verrous: Bond tier unlock, achievement unlock, narrative unlock
  - Ecran de gestion inter-run (equipement d'Oghams)
- [x] 14.6 Design 18 Oghams complets adaptes au Triade
  - Pour chaque: nom, arbre, Unicode, categorie, cout Awen, cooldown, effet, deblocage, synergie cachee
  - 3 Starters: beith (reveal), luis (protection), quert (recovery)
  - 15 Advanced: coll, ailm, gort, eadhadh, duir, tinne, onn, nuin, huath, straif, ruis, saille, muin, ioho, ur
  - Effets adaptes aux 3 etats discrets (pas de pourcentages sur jauges)
- [x] 14.7 Equilibrage vs Triade
  - Matrice situations critiques / Oghams recommandes
  - Courbe de puissance par Bond tier
  - Frequence d'utilisation cible (6-10/run)
  - Regles anti-abus (1/carte, cooldowns, cap Awen)
  - Knobs d'equilibrage documentes
- [x] 14.8 Specs GDScript
  - OGHAM_FULL_SPECS constant (18 entries avec toutes proprietes)
  - Bestiole state structure pour merlin_store
  - Fonctions: can_use_ogham, activate_ogham, tick_cooldowns, regenerate_awen
  - Signals: bond_tier_changed, awen_changed, ogham_activated, etc.
  - Integration contexte LLM

### Output
- `docs/60_companion/BESTIOLE_OGHAM_WHEEL_DESIGN.md` — Design complet (~900 lignes)

### Agent Utilise
- Game Designer (game_designer.md)

### Decisions Design
| Element | Decision |
|---------|----------|
| Ressource Oghams | Souffle d'Awen (SEPAREE du Souffle d'Ogham) |
| Interaction | Tap Bestiole -> Roue -> Selection -> Confirmation |
| Layout Roue | 3 anneaux (Bestiole, Starters, Equipes) |
| Max Oghams/carte | 1 seul |
| Starters | Toujours actifs, cout 1, pas d'equip requis |
| Bond meta-progression | Persiste entre runs (min 50% + 10) |
| Synergies | Cachees, revelees par Merlin progressivement |
| Effets adaptes Triade | Shifts d'etat discrets (pas de pourcentages jauges) |

---

## Phase 12: AUDIT COMPLET — Backlog Prioritise (2026-02-08)

### Objectif
Audit exhaustif de l'ecart entre documentation/design et implementation reelle. Production d'un backlog priorise avec estimations de complexite.

### Methodologie
- Analyse de 30+ documents de design (50_lore, 20_card_system, 40_world_rules, 60_companion)
- Inventaire complet des scripts GDScript (55+ fichiers) et scenes (19 .tscn)
- Cross-reference code vs documentation sur chaque systeme

---

### ETAT DES LIEUX — Ce Qui Existe

#### IMPLEMENTE ET FONCTIONNEL
| Systeme | Fichier(s) | Etat |
|---------|------------|------|
| MerlinStore (state Redux) | `scripts/merlin/merlin_store.gd` v0.3.0 | Triade system integre |
| MerlinCardSystem | `scripts/merlin/merlin_card_system.gd` v0.3.0 | Fallback cards, legacy + Triade |
| MerlinEffectEngine | `scripts/merlin/merlin_effect_engine.gd` | SHIFT_ASPECT, SOUFFLE, KARMA, PROMISE |
| MerlinLlmAdapter | `scripts/merlin/merlin_llm_adapter.gd` v2.0 | Context building, whitelist, validation |
| MerlinConstants | `scripts/merlin/merlin_constants.gd` | 18 Oghams definis, 12 endings, 3 victoires |
| MerlinSaveSystem | `scripts/merlin/merlin_save_system.gd` | 3 slots JSON |
| TriadeGameUI | `scripts/ui/triade_game_ui.gd` v0.3.0 | 3 aspects, 3 options, souffle |
| TriadeGameController | `scripts/ui/triade_game_controller.gd` v0.3.0 | Store-UI bridge, run flow |
| ReignsGameUI (legacy) | `scripts/ui/reigns_game_ui.gd` | 4 jauges, swipe, skills |
| MerlinOmniscient (MOS) | `addons/merlin_ai/merlin_omniscient.gd` | Orchestrateur IA complet |
| Registries IA | `addons/merlin_ai/registries/` (5 fichiers) | Player, Decision, Relationship, Narrative, Session |
| Processors IA | `addons/merlin_ai/processors/` (3 fichiers) | Difficulty, Narrative, Tone |
| FallbackPool | `addons/merlin_ai/generators/fallback_pool.gd` | Pool contextuel |
| LLMClient | `addons/merlin_ai/llm_client.gd` | GDExtension MerlinLLM |
| LLMManager | `scripts/LLMManager.gd` | Autoload, retry, status |
| GameManager | `scripts/game_manager.gd` v7.0 | Legacy state + GBC palette |
| Scenes Intro | IntroBoot, IntroCeltOS, IntroMerlinDialogue | Flow complet intro -> questionnaire |
| Scenes Narratives | SceneEveil, SceneAntreMerlin, TransitionBiome | Style parchemin, dialogues JSON |
| Menu Principal | MenuPrincipalReigns.gd | Saisonnalite, heure du jour, effets meteo |
| ScreenEffects | `scripts/autoload/ScreenEffects.gd` | Moods, shaders |
| LocaleManager | `scripts/autoload/LocaleManager.gd` | i18n 7 langues |
| Dialogues i18n | `data/dialogues/` + `data/` | FR, EN, ES, IT, PT, ZH, JA |

#### PARTIELLEMENT IMPLEMENTE (infra existe, logique incomplete)
| Systeme | Ce qui existe | Ce qui manque |
|---------|---------------|---------------|
| Promise System | CREATE/FULFILL/BREAK dans effect_engine | Pas de deadline check, pas de consequences auto |
| Hidden Resources (karma) | Compteur karma dans store | Pas utilise pour influencer cartes/narration |
| Triade Endings (12 chutes) | Constantes definies, check double-extreme | Narration de fin, ecran de fin, animation |
| Victory Endings (3) | Constantes definies | Pas de mission system pour trigger victoire |
| Bestiole Bond | MODIFY_BOND effect, bond tiers definis | Pas de UI bond, pas de decay, pas de care loop |
| Skill Cooldowns | SET_SKILL_COOLDOWN effect | Pas d'activation skill en gameplay |

---

### BACKLOG PRIORISE

---

#### P0 — CRITIQUE (Core Loop Jouable)

| # | Item | Description | Complexite | Dependances | Agent(s) |
|---|------|-------------|-----------|-------------|----------|
| P0.1 | **Connecter LLM a Triade** | Le LLM Adapter genere encore des cartes 2-options (Reigns). Adapter pour generer des cartes 3-options Triade avec SHIFT_ASPECT. Mettre a jour le system prompt, la whitelist, la validation. | L | - | llm_expert, lead_godot |
| P0.2 | **Fallback Cards Triade (50+)** | Actuellement ~10 cartes Triade fallback. En ecrire 50+ avec effets equilibres, 3 options, labels courts. Couvrir: early/mid/late, 7 biomes, crises. | L | - | narrative_writer, game_designer |
| P0.3 | **Mission System** | Generer une mission par run (objectif a accomplir en 25-35 cartes). Le LLM propose, fallback pool si LLM absent. PROGRESS_MISSION effect. Victoire si mission accomplie. | L | P0.1 | game_designer, lead_godot |
| P0.4 | **Ecran de Fin de Run** | Quand 2 aspects extremes ou mission accomplie: afficher narration de fin (12 chutes + 3 victoires), texte Merlin, score, bouton Rejouer/Menu. | M | P0.3 | ui_impl, narrative_writer |
| P0.5 | **Boucle Complete** | Enchainer: Menu -> Intro -> Eveil -> Antre -> Biome -> TriadeGame -> Fin -> Menu. Tester le flow complet. S'assurer qu'on peut jouer 5 parties d'affillee sans crash. | M | P0.1-P0.4 | debug_qa, lead_godot |

**Effort total P0: ~3-4 semaines**

---

#### P1 — IMPORTANT (Features Essentielles au Gameplay)

| # | Item | Description | Complexite | Dependances | Agent(s) |
|---|------|-------------|-----------|-------------|----------|
| P1.1 | **Ogham Skills Actifs** | Implementer `activate_skill(skill_id)` dans MerlinCardSystem. Appliquer les 18 effets (reveal, protection, boost, narrative, recovery, special). UI: boutons skill sur TriadeGameUI. Cooldown tracking. | XL | P0.5 | lead_godot, game_designer |
| P1.2 | **Bestiole Care Loop** | Needs decay (hunger, energy, mood, cleanliness). Care actions entre runs. Impact sur modifiers et skill dispo. UI panel Bestiole minimaliste. | L | P1.1 | ui_impl, game_designer |
| P1.3 | **Biome Modifiers** | Quand biome selectionne dans SceneAntreMerlin, appliquer les modificateurs (ex: Broceliande = +Ame, -Corps). Palette couleurs par biome dans TriadeGameUI. Cartes specifiques biome. | M | P0.2, P0.5 | lead_godot, art_direction |
| P1.4 | **Hidden Depth: Resonances** | Implementer les resonances (2-3 aspects meme etat = effet cache). Harmonie Interieure, Fievre Mystique, Triade Parfaite, etc. Merlin commente apres 5+ runs. | M | P0.5 | lead_godot, game_designer |
| P1.5 | **Systeme de Twists** | 5 types de retournements (Revelation, Trahison, Miracle, Catastrophe, Deus Ex). Probabilite = tension_narrative / 100. Injection dans le flux de cartes. | M | P0.1, P0.5 | lead_godot, narrative_writer |
| P1.6 | **Saison / Calendrier** | Cycle saisonnier pendant la run (affecte biomes, evenements, cartes). 8 festivals celtiques. Impact sur ambiance et gameplay. | M | P1.3 | game_designer, lead_godot |
| P1.7 | **Merlin Voice (Typewriter + Blips)** | Voix procedural Merlin pendant le gameplay Triade. Typewriter + blips sur les narrations de carte. Integration ACVoicebox/RobotBlipVoice. | M | P0.5 | audio_designer, lead_godot |
| P1.8 | **Promise System Complet** | Deadline tracking (compteur de cartes). Consequence auto si promesse brisee (karma, effects). Carte de rappel Merlin quand deadline approche. | S | P0.5 | lead_godot, game_designer |
| P1.9 | **Hidden Depth: Player Profile** | Tracking audace/altruisme/spirituel. Influence la selection de cartes (profil audacieux = plus de cartes risquees). Merlin commente le style. | M | P0.5, P1.5 | lead_godot, game_designer |
| P1.10 | **Fin Secrete** | Condition: Bond >= 95, Trust T3, toutes fins vues, 100+ runs. Sequence speciale ou Merlin revele M.E.R.L.I.N. | S | P1.1, P1.2, P2.1 | narrative_writer, lead_godot |

**Effort total P1: ~6-8 semaines**

---

#### P2 — NICE-TO-HAVE (Polish, Effets, Contenu)

| # | Item | Description | Complexite | Dependances | Agent(s) |
|---|------|-------------|-----------|-------------|----------|
| P2.1 | **Meta-Progression (Inter-Run)** | Sauvegarder: fins vues, runs total, oghams debloques, trust tier, bond max. Unlocks progressifs. Score persistant. | L | P0.5, P1.1 | lead_godot, game_designer |
| P2.2 | **Audio Procedural Ambiance** | Implementer les 13 sons proceduraux des 3 scenes (cave drone, heartbeat, fire, drips, etc.) selon `AUDIO_DESIGN_3_SCENES.md`. | L | P0.5 | audio_designer, lead_godot |
| P2.3 | **Animations Carte Triade** | Swipe animation, card flip, aspect shift pulse, souffle consume VFX. Easing et juice. | M | P0.5 | motion_designer, ui_impl |
| P2.4 | **Phase 11: Redesign Parchemin** | Finaliser le redesign des 3 scenes intro (SceneEveil, SceneAntreMerlin, IntroMerlinDialogue) avec style parchemin complet. | M | P0.5 | art_direction, ui_impl |
| P2.5 | **Narratives Merlin par Contexte** | Voice lines Merlin contextuelles (debut/milieu/fin de run, par biome, par etat d'aspect). 80+ lignes documentees dans MERLIN_COMPLETE_PERSONALITY.md. | M | P0.2, P1.7 | narrative_writer, audio_designer |
| P2.6 | **PNJ et Factions** | 5 factions (Druides, Korrigans, Humains, Anciens, Ankou). Reputation cachee. Cartes faction-specifiques. PNJ recurrents. | L | P0.2, P1.5 | narrative_writer, game_designer |
| P2.7 | **Indices Lore Progressifs** | Systeme d'indices cumulatifs (Run 1-5, 6-15, 16-30, 31+). Integration des 6 metaphores recurrentes. Merlin laisse echapper des indices selon trust tier. | M | P2.1, P1.10 | narrative_writer, lead_godot |
| P2.8 | **Tutorial Implicite** | Premieres 3-5 cartes d'une premiere partie = tutoriel doux. Merlin explique les bases sans etre lourd. Grace period (pas de mort possible). | S | P0.5 | ux_research, game_designer |
| P2.9 | **Scene Collection / Grimoire** | Scene pour consulter: oghams debloques, fins vues, fragments de lore, stats. Style parchemin. | M | P2.1 | ui_impl, art_direction |
| P2.10 | **Shaders Biomes** | 7 shaders d'ambiance par biome (brume Broceliande, vent Landes, vagues Cotes, etc.). Integration avec TriadeGameUI. | M | P1.3 | shader_specialist |

**Effort total P2: ~6-8 semaines**

---

#### P3 — FUTUR (Post-MVP, Multi-Run, Easter Eggs)

| # | Item | Description | Complexite | Dependances | Agent(s) |
|---|------|-------------|-----------|-------------|----------|
| P3.1 | **Ogham Synergies** | Combos entre oghams (ex: Beith+Luis = bonus special). Couche de profondeur cachee. | M | P1.1 | game_designer |
| P3.2 | **Inter-Run Echoes** | Traces de runs precedentes (PNJ se souvient, lieux changes). Persistence narrative. | L | P2.1 | narrative_writer, lead_godot |
| P3.3 | **Lunar Cycles** | Cycle lunaire reel affectant le gameplay. Pleine lune = evenements speciaux. | S | P1.6 | game_designer |
| P3.4 | **Bestiole Personality** | Bestiole developpe une personnalite basee sur les choix du joueur. Reactions uniques. | M | P1.2 | game_designer, narrative_writer |
| P3.5 | **Hub Entre Runs** | Scene hub avec: Bestiole care, grimoire, arbre oghams, carte biomes. | L | P1.2, P2.9 | ui_impl, art_direction |
| P3.6 | **Easter Egg 1000 Runs** | Message special de Merlin remerciant le joueur. "Merci d'avoir joue." | S | P2.1 | narrative_writer |
| P3.7 | **Narrative Debt System** | Dettes narratives (promesses, trahisons) qui reviennent dans les runs futures. | M | P1.8, P3.2 | game_designer, lead_godot |
| P3.8 | **A/B Testing Framework** | Metriques de gameplay, analytics, telemetrie. Optimisation des parametres. | L | P0.5 | data_analyst, lead_godot |
| P3.9 | **Mode Defi Quotidien** | Seed du jour, classement, conditions speciales. | M | P2.1 | game_designer |
| P3.10 | **Export Mobile** | Build Android/iOS. Adaptation touch, performance, taille. | XL | P0.5 | mobile_touch_expert, lead_godot |

**Effort total P3: ~8-12 semaines**

---

### GRAPHE DE DEPENDANCES PRINCIPAL

```
P0.1 (LLM Triade) ──────────┐
P0.2 (Fallback 50+) ────────┤
P0.3 (Mission System) ──────┼──> P0.5 (Boucle Complete) ──> P1.x, P2.x
P0.4 (Ecran Fin) ───────────┘
                                       │
                    ┌──────────────────┤
                    │                  │
               P1.1 (Oghams)    P1.3 (Biomes)
                    │                  │
               P1.2 (Bestiole)  P1.6 (Saisons)
                    │                  │
               P2.1 (Meta)      P2.10 (Shaders)
                    │
               P1.10 (Fin Secrete)
                    │
               P3.2 (Echoes)
```

---

### ESTIMATION GLOBALE

| Priorite | Items | Effort Estime | Prerequis |
|----------|-------|---------------|-----------|
| **P0** | 5 items | 3-4 semaines | Rien (depart immediat) |
| **P1** | 10 items | 6-8 semaines | P0 complet |
| **P2** | 10 items | 6-8 semaines | P0 complet, certains P1 |
| **P3** | 10 items | 8-12 semaines | P0+P1 complet |
| **TOTAL** | 35 items | ~23-32 semaines | - |

### RECOMMANDATION DE SEQUENCEMENT

**Sprint 1 (sem 1-2):** P0.1 + P0.2 en parallele
**Sprint 2 (sem 3-4):** P0.3 + P0.4 + P0.5
**Sprint 3 (sem 5-6):** P1.1 (Oghams) + P1.3 (Biomes)
**Sprint 4 (sem 7-8):** P1.4 (Resonances) + P1.5 (Twists) + P1.7 (Voice)
**Sprint 5 (sem 9-10):** P1.2 (Bestiole) + P1.8 (Promises) + P2.3 (Animations)
**Sprint 6+:** P2.x selon priorite utilisateur

---

## Phase 14: Bestiole Tool Wheel — Recherche & Spec UI (2026-02-08)

### Objectif
Rechercher et specifier l'architecture UI de la roue d'outils Bestiole (Oghams radial menu) pour le systeme Triade.

### Analyse Effectuee
1. **UI existante Triade** (`triade_game_ui.gd`): layout VBox, signal `skill_activated` existe mais rien ne l'emet
2. **UI legacy Reigns** (`reigns_game_ui.gd` + `ReignsGame.tscn`): BestiolePanel en bas avec skill buttons plats
3. **Theme** (`reigns_theme.tres`): palette parchemin, MorrisRomanBlackAlt, accent bordeaux
4. **Store** (`merlin_store.gd`): 18 OGHAM_SKILLS definis, 6 categories, bond tiers, cooldowns

### Decisions Architecture

| Element | Decision |
|---------|----------|
| Pattern | **Radial menu (roue)** — pas liste plate |
| Layout | **6 secteurs x 3 items** = 18 Oghams |
| Position icone | **Bas-droite**, 56x56px |
| Ouverture | **Tap ou long-press** (250ms) |
| Overlay | **CanvasLayer layer=10** + dim background |
| Pause | **Visuelle uniquement** (pas get_tree().paused) |
| Responsive | Radius 140px mobile / 180px desktop |
| Categorie couleurs | Bleu/Vert/Or/Violet/Rose/Rouge |

### Sous-phases
- [x] 14.1 Analyse UI existante (4 fichiers GDScript + 1 scene + 1 theme)
- [x] 14.2 Recherche patterns radial menu Godot 4
- [x] 14.3 Recherche UX tactile (Fitts law, touch best practices)
- [x] 14.4 Production spec complete `BESTIOLE_TOOL_WHEEL_SPEC.md`

### Output
- `docs/60_companion/BESTIOLE_TOOL_WHEEL_SPEC.md` (450+ lignes)
  - Section 1: Analyse UI existante
  - Section 2: Recherche patterns (radial menu, Godot 4, UX tactile)
  - Section 3: Architecture UI proposee (position, layout, etats, animations)
  - Section 4: Plan implementation technique (node tree, code indicatif ~300 LOC, responsive, pause)
  - Section 5: Plan en 5 phases (~6 jours)
  - Section 6: Alternatives rejetees (5)
  - Section 7: Questions ouvertes (5)

### Agents Invoques
| Agent | Role |
|-------|------|
| UI Implementation | Analyse UI, code indicatif, node tree |

### Relation au Backlog
- Correspond a **P1.1** (Ogham Skills Actifs) dans le backlog Phase 12
- Pre-requis: P0.5 (Boucle Complete)
- Le code indicatif dans la spec est pret a etre implemente quand P0 est termine
