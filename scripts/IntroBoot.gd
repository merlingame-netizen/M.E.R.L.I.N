extends Control
## IntroBoot - CeltOS Boot Sequence ULTRA RETRO v3
## Sequence: Power On -> Boot + Barre -> Orbe 24h -> Menu
## La barre se transforme en orbe qui se positionne selon l'heure

# =============================================================================
# CONFIGURATION
# =============================================================================

const FONT_PATH_LEGACY := "res://resources/fonts/morris/MorrisRomanBlackAlt.ttf"  # Legacy — use MerlinVisual
const LOGO_PATH := "res://icon.svg"
const STATIC_SHADER_PATH := "res://shaders/crt_static.gdshader"

# Layout
const LOADING_BAR_Y_RATIO := 0.42

# Behavior
const SKIP_POWER_ON := true
const SKIP_FIRST_AUDIO_BURST := true

# Phases
enum BootPhase {
	POWER_ON,        # Animation allumage CRT
	BOOT_SEQUENCE,   # Logo + barre + logs
	ORB_TRANSFORM,   # Barre se transforme en orbe
	ORB_POSITION,    # Orbe se deplace vers position horaire
	TRANSITION       # Transition vers menu
}

# Timing
const POWER_ON_DURATION := 1.8
const BOOT_DURATION := 6.0
const LOADING_DURATION := 4.5
const ORB_TRANSFORM_DURATION := 2.5  # Pixel rain phase — longer for visual impact
const ORB_POSITION_DURATION := 0.0  # Skipped — flash goes directly to menu
const TRANSITION_DURATION := 0.5  # Flash duration

# =============================================================================
# COULEURS
# =============================================================================

var COLOR_BLUE_GLOW := Color(0.3, 0.6, 1.0)
var COLOR_BLUE_BRIGHT := Color(0.5, 0.8, 1.0)
var COLOR_BLUE_CORE := Color(0.85, 0.95, 1.0)
var COLOR_AMBER := Color(1.0, 0.78, 0.1)
var COLOR_GREEN := Color(0.2, 1.0, 0.4)
var COLOR_CYAN := Color(0.4, 0.95, 0.95)
var COLOR_WHITE := Color(0.9, 0.92, 0.88)
var BG_COLOR := Color(0.005, 0.005, 0.012)

# =============================================================================
# BOOT LOGS
# =============================================================================

var BOOT_LOGS: Array[Dictionary] = [
	{"text": "[  OK  ] Mana Bus Controller initialized", "color": "green", "delay": 0.1},
	{"text": "[  OK  ] Arcane Runtime Environment loaded", "color": "green", "delay": 0.06},
	{"text": "[  OK  ] Neural Pattern Recognition Unit", "color": "green", "delay": 0.08},
	{"text": "[ INFO ] Loading inference weights...", "color": "cyan", "delay": 0.15},
	{"text": "[  OK  ] Transformer Core v4.2 ready", "color": "green", "delay": 0.1},
	{"text": "[  OK  ] Context Window: 32K tokens", "color": "green", "delay": 0.05},
	{"text": "[ WAIT ] Establishing neural handshake...", "color": "amber", "delay": 0.4},
	{"text": "[  OK  ] Embedding Matrix calibrated", "color": "green", "delay": 0.08},
	{"text": "[  OK  ] Response Generator online", "color": "green", "delay": 0.05},
	{"text": "[ INFO ] Entropy: 0x%08X" % (randi() % 0xFFFFFFFF), "color": "cyan", "delay": 0.05},
	{"text": "[  OK  ] Druidic Runtime Unit activated", "color": "green", "delay": 0.12},
	{"text": "", "color": "white", "delay": 0.1},
	{"text": "System ready. Welcome, Traveler.", "color": "amber", "delay": 0.0},
]

# =============================================================================
# NODES
# =============================================================================

var static_rect: ColorRect
var background: ColorRect
var logo: TextureRect

# =============================================================================
# STATE
# =============================================================================

var font: Font
var current_phase: int = BootPhase.POWER_ON
var phase_timer := 0.0
var time_elapsed := 0.0

# Power on
var power_on_progress := 0.0

# Static & Boot
var static_intensity := 0.0
var static_material: ShaderMaterial
var loading_progress := 0.0
var bar_glow_phase := 0.0
var visible_logs := 0
var log_timer := 0.0
var current_log_delay := 0.0
var content_alpha := 0.0

# Orb transformation
var orb_transform_progress := 0.0
var orb_position_progress := 0.0
var orb_current_pos := Vector2.ZERO
var orb_target_pos := Vector2.ZERO
var orb_start_pos := Vector2.ZERO
var orb_size := 0.0
var orb_target_size := 25.0

# Clock position (24h semi-circle)
var current_hour := 0.0
var clock_center := Vector2.ZERO
var clock_radius := 0.0

# Pixel rain particles
var _rain_pixels: Array[Dictionary] = []  # {pos, vel, color, sparkle_freq, sparkle_phase, size}
const RAIN_PIXEL_COUNT := 180
const RAIN_GRAVITY := 280.0

# Transition
var transition_alpha := 0.0

# =============================================================================
# EFFETS RETRO
# =============================================================================

var scanline_offset := 0.0
var flicker_value := 1.0
var rolling_band_y := 1.1
var chroma_offset := 0.0
var h_distort_phase := 0.0
var grain_intensity := 0.08
var hum_phase := 0.0

# Audio
var audio_player: AudioStreamPlayer
var audio_playback: AudioStreamGeneratorPlayback
var audio_rate: int = 44100
var rng := RandomNumberGenerator.new()
var continuous_noise := false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	rng.randomize()

	# Calculer l'heure actuelle
	var time_dict := Time.get_time_dict_from_system()
	current_hour = float(time_dict.hour) + float(time_dict.minute) / 60.0

	font = MerlinVisual.get_font("terminal")
	if font == null:
		font = ThemeDB.fallback_font

	_setup_nodes()
	_init_audio()

	if SKIP_POWER_ON:
		_start_boot_sequence()
	else:
		if not SKIP_FIRST_AUDIO_BURST:
			_play_power_on_sound()

	get_viewport().size_changed.connect(_on_viewport_resize)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_go_to_menu()


func _process(delta: float) -> void:
	time_elapsed += delta
	phase_timer += delta

	_update_retro_effects(delta)

	if continuous_noise:
		_feed_continuous_noise()

	match current_phase:
		BootPhase.POWER_ON:
			_process_power_on(delta)
		BootPhase.BOOT_SEQUENCE:
			_process_boot(delta)
		BootPhase.ORB_TRANSFORM:
			_process_orb_transform(delta)
		BootPhase.ORB_POSITION:
			_process_orb_position(delta)
		BootPhase.TRANSITION:
			_process_transition(delta)

	_update_static_shader()
	_update_logo()
	queue_redraw()

# =============================================================================
# SETUP
# =============================================================================

func _setup_nodes() -> void:
	background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = BG_COLOR
	add_child(background)

	static_rect = ColorRect.new()
	static_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	static_rect.visible = false
	add_child(static_rect)

	if ResourceLoader.exists(STATIC_SHADER_PATH):
		var shader: Shader = load(STATIC_SHADER_PATH)
		static_material = ShaderMaterial.new()
		static_material.shader = shader
		static_rect.material = static_material

	logo = TextureRect.new()
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.visible = false

	if ResourceLoader.exists(LOGO_PATH):
		logo.texture = load(LOGO_PATH)

	add_child(logo)
	_layout_logo()
	_calculate_clock_geometry()


func _layout_logo() -> void:
	if logo == null:
		return

	var viewport_size := get_viewport_rect().size
	var target_size := minf(viewport_size.x, viewport_size.y) * 0.2
	target_size = clampf(target_size, 80.0, 180.0)

	logo.size = Vector2(target_size, target_size)
	logo.position = Vector2(
		(viewport_size.x - target_size) * 0.5,
		viewport_size.y * 0.08
	)


func _calculate_clock_geometry() -> void:
	var viewport_size := get_viewport_rect().size
	# Arc 24h en haut de l'écran - synchronisé avec le menu
	# Gauche = 00h, Droite = 23h59
	var arc_y := viewport_size.y * 0.08
	clock_radius = minf(viewport_size.x, viewport_size.y) * 0.38
	clock_center = Vector2(viewport_size.x * 0.5, arc_y + clock_radius * 0.15)

	# Calculer la position cible de l'orbe selon l'heure
	# 0h = gauche (PI), 24h = droite (0)
	var angle := PI - (current_hour / 24.0) * PI
	orb_target_pos = clock_center + Vector2(cos(angle), -sin(angle)) * clock_radius
	orb_target_size = 18.0


func _on_viewport_resize() -> void:
	_layout_logo()
	_calculate_clock_geometry()


func _start_boot_sequence() -> void:
	current_phase = BootPhase.BOOT_SEQUENCE
	phase_timer = 0.0
	static_rect.visible = true
	static_intensity = 0.35
	loading_progress = 0.0
	bar_glow_phase = 0.0
	visible_logs = 0
	log_timer = 0.0
	current_log_delay = 0.25
	content_alpha = 0.0
	continuous_noise = true

	if not SKIP_FIRST_AUDIO_BURST:
		_play_static_burst()

# =============================================================================
# EFFETS RETRO UPDATE
# =============================================================================

func _update_retro_effects(delta: float) -> void:
	scanline_offset += delta * 25.0

	if rng.randf() < 0.02:
		flicker_value = rng.randf_range(0.88, 1.0)
	else:
		flicker_value = lerpf(flicker_value, 1.0, delta * 8.0)

	rolling_band_y -= delta * 0.12
	if rolling_band_y < -0.1:
		rolling_band_y = 1.1

	chroma_offset = 1.0 + sin(time_elapsed * 2.5) * 0.4
	h_distort_phase += delta * 2.5
	grain_intensity = 0.06 + sin(time_elapsed * 3.0) * 0.02
	hum_phase += delta * 60.0

# =============================================================================
# PHASE PROCESSING
# =============================================================================

func _process_power_on(_delta: float) -> void:
	power_on_progress = minf(phase_timer / POWER_ON_DURATION, 1.0)

	if power_on_progress >= 1.0:
		current_phase = BootPhase.BOOT_SEQUENCE
		phase_timer = 0.0
		static_rect.visible = true
		static_intensity = 0.5
		visible_logs = 0
		log_timer = 0.0
		current_log_delay = 0.25
		continuous_noise = true
		if not SKIP_FIRST_AUDIO_BURST:
			_play_static_burst()


func _process_boot(delta: float) -> void:
	if phase_timer < 0.8:
		content_alpha = _ease_out_cubic(phase_timer / 0.8)
	else:
		content_alpha = 1.0

	static_intensity = lerpf(0.35, 0.12, minf(phase_timer / 2.5, 1.0))

	var loading_start := 0.6
	if phase_timer > loading_start:
		var load_time := phase_timer - loading_start
		loading_progress = minf(_ease_out_expo(load_time / LOADING_DURATION), 1.0)

	log_timer += delta
	if visible_logs < BOOT_LOGS.size() and log_timer >= current_log_delay:
		visible_logs += 1
		log_timer = 0.0
		if visible_logs < BOOT_LOGS.size():
			current_log_delay = BOOT_LOGS[visible_logs].delay + rng.randf_range(0.02, 0.08)
			_play_log_sound()

	if loading_progress >= 1.0 and visible_logs >= BOOT_LOGS.size() and phase_timer >= BOOT_DURATION:
		current_phase = BootPhase.ORB_TRANSFORM
		phase_timer = 0.0
		orb_transform_progress = 0.0
		var viewport_size := get_viewport_rect().size
		orb_start_pos = Vector2(viewport_size.x * 0.5, viewport_size.y * LOADING_BAR_Y_RATIO)
		orb_current_pos = orb_start_pos
		orb_size = 0.0
		continuous_noise = false
		_play_orb_sound()


func _process_orb_transform(delta: float) -> void:
	orb_transform_progress = minf(phase_timer / ORB_TRANSFORM_DURATION, 1.0)
	var vs := get_viewport_rect().size

	# Initialize pixel rain on first frame
	if _rain_pixels.is_empty():
		_init_rain_pixels(vs)

	# Phase 1 (0-0.6): Pixels fall with gravity and sparkle
	# Phase 2 (0.6-0.85): Pixels converge toward center eye
	# Phase 3 (0.85-1.0): Flash white
	var t := orb_transform_progress

	if t < 0.6:
		# Falling phase — gravity + bounce
		for px in _rain_pixels:
			px.vel.y += RAIN_GRAVITY * delta
			px.pos.x += px.vel.x * delta
			px.pos.y += px.vel.y * delta
			# Bounce off bottom
			if px.pos.y > vs.y * 0.7:
				px.vel.y = -abs(px.vel.y) * 0.4
				px.pos.y = vs.y * 0.7
			px.sparkle_phase += px.sparkle_freq * delta
	elif t < 0.85:
		# Convergence phase — pixels fly toward center
		var convergence_t := (t - 0.6) / 0.25
		var center := Vector2(vs.x * 0.5, vs.y * 0.4)
		for px in _rain_pixels:
			var target := center + Vector2(rng.randf_range(-15.0, 15.0), rng.randf_range(-15.0, 15.0))
			px.pos = px.pos.lerp(target, convergence_t * 0.12)
			px.sparkle_phase += px.sparkle_freq * delta * 2.0

	static_intensity = lerpf(0.15, 0.0, t)

	if t >= 1.0:
		# Skip ORB_POSITION, go directly to TRANSITION (flash -> menu)
		current_phase = BootPhase.TRANSITION
		phase_timer = 0.0
		transition_alpha = 0.0
		static_rect.visible = false
		_save_orb_data()


func _init_rain_pixels(vs: Vector2) -> void:
	## Generate pixel rain particles across the top of screen.
	var eye_colors: Array[Color] = [
		COLOR_BLUE_GLOW, COLOR_BLUE_BRIGHT, COLOR_BLUE_CORE,
		COLOR_CYAN, COLOR_WHITE,
	]
	_rain_pixels.clear()
	for i in range(RAIN_PIXEL_COUNT):
		_rain_pixels.append({
			"pos": Vector2(rng.randf_range(vs.x * 0.1, vs.x * 0.9), rng.randf_range(-vs.y * 0.3, vs.y * 0.1)),
			"vel": Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(30.0, 120.0)),
			"color": eye_colors[i % eye_colors.size()],
			"sparkle_freq": rng.randf_range(3.0, 8.0),
			"sparkle_phase": rng.randf_range(0.0, TAU),
			"size": rng.randf_range(3.0, 7.0),
		})


func _process_orb_position(_delta: float) -> void:
	orb_position_progress = minf(phase_timer / ORB_POSITION_DURATION, 1.0)

	# L'orbe se deplace vers sa position horaire avec une courbe
	var t := _ease_in_out_cubic(orb_position_progress)

	# Trajectoire en arc
	var mid_point := (orb_start_pos + orb_target_pos) * 0.5
	mid_point.y -= 50  # Arc vers le haut

	# Bezier quadratique
	var p0 := orb_start_pos
	var p1 := mid_point
	var p2 := orb_target_pos
	orb_current_pos = p0 * (1-t) * (1-t) + p1 * 2 * (1-t) * t + p2 * t * t

	# Leger changement de taille pendant le deplacement
	orb_size = orb_target_size * (1.0 + sin(t * PI) * 0.2)

	if orb_position_progress >= 1.0:
		current_phase = BootPhase.TRANSITION
		phase_timer = 0.0
		transition_alpha = 0.0
		orb_size = orb_target_size
		# Sauvegarder la position de l'orbe pour le menu
		_save_orb_data()


func _process_transition(_delta: float) -> void:
	transition_alpha = minf(phase_timer / TRANSITION_DURATION, 1.0)

	if transition_alpha >= 1.0:
		_go_to_menu()

# =============================================================================
# RENDERING
# =============================================================================

func _draw() -> void:
	var viewport_size := get_viewport_rect().size

	match current_phase:
		BootPhase.POWER_ON:
			_draw_power_on(viewport_size)
		BootPhase.BOOT_SEQUENCE:
			_draw_boot_screen(viewport_size)
			_draw_retro_overlays(viewport_size)
		BootPhase.ORB_TRANSFORM:
			_draw_orb_transform(viewport_size)
			_draw_retro_overlays(viewport_size)
		BootPhase.ORB_POSITION:
			_draw_clock_arc(viewport_size)
			_draw_orb(viewport_size)
		BootPhase.TRANSITION:
			# Flash white → fade to menu (no orb/clock since we skip ORB_POSITION)
			draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.95, 0.97, 1.0, maxf(0.0, 1.0 - transition_alpha)))


func _draw_power_on(viewport_size: Vector2) -> void:
	var center := viewport_size * 0.5

	# Phase 1: Flash lumineux central (0 -> 0.15)
	if power_on_progress < 0.15:
		var p := power_on_progress / 0.15
		var flash_size := lerpf(0.0, 20.0, _ease_out_expo(p))
		var flash_alpha := _ease_out_cubic(p)

		# Glow concentrique
		for i in range(5):
			var glow_mult := float(5 - i) / 5.0
			var glow_size := flash_size * (1.0 + float(i) * 0.8)
			var glow_alpha := flash_alpha * glow_mult * 0.4
			var glow_color := Color(0.9, 0.95, 1.0, glow_alpha)
			draw_rect(Rect2(center.x - glow_size, center.y - glow_size, glow_size * 2, glow_size * 2), glow_color)

		var dot_color := Color(1.0, 1.0, 1.0, flash_alpha)
		draw_rect(Rect2(center.x - flash_size * 0.3, center.y - flash_size * 0.3, flash_size * 0.6, flash_size * 0.6), dot_color)

	# Phase 2: Expansion horizontale avec effet de degazage (0.15 -> 0.45)
	elif power_on_progress < 0.45:
		var p := (power_on_progress - 0.15) / 0.3
		var line_width := lerpf(20.0, viewport_size.x * 1.1, _ease_out_expo(p))
		var line_height := lerpf(20.0, 6.0, p)

		var line_x := center.x - line_width * 0.5
		var line_y := center.y - line_height * 0.5

		# Glow multiple
		for i in range(4):
			var glow_h := line_height * (3.0 + float(i) * 1.5)
			var glow_alpha := 0.3 * (1.0 - float(i) * 0.2)
			var glow_color := Color(0.7, 0.85, 1.0, glow_alpha)
			draw_rect(Rect2(line_x, center.y - glow_h * 0.5, line_width, glow_h), glow_color)

		var line_color := Color(0.95, 0.98, 1.0, 1.0)
		draw_rect(Rect2(line_x, line_y, line_width, line_height), line_color)

		# Effet de particules de degazage
		for i in range(20):
			var px := line_x + rng.randf() * line_width
			var py := center.y + rng.randf_range(-30, 30) * p
			var ps := rng.randf_range(2, 5)
			var pa := rng.randf() * 0.5 * (1.0 - p)
			draw_rect(Rect2(px, py, ps, ps), Color(0.8, 0.9, 1.0, pa))

	# Phase 3: Expansion verticale avec apparition de la statique (0.45 -> 1.0)
	else:
		var p := (power_on_progress - 0.45) / 0.55
		var screen_height := lerpf(6.0, viewport_size.y, _ease_out_expo(p))
		var rect_y := center.y - screen_height * 0.5

		# Flash qui diminue
		var flash_alpha := (1.0 - p) * 0.4
		draw_rect(Rect2(0, rect_y, viewport_size.x, screen_height), Color(1.0, 1.0, 1.0, flash_alpha))

		# Bruit statique croissant
		var noise_alpha := p * 0.4
		for i in range(int(80 * p)):
			var nx := rng.randf() * viewport_size.x
			var ny := rect_y + rng.randf() * screen_height
			var nw := rng.randf_range(3, 12)
			var nh := rng.randf_range(1, 4)
			var nc := Color(rng.randf() * 0.5 + 0.5, rng.randf() * 0.5 + 0.5, rng.randf() * 0.5 + 0.5, noise_alpha * rng.randf())
			draw_rect(Rect2(nx, ny, nw, nh), nc)

		# Lignes de scan pendant l'ouverture
		var scan_count := int(20 * p)
		for i in range(scan_count):
			var sy := rect_y + (float(i) / float(maxi(scan_count, 1))) * screen_height
			var sa := 0.1 * (1.0 - p)
			draw_rect(Rect2(0, sy, viewport_size.x, 1), Color(1, 1, 1, sa))


func _draw_boot_screen(viewport_size: Vector2) -> void:
	if not font:
		return

	var center_x := viewport_size.x * 0.5
	var alpha := content_alpha * flicker_value

	# Titre "CeltOS"
	var title := "C e l t O S"
	var title_size := 40
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size).x
	var title_y := viewport_size.y * 0.30

	# Bloom du titre
	for i in range(4):
		var glow_offset := float(i + 1) * 2.5
		var glow_alpha := alpha * 0.12 * (1.0 - float(i) * 0.25)
		var glow_color := Color(COLOR_AMBER.r, COLOR_AMBER.g, COLOR_AMBER.b, glow_alpha)
		draw_string(font, Vector2(center_x - title_width * 0.5 - glow_offset, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, glow_color)
		draw_string(font, Vector2(center_x - title_width * 0.5 + glow_offset, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, glow_color)
		draw_string(font, Vector2(center_x - title_width * 0.5, title_y - glow_offset), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, glow_color)
		draw_string(font, Vector2(center_x - title_width * 0.5, title_y + glow_offset), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, glow_color)

	# Chromatic aberration
	draw_string(font, Vector2(center_x - title_width * 0.5 - chroma_offset, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(1.0, 0.3, 0.3, alpha * 0.25))
	draw_string(font, Vector2(center_x - title_width * 0.5 + chroma_offset, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0.3, 0.3, 1.0, alpha * 0.25))

	# Titre principal
	draw_string(font, Vector2(center_x - title_width * 0.5, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(COLOR_AMBER.r, COLOR_AMBER.g, COLOR_AMBER.b, alpha))

	# Sous-titre
	var subtitle := "Druidic Runtime Unit v2.1"
	var sub_size := 13
	var sub_width := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_size).x
	draw_string(font, Vector2(center_x - sub_width * 0.5, title_y + 32), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(COLOR_CYAN.r, COLOR_CYAN.g, COLOR_CYAN.b, alpha * 0.8))

	# Barre de chargement
	_draw_loading_bar(viewport_size, viewport_size.y * LOADING_BAR_Y_RATIO, alpha)

	# Logs
	_draw_boot_logs(viewport_size, alpha)


func _draw_loading_bar(viewport_size: Vector2, y_pos: float, alpha: float) -> void:
	alpha = clampf(alpha * 1.25, 0.0, 1.0)
	var center_x := viewport_size.x * 0.5
	var bar_max_width := viewport_size.x * 0.55
	var bar_height := 16.0
	var bar_current_width := bar_max_width * loading_progress

	var bar_x := center_x - bar_max_width * 0.5
	var bar_y := y_pos

	var glow_pulse := 0.6 + 0.4 * sin(bar_glow_phase)
	bar_glow_phase += 0.15

	# === GLOW EXTERNE MASSIF (visible même sur static) ===
	for i in range(8):
		var glow_expand := float(8 - i) * 12.0
		var glow_alpha := 0.06 * (1.0 - float(i) * 0.1) * alpha * glow_pulse
		draw_rect(Rect2(bar_x - glow_expand, bar_y - glow_expand, bar_max_width + glow_expand * 2, bar_height + glow_expand * 2), Color(0.2, 0.5, 1.0, glow_alpha))

	# Fond sombre de la barre
	draw_rect(Rect2(bar_x - 4, bar_y - 4, bar_max_width + 8, bar_height + 8), Color(0.02, 0.04, 0.08, alpha * 0.95))

	# Bordure lumineuse
	draw_rect(Rect2(bar_x - 2, bar_y - 2, bar_max_width + 4, bar_height + 4), Color(COLOR_BLUE_BRIGHT.r, COLOR_BLUE_BRIGHT.g, COLOR_BLUE_BRIGHT.b, alpha * 0.7), false, 2.5)

	if bar_current_width > 2:
		# === GLOW INTENSE DE LA BARRE REMPLIE ===
		for i in range(6):
			var inner_glow := float(6 - i) * 8.0
			var inner_alpha := 0.12 * (1.0 - float(i) * 0.15) * alpha * glow_pulse
			draw_rect(Rect2(bar_x - inner_glow, bar_y - inner_glow, bar_current_width + inner_glow * 2, bar_height + inner_glow * 2), Color(0.3, 0.6, 1.0, inner_alpha))

		# Barre principale - dégradé simulé
		draw_rect(Rect2(bar_x, bar_y, bar_current_width, bar_height), Color(0.35, 0.65, 1.0, alpha))

		# Coeur lumineux au centre (plus brillant)
		var core_height := bar_height * 0.5
		var core_y := bar_y + (bar_height - core_height) * 0.5
		draw_rect(Rect2(bar_x, core_y, bar_current_width, core_height), Color(0.7, 0.88, 1.0, alpha * glow_pulse))

		# Ligne centrale ultra brillante
		var center_line_y := bar_y + bar_height * 0.5 - 1
		draw_rect(Rect2(bar_x, center_line_y, bar_current_width, 2), Color(0.95, 0.98, 1.0, alpha * glow_pulse))

		# Reflet en haut
		draw_rect(Rect2(bar_x, bar_y, bar_current_width, 3), Color(1.0, 1.0, 1.0, 0.45 * alpha * glow_pulse))

		# Particules scintillantes le long de la barre
		for i in range(8):
			var spark_x := bar_x + rng.randf() * bar_current_width
			var spark_y := bar_y + rng.randf() * bar_height
			var spark_size := rng.randf_range(1.5, 3.5)
			var spark_alpha := rng.randf() * 0.7 * alpha * glow_pulse
			draw_rect(Rect2(spark_x, spark_y, spark_size, spark_size), Color(0.9, 0.95, 1.0, spark_alpha))

	# Pourcentage avec glow
	if font:
		var percent_text := "%d%%" % int(loading_progress * 100)
		var percent_width := font.get_string_size(percent_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
		var text_pos := Vector2(center_x - percent_width * 0.5, bar_y + bar_height + 28)

		# Glow du texte
		draw_string(font, text_pos + Vector2(-1, -1), percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.3, 0.6, 1.0, alpha * 0.4))
		draw_string(font, text_pos + Vector2(1, 1), percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.3, 0.6, 1.0, alpha * 0.4))
		draw_string(font, text_pos, percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, alpha))


func _draw_boot_logs(viewport_size: Vector2, alpha: float) -> void:
	var log_start_y := viewport_size.y * 0.58
	var line_height := 17
	var log_size := 11
	var margin_x := viewport_size.x * 0.14

	var max_visible := int((viewport_size.y - log_start_y - 25) / line_height)
	var start_idx := maxi(0, visible_logs - max_visible)

	for i in range(start_idx, visible_logs):
		if i >= BOOT_LOGS.size():
			break

		var log_entry: Dictionary = BOOT_LOGS[i]
		var text: String = log_entry.text
		var color_name: String = log_entry.color

		var color: Color
		match color_name:
			"green": color = COLOR_GREEN
			"amber": color = COLOR_AMBER
			"cyan": color = COLOR_CYAN
			_: color = COLOR_WHITE

		var line_alpha := alpha
		if i >= visible_logs - 2:
			line_alpha *= 0.7 + 0.3 * sin(time_elapsed * 7.0)

		var h_offset := sin(h_distort_phase + float(i) * 0.4) * 1.2
		var y_pos := log_start_y + float(i - start_idx) * line_height

		draw_string(font, Vector2(margin_x + h_offset, y_pos), text, HORIZONTAL_ALIGNMENT_LEFT, -1, log_size, Color(color.r, color.g, color.b, line_alpha * 0.9))


func _draw_orb_transform(viewport_size: Vector2) -> void:
	if not font:
		return

	var t := orb_transform_progress
	var center := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.4)

	# Phase 1+2: Draw falling/converging pixel rain
	if t < 0.85:
		for px in _rain_pixels:
			var sparkle := 0.5 + 0.5 * sin(px.sparkle_phase)
			var alpha := clampf(sparkle, 0.3, 1.0)
			# Glow halo around each pixel
			var glow_size: float = px.size * 2.5
			draw_rect(Rect2(px.pos.x - glow_size * 0.5, px.pos.y - glow_size * 0.5, glow_size, glow_size),
				Color(px.color.r, px.color.g, px.color.b, alpha * 0.15))
			# Core pixel
			draw_rect(Rect2(px.pos.x - px.size * 0.5, px.pos.y - px.size * 0.5, px.size, px.size),
				Color(px.color.r, px.color.g, px.color.b, alpha))

	# Phase 3 (0.85-1.0): Bright flash expanding from center
	if t >= 0.85:
		var flash_t := (t - 0.85) / 0.15
		var flash_alpha := 1.0 - flash_t * 0.3  # Stay bright
		var flash_radius := flash_t * maxf(viewport_size.x, viewport_size.y)
		# Draw expanding white glow circles
		for i in range(5):
			var r := flash_radius * (1.0 - float(i) * 0.15)
			var a := flash_alpha * (1.0 - float(i) * 0.18)
			if r > 0 and a > 0:
				draw_rect(Rect2(center.x - r, center.y - r, r * 2.0, r * 2.0),
					Color(0.95, 0.97, 1.0, a))

	# Title fade out during pixel rain
	var title := "C e l t O S"
	var title_size := 40
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size).x
	var title_alpha := maxf(0.0, 1.0 - t * 2.0)
	if title_alpha > 0:
		draw_string(font, Vector2(viewport_size.x * 0.5 - title_width * 0.5, viewport_size.y * 0.30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(COLOR_AMBER.r, COLOR_AMBER.g, COLOR_AMBER.b, title_alpha))


func _draw_clock_arc(viewport_size: Vector2) -> void:
	# Dessiner le demi-cercle 24h
	var segments := 48
	var arc_alpha := 0.3

	# Arc principal
	for i in range(segments):
		var angle1 := PI - (float(i) / float(segments)) * PI
		var angle2 := PI - (float(i + 1) / float(segments)) * PI

		var p1 := clock_center + Vector2(cos(angle1), -sin(angle1)) * clock_radius
		var p2 := clock_center + Vector2(cos(angle2), -sin(angle2)) * clock_radius

		draw_line(p1, p2, Color(COLOR_BLUE_GLOW.r, COLOR_BLUE_GLOW.g, COLOR_BLUE_GLOW.b, arc_alpha), 2.0)

	# Marqueurs d'heures
	for h in range(25):
		var angle := PI - (float(h) / 24.0) * PI
		var marker_start := clock_center + Vector2(cos(angle), -sin(angle)) * (clock_radius - 8)
		var marker_end := clock_center + Vector2(cos(angle), -sin(angle)) * (clock_radius + 8)

		var marker_alpha := 0.5 if h % 6 == 0 else 0.2
		var marker_width := 2.0 if h % 6 == 0 else 1.0
		draw_line(marker_start, marker_end, Color(COLOR_BLUE_BRIGHT.r, COLOR_BLUE_BRIGHT.g, COLOR_BLUE_BRIGHT.b, marker_alpha), marker_width)

		# Labels pour 0h, 6h, 12h, 18h, 24h
		if h % 6 == 0 and font:
			var label := "%dh" % h
			var label_pos := clock_center + Vector2(cos(angle), -sin(angle)) * (clock_radius + 22)
			var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
			draw_string(font, Vector2(label_pos.x - label_size.x * 0.5, label_pos.y + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, 0.6))


func _draw_orb(viewport_size: Vector2) -> void:
	_draw_orb_at(orb_current_pos, orb_size)

	# Afficher l'heure actuelle
	if font:
		var time_dict := Time.get_time_dict_from_system()
		var time_str := "%02d:%02d" % [time_dict.hour, time_dict.minute]
		var time_size := font.get_string_size(time_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
		var time_pos := Vector2(orb_current_pos.x - time_size.x * 0.5, orb_current_pos.y + orb_size + 25)

		# Glow
		draw_string(font, time_pos + Vector2(-1, -1), time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(COLOR_BLUE_GLOW.r, COLOR_BLUE_GLOW.g, COLOR_BLUE_GLOW.b, 0.5))
		draw_string(font, time_pos, time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(COLOR_BLUE_CORE.r, COLOR_BLUE_CORE.g, COLOR_BLUE_CORE.b, 1.0))


func _draw_orb_at(pos: Vector2, size: float) -> void:
	if size <= 0:
		return

	var glow_pulse := 0.7 + 0.3 * sin(time_elapsed * 3.0)

	# Glow externe
	for i in range(5):
		var glow_size := size * (2.5 - float(i) * 0.3)
		var glow_alpha := 0.15 * (1.0 - float(i) * 0.18) * glow_pulse
		_draw_circle_approx(pos, glow_size, Color(COLOR_BLUE_GLOW.r, COLOR_BLUE_GLOW.g, COLOR_BLUE_GLOW.b, glow_alpha))

	# Orbe principal
	_draw_circle_approx(pos, size, Color(COLOR_BLUE_BRIGHT.r, COLOR_BLUE_BRIGHT.g, COLOR_BLUE_BRIGHT.b, 0.9))

	# Coeur lumineux
	_draw_circle_approx(pos, size * 0.6, Color(COLOR_BLUE_CORE.r, COLOR_BLUE_CORE.g, COLOR_BLUE_CORE.b, 1.0))

	# Reflet
	_draw_circle_approx(pos + Vector2(-size * 0.2, -size * 0.2), size * 0.25, Color(1.0, 1.0, 1.0, 0.5 * glow_pulse))


func _draw_circle_approx(center: Vector2, radius: float, color: Color) -> void:
	# Approximation de cercle avec des lignes
	var steps := maxi(12, int(radius / 2))
	for i in range(steps):
		var angle := float(i) / float(steps) * TAU
		var next_angle := float(i + 1) / float(steps) * TAU
		var p1 := center + Vector2(cos(angle), sin(angle)) * radius
		var p2 := center + Vector2(cos(next_angle), sin(next_angle)) * radius
		draw_line(p1, p2, color, maxf(radius * 0.25, 2.0))


func _draw_retro_overlays(viewport_size: Vector2) -> void:
	# Scanlines
	var y := fmod(scanline_offset, 3.0)
	while y < viewport_size.y:
		draw_rect(Rect2(0, y, viewport_size.x, 1), Color(0, 0, 0, 0.12))
		y += 3.0

	# Rolling band
	if rolling_band_y >= 0.0 and rolling_band_y <= 1.0:
		var band_y := rolling_band_y * viewport_size.y
		draw_rect(Rect2(0, band_y - 12, viewport_size.x, 24), Color(1.0, 1.0, 1.0, 0.06))

	# Grain
	for _i in range(25):
		var gx := rng.randf() * viewport_size.x
		var gy := rng.randf() * viewport_size.y
		var gs := rng.randf_range(1, 3)
		draw_rect(Rect2(gx, gy, gs, gs), Color(1, 1, 1, grain_intensity * rng.randf()))

	# Vignette
	var corner := minf(viewport_size.x, viewport_size.y) * 0.2
	for i in range(int(corner / 4)):
		var va := (1.0 - float(i * 4) / corner) * 0.25
		var d := float(i * 4)
		draw_rect(Rect2(0, 0, viewport_size.x, d), Color(0, 0, 0, va))
		draw_rect(Rect2(0, viewport_size.y - d, viewport_size.x, d), Color(0, 0, 0, va))
		draw_rect(Rect2(0, d, d, viewport_size.y - d * 2), Color(0, 0, 0, va))
		draw_rect(Rect2(viewport_size.x - d, d, d, viewport_size.y - d * 2), Color(0, 0, 0, va))


func _draw_transition(viewport_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0, 0, 0, transition_alpha))

# =============================================================================
# HELPERS
# =============================================================================

func _update_static_shader() -> void:
	if static_material:
		static_material.set_shader_parameter("intensity", static_intensity)


func _update_logo() -> void:
	if logo:
		logo.visible = current_phase == BootPhase.BOOT_SEQUENCE
		logo.modulate = Color(COLOR_AMBER.r, COLOR_AMBER.g, COLOR_AMBER.b, content_alpha * flicker_value)


func _save_orb_data() -> void:
	# Sauvegarder les donnees de l'orbe pour le menu
	var data := {
		"orb_position": orb_current_pos,
		"orb_size": orb_size,
		"current_hour": current_hour,
		"clock_center": clock_center,
		"clock_radius": clock_radius
	}
	Engine.set_meta("intro_orb_data", data)

# =============================================================================
# EASING
# =============================================================================

func _ease_out_expo(t: float) -> float:
	return 1.0 - pow(2.0, -10.0 * t) if t < 1.0 else 1.0

func _ease_out_cubic(t: float) -> float:
	var f := t - 1.0
	return f * f * f + 1.0

func _ease_in_cubic(t: float) -> float:
	return t * t * t

func _ease_in_out_cubic(t: float) -> float:
	if t < 0.5:
		return 4.0 * t * t * t
	else:
		var f := 2.0 * t - 2.0
		return 0.5 * f * f * f + 1.0

# =============================================================================
# NAVIGATION
# =============================================================================

func _go_to_menu() -> void:
	PixelTransition.transition_to("res://scenes/MenuPrincipal.tscn")

# =============================================================================
# AUDIO
# =============================================================================

func _init_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = audio_rate
	stream.buffer_length = 2.0
	audio_player.stream = stream
	audio_player.volume_db = -10.0
	audio_player.play()
	audio_playback = audio_player.get_stream_playback()


func _play_power_on_sound() -> void:
	if audio_playback == null:
		return

	_generate_noise(0.04, 0.1)

	var duration := 1.2
	var samples := int(audio_rate * duration)
	for i in range(samples):
		var t := float(i) / float(samples)
		var freq := lerpf(30.0, 150.0, t * t)
		var env := t * (1.0 - t * 0.3)
		var time_sec := float(i) / float(audio_rate)
		var sample := sin(TAU * freq * time_sec) * 0.05 * env
		sample += sin(TAU * freq * 2.0 * time_sec) * 0.02 * env
		sample += (rng.randf() * 2.0 - 1.0) * 0.03 * env
		audio_playback.push_frame(Vector2(sample, sample))


func _play_static_burst() -> void:
	if audio_playback == null:
		return
	_generate_noise(0.4, 0.12)


func _feed_continuous_noise() -> void:
	if audio_playback == null:
		return

	var frames := audio_playback.get_frames_available()
	if frames <= 0:
		return

	var volume := 0.035 * static_intensity

	for i in range(mini(frames, 1500)):
		var sample := (rng.randf() * 2.0 - 1.0) * volume
		sample += sin(hum_phase + float(i) * TAU * 60.0 / float(audio_rate)) * 0.006
		audio_playback.push_frame(Vector2(sample, sample))


func _play_log_sound() -> void:
	if audio_playback == null:
		return
	_generate_noise(0.012, 0.02)


func _play_orb_sound() -> void:
	if audio_playback == null:
		return

	var duration := 0.8
	var samples := int(audio_rate * duration)
	for i in range(samples):
		var t := float(i) / float(samples)
		var freq := lerpf(200.0, 800.0, t)
		var env := sin(t * PI) * 0.8
		var time_sec := float(i) / float(audio_rate)
		var sample := sin(TAU * freq * time_sec) * 0.04 * env
		sample += sin(TAU * freq * 1.5 * time_sec) * 0.02 * env
		audio_playback.push_frame(Vector2(sample, sample))


func _play_orb_move_sound() -> void:
	if audio_playback == null:
		return

	var duration := 1.0
	var samples := int(audio_rate * duration)
	for i in range(samples):
		var t := float(i) / float(samples)
		var freq := lerpf(300.0, 600.0, sin(t * PI))
		var env := sin(t * PI) * 0.6
		var time_sec := float(i) / float(audio_rate)
		var sample := sin(TAU * freq * time_sec) * 0.03 * env
		sample += (rng.randf() * 2.0 - 1.0) * 0.015 * env
		audio_playback.push_frame(Vector2(sample, sample))


func _generate_noise(duration: float, volume: float) -> void:
	var samples := int(audio_rate * duration)
	var fade := int(audio_rate * 0.01)

	for i in range(samples):
		var env := 1.0
		if i < fade:
			env = float(i) / float(fade)
		elif i > samples - fade:
			env = float(samples - i) / float(fade)

		var sample := (rng.randf() * 2.0 - 1.0) * volume * env
		audio_playback.push_frame(Vector2(sample, sample))
