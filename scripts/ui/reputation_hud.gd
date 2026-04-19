## ReputationHud — PSX-styled faction reputation display.
## Compact horizontal bar with 5 faction gauges, tier labels, threshold markers.
## Self-updates via MerlinStore.reputation_changed signal.

class_name ReputationHud
extends Control

const _FACTION_GLYPHS := {
	"druides":   "\u2698",
	"anciens":   "\u25B2",
	"korrigans": "\u2618",
	"niamh":     "\u2666",
	"ankou":     "\u2620",
}

const _FACTION_COLORS := {
	"druides":   Color(0.20, 1.00, 0.40),
	"anciens":   Color(1.00, 0.75, 0.20),
	"korrigans": Color(0.30, 0.85, 0.80),
	"niamh":     Color(0.50, 1.00, 0.95),
	"ankou":     Color(1.00, 0.30, 0.25),
}

const _TIER_THRESHOLDS := [
	{"min": 80.0, "label": "Honore",       "color_key": "phosphor_bright"},
	{"min": 50.0, "label": "Sympathisant", "color_key": "amber_bright"},
	{"min": 20.0, "label": "Neutre",       "color_key": "phosphor_dim"},
	{"min":  5.0, "label": "Mefiant",      "color_key": "amber_dim"},
	{"min":  0.0, "label": "Hostile",      "color_key": "danger"},
]

var _faction_bars: Dictionary = {}
var _faction_values: Dictionary = {}
var _faction_tier_labels: Dictionary = {}
var _faction_value_labels: Dictionary = {}
var _store: Node
var _container: HBoxContainer
var _collapsed: bool = false
var _toggle_btn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_store = get_node_or_null("/root/MerlinStore")
	_build_ui()
	if _store and _store.has_signal("reputation_changed"):
		_store.reputation_changed.connect(_on_reputation_changed)
	_load_initial_values()


func _build_ui() -> void:
	var pal: Dictionary = MerlinVisual.CRT_PALETTE

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	root.anchor_top = 0.88
	root.offset_top = 0
	root.offset_bottom = 0
	root.add_theme_constant_override("separation", 2)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_theme_constant_override("separation", 8)
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header_row)

	_toggle_btn = Button.new()
	_toggle_btn.text = "\u25BC FACTIONS"
	_toggle_btn.flat = true
	MerlinVisual.apply_responsive_font(_toggle_btn, 11, "terminal")
	_toggle_btn.add_theme_color_override("font_color", pal.phosphor_dim)
	_toggle_btn.add_theme_color_override("font_hover_color", pal.phosphor)
	_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle_btn.pressed.connect(_on_toggle)
	header_row.add_child(_toggle_btn)

	_container = HBoxContainer.new()
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.add_theme_constant_override("separation", 6)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_container)

	for faction: String in MerlinReputationSystem.FACTIONS:
		_build_faction_gauge(faction, pal)


func _build_faction_gauge(faction: String, pal: Dictionary) -> void:
	var accent: Color = _FACTION_COLORS.get(faction, pal.phosphor)
	var glyph: String = _FACTION_GLYPHS.get(faction, "\u25C6")

	var gauge_box: VBoxContainer = VBoxContainer.new()
	gauge_box.add_theme_constant_override("separation", 1)
	gauge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge_box.custom_minimum_size.x = MerlinVisual.responsive_size(56)
	_container.add_child(gauge_box)

	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 2)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge_box.add_child(name_row)

	var icon_label: Label = Label.new()
	icon_label.text = glyph
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", MerlinVisual.responsive_size(13))
	icon_label.add_theme_color_override("font_color", accent)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(icon_label)

	var value_label: Label = Label.new()
	value_label.text = "20"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MerlinVisual.apply_responsive_font(value_label, 11, "terminal")
	value_label.add_theme_color_override("font_color", pal.phosphor)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(value_label)
	_faction_value_labels[faction] = value_label

	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(MerlinVisual.responsive_size(56), MerlinVisual.responsive_size(6))
	bar_bg.color = pal.bg_highlight
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge_box.add_child(bar_bg)

	var bar_fill: ColorRect = ColorRect.new()
	bar_fill.position = Vector2.ZERO
	bar_fill.size = Vector2(0.0, MerlinVisual.responsive_size(6))
	bar_fill.color = accent
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(bar_fill)

	_add_threshold_marker(bar_bg, 50.0, pal.amber_dim)
	_add_threshold_marker(bar_bg, 80.0, pal.amber_bright)

	var tier_label: Label = Label.new()
	tier_label.text = "Neutre"
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MerlinVisual.apply_responsive_font(tier_label, 9, "terminal")
	tier_label.add_theme_color_override("font_color", pal.phosphor_dim)
	tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge_box.add_child(tier_label)
	_faction_tier_labels[faction] = tier_label

	_faction_bars[faction] = {"bg": bar_bg, "fill": bar_fill, "accent": accent}
	_faction_values[faction] = 20.0


func _add_threshold_marker(bar_bg: ColorRect, threshold: float, marker_color: Color) -> void:
	var marker: ColorRect = ColorRect.new()
	var bar_w: float = bar_bg.custom_minimum_size.x
	marker.position = Vector2(bar_w * (threshold / 100.0) - 0.5, 0.0)
	marker.size = Vector2(1.0, bar_bg.custom_minimum_size.y)
	marker.color = Color(marker_color.r, marker_color.g, marker_color.b, 0.5)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(marker)


func _load_initial_values() -> void:
	if not _store:
		return
	var factions: Dictionary = {}
	if _store.get("state") is Dictionary:
		var state: Dictionary = _store.state as Dictionary
		factions = state.get("meta", {}).get("faction_rep", {})
	for faction: String in factions:
		_set_value(faction, float(factions[faction]), false)


func _on_reputation_changed(faction: String, value: float, _delta: float) -> void:
	_set_value(faction, value, true)


func _set_value(faction: String, value: float, animate: bool) -> void:
	if not _faction_bars.has(faction):
		return

	var old_value: float = _faction_values.get(faction, 0.0)
	_faction_values[faction] = value
	var bar_data: Dictionary = _faction_bars[faction]
	var bar_bg: ColorRect = bar_data.bg as ColorRect
	var bar_fill: ColorRect = bar_data.fill as ColorRect
	var bar_w: float = bar_bg.custom_minimum_size.x
	var target_w: float = bar_w * clampf(value / 100.0, 0.0, 1.0)

	if animate and is_inside_tree():
		var tw: Tween = create_tween()
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(bar_fill, "size:x", target_w, 0.5)

		var vl: Label = _faction_value_labels.get(faction) as Label
		if vl:
			tw.parallel().tween_method(
				func(v: float) -> void: vl.text = str(int(v)),
				old_value, value, 0.5
			)
		_flash_bar(bar_data, value > old_value)
	else:
		bar_fill.size.x = target_w
		var vl: Label = _faction_value_labels.get(faction) as Label
		if vl:
			vl.text = str(int(value))

	_update_tier(faction, value)


func _flash_bar(bar_data: Dictionary, positive: bool) -> void:
	var fill: ColorRect = bar_data.fill as ColorRect
	var accent: Color = bar_data.accent as Color
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	var flash_color: Color = pal.phosphor_bright if positive else pal.danger

	var flash_tw: Tween = create_tween()
	flash_tw.tween_property(fill, "color", flash_color, 0.1)
	flash_tw.tween_property(fill, "color", accent, 0.4)


func _update_tier(faction: String, value: float) -> void:
	var tier_label: Label = _faction_tier_labels.get(faction) as Label
	if not tier_label:
		return

	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	for tier: Dictionary in _TIER_THRESHOLDS:
		if value >= float(tier.min):
			tier_label.text = str(tier.label)
			var c: Color = pal.get(str(tier.color_key), pal.phosphor_dim)
			tier_label.add_theme_color_override("font_color", c)
			return


func _on_toggle() -> void:
	_collapsed = not _collapsed
	_container.visible = not _collapsed
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	if _collapsed:
		_toggle_btn.text = "\u25B6 FACTIONS"
	else:
		_toggle_btn.text = "\u25BC FACTIONS"


func update_all(factions: Dictionary) -> void:
	for faction: String in factions:
		_set_value(faction, float(factions[faction]), false)
