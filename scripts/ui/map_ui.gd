## =============================================================================
## Map UI — Geographic World Map with 7 Celtic Biomes
## =============================================================================
## Displays the 7 biomes of Brittany as an interactive geographic map.
## Each biome has a positioned marker, lock system, animations, and details.
## Only foret_broceliande is unlocked by default.
## =============================================================================

extends Control
class_name MapUI

signal node_selected(biome_key: String)
signal close_requested

# === PALETTE ===
const PALETTE := {
	"paper": Color(0.965, 0.945, 0.905),
	"paper_dark": Color(0.935, 0.905, 0.855),
	"paper_warm": Color(0.955, 0.930, 0.890),
	"ink": Color(0.22, 0.18, 0.14),
	"ink_soft": Color(0.38, 0.32, 0.26),
	"ink_faded": Color(0.50, 0.44, 0.38, 0.35),
	"accent": Color(0.58, 0.44, 0.26),
	"accent_soft": Color(0.65, 0.52, 0.34),
	"accent_glow": Color(0.72, 0.58, 0.38, 0.25),
	"shadow": Color(0.25, 0.20, 0.16, 0.18),
	"mist": Color(0.94, 0.92, 0.88, 0.35),
	"locked": Color(0.45, 0.42, 0.38, 0.5),
	"unlocked_glow": Color(0.85, 0.70, 0.35, 0.6),
}

# === 7 BIOMES — Geographic positions (proportional 0-1) ===
# Inspired by real Brittany geography
const BIOME_MAP_POSITIONS := {
	"foret_broceliande": Vector2(0.55, 0.45),   # Center — Paimpont forest
	"landes_bruyere": Vector2(0.40, 0.25),       # North-center — Monts d'Arree
	"cotes_sauvages": Vector2(0.20, 0.35),       # West coast — Pointe du Raz
	"villages_celtes": Vector2(0.70, 0.65),       # Southeast — inland villages
	"cercles_pierres": Vector2(0.35, 0.60),       # South — Carnac area
	"marais_korrigans": Vector2(0.50, 0.72),      # South-center — Grande Briere
	"collines_dolmens": Vector2(0.75, 0.30),      # Northeast — hills
}

# Biome visual data (colors, icons, names)
const BIOME_VISUALS := {
	"foret_broceliande": {
		"name": "Foret de Broceliande",
		"subtitle": "Ou les arbres ont des yeux",
		"symbol": "\u2663",  # Club/tree
		"color": Color(0.30, 0.50, 0.28),
		"color_glow": Color(0.40, 0.65, 0.35, 0.4),
		"difficulty": "Normal",
		"guardian": "Maelgwn",
	},
	"landes_bruyere": {
		"name": "Landes de Bruyere",
		"subtitle": "L'horizon sans fin",
		"symbol": "\u2736",  # Six-pointed star
		"color": Color(0.55, 0.40, 0.55),
		"color_glow": Color(0.65, 0.50, 0.65, 0.4),
		"difficulty": "Difficile",
		"guardian": "Talwen",
	},
	"cotes_sauvages": {
		"name": "Cotes Sauvages",
		"subtitle": "L'ocean murmurant",
		"symbol": "\u223C",  # Wave
		"color": Color(0.35, 0.50, 0.65),
		"color_glow": Color(0.45, 0.60, 0.75, 0.4),
		"difficulty": "Normal",
		"guardian": "Bran",
	},
	"villages_celtes": {
		"name": "Villages Celtes",
		"subtitle": "Flammes obstinees de l'humanite",
		"symbol": "\u2302",  # House
		"color": Color(0.60, 0.45, 0.30),
		"color_glow": Color(0.70, 0.55, 0.40, 0.4),
		"difficulty": "Facile",
		"guardian": "Azenor",
	},
	"cercles_pierres": {
		"name": "Cercles de Pierres",
		"subtitle": "Ou le temps hesite",
		"symbol": "\u25CE",  # Bullseye
		"color": Color(0.50, 0.50, 0.55),
		"color_glow": Color(0.60, 0.60, 0.70, 0.4),
		"difficulty": "Difficile",
		"guardian": "Keridwen",
	},
	"marais_korrigans": {
		"name": "Marais des Korrigans",
		"subtitle": "Deception et feux follets",
		"symbol": "\u2735",  # Star
		"color": Color(0.30, 0.42, 0.30),
		"color_glow": Color(0.40, 0.55, 0.40, 0.4),
		"difficulty": "Tres difficile",
		"guardian": "Gwydion",
	},
	"collines_dolmens": {
		"name": "Collines aux Dolmens",
		"subtitle": "Les os de la terre",
		"symbol": "\u25B2",  # Triangle
		"color": Color(0.48, 0.55, 0.40),
		"color_glow": Color(0.58, 0.65, 0.50, 0.4),
		"difficulty": "Normal",
		"guardian": "Elouan",
	},
}

# Path connections between biomes (for map lines)
const BIOME_CONNECTIONS := [
	["foret_broceliande", "landes_bruyere"],
	["foret_broceliande", "cotes_sauvages"],
	["foret_broceliande", "villages_celtes"],
	["foret_broceliande", "cercles_pierres"],
	["foret_broceliande", "marais_korrigans"],
	["landes_bruyere", "cotes_sauvages"],
	["landes_bruyere", "collines_dolmens"],
	["cotes_sauvages", "cercles_pierres"],
	["villages_celtes", "collines_dolmens"],
	["villages_celtes", "marais_korrigans"],
	["cercles_pierres", "marais_korrigans"],
]

# === LAYOUT ===
const MARKER_RADIUS := 32.0
const MAP_MARGIN := 40.0

# === STATE ===
var _biome_buttons: Dictionary = {}   # biome_key -> Button
var _biome_glow_rects: Dictionary = {}  # biome_key -> ColorRect (glow)
var _biome_lock_icons: Dictionary = {}  # biome_key -> Label (lock)
var _selected_biome: String = ""
var _unlocked_biomes: Dictionary = {}  # biome_key -> bool
var _detail_label: Label
var _paths_layer: Control
var _markers_layer: Control
var _particles_layer: Control
var _title_label: Label
var back_button: Button
var _selected_pulse_tween: Tween
var _biome_system: MerlinBiomeSystem

# Fonts
var _title_font: Font
var _body_font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_fonts()
	_biome_system = MerlinBiomeSystem.new()
	_compute_unlock_states()
	_build_ui()
	# Animate map reveal after a frame
	await get_tree().process_frame
	_animate_reveal()


func _load_fonts() -> void:
	_title_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlack.otf")
	if _title_font == null:
		_title_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlack.ttf")
	_body_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.otf")
	if _body_font == null:
		_body_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf")
	if _body_font == null:
		_body_font = _title_font


func _try_load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var f: Resource = load(path)
	if f is Font:
		return f
	return null


func _compute_unlock_states() -> void:
	## Determine which biomes are unlocked based on meta-progression.
	var store := get_node_or_null("/root/MerlinStore")
	var meta: Dictionary = {}
	if store:
		meta = store.state.get("meta", {})

	for biome_key in BIOME_MAP_POSITIONS:
		_unlocked_biomes[biome_key] = _biome_system.is_unlocked(biome_key, meta)


func _build_ui() -> void:
	# Parchment background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var paper_shader := load("res://shaders/reigns_paper.gdshader")
	if paper_shader:
		var mat := ShaderMaterial.new()
		mat.shader = paper_shader
		mat.set_shader_parameter("paper_tint", PALETTE.paper)
		mat.set_shader_parameter("grain_strength", 0.03)
		mat.set_shader_parameter("vignette_strength", 0.12)
		mat.set_shader_parameter("vignette_softness", 0.6)
		mat.set_shader_parameter("grain_scale", 1200.0)
		mat.set_shader_parameter("grain_speed", 0.06)
		mat.set_shader_parameter("warp_strength", 0.001)
		bg.material = mat
	else:
		bg.color = PALETTE.paper
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Mist overlay
	var mist := ColorRect.new()
	mist.set_anchors_preset(Control.PRESET_FULL_RECT)
	mist.color = PALETTE.mist
	mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mist)

	# Title
	_title_label = Label.new()
	_title_label.text = "Carte de Bretagne"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_top = 16
	_title_label.offset_bottom = 52
	if _title_font:
		_title_label.add_theme_font_override("font", _title_font)
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", PALETTE.ink)
	add_child(_title_label)

	# Subtitle ornament
	var orn := Label.new()
	orn.text = "\u2500\u2500 \u25C6 Les 7 Sanctuaires \u25C6 \u2500\u2500"
	orn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orn.set_anchors_preset(Control.PRESET_TOP_WIDE)
	orn.offset_top = 48
	orn.offset_bottom = 68
	orn.add_theme_font_size_override("font_size", 13)
	orn.add_theme_color_override("font_color", PALETTE.accent)
	add_child(orn)

	# Particles layer (behind markers)
	_particles_layer = Control.new()
	_particles_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_particles_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_particles_layer)

	# Path lines layer
	_paths_layer = Control.new()
	_paths_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paths_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paths_layer.draw.connect(_draw_paths)
	add_child(_paths_layer)

	# Markers layer
	_markers_layer = Control.new()
	_markers_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_markers_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_markers_layer)

	# Create biome markers
	for biome_key in BIOME_MAP_POSITIONS:
		_create_biome_marker(biome_key)

	# Detail label at bottom
	_detail_label = Label.new()
	_detail_label.text = "Selectionne un sanctuaire pour partir a l'aventure"
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_detail_label.offset_top = -80
	_detail_label.offset_bottom = -50
	_detail_label.offset_left = MAP_MARGIN
	_detail_label.offset_right = -MAP_MARGIN
	if _body_font:
		_detail_label.add_theme_font_override("font", _body_font)
	_detail_label.add_theme_font_size_override("font_size", 15)
	_detail_label.add_theme_color_override("font_color", PALETTE.ink)
	add_child(_detail_label)

	# Back button
	back_button = Button.new()
	back_button.text = "\u25C0 Retour"
	back_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back_button.offset_left = 16
	back_button.offset_top = -44
	back_button.offset_right = 120
	back_button.offset_bottom = -8
	if _body_font:
		back_button.add_theme_font_override("font", _body_font)
	back_button.add_theme_font_size_override("font_size", 15)
	back_button.add_theme_color_override("font_color", PALETTE.accent)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = PALETTE.paper_dark
	btn_style.border_color = PALETTE.accent_soft
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(6)
	back_button.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = PALETTE.paper_warm
	back_button.add_theme_stylebox_override("hover", btn_hover)
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)

	# Layout after a frame so sizes are computed
	_layout_map.call_deferred()
	resized.connect(_layout_map)


func _create_biome_marker(biome_key: String) -> void:
	var vis: Dictionary = BIOME_VISUALS.get(biome_key, {})
	var unlocked: bool = _unlocked_biomes.get(biome_key, false)
	var biome_color: Color = vis.get("color", Color.GRAY)

	# Glow circle behind marker (pulsing for unlocked)
	var glow := ColorRect.new()
	glow.custom_minimum_size = Vector2(MARKER_RADIUS * 2.4, MARKER_RADIUS * 2.4)
	glow.size = glow.custom_minimum_size
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate.a = 0.0  # Hidden initially for reveal animation
	var glow_color: Color = vis.get("color_glow", Color(0.5, 0.5, 0.5, 0.3))
	if not unlocked:
		glow_color = Color(0.3, 0.3, 0.3, 0.15)
	glow.color = glow_color
	_particles_layer.add_child(glow)
	_biome_glow_rects[biome_key] = glow

	# Marker button
	var btn := Button.new()
	var symbol: String = vis.get("symbol", "\u25CF")
	var biome_name: String = vis.get("name", biome_key)
	btn.custom_minimum_size = Vector2(MARKER_RADIUS * 2.2, MARKER_RADIUS * 2.4)
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_text = false
	btn.modulate.a = 0.0  # Hidden for reveal
	btn.pivot_offset = btn.custom_minimum_size * 0.5

	if unlocked:
		btn.text = symbol + "\n" + biome_name
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		btn.text = "\u2612\n" + biome_name
		btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
		btn.disabled = true

	if _body_font:
		btn.add_theme_font_override("font", _body_font)
	btn.add_theme_font_size_override("font_size", 11)

	# Style
	var style := StyleBoxFlat.new()
	if unlocked:
		style.bg_color = Color(biome_color.r, biome_color.g, biome_color.b, 0.85)
		style.border_color = Color(biome_color.r * 1.3, biome_color.g * 1.3, biome_color.b * 1.3, 0.9)
	else:
		style.bg_color = PALETTE.locked
		style.border_color = Color(0.35, 0.32, 0.28, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(4)
	style.shadow_color = PALETTE.shadow
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	btn.add_theme_stylebox_override("normal", style)

	# Hover style
	var hover := style.duplicate()
	if unlocked:
		hover.bg_color = Color(biome_color.r * 1.2, biome_color.g * 1.2, biome_color.b * 1.2, 0.95)
		hover.set_border_width_all(3)
	btn.add_theme_stylebox_override("hover", hover)

	# Disabled style
	var disabled := style.duplicate()
	disabled.bg_color = Color(0.35, 0.33, 0.30, 0.6)
	btn.add_theme_stylebox_override("disabled", disabled)

	# Font colors
	if unlocked:
		btn.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.88))
	else:
		btn.add_theme_color_override("font_color", Color(0.55, 0.50, 0.45))
		btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.50, 0.45))

	# Signals
	if unlocked:
		btn.pressed.connect(_on_biome_pressed.bind(biome_key))
		btn.mouse_entered.connect(_on_biome_hover.bind(biome_key))
		btn.mouse_exited.connect(_on_biome_unhover.bind(biome_key))

	_markers_layer.add_child(btn)
	_biome_buttons[biome_key] = btn

	# Lock icon overlay for locked biomes
	if not unlocked:
		var lock_lbl := Label.new()
		lock_lbl.text = "\u2612"
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.add_theme_font_size_override("font_size", 18)
		lock_lbl.add_theme_color_override("font_color", Color(0.6, 0.55, 0.48))
		lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_markers_layer.add_child(lock_lbl)
		_biome_lock_icons[biome_key] = lock_lbl

		# Unlock hint tooltip
		var hint: String = _biome_system.get_unlock_hint(biome_key)
		if hint != "":
			btn.tooltip_text = hint


func _layout_map() -> void:
	## Position all biome markers and glow rects based on current viewport size.
	var map_rect := get_rect()
	var map_w: float = map_rect.size.x
	var map_h: float = map_rect.size.y
	var usable_top := 75.0
	var usable_bottom := 85.0
	var usable_h: float = map_h - usable_top - usable_bottom

	for biome_key in BIOME_MAP_POSITIONS:
		var prop: Vector2 = BIOME_MAP_POSITIONS[biome_key]
		var center := Vector2(
			MAP_MARGIN + (map_w - MAP_MARGIN * 2.0) * prop.x,
			usable_top + usable_h * prop.y
		)

		# Position marker button
		if _biome_buttons.has(biome_key):
			var btn: Button = _biome_buttons[biome_key]
			btn.position = center - btn.custom_minimum_size * 0.5

		# Position glow
		if _biome_glow_rects.has(biome_key):
			var glow: ColorRect = _biome_glow_rects[biome_key]
			glow.position = center - glow.custom_minimum_size * 0.5

		# Position lock icon
		if _biome_lock_icons.has(biome_key):
			var lock_lbl: Label = _biome_lock_icons[biome_key]
			lock_lbl.position = center + Vector2(-10, -38)

	# Redraw path lines
	_paths_layer.queue_redraw()


func _draw_paths() -> void:
	## Draw connection lines between biomes.
	var map_rect := get_rect()
	var map_w: float = map_rect.size.x
	var map_h: float = map_rect.size.y
	var usable_top := 75.0
	var usable_bottom := 85.0
	var usable_h: float = map_h - usable_top - usable_bottom

	for conn in BIOME_CONNECTIONS:
		var key_a: String = conn[0]
		var key_b: String = conn[1]
		var prop_a: Vector2 = BIOME_MAP_POSITIONS.get(key_a, Vector2.ZERO)
		var prop_b: Vector2 = BIOME_MAP_POSITIONS.get(key_b, Vector2.ZERO)

		var center_a := Vector2(
			MAP_MARGIN + (map_w - MAP_MARGIN * 2.0) * prop_a.x,
			usable_top + usable_h * prop_a.y
		)
		var center_b := Vector2(
			MAP_MARGIN + (map_w - MAP_MARGIN * 2.0) * prop_b.x,
			usable_top + usable_h * prop_b.y
		)

		var both_unlocked: bool = _unlocked_biomes.get(key_a, false) and _unlocked_biomes.get(key_b, false)
		var one_unlocked: bool = _unlocked_biomes.get(key_a, false) or _unlocked_biomes.get(key_b, false)
		var is_active: bool = _selected_biome in conn

		var color: Color
		var width: float
		if is_active and both_unlocked:
			color = Color(PALETTE.accent.r, PALETTE.accent.g, PALETTE.accent.b, 0.6)
			width = 2.5
		elif both_unlocked:
			color = Color(PALETTE.ink_soft.r, PALETTE.ink_soft.g, PALETTE.ink_soft.b, 0.3)
			width = 1.5
		elif one_unlocked:
			color = Color(PALETTE.ink_faded.r, PALETTE.ink_faded.g, PALETTE.ink_faded.b, 0.2)
			width = 1.0
		else:
			color = Color(PALETTE.ink_faded.r, PALETTE.ink_faded.g, PALETTE.ink_faded.b, 0.1)
			width = 0.8

		# Draw dotted line for locked connections, solid for unlocked
		if both_unlocked:
			_paths_layer.draw_line(center_a, center_b, color, width, true)
		else:
			_draw_dashed_line(center_a, center_b, color, width)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	## Draw a dashed line between two points.
	var dir := (to - from)
	var length := dir.length()
	if length < 1.0:
		return
	dir = dir.normalized()
	var dash_len := 8.0
	var gap_len := 6.0
	var pos := 0.0
	while pos < length:
		var end_pos := minf(pos + dash_len, length)
		_paths_layer.draw_line(from + dir * pos, from + dir * end_pos, color, width, true)
		pos = end_pos + gap_len


# =============================================================================
# BIOME INTERACTION
# =============================================================================

func _on_biome_pressed(biome_key: String) -> void:
	SFXManager.play("click")
	_selected_biome = biome_key
	_update_selection_visuals()
	node_selected.emit(biome_key)


func _on_biome_hover(biome_key: String) -> void:
	SFXManager.play_varied("hover", 0.05)
	var vis: Dictionary = BIOME_VISUALS.get(biome_key, {})
	var biome_name: String = vis.get("name", biome_key)
	var subtitle: String = vis.get("subtitle", "")
	var difficulty: String = vis.get("difficulty", "Normal")
	var guardian: String = vis.get("guardian", "?")
	_detail_label.text = "%s — %s | Gardien: %s | Difficulte: %s" % [biome_name, subtitle, guardian, difficulty]

	# Scale up on hover
	if _biome_buttons.has(biome_key):
		var btn: Button = _biome_buttons[biome_key]
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Brighten glow
	if _biome_glow_rects.has(biome_key):
		var glow: ColorRect = _biome_glow_rects[biome_key]
		var tw := create_tween()
		tw.tween_property(glow, "modulate:a", 1.0, 0.2)


func _on_biome_unhover(biome_key: String) -> void:
	if _selected_biome == "":
		_detail_label.text = "Selectionne un sanctuaire pour partir a l'aventure"
	elif _selected_biome != biome_key:
		# Restore selected biome detail
		_show_selected_detail()

	# Scale back
	if _biome_buttons.has(biome_key):
		var btn: Button = _biome_buttons[biome_key]
		var target_scale := Vector2(1.06, 1.06) if biome_key == _selected_biome else Vector2(1.0, 1.0)
		var tw := create_tween()
		tw.tween_property(btn, "scale", target_scale, 0.15)

	# Dim glow (unless selected)
	if _biome_glow_rects.has(biome_key) and biome_key != _selected_biome:
		var glow: ColorRect = _biome_glow_rects[biome_key]
		var tw := create_tween()
		tw.tween_property(glow, "modulate:a", 0.5, 0.2)


func _show_selected_detail() -> void:
	var vis: Dictionary = BIOME_VISUALS.get(_selected_biome, {})
	var biome_name: String = vis.get("name", _selected_biome)
	var subtitle: String = vis.get("subtitle", "")
	var difficulty: String = vis.get("difficulty", "Normal")
	var guardian: String = vis.get("guardian", "?")
	_detail_label.text = "\u25C6 %s — %s | Gardien: %s | Difficulte: %s" % [biome_name, subtitle, guardian, difficulty]


func _update_selection_visuals() -> void:
	## Update visual state of all biome markers based on selection.
	# Kill previous pulse
	if _selected_pulse_tween:
		_selected_pulse_tween.kill()
		_selected_pulse_tween = null

	for biome_key in _biome_buttons:
		var btn: Button = _biome_buttons[biome_key]
		var unlocked: bool = _unlocked_biomes.get(biome_key, false)
		var vis: Dictionary = BIOME_VISUALS.get(biome_key, {})
		var biome_color: Color = vis.get("color", Color.GRAY)

		if biome_key == _selected_biome:
			# Selected: bright border + pulse
			var style := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
			style.border_color = PALETTE.unlocked_glow
			style.set_border_width_all(3)
			btn.add_theme_stylebox_override("normal", style)

			_selected_pulse_tween = create_tween().set_loops()
			_selected_pulse_tween.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_selected_pulse_tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

			# Bright glow
			if _biome_glow_rects.has(biome_key):
				var tw := create_tween()
				tw.tween_property(_biome_glow_rects[biome_key], "modulate:a", 1.0, 0.3)

		elif unlocked:
			# Unselected unlocked: normal style
			var style := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
			style.border_color = Color(biome_color.r * 1.3, biome_color.g * 1.3, biome_color.b * 1.3, 0.9)
			style.set_border_width_all(2)
			btn.add_theme_stylebox_override("normal", style)
			btn.scale = Vector2(1.0, 1.0)

			if _biome_glow_rects.has(biome_key):
				var tw := create_tween()
				tw.tween_property(_biome_glow_rects[biome_key], "modulate:a", 0.5, 0.3)

	# Update detail text
	if _selected_biome != "":
		_show_selected_detail()

	# Redraw paths (highlight active connections)
	_paths_layer.queue_redraw()


func _on_back_pressed() -> void:
	SFXManager.play("click")
	close_requested.emit()
	# Fallback scene navigation
	if get_parent() is ColorRect and get_parent().name.contains("Overlay"):
		return
	var se := get_node_or_null("/root/ScreenEffects")
	var target: String = "res://scenes/HubAntre.tscn"
	if se and str(se.get("return_scene")) != "":
		target = str(se.return_scene)
	get_tree().change_scene_to_file(target)


# =============================================================================
# MAP REVEAL ANIMATION
# =============================================================================

func _animate_reveal() -> void:
	## Animate biome markers appearing with stagger + floating particles.
	if not is_inside_tree():
		return

	# Collect biome keys in display order (Broceliande first, then outward)
	var reveal_order: Array = [
		"foret_broceliande",
		"landes_bruyere", "cotes_sauvages",
		"villages_celtes", "cercles_pierres",
		"marais_korrigans", "collines_dolmens",
	]

	for i in range(reveal_order.size()):
		var biome_key: String = reveal_order[i]
		if not is_inside_tree():
			return

		# Reveal glow
		if _biome_glow_rects.has(biome_key):
			var glow: ColorRect = _biome_glow_rects[biome_key]
			var tw := create_tween()
			tw.tween_property(glow, "modulate:a", 0.5, 0.4).set_trans(Tween.TRANS_SINE)

		# Reveal marker with pop
		if _biome_buttons.has(biome_key):
			var btn: Button = _biome_buttons[biome_key]
			btn.scale = Vector2(0.3, 0.3)
			var tw := create_tween()
			tw.tween_property(btn, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		SFXManager.play_varied("landmark_pop", 0.08)
		await get_tree().create_timer(0.12).timeout

	if not is_inside_tree():
		return

	# Start floating particle effects for unlocked biomes
	_start_ambient_particles()


func _start_ambient_particles() -> void:
	## Spawn floating Celtic particles around unlocked biomes.
	for biome_key in BIOME_MAP_POSITIONS:
		if not _unlocked_biomes.get(biome_key, false):
			continue
		_spawn_biome_particle(biome_key)


func _spawn_biome_particle(biome_key: String) -> void:
	## Create a single floating particle near a biome marker.
	if not is_inside_tree():
		return
	if not _biome_buttons.has(biome_key):
		return

	var btn: Button = _biome_buttons[biome_key]
	var center := btn.position + btn.custom_minimum_size * 0.5
	var vis: Dictionary = BIOME_VISUALS.get(biome_key, {})
	var biome_color: Color = vis.get("color", Color.GRAY)

	var symbols := ["\u2022", "\u2736", "\u2726", "\u25CF", "\u2022"]
	var particle := Label.new()
	particle.text = symbols[randi() % symbols.size()]
	particle.add_theme_font_size_override("font_size", randi_range(8, 14))
	particle.add_theme_color_override("font_color", Color(biome_color.r, biome_color.g, biome_color.b, 0.4))
	particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	particle.position = center + Vector2(randf_range(-30, 30), randf_range(-20, 20))
	particle.modulate.a = 0.0
	_particles_layer.add_child(particle)

	# Float upward and fade
	var tw := create_tween()
	tw.tween_property(particle, "modulate:a", 0.6, 0.5)
	tw.tween_property(particle, "position:y", particle.position.y - randf_range(20, 40), 2.0).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(particle, "modulate:a", 0.0, 1.0).set_delay(1.0)
	tw.tween_callback(particle.queue_free)

	# Schedule next particle (loop)
	if is_inside_tree():
		var timer := get_tree().create_timer(randf_range(1.5, 3.0))
		timer.timeout.connect(_spawn_biome_particle.bind(biome_key))


# =============================================================================
# PUBLIC API (for HubAntre integration)
# =============================================================================

func get_selected_biome() -> String:
	return _selected_biome


func set_selected_biome(biome_key: String) -> void:
	if BIOME_MAP_POSITIONS.has(biome_key) and _unlocked_biomes.get(biome_key, false):
		_selected_biome = biome_key
		_update_selection_visuals()


func get_node_data(node_id: String) -> Dictionary:
	## Compatibility: return biome data as a node dictionary.
	var vis: Dictionary = BIOME_VISUALS.get(node_id, {})
	return vis


func set_map(_data: Array, _current_floor: int, _current_node_id: String) -> void:
	## Compatibility stub — biome map ignores STS map data.
	pass
