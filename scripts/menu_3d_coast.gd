## Menu3DCoast — Scène menu principal 3D : falaise grise + océan + cabane fumante
## Cycle jour/nuit temps réel (Animal Crossing style), low-poly, glitches rares.
## UI apparaît progressivement après simulation de chargement PC.

extends Node

# --- Preloads ---
const BrocDayNight = preload("res://scripts/broceliande_3d/broc_day_night.gd")

# --- Scene refs ---
var _world: Node3D
var _camera: Camera3D
var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _day_night: RefCounted
var _ocean_mesh: MeshInstance3D
var _ocean_time: float = 0.0
var _floating_stones: Array[MeshInstance3D] = []
var _floating_angles: Array[float] = []
var _tower_pos: Vector3 = Vector3(2.0, 4.0, -12.0)
var _wave_strips: Array[MeshInstance3D] = []
var _wave_base_z: Array[float] = []
var _wave_base_x: Array[float] = []
var _crash_strips: Array[MeshInstance3D] = []

# --- UI refs ---
var _ui_layer: CanvasLayer
var _boot_label: RichTextLabel
var _menu_container: VBoxContainer
var _title_label: Label
var _buttons: Array[Button] = []

# --- State ---
var _boot_phase: bool = true
var _boot_timer: float = 0.0
var _boot_lines: Array[String] = [
	"[color=#20ff40]CeltOS v3.7.2 — Initialisation systeme...[/color]",
	"[color=#20ff40]Memoire: 16384 Ko OK[/color]",
	"[color=#20ff40]Detection peripheriques... OK[/color]",
	"[color=#20ff40]Chargement noyau druidique...[/color]",
	"[color=#20ff40]Connexion au Reseau des Pierres... OK[/color]",
	"[color=#20ff40]Synchronisation temporelle...[/color]",
	"[color=#20ff40]M.E.R.L.I.N. ready.[/color]",
]
var _boot_line_idx: int = 0
var _boot_line_timer: float = 0.0
var _menu_visible: bool = false
var _glitch_timer: float = 0.0
var _glitch_cooldown: float = 15.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	# Disable CRT autoload CanvasLayers (hint_screen_texture breaks 3D in GL Compat)
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child != self:
			child.visible = false
			for sub in child.get_children():
				sub.queue_free()

	_build_3d_world()
	_build_ui()
	_start_boot_sequence()


func _process(delta: float) -> void:
	# Day/night disabled — fixed bright lighting for menu

	# Ocean wave strips animation — multi-frequency reactive waves
	_ocean_time += delta
	for i in _wave_strips.size():
		if not is_instance_valid(_wave_strips[i]):
			continue
		var fi: float = float(i)
		var wave_y: float = sin(_ocean_time * 1.5 + fi * 0.8) * 0.4 + sin(_ocean_time * 0.7 + fi * 1.3) * 0.25 + sin(_ocean_time * 2.2 + fi * 0.3) * 0.15
		_wave_strips[i].position.y = -4.5 + wave_y
		_wave_strips[i].rotation.x = sin(_ocean_time * 0.9 + fi * 0.5) * 0.08
		if i < _wave_base_x.size():
			_wave_strips[i].position.x = _wave_base_x[i] + sin(_ocean_time * 0.3 + fi * 0.7) * 0.5

	# Crash zone strips — faster, choppier
	for i in _crash_strips.size():
		if not is_instance_valid(_crash_strips[i]):
			continue
		var fi: float = float(i)
		var crash_y: float = sin(_ocean_time * 3.0 + fi * 1.2) * 0.5 + sin(_ocean_time * 2.0 + fi * 0.9) * 0.3
		_crash_strips[i].position.y = -5.0 + crash_y
		_crash_strips[i].rotation.x = sin(_ocean_time * 2.5 + fi * 0.8) * 0.12

	# Floating stones orbit around tower
	for i in _floating_stones.size():
		if i >= _floating_angles.size():
			break
		var stone: MeshInstance3D = _floating_stones[i]
		if not is_instance_valid(stone):
			continue
		_floating_angles[i] += delta * (0.15 + float(i) * 0.02)
		var angle: float = _floating_angles[i]
		var radius: float = 3.0 + float(i % 4) * 0.8
		var height: float = 8.0 + float(i % 3) * 3.0 + sin(_ocean_time * 0.5 + float(i)) * 0.5
		stone.position = _tower_pos + Vector3(cos(angle) * radius, height, sin(angle) * radius)
		stone.rotation.y = angle
		stone.rotation.x = sin(_ocean_time * 0.3 + float(i) * 0.7) * 0.2

	# Boot sequence
	if _boot_phase:
		_update_boot(delta)

	# Rare glitches
	_glitch_timer += delta
	if _glitch_timer >= _glitch_cooldown and _menu_visible:
		_glitch_timer = 0.0
		_glitch_cooldown = _rng.randf_range(12.0, 30.0)
		_trigger_glitch()


# ═══════════════════════════════════════════════════════════════════════════════
# 3D WORLD — Low-poly cliff + ocean + cabin
# ═══════════════════════════════════════════════════════════════════════════════

func _build_3d_world() -> void:
	_world = Node3D.new()
	_world.name = "World3D"
	add_child(_world)

	# Camera — low at ocean level, looking UP at cliff face + tower (dramatic side view)
	_camera = Camera3D.new()
	_camera.position = Vector3(35.0, 3.0, -30.0)
	_camera.fov = 50.0
	_camera.current = true
	_camera.far = 200.0
	_world.add_child(_camera)
	# Look up at cliff edge + tower silhouette against sky
	_camera.look_at(Vector3(-5.0, 8.0, -5.0), Vector3.UP)

	# Environment
	_env = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.40, 0.65, 0.95)  # Vivid blue sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.80, 0.85, 0.95)  # Cooler, bluer
	env.ambient_light_energy = 1.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.65, 0.80, 0.95)  # Blue-tinted fog
	env.fog_density = 0.0005
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.3
	_env.environment = env
	_world.add_child(_env)

	# Sun — realtime position
	_sun = DirectionalLight3D.new()
	_sun.light_color = Color(1.0, 0.95, 0.85)
	_sun.light_energy = 2.5
	_sun.shadow_enabled = false
	_sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)  # High noon, slightly angled
	_world.add_child(_sun)

	# Fill light
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20.0, 150.0, 0.0)
	fill.light_color = Color(0.50, 0.55, 0.65)
	fill.light_energy = 0.4
	fill.shadow_enabled = false
	_world.add_child(fill)

	# --- CLIFF (green, lush) ---
	_build_cliff()

	# --- OCEAN (geometric waves) ---
	_build_ocean()

	# --- CELTIC TOWER (ruined, floating stones) ---
	_build_tower()

	# --- CABIN (small, smoking) ---
	_build_cabin()

	# --- SUN (3D halo sphere) ---
	_build_sun_sphere()

	# --- CLOUDS (billboard quads) ---
	_build_clouds()

	# --- CRYSTALS (emissive prisms) ---
	_build_crystals()

	# --- MAGIC PARTICLES around tower ---
	_build_magic_particles()

	# --- GRASS + vegetation on cliff ---
	_build_cliff_grass()

	# --- DISTANT ISLANDS (depth) ---
	_build_distant_islands()


func _build_cliff() -> void:
	# Main cliff top — green plateau
	var cliff: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(50.0, 4.0, 25.0)
	cliff.mesh = bm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.45, 0.22)
	mat.roughness = 0.95
	cliff.material_override = mat
	cliff.position = Vector3(-5.0, 2.0, 0.0)
	cliff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(cliff)

	# --- LAYERED CLIFF FACE — 10 overlapping rock strata for textured look ---
	var cliff_layers: Array[Dictionary] = [
		{"size": Vector3(45.0, 3.0, 2.5), "pos": Vector3(-5.0, 0.0, -13.5), "rot": 0.0, "c": Color(0.38, 0.32, 0.24)},
		{"size": Vector3(35.0, 1.5, 3.2), "pos": Vector3(-3.0, -1.5, -13.0), "rot": 0.02, "c": Color(0.34, 0.28, 0.20)},
		{"size": Vector3(40.0, 2.0, 1.8), "pos": Vector3(-6.0, -3.5, -14.2), "rot": -0.03, "c": Color(0.32, 0.27, 0.19)},
		{"size": Vector3(42.0, 2.5, 2.8), "pos": Vector3(-4.0, -5.5, -13.8), "rot": 0.04, "c": Color(0.36, 0.30, 0.22)},
		{"size": Vector3(38.0, 1.8, 2.2), "pos": Vector3(-7.0, -7.0, -14.5), "rot": -0.02, "c": Color(0.30, 0.25, 0.18)},
		{"size": Vector3(44.0, 2.2, 2.0), "pos": Vector3(-3.5, -8.8, -13.6), "rot": 0.03, "c": Color(0.33, 0.29, 0.21)},
		{"size": Vector3(36.0, 1.6, 3.0), "pos": Vector3(-8.0, -2.8, -12.8), "rot": -0.04, "c": Color(0.37, 0.31, 0.23)},
		{"size": Vector3(30.0, 2.0, 2.5), "pos": Vector3(-2.0, -4.8, -14.0), "rot": 0.05, "c": Color(0.28, 0.24, 0.17)},
		{"size": Vector3(25.0, 1.4, 2.8), "pos": Vector3(5.0, -6.5, -13.2), "rot": -0.03, "c": Color(0.35, 0.30, 0.22)},
		{"size": Vector3(20.0, 1.8, 2.4), "pos": Vector3(-12.0, -9.0, -14.3), "rot": 0.02, "c": Color(0.31, 0.26, 0.19)},
	]
	for layer in cliff_layers:
		var face: MeshInstance3D = MeshInstance3D.new()
		var face_bm: BoxMesh = BoxMesh.new()
		face_bm.size = layer["size"] as Vector3
		face.mesh = face_bm
		var face_mat: StandardMaterial3D = StandardMaterial3D.new()
		face_mat.albedo_color = layer["c"] as Color
		face_mat.roughness = 1.0
		face.material_override = face_mat
		face.position = layer["pos"] as Vector3
		face.rotation.z = layer["rot"] as float
		face.rotation.y = _rng.randf_range(-0.03, 0.03)
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(face)

	# --- ROCK OUTCROPS — 8 protruding rock knobs on the cliff face ---
	for i in 8:
		var outcrop: MeshInstance3D = MeshInstance3D.new()
		var obm: BoxMesh = BoxMesh.new()
		obm.size = Vector3(
			_rng.randf_range(1.0, 3.0),
			_rng.randf_range(0.5, 1.5),
			_rng.randf_range(0.5, 1.2)
		)
		outcrop.mesh = obm
		var omat: StandardMaterial3D = StandardMaterial3D.new()
		omat.albedo_color = Color(0.30 + _rng.randf() * 0.08, 0.25 + _rng.randf() * 0.06, 0.18 + _rng.randf() * 0.05)
		omat.roughness = 1.0
		outcrop.material_override = omat
		outcrop.position = Vector3(
			_rng.randf_range(-22.0, 18.0),
			_rng.randf_range(-9.0, 0.0),
			-12.5 + _rng.randf_range(-1.0, 0.5)
		)
		outcrop.rotation = Vector3(
			_rng.randf_range(-0.15, 0.15),
			_rng.randf_range(-0.3, 0.3),
			_rng.randf_range(-0.1, 0.1)
		)
		outcrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(outcrop)

	# --- SERRATED CLIFF TOP EDGE — uneven grassline ---
	for i in 12:
		var edge_box: MeshInstance3D = MeshInstance3D.new()
		var ebm: BoxMesh = BoxMesh.new()
		var ew: float = _rng.randf_range(2.5, 5.0)
		var eh: float = _rng.randf_range(0.5, 2.0)
		ebm.size = Vector3(ew, eh, _rng.randf_range(1.5, 3.0))
		edge_box.mesh = ebm
		var emat: StandardMaterial3D = StandardMaterial3D.new()
		emat.albedo_color = Color(0.28 + _rng.randf() * 0.06, 0.42 + _rng.randf() * 0.08, 0.20 + _rng.randf() * 0.05)
		emat.roughness = 0.95
		edge_box.material_override = emat
		var x_spread: float = -20.0 + float(i) * 3.5 + _rng.randf_range(-1.0, 1.0)
		edge_box.position = Vector3(x_spread, 4.0 + eh * 0.3, -11.0 + _rng.randf_range(-1.0, 0.5))
		edge_box.rotation.y = _rng.randf_range(-0.1, 0.1)
		edge_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(edge_box)

	# Fog wisps near cliff edge (horizontal drift)
	var fog_wisps: GPUParticles3D = GPUParticles3D.new()
	fog_wisps.amount = 15
	fog_wisps.lifetime = 8.0
	fog_wisps.position = Vector3(-5.0, 2.0, -12.0)

	var fog_pmat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	fog_pmat.direction = Vector3(1.0, 0.1, 0.3)
	fog_pmat.spread = 25.0
	fog_pmat.initial_velocity_min = 0.5
	fog_pmat.initial_velocity_max = 1.5
	fog_pmat.gravity = Vector3(0.0, 0.0, 0.0)
	fog_pmat.scale_min = 1.5
	fog_pmat.scale_max = 4.0
	fog_pmat.color = Color(0.85, 0.88, 0.92, 0.2)
	fog_pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fog_pmat.emission_box_extents = Vector3(20.0, 1.0, 3.0)
	fog_wisps.process_material = fog_pmat

	var fog_mesh: QuadMesh = QuadMesh.new()
	fog_mesh.size = Vector2(3.0, 1.5)
	var fog_draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	fog_draw_mat.albedo_color = Color(0.85, 0.88, 0.92, 0.2)
	fog_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fog_draw_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fog_mesh.material = fog_draw_mat
	fog_wisps.draw_pass_1 = fog_mesh
	fog_wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(fog_wisps)

	# Cliff ledge rocks — jagged outcrops on the face
	for i in 12:
		var rock: MeshInstance3D = MeshInstance3D.new()
		var rbm: BoxMesh = BoxMesh.new()
		var w: float = _rng.randf_range(2.0, 5.0)
		var h: float = _rng.randf_range(2.0, 6.0)
		rbm.size = Vector3(w, h, _rng.randf_range(1.5, 3.0))
		rock.mesh = rbm
		var rmat: StandardMaterial3D = StandardMaterial3D.new()
		rmat.albedo_color = Color(0.25 + _rng.randf() * 0.1, 0.38 + _rng.randf() * 0.12, 0.18 + _rng.randf() * 0.08)
		rmat.roughness = 1.0
		rock.material_override = rmat
		rock.position = Vector3(_rng.randf_range(-20.0, 15.0), -2.0 - _rng.randf() * 5.0, -14.0 + _rng.randf_range(-2.0, 1.0))
		rock.rotation.y = _rng.randf_range(-0.3, 0.3)
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(rock)


func _build_ocean() -> void:
	# --- 40 THIN wave strips — high-definition faceted ocean ---
	var near_color: Color = Color(0.15, 0.40, 0.55)
	var deep_color: Color = Color(0.03, 0.12, 0.28)

	for i in 40:
		var strip: MeshInstance3D = MeshInstance3D.new()
		var strip_bm: BoxMesh = BoxMesh.new()
		strip_bm.size = Vector3(60.0, 0.15, 1.5)
		strip.mesh = strip_bm
		var smat: StandardMaterial3D = StandardMaterial3D.new()
		var depth_t: float = float(i) / 40.0
		smat.albedo_color = near_color.lerp(deep_color, depth_t)
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.roughness = 1.0
		strip.material_override = smat
		var base_z: float = -15.0 - float(i) * 1.75
		var base_x: float = -5.0
		strip.position = Vector3(base_x, -4.5, base_z)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(strip)
		_wave_strips.append(strip)
		_wave_base_z.append(base_z)
		_wave_base_x.append(base_x)

	# Whitecap foam crests on every 4th strip
	var foam_crest_mat: StandardMaterial3D = StandardMaterial3D.new()
	foam_crest_mat.albedo_color = Color(0.75, 0.85, 0.90, 0.7)
	foam_crest_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_crest_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for wi in 40:
		if wi % 4 != 0:
			continue
		var cap: MeshInstance3D = MeshInstance3D.new()
		var cap_bm: BoxMesh = BoxMesh.new()
		cap_bm.size = Vector3(55.0, 0.08, 0.6)
		cap.mesh = cap_bm
		cap.material_override = foam_crest_mat
		cap.position = Vector3(-5.0, -4.2, -15.0 - float(wi) * 1.75)
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(cap)

	# --- WAVE CRASH ZONE at cliff base (z ~ -14 to -16) ---
	var crash_color: Color = Color(0.40, 0.55, 0.65)
	for i in 5:
		var crash: MeshInstance3D = MeshInstance3D.new()
		var crash_bm: BoxMesh = BoxMesh.new()
		crash_bm.size = Vector3(50.0, 0.2, 1.0)
		crash.mesh = crash_bm
		var cmat: StandardMaterial3D = StandardMaterial3D.new()
		cmat.albedo_color = crash_color.lerp(Color(0.60, 0.70, 0.78), float(i) / 5.0)
		cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		crash.material_override = cmat
		crash.position = Vector3(-5.0, -5.0, -14.0 - float(i) * 0.5)
		crash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(crash)
		_crash_strips.append(crash)

	# Keep _ocean_mesh for backward compat (first strip)
	_ocean_mesh = _wave_strips[0] if not _wave_strips.is_empty() else null

	# Foam/spray particles at cliff base
	var spray: GPUParticles3D = GPUParticles3D.new()
	spray.amount = 30
	spray.lifetime = 2.5
	spray.position = Vector3(-5.0, -5.0, -15.0)

	var spray_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	spray_mat.direction = Vector3(0.0, 1.0, 0.5)
	spray_mat.spread = 60.0
	spray_mat.initial_velocity_min = 1.0
	spray_mat.initial_velocity_max = 3.0
	spray_mat.gravity = Vector3(0.0, -3.0, 0.0)
	spray_mat.scale_min = 0.08
	spray_mat.scale_max = 0.25
	spray_mat.color = Color(0.80, 0.85, 0.90, 0.5)
	spray_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	spray_mat.emission_box_extents = Vector3(15.0, 0.3, 1.0)
	spray.process_material = spray_mat

	var spray_mesh: SphereMesh = SphereMesh.new()
	spray_mesh.radius = 0.1
	spray_mesh.height = 0.2
	spray_mesh.radial_segments = 4
	spray_mesh.rings = 2
	spray.draw_pass_1 = spray_mesh
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(spray)

	# White foam line at cliff base
	var foam: MeshInstance3D = MeshInstance3D.new()
	var fbm: BoxMesh = BoxMesh.new()
	fbm.size = Vector3(40.0, 0.5, 3.0)
	foam.mesh = fbm
	var fmat: StandardMaterial3D = StandardMaterial3D.new()
	fmat.albedo_color = Color(0.85, 0.90, 0.95, 0.6)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam.material_override = fmat
	foam.position = Vector3(-5.0, -5.5, -15.0)
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(foam)

	# Distant rock formations — multi-box clusters, not raw cubes
	var rock_mat: StandardMaterial3D = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.22, 0.20, 0.18)
	rock_mat.roughness = 1.0
	var rock_positions: Array[Vector3] = [
		Vector3(15.0, -4.0, -35.0),
		Vector3(-18.0, -3.8, -45.0),
		Vector3(8.0, -4.2, -55.0),
		Vector3(-10.0, -3.5, -40.0),
		Vector3(22.0, -4.0, -50.0),
	]
	for rp in rock_positions:
		# Main rock body
		var rock: MeshInstance3D = MeshInstance3D.new()
		var rbm: BoxMesh = BoxMesh.new()
		var rw: float = _rng.randf_range(1.5, 3.5)
		var rh: float = _rng.randf_range(2.0, 4.5)
		rbm.size = Vector3(rw, rh, _rng.randf_range(1.5, 3.0))
		rock.mesh = rbm
		rock.material_override = rock_mat
		rock.position = rp
		rock.rotation.y = _rng.randf_range(0.0, TAU)
		rock.rotation.z = _rng.randf_range(-0.15, 0.15)
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(rock)
		# Secondary shard beside main rock
		var shard: MeshInstance3D = MeshInstance3D.new()
		var shard_bm: BoxMesh = BoxMesh.new()
		shard_bm.size = Vector3(rw * 0.4, rh * 0.7, _rng.randf_range(0.5, 1.2))
		shard.mesh = shard_bm
		var shard_mat: StandardMaterial3D = StandardMaterial3D.new()
		shard_mat.albedo_color = Color(0.25, 0.22, 0.20)
		shard_mat.roughness = 1.0
		shard.material_override = shard_mat
		shard.position = rp + Vector3(_rng.randf_range(-1.0, 1.0), 0.3, _rng.randf_range(-0.5, 0.5))
		shard.rotation = Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.15, 0.15))
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(shard)


func _build_cabin() -> void:
	# Small cabin — far left on cliff top
	var cabin_pos: Vector3 = Vector3(-12.0, 4.2, -8.0)

	# Walls
	var walls: MeshInstance3D = MeshInstance3D.new()
	var wbm: BoxMesh = BoxMesh.new()
	wbm.size = Vector3(2.5, 2.0, 2.5)
	walls.mesh = wbm
	var wmat: StandardMaterial3D = StandardMaterial3D.new()
	wmat.albedo_color = Color(0.30, 0.22, 0.15)
	wmat.roughness = 1.0
	walls.material_override = wmat
	walls.position = cabin_pos
	walls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(walls)

	# Door (dark rectangle on front face)
	var door: MeshInstance3D = MeshInstance3D.new()
	var door_bm: BoxMesh = BoxMesh.new()
	door_bm.size = Vector3(0.6, 1.2, 0.05)
	door.mesh = door_bm
	var door_mat: StandardMaterial3D = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.10, 0.08, 0.06)
	door_mat.roughness = 1.0
	door.material_override = door_mat
	door.position = cabin_pos + Vector3(0.0, -0.4, 1.28)
	door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(door)

	# Roof (tilted box)
	var roof: MeshInstance3D = MeshInstance3D.new()
	var rbm: BoxMesh = BoxMesh.new()
	rbm.size = Vector3(3.0, 0.3, 3.2)
	roof.mesh = rbm
	var rmat: StandardMaterial3D = StandardMaterial3D.new()
	rmat.albedo_color = Color(0.20, 0.15, 0.10)
	rmat.roughness = 1.0
	roof.material_override = rmat
	roof.position = cabin_pos + Vector3(0.0, 1.3, 0.0)
	roof.rotation_degrees.z = 8.0
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(roof)

	# Chimney (thin box on roof)
	var chimney: MeshInstance3D = MeshInstance3D.new()
	var chim_bm: BoxMesh = BoxMesh.new()
	chim_bm.size = Vector3(0.35, 1.0, 0.35)
	chimney.mesh = chim_bm
	var chim_mat: StandardMaterial3D = StandardMaterial3D.new()
	chim_mat.albedo_color = Color(0.25, 0.20, 0.15)
	chim_mat.roughness = 1.0
	chimney.material_override = chim_mat
	chimney.position = cabin_pos + Vector3(0.8, 2.0, 0.0)
	chimney.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(chimney)

	# Chimney smoke — GPUParticles3D
	var smoke: GPUParticles3D = GPUParticles3D.new()
	smoke.amount = 20
	smoke.lifetime = 6.0
	smoke.position = cabin_pos + Vector3(0.8, 2.5, 0.0)

	var smat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	smat.direction = Vector3(0.2, 1.0, 0.0)
	smat.spread = 15.0
	smat.initial_velocity_min = 0.2
	smat.initial_velocity_max = 0.5
	smat.gravity = Vector3(0.1, 0.05, 0.0)
	smat.scale_min = 0.3
	smat.scale_max = 0.8
	smat.color = Color(0.6, 0.6, 0.6, 0.3)
	smat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smat.emission_sphere_radius = 0.2
	smoke.process_material = smat

	var smoke_mesh: SphereMesh = SphereMesh.new()
	smoke_mesh.radius = 0.15
	smoke_mesh.height = 0.3
	smoke_mesh.radial_segments = 4
	smoke_mesh.rings = 2
	smoke.draw_pass_1 = smoke_mesh
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(smoke)


func _build_cliff_grass() -> void:
	# Dense grass (500 quads)
	var grass_mat: StandardMaterial3D = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.30, 0.50, 0.20)
	grass_mat.roughness = 1.0
	grass_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(0.4, 0.6)
	qm.material = grass_mat
	mm.mesh = qm
	mm.instance_count = 500

	for i in 500:
		var t: Transform3D = Transform3D.IDENTITY
		var scale_f: float = _rng.randf_range(0.5, 1.5)
		t = t.scaled(Vector3(scale_f, scale_f, scale_f))
		t = t.rotated(Vector3.UP, _rng.randf_range(0.0, TAU))
		t.origin = Vector3(
			_rng.randf_range(-18.0, 18.0),
			4.1,
			_rng.randf_range(-18.0, 5.0)
		)
		mm.set_instance_transform(i, t)

	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(mmi)

	# Bushes (varied green spheres, 60 instances — lush vegetation)
	var bush_mat: StandardMaterial3D = StandardMaterial3D.new()
	bush_mat.albedo_color = Color(0.25, 0.50, 0.15)
	bush_mat.roughness = 1.0

	var bush_mm: MultiMesh = MultiMesh.new()
	bush_mm.transform_format = MultiMesh.TRANSFORM_3D
	bush_mm.use_colors = true
	var bush_mesh: SphereMesh = SphereMesh.new()
	bush_mesh.radius = 1.0
	bush_mesh.height = 1.8
	bush_mesh.radial_segments = 6
	bush_mesh.rings = 3
	bush_mesh.material = bush_mat
	bush_mm.mesh = bush_mesh
	bush_mm.instance_count = 60

	for i in 60:
		var bt: Transform3D = Transform3D.IDENTITY
		var bs: float = _rng.randf_range(0.4, 1.4)
		bt = bt.scaled(Vector3(bs, bs * 0.7, bs))
		if false:
			pass  # Removed hanging bushes (looked like floating green boxes)
		else:
			bt.origin = Vector3(
				_rng.randf_range(-16.0, 16.0),
				4.3,
				_rng.randf_range(-8.0, 3.0)
			)
		bush_mm.set_instance_transform(i, bt)
		# Varied green shades per instance
		var green_t: float = _rng.randf()
		var bush_color: Color = Color(0.25, 0.50, 0.15).lerp(Color(0.35, 0.55, 0.20), green_t)
		bush_mm.set_instance_color(i, bush_color)

	var bush_mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	bush_mmi.multimesh = bush_mm
	bush_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(bush_mmi)

	# Grass tufts on cliff surface (30 tiny prisms)
	var tuft_mm: MultiMesh = MultiMesh.new()
	tuft_mm.transform_format = MultiMesh.TRANSFORM_3D
	tuft_mm.use_colors = true
	var tuft_mesh: PrismMesh = PrismMesh.new()
	tuft_mesh.size = Vector3(0.16, 0.3, 0.16)
	var tuft_mat: StandardMaterial3D = StandardMaterial3D.new()
	tuft_mat.albedo_color = Color(0.25, 0.55, 0.18)
	tuft_mat.roughness = 1.0
	tuft_mesh.material = tuft_mat
	tuft_mm.mesh = tuft_mesh
	tuft_mm.instance_count = 30

	for ti in 30:
		var tt: Transform3D = Transform3D.IDENTITY
		var ts: float = _rng.randf_range(0.6, 1.4)
		tt = tt.scaled(Vector3(ts, ts, ts))
		tt = tt.rotated(Vector3.UP, _rng.randf_range(0.0, TAU))
		tt.origin = Vector3(
			_rng.randf_range(-15.0, 12.0),
			4.05,
			_rng.randf_range(-10.0, 4.0)
		)
		tuft_mm.set_instance_transform(ti, tt)
		var g_shade: float = _rng.randf_range(0.0, 1.0)
		tuft_mm.set_instance_color(ti, Color(0.2, 0.45, 0.12).lerp(Color(0.35, 0.6, 0.2), g_shade))

	var tuft_mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	tuft_mmi.multimesh = tuft_mm
	tuft_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(tuft_mmi)

	# Standing stones / menhirs — multi-box sculpted shapes (7 stones)
	var stone_mat: StandardMaterial3D = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.25, 0.23, 0.22)
	stone_mat.roughness = 1.0
	var stone_cap_mat: StandardMaterial3D = StandardMaterial3D.new()
	stone_cap_mat.albedo_color = Color(0.28, 0.26, 0.24)
	stone_cap_mat.roughness = 1.0

	for i in 7:
		var mh: float = _rng.randf_range(3.0, 5.0)
		var mpos: Vector3 = Vector3(
			_rng.randf_range(-15.0, -5.0),
			4.0 + mh * 0.5,
			_rng.randf_range(-12.0, 0.0)
		)
		var mrot_y: float = _rng.randf_range(0.0, TAU)
		# Main tall body
		var menhir: MeshInstance3D = MeshInstance3D.new()
		var mbm: BoxMesh = BoxMesh.new()
		mbm.size = Vector3(0.5, mh, 0.4)
		menhir.mesh = mbm
		menhir.material_override = stone_mat
		menhir.position = mpos
		menhir.rotation = Vector3(_rng.randf_range(-0.1, 0.1), mrot_y, _rng.randf_range(-0.05, 0.05))
		menhir.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(menhir)
		# Cap piece — thinner, tilted differently
		var cap: MeshInstance3D = MeshInstance3D.new()
		var cap_bm: BoxMesh = BoxMesh.new()
		cap_bm.size = Vector3(0.35, mh * 0.3, 0.3)
		cap.mesh = cap_bm
		cap.material_override = stone_cap_mat
		cap.position = mpos + Vector3(_rng.randf_range(-0.1, 0.1), mh * 0.45, _rng.randf_range(-0.1, 0.1))
		cap.rotation = Vector3(_rng.randf_range(-0.2, 0.2), mrot_y + 0.4, _rng.randf_range(-0.15, 0.15))
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(cap)

	# --- VEGETATION EDGE — organic treeline silhouette along cliff edge ---
	var veg_mat: StandardMaterial3D = StandardMaterial3D.new()
	veg_mat.albedo_color = Color(0.22, 0.42, 0.16)
	veg_mat.roughness = 1.0
	for vi in 18:
		var veg: MeshInstance3D = MeshInstance3D.new()
		var veg_bm: BoxMesh = BoxMesh.new()
		var vs: float = _rng.randf_range(0.3, 0.8)
		veg_bm.size = Vector3(vs, vs * _rng.randf_range(0.8, 1.5), vs * 0.8)
		veg.mesh = veg_bm
		var vmat: StandardMaterial3D = StandardMaterial3D.new()
		vmat.albedo_color = Color(0.20 + _rng.randf() * 0.08, 0.38 + _rng.randf() * 0.12, 0.14 + _rng.randf() * 0.06)
		vmat.roughness = 1.0
		veg.material_override = vmat
		veg.position = Vector3(
			-18.0 + float(vi) * 2.1 + _rng.randf_range(-0.8, 0.8),
			4.2 + _rng.randf_range(0.0, 1.0),
			-11.0 + _rng.randf_range(-1.0, 0.5)
		)
		veg.rotation.y = _rng.randf_range(0.0, TAU)
		veg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(veg)


# ═══════════════════════════════════════════════════════════════════════════════
# CELTIC TOWER — Ruined tower with floating stones
# ═══════════════════════════════════════════════════════════════════════════════

func _build_tower() -> void:
	var tower_pos: Vector3 = Vector3(2.0, 4.0, -12.0)
	var stone_mat: StandardMaterial3D = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.40, 0.38, 0.32)
	stone_mat.roughness = 0.95

	# Tower base — cylinder approximated with stacked blocks (taller, 1.5x)
	for i in 10:
		var block: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		var height_f: float = float(i)
		bm.size = Vector3(3.0 - height_f * 0.15, 3.0, 3.0 - height_f * 0.15)
		block.mesh = bm
		block.material_override = stone_mat
		block.position = tower_pos + Vector3(0.0, height_f * 2.8, 0.0)
		block.rotation.y = height_f * 0.15
		block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(block)

	# Tower top — pointed roof (raised to match taller tower)
	var roof: MeshInstance3D = MeshInstance3D.new()
	var roof_bm: BoxMesh = BoxMesh.new()
	roof_bm.size = Vector3(2.0, 3.0, 2.0)
	roof.mesh = roof_bm
	var roof_mat: StandardMaterial3D = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.30, 0.35, 0.25)
	roof_mat.roughness = 1.0
	roof.material_override = roof_mat
	roof.position = tower_pos + Vector3(0.0, 29.0, 0.0)
	roof.rotation = Vector3(0.0, 0.3, 0.1)
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(roof)

	# Ruined top — broken stone pieces jutting out at angles
	var ruin_mat: StandardMaterial3D = StandardMaterial3D.new()
	ruin_mat.albedo_color = Color(0.35, 0.33, 0.30)
	ruin_mat.roughness = 1.0
	var ruin_data: Array[Dictionary] = [
		{"size": Vector3(1.2, 2.5, 0.8), "offset": Vector3(0.8, 27.0, 0.5), "rot": Vector3(0.3, 0.2, 0.5)},
		{"size": Vector3(0.9, 2.0, 1.0), "offset": Vector3(-0.6, 26.5, -0.7), "rot": Vector3(-0.4, 0.0, -0.3)},
		{"size": Vector3(1.0, 1.8, 0.7), "offset": Vector3(0.3, 27.5, -0.9), "rot": Vector3(0.2, -0.5, 0.4)},
	]
	for rd in ruin_data:
		var ruin: MeshInstance3D = MeshInstance3D.new()
		var rbm: BoxMesh = BoxMesh.new()
		rbm.size = rd["size"] as Vector3
		ruin.mesh = rbm
		ruin.material_override = ruin_mat
		ruin.position = tower_pos + (rd["offset"] as Vector3)
		ruin.rotation = rd["rot"] as Vector3
		ruin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(ruin)

	# Floating stones around tower (animated orbit in _process)
	for i in 15:
		var stone: MeshInstance3D = MeshInstance3D.new()
		var sbm: BoxMesh = BoxMesh.new()
		sbm.size = Vector3(_rng.randf_range(0.3, 1.2), _rng.randf_range(0.3, 1.0), _rng.randf_range(0.3, 1.2))
		stone.mesh = sbm
		stone.material_override = stone_mat
		stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(stone)
		_floating_stones.append(stone)
		_floating_angles.append(float(i) * TAU / 15.0)

	# --- TOWER WINDOWS — dark recesses at varied heights ---
	var win_mat: StandardMaterial3D = StandardMaterial3D.new()
	win_mat.albedo_color = Color(0.08, 0.06, 0.05)
	win_mat.roughness = 1.0
	var win_data: Array[Dictionary] = [
		{"offset": Vector3(0.0, 8.0, 1.55), "rot_y": 0.0},
		{"offset": Vector3(1.55, 14.0, 0.0), "rot_y": PI * 0.5},
		{"offset": Vector3(-0.3, 20.0, 1.5), "rot_y": 0.15},
	]
	for wd in win_data:
		var win: MeshInstance3D = MeshInstance3D.new()
		var win_bm: BoxMesh = BoxMesh.new()
		win_bm.size = Vector3(0.4, 0.6, 0.1)
		win.mesh = win_bm
		win.material_override = win_mat
		win.position = tower_pos + (wd["offset"] as Vector3)
		win.rotation.y = wd["rot_y"] as float
		win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(win)

	# --- SPIRAL STAIRCASE HINTS — tiny protruding steps ---
	var step_mat: StandardMaterial3D = StandardMaterial3D.new()
	step_mat.albedo_color = Color(0.38, 0.36, 0.30)
	step_mat.roughness = 1.0
	for si in 6:
		var step: MeshInstance3D = MeshInstance3D.new()
		var step_bm: BoxMesh = BoxMesh.new()
		step_bm.size = Vector3(0.3, 0.1, 0.5)
		step.mesh = step_bm
		step.material_override = step_mat
		var step_angle: float = float(si) * 1.05
		var step_h: float = 5.0 + float(si) * 3.5
		step.position = tower_pos + Vector3(sin(step_angle) * 1.6, step_h, cos(step_angle) * 1.6)
		step.rotation.y = step_angle
		step.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(step)

	# --- CRENELLATIONS — broken battlement pieces on tower rim ---
	var cren_mat: StandardMaterial3D = StandardMaterial3D.new()
	cren_mat.albedo_color = Color(0.37, 0.35, 0.30)
	cren_mat.roughness = 1.0
	for ci in 5:
		var cren: MeshInstance3D = MeshInstance3D.new()
		var cren_bm: BoxMesh = BoxMesh.new()
		cren_bm.size = Vector3(0.4, _rng.randf_range(0.6, 1.2), 0.4)
		cren.mesh = cren_bm
		cren.material_override = cren_mat
		var cren_angle: float = float(ci) * TAU / 5.0
		cren.position = tower_pos + Vector3(sin(cren_angle) * 1.2, 28.5, cos(cren_angle) * 1.2)
		cren.rotation.y = cren_angle + _rng.randf_range(-0.2, 0.2)
		cren.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(cren)

	# Moss/vine color bands on tower
	var moss_mat: StandardMaterial3D = StandardMaterial3D.new()
	moss_mat.albedo_color = Color(0.2, 0.4, 0.15)
	moss_mat.roughness = 1.0
	var moss_heights: Array[float] = [4.0, 10.0, 16.0, 22.0]
	for mh_idx in moss_heights.size():
		var moss: MeshInstance3D = MeshInstance3D.new()
		var moss_bm: BoxMesh = BoxMesh.new()
		moss_bm.size = Vector3(0.3, 0.5, 2.5)
		moss.mesh = moss_bm
		moss.material_override = moss_mat
		var angle_offset: float = float(mh_idx) * 1.2
		moss.position = tower_pos + Vector3(sin(angle_offset) * 1.5, moss_heights[mh_idx], cos(angle_offset) * 1.5)
		moss.rotation.y = angle_offset
		moss.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(moss)

	# Glowing window (green gem)
	var gem: MeshInstance3D = MeshInstance3D.new()
	var gem_bm: SphereMesh = SphereMesh.new()
	gem_bm.radius = 0.3
	gem_bm.height = 0.6
	gem_bm.radial_segments = 6
	gem_bm.rings = 3
	gem.mesh = gem_bm
	var gem_mat: StandardMaterial3D = StandardMaterial3D.new()
	gem_mat.albedo_color = Color(0.2, 0.9, 0.4)
	gem_mat.emission_enabled = true
	gem_mat.emission = Color(0.2, 0.9, 0.4)
	gem_mat.emission_energy_multiplier = 3.0
	gem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gem.material_override = gem_mat
	gem.position = tower_pos + Vector3(0.0, 12.0, 1.5)
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(gem)


# ═══════════════════════════════════════════════════════════════════════════════
# SUN — 3D halo sphere (like reference)
# ═══════════════════════════════════════════════════════════════════════════════

func _build_sun_sphere() -> void:
	# Sun glow sphere (unshaded, bright)
	var sun_sphere: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 14.0
	sm.height = 28.0
	sm.radial_segments = 12
	sm.rings = 6
	sun_sphere.mesh = sm
	var smat: StandardMaterial3D = StandardMaterial3D.new()
	smat.albedo_color = Color(1.0, 0.95, 0.70, 0.4)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.cull_mode = BaseMaterial3D.CULL_FRONT  # Visible from inside
	sun_sphere.material_override = smat
	sun_sphere.position = Vector3(-8.0, 22.0, -35.0)
	sun_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(sun_sphere)

	# Sun core (solid bright, bigger)
	var core: MeshInstance3D = MeshInstance3D.new()
	var cm: SphereMesh = SphereMesh.new()
	cm.radius = 5.0
	cm.height = 10.0
	cm.radial_segments = 8
	cm.rings = 4
	core.mesh = cm
	var cmat: StandardMaterial3D = StandardMaterial3D.new()
	cmat.albedo_color = Color(1.0, 0.98, 0.85)
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.material_override = cmat
	core.position = Vector3(-8.0, 22.0, -35.0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(core)

	# Outer halo glow — larger, very transparent sphere behind sun
	var halo: MeshInstance3D = MeshInstance3D.new()
	var hm: SphereMesh = SphereMesh.new()
	hm.radius = 9.0
	hm.height = 18.0
	hm.radial_segments = 10
	hm.rings = 5
	halo.mesh = hm
	var hmat: StandardMaterial3D = StandardMaterial3D.new()
	hmat.albedo_color = Color(1.0, 0.95, 0.7, 0.15)
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	halo.material_override = hmat
	halo.position = Vector3(-8.0, 22.0, -36.0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(halo)

	# Sun omni light — warm glow
	var sun_omni: OmniLight3D = OmniLight3D.new()
	sun_omni.light_color = Color(1.0, 0.95, 0.80)
	sun_omni.light_energy = 3.0
	sun_omni.omni_range = 100.0
	sun_omni.position = Vector3(-8.0, 22.0, -35.0)
	sun_omni.shadow_enabled = false
	_world.add_child(sun_omni)


# ═══════════════════════════════════════════════════════════════════════════════
# CLOUDS — Billboard quads
# ═══════════════════════════════════════════════════════════════════════════════

func _build_clouds() -> void:
	# 14 scattered volumetric cloud clusters across the sky
	for i in 14:
		var base_pos: Vector3 = Vector3(
			_rng.randf_range(-35.0, 45.0),
			_rng.randf_range(10.0, 22.0),
			_rng.randf_range(-55.0, -25.0)
		)
		var base_w: float = _rng.randf_range(4.0, 10.0)
		var base_h: float = _rng.randf_range(1.5, 3.5)
		# 3 overlapping billboard quads per cluster for volumetric look
		for layer_idx in 3:
			var cloud: MeshInstance3D = MeshInstance3D.new()
			var alpha: float = _rng.randf_range(0.3, 0.6) - float(layer_idx) * 0.08
			var layer_mat: StandardMaterial3D = StandardMaterial3D.new()
			layer_mat.albedo_color = Color(0.92, 0.95, 1.0, alpha)
			layer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			layer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			layer_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			layer_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			var qm: QuadMesh = QuadMesh.new()
			var scale_f: float = 1.0 - float(layer_idx) * 0.15
			qm.size = Vector2(base_w * scale_f, base_h * scale_f)
			qm.material = layer_mat
			cloud.mesh = qm
			cloud.position = base_pos + Vector3(
				_rng.randf_range(-1.5, 1.5),
				float(layer_idx) * 0.6,
				_rng.randf_range(-0.5, 0.5)
			)
			cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_world.add_child(cloud)


# ═══════════════════════════════════════════════════════════════════════════════
# CRYSTALS — Emissive prisms on cliff edge
# ═══════════════════════════════════════════════════════════════════════════════

func _build_crystals() -> void:
	var crystal_mat: StandardMaterial3D = StandardMaterial3D.new()
	crystal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crystal_mat.albedo_color = Color(0.55, 0.15, 0.85)  # Vivid purple, unshaded for GL Compat

	for i in 6:
		var h: float = _rng.randf_range(1.0, 3.0)
		var cpos: Vector3 = Vector3(
			_rng.randf_range(-3.0, 8.0),
			4.0 + h * 0.5,
			_rng.randf_range(-14.0, -8.0)
		)
		# Main crystal
		var crystal: MeshInstance3D = MeshInstance3D.new()
		var cbm: BoxMesh = BoxMesh.new()
		cbm.size = Vector3(0.3, h, 0.3)
		crystal.mesh = cbm
		crystal.material_override = crystal_mat
		crystal.position = cpos
		crystal.rotation = Vector3(
			_rng.randf_range(-0.3, 0.3),
			_rng.randf_range(0.0, TAU),
			_rng.randf_range(-0.2, 0.2)
		)
		crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(crystal)
		# Companion shard — smaller, tilted differently
		var shard: MeshInstance3D = MeshInstance3D.new()
		var shard_bm: BoxMesh = BoxMesh.new()
		shard_bm.size = Vector3(0.2, h * 0.5, 0.2)
		shard.mesh = shard_bm
		shard.material_override = crystal_mat
		shard.position = cpos + Vector3(_rng.randf_range(-0.4, 0.4), -h * 0.15, _rng.randf_range(-0.3, 0.3))
		shard.rotation = Vector3(
			_rng.randf_range(-0.5, 0.5),
			_rng.randf_range(0.0, TAU),
			_rng.randf_range(-0.4, 0.4)
		)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(shard)


# ═══════════════════════════════════════════════════════════════════════════════
# MAGIC PARTICLES — Floating around tower
# ═══════════════════════════════════════════════════════════════════════════════

func _build_magic_particles() -> void:
	# Tower magic — green-teal glow orbiting tower top
	var tower_magic: GPUParticles3D = GPUParticles3D.new()
	tower_magic.amount = 25
	tower_magic.lifetime = 6.0
	tower_magic.position = Vector3(2.0, 28.0, -12.0)

	var tm_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	tm_mat.direction = Vector3(0.0, 1.0, 0.0)
	tm_mat.spread = 180.0
	tm_mat.initial_velocity_min = 0.2
	tm_mat.initial_velocity_max = 0.6
	tm_mat.gravity = Vector3(0.0, 0.05, 0.0)
	tm_mat.scale_min = 0.08
	tm_mat.scale_max = 0.2
	tm_mat.color = Color(0.2, 0.9, 0.5, 0.7)
	tm_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	tm_mat.emission_sphere_radius = 4.0
	tm_mat.angular_velocity_min = -60.0
	tm_mat.angular_velocity_max = 60.0
	tower_magic.process_material = tm_mat

	var tm_mesh: SphereMesh = SphereMesh.new()
	tm_mesh.radius = 0.05
	tm_mesh.height = 0.1
	tm_mesh.radial_segments = 4
	tm_mesh.rings = 2
	tower_magic.draw_pass_1 = tm_mesh
	tower_magic.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(tower_magic)

	# Crystal sparkle — purple particles near crystal cluster
	var crystal_sparkle: GPUParticles3D = GPUParticles3D.new()
	crystal_sparkle.amount = 15
	crystal_sparkle.lifetime = 3.0
	crystal_sparkle.position = Vector3(3.0, 5.5, -11.0)

	var cs_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	cs_mat.direction = Vector3(0.0, 1.0, 0.0)
	cs_mat.spread = 90.0
	cs_mat.initial_velocity_min = 0.1
	cs_mat.initial_velocity_max = 0.3
	cs_mat.gravity = Vector3(0.0, 0.02, 0.0)
	cs_mat.scale_min = 0.03
	cs_mat.scale_max = 0.1
	cs_mat.color = Color(0.6, 0.2, 0.9, 0.5)
	cs_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	cs_mat.emission_box_extents = Vector3(3.0, 1.0, 2.0)
	crystal_sparkle.process_material = cs_mat

	var cs_mesh: SphereMesh = SphereMesh.new()
	cs_mesh.radius = 0.04
	cs_mesh.height = 0.08
	cs_mesh.radial_segments = 4
	cs_mesh.rings = 2
	crystal_sparkle.draw_pass_1 = cs_mesh
	crystal_sparkle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(crystal_sparkle)


# ═══════════════════════════════════════════════════════════════════════════════
# DISTANT ISLANDS — Dark silhouettes at horizon for depth
# ═══════════════════════════════════════════════════════════════════════════════

func _build_distant_islands() -> void:
	var island_mat: StandardMaterial3D = StandardMaterial3D.new()
	island_mat.albedo_color = Color(0.15, 0.18, 0.22)
	island_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var island_data: Array[Dictionary] = [
		{"pos": Vector3(-25.0, -1.0, -90.0), "size": Vector3(8.0, 3.0, 4.0)},
		{"pos": Vector3(10.0, -2.0, -95.0), "size": Vector3(6.0, 2.5, 3.0)},
		{"pos": Vector3(30.0, 0.0, -85.0), "size": Vector3(5.0, 2.0, 3.5)},
	]
	for idata in island_data:
		var island: MeshInstance3D = MeshInstance3D.new()
		var pm: PrismMesh = PrismMesh.new()
		pm.size = idata["size"] as Vector3
		island.mesh = pm
		island.material_override = island_mat
		island.position = idata["pos"] as Vector3
		island.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		island.visibility_range_end = 150.0
		_world.add_child(island)


# ═══════════════════════════════════════════════════════════════════════════════
# UI — Boot sequence + progressive menu appearance
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	# Boot text (fullscreen, CRT terminal style)
	_boot_label = RichTextLabel.new()
	_boot_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot_label.bbcode_enabled = true
	_boot_label.scroll_active = false
	_boot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = MerlinVisual.get_font("terminal")
	if font:
		_boot_label.add_theme_font_override("normal_font", font)
	_boot_label.add_theme_font_size_override("normal_font_size", 14)
	_boot_label.add_theme_color_override("default_color", MerlinVisual.CRT_PALETTE["phosphor"])
	_ui_layer.add_child(_boot_label)

	# Menu container (hidden initially)
	_menu_container = VBoxContainer.new()
	_menu_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_menu_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_menu_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_menu_container.offset_left = -460.0
	_menu_container.offset_right = -20.0
	_menu_container.offset_top = -300.0
	_menu_container.offset_bottom = -20.0
	_menu_container.alignment = BoxContainer.ALIGNMENT_END
	_menu_container.add_theme_constant_override("separation", 16)
	_menu_container.modulate.a = 0.0  # Hidden
	_ui_layer.add_child(_menu_container)

	# Title
	_title_label = Label.new()
	_title_label.text = "M  E  R  L  I  N"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		_title_label.add_theme_font_override("font", font)
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor"])
	_menu_container.add_child(_title_label)

	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	_menu_container.add_child(spacer)

	# Menu buttons
	var btn_labels: Array[String] = ["Nouvelle Partie", "Continuer", "Options"]
	for lbl in btn_labels:
		var btn: Button = Button.new()
		btn.text = lbl
		btn.custom_minimum_size = Vector2(300, 45)
		if font:
			btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor"])
		btn.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE["amber"])
		# Dark style
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.02, 0.04, 0.02, 0.7)
		style.border_color = MerlinVisual.CRT_PALETTE["border"]
		style.set_border_width_all(1)
		style.set_corner_radius_all(2)
		style.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", style)
		var hover_style: StyleBoxFlat = style.duplicate()
		hover_style.border_color = MerlinVisual.CRT_PALETTE["amber"]
		btn.add_theme_stylebox_override("hover", hover_style)
		_menu_container.add_child(btn)
		_buttons.append(btn)


func _start_boot_sequence() -> void:
	_boot_phase = true
	_boot_label.text = ""
	_boot_line_idx = 0
	_boot_line_timer = 0.0


func _update_boot(delta: float) -> void:
	_boot_timer += delta
	_boot_line_timer += delta

	# Add boot lines with staggered timing
	var line_delay: float = 0.4 + _rng.randf_range(0.0, 0.3)
	if _boot_line_idx < _boot_lines.size() and _boot_line_timer >= line_delay:
		_boot_line_timer = 0.0
		_boot_label.text += _boot_lines[_boot_line_idx] + "\n"
		_boot_line_idx += 1
		SFXManager.play("boot_line")

	# After all lines, fade to menu
	if _boot_line_idx >= _boot_lines.size() and _boot_timer > 5.0:
		_boot_phase = false
		_show_menu()


func _show_menu() -> void:
	if _menu_visible:
		return
	_menu_visible = true

	# Fade out boot text
	var tw: Tween = create_tween()
	tw.tween_property(_boot_label, "modulate:a", 0.0, 1.0)

	# Fade in menu container
	var tw2: Tween = create_tween()
	tw2.tween_interval(0.8)
	tw2.tween_property(_menu_container, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Stagger button appearance
	for i in _buttons.size():
		_buttons[i].modulate.a = 0.0
		_buttons[i].scale = Vector2(0.8, 0.8)
		_buttons[i].pivot_offset = _buttons[i].size * 0.5
		var btn_tw: Tween = _buttons[i].create_tween()
		btn_tw.set_parallel(true)
		btn_tw.tween_property(_buttons[i], "modulate:a", 1.0, 0.4).set_delay(1.5 + float(i) * 0.2)
		btn_tw.tween_property(_buttons[i], "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(1.5 + float(i) * 0.2)

	SFXManager.play("convergence")


func _trigger_glitch() -> void:
	if not _menu_visible:
		return
	# Brief screen distortion
	var glitch_rect: ColorRect = ColorRect.new()
	glitch_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	glitch_rect.color = Color(0.1, 0.3, 0.1, 0.08)
	glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(glitch_rect)

	# Offset some UI elements briefly
	if _title_label:
		_title_label.position.x += _rng.randf_range(-3.0, 3.0)

	# Clean up after 0.1s
	var tw: Tween = create_tween()
	tw.tween_interval(0.08)
	tw.tween_callback(func() -> void:
		glitch_rect.queue_free()
		if _title_label:
			_title_label.position.x = 0.0
	)
