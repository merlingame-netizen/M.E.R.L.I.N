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

# --- UI refs ---
var _ui_layer: CanvasLayer
var _boot_label: RichTextLabel
var _menu_container: VBoxContainer
var _title_label: Label
var _buttons: Array[Button] = []
var _lore_label: Label
var _lore_idx: int = 0
var _rune_labels: Array[Label3D] = []

# --- Lore Quotes ---
const LORE_QUOTES: Array[String] = [
	'"Les pierres se souviennent de tout." — Merlin',
	'"Chaque sentier mene a un choix. Chaque choix, a un destin."',
	'"La foret parle a ceux qui savent ecouter."',
	'"Ni la force ni la ruse ne suffisent. Seule la sagesse prevaut."',
	'"Les korrigans rient de ceux qui se croient seuls."',
	'"Le voile entre les mondes est plus fin qu\'un souffle."',
	'"Nul n\'entre en Broceliande sans y laisser une part de soi."',
	'"Les racines des chenes sont les veines du monde."',
]

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
	# Hide CRT autoload CanvasLayers (hint_screen_texture breaks 3D in GL Compat)
	# KEEP PixelTransition and SFXManager intact — they're needed for scene transitions
	var keep_names: Array[String] = ["PixelTransition", "SFXManager", "MusicManager", "MerlinAI", "GameManager", "MerlinVisual", "LocaleManager"]
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child != self and not (str(child.name) in keep_names):
			child.visible = false

	_build_3d_world()
	_build_ui()
	_start_boot_sequence()


func _process(delta: float) -> void:
	# Day/night disabled — fixed bright lighting for menu

	# Ocean animation handled by shader (TIME uniform) — no GDScript needed
	_ocean_time += delta

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

	# Ogham rune ring orbit
	for i in _rune_labels.size():
		var lbl: Label3D = _rune_labels[i]
		if not is_instance_valid(lbl):
			continue
		var angle: float = (float(i) / 18.0) * TAU + _ocean_time * 0.15
		lbl.position = _tower_pos + Vector3(cos(angle) * 3.2, 1.0 + sin(_ocean_time * 0.6 + float(i) * 0.4) * 0.25, sin(angle) * 3.2)
		# Fade by distance to camera
		var dist: float = lbl.position.distance_to(_camera.position) if is_instance_valid(_camera) else 5.0
		lbl.modulate.a = clampf(1.2 - dist / 10.0, 0.15, 0.8)

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
	_camera.position = Vector3(30.0, 2.0, -35.0)
	_camera.fov = 55.0
	_camera.current = true
	_camera.far = 200.0
	_world.add_child(_camera)
	# Look up at cliff + tower — dramatic low angle
	_camera.look_at(Vector3(-2.0, 12.0, -3.0), Vector3.UP)

	# Environment
	_env = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.62, 0.92)  # Saturated blue sky
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

	# --- TRELLIS TREES on plateau ---
	_build_trellis_trees()

	# --- MEGALITHS on plateau ---
	_build_megaliths()

	# --- OGHAM RUNE RING (game identity) ---
	_build_ogham_rune_ring()

	# --- DISTANT ISLANDS (depth) ---
	_build_distant_islands()


func _build_cliff() -> void:
	var cliff_scene: PackedScene = load("res://Assets/3d_models/menu_coast/cliff_unified.glb")
	var cliff_instance: Node3D = cliff_scene.instantiate()
	cliff_instance.name = "CliffTerrain"
	# Position so cliff edge faces ocean (negative Z side), flat top visible
	cliff_instance.position = Vector3(-5.0, 0.0, 0.0)
	cliff_instance.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	cliff_instance.scale = Vector3(1.0, 1.0, 1.0)
	_set_no_shadow_recursive(cliff_instance)
	_world.add_child(cliff_instance)

	# Keep fog wisps near cliff edge
	_add_fog_wisps()


func _add_fog_wisps() -> void:
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


func _set_no_shadow_recursive(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_set_no_shadow_recursive(child)


func _build_ocean() -> void:
	# --- SINGLE PlaneMesh + vertex displacement shader ---
	var ocean: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(120.0, 80.0)
	plane.subdivide_width = 60
	plane.subdivide_depth = 40
	ocean.mesh = plane

	var shader_mat: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = load("res://shaders/ocean_lowpoly.gdshader")
	shader_mat.shader = shader
	shader_mat.set_shader_parameter("deep_color", Color(0.03, 0.12, 0.28))
	shader_mat.set_shader_parameter("shallow_color", Color(0.12, 0.35, 0.50))
	shader_mat.set_shader_parameter("foam_color", Color(0.55, 0.70, 0.78))
	shader_mat.set_shader_parameter("wave_speed", 1.2)
	shader_mat.set_shader_parameter("wave_height", 0.8)
	shader_mat.set_shader_parameter("wave_frequency", 1.5)
	shader_mat.set_shader_parameter("foam_threshold", 0.6)
	ocean.material_override = shader_mat

	ocean.position = Vector3(-5.0, -5.0, -45.0)
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(ocean)
	_ocean_mesh = ocean

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

	# Sea rocks — single GLB with pre-positioned merged mesh
	var rocks_scene: PackedScene = load("res://Assets/3d_models/menu_coast/rocks_set.glb")
	if rocks_scene:
		var rocks_instance: Node3D = rocks_scene.instantiate()
		rocks_instance.name = "SeaRocks"
		rocks_instance.position = Vector3(0.0, 0.0, 0.0)  # Rocks are pre-positioned in the GLB
		rocks_instance.scale = Vector3(1.0, 1.0, 1.0)
		_set_no_shadow_recursive(rocks_instance)
		_world.add_child(rocks_instance)


func _build_cabin() -> void:
	var cabin_scene: PackedScene = load("res://Assets/3d_models/menu_coast/cabin_unified.glb")
	if cabin_scene == null:
		return
	var cabin_instance: Node3D = cabin_scene.instantiate()
	cabin_instance.name = "Cabin"
	cabin_instance.position = Vector3(-20.0, 9.5, 5.0)  # On cliff plateau, far left
	cabin_instance.scale = Vector3(1.5, 1.5, 1.5)
	_set_no_shadow_recursive(cabin_instance)
	_world.add_child(cabin_instance)

	# Smoke particles from chimney
	var smoke: GPUParticles3D = GPUParticles3D.new()
	smoke.amount = 8
	smoke.lifetime = 4.0
	smoke.position = Vector3(-18.5, 12.0, 5.0)
	var smoke_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	smoke_mat.direction = Vector3(0.2, 1.0, 0.0)
	smoke_mat.spread = 15.0
	smoke_mat.initial_velocity_min = 0.3
	smoke_mat.initial_velocity_max = 0.8
	smoke_mat.gravity = Vector3(0.0, 0.2, 0.0)
	smoke_mat.scale_min = 0.15
	smoke_mat.scale_max = 0.4
	smoke_mat.color = Color(0.6, 0.6, 0.6, 0.15)
	smoke.process_material = smoke_mat
	var smoke_mesh: SphereMesh = SphereMesh.new()
	smoke_mesh.radius = 0.1
	smoke_mesh.height = 0.2
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
	var tower_scene: PackedScene = load("res://Assets/3d_models/menu_coast/tower_unified.glb")
	var tower_instance: Node3D = tower_scene.instantiate()
	tower_instance.name = "CelticTower"
	tower_instance.position = Vector3(-5.0, 4.0, -5.0)
	tower_instance.scale = Vector3(2.0, 2.0, 2.0)
	_set_no_shadow_recursive(tower_instance)
	_world.add_child(tower_instance)
	_tower_pos = tower_instance.position

	# Keep orbiting stones (animated in _process)
	_build_orbiting_stones()


func _build_orbiting_stones() -> void:
	var stone_mat: StandardMaterial3D = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.40, 0.38, 0.32)
	stone_mat.roughness = 0.95
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
		for layer_idx in 3:
			var cloud: MeshInstance3D = MeshInstance3D.new()
			var alpha: float = _rng.randf_range(0.3, 0.6) - float(layer_idx) * 0.08
			var cmat: StandardMaterial3D = StandardMaterial3D.new()
			cmat.albedo_color = Color(0.95, 0.97, 1.0, alpha)
			cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			cmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
			var qm: QuadMesh = QuadMesh.new()
			var scale_f: float = 1.0 - float(layer_idx) * 0.15
			qm.size = Vector2(base_w * scale_f, base_h * scale_f)
			qm.material = cmat
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
	var crystal_scene: PackedScene = load("res://Assets/3d_models/menu_coast/crystal_cluster_unified.glb")
	if crystal_scene == null:
		return
	var crystal_instance: Node3D = crystal_scene.instantiate()
	crystal_instance.name = "CrystalCluster"
	crystal_instance.position = Vector3(5.0, 10.0, -8.0)  # Near tower base, cliff edge
	crystal_instance.scale = Vector3(1.2, 1.2, 1.2)
	_set_no_shadow_recursive(crystal_instance)
	_world.add_child(crystal_instance)


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

func _build_trellis_trees() -> void:
	# Place existing Trellis tree GLBs on the cliff plateau
	var tree_paths: Array[String] = [
		"res://Assets/3d_models/vegetation/01_Tree_Small.glb",
		"res://Assets/3d_models/vegetation/02_Tree_Medium.glb",
		"res://Assets/3d_models/vegetation/04_Pine.glb",
		"res://Assets/3d_models/vegetation/07_Bush.glb",
	]
	# Scatter 12 trees on plateau (y > -8 in Blender = z > -8 in Godot after rotation)
	var positions: Array[Vector3] = [
		Vector3(-18.0, 10.0, 2.0), Vector3(-14.0, 10.0, -3.0),
		Vector3(-10.0, 10.0, 6.0), Vector3(-6.0, 10.0, -1.0),
		Vector3(-2.0, 10.0, 4.0), Vector3(2.0, 10.0, -2.0),
		Vector3(6.0, 10.0, 3.0), Vector3(-16.0, 10.0, -5.0),
		Vector3(-12.0, 10.0, 7.0), Vector3(-8.0, 10.0, 0.0),
		Vector3(0.0, 10.0, 5.0), Vector3(4.0, 10.0, -4.0),
	]
	for i in positions.size():
		var path: String = tree_paths[i % tree_paths.size()]
		var scene: PackedScene = load(path)
		if scene == null:
			continue
		var inst: Node3D = scene.instantiate()
		inst.name = "Tree_%d" % i
		inst.position = positions[i]
		inst.scale = Vector3(3.0, 3.0, 3.0)
		inst.rotation.y = randf() * TAU
		_set_no_shadow_recursive(inst)
		_world.add_child(inst)


func _build_megaliths() -> void:
	# Place existing megalith GLBs on cliff
	var menhir_scene: PackedScene = load("res://Assets/3d_models/broceliande/megaliths/menhir_01.glb")
	if menhir_scene == null:
		return
	var positions: Array[Vector3] = [
		Vector3(-8.0, 10.0, -6.0), Vector3(2.0, 10.0, 8.0),
		Vector3(-14.0, 10.0, 3.0), Vector3(6.0, 10.0, -2.0),
		Vector3(-3.0, 10.0, -10.0),
	]
	for i in positions.size():
		var inst: Node3D = menhir_scene.instantiate()
		inst.name = "Menhir_%d" % i
		inst.position = positions[i]
		inst.scale = Vector3(3.0, 3.0, 3.0)
		inst.rotation.y = randf() * TAU
		_set_no_shadow_recursive(inst)
		_world.add_child(inst)


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


func _build_ogham_rune_ring() -> void:
	## 18 Ogham runes orbiting in phosphor green — game identity
	const RUNES: Array[String] = [
		"\u1681","\u1682","\u1683","\u1684","\u1685","\u1686",
		"\u1687","\u1688","\u1689","\u168A","\u168B","\u168C",
		"\u168D","\u168E","\u168F","\u1690","\u1691","\u1692",
	]
	for i in RUNES.size():
		var lbl3d: Label3D = Label3D.new()
		lbl3d.text = RUNES[i]
		lbl3d.font_size = 64
		lbl3d.modulate = Color(0.2, 1.0, 0.4, 0.6)
		lbl3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl3d.no_depth_test = true
		lbl3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lbl3d.name = "Rune_%d" % i
		_world.add_child(lbl3d)
		_rune_labels.append(lbl3d)


# ═══════════════════════════════════════════════════════════════════════════════
# UI — Boot sequence + progressive menu appearance
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	# ── CRT MONITOR BEZEL (Control + ColorRects — avoids theme override) ──
	var bezel: Control = Control.new()
	bezel.anchor_left = 0.08; bezel.anchor_right = 0.92
	bezel.anchor_top = 0.08; bezel.anchor_bottom = 0.92
	bezel.offset_left = 0; bezel.offset_right = 0
	bezel.offset_top = 0; bezel.offset_bottom = 0
	_ui_layer.add_child(bezel)

	# Bezel border (dark frame)
	var bezel_border: ColorRect = ColorRect.new()
	bezel_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	bezel_border.color = Color(0.06, 0.07, 0.06, 1.0)
	bezel_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bezel.add_child(bezel_border)

	# Screen surface (inset from border by 10px — the actual CRT screen)
	var screen_bg: ColorRect = ColorRect.new()
	screen_bg.anchor_left = 0.0; screen_bg.anchor_right = 1.0
	screen_bg.anchor_top = 0.0; screen_bg.anchor_bottom = 1.0
	screen_bg.offset_left = 10; screen_bg.offset_right = -10
	screen_bg.offset_top = 10; screen_bg.offset_bottom = -10
	screen_bg.color = Color(0.01, 0.03, 0.01, 0.0)  # Fully transparent — 3D cliff/tower visible through CRT glass
	screen_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bezel.add_child(screen_bg)

	# LED indicator (amber dot bottom-right of bezel)
	var led: ColorRect = ColorRect.new()
	led.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	led.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	led.grow_vertical = Control.GROW_DIRECTION_BEGIN
	led.offset_left = -12; led.offset_right = -4
	led.offset_top = -12; led.offset_bottom = -4
	led.color = MerlinVisual.CRT_PALETTE["amber"]
	led.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bezel.add_child(led)

	# ── Boot text INSIDE the bezel ────────────────────────────────────────
	_boot_label = RichTextLabel.new()
	_boot_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot_label.bbcode_enabled = true
	_boot_label.scroll_active = false
	_boot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = MerlinVisual.get_font("terminal")
	if font:
		_boot_label.add_theme_font_override("normal_font", font)
	_boot_label.add_theme_font_size_override("normal_font_size", 18)
	_boot_label.add_theme_color_override("default_color", MerlinVisual.CRT_PALETTE["phosphor"])
	bezel.add_child(_boot_label)

	# ── Menu container INSIDE the bezel (responsive) ──────────────────────
	_menu_container = VBoxContainer.new()
	_menu_container.set_anchors_preset(Control.PRESET_CENTER)
	_menu_container.anchor_left = 0.2; _menu_container.anchor_right = 0.8
	_menu_container.anchor_top = 0.3; _menu_container.anchor_bottom = 0.85
	_menu_container.offset_left = 0; _menu_container.offset_right = 0
	_menu_container.offset_top = 0; _menu_container.offset_bottom = 0
	_menu_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_container.add_theme_constant_override("separation", 16)
	_menu_container.modulate.a = 0.0  # Hidden
	bezel.add_child(_menu_container)

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
		btn.custom_minimum_size = Vector2(0, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		# Connect button actions
		btn.pressed.connect(_on_menu_button.bind(lbl))
		btn.mouse_entered.connect(func():
			if is_instance_valid(SFXManager):
				SFXManager.play("hover")
		)
		_menu_container.add_child(btn)
		_buttons.append(btn)

	# ── Lore Quote (Celtic atmosphere) ────────────────────────────────────
	var lore_spacer: Control = Control.new()
	lore_spacer.custom_minimum_size = Vector2(0, 24)
	_menu_container.add_child(lore_spacer)

	_lore_label = Label.new()
	_lore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if font:
		_lore_label.add_theme_font_override("font", font)
	_lore_label.add_theme_font_size_override("font_size", 15)
	_lore_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])
	_lore_idx = randi() % LORE_QUOTES.size()
	_lore_label.text = LORE_QUOTES[_lore_idx]
	_menu_container.add_child(_lore_label)

	# Rotate quotes every 7s
	var lore_timer := Timer.new()
	lore_timer.wait_time = 7.0
	lore_timer.autostart = true
	lore_timer.timeout.connect(_rotate_lore_quote)
	add_child(lore_timer)

	# ── Version label ─────────────────────────────────────────────────────
	var version_label: Label = Label.new()
	version_label.text = "v0.9 — Broceliande"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		version_label.add_theme_font_override("font", font)
	version_label.add_theme_font_size_override("font_size", 11)
	version_label.add_theme_color_override("font_color", Color(0.1, 0.2, 0.1, 0.4))
	_menu_container.add_child(version_label)


func _rotate_lore_quote() -> void:
	if not is_instance_valid(_lore_label):
		return
	var tw := create_tween()
	tw.tween_property(_lore_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		_lore_idx = (_lore_idx + 1) % LORE_QUOTES.size()
		_lore_label.text = LORE_QUOTES[_lore_idx]
	)
	tw.tween_property(_lore_label, "modulate:a", 1.0, 0.4)


func _on_menu_button(label: String) -> void:
	if is_instance_valid(SFXManager):
		SFXManager.play("click")
	match label:
		"Nouvelle Partie":
			_start_llm_warmup()
			_camera_to_tower()
		"Continuer":
			PixelTransition.transition_to("res://scenes/MerlinCabinHub.tscn")
		"Options":
			pass


func _camera_to_tower() -> void:
	# Hide menu UI
	_menu_container.modulate.a = 0.0
	_boot_label.modulate.a = 0.0

	# Tween camera toward tower (2s cinematic zoom)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_camera, "position", _tower_pos + Vector3(2.0, 2.0, 4.0), 2.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_camera, "fov", 35.0, 2.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# After zoom: transition to cabin
	var tw2: Tween = create_tween()
	tw2.tween_interval(2.5)
	tw2.tween_callback(func():
		PixelTransition.transition_to("res://scenes/MerlinCabinHub.tscn")
	)


func _start_llm_warmup() -> void:
	if MerlinAI and MerlinAI.has_method("_init_local_models"):
		MerlinAI._init_local_models()


func _start_boot_sequence() -> void:
	_boot_phase = true
	_boot_label.text = ""
	_boot_line_idx = 0
	_boot_line_timer = 0.0


func _update_boot(delta: float) -> void:
	_boot_timer += delta
	_boot_line_timer += delta

	# Add boot lines with staggered timing
	var line_delay: float = 0.25 + _rng.randf_range(0.0, 0.15)
	if _boot_line_idx < _boot_lines.size() and _boot_line_timer >= line_delay:
		_boot_line_timer = 0.0
		_boot_label.text += _boot_lines[_boot_line_idx] + "\n"
		_boot_line_idx += 1
		SFXManager.play("boot_line")

	# After all lines, fade to menu (reduced from 5s to 3s — GLB loading already provides wait)
	if _boot_line_idx >= _boot_lines.size() and _boot_timer > 3.0:
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

	# Simple button appearance — no stagger (was causing invisible buttons)
	for i in _buttons.size():
		_buttons[i].modulate.a = 1.0
		_buttons[i].scale = Vector2.ONE

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
