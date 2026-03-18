## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Game UI — Lightweight Orchestrator (v1.0)
## ═══════════════════════════════════════════════════════════════════════════════
## Delegates all logic to focused modules (UICardDisplay, UIDeckModule,
## UIStatusBar, UINarratorModule, UIOptionsModule, UIBiomeArt, UIOverlaysModule).
## Keeps @onready scene refs, signals, _configure_ui, layout, input, and
## the display_card() coordination method.
## ═══════════════════════════════════════════════════════════════════════════════

extends Control
class_name MerlinGameUI

signal option_chosen(option: int)  # 0=LEFT, 1=CENTER, 2=RIGHT
signal skill_activated(skill_id: String)
signal pause_requested
signal merlin_dialogue_requested(player_input: String)
signal journal_requested

# Explicit preloads — required when scripts created outside editor (UID cache stale)
const PixelSceneCompositor = preload("res://scripts/ui/pixel_scene_compositor.gd")
const PixelSceneData = preload("res://scripts/ui/pixel_scene_data.gd")
const CardSceneCompositorClass = preload("res://scripts/ui/card_scene_compositor.gd")

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION (shared with modules via _ui reference)
# ═══════════════════════════════════════════════════════════════════════════════

const INTRO_PIXEL_COLS := 84
const INTRO_PIXEL_ROWS := 48
const INTRO_STACK_BATCH := 26
const INTRO_STACK_STEP := 0.02
const INTRO_DECK_COUNT := 12
const TOP_ZONE_RATIO := 0.12
const CARD_ZONE_RATIO := 0.70
const BOTTOM_ZONE_RATIO := 0.18
const CARD_PORTRAIT_RATIO := 1.05

const BIOME_SHORT_NAMES := {
	"foret_broceliande": "broceliande",
	"landes_bruyere": "landes",
	"cotes_sauvages": "cotes",
	"villages_celtes": "villages",
	"cercles_pierres": "cercles",
	"marais_korrigans": "marais",
	"collines_dolmens": "collines",
}

const BIOME_DEFAULT_SEASON := {
	"broceliande": "automne",
	"landes": "hiver",
	"cotes": "hiver",
	"villages": "ete",
	"cercles": "printemps",
	"marais": "printemps",
	"collines": "automne",
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCENE REFERENCES (@onready from MerlinGameUI.tscn)
# ═══════════════════════════════════════════════════════════════════════════════

# Top status bar
@onready var _top_status_bar: HBoxContainer = $MainVBox/TopStatusBar
@onready var life_panel: VBoxContainer = $MainVBox/TopStatusBar/LifePanel
@onready var _life_bar: ProgressBar = $MainVBox/TopStatusBar/LifePanel/LifeBar
@onready var _life_counter: Label = $MainVBox/TopStatusBar/LifePanel/LifeCounter
@onready var _essence_counter: Label = $MainVBox/TopStatusBar/EssencePanel/EssenceCounter

# Card area
@onready var card_container: Control = $MainVBox/MiddleZone/CardContainer
@onready var card_panel: Panel = $MainVBox/MiddleZone/CardContainer/CardPanel
@onready var _card_visual_split: VBoxContainer = $MainVBox/MiddleZone/CardContainer/CardPanel/CardVisualSplit
@onready var _card_illustration_panel: PanelContainer = $MainVBox/MiddleZone/CardContainer/CardPanel/CardVisualSplit/CardIllustration
@onready var _card_body_panel: PanelContainer = $MainVBox/MiddleZone/CardContainer/CardPanel/CardVisualSplit/CardBodyPanel
@onready var _card_body_vbox: VBoxContainer = $MainVBox/MiddleZone/CardContainer/CardPanel/CardVisualSplit/CardBodyPanel/CardBodyVBox
@onready var card_speaker: Label = $MainVBox/MiddleZone/CardContainer/CardPanel/CardVisualSplit/CardBodyPanel/CardBodyVBox/CardSpeaker
@onready var card_text: RichTextLabel = $MainVBox/MiddleZone/CardContainer/CardPanel/CardVisualSplit/CardBodyPanel/CardBodyVBox/CardText
@onready var _card_body_content_host: Control = $MainVBox/MiddleZone/CardContainer/CardPanel/CardVisualSplit/CardBodyPanel/BodyContentHost
@onready var _text_pixel_fx_layer: Control = $MainVBox/MiddleZone/CardContainer/CardPanel/TextPixelFxLayer
@onready var _illo_bg: ColorRect = $MainVBox/MiddleZone/CardContainer/CardPanel/CardVisualSplit/CardIllustration/IlloLayer/IlloBg
@onready var _tile_center: CenterContainer = $MainVBox/MiddleZone/CardContainer/CardPanel/CardVisualSplit/CardIllustration/IlloLayer/TileCenter
@onready var _portrait_center: CenterContainer = $MainVBox/MiddleZone/CardContainer/CardPanel/CardVisualSplit/CardIllustration/IlloLayer/PortraitCenter

# Deck columns
@onready var _pioche_column: VBoxContainer = $MainVBox/MiddleZone/PiocheColumn
@onready var _remaining_deck_root: Control = $MainVBox/MiddleZone/PiocheColumn/DeckRoot
@onready var _remaining_deck_label: Label = $MainVBox/MiddleZone/PiocheColumn/DeckCount
@onready var _cimetiere_column: VBoxContainer = $MainVBox/MiddleZone/CimetiereColumn
@onready var _discard_root: Control = $MainVBox/MiddleZone/CimetiereColumn/DiscardRoot
@onready var _discard_label: Label = $MainVBox/MiddleZone/CimetiereColumn/DiscardCount

# Bottom zone + options
@onready var _bottom_zone: VBoxContainer = $MainVBox/BottomZone
@onready var _bottom_push_spacer: Control = $MainVBox/BottomZone/BottomSpacer
@onready var options_container: HBoxContainer = $MainVBox/BottomZone/OptionsBar
@onready var _btn_a: Button = $MainVBox/BottomZone/OptionsBar/OptionVBoxA/BtnA
@onready var _btn_b: Button = $MainVBox/BottomZone/OptionsBar/OptionVBoxB/BtnB
@onready var _btn_c: Button = $MainVBox/BottomZone/OptionsBar/OptionVBoxC/BtnC
@onready var info_panel: HBoxContainer = $MainVBox/BottomZone/InfoPanel
@onready var mission_label: Label = $MainVBox/BottomZone/InfoPanel/MissionLabel
@onready var cards_label: Label = $MainVBox/BottomZone/InfoPanel/CardsLabel

# Overlay layers
@onready var parchment_bg: ColorRect = $ParchmentBg
@onready var biome_art_layer: Control = $BiomeArtLayer
@onready var main_vbox: VBoxContainer = $MainVBox
@onready var _middle_zone: HBoxContainer = $MainVBox/MiddleZone
@onready var _deck_fx_layer: Control = $DeckFxLayer
@onready var _status_clock_panel: PanelContainer = $ClockPanel
@onready var _status_clock_label: Label = $ClockPanel/ClockLabel
@onready var _status_clock_timer: Timer = $ClockTimer
@onready var narrator_overlay: Control = $NarratorOverlay

# ═══════════════════════════════════════════════════════════════════════════════
# DYNAMIC NODES (created in _configure_ui, accessed by modules via _ui.xxx)
# ═══════════════════════════════════════════════════════════════════════════════

var _card_source_badge: PanelContainer
var _scene_compositor: PixelSceneCompositor
var _scene_compositor_v2: Control = null
var _pixel_portrait: PixelCharacterPortrait
var _npc_portrait: PixelNpcPortrait
var _reward_badge: MerlinRewardBadge
var option_buttons: Array[Button] = []
var option_labels: Array[Label] = []
var _option_desc_labels: Array[Label] = []
var _minigame_badge: Label
var _card_title_label: Label
var _what_if_labels: Array[Label] = []
var _dialogue_btn: Button
var _dialogue_popup: Control
var _dialogue_bubble: MerlinBubble
var _is_dialogue_open: bool = false
var _tool_label: Label
var _day_label: Label
var _mission_progress_label: Label
var _current_speaker_key: String = ""
var biome_indicator: Label
var _perk_badge: Label = null

# ═══════════════════════════════════════════════════════════════════════════════
# STATE (shared across modules)
# ═══════════════════════════════════════════════════════════════════════════════

var current_card: Dictionary = {}
var _card_float_tween: Tween
var _card_entry_tween: Tween
var _critical_badge_tween: Tween
var _biome_breath_tween: Tween
var _card_base_pos: Vector2 = Vector2.ZERO
var _opening_sequence_done: bool = false
var _ui_blocks_for_intro: Array[Control] = []
var _biome_art_pixels: Array[ColorRect] = []
var _ambient_timer: Timer
var _ambient_particles: Array[ColorRect] = []
var _ambient_biome_key: String = ""
var _active_biome_visual: String = "broceliande"
var _active_season_visual: String = "automne"
var _active_hour_visual: int = -1

var title_font: Font
var body_font: Font

# ═══════════════════════════════════════════════════════════════════════════════
# MODULES
# ═══════════════════════════════════════════════════════════════════════════════

var _card_display: UICardDisplay
var _deck_module: UIDeckModule
var _status_bar: UIStatusBar
var _narrator_module: UINarratorModule
var _options_module: UIOptionsModule
var _biome_art: UIBiomeArt
var _overlays_module: UIOverlaysModule
var _config_module: UIConfigModule

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Instantiate modules
	_card_display = UICardDisplay.new()
	_deck_module = UIDeckModule.new()
	_status_bar = UIStatusBar.new()
	_narrator_module = UINarratorModule.new()
	_options_module = UIOptionsModule.new()
	_biome_art = UIBiomeArt.new()
	_overlays_module = UIOverlaysModule.new()
	_config_module = UIConfigModule.new()

	# Initialize modules with self reference (before _configure_ui so modules are ready)
	_card_display.initialize(self)
	_deck_module.initialize(self)
	_status_bar.initialize(self)
	_narrator_module.initialize(self)
	_options_module.initialize(self)
	_biome_art.initialize(self)
	_overlays_module.initialize(self)
	_config_module.initialize(self)

	# Configure UI (creates dynamic nodes, applies theming, uses modules)
	_config_module.configure_ui()

	# Module-specific setup (after _configure_ui so dynamic nodes exist)
	_card_display.setup_card_3d()
	_status_bar.setup_life_segments()
	_narrator_module.init_blip_pool()
	_overlays_module.setup_dialogue_nodes()

	# Initial state
	_status_bar.update_life_essence(MerlinConstants.LIFE_ESSENCE_START)
	_status_bar.update_essences_collected(0)
	_deck_module.reset_run_visuals()


func _process(delta: float) -> void:
	_card_display.update_card_3d_tilt(delta)


# ═══════════════════════════════════════════════════════════════════════════════
# LAYOUT
# ═══════════════════════════════════════════════════════════════════════════════

func _layout_run_zones() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.y <= 0.0:
		return
	var top_h: float = maxf(52.0, vp_size.y * TOP_ZONE_RATIO)
	var middle_h: float = maxf(260.0, vp_size.y * CARD_ZONE_RATIO)
	var bottom_h: float = maxf(180.0, vp_size.y * BOTTOM_ZONE_RATIO)
	var total: float = top_h + middle_h + bottom_h
	if total > vp_size.y:
		var overflow: float = total - vp_size.y
		middle_h = maxf(220.0, middle_h - overflow)
	if _top_status_bar and is_instance_valid(_top_status_bar):
		_top_status_bar.custom_minimum_size = Vector2(0.0, top_h)
	if _middle_zone and is_instance_valid(_middle_zone):
		_middle_zone.custom_minimum_size = Vector2(0.0, middle_h)
	if _bottom_zone and is_instance_valid(_bottom_zone):
		_bottom_zone.custom_minimum_size = Vector2(0.0, bottom_h)
	if _perk_badge and is_instance_valid(_perk_badge):
		_perk_badge.position = Vector2(vp_size.x - 76.0, vp_size.y - 84.0)
		_perk_badge.custom_minimum_size = Vector2(72.0, 14.0)
	if _dialogue_btn and is_instance_valid(_dialogue_btn):
		_dialogue_btn.position = Vector2(vp_size.x - 84.0, vp_size.y - 112.0)


func _layout_card_stage() -> void:
	if not card_container or not is_instance_valid(card_container):
		return
	var stage_size: Vector2 = card_container.size
	if stage_size.x <= 40.0 or stage_size.y <= 40.0:
		stage_size = get_viewport_rect().size
		if card_container.custom_minimum_size.y > 0.0:
			stage_size.y = card_container.custom_minimum_size.y
	var target_h: float = clampf(stage_size.y - 12.0, 260.0, stage_size.y - 12.0)
	var max_w: float = minf(stage_size.x * 0.88, 960.0)
	var target_w: float = clampf(target_h * CARD_PORTRAIT_RATIO, 220.0, max_w)
	var target_size: Vector2 = Vector2(target_w, target_h)
	card_panel.size = target_size
	card_panel.custom_minimum_size = target_size
	var centered_y: float = (stage_size.y - target_size.y) * 0.50
	var max_y: float = maxf(6.0, stage_size.y - target_size.y - 6.0)
	_card_base_pos = Vector2(
		(stage_size.x - target_size.x) * 0.50,
		clampf(centered_y, 6.0, max_y)
	)
	card_panel.position = _card_base_pos
	card_panel.pivot_offset = target_size * 0.5
	if _card_illustration_panel and is_instance_valid(_card_illustration_panel):
		_card_illustration_panel.custom_minimum_size = Vector2(0.0, target_size.y * 0.18)
	if _card_body_panel and is_instance_valid(_card_body_panel):
		_card_body_panel.custom_minimum_size = Vector2(0.0, target_size.y * 0.82)
	_deck_module.update_remaining_deck_visual()
	_deck_module.update_discard_visual()


# ═══════════════════════════════════════════════════════════════════════════════
# DISPLAY CARD — Central coordination across modules
# ═══════════════════════════════════════════════════════════════════════════════

func display_card(card: Dictionary) -> void:
	if card.is_empty():
		push_warning("[MerlinUI] display_card called with empty card")
		return
	current_card = card
	_options_module.reset_highlight()
	if _reward_badge and is_instance_valid(_reward_badge):
		_reward_badge.hide_badge()
	if _critical_badge_tween:
		_critical_badge_tween.kill()
		_critical_badge_tween = null
	if card_panel and is_instance_valid(card_panel):
		card_panel.modulate = Color.WHITE

	# Hide thinking animations
	_overlays_module.hide_merlin_thinking_overlay()
	_narrator_module.hide_thinking()
	_options_module.hide_what_if_labels()

	# Reset button states
	for btn in option_buttons:
		if is_instance_valid(btn):
			btn.set_pressed_no_signal(false)
			btn.release_focus()
			btn.disabled = true
			btn.scale = Vector2.ONE
			btn.modulate = Color(1, 1, 1, 0.0)
			var parent_c: Control = btn.get_parent()
			if parent_c and is_instance_valid(parent_c) and parent_c is Container:
				(parent_c as Container).queue_sort()

	if options_container and is_instance_valid(options_container):
		options_container.modulate.a = 1.0
		options_container.visible = true

	_layout_card_stage()
	_card_display.push_card_shadow()
	_deck_module.animate_remaining_deck_draw()

	SFXManager.play("card_draw")

	# Resolve speaker
	var speaker: String = str(card.get("speaker", ""))
	var speaker_key: String = PixelCharacterPortrait.resolve_character_key(speaker) if speaker != "" else ""
	var is_new_speaker: bool = speaker_key != "" and speaker_key != _current_speaker_key

	if card_speaker and is_instance_valid(card_speaker):
		card_speaker.text = PixelCharacterPortrait.get_character_name(speaker_key) if speaker_key != "" else ""
		card_speaker.visible = not speaker.is_empty()

	if is_new_speaker:
		_current_speaker_key = speaker_key
		var npc_key: String = PixelNpcPortrait.resolve_npc_key(speaker)
		if not npc_key.is_empty() and _npc_portrait and is_instance_valid(_npc_portrait):
			_npc_portrait.visible = true
			_npc_portrait.setup(npc_key, 80.0)
			_npc_portrait.assemble(false)
			if _pixel_portrait and is_instance_valid(_pixel_portrait):
				_pixel_portrait.visible = false
		elif _pixel_portrait and is_instance_valid(_pixel_portrait):
			_pixel_portrait.visible = true
			_pixel_portrait.setup(speaker_key, 5.8)
			_pixel_portrait.assemble(false)
			if _npc_portrait and is_instance_valid(_npc_portrait):
				_npc_portrait.visible = false

	# Card entrance animation
	_card_display.disable_card_3d()
	if card_panel and is_instance_valid(card_panel):
		if _card_float_tween:
			_card_float_tween.kill()
		if _card_entry_tween:
			_card_entry_tween.kill()
		card_panel.position = _card_base_pos
		card_panel.modulate.a = 0.0
		card_panel.scale = Vector2.ONE
		card_panel.rotation_degrees = 0.0
		var pixel_entry_config: Dictionary = {
			"duration": MerlinVisual.CARD_ENTRY_DURATION,
			"block_size": 8,
			"row_stagger": 0.006,
			"jitter": 0.015,
			"scatter_x": 24.0,
			"scatter_y_min": -40.0,
			"scatter_y_max": -100.0,
			"easing": "back_out",
		}
		PixelContentAnimator.reveal(card_panel, pixel_entry_config)
		_card_entry_tween = create_tween()
		_card_entry_tween.tween_interval(MerlinVisual.CARD_ENTRY_DURATION + 0.15)
		_card_entry_tween.tween_callback(_card_display.start_card_float_and_3d)

	# Card title
	if _card_title_label and is_instance_valid(_card_title_label):
		var title_text: String = str(card.get("title", ""))
		if not title_text.is_empty():
			_card_title_label.text = title_text
			_card_title_label.visible = true
		else:
			_card_title_label.visible = false

	# Typewriter text
	if card_text and is_instance_valid(card_text):
		_narrator_module.typewriter_card_text(card.get("text", "..."))

	# Source badge
	if _card_source_badge and is_instance_valid(_card_source_badge):
		var card_source: String = _card_display.detect_card_source(card)
		LLMSourceBadge.update_badge(_card_source_badge, card_source)
		_card_source_badge.visible = true

	# Scene compositor
	var vtags: Array = card.get("visual_tags", [])
	var biome: String = str(card.get("biome", "foret_broceliande"))
	var season: String = str(card.get("season", "automne"))
	if vtags.is_empty():
		vtags = _card_display.derive_card_fallback_tags(card)
	if _scene_compositor_v2 and is_instance_valid(_scene_compositor_v2):
		var card_type: String = str(card.get("type", "narrative"))
		_scene_compositor_v2.compose_layers(vtags, biome, season, card_type)
		_scene_compositor_v2.build_scene(true)
	elif _scene_compositor and is_instance_valid(_scene_compositor):
		_scene_compositor.compose_scene(vtags, biome, season)
		_scene_compositor.assemble(true)

	# Visual + audio tags
	_card_display.apply_card_visual_tags(card)
	_card_display.apply_card_audio_tags(card)

	# Update options
	var options: Array = card.get("options", [])
	for i in range(3):
		var has_option: bool = i < options.size() and options[i] is Dictionary
		var option: Dictionary = options[i] if has_option else {}
		var action_label: String = _options_module.actionize_option_label(str(option.get("label", "")), i)
		if i < option_buttons.size() and is_instance_valid(option_buttons[i]):
			option_buttons[i].text = action_label if has_option else "\u2014"
			option_buttons[i].disabled = true
			option_buttons[i].modulate.a = 0.0 if has_option else 0.35
		if i < _option_desc_labels.size() and is_instance_valid(_option_desc_labels[i]):
			var action_desc: String = str(option.get("action_desc", ""))
			if action_desc.is_empty():
				var risk: String = str(option.get("risk_level", ""))
				match risk:
					"faible": action_desc = "Prudent"
					"moyen": action_desc = "Equilibre"
					"eleve": action_desc = "Audacieux"
			if action_desc.length() > 80:
				var cut: int = action_desc.rfind(" ", 77)
				if cut > 40:
					action_desc = action_desc.substr(0, cut) + "..."
				else:
					action_desc = action_desc.substr(0, 77) + "..."
			_option_desc_labels[i].text = action_desc
			_option_desc_labels[i].visible = false
		if i < option_buttons.size() and is_instance_valid(option_buttons[i]):
			var risk2: String = str(option.get("risk_level", ""))
			match risk2:
				"faible": option_buttons[i].tooltip_text = "Prudent \u2014 risque faible"
				"moyen": option_buttons[i].tooltip_text = "Equilibre \u2014 risque moyen"
				"eleve": option_buttons[i].tooltip_text = "Audacieux \u2014 risque eleve"

	# Minigame badge
	if _minigame_badge and is_instance_valid(_minigame_badge):
		var minigame: Dictionary = card.get("minigame", {})
		if not minigame.is_empty():
			_minigame_badge.text = "\u2694 Mini-jeu: %s (%s)" % [
				str(minigame.get("name", "")), str(minigame.get("desc", ""))]
			_minigame_badge.visible = true
		else:
			_minigame_badge.visible = false

	# Pre-hide buttons
	for j in range(option_buttons.size()):
		if is_instance_valid(option_buttons[j]):
			option_buttons[j].modulate.a = 0.0
			option_buttons[j].scale = Vector2.ONE
			var parent_container: Control = option_buttons[j].get_parent()
			if parent_container and is_instance_valid(parent_container) and parent_container is Container:
				(parent_container as Container).queue_sort()


func mark_card_completed() -> void:
	if current_card.is_empty():
		return
	if bool(current_card.get("_placeholder", false)):
		return
	_deck_module.increment_discard()
	if card_panel and is_instance_valid(card_panel):
		if _card_float_tween:
			_card_float_tween.kill()
		_card_display.disable_card_3d()
		card_panel.scale = Vector2.ONE
		card_panel.rotation_degrees = 0.0
		var pixel_exit_config: Dictionary = {
			"duration": MerlinVisual.CARD_EXIT_DURATION,
			"block_size": 8,
			"row_stagger": 0.005,
			"jitter": 0.012,
			"scatter_x": 28.0,
			"scatter_y_min": -50.0,
			"scatter_y_max": -120.0,
			"easing": "cubic_out",
			"sfx": "card_place",
		}
		PixelContentAnimator.dissolve(card_panel, pixel_exit_config)


# ═══════════════════════════════════════════════════════════════════════════════
# CARD BODY CONTENT HOST
# ═══════════════════════════════════════════════════════════════════════════════

func switch_body_to_content() -> void:
	if _card_body_vbox and is_instance_valid(_card_body_vbox):
		_card_body_vbox.visible = false
	if _card_body_content_host and is_instance_valid(_card_body_content_host):
		_card_body_content_host.visible = true
		_card_body_content_host.mouse_filter = Control.MOUSE_FILTER_STOP


func switch_body_to_text() -> void:
	if _card_body_content_host and is_instance_valid(_card_body_content_host):
		for child in _card_body_content_host.get_children():
			child.queue_free()
		_card_body_content_host.visible = false
		_card_body_content_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _card_body_vbox and is_instance_valid(_card_body_vbox):
		_card_body_vbox.visible = true


func get_body_content_host() -> Control:
	return _card_body_content_host


func set_options_visible(vis: bool) -> void:
	if options_container and is_instance_valid(options_container):
		options_container.visible = vis


# ═══════════════════════════════════════════════════════════════════════════════
# DELEGATED PUBLIC API — Status bar
# ═══════════════════════════════════════════════════════════════════════════════

func update_life_essence(life: int) -> void:
	_status_bar.update_life_essence(life)

func update_essences_collected(value: int) -> void:
	_status_bar.update_essences_collected(value)

func update_resource_bar(tool_id: String, day: int, mission_current: int, mission_total: int, essences_collected: int = 0) -> void:
	_status_bar.update_resource_bar(tool_id, day, mission_current, mission_total, essences_collected)

func update_selected_perk(perk_id: String) -> void:
	_status_bar.update_selected_perk(perk_id)

func update_biome_indicator(biome_name: String, biome_color: Color) -> void:
	_status_bar.update_biome_indicator(biome_name, biome_color)

func update_mission(mission: Dictionary) -> void:
	_status_bar.update_mission(mission)

func update_cards_count(count: int) -> void:
	_status_bar.update_cards_count(count)
	_deck_module.update_cards_count(count)


# ═══════════════════════════════════════════════════════════════════════════════
# DELEGATED PUBLIC API — Deck
# ═══════════════════════════════════════════════════════════════════════════════

func reset_run_visuals() -> void:
	_deck_module.reset_run_visuals()


# ═══════════════════════════════════════════════════════════════════════════════
# DELEGATED PUBLIC API — Narrator / Thinking
# ═══════════════════════════════════════════════════════════════════════════════

func show_thinking() -> void:
	_narrator_module.show_thinking()

func hide_thinking() -> void:
	_narrator_module.hide_thinking()

func show_narrator_intro(biome_key: String = "") -> void:
	await _narrator_module.show_narrator_intro(biome_key)

func show_scenario_intro(title: String, context: String) -> void:
	await _narrator_module.show_scenario_intro(title, context)

func show_narrator_text(text: String) -> void:
	## Stub for controller — displays text in narrator style.
	if card_text and is_instance_valid(card_text):
		_narrator_module.typewriter_card_text(text)


# ═══════════════════════════════════════════════════════════════════════════════
# DELEGATED PUBLIC API — Options
# ═══════════════════════════════════════════════════════════════════════════════

func hide_what_if_labels() -> void:
	_options_module.hide_what_if_labels()

func show_reveal_effects(options: Array, target_index: int) -> void:
	_options_module.show_reveal_effects(options, target_index)


# ═══════════════════════════════════════════════════════════════════════════════
# DELEGATED PUBLIC API — Biome art
# ═══════════════════════════════════════════════════════════════════════════════

func show_opening_sequence(biome_key: String, season_hint: String = "", hour_hint: int = -1) -> void:
	await _biome_art.show_opening_sequence(biome_key, season_hint, hour_hint)

func start_ambient_vfx(biome_key: String) -> void:
	_biome_art.start_ambient_vfx(biome_key)


# ═══════════════════════════════════════════════════════════════════════════════
# DELEGATED PUBLIC API — Overlays
# ═══════════════════════════════════════════════════════════════════════════════

func show_dice_roll(dc: int, target: int) -> void:
	await _overlays_module.show_dice_roll(dc, target)

func show_dice_instant(dc: int, value: int) -> void:
	_overlays_module.show_dice_instant(dc, value)

func show_dice_result(roll: int, dc: int, outcome: String) -> void:
	await _overlays_module.show_dice_result(roll, dc, outcome)

func show_minigame_intro(field: String, tool_bonus_text: String, tool_bonus: int) -> void:
	await _overlays_module.show_minigame_intro(field, tool_bonus_text, tool_bonus)

func show_score_to_d20(score: int, d20: int, tool_bonus: int) -> void:
	_overlays_module.show_score_to_d20(score, d20, tool_bonus)

func show_travel_animation(text: String) -> void:
	await _overlays_module.show_travel_animation(text)

func show_dream_overlay(dream_text: String) -> void:
	await _overlays_module.show_dream_overlay(dream_text)

func show_merlin_thinking_overlay() -> void:
	_overlays_module.show_merlin_thinking_overlay()

func hide_merlin_thinking_overlay() -> void:
	_overlays_module.hide_merlin_thinking_overlay()

func show_pause_menu() -> void:
	_overlays_module.show_pause_menu()

func hide_pause_menu() -> void:
	_overlays_module.hide_pause_menu()

func show_merlin_dialogue_response(text: String) -> void:
	_overlays_module.show_merlin_dialogue_response(text)

func show_end_screen(ending: Dictionary) -> void:
	await _overlays_module.show_end_screen(ending)

func show_journal_popup(run_summaries: Array[Dictionary]) -> void:
	_overlays_module.show_journal_popup(run_summaries)


func show_reaction_text(text: String, outcome: String) -> void:
	_overlays_module.show_reaction_text(text, outcome)

func show_result_text_transition(result_text: String, outcome: String) -> void:
	await _overlays_module.show_result_text_transition(result_text, outcome)

func show_critical_badge() -> void:
	_overlays_module.show_critical_badge()

func show_biome_passive(passive: Dictionary) -> void:
	_overlays_module.show_biome_passive(passive)

func animate_card_outcome(outcome: String) -> void:
	_overlays_module.animate_card_outcome(outcome)

func show_milestone_popup(title_text: String, desc_text: String) -> void:
	_overlays_module.show_milestone_popup(title_text, desc_text)

func show_life_delta(delta: int) -> void:
	_overlays_module.show_life_delta(delta)

func show_progressive_indicators() -> void:
	await _overlays_module.show_progressive_indicators()

# Stubs for methods called by controller but not previously implemented
func show_minigame_result(_score: int, _outcome: String) -> void:
	pass  # Minigame result display handled by minigame scene directly

func show_minigame_score(_score: int) -> void:
	pass  # Score display handled inline

func show_modifier_badge(_modifier_name: String) -> void:
	pass  # Modifier badge — placeholder for future implementation


# ═══════════════════════════════════════════════════════════════════════════════
# INPUT HANDLING
# ═══════════════════════════════════════════════════════════════════════════════

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_run_zones()
		_layout_card_stage()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SFXManager.play("click")
		pause_requested.emit()
		return

	if _narrator_module.is_typewriter_active() and event is InputEventMouseButton and event.pressed:
		_narrator_module.abort_typewriter()

	if _narrator_module.is_waiting_narrator_click() and event is InputEventMouseButton and event.pressed:
		_narrator_module.set_waiting_narrator_click(false)

	if event is InputEventKey and event.pressed:
		if _narrator_module.is_typewriter_active():
			_narrator_module.abort_typewriter()
			return
		if _narrator_module.is_waiting_narrator_click():
			_narrator_module.set_waiting_narrator_click(false)
			return
		match event.keycode:
			KEY_A, KEY_LEFT, KEY_1, KEY_KP_1:
				_options_module.highlight_option(MerlinConstants.CardOption.LEFT)
			KEY_B, KEY_UP, KEY_2, KEY_KP_2:
				_options_module.highlight_option(MerlinConstants.CardOption.CENTER)
			KEY_C, KEY_RIGHT, KEY_3, KEY_KP_3:
				_options_module.highlight_option(MerlinConstants.CardOption.RIGHT)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _options_module.get_highlighted_option() >= 0:
					_options_module.on_option_pressed(_options_module.get_highlighted_option())
			KEY_TAB:
				pass  # Ogham wheel — Phase 7


func _exit_tree() -> void:
	_narrator_module.abort_typewriter()
	_narrator_module.cleanup()
