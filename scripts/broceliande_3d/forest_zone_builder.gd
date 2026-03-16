extends RefCounted
## ForestZoneBuilder — Builds zone-specific POI decor (megaliths, structures, lights).
## Extracted from BroceliandeForest3D for file size reduction.

var _spawner: RefCounted  # ForestAssetSpawner
var _forest_root: Node3D
var _zone_centers: Array[Vector3]
var _rng: RandomNumberGenerator


func _init(spawner: RefCounted, forest_root: Node3D, zone_centers: Array[Vector3], rng: RandomNumberGenerator) -> void:
	_spawner = spawner
	_forest_root = forest_root
	_zone_centers = zone_centers
	_rng = rng


func build_zones() -> void:
	_build_z1_lisiere()
	_build_z2_dense()
	_build_z3_dolmen()
	_build_z4_mare()
	_build_z5_profonde()
	_build_z6_fontaine()
	_build_z7_cercle()


func _build_z1_lisiere() -> void:
	var c: Vector3 = _zone_centers[0]
	_spawner.spawn_broc("fallen_trunk", c + Vector3(10.0, 0.0, -5.0), 2.0, 15.0)
	_spawner.spawn_broc("giant_stump", c + Vector3(-12.0, 0.0, -8.0), 2.5)


func _build_z2_dense() -> void:
	var c: Vector3 = _zone_centers[1]
	_spawner.spawn_broc("root_network", c + Vector3(-6.0, 0.0, 5.0), 2.5)
	_spawner.spawn_broc("spider_web", c + Vector3(8.0, 3.0, -3.0), 2.0)
	_spawner.spawn_broc("giant_mushroom", c + Vector3(-3.0, 0.0, -10.0), 2.5)
	_spawner.spawn_broc("fallen_trunk", c + Vector3(12.0, 0.0, 8.0), 2.0, 45.0)


func _build_z3_dolmen() -> void:
	var c: Vector3 = _zone_centers[2]
	_spawner.spawn_broc("dolmen", c, 3.5, 0.0)
	_spawner.spawn_broc("menhir_01", c + Vector3(-4.0, 0.0, -3.0), 3.0)
	_spawner.spawn_broc("menhir_02", c + Vector3(4.5, 0.0, -2.0), 2.8)
	_spawner.spawn_broc("merlin_tomb", c + Vector3(7.0, 0.0, 5.0), 2.5)
	_spawner.spawn_special("old_oak", c + Vector3(-10.0, 0.0, 4.0), 4.0)
	_spawner.spawn_broc("merlin_oak", c + Vector3(9.0, 0.0, -5.0), 3.5)
	_add_point_light(c + Vector3(0.0, 2.0, 0.0), Color(0.85, 0.75, 0.35), 0.6, 10.0)


func _build_z4_mare() -> void:
	var c: Vector3 = _zone_centers[3]
	_create_water(c, 8.0)
	for i in 6:
		var angle: float = float(i) * TAU / 6.0 + 0.3
		_spawner.spawn_special("willow", c + Vector3(cos(angle) * 9.0, 0.0, sin(angle) * 9.0), _rng.randf_range(3.5, 5.0))
	for i in 6:
		_spawner.spawn_detail("lily_pink", c + _roff(1.0, 6.0) + Vector3(0.0, -0.25, 0.0), _rng.randf_range(1.5, 2.5))
	for i in 4:
		_spawner.spawn_detail("lily_white", c + _roff(1.0, 5.5) + Vector3(0.0, -0.25, 0.0), _rng.randf_range(1.5, 2.5))
	for i in 6:
		_spawner.spawn_detail("cattail", c + _roff(5.0, 9.0), _rng.randf_range(1.5, 2.5))
	_spawner.spawn_broc("bridge_wood", c + Vector3(8.0, -0.15, 0.0), 2.5, 90.0)
	_spawner.spawn_broc("giant_mushroom", c + Vector3(-6.0, 0.0, 4.0), 2.5, 45.0)
	_spawner.spawn_broc("spider_web", c + Vector3(5.0, 2.5, -6.0), 2.0)
	_add_point_light(c + Vector3(0.0, 0.8, 0.0), Color(0.3, 0.5, 0.7), 0.5, 9.0)


func _build_z5_profonde() -> void:
	var c: Vector3 = _zone_centers[4]
	for i in 4:
		_spawner.spawn_special("dead", c + _roff(6.0, 25.0), _rng.randf_range(3.0, 4.5))
	_spawner.spawn_broc("giant_mushroom", c + Vector3(-5.0, 0.0, 4.0), 3.0)
	_spawner.spawn_broc("giant_stump", c + Vector3(6.0, 0.0, -7.0), 3.0)
	_spawner.spawn_broc("fallen_trunk", c + Vector3(-8.0, 0.0, -5.0), 2.5, 30.0)
	_spawner.spawn_broc("root_network", c + Vector3(4.0, 0.0, 8.0), 2.5)
	_spawner.spawn_broc("spider_web", c + Vector3(-12.0, 3.0, 10.0), 2.5, 120.0)
	_spawner.spawn_broc("root_network", c + Vector3(8.0, 0.0, -4.0), 2.0, 200.0)
	_spawner.spawn_broc("fallen_trunk", c + Vector3(14.0, 0.0, 6.0), 2.0, 75.0)
	for i in 5:
		_add_point_light(c + _roff(3.0, 14.0) + Vector3(0.0, 0.5, 0.0), Color(0.5, 0.8, 0.3), 0.3, 3.5)


func _build_z6_fontaine() -> void:
	var c: Vector3 = _zone_centers[5]
	_spawner.spawn_broc("fountain_barenton", c, 3.0, 0.0)
	_create_water(c + Vector3(0.0, 0.3, 0.0), 3.0)
	_spawner.spawn_broc("fairy_lantern", c + Vector3(4.5, 0.0, -3.5), 2.5)
	_spawner.spawn_broc("fairy_lantern", c + Vector3(-3.5, 0.0, 4.0), 2.2, 180.0)
	_spawner.spawn_broc("root_arch", c + Vector3(0.0, 0.0, 10.0), 3.5, 0.0)
	_spawner.spawn_special("spiral", c + Vector3(7.0, 0.0, -5.0), 4.0)
	_spawner.spawn_special("silver", c + Vector3(-6.0, 0.0, -4.0), 3.5)
	_spawner.spawn_broc("giant_stump", c + Vector3(-6.0, 0.0, -2.0), 2.5, 60.0)
	_add_point_light(c + Vector3(0.0, 1.5, 0.0), Color(0.90, 0.75, 0.35), 1.0, 10.0)


func _build_z7_cercle() -> void:
	var c: Vector3 = _zone_centers[6]
	_spawner.spawn_broc("stone_circle", c, 4.0, 0.0)
	for i in 6:
		var angle: float = float(i) * TAU / 6.0 + 0.4
		var key: String = "menhir_01" if i % 2 == 0 else "menhir_02"
		_spawner.spawn_broc(key, c + Vector3(cos(angle) * 10.0, 0.0, sin(angle) * 10.0), _rng.randf_range(3.0, 4.0))
	_spawner.spawn_broc("druid_altar", c + Vector3(0.0, 0.0, 0.0), 2.5, 0.0)
	_spawner.spawn_special("old_oak", c + Vector3(-12.0, 0.0, 6.0), 5.0)
	_spawner.spawn_special("old_oak", c + Vector3(11.0, 0.0, -7.0), 4.5)
	_spawner.spawn_special("old_oak", c + Vector3(0.0, 0.0, 12.0), 5.5)
	_spawner.spawn_special("golden", c + Vector3(-8.0, 0.0, -9.0), 4.0)
	_spawner.spawn_broc("fallen_trunk", c + Vector3(0.0, 0.0, -10.0), 2.5, 0.0)
	_add_point_light(c + Vector3(0.0, 1.5, 0.0), Color(0.30, 0.60, 0.90), 1.0, 12.0)
	_add_point_light(c + Vector3(5.0, 0.8, 5.0), Color(0.20, 0.40, 0.80), 0.4, 6.0)
	_add_point_light(c + Vector3(-5.0, 0.8, -5.0), Color(0.20, 0.40, 0.80), 0.4, 6.0)


# --- Helpers ---

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
	_forest_root.add_child(mi)


func _add_point_light(pos: Vector3, color: Color, energy: float, rng: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = rng
	light.shadow_enabled = false
	_forest_root.add_child(light)


func _roff(min_r: float, max_r: float) -> Vector3:
	var d: float = _rng.randf_range(min_r, max_r)
	var a: float = _rng.randf_range(0.0, TAU)
	return Vector3(cos(a) * d, 0.0, sin(a) * d)
