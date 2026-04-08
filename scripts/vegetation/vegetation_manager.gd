## VegetationManager — Universal dense vegetation system with MultiMesh LOD.
## Supports two modes:
##   "static"  — scatter all layers at setup (BKForestTestRoom, BKShowcase, etc.)
##   "chunked" — reserved for BrocChunkManager integration (not implemented here)
## All vegetation batched into MultiMesh (1 draw call per mesh type).
## Per-instance color jitter for visual variety.
## Cross-billboard grass carpet with wind shader.

extends RefCounted

const MultiMeshPoolClass = preload("res://scripts/vegetation/multimesh_pool.gd")
const GrassCarpetClass = preload("res://scripts/vegetation/grass_carpet.gd")

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _root: Node3D
var _pool: RefCounted  # MultiMeshPool
var _config: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _container: Node3D  # Parent for all MultiMeshInstance3D nodes
var _density_mult: float = 1.0

# Stats
var _total_instances: int = 0
var _total_draw_calls: int = 0


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Initialize and build all vegetation layers.
## config: see VegetationPresets for schema.
## pool: optional pre-loaded MultiMeshPool (created internally if null).
func setup(root: Node3D, config: Dictionary, pool: RefCounted = null) -> void:
	_root = root
	_config = config
	_rng.seed = config.get("seed", 42) as int

	_container = Node3D.new()
	_container.name = "VegetationContainer"
	_root.add_child(_container)

	if pool:
		_pool = pool
	else:
		_pool = MultiMeshPoolClass.new()

	# Register all asset layers into pool
	var layers: Dictionary = config.get("layers", {}) as Dictionary
	for layer_name: String in layers:
		var layer: Dictionary = layers[layer_name] as Dictionary
		var paths: Array = layer.get("paths", []) as Array
		if paths.size() > 0:
			var typed_paths: Array[String] = []
			for p in paths:
				typed_paths.append(str(p))
			_pool.register_glb_paths(layer_name, typed_paths)

	var mode: String = config.get("mode", "static") as String
	if mode == "static":
		_build_static()


## Called every frame in chunked mode. No-op in static mode.
func update(_camera_pos: Vector3) -> void:
	pass  # Static mode: LOD handled by visibility_range, no per-frame work


## Adjust density multiplier at runtime.
func set_density_multiplier(mult: float) -> void:
	_density_mult = clampf(mult, 0.1, 10.0)


## Get current stats.
func get_stats() -> Dictionary:
	return {
		"instances": _total_instances,
		"draw_calls_est": _total_draw_calls,
		"tris_est": _total_instances * 30,  # rough average
	}


## Remove all vegetation from scene.
func cleanup() -> void:
	if _container and is_instance_valid(_container):
		_container.queue_free()
	_total_instances = 0
	_total_draw_calls = 0


# ═══════════════════════════════════════════════════════════════════════════════
# STATIC MODE BUILD
# ═══════════════════════════════════════════════════════════════════════════════

func _build_static() -> void:
	var area: Rect2 = _config.get("area", Rect2(-60, -60, 120, 120)) as Rect2
	var layers: Dictionary = _config.get("layers", {}) as Dictionary
	var path_clear: float = _config.get("path_clearance", 0.0) as float
	var exclusions: Array = _config.get("exclusion_zones", []) as Array
	var height_func: Callable = _config.get("height_func", Callable()) as Callable

	# Build GLB-based layers (trees, bushes, groundcover, mushrooms, deadwood, rocks)
	for layer_name: String in ["trees", "bushes", "groundcover", "mushrooms", "deadwood", "rocks"]:
		if not layers.has(layer_name):
			continue
		var layer: Dictionary = layers[layer_name] as Dictionary
		_build_glb_layer(layer_name, layer, area, path_clear, exclusions, height_func)

	# Build procedural grass carpet
	if layers.has("grass"):
		var grass_cfg: Dictionary = layers["grass"] as Dictionary
		if grass_cfg.get("enabled", false) as bool:
			_build_grass_carpet(grass_cfg, area, height_func)

	# Build canopy spheres (procedural, placed above trees)
	if layers.has("canopy"):
		var canopy_cfg: Dictionary = layers["canopy"] as Dictionary
		if canopy_cfg.get("enabled", false) as bool:
			_build_canopy(canopy_cfg, layers.get("trees", {}) as Dictionary, area, height_func)

	# Build billboard impostors (far-field tree silhouettes)
	if layers.has("billboard"):
		var bb_cfg: Dictionary = layers["billboard"] as Dictionary
		if bb_cfg.get("enabled", false) as bool:
			_build_billboards(bb_cfg, layers.get("trees", {}) as Dictionary, area, height_func)

	print("[VegetationManager] Built %d instances in %d draw calls" % [_total_instances, _total_draw_calls])


# ═══════════════════════════════════════════════════════════════════════════════
# GLB LAYER BUILDER
# ═══════════════════════════════════════════════════════════════════════════════

func _build_glb_layer(layer_name: String, layer: Dictionary, area: Rect2,
		path_clear: float, exclusions: Array, height_func: Callable) -> void:
	var density: float = layer.get("density", 0.1) as float
	var scale_range: Vector2 = layer.get("scale", Vector2(0.8, 1.2)) as Vector2
	var vis_range: Vector2 = layer.get("vis", Vector2(0, 30)) as Vector2
	var cluster_ratio: float = layer.get("cluster", 0.0) as float

	var area_m2: float = area.size.x * area.size.y
	var count: int = int(area_m2 * density * _density_mult)
	if count <= 0:
		return

	var keys: Array[String] = _pool.get_keys_with_prefix(layer_name)
	if keys.is_empty():
		return

	# Generate transforms per key (distribute evenly across variants)
	var xform_groups: Dictionary = {}
	for key in keys:
		xform_groups[key] = [] as Array[Transform3D]

	# Clustering: some instances in tight groups
	var cluster_centers: Array[Vector3] = []
	if cluster_ratio > 0.0:
		var num_clusters: int = maxi(1, int(float(count) * 0.1))
		for _c in num_clusters:
			cluster_centers.append(Vector3(
				_rng.randf_range(area.position.x + 5.0, area.position.x + area.size.x - 5.0),
				0.0,
				_rng.randf_range(area.position.y + 5.0, area.position.y + area.size.y - 5.0),
			))

	for i in count:
		var pos: Vector3
		var is_cluster: bool = cluster_ratio > 0.0 and _rng.randf() < cluster_ratio and not cluster_centers.is_empty()

		if is_cluster:
			var cc: Vector3 = cluster_centers[_rng.randi() % cluster_centers.size()]
			pos = cc + Vector3(_rng.randf_range(-2.5, 2.5), 0.0, _rng.randf_range(-2.5, 2.5))
		else:
			pos = Vector3(
				_rng.randf_range(area.position.x, area.position.x + area.size.x),
				0.0,
				_rng.randf_range(area.position.y, area.position.y + area.size.y),
			)

		# Path clearance
		if path_clear > 0.0 and _is_on_path(pos, path_clear):
			continue

		# Exclusion zones
		if _is_excluded(pos, exclusions):
			continue

		# Height sampling
		if height_func.is_valid():
			pos.y = height_func.call(pos.x, pos.z) as float

		var scale_f: float = _rng.randf_range(scale_range.x, scale_range.y)
		var rot_y: float = _rng.randf_range(0.0, TAU)

		var t: Transform3D = Transform3D.IDENTITY
		t = t.scaled(Vector3(scale_f, scale_f, scale_f))
		t = t.rotated(Vector3.UP, rot_y)
		t.origin = pos

		var key: String = keys[i % keys.size()]
		xform_groups[key].append(t)

	# Finalize each key into a MultiMeshInstance3D
	for key: String in xform_groups:
		var xforms: Array[Transform3D] = xform_groups[key] as Array[Transform3D]
		if xforms.is_empty():
			continue
		_finalize_multimesh(key, xforms, vis_range, layer_name)


# ═══════════════════════════════════════════════════════════════════════════════
# GRASS CARPET
# ═══════════════════════════════════════════════════════════════════════════════

func _build_grass_carpet(grass_cfg: Dictionary, area: Rect2, height_func: Callable) -> void:
	var density: float = grass_cfg.get("density", 5.0) as float
	var area_m2: float = area.size.x * area.size.y
	var count: int = int(area_m2 * density * _density_mult)
	count = mini(count, 8000)  # Safety cap

	var carpet: RefCounted = GrassCarpetClass.new()
	var mmi: MultiMeshInstance3D = carpet.build(null, _rng, area, count, grass_cfg)
	if mmi:
		# Apply height offsets if height function available
		if height_func.is_valid() and mmi.multimesh:
			var mm: MultiMesh = mmi.multimesh
			for i in mm.instance_count:
				var t: Transform3D = mm.get_instance_transform(i)
				t.origin.y = height_func.call(t.origin.x, t.origin.z) as float + 0.05
				mm.set_instance_transform(i, t)

		_container.add_child(mmi)
		_total_instances += count
		_total_draw_calls += 1
		print("[VegetationManager] Grass carpet: %d blades" % count)


# ═══════════════════════════════════════════════════════════════════════════════
# CANOPY SPHERES
# ═══════════════════════════════════════════════════════════════════════════════

func _build_canopy(canopy_cfg: Dictionary, tree_layer: Dictionary, area: Rect2, height_func: Callable) -> void:
	var vis_end: float = canopy_cfg.get("vis_end", 30.0) as float
	var density: float = tree_layer.get("density", 0.08) as float
	var area_m2: float = area.size.x * area.size.y
	var count: int = int(area_m2 * density * _density_mult)
	if count <= 0:
		return

	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.2
	sphere.radial_segments = 6
	sphere.rings = 3

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sphere
	mm.instance_count = count

	var canopy_base: Color = Color(0.25, 0.50, 0.18)

	for i in count:
		var x: float = _rng.randf_range(area.position.x, area.position.x + area.size.x)
		var z: float = _rng.randf_range(area.position.y, area.position.y + area.size.y)
		var base_y: float = 0.0
		if height_func.is_valid():
			base_y = height_func.call(x, z) as float
		var scale_f: float = _rng.randf_range(1.5, 3.5)
		var height_off: float = _rng.randf_range(3.0, 6.0)

		var t: Transform3D = Transform3D.IDENTITY
		t = t.scaled(Vector3(scale_f, scale_f * 0.8, scale_f))
		t.origin = Vector3(x, base_y + height_off, z)
		mm.set_instance_transform(i, t)

		# Color variation
		var tint: float = _rng.randf_range(0.0, 0.4)
		mm.set_instance_color(i, canopy_base.lerp(Color(0.35, 0.60, 0.22), tint))

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = vis_end
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.name = "CanopySpheres"
	_container.add_child(mmi)
	_total_instances += count
	_total_draw_calls += 1


# ═══════════════════════════════════════════════════════════════════════════════
# BILLBOARD IMPOSTORS
# ═══════════════════════════════════════════════════════════════════════════════

func _build_billboards(bb_cfg: Dictionary, tree_layer: Dictionary, area: Rect2, height_func: Callable) -> void:
	var vis: Vector2 = bb_cfg.get("vis", Vector2(35, 60)) as Vector2
	var ratio: float = bb_cfg.get("ratio", 0.4) as float
	var density: float = tree_layer.get("density", 0.08) as float
	var area_m2: float = area.size.x * area.size.y
	var count: int = int(area_m2 * density * ratio * _density_mult)
	if count <= 0:
		return

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.1

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = count

	var billboard_color: Color = Color(0.30, 0.55, 0.20, 0.85)

	for i in count:
		var x: float = _rng.randf_range(area.position.x, area.position.x + area.size.x)
		var z: float = _rng.randf_range(area.position.y, area.position.y + area.size.y)
		var base_y: float = 0.0
		if height_func.is_valid():
			base_y = height_func.call(x, z) as float
		var h: float = _rng.randf_range(4.0, 8.0)

		var t: Transform3D = Transform3D.IDENTITY
		t = t.scaled(Vector3(h * 0.4, h, 0.1))
		t.origin = Vector3(x, base_y + h * 0.5, z)
		mm.set_instance_transform(i, t)

		var tint: float = _rng.randf_range(-0.1, 0.15)
		mm.set_instance_color(i, Color(
			billboard_color.r + tint,
			billboard_color.g + tint * 1.2,
			billboard_color.b + tint * 0.5,
			billboard_color.a
		))

	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_begin = vis.x
	mmi.visibility_range_end = vis.y
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.name = "BillboardImpostors"
	_container.add_child(mmi)
	_total_instances += count
	_total_draw_calls += 1


# ═══════════════════════════════════════════════════════════════════════════════
# MULTIMESH FINALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _finalize_multimesh(key: String, xforms: Array[Transform3D], vis_range: Vector2, layer_name: String) -> void:
	var mesh: Mesh = _pool.get_mesh(key)
	if not mesh:
		return

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()

	# Determine base color for this layer type
	var base_color: Color = _get_layer_color(layer_name)

	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		# Per-instance color jitter
		var jitter: float = _rng.randf_range(0.85, 1.15)
		mm.set_instance_color(i, Color(
			clampf(base_color.r * jitter, 0.0, 1.0),
			clampf(base_color.g * jitter, 0.0, 1.0),
			clampf(base_color.b * jitter, 0.0, 1.0),
			base_color.a
		))

	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Apply material from pool
	var mat: Material = _pool.get_material(key)
	if mat:
		mmi.material_override = mat

	# Visibility range LOD
	mmi.visibility_range_begin = vis_range.x
	mmi.visibility_range_end = vis_range.y
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.name = "MM_%s" % key

	_container.add_child(mmi)
	_total_instances += xforms.size()
	_total_draw_calls += 1


# ═══════════════════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

func _get_layer_color(layer_name: String) -> Color:
	match layer_name:
		"trees":
			return Color(0.45, 0.55, 0.30, 1.0)
		"bushes":
			return Color(0.35, 0.50, 0.25, 1.0)
		"groundcover":
			return Color(0.30, 0.55, 0.20, 1.0)
		"mushrooms":
			return Color(0.70, 0.50, 0.30, 1.0)
		"deadwood":
			return Color(0.50, 0.38, 0.25, 1.0)
		"rocks":
			return Color(0.55, 0.52, 0.48, 1.0)
		_:
			return Color(0.5, 0.5, 0.5, 1.0)


func _is_on_path(pos: Vector3, clearance: float) -> bool:
	# Simple sine-based path approximation (matches BKForestTestRoom)
	var path_x: float = sin(pos.z * 0.05) * 3.0
	return absf(pos.x - path_x) < clearance


func _is_excluded(pos: Vector3, exclusions: Array) -> bool:
	for zone in exclusions:
		if zone is Rect2:
			var r: Rect2 = zone as Rect2
			if r.has_point(Vector2(pos.x, pos.z)):
				return true
	return false
