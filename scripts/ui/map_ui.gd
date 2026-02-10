## =============================================================================
## Map UI — STS-like World Map for TRIADE
## =============================================================================
## Procedural vertical map with typed nodes and Bezier connections.
## Layout: bottom = start (floor 0), top = boss (floor N-1).
## =============================================================================

extends Control
class_name MapUI

signal node_selected(node_id: String)
signal close_requested

# === LAYOUT CONSTANTS ===
const FLOOR_SPACING := 80.0
const NODE_RADIUS := 20.0
const MAP_MARGIN_X := 40.0
const MAP_MARGIN_Y := 60.0
const CONNECTION_WIDTH := 2.0

# === NODE TYPE VISUALS ===
const NODE_ICONS := {
	"NARRATIVE": "N",
	"EVENT": "E",
	"PROMISE": "P",
	"REST": "R",
	"MERCHANT": "M",
	"MYSTERY": "?",
	"MERLIN": "W",
}

const NODE_COLORS := {
	"NARRATIVE": Color(0.82, 0.78, 0.68),
	"EVENT": Color(0.68, 0.55, 0.32),
	"PROMISE": Color(0.58, 0.44, 0.70),
	"REST": Color(0.40, 0.65, 0.40),
	"MERCHANT": Color(0.70, 0.58, 0.30),
	"MYSTERY": Color(0.50, 0.55, 0.65),
	"MERLIN": Color(0.85, 0.70, 0.35),
}

const COLOR_VISITED := Color(0.35, 0.32, 0.28)
const COLOR_REACHABLE_BORDER := Color(0.85, 0.70, 0.30)
const COLOR_CONNECTION := Color(0.45, 0.40, 0.35, 0.6)
const COLOR_CONNECTION_VISITED := Color(0.55, 0.50, 0.40, 0.8)
const COLOR_BG := Color(0.08, 0.07, 0.06)

# === STATE ===
var _map_data: Array = []
var _current_floor: int = 0
var _current_node_id: String = ""
var _node_buttons: Dictionary = {}  # node_id -> Button
var _node_positions: Dictionary = {}  # node_id -> Vector2
var _scroll: ScrollContainer
var _map_container: Control
var _title_label: Label
var back_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Title
	_title_label = Label.new()
	_title_label.text = "Carte du Monde"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.75, 0.68, 0.55))
	_title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_top = 12
	_title_label.offset_bottom = 42
	add_child(_title_label)

	# Scroll container (main map area)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = 48
	_scroll.offset_bottom = -50
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	# Map container (drawn inside scroll)
	_map_container = Control.new()
	_map_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_map_container)

	# Back button
	back_button = Button.new()
	back_button.text = "< Retour"
	back_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back_button.offset_left = 16
	back_button.offset_top = -44
	back_button.offset_right = 110
	back_button.offset_bottom = -8
	back_button.add_theme_font_size_override("font_size", 14)
	back_button.add_theme_color_override("font_color", Color(0.75, 0.68, 0.55))
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.13, 0.11)
	btn_style.border_color = Color(0.45, 0.40, 0.35, 0.5)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(6)
	back_button.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.22, 0.18)
	back_button.add_theme_stylebox_override("hover", btn_hover)
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)


func set_map(data: Array, current_floor: int, current_node_id: String) -> void:
	## Load map data and build visuals.
	_map_data = data
	_current_floor = current_floor
	_current_node_id = current_node_id
	_build_map_visuals()
	# Scroll to current floor position
	await get_tree().process_frame
	_scroll_to_current()
	# Animate nodes appearing floor by floor
	_animate_map_reveal()


func _build_map_visuals() -> void:
	## Clear and rebuild all map nodes and connections.
	# Clear previous
	for child in _map_container.get_children():
		child.queue_free()
	_node_buttons.clear()
	_node_positions.clear()

	if _map_data.is_empty():
		return

	var viewport_w: float = get_viewport().get_visible_rect().size.x
	var total_floors: int = _map_data.size()
	var map_height: float = float(total_floors) * FLOOR_SPACING + MAP_MARGIN_Y * 2.0

	_map_container.custom_minimum_size = Vector2(viewport_w, map_height)

	# Calculate node positions (bottom-up: floor 0 at bottom)
	for floor_idx in range(total_floors):
		var floor_nodes: Array = _map_data[floor_idx]
		var y_pos: float = map_height - MAP_MARGIN_Y - float(floor_idx) * FLOOR_SPACING
		for node in floor_nodes:
			var x_pct: float = float(node.get("x", 50.0))
			var x_pos: float = MAP_MARGIN_X + (viewport_w - MAP_MARGIN_X * 2.0) * x_pct / 100.0
			var pos := Vector2(x_pos, y_pos)
			var nid: String = str(node.get("id", ""))
			_node_positions[nid] = pos

	# Connection drawing layer
	var conn_layer := Control.new()
	conn_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	conn_layer.custom_minimum_size = _map_container.custom_minimum_size
	conn_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conn_layer.draw.connect(_draw_connections.bind(conn_layer))
	_map_container.add_child(conn_layer)

	# Create node buttons
	for floor_idx in range(total_floors):
		var floor_nodes: Array = _map_data[floor_idx]
		for node in floor_nodes:
			var nid: String = str(node.get("id", ""))
			var pos: Vector2 = _node_positions.get(nid, Vector2.ZERO)
			_create_node_button(node, pos)


func _create_node_button(node: Dictionary, pos: Vector2) -> void:
	var nid: String = str(node.get("id", ""))
	var ntype: String = str(node.get("type", "NARRATIVE"))
	var visited: bool = node.get("visited", false)
	var revealed: bool = node.get("revealed", false)
	var reachable: bool = _is_reachable(nid)
	var is_current: bool = (nid == _current_node_id)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(NODE_RADIUS * 2, NODE_RADIUS * 2)
	btn.position = pos - Vector2(NODE_RADIUS, NODE_RADIUS)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if reachable else Control.CURSOR_ARROW

	# Icon text
	if not revealed and not visited:
		btn.text = "?"
	else:
		btn.text = NODE_ICONS.get(ntype, "?")
	btn.add_theme_font_size_override("font_size", 14)

	# Style
	var style := StyleBoxFlat.new()
	var base_color: Color = NODE_COLORS.get(ntype, Color(0.5, 0.5, 0.5))
	if visited:
		base_color = COLOR_VISITED
	elif not revealed:
		base_color = Color(0.25, 0.23, 0.20)

	style.bg_color = base_color
	style.set_corner_radius_all(int(NODE_RADIUS))
	style.set_content_margin_all(2)

	if is_current:
		style.border_color = Color(1.0, 0.85, 0.4)
		style.set_border_width_all(3)
	elif reachable:
		style.border_color = COLOR_REACHABLE_BORDER
		style.set_border_width_all(2)
	else:
		style.border_color = Color(0.3, 0.28, 0.25, 0.5)
		style.set_border_width_all(1)

	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	if reachable:
		hover_style.bg_color = base_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)

	# Font color
	var font_color := Color(0.95, 0.92, 0.85) if not visited else Color(0.55, 0.50, 0.45)
	btn.add_theme_color_override("font_color", font_color)

	# Tooltip
	if revealed or visited:
		var type_data: Dictionary = MerlinConstants.TRIADE_NODE_TYPES.get(ntype, {})
		var type_label: String = str(type_data.get("label", ntype))
		var cards_count: int = int(node.get("cards_count", 0))
		btn.tooltip_text = "%s (%d cartes)" % [type_label, cards_count] if cards_count > 0 else type_label

	# Signal
	btn.disabled = not reachable
	if reachable:
		btn.pressed.connect(_on_node_pressed.bind(nid))

	_map_container.add_child(btn)
	_node_buttons[nid] = btn

	# Pulsation for current node
	if is_current:
		_animate_current_node(btn)


func _draw_connections(layer: Control) -> void:
	## Draw Bezier curves between connected nodes.
	for floor_idx in range(_map_data.size()):
		var floor_nodes: Array = _map_data[floor_idx]
		for node in floor_nodes:
			var nid: String = str(node.get("id", ""))
			var from_pos: Vector2 = _node_positions.get(nid, Vector2.ZERO)
			var connections: Array = node.get("connections", [])
			for target_id in connections:
				var to_pos: Vector2 = _node_positions.get(str(target_id), Vector2.ZERO)
				if to_pos == Vector2.ZERO:
					continue
				var visited_conn: bool = node.get("visited", false)
				var color: Color = COLOR_CONNECTION_VISITED if visited_conn else COLOR_CONNECTION
				# Bezier control points for curve
				var mid_y: float = (from_pos.y + to_pos.y) / 2.0
				var cp1 := Vector2(from_pos.x, mid_y)
				var cp2 := Vector2(to_pos.x, mid_y)
				_draw_bezier(layer, from_pos, cp1, cp2, to_pos, color, CONNECTION_WIDTH)


func _draw_bezier(layer: Control, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, color: Color, width: float) -> void:
	## Draw a cubic Bezier curve using line segments.
	var points: PackedVector2Array = PackedVector2Array()
	var segments := 16
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var it: float = 1.0 - t
		var point := it * it * it * p0 + 3.0 * it * it * t * p1 + 3.0 * it * t * t * p2 + t * t * t * p3
		points.append(point)
	if points.size() >= 2:
		layer.draw_polyline(points, color, width, true)


func _is_reachable(node_id: String) -> bool:
	## Check if a node is reachable from the current position.
	if _current_node_id.is_empty():
		# No current node: only floor 0 nodes are reachable
		if _map_data.is_empty():
			return false
		for node in _map_data[0]:
			if str(node.get("id", "")) == node_id:
				return true
		return false

	# Node must be connected from the current node
	for floor_nodes in _map_data:
		for node in floor_nodes:
			if str(node.get("id", "")) == _current_node_id:
				return node.get("connections", []).has(node_id)
	return false


func _on_node_pressed(node_id: String) -> void:
	if _is_reachable(node_id):
		node_selected.emit(node_id)


func _on_back_pressed() -> void:
	# Emit close signal for overlay mode (parent handles cleanup)
	close_requested.emit()
	# If parent is an overlay ColorRect, let parent handle — don't change scene
	if get_parent() is ColorRect and get_parent().name.contains("Overlay"):
		return
	# Scene mode fallback: navigate back to hub
	var se := get_node_or_null("/root/ScreenEffects")
	var target: String = "res://scenes/HubAntre.tscn"
	if se and str(se.get("return_scene")) != "":
		target = str(se.return_scene)
	get_tree().change_scene_to_file(target)


func _animate_current_node(btn: Button) -> void:
	## Subtle pulsation on the current node.
	var tween := create_tween().set_loops()
	tween.tween_property(btn, "modulate", Color(1.2, 1.15, 1.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _scroll_to_current() -> void:
	## Scroll the map view to center on the current floor.
	if _current_node_id.is_empty() and _map_data.size() > 0:
		# Scroll to floor 0 (bottom)
		_scroll.scroll_vertical = int(_map_container.custom_minimum_size.y)
		return
	var pos: Vector2 = _node_positions.get(_current_node_id, Vector2.ZERO)
	if pos != Vector2.ZERO:
		var scroll_target: int = int(pos.y - _scroll.size.y / 2.0)
		_scroll.scroll_vertical = maxi(0, scroll_target)


func get_node_data(node_id: String) -> Dictionary:
	## Find and return node data by ID.
	for floor_nodes in _map_data:
		for node in floor_nodes:
			if str(node.get("id", "")) == node_id:
				return node
	return {}


# =============================================================================
# MAP REVEAL ANIMATION — Floor-by-floor node appearance + connection fade
# =============================================================================

func _animate_map_reveal() -> void:
	## Reveal map nodes floor by floor (bottom-up) then fade in connections.
	if _map_data.is_empty() or _map_container.get_child_count() == 0:
		return

	# Connection layer is the first child of _map_container
	var conn_layer: Control = _map_container.get_child(0)
	if conn_layer:
		conn_layer.modulate.a = 0.0

	# Hide all node buttons
	for nid in _node_buttons:
		var btn: Button = _node_buttons[nid]
		if is_instance_valid(btn):
			btn.modulate.a = 0.0

	await get_tree().create_timer(0.2).timeout
	if not is_inside_tree():
		return

	# Reveal nodes floor by floor (floor 0 = bottom, revealed first)
	var total_floors: int = _map_data.size()
	for floor_idx in range(total_floors):
		var floor_nodes: Array = _map_data[floor_idx]
		for node in floor_nodes:
			var nid: String = str(node.get("id", ""))
			var btn: Button = _node_buttons.get(nid)
			if btn and is_instance_valid(btn):
				SFXManager.play_varied("landmark_pop", 0.1)
				var tw := create_tween()
				tw.tween_property(btn, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.15).timeout
		if not is_inside_tree():
			return

	# Fade in connections
	if conn_layer and is_instance_valid(conn_layer):
		var tw := create_tween()
		tw.tween_property(conn_layer, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
