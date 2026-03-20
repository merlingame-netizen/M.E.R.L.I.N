extends Node
## BroceliandeForest3D v3
## Marche contemplative FPS — Foret de Broceliande.
## 7 zones, assets GLB reels, effets volumetriques, cycle jour/nuit, saisons.

const HUB_SCENE: String = "res://scenes/HubAntre.tscn"

# --- Helper modules ---
const BrocAutowalk = preload("res://scripts/broceliande_3d/broc_autowalk.gd")
const BrocDayNight = preload("res://scripts/broceliande_3d/broc_day_night.gd")
const BrocSeason = preload("res://scripts/broceliande_3d/broc_season.gd")
const BrocGrassWind = preload("res://scripts/broceliande_3d/broc_grass_wind.gd")
const BrocAtmosphere = preload("res://scripts/broceliande_3d/broc_atmosphere.gd")
# Deprecated: BrocDenseFill, BrocExtraDecor, BrocMassFill — replaced by BrocChunkManager
const BrocChunkManager = preload("res://scripts/broceliande_3d/broc_chunk_manager.gd")
const BrocEvents = preload("res://scripts/broceliande_3d/broc_events.gd")
const BrocEventVfxClass = preload("res://scripts/broceliande_3d/broc_event_vfx.gd")
const WalkEventControllerClass = preload("res://scripts/broceliande_3d/walk_event_controller.gd")
const WalkEventOverlayClass = preload("res://scripts/ui/walk_event_overlay.gd")
const WalkHudClass = preload("res://scripts/ui/walk_hud.gd")
const BrocScreenVfxClass = preload("res://scripts/broceliande_3d/broc_screen_vfx.gd")
const BrocCreatureSpawnerClass = preload("res://scripts/broceliande_3d/broc_creature_spawner.gd")
const BrocNarrativeDirectorClass = preload("res://scripts/broceliande_3d/broc_narrative_director.gd")
const ForestAssetSpawnerClass = preload("res://scripts/broceliande_3d/forest_asset_spawner.gd")
const ForestZoneBuilderClass = preload("res://scripts/broceliande_3d/forest_zone_builder.gd")
const ForestEffectsClass = preload("res://scripts/broceliande_3d/forest_effects.gd")
const ForestMerlinNpcClass = preload("res://scripts/broceliande_3d/forest_merlin_npc.gd")
const ForestTerrainBuilderClass = preload("res://scripts/broceliande_3d/forest_terrain_builder.gd")

# --- Input ---
const ACT_FWD: StringName = &"broc_move_forward"
const ACT_BACK: StringName = &"broc_move_back"
const ACT_LEFT: StringName = &"broc_move_left"
const ACT_RIGHT: StringName = &"broc_move_right"
const ACT_INTERACT: StringName = &"broc_interact"
const ACT_MOUSE: StringName = &"broc_toggle_mouse"

# --- GLB asset paths ---
const TREE_MODELS: Array[String] = [
	"res://Assets/3d_models/vegetation/01_Tree_Small.glb",
	"res://Assets/3d_models/vegetation/02_Tree_Medium.glb",
	"res://Assets/3d_models/vegetation/03_Tree_Large.glb",
	"res://Assets/3d_models/vegetation/04_Pine.glb",
	"res://Assets/3d_models/vegetation/05_Cypress.glb",
	"res://Assets/3d_models/vegetation/06_Thuya.glb",
	"res://Assets/3d_models/vegetation/29_Birch.glb",
]

const SPECIAL_TREES: Dictionary = {
	"old_oak": "res://Assets/3d_models/vegetation/08_OldOak_Merlin.glb",
	"golden": "res://Assets/3d_models/vegetation/09_GoldenTree_Sacred.glb",
	"spiral": "res://Assets/3d_models/vegetation/10_SpiralTree_Mystic.glb",
	"willow": "res://Assets/3d_models/vegetation/11_Willow_Enchanted.glb",
	"silver": "res://Assets/3d_models/vegetation/12_SilverTree_Moon.glb",
	"dead": "res://Assets/3d_models/vegetation/28_Tree_Dead.glb",
}

const BUSH_MODELS: Array[String] = [
	"res://Assets/3d_models/vegetation/07_Bush.glb",
	"res://Assets/3d_models/vegetation/26_Bush_Flower.glb",
	"res://Assets/3d_models/vegetation/27_Bush_Thick.glb",
]

const DETAIL_MODELS: Dictionary = {
	"fern": "res://Assets/3d_models/vegetation/16_Fern.glb",
	"grass_tall": "res://Assets/3d_models/vegetation/17_Grass_Tall.glb",
	"grass_short": "res://Assets/3d_models/vegetation/18_Grass_Short.glb",
	"mushroom_red": "res://Assets/3d_models/vegetation/19_Mushroom_Red.glb",
	"mushroom_group": "res://Assets/3d_models/vegetation/20_Mushroom_Group.glb",
	"rock_small": "res://Assets/3d_models/vegetation/21_Rock_Small.glb",
	"rock_medium": "res://Assets/3d_models/vegetation/22_Rock_Medium.glb",
	"rock_group": "res://Assets/3d_models/vegetation/23_Rock_Group.glb",
	"daisy": "res://Assets/3d_models/vegetation/25_Daisy.glb",
	"lily_pink": "res://Assets/3d_models/vegetation/13_LilyPad_Pink.glb",
	"lily_white": "res://Assets/3d_models/vegetation/15_LilyPad_White.glb",
	"cattail": "res://Assets/3d_models/vegetation/24_Cattail.glb",
}

# --- Broceliande 3D assets (TripoSR generated) ---
const BROC_ASSETS: Dictionary = {
	# Megaliths
	"dolmen": "res://Assets/3d_models/broceliande/megaliths/dolmen_01.glb",
	"menhir_01": "res://Assets/3d_models/broceliande/megaliths/menhir_01.glb",
	"menhir_02": "res://Assets/3d_models/broceliande/megaliths/menhir_02_ogham.glb",
	"stone_circle": "res://Assets/3d_models/broceliande/megaliths/stone_circle.glb",
	# Structures
	"bridge_wood": "res://Assets/3d_models/broceliande/structures/bridge_wood.glb",
	"root_arch": "res://Assets/3d_models/broceliande/structures/root_arch.glb",
	"fairy_lantern": "res://Assets/3d_models/broceliande/structures/fairy_lantern.glb",
	"druid_altar": "res://Assets/3d_models/broceliande/structures/druid_altar.glb",
	# POI
	"fountain_barenton": "res://Assets/3d_models/broceliande/poi/fountain_barenton.glb",
	"merlin_tomb": "res://Assets/3d_models/broceliande/poi/merlin_tomb.glb",
	"merlin_oak": "res://Assets/3d_models/broceliande/poi/merlin_oak.glb",
	# Creatures (disabled — GLBs need GUI editor reimport)
	# "korrigan": "res://Assets/3d_models/broceliande/creatures/korrigan.glb",
	# "white_doe": "res://Assets/3d_models/broceliande/creatures/white_doe.glb",
	# "mist_wolf": "res://Assets/3d_models/broceliande/creatures/mist_wolf.glb",
	# "giant_raven": "res://Assets/3d_models/broceliande/creatures/giant_raven.glb",
	# Decor
	"fallen_trunk": "res://Assets/3d_models/broceliande/decor/fallen_trunk.glb",
	"giant_mushroom": "res://Assets/3d_models/broceliande/decor/giant_mushroom.glb",
	"root_network": "res://Assets/3d_models/broceliande/decor/root_network.glb",
	"spider_web": "res://Assets/3d_models/broceliande/decor/spider_web.glb",
	"giant_stump": "res://Assets/3d_models/broceliande/decor/giant_stump.glb",
}


# --- Exports ---
@export var low_pixel_height: int = 320
@export var move_speed: float = 3.5
@export var mouse_sensitivity: float = 0.0026
@export var interact_distance: float = 2.8
@export var head_bob_amount: float = 0.04
@export var head_bob_speed: float = 8.0

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
var _events: RefCounted
var _chunk_manager: RefCounted

# New gameplay systems (LLM events + HUD)
var _walk_event_overlay: Node  # WalkEventOverlay (CanvasLayer)
var _walk_hud: Node  # WalkHUD (CanvasLayer)
var _walk_event_controller: RefCounted  # WalkEventController
var _event_vfx: RefCounted  # BrocEventVfx
var _screen_vfx: RefCounted  # BrocScreenVfx
var _creature_spawner: RefCounted  # BrocCreatureSpawner
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

var _path_points: PackedVector3Array = PackedVector3Array()
var _zone_centers: Array[Vector3] = []
var _zone_names: Array[String] = [
	"La Lisiere", "La Foret Dense", "Le Dolmen",
	"La Mare Enchantee", "La Foret Profonde",
	"La Fontaine de Barenton", "Le Cercle de Pierres",
]


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
	_terrain_builder = ForestTerrainBuilderClass.new(world_root, forest_root, _zone_centers, _path_points, _rng, _asset_spawner)
	_terrain_builder.build_ground()
	_terrain_builder.build_path_terrain()
	_zone_builder = ForestZoneBuilderClass.new(_asset_spawner, forest_root, _zone_centers, _rng)
	_zone_builder.build_zones()
	# _populate_forest() removed — chunk manager handles vegetation
	_spawn_merlin()
	_effects = ForestEffectsClass.new(forest_root, _zone_centers, _rng)
	_effects.add_fog_particles()
	_effects.add_pollen_particles()
	_effects.add_fireflies()
	_effects.add_god_rays()
	_init_helpers()
	_wire_buttons()
	_update_hud()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _init_helpers() -> void:
	# Auto-walk controller
	_autowalk = BrocAutowalk.new(_path_points, player, player_head, player_camera, _zone_centers)

	# Procedural chunk manager (replaces dense_fill + mass_fill + extra_decor)
	_chunk_manager = BrocChunkManager.new()
	_chunk_manager.setup(
		forest_root, _asset_spawner.tree_scenes, _asset_spawner.bush_scenes,
		_asset_spawner.special_scenes, _asset_spawner.detail_scenes, _asset_spawner.broc_scenes,
		_zone_centers, _path_points)
	_chunk_manager.generate_initial(player.position.z)

	# Day/night cycle
	_day_night = BrocDayNight.new(sun_light, world_env)

	# Season system (overlay on top of this Control)
	_season = BrocSeason.new(forest_root, self)

	# Wind-blown grass (along path borders)
	var grass_tall: PackedScene = _asset_spawner.detail_scenes.get("grass_tall") as PackedScene
	var grass_short: PackedScene = _asset_spawner.detail_scenes.get("grass_short") as PackedScene
	if grass_tall or grass_short:
		_grass_wind = BrocGrassWind.new(forest_root, _path_points, _zone_centers, grass_tall, grass_short)

	# Enhanced atmosphere (zone-aware fog)
	_atmosphere = BrocAtmosphere.new(forest_root, _zone_centers)
	_atmosphere.set_environment(world_env.environment)

	# Screen VFX (shake, flash, glitch, vignette)
	_screen_vfx = BrocScreenVfxClass.new()
	_screen_vfx.setup(null, self, forest_root)

	# Billboard creatures
	_creature_spawner = BrocCreatureSpawnerClass.new(forest_root)

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


func _notification(_what: int) -> void:
	pass  # NOTIFICATION_RESIZED no longer needed — no SubViewport pixel shrink


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
			player_camera.position.x = cos(_head_bob_time * 0.5) * head_bob_amount * 0.5
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


# ============================================================
# VIEWPORT / ENVIRONMENT
# ============================================================

func _setup_viewport() -> void:
	pass  # No SubViewport — Camera3D renders directly to main viewport


func _setup_environment() -> void:
	var env: Environment = Environment.new()

	# GL Compatibility: ProceduralSkyMaterial renders white regardless of BG_COLOR mode.
	# Remove sky entirely — ambient light comes from AMBIENT_SOURCE_COLOR below.
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.40, 0.28)  # Forest canopy — muted green

	# Ambient — strong enough to light dark CRT-style materials
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.65, 0.45)
	env.ambient_light_energy = 0.9

	# Fog — forest mist
	env.fog_enabled = true
	env.fog_light_color = Color(0.35, 0.45, 0.32)
	env.fog_density = 0.018
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
	sun_light.light_energy = 1.8
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


func _setup_player() -> void:
	player.position = Vector3(0.0, 1.2, 2.0) if _path_points.is_empty() else _path_points[0] + Vector3(0.0, 1.2, 0.0)
	player.rotation = Vector3.ZERO
	player_head.rotation = Vector3(deg_to_rad(-5.0), 0.0, 0.0)
	_pitch = deg_to_rad(-5.0)
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
	status_label.text = "Le druide ouvre un passage vers son Antre."
	zone_label.text = "Le Cercle de Pierres — Rencontre"
	result_text.text = "Au centre du cercle millenaire,\nMerlin se revele dans un halo bleu.\n\nLe chemin mystique est ouvert."
	result_panel.visible = true
	crosshair.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


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


func _on_hub() -> void:
	get_tree().change_scene_to_file(HUB_SCENE)
