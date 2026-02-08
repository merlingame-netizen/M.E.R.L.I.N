extends Control

const FONT_PATH := "res://resources/fonts/morris/MorrisRomanBlackAlt.ttf"
const LOGO_TEXT := "CeltOS"
const LOGO_GAP := 18.0
const FADE_IN_TIME := 0.6
const HOLD_TIME := 0.6

var font: Font
var logo_a: Label
var logo_b: Label
var splash_tween: Tween

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH)
	else:
		font = ThemeDB.fallback_font
	_build_ui()
	_layout_ui()
	_play_splash()
	get_viewport().size_changed.connect(_on_resized)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_go_to_menu()

func _build_ui() -> void:
	logo_a = Label.new()
	logo_a.name = "CeltOSLogoA"
	logo_a.text = LOGO_TEXT
	logo_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_a.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo_a.modulate = Color(1, 1, 1, 0)
	_add_logo_style(logo_a, 56)
	add_child(logo_a)

	logo_b = Label.new()
	logo_b.name = "CeltOSLogoB"
	logo_b.text = LOGO_TEXT
	logo_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo_b.modulate = Color(1, 1, 1, 0)
	_add_logo_style(logo_b, 46)
	add_child(logo_b)

func _add_logo_style(label: Label, font_size: int) -> void:
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.12, 0.10, 0.08, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.2))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

func _layout_ui() -> void:
	var viewport_size := get_viewport_rect().size
	var size_a := logo_a.get_combined_minimum_size()
	var size_b := logo_b.get_combined_minimum_size()
	var center_y := viewport_size.y * 0.5
	logo_a.position = Vector2((viewport_size.x - size_a.x) * 0.5, center_y - size_a.y - LOGO_GAP * 0.5)
	logo_b.position = Vector2((viewport_size.x - size_b.x) * 0.5, center_y + LOGO_GAP * 0.5)

func _play_splash() -> void:
	if splash_tween:
		splash_tween.kill()
	splash_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	splash_tween.tween_property(logo_a, "modulate", Color(1, 1, 1, 1), FADE_IN_TIME)
	splash_tween.parallel().tween_property(logo_b, "modulate", Color(1, 1, 1, 1), FADE_IN_TIME)
	splash_tween.tween_interval(HOLD_TIME)
	splash_tween.tween_callback(_go_to_menu)

func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn")

func _on_resized() -> void:
	call_deferred("_layout_ui")
