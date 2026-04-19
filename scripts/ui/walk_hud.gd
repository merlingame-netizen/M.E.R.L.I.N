## ═══════════════════════════════════════════════════════════════════════════════
## WalkHUD — Minimal 3D Walk HUD (Life, Rune, Currency, Cards)
## ═══════════════════════════════════════════════════════════════════════════════
## Overlays the 3D viewport during forest walk gameplay.
## CRT phosphor aesthetic, VT323 monospace font, mobile-responsive.
## ═══════════════════════════════════════════════════════════════════════════════

extends CanvasLayer

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

const MARGIN_H: int = 16
const MARGIN_V: int = 10
const PV_BAR_WIDTH: float = 130.0
const PV_BAR_HEIGHT: float = 8.0
const LOW_LIFE_RATIO: float = 0.25
const WARN_LIFE_RATIO: float = 0.50
const PULSE_DURATION: float = 0.8

# ═══════════════════════════════════════════════════════════════════════════════
# NODES
# ═══════════════════════════════════════════════════════════════════════════════

var _root: Control
var _pv_bar: ProgressBar
var _pv_label: Label
var _currency_label: Label
var _zone_label: Label
var _ogham_label: Label
var _ogham_cd_label: Label
var _card_counter: Label
var _bar_fill_style: StyleBoxFlat

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _show_zone: bool = true
var _cards_played: int = 0
var _pulse_tween: Tween = null
var _life_tween: Tween = null
var _current_life: int = 100


func _ready() -> void:
	layer = 5
	_build_ui()


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func update_pv(current: int, max_pv: int) -> void:
	var prev: int = _current_life
	_current_life = current

	_pv_bar.max_value = max_pv
	_pv_label.text = "PV %d/%d" % [current, max_pv]

	# Animate bar fill
	if _life_tween and _life_tween.is_valid():
		_life_tween.kill()
	_life_tween = create_tween()
	_life_tween.tween_property(_pv_bar, "value", float(current), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	var ratio: float = float(current) / float(max_pv) if max_pv > 0 else 1.0

	if ratio <= LOW_LIFE_RATIO:
		_pv_label.add_theme_color_override("font_color", pal["danger"])
		_bar_fill_style.bg_color = pal["danger"]
		_start_low_life_pulse()
	elif ratio <= WARN_LIFE_RATIO:
		_pv_label.add_theme_color_override("font_color", pal["warning"])
		_bar_fill_style.bg_color = pal["amber_dim"]
		_stop_low_life_pulse()
	else:
		_pv_label.add_theme_color_override("font_color", pal["phosphor"])
		_bar_fill_style.bg_color = pal["phosphor_dim"]
		_stop_low_life_pulse()

	# Flash on damage
	if current < prev:
		var flash: Tween = create_tween()
		flash.tween_property(_pv_label, "modulate", Color(1.5, 0.5, 0.5), 0.1)
		flash.tween_property(_pv_label, "modulate", Color.WHITE, 0.3)


func update_currency(amount: int, _biome_name: String = "") -> void:
	_currency_label.text = "\u25C8 %d" % amount


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
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	if cooldown <= 0:
		_ogham_cd_label.text = "Pret"
		_ogham_cd_label.add_theme_color_override("font_color", pal["cyan"])
	else:
		_ogham_cd_label.text = "CD: %d" % cooldown
		_ogham_cd_label.add_theme_color_override("font_color", pal["phosphor_dim"])


func update_card_count(count: int) -> void:
	_cards_played = count
	_card_counter.text = "Carte #%d" % count
	# Brief flash on new card
	var tw: Tween = create_tween()
	tw.tween_property(_card_counter, "modulate", Color(1.5, 1.5, 1.0), 0.1)
	tw.tween_property(_card_counter, "modulate", Color.WHITE, 0.4)


func toggle_zone_display() -> void:
	_show_zone = not _show_zone
	_zone_label.visible = _show_zone


func fade_for_card() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_root, "modulate:a", 0.3, 0.3)


func restore_from_card() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.3)


# ═══════════════════════════════════════════════════════════════════════════════
# LOW LIFE PULSE
# ═══════════════════════════════════════════════════════════════════════════════

func _start_low_life_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_pv_bar, "modulate:a", 0.5, PULSE_DURATION * 0.5)
	_pulse_tween.tween_property(_pv_bar, "modulate:a", 1.0, PULSE_DURATION * 0.5)


func _stop_low_life_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	_pv_bar.modulate.a = 1.0


# ═══════════════════════════════════════════════════════════════════════════════
# BUILD UI
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	var fs_main: int = 14
	var fs_small: int = 11
	var fs_ogham: int = 15

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Safe area margins (mobile notch/cutout awareness)
	var safe_top: int = MARGIN_V
	var safe_left: int = MARGIN_H
	var safe_right: int = MARGIN_H
	var safe_bottom: int = MARGIN_V
	var mr: Node = Engine.get_main_loop().root.get_node_or_null("MerlinResponsive") if Engine.get_main_loop() else null
	if mr and mr.has_method("get_safe_margin_top"):
		safe_top = maxi(MARGIN_V, int(mr.get_safe_margin_top()))
		safe_bottom = maxi(MARGIN_V, int(mr.get_safe_margin_bottom()))

	# ═══ TOP BAR ═══
	var top_bg: PanelContainer = PanelContainer.new()
	top_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var top_style: StyleBoxFlat = StyleBoxFlat.new()
	top_style.bg_color = Color(pal["bg_deep"].r, pal["bg_deep"].g, pal["bg_deep"].b, 0.65)
	top_style.content_margin_left = safe_left
	top_style.content_margin_right = safe_right
	top_style.content_margin_top = safe_top
	top_style.content_margin_bottom = 6
	top_style.border_width_bottom = 1
	top_style.border_color = Color(pal["border"].r, pal["border"].g, pal["border"].b, 0.4)
	top_bg.add_theme_stylebox_override("panel", top_style)
	_root.add_child(top_bg)

	var top_hbox: HBoxContainer = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 16)
	top_bg.add_child(top_hbox)

	# PV section (left)
	var pv_hbox: HBoxContainer = HBoxContainer.new()
	pv_hbox.add_theme_constant_override("separation", 8)
	top_hbox.add_child(pv_hbox)

	_pv_label = Label.new()
	_pv_label.text = "PV 100/100"
	MerlinVisual.apply_responsive_font(_pv_label, fs_main, "terminal")
	_pv_label.add_theme_color_override("font_color", pal["phosphor"])
	pv_hbox.add_child(_pv_label)

	_pv_bar = ProgressBar.new()
	_pv_bar.custom_minimum_size = Vector2(PV_BAR_WIDTH, PV_BAR_HEIGHT)
	_pv_bar.max_value = 100
	_pv_bar.value = 100
	_pv_bar.show_percentage = false
	_pv_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = pal["bg_dark"]
	bar_bg.border_color = Color(pal["border"].r, pal["border"].g, pal["border"].b, 0.5)
	bar_bg.set_border_width_all(1)
	bar_bg.set_corner_radius_all(0)
	_pv_bar.add_theme_stylebox_override("background", bar_bg)

	_bar_fill_style = StyleBoxFlat.new()
	_bar_fill_style.bg_color = pal["phosphor_dim"]
	_bar_fill_style.set_corner_radius_all(0)
	_pv_bar.add_theme_stylebox_override("fill", _bar_fill_style)
	pv_hbox.add_child(_pv_bar)

	# Spacer
	var spacer1: Control = Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer1)

	# Ogham actif (center-right)
	var ogham_hbox: HBoxContainer = HBoxContainer.new()
	ogham_hbox.add_theme_constant_override("separation", 6)
	top_hbox.add_child(ogham_hbox)

	_ogham_label = Label.new()
	_ogham_label.text = "\u25C6 Beith"
	MerlinVisual.apply_responsive_font(_ogham_label, fs_ogham, "terminal")
	_ogham_label.add_theme_color_override("font_color", pal["cyan"])
	ogham_hbox.add_child(_ogham_label)

	_ogham_cd_label = Label.new()
	_ogham_cd_label.text = "Pret"
	MerlinVisual.apply_responsive_font(_ogham_cd_label, fs_small, "terminal")
	_ogham_cd_label.add_theme_color_override("font_color", pal["cyan"])
	_ogham_cd_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ogham_hbox.add_child(_ogham_cd_label)

	# ═══ BOTTOM BAR ═══
	var bot_bg: PanelContainer = PanelContainer.new()
	bot_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	var bot_style: StyleBoxFlat = StyleBoxFlat.new()
	bot_style.bg_color = Color(pal["bg_deep"].r, pal["bg_deep"].g, pal["bg_deep"].b, 0.55)
	bot_style.content_margin_left = safe_left
	bot_style.content_margin_right = safe_right
	bot_style.content_margin_top = 6
	bot_style.content_margin_bottom = safe_bottom
	bot_style.border_width_top = 1
	bot_style.border_color = Color(pal["border"].r, pal["border"].g, pal["border"].b, 0.3)
	bot_bg.add_theme_stylebox_override("panel", bot_style)
	_root.add_child(bot_bg)

	var bot_hbox: HBoxContainer = HBoxContainer.new()
	bot_hbox.add_theme_constant_override("separation", 20)
	bot_bg.add_child(bot_hbox)

	# Card counter (left)
	_card_counter = Label.new()
	_card_counter.text = "Carte #0"
	MerlinVisual.apply_responsive_font(_card_counter, fs_main, "terminal")
	_card_counter.add_theme_color_override("font_color", pal["phosphor_dim"])
	bot_hbox.add_child(_card_counter)

	# Zone label (center)
	_zone_label = Label.new()
	_zone_label.text = ""
	_zone_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MerlinVisual.apply_responsive_font(_zone_label, fs_small, "terminal")
	_zone_label.add_theme_color_override("font_color", pal["phosphor_dim"])
	bot_hbox.add_child(_zone_label)

	# Biome currency (right)
	_currency_label = Label.new()
	_currency_label.text = "\u25C8 0"
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	MerlinVisual.apply_responsive_font(_currency_label, fs_main, "terminal")
	_currency_label.add_theme_color_override("font_color", pal["amber"])
	bot_hbox.add_child(_currency_label)
