## ═══════════════════════════════════════════════════════════════════════════════
## JourneyMapDisplay — CRT-styled vertical journey map of a run
## ═══════════════════════════════════════════════════════════════════════════════
## Bible s.5.3: "Carte du voyage — stylized biome map with pins at key moments"
## ═══════════════════════════════════════════════════════════════════════════════

extends Control
class_name JourneyMapDisplay

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const NODE_RADIUS: float = 5.0
const GLOW_RADIUS: float = 10.0
const LINE_WIDTH: float = 1.5
const DASH_LENGTH: float = 4.0
const GAP_LENGTH: float = 3.0
const NODE_SPACING: float = 34.0
const LEFT_MARGIN: float = 28.0
const TEXT_OFFSET_X: float = 22.0
const MAX_VISIBLE_NODES: int = 12
const LABEL_FONT_SIZE: int = 12
const SCANLINE_ALPHA: float = 0.04
const SCANLINE_SPACING: int = 3

enum EventType { CARD, HEAL, DAMAGE, REPUTATION, OGHAM, PROMISE }

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _story_entries: Array = []
var _is_victory: bool = false
var _headless: bool = false
var _scroll_offset: int = 0
var _pulse_phase: float = 0.0
var _terminal_font: Font = null


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_terminal_font = MerlinVisual.get_font("terminal")


func _process(delta: float) -> void:
	if _story_entries.is_empty() or _headless:
		return
	_pulse_phase += delta * 2.5
	if _pulse_phase > TAU:
		_pulse_phase -= TAU
	queue_redraw()


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

	_draw_scanlines()

	var visible_entries: Array = get_visible_entries()
	if visible_entries.is_empty():
		_draw_empty_message()
		return

	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	var last_index: int = visible_entries.size() - 1

	if _scroll_offset > 0:
		_draw_scroll_indicator(true, pal)

	for i in visible_entries.size():
		var entry: Dictionary = visible_entries[i] if visible_entries[i] is Dictionary else {}
		var y_pos: float = NODE_SPACING * 0.5 + float(i) * NODE_SPACING
		var center: Vector2 = Vector2(LEFT_MARGIN, y_pos)
		var is_last: bool = (i == last_index) and (_scroll_offset + i == _story_entries.size() - 1)
		var event_type: int = _classify_event(entry)

		if i < last_index:
			var next_y: float = NODE_SPACING * 0.5 + float(i + 1) * NODE_SPACING
			_draw_dashed_line(center, Vector2(LEFT_MARGIN, next_y), pal["line"])

		var node_color: Color = _get_event_color(event_type, is_last, pal)

		if is_last:
			var pulse: float = 0.15 + 0.15 * sin(_pulse_phase)
			draw_circle(center, GLOW_RADIUS, Color(node_color.r, node_color.g, node_color.b, pulse))
			draw_circle(center, NODE_RADIUS + 1.5, node_color)
		elif event_type == EventType.REPUTATION:
			_draw_diamond(center, NODE_RADIUS, node_color)
		elif event_type == EventType.HEAL:
			_draw_cross(center, NODE_RADIUS, node_color)
		elif event_type == EventType.OGHAM:
			_draw_triangle(center, NODE_RADIUS, node_color)
		else:
			draw_circle(center, NODE_RADIUS, node_color)

		var prefix: String = _get_event_glyph(event_type)
		var card_text: String = prefix + _get_entry_label(entry, _scroll_offset + i)
		var label_color: Color = node_color if is_last else pal["phosphor_dim"]
		if event_type != EventType.CARD:
			label_color = node_color.lerp(pal["phosphor_dim"], 0.3)

		var font: Font = _terminal_font if _terminal_font else ThemeDB.fallback_font
		var text_pos: Vector2 = Vector2(LEFT_MARGIN + TEXT_OFFSET_X, y_pos + 4.0)
		draw_string(font, text_pos, card_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, label_color)

	if _scroll_offset + MAX_VISIBLE_NODES < _story_entries.size():
		_draw_scroll_indicator(false, pal)


func _draw_scanlines() -> void:
	var scan_color: Color = Color(0.0, 0.0, 0.0, SCANLINE_ALPHA)
	var h: float = size.y
	var w: float = size.x
	var y: int = 0
	while y < int(h):
		draw_line(Vector2(0, float(y)), Vector2(w, float(y)), scan_color, 1.0)
		y += SCANLINE_SPACING


func _draw_dashed_line(from_pos: Vector2, to_pos: Vector2, color: Color) -> void:
	var dir: Vector2 = to_pos - from_pos
	var total: float = dir.length()
	if total < 1.0:
		return
	var norm: Vector2 = dir / total
	var drawn: float = 0.0
	var drawing: bool = true
	while drawn < total:
		var segment: float = DASH_LENGTH if drawing else GAP_LENGTH
		segment = minf(segment, total - drawn)
		if drawing:
			var a: Vector2 = from_pos + norm * drawn
			var b: Vector2 = from_pos + norm * (drawn + segment)
			draw_line(a, b, color, LINE_WIDTH)
		drawn += segment
		drawing = not drawing


func _draw_diamond(center: Vector2, r: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -r),
		center + Vector2(r, 0),
		center + Vector2(0, r),
		center + Vector2(-r, 0),
	])
	draw_colored_polygon(pts, color)


func _draw_cross(center: Vector2, r: float, color: Color) -> void:
	var t: float = r * 0.35
	draw_rect(Rect2(center.x - t, center.y - r, t * 2, r * 2), color)
	draw_rect(Rect2(center.x - r, center.y - t, r * 2, t * 2), color)


func _draw_triangle(center: Vector2, r: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -r),
		center + Vector2(r * 0.87, r * 0.5),
		center + Vector2(-r * 0.87, r * 0.5),
	])
	draw_colored_polygon(pts, color)


func _draw_scroll_indicator(is_top: bool, pal: Dictionary) -> void:
	var glyph: String = "..." if is_top else "..."
	var y: float = 8.0 if is_top else size.y - 4.0
	var font: Font = _terminal_font if _terminal_font else ThemeDB.fallback_font
	draw_string(font, Vector2(LEFT_MARGIN - 4.0, y), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, pal["phosphor_dim"])


func _draw_empty_message() -> void:
	var font: Font = _terminal_font if _terminal_font else ThemeDB.fallback_font
	draw_string(font, Vector2(LEFT_MARGIN, 30.0), "Aucune carte jouee", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, MerlinVisual.CRT_PALETTE["phosphor_dim"])


# ═══════════════════════════════════════════════════════════════════════════════
# EVENT CLASSIFICATION
# ═══════════════════════════════════════════════════════════════════════════════

func _classify_event(entry: Dictionary) -> int:
	var effects: Variant = entry.get("effects", [])
	if not (effects is Array):
		return EventType.CARD
	for effect in effects:
		var key: String = ""
		if effect is String:
			key = effect.to_upper()
		elif effect is Dictionary:
			key = str(effect.get("type", "")).to_upper()
		if key.begins_with("HEAL"):
			return EventType.HEAL
		if key.begins_with("DAMAGE"):
			return EventType.DAMAGE
		if key.begins_with("ADD_REPUTATION"):
			return EventType.REPUTATION
		if key.begins_with("ACTIVATE_OGHAM"):
			return EventType.OGHAM
		if key.begins_with("CREATE_PROMISE"):
			return EventType.PROMISE
	return EventType.CARD


func _get_event_color(event_type: int, is_last: bool, pal: Dictionary) -> Color:
	if is_last:
		return pal["amber"] if _is_victory else pal["danger"]
	match event_type:
		EventType.HEAL:
			return pal["success"]
		EventType.DAMAGE:
			return pal["danger"]
		EventType.REPUTATION:
			return pal["cyan"]
		EventType.OGHAM:
			return pal["amber"]
		EventType.PROMISE:
			return pal["amber_dim"]
	return pal["phosphor_dim"]


func _get_event_glyph(event_type: int) -> String:
	match event_type:
		EventType.HEAL:
			return "+ "
		EventType.DAMAGE:
			return "! "
		EventType.REPUTATION:
			return "~ "
		EventType.OGHAM:
			return "* "
		EventType.PROMISE:
			return "@ "
	return ""


# ═══════════════════════════════════════════════════════════════════════════════
# ENTRY HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _get_entry_label(entry: Dictionary, global_index: int) -> String:
	var card_idx: int = int(entry.get("card_idx", global_index + 1))
	var choice: String = str(entry.get("choice", ""))
	if not choice.is_empty():
		if choice.length() > 28:
			choice = choice.substr(0, 25) + "..."
		return "#%d [%s]" % [card_idx, choice]
	var text: String = str(entry.get("text", ""))
	if not text.is_empty():
		if text.length() > 32:
			text = text.substr(0, 29) + "..."
		return "#%d %s" % [card_idx, text]
	return "#%d" % card_idx
