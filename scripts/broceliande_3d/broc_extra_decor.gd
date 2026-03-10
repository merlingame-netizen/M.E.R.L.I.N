extends RefCounted
## BrocExtraDecor — Procedural decorative elements for atmosphere.
## Crystals, glow orbs, stone pillars, ground runes.

var _forest_root: Node3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(forest_root: Node3D, zone_centers: Array[Vector3]) -> void:
	_forest_root = forest_root
	_rng.randomize()

	var count: int = 0

	# Glowing crystals in dark zones (idx 2=Dolmen, idx 4=Foret Profonde)
	var crystal_zones: Array[int] = [2, 4]
	for zi in crystal_zones:
		if zi >= zone_centers.size():
			continue
		var zc: Vector3 = zone_centers[zi]
		for _i in range(3):
			_spawn_crystal(zc + _roff(3.0, 10.0))
			count += 1

	# Glow orbs near water (idx 3=Mare Enchantee, idx 5=Fontaine de Barenton)
	var water_zones: Array[int] = [3, 5]
	for zi in water_zones:
		if zi >= zone_centers.size():
			continue
		var zc: Vector3 = zone_centers[zi]
		for _i in range(5):
			_spawn_glow_orb(zc + _roff(1.5, 6.0) + Vector3(0.0, _rng.randf_range(0.3, 1.2), 0.0))
			count += 1

	# Stone pillars at ritual sites (idx 2=Dolmen, idx 6=Cercle de Pierres)
	var pillar_zones: Array[int] = [2, 6]
	for zi in pillar_zones:
		if zi >= zone_centers.size():
			continue
		var zc: Vector3 = zone_centers[zi]
		for _i in range(2):
			_spawn_stone_pillar(zc + _roff(5.0, 12.0))
			count += 1

	# Ground runes at idx 6 (Cercle de Pierres)
	if zone_centers.size() > 6:
		var zc: Vector3 = zone_centers[6]
		for _i in range(3):
			_spawn_ground_rune(zc + _roff(2.0, 7.0))
			count += 1

	print("[BrocExtraDecor] Spawned %d procedural decor elements" % count)


func _spawn_crystal(pos: Vector3) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.height = _rng.randf_range(0.6, 1.4)
	mesh.bottom_radius = _rng.randf_range(0.08, 0.15)
	mesh.top_radius = 0.02
	mesh.radial_segments = 5

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	var hue: float = _rng.randf_range(0.5, 0.7)
	mat.albedo_color = Color.from_hsv(hue, 0.6, 0.9, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color.from_hsv(hue, 0.5, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.roughness = 0.2
	mat.metallic = 0.4

	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.rotation_degrees = Vector3(
		_rng.randf_range(-15.0, 15.0),
		_rng.randf_range(0.0, 360.0),
		_rng.randf_range(-10.0, 10.0)
	)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.visibility_range_end = 35.0
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_forest_root.add_child(inst)


func _spawn_glow_orb(pos: Vector3) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = _rng.randf_range(0.03, 0.06)
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	var color: Color = Color(
		_rng.randf_range(0.4, 0.7),
		_rng.randf_range(0.7, 1.0),
		_rng.randf_range(0.3, 0.6),
		0.9
	)
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.visibility_range_end = 30.0
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_forest_root.add_child(inst)


func _spawn_stone_pillar(pos: Vector3) -> void:
	var height: float = _rng.randf_range(1.2, 2.5)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(
		_rng.randf_range(0.3, 0.5),
		height,
		_rng.randf_range(0.3, 0.5)
	)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(
		_rng.randf_range(0.30, 0.40),
		_rng.randf_range(0.30, 0.38),
		_rng.randf_range(0.28, 0.36)
	)
	mat.roughness = 0.9

	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos + Vector3(0.0, height * 0.5, 0.0)
	inst.rotation_degrees = Vector3(0.0, _rng.randf_range(0.0, 45.0), 0.0)
	inst.visibility_range_end = 45.0
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_forest_root.add_child(inst)


func _spawn_ground_rune(pos: Vector3) -> void:
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(_rng.randf_range(0.8, 1.5), _rng.randf_range(0.8, 1.5))

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.5, 0.8, 0.15)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.5, 0.9)
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos + Vector3(0.0, 0.02, 0.0)
	inst.rotation_degrees = Vector3(-90.0, _rng.randf_range(0.0, 360.0), 0.0)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.visibility_range_end = 25.0
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_forest_root.add_child(inst)


func _roff(min_r: float, max_r: float) -> Vector3:
	var angle: float = _rng.randf() * TAU
	var dist: float = _rng.randf_range(min_r, max_r)
	return Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
