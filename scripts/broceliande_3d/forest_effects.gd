extends RefCounted
## ForestEffects v2 — Biome-aware volumetric effects.
## Reads particle profiles from BiomeParticleProfiles per biome.

var _forest_root: Node3D
var _zone_centers: Array[Vector3]
var _rng: RandomNumberGenerator
var _biome_key: String = "foret_broceliande"

var pollen_node: GPUParticles3D
var firefly_nodes: Array[GPUParticles3D] = []


func _init(forest_root: Node3D, zone_centers: Array[Vector3], rng: RandomNumberGenerator) -> void:
	_forest_root = forest_root
	_zone_centers = zone_centers
	_rng = rng


func set_biome(biome_key: String) -> void:
	_biome_key = biome_key


func add_fog_particles() -> void:
	var profile: Dictionary = BiomeParticleProfiles.get_profile(_biome_key)
	var cfg: Dictionary = profile.get("fog", {})
	if cfg.is_empty():
		return
	var color: Color = cfg.get("color", Color(0.35, 0.45, 0.35, 0.08))
	var amount: int = int(cfg.get("amount", 30))
	var draw_color: Color = cfg.get("draw_color", Color(0.40, 0.50, 0.38, 0.06))
	var lifetime: float = float(cfg.get("lifetime", 8.0))
	var size_min: float = float(cfg.get("size_min", 3.0))
	var size_max: float = float(cfg.get("size_max", 6.0))

	for i in range(0, _zone_centers.size()):
		var center: Vector3 = _zone_centers[i]
		var fog: GPUParticles3D = GPUParticles3D.new()
		fog.name = "FogZone%d" % i
		fog.position = center + Vector3(0.0, 0.3, 0.0)
		fog.amount = amount
		fog.lifetime = lifetime
		fog.explosiveness = 0.0
		fog.randomness = 1.0
		fog.visibility_aabb = AABB(Vector3(-15, -1, -15), Vector3(30, 3, 30))

		var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
		mat.direction = cfg.get("direction", Vector3(1.0, 0.1, 0.0))
		mat.spread = float(cfg.get("spread", 180.0))
		mat.initial_velocity_min = float(cfg.get("velocity_min", 0.2))
		mat.initial_velocity_max = float(cfg.get("velocity_max", 0.5))
		mat.gravity = cfg.get("gravity", Vector3.ZERO)
		mat.scale_min = size_min
		mat.scale_max = size_max
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = cfg.get("emission_box", Vector3(12.0, 0.3, 12.0))
		mat.color = color
		fog.process_material = mat

		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2(2.0, 2.0)
		var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
		draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		draw_mat.albedo_color = draw_color
		draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_mat.no_depth_test = true
		qm.material = draw_mat
		fog.draw_pass_1 = qm

		_forest_root.add_child(fog)


func add_pollen_particles() -> void:
	var profile: Dictionary = BiomeParticleProfiles.get_profile(_biome_key)
	var cfg: Dictionary = profile.get("ambient_particles", {})
	if cfg.is_empty():
		return
	var color: Color = cfg.get("color", Color(0.90, 0.85, 0.60, 0.3))
	var amount: int = int(cfg.get("amount", 120))
	var draw_color: Color = cfg.get("draw_color", Color(0.95, 0.90, 0.65, 0.5))
	var has_glow: bool = bool(cfg.get("emission_glow", false))
	var glow_color: Color = cfg.get("emission_color", Color(0.95, 0.90, 0.65))
	var glow_energy: float = float(cfg.get("emission_energy", 0.5))

	var pollen: GPUParticles3D = GPUParticles3D.new()
	pollen.name = "AmbientParticles"
	pollen.position = Vector3(0.0, 2.0, -55.0)
	pollen.amount = amount
	pollen.lifetime = float(cfg.get("lifetime", 12.0))
	pollen.explosiveness = 0.0
	pollen.randomness = 1.0
	pollen.visibility_aabb = AABB(Vector3(-60, -2, -80), Vector3(120, 8, 160))

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = cfg.get("direction", Vector3(0.3, 0.1, -0.1))
	mat.spread = float(cfg.get("spread", 90.0))
	mat.initial_velocity_min = float(cfg.get("velocity_min", 0.05))
	mat.initial_velocity_max = float(cfg.get("velocity_max", 0.15))
	mat.gravity = cfg.get("gravity", Vector3(0.0, -0.01, 0.0))
	mat.scale_min = float(cfg.get("size_min", 0.5))
	mat.scale_max = float(cfg.get("size_max", 1.5))
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = cfg.get("emission_box", Vector3(50.0, 3.0, 70.0))
	mat.color = color
	pollen.process_material = mat

	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(0.04, 0.04)
	var dm: StandardMaterial3D = StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = draw_color
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if has_glow:
		dm.emission_enabled = true
		dm.emission = glow_color
		dm.emission_energy_multiplier = glow_energy
	qm.material = dm
	pollen.draw_pass_1 = qm

	_forest_root.add_child(pollen)
	pollen_node = pollen


func add_fireflies() -> void:
	var profile: Dictionary = BiomeParticleProfiles.get_profile(_biome_key)
	var cfg: Dictionary = profile.get("accent_particles", {})
	if cfg.is_empty():
		return
	var color: Color = cfg.get("color", Color(0.55, 0.90, 0.35, 0.8))
	var amount: int = int(cfg.get("amount", 12))
	var draw_color: Color = cfg.get("draw_color", Color(0.55, 0.85, 0.35, 0.9))
	var has_glow: bool = bool(cfg.get("emission_glow", true))
	var glow_color: Color = cfg.get("emission_color", Color(0.55, 0.90, 0.35))
	var glow_energy: float = float(cfg.get("emission_energy", 3.0))
	var light_color: Color = cfg.get("light_color", glow_color.darkened(0.1))
	var light_energy: float = float(cfg.get("light_energy", 0.15))

	for zi in range(2, _zone_centers.size()):
		var center: Vector3 = _zone_centers[zi]
		var ff: GPUParticles3D = GPUParticles3D.new()
		ff.name = "AccentParticles_Z%d" % zi
		ff.position = center + Vector3(0.0, 1.0, 0.0)
		ff.amount = amount
		ff.lifetime = float(cfg.get("lifetime", 6.0))
		ff.explosiveness = 0.0
		ff.randomness = 1.0
		ff.visibility_aabb = AABB(Vector3(-10, -1, -10), Vector3(20, 5, 20))

		var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
		mat.direction = cfg.get("direction", Vector3(0.0, 0.5, 0.0))
		mat.spread = float(cfg.get("spread", 180.0))
		mat.initial_velocity_min = float(cfg.get("velocity_min", 0.1))
		mat.initial_velocity_max = float(cfg.get("velocity_max", 0.3))
		mat.gravity = cfg.get("gravity", Vector3.ZERO)
		mat.scale_min = float(cfg.get("size_min", 1.0))
		mat.scale_max = float(cfg.get("size_max", 2.0))
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = cfg.get("emission_box", Vector3(8.0, 1.5, 8.0))
		mat.color = color
		ff.process_material = mat

		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2(0.06, 0.06)
		var dm: StandardMaterial3D = StandardMaterial3D.new()
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.albedo_color = draw_color
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if has_glow:
			dm.emission_enabled = true
			dm.emission = glow_color
			dm.emission_energy_multiplier = glow_energy
		qm.material = dm
		ff.draw_pass_1 = qm

		_forest_root.add_child(ff)
		firefly_nodes.append(ff)

		if light_energy > 0.0:
			_add_point_light(center + Vector3(0.0, 1.5, 0.0), light_color, light_energy, 4.0)


func add_god_rays() -> void:
	var profile: Dictionary = BiomeParticleProfiles.get_profile(_biome_key)
	var ray_cfg: Dictionary = profile.get("god_rays", {})
	var ray_color: Color = ray_cfg.get("color", Color(0.95, 0.90, 0.60, 0.04))
	var ray_emission: Color = ray_cfg.get("emission_color", Color(0.95, 0.90, 0.60))
	var ray_energy: float = float(ray_cfg.get("emission_energy", 0.15))
	var ray_count: int = int(ray_cfg.get("count", 3))

	var ray_mat: StandardMaterial3D = StandardMaterial3D.new()
	ray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray_mat.albedo_color = ray_color
	ray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ray_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ray_mat.no_depth_test = false
	ray_mat.emission_enabled = true
	ray_mat.emission = ray_emission
	ray_mat.emission_energy_multiplier = ray_energy

	var clearing_indices: Array[int] = [2, 5, 6]
	for zi in clearing_indices:
		if zi >= _zone_centers.size():
			continue
		var center: Vector3 = _zone_centers[zi]
		for r in ray_count:
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
			_forest_root.add_child(ray)


func add_falling_leaves() -> void:
	var profile: Dictionary = BiomeParticleProfiles.get_profile(_biome_key)
	var cfg: Dictionary = profile.get("falling", {})
	if cfg.is_empty():
		return
	var color: Color = cfg.get("color", Color(0.5, 0.35, 0.15))
	var amount: int = int(cfg.get("amount", 12))

	for i in range(0, _zone_centers.size()):
		var center: Vector3 = _zone_centers[i]
		var leaves: GPUParticles3D = GPUParticles3D.new()
		leaves.name = "FallingParticles_Z%d" % i
		leaves.position = center + Vector3(0.0, 4.0, 0.0)
		leaves.amount = amount
		leaves.lifetime = float(cfg.get("lifetime", 8.0))
		leaves.one_shot = false
		leaves.explosiveness = 0.0
		leaves.randomness = 1.0
		leaves.visibility_aabb = AABB(Vector3(-12, -8, -12), Vector3(24, 14, 24))

		var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
		mat.direction = cfg.get("direction", Vector3(0.0, -1.0, 0.0))
		mat.spread = float(cfg.get("spread", 30.0))
		mat.initial_velocity_min = float(cfg.get("velocity_min", 0.3))
		mat.initial_velocity_max = float(cfg.get("velocity_max", 0.8))
		mat.gravity = cfg.get("gravity", Vector3(0.0, -0.2, 0.0))
		mat.angular_velocity_min = -90.0
		mat.angular_velocity_max = 90.0
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = cfg.get("emission_box", Vector3(10.0, 6.0, 10.0))
		mat.scale_min = float(cfg.get("size_min", 0.03))
		mat.scale_max = float(cfg.get("size_max", 0.07))
		mat.color = color
		leaves.process_material = mat

		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2(0.06, 0.06)
		leaves.draw_pass_1 = qm

		leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_forest_root.add_child(leaves)


func add_ground_mist() -> void:
	var profile: Dictionary = BiomeParticleProfiles.get_profile(_biome_key)
	var cfg: Dictionary = profile.get("ground_mist", {})
	if cfg.is_empty():
		return
	var color: Color = cfg.get("color", Color(0.3, 0.4, 0.3, 0.04))
	var draw_color: Color = cfg.get("draw_color", color)
	var amount: int = int(cfg.get("amount", 8))

	for i in range(0, _zone_centers.size()):
		var center: Vector3 = _zone_centers[i]
		var mist: GPUParticles3D = GPUParticles3D.new()
		mist.name = "GroundMist_Z%d" % i
		mist.position = center + Vector3(0.0, 0.3, 0.0)
		mist.amount = amount
		mist.lifetime = float(cfg.get("lifetime", 12.0))
		mist.explosiveness = 0.0
		mist.randomness = 1.0
		mist.visibility_aabb = AABB(Vector3(-10, -1, -10), Vector3(20, 3, 20))

		var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
		mat.direction = cfg.get("direction", Vector3(1.0, 0.0, 0.0))
		mat.spread = float(cfg.get("spread", 180.0))
		mat.initial_velocity_min = float(cfg.get("velocity_min", 0.1))
		mat.initial_velocity_max = float(cfg.get("velocity_max", 0.3))
		mat.gravity = cfg.get("gravity", Vector3.ZERO)
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = cfg.get("emission_box", Vector3(8.0, 0.3, 8.0))
		mat.scale_min = float(cfg.get("size_min", 1.5))
		mat.scale_max = float(cfg.get("size_max", 3.0))
		mat.color = color
		mist.process_material = mat

		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2(2.0, 1.0)
		var dm: StandardMaterial3D = StandardMaterial3D.new()
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.albedo_color = draw_color
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.material = dm
		mist.draw_pass_1 = qm

		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_forest_root.add_child(mist)


func _add_point_light(pos: Vector3, color: Color, energy: float, rng: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = rng
	light.shadow_enabled = false
	_forest_root.add_child(light)
