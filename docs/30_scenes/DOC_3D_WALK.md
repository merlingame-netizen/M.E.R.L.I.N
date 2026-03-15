# Système de Marche 3D : Architecture Broceliande

**Dernière mise à jour** : 2026-03-15
**Version** : 3.0
**Phase** : Phase 6-7 (Run loop, card/minigame pauses)

## Vue d'ensemble

Le système de marche 3D du jeu offre une expérience contemplative en première personne à travers une forêt procédurale (Forêt de Broceliande et variantes biomes). La marche est un *rail* permanent : le joueur avance automatiquement sur un sentier, la caméra passe sur des cartes (2D) et des minigames, puis retour à la marche.

**Core loop** :
```
[Marche 3D] → [Drain -1 PV] → [Carte 2D (3 options)] → [Minigame overlay]
→ [Score] → [Effets appliqués] → [Retour marche] → ...
```

**Acteurs principaux** :
- `Run3DController` — Orchestration du run, timers de cartes, pauses
- `BroceliandeForest3D` — Scène 3D principale, caméra, input
- `BrocChunkManager` — Terrain procédural par chunks MultiMesh
- `BrocAtmosphere` — Fog, particules volumétriques, cycles
- `WalkEventController` — Événements dynamiques (LLM ou fallback)
- `BiomeWalkConfig` — Ressource de configuration biome

---

## 1. Chunk Manager — Terrain Procédural

### Vue d'ensemble

`BrocChunkManager` génère le terrain en avant du joueur par **chunks de 30×30 unités** (axe Z), organisés en zones biome-spécifiques. Chaque chunk contient :
- **Arbres** (grands, petits) via MultiMesh
- **Buissons** via MultiMesh
- **Détails** (herbes, roches, champignons, fougères, etc.) via MultiMesh
- **Tapis d'herbe** (quad billboard en herbe procédurale)

**Objectif** : Densité x10 vs v1, 1 appel de dessin par type de maille par chunk, culling fog-of-war.

### Configuration

```gdscript
const CHUNK_SIZE_Z: float = 30.0
const CHUNK_SIZE_X: float = 30.0
const CHUNKS_AHEAD: int = 3      # Chunks en avant du joueur
const CHUNKS_BEHIND: int = 1      # Chunks en arrière
const UNLOAD_BEHIND: int = 2      # Seuil de déchargement
const BUILD_PER_FRAME: int = 4    # Opérations finalize/frame (limité)

# Ranges de visibilité (fog-of-war culling)
const VIS_RANGE_TREE: float = 12.0
const VIS_RANGE_BUSH: float = 10.0
const VIS_RANGE_DETAIL: float = 8.0
const VIS_RANGE_GRASS: float = 8.0
```

### Densité par Zone

Chaque zone (Z0=Lisière, Z1=Dense, ..., Z6=Cercle) a un profil de densité :

```gdscript
const ZONE_DENSITY: Array[Array] = [
    [40, 20, 35, 120, 0.0],     # Z0 Lisiere — open but lush
    [80, 35, 55, 200, 0.005],   # Z1 Dense — closing canopy
    [50, 20, 40, 160, 0.008],   # Z2 Dolmen — clearing + surround
    [55, 28, 50, 220, 0.015],   # Z3 Mare — wet, lush undergrowth
    [120, 55, 70, 300, 0.02],   # Z4 Profonde — maximum density
    [65, 28, 50, 170, 0.01],    # Z5 Fontaine — filtered light
    [65, 35, 55, 160, 0.008],   # Z6 Cercle — moderate
]
# Format : [arbres, petits_arbres, buissons, détails, fog_add_density]
```

### Détails (Distribution)

Les détails utilisent un roll cumulatif :

```gdscript
const DETAIL_ROLLS: Array[Array] = [
    [0.25, "grass_short"],
    [0.42, "fern"],
    [0.55, "grass_tall"],
    [0.65, "mushroom_red"],
    [0.74, "rock_small"],
    [0.82, "daisy"],
    [0.90, "mushroom_group"],
    [1.00, "rock_medium"],
]
```

### Lifecycle des Chunks

```
ChunkState.UNLOADED → ChunkState.QUEUED → ChunkState.BUILDING → ChunkState.ACTIVE
                                           ↓
                                    (frame-budgeted)
```

**Seed déterministe** : `hash(Vector2i(chunk_index, global_seed))` → Reproducibilité

**Offset sentier** : Détails à proximité du sentier (< 2m) sont décalés de 2.5m latéralement.

### Methods clés

```gdscript
func setup(...) -> void           # Initialise le pool de mailles
func generate_initial(player_z)   # Génère 2 chunks au démarrage
func update(player_pos)           # Appel chaque frame (gère chunks ahead/behind)
func set_density_mult(mult)       # Override LLM (0.1-3.0)
```

---

## 2. Atmosphere — Fog, Jour/Nuit, Saisons

### BrocAtmosphere (Brouillard volumétrique)

**Classe** : `BrocAtmosphere` (RefCounted)

Gère le brouillard procédural par zone, avec overrides LLM temporaires.

```gdscript
const ZONE_FOG: Array[float] = [
    0.020,  # Z0 Lisiere
    0.035,  # Z1 Dense
    0.015,  # Z2 Dolmen
    0.045,  # Z3 Mare
    0.080,  # Z4 Profonde (opaque à 4m)
    0.015,  # Z5 Fontaine
    0.015,  # Z6 Cercle
]

var _current_fog_target: float = 0.025
var _current_fog: float = 0.025
var _fog_lerp_speed: float = 0.5  # Atteint cible en ~2s
```

**Composants visuels** :
- **Fog planes** (3 hauteurs par zone, drift vertical sinusoïdal)
- **Mist curtains** (entre zones, drift horizontal)
- **God rays** (zones clearings, respiration alpha)

**Override LLM** :
```gdscript
func set_fog_override(density: float, duration: float) -> void
    # Ex: dense mist(0.08, 3.0) pendant 3 secondes
```

### BrocDayNight (Cycle jour/nuit)

**Classe** : `BrocDayNight` (RefCounted)

Cycle de 5 minutes (configurable) ou temps réel système.

```
t=0.0 → dawn(6h)
t=0.25 → noon(12h)
t=0.5 → dusk(18h)
t=0.75 → midnight(0h)
```

**Interpolation par étape** :

```gdscript
const SUN_COLORS: Array[Color] = [
    Color(1.0, 0.55, 0.25),   # dawn — warm orange
    Color(0.85, 0.80, 0.60),  # noon — white-yellow
    Color(0.90, 0.35, 0.18),  # dusk — deep red-orange
    Color(0.08, 0.10, 0.22),  # midnight — dark blue
]

const SUN_ENERGY_STOPS: Array[float] = [0.6, 1.5, 0.5, 0.05]
const SUN_PITCH_STOPS: Array[float] = [-15.0, -75.0, -165.0, -195.0]
```

**Fog density** : Base 0.025 + boost dawn/dusk (0.015 max) = fog plus épais à l'aube/crépuscule.

```gdscript
func get_is_night() -> bool:
    return _time > 0.6 or _time < 0.1  # Après 19h ou avant 7h
```

### BrocSeason (Saisons)

**Classe** : `BrocSeason` (RefCounted)

Teintes saisonnières appliquées à la végétation et shader overlay.

```gdscript
const VEGETATION_TINTS: Array[Color] = [
    Color(0.65, 0.90, 0.50),  # Spring — bright green
    Color(0.40, 0.70, 0.30),  # Summer — deep green
    Color(0.75, 0.50, 0.20),  # Autumn — orange-gold
    Color(0.55, 0.55, 0.52),  # Winter — desaturated grey
]

const PARTICLE_COLORS: Array[Color] = [
    Color(1.0, 0.85, 0.90, 0.7),   # Spring — pink petals
    Color(1.0, 1.0, 0.8, 0.3),     # Summer — heat shimmer
    Color(0.85, 0.55, 0.15, 0.8),  # Autumn — orange leaves
    Color(0.95, 0.97, 1.0, 0.9),   # Winter — white snow
]
```

**Shader** : `seasonal_particles.gdshader` (overlay ColorRect en CanvasLayer 5)

---

## 3. Creature Spawner — Créatures Pixel-Art

**Classe** : `BrocCreatureSpawner` (RefCounted)

4 types de créatures en pixel-art (BoxMesh rigs, technique Merlin).

### Types

| Type | Zones | Apparence | Règles |
|------|-------|-----------|--------|
| **Korrigan** | Z1, Z3 | 8×8 grid, vert vif + peau | Neutre |
| **Mist Wolf** | Z4 | 10×8 grid, gris pâle | Neutre |
| **White Deer** | Z2, Z5 | 9×8 grid, blanc + bois | Neutre |
| **Giant Raven** | Partout (nuit) | 8×7 grid, noir + oeil gris | Nuit uniquement |

### Configurations

```gdscript
const MAX_CREATURES: int = 2          # Max simultanés
const FLEE_DIST: float = 3.0          # Distance avant fuite
const SPAWN_DIST_MIN: float = 5.0
const SPAWN_DIST_MAX: float = 7.0
const DESPAWN_DIST: float = 12.0
const FADE_SPEED: float = 2.0         # Alpha/s
const SPAWN_COOLDOWN: float = 15.0    # Entre spawns
```

### States

```
"spawning" → (alpha fade-in) → "idle" → (sway) → [fleeing] → (fade-out, despawn)
            si joueur proche        si > FLEE_DIST
```

**Idle behavior** : Gentle sway sin-based (+ base_y).

---

## 4. Walk Events — Événements Dynamiques

### WalkEventController (LLM bridge)

**Classe** : `WalkEventController` (RefCounted)

Déclenche événements narratifs lors de la marche avec prefetch LLM.

**Triggers** :
1. **Timer** (45-90s aléatoire)
2. **Zone change** (passage entre zones)
3. **POI** (Point of Interest, manuel)

**Buffer prefetch** : Taille 2 (génère en arrière-plan via LLM)

```gdscript
const EVENT_INTERVAL_MIN: float = 45.0
const EVENT_INTERVAL_MAX: float = 90.0
const COOLDOWN_MIN: float = 20.0
const PREFETCH_BUFFER_SIZE: int = 2
const ZONE_TRIGGER_COOLDOWN: float = 10.0
```

### Fallback Events

Si LLM indisponible, 5 événements hardcodés (Broceliande-themed) :
1. Brouillard + silhouette au loin
2. Pierre gravée d'oghams
3. Korrigan surgit des racines
4. Cerf blanc traverse le sentier
5. Fontaine de Barenton bouillonne

### LLM Context

```gdscript
{
    "biome": run.get("biome", "foret_broceliande"),
    "day": run.get("day", 1),
    "season": run.get("season", "automne"),
    "tension": float(run.get("tension", 20)),
    "life_essence": int(run.get("life_essence", ...)),
    "cards_played": _cards_played,
    "story_log": _story_log,
    "tags": run.get("tags", []),
}
```

### Card → Event Conversion

```gdscript
func _card_to_event(card: Dictionary) -> Dictionary:
    # Extract text, labels (3), effects (array of arrays)
    return {
        "text": card.get("text", ""),
        "labels": labels,          # 3 options
        "effects": effects,        # Array[Array[String]] — effect codes
        "card_id": card.get("id", ""),
        "source": "llm",
    }
```

### Effect Application

Effets appliqués via `MerlinStore.effects.apply_effects()` :
```
ADD_REPUTATION:faction:amount
HEAL_LIFE:amount
DAMAGE_LIFE:amount
ADD_ANAM:amount
ADD_TENSION:amount
```

---

## 5. Events VFX et Narrative Director

### BrocEvents (Atmospheric events)

**Classe** : `BrocEvents` (RefCounted)

8 événements visuels aléatoires déclenches par timer ou zone change.

| Événement | Durée | Effet |
|-----------|-------|-------|
| Magic Breeze | 4s | OmniLight vert/jaune, mouvement |
| Giant Firefly | 3s | Sphère brillante + lumière, mouve Z→Z |
| Murmure Ancien | 2s | Message texte uniquement |
| Sunburst | 5s | Boost énergie solaire (sin pulse) |
| Thick Mist | 8s | Augmente fog density (sin pulse) |
| Mushroom Circle | 10s | 8 champignons rouges disposés cercle |
| Glowing Stone | 4s | OmniLight bleutée |
| Shadow | 2.5s | Boîte noire qui traverse |

### BrocNarrativeDirector (scene directives)

**Classe** : `BrocNarrativeDirector` (RefCounted)

Interprète les directives LLM pour déclencher VFX scène-complexes.

```gdscript
# LLM peut retourner dans event :
"scene_directive": {
    "type": "mist_fog",
    "intensity": 0.08,
    "duration": 3.0,
    "sound": "wind_howl",
}
```

---

## 6. Configurations Biome

### BiomeWalkConfig (Resource)

Ressource `.tres` définissant chaque biome.

```gdscript
@export var biome_key: String = "foret_broceliande"
@export var biome_name: String = "Foret de Broceliande"
@export var biome_subtitle: String = "Ou les arbres ont des yeux"

# Zones
@export var zone_count: int = 7
@export var zone_names: Array[String] = [
    "La Lisiere", "La Foret Dense", "Le Dolmen",
    "La Mare Enchantee", "La Foret Profonde",
    "La Fontaine de Barenton", "Le Cercle de Pierres",
]
@export var zone_spacing: float = 35.0  # Z-distance entre zone centers

# Atmosphere
@export var terrain_color: Color
@export var fog_color: Color
@export var fog_density: float
@export var ambient_color: Color
@export var ambient_energy: float
@export var sky_top_color: Color
@export var sky_bottom_color: Color
@export var favored_season: String  # "spring", "summer", etc.

# Assets (chemins GLB)
@export var tree_models: Array[String]
@export var bush_models: Array[String]
@export var detail_models: Dictionary  # "grass_short" → path, ...
@export var special_trees: Dictionary
@export var biome_assets: Dictionary

# Events
@export var event_interval: Vector2 = Vector2(45.0, 90.0)
@export var event_cooldown: float = 20.0

# VFX keywords
@export var vfx_keyword_overrides: Dictionary

# Gameplay
@export var aspect_bias: Dictionary = {"Corps": 1.0, "Ame": 1.0, "Monde": 1.0}
@export var difficulty: int = 0
```

**Usage** : `BroceliandeForest3D` charge la config biome et initialise tous les systèmes.

---

## 7. Run 3D Controller — Intégration Run Loop

**Classe** : `Run3DController` (Node)

Orchestration du run loop : marche → pause → carte → minigame → effets → pause levée.

### Lifecycle

```gdscript
func start_run(biome: String, ogham: String) -> void:
    # 1. Init run_state
    # 2. Spawn collectibles
    # 3. Start walk

func stop_run(reason: String) -> void:
    # Emit run_ended signal avec data
```

### Game Loop (called from _process)

```gdscript
func process_tick(delta: float) -> void:
    if not _is_running or _is_paused:
        return

    _walk_timer += delta

    # Update period (day_night)
    var new_period = MerlinStore.get_period(card_index)
    if new_period != current_period:
        period_changed.emit(new_period)

    # Time for a card?
    if _walk_timer >= _card_interval:
        _trigger_card()
```

### Card Trigger Pipeline

```
1. _is_paused = true
2. Drain -1 PV (DRAIN_PER_CARD = 1)
3. Check run end (life ≤ 0 → stop_run("death"))
4. Check convergence zone
5. Check promises expirations
6. Fade → card 2D
7. Generate card (LLM ou fallback)
8. Emit card_started signal
```

### Signals

```gdscript
signal life_changed(current, maximum)
signal currency_changed(amount)
signal ogham_updated(ogham_id, cooldown)
signal promises_updated(promises)
signal period_changed(period)
signal card_started(card)
signal card_ended()
signal run_ended(reason, data)
signal convergence_zone_entered(card_index)
```

### Constants

```gdscript
const WALK_SPEED: float = 3.0
const CARD_INTERVAL_MIN: float = 8.0
const CARD_INTERVAL_MAX: float = 14.0
const DRAIN_PER_CARD: int = MerlinConstants.LIFE_ESSENCE_DRAIN_PER_CARD
```

---

## 8. Scène principale : BroceliandeForest3D

**Classe** : `BroceliandeForest3D` (Node)

Orchestration globale de la scène 3D.

### Initialization

```gdscript
func _setup_biome(config: BiomeWalkConfig) -> void:
    # 1. Load GLB assets from config
    # 2. Setup camera rail
    # 3. Initialize chunk manager with pool
    # 4. Setup day/night, season, atmosphere
    # 5. Setup events controller
    # 6. Setup creature spawner
    # 7. Wire signals
```

### Update Pipeline (per frame)

```gdscript
func _process(delta: float) -> void:
    _autowalk.update(delta, _camera.global_position)  # Move camera forward
    _chunk_manager.update(_camera.global_position)     # Load/unload chunks
    _day_night.update(delta)                           # Update sun/fog
    _atmosphere.update(delta, _day_night.get_time())  # Volumetric updates
    _creatures.update(delta, _camera_pos, current_zone, _day_night.get_is_night())
    _events.update(delta, _camera_pos, current_zone, _narrative_director)
    _run_3d_controller.process_tick(delta)             # Card timer + state
```

### Input

```gdscript
const ACT_FWD: StringName = &"broc_move_forward"
const ACT_BACK: StringName = &"broc_move_back"
const ACT_LEFT: StringName = &"broc_move_left"
const ACT_RIGHT: StringName = &"broc_move_right"
const ACT_INTERACT: StringName = &"broc_interact"
```

Utilisés pour **override automatique walk** (broc_autowalk gère le mouvement forward, input override pour exploration locale).

---

## 9. Collectibles (Spawner)

**Classe** : `CollectibleSpawner` (RefCounted) — *dans ui_spawner.gd*

Spawne des pickups sur le sentier pendant la marche.

**Types** :
- `currency` — Monnaie biome
- `heal` — Récupération PV
- `anam_rare` — Essence rare

**Appels via Run3DController** :
```gdscript
func on_collectible_picked(type: String, amount: int) -> void:
    match type:
        "currency": currency += amount
        "heal": life = mini(life + amount, life_max)
        "anam_rare": anam_found += amount
```

---

## 10. Autowalking

**Classe** : `BrocAutowalk` (RefCounted)

Mouvement automatique du joueur le long du rail (camera forward).

```gdscript
const WALK_SPEED: float = 3.0

func update(delta: float, cam_pos: Vector3) -> void:
    # Avance la caméra selon path_points
    # Gère la rotation vers la prochaine cible
```

---

## 11. GrassWind et détails

**Classe** : `BrocGrassWind` (RefCounted)

Animations procédurales herbe/végétation fine.

Utilise **ShaderMaterial** avec dérive sinusoïdale.

---

## 12. Screen VFX

**Classe** : `BrocScreenVfx` (RefCounted)

VFX fullscreen (fade, blur, color grading) pour événements majeurs.

---

## 13. Inventaire des Scripts

| Script | Classe | Rôle | Dépendances |
|--------|--------|------|-------------|
| `broceliande_forest_3d.gd` | `BroceliandeForest3D` | Orchestration scène 3D principale | Tous les modules ci-dessous |
| `run_3d_controller.gd` | `Run3DController` | Run loop (timer cartes, pauses, effets) | MerlinStore, MerlinCardSystem, MerlinEffectEngine |
| `broc_chunk_manager.gd` | `BrocChunkManager` | Terrain procédural MultiMesh | BrocMultiMeshPool |
| `broc_multimesh_pool.gd` | `BrocMultiMeshPool` | Maille cache pour chunks | Aucune |
| `broc_atmosphere.gd` | `BrocAtmosphere` | Fog volumétrique, planes, god rays | Node3D (forest_root), Environment |
| `broc_day_night.gd` | `BrocDayNight` | Cycle jour/nuit, sun, colors | DirectionalLight3D, WorldEnvironment |
| `broc_season.gd` | `BrocSeason` | Tintes saisonnières, shader overlay | Node3D (forest_root) |
| `broc_creature_spawner.gd` | `BrocCreatureSpawner` | Créatures pixel-art | Node3D (forest_root) |
| `broc_events.gd` | `BrocEvents` | Événements atmosphériques (8 types) | Node3D, WorldEnvironment, DirectionalLight3D |
| `walk_event_controller.gd` | `WalkEventController` | Événements narratifs LLM/fallback | MerlinStore, WalkEventOverlay, WalkHUD, BrocEventVfx |
| `broc_event_vfx.gd` | `BrocEventVfx` | VFX keywords (brouillard, sons, particules) | Node3D |
| `broc_narrative_director.gd` | `BrocNarrativeDirector` | Scene directives LLM complexes | Node3D, BrocEventVfx |
| `broc_autowalk.gd` | `BrocAutowalk` | Marche automatique sur rail | PackedVector3Array (path_points) |
| `broc_grass_wind.gd` | `BrocGrassWind` | Animations herbe | ShaderMaterial |
| `broc_screen_vfx.gd` | `BrocScreenVfx` | VFX fullscreen (fade, blur, color) | CanvasLayer |
| `biome_walk_config.gd` | `BiomeWalkConfig` | Ressource configuration biome | Aucune |
| `walk_event_overlay.gd` | `WalkEventOverlay` | UI événements (CanvasLayer) | Node |
| `walk_hud.gd` | `WalkHUD` | HUD walk (PV, essences) | CanvasLayer |

---

## 14. Data Flow — Intégration avec Card/Run System

```
[BroceliandeForest3D._ready()]
    ↓
[Load BiomeWalkConfig resource]
    ↓
[Initialize all modules]
    ├─ BrocChunkManager.setup()
    ├─ BrocAtmosphere.setup()
    ├─ BrocDayNight.setup()
    ├─ BrocSeason.setup()
    ├─ BrocCreatureSpawner.setup()
    ├─ WalkEventController.setup()
    ├─ Run3DController.setup()
    └─ (connect signals)

[_process(delta) loop]
    ├─ BrocAutowalk.update()       → camera advances
    ├─ BrocChunkManager.update()   → chunks load/unload
    ├─ BrocDayNight.update()       → sun rotates, colors
    ├─ BrocAtmosphere.update()     → fog breathes
    ├─ BrocCreatureSpawner.update() → creatures spawn/flee
    ├─ BrocEvents.update()         → atmospheric events
    ├─ WalkEventController.update() → LLM prefetch + timer events
    ├─ CollectibleSpawner.update() → pickups appear
    └─ Run3DController.process_tick(delta)
        ├─ _walk_timer += delta
        ├─ Check _card_interval → _trigger_card()
        │   ├─ Pause = true
        │   ├─ Drain -1 PV
        │   ├─ Check run end
        │   ├─ Fade to card 2D
        │   ├─ Generate card (async)
        │   └─ Emit card_started
        └─ (awaiting card choice...)

[on_card_choice(option, score)]
    ├─ Resolve card
    ├─ Apply effects
    ├─ Update promises
    ├─ Fade back to 3D
    └─ _is_paused = false → resume walk
```

---

## 15. Extensibilité et Overrides

### LLM Overrides

- **Fog density** : `BrocAtmosphere.set_fog_override(density, duration)`
- **Chunk density** : `BrocChunkManager.set_density_mult(mult)` (0.1-3.0)
- **Day/night speed** : `BrocDayNight.set_duration(seconds)`
- **Event generation** : `WalkEventController._do_prefetch()` via MerlinLlmAdapter

### Biome Customization

Créer une nouvelle ressource `BiomeWalkConfig` :
1. Copy `res://resources/biomes/foret_broceliande.tres`
2. Modifier :
   - `zone_names`, `zone_count`, `zone_spacing`
   - `tree_models`, `bush_models`, `detail_models` (paths GLB)
   - `fog_color`, `ambient_color`, `sky_top_color`, `sky_bottom_color`
   - `vfx_keyword_overrides` (ajouter patterns custom)
   - `creature_types` et `zone_creatures` mapping

3. Charger dans `BroceliandeForest3D._setup_biome(config)`

### Asset Pipeline

GLB models sont chargés dynamiquement via `BrocMultiMeshPool` :
```gdscript
func register_scenes(prefix: String, scenes: Array[PackedScene]) -> void:
    # Ex: register_scenes("tree", [tree1.glb, tree2.glb])
    # → crée mesh keys "tree_0", "tree_1", ...
```

---

## 16. Optimisations et Limites

### Chunks

- **Frustum culling** : MultiMesh instances avec `visibility_range_end`
- **Build budget** : 4 finalize ops/frame (contrôle baguette lente) — réglable via `BUILD_PER_FRAME`
- **Seed déterministe** : Même run peut être rejoué à l'identique

### Creatures

- **Max 2 simultanés** — limite ressources, évite saturation écran
- **Despawn distance** : 12m — recycling rapide
- **Spawn cooldown** : 15s entre nouvelles créatures

### Events

- **Prefetch buffer** : 2 événements en arrière-plan (smooth transitions)
- **Fallback chain** : LLM → buffer → fallback hardcodés
- **Cooldown 20s** : Entre événements consécutifs

### Fog/Atmosphere

- **Fog planes** : Drift subtle (sin 0.2s period)
- **God rays** : Zones clearings uniquement (Z2, Z5, Z6)
- **Mist curtains** : Entre zone centers, drift X

---

## 17. Intégration UI/UX

### Walk HUD (`WalkHud`)

Affiche en overlay :
- Barre PV (rouge)
- Essences/Anam (bleu)
- Nom zone courant
- Icônes factions (mini reputations)

### Walk Event Overlay (`WalkEventOverlay`)

```
[EVENT TEXT (centered)]

[Option A] [Option B] [Option C]
```

Signaux :
- `choice_selected(option_index)` → WalkEventController._on_choice_selected()
- `overlay_closed()` → HUD refresh

### Transition Manager

Fade 3D ↔ Card 2D via `TransitionManager` :
```gdscript
await _transition.fade_to_card(1.0)   # Dim 3D, show card
await _transition.fade_to_3d(1.0)     # Restore 3D
```

---

## 18. Checklist Développement (pour extensions)

- [ ] Nouvel événement atmosphérique : Ajouter case dans `BrocEvents._trigger_random_event()` + `_get_event_duration()` + `_update_active_event()`
- [ ] Nouvelle créature : Ajouter grid dans `BrocCreatureSpawner.CREATURE_GRIDS` + zone mapping
- [ ] Nouvelle zone biome : Augmenter `BiomeWalkConfig.zone_count`, ajouter entrée `ZONE_DENSITY`, `ZONE_FOG`, `ZONE_CREATURES`, `zone_names`
- [ ] Override VFX keyword : `BiomeWalkConfig.vfx_keyword_overrides["custom_event"] = {"type": "..."}` → `BrocEventVfx` interprète
- [ ] Custom narrative directive : Ajouter handler dans `BrocNarrativeDirector.apply_directive(directive, player_pos)`

---

## 19. Références et Liens

- **Game Design Bible** : `docs/GAME_DESIGN_BIBLE.md` (v2.4, core loop, Factions, Oghams)
- **LLM Architecture** : `docs/LLM_ARCHITECTURE.md` (Qwen, LoRA, prompts)
- **Card System** : `docs/20_card_system/` (fallback, minigames)
- **Effects Engine** : `scripts/merlin/merlin_effect_engine.gd` (ADD_REPUTATION, HEAL_LIFE, etc.)
- **Validation** : `validate.bat` (GDScript parser, Godot headless checks)

---

**Auteur** : Claude Code
**Version doc** : 3.0
**Status** : Production-ready (Phase 6-7)
