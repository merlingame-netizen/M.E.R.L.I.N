extends RefCounted
## BrocAtmosphere v2 — Zone-aware dynamic fog + volumetric fakes.
## Fog density varies per zone (opaque Z4, lighter clearings).
## LLM can override fog via set_fog_override().

var _forest_root: Node3D
var _zone_centers: Array[Vector3]
var _env: Environment
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _fog_planes: Array[MeshInstance3D] = []
var _mist_curtains: Array[MeshInstance3D] = []
var _god_ray_meshes: Array[MeshInstance3D] = []
var _time: float = 0.0

## Zone fog profiles: density per zone index
const ZONE_FOG: Array[float] = [
	0.020,  # Z0 Lisiere — light mist
	0.035,  # Z1 Dense — moderate
	0.015,  # Z2 Dolmen — clearing
	0.045,  # Z3 Mare — wet haze
	0.080,  # Z4 Profonde — near-opaque at 4m
	0.015,  # Z5 Fontaine — clearing
	0.015,  # Z6 Cercle — clearing
]

var _current_fog_target: float = 0.025
var _current_fog: float = 0.025
var _fog_lerp_speed: float = 0.5  # lerp per second (reaches target in ~2s)

## LLM override
var _fog_override: float = -1.0  # negative = no override
var _fog_override_timer: float = 0.0


func _init(forest_root: Node3D, zone_centers: Array[Vector3], env: Environment = null) -> void:
	_forest_root = forest_root
	_zone_centers = zone_centers
	_env = env
	_rng.randomize()
	_create_fog_planes()
	_create_mist_curtains()
	_create_enhanced_god_rays()
	print("[BrocAtmosphere v2] Zone fog + volumetric fakes ready")


func set_environment(env: Environment) -> void:
	_env = env


func set_fog_override(density: float, duration: float) -> void:
	_fog_override = density
	_fog_override_timer = duration


func update(delta: float, day_night_time: float) -> void:
	_time += delta

	# LLM fog override countdown
	if _fog_override_timer > 0.0:
		_fog_override_timer -= delta
		if _fog_override_timer <= 0.0:
			_fog_override = -1.0

	# Lerp fog toward target
	var target: float = _fog_override if _fog_override >= 0.0 else _current_fog_target
	_current_fog = lerpf(_current_fog, target, _fog_lerp_speed * delta)

	# Apply to environment
	if _env:
		_env.fog_density = _current_fog

	# Animate mist curtains drift
	for curtain in _mist_curtains:
		if is_instance_valid(curtain):
			var base_x: float = curtain.get_meta("base_x", curtain.position.x)
			curtain.position.x = base_x + sin(_time * 0.15 + curtain.position.z * 0.1) * 1.5

	# Animate god ray breathing
	for ray in _god_ray_meshes:
		if is_instance_valid(ray):
			var base_alpha: float = 0.035
			var time_factor: float = _dawn_dusk_brightness(day_night_time)
			var breath: float = sin(_time * 0.8 + ray.position.x) * 0.01
			var mat: StandardMaterial3D = ray.get_surface_override_material(0) as StandardMaterial3D
			if mat:
				mat.albedo_color.a = clampf((base_alpha + breath) * time_factor, 0.0, 0.08)

	# Fog planes subtle vertical drift
	for plane in _fog_planes:
		if is_instance_valid(plane):
			var base_y: float = plane.get_meta("base_y", 0.5)
			plane.position.y = base_y + sin(_time * 0.2 + plane.position.x * 0.3) * 0.15


func update_zone(zone_idx: int) -> void:
	if zone_idx >= 0 and zone_idx < ZONE_FOG.size():
		_current_fog_target = ZONE_FOG[zone_idx]


func get_current_fog_density() -> float:
	return _current_fog


func _create_fog_planes() -> void:
	# Use dither dissolve shader — avoids alpha blending (expensive on GL Compat)
	var dissolve_shader: Shader = load("res://shaders/fog_dissolve.gdshader") as Shader
	var heights: Array[float] = [0.2, 0.6, 1.2]
	for zc in _zone_centers:
		for h in heights:
			if _rng.randf() > 0.4:
				var pos: Vector3 = Vector3(zc.x + _rng.randf_range(-4.0, 4.0), h, zc.z + _rng.randf_range(-4.0, 4.0))
				var quad_size: Vector2 = Vector2(_rng.randf_range(8.0, 14.0), _rng.randf_range(6.0, 10.0))
				var mesh: QuadMesh = QuadMesh.new()
				mesh.size = quad_size
				var inst: MeshInstance3D = MeshInstance3D.new()
				inst.mesh = mesh
				inst.position = pos
				inst.rotation_degrees.x = -90.0
				inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if dissolve_shader:
					var mat: ShaderMaterial = ShaderMaterial.new()
					mat.shader = dissolve_shader
					mat.set_shader_parameter("fog_color", Color(0.35, 0.42, 0.32, 1.0))
					mat.set_shader_parameter("near_dist", 2.0)
					mat.set_shader_parameter("far_dist", 12.0 + _rng.randf_range(0.0, 6.0))
					mat.set_shader_parameter("density", 0.6)
					inst.set_surface_override_material(0, mat)
				else:
					# Fallback to alpha if shader not found
					var mat: StandardMaterial3D = StandardMaterial3D.new()
					mat.albedo_color = Color(0.35, 0.42, 0.32, 0.025)
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					inst.set_surface_override_material(0, mat)
				inst.set_meta("base_y", h)
				_forest_root.add_child(inst)
				_fog_planes.append(inst)


func _create_mist_curtains() -> void:
	if _zone_centers.size() < 2:
		return
	for i in range(_zone_centers.size() - 1):
		var mid: Vector3 = (_zone_centers[i] + _zone_centers[i + 1]) * 0.5
		mid.y = 1.5
		var curtain: MeshInstance3D = _make_billboard_quad(
			mid,
			Vector2(12.0, 5.0),
			Color(0.30, 0.38, 0.30, 0.02),
			false
		)
		curtain.set_meta("base_x", mid.x)
		_mist_curtains.append(curtain)


func _create_enhanced_god_rays() -> void:
	var clearing_indices: Array[int] = [2, 5, 6]
	for zi in clearing_indices:
		if zi >= _zone_centers.size():
			continue
		var zc: Vector3 = _zone_centers[zi]
		for _r in range(5):
			var pos: Vector3 = Vector3(
				zc.x + _rng.randf_range(-5.0, 5.0),
				_rng.randf_range(2.0, 5.0),
				zc.z + _rng.randf_range(-5.0, 5.0)
			)
			var ray: MeshInstance3D = _make_billboard_quad(
				pos,
				Vector2(_rng.randf_range(0.3, 0.8), _rng.randf_range(3.0, 6.0)),
				Color(0.95, 0.90, 0.70, 0.035),
				false
			)
			_god_ray_meshes.append(ray)


func _make_billboard_quad(pos: Vector3, quad_size: Vector2, color: Color, horizontal: bool) -> MeshInstance3D:
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = quad_size

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	if not horizontal:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y

	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.set_surface_override_material(0, mat)
	inst.position = pos
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if horizontal:
		inst.rotation_degrees.x = -90.0

	_forest_root.add_child(inst)
	return inst


func _dawn_dusk_brightness(t: float) -> float:
	if t > 0.65 and t < 0.85:
		return 0.15
	var dawn_factor: float = 1.0 - clampf(absf(t - 0.0) * 5.0, 0.0, 1.0)
	var dusk_factor: float = 1.0 - clampf(absf(t - 0.5) * 5.0, 0.0, 1.0)
	var noon_dim: float = 1.0 - clampf(absf(t - 0.25) * 4.0, 0.0, 1.0) * 0.4
	return clampf(maxf(dawn_factor, dusk_factor) + noon_dim * 0.6, 0.15, 1.0)
