## ═══════════════════════════════════════════════════════════════════════════════
## JourneyMapDisplay — CRT-styled vertical journey map of cards played during a run
## ═══════════════════════════════════════════════════════════════════════════════
## Bible s.5.3: "Carte du voyage — stylized biome map with pins at key moments"
## ═══════════════════════════════════════════════════════════════════════════════

extends Control
class_name JourneyMapDisplay

const NODE_RADIUS: float = 5.0
const GLOW_RADIUS: float = 8.0
const LINE_WIDTH: float = 1.5
const NODE_SPACING: float = 34.0
const LEFT_MARGIN: float = 28.0
const TEXT_OFFSET_X: float = 22.0
const MAX_VISIBLE_NODES: int = 12
const LABEL_FONT_SIZE: int = 13
const REVEAL_DELAY: float = 0.15
const PULSE_SPEED: float = 3.0

var _story_entries: Array = []
var _is_victory: bool = false
var _headless: bool = false
var _scroll_offset: int = 0
var _reveal_progress: float = 0.0
var _reveal_target: int = 0
var _time: float = 0.0
var _revealing: bool = false


func setup(story_log: Array, is_victory: bool, headless: bool = false) -> void:
	_story_entries = story_log
	_is_victory = is_victory
	_headless = headless

	if _story_entries.size() > MAX_VISIBLE_NODES:
		_scroll_offset = _story_entries.size() - MAX_VISIBLE_NODES

	var visible_count: int = mini(_story_entries.size(), MAX_VISIBLE_NODES)
	var needed_height: float = float(visible_count) * NODE_SPACING + NODE_SPACING
	custom_minimum_size = Vector2(0, maxf(needed_height, 80.0))

	_reveal_target = visible_count
	_reveal_progress = 0.0
	_revealing = visible_count > 0
	_time = 0.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _revealing:
		_reveal_progress += delta / REVEAL_DELAY
		if _reveal_progress >= float(_reveal_target):
			_reveal_progress = float(_reveal_target)
			_revealing = false
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


func _draw() -> void:
	if _headless:
		return

	var visible_entries: Array = get_visible_entries()
	if visible_entries.is_empty():
		_draw_empty_message()
		return

	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	var line_color: Color = pal["line"]
	var last_index: int = visible_entries.size() - 1
	var revealed_count: int = int(_reveal_progress)

	for i in visible_entries.size():
		if i > revealed_count:
			break
		var entry: Dictionary = visible_entries[i] if visible_entries[i] is Dictionary else {}
		var y_pos: float = NODE_SPACING * 0.5 + float(i) * NODE_SPACING
		var center: Vector2 = Vector2(LEFT_MARGIN, y_pos)
		var is_last: bool = (i == last_index) and (_scroll_offset + i == _story_entries.size() - 1)

		var node_alpha: float = 1.0
		if i == revealed_count:
			node_alpha = _reveal_progress - float(i)

		# Connection line to next node (dashed CRT style)
		if i < last_index and i < revealed_count:
			var next_y: float = NODE_SPACING * 0.5 + float(i + 1) * NODE_SPACING
			_draw_dashed_line(center, Vector2(LEFT_MARGIN, next_y), line_color, LINE_WIDTH, 4.0, 3.0)

		# Node glow ring
		var node_color: Color = _get_node_color(entry, is_last)
		var glow_color: Color = Color(node_color.r, node_color.g, node_color.b, 0.18 * node_alpha)
		draw_circle(center, GLOW_RADIUS, glow_color)

		# Inner solid node
		var inner_color: Color = Color(node_color.r, node_color.g, node_color.b, node_alpha)
		draw_circle(center, NODE_RADIUS, inner_color)

		# Score indicator ring (thin colored ring based on score)
		var score: int = int(entry.get("score", -1))
		if score >= 0:
			var score_color: Color = _get_score_color(score, pal)
			score_color.a = node_alpha * 0.7
			draw_arc(center, NODE_RADIUS + 2.0, 0.0, TAU, 24, score_color, 1.5)

		# Final node pulse
		if is_last:
			var pulse: float = (sin(_time * PULSE_SPEED) + 1.0) * 0.5
			var pulse_color: Color = Color(node_color.r, node_color.g, node_color.b, 0.12 + pulse * 0.15)
			draw_circle(center, GLOW_RADIUS + 3.0 + pulse * 2.0, pulse_color)
			# Outcome glyph
			var glyph: String = "✓" if _is_victory else "☠"
			var glyph_color: Color = Color(node_color.r, node_color.g, node_color.b, node_alpha)
			draw_string(ThemeDB.fallback_font, center + Vector2(-4.0, 4.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, glyph_color)

		# Text label
		var label_text: String = _get_entry_label(entry, _scroll_offset + i)
		var label_color: Color = pal["phosphor_dim"]
		if is_last:
			label_color = node_color
		label_color.a = node_alpha
		draw_string(ThemeDB.fallback_font, Vector2(LEFT_MARGIN + TEXT_OFFSET_X, y_pos + 4.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, label_color)

		# Score percentage badge (right-aligned)
		if score >= 0:
			var badge_text: String = "%d%%" % score
			var badge_color: Color = _get_score_color(score, pal)
			badge_color.a = node_alpha * 0.8
			draw_string(ThemeDB.fallback_font, Vector2(size.x - 48.0, y_pos + 4.0), badge_text, HORIZONTAL_ALIGNMENT_RIGHT, 40, 11, badge_color)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_len: float, gap_len: float) -> void:
	var dir: Vector2 = (to - from)
	var total: float = dir.length()
	if total < 0.01:
		return
	dir = dir / total
	var pos: float = 0.0
	while pos < total:
		var end_pos: float = minf(pos + dash_len, total)
		draw_line(from + dir * pos, from + dir * end_pos, color, width)
		pos = end_pos + gap_len


func _draw_empty_message() -> void:
	var msg_color: Color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
	msg_color.a = 0.5
	draw_string(ThemeDB.fallback_font, Vector2(LEFT_MARGIN, 30.0), "Aucune carte jouee", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, msg_color)
	# Decorative dashed line
	_draw_dashed_line(Vector2(LEFT_MARGIN, 40.0), Vector2(LEFT_MARGIN, custom_minimum_size.y - 10.0), MerlinVisual.CRT_PALETTE["line"], 1.0, 3.0, 5.0)


func _get_entry_label(entry: Dictionary, global_index: int) -> String:
	var card_idx: int = int(entry.get("card_idx", global_index + 1))
	var text: String = str(entry.get("text", ""))
	var choice: String = str(entry.get("choice", ""))

	var display_text: String = text
	if display_text.length() > 35:
		display_text = display_text.substr(0, 32) + "..."

	if not choice.is_empty():
		return "#%d %s [%s]" % [card_idx, display_text, choice]
	if not display_text.is_empty():
		return "#%d %s" % [card_idx, display_text]
	return "#%d" % card_idx


func _get_node_color(entry: Dictionary, is_last: bool) -> Color:
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	if is_last:
		return pal["amber"] if _is_victory else pal["danger"]
	var score: int = int(entry.get("score", -1))
	if score >= 80:
		return pal["success"]
	if score >= 0 and score < 30:
		return pal["danger"]
	var choice: String = str(entry.get("choice", ""))
	if choice.is_empty():
		return pal["phosphor_dim"]
	return pal["phosphor"]


func _get_score_color(score: int, pal: Dictionary) -> Color:
	if score >= 80:
		return pal["success"]
	if score >= 50:
		return pal["phosphor"]
	if score >= 30:
		return pal["amber"]
	return pal["danger"]
