## ═══════════════════════════════════════════════════════════════════════════════
## LLM Source Badge — Dev indicator for LLM vs Fallback text (v1.0)
## ═══════════════════════════════════════════════════════════════════════════════
## Reusable pill-shaped badge showing text generation source.
## Usage:
##   var badge := LLMSourceBadge.create("llm")   # green
##   var badge := LLMSourceBadge.create("fallback") # amber
##   parent.add_child(badge)
##   LLMSourceBadge.update_badge(badge, "llm")  # change source later
## ═══════════════════════════════════════════════════════════════════════════════

class_name LLMSourceBadge
extends RefCounted


static var BADGE_COLORS: Dictionary:
	get:
		if _badge_colors_cache.is_empty():
			_badge_colors_cache = {
				"llm": MerlinVisual.CRT_PALETTE["badge_llm"],         # Green
				"fallback": MerlinVisual.CRT_PALETTE["badge_fallback"], # Amber
				"static": MerlinVisual.CRT_PALETTE["badge_static"],   # Gray
				"error": MerlinVisual.CRT_PALETTE["badge_error"],     # Red
			}
		return _badge_colors_cache
static var _badge_colors_cache: Dictionary = {}

const BADGE_LABELS := {
	"llm": "LLM",
	"fallback": "FB",
	"static": "JSON",
	"error": "ERR",
}

const BADGE_DOTS := {
	"llm": "* ",       # Was U+25CF
	"fallback": "o ",  # Was U+25CB
	"static": "# ",    # Was U+25AA
	"error": "x ",     # Was U+2716
}

const FONT_SIZE := 10
const CORNER_RADIUS := 6


static func create(source: String = "static") -> PanelContainer:
	## Create a new source badge. source = "llm", "fallback", "static", "error".
	var panel := PanelContainer.new()
	panel.name = "LLMSourceBadge"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.name = "BadgeLabel"
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_bright"])
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	_apply_source(panel, label, source)
	return panel


static func update_badge(badge: PanelContainer, source: String) -> void:
	## Update an existing badge to a new source.
	if badge == null or not is_instance_valid(badge):
		return
	var label: Label = badge.get_node_or_null("BadgeLabel")
	if label == null:
		return
	_apply_source(badge, label, source)


static func _apply_source(panel: PanelContainer, label: Label, source: String) -> void:
	var key := source if BADGE_COLORS.has(source) else "static"

	# Text
	var dot: String = BADGE_DOTS.get(key, "")
	var lbl: String = BADGE_LABELS.get(key, "?")
	label.text = dot + lbl

	# Tooltip
	match key:
		"llm":
			panel.tooltip_text = "Texte genere par M.E.R.L.I.N."
		"fallback":
			panel.tooltip_text = "Texte de secours (JSON / pool)"
		"static":
			panel.tooltip_text = "Texte statique (script)"
		"error":
			panel.tooltip_text = "Erreur de generation"

	# Style
	var style := StyleBoxFlat.new()
	style.bg_color = BADGE_COLORS.get(key, Color.GRAY)
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

	# Subtle entrance animation
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
