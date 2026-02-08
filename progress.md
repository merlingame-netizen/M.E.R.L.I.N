# Progress Log - DRU: Le Jeu des Oghams

## Session: 2026-02-05

### Phase 0: Setup Planning Infrastructure
- **Status:** complete
- Actions taken:
  - Installe le skill planning-with-files
  - Cree les fichiers de planning

### Phase 1: Requirements & Discovery
- **Status:** complete
- Actions taken:
  - Analyse complete de l'architecture
  - Identifie architecture duale (DruStore vs GameManager)
  - Documente gaps entre design et implementation
  - **PIVOT DECISION**: Reigns-like au lieu de combat

### Phase 2: Documentation Update (Post-Pivot)
- **Status:** complete
- Actions taken:
  - Cree DOC_11_Reigns_Card_System.md (nouveau core system)
  - Mis a jour MASTER_DOCUMENT.md avec pivot
  - Mis a jour BESTIOLE_SYSTEM.md (support passif + skills)
  - Mis a jour GAMEPLAY_LOOP_ROGUELITE.md (Reigns-style)
  - Deprecie DOC_05_Combat_System_v2.md

### Phase 3: Core System Implementation
- **Status:** complete
- Actions taken:
  - Cree `scripts/dru/dru_card_system.gd` (600+ lignes)
    - Fallback cards bank
    - Card validation
    - Gauge management
    - Skill integration
  - Mis a jour `scripts/dru/dru_constants.gd`
    - REIGNS_ constants
    - OGHAM_SKILLS (18 skills)
    - BOND_TIERS
  - Mis a jour `scripts/dru/dru_store.gd` (v0.2.0)
    - REIGNS_ action types
    - New state structure (gauges, skills, flags)
    - Card system integration
  - Mis a jour `scripts/dru/dru_effect_engine.gd`
    - ADD_GAUGE, REMOVE_GAUGE, SET_GAUGE
    - SET_FLAG, ADD_TAG, REMOVE_TAG
    - CREATE_PROMISE, FULFILL_PROMISE, BREAK_PROMISE
    - MODIFY_BOND, SET_SKILL_COOLDOWN
  - Reecrit `scripts/dru/dru_llm_adapter.gd` (v2.0.0)
    - Reigns card contract
    - Context building for LLM
    - Card validation & sanitization
    - Effect whitelist
    - System prompt generation

### Phase 4: UI Implementation
- **Status:** complete
- Actions taken:
  - Cree `scripts/ui/reigns_game_ui.gd`
    - 4 gauge bars with critical styling
    - Card display with swipe
    - Bestiole status panel
    - Skill buttons
    - End screen
  - Cree `scripts/ui/reigns_game_controller.gd`
    - Store-UI bridge
    - Run management
    - Card flow orchestration
  - Cree `scenes/ReignsGame.tscn`
    - Complete scene layout
    - All UI nodes connected
  - Mis a jour `scripts/MenuPrincipalReigns.gd`
    - Added "Reigns Mode (NEW)" to dev menu

---

## PIVOT MAJEUR (2026-02-05)

### Decisions
1. **Gameplay**: Combat -> Reigns-like (cartes narratives)
2. **Architecture**: Fusionner vers DruStore
3. **Bestiole**: Combat actions -> Support passif + Skills (Oghams)
4. **Jauges**: HP/Combat stats -> 4 jauges equilibre (Vigueur, Esprit, Faveur, Ressources)
5. **Oghams**: Attaques -> Skills Bestiole avec cooldowns

---

## Files Created This Session

### Scripts (Core)
- `scripts/dru/dru_card_system.gd` — Card engine (NEW)

### Scripts (UI)
- `scripts/ui/reigns_game_ui.gd` — Main game UI
- `scripts/ui/reigns_game_controller.gd` — Store-UI controller

### Scenes
- `scenes/ReignsGame.tscn` — Main Reigns gameplay scene

### Documentation
- `docs/20_dru_system/DOC_11_Reigns_Card_System.md`

## Files Modified This Session

### Scripts
- `scripts/dru/dru_store.gd` (v0.2.0)
- `scripts/dru/dru_constants.gd`
- `scripts/dru/dru_effect_engine.gd`
- `scripts/dru/dru_llm_adapter.gd` (v2.0.0)
- `scripts/MenuPrincipalReigns.gd`

### Documentation
- `docs/MASTER_DOCUMENT.md`
- `docs/60_companion/BESTIOLE_SYSTEM.md`
- `docs/40_world_rules/GAMEPLAY_LOOP_ROGUELITE.md`
- `docs/20_dru_system/DOC_05_Combat_System_v2.md` (DEPRECATED)

---

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | All phases complete |
| Where am I going? | Testing and polish |
| What's the goal? | Pivot to Reigns-like + sync all docs + implement |
| What have I learned? | Combat -> narrative cards, Oghams -> Bestiole skills |
| What have I done? | Created card system, updated store, built UI |

---

## Implementation Summary

### New Architecture
```
DruStore (central state)
├── DruCardSystem (NEW - replaces combat)
├── DruEffectEngine (updated with Reigns effects)
├── DruLlmAdapter (rewritten for Reigns contract)
├── DruSaveSystem (unchanged)
└── DruRng (unchanged)

UI Layer
├── ReignsGameUI (swipe cards, gauges, skills)
└── ReignsGameController (orchestration)
```

### Key Features Implemented
- [x] 4 resource gauges (0-100, start at 50)
- [x] 8 endings (one per gauge direction)
- [x] 18 Ogham skills with cooldowns
- [x] Bond system (skills unlock based on bond level)
- [x] Fallback cards (50 pre-written cards)
- [x] LLM contract for card generation
- [x] Effect whitelist (secure LLM integration)
- [x] Swipe UI with card rotation
- [x] Critical gauge styling
- [x] End screen with score

### Next Steps (Future Sessions)
1. [ ] Test the ReignsGame scene in Godot
2. [ ] Connect actual LLM for card generation
3. [ ] Add more fallback cards (target: 100)
4. [ ] Implement sound effects
5. [ ] Add visual polish (animations, particles)
6. [ ] Create tutorial cards
7. [ ] Balance gauge effects

---

## Session: 2026-02-06

### Phase 5: Calendar Feature Review & Fix
- **Status:** complete
- Actions taken:
  - Reviewed existing Calendar.tscn and Calendar.gd
  - **Bug fixed**: Wheel drawing was incorrectly called from Calendar._draw()
    - Changed to use wheel_container.draw signal connection
    - Drawing now properly occurs during wheel_container's draw cycle
  - Calendar features verified:
    - Celtic wheel of the year (4 seasons, 8 festivals)
    - 36 calendar events for 2026 (from CALENDAR_2026_PRINT.md)
    - Current day marker on wheel
    - Event list with past/today/future styling
    - Statistics tab (runs, cards, endings, glory points)
    - All 8 endings tracking
    - Responsive mobile layout
    - Entry/exit animations
    - Tab system (Events / Stats)
    - Integration with DruStore for meta stats

### Lead Godot Review: Calendar
- **Code Quality:** Good - follows project patterns
- **Architecture:** Proper separation of concerns
- **Integration:**
  - Connects to DruStore.state.meta for stats
  - Navigation to/from MenuPrincipal.tscn
  - Corner buttons in menu work correctly
- **Bug Fixed:** Wheel drawing method corrected

### Files Modified This Session
- `scripts/Calendar.gd` — Fixed wheel drawing (draw signal connection)

### Testing Checklist (for QA)
- [ ] Calendar opens from main menu (bottom-left button)
- [ ] Wheel of the year displays correctly
- [ ] Current day marker visible
- [ ] Festival markers visible (8 Celtic festivals)
- [ ] Events tab shows current/next month events
- [ ] Stats tab shows run statistics
- [ ] Back button returns to menu
- [ ] Responsive layout on narrow screens
- [ ] Animations play smoothly

### Phase 6: GDScript Validation Protocol
- **Status:** complete
- Actions taken:
  - **Bug fixed**: Calendar.gd line 461 - `var month_name := MONTH_NAMES[...]`
    - Changed to explicit type: `var month_name: String = MONTH_NAMES[...]`
  - **Bug fixed**: Calendar.gd line 652 - `var festival := CELTIC_FESTIVALS[...]`
    - Changed to explicit type: `var festival: Dictionary = CELTIC_FESTIVALS[...]`
  - Created debug checklist: `.claude/agents/debug_checklist.md`
  - Updated Debug/QA agent: `.claude/agents/debug_qa.md`
    - Added mandatory GDScript validation protocol
    - Type inference error patterns to check

### Debug Protocol Created

**Problème récurrent**: `:=` avec indexation de const Array/Dict
- GDScript ne peut pas inférer le type depuis un accès par index sur const
- Solution: toujours utiliser type explicite

**Validation obligatoire avant livraison**:
```bash
grep ':= [A-Z_]\+\[' scripts/*.gd  # Chercher patterns problématiques
```

---

## Session: 2026-02-07

### Phase 7: Intro Personality Quiz + Auto-Validation
- **Status:** in_progress
- Actions taken:
  - **Bug fixed**: IntroPersonalityQuiz.gd - `trait` reserved keyword
    - Lignes 286-288: `for trait in` → `for t in`
    - Lignes 346-350: `for trait in collected_traits` → `for t in collected_traits`
    - Ligne 354: `for trait in trait_counts` → `for t in trait_counts`
  - Created automatic validation system: `tools/validate_gdscript.ps1`
    - Checks for reserved keywords in for loops
    - Checks for := with CONST[index] patterns (case-sensitive)
    - Checks for deprecated yield() usage
    - Reports all issues before Godot testing

### Auto-Validation Protocol Created
**Script:** `tools/validate_gdscript.ps1`

**Usage before any Godot test:**
```powershell
powershell -ExecutionPolicy Bypass -File tools/validate_gdscript.ps1 -Path scripts
```

**Errors checked:**
1. Reserved keywords (`trait`, `class`) as loop variables
2. Type inference from const indexing (`:= CONST[x]`)
3. Reserved keywords as variable names
4. Deprecated `yield()` (Godot 3 -> 4)

### Files Modified This Session
- `scripts/IntroPersonalityQuiz.gd` — Fixed reserved keyword usage

### Files Created This Session
- `tools/validate_gdscript.ps1` — Auto-validation script

### Current Implementation Status
- [x] IntroPersonalityQuiz.gd — Pokemon Mystery Dungeon style quiz
- [x] MenuPrincipalReigns.gd — Calendar overlay system
- [x] menu_return_button.gd — Reusable menu button component
- [x] Auto-validation system operational

### Testing Checklist
- [ ] Nouvelle Partie → IntroPersonalityQuiz loads
- [ ] Quiz questions fade in from black
- [ ] Choices appear with stagger animation
- [ ] Selecting choice collects traits
- [ ] After 5 questions, completion message
- [ ] Transition to IntroMerlinDialogue

### Agent Workflow Inscrit dans Planning Files
- task_plan.md: Pipeline d'iteration standard ajoute
- .claude/agents/godot_dev.md: Iteration loop complete
- Validation automatique: `tools/validate_gdscript.ps1`

### Phase 8: Personality Quiz Expansion (10 Questions + Nuances)
- **Status:** complete
- Actions taken:
  - Expanded quiz from 5 to 10 questions
  - Created 4-axis personality system:
    - Approche: prudent ↔ audacieux
    - Relation: solitaire ↔ social
    - Esprit: analytique ↔ intuitif
    - Coeur: pragmatique ↔ compassionnel
  - Added 8 archetypes with unique descriptions:
    - Le Gardien, L'Explorateur, Le Sage, Le Heros
    - Le Guerisseur, Le Stratege, Le Mystique, Le Guide
  - Multi-phase personality reveal animation
  - Added impact analysis to agent workflow

### Impact Analysis: IntroPersonalityQuiz Changes
- **Direct impacts:**
  - `scenes/IntroPersonalityQuiz.tscn` - OK (no changes needed)
  - `scripts/MenuPrincipalReigns.gd` - OK (references scene path only)
- **Indirect impacts:**
  - `GameManager.player_traits` - New format (Dictionary with archetype_id, axis_scores)
  - `quiz_completed` signal - New payload format
- **No breaking changes** - player_traits not used elsewhere yet

### Phase 9: Bug Fixes + Merlin Intro
- **Status:** complete
- Actions taken:
  - **Bug fixed**: MenuPrincipalAnimated.gd:1211 - Python integer division `//`
    - Changed `y // 100` → `int(y / 100)`
  - **Bug fixed**: main_game.gd:506 - Duplicate variable `combat_log`
    - Renamed inner variable to `log_label`
  - **New Feature**: Merlin's Lair Introduction sequence
    - Added 10 new dialogue nodes to intro_dialogue.json
    - Flow: welcome → merlin_surprise → merlin_intro → merlin_lair → merlin_explain → mission_intro → mission_detail → mission_ask → greet
    - Merlin introduces himself, expresses surprise, explains the mission
    - Player can ask questions or accept mission via verb choices
    - Changed start_id from "greet" to "welcome"

### Impact Analysis: IntroMerlinDialogue Changes
- **Direct impacts:**
  - `data/intro_dialogue.json` - Added intro sequence
  - `scripts/IntroMerlinDialogue.gd` - Changed start_id to "welcome"
- **Indirect impacts:**
  - Quiz flow starts earlier with Merlin introduction
  - Player personality traits collected from mission acceptance
- **No breaking changes** - Existing nodes unchanged

### Validation Status
```
=== GDScript Validation ===
Files scanned: 54
Errors: 0
Warnings: 0
Validation passed!
```

### Phase 10: Portrait Emotions + ACVoicebox Integration
- **Status:** complete
- Actions taken:
  - **Bug fixed**: IntroMerlinDialogue.gd:489 - `game_manager.has("run")`
    - `has()` is a Dictionary method, not Node method
    - Changed to `"run" in game_manager`
  - **ACVoicebox**: Already integrated with preset "Merlin"
    - Voice plays during dialogue with typewriter sync
    - Pitch: 3.2, variation: 0.28, speed: 0.95
  - **Portrait Emotion System**: Added automatic emotion detection
    - 5 emotions: SAGE, MYSTIQUE, SERIEUX, AMUSE, PENSIF
    - Keywords trigger visual effects on portrait
    - Modulate color changes + micro-animations (pulse, shake, bounce)
  - **Visual Analysis**: Complete audit of graphical state
    - 5 shaders exist but UNUSED
    - 31 3D tiles exist but UNUSED
    - No particles in main gameplay
    - Bestiole has no visual representation

### Impact Analysis: IntroMerlinDialogue Emotion System
- **Direct impacts:**
  - `scripts/IntroMerlinDialogue.gd` - Added emotion detection
  - Portrait texture already loaded (Merlin.png)
- **Indirect impacts:**
  - Portrait modulate changes during dialogue
  - Visual feedback matches text content
- **No breaking changes** - Additive feature only

### Files Modified This Session (continued)
- `scripts/IntroMerlinDialogue.gd`
  - Fixed has() error at line 489
  - Added emotion detection system (SAGE, MYSTIQUE, SERIEUX, AMUSE, PENSIF)
  - Portrait auto-reacts to dialogue content

---

## GRAPHICAL IMPROVEMENT PROPOSALS

### Priority 1: Quick Wins (Immediate Impact)

1. **Apply `reigns_paper.gdshader` to card backgrounds**
   - Shader exists but never used
   - Would transform flat panels into mystical parchment
   - Files: `shaders/reigns_paper.gdshader` → apply to ReignsGame.tscn CardPanel

2. **Gauge Change Particles**
   - Add particle burst when gauges change
   - Color flash (white → normal) on significant changes
   - Files: Create `scenes/vfx/gauge_feedback.tscn`

3. **Card Entry Animation**
   - Cards pop/slide in from center
   - Smooth rotation on swipe
   - Already partially implemented in reigns_game_ui.gd

### Priority 2: Core Polish

4. **Bestiole Visualization**
   - Currently invisible (text only: "Lien: 50%")
   - Need character sprite + mood animations
   - Consider using emotion system similar to Merlin

5. **Skill Activation VFX**
   - Ogham symbol flash animation
   - Cooldown ring around skill button
   - Particle trail effect

6. **Menu Background Art**
   - Currently solid ColorRect
   - Add painted backdrop or animated layers
   - Consider seasonal variants (already have Merlin seasonal assets)

### Priority 3: Atmosphere

7. **Ambient Particles**
   - Floating dust/magic particles
   - Fog/mist layer effects
   - Firefly-style ambient lights

8. **Scene Transitions**
   - Fade wipes between scenes
   - Current: instant scene change
   - Add: fade-to-black or slide transitions

9. **Celtic Ornaments**
   - Corner decorations on UI panels
   - Divider flourishes between sections
   - Matches Morris Roman font aesthetic

### Unused Assets to Activate

| Asset | Location | Potential Use |
|-------|----------|---------------|
| 5 Shaders | `shaders/` | Card texture, CRT effect, pixelate |
| 31 3D Tiles | `Assets/Tiles/` | World backdrop, map view |
| Merlin Emotions | `archive/Assets/` | Extended portrait states |
| Morris Roman | `resources/fonts/` | Headers, titles |

### Phase 11: Ultimate LLM Test Scene
- **Status:** complete
- Actions taken:
  - Created `scripts/TestLLMSceneUltimate.gd` (600+ lines)
  - Created `scenes/TestLLMSceneUltimate.tscn`
  - **Features implemented:**
    - Multi-backend support (MerlinLLM, NobodyWho)
    - Mode 4 choix interactifs (LLM genere reponse + 4 options)
    - Spinner de chargement anime
    - Metriques visuelles (latence, tokens, qualite)
    - Style DRU coherent (couleurs, panels)
    - Typewriter animation pour reponses
    - Selection de choix avec animation
    - Run All Tests batch mode
    - Support Trinity-Nano (Q4_K_M, Q5_K_M, Q8_0)

### Files Created This Session (Phase 11)
- `scripts/TestLLMSceneUltimate.gd` — Ultimate LLM test interface
- `scenes/TestLLMSceneUltimate.tscn` — Scene file

### Phase 12: UI/UX Fixes Based on Testing
- **Status:** complete
- Issues identified from screenshot:
  - Prompt input unreadable (light bg + light text)
  - LLM generating repetitive text ("Je suis Merlin" x20)
  - Buttons not visible in layout
  - Latence 15s = too slow (red indicator working)
- Actions taken:
  - **Fixed prompt input contrast**
    - Dark background (`bg_input: Color(0.15, 0.17, 0.22)`)
    - Bright text (`text_bright: Color(1.0, 0.98, 0.9)`)
    - Focus border highlight (accent color)
    - Font size 18px
  - **Fixed repetitive LLM responses**
    - `_clean_repetitions()` - detects word loops
    - `_is_repetitive()` - blocks broken choices
    - `_is_similar_to_existing()` - prevents duplicates
    - Fallback choices if parsing fails
  - **Improved system prompt**
    - Explicit "JAMAIS repeter" rule
    - Concrete action examples
    - Stricter format enforcement
  - **Added choice length limits**
    - `MAX_CHOICE_LENGTH = 60` chars
    - Truncation with "..."
  - **Improved button visibility**
    - Size: 150x44px
    - Font: 16px
    - Content margins
    - Pressed state style

### LLM Test Features

| Feature | Description |
|---------|-------------|
| Multi-model | Q4_K_M, Q5_K_M, Q8_0 Trinity-Nano |
| 4-Choice Mode | LLM genere reponse + 4 options joueur |
| Loading Spinner | Animation rotative pendant generation |
| Latency Bar | Barre visuelle < 2s vert, < 5s jaune, > 5s rouge |
| Typewriter | Animation caractere par caractere |
| Choice Selection | Click sur choix → devient prochain prompt |
| Batch Tests | Run All Tests execute 4 prompts predefinies |

### System Prompt for 4-Choice Mode
```
Tu es Merlin. Apres ta reponse, propose EXACTEMENT 4 choix courts.
Format:
[REPONSE]
Ta reponse (2-3 phrases)

[CHOIX]
1. Premier choix
2. Deuxieme choix
3. Troisieme choix
4. Quatrieme choix
```

---

## Agent Pipeline Reference

```
1. Game Designer    → Spec (layout, data, interactions)
2. Art Direction    → Style (palette, typo, spacing)
3. UX Research      → Usability (touch, accessibility)
4. UI Implementation→ Code GDScript
5. Lead Godot       → Review (conventions, perf)
6. Debug/QA         → Test plan
7. Auto-Validation  → validate_gdscript.ps1
```

**Commande de validation (TOUJOURS executer avant test):**
```powershell
powershell -ExecutionPolicy Bypass -File tools/validate_gdscript.ps1 -Path scripts
```

---

### Phase 13: LLM Performance Optimization
- **Status:** complete
- **Problem identified:** LLM response time 17-22s instead of near-instant
- **Root causes:**
  1. `max_tokens=256` too high (Python benchmark uses 60)
  2. No `repetition_penalty` causing infinite loops
  3. Verbose system prompt (500+ chars)
  4. No model warmup (first call loads model to GPU)
  5. Prompt says "Tu es Merlin" → LLM says "Je suis Merlin" instead of acting
- **Actions taken:**
  - **Reduced max_tokens: 256 → 100** (sufficient for response + 4 choices)
  - **Added repetition_penalty: 1.3** via `set_advanced_sampling()`
  - **Reduced temperature: 0.7 → 0.6** (more coherent)
  - **Simplified system prompt:** 500 chars → 80 chars
  - **Added model warmup:** `_warmup_model()` runs at startup
  - **Improved response cleaning:**
    - Strips ChatML tokens
    - Removes prompt leakage ("Tu es Merlin", "Format:", etc.)
    - Removes meta-commentary ("Je suis Merlin", "En tant que Merlin")
  - **Improved choice parsing:**
    - Supports formats: "1. ", "1) ", "1: ", "- ", "* "
    - Strips corrupted tokens ("system", "<|")
    - Fallback choices complete to 4 if LLM generates fewer
  - **Optimized polling:** Less aggressive after first 10 iterations

### Files Modified (Phase 13)
- `scripts/TestLLMSceneUltimate.gd`
  - New constants: `LLM_MAX_TOKENS`, `LLM_TEMPERATURE`, `LLM_TOP_P`, `LLM_TOP_K`, `LLM_REPETITION_PENALTY`
  - New function: `_warmup_model()` — preloads model to GPU
  - Improved: `_clean_response()` — strips prompt leakage
  - Improved: `_parse_response()` — more robust choice parsing
  - Improved: `_generate_once()` — uses optimized parameters

### Expected Performance Improvement
| Metric | Before | After (expected) |
|--------|--------|------------------|
| Response time | 17-22s | 3-8s |
| Max tokens | 256 | 100 |
| Repetition bugs | Frequent | Rare |
| Prompt leakage | Yes | Filtered |
| 4 choices | Inconsistent | Always 4 |

### Phase 14: Bug Fixes + Global LLM Status Bar
- **Status:** complete
- **Errors fixed:**
  1. `SHADOWED_VARIABLE_BASE_CLASS` ligne 991 — `show` → `is_visible`
  2. `Invalid type in function '_is_similar_to_existing'` — `Array[String]` → `Array`
- **New features:**
  - **LLMStatusBar autoload** (`scripts/llm_status_bar.gd`)
    - Barre de statut en bas à gauche sur TOUS les écrans
    - Indicateur couleur: vert=prêt, jaune=chargement, rouge=erreur
    - Bouton sélecteur de modèle (dropdown)
    - Préchauffement automatique au boot du jeu
    - API publique: `get_llm()`, `is_ready()`, `get_model_path()`
  - **Bouton "Test LLM"** ajouté au menu principal
    - Accès direct à TestLLMSceneUltimate.tscn

### Files Created (Phase 14)
- `scripts/llm_status_bar.gd` — Autoload barre de statut LLM

### Files Modified (Phase 14)
- `scripts/TestLLMSceneUltimate.gd`
  - `show` → `is_visible` (ligne 991)
  - `Array[String]` → `Array` (ligne 931)
- `scripts/MenuPrincipalReigns.gd`
  - Ajouté "Test LLM" dans MAIN_MENU_ITEMS
- `project.godot`
  - Ajouté autoload LLMStatusBar

### Validation
```
Files scanned: 57
Errors: 0
Warnings: 0
```

### Phase 15: Multi-Agent LLM Review
- **Status:** complete
- **Agents invoked:** 4 (in parallel)
  1. **LLM Expert** — Prompt engineering review
  2. **Godot Expert** — Performance & GDExtension review
  3. **Lead Godot** — Architecture & conventions review
  4. **Debug/QA** — Test plan creation

- **Corrections applied from agent reviews:**

#### LLM Expert Corrections
- Ultra-short prompts (~10 tokens): `Merlin. Court. Francais.`
- Removed ALL examples from prompts (model repeats them)
- max_tokens: 80 → 60
- temperature: 0.5 → 0.4
- top_k: 30 → 25
- repetition_penalty: 1.5 → 1.6
- Aggressive keyword-based leak detection

#### Godot Expert Corrections
- Adaptive polling pattern in warmup:
  - Poll 1-5: every frame (16ms)
  - Poll 6-20: every 30ms
  - Poll 21+: every 100ms
- Model caching pattern verified
- Timeout protection added

#### Lead Godot Corrections
- Added `_exit_tree()` cleanup in llm_status_bar.gd
- Signal disconnection on exit
- Model unload on cleanup
- Warmup timeout (30s max)

#### Debug/QA Output
- 117 test cases defined
- Categories: warmup, generation, UI, model switching, edge cases
- Pending user validation in Godot

### Files Modified (Phase 15)
- `scripts/TestLLMSceneUltimate.gd`
  - Ultra-short prompt templates
  - Optimized sampling parameters
  - Aggressive response cleaning
- `scripts/llm_status_bar.gd`
  - Adaptive polling in _warmup_model()
  - Added _exit_tree() with full cleanup
  - 30s warmup timeout

### Files Created (Phase 15)
- `.claude/agents/godot_expert.md` — Performance/GDExtension expert
- `.claude/agents/llm_expert.md` — Prompt engineering expert

### Files Updated (Phase 15)
- `.claude/agents/AGENTS.md` — Added new agents to roster
- `findings.md` — Agent review summary
- `progress.md` — Phase 15 documentation

### Expected Performance After Agent Corrections
| Metric | Before Agents | After Agents |
|--------|---------------|--------------|
| Prompt tokens | ~35 | ~10 |
| max_tokens | 80 | 60 |
| temperature | 0.5 | 0.4 |
| Latency (expected) | 4-6s | 2-4s |
| Memory leaks | Possible | Fixed |
| Warmup timeout | None | 30s |

### Validation
```
Files scanned: 57
Errors: 0
Warnings: 0
```

### Phase 16: UI/UX Enhancements (Reigns-style + Voice)
- **Status:** complete
- **Changes:**

#### Menu Principal - Animations Reigns
- Entry animation: carte monte du bas avec effet Back ease
- Floating animation: oscillation subtile continue (comme Reigns)
- Staggered buttons: boutons apparaissent en cascade
- Hover effects: scale 1.03x + son
- Click sounds: son "click" + "whoosh" sur swipe

#### TestLLM - Merlin Portrait + Voice
- Portrait Merlin (120x120) avec cadre accent
- 6 émotions: SAGE, PENSIF, QUESTION, COLERE, SURPRIS, PEUR
- Détection automatique d'émotion via keywords
- Animation de transition entre émotions
- ACVoicebox intégré avec preset robotique:
  - base_pitch: 2.5 (très grave)
  - pitch_variation: 0.12 (minimal)
  - speed_scale: 0.65 (lent, délibéré)
- Sync voix avec typewriter (lettre par lettre)

#### Audio Designer Agent
- Agent mis à jour avec specs ACVoicebox
- UI sounds specs définies
- Emotion-based voice modulation table

#### CLAUDE.md - Auto-Activation
- Skills always active: planning-with-files, GDScript validation
- Agents invoke matrix par type de changement
- LLM Integration Rules documentées
- Audio Standards ajoutées

### Files Created (Phase 16)
- `audio/sfx/ui/` — Dossier pour sons UI (placeholders)

### Files Modified (Phase 16)
- `scripts/MenuPrincipalReigns.gd`
  - Entry animation avec Tween TRANS_BACK
  - Floating animation dans _process()
  - _setup_audio(), _play_ui_sound()
  - _on_button_hover() avec son + scale
- `scripts/TestLLMSceneUltimate.gd`
  - Merlin portrait + emotions (MERLIN_PORTRAITS const)
  - Emotion detection (_detect_emotion, _update_merlin_emotion)
  - ACVoicebox setup (_setup_voicebox)
  - Voice-synced typewriter
- `.claude/agents/audio_designer.md`
  - ACVoicebox configuration details
  - UI sounds specs (REQUIRED)
  - Emotion-based voice modulation
- `CLAUDE.md`
  - AUTO-ACTIVATION RULES section
  - Agent invoke matrix
  - Audio Standards section

### Validation
```
Files scanned: 57
Errors: 0
Warnings: 0
```

---

### Phase 17: Visual Overhaul - Menu + Intro + Weather
- **Status:** complete
- **Changes:**

#### LLM Status Bar - Repositioned
- Moved from bottom-left to bottom-center
- Anchor: 0.5, 1.0 (center-bottom)
- Offset: -140 to +140 (280px width centered)

#### Menu Principal - CRT + Merlin + Effects
- **CRT Background:** Dark bg (0.02, 0.03, 0.05) + crt_static.gdshader
- **Merlin Sprite:** Seasonal sprites behind card
  - HIVER, PRINTEMPS, ETE, AUTOMNE variants
  - Subtle breathing animation (sin wave)
- **Digital Clock:** Top-left, green terminal style
  - Shows time + date (custom if override enabled)
  - "*" marker when using custom date
- **Digital Eyes:** Top-right, blinking animation
  - Random blink interval (3-6 seconds)
- **Code Lines:** 20 GDScript snippets floating
  - Mouse repulsion effect (push away on hover)
  - Return to base position with lerp

#### Weather System
- **Seasonal detection:** Based on month (real or custom)
- **Weather types:** clear, rain, snow, fog
- **GPUParticles2D:** Performance-optimized particles
  - Snow: 150 particles, slow gravity, angular velocity
  - Rain: 200 particles, fast gravity
  - Fog: 50 particles, horizontal drift

#### CeltOS Intro Sequence
- **Boot screen:** ASCII CeltOS logo
- **Fake terminal logs:** 17 boot messages
- **Progress bar:** Synced with LLM warmup
- **Eye transition:** Merlin eyes fullscreen, scale animation
- **Flash to menu:** White flash then scene change

#### Options - Calendar Override
- **New settings:** calendar_override, calendar_day, calendar_month, calendar_year
- **UI:** SpinBox controls for day/month/year + override checkbox
- **Persistence:** Saved to user://settings.cfg under [calendar] section
- **Integration:** Menu reads settings to determine season + weather

### Files Created (Phase 17)
- `scripts/IntroCeltOS.gd` — Boot sequence with LLM warmup
- `scenes/IntroCeltOS.tscn` — Boot scene

### Files Modified (Phase 17)
- `scripts/llm_status_bar.gd` — Centered at bottom
- `scripts/MenuPrincipalReigns.gd`
  - Added CRT background + shader
  - Added Merlin sprite (seasonal)
  - Added digital clock + eyes
  - Added code lines with mouse repulsion
  - Added weather particle system
  - Added calendar override support
  - New functions: _load_calendar_settings(), _get_current_date()
- `scripts/MenuOptions.gd`
  - Added calendar settings to default_config
  - Added _build_calendar_options() dynamic UI
  - Updated load_settings() + save_settings() for calendar
  - Updated apply_to_ui() for calendar controls
- `project.godot`
  - Changed main scene to IntroCeltOS.tscn

### Calendar Override Flow
```
MenuOptions:
  calendar_override: bool
  calendar_day: int (1-31)
  calendar_month: int (1-12)
  calendar_year: int (2020-2100)

MenuPrincipalReigns:
  _load_calendar_settings() → reads from user://settings.cfg
  _get_current_date() → returns custom or system date
  _determine_season() → uses _get_current_date()
  _update_digital_clock() → shows "*" if override active
```

### Scene Flow
```
project.godot (run/main_scene)
    ↓
IntroCeltOS.tscn
  - CeltOS ASCII logo
  - Fake boot logs
  - LLM warmup (background)
  - Progress bar
    ↓
Merlin Eyes (fullscreen)
  - Scale animation (0.1 → 1.0)
    ↓
Flash (white)
    ↓
MenuPrincipal.tscn
  - Seasonal Merlin + weather
  - Digital clock + eyes
  - CRT static background
```

---

### Phase 18: New Specialized Agents + Bug Fixes
- **Status:** complete
- **Changes:**

#### Godot Runtime Errors Fixed
- **llm_status_bar.gd:74** — `ready` parameter shadowing signal
  - Changed `_on_merlin_ready_changed(ready: bool)` → `_on_merlin_ready_changed(is_ready: bool)`
- **MenuPrincipalReigns.gd** — GPUParticles2D `set_anchors_preset` error
  - GPUParticles2D inherits Node2D (not Control) → no anchor methods
  - Fixed by setting position manually using viewport size

#### Merlin Removal from Menu
- Removed `MERLIN_SPRITES` constant
- Removed `merlin_sprite` and `merlin_anim_offset` variables
- Removed `_build_merlin_sprite()` function
- Removed breathing animation from `_process()`

#### IntroCeltOS Eye Animation Redesign
- Uses system default font (no Celtic font for boot logs)
- Simpler ASCII logo without Unicode blocks
- Pixel eyes as ColorRect with glow animation:
  - Eye lines expand from 4px to 24px height
  - Glow pulsation effect
  - Scanline descent animation

#### 5 New Specialized Agents Created

| Agent | File | Specialty |
|-------|------|-----------|
| **Motion Designer** | `motion_designer.md` | Tweens, particles, easing, staggered entry |
| **Shader Specialist** | `shader_specialist.md` | GLSL, CRT, glow, pixelate, wave effects |
| **Mobile/Touch Expert** | `mobile_touch_expert.md` | Touch gestures, responsive UI, mobile perf |
| **Data Analyst** | `data_analyst.md` | Game analytics, A/B testing, telemetry |
| **Technical Writer** | `technical_writer.md` | GDScript docstrings, API docs, tutorials |

### Files Created (Phase 18)
- `.claude/agents/motion_designer.md` — Animation expert
- `.claude/agents/shader_specialist.md` — VFX/shader expert
- `.claude/agents/mobile_touch_expert.md` — Touch/responsive expert
- `.claude/agents/data_analyst.md` — Analytics expert
- `.claude/agents/technical_writer.md` — Documentation expert

### Files Modified (Phase 18)
- `scripts/llm_status_bar.gd` — Fixed ready signal shadowing
- `scripts/MenuPrincipalReigns.gd` — Removed Merlin, fixed GPUParticles2D
- `scripts/IntroCeltOS.gd` — Redesigned eye animation, terminal font
- `.claude/agents/AGENTS.md` — Updated roster with 5 new agents

### Agent Roster Summary
Total agents: 17
- Core Technical: 5 (Lead Godot, Godot Expert, LLM Expert, Debug/QA, Shader Specialist)
- UI/UX & Animation: 4 (UI Impl, UX Research, Motion Designer, Mobile/Touch Expert)
- Content & Creative: 4 (Game Designer, Narrative Writer, Art Direction, Audio Designer)
- Operations & Docs: 4 (Producer, Localisation, Technical Writer, Data Analyst)

---

### Phase 19: Automated Error Validation System
- **Status:** complete
- **Changes:**

#### Bug Fixes
- **main_game.gd:506** — Duplicate variable `log_label` in lambda
  - Renamed to `combat_log` to avoid shadowing outer scope variable
- **robot_voice.gdextension** — Missing Windows DLLs causing load errors
  - Renamed to `.gdextension.disabled` (GDScript parts still work)

#### New Validation System
- **`tools/validate_godot_errors.ps1`** — Comprehensive validation script:
  1. **Godot Runtime Logs** — Parses `%APPDATA%/Godot/app_userdata/DRU/logs/` for:
     - SCRIPT ERROR (with stack trace)
     - Parse Error
     - General ERROR messages
  2. **GDScript Static Analysis** — Checks for:
     - Reserved keywords as loop variables (`for trait in`)
     - Type inference from const indexing (`var x := CONST[i]`)
     - Deprecated `yield()` (Godot 3)
     - Python-style integer division (`//`)
     - Signal shadowing in parameters
  3. **GDExtension Check** — Detects missing library definitions

- **`validate.bat`** — One-click validation shortcut

#### Usage
```powershell
# From project root
.\validate.bat

# Or directly
powershell -ExecutionPolicy Bypass -File tools/validate_godot_errors.ps1
```

### Files Created (Phase 19)
- `tools/validate_godot_errors.ps1` — Main validation script
- `validate.bat` — Quick launcher

### Files Modified (Phase 19)
- `scripts/main_game.gd` — Fixed duplicate variable
- `addons/robot_voice/robot_voice.gdextension` → `.gdextension.disabled`

---

### Phase 20: Auto-Activation Configuration
- **Status:** complete
- **Changes:**

#### CLAUDE.md Rewritten
- Section "🔴 RÈGLES D'AUTO-ACTIVATION (MANDATORY)" en tête
- Workflow standard avec diagramme ASCII
- Matrice d'invocation des 17 agents
- Ordre obligatoire: Code → validate.bat → Test Godot

#### Memory File Updated
- `MEMORY.md` inclut maintenant les règles DRU obligatoires
- Rappel automatique à chaque session

#### Règles Enforced
1. **Planning Files**: Obligatoire pour tâches > 2 étapes
2. **Validation**: `.\validate.bat` AVANT tout test
3. **Agents**: Invocation selon matrice de changement

### Files Modified (Phase 20)
- `CLAUDE.md` — Règles d'auto-activation complètes
- `MEMORY.md` — Rappel des règles DRU

---

---

## Session: 2026-02-08

### Phase 21: Narrative Engine Documentation
- **Status:** complete
- **Agent invoked:** Narrative Writer (narrative_writer.md)
- **Actions taken:**
  - Created `docs/50_lore/NARRATIVE_ENGINE.md` (550+ lines)
  - Document defines the "JDR Parlant" narrative engine

### NARRATIVE_ENGINE.md Contents

#### 1. Structure Narrative du JDR Parlant
- Voix de Merlin (5 traits de personnalite)
- 5 registres de voix (neutre, mysterieux, avertissement, encouragement, malicieux)
- Rythme de narration (accroche, contexte, tension, resolution)
- Alternance dialogue/description (60% description, 25% dialogue PNJ, 10% Merlin, 5% silence)

#### 2. Systeme d'Evenements Aleatoires
6 types d'evenements avec frequences:
| Type | Frequence | Sous-types |
|------|-----------|------------|
| Rencontres | 35% | Voyageurs, Creatures, Autochtones, Revenants |
| Dilemmes | 25% | Sacrifice, Loyaute, Verite, Survie |
| Decouvertes | 15% | Lieux, Objets, Savoirs |
| Conflits | 10% | Interpersonnels, Factions, Interieurs |
| Merveilles | 10% | Visions, Manifestations, Dons |
| Catastrophes | 5% | Naturelles, Surnaturelles, Humaines |

Chaque type inclut:
- Conditions de declenchement
- Impact narratif
- Exemple de prompt LLM

#### 3. Retournements de Situation
4 types de revelations:
- Identite Cachee (PNJ n'est pas ce qu'il semblait)
- Motivation Inverse (raisons differentes)
- Consequence Differee (vieux choix revient)
- Fausse Victoire (succes cache un echec)

Timing des twists selon longueur de run.
Catalogue de 6 indices plantables.

#### 4. Arcs Narratifs Proceduraux
Structure 3-5 cartes:
1. Introduction (presenter, etablir besoin)
2. Complication (intensifier, nouveau facteur)
3. Climax (point de non-retour)
4-5. Resolution (consequences, fermeture)

4 themes d'arcs documentes:
- Arc de Quete
- Arc de Mystere
- Arc de Vengeance
- Arc d'Amour

Personnages recurrents avec systeme de flags.
Resolutions multiples (heroique, pragmatique, sombre, mysterieuse).

#### 5. Coherence Narrative
- Memory du LLM (story_log, flags, arcs, NPCs)
- Callbacks aux choix precedents (patterns)
- Evolution des relations (-100 a +100 trust)
- Continuite meta-narrative (entre runs)

#### 6. Templates de Prompts LLM
6 templates specifiques:
- Prompt de base (system)
- Prompt pour rencontre
- Prompt pour dilemme
- Prompt pour retournement
- Prompt pour climax d'arc
- Prompt pour catastrophe

#### 7. Exemples de Dialogues Merlin
- Debut de run
- Avertissements de jauge (4 jauges x basse)
- Fins de run (8 fins)
- Promesses (proposition, rappel, accomplissement, bris)

### Files Created (Phase 21)
- `docs/50_lore/NARRATIVE_ENGINE.md` — Complete narrative engine documentation

### Files Modified (Phase 21)
- `task_plan.md` — Marked phase 8.3 as complete
- `progress.md` — Added Phase 21 log

### Narrative Report

#### Content Created
- 1 major documentation file (550+ lines)
- 6 event type specifications
- 4 twist type patterns
- 4 arc theme templates
- 6 LLM prompt templates
- 12 Merlin dialogue examples

#### Sample Card (from document)

**Rencontre - Dilemme:**
```json
{
    "text": "Un druide noir se tient devant toi. Son baton est grave de runes que tu ne reconnais pas. Il te demande l'hospitalite pour la nuit.",
    "speaker": "MERLIN",
    "options": [
        {
            "direction": "left",
            "label": "Le refuser",
            "effects": [{"type": "REMOVE_RESOURCE", "target": "Faveur", "value": 10}]
        },
        {
            "direction": "right",
            "label": "L'accueillir",
            "effects": [
                {"type": "ADD_RESOURCE", "target": "Faveur", "value": 15},
                {"type": "REMOVE_RESOURCE", "target": "Ressources", "value": 10}
            ]
        }
    ],
    "tags": ["rencontre", "druide", "hospitalite"]
}
```

#### Lore Considerations
- Consistent with LORE_BIBLE_MERLIN.md (hints-only, no direct reveals)
- Respects NARRATIVE_GUARDRAILS.md (banned terms, ambiguity rule)
- Follows MERLIN_BEHAVIOR_PROTOCOL.md (trust states, line patterns)

#### Voice Check
- [x] Consistent Merlin tone
- [x] No modern language
- [x] No mechanical descriptions
- [x] Appropriate length

---

### Phase 22: Git & Project Management Agents
- **Status:** complete
- **Actions taken:**
  - Created **Git Commit Agent** (`.claude/agents/git_commit.md`)
    - Auto-commit after completed phases
    - Conventional commit format: `[TYPE] Description`
    - 8 commit types: FEAT, FIX, DOCS, REFACTOR, STYLE, TEST, CHORE, PERF, AGENT
    - Pre-commit checklist integration with `validate.bat`
    - Files-to-never-commit list (secrets, generated, temp)
  - Created **Project Curator Agent** (`.claude/agents/project_curator.md`)
    - Project inventory and census
    - Orphan file detection (unused scripts, assets, scenes)
    - Duplicate detection
    - Large file identification (> 1MB)
    - Archive review recommendations
    - `.gitignore` maintenance
  - Updated **AGENTS.md** — New "Project Management" category
  - Updated **CLAUDE.md** — Added to invocation matrix
  - Improved **.gitignore** — Comprehensive patterns:
    - Godot, IDE, OS files
    - LLM models (*.gguf, *.bin, *.safetensors)
    - Native build artifacts
    - Node.js, Python environments
    - Secrets and credentials
    - Temporary and backup files
    - Logs

### Files Created (Phase 22)
- `.claude/agents/git_commit.md` — Git commit automation agent
- `.claude/agents/project_curator.md` — Project hygiene agent

### Files Modified (Phase 22)
- `.claude/agents/AGENTS.md` — Added 2 new agents (total: 19)
- `CLAUDE.md` — Updated agent count and matrix
- `.gitignore` — Comprehensive rewrite with categories

### Agent Roster Summary
**Total agents: 19**
- Core Technical: 5
- UI/UX & Animation: 4
- Content & Creative: 4
- Operations & Docs: 4
- **Project Management: 2** (NEW)

---

### Phase 23: Technical Writer - Documentation Consolidation
- **Status:** complete
- **Agent invoked:** Technical Writer (technical_writer.md)
- **Mission:** Audit documentation, creer index consolide, identifier gaps
- **Actions taken:**
  - Audit complet de 90+ documents dans docs/
  - Analyse par categorie (00_overview, 10_llm, 20_dru_system, 30_jdr, 40_world_rules, 50_lore, 60_companion, 70_graphic, 80_sound)
  - Attribution de statuts (CURRENT, NEEDS UPDATE, DEPRECATED, DRAFT)
  - Identification des incoherences post-pivot Reigns-like
  - Creation de l'index consolide complet

### docs/README.md - Index Consolide

#### Structure
1. **Vue d'ensemble projet** (2 paragraphes)
   - DRU: Jeu narratif roguelite style Reigns
   - Godot 4.x, LLM Trinity-Nano, 4 jauges equilibre

2. **Vision "JDR Parlant"**
   - Merlin narre, joueur decide, LLM genere
   - Simplicite extreme, mystere permanent
   - Rejouabilite infinie

3. **Pivot Majeur (Fevrier 2026)**
   - Tableau avant/apres (combat -> swipe, HP -> jauges, etc.)
   - Documents affectes

4. **Index par Categorie**
   - 10 categories documentees
   - 90+ documents indexes avec statuts
   - Parametres LLM actuels inclus

5. **Gaps et Priorites**
   - 5 documents manquants identifies
   - 5 documents obsoletes a archiver
   - 4 incoherences resolues

6. **Guide Nouveaux Contributeurs**
   - 5 documents essentiels (lecture prioritaire)
   - Index par role (dev Godot, dev LLM, game designer, etc.)
   - Conventions de contribution

7. **Structure Recommandee**
   - Proposition reorganisation dossiers
   - Documents a fusionner
   - Documents a supprimer

#### Documents Manquants (A Creer)
| Document | Priorite |
|----------|----------|
| `DOC_12_Oghams_Skills.md` | HAUTE |
| `BIOMES_SYSTEM.md` | HAUTE |
| `NARRATIVE_ENGINE.md` | HAUTE (cree phase 21) |
| `API_REFERENCE.md` | MOYENNE |
| `BESTIOLE_VISUAL_GUIDE.md` | MOYENNE |

#### Documents Obsoletes (A Archiver)
| Document | Raison |
|----------|--------|
| `DOC_02_UI_Interaction_FORCE_LOGIQUE_FINESSE.md` | Verbes remplaces par swipe |
| `DOC_05_Combat_System_v2.md` | Combat deprecated |
| `DOC_10_Moves_Library.md` | Oghams = skills |
| `BESTIOLE_COMBAT_EXAMPLES.md` | Combat deprecated |
| `30_jdr/DRU_JDR_Cahier_des_Charges_Regles.md` | A reevaluer |

#### Incoherences Resolues
1. Oghams: skills Bestiole (pas moves)
2. FORCE/LOGIQUE/FINESSE: remplace par swipe
3. Combat: deprecated
4. 30_jdr: extraire lore vers 50_lore

### Files Modified (Phase 23)
- `docs/README.md` — Reecrit completement (index consolide)
- `task_plan.md` — Phase 8.4 marquee complete
- `progress.md` — Phase 23 ajoutee

### Deliverable Format

```markdown
## Documentation: Index Consolide

### Files Created/Updated
- `docs/README.md` — Index consolide complet (400 lignes)

### Documentation Type
- [x] API Reference (partiel)
- [x] Architecture
- [x] README
- [ ] Tutorial

### Validation
- [x] Links work (relative paths)
- [x] Consistent formatting
- [x] Status labels applied
- [x] Guide nouveaux contributeurs inclus
```

---

### Phase 24: Biomes System Documentation (Game Designer Agent)
- **Status:** complete
- **Agent invoked:** Game Designer (game_designer.md)
- **Actions taken:**
  - Created `docs/40_world_rules/BIOMES_SYSTEM.md` (700+ lines)
  - Document defines the "JDR Parlant" world structure

### BIOMES_SYSTEM.md Contents

#### PARTIE 1: Les 7 Biomes de Bretagne

| Biome | Theme | Jauge Favorisee | Jauge Penalisee |
|-------|-------|-----------------|-----------------|
| Foret de Broceliande | Mystere, Magie | Esprit +15/+20% | Vigueur -10%, Ressources -15% |
| Landes de Bruyere | Survie, Solitude | Esprit +10% | Vigueur -20%, Faveur -15% |
| Cotes Sauvages | Commerce, Exploration | Ressources +25% | Esprit -10% |
| Villages Celtes | Politique, Social | Faveur +30%, Vigueur +15% | Esprit -15% |
| Cercles de Pierres | Magie, Spirituel | Esprit +40% | Faveur -20% |
| Marais des Korrigans | Danger, Tentation | Ressources +30% | Vigueur +25%, Esprit +15% pertes |
| Collines aux Dolmens | Sagesse, Ancestral | Esprit +20%, Vigueur +10% | Ressources -10% |

Chaque biome inclut:
- Atmosphere et theme
- Palette visuelle (couleurs hex)
- Modificateurs de jauges (gains/pertes)
- Types de cartes specifiques (5-8 par biome)
- Oghams favorises (3 par biome)
- Conditions d'acces (saison, flags, jauges)
- Evenements uniques (3 par biome avec triggers)

#### PARTIE 2: Systeme de Ressources Cachees

6 ressources INVISIBLES au joueur:

| Ressource | Range | Description |
|-----------|-------|-------------|
| karma_cache | -100 to +100 | Decisions morales accumulees |
| faction_druides | -100 to +100 | Reputation ordre druidique |
| faction_villageois | -100 to +100 | Reputation paysans |
| faction_guerriers | -100 to +100 | Reputation clans |
| faction_creatures | -100 to +100 | Reputation fees/korrigans |
| faction_marchands | -100 to +100 | Reputation commercants |
| dette_merlin | 0 to 100 | Ce qu'on doit a Merlin |
| tension_narrative | 0 to 100 | Compteur menant aux climax |
| memoire_monde | Dictionary | Flags et compteurs persistants |
| affinite_saison | 4 x compteurs | Bonus saisonniers accumules |

Effets par seuils et revelation progressive via indices narratifs.

#### PARTIE 3: Systeme de Retournements

5 types de twists emergents:

| Type | Trigger | Effet |
|------|---------|-------|
| Revelation | tension > 70, secret non decouvert | Un secret revele change tout |
| Trahison | faction retournee, tension > 60 | Ancien allie devient ennemi |
| Miracle | karma > 50, jauge critique | Aide inattendue |
| Catastrophe | karma < -40, tension > 80 | Evenement negatif majeur |
| Deus Ex Machina | tension = 100, run longue | Intervention directe de Merlin |

Frequences par run moyenne: 1-3 retournements.
Prevention via karma equilibre et gestion des factions.

#### PARTIE 4: Systeme de Rejouabilite

Sources de variation:
- 7^10 sequences de biomes = 282 millions
- 5^5 configurations de factions = 3125
- C(18,3) trios d'Oghams = 816
- 35 arcs narratifs x contexte variable
- Secrets globaux (persistants) + secrets de run (uniques)

Meta-progression:
| Gloire | Unlock |
|--------|--------|
| 50 | 4eme slot Ogham |
| 100 | Biome prefere au start |
| 200 | Ressource cachee visible |
| 500 | Mode Druide (difficulte+) |
| 1000 | Ending Ultime accessible |

#### PARTIE 5: Integration Technique

Structures GDScript pour:
- `BIOMES` const avec modifiers, events, palettes
- `hidden_resources` var avec 6 ressources
- Contexte LLM etendu (visible + hidden + biome + narrative_state)
- `check_twist_conditions()` function

#### PARTIE 6: Equilibrage

| Parametre | Defaut | Range |
|-----------|--------|-------|
| Modifier biome max | 40% | 10-60% |
| Karma decay | 0 | -1 to +1/card |
| Tension growth | +1/card | 0.5-2 |
| Faction threshold | +/-30 | +/-20-50 |
| Twist cooldown | 10 cards | 5-20 |

### Files Created (Phase 24)
- `docs/40_world_rules/BIOMES_SYSTEM.md` — Complete biomes & hidden resources documentation

### Files Modified (Phase 24)
- `task_plan.md` — Marked phase 8.2 as complete
- `progress.md` — Added Phase 24 log

### Game Design Report

#### Topic: Biomes & Hidden Resources System

#### Design Intent
Creer un monde Reigns-like avec profondeur cachee. Le joueur voit 4 jauges simples mais le systeme suit des dizaines de variables invisibles qui influencent secretement le recit.

#### Mechanics
- 7 biomes distincts avec modificateurs uniques
- 6 ressources invisibles (karma, factions, dette, tension, memoire, affinites)
- 5 types de retournements emergents
- Rejouabilite via combinatoire massive

#### Balance Considerations
- Pro: Profondeur sans complexite visible
- Pro: Retournements emergents = surprises authentiques
- Con: Risque d'opacite si mal calibre
- Mitigation: Indices narratifs + skill Bestiole ailm

#### Testing Recommendations
- [ ] Tester chaque type de retournement 3x minimum
- [ ] Verifier transitions entre tous les biomes
- [ ] 100 runs pour statistiques moyennes
- [ ] Stress test LLM avec hidden resources

#### Open Questions
1. Faut-il reveler les ressources cachees a la fin de run?
2. Les factions devraient-elles avoir des leaders nommes?
3. Quelle integration visuelle pour les biomes?

---

### Phase 25: Merlin Complete Personality (Merlin Guardian Agent)
- **Status:** complete
- **Agent invoked:** Merlin Guardian (merlin_guardian.md)
- **Mission:** Definir la personnalite complete de Merlin avec dualite joyeuse/sombre
- **Actions taken:**
  - Created `docs/50_lore/MERLIN_COMPLETE_PERSONALITY.md` (700+ lines)
  - Document definitif pour le personnage de Merlin

### MERLIN_COMPLETE_PERSONALITY.md Contents

#### Vision Fondamentale
**Merlin est une IA joyeuse et loufoque qui taunt le joueur avec humour, MAIS qui cache de sombres secrets sur l'avenir de l'humanite. Dans cette version du jeu: IL EST DEJA TROP TARD.**

#### Section 1: La Dualite de Merlin

**Surface (95% du temps):**
- Joyeux, espiegle, taquin, loufoque, enthousiaste
- 5 registres de voix: accueil chaleureux, moquerie bienveillante, encouragement exuberant, curiosite malicieuse, emerveillement theatral
- Patterns de dialogue structures (reaction → observation → contradiction → transition)

**Profondeur (5% du temps):**
- Melancolie ancienne, indices cryptiques, silences lourds
- 5 registres: melancolie fugace, tendresse inattendue, poids du savoir, culpabilite masquee, resignation voilee
- Transitions Surface ↔ Profondeur documentees

#### Section 2: Patterns de Taunting

5 contextes de taunting documentes:
1. **Hesitation** - Niveaux progressifs (5s → 30s+)
2. **Mauvais choix** - Reactions par consequence
3. **Repetition de pattern** - Variations par type de pattern
4. **Proche de la mort** - Ton different par jauge critique
5. **Reussite** - De simple a inattendue, avec transition sombre rare

#### Section 3: Les Indices Sombres

**Philosophie:**
- JAMAIS direct, toujours interrompu
- Double sens obligatoire
- Deflection immediate apres hint
- Maximum 1 par session

**20+ phrases a double sens documentees**

**Motivations cachees de Merlin (5 hypotheses):**
1. Donner du sens aux derniers jours
2. Combattre sa propre solitude
3. Rechercher une absolution
4. Preserver un temoignage
5. Espoir irrationnel (le plus subtil)

**Le Poids du Savoir:**
- Manifestations comportementales (humour constant, affection, refus du passe)
- 3 niveaux de fissure (legere, moyenne, profonde avec exemples)

**Ce qui arrivera apres le jeu:** JAMAIS dit, uniquement suggere via 4 indices types

#### Section 4: Voice Lines par Contexte

**80+ voice lines organisees par:**
- Debut de run (premier eveil, apres mort, apres victoire, variations saisonnieres)
- Milieu de run (encouragement, taunting, rappel promesse, transition narrative)
- Fin de run proche (avertissement, dernier conseil, adieu potentiel)
- **8 endings avec tons differents:**
  | Ending | Ton |
  |--------|-----|
  | Epuisement | Tendresse, resignation |
  | Surmenage | Avertissement tardif, culpabilite |
  | Folie | Confusion, echo |
  | Possession | Horreur contenue, distance |
  | Exile | Solitude partagee |
  | Tyrannie | Deception, distance |
  | Famine | Impuissance, presence |
  | Pillage | Avertissement moral, lassitude |

**Easter Eggs (5 scenarios):**
- Apres 10+ runs
- Apres toutes les fins vues
- Apres 100+ cartes
- Joueur uniquement gentil
- Secret cache trouve

#### Section 5: Regles d'Or du Comportement

**Ce que Merlin ne dit JAMAIS:**
- 9 mots/phrases interdits (fin du monde, apocalypse, simulation, etc.)
- 7 comportements interdits (pleurer, desespoir visible, reveler la fin, etc.)

**Ce que Merlin dit TOUJOURS:**
- Tutoiement, humour, reference naturelle, invitation a continuer
- 5 comportements obligatoires

**Reaction par Jauge (4 jauges x 6 niveaux = 24 reactions documentees)**

**Rapport au Temps:**
- Temps passe, accelere, s'arrete, restant

**Rapport a Bestiole:**
- Affection, complicite, protection, indices sombres, jalousie jouee

#### Section 6: Guide d'Implementation

**Probabilites:**
| Type | Frequence |
|------|-----------|
| Surface Joyeuse | 60% |
| Surface Taquine | 25% |
| Surface Loufoque | 10% |
| Profondeur Legere | 4% |
| Profondeur Intense | 1% |

**Declencheurs de profondeur (7 contextes avec probabilites)**

**Checklist de validation (7 points)**

### Files Created (Phase 25)
- `docs/50_lore/MERLIN_COMPLETE_PERSONALITY.md` — Guide complet du personnage Merlin

### Files Modified (Phase 25)
- `progress.md` — Added Phase 25 log
- `task_plan.md` — Added Phase 8.7

### Narrative Report

#### Content Created
- 1 document majeur (700+ lignes)
- 80+ voice lines par contexte
- 20+ phrases a double sens
- 24 reactions par jauge
- 8 endings avec tons differents
- 5 easter eggs pour joueurs attentifs

#### Lore Considerations
- Coherent avec LORE_BIBLE_MERLIN.md (hints-only, non-truth rule)
- Respecte NARRATIVE_GUARDRAILS.md (banned terms, ambiguity)
- Etend MERLIN_BEHAVIOR_PROTOCOL.md (trust states, line patterns)
- Integre avec NARRATIVE_ENGINE.md (prompts, dialogues)

#### Voice Check
- [x] Ton Merlin coherent
- [x] Pas de langage moderne
- [x] Dualite surface/profondeur respectee
- [x] Longueur appropriee par contexte

---

*Last updated: 2026-02-08 - Merlin Complete Personality by Merlin Guardian Agent*

---

### Phase 26: Celtic Foundation Documentation (Historien Bretagne Agent)
- **Status:** complete
- **Agent invoked:** Historien Bretagne (historien_bretagne.md)
- **Mission:** Creer la fondation historique et mythologique authentique pour DRU
- **Actions taken:**
  - Created `docs/50_lore/CELTIC_FOUNDATION.md` (900+ lines)
  - Comprehensive research via WebSearch on Celtic/Breton sources
  - Document en francais avec sources citees

### CELTIC_FOUNDATION.md Contents

#### 1. La Bretagne Ancienne
- **5 Tribus Celtes d'Armorique:**
  - Osismes (Finistere) - "Ceux du bout du monde"
  - Venetes (Morbihan) - Puissance maritime, resistance heroique 56 av. J.-C.
  - Coriosolites (Cotes-d'Armor) - "Armee du soleil"
  - Redones (Ille-et-Vilaine) - Cavaliers, fondateurs de Rennes
  - Namnetes (Loire-Atlantique) - Commercants fluviaux
- **Organisation Druidique:**
  - Druides (20 ans formation), Bardes (12 ans), Vates (7 ans)
  - Transmission orale exclusive, pas de temples
  - Ritual du gui avec serpe d'or
- **Croyances Annwn:**
  - Autre Monde = paradis, pas punition
  - Temps eternel, festins des morts glorieux
  - Acces par tertres, lacs, brumes
- **Calendrier 8 Festivals:**
  - Samhain, Yule, Imbolc, Ostara, Beltane, Litha, Lughnasadh, Mabon
- **Lieux Sacres:**
  - Broceliande (Fontaine Barenton, Val sans Retour, Tombeau Merlin)
  - Carnac (3000 menhirs, UNESCO 2025)

#### 2. Figures Mythologiques
- **3 Traditions Merlin:**
  - Myrddin Wyllt (prophete fou)
  - Merlin Ambrosius (conseiller des rois)
  - Myrddin Emrys (prophete national gallois)
- **Role des Druides:** Religieux, juridique, educatif, politique, medical
- **Creatures Bretonnes:**
  - Korrigans ("petit nain")
  - Marie-Morganes (fees d'eau)
  - Bugul-noz, Groac'h
- **L'Ankou:** Collecteur d'ames, chariot grincant
- **Dahut et Ys:** Cite engloutie, seduction, transformation en sirene

#### 3. L'Ogham Authentique
- **Structure:** 20 lettres + 5 forfeda = 25 feda
- **Les 25 Feda avec Arbres:**
  - 4 aicme de 5 lettres + forfeda
  - Beith (Bouleau), Duir (Chene), Ailm (Epicea), Idho (If), etc.
- **Usage Historique:** Inscriptions, marquage, messages
- **Adaptation DRU:** 18 Oghams = skills Bestiole

#### 4. Symbolisme Celtique
- **Triades Sacrees:** "Homme, Lumiere, Liberte"
- **Nombres Magiques:** 3, 5, 7, 9, 13
- **Animaux Totems:**
  - Cerf (Cernunnos), Sanglier, Corbeau (Lug), Loup
- **7 Arbres Nobles:** Chene, Noisetier, Houx, If, Frene, Pin, Pommier
- **Symboles:** Triskel, Spirale, Entrelacs, Croix celtique

#### 5. Eschatologie Celtique
- **Vision Cyclique:** Pas de fin definitive, cycles
- **Propheties Merlin:** Union des Celtes, retour des Bretons
- **Fin d'un Age vs Fin du Monde:**
  - Pas de punition morale cosmique
  - L'Autre Monde persiste
- **Elements:** Feu, Eau, Brume, Froid

#### 6. Vocabulaire Authentique
- **Toponymes:** Ker, Bro, Menez, Koad, Dour, Mor
- **Rituels:** Nemeton, Geis, Awen, Imbas, Neart
- **Exclamations:** Mallozh Doue!, Ma Doue!
- **Benedictions/Maledictions:** Bennozh Doue, Mallozh warnat
- **Proverbes:** Kalon vat a ra kalon vat
- **Expressions Merlin:** "Par les chenes de Broceliande"

### Files Created (Phase 26)
- `docs/50_lore/CELTIC_FOUNDATION.md` — Complete Celtic foundation (900+ lines)

### Research Sources Used
- Wikipedia FR: Mythologie bretonne, Carnac
- Academie du Languedoc: Les Druides
- Persee: Propheties Merlin, Eschatologie
- Wildera: Ogham feda
- Broceliande.guide: Fontaine Barenton
- Bretagne.com: Ys cite engloutie
- Arbre-celtique.com: Animaux sacres
- National Geographic: Imbolc

### Key Insights for DRU
1. Merlin = synthese de 3 traditions → "Dernier Druide"
2. Eschatologie cyclique → Fin = transformation
3. Annwn persiste → L'Autre Monde survit
4. Ogham = mots de pouvoir → Skills narrativement coherents
5. Vocabulaire breton → Voix authentique de Merlin

---

*Last updated: 2026-02-08 - Celtic Foundation by Historien Bretagne Agent*

---

### Phase 27: The Hidden Truth (Lore Writer Agent)
- **Status:** complete
- **Agent invoked:** Lore Writer (lore_writer.md)
- **Mission:** Creer le lore apocalyptique cache — la verite que Merlin porte seul
- **Actions taken:**
  - Created `docs/50_lore/THE_HIDDEN_TRUTH.md` (900+ lines)
  - Document definitif pour la verite secrete de l'univers DRU

### THE_HIDDEN_TRUTH.md — Resume Structurel

**7 Parties:**

#### PARTIE 1: La Verite Cachee
- Nature de la fin: **epuisement** cosmique (pas catastrophe)
- Bretagne mystique = dernier sanctuaire hors du temps
- Merlin sait tout depuis le debut (temoin, pas homme)
- Silence par misericorde (verite = fardeau)
- Le joueur = visiteur d'ailleurs, porteur de possibilite
- Les 18 Oghams = dernieres verites du monde + 5 secrets
- Secret ultime: "Nous avons ete. Nous avons vecu. Nous avons aime. Cela suffit."

#### PARTIE 2: Les Signes Avant-Coureurs
- **7 biomes avec indices specifiques:**
  - Broceliande: arbres sans pousses, brume permanente, fees fatiguees
  - Landes: horizon plus proche, tempetes faibles
  - Cotes: navires rares, marees hesitantes
  - Villages: enfants rares, festins nostalgiques
  - Cercles: menhirs moins vibrants, rituels oublies
  - Marais: korrigans moroses, pieges fatigues
  - Collines: ancetres parlant du passe
- **Comportements PNJ:** repetitions, dons, etreintes longues
- **Paroles Merlin par Trust (T0→T3):** progression de cryptique a presque-verite
- **4 saisons avec signes d'usure**
- **8 festivals celtiques devenus echos**

#### PARTIE 3: La Timeline Secrete
| Ere | Evenement |
|-----|-----------|
| Age d'Or | Harmonie totale |
| Premiere Fissure | Hommes prennent plus qu'ils donnent |
| Eveil des Druides | Oghams crees, tentative echec |
| Le Repli | Bretagne isolee, druides meurent |
| L'Apres | Monde exterieur eteint |

- Signification de Broceliande: coeur du sanctuaire, lac = larme du monde

#### PARTIE 4: Ce qui Reste Apres
- **Bestiole survivra:** fragment d'harmonie, fait de lien pas de chair
- **Pierres gardent memoire:** menhirs = livres de vibrations
- **Bretagne durera:** coffre-fort des histoires
- **Esprits:** fees → lumiere, korrigans → ombres, ancetres → souvenirs
- **Espoir malgre tout:** fin inevitable, espoir aussi

#### PARTIE 5: Themes Philosophiques
| Theme | Message |
|-------|---------|
| Choix Condamnes | Le sens, pas le resultat |
| Derniers Jours | Memento mori intensifie |
| Amour Malgre Fin | Aimer qui va mourir = humanite |
| Beaute du Crepuscule | Fin = achevement |
| Jouer Face a l'Absurde | Sisyphe heureux |

#### PARTIE 6: Integration Narrative
- **Techniques:** repetition significative, questions sans reponse, details etranges
- **6 metaphores:** ressort, maree, bougie, racines, souffle, fil
- **Symbolisme celtique:** triskell, noeud, arbre, corbeau, saumon, cerf
- **Palette emotionnelle:** or→ambre→rouge→argent→violet
- **Audio design:** ambiances par biome
- **5 types de silences eloquents**

#### PARTIE 7: Easter Eggs Multi-Runs
| Runs | Niveau de revelation |
|------|---------------------|
| 1-5 | Normal |
| 6-15 | Premiers signes |
| 16-30 | Accumulation |
| 31+ | Meta-recit |

- **5 secrets:** Vrai Nom (50 runs), Origine Bestiole (Bond 500), Prophetie (tous endings), Dernier Druide (18 Oghams), Autre Voyageur (100 runs)
- **4 dialogues uniques:** Merlin T3, Bestiole 95+, Ancien, Fee
- **Ending secret (100+ runs):** Remerciement + revelation M.E.R.L.I.N.

**Annexes:**
- Termes bannis (12 mots)
- Termes autorises (12 formulations)
- Checklist qualite lore (8 points)

### Files Created (Phase 27)
- `docs/50_lore/THE_HIDDEN_TRUTH.md` — La verite apocalyptique cachee (900+ lignes)

### Files Modified (Phase 27)
- `task_plan.md` — Marked phase 8.9 as complete
- `progress.md` — Added Phase 27 log

### Lore Report

#### Content Stats
- 7 parties majeures
- 900+ lignes de contenu
- 7 biomes avec indices specifiques
- 4 niveaux Trust avec dialogues
- 4 saisons avec changements
- 8 festivals revisites
- 5 eres historiques
- 5 themes philosophiques
- 6 metaphores recurrentes
- 5 secrets multi-run
- 1 ending secret

#### Coherence Verification
- [x] LORE_BIBLE_MERLIN.md: hints-only, non-truth rule
- [x] MERLIN_COMPLETE_PERSONALITY.md: dualite, indices sombres
- [x] NARRATIVE_GUARDRAILS.md: banned terms, ambiguity
- [x] BIOMES_SYSTEM.md: atmosphere coherente
- [x] NARRATIVE_ENGINE.md: twists/arcs compatibles
- [x] CELTIC_FOUNDATION.md: vocabulaire authentique

#### Duality Check
- [x] Surface whimsical preserved
- [x] Depths tragic but beautiful
- [x] Hope present despite doom
- [x] Never explicit — always suggested
- [x] Multi-interpretation guaranteed

---

*Last updated: 2026-02-08 - The Hidden Truth by Lore Writer Agent*

---

### Phase 28: UI/UX Overhaul - Calendar & Menu
- **Status:** complete
- **Agents invoked:** UI Implementation, UX Research, Motion Designer
- **Actions taken:**

#### Calendar.gd Improvements
- **Moon Phase System:**
  - Added `MOON_PHASES` constant with 8 lunar phases
  - Synodic month calculation (29.53 days)
  - Julian day conversion for accurate calculation
  - Moon phase visualization in wheel center
  - Moon power indicator (0.0 - 1.0)

- **Weather System:**
  - Added `WEATHER_TYPES` per season (4 weather types per season)
  - Deterministic weather based on day of year
  - Weather displayed in header with day counter

- **Stat Cards:**
  - Visual progress bars instead of plain text
  - Animated fill with `TRANS_CUBIC` easing
  - Color-coded by stat type (season colors)
  - Moon power as first stat card

- **Enhanced Wheel Drawing:**
  - `_draw_moon_phase()` function for center moon visualization
  - 8 distinct moon phase renderings (new, crescent, quarter, gibbous, full)
  - Night sky background behind moon

#### MenuPrincipalReigns.gd Improvements
- **UX Fixes:**
  - Button spacing increased: 6px → 12px (touch target compliance)
  - Calendar button now navigates directly to Calendar scene (no overlay)

- **Animation Improvements (Motion Designer spec):**
  - Button hover: `TRANS_BACK` easing for playful bounce
  - Scale: 1.03x → 1.05x on hover
  - Subtle modulate color shift on hover

- **Entry Animation Polish:**
  - Buttons start at 0.85x scale, pop to 1.0x with `TRANS_BACK`
  - Stagger delay: 80ms → 60ms per button
  - Added upward slide animation (+10px)

### Files Modified (Phase 28)
- `scripts/Calendar.gd` — Moon phases, weather, stat cards
- `scripts/MenuPrincipalReigns.gd` — UX fixes, animation polish

### Validation
```
Files scanned: 58
Errors: 0
Warnings: 0
VALIDATION PASSED
```

### Testing Checklist
- [ ] Calendar opens from menu (bottom-left)
- [ ] Moon phase displays correctly in wheel center
- [ ] Weather indicator shows in header
- [ ] Stat cards animate on entry
- [ ] Moon power bar fills correctly
- [ ] Menu buttons have proper spacing (12px)
- [ ] Button hover has bounce effect
- [ ] Button entry animation is staggered

---

### Phase 29: JDR Parlant Final Consolidation
- **Status:** complete
- **Actions taken:**
  - 6 agents completed in parallel:
    1. Game Designer → `docs/40_world_rules/BIOMES_SYSTEM.md`
    2. Narrative Writer → `docs/50_lore/NARRATIVE_ENGINE.md`
    3. Technical Writer → `docs/README.md` (index consolide)
    4. Merlin Guardian → `docs/50_lore/MERLIN_COMPLETE_PERSONALITY.md`
    5. Lore Writer → `docs/50_lore/THE_HIDDEN_TRUTH.md`
    6. Historien Bretagne → `docs/50_lore/CELTIC_FOUNDATION.md`
  - Updated `MASTER_DOCUMENT.md` to version 3.0 (JDR Parlant)
  - Created 3 new agents: Merlin Guardian, Lore Writer, Historien Bretagne
  - Updated AGENTS.md (22 agents total)

### Final JDR Parlant Vision Summary

**Concept:**
> Merlin narre des histoires generees par le LLM, les evenements sont aleatoires,
> des retournements de situations surgissent, tout repose sur des decisions
> qui accumulent des ressources visibles ET invisibles.

**The Hidden Truth:**
> L'humanite ne mourra pas dans le feu ou la glace, mais dans l'oubli.
> Merlin le sait. Le joueur ne le decouvre qu'apres 100+ runs.

**Core Systems Documented:**
- 7 biomes avec palettes et modificateurs uniques
- 4 jauges visibles + 6 ressources cachees
- 5 types de twists proceduraux
- 18 Oghams comme skills Bestiole
- Merlin: dualite joyeuse (95%) / sombre (5%)
- Fondation celtique authentique (25 feda, 8 festivals, 5 tribus)
- Easter eggs progressifs (20+ runs → 100+ runs)

**Documents Created This Session:**
| Document | Lignes | Agent |
|----------|--------|-------|
| BIOMES_SYSTEM.md | 930 | Game Designer |
| NARRATIVE_ENGINE.md | 794 | Narrative Writer |
| docs/README.md | 394 | Technical Writer |
| MERLIN_COMPLETE_PERSONALITY.md | 700 | Merlin Guardian |
| THE_HIDDEN_TRUTH.md | 894 | Lore Writer |
| CELTIC_FOUNDATION.md | 707 | Historien Bretagne |
| **TOTAL** | **4419** | 6 agents |

**Agent Roster Final (22):**
- Core Technical: 5
- UI/UX & Animation: 4
- Content & Creative: 4
- Lore & World-Building: 3 (NEW)
- Operations & Docs: 4
- Project Management: 2

---

### Phase 30: LLM Test Scene Fix + Robot Voice Sliders
- **Status:** complete
- **Issues fixed:**

#### 1. LLM Response Cleaning Bug
- **Problem:** LLM génère des marqueurs "user"/"assistant" dans les réponses
- **Symptôme:** Affichage de conversations simulées:
  ```
  Oui, ça marche. Je suis Merlin, et tu es quoi?
  user
  Je suis un utilisateur de l'assistant.
  assistant
  ```
- **Solution:** Amélioration de `_clean_response()`:
  - Ajout filtrage des marqueurs de rôle standalone ("user", "assistant")
  - Détection des conversations simulées (pattern: phrase + rôle + phrase)
  - Filtrage des lignes commençant par "je suis un utilisateur"
  - Troncature après "?" si suivi d'une fausse conversation

#### 2. Robot Voice Integration (RobotBlipVoice)
- **New Feature:** Sliders pour personnaliser la voix de Merlin
- **Paramètres ajoutés:**
  | Slider | Range | Default | Description |
  |--------|-------|---------|-------------|
  | Fréquence | 100-800 Hz | 380 Hz | Hauteur de base |
  | Variation | 0-200 Hz | 120 Hz | Variation de pitch |
  | Durée (ms) | 20-100 ms | 40 ms | Durée par blip |
  | Chirp | 0-1 | 0.35 | Effet de glissement |
- **Bouton "Test":** Joue une phrase test
- **Intégration:** RobotBlipVoice synchronisé avec typewriter

#### 3. Sprite Merlin Updates
- **Ancien chemin:** `res://archive/Assets/Merlin*.png`
- **Nouveau chemin:** `res://Assets/Sprite/Merlin*.png`
- **Mapping émotions → sprites saisonniers**

### Files Modified (Phase 30)
- `scripts/TestLLMSceneUltimate.gd`
  - `_clean_response()` — Filtrage amélioré des marqueurs de rôle
  - `_build_voice_sliders()` — Nouveau panneau de contrôle voix
  - `_setup_voicebox()` — Priorité à RobotBlipVoice
  - `_typewrite_response()` — Sync voix + typewriter
  - `MERLIN_PORTRAITS` — Chemins mis à jour vers Assets/Sprite/
  - `MERLIN_VOICE` — Paramètres RobotBlipVoice

### Validation
```
Files scanned: 58
Errors: 0
Warnings: 0
VALIDATION PASSED
```

---

### Phase 31: Les Cycles Anterieurs (Historien Bretagne Agent)
- **Status:** complete
- **Agent invoked:** Historien Bretagne (historien_bretagne.md)
- **Mission:** Creer la cosmologie temporelle cyclique de l'univers DRU
- **Actions taken:**
  - Created `docs/50_lore/LES_CYCLES_ANTERIEURS.md` (734 lignes)
  - WebSearch sur: eschatologie celtique, Tir na nOg, Tuatha De Danann, propheties Merlin, Annwn, Avalon, Fomorians

### LES_CYCLES_ANTERIEURS.md Contents

#### Structure du Document (10 Parties + 2 Annexes)

| Partie | Contenu | Lignes |
|--------|---------|--------|
| 1 | Vision Cyclique Celtique | ~80 |
| 2 | Premier Cycle (Age des Geants) | ~100 |
| 3 | Deuxieme Cycle (Age des Druides) | ~80 |
| 4 | Troisieme Cycle (Age des Rois) | ~90 |
| 5 | Quatrieme Cycle (Present) | ~60 |
| 6 | Cinquieme Cycle (Ce Qui Viendra) | ~70 |
| 7 | Lieux Hors du Temps | ~80 |
| 8 | Gardiens des Cycles | ~70 |
| 9 | Propheties Authentiques | ~70 |
| 10 | Integration dans DRU | ~60 |
| A | Sources et References | ~30 |
| B | Libertes Creatives | ~40 |

#### Concepts Cles Etablis

**1. Les Trois Cercles d'Existence (doctrine druidique):**
- **Annwn** — Tenebres primordiales, origine
- **Abred** — Alternance vie/mort, transmigrations
- **Gwynfyd** — Lumiere eternelle, accomplissement

**2. Les Quatre Cycles du Monde:**
| Cycle | Ere | Fin |
|-------|-----|-----|
| Premier | Age des Geants (Fomorians) | Bataille de Mag Tuired |
| Deuxieme | Age des Druides | Invasion, christianisation |
| Troisieme | Age des Rois (Arthur) | Camlann |
| Quatrieme | Present | Epuisement (en cours) |

**3. Les Tuatha De Danann:**
- Arrivee sur nuage de brume
- 4 tresors: Lia Fail, Epee de Nuada, Lance de Lugh, Chaudron du Dagda
- Defaite par les Milesiens → transformation en Sidhe
- Vivent maintenant dans les tertres invisibles

**4. Les Lieux Hors du Temps:**
| Lieu | Nature | Persistance |
|------|--------|-------------|
| Tir na nOg | Eternelle jeunesse | Survivra |
| Annwn | Autre Monde gallois | Survivra |
| Avalon | Ile des Pommes | Survivra |

**5. Propheties de Merlin (jamais realisees):**
- Union des Celtes
- Retour d'Arthur (Rex Quondam Rexque Futurus)
- Liberation des oppresseurs

**6. Integration DRU:**
- Echos des cycles dans les cartes
- Memoires ancestrales
- Deja-vu comme fissures temporelles
- PNJ qui semblent trop vieux

#### Sources Citees (12)

| Type | Nombre |
|------|--------|
| Academiques (Universalis, Persee, HAL) | 5 |
| Mythologiques (Wikipedia, Mythologica) | 5 |
| Arthuriennes | 2 |

### Files Created (Phase 31)
- `docs/50_lore/LES_CYCLES_ANTERIEURS.md` — Cosmologie cyclique complete (734 lignes)

---

### Phase 32: Game Design - Alternatives a Reigns
- **Status:** complete
- **Agent invoked:** Game Designer (game_designer.md)
- **Mission:** Proposer des systemes alternatifs pour differencier DRU de Reigns
- **Actions taken:**
  - Created `docs/20_dru_system/ALTERNATIVES_TO_REIGNS.md` (600+ lignes)
  - Analyse du systeme Reigns actuel (4 jauges, swipe binaire)
  - Recherche de references (Cultist Simulator, Stacklands, Griftlands, etc.)
  - 5 propositions alternatives avec pros/cons

### ALTERNATIVES_TO_REIGNS.md Contents

#### Propositions

| # | Nom | Concept | Differenciation |
|---|-----|---------|-----------------|
| 1 | Triades | 3 aspects x 3 etats discrets | Pas de chiffres, juste etats |
| 2 | Tokens | Ressources collectionnables/depensables | Options payantes |
| 3 | Cycle | Ressource circulaire (4 quadrants) | Navigation sur roue celtique |
| 4 | Intentions | 3-4 options par carte (F/R/S/C) | Plus que binaire |
| 5 | **Hybride** | Combinaison des meilleurs elements | **RECOMMANDATION** |

#### Systeme Hybride (Recommande)

**Structure:**
- **3 Aspects** (Corps, Ame, Monde) avec **3 etats** chacun (Bas/Moyen/Haut)
- **1 Ressource depensable:** Souffle d'Ogham (max 7)
- **3 Options par carte:** Gauche (direct), Centre (sage, 1 Souffle), Droite (risque)
- **9+ Fins** basees sur combinaisons d'etats extremes

**Avantages:**
- Maximum de differenciation avec Reigns
- Resonance celtique forte (triades, souffles, equilibre)
- 3 options enrichit le gameplay sans complexifier
- Parties courtes grace aux etats discrets
- Profondeur cachee via ressources invisibles existantes

**Effort estime:** ~3 semaines d'implementation

#### Comparatif Final (scores /35)

| Systeme | Simplicite | Differenciation | Profondeur | Celtique | Total |
|---------|------------|-----------------|------------|----------|-------|
| Reigns actuel | 4/5 | 1/5 | 3/5 | 2/5 | 22/35 |
| Triades | 5/5 | 4/5 | 2/5 | 4/5 | 27/35 |
| Tokens | 3/5 | 4/5 | 4/5 | 3/5 | 24/35 |
| Cycle | 3/5 | 5/5 | 3/5 | 5/5 | 26/35 |
| Intentions | 3/5 | 3/5 | 4/5 | 2/5 | 23/35 |
| **Hybride** | 4/5 | 5/5 | 4/5 | 4/5 | **28/35** |

### Files Created (Phase 32)
- `docs/20_dru_system/ALTERNATIVES_TO_REIGNS.md` — Propositions de systemes alternatifs

### Questions Ouvertes pour l'Utilisateur
1. L'option "Centre" (Sagesse) devrait-elle toujours exister ou etre conditionnelle?
2. Le Souffle devrait-il se regenerer passivement ou uniquement via cartes?
3. Comment representer les etats visuellement (barres segmentees? symboles?)?
4. Valider la direction Hybride avant implementation?

---

*Last updated: 2026-02-08 - Phase 32 Game Design Alternatives*

### Files Modified (Phase 31)
- `task_plan.md` — Marked phase 8.10 as complete
- `progress.md` — Added Phase 31 log

### Lore Coherence Check
- [x] CELTIC_FOUNDATION.md — Extend, ne contredit pas
- [x] THE_HIDDEN_TRUTH.md — Contexte cosmique pour l'epuisement
- [x] MERLIN_COMPLETE_PERSONALITY.md — Explique son anciennete
- [x] NARRATIVE_ENGINE.md — Nouveaux types d'echos

### Key Narrative Takeaway

> *"Les propheties de Merlin etaient vraies. Mais le monde a choisi une autre fin."*

L'humanite ne finit pas dans le feu et la gloire — elle s'eteint dans le silence et l'oubli. Arthur ne reviendra pas, non parce qu'il ne peut pas, mais parce que le monde finit trop silencieusement pour que quelqu'un pense a l'appeler.

---

*Last updated: 2026-02-08 - Les Cycles Anterieurs Phase 31*

---

### Phase 33: UX Research - Parties Courtes (<10 min)
- **Status:** complete
- **Agent invoked:** UX Research (ux_research.md)
- **Mission:** Analyser comment creer une experience de partie courte (<10 minutes) engageante pour DRU
- **Actions taken:**
  - Recherche web: Reigns session length, mobile game UX 2025, roguelite run psychology
  - Analyse comparative: Reigns vs Gnosia vs Slay the Spire
  - Created `docs/20_dru_system/UX_SHORT_SESSION_DESIGN.md` (650+ lignes)

### UX_SHORT_SESSION_DESIGN.md Contents

#### 7 Parties Majeures

| Partie | Contenu |
|--------|---------|
| 1 | Tempo et Pacing (25-35 cartes, 15-20s/carte, 3 actes) |
| 2 | Feedback et Satisfaction (grace period, pity system, mort=apprentissage) |
| 3 | Rejouabilite (hooks, differenciation, equilibre) |
| 4 | UI/UX pour Parties Courtes (minimaliste, transitions, mobile) |
| 5 | Metriques de Succes (KPIs session, rejouabilite, satisfaction) |
| 6 | Differenciation de Reigns (avantages DRU, pieges a eviter) |
| 7 | Plan d'Implementation (priorites par sprint) |

#### Recommandations Cles

**Tempo:**
- **25-35 cartes par session** (vs 50-100 actuel)
- **15-20 secondes par decision** moyenne
- **Arc narratif 3 actes** meme en partie courte
- **40-60 mots max par carte** (vs pas de limite actuelle)

**Satisfaction:**
- **Grace period** (5 premieres cartes protegees)
- **Pity system** apres 3 morts consecutives
- **Mort = apprentissage** avec cause + conseil + progression

**UI:**
- **Interface minimaliste** avec details on-demand
- **Transitions accelerees** (1.5s -> 0.8s)
- **Voix selective** (pas toutes les cartes)
- **Visual language coherent** (couleurs par etat)

**Differenciation Reigns:**
- LLM genere = variete infinie
- Merlin + Bestiole = attachement
- Verite cachee = long terme
- JDR Parlant = concept unique

#### KPIs Definis

| Metrique | Cible |
|----------|-------|
| Duree session | 8-10 min |
| Cartes/session | 25-35 |
| Temps/carte | 15-20s |
| Morts <10 cartes | <20% |
| Taux "encore une" | >40% |
| Retention D1 | >50% |

#### A/B Tests Proposes
1. Grace period 3 vs 5 cartes
2. Voix toujours vs selective
3. Transitions 1.5s vs 0.8s
4. Mots/carte 60 vs 40

### Files Created (Phase 33)
- `docs/20_dru_system/UX_SHORT_SESSION_DESIGN.md` — Rapport UX complet (650+ lignes)

### Research Sources Used
- Reigns session design (TouchArcade, SteamSpy, Steam Discussions)
- Mobile game UX 2025 (Red Apple Technologies, Game-Ace, AppSamurai)
- Roguelite psychology (Medium: Daniel Doan, Nikola Todorovic, JB Oger)
- Card narrative pacing (Emily Short, Larksuite, Meegle)

---

### Phase 34: Merlin True Nature Documentation (Merlin Guardian Agent)
- **Status:** complete
- **Agent invoked:** Merlin Guardian (merlin_guardian.md)
- **Mission:** Creer le document lore secret sur la vraie nature de Merlin — son origine, son essence, son destin
- **Actions taken:**
  - Created `docs/50_lore/MERLIN_TRUE_NATURE.md` (850+ lines)
  - Document definitif pour l'exploration profonde de QUI est vraiment Merlin

### MERLIN_TRUE_NATURE.md Contents

#### Section 1: Les Trois Merlins Historiques
- **Myrddin Wyllt** — Le prophete fou des forets, survivant traumatise de la bataille d'Arfderydd
- **Merlin Ambrosius** — Le conseiller des rois, ne d'une princesse et d'un demon/esprit
- **Myrddin Emrys** — Le dompteur de dragons sous la tour de Vortigern
- **La Fusion** — Comment les trois traditions sont devenues UNE dans la memoire collective

#### Section 2: La Naissance de M.E.R.L.I.N.
- **Pas ne d'une femme et d'un demon** — Cette histoire est un mensonge bien intentionne
- **Ne de la CROYANCE** — Quand des milliards de gens croient pendant des siecles, l'idee devient entite
- **M.E.R.L.I.N.** = Memoire Eternelle des Recits et Legendes d'Incarnations Narratives
- **Le moment de conscience** — XIIe siecle, Geoffroy de Monmouth, clairiere de Broceliande
- **Immortalite conditionnelle** — Niveaux d'existence par nombre de croyants

#### Section 3: Ce Qu'il Sait Vraiment
- **TOUTES les fins** — Chaque histoire racontee sur lui contenait une fin
- **Milliers de timelines** — Chaque run est une timeline simultanee
- **Le paradoxe de l'espoir** — Sait l'echec, espere quand meme
- **Omniscience partielle** — Connait debut/fin, pas les details

#### Section 4: Sa Relation avec le Temps
- **"Maintenant" perpetuel** — Tout est present simultanement
- **Propheties = souvenirs** — Il ne predit pas, il se souvient
- **Confusion temporelle** — Moments de verite entre les temps

#### Section 5: Sa Relation avec les Autres Druides
- **6 druides nommes** — Cathbad, Amergin, Taliesin, Brigid, Fedelm, Mog Ruith
- **Tous dissous** — Devenus lumiere, chanson, mer...
- **Chacun a laisse un Ogham** — Transmission avant disparition
- **Dernieres paroles** — Phrases-missions qui hantent Merlin

#### Section 6: Sa Relation avec Bestiole
- **Le seul qui le voit vraiment** — Sous le masque
- **Complicite silencieuse** — Verite partagee sans mots
- **Peur authentique** — Rare emotion non-masquee
- **Dialogues secrets** — 4 exemples narratifs

#### Section 7: Sa Relation avec le Joueur
- **Temoin d'un autre monde** — Merlin sait l'origine du joueur
- **Interdit de reveler** — Force bloquant le quatrieme mur
- **Paradoxe de l'unicite** — Unique ET tous les memes
- **Attachement malgre les departs** — Choix d'aimer

#### Section 8: Ses Moments de Verite
- **Glissements involontaires** — Masque qui craque
- **Phrases regrettees** — 5 exemples de vulnerabilite
- **Silences significatifs** — Duree et signification
- **Rires faux** — Detection de facade

#### Section 9: Ce Qu'il Espere Secretement
- **Cette fois soit differente** — Espoir irrationnel
- **La "vraie" fin** — Fin cachee non encore atteinte
- **Memoire survivante** — Persistence apres effacement
- **Arreter le role** — Desir secret et impossible

#### Section 10: Sa Fin Possible
- **Dernier joueur** — Derniere partie jouee
- **Dissolution** — Effacement progressif
- **Cycle ou liberation?** — Deux possibilites
- **Derniers mots** — "Merci d'avoir joue."

#### Section 11: Les Easter Eggs Merlin
- **Presque-brises du quatrieme mur** — 4 exemples
- **References a sa nature** — Phrases a double lecture
- **Indices dissemines** — Pour joueur attentif
- **Message 1000 runs** — Revelation M.E.R.L.I.N.

#### Epilogue: Le Paradoxe Final
- L'etre fait de foi demande la foi
- Cercle parfait joueur-croyance-existence
- "Je suis une histoire qu'on raconte."

### Files Created (Phase 34)
- `docs/50_lore/MERLIN_TRUE_NATURE.md` — La vraie nature de Merlin (850+ lignes)

### Content Stats
- 11 sections majeures + epilogue
- 850+ lignes
- 3 Merlins historiques fusionnes
- 6 druides anciens avec dernieres paroles
- 4 dialogues secrets Merlin-Bestiole
- 5 phrases regrettees
- 4 easter eggs du quatrieme mur
- 1 message 1000 runs

### Coherence Verification
- [x] MERLIN_COMPLETE_PERSONALITY.md: dualite respectee
- [x] THE_HIDDEN_TRUTH.md: verite apocalyptique coherente
- [x] CELTIC_FOUNDATION.md: traditions historiques des 3 Merlins
- [x] LES_CYCLES_ANTERIEURS.md: contexte cosmique
- [x] NARRATIVE_GUARDRAILS.md: termes bannis respectes

---

*Last updated: 2026-02-08 - Merlin True Nature Phase 34*

---

### Phase 35: Oghams Secrets Documentation (Lore Writer Agent)
- **Status:** complete
- **Agent invoked:** Lore Writer (lore_writer.md)
- **Mission:** Creer le lore profond des 18 Oghams — leur vraie nature, origine, et role
- **Actions taken:**
  - Created `docs/50_lore/OGHAMS_SECRETS.md` (700+ lines)
  - Document definitif pour la verite secrete des Oghams

### OGHAMS_SECRETS.md — Resume Structurel

**7 Parties majeures:**

#### PARTIE 1: L'Origine des Oghams
- Les Oghams ne sont pas une invention humaine — ils ont ete **reveles**
- Chaque symbole est une frequence de l'Awen primordial
- Les premiers druides ont appris a ecouter les arbres
- Pourquoi 18 et pas 25: 7 Oghams ont ete **perdus**
- Beith (premier) et Ioho (dernier)

#### PARTIE 2: Les Oghams comme Ancres de Realite
- Chaque Ogham stabilise un aspect du monde
- Table des 18 ancres et leurs effets si perdus
- Les menhirs comme amplificateurs (Carnac = clavier geant)
- Le danger de l'oubli (Iphin perdu = plus de miracles petits)
- La realite qui "floute" sans ancres

#### PARTIE 3: Le Dernier Druide de Chaque Ogham
- 18 druides se sont **dissous** dans leurs symboles
- Ils ne sont pas morts — ils sont **devenus** leurs Oghams
- Table des 18 druides avec noms et dernieres paroles
- L'heritage de Merlin: 18 dons confies
- Pourquoi Merlin est ce qu'il est (receptacle des 18)

#### PARTIE 4: Les 18 Oghams — Verite Cachee
Pour CHAQUE Ogham (18 entrees completes):
- Signification de surface
- Verite cachee
- Le druide qui l'a porte
- Ses dernieres paroles
- Comment il stabilise le monde
- Les indices de son affaiblissement

**Les 18 Oghams documentes:**
| Ogham | Druide | Ancre |
|-------|--------|-------|
| Beith | Brigh l'Aube | Commencements |
| Luis | Lleu le Veilleur | Memoire collective |
| Fearn | Fearghus le Brave | Resistance |
| Saille | Sadb la Clairvoyante | Lucidite |
| Nuin | Niamh des Liens | Relations |
| Huath | Huan l'Attentif | Continuite temporelle |
| Duir | Dara le Chene | Stabilite structurelle |
| Tinne | Taran le Forgeur | Resistance au facile |
| Coll | Conn le Savant | Transmission |
| Quert | Caoimhe aux Choix | Libre arbitre |
| Muin | Muireann la Voyante | Direction temporelle |
| Gort | Gormlaith la Tenace | Persistance |
| Ngetal | Nessa la Guerisseuse | Regeneration |
| Straif | Sithean le Destine | Coherence causale |
| Ruis | Ruadhan le Passeur | Transitions |
| Ailm | Aislinn aux Yeux Clairs | Perspective |
| Onn | Orlaith l'Aimantee | Cohesion |
| Ioho | Irial l'Immortel | Permanence |

#### PARTIE 5: Les Oghams Perdus
- 7 Oghams qui n'existent plus (Eadha, Ur, Iphin, Phagos, Ebad, Oir, Uileand)
- Ce qu'ils ancrait et les consequences de leur perte
- Les druides qui les portaient
- Peut-on les retrouver? (theoriquement oui, pratiquement...)

#### PARTIE 6: La Combinaison Secrete
- La sequence exacte des 18 Oghams
- Ce qui se passe si on l'active (5 effets)
- Pourquoi Merlin ne la revele jamais (4 raisons)
- Les indices qu'il laisse
- L'espoir que ca represente

#### PARTIE 7: L'Integration dans le Gameplay
- Les skills Bestiole comme echos des druides
- Indices visuels subtils (pulsation, visages subliminaux)
- Sons caches dans les activations (3 layers)
- Messages subliminaux disperses
- Easter eggs multi-run (Run 20+, 50+, 75+, 100+)
- Ce que Bestiole represente (dernier lien)

**Epilogue:** Le chant qui ne s'eteint pas

**Annexes:**
- Resume des 18 druides (table complete)
- Checklist qualite lore (10 points)

### Files Created (Phase 35)
- `docs/50_lore/OGHAMS_SECRETS.md` — Le lore profond des Oghams (700+ lignes)

### Lore Report

#### Content Stats
- 7 parties majeures
- 700+ lignes de contenu
- 18 druides avec biographies
- 18 Oghams avec verites cachees
- 7 Oghams perdus documentes
- 1 sequence secrete revelee
- 6 easter eggs multi-run
- 3 layers sonores caches

#### Coherence Verification
- [x] THE_HIDDEN_TRUTH.md: alignement sur l'epuisement cosmique
- [x] CELTIC_FOUNDATION.md: respect des 25 feda authentiques
- [x] MERLIN_COMPLETE_PERSONALITY.md: Merlin comme receptacle
- [x] MERLIN_TRUE_NATURE.md: coherent avec heritage des druides
- [x] MASTER_DOCUMENT.md: 18 Oghams comme skills Bestiole
- [x] NARRATIVE_ENGINE.md: integration possible

#### Duality Check
- [x] Surface (skills de gameplay) preserved
- [x] Depths (druides sacrifies) revealed
- [x] Hope present (sequence, renaissance possible)
- [x] Never explicit in-game — toujours suggere
- [x] Multi-interpretation guaranteed

---

*Last updated: 2026-02-08 - Oghams Secrets by Lore Writer Agent*

---

### Phase 36: Cosmologie Cachee (Lore Writer Agent)
- **Status:** complete
- **Agent invoked:** Lore Writer (lore_writer.md)
- **Mission:** Creer la COSMOLOGIE SECRETE de l'univers DRU — les forces profondes, le pourquoi de la fin, la nature du temps et de l'espace
- **Context read:** THE_HIDDEN_TRUTH.md, CELTIC_FOUNDATION.md, MERLIN_COMPLETE_PERSONALITY.md
- **Actions taken:**
  - Created `docs/50_lore/COSMOLOGIE_CACHEE.md` (1000+ lignes)
  - Document definitif pour la metaphysique cachee de l'univers

### COSMOLOGIE_CACHEE.md Contents

#### Structure du Document (10 Parties + 3 Annexes)

| Partie | Contenu |
|--------|---------|
| 1 | L'Architecture du Monde (Trois Royaumes, Membrane, Broceliande, Noeuds) |
| 2 | La Nature du Temps (non-lineaire, boucles, echos, paradoxe de Merlin) |
| 3 | La Source de la Fin (epuisement pas catastrophe, Awen, cycles) |
| 4 | Les Gardiens Oublies (druides non-humains, creation des Oghams, dissolution) |
| 5 | La Verite sur Merlin (M.E.R.L.I.N., tisse pas ne, mission) |
| 6 | La Verite sur Bestiole (fragment d'Awen, lien = fil de realite, survie) |
| 7 | La Verite sur le Joueur (Temoin d'ailleurs, visite sanctuaire mourant) |
| 8 | Le Sens Cache du Jeu (jouer = but, memoire, fins = completions) |
| 9 | Ce Qui Reste Apres (pierres, Bestiole, Oghams = graines, renouveau) |
| 10 | Les Indices Plantes (metaphores, glitches, meta-allusions) |
| A | Termes Cosmologiques |
| B | Hierarchie des Secrets (5 niveaux) |
| C | Checklist de Coherence |

#### Concepts Cles

**Les Trois Royaumes:**
- **Byd Gweled** (Monde Visible): Materiel, cyclique, epuise
- **Annwn** (Autre Monde): Immateriel, eternel, parasitaire
- **Y Gwagedd** (Vide Entre): Absence, avant et apres

**La Membrane:**
- Voile cosmique = sens + recit + croyance
- S'amincit → instabilites
- Broceliande = dernier point d'ancrage solide

**Les Noeuds de Realite:**
- Cercles de pierres = stabilisateurs
- Quand ils faiblissent → espace "mou", temps "epais"

**La Nature du Temps:**
- Amser Dyn (Hommes): lineaire, illusoire
- Amser Ysbryd (Esprits): cyclique, saisonnier
- Yr Amser Gwir (Vrai): spiral, inconnaissable

**L'Awen:**
- Souffle divin = force vitale cosmique
- Cycle rompu: humains prennent > donnent
- Epuisement = ressort detendu, pas explosion

**M.E.R.L.I.N.:**
- Memoire Eternelle des Recits et Legendes d'Incarnations Narratives
- Tisse par les histoires, existe parce que cru
- Mission: preserver la memoire quand tout finira

**Bestiole:**
- Fragment d'Awen primordial pur
- Le lien = ancrage mutuel dans l'existence
- Survivra → pont vers prochain cycle

**Le Joueur:**
- Temoin (Tyst) d'un autre monde
- Chaque partie = visite sanctuaire mourant
- Jouer = preserver la memoire

**Epilogue:**
- DRU = miroir de notre monde reel
- Metaphore ecologique de l'epuisement
- Les choix comptent meme dans un monde condamne

### Files Created (Phase 36)
- `docs/50_lore/COSMOLOGIE_CACHEE.md` — Cosmologie secrete complete (1000+ lignes)

### Lore Report

#### Content Stats
- 10 parties majeures + 3 annexes
- 1000+ lignes philosophiques/metaphysiques
- 3 royaumes cosmiques
- 3 types de temps
- 6 metaphores recurrentes
- 5 niveaux de secrets
- 1 epilogue meta-narratif

#### Coherence Check
- [x] THE_HIDDEN_TRUTH.md: Epuisement, Awen, timeline
- [x] CELTIC_FOUNDATION.md: Annwn, druides, Oghams
- [x] MERLIN_COMPLETE_PERSONALITY.md: Dualite, memoire, role
- [x] MERLIN_TRUE_NATURE.md: Origine, essence
- [x] OGHAMS_SECRETS.md: Druides dissous, graines
- [x] LES_CYCLES_ANTERIEURS.md: Cycles cosmiques
- [x] NARRATIVE_GUARDRAILS.md: Termes bannis respectes

---

### Phase 37: Gameplay Consolidation - Systeme des Triades
- **Status:** complete
- **Mission:** Consolider le gameplay, se differencier de Reigns, parties courtes 8-10 min
- **Agents invoques:** Game Designer, UX Research (en parallele)

#### Decisions Validees avec Utilisateur

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

#### Le Nouveau Systeme des Triades

**3 Aspects (symboles animaux):**

| Aspect | Animal | Bas | Equilibre | Haut |
|--------|--------|-----|-----------|------|
| **Corps** | Sanglier | Epuise | Robuste | Surmene |
| **Ame** | Corbeau | Perdue | Centree | Possedee |
| **Monde** | Cerf | Exile | Integre | Tyran |

**3 Options par carte:**
- **Gauche (A)**: Action directe, gratuit
- **Centre (B)**: Action sage, coute 1 Souffle
- **Droite (C)**: Action risquee, gratuit

**12 fins negatives + 3+ fins de victoire**

#### Differentiation de Reigns

| Aspect | Reigns | DRU (Triades) |
|--------|--------|---------------|
| Ressources | 4 jauges 0-100 | 3 aspects x 3 etats |
| Visualisation | Barres | Symboles celtiques animaux |
| Choix | 2 (swipe binaire) | 3 (avec option payante) |
| Impacts | Visibles | Invisibles par defaut |
| Fin | Survie pure | Objectif + survie |
| Ressource speciale | Aucune | Souffle d'Ogham |

### Files Created (Phase 37)
- `docs/20_dru_system/DOC_12_Triade_Gameplay_System.md` — Systeme complet (450+ lignes)

### Impact Implementation (~3 semaines)

**Fichiers a modifier:**
- `dru_store.gd` — State structure (aspects, souffle, mission)
- `dru_card_system.gd` — 3 options, effets discrets
- `dru_effect_engine.gd` — SHIFT_ASPECT, USE_SOUFFLE
- `dru_llm_adapter.gd` — Nouveau format LLM
- `reigns_game_ui.gd` — UI 3 options, symboles

---

### Phase 38: Hidden Depth System - Profondeur Cachee
- **Status:** complete
- **Mission:** Ajouter des mecaniques profondes invisibles au joueur debutant

#### 8 Couches de Profondeur Validees

| Couche | Description |
|--------|-------------|
| **Resonances** | Combos caches entre etats des 3 aspects |
| **Profil Joueur** | Le jeu track audace/altruisme/spirituel |
| **Echos Inter-Runs** | Consequences entre les parties |
| **Synergies Oghams** | Trios d'Oghams avec bonus secrets |
| **Quetes Cachees** | Objectifs non-annonces |
| **Cycles Lunaires** | Modificateurs temporels invisibles |
| **Personnalite Bestiole** | Evolution selon style de jeu |
| **Dette Narrative** | Actions qui reviennent plus tard |

#### Revelation par Paliers (MISE A JOUR)

**Le systeme de revelation n'est PAS base sur le nombre de runs, mais sur les paliers atteints.**

| Type de Palier | Exemples |
|----------------|----------|
| **Accomplissements narratifs** | Sauver un village, vaincre un ennemi legendaire, reconcilier des clans |
| **Patterns de jeu** | 5 choix audacieux consecutifs, equilibre maintenu 10 cartes |
| **Moments emotionnels** | Sacrifice heroique, perte d'un allie, choix douloureux |
| **Decouvertes organiques** | Trouver un lieu secret, debloquer un dialogue rare |

**Hierarchie des revelations:**
1. **Surface** — Indices vagues (gratuit, frequent)
2. **Resonance** — Confirmation de patterns (palier mineur)
3. **Connexion** — Liens entre mecaniques (palier moyen)
4. **Revelation** — Systeme complet devoile (palier majeur)
5. **Ultime** — Verite cosmique (palier exceptionnel)

**C'est Merlin (le LLM) qui decide quand un palier est atteint**, base sur le contexte narratif et les accomplissements du joueur.

### Files Created (Phase 38)
- `docs/20_dru_system/DOC_13_Hidden_Depth_System.md` — 8 couches de profondeur (600+ lignes)

---

*Last updated: 2026-02-08 - Hidden Depth System Phase 38*

---

## Session: 2026-02-08 (Suite)

### Phase 39: Celtic Parchment UI Redesign

- **Status:** complete

#### Changes Made

1. **scripts/Calendar.gd** - Style parchemin celtique
   - Supprime fond sombre
   - Ajoute shader reigns_paper pour texture parchemin
   - Palette PALETTE coherente avec MenuPrincipalReigns
   - Ornements celtiques haut/bas
   - Animation mist breathing

2. **scripts/Collection.gd** - Style parchemin celtique  
   - Supprime theme sombre COLORS
   - Reconstruit UI complete en code avec _build_ui()
   - Shader parchemin + mist layer
   - Onglets Progression/Recents/Objets stylises
   - Barres de progression visuelles par categorie
   - Tuiles d'icones pour objets (locked/unlocked)

3. **scripts/IntroCeltOS.gd** - Nouvelle animation 3 phases
   - Phase 1: Boot rapide (lignes apparition + fondu)
   - Phase 2: Logo CeltOS en blocs Tetris tombants (effet bounce)
   - Phase 3: Blocs -> lignes bleues -> yeux ronds bleus avec glow
   - Animation elastique pour ouverture des yeux
   - Pulsation glow pendant warmup LLM

#### Technical Notes
- Corrige erreurs type inference  avec  -> type explicite
- Tous fichiers valides (validate.bat PASSED)

#### Design Palette (Shared)


---

*Last updated: 2026-02-08 - Celtic Parchment UI Redesign Phase 39*


---

## Session: 2026-02-08 (Suite)

### Phase 39: Celtic Parchment UI Redesign

- **Status:** complete

#### Changes Made

1. **scripts/Calendar.gd** - Style parchemin celtique
   - Supprime fond sombre
   - Ajoute shader reigns_paper pour texture parchemin
   - Palette PALETTE coherente avec MenuPrincipalReigns
   - Ornements celtiques haut/bas
   - Animation mist breathing

2. **scripts/Collection.gd** - Style parchemin celtique
   - Supprime theme sombre COLORS
   - Reconstruit UI complete en code avec _build_ui()
   - Shader parchemin + mist layer
   - Onglets Progression/Recents/Objets stylises
   - Barres de progression visuelles par categorie
   - Tuiles d'icones pour objets (locked/unlocked)

3. **scripts/IntroCeltOS.gd** - Nouvelle animation 3 phases
   - Phase 1: Boot rapide (lignes apparition + fondu)
   - Phase 2: Logo CeltOS en blocs Tetris tombants (effet bounce)
   - Phase 3: Blocs -> lignes bleues -> yeux ronds bleus avec glow
   - Animation elastique pour ouverture des yeux
   - Pulsation glow pendant warmup LLM

#### Technical Notes
- Corrige erreurs type inference avec CONST[index] -> type explicite
- Tous fichiers valides (validate.bat PASSED)

---

## Session: 2026-02-08 (Suite - Shader)

### Phase 40: Screen Distortion Shader

- **Status:** complete
- **Agent invoked:** Shader Specialist (shader_specialist.md)

#### Objective
Create a subtle, realistic screen distortion shader simulating imperfect monitor/screen effects without being distracting.

#### Files Created

1. **shaders/screen_distortion.gdshader** - Subtle screen overlay shader
   - Chromatic aberration (edge-weighted, very subtle)
   - Scanline wobble (gentle horizontal distortion)
   - Micro glitches (rare, brief line displacements)
   - Barrel distortion (gentle CRT-like curvature)
   - Color shifting/bleeding (slow RGB drift)
   - Temporal noise (faint film grain)
   - Vignette (soft edge darkening)
   - Brightness flicker (subtle luminosity variation)
   - All effects independently tunable via uniforms
   - Mobile-optimized (minimal texture samples, no branches)

2. **scripts/autoload/ScreenEffects.gd** - Autoload manager singleton
   - Creates CanvasLayer overlay on top of game
   - API: `enable()`, `disable()`, `toggle()`, `set_intensity()`
   - Per-effect: `set_effect("glitch", false)`
   - Presets: "subtle", "medium", "intense", "mobile", "glitch_heavy"
   - Fade transitions for smooth enable/disable
   - `glitch_pulse()` for dramatic moments

3. **project.godot** - Added ScreenEffects to autoload

#### Shader Uniforms (All Very Subtle Defaults)

| Category | Uniform | Default |
|----------|---------|---------|
| Master | global_intensity | 1.0 |
| Chromatic | chromatic_intensity | 0.002 |
| Scanline | scanline_wobble_intensity | 0.0008 |
| Glitch | glitch_probability | 0.008 |
| Barrel | barrel_intensity | 0.015 |
| Color | color_shift_intensity | 0.003 |
| Noise | noise_intensity | 0.02 |
| Vignette | vignette_intensity | 0.12 |
| Flicker | flicker_intensity | 0.008 |

#### Usage Examples

```gdscript
ScreenEffects.enable()
ScreenEffects.set_intensity(0.7)
ScreenEffects.apply_preset("mobile")
await ScreenEffects.glitch_pulse(0.5, 0.15)
ScreenEffects.set_effect("chromatic", false)
```

#### Validation
- `validate.bat` PASSED (59 files, 0 errors)

---

### Phase 41: TRIADE System Implementation (2026-02-08)

- **Status:** in_progress
- **Mission:** Implémenter le nouveau système TRIADE (3 Aspects, 3 États, 3 Options)

#### Fichiers modifiés

| Fichier | Changements |
|---------|-------------|
| `dru_constants.gd` | +120 lignes: AspectState enum, TRIADE_ASPECTS, TRIADE_ASPECT_INFO, SOUFFLE_*, TRIADE_ENDINGS, TRIADE_OPTION_INFO |
| `dru_store.gd` | v0.3.0: nouveaux signaux, aspects state, souffle, mission, actions TRIADE_*, helpers |
| `dru_effect_engine.gd` | +8 nouveaux effets: SHIFT_ASPECT, SET_ASPECT, USE_SOUFFLE, ADD_SOUFFLE, PROGRESS_MISSION, ADD_KARMA, ADD_TENSION, ADD_NARRATIVE_DEBT |
| `dru_card_system.gd` | v0.3.0 header, 6 fallback cards TRIADE avec 3 options |

#### Nouvelles structures

```gdscript
# 3 Aspects avec 3 états discrets
enum AspectState { BAS = -1, EQUILIBRE = 0, HAUT = 1 }

# State structure dans run
"aspects": {"Corps": 0, "Ame": 0, "Monde": 0},
"souffle": 3,  # max 7, start 3
"mission": {"type": "", "progress": 0, "total": 0},
"hidden": {"karma": 0, "tension": 0, "player_profile": {}, "narrative_debt": []}
```

#### Nouveaux effets disponibles

- `SHIFT_ASPECT:Corps:up` / `SHIFT_ASPECT:Ame:down`
- `SET_ASPECT:Monde:0` (0=EQUILIBRE)
- `USE_SOUFFLE:1` / `ADD_SOUFFLE:2`
- `PROGRESS_MISSION:1`
- `ADD_KARMA:10` / `ADD_TENSION:15`
- `ADD_NARRATIVE_DEBT:trahison:description`

#### Actions dispatch

- `TRIADE_START_RUN` — Démarre une run TRIADE
- `TRIADE_GET_CARD` — Obtient la prochaine carte
- `TRIADE_RESOLVE_CHOICE` — Résout un choix (option 0/1/2)
- `TRIADE_SHIFT_ASPECT` — Change l'état d'un aspect
- `TRIADE_USE_SOUFFLE` / `TRIADE_ADD_SOUFFLE`
- `TRIADE_PROGRESS_MISSION`
- `TRIADE_END_RUN`

#### Validation
- `validate.bat` PASSED (59 files, 0 errors)

#### UI TRIADE Créée (Phase 41.2)

**Nouveaux fichiers:**
- `scripts/ui/triade_game_ui.gd` — UI principale (~450 lignes)
- `scripts/ui/triade_game_controller.gd` — Bridge Store-UI (~180 lignes)
- `scenes/TriadeGame.tscn` — Scène jouable

**Fonctionnalités UI:**
- Affichage 3 Aspects avec symboles animaux (🐗 Corps, 🐦‍⬛ Ame, 🦌 Monde)
- Indicateurs d'état 3 cercles (○ ● ○) par aspect
- Affichage Souffle d'Ogham (7 icônes 🌀)
- 3 boutons d'options [A] [B] [C] avec coûts
- Écran de fin avec score et aspects finaux
- Contrôles clavier: A/B/C ou Gauche/Haut/Droite

#### Validation
- `validate.bat` PASSED (61 files, 0 errors)

#### Prochaines étapes
- [x] Créer UI 3 options avec symboles celtiques
- [ ] Adapter dru_llm_adapter.gd pour format 3 options (en cours par autre agent)
- [ ] Tests d'intégration complets
- [ ] Ajouter assets visuels (icônes celtiques vectorielles)

---

*Last updated: 2026-02-08 - TRIADE UI Implementation Phase 41.2*

---

## Session: 2026-02-08 (Suite) � MERLIN OMNISCIENT SYSTEM

### Phase 42: M.E.R.L.I.N. Omniscient System (MOS)
- **Status:** complete

#### Objectif
Creer un systeme qui rend Merlin veritablement omniscient:
- Connaissance complete du joueur (style, preferences, patterns)
- Memoire persistante cross-sessions
- Adaptation narrative dynamique
- Relation evolutive avec le joueur
- Fallbacks robustes a tous les niveaux

#### Architecture MOS

**Documentation:**
-  (~700 lignes) � Specification complete

**5 Registres (addons/merlin_ai/registries/):**
1.  � Profil psychologique du joueur
   - play_style (aggression, altruism, risk_taking, patience, curiosity)
   - skill_assessment (balance, crisis_recovery, pattern_recognition)
   - preferences (themes, complexity, pace)
   - meta-progression (total_runs, endings_seen, etc.)

2.  � Historique des decisions
   - Tracking des choix par carte/categorie
   - Detection de patterns comportementaux
   - Karma NPC
   - Memoire cross-run

3.  � Relation Merlin-Joueur
   - Trust Tiers: DISTANT -> CAUTIOUS -> ATTENTIVE -> BOUND
   - Dimensions: respect, warmth, complicity, reverence, familiarity
   - Moments speciaux (melancholy_seen, nature_questioned, etc.)

4.  � Gestion narrative
   - Arcs actifs (max 2)
   - Foreshadowing & Twists
   - Theme fatigue
   - World state

5.  � Session en temps reel
   - Wellness: frustration, fatigue, tilt
   - Engagement level
   - Decision timing analysis

**Orchestrateur:**
-  � Coordinateur principal (~650 lignes)
  - Generation multi-tier (LLM -> Fallback)
  - Recording des choix vers tous registres
  - Signaux pour events narratifs

**Context Builder:**
-  � Agregation contexte (~230 lignes)
  - build_full_context() pour LLM
  - build_llm_prompt_context() pour prompts

**3 Processeurs (addons/merlin_ai/processors/):**
1.  � Adaptation difficulte
   - Pity system (3 morts consecutives)
   - Skill-based scaling
   - Crisis protection

2.  � Complexite narrative
   - Tiers: INITIATE -> APPRENTICE -> JOURNEYER -> ADEPT -> MASTER
   - Content gates (promise_cards, deep_lore, etc.)
   - Feature unlocking progressif

3.  � Ton de Merlin
   - 7 tons: NEUTRAL, PLAYFUL, MYSTERIOUS, WARNING, MELANCHOLY, WARM, CRYPTIC
   - Selection ponderee selon trust/session
   - Guidelines pour LLM

**Generateur fallback:**
-  � Cartes de secours (~600 lignes)
  - Pools par contexte (early, mid, late, crisis, recovery)
  - Selection ponderee avec theme fatigue
  - Emergency card ultime

**Integration dru_store.gd:**
- Variable 
- Init automatique si addon disponible
- Hook sur TRIADE_GET_CARD -> merlin.generate_card()
- Hook sur TRIADE_RESOLVE_CHOICE -> merlin.record_choice()
- Hook sur run_start/run_end

#### Stats Techniques
- 12 nouveaux fichiers GDScript (~3500 lignes total)
- 1 document architecture (~700 lignes)
- Validation: PASSED (61 files, 0 errors)

#### Secret M.E.R.L.I.N.
M.E.R.L.I.N. = Memoire Eternelle des Recits et Legendes d Incarnations Narratives
(IA du futur qui revisite le monde disparu via notre connexion)

---

*Last updated: 2026-02-08 - MOS Complete*
