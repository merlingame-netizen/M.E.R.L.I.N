class_name PixelSceneCompositor
extends Control
## Procedural 48x48 pixel scene compositor for card illustrations.
## Assembles background + props + creature + weather from PixelSceneData,
## tinted by biome and season. Pattern: PixelNpcPortrait packed arrays.

const GRID_SIZE := 48
const MAX_PROPS := 3
const MAX_CREATURES := 1
const ASSEMBLY_SPEED := 1.8  # ~0.55s total animation
const GLOW_FREQ := 1.5       # Hz for idle pulse

# Packed rendering data
var _positions := PackedVector2Array()
var _colors := PackedColorArray()
var _base_colors := PackedColorArray()
var _glow_mask := PackedFloat32Array()  # 1.0 = glow pixel, 0.0 = normal

# Animation state — assembly
var _assembled: bool = false
var _assembling: bool = false
var _assembly_progress: float = 0.0
var _pixel_delays := PackedFloat32Array()
var _pixel_targets := PackedVector2Array()
var _pixel_start_pos := PackedVector2Array()

# Animation state — idle
var _glow_time: float = 0.0

# Composition state
var _current_tags: Array = []
var _current_biome: String = ""
var _current_season: String = ""
var _target_size: float = 220.0
var _pixel_size: float = 4.583  # 220 / 48
var _occupied_rects: Array[Rect2i] = []


func setup(p_target_size: float) -> void:
	_target_size = p_target_size
	_pixel_size = p_target_size / float(GRID_SIZE)
	custom_minimum_size = Vector2(p_target_size, p_target_size)


func compose_scene(visual_tags: Array, biome: String, season: String) -> void:
	_current_tags = visual_tags
	_current_biome = biome
	_current_season = season
	_occupied_rects.clear()
	_positions.clear()
	_colors.clear()
	_glow_mask.clear()

	# Layer 1: Background
	var bg := _select_background(visual_tags, biome)
	if not bg.is_empty():
		_composite_grid(bg, Vector2i.ZERO)

	# Layer 2: Props (2-3)
	var props := _select_props(visual_tags, 2, MAX_PROPS)
	for prop in props:
		var pos := _find_prop_placement(prop)
		_composite_grid(prop, pos)

	# Layer 3: Creature (0-1)
	var creature := _select_creature(visual_tags)
	if not creature.is_empty():
		var pos := _find_creature_placement(creature)
		_composite_grid(creature, pos)

	# Layer 4: Weather overlay
	var weather := _select_weather(visual_tags)
	if not weather.is_empty():
		_composite_grid(weather, Vector2i.ZERO)

	# Apply biome + season tint
	_apply_tint(biome, season)

	# Store base colors for idle animation
	_base_colors = _colors.duplicate()

	# Build glow mask (accent-colored pixels glow)
	_glow_mask.resize(_colors.size())
	for i in range(_colors.size()):
		var c: Color = _colors[i]
		# Glow on bright warm pixels (fire, glowing elements)
		if c.a > 0.4 and ((c.r > 0.6 and c.g > 0.4) or c.v > 0.7):
			_glow_mask[i] = 1.0
		else:
			_glow_mask[i] = 0.0


func assemble(animated: bool = true) -> void:
	if not animated or _positions.is_empty():
		_assembled = true
		_assembling = false
		queue_redraw()
		return

	_assembled = false
	_assembling = true
	_assembly_progress = 0.0

	# Prepare cascade animation
	var count: int = _positions.size()
	_pixel_delays.resize(count)
	_pixel_targets = _positions.duplicate()
	_pixel_start_pos.resize(count)

	for i in range(count):
		# Row-based stagger with random offset for organic feel
		var row_ratio: float = _pixel_targets[i].y / _target_size
		_pixel_delays[i] = row_ratio * 0.5 + randf_range(0.0, 0.2)
		_pixel_start_pos[i] = Vector2(
			_pixel_targets[i].x + randf_range(-20.0, 20.0),
			_pixel_targets[i].y - randf_range(40.0, 100.0)
		)
	queue_redraw()


func _process(delta: float) -> void:
	if _assembling and not _assembled:
		_assembly_progress += delta * ASSEMBLY_SPEED
		if _assembly_progress >= 1.0:
			_assembly_progress = 1.0
			_assembling = false
			_assembled = true
			_positions = _pixel_targets.duplicate()
		queue_redraw()
		return

	if not _assembled or _positions.is_empty():
		return

	# Idle glow pulse on accent pixels
	_glow_time += delta
	var glow_strength: float = (sin(_glow_time * TAU * GLOW_FREQ) + 1.0) * 0.5
	var has_glow: bool = false
	for i in range(_colors.size()):
		if _glow_mask[i] > 0.5:
			var base_c: Color = _base_colors[i]
			var bright_c := Color(
				minf(base_c.r * 1.3, 1.0),
				minf(base_c.g * 1.3, 1.0),
				minf(base_c.b * 1.1, 1.0),
				base_c.a
			)
			_colors[i] = base_c.lerp(bright_c, glow_strength * 0.4)
			has_glow = true
	if has_glow:
		queue_redraw()


func _draw() -> void:
	if _positions.is_empty():
		return

	var ps: float = _pixel_size

	if _assembling:
		for i in range(_positions.size()):
			var delay: float = _pixel_delays[i]
			var t: float = clampf((_assembly_progress - delay) / maxf(1.0 - delay, 0.01), 0.0, 1.0)
			# ease_back_out
			var ease_t: float = 1.0 + 2.70158 * pow(t - 1.0, 3.0) + 1.70158 * pow(t - 1.0, 2.0)
			ease_t = clampf(ease_t, 0.0, 1.5)
			var pos: Vector2 = _pixel_start_pos[i].lerp(_pixel_targets[i], ease_t)
			var alpha: float = clampf(t * 3.0, 0.0, 1.0)
			var c: Color = _colors[i]
			if c.a > 0.01 and alpha > 0.01:
				draw_rect(Rect2(pos, Vector2(ps, ps)), Color(c.r, c.g, c.b, c.a * alpha))
		return

	# Normal rendering
	for i in range(_positions.size()):
		var c: Color = _colors[i]
		if c.a > 0.01:
			draw_rect(Rect2(_positions[i], Vector2(ps, ps)), c)


# ═══════════════════════════════════════════════════════════════════════════════
# COMPONENT SELECTION — tag overlap scoring
# ═══════════════════════════════════════════════════════════════════════════════

func _select_background(tags: Array, biome: String) -> Dictionary:
	var best_score := -1
	var best_key: String = ""
	for key in PixelSceneData.BACKGROUNDS:
		var bg: Dictionary = PixelSceneData.BACKGROUNDS[key]
		var score := _score_component(bg, tags, biome)
		if score > best_score:
			best_score = score
			best_key = key
	if best_key.is_empty():
		# Absolute fallback: first background
		var keys := PixelSceneData.BACKGROUNDS.keys()
		if not keys.is_empty():
			best_key = str(keys[0])
	return PixelSceneData.BACKGROUNDS.get(best_key, {})


func _select_props(tags: Array, min_count: int, max_count: int) -> Array[Dictionary]:
	var scored: Array[Dictionary] = []
	for key in PixelSceneData.PROPS:
		var prop: Dictionary = PixelSceneData.PROPS[key]
		var score: int = _score_component(prop, tags, _current_biome)
		scored.append({"key": key, "score": score, "data": prop})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.score) > int(b.score))

	var count: int = mini(max_count, scored.size())
	count = maxi(min_count, count)
	var result: Array[Dictionary] = []
	for i in range(mini(count, scored.size())):
		if int(scored[i].score) > 0 or i < min_count:
			result.append(scored[i].data as Dictionary)
	return result


func _select_creature(tags: Array) -> Dictionary:
	var best_score := 0
	var best_key: String = ""
	for key in PixelSceneData.CREATURES:
		var creature: Dictionary = PixelSceneData.CREATURES[key]
		var score: int = _score_component(creature, tags, _current_biome)
		if score > best_score:
			best_score = score
			best_key = key
	if best_key.is_empty():
		return {}
	return PixelSceneData.CREATURES[best_key]


func _select_weather(tags: Array) -> Dictionary:
	var best_score := 0
	var best_key: String = ""
	for key in PixelSceneData.WEATHER:
		var weather: Dictionary = PixelSceneData.WEATHER[key]
		var wtags: Array = weather.get("tags", [])
		var score := 0
		for tag in tags:
			if tag in wtags:
				score += 1
		if score > best_score:
			best_score = score
			best_key = key
	if best_key.is_empty():
		return {}
	return PixelSceneData.WEATHER[best_key]


func _score_component(component: Dictionary, tags: Array, biome: String) -> int:
	var score := 0
	var comp_biomes: Array = component.get("biomes", [])
	if not comp_biomes.is_empty() and biome in comp_biomes:
		score += 10
	var comp_tags: Array = component.get("tags", [])
	for tag in tags:
		if tag in comp_tags:
			score += 2
	return score


# ═══════════════════════════════════════════════════════════════════════════════
# COMPOSITION — grid → packed arrays
# ═══════════════════════════════════════════════════════════════════════════════

func _composite_grid(component: Dictionary, offset: Vector2i) -> void:
	var grid: PackedStringArray = component.get("grid", PackedStringArray())
	var palette: Array = component.get("palette", [])
	if grid.is_empty() or palette.is_empty():
		return

	var ps: float = _pixel_size
	for row_idx in range(grid.size()):
		var row: String = grid[row_idx]
		for col_idx in range(row.length()):
			var ch: String = row[col_idx]
			if ch == "0":
				continue  # transparent
			var palette_idx: int = ch.to_int()
			if palette_idx < 0 or palette_idx >= palette.size():
				continue
			var color: Color = palette[palette_idx]
			if color.a < 0.01:
				continue

			var px: float = (offset.x + col_idx) * ps
			var py: float = (offset.y + row_idx) * ps

			# Bounds check
			if px < 0.0 or py < 0.0 or px >= _target_size or py >= _target_size:
				continue

			_positions.append(Vector2(px, py))
			_colors.append(color)


func _find_prop_placement(prop: Dictionary) -> Vector2i:
	var prop_size: Vector2i = prop.get("size", Vector2i(8, 8))
	var anchor: Vector2i = prop.get("anchor", Vector2i(prop_size.x / 2, prop_size.y))

	# Place props in ground area (rows 28-44) with horizontal variety
	var max_attempts := 15
	for _attempt in range(max_attempts):
		var target_x: int = randi_range(4, GRID_SIZE - prop_size.x - 4)
		var target_y: int = randi_range(28, 44 - prop_size.y)
		var top_left := Vector2i(target_x - anchor.x + prop_size.x / 2, target_y)
		var rect := Rect2i(top_left, prop_size)

		# Check overlap with existing props
		var overlaps := false
		for occupied in _occupied_rects:
			if rect.intersects(occupied):
				overlaps = true
				break
		if not overlaps:
			_occupied_rects.append(rect)
			return top_left

	# Fallback: place anyway
	var fallback := Vector2i(randi_range(4, GRID_SIZE - prop_size.x - 4), 32)
	_occupied_rects.append(Rect2i(fallback, prop_size))
	return fallback


func _find_creature_placement(creature: Dictionary) -> Vector2i:
	var creature_size: Vector2i = creature.get("size", Vector2i(10, 10))

	# Place creature in mid-lower area, avoid center (props go there)
	var side: int = randi_range(0, 1)  # 0 = left, 1 = right
	var x: int
	if side == 0:
		x = randi_range(2, 14)
	else:
		x = randi_range(GRID_SIZE - creature_size.x - 14, GRID_SIZE - creature_size.x - 2)
	var y: int = randi_range(26, 40 - creature_size.y)

	var rect := Rect2i(Vector2i(x, y), creature_size)
	_occupied_rects.append(rect)
	return Vector2i(x, y)


# ═══════════════════════════════════════════════════════════════════════════════
# TINTING — biome + season color grading
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_tint(biome: String, season: String) -> void:
	if not MerlinVisual:
		return

	# Get biome tint color
	var biome_colors: Dictionary = MerlinVisual.BIOME_COLORS.get(
		_biome_to_key(biome), {})
	var biome_primary: Color = biome_colors.get("primary", Color.WHITE)

	# Get season tint
	var season_key: String = _season_to_key(season)
	var season_tint: Color = MerlinVisual.SEASON_TINTS.get(season_key, Color.WHITE)

	# Apply subtle biome tint (20% influence) + season tint (15% influence)
	for i in range(_colors.size()):
		var c: Color = _colors[i]
		if c.a < 0.01:
			continue
		# Biome influence: shift hue slightly toward biome primary
		var tinted := c.lerp(
			Color(c.r * biome_primary.r * 1.3, c.g * biome_primary.g * 1.3,
				  c.b * biome_primary.b * 1.3, c.a), 0.15)
		# Season multiplier
		tinted = Color(
			clampf(tinted.r * season_tint.r, 0.0, 1.0),
			clampf(tinted.g * season_tint.g, 0.0, 1.0),
			clampf(tinted.b * season_tint.b, 0.0, 1.0),
			tinted.a)
		_colors[i] = tinted


func _biome_to_key(biome: String) -> String:
	# Map full biome names to BIOME_COLORS keys
	match biome:
		"foret_broceliande": return "broceliande"
		"landes_bruyere": return "landes"
		"cotes_sauvages": return "cotes"
		"villages_celtes": return "villages"
		"cercles_pierres": return "cercles"
		"marais_korrigans": return "marais"
		"collines_dolmens": return "collines"
		_: return "broceliande"


func _season_to_key(season: String) -> String:
	match season:
		"spring", "printemps": return "printemps"
		"summer", "ete": return "ete"
		"autumn", "automne": return "automne"
		"winter", "hiver": return "hiver"
		_: return "automne"
