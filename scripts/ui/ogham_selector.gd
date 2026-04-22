class_name OghamSelector
extends Control

## CRT-styled ogham selection overlay for pre-run loadout.
## Bible s.2.2: "Le joueur equipe 1 Ogham au debut de chaque run"
## Shows unlocked oghams in a scrollable grid. Tap to select, confirm to start.

signal ogham_selected(ogham_key: String)
signal selector_dismissed

# === CATEGORY VISUAL MAPPING ===

const CATEGORY_COLORS := {
	"reveal": Color(0.3, 0.85, 0.85),
	"protection": Color(0.4, 0.55, 0.95),
	"boost": Color(0.3, 0.85, 0.35),
	"narrative": Color(0.85, 0.7, 0.2),
	"recovery": Color(0.85, 0.3, 0.35),
	"special": Color(0.7, 0.35, 0.85),
}

const CATEGORY_GLYPHS := {
	"reveal": "◈",
	"protection": "◆",
	"boost": "▲",
	"narrative": "✦",
	"recovery": "♥",
	"special": "✧",
}

# === LAYOUT ===

const COLUMNS := 3
const CARD_W := 140
const CARD_H := 170
const CARD_GAP := 12
const PANEL_PAD := 20

# === STATE ===

var _selected_key: String = ""
var _available_oghams: Array = []
var _cards: Dictionary = {}
var _confirm_btn: Button = null
var _title_label: Label = null
var _panel: PanelContainer = null
var _grid: GridContainer = null
var _bg: ColorRect = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open(last_ogham: String = "") -> void:
	_build_ui()
	_populate_oghams()
	if not last_ogham.is_empty() and _cards.has(last_ogham):
		_select_ogham(last_ogham)
	elif _available_oghams.size() > 0:
		_select_ogham(_available_oghams[0])
	visible = true
	SFXManager.play("ogham_chime")


func close() -> void:
	visible = false
	selector_dismissed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		accept_event()


# === UI CONSTRUCTION ===

func _build_ui() -> void:
	if _bg != null:
		return

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.0, 0.0, 0.0, 0.7)
	add_child(_bg)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.08
	_panel.anchor_right = 0.92
	_panel.anchor_top = 0.06
	_panel.anchor_bottom = 0.94
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.02, 0.92)
	sb.border_color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(PANEL_PAD)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "CHOISIR UNE RUNE"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_font: Font = MerlinVisual.get_font("celtic")
	if title_font:
		_title_label.add_theme_font_override("font", title_font)
	_title_label.add_theme_font_size_override("font_size", MerlinVisual.responsive_size(28))
	_title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_bright"])
	vbox.add_child(_title_label)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Cette rune t'accompagnera durant ta marche"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MerlinVisual.apply_responsive_font(subtitle, 14)
	subtitle.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])
	vbox.add_child(subtitle)

	# Scroll container for the grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", CARD_GAP)
	_grid.add_theme_constant_override("v_separation", CARD_GAP)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	# Confirm button
	_confirm_btn = Button.new()
	_confirm_btn.text = "PARTIR"
	_confirm_btn.custom_minimum_size = Vector2(200, 48)
	_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_btn.focus_mode = Control.FOCUS_ALL

	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.1, 0.25, 0.1, 0.9)
	btn_sb.border_color = MerlinVisual.CRT_PALETTE["phosphor_bright"]
	btn_sb.set_border_width_all(2)
	btn_sb.set_corner_radius_all(3)
	btn_sb.set_content_margin_all(8)
	_confirm_btn.add_theme_stylebox_override("normal", btn_sb)

	var btn_hover := btn_sb.duplicate()
	btn_hover.bg_color = Color(0.15, 0.35, 0.15, 0.95)
	_confirm_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed := btn_sb.duplicate()
	btn_pressed.bg_color = Color(0.2, 0.5, 0.2, 1.0)
	_confirm_btn.add_theme_stylebox_override("pressed", btn_pressed)

	var btn_font: Font = MerlinVisual.get_font("celtic")
	if btn_font:
		_confirm_btn.add_theme_font_override("font", btn_font)
	_confirm_btn.add_theme_font_size_override("font_size", MerlinVisual.responsive_size(22))
	_confirm_btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_bright"])
	_confirm_btn.pressed.connect(_on_confirm)
	vbox.add_child(_confirm_btn)


# === POPULATION ===

func _populate_oghams() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()
	_available_oghams.clear()

	var store: Node = get_node_or_null("/root/MerlinStore")
	var unlocked: Array = MerlinConstants.OGHAM_STARTER_SKILLS.duplicate()
	if store:
		var oghams_state: Dictionary = store.state.get("oghams", {})
		var extra: Array = oghams_state.get("skills_unlocked", [])
		for sk: String in extra:
			if not unlocked.has(sk):
				unlocked.append(sk)

	# Sort: starters first, then by category
	var sorted_keys: Array = []
	for key: String in MerlinConstants.OGHAM_FULL_SPECS:
		if unlocked.has(key):
			sorted_keys.append(key)
	sorted_keys.sort_custom(func(a: String, b: String) -> bool:
		var sa: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(a, {})
		var sb2: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(b, {})
		if sa.get("starter", false) != sb2.get("starter", false):
			return sa.get("starter", false)
		return str(sa.get("category", "")) < str(sb2.get("category", ""))
	)

	_available_oghams = sorted_keys

	for key: String in sorted_keys:
		var card: PanelContainer = _build_ogham_card(key)
		_grid.add_child(card)
		_cards[key] = card


func _build_ogham_card(ogham_key: String) -> PanelContainer:
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_key, {})
	var category: String = str(spec.get("category", "special"))
	var cat_color: Color = CATEGORY_COLORS.get(category, Color.WHITE)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.04, 0.85)
	sb.border_color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Unicode glyph (large)
	var glyph_label := Label.new()
	glyph_label.text = str(spec.get("unicode", "?"))
	glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_label.add_theme_font_size_override("font_size", MerlinVisual.responsive_size(36))
	glyph_label.add_theme_color_override("font_color", cat_color)
	vbox.add_child(glyph_label)

	# Name
	var name_label := Label.new()
	name_label.text = str(spec.get("name", ogham_key))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MerlinVisual.apply_responsive_font(name_label, 16)
	name_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_bright"])
	vbox.add_child(name_label)

	# Category tag
	var tag_label := Label.new()
	var cat_glyph: String = CATEGORY_GLYPHS.get(category, "?")
	tag_label.text = "%s %s" % [cat_glyph, category.to_upper()]
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MerlinVisual.apply_responsive_font(tag_label, 10)
	tag_label.add_theme_color_override("font_color", cat_color)
	vbox.add_child(tag_label)

	# Description (truncated)
	var desc_label := Label.new()
	var desc_text: String = str(spec.get("description", ""))
	if desc_text.length() > 50:
		desc_text = desc_text.left(47) + "..."
	desc_label.text = desc_text
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MerlinVisual.apply_responsive_font(desc_label, 10)
	desc_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.6))
	vbox.add_child(desc_label)

	# Cooldown
	var cd_label := Label.new()
	var cooldown: int = int(spec.get("cooldown", 3))
	cd_label.text = "⏱ %d tours" % cooldown
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MerlinVisual.apply_responsive_font(cd_label, 10)
	cd_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])
	vbox.add_child(cd_label)

	# Click handler
	card.gui_input.connect(_on_card_input.bind(ogham_key))
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	return card


# === INTERACTION ===

func _on_card_input(event: InputEvent, ogham_key: String) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_select_ogham(ogham_key)
			SFXManager.play("hover")


func _select_ogham(ogham_key: String) -> void:
	_selected_key = ogham_key

	for key: String in _cards:
		var card: PanelContainer = _cards[key]
		var sb: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
		if sb == null:
			continue
		if key == ogham_key:
			var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(key, {})
			var cat: String = str(spec.get("category", "special"))
			sb.border_color = CATEGORY_COLORS.get(cat, Color.WHITE)
			sb.set_border_width_all(2)
			sb.bg_color = Color(0.06, 0.1, 0.06, 0.95)
		else:
			sb.border_color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
			sb.set_border_width_all(1)
			sb.bg_color = Color(0.04, 0.06, 0.04, 0.85)

	_confirm_btn.text = "PARTIR  ᚋ"


func _on_confirm() -> void:
	if _selected_key.is_empty():
		return
	SFXManager.play("partir_fanfare")
	visible = false
	ogham_selected.emit(_selected_key)
