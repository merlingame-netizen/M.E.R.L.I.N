## ═══════════════════════════════════════════════════════════════════════════════
## Transition Biome — "Paysage Pixel Émergent"
## ═══════════════════════════════════════════════════════════════════════════════
## 6-phase travel animation: Brume → Émergence → Révélation → Sentier → Voix → Dissolution
## Each biome has a unique pixel-art landscape (32×16) assembled by cascading pixels.
## ═══════════════════════════════════════════════════════════════════════════════

extends Control

const NEXT_SCENE := "res://scenes/TriadeGame.tscn"
const DATA_PATH := "res://data/post_intro_dialogues.json"

const TYPEWRITER_DELAY := 0.025
const TYPEWRITER_PUNCT_DELAY := 0.08
const BLIP_VOLUME := 0.04

const GRID_W := 32
const GRID_H := 16

# ═══════════════════════════════════════════════════════════════════════════════
# PALETTE — Parchemin Mystique Breton
# ═══════════════════════════════════════════════════════════════════════════════

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
	"line": Color(0.40, 0.34, 0.28, 0.12),
	"mist": Color(0.94, 0.92, 0.88, 0.35),
}

# Biome color palettes (7 biomes)
const BIOME_COLORS := {
	"broceliande": {
		"primary": Color(0.18, 0.42, 0.22),
		"secondary": Color(0.35, 0.55, 0.28),
		"accent": Color(0.62, 0.78, 0.42),
	},
	"landes": {
		"primary": Color(0.55, 0.40, 0.52),
		"secondary": Color(0.60, 0.50, 0.36),
		"accent": Color(0.72, 0.52, 0.72),
	},
	"cotes": {
		"primary": Color(0.50, 0.48, 0.42),
		"secondary": Color(0.68, 0.62, 0.52),
		"accent": Color(0.38, 0.58, 0.75),
	},
	"villages": {
		"primary": Color(0.58, 0.44, 0.26),
		"secondary": Color(0.45, 0.38, 0.30),
		"accent": Color(0.82, 0.62, 0.32),
	},
	"cercles": {
		"primary": Color(0.50, 0.48, 0.46),
		"secondary": Color(0.38, 0.35, 0.32),
		"accent": Color(0.72, 0.78, 0.88),
	},
	"marais": {
		"primary": Color(0.28, 0.38, 0.25),
		"secondary": Color(0.22, 0.30, 0.35),
		"accent": Color(0.55, 0.72, 0.48),
	},
	"collines": {
		"primary": Color(0.50, 0.55, 0.33),
		"secondary": Color(0.60, 0.52, 0.40),
		"accent": Color(0.82, 0.55, 0.30),
	},
}

# ═══════════════════════════════════════════════════════════════════════════════
# NODES
# ═══════════════════════════════════════════════════════════════════════════════

var bg: ColorRect
var pixel_container: Control
var path_line: Line2D
var biome_title: Label
var biome_subtitle: Label
var arrival_text: RichTextLabel
var merlin_comment: RichTextLabel
var mist_particles: GPUParticles2D
var audio_player: AudioStreamPlayer

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


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_data()
	_current_grid = _generate_landscape(biome_key)
	_build_ui()
	_setup_audio()
	await _setup_voicebox()
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	_play_transition()


func _load_data() -> void:
	merlin_ai = get_node_or_null("/root/MerlinAI")
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var run_data: Dictionary = gm.get("run") if gm.get("run") is Dictionary else {}
		biome_key = run_data.get("current_biome", "broceliande")

	if FileAccess.file_exists(DATA_PATH):
		var file := FileAccess.open(DATA_PATH, FileAccess.READ)
		var json := JSON.new()
		var err := json.parse(file.get_as_text())
		file.close()
		if err == OK:
			var data: Dictionary = json.data
			biomes_all = data.get("biomes", {})

	biome_data = biomes_all.get(biome_key, {
		"name": "Terre Inconnue",
		"subtitle": "L'Inconnu",
		"arrival_text": "Tu arrives dans un lieu etrange.",
		"merlin_comment": "Eh bien. C'est... quelque chose.",
		"color": "#787870",
	})


func _build_ui() -> void:
	var vs := get_viewport_rect().size

	# Parchment background with shader
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper_shader := load("res://shaders/reigns_paper.gdshader")
	if paper_shader:
		var mat := ShaderMaterial.new()
		mat.shader = paper_shader
		mat.set_shader_parameter("paper_tint", PALETTE.paper)
		mat.set_shader_parameter("grain_strength", 0.025)
		mat.set_shader_parameter("vignette_strength", 0.08)
		mat.set_shader_parameter("vignette_softness", 0.65)
		mat.set_shader_parameter("grain_scale", 1200.0)
		mat.set_shader_parameter("grain_speed", 0.08)
		mat.set_shader_parameter("warp_strength", 0.001)
		bg.material = mat
	else:
		bg.color = PALETTE.paper
	add_child(bg)

	# Mist layer
	var mist_layer := ColorRect.new()
	mist_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	mist_layer.color = PALETTE.mist
	mist_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mist_layer)

	# Celtic ornaments
	var celtic_top := _make_celtic_ornament()
	celtic_top.position = Vector2(0, 20)
	celtic_top.size = Vector2(vs.x, 30)
	add_child(celtic_top)
	var celtic_bottom := _make_celtic_ornament()
	celtic_bottom.position = Vector2(0, vs.y - 50)
	celtic_bottom.size = Vector2(vs.x, 30)
	add_child(celtic_bottom)

	# Pixel container (landscape assembles here)
	pixel_container = Control.new()
	pixel_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	pixel_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pixel_container)

	# Mist particles
	_create_mist_particles()

	# Load fonts
	var title_font: Font = null
	var body_font: Font = null
	if ResourceLoader.exists("res://resources/fonts/morris/MorrisRomanBlack.otf"):
		title_font = load("res://resources/fonts/morris/MorrisRomanBlack.otf")
	elif ResourceLoader.exists("res://resources/fonts/morris/MorrisRomanBlack.ttf"):
		title_font = load("res://resources/fonts/morris/MorrisRomanBlack.ttf")
	if ResourceLoader.exists("res://resources/fonts/morris/MorrisRomanBlackAlt.otf"):
		body_font = load("res://resources/fonts/morris/MorrisRomanBlackAlt.otf")
	elif ResourceLoader.exists("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf"):
		body_font = load("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf")
	if body_font == null:
		body_font = title_font

	# Biome title
	biome_title = Label.new()
	biome_title.text = biome_data.get("name", "")
	biome_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	biome_title.position = Vector2(vs.x / 2.0 - 300, 55)
	biome_title.size = Vector2(600, 50)
	var biome_color_str = biome_data.get("color", "")
	var font_color: Color = PALETTE.accent
	if biome_color_str is String and biome_color_str != "":
		font_color = Color(biome_color_str)
	elif biome_color_str is Color:
		font_color = biome_color_str
	biome_title.add_theme_color_override("font_color", font_color)
	if title_font:
		biome_title.add_theme_font_override("font", title_font)
	biome_title.add_theme_font_size_override("font_size", 32)
	biome_title.modulate.a = 0.0
	add_child(biome_title)

	# Subtitle
	biome_subtitle = Label.new()
	biome_subtitle.text = biome_data.get("subtitle", "")
	biome_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	biome_subtitle.position = Vector2(vs.x / 2.0 - 300, 95)
	biome_subtitle.size = Vector2(600, 30)
	biome_subtitle.add_theme_color_override("font_color", PALETTE.ink_soft)
	if body_font:
		biome_subtitle.add_theme_font_override("font", body_font)
	biome_subtitle.add_theme_font_size_override("font_size", 18)
	biome_subtitle.modulate.a = 0.0
	add_child(biome_subtitle)

	# Arrival text (positioned after landscape is placed)
	arrival_text = RichTextLabel.new()
	arrival_text.bbcode_enabled = true
	arrival_text.fit_content = true
	arrival_text.scroll_active = false
	arrival_text.custom_minimum_size = Vector2(650, 80)
	arrival_text.size = Vector2(650, 80)
	arrival_text.position = Vector2(vs.x / 2.0 - 325, vs.y * 0.72)
	arrival_text.add_theme_color_override("default_color", PALETTE.ink_soft)
	if body_font:
		arrival_text.add_theme_font_override("normal_font", body_font)
	arrival_text.add_theme_font_size_override("normal_font_size", 18)
	arrival_text.visible_characters = 0
	arrival_text.text = ""
	add_child(arrival_text)

	# Merlin comment
	merlin_comment = RichTextLabel.new()
	merlin_comment.bbcode_enabled = true
	merlin_comment.fit_content = true
	merlin_comment.scroll_active = false
	merlin_comment.custom_minimum_size = Vector2(600, 50)
	merlin_comment.size = Vector2(600, 50)
	merlin_comment.position = Vector2(vs.x / 2.0 - 300, vs.y - 130)
	merlin_comment.add_theme_color_override("default_color", PALETTE.ink)
	if body_font:
		merlin_comment.add_theme_font_override("normal_font", body_font)
	merlin_comment.add_theme_font_size_override("normal_font_size", 20)
	merlin_comment.visible_characters = 0
	merlin_comment.text = ""
	add_child(merlin_comment)

	# Audio
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Master"
	audio_player.volume_db = linear_to_db(BLIP_VOLUME)
	add_child(audio_player)


func _make_celtic_ornament() -> Label:
	var lbl := Label.new()
	var pattern := ["\u2500", "\u2022", "\u2500", "\u2500", "\u25C6", "\u2500", "\u2500", "\u2022", "\u2500"]
	var line := ""
	for i in range(40):
		line += pattern[i % pattern.size()]
	lbl.text = line
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", PALETTE.ink_faded)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _create_mist_particles() -> void:
	mist_particles = GPUParticles2D.new()
	mist_particles.amount = 30
	mist_particles.lifetime = 4.0
	var vs := get_viewport_rect().size
	mist_particles.position = Vector2(vs.x / 2.0, vs.y / 2.0)
	mist_particles.emitting = false

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(-1, 0, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	mat.color = PALETTE.mist
	mist_particles.process_material = mat
	add_child(mist_particles)


func _setup_audio() -> void:
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
				await get_tree().process_frame
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
		_:
			_gen_broceliande(g)
	return g


func _gen_broceliande(g: Array) -> void:
	# Dense ancient forest — 4 conifer trees
	_grid_triangle(g, 13, 1, 8, 14, 1)   # Big tree center-left
	_grid_triangle(g, 23, 2, 8, 12, 1)   # Medium tree center-right
	_grid_triangle(g, 5, 4, 8, 8, 1)     # Small tree far-left
	_grid_triangle(g, 29, 5, 8, 6, 1)    # Tiny tree far-right
	# Trunks
	_grid_rect(g, 12, 9, 2, 2, 2)
	_grid_rect(g, 22, 9, 2, 2, 2)
	_grid_rect(g, 4, 9, 2, 2, 2)
	_grid_rect(g, 28, 9, 2, 2, 2)
	# Mossy ground
	_grid_rect(g, 0, 11, GRID_W, 2, 2)
	# Mushrooms
	_grid_dots(g, [[2, 13], [9, 13], [17, 13], [24, 13], [30, 13]], 3)


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
# TRANSITION SEQUENCE — 6 Phases
# ═══════════════════════════════════════════════════════════════════════════════

func _play_transition() -> void:
	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("mystique")

	# Phase 1: Brume — mist + scout pixels
	await _phase_brume()

	# Phase 2: Emergence — pixel cascade builds landscape
	await _phase_emergence()

	# Phase 3: Revelation — title + subtitle appear
	await _phase_revelation()

	# Phase 4: Sentier — ink path traces through landscape
	await _phase_sentier()

	# Phase 5: Voix — LLM narration with JSON fallback
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("narrateur")

	var biome_name: String = biome_data.get("name", "Terre Inconnue")
	var llm_arrival := await _try_llm_transition_text(
		"Tu es le narrateur d'un jeu celtique. Le voyageur arrive dans %s. Decris l'ambiance en 1-2 phrases poetiques. Francais uniquement." % biome_name,
		"Biome: %s. Le voyageur decouvre ce lieu pour la premiere fois." % biome_name
	)
	var text: String = llm_arrival if llm_arrival != "" else biome_data.get("arrival_text", "")
	await _show_typewriter(arrival_text, text)
	await get_tree().create_timer(0.3).timeout
	_advance_requested = false
	await _wait_for_advance(30.0)

	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("amuse")

	var llm_comment := await _try_llm_transition_text(
		"Tu es Merlin le druide. Commente l'arrivee du voyageur dans %s en 1 phrase, ton amuse. Francais uniquement." % biome_name,
		"Le voyageur arrive dans %s." % biome_name
	)
	var comment: String = llm_comment if llm_comment != "" else biome_data.get("merlin_comment", "")
	await _show_typewriter(merlin_comment, comment)
	await get_tree().create_timer(0.3).timeout
	_advance_requested = false
	await _wait_for_advance(30.0)

	# Phase 6: Dissolution — pixels fall away, transition to game
	await _phase_dissolution()


# — Phase 1: Brume ——————————————————————————————————————————————————————————

func _phase_brume() -> void:
	mist_particles.emitting = true
	SFXManager.play("mist_breath")

	var vs := get_viewport_rect().size
	var colors: Dictionary = BIOME_COLORS.get(biome_key, BIOME_COLORS.broceliande)
	var scout_colors: Array[Color] = [colors.primary, colors.secondary, PALETTE.ink_faded]

	# Spawn scout pixels — brief appearances, hinting at what's coming
	for i in range(12):
		var px := ColorRect.new()
		var sz := randf_range(6.0, 10.0)
		px.size = Vector2(sz, sz)
		px.position = Vector2(randf_range(vs.x * 0.2, vs.x * 0.8), -20.0)
		px.color = scout_colors[i % scout_colors.size()]
		px.modulate.a = 0.0
		px.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pixel_container.add_child(px)

		var target_y := randf_range(vs.y * 0.25, vs.y * 0.65)
		var tw := create_tween()
		tw.tween_property(px, "modulate:a", 0.6, 0.08)
		tw.parallel().tween_property(px, "position:y", target_y, randf_range(0.4, 0.8)) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.15)
		tw.tween_property(px, "modulate:a", 0.0, 0.3)
		tw.tween_callback(px.queue_free)

		await get_tree().create_timer(0.06).timeout

	await get_tree().create_timer(0.4).timeout


# — Phase 2: Emergence ——————————————————————————————————————————————————————

func _phase_emergence() -> void:
	var vs := get_viewport_rect().size
	var colors: Dictionary = BIOME_COLORS.get(biome_key, BIOME_COLORS.broceliande)
	var color_map := {1: colors.primary, 2: colors.secondary, 3: colors.accent}

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

	# Collect all active pixels
	var targets: Array[Dictionary] = []
	for row in range(GRID_H):
		for col in range(GRID_W):
			var c: int = _current_grid[row][col]
			if c > 0 and color_map.has(c):
				targets.append({
					"row": row, "col": col,
					"pos": _landscape_origin + Vector2(col * _pixel_size, row * _pixel_size),
					"color": color_map[c],
				})

	# Sort by column for left-to-right wave cascade
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.col != b.col:
			return a.col < b.col
		return a.row > b.row
	)

	_landscape_pixels.clear()
	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		var target_pos: Vector2 = t.pos

		var spawn_x := target_pos.x + randf_range(-25.0, 25.0)
		var spawn_y := -20.0 - randf_range(0.0, 100.0)

		var px := ColorRect.new()
		px.size = Vector2(_pixel_size, _pixel_size)
		px.position = Vector2(spawn_x, spawn_y)
		px.color = t.color
		px.modulate.a = 0.0
		px.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pixel_container.add_child(px)
		_landscape_pixels.append(px)

		var tw := create_tween()
		tw.tween_property(px, "modulate:a", 1.0, 0.05)
		tw.parallel().tween_property(px, "position", target_pos, randf_range(0.3, 0.55)) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

		# Stagger: batch of 4 pixels, then tiny delay
		if i % 4 == 3:
			SFXManager.play_varied("pixel_land", 0.2)
			await get_tree().create_timer(0.025).timeout

	# Settle
	await get_tree().create_timer(0.4).timeout

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
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(biome_title, "modulate:a", 1.0, 0.8)
	tw.tween_property(biome_subtitle, "modulate:a", 1.0, 0.6)
	await tw.finished
	await get_tree().create_timer(0.5).timeout


# — Phase 4: Sentier ———————————————————————————————————————————————————————

func _phase_sentier() -> void:
	var total_w := GRID_W * _pixel_size
	var total_h := GRID_H * _pixel_size
	var path_y := _landscape_origin.y + total_h - _pixel_size * 1.5

	path_line = Line2D.new()
	path_line.width = 2.0
	path_line.default_color = PALETTE.ink
	path_line.antialiased = true
	add_child(path_line)

	# Diamond marker at start
	var start_marker := _make_diamond(_landscape_origin + Vector2(-8, total_h - _pixel_size * 2), PALETTE.accent)
	add_child(start_marker)

	var steps := 35
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var x := _landscape_origin.x + t * total_w
		var y := path_y + sin(t * PI * 3.0) * 3.0
		path_line.add_point(Vector2(x, y))

		if i % 7 == 0:
			SFXManager.play_varied("path_scratch", 0.15)

		await get_tree().create_timer(0.022).timeout

	# Diamond marker at end
	var end_marker := _make_diamond(
		_landscape_origin + Vector2(total_w + 2, total_h - _pixel_size * 2), PALETTE.accent
	)
	add_child(end_marker)
	SFXManager.play("landmark_pop")
	await get_tree().create_timer(0.3).timeout


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


# — Phase 6: Dissolution ——————————————————————————————————————————————————

func _phase_dissolution() -> void:
	SFXManager.play("scene_transition")
	scene_finished = true

	# Fade text and UI elements first
	var text_tw := create_tween()
	text_tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	text_tw.tween_property(arrival_text, "modulate:a", 0.0, 0.3)
	text_tw.parallel().tween_property(merlin_comment, "modulate:a", 0.0, 0.3)
	text_tw.parallel().tween_property(biome_title, "modulate:a", 0.0, 0.3)
	text_tw.parallel().tween_property(biome_subtitle, "modulate:a", 0.0, 0.3)
	if path_line:
		text_tw.parallel().tween_property(path_line, "modulate:a", 0.0, 0.3)
	await text_tw.finished

	# Dissolve landscape — pixels fall away with gravity
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
			await get_tree().create_timer(0.015).timeout

	await get_tree().create_timer(0.6).timeout

	# Final screen fade
	var final_tw := create_tween()
	final_tw.tween_property(self, "modulate:a", 0.0, 0.5)
	final_tw.tween_callback(func():
		get_tree().change_scene_to_file(NEXT_SCENE)
	)


# ═══════════════════════════════════════════════════════════════════════════════
# LLM NARRATION
# ═══════════════════════════════════════════════════════════════════════════════

func _try_llm_transition_text(system_prompt: String, user_input: String) -> String:
	## Attempt LLM narration with 5s timeout. Returns "" on failure.
	if merlin_ai == null or not merlin_ai.is_ready:
		return ""
	var _done := false
	var _result := {}
	var _do := func():
		_result = await merlin_ai.generate_narrative(system_prompt, user_input, {"max_tokens": 60})
		_done = true
	_do.call()
	var elapsed := 0.0
	while not _done and elapsed < 5.0:
		if not is_inside_tree():
			return ""
		await get_tree().create_timer(0.25).timeout
		elapsed += 0.25
	if not _done or _result.has("error"):
		return ""
	var text: String = str(_result.get("text", ""))
	return text if text.length() >= 5 else ""


# ═══════════════════════════════════════════════════════════════════════════════
# TYPEWRITER
# ═══════════════════════════════════════════════════════════════════════════════

func _show_typewriter(label: RichTextLabel, text: String) -> void:
	typing_active = true
	typing_abort = false

	label.text = text
	label.visible_characters = 0
	for i in range(text.length()):
		if typing_abort:
			break
		label.visible_characters = i + 1
		var ch := text[i]
		if ch != " ":
			_play_blip()
		var delay := TYPEWRITER_DELAY
		if ch in [".", "!", "?"]:
			delay = TYPEWRITER_PUNCT_DELAY
		await get_tree().create_timer(delay).timeout
	label.visible_characters = -1
	typing_active = false


# ═══════════════════════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════════════════════

func _wait_for_advance(max_wait: float) -> void:
	var elapsed := 0.0
	while elapsed < max_wait and not _advance_requested and not scene_finished:
		await get_tree().process_frame
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
