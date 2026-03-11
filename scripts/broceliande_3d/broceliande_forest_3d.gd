extends Control
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

# --- Merlin pixel rig ---
const MERLIN_PX: float = 0.12
const MERLIN_GRID: Array = [
	[0,0,0,0,0,0,0,6,0,0,0,0],
	[0,0,0,0,0,0,1,1,0,0,0,0],
	[0,0,0,0,0,1,1,1,1,0,0,0],
	[0,0,0,0,1,1,1,2,2,0,0,0],
	[0,0,0,1,1,1,2,2,2,2,0,0],
	[0,5,5,5,5,5,5,5,5,5,5,0],
	[0,0,3,3,4,4,4,4,3,3,0,0],
	[0,0,3,7,4,4,4,7,3,3,0,0],
	[0,0,3,3,4,3,3,3,3,3,0,0],
	[0,0,0,3,3,3,3,3,3,0,0,0],
	[0,0,0,0,3,3,3,3,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0],
]
const MERLIN_COLORS: Dictionary = {
	1: Color(0.07, 0.12, 0.29), 2: Color(0.12, 0.20, 0.42),
	3: Color(0.04, 0.05, 0.08), 4: Color(0.14, 0.15, 0.20),
	5: Color(0.03, 0.04, 0.06), 6: Color(0.34, 0.72, 1.0),
	7: Color(0.40, 0.84, 1.0),
}

# --- Exports ---
@export var low_pixel_height: int = 320
@export var move_speed: float = 3.5
@export var mouse_sensitivity: float = 0.0026
@export var interact_distance: float = 2.8
@export var head_bob_amount: float = 0.04
@export var head_bob_speed: float = 8.0

# --- Scene refs ---
@onready var viewport_container: SubViewportContainer = $ViewportContainer
@onready var game_viewport: SubViewport = $ViewportContainer/GameViewport
@onready var world_root: Node3D = $ViewportContainer/GameViewport/World3D
@onready var world_env: WorldEnvironment = $ViewportContainer/GameViewport/World3D/WorldEnvironment
@onready var sun_light: DirectionalLight3D = $ViewportContainer/GameViewport/World3D/SunLight
@onready var forest_root: Node3D = $ViewportContainer/GameViewport/World3D/ForestRoot
@onready var merlin_node: Node3D = $ViewportContainer/GameViewport/World3D/Merlin
@onready var player: CharacterBody3D = $ViewportContainer/GameViewport/World3D/Player
@onready var player_collision: CollisionShape3D = $ViewportContainer/GameViewport/World3D/Player/CollisionShape3D
@onready var player_head: Node3D = $ViewportContainer/GameViewport/World3D/Player/Head
@onready var player_camera: Camera3D = $ViewportContainer/GameViewport/World3D/Player/Head/Camera3D
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
var _merlin_float_time: float = 0.0
var _merlin_pixel_rig: Node3D
var _merlin_orb_light: OmniLight3D
var _current_zone: int = 0
var _event_text: String = ""
var _event_text_timer: float = 0.0
var _head_bob_time: float = 0.0
var _time: float = 0.0

# Loaded scene caches
var _tree_scenes: Array[PackedScene] = []
var _bush_scenes: Array[PackedScene] = []
var _special_scenes: Dictionary = {}
var _detail_scenes: Dictionary = {}
var _broc_scenes: Dictionary = {}

# Swaying trees tracking
var _sway_nodes: Array[Node3D] = []

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

# Particle refs for day/night modulation
var _pollen_node: GPUParticles3D
var _firefly_nodes: Array[GPUParticles3D] = []

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
	# Hide CRT post-process entirely (screen_texture incompatible with SubViewport in GL Compat)
	var crt_layer: Node = get_node_or_null("/root/ScreenDither")
	if crt_layer:
		if crt_layer.has_method("get_crt_preset"):
			_saved_crt_preset = crt_layer.get_crt_preset()
		if crt_layer.has_method("set_enabled"):
			crt_layer.set_enabled(false)
	_load_assets()
	_ensure_actions()
	_setup_viewport()
	_setup_environment()
	_generate_path()
	_setup_player()
	_build_ground()
	_build_path_terrain()
	_build_zones()  # POIs, megaliths, zone-specific decor (kept)
	# _populate_forest() removed — chunk manager handles vegetation
	_spawn_merlin()
	_add_fog_particles()
	_add_pollen_particles()
	_add_fireflies()
	_add_god_rays()
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
		forest_root, _tree_scenes, _bush_scenes,
		_special_scenes, _detail_scenes, _broc_scenes,
		_zone_centers, _path_points)
	_chunk_manager.generate_initial(player.position.z)

	# Day/night cycle
	_day_night = BrocDayNight.new(sun_light, world_env)

	# Season system (overlay on top of this Control)
	_season = BrocSeason.new(forest_root, self)

	# Wind-blown grass (along path borders)
	var grass_tall: PackedScene = _detail_scenes.get("grass_tall") as PackedScene
	var grass_short: PackedScene = _detail_scenes.get("grass_short") as PackedScene
	if grass_tall or grass_short:
		_grass_wind = BrocGrassWind.new(forest_root, _path_points, _zone_centers, grass_tall, grass_short)

	# Enhanced atmosphere (zone-aware fog)
	_atmosphere = BrocAtmosphere.new(forest_root, _zone_centers)
	_atmosphere.set_environment(world_env.environment)

	# Screen VFX (shake, flash, glitch, vignette)
	_screen_vfx = BrocScreenVfxClass.new()
	_screen_vfx.setup(viewport_container, self, forest_root)

	# Billboard creatures
	_creature_spawner = BrocCreatureSpawnerClass.new(forest_root)

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

	# VFX system (keyword → 3D effects)
	_event_vfx = BrocEventVfxClass.new(forest_root, world_env, sun_light)

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


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_pixel_shrink()


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Restore CRT post-process for other scenes
	var crt_layer: Node = get_node_or_null("/root/ScreenDither")
	if crt_layer:
		if crt_layer.has_method("set_enabled"):
			crt_layer.set_enabled(true)
		if crt_layer.has_method("set_crt_preset"):
			crt_layer.set_crt_preset(_saved_crt_preset)


# ============================================================
# ASSET LOADING
# ============================================================

func _load_assets() -> void:
	for path in TREE_MODELS:
		var scene: PackedScene = _try_load(path)
		if scene:
			_tree_scenes.append(scene)

	for path in BUSH_MODELS:
		var scene: PackedScene = _try_load(path)
		if scene:
			_bush_scenes.append(scene)

	for key in SPECIAL_TREES:
		var scene: PackedScene = _try_load(SPECIAL_TREES[key])
		if scene:
			_special_scenes[key] = scene

	for key in DETAIL_MODELS:
		var scene: PackedScene = _try_load(DETAIL_MODELS[key])
		if scene:
			_detail_scenes[key] = scene

	for key in BROC_ASSETS:
		var scene: PackedScene = _try_load(BROC_ASSETS[key])
		if scene:
			_broc_scenes[key] = scene
	print("[Broceliande] Loaded %d/%d GLB assets" % [_broc_scenes.size(), BROC_ASSETS.size()])


func _try_load(path: String) -> PackedScene:
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	return null


func _spawn_glb(scene: PackedScene, pos: Vector3, scale_f: float = 1.0, rot_y: float = -1.0, vis_range: float = 0.0) -> Node3D:
	var instance: Node3D = scene.instantiate() as Node3D
	instance.position = pos
	instance.scale = Vector3.ONE * scale_f
	if rot_y < 0.0:
		instance.rotation_degrees.y = _rng.randf_range(0.0, 360.0)
	else:
		instance.rotation_degrees.y = rot_y
	if vis_range > 0.0:
		_apply_lod(instance, vis_range)
	forest_root.add_child(instance)
	return instance


func _apply_lod(node: Node3D, range_end: float) -> void:
	if node is GeometryInstance3D:
		node.visibility_range_end = range_end
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for child in node.get_children():
		if child is Node3D:
			_apply_lod(child as Node3D, range_end)


func _spawn_random_tree(pos: Vector3, scale_f: float = 1.0) -> Node3D:
	if _tree_scenes.is_empty():
		return _create_fallback_tree(pos, scale_f)
	var scene: PackedScene = _tree_scenes[_rng.randi_range(0, _tree_scenes.size() - 1)]
	var node: Node3D = _spawn_glb(scene, pos, scale_f, -1.0, 60.0)
	_sway_nodes.append(node)
	return node


func _spawn_random_bush(pos: Vector3, scale_f: float = 1.0) -> Node3D:
	if _bush_scenes.is_empty():
		return _create_fallback_shrub(pos, scale_f)
	var scene: PackedScene = _bush_scenes[_rng.randi_range(0, _bush_scenes.size() - 1)]
	return _spawn_glb(scene, pos, scale_f, -1.0, 40.0)


func _spawn_special(key: String, pos: Vector3, scale_f: float = 1.0) -> Node3D:
	if _special_scenes.has(key):
		var node: Node3D = _spawn_glb(_special_scenes[key], pos, scale_f, -1.0, 60.0)
		_sway_nodes.append(node)
		return node
	return _create_fallback_tree(pos, scale_f)


func _spawn_detail(key: String, pos: Vector3, scale_f: float = 1.0) -> Node3D:
	if _detail_scenes.has(key):
		return _spawn_glb(_detail_scenes[key], pos, scale_f, -1.0, 25.0)
	return null


func _spawn_broc(key: String, pos: Vector3, scale_f: float = 1.0, rot_y: float = -1.0) -> Node3D:
	if _broc_scenes.has(key):
		return _spawn_glb(_broc_scenes[key], pos, scale_f, rot_y, 70.0)
	push_warning("[Broceliande] Missing asset: %s" % key)
	return null


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
		for ff in _firefly_nodes:
			if is_instance_valid(ff):
				ff.amount_ratio = 1.0 if is_night else 0.15
		# Pollen only during daytime
		if _pollen_node and is_instance_valid(_pollen_node):
			_pollen_node.amount_ratio = 0.0 if is_night else 1.0

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

	_update_merlin_visual(delta)
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
	viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_update_pixel_shrink()


func _update_pixel_shrink() -> void:
	var sy: float = get_viewport_rect().size.y
	if sy < 1.0:
		return
	viewport_container.stretch_shrink = max(int(round(sy / max(1.0, float(low_pixel_height)))), 1)


func _setup_environment() -> void:
	var env: Environment = Environment.new()

	# Sky — procedural sky with forest atmosphere
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.55, 0.75)
	sky_mat.sky_horizon_color = Color(0.55, 0.65, 0.55)
	sky_mat.ground_bottom_color = Color(0.12, 0.18, 0.10)
	sky_mat.ground_horizon_color = Color(0.30, 0.38, 0.25)
	sky_mat.sun_angle_max = 30.0
	sky_mat.sun_curve = 0.1
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.background_color = Color(0.12, 0.18, 0.14)

	# Ambient — brighter, warmer
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.55, 0.40)
	env.ambient_light_energy = 0.7

	# Fog — dense forest mist (fog of war effect)
	env.fog_enabled = true
	env.fog_light_color = Color(0.35, 0.45, 0.32)
	env.fog_density = 0.025
	env.fog_aerial_perspective = 0.8

	# Tonemap
	env.tonemap_mode = 2  # Filmic (ACES removed in Godot 4.5)
	env.tonemap_white = 8.0
	env.tonemap_exposure = 1.2

	# Glow — for magic
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# SSAO — only available in Forward+/Mobile, skip on GL Compatibility
	# env.ssao_enabled = true

	world_env.environment = env

	# Sun — warm filtered light
	sun_light.rotation_degrees = Vector3(-45.0, -25.0, 0.0)
	sun_light.light_color = Color(0.85, 0.80, 0.60)
	sun_light.light_energy = 1.6
	sun_light.shadow_enabled = true
	sun_light.shadow_bias = 0.02
	sun_light.shadow_normal_bias = 1.0

	# Secondary fill light (blue bounce from sky)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(30.0, 160.0, 0.0)
	fill.light_color = Color(0.40, 0.55, 0.65)
	fill.light_energy = 0.35
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
# TERRAIN
# ============================================================

func _build_ground() -> void:
	var ground: StaticBody3D = StaticBody3D.new()
	ground.name = "Ground"
	world_root.add_child(ground)

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(120.0, 2.0, 320.0)
	col.shape = shape
	col.position = Vector3(0.0, -1.0, -135.0)
	ground.add_child(col)

	# Ground mesh with better color
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(120.0, 0.2, 320.0)
	mi.mesh = bm
	mi.position = Vector3(0.0, -0.1, -135.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.22, 0.10)
	mat.roughness = 0.95
	mi.material_override = mat
	ground.add_child(mi)


func _build_path_terrain() -> void:
	# Organic path: variable width, terre+racines base
	var dirt_mat: StandardMaterial3D = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.28, 0.20, 0.11)
	dirt_mat.roughness = 0.95

	var root_mat: StandardMaterial3D = StandardMaterial3D.new()
	root_mat.albedo_color = Color(0.15, 0.10, 0.06)
	root_mat.roughness = 1.0

	# Luminescent marker material (for dark zones)
	var glow_mat: StandardMaterial3D = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.3, 0.9, 0.5, 0.8)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.3, 0.9, 0.5)
	glow_mat.emission_energy_multiplier = 3.0
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for i in range(_path_points.size() - 1):
		var a: Vector3 = _path_points[i]
		var b: Vector3 = _path_points[i + 1]
		var mid: Vector3 = (a + b) * 0.5
		var length: float = a.distance_to(b)
		if length < 0.05:
			continue

		# Variable width: wider at clearings, narrower in dense forest
		var zone_idx: int = _get_zone_for_pos(mid)
		var width: float = 2.0
		if zone_idx in [2, 5, 6]:  # clearings
			width = 3.0
		elif zone_idx == 4:  # profonde
			width = 1.5

		# Dirt segment
		var seg: MeshInstance3D = MeshInstance3D.new()
		var bx: BoxMesh = BoxMesh.new()
		bx.size = Vector3(width, 0.06, length + 0.3)
		seg.mesh = bx
		seg.material_override = dirt_mat
		seg.position = mid + Vector3(0.0, 0.03, 0.0)
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dir: Vector3 = (b - a).normalized()
		if dir.length() > 0.001:
			seg.rotation.y = atan2(dir.x, dir.z)
		forest_root.add_child(seg)

		# Root details on path edges (every 3rd segment)
		if i % 3 == 0:
			for side_sign in [-1.0, 1.0]:
				var root_pos: Vector3 = mid + Vector3(side_sign * width * 0.4, 0.04, 0.0)
				var root_seg: MeshInstance3D = MeshInstance3D.new()
				var root_bx: BoxMesh = BoxMesh.new()
				root_bx.size = Vector3(0.15, 0.04, _rng.randf_range(0.5, 1.2))
				root_seg.mesh = root_bx
				root_seg.material_override = root_mat
				root_seg.position = root_pos
				root_seg.rotation.y = _rng.randf_range(-0.5, 0.5) + seg.rotation.y
				root_seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				forest_root.add_child(root_seg)

		# Luminescent markers in dark zones (Z3 Mare, Z4 Profonde)
		if zone_idx in [3, 4] and i % 8 == 0:
			for side_sign in [-1.0, 1.0]:
				var glow_pos: Vector3 = mid + Vector3(side_sign * (width * 0.5 + 0.2), 0.08, 0.0)
				var glow_quad: MeshInstance3D = MeshInstance3D.new()
				var gm: QuadMesh = QuadMesh.new()
				gm.size = Vector2(0.12, 0.12)
				glow_quad.mesh = gm
				glow_quad.material_override = glow_mat
				glow_quad.position = glow_pos
				glow_quad.rotation_degrees.x = -90.0
				glow_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				forest_root.add_child(glow_quad)

	# Stone markers at zone transitions
	for i in range(1, _zone_centers.size()):
		var closest_idx: int = _find_closest_path_point(_zone_centers[i])
		if closest_idx >= 0 and closest_idx < _path_points.size():
			var pt: Vector3 = _path_points[closest_idx]
			_spawn_broc("menhir_01", pt + Vector3(_rng.randf_range(2.0, 3.5), 0.0, 0.0), _rng.randf_range(1.0, 1.8))


func _get_zone_for_pos(pos: Vector3) -> int:
	var best: int = 0
	var best_d: float = INF
	for i in _zone_centers.size():
		var d: float = Vector2(pos.x - _zone_centers[i].x, pos.z - _zone_centers[i].z).length()
		if d < best_d:
			best_d = d
			best = i
	return best


func _find_closest_path_point(target: Vector3) -> int:
	var best_idx: int = -1
	var best_dist: float = INF
	for i in range(0, _path_points.size(), 4):
		var d: float = _path_points[i].distance_to(target)
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx


# ============================================================
# ZONES — now using real GLB assets
# ============================================================

func _build_zones() -> void:
	_build_z1_lisiere()
	_build_z2_dense()
	_build_z3_dolmen()
	_build_z4_mare()
	_build_z5_profonde()
	_build_z6_fontaine()
	_build_z7_cercle()


func _build_z1_lisiere() -> void:
	var c: Vector3 = _zone_centers[0]
	# POI decor only — bulk vegetation handled by ChunkManager MultiMesh
	_spawn_broc("fallen_trunk", c + Vector3(10.0, 0.0, -5.0), 2.0, 15.0)
	_spawn_broc("giant_stump", c + Vector3(-12.0, 0.0, -8.0), 2.5)


func _build_z2_dense() -> void:
	var c: Vector3 = _zone_centers[1]
	# POI decor only — bulk vegetation handled by ChunkManager MultiMesh
	_spawn_broc("root_network", c + Vector3(-6.0, 0.0, 5.0), 2.5)
	_spawn_broc("spider_web", c + Vector3(8.0, 3.0, -3.0), 2.0)
	_spawn_broc("giant_mushroom", c + Vector3(-3.0, 0.0, -10.0), 2.5)
	_spawn_broc("fallen_trunk", c + Vector3(12.0, 0.0, 8.0), 2.0, 45.0)


func _build_z3_dolmen() -> void:
	var c: Vector3 = _zone_centers[2]
	# POI: megaliths + special trees + lights
	_spawn_broc("dolmen", c, 3.5, 0.0)
	_spawn_broc("menhir_01", c + Vector3(-4.0, 0.0, -3.0), 3.0)
	_spawn_broc("menhir_02", c + Vector3(4.5, 0.0, -2.0), 2.8)
	_spawn_broc("merlin_tomb", c + Vector3(7.0, 0.0, 5.0), 2.5)
	_spawn_special("old_oak", c + Vector3(-10.0, 0.0, 4.0), 4.0)
	_spawn_broc("merlin_oak", c + Vector3(9.0, 0.0, -5.0), 3.5)
	_add_point_light(c + Vector3(0.0, 2.0, 0.0), Color(0.85, 0.75, 0.35), 0.6, 10.0)


func _build_z4_mare() -> void:
	var c: Vector3 = _zone_centers[3]
	# POI: water, willows, structures, lights
	_create_water(c, 8.0)
	for i in 6:
		var angle: float = float(i) * TAU / 6.0 + 0.3
		_spawn_special("willow", c + Vector3(cos(angle) * 9.0, 0.0, sin(angle) * 9.0), _rng.randf_range(3.5, 5.0))
	# Water plants (unique to this zone, not in chunk manager)
	for i in 6:
		_spawn_detail("lily_pink", c + _roff(1.0, 6.0) + Vector3(0.0, -0.25, 0.0), _rng.randf_range(1.5, 2.5))
	for i in 4:
		_spawn_detail("lily_white", c + _roff(1.0, 5.5) + Vector3(0.0, -0.25, 0.0), _rng.randf_range(1.5, 2.5))
	for i in 6:
		_spawn_detail("cattail", c + _roff(5.0, 9.0), _rng.randf_range(1.5, 2.5))
	_spawn_broc("bridge_wood", c + Vector3(8.0, -0.15, 0.0), 2.5, 90.0)
	_spawn_broc("giant_mushroom", c + Vector3(-6.0, 0.0, 4.0), 2.5, 45.0)
	_spawn_broc("spider_web", c + Vector3(5.0, 2.5, -6.0), 2.0)
	_add_point_light(c + Vector3(0.0, 0.8, 0.0), Color(0.3, 0.5, 0.7), 0.5, 9.0)


func _build_z5_profonde() -> void:
	var c: Vector3 = _zone_centers[4]
	# POI: unique decor + dead trees + lights
	for i in 4:
		_spawn_special("dead", c + _roff(6.0, 25.0), _rng.randf_range(3.0, 4.5))
	_spawn_broc("giant_mushroom", c + Vector3(-5.0, 0.0, 4.0), 3.0)
	_spawn_broc("giant_stump", c + Vector3(6.0, 0.0, -7.0), 3.0)
	_spawn_broc("fallen_trunk", c + Vector3(-8.0, 0.0, -5.0), 2.5, 30.0)
	_spawn_broc("root_network", c + Vector3(4.0, 0.0, 8.0), 2.5)
	_spawn_broc("spider_web", c + Vector3(-12.0, 3.0, 10.0), 2.5, 120.0)
	_spawn_broc("root_network", c + Vector3(8.0, 0.0, -4.0), 2.0, 200.0)
	_spawn_broc("fallen_trunk", c + Vector3(14.0, 0.0, 6.0), 2.0, 75.0)
	for i in 5:
		_add_point_light(c + _roff(3.0, 14.0) + Vector3(0.0, 0.5, 0.0), Color(0.5, 0.8, 0.3), 0.3, 3.5)


func _build_z6_fontaine() -> void:
	var c: Vector3 = _zone_centers[5]
	# Real fountain GLB — imposing sacred spring
	_spawn_broc("fountain_barenton", c, 3.0, 0.0)
	_create_water(c + Vector3(0.0, 0.3, 0.0), 3.0)
	# Fairy lanterns around fountain — scaled up
	_spawn_broc("fairy_lantern", c + Vector3(4.5, 0.0, -3.5), 2.5)
	_spawn_broc("fairy_lantern", c + Vector3(-3.5, 0.0, 4.0), 2.2, 180.0)
	# Root arch as entrance — massive
	_spawn_broc("root_arch", c + Vector3(0.0, 0.0, 10.0), 3.5, 0.0)
	# Sacred trees — giant spiral and silver
	_spawn_special("spiral", c + Vector3(7.0, 0.0, -5.0), 4.0)
	_spawn_special("silver", c + Vector3(-6.0, 0.0, -4.0), 3.5)
	# POI: stump with fairy glow
	_spawn_broc("giant_stump", c + Vector3(-6.0, 0.0, -2.0), 2.5, 60.0)
	_add_point_light(c + Vector3(0.0, 1.5, 0.0), Color(0.90, 0.75, 0.35), 1.0, 10.0)


func _build_z7_cercle() -> void:
	var c: Vector3 = _zone_centers[6]
	# Real stone circle GLB at center — massive ritual site
	_spawn_broc("stone_circle", c, 4.0, 0.0)
	# Towering menhirs around the circle
	for i in 6:
		var angle: float = float(i) * TAU / 6.0 + 0.4
		var key: String = "menhir_01" if i % 2 == 0 else "menhir_02"
		_spawn_broc(key, c + Vector3(cos(angle) * 10.0, 0.0, sin(angle) * 10.0), _rng.randf_range(3.0, 4.0))
	# Druid altar at center — imposing
	_spawn_broc("druid_altar", c + Vector3(0.0, 0.0, 0.0), 2.5, 0.0)
	# Ancient giant oaks — the oldest trees in the forest
	_spawn_special("old_oak", c + Vector3(-12.0, 0.0, 6.0), 5.0)
	_spawn_special("old_oak", c + Vector3(11.0, 0.0, -7.0), 4.5)
	_spawn_special("old_oak", c + Vector3(0.0, 0.0, 12.0), 5.5)
	_spawn_special("golden", c + Vector3(-8.0, 0.0, -9.0), 4.0)
	# POI: fallen trunk as ancient sentinel
	_spawn_broc("fallen_trunk", c + Vector3(0.0, 0.0, -10.0), 2.5, 0.0)
	# Mystical blue glow — strongest here
	_add_point_light(c + Vector3(0.0, 1.5, 0.0), Color(0.30, 0.60, 0.90), 1.0, 12.0)
	_add_point_light(c + Vector3(5.0, 0.8, 5.0), Color(0.20, 0.40, 0.80), 0.4, 6.0)
	_add_point_light(c + Vector3(-5.0, 0.8, -5.0), Color(0.20, 0.40, 0.80), 0.4, 6.0)


# ============================================================
# PROCEDURAL BUILDERS (water + fallbacks)
# ============================================================

func _create_water(pos: Vector3, radius: float) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.height = 0.05
	cm.bottom_radius = radius
	cm.top_radius = radius
	cm.radial_segments = 12
	mi.mesh = cm
	mi.position = pos + Vector3(0.0, -0.3, 0.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.22, 0.28, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	mat.metallic = 0.3
	mi.material_override = mat
	forest_root.add_child(mi)


# Fallbacks if GLB not loaded
func _create_fallback_tree(pos: Vector3, scale_f: float) -> Node3D:
	var tree: Node3D = Node3D.new()
	tree.position = pos
	forest_root.add_child(tree)
	var trunk: MeshInstance3D = MeshInstance3D.new()
	var tm: CylinderMesh = CylinderMesh.new()
	tm.height = 2.4 * scale_f
	tm.bottom_radius = 0.2 * scale_f
	tm.top_radius = 0.15 * scale_f
	tm.radial_segments = 6
	trunk.mesh = tm
	trunk.position = Vector3(0.0, 1.2 * scale_f, 0.0)
	var t_mat: StandardMaterial3D = StandardMaterial3D.new()
	t_mat.albedo_color = Color(0.20, 0.14, 0.08)
	t_mat.roughness = 1.0
	trunk.material_override = t_mat
	tree.add_child(trunk)
	for layer in 3:
		var crown: MeshInstance3D = MeshInstance3D.new()
		var cone: CylinderMesh = CylinderMesh.new()
		cone.height = (1.3 - float(layer) * 0.15) * scale_f
		cone.bottom_radius = (1.3 - float(layer) * 0.2) * scale_f
		cone.top_radius = 0.0
		cone.radial_segments = 6
		crown.mesh = cone
		crown.position = Vector3(0.0, 2.4 * scale_f + 0.4 + float(layer) * 0.55, 0.0)
		var lm: StandardMaterial3D = StandardMaterial3D.new()
		lm.albedo_color = Color(0.14 + _rng.randf_range(-0.03, 0.04), 0.32, 0.12)
		lm.roughness = 1.0
		crown.material_override = lm
		tree.add_child(crown)
	_sway_nodes.append(tree)
	return tree


func _create_fallback_shrub(pos: Vector3, scale_f: float) -> Node3D:
	var shrub: MeshInstance3D = MeshInstance3D.new()
	shrub.position = pos + Vector3(0.0, 0.35 * scale_f, 0.0)
	forest_root.add_child(shrub)
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.5 * scale_f
	sm.height = 0.7 * scale_f
	sm.radial_segments = 6
	sm.rings = 3
	shrub.mesh = sm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.34, 0.12)
	mat.roughness = 1.0
	shrub.material_override = mat
	return shrub


# ============================================================
# VOLUMETRIC EFFECTS
# ============================================================

func _add_fog_particles() -> void:
	# Ground fog along the path
	for i in range(0, _zone_centers.size()):
		var center: Vector3 = _zone_centers[i]
		var fog: GPUParticles3D = GPUParticles3D.new()
		fog.name = "FogZone%d" % i
		fog.position = center + Vector3(0.0, 0.3, 0.0)
		fog.amount = 30
		fog.lifetime = 8.0
		fog.explosiveness = 0.0
		fog.randomness = 1.0
		fog.visibility_aabb = AABB(Vector3(-15, -1, -15), Vector3(30, 3, 30))

		var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
		mat.direction = Vector3(1.0, 0.1, 0.0)
		mat.spread = 180.0
		mat.initial_velocity_min = 0.2
		mat.initial_velocity_max = 0.5
		mat.gravity = Vector3(0.0, 0.0, 0.0)
		mat.scale_min = 3.0
		mat.scale_max = 6.0
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(12.0, 0.3, 12.0)
		# Fade
		mat.color = Color(0.35, 0.45, 0.35, 0.08)
		fog.process_material = mat

		# Billboard quad mesh
		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2(2.0, 2.0)
		var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
		draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		draw_mat.albedo_color = Color(0.40, 0.50, 0.38, 0.06)
		draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_mat.no_depth_test = true
		qm.material = draw_mat
		fog.draw_pass_1 = qm

		forest_root.add_child(fog)


func _add_pollen_particles() -> void:
	# Floating pollen/dust everywhere
	var pollen: GPUParticles3D = GPUParticles3D.new()
	pollen.name = "Pollen"
	pollen.position = Vector3(0.0, 2.0, -55.0)
	pollen.amount = 80
	pollen.lifetime = 12.0
	pollen.explosiveness = 0.0
	pollen.randomness = 1.0
	pollen.visibility_aabb = AABB(Vector3(-60, -2, -80), Vector3(120, 8, 160))

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.3, 0.1, -0.1)
	mat.spread = 90.0
	mat.initial_velocity_min = 0.05
	mat.initial_velocity_max = 0.15
	mat.gravity = Vector3(0.0, -0.01, 0.0)
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(50.0, 3.0, 70.0)
	mat.color = Color(0.90, 0.85, 0.60, 0.3)
	pollen.process_material = mat

	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(0.04, 0.04)
	var dm: StandardMaterial3D = StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.95, 0.90, 0.65, 0.5)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.emission_enabled = true
	dm.emission = Color(0.95, 0.90, 0.65)
	dm.emission_energy_multiplier = 0.5
	qm.material = dm
	pollen.draw_pass_1 = qm

	forest_root.add_child(pollen)
	_pollen_node = pollen


func _add_fireflies() -> void:
	# Fireflies in zones 3-7
	for zi in range(2, _zone_centers.size()):
		var center: Vector3 = _zone_centers[zi]
		var ff: GPUParticles3D = GPUParticles3D.new()
		ff.name = "Fireflies_Z%d" % zi
		ff.position = center + Vector3(0.0, 1.0, 0.0)
		ff.amount = 12
		ff.lifetime = 6.0
		ff.explosiveness = 0.0
		ff.randomness = 1.0
		ff.visibility_aabb = AABB(Vector3(-10, -1, -10), Vector3(20, 5, 20))

		var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
		mat.direction = Vector3(0.0, 0.5, 0.0)
		mat.spread = 180.0
		mat.initial_velocity_min = 0.1
		mat.initial_velocity_max = 0.3
		mat.gravity = Vector3(0.0, 0.0, 0.0)
		mat.scale_min = 1.0
		mat.scale_max = 2.0
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(8.0, 1.5, 8.0)
		mat.color = Color(0.55, 0.90, 0.35, 0.8)
		ff.process_material = mat

		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2(0.06, 0.06)
		var dm: StandardMaterial3D = StandardMaterial3D.new()
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.albedo_color = Color(0.55, 0.85, 0.35, 0.9)
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.emission_enabled = true
		dm.emission = Color(0.55, 0.90, 0.35)
		dm.emission_energy_multiplier = 3.0
		qm.material = dm
		ff.draw_pass_1 = qm

		forest_root.add_child(ff)
		_firefly_nodes.append(ff)

		# Per-firefly point light for glow
		_add_point_light(center + Vector3(0.0, 1.5, 0.0), Color(0.50, 0.80, 0.30), 0.15, 4.0)


func _add_god_rays() -> void:
	# Fake light shafts using vertical billboard quads in clearings
	var ray_mat: StandardMaterial3D = StandardMaterial3D.new()
	ray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray_mat.albedo_color = Color(0.95, 0.90, 0.60, 0.04)
	ray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ray_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ray_mat.no_depth_test = false
	ray_mat.emission_enabled = true
	ray_mat.emission = Color(0.95, 0.90, 0.60)
	ray_mat.emission_energy_multiplier = 0.15

	# Place god rays in clearings (zones 3, 6, 7)
	for zi in [2, 5, 6]:
		var center: Vector3 = _zone_centers[zi]
		for r in 3:
			var ray: MeshInstance3D = MeshInstance3D.new()
			var qm: QuadMesh = QuadMesh.new()
			qm.size = Vector2(_rng.randf_range(1.5, 3.0), _rng.randf_range(8.0, 14.0))
			qm.material = ray_mat
			ray.mesh = qm
			ray.position = center + Vector3(
				_rng.randf_range(-4.0, 4.0),
				_rng.randf_range(3.0, 6.0),
				_rng.randf_range(-4.0, 4.0)
			)
			ray.rotation_degrees = Vector3(
				_rng.randf_range(-10.0, 10.0),
				_rng.randf_range(0.0, 360.0),
				_rng.randf_range(-5.0, 5.0)
			)
			ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			forest_root.add_child(ray)


func _add_point_light(pos: Vector3, color: Color, energy: float, rng: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = rng
	light.shadow_enabled = false
	forest_root.add_child(light)


# ============================================================
# ANIMATIONS
# ============================================================

func _update_tree_sway(_delta: float) -> void:
	for node in _sway_nodes:
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
	var center: Vector3 = _zone_centers[6]
	merlin_node.position = center
	_merlin_float_time = _rng.randf_range(0.0, TAU)
	_merlin_pixel_rig = Node3D.new()
	_merlin_pixel_rig.name = "PixelRig"
	_merlin_pixel_rig.position = Vector3(0.0, 0.65, 0.0)
	merlin_node.add_child(_merlin_pixel_rig)
	_build_merlin_rig(_merlin_pixel_rig)


func _build_merlin_rig(rig: Node3D) -> void:
	var bx: BoxMesh = BoxMesh.new()
	bx.size = Vector3(MERLIN_PX, MERLIN_PX, 0.08)
	var pixels: Array[MeshInstance3D] = []
	var gh: int = MERLIN_GRID.size()
	var gw: int = int(MERLIN_GRID[0].size())
	var orb: Vector3 = Vector3.ZERO

	for row in gh:
		var rd: Array = MERLIN_GRID[row]
		for col in rd.size():
			var ci: int = int(rd[col])
			if ci == 0:
				continue
			var px: MeshInstance3D = MeshInstance3D.new()
			px.mesh = bx
			px.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = MERLIN_COLORS.get(ci, Color.WHITE)
			mat.roughness = 1.0
			if ci == 6 or ci == 7:
				mat.emission_enabled = true
				mat.emission = mat.albedo_color
				mat.emission_energy_multiplier = 1.5 if ci == 6 else 2.0
			px.material_override = mat
			var target: Vector3 = Vector3(
				(float(col) - (float(gw) - 1.0) * 0.5) * MERLIN_PX,
				float(gh - 1 - row) * MERLIN_PX,
				0.0
			)
			px.position = target + Vector3(_rng.randf_range(-0.12, 0.12), _rng.randf_range(1.0, 2.5), _rng.randf_range(-0.1, 0.1))
			px.scale = Vector3.ONE * _rng.randf_range(0.4, 0.8)
			px.set_meta("t", target)
			px.set_meta("r", row)
			rig.add_child(px)
			pixels.append(px)
			if ci == 6:
				orb = target

	# Assemble animation
	var tw: Tween = create_tween().set_parallel(true)
	for px in pixels:
		var t: Vector3 = px.get_meta("t")
		var r: int = int(px.get_meta("r"))
		var dl: float = float(r) * 0.02 + _rng.randf_range(0.0, 0.2)
		var dur: float = 0.4 + _rng.randf_range(0.1, 0.4)
		tw.tween_property(px, "position", t, dur).set_delay(dl).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(px, "scale", Vector3.ONE, dur * 0.9).set_delay(dl).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_merlin_orb_light = OmniLight3D.new()
	_merlin_orb_light.light_color = Color(0.33, 0.73, 1.0)
	_merlin_orb_light.light_energy = 1.0
	_merlin_orb_light.omni_range = 4.0
	_merlin_orb_light.position = orb + Vector3(0.0, 0.0, 0.3)
	rig.add_child(_merlin_orb_light)


func _update_merlin_visual(delta: float) -> void:
	if not is_instance_valid(merlin_node):
		return
	_merlin_float_time += delta
	merlin_node.position.y = _zone_centers[6].y + sin(_merlin_float_time * 1.6) * 0.08
	if _merlin_pixel_rig and is_instance_valid(_merlin_pixel_rig) and is_instance_valid(player):
		var look: Vector3 = Vector3(player.global_position.x, _merlin_pixel_rig.global_position.y, player.global_position.z)
		if _merlin_pixel_rig.global_position.distance_to(look) > 0.01:
			_merlin_pixel_rig.look_at(look, Vector3.UP)
	if _merlin_orb_light and is_instance_valid(_merlin_orb_light):
		_merlin_orb_light.light_energy = 0.8 + sin(_merlin_float_time * 4.5) * 0.3


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


func _roff(min_r: float, max_r: float) -> Vector3:
	var d: float = _rng.randf_range(min_r, max_r)
	var a: float = _rng.randf_range(0.0, TAU)
	return Vector3(cos(a) * d, 0.0, sin(a) * d)
