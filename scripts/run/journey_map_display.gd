## ═══════════════════════════════════════════════════════════════════════════════
## JourneyMapDisplay — Vertical journey map of cards played during a run
## ═══════════════════════════════════════════════════════════════════════════════
## Shows the path taken through the run as a vertical list:
## - Each card shown as a node with title + outcome icon
## - Connected by vertical lines
## - Final node highlighted (victory or death)
## Bible s.5.3: "Carte du voyage — stylized biome map with pins at key moments"
## ═══════════════════════════════════════════════════════════════════════════════

extends Control
class_name JourneyMapDisplay

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const NODE_RADIUS: float = 6.0
const LINE_WIDTH: float = 2.0
const NODE_SPACING: float = 32.0
const LEFT_MARGIN: float = 24.0
const TEXT_OFFSET_X: float = 20.0
const MAX_VISIBLE_NODES: int = 12
const LABEL_FONT_SIZE: int = 13

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _story_entries: Array = []
var _is_victory: bool = false
var _headless: bool = false
var _scroll_offset: int = 0


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(story_log: Array, is_victory: bool, headless: bool = false) -> void:
	_story_entries = story_log
	_is_victory = is_victory
	_headless = headless

	# If more entries than visible, scroll to show the last ones
	if _story_entries.size() > MAX_VISIBLE_NODES:
		_scroll_offset = _story_entries.size() - MAX_VISIBLE_NODES

	# Calculate minimum height
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

	var visible_entries: Array = get_visible_entries()
	if visible_entries.is_empty():
		_draw_empty_message()
		return

	var line_color: Color = MerlinVisual.CRT_PALETTE["line"]
	var node_color: Color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
	var text_color: Color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
	var last_index: int = visible_entries.size() - 1

	for i in visible_entries.size():
		var entry: Dictionary = visible_entries[i] if visible_entries[i] is Dictionary else {}
		var y_pos: float = NODE_SPACING * 0.5 + float(i) * NODE_SPACING
		var center: Vector2 = Vector2(LEFT_MARGIN, y_pos)
		var is_last: bool = (i == last_index) and (_scroll_offset + i == _story_entries.size() - 1)

		# Draw connecting line to next node
		if i < last_index:
			var next_y: float = NODE_SPACING * 0.5 + float(i + 1) * NODE_SPACING
			draw_line(center, Vector2(LEFT_MARGIN, next_y), line_color, LINE_WIDTH)

		# Determine node color
		var current_node_color: Color = node_color
		if is_last:
			current_node_color = _get_final_node_color()
		else:
			current_node_color = _get_entry_color(entry)

		# Draw node circle
		draw_circle(center, NODE_RADIUS, current_node_color)

		# Draw text label
		var card_text: String = _get_entry_label(entry, _scroll_offset + i)
		var label_color: Color = text_color
		if is_last:
			label_color = _get_final_node_color()

		var text_pos: Vector2 = Vector2(LEFT_MARGIN + TEXT_OFFSET_X, y_pos + 4.0)
		draw_string(
			ThemeDB.fallback_font,
			text_pos,
			card_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			LABEL_FONT_SIZE,
			label_color
		)

		# Draw outcome icon for the last node
		if is_last:
			var icon_text: String = "V" if _is_victory else "X"
			var icon_color: Color = _get_final_node_color()
			draw_circle(center, NODE_RADIUS + 2.0, Color(icon_color.r, icon_color.g, icon_color.b, 0.3))


func _draw_empty_message() -> void:
	var msg_color: Color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
	draw_string(
		ThemeDB.fallback_font,
		Vector2(LEFT_MARGIN, 30.0),
		"Aucune carte jouee",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		LABEL_FONT_SIZE,
		msg_color
	)


# ═══════════════════════════════════════════════════════════════════════════════
# ENTRY HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _get_entry_label(entry: Dictionary, global_index: int) -> String:
	var card_idx: int = int(entry.get("card_idx", global_index + 1))
	var text: String = str(entry.get("text", ""))
	var choice: String = str(entry.get("choice", ""))

	# Truncate text for display
	var display_text: String = text
	if display_text.length() > 40:
		display_text = display_text.substr(0, 37) + "..."

	if not choice.is_empty():
		return "#%d %s [%s]" % [card_idx, display_text, choice]
	if not display_text.is_empty():
		return "#%d %s" % [card_idx, display_text]
	return "#%d" % card_idx


func _get_entry_color(entry: Dictionary) -> Color:
	var choice: String = str(entry.get("choice", ""))
	if choice.is_empty():
		return MerlinVisual.CRT_PALETTE["phosphor_dim"]
	return MerlinVisual.CRT_PALETTE["phosphor"]


func _get_final_node_color() -> Color:
	if _is_victory:
		return MerlinVisual.CRT_PALETTE["amber"]
	return MerlinVisual.CRT_PALETTE["danger"]
