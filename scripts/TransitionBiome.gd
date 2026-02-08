## ═══════════════════════════════════════════════════════════════════════════════
## Transition Biome — Travel Animation to Selected Biome
## ═══════════════════════════════════════════════════════════════════════════════
## Shows: map path drawing → biome name/subtitle → arrival text → merlin comment
## Then transitions to TriadeGame with biome context loaded.
## ═══════════════════════════════════════════════════════════════════════════════

extends Control

const NEXT_SCENE := "res://scenes/TriadeGame.tscn"
const DATA_PATH := "res://data/post_intro_dialogues.json"

const TYPEWRITER_DELAY := 0.025
const TYPEWRITER_PUNCT_DELAY := 0.08
const BLIP_FREQ := 880.0
const BLIP_DURATION := 0.018
const BLIP_VOLUME := 0.04

# ═══════════════════════════════════════════════════════════════════════════════
# PALETTE — Parchemin Mystique Breton (shared with all scenes)
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

const PATH_COLOR := Color(0.58, 0.44, 0.26, 0.7)

# Biome-specific color palettes
const BIOME_COLORS := {
	"broceliande": {
		"primary": Color(0.18, 0.42, 0.22),    # Deep forest green
		"secondary": Color(0.35, 0.55, 0.28),   # Moss green
		"accent": Color(0.62, 0.78, 0.42),      # Leaf green
		"mist": Color(0.75, 0.82, 0.70, 0.4),   # Forest mist
	},
	"carnac": {
		"primary": Color(0.52, 0.50, 0.44),     # Standing stone grey
		"secondary": Color(0.68, 0.62, 0.52),   # Lichen
		"accent": Color(0.82, 0.72, 0.48),      # Sandy
		"mist": Color(0.85, 0.82, 0.75, 0.4),
	},
	"avalon": {
		"primary": Color(0.22, 0.35, 0.55),     # Deep water
		"secondary": Color(0.42, 0.55, 0.72),   # Lake blue
		"accent": Color(0.72, 0.82, 0.92),      # Sky
		"mist": Color(0.80, 0.85, 0.92, 0.5),
	},
	"annwn": {
		"primary": Color(0.35, 0.18, 0.42),     # Deep purple
		"secondary": Color(0.52, 0.30, 0.55),   # Twilight
		"accent": Color(0.72, 0.55, 0.78),      # Ethereal
		"mist": Color(0.78, 0.72, 0.85, 0.5),
	},
}

# Biome icon patterns (8x8 grids, 1 = pixel, 0 = empty)
const BIOME_ICONS := {
	"broceliande": [  # Tree
		[0,0,0,1,1,0,0,0],
		[0,0,1,1,1,1,0,0],
		[0,1,1,1,1,1,1,0],
		[1,1,1,1,1,1,1,1],
		[0,1,1,1,1,1,1,0],
		[0,0,0,1,1,0,0,0],
		[0,0,0,1,1,0,0,0],
		[0,0,1,1,1,1,0,0],
	],
	"carnac": [  # Standing stone
		[0,0,1,1,1,1,0,0],
		[0,1,1,1,1,1,1,0],
		[0,1,1,1,1,1,1,0],
		[0,1,1,1,1,1,1,0],
		[0,1,1,1,1,1,1,0],
		[0,1,1,1,1,1,1,0],
		[1,1,1,1,1,1,1,1],
		[1,1,1,1,1,1,1,1],
	],
	"avalon": [  # Wave/island
		[0,0,0,1,1,0,0,0],
		[0,0,1,1,1,1,0,0],
		[0,1,1,1,1,1,1,0],
		[0,0,1,1,1,1,0,0],
		[1,0,0,1,1,0,0,1],
		[1,1,0,0,0,0,1,1],
		[0,1,1,0,0,1,1,0],
		[0,0,1,1,1,1,0,0],
	],
	"annwn": [  # Portal/spiral
		[0,0,1,1,1,1,0,0],
		[0,1,0,0,0,0,1,0],
		[1,0,0,1,1,0,0,1],
		[1,0,1,0,0,1,0,1],
		[1,0,1,0,0,1,0,1],
		[1,0,0,1,1,0,0,1],
		[0,1,0,0,0,0,1,0],
		[0,0,1,1,1,1,0,0],
	],
}

# ═══════════════════════════════════════════════════════════════════════════════
# NODES
# ═══════════════════════════════════════════════════════════════════════════════

var bg: ColorRect
var path_line: Line2D
var biome_title: Label
var biome_subtitle: Label
var arrival_text: RichTextLabel
var merlin_comment: RichTextLabel
var mist_particles: GPUParticles2D
var audio_player: AudioStreamPlayer
var pixel_container: Control
var landmark_container: Control

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

# Voicebox
var voicebox: Node = null
var voice_ready: bool = false


func _ready() -> void:
	_load_data()
	_build_ui()
	_setup_audio()
	await _setup_voicebox()

	await get_tree().create_timer(0.3).timeout
	_play_transition()


func _load_data() -> void:
	# Get biome from GameManager
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var run_data: Dictionary = gm.get("run") if gm.get("run") is Dictionary else {}
		biome_key = run_data.get("current_biome", "broceliande")

	# Load dialogue data
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
		"map_position": [0.5, 0.5],
	})


func _build_ui() -> void:
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
	celtic_top.size = Vector2(get_viewport_rect().size.x, 30)
	add_child(celtic_top)
	var celtic_bottom := _make_celtic_ornament()
	celtic_bottom.position = Vector2(0, get_viewport_rect().size.y - 50)
	celtic_bottom.size = Vector2(get_viewport_rect().size.x, 30)
	add_child(celtic_bottom)

	# Landmark container (map points)
	landmark_container = Control.new()
	landmark_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	landmark_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(landmark_container)

	# Path line (animated) — ink-colored on parchment
	path_line = Line2D.new()
	path_line.width = 2.5
	path_line.default_color = PATH_COLOR
	path_line.antialiased = true
	add_child(path_line)

	# Pixel cascade container (for biome icon materialization)
	pixel_container = Control.new()
	pixel_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	pixel_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pixel_container)

	# Mist particles (subtle, parchment-tinted)
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

	# Biome title (centered, large)
	biome_title = Label.new()
	biome_title.text = biome_data.get("name", "")
	biome_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	biome_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	biome_title.position = Vector2(-300, 80)
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
	biome_subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	biome_subtitle.position = Vector2(-300, 125)
	biome_subtitle.size = Vector2(600, 30)
	biome_subtitle.add_theme_color_override("font_color", PALETTE.ink_soft)
	if body_font:
		biome_subtitle.add_theme_font_override("font", body_font)
	biome_subtitle.add_theme_font_size_override("font_size", 18)
	biome_subtitle.modulate.a = 0.0
	add_child(biome_subtitle)

	# Arrival text
	arrival_text = RichTextLabel.new()
	arrival_text.bbcode_enabled = true
	arrival_text.fit_content = true
	arrival_text.scroll_active = false
	arrival_text.set_anchors_preset(Control.PRESET_CENTER)
	arrival_text.custom_minimum_size = Vector2(650, 80)
	arrival_text.size = Vector2(650, 80)
	arrival_text.position = Vector2(-325, -20)
	arrival_text.add_theme_color_override("default_color", PALETTE.ink_soft)
	if body_font:
		arrival_text.add_theme_font_override("normal_font", body_font)
	arrival_text.add_theme_font_size_override("normal_font_size", 18)
	arrival_text.visible_characters = 0
	arrival_text.text = ""
	add_child(arrival_text)

	# Merlin comment (below)
	merlin_comment = RichTextLabel.new()
	merlin_comment.bbcode_enabled = true
	merlin_comment.fit_content = true
	merlin_comment.scroll_active = false
	merlin_comment.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	merlin_comment.custom_minimum_size = Vector2(600, 50)
	merlin_comment.size = Vector2(600, 50)
	merlin_comment.position = Vector2(-300, -120)
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
	mist_particles.position = Vector2(400, 300)
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
	pass  # audio_player created in _build_ui


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
# TRANSITION SEQUENCE
# ═══════════════════════════════════════════════════════════════════════════════

func _play_transition() -> void:
	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("mystique")

	# Phase 1: Draw path on screen
	await _animate_path()

	# Phase 2: Start mist
	mist_particles.emitting = true

	# Phase 3: Show biome title + subtitle
	await _show_biome_title()

	# Phase 4: Show arrival text (narration) — click to show, click to advance
	var text: String = biome_data.get("arrival_text", "")
	await _show_typewriter(arrival_text, text)
	await get_tree().create_timer(0.3).timeout
	_advance_requested = false
	await _wait_for_advance(30.0)

	# Phase 5: Merlin comment
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("amuse")

	var comment: String = biome_data.get("merlin_comment", "")
	await _show_typewriter(merlin_comment, comment)
	await get_tree().create_timer(0.3).timeout
	_advance_requested = false
	await _wait_for_advance(30.0)

	# Phase 6: Transition to gameplay
	await _fade_to_game()


func _animate_path() -> void:
	var viewport_size := get_viewport_rect().size
	# Start from bottom-left (Antre de Merlin) to biome position
	var start := Vector2(viewport_size.x * 0.15, viewport_size.y * 0.75)
	var biome_pos: Array = biome_data.get("map_position", [0.7, 0.3])
	var target := Vector2(biome_pos[0] * viewport_size.x, biome_pos[1] * viewport_size.y)

	# Place starting landmark (Antre)
	_add_landmark(start, "Antre", PALETTE.accent)

	# Waypoints along the path
	var waypoints := ["Lande", "Gue", "Sentier"]
	var control := (start + target) / 2.0 + Vector2(randf_range(-80, 80), randf_range(-120, -60))
	var steps := 40

	# Animate path drawing with subtle wobble
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := _bezier(start, control, target, t)
		# Subtle hand-drawn wobble
		p += Vector2(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2))
		path_line.add_point(p)

		# Add waypoint landmarks at 25%, 50%, 75%
		if i == steps / 4:
			_add_landmark(p, waypoints[0], PALETTE.ink_faded)
		elif i == steps / 2:
			_add_landmark(p, waypoints[1], PALETTE.ink_faded)
		elif i == steps * 3 / 4:
			_add_landmark(p, waypoints[2], PALETTE.ink_faded)

		# Play tiny tick at waypoints
		if i % 10 == 0:
			_play_blip()

		await get_tree().create_timer(0.025).timeout

	# Place destination landmark with biome color
	var colors: Dictionary = BIOME_COLORS.get(biome_key, BIOME_COLORS.broceliande)
	_add_landmark(target, biome_data.get("name", "?"), colors.primary)

	# Phase 1.5: Pixel cascade builds biome icon at destination
	await _animate_biome_icon(target, colors)


func _add_landmark(pos: Vector2, label_text: String, color: Color) -> void:
	# Diamond marker
	var marker := ColorRect.new()
	marker.size = Vector2(8, 8)
	marker.position = pos - Vector2(4, 4)
	marker.color = color
	marker.rotation = PI / 4.0
	marker.pivot_offset = Vector2(4, 4)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.modulate.a = 0.0
	landmark_container.add_child(marker)

	# Label
	var lbl := Label.new()
	lbl.text = label_text
	lbl.position = pos + Vector2(8, -8)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a = 0.0
	landmark_container.add_child(lbl)

	# Fade in
	var tw := create_tween()
	tw.tween_property(marker, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(lbl, "modulate:a", 0.7, 0.4)


func _animate_biome_icon(center: Vector2, colors: Dictionary) -> void:
	## Build the biome icon from falling micro-pixels (CeltOS style).
	var icon_grid: Array = BIOME_ICONS.get(biome_key, BIOME_ICONS.broceliande)
	var pixel_size := 6.0
	var grid_size := 8
	var origin := center - Vector2(grid_size * pixel_size / 2.0, grid_size * pixel_size / 2.0 + 40)

	# Collect target positions for all filled pixels
	var targets: Array[Dictionary] = []
	for row in range(grid_size):
		for col in range(grid_size):
			if icon_grid[row][col] == 1:
				targets.append({
					"row": row, "col": col,
					"pos": origin + Vector2(col * pixel_size, row * pixel_size),
				})

	# Shuffle for random arrival order
	targets.shuffle()

	# Spawn pixels from random top positions, cascade down to target
	var color_pool: Array[Color] = [colors.primary, colors.secondary, colors.accent]
	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		var target_pos: Vector2 = t.pos

		# Start position: random X near target, well above
		var spawn_x := target_pos.x + randf_range(-40, 40)
		var spawn_y := target_pos.y - randf_range(80, 200)

		var px := ColorRect.new()
		px.size = Vector2(pixel_size, pixel_size)
		px.position = Vector2(spawn_x, spawn_y)
		px.color = color_pool[i % color_pool.size()]
		px.modulate.a = 0.0
		px.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pixel_container.add_child(px)

		# Cascade tween: appear + fall to target
		var tw := create_tween()
		var fall_time := randf_range(0.25, 0.5)
		tw.tween_property(px, "modulate:a", 1.0, 0.05)
		tw.parallel().tween_property(px, "position", target_pos, fall_time).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

		# Stagger spawns (3-4 pixels per frame batch)
		if i % 3 == 2:
			await get_tree().create_timer(0.04).timeout

	# Let icon settle
	await get_tree().create_timer(0.5).timeout

	# Subtle pulse glow on completed icon
	var glow := create_tween()
	glow.tween_property(pixel_container, "modulate:a", 0.5, 0.3)
	glow.tween_property(pixel_container, "modulate:a", 1.0, 0.3)
	glow.tween_property(pixel_container, "modulate:a", 0.5, 0.3)
	glow.tween_property(pixel_container, "modulate:a", 1.0, 0.3)
	await glow.finished


func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 := p0.lerp(p1, t)
	var q1 := p1.lerp(p2, t)
	return q0.lerp(q1, t)


func _show_biome_title() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(biome_title, "modulate:a", 1.0, 0.8)
	tween.tween_property(biome_subtitle, "modulate:a", 1.0, 0.6)
	await tween.finished
	await get_tree().create_timer(1.0).timeout


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


func _fade_to_game() -> void:
	scene_finished = true

	# Fade out all elements
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(path_line, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(landmark_container, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(pixel_container, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(biome_title, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(biome_subtitle, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(arrival_text, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(merlin_comment, "modulate:a", 0.0, 0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(NEXT_SCENE)
	)


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


func _play_blip() -> void:
	## Soft keyboard click — procedural
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
