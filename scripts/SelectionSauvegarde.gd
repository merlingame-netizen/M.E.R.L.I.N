extends Control

const SLOT_COUNT := 3
const MENU_SCENE := "res://scenes/MenuPrincipal.tscn"
const GAME_SCENE := "res://scenes/GameMain.tscn"

@onready var panel: PanelContainer = $RootPanel
@onready var title_label: Label = $RootPanel/RootVBox/Title
@onready var hint_label: Label = $RootPanel/RootVBox/Hint
@onready var slots_vbox: VBoxContainer = $RootPanel/RootVBox/Slots
@onready var back_button: Button = $RootPanel/RootVBox/BackButton

var game_manager: Node = null
var font_title: Font
var font_body: Font

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	game_manager = get_node_or_null("/root/GameManager")
	_load_fonts()
	_apply_theme()
	_build_slots()
	back_button.pressed.connect(_on_back_pressed)


func _load_fonts() -> void:
	var title_path = "res://resources/fonts/morris/MorrisRomanBlack.ttf"
	var body_path = "res://resources/fonts/morris/MorrisRomanBlackAlt.ttf"
	if ResourceLoader.exists(title_path):
		font_title = load(title_path)
	else:
		font_title = ThemeDB.fallback_font
	if ResourceLoader.exists(body_path):
		font_body = load(body_path)
	else:
		font_body = ThemeDB.fallback_font


func _apply_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.08, 0.1, 0.98)
	panel_style.border_color = Color(0.74, 0.66, 0.45)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)

	title_label.add_theme_font_override("font", font_title)
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))

	hint_label.add_theme_font_override("font", font_body)
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.78, 0.75, 0.66))

	_style_button(back_button)


func _style_button(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.09, 0.1, 0.13)
	normal.border_color = Color(0.6, 0.52, 0.34)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.13, 0.15, 0.2)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.18, 0.2, 0.26)
	pressed.border_color = Color(0.85, 0.74, 0.48)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", Color(0.9, 0.86, 0.76))
	btn.add_theme_color_override("font_hover_color", Color(0.98, 0.92, 0.7))
	btn.add_theme_color_override("font_pressed_color", Color(0.98, 0.92, 0.7))
	btn.add_theme_font_override("font", font_body)
	btn.add_theme_font_size_override("font_size", 16)


func _build_slots() -> void:
	for child in slots_vbox.get_children():
		child.queue_free()

	for slot in range(1, SLOT_COUNT + 1):
		var info := {}
		if game_manager and game_manager.has_method("get_save_slot_info"):
			info = game_manager.get_save_slot_info(slot)
		var btn := Button.new()
		btn.name = "Slot%d" % slot
		btn.custom_minimum_size = Vector2(420, 38)
		btn.text = _slot_text(slot, info)
		btn.disabled = info.is_empty()
		btn.focus_mode = Control.FOCUS_ALL
		_style_button(btn)
		if not btn.disabled:
			btn.pressed.connect(_on_slot_pressed.bind(slot))
		slots_vbox.add_child(btn)


func _slot_text(slot: int, info: Dictionary) -> String:
	if info.is_empty():
		return "Chronique %d - vide" % slot
	var chronicle := str(info.get("chronicle_name", ""))
	if chronicle == "":
		chronicle = str(info.get("name", "Chronique %d" % slot))
	var floor = int(info.get("floor", 0))
	return "Chronique %d - %s (etage %d)" % [slot, chronicle, floor]


func _on_slot_pressed(slot: int) -> void:
	if game_manager and game_manager.has_method("load_from_slot"):
		var ok: bool = game_manager.load_from_slot(slot)
		if ok:
			_go_to_scene(GAME_SCENE)
			return
	_show_message("Chronique introuvable.")


func _on_back_pressed() -> void:
	_go_to_scene(MENU_SCENE)


func _go_to_scene(scene_path: String) -> void:
	if scene_path == "":
		return
	if not ResourceLoader.exists(scene_path):
		_show_message("Scene introuvable.")
		return
	get_tree().change_scene_to_file(scene_path)


func _show_message(text: String) -> void:
	var msg := Label.new()
	msg.text = text
	msg.add_theme_font_override("font", font_body)
	msg.add_theme_font_size_override("font_size", 16)
	msg.add_theme_color_override("font_color", Color(0.95, 0.6, 0.5))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.set_anchors_preset(Control.PRESET_CENTER)
	msg.position.y += 150
	msg.modulate.a = 0.0
	add_child(msg)
	var tween = create_tween()
	tween.tween_property(msg, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.2)
	tween.tween_property(msg, "modulate:a", 0.0, 0.2)
	tween.tween_callback(msg.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
