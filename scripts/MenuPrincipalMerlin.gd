extends Control

# =============================================================================
# MENU PRINCIPAL "PARCHEMIN MYSTIQUE BRETON"
# Design celtique sobre et épuré - Ambiance sanctuaire ancien
# =============================================================================


const TITLE_TEXT := "M  E  R  L  I  N"

const MAIN_MENU_ITEMS := [
	{"text": "Nouvelle Partie", "scene": "res://scenes/IntroPersonalityQuiz.tscn"},
	{"text": "Continuer", "scene": "res://scenes/SelectionSauvegarde.tscn"},
	{"text": "Options", "scene": "res://scenes/MenuOptions.tscn"},
	{"text": "Quitter", "scene": "__quit__"},
]

# Ornements celtiques (ASCII-safe — TextServerFallback compatible)
const CELTIC_ORNAMENTS := {
	"triskel": "*",            # Was U+2618
	"spiral": "@",             # Was U+25CE
	"knot_simple": "+",        # Was U+274B
	"diamond": "<>",           # Was U+25C6
	"dot": ".",                # Was U+2022
	"line_h": "-",             # Was U+2500
	"corner_tl": "+",          # Was U+256D
	"corner_tr": "+",          # Was U+256E
	"corner_bl": "+",          # Was U+2570
	"corner_br": "+",          # Was U+256F
}

const CORNER_BUTTON_SIZE := Vector2(52, 52)
const CORNER_BUTTON_MARGIN := 28
const CARD_MAX_WIDTH := 480.0
const CARD_MAX_HEIGHT := 520.0
const COLLECTION_SCENE := "res://scenes/Collection.tscn"
const CALENDAR_SCENE := "res://scenes/Calendar.tscn"
const CONFIG_PATH := "user://settings.cfg"

# Calendar settings
var calendar_override := false
var calendar_day := 1
var calendar_month := 1
var calendar_year := 2026

# Scene nodes (from MenuPrincipal.tscn)
@onready var parchment_background: ColorRect = $ParchmentBg
@onready var mist_layer: ColorRect = $MistLayer
@onready var celtic_ornament_top: Label = $CelticOrnamentTop
@onready var celtic_ornament_bottom: Label = $CelticOrnamentBottom
@onready var card: PanelContainer = $Card
@onready var card_contents: VBoxContainer = $Card/CardContents
@onready var main_buttons: VBoxContainer = $Card/CardContents/MainButtons
@onready var title_label: Label = $Card/CardContents/Title
@onready var _sep_left: ColorRect = $Card/CardContents/SeparatorContainer/SepLeft
@onready var _sep_diamond: Label = $Card/CardContents/SeparatorContainer/SepDiamond
@onready var _sep_right: ColorRect = $Card/CardContents/SeparatorContainer/SepRight
@onready var calendar_button: Button = $CalendarButton
@onready var collections_button: Button = $CollectionsButton
@onready var clock_label: Label = $ClockLabel

# Runtime state
var _corner_hover_tweens: Dictionary = {}
var _last_minute: int = -1

# Fonts
var title_font: Font
var body_font: Font
var celtic_font: Font

# Animation state
var card_target_pos := Vector2.ZERO
var swipe_in_progress := false
var swipe_tween: Tween
var _entry_tween: Tween
var _mist_tween: Tween

# Voice calibration
var _voice_panel: CanvasLayer
var _voice_vb: Node  # ACVoicebox instance
var _voice_pitch_slider: HSlider
var _voice_variation_slider: HSlider
var _voice_speed_slider: HSlider
var _voice_test_label: RichTextLabel
var _llm_test_badge: PanelContainer
var _voice_pitch_value: Label
var _voice_variation_value: Label
var _voice_speed_value: Label

# Particle landing sound counter (avoid audio spam)
var _particle_land_count: int = 0

# Custom cursor
var _custom_cursor: Control

# LLM status indicator
var _ai_status_label: Label

# Pixel art landscape
var _pixel_bg_layer: Control
var _pixel_bg_pixels: Array[Dictionary] = []  # {node, target_pos, is_window}
var _tower_windows: Array[ColorRect] = []
var _tower_rays: Array[ColorRect] = []
var _assembly_done := false
var _tower_glow_tween: Tween

# Season for atmosphere
var current_season := "HIVER"

# =============================================================================
# TIME-OF-DAY LIGHTING
# =============================================================================

# Tint profiles: each hour range has a target color overlay
# Using custom colors for atmospheric time-of-day effects
const TIME_TINTS := {
	"night":   Color(0.10, 0.12, 0.25, 0.35),   # Deep night blue
	"dawn":    Color(0.45, 0.28, 0.15, 0.20),   # Golden rose dawn
	"morning": Color(0.95, 0.90, 0.80, 0.05),   # Soft morning light
	"midday":  Color(1.0, 1.0, 0.95, 0.0),      # Neutral, nearly invisible
	"afternoon": Color(0.90, 0.82, 0.65, 0.08), # Warm afternoon light
	"dusk":    Color(0.55, 0.25, 0.10, 0.25),   # Amber twilight
	"evening": Color(0.20, 0.15, 0.28, 0.30),   # Violet evening
}

var time_tint_layer: ColorRect
var _time_tint_tween: Tween

# =============================================================================
# SEASONAL EFFECTS — Universal accumulation system
# =============================================================================

# Falling particles (all seasons except summer)
var _falling_particles: Array[Dictionary] = []  # {node, speed, drift, time_offset}
var _fall_timer: float = 0.0

# Accumulation grid — deposits form wherever particles land
# Each cell = column of N pixels wide, tracks accumulated height
var _accum_grid: Array[float] = []         # height per column
var _accum_nodes: Array[ColorRect] = []    # visual node per column
const ACCUM_CELL_WIDTH := 12              # pixels per grid column
const ACCUM_MAX_HEIGHT := 600.0           # can cover entire screen eventually
const ACCUM_GROW_PER_PARTICLE := 0.15     # very slow growth per landed particle
var _accum_container: Control              # parent node for accumulation visuals

# Season-specific tuning - custom atmospheric colors
const SEASON_CONFIG := {
	"HIVER": {
		"spawn_interval": 0.25,     # slow, contemplative snowfall
		"max_particles": 80,
		"size_min": 2.0, "size_max": 5.0,
		"speed_min": 12.0, "speed_max": 35.0,  # very slow fall
		"drift": 10.0,
		"color_base": Color(0.95, 0.96, 1.0, 0.8),  # Snow white with blue tint
		"color_var": 0.05,
		"accum_color": Color(0.94, 0.95, 1.0, 0.9),  # Snow accumulation
		"accum_grow": 0.12,    # very slow pile growth
		"round": true,
	},
	"AUTOMNE": {
		"spawn_interval": 0.6,     # sparse leaves
		"max_particles": 35,
		"size_min": 5.0, "size_max": 11.0,
		"speed_min": 15.0, "speed_max": 40.0,
		"drift": 25.0,
		"color_base": Color(0.85, 0.45, 0.15, 0.85),  # Autumn leaf orange/brown
		"color_var": 0.25,
		"accum_color": Color(0.65, 0.35, 0.12, 0.75),  # Fallen leaves pile
		"accum_grow": 0.10,
		"round": false,
	},
	"PRINTEMPS": {
		"spawn_interval": 0.5,
		"max_particles": 40,
		"size_min": 3.0, "size_max": 7.0,
		"speed_min": 10.0, "speed_max": 28.0,  # very gentle
		"drift": 18.0,
		"color_base": Color(1.0, 0.78, 0.85, 0.7),  # Spring blossom pink
		"color_var": 0.15,
		"accum_color": Color(0.95, 0.80, 0.85, 0.6),  # Petal accumulation
		"accum_grow": 0.08,
		"round": true,
	},
}

# Summer sun rays
var _sun_rays: Array[ColorRect] = []
var _sun_ray_timer: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_calendar_settings()
	_determine_season()
	_load_fonts()
	_build_pixel_landscape()
	_configure_background()
	_configure_celtic_ornaments()
	_configure_clock()
	_configure_main_ui()
	_configure_corner_buttons()
	_apply_theme()
	_build_time_tint_layer()
	_build_seasonal_effects()
	_build_custom_cursor()
	_layout_ui()
	resized.connect(_on_resized)
	_play_entry_animation.call_deferred()
	_start_mist_animation()
	# Eager LLM warmup — start loading both brains immediately in background
	call_deferred("_start_llm_warmup_background")
	_build_ai_status_indicator()
	_apply_pixel_dither()


func _apply_pixel_dither() -> void:
	## Apply full-screen pixel dither post-process for retro aesthetic.
	var dither_layer := CanvasLayer.new()
	dither_layer.layer = 100
	add_child(dither_layer)
	var dither_rect := ColorRect.new()
	dither_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dither_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/screen_dither.gdshader")
	mat.set_shader_parameter("color_levels", 8.0)
	mat.set_shader_parameter("dither_strength", 0.35)
	mat.set_shader_parameter("pixel_scale", 2.0)
	mat.set_shader_parameter("intensity", 0.6)
	dither_rect.material = mat
	dither_layer.add_child(dither_rect)


func _load_calendar_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err == OK:
		calendar_override = config.get_value("calendar", "override", false)
		calendar_day = config.get_value("calendar", "day", 1)
		calendar_month = config.get_value("calendar", "month", 1)
		calendar_year = config.get_value("calendar", "year", 2026)


func _get_current_date() -> Dictionary:
	if calendar_override:
		return {"day": calendar_day, "month": calendar_month, "year": calendar_year}
	return Time.get_date_dict_from_system()


func _determine_season() -> void:
	var date := _get_current_date()
	var month: int = date.month
	if month >= 3 and month <= 5:
		current_season = "PRINTEMPS"
	elif month >= 6 and month <= 8:
		current_season = "ETE"
	elif month >= 9 and month <= 11:
		current_season = "AUTOMNE"
	else:
		current_season = "HIVER"


func _load_fonts() -> void:
	# Morris Roman pour l'élégance celtique
	title_font = _load_font("res://resources/fonts/morris/MorrisRomanBlack.otf")
	if title_font == null:
		title_font = _load_font("res://resources/fonts/morris/MorrisRomanBlack.ttf")
	body_font = _load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.otf")
	if body_font == null:
		body_font = _load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf")
	if body_font == null:
		body_font = title_font
	# Celtic font for ornaments
	celtic_font = _load_font("res://resources/fonts/celtic_bit/celtic-bit.ttf")
	if celtic_font == null:
		celtic_font = body_font


func _load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var f: Resource = load(path)
	if f is Font:
		return f
	return ThemeDB.fallback_font



# =============================================================================
# FOND PARCHEMIN MYSTIQUE
# =============================================================================

func _configure_background() -> void:
	# CRT terminal background
	parchment_background.material = null
	parchment_background.color = MerlinVisual.CRT_PALETTE.bg_dark
	parchment_background.modulate.a = 1.0
	# Mist layer
	mist_layer.color = MerlinVisual.CRT_PALETTE.mist


# =============================================================================
# PIXEL ART LANDSCAPE — Broceliande with Merlin's Tower
# =============================================================================

const PX_GRID_W := 32
const PX_GRID_H := 16

func _px_grid_set(g: Array, x: int, y: int, c: int) -> void:
	if y >= 0 and y < PX_GRID_H and x >= 0 and x < PX_GRID_W:
		g[y][x] = c


func _px_grid_rect(g: Array, x0: int, y0: int, w: int, h: int, c: int) -> void:
	for dy in range(h):
		for dx in range(w):
			_px_grid_set(g, x0 + dx, y0 + dy, c)


func _px_grid_triangle(g: Array, cx: int, top_y: int, base_y: int, max_w: int, c: int) -> void:
	if base_y <= top_y:
		return
	var height := base_y - top_y
	for dy in range(height + 1):
		var y := top_y + dy
		var t := float(dy) / float(height)
		var half := int(t * float(max_w) / 2.0)
		for dx in range(-half, half + 1):
			_px_grid_set(g, cx + dx, y, c)


func _px_grid_dots(g: Array, positions: Array, c: int) -> void:
	for pos in positions:
		_px_grid_set(g, pos[0], pos[1], c)


func _generate_menu_landscape() -> Array:
	## Generate 32x16 pixel art grid: Broceliande forest with Merlin's tower center.
	var g: Array = []
	for y in range(PX_GRID_H):
		var row: Array = []
		for x in range(PX_GRID_W):
			row.append(0)
		g.append(row)

	# --- TOWER (center, cols 14-17) ---
	# Spire (accent color)
	_px_grid_rect(g, 15, 1, 2, 2, 3)
	# Roof (triangular, primary color)
	_px_grid_rect(g, 13, 3, 6, 2, 1)
	_px_grid_rect(g, 14, 2, 4, 1, 1)
	# Tower body (secondary color)
	_px_grid_rect(g, 14, 5, 4, 5, 2)
	# Windows (color 4 = golden glow)
	_px_grid_set(g, 14, 6, 4)
	_px_grid_set(g, 17, 6, 4)
	_px_grid_set(g, 14, 8, 4)
	_px_grid_set(g, 17, 8, 4)
	# Tower base (wider, primary)
	_px_grid_rect(g, 13, 10, 6, 2, 1)

	# --- FOREST (left and right of tower) ---
	# Left trees
	_px_grid_triangle(g, 4, 4, 9, 8, 1)
	_px_grid_rect(g, 3, 10, 2, 2, 2)
	_px_grid_triangle(g, 9, 5, 9, 6, 1)
	_px_grid_rect(g, 8, 10, 2, 2, 2)
	# Right trees
	_px_grid_triangle(g, 22, 5, 9, 6, 1)
	_px_grid_rect(g, 21, 10, 2, 2, 2)
	_px_grid_triangle(g, 27, 4, 9, 8, 1)
	_px_grid_rect(g, 26, 10, 2, 2, 2)

	# --- GROUND ---
	_px_grid_rect(g, 0, 12, PX_GRID_W, 2, 2)

	# --- DETAILS (mushrooms, flowers) ---
	_px_grid_dots(g, [[1, 14], [6, 14], [11, 14], [20, 14], [25, 14], [30, 14]], 3)

	return g


func _build_pixel_landscape() -> void:
	## Build pixel art landscape layer with falling assembly animation.
	_pixel_bg_layer = Control.new()
	_pixel_bg_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pixel_bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pixel_bg_layer.z_index = -1
	add_child(_pixel_bg_layer)

	var grid: Array = _generate_menu_landscape()

	var colors: Dictionary = MerlinVisual.BIOME_COLORS.get("broceliande", {})
	var primary_color: Color = colors.get("primary", Color(0.18, 0.42, 0.22))
	var secondary_color: Color = colors.get("secondary", Color(0.35, 0.55, 0.28))
	var accent_color: Color = colors.get("accent", Color(0.62, 0.78, 0.42))
	var window_color: Color = MerlinVisual.CRT_PALETTE.get("amber_bright", Color(0.68, 0.55, 0.32))

	var color_map := {
		1: primary_color,
		2: secondary_color,
		3: accent_color,
		4: window_color,
	}

	# Calculate pixel size (fill ~70% of viewport width)
	var vs := get_viewport_rect().size
	if vs.x < 1.0:
		vs = Vector2(1152, 648)
	var pixel_size: float = floor(vs.x * 0.70 / float(PX_GRID_W))
	pixel_size = clampf(pixel_size, 8.0, 18.0)

	var total_w: float = float(PX_GRID_W) * pixel_size
	var total_h: float = float(PX_GRID_H) * pixel_size
	var origin := Vector2(
		(vs.x - total_w) / 2.0,
		vs.y - total_h - 20.0  # Anchored near bottom
	)

	_pixel_bg_pixels.clear()
	_tower_windows.clear()

	for row in range(PX_GRID_H):
		for col in range(PX_GRID_W):
			var c: int = grid[row][col]
			if c <= 0 or not color_map.has(c):
				continue
			var target_pos := origin + Vector2(col * pixel_size, row * pixel_size)
			var spawn_y := -20.0 - randf_range(0.0, vs.y * 0.6)
			var spawn_x := target_pos.x + randf_range(-20.0, 20.0)

			var px := ColorRect.new()
			px.size = Vector2(pixel_size, pixel_size)
			px.position = Vector2(spawn_x, spawn_y)
			px.color = color_map[c]
			px.modulate.a = 0.0
			px.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_pixel_bg_layer.add_child(px)

			var is_window := c == 4
			_pixel_bg_pixels.append({"node": px, "target_pos": target_pos, "is_window": is_window})
			if is_window:
				_tower_windows.append(px)



func _animate_pixel_assembly() -> void:
	## Animate pixels falling from sky and assembling into landscape.
	if _assembly_done:
		return
	_assembly_done = true

	# Sort by column for wave cascade effect
	var sorted: Array = _pixel_bg_pixels.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ac: float = a.target_pos.x
		var bc: float = b.target_pos.x
		if absf(ac - bc) > 1.0:
			return ac < bc
		return a.target_pos.y > b.target_pos.y
	)

	var sfx := get_node_or_null("/root/SFXManager")

	for i in range(sorted.size()):
		var entry: Dictionary = sorted[i]
		var px: ColorRect = entry.node
		if not is_instance_valid(px):
			continue
		var target: Vector2 = entry.target_pos

		var tw := create_tween()
		tw.tween_property(px, "modulate:a", 1.0, 0.08)
		tw.parallel().tween_property(px, "position", target, randf_range(0.30, 0.55)) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

		if i % 5 == 4:
			if sfx and sfx.has_method("play_varied"):
				sfx.play_varied("blip", 0.12)
			await get_tree().create_timer(0.025).timeout

	# Brief flash pulse when assembled
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(_pixel_bg_layer):
		var pulse := create_tween()
		pulse.tween_property(_pixel_bg_layer, "modulate", Color(1.15, 1.15, 1.15), 0.15)
		pulse.tween_property(_pixel_bg_layer, "modulate", Color.WHITE, 0.15)
		await pulse.finished

	_start_tower_glow()


func _start_tower_glow() -> void:
	## Create light rays above tower and pulse window glow.
	if not is_instance_valid(_pixel_bg_layer):
		return

	var vs := get_viewport_rect().size
	if vs.x < 1.0:
		vs = Vector2(1152, 648)
	var pixel_size: float = floor(vs.x * 0.70 / float(PX_GRID_W))
	pixel_size = clampf(pixel_size, 8.0, 18.0)
	var total_h: float = float(PX_GRID_H) * pixel_size
	var origin_y: float = vs.y - total_h - 20.0
	var tower_cx: float = (vs.x - float(PX_GRID_W) * pixel_size) / 2.0 + 16.0 * pixel_size
	var tower_top_y: float = origin_y

	# 3 volumetric light rays fanning upward
	var ray_color: Color = MerlinVisual.CRT_PALETTE.get("amber_bright", Color(0.68, 0.55, 0.32))
	for i in range(3):
		var ray := ColorRect.new()
		ray.size = Vector2(3.0, 70.0)
		ray.position = Vector2(tower_cx - 8.0 + float(i) * 8.0, tower_top_y - 70.0)
		ray.color = Color(ray_color.r, ray_color.g, ray_color.b, 0.15)
		ray.rotation = -0.08 + float(i) * 0.08
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pixel_bg_layer.add_child(ray)
		_tower_rays.append(ray)

	# Pulse tweens
	if _tower_glow_tween:
		_tower_glow_tween.kill()
	_tower_glow_tween = create_tween().set_loops()

	# Window brightness pulse
	for win in _tower_windows:
		if is_instance_valid(win):
			_tower_glow_tween.parallel().tween_property(win, "modulate", Color(1.5, 1.4, 1.1), 2.0) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Ray opacity pulse
	for ray in _tower_rays:
		if is_instance_valid(ray):
			_tower_glow_tween.parallel().tween_property(ray, "modulate:a", 0.35, 2.0) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tower_glow_tween.tween_interval(0.0)

	for win in _tower_windows:
		if is_instance_valid(win):
			_tower_glow_tween.parallel().tween_property(win, "modulate", Color.WHITE, 2.0) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for ray in _tower_rays:
		if is_instance_valid(ray):
			_tower_glow_tween.parallel().tween_property(ray, "modulate:a", 0.12, 2.0) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# NOTE: mist_layer color is applied in _configure_background()


func _start_mist_animation() -> void:
	# Animation subtile de la brume (respiration douce)
	if _mist_tween:
		_mist_tween.kill()
	_mist_tween = create_tween().set_loops()
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.25, 8.0).set_trans(Tween.TRANS_SINE)
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.08, 8.0).set_trans(Tween.TRANS_SINE)


# =============================================================================
# ORNEMENTS CELTIQUES
# =============================================================================

func _configure_celtic_ornaments() -> void:
	var line_text := _create_celtic_line(40)
	celtic_ornament_top.text = line_text
	celtic_ornament_top.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)
	celtic_ornament_top.position = Vector2(0, 50)
	celtic_ornament_bottom.text = line_text
	celtic_ornament_bottom.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)


func _create_celtic_line(length: int) -> String:
	# Crée une ligne décorative celtique sobre
	var line := ""
	var pattern := ["\u2500", "\u2022", "\u2500", "\u2500", "\u25c6", "\u2500", "\u2500", "\u2022", "\u2500"]
	for i in range(length):
		line += pattern[i % pattern.size()]
	return line


func _layout_celtic_ornaments(viewport_size: Vector2) -> void:
	if celtic_ornament_top:
		celtic_ornament_top.size = Vector2(viewport_size.x, 30)
		celtic_ornament_top.position = Vector2(0, 45)

	if celtic_ornament_bottom:
		celtic_ornament_bottom.size = Vector2(viewport_size.x, 30)
		celtic_ornament_bottom.position = Vector2(0, viewport_size.y - 75)


# =============================================================================
# HORLOGE DIGITALE
# =============================================================================

const MONTH_NAMES := [
	"", "Genver", "C'hwevrer", "Meurzh", "Ebrel", "Mae", "Mezheven",
	"Gouere", "Eost", "Gwengolo", "Here", "Du", "Kerzu"
]

const DAY_NAMES := [
	"Sul", "Lun", "Meurzh", "Merc'her", "Yaou", "Gwener", "Sadorn"
]


func _configure_clock() -> void:
	_update_clock_text()


func _process(delta: float) -> void:
	var time_dict := Time.get_time_dict_from_system()
	var minute: int = time_dict.minute
	if minute != _last_minute:
		_update_clock_text()
		_update_time_tint()
		_last_minute = minute

	# Seasonal particle systems
	_process_seasonal_effects(delta)


func _update_clock_text() -> void:
	if not clock_label:
		return
	var time_dict := Time.get_time_dict_from_system()
	var date_dict := _get_current_date()
	var weekday: int = Time.get_date_dict_from_system().weekday
	var day_name: String = DAY_NAMES[weekday]
	var month_name: String = MONTH_NAMES[date_dict.month]
	var time_str := "%02d:%02d" % [time_dict.hour, time_dict.minute]
	clock_label.text = "%s. %d %s\n%s" % [
		day_name, date_dict.day, month_name, time_str
	]


func _apply_clock_style() -> void:
	if not clock_label:
		return
	if body_font:
		clock_label.add_theme_font_override("font", body_font)
	clock_label.add_theme_font_size_override("font_size", 28)
	clock_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)


func _layout_clock() -> void:
	if clock_label:
		clock_label.position = Vector2(CORNER_BUTTON_MARGIN, 16)
		clock_label.size = Vector2(320, 80)


# =============================================================================
# UI PRINCIPALE
# =============================================================================

func _configure_main_ui() -> void:
	# Separator colors (runtime palette)
	_sep_left.color = MerlinVisual.CRT_PALETTE.line
	_sep_diamond.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	_sep_right.color = MerlinVisual.CRT_PALETTE.line

	# Populate menu buttons (data-driven from MAIN_MENU_ITEMS)
	for item in MAIN_MENU_ITEMS:
		var btn := _create_button(item.text, item.scene, true)
		main_buttons.add_child(btn)


func _configure_corner_buttons() -> void:
	calendar_button.pressed.connect(_on_calendar_pressed)
	calendar_button.mouse_entered.connect(func(): _on_corner_button_hover(calendar_button, true))
	calendar_button.mouse_exited.connect(func(): _on_corner_button_hover(calendar_button, false))
	collections_button.pressed.connect(_on_collections_pressed)
	collections_button.mouse_entered.connect(func(): _on_corner_button_hover(collections_button, true))
	collections_button.mouse_exited.connect(func(): _on_corner_button_hover(collections_button, false))


# =============================================================================
# THÈME ET STYLES
# =============================================================================

func _apply_theme() -> void:
	var menu_theme := Theme.new()

	# Style carte - parchemin élégant avec bordure fine
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
	card_style.border_color = MerlinVisual.CRT_PALETTE.border
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_left = 4
	card_style.corner_radius_bottom_right = 4
	card_style.shadow_color = MerlinVisual.CRT_PALETTE.shadow
	card_style.shadow_size = 16
	card_style.shadow_offset = Vector2(0, 4)
	card_style.content_margin_left = 36
	card_style.content_margin_top = 32
	card_style.content_margin_right = 36
	card_style.content_margin_bottom = 32
	menu_theme.set_stylebox("panel", "PanelContainer", card_style)

	# Style boutons - minimaliste, élégant
	var btn_normal := StyleBoxFlat.new()
	var white_base: Color = MerlinVisual.GBC.white
	var black_base: Color = MerlinVisual.GBC.black
	btn_normal.bg_color = Color(white_base.r, white_base.g, white_base.b, 0.0)
	btn_normal.border_color = Color(black_base.r, black_base.g, black_base.b, 0.0)
	btn_normal.content_margin_left = 16
	btn_normal.content_margin_top = 14
	btn_normal.content_margin_right = 16
	btn_normal.content_margin_bottom = 14

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = MerlinVisual.CRT_PALETTE.phosphor_glow
	btn_hover.border_color = MerlinVisual.CRT_PALETTE.amber
	btn_hover.border_width_bottom = 1
	btn_hover.corner_radius_top_left = 2
	btn_hover.corner_radius_top_right = 2
	btn_hover.corner_radius_bottom_left = 2
	btn_hover.corner_radius_bottom_right = 2
	btn_hover.content_margin_left = 16
	btn_hover.content_margin_top = 14
	btn_hover.content_margin_right = 16
	btn_hover.content_margin_bottom = 14

	var btn_pressed := btn_hover.duplicate()
	var accent_color: Color = MerlinVisual.CRT_PALETTE.amber
	btn_pressed.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.15)

	menu_theme.set_stylebox("normal", "Button", btn_normal)
	menu_theme.set_stylebox("hover", "Button", btn_hover)
	menu_theme.set_stylebox("pressed", "Button", btn_pressed)
	menu_theme.set_stylebox("focus", "Button", btn_hover)
	menu_theme.set_stylebox("disabled", "Button", btn_normal)

	menu_theme.set_color("font_color", "Button", MerlinVisual.CRT_PALETTE.phosphor)
	menu_theme.set_color("font_hover_color", "Button", MerlinVisual.CRT_PALETTE.amber)
	menu_theme.set_color("font_pressed_color", "Button", MerlinVisual.CRT_PALETTE.amber)
	menu_theme.set_color("font_disabled_color", "Button", MerlinVisual.CRT_PALETTE.border)

	menu_theme.set_color("font_color", "Label", MerlinVisual.CRT_PALETTE.phosphor)

	self.theme = menu_theme

	# Style titre
	if title_label and title_font:
		title_label.add_theme_font_override("font", title_font)
		title_label.add_theme_font_size_override("font_size", 52)
		title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)

	# Style boutons menu
	for btn in main_buttons.get_children():
		if btn is Button and body_font:
			btn.add_theme_font_override("font", body_font)
			btn.add_theme_font_size_override("font_size", 22)
			btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Style boutons coins
	_apply_corner_button_style(calendar_button)
	_apply_corner_button_style(collections_button)

	# Style horloge
	_apply_clock_style()


func _apply_corner_button_style(btn: Button) -> void:
	if btn:
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
		btn.pivot_offset = CORNER_BUTTON_SIZE * 0.5


# =============================================================================
# CUSTOM CURSOR
# =============================================================================

func _build_custom_cursor() -> void:
	var cursor_script: GDScript = load("res://scripts/ui/custom_cursor.gd")
	if not cursor_script:
		return
	_custom_cursor = Control.new()
	_custom_cursor.set_script(cursor_script)
	_custom_cursor.set_palette(MerlinVisual.CRT_PALETTE.phosphor, MerlinVisual.CRT_PALETTE.phosphor_dim)
	add_child(_custom_cursor)


# =============================================================================
# ANIMATIONS
# =============================================================================

func _play_entry_animation() -> void:
	if not card:
		return

	# Start pixel assembly in parallel
	_animate_pixel_assembly()

	var sfx := get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("scene_transition")

	# État initial: carte invisible, légèrement en bas
	card.position.y = card_target_pos.y + 40
	card.modulate.a = 0.0

	# Ornements invisibles
	if celtic_ornament_top:
		celtic_ornament_top.modulate.a = 0.0
	if celtic_ornament_bottom:
		celtic_ornament_bottom.modulate.a = 0.0

	# Boutons invisibles
	for btn in main_buttons.get_children():
		if btn is Button:
			btn.modulate.a = 0.0

	# Animation d'entrée douce et élégante
	if _entry_tween:
		_entry_tween.kill()
	_entry_tween = create_tween()

	# Fade in des ornements
	_entry_tween.tween_property(celtic_ornament_top, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	_entry_tween.parallel().tween_property(celtic_ornament_bottom, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)

	# Entrée de la carte
	_entry_tween.tween_property(card, "position:y", card_target_pos.y, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_entry_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)

	# Apparition des boutons en cascade
	_entry_tween.tween_callback(func(): _animate_buttons_entry())


func _animate_buttons_entry() -> void:
	var sfx := get_node_or_null("/root/SFXManager")
	var delay := 0.0
	for btn in main_buttons.get_children():
		if btn is Button:
			var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_interval(delay)
			tween.tween_callback(func():
				if sfx and sfx.has_method("play_varied"):
					sfx.play_varied("button_appear", 0.15)
			)
			tween.tween_property(btn, "modulate:a", 1.0, 0.3)
			delay += 0.05


func _create_button(label: String, scene: String, _is_primary: bool) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = false
	btn.pressed.connect(func(): _on_menu_action(scene))
	btn.mouse_entered.connect(func(): _on_button_hover(btn, true))
	btn.mouse_exited.connect(func(): _on_button_hover(btn, false))
	return btn


func _on_button_hover(btn: Button, hovering: bool) -> void:
	if hovering:
		_play_ui_sound("hover")
		var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", Vector2(1.02, 1.02), 0.15)
	else:
		var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)


func _on_corner_button_hover(btn: Button, hovering: bool) -> void:
	if _corner_hover_tweens.has(btn) and _corner_hover_tweens[btn]:
		_corner_hover_tweens[btn].kill()
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_corner_hover_tweens[btn] = tween
	if hovering:
		tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.2)
		btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	else:
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
		btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)


# =============================================================================
# LAYOUT
# =============================================================================

func _layout_ui() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	var card_w: float = minf(CARD_MAX_WIDTH, viewport_size.x * 0.85)
	var card_h: float = minf(CARD_MAX_HEIGHT, viewport_size.y * 0.72)
	var content_min: Vector2 = card_contents.get_combined_minimum_size()
	if content_min.y > 0.0:
		var max_h: float = minf(CARD_MAX_HEIGHT, viewport_size.y * 0.88)
		card_h = minf(maxf(card_h, content_min.y + 48.0), max_h)
	card.size = Vector2(card_w, card_h)
	card.position = (viewport_size - card.size) * 0.5
	card.pivot_offset = card.size * 0.5
	card_target_pos = card.position

	_layout_corner_buttons(viewport_size)
	_layout_celtic_ornaments(viewport_size)
	_layout_clock()
	if _ai_status_label:
		_ai_status_label.position = Vector2(viewport_size.x - 212, viewport_size.y - 28)


func _layout_corner_buttons(viewport_size: Vector2) -> void:
	if calendar_button:
		calendar_button.position = Vector2(
			CORNER_BUTTON_MARGIN,
			viewport_size.y - CORNER_BUTTON_SIZE.y - CORNER_BUTTON_MARGIN
		)
		calendar_button.size = CORNER_BUTTON_SIZE

	if collections_button:
		collections_button.position = Vector2(
			viewport_size.x - CORNER_BUTTON_SIZE.x - CORNER_BUTTON_MARGIN,
			viewport_size.y - CORNER_BUTTON_SIZE.y - CORNER_BUTTON_MARGIN
		)
		collections_button.size = CORNER_BUTTON_SIZE


# =============================================================================
# ACTIONS
# =============================================================================

func _on_menu_action(scene: String) -> void:
	_play_ui_sound("click")
	if scene == "__quit__":
		get_tree().quit()
		return
	if scene == "__voice_llm_test__":
		_show_voice_llm_panel()
		return
	if scene == "" or swipe_in_progress:
		return

	# Trigger LLM warm-up for game sessions (not Calendar/Collection)
	var game_scenes := ["res://scenes/IntroPersonalityQuiz.tscn", "res://scenes/SelectionSauvegarde.tscn"]
	if scene in game_scenes:
		_start_llm_warmup()

	swipe_in_progress = true
	_play_ui_sound("whoosh")

	var dir := 1.0
	if card:
		var mouse_pos := get_viewport().get_mouse_position()
		var card_center := card.global_position + card.size * 0.5
		if mouse_pos.x < card_center.x:
			dir = -1.0
	_play_swipe(dir)
	_fade_music_out(3.0)
	await get_tree().create_timer(0.25).timeout
	_store_return_scene()
	PixelTransition.transition_to(scene)


func _on_calendar_pressed() -> void:
	if swipe_in_progress:
		return
	swipe_in_progress = true
	_play_swipe(-1.0)
	_fade_music_out(3.0)
	await get_tree().create_timer(0.25).timeout
	_store_return_scene()
	PixelTransition.transition_to(CALENDAR_SCENE)


func _on_collections_pressed() -> void:
	if swipe_in_progress:
		return
	swipe_in_progress = true
	_play_swipe(1.0)
	_fade_music_out(3.0)
	await get_tree().create_timer(0.25).timeout
	_store_return_scene()
	PixelTransition.transition_to(COLLECTION_SCENE)


func _fade_music_out(duration: float) -> void:
	var mm := get_node_or_null("/root/MusicManager")
	if mm:
		mm.fade_out(duration)


func _build_ai_status_indicator() -> void:
	## Discreet AI status label in bottom-right corner.
	_ai_status_label = Label.new()
	_ai_status_label.name = "AIStatus"
	_ai_status_label.text = "IA: ..."
	_ai_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ai_status_label.add_theme_font_size_override("font_size", 11)
	_ai_status_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)
	if body_font:
		_ai_status_label.add_theme_font_override("font", body_font)
	add_child(_ai_status_label)
	# Position bottom-right
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_ai_status_label.size = Vector2(200, 20)
	_ai_status_label.position = Vector2(vp_size.x - 212, vp_size.y - 28)
	# Connect to MerlinAI signals
	var mai := get_node_or_null("/root/MerlinAI")
	if mai == null:
		_ai_status_label.text = "IA: offline"
		return
	if mai.is_ready:
		_ai_status_label.text = "IA: %d cerveaux" % mai.brain_count
		_ai_status_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_dim)
	if mai.has_signal("status_changed"):
		mai.status_changed.connect(_on_ai_status_changed)
	if mai.has_signal("ready_changed"):
		mai.ready_changed.connect(_on_ai_ready_changed)


func _on_ai_status_changed(status_text: String, _detail: String, _progress: float) -> void:
	if _ai_status_label and is_instance_valid(_ai_status_label):
		_ai_status_label.text = "IA: " + status_text.substr(0, 24)


func _on_ai_ready_changed(is_ai_ready: bool) -> void:
	if not _ai_status_label or not is_instance_valid(_ai_status_label):
		return
	if is_ai_ready:
		var mai := get_node_or_null("/root/MerlinAI")
		var bc: int = mai.brain_count if mai else 0
		_ai_status_label.text = "IA: %d cerveaux" % bc
		_ai_status_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_dim)
		# Subtle fade-in accent
		var tw := create_tween()
		_ai_status_label.modulate.a = 0.3
		tw.tween_property(_ai_status_label, "modulate:a", 1.0, 0.5)


func _start_llm_warmup_background() -> void:
	## Silent warmup — starts loading LLM brains without overlay.
	var mai := get_node_or_null("/root/MerlinAI")
	if mai == null or not mai.has_method("start_warmup"):
		return
	if mai.is_ready:
		return
	mai.start_warmup()


func _start_llm_warmup() -> void:
	## Explicit warmup with overlay — called when player clicks "Jouer".
	var mai := get_node_or_null("/root/MerlinAI")
	if mai == null:
		return
	# If already ready (background warmup succeeded), skip overlay
	if mai.is_ready:
		return
	if mai.has_method("start_warmup"):
		mai.start_warmup()
	# Show overlay only if models are still loading
	var overlay_scene = load("res://scenes/ui/LLMWarmupOverlay.tscn")
	if overlay_scene:
		var overlay = overlay_scene.instantiate()
		add_child(overlay)


func _store_return_scene() -> void:
	var se := get_node_or_null("/root/ScreenEffects")
	if se:
		se.return_scene = get_tree().current_scene.scene_file_path


func _play_swipe(dir: float) -> void:
	if swipe_tween:
		swipe_tween.kill()
	var angle := deg_to_rad(5.0) * dir
	var offset := Vector2(120.0 * dir, -8.0)
	swipe_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	swipe_tween.tween_property(card, "rotation", angle, 0.25)
	swipe_tween.parallel().tween_property(card, "position", card.position + offset, 0.25)
	swipe_tween.parallel().tween_property(card, "modulate:a", 0.0, 0.2)


func _play_ui_sound(sound_name: String) -> void:
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play(sound_name)


func _on_resized() -> void:
	call_deferred("_layout_ui")
	_rebuild_accum_visuals()


# =============================================================================
# TIME-OF-DAY TINT SYSTEM
# =============================================================================

func _build_time_tint_layer() -> void:
	time_tint_layer = ColorRect.new()
	time_tint_layer.name = "TimeTintLayer"
	time_tint_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	time_tint_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var transparent: Color = MerlinVisual.GBC.black
	time_tint_layer.color = Color(transparent.r, transparent.g, transparent.b, 0.0)
	add_child(time_tint_layer)
	_update_time_tint()


func _get_time_period(hour: int) -> String:
	if hour >= 0 and hour < 5:
		return "night"
	elif hour >= 5 and hour < 7:
		return "dawn"
	elif hour >= 7 and hour < 10:
		return "morning"
	elif hour >= 10 and hour < 14:
		return "midday"
	elif hour >= 14 and hour < 17:
		return "afternoon"
	elif hour >= 17 and hour < 20:
		return "dusk"
	elif hour >= 20 and hour < 22:
		return "evening"
	else:
		return "night"


func _update_time_tint() -> void:
	if not time_tint_layer:
		return
	var time_dict := Time.get_time_dict_from_system()
	var hour: int = time_dict.hour
	var period := _get_time_period(hour)
	var target_color: Color = TIME_TINTS[period]

	if _time_tint_tween:
		_time_tint_tween.kill()
	_time_tint_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_time_tint_tween.tween_property(time_tint_layer, "color", target_color, 2.0)


# =============================================================================
# SEASONAL EFFECTS — UNIFIED SYSTEM
# =============================================================================

func _build_seasonal_effects() -> void:
	if current_season == "ETE":
		_build_sun_rays()
		return
	# For HIVER, AUTOMNE, PRINTEMPS: build accumulation grid
	_build_accum_grid()


func _process_seasonal_effects(delta: float) -> void:
	if current_season == "ETE":
		_process_sun_rays(delta)
		return
	if not SEASON_CONFIG.has(current_season):
		return
	_process_falling_particles(delta)


# =============================================================================
# FALLING PARTICLES + ACCUMULATION (HIVER / AUTOMNE / PRINTEMPS)
# =============================================================================

func _process_falling_particles(delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var cfg: Dictionary = SEASON_CONFIG[current_season]

	# Spawn
	_fall_timer += delta
	if _fall_timer >= cfg.spawn_interval and _falling_particles.size() < cfg.max_particles:
		_fall_timer = 0.0
		_spawn_falling_particle(viewport_size, cfg)

	# Update
	var to_remove: Array[int] = []
	for i in range(_falling_particles.size()):
		var p: Dictionary = _falling_particles[i]
		var node: ColorRect = p.node
		if not is_instance_valid(node):
			to_remove.append(i)
			continue

		node.position.y += p.speed * delta
		node.position.x += sin((node.position.y * 0.015) + p.time_offset) * p.drift * delta
		# Gentle rotation for leaves/petals
		if not cfg.round:
			node.rotation += p.drift * 0.02 * delta

		# Check landing: particle reached the accumulation surface?
		var col := int(clampf(node.position.x / ACCUM_CELL_WIDTH, 0, _accum_grid.size() - 1))
		var surface_y: float = viewport_size.y - _accum_grid[col]
		if node.position.y >= surface_y:
			# Land! grow accumulation
			_particle_land_count += 1
			if _particle_land_count % 10 == 0:
				var sfx := get_node_or_null("/root/SFXManager")
				if sfx and sfx.has_method("play_varied"):
					sfx.play_varied("pixel_land", 0.2)
			_accum_grid[col] = minf(_accum_grid[col] + cfg.accum_grow, ACCUM_MAX_HEIGHT)
			# Spread a tiny bit to neighbors for natural mound shape
			if col > 0:
				_accum_grid[col - 1] = minf(_accum_grid[col - 1] + cfg.accum_grow * 0.3, ACCUM_MAX_HEIGHT)
			if col < _accum_grid.size() - 1:
				_accum_grid[col + 1] = minf(_accum_grid[col + 1] + cfg.accum_grow * 0.3, ACCUM_MAX_HEIGHT)
			_update_accum_column(col, viewport_size)
			if col > 0:
				_update_accum_column(col - 1, viewport_size)
			if col < _accum_grid.size() - 1:
				_update_accum_column(col + 1, viewport_size)
			to_remove.append(i)
			continue

		# Off-screen
		if node.position.x < -20 or node.position.x > viewport_size.x + 20:
			to_remove.append(i)

	# Cleanup (reverse order)
	for i in range(to_remove.size() - 1, -1, -1):
		var idx: int = to_remove[i]
		if is_instance_valid(_falling_particles[idx].node):
			_falling_particles[idx].node.queue_free()
		_falling_particles.remove_at(idx)


func _spawn_falling_particle(viewport_size: Vector2, cfg: Dictionary) -> void:
	var node := ColorRect.new()
	var s: float = randf_range(cfg.size_min, cfg.size_max)

	if cfg.round:
		node.size = Vector2(s, s)
	else:
		# Leaf/petal shape: wider than tall or vice versa
		node.size = Vector2(s, s * randf_range(0.5, 0.8))

	node.position = Vector2(randf_range(-10, viewport_size.x + 10), randf_range(-20, -5))

	# Color with variation
	var base: Color = cfg.color_base
	var v: float = cfg.color_var
	if current_season == "AUTOMNE":
		# Pick from autumn palette - various leaf colors
		var autumn_colors: Array[Color] = [
			MerlinVisual.GBC.fire_light,      # Bright orange leaf
			MerlinVisual.GBC.fire_dark,       # Deep red-brown
			MerlinVisual.ASPECT_COLORS["Corps"],  # Earthy brown
			MerlinVisual.GBC.thunder,         # Golden yellow
			MerlinVisual.SEASON_COLORS["automne"],  # Base autumn tone
		]
		base = autumn_colors[randi() % autumn_colors.size()]
	node.color = Color(
		clampf(base.r + randf_range(-v, v), 0, 1),
		clampf(base.g + randf_range(-v, v), 0, 1),
		clampf(base.b + randf_range(-v, v), 0, 1),
		base.a
	)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var data := {
		"node": node,
		"speed": randf_range(cfg.speed_min, cfg.speed_max),
		"drift": randf_range(-cfg.drift, cfg.drift),
		"time_offset": randf_range(0, TAU),
	}

	add_child(node)
	# Place behind card but above background
	if card:
		move_child(node, card.get_index())
	_falling_particles.append(data)


# =============================================================================
# ACCUMULATION GRID — grows from bottom, clickable to destroy
# =============================================================================

func _build_accum_grid() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var col_count := int(ceilf(viewport_size.x / ACCUM_CELL_WIDTH)) + 1
	_accum_grid.resize(col_count)
	_accum_grid.fill(0.0)

	# Container for accumulation visuals (above background, below card)
	_accum_container = Control.new()
	_accum_container.name = "AccumContainer"
	_accum_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_accum_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_accum_container)
	if card:
		move_child(_accum_container, card.get_index())

	# Create one visual column per cell
	_accum_nodes.clear()
	var cfg: Dictionary = SEASON_CONFIG[current_season]
	for i in range(col_count):
		var col_node := ColorRect.new()
		col_node.name = "AccumCol_%d" % i
		col_node.color = cfg.accum_color
		col_node.size = Vector2(ACCUM_CELL_WIDTH, 0)
		col_node.position = Vector2(i * ACCUM_CELL_WIDTH, viewport_size.y)
		col_node.mouse_filter = Control.MOUSE_FILTER_STOP
		col_node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var col_idx := i  # capture for lambda
		col_node.gui_input.connect(func(event: InputEvent): _on_accum_clicked(event, col_idx))
		_accum_container.add_child(col_node)
		_accum_nodes.append(col_node)


func _update_accum_column(col: int, viewport_size: Vector2) -> void:
	if col < 0 or col >= _accum_nodes.size():
		return
	var node: ColorRect = _accum_nodes[col]
	if not is_instance_valid(node):
		return
	var h: float = _accum_grid[col]
	node.size = Vector2(ACCUM_CELL_WIDTH, h)
	node.position = Vector2(col * ACCUM_CELL_WIDTH, viewport_size.y - h)


func _rebuild_accum_visuals() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if _accum_nodes.is_empty():
		return
	# Resize grid if viewport changed
	var needed := int(ceilf(viewport_size.x / ACCUM_CELL_WIDTH)) + 1
	while _accum_grid.size() < needed:
		_accum_grid.append(0.0)
	for i in range(_accum_nodes.size()):
		_update_accum_column(i, viewport_size)


func _on_accum_clicked(event: InputEvent, col: int) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _accum_grid[col] < 2.0:
		return  # nothing to destroy

	var sfx := get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("accum_explode")
	_explode_accum_area(col)


func _explode_accum_area(center_col: int) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var cfg: Dictionary = SEASON_CONFIG[current_season]

	# Determine blast radius (5 columns each side)
	var blast_radius := 5
	var total_height := 0.0
	for c in range(maxi(0, center_col - blast_radius), mini(_accum_grid.size(), center_col + blast_radius + 1)):
		total_height += _accum_grid[c]

	# Spawn burst particles proportional to destroyed height
	var burst_count := int(total_height * 0.4) + 8
	burst_count = mini(burst_count, 40)
	var center_x: float = center_col * ACCUM_CELL_WIDTH + ACCUM_CELL_WIDTH * 0.5
	var center_y: float = viewport_size.y - _accum_grid[center_col]

	for i in range(burst_count):
		var particle := ColorRect.new()
		var s: float = randf_range(2, 6)
		particle.size = Vector2(s, s)
		particle.position = Vector2(
			center_x + randf_range(-blast_radius * ACCUM_CELL_WIDTH * 0.5, blast_radius * ACCUM_CELL_WIDTH * 0.5),
			center_y + randf_range(-5, 5)
		)
		particle.color = cfg.accum_color
		particle.color.a = randf_range(0.5, 1.0)
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(particle)

		var angle := randf_range(0, TAU)
		var dist := randf_range(25, 80)
		var target_pos := particle.position + Vector2(cos(angle), sin(angle) - 0.6) * dist
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "position", target_pos, randf_range(0.3, 0.6))
		tween.parallel().tween_property(particle, "modulate:a", 0.0, randf_range(0.4, 0.8))
		tween.tween_callback(particle.queue_free)

	# Clear the accumulation in blast area
	for c in range(maxi(0, center_col - blast_radius), mini(_accum_grid.size(), center_col + blast_radius + 1)):
		_accum_grid[c] = 0.0
		_update_accum_column(c, viewport_size)


# =============================================================================
# SUMMER — SUN RAYS
# =============================================================================

func _build_sun_rays() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	# Create 4-6 diagonal light beams
	var ray_count := randi_range(4, 6)
	for i in range(ray_count):
		var ray := ColorRect.new()
		ray.name = "SunRay_%d" % i
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Tall narrow rectangles, rotated diagonally
		var w: float = randf_range(30, 80)
		var h: float = viewport_size.y * randf_range(1.2, 1.6)
		ray.size = Vector2(w, h)
		ray.pivot_offset = Vector2(w * 0.5, 0)

		# Position across the top, spread out
		var x_spread: float = viewport_size.x / ray_count
		ray.position = Vector2(
			x_spread * i + randf_range(-30, 30),
			randf_range(-h * 0.3, -h * 0.1)
		)

		# Slight diagonal rotation
		ray.rotation = randf_range(deg_to_rad(10), deg_to_rad(35))

		# Warm golden color, very transparent
		var sun_gold: Color = MerlinVisual.GBC.light
		ray.color = Color(sun_gold.r, sun_gold.g, sun_gold.b, randf_range(0.03, 0.07))

		add_child(ray)
		if card:
			move_child(ray, card.get_index())

		_sun_rays.append(ray)
		ray.set_meta("base_alpha", ray.color.a)
		ray.set_meta("phase", randf_range(0, TAU))
		ray.set_meta("speed", randf_range(0.15, 0.4))


func _process_sun_rays(delta: float) -> void:
	_sun_ray_timer += delta
	for ray in _sun_rays:
		if not is_instance_valid(ray):
			continue
		var base_a: float = ray.get_meta("base_alpha")
		var phase: float = ray.get_meta("phase")
		var spd: float = ray.get_meta("speed")
		# Gentle pulsing opacity
		ray.color.a = base_a * (0.5 + 0.5 * sin(_sun_ray_timer * spd + phase))


# =============================================================================
# COMBINED VOICE + LLM TEST PANEL
# =============================================================================

const VOICE_TEST_TEXT := "Bienvenue, voyageur. Je suis Merlin, le dernier druide de Broceliande."
const LLM_DEFAULT_PROMPT := "Dis bonjour au joueur."
const LLM_SYSTEM_PROMPT := "Tu es Merlin, druide taquin d'une lande celtique. Court, percutant, 1-2 phrases max. Tutoiement. Humour et metaphores naturelles."

# Params override for short, clean LLM responses
const LLM_PARAMS_OVERRIDE := {
	"max_tokens": 60,
	"temperature": 0.4,
	"top_p": 0.75,
	"top_k": 25,
	"repetition_penalty": 1.6,
}

# Voice: 0 = AC Voice (on), 1 = Off
const PANEL_VOICE_LABELS := [
	"AC Voice (Animalese)",
	"Desactivee",
]

var _panel_voice_idx: int = 0
var _panel_voice_bank: String = "default"
var _panel_preset: String = "Merlin"
var _panel_prompt_input: TextEdit


func _show_voice_llm_panel() -> void:
	if _voice_panel and is_instance_valid(_voice_panel):
		_voice_panel.visible = true
		for child in _voice_panel.get_children():
			if child is Control:
				child.modulate.a = 0.0
				var tw := create_tween()
				tw.tween_property(child, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		return
	_load_voice_settings_for_panel()
	_build_voice_llm_panel()


func _load_voice_settings_for_panel() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		_panel_voice_idx = config.get_value("voice", "panel_idx", 0)
		_panel_voice_bank = config.get_value("voice", "bank", "default")
		_panel_preset = config.get_value("voice", "preset", "Merlin")


func _build_voice_llm_panel() -> void:
	_voice_panel = CanvasLayer.new()
	_voice_panel.layer = 50
	add_child(_voice_panel)

	# Dim background
	var dim := ColorRect.new()
	var black_base: Color = MerlinVisual.GBC.black
	dim.color = Color(black_base.r, black_base.g, black_base.b, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close_voice_panel()
	)
	_voice_panel.add_child(dim)

	# Scrollable panel
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_CENTER)
	scroll.offset_left = -280
	scroll.offset_right = 280
	scroll.offset_top = -300
	scroll.offset_bottom = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_voice_panel.add_child(scroll)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
	style.border_color = MerlinVisual.CRT_PALETTE.amber
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = MerlinVisual.CRT_PALETTE.shadow
	style.shadow_size = 12
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	scroll.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Test Voix & LLM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if body_font:
		title.add_theme_font_override("font", body_font)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# --- VOICE TYPE SELECTOR (all 10 types + off) ---
	var mode_row := _create_panel_row(vbox, "Type voix :")
	var mode_opt := OptionButton.new()
	mode_opt.name = "PanelVoiceTypeOpt"
	for lbl in PANEL_VOICE_LABELS:
		mode_opt.add_item(lbl)
	mode_opt.selected = _panel_voice_idx
	mode_opt.add_theme_font_size_override("font_size", 13)
	mode_opt.item_selected.connect(func(idx: int):
		_panel_voice_idx = idx
		_update_panel_voice_controls()
	)
	mode_row.add_child(mode_opt)

	# --- SOUND BANK (AC Voice only, idx 0) ---
	var bank_row := _create_panel_row(vbox, "Banque :")
	bank_row.name = "PanelBankRow"
	var bank_opt := OptionButton.new()
	bank_opt.name = "PanelBankOpt"
	var bank_names := ["default", "high", "low", "lowest", "med", "robot", "glitch", "whisper", "droid"]
	var bank_labels := {"default": "Classique", "high": "Aigu (Peppy)", "low": "Grave (Cranky)", "lowest": "Tres grave", "med": "Medium", "robot": "Robot Beep", "glitch": "Glitch Bot", "whisper": "Synth Whisper", "droid": "Droid (R2D2)"}
	for bname in bank_names:
		bank_opt.add_item(bank_labels.get(bname, bname))
		bank_opt.set_item_metadata(bank_opt.item_count - 1, bname)
	for i in range(bank_opt.item_count):
		if bank_opt.get_item_metadata(i) == _panel_voice_bank:
			bank_opt.selected = i
			break
	bank_opt.add_theme_font_size_override("font_size", 13)
	bank_opt.item_selected.connect(func(idx: int):
		_panel_voice_bank = bank_opt.get_item_metadata(idx)
		if _voice_vb and _voice_vb.has_method("set_sound_bank"):
			_voice_vb.set_sound_bank(_panel_voice_bank)
	)
	bank_row.add_child(bank_opt)

	# --- PRESET (AC Voice only, idx 0) ---
	var preset_row := _create_panel_row(vbox, "Preset :")
	preset_row.name = "PanelPresetRow"
	var preset_opt := OptionButton.new()
	preset_opt.name = "PanelPresetOpt"
	var presets := ["Merlin", "Normal", "Grave", "Sage", "Mysterieux", "Joyeux", "Aigu", "Enfant"]
	for p in presets:
		preset_opt.add_item(p)
	for i in range(preset_opt.item_count):
		if preset_opt.get_item_text(i) == _panel_preset:
			preset_opt.selected = i
			break
	preset_opt.add_theme_font_size_override("font_size", 13)
	preset_opt.item_selected.connect(func(idx: int):
		_panel_preset = presets[idx]
		_on_voice_preset_selected(idx)
	)
	preset_row.add_child(preset_opt)

	# --- SLIDERS ---
	_voice_pitch_slider = _create_voice_slider(vbox, "Pitch", 0.5, 5.0, 3.2, "_voice_pitch_value")
	_voice_variation_slider = _create_voice_slider(vbox, "Variation", 0.0, 1.0, 0.28, "_voice_variation_value")
	_voice_speed_slider = _create_voice_slider(vbox, "Vitesse", 0.3, 2.5, 0.95, "_voice_speed_value")

	# --- LLM PROMPT INPUT ---
	var prompt_lbl := Label.new()
	prompt_lbl.text = "Prompt LLM :"
	prompt_lbl.add_theme_font_size_override("font_size", 14)
	prompt_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	vbox.add_child(prompt_lbl)

	_panel_prompt_input = TextEdit.new()
	_panel_prompt_input.text = LLM_DEFAULT_PROMPT
	_panel_prompt_input.custom_minimum_size = Vector2(460, 50)
	_panel_prompt_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_prompt_input.scroll_fit_content_height = true
	_panel_prompt_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_panel_prompt_input.add_theme_font_size_override("font_size", 14)
	_panel_prompt_input.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	var input_style := StyleBoxFlat.new()
	var white_base: Color = MerlinVisual.GBC.white
	input_style.bg_color = Color(white_base.r, white_base.g, white_base.b, 0.5)
	input_style.border_color = MerlinVisual.CRT_PALETTE.border
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(4)
	input_style.set_content_margin_all(6)
	_panel_prompt_input.add_theme_stylebox_override("normal", input_style)
	vbox.add_child(_panel_prompt_input)

	# --- TEST TEXT DISPLAY (output) ---
	_voice_test_label = RichTextLabel.new()
	_voice_test_label.text = ""
	_voice_test_label.bbcode_enabled = true
	_voice_test_label.fit_content = true
	_voice_test_label.scroll_active = false
	_voice_test_label.custom_minimum_size = Vector2(460, 40)
	if body_font:
		_voice_test_label.add_theme_font_override("normal_font", body_font)
	_voice_test_label.add_theme_font_size_override("normal_font_size", 15)
	_voice_test_label.add_theme_color_override("default_color", MerlinVisual.CRT_PALETTE.phosphor)
	vbox.add_child(_voice_test_label)

	# LLM source badge (dev indicator)
	_llm_test_badge = LLMSourceBadge.create("static")
	_llm_test_badge.visible = false
	vbox.add_child(_llm_test_badge)

	# --- BUTTONS ---
	var btn_row1 := HBoxContainer.new()
	btn_row1.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row1.add_theme_constant_override("separation", 10)

	var test_voice_btn := _create_panel_button("Test Voix", func(): _on_test_voice_only())
	btn_row1.add_child(test_voice_btn)

	var test_llm_btn := _create_panel_button("Test LLM", func(): _on_test_llm_only())
	btn_row1.add_child(test_llm_btn)

	var test_both_btn := _create_panel_button("Voix + LLM", func(): _on_test_voice_and_llm())
	btn_row1.add_child(test_both_btn)

	vbox.add_child(btn_row1)

	var btn_row2 := HBoxContainer.new()
	btn_row2.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row2.add_theme_constant_override("separation", 10)

	var stop_btn := _create_panel_button("Stop", func(): _on_voice_stop())
	btn_row2.add_child(stop_btn)

	var close_btn := _create_panel_button("Fermer", func(): _close_voice_panel())
	btn_row2.add_child(close_btn)

	vbox.add_child(btn_row2)

	# Initialize voicebox
	_setup_menu_voicebox()
	_on_voice_preset_selected(0)
	_update_panel_voice_controls()


func _create_panel_row(parent: VBoxContainer, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 80
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	row.add_child(lbl)
	parent.add_child(row)
	return row


func _create_panel_button(label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(110, 36)
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(callback)
	return btn


func _update_panel_voice_controls() -> void:
	if not _voice_panel:
		return
	var bank_row = _find_node_recursive(_voice_panel, "PanelBankRow")
	var preset_row = _find_node_recursive(_voice_panel, "PanelPresetRow")
	var is_ac: bool = (_panel_voice_idx == 0)
	if bank_row:
		bank_row.visible = is_ac
	if preset_row:
		preset_row.visible = is_ac


func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_node_recursive(child, target_name)
		if found:
			return found
	return null


# --- VOICE TEST ---

func _on_test_voice_only() -> void:
	_on_voice_stop()
	if _panel_voice_idx == 0:
		_on_voice_play()


func _on_voice_play() -> void:
	if not _voice_vb or not is_instance_valid(_voice_vb):
		_setup_menu_voicebox()
	if not _voice_vb:
		return
	_sync_voice_params()
	if _voice_vb.has_method("stop_speaking"):
		_voice_vb.stop_speaking()
	_voice_vb.set("text_label", _voice_test_label)
	_voice_test_label.text = VOICE_TEST_TEXT
	_voice_test_label.visible_characters = 0
	_voice_vb.play_string(VOICE_TEST_TEXT)


# --- LLM TEST (async/await) ---

func _on_test_llm_only() -> void:
	_on_voice_stop()
	_voice_test_label.text = "Envoi au LLM..."
	_voice_test_label.visible_characters = -1

	var prompt := _get_panel_prompt()
	var text := await _call_llm(prompt)
	_voice_test_label.text = text
	_voice_test_label.visible_characters = -1


func _on_test_voice_and_llm() -> void:
	_on_voice_stop()
	_voice_test_label.text = "Envoi au LLM..."
	_voice_test_label.visible_characters = -1

	var prompt := _get_panel_prompt()
	var text := await _call_llm(prompt)

	if _panel_voice_idx == 0 and _voice_vb and is_instance_valid(_voice_vb):
		_sync_voice_params()
		_voice_vb.set("text_label", _voice_test_label)
		_voice_test_label.text = text
		_voice_test_label.visible_characters = 0
		_voice_vb.play_string(text)
	else:
		_voice_test_label.text = text
		_voice_test_label.visible_characters = -1


func _get_panel_prompt() -> String:
	if _panel_prompt_input and _panel_prompt_input.text.strip_edges() != "":
		return _panel_prompt_input.text.strip_edges()
	return LLM_DEFAULT_PROMPT


func _update_llm_test_badge(source: String) -> void:
	if _llm_test_badge and is_instance_valid(_llm_test_badge):
		LLMSourceBadge.update_badge(_llm_test_badge, source)
		_llm_test_badge.visible = true


func _call_llm(user_prompt: String) -> String:
	var merlin_ai = get_node_or_null("/root/MerlinAI")
	if not merlin_ai:
		_update_llm_test_badge("error")
		return "MerlinAI non disponible."

	# Streaming API — show chunks as they arrive
	if merlin_ai.has_method("generate_with_system_stream"):
		var on_chunk := func(chunk: String, _done: bool) -> void:
			if _voice_test_label:
				var current := _voice_test_label.text
				if current == "Envoi au LLM..." or current == "Generation...":
					current = ""
				_voice_test_label.text = current + chunk
				_voice_test_label.visible_characters = -1
		_voice_test_label.text = "Generation..."
		var result: Dictionary = await merlin_ai.generate_with_system_stream(
			LLM_SYSTEM_PROMPT, user_prompt, LLM_PARAMS_OVERRIDE, on_chunk
		)
		if result.has("error"):
			_update_llm_test_badge("error")
			return "Erreur LLM: " + str(result.error)
		_update_llm_test_badge("llm")
		return _clean_llm_response(str(result.get("text", "")))

	# Fallback: non-streaming generate_with_system
	if merlin_ai.has_method("generate_with_system"):
		var result: Dictionary = await merlin_ai.generate_with_system(
			LLM_SYSTEM_PROMPT, user_prompt, LLM_PARAMS_OVERRIDE
		)
		if result.has("error"):
			_update_llm_test_badge("error")
			return "Erreur LLM: " + str(result.error)
		_update_llm_test_badge("llm")
		return _clean_llm_response(str(result.get("text", "")))

	# Fallback: debug_execute_input
	if merlin_ai.has_method("debug_execute_input"):
		var result: Dictionary = await merlin_ai.debug_execute_input(user_prompt)
		_update_llm_test_badge("llm")
		return _clean_llm_response(str(result.get("response", result.get("text", ""))))

	return "LLM: aucune methode disponible."


func _clean_llm_response(raw: String) -> String:
	var text := raw.strip_edges()
	# Truncate at first template token (all known variants)
	var stop_tokens := [
		"<|im_end|>", "<|im_start|>", "<|endoftext|>",
		"<|im_end>", "<|im_start>", "<|endoftext>",
		"<im_end>", "<im_start>",
		"<|im_end", "<|im_start",
	]
	for stop_token in stop_tokens:
		var idx := text.find(stop_token)
		if idx >= 0:
			text = text.substr(0, idx)
	# Strip any remaining angle-bracket template markers via regex
	var regex := RegEx.new()
	regex.compile("<\\|?im_(?:end|start)\\|?>")
	text = regex.sub(text, "", true)
	regex.compile("<\\|?endoftext\\|?>")
	text = regex.sub(text, "", true)
	# Remove role prefixes
	for prefix in ["system\n", "user\n", "assistant\n"]:
		if text.begins_with(prefix):
			text = text.substr(prefix.length())
	text = text.strip_edges()
	if text == "":
		return "(Reponse vide du LLM)"
	return text


# --- SLIDERS & VOICEBOX HELPERS ---

func _create_voice_slider(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, default_val: float, value_var: String) -> HSlider:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 70
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	hbox.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.01
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 200
	hbox.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % default_val
	val_lbl.custom_minimum_size.x = 40
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	hbox.add_child(val_lbl)

	if value_var == "_voice_pitch_value":
		_voice_pitch_value = val_lbl
	elif value_var == "_voice_variation_value":
		_voice_variation_value = val_lbl
	elif value_var == "_voice_speed_value":
		_voice_speed_value = val_lbl

	slider.value_changed.connect(func(v: float):
		val_lbl.text = "%.2f" % v
		_sync_voice_params()
	)

	parent.add_child(hbox)
	return slider


func _setup_menu_voicebox() -> void:
	if _voice_vb and is_instance_valid(_voice_vb):
		return
	var script_path := "res://addons/acvoicebox/acvoicebox.gd"
	if ResourceLoader.exists(script_path):
		var scr = load(script_path)
		if scr:
			_voice_vb = scr.new()
			_voice_vb.set("base_pitch", 3.2)
			_voice_vb.set("pitch_variation", 0.28)
			_voice_vb.set("speed_scale", 0.95)
			add_child(_voice_vb)
			if _voice_vb.has_method("set_sound_bank"):
				_voice_vb.set_sound_bank(_panel_voice_bank)


func _sync_voice_params() -> void:
	if not _voice_vb or not is_instance_valid(_voice_vb):
		return
	if _voice_pitch_slider:
		_voice_vb.set("base_pitch", _voice_pitch_slider.value)
	if _voice_variation_slider:
		_voice_vb.set("pitch_variation", _voice_variation_slider.value)
	if _voice_speed_slider:
		_voice_vb.set("speed_scale", _voice_speed_slider.value)


func _on_voice_preset_selected(index: int) -> void:
	var presets := ["Merlin", "Normal", "Grave", "Sage", "Mysterieux", "Joyeux", "Aigu", "Enfant"]
	if index < 0 or index >= presets.size():
		return
	_panel_preset = presets[index]
	if _voice_vb and _voice_vb.has_method("apply_preset"):
		_voice_vb.apply_preset(presets[index])
	if _voice_vb:
		if _voice_pitch_slider:
			_voice_pitch_slider.value = _voice_vb.get("base_pitch")
		if _voice_variation_slider:
			_voice_variation_slider.value = _voice_vb.get("pitch_variation")
		if _voice_speed_slider:
			_voice_speed_slider.value = _voice_vb.get("speed_scale")


func _on_voice_stop() -> void:
	if _voice_vb and _voice_vb.has_method("stop_speaking"):
		_voice_vb.stop_speaking()
	if _voice_test_label:
		_voice_test_label.visible_characters = -1


func _close_voice_panel() -> void:
	_on_voice_stop()
	if _voice_panel:
		var tw := create_tween()
		for child in _voice_panel.get_children():
			if child is Control:
				tw.tween_property(child, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(func(): _voice_panel.visible = false)
