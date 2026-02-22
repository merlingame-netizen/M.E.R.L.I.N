## =============================================================================
## MapUI — Tiered Biome Tree World Map (Parchment Style)
## =============================================================================
## Displays 7 biomes across 4 tiers with gauge-based unlock conditions.
## Uses WorldMapSystem autoload for accessibility, MerlinBiomeTree for layout.
## Visual style: parchment paper, circular nodes, curved dashed paths.
## =============================================================================

extends Control
class_name MapUI

signal node_selected(biome_key: String)
signal start_requested(biome_key: String)
signal close_requested

const TRANSITION_SCENE := "res://scenes/TransitionBiome.tscn"
const ROOT_BIOME := "foret_broceliande"

const NODE_RADIUS := 15.0
const NODE_HIT_RADIUS := 22.0
const MAP_MARGIN := 38.0
const USABLE_TOP := 78.0
const USABLE_BOTTOM := 140.0
const BEZIER_SEGMENTS := 20
const DASH_LENGTH := 8.0
const GAP_LENGTH := 6.0
const PATH_WIDTH_LOCKED := 1.5
const PATH_WIDTH_UNLOCKED := 2.2
const PATH_WIDTH_HIGHLIGHT := 3.0
const GAUGE_BAR_HEIGHT := 6.0
const GAUGE_BAR_WIDTH := 50.0
const GAUGE_SPACING := 12.0

var _title_font: Font
var _body_font: Font
var _biome_tree := MerlinBiomeTree.new()
var _gauge_system := MerlinGaugeSystem.new()

var _selected_biome: String = ROOT_BIOME
var _biome_states: Dictionary = {}  # biome_key -> "locked"/"accessible"/"current"/"completed"

@onready var _parchment_bg: ColorRect = $ParchmentBG
@onready var _title_label: Label = $TitleLabel
@onready var _subtitle_label: Label = $SubtitleLabel
@onready var _paths_layer: Control = $PathsLayer
@onready var _nodes_layer: Control = $NodesLayer
@onready var _detail_label: Label = $DetailLabel
@onready var _gauge_panel: Control = $GaugePanel
@onready var back_button: Button = $BottomBar/BackButton
@onready var _start_button: Button = $BottomBar/StartButton
var _selection_tween: Tween
var _ink_tween: Tween
var _ink_progress: float = 0.0
var _ink_target_biome: String = ""


func _ready() -> void:
	_load_fonts()
	_compute_biome_states()
	_configure_ui()
	resized.connect(_layout_tree)
	await get_tree().process_frame
	_layout_tree()
	_animate_reveal()
	_connect_world_map_signals()


func _load_fonts() -> void:
	_title_font = MerlinVisual.get_font("title")
	_body_font = MerlinVisual.get_font("body")


func _connect_world_map_signals() -> void:
	var wms := get_node_or_null("/root/WorldMapSystem")
	if wms == null:
		return
	if not wms.is_connected("biome_unlocked", _on_biome_unlocked):
		wms.biome_unlocked.connect(_on_biome_unlocked)
	if not wms.is_connected("gauges_changed", _on_gauges_changed):
		wms.gauges_changed.connect(_on_gauges_changed)


# =============================================================================
# STATE COMPUTATION
# =============================================================================

func _compute_biome_states() -> void:
	var wms := get_node_or_null("/root/WorldMapSystem")
	var current_biome: String = ROOT_BIOME
	var completed: Array = []

	if wms:
		current_biome = wms.get_current_biome()
		completed = wms.get_completed_biomes()

	for biome_key in MerlinBiomeTree.BIOME_KEYS:
		if biome_key == current_biome:
			_biome_states[biome_key] = "current"
		elif biome_key in completed:
			_biome_states[biome_key] = "completed"
		elif wms and wms.is_biome_accessible(biome_key):
			_biome_states[biome_key] = "accessible"
		elif biome_key == ROOT_BIOME:
			_biome_states[biome_key] = "accessible"
		else:
			_biome_states[biome_key] = "locked"


# =============================================================================
# UI BUILDING
# =============================================================================

func _configure_ui() -> void:
	# CRT terminal background
	_parchment_bg.material = null
	_parchment_bg.color = MerlinVisual.CRT_PALETTE.bg_panel

	# Font + color overrides (runtime-dependent on MerlinVisual)
	if _title_font:
		_title_label.add_theme_font_override("font", _title_font)
	_title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)

	if _body_font:
		_subtitle_label.add_theme_font_override("font", _body_font)
	_subtitle_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)

	if _body_font:
		_detail_label.add_theme_font_override("font", _body_font)
	_detail_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)

	# Draw signal connections
	_paths_layer.draw.connect(_draw_paths)
	_nodes_layer.draw.connect(_draw_nodes)
	_nodes_layer.gui_input.connect(_on_nodes_input)
	_gauge_panel.draw.connect(_draw_gauges)

	# Button styling (runtime StyleBoxFlat)
	if _body_font:
		back_button.add_theme_font_override("font", _body_font)
	_style_action_button(back_button, false)
	back_button.pressed.connect(_on_back_pressed)

	if _title_font:
		_start_button.add_theme_font_override("font", _title_font)
	_style_action_button(_start_button, true)
	_start_button.pressed.connect(_on_start_pressed)

	_show_selected_detail()
	_update_start_button_state()


func _style_action_button(button: Button, primary: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = MerlinVisual.CRT_PALETTE.amber if primary else MerlinVisual.CRT_PALETTE.bg_dark
	normal.border_color = MerlinVisual.CRT_PALETTE.phosphor
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	normal.shadow_color = MerlinVisual.CRT_PALETTE.shadow
	normal.shadow_size = 3
	normal.shadow_offset = Vector2(0, 1)
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = MerlinVisual.CRT_PALETTE.amber_dim if primary else MerlinVisual.CRT_PALETTE.bg_panel
	button.add_theme_stylebox_override("hover", hover)

	var disabled := normal.duplicate()
	var disabled_bg: Color = MerlinVisual.CRT_PALETTE.inactive
	var disabled_border: Color = MerlinVisual.CRT_PALETTE.inactive_dark
	disabled.bg_color = Color(disabled_bg.r, disabled_bg.g, disabled_bg.b, 0.60)
	disabled.border_color = Color(disabled_border.r, disabled_border.g, disabled_border.b, 0.7)
	button.add_theme_stylebox_override("disabled", disabled)

	if primary:
		button.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.bg_panel)
		button.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE.bg_panel)
	else:
		button.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)


# =============================================================================
# LAYOUT & COORDINATE MAPPING
# =============================================================================

func _layout_tree() -> void:
	_paths_layer.queue_redraw()
	_nodes_layer.queue_redraw()
	_gauge_panel.queue_redraw()


func _map_to_screen(prop: Vector2) -> Vector2:
	var rect_size := get_rect().size
	var usable_h := rect_size.y - USABLE_TOP - USABLE_BOTTOM
	return Vector2(
		MAP_MARGIN + (rect_size.x - MAP_MARGIN * 2.0) * prop.x,
		USABLE_TOP + usable_h * prop.y
	)


func _get_node_center(biome_key: String) -> Vector2:
	var prop: Vector2 = MerlinBiomeTree.BIOME_POSITIONS.get(biome_key, Vector2(0.5, 0.5))
	return _map_to_screen(prop)


# =============================================================================
# DRAWING — Paths (Bezier curves with gradients)
# =============================================================================

func _draw_paths() -> void:
	for edge in MerlinBiomeTree.BIOME_TREE_EDGES:
		var from_key: String = str(edge["from"])
		var to_key: String = str(edge["to"])
		var from_pos: Vector2 = _get_node_center(from_key)
		var to_pos: Vector2 = _get_node_center(to_key)

		var from_color: Color = MerlinBiomeTree.BIOME_COLORS.get(from_key, Color.GRAY)
		var to_color: Color = MerlinBiomeTree.BIOME_COLORS.get(to_key, Color.GRAY)

		var from_state: String = _biome_states.get(from_key, "locked")
		var to_state: String = _biome_states.get(to_key, "locked")
		var segment_unlocked: bool = from_state != "locked" and to_state != "locked"
		var highlighted: bool = _selected_biome == to_key or _selected_biome == from_key

		_draw_bezier_path(from_pos, to_pos, from_color, to_color, segment_unlocked, highlighted)


func _draw_bezier_path(from: Vector2, to: Vector2, color_a: Color, color_b: Color, unlocked: bool, highlighted: bool) -> void:
	# Control point for quadratic Bezier (perpendicular offset)
	var mid := (from + to) * 0.5
	var dir := (to - from)
	var perp := Vector2(-dir.y, dir.x).normalized() * 25.0
	var ctrl := mid + perp

	var width: float = PATH_WIDTH_LOCKED
	var alpha_mult: float = 0.35
	if unlocked:
		width = PATH_WIDTH_UNLOCKED
		alpha_mult = 0.65
	if highlighted and unlocked:
		width = PATH_WIDTH_HIGHLIGHT
		alpha_mult = 0.95

	var prev_point := from
	var dash_on := true
	var dash_accum := 0.0

	for i in range(1, BEZIER_SEGMENTS + 1):
		var t: float = float(i) / float(BEZIER_SEGMENTS)
		var point := _bezier_point(from, ctrl, to, t)
		var seg_length := prev_point.distance_to(point)
		var color := color_a.lerp(color_b, t)
		color.a = alpha_mult

		dash_accum += seg_length
		if dash_on:
			_paths_layer.draw_line(prev_point, point, color, width, true)
			if dash_accum >= DASH_LENGTH:
				dash_on = false
				dash_accum = 0.0
		else:
			if dash_accum >= GAP_LENGTH:
				dash_on = true
				dash_accum = 0.0

		prev_point = point


func _bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 := p0.lerp(p1, t)
	var q1 := p1.lerp(p2, t)
	return q0.lerp(q1, t)


# =============================================================================
# DRAWING — Nodes (circles with state-dependent visuals)
# =============================================================================

func _draw_nodes() -> void:
	for biome_key in MerlinBiomeTree.BIOME_KEYS:
		var center := _get_node_center(biome_key)
		var biome_color: Color = MerlinBiomeTree.BIOME_COLORS.get(biome_key, Color.GRAY)
		var state_key: String = _biome_states.get(biome_key, "locked")
		var is_selected: bool = biome_key == _selected_biome

		# Draw node circle
		match state_key:
			"locked":
				var dim_color := Color(biome_color.r, biome_color.g, biome_color.b, 0.35)
				_nodes_layer.draw_circle(center, NODE_RADIUS, dim_color)
				_nodes_layer.draw_arc(center, NODE_RADIUS, 0, TAU, 24, MerlinVisual.CRT_PALETTE.locked, 1.5, true)
				# Lock icon (small X)
				var lk := 4.0
				_nodes_layer.draw_line(center - Vector2(lk, lk), center + Vector2(lk, lk), MerlinVisual.CRT_PALETTE.locked, 1.5, true)
				_nodes_layer.draw_line(center - Vector2(-lk, lk), center + Vector2(-lk, lk), MerlinVisual.CRT_PALETTE.locked, 1.5, true)

			"accessible":
				_nodes_layer.draw_circle(center, NODE_RADIUS, biome_color)
				var outline_color: Color = MerlinVisual.CRT_PALETTE.amber if not is_selected else MerlinVisual.CRT_PALETTE.success
				_nodes_layer.draw_arc(center, NODE_RADIUS + 1.0, 0, TAU, 24, outline_color, 2.0, true)

			"current":
				_nodes_layer.draw_circle(center, NODE_RADIUS + 2.0, Color(biome_color.r, biome_color.g, biome_color.b, 0.25))
				_nodes_layer.draw_circle(center, NODE_RADIUS, biome_color)
				_nodes_layer.draw_arc(center, NODE_RADIUS + 2.0, 0, TAU, 24, MerlinVisual.CRT_PALETTE.success, 2.5, true)
				# Animated pulse indicator (small triangle)
				var tri_size := 5.0
				var tri_top := center + Vector2(0, -NODE_RADIUS - 8)
				_nodes_layer.draw_colored_polygon(
					PackedVector2Array([
						tri_top,
						tri_top + Vector2(-tri_size, -tri_size),
						tri_top + Vector2(tri_size, -tri_size),
					]),
					MerlinVisual.CRT_PALETTE.success
				)

			"completed":
				var dim := Color(biome_color.r * 0.7, biome_color.g * 0.7, biome_color.b * 0.7, 0.75)
				_nodes_layer.draw_circle(center, NODE_RADIUS, dim)
				_nodes_layer.draw_arc(center, NODE_RADIUS, 0, TAU, 24, MerlinVisual.CRT_PALETTE.phosphor_dim, 1.5, true)
				# Checkmark
				var ck := 5.0
				_nodes_layer.draw_line(center + Vector2(-ck, 0), center + Vector2(-ck * 0.3, ck), MerlinVisual.CRT_PALETTE.success, 2.0, true)
				_nodes_layer.draw_line(center + Vector2(-ck * 0.3, ck), center + Vector2(ck, -ck), MerlinVisual.CRT_PALETTE.success, 2.0, true)

		# Selection ring
		if is_selected and state_key != "locked":
			_nodes_layer.draw_arc(center, NODE_RADIUS + 4.0, 0, TAU, 24, MerlinVisual.CRT_PALETTE.success, 1.5, true)

		# Biome name label
		var name_text: String = str(MerlinBiomeTree.BIOME_NAMES.get(biome_key, biome_key))
		var font: Font = _body_font if _body_font else ThemeDB.fallback_font
		var font_size: int = 11
		var text_size := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := center + Vector2(-text_size.x * 0.5, NODE_RADIUS + 14)
		var text_color: Color = MerlinVisual.CRT_PALETTE.phosphor if state_key != "locked" else MerlinVisual.CRT_PALETTE.border
		_nodes_layer.draw_string(font, text_pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

		# Tier label
		var tier: int = _biome_tree.get_tier(biome_key)
		var tier_text: String = "T%d" % tier if tier < 4 else "FIN"
		var tier_pos := center + Vector2(-8, -NODE_RADIUS - 4)
		_nodes_layer.draw_string(font, tier_pos, tier_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MerlinVisual.CRT_PALETTE.border)


# =============================================================================
# DRAWING — Gauge Bars
# =============================================================================

func _draw_gauges() -> void:
	var wms := get_node_or_null("/root/WorldMapSystem")
	if wms == null:
		return

	var displays: Array = wms.get_gauge_displays()
	var total_width: float = float(displays.size()) * (GAUGE_BAR_WIDTH + GAUGE_SPACING) - GAUGE_SPACING
	var panel_width: float = _gauge_panel.size.x
	var start_x: float = (panel_width - total_width) * 0.5

	for i in displays.size():
		var display: Dictionary = displays[i]
		var x: float = start_x + float(i) * (GAUGE_BAR_WIDTH + GAUGE_SPACING)
		var y: float = 2.0
		var pct: float = float(display.get("percent", 0.0))
		var color: Color = display.get("color", Color.GRAY)
		var name_text: String = str(display.get("name", ""))
		var value_text: String = "%d" % int(display.get("value", 0))

		# Background bar
		_gauge_panel.draw_rect(Rect2(x, y, GAUGE_BAR_WIDTH, GAUGE_BAR_HEIGHT), MerlinVisual.CRT_PALETTE.border)
		# Fill bar
		var fill_width: float = GAUGE_BAR_WIDTH * pct
		_gauge_panel.draw_rect(Rect2(x, y, fill_width, GAUGE_BAR_HEIGHT), color)
		# Border
		_gauge_panel.draw_rect(Rect2(x, y, GAUGE_BAR_WIDTH, GAUGE_BAR_HEIGHT), MerlinVisual.CRT_PALETTE.phosphor_dim, false, 1.0)

		# Label below
		var font: Font = _body_font if _body_font else ThemeDB.fallback_font
		var label_text: String = "%s %s" % [name_text, value_text]
		_gauge_panel.draw_string(font, Vector2(x, y + GAUGE_BAR_HEIGHT + 12), label_text, HORIZONTAL_ALIGNMENT_LEFT, GAUGE_BAR_WIDTH, 9, MerlinVisual.CRT_PALETTE.phosphor_dim)


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _on_nodes_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	var click_pos: Vector2 = mb.position
	for biome_key in MerlinBiomeTree.BIOME_KEYS:
		var center := _get_node_center(biome_key)
		if click_pos.distance_to(center) <= NODE_HIT_RADIUS:
			_on_biome_clicked(biome_key)
			get_viewport().set_input_as_handled()
			return


func _on_biome_clicked(biome_key: String) -> void:
	var state_key: String = _biome_states.get(biome_key, "locked")
	_selected_biome = biome_key

	if state_key == "locked":
		SFXManager.play_varied("hover", 0.04)
	else:
		SFXManager.play("click")
		node_selected.emit(biome_key)

	_update_selection_feedback()


# =============================================================================
# SELECTION FEEDBACK
# =============================================================================

func _update_selection_feedback() -> void:
	_show_selected_detail()
	_update_start_button_state()
	_paths_layer.queue_redraw()
	_nodes_layer.queue_redraw()

	# Pulse animation on selected node
	if _selection_tween:
		_selection_tween.kill()


func _show_selected_detail() -> void:
	var name_text: String = str(MerlinBiomeTree.BIOME_NAMES.get(_selected_biome, _selected_biome))
	var state_key: String = _biome_states.get(_selected_biome, "locked")
	var wms := get_node_or_null("/root/WorldMapSystem")

	if state_key == "locked":
		var hint: String = "Verrouille"
		if wms:
			hint = wms.get_unlock_hint(_selected_biome)
		_detail_label.text = "%s — %s" % [name_text, hint]
	elif state_key == "completed":
		var mods_text: String = ""
		if wms:
			mods_text = wms.get_biome_modifiers_text(_selected_biome)
		_detail_label.text = "%s — Complete (%s)" % [name_text, mods_text]
	else:
		var mods_text: String = ""
		if wms:
			mods_text = wms.get_biome_modifiers_text(_selected_biome)
		_detail_label.text = "%s — %s" % [name_text, mods_text]


func _update_start_button_state() -> void:
	if _start_button == null:
		return
	var state_key: String = _biome_states.get(_selected_biome, "locked")
	var can_start: bool = state_key == "accessible" or state_key == "current"
	_start_button.disabled = not can_start


# =============================================================================
# ACTIONS
# =============================================================================

func _on_start_pressed() -> void:
	var state_key: String = _biome_states.get(_selected_biome, "locked")
	if state_key == "locked" or state_key == "completed":
		return
	SFXManager.play("click")
	node_selected.emit(_selected_biome)
	start_requested.emit(_selected_biome)

	# Update GameManager with selected biome
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var run_data = gm.get("run")
		if not run_data is Dictionary:
			run_data = {}
		run_data["current_biome"] = _selected_biome
		run_data["biome"] = {
			"id": _selected_biome,
			"name": str(MerlinBiomeTree.BIOME_NAMES.get(_selected_biome, _selected_biome)),
		}
		gm.set("run", run_data)

	# Select biome in WorldMapSystem
	var wms := get_node_or_null("/root/WorldMapSystem")
	if wms:
		wms.select_biome(_selected_biome)

	PixelTransition.transition_to(TRANSITION_SCENE)


func _on_back_pressed() -> void:
	SFXManager.play("click")
	close_requested.emit()
	if get_parent() is ColorRect and get_parent().name.contains("Overlay"):
		return
	var target := "res://scenes/HubAntre.tscn"
	var se := get_node_or_null("/root/ScreenEffects")
	if se and str(se.get("return_scene")) != "":
		target = str(se.return_scene)
	PixelTransition.transition_to(target)


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_biome_unlocked(biome_key: String) -> void:
	_compute_biome_states()
	_update_selection_feedback()


func _on_gauges_changed(_gauges: Dictionary) -> void:
	_gauge_panel.queue_redraw()


# =============================================================================
# ANIMATION
# =============================================================================

func _animate_reveal() -> void:
	_nodes_layer.modulate.a = 0.0
	_paths_layer.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_paths_layer, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(_nodes_layer, "modulate:a", 1.0, 0.4).set_delay(0.1)


# =============================================================================
# PUBLIC API
# =============================================================================

func get_selected_biome() -> String:
	return _selected_biome


func set_selected_biome(biome_key: String) -> void:
	if not MerlinBiomeTree.BIOME_POSITIONS.has(biome_key):
		return
	_selected_biome = biome_key
	_update_selection_feedback()


func get_node_data(node_id: String) -> Dictionary:
	return {
		"name": str(MerlinBiomeTree.BIOME_NAMES.get(node_id, node_id)),
		"color": MerlinBiomeTree.BIOME_COLORS.get(node_id, Color.GRAY),
		"tier": _biome_tree.get_tier(node_id),
	}


func set_map(_data: Array, _current_floor: int, _current_node_id: String) -> void:
	pass
