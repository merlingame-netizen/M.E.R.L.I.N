extends Node3D
## BK Forest Test Room v3 — Dense forest with true BK poly budgets.
## 72 unique assets across 12 generators, ~3,000-5,000 tris visible scene.

# --- Asset paths (12 categories from BK_N64_ASSET_BIBLE.md) ---
const BK: String = "res://Assets/bk_assets/"
const BI: String = "foret_broceliande/"
const OLD: String = "res://Assets/3d_models/"

const BK_TREES: Array[String] = [
	BK + "vegetation/" + BI + "tree_bk_foret_broceliande_0000.glb",
	BK + "vegetation/" + BI + "tree_bk_foret_broceliande_0001.glb",
	BK + "vegetation/" + BI + "tree_bk_foret_broceliande_0002.glb",
	BK + "vegetation/" + BI + "tree_bk_foret_broceliande_0003.glb",
	BK + "vegetation/" + BI + "tree_bk_foret_broceliande_0004.glb",
	BK + "vegetation/" + BI + "tree_bk_foret_broceliande_0005.glb",
]
const BK_BUSHES: Array[String] = [
	BK + "bushes/" + BI + "bush_bk_foret_broceliande_0000.glb",
	BK + "bushes/" + BI + "bush_bk_foret_broceliande_0001.glb",
	BK + "bushes/" + BI + "bush_bk_foret_broceliande_0002.glb",
	BK + "bushes/" + BI + "bush_bk_foret_broceliande_0003.glb",
	BK + "bushes/" + BI + "bush_bk_foret_broceliande_0004.glb",
	BK + "bushes/" + BI + "bush_bk_foret_broceliande_0005.glb",
]
const BK_GROUND: Array[String] = [
	BK + "groundcover/" + BI + "groundcover_bk_foret_broceliande_0000.glb",
	BK + "groundcover/" + BI + "groundcover_bk_foret_broceliande_0001.glb",
	BK + "groundcover/" + BI + "groundcover_bk_foret_broceliande_0002.glb",
	BK + "groundcover/" + BI + "groundcover_bk_foret_broceliande_0003.glb",
	BK + "groundcover/" + BI + "groundcover_bk_foret_broceliande_0004.glb",
	BK + "groundcover/" + BI + "groundcover_bk_foret_broceliande_0005.glb",
]
const BK_MUSHROOMS: Array[String] = [
	BK + "mushrooms/" + BI + "mushroom_bk_foret_broceliande_0000.glb",
	BK + "mushrooms/" + BI + "mushroom_bk_foret_broceliande_0001.glb",
	BK + "mushrooms/" + BI + "mushroom_bk_foret_broceliande_0002.glb",
	BK + "mushrooms/" + BI + "mushroom_bk_foret_broceliande_0003.glb",
	BK + "mushrooms/" + BI + "mushroom_bk_foret_broceliande_0004.glb",
	BK + "mushrooms/" + BI + "mushroom_bk_foret_broceliande_0005.glb",
]
const BK_DEADWOOD: Array[String] = [
	BK + "deadwood/" + BI + "deadwood_bk_foret_broceliande_0000.glb",
	BK + "deadwood/" + BI + "deadwood_bk_foret_broceliande_0001.glb",
	BK + "deadwood/" + BI + "deadwood_bk_foret_broceliande_0002.glb",
	BK + "deadwood/" + BI + "deadwood_bk_foret_broceliande_0003.glb",
	BK + "deadwood/" + BI + "deadwood_bk_foret_broceliande_0004.glb",
	BK + "deadwood/" + BI + "deadwood_bk_foret_broceliande_0005.glb",
]
const BK_ROCKS: Array[String] = [
	BK + "rocks/" + BI + "rock_bk_foret_broceliande_0000.glb",
	BK + "rocks/" + BI + "rock_bk_foret_broceliande_0001.glb",
	BK + "rocks/" + BI + "rock_bk_foret_broceliande_0002.glb",
	BK + "rocks/" + BI + "rock_bk_foret_broceliande_0003.glb",
	BK + "rocks/" + BI + "rock_bk_foret_broceliande_0004.glb",
	BK + "rocks/" + BI + "rock_bk_foret_broceliande_0005.glb",
]
const BK_MEGALITHS: Array[String] = [
	BK + "megaliths/" + BI + "megalith_bk_foret_broceliande_0000.glb",
	BK + "megaliths/" + BI + "megalith_bk_foret_broceliande_0001.glb",
	BK + "megaliths/" + BI + "megalith_bk_foret_broceliande_0002.glb",
	BK + "megaliths/" + BI + "megalith_bk_foret_broceliande_0003.glb",
	BK + "megaliths/" + BI + "megalith_bk_foret_broceliande_0004.glb",
	BK + "megaliths/" + BI + "megalith_bk_foret_broceliande_0005.glb",
]
const BK_STRUCTURES: Array[String] = [
	BK + "structures/" + BI + "structure_bk_foret_broceliande_0000.glb",
	BK + "structures/" + BI + "structure_bk_foret_broceliande_0001.glb",
	BK + "structures/" + BI + "structure_bk_foret_broceliande_0002.glb",
	BK + "structures/" + BI + "structure_bk_foret_broceliande_0003.glb",
	BK + "structures/" + BI + "structure_bk_foret_broceliande_0004.glb",
	BK + "structures/" + BI + "structure_bk_foret_broceliande_0005.glb",
]
const BK_COLLECTIBLES: Array[String] = [
	BK + "collectibles/" + BI + "collectible_bk_foret_broceliande_0000.glb",
	BK + "collectibles/" + BI + "collectible_bk_foret_broceliande_0001.glb",
	BK + "collectibles/" + BI + "collectible_bk_foret_broceliande_0002.glb",
	BK + "collectibles/" + BI + "collectible_bk_foret_broceliande_0003.glb",
	BK + "collectibles/" + BI + "collectible_bk_foret_broceliande_0004.glb",
	BK + "collectibles/" + BI + "collectible_bk_foret_broceliande_0005.glb",
]
const BK_CREATURES: Array[String] = [
	BK + "characters/" + BI + "creature_bk_foret_broceliande_0000.glb",
	BK + "characters/" + BI + "creature_bk_foret_broceliande_0001.glb",
	BK + "characters/" + BI + "creature_bk_foret_broceliande_0002.glb",
	BK + "characters/" + BI + "creature_bk_foret_broceliande_0003.glb",
	BK + "characters/" + BI + "creature_bk_foret_broceliande_0004.glb",
	BK + "characters/" + BI + "creature_bk_foret_broceliande_0005.glb",
]
const BK_BRIDGES: Array[String] = [
	BK + "props/" + BI + "bridge_bk_foret_broceliande_0000.glb",
	BK + "props/" + BI + "bridge_bk_foret_broceliande_0001.glb",
	BK + "props/" + BI + "bridge_bk_foret_broceliande_0002.glb",
	BK + "props/" + BI + "bridge_bk_foret_broceliande_0003.glb",
	BK + "props/" + BI + "bridge_bk_foret_broceliande_0004.glb",
	BK + "props/" + BI + "bridge_bk_foret_broceliande_0005.glb",
]
const BK_PROPS: Array[String] = [
	BK + "props/" + BI + "prop_bk_foret_broceliande_0000.glb",
	BK + "props/" + BI + "prop_bk_foret_broceliande_0001.glb",
	BK + "props/" + BI + "prop_bk_foret_broceliande_0002.glb",
	BK + "props/" + BI + "prop_bk_foret_broceliande_0003.glb",
	BK + "props/" + BI + "prop_bk_foret_broceliande_0004.glb",
	BK + "props/" + BI + "prop_bk_foret_broceliande_0005.glb",
]
const OLD_TREES: Array[String] = [
	OLD + "vegetation/01_Tree_Small.glb",
	OLD + "vegetation/02_Tree_Medium.glb",
	OLD + "vegetation/03_Tree_Large.glb",
]
const OLD_MEGALITHS: Array[String] = [
	OLD + "broceliande/megaliths/menhir_01.glb",
	OLD + "broceliande/megaliths/dolmen_01.glb",
]

# --- Terrain config ---
const TERRAIN_SIZE: float = 120.0
const TERRAIN_RES: int = 128
const CELL: float = TERRAIN_SIZE / float(TERRAIN_RES)

# BK palette
const COL_GRASS: Color = Color(0.42, 0.58, 0.22)
const COL_GRASS_DARK: Color = Color(0.22, 0.38, 0.14)
const COL_DIRT: Color = Color(0.55, 0.38, 0.22)
const COL_ROCK: Color = Color(0.55, 0.52, 0.48)
const COL_PATH: Color = Color(0.58, 0.42, 0.26)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _placed: Array[Vector3] = []
var _terrain_mesh: MeshInstance3D


func _ready() -> void:
	_rng.seed = 42
	for autoload_name in ["ScreenFrame", "ScreenDither", "MerlinBackdrop", "ScreenEffects"]:
		var node: Node = get_node_or_null("/root/" + autoload_name)
		if node and node is CanvasLayer:
			node.visible = false
	RenderingServer.set_default_clear_color(Color(0.45, 0.72, 0.82))

	_build_skydome()
	_build_n64_sun()
	_build_terrain()
	_build_dirt_path()
	_build_creek_bed()

	# Dense vegetation via universal MultiMesh system (replaces individual scatter)
	var VegMgr = preload("res://scripts/vegetation/vegetation_manager.gd")
	var VegPresets = preload("res://scripts/vegetation/vegetation_presets.gd")
	var veg_config: Dictionary = VegPresets.bk_forest_test_room()
	veg_config["height_func"] = Callable(self, "get_height")
	var _veg_mgr: RefCounted = VegMgr.new()
	_veg_mgr.setup(self, veg_config)

	# Manual unique placements (artistic composition, fixed positions)
	_place_megalith_hilltop()
	_place_clearing_structures()
	_place_creatures()
	_place_collectibles()
	_place_props_along_path()

	_add_fog_volumes()
	_add_fairy_particles()
	_add_ambient_lights()
	_add_weather_system()

	var cam: Camera3D = get_node_or_null("Camera")
	if cam and cam.has_method("set_terrain_sampler"):
		cam.set_terrain_sampler(self)

	var stats: Dictionary = _veg_mgr.get_stats()
	print("[BKForest] Dense forest built — %d veg instances, ~%d draw calls, %d nodes" % [stats["instances"], stats["draw_calls_est"], get_child_count()])


# ====================================================================
# SKYDOME — Inverted sphere with N64-style gradient vertex colors
# ====================================================================

var _sun_pivot: Node3D

func _build_skydome() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings: int = 16
	var sectors: int = 24
	var radius: float = 90.0

	var col_zenith: Color = Color(0.28, 0.52, 0.85)
	var col_mid: Color = Color(0.45, 0.72, 0.88)
	var col_horizon: Color = Color(0.75, 0.85, 0.70)
	var col_below: Color = Color(0.35, 0.55, 0.25)

	for i in range(rings + 1):
		var phi: float = PI * float(i) / float(rings)
		var y: float = cos(phi)
		var r: float = sin(phi)
		var t: float = float(i) / float(rings)

		var col: Color
		if t < 0.35:
			col = col_zenith.lerp(col_mid, t / 0.35)
		elif t < 0.5:
			col = col_mid.lerp(col_horizon, (t - 0.35) / 0.15)
		elif t < 0.6:
			col = col_horizon.lerp(col_below, (t - 0.5) / 0.1)
		else:
			col = col_below

		for j in range(sectors + 1):
			var theta: float = TAU * float(j) / float(sectors)
			var x: float = r * cos(theta)
			var z: float = r * sin(theta)
			st.set_normal(Vector3(-x, -y, -z).normalized())
			st.set_color(col)
			st.set_uv(Vector2(float(j) / float(sectors), t))
			st.add_vertex(Vector3(x * radius, y * radius, z * radius))

	for i in range(rings):
		for j in range(sectors):
			var a: int = i * (sectors + 1) + j
			var b: int = a + sectors + 1
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b + 1)

	var sky_mat: StandardMaterial3D = StandardMaterial3D.new()
	sky_mat.vertex_color_use_as_albedo = true
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	sky_mat.no_depth_test = true

	var sky_mesh: MeshInstance3D = MeshInstance3D.new()
	sky_mesh.mesh = st.commit()
	sky_mesh.material_override = sky_mat
	sky_mesh.name = "Skydome"
	sky_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky_mesh.sorting_offset = 100.0
	add_child(sky_mesh)


# ====================================================================
# N64 SUN — Billboard disc + lens flare cross
# ====================================================================

func _build_n64_sun() -> void:
	_sun_pivot = Node3D.new()
	_sun_pivot.name = "SunPivot"
	add_child(_sun_pivot)

	var sun_mat: StandardMaterial3D = StandardMaterial3D.new()
	sun_mat.albedo_color = Color(1.0, 0.95, 0.7)
	sun_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	sun_mat.no_depth_test = true
	sun_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var sun_mesh: SphereMesh = SphereMesh.new()
	sun_mesh.radius = 4.0
	sun_mesh.height = 8.0
	sun_mesh.radial_segments = 12
	sun_mesh.rings = 6

	var sun_inst: MeshInstance3D = MeshInstance3D.new()
	sun_inst.mesh = sun_mesh
	sun_inst.material_override = sun_mat
	sun_inst.position = Vector3(-30, 55, -40)
	sun_inst.name = "SunDisc"
	sun_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sun_pivot.add_child(sun_inst)

	var glow_mat: StandardMaterial3D = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.92, 0.5, 0.25)
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	glow_mat.no_depth_test = true
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var glow_mesh: SphereMesh = SphereMesh.new()
	glow_mesh.radius = 10.0
	glow_mesh.height = 20.0
	glow_mesh.radial_segments = 8
	glow_mesh.rings = 4

	var glow_inst: MeshInstance3D = MeshInstance3D.new()
	glow_inst.mesh = glow_mesh
	glow_inst.material_override = glow_mat
	glow_inst.position = sun_inst.position
	glow_inst.name = "SunGlow"
	glow_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sun_pivot.add_child(glow_inst)

	var flare_mat: StandardMaterial3D = StandardMaterial3D.new()
	flare_mat.albedo_color = Color(1.0, 0.95, 0.6, 0.15)
	flare_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flare_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flare_mat.no_depth_test = true
	flare_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flare_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for angle_deg in [0.0, 45.0]:
		var quad_mesh: QuadMesh = QuadMesh.new()
		quad_mesh.size = Vector2(30.0, 3.0)
		var flare: MeshInstance3D = MeshInstance3D.new()
		flare.mesh = quad_mesh
		flare.material_override = flare_mat
		flare.position = sun_inst.position
		flare.rotation_degrees.z = angle_deg
		flare.name = "Flare_%d" % int(angle_deg)
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sun_pivot.add_child(flare)


# ====================================================================
# TERRAIN — Procedural heightmap with vertex colors (BK style)
# ====================================================================

func get_height(x: float, z: float) -> float:
	var h: float = 0.0
	h += sin(x * 0.08) * cos(z * 0.06) * 2.5
	h += sin(x * 0.15 + z * 0.12) * 1.2
	h += cos(x * 0.04 - z * 0.07) * 1.8

	var dist_center: float = sqrt(x * x + z * z)
	var clearing_factor: float = clampf(1.0 - dist_center / 18.0, 0.0, 1.0)
	clearing_factor = clearing_factor * clearing_factor * clearing_factor
	h -= clearing_factor * 3.0

	var dx_m: float = x - 0.0
	var dz_m: float = z - (-22.0)
	var dist_mound: float = sqrt(dx_m * dx_m + dz_m * dz_m)
	var mound: float = clampf(1.0 - dist_mound / 12.0, 0.0, 1.0)
	mound = mound * mound
	h += mound * 4.5

	var creek_z: float = clampf((z - 5.0) / 20.0, 0.0, 1.0)
	var creek_x: float = exp(-(x - 8.0) * (x - 8.0) / 8.0)
	var creek_depth: float = creek_x * creek_z * (1.0 - creek_z) * 4.0 * 3.0
	h -= creek_depth

	var edge_dist: float = maxf(absf(x), absf(z))
	if edge_dist > 35.0:
		var rise: float = (edge_dist - 35.0) * 0.15
		h += rise * rise * 0.3
	return h


func _build_terrain() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = TERRAIN_SIZE * 0.5
	var res: int = TERRAIN_RES

	for iz in range(res + 1):
		for ix in range(res + 1):
			var x: float = -half + float(ix) * CELL
			var z: float = -half + float(iz) * CELL
			var y: float = get_height(x, z)

			var hx: float = get_height(x + 0.5, z)
			var hz: float = get_height(x, z + 0.5)
			var nx: float = y - hx
			var nz: float = y - hz
			var normal: Vector3 = Vector3(nx, 0.5, nz).normalized()

			var steepness: float = 1.0 - normal.y
			var path_dist: float = _dist_to_path(x, z)
			var is_path: bool = path_dist < 2.5

			var color: Color
			if is_path:
				color = COL_PATH.lerp(COL_GRASS, clampf((path_dist - 1.5) / 1.0, 0.0, 1.0))
			elif steepness > 0.4:
				color = COL_ROCK
			elif steepness > 0.15:
				color = COL_DIRT.lerp(COL_GRASS, clampf((0.4 - steepness) / 0.25, 0.0, 1.0))
			else:
				var grass_noise: float = sin(x * 0.5) * cos(z * 0.7) * 0.5 + 0.5
				color = COL_GRASS.lerp(COL_GRASS_DARK, grass_noise * 0.4)

			st.set_normal(normal)
			st.set_color(color)
			st.set_uv(Vector2(float(ix) / float(res), float(iz) / float(res)))
			st.add_vertex(Vector3(x, y, z))

	for iz in range(res):
		for ix in range(res):
			var i: int = iz * (res + 1) + ix
			st.add_index(i)
			st.add_index(i + res + 1)
			st.add_index(i + 1)
			st.add_index(i + 1)
			st.add_index(i + res + 1)
			st.add_index(i + res + 2)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.metallic = 0.0
	mat.metallic_specular = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_terrain_mesh = MeshInstance3D.new()
	_terrain_mesh.mesh = st.commit()
	_terrain_mesh.material_override = mat
	_terrain_mesh.name = "Terrain"
	_terrain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_terrain_mesh)

	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = COL_GRASS_DARK
	floor_mat.roughness = 1.0
	var floor_mesh: PlaneMesh = PlaneMesh.new()
	floor_mesh.size = Vector2(TERRAIN_SIZE * 1.5, TERRAIN_SIZE * 1.5)
	var floor_inst: MeshInstance3D = MeshInstance3D.new()
	floor_inst.mesh = floor_mesh
	floor_inst.material_override = floor_mat
	floor_inst.position.y = -5.0
	floor_inst.name = "SafetyFloor"
	floor_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_inst)


func _dist_to_path(x: float, z: float) -> float:
	var path_x: float = sin(z * 0.05) * 3.0
	return absf(x - path_x)


# ====================================================================
# CREEK BED + BRIDGE
# ====================================================================

func _build_creek_bed() -> void:
	var water_mat: StandardMaterial3D = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.12, 0.25, 0.35, 0.65)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.1
	water_mat.metallic = 0.3
	var water_mesh: PlaneMesh = PlaneMesh.new()
	water_mesh.size = Vector2(6.0, 18.0)
	var water: MeshInstance3D = MeshInstance3D.new()
	water.mesh = water_mesh
	water.material_override = water_mat
	water.position = Vector3(8.0, get_height(8.0, 15.0) - 0.6, 15.0)
	water.name = "CreekWater"
	add_child(water)
	_place_on_terrain(BK_BRIDGES[0], Vector3(8.0, 0, 14.0), 1.2, 0.0, 0.3)


func _build_dirt_path() -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = COL_PATH
	mat.roughness = 1.0
	var points: Array[Vector3] = []
	for z_step in range(-30, 31, 2):
		var z: float = float(z_step)
		var x: float = sin(z * 0.05) * 3.0
		var y: float = get_height(x, z) + 0.02
		points.append(Vector3(x, y, z))
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var mid: Vector3 = (a + b) * 0.5
		var length: float = a.distance_to(b)
		var angle: float = atan2(b.x - a.x, b.z - a.z)
		var mesh: PlaneMesh = PlaneMesh.new()
		mesh.size = Vector2(3.0, length + 0.5)
		var inst: MeshInstance3D = MeshInstance3D.new()
		inst.mesh = mesh
		inst.material_override = mat
		inst.position = mid
		inst.rotation.y = angle
		inst.name = "PathSeg_%d" % i
		add_child(inst)


# ====================================================================
# DENSE FOREST — BK composition: 3 rings of increasing density
# ====================================================================

func _place_forest_dense() -> void:
	# Inner ring: sparse, near clearing (6-8 trees, BK budget: 60 tris each = ~420 tris)
	_scatter_assets(BK_TREES, 8, 14.0, 24.0, 0.85, 1.15, 4.5)
	# Middle ring: denser (18-22 trees = ~1,200 tris)
	_scatter_assets(BK_TREES, 22, 24.0, 38.0, 0.9, 1.2, 3.2)
	# Outer ring: dense wall (35-40 trees = ~2,400 tris)
	_scatter_assets(BK_TREES, 38, 38.0, 55.0, 0.95, 1.3, 2.5)
	# Mixed in old project trees for variety (scaled to match)
	_scatter_assets(OLD_TREES, 12, 22.0, 50.0, 2.5, 4.0, 4.0)
	print("[BKForest] %d trees placed (inner 8 + mid 22 + outer 38 + old 12)" % (8 + 22 + 38 + 12))


func _place_undergrowth() -> void:
	## Bushes between trees — BK uses these to fill gaps
	_scatter_assets(BK_BUSHES, 30, 10.0, 50.0, 0.7, 1.3, 2.0)
	print("[BKForest] 30 bushes placed")


func _place_ground_scatter() -> void:
	## Ground cover: grass tufts, ferns, flowers — BK cross-billboards
	## These are 4 tris each — EXTREMELY cheap, scatter heavily
	_scatter_assets(BK_GROUND, 80, 5.0, 50.0, 0.6, 1.4, 1.0)
	# Extra dense near path edges
	for z_step in range(-28, 29, 3):
		var z: float = float(z_step)
		var path_x: float = sin(z * 0.05) * 3.0
		for side in [-1, 1]:
			var x: float = path_x + side * _rng.randf_range(2.0, 5.0)
			var pos: Vector3 = Vector3(x, 0, z)
			_place_on_terrain(BK_GROUND[_rng.randi() % BK_GROUND.size()], pos,
					_rng.randf_range(0.6, 1.2), _rng.randf_range(0, 360))
	print("[BKForest] 80+ ground cover placed")


func _place_mushroom_patches() -> void:
	## Mushrooms in clusters near trees and deadwood (BK signature)
	var patch_centers: Array[Vector3] = [
		Vector3(-8, 0, 5), Vector3(15, 0, -8), Vector3(-20, 0, -15),
		Vector3(6, 0, 22), Vector3(-12, 0, 18), Vector3(25, 0, 5),
		Vector3(-5, 0, -28), Vector3(18, 0, -22),
	]
	for center in patch_centers:
		var count: int = _rng.randi_range(3, 6)
		for i in count:
			var off: Vector3 = Vector3(_rng.randf_range(-2.5, 2.5), 0, _rng.randf_range(-2.5, 2.5))
			_place_on_terrain(BK_MUSHROOMS[_rng.randi() % BK_MUSHROOMS.size()],
					center + off, _rng.randf_range(0.7, 1.3), _rng.randf_range(0, 360))
	print("[BKForest] Mushroom patches placed")


func _place_deadwood_scatter() -> void:
	## Stumps, fallen logs, branch piles — forest floor character
	_scatter_assets(BK_DEADWOOD, 20, 8.0, 50.0, 0.7, 1.3, 3.0)
	print("[BKForest] 20 deadwood pieces placed")


# ====================================================================
# MEGALITH HILLTOP — Elevated clearing with stone circle
# ====================================================================

func _place_megalith_hilltop() -> void:
	var center: Vector3 = Vector3(0, 0, -22)
	center.y = get_height(center.x, center.z)
	var radius: float = 8.0

	_place_on_terrain(BK_MEGALITHS[0], center, 1.3, 0.0)
	for i in 8:
		var angle: float = float(i) * TAU / 8.0 + 0.2
		var pos: Vector3 = Vector3(center.x + cos(angle) * radius, 0, center.z + sin(angle) * radius)
		_place_on_terrain(BK_MEGALITHS[i % BK_MEGALITHS.size()], pos,
				_rng.randf_range(0.8, 1.15), _rng.randf_range(0, 360))
	for i in 4:
		var angle: float = float(i) * TAU / 4.0 + 0.8
		var pos: Vector3 = Vector3(center.x + cos(angle) * (radius + 5.0), 0, center.z + sin(angle) * (radius + 5.0))
		_place_on_terrain(OLD_MEGALITHS[i % OLD_MEGALITHS.size()], pos,
				_rng.randf_range(3.0, 4.5), _rng.randf_range(0, 360))
	print("[BKForest] Megalith hilltop placed")


# ====================================================================
# CLEARING — Structures, bridge, props
# ====================================================================

func _place_clearing_structures() -> void:
	_place_on_terrain(BK_STRUCTURES[0], Vector3(12, 0, -6), 1.0, 30.0)
	_place_on_terrain(BK_STRUCTURES[1], Vector3(-14, 0, 8), 0.9, -25.0)
	_place_on_terrain(BK_STRUCTURES[2], Vector3(-8, 0, -12), 0.85, 150.0)
	_place_on_terrain(BK_STRUCTURES[3], Vector3(16, 0, 4), 0.95, 80.0)
	_place_on_terrain(BK_BRIDGES[1], Vector3(-10, 0, -18), 1.0, 60.0)
	print("[BKForest] Structures placed")


func _place_scattered_rocks() -> void:
	# Random scatter
	for i in 35:
		var r: float = _rng.randf_range(4.0, 52.0)
		var angle: float = _rng.randf() * TAU
		var pos: Vector3 = Vector3(cos(angle) * r, 0, sin(angle) * r)
		_place_on_terrain(BK_ROCKS[_rng.randi() % BK_ROCKS.size()], pos,
				_rng.randf_range(0.6, 1.5), _rng.randf_range(0, 360))
	# Rock clusters
	for cluster_pos in [Vector3(20, 0, -10), Vector3(-18, 0, -25), Vector3(15, 0, 30), Vector3(-25, 0, 10)]:
		for j in 5:
			var off: Vector3 = Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))
			_place_on_terrain(BK_ROCKS[_rng.randi() % BK_ROCKS.size()],
					cluster_pos + off, _rng.randf_range(0.4, 1.0), _rng.randf_range(0, 360))
	print("[BKForest] Rocks placed")


func _place_creatures() -> void:
	_place_on_terrain(BK_CREATURES[0], Vector3(2, 0, -18), 1.0, 120.0)
	_place_on_terrain(BK_CREATURES[1], Vector3(-6, 0, 4), 1.0, -30.0)
	_place_on_terrain(BK_CREATURES[2], Vector3(16, 0, 12), 1.0, 200.0)
	_place_on_terrain(BK_CREATURES[3], Vector3(14, 0, -4), 0.85, 60.0)
	_place_on_terrain(BK_CREATURES[4], Vector3(-20, 0, -15), 1.1, 90.0)
	_place_on_terrain(BK_CREATURES[5], Vector3(-15, 0, 20), 0.95, 270.0)
	print("[BKForest] 6 creatures placed")


func _place_collectibles() -> void:
	# Along the path
	for z_step in range(-24, 26, 6):
		var z: float = float(z_step)
		var x: float = sin(z * 0.05) * 3.0 + _rng.randf_range(-1.5, 1.5)
		var pos: Vector3 = Vector3(x, 0, z)
		_place_on_terrain(BK_COLLECTIBLES[_rng.randi() % BK_COLLECTIBLES.size()], pos,
				1.0, _rng.randf_range(0, 360), 0.2)
	# Near megalith circle
	for i in 5:
		var angle: float = _rng.randf() * TAU
		var pos: Vector3 = Vector3(cos(angle) * 5.0, 0, -22.0 + sin(angle) * 5.0)
		_place_on_terrain(BK_COLLECTIBLES[i % BK_COLLECTIBLES.size()], pos,
				1.0, _rng.randf_range(0, 360), 0.2)
	# Near structures
	for struct_pos in [Vector3(12, 0, -6), Vector3(-14, 0, 8), Vector3(-8, 0, -12)]:
		var off: Vector3 = Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))
		_place_on_terrain(BK_COLLECTIBLES[_rng.randi() % BK_COLLECTIBLES.size()],
				struct_pos + off, 1.0, _rng.randf_range(0, 360), 0.2)
	print("[BKForest] Collectibles placed")


func _place_props_along_path() -> void:
	## Fences, signposts, torches along the path — BK level dressing
	# Signposts at path intersections
	_place_on_terrain(BK_PROPS[1], Vector3(0.5, 0, -10), 1.0, 45.0)
	_place_on_terrain(BK_PROPS[1], Vector3(-0.5, 0, 10), 1.0, -30.0)
	# Fence sections near clearing
	for i in 6:
		var angle: float = float(i) * TAU / 6.0 + 0.3
		var pos: Vector3 = Vector3(cos(angle) * 14.0, 0, sin(angle) * 14.0)
		_place_on_terrain(BK_PROPS[0], pos, 1.0, rad_to_deg(angle) + 90.0)
	# Torches near structures
	_place_on_terrain(BK_PROPS[2], Vector3(11, 0, -5), 1.0, 0.0)
	_place_on_terrain(BK_PROPS[2], Vector3(-13, 0, 7), 1.0, 0.0)
	# Well in clearing
	_place_on_terrain(BK_PROPS[3], Vector3(-3, 0, -2), 1.0, 15.0)
	print("[BKForest] Props placed")


# ====================================================================
# ATMOSPHERE — Fog + fairy dust + ambient lights + weather
# ====================================================================

func _add_fog_volumes() -> void:
	var fog_mat: StandardMaterial3D = StandardMaterial3D.new()
	fog_mat.albedo_color = Color(0.7, 0.8, 0.7, 0.08)
	fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog_mat.no_depth_test = true
	fog_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var fog_positions: Array[Vector3] = [
		Vector3(8, -0.5, 15), Vector3(-5, 0.5, 0), Vector3(0, 2.0, -22),
		Vector3(25, 1.0, -5), Vector3(-20, 0.5, 15), Vector3(-30, 0.8, -10),
		Vector3(15, 0.3, 25),
	]
	var fog_scales: Array[float] = [8.0, 12.0, 10.0, 15.0, 12.0, 10.0, 8.0]

	for i in fog_positions.size():
		var fog_mesh: SphereMesh = SphereMesh.new()
		fog_mesh.radius = fog_scales[i]
		fog_mesh.height = fog_scales[i] * 0.6
		fog_mesh.radial_segments = 12
		fog_mesh.rings = 6
		var inst: MeshInstance3D = MeshInstance3D.new()
		inst.mesh = fog_mesh
		inst.material_override = fog_mat
		inst.position = fog_positions[i]
		inst.position.y = get_height(fog_positions[i].x, fog_positions[i].z) + fog_scales[i] * 0.15
		inst.name = "FogVolume_%d" % i
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)


func _add_fairy_particles() -> void:
	var emitter_data: Array[Dictionary] = [
		{"pos": Vector3(0, 2.0, -22), "color": Color(0.3, 0.6, 1.0, 0.8), "count": 30},
		{"pos": Vector3(-5, 1.0, 3), "color": Color(0.4, 0.9, 0.3, 0.7), "count": 20},
		{"pos": Vector3(8, 0.5, 15), "color": Color(0.2, 0.5, 0.8, 0.6), "count": 15},
		{"pos": Vector3(12, 1.5, -6), "color": Color(0.9, 0.7, 0.2, 0.7), "count": 15},
		{"pos": Vector3(-14, 1.0, 8), "color": Color(0.8, 0.4, 0.9, 0.6), "count": 10},
	]
	for i in emitter_data.size():
		var data: Dictionary = emitter_data[i]
		var particles: CPUParticles3D = CPUParticles3D.new()
		particles.amount = data["count"]
		particles.lifetime = 4.0
		particles.speed_scale = 0.5
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 5.0
		particles.direction = Vector3(0, 1, 0)
		particles.spread = 180.0
		particles.gravity = Vector3(0, -0.1, 0)
		particles.initial_velocity_min = 0.2
		particles.initial_velocity_max = 0.8
		particles.mesh = _create_particle_mesh()
		particles.color = data["color"]
		particles.scale_amount_min = 0.03
		particles.scale_amount_max = 0.08
		var base_pos: Vector3 = data["pos"]
		particles.position = Vector3(base_pos.x, get_height(base_pos.x, base_pos.z) + 2.0, base_pos.z)
		particles.name = "FairyDust_%d" % i
		add_child(particles)


func _create_particle_mesh() -> Mesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 4
	mesh.rings = 2
	return mesh


func _add_ambient_lights() -> void:
	var lights: Array[Dictionary] = [
		{"pos": Vector3(0, 3.0, -22), "col": Color(0.3, 0.55, 0.9), "e": 1.2, "r": 14.0},
		{"pos": Vector3(12, 2.0, -6), "col": Color(0.9, 0.75, 0.3), "e": 0.8, "r": 10.0},
		{"pos": Vector3(-14, 2.0, 8), "col": Color(0.85, 0.6, 0.3), "e": 0.6, "r": 8.0},
		{"pos": Vector3(8, 1.0, 15), "col": Color(0.2, 0.5, 0.7), "e": 0.5, "r": 8.0},
		{"pos": Vector3(-5, 1.5, 3), "col": Color(0.5, 0.8, 0.35), "e": 0.6, "r": 10.0},
		{"pos": Vector3(0, 1.0, 0), "col": Color(0.9, 0.85, 0.6), "e": 0.4, "r": 15.0},
		{"pos": Vector3(30, 3.0, 0), "col": Color(0.3, 0.5, 0.2), "e": 0.3, "r": 12.0},
		{"pos": Vector3(-30, 3.0, 0), "col": Color(0.3, 0.5, 0.2), "e": 0.3, "r": 12.0},
		{"pos": Vector3(0, 3.0, 30), "col": Color(0.3, 0.5, 0.2), "e": 0.3, "r": 12.0},
	]
	for i in lights.size():
		var data: Dictionary = lights[i]
		var light: OmniLight3D = OmniLight3D.new()
		var lpos: Vector3 = data["pos"]
		light.position = Vector3(lpos.x, get_height(lpos.x, lpos.z) + lpos.y, lpos.z)
		light.light_color = data["col"]
		light.light_energy = data["e"]
		light.omni_range = data["r"]
		light.shadow_enabled = false
		light.name = "Light_%d" % i
		add_child(light)


# ====================================================================
# WEATHER — Rain, wind leaves, god rays, mist
# ====================================================================

var _time: float = 0.0
var _god_rays: Array[MeshInstance3D] = []

func _add_weather_system() -> void:
	# Light forest rain
	var rain: CPUParticles3D = CPUParticles3D.new()
	rain.amount = 200
	rain.lifetime = 2.5
	rain.speed_scale = 1.0
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(40.0, 0.5, 40.0)
	rain.direction = Vector3(-0.1, -1, 0.05)
	rain.spread = 5.0
	rain.gravity = Vector3(0, -8.0, 0)
	rain.initial_velocity_min = 3.0
	rain.initial_velocity_max = 5.0
	var rain_mesh: BoxMesh = BoxMesh.new()
	rain_mesh.size = Vector3(0.02, 0.3, 0.02)
	rain.mesh = rain_mesh
	var rain_mat: StandardMaterial3D = StandardMaterial3D.new()
	rain_mat.albedo_color = Color(0.7, 0.8, 0.9, 0.3)
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain.material_override = rain_mat
	rain.position = Vector3(0, 25, 0)
	rain.name = "Rain"
	add_child(rain)

	# Wind leaves
	var wind: CPUParticles3D = CPUParticles3D.new()
	wind.amount = 40
	wind.lifetime = 6.0
	wind.speed_scale = 0.8
	wind.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	wind.emission_box_extents = Vector3(30.0, 5.0, 30.0)
	wind.direction = Vector3(1, 0.15, 0.3)
	wind.spread = 25.0
	wind.gravity = Vector3(0.5, -0.3, 0.2)
	wind.initial_velocity_min = 1.0
	wind.initial_velocity_max = 3.0
	wind.angular_velocity_min = -90.0
	wind.angular_velocity_max = 90.0
	var leaf_mesh: SphereMesh = SphereMesh.new()
	leaf_mesh.radius = 0.08
	leaf_mesh.height = 0.04
	leaf_mesh.radial_segments = 4
	leaf_mesh.rings = 2
	wind.mesh = leaf_mesh
	wind.color = Color(0.5, 0.65, 0.3, 0.6)
	wind.scale_amount_min = 0.5
	wind.scale_amount_max = 1.5
	wind.position = Vector3(0, 4, 0)
	wind.name = "WindLeaves"
	add_child(wind)

	# God rays
	var ray_mat: StandardMaterial3D = StandardMaterial3D.new()
	ray_mat.albedo_color = Color(1.0, 0.95, 0.7, 0.06)
	ray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ray_mat.no_depth_test = true
	for i in 8:
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(3.0 + _rng.randf() * 4.0, 20.0 + _rng.randf() * 15.0)
		var ray: MeshInstance3D = MeshInstance3D.new()
		ray.mesh = quad
		ray.material_override = ray_mat
		var angle: float = _rng.randf() * TAU
		var r: float = _rng.randf_range(8.0, 35.0)
		var bx: float = cos(angle) * r
		var bz: float = sin(angle) * r
		ray.position = Vector3(bx, get_height(bx, bz) + 10.0, bz)
		ray.rotation_degrees = Vector3(-20, _rng.randf_range(0, 360), _rng.randf_range(-10, 10))
		ray.name = "GodRay_%d" % i
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ray)
		_god_rays.append(ray)

	# Mist pockets
	var mist_mat: StandardMaterial3D = StandardMaterial3D.new()
	mist_mat.albedo_color = Color(0.8, 0.85, 0.75, 0.12)
	mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mist_mat.no_depth_test = true
	for i in 8:
		var mist_mesh: SphereMesh = SphereMesh.new()
		var s: float = _rng.randf_range(6.0, 14.0)
		mist_mesh.radius = s
		mist_mesh.height = s * 0.3
		mist_mesh.radial_segments = 8
		mist_mesh.rings = 4
		var mist: MeshInstance3D = MeshInstance3D.new()
		mist.mesh = mist_mesh
		mist.material_override = mist_mat
		var mx: float = _rng.randf_range(-35, 35)
		var mz: float = _rng.randf_range(-35, 35)
		mist.position = Vector3(mx, get_height(mx, mz) + 0.5, mz)
		mist.name = "Mist_%d" % i
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mist)


func _process(delta: float) -> void:
	_time += delta
	for i in _god_rays.size():
		var ray: MeshInstance3D = _god_rays[i]
		ray.rotation_degrees.y += sin(_time * 0.3 + float(i)) * 0.1
		var mat: StandardMaterial3D = ray.material_override as StandardMaterial3D
		if mat:
			var pulse: float = 0.04 + sin(_time * 0.5 + float(i) * 1.5) * 0.025
			mat.albedo_color.a = pulse

	var cam: Camera3D = get_node_or_null("Camera")
	if cam:
		var sky: MeshInstance3D = get_node_or_null("Skydome") as MeshInstance3D
		if sky:
			sky.position = Vector3(cam.position.x, 0, cam.position.z)
		if _sun_pivot:
			_sun_pivot.position = Vector3(cam.position.x, 0, cam.position.z)


# ====================================================================
# HELPERS
# ====================================================================

func _place_on_terrain(glb_path: String, pos: Vector3, scale_f: float, rot_y_deg: float, y_offset: float = 0.0) -> void:
	var scene: PackedScene = _try_load(glb_path)
	if scene == null:
		return
	var inst: Node3D = scene.instantiate() as Node3D
	var y: float = get_height(pos.x, pos.z) + y_offset
	inst.position = Vector3(pos.x, y, pos.z)
	inst.scale = Vector3(scale_f, scale_f, scale_f)
	inst.rotation_degrees.y = rot_y_deg
	add_child(inst)
	_placed.append(Vector3(pos.x, y, pos.z))


func _scatter_assets(assets: Array[String], count: int, r_min: float, r_max: float,
		s_min: float, s_max: float, min_dist: float) -> void:
	for i in count:
		var glb: String = assets[_rng.randi() % assets.size()]
		var pos_xz: Vector3 = _find_pos(r_min, r_max, min_dist)
		if pos_xz == Vector3.ZERO and i > 0:
			continue
		var y: float = get_height(pos_xz.x, pos_xz.z)
		var scene: PackedScene = _try_load(glb)
		if scene == null:
			continue
		var inst: Node3D = scene.instantiate() as Node3D
		inst.position = Vector3(pos_xz.x, y, pos_xz.z)
		inst.rotation.y = _rng.randf() * TAU
		inst.rotation.x = _rng.randf_range(-0.05, 0.05)
		inst.rotation.z = _rng.randf_range(-0.05, 0.05)
		var s: float = _rng.randf_range(s_min, s_max)
		inst.scale = Vector3(s, s, s)
		add_child(inst)


func _find_pos(r_min: float, r_max: float, min_dist: float) -> Vector3:
	for _attempt in range(30):
		var angle: float = _rng.randf() * TAU
		var radius: float = _rng.randf_range(r_min, r_max)
		var pos: Vector3 = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var ok: bool = true
		for existing in _placed:
			var dx: float = pos.x - existing.x
			var dz: float = pos.z - existing.z
			if sqrt(dx * dx + dz * dz) < min_dist:
				ok = false
				break
		if ok:
			_placed.append(pos)
			return pos
	return Vector3.ZERO


func _try_load(path: String) -> PackedScene:
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	return null
