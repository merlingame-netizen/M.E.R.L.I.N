## ═══════════════════════════════════════════════════════════════════════════════
## Scene Antre Merlin — Merlin's Lair
## ═══════════════════════════════════════════════════════════════════════════════
## Meet Bestiole → Oghams unlock → Map of 7 biomes → Mission → Choose biome
## Flow: Bestiole intro → Ogham reveal → Mission briefing → Biome selection
## ═══════════════════════════════════════════════════════════════════════════════

extends Control

const NEXT_SCENE := "res://scenes/TransitionBiome.tscn"
const DATA_PATH := "res://data/post_intro_dialogues.json"
const PORTRAIT_PATH := "res://Assets/Sprite/Merlin.png"

const TYPEWRITER_DELAY := 0.025
const TYPEWRITER_PUNCT_DELAY := 0.08
const BLIP_FREQ := 880.0
const BLIP_DURATION := 0.018
const BLIP_VOLUME := 0.04

# ═══════════════════════════════════════════════════════════════════════════════
# BIOME CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

const CLASS_TO_BIOME := {
	"druide": "broceliande",
	"guerrier": "landes",
	"barde": "villages",
	"eclaireur": "cotes",
}

const BIOME_KEYS := ["broceliande", "landes", "cotes", "villages", "cercles", "marais", "collines"]

# ═══════════════════════════════════════════════════════════════════════════════
# PALETTE (from GameManager GBC palette)
# ═══════════════════════════════════════════════════════════════════════════════

const ANTRE_BG := Color("#181810")
const ANTRE_WARM := Color("#a08058")
const EMBER_COLOR := Color("#f8a850")
const TEXT_COLOR := Color("#e8e8e8")
const TEXT_DIM := Color("#b8b0a0")
const OGHAM_GLOW := Color("#88d850")
const BESTIOLE_COLOR := Color("#78c8f0")

# ═══════════════════════════════════════════════════════════════════════════════
# NODES
# ═══════════════════════════════════════════════════════════════════════════════

var bg: ColorRect
var portrait: TextureRect
var merlin_text: RichTextLabel
var bestiole_sprite: ColorRect  # Simple glow placeholder
var ogham_container: HBoxContainer
var map_panel: Panel
var map_biome_buttons: Dictionary = {}
var continue_button: Button
var skip_hint: Label
var audio_player: AudioStreamPlayer

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

enum Phase { BESTIOLE_INTRO, OGHAM_REVEAL, MISSION_BRIEFING, BIOME_SELECTION, TRANSITIONING }

var current_phase: int = Phase.BESTIOLE_INTRO
var typing_active: bool = false
var typing_abort: bool = false
var scene_finished: bool = false
var _advance_requested: bool = false

var dialogue_data: Dictionary = {}
var biomes_data: Dictionary = {}
var selected_biome: String = ""
var suggested_biome: String = ""
var player_class: String = "eclaireur"
var chronicle_name: String = "Voyageur"

# Voicebox
var voicebox: Node = null
var voice_ready: bool = false


func _ready() -> void:
	_load_data()
	_load_player_data()
	_build_ui()
	_setup_audio()
	_setup_voicebox()

	# Set mood
	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("warm")

	await get_tree().create_timer(0.5).timeout
	_run_bestiole_intro()


func _load_data() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("[SceneAntreMerlin] Data file not found")
		return
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("[SceneAntreMerlin] JSON parse error")
		return
	var data: Dictionary = json.data
	dialogue_data = data.get("antre", {})
	biomes_data = data.get("biomes", {})


func _load_player_data() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var run_data: Dictionary = gm.get("run") if gm.get("run") is Dictionary else {}
		var profile: Dictionary = run_data.get("traveler_profile", {})
		player_class = profile.get("class", "eclaireur")
		chronicle_name = run_data.get("chronicle_name", "Voyageur")
	suggested_biome = CLASS_TO_BIOME.get(player_class, "broceliande")


func _build_ui() -> void:
	# Background — dark cave atmosphere
	bg = ColorRect.new()
	bg.color = ANTRE_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Warm ambient glow (large, soft, behind everything)
	var ambient := ColorRect.new()
	ambient.color = EMBER_COLOR
	ambient.modulate.a = 0.05
	ambient.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ambient)

	# Portrait (top-left area)
	portrait = TextureRect.new()
	if ResourceLoader.exists(PORTRAIT_PATH):
		portrait.texture = load(PORTRAIT_PATH)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(180, 220)
	portrait.size = Vector2(180, 220)
	portrait.position = Vector2(40, 60)
	add_child(portrait)

	# Bestiole (small glow, starts hidden, appears from right)
	bestiole_sprite = ColorRect.new()
	bestiole_sprite.color = BESTIOLE_COLOR
	bestiole_sprite.custom_minimum_size = Vector2(20, 20)
	bestiole_sprite.size = Vector2(20, 20)
	bestiole_sprite.position = Vector2(900, 200)
	bestiole_sprite.modulate.a = 0.0
	bestiole_sprite.pivot_offset = Vector2(10, 10)
	add_child(bestiole_sprite)

	# Merlin text area (right of portrait, main content area)
	merlin_text = RichTextLabel.new()
	merlin_text.bbcode_enabled = true
	merlin_text.fit_content = true
	merlin_text.scroll_active = false
	merlin_text.custom_minimum_size = Vector2(550, 80)
	merlin_text.size = Vector2(550, 80)
	merlin_text.position = Vector2(240, 120)
	merlin_text.add_theme_color_override("default_color", TEXT_COLOR)
	merlin_text.add_theme_font_size_override("normal_font_size", 20)
	merlin_text.visible_characters = 0
	merlin_text.text = ""
	add_child(merlin_text)

	# Ogham reveal container (hidden initially)
	ogham_container = HBoxContainer.new()
	ogham_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ogham_container.position = Vector2(-150, -200)
	ogham_container.add_theme_constant_override("separation", 30)
	ogham_container.visible = false
	ogham_container.modulate.a = 0.0
	add_child(ogham_container)

	var starter_oghams := [
		{"name": "Beith", "meaning": "Bouleau", "icon": "🌿"},
		{"name": "Luis", "meaning": "Sorbier", "icon": "🛡"},
		{"name": "Quert", "meaning": "Pommier", "icon": "🍎"},
	]
	for ogham in starter_oghams:
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon_label := Label.new()
		icon_label.text = ogham.icon
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 36)
		vbox.add_child(icon_label)
		var name_label := Label.new()
		name_label.text = ogham.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", OGHAM_GLOW)
		name_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(name_label)
		var meaning_label := Label.new()
		meaning_label.text = ogham.meaning
		meaning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		meaning_label.add_theme_color_override("font_color", TEXT_DIM)
		meaning_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(meaning_label)
		ogham_container.add_child(vbox)

	# Map panel (hidden, shown during biome selection)
	map_panel = Panel.new()
	map_panel.custom_minimum_size = Vector2(600, 350)
	map_panel.size = Vector2(600, 350)
	map_panel.set_anchors_preset(Control.PRESET_CENTER)
	map_panel.position = Vector2(-300, -120)
	map_panel.visible = false
	map_panel.modulate.a = 0.0
	var map_style := StyleBoxFlat.new()
	map_style.bg_color = Color(0.1, 0.08, 0.06, 0.9)
	map_style.border_color = ANTRE_WARM
	map_style.set_border_width_all(2)
	map_style.set_corner_radius_all(8)
	map_panel.add_theme_stylebox_override("panel", map_style)
	add_child(map_panel)

	# Map title
	var map_title := Label.new()
	map_title.text = "Les Sept Sanctuaires"
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_title.position = Vector2(0, 10)
	map_title.size = Vector2(600, 30)
	map_title.add_theme_color_override("font_color", EMBER_COLOR)
	map_title.add_theme_font_size_override("font_size", 20)
	map_panel.add_child(map_title)

	# Antre marker (center of map)
	var antre_label := Label.new()
	antre_label.text = "★"
	antre_label.position = Vector2(280, 160)
	antre_label.add_theme_color_override("font_color", EMBER_COLOR)
	antre_label.add_theme_font_size_override("font_size", 18)
	map_panel.add_child(antre_label)

	# Biome buttons on map
	for biome_key in BIOME_KEYS:
		var biome_info: Dictionary = biomes_data.get(biome_key, {})
		var map_pos: Array = biome_info.get("map_position", [0.5, 0.5])
		var biome_color := Color(biome_info.get("color", "#787870"))
		var biome_name: String = biome_info.get("name", biome_key)

		var btn := Button.new()
		btn.text = biome_name
		btn.custom_minimum_size = Vector2(130, 32)
		btn.position = Vector2(map_pos[0] * 500 + 20, map_pos[1] * 280 + 40)

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = biome_color.darkened(0.5)
		btn_style.border_color = biome_color
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", btn_style)

		var btn_hover := btn_style.duplicate()
		btn_hover.bg_color = biome_color.darkened(0.2)
		btn_hover.set_border_width_all(2)
		btn.add_theme_stylebox_override("hover", btn_hover)

		var btn_pressed := btn_style.duplicate()
		btn_pressed.bg_color = biome_color
		btn_pressed.set_border_width_all(3)
		btn.add_theme_stylebox_override("pressed", btn_pressed)

		btn.add_theme_color_override("font_color", TEXT_COLOR)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_biome_selected.bind(biome_key))
		btn.disabled = true

		map_panel.add_child(btn)
		map_biome_buttons[biome_key] = btn

	# Continue button (hidden, for non-map advancement)
	continue_button = Button.new()
	continue_button.text = "Continuer"
	continue_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	continue_button.position = Vector2(-60, -40)
	continue_button.custom_minimum_size = Vector2(120, 40)
	continue_button.visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	add_child(continue_button)

	# Skip hint
	skip_hint = Label.new()
	skip_hint.text = "Appuie pour continuer"
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	skip_hint.position.y -= 20
	skip_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.25))
	skip_hint.add_theme_font_size_override("font_size", 13)
	skip_hint.visible = false
	add_child(skip_hint)


func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Master"
	audio_player.volume_db = linear_to_db(BLIP_VOLUME)
	add_child(audio_player)


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
# PHASE 1: BESTIOLE INTRO
# ═══════════════════════════════════════════════════════════════════════════════

func _run_bestiole_intro() -> void:
	current_phase = Phase.BESTIOLE_INTRO

	var lines: Array = dialogue_data.get("bestiole_intro", [])
	for i in range(lines.size()):
		var line: Dictionary = lines[i]
		var text: String = line.get("text", "")
		var mood: String = line.get("mood", "warm")
		var line_type: String = line.get("type", "merlin")

		# Set mood
		var screen_fx := get_node_or_null("/root/ScreenEffects")
		if screen_fx and screen_fx.has_method("set_merlin_mood"):
			screen_fx.set_merlin_mood(mood)

		# Bestiole animation on first narration line
		if i == 0:
			_animate_bestiole_entrance()

		# Show text with narration styling
		if line_type == "narration":
			merlin_text.add_theme_color_override("default_color", TEXT_DIM)
		else:
			merlin_text.add_theme_color_override("default_color", TEXT_COLOR)

		await _show_text(text)
		skip_hint.visible = true
		await _wait_for_advance(4.0)
		skip_hint.visible = false

	# Move to Ogham reveal
	_run_ogham_reveal()


func _animate_bestiole_entrance() -> void:
	# Fade in and float towards center
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(bestiole_sprite, "modulate:a", 0.8, 1.5)
	tween.parallel().tween_property(bestiole_sprite, "position", Vector2(500, 180), 2.0)

	# Start idle float animation after entrance
	tween.tween_callback(_start_bestiole_idle)


func _start_bestiole_idle() -> void:
	var idle := create_tween()
	idle.set_loops()
	idle.set_trans(Tween.TRANS_SINE)
	idle.tween_property(bestiole_sprite, "position:y", 170.0, 1.2)
	idle.tween_property(bestiole_sprite, "position:y", 190.0, 1.2)

	# Subtle glow pulse
	var glow := create_tween()
	glow.set_loops()
	glow.tween_property(bestiole_sprite, "modulate:a", 0.5, 1.8).set_trans(Tween.TRANS_SINE)
	glow.tween_property(bestiole_sprite, "modulate:a", 0.9, 1.8).set_trans(Tween.TRANS_SINE)


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 2: OGHAM REVEAL
# ═══════════════════════════════════════════════════════════════════════════════

func _run_ogham_reveal() -> void:
	current_phase = Phase.OGHAM_REVEAL

	# Show ogham container with glow burst
	ogham_container.visible = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ogham_container, "modulate:a", 1.0, 0.8)
	tween.parallel().tween_property(ogham_container, "scale", Vector2(1.0, 1.0), 0.6).from(Vector2(0.5, 0.5))

	# Brief glow flash on each ogham
	await tween.finished
	for child in ogham_container.get_children():
		var flash := create_tween()
		flash.tween_property(child, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.15)
		flash.tween_property(child, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
		await flash.finished

	await _wait_for_advance(3.0)

	# Hide oghams, move to mission
	var hide := create_tween()
	hide.tween_property(ogham_container, "modulate:a", 0.0, 0.4)
	await hide.finished
	ogham_container.visible = false

	_run_mission_briefing()


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 3: MISSION BRIEFING
# ═══════════════════════════════════════════════════════════════════════════════

func _run_mission_briefing() -> void:
	current_phase = Phase.MISSION_BRIEFING
	merlin_text.add_theme_color_override("default_color", TEXT_COLOR)

	# Show map behind text
	map_panel.visible = true
	var map_tween := create_tween()
	map_tween.tween_property(map_panel, "modulate:a", 0.5, 1.0)

	var screen_fx := get_node_or_null("/root/ScreenEffects")
	var lines: Array = dialogue_data.get("mission_briefing", [])
	for line in lines:
		var text: String = line.get("text", "")
		var mood: String = line.get("mood", "sage")
		var pause: float = line.get("pause_after", 1.0)

		if screen_fx and screen_fx.has_method("set_merlin_mood"):
			screen_fx.set_merlin_mood(mood)

		await _show_text(text)
		skip_hint.visible = true
		await _wait_for_advance(pause + 2.5)
		skip_hint.visible = false

	# Now show biome suggestion
	_run_biome_selection()


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 4: BIOME SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

func _run_biome_selection() -> void:
	current_phase = Phase.BIOME_SELECTION

	# Full map opacity
	var tween := create_tween()
	tween.tween_property(map_panel, "modulate:a", 1.0, 0.5)

	# Enable all biome buttons
	for key in map_biome_buttons:
		map_biome_buttons[key].disabled = false

	# Highlight suggested biome
	if map_biome_buttons.has(suggested_biome):
		var suggested_btn: Button = map_biome_buttons[suggested_biome]
		var pulse := create_tween()
		pulse.set_loops()
		pulse.tween_property(suggested_btn, "modulate", Color(1.3, 1.3, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(suggested_btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)

	# Show Merlin's class-based suggestion
	var suggestions: Dictionary = dialogue_data.get("biome_suggestions", {})
	if suggestions.has(player_class):
		var suggestion: Dictionary = suggestions[player_class]
		var text: String = suggestion.get("text", "").replace("{name}", chronicle_name)
		var mood: String = suggestion.get("mood", "sage")

		var screen_fx := get_node_or_null("/root/ScreenEffects")
		if screen_fx and screen_fx.has_method("set_merlin_mood"):
			screen_fx.set_merlin_mood(mood)

		await _show_text(text)

	# Move text to bottom so map is visible
	merlin_text.position = Vector2(40, 500)
	merlin_text.size = Vector2(700, 60)
	skip_hint.text = "Choisis un biome sur la carte"
	skip_hint.visible = true


func _on_biome_selected(biome_key: String) -> void:
	if current_phase != Phase.BIOME_SELECTION or scene_finished:
		return

	selected_biome = biome_key
	skip_hint.visible = false

	# Disable all buttons
	for key in map_biome_buttons:
		map_biome_buttons[key].disabled = true

	# Show reaction
	var reactions: Dictionary = dialogue_data.get("biome_reactions", {})
	var reaction_text: String
	if biome_key == suggested_biome:
		reaction_text = reactions.get("accepted", "Bien.")
	else:
		reaction_text = reactions.get("rejected", "Interessant.")

	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("amuse")

	await _show_text(reaction_text)
	await get_tree().create_timer(1.5).timeout

	# Save to GameManager and transition
	_save_biome_choice()
	_transition_out()


func _save_biome_choice() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if not gm:
		return
	var run_data: Dictionary = gm.get("run") if gm.get("run") is Dictionary else {}
	run_data["current_biome"] = selected_biome
	run_data["biome_data"] = biomes_data.get(selected_biome, {})
	run_data["active"] = true
	gm.set("run", run_data)

	# Also set bestiole starter oghams
	var bestiole_data: Dictionary = gm.get("bestiole") if gm.get("bestiole") is Dictionary else {}
	bestiole_data["known_oghams"] = ["beith", "luis", "quert"]
	bestiole_data["equipped_oghams"] = ["beith", "luis", "quert", ""]
	gm.set("bestiole", bestiole_data)


func _on_continue_pressed() -> void:
	if current_phase == Phase.BESTIOLE_INTRO or current_phase == Phase.MISSION_BRIEFING:
		_advance_requested = true


# ═══════════════════════════════════════════════════════════════════════════════
# TRANSITION OUT
# ═══════════════════════════════════════════════════════════════════════════════

func _transition_out() -> void:
	scene_finished = true
	current_phase = Phase.TRANSITIONING

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(NEXT_SCENE)
	)


# ═══════════════════════════════════════════════════════════════════════════════
# TEXT DISPLAY & INPUT
# ═══════════════════════════════════════════════════════════════════════════════

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
	while elapsed < max_wait and not _advance_requested and not scene_finished:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_advance_requested = false


func _consume_advance_input() -> bool:
	if _advance_requested:
		_advance_requested = false
		return true
	return false


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
			_skip_typewriter()
		elif current_phase != Phase.BIOME_SELECTION:
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
