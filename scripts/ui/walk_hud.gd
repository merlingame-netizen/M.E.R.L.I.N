## ═══════════════════════════════════════════════════════════════════════════════
## WalkHUD — Minimal 3D Walk HUD (PV, Currency, Ogham, Card Count)
## ═══════════════════════════════════════════════════════════════════════════════
## Overlays the 3D viewport during forest walk gameplay.
## CRT phosphor aesthetic, VT323 monospace font.
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

# ═══════════════════════════════════════════════════════════════════════════════
# NODES
# ═══════════════════════════════════════════════════════════════════════════════

var _root: Control
var _pv_bar: ProgressBar
var _pv_label: Label
var _currency_label: Label
var _card_count_label: Label
var _zone_label: Label
var _crosshair: Label
var _ogham_label: Label
var _ogham_cd_label: Label
# C28 — minimal HUD cohabitation: active gift count chip + faction shift floater.
var _gifts_chip: Label
var _shift_layer: Control  # parent for floating shift labels

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
	_pv_bar.max_value = max_pv
	_pv_bar.value = current
	_pv_label.text = "PV %d/%d" % [current, max_pv]
	# Color shift when low
	var ratio: float = float(current) / float(max_pv) if max_pv > 0 else 1.0
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	if ratio <= 0.25:
		_pv_label.add_theme_color_override("font_color", pal["danger"])
	elif ratio <= 0.50:
		_pv_label.add_theme_color_override("font_color", pal["warning"])
	else:
		_pv_label.add_theme_color_override("font_color", pal["phosphor"])


func update_currency(count: int) -> void:
	_currency_label.text = "\u25C6 %d" % count


func update_essences(count: int) -> void:
	update_currency(count)


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


## C28 — Update the gift-active chip with the count of gifts taken so far this run.
## Empty/0 = chip hidden. The chip is purely informational, never blocks gameplay.
func update_gifts(count: int, last_label: String = "") -> void:
	if _gifts_chip == null:
		return
	if count <= 0:
		_gifts_chip.visible = false
		return
	# Format: "✦×N · last_label" — keeps the bottom-right chip a single tight line.
	var summary: String = "✦×%d" % count
	if not last_label.is_empty():
		summary += " · %s" % last_label
	_gifts_chip.text = summary
	_gifts_chip.visible = true


## C28 — Spawn a transient floating label (top-right) showing a faction reputation
## delta. Fades up + out over ~1.4s, no persistent state. Color reflects sign.
func show_faction_shift(faction: String, delta: int) -> void:
	if delta == 0 or _shift_layer == null:
		return
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	var lbl: Label = Label.new()
	var sign_str: String = "+" if delta > 0 else ""
	lbl.text = "%s%d %s" % [sign_str, delta, faction.capitalize()]
	lbl.add_theme_font_override("font", MerlinVisual.get_font("terminal"))
	lbl.add_theme_font_size_override("font_size", FONT_SIZE_HUD)
	lbl.add_theme_color_override("font_color", pal["success"] if delta > 0 else pal["danger"])
	lbl.modulate.a = 0.0
	# Stagger vertically so multiple shifts don't overlap.
	var existing: int = _shift_layer.get_child_count()
	lbl.position = Vector2(0, float(existing) * 22.0)
	_shift_layer.add_child(lbl)
	var t: Tween = lbl.create_tween().set_parallel(true)
	t.tween_property(lbl, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE)
	t.tween_property(lbl, "position:y", lbl.position.y - 24.0, 1.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(lbl, "modulate:a", 0.0, 0.40).set_trans(Tween.TRANS_SINE)
	t.chain().tween_callback(lbl.queue_free)


func update_card_count(current: int, total: int) -> void:
	_card_count_label.text = "Carte %d/%d" % [current, total]
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	var ratio: float = float(current) / float(total) if total > 0 else 0.0
	if ratio >= 0.8:
		_card_count_label.add_theme_color_override("font_color", pal["amber_bright"])
	elif ratio >= 0.5:
		_card_count_label.add_theme_color_override("font_color", pal["amber"])
	else:
		_card_count_label.add_theme_color_override("font_color", pal["phosphor_dim"])


func toggle_zone_display() -> void:
	_show_zone = not _show_zone
	_zone_label.visible = _show_zone


func set_crosshair_visible(vis: bool) -> void:
	_crosshair.visible = vis


# ═══════════════════════════════════════════════════════════════════════════════
# BUILD UI
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var font: Font = MerlinVisual.get_font("terminal")
	var pal: Dictionary = MerlinVisual.CRT_PALETTE

	# Root control
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
	_pv_label.add_theme_font_size_override("font_size", FONT_SIZE_HUD)
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

	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = pal["phosphor_dim"]
	bar_fill.set_corner_radius_all(1)
	_pv_bar.add_theme_stylebox_override("fill", bar_fill)
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
	_ogham_label.add_theme_font_size_override("font_size", FONT_SIZE_HUD + 2)
	_ogham_label.add_theme_color_override("font_color", pal["cyan"])
	ogham_vbox.add_child(_ogham_label)

	_ogham_cd_label = Label.new()
	_ogham_cd_label.text = "Pret"
	_ogham_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ogham_cd_label.add_theme_font_override("font", font)
	_ogham_cd_label.add_theme_font_size_override("font_size", FONT_SIZE_ZONE)
	_ogham_cd_label.add_theme_color_override("font_color", pal["phosphor_dim"])
	ogham_vbox.add_child(_ogham_cd_label)

	# Spacer
	var spacer2: Control = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer2)

	# Card count (center-right)
	_card_count_label = Label.new()
	_card_count_label.text = "Carte 0/5"
	_card_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_count_label.add_theme_font_override("font", font)
	_card_count_label.add_theme_font_size_override("font_size", FONT_SIZE_HUD)
	_card_count_label.add_theme_color_override("font_color", pal["phosphor_dim"])
	top_hbox.add_child(_card_count_label)

	# Spacer
	var spacer3: Control = Control.new()
	spacer3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer3)

	# Biome currency (right)
	_currency_label = Label.new()
	_currency_label.text = "\u25C6 0"
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_currency_label.add_theme_font_override("font", font)
	_currency_label.add_theme_font_size_override("font_size", FONT_SIZE_HUD)
	_currency_label.add_theme_color_override("font_color", pal["amber"])
	top_hbox.add_child(_currency_label)

	# === CROSSHAIR (center) ===
	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair.add_theme_font_override("font", font)
	_crosshair.add_theme_font_size_override("font_size", 14)
	_crosshair.add_theme_color_override("font_color", pal["phosphor_dim"])
	_root.add_child(_crosshair)

	# === ZONE LABEL (bottom-left) ===
	var bottom_margin: MarginContainer = MarginContainer.new()
	bottom_margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom_margin.add_theme_constant_override("margin_left", MARGIN_H)
	bottom_margin.add_theme_constant_override("margin_bottom", MARGIN_V)
	_root.add_child(bottom_margin)

	_zone_label = Label.new()
	_zone_label.text = ""
	_zone_label.add_theme_font_override("font", font)
	_zone_label.add_theme_font_size_override("font_size", FONT_SIZE_ZONE)
	_zone_label.add_theme_color_override("font_color", pal["phosphor_dim"])
	bottom_margin.add_child(_zone_label)

	# C28 — Gifts chip (bottom-right). Single tiny label, hidden until first gift.
	var gifts_margin: MarginContainer = MarginContainer.new()
	gifts_margin.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	gifts_margin.add_theme_constant_override("margin_right", MARGIN_H)
	gifts_margin.add_theme_constant_override("margin_bottom", MARGIN_V)
	_root.add_child(gifts_margin)
	_gifts_chip = Label.new()
	_gifts_chip.text = ""
	_gifts_chip.visible = false
	_gifts_chip.add_theme_font_override("font", font)
	_gifts_chip.add_theme_font_size_override("font_size", FONT_SIZE_ZONE)
	_gifts_chip.add_theme_color_override("font_color", pal["amber"])
	_gifts_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gifts_margin.add_child(_gifts_chip)

	# C28 — Faction-shift floater layer (top-right, below currency). Children are
	# transient; this is just an anchored container with margin.
	var shift_margin: MarginContainer = MarginContainer.new()
	shift_margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	shift_margin.add_theme_constant_override("margin_right", MARGIN_H)
	shift_margin.add_theme_constant_override("margin_top", MARGIN_V + 22)  # below the currency line
	_root.add_child(shift_margin)
	_shift_layer = Control.new()
	_shift_layer.custom_minimum_size = Vector2(140, 100)
	_shift_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shift_margin.add_child(_shift_layer)
