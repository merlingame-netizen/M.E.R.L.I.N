extends RefCounted
## GlbAssetPlacer — Places GLB assets (all BK categories) into BroceliandeForest3D zones.
## v2: 12 asset categories from BK_N64_ASSET_BIBLE.md

const BK_BASE: String = "res://Assets/bk_assets/"
const BK_BIOME: String = "foret_broceliande/"

const CREATURE_ASSETS: Dictionary = {
	"korrigan_a": BK_BASE + "characters/" + BK_BIOME + "creature_bk_foret_broceliande_0000.glb",
	"doe_a": BK_BASE + "characters/" + BK_BIOME + "creature_bk_foret_broceliande_0001.glb",
	"wolf_a": BK_BASE + "characters/" + BK_BIOME + "creature_bk_foret_broceliande_0002.glb",
	"korrigan_b": BK_BASE + "characters/" + BK_BIOME + "creature_bk_foret_broceliande_0003.glb",
	"doe_b": BK_BASE + "characters/" + BK_BIOME + "creature_bk_foret_broceliande_0004.glb",
	"wolf_b": BK_BASE + "characters/" + BK_BIOME + "creature_bk_foret_broceliande_0005.glb",
}

const MEGALITH_KEYS: Array[String] = ["megalith_0", "megalith_1", "megalith_2", "megalith_3", "megalith_4", "megalith_5"]
const MEGALITH_PATHS: Dictionary = {
	"megalith_0": BK_BASE + "megaliths/" + BK_BIOME + "megalith_bk_foret_broceliande_0000.glb",
	"megalith_1": BK_BASE + "megaliths/" + BK_BIOME + "megalith_bk_foret_broceliande_0001.glb",
	"megalith_2": BK_BASE + "megaliths/" + BK_BIOME + "megalith_bk_foret_broceliande_0002.glb",
	"megalith_3": BK_BASE + "megaliths/" + BK_BIOME + "megalith_bk_foret_broceliande_0003.glb",
	"megalith_4": BK_BASE + "megaliths/" + BK_BIOME + "megalith_bk_foret_broceliande_0004.glb",
	"megalith_5": BK_BASE + "megaliths/" + BK_BIOME + "megalith_bk_foret_broceliande_0005.glb",
}

const DECOR_KEYS: Array[String] = ["rock_0", "rock_1", "rock_2", "rock_3", "rock_4", "rock_5"]
const DECOR_PATHS: Dictionary = {
	"rock_0": BK_BASE + "rocks/" + BK_BIOME + "rock_bk_foret_broceliande_0000.glb",
	"rock_1": BK_BASE + "rocks/" + BK_BIOME + "rock_bk_foret_broceliande_0001.glb",
	"rock_2": BK_BASE + "rocks/" + BK_BIOME + "rock_bk_foret_broceliande_0002.glb",
	"rock_3": BK_BASE + "rocks/" + BK_BIOME + "rock_bk_foret_broceliande_0003.glb",
	"rock_4": BK_BASE + "rocks/" + BK_BIOME + "rock_bk_foret_broceliande_0004.glb",
	"rock_5": BK_BASE + "rocks/" + BK_BIOME + "rock_bk_foret_broceliande_0005.glb",
}

const VEGETATION_MODELS: Array[String] = [
	BK_BASE + "vegetation/" + BK_BIOME + "tree_bk_foret_broceliande_0000.glb",
	BK_BASE + "vegetation/" + BK_BIOME + "tree_bk_foret_broceliande_0001.glb",
	BK_BASE + "vegetation/" + BK_BIOME + "tree_bk_foret_broceliande_0002.glb",
	BK_BASE + "vegetation/" + BK_BIOME + "tree_bk_foret_broceliande_0003.glb",
	BK_BASE + "vegetation/" + BK_BIOME + "tree_bk_foret_broceliande_0004.glb",
	BK_BASE + "vegetation/" + BK_BIOME + "tree_bk_foret_broceliande_0005.glb",
]

const BUSH_MODELS: Array[String] = [
	BK_BASE + "bushes/" + BK_BIOME + "bush_bk_foret_broceliande_0000.glb",
	BK_BASE + "bushes/" + BK_BIOME + "bush_bk_foret_broceliande_0001.glb",
	BK_BASE + "bushes/" + BK_BIOME + "bush_bk_foret_broceliande_0002.glb",
	BK_BASE + "bushes/" + BK_BIOME + "bush_bk_foret_broceliande_0003.glb",
	BK_BASE + "bushes/" + BK_BIOME + "bush_bk_foret_broceliande_0004.glb",
	BK_BASE + "bushes/" + BK_BIOME + "bush_bk_foret_broceliande_0005.glb",
]

const GROUNDCOVER_MODELS: Array[String] = [
	BK_BASE + "groundcover/" + BK_BIOME + "groundcover_bk_foret_broceliande_0000.glb",
	BK_BASE + "groundcover/" + BK_BIOME + "groundcover_bk_foret_broceliande_0001.glb",
	BK_BASE + "groundcover/" + BK_BIOME + "groundcover_bk_foret_broceliande_0002.glb",
	BK_BASE + "groundcover/" + BK_BIOME + "groundcover_bk_foret_broceliande_0003.glb",
	BK_BASE + "groundcover/" + BK_BIOME + "groundcover_bk_foret_broceliande_0004.glb",
	BK_BASE + "groundcover/" + BK_BIOME + "groundcover_bk_foret_broceliande_0005.glb",
]

const MUSHROOM_MODELS: Array[String] = [
	BK_BASE + "mushrooms/" + BK_BIOME + "mushroom_bk_foret_broceliande_0000.glb",
	BK_BASE + "mushrooms/" + BK_BIOME + "mushroom_bk_foret_broceliande_0001.glb",
	BK_BASE + "mushrooms/" + BK_BIOME + "mushroom_bk_foret_broceliande_0002.glb",
	BK_BASE + "mushrooms/" + BK_BIOME + "mushroom_bk_foret_broceliande_0003.glb",
	BK_BASE + "mushrooms/" + BK_BIOME + "mushroom_bk_foret_broceliande_0004.glb",
	BK_BASE + "mushrooms/" + BK_BIOME + "mushroom_bk_foret_broceliande_0005.glb",
]

const DEADWOOD_MODELS: Array[String] = [
	BK_BASE + "deadwood/" + BK_BIOME + "deadwood_bk_foret_broceliande_0000.glb",
	BK_BASE + "deadwood/" + BK_BIOME + "deadwood_bk_foret_broceliande_0001.glb",
	BK_BASE + "deadwood/" + BK_BIOME + "deadwood_bk_foret_broceliande_0002.glb",
	BK_BASE + "deadwood/" + BK_BIOME + "deadwood_bk_foret_broceliande_0003.glb",
	BK_BASE + "deadwood/" + BK_BIOME + "deadwood_bk_foret_broceliande_0004.glb",
	BK_BASE + "deadwood/" + BK_BIOME + "deadwood_bk_foret_broceliande_0005.glb",
]

# Scale ranges (BK assets are real-world scale — minor variation only)
const CREATURE_SCALE: float = 1.0
const MEGALITH_SCALE_MIN: float = 0.8
const MEGALITH_SCALE_MAX: float = 1.2
const DECOR_SCALE_MIN: float = 0.85
const DECOR_SCALE_MAX: float = 1.3
const TREE_SCALE_MIN: float = 0.8
const TREE_SCALE_MAX: float = 1.15
const BUSH_SCALE_MIN: float = 0.7
const BUSH_SCALE_MAX: float = 1.3
const GROUND_SCALE_MIN: float = 0.6
const GROUND_SCALE_MAX: float = 1.4

var _creature_scenes: Dictionary = {}
var _vegetation_scenes: Array[PackedScene] = []
var _bush_scenes: Array[PackedScene] = []
var _groundcover_scenes: Array[PackedScene] = []
var _mushroom_scenes: Array[PackedScene] = []
var _deadwood_scenes: Array[PackedScene] = []


func place_assets(world: Node3D, zones: Array, rng: RandomNumberGenerator) -> void:
	_load_all_scenes()
	_place_creatures(world, zones, rng)
	_place_path_megaliths(world, zones, rng)
	_scatter_decor(world, zones, rng)
	_scatter_vegetation(world, zones, rng)
	_scatter_bushes(world, zones, rng)
	_scatter_groundcover(world, zones, rng)
	_scatter_mushrooms(world, zones, rng)
	_scatter_deadwood(world, zones, rng)
	print("[GlbAssetPlacer] Asset placement complete (8 categories)")


func _load_all_scenes() -> void:
	# Creatures
	for key in CREATURE_ASSETS:
		var path: String = CREATURE_ASSETS[key]
		if ResourceLoader.exists(path):
			var scene: PackedScene = load(path) as PackedScene
			if scene:
				_creature_scenes[key] = scene
	print("[GlbAssetPlacer] Loaded %d/%d creatures" % [_creature_scenes.size(), CREATURE_ASSETS.size()])

	# Vegetation
	_vegetation_scenes = _load_scenes(VEGETATION_MODELS)
	print("[GlbAssetPlacer] Loaded %d/%d trees" % [_vegetation_scenes.size(), VEGETATION_MODELS.size()])

	_bush_scenes = _load_scenes(BUSH_MODELS)
	_groundcover_scenes = _load_scenes(GROUNDCOVER_MODELS)
	_mushroom_scenes = _load_scenes(MUSHROOM_MODELS)
	_deadwood_scenes = _load_scenes(DEADWOOD_MODELS)
	print("[GlbAssetPlacer] Loaded bushes:%d ground:%d mushrooms:%d deadwood:%d" % [
		_bush_scenes.size(), _groundcover_scenes.size(), _mushroom_scenes.size(), _deadwood_scenes.size()])


func _load_scenes(paths: Array[String]) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	for path in paths:
		if ResourceLoader.exists(path):
			var scene: PackedScene = load(path) as PackedScene
			if scene:
				result.append(scene)
	return result


# --- Creatures: 1-3 in outer zones ---

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


# --- Megaliths: 2-4 along path segments ---

func _place_path_megaliths(world: Node3D, zones: Array, rng: RandomNumberGenerator) -> void:
	if zones.size() < 2:
		return
	var count: int = rng.randi_range(4, 7)
	for i in count:
		var seg_idx: int = rng.randi_range(0, zones.size() - 2)
		var a: Vector3 = zones[seg_idx] as Vector3
		var b: Vector3 = zones[seg_idx + 1] as Vector3
		var t: float = rng.randf_range(0.2, 0.8)
		var pos: Vector3 = a.lerp(b, t)
		# Min 6m off the path so menhirs don't block the walker.
		var side_offset: Vector3 = _random_offset(rng, 6.0, 12.0)
		pos += side_offset
		pos.y = 0.0
		var key: String = MEGALITH_KEYS[rng.randi_range(0, MEGALITH_KEYS.size() - 1)]
		var scene: PackedScene = _try_load_broc(MEGALITH_PATHS[key])
		if scene:
			var scale_f: float = rng.randf_range(MEGALITH_SCALE_MIN, MEGALITH_SCALE_MAX)
			_spawn_instance(world, scene, pos, scale_f, rng.randf_range(0.0, 360.0), 70.0)


# --- Rocks: scatter across all zones ---

func _scatter_decor(world: Node3D, zones: Array, rng: RandomNumberGenerator) -> void:
	for zone_idx in zones.size():
		var center: Vector3 = zones[zone_idx] as Vector3
		var decor_count: int = rng.randi_range(4, 8)
		for _i in decor_count:
			var key: String = DECOR_KEYS[rng.randi_range(0, DECOR_KEYS.size() - 1)]
			var scene: PackedScene = _try_load_broc(DECOR_PATHS[key])
			if scene:
				var offset: Vector3 = _random_offset(rng, 8.0, 20.0)
				var pos: Vector3 = center + offset
				pos.y = 0.0
				var scale_f: float = rng.randf_range(DECOR_SCALE_MIN, DECOR_SCALE_MAX)
				_spawn_instance(world, scene, pos, scale_f, rng.randf_range(0.0, 360.0), 40.0)


# --- Trees: scattered per zone ---

func _scatter_vegetation(world: Node3D, zones: Array, rng: RandomNumberGenerator) -> void:
	if _vegetation_scenes.is_empty():
		return
	for zone_idx in zones.size():
		var center: Vector3 = zones[zone_idx] as Vector3
		var tree_count: int = rng.randi_range(9, 16)
		for _i in tree_count:
			var offset: Vector3 = _random_offset(rng, 6.0, 22.0)
			var pos: Vector3 = center + offset
			pos.y = 0.0
			var scene: PackedScene = _vegetation_scenes[rng.randi_range(0, _vegetation_scenes.size() - 1)]
			var scale_f: float = rng.randf_range(TREE_SCALE_MIN, TREE_SCALE_MAX)
			_spawn_instance(world, scene, pos, scale_f, rng.randf_range(0.0, 360.0), 60.0)


# --- Bushes: fill gaps between trees ---

func _scatter_bushes(world: Node3D, zones: Array, rng: RandomNumberGenerator) -> void:
	if _bush_scenes.is_empty():
		return
	for zone_idx in zones.size():
		var center: Vector3 = zones[zone_idx] as Vector3
		var bush_count: int = rng.randi_range(6, 12)
		for _i in bush_count:
			var offset: Vector3 = _random_offset(rng, 7.0, 18.0)
			var pos: Vector3 = center + offset
			pos.y = 0.0
			var scene: PackedScene = _bush_scenes[rng.randi_range(0, _bush_scenes.size() - 1)]
			var scale_f: float = rng.randf_range(BUSH_SCALE_MIN, BUSH_SCALE_MAX)
			_spawn_instance(world, scene, pos, scale_f, rng.randf_range(0.0, 360.0), 30.0)


# --- Groundcover: heavy scatter (4 tris each — very cheap) ---

func _scatter_groundcover(world: Node3D, zones: Array, rng: RandomNumberGenerator) -> void:
	if _groundcover_scenes.is_empty():
		return
	for zone_idx in zones.size():
		var center: Vector3 = zones[zone_idx] as Vector3
		var cover_count: int = rng.randi_range(16, 28)
		for _i in cover_count:
			var offset: Vector3 = _random_offset(rng, 7.0, 20.0)
			var pos: Vector3 = center + offset
			pos.y = 0.0
			var scene: PackedScene = _groundcover_scenes[rng.randi_range(0, _groundcover_scenes.size() - 1)]
			var scale_f: float = rng.randf_range(GROUND_SCALE_MIN, GROUND_SCALE_MAX)
			_spawn_instance(world, scene, pos, scale_f, rng.randf_range(0.0, 360.0), 25.0)


# --- Mushrooms: clusters near trees/deadwood ---

func _scatter_mushrooms(world: Node3D, zones: Array, rng: RandomNumberGenerator) -> void:
	if _mushroom_scenes.is_empty():
		return
	for zone_idx in range(0, zones.size(), 2):  # Every other zone
		var center: Vector3 = zones[zone_idx] as Vector3
		var mush_count: int = rng.randi_range(4, 9)
		for _i in mush_count:
			var offset: Vector3 = _random_offset(rng, 7.0, 12.0)
			var pos: Vector3 = center + offset
			pos.y = 0.0
			var scene: PackedScene = _mushroom_scenes[rng.randi_range(0, _mushroom_scenes.size() - 1)]
			_spawn_instance(world, scene, pos, rng.randf_range(0.7, 1.3), rng.randf_range(0.0, 360.0), 20.0)


# --- Deadwood: stumps and logs ---

func _scatter_deadwood(world: Node3D, zones: Array, rng: RandomNumberGenerator) -> void:
	if _deadwood_scenes.is_empty():
		return
	for zone_idx in zones.size():
		var center: Vector3 = zones[zone_idx] as Vector3
		var dw_count: int = rng.randi_range(3, 6)
		for _i in dw_count:
			var offset: Vector3 = _random_offset(rng, 5.0, 16.0)
			var pos: Vector3 = center + offset
			pos.y = 0.0
			var scene: PackedScene = _deadwood_scenes[rng.randi_range(0, _deadwood_scenes.size() - 1)]
			_spawn_instance(world, scene, pos, rng.randf_range(0.7, 1.2), rng.randf_range(0.0, 360.0), 35.0)


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
