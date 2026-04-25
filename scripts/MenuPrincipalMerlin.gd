extends Control

# =============================================================================
# MENU PRINCIPAL "PARCHEMIN MYSTIQUE BRETON"
# Design celtique sobre et epure - Ambiance sanctuaire ancien
# Delegates to: menu_principal_animations, menu_principal_seasonal,
#               menu_principal_theme, menu_principal_voice_panel
# =============================================================================


const TITLE_TEXT := "M  E  R  L  I  N"

const MAIN_MENU_ITEMS := [
	{"text_key": "MENU_NEW_GAME", "scene": "res://scenes/ParchmentPreRun.tscn", "priority": "primary"},
	{"text_key": "MENU_CONTINUE", "scene": "res://scenes/SelectionSauvegarde.tscn", "priority": "secondary"},
	{"text_key": "MENU_OPTIONS", "scene": "res://scenes/MenuOptions.tscn", "priority": "tertiary"},
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
# Collection.tscn and Calendar.tscn removed in demo cleanup (2026-04-25)
# Calendar/Collections buttons are no-op until meta-progression is reintroduced.
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
var _last_minute: int = -1

# Fonts
var title_font: Font
var body_font: Font
var celtic_font: Font

# Mist animation
var _mist_tween: Tween

# Custom cursor
var _custom_cursor: Control

# LLM status indicator
var _ai_status_label: Label

# Pixel matrix background
var _matrix_bg: Control

# Season for atmosphere
var current_season := "HIVER"

# Time-of-day tint
var time_tint_layer: ColorRect
var _time_tint_tween: Tween

# Clock constants
const MONTH_NAMES := [
	"", "Genver", "C'hwevrer", "Meurzh", "Ebrel", "Mae", "Mezheven",
	"Gouere", "Eost", "Gwengolo", "Here", "Du", "Kerzu"
]
const DAY_NAMES := [
	"Sul", "Lun", "Meurzh", "Merc'her", "Yaou", "Gwener", "Sadorn"
]

# =============================================================================
# MODULE INSTANCES
# =============================================================================

var _anim: MenuPrincipalAnimations = MenuPrincipalAnimations.new()
var _seasonal: MenuPrincipalSeasonal = MenuPrincipalSeasonal.new()
var _theme_builder: MenuPrincipalTheme = MenuPrincipalTheme.new()
var _voice_panel_module: MenuPrincipalVoicePanel = MenuPrincipalVoicePanel.new()


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_calendar_settings()
	_determine_season()
	_load_fonts()
	_init_modules()
	_build_matrix_bg()
	_configure_background()
	_configure_celtic_ornaments()
	_configure_clock()
	_configure_main_ui()
	_configure_corner_buttons()
	_theme_builder.apply(title_label, main_buttons, calendar_button, collections_button, clock_label)
	_build_time_tint_layer()
	_seasonal.build()
	_build_custom_cursor()
	_layout_ui()
	resized.connect(_on_resized)
	_play_entry_animation.call_deferred()
	_start_mist_animation()
	call_deferred("_start_llm_warmup_background")
	_build_ai_status_indicator()
	_apply_pixel_dither()


func _init_modules() -> void:
	_anim.init(self, card, title_label, main_buttons, celtic_ornament_top, celtic_ornament_bottom)
	_seasonal.init(self, card, current_season)
	_theme_builder.init(self, title_font, body_font)
	_voice_panel_module.init(self, body_font)


func _process(delta: float) -> void:
	var time_dict := Time.get_time_dict_from_system()
	var minute: int = time_dict.minute
	if minute != _last_minute:
		_update_clock_text()
		_update_time_tint()
		_last_minute = minute

	# Seasonal particle systems
	_seasonal.process(delta)

	# Mouse parallax on matrix background
	if is_instance_valid(_matrix_bg):
		var vs := get_viewport().get_visible_rect().size
		var mouse := get_viewport().get_mouse_position()
		var offset_x: float = (mouse.x / vs.x - 0.5) * -8.0
		var offset_y: float = (mouse.y / vs.y - 0.5) * -4.0
		_matrix_bg.position = _matrix_bg.position.lerp(
			Vector2(offset_x, offset_y), clampf(3.0 * delta, 0.0, 1.0)
		)


# =============================================================================
# INITIALIZATION HELPERS
# =============================================================================

func _apply_pixel_dither() -> void:
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
	title_font = MerlinVisual.get_font("title")
	body_font = MerlinVisual.get_font("body")
	if body_font == null:
		body_font = title_font
	celtic_font = MerlinVisual.get_font("celtic")
	if celtic_font == null:
		celtic_font = body_font


# =============================================================================
# BACKGROUND & ORNAMENTS
# =============================================================================

func _configure_background() -> void:
	parchment_background.material = null
	parchment_background.color = MerlinVisual.CRT_PALETTE.bg_dark
	parchment_background.modulate.a = 1.0
	mist_layer.color = MerlinVisual.CRT_PALETTE.mist


func _build_matrix_bg() -> void:
	var matrix_script: GDScript = load("res://scripts/ui/pixel_matrix_bg.gd")
	if not matrix_script:
		return
	_matrix_bg = Control.new()
	_matrix_bg.set_script(matrix_script)
	var dark: Color = MerlinVisual.CRT_PALETTE.get("bg_deep", Color(0.02, 0.04, 0.02))
	var mid: Color = Color(dark.r * 2.5, dark.g * 2.5, dark.b * 2.5)
	var glow: Color = MerlinVisual.CRT_PALETTE.get("phosphor", Color(0.2, 1.0, 0.4))
	_matrix_bg.set_palette(dark, mid, glow)
	_matrix_bg.modulate.a = 0.0
	add_child(_matrix_bg)
	move_child(_matrix_bg, 0)


func _start_mist_animation() -> void:
	if _mist_tween:
		_mist_tween.kill()
	_mist_tween = create_tween().set_loops()
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.25, 8.0).set_trans(Tween.TRANS_SINE)
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.08, 8.0).set_trans(Tween.TRANS_SINE)


func _configure_celtic_ornaments() -> void:
	var line_text := _create_celtic_line(40)
	celtic_ornament_top.text = line_text
	celtic_ornament_top.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)
	celtic_ornament_top.position = Vector2(0, 50)
	celtic_ornament_bottom.text = line_text
	celtic_ornament_bottom.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)


func _create_celtic_line(length: int) -> String:
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
# CLOCK
# =============================================================================

func _configure_clock() -> void:
	_update_clock_text()


func _update_clock_text() -> void:
	if not clock_label:
		return
	var time_dict := Time.get_time_dict_from_system()
	var time_str := "%02d:%02d" % [time_dict.hour, time_dict.minute]
	clock_label.text = time_str


func _layout_clock() -> void:
	if clock_label:
		clock_label.position = Vector2(CORNER_BUTTON_MARGIN, 16)
		clock_label.size = Vector2(320, 80)


# =============================================================================
# UI CONFIGURATION
# =============================================================================

func _configure_main_ui() -> void:
	_sep_left.color = MerlinVisual.CRT_PALETTE.line
	_sep_diamond.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	_sep_right.color = MerlinVisual.CRT_PALETTE.line

	# Fallback labels if translations.csv is missing
	var _fallback_labels: Dictionary = {
		"MENU_NEW_GAME": "Nouvelle Partie",
		"MENU_CONTINUE": "Continuer",
		"MENU_OPTIONS": "Options",
	}
	for item in MAIN_MENU_ITEMS:
		var is_primary: bool = item.get("priority", "") == "primary"
		var label: String = tr(item.text_key)
		if label == item.text_key:  # Translation not found — use fallback
			label = _fallback_labels.get(item.text_key, item.text_key)
		var btn := _create_menu_button(label, item.scene, is_primary)
		btn.set_meta("priority", item.get("priority", "secondary"))
		btn.pivot_offset = Vector2(200, 28)
		main_buttons.add_child(btn)


func _configure_corner_buttons() -> void:
	calendar_button.pressed.connect(_on_calendar_pressed)
	calendar_button.mouse_entered.connect(func(): _anim.on_corner_button_hover(calendar_button, true))
	calendar_button.mouse_exited.connect(func(): _anim.on_corner_button_hover(calendar_button, false))
	collections_button.pressed.connect(_on_collections_pressed)
	collections_button.mouse_entered.connect(func(): _anim.on_corner_button_hover(collections_button, true))
	collections_button.mouse_exited.connect(func(): _anim.on_corner_button_hover(collections_button, false))


func _create_menu_button(label: String, scene: String, is_primary: bool) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = false
	var mr: Node = get_node_or_null("/root/MerlinResponsive")
	var min_h: int = 56 if is_primary else MerlinVisual.MIN_TOUCH_TARGET
	if mr:
		mr.apply_touch_margins(btn)
		if is_primary:
			btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, min_h)
	else:
		btn.custom_minimum_size = Vector2(0, min_h)
	btn.pressed.connect(func(): _on_menu_action(scene))
	btn.mouse_entered.connect(func(): _anim.on_button_hover(btn, true))
	btn.mouse_exited.connect(func(): _anim.on_button_hover(btn, false))
	return btn


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
# ANIMATIONS (delegated)
# =============================================================================

func _play_entry_animation() -> void:
	_anim.play_entry(_matrix_bg)


# =============================================================================
# LAYOUT
# =============================================================================

func _layout_ui() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var mr: Node = get_node_or_null("/root/MerlinResponsive")
	var is_compact: bool = mr != null and (mr.is_mobile or mr.is_portrait)

	var width_ratio: float = 0.94 if is_compact else 0.85
	var height_ratio: float = 0.88 if is_compact else 0.72
	var card_w: float = minf(CARD_MAX_WIDTH, viewport_size.x * width_ratio)
	var card_h: float = minf(CARD_MAX_HEIGHT, viewport_size.y * height_ratio)
	var content_min: Vector2 = card_contents.get_combined_minimum_size()
	if content_min.y > 0.0:
		var max_h: float = minf(CARD_MAX_HEIGHT, viewport_size.y * 0.92)
		card_h = minf(maxf(card_h, content_min.y + 48.0), max_h)
	card.size = Vector2(card_w, card_h)

	var safe_top: float = mr.get_safe_margin_top() if mr else 0.0
	var card_y: float = (viewport_size.y - card.size.y) * 0.5 + safe_top * 0.5
	card.position = Vector2((viewport_size.x - card.size.x) * 0.5, card_y)
	card.pivot_offset = card.size * 0.5
	_anim.card_target_pos = card.position

	_layout_corner_buttons(viewport_size)
	_layout_celtic_ornaments(viewport_size)
	_layout_clock()
	if _ai_status_label:
		var safe_bottom: float = mr.get_safe_margin_bottom() if mr else 0.0
		_ai_status_label.position = Vector2(viewport_size.x - 212, viewport_size.y - 28 - safe_bottom)


func _layout_corner_buttons(viewport_size: Vector2) -> void:
	var mr: Node = get_node_or_null("/root/MerlinResponsive")
	var safe_bottom: float = mr.get_safe_margin_bottom() if mr else 0.0
	var btn_size: Vector2 = CORNER_BUTTON_SIZE
	if mr and mr.is_mobile:
		btn_size = Vector2(56, 56)
	var margin: float = CORNER_BUTTON_MARGIN
	if calendar_button:
		calendar_button.position = Vector2(
			margin,
			viewport_size.y - btn_size.y - margin - safe_bottom
		)
		calendar_button.size = btn_size
	if collections_button:
		collections_button.position = Vector2(
			viewport_size.x - btn_size.x - margin,
			viewport_size.y - btn_size.y - margin - safe_bottom
		)
		collections_button.size = btn_size


func _on_resized() -> void:
	call_deferred("_layout_ui")
	_seasonal.on_resized()


# =============================================================================
# ACTIONS
# =============================================================================

func _on_menu_action(scene: String) -> void:
	_play_ui_sound("click")
	if scene == "__quit__":
		get_tree().quit()
		return
	if scene == "__voice_llm_test__":
		_voice_panel_module.show()
		return
	if scene == "" or _anim.swipe_in_progress:
		return

	var game_scenes := ["res://scenes/ParchmentPreRun.tscn", "res://scenes/SelectionSauvegarde.tscn"]
	if scene in game_scenes:
		_start_llm_warmup()

	_anim.swipe_in_progress = true
	_play_ui_sound("whoosh")

	var dir := 1.0
	if card:
		var mouse_pos := get_viewport().get_mouse_position()
		var card_center := card.global_position + card.size * 0.5
		if mouse_pos.x < card_center.x:
			dir = -1.0
	_anim.play_swipe(dir)
	_fade_music_out(3.0)
	await get_tree().create_timer(0.25).timeout
	_store_return_scene()
	PixelTransition.transition_to(scene)


func _on_calendar_pressed() -> void:
	# No-op: Calendar removed in demo cleanup (2026-04-25). Reintroduce when meta-progression returns.
	print("[MenuPrincipal] Calendar disabled in demo build")


func _on_collections_pressed() -> void:
	# No-op: Collection removed in demo cleanup (2026-04-25). Reintroduce when meta-progression returns.
	print("[MenuPrincipal] Collections disabled in demo build")


func _fade_music_out(duration: float) -> void:
	var mm := get_node_or_null("/root/MusicManager")
	if mm:
		mm.fade_out(duration)


func _store_return_scene() -> void:
	var se := get_node_or_null("/root/ScreenEffects")
	if se:
		se.return_scene = get_tree().current_scene.scene_file_path


func _play_ui_sound(sound_name: String) -> void:
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play(sound_name)


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
	var target_color: Color = MerlinVisual.TIME_OF_DAY_COLORS[period]
	if _time_tint_tween:
		_time_tint_tween.kill()
	_time_tint_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_time_tint_tween.tween_property(time_tint_layer, "color", target_color, 2.0)


# =============================================================================
# AI STATUS INDICATOR
# =============================================================================

func _build_ai_status_indicator() -> void:
	_ai_status_label = Label.new()
	_ai_status_label.name = "AIStatus"
	_ai_status_label.text = "IA: ..."
	_ai_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ai_status_label.add_theme_font_size_override("font_size", 11)
	_ai_status_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)
	if body_font:
		_ai_status_label.add_theme_font_override("font", body_font)
	add_child(_ai_status_label)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_ai_status_label.size = Vector2(200, 20)
	_ai_status_label.position = Vector2(vp_size.x - 212, vp_size.y - 28)
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
		var tw := create_tween()
		_ai_status_label.modulate.a = 0.3
		tw.tween_property(_ai_status_label, "modulate:a", 1.0, 0.5)


# =============================================================================
# LLM WARMUP
# =============================================================================

func _start_llm_warmup_background() -> void:
	var mai := get_node_or_null("/root/MerlinAI")
	if mai == null or not mai.has_method("start_warmup"):
		return
	if mai.is_ready:
		return
	mai.start_warmup()


func _start_llm_warmup() -> void:
	var mai := get_node_or_null("/root/MerlinAI")
	if mai == null:
		return
	if mai.is_ready:
		return
	if mai.has_method("start_warmup"):
		mai.start_warmup()
	var overlay_scene: PackedScene = load("res://scenes/ui/LLMWarmupOverlay.tscn")
	if overlay_scene:
		var overlay: Node = overlay_scene.instantiate()
		add_child(overlay)
