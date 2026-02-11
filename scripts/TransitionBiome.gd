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

# Biome-specific fog tint and behavior
const FOG_CONFIG := {
	"broceliande": {"tint": Color(0.82, 0.94, 0.84), "direction": Vector3(-0.5, -0.3, 0), "speed": 0.7},
	"landes": {"tint": Color(0.92, 0.88, 0.94), "direction": Vector3(-1, 0.1, 0), "speed": 1.3},
	"cotes": {"tint": Color(0.84, 0.92, 0.98), "direction": Vector3(-1, 0, 0), "speed": 1.5},
	"villages": {"tint": Color(0.98, 0.94, 0.88), "direction": Vector3(0, -1, 0), "speed": 0.5},
	"cercles": {"tint": Color(0.90, 0.90, 0.92), "direction": Vector3(0, 0, 0), "speed": 0.3},
	"marais": {"tint": Color(0.88, 0.94, 0.88), "direction": Vector3(-0.3, 0.5, 0), "speed": 0.6},
	"collines": {"tint": Color(0.94, 0.94, 0.88), "direction": Vector3(-0.7, -0.2, 0), "speed": 0.9},
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
var _arrival_badge: PanelContainer
var _merlin_badge: PanelContainer
var mist_particles: GPUParticles2D
var _mist_layers: Array = []  # Multi-layer fog system
var _volumetric_fog: ColorRect  # Shader-based fog layer
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
# LLM Prefetch state
var _prefetch_arrival: Dictionary = {}
var _prefetch_merlin: Dictionary = {}
var _seen_variants: Dictionary = {}
var _last_arrival_text: String = ""


func _exit_tree() -> void:
	# Kill any active tweens to prevent "data.tree is null" errors
	scene_finished = true
	typing_abort = true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_data()
	_current_grid = _generate_landscape(biome_key)
	_build_ui()
	_setup_audio()
	await _setup_voicebox()
	if not is_inside_tree():
		return
	await _safe_wait(0.3)
	if not is_inside_tree():
		return
	_play_transition()


## Safe helpers — prevent crashes when node exits tree during await
func _safe_wait(seconds: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout

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
}


func _load_data() -> void:
	merlin_ai = get_node_or_null("/root/MerlinAI")
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var run_data: Dictionary = gm.get("run") if gm.get("run") is Dictionary else {}
		var raw_key: String = run_data.get("current_biome", "broceliande")
		# Normalize full biome keys to short keys used by BIOME_COLORS and _generate_landscape
		biome_key = BIOME_KEY_MAP.get(raw_key, raw_key)

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

	# Arrival source badge (dev indicator)
	_arrival_badge = LLMSourceBadge.create("static")
	_arrival_badge.position = Vector2(arrival_text.position.x + arrival_text.custom_minimum_size.x - 60, arrival_text.position.y - 18)
	_arrival_badge.visible = false
	add_child(_arrival_badge)

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

	# Merlin source badge (dev indicator)
	_merlin_badge = LLMSourceBadge.create("static")
	_merlin_badge.position = Vector2(merlin_comment.position.x + merlin_comment.custom_minimum_size.x - 60, merlin_comment.position.y - 18)
	_merlin_badge.visible = false
	add_child(_merlin_badge)

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
	## Multi-layer volumetric fog system with biome-specific tinting.
	var vs := get_viewport_rect().size
	var fog_cfg: Dictionary = FOG_CONFIG.get(biome_key, FOG_CONFIG.broceliande)
	var fog_tint: Color = fog_cfg.get("tint", PALETTE.mist)
	var fog_dir: Vector3 = fog_cfg.get("direction", Vector3(-1, 0, 0))
	var fog_speed: float = fog_cfg.get("speed", 1.0)

	# Create soft circular gradient texture for particles
	var soft_tex := _create_soft_fog_texture(64)

	# Layer definitions: [amount, lifetime, scale_min, scale_max, vel_min, vel_max, opacity, z_index]
	var layers := [
		[20, 6.0, 8.0, 15.0, 10.0, 25.0, 0.40, -2],  # Back: large, slow
		[30, 4.5, 5.0, 10.0, 20.0, 50.0, 0.30, -1],  # Mid: medium, moderate
		[15, 3.0, 3.0, 6.0, 35.0, 70.0, 0.20, 0],     # Front: small, fast
	]

	_mist_layers.clear()
	for layer_def in layers:
		var particles := GPUParticles2D.new()
		particles.amount = int(layer_def[0])
		particles.lifetime = float(layer_def[1])
		particles.position = Vector2(vs.x / 2.0, vs.y * 0.55)
		particles.emitting = false
		particles.z_index = int(layer_def[7])
		particles.texture = soft_tex

		var mat := ParticleProcessMaterial.new()
		mat.direction = fog_dir
		mat.spread = 25.0
		mat.initial_velocity_min = float(layer_def[4]) * fog_speed
		mat.initial_velocity_max = float(layer_def[5]) * fog_speed
		mat.gravity = Vector3.ZERO
		mat.scale_min = float(layer_def[2])
		mat.scale_max = float(layer_def[3])
		var layer_color := Color(fog_tint.r, fog_tint.g, fog_tint.b, float(layer_def[6]))
		mat.color = layer_color

		particles.process_material = mat
		add_child(particles)
		_mist_layers.append(particles)

	# Keep first layer reference for legacy compatibility
	mist_particles = _mist_layers[0] if _mist_layers.size() > 0 else null

	# Shader-based volumetric fog background
	_volumetric_fog = ColorRect.new()
	_volumetric_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_volumetric_fog.z_index = -3
	_volumetric_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fog_shader := Shader.new()
	fog_shader.code = """shader_type canvas_item;
uniform vec4 fog_color : source_color = vec4(0.94, 0.92, 0.88, 0.15);
uniform float fog_density : hint_range(0.0, 1.0) = 0.25;
uniform float time_scale : hint_range(0.0, 2.0) = 0.3;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i); float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0)); float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}
void fragment() {
	vec2 uv = UV;
	float t = TIME * time_scale;
	float n = noise(uv * 4.0 + vec2(t * 0.5, t * 0.3));
	n += noise(uv * 8.0 - vec2(t * 0.3, t * 0.2)) * 0.5;
	n = n / 1.5;
	float vertical_grad = smoothstep(0.0, 0.6, uv.y);
	float fog = n * fog_density * vertical_grad;
	COLOR = vec4(fog_color.rgb, fog_color.a * fog);
}
"""
	var fog_mat := ShaderMaterial.new()
	fog_mat.shader = fog_shader
	fog_mat.set_shader_parameter("fog_color", Color(fog_tint.r, fog_tint.g, fog_tint.b, 0.2))
	fog_mat.set_shader_parameter("fog_density", 0.3)
	fog_mat.set_shader_parameter("time_scale", 0.3)
	_volumetric_fog.material = fog_mat
	_volumetric_fog.modulate.a = 0.0
	add_child(_volumetric_fog)


func _create_soft_fog_texture(tex_size: int) -> GradientTexture2D:
	## Create a soft circular gradient for fog particles.
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 1.0))
	gradient.add_point(0.5, Color(1, 1, 1, 0.5))
	gradient.add_point(1.0, Color(1, 1, 1, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = tex_size
	texture.height = tex_size
	return texture


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

	# Start LLM prefetch immediately — runs in parallel with animations
	_prefetch_arrival = {"done": false, "text": ""}
	_prefetch_merlin = {"done": false, "text": ""}
	_start_llm_prefetch()

	# Phase 1: Brume — mist + scout pixels
	await _phase_brume()

	# Phase 2: Emergence — pixel cascade builds landscape
	await _phase_emergence()

	# Phase 3: Revelation — title + subtitle appear
	await _phase_revelation()

	# Phase 4: Sentier — ink path traces through landscape
	await _phase_sentier()

	# Phase 5: Voix — consume prefetch results (generated during animations)
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("sage")

	var arrival_result: Dictionary = await _consume_prefetch(_prefetch_arrival, "arrival")
	var arrival_str: String = arrival_result.get("text", "")
	_last_arrival_text = arrival_str
	# Show source badge
	if _arrival_badge and is_instance_valid(_arrival_badge):
		LLMSourceBadge.update_badge(_arrival_badge, arrival_result.get("source", "static"))
		_arrival_badge.visible = true
	await _show_typewriter(arrival_text, arrival_str)
	await _safe_wait(0.3)
	_advance_requested = false
	await _wait_for_advance(30.0)

	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("amuse")

	var merlin_result: Dictionary = await _consume_prefetch(_prefetch_merlin, "merlin")
	var merlin_str: String = merlin_result.get("text", "")
	# Show source badge
	if _merlin_badge and is_instance_valid(_merlin_badge):
		LLMSourceBadge.update_badge(_merlin_badge, merlin_result.get("source", "static"))
		_merlin_badge.visible = true
	await _show_typewriter(merlin_comment, merlin_str)
	await _safe_wait(0.3)
	_advance_requested = false
	await _wait_for_advance(30.0)

	# Phase 6: Dissolution — pixels fall away, transition to game
	await _phase_dissolution()


# — Phase 1: Brume ——————————————————————————————————————————————————————————

func _phase_brume() -> void:
	# Activate all fog layers
	for layer in _mist_layers:
		if is_instance_valid(layer):
			layer.emitting = true
	# Fade in volumetric fog shader
	if _volumetric_fog:
		var fog_tw := create_tween()
		fog_tw.tween_property(_volumetric_fog, "modulate:a", 1.0, 1.5)
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

		await _safe_wait(0.06)

	await _safe_wait(0.4)


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
			await _safe_wait(0.025)

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
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(biome_title, "modulate:a", 1.0, 0.8)
	tw.tween_property(biome_subtitle, "modulate:a", 1.0, 0.6)
	await tw.finished
	await _safe_wait(0.3)

	# Camera zoom into landscape using Control.scale
	await _zoom_into_landscape()


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

		await _safe_wait(0.022)

	# Diamond marker at end
	var end_marker := _make_diamond(
		_landscape_origin + Vector2(total_w + 2, total_h - _pixel_size * 2), PALETTE.accent
	)
	add_child(end_marker)
	SFXManager.play("landmark_pop")
	await _safe_wait(0.3)


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
	if path_line:
		text_tw.parallel().tween_property(path_line, "modulate:a", 0.0, 0.3)
	if _volumetric_fog:
		text_tw.parallel().tween_property(_volumetric_fog, "modulate:a", 0.0, 0.3)
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
			await _safe_wait(0.015)

	await _safe_wait(0.6)

	# Final screen fade
	var final_tw := create_tween()
	final_tw.tween_property(self, "modulate:a", 0.0, 0.5)
	final_tw.tween_callback(func():
		if is_inside_tree():
			get_tree().change_scene_to_file(NEXT_SCENE)
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
	# Day, tool, departure condition
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and "run" in gm:
		var run: Dictionary = gm.run if gm.run is Dictionary else {}
		var day: int = int(run.get("day", 1))
		parts.append("Jour %d de l'expedition." % day)
		var tool_id: String = str(run.get("tool", ""))
		if tool_id != "" and MerlinConstants.EXPEDITION_TOOLS.has(tool_id):
			parts.append("Outil: %s." % MerlinConstants.EXPEDITION_TOOLS[tool_id].get("name", ""))
		var cond: String = str(run.get("departure_condition", ""))
		if cond != "" and MerlinConstants.DEPARTURE_CONDITIONS.has(cond):
			parts.append("Condition: %s." % MerlinConstants.DEPARTURE_CONDITIONS[cond].get("name", ""))
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
	# Day and tool context
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and "run" in gm:
		var run: Dictionary = gm.run if gm.run is Dictionary else {}
		var day: int = int(run.get("day", 1))
		parts.append("Jour %d." % day)
		var tool_id: String = str(run.get("tool", ""))
		if tool_id != "" and MerlinConstants.EXPEDITION_TOOLS.has(tool_id):
			parts.append("Outil: %s." % MerlinConstants.EXPEDITION_TOOLS[tool_id].get("name", ""))
	parts.append("Commente en 1 phrase avec ton amuse. Francais uniquement.")
	return "\n".join(parts)


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
	## Fire-and-forget: starts both LLM calls in parallel while animations play.
	if merlin_ai == null or not merlin_ai.is_ready:
		_prefetch_arrival = {"done": true, "text": ""}
		_prefetch_merlin = {"done": true, "text": ""}
		return
	# Arrival text
	var sys_arrival := _build_llm_biome_context()
	var usr_arrival := "Decris l'arrivee du voyageur dans ce biome."
	_async_generate(_prefetch_arrival, sys_arrival, usr_arrival)
	# Merlin comment
	var sys_merlin := _build_merlin_comment_context()
	var usr_merlin := "Commente l'arrivee du voyageur."
	_async_generate(_prefetch_merlin, sys_merlin, usr_merlin)


func _async_generate(state: Dictionary, system_prompt: String, user_input: String) -> void:
	## Async LLM generation — updates state dict when done.
	var result: Dictionary = await merlin_ai.generate_narrative(system_prompt, user_input, {"max_tokens": 80})
	var text: String = str(result.get("text", ""))
	# Validate the generated text
	text = _validate_llm_text(text)
	state["text"] = text
	state["done"] = true


func _consume_prefetch(state: Dictionary, fallback_type: String) -> Dictionary:
	## Wait for prefetch result (max 3s extra), then return {"text": ..., "source": "llm"|"fallback"}.
	var wait := 0.0
	while not state.get("done", false) and wait < 3.0:
		if not is_inside_tree():
			break
		await _safe_wait(0.2)
		wait += 0.2
	var text: String = str(state.get("text", ""))
	var source: String = ""
	if text != "":
		source = "llm"
	else:
		var fb := _get_fallback_text(biome_key)
		text = str(fb.get(fallback_type, biome_data.get("arrival_text", "")))
		source = "fallback"
	return {"text": text, "source": source}


func _validate_llm_text(text: String) -> String:
	## Validate LLM output. Returns "" if invalid (triggers fallback).
	if text.length() < 10 or text.length() > 300:
		return ""
	# Reject if contains common English words
	var lower := text.to_lower()
	for eng_word in ["the ", " and ", " you ", " are ", " this ", " that "]:
		if eng_word in lower:
			return ""
	# Reject if too similar to last text (Jaccard > 0.7)
	if _last_arrival_text != "" and text != "":
		var sim := _jaccard_similarity(text, _last_arrival_text)
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
	var elapsed := 0.0
	while elapsed < max_wait and not _advance_requested and not scene_finished:
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
