extends RefCounted
## ForestEffects — Volumetric effects: fog, pollen, fireflies, god rays, point lights.
## Extracted from BroceliandeForest3D for file size reduction.

var _forest_root: Node3D
var _zone_centers: Array[Vector3]
var _rng: RandomNumberGenerator

# Particle refs for day/night modulation (exposed for main script)
var pollen_node: GPUParticles3D
var firefly_nodes: Array[GPUParticles3D] = []


func _init(forest_root: Node3D, zone_centers: Array[Vector3], rng: RandomNumberGenerator) -> void:
	_forest_root = forest_root
	_zone_centers = zone_centers
	_rng = rng


func add_fog_particles() -> void:
	for i in range(0, _zone_centers.size()):
		var center: Vector3 = _zone_centers[i]
		var fog: GPUParticles3D = GPUParticles3D.new()
		fog.name = "FogZone%d" % i
		fog.position = center + Vector3(0.0, 0.3, 0.0)
		fog.amount = 30
		fog.lifetime = 8.0
		fog.explosiveness = 0.0
		fog.randomness = 1.0
		fog.visibility_aabb = AABB(Vector3(-15, -1, -15), Vector3(30, 3, 30))

		var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
		mat.direction = Vector3(1.0, 0.1, 0.0)
		mat.spread = 180.0
		mat.initial_velocity_min = 0.2
		mat.initial_velocity_max = 0.5
		mat.gravity = Vector3(0.0, 0.0, 0.0)
		mat.scale_min = 3.0
		mat.scale_max = 6.0
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(12.0, 0.3, 12.0)
		mat.color = Color(0.35, 0.45, 0.35, 0.08)
		fog.process_material = mat

		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2(2.0, 2.0)
		var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
		draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		draw_mat.albedo_color = Color(0.40, 0.50, 0.38, 0.06)
		draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_mat.no_depth_test = true
		qm.material = draw_mat
		fog.draw_pass_1 = qm

		_forest_root.add_child(fog)


func add_pollen_particles() -> void:
	var pollen: GPUParticles3D = GPUParticles3D.new()
	pollen.name = "Pollen"
	pollen.position = Vector3(0.0, 2.0, -55.0)
	pollen.amount = 120
	pollen.lifetime = 12.0
	pollen.explosiveness = 0.0
	pollen.randomness = 1.0
	pollen.visibility_aabb = AABB(Vector3(-60, -2, -80), Vector3(120, 8, 160))

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.3, 0.1, -0.1)
	mat.spread = 90.0
	mat.initial_velocity_min = 0.05
	mat.initial_velocity_max = 0.15
	mat.gravity = Vector3(0.0, -0.01, 0.0)
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(50.0, 3.0, 70.0)
	mat.color = Color(0.90, 0.85, 0.60, 0.3)
	pollen.process_material = mat

	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(0.04, 0.04)
	var dm: StandardMaterial3D = StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.95, 0.90, 0.65, 0.5)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.emission_enabled = true
	dm.emission = Color(0.95, 0.90, 0.65)
	dm.emission_energy_multiplier = 0.5
	qm.material = dm
	pollen.draw_pass_1 = qm

	_forest_root.add_child(pollen)
	pollen_node = pollen


func add_fireflies() -> void:
	for zi in range(2, _zone_centers.size()):
		var center: Vector3 = _zone_centers[zi]
		var ff: GPUParticles3D = GPUParticles3D.new()
		ff.name = "Fireflies_Z%d" % zi
		ff.position = center + Vector3(0.0, 1.0, 0.0)
		ff.amount = 12
		ff.lifetime = 6.0
		ff.explosiveness = 0.0
		ff.randomness = 1.0
		ff.visibility_aabb = AABB(Vector3(-10, -1, -10), Vector3(20, 5, 20))

		var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
		mat.direction = Vector3(0.0, 0.5, 0.0)
		mat.spread = 180.0
		mat.initial_velocity_min = 0.1
		mat.initial_velocity_max = 0.3
		mat.gravity = Vector3(0.0, 0.0, 0.0)
		mat.scale_min = 1.0
		mat.scale_max = 2.0
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(8.0, 1.5, 8.0)
		mat.color = Color(0.55, 0.90, 0.35, 0.8)
		ff.process_material = mat

		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2(0.06, 0.06)
		var dm: StandardMaterial3D = StandardMaterial3D.new()
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.albedo_color = Color(0.55, 0.85, 0.35, 0.9)
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.emission_enabled = true
		dm.emission = Color(0.55, 0.90, 0.35)
		dm.emission_energy_multiplier = 3.0
		qm.material = dm
		ff.draw_pass_1 = qm

		_forest_root.add_child(ff)
		firefly_nodes.append(ff)

		# Per-firefly point light for glow
		_add_point_light(center + Vector3(0.0, 1.5, 0.0), Color(0.50, 0.80, 0.30), 0.15, 4.0)


func add_god_rays() -> void:
	var ray_mat: StandardMaterial3D = StandardMaterial3D.new()
	ray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray_mat.albedo_color = Color(0.95, 0.90, 0.60, 0.04)
	ray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ray_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ray_mat.no_depth_test = false
	ray_mat.emission_enabled = true
	ray_mat.emission = Color(0.95, 0.90, 0.60)
	ray_mat.emission_energy_multiplier = 0.15

	for zi in [2, 5, 6]:
		var center: Vector3 = _zone_centers[zi]
		for r in 3:
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
	for i in range(0, _zone_centers.size()):
		var center: Vector3 = _zone_centers[i]
		var leaves: GPUParticles3D = GPUParticles3D.new()
		leaves.name = "FallingLeaves_Z%d" % i
		leaves.position = center + Vector3(0.0, 4.0, 0.0)
		leaves.amount = 12
		leaves.lifetime = 8.0
		leaves.one_shot = false
		leaves.explosiveness = 0.0
		leaves.randomness = 1.0
		leaves.visibility_aabb = AABB(Vector3(-12, -8, -12), Vector3(24, 14, 24))

		var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
		mat.direction = Vector3(0.0, -1.0, 0.0)
		mat.spread = 30.0
		mat.initial_velocity_min = 0.3
		mat.initial_velocity_max = 0.8
		mat.gravity = Vector3(0.0, -0.2, 0.0)
		mat.angular_velocity_min = -90.0
		mat.angular_velocity_max = 90.0
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(10.0, 6.0, 10.0)
		mat.scale_min = 0.03
		mat.scale_max = 0.07
		mat.color = Color(0.5, 0.35, 0.15)
		leaves.process_material = mat

		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2(0.06, 0.06)
		leaves.draw_pass_1 = qm

		leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_forest_root.add_child(leaves)


func add_ground_mist() -> void:
	for i in range(0, _zone_centers.size()):
		var center: Vector3 = _zone_centers[i]
		var mist: GPUParticles3D = GPUParticles3D.new()
		mist.name = "GroundMist_Z%d" % i
		mist.position = center + Vector3(0.0, 0.3, 0.0)
		mist.amount = 8
		mist.lifetime = 12.0
		mist.explosiveness = 0.0
		mist.randomness = 1.0
		mist.visibility_aabb = AABB(Vector3(-10, -1, -10), Vector3(20, 3, 20))

		var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
		mat.direction = Vector3(1.0, 0.0, 0.0)
		mat.spread = 180.0
		mat.initial_velocity_min = 0.1
		mat.initial_velocity_max = 0.3
		mat.gravity = Vector3(0.0, 0.0, 0.0)
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(8.0, 0.3, 8.0)
		mat.scale_min = 1.5
		mat.scale_max = 3.0
		mat.color = Color(0.3, 0.4, 0.3, 0.04)
		mist.process_material = mat

		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2(2.0, 1.0)
		var dm: StandardMaterial3D = StandardMaterial3D.new()
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.albedo_color = Color(0.3, 0.4, 0.3, 0.04)
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
