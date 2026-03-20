extends RefCounted
## ForestTerrainBuilder — Ground plane, path terrain with roots and glow markers.
## Extracted from BroceliandeForest3D for file size reduction.

var _world_root: Node3D
var _forest_root: Node3D
var _zone_centers: Array[Vector3]
var _path_points: PackedVector3Array
var _rng: RandomNumberGenerator
var _asset_spawner: RefCounted  # ForestAssetSpawner
var _biome_config: Dictionary = {}  # From BiomeWalkConfigs


func _init(
	world_root: Node3D,
	forest_root: Node3D,
	zone_centers: Array[Vector3],
	path_points: PackedVector3Array,
	rng: RandomNumberGenerator,
	asset_spawner: RefCounted,
) -> void:
	_world_root = world_root
	_forest_root = forest_root
	_zone_centers = zone_centers
	_path_points = path_points
	_rng = rng
	_asset_spawner = asset_spawner


func set_biome_config(biome_key: String) -> void:
	_biome_config = BiomeWalkConfigs.get_config(biome_key)


func _get_terrain_color() -> Color:
	return _biome_config.get("terrain_color", Color(0.22, 0.35, 0.18))


func build_ground() -> void:
	var ground: StaticBody3D = StaticBody3D.new()
	ground.name = "Ground"
	_world_root.add_child(ground)

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
	mat.albedo_color = _get_terrain_color()
	mat.roughness = 0.95
	mi.material_override = mat
	ground.add_child(mi)


func build_path_terrain() -> void:
	# Batched path rendering — 3 MultiMesh instead of ~500 individual MeshInstance3D
	var dirt_mat: StandardMaterial3D = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.40, 0.30, 0.18)
	dirt_mat.roughness = 0.95

	var root_mat: StandardMaterial3D = StandardMaterial3D.new()
	root_mat.albedo_color = Color(0.15, 0.10, 0.06)
	root_mat.roughness = 1.0

	var glow_mat: StandardMaterial3D = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.3, 0.9, 0.5, 0.8)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.3, 0.9, 0.5)
	glow_mat.emission_energy_multiplier = 3.0
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Pass 1: Collect transforms
	var dirt_xforms: Array[Transform3D] = []
	var root_xforms: Array[Transform3D] = []
	var glow_xforms: Array[Transform3D] = []

	for i in range(_path_points.size() - 1):
		var a: Vector3 = _path_points[i]
		var b: Vector3 = _path_points[i + 1]
		var mid: Vector3 = (a + b) * 0.5
		var seg_length: float = a.distance_to(b)
		if seg_length < 0.05:
			continue

		var zone_idx: int = _get_zone_for_pos(mid)
		var width: float = 2.0
		if zone_idx in [2, 5, 6]:
			width = 3.0
		elif zone_idx == 4:
			width = 1.5

		# Dirt segment transform (unit box scaled to width×0.06×length)
		var dir: Vector3 = (b - a).normalized()
		var rot_y: float = atan2(dir.x, dir.z) if dir.length() > 0.001 else 0.0
		var dt: Transform3D = Transform3D.IDENTITY
		dt = dt.scaled(Vector3(width, 0.06, seg_length + 0.3))
		dt = dt.rotated(Vector3.UP, rot_y)
		dt.origin = mid + Vector3(0.0, 0.03, 0.0)
		dirt_xforms.append(dt)

		# Root details (every 3rd segment)
		if i % 3 == 0:
			for side_sign in [-1.0, 1.0]:
				var root_len: float = _rng.randf_range(0.5, 1.2)
				var rt: Transform3D = Transform3D.IDENTITY
				rt = rt.scaled(Vector3(0.15, 0.04, root_len))
				rt = rt.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5) + rot_y)
				rt.origin = mid + Vector3(side_sign * width * 0.4, 0.04, 0.0)
				root_xforms.append(rt)

		# Glow markers in dark zones
		if zone_idx in [3, 4] and i % 8 == 0:
			for side_sign in [-1.0, 1.0]:
				var gt: Transform3D = Transform3D.IDENTITY
				gt = gt.scaled(Vector3(0.12, 0.12, 0.12))
				gt = gt.rotated(Vector3.RIGHT, deg_to_rad(-90.0))
				gt.origin = mid + Vector3(side_sign * (width * 0.5 + 0.2), 0.08, 0.0)
				glow_xforms.append(gt)

	# Pass 2: Create batched MultiMesh nodes
	_create_path_multimesh(dirt_xforms, BoxMesh.new(), dirt_mat)
	if not root_xforms.is_empty():
		_create_path_multimesh(root_xforms, BoxMesh.new(), root_mat)
	if not glow_xforms.is_empty():
		var glow_mesh: QuadMesh = QuadMesh.new()
		glow_mesh.size = Vector2(1.0, 1.0)
		_create_path_multimesh(glow_xforms, glow_mesh, glow_mat)

	# Stone markers at zone transitions
	for i in range(1, _zone_centers.size()):
		var closest_idx: int = _find_closest_path_point(_zone_centers[i])
		if closest_idx >= 0 and closest_idx < _path_points.size():
			var pt: Vector3 = _path_points[closest_idx]
			_asset_spawner.spawn_broc("menhir_01", pt + Vector3(_rng.randf_range(2.0, 3.5), 0.0, 0.0), _rng.randf_range(1.0, 1.8))


func _create_path_multimesh(xforms: Array[Transform3D], mesh: Mesh, mat: Material) -> void:
	if xforms.is_empty():
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_forest_root.add_child(mmi)


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
