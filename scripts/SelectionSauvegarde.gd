extends Control

const MENU_SCENE_FALLBACK := "res://scenes/MerlinCabinHub.tscn"
const GAME_SCENE := "res://scenes/MerlinCabinHub.tscn"

@onready var panel: PanelContainer = $RootPanel
@onready var title_label: Label = $RootPanel/RootVBox/Title
@onready var hint_label: Label = $RootPanel/RootVBox/Hint
@onready var slots_vbox: VBoxContainer = $RootPanel/RootVBox/Slots
@onready var back_button: Button = $RootPanel/RootVBox/BackButton

var _save := MerlinSaveSystem.new()
var font_title: Font
var font_body: Font

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_load_fonts()
	_apply_theme()
	back_button.pressed.connect(_on_back_pressed)
	# Auto-continue (Hades-style): skip UI, load profile and go
	_auto_continue()


func _load_fonts() -> void:
	font_title = MerlinVisual.get_font("title")
	if font_title == null:
		font_title = ThemeDB.fallback_font
	font_body = MerlinVisual.get_font("body")
	if font_body == null:
		font_body = ThemeDB.fallback_font


func _apply_theme() -> void:
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


func _auto_continue() -> void:
	if _save.profile_exists():
		var store: Node = get_node_or_null("/root/MerlinStore")
		if store and store.has_method("dispatch"):
			var result = await store.dispatch({"type": "LOAD_PROFILE"})
			if result is Dictionary and result.get("ok", false):
				_go_to_scene(GAME_SCENE)
				return
		# Fallback: profile exists but load failed — show UI
		_build_profile_ui()
	else:
		# No profile: go directly, store will create default state
		_go_to_scene(GAME_SCENE)


func _build_profile_ui() -> void:
	for child in slots_vbox.get_children():
		child.queue_free()

	if _save.profile_exists():
		var info: Dictionary = _save.get_profile_info()

		# Profile stats label
		var stats_lbl := Label.new()
		var anam: int = int(info.get("anam", 0))
		var runs: int = int(info.get("total_runs", 0))
		var talents: int = int(info.get("talents_unlocked", 0))
		var endings: int = int(info.get("endings_seen", 0))
		stats_lbl.text = "Anam: %d | Runs: %d | Talents: %d | Fins: %d" % [anam, runs, talents, endings]
		stats_lbl.add_theme_font_override("font", font_body)
		stats_lbl.add_theme_font_size_override("font_size", 14)
		stats_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])
		stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slots_vbox.add_child(stats_lbl)

		# Continue button
		var continue_btn := Button.new()
		continue_btn.name = "ContinueBtn"
		continue_btn.text = "Continuer"
		continue_btn.custom_minimum_size = Vector2(420, 42)
		continue_btn.focus_mode = Control.FOCUS_ALL
		_style_button(continue_btn)
		continue_btn.pressed.connect(_on_continue_pressed)
		slots_vbox.add_child(continue_btn)

		# Reset button
		var reset_btn := Button.new()
		reset_btn.name = "ResetBtn"
		reset_btn.text = "Reinitialiser le profil"
		reset_btn.custom_minimum_size = Vector2(420, 38)
		_style_button(reset_btn)
		reset_btn.pressed.connect(_on_reset_pressed)
		slots_vbox.add_child(reset_btn)
	else:
		# New game button
		var new_btn := Button.new()
		new_btn.name = "NewGameBtn"
		new_btn.text = "Nouvelle partie"
		new_btn.custom_minimum_size = Vector2(420, 42)
		new_btn.focus_mode = Control.FOCUS_ALL
		_style_button(new_btn)
		new_btn.pressed.connect(_on_new_game_pressed)
		slots_vbox.add_child(new_btn)


func _on_continue_pressed() -> void:
	var store: Node = get_node_or_null("/root/MerlinStore")
	if store and store.has_method("dispatch"):
		var result = await store.dispatch({"type": "LOAD_PROFILE"})
		if result is Dictionary and result.get("ok", false):
			_go_to_scene(GAME_SCENE)
			return
	_show_message("Profil introuvable.")


func _on_new_game_pressed() -> void:
	_go_to_scene(GAME_SCENE)


func _on_reset_pressed() -> void:
	# Confirmation: build a simple confirm dialog
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "Reinitialiser le profil ?\nToute la progression sera perdue."
	confirm.ok_button_text = "Confirmer"
	confirm.cancel_button_text = "Annuler"
	confirm.confirmed.connect(func():
		_save.reset_profile()
		_build_profile_ui()
	)
	add_child(confirm)
	confirm.popup_centered()


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
		var tween := create_tween()
		tween.tween_property(msg, "modulate:a", 1.0, 0.2)
		tween.tween_interval(1.2)
		tween.tween_property(msg, "modulate:a", 0.0, 0.2)
		tween.tween_callback(msg.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
