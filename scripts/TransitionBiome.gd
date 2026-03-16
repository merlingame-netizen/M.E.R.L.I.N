## ═══════════════════════════════════════════════════════════════════════════════
## Transition Biome — "Paysage Pixel Émergent"
## ═══════════════════════════════════════════════════════════════════════════════
## 6-phase travel animation: Brume → Émergence → Révélation → Sentier → Voix → Dissolution
## Each biome has a unique pixel-art landscape (32×16) assembled by cascading pixels.
##
## Delegates to modules:
##   TransitionBiomeLandscape  — grid generation + biome stages
##   TransitionBiomeWeather    — weather overlay, solar clock
##   TransitionBiomeCards      — LLM card generation + text processing
##   TransitionBiomeLLM        — LLM context, prefetch, validation, fallbacks
##   TransitionBiomeQuestUI    — quest preparation UI, dice minigame
## ═══════════════════════════════════════════════════════════════════════════════

extends Control

const NEXT_SCENE := "res://scenes/MerlinGame.tscn"
const DATA_PATH := "res://data/post_intro_dialogues.json"

const ANIMATION_SPEED_FACTOR := 1.7
const TYPEWRITER_DELAY := 0.016
const TYPEWRITER_PUNCT_DELAY := 0.045
const BLIP_VOLUME := 0.04
const MAX_ADVANCE_WAIT := 16.0

const GRID_W := 32
const GRID_H := 16

const QUEST_TREE_W := 10
const QUEST_TREE_H := 14

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

# ═══════════════════════════════════════════════════════════════════════════════
# MODULES (instantiated in _ready)
# ═══════════════════════════════════════════════════════════════════════════════

var _landscape_mod: TransitionBiomeLandscape
var _weather_mod: TransitionBiomeWeather
var _cards_mod: TransitionBiomeCards
var _llm_mod: TransitionBiomeLLM
var _quest_ui_mod: TransitionBiomeQuestUI

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

# Quest preparation state
var _quest_button: Button = null
var _quest_tree_container: Control = null
var _quest_tree_pixel_nodes: Array = []
var _quest_progress_label: Label = null
var _prerun_cards: Array = []
var _cards_generated: bool = false

# Weather state (delegated timer)
var _weather_check_timer: float = 0.0


func _exit_tree() -> void:
	scene_finished = true
	typing_abort = true
	_clear_merlin_scene_context()


func _ready() -> void:
	# Instantiate modules
	_landscape_mod = TransitionBiomeLandscape.new()
	_weather_mod = TransitionBiomeWeather.new()
	_llm_mod = TransitionBiomeLLM.new()
	_cards_mod = TransitionBiomeCards.new(_weather_mod)
	_quest_ui_mod = TransitionBiomeQuestUI.new()

	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_data()
	_current_grid = _landscape_mod.generate_landscape(biome_key)
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
		_weather_mod.apply_weather_for_hour(int(now.get("hour", 12)), false, self, _weather_overlay, pixel_container)
	_weather_mod.update_solar_clock(_clock_panel, _clock_label, self)
	_weather_mod.process_storm_flash(delta, _weather_overlay)


## Safe helpers — prevent crashes when node exits tree during await
func _safe_wait(seconds: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(maxf(0.01, seconds / ANIMATION_SPEED_FACTOR)).timeout

func _safe_frame() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame


# ═══════════════════════════════════════════════════════════════════════════════
# DATA LOADING
# ═══════════════════════════════════════════════════════════════════════════════

func _load_data() -> void:
	merlin_ai = get_node_or_null("/root/MerlinAI")
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var run_data: Dictionary = gm.get("run") if gm.get("run") is Dictionary else {}
		var raw_key: String = run_data.get("current_biome", "broceliande")
		biome_key = BIOME_KEY_MAP.get(raw_key, raw_key)
	MerlinVisual.apply_biome_crt(biome_key)

	if FileAccess.file_exists(DATA_PATH):
		var file := FileAccess.open(DATA_PATH, FileAccess.READ)
		var json := JSON.new()
		var err := json.parse(file.get_as_text())
		file.close()
		if err == OK:
			var data: Dictionary = json.data
			biomes_all = data.get("biomes", {})

	biome_data = biomes_all.get(biome_key, {})
	if biome_data.is_empty():
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


# ═══════════════════════════════════════════════════════════════════════════════
# UI CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

func _configure_ui() -> void:
	var vs := get_viewport_rect().size

	bg.material = null
	bg.color = MerlinVisual.CRT_PALETTE.bg_dark

	_configure_celtic_ornament($CelticTop, Vector2(0, 20), Vector2(vs.x, 30))
	_configure_celtic_ornament($CelticBottom, Vector2(0, vs.y - 50), Vector2(vs.x, 30))

	_weather_mod.configure_weather_system(_weather_overlay, _clock_panel, _clock_label, self, pixel_container)

	var title_font: Font = MerlinVisual.get_font("title")
	var body_font: Font = MerlinVisual.get_font("body")
	if body_font == null:
		body_font = title_font

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

	biome_subtitle.text = biome_data.get("subtitle", "")
	biome_subtitle.position = Vector2(vs.x / 2.0 - 300, 95)
	biome_subtitle.size = Vector2(600, 30)
	biome_subtitle.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	if body_font:
		biome_subtitle.add_theme_font_override("font", body_font)

	arrival_text.size = Vector2(680, 200)
	arrival_text.position = Vector2(vs.x / 2.0 - 340, vs.y * 0.65)
	arrival_text.add_theme_color_override("default_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	if body_font:
		arrival_text.add_theme_font_override("normal_font", body_font)
	arrival_text.add_theme_font_size_override("normal_font_size", 18)

	merlin_comment.size = Vector2(600, 50)
	merlin_comment.position = Vector2(vs.x / 2.0 - 300, vs.y - 130)
	merlin_comment.add_theme_color_override("default_color", MerlinVisual.CRT_PALETTE.phosphor)
	if body_font:
		merlin_comment.add_theme_font_override("normal_font", body_font)
	merlin_comment.add_theme_font_size_override("normal_font_size", 20)

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


func _configure_audio() -> void:
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
# TRANSITION SEQUENCE — 6 Phases
# ═══════════════════════════════════════════════════════════════════════════════

func _play_transition() -> void:
	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("mystique")

	_prefetch_monologue = {"done": false, "text": "", "source": "pending"}
	_set_merlin_scene_context("transition_biome_dealer", {"phase": "dealer_monologue"})
	_llm_mod.start_llm_prefetch(_prefetch_monologue, merlin_ai, biome_data, biome_key)

	var _now_setup := Time.get_datetime_dict_from_system()
	_weather_mod.apply_weather_for_hour(int(_now_setup.get("hour", 12)), false, self, _weather_overlay, pixel_container)
	if biome_subtitle and is_instance_valid(biome_subtitle):
		biome_subtitle.visible = false
	if arrival_text and is_instance_valid(arrival_text):
		arrival_text.visible = false
	if merlin_comment and is_instance_valid(merlin_comment):
		merlin_comment.visible = false

	await _phase_emergence()
	await _phase_revelation()
	await _phase_sentier()
	await _phase_quest_preparation()
	await _phase_dissolution()


# — Phase 1: Brume ——————————————————————————————————————————————————————————

func _phase_brume() -> void:
	var now := Time.get_datetime_dict_from_system()
	_weather_mod.apply_weather_for_hour(int(now.get("hour", 12)), false, self, _weather_overlay, pixel_container)
	_weather_mod.update_solar_clock(_clock_panel, _clock_label, self)
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

	_pixel_size = floor(vs.x * 0.48 / float(GRID_W))
	_pixel_size = clampf(_pixel_size, 6.0, 16.0)

	var total_w := GRID_W * _pixel_size
	var total_h := GRID_H * _pixel_size
	_landscape_origin = Vector2(
		(vs.x - total_w) / 2.0,
		(vs.y - total_h) / 2.0 + 25.0
	)

	arrival_text.position.y = _landscape_origin.y + total_h + 15.0
	_weather_mod.layout_solar_arc_geometry(_clock_panel, self)

	_landscape_pixels.clear()

	var stages: Array = _landscape_mod.get_biome_stages(biome_key)
	for stage_idx in range(stages.size()):
		await _cascade_landscape_stage(stages[stage_idx])
		if stage_idx < stages.size() - 1:
			await _safe_wait(0.15)

	await _safe_wait(0.4)

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
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(biome_title, "modulate:a", 1.0, 0.8)
	await tw.finished

	var bcolors: Dictionary = MerlinVisual.BIOME_COLORS.get(biome_key, MerlinVisual.BIOME_COLORS.broceliande)
	var tint: Color = bcolors.primary
	tint.a = 1.0
	var tc: Tween = create_tween()
	tc.tween_property(biome_title, "modulate", tint, 0.25).set_ease(Tween.EASE_OUT)
	tc.tween_property(biome_title, "modulate", Color.WHITE, 0.30).set_ease(Tween.EASE_IN)
	biome_title.pivot_offset = biome_title.size / 2.0
	var sp: Tween = create_tween()
	sp.tween_property(biome_title, "scale", Vector2(1.05, 1.05), 0.35).set_ease(Tween.EASE_OUT)
	sp.tween_property(biome_title, "scale", Vector2(1.0, 1.0), 0.45).set_ease(Tween.EASE_IN_OUT)

	await _safe_wait(0.3)


func _zoom_into_landscape() -> void:
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
	_weather_mod.update_solar_clock(_clock_panel, _clock_label, self)

	if _clock_panel and is_instance_valid(_clock_panel):
		var clock_tw := create_tween()
		clock_tw.tween_property(_clock_panel, "modulate:a", 1.0, 0.22)
		await clock_tw.finished

	_weather_mod.update_solar_clock(_clock_panel, _clock_label, self)
	await _safe_wait(0.15)


func _make_diamond(pos: Vector2, color: Color) -> ColorRect:
	var marker := ColorRect.new()
	marker.size = Vector2(8, 8)
	marker.position = pos - Vector2(4, 4)
	marker.color = color
	marker.rotation = PI / 4.0
	marker.pivot_offset = Vector2(4, 4)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(marker, "modulate:a", 1.0, 0.3)
	return marker


# ═══════════════════════════════════════════════════════════════════════════════
# QUEST PREPARATION — Pre-generate cards with growing tree animation
# ═══════════════════════════════════════════════════════════════════════════════

func _phase_quest_preparation() -> void:
	var vs := get_viewport_rect().size
	_cards_generated = false

	if biome_title and is_instance_valid(biome_title):
		var title_tw := create_tween()
		title_tw.tween_property(biome_title, "modulate:a", 0.25, 0.4)
		await title_tw.finished

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

	if merlin_ai and not merlin_ai.get("is_ready"):
		if merlin_ai.has_method("ensure_ready"):
			merlin_ai.ensure_ready()
		elif merlin_ai.has_method("start_warmup"):
			merlin_ai.start_warmup()

	_prerun_cards.clear()
	_generate_cards_background()

	var cards_gen_ref: Array = [false]
	var mg_result: Dictionary = await _quest_ui_mod.show_de_du_destin_minigame(vs, self, biome_key, cards_gen_ref)
	var faveurs_earned: int = mg_result.get("faveurs", MerlinConstants.FAVEURS_PER_MINIGAME_PLAY)

	var store: Node = get_node_or_null("/root/MerlinStore")
	if store and store.has_method("dispatch"):
		store.dispatch({"type": "FAVEUR_ADD", "amount": faveurs_earned})

	await _quest_ui_mod.show_faveur_reward(vs, faveurs_earned, self)

	var wait_time: float = 0.0
	while not _cards_generated and wait_time < 120.0:
		if scene_finished or not is_inside_tree():
			break
		if _quest_progress_label and is_instance_valid(_quest_progress_label):
			_quest_progress_label.text = "Merlin tisse le destin..."
		await _safe_wait(0.5)
		wait_time += 0.5

	if _quest_progress_label and is_instance_valid(_quest_progress_label):
		_quest_progress_label.text = "Le destin est tisse."
	SFXManager.play("magic_reveal")
	await _safe_wait(0.5)

	await _llm_mod.generate_run_intro(merlin_ai, biome_data, biome_key)

	var fade_tw := create_tween()
	fade_tw.tween_property(_quest_progress_label, "modulate:a", 0.0, 0.3)
	await fade_tw.finished
	if _quest_progress_label and is_instance_valid(_quest_progress_label):
		_quest_progress_label.queue_free()
		_quest_progress_label = null


func _generate_cards_background() -> void:
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

	for i in range(TransitionBiomeCards.PRERUN_CARD_COUNT):
		if not is_inside_tree():
			break
		if _quest_progress_label and is_instance_valid(_quest_progress_label):
			_quest_progress_label.text = "Tissage %d/%d..." % [i + 1, TransitionBiomeCards.PRERUN_CARD_COUNT]
		var card: Dictionary = await _cards_mod.generate_prerun_card(i, merlin_ai, biome_data, biome_key)
		if not card.is_empty():
			_prerun_cards.append(card)
			_cards_mod.save_prerun_cards(_prerun_cards)
			print("[TransitionBiome] BG: card %d/%d saved (%d total)" % [i + 1, TransitionBiomeCards.PRERUN_CARD_COUNT, _prerun_cards.size()])
		if is_inside_tree() and not scene_finished:
			SFXManager.play_varied("pixel_land", 0.3)

	_cards_generated = true
	print("[TransitionBiome] BG: generation complete, %d cartes saved." % _prerun_cards.size())


# ═══════════════════════════════════════════════════════════════════════════════
# PIXEL CASCADE ANIMATION
# ═══════════════════════════════════════════════════════════════════════════════

func _cascade_landscape_stage(stage_pixels: Array) -> void:
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


func _cascade_tree_stage(stage_pixels: Array, vs: Vector2) -> void:
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


# — Phase 6: Dissolution ——————————————————————————————————————————————————

func _phase_dissolution() -> void:
	SFXManager.play("scene_transition")
	SFXManager.play("pixel_scatter")
	SFXManager.play("biome_dissolve")
	scene_finished = true

	if pixel_container and pixel_container.scale != Vector2.ONE:
		var reset_tw := create_tween()
		reset_tw.tween_property(pixel_container, "scale", Vector2.ONE, 0.3)
		await reset_tw.finished

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

		if i % 6 == 5:
			await _safe_wait(0.015)

	await _safe_wait(0.6)

	var final_tw := create_tween()
	final_tw.tween_property(self, "modulate:a", 0.0, 0.5)
	final_tw.tween_callback(func():
		_clear_merlin_scene_context()
		if is_inside_tree():
			PixelTransition.transition_to(NEXT_SCENE)
	)


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


func _play_blip() -> void:
	SFXManager.play("click")
