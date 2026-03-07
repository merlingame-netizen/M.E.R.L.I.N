## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Game UI — Main Gameplay Interface (v0.3.0)
## ═══════════════════════════════════════════════════════════════════════════════
## UI for Merlin Triade system: 3 Aspects, 3 States, 3 Options per card.
## Celtic symbols: Sanglier (Corps), Corbeau (Ame), Cerf (Monde)
## ═══════════════════════════════════════════════════════════════════════════════

extends Control
class_name MerlinGameUI

signal option_chosen(option: int)  # 0=LEFT, 1=CENTER, 2=RIGHT
signal skill_activated(skill_id: String)
signal pause_requested
signal souffle_activated
signal merlin_dialogue_requested(player_input: String)
signal journal_requested

# Explicit preloads — required when scripts created outside editor (UID cache stale)
const PixelSceneCompositor = preload("res://scripts/ui/pixel_scene_compositor.gd")
const PixelSceneData = preload("res://scripts/ui/pixel_scene_data.gd")
const CardSceneCompositorClass = preload("res://scripts/ui/card_scene_compositor.gd")

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

const STATE_LABELS := {
	MerlinConstants.AspectState.BAS: "v",       # Was U+25BC (TextServerFallback incompatible)
	MerlinConstants.AspectState.EQUILIBRE: "=",  # Was U+25CF
	MerlinConstants.AspectState.HAUT: "^",       # Was U+25B2
}

const SOUFFLE_ICON := "*"   # Was U+0DA7 (TextServerFallback incompatible)
const SOUFFLE_EMPTY := "o"  # Was U+25CB

const OPTION_KEYS := {
	MerlinConstants.CardOption.LEFT: "A",
	MerlinConstants.CardOption.CENTER: "B",
	MerlinConstants.CardOption.RIGHT: "C",
}

const INTRO_PIXEL_COLS := 84
const INTRO_PIXEL_ROWS := 48
const INTRO_STACK_BATCH := 26
const INTRO_STACK_STEP := 0.02
const INTRO_DECK_COUNT := 12
const LIVE_DECK_VISIBLE_COUNT := 5
const DISCARD_VISIBLE_COUNT := 5
const RUN_DECK_ESTIMATE := 24
const TOP_ZONE_RATIO := 0.12     # DOC_17 UX: augmenté 0.10→0.12 pour barres vie lisibles
const CARD_ZONE_RATIO := 0.70    # Réduit légèrement pour compenser TOP_ZONE
const BOTTOM_ZONE_RATIO := 0.18
# Use MerlinVisual constants for card animation
# const CARD_FLOAT_OFFSET := MerlinVisual.CARD_FLOAT_OFFSET
# const CARD_FLOAT_DURATION := MerlinVisual.CARD_FLOAT_DURATION
const CARD_PORTRAIT_RATIO := 1.05
const ACTION_VERB_FALLBACK := ["Observer", "Canaliser", "Braver"]
const ACTION_VERBS := [
	"Explorer", "Fuir", "Negocier", "Observer", "Defier", "Invoquer",
	"Traverser", "Accepter", "Refuser", "Proteger", "Attaquer", "Apaiser",
	"Chercher", "Ecouter", "Suivre", "Braver", "Canaliser", "Mediter",
	"Soigner", "Sacrifier", "Marchander", "Implorer", "Confronter",
	"Esquiver", "Sonder", "Conjurer", "Purifier", "Resister",
	"Avancer", "Agir", "Reculer", "Parler", "Ignorer", "Prendre",
	"Toucher", "Ouvrir", "Courir", "Attendre", "Prier", "Ramasser",
	"Contourner", "Plonger", "Grimper", "Frapper", "Appeler",
]

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
@onready var souffle_panel: VBoxContainer = $MainVBox/TopStatusBar/SoufflePanel
@onready var souffle_display: HBoxContainer = $MainVBox/TopStatusBar/SoufflePanel/SouffleIcons
@onready var _souffle_counter: Label = $MainVBox/TopStatusBar/SoufflePanel/SouffleCounter
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

# Dynamic nodes (created in _configure_ui)
var _card_source_badge: PanelContainer
var _scene_compositor: PixelSceneCompositor
var _scene_compositor_v2: Control = null  ## CardSceneCompositor — layered sprite system (feature flag)
var _pixel_portrait: PixelCharacterPortrait
var _npc_portrait: PixelNpcPortrait
var bestiole_wheel: BestioleWheelSystem
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
var aspect_panel: Control
var aspect_displays: Dictionary = {}

# Unused but referenced by update_resource_bar() — kept for interface compat
var _tool_label: Label
var _day_label: Label
var _mission_progress_label: Label

# State (non-scene)
var _current_speaker_key: String = ""
var biome_indicator: Label

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var current_card: Dictionary = {}
var current_aspects: Dictionary = {}
var _previous_aspects: Dictionary = {}
var current_souffle: int = MerlinConstants.SOUFFLE_START
var _previous_souffle: int = -1
var _blip_pool: Array[AudioStreamPlayer] = []
var _blip_idx: int = 0
const BLIP_POOL_SIZE := 4

# Card stacking
var _card_shadows: Array[Panel] = []
const MAX_CARD_SHADOWS := 3

# Ambient VFX
var _ambient_timer: Timer
var _ambient_particles: Array[ColorRect] = []
const MAX_AMBIENT_PARTICLES := 10
var _ambient_biome_key: String = ""
var _opening_sequence_done := false
var _ui_blocks_for_intro: Array[Control] = []
var _biome_art_pixels: Array[ColorRect] = []
var _card_float_tween: Tween
var _card_entry_tween: Tween
var _critical_badge_tween: Tween   ## BUG-04 fix — badge pulse, infinite, killed on next display_card
var _biome_breath_tween: Tween     ## BUG-05 fix — biome breathing loop, killed on re-entry
var _card_base_pos: Vector2 = Vector2.ZERO
var _remaining_deck_cards: Array[Panel] = []
var _remaining_deck_estimate: int = RUN_DECK_ESTIMATE
var _discard_cards: Array[Panel] = []
var _discard_total: int = 0

# Fake 3D card tilt
var _card_hovered := false
var _card_tilt_target: Vector2 = Vector2.ZERO  # x=horizontal tilt, y=vertical tilt (-1..1)
var _card_tilt_current: Vector2 = Vector2.ZERO
var _card_3d_shine: ColorRect  # Subtle highlight overlay for 3D effect
var _card_3d_active := false   # Only tilt when card is displayed and idle

# Life essence — 10 barres pixelisées de 10 PV chacune (DOC_17)
var _life_segment_bars: Array = []    # Array[ProgressBar], créés dynamiquement

# Souffle d'Ogham button (bottom-right)
var _souffle_btn: Button
var _souffle_active := false
var _perk_badge: Label = null  # B.1 — shows selected perk name near Souffle button

# Bestiole companion (bottom-left, permanent)
var _bestiole_mini: Label
var _bestiole_emote: Label

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_configure_ui()
	_init_blip_pool()
	_update_souffle(MerlinConstants.SOUFFLE_START)
	update_life_essence(MerlinConstants.LIFE_ESSENCE_START)
	update_essences_collected(0)
	reset_run_visuals()


func _process(delta: float) -> void:
	_update_card_3d_tilt(delta)


func _init_blip_pool() -> void:
	## Pre-create a pool of AudioStreamPlayers to avoid per-character allocation.
	for i in range(BLIP_POOL_SIZE):
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.02
		var player := AudioStreamPlayer.new()
		player.stream = gen
		player.volume_db = linear_to_db(0.04)
		add_child(player)
		_blip_pool.append(player)


var title_font: Font
var body_font: Font
var _active_biome_visual: String = "broceliande"
var _active_season_visual: String = "automne"
var _active_hour_visual: int = -1


func _configure_ui() -> void:
	## Apply runtime styling and create dynamic nodes. Structure is in MerlinGameUI.tscn.
	# Fonts
	title_font = MerlinVisual.get_font("title")
	body_font = MerlinVisual.get_font("body")
	if body_font == null:
		body_font = title_font

	# Fond transparent — la forêt Brocéliande est le fond visuel principal
	parchment_bg.material = null
	parchment_bg.color = Color(0.0, 0.0, 0.0, 0.0)  # Transparent — forêt visible derrière

	# UIBackdrop : supprimé — les panels UI ont leur propre fond opaque (bg_deep)
	# La lisibilité est assurée par les StyleBoxFlat des cartes et boutons, pas par un overlay global

	# Life bar theming
	_life_bar.max_value = MerlinConstants.LIFE_ESSENCE_MAX
	_life_bar.value = MerlinConstants.LIFE_ESSENCE_START
	MerlinVisual.apply_bar_theme(_life_bar, "danger")
	# 10 barres pixelisées de 10 PV (DOC_17 — remplace la barre unique visuellement)
	_life_bar.visible = false  # Cachée — remplacée par les segments
	_life_segment_bars.clear()
	var seg_hbox := HBoxContainer.new()
	seg_hbox.name = "LifeSegmentsHBox"
	seg_hbox.add_theme_constant_override("separation", 3)
	life_panel.add_child(seg_hbox)
	for _i in range(MerlinConstants.LIFE_BAR_SEGMENTS):
		var seg := ProgressBar.new()
		seg.max_value = 10
		seg.value = 10
		seg.show_percentage = false
		seg.custom_minimum_size = Vector2(20, 14)  # DOC_17 UX: 20×14px lisibles
		MerlinVisual.apply_bar_theme(seg, "danger")
		seg_hbox.add_child(seg)
		_life_segment_bars.append(seg)

	# Clock panel styling
	_status_clock_panel.add_theme_stylebox_override("panel", MerlinVisual.make_clock_panel_style())
	_status_clock_timer.timeout.connect(_update_clock_status)
	_update_clock_status()

	# Card panel styling
	card_panel.add_theme_stylebox_override("panel", MerlinVisual.make_card_panel_style())
	card_panel.pivot_offset = Vector2(320, 200)
	card_panel.clip_contents = true
	_setup_card_3d()
	if card_container and is_instance_valid(card_container):
		card_container.clip_contents = true
	_card_illustration_panel.add_theme_stylebox_override("panel", MerlinVisual.make_card_illustration_style())
	_card_body_panel.add_theme_stylebox_override("panel", MerlinVisual.make_card_body_style())
	var ink_bg: Color = MerlinVisual.CRT_PALETTE.phosphor
	_illo_bg.color = Color(ink_bg.r, ink_bg.g, ink_bg.b, 0.95)

	# Dynamic nodes: scene compositor + portrait
	if MerlinVisual.USE_LAYERED_SPRITES:
		_scene_compositor_v2 = CardSceneCompositorClass.new()
		_scene_compositor_v2.name = "LayeredCompositor"
		_scene_compositor_v2.setup(MerlinVisual.LAYER_ILLUSTRATION_SIZE)
		_tile_center.add_child(_scene_compositor_v2)
	else:
		_scene_compositor = PixelSceneCompositor.new()
		_scene_compositor.name = "SceneCompositor"
		_scene_compositor.setup(220.0)
		_tile_center.add_child(_scene_compositor)

	# Portraits supprimés — libère l'espace card pour le texte
	_pixel_portrait = null
	_npc_portrait = null
	if _portrait_center and is_instance_valid(_portrait_center):
		_portrait_center.visible = false

	# LLM source badge
	_card_source_badge = LLMSourceBadge.create("static")
	_card_source_badge.visible = false
	_card_body_vbox.add_child(_card_source_badge)

	# Option buttons — collect refs + wire signals
	option_buttons = [_btn_a, _btn_b, _btn_c]
	var option_configs := [
		{"key": "A", "color": MerlinVisual.ASPECT_COLORS["Monde"]},
		{"key": "B", "color": MerlinVisual.CRT_PALETTE.amber},
		{"key": "C", "color": MerlinVisual.ASPECT_COLORS["Corps"]},
	]
	for i in range(3):
		var btn: Button = option_buttons[i]
		MerlinVisual.apply_celtic_option_theme(btn, option_configs[i]["color"])
		btn.pressed.connect(_on_option_pressed.bind(i))
		btn.mouse_entered.connect(_on_option_hover_enter.bind(i))
		btn.mouse_exited.connect(_on_option_hover_exit)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.get_parent().mouse_filter = Control.MOUSE_FILTER_PASS
		# Boutons occupent toute la largeur disponible, hauteur minimum garantie
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 80)  # DOC_17 UX: 72→80px, mieux lisible mobile
		btn.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# OptionsBar : expansion horizontale + séparation lisible
	if options_container and is_instance_valid(options_container):
		options_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options_container.add_theme_constant_override("separation", 10)  # 14→10px, espace gagné

	# Ensure parent containers don't block mouse events on buttons
	if _bottom_zone and is_instance_valid(_bottom_zone):
		_bottom_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	if options_container and is_instance_valid(options_container):
		options_container.mouse_filter = Control.MOUSE_FILTER_PASS

	# Action description labels — ABOVE each option button (shown on hover)
	var desc_color: Color = MerlinVisual.CRT_PALETTE.get("phosphor", Color(0.20, 1.00, 0.40))
	_option_desc_labels.clear()
	for i2 in range(3):
		var desc_lbl := Label.new()
		desc_lbl.name = "DescLabel%s" % ["A", "B", "C"][i2]
		if body_font:
			desc_lbl.add_theme_font_override("font", body_font)
		desc_lbl.add_theme_font_size_override("font_size", 11)  # 10→11pt, + lisible
		desc_lbl.add_theme_color_override("font_color", desc_color)  # phosphor_dim→phosphor
		desc_lbl.custom_minimum_size = Vector2(0, 18)
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_lbl.visible = false
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var parent_vbox: Control = option_buttons[i2].get_parent()
		parent_vbox.add_child(desc_lbl)
		parent_vbox.move_child(desc_lbl, 0)  # Move BEFORE the button
		_option_desc_labels.append(desc_lbl)

	# What-if labels — shown AFTER choice on unchosen options (P3.17.4)
	var whatif_color: Color = MerlinVisual.CRT_PALETTE.get("phosphor_dim", Color(0.45, 0.4, 0.35))
	_what_if_labels.clear()
	for i3 in range(3):
		var wif_lbl := Label.new()
		wif_lbl.name = "WhatIfLabel%s" % ["A", "B", "C"][i3]
		if body_font:
			wif_lbl.add_theme_font_override("font", body_font)
		wif_lbl.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_TINY)
		wif_lbl.add_theme_color_override("font_color", whatif_color)
		wif_lbl.custom_minimum_size = Vector2(0, 0)
		wif_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wif_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		wif_lbl.visible = false
		wif_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var wif_parent: Control = option_buttons[i3].get_parent()
		wif_parent.add_child(wif_lbl)  # After the button
		_what_if_labels.append(wif_lbl)

	# Minigame badge — displayed below card text when a minigame is detected
	_minigame_badge = Label.new()
	_minigame_badge.name = "MinigameBadge"
	if body_font:
		_minigame_badge.add_theme_font_override("font", body_font)
	_minigame_badge.add_theme_font_size_override("font_size", 11)
	_minigame_badge.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_bright)
	_minigame_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minigame_badge.visible = false
	_card_body_vbox.add_child(_minigame_badge)

	# Reward badge (floating overlay)
	_reward_badge = MerlinRewardBadge.new()
	add_child(_reward_badge)

	# Souffle d'Ogham button (bottom-right, dedicated activation)
	_souffle_btn = Button.new()
	_souffle_btn.name = "SouffleBtn"
	_souffle_btn.text = SOUFFLE_ICON
	_souffle_btn.custom_minimum_size = Vector2(56, 56)
	_souffle_btn.tooltip_text = "Souffle d'Ogham: bonus au prochain jet (usage unique)"
	MerlinVisual.apply_celtic_option_theme(_souffle_btn, MerlinVisual.CRT_PALETTE.souffle)
	_souffle_btn.z_index = 20
	_souffle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_souffle_btn.pressed.connect(_on_souffle_btn_pressed)
	_souffle_btn.mouse_entered.connect(func(): SFXManager.play("hover"))
	add_child(_souffle_btn)
	_souffle_btn.visible = false  # Retiré de l'UI — pas de bouton souffle en bas à droite
	_update_souffle_btn_state()

	# B.1 — Perk badge: shows selected perk name above Souffle button
	_perk_badge = Label.new()
	_perk_badge.name = "PerkBadge"
	_perk_badge.text = ""
	_perk_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_perk_badge.add_theme_font_size_override("font_size", 9)
	_perk_badge.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_bright)
	_perk_badge.visible = false
	_perk_badge.z_index = 20
	add_child(_perk_badge)

	# "Talk to Merlin" button (bottom-right, above Souffle)
	_dialogue_btn = Button.new()
	_dialogue_btn.name = "DialogueBtn"
	_dialogue_btn.text = "Parler"
	_dialogue_btn.custom_minimum_size = Vector2(72, 36)
	_dialogue_btn.tooltip_text = "Parler a Merlin"
	MerlinVisual.apply_celtic_option_theme(_dialogue_btn, MerlinVisual.CRT_PALETTE.get("amber_bright", Color(0.85, 0.65, 0.13)))
	_dialogue_btn.z_index = 20
	_dialogue_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_btn.pressed.connect(_on_dialogue_btn_pressed)
	_dialogue_btn.mouse_entered.connect(func(): SFXManager.play("hover"))
	add_child(_dialogue_btn)
	_dialogue_btn.visible = false  # Retiré de l'UI — pas de bouton dialogue en bas à droite

	# Merlin response bubble (reusable)
	_dialogue_bubble = MerlinBubble.new()
	_dialogue_bubble.name = "DialogueBubble"
	_dialogue_bubble.z_index = 25
	add_child(_dialogue_bubble)

	# Bestiole wheel: lazy-loaded on Tab press (no permanent button to avoid duplication with SouffleBtn)
	# bestiole_wheel variable stays null until Tab is pressed — see _input()

	# Bestiole companion mini (bottom-left, permanent)
	_bestiole_mini = Label.new()
	_bestiole_mini.name = "BestioleMini"
	_bestiole_mini.text = "~(o.o)~"
	if body_font:
		_bestiole_mini.add_theme_font_override("font", body_font)
	_bestiole_mini.add_theme_font_size_override("font_size", 18)
	var bestiole_col: Color = MerlinVisual.CRT_PALETTE.get("bestiole", Color(0.6, 0.8, 0.5))
	_bestiole_mini.add_theme_color_override("font_color", bestiole_col)
	_bestiole_mini.position = Vector2(16, get_viewport_rect().size.y - 64)
	_bestiole_mini.z_index = 15
	add_child(_bestiole_mini)

	_bestiole_emote = Label.new()
	_bestiole_emote.name = "BestioleEmote"
	_bestiole_emote.text = ""
	if body_font:
		_bestiole_emote.add_theme_font_override("font", body_font)
	_bestiole_emote.add_theme_font_size_override("font_size", 14)
	_bestiole_emote.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.get("amber_bright", Color(0.85, 0.65, 0.13)))
	_bestiole_emote.position = Vector2(16, get_viewport_rect().size.y - 82)
	_bestiole_emote.z_index = 16
	_bestiole_emote.modulate.a = 0.0
	add_child(_bestiole_emote)

	# Biome indicator (orphan label, not in tree)
	biome_indicator = Label.new()
	biome_indicator.visible = false

	# Apply font/color theming to scene labels
	_apply_label_theming()

	# Dynamic deck stacks + layout
	_build_remaining_deck_stack()
	_build_discard_stack()
	_ui_blocks_for_intro = [_top_status_bar, options_container, _pioche_column, _cimetiere_column]
	_layout_run_zones()
	call_deferred("_layout_card_stage")


func _apply_label_theming() -> void:
	## Apply MerlinVisual fonts and colors to scene labels.
	# Titres TopStatusBar — masqués (redondants avec les barres visuelles, gagnent de l'espace)
	for lbl: Label in [
		$MainVBox/TopStatusBar/LifePanel/LifeTitle,
		$MainVBox/TopStatusBar/SoufflePanel/SouffleTitle,
		$MainVBox/TopStatusBar/EssencePanel/EssenceTitle,
	]:
		lbl.visible = false  # DOC_17 UX review: labels redondants masqués

	# Life counter — 16pt (dominant, Vie est la ressource principale)
	_life_counter.text = "%d/%d" % [MerlinConstants.LIFE_ESSENCE_START, MerlinConstants.LIFE_ESSENCE_MAX]
	if body_font:
		_life_counter.add_theme_font_override("font", body_font)
	_life_counter.add_theme_font_size_override("font_size", 16)
	_life_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)

	# Souffle counter — masqué, le logo seul suffit (SOUFFLE_MAX=1, usage unique)
	_souffle_counter.visible = false

	# Souffle icons — MerlinGameUI.tscn contient 7 Labels (Icon0-Icon6) mais SOUFFLE_MAX=1.
	# Masquer les Labels 1-6 supplémentaires pour n'afficher qu'un seul logo.
	if souffle_display and is_instance_valid(souffle_display):
		var n: int = souffle_display.get_child_count()
		for i: int in range(1, n):
			var extra: Control = souffle_display.get_child(i) as Control
			if extra and is_instance_valid(extra):
				extra.visible = false

	# Essence counter — 16pt (réduit, Essences secondaires vs Vie)
	if body_font:
		_essence_counter.add_theme_font_override("font", body_font)
	_essence_counter.add_theme_font_size_override("font_size", 16)
	_essence_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_bright)

	# Essence caption
	var caption: Label = $MainVBox/TopStatusBar/EssencePanel/EssenceCaption
	if body_font:
		caption.add_theme_font_override("font", body_font)
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)

	# Clock label
	_status_clock_label.add_theme_font_size_override("font_size", 15)
	_status_clock_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	if body_font:
		_status_clock_label.add_theme_font_override("font", body_font)

	# Pioche + Cimetiere titles
	for lbl: Label in [
		$MainVBox/MiddleZone/PiocheColumn/PiocheTitle,
		$MainVBox/MiddleZone/CimetiereColumn/CimetiereTitle,
	]:
		if title_font:
			lbl.add_theme_font_override("font", title_font)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)

	# Deck + discard count labels
	for lbl: Label in [_remaining_deck_label, _discard_label]:
		if body_font:
			lbl.add_theme_font_override("font", body_font)
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)

	# Card title (poetic, generated by GM brain — P3.17.2)
	_card_title_label = Label.new()
	_card_title_label.name = "CardTitle"
	_card_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if title_font:
		_card_title_label.add_theme_font_override("font", title_font)
	_card_title_label.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_LARGE)
	_card_title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	_card_title_label.visible = false
	if _card_body_vbox and is_instance_valid(_card_body_vbox):
		_card_body_vbox.add_child(_card_title_label)
		_card_body_vbox.move_child(_card_title_label, 0)  # Before CardSpeaker

	# Card speaker
	if title_font:
		card_speaker.add_theme_font_override("font", title_font)
	card_speaker.add_theme_font_size_override("font_size", 17)
	card_speaker.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)

	# Card text
	if body_font:
		card_text.add_theme_font_override("normal_font", body_font)
	card_text.add_theme_font_size_override("normal_font_size", 15)
	card_text.add_theme_color_override("default_color", MerlinVisual.CRT_PALETTE.phosphor)
	card_text.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Option buttons font
	for btn: Button in option_buttons:
		if title_font:
			btn.add_theme_font_override("font", title_font)
		btn.add_theme_font_size_override("font_size", 17)

	# Info panel labels
	for lbl: Label in [mission_label, cards_label]:
		if body_font:
			lbl.add_theme_font_override("font", body_font)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)

func _update_clock_status() -> void:
	if not _status_clock_label or not is_instance_valid(_status_clock_label):
		return
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var hour := int(now.get("hour", 0))
	var minute := int(now.get("minute", 0))
	_status_clock_label.text = "%02d:%02d" % [hour, minute]


func _draw_animal(ctrl: Control, animal: String, color: Color) -> void:
	## Draw Celtic-style animal silhouettes using vector shapes.
	var sz := ctrl.size
	var cx := sz.x * 0.5
	var cy := sz.y * 0.5
	var r := mini(int(sz.x), int(sz.y)) * 0.4

	match animal:
		"sanglier":  # Boar — Corps (strength)
			_draw_sanglier(ctrl, cx, cy, r, color)
		"corbeau":  # Raven — Ame (spirit)
			_draw_corbeau(ctrl, cx, cy, r, color)
		"cerf":  # Stag — Monde (world)
			_draw_cerf(ctrl, cx, cy, r, color)
		_:
			# Fallback: Celtic spiral
			ctrl.draw_arc(Vector2(cx, cy), r, 0.0, TAU, 24, color, 2.0)


func _draw_sanglier(ctrl: Control, cx: float, cy: float, r: float, color: Color) -> void:
	## Sanglier (boar) — stocky body with tusks, Celtic knotwork style.
	var body := PackedVector2Array()
	# Body shape (rounded rectangle-ish)
	body.append(Vector2(cx - r * 0.9, cy + r * 0.2))
	body.append(Vector2(cx - r * 0.7, cy - r * 0.5))
	body.append(Vector2(cx - r * 0.2, cy - r * 0.7))
	body.append(Vector2(cx + r * 0.3, cy - r * 0.6))
	body.append(Vector2(cx + r * 0.8, cy - r * 0.3))
	body.append(Vector2(cx + r * 1.0, cy + r * 0.1))
	body.append(Vector2(cx + r * 0.8, cy + r * 0.5))
	body.append(Vector2(cx + r * 0.3, cy + r * 0.7))
	body.append(Vector2(cx - r * 0.4, cy + r * 0.6))
	body.append(Vector2(cx - r * 0.9, cy + r * 0.2))
	ctrl.draw_polyline(body, color, 2.0, true)
	# Tusks
	ctrl.draw_line(Vector2(cx + r * 0.85, cy - r * 0.1), Vector2(cx + r * 1.1, cy - r * 0.5), color, 2.0)
	ctrl.draw_line(Vector2(cx + r * 0.85, cy + r * 0.0), Vector2(cx + r * 1.1, cy + r * 0.1), color, 1.5)
	# Eye
	ctrl.draw_circle(Vector2(cx + r * 0.5, cy - r * 0.2), r * 0.12, color)
	# Legs (front + back)
	ctrl.draw_line(Vector2(cx - r * 0.5, cy + r * 0.6), Vector2(cx - r * 0.5, cy + r * 1.0), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.4, cy + r * 0.65), Vector2(cx + r * 0.4, cy + r * 1.0), color, 1.5)


func _draw_corbeau(ctrl: Control, cx: float, cy: float, r: float, color: Color) -> void:
	## Corbeau (raven) — wings spread, Celtic knot-style.
	# Body
	var body := PackedVector2Array()
	body.append(Vector2(cx + r * 0.8, cy + r * 0.1))
	body.append(Vector2(cx + r * 0.5, cy - r * 0.3))
	body.append(Vector2(cx + r * 0.1, cy - r * 0.2))
	body.append(Vector2(cx - r * 0.3, cy + r * 0.1))
	body.append(Vector2(cx - r * 0.5, cy + r * 0.4))
	body.append(Vector2(cx + r * 0.2, cy + r * 0.5))
	body.append(Vector2(cx + r * 0.8, cy + r * 0.1))
	ctrl.draw_polyline(body, color, 2.0, true)
	# Beak
	ctrl.draw_line(Vector2(cx + r * 0.8, cy + r * 0.1), Vector2(cx + r * 1.2, cy - r * 0.05), color, 2.0)
	ctrl.draw_line(Vector2(cx + r * 1.2, cy - r * 0.05), Vector2(cx + r * 0.8, cy + r * 0.2), color, 1.5)
	# Eye
	ctrl.draw_circle(Vector2(cx + r * 0.55, cy - r * 0.1), r * 0.1, color)
	# Left wing (spread)
	var wing := PackedVector2Array()
	wing.append(Vector2(cx - r * 0.1, cy - r * 0.1))
	wing.append(Vector2(cx - r * 0.7, cy - r * 0.8))
	wing.append(Vector2(cx - r * 1.0, cy - r * 0.5))
	wing.append(Vector2(cx - r * 0.8, cy - r * 0.2))
	wing.append(Vector2(cx - r * 0.3, cy + r * 0.1))
	ctrl.draw_polyline(wing, color, 1.5, true)
	# Tail feathers
	ctrl.draw_line(Vector2(cx - r * 0.5, cy + r * 0.4), Vector2(cx - r * 0.9, cy + r * 0.7), color, 1.5)
	ctrl.draw_line(Vector2(cx - r * 0.5, cy + r * 0.4), Vector2(cx - r * 0.7, cy + r * 0.8), color, 1.5)


func _draw_cerf(ctrl: Control, cx: float, cy: float, r: float, color: Color) -> void:
	## Cerf (stag) — proud head with antlers, Celtic knotwork style.
	# Head
	var head := PackedVector2Array()
	head.append(Vector2(cx, cy + r * 0.8))
	head.append(Vector2(cx - r * 0.3, cy + r * 0.3))
	head.append(Vector2(cx - r * 0.25, cy - r * 0.2))
	head.append(Vector2(cx, cy - r * 0.4))
	head.append(Vector2(cx + r * 0.25, cy - r * 0.2))
	head.append(Vector2(cx + r * 0.3, cy + r * 0.3))
	head.append(Vector2(cx, cy + r * 0.8))
	ctrl.draw_polyline(head, color, 2.0, true)
	# Eye
	ctrl.draw_circle(Vector2(cx, cy), r * 0.1, color)
	# Left antler (branching)
	ctrl.draw_line(Vector2(cx - r * 0.25, cy - r * 0.2), Vector2(cx - r * 0.6, cy - r * 0.8), color, 1.5)
	ctrl.draw_line(Vector2(cx - r * 0.4, cy - r * 0.5), Vector2(cx - r * 0.8, cy - r * 0.6), color, 1.5)
	ctrl.draw_line(Vector2(cx - r * 0.55, cy - r * 0.7), Vector2(cx - r * 0.9, cy - r * 0.9), color, 1.5)
	# Right antler (mirrored)
	ctrl.draw_line(Vector2(cx + r * 0.25, cy - r * 0.2), Vector2(cx + r * 0.6, cy - r * 0.8), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.4, cy - r * 0.5), Vector2(cx + r * 0.8, cy - r * 0.6), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.55, cy - r * 0.7), Vector2(cx + r * 0.9, cy - r * 0.9), color, 1.5)
	# Ears
	ctrl.draw_line(Vector2(cx - r * 0.2, cy - r * 0.3), Vector2(cx - r * 0.35, cy - r * 0.45), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.2, cy - r * 0.3), Vector2(cx + r * 0.35, cy - r * 0.45), color, 1.5)


func _build_remaining_deck_stack() -> void:
	if not _remaining_deck_root or not is_instance_valid(_remaining_deck_root):
		return
	for child in _remaining_deck_root.get_children():
		child.queue_free()
	_remaining_deck_cards.clear()

	for i in range(LIVE_DECK_VISIBLE_COUNT):
		var deck_card := Panel.new()
		deck_card.size = Vector2(78, 106)
		deck_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deck_card.modulate.a = 0.95 - float(i) * 0.1
		deck_card.pivot_offset = deck_card.size * 0.5
		var deck_style := StyleBoxFlat.new()
		var ink_deck: Color = MerlinVisual.CRT_PALETTE.phosphor
		deck_style.bg_color = Color(ink_deck.r, ink_deck.g, ink_deck.b, 0.96)
		var bestiole: Color = MerlinVisual.CRT_PALETTE.bestiole
		deck_style.border_color = Color(bestiole.r, bestiole.g, bestiole.b, 0.72)
		deck_style.set_border_width_all(2)
		deck_style.set_corner_radius_all(7)
		deck_style.shadow_color = Color(0, 0, 0, 0.3)
		deck_style.shadow_size = 6
		deck_style.shadow_offset = Vector2(0, 2)
		deck_card.add_theme_stylebox_override("panel", deck_style)
		_remaining_deck_root.add_child(deck_card)
		_remaining_deck_cards.append(deck_card)

	_update_remaining_deck_visual()


func _update_remaining_deck_visual() -> void:
	if _remaining_deck_cards.is_empty():
		return
	var visible_count := clampi(_remaining_deck_estimate, 0, LIVE_DECK_VISIBLE_COUNT)
	for i in range(_remaining_deck_cards.size()):
		var card := _remaining_deck_cards[i]
		if not card or not is_instance_valid(card):
			continue
		card.position = Vector2(12.0 + float(i) * 2.0, 10.0 + float(i) * 3.0)
		card.rotation_degrees = -2.0 + float(i) * 1.2
		card.scale = Vector2(1.0, 1.0)
		card.modulate.a = clampf(0.92 - float(i) * 0.12, 0.18, 1.0) if i < visible_count else 0.0

	if _remaining_deck_label and is_instance_valid(_remaining_deck_label):
		_remaining_deck_label.text = "%d" % maxi(_remaining_deck_estimate, 0)


func _build_discard_stack() -> void:
	if not _discard_root or not is_instance_valid(_discard_root):
		return
	for child in _discard_root.get_children():
		child.queue_free()
	_discard_cards.clear()

	for i in range(DISCARD_VISIBLE_COUNT):
		var discard_card := Panel.new()
		discard_card.size = Vector2(62, 86)
		discard_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		discard_card.pivot_offset = discard_card.size * 0.5
		discard_card.add_theme_stylebox_override("panel", MerlinVisual.make_discard_card_style())
		_discard_root.add_child(discard_card)
		_discard_cards.append(discard_card)

	_update_discard_visual()


func _update_discard_visual() -> void:
	if _discard_cards.is_empty():
		return
	var visible_count := clampi(_discard_total, 0, DISCARD_VISIBLE_COUNT)
	for i in range(_discard_cards.size()):
		var card := _discard_cards[i]
		if not card or not is_instance_valid(card):
			continue
		card.position = Vector2(10.0 + float(i) * 2.0, 8.0 + float(i) * 3.0)
		card.rotation_degrees = 1.8 + float(i) * 1.0
		card.modulate.a = clampf(0.86 - float(i) * 0.14, 0.18, 1.0) if i < visible_count else 0.08
	if _discard_label and is_instance_valid(_discard_label):
		_discard_label.text = "%d" % maxi(_discard_total, 0)


func reset_run_visuals() -> void:
	_remaining_deck_estimate = RUN_DECK_ESTIMATE
	_discard_total = 0
	_update_remaining_deck_visual()
	_update_discard_visual()


func mark_card_completed() -> void:
	if current_card.is_empty():
		return
	if bool(current_card.get("_placeholder", false)):
		return
	_discard_total += 1
	_update_discard_visual()
	# Animate card dissolving into pixels — dramatic exit
	if card_panel and is_instance_valid(card_panel):
		if _card_float_tween:
			_card_float_tween.kill()
		_disable_card_3d()
		card_panel.scale = Vector2.ONE
		card_panel.rotation_degrees = 0.0
		# Pixel dissolve: blocks scatter upward from the card
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


func _layout_run_zones() -> void:
	var vp_size := get_viewport_rect().size
	if vp_size.y <= 0.0:
		return
	var top_h := maxf(52.0, vp_size.y * TOP_ZONE_RATIO)
	var middle_h := maxf(260.0, vp_size.y * CARD_ZONE_RATIO)
	var bottom_h := maxf(180.0, vp_size.y * BOTTOM_ZONE_RATIO)
	var total := top_h + middle_h + bottom_h
	if total > vp_size.y:
		var overflow := total - vp_size.y
		middle_h = maxf(220.0, middle_h - overflow)

	if _top_status_bar and is_instance_valid(_top_status_bar):
		_top_status_bar.custom_minimum_size = Vector2(0.0, top_h)
	if _middle_zone and is_instance_valid(_middle_zone):
		_middle_zone.custom_minimum_size = Vector2(0.0, middle_h)
	if _bottom_zone and is_instance_valid(_bottom_zone):
		_bottom_zone.custom_minimum_size = Vector2(0.0, bottom_h)

	# Position Souffle button bottom-right
	if _souffle_btn and is_instance_valid(_souffle_btn):
		_souffle_btn.position = Vector2(vp_size.x - 68.0, vp_size.y - 68.0)

	# B.1 — Position perk badge above Souffle button
	if _perk_badge and is_instance_valid(_perk_badge):
		_perk_badge.position = Vector2(vp_size.x - 76.0, vp_size.y - 84.0)
		_perk_badge.custom_minimum_size = Vector2(72.0, 14.0)

	# Position Dialogue button above Souffle
	if _dialogue_btn and is_instance_valid(_dialogue_btn):
		_dialogue_btn.position = Vector2(vp_size.x - 84.0, vp_size.y - 112.0)


func _layout_card_stage() -> void:
	if not card_container or not is_instance_valid(card_container):
		return
	var stage_size := card_container.size
	if stage_size.x <= 40.0 or stage_size.y <= 40.0:
		stage_size = get_viewport_rect().size
		# Use card zone height (70% viewport) instead of full viewport for Y centering
		if card_container.custom_minimum_size.y > 0.0:
			stage_size.y = card_container.custom_minimum_size.y

	var target_h := clampf(stage_size.y - 12.0, 260.0, stage_size.y - 12.0)
	var max_w := minf(stage_size.x * 0.88, 960.0)
	var target_w := clampf(target_h * CARD_PORTRAIT_RATIO, 220.0, max_w)
	var target_size := Vector2(target_w, target_h)
	card_panel.size = target_size
	card_panel.custom_minimum_size = target_size
	var centered_y := (stage_size.y - target_size.y) * 0.50
	var max_y := maxf(6.0, stage_size.y - target_size.y - 6.0)
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
	_update_remaining_deck_visual()
	_update_discard_visual()


func _get_deck_draw_origin() -> Vector2:
	if not _remaining_deck_root or not is_instance_valid(_remaining_deck_root):
		return _card_base_pos + Vector2(200.0, 40.0)
	var source_global := _remaining_deck_root.global_position
	var local_in_card := card_container.get_global_transform().affine_inverse() * (source_global + Vector2(18.0, 16.0))
	return local_in_card


func _animate_remaining_deck_draw() -> void:
	## Mise à jour visuelle du deck seulement — ghost panel supprimé (2026-02-26).
	## La carte se matérialise en pixels via PixelContentAnimator dans display_card().
	if _remaining_deck_cards.is_empty():
		return
	var top_card: Panel = _remaining_deck_cards.pop_front()
	if not top_card or not is_instance_valid(top_card):
		return
	_remaining_deck_cards.append(top_card)
	_update_remaining_deck_visual()


func _start_card_float_motion() -> void:
	if not card_panel or not is_instance_valid(card_panel):
		return
	if _card_float_tween:
		_card_float_tween.kill()
	# Only reset position (rotation/scale managed by 3D tilt when active)
	card_panel.position = _card_base_pos
	_card_float_tween = create_tween().set_loops()
	_card_float_tween.tween_property(card_panel, "position:y", _card_base_pos.y - MerlinVisual.CARD_FLOAT_OFFSET, MerlinVisual.CARD_FLOAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_card_float_tween.tween_property(card_panel, "position:y", _card_base_pos.y + MerlinVisual.CARD_FLOAT_OFFSET * 0.6, MerlinVisual.CARD_FLOAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_card_float_and_3d() -> void:
	## Start idle float + enable fake 3D tilt. Called after card entry settles.
	_start_card_float_motion()
	_enable_card_3d()


func _card_panel_safe_reset_transform() -> void:
	if not card_panel or not is_instance_valid(card_panel):
		return
	_disable_card_3d()
	card_panel.scale = Vector2.ONE
	card_panel.rotation_degrees = 0.0
	card_panel.position = _card_base_pos


func _on_option_hover_enter(option_index: int) -> void:
	SFXManager.play("hover")
	if current_card.is_empty():
		return
	var options: Array = current_card.get("options", [])
	if option_index >= options.size():
		return
	var option: Dictionary = options[option_index] if options[option_index] is Dictionary else {}
	var btn: Button = option_buttons[option_index] if option_index < option_buttons.size() else null
	if _reward_badge and is_instance_valid(_reward_badge) and btn and is_instance_valid(btn):
		_reward_badge.show_for_option(option, btn)

	# Hover scale-up (amplified)
	if btn and is_instance_valid(btn):
		btn.pivot_offset = btn.size / 2.0
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.07, 1.07), 0.18)

	# Show action description below hovered button
	for k in range(_option_desc_labels.size()):
		if k < _option_desc_labels.size() and is_instance_valid(_option_desc_labels[k]):
			var show_it: bool = k == option_index and not _option_desc_labels[k].text.is_empty()
			_option_desc_labels[k].visible = show_it
			if show_it:
				_option_desc_labels[k].modulate.a = 0.0
				var desc_tw := create_tween()
				desc_tw.tween_property(_option_desc_labels[k], "modulate:a", 1.0, 0.15)


func _on_option_hover_exit() -> void:
	if _reward_badge and is_instance_valid(_reward_badge):
		_reward_badge.hide_badge()
	# Reset button scales and hide desc labels
	for ob in option_buttons:
		if is_instance_valid(ob):
			ob.scale = Vector2.ONE
	for dl in _option_desc_labels:
		if is_instance_valid(dl):
			dl.visible = false


# ═══════════════════════════════════════════════════════════════════════════════
# FAKE 3D CARD TILT — Perspective effect on mouse hover
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_card_3d() -> void:
	## Setup fake 3D tilt. Hover detected via card_container rect (not card_panel signals)
	## to avoid blocking mouse events on buttons below the card.
	if not card_panel or not is_instance_valid(card_panel):
		return
	# CRITICAL: MOUSE_FILTER_IGNORE prevents card from intercepting clicks on buttons
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Shine overlay (subtle highlight that shifts with tilt)
	_card_3d_shine = ColorRect.new()
	_card_3d_shine.name = "Card3DShine"
	_card_3d_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_3d_shine.color = Color(1.0, 1.0, 1.0, 0.0)
	_card_3d_shine.z_index = 6
	_card_3d_shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_panel.add_child(_card_3d_shine)


func _update_card_3d_tilt(delta: float) -> void:
	## Interpolate card rotation + scale for fake 3D perspective. Called every frame.
	## Hover is detected via card_container rect (not card_panel signals) to avoid
	## blocking mouse events on option buttons below.
	if not card_panel or not is_instance_valid(card_panel):
		return
	if not _card_3d_active:
		# Smoothly return to neutral when not active
		if _card_tilt_current.length() > 0.001:
			_card_tilt_current = _card_tilt_current.lerp(Vector2.ZERO, delta * MerlinVisual.CARD_3D_TILT_SPEED)
			_apply_card_3d_transform()
		return

	# Detect hover via card_container rect (not card_panel mouse signals)
	var is_hovering := false
	if card_container and is_instance_valid(card_container):
		var mouse_global := get_global_mouse_position()
		is_hovering = card_container.get_global_rect().has_point(mouse_global)
	_card_hovered = is_hovering

	# Compute tilt target from mouse position relative to card center
	if _card_hovered:
		var mouse_pos := card_panel.get_local_mouse_position()
		var card_size := card_panel.size
		if card_size.x > 10.0 and card_size.y > 10.0:
			var normalized := Vector2(
				clampf((mouse_pos.x / card_size.x - 0.5) * 2.0, -1.0, 1.0),
				clampf((mouse_pos.y / card_size.y - 0.5) * 2.0, -1.0, 1.0)
			)
			_card_tilt_target = normalized
	else:
		_card_tilt_target = Vector2.ZERO

	# Smooth interpolation
	_card_tilt_current = _card_tilt_current.lerp(_card_tilt_target, delta * MerlinVisual.CARD_3D_TILT_SPEED)
	_apply_card_3d_transform()


func _apply_card_3d_transform() -> void:
	## Apply rotation + scale + parallax + shine based on current tilt values.
	## Creates a convincing fake 3D perspective effect on a 2D card.
	if not card_panel or not is_instance_valid(card_panel):
		return
	var tilt := _card_tilt_current
	# Rotation: horizontal mouse offset tilts card left/right
	var rotation_deg: float = tilt.x * MerlinVisual.CARD_3D_TILT_MAX
	card_panel.rotation_degrees = rotation_deg

	# Scale: enlargement when hovered + slight asymmetry from vertical tilt
	var hover_factor: float = clampf(tilt.length(), 0.0, 1.0)
	var base_scale: float = lerpf(1.0, MerlinVisual.CARD_3D_SCALE_HOVER, hover_factor)
	# Vertical tilt creates subtle perspective (wider at bottom when hovering top)
	var scale_x: float = base_scale + tilt.y * 0.012
	var scale_y: float = base_scale - tilt.y * 0.008
	card_panel.scale = Vector2(scale_x, scale_y)

	# Shadow shift: move panel style shadow opposite to tilt direction
	var panel_style := card_panel.get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		var base_offset := Vector2(2.0, 4.0)
		var tilt_shift := Vector2(-tilt.x, -tilt.y) * MerlinVisual.CARD_3D_SHADOW_SHIFT
		panel_style.shadow_offset = base_offset + tilt_shift

	# Shine overlay: shifts across card surface based on tilt direction
	if _card_3d_shine and is_instance_valid(_card_3d_shine):
		var shine_alpha: float = hover_factor * MerlinVisual.CARD_3D_SHINE_ALPHA
		_card_3d_shine.color = Color(1.0, 1.0, 1.0, shine_alpha)
		# Shift shine position to follow "light source" (upper-left)
		var shine_margin_x: float = tilt.x * 20.0
		var shine_margin_y: float = tilt.y * 15.0
		_card_3d_shine.position = Vector2(shine_margin_x, shine_margin_y)

	# Layered compositor parallax — depth effect per layer on hover
	if _scene_compositor_v2 and is_instance_valid(_scene_compositor_v2):
		_scene_compositor_v2.apply_parallax(tilt)


func _enable_card_3d() -> void:
	## Enable 3D tilt tracking (call after card entry animation settles).
	_card_3d_active = true
	_card_tilt_current = Vector2.ZERO
	_card_tilt_target = Vector2.ZERO


func _disable_card_3d() -> void:
	## Disable 3D tilt (call before card exit or during transitions).
	_card_3d_active = false
	_card_tilt_target = Vector2.ZERO


# ═══════════════════════════════════════════════════════════════════════════════
# THINKING ANIMATION — Shown while LLM generates next card
# ═══════════════════════════════════════════════════════════════════════════════

var _thinking_active := false
var _thinking_dots := 0
var _thinking_timer: Timer = null
var _thinking_spiral: Control = null

func show_thinking() -> void:
	## Show "Merlin is thinking" animation on the card area.
	if _thinking_active:
		return
	if not card_panel or not is_instance_valid(card_panel):
		push_warning("[MerlinUI] show_thinking: card_panel invalid, skipping")
		return
	_thinking_active = true
	_disable_card_3d()

	# Dim options
	if options_container and is_instance_valid(options_container):
		var tw := create_tween()
		tw.tween_property(options_container, "modulate:a", 0.3, 0.2)

	# Update card text with animated dots
	if card_speaker and is_instance_valid(card_speaker):
		card_speaker.text = "Merlin"
		card_speaker.visible = true

	# Show Celtic spiral animation (reuse if already created)
	if card_panel and is_instance_valid(card_panel):
		if _thinking_spiral != null and is_instance_valid(_thinking_spiral):
			_thinking_spiral.visible = true
		else:
			_thinking_spiral = Control.new()
			_thinking_spiral.name = "ThinkingSpiral"
			_thinking_spiral.custom_minimum_size = Vector2(60, 60)
			_thinking_spiral.set_anchors_preset(Control.PRESET_CENTER)
			var panel_size: Vector2 = card_panel.size if card_panel.size.length() > 0 else Vector2(460, 360)
			_thinking_spiral.position = panel_size * 0.5 - Vector2(30, 50)
			_thinking_spiral.draw.connect(_draw_thinking_spiral.bind(_thinking_spiral))
			card_panel.add_child(_thinking_spiral)

	# Start dot animation timer
	_thinking_dots = 0
	if _thinking_timer == null:
		_thinking_timer = Timer.new()
		_thinking_timer.wait_time = 0.4
		_thinking_timer.timeout.connect(_on_thinking_tick)
		add_child(_thinking_timer)
	_thinking_timer.start()
	_on_thinking_tick()  # First tick immediately


func hide_thinking() -> void:
	## Hide thinking animation and restore UI.
	if not _thinking_active:
		return
	_thinking_active = false

	# Stop timer
	if _thinking_timer:
		_thinking_timer.stop()

	# Hide spiral (keep for reuse — avoids node leak)
	if _thinking_spiral and is_instance_valid(_thinking_spiral):
		_thinking_spiral.visible = false

	# Restore options opacity
	if options_container and is_instance_valid(options_container):
		var tw := create_tween()
		tw.tween_property(options_container, "modulate:a", 1.0, 0.2)


func _on_thinking_tick() -> void:
	## Animate thinking dots on the card text.
	if not card_text or not is_instance_valid(card_text):
		if _thinking_timer and is_instance_valid(_thinking_timer):
			_thinking_timer.stop()
		_thinking_active = false
		return
	_thinking_dots = (_thinking_dots + 1) % 4
	var dots := ".".repeat(_thinking_dots)
	card_text.text = "Merlin reflechit" + dots

	# Rotate spiral
	if _thinking_spiral and is_instance_valid(_thinking_spiral):
		var tw := create_tween()
		tw.tween_property(_thinking_spiral, "rotation", _thinking_spiral.rotation + PI * 0.5, 0.35)
		_thinking_spiral.queue_redraw()


func _draw_thinking_spiral(ctrl: Control) -> void:
	## Draw an animated Celtic triple spiral (triskelion).
	var cx := ctrl.size.x * 0.5
	var cy := ctrl.size.y * 0.5
	var r := mini(int(ctrl.size.x), int(ctrl.size.y)) * 0.35

	# Draw 3 spiraling arms (triskelion)
	for arm in range(3):
		var angle_offset := TAU * arm / 3.0
		var points := PackedVector2Array()
		for i in range(20):
			var t := float(i) / 19.0
			var spiral_r := r * t
			var angle := angle_offset + t * TAU * 0.75
			points.append(Vector2(
				cx + cos(angle) * spiral_r,
				cy + sin(angle) * spiral_r
			))
		if points.size() >= 2:
			ctrl.draw_polyline(points, MerlinVisual.CRT_PALETTE.amber, 2.0, true)

	# Center dot
	ctrl.draw_circle(Vector2(cx, cy), 3.0, MerlinVisual.CRT_PALETTE.amber)


# ═══════════════════════════════════════════════════════════════════════════════
# UPDATE METHODS
# ═══════════════════════════════════════════════════════════════════════════════

func update_biome_indicator(biome_name: String, biome_color: Color) -> void:
	if biome_indicator:
		biome_indicator.text = "# %s #" % biome_name
		biome_indicator.add_theme_color_override("font_color", Color(biome_color.r, biome_color.g, biome_color.b, 0.7))


func update_aspects(_aspects: Dictionary) -> void:
	# Aspect system removed — no-op (kept for interface compatibility)
	pass


func update_souffle(souffle: int) -> void:
	_update_souffle(souffle)


func update_selected_perk(perk_id: String) -> void:
	## B.1 — Called by controller/store to show selected perk badge near Souffle.
	if _perk_badge == null or not is_instance_valid(_perk_badge):
		return
	if perk_id.is_empty():
		_perk_badge.visible = false
		return
	var pdata: Dictionary = MerlinConstants.SOUFFLE_PERK_TYPES.get(perk_id, {})
	var pname: String = str(pdata.get("name", perk_id.capitalize()))
	_perk_badge.text = "[%s]" % pname
	_perk_badge.visible = true


func _update_souffle(souffle: int) -> void:
	var old_souffle := _previous_souffle
	_previous_souffle = souffle
	current_souffle = souffle

	# Update numeric counter
	if _souffle_counter and is_instance_valid(_souffle_counter):
		_souffle_counter.text = "%d/%d" % [souffle, MerlinConstants.SOUFFLE_MAX]
		if souffle == 0:
			_souffle_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
		elif souffle <= 2:
			_souffle_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.warning)
		else:
			_souffle_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.souffle)

	if not souffle_display:
		return

	for i in range(MerlinConstants.SOUFFLE_MAX):
		var icon: Label = souffle_display.get_child(i) as Label
		if icon:
			if i < souffle:
				icon.text = SOUFFLE_ICON
				icon.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.souffle)
			else:
				icon.text = SOUFFLE_EMPTY
				icon.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.inactive_dark)

	# VFX: Regen animation (gained souffle)
	if old_souffle >= 0 and souffle > old_souffle:
		for i in range(old_souffle, mini(souffle, MerlinConstants.SOUFFLE_MAX)):
			var icon: Label = souffle_display.get_child(i) as Label
			if icon:
				icon.scale = Vector2(0.3, 0.3)
				icon.pivot_offset = icon.size * 0.5
				var tw := create_tween()
				tw.tween_property(icon, "scale", Vector2(1.2, 1.2), 0.25) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1 * (i - old_souffle))
				tw.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.15)
		SFXManager.play("souffle_regen")

	# VFX: Consumption animation (lost souffle)
	if old_souffle >= 0 and souffle < old_souffle:
		for i in range(souffle, mini(old_souffle, MerlinConstants.SOUFFLE_MAX)):
			var icon: Label = souffle_display.get_child(i) as Label
			if icon:
				var tw := create_tween()
				tw.tween_property(icon, "scale", Vector2(0.5, 0.5), 0.2) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				tw.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.1)

	# VFX: Full souffle glow (7/7)
	if souffle >= MerlinConstants.SOUFFLE_MAX:
		for i in range(MerlinConstants.SOUFFLE_MAX):
			var icon: Label = souffle_display.get_child(i) as Label
			if icon:
				icon.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.souffle_full)
		if old_souffle >= 0 and old_souffle < MerlinConstants.SOUFFLE_MAX:
			SFXManager.play("souffle_full")

	# VFX: Empty souffle blink (0/7)
	if souffle <= 0:
		for i in range(MerlinConstants.SOUFFLE_MAX):
			var icon: Label = souffle_display.get_child(i) as Label
			if icon:
				var tw := create_tween()
				tw.set_loops(3)
				tw.tween_property(icon, "modulate:a", 0.3, 0.4)
				tw.tween_property(icon, "modulate:a", 1.0, 0.4)

	# Center is now free (Phase 43) — no risk indicator needed
	_update_souffle_btn_state()
	# Glow pulsant sur l'icône souffle quand disponible, dim statique sinon
	if souffle_display and is_instance_valid(souffle_display):
		var icon: Label = souffle_display.get_child(0) as Label
		if icon and is_instance_valid(icon):
			if _souffle_glow_tween and _souffle_glow_tween.is_valid():
				_souffle_glow_tween.kill()
			if souffle > 0:
				# Glow pulsant : luminosité oscillante  (disponible)
				icon.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.souffle)
				_souffle_glow_tween = create_tween().set_loops()
				_souffle_glow_tween.tween_property(icon, "modulate:a", 0.55, 1.2).set_trans(Tween.TRANS_SINE)
				_souffle_glow_tween.tween_property(icon, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
			else:
				# Dim statique (utilisé)
				icon.modulate.a = 0.35
				icon.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.inactive_dark)


func _on_souffle_btn_pressed() -> void:
	## Activate Souffle d'Ogham — boosts next action's dice success.
	if current_souffle <= 0 or _souffle_active:
		SFXManager.play("error")
		return
	_souffle_active = true
	SFXManager.play("souffle_regen")
	# Visual confirmation: change icon + pulse animation
	if _souffle_btn and is_instance_valid(_souffle_btn):
		_souffle_btn.text = "+" + SOUFFLE_ICON
		_souffle_btn.pivot_offset = _souffle_btn.size / 2.0
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_souffle_btn, "scale", Vector2(1.3, 1.3), 0.15)
		tw.tween_property(_souffle_btn, "scale", Vector2(1.1, 1.1), 0.25)
	souffle_activated.emit()


func _update_souffle_btn_state() -> void:
	## Enable/disable Souffle button based on available charges.
	if not _souffle_btn or not is_instance_valid(_souffle_btn):
		return
	var can_use: bool = current_souffle > 0 and not _souffle_active
	_souffle_btn.disabled = not can_use
	_souffle_btn.modulate.a = 1.0 if can_use else 0.35


func is_souffle_active() -> bool:
	return _souffle_active


func consume_souffle_active() -> void:
	## Called by controller after resolving dice with Souffle bonus.
	_souffle_active = false
	_update_souffle_btn_state()


func _toggle_bestiole_wheel() -> void:
	## Lazy-load and toggle Bestiole Ogham wheel (Tab key).
	if not bestiole_wheel or not is_instance_valid(bestiole_wheel):
		var wheel_scene := preload("res://scenes/ui/BestioleWheel.tscn")
		bestiole_wheel = wheel_scene.instantiate() as BestioleWheelSystem
		add_child(bestiole_wheel)
		bestiole_wheel.z_index = 25
		bestiole_wheel.ogham_selected.connect(func(_skill_id: String):
			SFXManager.play("skill_activate")
		)
	if bestiole_wheel.is_open:
		bestiole_wheel.close_wheel()
	else:
		var store_node: Node = get_node_or_null("/root/MerlinStore")
		if store_node and store_node is MerlinStore:
			bestiole_wheel.open_wheel(store_node as MerlinStore)
		else:
			SFXManager.play("error")


func update_life_essence(life: int) -> void:
	## Update the life essence display — 10 barres pixelisées de 10 PV (DOC_17).
	if _life_counter and is_instance_valid(_life_counter):
		_life_counter.text = "%d/%d" % [life, MerlinConstants.LIFE_ESSENCE_MAX]
		if life <= 0:
			_life_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
		elif life <= MerlinConstants.LIFE_ESSENCE_LOW_THRESHOLD:
			_life_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.warning)
		else:
			_life_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)  ## BUG-01 fix: healthy = phosphor not danger
	# Mise à jour des 10 segments pixelisés (10 PV chacun)
	if _life_segment_bars.size() == MerlinConstants.LIFE_BAR_SEGMENTS:
		var remaining: int = clampi(life, 0, MerlinConstants.LIFE_ESSENCE_MAX)
		for seg_i in range(MerlinConstants.LIFE_BAR_SEGMENTS):
			var seg: ProgressBar = _life_segment_bars[seg_i]
			if not seg or not is_instance_valid(seg):
				continue
			var seg_max: int = 10
			var seg_filled: int = clampi(remaining - seg_i * seg_max, 0, seg_max)
			seg.value = float(seg_filled)
			# Couleur : rouge si dernier segment critique
			var bar_pct: float = float(life) / float(MerlinConstants.LIFE_ESSENCE_MAX)
			if bar_pct <= 0.2:
				MerlinVisual.apply_bar_theme(seg, "danger")
			elif bar_pct <= 0.5:
				MerlinVisual.apply_bar_theme(seg, "warning")
		if life <= MerlinConstants.LIFE_ESSENCE_LOW_THRESHOLD and _life_segment_bars.size() > 0:
			var last_full_seg: int = maxi(0, int(life / 10) - 1)
			var last_seg: ProgressBar = _life_segment_bars[last_full_seg]
			if last_seg and is_instance_valid(last_seg):
				var tw := create_tween()
				tw.set_loops(2)
				tw.tween_property(last_seg, "modulate:a", 0.5, 0.3)
				tw.tween_property(last_seg, "modulate:a", 1.0, 0.3)
	elif _life_bar and is_instance_valid(_life_bar):
		# Fallback : barre unique si segments non créés
		_life_bar.value = life


func update_essences_collected(value: int) -> void:
	if _essence_counter and is_instance_valid(_essence_counter):
		_essence_counter.text = "%d ◆" % maxi(value, 0)


func update_resource_bar(tool_id: String, day: int, mission_current: int, mission_total: int, essences_collected: int = 0) -> void:
	if _tool_label:
		if tool_id != "" and MerlinConstants.EXPEDITION_TOOLS.has(tool_id):
			var tool_info: Dictionary = MerlinConstants.EXPEDITION_TOOLS[tool_id]
			_tool_label.text = "%s %s" % [str(tool_info.get("icon", "")), str(tool_info.get("name", tool_id))]
		else:
			_tool_label.text = ""
	if _day_label:
		_day_label.text = "Jour %d" % day
	if _mission_progress_label:
		if mission_total > 0:
			_mission_progress_label.text = "Mission %d/%d" % [mission_current, mission_total]
		else:
			_mission_progress_label.text = ""
	update_essences_collected(essences_collected)


func display_card(card: Dictionary) -> void:
	if card.is_empty():
		push_warning("[MerlinUI] display_card called with empty card")
		return
	current_card = card
	_highlighted_option = -1  # Reset arrow-key highlight for new card
	if _reward_badge and is_instance_valid(_reward_badge):
		_reward_badge.hide_badge()
	## BUG-04 fix: kill critical badge pulse before new card (avoids persistent glow)
	if _critical_badge_tween:
		_critical_badge_tween.kill()
		_critical_badge_tween = null
	if card_panel and is_instance_valid(card_panel):
		card_panel.modulate = Color.WHITE

	# Safety: ensure ALL thinking animations are hidden before showing card (P0.1.2)
	hide_merlin_thinking_overlay()
	hide_thinking()
	hide_what_if_labels()

	# Reset button states completely for new card (undo all tween effects)
	for btn in option_buttons:
		if is_instance_valid(btn):
			btn.set_pressed_no_signal(false)
			btn.release_focus()
			btn.disabled = true      # Locked until typewriter completes
			btn.scale = Vector2.ONE
			btn.modulate = Color(1, 1, 1, 0.0)  # Hidden until typewriter completes
			var parent_c: Control = btn.get_parent()
			if parent_c and is_instance_valid(parent_c) and parent_c is Container:
				(parent_c as Container).queue_sort()

	# Ensure options container is visible (may have been hidden by opening sequence)
	if options_container and is_instance_valid(options_container):
		options_container.modulate.a = 1.0
		options_container.visible = true

	_layout_card_stage()
	_push_card_shadow()
	_animate_remaining_deck_draw()

	SFXManager.play("card_draw")

	# Resolve speaker and pixel portrait
	var speaker: String = str(card.get("speaker", ""))
	var speaker_key := PixelCharacterPortrait.resolve_character_key(speaker) if speaker != "" else ""
	var is_new_speaker := speaker_key != "" and speaker_key != _current_speaker_key

	# Update speaker label
	if card_speaker and is_instance_valid(card_speaker):
		card_speaker.text = PixelCharacterPortrait.get_character_name(speaker_key) if speaker_key != "" else ""
		card_speaker.visible = not speaker.is_empty()

	# Pixel portrait: assemble new character if speaker changed
	if is_new_speaker:
		_current_speaker_key = speaker_key
		# Check if speaker is an NPC archetype (32x32 portrait)
		var npc_key := PixelNpcPortrait.resolve_npc_key(speaker)
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

	# Disable 3D tilt during card transition
	_disable_card_3d()

	# Animate card entrance — pixel construction (blocks assemble from above)
	if card_panel and is_instance_valid(card_panel):
		if _card_float_tween:
			_card_float_tween.kill()
		if _card_entry_tween:
			_card_entry_tween.kill()
		# Position card at final location, hidden — PixelContentAnimator will reveal it
		card_panel.position = _card_base_pos
		card_panel.modulate.a = 0.0
		card_panel.scale = Vector2.ONE
		card_panel.rotation_degrees = 0.0
		# Pixel reveal: blocks rain from above to form the card
		# Note: SFX already played by SFXManager.play("card_draw") above — no sfx in config
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
		# Chain post-reveal callbacks: float + 3D tilt + option buttons
		# Use animation_complete signal to trigger after pixel assembly finishes
		_card_entry_tween = create_tween()
		_card_entry_tween.tween_interval(MerlinVisual.CARD_ENTRY_DURATION + 0.15)
		_card_entry_tween.tween_callback(_start_card_float_and_3d)
		# Options are revealed after typewriter (not after card entry) — see _typewriter_card_text()

	# Update card title (poetic GM title — P3.17.2)
	if _card_title_label and is_instance_valid(_card_title_label):
		var title_text: String = str(card.get("title", ""))
		if not title_text.is_empty():
			_card_title_label.text = title_text
			_card_title_label.visible = true
		else:
			_card_title_label.visible = false

	# Update text with typewriter
	if card_text and is_instance_valid(card_text):
		_typewriter_card_text(card.get("text", "..."))

	# Update source badge (dev indicator)
	if _card_source_badge and is_instance_valid(_card_source_badge):
		var card_source := _detect_card_source(card)
		LLMSourceBadge.update_badge(_card_source_badge, card_source)
		_card_source_badge.visible = true

	# Update scene compositor (dynamic illustration per card context)
	var vtags: Array = card.get("visual_tags", [])
	var biome: String = str(card.get("biome", "foret_broceliande"))
	var season: String = str(card.get("season", "automne"))
	if vtags.is_empty():
		vtags = _derive_card_fallback_tags(card)
	if _scene_compositor_v2 and is_instance_valid(_scene_compositor_v2):
		var card_type: String = str(card.get("type", "narrative"))
		_scene_compositor_v2.compose_layers(vtags, biome, season, card_type)
		_scene_compositor_v2.build_scene(true)
	elif _scene_compositor and is_instance_valid(_scene_compositor):
		_scene_compositor.compose_scene(vtags, biome, season)
		_scene_compositor.assemble(true)

	# Apply card-level visual FX from visual_tags (P1.9.1)
	_apply_card_visual_tags(card)

	# Play ambient SFX from audio_tags (P1.9.2)
	_apply_card_audio_tags(card)

	# Update options — always show all 3 buttons in action-verb style.
	var options: Array = card.get("options", [])
	for i in range(3):
		var has_option: bool = i < options.size() and options[i] is Dictionary
		var option: Dictionary = options[i] if has_option else {}
		var action_label := _actionize_option_label(str(option.get("label", "")), i)
		# Labels above buttons removed (text already in buttons)
		if i < option_buttons.size() and is_instance_valid(option_buttons[i]):
			var key: String = OPTION_KEYS.get(i, "?")
			option_buttons[i].text = action_label if has_option else "—"
			option_buttons[i].disabled = true  # Locked until typewriter ends
			option_buttons[i].modulate.a = 0.0 if has_option else 0.35  # Hidden (has_opt) or dim (no_opt)
		# Action description — shown as subtitle label above button on hover
		if i < _option_desc_labels.size() and is_instance_valid(_option_desc_labels[i]):
			var action_desc: String = str(option.get("action_desc", ""))
			if action_desc.is_empty():
				# Fallback: show risk level if no action description
				var risk: String = str(option.get("risk_level", ""))
				match risk:
					"faible": action_desc = "Prudent"
					"moyen": action_desc = "Equilibre"
					"eleve": action_desc = "Audacieux"
			# Truncate long descriptions for UI fit
			if action_desc.length() > 80:
				var cut := action_desc.rfind(" ", 77)
				if cut > 40:
					action_desc = action_desc.substr(0, cut) + "..."
				else:
					action_desc = action_desc.substr(0, 77) + "..."
			_option_desc_labels[i].text = action_desc
			_option_desc_labels[i].visible = false  # Shown on hover via _on_option_hover_enter
		# Also set button tooltip for accessibility
		if i < option_buttons.size() and is_instance_valid(option_buttons[i]):
			var risk2: String = str(option.get("risk_level", ""))
			match risk2:
				"faible": option_buttons[i].tooltip_text = "Prudent — risque faible"
				"moyen": option_buttons[i].tooltip_text = "Equilibre — risque moyen (coute 1 Souffle)"
				"eleve": option_buttons[i].tooltip_text = "Audacieux — risque eleve"

	# Minigame badge
	if _minigame_badge and is_instance_valid(_minigame_badge):
		var minigame: Dictionary = card.get("minigame", {})
		if not minigame.is_empty():
			_minigame_badge.text = "\u2694 Mini-jeu: %s (%s)" % [
				str(minigame.get("name", "")), str(minigame.get("desc", ""))]
			_minigame_badge.visible = true
		else:
			_minigame_badge.visible = false

	# Pre-hide buttons and reset state from previous card animations
	for j in range(option_buttons.size()):
		if is_instance_valid(option_buttons[j]):
			option_buttons[j].modulate.a = 0.0
			option_buttons[j].scale = Vector2.ONE
			# Force parent Container to re-compute layout (fixes residual position offsets)
			var parent_container: Control = option_buttons[j].get_parent()
			if parent_container and is_instance_valid(parent_container) and parent_container is Container:
				(parent_container as Container).queue_sort()


func _actionize_option_label(raw_label: String, option_index: int) -> String:
	## Returns ONLY a single action verb (title case). No description, no prefix.
	## Trusts the LLM adapter — no secondary whitelist rejection.
	var clean := raw_label.strip_edges()
	if clean.is_empty():
		return ACTION_VERB_FALLBACK[clampi(option_index, 0, ACTION_VERB_FALLBACK.size() - 1)]
	var words: PackedStringArray = clean.replace(":", " ").replace(",", " ").replace(".", " ").split(" ", false)
	if words.is_empty():
		return ACTION_VERB_FALLBACK[clampi(option_index, 0, ACTION_VERB_FALLBACK.size() - 1)]
	return words[0].capitalize()


func _animate_option_entrance() -> void:
	## Pixel reveal stagger entrance for option buttons. Called after card pixel-assembles.
	## Uses PixelContentAnimator for pixel construction effect + scale settle.
	var pixel_btn_config: Dictionary = {
		"duration": MerlinVisual.OPTION_SLIDE_DURATION,
		"block_size": 6,
		"row_stagger": 0.003,
		"jitter": 0.008,
		"scatter_x": 12.0,
		"scatter_y_min": -20.0,
		"scatter_y_max": -50.0,
		"easing": "back_out",
	}
	for j in range(option_buttons.size()):
		if not is_instance_valid(option_buttons[j]) or option_buttons[j].disabled:
			continue
		var btn: Button = option_buttons[j]
		btn.pivot_offset = btn.size / 2.0
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.95, 0.95)
		var delay: float = float(j) * MerlinVisual.OPTION_STAGGER_DELAY
		# Stagger: wait then pixel-reveal each button
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
			if not is_inside_tree():  ## BUG-07 fix: scene may have changed during await
				return
		PixelContentAnimator.reveal(btn, pixel_btn_config)
		# Subtle scale settle alongside pixel reveal
		var settle_tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		settle_tw.tween_property(btn, "scale", Vector2.ONE, MerlinVisual.OPTION_SLIDE_DURATION)
	# Safety timer: ensure all buttons reach alpha=1.0 even if pixel anim is killed
	get_tree().create_timer(1.2).timeout.connect(func():
		for btn2 in option_buttons:
			if is_instance_valid(btn2) and not btn2.disabled and btn2.modulate.a < 0.5:
				btn2.modulate.a = 1.0
				btn2.scale = Vector2.ONE
	)


func _derive_card_fallback_tags(card: Dictionary) -> Array:
	## Derive visual tags from card metadata when LLM tags are missing.
	var biome: String = str(card.get("biome", "foret_broceliande"))
	var base: Array = PixelSceneData.BIOME_DEFAULT_TAGS.get(biome, ["foret", "arbres"])
	var result: Array = base.duplicate()
	var tags: Array = card.get("tags", [])
	for tag in tags:
		var modifier_tags: Array = PixelSceneData.MODIFIER_TAGS.get(str(tag), [])
		for mt in modifier_tags:
			if mt not in result:
				result.append(mt)
	return result


func _detect_card_source(card: Dictionary) -> String:
	## Detect whether a card was generated by LLM, fallback pool, or static.
	var tags: Array = card.get("tags", [])
	if "llm_generated" in tags:
		return "llm"
	if "emergency_fallback" in tags:
		return "fallback"
	var gen_by: String = str(card.get("_generated_by", ""))
	if gen_by.contains("llm"):
		return "llm"
	if gen_by != "":
		return "llm"  # Any _generated_by means LLM pipeline
	# Check if card has omniscient pipeline marker
	if card.has("_omniscient"):
		return "llm"
	return "fallback"


# ═══════════════════════════════════════════════════════════════════════════════
# CARD VISUAL & AUDIO TAGS (P1.9) — Ambient FX driven by LLM tags
# ═══════════════════════════════════════════════════════════════════════════════

## Tag-to-visual mapping: card panel color modulation per mood tag.
const VISUAL_TAG_TINTS := {
	"danger": Color(1.0, 0.7, 0.7, 1.0),
	"combat": Color(1.0, 0.75, 0.75, 1.0),
	"mort": Color(0.85, 0.75, 0.85, 1.0),
	"magie": Color(0.85, 0.85, 1.0, 1.0),
	"sacre": Color(0.9, 0.9, 1.0, 1.0),
	"mystere": Color(0.8, 0.85, 0.95, 1.0),
	"nuit": Color(0.75, 0.78, 0.9, 1.0),
	"brume": Color(0.88, 0.9, 0.92, 1.0),
	"orage": Color(0.8, 0.8, 0.88, 1.0),
	"feu": Color(1.0, 0.85, 0.7, 1.0),
	"eau": Color(0.8, 0.9, 1.0, 1.0),
	"terre": Color(0.92, 0.88, 0.78, 1.0),
	"lumiere": Color(1.0, 1.0, 0.9, 1.0),
	"soin": Color(0.8, 1.0, 0.85, 1.0),
}

## Tag-to-sound mapping: ambient SFX per mood tag.
const AUDIO_TAG_SOUNDS := {
	"danger": "critical_alert",
	"combat": "dice_shake",
	"magie": "magic_reveal",
	"sacre": "ogham_chime",
	"mystere": "mist_breath",
	"brume": "mist_breath",
	"orage": "flash_boom",
	"feu": "flash_boom",
	"soin": "bestiole_shimmer",
	"ogham": "ogham_chime",
	"nuit": "mist_breath",
}

var _card_visual_tween: Tween = null


func _apply_card_visual_tags(card: Dictionary) -> void:
	## Apply card-level visual modulation based on visual_tags (P1.9.1).
	## Subtle color tint on card panel + pulse for danger tags.
	if not card_panel or not is_instance_valid(card_panel):
		return

	var vtags: Array = card.get("visual_tags", [])
	var tags: Array = card.get("tags", [])
	var all_tags: Array = vtags + tags

	# Find first matching visual tag
	var tint: Color = Color.WHITE
	var has_danger := false
	for tag in all_tags:
		var tag_str: String = str(tag).to_lower()
		if VISUAL_TAG_TINTS.has(tag_str):
			tint = VISUAL_TAG_TINTS[tag_str]
		if tag_str == "danger" or tag_str == "combat" or tag_str == "mort":
			has_danger = true

	# Kill previous visual tag tween
	if _card_visual_tween and _card_visual_tween.is_valid():
		_card_visual_tween.kill()

	if tint != Color.WHITE:
		# Smooth tint transition
		_card_visual_tween = create_tween()
		_card_visual_tween.tween_property(card_panel, "self_modulate", tint, 0.6)
		# Danger pulse: subtle oscillation
		if has_danger:
			var dim_tint: Color = tint.darkened(0.1)
			_card_visual_tween.set_loops(0)
			_card_visual_tween.tween_property(card_panel, "self_modulate", dim_tint, 1.2)
			_card_visual_tween.tween_property(card_panel, "self_modulate", tint, 1.2)
	else:
		card_panel.self_modulate = Color.WHITE


func _apply_card_audio_tags(card: Dictionary) -> void:
	## Play ambient SFX based on audio_tags from the card (P1.9.2).
	## Plays at most 1 ambient sound per card to avoid cacophony.
	var atags: Array = card.get("audio_tags", [])
	var vtags: Array = card.get("visual_tags", [])
	var all_tags: Array = atags + vtags

	for tag in all_tags:
		var tag_str: String = str(tag).to_lower()
		if AUDIO_TAG_SOUNDS.has(tag_str):
			# Delayed playback: after card_draw sound finishes
			var sound_name: String = AUDIO_TAG_SOUNDS[tag_str]
			get_tree().create_timer(0.4).timeout.connect(
				func() -> void: SFXManager.play_varied(sound_name, 0.15),
				CONNECT_ONE_SHOT
			)
			return  # Only 1 ambient sound per card


# ═══════════════════════════════════════════════════════════════════════════════
# CARD STACKING — Shadow cards pile up behind the active card
# ═══════════════════════════════════════════════════════════════════════════════

func _push_card_shadow() -> void:
	if not card_panel or not is_instance_valid(card_panel) or not card_container:
		return
	# Remove oldest shadow if at max
	if _card_shadows.size() >= MAX_CARD_SHADOWS:
		var oldest: Panel = _card_shadows.pop_front()
		if is_instance_valid(oldest):
			var fade_tw := create_tween()
			fade_tw.tween_property(oldest, "modulate:a", 0.0, 0.2)
			fade_tw.tween_callback(oldest.queue_free)

	# Create shadow from current card position
	var shadow := Panel.new()
	shadow.custom_minimum_size = card_panel.custom_minimum_size
	shadow.size = card_panel.size
	shadow.position = card_panel.position + Vector2(2, 2) * float(_card_shadows.size() + 1)
	shadow.modulate.a = maxf(0.06, 0.18 - 0.04 * float(_card_shadows.size()))
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var base_style = card_panel.get_theme_stylebox("panel")
	if base_style:
		var style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
		if style:
			style.bg_color = style.bg_color.darkened(0.15)
			shadow.add_theme_stylebox_override("panel", style)

	card_container.add_child(shadow)
	card_container.move_child(shadow, 0)  # Behind main card
	_card_shadows.append(shadow)


# ═══════════════════════════════════════════════════════════════════════════════
# PROGRESSIVE INDICATORS — Reveal aspects and souffle one by one
# ═══════════════════════════════════════════════════════════════════════════════

func show_progressive_indicators() -> void:
	## Animate only the top HUD metrics (health, souffle, essences) via pixel reveal.
	var essence_panel: Control = _essence_counter.get_parent() if _essence_counter and is_instance_valid(_essence_counter) else null
	if _top_status_bar and is_instance_valid(_top_status_bar):
		_top_status_bar.modulate.a = 1.0
	if life_panel and is_instance_valid(life_panel):
		life_panel.modulate.a = 0.0
	if souffle_panel and is_instance_valid(souffle_panel):
		souffle_panel.modulate.a = 0.0
	if essence_panel and is_instance_valid(essence_panel):
		essence_panel.modulate.a = 0.0

	await get_tree().create_timer(0.15).timeout
	if not is_inside_tree():
		return

	var pca: Node = get_node_or_null("/root/PixelContentAnimator")

	if life_panel and is_instance_valid(life_panel):
		if pca:
			pca.reveal(life_panel, {"duration": 0.3, "block_size": 6})
			await get_tree().create_timer(0.32).timeout
		else:
			life_panel.modulate.a = 1.0

	if souffle_panel and is_instance_valid(souffle_panel):
		SFXManager.play("ogham_chime")
		if pca:
			pca.reveal(souffle_panel, {"duration": 0.35, "block_size": 6})
			await get_tree().create_timer(0.38).timeout
		else:
			souffle_panel.modulate.a = 1.0

	if essence_panel and is_instance_valid(essence_panel):
		if pca:
			pca.reveal(essence_panel, {"duration": 0.28, "block_size": 6})
			await get_tree().create_timer(0.3).timeout
		else:
			essence_panel.modulate.a = 1.0


# ═══════════════════════════════════════════════════════════════════════════════
# AMBIENT VFX — Biome-themed simple particles behind the card
# ═══════════════════════════════════════════════════════════════════════════════

func start_ambient_vfx(biome_key: String) -> void:
	## Start subtle ambient particle effects based on biome.
	_ambient_biome_key = biome_key
	if _ambient_timer:
		_ambient_timer.queue_free()
	_ambient_timer = Timer.new()
	_ambient_timer.wait_time = 1.2
	_ambient_timer.autostart = true
	_ambient_timer.timeout.connect(_spawn_ambient_particle)
	add_child(_ambient_timer)


func _spawn_ambient_particle() -> void:
	if _ambient_particles.size() >= MAX_AMBIENT_PARTICLES or not is_inside_tree():
		return
	var vp: Vector2 = get_viewport_rect().size
	var px := ColorRect.new()
	px.size = Vector2(randf_range(3.0, 5.0), randf_range(3.0, 5.0))
	px.mouse_filter = Control.MOUSE_FILTER_IGNORE
	px.z_index = -1
	px.modulate.a = randf_range(0.15, 0.35)

	var start_pos := Vector2.ZERO
	var end_pos := Vector2.ZERO
	var duration: float = randf_range(4.0, 7.0)

	var key: String = _ambient_biome_key.replace("foret_", "").replace("landes_", "") \
		.replace("cotes_", "").replace("villages_", "").replace("cercles_", "") \
		.replace("marais_", "").replace("collines_", "")

	match key:
		"broceliande":
			# Falling leaves (green/brown)
			px.color = [Color(0.35, 0.55, 0.28), Color(0.55, 0.40, 0.25)][randi() % 2]
			start_pos = Vector2(randf_range(0, vp.x), -10)
			end_pos = start_pos + Vector2(randf_range(-60, 60), vp.y + 20)
		"bruyere":
			# Wind dust (horizontal)
			px.color = Color(0.55, 0.40, 0.55, 0.5)
			start_pos = Vector2(-10, randf_range(vp.y * 0.3, vp.y * 0.8))
			end_pos = Vector2(vp.x + 10, start_pos.y + randf_range(-30, 30))
			duration = randf_range(3.0, 5.0)
		"sauvages":
			# Rising mist (blue)
			px.color = Color(0.38, 0.58, 0.75, 0.4)
			start_pos = Vector2(randf_range(0, vp.x), vp.y + 10)
			end_pos = start_pos + Vector2(randf_range(-20, 20), -vp.y * 0.4)
		"celtes":
			# Rising smoke (gray)
			px.color = Color(0.5, 0.48, 0.45, 0.3)
			start_pos = Vector2(randf_range(vp.x * 0.3, vp.x * 0.7), vp.y + 10)
			end_pos = start_pos + Vector2(randf_range(-15, 15), -vp.y * 0.5)
		"pierres":
			# Fireflies (warm yellow glow)
			px.color = Color(0.85, 0.75, 0.30, 0.6)
			px.size = Vector2(3, 3)
			start_pos = Vector2(randf_range(vp.x * 0.1, vp.x * 0.9), randf_range(vp.y * 0.2, vp.y * 0.8))
			end_pos = start_pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))
			duration = randf_range(2.0, 4.0)
		"korrigans":
			# Phosphorescence (dark green)
			px.color = Color(0.20, 0.45, 0.25, 0.4)
			start_pos = Vector2(randf_range(0, vp.x), vp.y * randf_range(0.6, 0.95))
			end_pos = start_pos + Vector2(randf_range(-25, 25), randf_range(-20, -50))
			duration = randf_range(3.0, 5.0)
		"dolmens":
			# Grass swaying (green tufts)
			px.color = Color(0.40, 0.60, 0.30, 0.3)
			start_pos = Vector2(randf_range(0, vp.x), vp.y * randf_range(0.7, 0.95))
			end_pos = start_pos + Vector2(randf_range(-20, 20), randf_range(-10, 10))
			duration = randf_range(2.0, 4.0)
		_:
			# Default: gentle floating motes
			px.color = Color(0.6, 0.55, 0.45, 0.2)
			start_pos = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
			end_pos = start_pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))

	px.position = start_pos
	add_child(px)
	_ambient_particles.append(px)

	var tw := create_tween()
	tw.tween_property(px, "position", end_pos, duration).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(px, "modulate:a", 0.0, duration * 0.8).set_delay(duration * 0.2)
	tw.tween_callback(func():
		_ambient_particles.erase(px)
		if is_instance_valid(px):
			px.queue_free()
	)


func show_opening_sequence(biome_key: String, season_hint: String = "", hour_hint: int = -1) -> void:
	if _opening_sequence_done:
		return
	_opening_sequence_done = true
	_layout_run_zones()
	_layout_card_stage()
	_set_intro_hidden_state()
	await get_tree().process_frame

	var key := _normalize_biome_key(biome_key)
	var season := _normalize_season(season_hint, key)
	var hour := hour_hint
	if hour < 0 or hour > 23:
		var now: Dictionary = Time.get_datetime_dict_from_system()
		hour = int(now.get("hour", 12))

	_build_biome_artwork(key, season, hour)
	biome_art_layer.visible = true
	biome_art_layer.modulate.a = 0.0
	await _animate_biome_artwork_stack()
	_dim_biome_background()
	await _animate_deck_assembly(key)
	_set_empty_center_card_state()
	await _reveal_empty_center_card()
	await _reveal_intro_blocks()


func _set_intro_hidden_state() -> void:
	var essence_panel: Control = _essence_counter.get_parent() if _essence_counter and is_instance_valid(_essence_counter) else null
	var hide_targets: Array = [
		_top_status_bar,
		life_panel,
		souffle_panel,
		essence_panel,
		card_container,
		_bottom_zone,
		_pioche_column,
		_cimetiere_column,
		options_container,
		info_panel,
	]
	for node in hide_targets:
		var target: Control = node as Control
		if target and is_instance_valid(target):
			target.modulate.a = 0.0


func _set_empty_center_card_state() -> void:
	current_card = {
		"id": "intro_placeholder",
		"_placeholder": true,
	}
	if _card_title_label and is_instance_valid(_card_title_label):
		_card_title_label.text = ""
		_card_title_label.visible = false
	if card_speaker and is_instance_valid(card_speaker):
		card_speaker.text = ""
		card_speaker.visible = false
	if card_text and is_instance_valid(card_text):
		card_text.text = " "
	if _card_source_badge and is_instance_valid(_card_source_badge):
		_card_source_badge.visible = false
	if card_panel and is_instance_valid(card_panel):
		card_panel.modulate.a = 1.0
		card_panel.scale = Vector2.ONE
		card_panel.rotation_degrees = 0.0
		card_panel.position = _card_base_pos


func _reveal_empty_center_card() -> void:
	if not card_container or not is_instance_valid(card_container):
		return
	var tw := create_tween()
	tw.tween_property(card_container, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _reveal_intro_blocks() -> void:
	var essence_panel: Control = _essence_counter.get_parent() if _essence_counter and is_instance_valid(_essence_counter) else null
	var reveal_targets: Array = [_top_status_bar, _bottom_zone, _pioche_column, _cimetiere_column, card_container, info_panel, life_panel, souffle_panel, essence_panel]
	for i in range(reveal_targets.size()):
		var target: Control = reveal_targets[i] as Control
		if not target or not is_instance_valid(target):
			continue
		var tw := create_tween()
		tw.tween_property(target, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_delay(0.05 * float(i))
	await get_tree().create_timer(0.45).timeout


func _normalize_biome_key(biome_key: String) -> String:
	var key := str(biome_key).strip_edges().to_lower()
	if MerlinVisual.BIOME_ART_PROFILES.has(key):
		return key
	if BIOME_SHORT_NAMES.has(key):
		return str(BIOME_SHORT_NAMES[key])
	return "broceliande"


func _normalize_season(season_hint: String, biome_key: String) -> String:
	var season := str(season_hint).strip_edges().to_lower()
	if season == "automn":
		season = "automne"
	if MerlinVisual.SEASON_TINTS.has(season):
		return season
	return str(BIOME_DEFAULT_SEASON.get(biome_key, "automne"))


func _tone_color(base: Color, hour_light: Color, season_tint: Color) -> Color:
	return Color(
		clampf(base.r * hour_light.r * season_tint.r, 0.0, 1.0),
		clampf(base.g * hour_light.g * season_tint.g, 0.0, 1.0),
		clampf(base.b * hour_light.b * season_tint.b, 0.0, 1.0),
		1.0
	)


func _hour_light_color(hour: int) -> Color:
	var h := clampi(hour, 0, 23)
	var daylight := (cos((float(h) - 12.0) * PI / 12.0) + 1.0) * 0.5
	var base := lerpf(0.38, 1.0, daylight)
	var blue_boost := lerpf(1.09, 0.96, daylight)
	return Color(base, base * 0.98, base * blue_boost, 1.0)


func _build_biome_artwork(biome_key: String, season_key: String, hour: int) -> void:
	if not biome_art_layer or not is_instance_valid(biome_art_layer):
		return
	for child in biome_art_layer.get_children():
		child.queue_free()
	_biome_art_pixels.clear()
	# TODO: When 2D biome assets are available, load them here:
	# var texture_path := "res://assets/biomes/%s.png" % biome_key
	# if ResourceLoader.exists(texture_path):
	#     _load_biome_texture(texture_path, season_key, hour)
	#     return
	## BUG-02 fix: removed early return — procedural pixel art now active

	var profile: Dictionary = MerlinVisual.BIOME_ART_PROFILES.get(biome_key, MerlinVisual.BIOME_ART_PROFILES.broceliande)
	var season_tint: Color = MerlinVisual.SEASON_TINTS.get(season_key, Color.WHITE)
	var hour_light: Color = _hour_light_color(hour)
	var sky_color := _tone_color(profile.sky, hour_light, season_tint)
	var mist_color := _tone_color(profile.mist, hour_light, season_tint)
	var mid_color := _tone_color(profile.mid, hour_light, season_tint)
	var accent_color := _tone_color(profile.accent, hour_light, season_tint)
	var foreground_color := _tone_color(profile.foreground, hour_light, season_tint)

	var vp := get_viewport_rect().size
	var pixel_size: float = floor(minf(vp.x / float(INTRO_PIXEL_COLS), vp.y / float(INTRO_PIXEL_ROWS)))
	pixel_size = clampf(pixel_size, 6.0, 20.0)
	var total_w: float = float(INTRO_PIXEL_COLS) * pixel_size
	var total_h: float = float(INTRO_PIXEL_ROWS) * pixel_size
	var origin: Vector2 = Vector2((vp.x - total_w) * 0.5, (vp.y - total_h) * 0.46)

	_add_biome_block(0, 0, INTRO_PIXEL_COLS, 18, sky_color, origin, pixel_size)
	_add_biome_block(0, 18, INTRO_PIXEL_COLS, 10, mist_color, origin, pixel_size)
	_add_biome_block(0, 28, INTRO_PIXEL_COLS, INTRO_PIXEL_ROWS - 28, mid_color.darkened(0.10), origin, pixel_size)

	for x in range(INTRO_PIXEL_COLS):
		var wave := sin(float(x) * 0.21) * 2.6 + cos(float(x) * 0.09) * 1.7
		var ridge_h := 5 + int(abs(wave))
		_add_biome_block(x, 30 - ridge_h, 1, ridge_h + 1, mid_color, origin, pixel_size)

	for x in range(INTRO_PIXEL_COLS):
		var ground_h := 6 + int(abs(sin(float(x) * 0.19)) * 2.0)
		_add_biome_block(x, INTRO_PIXEL_ROWS - ground_h, 1, ground_h, foreground_color, origin, pixel_size)

	_add_biome_feature_blocks(biome_key, origin, pixel_size, accent_color, foreground_color)
	biome_art_layer.modulate = Color.WHITE


func _add_biome_feature_blocks(
	biome_key: String,
	origin: Vector2,
	pixel_size: float,
	accent_color: Color,
	foreground_color: Color
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash("%s_%d" % [biome_key, int(Time.get_unix_time_from_system() / 1800)]))
	var trunk_color := foreground_color.lightened(0.08)
	var detail_color := accent_color.darkened(0.12)

	match biome_key:
		"broceliande":
			for i in range(28):
				var col := rng.randi_range(2, INTRO_PIXEL_COLS - 3)
				var trunk_h := rng.randi_range(5, 10)
				var canopy_w := rng.randi_range(3, 5)
				_add_biome_block(col, INTRO_PIXEL_ROWS - 6 - trunk_h, 1, trunk_h, trunk_color, origin, pixel_size)
				_add_biome_block(col - int(canopy_w / 2), INTRO_PIXEL_ROWS - 8 - trunk_h, canopy_w, 2, detail_color, origin, pixel_size)
		"landes":
			for i in range(40):
				var col := rng.randi_range(1, INTRO_PIXEL_COLS - 2)
				var h := rng.randi_range(1, 3)
				_add_biome_block(col, INTRO_PIXEL_ROWS - 7 - h, 1, h, detail_color, origin, pixel_size)
		"cotes":
			_add_biome_block(0, INTRO_PIXEL_ROWS - 7, INTRO_PIXEL_COLS, 2, accent_color.lightened(0.08), origin, pixel_size)
			for i in range(20):
				var col := rng.randi_range(4, INTRO_PIXEL_COLS - 6)
				var cliff_h := rng.randi_range(4, 9)
				_add_biome_block(col, INTRO_PIXEL_ROWS - 9 - cliff_h, 1, cliff_h, trunk_color, origin, pixel_size)
		"villages":
			for i in range(8):
				var col := 4 + i * 9
				_add_biome_block(col, INTRO_PIXEL_ROWS - 12, 5, 4, trunk_color, origin, pixel_size)
				_add_biome_block(col + 1, INTRO_PIXEL_ROWS - 14, 3, 2, detail_color, origin, pixel_size)
		"cercles":
			for i in range(12):
				var angle := TAU * float(i) / 12.0
				var col := int(INTRO_PIXEL_COLS * 0.5 + cos(angle) * 14.0)
				var row := int(INTRO_PIXEL_ROWS * 0.68 + sin(angle) * 4.0)
				_add_biome_block(col, row, 1, 4, trunk_color.lightened(0.12), origin, pixel_size)
		"marais":
			for i in range(10):
				var col := rng.randi_range(2, INTRO_PIXEL_COLS - 8)
				var row := rng.randi_range(INTRO_PIXEL_ROWS - 9, INTRO_PIXEL_ROWS - 5)
				_add_biome_block(col, row, rng.randi_range(4, 8), 1, accent_color.lightened(0.12), origin, pixel_size)
		"collines":
			for i in range(3):
				var base_col := 8 + i * 22
				_add_biome_block(base_col, INTRO_PIXEL_ROWS - 12, 8, 4, trunk_color, origin, pixel_size)
				_add_biome_block(base_col + 2, INTRO_PIXEL_ROWS - 14, 4, 2, detail_color, origin, pixel_size)
		_:
			for i in range(24):
				_add_biome_block(rng.randi_range(1, INTRO_PIXEL_COLS - 2), INTRO_PIXEL_ROWS - rng.randi_range(5, 12), 1, rng.randi_range(2, 5), detail_color, origin, pixel_size)


func _add_biome_block(col: int, row: int, width: int, height: int, color: Color, origin: Vector2, pixel_size: float) -> void:
	var c := maxi(col, 0)
	var r := maxi(row, 0)
	var w := mini(width, INTRO_PIXEL_COLS - c)
	var h := mini(height, INTRO_PIXEL_ROWS - r)
	if w <= 0 or h <= 0:
		return
	var block := ColorRect.new()
	block.size = Vector2(float(w) * pixel_size, float(h) * pixel_size)
	block.position = origin + Vector2(float(c) * pixel_size, float(r) * pixel_size)
	block.color = color
	block.modulate.a = 0.0
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	biome_art_layer.add_child(block)
	_biome_art_pixels.append(block)


func _animate_biome_artwork_stack() -> void:
	if _biome_art_pixels.is_empty():
		return
	var ordered: Array = _biome_art_pixels.duplicate()
	ordered.sort_custom(func(a: ColorRect, b: ColorRect) -> bool:
		return a.position.y > b.position.y
	)

	for i in range(ordered.size()):
		var px: ColorRect = ordered[i]
		if not is_instance_valid(px):
			continue
		var target := px.position
		px.position = target + Vector2(randf_range(-3.0, 3.0), randf_range(10.0, 24.0))
		px.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(px, "modulate:a", 1.0, 0.16)
		tw.parallel().tween_property(px, "position", target, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if i % INTRO_STACK_BATCH == INTRO_STACK_BATCH - 1:
			await get_tree().create_timer(INTRO_STACK_STEP).timeout

	var pulse := create_tween()
	pulse.tween_property(biome_art_layer, "modulate", Color(1.06, 1.06, 1.06), 0.14)
	pulse.tween_property(biome_art_layer, "modulate", Color.WHITE, 0.14)
	await pulse.finished


func _dim_biome_background() -> void:
	## Dim biome art layer to serve as subtle atmospheric background during gameplay.
	if not biome_art_layer or not is_instance_valid(biome_art_layer):
		return
	biome_art_layer.visible = true
	var tw := create_tween()
	tw.tween_property(biome_art_layer, "modulate:a", 0.80, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_start_biome_breathing()


func _start_biome_breathing() -> void:
	## Breathing animation on the biome background layer — forest fully visible.
	if not biome_art_layer or not is_instance_valid(biome_art_layer):
		return
	if _biome_breath_tween:  ## BUG-05 fix: kill previous loop before creating new one
		_biome_breath_tween.kill()
	_biome_breath_tween = create_tween().set_loops()
	_biome_breath_tween.tween_property(biome_art_layer, "modulate:a", 0.95, 4.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_biome_breath_tween.tween_property(biome_art_layer, "modulate:a", 0.80, 4.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_deck_assembly(_biome_key: String) -> void:
	## Désactivé — suppression de l'animation de shuffle (2026-02-26).
	## Les cartes se matérialisent en pixels directement via PixelContentAnimator.
	return
	var profile: Dictionary = MerlinVisual.BIOME_ART_PROFILES.get(_biome_key, MerlinVisual.BIOME_ART_PROFILES.broceliande)
	var edge_color: Color = Color(profile.accent)
	var vp := get_viewport_rect().size
	var center := Vector2(vp.x * 0.5, vp.y * 0.60)
	var reveal_center := center
	if card_panel and is_instance_valid(card_panel):
		var rect := card_panel.get_global_rect()
		reveal_center = rect.position + rect.size * 0.5
	var cards: Array[Panel] = []

	for i in range(INTRO_DECK_COUNT):
		var card := Panel.new()
		card.size = Vector2(92, 128)
		card.position = Vector2(center.x + randf_range(-240.0, 240.0), vp.y + 70.0 + randf_range(0.0, 120.0))
		card.rotation_degrees = randf_range(-36.0, 36.0)
		card.modulate.a = 0.0
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(MerlinVisual.CRT_PALETTE.bg_dark.r, MerlinVisual.CRT_PALETTE.bg_dark.g, MerlinVisual.CRT_PALETTE.bg_dark.b, 0.96)
		style.border_color = edge_color
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
		style.shadow_color = Color(0, 0, 0, 0.22)
		style.shadow_size = 5
		style.shadow_offset = Vector2(0, 2)
		card.add_theme_stylebox_override("panel", style)
		_deck_fx_layer.add_child(card)
		cards.append(card)

	# Phase 1: Cards crash into a central stack.
	for i in range(cards.size()):
		var card: Panel = cards[i]
		var stack_pos := Vector2(center.x - 46.0 + randf_range(-7.0, 7.0), center.y - 70.0 - float(i) * 1.4)
		var tw := create_tween()
		tw.tween_property(card, "modulate:a", 1.0, 0.09).set_delay(0.015 * float(i))
		tw.parallel().tween_property(card, "position", stack_pos, 0.27 + 0.01 * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(card, "rotation_degrees", randf_range(-4.0, 4.0), 0.27).set_delay(0.02 * float(i))
	await get_tree().create_timer(0.46).timeout

	# Phase 2: Riffle split and interleave.
	var left_stack: Array[Panel] = []
	var right_stack: Array[Panel] = []
	for i in range(cards.size()):
		if i % 2 == 0:
			left_stack.append(cards[i])
		else:
			right_stack.append(cards[i])
	for i in range(left_stack.size()):
		var lc := left_stack[i]
		var ltw := create_tween()
		ltw.tween_property(lc, "position", Vector2(center.x - 132.0, center.y - 84.0 + float(i) * 3.0), 0.18)
		ltw.parallel().tween_property(lc, "rotation_degrees", -15.0 + float(i), 0.18)
	for i in range(right_stack.size()):
		var rc := right_stack[i]
		var rtw := create_tween()
		rtw.tween_property(rc, "position", Vector2(center.x + 52.0, center.y - 84.0 + float(i) * 3.0), 0.18)
		rtw.parallel().tween_property(rc, "rotation_degrees", 15.0 - float(i), 0.18)
	await get_tree().create_timer(0.22).timeout

	var interleave: Array[Panel] = []
	for i in range(maxi(left_stack.size(), right_stack.size())):
		if i < left_stack.size():
			interleave.append(left_stack[i])
		if i < right_stack.size():
			interleave.append(right_stack[i])
	for i in range(interleave.size()):
		var ic := interleave[i]
		var itw := create_tween()
		itw.tween_property(ic, "position", Vector2(center.x - 46.0 + randf_range(-4.0, 4.0), center.y - 72.0 - float(i) * 1.3), 0.18)
		itw.parallel().tween_property(ic, "rotation_degrees", randf_range(-3.0, 3.0), 0.18)
		if i % 4 == 3:
			await get_tree().create_timer(0.015).timeout
	await get_tree().create_timer(0.16).timeout

	# Phase 3: Fan spread.
	var mid := (float(cards.size()) - 1.0) * 0.5
	for i in range(cards.size()):
		var card2: Panel = cards[i]
		var offset := float(i) - mid
		var fan_pos := Vector2(center.x - 46.0 + offset * 17.0, center.y - 74.0 + abs(offset) * 3.0)
		var tw2 := create_tween()
		tw2.tween_property(card2, "position", fan_pos, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw2.parallel().tween_property(card2, "rotation_degrees", offset * 4.8, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.22).timeout

	# Phase 4: Merge stack and keep only top few cards.
	for i in range(cards.size()):
		var card3: Panel = cards[i]
		var merge_pos := Vector2(center.x - 46.0 + randf_range(-3.0, 3.0), center.y - 70.0 - float(i) * 1.1)
		var tw3 := create_tween()
		tw3.tween_property(card3, "position", merge_pos, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw3.parallel().tween_property(card3, "rotation_degrees", randf_range(-2.0, 2.0), 0.20)
		tw3.parallel().tween_property(card3, "modulate:a", 0.0 if i < cards.size() - 3 else 1.0, 0.22)
	await get_tree().create_timer(0.18).timeout

	# Phase 5: Top card zoom reveal to the active-card center.
	var lead_card: Panel = cards.back()
	if lead_card and is_instance_valid(lead_card):
		lead_card.z_index = 9
		var reveal_tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		reveal_tw.tween_property(lead_card, "position", reveal_center - lead_card.size * 0.5, 0.24)
		reveal_tw.parallel().tween_property(lead_card, "rotation_degrees", 0.0, 0.24)
		reveal_tw.parallel().tween_property(lead_card, "scale", Vector2(3.9, 3.9), 0.24)
		reveal_tw.tween_property(lead_card, "modulate:a", 0.0, 0.12)
		await reveal_tw.finished

	for i in range(cards.size()):
		var card4: Panel = cards[i]
		if not is_instance_valid(card4):
			continue
		var tw4 := create_tween()
		tw4.tween_property(card4, "position:y", card4.position.y - randf_range(14.0, 44.0), 0.18).set_delay(0.01 * float(i))
		tw4.parallel().tween_property(card4, "modulate:a", 0.0, 0.15).set_delay(0.05 + 0.01 * float(i))
	await get_tree().create_timer(0.30).timeout
	_deck_fx_layer.visible = false


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN NARRATOR INTRO — Run opening narration
# ═══════════════════════════════════════════════════════════════════════════════

signal narrator_intro_finished

const NARRATOR_INTROS := [
	"Les brumes de Bretagne s'ouvrent devant toi... Le chemin serpente, et l'avenir est incertain.",
	"La foret murmure ton nom. Merlin veille... mais pour combien de temps encore?",
	"Le vent porte des echos anciens. Un nouveau cycle commence, voyageur.",
	"Les pierres se souviennent de chaque pas. Pret a ecrire un nouveau chapitre?",
	"L'aube se leve sur les landes. Quelque chose attend au bout du sentier.",
]

var _narrator_active := false
var _waiting_narrator_click := false
var _typewriter_active := false
var _typewriter_abort := false
var _souffle_glow_tween: Tween = null  # Persistent glow when souffle available
var _highlighted_option: int = -1  # Arrow key highlight without confirm (-1 = none)


func show_narrator_intro(biome_key: String = "") -> void:
	## Show Merlin as narrator + quest briefing before the first card of a run.
	print("[MerlinUI] show_narrator_intro(biome=%s)" % biome_key)
	SFXManager.play("whoosh")
	_narrator_active = true
	var should_dim_ui := not _opening_sequence_done

	# Hide game UI during intro (pixel dissolve)
	var pca: Node = get_node_or_null("/root/PixelContentAnimator")
	if should_dim_ui and options_container and is_instance_valid(options_container):
		if pca and options_container.modulate.a > 0.1:
			pca.dissolve(options_container, {"duration": 0.3, "block_size": 8})
		else:
			options_container.modulate.a = 0.0
	if should_dim_ui and info_panel and is_instance_valid(info_panel):
		if pca and info_panel.modulate.a > 0.1:
			pca.dissolve(info_panel, {"duration": 0.3, "block_size": 8})
		else:
			info_panel.modulate.a = 0.0

	# Resolve biome key — try parameter, then GameManager, then default
	var bk: String = biome_key.strip_edges().to_lower()
	if bk.is_empty():
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm:
			var run_data = gm.get("run")
			if run_data is Dictionary:
				bk = str(run_data.get("current_biome", run_data.get("biome", {}).get("id", "")))
	if bk.is_empty():
		bk = "broceliande"
	# Normalize: strip "foret_" etc. for MISSION_TEMPLATES lookup
	var bk_short: String = bk
	for prefix in ["foret_", "landes_", "cotes_", "villages_", "cercles_", "marais_", "collines_"]:
		bk_short = bk_short.replace(prefix, "")

	# Look up mission template from docs spec
	var mission: Dictionary = MerlinConstants.get_mission_template(bk_short)
	if mission.is_empty():
		mission = MerlinConstants.get_mission_template(bk)

	# Show Merlin as speaker with biome context (always show biome name)
	if card_speaker and is_instance_valid(card_speaker):
		var biome_display: String = bk.replace("_", " ").capitalize()
		if not mission.is_empty():
			var mission_name: String = str(mission.get("name", biome_display))
			card_speaker.text = "Merlin \u2014 %s" % mission_name
		else:
			card_speaker.text = "Merlin \u2014 %s" % biome_display
		card_speaker.visible = true

	# Try LLM intro (generated by TransitionBiome), fallback to static
	var atmo_text: String = ""
	var intro_source: String = "static"
	var intro_file := FileAccess.open("user://temp_run_intro.json", FileAccess.READ)
	if intro_file:
		var json_str := intro_file.get_as_text()
		intro_file.close()
		var parsed = JSON.parse_string(json_str)
		if parsed is Dictionary:
			var llm_text: String = str(parsed.get("text", ""))
			if llm_text.length() >= 10:
				atmo_text = llm_text
				intro_source = "llm"
				print("[MerlinUI] LLM narrator intro loaded: %s" % llm_text.left(50))
		DirAccess.remove_absolute("user://temp_run_intro.json")

	# Fallback: try inline LLM generation with 3s timeout, then static
	if atmo_text.is_empty():
		var merlin_ai: Node = get_node_or_null("/root/MerlinAI")
		if merlin_ai and merlin_ai.has_method("generate_text") and merlin_ai.get("is_ready"):
			var inline_prompt := "Tu es Merlin. Accueille le voyageur en 2 phrases. Biome: %s." % bk
			var t0 := Time.get_ticks_msec()
			var llm_r = await merlin_ai.generate_text(inline_prompt, {"max_tokens": 40, "temperature": 0.8})
			if (Time.get_ticks_msec() - t0) < 3000 and llm_r is Dictionary:
				var txt: String = str(llm_r.get("text", ""))
				if txt.length() >= 10:
					atmo_text = txt
					intro_source = "llm_inline"
	if atmo_text.is_empty():
		atmo_text = NARRATOR_INTROS[randi() % NARRATOR_INTROS.size()]

	# Compose full quest intro: mission title first, then atmospheric text
	var intro_text: String = ""
	if not mission.is_empty():
		var quest_title: String = str(mission.get("title", ""))
		var quest_text: String = str(mission.get("text", ""))
		if not quest_title.is_empty():
			intro_text = quest_title + "\n\n" + atmo_text
			if not quest_text.is_empty():
				intro_text += "\n\n" + quest_text
	if intro_text.is_empty():
		intro_text = atmo_text

	# Source badge for narrator intro
	if _card_source_badge and is_instance_valid(_card_source_badge):
		LLMSourceBadge.update_badge(_card_source_badge, intro_source)
		_card_source_badge.visible = true

	# SFX: eye_open before narration
	SFXManager.play("eye_open")

	# Multi-page typewriter: split long text into readable pages
	var pages: Array[String] = _split_into_pages(intro_text)
	for page_idx in range(pages.size()):
		if not is_inside_tree():
			return
		await _typewriter_card_text(pages[page_idx])
		# After each page: wait for click/key to continue
		if not is_inside_tree():
			return
		var is_last_page: bool = (page_idx == pages.size() - 1)
		var continue_hint: String = "[color=#8a7a6a][i]Cliquez pour continuer...[/i][/color]" if not is_last_page else "[color=#8a7a6a][i]Cliquez pour commencer l'aventure...[/i][/color]"
		if card_text and is_instance_valid(card_text):
			card_text.text += "\n\n" + continue_hint
		_waiting_narrator_click = true
		var safety_deadline := Time.get_ticks_msec() + 30000
		while _waiting_narrator_click and is_inside_tree() and Time.get_ticks_msec() < safety_deadline:
			await get_tree().process_frame
		_waiting_narrator_click = false
		if not is_last_page:
			SFXManager.play("card_draw")

	# SFX: card_draw after full narration
	SFXManager.play("card_draw")

	# Pixel reveal game UI
	if should_dim_ui and options_container and is_instance_valid(options_container):
		if pca:
			pca.reveal(options_container, {"duration": 0.35, "block_size": 8})
		else:
			options_container.modulate.a = 1.0
	if should_dim_ui and info_panel and is_instance_valid(info_panel):
		if pca:
			pca.reveal(info_panel, {"duration": 0.35, "block_size": 8})
		else:
			info_panel.modulate.a = 1.0

	_narrator_active = false
	narrator_intro_finished.emit()
	print("[MerlinUI] narrator intro finished")


func show_scenario_intro(title: String, context: String) -> void:
	## Display scenario-specific introduction before the first card.
	## Uses dealer_intro_context from the active scenario.
	if not card_text or not is_instance_valid(card_text):
		return
	if context.strip_edges().is_empty():
		return
	print("[MerlinUI] show_scenario_intro: %s" % title)
	# Speaker = scenario title
	if card_speaker and is_instance_valid(card_speaker):
		card_speaker.text = title if not title.is_empty() else "Scenario"
		card_speaker.visible = true
	SFXManager.play("eye_open")
	# Typewriter the context text
	await _typewriter_card_text(context)
	# Wait for click to continue
	if card_text and is_instance_valid(card_text):
		card_text.text += "\n\n[color=#8a7a6a][i]Cliquez pour commencer...[/i][/color]"
	_waiting_narrator_click = true
	var deadline := Time.get_ticks_msec() + 30000
	while _waiting_narrator_click and is_inside_tree() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_waiting_narrator_click = false
	SFXManager.play("card_draw")


func _split_into_pages(text: String, max_chars: int = 180) -> Array[String]:
	## Split long text into readable pages at sentence boundaries.
	## Returns at least 1 page. Double newlines always force a page break.
	var pages: Array[String] = []
	# First split on double newlines (explicit page breaks)
	var blocks: Array[String] = []
	for block in text.split("\n\n"):
		var trimmed: String = block.strip_edges()
		if not trimmed.is_empty():
			blocks.append(trimmed)
	# Then split any block longer than max_chars at sentence boundaries
	for block in blocks:
		if block.length() <= max_chars:
			pages.append(block)
		else:
			# Split at sentence endings (. ! ?) keeping the punctuation
			var sentences: PackedStringArray = block.split(". ")
			var current_page: String = ""
			for sent in sentences:
				var candidate: String = sent.strip_edges()
				if candidate.is_empty():
					continue
				# Re-add period if it was split off (unless ends with ! or ?)
				if not candidate.ends_with(".") and not candidate.ends_with("!") and not candidate.ends_with("?"):
					candidate += "."
				if current_page.is_empty():
					current_page = candidate
				elif (current_page + " " + candidate).length() <= max_chars:
					current_page += " " + candidate
				else:
					pages.append(current_page)
					current_page = candidate
			if not current_page.is_empty():
				pages.append(current_page)
	if pages.is_empty():
		pages.append(text.strip_edges())
	return pages


func _typewriter_card_text(full_text: String) -> void:
	## Pixel rain reveal for card text (replaces legacy typewriter).
	if card_text == null or not is_instance_valid(card_text):
		return

	_typewriter_active = true
	_typewriter_abort = false
	if _text_pixel_fx_layer and is_instance_valid(_text_pixel_fx_layer):
		for child in _text_pixel_fx_layer.get_children():
			child.queue_free()

	# Set full text hidden, then pixel reveal
	card_text.text = full_text
	card_text.visible_characters = -1
	card_text.modulate.a = 0.0

	var pca: Node = get_node_or_null("/root/PixelContentAnimator")
	if pca:
		await get_tree().process_frame
		pca.reveal(card_text, {"duration": 0.35, "block_size": 6, "easing": "back_out"})
		# Play a blip burst for audio feedback
		_play_blip()
		await get_tree().create_timer(0.4).timeout
	else:
		# Fallback: instant reveal
		card_text.modulate.a = 1.0

	_typewriter_active = false
	# Unlock buttons that have actual options (text != "—") then animate entrance
	for btn in option_buttons:
		if is_instance_valid(btn) and btn.text != "—":
			btn.disabled = false
	_animate_option_entrance()


func _spawn_text_pixel_drop(progress_ratio: float) -> void:
	if not _text_pixel_fx_layer or not is_instance_valid(_text_pixel_fx_layer):
		return
	if not card_panel or not is_instance_valid(card_panel):
		return

	var px := ColorRect.new()
	var size_px := randf_range(2.0, 4.0)
	px.size = Vector2(size_px, size_px)
	px.mouse_filter = Control.MOUSE_FILTER_IGNORE
	px.color = Color(0.70, 0.86, 1.0, 0.90)
	px.position = Vector2(
		lerpf(card_panel.size.x * 0.12, card_panel.size.x * 0.88, clampf(progress_ratio, 0.0, 1.0)) + randf_range(-6.0, 6.0),
		card_panel.size.y * 0.58 + randf_range(-24.0, -8.0)
	)
	_text_pixel_fx_layer.add_child(px)

	var tw := create_tween()
	tw.tween_property(px, "position:y", px.position.y + randf_range(12.0, 24.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(px, "modulate:a", 0.0, 0.18)
	tw.tween_callback(px.queue_free)


func _play_blip() -> void:
	## Désactivé — pas de SFX texte sur MerlinGame.
	return
	## Procedural keyboard click sound (pooled — no node leak).
	if _blip_pool.is_empty():
		return
	var player: AudioStreamPlayer = _blip_pool[_blip_idx]
	_blip_idx = (_blip_idx + 1) % BLIP_POOL_SIZE
	if player.playing:
		player.stop()
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var freq := randf_range(280.0, 380.0)
	var samples := int(22050.0 * 0.015)
	for s in range(samples):
		var t := float(s) / 22050.0
		var envelope := exp(-t * 200.0)
		var val := sin(TAU * freq * t) * envelope * 0.3
		val += randf_range(-0.05, 0.05) * envelope
		playback.push_frame(Vector2(val, val))


func update_mission(mission: Dictionary) -> void:
	if mission_label:
		if mission.get("revealed", false):
			var progress: int = int(mission.get("progress", 0))
			var total: int = int(mission.get("total", 0))
			mission_label.text = "Mission: %d/%d" % [progress, total]
		else:
			mission_label.text = "Mission: ???"


func update_cards_count(count: int) -> void:
	if cards_label:
		cards_label.text = "Cartes: %d" % count
	_remaining_deck_estimate = maxi(RUN_DECK_ESTIMATE - maxi(count, 0), 0)
	_update_remaining_deck_visual()


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

	# Skip typewriter on click/tap (don't return — let click reach buttons)
	if _typewriter_active and event is InputEventMouseButton and event.pressed:
		_typewriter_abort = true

	# Narrator intro: click to dismiss
	if _waiting_narrator_click and event is InputEventMouseButton and event.pressed:
		_waiting_narrator_click = false

	# Keyboard shortcuts for options (highlight first, confirm with Enter/Space)
	if event is InputEventKey and event.pressed:
		# Skip typewriter on any key
		if _typewriter_active:
			_typewriter_abort = true
			return
		# Narrator intro: any key to dismiss
		if _waiting_narrator_click:
			_waiting_narrator_click = false
			return
		match event.keycode:
			KEY_A, KEY_LEFT, KEY_1, KEY_KP_1:
				_highlight_option(MerlinConstants.CardOption.LEFT)
			KEY_B, KEY_UP, KEY_2, KEY_KP_2:
				_highlight_option(MerlinConstants.CardOption.CENTER)
			KEY_C, KEY_RIGHT, KEY_3, KEY_KP_3:
				_highlight_option(MerlinConstants.CardOption.RIGHT)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _highlighted_option >= 0:
					_on_option_pressed(_highlighted_option)
			KEY_TAB:
				_toggle_bestiole_wheel()


func _highlight_option(option: int) -> void:
	## Highlight an option without confirming (arrow key / letter key behavior).
	if current_card.is_empty():
		return
	if _highlighted_option == option:
		return  # Already highlighted

	# Reset all buttons to normal
	for i in range(option_buttons.size()):
		var btn: Button = option_buttons[i]
		if is_instance_valid(btn):
			btn.scale = Vector2.ONE
			btn.pivot_offset = btn.size / 2.0

	_highlighted_option = option
	SFXManager.play("hover")

	# Scale up and show badge for the highlighted option
	if option < option_buttons.size():
		var btn: Button = option_buttons[option]
		if is_instance_valid(btn):
			btn.pivot_offset = btn.size / 2.0
			var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.12)
		_on_option_hover_enter(option)


func _on_option_pressed(option: int) -> void:
	if current_card.is_empty():
		return

	_highlighted_option = -1  # Reset highlight on confirm
	SFXManager.play("choice_select")

	# Animate selected button: flash + scale slam
	if option < option_buttons.size():
		var btn := option_buttons[option]
		btn.pivot_offset = btn.size / 2.0
		var tween := create_tween()
		tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.08)
		tween.parallel().tween_property(btn, "modulate", Color(1.5, 1.5, 1.5), 0.08)
		tween.tween_property(btn, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(btn, "modulate", Color.WHITE, 0.15)

	# Clear non-selected buttons: fade out + scale down (no position:y — Container manages layout)
	for j in range(option_buttons.size()):
		if j == option:
			continue
		if not is_instance_valid(option_buttons[j]):
			continue
		var other_btn: Button = option_buttons[j]
		other_btn.pivot_offset = other_btn.size / 2.0
		var clear_tw := create_tween().set_parallel(true)
		clear_tw.tween_property(other_btn, "modulate:a", 0.0, 0.25)
		clear_tw.tween_property(other_btn, "scale", Vector2(0.85, 0.85), 0.25)

	# Hide all desc labels
	for dl in _option_desc_labels:
		if is_instance_valid(dl):
			dl.visible = false

	option_chosen.emit(option)


# ═══════════════════════════════════════════════════════════════════════════════
# END SCREEN
# ═══════════════════════════════════════════════════════════════════════════════

func show_end_screen(ending: Dictionary) -> void:
	# Phase 0 : forêt réagit dramatiquement avant l'overlay
	var is_victory: bool = ending.get("victory", false)
	if biome_art_layer and is_instance_valid(biome_art_layer):
		var tw_forest := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if is_victory:
			# Victoire : forêt s'illumine → blanc doré
			tw_forest.tween_property(biome_art_layer, "modulate", Color(1.4, 1.3, 0.8), 1.2)
			tw_forest.tween_property(biome_art_layer, "modulate", Color(1.1, 1.1, 0.9), 0.6)
		else:
			# Mort : forêt s'assombrit lentement → presque noire
			tw_forest.tween_property(biome_art_layer, "modulate:a", 0.06, 1.5)
		await tw_forest.finished

	# Hide main UI
	if card_container:
		card_container.visible = false
	if options_container:
		options_container.visible = false

	# Create parchment overlay
	var overlay := ColorRect.new()
	overlay.color = Color(MerlinVisual.CRT_PALETTE.bg_panel.r, MerlinVisual.CRT_PALETTE.bg_panel.g, MerlinVisual.CRT_PALETTE.bg_panel.b, 0.95)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.modulate.a = 0.0
	add_child(overlay)

	# Fade in
	var fade_tw := create_tween()
	fade_tw.tween_property(overlay, "modulate:a", 1.0, 0.8)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	# Celtic ornament top
	var orn_top := Label.new()
	orn_top.text = "\u2500\u2500\u2500 # \u2500\u2500\u2500"
	orn_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orn_top.add_theme_font_size_override("font_size", 14)
	orn_top.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	vbox.add_child(orn_top)

	# Ending title
	var title := Label.new()
	var ending_data: Dictionary = ending.get("ending", {})
	title.text = ending_data.get("title", "Fin")
	if title_font:
		title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if ending.get("victory", false):
		title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.success)
	else:
		title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)

	vbox.add_child(title)

	# Ending text
	if ending_data.has("text"):
		var text := Label.new()
		text.text = ending_data.get("text", "")
		if body_font:
			text.add_theme_font_override("font", body_font)
		text.add_theme_font_size_override("font_size", 16)
		text.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size.x = 400
		vbox.add_child(text)

	# Score
	var score := Label.new()
	score.text = "Gloire: %d" % ending.get("score", 0)
	if title_font:
		score.add_theme_font_override("font", title_font)
	score.add_theme_font_size_override("font_size", 22)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	vbox.add_child(score)

	# Life depleted indicator
	if ending.get("life_depleted", false):
		var life_lbl := Label.new()
		life_lbl.text = "Essences de vie epuisees"
		if body_font:
			life_lbl.add_theme_font_override("font", body_font)
		life_lbl.add_theme_font_size_override("font_size", 14)
		life_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
		life_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(life_lbl)

	# Stats
	var stats_lbl := Label.new()
	stats_lbl.text = "Cartes: %d  \u2502  Jours: %d" % [
		ending.get("cards_played", 0),
		ending.get("days_survived", 1)
	]
	if body_font:
		stats_lbl.add_theme_font_override("font", body_font)
	stats_lbl.add_theme_font_size_override("font_size", 14)
	stats_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_lbl)

	# Story summary — "Ton chemin" (last 5 choices)
	var story_log: Array = ending.get("story_log", [])
	if story_log.size() > 0:
		var path_title := Label.new()
		path_title.text = "Ton chemin"
		if title_font:
			path_title.add_theme_font_override("font", title_font)
		path_title.add_theme_font_size_override("font_size", 16)
		path_title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
		path_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(path_title)

		var last_entries: Array = story_log.slice(-5) if story_log.size() > 5 else story_log
		var path_parts: PackedStringArray = []
		for entry in last_entries:
			var choice_text: String = str(entry.get("choice", ""))
			if not choice_text.is_empty():
				path_parts.append(choice_text)
		if path_parts.size() > 0:
			var path_lbl := Label.new()
			path_lbl.text = " > ".join(path_parts)
			if body_font:
				path_lbl.add_theme_font_override("font", body_font)
			path_lbl.add_theme_font_size_override("font_size", 12)
			path_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
			path_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			path_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			path_lbl.custom_minimum_size.x = 400
			vbox.add_child(path_lbl)

	# Rewards section
	var rewards: Dictionary = ending.get("rewards", {})
	if rewards.size() > 0:
		# Partial rewards indicator
		if rewards.get("partial", false):
			var partial_lbl := Label.new()
			partial_lbl.text = "Run incomplete \u2014 recompenses x0.25"
			if body_font:
				partial_lbl.add_theme_font_override("font", body_font)
			partial_lbl.add_theme_font_size_override("font_size", 14)
			partial_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
			partial_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(partial_lbl)

		var rewards_title := Label.new()
		rewards_title.text = "Recompenses obtenues"
		if title_font:
			rewards_title.add_theme_font_override("font", title_font)
		rewards_title.add_theme_font_size_override("font_size", 18)
		rewards_title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
		rewards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(rewards_title)

		# Essences earned
		var ess: Dictionary = rewards.get("essence", {})
		if ess.size() > 0:
			var parts: PackedStringArray = []
			for elem in ess:
				if int(ess[elem]) > 0:
					parts.append("%s +%d" % [str(elem).left(4), int(ess[elem])])
			if parts.size() > 0:
				var ess_lbl := Label.new()
				ess_lbl.text = "Essences: " + " | ".join(parts)
				if body_font:
					ess_lbl.add_theme_font_override("font", body_font)
				ess_lbl.add_theme_font_size_override("font_size", 13)
				ess_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
				ess_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ess_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				ess_lbl.custom_minimum_size.x = 400
				vbox.add_child(ess_lbl)

		# Fragments, Liens, Gloire
		var currency_parts: PackedStringArray = []
		var frag: int = int(rewards.get("fragments", 0))
		var liens: int = int(rewards.get("liens", 0))
		var gloire_r: int = int(rewards.get("gloire", 0))
		if frag > 0:
			currency_parts.append("Fragments +%d" % frag)
		if liens > 0:
			currency_parts.append("Liens +%d" % liens)
		if gloire_r > 0:
			currency_parts.append("Gloire +%d" % gloire_r)
		if currency_parts.size() > 0:
			var cur_lbl := Label.new()
			cur_lbl.text = " | ".join(currency_parts)
			if body_font:
				cur_lbl.add_theme_font_override("font", body_font)
			cur_lbl.add_theme_font_size_override("font_size", 14)
			cur_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
			cur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(cur_lbl)

	# Celtic ornament bottom
	var orn_bot := Label.new()
	orn_bot.text = "\u2500\u2500\u2500 # \u2500\u2500\u2500"
	orn_bot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orn_bot.add_theme_font_size_override("font_size", 14)
	orn_bot.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	vbox.add_child(orn_bot)

	# Aspects final state
	var aspects_label := Label.new()
	var aspects_text := "Aspects finaux: "
	for aspect in MerlinConstants.TRIADE_ASPECTS:
		var state_val: int = current_aspects.get(aspect, 0)
		var info = MerlinConstants.TRIADE_ASPECT_INFO.get(aspect, {})
		var states = info.get("states", {})
		var animal_key: String = str(info.get("animal_key", aspect))
		var name_key: String = str(info.get("name_key", aspect))
		aspects_text += "%s %s (%s) | " % [tr(animal_key), tr(name_key), tr(str(states.get(state_val, "?")))]
	aspects_label.text = aspects_text.trim_suffix(" | ")
	aspects_label.add_theme_font_size_override("font_size", 12)
	aspects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(aspects_label)

	# Action buttons
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	vbox.add_child(spacer)

	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_box)

	var btn_hub := Button.new()
	btn_hub.text = "Retour au Hub"
	btn_hub.custom_minimum_size = Vector2(200, 50)
	btn_hub.pressed.connect(func(): PixelTransition.transition_to("res://scenes/HubAntre.tscn"))
	btn_box.add_child(btn_hub)

	var btn_new := Button.new()
	btn_new.text = "Nouvelle Aventure"
	btn_new.custom_minimum_size = Vector2(200, 50)
	btn_new.pressed.connect(func(): PixelTransition.transition_to("res://scenes/TransitionBiome.tscn"))
	btn_box.add_child(btn_new)


# ═══════════════════════════════════════════════════════════════════════════════
# CARD BODY CONTENT HOST — Switch body between text and dice/minigame
# ═══════════════════════════════════════════════════════════════════════════════

func switch_body_to_content() -> void:
	## Hide card text, show content host for dice/minigame.
	if _card_body_vbox and is_instance_valid(_card_body_vbox):
		_card_body_vbox.visible = false
	if _card_body_content_host and is_instance_valid(_card_body_content_host):
		_card_body_content_host.visible = true
		_card_body_content_host.mouse_filter = Control.MOUSE_FILTER_STOP


func switch_body_to_text() -> void:
	## Restore card text, hide content host. Clears any content host children.
	if _card_body_content_host and is_instance_valid(_card_body_content_host):
		for child in _card_body_content_host.get_children():
			child.queue_free()
		_card_body_content_host.visible = false
		_card_body_content_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _card_body_vbox and is_instance_valid(_card_body_vbox):
		_card_body_vbox.visible = true


func get_body_content_host() -> Control:
	## Returns the content host inside the card body for hosting dice/minigames.
	return _card_body_content_host


func set_options_visible(visible: bool) -> void:
	## Show or hide the option buttons bar (used during minigames).
	if options_container and is_instance_valid(options_container):
		options_container.visible = visible


# ═══════════════════════════════════════════════════════════════════════════════
# D20 DICE UI — Inside card body (Phase 44)
# ═══════════════════════════════════════════════════════════════════════════════

var _dice_overlay: Control = null
var _dice_display: Label = null
var _dice_dc_label: Label = null
var _dice_result_label: Label = null
var _dice_bg_panel: PanelContainer = null

func show_dice_roll(dc: int, target: int) -> void:
	## Show D20 dice animation inside card body. Await this.
	_ensure_dice_overlay()
	switch_body_to_content()
	_dice_overlay.visible = true
	_dice_overlay.modulate.a = 0.0
	_dice_dc_label.text = "Difficulte: %d" % dc
	_dice_result_label.text = ""
	_dice_display.text = "?"
	_dice_display.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	_dice_display.scale = Vector2.ONE
	if _dice_bg_panel and is_instance_valid(_dice_bg_panel):
		_dice_bg_panel.scale = Vector2.ONE
		_dice_bg_panel.rotation = 0.0

	# Fade in dice area
	var tw_in := create_tween()
	tw_in.tween_property(_dice_overlay, "modulate:a", 1.0, 0.2)
	await tw_in.finished

	# Dice roll animation: decelerate over 3.0s
	var duration := 3.0
	var elapsed := 0.0
	while elapsed < duration and is_inside_tree():
		var progress: float = elapsed / duration
		var cycle_speed: float = lerpf(0.07, 0.35, progress * progress)
		_dice_display.text = str(randi_range(1, 20))
		# Wobble the dice panel during cycling
		if _dice_bg_panel and is_instance_valid(_dice_bg_panel):
			_dice_bg_panel.rotation = randf_range(-0.1, 0.1) * (1.0 - progress)
		await get_tree().create_timer(cycle_speed).timeout
		elapsed += cycle_speed

	# Land on target
	_dice_display.text = str(target)
	if _dice_bg_panel and is_instance_valid(_dice_bg_panel):
		_dice_bg_panel.rotation = 0.0
		var tw_bounce := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw_bounce.tween_property(_dice_bg_panel, "scale", Vector2(1.25, 1.25), 0.15)
		tw_bounce.tween_property(_dice_bg_panel, "scale", Vector2(1.0, 1.0), 0.3)
		await tw_bounce.finished
	else:
		_dice_display.pivot_offset = _dice_display.size / 2.0
		var tw_bounce := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw_bounce.tween_property(_dice_display, "scale", Vector2(1.3, 1.3), 0.15)
		tw_bounce.tween_property(_dice_display, "scale", Vector2(1.0, 1.0), 0.25)
		await tw_bounce.finished


func show_dice_instant(dc: int, value: int) -> void:
	## Show dice result instantly (after minigame) inside card body.
	_ensure_dice_overlay()
	switch_body_to_content()
	_dice_overlay.visible = true
	_dice_overlay.modulate.a = 1.0
	_dice_dc_label.text = "Difficulte: %d" % dc
	_dice_result_label.text = ""
	_dice_display.text = str(value)
	var glow: Color = _dice_outcome_color(value, dc)
	_dice_display.add_theme_color_override("font_color", glow)
	# Bounce panel
	if _dice_bg_panel and is_instance_valid(_dice_bg_panel):
		_dice_bg_panel.rotation = 0.0
		var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_dice_bg_panel, "scale", Vector2(1.25, 1.25), 0.15)
		tw.tween_property(_dice_bg_panel, "scale", Vector2(1.0, 1.0), 0.3)
	else:
		_dice_display.pivot_offset = _dice_display.size / 2.0
		var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_dice_display, "scale", Vector2(1.3, 1.3), 0.15)
		tw.tween_property(_dice_display, "scale", Vector2(1.0, 1.0), 0.25)


func show_dice_result(roll: int, dc: int, outcome: String) -> void:
	## Show final dice result text + color.
	_ensure_dice_overlay()
	var glow: Color = _dice_outcome_color(roll, dc)
	_dice_display.add_theme_color_override("font_color", glow)

	match outcome:
		"critical_success":
			_dice_result_label.text = "Coup Critique !"
			_dice_result_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.souffle_full)
		"success":
			_dice_result_label.text = "Reussite ! (%d >= %d)" % [roll, dc]
			_dice_result_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.success)
		"failure":
			_dice_result_label.text = "Echec... (%d < %d)" % [roll, dc]
			_dice_result_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
		"critical_failure":
			_dice_result_label.text = "Echec Critique !"
			_dice_result_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)


func _dice_outcome_color(roll: int, dc: int) -> Color:
	if roll == 20:
		return MerlinVisual.CRT_PALETTE.souffle_full  # Gold
	elif roll == 1:
		return MerlinVisual.CRT_PALETTE.danger  # Dark red
	elif roll >= dc:
		return MerlinVisual.CRT_PALETTE.success  # Green
	else:
		return MerlinVisual.CRT_PALETTE.danger  # Red


func _ensure_dice_overlay() -> void:
	## Create dice UI elements inside the card body content host.
	if _dice_overlay and is_instance_valid(_dice_overlay):
		return
	if not _card_body_content_host or not is_instance_valid(_card_body_content_host):
		return
	_dice_overlay = Control.new()
	_dice_overlay.name = "DiceOverlay"
	_dice_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dice_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dice_overlay.visible = false
	_card_body_content_host.add_child(_dice_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dice_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	center.add_child(vbox)

	_dice_dc_label = Label.new()
	_dice_dc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_dc_label.add_theme_font_size_override("font_size", 12)
	_dice_dc_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	if body_font:
		_dice_dc_label.add_theme_font_override("font", body_font)
	vbox.add_child(_dice_dc_label)

	# Dice frame panel (smaller: 70x70, font 48px for in-card display)
	var dice_center := CenterContainer.new()
	vbox.add_child(dice_center)

	_dice_bg_panel = PanelContainer.new()
	_dice_bg_panel.custom_minimum_size = Vector2(70, 70)
	var dice_style := StyleBoxFlat.new()
	dice_style.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
	dice_style.border_color = MerlinVisual.CRT_PALETTE.amber
	dice_style.set_border_width_all(2)
	dice_style.set_corner_radius_all(10)
	dice_style.content_margin_left = 6
	dice_style.content_margin_right = 6
	dice_style.content_margin_top = 6
	dice_style.content_margin_bottom = 6
	dice_style.shadow_color = Color(0, 0, 0, 0.2)
	dice_style.shadow_size = 3
	dice_style.shadow_offset = Vector2(1, 2)
	_dice_bg_panel.add_theme_stylebox_override("panel", dice_style)
	_dice_bg_panel.pivot_offset = Vector2(35, 35)
	dice_center.add_child(_dice_bg_panel)

	_dice_display = Label.new()
	_dice_display.text = "?"
	_dice_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_display.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if title_font:
		_dice_display.add_theme_font_override("font", title_font)
	_dice_display.add_theme_font_size_override("font_size", 48)
	_dice_display.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	_dice_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dice_bg_panel.add_child(_dice_display)

	_dice_result_label = Label.new()
	_dice_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_result_label.add_theme_font_size_override("font_size", 13)
	if body_font:
		_dice_result_label.add_theme_font_override("font", body_font)
	vbox.add_child(_dice_result_label)


func _hide_dice_overlay() -> void:
	if _dice_overlay and is_instance_valid(_dice_overlay):
		var tw := create_tween()
		tw.tween_property(_dice_overlay, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func():
			_dice_overlay.visible = false
			switch_body_to_text()
		)


# ═══════════════════════════════════════════════════════════════════════════════
# MINIGAME INTRO & SCORE DISPLAY
# ═══════════════════════════════════════════════════════════════════════════════

const MINIGAME_FIELD_ICONS := {
	"combat": "\u2694",
	"exploration": "\uD83D\uDD0D",
	"mysticisme": "\u2728",
	"survie": "\u2605",
	"diplomatie": "\u2696",
}

func show_minigame_intro(field: String, tool_bonus_text: String, tool_bonus: int) -> void:
	## Brief intro announcing the minigame type inside the card body.
	if not _card_body_content_host or not is_instance_valid(_card_body_content_host):
		return
	switch_body_to_content()

	var overlay := Control.new()
	overlay.name = "MinigameIntro"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.modulate.a = 0.0
	_card_body_content_host.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	center.add_child(vbox)

	# Field icon
	var icon_label := Label.new()
	var field_icon: String = MINIGAME_FIELD_ICONS.get(field, "\u2726")
	icon_label.text = field_icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(icon_label)

	# Field name
	var name_label := Label.new()
	name_label.text = "Epreuve: %s" % field.capitalize()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font:
		name_label.add_theme_font_override("font", title_font)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	vbox.add_child(name_label)

	# Tool bonus
	if tool_bonus != 0 and tool_bonus_text != "":
		var bonus_label := Label.new()
		bonus_label.text = "%s DC %d" % [tool_bonus_text, tool_bonus]
		bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if body_font:
			bonus_label.add_theme_font_override("font", body_font)
		bonus_label.add_theme_font_size_override("font_size", 13)
		bonus_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.success)
		vbox.add_child(bonus_label)

	# Animate in then auto-remove (stays in card body)
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.2)
	tw.tween_interval(0.8)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.2)
	tw.tween_callback(overlay.queue_free)


func show_score_to_d20(score: int, d20: int, tool_bonus: int) -> void:
	## Brief display: "Score: 78 -> D20: 17" inside card body.
	_ensure_dice_overlay()
	switch_body_to_content()
	_dice_overlay.visible = true
	_dice_overlay.modulate.a = 1.0
	var bonus_text: String = ""
	if tool_bonus != 0:
		bonus_text = " (bonus %d)" % tool_bonus
	_dice_dc_label.text = "Score: %d \u2192 D20: %d%s" % [score, d20, bonus_text]
	_dice_dc_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.bestiole)
	_dice_display.text = str(d20)
	_dice_result_label.text = ""


# ═══════════════════════════════════════════════════════════════════════════════
# TRAVEL ANIMATION (fog overlay between cards)
# ═══════════════════════════════════════════════════════════════════════════════

func show_travel_animation(text: String) -> void:
	## Full-screen fog overlay with contextual text. Awaitable.
	_hide_dice_overlay()
	SFXManager.play("mist_breath")

	var fog := ColorRect.new()
	fog.name = "TravelFog"
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	var fog_base: Color = MerlinVisual.CRT_PALETTE.phosphor
	fog.color = Color(fog_base.r * 0.4, fog_base.g * 0.4, fog_base.b * 0.4, 0.0)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fog)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	if body_font:
		lbl.add_theme_font_override("font", body_font)
	lbl.add_theme_font_size_override("font_size", 18)
	var lbl_base: Color = MerlinVisual.CRT_PALETTE.bg_panel
	lbl.add_theme_color_override("font_color", Color(lbl_base.r, lbl_base.g, lbl_base.b, 0.0))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	fog.add_child(lbl)

	# Fade in
	var tw_in := create_tween()
	tw_in.set_parallel(true)
	tw_in.tween_property(fog, "color:a", 0.85, 0.6)
	tw_in.tween_property(lbl, "theme_override_colors/font_color:a", 1.0, 0.6)
	await tw_in.finished

	# Hold (extended for LLM generation time)
	if is_inside_tree():
		await get_tree().create_timer(1.8).timeout

	# Fade out
	var tw_out := create_tween()
	tw_out.set_parallel(true)
	tw_out.tween_property(fog, "color:a", 0.0, 0.6)
	tw_out.tween_property(lbl, "theme_override_colors/font_color:a", 0.0, 0.6)
	await tw_out.finished

	if is_instance_valid(fog):
		fog.queue_free()


func show_dream_overlay(dream_text: String) -> void:
	## Full-screen dream overlay with deep purple tint, pulsing, typewriter text (P3.18.2).
	## Awaitable — holds for reading time proportional to text length.
	SFXManager.play("mist_breath")

	# Deep dream background
	var dream_bg := ColorRect.new()
	dream_bg.name = "DreamOverlay"
	dream_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dream_bg.color = Color(MerlinVisual.CRT_PALETTE.bg_deep.r, MerlinVisual.CRT_PALETTE.bg_deep.g, MerlinVisual.CRT_PALETTE.bg_deep.b, 0.0)
	dream_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dream_bg)

	# Dream header
	var header := Label.new()
	header.text = "~ Reve ~"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.set_anchors_preset(Control.PRESET_CENTER_TOP)
	header.offset_top = 60.0
	header.offset_left = -200.0
	header.offset_right = 200.0
	var title_font: Font = MerlinVisual.get_font("title")
	if title_font:
		header.add_theme_font_override("font", title_font)
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(MerlinVisual.CRT_PALETTE.cyan.r, MerlinVisual.CRT_PALETTE.cyan.g, MerlinVisual.CRT_PALETTE.cyan.b, 0.0))
	dream_bg.add_child(header)

	# Dream text (center of screen)
	var lbl := RichTextLabel.new()
	lbl.text = ""
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.offset_left = -260.0
	lbl.offset_right = 260.0
	lbl.offset_top = -80.0
	lbl.offset_bottom = 80.0
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	var dream_body_font: Font = MerlinVisual.get_font("body")
	if dream_body_font:
		lbl.add_theme_font_override("normal_font", dream_body_font)
	lbl.add_theme_font_size_override("normal_font_size", 15)
	lbl.add_theme_color_override("default_color", MerlinVisual.CRT_PALETTE.cyan_bright)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a = 0.0
	dream_bg.add_child(lbl)

	# Fade in background + header
	var tw_in := create_tween()
	tw_in.set_parallel(true)
	tw_in.tween_property(dream_bg, "color:a", 0.92, 1.0).set_trans(Tween.TRANS_SINE)
	tw_in.tween_property(header, "theme_override_colors/font_color:a", 0.8, 1.2)
	tw_in.tween_property(lbl, "modulate:a", 1.0, 1.0)
	await tw_in.finished

	# Typewriter dream text
	for i in range(dream_text.length()):
		lbl.text = dream_text.left(i + 1)
		if is_inside_tree():
			await get_tree().create_timer(0.03).timeout

	# Gentle pulse on background while reading
	var read_time: float = clampf(dream_text.length() * 0.04, 2.0, 6.0)
	var pulse_tw := create_tween()
	pulse_tw.set_loops(int(read_time / 1.6))
	pulse_tw.tween_property(dream_bg, "color:a", 0.85, 0.8).set_trans(Tween.TRANS_SINE)
	pulse_tw.tween_property(dream_bg, "color:a", 0.92, 0.8).set_trans(Tween.TRANS_SINE)

	if is_inside_tree():
		await get_tree().create_timer(read_time).timeout

	pulse_tw.kill()

	# Guard: abort if node left the tree during read wait
	if not is_inside_tree():
		if is_instance_valid(dream_bg):
			dream_bg.queue_free()
		return

	# Fade out
	var tw_out := create_tween()
	tw_out.set_parallel(true)
	tw_out.tween_property(dream_bg, "color:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw_out.tween_property(header, "theme_override_colors/font_color:a", 0.0, 0.8)
	tw_out.tween_property(lbl, "modulate:a", 0.0, 1.0)
	await tw_out.finished

	if is_instance_valid(dream_bg):
		dream_bg.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# REACTION TEXT + CRITICAL BADGE + BIOME PASSIVE
# ═══════════════════════════════════════════════════════════════════════════════

func show_reaction_text(text: String, outcome: String) -> void:
	## Show narrative reaction on the card text area.
	if not card_text or not is_instance_valid(card_text):
		return
	_flash_biome_for_outcome(outcome)
	# Restore card text VBox (may be hidden after dice/minigame)
	switch_body_to_text()
	var color: Color = MerlinVisual.CRT_PALETTE.success if outcome.contains("success") else MerlinVisual.CRT_PALETTE.danger
	card_text.text = "[color=#%s]%s[/color]" % [color.to_html(false), text]
	card_text.visible_characters = -1
	card_text.modulate.a = 1.0


func show_result_text_transition(result_text: String, outcome: String) -> void:
	## Replace card text with a narrative result using fade + typewriter.
	if not card_text or not is_instance_valid(card_text):
		return
	_flash_biome_for_outcome(outcome)
	# Switch body back to text mode (dice/minigame hid the card text VBox)
	switch_body_to_text()
	# Fade out current text
	var tw := create_tween()
	tw.tween_property(card_text, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if not is_inside_tree():
		return

	# Update speaker label
	if card_speaker and is_instance_valid(card_speaker):
		match outcome:
			"critical_success":
				card_speaker.text = "Reussite critique !"
				card_speaker.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.souffle_full)
			"success":
				card_speaker.text = "Reussite"
				card_speaker.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.success)
			"critical_failure":
				card_speaker.text = "Echec critique..."
				card_speaker.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
			_:
				card_speaker.text = "Echec"
				card_speaker.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)

	# Colorize and typewriter the result
	var color: Color = MerlinVisual.CRT_PALETTE.success if outcome.contains("success") else MerlinVisual.CRT_PALETTE.danger
	var bbcode_text := "[color=#%s]%s[/color]" % [color.to_html(false), result_text]
	card_text.modulate.a = 1.0
	_typewriter_card_text(bbcode_text)


func _flash_biome_for_outcome(outcome: String) -> void:
	## Flash the biome background to match the choice outcome.
	## success/critical_success → green shimmer | failure/critical_failure → red pulse.
	if not biome_art_layer or not is_instance_valid(biome_art_layer):
		return
	var is_success: bool = outcome.contains("success")
	var intensity: float = 1.6 if outcome.contains("critical") else 1.3
	var tint: Color = Color(0.7, intensity, 0.7) if is_success else Color(intensity, 0.7, 0.7)
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(biome_art_layer, "modulate", tint, 0.12)
	tw.tween_property(biome_art_layer, "modulate", Color.WHITE, 0.25)


func show_critical_badge() -> void:
	## Pulse gold border on the card panel to indicate critical choice.
	if not card_panel or not is_instance_valid(card_panel):
		return
	var base_style = card_panel.get_theme_stylebox("panel")
	if not base_style:
		return
	var style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	if style:
		style.border_color = MerlinVisual.CRT_PALETTE.souffle_full
		style.set_border_width_all(3)
		card_panel.add_theme_stylebox_override("panel", style)
	# Pulse animation (infinite, killed in display_card())
	_critical_badge_tween = create_tween().set_loops(0)  ## BUG-04 fix: stored in class var
	_critical_badge_tween.tween_property(card_panel, "modulate", Color(1.15, 1.1, 0.9), 0.3)
	_critical_badge_tween.tween_property(card_panel, "modulate", Color.WHITE, 0.3)


func show_biome_passive(passive: Dictionary) -> void:
	## Brief notification for biome passive effect.
	var text: String = str(passive.get("text", "Force du biome..."))
	var notif := Label.new()
	notif.text = text
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	notif.add_theme_font_size_override("font_size", 14)
	notif.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.success)
	if body_font:
		notif.add_theme_font_override("font", body_font)
	notif.modulate.a = 0.0
	add_child(notif)
	var tw := create_tween()
	tw.tween_property(notif, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.5)
	tw.tween_property(notif, "modulate:a", 0.0, 0.3)
	tw.tween_callback(notif.queue_free)


# ═══════════════════════════════════════════════════════════════════════════════
# CARD OUTCOME ANIMATIONS (shake, pulse, particles)
# ═══════════════════════════════════════════════════════════════════════════════

func animate_card_outcome(outcome: String) -> void:
	## Animate card panel based on D20 outcome.
	_disable_card_3d()
	if not card_panel or not is_instance_valid(card_panel):
		return
	match outcome:
		"critical_success":
			# Gold pulse
			var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(card_panel, "scale", Vector2(1.08, 1.08), 0.2)
			tw.tween_property(card_panel, "scale", Vector2(1.0, 1.0), 0.3)
		"success":
			var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(card_panel, "scale", Vector2(1.04, 1.04), 0.15)
			tw.tween_property(card_panel, "scale", Vector2(1.0, 1.0), 0.2)
		"failure":
			# Shake horizontal x3 — BUG-06 fix: capture origin_x once to ensure correct oscillation
			var origin_x: float = _card_base_pos.x if _card_base_pos != Vector2.ZERO else card_panel.position.x
			var tw := create_tween()
			for _i in range(3):
				tw.tween_property(card_panel, "position:x", origin_x + 8, 0.05).set_trans(Tween.TRANS_SINE)
				tw.tween_property(card_panel, "position:x", origin_x - 8, 0.05).set_trans(Tween.TRANS_SINE)
			tw.tween_property(card_panel, "position:x", origin_x, 0.05)
		"critical_failure":
			# Violent shake x5 + shrink — BUG-06 fix: same as failure
			var origin_x: float = _card_base_pos.x if _card_base_pos != Vector2.ZERO else card_panel.position.x
			var tw := create_tween()
			for _i in range(5):
				tw.tween_property(card_panel, "position:x", origin_x + 14, 0.04).set_trans(Tween.TRANS_SINE)
				tw.tween_property(card_panel, "position:x", origin_x - 14, 0.04).set_trans(Tween.TRANS_SINE)
			tw.tween_property(card_panel, "position:x", origin_x, 0.04)
			tw.tween_property(card_panel, "scale", Vector2(0.97, 0.97), 0.1)
			tw.tween_property(card_panel, "scale", Vector2(1.0, 1.0), 0.15)


func show_milestone_popup(title_text: String, desc_text: String) -> void:
	## Milestone intégré : forêt pulse doré + texte dans la carte (pas de popup séparé).
	# Forêt : pulse ambré 3 fois (milestone = moment magique)
	if biome_art_layer and is_instance_valid(biome_art_layer):
		var gold_tint := Color(1.4, 1.1, 0.6)
		var tw_forest := create_tween()
		for _i in range(3):
			tw_forest.tween_property(biome_art_layer, "modulate", gold_tint, 0.2).set_trans(Tween.TRANS_SINE)
			tw_forest.tween_property(biome_art_layer, "modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_SINE)
	# Texte dans la carte (speaker = titre milestone, corps = desc)
	if card_speaker and is_instance_valid(card_speaker):
		card_speaker.text = title_text
		var amber: Color = MerlinVisual.CRT_PALETTE.get("amber_bright", Color(0.85, 0.65, 0.13))
		card_speaker.add_theme_color_override("font_color", amber)
		card_speaker.visible = true
	if card_text and is_instance_valid(card_text):
		var amber: Color = MerlinVisual.CRT_PALETTE.get("amber_bright", Color(0.85, 0.65, 0.13))
		var bbcode := "[color=#%s]✦ %s[/color]" % [amber.to_html(false), desc_text]
		card_text.text = bbcode
		card_text.modulate.a = 1.0



func show_life_delta(delta: int) -> void:
	## Dramatic life change: screen flash, camera shake, zoom bar, smooth tween, BIG number.
	if delta == 0:
		return

	var is_damage: bool = delta < 0
	var color: Color = MerlinVisual.CRT_PALETTE.danger if is_damage else MerlinVisual.CRT_PALETTE.success

	# --- Stage 1: Screen flash (red for damage, green for heal) ---
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(color.r, color.g, color.b, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 30
	add_child(flash)
	var tw_flash := create_tween()
	tw_flash.tween_property(flash, "color:a", 0.25 if is_damage else 0.15, 0.08)
	tw_flash.tween_property(flash, "color:a", 0.0, 0.15)
	tw_flash.tween_callback(flash.queue_free)

	# --- Stage 2: Camera shake (damage only) ---
	if is_damage and main_vbox and is_instance_valid(main_vbox):
		var base_pos := main_vbox.position
		var shake_tw := create_tween()
		for i in range(4):
			var intensity: float = 4.0 * (1.0 - float(i) / 4.0)
			shake_tw.tween_property(main_vbox, "position:x", base_pos.x + intensity, 0.035)
			shake_tw.tween_property(main_vbox, "position:y", base_pos.y - intensity * 0.5, 0.035)
			shake_tw.tween_property(main_vbox, "position:x", base_pos.x - intensity, 0.035)
			shake_tw.tween_property(main_vbox, "position:y", base_pos.y + intensity * 0.5, 0.035)
		shake_tw.tween_property(main_vbox, "position", base_pos, 0.04)

	# --- Stage 3: Zoom life bar (elastic scale 1.0 -> 1.6 -> 1.0) ---
	if life_panel and is_instance_valid(life_panel):
		life_panel.pivot_offset = life_panel.size * 0.5
		var tw_zoom := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw_zoom.tween_property(life_panel, "scale", Vector2(1.6, 1.6), 0.2)
		tw_zoom.tween_property(life_panel, "scale", Vector2(1.0, 1.0), 0.4)

	# --- Stage 4: Smooth bar value tween ---
	if _life_bar and is_instance_valid(_life_bar):
		var old_val: float = _life_bar.value
		var new_val: float = clampf(old_val + float(delta), 0.0, float(MerlinConstants.LIFE_ESSENCE_MAX))
		var tw_bar := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw_bar.tween_property(_life_bar, "value", new_val, 0.5)

	# --- Stage 5: BIG floating number (48px, bounce scale, rises 80px) ---
	var label := Label.new()
	label.text = "+%d" % delta if delta > 0 else "%d" % delta
	if title_font:
		label.add_theme_font_override("font", title_font)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 25

	# Position near the life bar
	if life_panel and is_instance_valid(life_panel):
		var bar_global := life_panel.global_position
		label.position = Vector2(bar_global.x + life_panel.size.x * 0.5 - 30, bar_global.y - 10)
	else:
		label.position = Vector2(size.x * 0.5 - 40, size.y * 0.15)

	label.pivot_offset = Vector2(30, 24)
	label.scale = Vector2(0.3, 0.3)
	add_child(label)

	var tw_num := create_tween()
	tw_num.tween_property(label, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_num.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)
	tw_num.tween_property(label, "position:y", label.position.y - 80.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw_num.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tw_num.tween_callback(label.queue_free)


var _merlin_overlay: Control = null

func show_merlin_thinking_overlay() -> void:
	## Show "Merlin reflechit..." overlay when LLM takes extra time.
	if _merlin_overlay and is_instance_valid(_merlin_overlay):
		_merlin_overlay.visible = true
		_merlin_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	_merlin_overlay = Control.new()
	_merlin_overlay.name = "MerlinThinkingOverlay"
	_merlin_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_merlin_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_merlin_overlay.z_index = 20
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var p: Color = MerlinVisual.CRT_PALETTE.bg_panel
	bg.color = Color(p.r, p.g, p.b, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_merlin_overlay.add_child(bg)
	var lbl := Label.new()
	lbl.text = "Merlin reflechit..."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	if title_font:
		lbl.add_theme_font_override("font", title_font)
	_merlin_overlay.add_child(lbl)
	add_child(_merlin_overlay)
	_merlin_overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_merlin_overlay, "modulate:a", 1.0, 0.4)


func hide_merlin_thinking_overlay() -> void:
	if not _merlin_overlay or not is_instance_valid(_merlin_overlay):
		return
	var tw := create_tween()
	tw.tween_property(_merlin_overlay, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		if _merlin_overlay and is_instance_valid(_merlin_overlay):
			_merlin_overlay.visible = false
			_merlin_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)


# ═══════════════════════════════════════════════════════════════════════════════
# DIALOGUE MERLIN (P3.16)
# ═══════════════════════════════════════════════════════════════════════════════

const DIALOGUE_PRESETS: Array[String] = [
	"Qui es-tu vraiment, Merlin ?",
	"Que me conseilles-tu ?",
	"Parle-moi de cet endroit.",
	"Journal des Vies",
]
const JOURNAL_PRESET_INDEX := 3  # Index of the journal action in DIALOGUE_PRESETS

func _on_dialogue_btn_pressed() -> void:
	if _is_dialogue_open:
		return
	SFXManager.play("card_draw")
	_show_dialogue_popup()


func _show_dialogue_popup() -> void:
	## Modal popup: 3 preset questions + free text LineEdit.
	if _dialogue_popup and is_instance_valid(_dialogue_popup):
		_dialogue_popup.queue_free()

	_is_dialogue_open = true
	_dialogue_popup = Control.new()
	_dialogue_popup.name = "DialoguePopup"
	_dialogue_popup.z_index = 30
	_dialogue_popup.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Dim background
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shadow_c: Color = MerlinVisual.CRT_PALETTE.shadow
	dim.color = Color(shadow_c.r, shadow_c.g, shadow_c.b, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_dialogue_popup()
	)
	_dialogue_popup.add_child(dim)

	# Panel
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var bg_dark: Color = MerlinVisual.CRT_PALETTE.get("bg_dark", Color(0.05, 0.05, 0.08))
	style.bg_color = Color(bg_dark.r, bg_dark.g, bg_dark.b, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	var amber: Color = MerlinVisual.CRT_PALETTE.get("amber_bright", Color(0.85, 0.65, 0.13))
	style.border_color = Color(amber.r, amber.g, amber.b, 0.4)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(340, 0)
	var vp_size := get_viewport_rect().size
	panel.position = Vector2((vp_size.x - 340) * 0.5, vp_size.y * 0.25)
	_dialogue_popup.add_child(panel)

	# VBox content
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Parler a Merlin"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font:
		title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", amber)
	vbox.add_child(title)

	# Preset buttons
	for i in range(DIALOGUE_PRESETS.size()):
		var btn := Button.new()
		btn.text = DIALOGUE_PRESETS[i]
		btn.custom_minimum_size = Vector2(300, 36)
		MerlinVisual.apply_celtic_option_theme(btn, MerlinVisual.CRT_PALETTE.get("phosphor", Color(0.20, 1.00, 0.40)))
		btn.pressed.connect(_on_dialogue_preset_chosen.bind(i))
		btn.mouse_entered.connect(func(): SFXManager.play("hover"))
		vbox.add_child(btn)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	# Free text input
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	vbox.add_child(input_row)

	var line_edit := LineEdit.new()
	line_edit.name = "FreeTextInput"
	line_edit.placeholder_text = "Ecris ta question..."
	line_edit.custom_minimum_size = Vector2(240, 32)
	if body_font:
		line_edit.add_theme_font_override("font", body_font)
	line_edit.add_theme_font_size_override("font_size", 14)
	line_edit.text_submitted.connect(_on_dialogue_free_text_submitted)
	input_row.add_child(line_edit)

	var send_btn := Button.new()
	send_btn.text = ">"
	send_btn.custom_minimum_size = Vector2(48, 48)
	MerlinVisual.apply_button_theme(send_btn)
	send_btn.pressed.connect(func():
		var text: String = line_edit.text.strip_edges()
		if text.length() > 0:
			_on_dialogue_free_text_submitted(text)
	)
	input_row.add_child(send_btn)

	add_child(_dialogue_popup)

	# Fade in
	_dialogue_popup.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_dialogue_popup, "modulate:a", 1.0, 0.2)

	# Focus the text input
	line_edit.grab_focus()


func _close_dialogue_popup() -> void:
	_is_dialogue_open = false
	if _dialogue_popup and is_instance_valid(_dialogue_popup):
		var tw := create_tween()
		tw.tween_property(_dialogue_popup, "modulate:a", 0.0, 0.15)
		tw.tween_callback(_dialogue_popup.queue_free)


func _on_dialogue_preset_chosen(index: int) -> void:
	if index < 0 or index >= DIALOGUE_PRESETS.size():
		return
	_close_dialogue_popup()
	SFXManager.play("card_draw")
	# Journal action — special handling (P3.20.3)
	if index == JOURNAL_PRESET_INDEX:
		journal_requested.emit()
		return
	var question: String = DIALOGUE_PRESETS[index]
	merlin_dialogue_requested.emit(question)


func _on_dialogue_free_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	_close_dialogue_popup()
	SFXManager.play("card_draw")
	merlin_dialogue_requested.emit(text.strip_edges())


func show_merlin_dialogue_response(text: String) -> void:
	## Display Merlin's response in the dialogue bubble.
	if _dialogue_bubble and is_instance_valid(_dialogue_bubble):
		_dialogue_bubble.show_message(text, 6.0)




func hide_what_if_labels() -> void:
	## Clear all what-if labels (called on new card display).
	for lbl in _what_if_labels:
		if lbl and is_instance_valid(lbl):
			lbl.visible = false
			lbl.text = ""


func show_reveal_effects(options: Array, target_index: int) -> void:
	## Show hidden effects on option buttons as temporary overlay labels.
	## target_index = -1 → reveal all, 0/1/2 → reveal specific option.
	var reveal_color: Color = MerlinVisual.CRT_PALETTE.get("ogham_gold", Color(0.85, 0.75, 0.4))
	for i in range(mini(options.size(), 3)):
		if target_index >= 0 and i != target_index:
			continue
		var opt: Dictionary = options[i] if i < options.size() else {}
		var effects: Array = opt.get("effects", [])
		if effects.is_empty():
			continue
		# Build compact effect summary
		var parts: Array[String] = []
		for eff in effects:
			var eff_dict: Dictionary = eff if eff is Dictionary else {}
			var etype: String = str(eff_dict.get("type", ""))
			var amount: int = int(eff_dict.get("amount", eff_dict.get("intensity", 0)))
			if etype == "SHIFT_ASPECT":
				var asp: String = str(eff_dict.get("aspect", "?"))
				parts.append("%s %+d" % [asp.left(4), amount])
			elif etype == "ADD_SOUFFLE" or etype == "SOUFFLE":
				parts.append("Souffle %+d" % amount)
			elif etype == "ADD_KARMA" or etype == "KARMA":
				parts.append("Karma %+d" % amount)
			elif etype == "DAMAGE_LIFE":
				parts.append("Vie -%d" % absi(amount))
			elif etype == "HEAL_LIFE":
				parts.append("Vie +%d" % absi(amount))
			else:
				parts.append(etype.to_lower())
		if parts.is_empty():
			continue
		var summary: String = " | ".join(parts)
		# Display on the what-if label (reuse existing labels)
		if i < _what_if_labels.size():
			var lbl: Label = _what_if_labels[i]
			if lbl and is_instance_valid(lbl):
				lbl.text = summary
				lbl.add_theme_color_override("font_color", reveal_color)
				lbl.visible = true
				# Auto-hide after 4 seconds
				var tw := create_tween()
				tw.tween_interval(4.0)
				tw.tween_callback(func():
					if lbl and is_instance_valid(lbl):
						lbl.visible = false
						lbl.text = "")


func show_journal_popup(run_summaries: Array[Dictionary]) -> void:
	## P3.20.3: Display a visual journal of past lives as a scrollable popup.
	if run_summaries.is_empty():
		return

	var popup := ColorRect.new()
	popup.name = "JournalPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.color = Color(MerlinVisual.CRT_PALETTE.bg_deep.r, MerlinVisual.CRT_PALETTE.bg_deep.g, MerlinVisual.CRT_PALETTE.bg_deep.b, 0.92)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(popup)

	# Title
	var title := Label.new()
	title.text = "Journal des Vies"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 30.0
	title.offset_left = -200.0
	title.offset_right = 200.0
	var title_font_res: Font = MerlinVisual.get_font("title")
	if title_font_res:
		title.add_theme_font_override("font", title_font_res)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	popup.add_child(title)

	# Scroll container for entries
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 70.0
	scroll.offset_bottom = -60.0
	scroll.offset_left = 40.0
	scroll.offset_right = -40.0
	popup.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var body_font_res: Font = MerlinVisual.get_font("body")
	var entry_color: Color = MerlinVisual.CRT_PALETTE.phosphor
	var dim_color: Color = MerlinVisual.CRT_PALETTE.phosphor_dim

	for i in range(run_summaries.size()):
		var run: Dictionary = run_summaries[i]
		var entry := RichTextLabel.new()
		entry.bbcode_enabled = true
		entry.fit_content = true
		entry.scroll_active = false
		if body_font_res:
			entry.add_theme_font_override("normal_font", body_font_res)
		entry.add_theme_font_size_override("normal_font_size", 13)
		entry.add_theme_color_override("default_color", entry_color)
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var ending: String = str(run.get("ending", "inconnu"))
		var cards: int = int(run.get("cards_played", 0))
		var dom: String = str(run.get("dominant_aspect", ""))
		var style: String = str(run.get("player_style", ""))
		var life: int = int(run.get("life_final", 0))
		var events: String = str(run.get("notable_events", ""))

		var text := "[b]Vie %d[/b] -- %s\n" % [i + 1, ending]
		if cards > 0:
			text += "Cartes: %d | " % cards
		if not dom.is_empty():
			text += "Aspect: %s | " % dom
		if not style.is_empty():
			text += "Style: %s | " % style
		if life > 0:
			text += "Vie: %d" % life
		if not events.is_empty():
			text += "\n%s" % events
		entry.text = text
		vbox.add_child(entry)

		# Separator
		if i < run_summaries.size() - 1:
			var sep := HSeparator.new()
			sep.add_theme_color_override("separator", dim_color)
			vbox.add_child(sep)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Fermer"
	close_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close_btn.offset_bottom = -20.0
	close_btn.offset_top = -50.0
	close_btn.offset_left = -60.0
	close_btn.offset_right = 60.0
	if title_font_res:
		close_btn.add_theme_font_override("font", title_font_res)
	close_btn.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SIZE)
	close_btn.custom_minimum_size = Vector2(120, 48)
	MerlinVisual.apply_button_theme(close_btn)
	popup.add_child(close_btn)

	# Fade in
	popup.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(popup, "modulate:a", 1.0, 0.3)

	# Close handler
	close_btn.pressed.connect(func():
		var tw_out := create_tween()
		tw_out.tween_property(popup, "modulate:a", 0.0, 0.2)
		tw_out.tween_callback(popup.queue_free)
	)


# ═══════════════════════════════════════════════════════════════════════════════
# TYPOLOGY UI — Timer Urgence + Badge + Event feedback
# ═══════════════════════════════════════════════════════════════════════════════

var _typology_timer_bar: ProgressBar = null
var _typology_badge: Label = null
var _typology_timer_max: float = 10.0


func show_typology_timer(total_seconds: float) -> void:
	_typology_timer_max = total_seconds
	if _typology_timer_bar == null or not is_instance_valid(_typology_timer_bar):
		_typology_timer_bar = ProgressBar.new()
		_typology_timer_bar.custom_minimum_size = Vector2(120.0, 14.0)
		_typology_timer_bar.min_value = 0.0
		_typology_timer_bar.max_value = total_seconds
		_typology_timer_bar.value = total_seconds
		_typology_timer_bar.show_percentage = false
		_typology_timer_bar.modulate = MerlinVisual.CRT_PALETTE.warning  ## BUG-09 fix: palette ref
		if is_instance_valid(_top_status_bar):
			_top_status_bar.add_child(_typology_timer_bar)
	_typology_timer_bar.max_value = total_seconds
	_typology_timer_bar.value = total_seconds
	_typology_timer_bar.visible = true


func update_typology_timer(remaining: float) -> void:
	if _typology_timer_bar and is_instance_valid(_typology_timer_bar):
		_typology_timer_bar.value = maxf(remaining, 0.0)
		# Flash rouge dans les 3 dernières secondes
		var alpha: float = 1.0 if remaining > 3.0 else 0.6 + 0.4 * sin(remaining * 6.0)
		var warn: Color = MerlinVisual.CRT_PALETTE.warning  ## BUG-09 fix
		warn.a = alpha
		_typology_timer_bar.modulate = warn


func hide_typology_timer() -> void:
	if _typology_timer_bar and is_instance_valid(_typology_timer_bar):
		_typology_timer_bar.visible = false


func show_typology_badge(typology: String) -> void:
	if typology == "classique":
		hide_typology_badge()
		return
	var tdata: Dictionary = MerlinConstants.RUN_TYPOLOGIES.get(typology, {})
	var icon: String = str(tdata.get("icon", ""))
	var name_str: String = str(tdata.get("name", typology))
	if _typology_badge == null or not is_instance_valid(_typology_badge):
		_typology_badge = Label.new()
		_typology_badge.add_theme_font_size_override("font_size", 11)
		_typology_badge.modulate = MerlinVisual.CRT_PALETTE.amber  ## BUG-09 fix: palette ref
		if is_instance_valid(_top_status_bar):
			_top_status_bar.add_child(_typology_badge)
	_typology_badge.text = "%s %s" % [icon, name_str]
	_typology_badge.visible = true


func hide_typology_badge() -> void:
	if _typology_badge and is_instance_valid(_typology_badge):
		_typology_badge.visible = false


func show_typology_event(event: String) -> void:
	## Feedback visuel rapide pour crit/fumble Parieur.
	var label := Label.new()
	var vs: Vector2 = get_viewport_rect().size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(200.0, 40.0)
	label.position = Vector2((vs.x - 200.0) / 2.0, vs.y * 0.35)
	label.add_theme_font_size_override("font_size", 20)
	if event == "critique":
		label.text = "CRITIQUE !"
		label.modulate = MerlinVisual.CRT_PALETTE.success  ## BUG-09 fix: palette ref
	else:
		label.text = "FUMBLE..."
		label.modulate = MerlinVisual.CRT_PALETTE.danger  ## BUG-09 fix: palette ref
	add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 0.0, 1.2)
	tw.tween_callback(label.queue_free)


var _pause_overlay: Control = null


func show_pause_menu() -> void:
	## Display a CRT-styled pause overlay with Resume/Quit buttons.
	if _pause_overlay and is_instance_valid(_pause_overlay):
		_pause_overlay.visible = true
		return

	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Process mode: always so it works while paused
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -120.0
	vbox.offset_right = 120.0
	vbox.offset_top = -80.0
	vbox.offset_bottom = 80.0
	vbox.add_theme_constant_override("separation", 16)
	_pause_overlay.add_child(vbox)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = "PAUSE"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pause_font: Font = MerlinVisual.get_font("title")
	if pause_font:
		title_lbl.add_theme_font_override("font", pause_font)
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.get("amber", Color(1.0, 0.75, 0.0)))
	vbox.add_child(title_lbl)

	# Resume button
	var btn_resume := Button.new()
	btn_resume.text = "Reprendre"
	btn_resume.process_mode = Node.PROCESS_MODE_ALWAYS
	@warning_ignore("static_called_on_instance")
	MerlinVisual.apply_button_theme(btn_resume)
	btn_resume.pressed.connect(func():
		pause_requested.emit())
	vbox.add_child(btn_resume)

	# Quit button
	var btn_quit := Button.new()
	btn_quit.text = "Quitter la Partie"
	btn_quit.process_mode = Node.PROCESS_MODE_ALWAYS
	@warning_ignore("static_called_on_instance")
	MerlinVisual.apply_button_theme(btn_quit)
	btn_quit.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn"))
	vbox.add_child(btn_quit)


func hide_pause_menu() -> void:
	## Hide the pause overlay.
	if _pause_overlay and is_instance_valid(_pause_overlay):
		_pause_overlay.visible = false


func _exit_tree() -> void:
	## Cleanup to prevent orphaned nodes and dangling signals.
	_typewriter_abort = true
	if _thinking_timer and is_instance_valid(_thinking_timer):
		_thinking_timer.stop()
