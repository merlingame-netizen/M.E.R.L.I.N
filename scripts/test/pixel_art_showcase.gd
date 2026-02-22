## PixelArtShowcase — Preview scene for all pixel art assets
## Displays portraits, ogham icons, shader controls, animations

extends Control

const PORTRAIT_SIZE := 96.0
const ICON_SIZE := 48.0
const SECTION_MARGIN := 20.0
const H_GAP := 12.0
const V_GAP := 8.0

var _dither_layer: ScreenDitherLayer
var _portraits: Array[PixelNpcPortrait] = []
var _ogham_icons: Array[PixelOghamIcon] = []


func _ready() -> void:
	_build_background()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", int(V_GAP))
	scroll.add_child(vbox)

	_add_title(vbox)
	_add_portraits_section(vbox)
	_add_ogham_section(vbox)
	_add_shader_controls(vbox)
	_add_animation_controls(vbox)

	# Global dither post-process
	_dither_layer = ScreenDitherLayer.new()
	add_child(_dither_layer)

	# Trigger assembly animations after a short delay
	await get_tree().create_timer(0.3).timeout
	for p: PixelNpcPortrait in _portraits:
		p.assemble(false)
		await get_tree().create_timer(0.08).timeout
	for icon: PixelOghamIcon in _ogham_icons:
		icon.reveal(false)


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = MerlinVisual.PALETTE.get("bg_mid", Color("#2a1f14"))
	add_child(bg)


func _add_title(parent: Control) -> void:
	var label := _make_label("M.E.R.L.I.N. — Pixel Art Showcase", 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", MerlinVisual.PALETTE.get("ink_gold", Color("#c49256")))
	parent.add_child(label)


# ═══════════════════════════════════════════════════════════════════════════════
# PORTRAITS SECTION
# ═══════════════════════════════════════════════════════════════════════════════

func _add_portraits_section(parent: Control) -> void:
	parent.add_child(_make_section_label("Portraits PNJ — 32x32 (8 archetypes)"))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(H_GAP))
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(hbox)

	var npc_keys: PackedStringArray = PixelNpcPortrait.get_available_npcs()
	for key: String in npc_keys:
		var container := VBoxContainer.new()
		container.alignment = BoxContainer.ALIGNMENT_CENTER

		var portrait := PixelNpcPortrait.new()
		portrait.setup(key, PORTRAIT_SIZE)
		container.add_child(portrait)

		var name_label := _make_label(PixelNpcPortrait.get_npc_display_name(key), 11)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", MerlinVisual.PALETTE.get("ink_warm", Color("#c0b8ad")))
		container.add_child(name_label)

		hbox.add_child(container)
		_portraits.append(portrait)


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM ICONS SECTION
# ═══════════════════════════════════════════════════════════════════════════════

func _add_ogham_section(parent: Control) -> void:
	parent.add_child(_make_section_label("Runes Ogham — 16x16 (18 runes, 6 categories)"))

	var categories := ["reveal", "protection", "boost", "narrative", "recovery", "special"]
	var category_labels := {
		"reveal": "Revelation", "protection": "Protection", "boost": "Force",
		"narrative": "Recit", "recovery": "Guerison", "special": "Secret",
	}

	for cat: String in categories:
		var row_container := HBoxContainer.new()
		row_container.add_theme_constant_override("separation", int(H_GAP))

		var cat_label := _make_label(category_labels.get(cat, cat), 12)
		cat_label.custom_minimum_size.x = 100
		cat_label.add_theme_color_override("font_color", _get_category_color(cat))
		row_container.add_child(cat_label)

		# Find oghams in this category
		for ogham_key: String in PixelOghamIcon.OGHAM_CATEGORY:
			if PixelOghamIcon.OGHAM_CATEGORY[ogham_key] != cat:
				continue
			var icon_container := VBoxContainer.new()
			icon_container.alignment = BoxContainer.ALIGNMENT_CENTER

			var icon := PixelOghamIcon.new()
			icon.setup(ogham_key, ICON_SIZE)
			icon_container.add_child(icon)

			var icon_label := _make_label(ogham_key, 9)
			icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_label.add_theme_color_override("font_color", MerlinVisual.PALETTE.get("ink_warm", Color("#a88d7b")))
			icon_container.add_child(icon_label)

			row_container.add_child(icon_container)
			_ogham_icons.append(icon)

		parent.add_child(row_container)


# ═══════════════════════════════════════════════════════════════════════════════
# SHADER CONTROLS
# ═══════════════════════════════════════════════════════════════════════════════

func _add_shader_controls(parent: Control) -> void:
	parent.add_child(_make_section_label("Post-Process Dither (Global)"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)

	_add_slider(grid, "Dither ON/OFF", 0.0, 1.0, 1.0, func(v: float) -> void: _dither_layer.set_enabled(v > 0.5))
	_add_slider(grid, "Strength", 0.0, 1.0, 0.4, func(v: float) -> void: _dither_layer.set_dither_strength(v))
	_add_slider(grid, "Color Levels", 2.0, 32.0, 8.0, func(v: float) -> void: _dither_layer.set_color_levels(v))
	_add_slider(grid, "Tint Blend", 0.0, 1.0, 0.12, func(v: float) -> void: _dither_layer.set_tint_blend(v))
	_add_slider(grid, "Pixel Scale", 1.0, 8.0, 1.0, func(v: float) -> void: _dither_layer.set_pixel_scale(v))
	_add_slider(grid, "Intensity", 0.0, 1.0, 1.0, func(v: float) -> void: _dither_layer.set_intensity(v))


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATION CONTROLS
# ═══════════════════════════════════════════════════════════════════════════════

func _add_animation_controls(parent: Control) -> void:
	parent.add_child(_make_section_label("Animations"))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var btn_assemble := _make_button("Assemble All")
	btn_assemble.pressed.connect(func() -> void:
		for p: PixelNpcPortrait in _portraits:
			p.assemble(false)
	)
	hbox.add_child(btn_assemble)

	var btn_disassemble := _make_button("Disassemble All")
	btn_disassemble.pressed.connect(func() -> void:
		for p: PixelNpcPortrait in _portraits:
			p.disassemble()
	)
	hbox.add_child(btn_disassemble)

	var btn_pulse := _make_button("Pulse Oghams")
	btn_pulse.pressed.connect(func() -> void:
		for icon: PixelOghamIcon in _ogham_icons:
			icon.set_active(not icon._active)
	)
	hbox.add_child(btn_pulse)

	var btn_reveal := _make_button("Reveal Oghams")
	btn_reveal.pressed.connect(func() -> void:
		for icon: PixelOghamIcon in _ogham_icons:
			icon.reveal(false)
	)
	hbox.add_child(btn_reveal)

	# Spacer at bottom
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40.0
	parent.add_child(spacer)


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_section_label(text: String) -> Label:
	var label := _make_label("— " + text + " —", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", MerlinVisual.PALETTE.get("ink_gold", Color("#c49256")))
	var margin := label.custom_minimum_size
	margin.y = 32.0
	label.custom_minimum_size = margin
	return label


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 12)
	return btn


func _add_slider(parent: Control, label_text: String, min_val: float, max_val: float, default_val: float, callback: Callable) -> void:
	var label := _make_label(label_text, 12)
	label.add_theme_color_override("font_color", MerlinVisual.PALETTE.get("ink_warm", Color("#c0b8ad")))
	parent.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.step = 0.01 if max_val <= 1.0 else 1.0
	slider.custom_minimum_size.x = 200
	slider.value_changed.connect(callback)
	parent.add_child(slider)


func _get_category_color(category: String) -> Color:
	var cat_colors := {
		"reveal": Color(0.596, 0.667, 0.847),
		"protection": Color(0.361, 0.580, 0.486),
		"boost": Color(0.769, 0.573, 0.337),
		"narrative": Color(0.298, 0.267, 0.318),
		"recovery": Color(0.541, 0.612, 0.420),
		"special": Color(0.580, 0.290, 0.259),
	}
	return cat_colors.get(category, Color.WHITE)
