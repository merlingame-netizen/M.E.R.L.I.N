## ═══════════════════════════════════════════════════════════════════════════════
## HubScreen — Hub 2D main screen between runs (Phase 7, DEV_PLAN_V2.5)
## ═══════════════════════════════════════════════════════════════════════════════
## Displays player profile, faction reputation, biome selection, ogham loadout,
## and navigation to talent tree / save & quit.
## Scene flow: Hub 2D -> [Choose biome + Ogham] -> Run 3D -> [End] -> Hub 2D
## Colors from MerlinVisual.CRT_PALETTE. Data from MerlinStore state.
## ═══════════════════════════════════════════════════════════════════════════════

extends Control
class_name HubScreen

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ═══════════════════════════════════════════════════════════════════════════════

signal run_requested(biome_id: String, selected_oghams: Array)
signal talent_tree_requested()
signal quit_requested()

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const MAX_OGHAM_SELECTION: int = 3
const PANEL_MARGIN: int = 12
const SECTION_SPACING: int = 8

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _player_name: String = ""
var _anam: int = 0
var _total_runs: int = 0
var _faction_rep: Dictionary = {}
var _unlocked_oghams: Array = []
var _selected_oghams: Array = []
var _biomes_data: Array = []
var _locked_biomes: Array = []
var _selected_biome: String = ""
var _maturity_score: int = 0

# ═══════════════════════════════════════════════════════════════════════════════
# UI NODES
# ═══════════════════════════════════════════════════════════════════════════════

var _root_vbox: VBoxContainer
var _header_panel: PanelContainer
var _player_name_label: Label
var _anam_label: Label
var _runs_label: Label
var _maturity_label: Label

# Faction bars
var _faction_container: VBoxContainer
var _faction_bars: Dictionary = {}

# Biome grid
var _biome_section_label: Label
var _biome_grid: GridContainer
var _biome_buttons: Dictionary = {}

# Ogham selection
var _ogham_section_label: Label
var _ogham_grid: GridContainer
var _ogham_buttons: Dictionary = {}
var _ogham_count_label: Label

# Action buttons
var _start_button: Button
var _talent_button: Button
var _quit_button: Button

# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_build_ui()
	_apply_root_style()


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func setup(data: Dictionary) -> void:
	_player_name = str(data.get("player_name", "Druide"))
	_anam = int(data.get("anam", 0))
	_total_runs = int(data.get("total_runs", 0))
	_faction_rep = data.get("faction_rep", {}).duplicate()
	_unlocked_oghams = data.get("unlocked_oghams", []).duplicate()
	_selected_oghams = data.get("selected_oghams", []).duplicate()
	_maturity_score = int(data.get("maturity_score", 0))

	var biomes_raw: Array = data.get("biomes", [])
	_biomes_data = biomes_raw.duplicate()
	var locked_raw: Array = data.get("locked_biomes", [])
	_locked_biomes = locked_raw.duplicate()

	if _selected_oghams.size() > MAX_OGHAM_SELECTION:
		_selected_oghams.resize(MAX_OGHAM_SELECTION)

	# Default biome selection
	if _selected_biome == "" and _biomes_data.size() > 0:
		_selected_biome = str(_biomes_data[0].get("id", ""))

	_refresh_all()


func get_selected_biome() -> String:
	return _selected_biome


func get_selected_oghams() -> Array:
	return _selected_oghams.duplicate()


func get_ogham_count() -> int:
	return _selected_oghams.size()


func is_ogham_selected(ogham_id: String) -> bool:
	return _selected_oghams.has(ogham_id)


func can_start_run() -> bool:
	return _selected_biome != "" and _selected_oghams.size() > 0


# ═══════════════════════════════════════════════════════════════════════════════
# UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_root_vbox = VBoxContainer.new()
	_root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.add_theme_constant_override("separation", SECTION_SPACING)
	scroll.add_child(_root_vbox)

	_build_header()
	_build_faction_section()
	_build_biome_section()
	_build_ogham_section()
	_build_action_buttons()


func _build_header() -> void:
	_header_panel = PanelContainer.new()
	var style: StyleBoxFlat = _make_section_style()
	_header_panel.add_theme_stylebox_override("panel", style)
	_root_vbox.add_child(_header_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_header_panel.add_child(vbox)

	# Title
	var title: Label = _make_label("=== L'ANTRE DE MERLIN ===", 18)
	var amber: Color = MerlinVisual.CRT_PALETTE["amber"]
	title.add_theme_color_override("font_color", amber)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Player info row
	var info_hbox: HBoxContainer = HBoxContainer.new()
	info_hbox.add_theme_constant_override("separation", 16)
	info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(info_hbox)

	_player_name_label = _make_label("", 14)
	info_hbox.add_child(_player_name_label)

	_anam_label = _make_label("", 14)
	info_hbox.add_child(_anam_label)

	_runs_label = _make_label("", 12)
	info_hbox.add_child(_runs_label)

	_maturity_label = _make_label("", 12)
	info_hbox.add_child(_maturity_label)


func _build_faction_section() -> void:
	var section: PanelContainer = PanelContainer.new()
	section.add_theme_stylebox_override("panel", _make_section_style())
	_root_vbox.add_child(section)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	section.add_child(vbox)

	var title: Label = _make_label("[ REPUTATIONS ]", 14)
	var amber: Color = MerlinVisual.CRT_PALETTE["amber_dim"]
	title.add_theme_color_override("font_color", amber)
	vbox.add_child(title)

	_faction_container = VBoxContainer.new()
	_faction_container.add_theme_constant_override("separation", 2)
	vbox.add_child(_faction_container)

	# Create 5 faction bars
	for faction_id in MerlinConstants.FACTIONS:
		var bar: FactionRepBar = FactionRepBar.new()
		_faction_container.add_child(bar)
		_faction_bars[faction_id] = bar


func _build_biome_section() -> void:
	var section: PanelContainer = PanelContainer.new()
	section.add_theme_stylebox_override("panel", _make_section_style())
	_root_vbox.add_child(section)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	section.add_child(vbox)

	_biome_section_label = _make_label("[ BIOMES ]", 14)
	var amber: Color = MerlinVisual.CRT_PALETTE["amber_dim"]
	_biome_section_label.add_theme_color_override("font_color", amber)
	vbox.add_child(_biome_section_label)

	_biome_grid = GridContainer.new()
	_biome_grid.columns = 4
	_biome_grid.add_theme_constant_override("h_separation", 6)
	_biome_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_biome_grid)


func _build_ogham_section() -> void:
	var section: PanelContainer = PanelContainer.new()
	section.add_theme_stylebox_override("panel", _make_section_style())
	_root_vbox.add_child(section)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	section.add_child(vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(header_hbox)

	_ogham_section_label = _make_label("[ OGHAMS ]", 14)
	var amber: Color = MerlinVisual.CRT_PALETTE["amber_dim"]
	_ogham_section_label.add_theme_color_override("font_color", amber)
	header_hbox.add_child(_ogham_section_label)

	_ogham_count_label = _make_label("", 12)
	header_hbox.add_child(_ogham_count_label)

	_ogham_grid = GridContainer.new()
	_ogham_grid.columns = 6
	_ogham_grid.add_theme_constant_override("h_separation", 4)
	_ogham_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_ogham_grid)


func _build_action_buttons() -> void:
	var section: PanelContainer = PanelContainer.new()
	section.add_theme_stylebox_override("panel", _make_section_style())
	_root_vbox.add_child(section)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	section.add_child(hbox)

	_start_button = _make_action_button(">> PARTIR EN RUN <<")
	_start_button.pressed.connect(_on_start_pressed)
	hbox.add_child(_start_button)

	_talent_button = _make_action_button("ARBRE DE VIE")
	_talent_button.pressed.connect(_on_talent_pressed)
	hbox.add_child(_talent_button)

	_quit_button = _make_action_button("SAUVER & QUITTER")
	_quit_button.pressed.connect(_on_quit_pressed)
	hbox.add_child(_quit_button)


# ═══════════════════════════════════════════════════════════════════════════════
# REFRESH
# ═══════════════════════════════════════════════════════════════════════════════

func _refresh_all() -> void:
	_refresh_header()
	_refresh_factions()
	_refresh_biomes()
	_refresh_oghams()
	_refresh_start_button()


func _refresh_header() -> void:
	if _player_name_label:
		var phosphor: Color = MerlinVisual.CRT_PALETTE["phosphor"]
		_player_name_label.text = "> %s" % _player_name
		_player_name_label.add_theme_color_override("font_color", phosphor)
	if _anam_label:
		var cyan: Color = MerlinVisual.CRT_PALETTE["cyan"]
		_anam_label.text = "Anam: %d" % _anam
		_anam_label.add_theme_color_override("font_color", cyan)
	if _runs_label:
		var dim: Color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
		_runs_label.text = "Runs: %d" % _total_runs
		_runs_label.add_theme_color_override("font_color", dim)
	if _maturity_label:
		var dim: Color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
		_maturity_label.text = "Maturite: %d" % _maturity_score
		_maturity_label.add_theme_color_override("font_color", dim)


func _refresh_factions() -> void:
	for faction_id in MerlinConstants.FACTIONS:
		var bar: FactionRepBar = _faction_bars.get(faction_id)
		if bar:
			var value: float = float(_faction_rep.get(faction_id, 0))
			bar.update(faction_id, value)


func _refresh_biomes() -> void:
	# Clear existing buttons
	for child in _biome_grid.get_children():
		child.queue_free()
	_biome_buttons.clear()

	# Available biomes
	for biome_data in _biomes_data:
		var biome_id: String = str(biome_data.get("id", ""))
		var biome_name: String = str(biome_data.get("name", biome_id))
		var btn: Button = _make_biome_button(biome_id, biome_name, false)
		_biome_grid.add_child(btn)
		_biome_buttons[biome_id] = btn

	# Locked biomes
	for biome_data in _locked_biomes:
		var biome_id: String = str(biome_data.get("id", ""))
		var biome_name: String = str(biome_data.get("name", biome_id))
		var threshold: int = int(biome_data.get("threshold", 0))
		var btn: Button = _make_biome_button(biome_id, biome_name, true)
		btn.tooltip_text = "Maturite requise: %d (actuel: %d)" % [threshold, _maturity_score]
		_biome_grid.add_child(btn)
		_biome_buttons[biome_id] = btn

	_highlight_selected_biome()


func _refresh_oghams() -> void:
	# Clear existing buttons
	for child in _ogham_grid.get_children():
		child.queue_free()
	_ogham_buttons.clear()

	for ogham_id in _unlocked_oghams:
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
		var ogham_name: String = str(spec.get("name", ogham_id))
		var btn: Button = _make_ogham_button(ogham_id, ogham_name)
		_ogham_grid.add_child(btn)
		_ogham_buttons[ogham_id] = btn

	_update_ogham_count_label()
	_highlight_selected_oghams()


func _refresh_start_button() -> void:
	if _start_button:
		_start_button.disabled = not can_start_run()


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

func select_biome(biome_id: String) -> void:
	# Only allow selecting available (unlocked) biomes
	var is_available: bool = false
	for biome_data in _biomes_data:
		if str(biome_data.get("id", "")) == biome_id:
			is_available = true
			break

	if not is_available:
		return

	_selected_biome = biome_id
	_highlight_selected_biome()
	_refresh_start_button()


func _highlight_selected_biome() -> void:
	for biome_id in _biome_buttons:
		var btn: Button = _biome_buttons[biome_id]
		if biome_id == _selected_biome:
			var selected_color: Color = MerlinVisual.CRT_PALETTE["amber"]
			btn.add_theme_color_override("font_color", selected_color)
		else:
			var is_locked: bool = _is_biome_locked(biome_id)
			if is_locked:
				var locked_color: Color = MerlinVisual.CRT_PALETTE["inactive"]
				btn.add_theme_color_override("font_color", locked_color)
			else:
				var normal_color: Color = MerlinVisual.CRT_PALETTE["phosphor"]
				btn.add_theme_color_override("font_color", normal_color)


func _is_biome_locked(biome_id: String) -> bool:
	for biome_data in _locked_biomes:
		if str(biome_data.get("id", "")) == biome_id:
			return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

func toggle_ogham(ogham_id: String) -> bool:
	if not _unlocked_oghams.has(ogham_id):
		return false

	if _selected_oghams.has(ogham_id):
		# Deselect
		_selected_oghams.erase(ogham_id)
		_highlight_selected_oghams()
		_update_ogham_count_label()
		_refresh_start_button()
		return true

	# Select — enforce max
	if _selected_oghams.size() >= MAX_OGHAM_SELECTION:
		return false

	_selected_oghams.append(ogham_id)
	_highlight_selected_oghams()
	_update_ogham_count_label()
	_refresh_start_button()
	return true


func _highlight_selected_oghams() -> void:
	for ogham_id in _ogham_buttons:
		var btn: Button = _ogham_buttons[ogham_id]
		if _selected_oghams.has(ogham_id):
			var cyan: Color = MerlinVisual.CRT_PALETTE["cyan_bright"]
			btn.add_theme_color_override("font_color", cyan)
		else:
			var dim: Color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
			btn.add_theme_color_override("font_color", dim)


func _update_ogham_count_label() -> void:
	if _ogham_count_label:
		var phosphor: Color = MerlinVisual.CRT_PALETTE["phosphor"]
		_ogham_count_label.text = "(%d/%d)" % [_selected_oghams.size(), MAX_OGHAM_SELECTION]
		_ogham_count_label.add_theme_color_override("font_color", phosphor)


# ═══════════════════════════════════════════════════════════════════════════════
# BUTTON FACTORIES
# ═══════════════════════════════════════════════════════════════════════════════

func _make_biome_button(biome_id: String, biome_name: String, locked: bool) -> Button:
	var btn: Button = Button.new()
	btn.text = biome_name
	btn.custom_minimum_size = Vector2(140, 36)
	MerlinVisual.apply_button_theme(btn)

	if locked:
		btn.disabled = true
		var locked_color: Color = MerlinVisual.CRT_PALETTE["inactive"]
		btn.add_theme_color_override("font_color", locked_color)
		btn.text = "[X] " + biome_name
	else:
		btn.pressed.connect(_on_biome_selected.bind(biome_id))

	return btn


func _make_ogham_button(ogham_id: String, ogham_name: String) -> Button:
	var btn: Button = Button.new()
	btn.text = ogham_name
	btn.custom_minimum_size = Vector2(100, 30)
	MerlinVisual.apply_button_theme(btn)

	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
	var category: String = str(spec.get("category", ""))
	var cooldown: int = int(spec.get("cooldown", 0))
	btn.tooltip_text = "%s\nCategorie: %s\nCooldown: %d" % [
		str(spec.get("description", "")), category, cooldown
	]

	btn.pressed.connect(_on_ogham_toggled.bind(ogham_id))
	return btn


func _make_action_button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 40)
	MerlinVisual.apply_button_theme(btn)
	return btn


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_biome_selected(biome_id: String) -> void:
	select_biome(biome_id)


func _on_ogham_toggled(ogham_id: String) -> void:
	toggle_ogham(ogham_id)


func _on_start_pressed() -> void:
	if can_start_run():
		run_requested.emit(_selected_biome, _selected_oghams.duplicate())


func _on_talent_pressed() -> void:
	talent_tree_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()


# ═══════════════════════════════════════════════════════════════════════════════
# STYLE HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_root_style() -> void:
	var bg: Color = MerlinVisual.CRT_PALETTE["bg_deep"]
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	add_theme_stylebox_override("panel", style)


func _make_section_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var bg: Color = MerlinVisual.CRT_PALETTE["bg_panel"]
	var border: Color = MerlinVisual.CRT_PALETTE["border"]
	style.bg_color = bg
	style.border_color = border
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.content_margin_top = PANEL_MARGIN
	style.content_margin_bottom = PANEL_MARGIN
	style.content_margin_left = PANEL_MARGIN
	style.content_margin_right = PANEL_MARGIN
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style


func _make_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	var phosphor: Color = MerlinVisual.CRT_PALETTE["phosphor"]
	label.add_theme_color_override("font_color", phosphor)
	label.add_theme_font_size_override("font_size", font_size)
	return label
