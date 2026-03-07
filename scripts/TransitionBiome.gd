## ═══════════════════════════════════════════════════════════════════════════════
## Transition Biome — "Paysage Pixel Émergent"
## ═══════════════════════════════════════════════════════════════════════════════
## 6-phase travel animation: Brume → Émergence → Révélation → Sentier → Voix → Dissolution
## Each biome has a unique pixel-art landscape (32×16) assembled by cascading pixels.
## ═══════════════════════════════════════════════════════════════════════════════

extends Control

const NEXT_SCENE := "res://scenes/MerlinGame.tscn"
const DATA_PATH := "res://data/post_intro_dialogues.json"

const ANIMATION_SPEED_FACTOR := 1.7
const TYPEWRITER_DELAY := 0.016
const TYPEWRITER_PUNCT_DELAY := 0.045
const BLIP_VOLUME := 0.04
const LLM_POLL_INTERVAL := 0.12
const PREFETCH_WAIT_MAX := 6.0
const PREFETCH_SENTIER_WAIT_MAX := 3.0
const MAX_ADVANCE_WAIT := 16.0
const WEATHER_CLEAR := "clear"
const WEATHER_CLOUDY := "cloudy"
const WEATHER_RAIN := "rain"
const WEATHER_STORM := "storm"
const WEATHER_MIST := "mist"
const WEATHER_SNOW := "snow"

const GRID_W := 32
const GRID_H := 16

# Quest preparation — pre-generate cards with tree animation
const QUEST_TREE_W := 10
const QUEST_TREE_H := 14
const PRERUN_CARD_COUNT := 5
const PRERUN_CARDS_PATH := "user://temp_run_cards.json"

# PALETTE constant removed — using MerlinVisual.CRT_PALETTE autoload

# Biome-specific fog tint and behavior (lazy init — autoloads not available at const time)
var _fog_config: Dictionary = {}

func _get_fog_config() -> Dictionary:
	if _fog_config.is_empty():
		_fog_config = {
			"broceliande": {"tint": MerlinVisual.CRT_PALETTE.mist.lightened(0.05), "direction": Vector3(-0.5, -0.3, 0), "speed": 0.7},
			"landes": {"tint": MerlinVisual.CRT_PALETTE.mist, "direction": Vector3(-1, 0.1, 0), "speed": 1.3},
			"cotes": {"tint": MerlinVisual.CRT_PALETTE.mist.lightened(0.08), "direction": Vector3(-1, 0, 0), "speed": 1.5},
			"villages": {"tint": MerlinVisual.CRT_PALETTE.bg_panel, "direction": Vector3(0, -1, 0), "speed": 0.5},
			"cercles": {"tint": MerlinVisual.CRT_PALETTE.bg_panel.darkened(0.05), "direction": Vector3(0, 0, 0), "speed": 0.3},
			"marais": {"tint": MerlinVisual.CRT_PALETTE.mist.lightened(0.02), "direction": Vector3(-0.3, 0.5, 0), "speed": 0.6},
			"collines": {"tint": MerlinVisual.CRT_PALETTE.bg_panel.lightened(0.02), "direction": Vector3(-0.7, -0.2, 0), "speed": 0.9},
			"iles": {"tint": MerlinVisual.CRT_PALETTE.mist.lightened(0.10), "direction": Vector3(-0.6, 0.2, 0), "speed": 1.1},
		}
	return _fog_config

# ═══════════════════════════════════════════════════════════════════════════════
# SCENE NODES (@onready)
# ═══════════════════════════════════════════════════════════════════════════════

@onready var bg: ColorRect = $Bg
@onready var pixel_container: Control = $PixelContainer
@onready var biome_title: Label = $BiomeTitle
@onready var biome_subtitle: Label = $BiomeSubtitle
@onready var arrival_text: RichTextLabel = $ArrivalText
@onready var merlin_comment: RichTextLabel = $MerlinComment
@onready var _weather_overlay: ColorRect = $WeatherOverlay
@onready var _clock_panel: PanelContainer = $ClockPanel
@onready var _clock_label: Label = $ClockPanel/ClockLabel
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

# Dynamic nodes (created at runtime)

# Weather state
var _weather_mode: String = ""
var _weather_check_timer: float = 0.0
var _weather_light_factor: float = 1.0
var _weather_tween: Tween
var _storm_flash_timer: float = 0.0
var _solar_arc: Line2D
var _solar_arc_points: PackedVector2Array = PackedVector2Array()
var _weather_rng := RandomNumberGenerator.new()

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var biome_key: String = ""
var biome_data: Dictionary = {}
var biomes_all: Dictionary = {}
var typing_active: bool = false
var typing_abort: bool = false
var scene_finished: bool = false
var _advance_requested: bool = false
var _landscape_pixels: Array = []
var _pixel_size: float = 10.0
var _landscape_origin: Vector2 = Vector2.ZERO
var _current_grid: Array = []

# Voicebox
var voicebox: Node = null
var voice_ready: bool = false
# LLM
var merlin_ai: Node = null
# LLM Prefetch state — dealer monologue (Hand of Fate 2 style)
var _prefetch_monologue: Dictionary = {}
var _seen_variants: Dictionary = {}
var _last_monologue_text: String = ""

# Quest preparation state
var _quest_button: Button = null
var _quest_tree_container: Control = null
var _quest_tree_pixel_nodes: Array = []
var _quest_progress_label: Label = null
var _prerun_cards: Array = []
var _cards_generated: bool = false


func _exit_tree() -> void:
	# Kill any active tweens to prevent "data.tree is null" errors
	scene_finished = true
	typing_abort = true
	_clear_merlin_scene_context()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_weather_rng.seed = int(Time.get_unix_time_from_system())
	_load_data()
	_current_grid = _generate_landscape(biome_key)
	_configure_ui()
	_configure_audio()
	await _setup_voicebox()
	if not is_inside_tree():
		return
	await _safe_wait(0.3)
	if not is_inside_tree():
		return
	_play_transition()


func _process(delta: float) -> void:
	if scene_finished:
		return
	_weather_check_timer += delta
	if _weather_check_timer >= 1.0:
		_weather_check_timer = 0.0
		var now: Dictionary = Time.get_datetime_dict_from_system()
		_apply_weather_for_hour(int(now.get("hour", 12)), false)
	_update_solar_clock(false)
	if _weather_mode == WEATHER_STORM:
		_storm_flash_timer -= delta
		if _storm_flash_timer <= 0.0 and _weather_overlay and is_instance_valid(_weather_overlay):
			var flash_strength := _weather_rng.randf_range(0.06, 0.16)
			_weather_overlay.color = _weather_overlay.color.lightened(flash_strength)
			_storm_flash_timer = _weather_rng.randf_range(1.8, 4.8)


## Safe helpers — prevent crashes when node exits tree during await
func _safe_wait(seconds: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(maxf(0.01, seconds / ANIMATION_SPEED_FACTOR)).timeout

func _safe_frame() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame


## Full key → short key mapping (HubAntre uses full keys, TransitionBiome uses short)
const BIOME_KEY_MAP := {
	"foret_broceliande": "broceliande",
	"landes_bruyere": "landes",
	"cotes_sauvages": "cotes",
	"villages_celtes": "villages",
	"cercles_pierres": "cercles",
	"marais_korrigans": "marais",
	"collines_dolmens": "collines",
	"iles_mystiques": "iles",
}


func _load_data() -> void:
	merlin_ai = get_node_or_null("/root/MerlinAI")
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var run_data: Dictionary = gm.get("run") if gm.get("run") is Dictionary else {}
		var raw_key: String = run_data.get("current_biome", "broceliande")
		# Normalize full biome keys to short keys used by MerlinVisual.BIOME_COLORS and _generate_landscape
		biome_key = BIOME_KEY_MAP.get(raw_key, raw_key)
	# Apply biome CRT profile (phosphor tint + distortion)
	MerlinVisual.apply_biome_crt(biome_key)

	if FileAccess.file_exists(DATA_PATH):
		var file := FileAccess.open(DATA_PATH, FileAccess.READ)
		var json := JSON.new()
		var err := json.parse(file.get_as_text())
		file.close()
		if err == OK:
			var data: Dictionary = json.data
			biomes_all = data.get("biomes", {})

	# Try both short and full keys for biome dialogue data
	biome_data = biomes_all.get(biome_key, {})
	if biome_data.is_empty():
		# Try full key lookup in case dialogue data uses full keys
		for full_key in BIOME_KEY_MAP:
			if BIOME_KEY_MAP[full_key] == biome_key:
				biome_data = biomes_all.get(full_key, {})
				break
	if biome_data.is_empty():
		biome_data = {
			"name": "Terre Inconnue",
			"subtitle": "L'Inconnu",
			"arrival_text": "Tu arrives dans un lieu etrange.",
			"merlin_comment": "Eh bien. C'est... quelque chose.",
			"color": "#787870",
		}


func _set_merlin_scene_context(scene_id: String, overrides: Dictionary = {}) -> void:
	if merlin_ai == null or not merlin_ai.has_method("set_scene_context"):
		return
	var payload: Dictionary = {
		"biome": biome_key,
		"biome_name": str(biome_data.get("name", biome_key))
	}
	for key in overrides.keys():
		payload[key] = overrides[key]
	merlin_ai.set_scene_context(scene_id, payload)


func _clear_merlin_scene_context() -> void:
	if merlin_ai and merlin_ai.has_method("clear_scene_context"):
		merlin_ai.clear_scene_context()


func _configure_ui() -> void:
	var vs := get_viewport_rect().size

	# CRT terminal background
	bg.material = null
	bg.color = MerlinVisual.CRT_PALETTE.bg_dark

	# Configure celtic ornaments
	_configure_celtic_ornament($CelticTop, Vector2(0, 20), Vector2(vs.x, 30))
	_configure_celtic_ornament($CelticBottom, Vector2(0, vs.y - 50), Vector2(vs.x, 30))

	# Configure weather + solar clock overlay
	_configure_weather_system()

	# Load fonts from MerlinVisual
	var title_font: Font = MerlinVisual.get_font("title")
	var body_font: Font = MerlinVisual.get_font("body")
	if body_font == null:
		body_font = title_font

	# Configure biome title
	biome_title.text = biome_data.get("name", "")
	biome_title.position = Vector2(vs.x / 2.0 - 300, 55)
	biome_title.size = Vector2(600, 50)
	var biome_color_str = biome_data.get("color", "")
	var font_color: Color = MerlinVisual.CRT_PALETTE.amber
	if biome_color_str is String and biome_color_str != "":
		font_color = Color(biome_color_str)
	elif biome_color_str is Color:
		font_color = biome_color_str
	biome_title.add_theme_color_override("font_color", font_color)
	if title_font:
		biome_title.add_theme_font_override("font", title_font)

	# Configure subtitle
	biome_subtitle.text = biome_data.get("subtitle", "")
	biome_subtitle.position = Vector2(vs.x / 2.0 - 300, 95)
	biome_subtitle.size = Vector2(600, 30)
	biome_subtitle.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	if body_font:
		biome_subtitle.add_theme_font_override("font", body_font)

	# Configure arrival text (sized for dealer monologue — 4-6 sentences)
	arrival_text.size = Vector2(680, 200)
	arrival_text.position = Vector2(vs.x / 2.0 - 340, vs.y * 0.65)
	arrival_text.add_theme_color_override("default_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	if body_font:
		arrival_text.add_theme_font_override("normal_font", body_font)
	arrival_text.add_theme_font_size_override("normal_font_size", 18)

	# Configure merlin comment
	merlin_comment.size = Vector2(600, 50)
	merlin_comment.position = Vector2(vs.x / 2.0 - 300, vs.y - 130)
	merlin_comment.add_theme_color_override("default_color", MerlinVisual.CRT_PALETTE.phosphor)
	if body_font:
		merlin_comment.add_theme_font_override("normal_font", body_font)
	merlin_comment.add_theme_font_size_override("normal_font_size", 20)

	# Configure audio volume
	audio_player.volume_db = linear_to_db(BLIP_VOLUME)


func _configure_celtic_ornament(lbl: Label, pos: Vector2, sz: Vector2) -> void:
	var pattern := ["\u2500", "\u2022", "\u2500", "\u2500", "#", "\u2500", "\u2500", "\u2022", "\u2500"]
	var line := ""
	for i in range(40):
		line += pattern[i % pattern.size()]
	lbl.text = line
	lbl.position = pos
	lbl.size = sz
	lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)


func _configure_weather_system() -> void:
	## Configure weather overlay + solar clock from scene nodes.

	var base_overlay: Color = MerlinVisual.CRT_PALETTE.phosphor
	_weather_overlay.color = Color(base_overlay.r, base_overlay.g, base_overlay.b, 0.06)

	# Style clock panel
	var clock_style := StyleBoxFlat.new()
	var clock_bg: Color = MerlinVisual.CRT_PALETTE.bg_dark
	var clock_border: Color = MerlinVisual.CRT_PALETTE.souffle
	clock_style.bg_color = Color(clock_bg.r, clock_bg.g, clock_bg.b, 0.9)
	clock_style.border_color = Color(clock_border.r, clock_border.g, clock_border.b, 0.85)
	clock_style.set_border_width_all(1)
	clock_style.set_corner_radius_all(6)
	clock_style.content_margin_left = 10
	clock_style.content_margin_right = 10
	clock_style.content_margin_top = 4
	clock_style.content_margin_bottom = 3
	_clock_panel.add_theme_stylebox_override("panel", clock_style)

	# Style clock label
	_clock_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)

	_layout_solar_arc_geometry()
	var initial_hour := int(Time.get_datetime_dict_from_system().get("hour", 12))
	_apply_weather_for_hour(initial_hour, true)
	_update_solar_clock(true)


func _layout_solar_arc_geometry() -> void:
	var vs := get_viewport_rect().size
	_solar_arc_points = PackedVector2Array()
	if _clock_panel and is_instance_valid(_clock_panel):
		_clock_panel.position = Vector2(vs.x * 0.5 - 52.0, 22.0)


func _current_time_float() -> float:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	return float(now.get("hour", 12)) + float(now.get("minute", 0)) / 60.0 + float(now.get("second", 0)) / 3600.0


func _sun_position_for_time(time_float: float) -> Vector2:
	var vs := get_viewport_rect().size
	var t := clampf(fposmod(time_float, 24.0) / 24.0, 0.0, 1.0)
	var margin := clampf(vs.x * 0.06, 40.0, 140.0)
	var x := lerpf(margin, vs.x - margin, t)
	var y := clampf(vs.y * 0.14, 48.0, 126.0)
	if _landscape_origin != Vector2.ZERO and _pixel_size > 0.0:
		var landscape_top := _landscape_origin.y - _pixel_size * 0.7
		y = minf(y, maxf(40.0, landscape_top - 18.0))
	return Vector2(x, y)


func _is_moon_hour(time_float: float) -> bool:
	var hour := int(floor(fposmod(time_float, 24.0)))
	return hour >= 22 or hour < 6


func _get_time_of_day_label(hour: int) -> String:
	if hour >= 6 and hour < 12:   return "Matin"
	if hour >= 12 and hour < 18:  return "Après-midi"
	if hour >= 18 and hour < 22:  return "Soir"
	return "Nuit"


func _get_current_season() -> String:
	var month: int = Time.get_datetime_dict_from_system().get("month", 1)
	if month >= 3 and month <= 5: return "printemps"
	if month >= 6 and month <= 8: return "ete"
	if month >= 9 and month <= 11: return "automne"
	return "hiver"


func _update_solar_clock(_instant: bool) -> void:
	_layout_solar_arc_geometry()
	var now: Dictionary = Time.get_datetime_dict_from_system()
	if _clock_label and is_instance_valid(_clock_label):
		_clock_label.text = _get_time_of_day_label(int(now.get("hour", 12)))


func _weather_mode_for_hour(hour: int) -> String:
	if hour >= 0 and hour < 5:
		return WEATHER_MIST
	if hour >= 5 and hour < 9:
		return WEATHER_CLEAR
	if hour >= 9 and hour < 13:
		return WEATHER_CLOUDY
	if hour >= 13 and hour < 17:
		return WEATHER_RAIN
	if hour >= 17 and hour < 21:
		return WEATHER_STORM
	if hour >= 21 and hour < 23:
		return WEATHER_CLOUDY
	return WEATHER_SNOW


func _apply_weather_for_hour(hour: int, instant: bool) -> void:
	_apply_weather_mode(_weather_mode_for_hour(hour), instant)


func _apply_weather_mode(mode: String, instant: bool) -> void:
	_weather_mode = mode
	var overlay_base: Color = MerlinVisual.CRT_PALETTE.phosphor
	var target_overlay := Color(overlay_base.r, overlay_base.g, overlay_base.b, 0.06)
	_weather_light_factor = 1.0

	match mode:
		WEATHER_CLEAR:
			target_overlay = Color(overlay_base.r * 0.7, overlay_base.g * 1.1, overlay_base.b * 1.35, 0.04)
			_weather_light_factor = 1.0
		WEATHER_CLOUDY:
			target_overlay = Color(overlay_base.r * 0.8, overlay_base.g * 1.1, overlay_base.b * 1.2, 0.12)
			_weather_light_factor = 0.9
		WEATHER_RAIN:
			target_overlay = Color(overlay_base.r * 0.7, overlay_base.g * 0.9, overlay_base.b * 1.05, 0.20)
			_weather_light_factor = 0.78
		WEATHER_STORM:
			target_overlay = Color(overlay_base.r * 0.45, overlay_base.g * 0.65, overlay_base.b * 0.78, 0.28)
			_weather_light_factor = 0.62
			_storm_flash_timer = _weather_rng.randf_range(1.2, 3.3)
		WEATHER_MIST:
			target_overlay = Color(overlay_base.r, overlay_base.g * 1.15, overlay_base.b * 1.05, 0.18)
			_weather_light_factor = 0.72
		WEATHER_SNOW:
			target_overlay = Color(overlay_base.r * 1.1, overlay_base.g * 1.3, overlay_base.b * 1.35, 0.16)
			_weather_light_factor = 0.8

	var light_color := Color(
		clampf(_weather_light_factor * 1.03, 0.60, 1.1),
		clampf(_weather_light_factor, 0.56, 1.06),
		clampf(_weather_light_factor * 1.08, 0.62, 1.14),
		1.0
	)

	if instant:
		if _weather_overlay and is_instance_valid(_weather_overlay):
			_weather_overlay.color = target_overlay
		if pixel_container and is_instance_valid(pixel_container):
			pixel_container.modulate = light_color
	else:
		if _weather_tween:
			_weather_tween.kill()
		_weather_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if _weather_overlay and is_instance_valid(_weather_overlay):
			_weather_tween.tween_property(_weather_overlay, "color", target_overlay, 1.2)
		if pixel_container and is_instance_valid(pixel_container):
			_weather_tween.parallel().tween_property(pixel_container, "modulate", light_color, 1.2)


func _configure_audio() -> void:
	# Audio player is already in the scene — nothing extra needed
	pass


func _setup_voicebox() -> void:
	var script_path := "res://addons/acvoicebox/acvoicebox.gd"
	if ResourceLoader.exists(script_path):
		var scr = load(script_path)
		if scr:
			voicebox = scr.new()
			if voicebox:
				voicebox.set("sound_bank", "whisper")
				voicebox.set("base_pitch", 3.2)
				voicebox.set("pitch_variation", 0.15)
				voicebox.set("speed_scale", 0.85)
				add_child(voicebox)
				await _safe_frame()
				if voicebox.has_method("is_ready") and voicebox.is_ready():
					voice_ready = true
				else:
					voice_ready = false


# ═══════════════════════════════════════════════════════════════════════════════
# LANDSCAPE GENERATION — Procedural pixel-art grids
# ═══════════════════════════════════════════════════════════════════════════════

func _make_empty_grid() -> Array:
	var g: Array = []
	for y in range(GRID_H):
		var row: Array = []
		for x in range(GRID_W):
			row.append(0)
		g.append(row)
	return g


func _grid_set(g: Array, x: int, y: int, c: int) -> void:
	if y >= 0 and y < GRID_H and x >= 0 and x < GRID_W:
		g[y][x] = c


func _grid_rect(g: Array, x0: int, y0: int, w: int, h: int, c: int) -> void:
	for dy in range(h):
		for dx in range(w):
			_grid_set(g, x0 + dx, y0 + dy, c)


func _grid_triangle(g: Array, cx: int, top_y: int, base_y: int, max_w: int, c: int) -> void:
	if base_y <= top_y:
		return
	var height := base_y - top_y
	for dy in range(height + 1):
		var y := top_y + dy
		var t := float(dy) / float(height)
		var half := int(t * float(max_w) / 2.0)
		for dx in range(-half, half + 1):
			_grid_set(g, cx + dx, y, c)


func _grid_hill(g: Array, cx: int, base_y: int, rx: int, ry: int, c: int) -> void:
	for dx in range(-rx, rx + 1):
		var norm := float(dx) / float(rx)
		var val := 1.0 - norm * norm
		if val <= 0.0:
			continue
		var h := int(float(ry) * sqrt(val))
		for dy in range(h):
			_grid_set(g, cx + dx, base_y - dy, c)


func _grid_dots(g: Array, positions: Array, c: int) -> void:
	for pos in positions:
		_grid_set(g, pos[0], pos[1], c)


func _generate_landscape(biome: String) -> Array:
	var g := _make_empty_grid()
	match biome:
		"broceliande":
			_gen_broceliande(g)
		"landes":
			_gen_landes(g)
		"cotes":
			_gen_cotes(g)
		"villages":
			_gen_villages(g)
		"cercles":
			_gen_cercles(g)
		"marais":
			_gen_marais(g)
		"collines":
			_gen_collines(g)
		"iles":
			_gen_iles(g)
		_:
			_gen_broceliande(g)
	return g


func _gen_broceliande(g: Array) -> void:
	## Dense ancient forest — 100% pixel density, entire 32×16 grid filled.
	## Layout: canopy tips (0-1), dense canopy (2-5), body+trunks (6-9),
	##         understory (10-11), ground (12-13), earth (14-15)
	for row in range(GRID_H):
		for col in range(GRID_W):
			var c: int
			if row <= 1:
				# Canopy tips — primary with accent highlights
				c = 3 if (col * 3 + row * 7) % 11 == 0 else 1
			elif row <= 5:
				# Dense canopy — primary dominant, accent sparse
				c = 3 if (col + row * 2) % 9 == 0 else 1
			elif row <= 9:
				# Body — primary + secondary trunk columns
				if col in [5, 12, 13, 17, 22, 23, 29]:
					c = 2  # trunk/bark
				else:
					c = 1 if (col * 2 + row) % 7 != 0 else 3
			elif row <= 11:
				# Understory — secondary/bark + primary mix
				c = 2 if col % 3 == 0 else 1
			elif row <= 13:
				# Ground — secondary (dark moss/soil) + accent stones
				c = 3 if (col * 2 + row * 5) % 13 == 0 else 2
			else:
				# Earth — pure secondary
				c = 2
			_grid_set(g, col, row, c)


func _get_broceliande_stages() -> Array:
	## Returns 5 progressive growth stages for a dense Broceliande forest.
	## Each stage = Array of [col, row, color_key].
	## "p" = primary (leaves), "s" = secondary (trunk/bark), "a" = accent (details).
	return [
		# Stage 1: Ground + moss + stones
		_broceliande_stage_ground(),
		# Stage 2: Tree trunks + roots emerge
		_broceliande_stage_trunks(),
		# Stage 3: Lower branches + understory bushes
		_broceliande_stage_branches(),
		# Stage 4: Dense canopy connecting between trees
		_broceliande_stage_canopy(),
		# Stage 5: Details — mushrooms, flowers, fireflies
		_broceliande_stage_details(),
	]


func _broceliande_stage_ground() -> Array:
	var px: Array = []
	# Full-width mossy ground (rows 12-15)
	for x in range(GRID_W):
		for y in range(12, 16):
			px.append([x, y, "s"])
	# Stones scattered on ground
	for pos in [[3, 12], [10, 12], [19, 12], [27, 12]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _broceliande_stage_trunks() -> Array:
	var px: Array = []
	# 6 trunks of varying heights emerging from ground
	# Trunk 1 — large oak center-left
	for y in range(5, 12):
		px.append([12, y, "s"])
		px.append([13, y, "s"])
	# Trunk 2 — large oak center-right
	for y in range(4, 12):
		px.append([22, y, "s"])
		px.append([23, y, "s"])
	# Trunk 3 — medium left
	for y in range(6, 12):
		px.append([5, y, "s"])
	# Trunk 4 — medium right
	for y in range(7, 12):
		px.append([29, y, "s"])
	# Trunk 5 — small between
	for y in range(8, 12):
		px.append([17, y, "s"])
	# Trunk 6 — small far-left
	for y in range(9, 12):
		px.append([1, y, "s"])
	# Roots spreading at base
	for pos in [[11, 11], [14, 11], [21, 11], [24, 11], [4, 11], [6, 11], [28, 11], [30, 11]]:
		px.append([pos[0], pos[1], "s"])
	return px


func _broceliande_stage_branches() -> Array:
	var px: Array = []
	# Lower branches spreading from trunks
	# Oak 1 (center-left) branches
	for x in range(9, 16):
		px.append([x, 5, "p"])
		px.append([x, 6, "p"])
	# Oak 2 (center-right) branches
	for x in range(19, 27):
		px.append([x, 4, "p"])
		px.append([x, 5, "p"])
	# Medium tree left branches
	for x in range(3, 8):
		px.append([x, 6, "p"])
		px.append([x, 7, "p"])
	# Medium tree right branches
	for x in range(27, 31):
		px.append([x, 7, "p"])
	# Understory bushes between trees
	for x in range(7, 11):
		px.append([x, 10, "p"])
		px.append([x, 11, "p"])
	for x in range(15, 19):
		px.append([x, 10, "p"])
		px.append([x, 11, "p"])
	for x in range(25, 28):
		px.append([x, 10, "p"])
	return px


func _broceliande_stage_canopy() -> Array:
	var px: Array = []
	# Dense canopy — fills gaps between trees creating a continuous green mass
	# Known trunk columns (from _broceliande_stage_trunks) — skip when filling canopy
	var trunk_cols: Array = [1, 5, 12, 13, 17, 22, 23, 29]
	# Upper canopy row 1-3 (nearly full width)
	for x in range(2, 30):
		px.append([x, 2, "p"])
		px.append([x, 3, "p"])
	# Mid canopy row 4 (full connecting canopy)
	for x in range(1, 31):
		px.append([x, 4, "p"])
	# Canopy extensions at row 5 — skip trunk positions
	for x in range(0, GRID_W):
		if not trunk_cols.has(x):
			px.append([x, 5, "p"])
	# Fill remaining gaps at row 6-9 between trunks (sparse for natural look)
	for x in range(0, GRID_W):
		for y in range(6, 10):
			if not trunk_cols.has(x) and (x + y) % 3 != 0:
				px.append([x, y, "p"])
	# Canopy crown peaks
	for pos in [[8, 1], [9, 1], [14, 0], [15, 0], [20, 1], [21, 1], [25, 1]]:
		px.append([pos[0], pos[1], "p"])
	return px


func _broceliande_stage_details() -> Array:
	var px: Array = []
	# Mushrooms (glowing)
	for pos in [[2, 13], [9, 14], [16, 13], [24, 14], [30, 13]]:
		px.append([pos[0], pos[1], "a"])
	# Flowers
	for pos in [[6, 12], [14, 12], [20, 12], [26, 12]]:
		px.append([pos[0], pos[1], "a"])
	# Fireflies / light particles in canopy
	for pos in [[4, 3], [11, 2], [18, 1], [25, 3], [7, 5], [22, 4], [15, 3], [28, 2]]:
		px.append([pos[0], pos[1], "a"])
	# Hanging vines from canopy
	for pos in [[8, 8], [8, 9], [16, 8], [16, 9], [26, 8]]:
		px.append([pos[0], pos[1], "p"])
	return px


func _gen_landes(g: Array) -> void:
	# Heather moors — lone menhir on rolling hills
	# Menhir (standing stone)
	_grid_set(g, 15, 2, 1)
	_grid_set(g, 16, 2, 1)
	_grid_rect(g, 14, 3, 3, 6, 1)
	# Rolling hills
	_grid_hill(g, 11, 11, 13, 3, 2)
	_grid_hill(g, 25, 11, 10, 2, 2)
	# Heather ground
	_grid_rect(g, 0, 12, GRID_W, 2, 1)
	# Heather flowers
	_grid_dots(g, [[1, 14], [4, 14], [7, 14], [10, 14], [13, 14],
		[16, 14], [19, 14], [22, 14], [25, 14], [28, 14], [31, 14]], 3)


func _gen_cotes(g: Array) -> void:
	# Sea cliffs — cliff face left, waves right
	# Cliff body (stepped descent)
	_grid_rect(g, 0, 2, 7, 10, 1)
	_grid_rect(g, 7, 4, 3, 8, 1)
	_grid_rect(g, 10, 6, 2, 6, 1)
	_grid_rect(g, 12, 8, 2, 4, 1)
	# Waves
	_grid_dots(g, [[17, 8], [18, 8], [23, 7], [24, 7], [29, 8], [30, 8]], 3)
	_grid_dots(g, [[16, 9], [17, 9], [21, 9], [22, 9], [27, 9], [28, 9]], 3)
	# Sea surface
	_grid_rect(g, 14, 10, 18, 2, 3)
	# Beach/shore
	_grid_rect(g, 0, 12, GRID_W, 2, 2)
	# Foam
	_grid_dots(g, [[3, 14], [8, 14], [15, 14], [21, 14], [27, 14]], 3)


func _gen_villages(g: Array) -> void:
	# Celtic hamlet — two round huts with smoke
	# Smoke rising
	_grid_dots(g, [[8, 0], [24, 0], [9, 1], [23, 1]], 3)
	# Hut 1 — peaked roof + walls
	_grid_triangle(g, 8, 2, 5, 10, 1)
	_grid_rect(g, 4, 6, 8, 3, 2)
	_grid_set(g, 7, 7, 3)   # door
	_grid_set(g, 7, 8, 3)
	# Hut 2 — peaked roof + walls
	_grid_triangle(g, 23, 2, 5, 10, 1)
	_grid_rect(g, 19, 6, 8, 3, 2)
	_grid_set(g, 22, 7, 3)  # door
	_grid_set(g, 22, 8, 3)
	# Ground
	_grid_rect(g, 0, 9, GRID_W, 2, 2)
	# Path stones
	_grid_dots(g, [[2, 11], [6, 11], [10, 11], [14, 11],
		[18, 11], [22, 11], [26, 11], [30, 11]], 3)


func _gen_cercles(g: Array) -> void:
	# Stone circle under stars and moon
	# Stars
	_grid_dots(g, [[3, 0], [9, 1], [15, 0], [22, 1], [28, 0],
		[6, 1], [19, 0], [26, 1], [12, 0], [30, 1]], 3)
	# Moon
	_grid_dots(g, [[15, 2], [16, 2], [14, 3], [15, 3], [16, 3], [17, 3]], 3)
	# Standing stones (5 in curved arc)
	_grid_rect(g, 3, 5, 2, 6, 1)    # Stone 1 (leftmost, shorter)
	_grid_rect(g, 9, 4, 2, 7, 1)    # Stone 2
	_grid_rect(g, 15, 3, 2, 8, 1)   # Stone 3 (center, tallest)
	_grid_rect(g, 21, 4, 2, 7, 1)   # Stone 4
	_grid_rect(g, 27, 5, 2, 6, 1)   # Stone 5 (rightmost, shorter)
	# Ground
	_grid_rect(g, 0, 11, GRID_W, 2, 2)
	# Moss between stones
	_grid_dots(g, [[6, 12], [12, 12], [18, 12], [24, 12]], 3)


func _gen_marais(g: Array) -> void:
	# Dark swamp — gnarled trees, water, phosphorescence
	# Mist dots
	_grid_dots(g, [[4, 0], [12, 1], [20, 0], [28, 1], [8, 0], [24, 1]], 3)
	# Gnarled tree 1 — trunk + branches
	_grid_rect(g, 5, 4, 2, 5, 1)
	_grid_dots(g, [[4, 2], [5, 2], [7, 2], [3, 3], [4, 3], [5, 3],
		[6, 3], [7, 3], [8, 3]], 1)
	# Gnarled tree 2
	_grid_rect(g, 22, 5, 2, 4, 1)
	_grid_dots(g, [[21, 3], [22, 3], [24, 3], [20, 4], [21, 4],
		[22, 4], [23, 4], [24, 4], [25, 4]], 1)
	# Dark water
	_grid_rect(g, 0, 9, GRID_W, 3, 2)
	# Water reflections
	_grid_dots(g, [[5, 10], [6, 10], [22, 10], [23, 10],
		[10, 11], [15, 11], [28, 11]], 3)
	# Muddy bank
	_grid_rect(g, 0, 12, GRID_W, 2, 1)
	# Phosphorescence
	_grid_dots(g, [[2, 13], [8, 13], [14, 13], [19, 13], [26, 13]], 3)


func _gen_collines(g: Array) -> void:
	# Dolmen on rolling hills at sunset
	# Sunset hints
	_grid_dots(g, [[5, 0], [12, 0], [20, 0], [27, 0], [16, 1],
		[8, 1], [24, 1]], 3)
	# Dolmen capstone
	_grid_rect(g, 11, 4, 10, 2, 1)
	# Dolmen pillars
	_grid_rect(g, 12, 6, 2, 4, 1)
	_grid_rect(g, 18, 6, 2, 4, 1)
	# Rolling hills (background)
	_grid_hill(g, 8, 11, 10, 3, 2)
	_grid_hill(g, 24, 11, 10, 4, 2)
	# Ground
	_grid_rect(g, 0, 12, GRID_W, 2, 2)
	# Grass tufts
	_grid_dots(g, [[2, 14], [7, 14], [14, 14], [21, 14], [26, 14], [30, 14]], 1)


# ═══════════════════════════════════════════════════════════════════════════════
# STAGED GROWTH — All Biomes (5-stage progressive emergence)
# ═══════════════════════════════════════════════════════════════════════════════

func _get_biome_stages(biome: String) -> Array:
	## Returns 5 progressive growth stages for any biome.
	## Each stage = Array of [col, row, color_key].
	## "p" = primary, "s" = secondary, "a" = accent.
	match biome:
		"broceliande": return _get_broceliande_stages()
		"landes": return _get_landes_stages()
		"cotes": return _get_cotes_stages()
		"villages": return _get_villages_stages()
		"cercles": return _get_cercles_stages()
		"marais": return _get_marais_stages()
		"collines": return _get_collines_stages()
		"iles": return _get_iles_stages()
		_: return _get_broceliande_stages()
	return []


# ── LANDES ── Heather moors, lone menhirs, windswept ─────────────────────────

func _get_landes_stages() -> Array:
	return [
		_landes_stage_ground(),
		_landes_stage_menhirs(),
		_landes_stage_hills(),
		_landes_stage_heather(),
		_landes_stage_details(),
	]


func _landes_stage_ground() -> Array:
	var px: Array = []
	# Sandy heath floor (rows 13-15)
	for x in range(GRID_W):
		for y in range(13, 16):
			px.append([x, y, "s"])
	# Scattered pebbles
	for pos in [[3, 13], [10, 13], [19, 13], [27, 13], [7, 14], [23, 14]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _landes_stage_menhirs() -> Array:
	var px: Array = []
	# Main menhir — tall central standing stone
	for y in range(2, 13):
		px.append([15, y, "p"])
		px.append([16, y, "p"])
	# Menhir pointed top
	px.append([15, 1, "p"])
	# Widened base
	for x in [14, 17]:
		for y in [11, 12]:
			px.append([x, y, "p"])
	# Smaller background menhir (left)
	for y in range(6, 13):
		px.append([6, y, "p"])
	# Tiny distant menhir (far right)
	for y in range(8, 13):
		px.append([28, y, "p"])
	return px


func _landes_stage_hills() -> Array:
	var px: Array = []
	# Left rolling hill
	for x in range(4, 13):
		px.append([x, 10, "s"])
	for x in range(2, 14):
		px.append([x, 11, "s"])
	for x in range(0, 14):
		px.append([x, 12, "s"])
	# Right rolling hill
	for x in range(22, 30):
		px.append([x, 10, "s"])
	for x in range(20, 31):
		px.append([x, 11, "s"])
	for x in range(18, GRID_W):
		px.append([x, 12, "s"])
	return px


func _landes_stage_heather() -> Array:
	var px: Array = []
	# Heather flowers on hills (accent purple)
	for pos in [[1, 12], [4, 11], [7, 10], [10, 10], [5, 12], [9, 11],
		[12, 11], [20, 12], [22, 11], [25, 10], [28, 11], [30, 12],
		[2, 14], [8, 14], [13, 14], [18, 14], [24, 14], [29, 14]]:
		px.append([pos[0], pos[1], "a"])
	# Low heather bushes (clusters)
	for pos in [[3, 12], [4, 12], [11, 10], [12, 10], [23, 10], [24, 10],
		[26, 11], [27, 11]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _landes_stage_details() -> Array:
	var px: Array = []
	# Wind streaks (horizontal accent lines)
	for pos in [[2, 1], [3, 1], [4, 1], [20, 2], [21, 2], [22, 2],
		[10, 3], [11, 3], [12, 3]]:
		px.append([pos[0], pos[1], "a"])
	# Crow silhouettes
	for pos in [[8, 0], [9, 0], [25, 1], [26, 1]]:
		px.append([pos[0], pos[1], "p"])
	# Moss on menhir base
	for pos in [[15, 12], [16, 12]]:
		px.append([pos[0], pos[1], "a"])
	return px


# ── COTES ── Sea cliffs, crashing waves, salty breeze ────────────────────────

func _get_cotes_stages() -> Array:
	return [
		_cotes_stage_shore(),
		_cotes_stage_cliff(),
		_cotes_stage_waves(),
		_cotes_stage_spray(),
		_cotes_stage_details(),
	]


func _cotes_stage_shore() -> Array:
	var px: Array = []
	# Deep sea (rows 10-11)
	for x in range(14, GRID_W):
		for y in [10, 11]:
			px.append([x, y, "s"])
	# Beach sand (rows 12-15)
	for x in range(GRID_W):
		for y in range(12, 16):
			px.append([x, y, "s"])
	return px


func _cotes_stage_cliff() -> Array:
	var px: Array = []
	# Cliff face — stepped descent from left
	# Upper cliff (cols 0-6, rows 2-12)
	for x in range(0, 7):
		for y in range(2, 12):
			px.append([x, y, "p"])
	# Step 1 (cols 7-9, rows 4-12)
	for x in range(7, 10):
		for y in range(4, 12):
			px.append([x, y, "p"])
	# Step 2 (cols 10-11, rows 6-12)
	for x in range(10, 12):
		for y in range(6, 12):
			px.append([x, y, "p"])
	# Step 3 (cols 12-13, rows 8-12)
	for x in range(12, 14):
		for y in range(8, 12):
			px.append([x, y, "p"])
	# Cliff top grass
	for x in range(0, 7):
		px.append([x, 1, "a"])
	return px


func _cotes_stage_waves() -> Array:
	var px: Array = []
	# Wave crests (white caps in sea area)
	for pos in [[17, 8], [18, 8], [23, 7], [24, 7], [29, 8], [30, 8]]:
		px.append([pos[0], pos[1], "a"])
	# Wave bodies
	for pos in [[16, 9], [17, 9], [21, 9], [22, 9], [27, 9], [28, 9]]:
		px.append([pos[0], pos[1], "a"])
	# Gentle swells
	for pos in [[15, 10], [19, 10], [25, 10], [31, 10]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _cotes_stage_spray() -> Array:
	var px: Array = []
	# Cliff base spray (where waves hit rock)
	for pos in [[13, 9], [14, 9], [14, 8], [12, 10], [13, 10]]:
		px.append([pos[0], pos[1], "a"])
	# Beach foam line
	for pos in [[3, 14], [8, 14], [15, 14], [21, 14], [27, 14]]:
		px.append([pos[0], pos[1], "a"])
	# Sea spray dots
	for pos in [[14, 6], [15, 7], [11, 7]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _cotes_stage_details() -> Array:
	var px: Array = []
	# Seabirds in sky
	for pos in [[18, 1], [19, 1], [24, 0], [25, 0], [28, 2], [29, 2]]:
		px.append([pos[0], pos[1], "a"])
	# Lighthouse hint (far right)
	for y in range(3, 8):
		px.append([31, y, "p"])
	px.append([31, 2, "a"])  # beacon light
	# Cliff face texture (erosion lines)
	for pos in [[2, 5], [4, 7], [1, 9], [5, 4], [3, 8]]:
		px.append([pos[0], pos[1], "a"])
	# Tidepools on shore
	for pos in [[6, 13], [10, 13]]:
		px.append([pos[0], pos[1], "a"])
	return px


# ── VILLAGES ── Celtic hamlet, round huts, hearth smoke ──────────────────────

func _get_villages_stages() -> Array:
	return [
		_villages_stage_ground(),
		_villages_stage_walls(),
		_villages_stage_roofs(),
		_villages_stage_smoke(),
		_villages_stage_details(),
	]


func _villages_stage_ground() -> Array:
	var px: Array = []
	# Earth ground (rows 10-15)
	for x in range(GRID_W):
		for y in range(10, 16):
			px.append([x, y, "s"])
	return px


func _villages_stage_walls() -> Array:
	var px: Array = []
	# Hut 1 walls (left)
	for x in range(4, 12):
		for y in range(6, 10):
			px.append([x, y, "s"])
	# Hut 2 walls (right)
	for x in range(19, 27):
		for y in range(6, 10):
			px.append([x, y, "s"])
	# Well structure (center)
	for y in range(8, 10):
		px.append([15, y, "p"])
		px.append([16, y, "p"])
	return px


func _villages_stage_roofs() -> Array:
	var px: Array = []
	# Hut 1 peaked roof — triangular thatch
	for x in range(5, 11):
		px.append([x, 4, "p"])
	for x in range(4, 12):
		px.append([x, 5, "p"])
	px.append([7, 3, "p"])
	px.append([8, 3, "p"])
	# Hut 2 peaked roof
	for x in range(20, 26):
		px.append([x, 4, "p"])
	for x in range(19, 27):
		px.append([x, 5, "p"])
	px.append([22, 3, "p"])
	px.append([23, 3, "p"])
	# Well roof (small)
	for x in [14, 15, 16, 17]:
		px.append([x, 7, "p"])
	return px


func _villages_stage_smoke() -> Array:
	var px: Array = []
	# Smoke from hut 1 chimney
	for pos in [[8, 2], [7, 1], [8, 0], [9, 1]]:
		px.append([pos[0], pos[1], "a"])
	# Smoke from hut 2 chimney
	for pos in [[23, 2], [22, 1], [23, 0], [24, 1]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _villages_stage_details() -> Array:
	var px: Array = []
	# Doors (warm light glow)
	for pos in [[7, 8], [7, 9], [22, 8], [22, 9]]:
		px.append([pos[0], pos[1], "a"])
	# Windows (small glowing squares)
	for pos in [[5, 7], [10, 7], [20, 7], [25, 7]]:
		px.append([pos[0], pos[1], "a"])
	# Path stones leading between huts
	for pos in [[2, 11], [6, 11], [10, 11], [13, 11], [14, 11],
		[15, 11], [16, 11], [17, 11], [18, 11], [22, 11], [26, 11], [30, 11]]:
		px.append([pos[0], pos[1], "a"])
	# Garden patches
	for pos in [[1, 10], [2, 10], [29, 10], [30, 10]]:
		px.append([pos[0], pos[1], "p"])
	# Fence posts
	for pos in [[3, 9], [12, 9], [18, 9], [27, 9]]:
		px.append([pos[0], pos[1], "p"])
	return px


# ── CERCLES ── Stone circle, starlit ritual, ancient power ───────────────────

func _get_cercles_stages() -> Array:
	return [
		_cercles_stage_ground(),
		_cercles_stage_stones(),
		_cercles_stage_moon(),
		_cercles_stage_stars(),
		_cercles_stage_details(),
	]


func _cercles_stage_ground() -> Array:
	var px: Array = []
	# Dark earth and moss (rows 11-15)
	for x in range(GRID_W):
		for y in range(11, 16):
			px.append([x, y, "s"])
	return px


func _cercles_stage_stones() -> Array:
	var px: Array = []
	# 5 standing stones in curved arc (tallest center)
	# Stone 1 (leftmost, shorter)
	for y in range(5, 11):
		px.append([3, y, "p"])
		px.append([4, y, "p"])
	# Stone 2 (left-center)
	for y in range(4, 11):
		px.append([9, y, "p"])
		px.append([10, y, "p"])
	# Stone 3 (center, tallest)
	for y in range(3, 11):
		px.append([15, y, "p"])
		px.append([16, y, "p"])
	# Stone 4 (right-center)
	for y in range(4, 11):
		px.append([21, y, "p"])
		px.append([22, y, "p"])
	# Stone 5 (rightmost, shorter)
	for y in range(5, 11):
		px.append([27, y, "p"])
		px.append([28, y, "p"])
	# Altar stone (flat, center low)
	for x in range(13, 19):
		px.append([x, 10, "p"])
	return px


func _cercles_stage_moon() -> Array:
	var px: Array = []
	# Crescent moon (upper right area)
	for pos in [[22, 0], [23, 0], [24, 0],
		[21, 1], [22, 1], [23, 1], [24, 1], [25, 1],
		[22, 2], [23, 2], [24, 2]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _cercles_stage_stars() -> Array:
	var px: Array = []
	# Stars scattered across sky
	for pos in [[3, 0], [7, 1], [12, 0], [17, 1], [28, 0],
		[5, 2], [10, 1], [14, 2], [19, 0], [26, 2],
		[1, 1], [30, 1], [8, 0], [20, 2]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _cercles_stage_details() -> Array:
	var px: Array = []
	# Runic glow on stones
	for pos in [[3, 7], [9, 6], [15, 5], [21, 6], [27, 7],
		[4, 8], [10, 7], [16, 6], [22, 7], [28, 8]]:
		px.append([pos[0], pos[1], "a"])
	# Moss between stones
	for pos in [[6, 12], [12, 12], [18, 12], [24, 12]]:
		px.append([pos[0], pos[1], "a"])
	# Ground-level mist
	for pos in [[0, 11], [5, 11], [11, 11], [20, 11], [26, 11], [31, 11]]:
		px.append([pos[0], pos[1], "a"])
	# Ethereal glow from altar
	for pos in [[14, 9], [15, 9], [16, 9], [17, 9], [18, 9]]:
		px.append([pos[0], pos[1], "a"])
	return px


# ── MARAIS ── Dark swamp, gnarled trees, phosphorescence ────────────────────

func _get_marais_stages() -> Array:
	return [
		_marais_stage_water(),
		_marais_stage_trunks(),
		_marais_stage_branches(),
		_marais_stage_mist(),
		_marais_stage_details(),
	]


func _marais_stage_water() -> Array:
	var px: Array = []
	# Dark swamp water (rows 9-12)
	for x in range(GRID_W):
		for y in range(9, 13):
			px.append([x, y, "s"])
	# Muddy banks (rows 13-15)
	for x in range(GRID_W):
		for y in range(13, 16):
			px.append([x, y, "p"])
	return px


func _marais_stage_trunks() -> Array:
	var px: Array = []
	# Gnarled tree 1 — thick twisted trunk (left)
	for y in range(4, 9):
		px.append([5, y, "p"])
		px.append([6, y, "p"])
	# Root spreading
	for pos in [[3, 9], [4, 9], [7, 9]]:
		px.append([pos[0], pos[1], "p"])
	# Gnarled tree 2 — thinner, leaning (right)
	for y in range(5, 9):
		px.append([22, y, "p"])
		px.append([23, y, "p"])
	# Root spreading
	for pos in [[21, 9], [24, 9]]:
		px.append([pos[0], pos[1], "p"])
	# Dead stump (center)
	for y in range(7, 9):
		px.append([14, y, "p"])
	return px


func _marais_stage_branches() -> Array:
	var px: Array = []
	# Tree 1 branches — spreading canopy
	for pos in [[3, 2], [4, 2], [5, 2], [7, 2], [8, 2],
		[2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [7, 3], [8, 3], [9, 3],
		[3, 4], [4, 4], [7, 4], [8, 4]]:
		px.append([pos[0], pos[1], "p"])
	# Tree 2 branches
	for pos in [[20, 3], [21, 3], [22, 3], [24, 3], [25, 3],
		[19, 4], [20, 4], [21, 4], [22, 4], [23, 4], [24, 4], [25, 4], [26, 4],
		[20, 5], [21, 5], [24, 5], [25, 5]]:
		px.append([pos[0], pos[1], "p"])
	# Hanging moss from branches
	for pos in [[3, 5], [8, 4], [20, 6], [25, 6]]:
		px.append([pos[0], pos[1], "s"])
	return px


func _marais_stage_mist() -> Array:
	var px: Array = []
	# Mist wisps in upper area
	for pos in [[4, 0], [12, 1], [16, 0], [20, 0], [28, 1], [8, 0], [24, 1]]:
		px.append([pos[0], pos[1], "a"])
	# Water reflections below trees
	for pos in [[5, 10], [6, 10], [22, 10], [23, 10],
		[10, 11], [15, 11], [28, 11]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _marais_stage_details() -> Array:
	var px: Array = []
	# Phosphorescence in water (glowing dots)
	for pos in [[2, 13], [8, 13], [11, 12], [17, 13], [19, 12], [26, 13], [30, 12]]:
		px.append([pos[0], pos[1], "a"])
	# Will-o-wisps (floating lights)
	for pos in [[10, 6], [13, 3], [18, 5], [27, 2]]:
		px.append([pos[0], pos[1], "a"])
	# Eyes peering from darkness (paired dots)
	for pos in [[11, 7], [12, 7], [29, 6], [30, 6]]:
		px.append([pos[0], pos[1], "a"])
	# Lily pads on water
	for pos in [[7, 9], [8, 9], [16, 9], [17, 9], [25, 9], [26, 9]]:
		px.append([pos[0], pos[1], "a"])
	return px


# ── COLLINES ── Rolling hills, dolmen, golden sunset ─────────────────────────

func _get_collines_stages() -> Array:
	return [
		_collines_stage_hills(),
		_collines_stage_pillars(),
		_collines_stage_capstone(),
		_collines_stage_sunset(),
		_collines_stage_details(),
	]


func _collines_stage_hills() -> Array:
	var px: Array = []
	# Background hill left
	for x in range(3, 15):
		px.append([x, 10, "s"])
	for x in range(1, 16):
		px.append([x, 11, "s"])
	# Background hill right
	for x in range(20, 30):
		px.append([x, 10, "s"])
	for x in range(18, 31):
		px.append([x, 11, "s"])
	# Full ground (rows 12-15)
	for x in range(GRID_W):
		for y in range(12, 16):
			px.append([x, y, "s"])
	return px


func _collines_stage_pillars() -> Array:
	var px: Array = []
	# Left dolmen pillar
	for y in range(6, 11):
		px.append([12, y, "p"])
		px.append([13, y, "p"])
	# Right dolmen pillar
	for y in range(6, 11):
		px.append([18, y, "p"])
		px.append([19, y, "p"])
	return px


func _collines_stage_capstone() -> Array:
	var px: Array = []
	# Horizontal capstone connecting pillars
	for x in range(11, 21):
		px.append([x, 4, "p"])
		px.append([x, 5, "p"])
	return px


func _collines_stage_sunset() -> Array:
	var px: Array = []
	# Golden sunset bands in sky
	for pos in [[5, 0], [8, 0], [12, 0], [16, 0], [20, 0], [24, 0], [27, 0],
		[3, 1], [7, 1], [11, 1], [15, 1], [19, 1], [23, 1], [27, 1],
		[6, 2], [10, 2], [14, 2], [18, 2], [22, 2], [26, 2]]:
		px.append([pos[0], pos[1], "a"])
	# Warm glow behind dolmen
	for pos in [[14, 3], [15, 3], [16, 3], [17, 3]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _collines_stage_details() -> Array:
	var px: Array = []
	# Grass tufts
	for pos in [[2, 14], [7, 14], [14, 14], [21, 14], [26, 14], [30, 14],
		[4, 12], [9, 12], [22, 12], [28, 12]]:
		px.append([pos[0], pos[1], "p"])
	# Distant tumuli mounds (far background)
	for pos in [[1, 9], [2, 9], [29, 9], [30, 9]]:
		px.append([pos[0], pos[1], "s"])
	# Small standing stone (far left)
	for y in range(8, 11):
		px.append([0, y, "p"])
	# Path leading to dolmen
	for pos in [[10, 12], [11, 12], [15, 12], [16, 12], [20, 12], [21, 12]]:
		px.append([pos[0], pos[1], "a"])
	return px


# ── ILES ── Mystical island beyond the mists, Avalon-like ───────────────────

func _gen_iles(g: Array) -> void:
	# Mystical island — central rocky mass surrounded by endless ocean
	# Ocean (full width)
	_grid_rect(g, 0, 10, GRID_W, 6, 2)
	# Island mass (center)
	_grid_rect(g, 10, 6, 12, 4, 1)
	_grid_rect(g, 12, 4, 8, 2, 1)
	_grid_rect(g, 14, 3, 4, 1, 1)
	# Tower
	_grid_rect(g, 15, 0, 2, 3, 1)
	# Waves
	_grid_dots(g, [[4, 9], [5, 9], [8, 10], [24, 9], [25, 9], [28, 10]], 3)
	# Stars/lights
	_grid_dots(g, [[2, 0], [6, 1], [10, 0], [22, 0], [28, 1]], 3)


func _get_iles_stages() -> Array:
	return [
		_iles_stage_ocean(),
		_iles_stage_island(),
		_iles_stage_tower(),
		_iles_stage_aurora(),
		_iles_stage_details(),
	]


func _iles_stage_ocean() -> Array:
	var px: Array = []
	# Vast ocean surrounding the island (rows 10-15)
	for x in range(GRID_W):
		for y in range(10, 16):
			px.append([x, y, "s"])
	# Distant horizon line (row 9, sparse)
	for x in range(0, GRID_W, 2):
		px.append([x, 9, "s"])
	return px


func _iles_stage_island() -> Array:
	var px: Array = []
	# Central rocky island mass rising from waves
	# Base (widest)
	for x in range(10, 22):
		px.append([x, 9, "p"])
	for x in range(9, 23):
		px.append([x, 8, "p"])
	# Mid section
	for x in range(11, 21):
		px.append([x, 7, "p"])
	for x in range(12, 20):
		px.append([x, 6, "p"])
	# Upper slope
	for x in range(13, 19):
		px.append([x, 5, "p"])
	for x in range(14, 18):
		px.append([x, 4, "p"])
	return px


func _iles_stage_tower() -> Array:
	var px: Array = []
	# Ancient round tower on the island peak
	for y in range(1, 4):
		px.append([15, y, "p"])
		px.append([16, y, "p"])
	# Tower top (pointed)
	px.append([15, 0, "p"])
	px.append([16, 0, "p"])
	# Ruins beside tower (left)
	for pos in [[12, 5], [13, 5], [11, 6], [12, 6]]:
		px.append([pos[0], pos[1], "p"])
	# Ruins beside tower (right)
	for pos in [[19, 5], [20, 5], [19, 6], [20, 6]]:
		px.append([pos[0], pos[1], "p"])
	# Archway / entrance
	px.append([15, 3, "a"])
	px.append([16, 3, "a"])
	return px


func _iles_stage_aurora() -> Array:
	var px: Array = []
	# Ethereal aurora / mist wrapping the island
	# Upper aurora bands
	for pos in [[3, 0], [4, 0], [5, 0], [7, 1], [8, 1],
		[24, 0], [25, 0], [26, 0], [28, 1], [29, 1],
		[1, 2], [2, 2], [29, 2], [30, 2]]:
		px.append([pos[0], pos[1], "a"])
	# Mist ring around island base
	for pos in [[7, 8], [8, 8], [23, 8], [24, 8],
		[6, 9], [7, 9], [24, 9], [25, 9]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _iles_stage_details() -> Array:
	var px: Array = []
	# Phosphorescent waves
	for pos in [[3, 11], [4, 11], [9, 12], [10, 12],
		[22, 11], [23, 11], [27, 12], [28, 12],
		[1, 13], [14, 14], [18, 14], [30, 13]]:
		px.append([pos[0], pos[1], "a"])
	# Stars reflected in water
	for pos in [[2, 14], [6, 15], [12, 15], [20, 15], [26, 14]]:
		px.append([pos[0], pos[1], "a"])
	# Spirit lights near tower
	for pos in [[14, 2], [17, 1], [13, 3]]:
		px.append([pos[0], pos[1], "a"])
	# Distant shoreline hint (far left)
	for pos in [[0, 8], [1, 8], [0, 9]]:
		px.append([pos[0], pos[1], "p"])
	return px


# ═══════════════════════════════════════════════════════════════════════════════
# TRANSITION SEQUENCE — 6 Phases
# ═══════════════════════════════════════════════════════════════════════════════

func _play_transition() -> void:
	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("mystique")

	# LLM prefetch lancé en background (utilisé pour les cartes)
	_prefetch_monologue = {"done": false, "text": "", "source": "pending"}
	_start_llm_prefetch()

	# Appliquer météo + masquer les éléments texte superflus
	var _now_setup := Time.get_datetime_dict_from_system()
	_apply_weather_for_hour(int(_now_setup.get("hour", 12)), false)
	if biome_subtitle and is_instance_valid(biome_subtitle):
		biome_subtitle.visible = false
	if arrival_text and is_instance_valid(arrival_text):
		arrival_text.visible = false
	if merlin_comment and is_instance_valid(merlin_comment):
		merlin_comment.visible = false

	# Phase 2: Emergence — pixel cascade builds landscape
	await _phase_emergence()

	# Phase 3: Revelation — titre biome seul (pas de sous-titre, pas de zoom)
	await _phase_revelation()

	# Phase 4: Tranche de journée (remplace l'horloge HH:MM)
	await _phase_sentier()

	# Phase 5.5: Génération cartes en background + mini-jeu Faveurs
	await _phase_quest_preparation()

	# Phase 6: Dissolution — pixels fall away, transition to game
	await _phase_dissolution()


# — Phase 1: Brume ——————————————————————————————————————————————————————————

func _phase_brume() -> void:
	var now := Time.get_datetime_dict_from_system()
	_apply_weather_for_hour(int(now.get("hour", 12)), false)
	_update_solar_clock(true)
	SFXManager.play("mist_breath")
	SFXManager.play_biome_ambient(biome_key)

	var vs := get_viewport_rect().size
	var colors: Dictionary = MerlinVisual.BIOME_COLORS.get(biome_key, MerlinVisual.BIOME_COLORS.broceliande)
	var scout_colors: Array[Color] = [colors.primary, colors.secondary, MerlinVisual.CRT_PALETTE.amber]
	for i in range(10):
		var px := ColorRect.new()
		var sz := randf_range(5.0, 9.0)
		px.size = Vector2(sz, sz)
		px.position = Vector2(randf_range(vs.x * 0.2, vs.x * 0.8), randf_range(vs.y * 0.2, vs.y * 0.7))
		px.color = scout_colors[i % scout_colors.size()]
		px.modulate.a = 0.0
		px.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pixel_container.add_child(px)

		var tw := create_tween()
		tw.tween_property(px, "modulate:a", 0.65, 0.06)
		tw.parallel().tween_property(px, "scale", Vector2(1.35, 1.35), 0.22)
		tw.tween_property(px, "modulate:a", 0.0, 0.18)
		tw.tween_callback(px.queue_free)
		if i % 2 == 1:
			await _safe_wait(0.04)

	await _safe_wait(0.2)


# — Phase 2: Emergence ——————————————————————————————————————————————————————

func _phase_emergence() -> void:
	var vs := get_viewport_rect().size

	# Dynamic pixel size — landscape fills ~50% of viewport width
	_pixel_size = floor(vs.x * 0.48 / float(GRID_W))
	_pixel_size = clampf(_pixel_size, 6.0, 16.0)

	var total_w := GRID_W * _pixel_size
	var total_h := GRID_H * _pixel_size
	_landscape_origin = Vector2(
		(vs.x - total_w) / 2.0,
		(vs.y - total_h) / 2.0 + 25.0
	)

	# Reposition arrival text below landscape
	arrival_text.position.y = _landscape_origin.y + total_h + 15.0
	_layout_solar_arc_geometry()

	_landscape_pixels.clear()

	# 5-stage progressive growth — ground → structures → canopy → atmosphere → details
	var stages: Array = _get_biome_stages(biome_key)
	for stage_idx in range(stages.size()):
		await _cascade_landscape_stage(stages[stage_idx])
		if stage_idx < stages.size() - 1:
			await _safe_wait(0.15)

	# Settle
	await _safe_wait(0.4)

	# Subtle glow pulse on completed landscape
	var glow := create_tween()
	glow.tween_property(pixel_container, "modulate", Color(1.3, 1.3, 1.3), 0.25)
	glow.tween_property(pixel_container, "modulate", Color.WHITE, 0.25)
	glow.tween_property(pixel_container, "modulate", Color(1.15, 1.15, 1.15), 0.2)
	glow.tween_property(pixel_container, "modulate", Color.WHITE, 0.2)
	await glow.finished
	SFXManager.play("pixel_cascade")


# — Phase 3: Revelation ————————————————————————————————————————————————————

func _phase_revelation() -> void:
	SFXManager.play("magic_reveal")
	# Titre seul — sous-titre masqué, pas de zoom
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(biome_title, "modulate:a", 1.0, 0.8)
	await tw.finished

	# Pulse couleur biome sur le titre
	var bcolors: Dictionary = MerlinVisual.BIOME_COLORS.get(biome_key, MerlinVisual.BIOME_COLORS.broceliande)
	var tint: Color = bcolors.primary
	tint.a = 1.0
	var tc: Tween = create_tween()
	tc.tween_property(biome_title, "modulate", tint, 0.25).set_ease(Tween.EASE_OUT)
	tc.tween_property(biome_title, "modulate", Color.WHITE, 0.30).set_ease(Tween.EASE_IN)
	# Scale pulse concurrent (T.3 — subtle breathe)
	biome_title.pivot_offset = biome_title.size / 2.0
	var sp: Tween = create_tween()
	sp.tween_property(biome_title, "scale", Vector2(1.05, 1.05), 0.35).set_ease(Tween.EASE_OUT)
	sp.tween_property(biome_title, "scale", Vector2(1.0, 1.0), 0.45).set_ease(Tween.EASE_IN_OUT)

	await _safe_wait(0.3)


func _zoom_into_landscape() -> void:
	## Cinematic zoom into the pixel landscape (1.0 → 1.4x).
	if pixel_container == null:
		await _safe_wait(0.5)
		return
	var total_w := GRID_W * _pixel_size
	var total_h := GRID_H * _pixel_size
	pixel_container.pivot_offset = _landscape_origin + Vector2(total_w / 2.0, total_h / 2.0)

	SFXManager.play("camera_focus")
	var zoom_tw := create_tween()
	zoom_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	zoom_tw.tween_property(pixel_container, "scale", Vector2(1.4, 1.4), 1.5)
	await zoom_tw.finished
	await _safe_wait(0.3)


# — Phase 4: Sentier ———————————————————————————————————————————————————————

func _phase_sentier() -> void:
	SFXManager.play("biome_reveal")
	_update_solar_clock(true)

	if _clock_panel and is_instance_valid(_clock_panel):
		var clock_tw := create_tween()
		clock_tw.tween_property(_clock_panel, "modulate:a", 1.0, 0.22)
		await clock_tw.finished

	_update_solar_clock(true)
	await _safe_wait(0.15)


func _make_diamond(pos: Vector2, color: Color) -> ColorRect:
	var marker := ColorRect.new()
	marker.size = Vector2(8, 8)
	marker.position = pos - Vector2(4, 4)
	marker.color = color
	marker.rotation = PI / 4.0
	marker.pivot_offset = Vector2(4, 4)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fade in
	marker.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(marker, "modulate:a", 1.0, 0.3)
	return marker


# ═══════════════════════════════════════════════════════════════════════════════
# QUEST PREPARATION — Pre-generate cards with growing tree animation
# ═══════════════════════════════════════════════════════════════════════════════

func _phase_quest_preparation() -> void:
	## AUTO : lance la génération des cartes en arrière-plan + mini-jeu Dé du Destin.
	var vs := get_viewport_rect().size
	_cards_generated = false

	# Atténuer le titre (reste lisible)
	if biome_title and is_instance_valid(biome_title):
		var title_tw := create_tween()
		title_tw.tween_property(biome_title, "modulate:a", 0.25, 0.4)
		await title_tw.finished

	# Progress label — status de la génération en arrière-plan
	_quest_progress_label = Label.new()
	_quest_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_progress_label.position = Vector2(vs.x / 2.0 - 200, vs.y * 0.88)
	_quest_progress_label.size = Vector2(400, 28)
	_quest_progress_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	_quest_progress_label.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SIZE)
	var progress_font: Font = MerlinVisual.get_font("body")
	if progress_font:
		_quest_progress_label.add_theme_font_override("font", progress_font)
	_quest_progress_label.modulate.a = 0.0
	_quest_progress_label.text = "Merlin tisse le destin..."
	add_child(_quest_progress_label)
	var plbl_tw := create_tween()
	plbl_tw.tween_property(_quest_progress_label, "modulate:a", 1.0, 0.3)
	await plbl_tw.finished

	# Trigger warmup si pas encore prêt (non-bloquant)
	if merlin_ai and not merlin_ai.get("is_ready"):
		if merlin_ai.has_method("ensure_ready"):
			merlin_ai.ensure_ready()
		elif merlin_ai.has_method("start_warmup"):
			merlin_ai.start_warmup()

	# Lancer génération EN ARRIÈRE-PLAN (coroutine non-awaited)
	_prerun_cards.clear()
	_generate_cards_background()

	# Afficher le mini-jeu pendant la génération
	var mg_result: Dictionary = await _show_de_du_destin_minigame(vs)
	var faveurs_earned: int = mg_result.get("faveurs", MerlinConstants.FAVEURS_PER_MINIGAME_PLAY)

	# Dispatch FAVEUR_ADD
	var store: Node = get_node_or_null("/root/MerlinStore")
	if store and store.has_method("dispatch"):
		store.dispatch({"type": "FAVEUR_ADD", "amount": faveurs_earned})

	# Notification visuelle récompense
	await _show_faveur_reward(vs, faveurs_earned)

	# Attendre la fin de la génération si pas encore terminée (120s max — cards take ~10-20s each)
	var wait_time: float = 0.0
	while not _cards_generated and wait_time < 120.0:
		if scene_finished or not is_inside_tree():
			break
		if _quest_progress_label and is_instance_valid(_quest_progress_label):
			_quest_progress_label.text = "Merlin tisse le destin..."
		await _safe_wait(0.5)
		wait_time += 0.5

	# Confirmation fin
	if _quest_progress_label and is_instance_valid(_quest_progress_label):
		_quest_progress_label.text = "Le destin est tisse."
	SFXManager.play("magic_reveal")
	await _safe_wait(0.5)

	# Générer l'intro du run pour MerlinGame
	await _generate_run_intro()

	# Fade progress label
	var fade_tw := create_tween()
	fade_tw.tween_property(_quest_progress_label, "modulate:a", 0.0, 0.3)
	await fade_tw.finished
	if _quest_progress_label and is_instance_valid(_quest_progress_label):
		_quest_progress_label.queue_free()
		_quest_progress_label = null


func _generate_cards_background() -> void:
	## Génère PRERUN_CARD_COUNT cartes en arrière-plan via LLM.
	## Appelée sans await = coroutine background indépendante.
	if merlin_ai and not merlin_ai.get("is_ready"):
		var wait_start := Time.get_ticks_msec()
		const MAX_WAIT_BG_MS := 30000
		while merlin_ai and not merlin_ai.get("is_ready"):
			if scene_finished or not is_inside_tree():
				_cards_generated = true
				return
			if Time.get_ticks_msec() - wait_start >= MAX_WAIT_BG_MS:
				print("[TransitionBiome] BG: MerlinAI timeout")
				break
			await get_tree().process_frame

	for i in range(PRERUN_CARD_COUNT):
		# Don't break on scene_finished — keep generating even during dissolution
		# Only break if node is freed (is_inside_tree check for await safety)
		if not is_inside_tree():
			break
		if _quest_progress_label and is_instance_valid(_quest_progress_label):
			_quest_progress_label.text = "Tissage %d/%d..." % [i + 1, PRERUN_CARD_COUNT]
		var card: Dictionary = await _generate_prerun_card(i)
		if not card.is_empty():
			_prerun_cards.append(card)
			# Save incrementally — even if scene transitions, partial cards are available
			_save_prerun_cards()
			print("[TransitionBiome] BG: card %d/%d saved (%d total)" % [i + 1, PRERUN_CARD_COUNT, _prerun_cards.size()])
		if is_inside_tree() and not scene_finished:
			SFXManager.play_varied("pixel_land", 0.3)

	_cards_generated = true
	print("[TransitionBiome] BG: generation complete, %d cartes saved." % _prerun_cards.size())


func _show_de_du_destin_minigame(vs: Vector2) -> Dictionary:
	## Mini-jeu inline "Dé du Destin" : lancer un D20 pour gagner des Faveurs.
	const PANEL_W := 300.0
	const PANEL_H := 220.0

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	panel.position = (vs - Vector2(PANEL_W, PANEL_H)) / 2.0
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
	panel_style.border_color = MerlinVisual.CRT_PALETTE.amber
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Titre
	var title_lbl := Label.new()
	title_lbl.text = "Le De du Destin"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	title_lbl.add_theme_font_size_override("font_size", 18)
	var title_font: Font = MerlinVisual.get_font("title")
	if title_font:
		title_lbl.add_theme_font_override("font", title_font)
	vbox.add_child(title_lbl)

	# Sous-titre
	var sub_lbl := Label.new()
	sub_lbl.text = "Lancez en attendant que Merlin\ntisse votre scenario..."
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	sub_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(sub_lbl)

	# Affichage dé (grand nombre)
	var die_lbl := Label.new()
	die_lbl.text = "[ ? ]"
	die_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	die_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	die_lbl.add_theme_font_size_override("font_size", 44)
	vbox.add_child(die_lbl)

	# Bouton Lancer
	var roll_btn := Button.new()
	roll_btn.text = "Lancer le De"
	roll_btn.custom_minimum_size = Vector2(180, 40)
	roll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = MerlinVisual.CRT_PALETTE.amber
	btn_style.set_corner_radius_all(5)
	btn_style.set_content_margin_all(10)
	roll_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover: StyleBoxFlat = btn_style.duplicate()
	btn_hover.bg_color = MerlinVisual.CRT_PALETTE.amber.lightened(0.15)
	roll_btn.add_theme_stylebox_override("hover", btn_hover)
	roll_btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.bg_panel)
	roll_btn.add_theme_font_size_override("font_size", 15)
	vbox.add_child(roll_btn)

	# Fade in
	var fade_in := create_tween()
	fade_in.tween_property(panel, "modulate:a", 1.0, 0.3)
	await fade_in.finished

	# Attendre clic (ou fin génération si ultra-rapide)
	var clicked: Array = [false]
	roll_btn.pressed.connect(func(): clicked[0] = true, CONNECT_ONE_SHOT)
	while not clicked[0] and not scene_finished and not _cards_generated:
		if not is_inside_tree():
			break
		await get_tree().process_frame

	roll_btn.disabled = true

	# Animation spin — décélération progressive
	var die_rng := RandomNumberGenerator.new()
	die_rng.randomize()
	var final_roll: int = die_rng.randi_range(1, 20)
	for spin_i in range(16):
		die_lbl.text = "[ %d ]" % die_rng.randi_range(1, 20)
		var delay: float = 0.04 + spin_i * 0.012
		await _safe_wait(delay)
	die_lbl.text = "[ %d ]" % final_roll

	# Couleur résultat
	var result_color: Color = MerlinVisual.CRT_PALETTE.amber if final_roll >= 10 else MerlinVisual.CRT_PALETTE.phosphor_dim
	die_lbl.add_theme_color_override("font_color", result_color)
	SFXManager.play("magic_reveal")

	# Calcul Faveurs
	var faveurs: int
	var result_text: String
	if final_roll >= 17:
		faveurs = MerlinConstants.FAVEURS_PER_MINIGAME_WIN
		result_text = "Reussite Critique !"
	elif final_roll >= 10:
		faveurs = 2
		result_text = "Succes !"
	else:
		faveurs = MerlinConstants.FAVEURS_PER_MINIGAME_PLAY
		result_text = "Le destin s'eveille..."
	sub_lbl.text = result_text
	sub_lbl.add_theme_color_override("font_color", result_color)

	await _safe_wait(1.0)

	# Fade out
	var fade_out := create_tween()
	fade_out.tween_property(panel, "modulate:a", 0.0, 0.3)
	await fade_out.finished
	panel.queue_free()

	return {"roll": final_roll, "faveurs": faveurs}


func _show_faveur_reward(vs: Vector2, amount: int) -> void:
	## Affiche "+N Faveur(s)" en feedback visuel centré, fade-in/out 1.2s.
	var lbl := Label.new()
	lbl.text = "+%d Faveur%s" % [amount, "s" if amount > 1 else ""]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	lbl.add_theme_font_size_override("font_size", 26)
	var reward_font: Font = MerlinVisual.get_font("title")
	if reward_font:
		lbl.add_theme_font_override("font", reward_font)
	lbl.modulate.a = 0.0
	lbl.size = Vector2(280, 50)
	lbl.position = Vector2((vs.x - 280.0) / 2.0, vs.y * 0.38)
	add_child(lbl)

	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.35)
	tw.tween_property(lbl, "position:y", lbl.position.y - 18.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.35).set_delay(0.7)
	await tw.finished
	lbl.queue_free()


func _create_quest_button(vs: Vector2) -> Button:
	var btn := Button.new()
	btn.text = "Partir en quete"
	btn.custom_minimum_size = Vector2(240, 48)
	btn.position = Vector2(vs.x / 2.0 - 120, vs.y * 0.86)
	btn.pivot_offset = Vector2(120, 24)
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE.amber
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = MerlinVisual.CRT_PALETTE.amber.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)
	var pressed_style: StyleBoxFlat = style.duplicate()
	pressed_style.bg_color = MerlinVisual.CRT_PALETTE.amber.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.bg_panel)
	btn.add_theme_font_size_override("font_size", 18)
	var title_font: Font = MerlinVisual.get_font("title")
	if title_font:
		btn.add_theme_font_override("font", title_font)
	btn.modulate.a = 0.0
	return btn


func _get_quest_tree_stages() -> Array:
	## Returns 5 stages of pixel data for a growing oak tree.
	## Each stage = array of [col, row, color_key].
	## "p" = primary (leaves), "s" = secondary (trunk), "a" = accent (fruit).
	return [
		# Stage 1: Roots + ground
		[
			[0,13,"s"],[1,13,"s"],[2,13,"s"],[3,13,"s"],[4,13,"s"],
			[5,13,"s"],[6,13,"s"],[7,13,"s"],[8,13,"s"],[9,13,"s"],
			[3,12,"s"],[4,12,"s"],[5,12,"s"],[6,12,"s"],
			[2,12,"s"],[7,12,"s"],
		],
		# Stage 2: Trunk
		[
			[4,11,"s"],[5,11,"s"],
			[4,10,"s"],[5,10,"s"],
			[4,9,"s"],[5,9,"s"],
			[4,8,"s"],[5,8,"s"],
			[4,7,"s"],[5,7,"s"],
		],
		# Stage 3: Lower branches
		[
			[2,7,"p"],[3,7,"p"],[6,7,"p"],[7,7,"p"],
			[2,6,"p"],[3,6,"p"],[4,6,"p"],[5,6,"p"],[6,6,"p"],[7,6,"p"],
			[1,6,"p"],[8,6,"p"],
			[3,5,"p"],[4,5,"p"],[5,5,"p"],[6,5,"p"],
		],
		# Stage 4: Upper canopy
		[
			[2,5,"p"],[7,5,"p"],
			[2,4,"p"],[3,4,"p"],[4,4,"p"],[5,4,"p"],[6,4,"p"],[7,4,"p"],
			[3,3,"p"],[4,3,"p"],[5,3,"p"],[6,3,"p"],
			[4,2,"p"],[5,2,"p"],
		],
		# Stage 5: Crown + golden accents
		[
			[3,2,"p"],[6,2,"p"],
			[3,1,"a"],[4,1,"p"],[5,1,"p"],[6,1,"a"],
			[4,0,"a"],[5,0,"a"],
			[1,5,"a"],[8,5,"a"],[2,3,"a"],
		],
	]


func _cascade_tree_stage(stage_pixels: Array, vs: Vector2) -> void:
	## Animate one stage of tree pixels cascading into place.
	var colors: Dictionary = MerlinVisual.BIOME_COLORS.get(biome_key, MerlinVisual.BIOME_COLORS.broceliande)
	var color_map := {"p": colors.primary, "s": colors.secondary, "a": colors.accent}
	var px_size := clampf(vs.x * 0.02, 8.0, 18.0)
	var tree_origin := Vector2(
		vs.x / 2.0 - (QUEST_TREE_W * px_size) / 2.0,
		vs.y * 0.25
	)

	for i in range(stage_pixels.size()):
		var data: Array = stage_pixels[i]
		var col: int = int(data[0])
		var row: int = int(data[1])
		var color_key: String = str(data[2])
		var target_pos := tree_origin + Vector2(col * px_size, row * px_size)
		var color: Color = color_map.get(color_key, colors.primary)

		var px := ColorRect.new()
		px.size = Vector2(px_size, px_size)
		px.position = Vector2(target_pos.x + randf_range(-15.0, 15.0), -20.0 - randf_range(0, 60))
		px.color = color
		px.modulate.a = 0.0
		px.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_quest_tree_container.add_child(px)
		_quest_tree_pixel_nodes.append(px)

		var tw := create_tween()
		tw.tween_property(px, "modulate:a", 1.0, 0.05)
		tw.parallel().tween_property(px, "position", target_pos, randf_range(0.25, 0.45)) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

		if i % 3 == 2:
			await _safe_wait(0.02)

	await _safe_wait(0.2)


func _cascade_landscape_stage(stage_pixels: Array) -> void:
	## Animate one stage of landscape pixels cascading into place.
	## Uses _landscape_origin and _pixel_size set by _phase_emergence().
	var colors: Dictionary = MerlinVisual.BIOME_COLORS.get(biome_key, MerlinVisual.BIOME_COLORS.broceliande)
	var color_map := {"p": colors.primary, "s": colors.secondary, "a": colors.accent}

	for i in range(stage_pixels.size()):
		var data: Array = stage_pixels[i]
		var col: int = int(data[0])
		var row: int = int(data[1])
		var color_key: String = str(data[2])
		var target_pos := _landscape_origin + Vector2(col * _pixel_size, row * _pixel_size)
		var color: Color = color_map.get(color_key, colors.primary)

		var px := ColorRect.new()
		px.size = Vector2(_pixel_size, _pixel_size)
		px.position = Vector2(target_pos.x + randf_range(-20.0, 20.0), -20.0 - randf_range(0, 80))
		px.color = color
		px.modulate.a = 0.0
		px.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pixel_container.add_child(px)
		_landscape_pixels.append(px)

		var tw := create_tween()
		tw.tween_property(px, "modulate:a", 1.0, 0.05)
		tw.parallel().tween_property(px, "position", target_pos, randf_range(0.25, 0.45)) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

		if i % 4 == 3:
			SFXManager.play_varied("pixel_land", 0.15)
			await _safe_wait(0.018)

	await _safe_wait(0.25)


func _strip_meta_text(text: String) -> String:
	## Remove meta-commentary, prompt leaks, and instruction fragments from LLM output.
	# FIX 23+26a: Expanded meta-words list — catches self-intro, option meta-text, stage directions
	var meta_words: Array[String] = [
		"decrochez le choix", "decrocher le choix", "choisir entre",
		"(a)", "(b)", "(c)", "chaudron de", "tendres choix", "(a/b/c)", "a/b/c",
		"regle stricte", "meta-commentaire", "vocabulaire celtique",
		"ecris une scene", "3 choix", "biome:", "carte:", "role:",
		"action a)", "action b)", "action c)",
		"scene narrative", "phrases)", "villageois]",
		"trois options", "trois choix", "je vais te donner",
		"je suis merlin", "je suis le druide", "je suis un druide",
		"je suis une voix", "je suis un ancien", "je suis le gardien",
		"voici les choix", "voici trois", "voici les options",
		"reprendre la scene", "scene precedente",
		"voici une introduction", "introduction detaillee",
		"voici ta reponse", "voici la reponse", "voici le resultat",
		"je suis pret", "je suis prete",
		"merlin est un", "merlin est le",
		"tu as choisi", "tu choisis", "ta reponse",
		"avec une voix", "d'une voix",
		"ensemble nous formons", "formons un arc",
		"c'est une situation", "situation difficile",
		"narration:", "narrateur:", "scenario:",
		"la roche tremble", "un grondement sourd", "escalader la paroi",
		"invoquer la pierre", "fuir vers le vallon",
		"la mousse craque", "odeur de terre humide", "envahit tes narines",
		"avancer vers la lumiere", "ecouter le murmure", "reculer dans l'ombre",
		"voulez!", "croyez!", "devez!", "pouvez!",
		"le lieu est", "le parc national", "il y a environ",
		"heures de train", "nord-ouest", "nord-est", "pays-bas",
		"les aventures d'", "se deroulent les",
		"voici une description", "description ambiante", "description contextuelle",
		"basee sur le scenario", "que vous avez", "scenario detaille",
		"bienvenue dans", "bienvenue en", "bienvenu a",
		"le pays du nord", "ce voyageur est", "ce voyageur",
		# FIX 38: Meta-text describing narrative structure
		"sert de catalyseur", "met l'accent sur", "complication suivante",
		"la suite de l'histoire", "dans cette scene", "cette carte",
		"cette situation sert", "voici une complication", "voici un",
		"ce passage montre", "ce moment revele", "cela introduit",
		# FIX 41: Prompt structure leaks (VERBE:, B/C, FORCE label)
		"verbe :", "verbe:", "b/c)", "a/b)", "a) ", "b) ", "c) ",
		"a/ ", "b/ ", "c/ ", "a/'", "b/'", "c/'",
		"force:", "force :", "option a", "option b", "option c",
		# FIX 43: Identity leaks (LLM assigns Merlin identity to player)
		"tu es merlin", "tu es le druide", "tu es un druide",
		"tu es l'enchanteur", "merlin l'enchanteur",
		# FIX 44: Card generation meta-text + scene structure
		"voici ta carte", "entierement generee", "informations fournies",
		"premiere scene", "deuxieme scene", "troisieme scene",
		"point de depart", "genere en fonction",
		# FIX 45: Prompt instruction leaks (raw template output)
		"titre poetique", "action en 1 phrase", "vers de complication",
		"action differente", "tu puis ai", "equipe principale",
		# FIX 46: Narrative structure leaks ("la complication est causée par...")
		"la complication est", "causee par", "causée par",
		"est causee par", "est causée par",
		# FIX 47: Scenario suggestion + tag description leaks
		"voici la suggestion", "suggestion du scenario",
		"theme ambiant", "thème ambiant", "tags appropries", "tags appropriés",
		"pour le biome", "carte ambiante pour",
		"jour 1 de ce voyage", "jour 2 de ce voyage", "jour 3 de ce voyage",
		# FIX 48: Option labeling leaks + "phrase finale"
		"phrase finale", "phrase initiale", "phrase de transition",
		# FIX 49: Arc prefix + season/session labels
		"saison spring", "saison summer", "saison autumn", "saison winter",
		"saison :", "séance:", "seance:", "séance :",
		# FIX 50: Screenplay format + "cette scène"
		"cette scene", "cette scène", "the scene is",
		# FIX 51: Dash-prefixed arc names
		"- voyage en", "- exploration de", "- complication",
		# FIX 52: "Scene N" without separator + "in the" English intro
		"scene 1", "scene 2", "scene 3", "scene 4", "scene 5",
		"in the forest", "in the mist", "in the cave",
		# FIX 55: Card type labels leaked from prompt
		"carte ambiante", "carte narrative", "carte ambiance",
		"carte événement", "carte evenement", "carte merlin",
		"carte promesse", "ambient card", "narrative card",
	]
	var result := text
	# FIX 52: Strip "Etape N:" / "Scene :" / "Scene 1" prefixes (digits OR separator required)
	var rx_etape := RegEx.new()
	rx_etape.compile("(?im)^\\s*(?:[eé]tape|scene|sc[eè]ne|acte|chapitre|séance)\\s*(?:\\d+\\s*[:\\-]?|[:\\-])\\s*(?:[A-Z][^\\n]{0,40}\\n)?")
	result = rx_etape.sub(result, "", true)
	# FIX 36: Strip arc phase prefixes (Complication:, Climax:, etc.)
	var rx_arc := RegEx.new()
	rx_arc.compile("(?im)^\\s*(?:complication|climax|resolution|introduction|exploration|twist|epilogue|prologue|transition|aurore druidique)\\s*:?\\s*(?:[A-Z][^\\n]{0,40}\\n)?")
	result = rx_arc.sub(result, "", true)
	# Strip markdown bold markers and their meta content
	var rx_md := RegEx.new()
	rx_md.compile("\\*\\*[^*]{0,60}\\*\\*:?")
	result = rx_md.sub(result, "", true)
	# FIX 50: Strip screenplay format headers (INT./EXT. LOCATION - TIME)
	var rx_sp := RegEx.new()
	rx_sp.compile("(?im)^\\s*(?:INT|EXT|int|ext)\\.\\s*[A-ZÀ-Ü ]{2,50}\\s*[-–—]\\s*[A-ZÀ-Ü ]{2,20}\\s*\\n?")
	result = rx_sp.sub(result, "", true)
	# FIX 46: Strip lines starting with backslash (raw markup leak)
	var rx_bs := RegEx.new()
	rx_bs.compile("(?m)^\\s*\\\\\\s*.+$")
	result = rx_bs.sub(result, "", true)
	# Strip lines with meta-words
	for mw in meta_words:
		var pos := result.to_lower().find(mw)
		while pos >= 0:
			var line_start := result.rfind("\n", pos)
			var line_end := result.find("\n", pos)
			if line_start < 0: line_start = 0
			if line_end < 0: line_end = result.length()
			var candidate: String = result.substr(0, line_start) + result.substr(line_end)
			# FIX 47: If line-strip would destroy all text, use sentence-strip instead
			if candidate.strip_edges().length() < 10:
				var sent_start := pos
				for ch in [".", ":", ";", "!"]:
					var ss := result.rfind(ch, pos)
					if ss >= 0 and ss > line_start:
						sent_start = ss + 1
						break
				if sent_start == pos:
					sent_start = line_start
				var sent_end := result.length()
				for ch in [".", ":", ";", "!"]:
					var se := result.find(ch, pos + mw.length())
					if se >= 0 and se < sent_end:
						sent_end = se + 1
				result = result.substr(0, sent_start) + result.substr(sent_end)
			else:
				result = candidate
			pos = result.to_lower().find(mw)
	# FIX 47: Strip "→ choix:" template arrows and ALL-CAPS option labels
	var rx_arrow := RegEx.new()
	rx_arrow.compile("(?m)→\\s*choix\\s*:\\s*[A-ZÀ-Ü]+")
	result = rx_arrow.sub(result, "", true)
	# Clean multiple blank lines
	while result.contains("\n\n\n"):
		result = result.replace("\n\n\n", "\n\n")
	return result.strip_edges()


func _convert_first_to_second_person(text: String) -> String:
	## FIX 30: Post-process LLM output to convert 1st person (je/me/mon/ma/mes)
	## to 2nd person (tu/te/ton/ta/tes). The small LLM often ignores the "tu" instruction.
	## Uses word-boundary-aware regex to avoid breaking words like "jeter", "montagne".

	var result := text

	# --- Pronoun conversions (order matters: longer patterns first) ---

	# FIX 40: Handle j'ai/j'avais/j'étais BEFORE generic j'→t' (prevents "t'ai")
	var rx := RegEx.new()
	rx.compile("(?i)\\bj'ai\\b")
	result = rx.sub(result, "tu as", true)
	rx.compile("(?i)\\bj'avais\\b")
	result = rx.sub(result, "tu avais", true)
	rx.compile("(?i)\\bj'[eé]tais\\b")
	result = rx.sub(result, "tu étais", true)
	rx.compile("(?i)\\bj'aurai\\b")
	result = rx.sub(result, "tu auras", true)
	# "j'" before vowel -> "t'" (j'entends -> t'entends, etc.)
	rx.compile("(?i)\\bj'")
	result = rx.sub(result, "t'", true)

	# "je " -> "tu " (standalone subject pronoun)
	rx.compile("(?i)\\bje\\b")
	result = rx.sub(result, "tu", true)

	# "m'" before vowel -> "t'" (m'appelle -> t'appelle, m'envahit -> t'envahit)
	rx.compile("(?i)\\bm'")
	result = rx.sub(result, "t'", true)

	# " me " -> " te " (reflexive/object pronoun, avoid word-start "me" in "mesure")
	rx.compile("(?i)\\bme\\b")
	result = rx.sub(result, "te", true)

	# "moi" -> "toi" (stressed pronoun: "devant moi", "pour moi")
	rx.compile("(?i)\\bmoi\\b")
	result = rx.sub(result, "toi", true)

	# --- "vous" -> "tu" (formal/plural -> informal 2nd person) ---

	# "vous avez" -> "tu as"
	rx.compile("(?i)\\bvous avez\\b")
	result = rx.sub(result, "tu as", true)

	# "vous etes" / "vous êtes" -> "tu es"
	rx.compile("(?i)\\bvous [eê]tes\\b")
	result = rx.sub(result, "tu es", true)

	# "vous" standalone -> "tu" (generic fallback)
	rx.compile("(?i)\\bvous\\b")
	result = rx.sub(result, "tu", true)

	# "votre" -> "ton/ta" (default to "ton")
	rx.compile("(?i)\\bvotre\\b")
	result = rx.sub(result, "ton", true)

	# "vos" -> "tes"
	rx.compile("(?i)\\bvos\\b")
	result = rx.sub(result, "tes", true)

	# --- Possessive adjectives ---

	# "mes " -> "tes " (mes cheveux -> tes cheveux)
	rx.compile("(?i)\\bmes\\b")
	result = rx.sub(result, "tes", true)

	# "mon " -> "ton " (mon coeur -> ton coeur)
	rx.compile("(?i)\\bmon\\b")
	result = rx.sub(result, "ton", true)

	# "ma " -> "ta " (ma main -> ta main)
	rx.compile("(?i)\\bma\\b")
	result = rx.sub(result, "ta", true)

	# FIX 42: Fix avoir conjugation after "je"→"tu" conversion
	rx.compile("(?i)\\btu n'ai\\b")
	result = rx.sub(result, "tu n'as", true)
	rx.compile("(?i)\\btu ai\\b")
	result = rx.sub(result, "tu as", true)

	# --- Fix case at sentence start ---
	# After conversion, "tu" at sentence start should be capitalized: "Tu"
	rx.compile("(?m)^tu\\b")
	result = rx.sub(result, "Tu", true)
	rx.compile("\\.\\s+tu\\b")
	# For mid-sentence after period: ". tu" -> ". Tu"
	var matches := rx.search_all(result)
	for i in range(matches.size() - 1, -1, -1):
		var m := matches[i]
		var matched_text: String = m.get_string()
		var capitalized: String = matched_text.substr(0, matched_text.length() - 2) + "Tu"
		result = result.substr(0, m.get_start()) + capitalized + result.substr(m.get_end())

	return result


func _generate_prerun_card(index: int) -> Dictionary:
	## Generate one pre-run card via LLM only. Returns {} if LLM unavailable.
	if not merlin_ai or not merlin_ai.get("is_ready") or not merlin_ai.has_method("generate_with_system"):
		print("[TransitionBiome] LLM unavailable for card %d" % index)
		return {}
	var card := await _try_llm_prerun_card(index)
	if not card.is_empty():
		return card
	# Retry once after brief delay
	await get_tree().create_timer(0.5).timeout
	card = await _try_llm_prerun_card(index)
	return card


func _try_llm_prerun_card(index: int) -> Dictionary:
	var biome_name: String = str(biome_data.get("name", "Broceliande"))

	# Arc-based prompt: each card has a narrative role
	var arc_roles: Array[String] = [
		"INTRODUCTION: Etablis le lieu, le danger et l'atmosphere. Le voyageur decouvre le biome.",
		"EXPLORATION: Le voyageur explore, la tension monte. Un indice subtil apparait.",
		"COMPLICATION: Un obstacle majeur se dresse. La situation se complexifie.",
		"CLIMAX: Le moment critique. Le choix du voyageur a des consequences lourdes.",
		"RETOURNEMENT: Une revelation inattendue. Rien n'est ce qu'il semblait etre.",
	]
	var arc_role: String = arc_roles[mini(index, arc_roles.size() - 1)]

	# FIX 21+26d+27+29b: Prompt — sensory 2e personne, different biome example
	var system_prompt := (
		"Narration 2e personne (tu). Present. Francais. Foret celtique.\n"
		+ "INTERDIT: 'je suis', description du lieu, geographie, meta-commentaire.\n"
		+ "Decris ce que tu SENS: odeurs, sons, toucher, lumiere.\n"
		+ "La mousse craque sous tes pas. L'odeur de terre humide envahit tes narines.\n"
		+ "A) Avancer vers la lumiere\nB) Ecouter le murmure\nC) Reculer dans l'ombre"
	)
	var user_prompt := "%s en %s. Sensations (tu), 3-4 phrases, puis A) B) C) verbe." % [arc_role.split(":")[0], biome_name]

	var params := {"max_tokens": 200, "temperature": 0.7 + index * 0.02}
	var result: Dictionary = await merlin_ai.generate_with_system(system_prompt, user_prompt, params)

	if result.has("error") or str(result.get("text", "")).length() < 20:
		return {}

	var raw_text: String = str(result.get("text", ""))

	# Strip meta-text / prompt leak (same patterns as merlin_llm_adapter FIX 12)
	raw_text = _strip_meta_text(raw_text)

	# FIX 22: Extract labels with permissive regex — captures A)/B)/C), A-/B-/C-, 1//2//3/, 1./2./3.
	var labels: Array[String] = []
	var sequel_hooks: Array[String] = []
	var rx := RegEx.new()
	# Captures: A-D) a-d), A-D-, 1-4/, 1-4., -/*, §, Action A)
	rx.compile("(?m)^\\s*(?:[§\\-*]\\s*)?\\*{0,2}(?:(?:Action\\s+)?[A-Da-d]\\s*[):.\\]\\-/]|[1-4]\\s*[.)/])\\*{0,2}[:\\s]*(.+)")
	var matches := rx.search_all(raw_text)
	for m in matches:
		var full_label := m.get_string(1).strip_edges().replace("**", "").replace("*", "")
		if full_label.length() > 2 and full_label.length() < 120:
			# Parse sequel hook after " -> "
			var arrow_pos := full_label.find(" -> ")
			if arrow_pos > 0:
				labels.append(full_label.substr(0, arrow_pos).strip_edges())
				sequel_hooks.append(full_label.substr(arrow_pos + 4).strip_edges())
			else:
				labels.append(full_label)
				sequel_hooks.append("")

	# FIX 22+25+26b+27: Strip ALL inline options from narrative text (line-start AND paragraph-inline)
	var narrative := raw_text
	var rx_strip := RegEx.new()
	# Strip any line starting with A)/B)/C), a-c, 1-9 (any digit), §, or dash/star option markers
	rx_strip.compile("(?m)^\\s*(?:[§\\-*]\\s*)?\\*{0,2}(?:(?:Action\\s+)?[A-Da-d]\\s*[):.\\]\\-/]|[1-9]\\s*[.)/\\-]).*$")
	narrative = rx_strip.sub(narrative, "", true).strip_edges()
	# FIX 27: Strip "(tu)" instruction fragment and standalone § markers
	narrative = narrative.replace("(tu)", "").replace("§", "")
	# Also strip lines that start with just "A " or "B " or "C " followed by text (common LLM pattern)
	var rx_bare := RegEx.new()
	rx_bare.compile("(?m)^\\s*[A-C]\\s{1,3}[A-Z].*$")
	narrative = rx_bare.sub(narrative, "", true).strip_edges()
	# FIX 26b: Strip paragraph-inline options like "1/ text 2/ text 3/ text" on a single line
	var rx_inline := RegEx.new()
	rx_inline.compile("\\s[1-3]\\s*[/)]\\s*[A-Z][^.!?]{3,60}(?=[\\s.!?]|$)")
	narrative = rx_inline.sub(narrative, "", true).strip_edges()
	# Also strip "A) text" mid-sentence
	var rx_inline_abc := RegEx.new()
	rx_inline_abc.compile("\\s[A-C]\\)\\s*[A-Z][^.!?]{3,60}(?=[\\s.!?]|$)")
	narrative = rx_inline_abc.sub(narrative, "", true).strip_edges()
	# Strip lines that are ONLY a dash followed by dialogue (not narrative dashes mid-sentence)
	var rx_dash_dialogue := RegEx.new()
	rx_dash_dialogue.compile("(?m)^\\s*-\\s*[\"'].*$")
	narrative = rx_dash_dialogue.sub(narrative, "", true).strip_edges()
	# Clean multiple blank lines
	while narrative.contains("\n\n\n"):
		narrative = narrative.replace("\n\n\n", "\n\n")
	while narrative.contains("\n\n"):
		narrative = narrative.replace("\n\n", "\n")

	# FIX 30: Convert 1st person to 2nd person (tu) — LLM often writes "je" despite prompt
	narrative = _convert_first_to_second_person(narrative)

	# FIX 22b+26c+28: Label safety net — reject non-action labels
	var safe_labels: Array[String] = []
	var reject_words: Array[String] = [
		"LA", "LE", "LES", "UN", "UNE", "DES", "VOTRE", "NOTRE", "SON", "SA", "SES",
		"JE", "TU", "IL", "ELLE", "NOUS", "VOUS", "ILS", "ELLES", "MON", "MA", "MES",
		"CE", "CET", "CETTE", "CES", "QUI", "QUE", "QUOI", "MERLIN",
		"CEST", "AVEC", "DANS", "POUR", "VERS", "ENTRE", "MAIS", "DONC",
		"CONTINUE", "CHOISI", "CHOISIS", "JUSQUAU", "JUSQUA",
		"PRISE", "VUE", "PLACE", "FIN", "LIEU", "VOIX",
		"VOULEZ", "CROYEZ", "DEVEZ", "POUVEZ", "SAVEZ",
	]
	# FIX 28: Reject suffixes that indicate non-action words
	var reject_suffixes: Array[String] = [
		"ANT", "ANTE", "ANTS",  # present participle (voyageant, marchant)
		"IQUE", "IQUES",  # adjective (historique, mystique)
		"TION", "TIONS",  # noun (exploration, situation)
		"MENT", "MENTS",  # adverb/noun (mouvement, rapidement)
		"ENCE", "ENCES",  # noun (prudence, violence)
		"ISTE", "ISTES",  # noun (druide → but this doesn't end in iste)
	]
	for lbl in labels:
		var clean_lbl := lbl.replace("\"", "").replace("'", "").strip_edges()
		# FIX 26c: Split on apostrophe too (C'est -> C, est -> first_word = C = rejected)
		var fw_raw: String = clean_lbl.split(" ", false)[0] if not clean_lbl.is_empty() else ""
		# Handle French apostrophe contractions: split on ' to get real first word
		var first_word: String = fw_raw.split("'")[0] if "'" in fw_raw else fw_raw
		first_word = first_word.replace(")", "").replace("(", "").replace("-", "").strip_edges()
		# Also check the full first token without apostrophe split
		var fw_full: String = fw_raw.replace(")", "").replace("(", "").replace("-", "").replace("'", "").strip_edges()
		# FIX 28: Check for merged apostrophe (Lhisterique = L' + hystérique)
		var looks_merged: bool = fw_full.length() > 5 and (fw_full.begins_with("L") or fw_full.begins_with("D")) and not " " in clean_lbl.substr(0, 4)
		# FIX 28: Check for non-action suffixes on first word
		var has_bad_suffix: bool = false
		for suf in reject_suffixes:
			if fw_full.to_upper().ends_with(suf) and fw_full.length() > suf.length() + 2:
				has_bad_suffix = true
				break
		# Reject: too short, articles/pronouns, starts with quote, or contains meta-text
		var is_bad: bool = (
			first_word.length() < 3
			or first_word.to_upper() in reject_words
			or fw_full.to_upper() in reject_words
			or looks_merged
			or has_bad_suffix
			or clean_lbl.begins_with("\"")
			or clean_lbl.begins_with("'")
			or "je suis" in clean_lbl.to_lower()
			or "merlin" in clean_lbl.to_lower()
			or "option" in clean_lbl.to_lower()
			or "tu as choisi" in clean_lbl.to_lower()
			or "tu choisis" in clean_lbl.to_lower()
			or " est " in clean_lbl.to_lower()
			or " sont " in clean_lbl.to_lower()
		)
		if is_bad:
			safe_labels.append("")  # Will be replaced by fallback
		else:
			# Truncate long labels to first meaningful part (max ~40 chars)
			if clean_lbl.length() > 45:
				var truncate_pos := clean_lbl.find(".", 5)
				if truncate_pos < 0 or truncate_pos > 45:
					truncate_pos = clean_lbl.find(",", 5)
				if truncate_pos > 5 and truncate_pos <= 45:
					clean_lbl = clean_lbl.substr(0, truncate_pos).strip_edges()
				else:
					clean_lbl = clean_lbl.substr(0, 40).strip_edges()
			safe_labels.append(clean_lbl)
	labels = safe_labels

	if labels.size() < 3 or labels.count("") > 0:
		# Rotate fallback triplets per card index to avoid repetition
		var fallback_pool: Array = [
			[tr("FALLBACK_CAUTIOUS"), tr("FALLBACK_OBSERVE"), tr("FALLBACK_ACT")],
			["Chercher un indice", "Attendre patiemment", "Invoquer les esprits"],
			["Escalader le rocher", "Contourner l'obstacle", "Briser le sceau"],
			["Negocier avec l'ombre", "Defier le gardien", "Fuir vers la clairiere"],
			["Toucher la rune", "Ecouter le vent", "Suivre le corbeau"],
		]
		var fb_triplet: Array = fallback_pool[mini(index, fallback_pool.size() - 1)]
		for fi in range(3):
			if fi >= labels.size():
				labels.append(fb_triplet[fi])
			elif labels[fi].is_empty():
				labels[fi] = fb_triplet[fi]
		if sequel_hooks.size() < 3:
			sequel_hooks = ["La prudence sera recompensee", "Le silence revele des secrets", "L'audace attire l'attention"]

	# Dynamic effects scaling with card position + SHIFT_ASPECT for Triade progression
	var base_amt: int = 3 + index  # 3 for card 0, up to 7 for card 4
	# Rotate aspects across cards so all 3 get shifted during the prerun buffer
	var aspects: Array[String] = ["Corps", "Ame", "Monde"]
	var primary_aspect: String = aspects[index % 3]
	var secondary_aspect: String = aspects[(index + 1) % 3]
	var effect_pool: Array = [
		[{"type": "HEAL_LIFE", "amount": base_amt}, {"type": "SHIFT_ASPECT", "aspect": primary_aspect, "direction": "up"}],
		[{"type": "ADD_KARMA", "amount": clampi(base_amt / 2, 1, 3)}, {"type": "SHIFT_ASPECT", "aspect": secondary_aspect, "direction": "up"}],
		[{"type": "DAMAGE_LIFE", "amount": base_amt}, {"type": "SHIFT_ASPECT", "aspect": primary_aspect, "direction": "down"}],
	]
	# Late arc: add PROGRESS_MISSION to option C (keep SHIFT_ASPECT too)
	if index >= 3:
		effect_pool[2] = [{"type": "PROGRESS_MISSION", "step": 1}, {"type": "SHIFT_ASPECT", "aspect": secondary_aspect, "direction": "down"}]

	var dc_hints: Array = [
		{"min": 4, "max": 8},
		{"min": 7, "max": 12},
		{"min": 10, "max": 16},
	]
	var risk_levels: Array[String] = ["faible", "moyen", "eleve"]

	var options: Array = []
	for j in range(3):
		var hook: String = sequel_hooks[j] if j < sequel_hooks.size() else ""
		var label_text: String = labels[j] if j < labels.size() else "Choix %d" % (j + 1)
		var opt: Dictionary = {
			"label": label_text,
			"effects": effect_pool[j],
			"sequel_hook": hook,
			"dc_hint": dc_hints[j],
			"risk_level": risk_levels[j],
			"result_success": "Votre %s s'avere payant." % label_text.split(" ")[0].to_lower(),
			"result_failure": "Malgre vos efforts, %s ne suffit pas." % label_text.split(" ")[0].to_lower(),
		}
		if j == 1:
			opt["cost"] = 1
		options.append(opt)

	# FIX 23: Always use evocative arc titles — narrative sentences are too long/generic as titles
	var arc_phase: String = ["intro", "exploration", "complication", "climax", "twist"][mini(index, 4)]
	var arc_titles: Array[String] = ["L'Eveil du Sentier", "Echos dans la Brume", "Le Seuil de l'Ombre", "L'Heure du Choix", "Retournement du Destin"]
	var title: String = arc_titles[mini(index, 4)]

	# Biome-appropriate visual and audio tags
	var biome_vtags: Dictionary = {
		"broceliande": ["foret", "arbre", "mousse", "lumiere_filtree"],
		"landes": ["bruyere", "menhir", "vent", "horizon"],
		"cotes": ["falaise", "vague", "goeland", "embruns"],
		"villages": ["chaumiere", "chemin", "fumee", "pierre"],
		"cercles": ["menhir", "rune", "brume", "lune"],
		"marais": ["eau_sombre", "jonc", "brume", "luciole"],
		"collines": ["colline", "dolmen", "vent", "ciel"],
	}
	var biome_atags: Dictionary = {
		"broceliande": ["vent_feuillage", "oiseau"],
		"landes": ["vent_fort", "grillon"],
		"cotes": ["vagues", "vent_marin"],
		"villages": ["feu_craquement", "cloche"],
		"cercles": ["silence", "bourdonnement"],
		"marais": ["eau_clapotis", "grenouille"],
		"collines": ["vent_doux", "aigle"],
	}
	var vtags: Array = biome_vtags.get(biome_key, ["foret", "sentier"])
	var atags: Array = biome_atags.get(biome_key, ["vent_feuillage"])

	return {
		"id": "prerun_%d" % index,
		"title": title,
		"text": narrative if narrative.length() > 20 else raw_text.substr(0, mini(raw_text.length(), 300)),
		"speaker": "Merlin",
		"type": "narrative",
		"biome": biome_key,
		"season": _get_current_season(),
		"options": options,
		"visual_tags": vtags,
		"audio_tags": atags,
		"card_position": index + 1,
		"arc_phase": arc_phase,
		"result_success": "Le choix porte ses fruits, la foret repond a ton audace.",
		"result_failure": "Le sentier se referme, les ombres grondent autour de toi.",
		"tags": ["prerun", "llm_generated"],
	}



func _save_prerun_cards() -> void:
	if _prerun_cards.is_empty():
		return
	var file := FileAccess.open(PRERUN_CARDS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_prerun_cards, "\t"))
		file.close()
		print("[TransitionBiome] Saved %d pre-generated cards to %s" % [_prerun_cards.size(), PRERUN_CARDS_PATH])


func _generate_run_intro() -> void:
	## Generate a cinematic LLM intro (Hand of Fate 2 style dealer monologue).
	## Saves to user://temp_run_intro.json for consumption by MerlinGameUI.
	if merlin_ai == null or not merlin_ai.is_ready:
		return

	var biome_name: String = str(biome_data.get("name", "Broceliande"))
	var biome_subtitle: String = str(biome_data.get("sous_titre", ""))
	var guardian: String = str(biome_data.get("gardien", ""))
	var ogham: String = str(biome_data.get("ogham", ""))

	# Use dealer_monologue template from scenario_prompts.json
	var sys := (
		"Tu es Merlin l'Enchanteur, conteur et maitre des cartes. "
		+ "Tu poses les cartes du destin sur la table de pierre devant le Voyageur. "
		+ "Decris le biome avec tes sens de druide (odeurs, sons, lumiere, textures). "
		+ "Mentionne l'etat du voyageur sans nommer les mecaniques. "
		+ "Termine par un pressentiment enigmatique sur ce qui attend. "
		+ "4-6 phrases en francais, ton grave et theatral, comme un conteur au coin du feu. "
		+ "Pas de guillemets. Vocabulaire celtique: nemeton, ogham, sidhe, dolmen, brume, racines, pierre dressee."
	)
	var usr := "Biome: %s (%s). Gardien: %s. Ogham: %s. Genere le monologue du dealer." % [
		biome_name, biome_subtitle, guardian, ogham
	]

	# Enrich with scenario context if active
	var store: Node = get_node_or_null("/root/MerlinStore")
	if store and store.has_method("get_scenario_manager"):
		var scenario_mgr = store.get_scenario_manager()
		if scenario_mgr and scenario_mgr.is_scenario_active():
			var title: String = scenario_mgr.get_scenario_title()
			var tone: String = scenario_mgr.get_scenario_tone()
			if not title.is_empty():
				usr += " Scenario: %s. Ton: %s." % [title, tone]

	var result: Dictionary = await merlin_ai.generate_narrative(sys, usr, {"max_tokens": 250})
	var text: String = str(result.get("text", "")).strip_edges()

	# Validate basic quality (allow longer intro for dealer monologue)
	if text.length() < 10 or text.length() > 800:
		return
	var lower := text.to_lower()
	for eng_word in ["the ", " and ", " you "]:
		if eng_word in lower:
			return

	# Save for MerlinGame
	var intro_data := {
		"text": text,
		"biome": biome_key,
		"source": "llm",
		"timestamp": Time.get_ticks_msec()
	}
	var f := FileAccess.open("user://temp_run_intro.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(intro_data))
		f.close()
		print("[TransitionBiome] Run intro saved: %s" % text.left(60))


# — Phase 6: Dissolution ——————————————————————————————————————————————————

func _phase_dissolution() -> void:
	SFXManager.play("scene_transition")
	SFXManager.play("pixel_scatter")
	SFXManager.play("biome_dissolve")
	scene_finished = true

	# Reset zoom before dissolving
	if pixel_container and pixel_container.scale != Vector2.ONE:
		var reset_tw := create_tween()
		reset_tw.tween_property(pixel_container, "scale", Vector2.ONE, 0.3)
		await reset_tw.finished

	# Fade text and UI elements first
	var text_tw := create_tween()
	text_tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	text_tw.tween_property(arrival_text, "modulate:a", 0.0, 0.3)
	text_tw.parallel().tween_property(merlin_comment, "modulate:a", 0.0, 0.3)
	text_tw.parallel().tween_property(biome_title, "modulate:a", 0.0, 0.3)
	text_tw.parallel().tween_property(biome_subtitle, "modulate:a", 0.0, 0.3)
	if _clock_panel and is_instance_valid(_clock_panel):
		text_tw.parallel().tween_property(_clock_panel, "modulate:a", 0.0, 0.3)
	if _weather_overlay and is_instance_valid(_weather_overlay):
		text_tw.parallel().tween_property(_weather_overlay, "modulate:a", 0.0, 0.3)
	await text_tw.finished

	# Dissolve landscape — pixels fall away with gravity
	SFXManager.play("whoosh")
	_landscape_pixels.shuffle()
	for i in range(_landscape_pixels.size()):
		var px: ColorRect = _landscape_pixels[i]
		if not is_instance_valid(px):
			continue

		var fall_dist := randf_range(250.0, 500.0)
		var fall_time := randf_range(0.5, 1.0)

		var tw := create_tween()
		tw.tween_property(px, "position:y", px.position.y + fall_dist, fall_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(px, "position:x",
			px.position.x + randf_range(-25.0, 25.0), fall_time)
		tw.parallel().tween_property(px, "modulate:a", 0.0, fall_time * 0.7)

		# Stagger dissolution
		if i % 6 == 5:
			await _safe_wait(0.015)

	await _safe_wait(0.6)

	# Final screen fade
	var final_tw := create_tween()
	final_tw.tween_property(self, "modulate:a", 0.0, 0.5)
	final_tw.tween_callback(func():
		_clear_merlin_scene_context()
		if is_inside_tree():
			PixelTransition.transition_to(NEXT_SCENE)
	)


# ═══════════════════════════════════════════════════════════════════════════════
# LLM NARRATION
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# LLM CONTEXT BUILDERS
# ═══════════════════════════════════════════════════════════════════════════════

func _build_llm_biome_context() -> String:
	## Build a rich system prompt for the Narrator brain.
	var parts: PackedStringArray = []
	parts.append("Tu es le narrateur poetique d'un jeu celtique breton.")
	parts.append("Biome: %s (%s)." % [biome_data.get("name", ""), biome_data.get("subtitle", "")])
	parts.append("Gardien: %s. Ogham: %s. Saison: %s." % [
		biome_data.get("gardien", ""), biome_data.get("ogham", ""), biome_data.get("saison", "")])
	# Atmosphere sensorielle
	var atmo: Dictionary = biome_data.get("atmosphere", {})
	if not atmo.is_empty():
		parts.append("Ambiance: sons=%s, odeurs=%s, lumiere=%s, mood=%s." % [
			atmo.get("sounds", ""), atmo.get("smell", ""), atmo.get("light", ""), atmo.get("mood", "")])
	# Player aspect states
	var store: Node = get_node_or_null("/root/MerlinStore")
	if store and store.has_method("get_all_aspects"):
		var aspects: Dictionary = store.get_all_aspects()
		var aspect_labels: PackedStringArray = []
		for a in MerlinConstants.TRIADE_ASPECTS:
			var st: int = int(aspects.get(a, 0))
			var info: Dictionary = MerlinConstants.TRIADE_ASPECT_INFO.get(a, {})
			var states_dict: Dictionary = info.get("states", {})
			var state_name: String = str(states_dict.get(st, "?"))
			aspect_labels.append("%s=%s" % [a, state_name])
		parts.append("Etat du voyageur: %s." % ", ".join(aspect_labels))
	# Day context
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and "run" in gm:
		var run: Dictionary = gm.run if gm.run is Dictionary else {}
		var day: int = int(run.get("day", 1))
		parts.append("Jour %d de l'expedition." % day)
	parts.append("Ecris 1-2 phrases poetiques en francais. Pas de guillemets.")
	return "\n".join(parts)


func _build_merlin_comment_context() -> String:
	## Build system prompt for Merlin's comment (amused/sage tone).
	var parts: PackedStringArray = []
	parts.append("Tu es Merlin le druide, guide amuse et un peu cynique.")
	parts.append("Biome: %s. Gardien: %s." % [biome_data.get("name", ""), biome_data.get("gardien", "")])
	# Player aspect states
	var store: Node = get_node_or_null("/root/MerlinStore")
	if store and store.has_method("get_all_aspects"):
		var aspects: Dictionary = store.get_all_aspects()
		var aspect_labels: PackedStringArray = []
		for a in MerlinConstants.TRIADE_ASPECTS:
			var st: int = int(aspects.get(a, 0))
			var info: Dictionary = MerlinConstants.TRIADE_ASPECT_INFO.get(a, {})
			var states_dict: Dictionary = info.get("states", {})
			var state_name: String = str(states_dict.get(st, "?"))
			aspect_labels.append("%s=%s" % [a, state_name])
		parts.append("Le voyageur est %s." % ", ".join(aspect_labels))
	# Day context
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and "run" in gm:
		var run: Dictionary = gm.run if gm.run is Dictionary else {}
		var day: int = int(run.get("day", 1))
		parts.append("Jour %d." % day)
	parts.append("Commente en 1 phrase avec ton amuse. Francais uniquement.")
	return "\n".join(parts)


func _build_dealer_monologue_prompt() -> Dictionary:
	## Build system + user prompt for dealer monologue (Hand of Fate 2 style).
	## Returns {"system": ..., "user": ...} using scenario_prompts template.
	var template: Dictionary = {}
	var store: Node = get_node_or_null("/root/MerlinStore")
	if store and store.get("llm") and store.llm.has_method("get_scenario_template"):
		template = store.llm.get_scenario_template("dealer_monologue")

	var system_prompt: String = str(template.get("system", ""))
	var user_template: String = str(template.get("user_template", ""))

	# Fallback if template not loaded
	if system_prompt.is_empty():
		system_prompt = "Tu es Merlin l'Enchanteur, conteur et maitre des cartes. Decris le biome avec tes sens de druide. 4-6 phrases en francais, ton grave et theatral. Pas de guillemets."
	if user_template.is_empty():
		user_template = "Biome: {biome_name}. Gardien: {guardian}. Saison: {season}. Jour {day}. Etat: Corps={corps_state}, Ame={ame_state}, Monde={monde_state}. Souffle={souffle}/7. Genere le monologue du dealer."

	# Collect template variables
	var vars := {}
	vars["biome_name"] = str(biome_data.get("name", "Inconnu"))
	vars["biome_subtitle"] = str(biome_data.get("subtitle", ""))
	vars["guardian"] = str(biome_data.get("gardien", ""))
	vars["ogham"] = str(biome_data.get("ogham", ""))
	vars["season"] = str(biome_data.get("saison", biome_data.get("season_forte", "")))

	# Day
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and "run" in gm:
		var run: Dictionary = gm.run if gm.run is Dictionary else {}
		vars["day"] = str(int(run.get("day", 1)))
	else:
		vars["day"] = "1"

	# Player aspects (reuse store from above)
	vars["corps_state"] = "Equilibre"
	vars["ame_state"] = "Equilibre"
	vars["monde_state"] = "Equilibre"
	vars["souffle"] = "3"
	if store and store.has_method("get_all_aspects"):
		var aspects: Dictionary = store.get_all_aspects()
		for a in MerlinConstants.TRIADE_ASPECTS:
			var st: int = int(aspects.get(a, 0))
			var info: Dictionary = MerlinConstants.TRIADE_ASPECT_INFO.get(a, {})
			var states_dict: Dictionary = info.get("states", {})
			var state_name: String = str(states_dict.get(st, "Equilibre"))
			match a:
				"Corps": vars["corps_state"] = state_name
				"Ame": vars["ame_state"] = state_name
				"Monde": vars["monde_state"] = state_name
	if store and store.has_method("get_state"):
		var state: Dictionary = store.get_state()
		vars["souffle"] = str(int(state.get("souffle", 3)))

	# Replace template variables
	var user_prompt := user_template
	for key in vars:
		user_prompt = user_prompt.replace("{%s}" % key, str(vars[key]))

	# Scenario context injection (Hand of Fate 2-style quest)
	if store and store.has_method("get_scenario_manager"):
		var scenario_mgr = store.get_scenario_manager()
		if scenario_mgr and scenario_mgr.is_scenario_active():
			var override: Dictionary = scenario_mgr.get_dealer_intro_override()
			if not override.is_empty():
				user_prompt += "\nQUETE EN COURS: %s. %s" % [
					str(override.get("title", "")),
					str(override.get("context", ""))
				]
				var scenario_tone: String = str(override.get("tone", ""))
				if not scenario_tone.is_empty():
					user_prompt += " Ton dominant: %s." % scenario_tone

	return {"system": system_prompt, "user": user_prompt}


const FALLBACK_MONOLOGUES := {
	"foret_broceliande": "Les cartes s'agitent sous mes doigts, Voyageur. La foret de Broceliande murmure ton nom entre ses chenes centenaires. L'odeur de mousse et de terre humide monte deja vers toi, comme un souvenir que tu n'as pas encore vecu. Les racines anciennes savent des choses que les pierres ont oubliees. Ton chemin commence ou la brume se dechire.",
	"landes_bruyere": "Ecoute le vent, Voyageur. Les landes de bruyere s'etendent devant toi comme un ocean de solitude violette. Ici les pierres dressees comptent les siecles en silence, et chaque pas crisse sur un secret enterre. Le gardien Talwen observe depuis les hauteurs. Ton ame sera mise a l'epreuve dans cette immensity.",
	"cotes_sauvages": "Sens-tu le sel sur tes levres, Voyageur ? Les cotes sauvages grondent de l'autre cote du voile. Les vagues frappent les falaises comme les battements d'un coeur ancien. Bran le gardien attend au bord de l'ecume. Le monde marin a ses propres regles, et tu devras les apprendre vite.",
	"villages_celtes": "Les flammes dansent dans les villages celtes, Voyageur. L'odeur de tourbe et de pain chaud porte jusqu'ici. Azenor la gardienne veille sur les siens avec une fermete douce. Chaque foyer raconte une histoire, chaque porte cache un choix. Le printemps reveille les esperances et les vieilles querelles.",
	"cercles_pierres": "Le temps hesite entre ces pierres dressees, Voyageur. Les cercles de pierres sont des portes que seuls les inities franchissent. Keridwen la gardienne tisse ses sortileges dans la brume du samhain. Ici l'ame se reflete dans le granit poli par les ages. Choisis bien tes pas.",
	"marais_enchantes": "Les eaux dormantes cachent bien des verites, Voyageur. Les marais enchantes brillent d'une lumiere trompeuse sous la lune. Gwydion le gardien connait chaque sentier entre les roseaux. Le corps s'alourdit dans ces brumes, mais l'esprit s'affute. N'oublie pas de regarder sous la surface.",
	"monts_arree": "Les monts d'Arree se dressent comme les dents d'un monde oublie, Voyageur. Le vent hurle entre les cretes et porte les echos du Yeun Elez. Dahut la gardienne regne sur ces hauteurs ou les nuages rampent comme des serpents. Ici tout est vertical : la montee, la chute, le choix.",
}


func _get_fallback_monologue() -> String:
	## Return a pre-written monologue for the current biome.
	var text: String = str(FALLBACK_MONOLOGUES.get(biome_key, ""))
	if text.is_empty():
		text = "Les cartes du destin s'etalent devant toi, Voyageur. Merlin observe la brume qui se dissipe lentement. Chaque chemin mene quelque part, mais aucun ne ramene au meme endroit. Ton histoire s'ecrit a chaque pas."
	return text


# ═══════════════════════════════════════════════════════════════════════════════
# FALLBACK INTELLIGENT (JSON VARIANTS)
# ═══════════════════════════════════════════════════════════════════════════════

func _get_fallback_text(bkey: String) -> Dictionary:
	## Returns {"arrival": "...", "merlin": "..."} from JSON variants.
	## Selects category based on current aspect states.
	var category := _detect_aspect_category()
	var variants_dict: Dictionary = biome_data.get("variants", {})
	var variants: Array = variants_dict.get(category, [])
	if variants.is_empty():
		# Try balanced as fallback category
		variants = variants_dict.get("balanced", [])
	if variants.is_empty():
		# Ultimate fallback: old single-variant system
		return {"arrival": biome_data.get("arrival_text", ""), "merlin": biome_data.get("merlin_comment", "")}
	var idx: int = _pick_unseen_variant(bkey, category, variants.size())
	var v: Dictionary = variants[idx]
	return {"arrival": str(v.get("arrival", "")), "merlin": str(v.get("merlin", ""))}


func _detect_aspect_category() -> String:
	## Returns "balanced", "corps_extreme", "ame_extreme", or "monde_extreme".
	var store: Node = get_node_or_null("/root/MerlinStore")
	if not store or not store.has_method("get_aspect_state"):
		return "balanced"
	for a in ["Corps", "Ame", "Monde"]:
		var st: int = store.get_aspect_state(a)
		if st != MerlinConstants.AspectState.EQUILIBRE:
			return a.to_lower() + "_extreme"
	return "balanced"


func _pick_unseen_variant(bkey: String, category: String, total: int) -> int:
	## Returns variant index, preferring those not yet seen this session.
	var seen_key := "%s_%s" % [bkey, category]
	if not _seen_variants.has(seen_key):
		_seen_variants[seen_key] = []
	var seen: Array = _seen_variants[seen_key]
	var unseen: Array = []
	for i in range(total):
		if i not in seen:
			unseen.append(i)
	if unseen.is_empty():
		seen.clear()
		for i in range(total):
			unseen.append(i)
	var idx: int = unseen[randi() % unseen.size()]
	seen.append(idx)
	return idx


# ═══════════════════════════════════════════════════════════════════════════════
# LLM PREFETCH + VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

func _start_llm_prefetch() -> void:
	## Fire-and-forget: starts dealer monologue generation while animations play.
	if merlin_ai == null or not merlin_ai.is_ready:
		_prefetch_monologue = {"done": true, "text": "", "source": "fallback"}
		return
	_set_merlin_scene_context("transition_biome_dealer", {
		"phase": "dealer_monologue"
	})
	var prompt_data: Dictionary = _build_dealer_monologue_prompt()
	_async_generate(_prefetch_monologue, prompt_data["system"], prompt_data["user"], 250)


func _async_generate(state: Dictionary, system_prompt: String, user_input: String, max_tokens: int = 80) -> void:
	## Async LLM generation — updates state dict when done with explicit source.
	state["done"] = false
	state["text"] = ""
	state["source"] = "fallback"

	if merlin_ai == null or not merlin_ai.is_ready:
		state["done"] = true
		return

	var result: Dictionary = await merlin_ai.generate_narrative(system_prompt, user_input, {"max_tokens": max_tokens})
	if result.has("error"):
		state["done"] = true
		return

	var text: String = str(result.get("text", ""))
	text = _validate_llm_text(text)
	if not text.is_empty():
		state["text"] = text
		state["source"] = "llm"

	state["done"] = true


func _consume_prefetch(state: Dictionary, fallback_type: String) -> Dictionary:
	## Wait for prefetch result (short cap), then return {"text": ..., "source": "llm"|"fallback"}.
	var wait := 0.0
	while not state.get("done", false) and wait < PREFETCH_WAIT_MAX:
		if not is_inside_tree():
			break
		await _safe_wait(LLM_POLL_INTERVAL)
		wait += LLM_POLL_INTERVAL
	var text: String = str(state.get("text", ""))
	var source: String = str(state.get("source", "fallback"))
	if source != "llm" or text.is_empty():
		if fallback_type == "monologue":
			text = _get_fallback_monologue()
		else:
			var fb := _get_fallback_text(biome_key)
			var legacy_key := "arrival_text" if fallback_type == "arrival" else "merlin_comment"
			text = str(fb.get(fallback_type, biome_data.get(legacy_key, "")))
		source = "fallback"
	return {"text": text, "source": source}


func _validate_llm_text(text: String) -> String:
	## Validate LLM output. Returns "" if invalid (triggers fallback).
	if text.length() < 10 or text.length() > 800:
		return ""
	# Reject if contains common English words
	var lower := text.to_lower()
	for eng_word in ["the ", " and ", " you ", " are ", " this ", " that "]:
		if eng_word in lower:
			return ""
	# Reject if too similar to last text (Jaccard > 0.7)
	if _last_monologue_text != "" and text != "":
		var sim := _jaccard_similarity(text, _last_monologue_text)
		if sim > 0.7:
			return ""
	return text


func _jaccard_similarity(a: String, b: String) -> float:
	## Simple word-level Jaccard similarity.
	var words_a: PackedStringArray = a.to_lower().split(" ", false)
	var words_b: PackedStringArray = b.to_lower().split(" ", false)
	if words_a.is_empty() or words_b.is_empty():
		return 0.0
	var set_a: Dictionary = {}
	for w in words_a:
		set_a[w] = true
	var set_b: Dictionary = {}
	for w in words_b:
		set_b[w] = true
	var intersection: int = 0
	for w in set_a:
		if set_b.has(w):
			intersection += 1
	var union_size: int = set_a.size() + set_b.size() - intersection
	if union_size == 0:
		return 0.0
	return float(intersection) / float(union_size)


# ═══════════════════════════════════════════════════════════════════════════════
# TYPEWRITER
# ═══════════════════════════════════════════════════════════════════════════════

func _show_typewriter(label: RichTextLabel, text: String) -> void:
	typing_active = true
	typing_abort = false

	label.text = text
	label.visible_characters = 0
	for i in range(text.length()):
		if typing_abort or not is_inside_tree():
			break
		label.visible_characters = i + 1
		var ch := text[i]
		if ch != " ":
			_play_blip()
		var delay := TYPEWRITER_DELAY
		if ch in [".", "!", "?"]:
			delay = TYPEWRITER_PUNCT_DELAY
		await _safe_wait(delay)
	label.visible_characters = -1
	typing_active = false


# ═══════════════════════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════════════════════

func _wait_for_advance(max_wait: float) -> void:
	var effective_wait := minf(max_wait, MAX_ADVANCE_WAIT)
	var elapsed := 0.0
	while elapsed < effective_wait and not _advance_requested and not scene_finished:
		if not is_inside_tree():
			break
		await _safe_frame()
		if not is_inside_tree():
			break
		elapsed += get_process_delta_time()
	_advance_requested = false


func _unhandled_input(event: InputEvent) -> void:
	if scene_finished:
		return

	var is_press := false
	if event is InputEventMouseButton and event.pressed:
		is_press = true
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			is_press = true
	elif event is InputEventScreenTouch and event.pressed:
		is_press = true

	if is_press:
		if typing_active:
			typing_abort = true
			if voice_ready and voicebox and voicebox.has_method("stop_speaking"):
				voicebox.stop_speaking()
		else:
			_advance_requested = true
		get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
# AUDIO
# ═══════════════════════════════════════════════════════════════════════════════

func _play_blip() -> void:
	var sample_rate := 44100.0
	var duration := 0.014
	var num_samples := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_rate)
	stream.stereo = false
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var freq := randf_range(260.0, 360.0)
	for s in range(num_samples):
		var t := float(s) / sample_rate
		var envelope := exp(-t * 320.0)
		var click := sin(TAU * freq * t) * 0.35
		var noise := randf_range(-1.0, 1.0) * 0.12
		var value := (click + noise) * envelope * 0.25
		var sample_val := int(clampf(value, -1.0, 1.0) * 32767.0)
		data[s * 2] = sample_val & 0xFF
		data[s * 2 + 1] = (sample_val >> 8) & 0xFF
	stream.data = data
	audio_player.stream = stream
	audio_player.play()
