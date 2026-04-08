extends Node3D
## BK Showcase Scene — procedurally places BK assets with BK-style environment.
## Builds a Broceliande forest clearing at runtime from GLB assets.

const ASSET_BASE: String = "res://Assets/bk_assets/"
const BIOME: String = "foret_broceliande"

# Layout: category, subfolder, count, radius_min, radius_max, scale_min, scale_max, y_offset
# Assets are now real-world scale (1 unit = 1 meter), so scale_min/max are minor variation only.
const PLACEMENTS: Array = [
	["vegetation", "vegetation", 6, 12.0, 35.0, 0.85, 1.2, 0.0],
	["rocks", "rocks", 8, 6.0, 30.0, 0.8, 1.3, 0.0],
	["megaliths", "megaliths", 4, 14.0, 28.0, 0.9, 1.15, 0.0],
	["structures", "structures", 2, 16.0, 24.0, 0.95, 1.05, 0.0],
	["collectibles", "collectibles", 5, 4.0, 20.0, 0.9, 1.1, 0.15],
	["characters", "characters", 3, 8.0, 18.0, 0.9, 1.1, 0.0],
	["props", "props", 2, 10.0, 22.0, 0.95, 1.05, 0.0],
]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2026
	# Hide ScreenFrame border overlay in this showcase scene
	var sf: Node = get_node_or_null("/root/ScreenFrame")
	if sf and sf is CanvasLayer:
		sf.visible = false
	print("[BKShowcase] Building scene...")
	_build_ground()
	print("[BKShowcase] Ground built, children: ", get_child_count())
	_build_environment()
	print("[BKShowcase] Environment built, children: ", get_child_count())
	_place_assets()
	print("[BKShowcase] Assets placed, children: ", get_child_count())
	# Dense vegetation background via universal MultiMesh system
	var VegMgr = preload("res://scripts/vegetation/vegetation_manager.gd")
	var VegPresets = preload("res://scripts/vegetation/vegetation_presets.gd")
	var _veg: RefCounted = VegMgr.new()
	_veg.setup(self, VegPresets.bk_showcase())
	print("[BKShowcase] Vegetation: ", _veg.get_stats())
	_add_info_label()


func _build_ground() -> void:
	# Large green ground plane with BK vertex colors
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = Vector2(80.0, 80.0)
	mesh.subdivide_width = 24
	mesh.subdivide_depth = 24

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.353, 0.541, 0.227)  # GRASS_GREEN
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.metallic_specular = 0.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX

	var ground_inst: MeshInstance3D = MeshInstance3D.new()
	ground_inst.mesh = mesh
	ground_inst.material_override = mat
	ground_inst.name = "Ground"
	add_child(ground_inst)

	# Secondary darker ring around edges
	var ring_mesh: PlaneMesh = PlaneMesh.new()
	ring_mesh.size = Vector2(140.0, 140.0)
	ring_mesh.subdivide_width = 4
	ring_mesh.subdivide_depth = 4

	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.227, 0.416, 0.165)  # MOSS_GREEN
	ring_mat.roughness = 1.0
	ring_mat.metallic = 0.0
	ring_mat.metallic_specular = 0.0

	var ring_inst: MeshInstance3D = MeshInstance3D.new()
	ring_inst.mesh = ring_mesh
	ring_inst.material_override = ring_mat
	ring_inst.position.y = -0.01
	ring_inst.name = "GroundEdge"
	add_child(ring_inst)

	# Dirt path — narrow strip
	var path_mesh: PlaneMesh = PlaneMesh.new()
	path_mesh.size = Vector2(4.0, 70.0)

	var path_mat: StandardMaterial3D = StandardMaterial3D.new()
	path_mat.albedo_color = Color(0.616, 0.404, 0.286)  # BANJO_BROWN
	path_mat.roughness = 1.0
	path_mat.metallic = 0.0
	path_mat.metallic_specular = 0.0

	var path_inst: MeshInstance3D = MeshInstance3D.new()
	path_inst.mesh = path_mesh
	path_inst.material_override = path_mat
	path_inst.position.y = 0.005
	path_inst.name = "DirtPath"
	add_child(path_inst)


func _build_environment() -> void:
	# Override project clear color for BK sky
	RenderingServer.set_default_clear_color(Color(0.349, 0.749, 0.780))

	# WorldEnvironment with BK-style warm sky and fog
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.349, 0.749, 0.780)  # SKY_CYAN
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.941, 0.910, 0.816)  # CREAM_LIGHT
	env.ambient_light_energy = 0.6

	# BK fog — matches sky color, warm
	env.fog_enabled = true
	env.fog_light_color = Color(0.349, 0.749, 0.780)  # Same as sky
	env.fog_density = 0.005

	# Tonemap for warm BK look
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0

	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	world_env.name = "WorldEnvironment"
	add_child(world_env)

	# Key light — warm sun (BK signature warm sunlight)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	sun.name = "SunLight"
	add_child(sun)

	# Fill light — cool blue from opposite side
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = 0.5
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-30.0, -150.0, 0.0)
	fill.name = "FillLight"
	add_child(fill)


func _place_assets() -> void:
	var placed_positions: Array[Vector3] = []

	for placement in PLACEMENTS:
		var category: String = placement[0]
		var subfolder: String = placement[1]
		var count: int = placement[2]
		var r_min: float = placement[3]
		var r_max: float = placement[4]
		var s_min: float = placement[5]
		var s_max: float = placement[6]
		var y_off: float = placement[7]

		# Find available GLB files for this category
		var dir_path: String = ASSET_BASE + subfolder + "/" + BIOME + "/"
		var glb_files: Array = _scan_glb_files(dir_path)

		if glb_files.is_empty():
			push_warning("BKShowcase: No GLB files in " + dir_path)
			continue

		for i in range(count):
			var glb_path: String = glb_files[i % glb_files.size()]
			_spawn_asset(glb_path, category, i, r_min, r_max, s_min, s_max, y_off, placed_positions)


func _scan_glb_files(dir_path: String) -> Array:
	var files: Array = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		print("[BKShowcase] DirAccess.open FAILED for: ", dir_path)
		return files
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".glb"):
			files.append(dir_path + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("[BKShowcase] Scanned ", dir_path, " -> ", files.size(), " GLBs")
	return files


func _spawn_asset(glb_path: String, category: String, index: int,
		r_min: float, r_max: float, s_min: float, s_max: float,
		y_off: float, placed_positions: Array) -> void:
	# Load GLB as PackedScene
	var scene: PackedScene = load(glb_path) as PackedScene
	if scene == null:
		push_warning("BKShowcase: Failed to load " + glb_path)
		return

	var instance: Node3D = scene.instantiate() as Node3D
	if instance == null:
		return

	# Find non-overlapping position (skip if all attempts fail)
	var pos: Vector3 = Vector3.ZERO
	var min_dist: float = 3.0
	var found_spot: bool = false
	for _attempt in range(30):
		var angle: float = _rng.randf() * TAU
		var radius: float = _rng.randf_range(r_min, r_max)
		pos = Vector3(cos(angle) * radius, y_off, sin(angle) * radius)

		var too_close: bool = false
		for existing in placed_positions:
			if pos.distance_to(existing as Vector3) < min_dist:
				too_close = true
				break
		if not too_close:
			found_spot = true
			break

	if not found_spot:
		instance.queue_free()
		push_warning("BKShowcase: Could not place " + glb_path + " without overlap, skipping")
		return

	placed_positions.append(pos)

	instance.position = pos
	instance.rotation.y = _rng.randf() * TAU

	var s: float = _rng.randf_range(s_min, s_max)
	instance.scale = Vector3(s, s, s)

	instance.name = category + "_" + str(index)
	add_child(instance)


func _add_info_label() -> void:
	# HUD with controls info
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var label: Label = Label.new()
	label.text = "BK Showcase - Foret de Broceliande\nWASD: Move | Mouse: Look | Shift: Fast | Scroll: Speed | Esc: Release mouse"
	label.position = Vector2(16, 16)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.941, 0.910, 0.816))  # CREAM_LIGHT
	label.add_theme_color_override("font_shadow_color", Color(0.286, 0.235, 0.184, 0.8))  # SHADOW_BROWN
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)
