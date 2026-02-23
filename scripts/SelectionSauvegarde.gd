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
	font_title = MerlinVisual.get_font("title")
	if font_title == null:
		font_title = ThemeDB.fallback_font
	font_body = MerlinVisual.get_font("body")
	if font_body == null:
		font_body = ThemeDB.fallback_font


func _apply_theme() -> void:
	# CRT terminal background
	var bg := get_node_or_null("Background")
	if bg is ColorRect:
		bg.color = MerlinVisual.CRT_PALETTE["bg_dark"]

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = MerlinVisual.CRT_PALETTE["bg_panel"]
	panel_style.border_color = MerlinVisual.CRT_PALETTE["border"]
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel_style.shadow_color = MerlinVisual.CRT_PALETTE["shadow"]
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", panel_style)

	title_label.add_theme_font_override("font", font_title)
	title_label.add_theme_font_size_override("font_size", 30)
	var title_color: Color = MerlinVisual.CRT_PALETTE["phosphor"]
	title_label.add_theme_color_override("font_color", title_color)

	hint_label.add_theme_font_override("font", font_body)
	hint_label.add_theme_font_size_override("font_size", 14)
	var hint_color: Color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
	hint_label.add_theme_color_override("font_color", hint_color)

	_style_button(back_button)


func _style_button(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = MerlinVisual.CRT_PALETTE["bg_panel"]
	normal.border_color = MerlinVisual.CRT_PALETTE["border"]
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover := normal.duplicate()
	hover.bg_color = MerlinVisual.CRT_PALETTE["bg_dark"]
	hover.border_color = MerlinVisual.CRT_PALETTE["amber"]

	var pressed := normal.duplicate()
	pressed.bg_color = MerlinVisual.CRT_PALETTE["bg_highlight"]
	pressed.border_color = MerlinVisual.CRT_PALETTE["amber"]

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	var btn_font_color: Color = MerlinVisual.CRT_PALETTE["phosphor"]
	var btn_accent_color: Color = MerlinVisual.CRT_PALETTE["amber"]
	btn.add_theme_color_override("font_color", btn_font_color)
	btn.add_theme_color_override("font_hover_color", btn_accent_color)
	btn.add_theme_color_override("font_pressed_color", btn_accent_color)
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
	var msg_color: Color = MerlinVisual.CRT_PALETTE["danger"]
	msg.add_theme_color_override("font_color", msg_color)
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
