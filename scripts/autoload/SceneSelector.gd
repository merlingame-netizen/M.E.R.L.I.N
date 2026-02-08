extends CanvasLayer
## SceneSelector - Debug scene navigation dropdown
## Autoload singleton that provides a small dropdown in the top-right corner
## to quickly jump between scenes during development.

# === SCENE REGISTRY ===
const SCENES: Array[Dictionary] = [
	# — Intro —
	{"label": "IntroCeltOS (Boot)", "path": "res://scenes/IntroCeltOS.tscn"},
	{"label": "IntroPersonalityQuiz", "path": "res://scenes/IntroPersonalityQuiz.tscn"},
	{"label": "IntroMerlinDialogue", "path": "res://scenes/IntroMerlinDialogue.tscn"},
	{"label": "SceneEveil", "path": "res://scenes/SceneEveil.tscn"},
	{"label": "SceneAntreMerlin", "path": "res://scenes/SceneAntreMerlin.tscn"},
	{"label": "TransitionBiome", "path": "res://scenes/TransitionBiome.tscn"},
	{"label": "HubAntre", "path": "res://scenes/HubAntre.tscn"},
	# — Menus —
	{"label": "MenuPrincipal", "path": "res://scenes/MenuPrincipal.tscn"},
	{"label": "MenuOptions", "path": "res://scenes/MenuOptions.tscn"},
	{"label": "SelectionSauvegarde", "path": "res://scenes/SelectionSauvegarde.tscn"},
	# — Gameplay —
	{"label": "TriadeGame", "path": "res://scenes/TriadeGame.tscn"},
	{"label": "GameMain", "path": "res://scenes/GameMain.tscn"},
	# — Collections —
	{"label": "Calendar", "path": "res://scenes/Calendar.tscn"},
	{"label": "Collection", "path": "res://scenes/Collection.tscn"},
	# — Test —
	{"label": "TestLLMSceneUltimate", "path": "res://scenes/TestLLMSceneUltimate.tscn"},
	{"label": "LLM Benchmark", "path": "res://scenes/TestLLMBenchmark.tscn"},
]

# === NODES ===
var _toggle_btn: Button
var _dropdown: PanelContainer
var _list: VBoxContainer
var _is_open: bool = false

# === LIFECYCLE ===

func _ready() -> void:
	layer = 101  # Above ScreenEffects (100), always on top
	_build_ui()


func _build_ui() -> void:
	# --- Toggle button (top-right) ---
	_toggle_btn = Button.new()
	_toggle_btn.text = "Scenes"
	_toggle_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_toggle_btn.custom_minimum_size = Vector2(70, 28)
	_toggle_btn.pressed.connect(_toggle_dropdown)

	# Style the toggle button
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	btn_style.border_color = Color(0.4, 0.4, 0.4, 0.6)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn_style.content_margin_left = 8
	btn_style.content_margin_right = 8
	btn_style.content_margin_top = 4
	btn_style.content_margin_bottom = 4
	_toggle_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.25, 0.25, 0.9)
	_toggle_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed := btn_style.duplicate()
	btn_pressed.bg_color = Color(0.3, 0.3, 0.3, 0.95)
	_toggle_btn.add_theme_stylebox_override("pressed", btn_pressed)

	_toggle_btn.add_theme_font_size_override("font_size", 12)
	_toggle_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

	# Position: top-right with margin
	var btn_container := Control.new()
	btn_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_container.offset_left = -80
	btn_container.offset_top = 8
	btn_container.offset_right = -8
	btn_container.offset_bottom = 36
	btn_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toggle_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn_container.add_child(_toggle_btn)
	add_child(btn_container)

	# --- Dropdown panel ---
	_dropdown = PanelContainer.new()
	_dropdown.visible = false

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.92)
	panel_style.border_color = Color(0.35, 0.35, 0.35, 0.7)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 4
	panel_style.content_margin_right = 4
	panel_style.content_margin_top = 4
	panel_style.content_margin_bottom = 4
	_dropdown.add_theme_stylebox_override("panel", panel_style)

	# Scrollable list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(200, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)

	# Populate scene buttons
	var current_path := _get_current_scene_path()
	for i in SCENES.size():
		var scene_data: Dictionary = SCENES[i]
		var btn := Button.new()
		btn.text = scene_data["label"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(192, 26)
		btn.pressed.connect(_on_scene_selected.bind(i))

		# Style each scene button
		var item_style := StyleBoxFlat.new()
		item_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		item_style.content_margin_left = 6
		item_style.content_margin_right = 6
		item_style.content_margin_top = 2
		item_style.content_margin_bottom = 2
		item_style.set_corner_radius_all(3)
		btn.add_theme_stylebox_override("normal", item_style)

		var item_hover := item_style.duplicate()
		item_hover.bg_color = Color(0.3, 0.3, 0.3, 0.5)
		btn.add_theme_stylebox_override("hover", item_hover)

		var item_pressed := item_style.duplicate()
		item_pressed.bg_color = Color(0.4, 0.4, 0.4, 0.6)
		btn.add_theme_stylebox_override("pressed", item_pressed)

		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))

		# Highlight current scene
		if scene_data["path"] == current_path:
			btn.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
			btn.text = "> " + btn.text

		_list.add_child(btn)

	scroll.add_child(_list)
	_dropdown.add_child(scroll)

	# Position dropdown below the toggle button
	var dropdown_container := Control.new()
	dropdown_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dropdown_container.offset_left = -212
	dropdown_container.offset_top = 40
	dropdown_container.offset_right = -8
	dropdown_container.offset_bottom = 440
	dropdown_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dropdown.set_anchors_preset(Control.PRESET_FULL_RECT)
	dropdown_container.add_child(_dropdown)
	add_child(dropdown_container)


func _toggle_dropdown() -> void:
	_is_open = not _is_open
	_dropdown.visible = _is_open
	_toggle_btn.text = "X" if _is_open else "Scenes"

	if _is_open:
		_refresh_current_highlight()


func _on_scene_selected(index: int) -> void:
	var scene_path: String = SCENES[index]["path"]
	_is_open = false
	_dropdown.visible = false
	_toggle_btn.text = "Scenes"
	get_tree().change_scene_to_file(scene_path)


func _refresh_current_highlight() -> void:
	var current_path := _get_current_scene_path()
	for i in _list.get_child_count():
		var btn: Button = _list.get_child(i) as Button
		var scene_data: Dictionary = SCENES[i]
		if scene_data["path"] == current_path:
			btn.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
			btn.text = "> " + scene_data["label"]
		else:
			btn.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
			btn.text = scene_data["label"]


func _get_current_scene_path() -> String:
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.scene_file_path:
		return current_scene.scene_file_path
	return ""


# Close dropdown when clicking outside
func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventMouseButton and event.pressed:
		# Check if click is outside the dropdown area
		var viewport_size := get_viewport().get_visible_rect().size
		var click_pos: Vector2 = event.position
		var dropdown_rect := Rect2(
			viewport_size.x - 212, 40,
			204, 400
		)
		var btn_rect := Rect2(
			viewport_size.x - 80, 8,
			72, 28
		)
		if not dropdown_rect.has_point(click_pos) and not btn_rect.has_point(click_pos):
			_is_open = false
			_dropdown.visible = false
			_toggle_btn.text = "Scenes"
