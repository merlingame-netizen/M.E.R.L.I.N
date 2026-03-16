## ═══════════════════════════════════════════════════════════════════════════════
## UI Biome Art Module — Biome artwork, ambient VFX, opening sequence
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_game_ui.gd — handles procedural biome pixel art,
## ambient particles, opening sequence, and biome breathing animation.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name UIBiomeArt

var _ui: MerlinGameUI

const INTRO_PIXEL_COLS := 84
const INTRO_PIXEL_ROWS := 48
const INTRO_STACK_BATCH := 26
const INTRO_STACK_STEP := 0.02
const INTRO_DECK_COUNT := 12

const BIOME_SHORT_NAMES: Dictionary = {
	"foret_broceliande": "broceliande",
	"landes_bruyere": "landes",
	"cotes_sauvages": "cotes",
	"villages_celtes": "villages",
	"cercles_pierres": "cercles",
	"marais_korrigans": "marais",
	"collines_dolmens": "collines",
}

const BIOME_DEFAULT_SEASON: Dictionary = {
	"broceliande": "automne",
	"landes": "hiver",
	"cotes": "hiver",
	"villages": "ete",
	"cercles": "printemps",
	"marais": "printemps",
	"collines": "automne",
}

const MAX_AMBIENT_PARTICLES := 10

var _ambient_timer: Timer
var _ambient_particles: Array[ColorRect] = []
var _ambient_biome_key: String = ""
var _biome_art_pixels: Array[ColorRect] = []
var _biome_breath_tween: Tween


func initialize(ui: MerlinGameUI) -> void:
	_ui = ui


# ═══════════════════════════════════════════════════════════════════════════════
# OPENING SEQUENCE
# ═══════════════════════════════════════════════════════════════════════════════

func show_opening_sequence(biome_key: String, season_hint: String = "", hour_hint: int = -1) -> void:
	if _ui._opening_sequence_done:
		return
	_ui._opening_sequence_done = true
	_ui._layout_run_zones()
	_ui._layout_card_stage()
	_set_intro_hidden_state()
	await _ui.get_tree().process_frame

	var key: String = normalize_biome_key(biome_key)
	var season: String = normalize_season(season_hint, key)
	var hour: int = hour_hint
	if hour < 0 or hour > 23:
		var now: Dictionary = Time.get_datetime_dict_from_system()
		hour = int(now.get("hour", 12))

	build_biome_artwork(key, season, hour)
	_ui.biome_art_layer.visible = true
	_ui.biome_art_layer.modulate.a = 0.0
	await _animate_biome_artwork_stack()
	_dim_biome_background()
	await _animate_deck_assembly(key)
	_set_empty_center_card_state()
	await _reveal_empty_center_card()
	await _reveal_intro_blocks()


func _set_intro_hidden_state() -> void:
	var essence_panel: Control = _ui._essence_counter.get_parent() if _ui._essence_counter and is_instance_valid(_ui._essence_counter) else null
	var hide_targets: Array = [
		_ui._top_status_bar, _ui.life_panel, _ui.souffle_panel, essence_panel,
		_ui.card_container, _ui._bottom_zone, _ui._pioche_column,
		_ui._cimetiere_column, _ui.options_container, _ui.info_panel,
	]
	for node in hide_targets:
		var target: Control = node as Control
		if target and is_instance_valid(target):
			target.modulate.a = 0.0


func _set_empty_center_card_state() -> void:
	_ui.current_card = {"id": "intro_placeholder", "_placeholder": true}
	if _ui._card_title_label and is_instance_valid(_ui._card_title_label):
		_ui._card_title_label.text = ""
		_ui._card_title_label.visible = false
	if _ui.card_speaker and is_instance_valid(_ui.card_speaker):
		_ui.card_speaker.text = ""
		_ui.card_speaker.visible = false
	if _ui.card_text and is_instance_valid(_ui.card_text):
		_ui.card_text.text = " "
	if _ui._card_source_badge and is_instance_valid(_ui._card_source_badge):
		_ui._card_source_badge.visible = false
	if _ui.card_panel and is_instance_valid(_ui.card_panel):
		_ui.card_panel.modulate.a = 1.0
		_ui.card_panel.scale = Vector2.ONE
		_ui.card_panel.rotation_degrees = 0.0
		_ui.card_panel.position = _ui._card_base_pos


func _reveal_empty_center_card() -> void:
	if not _ui.card_container or not is_instance_valid(_ui.card_container):
		return
	var tw: Tween = _ui.create_tween()
	tw.tween_property(_ui.card_container, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _reveal_intro_blocks() -> void:
	var essence_panel: Control = _ui._essence_counter.get_parent() if _ui._essence_counter and is_instance_valid(_ui._essence_counter) else null
	var reveal_targets: Array = [_ui._top_status_bar, _ui._bottom_zone, _ui._pioche_column, _ui._cimetiere_column, _ui.card_container, _ui.info_panel, _ui.life_panel, _ui.souffle_panel, essence_panel]
	for i in range(reveal_targets.size()):
		var target: Control = reveal_targets[i] as Control
		if not target or not is_instance_valid(target):
			continue
		var tw: Tween = _ui.create_tween()
		tw.tween_property(target, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_delay(0.05 * float(i))
	await _ui.get_tree().create_timer(0.45).timeout


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME ARTWORK
# ═══════════════════════════════════════════════════════════════════════════════

func normalize_biome_key(biome_key: String) -> String:
	var key: String = str(biome_key).strip_edges().to_lower()
	if MerlinVisual.BIOME_ART_PROFILES.has(key):
		return key
	if BIOME_SHORT_NAMES.has(key):
		return str(BIOME_SHORT_NAMES[key])
	return "broceliande"


func normalize_season(season_hint: String, biome_key: String) -> String:
	var season: String = str(season_hint).strip_edges().to_lower()
	if season == "automn":
		season = "automne"
	if MerlinVisual.SEASON_TINTS.has(season):
		return season
	return str(BIOME_DEFAULT_SEASON.get(biome_key, "automne"))


func _tone_color(base: Color, hour_light: Color, season_tint: Color) -> Color:
	return Color(
		clampf(base.r * hour_light.r * season_tint.r, 0.0, 1.0),
		clampf(base.g * hour_light.g * season_tint.g, 0.0, 1.0),
		clampf(base.b * hour_light.b * season_tint.b, 0.0, 1.0),
		1.0
	)


func _hour_light_color(hour: int) -> Color:
	var h: int = clampi(hour, 0, 23)
	var daylight: float = (cos((float(h) - 12.0) * PI / 12.0) + 1.0) * 0.5
	var base: float = lerpf(0.38, 1.0, daylight)
	var blue_boost: float = lerpf(1.09, 0.96, daylight)
	return Color(base, base * 0.98, base * blue_boost, 1.0)


func build_biome_artwork(biome_key: String, season_key: String, hour: int) -> void:
	if not _ui.biome_art_layer or not is_instance_valid(_ui.biome_art_layer):
		return
	for child in _ui.biome_art_layer.get_children():
		child.queue_free()
	_biome_art_pixels.clear()

	var profile: Dictionary = MerlinVisual.BIOME_ART_PROFILES.get(biome_key, MerlinVisual.BIOME_ART_PROFILES.broceliande)
	var season_tint: Color = MerlinVisual.SEASON_TINTS.get(season_key, Color.WHITE)
	var hour_light: Color = _hour_light_color(hour)
	var sky_color: Color = _tone_color(profile.sky, hour_light, season_tint)
	var mist_color: Color = _tone_color(profile.mist, hour_light, season_tint)
	var mid_color: Color = _tone_color(profile.mid, hour_light, season_tint)
	var accent_color: Color = _tone_color(profile.accent, hour_light, season_tint)
	var foreground_color: Color = _tone_color(profile.foreground, hour_light, season_tint)

	var vp: Vector2 = _ui.get_viewport_rect().size
	var pixel_size: float = floor(minf(vp.x / float(INTRO_PIXEL_COLS), vp.y / float(INTRO_PIXEL_ROWS)))
	pixel_size = clampf(pixel_size, 6.0, 20.0)
	var total_w: float = float(INTRO_PIXEL_COLS) * pixel_size
	var total_h: float = float(INTRO_PIXEL_ROWS) * pixel_size
	var origin: Vector2 = Vector2((vp.x - total_w) * 0.5, (vp.y - total_h) * 0.46)

	_add_biome_block(0, 0, INTRO_PIXEL_COLS, 18, sky_color, origin, pixel_size)
	_add_biome_block(0, 18, INTRO_PIXEL_COLS, 10, mist_color, origin, pixel_size)
	_add_biome_block(0, 28, INTRO_PIXEL_COLS, INTRO_PIXEL_ROWS - 28, mid_color.darkened(0.10), origin, pixel_size)

	for x in range(INTRO_PIXEL_COLS):
		var wave: float = sin(float(x) * 0.21) * 2.6 + cos(float(x) * 0.09) * 1.7
		var ridge_h: int = 5 + int(abs(wave))
		_add_biome_block(x, 30 - ridge_h, 1, ridge_h + 1, mid_color, origin, pixel_size)

	for x in range(INTRO_PIXEL_COLS):
		var ground_h: int = 6 + int(abs(sin(float(x) * 0.19)) * 2.0)
		_add_biome_block(x, INTRO_PIXEL_ROWS - ground_h, 1, ground_h, foreground_color, origin, pixel_size)

	_add_biome_feature_blocks(biome_key, origin, pixel_size, accent_color, foreground_color)
	_ui.biome_art_layer.modulate = Color.WHITE


func _add_biome_feature_blocks(biome_key: String, origin: Vector2, pixel_size: float, accent_color: Color, foreground_color: Color) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(hash("%s_%d" % [biome_key, int(Time.get_unix_time_from_system() / 1800)]))
	var trunk_color: Color = foreground_color.lightened(0.08)
	var detail_color: Color = accent_color.darkened(0.12)

	match biome_key:
		"broceliande":
			for i in range(28):
				var col: int = rng.randi_range(2, INTRO_PIXEL_COLS - 3)
				var trunk_h: int = rng.randi_range(5, 10)
				var canopy_w: int = rng.randi_range(3, 5)
				_add_biome_block(col, INTRO_PIXEL_ROWS - 6 - trunk_h, 1, trunk_h, trunk_color, origin, pixel_size)
				_add_biome_block(col - int(canopy_w / 2), INTRO_PIXEL_ROWS - 8 - trunk_h, canopy_w, 2, detail_color, origin, pixel_size)
		"landes":
			for i in range(40):
				var col: int = rng.randi_range(1, INTRO_PIXEL_COLS - 2)
				var h: int = rng.randi_range(1, 3)
				_add_biome_block(col, INTRO_PIXEL_ROWS - 7 - h, 1, h, detail_color, origin, pixel_size)
		"cotes":
			_add_biome_block(0, INTRO_PIXEL_ROWS - 7, INTRO_PIXEL_COLS, 2, accent_color.lightened(0.08), origin, pixel_size)
			for i in range(20):
				var col: int = rng.randi_range(4, INTRO_PIXEL_COLS - 6)
				var cliff_h: int = rng.randi_range(4, 9)
				_add_biome_block(col, INTRO_PIXEL_ROWS - 9 - cliff_h, 1, cliff_h, trunk_color, origin, pixel_size)
		"villages":
			for i in range(8):
				var col: int = 4 + i * 9
				_add_biome_block(col, INTRO_PIXEL_ROWS - 12, 5, 4, trunk_color, origin, pixel_size)
				_add_biome_block(col + 1, INTRO_PIXEL_ROWS - 14, 3, 2, detail_color, origin, pixel_size)
		"cercles":
			for i in range(12):
				var angle: float = TAU * float(i) / 12.0
				var col: int = int(INTRO_PIXEL_COLS * 0.5 + cos(angle) * 14.0)
				var row: int = int(INTRO_PIXEL_ROWS * 0.68 + sin(angle) * 4.0)
				_add_biome_block(col, row, 1, 4, trunk_color.lightened(0.12), origin, pixel_size)
		"marais":
			for i in range(10):
				var col: int = rng.randi_range(2, INTRO_PIXEL_COLS - 8)
				var row: int = rng.randi_range(INTRO_PIXEL_ROWS - 9, INTRO_PIXEL_ROWS - 5)
				_add_biome_block(col, row, rng.randi_range(4, 8), 1, accent_color.lightened(0.12), origin, pixel_size)
		"collines":
			for i in range(3):
				var base_col: int = 8 + i * 22
				_add_biome_block(base_col, INTRO_PIXEL_ROWS - 12, 8, 4, trunk_color, origin, pixel_size)
				_add_biome_block(base_col + 2, INTRO_PIXEL_ROWS - 14, 4, 2, detail_color, origin, pixel_size)
		_:
			for i in range(24):
				_add_biome_block(rng.randi_range(1, INTRO_PIXEL_COLS - 2), INTRO_PIXEL_ROWS - rng.randi_range(5, 12), 1, rng.randi_range(2, 5), detail_color, origin, pixel_size)


func _add_biome_block(col: int, row: int, width: int, height: int, color: Color, origin: Vector2, pixel_size: float) -> void:
	var c: int = maxi(col, 0)
	var r: int = maxi(row, 0)
	var w: int = mini(width, INTRO_PIXEL_COLS - c)
	var h: int = mini(height, INTRO_PIXEL_ROWS - r)
	if w <= 0 or h <= 0:
		return
	var block: ColorRect = ColorRect.new()
	block.size = Vector2(float(w) * pixel_size, float(h) * pixel_size)
	block.position = origin + Vector2(float(c) * pixel_size, float(r) * pixel_size)
	block.color = color
	block.modulate.a = 0.0
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.biome_art_layer.add_child(block)
	_biome_art_pixels.append(block)


func _animate_biome_artwork_stack() -> void:
	if _biome_art_pixels.is_empty():
		return
	var ordered: Array = _biome_art_pixels.duplicate()
	ordered.sort_custom(func(a: ColorRect, b: ColorRect) -> bool:
		return a.position.y > b.position.y
	)

	for i in range(ordered.size()):
		var px: ColorRect = ordered[i]
		if not is_instance_valid(px):
			continue
		var target: Vector2 = px.position
		px.position = target + Vector2(randf_range(-3.0, 3.0), randf_range(10.0, 24.0))
		px.modulate.a = 0.0
		var tw: Tween = _ui.create_tween()
		tw.tween_property(px, "modulate:a", 1.0, 0.16)
		tw.parallel().tween_property(px, "position", target, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if i % INTRO_STACK_BATCH == INTRO_STACK_BATCH - 1:
			await _ui.get_tree().create_timer(INTRO_STACK_STEP).timeout

	var pulse: Tween = _ui.create_tween()
	pulse.tween_property(_ui.biome_art_layer, "modulate", Color(1.06, 1.06, 1.06), 0.14)
	pulse.tween_property(_ui.biome_art_layer, "modulate", Color.WHITE, 0.14)
	await pulse.finished


func _dim_biome_background() -> void:
	if not _ui.biome_art_layer or not is_instance_valid(_ui.biome_art_layer):
		return
	_ui.biome_art_layer.visible = true
	var tw: Tween = _ui.create_tween()
	tw.tween_property(_ui.biome_art_layer, "modulate:a", 0.80, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_start_biome_breathing()


func _start_biome_breathing() -> void:
	if not _ui.biome_art_layer or not is_instance_valid(_ui.biome_art_layer):
		return
	if _biome_breath_tween:
		_biome_breath_tween.kill()
	_biome_breath_tween = _ui.create_tween().set_loops()
	_biome_breath_tween.tween_property(_ui.biome_art_layer, "modulate:a", 0.95, 4.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_biome_breath_tween.tween_property(_ui.biome_art_layer, "modulate:a", 0.80, 4.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_deck_assembly(_biome_key: String) -> void:
	## Disabled — deck assembly animation removed (2026-02-26).
	return


# ═══════════════════════════════════════════════════════════════════════════════
# AMBIENT VFX
# ═══════════════════════════════════════════════════════════════════════════════

func start_ambient_vfx(biome_key: String) -> void:
	_ambient_biome_key = biome_key
	if _ambient_timer:
		_ambient_timer.queue_free()
	_ambient_timer = Timer.new()
	_ambient_timer.wait_time = 1.2
	_ambient_timer.autostart = true
	_ambient_timer.timeout.connect(_spawn_ambient_particle)
	_ui.add_child(_ambient_timer)


func _spawn_ambient_particle() -> void:
	if _ambient_particles.size() >= MAX_AMBIENT_PARTICLES or not _ui.is_inside_tree():
		return
	var vp: Vector2 = _ui.get_viewport_rect().size
	var px: ColorRect = ColorRect.new()
	px.size = Vector2(randf_range(3.0, 5.0), randf_range(3.0, 5.0))
	px.mouse_filter = Control.MOUSE_FILTER_IGNORE
	px.z_index = -1
	px.modulate.a = randf_range(0.15, 0.35)

	var start_pos: Vector2 = Vector2.ZERO
	var end_pos: Vector2 = Vector2.ZERO
	var duration: float = randf_range(4.0, 7.0)

	var key: String = _ambient_biome_key.replace("foret_", "").replace("landes_", "") \
		.replace("cotes_", "").replace("villages_", "").replace("cercles_", "") \
		.replace("marais_", "").replace("collines_", "")

	match key:
		"broceliande":
			px.color = [MerlinVisual.CRT_PALETTE["particle_leaf_green"], MerlinVisual.CRT_PALETTE["particle_leaf_brown"]][randi() % 2]
			start_pos = Vector2(randf_range(0, vp.x), -10)
			end_pos = start_pos + Vector2(randf_range(-60, 60), vp.y + 20)
		"bruyere":
			px.color = MerlinVisual.CRT_PALETTE["particle_dust_purple"]
			start_pos = Vector2(-10, randf_range(vp.y * 0.3, vp.y * 0.8))
			end_pos = Vector2(vp.x + 10, start_pos.y + randf_range(-30, 30))
			duration = randf_range(3.0, 5.0)
		"sauvages":
			px.color = MerlinVisual.CRT_PALETTE["particle_mist_blue"]
			start_pos = Vector2(randf_range(0, vp.x), vp.y + 10)
			end_pos = start_pos + Vector2(randf_range(-20, 20), -vp.y * 0.4)
		"celtes":
			px.color = MerlinVisual.CRT_PALETTE["particle_smoke_gray"]
			start_pos = Vector2(randf_range(vp.x * 0.3, vp.x * 0.7), vp.y + 10)
			end_pos = start_pos + Vector2(randf_range(-15, 15), -vp.y * 0.5)
		"pierres":
			px.color = MerlinVisual.CRT_PALETTE["particle_firefly"]
			px.size = Vector2(3, 3)
			start_pos = Vector2(randf_range(vp.x * 0.1, vp.x * 0.9), randf_range(vp.y * 0.2, vp.y * 0.8))
			end_pos = start_pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))
			duration = randf_range(2.0, 4.0)
		"korrigans":
			px.color = MerlinVisual.CRT_PALETTE["particle_phosphor"]
			start_pos = Vector2(randf_range(0, vp.x), vp.y * randf_range(0.6, 0.95))
			end_pos = start_pos + Vector2(randf_range(-25, 25), randf_range(-20, -50))
			duration = randf_range(3.0, 5.0)
		"dolmens":
			px.color = MerlinVisual.CRT_PALETTE["particle_grass"]
			start_pos = Vector2(randf_range(0, vp.x), vp.y * randf_range(0.7, 0.95))
			end_pos = start_pos + Vector2(randf_range(-20, 20), randf_range(-10, 10))
			duration = randf_range(2.0, 4.0)
		_:
			px.color = MerlinVisual.CRT_PALETTE["particle_mote"]
			start_pos = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
			end_pos = start_pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))

	px.position = start_pos
	_ui.add_child(px)
	_ambient_particles.append(px)

	var tw: Tween = _ui.create_tween()
	tw.tween_property(px, "position", end_pos, duration).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(px, "modulate:a", 0.0, duration * 0.8).set_delay(duration * 0.2)
	tw.tween_callback(func():
		_ambient_particles.erase(px)
		if is_instance_valid(px):
			px.queue_free()
	)


func flash_biome_for_outcome(outcome: String) -> void:
	if not _ui.biome_art_layer or not is_instance_valid(_ui.biome_art_layer):
		return
	var is_success: bool = outcome.contains("success")
	var intensity: float = 1.6 if outcome.contains("critical") else 1.3
	var tint: Color = Color(0.7, intensity, 0.7) if is_success else Color(intensity, 0.7, 0.7)
	var tw: Tween = _ui.create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_ui.biome_art_layer, "modulate", tint, 0.12)
	tw.tween_property(_ui.biome_art_layer, "modulate", Color.WHITE, 0.25)
