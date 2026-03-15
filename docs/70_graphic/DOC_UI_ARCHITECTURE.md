# Architecture UI — Couche Présentation du Jeu Merlin

**Dernière mise à jour**: 2026-03-15
**Version**: 1.0
**Auteur**: Documentation Technique M.E.R.L.I.N.

---

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture générale](#architecture-générale)
3. [Arborescence des composants](#arborescence-des-composants)
4. [Flux des signaux](#flux-des-signaux)
5. [MerlinGameController](#merlingamecontroller)
6. [Système de cartes UI](#système-de-cartes-ui)
7. [Système HUD](#système-hud)
8. [Écrans de transition](#écrans-de-transition)
9. [Visuels et constantes](#visuels-et-constantes)
10. [Patterns et bonnes pratiques](#patterns-et-bonnes-pratiques)

---

## Vue d'ensemble

La couche UI de Merlin est une architecture **découplée et réactive** qui établit un pont entre la logique métier (Store) et la présentation (scènes Godot). Elle utilise un pattern **Store → UI Bridge** via signaux Godot, combiné avec une composit ion procédurale et dynamique des éléments visuels.

### Principes architecturaux

- **Séparation des responsabilités** : Store (état) ≠ Controller (orchestration) ≠ UI (présentation)
- **Réactivité basée signaux** : Les changements d'état déclenchent des mises à jour UI via les signaux du Store
- **Composition procédurale** : Les cartes, écrans de pixel art et HUD sont assemblés dynamiquement
- **Thème CRT cyberpunk** : Tous les éléments respectent la palette CRT_PALETTE centralisée (MerlinVisual)
- **Immutabilité des données** : Les mises à jour UI ne modifient pas l'état (lecture seule du Store)

### Acteurs principaux

| Composant | Rôle | Entrées | Sorties |
|-----------|------|---------|---------|
| **MerlinStore** | État global (singletons) | - | Signaux reputation_changed, life_changed |
| **MerlinGameController** | Orchestrateur du jeu | Signaux du Store | Orchestration minigames, gestion run |
| **MerlinGameUI** | Interface de gameplay | Références de nœuds | option_chosen, skill_activated |
| **HudController** | HUD 3D walk | Signaux Run3DController | Affichage PV, Souffle, Essences |
| **CardSceneCompositor** | Compositeur de cartes | Tags visuels, biome | Scène procédurale 4 couches |
| **WalkHUD** | HUD minimal 3D | État local | Affichage PV bar, Souffle, Zone |
| **EndRunScreen** | Écran de fin | Données run + rewards | screen_completed, faction_chosen |

---

## Architecture générale

```
┌─────────────────────────────────────────────────────────────────┐
│                      COUCHE MÉTIER (Scripts/)                   │
│  MerlinStore (État) ← MerlinGameController (Orchestration)      │
│  Signaux: reputation_changed, life_changed, card_drawn          │
└──────────────────────────┬──────────────────────────────────────┘
                           │ Signaux + Appels
                           ↓
┌─────────────────────────────────────────────────────────────────┐
│                   COUCHE PRÉSENTATION (UI Layer)                │
│                   Responsabilité: Affichage seul                │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ MerlinGameUI (Scène gameplay 2D)                           │ │
│  │  ├─ TopStatusBar (Vie, Souffle, Factions)                │ │
│  │  ├─ CardZone (Illustration + 3 options)                  │ │
│  │  ├─ BottomZone (Feedback texte, contrôles)              │ │
│  │  └─ Overlays (Thinking, Tutorial)                        │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ WalkHUD (Overlay 3D walk)                                 │ │
│  │  ├─ PV Bar (minimal)                                      │ │
│  │  ├─ Souffle Icons                                         │ │
│  │  ├─ Essences Counter                                      │ │
│  │  └─ Zone Label (aube/jour/soir/nuit)                    │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ EndRunScreen (Post-run results)                           │ │
│  │  ├─ Screen 0: Narrative ending                           │ │
│  │  ├─ Screen 1: Journey map                                │ │
│  │  ├─ Screen 2: Rewards summary                            │ │
│  │  └─ Screen 3: Faction choice (opt)                       │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Compositors (Procédural)                                  │ │
│  │  ├─ CardSceneCompositor (4 couches parallax)             │ │
│  │  ├─ PixelSceneCompositor (48×48 pixel art)              │ │
│  │  └─ PixelSceneData (Données packed arrays)              │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Flux de données

```
Store.reputation_changed
    ↓
MerlinGameUI._on_reputation_changed()
    ↓
ReputationHud.update_faction(faction, value)
    ↓
Label.text = "Druides: 45"  (affichage)
```

---

## Arborescence des composants

### Vue organisée par fonction

```
scripts/ui/
├─ CONTRÔLEURS PRINCIPAUX
│  ├─ merlin_game_controller.gd       [36 KB] Orchestrateur principal
│  ├─ merlin_game_ui.gd               [28 KB] Interface gameplay 2D
│  ├─ hud_controller.gd               [8 KB]  HUD 3D walk (deprecated)
│  └─ hub_controller.gd               [6 KB]  Contrôleur hub menu
│
├─ CARTES ET ILLUSTRATIONS
│  ├─ card_scene_compositor.gd        [44 KB] Compositeur 4 couches
│  ├─ pixel_scene_compositor.gd       [52 KB] Compositeur 48×48 pixel art
│  ├─ card_layer.gd                   [2 KB]  Classe données layer
│  ├─ pixel_scene_data.gd             [8 KB]  Données packed arrays
│  ├─ layered_scene_data.gd           [3 KB]  Métadonnées layers
│  └─ card_scene_compositor.gd        [44 KB] Compositeur parallax layers
│
├─ HUD ET AFFICHAGE 3D
│  ├─ walk_hud.gd                     [18 KB] Minimal HUD (PV, Souffle, Zone)
│  ├─ walk_event_overlay.gd           [4 KB]  Overlay événement marche
│  └─ reputation_hud.gd               [2 KB]  Affichage réputations factions
│
├─ ÉCRANS DE TRANSITION
│  ├─ end_run_screen.gd               [16 KB] Écran fin de run (3-4 screens)
│  ├─ tutorial_card_layer.gd          [6 KB]  Overlay tutoriel
│  └─ llm_warmup_overlay.gd           [3 KB]  Écran chargement LLM
│
├─ ÉLÉMENTS VISUELS SPÉCIALISÉS
│  ├─ pixel_merlin_portrait.gd        [22 KB] Portrait Merlin 48×48
│  ├─ pixel_npc_portrait.gd           [18 KB] Portrait PNJ 48×48
│  ├─ pixel_character_portrait.gd     [16 KB] Portrait joueur 48×48
│  ├─ pixel_ogham_icons.gd            [8 KB]  Icônes Oghams
│  ├─ pixel_biome_backdrop.gd         [6 KB]  Fond biome pixel
│  ├─ arbre_de_vie_ui.gd              [12 KB] Arbre de vie animation
│  ├─ arbre_pixel_art.gd              [14 KB] Arbre pixel art procédural
│  ├─ merlin_bubble.gd                [4 KB]  Bulle dialogue Merlin
│  ├─ merlin_reward_badge.gd          [3 KB]  Badge récompense
│  └─ llm_source_badge.gd             [2 KB]  Indicateur source LLM
│
├─ MENUS ET NAVIGATION
│  ├─ map_ui.gd                       [8 KB]  Carte biomes interactive
│  ├─ biome_radial.gd                 [6 KB]  Sélection radiale biome
│  ├─ hub_hotspot.gd                  [4 KB]  Hotspot interactif
│  ├─ menu_return_button.gd           [2 KB]  Bouton retour
│  ├─ custom_cursor.gd                [2 KB]  Curseur personnalisé
│  └─ screen_dither_layer.gd          [2 KB]  Effet dither écran
│
├─ SPRITE FACTORY (Procédural)
│  ├─ sprite_factory.gd               [44 KB] Générateur sprites
│  ├─ sprite_templates.gd             [18 KB] Templates creatures
│  ├─ sprite_palette.gd               [6 KB]  Mappings couleur
│  └─ sprite_noise.gd                 [4 KB]  Bruit Perlin/Simplex
│
├─ DONNÉES ET CONFIGURATION
│  ├─ ambiance_data.gd                [6 KB]  Données ambiance/lumière
│  ├─ pixel_matrix_bg.gd              [3 KB]  Fond matrice CRT
│  └─ custom_cursor.gd                [2 KB]  Configuration curseur
│
└─ AUTOLOAD (Singleton)
   └─ scripts/autoload/merlin_visual.gd [28 KB] Palette + Constantes visuelles
```

### Statistiques

- **36 scripts UI** dans `scripts/ui/`
- **1 singleton** (`merlin_visual.gd`) centralisé dans `scripts/autoload/`
- **Taille totale** : ~450 KB code + données
- **Langages** : 100% GDScript (Godot 4.x)

---

## Flux des signaux

### Signaux du Store

Le `MerlinStore` (état global) émet des signaux qui déclenchent les mises à jour UI. L'UI ne doit **jamais** modifier le Store directement — lecture seule.

```gdscript
# MerlinStore (source de vérité)
signal reputation_changed(faction: String, value: float, delta: float)
signal life_changed(current: int, max_pv: int)
signal card_drawn(card: Dictionary)
signal run_started(biome: String, season: String)
signal run_ended(reason: String)
```

### Signaux UI → Controller

L'UI émet des signaux que le Controller écoute pour déclencher la logique métier.

```gdscript
# MerlinGameUI
signal option_chosen(option: int)              # 0=LEFT, 1=CENTER, 2=RIGHT
signal skill_activated(skill_id: String)       # Ogham activation
signal pause_requested
signal souffle_activated
signal merlin_dialogue_requested(player_input: String)
signal journal_requested
```

### Chaîne complète : Store → UI → Controller → Store

```
1. Store.set_life(80)
   ↓ (émet signal)
   ↓
2. MerlinGameUI._on_life_changed(80, 100)
   ↓ (met à jour contrôles)
   ↓
3. _life_bar.value = 80
   _life_counter.text = "80/100"
   ↓
4. [Joueur clique option LEFT]
   ↓
5. MerlinGameUI.option_chosen.emit(0)
   ↓
6. MerlinGameController._on_option_chosen(0)
   ↓
7. Controller fait appel au Store pour déclencher effets
   ↓
8. Boucle : Store change → retour à étape 1
```

### Graphe des dépendances (vue simplifiée)

```
MerlinStore (singleton)
    ↓ (signaux)
MerlinGameUI
    ├─ Signaux → MerlinGameController
    ├─ Appels directs : CardSceneCompositor.compose_layers()
    ├─ Appels directs : WalkHUD.update_pv()
    └─ Appels directs : ReputationHud.update_all()

MerlinGameController
    ├─ Écoute Store
    ├─ Orchestration : CardBuffer, LLM, Minigames
    └─ Appels → Store (modifications d'état)

HudController (ancien — à déprecier)
    ├─ Écoute Run3DController
    └─ Affichage HUD minimal

EndRunScreen (modal)
    ├─ Reçoit données run + rewards
    └─ Signaux : screen_completed, faction_chosen
```

---

## MerlinGameController

Le contrôleur principal du jeu, responsable de l'orchestration complète du gameplay.

### Responsabilités

1. **Orchestration de run** : Démarrage, management des phases
2. **Génération de cartes** : Buffering LLM, fallback pools
3. **Minigames** : D20 vs mini-games avec scoring
4. **Effets de carte** : Appels à MerlinEffectEngine
5. **Gestion du state local** : Karma, Blessings, Tutorial
6. **LLM wiring** : Intégration Qwen 3.5 via MerlinAI

### Structure interne

```gdscript
extends Node
class_name MerlinGameController

var store: MerlinStore                  # Référence singleton
var ui: MerlinGameUI                    # Interface principale
var merlin_ai: Node = null              # Interface LLM (MerlinAI)

# Run-local state (reset chaque start_run)
var _karma: int = 0                     # [-10, +10] pour difficulty
var _blessings: int = 0                 # Réserve de blessings (max 2)
var _critical_choice := false           # Choix critique dégagé?
var _critical_used := false             # Critique utilisé dans la run?
var _minigames_won: int = 0

# Card buffer (smooth gameplay)
var _card_buffer: Array[Dictionary] = []
const BUFFER_SIZE := 5                  # Ollama: <3s/card → ~15s buffer

# Tutorial system
var _tutorial_shown: Dictionary = {}    # { "trigger_key": true }
var _tutorial_data: Dictionary = {}     # Chargé de tutorial_narratives.json

# LLM generation
const LLM_TIMEOUT_SEC := 360.0          # 6 minutes timeout

# D20 Dice system
const DICE_ROLL_DURATION := 3.0
var minigame_chance := 0.3              # 30% minigames
var headless_mode := false              # Disable minigames for tests
```

### Principales phases de jeu

```
1. _ready() → Initialisation signaux + chargement tutorial

2. start_run() → Setup biome, intro speech, première carte

3. _show_card(card: Dictionary) → Affichage carte + 3 options

4. _on_option_chosen(option: int) → Résolution choix
   ├─ Minigame? (30% chance)
   │  └─ _play_minigame(aspect) → D20 roll vs DC variable
   │  └─ Scoring → Score multiplié par difficulty dynamique
   ├─ Ou D20 simple (70%)
   └─ Résolution via MerlinEffectEngine

5. _process_effects(card, option, score) → Appels Store
   ├─ Store.drain_life(-1)
   ├─ Store.apply_effect(effect_type, value)
   ├─ Store.change_reputation(faction, delta)
   └─ etc...

6. _draw_next_card() → Buffer management + prefetch LLM

7. end_run() → Transition vers EndRunScreen
```

### Card Buffer (système clé)

Le buffer lisse le gameplay en pré-chargeant les cartes pendant que le joueur joue :

```gdscript
func _process_card_buffer() -> void:
    while _card_buffer.size() < BUFFER_SIZE:
        var card = await _generate_next_card()
        _card_buffer.append(card)
        # LLM generation continue en background
        # Timeout 360s (CPU-only Qwen 3B: ~120s Strategy B + 120s Strategy C)

func _draw_next_card() -> Dictionary:
    if _card_buffer.is_empty():
        push_warning("Card buffer empty - stalling for LLM")
        # Attend que la première carte soit générée
        await get_tree().process_frame

    var card = _card_buffer.pop_front()
    _process_card_buffer()  # Recharge async
    return card
```

### Gestion du LLM

```gdscript
func _generate_next_card() -> Dictionary:
    if not merlin_ai:
        return _fallback_card()

    var context = _build_rag_context()
    var prompt = _build_generation_prompt(context)

    try:
        var response = await merlin_ai.generate(prompt, LLM_TIMEOUT_SEC)
        var card = _parse_card_json(response)
        return card if card else _fallback_card()
    except TimeoutError:
        push_error("LLM timeout after 360s")
        return _fallback_card()
    except ParseError:
        push_error("Invalid LLM response JSON")
        return _fallback_card()
```

### Intégration tutorial

Les tutoriels sont contextuels et dégagés après lecture :

```gdscript
func _check_tutorial(trigger: String) -> void:
    if _tutorial_shown.has(trigger):
        return  # Déjà montré

    var tutorial = _tutorial_data.get(trigger)
    if not tutorial:
        return  # Pas de tutoriel pour ce trigger

    ui.show_tutorial_overlay(tutorial)
    _tutorial_shown[trigger] = true
```

---

## Système de cartes UI

### Architecture compositor

Les cartes Merlin utilisent une composition procédurale multi-couches :

```
CardSceneCompositor (v2.0 — actif)
    ├─ Composition 4 couches (parallax)
    │  ├─ SKY (parallax 0.3)
    │  ├─ TERRAIN (parallax 0.6)
    │  ├─ SUBJECT (parallax 1.0 — sans parallax)
    │  └─ ATMOSPHERE (parallax 0.1 — subtle)
    │
    ├─ Sélection dynamique par biome + season + period + weather
    ├─ Shaders procéduraux (ciel, silhouette)
    └─ Animations idle (sway, breathe, drift)

OU

PixelSceneCompositor (v1.0 — fallback)
    ├─ Composition 4 couches (non-parallax)
    │  ├─ Background (procedural via PixelSceneData)
    │  ├─ Props (2-3 placements aléatoires)
    │  ├─ Creature (0-1)
    │  └─ Weather overlay
    │
    ├─ Grille 48×48 pixels
    ├─ Tintage par biome + season
    └─ Animation d'assemblage pixel-par-pixel
```

### Flux d'affichage d'une carte

```gdscript
# 1. Controller tire une carte du buffer
var card = _draw_next_card()

# 2. UI prépare l'affichage
ui.prepare_card(card)

# 3. Compositor sélectionne les couches
var tags = card.get("visual_tags", [])
var biome = store.current_biome
var season = store.current_season
ui.card_compositor.compose_layers(tags, biome, season)

# 4. Texture generation + animation reveal
ui.card_compositor.build_scene()  # Construit les nœuds
ui.show_card_with_animation()     # Fade in + parallax

# 5. Options affichées avec verbes aléatoires
ui.display_options(card.get("options", []))

# 6. Joueur clique → option_chosen.emit(option_index)
```

### Sélection des couches visuelles

La sélection est déterministe basée sur `visual_tags` et `biome` :

```gdscript
func _select_layers_for_card(tags: Array, biome: String, season: String, period: String) -> Array[CardLayer]:
    var layers: Array[CardLayer] = []

    # SKY layer (shader procédural ou texture)
    if "night" in tags:
        layers.append(CardLayer.create_shader(SKY, 0.3, _night_sky_shader))
    else:
        layers.append(CardLayer.create_texture(SKY, 0.3, "res://assets/card_skies/broceliande_day.png"))

    # TERRAIN layer (tintage biome)
    var terrain_texture = _select_terrain_for_biome(biome)
    layers.append(CardLayer.create_texture(TERRAIN, 0.6, terrain_texture))

    # SUBJECT layer (creature/PNJ — SpriteFactory)
    var subject_texture = _generate_subject_texture(tags, biome)
    layers.append(CardLayer.create_texture(SUBJECT, 1.0, subject_texture))

    # ATMOSPHERE layer (fog, mist, particles)
    if "misty" in tags:
        layers.append(CardLayer.create_texture(ATMOSPHERE, 0.1, "res://assets/atmosphere/mist.png"))

    return layers
```

### Tintage et variables contextuelles

Chaque couche accepte des variables shader pour la variation dynamique :

```gdscript
shader_type canvas_item;

uniform vec3 biome_tint : hint_color = vec3(1.0);
uniform float season_saturation : hint_range(0.0, 2.0) = 1.0;
uniform float period_brightness : hint_range(0.0, 2.0) = 1.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // Tintage biome
    tex.rgb *= biome_tint;

    // Saturation season
    float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    tex.rgb = mix(vec3(gray), tex.rgb, season_saturation);

    // Brightness period (jour/nuit)
    tex.rgb *= period_brightness;

    COLOR = tex;
}
```

### Verbes d'action (options)

Les 3 options des cartes reçoivent des verbes aléatoires de la liste ACTION_VERBS :

```gdscript
const ACTION_VERBS := [
    "Explorer", "Fuir", "Negocier", "Observer", "Defier", "Invoquer",
    "Traverser", "Accepter", "Refuser", "Proteger", "Attaquer", "Apaiser",
    "Chercher", "Ecouter", "Suivre", "Braver", "Canaliser", "Mediter",
    "Soigner", "Sacrifier", "Marchander", "Implorer", "Confronter",
    "Esquiver", "Sonder", "Conjurer", "Purifier", "Resister",
    "Avancer", "Agir", "Reculer", "Parler", "Ignorer", "Prendre",
    "Toucher", "Ouvrir", "Courir", "Attendre", "Prier", "Ramasser",
    "Contourner", "Plonger", "Grimper", "Frapper", "Appeler",
]

func _get_three_unique_verbs() -> Array[String]:
    var shuffled = ACTION_VERBS.duplicate()
    shuffled.shuffle()
    return [shuffled[0], shuffled[1], shuffled[2]]
```

---

## Système HUD

### WalkHUD (Affichage 3D minimal)

Overlay CanvasLayer affichée pendant la marche en 3D. Conception minimaliste CRT phosphor.

**Localisation** : `scripts/ui/walk_hud.gd`

**Composition** :

```
┌────────────────────────────────────────┐
│ PV 87/100    Souffle: * * o o o o o   │  ← Top-left
│                                        │
│                                        │  ← Zone centrale (3D viewport)
│                                        │
│ Zone: Jour   Essences: ~ 3            │  ← Bottom-left
└────────────────────────────────────────┘
```

**Élements** :

1. **PV Bar** (ProgressBar)
   - Barre verte (phosphor) → rouge (danger) si <25%
   - Couleur moyenne (amber) si 25-50%
   - Texte : "PV {current}/{max}"

2. **Souffle Icons** (HBoxContainer)
   - Icônes visuelles `*` (filled) / `o` (empty)
   - Max 7 souffles affichés
   - Layout horizontal

3. **Zone Label** (Label)
   - Affiche la période actuelle : "Aube", "Jour", "Soir", "Nuit"
   - Couleur varie selon la période

4. **Essences Counter** (Label)
   - Symbole `~` + nombre
   - Mises à jour en temps réel

**Signaux reçus** :

```gdscript
# De Run3DController
func update_pv(current: int, max_pv: int) -> void
func update_souffle(current: int) -> void
func update_essences(count: int) -> void
func update_period(period: String) -> void  # "aube"|"jour"|"soir"|"nuit"
```

**Color Mapping** :

```gdscript
# PV colors
ratio > 0.50  → phosphor (vert)
ratio 0.25-0.50 → warning (amber)
ratio < 0.25  → danger (rouge)

# Period colors
"aube"  → cyan_dim
"jour"  → phosphor_bright
"soir"  → amber
"nuit"  → cyan
```

### ReputationHUD (Affichage factions)

Simple affichage texte des 5 réputations de faction.

**Localisation** : `scripts/ui/reputation_hud.gd`

**Composition** :

```
Druides: 45
Anciens: 32
Korrigans: 78
Niamh: 12
Ankou: 56
```

**Signaux reçus** :

```gdscript
signal reputation_changed(faction: String, value: float, delta: float)
```

**Mise à jour** :

```gdscript
func _on_reputation_changed(faction: String, value: float, _delta: float) -> void:
    if _faction_labels.has(faction):
        _faction_labels[faction].text = faction.capitalize() + ": " + str(int(value))
```

### HudController (Hérité — À déprécier)

Ancienne interface pour HUD 3D walk. Supersédée par WalkHUD. À supprimer.

---

## Écrans de transition

### MerlinGameUI (Gameplay principal)

Interface complète du jeu en 2D, divisée en 3 zones.

**Localisation** : `scripts/ui/merlin_game_ui.gd` + `scenes/MerlinGameUI.tscn`

**Ratio zones** (DOC_17 UX) :

```
TOP_ZONE_RATIO: 0.12    (Barres vie/souffle/factions)
CARD_ZONE_RATIO: 0.70   (Illustration + 3 options)
BOTTOM_ZONE_RATIO: 0.18 (Feedback texte, contrôles)
```

**Nœuds principaux** :

```
MerlinGameUI (Control)
├─ MainVBox (VBoxContainer)
│  ├─ TopStatusBar (HBoxContainer)
│  │  ├─ LifePanel
│  │  │  ├─ LifeBar (ProgressBar)
│  │  │  └─ LifeCounter (Label)
│  │  ├─ SoufflePanel
│  │  │  ├─ SouffleIcons (HBoxContainer)
│  │  │  └─ SouffleCounter (Label)
│  │  └─ FactionsPanel (HBoxContainer)
│  │     └─ [5× Faction labels]
│  │
│  ├─ CardZone (CenterContainer)
│  │  └─ CardSceneCompositor (dynamique)
│  │     └─ [4 couches parallax + layers]
│  │
│  └─ BottomZone (VBoxContainer)
│     ├─ FeedbackLabel (RichTextLabel)
│     ├─ OptionsPanel (HBoxContainer)
│     │  ├─ LeftButton (Button) [Verbe A]
│     │  ├─ CenterButton (Button) [Verbe B]
│     │  └─ RightButton (Button) [Verbe C]
│     └─ ControlsHint (Label)
```

**Signaux émis** :

```gdscript
signal option_chosen(option: int)                # 0/1/2
signal skill_activated(skill_id: String)         # Ogham ID
signal pause_requested
signal souffle_activated
signal merlin_dialogue_requested(player_input: String)
signal journal_requested
```

**États d'animation** :

1. **Reveal** — Carte fade-in + parallax initial
2. **Idle** — Pulsation légère, mouvement atmosphérique
3. **Selection** — Bouton hover → surlignage
4. **Transition** — Fade-out vers carte suivante

### EndRunScreen (Post-run modal)

Écran de résumé fin de run avec 3-4 screens progresses.

**Localisation** : `scripts/ui/end_run_screen.gd`

**Progression** :

```
Screen 0: NARRATIVE
  ├─ Texte ending (LLM ou fallback)
  ├─ Affichage ~5s
  └─ "CONTINUER" (bouton ou auto-advance)
     ↓
Screen 1: JOURNEY MAP
  ├─ Timeline des événements joués
  ├─ Icônes cartes
  └─ Stats locales (cartes, choix critiques)
     ↓
Screen 2: REWARDS
  ├─ Anam gagné
  ├─ Réputations factions changées
  ├─ Bois/Artefacts/Unlocks
  └─ "CONTINUER"
     ↓
Screen 3: FACTION CHOICE (optionnel)
  └─ Si 2+ factions >= 80 rep
     ├─ Afficher 2-5 factions
     └─ Choix permanent (alliance run)
```

**Signaux** :

```gdscript
signal screen_completed(screen_name: String)
signal return_to_hub()
signal faction_chosen(faction: String)
```

### LLM Warmup Overlay

Écran d'attente lors du préchauffage LLM (Ollama/Qwen 3.5).

**Localisation** : `scripts/ui/llm_warmup_overlay.gd`

**Affichage** :

```
Merlin se prepare...
[████████░░] 82%

(Message poétique / intro speech)
```

---

## Visuels et constantes

### MerlinVisual (Singleton autoload)

**Source unique de vérité pour TOUS les visuels.**

**Localisation** : `scripts/autoload/merlin_visual.gd`

**Principes** :

- **Immutabilité** : Les constantes ne changent jamais en runtime
- **Centralisation** : Aucune couleur ne doit être hardcodée (utiliser les clés)
- **Organisation** : Palettes séparées (CRT_PALETTE, PALETTE legacy, biome palettes)

### CRT_PALETTE (Actif)

Palette CRT terminal druido-tech (couleurs phosphor, amber, cyan).

```gdscript
const CRT_PALETTE := {
    # Backgrounds
    "bg_deep":        Color(0.02, 0.04, 0.02),      # Noir très foncé (green tint)
    "bg_dark":        Color(0.04, 0.08, 0.04),
    "bg_panel":       Color(0.06, 0.12, 0.06),
    "bg_highlight":   Color(0.08, 0.16, 0.08),

    # Phosphor primaire (vert terminal)
    "phosphor":       Color(0.20, 1.00, 0.40),      # Vert principal
    "phosphor_dim":   Color(0.12, 0.60, 0.24),      # Sombre
    "phosphor_bright": Color(0.40, 1.00, 0.60),     # Brillant
    "phosphor_glow":  Color(0.20, 1.00, 0.40, 0.15), # Avec alpha glow

    # Amber secondaire (terminal classique)
    "amber":          Color(1.00, 0.75, 0.20),
    "amber_dim":      Color(0.60, 0.45, 0.12),
    "amber_bright":   Color(1.00, 0.85, 0.40),

    # Cyan tertaire (magie mystique)
    "cyan":           Color(0.30, 0.85, 0.80),
    "cyan_bright":    Color(0.50, 1.00, 0.95),
    "cyan_dim":       Color(0.15, 0.42, 0.40),

    # Status
    "danger":         Color(1.00, 0.20, 0.15),      # Rouge critique
    "success":        Color(0.20, 1.00, 0.40),      # Vert succès
    "warning":        Color(1.00, 0.75, 0.20),      # Amber warning
    "inactive":       Color(0.20, 0.25, 0.20),      # Gris

    # Structuraux
    "border":         Color(0.12, 0.30, 0.14),
    "border_bright":  Color(0.20, 0.50, 0.24),
    "shadow":         Color(0.00, 0.00, 0.00, 0.40),
    "scanline":       Color(0.00, 0.00, 0.00, 0.15), # Effet scanlines CRT
}
```

### Biome CRT Palettes

Palette 8 couleurs stricte par biome pour la cohérence visuelle.

```gdscript
const BIOME_CRT_PALETTES := {
    "foret_broceliande": {
        "primary":   Color(0.20, 1.00, 0.40),     # Vert forêt
        "secondary": Color(0.15, 0.75, 0.30),
        "accent":    Color(0.30, 0.85, 0.80),     # Cyan mystique
        "tint_dark": Color(0.06, 0.12, 0.06),
        # ... etc
    },
    "marais_korrigans": {
        "primary":   Color(0.30, 0.85, 0.80),     # Cyan marais
        "secondary": Color(0.20, 0.65, 0.65),
        "accent":    Color(1.00, 0.75, 0.20),     # Amber
        "tint_dark": Color(0.04, 0.08, 0.08),
        # ... etc
    },
    # ... autres biomes
}
```

### Fonts et tailles

```gdscript
const FONT_NAME := "VT323"              # Monospace terminal
const FONT_SIZE_HUD := 14
const FONT_SIZE_CARD := 16
const FONT_SIZE_UI := 12
const FONT_SIZE_TITLE := 24
const FONT_SIZE_BODY := 10
```

### Constantes animation

```gdscript
const CARD_FLOAT_OFFSET := 12.0         # Pixels
const CARD_FLOAT_DURATION := 2.0        # Secondes
const FADE_DURATION := 0.5
const PARALLAX_SPEED := 0.3             # Ratio du mouvement souris
const SCANLINE_SPEED := 0.5             # Hz scanlines pulsation
```

### Usage pattern

```gdscript
# CORRECT — utiliser MerlinVisual
var c: Color = MerlinVisual.CRT_PALETTE["phosphor"]
label.add_theme_color_override("font_color", c)

# FAUX — hardcoder
label.add_theme_color_override("font_color", Color(0.20, 1.00, 0.40))

# CORRECT — type explicite
var c: Color = MerlinVisual.CRT_PALETTE["danger"]

# FAUX — sans type (:= deduit par Godot)
var c := MerlinVisual.CRT_PALETTE["danger"]  # Risque de confusion
```

---

## Patterns et bonnes pratiques

### 1. Store-UI Bridge Pattern

**Règle** : L'UI écoute le Store via signaux, JAMAIS n'appelle Store.set_*() directement.

```gdscript
# ✅ CORRECT
func _ready() -> void:
    store = get_node_or_null("/root/MerlinStore")
    if store:
        store.life_changed.connect(_on_life_changed)
        store.reputation_changed.connect(_on_reputation_changed)

func _on_life_changed(current: int, max_pv: int) -> void:
    _life_bar.value = current  # Mise à jour passive

# ❌ FAUX
func _on_option_chosen(option: int) -> void:
    store.set_life(store.life - 10)  # Modifie le Store directement
```

### 2. Immutabilité visuelle

Les constantes visuelles ne changent jamais. Les variations passent par le contexte (biome, season, period).

```gdscript
# ✅ CORRECT — variation via contexte
var tint = _get_biome_tint(current_biome)
shader_material.set_shader_parameter("biome_tint", tint)

# ❌ FAUX — mutation globale
MerlinVisual.CRT_PALETTE["phosphor"] = Color.RED  # Ne faire jamais!
```

### 3. Composition procédurale

Les éléments complexes (cartes, portraits) sont assemblés dynamiquement, pas pré-créés.

```gdscript
# ✅ CORRECT — compositor crée les nœuds
var compositor = CardSceneCompositor.new()
compositor.setup(Vector2(440, 220))
compositor.compose_layers(visual_tags, biome, season)
compositor.build_scene()  # Assemble les nœuds

# ❌ FAUX — instancier une scène statique
var card_scene = load("res://scenes/Card.tscn")
var card = card_scene.instantiate()  # Limité à une layout fixe
```

### 4. Gestion des erreurs UI

Les erreurs UI ne doivent jamais bloquer le gameplay. Fallback gracieux.

```gdscript
# ✅ CORRECT — fallback si LLM échoue
func _generate_next_card() -> Dictionary:
    if merlin_ai:
        var card = await _call_llm()
        if card:
            return card
    return _fallback_card()  # Toujours une carte valide

# ❌ FAUX — crash si LLM indisponible
var card = await merlin_ai.generate(prompt)  # Peut lever exception
return card
```

### 5. Organisation du code UI

- **Fichier par composant** : Chaque UI script = 1 responsabilité
- **Taille cible** : 200-400 lignes par script (max 800)
- **Préloads explicites** : Les classes utilisées en runtime sont préchargées en haut

```gdscript
# En haut du script
const CardSceneCompositor = preload("res://scripts/ui/card_scene_compositor.gd")
const PixelSceneData = preload("res://scripts/ui/pixel_scene_data.gd")

# UID cache peut être stale si le script est créé en runtime
# Donc: précharger explicitement plutôt que rely on UID
```

### 6. Signal naming convention

```gdscript
# Émis PAR ce composant (sortie)
signal option_chosen(option: int)
signal card_revealed
signal hud_updated

# Reçu DEPUIS d'autres composants (entrée)
func _on_store_life_changed(current: int, max_pv: int) -> void:
    # Préfixe _on_ = handler, pas une API publique
```

### 7. Éviter le flickering CRT

Le CRT_PALETTE utilise des alpha subtils et des scanlines pour le flicker contrôlé.

```gdscript
# ✅ CORRECT — utiliser palette scanline
modulate = MerlinVisual.CRT_PALETTE["scanline"]  # Alpha 0.15

# ❌ FAUX — créer flicker manuel
modulate.a = randf() * 0.5  # Aléatoire non-contrôlé
```

### 8. Tailles d'écran et responsivité

Utiliser des ratios plutôt que des pixels fixes.

```gdscript
# ✅ CORRECT
var card_height = get_viewport_rect().size.y * CARD_ZONE_RATIO
var card_compositor = CardSceneCompositor.new()
card_compositor.setup(Vector2(card_height * 2, card_height))

# ❌ FAUX
var card_compositor = CardSceneCompositor.new()
card_compositor.setup(Vector2(440, 220))  # Hardcoded
```

### 9. Cache et performance

Les éléments procéduraux coûteux (textures SpriteFactory) sont cachés et réutilisés.

```gdscript
# Exemple : Cache SpriteFactory
class SpriteCache:
    var _cache: Dictionary = {}

    func get_sprite(key: String) -> ImageTexture:
        if _cache.has(key):
            return _cache[key]

        var texture = _generate_expensive_texture(key)
        _cache[key] = texture
        return texture
```

### 10. Debugging visuel

Laisser les print/debug comments en code — utiles pour les problèmes visuels.

```gdscript
print("[CardCompositor] compose_layers: tags=%s biome=%s" % [
    str(visual_tags), biome])
print("[WalkHUD] update_pv: %d/%d (ratio=%.2f)" % [current, max_pv, ratio])
```

---

## Checklist de validation UI

Avant de commiter du code UI :

- [ ] Toutes les couleurs utilisent `MerlinVisual.CRT_PALETTE` (pas de hardcode)
- [ ] Les types de variables sont explicites (pas de `:=` sur const visuelles)
- [ ] L'UI écoute le Store, ne le modifie pas (signaux unidirectionnels)
- [ ] Pas de `await` bloquants dans _ready() (async en background)
- [ ] Fallback gracieux si LLM/ressources indisponibles
- [ ] `validate.bat` passe (Step 0 minimum)
- [ ] Pas de mutation en place (immutabilité)
- [ ] Responsivité écran testée (ratios, pas pixels)
- [ ] Pas de print/warnings non-justifiés (sauf debug temporaire)
- [ ] Commentaires expliquent le "pourquoi", pas le "quoi"

---

## Références croisées

| Document | Contenu |
|----------|---------|
| `GAME_DESIGN_BIBLE.md` (v2.4) | Game loop, systèmes core, factions |
| `DEV_PLAN_V2.5.md` | Phases dev, acceptance criteria |
| `LLM_ARCHITECTURE.md` | Multi-Brain, LoRA, génération cartes |
| `UI_UX_BIBLE.md` (70_graphic/) | Design visual, grille responsive |
| `CLAUDE.md` (v3.3) | Workflow dev, validation |

---

## Conclusion

La couche UI Merlin est conçue pour la **cohérence**, la **maintenabilité** et la **performance**. L'architecture découplée store-controller-ui permet d'itérer rapidement sans effet de bord. Les patterns procéduraux (SpriteFactory, Compositor) offrent la flexibilité pour varier visuellement sans pénalité de mémoire.

**Clés du succès** :
1. Respecter le Store-UI bridge (signaux unidirectionnels)
2. Centraliser les constantes visuelles (MerlinVisual)
3. Composer, ne pas hardcoder (procédural over static)
4. Fallback gracieux (jamais de crash)
5. Valider avant de commit (validate.bat + agents)
