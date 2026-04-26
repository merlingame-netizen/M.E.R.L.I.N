extends Node
## BroceliandeForest3D v3
## Marche contemplative FPS — Foret de Broceliande.
## 7 zones, assets GLB reels, effets volumetriques, cycle jour/nuit, saisons.

signal merlin_encounter_complete  # Emitted when Merlin found → ready for MerlinGame

const HUB_SCENE: String = "res://scenes/MerlinCabinHub.tscn"
const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"

# --- Helper modules ---
const BrocAutowalk = preload("res://scripts/broceliande_3d/broc_autowalk.gd")
const BrocAerialDescent = preload("res://scripts/broceliande_3d/broc_aerial_descent.gd")
const EncounterCardOverlayScript = preload("res://scripts/ui/encounter_card_overlay.gd")
const BrocDayNight = preload("res://scripts/broceliande_3d/broc_day_night.gd")
const BrocSeason = preload("res://scripts/broceliande_3d/broc_season.gd")
const BrocGrassWind = preload("res://scripts/broceliande_3d/broc_grass_wind.gd")
const BrocAtmosphere = preload("res://scripts/broceliande_3d/broc_atmosphere.gd")
const BrocParallaxLayers = preload("res://scripts/broceliande_3d/broc_parallax_layers.gd")
# Deprecated: BrocDenseFill, BrocExtraDecor, BrocMassFill — replaced by BrocChunkManager
const BrocChunkManager = preload("res://scripts/broceliande_3d/broc_chunk_manager.gd")
const BrocEvents = preload("res://scripts/broceliande_3d/broc_events.gd")
const BrocEventVfxClass = preload("res://scripts/broceliande_3d/broc_event_vfx.gd")
const WalkEventControllerClass = preload("res://scripts/broceliande_3d/walk_event_controller.gd")
const WalkEventOverlayClass = preload("res://scripts/ui/walk_event_overlay.gd")
const WalkHudClass = preload("res://scripts/ui/walk_hud.gd")
const BrocScreenVfxClass = preload("res://scripts/broceliande_3d/broc_screen_vfx.gd")
const BrocFaunaBubbleClass = preload("res://scripts/broceliande_3d/broc_fauna_bubble.gd")
const BrocCreatureSpawnerClass = preload("res://scripts/broceliande_3d/broc_creature_spawner.gd")
const BrocNarrativeDirectorClass = preload("res://scripts/broceliande_3d/broc_narrative_director.gd")
const MerlinWhisperClass = preload("res://scripts/ui/merlin_whisper.gd")
const ForestAssetSpawnerClass = preload("res://scripts/broceliande_3d/forest_asset_spawner.gd")
const ForestZoneBuilderClass = preload("res://scripts/broceliande_3d/forest_zone_builder.gd")
const ForestEffectsClass = preload("res://scripts/broceliande_3d/forest_effects.gd")
const ForestMerlinNpcClass = preload("res://scripts/broceliande_3d/forest_merlin_npc.gd")
const ForestTerrainBuilderClass = preload("res://scripts/broceliande_3d/forest_terrain_builder.gd")
const GlbAssetPlacerClass = preload("res://scripts/broceliande_3d/glb_asset_placer.gd")

# --- Input ---
const ACT_FWD: StringName = &"broc_move_forward"
const ACT_BACK: StringName = &"broc_move_back"
const ACT_LEFT: StringName = &"broc_move_left"
const ACT_RIGHT: StringName = &"broc_move_right"
const ACT_INTERACT: StringName = &"broc_interact"
const ACT_MOUSE: StringName = &"broc_toggle_mouse"

# --- GLB asset paths (BK art direction — real-world scale) ---
const BK_BASE: String = "res://Assets/bk_assets/"
const BK_BIOME: String = "foret_broceliande"

const TREE_MODELS: Array[String] = [
	BK_BASE + "vegetation/" + BK_BIOME + "/tree_bk_foret_broceliande_0000.glb",
	BK_BASE + "vegetation/" + BK_BIOME + "/tree_bk_foret_broceliande_0001.glb",
	BK_BASE + "vegetation/" + BK_BIOME + "/tree_bk_foret_broceliande_0002.glb",
	BK_BASE + "vegetation/" + BK_BIOME + "/tree_bk_foret_broceliande_0003.glb",
	BK_BASE + "vegetation/" + BK_BIOME + "/tree_bk_foret_broceliande_0004.glb",
	BK_BASE + "vegetation/" + BK_BIOME + "/tree_bk_foret_broceliande_0005.glb",
]

const SPECIAL_TREES: Dictionary = {
	"old_oak": BK_BASE + "vegetation/" + BK_BIOME + "/tree_bk_foret_broceliande_0000.glb",
	"golden": BK_BASE + "vegetation/" + BK_BIOME + "/tree_bk_foret_broceliande_0003.glb",
	"spiral": BK_BASE + "vegetation/" + BK_BIOME + "/tree_bk_foret_broceliande_0004.glb",
	"willow": BK_BASE + "vegetation/" + BK_BIOME + "/tree_bk_foret_broceliande_0002.glb",
	"silver": BK_BASE + "vegetation/" + BK_BIOME + "/tree_bk_foret_broceliande_0005.glb",
	"dead": BK_BASE + "vegetation/" + BK_BIOME + "/tree_bk_foret_broceliande_0001.glb",
}

const BUSH_MODELS: Array[String] = [
	BK_BASE + "bushes/" + BK_BIOME + "/bush_bk_foret_broceliande_0000.glb",
	BK_BASE + "bushes/" + BK_BIOME + "/bush_bk_foret_broceliande_0001.glb",
	BK_BASE + "bushes/" + BK_BIOME + "/bush_bk_foret_broceliande_0002.glb",
	BK_BASE + "bushes/" + BK_BIOME + "/bush_bk_foret_broceliande_0003.glb",
	BK_BASE + "bushes/" + BK_BIOME + "/bush_bk_foret_broceliande_0004.glb",
	BK_BASE + "bushes/" + BK_BIOME + "/bush_bk_foret_broceliande_0005.glb",
]

const DETAIL_MODELS: Dictionary = {
	"rock_small": BK_BASE + "rocks/" + BK_BIOME + "/rock_bk_foret_broceliande_0000.glb",
	"rock_medium": BK_BASE + "rocks/" + BK_BIOME + "/rock_bk_foret_broceliande_0001.glb",
	"rock_group": BK_BASE + "rocks/" + BK_BIOME + "/rock_bk_foret_broceliande_0004.glb",
	"lily_pink": BK_BASE + "collectibles/" + BK_BIOME + "/collectible_bk_foret_broceliande_0000.glb",
	"lily_white": BK_BASE + "collectibles/" + BK_BIOME + "/collectible_bk_foret_broceliande_0003.glb",
	"cattail": BK_BASE + "collectibles/" + BK_BIOME + "/collectible_bk_foret_broceliande_0005.glb",
}

# --- Broceliande 3D assets (BK art direction) ---
const BROC_ASSETS: Dictionary = {
	# Megaliths (3.5m real-world)
	"dolmen": BK_BASE + "megaliths/" + BK_BIOME + "/megalith_bk_foret_broceliande_0000.glb",
	"menhir_01": BK_BASE + "megaliths/" + BK_BIOME + "/megalith_bk_foret_broceliande_0001.glb",
	"menhir_02": BK_BASE + "megaliths/" + BK_BIOME + "/megalith_bk_foret_broceliande_0002.glb",
	"stone_circle": BK_BASE + "megaliths/" + BK_BIOME + "/megalith_bk_foret_broceliande_0003.glb",
	# Structures (3.2m real-world)
	"bridge_wood": BK_BASE + "props/" + BK_BIOME + "/bridge_bk_foret_broceliande_0000.glb",
	"root_arch": BK_BASE + "structures/" + BK_BIOME + "/structure_bk_foret_broceliande_0000.glb",
	"fairy_lantern": BK_BASE + "collectibles/" + BK_BIOME + "/collectible_bk_foret_broceliande_0001.glb",
	"druid_altar": BK_BASE + "structures/" + BK_BIOME + "/structure_bk_foret_broceliande_0003.glb",
	# POI
	"fountain_barenton": BK_BASE + "structures/" + BK_BIOME + "/structure_bk_foret_broceliande_0004.glb",
	"merlin_tomb": BK_BASE + "megaliths/" + BK_BIOME + "/megalith_bk_foret_broceliande_0004.glb",
	"merlin_oak": BK_BASE + "vegetation/" + BK_BIOME + "/tree_bk_foret_broceliande_0000.glb",
	# Creatures (0.7m real-world) — 0=korrigan, 1=doe, 2=wolf
	"korrigan": BK_BASE + "characters/" + BK_BIOME + "/creature_bk_foret_broceliande_0000.glb",
	"white_doe": BK_BASE + "characters/" + BK_BIOME + "/creature_bk_foret_broceliande_0001.glb",
	"mist_wolf": BK_BASE + "characters/" + BK_BIOME + "/creature_bk_foret_broceliande_0002.glb",
	"giant_raven": BK_BASE + "characters/" + BK_BIOME + "/creature_bk_foret_broceliande_0003.glb",
	# Decor (rocks 1.8m / collectibles 0.4m)
	"fallen_trunk": BK_BASE + "rocks/" + BK_BIOME + "/rock_bk_foret_broceliande_0000.glb",
	"giant_mushroom": BK_BASE + "rocks/" + BK_BIOME + "/rock_bk_foret_broceliande_0003.glb",
	"root_network": BK_BASE + "rocks/" + BK_BIOME + "/rock_bk_foret_broceliande_0004.glb",
	"spider_web": BK_BASE + "collectibles/" + BK_BIOME + "/collectible_bk_foret_broceliande_0002.glb",
	"giant_stump": BK_BASE + "rocks/" + BK_BIOME + "/rock_bk_foret_broceliande_0005.glb",
}


# --- Exports ---
@export var biome_key: String = "foret_broceliande"
@export var low_pixel_height: int = 320
@export var move_speed: float = 3.5
@export var mouse_sensitivity: float = 0.0026
@export var interact_distance: float = 2.8
@export var head_bob_amount: float = 0.005   # was 0.015 — softened (user feedback "trop de head bob")
@export var head_bob_speed: float = 2.8      # was 5.0 — slower for calmer walk feel

# --- Scene refs ---
@onready var world_root: Node3D = $World3D
@onready var world_env: WorldEnvironment = $World3D/WorldEnvironment
@onready var sun_light: DirectionalLight3D = $World3D/SunLight
@onready var forest_root: Node3D = $World3D/ForestRoot
@onready var merlin_node: Node3D = $World3D/Merlin
@onready var player: CharacterBody3D = $World3D/Player
@onready var player_collision: CollisionShape3D = $World3D/Player/CollisionShape3D
@onready var player_head: Node3D = $World3D/Player/Head
@onready var player_camera: Camera3D = $World3D/Player/Head/Camera3D
@onready var zone_label: Label = $HUD/Margin/InfoPanel/VBox/ZoneLabel
@onready var objective_label: Label = $HUD/Margin/InfoPanel/VBox/ObjectiveLabel
@onready var status_label: Label = $HUD/Margin/InfoPanel/VBox/StatusLabel
@onready var crosshair: Label = $HUD/Crosshair
@onready var result_panel: PanelContainer = $HUD/ResultPanel
@onready var result_text: Label = $HUD/ResultPanel/ResultMargin/VBox/ResultText
@onready var replay_button: Button = $HUD/ResultPanel/ResultMargin/VBox/Buttons/ReplayButton
@onready var hub_button: Button = $HUD/ResultPanel/ResultMargin/VBox/Buttons/HubButton

# --- State ---
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _gravity: float = 9.8
var _velocity: Vector3 = Vector3.ZERO
var _pitch: float = 0.0
var _merlin_found: bool = false
var _current_zone: int = 0
var _event_text: String = ""
var _event_text_timer: float = 0.0
var _head_bob_time: float = 0.0
var _time: float = 0.0


# Helper modules
var _autowalk: RefCounted
var _day_night: RefCounted
var _season: RefCounted
var _grass_wind: RefCounted
var _atmosphere: RefCounted
var _parallax: RefCounted
var _events: RefCounted
var _chunk_manager: RefCounted

# New gameplay systems (LLM events + HUD)
var _walk_event_overlay: Node  # WalkEventOverlay (CanvasLayer)
var _walk_hud: Node  # WalkHUD (CanvasLayer)
var _walk_event_controller: RefCounted  # WalkEventController
var _event_vfx: RefCounted  # BrocEventVfx
var _screen_vfx: RefCounted  # BrocScreenVfx
var _creature_spawner: RefCounted  # BrocCreatureSpawner
var _fauna_bubble: RefCounted  # BrocFaunaBubble
var _narrative_director: RefCounted  # BrocNarrativeDirector
var _merlin_whisper: Node  # MerlinWhisper (CanvasLayer)
var _gameplay_active: bool = false  # true when LLM event system is wired
var _is_tutorial: bool = false  # set by GameManager.first_run_tutorial — uses scripted fallback cards only, no LLM
var _encounter_count: int = 0
var _encounter_total: int = 5
var _saved_crt_preset: String = "medium"
var _crt_was_visible: bool = true

# Extracted modules
var _asset_spawner: RefCounted  # ForestAssetSpawner
var _zone_builder: RefCounted  # ForestZoneBuilder
var _effects: RefCounted  # ForestEffects
var _merlin_npc: RefCounted  # ForestMerlinNpc
var _terrain_builder: RefCounted  # ForestTerrainBuilder
var _glb_placer: RefCounted  # GlbAssetPlacer

var _path_points: PackedVector3Array = PackedVector3Array()
var _zone_centers: Array[Vector3] = []
var _zone_names: Array[String] = []  # Loaded from BiomeWalkConfigs in _ready

# Pixel-shrink SubViewport (renders 3D at low_pixel_height, upscales with nearest + CRT)
var _sub_viewport: SubViewport
var _viewport_container: SubViewportContainer
var _retro_material: ShaderMaterial

# Dynamic resolution scaling — auto-adapts to device performance
const RES_TIERS: Array[Vector2i] = [Vector2i(320, 180), Vector2i(480, 270), Vector2i(640, 360)]
var _res_tier: int = 0
var _res_cooldown: float = 0.0
var _frame_samples: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_rng.randomize()
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	# Tutorial mode (First Run from Intro): no LLM, scripted fallback cards only.
	var gm_node: Node = get_tree().root.get_node_or_null("GameManager")
	if gm_node and gm_node.has_meta("first_run_tutorial"):
		_is_tutorial = bool(gm_node.get_meta("first_run_tutorial"))
		if _is_tutorial:
			print("[Forest3D] Tutorial mode active (scripted, no LLM)")
			gm_node.remove_meta("first_run_tutorial")  # consume flag — next run uses LLM
	# Test/dev override: force tutorial via env var (used by smoke capture).
	if not _is_tutorial and OS.get_environment("MERLIN_FORCE_TUTORIAL") == "1":
		_is_tutorial = true
		print("[Forest3D] Tutorial mode forced via MERLIN_FORCE_TUTORIAL=1")
	# Read biome_key from MerlinStore if a run selected a different biome
	var init_store: Node = _find_store()
	if init_store:
		var st_val: Variant = init_store.get("state")
		if st_val is Dictionary:
			var run_data: Dictionary = (st_val as Dictionary).get("run", {})
			var stored_biome: String = str(run_data.get("current_biome", ""))
			if stored_biome != "":
				biome_key = stored_biome
	# Disable ALL autoload CanvasLayers — hint_screen_texture breaks 3D in GL Compatibility
	for child in get_tree().root.get_children():
		if child is CanvasLayer:
			if child.has_method("get_crt_preset"):
				_saved_crt_preset = child.get_crt_preset()
			_crt_was_visible = child.visible
			child.visible = false
			for sub in child.get_children():
				sub.queue_free()
			print("[Broceliande] Disabled autoload CanvasLayer: %s" % child.name)
	_asset_spawner = ForestAssetSpawnerClass.new(forest_root, _rng)
	_asset_spawner.load_assets(TREE_MODELS, BUSH_MODELS, SPECIAL_TREES, DETAIL_MODELS, BROC_ASSETS)
	_ensure_actions()
	_setup_viewport()
	_setup_environment()
	_generate_path()
	_setup_player()
	# Load zone names from biome config
	var ready_biome_cfg: Dictionary = BiomeWalkConfigs.get_config(biome_key)
	var cfg_zones: Array = ready_biome_cfg.get("zones", []) as Array
	_zone_names.clear()
	for z in cfg_zones:
		_zone_names.append(str(z))
	# Pad to match _zone_centers count if config has fewer names
	while _zone_names.size() < _zone_centers.size():
		_zone_names.append("Zone %d" % _zone_names.size())

	_terrain_builder = ForestTerrainBuilderClass.new(world_root, forest_root, _zone_centers, _path_points, _rng, _asset_spawner)
	_terrain_builder.set_biome_config(biome_key)
	_terrain_builder.build_ground()
	_terrain_builder.build_path_terrain()
	_terrain_builder.build_occluders()
	# Apply biome walk speed
	var biome_walk_cfg: Dictionary = BiomeWalkConfigs.get_config(biome_key)
	move_speed = float(biome_walk_cfg.get("walk_speed", 3.5))
	_zone_builder = ForestZoneBuilderClass.new(_asset_spawner, forest_root, _zone_centers, _rng)
	_zone_builder.build_zones()
	# GLB asset placer — creatures, extra megaliths, decor scatter, vegetation GLBs
	# GLB assets ALWAYS for the world to feel alive (decorative, interactable later).
	_glb_placer = GlbAssetPlacerClass.new()
	_glb_placer.place_assets(forest_root, _zone_centers, _rng)
	_spawn_merlin()
	# Effects: tutorial mode uses a curated subset (volumetric fog + god rays + pollen).
	# Skip the noisy ones (falling leaves, fog particles, fireflies — too distracting during VO).
	_effects = ForestEffectsClass.new(forest_root, _zone_centers, _rng)
	if _is_tutorial:
		_effects.add_god_rays()
		_effects.add_pollen_particles()
		_effects.add_ground_mist()
	else:
		_effects.add_fog_particles()
		_effects.add_pollen_particles()
		_effects.add_fireflies()
		_effects.add_god_rays()
		_effects.add_falling_leaves()
		_effects.add_ground_mist()
	_init_helpers()

	# Procedural fallback trees: SKIP in tuto (they produce rectangular bar silhouettes).
	# Ground details (rocks + grass patches): keep them — user wants more grass + decor.
	if not _is_tutorial:
		# If no GLB trees loaded, spawn procedural fallback trees along the path
		if _asset_spawner and not _asset_spawner.has_trees():
			print("[Broceliande] Spawning 40 procedural trees along path")
			for i in 40:
				var t: float = float(i) / 40.0
				var path_idx: int = clampi(int(t * float(_path_points.size() - 1)), 0, _path_points.size() - 1)
				var base_pos: Vector3 = _path_points[path_idx]
				var offset_x: float = randf_range(-12.0, 12.0)
				var offset_z: float = randf_range(-8.0, 8.0)
				if absf(offset_x) < 3.0:
					offset_x = 3.0 * signf(offset_x + 0.01)
				var pos: Vector3 = Vector3(base_pos.x + offset_x, 0.0, base_pos.z + offset_z)
				_asset_spawner.spawn_procedural_tree(pos, randf_range(1.5, 3.5))

	# Procedural ground detail (rocks + grass patches) along path — both modes.
	_spawn_ground_details()
	# Tutorial mode: scatter floating ogham symbols along the path (decorative drift).
	if _is_tutorial:
		_spawn_floating_oghams()

	_wire_buttons()
	_update_hud()
	# PC mode: cursor visible, no mouse capture. Camera is rail-only (autowalk drives it).
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Tutorial mode: progressive reveal sequence (Merlin VO + assets fade in + parchment),
	# then start the actual walk. Otherwise straight to aerial descent → autowalk.
	if _is_tutorial:
		_run_tutorial_intro()
	else:
		# Book cinematic is now shown in MerlinCabinHub BEFORE entering forest
		# Forest starts directly with aerial descent → auto-walk
		_start_aerial_then_walk()


func _init_helpers() -> void:
	# Auto-walk controller with encounter stops
	_autowalk = BrocAutowalk.new(_path_points, player, player_head, player_camera, _zone_centers)
	var total_wp: int = _path_points.size()
	var enc_indices: Array[int] = []
	if _is_tutorial:
		# Tutorial: exactly 3 encounters, evenly spaced at ~25%, 55%, 85% of the path.
		_encounter_total = 3
		for t_pct in [0.25, 0.55, 0.85]:
			var idx_t: int = clampi(int(float(total_wp) * float(t_pct)), 1, total_wp - 1)
			enc_indices.append(idx_t)
	else:
		# Default: ~5 encounters every total_wp/6 waypoints.
		var enc_spacing: int = maxi(total_wp / 6, 5)
		for i in range(enc_spacing, total_wp - enc_spacing, enc_spacing):
			enc_indices.append(i)
	_autowalk.set_encounters(enc_indices, _on_encounter_reached)
	_autowalk.set_run_complete_callback(_on_run_complete)

	# Procedural chunk manager (replaces dense_fill + mass_fill + extra_decor)
	# Tutorial mode: skip — chunks spawn rectangular tree silhouettes that pollute the scene.
	if not _is_tutorial:
		_chunk_manager = BrocChunkManager.new()
		_chunk_manager.setup(
			forest_root, _asset_spawner.tree_scenes, _asset_spawner.bush_scenes,
			_asset_spawner.special_scenes, _asset_spawner.detail_scenes, _asset_spawner.broc_scenes,
			_zone_centers, _path_points)
		var chunk_biome_cfg: Dictionary = BiomeWalkConfigs.get_config(biome_key)
		var terrain_col: Color = chunk_biome_cfg.get("terrain_color", Color(0.15, 0.25, 0.10)) as Color
		_chunk_manager.set_biome_colors(terrain_col)
		_chunk_manager.generate_initial(player.position.z)

	# Day/night cycle
	_day_night = BrocDayNight.new(sun_light, world_env)

	# Season system (overlay on top of this Control)
	_season = BrocSeason.new(forest_root, self)

	# Grass now handled by ChunkManager cross-billboard MultiMesh (replaces BrocGrassWind)
	_grass_wind = null

	# Enhanced atmosphere (zone-aware fog)
	_atmosphere = BrocAtmosphere.new(forest_root, _zone_centers)
	_atmosphere.set_environment(world_env.environment)

	# Tutorial mode: skip parallax (2D bars in front/behind), screen VFX (vignette/shake/flash),
	# creature spawner ("Chut...", "*glousse*" bubbles) and fauna bubbles. All would compete
	# with Merlin's narration.
	if not _is_tutorial:
		# 2D parallax forest layers (behind + in front of 3D)
		_parallax = BrocParallaxLayers.new()
		_parallax.setup(self, biome_key)

		# Screen VFX (shake, flash, glitch, vignette)
		_screen_vfx = BrocScreenVfxClass.new()
		_screen_vfx.setup(null, self, forest_root)

		# Billboard creatures
		_creature_spawner = BrocCreatureSpawnerClass.new(forest_root)

		# Fauna dialogue bubbles
		_fauna_bubble = BrocFaunaBubbleClass.new()
		_fauna_bubble.setup(self)

	# VFX + NarrativeDirector + atmospheric events: skip in tutorial mode
	# (they reference _creature_spawner / _screen_vfx / _chunk_manager which are null in tuto).
	if not _is_tutorial:
		# VFX system (keyword → 3D effects) — must be created before NarrativeDirector
		_event_vfx = BrocEventVfxClass.new(forest_root, world_env, sun_light)

		# LLM Narrative Director (orchestration layer)
		_narrative_director = BrocNarrativeDirectorClass.new()
		_narrative_director.setup(_atmosphere, _creature_spawner, _screen_vfx, _event_vfx, _chunk_manager)

		# Random atmospheric events (legacy, still runs if gameplay not active)
		_events = BrocEvents.new(forest_root, world_env, sun_light)

	# New gameplay systems: LLM event overlay + minimal HUD
	_init_gameplay_systems()


func _init_gameplay_systems() -> void:
	# Walk HUD (PV, Currency, Ogham, Card Count) — CanvasLayer above viewport
	_walk_hud = WalkHudClass.new()
	add_child(_walk_hud)

	# Merlin whisper system — ambient cryptic one-liners during walk
	_merlin_whisper = MerlinWhisperClass.new()
	add_child(_merlin_whisper)

	# Event overlay (darkened bg + typewriter + 3 choices)
	_walk_event_overlay = WalkEventOverlayClass.new()
	add_child(_walk_event_overlay)

	# Event controller (LLM bridge, triggers, prefetch)
	_walk_event_controller = WalkEventControllerClass.new()

	# Try to find MerlinStore autoload
	var store: Node = _find_store()
	if store:
		_walk_event_controller.setup(store, _walk_event_overlay, _walk_hud, _event_vfx)
		_gameplay_active = true
		print("[Broceliande] Gameplay systems active (MerlinStore found)")
	else:
		# No store — still show HUD with defaults, events use fallback pool
		_walk_event_controller.setup(null, _walk_event_overlay, _walk_hud, _event_vfx)
		_gameplay_active = true
		print("[Broceliande] Gameplay systems active (fallback mode, no MerlinStore)")


func _find_store() -> Node:
	# Try autoload singleton
	if has_node("/root/MerlinStore"):
		return get_node("/root/MerlinStore")
	# Try SceneTree autoload
	for child: Node in get_tree().root.get_children():
		if child is MerlinStore:
			return child
	return null


func _spawn_diag_box() -> void:
	pass  # Diagnostic removed — 3D rendering confirmed working


func _on_window_resized() -> void:
	if _viewport_container:
		var win_size: Vector2 = get_viewport().get_visible_rect().size
		_viewport_container.size = win_size
		if _retro_material:
			_retro_material.set_shader_parameter("screen_size", win_size)


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Restore CRT post-process for other scenes
	var crt_layer: Node = get_node_or_null("/root/ScreenDither")
	if crt_layer:
		if crt_layer.has_method("set_crt_preset"):
			crt_layer.set_crt_preset(_saved_crt_preset)
		if crt_layer.has_method("set_enabled"):
			crt_layer.set_enabled(_crt_was_visible)



# ============================================================
# INPUT
# ============================================================

func _ensure_actions() -> void:
	_bind(ACT_FWD, [KEY_W, KEY_UP])
	_bind(ACT_BACK, [KEY_S, KEY_DOWN])
	_bind(ACT_LEFT, [KEY_A, KEY_LEFT])
	_bind(ACT_RIGHT, [KEY_D, KEY_RIGHT])
	_bind(ACT_INTERACT, [KEY_E, KEY_ENTER])
	_bind(ACT_MOUSE, [KEY_ESCAPE])
	_bind(&"broc_autowalk_toggle", [KEY_TAB])
	_bind(&"broc_season_cycle", [KEY_F5])
	_bind(&"broc_time_toggle", [KEY_F4])


func _bind(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var mapped: Dictionary = {}
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			mapped[(ev as InputEventKey).physical_keycode] = true
	for k in keys:
		if not mapped.has(k):
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACT_MOUSE):
		_toggle_mouse()
		return
	if event.is_action_pressed(ACT_INTERACT):
		# POI event trigger if gameplay active and overlay not showing
		if _gameplay_active and _walk_event_controller and _walk_event_overlay and not _walk_event_overlay.is_active():
			_walk_event_controller.trigger_poi_event(player.position)
		_try_interact()
		return
	if event.is_action_pressed(&"broc_autowalk_toggle"):
		if _autowalk:
			_autowalk.toggle()
		return
	if event.is_action_pressed(&"broc_season_cycle"):
		if _season:
			_season.cycle_next()
		return
	if event.is_action_pressed(&"broc_time_toggle"):
		if _day_night:
			_day_night.set_realtime(not _day_night._realtime_mode)
			print("[Broceliande] Time mode: %s" % ("REALTIME" if _day_night._realtime_mode else "ACCELERATED"))
		return
	# Camera is rail-only — mouse motion does NOT rotate the player/camera.
	# Autowalk + path follower drive orientation. Cursor stays visible (PC mode).


func _physics_process(delta: float) -> void:
	_time += delta

	# Freeze movement during event overlay
	var overlay_active: bool = _walk_event_overlay and _walk_event_overlay.is_active()

	# Auto-walk overrides manual movement
	var autowalk_active: bool = _autowalk and _autowalk.is_active()

	if overlay_active:
		# Player frozen during events — only gravity
		_velocity.y = -0.05 if player.is_on_floor() else _velocity.y - _gravity * delta
		_velocity.x = move_toward(_velocity.x, 0.0, 8.0 * delta)
		_velocity.z = move_toward(_velocity.z, 0.0, 8.0 * delta)
		player.velocity = _velocity
		player.move_and_slide()
		_velocity = player.velocity
	elif autowalk_active:
		_autowalk.update(delta)
	else:
		var axis: Vector2 = Input.get_vector(ACT_LEFT, ACT_RIGHT, ACT_FWD, ACT_BACK)
		var move_dir: Vector3 = Vector3.ZERO
		var is_moving: bool = false

		if axis.length() > 0.01 and not _merlin_found and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			var yaw: Basis = Basis(Vector3.UP, player.rotation.y)
			move_dir = (yaw * Vector3(axis.x, 0.0, axis.y)).normalized()
			is_moving = true

		var accel: float = 12.0 if is_moving else 8.0
		_velocity.x = move_toward(_velocity.x, move_dir.x * move_speed, accel * delta)
		_velocity.z = move_toward(_velocity.z, move_dir.z * move_speed, accel * delta)
		_velocity.y = -0.05 if player.is_on_floor() else _velocity.y - _gravity * delta

		player.velocity = _velocity
		player.move_and_slide()
		_velocity = player.velocity

		# Head bob
		if is_moving and player.is_on_floor():
			_head_bob_time += delta * head_bob_speed
			player_camera.position.y = sin(_head_bob_time) * head_bob_amount
			player_camera.position.x = cos(_head_bob_time * 0.5) * head_bob_amount * 0.25
		else:
			_head_bob_time = 0.0
			player_camera.position.y = move_toward(player_camera.position.y, 0.0, delta * 2.0)
			player_camera.position.x = move_toward(player_camera.position.x, 0.0, delta * 2.0)

	# Chunk manager — stream vegetation around player
	if _chunk_manager:
		_chunk_manager.update(player.position)

	# Day/night cycle
	if _day_night:
		_day_night.update(delta)

	# Atmosphere animation + zone fog
	if _atmosphere and _day_night:
		_atmosphere.update(delta, _day_night.get_time())
		_atmosphere.update_zone(_current_zone)
	elif _atmosphere:
		_atmosphere.update(delta, 0.15)
		_atmosphere.update_zone(_current_zone)

	# Parallax 2D layers scroll with player
	if _parallax:
		_parallax.update(player.position.z, player.position.x)
		_parallax.set_zone(_current_zone)

	# Screen VFX (shake, glitch, vignette decay)
	if _screen_vfx:
		_screen_vfx.update(delta)

	# Billboard creatures
	if _creature_spawner:
		var is_night: bool = false
		if _day_night:
			var t: float = _day_night.get_time()
			is_night = t >= 0.55 and t < 0.95
		_creature_spawner.update(delta, player.position, _current_zone, is_night)

	# Fauna dialogue bubbles
	if _fauna_bubble and _creature_spawner:
		_fauna_bubble.update(delta, player_camera, _creature_spawner.get_active_creatures())

	# Modulate particles by day/night
	if _day_night:
		var t: float = _day_night.get_time()
		var is_night: bool = t >= 0.55 and t < 0.95
		# Fireflies visible at night, faint during day
		if _effects:
			for ff in _effects.firefly_nodes:
				if is_instance_valid(ff):
					ff.amount_ratio = 1.0 if is_night else 0.15
			# Pollen only during daytime
			if _effects.pollen_node and is_instance_valid(_effects.pollen_node):
				_effects.pollen_node.amount_ratio = 0.0 if is_night else 1.0

	# Event system: use new walk controller if gameplay active, else legacy
	if _gameplay_active and _walk_event_controller:
		_walk_event_controller.update(delta, player.position, _current_zone, _narrative_director)
	elif _events and _day_night:
		var evt_text: String = _events.update(delta, player.position, _current_zone, _day_night.get_time())
		if evt_text != "":
			_show_event_text(evt_text)
	if _event_text_timer > 0.0:
		_event_text_timer -= delta

	# Tree sway animation
	_update_tree_sway(delta)

	if _merlin_npc:
		_merlin_npc.update_visual(delta)
	_update_current_zone()
	_update_hud()

	# Update walk HUD zone info
	if _walk_hud and _walk_hud.has_method("update_zone"):
		var zone_name: String = _zone_names[_current_zone] if _current_zone < _zone_names.size() else ""
		var season_name: String = _season.get_name() if _season else ""
		var time_name: String = _get_time_of_day_name()
		_walk_hud.update_zone(zone_name, season_name, time_name)

	# Update whisper context for ambient Merlin quips
	if _merlin_whisper and _merlin_whisper.has_method("set_context"):
		var health_pct: float = 1.0
		var gm_w: Node = get_node_or_null("/root/GameManager")
		if gm_w:
			var rs_val: Variant = gm_w.get("run_state")
			if rs_val is Dictionary:
				health_pct = float((rs_val as Dictionary).get("life_essence", 100)) / 100.0
		var total_runs: int = 0
		var st: Node = get_node_or_null("/root/MerlinStore")
		if st:
			var st_val: Variant = st.get("state")
			if st_val is Dictionary:
				total_runs = int((st_val as Dictionary).get("meta", {}).get("total_runs", 0))
		_merlin_whisper.set_context("broceliande", health_pct, _get_time_of_day_name(), total_runs)

	# Dynamic resolution scaling — adjust SubViewport size based on frame time
	_update_dynamic_resolution(delta)


func _update_dynamic_resolution(delta: float) -> void:
	if not _sub_viewport:
		return
	_frame_samples.append(delta)
	if _frame_samples.size() > 30:
		_frame_samples.remove_at(0)
	_res_cooldown -= delta
	if _res_cooldown > 0.0:
		return
	_res_cooldown = 0.5
	var avg: float = 0.0
	for s in _frame_samples:
		avg += s
	avg /= float(_frame_samples.size())
	var changed: bool = false
	if avg > 0.018 and _res_tier > 0:
		_res_tier -= 1
		changed = true
	elif avg < 0.012 and _res_tier < RES_TIERS.size() - 1:
		_res_tier += 1
		changed = true
	if changed:
		var tier: Vector2i = RES_TIERS[_res_tier]
		_sub_viewport.size = tier
		if _retro_material:
			_retro_material.set_shader_parameter("render_size", Vector2(tier.x, tier.y))
		print("[Broceliande] Dynamic res: tier %d (%dx%d)" % [_res_tier, tier.x, tier.y])


# ============================================================
# VIEWPORT / ENVIRONMENT
# ============================================================

func _setup_viewport() -> void:
	# Pixel-shrink: render 3D at low_pixel_height, upscale with nearest-neighbor + CRT shader.
	# 320x180 = 16x fewer fragments than 1280x720. Huge win for GL Compat / web.
	# Tutorial mode keeps the PS1 aesthetic but with softer dither so the reveal stays readable.
	var render_h: int = low_pixel_height
	var render_w: int = int(float(render_h) * 16.0 / 9.0)
	render_w += render_w % 2  # Round to even

	# Create SubViewport at low resolution
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(render_w, render_h)
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_viewport.handle_input_locally = false
	_sub_viewport.name = "PixelShrinkVP"

	# Reparent World3D under SubViewport (Camera3D renders at low res)
	var parent: Node = world_root.get_parent()
	parent.remove_child(world_root)
	_sub_viewport.add_child(world_root)

	# SubViewportContainer displays the low-res output upscaled
	_viewport_container = SubViewportContainer.new()
	_viewport_container.stretch = true
	_viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_viewport_container.name = "PixelShrinkContainer"

	# Apply retro CRT upscale shader (scanlines, curvature, posterization)
	# User feedback "trop de dithering" — soften scanline + grid + noise.
	var retro_shader: Shader = load("res://resources/shaders/retro_screen.gdshader") as Shader
	if retro_shader:
		_retro_material = ShaderMaterial.new()
		_retro_material.shader = retro_shader
		_retro_material.set_shader_parameter("render_size", Vector2(render_w, render_h))
		_retro_material.set_shader_parameter("screen_size", Vector2(1280.0, 720.0))
		_retro_material.set_shader_parameter("scanline_strength", 0.08)   # was 0.18 default
		_retro_material.set_shader_parameter("grid_strength", 0.04)        # was 0.12
		_retro_material.set_shader_parameter("noise_strength", 0.015)      # was 0.04
		_retro_material.set_shader_parameter("vignette_strength", 0.18)    # was 0.25
		_retro_material.set_shader_parameter("color_levels", 6.0)          # was 3.0 — less posterized
		_retro_material.set_shader_parameter("curvature", 0.03)            # was 0.06 — flatter screen
		_viewport_container.material = _retro_material

	_viewport_container.add_child(_sub_viewport)

	# Size container to fill window
	var win_size: Vector2 = get_viewport().get_visible_rect().size
	_viewport_container.size = win_size

	# Insert at index 0 so 3D renders behind HUD CanvasLayer
	add_child(_viewport_container)
	move_child(_viewport_container, 0)

	# Handle window resize
	get_tree().root.size_changed.connect(_on_window_resized)
	print("[Broceliande] Pixel shrink: %dx%d -> %dx%d" % [render_w, render_h, int(win_size.x), int(win_size.y)])


func _setup_environment() -> void:
	var env: Environment = Environment.new()

	# Load biome-specific colors from BiomeWalkConfigs
	var biome_cfg: Dictionary = BiomeWalkConfigs.get_config(biome_key)
	var bg_color: Color = biome_cfg.get("fog_color", Color(0.30, 0.40, 0.28)) as Color
	var ambient_color: Color = biome_cfg.get("ambient_color", Color(0.55, 0.65, 0.45)) as Color
	var fog_color: Color = biome_cfg.get("fog_color", Color(0.35, 0.45, 0.32)) as Color
	var fog_density: float = float(biome_cfg.get("fog_density", 0.018)) * 0.25  # Heavily reduced for web — trees must be visible

	# GL Compatibility: ProceduralSkyMaterial renders white regardless of BG_COLOR mode.
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.55, 0.70)  # Blue-grey sky for contrast with green trees

	# Ambient — strong enough to light dark CRT-style materials
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = 1.3  # Brighter for web (low-poly needs more light)

	# Fog — biome-specific
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	# fog_aerial_perspective not supported in GL Compatibility — skip

	# Tonemap
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.tonemap_exposure = 1.4

	# Glow, SSAO — not supported in GL Compatibility, omitted
	# env.ssao_enabled = true

	world_env.environment = env

	# Sun — warm filtered light
	sun_light.rotation_degrees = Vector3(-45.0, -25.0, 0.0)
	sun_light.light_color = Color(0.85, 0.80, 0.60)
	sun_light.light_energy = 2.5  # Brighter sun for low-poly visibility
	sun_light.shadow_enabled = true
	sun_light.shadow_bias = 0.02
	sun_light.shadow_normal_bias = 1.0

	# Secondary fill light (blue bounce from sky)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(30.0, 160.0, 0.0)
	fill.light_color = Color(0.40, 0.55, 0.65)
	fill.light_energy = 0.5
	fill.shadow_enabled = false
	world_root.add_child(fill)

	# --- DayNightManager integration ---
	# Blend time-of-day lighting into the biome environment.
	# We keep BG_COLOR mode (GL Compat) but tint ambient, fog, sun from DayNightManager.
	_apply_day_night_to_environment(env, sun_light, fill)


func _apply_day_night_to_environment(env: Environment, sun: DirectionalLight3D, fill: DirectionalLight3D) -> void:
	## Blend DayNightManager time-of-day colors into the biome environment.
	## Uses BG_COLOR mode (GL Compat safe) — tints ambient, fog, sun, fill light.
	var dnm: Node = get_node_or_null("/root/DayNightManager")
	if dnm == null:
		return
	var sun_cfg: Dictionary = dnm.get_sun_config()
	var fill_cfg: Dictionary = dnm.get_fill_light_config()
	var period: String = dnm.get_time_of_day()
	var pcfg: Dictionary = dnm.get_period_config(period)

	# Blend sun color and energy (50% biome / 50% day-night for natural look)
	sun.light_color = sun.light_color.lerp(sun_cfg.get("color", sun.light_color), 0.5)
	sun.light_energy = lerpf(sun.light_energy, sun_cfg.get("energy", sun.light_energy) * 2.5, 0.4)
	var angle: Vector3 = sun_cfg.get("angle", sun.rotation_degrees)
	sun.rotation_degrees.x = lerpf(sun.rotation_degrees.x, angle.x, 0.3)

	# Blend fill light
	fill.light_color = fill.light_color.lerp(fill_cfg.get("color", fill.light_color), 0.4)
	fill.light_energy = lerpf(fill.light_energy, fill_cfg.get("energy", fill.light_energy), 0.3)

	# Blend ambient
	var dnm_ambient: Color = pcfg.get("ambient_color", env.ambient_light_color)
	env.ambient_light_color = env.ambient_light_color.lerp(dnm_ambient, 0.35)

	# Blend fog
	var dnm_fog: Color = pcfg.get("fog_color", env.fog_light_color)
	env.fog_light_color = env.fog_light_color.lerp(dnm_fog, 0.3)

	# Blend background sky color
	var dnm_sky_horizon: Color = pcfg.get("sky_horizon_color", env.background_color)
	env.background_color = env.background_color.lerp(dnm_sky_horizon, 0.3)

	print("[Broceliande] DayNightManager applied — period: %s" % period)


func _setup_player() -> void:
	player.position = Vector3(0.0, 1.2, 2.0) if _path_points.is_empty() else _path_points[0] + Vector3(0.0, 1.2, 0.0)
	player.rotation = Vector3.ZERO
	player_head.rotation = Vector3(deg_to_rad(-20.0), 0.0, 0.0)
	_pitch = deg_to_rad(-20.0)
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.0
	player_collision.shape = capsule
	player_collision.position = Vector3(0.0, 0.85, 0.0)
	if _path_points.size() > 1:
		var look: Vector3 = _path_points[1]
		look.y = player.position.y
		player.look_at(look, Vector3.UP)
	# Camera3D has current = true in .tscn — renders directly to main viewport
	# DIAGNOSTIC: bright unshaded box 2m in front — if visible, camera IS rendering
	call_deferred("_spawn_diag_box")



# ============================================================
# PATH
# ============================================================

func _generate_path() -> void:
	# Deep linear progression — path plunges into forest on -Z axis
	_zone_centers = [
		Vector3(0.0, 0.0, 0.0),       # Z0 Lisiere — sky visible
		Vector3(3.0, 0.0, -40.0),      # Z1 Foret Dense — canopy closes
		Vector3(-4.0, 0.0, -85.0),     # Z2 Dolmen — sacred clearing
		Vector3(2.0, -0.3, -130.0),    # Z3 Mare Enchantee — wet depression
		Vector3(-2.0, 0.3, -180.0),    # Z4 Foret Profonde — near darkness
		Vector3(5.0, 0.0, -225.0),     # Z5 Fontaine de Barenton — filtered light
		Vector3(0.0, 0.5, -270.0),     # Z6 Cercle de Pierres — climax
	]
	# Organic Bezier path — Curve3D with random tangent offsets
	var curve: Curve3D = Curve3D.new()
	for i in _zone_centers.size():
		var pt: Vector3 = _zone_centers[i]
		# Tangent handles: perpendicular wobble for organic feel
		var tang_len: float = 12.0 + _rng.randf_range(-3.0, 5.0)
		var tang_x: float = _rng.randf_range(-6.0, 6.0)
		var in_tang: Vector3 = Vector3(tang_x, 0.0, tang_len)
		var out_tang: Vector3 = Vector3(-tang_x, 0.0, -tang_len)
		curve.add_point(pt, in_tang, out_tang)

	# Sample at 0.5m resolution for smooth walking
	var total_len: float = curve.get_baked_length()
	var step: float = 0.5
	_path_points = PackedVector3Array()
	var dist: float = 0.0
	while dist <= total_len:
		var pt: Vector3 = curve.sample_baked(dist)
		_path_points.append(pt)
		dist += step
	if _path_points.size() > 0:
		var last: Vector3 = _zone_centers[_zone_centers.size() - 1]
		if _path_points[_path_points.size() - 1].distance_to(last) > 0.1:
			_path_points.append(last)






# ============================================================
# ANIMATIONS
# ============================================================

func _update_tree_sway(_delta: float) -> void:
	if not _asset_spawner:
		return
	for node in _asset_spawner.sway_nodes:
		if not is_instance_valid(node):
			continue
		var hash_val: float = float(node.get_instance_id() % 1000) * 0.001
		var sway_x: float = sin(_time * 0.8 + hash_val * TAU) * 0.008
		var sway_z: float = cos(_time * 0.6 + hash_val * TAU * 1.3) * 0.005
		node.rotation.x = sway_x
		node.rotation.z = sway_z


# ============================================================
# MERLIN
# ============================================================

func _spawn_ground_details() -> void:
	## Procedural rocks + grass patches for visual depth
	var rng_local: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_local.seed = 42
	for i in 25:
		var t: float = float(i) / 25.0
		var pidx: int = clampi(int(t * float(_path_points.size() - 1)), 0, _path_points.size() - 1)
		var bp: Vector3 = _path_points[pidx]

		# Rock
		var rock: MeshInstance3D = MeshInstance3D.new()
		var rm: BoxMesh = BoxMesh.new()
		var rs: float = rng_local.randf_range(0.2, 0.8)
		rm.size = Vector3(rs, rs * 0.6, rs * 0.8)
		rock.mesh = rm
		var rmat: StandardMaterial3D = StandardMaterial3D.new()
		rmat.albedo_color = Color(0.35, 0.32, 0.28)
		rmat.roughness = 0.95
		rock.material_override = rmat
		rock.position = Vector3(
			bp.x + rng_local.randf_range(-8.0, 8.0),
			rs * 0.2,
			bp.z + rng_local.randf_range(-6.0, 6.0)
		)
		rock.rotation.y = rng_local.randf_range(0.0, TAU)
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		forest_root.add_child(rock)

		# Grass patch (flat disc on ground)
		if i % 2 == 0:
			var grass: MeshInstance3D = MeshInstance3D.new()
			var gm: CylinderMesh = CylinderMesh.new()
			gm.top_radius = rng_local.randf_range(0.5, 1.5)
			gm.bottom_radius = gm.top_radius * 1.1
			gm.height = 0.05
			grass.mesh = gm
			var gmat: StandardMaterial3D = StandardMaterial3D.new()
			gmat.albedo_color = Color(0.18 + rng_local.randf() * 0.1, 0.35 + rng_local.randf() * 0.15, 0.12)
			gmat.roughness = 1.0
			grass.material_override = gmat
			grass.position = Vector3(
				bp.x + rng_local.randf_range(-10.0, 10.0),
				0.02,
				bp.z + rng_local.randf_range(-8.0, 8.0)
			)
			grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			forest_root.add_child(grass)


func _spawn_merlin() -> void:
	_merlin_npc = ForestMerlinNpcClass.new(merlin_node, player, _zone_centers[6], _rng, self)
	_merlin_npc.spawn()


# ============================================================
# HUD & INTERACTION
# ============================================================

func _update_current_zone() -> void:
	var best: int = 0
	var best_d: float = 999.0
	for i in _zone_centers.size():
		var d: float = Vector2(player.global_position.x - _zone_centers[i].x, player.global_position.z - _zone_centers[i].z).length()
		if d < best_d:
			best_d = d
			best = i
	_current_zone = best


func _update_hud() -> void:
	if _merlin_found:
		return

	# Update WalkHUD (PV + Ogham + Essences)
	if _walk_hud:
		var store: Node = get_node_or_null("/root/GameManager")
		if store:
			# run_state can be null (no active run) — guard the cast.
			var rs: Variant = store.get("run_state") if store.has_method("get") else null
			var run: Dictionary = rs as Dictionary if rs is Dictionary else {}
			var life: int = int(run.get("life_essence", 100))
			_walk_hud.update_pv(life, 100)
			var essences: int = int(run.get("biome_currency", 0))
			_walk_hud.update_essences(essences)
		if _walk_hud.has_method("update_ogham"):
			var ogham_key: String = "beith"
			var merlin_store: Node = get_node_or_null("/root/MerlinStore")
			if merlin_store:
				ogham_key = str(merlin_store.state.get("run", {}).get("ogham_actif", "beith"))
			if ogham_key.is_empty() or not MerlinConstants.OGHAM_FULL_SPECS.has(ogham_key):
				ogham_key = "beith"
			var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_key, {})
			var glyph: String = str(spec.get("unicode", "\u1681"))
			var ogham_name: String = str(spec.get("name", ogham_key.capitalize()))
			var cooldown: int = int(spec.get("cooldown", 3))
			_walk_hud.update_ogham(glyph, ogham_name, cooldown)

	# Zone name + season + time of day + autowalk indicators
	var zone_text: String = _zone_names[_current_zone]
	if _season:
		zone_text += " | %s" % _season.get_name()
	if _day_night:
		zone_text += " | %s" % _get_time_of_day_name()
	if _autowalk and _autowalk.is_active():
		zone_text += " | Auto [Tab]"
	zone_label.text = zone_text

	objective_label.text = "Suis le sentier vers le coeur de Broceliande. [Tab] Auto | [F4] Temps | [F5] Saison"

	# Event text overrides status temporarily
	if _event_text_timer > 0.0:
		status_label.text = _event_text
		return

	var dist: float = player.global_position.distance_to(merlin_node.global_position)
	if dist <= interact_distance:
		status_label.text = "Aura druidique intense. [E] pour parler a Merlin."
	elif dist < 15.0:
		status_label.text = "Presence mystique toute proche... (%.0f m)" % dist
	elif dist < 40.0:
		status_label.text = "L'air vibre d'une energie ancienne..."
	else:
		status_label.text = "Le sentier s'enfonce dans la foret..."


func _show_event_text(text: String) -> void:
	_event_text = text
	_event_text_timer = 3.0


func _get_time_of_day_name() -> String:
	if not _day_night:
		return ""
	var t: float = _day_night.get_time()
	if t < 0.1 or t > 0.95:
		return "Aube"
	elif t < 0.35:
		return "Midi"
	elif t < 0.55:
		return "Crepuscule"
	else:
		return "Nuit"


func _try_interact() -> void:
	if _merlin_found:
		return
	if player.global_position.distance_to(merlin_node.global_position) > interact_distance:
		return
	_merlin_found = true
	objective_label.text = "Merlin t'a retrouve au coeur de Broceliande."
	status_label.text = "Le druide ouvre un passage vers la quete."
	zone_label.text = "Le Cercle de Pierres — Rencontre"
	result_text.text = "Au centre du cercle millenaire,\nMerlin se revele dans un halo bleu.\n\nLa quete des Runes commence."
	result_panel.visible = true
	crosshair.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	merlin_encounter_complete.emit()


func _toggle_mouse() -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif not _merlin_found:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _wire_buttons() -> void:
	if not replay_button.pressed.is_connected(_on_replay):
		replay_button.pressed.connect(_on_replay)
	if not hub_button.pressed.is_connected(_on_hub):
		hub_button.pressed.connect(_on_hub)


func _on_replay() -> void:
	get_tree().reload_current_scene()


## Start aerial descent then auto-walk (book cinematic already shown in cabin)
func _start_aerial_then_walk() -> void:
	if _autowalk:
		_autowalk._stopped = true
	# Aerial descent → then start walking
	var descent: Node = BrocAerialDescent.new(
		player_camera, _path_points, _zone_centers, biome_key, world_env)
	descent.descent_complete.connect(func():
		if _autowalk:
			_autowalk._stopped = false
	)
	add_child(descent)
	descent.start()


## (Legacy) Show book cinematic overlay — kept for reference
func _show_book_cinematic() -> void:
	# Pause auto-walk during intro sequence
	if _autowalk:
		_autowalk._stopped = true

	# Phase 1: Book cinematic (double scroll intro)
	var cinematic: BookCinematic = BookCinematic.new()
	cinematic.set_intro(_title_text(), FALLBACK_INTRO_TEXT)
	add_child(cinematic)
	cinematic.cinematic_complete.connect(func():
		# Phase 2: Aerial descent (camera high → spiral → ground)
		var descent: Node = BrocAerialDescent.new(
			player_camera, _path_points, _zone_centers, biome_key, world_env)
		descent.descent_complete.connect(func():
			# Phase 3: Start walking
			if _autowalk:
				_autowalk._stopped = false
		)
		add_child(descent)
		descent.start()
	)


func _title_text() -> String:
	var cfg: Dictionary = BiomeWalkConfigs.get_config(biome_key)
	return str(cfg.get("display_name", "Broceliande"))


const FALLBACK_INTRO_TEXT: String = "Les brumes de Broceliande se levent lentement, devoilant les racines noueuses des chenes millenaires. Au loin, une lueur ambre pulse — le Nemeton, coeur sacre de la foret. Le sentier s'ouvre devant toi, etroit et sinueux. Merlin murmure dans le vent. La foret attend."


## Encounter callback — auto-walk paused, show card overlay on 3D
func _on_encounter_reached(enc_idx: int) -> void:
	_encounter_count = enc_idx + 1
	print("[Forest3D] Encounter %d — showing card overlay" % enc_idx)

	# Pause whispers during card encounters
	if _merlin_whisper and _merlin_whisper.has_method("pause_whispers"):
		_merlin_whisper.pause_whispers()

	# Update card count on HUD
	if _walk_hud and _walk_hud.has_method("update_card_count"):
		_walk_hud.update_card_count(_encounter_count, _encounter_total)

	# Brief anticipation — show text before card popup
	if is_instance_valid(objective_label):
		objective_label.text = "Une presence dans la brume..."
	if is_instance_valid(status_label):
		status_label.text = "Rencontre %d / %d" % [_encounter_count, _encounter_total]

	# SFX: mysterious chime
	if is_instance_valid(SFXManager):
		SFXManager.play("encounter")

	# Brief dramatic pause (1.5s) — player sees the forest freeze
	await get_tree().create_timer(1.5).timeout

	# Release mouse for UI interaction
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Generate card (FastRoute fallback or LLM)
	var card: Dictionary = await _get_encounter_card(enc_idx)

	# Show card overlay on top of frozen 3D
	var overlay: CanvasLayer = EncounterCardOverlayScript.new(card)
	add_child(overlay)
	overlay.card_resolved.connect(func(choice_idx: int, score: int):
		print("[Forest3D] Card resolved: choice=%d score=%d" % [choice_idx, score])

		# Apply effects: heal/damage based on score (no per-card drain — director decision)
		var store: Node = get_node_or_null("/root/GameManager")
		if store and store.has_method("get") and store.get("run_state") is Dictionary:
			var run: Dictionary = store.get("run_state") as Dictionary
			var life: int = int(run.get("life_essence", 100))
			if score >= 80:
				life += 5  # Reussite bonus
			elif score < 30:
				life -= 8  # Echec penalty
			life = clampi(life, 0, 100)
			run["life_essence"] = life
			# Update HUD
			if _walk_hud and _walk_hud.has_method("update_pv"):
				_walk_hud.update_pv(life, 100)
			# Check death
			if life <= 0:
				print("[Forest3D] Life = 0 — ending run")
				_on_run_complete()
				return

		# Show life change feedback on HUD
		var life_change: int = 0
		if score >= 80:
			life_change = 5  # +5 heal
		elif score < 30:
			life_change = -8  # -8 damage
		if is_instance_valid(status_label):
			if life_change > 0:
				status_label.text = "+%d PV — La foret te sourit." % life_change
			elif life_change < 0:
				status_label.text = "%d PV — Les ombres s'epaississent..." % life_change
			else:
				status_label.text = "La foret observe en silence."

		# Re-capture mouse for walk
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if is_instance_valid(objective_label):
			objective_label.text = "Le sentier continue..."
		# Resume whispers after encounter
		if _merlin_whisper and _merlin_whisper.has_method("resume_whispers"):
			_merlin_whisper.resume_whispers()
		if _autowalk:
			_autowalk.resume_after_encounter()
	)


func _get_encounter_card(enc_idx: int) -> Dictionary:
	# Tutorial mode: return one of the 3 scripted cards (no LLM, deterministic content).
	if _is_tutorial:
		print("[Forest3D] Tutorial card #%d (scripted)" % (enc_idx + 1))
		return _get_tutorial_card(enc_idx)
	# Try LLM via MerlinAI (Groq cloud in web export).
	var ai: Node = get_node_or_null("/root/MerlinAI")
	if ai and ai.get("is_ready") and ai.get("narrator_llm"):
		var llm: Object = ai.narrator_llm
		if llm and llm.has_method("generate_async") and not llm.is_generating_now():
			var prompt: String = "<|im_start|>system\nTu es Merlin. Genere une carte narrative celtique en JSON: {\"title\":\"...\",\"text\":\"...\",\"choices\":[{\"label\":\"...\"},{\"label\":\"...\"},{\"label\":\"...\"}]}. Francais uniquement. Pas d'anglais.\n<|im_end|>\n<|im_start|>user\nEncounter %d en foret de Broceliande. Genere une carte avec 3 choix distincts.\n<|im_end|>" % (enc_idx + 1)
			var result: Dictionary = {}
			var done: bool = false
			llm.generate_async(prompt, func(r: Dictionary):
				result = r
				done = true
			)
			# Poll for up to 15s
			var wait_start: float = Time.get_ticks_msec() / 1000.0
			while not done and (Time.get_ticks_msec() / 1000.0 - wait_start) < 15.0:
				if llm.has_method("poll_result"):
					llm.poll_result()
				await get_tree().process_frame
			if result.has("response"):
				var json := JSON.new()
				if json.parse(str(result["response"])) == OK and json.data is Dictionary:
					var card: Dictionary = json.data as Dictionary
					if card.has("title") and card.has("choices"):
						print("[Forest3D] LLM card generated: %s" % str(card.get("title", "")))
						return card
	# 10 fallback cards — varied themes, factions, verbs
	var fallback_cards: Array[Dictionary] = [
		{"title": "Le Cercle des Anciens", "text": "Des menhirs se dressent en sentinelles immobiles. Des runes a moitie effacees luisent dans la penombre. Le sol vibre sous tes pieds comme un coeur ancien.", "choices": [{"label": "Dechiffrer les runes"}, {"label": "Mediter au centre"}, {"label": "Contourner le cercle"}]},
		{"title": "Le Ruisseau Murmurant", "text": "Une eau cristalline coule entre les racines noueuses. Les reflets dansent comme des esprits malicieux. Le courant porte des fragments de melodies oubliees.", "choices": [{"label": "Boire l'eau sacree"}, {"label": "Suivre le courant"}, {"label": "Jeter une offrande"}]},
		{"title": "Le Marchand des Ombres", "text": "Un voyageur aux yeux d'ambre se tient au carrefour. Sa carriole deborde de curiosites etranges. Chaque objet semble porter le poids d'une histoire.", "choices": [{"label": "Negocier un echange"}, {"label": "Examiner les reliques"}, {"label": "Passer son chemin"}]},
		{"title": "La Grotte des Echos", "text": "L'obscurite s'ouvre comme une bouche de pierre. Des stalagmites brillent d'une lumiere interieure. Les echos repetent des mots que personne n'a prononces.", "choices": [{"label": "Explorer les profondeurs"}, {"label": "Appeler dans le noir"}, {"label": "Allumer une torche"}]},
		{"title": "Le Seuil de Broceliande", "text": "Le sentier debouche sur une arche naturelle de branches entrelacees. Au-dela, la foret change. Les regles du monde ordinaire n'ont plus cours.", "choices": [{"label": "Franchir l'arche"}, {"label": "Invoquer un guide"}, {"label": "Observer depuis le seuil"}]},
		{"title": "La Fontaine de Barenton", "text": "Une source jaillit entre des pierres moussues. L'eau scintille d'une lumiere surnaturelle. On dit que boire ici revele les verites cachees.", "choices": [{"label": "Boire a la source"}, {"label": "Verser une offrande"}, {"label": "Ecouter l'eau"}]},
		{"title": "Le Korrigan Malicieux", "text": "Un petit etre aux yeux brillants surgit d'un buisson. Il rit et fait tournoyer une piece d'or entre ses doigts. Son sourire est a la fois charmant et inquietant.", "choices": [{"label": "Jouer a son jeu"}, {"label": "Marchander avec lui"}, {"label": "L'ignorer"}]},
		{"title": "Le Dolmen du Passage", "text": "Deux pierres massives soutiennent une dalle de granit. L'air entre les pierres est plus froid, plus dense. Quelque chose attend de l'autre cote.", "choices": [{"label": "Traverser le passage"}, {"label": "Toucher les pierres"}, {"label": "Deposer un present"}]},
		{"title": "Le Loup de Brume", "text": "Une silhouette grise se dessine dans le brouillard. Deux yeux ambres vous fixent sans ciller. Le loup ne montre ni agressivite ni peur.", "choices": [{"label": "Soutenir son regard"}, {"label": "Tendre la main"}, {"label": "Reculer lentement"}]},
		{"title": "Le Chene de Merlin", "text": "Un chene immense deploie ses branches comme des bras protecteurs. Son tronc porte les cicatrices de mille saisons. Les druides y ont grave des symboles de pouvoir.", "choices": [{"label": "Toucher l'ecorce"}, {"label": "Grimper dans l'arbre"}, {"label": "Graver son nom"}]},
		{"title": "Le Conseil des Druides", "text": "Trois silhouettes encapuchonnees se tiennent en cercle autour d'un feu vert. Leurs chants s'elevent comme de la fumee. Ils semblent attendre quelqu'un.", "choices": [{"label": "Rejoindre le cercle"}, {"label": "Ecouter leurs chants"}, {"label": "Offrir du gui"}]},
		{"title": "La Danse des Korrigans", "text": "Des etres minuscules dansent en ronde dans une clairiere baignee de lune. Leurs rires tintent comme des clochettes. Le sol sous leurs pieds brille d'or.", "choices": [{"label": "Danser avec eux"}, {"label": "Voler une piece d'or"}, {"label": "Applaudir"}]},
		{"title": "Le Reflet de Niamh", "text": "Un lac immobile reflete un ciel qui n'est pas le votre. Une silhouette feminine se dessine sous la surface. Sa voix murmure des promesses de Tir na nOg.", "choices": [{"label": "Plonger la main"}, {"label": "Chanter pour elle"}, {"label": "Detourner le regard"}]},
		{"title": "La Stele des Anciens", "text": "Une pierre dressee porte des inscriptions dans une langue oubliee. Le vent qui la caresse produit un son grave et melodieux. Les ancetres parlent a travers elle.", "choices": [{"label": "Dechiffrer les signes"}, {"label": "Poser le front contre la pierre"}, {"label": "Graver une rune"}]},
		{"title": "L'Ombre de l'Ankou", "text": "Une charette grince dans le brouillard. Une silhouette haute et maigre la pousse lentement. Ses yeux sont des trous noirs dans un visage de craie. Il ne menace pas — il observe.", "choices": [{"label": "L'affronter du regard"}, {"label": "Offrir un objet"}, {"label": "Fuir dans la brume"}]},
	]
	# Shuffle based on encounter index for variety
	var idx: int = (enc_idx * 7 + 3) % fallback_cards.size()
	return fallback_cards[idx]


func _build_run_summary() -> Dictionary:
	var gm: Node = get_node_or_null("/root/GameManager")
	var life: int = 100
	var currency: int = 0
	if gm:
		var rs: Variant = gm.get("run_state") if gm.has_method("get") else null
		if rs is Dictionary:
			life = int(rs.get("life_essence", 100))
			currency = int(rs.get("biome_currency", 0))
	return {
		"biome": biome_key,
		"card_index": _encounter_count,
		"life_essence": life,
		"biome_currency": currency,
		"merlin_found": _merlin_found,
	}


func _on_run_complete() -> void:
	print("[Forest3D] Run complete — transitioning")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Tutorial mode: award fixed rewards, persist tutorial_completed, go to MenuPrincipal.
	if _is_tutorial:
		_finalize_tutorial_rewards()
		var pt2: Node = get_node_or_null("/root/PixelTransition")
		if pt2 and pt2.has_method("transition_to"):
			pt2.transition_to("res://scenes/MerlinCabinHub.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/MerlinCabinHub.tscn")
		return

	var reason: String = "completed"
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var rs: Variant = gm.get("run_state") if gm.has_method("get") else null
		if rs is Dictionary and int((rs as Dictionary).get("life_essence", 100)) <= 0:
			reason = "death"
	var gfc: Node = get_node_or_null("/root/GameFlow")
	if gfc and gfc.has_method("complete_run"):
		gfc.complete_run(reason, _build_run_summary())
	else:
		var pt: Node = get_node_or_null("/root/PixelTransition")
		if pt and pt.has_method("transition_to"):
			pt.transition_to("res://scenes/MerlinCabinHub.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/MerlinCabinHub.tscn")


func _spawn_floating_oghams() -> void:
	# Drift 14 ogham Sprite3D billboards along the path. They float upward slowly,
	# fade in/out, and respawn — adds atmosphere without competing with the dialogue.
	const OGHAM_GLYPHS: Array = ["ᚐ", "ᚁ", "ᚂ", "ᚃ", "ᚄ", "ᚅ", "ᚆ", "ᚇ", "ᚈ", "ᚉ", "ᚊ", "ᚋ"]
	if _path_points.is_empty():
		return
	for i in 14:
		var t: float = float(i) / 14.0
		var path_idx: int = clampi(int(t * float(_path_points.size() - 1)), 0, _path_points.size() - 1)
		var base: Vector3 = _path_points[path_idx]
		var ox: float = _rng.randf_range(-6.0, 6.0)
		var oz: float = _rng.randf_range(-4.0, 4.0)
		var oy: float = _rng.randf_range(1.2, 3.5)
		var lbl: Label3D = Label3D.new()
		lbl.text = String(OGHAM_GLYPHS[_rng.randi() % OGHAM_GLYPHS.size()])
		lbl.font_size = 64
		lbl.modulate = Color(1.0, 0.86, 0.45, 0.0)
		lbl.outline_modulate = Color(0.20, 0.14, 0.08, 0.0)
		lbl.outline_size = 4
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = false
		lbl.position = Vector3(base.x + ox, oy, base.z + oz)
		lbl.name = "FloatingOgham%d" % i
		forest_root.add_child(lbl)
		# Drift loop: fade in, rise + sway, fade out, repeat with new glyph + position.
		_animate_floating_ogham(lbl)


func _animate_floating_ogham(lbl: Label3D) -> void:
	if not is_instance_valid(lbl):
		return
	const OGHAM_GLYPHS_2: Array = ["ᚐ", "ᚁ", "ᚂ", "ᚃ", "ᚄ", "ᚅ", "ᚆ", "ᚇ", "ᚈ", "ᚉ", "ᚊ", "ᚋ"]
	var start_y: float = lbl.position.y
	var rise_amount: float = _rng.randf_range(1.4, 2.4)
	var dur_in: float = _rng.randf_range(2.0, 3.0)
	var dur_hold: float = _rng.randf_range(2.5, 4.0)
	var dur_out: float = _rng.randf_range(1.5, 2.5)
	var t_in: Tween = create_tween().set_parallel(true)
	t_in.tween_property(lbl, "modulate:a", 0.85, dur_in).set_trans(Tween.TRANS_SINE)
	t_in.tween_property(lbl, "outline_modulate:a", 0.7, dur_in).set_trans(Tween.TRANS_SINE)
	t_in.tween_property(lbl, "position:y", start_y + rise_amount * 0.6, dur_in + dur_hold).set_trans(Tween.TRANS_SINE)
	await t_in.finished
	if not is_instance_valid(lbl):
		return
	await get_tree().create_timer(dur_hold).timeout
	if not is_instance_valid(lbl):
		return
	var t_out: Tween = create_tween().set_parallel(true)
	t_out.tween_property(lbl, "modulate:a", 0.0, dur_out).set_trans(Tween.TRANS_SINE)
	t_out.tween_property(lbl, "outline_modulate:a", 0.0, dur_out).set_trans(Tween.TRANS_SINE)
	t_out.tween_property(lbl, "position:y", start_y + rise_amount, dur_out).set_trans(Tween.TRANS_SINE)
	await t_out.finished
	if not is_instance_valid(lbl) or _path_points.is_empty():
		return
	# Reset position + glyph and loop
	var new_idx: int = _rng.randi_range(0, _path_points.size() - 1)
	var new_base: Vector3 = _path_points[new_idx]
	lbl.position = Vector3(new_base.x + _rng.randf_range(-6.0, 6.0), _rng.randf_range(1.2, 3.5), new_base.z + _rng.randf_range(-4.0, 4.0))
	lbl.text = String(OGHAM_GLYPHS_2[_rng.randi() % OGHAM_GLYPHS_2.size()])
	_animate_floating_ogham(lbl)


func _finalize_tutorial_rewards() -> void:
	# Persist tutorial_completed + tutorial rewards to user://merlin_profile.json.
	# Idempotent: re-running the tutorial just bumps timestamp/anam.
	const TUTORIAL_ANAM_REWARD: int = 50
	var save_path := "user://merlin_profile.json"
	var data: Dictionary = {}
	if FileAccess.file_exists(save_path):
		var fr: FileAccess = FileAccess.open(save_path, FileAccess.READ)
		if fr:
			var raw: String = fr.get_as_text()
			fr.close()
			var json := JSON.new()
			if json.parse(raw) == OK and json.data is Dictionary:
				data = json.data as Dictionary
	var meta: Dictionary = data.get("meta", {}) as Dictionary
	meta["anam"] = int(meta.get("anam", 0)) + TUTORIAL_ANAM_REWARD
	meta["total_runs"] = int(meta.get("total_runs", 0)) + 1
	meta["tutorial_completed"] = true
	data["meta"] = meta
	data["tutorial_completed"] = true
	data["timestamp"] = int(Time.get_unix_time_from_system())
	var fw: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if fw:
		fw.store_string(JSON.stringify(data, "\t"))
		fw.close()
	print("[Forest3D] Tutorial rewards: +%d Anam, tutorial_completed=true" % TUTORIAL_ANAM_REWARD)


# ═══════════════════════════════════════════════════════════════════════════════
# TUTORIAL INTRO — Merlin VO + progressive asset reveal + quest parchment
# ═══════════════════════════════════════════════════════════════════════════════

const TUTORIAL_VO_LINES: Array[Dictionary] = [
	# Speak first, then trigger the effect (see docs/INTRO_TUTO_SEQUENCE.md).
	# Each phrase INTRODUCES what is about to appear.
	{"text": "...Voyageur. Tu es la, enfin.", "delay": 1.6, "phase": "black"},
	{"text": "Ferme les yeux. Je vais batir ce monde sous tes pas.", "delay": 1.8, "phase": "black"},
	{"text": "D'abord, le ciel. La voute sous laquelle nous marcherons.", "delay": 1.4, "phase": "sky"},
	{"text": "Maintenant la terre. Broceliande s'eveille pour t'accueillir.", "delay": 1.6, "phase": "forest"},
	{"text": "Voici la carte de ta quete. Regarde le chemin que je te trace.", "delay": 1.4, "phase": "parchment"},
	{"text": "Avance maintenant. Trois epreuves t'attendent — je serai a chaque carrefour.", "delay": 1.8, "phase": "walk"},
]


func _run_tutorial_intro() -> void:
	# Hide ENTIRE 3D world + all HUD + disable encounter pipeline. Reveal in sequence.
	# (Individual hides on forest_root/sun_light don't catch terrain ground or chunk meshes
	# that may be parented to world_root directly; hiding world_root is the catch-all.)
	if is_instance_valid(world_root):
		world_root.visible = false
	if is_instance_valid(player):
		player.visible = false
	if is_instance_valid(merlin_node):
		merlin_node.visible = false
	# Hide the full HUD CanvasLayer — the gameplay HUD must NOT show during reveal.
	var hud_node: Node = get_node_or_null("HUD")
	if hud_node and hud_node is CanvasLayer:
		(hud_node as CanvasLayer).visible = false
	# Hide encounter overlays, walk HUD, fauna bubbles, narrative VO — anything that
	# could compete with Merlin's narration. CanvasLayer.visible hides children too.
	for overlay_field in [_walk_event_overlay, _walk_hud, _merlin_whisper]:
		if is_instance_valid(overlay_field) and overlay_field is CanvasLayer:
			(overlay_field as CanvasLayer).visible = false
	# Disable encounter triggering during reveal (best-effort — methods may not exist).
	if _walk_event_controller and _walk_event_controller.has_method("set_active"):
		_walk_event_controller.set_active(false)
	if _autowalk and _autowalk.has_method("pause"):
		_autowalk.pause()
	print("[Forest3D] Tutorial intro: world+HUD+overlays hidden, encounter pipeline paused")
	# Save env state and switch to pure black background.
	var saved_bg_mode: int = -1
	var saved_bg_color: Color = Color(0, 0, 0)
	if is_instance_valid(world_env) and world_env.environment:
		saved_bg_mode = world_env.environment.background_mode
		saved_bg_color = world_env.environment.background_color
		world_env.environment.background_mode = Environment.BG_COLOR
		world_env.environment.background_color = Color(0.01, 0.01, 0.02)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# VO overlay (CanvasLayer with Label at bottom-center).
	var vo_layer: CanvasLayer = CanvasLayer.new()
	vo_layer.layer = 50
	add_child(vo_layer)

	var vo_panel: ColorRect = ColorRect.new()
	vo_panel.color = Color(0.0, 0.0, 0.0, 0.65)
	vo_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	vo_panel.offset_top = -120
	vo_panel.offset_left = 80
	vo_panel.offset_right = -80
	vo_panel.offset_bottom = -40
	vo_layer.add_child(vo_panel)

	var vo_label: Label = Label.new()
	vo_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	vo_label.add_theme_font_size_override("font_size", 24)
	vo_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	vo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vo_label.text = ""
	vo_panel.add_child(vo_label)

	# Run the scripted reveal sequence.
	# RULE: speak FIRST, then trigger the visual effect (one voice / one effect at a time).
	# See docs/INTRO_TUTO_SEQUENCE.md for the canonical timing.
	for entry in TUTORIAL_VO_LINES:
		if not is_inside_tree():
			return
		# 1) Merlin speaks the line completely (typewriter + hold).
		await _vo_speak_line(vo_label, String(entry.get("text", "")), float(entry.get("delay", 2.0)))
		if not is_inside_tree():
			return
		# 2) THEN the visual effect for this beat fires.
		var phase: String = String(entry.get("phase", "black"))
		match phase:
			"sky":
				# Restore env background (sky procedural) without revealing forest yet.
				if is_instance_valid(world_env) and world_env.environment and saved_bg_mode != -1:
					world_env.environment.background_mode = saved_bg_mode
					world_env.environment.background_color = saved_bg_color
				# Reveal world but keep forest hidden so only the sky shows.
				if is_instance_valid(world_root):
					world_root.visible = true
				if is_instance_valid(sun_light):
					sun_light.visible = true
				if is_instance_valid(forest_root):
					forest_root.visible = false  # hide forest until forest beat
				await get_tree().create_timer(0.6).timeout
			"forest":
				if is_instance_valid(forest_root):
					forest_root.visible = true
				await get_tree().create_timer(0.6).timeout
			"parchment":
				# VO label hidden during parchment (one focus at a time).
				vo_label.text = ""
				await _show_quest_parchment(vo_layer)
			"walk":
				if is_instance_valid(player):
					player.visible = true
				if is_instance_valid(merlin_node):
					merlin_node.visible = true
				# Re-show HUD + overlays + re-enable encounter pipeline + resume walker.
				var hud_show: Node = get_node_or_null("HUD")
				if hud_show and hud_show is CanvasLayer:
					(hud_show as CanvasLayer).visible = true
				for overlay_show in [_walk_event_overlay, _walk_hud, _merlin_whisper]:
					if is_instance_valid(overlay_show) and overlay_show is CanvasLayer:
						(overlay_show as CanvasLayer).visible = true
				if _walk_event_controller and _walk_event_controller.has_method("set_active"):
					_walk_event_controller.set_active(true)
				if _autowalk and _autowalk.has_method("resume"):
					_autowalk.resume()
				await get_tree().create_timer(0.4).timeout

	# Cleanup overlay then start the actual walk.
	if is_instance_valid(vo_layer):
		var fade_out: Tween = create_tween()
		fade_out.tween_property(vo_panel, "modulate:a", 0.0, 0.5)
		await fade_out.finished
		vo_layer.queue_free()
	# Camera is rail-only (no FPS look) + cursor visible (PC mode).
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_start_aerial_then_walk()


func _vo_speak_line(label: Label, text: String, hold_seconds: float) -> void:
	if not is_instance_valid(label):
		return
	# Typewriter effect, ~50 chars/s
	label.text = ""
	for i in range(text.length()):
		if not is_instance_valid(label) or not is_inside_tree():
			return
		label.text += text.substr(i, 1)
		await get_tree().create_timer(0.020).timeout
	if is_inside_tree():
		await get_tree().create_timer(hold_seconds).timeout


func _show_quest_parchment(vo_layer: CanvasLayer) -> void:
	# Parchment overlay with quest title, description, and an animated path drawn by Merlin.
	var parchment: PanelContainer = PanelContainer.new()
	parchment.set_anchors_preset(Control.PRESET_CENTER)
	parchment.custom_minimum_size = Vector2(720, 480)
	parchment.size = Vector2(720, 480)
	parchment.position = Vector2(-360, -240)
	parchment.modulate.a = 0.0
	vo_layer.add_child(parchment)

	var pstyle: StyleBoxFlat = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.92, 0.83, 0.65)  # cream parchment
	pstyle.border_color = Color(0.45, 0.30, 0.15)
	pstyle.set_border_width_all(3)
	pstyle.set_corner_radius_all(6)
	pstyle.content_margin_left = 32
	pstyle.content_margin_right = 32
	pstyle.content_margin_top = 28
	pstyle.content_margin_bottom = 28
	parchment.add_theme_stylebox_override("panel", pstyle)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	parchment.add_child(vbox)

	# Corner ornaments (4 celtic flourishes) + ink stains for old-paper feel
	for corner_data in [{"pos": Vector2(18, 12), "txt": "❦"}, {"pos": Vector2(680, 12), "txt": "❦"}, {"pos": Vector2(18, 444), "txt": "❦"}, {"pos": Vector2(680, 444), "txt": "❦"}]:
		var orn: Label = Label.new()
		orn.text = String(corner_data["txt"])
		orn.add_theme_font_size_override("font_size", 24)
		orn.add_theme_color_override("font_color", Color(0.45, 0.28, 0.12))
		orn.size = Vector2(24, 24)
		orn.position = corner_data["pos"] as Vector2
		parchment.add_child(orn)
	# Ink stains (faint dark blots scattered on the parchment)
	var stain_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	stain_rng.seed = 7
	for j in 6:
		var stain: ColorRect = ColorRect.new()
		stain.color = Color(0.30, 0.18, 0.08, 0.10 + stain_rng.randf() * 0.12)
		var sw: float = stain_rng.randf_range(8.0, 22.0)
		stain.size = Vector2(sw, sw * stain_rng.randf_range(0.5, 1.2))
		stain.position = Vector2(stain_rng.randf_range(40, 660), stain_rng.randf_range(40, 420))
		parchment.add_child(stain)

	var title: Label = Label.new()
	title.text = "✦ QUETE DE BROCELIANDE ✦"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.30, 0.18, 0.08))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	var desc: Label = Label.new()
	desc.text = "❧ Suis le chemin que je trace pour toi.\n❧ Trois epreuves jalonnent ta route — chaque X est un carrefour.\n❧ Tes pas restent graves : tu peux relire le chemin parcouru.\n❧ A chaque arret, j'ouvrirai une carte 3D — un test attend ton choix.\n❧ Ta vie est une essence : protege-la."
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Color(0.30, 0.20, 0.12))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Marauder's-Map style — animated footstep trail that wanders left to right.
	# Erratic offsets (Perlin-ish) instead of smooth sinusoid; footsteps remain visible.
	var path_holder: Control = Control.new()
	path_holder.custom_minimum_size = Vector2(640, 220)
	vbox.add_child(path_holder)

	# Faint dotted ink trail (the "drawn" line under the footsteps)
	var path_line: Line2D = Line2D.new()
	path_line.width = 2.0
	path_line.default_color = Color(0.22, 0.14, 0.08, 0.55)
	path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	path_holder.add_child(path_line)

	# Generate erratic footstep waypoints (left -> right with random walk in Y)
	var full_points: PackedVector2Array = PackedVector2Array()
	var segments: int = 200  # was 60 — much longer trail
	var rng_path: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_path.seed = 42
	var y_base: float = 110.0
	var y_drift: float = 0.0
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		# Slight rightward bias with random walk
		var x: float = 20.0 + t * 600.0 + rng_path.randf_range(-3.0, 3.0)
		# Random walk in Y, capped so it stays in the parchment
		y_drift += rng_path.randf_range(-3.5, 3.5)
		y_drift = clampf(y_drift, -55.0, 55.0)
		var y: float = y_base + y_drift + sin(t * TAU * 0.8 + rng_path.randf_range(-0.2, 0.2)) * 12.0
		full_points.append(Vector2(x, y))

	# Three encounter markers (X marks the spot — red ink)
	for marker_t in [0.25, 0.55, 0.85]:
		var marker_idx: int = int(float(segments) * float(marker_t))
		var marker: Label = Label.new()
		marker.text = "X"
		marker.add_theme_font_size_override("font_size", 22)
		marker.add_theme_color_override("font_color", Color(0.65, 0.18, 0.12))
		marker.size = Vector2(20, 22)
		marker.position = full_points[marker_idx] - Vector2(10, 14)
		marker.modulate.a = 0.0  # fade in when path reaches it
		marker.set_meta("appear_at_index", marker_idx)
		path_holder.add_child(marker)

	# Unfold parchment (scroll-style horizontal expansion + fade in)
	# Pivot at center so it expands left+right symmetrically.
	parchment.pivot_offset = parchment.size * 0.5
	parchment.scale = Vector2(0.04, 1.0)
	var unfold: Tween = create_tween().set_parallel(true)
	unfold.tween_property(parchment, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	unfold.tween_property(parchment, "scale", Vector2(1.0, 1.0), 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Subtle "settle" wobble at the end
	await unfold.finished
	var wobble: Tween = create_tween()
	wobble.tween_property(parchment, "scale", Vector2(1.02, 1.0), 0.12)
	wobble.tween_property(parchment, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_SINE)
	await wobble.finished

	# Draw progressively: every 4 path points, drop a footstep (alternating L/R foot offset).
	# Footsteps are tiny ovals (< or > shape via Label) that REMAIN visible — never freed.
	var footstep_step: int = 4
	var foot_alternate: int = 0
	for i in range(full_points.size()):
		if not is_instance_valid(path_line):
			return
		path_line.add_point(full_points[i])
		if i % footstep_step == 0:
			var foot: Label = Label.new()
			# Use a small bracket character as a footstep silhouette; alternate L/R
			foot.text = "<" if (foot_alternate % 2 == 0) else ">"
			foot.add_theme_font_size_override("font_size", 11)
			foot.add_theme_color_override("font_color", Color(0.22, 0.13, 0.07, 0.85))
			foot.size = Vector2(10, 12)
			# Offset perpendicular to the trail to imitate left/right foot
			var perp_offset: float = -3.0 if (foot_alternate % 2 == 0) else 3.0
			foot.position = full_points[i] + Vector2(-5, -6) + Vector2(0, perp_offset)
			# Slight rotation per footstep for organic feel
			foot.rotation = rng_path.randf_range(-0.3, 0.3)
			foot.modulate.a = 0.0
			path_holder.add_child(foot)
			# Fade-in the footstep so it "appears" rather than pops
			var foot_fade: Tween = create_tween()
			foot_fade.tween_property(foot, "modulate:a", 0.85, 0.18)
			foot_alternate += 1
		# Reveal X markers when the trail reaches them
		for child in path_holder.get_children():
			if child is Label and child.has_meta("appear_at_index") and child.modulate.a < 0.5:
				if i >= int(child.get_meta("appear_at_index")):
					var m_fade: Tween = create_tween()
					m_fade.tween_property(child, "modulate:a", 1.0, 0.25)
		await get_tree().create_timer(0.018).timeout

	# Wax seal stamp: appears at end of trail with a small "press" animation
	var seal: Label = Label.new()
	seal.text = "ᛗ"  # Mannaz rune as Merlin's signature
	seal.add_theme_font_size_override("font_size", 38)
	seal.add_theme_color_override("font_color", Color(0.65, 0.13, 0.10))
	seal.size = Vector2(48, 48)
	seal.position = full_points[full_points.size() - 1] + Vector2(8, -22)
	seal.scale = Vector2(0.1, 0.1)
	seal.modulate.a = 0.0
	path_holder.add_child(seal)
	# Halo behind the seal
	var halo: ColorRect = ColorRect.new()
	halo.color = Color(0.65, 0.13, 0.10, 0.18)
	halo.size = Vector2(60, 60)
	halo.position = full_points[full_points.size() - 1] + Vector2(2, -28)
	halo.modulate.a = 0.0
	path_holder.add_child(halo)
	var seal_anim: Tween = create_tween().set_parallel(true)
	seal_anim.tween_property(seal, "modulate:a", 1.0, 0.4)
	seal_anim.tween_property(seal, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	seal_anim.tween_property(halo, "modulate:a", 1.0, 0.6)
	await seal_anim.finished

	# Hold parchment for reading the full map (footsteps remain — the "Maraudeurs" effect)
	await get_tree().create_timer(3.5).timeout

	# Fade out + free
	var fade_out: Tween = create_tween()
	fade_out.tween_property(parchment, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	await fade_out.finished
	if is_instance_valid(parchment):
		parchment.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# TUTORIAL CARDS — 3 scripted encounters (idx 0, 1, 2), no LLM
# ═══════════════════════════════════════════════════════════════════════════════

const TUTORIAL_CARDS: Array[Dictionary] = [
	{
		"title": "Le Premier Souffle",
		"text": "Le sentier s'ouvre devant toi. Une brume legere caresse les fougeres. Une voix murmure : choisis comment tu avances dans ce monde.",
		"choices": [
			{"label": "Avancer en silence"},
			{"label": "Saluer la foret"},
			{"label": "Observer chaque ombre"},
		],
	},
	{
		"title": "Le Carrefour des Eaux",
		"text": "Un ruisseau coupe le chemin. Une pierre plate sert de pont. Tes paumes ressentent la fraicheur de l'air humide. Que fais-tu ?",
		"choices": [
			{"label": "Boire une gorgee"},
			{"label": "Traverser sans m'arreter"},
			{"label": "Ecouter le chant de l'eau"},
		],
	},
	{
		"title": "Le Seuil de Merlin",
		"text": "Une arche de branches entrelacees marque la fin du sentier. Au-dela, une lumiere doree. Tu es au seuil. Comment franchis-tu le passage ?",
		"choices": [
			{"label": "Avec confiance"},
			{"label": "Avec humilite"},
			{"label": "Avec curiosite"},
		],
	},
]


func _get_tutorial_card(enc_idx: int) -> Dictionary:
	# Wrap index for safety; tutorial has exactly 3 cards.
	var idx: int = clampi(enc_idx, 0, TUTORIAL_CARDS.size() - 1)
	return TUTORIAL_CARDS[idx]


func _on_hub() -> void:
	var gfc: Node = get_node_or_null("/root/GameFlow")
	if gfc:
		if _merlin_found and gfc.has_method("enter_card_game"):
			gfc.enter_card_game()
		elif gfc.has_method("return_to_hub"):
			gfc.return_to_hub()
		return
	var target: String = GAME_SCENE if _merlin_found else HUB_SCENE
	var pt: Node = get_node_or_null("/root/PixelTransition")
	if pt and pt.has_method("transition_to"):
		pt.transition_to(target)
	else:
		get_tree().change_scene_to_file(target)
