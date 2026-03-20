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

	# Ocean wave animation
	_ocean_time += delta
	if _ocean_mesh:
		_ocean_mesh.position.y = sin(_ocean_time * 0.8) * 0.15 - 3.5

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
	_camera.position = Vector3(0.0, 5.0, 8.0)
	_camera.rotation_degrees = Vector3(-12.0, -5.0, 0.0)
	_camera.fov = 60.0
	_camera.current = true
	_camera.far = 200.0
	_world.add_child(_camera)

	# Environment
	_env = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.50, 0.55)  # Gris breton
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.55, 0.60)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.58, 0.62)
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

	# --- CLIFF (low-poly grey rock) ---
	_build_cliff()

	# --- OCEAN ---
	_build_ocean()

	# --- CABIN ---
	_build_cabin()

	# --- GRASS on cliff top ---
	_build_cliff_grass()


func _build_cliff() -> void:
	# Main cliff body — large grey box
	var cliff: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(40.0, 12.0, 30.0)
	cliff.mesh = bm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.38, 0.40)
	mat.roughness = 0.95
	cliff.material_override = mat
	cliff.position = Vector3(0.0, -2.0, -5.0)
	cliff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(cliff)

	# Cliff face detail — jagged rocks
	for i in 8:
		var rock: MeshInstance3D = MeshInstance3D.new()
		var rbm: BoxMesh = BoxMesh.new()
		var w: float = _rng.randf_range(2.0, 5.0)
		var h: float = _rng.randf_range(3.0, 8.0)
		rbm.size = Vector3(w, h, _rng.randf_range(2.0, 4.0))
		rock.mesh = rbm
		var rmat: StandardMaterial3D = StandardMaterial3D.new()
		rmat.albedo_color = Color(0.30 + _rng.randf() * 0.1, 0.32 + _rng.randf() * 0.08, 0.35 + _rng.randf() * 0.08)
		rmat.roughness = 1.0
		rock.material_override = rmat
		rock.position = Vector3(_rng.randf_range(-15.0, 15.0), -4.0 - _rng.randf() * 3.0, -18.0 + _rng.randf_range(-3.0, 3.0))
		rock.rotation.y = _rng.randf_range(-0.3, 0.3)
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(rock)


func _build_ocean() -> void:
	_ocean_mesh = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(200.0, 200.0)
	_ocean_mesh.mesh = pm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.25, 0.35)
	mat.roughness = 0.3
	mat.metallic = 0.2
	_ocean_mesh.material_override = mat
	_ocean_mesh.position = Vector3(0.0, -3.5, -40.0)
	_ocean_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_ocean_mesh)

	# Foam line at cliff base
	var foam: MeshInstance3D = MeshInstance3D.new()
	var fbm: BoxMesh = BoxMesh.new()
	fbm.size = Vector3(35.0, 0.3, 2.0)
	foam.mesh = fbm
	var fmat: StandardMaterial3D = StandardMaterial3D.new()
	fmat.albedo_color = Color(0.70, 0.75, 0.80, 0.6)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam.material_override = fmat
	foam.position = Vector3(0.0, -3.0, -19.0)
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
	# Sparse grass on cliff top
	var grass_mat: StandardMaterial3D = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.25, 0.35, 0.20)
	grass_mat.roughness = 1.0
	grass_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(0.3, 0.5)
	qm.material = grass_mat
	mm.mesh = qm
	mm.instance_count = 200

	for i in 200:
		var t: Transform3D = Transform3D.IDENTITY
		var scale_f: float = _rng.randf_range(0.6, 1.3)
		t = t.scaled(Vector3(scale_f, scale_f, scale_f))
		t = t.rotated(Vector3.UP, _rng.randf_range(0.0, TAU))
		t.origin = Vector3(
			_rng.randf_range(-18.0, 18.0),
			4.1,
			_rng.randf_range(-15.0, 5.0)
		)
		mm.set_instance_transform(i, t)

	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(mmi)


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
