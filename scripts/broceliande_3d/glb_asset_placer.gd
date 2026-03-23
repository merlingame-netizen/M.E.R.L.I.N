extends RefCounted
## GlbAssetPlacer — Places GLB assets (creatures, extra megaliths, decor scatter)
## into BroceliandeForest3D zones. Complements ForestZoneBuilder (POI/structures)
## and BrocChunkManager (vegetation streaming).

const CREATURE_ASSETS: Dictionary = {
	"korrigan": "res://Assets/3d_models/broceliande/creatures/korrigan.glb",
	"white_doe": "res://Assets/3d_models/broceliande/creatures/white_doe.glb",
	"mist_wolf": "res://Assets/3d_models/broceliande/creatures/mist_wolf.glb",
	"giant_raven": "res://Assets/3d_models/broceliande/creatures/giant_raven.glb",
}

const MEGALITH_KEYS: Array[String] = ["menhir_01", "menhir_02"]

const DECOR_KEYS: Array[String] = ["fallen_trunk", "giant_mushroom", "giant_stump"]

const VEGETATION_MODELS: Array[String] = [
	"res://Assets/3d_models/vegetation/01_Tree_Small.glb",
	"res://Assets/3d_models/vegetation/02_Tree_Medium.glb",
	"res://Assets/3d_models/vegetation/03_Tree_Large.glb",
]

# Scale ranges for each category (Trellis models are ~1 unit)
const CREATURE_SCALE: float = 1.8
const MEGALITH_SCALE_MIN: float = 2.5
const MEGALITH_SCALE_MAX: float = 4.0
const DECOR_SCALE_MIN: float = 1.5
const DECOR_SCALE_MAX: float = 3.0
const TREE_SCALE_MIN: float = 3.0
const TREE_SCALE_MAX: float = 5.0

var _creature_scenes: Dictionary = {}
var _vegetation_scenes: Array[PackedScene] = []


func place_assets(world: Node3D, zones: Array, rng: RandomNumberGenerator) -> void:
	_load_creature_scenes()
	_load_vegetation_scenes()
	_place_creatures(world, zones, rng)
	_place_path_megaliths(world, zones, rng)
	_scatter_decor(world, zones, rng)
	_scatter_vegetation(world, zones, rng)
	print("[GlbAssetPlacer] Asset placement complete")


func _load_creature_scenes() -> void:
	for key in CREATURE_ASSETS:
		var path: String = CREATURE_ASSETS[key]
		if ResourceLoader.exists(path):
			var scene: PackedScene = load(path) as PackedScene
			if scene:
				_creature_scenes[key] = scene
	print("[GlbAssetPlacer] Loaded %d/%d creature GLBs" % [_creature_scenes.size(), CREATURE_ASSETS.size()])


func _load_vegetation_scenes() -> void:
	for path in VEGETATION_MODELS:
		if ResourceLoader.exists(path):
			var scene: PackedScene = load(path) as PackedScene
			if scene:
				_vegetation_scenes.append(scene)
	print("[GlbAssetPlacer] Loaded %d/%d vegetation GLBs" % [_vegetation_scenes.size(), VEGETATION_MODELS.size()])


# --- Creatures: 1-3 in outer zones (indices 4, 5, 6) ---

func _place_creatures(world: Node3D, zones: Array, rng: RandomNumberGenerator) -> void:
	if _creature_scenes.is_empty():
		return
	var outer_indices: Array[int] = [4, 5, 6]
	var creature_keys: Array = _creature_scenes.keys()
	var count: int = rng.randi_range(1, 3)
	for i in count:
		var zone_idx: int = outer_indices[rng.randi_range(0, outer_indices.size() - 1)]
		if zone_idx >= zones.size():
			continue
		var center: Vector3 = zones[zone_idx] as Vector3
		var offset: Vector3 = _random_offset(rng, 5.0, 15.0)
		var key: String = creature_keys[rng.randi_range(0, creature_keys.size() - 1)]
		var scene: PackedScene = _creature_scenes[key] as PackedScene
		_spawn_instance(world, scene, center + offset, CREATURE_SCALE, rng.randf_range(0.0, 360.0), 50.0)


# --- Megaliths: 2-4 menhirs along the path (spaced between zone centers) ---

func _place_path_megaliths(world: Node3D, zones: Array, rng: RandomNumberGenerator) -> void:
	if zones.size() < 2:
		return
	var count: int = rng.randi_range(2, 4)
	for i in count:
		# Pick a random segment between consecutive zones
		var seg_idx: int = rng.randi_range(0, zones.size() - 2)
		var a: Vector3 = zones[seg_idx] as Vector3
		var b: Vector3 = zones[seg_idx + 1] as Vector3
		var t: float = rng.randf_range(0.2, 0.8)
		var pos: Vector3 = a.lerp(b, t)
		# Offset slightly from path center
		var side_offset: Vector3 = _random_offset(rng, 2.0, 6.0)
		pos += side_offset
		pos.y = 0.0
		var key: String = MEGALITH_KEYS[rng.randi_range(0, MEGALITH_KEYS.size() - 1)]
		var scene: PackedScene = _try_load_broc("res://Assets/3d_models/broceliande/megaliths/%s.glb" % key)
		if scene:
			var scale_f: float = rng.randf_range(MEGALITH_SCALE_MIN, MEGALITH_SCALE_MAX)
			_spawn_instance(world, scene, pos, scale_f, rng.randf_range(0.0, 360.0), 70.0)


# --- Decor: scatter fallen_trunk, giant_mushroom, giant_stump randomly across zones ---

func _scatter_decor(world: Node3D, zones: Array, rng: RandomNumberGenerator) -> void:
	for zone_idx in zones.size():
		var center: Vector3 = zones[zone_idx] as Vector3
		var decor_count: int = rng.randi_range(1, 3)
		for _i in decor_count:
			var key: String = DECOR_KEYS[rng.randi_range(0, DECOR_KEYS.size() - 1)]
			var path: String = "res://Assets/3d_models/broceliande/decor/%s.glb" % key
			var scene: PackedScene = _try_load_broc(path)
			if scene:
				var offset: Vector3 = _random_offset(rng, 8.0, 20.0)
				var pos: Vector3 = center + offset
				pos.y = 0.0
				var scale_f: float = rng.randf_range(DECOR_SCALE_MIN, DECOR_SCALE_MAX)
				_spawn_instance(world, scene, pos, scale_f, rng.randf_range(0.0, 360.0), 40.0)


# --- Vegetation: scatter tree GLBs (replaces procedural BoxMesh trees) ---

func _scatter_vegetation(world: Node3D, zones: Array, rng: RandomNumberGenerator) -> void:
	if _vegetation_scenes.is_empty():
		return
	for zone_idx in zones.size():
		var center: Vector3 = zones[zone_idx] as Vector3
		var tree_count: int = rng.randi_range(4, 8)
		for _i in tree_count:
			var offset: Vector3 = _random_offset(rng, 6.0, 22.0)
			var pos: Vector3 = center + offset
			pos.y = 0.0
			var scene: PackedScene = _vegetation_scenes[rng.randi_range(0, _vegetation_scenes.size() - 1)]
			var scale_f: float = rng.randf_range(TREE_SCALE_MIN, TREE_SCALE_MAX)
			_spawn_instance(world, scene, pos, scale_f, rng.randf_range(0.0, 360.0), 60.0)


# --- Helpers ---

func _spawn_instance(parent: Node3D, scene: PackedScene, pos: Vector3, scale_f: float, rot_y_deg: float, vis_range: float) -> Node3D:
	var instance: Node3D = scene.instantiate() as Node3D
	instance.position = pos
	instance.scale = Vector3.ONE * scale_f
	instance.rotation_degrees.y = rot_y_deg
	if vis_range > 0.0:
		_apply_vis_range(instance, vis_range)
	parent.add_child(instance)
	return instance


func _apply_vis_range(node: Node3D, range_end: float) -> void:
	if node is GeometryInstance3D:
		node.visibility_range_end = range_end
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for child in node.get_children():
		if child is Node3D:
			_apply_vis_range(child as Node3D, range_end)


func _random_offset(rng: RandomNumberGenerator, min_r: float, max_r: float) -> Vector3:
	var dist: float = rng.randf_range(min_r, max_r)
	var angle: float = rng.randf_range(0.0, TAU)
	return Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


func _try_load_broc(path: String) -> PackedScene:
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	return null
