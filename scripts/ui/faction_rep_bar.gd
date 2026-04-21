## ═══════════════════════════════════════════════════════════════════════════════
## FactionRepBar — Horizontal faction reputation bar with threshold markers
## ═══════════════════════════════════════════════════════════════════════════════
## Displays a single faction's reputation (0-100) with CRT terminal styling.
## Threshold markers at 50 (content unlock) and 80 (ending unlock).
## Colors from MerlinVisual.CRT_PALETTE.
## ═══════════════════════════════════════════════════════════════════════════════

extends Control
class_name FactionRepBar

signal bar_clicked(faction_id: String)

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const BAR_HEIGHT: int = 18
const BAR_MIN_WIDTH: int = 120
const THRESHOLD_CONTENT: int = 50
const THRESHOLD_ENDING: int = 80
const VALUE_MIN: float = 0.0
const VALUE_MAX: float = 100.0

## Faction-specific colors (CRT terminal aesthetic) — from MerlinVisual.CRT_PALETTE
static var FACTION_COLORS: Dictionary:
	get:
		if _faction_colors_cache.is_empty():
			_faction_colors_cache = {
				"druides":   MerlinVisual.CRT_PALETTE["faction_druides"],
				"anciens":   MerlinVisual.CRT_PALETTE["faction_anciens"],
				"korrigans": MerlinVisual.CRT_PALETTE["faction_korrigans"],
				"niamh":     MerlinVisual.CRT_PALETTE["faction_niamh"],
				"ankou":     MerlinVisual.CRT_PALETTE["faction_ankou"],
			}
		return _faction_colors_cache
static var _faction_colors_cache: Dictionary = {}

const FACTION_SYMBOLS: Dictionary = {
	"druides":   "[D]",
	"anciens":   "[A]",
	"korrigans": "[K]",
	"niamh":     "[N]",
	"ankou":     "[X]",
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _faction_id: String = ""
var _value: float = 0.0
var _faction_name: String = ""
var _faction_color: Color = Color.WHITE

# ═══════════════════════════════════════════════════════════════════════════════
# UI NODES
# ═══════════════════════════════════════════════════════════════════════════════

var _icon_label: Label
var _name_label: Label
var _bar_container: Control
var _value_label: Label
var _tier_label: Label

# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	custom_minimum_size = Vector2(280, 32)
	_build_ui()


func _build_ui() -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 6)
	add_child(hbox)

	# Faction symbol
	_icon_label = Label.new()
	_icon_label.custom_minimum_size = Vector2(32, 0)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label_style(_icon_label, 14)
	hbox.add_child(_icon_label)

	# Faction name
	_name_label = Label.new()
	_name_label.custom_minimum_size = Vector2(90, 0)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label_style(_name_label, 12)
	hbox.add_child(_name_label)

	# Bar container (draws the bar via _draw override)
	_bar_container = Control.new()
	_bar_container.custom_minimum_size = Vector2(BAR_MIN_WIDTH, BAR_HEIGHT)
	_bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_container.draw.connect(_draw_bar)
	hbox.add_child(_bar_container)

	# Value text
	_value_label = Label.new()
	_value_label.custom_minimum_size = Vector2(36, 0)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label_style(_value_label, 12)
	hbox.add_child(_value_label)

	# Tier label
	_tier_label = Label.new()
	_tier_label.custom_minimum_size = Vector2(80, 0)
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label_style(_tier_label, 10)
	hbox.add_child(_tier_label)


func _apply_label_style(label: Label, font_size: int) -> void:
	var c: Color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
	label.add_theme_color_override("font_color", c)
	MerlinVisual.apply_responsive_font(label, font_size, "terminal")


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func update(faction_id: String, value: float) -> void:
	_faction_id = faction_id
	_value = clampf(value, VALUE_MIN, VALUE_MAX)

	var info: Dictionary = MerlinConstants.FACTION_INFO.get(faction_id, {})
	_faction_name = str(info.get("name", faction_id))
	_faction_color = FACTION_COLORS.get(faction_id, Color.WHITE)

	_refresh_labels()
	if _bar_container:
		_bar_container.queue_redraw()


func get_faction_id() -> String:
	return _faction_id


func get_value() -> float:
	return _value


func get_tier() -> String:
	return _calculate_tier(_value)


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL
# ═══════════════════════════════════════════════════════════════════════════════

func _refresh_labels() -> void:
	if _icon_label:
		_icon_label.text = FACTION_SYMBOLS.get(_faction_id, "?")
		_icon_label.add_theme_color_override("font_color", _faction_color)
	if _name_label:
		_name_label.text = _faction_name
		_name_label.add_theme_color_override("font_color", _faction_color)
	if _value_label:
		_value_label.text = str(int(_value))
		var phosphor: Color = MerlinVisual.CRT_PALETTE["phosphor"]
		_value_label.add_theme_color_override("font_color", phosphor)
	if _tier_label:
		var tier: String = _calculate_tier(_value)
		_tier_label.text = tier
		var tier_color: Color = _get_tier_color(tier)
		_tier_label.add_theme_color_override("font_color", tier_color)


func _draw_bar() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _bar_container.size)
	var bar_h: float = rect.size.y

	# Background
	var bg_color: Color = MerlinVisual.CRT_PALETTE["bg_dark"]
	_bar_container.draw_rect(rect, bg_color)

	# Border
	var border_color: Color = MerlinVisual.CRT_PALETTE["border"]
	_bar_container.draw_rect(rect, border_color, false, 1.0)

	# Fill
	var fill_ratio: float = _value / VALUE_MAX
	var fill_width: float = rect.size.x * fill_ratio
	if fill_width > 0:
		var fill_rect: Rect2 = Rect2(rect.position, Vector2(fill_width, bar_h))
		var fill_color: Color = _faction_color
		fill_color.a = 0.7
		_bar_container.draw_rect(fill_rect, fill_color)

	# Threshold markers
	_draw_threshold_marker(rect, THRESHOLD_CONTENT)
	_draw_threshold_marker(rect, THRESHOLD_ENDING)


func _draw_threshold_marker(rect: Rect2, threshold: int) -> void:
	var x_pos: float = rect.position.x + rect.size.x * (float(threshold) / VALUE_MAX)
	var amber: Color = MerlinVisual.CRT_PALETTE["amber"]
	amber.a = 0.6
	var top: Vector2 = Vector2(x_pos, rect.position.y)
	var bottom: Vector2 = Vector2(x_pos, rect.position.y + rect.size.y)
	_bar_container.draw_line(top, bottom, amber, 2.0)


func _calculate_tier(value: float) -> String:
	if value >= 80.0:
		return "Honore"
	elif value >= 50.0:
		return "Sympathisant"
	elif value >= 20.0:
		return "Neutre"
	elif value >= 5.0:
		return "Mefiant"
	else:
		return "Hostile"


func _get_tier_color(tier: String) -> Color:
	match tier:
		"Honore":
			return MerlinVisual.CRT_PALETTE["amber_bright"]
		"Sympathisant":
			return MerlinVisual.CRT_PALETTE["phosphor"]
		"Neutre":
			return MerlinVisual.CRT_PALETTE["phosphor_dim"]
		"Mefiant":
			return MerlinVisual.CRT_PALETTE["warning"]
		"Hostile":
			return MerlinVisual.CRT_PALETTE["danger"]
		_:
			return MerlinVisual.CRT_PALETTE["inactive"]
