## Menu3DPC — Main menu (N64 retro x modern design)
## 4 visual layers: vertex jitter, fairy trails, rune grid, boot sequence.
## Responsive: anchor-based, touch-friendly 52dp+, mobile/console/desktop.

extends Control

# ═══════════════════════════════════════════════════════════════
# PALETTE
# ═══════════════════════════════════════════════════════════════
const GOLD := Color(0.90, 0.75, 0.30)
const GOLD_DIM := Color(0.55, 0.45, 0.18)
const GOLD_BRIGHT := Color(1.00, 0.88, 0.42)
const GOLD_FAINT := Color(0.55, 0.45, 0.18, 0.35)
const GOLD_SUBTLE := Color(0.40, 0.32, 0.14, 0.18)
const GOLD_GLOW := Color(1.00, 0.85, 0.30, 0.06)
const NEON_CYAN := Color(0.20, 0.85, 0.95, 0.55)
const NEON_MAGENTA := Color(0.95, 0.20, 0.50, 0.45)
const PHOSPHOR_GREEN := Color(0.20, 1.00, 0.40)
const BG_BLACK := Color(0.015, 0.015, 0.02)
const BG_BTN := Color(0.06, 0.05, 0.02, 0.30)
const BG_BTN_HOVER := Color(0.14, 0.11, 0.04, 0.55)
const BORDER_BTN := Color(0.45, 0.35, 0.14, 0.25)

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

const GLITCH_CHARS := "!@#$%^&*<>{}[]|/\\~`01"
const TITLE_TEXT := "M . E . R . L . I . N"

# Unicode Ogham characters for rune grid background
const OGHAM_CHARS: Array[String] = [
	"\u1681", "\u1682", "\u1683", "\u1684", "\u1685",
	"\u1686", "\u1687", "\u1688", "\u1689", "\u168A",
	"\u168B", "\u168C", "\u168D", "\u168E", "\u168F",
	"\u1690", "\u1691", "\u1692", "\u1693", "\u1694",
	"\u25C6", "\u25CB", "\u2022", "\u2666",  # decorative
]

# ═══════════════════════════════════════════════════════════════
# RESPONSIVE
# ═══════════════════════════════════════════════════════════════
var _scale: float = 1.0
var _is_portrait: bool = false

# ═══════════════════════════════════════════════════════════════
# 3D VIEWPORT (background scene)
# ═══════════════════════════════════════════════════════════════
var _3d_container: SubViewportContainer
var _3d_viewport: SubViewport
var _3d_camera: Camera3D
var _3d_env: WorldEnvironment
var _3d_scene_root: Node3D
var _3d_sun: DirectionalLight3D
var _3d_fill: OmniLight3D
var _time_of_day: String = ""
var _camera_idle_phase: float = 0.0
var _camera_fly_active: bool = false
var _camera_fly_t: float = 0.0

# Camera positions
const CAM_IDLE_POS := Vector3(8.0, 4.5, 12.0)
const CAM_IDLE_LOOK := Vector3(0.0, 2.0, 0.0)
const CAM_TOWER_POS := Vector3(1.0, 3.0, 3.0)
const CAM_TOWER_LOOK := Vector3(0.0, 4.0, -1.0)

# ═══════════════════════════════════════════════════════════════
# UI NODES
# ═══════════════════════════════════════════════════════════════
var _background: ColorRect
var _rune_grid_layer: Control
var _particle_layer: Control
var _frame_corners: Control
var _crt_overlay: ColorRect
var _root_container: MarginContainer
var _center_vbox: VBoxContainer
var _title_label: Label
var _title_shadow_r: Label
var _title_shadow_b: Label
var _greeting_label: Label
var _btn_container: VBoxContainer
var _buttons: Array[Button] = []
var _lore_label: Label
var _clock_label: Label
var _version_label: Label
var _separator_top: Control
var _separator_bottom: Control
var _scan_bar: ColorRect
var _boot_overlay: ColorRect  # CRT static during boot

# ═══════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════
var _lore_idx: int = 0
var _glitch_timer: float = 0.0
var _glitch_cooldown: float = 4.0
var _micro_glitch_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _menu_visible: bool = false
var _title_glow_phase: float = 0.0
var _frame_alpha_phase: float = 0.0
var _transitioning: bool = false
var _booting: bool = false

# Phase 1 — Vertex jitter
var _jitter_frame: int = 0

# Phase 2 — Particles + orbs
var _particles: Array[Dictionary] = []
var _orbs: Array[Dictionary] = []
var _trail_update_counter: int = 0

# Phase 3 — Rune grid
var _rune_labels: Array[Label] = []
var _rune_grid_scroll_y: float = 0.0
var _rune_row_timer: float = 0.0
var _rune_row_cooldown: float = 6.0
var _scan_bar_active: bool = false
var _scan_bar_timer: float = 0.0
var _scan_bar_cooldown: float = 8.0

# Phase 4 — Boot sequence
var _boot_skip_pressed: bool = false


# ═══════════════════════════════════════════════════════════════
# READY
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	_rng.randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_hide_autoload("ScreenFrame")
	_hide_autoload("SceneSelector")

	_compute_scale()
	_build_ui()
	_init_particles(40)
	_init_orbs(4)
	_init_rune_grid()

	get_viewport().size_changed.connect(_on_viewport_resized)

	# Boot sequence: play once per session
	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_meta("menu_boot_done"):
		_show_menu()
	else:
		_play_boot_sequence()


func _exit_tree() -> void:
	_show_autoload("ScreenFrame")
	_show_autoload("SceneSelector")


func _compute_scale() -> void:
	var vp := get_viewport().get_visible_rect().size
	_scale = clampf(minf(vp.x / 1280.0, vp.y / 720.0), 0.5, 2.5)
	_is_portrait = vp.y > vp.x


func _on_viewport_resized() -> void:
	_compute_scale()
	if _3d_viewport:
		_3d_viewport.size = get_viewport().get_visible_rect().size


func _hide_autoload(autoload_name: String) -> void:
	var node := get_node_or_null("/root/" + autoload_name)
	if node and (node is CanvasLayer or node is Control):
		node.visible = false


func _show_autoload(autoload_name: String) -> void:
	var node := get_node_or_null("/root/" + autoload_name)
	if node and (node is CanvasLayer or node is Control):
		node.visible = true


func _input(event: InputEvent) -> void:
	# Boot skip on any press
	if _booting and not _boot_skip_pressed:
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
			if event.is_pressed():
				_boot_skip_pressed = true


# ═══════════════════════════════════════════════════════════════
# PROCESS
# ═══════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	_update_clock()
	_animate_title_glow(delta)
	_animate_particles(delta)
	_animate_orbs(delta)
	_animate_frame(delta)
	_animate_rune_grid(delta)
	_animate_scan_bar(delta)
	_apply_vertex_jitter()
	_animate_3d_camera(delta)

	if not _menu_visible:
		return

	_glitch_timer += delta
	if _glitch_timer >= _glitch_cooldown:
		_glitch_timer = 0.0
		_glitch_cooldown = _rng.randf_range(3.0, 8.0)
		_trigger_glitch()

	_micro_glitch_timer += delta
	if _micro_glitch_timer >= 1.5:
		_micro_glitch_timer = 0.0
		if _rng.randf() < 0.4:
			_trigger_micro_glitch()


# ═══════════════════════════════════════════════════════════════
# BUILD UI
# ═══════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════
# 3D BACKGROUND SCENE
# ═══════════════════════════════════════════════════════════════

func _build_3d_viewport() -> void:
	_3d_container = SubViewportContainer.new()
	_3d_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_3d_container.stretch = true
	_3d_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_3d_container)

	_3d_viewport = SubViewport.new()
	_3d_viewport.size = Vector2i(
		int(get_viewport().get_visible_rect().size.x),
		int(get_viewport().get_visible_rect().size.y)
	)
	_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_3d_viewport.msaa_3d = Viewport.MSAA_2X
	_3d_viewport.transparent_bg = false
	_3d_container.add_child(_3d_viewport)

	# World environment — dusk coastal atmosphere
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.12, 0.20)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAP_ACES
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.10, 0.18)
	env.fog_density = 0.015
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.1
	_3d_env = WorldEnvironment.new()
	_3d_env.environment = env
	_3d_viewport.add_child(_3d_env)

	# Camera
	_3d_camera = Camera3D.new()
	_3d_camera.position = CAM_IDLE_POS
	_3d_camera.look_at(CAM_IDLE_LOOK)
	_3d_camera.fov = 55.0
	_3d_camera.far = 200.0
	_3d_viewport.add_child(_3d_camera)

	# Dynamic lighting — driven by system clock
	_3d_sun = DirectionalLight3D.new()
	_3d_sun.shadow_enabled = true
	_3d_viewport.add_child(_3d_sun)

	_3d_fill = OmniLight3D.new()
	_3d_fill.position = Vector3(0, 5, 0)
	_3d_fill.omni_range = 15.0
	_3d_fill.omni_attenuation = 1.5
	_3d_viewport.add_child(_3d_fill)

	_apply_time_of_day_lighting()

	# Scene root
	_3d_scene_root = Node3D.new()
	_3d_scene_root.name = "MenuCoastScene"
	_3d_viewport.add_child(_3d_scene_root)

	# Load pre-composed 3D scene
	_load_menu_3d_assets()


# ═══════════════════════════════════════════════════════════════
# DAY/NIGHT CYCLE — 3D lighting driven by system clock
# ═══════════════════════════════════════════════════════════════

const TIME_LIGHTING := {
	"night": {
		"sun_color": Color(0.20, 0.18, 0.35), "sun_energy": 0.25,
		"sun_angle": Vector3(-15, -60, 0),
		"fill_color": Color(0.15, 0.12, 0.30), "fill_energy": 0.5,
		"bg_color": Color(0.02, 0.02, 0.06),
		"ambient_color": Color(0.08, 0.06, 0.15), "ambient_energy": 0.3,
		"fog_color": Color(0.05, 0.04, 0.10),
	},
	"dawn": {
		"sun_color": Color(0.95, 0.55, 0.25), "sun_energy": 0.5,
		"sun_angle": Vector3(-5, -80, 0),
		"fill_color": Color(0.90, 0.50, 0.20), "fill_energy": 0.8,
		"bg_color": Color(0.12, 0.06, 0.08),
		"ambient_color": Color(0.25, 0.15, 0.12), "ambient_energy": 0.4,
		"fog_color": Color(0.20, 0.12, 0.10),
	},
	"morning": {
		"sun_color": Color(0.95, 0.85, 0.65), "sun_energy": 0.7,
		"sun_angle": Vector3(-25, -50, 0),
		"fill_color": Color(0.85, 0.70, 0.35), "fill_energy": 1.0,
		"bg_color": Color(0.06, 0.06, 0.09),
		"ambient_color": Color(0.20, 0.18, 0.15), "ambient_energy": 0.45,
		"fog_color": Color(0.14, 0.12, 0.10),
	},
	"midday": {
		"sun_color": Color(1.0, 0.95, 0.85), "sun_energy": 0.9,
		"sun_angle": Vector3(-60, -30, 0),
		"fill_color": Color(0.90, 0.80, 0.50), "fill_energy": 1.0,
		"bg_color": Color(0.08, 0.08, 0.10),
		"ambient_color": Color(0.25, 0.22, 0.18), "ambient_energy": 0.5,
		"fog_color": Color(0.15, 0.13, 0.10),
	},
	"afternoon": {
		"sun_color": Color(0.95, 0.80, 0.50), "sun_energy": 0.75,
		"sun_angle": Vector3(-40, 30, 0),
		"fill_color": Color(0.90, 0.70, 0.35), "fill_energy": 1.1,
		"bg_color": Color(0.06, 0.06, 0.08),
		"ambient_color": Color(0.22, 0.18, 0.14), "ambient_energy": 0.45,
		"fog_color": Color(0.14, 0.11, 0.08),
	},
	"dusk": {
		"sun_color": Color(0.90, 0.35, 0.15), "sun_energy": 0.5,
		"sun_angle": Vector3(-8, 70, 0),
		"fill_color": Color(0.85, 0.40, 0.15), "fill_energy": 0.9,
		"bg_color": Color(0.08, 0.04, 0.06),
		"ambient_color": Color(0.20, 0.10, 0.12), "ambient_energy": 0.35,
		"fog_color": Color(0.18, 0.08, 0.06),
	},
	"evening": {
		"sun_color": Color(0.35, 0.30, 0.55), "sun_energy": 0.35,
		"sun_angle": Vector3(-20, -55, 0),
		"fill_color": Color(0.30, 0.25, 0.45), "fill_energy": 0.7,
		"bg_color": Color(0.03, 0.03, 0.07),
		"ambient_color": Color(0.12, 0.10, 0.18), "ambient_energy": 0.35,
		"fog_color": Color(0.08, 0.06, 0.12),
	},
}

func _get_time_of_day() -> String:
	var hour: int = Time.get_datetime_dict_from_system().get("hour", 12)
	if hour < 5: return "night"
	if hour < 7: return "dawn"
	if hour < 10: return "morning"
	if hour < 14: return "midday"
	if hour < 17: return "afternoon"
	if hour < 20: return "dusk"
	if hour < 22: return "evening"
	return "night"

func _apply_time_of_day_lighting() -> void:
	_time_of_day = _get_time_of_day()
	var cfg: Dictionary = TIME_LIGHTING.get(_time_of_day, TIME_LIGHTING["night"])
	var env: Environment = _3d_env.environment

	_3d_sun.light_color = cfg.sun_color
	_3d_sun.light_energy = cfg.sun_energy
	_3d_sun.rotation_degrees = cfg.sun_angle

	_3d_fill.light_color = cfg.fill_color
	_3d_fill.light_energy = cfg.fill_energy

	env.background_color = cfg.bg_color
	env.ambient_light_color = cfg.ambient_color
	env.ambient_light_energy = cfg.ambient_energy
	env.fog_light_color = cfg.fog_color


func _load_menu_3d_assets() -> void:
	# Try menu_scene_v3 first, then v2, then complete, then individual assets
	var scene_paths: Array[String] = [
		"res://Assets/3d_models/menu_coast/menu_scene_v3.glb",
		"res://Assets/3d_models/menu_coast/menu_scene_v2.glb",
		"res://Assets/3d_models/menu_coast/menu_scene_complete.glb",
	]

	for path in scene_paths:
		if ResourceLoader.exists(path):
			var packed: PackedScene = load(path)
			if packed:
				var instance: Node3D = packed.instantiate()
				_3d_scene_root.add_child(instance)
				print("[Menu3D] Loaded scene: %s" % path)
				return

	# Fallback: load individual assets
	print("[Menu3D] No pre-composed scene found, loading individual assets")
	_load_individual_assets()


func _load_individual_assets() -> void:
	var assets: Array[Dictionary] = [
		{"path": "res://Assets/3d_models/menu_coast/celtic_tower.glb", "pos": Vector3(0, 0, 0), "scale": Vector3.ONE},
		{"path": "res://Assets/3d_models/menu_coast/cliff_unified.glb", "pos": Vector3(0, -1, 0), "scale": Vector3.ONE},
		{"path": "res://Assets/3d_models/menu_coast/ocean_3.glb", "pos": Vector3(0, -0.5, 5), "scale": Vector3(3, 1, 3)},
		{"path": "res://Assets/3d_models/menu_coast/rocks_set.glb", "pos": Vector3(4, 0, 3), "scale": Vector3.ONE},
		{"path": "res://Assets/3d_models/menu_coast/coastal_bush_1.glb", "pos": Vector3(-3, 0, 2), "scale": Vector3.ONE},
		{"path": "res://Assets/3d_models/menu_coast/cabin_unified.glb", "pos": Vector3(-5, 0, -2), "scale": Vector3.ONE},
	]

	for asset in assets:
		var path: String = asset["path"]
		if ResourceLoader.exists(path):
			var packed: PackedScene = load(path)
			if packed:
				var instance: Node3D = packed.instantiate()
				instance.position = asset["pos"]
				instance.scale = asset["scale"]
				_3d_scene_root.add_child(instance)


func _animate_3d_camera(delta: float) -> void:
	if _3d_camera == null or not is_instance_valid(_3d_camera):
		return

	if _camera_fly_active:
		# Fly towards tower on "new game"
		_camera_fly_t = minf(_camera_fly_t + delta * 0.4, 1.0)
		var t: float = _ease_in_out(_camera_fly_t)
		_3d_camera.position = CAM_IDLE_POS.lerp(CAM_TOWER_POS, t)
		var look_target: Vector3 = CAM_IDLE_LOOK.lerp(CAM_TOWER_LOOK, t)
		_3d_camera.look_at(look_target)
	else:
		# Gentle idle orbit
		_camera_idle_phase += delta * 0.08
		var orbit_radius: float = CAM_IDLE_POS.length() * 0.98
		var height: float = CAM_IDLE_POS.y + sin(_camera_idle_phase * 0.7) * 0.3
		_3d_camera.position = Vector3(
			cos(_camera_idle_phase) * orbit_radius,
			height,
			sin(_camera_idle_phase) * orbit_radius
		)
		_3d_camera.look_at(CAM_IDLE_LOOK + Vector3(0, sin(_camera_idle_phase * 0.5) * 0.2, 0))


func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _start_camera_fly_to_tower() -> void:
	_camera_fly_active = true
	_camera_fly_t = 0.0


func _build_ui() -> void:
	# 3D background viewport (behind everything)
	_build_3d_viewport()

	_background = ColorRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.color = Color(BG_BLACK.r, BG_BLACK.g, BG_BLACK.b, 0.55)
	add_child(_background)

	# Rune grid (behind particles)
	_rune_grid_layer = Control.new()
	_rune_grid_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rune_grid_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rune_grid_layer.clip_contents = true
	add_child(_rune_grid_layer)

	# Particle layer
	_particle_layer = Control.new()
	_particle_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_particle_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_particle_layer)

	# Frame corners
	_frame_corners = _create_frame_corners()
	_frame_corners.visible = false  # revealed during boot/show
	add_child(_frame_corners)

	# Scan bar (rune grid scanner)
	_scan_bar = ColorRect.new()
	_scan_bar.size = Vector2(get_viewport().get_visible_rect().size.x, maxf(_s(2), 1.0))
	_scan_bar.color = Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.12)
	_scan_bar.position = Vector2(0, -10)
	_scan_bar.visible = false
	_scan_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scan_bar)

	# CRT shader overlay (subtle curvature + glow)
	_crt_overlay = ColorRect.new()
	_crt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crt_shader := load("res://shaders/crt_terminal.gdshader")
	if crt_shader:
		var mat := ShaderMaterial.new()
		mat.shader = crt_shader
		mat.set_shader_parameter("global_intensity", 0.22)
		mat.set_shader_parameter("curvature", 0.015)
		mat.set_shader_parameter("scanline_opacity", 0.05)
		mat.set_shader_parameter("scanline_count", 350.0)
		mat.set_shader_parameter("phosphor_glow", 0.06)
		mat.set_shader_parameter("phosphor_tint", Vector4(0.9, 0.75, 0.3, 1.0))
		mat.set_shader_parameter("tint_blend", 0.01)
		mat.set_shader_parameter("dither_strength", 0.15)
		mat.set_shader_parameter("color_levels", 12.0)
		mat.set_shader_parameter("chromatic_enabled", true)
		mat.set_shader_parameter("chromatic_intensity", 0.0003)
		mat.set_shader_parameter("barrel_enabled", true)
		mat.set_shader_parameter("barrel_intensity", 0.002)
		mat.set_shader_parameter("glitch_enabled", true)
		mat.set_shader_parameter("glitch_probability", 0.003)
		mat.set_shader_parameter("glitch_intensity", 0.003)
		mat.set_shader_parameter("noise_enabled", true)
		mat.set_shader_parameter("noise_intensity", 0.006)
		mat.set_shader_parameter("vignette_enabled", true)
		mat.set_shader_parameter("vignette_intensity", 0.06)
		mat.set_shader_parameter("vignette_softness", 0.6)
		mat.set_shader_parameter("flicker_enabled", true)
		mat.set_shader_parameter("flicker_intensity", 0.002)
		_crt_overlay.material = mat
	add_child(_crt_overlay)

	# Digital clock
	_clock_label = Label.new()
	_clock_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_clock_label.offset_left = _s(28)
	_clock_label.offset_top = _s(18)
	_clock_label.add_theme_font_size_override("font_size", _font(10))
	_clock_label.add_theme_color_override("font_color", GOLD_FAINT)
	add_child(_clock_label)
	_update_clock()

	# Root margin container
	_root_container = MarginContainer.new()
	_root_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	var h_margin: int = _s(100) if not _is_portrait else _s(28)
	var v_margin: int = _s(50)
	_root_container.add_theme_constant_override("margin_left", h_margin)
	_root_container.add_theme_constant_override("margin_right", h_margin)
	_root_container.add_theme_constant_override("margin_top", v_margin)
	_root_container.add_theme_constant_override("margin_bottom", v_margin)
	_root_container.visible = false  # revealed after boot
	add_child(_root_container)

	# Center VBox
	_center_vbox = VBoxContainer.new()
	_center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center_vbox.add_theme_constant_override("separation", _s(4))
	_root_container.add_child(_center_vbox)

	# Title with chromatic aberration
	var title_wrapper := Control.new()
	title_wrapper.custom_minimum_size = Vector2(0, _s(60))
	title_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_vbox.add_child(title_wrapper)

	_title_shadow_r = Label.new()
	_title_shadow_r.text = TITLE_TEXT
	_title_shadow_r.set_anchors_preset(Control.PRESET_CENTER)
	_title_shadow_r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_shadow_r.add_theme_font_size_override("font_size", _font(44))
	_title_shadow_r.add_theme_color_override("font_color", Color(0.9, 0.15, 0.1, 0.0))
	_title_shadow_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_wrapper.add_child(_title_shadow_r)

	_title_shadow_b = Label.new()
	_title_shadow_b.text = TITLE_TEXT
	_title_shadow_b.set_anchors_preset(Control.PRESET_CENTER)
	_title_shadow_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_shadow_b.add_theme_font_size_override("font_size", _font(44))
	_title_shadow_b.add_theme_color_override("font_color", Color(0.1, 0.3, 0.95, 0.0))
	_title_shadow_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_wrapper.add_child(_title_shadow_b)

	_title_label = Label.new()
	_title_label.text = TITLE_TEXT
	_title_label.set_anchors_preset(Control.PRESET_CENTER)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", _font(44))
	_title_label.add_theme_color_override("font_color", GOLD)
	_title_label.add_theme_color_override("font_shadow_color", Color(0.5, 0.38, 0.08, 0.3))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	title_wrapper.add_child(_title_label)

	# Separator (3-band N64 color banding)
	_separator_top = _create_deco_separator()
	_center_vbox.add_child(_separator_top)

	# Greeting
	_greeting_label = Label.new()
	_greeting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_greeting_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_greeting_label.add_theme_font_size_override("font_size", _font(13))
	_greeting_label.add_theme_color_override("font_color", GOLD_FAINT)
	_greeting_label.custom_minimum_size = Vector2(0, _s(24))
	_center_vbox.add_child(_greeting_label)

	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_meta("merlin_greeting"):
		var greeting: String = str(game_mgr.get_meta("merlin_greeting"))
		if greeting.strip_edges() != "":
			_greeting_label.text = greeting
			_greeting_label.add_theme_color_override("font_color", GOLD_DIM)

	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, _s(14))
	_center_vbox.add_child(spacer_top)

	# Button container
	var btn_wrapper := CenterContainer.new()
	btn_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_vbox.add_child(btn_wrapper)

	_btn_container = VBoxContainer.new()
	_btn_container.add_theme_constant_override("separation", _s(8))
	var btn_max_w: float = 380.0 * _scale if not _is_portrait else 560.0 * _scale
	_btn_container.custom_minimum_size = Vector2(btn_max_w, 0)
	btn_wrapper.add_child(_btn_container)

	var btn_data: Array[Dictionary] = [
		{"label": "NOUVELLE PARTIE", "enabled": true},
		{"label": "CONTINUER", "enabled": _has_save()},
		{"label": "OPTIONS", "enabled": true},
		{"label": "QUITTER", "enabled": true},
	]

	for entry in btn_data:
		var btn: Button = _make_button(entry["label"], entry["enabled"])
		btn.pressed.connect(_on_menu_button.bind(entry["label"]))
		_btn_container.add_child(btn)
		_buttons.append(btn)

	var spacer_bottom := Control.new()
	spacer_bottom.custom_minimum_size = Vector2(0, _s(10))
	_center_vbox.add_child(spacer_bottom)

	_separator_bottom = _create_deco_separator()
	_center_vbox.add_child(_separator_bottom)

	_lore_label = Label.new()
	_lore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_lore_label.add_theme_font_size_override("font_size", _font(11))
	_lore_label.add_theme_color_override("font_color", GOLD_FAINT)
	_lore_label.pivot_offset = Vector2(_lore_label.size.x * 0.5, _lore_label.size.y * 0.5)
	_lore_idx = randi() % LORE_QUOTES.size()
	_lore_label.text = LORE_QUOTES[_lore_idx]
	_center_vbox.add_child(_lore_label)

	var lore_timer := Timer.new()
	lore_timer.wait_time = 7.0
	lore_timer.autostart = true
	lore_timer.timeout.connect(_rotate_lore_quote)
	add_child(lore_timer)

	_version_label = Label.new()
	_version_label.text = "v0.9 // BROCELIANDE"
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_version_label.add_theme_font_size_override("font_size", _font(9))
	_version_label.add_theme_color_override("font_color", Color(0.30, 0.24, 0.10, 0.20))
	_center_vbox.add_child(_version_label)


# ═══════════════════════════════════════════════════════════════
# PHASE 1 — VERTEX JITTER (N64 hardware artifact)
# ═══════════════════════════════════════════════════════════════

func _apply_vertex_jitter() -> void:
	_jitter_frame += 1
	if not is_instance_valid(_title_label) or not _menu_visible:
		return
	# 0.5px sub-pixel jitter at 60fps = authentic N64 vertex snapping
	_title_label.position.x = _rng.randf_range(-0.5, 0.5)
	_title_label.position.y = _rng.randf_range(-0.5, 0.5)
	# Independent phase on chromatic shadows
	if is_instance_valid(_title_shadow_r):
		_title_shadow_r.position.x += _rng.randf_range(-0.3, 0.3)
	if is_instance_valid(_title_shadow_b):
		_title_shadow_b.position.x += _rng.randf_range(-0.3, 0.3)


# ═══════════════════════════════════════════════════════════════
# PHASE 1 — 3-BAND SEPARATOR (N64 16-bit color banding)
# ═══════════════════════════════════════════════════════════════

func _create_deco_separator() -> CenterContainer:
	var wrapper := CenterContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.custom_minimum_size = Vector2(0, _s(18))

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", _s(8))
	wrapper.add_child(hbox)

	# Left: 3-band line (dim / bright / dim)
	var left_band := VBoxContainer.new()
	left_band.add_theme_constant_override("separation", 0)
	for band_color in [GOLD_SUBTLE, GOLD_DIM, GOLD_SUBTLE]:
		var band := ColorRect.new()
		band.custom_minimum_size = Vector2(_s(60), 1)
		band.color = band_color
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left_band.add_child(band)
	hbox.add_child(left_band)

	# Center diamond
	var diamond := Label.new()
	diamond.text = "\u25C6"
	diamond.add_theme_font_size_override("font_size", _font(8))
	diamond.add_theme_color_override("font_color", GOLD)
	hbox.add_child(diamond)

	# Right: 3-band line
	var right_band := VBoxContainer.new()
	right_band.add_theme_constant_override("separation", 0)
	for band_color in [GOLD_SUBTLE, GOLD_DIM, GOLD_SUBTLE]:
		var band := ColorRect.new()
		band.custom_minimum_size = Vector2(_s(60), 1)
		band.color = band_color
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right_band.add_child(band)
	hbox.add_child(right_band)

	return wrapper


# ═══════════════════════════════════════════════════════════════
# PHASE 2 — PARTICLES WITH TRAILS (Zelda OoT Navi)
# ═══════════════════════════════════════════════════════════════

func _init_particles(count: int) -> void:
	var vp := get_viewport().get_visible_rect().size
	for _i in range(count):
		var dot := ColorRect.new()
		var sz: float = _rng.randf_range(1.0, 3.0) * _scale
		dot.size = Vector2(sz, sz)
		dot.color = Color(GOLD.r, GOLD.g, GOLD.b, _rng.randf_range(0.03, 0.12))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(_rng.randf() * vp.x, _rng.randf() * vp.y)
		_particle_layer.add_child(dot)

		# Trail: 5 smaller fading dots
		var trail_nodes: Array[ColorRect] = []
		for t_idx in range(5):
			var trail := ColorRect.new()
			var t_sz: float = sz * (0.7 - t_idx * 0.1)
			trail.size = Vector2(maxf(t_sz, 0.5), maxf(t_sz, 0.5))
			trail.color = Color(GOLD.r, GOLD.g, GOLD.b, dot.color.a * (0.5 - t_idx * 0.08))
			trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
			trail.position = dot.position
			_particle_layer.add_child(trail)
			trail_nodes.append(trail)

		_particles.append({
			"node": dot,
			"trails": trail_nodes,
			"trail_positions": [],  # ring buffer filled during animate
			"vx": _rng.randf_range(-8.0, 8.0),
			"vy": _rng.randf_range(-15.0, -3.0),
			"alpha_base": dot.color.a,
			"phase": _rng.randf() * TAU,
			"cyan_timer": 0.0,  # >0 = currently cyan
		})


func _animate_particles(delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	_trail_update_counter += 1
	var update_trail: bool = (_trail_update_counter % 3 == 0)  # every 3rd frame

	for p in _particles:
		var dot: ColorRect = p["node"]
		if not is_instance_valid(dot):
			continue

		# Store position for trail (ring buffer of 5)
		if update_trail:
			var trail_pos: Array = p["trail_positions"]
			trail_pos.push_front(Vector2(dot.position.x, dot.position.y))
			if trail_pos.size() > 5:
				trail_pos.resize(5)
			p["trail_positions"] = trail_pos

			# Update trail dot positions
			var trails: Array = p["trails"]
			for t_idx in range(trails.size()):
				var trail_node: ColorRect = trails[t_idx]
				if is_instance_valid(trail_node) and t_idx < trail_pos.size():
					trail_node.position = trail_pos[t_idx]

		dot.position.x += float(p["vx"]) * delta
		dot.position.y += float(p["vy"]) * delta
		p["phase"] = float(p["phase"]) + delta * 1.5

		# Twinkle
		var alpha: float = float(p["alpha_base"]) * (0.5 + 0.5 * sin(float(p["phase"])))
		dot.color.a = alpha

		# Cyan color cycling (1 in 10 chance per cycle)
		var cyan_t: float = float(p["cyan_timer"])
		if cyan_t > 0.0:
			p["cyan_timer"] = cyan_t - delta
			dot.color.r = NEON_CYAN.r
			dot.color.g = NEON_CYAN.g
			dot.color.b = NEON_CYAN.b
		else:
			dot.color.r = GOLD.r
			dot.color.g = GOLD.g
			dot.color.b = GOLD.b
			if _rng.randf() < 0.0005:  # rare trigger
				p["cyan_timer"] = 2.0

		# Wrap
		if dot.position.y < -10.0:
			dot.position.y = vp.y + 5.0
			dot.position.x = _rng.randf() * vp.x
		if dot.position.x < -10.0:
			dot.position.x = vp.x + 5.0
		elif dot.position.x > vp.x + 10.0:
			dot.position.x = -5.0


# ═══════════════════════════════════════════════════════════════
# PHASE 2 — LUMINOUS ORBS (will-o'-wisps)
# ═══════════════════════════════════════════════════════════════

func _init_orbs(count: int) -> void:
	var vp := get_viewport().get_visible_rect().size
	for _i in range(count):
		var base_x: float = _rng.randf() * vp.x
		var base_y: float = _rng.randf() * vp.y

		# 3 concentric layers: outer glow, mid, core
		var outer := ColorRect.new()
		outer.size = Vector2(_s(18), _s(18))
		outer.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.03)
		outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_particle_layer.add_child(outer)

		var mid := ColorRect.new()
		mid.size = Vector2(_s(10), _s(10))
		mid.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.07)
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_particle_layer.add_child(mid)

		var core := ColorRect.new()
		core.size = Vector2(_s(4), _s(4))
		core.color = Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.15)
		core.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_particle_layer.add_child(core)

		_orbs.append({
			"outer": outer, "mid": mid, "core": core,
			"base_x": base_x, "base_y": base_y,
			"phase_x": _rng.randf() * TAU,
			"phase_y": _rng.randf() * TAU,
			"speed_x": _rng.randf_range(0.3, 0.6),
			"speed_y": _rng.randf_range(0.2, 0.5),
			"amp_x": _rng.randf_range(80.0, 150.0) * _scale,
			"amp_y": _rng.randf_range(40.0, 80.0) * _scale,
		})


func _animate_orbs(delta: float) -> void:
	var title_center := Vector2.ZERO
	if is_instance_valid(_title_label):
		title_center = _title_label.global_position + _title_label.size * 0.5

	for orb in _orbs:
		orb["phase_x"] = float(orb["phase_x"]) + delta * float(orb["speed_x"])
		orb["phase_y"] = float(orb["phase_y"]) + delta * float(orb["speed_y"])

		var px: float = float(orb["base_x"]) + sin(float(orb["phase_x"])) * float(orb["amp_x"])
		var py: float = float(orb["base_y"]) + cos(float(orb["phase_y"])) * float(orb["amp_y"])

		var outer: ColorRect = orb["outer"]
		var mid: ColorRect = orb["mid"]
		var core_node: ColorRect = orb["core"]

		if is_instance_valid(outer):
			outer.position = Vector2(px - outer.size.x * 0.5, py - outer.size.y * 0.5)
		if is_instance_valid(mid):
			mid.position = Vector2(px - mid.size.x * 0.5, py - mid.size.y * 0.5)
		if is_instance_valid(core_node):
			core_node.position = Vector2(px - core_node.size.x * 0.5, py - core_node.size.y * 0.5)

		# Proximity to title → chromatic aberration boost
		if title_center != Vector2.ZERO:
			var dist: float = Vector2(px, py).distance_to(title_center)
			if dist < 120.0 * _scale:
				var intensity: float = (1.0 - dist / (120.0 * _scale)) * 0.15
				if is_instance_valid(_title_shadow_r):
					_title_shadow_r.add_theme_color_override("font_color", Color(0.9, 0.15, 0.1, 0.04 + intensity))
				if is_instance_valid(_title_shadow_b):
					_title_shadow_b.add_theme_color_override("font_color", Color(0.1, 0.3, 0.95, 0.04 + intensity))


# ═══════════════════════════════════════════════════════════════
# PHASE 3 — SCROLLING RUNE GRID (GoldenEye data stream)
# ═══════════════════════════════════════════════════════════════

func _init_rune_grid() -> void:
	var vp := get_viewport().get_visible_rect().size
	var cell_w: int = _s(28)
	var cell_h: int = _s(22)
	var cols: int = int(vp.x / float(cell_w)) + 2
	var rows: int = int(vp.y / float(cell_h)) + 4  # extra rows for scroll wrap

	for row in range(rows):
		for col in range(cols):
			var lbl := Label.new()
			lbl.text = OGHAM_CHARS[_rng.randi() % OGHAM_CHARS.size()]
			lbl.add_theme_font_size_override("font_size", _font(10))
			lbl.add_theme_color_override("font_color", Color(GOLD.r, GOLD.g, GOLD.b, _rng.randf_range(0.03, 0.07)))
			lbl.position = Vector2(col * cell_w, row * cell_h)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_rune_grid_layer.add_child(lbl)
			_rune_labels.append(lbl)


func _animate_rune_grid(delta: float) -> void:
	# Slow upward scroll
	_rune_grid_scroll_y -= delta * 10.0 * _scale
	var cell_h: int = _s(22)
	var vp_h: float = get_viewport().get_visible_rect().size.y

	for lbl in _rune_labels:
		if not is_instance_valid(lbl):
			continue
		lbl.position.y += _rune_grid_scroll_y * delta
		# Wrap when scrolled off top
		if lbl.position.y < -float(cell_h):
			lbl.position.y += vp_h + float(cell_h) * 3.0
			lbl.text = OGHAM_CHARS[_rng.randi() % OGHAM_CHARS.size()]

	_rune_grid_scroll_y = 0.0  # reset accumulator (applied per-frame)

	# Row activation flash (every 5-10s)
	_rune_row_timer += delta
	if _rune_row_timer >= _rune_row_cooldown:
		_rune_row_timer = 0.0
		_rune_row_cooldown = _rng.randf_range(5.0, 10.0)
		_flash_rune_row()

	# Scan bar timer
	if not _scan_bar_active:
		_scan_bar_timer += delta
		if _scan_bar_timer >= _scan_bar_cooldown:
			_scan_bar_timer = 0.0
			_start_scan_bar()


func _flash_rune_row() -> void:
	if _rune_labels.is_empty():
		return
	# Pick a random label and flash its horizontal neighbors
	var target_y: float = _rune_labels[_rng.randi() % _rune_labels.size()].position.y
	SFXManager.play("boot_line")

	for lbl in _rune_labels:
		if not is_instance_valid(lbl):
			continue
		if absf(lbl.position.y - target_y) < 4.0:
			var orig_color := lbl.get_theme_color("font_color")
			var orig_x: float = lbl.position.x
			lbl.add_theme_color_override("font_color", GOLD_BRIGHT)
			lbl.position.x += _rng.randf_range(3.0, 8.0)
			var tw := create_tween()
			tw.tween_interval(0.12)
			tw.tween_callback(func() -> void:
				if is_instance_valid(lbl):
					lbl.add_theme_color_override("font_color", orig_color)
					lbl.position.x = orig_x
			)


func _start_scan_bar() -> void:
	if not is_instance_valid(_scan_bar):
		return
	_scan_bar.visible = true
	_scan_bar.position.y = -5.0
	_scan_bar_active = true
	var vp_h: float = get_viewport().get_visible_rect().size.y
	var tw := create_tween()
	tw.tween_property(_scan_bar, "position:y", vp_h + 5.0, 3.0).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func() -> void:
		_scan_bar_active = false
		if is_instance_valid(_scan_bar):
			_scan_bar.visible = false
		SFXManager.play("ogham_chime")
	)


func _animate_scan_bar(_delta: float) -> void:
	if not _scan_bar_active or not is_instance_valid(_scan_bar):
		return
	# Brighten runes near the scan bar
	var bar_y: float = _scan_bar.position.y
	for lbl in _rune_labels:
		if not is_instance_valid(lbl):
			continue
		if absf(lbl.position.y - bar_y) < 15.0 * _scale:
			lbl.add_theme_color_override("font_color", Color(GOLD.r, GOLD.g, GOLD.b, 0.18))
		# Don't reset here — the grid animation will naturally fade them


# ═══════════════════════════════════════════════════════════════
# TITLE GLOW PULSE
# ═══════════════════════════════════════════════════════════════

func _animate_title_glow(delta: float) -> void:
	_title_glow_phase += delta * 0.8
	if not is_instance_valid(_title_label):
		return
	var glow: float = 0.85 + 0.15 * sin(_title_glow_phase)
	_title_label.add_theme_color_override("font_color", Color(GOLD.r * glow, GOLD.g * glow, GOLD.b * glow))

	var drift: float = sin(_title_glow_phase * 1.3) * 0.8
	if is_instance_valid(_title_shadow_r):
		_title_shadow_r.position.x = -1.5 + drift
		_title_shadow_r.add_theme_color_override("font_color", Color(0.9, 0.15, 0.1, 0.04 + 0.02 * sin(_title_glow_phase * 2.0)))
	if is_instance_valid(_title_shadow_b):
		_title_shadow_b.position.x = 1.5 - drift
		_title_shadow_b.add_theme_color_override("font_color", Color(0.1, 0.3, 0.95, 0.04 + 0.02 * sin(_title_glow_phase * 2.0 + 1.0)))


func _animate_frame(delta: float) -> void:
	_frame_alpha_phase += delta * 0.6
	if not is_instance_valid(_frame_corners):
		return
	_frame_corners.modulate.a = 0.5 + 0.25 * sin(_frame_alpha_phase)


# ═══════════════════════════════════════════════════════════════
# N64-STYLE FRAME CORNERS
# ═══════════════════════════════════════════════════════════════

func _create_frame_corners() -> Control:
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vp := get_viewport().get_visible_rect().size
	var corner_len: float = _s(40)
	var corner_thick: float = maxf(_s(2), 1.0)
	var inset: float = _s(16)
	var col := GOLD_DIM

	_add_corner_line(container, Vector2(inset, inset), Vector2(inset + corner_len, inset), corner_thick, col)
	_add_corner_line(container, Vector2(inset, inset), Vector2(inset, inset + corner_len), corner_thick, col)
	_add_corner_line(container, Vector2(vp.x - inset, inset), Vector2(vp.x - inset - corner_len, inset), corner_thick, col)
	_add_corner_line(container, Vector2(vp.x - inset, inset), Vector2(vp.x - inset, inset + corner_len), corner_thick, col)
	_add_corner_line(container, Vector2(inset, vp.y - inset), Vector2(inset + corner_len, vp.y - inset), corner_thick, col)
	_add_corner_line(container, Vector2(inset, vp.y - inset), Vector2(inset, vp.y - inset - corner_len), corner_thick, col)
	_add_corner_line(container, Vector2(vp.x - inset, vp.y - inset), Vector2(vp.x - inset - corner_len, vp.y - inset), corner_thick, col)
	_add_corner_line(container, Vector2(vp.x - inset, vp.y - inset), Vector2(vp.x - inset, vp.y - inset - corner_len), corner_thick, col)

	for pos in [Vector2(inset, inset), Vector2(vp.x - inset, inset), Vector2(inset, vp.y - inset), Vector2(vp.x - inset, vp.y - inset)]:
		var diamond := ColorRect.new()
		diamond.size = Vector2(maxf(_s(4), 2), maxf(_s(4), 2))
		diamond.position = pos - diamond.size * 0.5
		diamond.color = GOLD
		diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(diamond)

	return container


func _add_corner_line(parent: Control, from: Vector2, to: Vector2, thick: float, col: Color) -> void:
	var line := Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.width = thick
	line.default_color = col
	parent.add_child(line)


# ═══════════════════════════════════════════════════════════════
# BUTTON FACTORY
# ═══════════════════════════════════════════════════════════════

func _make_button(text: String, enabled: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.disabled = not enabled
	btn.custom_minimum_size = Vector2(0, _s(52))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", _font(15))
	btn.add_theme_color_override("font_color", GOLD_DIM if enabled else GOLD_SUBTLE)
	btn.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", GOLD)
	btn.add_theme_color_override("font_disabled_color", GOLD_SUBTLE)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.focus_mode = Control.FOCUS_ALL

	var style := StyleBoxFlat.new()
	style.bg_color = BG_BTN
	style.border_color = BORDER_BTN
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(_s(10))
	btn.add_theme_stylebox_override("normal", style)

	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = BG_BTN_HOVER
	hover_style.border_color = GOLD
	hover_style.border_width_left = _s(3)
	hover_style.border_width_right = 1
	hover_style.border_width_top = 1
	hover_style.border_width_bottom = 1
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = style.duplicate()
	pressed_style.bg_color = Color(0.20, 0.16, 0.05, 0.55)
	pressed_style.border_color = GOLD_BRIGHT
	pressed_style.set_border_width_all(2)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	var focus_style: StyleBoxFlat = hover_style.duplicate()
	focus_style.border_color = GOLD_BRIGHT
	focus_style.border_width_left = _s(3)
	btn.add_theme_stylebox_override("focus", focus_style)

	var disabled_style: StyleBoxFlat = style.duplicate()
	disabled_style.bg_color = Color(0.03, 0.03, 0.02, 0.15)
	disabled_style.border_color = Color(0.12, 0.10, 0.05, 0.10)
	btn.add_theme_stylebox_override("disabled", disabled_style)

	btn.mouse_entered.connect(func() -> void:
		if not btn.disabled:
			SFXManager.play("hover")
			_btn_hover_glitch(btn)
	)
	return btn


func _btn_hover_glitch(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	var original_text: String = btn.text
	var corrupted: String = ""
	for ch in original_text:
		if _rng.randf() < 0.3 and ch != " ":
			corrupted += GLITCH_CHARS[_rng.randi() % GLITCH_CHARS.length()]
		else:
			corrupted += ch
	btn.text = corrupted
	var tw := create_tween()
	tw.tween_interval(0.06)
	tw.tween_callback(func() -> void:
		if is_instance_valid(btn):
			btn.text = original_text
	)


# ═══════════════════════════════════════════════════════════════
# SCALE HELPERS
# ═══════════════════════════════════════════════════════════════

func _s(base_px: int) -> int:
	return int(float(base_px) * _scale)

func _font(base_size: int) -> int:
	return maxi(int(float(base_size) * _scale), 9)

func _update_clock() -> void:
	if not is_instance_valid(_clock_label):
		return
	var t := Time.get_time_dict_from_system()
	_clock_label.text = "%02d:%02d:%02d" % [t.get("hour", 0), t.get("minute", 0), t.get("second", 0)]


# ═══════════════════════════════════════════════════════════════
# PHASE 4 — N64 BOOT SEQUENCE (one-time CRT power-on)
# ═══════════════════════════════════════════════════════════════

func _play_boot_sequence() -> void:
	_booting = true
	_menu_visible = false

	# Hide everything
	_root_container.visible = false
	_frame_corners.visible = false
	_clock_label.visible = false
	_rune_grid_layer.modulate.a = 0.0

	# CRT static overlay
	_boot_overlay = ColorRect.new()
	_boot_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var static_shader := load("res://shaders/crt_static.gdshader")
	if static_shader:
		var mat := ShaderMaterial.new()
		mat.shader = static_shader
		mat.set_shader_parameter("intensity", 0.7)
		mat.set_shader_parameter("noise_speed", 50.0)
		mat.set_shader_parameter("grain_intensity", 0.4)
		mat.set_shader_parameter("flicker_intensity", 0.08)
		mat.set_shader_parameter("tint", Vector4(0.9, 0.8, 0.4, 1.0))
		_boot_overlay.material = mat
	else:
		_boot_overlay.color = Color(0.1, 0.1, 0.1, 0.8)
	add_child(_boot_overlay)

	# CRT power-on line (expands from center)
	var vp := get_viewport().get_visible_rect().size
	var power_line := ColorRect.new()
	power_line.color = Color(0.9, 0.8, 0.4, 0.6)
	power_line.size = Vector2(vp.x, 2.0)
	power_line.position = Vector2(0, vp.y * 0.5 - 1.0)
	power_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(power_line)

	SFXManager.play("convergence")

	var tw := create_tween()

	# Phase A: CRT power-on (0.0 - 0.8s)
	tw.tween_property(power_line, "size:y", vp.y, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(power_line, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# Fade static overlay
	if _boot_overlay.material:
		tw.parallel().tween_method(func(val: float) -> void:
			if is_instance_valid(_boot_overlay) and _boot_overlay.material:
				(_boot_overlay.material as ShaderMaterial).set_shader_parameter("intensity", val)
		, 0.7, 0.0, 0.8)

	tw.tween_callback(func() -> void:
		if _boot_skip_pressed:
			_boot_finish(power_line)
			return
		if is_instance_valid(power_line):
			power_line.queue_free()
	)

	# Phase B: Logo type-in (0.8 - 2.0s)
	tw.tween_callback(func() -> void:
		if _boot_skip_pressed:
			return
		_root_container.visible = true
		_root_container.modulate.a = 1.0
		if is_instance_valid(_title_label):
			_title_label.add_theme_color_override("font_color", PHOSPHOR_GREEN)
			_title_label.visible_characters = 0
	)

	# Type each character
	for ch_idx in range(TITLE_TEXT.length()):
		tw.tween_callback(func() -> void:
			if _boot_skip_pressed:
				return
			if is_instance_valid(_title_label):
				_title_label.visible_characters += 1
				SFXManager.play("boot_line")
		)
		tw.tween_interval(0.055)

	# Green → Gold color shift
	tw.tween_callback(func() -> void:
		if _boot_skip_pressed:
			return
		SFXManager.play("boot_confirm")
	)
	tw.tween_method(func(t: float) -> void:
		if _boot_skip_pressed:
			return
		if is_instance_valid(_title_label):
			_title_label.add_theme_color_override("font_color", PHOSPHOR_GREEN.lerp(GOLD, t))
	, 0.0, 1.0, 0.4)

	# Phase C: Grid convergence (corners appear)
	tw.tween_callback(func() -> void:
		if _boot_skip_pressed:
			return
		_frame_corners.visible = true
		_frame_corners.modulate.a = 0.0
		_frame_corners.scale = Vector2(0.9, 0.9)
		SFXManager.play("flash_boom")
	)
	tw.tween_property(_frame_corners, "modulate:a", 0.7, 0.3).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_frame_corners, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Phase D: Rune grid fade in
	tw.tween_property(_rune_grid_layer, "modulate:a", 1.0, 0.5)

	# Phase E: Menu cascade
	tw.tween_callback(func() -> void:
		_boot_finish(power_line)
	)


func _boot_finish(power_line_ref: ColorRect) -> void:
	_booting = false
	_boot_skip_pressed = false

	# Clean up boot overlay
	if is_instance_valid(_boot_overlay):
		_boot_overlay.queue_free()
		_boot_overlay = null
	if is_instance_valid(power_line_ref):
		power_line_ref.queue_free()

	# Ensure everything visible
	_root_container.visible = true
	_root_container.modulate.a = 1.0
	_frame_corners.visible = true
	_clock_label.visible = true
	_rune_grid_layer.modulate.a = 1.0

	if is_instance_valid(_title_label):
		_title_label.visible_characters = -1
		_title_label.add_theme_color_override("font_color", GOLD)

	# Mark as done for this session
	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.set_meta("menu_boot_done", true)

	_show_menu()


# ═══════════════════════════════════════════════════════════════
# MENU SHOW
# ═══════════════════════════════════════════════════════════════

func _show_menu() -> void:
	_menu_visible = true
	_root_container.visible = true

	_root_container.modulate.a = 0.0
	if is_instance_valid(_frame_corners) and not _frame_corners.visible:
		_frame_corners.visible = true
		_frame_corners.modulate.a = 0.0
	for btn in _buttons:
		btn.modulate.a = 0.0
		btn.position.x = -_s(30)

	var tween := create_tween()

	if is_instance_valid(_frame_corners):
		tween.tween_property(_frame_corners, "modulate:a", 0.6, 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_root_container, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

	for i in range(_buttons.size()):
		tween.parallel().tween_property(_buttons[i], "modulate:a", 1.0, 0.35).set_delay(0.3 + i * 0.12)
		tween.parallel().tween_property(_buttons[i], "position:x", 0.0, 0.35).set_delay(0.3 + i * 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_callback(_trigger_glitch).set_delay(0.15)
	tween.parallel().tween_callback(_trigger_glitch).set_delay(0.35)

	tween.tween_callback(func() -> void:
		for btn in _buttons:
			if not btn.disabled:
				btn.grab_focus()
				break
	)

	_clock_label.visible = true
	SFXManager.play("convergence")


# ═══════════════════════════════════════════════════════════════
# LORE ROTATION (with N64 texture swimming)
# ═══════════════════════════════════════════════════════════════

func _rotate_lore_quote() -> void:
	if not is_instance_valid(_lore_label):
		return
	var tw := create_tween()
	tw.tween_property(_lore_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_lore_label):
			_lore_idx = (_lore_idx + 1) % LORE_QUOTES.size()
			_lore_label.text = LORE_QUOTES[_lore_idx]
	)
	tw.tween_property(_lore_label, "modulate:a", 1.0, 0.4)
	# N64 mip-map shimmer: brief scale overshoot
	tw.parallel().tween_property(_lore_label, "scale", Vector2(1.02, 1.02), 0.15).set_delay(0.4)
	tw.tween_property(_lore_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)


# ═══════════════════════════════════════════════════════════════
# BUTTON ACTIONS
# ═══════════════════════════════════════════════════════════════

func _on_menu_button(label: String) -> void:
	if _transitioning:
		return
	SFXManager.play("click")
	match label:
		"NOUVELLE PARTIE":
			_start_new_game()
		"CONTINUER":
			_start_camera_fly_to_tower()
			_glitch_transition("res://scenes/HubAntre.tscn")
		"OPTIONS":
			_glitch_transition("res://scenes/MenuOptions.tscn")
		"QUITTER":
			get_tree().quit()


func _start_new_game() -> void:
	_start_camera_fly_to_tower()
	if MerlinAI and MerlinAI.has_method("_init_local_models"):
		MerlinAI._init_local_models()
	_glitch_transition("res://scenes/ParchmentPreRun.tscn")


func _has_save() -> bool:
	return FileAccess.file_exists("user://merlin_profile.json")


# ═══════════════════════════════════════════════════════════════
# GLITCH TRANSITION
# ═══════════════════════════════════════════════════════════════

func _glitch_transition(target_scene: String) -> void:
	if _transitioning:
		return
	_transitioning = true

	for btn in _buttons:
		btn.disabled = true

	var tween := create_tween()

	for _i in range(5):
		tween.tween_callback(_trigger_glitch)
		tween.tween_interval(0.06)

	tween.tween_callback(func() -> void:
		if is_instance_valid(_title_shadow_r):
			_title_shadow_r.position.x = -6.0
			_title_shadow_r.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1, 0.35))
		if is_instance_valid(_title_shadow_b):
			_title_shadow_b.position.x = 6.0
			_title_shadow_b.add_theme_color_override("font_color", Color(0.1, 0.2, 0.95, 0.35))
	)
	tween.tween_interval(0.08)

	tween.tween_callback(func() -> void:
		var flash := ColorRect.new()
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.color = Color(0.9, 0.75, 0.3, 0.18)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		var flash_tw := create_tween()
		flash_tw.tween_property(flash, "color:a", 0.0, 0.25)
		flash_tw.tween_callback(func() -> void:
			if is_instance_valid(flash):
				flash.queue_free()
		)
	)
	tween.tween_interval(0.12)

	tween.tween_callback(func() -> void:
		_spawn_screen_tears(6)
	)
	tween.tween_interval(0.15)

	tween.tween_callback(func() -> void:
		if not is_inside_tree():
			return
		if PixelTransition.has_method("_force_complete"):
			PixelTransition._force_complete()
		PixelTransition.transition_to(target_scene)
	)


# ═══════════════════════════════════════════════════════════════
# GLITCH EFFECTS
# ═══════════════════════════════════════════════════════════════

func _trigger_glitch() -> void:
	if not _menu_visible:
		return

	_spawn_screen_tears(_rng.randi_range(1, 3))

	if is_instance_valid(_title_label):
		var orig := TITLE_TEXT
		var corrupted := ""
		for ch in orig:
			if _rng.randf() < 0.25 and ch != " " and ch != ".":
				corrupted += GLITCH_CHARS[_rng.randi() % GLITCH_CHARS.length()]
			else:
				corrupted += ch
		_title_label.text = corrupted

		if is_instance_valid(_title_shadow_r):
			_title_shadow_r.position.x = _rng.randf_range(-4.0, -1.5)
			_title_shadow_r.add_theme_color_override("font_color", Color(0.9, 0.15, 0.1, 0.15))
		if is_instance_valid(_title_shadow_b):
			_title_shadow_b.position.x = _rng.randf_range(1.5, 4.0)
			_title_shadow_b.add_theme_color_override("font_color", Color(0.1, 0.3, 0.95, 0.15))

		_title_label.position.x = _rng.randf_range(-6.0, 6.0)

		var tw := create_tween()
		tw.tween_interval(0.08)
		tw.tween_callback(func() -> void:
			if is_instance_valid(_title_label):
				_title_label.text = TITLE_TEXT
				_title_label.position.x = 0.0
		)

	var glitch_overlay := ColorRect.new()
	glitch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	glitch_overlay.color = Color(GOLD.r, GOLD.g, GOLD.b, _rng.randf_range(0.02, 0.06))
	glitch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glitch_overlay)

	var overlay_tw := create_tween()
	overlay_tw.tween_interval(0.07)
	overlay_tw.tween_callback(func() -> void:
		if is_instance_valid(glitch_overlay):
			glitch_overlay.queue_free()
	)


func _spawn_screen_tears(count: int) -> void:
	var vp := get_viewport().get_visible_rect().size
	for _i in range(count):
		var tear := ColorRect.new()
		var y_pos: float = _rng.randf() * vp.y
		var height: float = _rng.randf_range(1.0, 4.0) * _scale
		tear.position = Vector2(0, y_pos)
		tear.size = Vector2(vp.x, height)
		var tear_colors := [
			Color(GOLD.r, GOLD.g, GOLD.b, 0.08),
			Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.06),
			Color(NEON_MAGENTA.r, NEON_MAGENTA.g, NEON_MAGENTA.b, 0.05),
		]
		tear.color = tear_colors[_rng.randi() % tear_colors.size()]
		tear.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tear.position.x = _rng.randf_range(-20.0, 20.0)
		add_child(tear)

		var tear_tw := create_tween()
		tear_tw.tween_interval(_rng.randf_range(0.04, 0.10))
		tear_tw.tween_callback(func() -> void:
			if is_instance_valid(tear):
				tear.queue_free()
		)


func _trigger_micro_glitch() -> void:
	if is_instance_valid(_frame_corners) and _rng.randf() < 0.3:
		_frame_corners.modulate.a = 1.0
		var fw := create_tween()
		fw.tween_interval(0.05)
		fw.tween_callback(func() -> void:
			if is_instance_valid(_frame_corners):
				_frame_corners.modulate.a = 0.5
		)
