## ═══════════════════════════════════════════════════════════════════════════════
## BrocChunkManager v2 — MultiMesh-based procedural chunked forest generation
## ═══════════════════════════════════════════════════════════════════════════════
## All vegetation batched into MultiMesh (1 draw call per mesh type per chunk).
## Density x10 vs v1, culling at 8m for fog-of-war proximity aesthetic.
## Deterministic seeds per chunk for reproducibility.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted

const BrocMultiMeshPool = preload("res://scripts/broceliande_3d/broc_multimesh_pool.gd")

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

const CHUNK_SIZE_Z: float = 30.0
const CHUNK_SIZE_X: float = 30.0
const CHUNKS_AHEAD: int = 3
const CHUNKS_BEHIND: int = 1
const UNLOAD_BEHIND: int = 2
const BUILD_PER_FRAME: int = 4  # Chunk finalize ops per frame (fewer but heavier)

## Visibility range for all MultiMesh instances (fog-of-war culling)
const VIS_RANGE_TREE: float = 12.0
const VIS_RANGE_BUSH: float = 10.0
const VIS_RANGE_DETAIL: float = 8.0
const VIS_RANGE_GRASS: float = 8.0

## Zone density profiles x10: [trees, small_trees, bushes, detail_count, fog_density_add]
const ZONE_DENSITY: Array[Array] = [
	[40, 20, 35, 120, 0.0],     # Z0 Lisiere — open but lush
	[80, 35, 55, 200, 0.005],   # Z1 Dense — closing canopy
	[50, 20, 40, 160, 0.008],   # Z2 Dolmen — clearing + surround
	[55, 28, 50, 220, 0.015],   # Z3 Mare — wet, lush undergrowth
	[120, 55, 70, 300, 0.02],   # Z4 Profonde — maximum density
	[65, 28, 50, 170, 0.01],    # Z5 Fontaine — filtered light
	[65, 35, 55, 160, 0.008],   # Z6 Cercle — moderate
]

## Detail type distribution (cumulative weights)
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

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

enum ChunkState { UNLOADED, QUEUED, BUILDING, ACTIVE }

var _forest_root: Node3D
var _pool: RefCounted  # BrocMultiMeshPool
var _zone_centers: Array[Vector3]
var _path_points: PackedVector3Array

var _tree_keys: Array[String] = []
var _bush_keys: Array[String] = []
var _detail_keys: Array[String] = []

## chunk_z_index -> { state, container, rng, transforms, node_count }
var _chunks: Dictionary = {}
var _last_player_chunk: int = -999
var _global_seed: int = 42
var _density_mult: float = 1.0  # LLM can override


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(
	forest_root: Node3D,
	tree_scenes: Array[PackedScene],
	bush_scenes: Array[PackedScene],
	_special_scenes: Dictionary,
	detail_scenes: Dictionary,
	_broc_scenes: Dictionary,
	zone_centers: Array[Vector3],
	path_points: PackedVector3Array,
) -> void:
	_forest_root = forest_root
	_zone_centers = zone_centers
	_path_points = path_points
	_global_seed = hash("broceliande_forest")

	# Build mesh pool from all scene types
	_pool = BrocMultiMeshPool.new()
	_pool.register_scenes("tree", tree_scenes)
	_pool.register_scenes("bush", bush_scenes)
	_pool.register_dict(detail_scenes)

	_tree_keys = _pool.get_keys_with_prefix("tree")
	_bush_keys = _pool.get_keys_with_prefix("bush")
	for key: String in detail_scenes:
		if _pool.has_key(key):
			_detail_keys.append(key)

	print("[ChunkManager v2] Pool: %d meshes (%d trees, %d bushes, %d details)" % [
		_pool.get_entry_count(), _tree_keys.size(), _bush_keys.size(), _detail_keys.size()])


func generate_initial(player_z: float) -> void:
	var player_chunk: int = _z_to_chunk(player_z)
	for ci in range(player_chunk, player_chunk + 2):
		_create_chunk(ci)
		_build_chunk_full(ci)
	_last_player_chunk = player_chunk


func set_density_mult(mult: float) -> void:
	_density_mult = clampf(mult, 0.1, 3.0)


# ═══════════════════════════════════════════════════════════════════════════════
# UPDATE (called every physics frame)
# ═══════════════════════════════════════════════════════════════════════════════

func update(player_pos: Vector3) -> void:
	var player_chunk: int = _z_to_chunk(player_pos.z)

	if player_chunk == _last_player_chunk:
		_process_build_queues()
		return
	_last_player_chunk = player_chunk

	# Queue chunks ahead
	for ci in range(player_chunk - CHUNKS_BEHIND, player_chunk + CHUNKS_AHEAD + 1):
		if not _chunks.has(ci):
			_create_chunk(ci)
			_queue_chunk_build(ci)

	# Unload distant chunks
	var keys_to_remove: Array[int] = []
	for ci: int in _chunks:
		if ci < player_chunk - UNLOAD_BEHIND or ci > player_chunk + CHUNKS_AHEAD + 1:
			keys_to_remove.append(ci)
	for ci in keys_to_remove:
		_unload_chunk(ci)

	_process_build_queues()


# ═══════════════════════════════════════════════════════════════════════════════
# CHUNK LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _z_to_chunk(z: float) -> int:
	return int(floor(-z / CHUNK_SIZE_Z))


func _chunk_z_range(ci: int) -> Vector2:
	var z_max: float = -float(ci) * CHUNK_SIZE_Z
	var z_min: float = z_max - CHUNK_SIZE_Z
	return Vector2(z_min, z_max)


func _create_chunk(ci: int) -> void:
	if _chunks.has(ci):
		return
	var container: Node3D = Node3D.new()
	container.name = "Chunk_%d" % ci
	_forest_root.add_child(container)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(ci, _global_seed))

	_chunks[ci] = {
		"state": ChunkState.QUEUED,
		"container": container,
		"rng": rng,
		"transforms": {},  # mesh_key -> Array[Transform3D]
		"pending_keys": [] as Array[String],  # keys to finalize
		"node_count": 0,
	}


func _queue_chunk_build(ci: int) -> void:
	if not _chunks.has(ci):
		return
	var chunk: Dictionary = _chunks[ci]
	if chunk["state"] != ChunkState.QUEUED:
		return

	var z_range: Vector2 = _chunk_z_range(ci)
	var zone_idx: int = _get_zone_for_z((z_range.x + z_range.y) * 0.5)
	var density: Array = ZONE_DENSITY[zone_idx] if zone_idx < ZONE_DENSITY.size() else ZONE_DENSITY[0]
	var rng: RandomNumberGenerator = chunk["rng"]
	var transforms: Dictionary = {}  # mesh_key -> Array[Transform3D]

	var eff_mult: float = _density_mult

	# Large trees
	var tree_count: int = int(float(density[0]) * eff_mult)
	_collect_transforms(transforms, rng, z_range, _tree_keys, tree_count, 3.0, 5.5)

	# Small trees
	var small_tree_count: int = int(float(density[1]) * eff_mult)
	_collect_transforms(transforms, rng, z_range, _tree_keys, small_tree_count, 1.5, 3.0)

	# Bushes
	var bush_count: int = int(float(density[2]) * eff_mult)
	_collect_transforms(transforms, rng, z_range, _bush_keys, bush_count, 1.2, 2.5)

	# Details
	var detail_count: int = int(float(density[3]) * eff_mult)
	for _i in detail_count:
		var roll: float = rng.randf()
		var detail_key: String = "grass_short"  # fallback
		for dr: Array in DETAIL_ROLLS:
			if roll < float(dr[0]):
				detail_key = dr[1] as String
				break
		if not _pool.has_key(detail_key):
			continue
		var pos: Vector3 = _random_pos(rng, z_range)
		if _is_on_path(pos, 2.0):
			pos.x += sign(pos.x + 0.01) * 2.5 + rng.randf_range(0.5, 2.0)
		var scale_f: float = rng.randf_range(0.5, 1.4)
		var rot_y: float = rng.randf_range(0.0, TAU)
		var t: Transform3D = Transform3D.IDENTITY
		t = t.scaled(Vector3(scale_f, scale_f, scale_f))
		t = t.rotated(Vector3.UP, rot_y)
		t.origin = pos
		if not transforms.has(detail_key):
			transforms[detail_key] = [] as Array[Transform3D]
		(transforms[detail_key] as Array[Transform3D]).append(t)

	# Collect pending keys for frame-budgeted finalization
	var pending: Array[String] = []
	for key: String in transforms:
		pending.append(key)
	# Always add grass multimesh
	pending.append("_grass_carpet")

	chunk["transforms"] = transforms
	chunk["pending_keys"] = pending
	chunk["_zone_idx"] = zone_idx
	chunk["_z_range"] = z_range
	chunk["state"] = ChunkState.BUILDING


func _process_build_queues() -> void:
	var built_this_frame: int = 0
	for ci: int in _chunks:
		var chunk: Dictionary = _chunks[ci]
		if chunk["state"] != ChunkState.BUILDING:
			continue
		var pending: Array = chunk["pending_keys"]
		var container: Node3D = chunk["container"]
		var rng: RandomNumberGenerator = chunk["rng"]

		while pending.size() > 0 and built_this_frame < BUILD_PER_FRAME:
			var key: String = pending.pop_front() as String
			if key == "_grass_carpet":
				var zone_idx: int = int(chunk.get("_zone_idx", 0))
				var density: Array = ZONE_DENSITY[zone_idx] if zone_idx < ZONE_DENSITY.size() else ZONE_DENSITY[0]
				var grass_count: int = int(float(density[3]) * 2.0 * _density_mult)
				var z_range: Vector2 = chunk["_z_range"] as Vector2
				_spawn_multimesh_grass(container, rng, z_range, grass_count)
			else:
				var transforms: Dictionary = chunk["transforms"]
				if transforms.has(key):
					_finalize_multimesh(container, key, transforms[key] as Array[Transform3D])
			chunk["node_count"] += 1
			built_this_frame += 1

		if pending.is_empty():
			chunk["state"] = ChunkState.ACTIVE
			chunk.erase("transforms")
			chunk.erase("pending_keys")
			chunk.erase("_zone_idx")
			chunk.erase("_z_range")


func _unload_chunk(ci: int) -> void:
	if not _chunks.has(ci):
		return
	var chunk: Dictionary = _chunks[ci]
	var container: Node3D = chunk["container"]
	if is_instance_valid(container):
		container.queue_free()
	_chunks.erase(ci)


# ═══════════════════════════════════════════════════════════════════════════════
# TRANSFORM COLLECTION
# ═══════════════════════════════════════════════════════════════════════════════

func _collect_transforms(
	transforms: Dictionary,
	rng: RandomNumberGenerator,
	z_range: Vector2,
	keys: Array[String],
	count: int,
	scale_min: float,
	scale_max: float,
) -> void:
	if keys.is_empty():
		return
	for _i in count:
		var key: String = keys[rng.randi_range(0, keys.size() - 1)]
		var pos: Vector3 = _random_pos(rng, z_range)
		if _is_on_path(pos, 3.0):
			pos.x += sign(pos.x + 0.01) * 3.0 + rng.randf_range(1.0, 3.0)
		var scale_f: float = rng.randf_range(scale_min, scale_max)
		var rot_y: float = rng.randf_range(0.0, TAU)

		var t: Transform3D = Transform3D.IDENTITY
		t = t.scaled(Vector3(scale_f, scale_f, scale_f))
		t = t.rotated(Vector3.UP, rot_y)
		t.origin = pos

		if not transforms.has(key):
			transforms[key] = [] as Array[Transform3D]
		(transforms[key] as Array[Transform3D]).append(t)


func _random_pos(rng: RandomNumberGenerator, z_range: Vector2) -> Vector3:
	return Vector3(
		rng.randf_range(-CHUNK_SIZE_X * 0.5, CHUNK_SIZE_X * 0.5),
		0.0,
		rng.randf_range(z_range.x, z_range.y)
	)


# ═══════════════════════════════════════════════════════════════════════════════
# MULTIMESH FINALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _finalize_multimesh(container: Node3D, key: String, xforms: Array[Transform3D]) -> void:
	if xforms.is_empty():
		return
	var mesh: Mesh = _pool.get_mesh(key)
	if not mesh:
		return

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()

	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])

	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Apply material from pool if available
	var mat: Material = _pool.get_material(key)
	if mat:
		mmi.material_override = mat

	# Visibility range based on type
	if key.begins_with("tree"):
		mmi.visibility_range_end = VIS_RANGE_TREE
	elif key.begins_with("bush"):
		mmi.visibility_range_end = VIS_RANGE_BUSH
	else:
		mmi.visibility_range_end = VIS_RANGE_DETAIL
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	container.add_child(mmi)


# ═══════════════════════════════════════════════════════════════════════════════
# MULTIMESH GROUND COVER (procedural grass carpet)
# ═══════════════════════════════════════════════════════════════════════════════

func _spawn_multimesh_grass(container: Node3D, rng: RandomNumberGenerator, z_range: Vector2, count: int) -> void:
	var grass_mesh: QuadMesh = QuadMesh.new()
	grass_mesh.size = Vector2(0.3, 0.5)
	grass_mesh.orientation = PlaneMesh.FACE_Y

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.35, 0.12, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.3
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_mesh.material = mat

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = grass_mesh
	mm.instance_count = count

	for i in count:
		var x: float = rng.randf_range(-CHUNK_SIZE_X * 0.5, CHUNK_SIZE_X * 0.5)
		var z: float = rng.randf_range(z_range.x, z_range.y)
		var scale_f: float = rng.randf_range(0.5, 1.3)
		var rot_y: float = rng.randf_range(0.0, TAU)

		var t: Transform3D = Transform3D.IDENTITY
		t = t.scaled(Vector3(scale_f, scale_f, scale_f))
		t = t.rotated(Vector3.UP, rot_y)
		t.origin = Vector3(x, 0.05, z)
		mm.set_instance_transform(i, t)

		var green_var: float = rng.randf_range(0.8, 1.2)
		mm.set_instance_color(i, Color(0.18, 0.35 * green_var, 0.12, 0.9))

	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = VIS_RANGE_GRASS
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	container.add_child(mmi)


# ═══════════════════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

func _get_zone_for_z(z: float) -> int:
	var best_idx: int = 0
	var best_dist: float = INF
	for i in _zone_centers.size():
		var d: float = absf(z - _zone_centers[i].z)
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx


func _is_on_path(pos: Vector3, min_dist: float) -> bool:
	var min_dist_sq: float = min_dist * min_dist
	for i in range(0, _path_points.size(), 4):
		var dx: float = pos.x - _path_points[i].x
		var dz: float = pos.z - _path_points[i].z
		if dx * dx + dz * dz < min_dist_sq:
			return true
	return false


func _build_chunk_full(ci: int) -> void:
	if not _chunks.has(ci):
		return
	if _chunks[ci]["state"] != ChunkState.QUEUED:
		return
	_queue_chunk_build(ci)
	var chunk: Dictionary = _chunks[ci]
	var pending: Array = chunk["pending_keys"]
	var container: Node3D = chunk["container"]
	var rng: RandomNumberGenerator = chunk["rng"]

	while pending.size() > 0:
		var key: String = pending.pop_front() as String
		if key == "_grass_carpet":
			var zone_idx: int = int(chunk.get("_zone_idx", 0))
			var density: Array = ZONE_DENSITY[zone_idx] if zone_idx < ZONE_DENSITY.size() else ZONE_DENSITY[0]
			var grass_count: int = int(float(density[3]) * 2.0 * _density_mult)
			var z_range: Vector2 = chunk["_z_range"] as Vector2
			_spawn_multimesh_grass(container, rng, z_range, grass_count)
		else:
			var transforms: Dictionary = chunk["transforms"]
			if transforms.has(key):
				_finalize_multimesh(container, key, transforms[key] as Array[Transform3D])
		chunk["node_count"] += 1

	chunk["state"] = ChunkState.ACTIVE
	chunk.erase("transforms")
	chunk.erase("pending_keys")
	chunk.erase("_zone_idx")
	chunk.erase("_z_range")


func get_active_chunk_count() -> int:
	var count: int = 0
	for ci: int in _chunks:
		if _chunks[ci]["state"] == ChunkState.ACTIVE:
			count += 1
	return count


func get_total_node_count() -> int:
	var total: int = 0
	for ci: int in _chunks:
		total += int(_chunks[ci].get("node_count", 0))
	return total
