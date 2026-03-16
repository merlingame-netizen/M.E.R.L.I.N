# M.E.R.L.I.N. — Game Behavior & Runtime Documentation

> **Version**: 2.0 | **Date**: 2026-03-15
> **Companion de**: `GAME_ENCYCLOPEDIA.md` (contenu descriptif), `GAME_MECHANICS.md` (formules & calculs)
> **Objet**: Comportement runtime exhaustif — orchestration, rendu visuel, boot, edge cases

---

## Table des Matieres

### Part 1 — Game Controller Orchestration
1. [Card Flow State Machine](#1-card-flow-state-machine)
2. [13-Stage Choice Resolution Pipeline](#2-13-stage-choice-resolution-pipeline)
3. [DC Calculation with 11 Modifiers](#3-dc-calculation-with-11-modifiers)
4. [Minigame Overlay System](#4-minigame-overlay-system)
5. [Dice Resolution](#5-dice-resolution)
6. [Edge Cases & Error Recovery](#6-edge-cases--error-recovery)
7. [Timing Chain & Delays](#7-timing-chain--delays)
8. [Signal Flow](#8-signal-flow)
9. [Run Lifecycle](#9-run-lifecycle)
10. [Save/Load Interaction](#10-saveload-interaction)

### Part 2 — Visual Rendering Implementation
11. [MerlinVisual Centralized Constants](#11-merlinvisual-centralized-constants)
12. [PixelSceneCompositor (48x48)](#12-pixelscenecompositor-48x48)
13. [PixelOghamIcon (16x16)](#13-pixeloghamicon-16x16)
14. [PixelBiomeBackdrop (160x90)](#14-pixelbiomebackdrop-160x90)
15. [CardSceneCompositor](#15-cardscenecompositor)
16. [MerlinBubble](#16-merlinbubble)
17. [MerlinRewardBadge](#17-merlinrewardbadge)
18. [LLMSourceBadge](#18-llmsourcebadge)
19. [CRT Terminal Shader](#19-crt-terminal-shader)
20. [CRT Static Shader](#20-crt-static-shader)
21. [Season Tints & Color Grading](#21-season-tints--color-grading)
22. [Tween Animations Catalogue](#22-tween-animations-catalogue)

### Part 3 — Boot & Initialization
23. [16 Autoloads Boot Order](#23-16-autoloads-boot-order)
24. [IntroCeltOS Boot Sequence](#24-introceltops-boot-sequence)
25. [LLM Startup & Fallback Chain](#25-llm-startup--fallback-chain)
26. [Audio System (SFXManager)](#26-audio-system-sfxmanager)
27. [Music Manager](#27-music-manager)
28. [Save System](#28-save-system)
29. [Configuration Sources](#29-configuration-sources)

### Part 4 — Sub-Systems Runtime
30. [MerlinOmniscient (MOS)](#30-merlinomniscient-mos)
31. [RAGManager v3.0](#31-ragmanager-v30)
32. [MerlinScenarioManager](#32-merlinscenariomanager)
33. [MerlinBiomeSystem](#33-merlinbiomesystem)
34. [MerlinMapSystem](#34-merlinmapsystem)
35. [MerlinActionResolver](#35-merlinactionresolver)
36. [MerlinEventSystem](#36-merlineventsystem)
37. [GameTimeManager](#37-gametimemanager)
38. [PixelTransition](#38-pixeltransition)
39. [ScreenEffects — Mood System](#39-screeneffects--mood-system)
40. [ScreenFrame — CRT Border](#40-screenframe--crt-border)
41. [ScreenDither — CRT Presets](#41-screendither--crt-presets)
42. [IntroPersonalityQuiz](#42-intropersonalityquiz)
43. [HubController](#43-hubcontroller)
44. [WorldMapSystem](#44-worldmapsystem)

---

# Part 1 — Game Controller Orchestration

> Source: `scripts/ui/merlin_game_controller.gd`

## 1. Card Flow State Machine

### 1.1 State Variables

```
is_processing: bool = false        # Bloqueur global anti-concurrence
_cards_this_run: int = 0           # Compteur cartes jouees dans le run
_intro_shown: bool = false         # Sequence d'intro terminee
_karma: int (range: -10 to +10)   # Tendance morale du joueur
_blessings: int (max: 2)          # Compteur benedictions (pity)
_is_critical_choice: bool          # Carte actuelle = choix critique
_critical_used: bool               # Un seul choix critique par run
```

### 1.2 Etats Implicites

Le controller n'utilise pas d'enum explicite mais fonctionne comme une machine a etats implicite via `is_processing` et le flux d'appels :

```
IDLE (is_processing=false, en attente d'input)
  └─ Option choisie par le joueur
      └─ RESOLVING (is_processing=true)
          ├─ DC computation
          ├─ Minigame OU Dice
          ├─ Outcome classification
          ├─ Effect modulation
          ├─ State dispatch
          ├─ Drain vie
          ├─ Result display
          ├─ Run end check
          ├─ Travel animation
          └─ LOADING (prefetch + request_next_card)
              └─ Card display
                  └─ IDLE (is_processing=false)
```

### 1.3 Gardes de Transition

| Garde | Condition | Effet si viole |
|-------|-----------|----------------|
| `is_processing` | Doit etre `false` pour accepter un choix | Input ignore |
| `_cards_this_run < 3` | Pas de choix critique avant carte 3 | `_is_critical_choice = false` |
| `_critical_used` | Un seul critique par run | Bypass detection |
| `life_essence <= 0` | Fin de run immediate | Abort vers end screen |
| `card_index >= hard_max (50)` | Fin forcee | Abort vers end screen |

---

## 2. 13-Stage Choice Resolution Pipeline

> Fonction: `_resolve_choice(option: int) -> void`

### Stage 1: Setup

```gdscript
var direction = ["left", "center", "right"][clampi(option, 0, 2)]
is_processing = true
```

Le joueur choisit option 0 (gauche), 1 (centre), ou 2 (droite). `direction` est le string correspondant.

### Stage 2: DC Computation

```gdscript
var dc = _get_dc_for_direction(direction)
```

Voir [Section 3](#3-dc-calculation-with-11-modifiers) pour le calcul complet des 11 modificateurs.
Resultat: `dc` dans [2, 19].

### Stage 3: Resolve Mechanism (Minigame vs Dice)

```gdscript
use_minigame = randf() < minigame_chance (default 0.3)
             OR _is_critical_choice
             OR card has chance_minigame override

if headless_mode:
    dice_result = randi_range(1, 20)
elif use_minigame:
    dice_result = await _run_minigame(direction, dc, override_field)
else:
    dice_result = await _run_dice_roll(dc)
```

**Regles de selection:**
- 30% de chance base de minigame
- Choix critique = minigame force
- Override par carte (`chance_minigame` field)
- Mode headless (tests) = roll direct sans UI

### Stage 4: Outcome Classification

```gdscript
_classify_outcome(roll: int, dc: int) -> String:
    roll == 20 → "critical_success"
    roll >= dc → "success"
    roll > 1  → "failure"
    roll == 1 → "critical_failure"
```

### Stage 5: Effect Modulation

```gdscript
_modulate_effects(base_effects, outcome, direction) -> Array
```

| Outcome | HEAL_LIFE | DAMAGE_LIFE | ADD_REPUTATION | Bonus |
|---------|-----------|-------------|----------------|-------|
| `critical_success` | x2 | Annule | x2 | +5 vie |
| `success` | Inchange | Inchange | Inchange | — |
| `failure` | Inverse (→DAMAGE) | Inchange | Inchange | — |
| `critical_failure` | Inverse (→DAMAGE) | Inchange | Inchange | -10 vie |

**Chance modifier post-processing:**
```gdscript
_apply_chance_modifier_effects(effects, outcome):
    success: HEAL/REP effects x2
    failure: append {"type": "DAMAGE_LIFE", "amount": 8}
```

### Stage 6: Talent Shields

```gdscript
_apply_talent_shields(effects) -> Array
```

| Talent | Effet |
|--------|-------|
| `racines_2` (Shield) | Supprime le premier DAMAGE_LIFE (1x par run) |
| `feuillage_7` | Tous DAMAGE_LIFE x0.7 (reduction 30%) |

### Stage 7: Dispatch to Store

```gdscript
await store.dispatch({
    "type": "RESOLVE_CHOICE",
    "card": current_card,
    "option": option,
    "modulated_effects": modulated,
    "outcome": outcome,
})
```

Le store applique les effets via `MerlinEffectEngine`, met a jour le state, et emet les signaux.

### Stage 8: Life Drain

```gdscript
store.dispatch({"type": "DAMAGE_LIFE", "amount": 1})
```

Chaque carte coute 1 point de vie. Pression de survie constante.

### Stage 9: Karma Update

Le karma est ajuste selon la direction choisie et l'outcome.

### Stage 10: Narrative Result Display

```gdscript
result_key = "result_success" (if outcome contains "success") else "result_failure"
```

Priorite: texte specifique a l'option → texte generique de la carte → fallback.

```gdscript
await ui.show_result_text_transition(result_text, outcome)
```

### Stage 11: Run End Check

```gdscript
if result.run_ended:
    # Attacher story_log
    # Appliquer rewards
    # Afficher end screen
    return  # Abort loop
```

Conditions de fin: voir [Section 9](#9-run-lifecycle).

### Stage 12: Travel & Biome

```gdscript
# Animation de voyage ("Le sentier continue...")
# Ecriture contexte RAG
# Check passifs biome
# Update difficulte dynamique (toutes les 3 cartes)
```

### Stage 13: Next Card (Loop)

```gdscript
_request_next_card()  # Recursif → retour Stage 1
```

---

## 3. DC Calculation with 11 Modifiers

> Fonction: `_get_dc_for_direction(direction: String) -> int`

### 3.1 Base DC par Direction

```
DC_BASE (MerlinConstants):
    left  (prudent):   min=4, max=8
    center (equilibre): min=7, max=12
    right (audacieux):  min=10, max=16
```

```gdscript
base_dc = randi_range(dc_min, dc_max)
```

### 3.2 Les 11 Modificateurs (ordre d'application)

| # | Modificateur | Valeur | Condition |
|---|-------------|--------|-----------|
| 1 | **Adaptive (Pity)** | -4 | 3 echecs consecutifs |
| 2 | **Adaptive (Challenge)** | +2 | 3 succes consecutifs |
| 3 | **Critical Choice** | +4 | `_is_critical_choice = true` |
| 4 | **Critical + Talent** | +2 (au lieu de +4) | Talent `feuillage_4` actif |
| 5 | **Biome Difficulty** | Variable | Selon biome actuel |
| 6 | **Faction Alignment** | +1 par extreme | Rep < 20 ou rep > 80 |
| 7 | **Faction All Neutral** | -2 | Toutes factions dans [20, 80] |
| 8 | **Power Milestone** | -dc_bonus | Bonus cumule des milestones |
| 9 | **Archetype** | Variable | Selon `player_traits.archetype_id` |
| 10 | **Dynamic Difficulty** | -3 a +3 | Recalcule toutes les 3 cartes |
| 11 | **Clamp Final** | [2, 19] | Toujours |

### 3.3 Exemples Worked

**Scenario: Carte 7, direction "right", 2 echecs precedents, biome Marais**
```
base_dc = randi_range(10, 16) = 13
+ adaptive: 0 (seulement 2 echecs, pas 3)
+ critical: 0 (pas critique)
+ biome: +1 (Marais)
+ faction: 0 (pas d'extremes)
- dc_bonus: -0 (pas de milestone a carte 7)
+ dynamic: +1 (ajuste a carte 6)
= 15, clamp [2,19] = 15
```

**Scenario: Carte 12, direction "left", 3 echecs, milestone carte 10, critique**
```
base_dc = randi_range(4, 8) = 6
+ adaptive: -4 (3 echecs → pity)
+ critical: +4
- dc_bonus: -1 (milestone carte 10: MINIGAME_BONUS)
= 5, clamp [2,19] = 5
```

---

## 4. Minigame Overlay System

> Source: `merlin_minigame_system.gd`, `minigame_base.gd`, `MiniGameRegistry`

### 4.1 Invocation

```gdscript
var field = MiniGameRegistry.detect_field(narrative_text, gm_hint, card_tags)
var base_diff = clampi(int(dc / 2.0), 1, 10)
if _is_critical_choice:
    base_diff = mini(base_diff + 3, 10)

var game = MiniGameRegistry.create_minigame(field, base_diff, modifiers)
game.start()
# Signal: game_completed(result: {"success": bool, "score": int})
```

### 4.2 Detection Champ Lexical → Minigame

| Champ | Keywords (regex) | Minigames associes |
|-------|-----------------|-------------------|
| **chance** | cueillir, chercher, hasard, fortune, tirage, de | mg_de_du_destin, mg_pile_ou_face, mg_roue_fortune |
| **bluff** | marchander, convaincre, mentir, negocier, charmer | mg_joute_verbale, mg_bluff_druide, mg_negociation |
| **observation** | observer, scruter, memoriser, examiner, fixer | mg_oeil_corbeau, mg_trace_cerf, mg_rune_cachee |
| **logique** | dechiffrer, analyser, resoudre, decoder | mg_enigme_ogham, mg_noeud_celtique, mg_pierre_feuille_racine |
| **finesse** | se faufiler, esquiver, contourner, escalader | mg_tir_a_larc, mg_lame_druide, mg_pas_renard |
| **vigueur** | force, endurance, puissance, resistance, soulever | mg_combat_rituel, mg_sang_froid, mg_course |
| **esprit** | volonte, concentration, mediter, calme, serenite | mg_volonte, mg_apaisement, mg_meditation |
| **perception** | sentir, entendre, percevoir, instinct, flair | mg_ombres, mg_regard, mg_echo |

### 4.3 Score → D20 Conversion

```gdscript
MiniGameBase.score_to_d20(score: int) -> int:
    score <= 10:  randi_range(1, 1)  = 1
    score <= 25:  randi_range(2, 5)
    score <= 50:  randi_range(6, 10)
    score <= 75:  randi_range(11, 15)
    score <= 95:  randi_range(16, 19)
    score > 95:   20
```

### 4.4 Timeout Protection

```
Minigame timeout: 30.0 seconds
Si pas de signal game_completed → fallback vers _run_dice_roll(dc)
```

### 4.5 Minigame Catalogue (14 epreuves)

Chaque epreuve definie dans `MerlinConstants.MINIGAME_CATALOGUE`:

| ID | Nom | Trigger Regex |
|----|-----|--------------|
| `traces` | Traces | `piste\|trace\|empreinte\|pas\|sentier` |
| `runes` | Runes | `rune\|ogham\|symbole\|gravure` |
| `equilibre` | Equilibre | `pont\|equilibre\|vertige\|gouffre` |
| `herboristerie` | Herboristerie | `plante\|herbe\|champignon\|racine` |
| `negociation` | Negociation | `esprit\|fae\|parler\|negocier` |
| `combat_rituel` | Combat Rituel | `combat\|defi\|guerrier\|lame\|epee` |
| `apaisement` | Apaisement | `apaiser\|calmer\|respir\|gardien` |
| `sang_froid` | Sang-froid | `piege\|danger\|froid\|sang` |
| `course` | Course | `courir\|pourchasser\|fuir\|sprint` |
| `fouille` | Fouille | `fouille\|chercher\|indice\|recueillir` |
| `ombres` | Ombres | `cacher\|ombre\|discret\|invisible` |
| `volonte` | Volonte | `douter\|murmure\|resister\|volonte` |
| `regard` | Regard | `vision\|forme\|memoriser\|fixer` |
| `echo` | Echo | `voix\|appel\|son\|echo\|ecouter` |

---

## 5. Dice Resolution

> Fonction: `_run_dice_roll(dc: int) -> int`

### 5.1 Sequence Dice Roll

```gdscript
target = randi_range(1, 20)
SFXManager.play("dice_shake")
await get_tree().create_timer(0.3).timeout
SFXManager.play("dice_roll")
await ui.show_dice_roll(dc, target)   # Duration: DICE_ROLL_DURATION = 3.0s
SFXManager.play("dice_land")
return target
```

### 5.2 Resultats Speciaux

| Roll | Nom | Effet supplementaire |
|------|-----|---------------------|
| 20 | Critical Success | +5 vie, effets positifs x2 |
| 1 | Critical Failure | -10 vie, effets inverses |

### 5.3 RNG

Le jeu utilise `randi_range()` natif de Godot (Mersenne Twister) avec seed optionnel via `MerlinRng`.

---

## 6. Edge Cases & Error Recovery

### 6.1 LLM Timeout

```
Timeout principal: 30s (GENERATION_TIMEOUT_MS dans MerlinLlmAdapter)
Retry avec temperatures escaladees: [0.6, 0.7, 0.8] (3 tentatives)
Si echec total → FastRoute fallback pool (cartes pre-generees)
```

### 6.2 Minigame Timeout

```
Timeout: 30.0 secondes
Fallback: _run_dice_roll(dc) automatique
```

### 6.3 JSON Malformed (reponse LLM)

```
MerlinLlmAdapter repare le JSON:
- Strip metadata/thinking tokens
- Fix single quotes → double quotes
- Fix trailing commas
- Validate required keys: ["text", "options"]
- Si < 3 options → padding avec labels generiques
```

### 6.4 Card Pool Vide

```
4-tier fallback:
1. Buffer pre-genere → consommer
2. Sequel card (30% chance) → generer depuis choix precedents
3. MerlinOmniscient prefetch → consommer
4. LLM dispatch → generer en temps reel
5. Si tout echoue → retry_llm_generation(3) avec temperatures escaladees
6. Ultime fallback → carte d'urgence hardcodee (3 options generiques)
```

### 6.5 Faction Overflow

```
Reputation toujours clampee [0.0, 100.0] via MerlinReputationSystem.apply_delta()
Retourne un nouveau Dictionary (immutable pattern)
```

### 6.6 Vie <= 0

```
Check a chaque Stage 11 (Run End Check)
Si life_essence <= 0 → run_ended avec reason "death"
Pas de negative: clamp a 0
```

### 6.7 Store Dispatch Null

```
Si dispatch retourne null → return {"ok": false}
Le controller verifie et log l'erreur, continue le jeu
```

---

## 7. Timing Chain & Delays

### 7.1 Durees Exactes

| Timer | Duree | Contexte |
|-------|-------|---------|
| `DICE_ROLL_DURATION` | 3.0s | Animation visuelle du de |
| Dice shake → roll gap | 0.3s | Pause dramatique |
| Post-dice dramatic pause | 0.5s | Avant result |
| Minigame timeout | 30.0s | Limite pour le joueur |
| Card buffer ready check | 5.0s max | Attente cartes prefetch |
| LLM timeout | 30.0s | Generation carte |
| LLM poll (warm) | 45.0s | Model deja charge |
| LLM poll (cold start) | 90.0s | Premier chargement model |
| Thinking overlay | 1.5s | Overlay "reflexion..." |
| Post-choice wait | 3.0s | Etendu pour prefetch LLM |
| Result text display | Variable | Await typewriter complet |
| Travel animation | Variable | Await animation complete |
| Autosave debounce | 30.0s | Timer avant sauvegarde auto |

### 7.2 Sequence Temporelle d'un Tour Complet

```
T+0.0s    Joueur clique option
T+0.0s    DC calcule (instantane)
T+0.0s    Selection minigame/dice (instantane)

[Si dice]
T+0.0s    SFX "dice_shake"
T+0.3s    SFX "dice_roll"
T+0.3s    Animation dice (3.0s)
T+3.3s    SFX "dice_land"
T+3.8s    Pause dramatique (0.5s)

[Si minigame]
T+0.0s    Minigame instancie
T+0-30s   Joueur joue le minigame
T+Xms     Score → D20 converti

T+3.8s    Outcome classifie (instantane)
T+3.8s    Effets modules (instantane)
T+3.8s    Dispatch store (instantane)
T+3.8s    Drain vie -1 (instantane)
T+3.8s    Result text affiche (typewriter, ~2-4s)
T+7.0s    Travel animation (~1-2s)
T+9.0s    Prefetch background (asynchrone)
T+9.0s    Next card affichee
T+9.0s    is_processing = false → IDLE

Duree totale moyenne d'un tour: 8-12 secondes (dice) ou 15-40s (minigame)
```

---

## 8. Signal Flow

### 8.1 Signaux Emis par le Controller/Store

```gdscript
signal state_changed(state: Dictionary)
signal phase_changed(phase: String)
signal life_changed(old_value: int, new_value: int)
signal reputation_changed(faction: String, value: float, delta: float)
signal run_ended(ending: Dictionary)
signal card_resolved(card_id: String, option: int)
signal mission_progress(step: int, total: int)
signal ogham_activated(skill_id: String, effect: String)
signal game_completed(result: Dictionary)    # Minigame
```

### 8.2 Connexions Signal → Handler

| Signal | Emetteur | Recepteur | Handler |
|--------|----------|-----------|---------|
| `state_changed` | Store | Controller | `_on_state_changed` (sync UI) |
| `life_changed` | Store | Controller | `_on_life_changed` (play SFX) |
| `run_ended` | Store | Controller | `_on_run_ended` (end screen) |
| `option_chosen` | UI | Controller | `_on_option_chosen` → `_resolve_choice` |
| `ogham_selected` | OghamWheel | Controller | `_on_ogham_selected` → `_use_ogham` |
| `game_completed` | Minigame | Controller | Capture result → `score_to_d20` |

### 8.3 Flux Signal Complet d'un Tour

```
UI.option_chosen(2)
  → Controller._on_option_chosen(2)
    → Controller._resolve_choice(2)
      → [dice/minigame]
      → Store.dispatch("RESOLVE_CHOICE")
        → EffectEngine.apply_effects()
          → Store.state_changed.emit(new_state)
          → Store.life_changed.emit(old, new)
          → Store.reputation_changed.emit(faction, value, delta)
      → Store.dispatch("DAMAGE_LIFE", 1)
        → Store.life_changed.emit(old, new)
      → [if life <= 0] Store.run_ended.emit(ending)
      → Controller._request_next_card()
```

---

## 9. Run Lifecycle

### 9.1 Demarrage (`start_run`)

```gdscript
func start_run(seed_value: int = -1) -> void:
    # 1. Reset variables run
    _cards_this_run = 0
    _karma = 0
    _blessings = 0
    _critical_used = false
    is_processing = false

    # 2. Dispatch START_RUN
    store.dispatch({"type": "START_RUN", "seed": seed_value, "biome": current_biome})

    # 3. Charger buffer pre-genere
    # Source: user://temp_run_cards.json (genere par TransitionBiome)

    # 4. Sequence UI d'ouverture
    # - Opening screen
    # - Narrator intro
    # - Scenario intro (si actif)
    # - Merlin speech contextuel:
    #   "Les brumes de {biome} s'ouvrent..." + season_flavor

    # 5. Attente buffer pret (max 5s)

    # 6. _request_next_card() → premiere carte
```

### 9.2 Boucle Principale

```
_request_next_card() [recursive]
  → Check power milestones (cartes 5/10/15/20)
  → Fetch card (4-tier)
  → Detect critical choice
  → Post-process text
  → Display card
  → Prefetch next card (background)
  → is_processing = false
  → [Attente choix joueur]
  → _resolve_choice()
    → [13 stages]
    → _request_next_card()  ← Recursion
```

### 9.3 Power Milestones

| Carte | Type | Valeur |
|-------|------|--------|
| 5 | HEAL | +15 vie |
| 10 | MINIGAME_BONUS | +5 au score |
| 15 | HEAL | +10 vie |
| 20 | HEAL | +20 vie |

### 9.4 Conditions de Fin

| Condition | Trigger | Raison |
|-----------|---------|--------|
| Mort | `life_essence <= 0` | `"death"` |
| Hard Max | `card_index >= 50` | `"hard_max"` |
| Convergence MOS | `card_index >= 25 AND MOS decide` | `"convergence"` |
| Zone de convergence | `card_index in [25, 40]` | MOS peut decider |

### 9.5 Critical Choice Detection

```gdscript
_detect_critical_choice():
    if _critical_used or _cards_this_run < 3:
        return  # Max 1 par run, apres carte 3

    if _karma >= 6 and randf() < 0.4:
        _is_critical_choice = true     # 40% si karma haut
    elif _karma <= -6 and randf() < 0.5:
        _is_critical_choice = true     # 50% si karma bas
    elif randf() < 0.15:
        _is_critical_choice = true     # 15% base

    if _is_critical_choice:
        _critical_used = true
        SFXManager.play("critical_alert")
        ui.show_critical_badge()
```

### 9.6 Cleanup de Fin

```gdscript
# Calculer rewards (Anam, reputation deltas)
# Archiver run dans RAG memory
# Afficher end screen avec stats
# Retourner au Hub
```

---

## 10. Save/Load Interaction

### 10.1 Quand le State est Persiste

| Moment | Donnees | Methode |
|--------|---------|---------|
| Fin de run | Profile meta (anam, factions, stats) | `save_system.save_profile(meta)` |
| Autosave | Profile + run_state | Timer debounce 30s |
| Avant run | Profile backup (.bak) | Automatique |
| Achat talent | Profile meta | Immediat |

### 10.2 Donnees Sauvegardees vs Non Sauvegardees

**Sauvegardees (cross-run):**
- Anam (monnaie)
- Faction reputation (5 factions, 0-100)
- Trust Merlin
- Talent tree (unlocked)
- Oghams possedes/equipes
- Endings vus
- Stats globales (total_runs, total_cards, deaths, etc.)
- Biome runs count

**NON sauvegardees (volatile par run):**
- Life essence (reset a 100 chaque run)
- Karma/tension (reset a 0)
- Promesses actives (resolues ou abandonnees)
- Story log (archive dans RAG mais pas dans save)
- Card buffer/prefetch
- DC bonus accumules

### 10.3 Format de Sauvegarde

Fichier unique: `user://merlin_profile.json`

```json
{
    "version": "1.0.0",
    "anam": 150,
    "total_runs": 7,
    "faction_rep": {
        "druides": 65.0,
        "anciens": 30.0,
        "korrigans": 45.0,
        "niamh": 80.0,
        "ankou": 10.0
    },
    "trust_merlin": 42,
    "talent_tree": { "unlocked": ["racines_1", "feuillage_2"] },
    "oghams": {
        "owned": ["beith", "luis", "quert", "duir"],
        "equipped": "duir"
    },
    "endings_seen": ["death_broceliande", "convergence_niamh"],
    "stats": {
        "total_cards": 234,
        "total_minigames_won": 18,
        "total_deaths": 4,
        "consecutive_deaths": 0,
        "total_anam_earned": 420
    },
    "biome_runs": {
        "foret_broceliande": 5,
        "landes_bruyere": 2
    },
    "run_state": null
}
```

---

# Part 2 — Visual Rendering Implementation

## 11. MerlinVisual Centralized Constants

> Source: `scripts/autoload/merlin_visual.gd` (Autoload singleton)

### 11.1 CRT_PALETTE — Palette Active (CRT Terminal Druido-Tech)

**Backgrounds (vert sombre terminal):**

| Cle | Valeur | Usage |
|-----|--------|-------|
| `bg_deep` | `Color(0.02, 0.04, 0.02)` | Noir terminal le plus sombre |
| `bg_dark` | `Color(0.04, 0.08, 0.04)` | Fond de panneau |
| `bg_panel` | `Color(0.06, 0.12, 0.06)` | Panneau sureleve |
| `bg_highlight` | `Color(0.08, 0.16, 0.08)` | Fond le plus clair |

**Phosphor (Vert primaire — style terminal):**

| Cle | Valeur | Usage |
|-----|--------|-------|
| `phosphor` | `Color(0.20, 1.00, 0.40)` | Texte vert principal |
| `phosphor_dim` | `Color(0.12, 0.60, 0.24)` | Vert attenue |
| `phosphor_bright` | `Color(0.40, 1.00, 0.60)` | Accent vert vif |
| `phosphor_glow` | `Color(0.20, 1.00, 0.40, 0.15)` | Overlay lumineux |

**Amber (Secondaire — accents):**

| Cle | Valeur | Usage |
|-----|--------|-------|
| `amber` | `Color(1.00, 0.75, 0.20)` | Ambre primaire |
| `amber_dim` | `Color(0.60, 0.45, 0.12)` | Ambre attenue |
| `amber_bright` | `Color(1.00, 0.85, 0.40)` | Ambre vif |

**Celtic Mystic (Tertiaire — magie):**

| Cle | Valeur | Usage |
|-----|--------|-------|
| `cyan` | `Color(0.30, 0.85, 0.80)` | Teal mystique |
| `cyan_bright` | `Color(0.50, 1.00, 0.95)` | Cyan vif |
| `cyan_dim` | `Color(0.15, 0.42, 0.40)` | Cyan attenue |

**Status:**

| Cle | Valeur | Usage |
|-----|--------|-------|
| `danger` | `Color(1.00, 0.20, 0.15)` | Rouge |
| `success` | `Color(0.20, 1.00, 0.40)` | Vert (= phosphor) |
| `warning` | `Color(1.00, 0.75, 0.20)` | Ambre (= amber) |
| `inactive` | `Color(0.20, 0.25, 0.20)` | Grise |
| `inactive_dark` | `Color(0.12, 0.15, 0.12)` | Grise sombre |

**Elements structurels:**

| Cle | Valeur | Usage |
|-----|--------|-------|
| `border` | `Color(0.12, 0.30, 0.14)` | Bordure verte |
| `border_bright` | `Color(0.20, 0.50, 0.24)` | Bordure vive |
| `shadow` | `Color(0.00, 0.00, 0.00, 0.40)` | Ombre 40% |
| `scanline` | `Color(0.00, 0.00, 0.00, 0.15)` | Overlay scanline 15% |
| `line` | `Color(0.12, 0.30, 0.14, 0.25)` | Ligne 25% |
| `mist` | `Color(0.10, 0.20, 0.10, 0.20)` | Brume 20% |

**UI specifique:**

| Cle | Valeur | Usage |
|-----|--------|-------|
| `choice_normal` | `Color(0.12, 0.60, 0.24)` | Bouton inactif |
| `choice_hover` | `Color(0.20, 1.00, 0.40)` | Bouton survole |
| `choice_selected` | `Color(1.00, 0.75, 0.20)` | Bouton selectionne |
| `reward_bg` | `Color(0.04, 0.08, 0.04, 0.92)` | Fond badge reward |
| `reward_border` | `Color(0.20, 1.00, 0.40, 0.75)` | Bordure badge reward |

### 11.2 Font Configuration

```gdscript
FONT_NAME: "VT323"          # Police monospace terminal
TITLE_SIZE: 64px
HEADING_SIZE: 48px
BODY_SIZE: 24px
CAPTION_SMALL: 16px (12px dans certains contextes)
OUTLINE_SIZE: 2px (1px en petit)
OUTLINE_COLOR: Color(0.0, 0.0, 0.0, 0.5)
```

### 11.3 PALETTE — Legacy (Parchemin Mystique Breton)

Conservee pour migration graduelle. Tons parchemin chauds, bronze/or, accents celtiques.

### 11.4 GBC — Game Boy Color Palette

~30 couleurs pour le pixel art des biomes (grass, water, fire, earth, mystic, ice, thunder, poison, metal, shadow, light).

---

## 12. PixelSceneCompositor (48x48)

> Source: `scripts/ui/pixel_scene_compositor.gd`

### 12.1 Constantes

```gdscript
GRID_SIZE = 48           # Grille 48x48 pixels
MAX_PROPS = 3            # Max props par scene
MAX_CREATURES = 1        # Un seul creature
ASSEMBLY_SPEED = 1.8     # Vitesse animation cascade
GLOW_FREQ = 1.5          # Hz pulse idle (1.5 cycles/s)
```

### 12.2 Architecture 4 Layers

```
Layer 1: Background (ciel, sol)
Layer 2: Props (2-3 elements: arbres, pierres, champignons)
Layer 3: Creature (0-1, PNJ ou monstre)
Layer 4: Weather (pluie, neige, brume)
```

### 12.3 Rendu

- `PackedVector2Array` pour positions, `PackedColorArray` pour couleurs
- `_base_colors` stocke les couleurs non-animees
- `_glow_mask` marque les pixels lumineux: `r > 0.6 AND g > 0.4` ou `v > 0.7`
- Taille affichee: 220px (default) → `_pixel_size = 220 / 48 = 4.583 px/cell`

### 12.4 Animation d'Assemblage

```
1. Pixels cascadent depuis le haut avec stagger par ligne
   Offset: 0.5s + random(0, 0.2s) par ligne
2. Easing: ease_back_out (custom):
   1.0 + 2.70158 * (t-1)^3 + 1.70158 * (t-1)^2
3. Alpha fade-in: clamp(t * 3.0, 0.0, 1.0) → transparent→opaque en 0.33s
4. Duree totale: ~0.55s
```

### 12.5 Pulse Idle (Glow)

```
Pixels marques _glow_mask:
  base_color → brightened (x1.3 R/G, x1.1 B)
  Pulse amplitude: 40% du brighten
  Oscillation: sin(time * GLOW_FREQ * 2PI) a 1.5 Hz
```

### 12.6 Tinting (Biome + Saison)

```
Biome tint: 15% lerp vers couleur primaire biome (x1.3)
Season tint: 15% multiplicatif (RGB * season_tint, clamp 0-1)
```

### 12.7 Selection de Composants (Scoring)

```
Backgrounds: 10 pts match biome, 2 pts par tag correspondant
Props: Score, tri, selection aleatoire 2-3 avec detection overlap
Creatures: Meilleur score unique
Weather: Tag-based overlay (pas de blending)
```

---

## 13. PixelOghamIcon (16x16)

> Source: `scripts/ui/pixel_ogham_icons.gd`

### 13.1 Constantes

```gdscript
GRID_SIZE = 16                  # 16x16 pixel art
DEFAULT_TARGET_SIZE = 48.0      # Upscale 3x
_pixel_size = 48.0 / 16 = 3.0  # px par cell
```

### 13.2 Palettes par Categorie (5 couleurs indexees)

| Index | Role | Couleur |
|-------|------|---------|
| 0 | Transparent | `Color(0, 0, 0, 0)` |
| 1 | Outline | `#1a120e` (brun sombre) |
| 2 | Stem | Specifique categorie |
| 3 | Accent | Specifique categorie |
| 4 | Highlight | Plus clair, specifique |

**Couleurs par categorie:**

| Categorie | Oghams | Stem | Accent | Highlight |
|-----------|--------|------|--------|-----------|
| REVEAL (Bleu) | beith, coll, ailm | `#374351` | `#98aad8` | `#e3dbe0` |
| PROTECTION (Vert) | luis, gort, eadhadh | `#3f6f46` | `#5c947c` | `#8a9c6b` |
| BOOST (Or) | duir, tinne, onn | `#785f39` | `#c49256` | `#d8ce98` |
| NARRATIVE (Pierre) | nuin, huath, straif | `#2c1c22` | `#4c4651` | `#c0b8ad` |
| RECOVERY (Sauge) | quert, ruis, saille | `#53693d` | `#8a9c6b` | `#c0b8ad` |
| SPECIAL (Rouge) | muin, ioho, ur | `#552320` | `#944a42` | `#764535` |

### 13.3 Animations

**Pulse Glow:**
```
_pulse_time oscille a 2.5 Hz
Lerp accent → highlight a 30% amplitude
```

**Reveal Animation:**
```
Duree totale: 1.5s (0.5s par pixel revele)
Delay random par pixel: 0-0.5s
Alpha fade-in: lineaire 0→1 sur la periode de reveil
```

---

## 14. PixelBiomeBackdrop (160x90)

> Source: `scripts/ui/pixel_biome_backdrop.gd`

### 14.1 Pipeline de Rendu

```
Resolution native: 160x90 pixels (ratio 16:9)
Upscale: 4x via TEXTURE_FILTER_NEAREST → 640x360 affichage
Taux de rafraichissement: 0.1s interval (~10 FPS)
```

### 14.2 5 Layers (bas → haut)

| Layer | Contenu | Hauteur |
|-------|---------|---------|
| Sky | Gradient + etoiles + nuages | 0-30% |
| Far Hills | Collines roulantes background | ~30% |
| Mid Terrain | Arbres, structures | ~55% |
| Near Foreground | Herbe, buissons | ~75% |
| Atmosphere | Bandes de brume, particules | Full overlay |

### 14.3 Constantes d'Animation

```gdscript
WIND_SPEED = 0.3        # Derive horizontale par frame
MIST_SPEED = 0.15       # Vitesse scroll brume
PARTICLE_COUNT = 24      # Particules meteo
STAR_COUNT = 18          # Etoiles scintillantes
GLOW_COUNT = 6           # Lueurs mystiques (Broceliande seulement)
```

### 14.4 Types de Meteo

| Type | Comportement |
|------|-------------|
| `CLEAR` | Poussieres/lucioles flottantes, mouvement doux vers le haut |
| `RAIN` | Particules tombent (x4 vitesse) avec derive horizontale |
| `FOG` | Bandes de brume horizontales, `fog_intensity = 0.25` |
| `SNOW` | Chute douce (x0.8 vitesse) avec oscillation sinusoidale |

### 14.5 Details de Rendu

**Etoiles:** Clignotent a 2 Hz via `sin(_time * 2.0 + index * 1.7)`, rendues si > 0.4 luminosite

**Nuages:** Offset par `_wind_offset * 8.0` a intervalles de 20 pixels

**Brume:** 55%-80% hauteur, bruit scrollant: `sin(scroll_x * 0.08 + y * 0.12)`

**Arbres:** Balancement vent: `sin(_time * 1.2 + x * 0.1) * 1.5px`, canope diamant

**Lueurs Broceliande:** 3x3 glow (centre 1.0x alpha, bords 0.4x), pulse a 1.8 Hz

### 14.6 Profils Biome

Chaque biome definit 5 couleurs: `sky`, `mist`, `mid`, `accent`, `foreground` + `feature_density`:

| Biome | Sky | Feature Density |
|-------|-----|-----------------|
| Broceliande | `Color(0.16, 0.24, 0.14)` | 0.64 |
| Landes | `Color(0.28, 0.22, 0.34)` | 0.48 |
| Cotes | `Color(0.20, 0.28, 0.36)` | 0.50 |
| Villages | `Color(0.30, 0.23, 0.16)` | 0.55 |
| Cercles | `Color(0.23, 0.24, 0.27)` | 0.42 |
| Marais | `Color(0.17, 0.24, 0.22)` | 0.60 |
| Collines | `Color(0.26, 0.29, 0.19)` | 0.52 |
| Iles | `Color(0.14, 0.22, 0.34)` | 0.38 |

### 14.7 Palettes CRT 8-Couleurs Indexees par Biome

Chaque biome: 8 couleurs strictes [le plus sombre → le plus clair]:

**Exemple Broceliande:**
```
[0] Color(0.02, 0.06, 0.02)    # Noir
[1] Color(0.04, 0.12, 0.06)
[2] Color(0.08, 0.22, 0.10)
[3] Color(0.12, 0.35, 0.16)
[4] Color(0.20, 0.50, 0.24)    # Mid
[5] Color(0.30, 0.65, 0.30)
[6] Color(0.50, 0.80, 0.40)
[7] Color(0.70, 1.00, 0.50)    # Plus clair
```

---

## 15. CardSceneCompositor

> Source: `scripts/ui/card_scene_compositor.gd`

### 15.1 Constantes

```gdscript
PARALLAX_MAX_SHIFT = 8.0       # Max offset parallaxe en pixels
LAYER_STAGGER_DELAY = 0.08     # Delai entre animations layers (80ms)
LAYER_SLIDE_OFFSET = 10.0      # Distance initiale slide
IDLE_UPDATE_INTERVAL = 0.016   # ~60 Hz pour animations idle
```

### 15.2 4 Layers

| Layer | Source | Shader |
|-------|--------|--------|
| Sky | Gradient procedural | `card_sky.gdshader` |
| Terrain | Silhouette | `card_silhouette.gdshader` |
| Subject | Sprite (SpriteFactory) | Idle breathing |
| Atmosphere | CPUParticles2D + ColorRect pulse | — |

### 15.3 Subject Idle Motion

```
Animation "breathe":
  Amplitude: 1.005 (0.5% scale)
  Periode: 4.0s
  Le sujet respire doucement en cycle de 4 secondes
```

### 15.4 Effet Parallaxe

```gdscript
apply_parallax(tilt: Vector2):
    offset = tilt * depth_factor * PARALLAX_MAX_SHIFT (8.0px)
```

---

## 16. MerlinBubble

> Source: `scripts/ui/merlin_bubble.gd`

### 16.1 Specifications

```
Largeur max: 400 px
Corner radius: 8 px
Border width: 1 px
```

### 16.2 Couleurs

| Element | Source |
|---------|--------|
| Background | `CRT_PALETTE.bg_dark` avec alpha 0.88 |
| Border | `CRT_PALETTE.amber_bright` avec alpha 0.3 |
| Texte | `CRT_PALETTE.bg_panel` (vert clair) |
| Shadow | MerlinVisual, 8 px size |

### 16.3 Padding

```
Horizontal: 16 px
Vertical: 12 px
```

### 16.4 Effet Typewriter

```
Vitesse: 0.025 secondes par caractere
Ponctuation (.!?;:): 0.080 secondes
SFX: SFXManager.play_ui_click() par caractere
```

### 16.5 Animations

**Entree:**
```
Position: Centre X, offset Y par SLIDE_OFFSET = -20.0 px (glisse vers le bas)
Position finale: parent_height * 0.15 (15% du haut)
Duree: 0.3s
Easing: TRANS_CUBIC, EASE_OUT
Alpha: 0 → 1.0 simultane
```

**Sortie:**
```
Duree: 0.5s
Alpha: 1.0 → 0.0
Easing: Lineaire
```

**Auto-dismiss:** Timer 4 secondes apres fin du typewriter.

---

## 17. MerlinRewardBadge

> Source: `scripts/ui/merlin_reward_badge.gd`

### 17.1 Layout (VBoxContainer)

```
Row 1: Icone (20px) + Label type (CAPTION_SMALL, centre)
Row 2: DC Hint (11px, centre)
Row 3: Preview effet (11px, centre)
```

### 17.2 Style

```
Background: MerlinVisual.REWARD_BADGE.bg
Border: MerlinVisual.REWARD_BADGE.border
Corner radius: 8 px
Content padding: 12px H, 6px V
```

### 17.3 Couleurs par Niveau de Risque

| Niveau | Couleur |
|--------|---------|
| `faible` | `Color(0.2, 0.7, 0.3)` (vert) |
| `moyen` | Ambre (depuis REWARD_TYPES) |
| `eleve` | `Color(0.8, 0.2, 0.2)` (rouge) |

### 17.4 Positionnement

Au-dessus du bouton survole, centre X, 8.0 px au-dessus.

### 17.5 Format Effets

```
Separateur: " | "
Exemples: "+5 Vie" | "-3 Vie" | "+10 druides"
Couleur: badge_color.lerp(Color.WHITE, 0.5)
```

### 17.6 Reward Types

```gdscript
REWARD_TYPES = {
    "vie":        {"icon": "❤", "label": "Vie",        "color_key": "danger"},
    "anam":       {"icon": "#", "label": "Anam",       "color_key": "amber_bright"},
    "reputation": {"icon": "✦", "label": "Reputation", "color_key": "amber_bright"},
    "mystere":    {"icon": "?", "label": "Mystere",    "color_key": "amber"},
}
```

---

## 18. LLMSourceBadge

> Source: `scripts/ui/llm_source_badge.gd`

### 18.1 Types de Badge

| Type | Couleur | Indicateur |
|------|---------|-----------|
| `"llm"` | `Color(0.18, 0.55, 0.28, 0.90)` Vert | `"* "` (U+25CF) |
| `"fallback"` | `Color(0.72, 0.50, 0.10, 0.90)` Ambre | `"o "` (U+25CB) |
| `"static"` | `Color(0.42, 0.40, 0.38, 0.75)` Gris | `"# "` |
| `"error"` | `Color(0.70, 0.22, 0.18, 0.90)` Rouge | `"x "` (U+2716) |

### 18.2 Style

```
Font size: 10 px
Corner radius: 6 px
Content margin: 6px H, 2px V
Text color: CRT_PALETTE.phosphor_bright
```

### 18.3 Animation Entree

```
Fade: alpha 0.0 → 1.0 en 0.3s
```

---

## 19. CRT Terminal Shader

> Source: `shaders/crt_terminal.gdshader`

### 19.1 Master Control

```glsl
uniform float global_intensity: hint_range(0.0, 1.0) = 0.4;
```

### 19.2 Parametres Complets

**Courbure CRT (Barrel Distortion):**
```glsl
curvature: hint_range(0.0, 0.15) = 0.04
barrel_enabled: bool = true
barrel_intensity: hint_range(0.0, 0.1) = 0.003
Formule: distort = 1.0 + r² * (curvature + barrel_intensity) * global_intensity
```

**Scanlines:**
```glsl
scanline_opacity: hint_range(0.0, 1.0) = 0.12   # 12% darkening
scanline_count: hint_range(100, 800) = 400.0     # Lignes par hauteur ecran
Effet: 1.0 - (scanline * opacity * intensity)
```

**Wobble Scanline (jitter CRT):**
```glsl
scanline_wobble_intensity: hint_range(0.0, 0.005) = 0.0003
scanline_wobble_frequency: hint_range(0.0, 100.0) = 30.0 Hz
scanline_wobble_speed: hint_range(0.0, 5.0) = 0.8
```

**Micro Glitches:**
```glsl
glitch_enabled: bool = true
glitch_probability: hint_range(0.0, 0.3) = 0.005   # 0.5% chance/frame
glitch_intensity: hint_range(0.0, 0.02) = 0.004
glitch_line_height: hint_range(0.001, 0.05) = 0.015
```

**Phosphor Tint:**
```glsl
phosphor_tint: vec4 = vec4(0.2, 1.0, 0.4, 1.0)   # Vert terminal
tint_blend: hint_range(0.0, 1.0) = 0.03            # 3% influence
```

**Dithering (Bayer 4x4):**
```glsl
dither_strength: hint_range(0.0, 1.0) = 0.3        # 30%
color_levels: hint_range(2.0, 32.0) = 8.0           # Quantification 8 niveaux
```

**Phosphor Glow (Bloom):**
```glsl
phosphor_glow: hint_range(0.0, 1.0) = 0.06          # 6% bloom
Seuil: luminance > 0.5 declenche bloom
Formule: col.rgb += col.rgb * bloom_factor
```

**Aberration Chromatique (RGB Split):**
```glsl
chromatic_enabled: bool = true
chromatic_intensity: hint_range(0.0, 0.01) = 0.0005
chromatic_falloff: hint_range(1.0, 4.0) = 3.0
Offset: normalize(center_dist + 0.001) * ca_amount
```

**Color Shifting (decalage teinte temporal):**
```glsl
color_shift_enabled: bool = true
color_shift_intensity: hint_range(0.0, 0.02) = 0.0006
color_shift_speed: hint_range(0.0, 2.0) = 0.3
```

**Bruit Temporel (Grain):**
```glsl
noise_enabled: bool = true
noise_intensity: hint_range(0.0, 0.1) = 0.010       # 1% grain
noise_speed: hint_range(1.0, 60.0) = 24.0 Hz
```

**Vignette:**
```glsl
vignette_enabled: bool = true
vignette_intensity: hint_range(0.0, 0.5) = 0.08     # 8% darkening
vignette_softness: hint_range(0.1, 1.0) = 0.55
```

**Flicker (clignotement luminosite):**
```glsl
flicker_enabled: bool = true
flicker_intensity: hint_range(0.0, 0.05) = 0.003    # 0.3%
flicker_speed: hint_range(1.0, 30.0) = 12.0 Hz
```

---

## 20. CRT Static Shader

> Source: `shaders/crt_static.gdshader`

Shader plus ancien pour effet de neige/parasites statiques.

```glsl
intensity: hint_range(0.0, 1.0) = 1.0
noise_speed: hint_range(1.0, 100.0) = 50.0
scanline_opacity: hint_range(0.0, 1.0) = 0.4        # 40% scanlines
scanline_count: hint_range(100.0, 800.0) = 400.0
grain_intensity: hint_range(0.0, 1.0) = 0.8
flicker_intensity: hint_range(0.0, 0.5) = 0.15
vignette_intensity: hint_range(0.0, 1.0) = 0.3
tint: source_color = vec4(0.85, 0.9, 0.95, 1.0)     # Presque blanc
```

Effets: Perlin noise + bandes d'interference verticales + vignette (3.0x distance) + CRT edge darken (6e puissance, 15%).

---

## 21. Season Tints & Color Grading

### 21.1 Season Colors (teintes primaires)

| Saison | Couleur |
|--------|---------|
| `printemps` | `Color(0.45, 0.70, 0.40)` |
| `ete` | `Color(0.40, 0.65, 0.85)` |
| `automne` | `Color(0.80, 0.55, 0.25)` |
| `hiver` | `Color(0.60, 0.45, 0.70)` |

### 21.2 Season Tints (multiplicatifs sur pixel scenes)

| Saison | Tint Multiplicatif | Effet Visuel |
|--------|-------------------|--------------|
| Printemps | `Color(1.02, 1.07, 1.00)` | Legerement lumineux, vert booste |
| Ete | `Color(1.08, 1.04, 0.95)` | Chaud, bleu legerement desature |
| Automne | `Color(1.10, 0.92, 0.82)` | Jaunes chauds, bleus attenues |
| Hiver | `Color(0.84, 0.90, 1.08)` | Froid, decale vers le bleu |

### 21.3 Palettes Visuelles Saisonnieres (particules & grading)

```
Spring:  fog_tint: Color(0.88, 0.94, 0.85, 0.30)
         particle_color: Color(0.70, 0.90, 0.60, 0.15)

Summer:  fog_tint: Color(0.95, 0.92, 0.85, 0.25)
         particle_color: Color(0.95, 0.90, 0.60, 0.12)

Autumn:  fog_tint: Color(0.92, 0.85, 0.78, 0.32)
         particle_color: Color(0.90, 0.70, 0.45, 0.18)

Winter:  fog_tint: Color(0.85, 0.88, 0.95, 0.35)
         particle_color: Color(0.80, 0.85, 0.95, 0.20)
```

---

## 22. Tween Animations Catalogue

### 22.1 IntroCeltOS

| Composant | Propriete | De | A | Duree | Easing | Delai |
|-----------|----------|-----|---|-------|--------|-------|
| Boot labels | `modulate:a` | 0.0 | 0.8 | 0.08s | Linear | 0.06s x i |
| Boot labels | `theme_color` | phosphor_dim | amber | 0.1s | Linear | Stagger |
| Boot container | `modulate:a` | 1.0 | 0.0 | 0.4s | Linear | Post-flash |
| Logo container | `modulate:a` | 0.0 | 1.0 | 0.2s | Linear | Debut |
| Logo blocks | `position` | Au-dessus ecran | Position finale | 0.35s | BOUNCE/OUT | Stagger |
| Logo blocks | `color` | phosphor/phosphor_bright | amber | 0.15s | Linear | Flash |
| Logo blocks | `color` | amber | phosphor | 0.2s | Linear | Post-flash |
| Logo container | `position:y` | centre | -40px | 0.4s | SINE | Phase 3 |
| Loading container | `modulate:a` | 0.0 | 1.0 | 0.3s | Linear | Phase 3 |
| Loading bar | `size:x` | 0 | 96px (30%) | 0.4s | SINE | Stage 1 |
| Loading bar | `size:x` | 96px | 192px (60%) | 0.5s | SINE | Stage 2 |
| Loading bar | `size:x` | 192px | 272px (85%) | 0.4s | SINE | Stage 3 |
| Loading bar | `size:x` | 272px | 320px (100%) | 0.3s | SINE | Final |
| Loading bar | `color` | phosphor | amber | Instantane | — | Complete |
| Loading container | `modulate:a` | 1.0 | 0.0 | 0.3s | Linear | Sortie |

### 22.2 MerlinBubble

| Composant | Propriete | De | A | Duree | Easing |
|-----------|----------|-----|---|-------|--------|
| Bubble | `modulate:a` | 0.0 | 1.0 | 0.3s | CUBIC/OUT |
| Bubble | `position` | start_pos | end_pos | 0.3s | CUBIC/OUT |
| Bubble | `modulate:a` | 1.0 | 0.0 | 0.5s | Linear |

### 22.3 LLMSourceBadge

| Composant | Propriete | De | A | Duree | Easing |
|-----------|----------|-----|---|-------|--------|
| Badge panel | `modulate:a` | 0.0 | 1.0 | 0.3s | Linear |

### 22.4 PixelSceneCompositor

| Composant | Propriete | Description | Duree | Easing |
|-----------|----------|-------------|-------|--------|
| Pixels (assemblage) | position | Cascade depuis offset haut | Variable | ease_back_out |
| Pixels (assemblage) | alpha | Transparent → opaque | duration/3 | Linear (clamp) |

### 22.5 CardSceneCompositor

| Composant | Propriete | De | A | Duree | Easing |
|-----------|----------|-----|---|-------|--------|
| Layers (reveal) | position | +LAYER_SLIDE_OFFSET | position finale | Stagger 0.08s | — |
| Subject | scale | 1.0 | 1.005 | 4.0s (cycle) | Sine |

### 22.6 Resume des Durees

| Animation | Duree Totale | Notes |
|-----------|-------------|-------|
| IntroCeltOS Phase 1 | ~1.5s | Boot lines |
| IntroCeltOS Phase 2 | ~2.0s | Logo Tetris |
| IntroCeltOS Phase 3 | ~3.5s | Barre de chargement |
| IntroCeltOS Total | **~7.0s** | + warmup LLM |
| PixelSceneCompositor assembly | 0.55s | Cascade pixels |
| PixelOghamIcon reveal | 1.5s | Reveil progressif |
| MerlinBubble entree | 0.3s | Slide + fade |
| MerlinBubble sortie | 0.5s | Fade out |
| Pulse idle glow | Infini | 1.5 Hz |

---

# Part 3 — Boot & Initialization

## 23. 16 Autoloads Boot Order

> Source: `project.godot` section `[autoload]`

### 23.1 Ordre d'Initialisation (critique)

| # | Nom | Script | Role |
|---|-----|--------|------|
| 1 | GameManager | `scripts/game_manager.gd` | Legacy type/enemy (plus utilise) |
| 2 | MerlinAI | `addons/merlin_ai/merlin_ai.gd` | Orchestrateur LLM (tot!) |
| 3 | MerlinBackdrop | `scripts/merlin_backdrop.gd` | Fond global (CanvasLayer -100) |
| 4 | ScreenFrame | `scripts/autoload/screen_frame.gd` | Cadre ecran |
| 5 | ScreenEffects | `scripts/autoload/ScreenEffects.gd` | Effets ecran |
| 6 | SceneSelector | `scripts/autoload/SceneSelector.gd` | Selecteur de scenes |
| 7 | LocaleManager | `scripts/autoload/LocaleManager.gd` | Internationalisation (fr) |
| 8 | SFXManager | `scripts/autoload/SFXManager.gd` | Audio procedural |
| 9 | MerlinVisual | `scripts/autoload/merlin_visual.gd` | Couleurs/constantes visuelles |
| 10 | PixelTransition | `scripts/autoload/pixel_transition.gd` | Transitions entre scenes |
| 11 | PixelContentAnimator | `scripts/autoload/pixel_content_animator.gd` | Animations contenu pixel |
| 12 | WorldMapSystem | `scripts/autoload/world_map_system.gd` | Systeme carte monde |
| 13 | MusicManager | `scripts/autoload/music_manager.gd` | Musique de fond |
| 14 | GameTimeManager | `scripts/autoload/game_time_manager.gd` | Gestion temps jeu |
| 15 | ScreenDither | `scripts/ui/screen_dither_layer.gd` | Layer dithering |
| 16 | GameDebugServer | `scripts/test/game_debug_server.gd` | Serveur debug (dev) |

### 23.2 Dependencies Cles

```
MerlinAI (#2) doit etre charge avant tout systeme LLM
SFXManager (#8) doit exister avant IntroCeltOS (sons boot)
MerlinVisual (#9) doit exister avant tout rendu UI
MerlinBackdrop (#3) est le fond le plus bas (CanvasLayer -100)
```

### 23.3 MerlinAI._ready()

```gdscript
set_process(false)           # Active seulement quand taches background
rag_manager = RAGManager.new()
add_child(rag_manager)
# LLM backends initialises paresseusement (au premier generate)
```

### 23.4 SFXManager._ready()

```gdscript
# Cree pool de 6 AudioStreamPlayers
for i in POOL_SIZE:
    var player = AudioStreamPlayer.new()
    add_child(player)
    _pool.append(player)
```

---

## 24. IntroCeltOS Boot Sequence

> Source: `scripts/IntroCeltOS.gd`, `scenes/IntroCeltOS.tscn`

### 24.1 _ready() Flow

```gdscript
1. set_anchors_preset(PRESET_FULL_RECT)
2. Input.set_mouse_mode(MOUSE_MODE_HIDDEN)       # Masquer curseur
3. _build_ui()                                     # Construire UI
4. _warmup_llm_async()                             # Timeout 2.0s
5. MusicManager.play_intro_music()                 # Demarrer musique
6. _start_phase_1()                                # Lancer boot
```

### 24.2 Phase 1: Boot Lines (Terminal Rapide)

**8 lignes affichees:**
```
"BIOS POST check..."
"Memory: 4096 MB"
"Loading druid_core.ko"
"Loading ogham_driver.ko"
"Ley line scan... FOUND"
"LLM: M.E.R.L.I.N.-3B"
"Warmup inference..."
"Systems ready"
```

**Animation:**
- Labels commencent a `alpha = 0.0`, positiones a `y = screen_height * 0.3 + i * 28px`
- Reveal: `tween_property(label[i], "modulate:a", 0.8, 0.08)` avec `.set_delay(i * 0.06)`
- SFX: `SFXManager.play_varied("boot_line", 0.1)` par ligne
- Flash confirmation: tous labels → `alpha = 1.0` + couleur `amber` en 0.1s
- 0.3s idle
- Fade out container: `tween_property(boot_container, "modulate:a", 0.0, 0.4)`

**Couleurs:**
- Avant flash: `CRT_PALETTE.phosphor_dim` (0.12, 0.60, 0.24)
- Apres flash: `CRT_PALETTE.amber` (1.00, 0.75, 0.20)
- Font size: `CAPTION_SMALL` (12px)

**Duree Phase 1: ~1.5s**

### 24.3 Phase 2: Logo CeltOS (Blocs Tetris)

**Grille:** 23 colonnes x 5 lignes (1=bloc, 0=vide)
```
[1,1,1,0,1,1,1,0,1,0,0,0,1,1,1,0,1,1,1,0,1,1,1]
[1,0,0,0,1,0,0,0,1,0,0,0,0,1,0,0,1,0,1,0,1,0,0]
[1,0,0,0,1,1,0,0,1,0,0,0,0,1,0,0,1,0,1,0,1,1,1]
[1,0,0,0,1,0,0,0,1,0,0,0,0,1,0,0,1,0,1,0,0,0,1]
[1,1,1,0,1,1,1,0,1,1,1,0,0,1,0,0,1,1,1,0,1,1,1]
```

**Bloc:** 12x12 px + 2 px gap = stride 14 px
**Grille totale:** 322x70 px, centree

**Animation:**
1. Logo container fade in: alpha 0→1 en 0.2s
2. Blocs tries par colonne (gauche→droite)
3. Chaque bloc:
   - Position depart: `(final_x, -50 - random(0, 200)px)` (au-dessus ecran)
   - Position finale: position grille
   - Duree: **0.35s** avec `TRANS_BOUNCE`, `EASE_OUT`
   - Delai: `i * 0.015 + random(0.0, 0.02)`
   - SFX: `SFXManager.play_varied("block_land", 0.1)` au landing
4. Couleurs alternees: `phosphor` / `phosphor_bright`
5. Flash: `SFXManager.play("flash_boom")` → tous blocs amber (0.15s) → retour phosphor (0.2s)

**Duree Phase 2: ~2.0s**

### 24.4 Phase 3: Barre de Chargement

**Dimensions:** 320 x 12 px, centree, `center_y + 60`

| Etape | Duree | Remplissage | Label |
|-------|-------|-------------|-------|
| 1 | 0.4s | 30% | "Initialisation du systeme druidique..." |
| 2 | 0.5s | 60% | "Chargement des runes oghamiques..." |
| 3 | 0.4s | 85% | "Connexion aux lignes de ley..." |
| Poll | ≤2.0s | (pause) | "Eveil de M.E.R.L.I.N. ..." (si LLM warm) |
| 4 | 0.3s | 100% | "Systeme pret." → barre passe en amber |
| Confirm | 0.4s | (final) | `SFXManager.play("boot_confirm")` |

**Transition finale:**
- Loading container + logo → alpha 0.0 en 0.3s
- 0.2s delai
- `PixelTransition.transition_to()` vers `scenes/MenuPrincipal.tscn`

**Duree Phase 3: ~3.5s**

### 24.5 _exit_tree() Cleanup

```gdscript
Input.set_mouse_mode(MOUSE_MODE_VISIBLE)   # Re-activer curseur
```

### 24.6 Timeline Totale Boot-to-Menu

| Phase | Duree | Evenements Cles |
|-------|-------|----------------|
| Autoload Init | ~100ms | 16 autoloads charges |
| IntroCeltOS._ready() | ~50ms | UI construit, warmup LLM |
| Phase 1: Boot Lines | 1-2s | 8 lignes terminal + SFX |
| Phase 2: Logo Tetris | 2s | 115 blocs tombent + flash |
| Phase 3: Loading Bar | 2-3.5s | Barre remplit + "Pret!" |
| Scene Transition | ~500ms | Fade out + changement scene |
| MenuPrincipal._ready() | ~100ms | Menu principal affiche |
| **Total** | **~5.5-7s** | Joueur voit le menu |

---

## 25. LLM Startup & Fallback Chain

> Source: `addons/merlin_ai/merlin_ai.gd`, `addons/merlin_ai/ollama_backend.gd`

### 25.1 Backend Types

```gdscript
enum BackendType { NONE, OLLAMA, BITNET, MERLIN_LLM }
var active_backend: int = BackendType.NONE
```

### 25.2 Brain Profiles (BrainSwarmConfig)

| Profile | Mode | RAM Min | Threads Min | Cerveaux |
|---------|------|---------|-------------|----------|
| NANO | resident | 800 MB | 2 | narrator:0.8B |
| SINGLE | resident | 1800 MB | 4 | narrator:2B |
| SINGLE_PLUS | time_sharing | 3200 MB | 4 | narrator:4B, gm:2B (swap) |
| DUAL | parallel | 5000 MB | 6 | narrator:4B, gm:2B |
| TRIPLE | parallel | 5800 MB | 8 | narrator:4B, gm:2B, worker:0.8B |
| QUAD | parallel | 6600 MB | 8 | narrator:4B, gm:2B, judge:0.8B, worker:0.8B |

### 25.3 Auto-Detection

```gdscript
static func detect_profile(available_ram_mb: int, cpu_threads: int) -> int:
    # Teste du plus gourmand au plus leger
    for profile in [QUAD, TRIPLE, DUAL, SINGLE_PLUS, SINGLE, NANO]:
        if available_ram_mb >= min_ram AND cpu_threads >= min_threads:
            return profile
    return NANO  # Fallback minimal
```

### 25.4 Warmup Strategy

```gdscript
_warmup_started: bool = false
_warmup_attempt_time: int = 0
LLM_POLL_TIMEOUT_MS: 45000          # Warm load: 7-15s
LLM_POLL_TIMEOUT_FIRST_MS: 90000    # Cold start: 30-60s
```

### 25.5 Health Check

| Backend | Methode | Timeout |
|---------|---------|---------|
| Ollama | `HTTPClient.connect_to_host()` + `GET /api/tags` | 5s |
| BitNet | Verification disponibilite classe | N/A |
| MerlinLLM | Existence fichier model | N/A |

### 25.6 Fallback Chain

```
1. Ollama → check_available() via HTTP GET /api/tags
   Si OK → active_backend = OLLAMA
2. Si Ollama fail → BitNetBackend (inference CPU, lent)
3. Si BitNet fail → MerlinLLM (GGUF natif)
4. Si tout fail → FastRoute pool (cartes pre-generees, pas de LLM)
```

### 25.7 Sampling Parameters

**Narrateur (Qwen 3.5):**
```gdscript
temperature: 0.70
top_p: 0.90
max_tokens: 180
top_k: 40
repetition_penalty: 1.45
```

**Gamemaster:**
```gdscript
temperature: 0.15
top_p: 0.8
max_tokens: 80
top_k: 15
repetition_penalty: 1.0
```

### 25.8 Signaux Status

```gdscript
signal error_occurred(message: String)
signal status_changed(status_text: String, detail_text: String, progress_value: float)
signal ready_changed(is_ready: bool)
```

### 25.9 Model & Prompts Paths

```gdscript
MODEL_FILE: "res://addons/merlin_llm/models/qwen3.5-4b-q4_k_m.gguf"
PROMPTS_PATH: "res://data/ai/config/prompts.json"
PROMPT_TEMPLATES_PATH: "res://data/ai/config/prompt_templates.json"
SCENE_PROFILES_PATH: "res://data/ai/config/scene_profiles.json"
PERSONA_CONFIG_PATH: "res://data/ai/config/merlin_persona.json"
SESSION_PERSIST_PATH: "user://ai/memory/llm_session_history.json"
```

---

## 26. Audio System (SFXManager)

> Source: `scripts/autoload/SFXManager.gd`

### 26.1 Configuration

```gdscript
SAMPLE_RATE: 44100
POOL_SIZE: 6               # Players audio concurrents
VOLUME: {
    "ui": 0.25,
    "ambient": 0.15,
    "impact": 0.30,
    "magic": 0.20,
    "transition": 0.22,
}
```

### 26.2 Catalogue Complet des Sons (tous proceduraux)

| Categorie | Sons | Methode |
|-----------|------|---------|
| **UI** | hover, click, slider_tick, button_appear | Onde sine/triangle |
| **Transition** | whoosh, card_draw, card_swipe, scene_transition | Sweep frequence |
| **Impact** | block_land, pixel_land, pixel_cascade, pixel_scatter, accum_explode | Burst bruit + decay |
| **Magic** | ogham_chime, ogham_unlock, bestiole_shimmer, eye_open, flash_boom, magic_reveal, skill_activate | Accord harmonique + modulation |
| **Ambient** | path_scratch, landmark_pop, mist_breath, aspect_shift, aspect_up, aspect_down, amb_* | Ton ambient + enveloppe |
| **Boot** | boot_line, boot_confirm, convergence, slit_glow | Beep digital + sweep |
| **Quiz** | choice_hover, choice_select, result_reveal, question_transition | Tons en escalier |
| **Dice** | dice_shake, dice_roll, dice_land, dice_crit_success, dice_crit_fail | Texture granulaire |
| **Minigame** | minigame_start, minigame_success, minigame_fail, minigame_tick, critical_alert | Stabs synth |
| **Souffle** | souffle_regen, souffle_full, perk_confirm | Pitch montant/descendant |
| **Biome** | amb_{biome_key} (par biome) | Pad ambient boucle |

**Important:** AUCUN fichier audio — tous les sons sont generes proceduralement par synthese.

### 26.3 Audio Bus Layout

```
Master (bus par defaut)
├── SFX (UI, impact, transition)
├── Ambient (pad background)
└── Music (piste de fond)
```

### 26.4 Pool Management

```gdscript
func _get_next_player() -> AudioStreamPlayer:
    # Cherche un player libre
    for i in range(POOL_SIZE):
        var idx = (_pool_index + i) % POOL_SIZE
        if not _pool[idx].playing:
            _pool_index = (idx + 1) % POOL_SIZE
            return _pool[idx]
    # Tous occupes: round-robin (coupe le plus ancien)
    var player = _pool[_pool_index]
    _pool_index = (_pool_index + 1) % POOL_SIZE
    return player
```

### 26.5 API

```gdscript
func play(sound_name: String, pitch_scale: float = 1.0) -> void
func play_varied(sound_name: String, variation: float = 0.1) -> void
func play_ui_click() -> void
func play_biome_ambient(biome_key: String) -> void
func set_master_volume(vol: float) -> void   # 0.0 a 1.0
```

---

## 27. Music Manager

> Source: `scripts/autoload/music_manager.gd`

### 27.1 Configuration

```gdscript
INTRO_MUSIC_PATH: "res://music/loop/VOYAGEUR - INTRO (Tri Martolod) (Remastered).mp3-loop.wav"
INTRO_MUSIC_INTRO_PATH: "res://music/loop/VOYAGEUR - INTRO (Tri Martolod) (Remastered).mp3-intro.wav"
DEFAULT_VOLUME_DB: -6.0
FADE_IN_DURATION: 1.5s
CROSSFADE_DURATION: 2.0s
```

### 27.2 Architecture 2 Players

- `_player_intro`: Joue la section intro (fade in)
- `_player_loop`: Boucle la piste principale (crossfade seamless)

### 27.3 Musiques par Biome

```gdscript
BIOME_MUSIC = {
    "foret_broceliande": {
        "intro": "res://music/loop/CHAS DONZ PART1 (Cover).mp3-intro.wav",
        "loop": "res://music/loop/CHAS DONZ PART1 (Cover).mp3-loop.wav",
    },
    # Autres biomes...
}
```

### 27.4 API

```gdscript
func play_intro_music() -> void
func play_biome_music(biome_key: String) -> void
func fade_out(duration: float) -> void
func stop() -> void
```

---

## 28. Save System

> Source: `scripts/merlin/merlin_save_system.gd`

### 28.1 Fichiers

```gdscript
PROFILE_PATH: "user://merlin_profile.json"
BACKUP_SUFFIX: ".bak"
LEGACY_SLOT_PATH: "user://merlin_save_slot_%d.json"   # Migration
LEGACY_AUTOSAVE_PATH: "user://merlin_autosave.json"    # Migration
```

### 28.2 Schema Profile (v1.0.0)

```json
{
    "anam": 0,
    "total_runs": 0,
    "faction_rep": {
        "druides": 0.0, "anciens": 0.0, "korrigans": 0.0,
        "niamh": 0.0, "ankou": 0.0
    },
    "trust_merlin": 0,
    "talent_tree": { "unlocked": [] },
    "oghams": {
        "owned": ["beith", "luis", "quert"],
        "equipped": "beith"
    },
    "ogham_discounts": {},
    "endings_seen": [],
    "arc_tags": [],
    "biome_runs": {
        "foret_broceliande": 0, "landes_bruyere": 0,
        "cotes_sauvages": 0, "villages_celtes": 0,
        "cercles_pierres": 0, "marais_korrigans": 0,
        "collines_dolmens": 0, "iles_mystiques": 0
    },
    "stats": {
        "total_cards": 0, "total_minigames_won": 0,
        "total_deaths": 0, "consecutive_deaths": 0,
        "oghams_discovered_in_runs": 0, "total_anam_earned": 0
    }
}
```

### 28.3 Schema Run State

```json
{
    "biome": "foret_broceliande",
    "card_index": 0,
    "life_essence": 100, "life_max": 100,
    "biome_currency": 0,
    "equipped_oghams": ["beith"],
    "active_ogham": "beith",
    "cooldowns": {},
    "promises": [],
    "faction_rep_delta": {
        "druides": 0.0, "anciens": 0.0, "korrigans": 0.0,
        "niamh": 0.0, "ankou": 0.0
    },
    "trust_delta": 0,
    "narrative_summary": "",
    "arc_tags_this_run": [],
    "period": "aube",
    "buffs": [],
    "events_log": []
}
```

### 28.4 API

| Fonction | Comportement |
|----------|-------------|
| `save_profile(meta)` | Sauvegarde profile + run_state → PROFILE_PATH |
| `load_profile()` | Charge depuis PROFILE_PATH, fallback .bak, puis migration legacy |
| `load_or_create_profile()` | Charge existant ou cree defaut |
| `profile_exists()` | Verifie existence PROFILE_PATH |
| `reset_profile()` | Supprime PROFILE_PATH + .bak |
| `save_run_state(state)` | Ajoute run_state au JSON profile |
| `load_run_state()` | Extrait run_state du profile |
| `clear_run_state()` | Met run_state = null |
| `has_active_run()` | Verifie si run_state non vide |

### 28.5 Backup Strategy

```
Avant ecriture: copie PROFILE_PATH → PROFILE_PATH.bak
En cas d'erreur lecture: tente .bak comme fallback
Migration legacy: anciens fichiers nettoyes apres upgrade
```

### 28.6 Migration (0.4.0 → 1.0.0)

```gdscript
# Convertit essence dict → anam
var essence_total = sum(essence.values())
meta["anam"] = meta.get("anam", 0) + essence_total

# Renomme humains → niamh
if faction_rep.has("humains"):
    faction_rep["niamh"] = faction_rep["humains"]
    faction_rep.erase("humains")

# Supprime cles legacy
meta.erase("essence")
meta.erase("ogham_fragments")
meta.erase("liens")
meta.erase("gloire_points")
```

---

## 29. Configuration Sources

### 29.1 project.godot

```ini
[application]
config/name = "DRU"
run/main_scene = "res://scenes/IntroCeltOS.tscn"
config/features = ["4.5", "GL Compatibility"]

[display]
window/stretch/mode = "canvas_items"

[gui]
theme/custom = "res://themes/merlin_theme.tres"

[internationalization]
locale/translations = ["res://data/i18n/translations.csv"]
locale/fallback = "fr"

[merlin_llm]
log_enabled = true
log_verbose = true
log_path = "user://merlin_llm/merlin.log"
allow_native_in_editor = true
require_native = true
low_spec_mode = true

[rendering]
renderer/rendering_method = "gl_compatibility"
```

### 29.2 Fichiers de Configuration Runtime (JSON)

| Fichier | Usage |
|---------|-------|
| `res://data/ai/config/prompts.json` | Prompts LLM (systeme + utilisateur) |
| `res://data/ai/config/prompt_templates.json` | Templates dynamiques |
| `res://data/ai/config/scenario_prompts.json` | Prompts par categorie scenario |
| `res://data/ai/config/scene_profiles.json` | Profils par scene |
| `res://data/ai/config/merlin_persona.json` | Personnalite Merlin |

### 29.3 Constantes Visuelles (MerlinVisual Autoload)

- `CRT_PALETTE` — Palette active (CRT terminal druido-tech)
- `PALETTE` — Legacy (parchemin mystique, migration graduelle)
- `GBC` — Game Boy Color (reference pixel art)
- `BIOME_ART_PROFILES` — 5 couleurs + densite par biome
- `BIOME_CRT_PALETTES` — 8 couleurs indexees par biome
- `SEASON_TINTS` — Multiplicateurs par saison

### 29.4 Theme Godot

`res://themes/merlin_theme.tres` — Defauts globaux: polices, boutons, labels.

### 29.5 Error Handling Strategy

| Pattern | Methode |
|---------|---------|
| Validation d'abord | Parse + validate avant apply |
| Degradation gracieuse | Fallback chains (LLM → FastRoute → erreur) |
| Logging, pas crash | `print()` + `push_warning()` pour debug |
| Defauts securises | Dict vide au lieu de null |
| Immutabilite | Toujours retourner nouveaux objets |

---

## Dimensions & Geometrie — Reference Rapide

| Composant | Dimensions | Notes |
|-----------|-----------|-------|
| PixelSceneCompositor | 220x220 px | 48x48 grille, 4.583 px/cell |
| PixelOghamIcon | 48x48 px | 16x16 grille, 3.0 px/cell |
| PixelBiomeBackdrop | 640x360 px (affichage) | 160x90 grille, 4x upscale |
| CardSceneCompositor | 440x220 px | Target default |
| MerlinBubble | 400 px large | Hauteur dynamique |
| Loading bar | 320x12 px | Centree sous logo |
| CeltOS logo | 322x70 px | 23x5 grille blocs |
| Bloc CeltOS | 12x12 px | 2 px gaps (stride 14 px) |

---

## Fichiers Source — Index

| Systeme | Chemin |
|---------|--------|
| Game Controller | `scripts/ui/merlin_game_controller.gd` |
| Store (State) | `scripts/merlin/merlin_store.gd` |
| Effect Engine | `scripts/merlin/merlin_effect_engine.gd` |
| Card System | `scripts/merlin/merlin_card_system.gd` |
| LLM Adapter | `scripts/merlin/merlin_llm_adapter.gd` |
| Reputation | `scripts/merlin/merlin_reputation_system.gd` |
| Constants | `scripts/merlin/merlin_constants.gd` |
| Save System | `scripts/merlin/merlin_save_system.gd` |
| MerlinVisual | `scripts/autoload/merlin_visual.gd` |
| MerlinAI | `addons/merlin_ai/merlin_ai.gd` |
| Ollama Backend | `addons/merlin_ai/ollama_backend.gd` |
| SFXManager | `scripts/autoload/SFXManager.gd` |
| MusicManager | `scripts/autoload/music_manager.gd` |
| IntroCeltOS | `scripts/IntroCeltOS.gd` |
| PixelSceneCompositor | `scripts/ui/pixel_scene_compositor.gd` |
| PixelOghamIcon | `scripts/ui/pixel_ogham_icons.gd` |
| PixelBiomeBackdrop | `scripts/ui/pixel_biome_backdrop.gd` |
| CardSceneCompositor | `scripts/ui/card_scene_compositor.gd` |
| MerlinBubble | `scripts/ui/merlin_bubble.gd` |
| MerlinRewardBadge | `scripts/ui/merlin_reward_badge.gd` |
| LLMSourceBadge | `scripts/ui/llm_source_badge.gd` |
| CRT Terminal Shader | `shaders/crt_terminal.gdshader` |
| CRT Static Shader | `shaders/crt_static.gdshader` |

---

# Part 4 — Sub-Systems Runtime

## 30. MerlinOmniscient (MOS)

> Source: `addons/merlin_ai/merlin_omniscient.gd` (~1100 lignes)

### 30.1 Role

Orchestrateur principal de la generation narrative. Coordonne LLM, RAG, guardrails, prefetch, et qualite.

### 30.2 Signaux

```gdscript
signal card_generated(card: Dictionary)
signal generation_failed(reason: String)
signal context_built(context: Dictionary)
signal trust_tier_changed(old_tier: int, new_tier: int)
signal pattern_detected(pattern: String, confidence: float)
signal wellness_alert(alert_type: String, data: Dictionary)
signal merlin_speaks(text: String, tone: String)
signal prefetch_ready
```

### 30.3 Architecture Interne

| Composant | Role |
|-----------|------|
| **5 Registries** | PlayerProfile, DecisionHistory, Relationship, Narrative, Session |
| **5 Processors** | ContextBuilder, DifficultyAdapter, EventAdapter, NarrativeScaler, ToneController |
| **4 Generators** | LLM (MerlinAI), FastRoute, RAGManager, EventCategorySelector |
| **1 Quality Judge** | BrainQualityJudge — score outputs LLM, selection best-of-N |

### 30.4 Constantes

```
LLM_TIMEOUT_MS = 300000           # 5 minutes (cold start CPU Qwen 3B)
MAX_RETRIES = 2
Recent cards memory = 15           # Prevention repetition
Response cache limit = 300         # Entrees max cache
```

### 30.5 Danger Thresholds

| Seuil | Valeur | Effet |
|-------|--------|-------|
| `DANGER_LIFE_CRITICAL` | 15 | Mode immediat: cartes de survie |
| `DANGER_LIFE_LOW` | 25 | Reduction difficulte |
| `DANGER_LIFE_WOUNDED` | 50 | Signal au LLM: joueur blesse |
| `DANGER_BLOCK_CATASTROPHE_AT` | 15 | Bloquer events catastrophe |

### 30.6 Pipeline de Generation (11 etapes)

```
1. Check prefetch (hash validation, biome match)
2. Phase 44: Select event category (EventCategorySelector)
3. Select card modifier (minigame pool, effect modifiers)
4. ~15% chance: Inject calendar event (EventAdapter)
5. Sync registries → RAG v3.0 (prioritized retrieval)
6. Adaptive processing (difficulty scaling)
7. Generate (Fast Route OR LLM)
8. Guardrails (langue, repetition, longueur)
9. Post-process (difficulty scaling)
10. Tag scenario anchors (si actif)
11. Log card dans RAG journal
```

### 30.7 Guardrails

```
Min text: 30 caracteres
Max text: 800 caracteres
2+ mots-cles francais requis
Similarity threshold: 0.5 (vs cartes recentes)
```

### 30.8 Prefetch

```
Profondeur: 1 carte (defaut), 2-3 avec BitNet swarm
Validation: hash de contexte (changement state = miss)
Timeout: 180s max, annule si depasse
```

### 30.9 Stats Tracking

```
cards_generated, llm_successes, llm_failures,
fallback_uses, fast_route_hits, prefetch_hits,
prefetch_misses, average_generation_time_ms
```

---

## 31. RAGManager v3.0

> Source: `addons/merlin_ai/rag_manager.gd`

### 31.1 Budget Tokens par Brain

```gdscript
CHARS_PER_TOKEN = 4    # ~4 chars = 1 token (heuristique multilingue)
BRAIN_BUDGETS = {
    "narrator": 800,   # 4B model, 8192 context
    "gamemaster": 400,  # 2B model, 4096 context
    "judge": 200,       # 0.8B model, 2048 context
    "worker": 200,      # 0.8B model, 2048 context
}
```

### 31.2 Storage Paths

```
user://ai/memory/game_journal.json       # Journal run courant
user://ai/memory/cross_run_memory.json   # Memoire cross-run
user://ai/memory/world_state.json        # Etat monde
```

### 31.3 Journal (Run Courant)

```
Max entries: 100
Types: card_played, choice_made, effect_applied,
       aspect_shifted, ogham_used, run_event
Schema: {type, card_num, day, data, timestamp}
```

### 31.4 Cross-Run Memory

```
Max summaries: 20
Schema: {run_id, ending, cards_played, dominant_faction,
         notable_events, player_style, score}
```

### 31.5 Retrieval Priorite

| Priorite | Sections |
|----------|----------|
| CRITICAL (4) | Contexte crise, contrat scene |
| HIGH (3) | Narratif recent, arcs actifs, biome, tone, karma/tension |
| MEDIUM (2) | Promesses, patterns joueur |
| LOW (1) | Backstory, events monde |
| OPTIONAL (0) | Historique ancien |

### 31.6 API

```gdscript
get_prioritized_context(game_state, brain_role) -> String
estimate_tokens(text) -> int
trim_to_budget(text, max_tokens) -> String
log_card_played(card, cards_played, day)
get_recent_narrative() -> String
get_active_arcs_context() -> String
get_promises_context() -> String
```

---

## 32. MerlinScenarioManager

> Source: `scripts/merlin/merlin_scenario_manager.gd` (~343 lignes)

### 32.1 Signaux

```gdscript
signal scenario_started(scenario_id: String)
signal anchor_triggered(anchor_id: String, card_index: int)
signal scenario_resolved(scenario_id: String, resolution: String)
```

### 32.2 Catalogue

Path: `res://data/ai/scenarios/scenario_catalogue.json`

### 32.3 Selection (au demarrage du run)

```
1. Filtrer par biome affinity (vide = tous biomes)
2. Scaling poids: 0.3x si vu recemment
3. Selection aleatoire ponderee
```

### 32.4 Systeme d'Anchors

- Anchors positionnes a des indices de carte (avec ±flex tolerance)
- Conditions: checks de flags (single, any, all)
- Branches: `if_flag_*` + `default`
- Chaque branche: `prompt_override`, `flags_set`, `tone`
- Max 1 anchor par carte
- Cartes anchor taguees `"scenario_anchor"` dans `card["tags"]`

### 32.5 Context Injection

```gdscript
get_theme_injection() -> String     # Texte thematique pour chaque prompt LLM
get_dealer_intro_override() -> String  # Contexte pour monologue TransitionBiome
get_scenario_tone() -> String       # Tone emotionnel dominant
get_ambient_tags() -> Array         # Tags pour cartes non-anchor
```

### 32.6 Scenarios Documentes

**1. La Fille Perdue de Broceliande** (medium)
- Affinite: foret_broceliande + marais_korrigans
- Anchors: fille_trace (carte 3±1), fille_chasseur (carte 8±2), fille_climax (carte 14±2)
- Resolutions: victoire / sombre / twist

**2. Le Serment du Cerf d'Argent** (hard)
- Affinite: foret + cercles + collines
- Anchors: cerf_vision (carte 2±1), cerf_gardien (carte 6±1), cerf_epreuve (carte 11±2), cerf_serment (carte 16±2)
- Flags: serment_accepte / refuse / cerf_etait_merlin

**3. La Forge du Korrigan** (medium)
- Affinite: marais + foret + collines
- Anchors: korrigan_bruit (carte 3±1), korrigan_marche (carte 7±2), korrigan_trahison (climax)
- Flags: objet_maudit, korrigan_surpasse, dette_korrigan

---

## 33. MerlinBiomeSystem

> Source: `scripts/merlin/merlin_biome_system.gd` (~385 lignes)

### 33.1 8 Biomes Complets

| Biome | Affinite | Difficulte | Passif | Ogham Bonus |
|-------|----------|-----------|--------|-------------|
| foret_broceliande | korrigans 1.2x | 0 | korrigans ↑ /5 cartes | beith, huath, coll |
| landes_bruyere | anciens 1.2x | +1 | anciens ↓ /6 cartes | luis, onn, saille |
| cotes_sauvages | niamh 1.2x | 0 | niamh ↑ /5 cartes | muin, nuin, tinne |
| villages_celtes | druides 1.2x | -1 | druides ↑ /4 cartes | duir, coll, beith |
| cercles_pierres | druides 1.4x | +1 | druides ↑ /4 cartes | ioho, straif, ruis |
| marais_korrigans | korrigans 1.4x | +2 | korrigans ↓ /5 cartes | gort, eadhadh, luis |
| collines_dolmens | balanced 1.0x | 0 | random faction /7 cartes | quert, ailm, coll |
| iles_mystiques | niamh 1.4x | +3 | niamh random /4 cartes | ailm, ruis, ioho |

### 33.2 Effets Passifs

```
Trigger: toutes les N cartes (every_n)
Direction:
  "up" → HEAL_LIFE +5
  "down" → DAMAGE_LIFE -5
  "random" → aleatoire up/down
```

### 33.3 Ogham Cooldown Bonus

En biome aligne: cooldown reduit de 1-2 tours.

### 33.4 Unlock Conditions

| Biome | Min Runs | Min Endings | Ending Requis |
|-------|----------|-------------|---------------|
| foret_broceliande | 0 | 0 | — |
| landes_bruyere | 2 | 0 | — |
| cotes_sauvages | 3 | 0 | — |
| villages_celtes | 5 | 0 | — |
| cercles_pierres | 8 | 2 | — |
| marais_korrigans | 10 | 0 | "harmonie" |
| collines_dolmens | 15 | 5 | — |
| iles_mystiques | 20 | 5 | "transcendance" |

### 33.5 Saison Favorisee

Chaque biome a une `favored_season` (bonus contexte LLM).

### 33.6 Tuning Externe

`res://data/balance/tuning.json` peut overrider les definitions biome.

---

## 34. MerlinMapSystem

> Source: `scripts/merlin/merlin_map_system.gd` (~126 lignes)

### 34.1 Types de Noeuds

| Type | Poids | Cartes Min-Max |
|------|-------|---------------|
| NARRATIVE | 5.0 | 2-4 |
| EVENT | 2.0 | 1-2 |
| PROMISE | 1.0 | 1-3 |
| REST | 1.5 | 0 |
| MERCHANT | 1.0 | 0 |
| MYSTERY | 1.0 | 1-2 |
| MERLIN | 0.0 (fin only) | 1 |

### 34.2 Generation de Map

```
Floors: user-specified (min 3)
Floor 0 (depart): 1 noeud NARRATIVE
Floor N-1 (fin): 1 noeud MERLIN
Milieu: 2-3 noeuds aleatoires
Point median: REST ou MERCHANT force
Positions X: 50% centre (1 noeud), 15-85% (multi)
```

### 34.3 Connexions

```
Chaque noeud courant: ≥1 parent
Chaque noeud precedent: ≥1 enfant
Extra connexions: max 3/noeud, ~45% chance aleatoire
```

---

## 35. MerlinActionResolver

> Source: `scripts/merlin/merlin_action_resolver.gd` (~124 lignes)

### 35.1 Style Modifiers

```gdscript
STYLE_MODS = {
    "PROTECTEUR": {FORCE: -2, LOGIQUE: 3, FINESSE: 0},
    "AVENTUREUX": {FORCE: 2, LOGIQUE: -1, FINESSE: 2},
    "PRAGMATIQUE": {FORCE: 2, LOGIQUE: 2, FINESSE: -1},
    "SOMBRE": {FORCE: 0, LOGIQUE: 0, FINESSE: 2},
    "PEDAGOGUE": {FORCE: 0, LOGIQUE: 3, FINESSE: 0},
}
```

### 35.2 Posture Modifiers

```gdscript
POSTURE_MODS = {
    "Prudence": {FORCE: 0, LOGIQUE: 2, FINESSE: 1},
    "Agressif": {FORCE: 3, LOGIQUE: -1, FINESSE: 0},
    "Ruse": {FORCE: 0, LOGIQUE: 0, FINESSE: 3},
    "Serenite": {FORCE: 1, LOGIQUE: 1, FINESSE: 1},
}
```

### 35.3 Classification Success/Risk

| Score | Chance | Risk |
|-------|--------|------|
| < 35 | Low | Severe |
| 35-65 | Medium | Moderate |
| > 65 | High | Light |

### 35.4 Output Structure

```gdscript
{
    "verb": verb_name,
    "subchoice": subchoice_label,
    "score": clamped_attribute_score,
    "chance": "Low" | "Medium" | "High",
    "risk": "Severe" | "Moderate" | "Light",
    "hidden_test": {type, difficulty, modifiers},
    "costs": context_costs,
    "gain": context_gain,
}
```

---

## 36. MerlinEventSystem

> Source: `scripts/merlin/merlin_event_system.gd` (~74 lignes)

### 36.1 Flow Principal

```
1. Validate scene (LLM validation via MerlinLlmAdapter)
2. Get choices for verb
3. Resolve action (ActionResolver)
4. Run minigame (test type & difficulty)
5. Check force_soft_success (pity system)
6. Apply effects (success → on_success, fail → on_fail)
7. Update fail streak
8. Reset one-shot mods
```

### 36.2 Output

```gdscript
{
    "ok": bool,
    "scene_id": string,
    "resolution": action_resolver_output,
    "outcome": minigame_result,
    "effects": effect_application_result,
}
```

---

## 37. GameTimeManager

> Source: `scripts/autoload/game_time_manager.gd` (~170 lignes)

### 37.1 Signaux

```gdscript
signal period_changed(new_period: String)
signal season_changed(new_season: String)
```

### 37.2 Update Interval

5 minutes (300s)

### 37.3 Periodes (basees sur l'heure systeme)

| Periode | Heures | Faction Bonus |
|---------|--------|---------------|
| aube | 5-8 | druides +10% |
| jour | 8-18 | (aucun) |
| crepuscule | 18-21 | korrigans +10% |
| nuit | 21-5 | ankou +15% |

### 37.4 Saisons (basees sur le mois)

| Saison | Mois | Faction Bonus |
|--------|------|---------------|
| hiver | 12, 1-2 | niamh +20% |
| printemps | 3-5 | druides +20% |
| ete | 6-8 | anciens +20% |
| automne | 9-11 | ankou +30% |

### 37.5 Festivals (Sabbats)

| Mois | Festival |
|------|----------|
| Fevrier | Imbolc |
| Mai | Beltane |
| Aout | Lughnasadh |
| Octobre | Samhain |

### 37.6 Context Output

```gdscript
{
    "period": "jour" | "aube" | "crepuscule" | "nuit",
    "season": "printemps" | "ete" | "automne" | "hiver",
    "festival": "Imbolc" | "Beltane" | "Lughnasadh" | "Samhain" | "",
    "hour": int,
    "reputation_bonus": {faction: float, ...}
}
```

---

## 38. PixelTransition

> Source: `scripts/autoload/pixel_transition.gd` (~400 lignes)

### 38.1 Machine a Etats

```
IDLE → EXITING → BLACK → ENTERING → IDLE
```

### 38.2 Signaux

```gdscript
signal transition_started(scene_path: String)
signal exit_complete
signal enter_complete
signal transition_complete(scene_path: String)
```

### 38.3 Parametres de Rendu

```
Block size: 10px
Element stagger: 0.08s
Min element area: 400 px²
Total duration: 0.8s
```

### 38.4 Animation

```
EXIT: pixels scattered upward from element centers
BLACK: brief pause at midpoint
ENTER: pixels fall back and assemble
```

### 38.5 Donnees Pixel (flat arrays pour performance)

```
_colors_r/g/b:  couleurs par pixel
_grid_x/y:      positions cible ecran
_cur_x/y/a:     positions animation courantes
_from_x/y:      positions depart
_to_x/y:        positions fin
_delay:          delai par pixel
_elem_id:        quel element possede chaque pixel
```

### 38.6 Profiles

`PixelTransitionConfig.get_profile(scene_path)` — settings par scene.
Flags optionnels: `skip_exit`, `skip_enter`.

---

## 39. ScreenEffects — Mood System

> Source: `scripts/autoload/ScreenEffects.gd` (~150 lignes)

### 39.1 Signaux

```gdscript
signal effects_enabled
signal effects_disabled
signal intensity_changed(new_intensity: float)
signal mood_changed(mood: String)
```

### 39.2 7 Merlin Mood Profiles

| Mood | Tone | chromatic | scanline | glitch |
|------|------|-----------|----------|--------|
| sage | NEUTRAL | 0.0005 | 0.0002 | 0.003 |
| amuse | PLAYFUL | 0.0003 | 0.0001 | 0.001 |
| mystique | MYSTERIOUS | 0.003 | 0.0006 | 0.005 |
| serieux | WARNING | 0.002 | 0.001 | 0.04 |
| pensif | MELANCHOLY | 0.001 | 0.0008 | 0.006 |
| warm | WARM | 0.0004 | 0.0002 | 0.002 |
| cryptic | CRYPTIC | 0.004 | 0.001 | 0.025 |

### 39.3 Parametres Shader Controles (8)

```
chromatic_intensity, scanline_wobble_intensity,
glitch_probability, barrel_intensity,
color_shift_intensity, noise_intensity,
vignette_intensity, flicker_intensity
```

### 39.4 Transition Mood

Duree: 0.6s (tweened).

---

## 40. ScreenFrame — CRT Border

> Source: `scripts/autoload/screen_frame.gd` (~384 lignes)

### 40.1 Composants

```
4 bordures (haut, bas, gauche, droite): 12px large
4 coins Celtic knot (24x24px): pixel-art procedural
1 LLM status crystal (12x12px, bas-gauche, dans la bordure)
```

### 40.2 Etats du Cristal LLM

| Etat | Couleur | Animation |
|------|---------|-----------|
| DISCONNECTED | Gris inactif | Fixe |
| WARMUP | Ambre remplissage (bas→haut) | Fill progressif |
| READY | Cyan + pulse | sin wave |
| GENERATING | Ambre + pulse rapide | Oscillation acceleree |
| ERROR | Rouge clignotant | Blink |

### 40.3 Biome Tint

```gdscript
set_biome_tint(color):
    # Blend bordure avec couleur biome a 25%
```

### 40.4 Pulse Duration

2.0s cycle complet.

---

## 41. ScreenDither — CRT Presets

> Source: `scripts/ui/screen_dither_layer.gd` (~145 lignes)

### 41.1 4 Presets

| Preset | global_intensity | curvature | scanline | dither | glow | tint_blend |
|--------|-----------------|-----------|----------|--------|------|------------|
| off | 0.0 | — | — | — | — | — |
| subtle | 0.4 | 0.02 | 0.10 | 0.2 | 0.08 | 0.04 |
| medium | 0.6 | 0.04 | 0.18 | 0.3 | 0.12 | 0.06 |
| heavy | 0.85 | 0.07 | 0.28 | 0.45 | 0.18 | 0.10 |

**Defaut:** "medium"

### 41.2 API

```gdscript
set_intensity(value: float)
set_crt_preset(preset_name: String)
set_phosphor_tint(color: Color)           # Teinte biome
set_curvature(value: float)
set_scanline_opacity(value: float)
set_phosphor_glow(value: float)
tween_parameter(param_name, from, to, duration)  # Transitions douces
```

---

## 42. IntroPersonalityQuiz

> Source: `scripts/IntroPersonalityQuiz.gd` (~250 lignes)

### 42.1 4 Axes de Personnalite (chacun -2 a +2)

```
approche:  prudent (-) ↔ audacieux (+)
relation:  solitaire (-) ↔ social (+)
esprit:    analytique (-) ↔ intuitif (+)
coeur:     pragmatique (-) ↔ compassionnel (+)
```

### 42.2 8 Archetypes

| Archetype | Pattern | Titre |
|-----------|---------|-------|
| gardien | approche:-1, coeur:+1 | Le Gardien |
| explorateur | approche:+1, esprit:+1 | L'Explorateur |
| sage | relation:-1, esprit:-1 | Le Sage |
| heros | approche:+1, relation:+1 | Le Heros |
| guerisseur | coeur:+1, relation:+1 | Le Guerisseur |
| stratege | esprit:-1, approche:-1 | Le Stratege |
| mystique | esprit:+1, relation:-1 | Le Mystique |
| guide | coeur:+1, esprit:+1 | Le Guide |

### 42.3 Quiz: 15 Questions

- Q1-3: Axes de personnalite de base
- Q4: Portrait Printemps (choix saisonnier)
- Q5-7: Tests approfondis
- Q8: Portrait Ete
- Q9-11: Reponses situationnelles
- Q12: Portrait Automne
- Q13-14: Pression/conflit
- Q15: Reflexion finale + Portrait Hiver

### 42.4 Chaque Question

4 choix, chacun modifie les axes de ±1 a ±2.
Score total: somme sur les 15 questions.
Archetype: meilleur pattern match.

### 42.5 Output

```gdscript
{
    "archetype_id": string,
    "archetype_title": string,
    "dominant_traits": [string],
    "axis_scores": {approche, relation, esprit, coeur},
}
```

---

## 43. HubController

> Source: `scripts/ui/hub_controller.gd` (~200 lignes)

### 43.1 Signaux

```gdscript
signal hub_ready()
signal run_requested(biome: String, ogham: String)
signal talent_unlocked(talent_id: String)
```

### 43.2 API

```gdscript
show_hub()                            # Charger profile, emettre ready
get_profile_summary() -> Dictionary   # Resume profile
generate_merlin_dialogue(last_run)    # LLM ou fallback greeting
show_talent_tree()                    # Talents disponibles, cout, prereqs
unlock_talent(talent_id)              # Depenser Anam, update profile
```

### 43.3 Dialogue Merlin Fallback

| Condition | Phrase |
|-----------|--------|
| 0 runs | "Bienvenue, jeune druide..." |
| Derniere mort | "La mort n'est qu'un passage..." |
| Hard max | "Tu as parcouru un long chemin..." |
| Autre | Phrases rotees (run_count % array_size) |

---

## 44. WorldMapSystem

> Source: `scripts/autoload/world_map_system.gd` (~200 lignes)

### 44.1 Signaux

```gdscript
signal gauges_changed(gauges: Dictionary)
signal biome_unlocked(biome_key: String)
signal biome_completed(biome_key: String)
signal map_state_changed(map_state: Dictionary)
signal fallback_event_triggered(biome_key: String, event_data: Dictionary)
```

### 44.2 Sous-Systemes

- `MerlinGaugeSystem` — tracking jauges & modificateurs biome
- `MerlinBiomeTree` — conditions unlock, progression

### 44.3 Fallback Events (biome inaccessible)

| Event | Type | Effet |
|-------|------|-------|
| npc_encounter | NPC | faveur +10, ressources +5 |
| essence_trade | TRADE | ressources +15 |
| druid_blessing | BLESSING | esprit +10, logique +5 |
| training_camp | TRAINING | vigueur +15 |

---

## Fichiers Source — Index Complet (v2.0)

| Systeme | Chemin |
|---------|--------|
| Game Controller | `scripts/ui/merlin_game_controller.gd` |
| Store (State) | `scripts/merlin/merlin_store.gd` |
| Effect Engine | `scripts/merlin/merlin_effect_engine.gd` |
| Card System | `scripts/merlin/merlin_card_system.gd` |
| LLM Adapter | `scripts/merlin/merlin_llm_adapter.gd` |
| Reputation | `scripts/merlin/merlin_reputation_system.gd` |
| Constants | `scripts/merlin/merlin_constants.gd` |
| Save System | `scripts/merlin/merlin_save_system.gd` |
| MerlinVisual | `scripts/autoload/merlin_visual.gd` |
| MerlinAI | `addons/merlin_ai/merlin_ai.gd` |
| MerlinOmniscient | `addons/merlin_ai/merlin_omniscient.gd` |
| RAGManager | `addons/merlin_ai/rag_manager.gd` |
| Ollama Backend | `addons/merlin_ai/ollama_backend.gd` |
| BrainSwarmConfig | `addons/merlin_ai/brain_swarm_config.gd` |
| SFXManager | `scripts/autoload/SFXManager.gd` |
| MusicManager | `scripts/autoload/music_manager.gd` |
| GameTimeManager | `scripts/autoload/game_time_manager.gd` |
| PixelTransition | `scripts/autoload/pixel_transition.gd` |
| ScreenEffects | `scripts/autoload/ScreenEffects.gd` |
| ScreenFrame | `scripts/autoload/screen_frame.gd` |
| ScreenDither | `scripts/ui/screen_dither_layer.gd` |
| WorldMapSystem | `scripts/autoload/world_map_system.gd` |
| IntroCeltOS | `scripts/IntroCeltOS.gd` |
| IntroPersonalityQuiz | `scripts/IntroPersonalityQuiz.gd` |
| HubController | `scripts/ui/hub_controller.gd` |
| ScenarioManager | `scripts/merlin/merlin_scenario_manager.gd` |
| BiomeSystem | `scripts/merlin/merlin_biome_system.gd` |
| MapSystem | `scripts/merlin/merlin_map_system.gd` |
| ActionResolver | `scripts/merlin/merlin_action_resolver.gd` |
| EventSystem | `scripts/merlin/merlin_event_system.gd` |
| MinigameSystem | `scripts/merlin/merlin_minigame_system.gd` |
| PixelSceneCompositor | `scripts/ui/pixel_scene_compositor.gd` |
| PixelOghamIcon | `scripts/ui/pixel_ogham_icons.gd` |
| PixelBiomeBackdrop | `scripts/ui/pixel_biome_backdrop.gd` |
| CardSceneCompositor | `scripts/ui/card_scene_compositor.gd` |
| MerlinBubble | `scripts/ui/merlin_bubble.gd` |
| MerlinRewardBadge | `scripts/ui/merlin_reward_badge.gd` |
| LLMSourceBadge | `scripts/ui/llm_source_badge.gd` |
| CRT Terminal Shader | `shaders/crt_terminal.gdshader` |
| CRT Static Shader | `shaders/crt_static.gdshader` |
| Scenario Catalogue | `data/ai/scenarios/scenario_catalogue.json` |
| Merlin Persona | `data/ai/config/merlin_persona.json` |
| FastRoute Cards | `data/ai/fastroute_cards.json` |
| Event Cards | `data/ai/event_cards.json` |
| Promise Cards | `data/ai/promise_cards.json` |

---

*GAME_BEHAVIOR.md v2.0 — 2026-03-15*
*Companion de GAME_ENCYCLOPEDIA.md v4.0 et GAME_MECHANICS.md v2.0*
