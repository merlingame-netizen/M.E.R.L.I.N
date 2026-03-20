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
	# Day/night cycle (realtime)
	if _day_night:
		_day_night.update(delta)

	# Ocean wave strips animation — each strip bobs at different phase
	_ocean_time += delta
	for i in _wave_strips.size():
		if not is_instance_valid(_wave_strips[i]):
			continue
		var phase: float = float(i) * 0.6
		var wave_y: float = sin(_ocean_time * 1.2 + phase) * 0.4 + sin(_ocean_time * 0.7 + phase * 1.5) * 0.2
		_wave_strips[i].position.y = -6.0 + wave_y
		_wave_strips[i].rotation.x = sin(_ocean_time * 0.9 + phase) * 0.05

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

	# Camera — fixed view looking at cliff edge + ocean
	_camera = Camera3D.new()
	_camera.position = Vector3(5.0, 6.0, 10.0)
	_camera.rotation_degrees = Vector3(-10.0, -10.0, 0.0)
	_camera.fov = 65.0
	_camera.current = true
	_camera.far = 200.0
	_world.add_child(_camera)

	# Environment
	_env = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.72, 0.88)  # Blue sky like reference
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.60, 0.65, 0.55)
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.65, 0.75, 0.85)
	env.fog_density = 0.008
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.3
	_env.environment = env
	_world.add_child(_env)

	# Sun — realtime position
	_sun = DirectionalLight3D.new()
	_sun.light_color = Color(0.90, 0.85, 0.75)
	_sun.light_energy = 1.5
	_sun.shadow_enabled = false
	_world.add_child(_sun)

	# Day/night cycle — REALTIME mode (system clock)
	_day_night = BrocDayNight.new(_sun, _env)
	_day_night.set_realtime(true)

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

	# Cliff FACE — vertical brown rock wall (dramatic drop to ocean)
	var face: MeshInstance3D = MeshInstance3D.new()
	var face_bm: BoxMesh = BoxMesh.new()
	face_bm.size = Vector3(50.0, 10.0, 3.0)
	face.mesh = face_bm
	var face_mat: StandardMaterial3D = StandardMaterial3D.new()
	face_mat.albedo_color = Color(0.35, 0.30, 0.22)
	face_mat.roughness = 1.0
	face.material_override = face_mat
	face.position = Vector3(-5.0, -3.0, -13.5)
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(face)

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
	# Geometric wave strips — 20 rows of tilted boxes for faceted ocean look
	var deep_color: Color = Color(0.06, 0.22, 0.40)
	var mid_color: Color = Color(0.10, 0.32, 0.50)
	var bright_color: Color = Color(0.15, 0.42, 0.55)

	for i in 20:
		var strip: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(60.0, 0.4, 4.0)
		strip.mesh = bm
		var smat: StandardMaterial3D = StandardMaterial3D.new()
		var depth_t: float = float(i) / 20.0
		smat.albedo_color = deep_color.lerp(bright_color, 1.0 - depth_t)
		smat.roughness = 0.15 + depth_t * 0.2
		smat.metallic = 0.3 - depth_t * 0.2
		strip.material_override = smat
		strip.position = Vector3(-5.0, -6.0, -16.0 - float(i) * 4.0)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(strip)
		_wave_strips.append(strip)

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
	fmat.albedo_color = Color(0.80, 0.85, 0.90, 0.5)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam.material_override = fmat
	foam.position = Vector3(-5.0, -5.5, -15.0)
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(foam)


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
	smat.color = Color(0.6, 0.6, 0.6, 0.15)
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

	# Bushes (dark green spheres, 30 instances)
	var bush_mat: StandardMaterial3D = StandardMaterial3D.new()
	bush_mat.albedo_color = Color(0.15, 0.30, 0.10)
	bush_mat.roughness = 1.0

	var bush_mm: MultiMesh = MultiMesh.new()
	bush_mm.transform_format = MultiMesh.TRANSFORM_3D
	var bush_mesh: SphereMesh = SphereMesh.new()
	bush_mesh.radius = 1.0
	bush_mesh.height = 1.2
	bush_mesh.radial_segments = 6
	bush_mesh.rings = 3
	bush_mesh.material = bush_mat
	bush_mm.mesh = bush_mesh
	bush_mm.instance_count = 30

	for i in 30:
		var bt: Transform3D = Transform3D.IDENTITY
		var bs: float = _rng.randf_range(0.4, 1.2)
		bt = bt.scaled(Vector3(bs, bs * 0.7, bs))
		bt.origin = Vector3(
			_rng.randf_range(-16.0, 16.0),
			4.3,
			_rng.randf_range(-16.0, 3.0)
		)
		bush_mm.set_instance_transform(i, bt)

	var bush_mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	bush_mmi.multimesh = bush_mm
	bush_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(bush_mmi)

	# Standing stones / menhirs (tall thin boxes, 8 instances)
	var stone_mat: StandardMaterial3D = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.38, 0.40, 0.36)
	stone_mat.roughness = 1.0

	for i in 8:
		var menhir: MeshInstance3D = MeshInstance3D.new()
		var mbm: BoxMesh = BoxMesh.new()
		var mh: float = _rng.randf_range(1.5, 4.0)
		mbm.size = Vector3(0.5, mh, 0.4)
		menhir.mesh = mbm
		menhir.material_override = stone_mat
		menhir.position = Vector3(
			_rng.randf_range(-15.0, -5.0),
			4.0 + mh * 0.5,
			_rng.randf_range(-12.0, 0.0)
		)
		menhir.rotation = Vector3(_rng.randf_range(-0.1, 0.1), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.05, 0.05))
		menhir.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(menhir)


# ═══════════════════════════════════════════════════════════════════════════════
# CELTIC TOWER — Ruined tower with floating stones
# ═══════════════════════════════════════════════════════════════════════════════

func _build_tower() -> void:
	var tower_pos: Vector3 = Vector3(2.0, 4.0, -12.0)
	var stone_mat: StandardMaterial3D = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.40, 0.38, 0.32)
	stone_mat.roughness = 0.95

	# Tower base — cylinder approximated with stacked blocks (taller)
	for i in 7:
		var block: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		var height_f: float = float(i)
		bm.size = Vector3(3.0 - height_f * 0.2, 3.0, 3.0 - height_f * 0.2)
		block.mesh = bm
		block.material_override = stone_mat
		block.position = tower_pos + Vector3(0.0, height_f * 2.8, 0.0)
		block.rotation.y = height_f * 0.15
		block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(block)

	# Tower top — pointed roof
	var roof: MeshInstance3D = MeshInstance3D.new()
	var roof_bm: BoxMesh = BoxMesh.new()
	roof_bm.size = Vector3(2.0, 3.0, 2.0)
	roof.mesh = roof_bm
	var roof_mat: StandardMaterial3D = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.30, 0.35, 0.25)
	roof_mat.roughness = 1.0
	roof.material_override = roof_mat
	roof.position = tower_pos + Vector3(0.0, 20.0, 0.0)
	roof.rotation = Vector3(0.0, 0.3, 0.1)
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(roof)

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
	sm.radius = 8.0
	sm.height = 16.0
	sm.radial_segments = 12
	sm.rings = 6
	sun_sphere.mesh = sm
	var smat: StandardMaterial3D = StandardMaterial3D.new()
	smat.albedo_color = Color(1.0, 0.95, 0.70, 0.4)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.cull_mode = BaseMaterial3D.CULL_FRONT  # Visible from inside
	sun_sphere.material_override = smat
	sun_sphere.position = Vector3(15.0, 18.0, -50.0)
	sun_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(sun_sphere)

	# Sun core (solid bright)
	var core: MeshInstance3D = MeshInstance3D.new()
	var cm: SphereMesh = SphereMesh.new()
	cm.radius = 3.0
	cm.height = 6.0
	cm.radial_segments = 8
	cm.rings = 4
	core.mesh = cm
	var cmat: StandardMaterial3D = StandardMaterial3D.new()
	cmat.albedo_color = Color(1.0, 0.98, 0.85)
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.material_override = cmat
	core.position = Vector3(15.0, 18.0, -50.0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(core)

	# Sun omni light
	var sun_omni: OmniLight3D = OmniLight3D.new()
	sun_omni.light_color = Color(1.0, 0.95, 0.80)
	sun_omni.light_energy = 2.0
	sun_omni.omni_range = 80.0
	sun_omni.position = Vector3(15.0, 18.0, -50.0)
	sun_omni.shadow_enabled = false
	_world.add_child(sun_omni)


# ═══════════════════════════════════════════════════════════════════════════════
# CLOUDS — Billboard quads
# ═══════════════════════════════════════════════════════════════════════════════

func _build_clouds() -> void:
	var cloud_mat: StandardMaterial3D = StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(0.92, 0.94, 0.96, 0.5)
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	cloud_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for i in 8:
		var cloud: MeshInstance3D = MeshInstance3D.new()
		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2(_rng.randf_range(8.0, 20.0), _rng.randf_range(3.0, 6.0))
		qm.material = cloud_mat
		cloud.mesh = qm
		cloud.position = Vector3(
			_rng.randf_range(-40.0, 40.0),
			_rng.randf_range(20.0, 30.0),
			_rng.randf_range(-60.0, -30.0)
		)
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(cloud)


# ═══════════════════════════════════════════════════════════════════════════════
# CRYSTALS — Emissive prisms on cliff edge
# ═══════════════════════════════════════════════════════════════════════════════

func _build_crystals() -> void:
	var crystal_mat: StandardMaterial3D = StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(0.5, 0.2, 0.7)
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color(0.6, 0.2, 0.8)
	crystal_mat.emission_energy_multiplier = 2.0
	crystal_mat.roughness = 0.2
	crystal_mat.metallic = 0.5

	for i in 6:
		var crystal: MeshInstance3D = MeshInstance3D.new()
		var cbm: BoxMesh = BoxMesh.new()
		var h: float = _rng.randf_range(1.0, 3.0)
		cbm.size = Vector3(0.3, h, 0.3)
		crystal.mesh = cbm
		crystal.material_override = crystal_mat
		crystal.position = Vector3(
			_rng.randf_range(-3.0, 8.0),
			4.0 + h * 0.5,
			_rng.randf_range(-14.0, -8.0)
		)
		crystal.rotation = Vector3(
			_rng.randf_range(-0.3, 0.3),
			_rng.randf_range(0.0, TAU),
			_rng.randf_range(-0.2, 0.2)
		)
		crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(crystal)


# ═══════════════════════════════════════════════════════════════════════════════
# MAGIC PARTICLES — Floating around tower
# ═══════════════════════════════════════════════════════════════════════════════

func _build_magic_particles() -> void:
	var tower_pos: Vector3 = Vector3(2.0, 10.0, -12.0)

	# Dark magic orbs
	var orbs: GPUParticles3D = GPUParticles3D.new()
	orbs.amount = 25
	orbs.lifetime = 5.0
	orbs.position = tower_pos

	var omat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	omat.direction = Vector3(0.0, 0.5, 0.0)
	omat.spread = 180.0
	omat.initial_velocity_min = 0.3
	omat.initial_velocity_max = 1.0
	omat.gravity = Vector3(0.0, 0.1, 0.0)
	omat.scale_min = 0.15
	omat.scale_max = 0.4
	omat.color = Color(0.5, 0.1, 0.7, 0.7)
	omat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	omat.emission_sphere_radius = 5.0
	omat.angular_velocity_min = -90.0
	omat.angular_velocity_max = 90.0
	orbs.process_material = omat

	var orb_mesh: SphereMesh = SphereMesh.new()
	orb_mesh.radius = 0.2
	orb_mesh.height = 0.4
	orb_mesh.radial_segments = 6
	orb_mesh.rings = 3
	orbs.draw_pass_1 = orb_mesh
	orbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(orbs)

	# Stone debris particles
	var debris: GPUParticles3D = GPUParticles3D.new()
	debris.amount = 15
	debris.lifetime = 8.0
	debris.position = tower_pos + Vector3(0.0, 2.0, 0.0)

	var dmat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	dmat.direction = Vector3(0.0, 0.3, 0.0)
	dmat.spread = 120.0
	dmat.initial_velocity_min = 0.1
	dmat.initial_velocity_max = 0.4
	dmat.gravity = Vector3(0.0, -0.05, 0.0)
	dmat.scale_min = 0.05
	dmat.scale_max = 0.15
	dmat.color = Color(0.4, 0.38, 0.32, 0.8)
	dmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	dmat.emission_sphere_radius = 4.0
	dmat.angular_velocity_min = -45.0
	dmat.angular_velocity_max = 45.0
	debris.process_material = dmat

	var debris_mesh: BoxMesh = BoxMesh.new()
	debris_mesh.size = Vector3(0.15, 0.15, 0.15)
	debris.draw_pass_1 = debris_mesh
	debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(debris)


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
	_menu_container.set_anchors_preset(Control.PRESET_CENTER)
	_menu_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu_container.offset_left = -200.0
	_menu_container.offset_right = 200.0
	_menu_container.offset_top = -180.0
	_menu_container.offset_bottom = 180.0
	_menu_container.alignment = BoxContainer.ALIGNMENT_CENTER
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
