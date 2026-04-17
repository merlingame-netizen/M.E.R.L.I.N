## ═══════════════════════════════════════════════════════════════════════════════
## SceneRencontreMerlin — Merged Eveil + Antre in one scene
## ═══════════════════════════════════════════════════════════════════════════════
## 2-phase flow: LLM_INTRO (greeting + ogham reveal + mission) → Transition
## Central dialogue card with LLM-driven text. No portrait sprite.
## ═══════════════════════════════════════════════════════════════════════════════

extends Control

const SCENE_HUB := "res://scenes/BroceliandeForest3D.tscn"      # Was HubAntre (archived)
const SCENE_BIOME := "res://scenes/BroceliandeForest3D.tscn"   # Was TransitionBiome (archived)
const SCENE_TUTORIAL := "res://scenes/BroceliandeForest3D.tscn" # Was IntroTutorial (archived)
const DATA_PATH := "res://data/dialogues/scene_dialogues.json"
var _next_scene: String = SCENE_HUB

const UI_SPEED_FACTOR := 1.45
const BLIP_VOLUME := 0.04
const MAX_ADVANCE_WAIT := 16.0
const LLM_READY_WAIT_MAX := 3.0
const LLM_POLL_INTERVAL := 0.12

const CARD_MAX_WIDTH := 720.0
const CARD_MAX_HEIGHT := 800.0

const STARTER_OGHAMS := [
	{"name": "Beith", "symbol": "\u1681", "meaning": "Bouleau — Nouveau depart", "gameplay": "Revele les effets d'un choix"},
	{"name": "Luis", "symbol": "\u1682", "meaning": "Sorbier — Protection", "gameplay": "Annule un changement negatif"},
	{"name": "Quert", "symbol": "\u168A", "meaning": "Pommier — Guerison", "gameplay": "Ramene vers l'equilibre"},
]

const CLASS_TO_BIOME := {
	"druide": "cercles_pierres",
	"guerrier": "villages_celtes",
	"barde": "cotes_sauvages",
	"eclaireur": "foret_broceliande",
}

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE STATE MACHINE
# ═══════════════════════════════════════════════════════════════════════════════

enum Phase {
	LLM_INTRO,          # Merged: Intro + Ogham reveal + Mission (single flow)
	TRANSITIONING,      # Exit to HubAntre
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCENE NODES (@onready)
# ═══════════════════════════════════════════════════════════════════════════════

@onready var parchment_bg: ColorRect = $ParchmentBg
@onready var mist_layer: ColorRect = $MistLayer
@onready var celtic_top: Label = $CelticTop
@onready var celtic_bottom: Label = $CelticBottom
@onready var card: PanelContainer = $Card
@onready var card_vbox: VBoxContainer = $Card/CardVBox
@onready var merlin_text: RichTextLabel = $Card/CardVBox/MerlinText
@onready var skip_hint: Label = $Card/CardVBox/SkipHint
@onready var response_container: VBoxContainer = $ResponseContainer
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

# Dynamic nodes (created at runtime)
var ogham_panel: PanelContainer
var response_buttons: Array[Button] = []
var _dialogue_source_badge: PanelContainer
var _response_source_badge: PanelContainer
var _last_response_source: String = "static"

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var current_phase: Phase = Phase.LLM_INTRO
var scene_finished: bool = false
var typing_active: bool = false
var typing_abort: bool = false
var _advance_requested: bool = false
var _mist_tween: Tween
var _entry_tween: Tween
var _llm_wait_tween: Tween
var _skip_hint_tween: Tween
var card_target_pos := Vector2.ZERO

# Dialogue data
var dialogue_data: Dictionary = {}
var eveil_lines: Array = []
var _response_chosen: int = -1

# Game state
var player_class: String = "druide"
var suggested_biome: String = "foret_broceliande"

# Fonts
var title_font: Font
var body_font: Font

# LLM
var merlin_ai: Node = null

# Extracted modules
var _llm_module: RencontreLLM
var _dialogue_module: RencontreDialogue


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_load_fonts()
	_load_data()
	_load_game_state()
	_llm_module = RencontreLLM.new(self)
	_dialogue_module = RencontreDialogue.new(self)
	_configure_ui()
	_configure_audio()

	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("pensif")

	resized.connect(_on_resized)
	_start_mist_animation()

	if not is_inside_tree():
		return

	_play_entry_animation()
	if not is_inside_tree():
		return

	# Start phase machine
	_run_phase(Phase.LLM_INTRO)


func _exit_tree() -> void:
	_clear_merlin_scene_context()


# ═══════════════════════════════════════════════════════════════════════════════
# DATA LOADING
# ═══════════════════════════════════════════════════════════════════════════════

func _load_fonts() -> void:
	title_font = MerlinVisual.get_font("title")
	body_font = MerlinVisual.get_font("body")
	if body_font == null:
		body_font = title_font


func _load_data() -> void:
	var path: String = DATA_PATH
	var locale_mgr = get_node_or_null("/root/LocaleManager")
	if locale_mgr and locale_mgr.has_method("get_data_path"):
		path = locale_mgr.get_data_path(DATA_PATH)

	if not FileAccess.file_exists(path):
		_set_fallback_data()
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_set_fallback_data()
		return
	file.close()

	var data: Dictionary = json.data
	eveil_lines = data.get("scene_eveil", {}).get("lines", [])
	if eveil_lines.is_empty():
		_set_fallback_data()
		return

	dialogue_data = data.get("scene_antre_merlin", {})


func _set_fallback_data() -> void:
	eveil_lines = [
		{"text": "... Tu es la.", "emotion": "soulagement_profond"},
		{"text": "J'ai attendu. Longtemps.", "emotion": "vulnerabilite_rare"},
		{"text": "La brume t'a laisse passer. C'est bon signe.", "emotion": "transition_vers_humour"},
		{"text": "Bon. Bienvenue a Broceliande.", "emotion": "accueil_jovial"},
	]


func _load_game_state() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		player_class = gm.get("player_class") if gm.get("player_class") is String else "druide"
	suggested_biome = CLASS_TO_BIOME.get(player_class, "foret_broceliande")
	merlin_ai = get_node_or_null("/root/MerlinAI")


func _set_merlin_scene_context(scene_id: String, overrides: Dictionary = {}) -> void:
	if merlin_ai == null or not merlin_ai.has_method("set_scene_context"):
		return
	var payload: Dictionary = {
		"player_class": player_class,
		"suggested_biome": suggested_biome
	}
	for key in overrides.keys():
		payload[key] = overrides[key]
	merlin_ai.set_scene_context(scene_id, payload)


func _clear_merlin_scene_context() -> void:
	if merlin_ai and merlin_ai.has_method("clear_scene_context"):
		merlin_ai.clear_scene_context()


# ═══════════════════════════════════════════════════════════════════════════════
# UI BUILD
# ═══════════════════════════════════════════════════════════════════════════════

func _configure_ui() -> void:
	# CRT terminal background
	parchment_bg.material = null
	parchment_bg.color = MerlinVisual.CRT_PALETTE.bg_deep

	# Configure mist layer
	mist_layer.color = MerlinVisual.CRT_PALETTE.mist

	# Configure celtic ornaments
	_configure_celtic_ornament(celtic_top)
	_configure_celtic_ornament(celtic_bottom)

	# Style central card
	_apply_card_style()

	# Hide portrait container (no longer used)
	var portrait_node := get_node_or_null("Card/CardVBox/PortraitContainer")
	if portrait_node:
		portrait_node.visible = false

	# Style separator
	var sep_left: ColorRect = $Card/CardVBox/SeparatorContainer/SepLeft
	var sep_diamond: Label = $Card/CardVBox/SeparatorContainer/SepDiamond
	var sep_right: ColorRect = $Card/CardVBox/SeparatorContainer/SepRight
	sep_left.color = MerlinVisual.CRT_PALETTE.line
	sep_diamond.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	sep_right.color = MerlinVisual.CRT_PALETTE.line

	# Style text area
	if body_font:
		merlin_text.add_theme_font_override("normal_font", body_font)
	merlin_text.add_theme_font_size_override("normal_font_size", 24)
	merlin_text.add_theme_color_override("default_color", MerlinVisual.CRT_PALETTE.phosphor)

	# Dialogue source badge (dynamic — LLMSourceBadge)
	_dialogue_source_badge = LLMSourceBadge.create("static")
	_dialogue_source_badge.visible = false
	card_vbox.add_child(_dialogue_source_badge)

	# Style skip hint
	if body_font:
		skip_hint.add_theme_font_override("font", body_font)
	skip_hint.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)

	# Response buttons (dynamic)
	_build_response_buttons()
	# Ogham panel (dynamic)
	_build_ogham_panel()

	_layout_ui()


func _apply_card_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
	style.border_color = MerlinVisual.CRT_PALETTE.border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.shadow_color = MerlinVisual.CRT_PALETTE.shadow
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 32
	style.content_margin_top = 28
	style.content_margin_right = 32
	style.content_margin_bottom = 28
	card.add_theme_stylebox_override("panel", style)


func _configure_celtic_ornament(lbl: Label) -> void:
	var pattern := ["\u2500", "\u2022", "\u2500", "\u2500", "\u25c6", "\u2500", "\u2500", "\u2022", "\u2500"]
	var line := ""
	for i in range(40):
		line += pattern[i % pattern.size()]
	lbl.text = line
	lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)


func _build_response_buttons() -> void:
	for i in range(3):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = "..."
		btn.mouse_filter = Control.MOUSE_FILTER_STOP

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
		btn_style.border_color = MerlinVisual.CRT_PALETTE.border
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(4)
		btn_style.content_margin_left = 16
		btn_style.content_margin_right = 16
		btn_style.content_margin_top = 8
		btn_style.content_margin_bottom = 8
		var btn_hover := btn_style.duplicate()
		btn_hover.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
		btn_hover.border_color = MerlinVisual.CRT_PALETTE.amber
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_hover)
		btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
		btn.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE.amber)
		if body_font:
			btn.add_theme_font_override("font", body_font)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func(): _dialogue_module.on_response_chosen(i))
		btn.mouse_entered.connect(func(): SFXManager.play("choice_hover"))
		response_container.add_child(btn)
		response_buttons.append(btn)

	# Response source badge (dev indicator — appended after buttons)
	_response_source_badge = LLMSourceBadge.create("static")
	_response_source_badge.visible = false
	response_container.add_child(_response_source_badge)


func _build_ogham_panel() -> void:
	ogham_panel = PanelContainer.new()
	ogham_panel.visible = false
	ogham_panel.modulate.a = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
	style.border_color = MerlinVisual.CRT_PALETTE.ogham_glow
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	ogham_panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	ogham_panel.add_child(hbox)

	for ogham in STARTER_OGHAMS:
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		# Pixel art ogham icon (16x16 scaled to 36px)
		var ogham_key: String = str(ogham.name).to_lower()
		var ogham_icon := PixelOghamIcon.new()
		ogham_icon.setup(ogham_key, 36.0)
		ogham_icon.reveal(true)
		vbox.add_child(ogham_icon)
		var symbol := Label.new()
		symbol.text = ogham.symbol
		symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		symbol.add_theme_font_size_override("font_size", 32)
		symbol.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.ogham_glow)
		vbox.add_child(symbol)
		var name_lbl := Label.new()
		name_lbl.text = ogham.name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if title_font:
			name_lbl.add_theme_font_override("font", title_font)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
		vbox.add_child(name_lbl)
		var meaning := Label.new()
		meaning.text = ogham.meaning
		meaning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if body_font:
			meaning.add_theme_font_override("font", body_font)
		meaning.add_theme_font_size_override("font_size", 11)
		meaning.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
		vbox.add_child(meaning)
		# Gameplay effect label
		var gameplay := Label.new()
		gameplay.text = ogham.get("gameplay", "")
		gameplay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if body_font:
			gameplay.add_theme_font_override("font", body_font)
		gameplay.add_theme_font_size_override("font_size", 10)
		gameplay.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.ogham_glow)
		gameplay.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gameplay.custom_minimum_size.x = 120
		vbox.add_child(gameplay)
		hbox.add_child(vbox)
	add_child(ogham_panel)


# ═══════════════════════════════════════════════════════════════════════════════
# LAYOUT
# ═══════════════════════════════════════════════════════════════════════════════

func _layout_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	var card_w := minf(CARD_MAX_WIDTH, vp.x * 0.85)
	var card_h := minf(CARD_MAX_HEIGHT, vp.y * 0.62)
	card.size = Vector2(card_w, card_h)
	card.position = Vector2((vp.x - card_w) * 0.5, (vp.y - card_h) * 0.5)
	card.pivot_offset = card.size * 0.5
	card_target_pos = card.position

	if celtic_top:
		celtic_top.size = Vector2(vp.x, 30)
		celtic_top.position = Vector2(0, card.position.y - 35)
	if celtic_bottom:
		celtic_bottom.size = Vector2(vp.x, 30)
		celtic_bottom.position = Vector2(0, card.position.y + card_h + 5)

	# Position ogham below card
	if ogham_panel:
		var ow := minf(500, vp.x * 0.85)
		ogham_panel.size.x = ow
		ogham_panel.position = Vector2((vp.x - ow) * 0.5, card.position.y + card_h + 20)


func _on_resized() -> void:
	call_deferred("_layout_ui")


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _play_entry_animation() -> void:
	if not card:
		return
	SFXManager.play("scene_transition")
	var target_y: float = card_target_pos.y
	card.modulate.a = 0.0
	card.position.y = target_y + 40
	if _entry_tween:
		_entry_tween.kill()
	_entry_tween = create_tween()
	_entry_tween.tween_property(celtic_top, "modulate:a", 1.0, _scaled_delay(0.32)).set_trans(Tween.TRANS_SINE)
	_entry_tween.parallel().tween_property(celtic_bottom, "modulate:a", 1.0, _scaled_delay(0.32)).set_trans(Tween.TRANS_SINE)
	_entry_tween.tween_property(card, "position:y", target_y, _scaled_delay(0.28)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_entry_tween.parallel().tween_property(card, "modulate:a", 1.0, _scaled_delay(0.18)).set_trans(Tween.TRANS_SINE)


func _start_mist_animation() -> void:
	if _mist_tween:
		_mist_tween.kill()
	_mist_tween = create_tween().set_loops()
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.25, 8.0).set_trans(Tween.TRANS_SINE)
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.08, 8.0).set_trans(Tween.TRANS_SINE)


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE STATE MACHINE
# ═══════════════════════════════════════════════════════════════════════════════

func _run_phase(phase: Phase) -> void:
	if scene_finished or not is_inside_tree():
		return
	current_phase = phase

	match phase:
		Phase.LLM_INTRO:
			_set_merlin_scene_context("scene_rencontre_merlin", {
				"phase": "llm_intro",
				"must_reference": ["Runes", "Factions"]
			})
			await _phase_llm_intro()
		Phase.TRANSITIONING:
			await _transition_out()


## Merged LLM_INTRO: greeting → ogham reveal → mission briefing
func _phase_llm_intro() -> void:
	# Wait for LLM readiness (short cap to keep pacing snappy)
	if merlin_ai and not merlin_ai.is_ready:
		var wait_elapsed: float = 0.0
		while merlin_ai and not merlin_ai.is_ready and wait_elapsed < LLM_READY_WAIT_MAX:
			await get_tree().create_timer(LLM_POLL_INTERVAL).timeout
			wait_elapsed += LLM_POLL_INTERVAL
			if not is_inside_tree():
				return

	_set_mood("pensif")

	# --- Part 1: Welcome ---
	var archetype: String = "druide"
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.get("archetype_title") is String:
		archetype = str(gm.get("archetype_title"))

	var intro_text := await _llm_module.generate_from_rag(RencontreLLM.RAG_INTRO_CONTEXT % archetype)

	if intro_text != "":
		_dialogue_module.update_dialogue_badge("llm")
		await _dialogue_module.show_text(intro_text)
	else:
		_dialogue_module.update_dialogue_badge("static")
		await _dialogue_module.show_text("Bienvenue a Broceliande, voyageur. Runes, factions et aventure t'attendent.")
	if not is_inside_tree():
		return

	await get_tree().create_timer(_scaled_delay(0.1)).timeout
	_dialogue_module.set_skip_hint(true)
	_advance_requested = false
	await _wait_for_advance(30.0)
	_dialogue_module.set_skip_hint(false)

	# Interactive response
	var fade1 := create_tween()
	fade1.tween_property(merlin_text, "modulate:a", 0.0, _scaled_delay(0.12))
	await fade1.finished
	merlin_text.modulate.a = 1.0
	await _dialogue_module.show_response_blocks(1, "Merlin t'a presente le monde.")

	if gm and gm.has_method("set"):
		gm.set("eveil_seen", true)

	if not is_inside_tree():
		return

	# --- Part 2: Ogham Reveal ---
	_set_mood("amuse")

	var ogham_intro_text := await _llm_module.generate_from_rag(RencontreLLM.RAG_OGHAM_REVEAL)
	if ogham_intro_text != "":
		_dialogue_module.update_dialogue_badge("llm")
		await _dialogue_module.show_text(ogham_intro_text)
	else:
		_dialogue_module.update_dialogue_badge("static")
		await _dialogue_module.show_text("Trois lettres sacrees brillent dans la brume, attendant ta main.")
	if not is_inside_tree():
		return

	await get_tree().create_timer(_scaled_delay(0.1)).timeout
	_dialogue_module.set_skip_hint(true)
	_advance_requested = false
	await _wait_for_advance(15.0)
	_dialogue_module.set_skip_hint(false)

	# Ogham reveal
	_dialogue_module.update_dialogue_badge("static")
	_set_mood("sage")
	var ogham_line: String = dialogue_data.get("ogham_reveal", {}).get("line", {}).get("text", "Trois Runes pour commencer ton chemin.")
	var fade_ogham := create_tween()
	fade_ogham.tween_property(merlin_text, "modulate:a", 0.0, _scaled_delay(0.12))
	await fade_ogham.finished
	merlin_text.modulate.a = 1.0

	await _dialogue_module.show_text(ogham_line)
	if not is_inside_tree():
		return

	# Show ogham panel (pixel reveal)
	SFXManager.play("flash_boom")
	ogham_panel.visible = true
	ogham_panel.modulate.a = 0.0
	_layout_ui()
	var pca: Node = get_node_or_null("/root/PixelContentAnimator")
	if pca:
		await get_tree().process_frame
		pca.reveal(ogham_panel, {"duration": 0.5, "block_size": 8})
		await get_tree().create_timer(0.55).timeout
	else:
		var tw := create_tween()
		tw.tween_property(ogham_panel, "modulate:a", 1.0, _scaled_delay(0.6)).set_trans(Tween.TRANS_SINE)
		await tw.finished

	# Store starter oghams in GameManager
	var gm2 := get_node_or_null("/root/GameManager")
	if gm2 and gm2.has_method("set"):
		var oghams_data: Dictionary = gm2.get("oghams") if gm2.get("oghams") is Dictionary else {}
		if not oghams_data.has("known_oghams"):
			oghams_data["known_oghams"] = ["beith", "luis", "quert"]
			oghams_data["equipped_oghams"] = ["beith", "luis", "quert", ""]
			gm2.set("oghams", oghams_data)

	if not is_inside_tree():
		return
	await get_tree().create_timer(_scaled_delay(0.65)).timeout
	_dialogue_module.set_skip_hint(true)
	_advance_requested = false
	await _wait_for_advance(30.0)
	_dialogue_module.set_skip_hint(false)

	# Hide ogham panel (pixel dissolve)
	if pca:
		pca.dissolve(ogham_panel, {"duration": 0.3, "block_size": 8})
		await get_tree().create_timer(0.35).timeout
	else:
		var hide_tw := create_tween()
		hide_tw.tween_property(ogham_panel, "modulate:a", 0.0, _scaled_delay(0.28))
		await hide_tw.finished
	ogham_panel.visible = false

	if not is_inside_tree():
		return

	# --- Part 3: Mission briefing ---
	_set_mood("serieux")
	var mission_text := await _llm_module.generate_from_rag(RencontreLLM.RAG_MISSION_HUB)
	if mission_text != "":
		_dialogue_module.update_dialogue_badge("llm")
		await _dialogue_module.show_text(mission_text)
	else:
		_dialogue_module.update_dialogue_badge("static")
		await _dialogue_module.show_text("Carte, Runes, sauvegardes — tout t'attend dans l'Antre. Tu n'es pas seul.")
	if not is_inside_tree():
		return

	await get_tree().create_timer(_scaled_delay(0.1)).timeout
	_dialogue_module.set_skip_hint(true)
	_advance_requested = false
	await _wait_for_advance(20.0)
	_dialogue_module.set_skip_hint(false)

	# Set default biome
	var gm3 := get_node_or_null("/root/GameManager")
	if gm3 and gm3.has_method("set"):
		gm3.set("selected_biome", "foret_broceliande")

	# B.5 — First-run destination choice: Hub or direct adventure
	if not is_inside_tree():
		return
	await _show_destination_choice()

	_run_phase(Phase.TRANSITIONING)


## B.5 — First-run destination choice: Hub exploration or direct adventure
## Displays Merlin's question + 2 response buttons. Sets _next_scene based on choice.
func _show_destination_choice() -> void:
	if not is_inside_tree():
		return

	var choice: int = await _dialogue_module.show_destination_choice()

	# Apply destination based on choice
	if choice == 1:
		_next_scene = SCENE_BIOME
		var gm4 := get_node_or_null("/root/GameManager")
		if gm4 and gm4.has_method("set"):
			gm4.set("selected_biome", suggested_biome)
			gm4.set("skipped_hub", true)
	else:
		var gm_tut := get_node_or_null("/root/GameManager")
		if gm_tut and not gm_tut.flags.get("tutorial_done", false):
			_next_scene = SCENE_TUTORIAL
		else:
			_next_scene = SCENE_HUB


func _scaled_delay(seconds: float) -> float:
	return maxf(0.01, seconds / UI_SPEED_FACTOR)


# ═══════════════════════════════════════════════════════════════════════════════
# INPUT & WAIT
# ═══════════════════════════════════════════════════════════════════════════════

func _wait_for_advance(max_wait: float) -> void:
	var effective_wait := minf(max_wait, MAX_ADVANCE_WAIT)
	var elapsed := 0.0
	while elapsed < effective_wait and not _advance_requested and not scene_finished:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_advance_requested = false


func _unhandled_input(event: InputEvent) -> void:
	if scene_finished:
		return
	var pressed := false
	if event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventKey and event.pressed and not event.echo:
		var response_idx := -1
		match event.keycode:
			KEY_1, KEY_KP_1:
				response_idx = 0
			KEY_2, KEY_KP_2:
				response_idx = 1
			KEY_3, KEY_KP_3:
				response_idx = 2
		if response_idx >= 0 and response_container and response_container.visible and _response_chosen < 0:
			if response_idx < response_buttons.size():
				var btn: Button = response_buttons[response_idx]
				if btn and btn.visible and not btn.disabled:
					_dialogue_module.on_response_chosen(response_idx)
					get_viewport().set_input_as_handled()
					return
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true

	if pressed:
		if typing_active:
			_dialogue_module.skip_typewriter()
		else:
			_advance_requested = true
		get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
# MOOD & TRANSITION
# ═══════════════════════════════════════════════════════════════════════════════

func _set_mood(emotion: String) -> void:
	var mood := "sage"
	if "humour" in emotion or "jovial" in emotion or "amuse" in emotion:
		mood = "amuse"
	elif "vulnerabilite" in emotion or "soulagement" in emotion or "pensif" in emotion:
		mood = "pensif"
	elif "accueil" in emotion or "warm" in emotion:
		mood = "warm"
	elif "serieux" in emotion or "gravite" in emotion or "sage" in emotion:
		mood = "serieux"
	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood(mood)


func _transition_out() -> void:
	SFXManager.play("scene_transition")
	scene_finished = true
	_set_mood("warm")

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "modulate:a", 0.0, _scaled_delay(0.45))
	tween.parallel().tween_property(celtic_top, "modulate:a", 0.0, _scaled_delay(0.28))
	tween.parallel().tween_property(celtic_bottom, "modulate:a", 0.0, _scaled_delay(0.28))
	tween.parallel().tween_property(mist_layer, "modulate:a", 0.6, _scaled_delay(0.55))
	tween.tween_interval(_scaled_delay(0.18))
	tween.tween_callback(func():
		_clear_merlin_scene_context()
		if is_inside_tree():
			PixelTransition.transition_to(_next_scene)
	)
	await tween.finished


# ═══════════════════════════════════════════════════════════════════════════════
# AUDIO
# ═══════════════════════════════════════════════════════════════════════════════

func _configure_audio() -> void:
	audio_player.volume_db = linear_to_db(BLIP_VOLUME)


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
