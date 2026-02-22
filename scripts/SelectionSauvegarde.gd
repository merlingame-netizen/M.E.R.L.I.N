extends Control

const SLOT_COUNT := 3
const MENU_SCENE_FALLBACK := "res://scenes/HubAntre.tscn"
const GAME_SCENE := "res://scenes/HubAntre.tscn"

@onready var panel: PanelContainer = $RootPanel
@onready var title_label: Label = $RootPanel/RootVBox/Title
@onready var hint_label: Label = $RootPanel/RootVBox/Hint
@onready var slots_vbox: VBoxContainer = $RootPanel/RootVBox/Slots
@onready var back_button: Button = $RootPanel/RootVBox/BackButton

var game_manager: Node = null
var _merlin_save := MerlinSaveSystem.new()
var font_title: Font
var font_body: Font

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
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
	# Parchment background (override dark .tscn background)
	var bg := get_node_or_null("Background")
	if bg is ColorRect:
		bg.color = Color(0.965, 0.945, 0.905)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.955, 0.930, 0.890)
	panel_style.border_color = Color(0.40, 0.34, 0.28, 0.25)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel_style.shadow_color = Color(0.25, 0.20, 0.16, 0.18)
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", panel_style)

	title_label.add_theme_font_override("font", font_title)
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14))

	hint_label.add_theme_font_override("font", font_body)
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.50, 0.44, 0.38))

	_style_button(back_button)


func _style_button(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.955, 0.930, 0.890)
	normal.border_color = Color(0.40, 0.34, 0.28, 0.20)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover := normal.duplicate()
	hover.bg_color = Color(0.935, 0.905, 0.855)
	hover.border_color = Color(0.58, 0.44, 0.26)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.92, 0.89, 0.84)
	pressed.border_color = Color(0.58, 0.44, 0.26)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14))
	btn.add_theme_color_override("font_hover_color", Color(0.58, 0.44, 0.26))
	btn.add_theme_color_override("font_pressed_color", Color(0.58, 0.44, 0.26))
	btn.add_theme_font_override("font", font_body)
	btn.add_theme_font_size_override("font_size", 16)


func _build_slots() -> void:
	for child in slots_vbox.get_children():
		child.queue_free()

	for slot in range(1, SLOT_COUNT + 1):
		var info := {}
		# Try MerlinSaveSystem first (TRIADE saves)
		if _merlin_save.slot_exists(slot):
			info = _merlin_save.get_slot_info(slot)
		elif game_manager and game_manager.has_method("get_save_slot_info"):
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

	# Autosave slot
	if _merlin_save.autosave_exists():
		var auto_info := _merlin_save.get_autosave_info()
		if not auto_info.is_empty():
			var btn := Button.new()
			btn.name = "SlotAutosave"
			btn.custom_minimum_size = Vector2(420, 38)
			btn.text = _slot_text_autosave(auto_info)
			btn.focus_mode = Control.FOCUS_ALL
			_style_button(btn)
			btn.pressed.connect(_on_autosave_pressed)
			slots_vbox.add_child(btn)


func _slot_text(slot: int, info: Dictionary) -> String:
	if info.is_empty():
		return "Chronique %d - vide" % slot
	# TRIADE format
	if info.has("mode") and str(info.get("mode", "")) == "triade":
		var cards: int = int(info.get("cards_played", 0))
		var ts: int = int(info.get("timestamp", 0))
		var date_str := ""
		if ts > 0:
			var dt := Time.get_datetime_dict_from_unix_time(ts)
			date_str = " (%02d/%02d)" % [int(dt.get("day", 0)), int(dt.get("month", 0))]
		return "Chronique %d - %d cartes%s" % [slot, cards, date_str]
	# Legacy format
	var chronicle := str(info.get("chronicle_name", ""))
	if chronicle == "":
		chronicle = str(info.get("name", "Chronique %d" % slot))
	var floor_val = int(info.get("floor", 0))
	return "Chronique %d - %s (etage %d)" % [slot, chronicle, floor_val]


func _slot_text_autosave(info: Dictionary) -> String:
	var cards: int = int(info.get("cards_played", 0))
	var ts: int = int(info.get("timestamp", 0))
	var date_str := ""
	if ts > 0:
		var dt := Time.get_datetime_dict_from_unix_time(ts)
		date_str = " (%02d/%02d %02d:%02d)" % [int(dt.get("day", 0)), int(dt.get("month", 0)), int(dt.get("hour", 0)), int(dt.get("minute", 0))]
	return "Sauvegarde auto - %d cartes%s" % [cards, date_str]


func _on_slot_pressed(slot: int) -> void:
	# Try MerlinStore first (TRIADE system)
	var store := _find_merlin_store()
	if store and store.has_method("dispatch"):
		var result = await store.dispatch({"type": "LOAD_SLOT", "slot": slot})
		if result is Dictionary and result.get("ok", false):
			_go_to_scene(GAME_SCENE)
			return
	# Fall back to legacy GameManager
	if game_manager and game_manager.has_method("load_from_slot"):
		var ok: bool = game_manager.load_from_slot(slot)
		if ok:
			_go_to_scene(GAME_SCENE)
			return
	_show_message("Chronique introuvable.")


func _on_autosave_pressed() -> void:
	var store := _find_merlin_store()
	if store and store.has_method("dispatch"):
		var result = await store.dispatch({"type": "LOAD_AUTOSAVE"})
		if result is Dictionary and result.get("ok", false):
			_go_to_scene(GAME_SCENE)
			return
	_show_message("Sauvegarde auto introuvable.")


func _find_merlin_store() -> Node:
	return get_node_or_null("/root/MerlinStore")


func _on_back_pressed() -> void:
	var se := get_node_or_null("/root/ScreenEffects")
	var target: String = se.return_scene if se and se.return_scene != "" else MENU_SCENE_FALLBACK
	_go_to_scene(target)


func _go_to_scene(scene_path: String) -> void:
	if scene_path == "":
		return
	if not ResourceLoader.exists(scene_path):
		_show_message("Scene introuvable.")
		return
	PixelTransition.transition_to(scene_path)


func _show_message(text: String) -> void:
	var msg := Label.new()
	msg.text = text
	msg.add_theme_font_override("font", font_body)
	msg.add_theme_font_size_override("font_size", 16)
	msg.add_theme_color_override("font_color", Color(0.72, 0.28, 0.22))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.set_anchors_preset(Control.PRESET_CENTER)
	msg.position.y += 150
	msg.modulate.a = 0.0
	add_child(msg)
	var pca: Node = get_node_or_null("/root/PixelContentAnimator")
	if pca:
		await get_tree().process_frame
		pca.reveal(msg, {"duration": 0.25, "block_size": 6})
		await get_tree().create_timer(1.4).timeout
		pca.dissolve(msg, {"duration": 0.25, "block_size": 6})
		await get_tree().create_timer(0.3).timeout
		msg.queue_free()
	else:
		var tween = create_tween()
		tween.tween_property(msg, "modulate:a", 1.0, 0.2)
		tween.tween_interval(1.2)
		tween.tween_property(msg, "modulate:a", 0.0, 0.2)
		tween.tween_callback(msg.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
