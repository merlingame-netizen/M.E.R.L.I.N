## ═══════════════════════════════════════════════════════════════════════════════
## Scene Eveil — The Awakening (Post-Questionnaire)
## ═══════════════════════════════════════════════════════════════════════════════
## Black screen → Merlin speaks in the dark → Gradual light → Transition
## Duration: ~30-45 seconds, skippable per line
## ═══════════════════════════════════════════════════════════════════════════════

extends Control

const NEXT_SCENE := "res://scenes/SceneAntreMerlin.tscn"
const DATA_PATH := "res://data/post_intro_dialogues.json"

const TYPEWRITER_DELAY := 0.030
const TYPEWRITER_PUNCT_DELAY := 0.10
const BLIP_FREQ := 880.0
const BLIP_DURATION := 0.018
const BLIP_VOLUME := 0.04

# ═══════════════════════════════════════════════════════════════════════════════
# NODES (created dynamically)
# ═══════════════════════════════════════════════════════════════════════════════

var bg: ColorRect
var ember: ColorRect
var merlin_text: RichTextLabel
var skip_hint: Label
var audio_player: AudioStreamPlayer

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var dialogue_lines: Array = []
var current_line_index: int = 0
var typing_active: bool = false
var typing_abort: bool = false
var scene_finished: bool = false
var ember_tween: Tween

# ═══════════════════════════════════════════════════════════════════════════════
# VOICEBOX
# ═══════════════════════════════════════════════════════════════════════════════

var voicebox: Node = null
var voice_ready: bool = false


func _ready() -> void:
	_load_data()
	_build_ui()
	_setup_audio()
	_setup_voicebox()

	# Start with ScreenEffects in pensif mood (if available)
	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("pensif")

	# Begin the sequence after a short delay
	await get_tree().create_timer(1.0).timeout
	_play_sequence()


func _load_data() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("[SceneEveil] Data file not found: %s" % DATA_PATH)
		dialogue_lines = [
			{"text": "Tu es la.", "mood": "pensif", "pause_after": 1.5},
			{"text": "Suis-moi.", "mood": "warm", "pause_after": 1.0},
		]
		return

	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("[SceneEveil] JSON parse error: %s" % json.get_error_message())
		return

	var data: Dictionary = json.data
	dialogue_lines = data.get("eveil", {}).get("lines", [])


func _build_ui() -> void:
	# Full black background
	bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Ember glow (centered, pulsing orange circle)
	ember = ColorRect.new()
	ember.color = Color("#FF7900")
	ember.custom_minimum_size = Vector2(6, 6)
	ember.size = Vector2(6, 6)
	ember.set_anchors_preset(Control.PRESET_CENTER)
	ember.position -= Vector2(3, 3)
	ember.modulate.a = 0.0
	add_child(ember)

	# Merlin text (centered, wide)
	merlin_text = RichTextLabel.new()
	merlin_text.bbcode_enabled = true
	merlin_text.fit_content = true
	merlin_text.scroll_active = false
	merlin_text.set_anchors_preset(Control.PRESET_CENTER)
	merlin_text.custom_minimum_size = Vector2(700, 100)
	merlin_text.size = Vector2(700, 100)
	merlin_text.position = Vector2(-350, 40)
	merlin_text.add_theme_color_override("default_color", Color("#e8e8e8"))
	merlin_text.add_theme_font_size_override("normal_font_size", 22)
	merlin_text.visible_characters = 0
	merlin_text.text = ""
	add_child(merlin_text)

	# Skip hint (bottom)
	skip_hint = Label.new()
	skip_hint.text = "Appuie pour continuer"
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	skip_hint.position.y -= 60
	skip_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	skip_hint.add_theme_font_size_override("font_size", 14)
	skip_hint.visible = false
	add_child(skip_hint)


func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Master"
	audio_player.volume_db = linear_to_db(BLIP_VOLUME)
	add_child(audio_player)


func _setup_voicebox() -> void:
	# Try to find ACVoicebox
	var voicebox_class := "ACVoicebox"
	if ClassDB.class_exists(voicebox_class):
		voicebox = ClassDB.instantiate(voicebox_class)
	else:
		var script_path := "res://addons/ac_voicebox/ac_voicebox.gd"
		if ResourceLoader.exists(script_path):
			var scr = load(script_path)
			if scr:
				voicebox = scr.new()
	if voicebox:
		voicebox.set("pitch", 2.5)
		voicebox.set("pitch_variation", 0.12)
		voicebox.set("speed_scale", 0.65)
		add_child(voicebox)
		voice_ready = true


func _play_sequence() -> void:
	# Fade in ember glow
	_start_ember_pulse()

	for i in range(dialogue_lines.size()):
		current_line_index = i
		if scene_finished:
			return

		var line: Dictionary = dialogue_lines[i]
		var text: String = line.get("text", "")
		var mood: String = line.get("mood", "pensif")
		var pause: float = line.get("pause_after", 1.5)

		# Set mood
		var screen_fx := get_node_or_null("/root/ScreenEffects")
		if screen_fx and screen_fx.has_method("set_merlin_mood"):
			screen_fx.set_merlin_mood(mood)

		# Grow ember with each line
		var progress := float(i + 1) / float(dialogue_lines.size())
		_grow_ember(progress)

		# Display text
		await _show_text(text)

		# Show skip hint
		skip_hint.visible = true

		# Wait for tap or timeout
		await _wait_for_advance(pause + 2.0)

		skip_hint.visible = false

	# All lines done — transition
	await _transition_out()


func _start_ember_pulse() -> void:
	# Fade ember in
	var fade_in := create_tween()
	fade_in.tween_property(ember, "modulate:a", 0.6, 2.0)
	await fade_in.finished

	# Continuous pulse
	_pulse_ember()


func _pulse_ember() -> void:
	if scene_finished:
		return
	ember_tween = create_tween()
	ember_tween.set_loops()
	ember_tween.tween_property(ember, "modulate:a", 0.3, 1.5).set_trans(Tween.TRANS_SINE)
	ember_tween.tween_property(ember, "modulate:a", 0.8, 1.5).set_trans(Tween.TRANS_SINE)


func _grow_ember(progress: float) -> void:
	var target_size := Vector2(6, 6) + Vector2(30, 30) * progress
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ember, "custom_minimum_size", target_size, 0.8)
	tween.parallel().tween_property(ember, "size", target_size, 0.8)
	tween.parallel().tween_property(ember, "position", -target_size / 2.0, 0.8)


func _show_text(text: String) -> void:
	typing_active = true
	typing_abort = false

	if voice_ready and voicebox:
		if voicebox.has_method("stop_speaking"):
			voicebox.stop_speaking()
		voicebox.set("text_label", merlin_text)
		voicebox.play_string(text)
		await voicebox.finished_phrase
		typing_active = false
		return

	# Fallback: manual typewriter
	merlin_text.text = text
	merlin_text.visible_characters = 0
	for i in range(text.length()):
		if typing_abort:
			break
		merlin_text.visible_characters = i + 1
		var ch := text[i]
		if ch != " ":
			_play_blip()
		var delay := TYPEWRITER_DELAY
		if ch in [".", "!", "?"]:
			delay = TYPEWRITER_PUNCT_DELAY
		await get_tree().create_timer(delay).timeout
	merlin_text.visible_characters = -1
	typing_active = false


func _skip_typewriter() -> void:
	if typing_active:
		typing_abort = true
		merlin_text.visible_characters = -1
		if voice_ready and voicebox and voicebox.has_method("stop_speaking"):
			voicebox.stop_speaking()


func _wait_for_advance(max_wait: float) -> void:
	var elapsed := 0.0
	var advanced := false

	while elapsed < max_wait and not advanced and not scene_finished:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		# Check if input happened (set by _unhandled_input)
		if _consume_advance_input():
			advanced = true


var _advance_requested: bool = false

func _consume_advance_input() -> bool:
	if _advance_requested:
		_advance_requested = false
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if scene_finished:
		return

	if event is InputEventMouseButton and event.pressed:
		if typing_active:
			_skip_typewriter()
		else:
			_advance_requested = true
		get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			if typing_active:
				_skip_typewriter()
			else:
				_advance_requested = true
			get_viewport().set_input_as_handled()

	# Touch support
	if event is InputEventScreenTouch and event.pressed:
		if typing_active:
			_skip_typewriter()
		else:
			_advance_requested = true
		get_viewport().set_input_as_handled()


func _transition_out() -> void:
	scene_finished = true
	if ember_tween:
		ember_tween.kill()

	# Set warm mood for transition
	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("warm")

	# Fade out text, grow ember to fill screen
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(merlin_text, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(skip_hint, "modulate:a", 0.0, 0.4)
	tween.tween_property(ember, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(ember, "custom_minimum_size", Vector2(2000, 2000), 1.2)
	tween.parallel().tween_property(ember, "size", Vector2(2000, 2000), 1.2)
	tween.parallel().tween_property(ember, "position", Vector2(-1000, -1000), 1.2)

	# Hold briefly then transition
	tween.tween_interval(0.3)
	tween.tween_callback(_go_to_antre)
	await tween.finished


func _go_to_antre() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)


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
