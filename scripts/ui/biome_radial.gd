class_name BiomeRadial
extends Control

## Half-circle radial biome selector for hub scene
## Appears above PARTIR button when no biome is selected
## 7 biomes on a 180-degree arc with procedural pixel art icons

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
	"iles_mystiques",
]

const BIOME_SHORT_NAMES := {
	"foret_broceliande": "Foret",
	"landes_bruyere": "Landes",
	"cotes_sauvages": "Cotes",
	"villages_celtes": "Villages",
	"cercles_pierres": "Cercles",
	"marais_korrigans": "Marais",
	"collines_dolmens": "Collines",
	"iles_mystiques": "Iles",
}

const BIOME_PROFILE_KEYS := {
	"foret_broceliande": "broceliande",
	"landes_bruyere": "landes",
	"cotes_sauvages": "cotes",
	"villages_celtes": "villages",
	"cercles_pierres": "cercles",
	"marais_korrigans": "marais",
	"collines_dolmens": "collines",
	"iles_mystiques": "iles",
}

const BIOME_THRESHOLDS := {
	"foret_broceliande": 0,
	"landes_bruyere": 15,
	"cotes_sauvages": 15,
	"villages_celtes": 25,
	"cercles_pierres": 30,
	"marais_korrigans": 40,
	"collines_dolmens": 50,
	"iles_mystiques": 75,
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
var _global_maturity: float = 0.0

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

	_refresh_maturity()
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
	for i in BIOMES.size():
		if _is_point_in_icon(pos, i):
			if not _is_biome_unlocked(BIOMES[i]):
				return
			biome_selected.emit(BIOMES[i])
			close()
			return

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

	var biome_key: String = BIOMES[index]
	var profile_key: String = BIOME_PROFILE_KEYS[biome_key]
	var c_accent: Color = MerlinVisual.BIOME_ART_PROFILES[profile_key]["accent"]
	var c_outline: Color = MerlinVisual.GBC["dark_gray"]
	var unlocked: bool = _is_biome_unlocked(biome_key)

	if not unlocked:
		c_accent = c_accent.darkened(0.55)
		c_accent.a = 0.45
		c_outline = c_outline.darkened(0.4)

	var radius: float = ICON_RADIUS * scale
	draw_circle(pos, radius, c_accent)
	draw_arc(pos, radius, 0.0, TAU, 32, c_outline, 1.0, true)

	_draw_procedural_icon(pos, profile_key, scale)

	if not unlocked:
		_draw_maturity_ring(pos, radius, biome_key)
	_draw_biome_label(pos, biome_key, index == _hovered_index, unlocked)

func _draw_procedural_icon(pos: Vector2, profile_key: String, scale: float) -> void:
	var icon_size := ICON_SIZE * scale

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
			_draw_islands_icon(pos, icon_size)

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

func _draw_biome_label(pos: Vector2, biome_key: String, is_hovered: bool = false, unlocked: bool = true) -> void:
	var label_text: String = BIOME_SHORT_NAMES[biome_key]
	var font := MerlinVisual.get_font("body")
	var font_size := 14

	if not unlocked:
		var threshold: int = BIOME_THRESHOLDS.get(biome_key, 0)
		label_text = "%s (%d)" % [label_text, threshold]

	var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var label_pos := pos + Vector2(-text_size.x * 0.5, ICON_RADIUS + 14.0)

	var c_shadow: Color = MerlinVisual.GBC["black"]
	draw_string(font, label_pos + Vector2(1, 1), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, c_shadow)

	var c_text: Color
	if not unlocked:
		c_text = Color(1.0, 1.0, 1.0, 0.35)
	elif is_hovered:
		c_text = MerlinVisual.GBC["white"]
	else:
		c_text = Color(1.0, 1.0, 1.0, 0.65)
	draw_string(font, label_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, c_text)


func _draw_islands_icon(pos: Vector2, size: float) -> void:
	var c_land: Color = MerlinVisual.GBC["light_gray"]
	var c_wave: Color = MerlinVisual.GBC["cream"]
	draw_circle(pos + Vector2(-size * 0.2, -size * 0.05), size * 0.18, c_land)
	draw_circle(pos + Vector2(size * 0.22, size * 0.08), size * 0.14, c_land)
	draw_arc(pos + Vector2(0, size * 0.3), size * 0.4, PI, TAU, 16, c_wave, 1.5, true)


func _draw_maturity_ring(pos: Vector2, radius: float, biome_key: String) -> void:
	var threshold: int = BIOME_THRESHOLDS.get(biome_key, 1)
	if threshold <= 0:
		return
	var progress: float = clampf(_global_maturity / float(threshold), 0.0, 1.0)
	var ring_angle: float = progress * TAU
	var c_ring: Color = MerlinVisual.CRT_PALETTE["amber_dim"]
	draw_arc(pos, radius + 3.0, -PI * 0.5, -PI * 0.5 + ring_angle, 32, c_ring, 2.0, true)


func _refresh_maturity() -> void:
	var store: Node = get_node_or_null("/root/MerlinStore")
	if store == null:
		return
	var meta: Dictionary = store.state.get("meta", {})
	var total_runs: int = int(meta.get("total_runs", 0))
	var endings: Array = meta.get("endings_seen", [])
	var oghams: Array = meta.get("oghams_owned", [])
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	var max_rep: float = 0.0
	for val in faction_rep.values():
		max_rep = maxf(max_rep, float(val))
	_global_maturity = total_runs * 2.0 + endings.size() * 5.0 + oghams.size() * 3.0 + max_rep


func _is_biome_unlocked(biome_key: String) -> bool:
	return _global_maturity >= float(BIOME_THRESHOLDS.get(biome_key, 0))
