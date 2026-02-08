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
# PALETTE
# ═══════════════════════════════════════════════════════════════════════════════

const BG_COLOR := Color("#181810")
const MIST_COLOR := Color(0.8, 0.8, 0.85, 0.15)
const PATH_COLOR := Color("#f8a850")
const TEXT_COLOR := Color("#e8e8e8")
const TEXT_DIM := Color("#b8b0a0")

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
	_setup_voicebox()

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
	# Background
	bg = ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Path line (animated)
	path_line = Line2D.new()
	path_line.width = 3.0
	path_line.default_color = PATH_COLOR
	path_line.antialiased = true
	add_child(path_line)

	# Mist particles
	_create_mist_particles()

	# Biome title (centered, large)
	biome_title = Label.new()
	biome_title.text = biome_data.get("name", "")
	biome_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	biome_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	biome_title.position = Vector2(-300, 80)
	biome_title.size = Vector2(600, 50)
	biome_title.add_theme_color_override("font_color", Color(biome_data.get("color", "#e8e8e8")))
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
	biome_subtitle.add_theme_color_override("font_color", TEXT_DIM)
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
	arrival_text.add_theme_color_override("default_color", TEXT_DIM)
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
	merlin_comment.add_theme_color_override("default_color", TEXT_COLOR)
	merlin_comment.add_theme_font_size_override("normal_font_size", 20)
	merlin_comment.visible_characters = 0
	merlin_comment.text = ""
	add_child(merlin_comment)

	# Audio
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Master"
	audio_player.volume_db = linear_to_db(BLIP_VOLUME)
	add_child(audio_player)


func _create_mist_particles() -> void:
	mist_particles = GPUParticles2D.new()
	mist_particles.amount = 30
	mist_particles.lifetime = 4.0
	mist_particles.set_anchors_preset(Control.PRESET_CENTER)
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
	mat.color = MIST_COLOR
	mist_particles.process_material = mat

	add_child(mist_particles)


func _setup_audio() -> void:
	pass  # audio_player created in _build_ui


func _setup_voicebox() -> void:
	var script_path := "res://addons/ac_voicebox/ac_voicebox.gd"
	if ResourceLoader.exists(script_path):
		var scr = load(script_path)
		if scr:
			voicebox = scr.new()
			voicebox.set("pitch", 2.5)
			voicebox.set("pitch_variation", 0.12)
			voicebox.set("speed_scale", 0.65)
			add_child(voicebox)
			voice_ready = true


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

	# Phase 4: Show arrival text (narration)
	var text: String = biome_data.get("arrival_text", "")
	await _show_typewriter(arrival_text, text)
	await _wait_for_advance(3.0)

	# Phase 5: Merlin comment
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("amuse")

	var comment: String = biome_data.get("merlin_comment", "")
	await _show_typewriter(merlin_comment, comment)
	await _wait_for_advance(2.5)

	# Phase 6: Transition to gameplay
	await _fade_to_game()


func _animate_path() -> void:
	# Draw a curved path from center (Antre) to biome position
	var viewport_size := get_viewport_rect().size
	var start := viewport_size / 2.0
	var biome_pos: Array = biome_data.get("map_position", [0.5, 0.5])
	var target := Vector2(biome_pos[0] * viewport_size.x, biome_pos[1] * viewport_size.y)

	# Generate bezier points
	var control := (start + target) / 2.0 + Vector2(0, -100)
	var steps := 30

	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := _bezier(start, control, target, t)
		path_line.add_point(p)
		await get_tree().create_timer(0.03).timeout

	# Pulse at destination
	await get_tree().create_timer(0.3).timeout


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

	if voice_ready and voicebox:
		if voicebox.has_method("stop_speaking"):
			voicebox.stop_speaking()
		voicebox.set("text_label", label)
		voicebox.play_string(text)
		await voicebox.finished_phrase
		typing_active = false
		return

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

	# Fade background to biome color
	var target_color := Color(biome_data.get("color", "#181810"))
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(bg, "color", target_color, 0.8)
	tween.parallel().tween_property(path_line, "modulate:a", 0.0, 0.6)
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
	var sample_rate := 44100.0
	var num_samples := int(sample_rate * BLIP_DURATION)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_rate)
	stream.stereo = false
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for s in range(num_samples):
		var t := float(s) / sample_rate
		var envelope := 1.0 - (float(s) / float(num_samples))
		var value := sin(TAU * BLIP_FREQ * t) * envelope * 0.3
		var sample := int(clampf(value, -1.0, 1.0) * 32767.0)
		data[s * 2] = sample & 0xFF
		data[s * 2 + 1] = (sample >> 8) & 0xFF
	stream.data = data
	audio_player.stream = stream
	audio_player.play()
