## ═══════════════════════════════════════════════════════════════════════════════
## Scene Eveil — The Awakening (Post-Questionnaire)
## ═══════════════════════════════════════════════════════════════════════════════
## Style "Parchemin Mystique Breton" — Carte centree, portrait Merlin, typewriter
## Duration: ~30-45 seconds, tap to advance each line
## ═══════════════════════════════════════════════════════════════════════════════

extends Control

const NEXT_SCENE := "res://scenes/HubAntre.tscn"
const DATA_PATH := "res://data/dialogues/scene_dialogues.json"

const TYPEWRITER_DELAY := 0.030
const TYPEWRITER_PUNCT_DELAY := 0.10
const BLIP_FREQ := 880.0
const BLIP_DURATION := 0.018
const BLIP_VOLUME := 0.04

# ═══════════════════════════════════════════════════════════════════════════════
# PALETTE — Parchemin Mystique Breton (shared with MenuPrincipal)
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

const CARD_MAX_WIDTH := 720.0
const CARD_MAX_HEIGHT := 800.0
const PORTRAIT_SIZE := Vector2(280, 340)

const PORTRAIT_DEFAULT := "res://Assets/Sprite/Merlin.png"
const PORTRAIT_PRINTEMPS := "res://Assets/Sprite/Merlin_PRINTEMPS.png"
const PORTRAIT_ETE := "res://Assets/Sprite/Merlin_ETE.png"
const PORTRAIT_AUTOMNE := "res://Assets/Sprite/Merlin_AUTOMNE.png"
const PORTRAIT_HIVER := "res://Assets/Sprite/Merlin_HIVER.png"

const UI_SOUNDS := {
	"click": "res://audio/sfx/ui/ui_click.ogg",
}

# ═══════════════════════════════════════════════════════════════════════════════
# NODES
# ═══════════════════════════════════════════════════════════════════════════════

var parchment_bg: ColorRect
var mist_layer: ColorRect
var celtic_top: Label
var celtic_bottom: Label
var card: PanelContainer
var card_vbox: VBoxContainer
var portrait_rect: TextureRect
var merlin_text: RichTextLabel
var _dialogue_source_badge: PanelContainer
var skip_hint: Label
var audio_player: AudioStreamPlayer
var seasonal_overlay: ColorRect

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var dialogue_lines: Array = []
var current_line_index: int = 0
var typing_active: bool = false
var typing_abort: bool = false
var scene_finished: bool = false
var _advance_requested: bool = false
var _mist_tween: Tween
var _entry_tween: Tween

# Fonts
var title_font: Font
var body_font: Font

# Voicebox
var voicebox: Node = null
var voice_ready: bool = false

# LLM dialogue generator
var _llm_gen: LLMDialogueGenerator = null

# Response blocks (LLM-generated player choices)
var response_container: VBoxContainer
var response_buttons: Array[Button] = []
var _response_chosen: int = -1
var _llm_warmup_done: bool = false
var _preloaded_responses: Dictionary = {}  # line_index -> Array of 3 strings
var _preloaded_sources: Dictionary = {}  # line_index -> "llm" or "fallback"
var _response_source_badge: PanelContainer
var loading_spinner: Label
var merlin_ai: Node = null


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_fonts()
	_load_data()
	_init_llm_generator()
	_build_ui()
	_setup_audio()

	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("pensif")

	resized.connect(_on_resized)
	_start_mist_animation()
	_play_entry_animation.call_deferred()

	# Setup voicebox (async — waits for sounds to load)
	await _setup_voicebox()

	# Begin dialogue after entry animation
	if not is_inside_tree():
		return
	await get_tree().create_timer(1.5).timeout
	_play_sequence()


func _load_fonts() -> void:
	title_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlack.otf")
	if title_font == null:
		title_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlack.ttf")
	body_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.otf")
	if body_font == null:
		body_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf")
	if body_font == null:
		body_font = title_font


func _try_load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var f: Resource = load(path)
	if f is Font:
		return f
	return null


func _load_data() -> void:
	var locale_mgr = get_node_or_null("/root/LocaleManager")
	var path: String = DATA_PATH
	if locale_mgr:
		path = locale_mgr.get_data_path(DATA_PATH)

	if not FileAccess.file_exists(path):
		push_warning("[SceneEveil] Data file not found: %s" % path)
		dialogue_lines = [
			{"text": "... Tu es la.", "emotion": "soulagement_profond"},
			{"text": "J'ai attendu. Longtemps.", "emotion": "vulnerabilite_rare"},
			{"text": "La brume t'a laisse passer. C'est bon signe.", "emotion": "transition_vers_humour"},
			{"text": "Bon. Bienvenue a Broceliande.", "emotion": "accueil_jovial"},
		]
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("[SceneEveil] JSON parse error: %s" % json.get_error_message())
		return

	var data: Dictionary = json.data
	dialogue_lines = data.get("scene_eveil", {}).get("lines", [])


func _init_llm_generator() -> void:
	var gen_script = load("res://scripts/llm_dialogue_generator.gd")
	if gen_script == null:
		return
	_llm_gen = gen_script.new()
	_llm_gen.setup(get_tree())
	if not _llm_gen.is_llm_available():
		return
	# Pre-generate all lines asynchronously
	var locale_mgr = get_node_or_null("/root/LocaleManager")
	var lang: String = "fr"
	if locale_mgr:
		lang = locale_mgr.get_language()
	_llm_gen.generate_batch(dialogue_lines, lang)

	# Find MerlinAI for response generation
	merlin_ai = get_node_or_null("/root/MerlinAI")
	if merlin_ai:
		print("[SceneEveil] MerlinAI found, response generation available")
		# Start warmup — pre-generate responses for interactive lines
		_warmup_llm_responses()


func _build_response_ui() -> void:
	response_container = VBoxContainer.new()
	response_container.name = "ResponseContainer"
	response_container.add_theme_constant_override("separation", 10)
	response_container.visible = false
	response_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(response_container)

	# 3 response buttons
	for i in range(3):
		var btn := Button.new()
		btn.name = "Response%d" % i
		btn.custom_minimum_size = Vector2(400, 44)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = "..."
		btn.mouse_filter = Control.MOUSE_FILTER_STOP

		# Parchment button style
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = PALETTE.paper_warm
		btn_style.border_color = PALETTE.ink_faded
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(4)
		btn_style.content_margin_left = 16
		btn_style.content_margin_right = 16
		btn_style.content_margin_top = 8
		btn_style.content_margin_bottom = 8
		var btn_hover := btn_style.duplicate()
		btn_hover.bg_color = PALETTE.paper_dark
		btn_hover.border_color = PALETTE.accent
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_hover)
		btn.add_theme_stylebox_override("focus", btn_hover)
		btn.add_theme_color_override("font_color", PALETTE.ink)
		btn.add_theme_color_override("font_hover_color", PALETTE.accent)
		if body_font:
			btn.add_theme_font_override("font", body_font)
		btn.add_theme_font_size_override("font_size", 16)

		btn.pressed.connect(_on_response_chosen.bind(i))
		btn.mouse_entered.connect(func(): SFXManager.play("choice_hover"))
		response_container.add_child(btn)
		response_buttons.append(btn)

	# Response source badge (dev indicator)
	_response_source_badge = LLMSourceBadge.create("static")
	_response_source_badge.visible = false
	response_container.add_child(_response_source_badge)


func _warmup_llm_responses() -> void:
	## Pre-generate response options for interactive lines (runs in background).
	if merlin_ai == null:
		return
	if not merlin_ai.get("is_ready"):
		return

	# Interactive lines: after eveil_02 (index 1) and eveil_04 (index 3)
	var interactive_indices := [1, 3]
	for idx in interactive_indices:
		if idx >= dialogue_lines.size():
			continue
		_pregenerate_responses(idx)
	_llm_warmup_done = true


func _pregenerate_responses(line_index: int) -> void:
	## Generate 3 player response options for a given dialogue line.
	if merlin_ai == null or not merlin_ai.has_method("generate_with_system"):
		_preloaded_responses[line_index] = _fallback_responses(line_index)
		_preloaded_sources[line_index] = "fallback"
		return

	var line_data: Dictionary = dialogue_lines[line_index] if line_index < dialogue_lines.size() else {}
	var merlin_text_content: String = line_data.get("text", "")

	var system := "Tu incarnes un voyageur qui repond a Merlin. Propose 3 reponses courtes (1 phrase chacune), numerotees 1. 2. 3. Ton: humble, curieux, ou audacieux."
	var user := "Merlin dit: \"%s\"\nTes 3 reponses possibles:" % merlin_text_content

	var result: Dictionary = await merlin_ai.generate_with_system(system, user, {"max_tokens": 150, "temperature": 0.8})

	if result.has("error") or result.get("text", "").is_empty():
		_preloaded_responses[line_index] = _fallback_responses(line_index)
		_preloaded_sources[line_index] = "fallback"
		return

	var responses := _parse_numbered_responses(result.get("text", ""))
	if responses.size() < 3:
		_preloaded_responses[line_index] = _fallback_responses(line_index)
		_preloaded_sources[line_index] = "fallback"
		return

	_preloaded_responses[line_index] = responses
	_preloaded_sources[line_index] = "llm"


func _parse_numbered_responses(text: String) -> Array[String]:
	## Parse "1. ... 2. ... 3. ..." format.
	var responses: Array[String] = []
	var lines := text.split("\n")
	for line in lines:
		var stripped := line.strip_edges()
		# Match patterns like "1.", "2.", "3." or "1)", "2)", "3)"
		if stripped.length() > 2:
			var first_char := stripped[0]
			if first_char in ["1", "2", "3"]:
				var rest := stripped.substr(1).strip_edges()
				if rest.begins_with(".") or rest.begins_with(")"):
					rest = rest.substr(1).strip_edges()
				if not rest.is_empty():
					responses.append(rest)
	return responses


func _fallback_responses(line_index: int) -> Array[String]:
	## Handcrafted fallback responses if LLM is unavailable.
	if line_index == 1:
		return [
			"Je suis la. Que dois-je faire ?",
			"Longtemps ? Tu comptais les siecles ou les feuilles ?",
			"La brume m'a guide jusqu'ici.",
		]
	return [
		"Je suis pret. Montre-moi ce monde.",
		"Joli ? Meme dans le noir, je te crois.",
		"Le bout du monde ? Ca ne me fait pas peur.",
	]


func _on_response_chosen(index: int) -> void:
	SFXManager.play("choice_select")
	_response_chosen = index
	# Visual feedback
	for i in range(response_buttons.size()):
		if i == index:
			response_buttons[i].add_theme_color_override("font_color", PALETTE.accent)
		else:
			response_buttons[i].modulate.a = 0.4


func _is_interactive_line(index: int) -> bool:
	## Lines after which player can respond (indices 1 and 3).
	return index == 1 or index == 3


# ═══════════════════════════════════════════════════════════════════════════════
# UI BUILD — Parchemin Mystique Breton
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Parchment background with shader
	parchment_bg = ColorRect.new()
	parchment_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parchment_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		parchment_bg.material = mat
	else:
		parchment_bg.color = PALETTE.paper
	add_child(parchment_bg)

	# Mist layer
	mist_layer = ColorRect.new()
	mist_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	mist_layer.color = PALETTE.mist
	mist_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mist_layer.modulate.a = 0.0
	add_child(mist_layer)

	# Celtic ornaments
	celtic_top = _make_celtic_ornament()
	add_child(celtic_top)
	celtic_bottom = _make_celtic_ornament()
	add_child(celtic_bottom)

	# Central card
	card = PanelContainer.new()
	card.name = "Card"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_card_style()
	add_child(card)

	card_vbox = VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 20)
	card.add_child(card_vbox)

	# Portrait Merlin (centered in card)
	var portrait_container := CenterContainer.new()
	card_vbox.add_child(portrait_container)

	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = PORTRAIT_SIZE
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_seasonal_portrait()
	portrait_container.add_child(portrait_rect)

	# Separator
	var sep_container := HBoxContainer.new()
	sep_container.alignment = BoxContainer.ALIGNMENT_CENTER
	sep_container.add_theme_constant_override("separation", 8)
	card_vbox.add_child(sep_container)

	var sep_left := ColorRect.new()
	sep_left.color = PALETTE.line
	sep_left.custom_minimum_size = Vector2(60, 1)
	sep_container.add_child(sep_left)
	var sep_diamond := Label.new()
	sep_diamond.text = "◆"
	sep_diamond.add_theme_color_override("font_color", PALETTE.accent)
	sep_diamond.add_theme_font_size_override("font_size", 10)
	sep_container.add_child(sep_diamond)
	var sep_right := ColorRect.new()
	sep_right.color = PALETTE.line
	sep_right.custom_minimum_size = Vector2(60, 1)
	sep_container.add_child(sep_right)

	# Merlin text area
	merlin_text = RichTextLabel.new()
	merlin_text.name = "MerlinText"
	merlin_text.bbcode_enabled = true
	merlin_text.fit_content = true
	merlin_text.scroll_active = false
	merlin_text.custom_minimum_size = Vector2(440, 140)
	merlin_text.visible_characters = 0
	merlin_text.text = ""
	merlin_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if body_font:
		merlin_text.add_theme_font_override("normal_font", body_font)
	merlin_text.add_theme_font_size_override("normal_font_size", 26)
	merlin_text.add_theme_color_override("default_color", PALETTE.ink)
	card_vbox.add_child(merlin_text)

	# Dialogue source badge (dev indicator)
	_dialogue_source_badge = LLMSourceBadge.create("static")
	_dialogue_source_badge.visible = false
	card_vbox.add_child(_dialogue_source_badge)

	# Skip hint — inside card, below text
	skip_hint = Label.new()
	skip_hint.text = "Appuie pour continuer"
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if body_font:
		skip_hint.add_theme_font_override("font", body_font)
	skip_hint.add_theme_font_size_override("font_size", 14)
	skip_hint.add_theme_color_override("font_color", PALETTE.ink_faded)
	skip_hint.visible = false
	card_vbox.add_child(skip_hint)

	# Response container (3 choice buttons, below card)
	_build_response_ui()

	# Loading spinner
	loading_spinner = Label.new()
	loading_spinner.text = "..."
	loading_spinner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_spinner.add_theme_color_override("font_color", PALETTE.accent)
	loading_spinner.add_theme_font_size_override("font_size", 18)
	if body_font:
		loading_spinner.add_theme_font_override("font", body_font)
	loading_spinner.visible = false
	loading_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(loading_spinner)

	# Seasonal overlay (snow on card)
	_build_seasonal_overlay()

	_layout_ui()


func _apply_card_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.paper_warm
	style.border_color = PALETTE.ink_faded
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.shadow_color = PALETTE.shadow
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 36
	style.content_margin_top = 32
	style.content_margin_right = 36
	style.content_margin_bottom = 32
	card.add_theme_stylebox_override("panel", style)


func _load_seasonal_portrait() -> void:
	var month: int = Time.get_date_dict_from_system().month
	var path := PORTRAIT_DEFAULT
	if month >= 3 and month <= 5:
		path = PORTRAIT_PRINTEMPS
	elif month >= 6 and month <= 8:
		path = PORTRAIT_ETE
	elif month >= 9 and month <= 11:
		path = PORTRAIT_AUTOMNE
	else:
		path = PORTRAIT_HIVER
	if ResourceLoader.exists(path):
		portrait_rect.texture = load(path)
	elif ResourceLoader.exists(PORTRAIT_DEFAULT):
		portrait_rect.texture = load(PORTRAIT_DEFAULT)


func _make_celtic_ornament() -> Label:
	var lbl := Label.new()
	var pattern := ["─", "•", "─", "─", "◆", "─", "─", "•", "─"]
	var line := ""
	for i in range(40):
		line += pattern[i % pattern.size()]
	lbl.text = line
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", PALETTE.ink_faded)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a = 0.0
	return lbl


func _build_seasonal_overlay() -> void:
	var month: int = Time.get_date_dict_from_system().month
	var is_winter := month >= 12 or month <= 2
	if not is_winter:
		return
	var snow_shader = load("res://shaders/seasonal_snow.gdshader")
	if snow_shader == null:
		return
	seasonal_overlay = ColorRect.new()
	seasonal_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = snow_shader
	mat.set_shader_parameter("speed", 0.25)
	mat.set_shader_parameter("density", 0.22)
	seasonal_overlay.material = mat
	add_child(seasonal_overlay)


func _layout_ui() -> void:
	var vp := get_viewport().get_visible_rect().size

	var card_w := minf(CARD_MAX_WIDTH, vp.x * 0.85)
	var card_h := minf(CARD_MAX_HEIGHT, vp.y * 0.78)
	card.size = Vector2(card_w, card_h)
	card.position = (vp - card.size) * 0.5
	card.pivot_offset = card.size * 0.5

	if celtic_top:
		celtic_top.size = Vector2(vp.x, 30)
		celtic_top.position = Vector2(0, card.position.y - 35)
	if celtic_bottom:
		celtic_bottom.size = Vector2(vp.x, 30)
		celtic_bottom.position = Vector2(0, card.position.y + card_h + 5)

	if seasonal_overlay:
		seasonal_overlay.position = card.position
		seasonal_overlay.size = card.size


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _play_entry_animation() -> void:
	if not card:
		return
	SFXManager.play("scene_transition")

	card.modulate.a = 0.0
	card.position.y += 40

	if _entry_tween:
		_entry_tween.kill()
	_entry_tween = create_tween()

	# Fade ornaments
	_entry_tween.tween_property(celtic_top, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	_entry_tween.parallel().tween_property(celtic_bottom, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)

	# Card entrance
	var target_y := card.position.y - 40
	_entry_tween.tween_property(card, "position:y", target_y, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_entry_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)


func _start_mist_animation() -> void:
	if _mist_tween:
		_mist_tween.kill()
	_mist_tween = create_tween().set_loops()
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.25, 8.0).set_trans(Tween.TRANS_SINE)
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.08, 8.0).set_trans(Tween.TRANS_SINE)


# ═══════════════════════════════════════════════════════════════════════════════
# DIALOGUE SEQUENCE
# ═══════════════════════════════════════════════════════════════════════════════

func _play_sequence() -> void:
	for i in range(dialogue_lines.size()):
		current_line_index = i
		if scene_finished:
			return

		var line: Dictionary = dialogue_lines[i]
		var original_text: String = line.get("text", "")
		var text: String = original_text
		# Use LLM-generated text if available
		if _llm_gen:
			text = _llm_gen.get_result(i, original_text)
		# Update dialogue source badge
		var dlg_source: String = "static"
		if _llm_gen != null:
			dlg_source = "llm" if text != original_text else "fallback"
		if _dialogue_source_badge and is_instance_valid(_dialogue_source_badge):
			LLMSourceBadge.update_badge(_dialogue_source_badge, dlg_source)
			_dialogue_source_badge.visible = true

		# Set mood via ScreenEffects
		var emotion: String = line.get("emotion", "pensif")
		var mood := _emotion_to_mood(emotion)
		var screen_fx := get_node_or_null("/root/ScreenEffects")
		if screen_fx and screen_fx.has_method("set_merlin_mood"):
			screen_fx.set_merlin_mood(mood)

		# Typewriter text (click = instant show)
		await _show_text(text)
		if not is_inside_tree():
			return

		# 0.3s mandatory pause after text is fully shown
		await get_tree().create_timer(0.3).timeout

		# Interactive line? Show response blocks
		if _is_interactive_line(i):
			await _show_response_blocks(i)
		else:
			# Show hint and wait for click to advance
			skip_hint.visible = true
			SFXManager.play("click")
			_advance_requested = false
			await _wait_for_advance(30.0)
			skip_hint.visible = false

		# Brief fade between lines
		if i < dialogue_lines.size() - 1:
			var fade := create_tween()
			fade.tween_property(merlin_text, "modulate:a", 0.0, 0.3)
			await fade.finished
			merlin_text.modulate.a = 1.0

	# All lines done
	await _transition_out()


func _show_response_blocks(line_index: int) -> void:
	## Show 3 response blocks. If LLM responses aren't ready, show loading.
	_response_chosen = -1

	# Position response container below card
	var vp := get_viewport().get_visible_rect().size
	var rc_width := minf(450.0, vp.x * 0.8)
	response_container.position = Vector2((vp.x - rc_width) * 0.5, card.position.y + card.size.y + 16)
	response_container.size.x = rc_width

	# Check if responses are preloaded
	var responses: Array = _preloaded_responses.get(line_index, [])
	if responses.is_empty():
		# Show loading animation
		loading_spinner.visible = true
		loading_spinner.position = response_container.position + Vector2(rc_width * 0.5 - 20, 0)
		_animate_loading_spinner()

		# Generate now (blocking-ish)
		await _pregenerate_responses(line_index)
		responses = _preloaded_responses.get(line_index, _fallback_responses(line_index))

		loading_spinner.visible = false

	# Populate buttons
	for i in range(response_buttons.size()):
		if i < responses.size():
			response_buttons[i].text = responses[i]
			response_buttons[i].visible = true
			response_buttons[i].modulate.a = 0.0
		else:
			response_buttons[i].visible = false

	# Update source badge
	var resp_source: String = _preloaded_sources.get(line_index, "fallback")
	if _response_source_badge and is_instance_valid(_response_source_badge):
		LLMSourceBadge.update_badge(_response_source_badge, resp_source)
		_response_source_badge.visible = true

	# Reveal with cascade animation
	response_container.visible = true
	for i in range(mini(responses.size(), 3)):
		var tw := create_tween()
		tw.tween_property(response_buttons[i], "modulate:a", 1.0, 0.3).set_delay(i * 0.15)

	# Wait for player to pick a response
	while _response_chosen < 0 and not scene_finished:
		if not is_inside_tree():
			return
		await get_tree().process_frame

	# Brief flash on chosen response
	if _response_chosen >= 0 and is_inside_tree():
		await get_tree().create_timer(0.4).timeout

	# Hide response container
	var hide_tw := create_tween()
	hide_tw.tween_property(response_container, "modulate:a", 0.0, 0.3)
	await hide_tw.finished
	response_container.visible = false
	response_container.modulate.a = 1.0
	for btn in response_buttons:
		btn.modulate.a = 1.0


func _animate_loading_spinner() -> void:
	## Simple dot animation: "." -> ".." -> "..." -> "."
	var dots := 0
	while loading_spinner.visible:
		dots = (dots % 3) + 1
		loading_spinner.text = ".".repeat(dots)
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.4).timeout


func _clean_tags(text: String) -> String:
	text = text.replace("[long_pause]", "").replace("[pause]", "").replace("[beat]", "")
	while text.find("  ") != -1:
		text = text.replace("  ", " ")
	return text.strip_edges()


func _emotion_to_mood(emotion: String) -> String:
	if "humour" in emotion or "jovial" in emotion or "amuse" in emotion:
		return "amuse"
	if "vulnerabilite" in emotion or "soulagement" in emotion or "pensif" in emotion:
		return "pensif"
	if "accueil" in emotion or "warm" in emotion:
		return "warm"
	if "serieux" in emotion or "gravite" in emotion:
		return "serieux"
	return "sage"


# ═══════════════════════════════════════════════════════════════════════════════
# TYPEWRITER
# ═══════════════════════════════════════════════════════════════════════════════

func _show_text(text: String) -> void:
	text = _clean_tags(text)
	typing_active = true
	typing_abort = false

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
		if not is_inside_tree():
			break
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
		var tree := get_tree()
		if tree == null:
			return
		await tree.process_frame
		elapsed += get_process_delta_time()
	_advance_requested = false


# ═══════════════════════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if scene_finished:
		return

	var pressed := false
	if event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true

	if pressed:
		if typing_active:
			_skip_typewriter()
		else:
			_advance_requested = true
		get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
# TRANSITION
# ═══════════════════════════════════════════════════════════════════════════════

func _transition_out() -> void:
	SFXManager.play("scene_transition")
	scene_finished = true

	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("warm")

	# Store eveil flag + initial oghams (previously done in SceneAntreMerlin)
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		if gm.has_method("set"):
			gm.set("eveil_seen", true)

		var bestiole_data: Dictionary = gm.get("bestiole") if gm.get("bestiole") is Dictionary else {}
		if not bestiole_data.has("known_oghams"):
			bestiole_data["known_oghams"] = ["beith", "luis", "quert"]
			bestiole_data["equipped_oghams"] = ["beith", "luis", "quert", ""]
			gm.set("bestiole", bestiole_data)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(celtic_top, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(celtic_bottom, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(mist_layer, "modulate:a", 0.6, 0.8)
	tween.tween_interval(0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file(NEXT_SCENE))
	await tween.finished


# ═══════════════════════════════════════════════════════════════════════════════
# AUDIO
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Master"
	audio_player.volume_db = linear_to_db(BLIP_VOLUME)
	add_child(audio_player)


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
				# Wait a frame for _ready to load sounds, then check
				if is_inside_tree():
					await get_tree().process_frame
				if voicebox.has_method("is_ready") and voicebox.is_ready():
					voice_ready = true
				else:
					voice_ready = false


func _play_blip() -> void:
	## Soft keyboard click — procedural (no .wav needed)
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


func _play_ui_sound(sound_name: String) -> void:
	if not UI_SOUNDS.has(sound_name):
		return
	var path: String = UI_SOUNDS[sound_name]
	if ResourceLoader.exists(path):
		var snd = load(path)
		if snd:
			audio_player.stream = snd
			audio_player.play()


func _on_resized() -> void:
	call_deferred("_layout_ui")
