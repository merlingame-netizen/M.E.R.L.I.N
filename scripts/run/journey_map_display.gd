## ═══════════════════════════════════════════════════════════════════════════════
## JourneyMapDisplay — CRT-styled vertical journey map of cards played during a run
## ═══════════════════════════════════════════════════════════════════════════════
## Shows the path taken through the run as a vertical timeline:
## - Each card = styled node with glow ring + truncated text + choice tag
## - Connected by dashed phosphor lines
## - Effect pips (heal=green, damage=red, reputation=amber, ogham=cyan)
## - Final node highlighted with outer glow (victory=amber, death=danger)
## - Scroll indicator when entries exceed visible limit
## Bible s.5.3: "Carte du voyage — stylized biome map with pins at key moments"
## ═══════════════════════════════════════════════════════════════════════════════

extends Control
class_name JourneyMapDisplay

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const NODE_RADIUS: float = 5.0
const GLOW_RADIUS: float = 9.0
const FINAL_RADIUS: float = 7.0
const FINAL_GLOW_RADIUS: float = 13.0
const LINE_WIDTH: float = 1.5
const DASH_LENGTH: float = 6.0
const GAP_LENGTH: float = 4.0
const NODE_SPACING: float = 34.0
const LEFT_MARGIN: float = 28.0
const TEXT_OFFSET_X: float = 22.0
const PIP_OFFSET_X: float = -12.0
const PIP_RADIUS: float = 2.5
const MAX_VISIBLE_NODES: int = 12
const LABEL_FONT_SIZE: int = 13
const CHOICE_FONT_SIZE: int = 11
const MAX_TEXT_LENGTH: int = 36

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ══════════════════════════════════════════════════════════════════════════════════

var _story_entries: Array = []
var _is_victory: bool = false
var _headless: bool = false
var _scroll_offset: int = 0
var _cached_font: Font = null


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(story_log: Array, is_victory: bool, headless: bool = false) -> void:
	_story_entries = story_log
	_is_victory = is_victory
	_headless = headless

	if _story_entries.size() > MAX_VISIBLE_NODES:
		_scroll_offset = _story_entries.size() - MAX_VISIBLE_NODES

	var visible_count: int = mini(_story_entries.size(), MAX_VISIBLE_NODES)
	var needed_height: float = float(visible_count) * NODE_SPACING + NODE_SPACING
	custom_minimum_size = Vector2(0, maxf(needed_height, 80.0))

	_cached_font = MerlinVisual.get_font("terminal")
	queue_redraw()


func get_entry_count() -> int:
	return _story_entries.size()


func get_visible_entries() -> Array:
	if _story_entries.is_empty():
		return []
	var start_idx: int = _scroll_offset
	var end_idx: int = mini(start_idx + MAX_VISIBLE_NODES, _story_entries.size())
	return _story_entries.slice(start_idx, end_idx)


func get_is_victory() -> bool:
	return _is_victory


# ═══════════════════════════════════════════════════════════════════════════════
# DRAWING
# ═══════════════════════════════════════════════════════════════════════════════

func _draw() -> void:
	if _headless:
		return

	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	var visible_entries: Array = get_visible_entries()

	if visible_entries.is_empty():
		_draw_empty_state(pal)
		return

	var font: Font = _cached_font if _cached_font else ThemeDB.fallback_font
	var last_index: int = visible_entries.size() - 1

	# Scroll-up indicator
	if _scroll_offset > 0:
		_draw_scroll_indicator(pal, true)

	for i in visible_entries.size():
		var entry: Dictionary = visible_entries[i] if visible_entries[i] is Dictionary else {}
		var y_pos: float = NODE_SPACING * 0.5 + float(i) * NODE_SPACING
		var center: Vector2 = Vector2(LEFT_MARGIN, y_pos)
		var is_last: bool = (i == last_index) and (_scroll_offset + i == _story_entries.size() - 1)

		# Dashed connecting line to next node
		if i < last_index:
			var next_y: float = NODE_SPACING * 0.5 + float(i + 1) * NODE_SPACING
			_draw_dashed_line(center, Vector2(LEFT_MARGIN, next_y), pal["line"], LINE_WIDTH)

		# Effect pip (left of node)
		_draw_effect_pip(entry, center, pal)

		# Node circle with glow
		if is_last:
			_draw_final_node(center, pal)
		else:
			_draw_journey_node(center, entry, pal)

		# Text label
		var global_idx: int = _scroll_offset + i
		var label_text: String = _format_entry_label(entry, global_idx)
		var text_color: Color = pal["phosphor"] if is_last else pal["phosphor_dim"]
		var text_pos: Vector2 = Vector2(LEFT_MARGIN + TEXT_OFFSET_X, y_pos + 4.0)
		draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, text_color)

		# Choice tag (smaller, right-aligned to text)
		var choice: String = str(entry.get("choice", ""))
		if not choice.is_empty():
			var choice_color: Color = pal["amber_dim"] if not is_last else pal["amber"]
			var tag_text: String = "[%s]" % choice
			var choice_x: float = LEFT_MARGIN + TEXT_OFFSET_X
			var choice_y: float = y_pos + 4.0 + float(LABEL_FONT_SIZE) + 2.0
			if choice_y < y_pos + NODE_SPACING - 4.0:
				draw_string(font, Vector2(choice_x, choice_y), tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHOICE_FONT_SIZE, choice_color)

	# Scroll-down indicator
	if _scroll_offset + MAX_VISIBLE_NODES < _story_entries.size():
		var bottom_y: float = NODE_SPACING * 0.5 + float(last_index + 1) * NODE_SPACING
		_draw_scroll_indicator_at(pal, bottom_y, false)


func _draw_empty_state(pal: Dictionary) -> void:
	var font: Font = _cached_font if _cached_font else ThemeDB.fallback_font
	var msg: String = "Le sentier s'etend... aucune carte jouee."
	draw_string(font, Vector2(LEFT_MARGIN, 24.0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, pal["phosphor_dim"])
	# Decorative dots
	for i in 3:
		var x: float = LEFT_MARGIN + float(i) * 16.0
		draw_circle(Vector2(x, 44.0), 1.5, pal["line"])


# ═══════════════════════════════════════════════════════════════════════════════
# NODE DRAWING
# ═══════════════════════════════════════════════════════════════════════════════

func _draw_journey_node(center: Vector2, entry: Dictionary, pal: Dictionary) -> void:
	var node_color: Color = _get_entry_color(entry, pal)
	var glow_color: Color = Color(node_color.r, node_color.g, node_color.b, 0.12)
	draw_circle(center, GLOW_RADIUS, glow_color)
	draw_circle(center, NODE_RADIUS, node_color)
	draw_circle(center, NODE_RADIUS - 1.5, Color(node_color.r * 0.3, node_color.g * 0.3, node_color.b * 0.3))


func _draw_final_node(center: Vector2, pal: Dictionary) -> void:
	var accent: Color = pal["amber"] if _is_victory else pal["danger"]
	var glow: Color = Color(accent.r, accent.g, accent.b, 0.2)
	var inner_glow: Color = Color(accent.r, accent.g, accent.b, 0.08)
	# Outer glow ring
	draw_circle(center, FINAL_GLOW_RADIUS, inner_glow)
	draw_arc(center, FINAL_GLOW_RADIUS, 0.0, TAU, 24, glow, 2.0)
	# Core
	draw_circle(center, FINAL_RADIUS, accent)
	draw_circle(center, FINAL_RADIUS - 2.0, Color(accent.r * 0.4, accent.g * 0.4, accent.b * 0.4))
	# Icon glyph
	var font: Font = _cached_font if _cached_font else ThemeDB.fallback_font
	var glyph: String = "V" if _is_victory else "X"
	draw_string(font, center + Vector2(-3.0, 4.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, accent)


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT PIPS
# ═══════════════════════════════════════════════════════════════════════════════

func _draw_effect_pip(entry: Dictionary, center: Vector2, pal: Dictionary) -> void:
	var effects: Array = entry.get("effects", [])
	if effects.is_empty():
		return

	var pip_x: float = center.x + PIP_OFFSET_X
	var pip_y: float = center.y
	var pip_count: int = 0

	for effect in effects:
		var effect_str: String = str(effect)
		var pip_color: Color = _classify_effect_color(effect_str, pal)
		if pip_color.a < 0.01:
			continue
		var offset_y: float = float(pip_count) * (PIP_RADIUS * 2.5)
		draw_circle(Vector2(pip_x, pip_y - 4.0 + offset_y), PIP_RADIUS, pip_color)
		pip_count += 1
		if pip_count >= 3:
			break


func _classify_effect_color(effect_str: String, pal: Dictionary) -> Color:
	var upper: String = effect_str.to_upper()
	if upper.begins_with("HEAL") or upper.begins_with("ADD_LIFE"):
		return pal["success"]
	if upper.begins_with("DAMAGE") or upper.begins_with("DRAIN"):
		return pal["danger"]
	if upper.begins_with("ADD_REPUTATION"):
		return pal["amber"]
	if upper.begins_with("ACTIVATE_OGHAM") or upper.begins_with("USE_OGHAM"):
		return pal["cyan"]
	if upper.begins_with("PROGRESS_MISSION"):
		return pal["phosphor_bright"]
	return Color.TRANSPARENT


# ══════════════════════════════════════════════════════════════════════════════════
# DASHED LINE
# ═══════════════════════════════════════════════════════════════════════════════

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var total_dist: float = from.distance_to(to)
	if total_dist < 1.0:
		return
	var dir: Vector2 = (to - from).normalized()
	var segment: float = DASH_LENGTH + GAP_LENGTH
	var pos: float = 0.0
	while pos < total_dist:
		var dash_end: float = minf(pos + DASH_LENGTH, total_dist)
		draw_line(from + dir * pos, from + dir * dash_end, color, width)
		pos += segment


# ═══════════════════════════════════════════════════════════════════════════════
# SCROLL INDICATORS
# ═══════════════════════════════════════════════════════════════════════════════

func _draw_scroll_indicator(pal: Dictionary, is_top: bool) -> void:
	var y: float = 6.0 if is_top else size.y - 6.0
	_draw_scroll_indicator_at(pal, y, is_top)


func _draw_scroll_indicator_at(pal: Dictionary, y: float, _is_top: bool) -> void:
	var dot_color: Color = pal["phosphor_dim"]
	for i in 3:
		draw_circle(Vector2(LEFT_MARGIN - 4.0 + float(i) * 8.0, y), 1.5, dot_color)


# ═══════════════════════════════════════════════════════════════════════════════
# ENTRY HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _format_entry_label(entry: Dictionary, global_index: int) -> String:
	var card_idx: int = int(entry.get("card_idx", global_index + 1))
	var text: String = str(entry.get("text", ""))

	if text.length() > MAX_TEXT_LENGTH:
		text = text.substr(0, MAX_TEXT_LENGTH - 3) + "..."

	if not text.is_empty():
		return "#%d %s" % [card_idx, text]
	return "#%d" % card_idx


func _get_entry_color(entry: Dictionary, pal: Dictionary) -> Color:
	var effects: Array = entry.get("effects", [])
	for effect in effects:
		var s: String = str(effect).to_upper()
		if s.begins_with("HEAL") or s.begins_with("ADD_LIFE"):
			return pal["success"]
		if s.begins_with("DAMAGE") or s.begins_with("DRAIN"):
			return pal["danger"]
	var choice: String = str(entry.get("choice", ""))
	if choice.is_empty():
		return pal["phosphor_dim"]
	return pal["phosphor"]


func _get_final_node_color() -> Color:
	if _is_victory:
		return MerlinVisual.CRT_PALETTE["amber"]
	return MerlinVisual.CRT_PALETTE["danger"]
