class_name BiomeRadial
extends Control

## Half-circle radial biome selector for hub scene
## Appears above PARTIR button when no biome is selected
## 8 biomes on a 180-degree arc with procedural pixel art icons

signal biome_selected(biome_key: String)
signal radial_dismissed

# === BIOME DATA ===

const BIOMES := [
	"foret_broceliande",
	"landes_bruyere",
	"cotes_sauvages",
	"villages_celtes",
	"cercles_pierres",
	"marais_korrigans",
	"collines_dolmens",
	"iles_mystiques"
]

const BIOME_SHORT_NAMES := {
	"foret_broceliande": "Foret",
	"landes_bruyere": "Landes",
	"cotes_sauvages": "Cotes",
	"villages_celtes": "Villages",
	"cercles_pierres": "Cercles",
	"marais_korrigans": "Marais",
	"collines_dolmens": "Collines",
	"iles_mystiques": "Iles"
}

const BIOME_FULL_NAMES := {
	"foret_broceliande": "Foret de Broceliande",
	"landes_bruyere": "Landes de Bruyere",
	"cotes_sauvages": "Cotes Sauvages",
	"villages_celtes": "Villages Celtes",
	"cercles_pierres": "Cercles de Pierres",
	"marais_korrigans": "Marais des Korrigans",
	"collines_dolmens": "Collines aux Dolmens",
	"iles_mystiques": "Iles Mystiques"
}

const BIOME_GUARDIANS := {
	"foret_broceliande": "Maelgwn",
	"landes_bruyere": "Talwen",
	"cotes_sauvages": "Bran",
	"villages_celtes": "Azenor",
	"cercles_pierres": "Keridwen",
	"marais_korrigans": "Gwydion",
	"collines_dolmens": "Elouan",
	"iles_mystiques": "Morgane"
}

const BIOME_SEASONS := {
	"foret_broceliande": "Automne",
	"landes_bruyere": "Hiver",
	"cotes_sauvages": "Ete",
	"villages_celtes": "Printemps",
	"cercles_pierres": "Samhain",
	"marais_korrigans": "Lughnasadh",
	"collines_dolmens": "Yule",
	"iles_mystiques": "Samhain"
}

const BIOME_DIFFICULTY := {
	"foret_broceliande": "Normal",
	"landes_bruyere": "Difficile",
	"cotes_sauvages": "Normal",
	"villages_celtes": "Facile",
	"cercles_pierres": "Difficile",
	"marais_korrigans": "Tres difficile",
	"collines_dolmens": "Normal",
	"iles_mystiques": "Legendaire"
}

# Map full biome keys to BIOME_ART_PROFILES keys
const BIOME_PROFILE_KEYS := {
	"foret_broceliande": "broceliande",
	"landes_bruyere": "landes",
	"cotes_sauvages": "cotes",
	"villages_celtes": "villages",
	"cercles_pierres": "cercles",
	"marais_korrigans": "marais",
	"collines_dolmens": "collines",
	"iles_mystiques": "iles"
}

# === VISUAL CONSTANTS ===

const ARC_RADIUS := 150.0
const ICON_RADIUS := 26.0
const ICON_SIZE := 12.0
const STAGGER_DELAY := 0.06
const OPEN_DURATION := 0.3
const CLOSE_DURATION := 0.2
const HOVER_SCALE := 1.25
const BACKGROUND_ALPHA := 0.4

# === STATE ===

var _is_open := false
var _center_pos := Vector2.ZERO
var _hovered_index := -1
var _biome_positions: Array[Vector2] = []
var _biome_scales: Array[float] = []
var _biome_current_scales: Array[float] = []

# === LIFECYCLE ===

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_biome_scales.resize(BIOMES.size())
	_biome_current_scales.resize(BIOMES.size())
	_biome_positions.resize(BIOMES.size())

	for i in BIOMES.size():
		_biome_scales[i] = 0.0
		_biome_current_scales[i] = 1.0

func _draw() -> void:
	if not _is_open:
		return

	# Draw semi-transparent background
	var c_dim: Color = Color(0.0, 0.0, 0.0, BACKGROUND_ALPHA)
	draw_rect(Rect2(Vector2.ZERO, size), c_dim, true)

	# Draw biome icons
	for i in BIOMES.size():
		_draw_biome_icon(i)

	# Draw hover info panel below the arc
	_draw_hover_panel()

func _input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(mb.position)
			accept_event()

	elif event is InputEventMouseMotion:
		_update_hover(event.position)

	elif event.is_action_pressed("ui_cancel"):
		close()
		accept_event()

# === PUBLIC API ===

func open(center_pos: Vector2) -> void:
	if _is_open:
		return

	_is_open = true
	_center_pos = center_pos
	_hovered_index = -1
	visible = true

	_calculate_positions()
	_animate_open()

func close() -> void:
	if not _is_open:
		return

	_is_open = false
	_hovered_index = -1
	_animate_close()

func is_open() -> bool:
	return _is_open

# === PRIVATE METHODS ===

func _calculate_positions() -> void:
	# Distribute icons on a 180-degree arc (PI radians)
	# First icon at angle PI (left), last at angle 0 (right)
	var angle_step := PI / float(BIOMES.size() - 1)

	for i in BIOMES.size():
		var angle := PI - (i * angle_step)
		var offset := Vector2(cos(angle), sin(angle)) * ARC_RADIUS
		_biome_positions[i] = _center_pos + offset

func _animate_open() -> void:
	# Stagger animation for each icon
	for i in BIOMES.size():
		var delay := i * STAGGER_DELAY
		_animate_icon_open(i, delay)

func _animate_icon_open(index: int, delay: float) -> void:
	await get_tree().create_timer(delay).timeout

	var tween := create_tween()
	tween.set_trans(MerlinVisual.TRANS_UI)
	tween.set_ease(Tween.EASE_OUT)

	# Scale from 0 to 1 with slight bounce
	tween.tween_method(
		func(v: float) -> void:
			_biome_scales[index] = v
			queue_redraw(),
		0.0,
		1.0,
		OPEN_DURATION
	)

func _animate_close() -> void:
	var tween := create_tween()
	tween.set_trans(MerlinVisual.TRANS_UI)
	tween.set_ease(MerlinVisual.EASING_UI)

	# Scale all icons to 0 simultaneously
	for i in BIOMES.size():
		tween.parallel().tween_method(
			func(v: float) -> void:
				_biome_scales[i] = v
				queue_redraw(),
			_biome_scales[i],
			0.0,
			CLOSE_DURATION
		)

	await tween.finished
	visible = false

func _handle_click(pos: Vector2) -> void:
	# Check if click hit any biome icon
	for i in BIOMES.size():
		if _is_point_in_icon(pos, i):
			if _is_biome_locked(BIOMES[i]):
				SFXManager.play("hover")
				return
			biome_selected.emit(BIOMES[i])
			close()
			return

	# Click outside -> dismiss
	radial_dismissed.emit()
	close()

func _update_hover(pos: Vector2) -> void:
	var old_hover := _hovered_index
	_hovered_index = -1

	# Find hovered icon
	for i in BIOMES.size():
		if _is_point_in_icon(pos, i):
			_hovered_index = i
			break

	# Update scales if hover changed
	if old_hover != _hovered_index:
		_animate_hover_scales()

func _animate_hover_scales() -> void:
	for i in BIOMES.size():
		var target_scale := HOVER_SCALE if i == _hovered_index else 1.0

		var tween := create_tween()
		tween.set_trans(MerlinVisual.TRANS_UI)
		tween.set_ease(MerlinVisual.EASING_UI)
		tween.tween_method(
			func(v: float) -> void:
				_biome_current_scales[i] = v
				queue_redraw(),
			_biome_current_scales[i],
			target_scale,
			0.1
		)

func _is_point_in_icon(pos: Vector2, index: int) -> bool:
	if index < 0 or index >= _biome_positions.size():
		return false

	var icon_pos: Vector2 = _biome_positions[index]
	var distance := pos.distance_to(icon_pos)
	var scaled_radius: float = ICON_RADIUS * _biome_scales[index]

	return distance <= scaled_radius

func _draw_biome_icon(index: int) -> void:
	if _biome_scales[index] <= 0.0:
		return

	var pos: Vector2 = _biome_positions[index]
	var scale: float = _biome_scales[index] * _biome_current_scales[index]

	# Get biome accent color
	var biome_key: String = BIOMES[index]
	var profile_key: String = BIOME_PROFILE_KEYS[biome_key]
	var c_accent: Color = MerlinVisual.BIOME_ART_PROFILES[profile_key]["accent"]
	var c_outline: Color = MerlinVisual.GBC["dark_gray"]
	var locked: bool = _is_biome_locked(biome_key)

	# Dim if locked
	if locked:
		c_accent.a *= 0.35

	# Draw circle background
	var radius: float = ICON_RADIUS * scale
	draw_circle(pos, radius, c_accent)
	draw_arc(pos, radius, 0.0, TAU, 32, c_outline, 1.0, true)

	# Draw procedural icon
	_draw_procedural_icon(pos, profile_key, scale)

	# Draw lock indicator if locked
	if locked:
		_draw_lock_indicator(pos, scale)

	# Label permanent (toujours visible, plus lumineux si hovered)
	_draw_biome_label(pos, biome_key, index == _hovered_index)

func _draw_procedural_icon(pos: Vector2, profile_key: String, scale: float) -> void:
	var icon_size := ICON_SIZE * scale
	var half_size := icon_size * 0.5

	match profile_key:
		"broceliande":
			_draw_forest_icon(pos, icon_size)
		"landes":
			_draw_grass_icon(pos, icon_size)
		"cotes":
			_draw_coast_icon(pos, icon_size)
		"villages":
			_draw_village_icon(pos, icon_size)
		"cercles":
			_draw_stones_icon(pos, icon_size)
		"marais":
			_draw_marsh_icon(pos, icon_size)
		"collines":
			_draw_hills_icon(pos, icon_size)
		"iles":
			_draw_island_icon(pos, icon_size)

func _draw_forest_icon(pos: Vector2, size: float) -> void:
	# 3 triangle trees
	var c_tree: Color = MerlinVisual.GBC["gray"]
	var spacing := size * 0.3

	for i in 3:
		var x := pos.x - size * 0.4 + i * spacing
		var y := pos.y
		_draw_triangle(Vector2(x, y), size * 0.25, c_tree)

func _draw_grass_icon(pos: Vector2, size: float) -> void:
	# 3 wavy grass lines
	var c_grass: Color = MerlinVisual.GBC["light_gray"]
	var spacing := size * 0.3

	for i in 3:
		var x := pos.x - size * 0.4 + i * spacing
		var y := pos.y
		draw_line(Vector2(x, y - size * 0.2), Vector2(x, y + size * 0.2), c_grass, 1.0)

func _draw_coast_icon(pos: Vector2, size: float) -> void:
	# Wave curve + dot rock
	var c_wave: Color = MerlinVisual.GBC["cream"]
	var c_rock: Color = MerlinVisual.GBC["gray"]

	# Simple wave as arc
	draw_arc(pos, size * 0.4, 0.0, PI, 16, c_wave, 1.5, true)

	# Rock dot
	draw_circle(pos + Vector2(size * 0.3, -size * 0.2), size * 0.15, c_rock)

func _draw_village_icon(pos: Vector2, size: float) -> void:
	# Simple house shape
	var c_house: Color = MerlinVisual.GBC["cream"]

	# House base
	var rect := Rect2(pos - Vector2(size * 0.3, size * 0.1), Vector2(size * 0.6, size * 0.4))
	draw_rect(rect, c_house, true)

	# Roof triangle
	_draw_triangle(pos - Vector2(0, size * 0.3), size * 0.4, c_house)

func _draw_stones_icon(pos: Vector2, size: float) -> void:
	# 3 vertical menhirs
	var c_stone: Color = MerlinVisual.GBC["light_gray"]
	var spacing := size * 0.3

	for i in 3:
		var x := pos.x - size * 0.4 + i * spacing
		var rect := Rect2(Vector2(x - size * 0.08, pos.y - size * 0.3), Vector2(size * 0.16, size * 0.6))
		draw_rect(rect, c_stone, true)

func _draw_marsh_icon(pos: Vector2, size: float) -> void:
	# Wavy water + small dot
	var c_water: Color = MerlinVisual.GBC["cream"]
	var c_plant: Color = MerlinVisual.GBC["cream"]

	# Water waves
	draw_arc(pos, size * 0.35, 0.0, PI, 16, c_water, 1.5, true)

	# Plant dot
	draw_circle(pos + Vector2(size * 0.2, -size * 0.1), size * 0.12, c_plant)

func _draw_hills_icon(pos: Vector2, size: float) -> void:
	# Hill curve + dolmen rectangle
	var c_hill: Color = MerlinVisual.GBC["light_gray"]
	var c_stone: Color = MerlinVisual.GBC["gray"]

	# Hill arc
	draw_arc(pos + Vector2(0, size * 0.2), size * 0.4, PI, TAU, 16, c_hill, 2.0, true)

	# Dolmen
	var rect := Rect2(pos - Vector2(size * 0.15, size * 0.25), Vector2(size * 0.3, size * 0.2))
	draw_rect(rect, c_stone, true)

func _draw_triangle(pos: Vector2, size: float, color: Color) -> void:
	var points := PackedVector2Array([
		pos + Vector2(0, -size),
		pos + Vector2(-size * 0.5, size * 0.5),
		pos + Vector2(size * 0.5, size * 0.5)
	])
	draw_colored_polygon(points, color)

func _draw_biome_label(pos: Vector2, biome_key: String, is_hovered: bool = false) -> void:
	var locked: bool = _is_biome_locked(biome_key)
	var label_text: String = BIOME_SHORT_NAMES[biome_key]
	if locked:
		var threshold: int = int(MerlinConstants.BIOME_MATURITY_THRESHOLDS.get(biome_key, 0))
		label_text += " (%d)" % threshold
	var font := MerlinVisual.get_font("body")
	var font_size := 14

	var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var label_pos := pos + Vector2(-text_size.x * 0.5, ICON_RADIUS + 14.0)

	# Shadow
	var c_shadow: Color = MerlinVisual.GBC["black"]
	draw_string(font, label_pos + Vector2(1, 1), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, c_shadow)

	# Texte : blanc brillant si hovered, dimmed if locked, blanc atténué sinon (label permanent)
	var c_text: Color
	if locked:
		c_text = Color(1.0, 1.0, 1.0, 0.35)
	elif is_hovered:
		c_text = MerlinVisual.GBC["white"]
	else:
		c_text = Color(1.0, 1.0, 1.0, 0.65)
	draw_string(font, label_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, c_text)

# === HOVER INFO PANEL ===

func _draw_hover_panel() -> void:
	if _hovered_index < 0:
		return

	var biome_key: String = BIOMES[_hovered_index]
	var font: Font = MerlinVisual.get_font("body")
	var font_size: int = 12

	# --- Colors from CRT palette ---
	var c_bg: Color = Color(
		MerlinVisual.CRT_PALETTE["bg_deep"].r,
		MerlinVisual.CRT_PALETTE["bg_deep"].g,
		MerlinVisual.CRT_PALETTE["bg_deep"].b,
		0.9
	)
	var c_border: Color = MerlinVisual.CRT_PALETTE["amber_dim"]
	var c_text: Color = MerlinVisual.CRT_PALETTE["phosphor"]
	var c_cyan: Color = MerlinVisual.CRT_PALETTE["cyan_dim"]

	# --- Panel dimensions ---
	var panel_w: float = 220.0
	var line_h: float = 16.0
	var pad_x: float = 10.0
	var pad_y: float = 8.0
	var bar_h: float = 8.0
	# 5 text lines + maturity bar + spacing
	var panel_h: float = pad_y + line_h * 5 + bar_h + pad_y + 4.0

	# --- Position: centered below arc ---
	var panel_x: float = _center_pos.x - panel_w * 0.5
	var panel_y: float = _center_pos.y + 20.0
	var panel_rect: Rect2 = Rect2(Vector2(panel_x, panel_y), Vector2(panel_w, panel_h))

	# --- Draw background and border ---
	draw_rect(panel_rect, c_bg, true)
	draw_rect(panel_rect, c_border, false, 1.0)

	# --- Text content ---
	var full_name: String = BIOME_FULL_NAMES.get(biome_key, biome_key)
	var guardian: String = BIOME_GUARDIANS.get(biome_key, "???")
	var season: String = BIOME_SEASONS.get(biome_key, "???")
	var difficulty: String = BIOME_DIFFICULTY.get(biome_key, "???")

	var text_x: float = panel_x + pad_x
	var cur_y: float = panel_y + pad_y + font_size

	# Line 1: Full biome name (phosphor)
	draw_string(font, Vector2(text_x, cur_y), full_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c_text)
	cur_y += line_h

	# Line 2: Guardian (cyan)
	draw_string(font, Vector2(text_x, cur_y), "Gardien: " + guardian, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c_cyan)
	cur_y += line_h

	# Line 3: Season (phosphor)
	draw_string(font, Vector2(text_x, cur_y), "Saison: " + season, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c_text)
	cur_y += line_h

	# Line 4: Difficulty (phosphor)
	draw_string(font, Vector2(text_x, cur_y), "Difficulte: " + difficulty, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c_text)
	cur_y += line_h

	# Line 5: Maturity label
	var threshold: int = int(MerlinConstants.BIOME_MATURITY_THRESHOLDS.get(biome_key, 0))
	var current_maturity: int = _calculate_player_maturity()
	var maturity_label: String = "Maturite: %d / %d" % [current_maturity, threshold]
	draw_string(font, Vector2(text_x, cur_y), maturity_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c_text)
	cur_y += line_h - 2.0

	# --- Maturity progress bar ---
	var bar_w: float = 180.0
	var bar_x: float = panel_x + (panel_w - bar_w) * 0.5
	var bar_rect: Rect2 = Rect2(Vector2(bar_x, cur_y), Vector2(bar_w, bar_h))

	# Bar background (dark)
	draw_rect(bar_rect, Color(0.0, 0.0, 0.0, 0.6), true)

	# Bar fill
	var locked: bool = _is_biome_locked(biome_key)
	var c_fill: Color = MerlinVisual.CRT_PALETTE["amber_bright"] if not locked else MerlinVisual.CRT_PALETTE["phosphor_dim"]
	var ratio: float = 1.0 if threshold <= 0 else clampf(float(current_maturity) / float(threshold), 0.0, 1.0)
	if ratio > 0.0:
		var fill_rect: Rect2 = Rect2(Vector2(bar_x, cur_y), Vector2(bar_w * ratio, bar_h))
		draw_rect(fill_rect, c_fill, true)

	# Bar outline
	draw_rect(bar_rect, c_border, false, 1.0)

# === ISLAND ICON ===

func _draw_island_icon(pos: Vector2, size: float) -> void:
	# Draw 2-3 small island shapes partially submerged in a wave line
	var c_land: Color = MerlinVisual.GBC["cream"]
	var c_wave: Color = MerlinVisual.GBC["light_gray"]

	# Water wave line across the middle
	draw_arc(pos + Vector2(-size * 0.2, size * 0.1), size * 0.25, PI, TAU, 12, c_wave, 1.5, true)
	draw_arc(pos + Vector2(size * 0.2, size * 0.1), size * 0.25, PI, TAU, 12, c_wave, 1.5, true)

	# Island 1 (left) — small arc above the wave
	draw_arc(pos + Vector2(-size * 0.3, size * 0.05), size * 0.18, PI, TAU, 12, c_land, 2.0, true)

	# Island 2 (center) — slightly larger
	draw_arc(pos + Vector2(0.0, -size * 0.05), size * 0.22, PI, TAU, 12, c_land, 2.0, true)

	# Island 3 (right) — small
	draw_arc(pos + Vector2(size * 0.3, size * 0.05), size * 0.15, PI, TAU, 12, c_land, 2.0, true)

# === MATURITY / LOCKING ===

func _calculate_player_maturity() -> int:
	var store_node: Node = get_node_or_null("/root/MerlinStore")
	if store_node == null:
		return 0
	var state: Dictionary = store_node.get("state") as Dictionary
	if state.is_empty():
		return 0
	var meta: Dictionary = state.get("meta", {})
	var total_runs: int = int(meta.get("total_runs", 0))
	var endings_seen: int = meta.get("endings_seen", []).size()
	var oghams_discovered: int = state.get("oghams", {}).get("skills_unlocked", []).size()
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	var max_faction_rep: float = 0.0
	for faction in faction_rep:
		max_faction_rep = maxf(max_faction_rep, float(faction_rep[faction]))
	return total_runs * 2 + endings_seen * 5 + oghams_discovered * 3 + int(max_faction_rep) * 1

func _is_biome_locked(biome_key: String) -> bool:
	var threshold: int = int(MerlinConstants.BIOME_MATURITY_THRESHOLDS.get(biome_key, 999))
	return _calculate_player_maturity() < threshold

func _draw_lock_indicator(pos: Vector2, scale: float) -> void:
	var c_lock: Color = MerlinVisual.GBC["dark_gray"]
	var lock_size: float = 6.0 * scale

	# Padlock body (filled rect)
	var body_rect := Rect2(
		pos + Vector2(-lock_size * 0.5, -lock_size * 0.1),
		Vector2(lock_size, lock_size * 0.8)
	)
	draw_rect(body_rect, c_lock, true)

	# Padlock shackle (small rect above body)
	var shackle_rect := Rect2(
		pos + Vector2(-lock_size * 0.3, -lock_size * 0.6),
		Vector2(lock_size * 0.6, lock_size * 0.5)
	)
	draw_rect(shackle_rect, c_lock, false, 1.5)
