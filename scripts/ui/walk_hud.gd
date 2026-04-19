## ═══════════════════════════════════════════════════════════════════════════════
## WalkHUD — Run HUD (PV, Ogham, Currency, Factions, Turn)
## ═══════════════════════════════════════════════════════════════════════════════
## Overlays the 3D viewport during forest walk gameplay.
## CRT phosphor aesthetic, VT323 monospace font, responsive sizing.
## ═══════════════════════════════════════════════════════════════════════════════

extends CanvasLayer

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

const FONT_SIZE_HUD: int = 14
const FONT_SIZE_ZONE: int = 11
const MARGIN_H: int = 12
const MARGIN_V: int = 8
const PV_BAR_WIDTH: float = 120.0
const PV_BAR_HEIGHT: float = 10.0

const _FACTION_COLORS := {
	"druides":   Color(0.20, 0.85, 0.40),
	"anciens":   Color(1.00, 0.75, 0.20),
	"korrigans": Color(0.80, 0.40, 1.00),
	"niamh":     Color(0.30, 0.70, 1.00),
	"ankou":     Color(1.00, 0.25, 0.20),
}

const _FACTION_GLYPHS := {
	"druides": "\u2663", "anciens": "\u2662",
	"korrigans": "\u2660", "niamh": "\u2661", "ankou": "\u2620",
}

# ═══════════════════════════════════════════════════════════════════════════════
# NODES
# ═══════════════════════════════════════════════════════════════════════════════

var _root: Control
var _pv_bar: ProgressBar
var _pv_label: Label
var _pv_bar_fill: StyleBoxFlat
var _essences_label: Label
var _zone_label: Label
var _crosshair: Label
var _ogham_label: Label
var _ogham_cd_label: Label
var _turn_label: Label
var _faction_labels: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _show_zone: bool = true


func _ready() -> void:
	layer = 5
	_build_ui()


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func update_pv(current: int, max_pv: int) -> void:
	var old_val: int = int(_pv_bar.value)
	_pv_bar.max_value = max_pv
	_pv_bar.value = current
	_pv_label.text = "PV %d/%d" % [current, max_pv]
	var ratio: float = float(current) / float(max_pv) if max_pv > 0 else 1.0
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	if ratio <= 0.25:
		_pv_label.add_theme_color_override("font_color", pal["danger"])
	elif ratio <= 0.50:
		_pv_label.add_theme_color_override("font_color", pal["warning"])
	else:
		_pv_label.add_theme_color_override("font_color", pal["phosphor"])
	if current < old_val:
		_flash_bar(pal["danger"])
	elif current > old_val:
		_flash_bar(pal["cyan"])


func update_essences(count: int) -> void:
	_essences_label.text = "\u2666 %d" % count


func update_zone(zone_name: String, season_name: String, time_name: String) -> void:
	if _show_zone:
		var parts: Array[String] = [zone_name]
		if season_name != "":
			parts.append(season_name)
		if time_name != "":
			parts.append(time_name)
		_zone_label.text = " | ".join(parts)
		_zone_label.visible = true
	else:
		_zone_label.visible = false


func update_ogham(rune: String, ogham_name: String, cooldown: int) -> void:
	_ogham_label.text = "%s %s" % [rune, ogham_name]
	if cooldown <= 0:
		_ogham_cd_label.text = "Pret"
		_ogham_cd_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["cyan"])
	else:
		_ogham_cd_label.text = "CD: %d" % cooldown
		_ogham_cd_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])


func update_turn(cards_played: int, mos_target: int) -> void:
	if mos_target > 0:
		_turn_label.text = "Carte %d/%d" % [cards_played, mos_target]
	else:
		_turn_label.text = "Carte %d" % cards_played
	if mos_target > 0 and cards_played >= mos_target - 3:
		_turn_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["amber"])
	else:
		_turn_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])


func update_factions(factions: Dictionary) -> void:
	for faction_id: String in _faction_labels:
		var label: Label = _faction_labels[faction_id] as Label
		var val: int = int(factions.get(faction_id, 0))
		var glyph: String = _FACTION_GLYPHS.get(faction_id, "\u25C6")
		var bar_str: String = _make_mini_bar(val, 100, 5)
		label.text = "%s%s" % [glyph, bar_str]
		var base_color: Color = _FACTION_COLORS.get(faction_id, MerlinVisual.CRT_PALETTE["phosphor_dim"])
		var alpha: float = 0.4 + (float(val) / 100.0) * 0.6
		label.add_theme_color_override("font_color", Color(base_color.r, base_color.g, base_color.b, alpha))


func toggle_zone_display() -> void:
	_show_zone = not _show_zone
	_zone_label.visible = _show_zone


func set_crosshair_visible(vis: bool) -> void:
	_crosshair.visible = vis


func _flash_bar(flash_color: Color) -> void:
	if not _pv_bar_fill:
		return
	var original: Color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
	_pv_bar_fill.bg_color = flash_color
	var tw: Tween = _pv_bar.create_tween()
	tw.tween_property(_pv_bar_fill, "bg_color", original, 0.4)


static func _make_mini_bar(value: int, max_val: int, segments: int) -> String:
	var filled: int = int(float(value) / float(max_val) * float(segments))
	filled = clampi(filled, 0, segments)
	return "\u2588".repeat(filled) + "\u2591".repeat(segments - filled)


# ═══════════════════════════════════════════════════════════════════════════════
# BUILD UI
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var font: Font = MerlinVisual.get_font("terminal")
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	var sz_hud: int = MerlinVisual.responsive_size(FONT_SIZE_HUD)
	var sz_zone: int = MerlinVisual.responsive_size(FONT_SIZE_ZONE)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# === TOP ROW ===
	var top_margin: MarginContainer = MarginContainer.new()
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.add_theme_constant_override("margin_left", MARGIN_H)
	top_margin.add_theme_constant_override("margin_right", MARGIN_H)
	top_margin.add_theme_constant_override("margin_top", MARGIN_V)
	_root.add_child(top_margin)

	var top_hbox: HBoxContainer = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 20)
	top_margin.add_child(top_hbox)

	# PV section (left)
	var pv_vbox: VBoxContainer = VBoxContainer.new()
	pv_vbox.add_theme_constant_override("separation", 2)
	top_hbox.add_child(pv_vbox)

	_pv_label = Label.new()
	_pv_label.text = "PV 100/100"
	_pv_label.add_theme_font_override("font", font)
	_pv_label.add_theme_font_size_override("font_size", sz_hud)
	_pv_label.add_theme_color_override("font_color", pal["phosphor"])
	pv_vbox.add_child(_pv_label)

	_pv_bar = ProgressBar.new()
	_pv_bar.custom_minimum_size = Vector2(PV_BAR_WIDTH, PV_BAR_HEIGHT)
	_pv_bar.max_value = 100
	_pv_bar.value = 100
	_pv_bar.show_percentage = false

	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = pal["bg_dark"]
	bar_bg.border_color = pal["border"]
	bar_bg.set_border_width_all(1)
	bar_bg.set_corner_radius_all(1)
	_pv_bar.add_theme_stylebox_override("background", bar_bg)

	_pv_bar_fill = StyleBoxFlat.new()
	_pv_bar_fill.bg_color = pal["phosphor_dim"]
	_pv_bar_fill.set_corner_radius_all(1)
	_pv_bar.add_theme_stylebox_override("fill", _pv_bar_fill)
	pv_vbox.add_child(_pv_bar)

	# Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	# Ogham actif (center)
	var ogham_vbox: VBoxContainer = VBoxContainer.new()
	ogham_vbox.add_theme_constant_override("separation", 2)
	top_hbox.add_child(ogham_vbox)

	_ogham_label = Label.new()
	_ogham_label.text = "\u1681 Beith"
	_ogham_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ogham_label.add_theme_font_override("font", font)
	_ogham_label.add_theme_font_size_override("font_size", sz_hud + 2)
	_ogham_label.add_theme_color_override("font_color", pal["cyan"])
	ogham_vbox.add_child(_ogham_label)

	_ogham_cd_label = Label.new()
	_ogham_cd_label.text = "Pret"
	_ogham_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ogham_cd_label.add_theme_font_override("font", font)
	_ogham_cd_label.add_theme_font_size_override("font_size", sz_zone)
	_ogham_cd_label.add_theme_color_override("font_color", pal["phosphor_dim"])
	ogham_vbox.add_child(_ogham_cd_label)

	# Spacer
	var spacer2: Control = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer2)

	# Essences (right)
	_essences_label = Label.new()
	_essences_label.text = "\u2666 0"
	_essences_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_essences_label.add_theme_font_override("font", font)
	_essences_label.add_theme_font_size_override("font_size", sz_hud)
	_essences_label.add_theme_color_override("font_color", pal["amber"])
	top_hbox.add_child(_essences_label)

	# === CROSSHAIR (center) ===
	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair.add_theme_font_override("font", font)
	_crosshair.add_theme_font_size_override("font_size", MerlinVisual.responsive_size(14))
	_crosshair.add_theme_color_override("font_color", pal["phosphor_dim"])
	_root.add_child(_crosshair)

	# === BOTTOM BAR ===
	var bottom_margin: MarginContainer = MarginContainer.new()
	bottom_margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_margin.add_theme_constant_override("margin_left", MARGIN_H)
	bottom_margin.add_theme_constant_override("margin_right", MARGIN_H)
	bottom_margin.add_theme_constant_override("margin_bottom", MARGIN_V)
	_root.add_child(bottom_margin)

	var bottom_hbox: HBoxContainer = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 12)
	bottom_margin.add_child(bottom_hbox)

	# Zone label (bottom-left)
	_zone_label = Label.new()
	_zone_label.text = ""
	_zone_label.add_theme_font_override("font", font)
	_zone_label.add_theme_font_size_override("font_size", sz_zone)
	_zone_label.add_theme_color_override("font_color", pal["phosphor_dim"])
	bottom_hbox.add_child(_zone_label)

	# Turn counter
	_turn_label = Label.new()
	_turn_label.text = "Carte 0"
	_turn_label.add_theme_font_override("font", font)
	_turn_label.add_theme_font_size_override("font_size", sz_zone)
	_turn_label.add_theme_color_override("font_color", pal["phosphor_dim"])
	bottom_hbox.add_child(_turn_label)

	# Spacer
	var bottom_spacer: Control = Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(bottom_spacer)

	# Faction mini-badges (bottom-right)
	for faction_id: String in ["druides", "anciens", "korrigans", "niamh", "ankou"]:
		var fl: Label = Label.new()
		var glyph: String = _FACTION_GLYPHS.get(faction_id, "\u25C6")
		fl.text = "%s%s" % [glyph, _make_mini_bar(20, 100, 5)]
		fl.add_theme_font_override("font", font)
		fl.add_theme_font_size_override("font_size", sz_zone)
		var fc: Color = _FACTION_COLORS.get(faction_id, pal["phosphor_dim"])
		fl.add_theme_color_override("font_color", Color(fc.r, fc.g, fc.b, 0.5))
		fl.tooltip_text = str(MerlinConstants.FACTION_INFO.get(faction_id, {}).get("name", faction_id))
		bottom_hbox.add_child(fl)
		_faction_labels[faction_id] = fl
