extends Node
## BroceliandeForest3D v3
## Marche contemplative FPS — Foret de Broceliande.
## 7 zones, assets GLB reels, effets volumetriques, cycle jour/nuit, saisons.

signal merlin_encounter_complete  # Emitted when Merlin found → ready for MerlinGame

const HUB_SCENE: String = "res://scenes/HubAntre.tscn"
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
@export var head_bob_amount: float = 0.015
@export var head_bob_speed: float = 5.0

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
var _gameplay_active: bool = false  # true when LLM event system is wired
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
	_glb_placer = GlbAssetPlacerClass.new()
	_glb_placer.place_assets(forest_root, _zone_centers, _rng)
	# _populate_forest() removed — chunk manager handles vegetation
	_spawn_merlin()
	_effects = ForestEffectsClass.new(forest_root, _zone_centers, _rng)
	_effects.add_fog_particles()
	_effects.add_pollen_particles()
	_effects.add_fireflies()
	_effects.add_god_rays()
	_effects.add_falling_leaves()
	_effects.add_ground_mist()
	_init_helpers()

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

	# Procedural ground detail (rocks + grass patches) along path
	_spawn_ground_details()

	_wire_buttons()
	_update_hud()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Book cinematic is now shown in MerlinCabinHub BEFORE entering forest
	# Forest starts directly with aerial descent → auto-walk
	_start_aerial_then_walk()


func _init_helpers() -> void:
	# Auto-walk controller with encounter stops
	_autowalk = BrocAutowalk.new(_path_points, player, player_head, player_camera, _zone_centers)
	# Set encounter stops every ~15 waypoints (5 encounters per run)
	var total_wp: int = _path_points.size()
	var enc_spacing: int = maxi(total_wp / 6, 5)
	var enc_indices: Array[int] = []
	for i in range(enc_spacing, total_wp - enc_spacing, enc_spacing):
		enc_indices.append(i)
	_autowalk.set_encounters(enc_indices, _on_encounter_reached)
	_autowalk.set_run_complete_callback(_on_run_complete)

	# Procedural chunk manager (replaces dense_fill + mass_fill + extra_decor)
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
	# Walk HUD (PV, Souffle, Essences) — CanvasLayer above viewport
	_walk_hud = WalkHudClass.new()
	add_child(_walk_hud)

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
	if event is InputEventMouseMotion:
		var overlay_blocking: bool = _walk_event_overlay and _walk_event_overlay.is_active()
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED or _merlin_found or overlay_blocking:
			return
		var m: InputEventMouseMotion = event as InputEventMouseMotion
		player.rotate_y(-m.relative.x * mouse_sensitivity)
		_pitch = clamp(_pitch - m.relative.y * mouse_sensitivity, deg_to_rad(-45.0), deg_to_rad(30.0))
		player_head.rotation.x = _pitch


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
	var retro_shader: Shader = load("res://resources/shaders/retro_screen.gdshader") as Shader
	if retro_shader:
		_retro_material = ShaderMaterial.new()
		_retro_material.shader = retro_shader
		_retro_material.set_shader_parameter("render_size", Vector2(render_w, render_h))
		_retro_material.set_shader_parameter("screen_size", Vector2(1280.0, 720.0))
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
			var run: Dictionary = store.get("run_state") as Dictionary if store.has_method("get") else {}
			var life: int = int(run.get("life_essence", 100))
			_walk_hud.update_pv(life, 100)
			var essences: int = int(run.get("biome_currency", 0))
			_walk_hud.update_essences(essences)
		# Default ogham (Beith starter)
		if _walk_hud.has_method("update_ogham"):
			_walk_hud.update_ogham("\u1681", "Beith", 0)
		# Faction indicators from MerlinStore
		var merlin_store: Node = _find_store()
		if merlin_store and _walk_hud.has_method("update_factions"):
			var state_v: Variant = merlin_store.get("state")
			if state_v is Dictionary:
				var factions: Dictionary = (state_v as Dictionary).get("factions", {})
				if not factions.is_empty():
					_walk_hud.update_factions(factions)

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
	print("[Forest3D] Encounter %d — showing card overlay" % enc_idx)

	# Brief anticipation — show text before card popup
	if is_instance_valid(objective_label):
		objective_label.text = "Une presence dans la brume..."
	if is_instance_valid(status_label):
		status_label.text = "Rencontre %d / 5" % (enc_idx + 1)

	# SFX: mysterious chime
	if is_instance_valid(SFXManager):
		SFXManager.play("encounter")

	# Brief dramatic pause (1.5s) — player sees the forest freeze
	await get_tree().create_timer(1.5).timeout

	# Release mouse for UI interaction
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Update HUD card counter
	if _walk_hud and _walk_hud.has_method("update_cards"):
		_walk_hud.update_cards(enc_idx + 1, 5)

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
		if _walk_hud and _walk_hud.has_method("flash_life_change") and life_change != 0:
			_walk_hud.flash_life_change(life_change)
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
		if _autowalk:
			_autowalk.resume_after_encounter()
	)


func _get_encounter_card(enc_idx: int) -> Dictionary:
	# Try LLM via MerlinAI (Groq cloud in web export)
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


## Run complete — path ended, show end-run stats overlay
func _on_run_complete() -> void:
	print("[Forest3D] Run complete — showing end stats")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var end_overlay: CanvasLayer = CanvasLayer.new()
	end_overlay.layer = 18
	add_child(end_overlay)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.02, 0.0, 0.0)
	end_overlay.add_child(bg)
	var tw: Tween = create_tween()
	tw.tween_property(bg, "color:a", 0.9, 1.0)

	var font: Font = MerlinVisual.get_font("terminal") if is_instance_valid(MerlinVisual) else null
	var pal: Dictionary = MerlinVisual.CRT_PALETTE if is_instance_valid(MerlinVisual) else {}

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.anchor_left = 0.2; vbox.anchor_right = 0.8
	vbox.anchor_top = 0.15; vbox.anchor_bottom = 0.85
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	end_overlay.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Fin du Voyage"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font: title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", pal.get("amber", Color(1.0, 0.75, 0.2)))
	vbox.add_child(title)

	var stats: Label = Label.new()
	stats.text = "Rencontres: 5\nBiome: Broceliande\nSaison: Printemps"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font: stats.add_theme_font_override("font", font)
	stats.add_theme_font_size_override("font_size", 18)
	stats.add_theme_color_override("font_color", pal.get("phosphor", Color(0.2, 1.0, 0.4)))
	vbox.add_child(stats)

	var btn_menu: Button = Button.new()
	btn_menu.text = "Retour au Menu"
	btn_menu.custom_minimum_size = Vector2(0, 48)
	btn_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font: btn_menu.add_theme_font_override("font", font)
	btn_menu.add_theme_font_size_override("font_size", 20)
	btn_menu.add_theme_color_override("font_color", pal.get("phosphor", Color(0.2, 1.0, 0.4)))
	var btn_s: StyleBoxFlat = StyleBoxFlat.new()
	btn_s.bg_color = Color(0.02, 0.04, 0.02, 0.8)
	btn_s.border_color = pal.get("phosphor_dim", Color(0.12, 0.60, 0.24))
	btn_s.set_border_width_all(1)
	btn_s.set_corner_radius_all(4)
	btn_s.set_content_margin_all(10)
	btn_menu.add_theme_stylebox_override("normal", btn_s)
	btn_menu.pressed.connect(func():
		var pt: Node = get_node_or_null("/root/PixelTransition")
		if pt and pt.has_method("transition_to"):
			pt.transition_to("res://scenes/HubAntre.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/HubAntre.tscn")
	)
	vbox.add_child(btn_menu)


func _on_hub() -> void:
	# After forest walk, go to MerlinGame (card encounters)
	var target: String = GAME_SCENE if _merlin_found else HUB_SCENE
	var pt: Node = get_node_or_null("/root/PixelTransition")
	if pt and pt.has_method("transition_to"):
		pt.transition_to(target)
	else:
		get_tree().change_scene_to_file(target)
