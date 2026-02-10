extends Control

## TestBrainPool — Interactive Quest Showcase (Phase 32)
## RPG-style: hidden effects, D20 dice rolls, travel animations,
## RAG context management, brain monitoring. Narrator-only generation.

# ═══════════════════════════════════════════════════════════════════════════════
# PRELOADS (explicit to avoid parse-order issues with class_name)
# ═══════════════════════════════════════════════════════════════════════════════
const _MiniGameRegistry = preload("res://scripts/minigames/minigame_registry.gd")
const _MiniGameBase = preload("res://scripts/minigames/minigame_base.gd")

# ═══════════════════════════════════════════════════════════════════════════════
# PALETTE & CONSTANTS
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
	"celtic_gold": Color(0.68, 0.55, 0.32),
	"green": Color(0.25, 0.55, 0.25),
	"red": Color(0.65, 0.20, 0.15),
	"blue": Color(0.25, 0.40, 0.65),
	"fog": Color(0.90, 0.88, 0.84, 0.95),
}

const QUESTS := [
	{"title": "La Brume de Broceliande", "subs": ["Traverser la lisiere", "Trouver le dolmen", "Apaiser le gardien"]},
	{"title": "Le Chant des Pierres", "subs": ["Ecouter les menhirs", "Dechiffrer l'ogham", "Accomplir le rituel"]},
	{"title": "L'Ombre du Sanglier", "subs": ["Suivre les traces", "Affronter la bete", "Reveler le secret"]},
]

const FALLBACK_CARDS := [
	{"text": "Un brouillard epais descend sur le sentier. Des murmures s'elevent des fougeres.", "left": "Reculer", "center": "Attendre", "right": "Avancer"},
	{"text": "Une voix chante depuis les pierres dressees. Le vent porte des mots oublies.", "left": "Fuir", "center": "Ecouter", "right": "Repondre"},
	{"text": "Le sanglier blanc apparait entre les chenes. Ses yeux brillent d'un eclat ancien.", "left": "Se cacher", "center": "Observer", "right": "Le suivre"},
	{"text": "La riviere chante un air que tu connais. Ses eaux refletent un monde inverse.", "left": "Boire", "center": "Contempler", "right": "Traverser"},
	{"text": "Le cercle de pierres pulse d'energie. La terre vibre sous tes pieds nus.", "left": "Quitter", "center": "Mediter", "right": "Toucher"},
	{"text": "Un corbeau se pose sur ton epaule. Il murmure ton nom dans une langue ancienne.", "left": "Le chasser", "center": "Ecouter", "right": "Le nourrir"},
	{"text": "La lune perce les nuages. Chaque ombre dessine un ogham sur le sol.", "left": "Fermer les yeux", "center": "Lire les signes", "right": "Danser"},
]

const CHOICE_LABELS_FALLBACK := [
	["Prudence", "Sagesse", "Audace"],
	["Reculer", "Reflechir", "Foncer"],
	["Esquiver", "Equilibrer", "Embrasser"],
	["Contourner", "Negocier", "Affronter"],
	["Observer", "Invoquer", "Agir"],
]

# Dice outcome reaction templates — {choice} is replaced by label
const REACTIONS_CRIT_SUCCESS := [
	"Un eclat dore illumine la foret. Ton choix de {choice} depasse toute esperance !",
	"Les esprits applaudissent. {choice} — un coup de maitre digne des anciens druides.",
	"La magie repond a ton audace. {choice} s'accomplit avec une puissance inattendue !",
	"Les oghams chantent en chœur. {choice} resonne comme un echo parfait dans Broceliande.",
]
const REACTIONS_SUCCESS := [
	"Ton instinct ne te trompe pas. {choice} porte ses fruits dans la brume.",
	"Le sentier s'eclaircit. {choice} etait le bon choix, les esprits approuvent.",
	"Un souffle chaud traverse la clairiere. {choice} apaise les forces en presence.",
	"Les feuilles bruissent d'approbation. {choice} — Merlin hoche la tete en silence.",
]
const REACTIONS_FAILURE := [
	"La brume s'epaissit. {choice} n'a pas l'effet escompte... les ombres grondent.",
	"Un frisson parcourt l'air. {choice} se retourne contre toi, le prix est lourd.",
	"Les pierres tremblent. {choice} etait risque, et la foret n'a pas pardonne.",
	"Le vent siffle une plainte. {choice} — Merlin detourne le regard, pensif.",
]
const REACTIONS_CRIT_FAILURE := [
	"Un craquement sinistre dechire le silence ! {choice} provoque la colere des anciens.",
	"Les tenebres se referment. {choice} etait une erreur fatale... tout bascule.",
	"La terre tremble sous tes pieds. {choice} — meme Merlin semble inquiet.",
	"Un corbeau croasse trois fois. {choice} attire le malheur des profondeurs de l'Annwn.",
]

const CARDS_PER_QUEST := 7
const DICE_ROLL_DURATION := 2.2
const DICE_CYCLE_MS := 70

# Aspect range & game over thresholds
const ASPECT_MIN := -3
const ASPECT_MAX := 3
const ASPECT_GAME_OVER := 3   # abs(aspect) >= 3 triggers chute
const ASPECT_DANGER := 2       # abs(aspect) >= 2 shows warning

# Resource caps
const SOUFFLE_MAX := 5
const KARMA_MIN := -10
const KARMA_MAX := 10
const BLESSINGS_MAX := 2

# Difficulty Class per choice direction (like D&D)
const DC_LEFT := 6       # Cautious — easy check
const DC_CENTER := 10    # Balanced — medium check (costs Souffle)
const DC_RIGHT := 14     # Bold — hard check (big reward/risk)

# RAG context file — prevents prompt bloat
const CONTEXT_FILE := "user://brain_pool_context.txt"
const CONTEXT_MAX_ENTRIES := 5

# Loading animation symbols
const LOADING_SYMBOLS := ["◎", "◉", "●", "◐", "◑", "◒", "◓"]

# Buffer system — continuous pre-generation
const BUFFER_SIZE := 3
const LOADING_FLAVOR := [
	"Les esprits tissent le destin...",
	"Les runes s'assemblent dans la brume...",
	"Merlin consulte les etoiles...",
	"Le chaudron bouillonne doucement...",
	"Les oghams murmurent vos prochains pas...",
	"La foret revele ses secrets...",
	"Le vent porte les voix anciennes...",
	"Les pierres dressees resonnent...",
]

# Travel flavor texts
const TRAVEL_TEXTS := [
	"Le chemin serpente entre les chenes...",
	"La brume se leve sur le sentier...",
	"Les arbres murmurent ton passage...",
	"Le vent porte l'echo des druides...",
	"Les pierres guident tes pas...",
	"La foret s'ouvre devant toi...",
]

# BBCode colors
const C_OK := "[color=#408040]"
const C_FAIL := "[color=#a03020]"
const C_WARN := "[color=#907030]"
const C_INFO := "[color=#4a6a8a]"
const C_ACCENT := "[color=#94702a]"
const C_NARR := "[color=#2a6a8a]"
const C_GM := "[color=#8a5a2a]"
const C_CRIT := "[color=#c8a020]"
const C_END := "[/color]"


# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

enum Phase { IDLE, GENERATING, CARD_SHOWN, DICE_ROLLING, EFFECTS_REVEALED, TRAVELING, QUEST_END }

var _phase: int = Phase.IDLE
var _merlin_ai: Node = null
var _title_font: Font
var _body_font: Font

# Quest
var _quest: Dictionary = {}
var _sub_idx: int = 0
var _cards_played: int = 0

# Aspects & Resources
var _aspects := {"Corps": 0, "Ame": 0, "Monde": 0}
var _souffle: int = 3
var _karma: int = 0
var _blessings: int = 0
var _is_critical_choice: bool = false
var _critical_used: bool = false  # Max 1 per quest (except karma-forced)

# Quest outcome history (for adaptive difficulty)
var _quest_history: Array[Dictionary] = []

# Flux system — hidden energy balance (Phase 35)
var _flux := {"terre": 50, "esprit": 30, "lien": 40}
var _minigames_won: int = 0
var _oghams_used: int = 0
var _awen_spent: int = 0

# Talent tracking (Phase 35)
var _souffle_max: int = SOUFFLE_MAX
var _shield_corps_used: bool = false
var _shield_monde_used: bool = false
var _free_center_remaining: int = 0

# Card buffer (continuous pre-generation)
var _current_card: Dictionary = {}
var _card_buffer: Array[Dictionary] = []
var _quest_active: bool = false
var _is_refilling: bool = false

# Timings
var _narrator_ms: int = 0

# Dice roll (choice resolution)
var _dice_rolling := false
var _dice_timer: float = 0.0
var _dice_last_cycle: float = 0.0
var _dice_target: int = 0
var _pending_choice: String = ""
var _pending_fx: Dictionary = {}
var _dice_dc: int = 10

# RAG context history
var _context_history: Array[String] = []

# Loading animation
var _is_loading: bool = false
var _loading_anim_idx: int = 0
var _loading_anim_timer: float = 0.0
var _loading_flavor_idx: int = 0
var _loading_flavor_timer: float = 0.0

# Monitor
var _monitor_timer: float = 0.0

# UI refs
var _quest_title: Label
var _quest_sub: Label
var _quest_progress: Label
var _card_panel: PanelContainer
var _card_text: RichTextLabel
var _narrator_badge: Label
var _choice_row: HBoxContainer
var _choice_left: Button
var _choice_center: Button
var _choice_right: Button
var _dice_area: VBoxContainer
var _dice_display: Label
var _dice_dc_label: Label
var _dice_result_label: Label
var _effects_rtl: RichTextLabel
var _start_overlay: VBoxContainer
var _start_btn: Button
var _loading_label: Label
var _travel_overlay: ColorRect
var _travel_label: Label
var _aspect_bars: Dictionary = {}
var _souffle_dots: Label
var _brain_log: RichTextLabel
var _brain_bar_fills: Array[ColorRect] = []
var _brain_bar_labels: Array[Label] = []
var _monitor_summary: RichTextLabel


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_fonts()
	_build_ui()
	_update_monitor()
	_update_aspect_display()
	_load_context_history()


func _process(delta: float) -> void:
	# Monitor refresh
	_monitor_timer += delta
	if _monitor_timer >= 0.5:
		_monitor_timer = 0.0
		_update_monitor()

	# Loading animation — cycling symbols + flavor texts
	if _is_loading:
		_loading_anim_timer += delta
		if _loading_anim_timer >= 0.2:
			_loading_anim_timer = 0.0
			_loading_anim_idx = (_loading_anim_idx + 1) % LOADING_SYMBOLS.size()
		_loading_flavor_timer += delta
		if _loading_flavor_timer >= 3.0:
			_loading_flavor_timer = 0.0
			_loading_flavor_idx = (_loading_flavor_idx + 1) % LOADING_FLAVOR.size()
		if _loading_label:
			var sym: String = LOADING_SYMBOLS[_loading_anim_idx]
			var flavor: String = LOADING_FLAVOR[_loading_flavor_idx]
			_loading_label.text = "%s  %s  %s" % [sym, flavor, sym]

	# Dice roll animation — decelerating cycle + bounce at landing
	if _dice_rolling:
		_dice_timer += delta
		if _dice_timer >= DICE_ROLL_DURATION:
			_dice_rolling = false
			if _dice_display:
				_dice_display.text = str(_dice_target)
				_dice_display.rotation = 0.0
				# Outcome color glow
				var glow_color := PALETTE.celtic_gold
				if _dice_target == 1:
					glow_color = PALETTE.red
				elif _dice_target >= _dice_dc:
					glow_color = PALETTE.green if _dice_target < 20 else PALETTE.celtic_gold
				else:
					glow_color = PALETTE.red
				_dice_display.add_theme_color_override("font_color", glow_color)
				# Bounce animation at landing
				_dice_display.pivot_offset = _dice_display.size / 2.0
				var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(_dice_display, "scale", Vector2(1.3, 1.3), 0.15)
				tw.tween_property(_dice_display, "scale", Vector2(1.0, 1.0), 0.25)
			_on_choice_dice_settled()
		else:
			# Decelerating cycle speed (fast at start, slow near end)
			var progress: float = _dice_timer / DICE_ROLL_DURATION
			var cycle_speed: float = lerpf(DICE_CYCLE_MS * 0.001, DICE_CYCLE_MS * 0.005, progress * progress)
			_dice_last_cycle += delta
			if _dice_last_cycle >= cycle_speed:
				_dice_last_cycle = 0.0
				if _dice_display:
					_dice_display.text = str(randi_range(1, 20))
					# Subtle rotation wobble during roll
					_dice_display.rotation = randf_range(-0.08, 0.08) * (1.0 - progress)


func _load_fonts() -> void:
	_title_font = _try_font("res://resources/fonts/morris/MorrisRomanBlack.otf")
	if _title_font == null:
		_title_font = _try_font("res://resources/fonts/morris/MorrisRomanBlack.ttf")
	_body_font = _try_font("res://resources/fonts/morris/MorrisRomanBlackAlt.otf")
	if _body_font == null:
		_body_font = _try_font("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf")
	if _body_font == null:
		_body_font = _title_font


func _try_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var f: Resource = load(path)
	return f if f is Font else null


# ═══════════════════════════════════════════════════════════════════════════════
# UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Parchment BG
	var bg := ColorRect.new()
	bg.color = PALETTE.paper
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 10)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	_build_quest_bar(root)

	var content := HSplitContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.split_offset = 600
	root.add_child(content)

	_build_game_area(content)
	_build_brain_panel(content)

	# Travel overlay (full screen fog between cards)
	_travel_overlay = ColorRect.new()
	_travel_overlay.color = PALETTE.fog
	_travel_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_travel_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_travel_overlay.visible = false
	_travel_overlay.modulate.a = 0.0
	add_child(_travel_overlay)

	_travel_label = Label.new()
	_travel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_travel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_travel_label.set_anchors_preset(Control.PRESET_CENTER)
	if _title_font:
		_travel_label.add_theme_font_override("font", _title_font)
	_travel_label.add_theme_font_size_override("font_size", 28)
	_travel_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	_travel_label.text = ""
	_travel_overlay.add_child(_travel_label)


func _build_quest_bar(parent: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	parent.add_child(bar)

	# Back button
	var back := _btn("Retour", func(): get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn"))
	back.custom_minimum_size = Vector2(80, 28)
	bar.add_child(back)

	# Quest title
	_quest_title = Label.new()
	_quest_title.text = "Atelier du Druide"
	if _title_font:
		_quest_title.add_theme_font_override("font", _title_font)
	_quest_title.add_theme_font_size_override("font_size", 28)
	_quest_title.add_theme_color_override("font_color", PALETTE.ink)
	bar.add_child(_quest_title)

	# Sub-quest
	_quest_sub = Label.new()
	_quest_sub.text = ""
	_quest_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _body_font:
		_quest_sub.add_theme_font_override("font", _body_font)
	_quest_sub.add_theme_font_size_override("font_size", 16)
	_quest_sub.add_theme_color_override("font_color", PALETTE.ink_soft)
	bar.add_child(_quest_sub)

	# Progress
	_quest_progress = Label.new()
	_quest_progress.text = ""
	_quest_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quest_progress.custom_minimum_size = Vector2(80, 0)
	if _body_font:
		_quest_progress.add_theme_font_override("font", _body_font)
	_quest_progress.add_theme_font_size_override("font_size", 16)
	_quest_progress.add_theme_color_override("font_color", PALETTE.accent)
	bar.add_child(_quest_progress)

	# Separator
	var sep := ColorRect.new()
	sep.color = PALETTE.line
	sep.custom_minimum_size = Vector2(0, 1)
	parent.add_child(sep)

	# Aspects row
	var aspects_row := HBoxContainer.new()
	aspects_row.add_theme_constant_override("separation", 20)
	aspects_row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(aspects_row)

	for aspect_key in ["Corps", "Ame", "Monde"]:
		var aspect_hb := HBoxContainer.new()
		aspect_hb.add_theme_constant_override("separation", 4)
		aspects_row.add_child(aspect_hb)

		var lbl := Label.new()
		lbl.text = aspect_key
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", PALETTE.ink_soft)
		lbl.custom_minimum_size = Vector2(42, 0)
		aspect_hb.add_child(lbl)

		var bar_bg := ColorRect.new()
		bar_bg.color = PALETTE.paper_dark
		bar_bg.custom_minimum_size = Vector2(100, 12)
		aspect_hb.add_child(bar_bg)

		var bar_fill := ColorRect.new()
		bar_fill.color = PALETTE.green
		bar_fill.size = Vector2(50, 12)
		bar_bg.add_child(bar_fill)

		var val_lbl := Label.new()
		val_lbl.text = "0"
		val_lbl.add_theme_font_size_override("font_size", 13)
		val_lbl.add_theme_color_override("font_color", PALETTE.ink)
		val_lbl.custom_minimum_size = Vector2(24, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		aspect_hb.add_child(val_lbl)

		_aspect_bars[aspect_key] = {"bg": bar_bg, "fill": bar_fill, "val": val_lbl}

	# Souffle
	_souffle_dots = Label.new()
	_souffle_dots.text = "Souffle: ◆◆◆"
	_souffle_dots.add_theme_font_size_override("font_size", 14)
	_souffle_dots.add_theme_color_override("font_color", PALETTE.celtic_gold)
	aspects_row.add_child(_souffle_dots)


func _build_game_area(parent: HSplitContainer) -> void:
	var game := VBoxContainer.new()
	game.add_theme_constant_override("separation", 6)
	game.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(game)

	# Card panel
	_card_panel = PanelContainer.new()
	_card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = PALETTE.paper_warm
	card_style.border_color = PALETTE.ink_faded
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(6)
	card_style.shadow_color = PALETTE.shadow
	card_style.shadow_size = 12
	card_style.shadow_offset = Vector2(0, 4)
	card_style.set_content_margin_all(20)
	_card_panel.add_theme_stylebox_override("panel", card_style)
	game.add_child(_card_panel)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 8)
	_card_panel.add_child(card_vbox)

	# Card text (narrative)
	_card_text = RichTextLabel.new()
	_card_text.bbcode_enabled = true
	_card_text.fit_content = true
	_card_text.scroll_active = false
	_card_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _body_font:
		_card_text.add_theme_font_override("normal_font", _body_font)
	_card_text.add_theme_font_size_override("normal_font_size", 18)
	_card_text.add_theme_color_override("default_color", PALETTE.ink)
	card_vbox.add_child(_card_text)

	# Narrator badge
	_narrator_badge = Label.new()
	_narrator_badge.text = ""
	_narrator_badge.add_theme_font_size_override("font_size", 11)
	_narrator_badge.add_theme_color_override("font_color", PALETTE.blue)
	card_vbox.add_child(_narrator_badge)

	# Choice buttons row (hidden during dice roll)
	_choice_row = HBoxContainer.new()
	_choice_row.add_theme_constant_override("separation", 8)
	_choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_child(_choice_row)

	# Left: cautious (DC 6)
	_choice_left = _btn("Gauche", func(): _on_choice("left"))
	_choice_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_left.custom_minimum_size.y = 38
	_choice_left.visible = false
	_choice_row.add_child(_choice_left)

	# Center: balanced (DC 10, costs Souffle)
	_choice_center = _btn("Centre", func(): _on_choice("center"))
	_choice_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_center.custom_minimum_size.y = 38
	_choice_center.visible = false
	_choice_row.add_child(_choice_center)

	# Right: bold (DC 14)
	_choice_right = _btn("Droite", func(): _on_choice("right"))
	_choice_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_right.custom_minimum_size.y = 38
	_choice_right.visible = false
	_choice_row.add_child(_choice_right)

	# Dice area (hidden, shown during choice resolution)
	_dice_area = VBoxContainer.new()
	_dice_area.alignment = BoxContainer.ALIGNMENT_CENTER
	_dice_area.add_theme_constant_override("separation", 4)
	_dice_area.visible = false
	card_vbox.add_child(_dice_area)

	_dice_display = Label.new()
	_dice_display.text = "?"
	_dice_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _title_font:
		_dice_display.add_theme_font_override("font", _title_font)
	_dice_display.add_theme_font_size_override("font_size", 56)
	_dice_display.add_theme_color_override("font_color", PALETTE.ink)
	_dice_area.add_child(_dice_display)

	_dice_dc_label = Label.new()
	_dice_dc_label.text = ""
	_dice_dc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _body_font:
		_dice_dc_label.add_theme_font_override("font", _body_font)
	_dice_dc_label.add_theme_font_size_override("font_size", 14)
	_dice_dc_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	_dice_area.add_child(_dice_dc_label)

	_dice_result_label = Label.new()
	_dice_result_label.text = ""
	_dice_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _body_font:
		_dice_result_label.add_theme_font_override("font", _body_font)
	_dice_result_label.add_theme_font_size_override("font_size", 18)
	_dice_result_label.add_theme_color_override("font_color", PALETTE.accent)
	_dice_area.add_child(_dice_result_label)

	# Effects (revealed after dice settles)
	_effects_rtl = RichTextLabel.new()
	_effects_rtl.bbcode_enabled = true
	_effects_rtl.fit_content = true
	_effects_rtl.scroll_active = false
	_effects_rtl.add_theme_font_size_override("normal_font_size", 14)
	_effects_rtl.add_theme_color_override("default_color", PALETTE.ink_soft)
	_effects_rtl.custom_minimum_size = Vector2(0, 20)
	card_vbox.add_child(_effects_rtl)

	# Start overlay (shown initially, hidden after quest starts)
	_start_overlay = VBoxContainer.new()
	_start_overlay.alignment = BoxContainer.ALIGNMENT_CENTER
	_start_overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_start_overlay.add_theme_constant_override("separation", 16)
	card_vbox.add_child(_start_overlay)

	_start_btn = _btn("Commencer la Quete", _start_quest)
	_start_btn.custom_minimum_size = Vector2(220, 44)
	if _title_font:
		_start_btn.add_theme_font_override("font", _title_font)
	_start_btn.add_theme_font_size_override("font_size", 22)
	_start_overlay.add_child(_start_btn)

	_loading_label = Label.new()
	_loading_label.text = ""
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _body_font:
		_loading_label.add_theme_font_override("font", _body_font)
	_loading_label.add_theme_font_size_override("font_size", 16)
	_loading_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	_start_overlay.add_child(_loading_label)


func _build_brain_panel(parent: HSplitContainer) -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var title := Label.new()
	title.text = "Cerveaux"
	if _body_font:
		title.add_theme_font_override("font", _body_font)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", PALETTE.accent)
	panel.add_child(title)

	# Brain bars
	var brain_names := ["Narrateur", "Maitre du Jeu", "Ouvrier A", "Ouvrier B"]
	for i in range(4):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		panel.add_child(row)

		var lbl := Label.new()
		lbl.text = brain_names[i]
		lbl.custom_minimum_size = Vector2(95, 0)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", PALETTE.ink_soft)
		row.add_child(lbl)
		_brain_bar_labels.append(lbl)

		var bar_bg := ColorRect.new()
		bar_bg.color = PALETTE.paper_dark
		bar_bg.custom_minimum_size = Vector2(80, 12)
		bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar_bg)

		var fill := ColorRect.new()
		fill.color = PALETTE.green
		fill.size = Vector2(0, 12)
		bar_bg.add_child(fill)
		_brain_bar_fills.append(fill)

	# Monitor summary
	_monitor_summary = RichTextLabel.new()
	_monitor_summary.bbcode_enabled = true
	_monitor_summary.fit_content = true
	_monitor_summary.scroll_active = false
	_monitor_summary.custom_minimum_size = Vector2(0, 40)
	_monitor_summary.add_theme_font_size_override("normal_font_size", 11)
	_monitor_summary.add_theme_color_override("default_color", PALETTE.ink_soft)
	panel.add_child(_monitor_summary)

	# Separator
	var sep := ColorRect.new()
	sep.color = PALETTE.line
	sep.custom_minimum_size = Vector2(0, 1)
	panel.add_child(sep)

	# Activity log
	var log_title := Label.new()
	log_title.text = "Activite"
	if _body_font:
		log_title.add_theme_font_override("font", _body_font)
	log_title.add_theme_font_size_override("font_size", 18)
	log_title.add_theme_color_override("font_color", PALETTE.accent)
	panel.add_child(log_title)

	var log_scroll := ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(log_scroll)

	_brain_log = RichTextLabel.new()
	_brain_log.bbcode_enabled = true
	_brain_log.fit_content = true
	_brain_log.scroll_active = false
	_brain_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brain_log.selection_enabled = true
	_brain_log.add_theme_font_size_override("normal_font_size", 11)
	_brain_log.add_theme_color_override("default_color", PALETTE.ink_soft)
	_brain_log.text = "%sEn attente du lancement...%s" % [C_INFO, C_END]
	log_scroll.add_child(_brain_log)


# ═══════════════════════════════════════════════════════════════════════════════
# UI HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _btn(label: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _body_font:
		b.add_theme_font_override("font", _body_font)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", PALETTE.ink)

	var s := StyleBoxFlat.new()
	s.bg_color = PALETTE.paper_warm
	s.border_color = PALETTE.ink_faded
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", s)

	var h := s.duplicate()
	h.bg_color = PALETTE.accent_glow
	h.border_color = PALETTE.accent
	b.add_theme_stylebox_override("hover", h)

	var p := s.duplicate()
	p.bg_color = Color(PALETTE.accent.r, PALETTE.accent.g, PALETTE.accent.b, 0.15)
	b.add_theme_stylebox_override("pressed", p)

	# SFX on hover and press
	b.mouse_entered.connect(func():
		var sfx := get_node_or_null("/root/SFXManager")
		if sfx and sfx.has_method("play"):
			sfx.play("hover")
		# Subtle scale up
		b.pivot_offset = b.size / 2.0
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2(1.05, 1.05), 0.1)
	)
	b.mouse_exited.connect(func():
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2(1.0, 1.0), 0.1)
	)
	b.pressed.connect(func():
		var sfx := get_node_or_null("/root/SFXManager")
		if sfx and sfx.has_method("play"):
			sfx.play("click")
		# Press shrink
		b.pivot_offset = b.size / 2.0
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2(0.95, 0.95), 0.05)
		tw.tween_property(b, "scale", Vector2(1.0, 1.0), 0.1)
	)
	b.pressed.connect(callback)
	return b


func _log_brain(msg: String) -> void:
	if not _brain_log:
		return
	var t := Time.get_time_dict_from_system()
	var ts := "%02d:%02d:%02d" % [t.hour, t.minute, t.second]
	_brain_log.text += "\n[%s] %s" % [ts, msg]


# ═══════════════════════════════════════════════════════════════════════════════
# QUEST FLOW
# ═══════════════════════════════════════════════════════════════════════════════

func _start_quest() -> void:
	_quest = QUESTS[randi() % QUESTS.size()].duplicate(true)
	_sub_idx = 0
	_cards_played = 0
	_aspects = {"Corps": 0, "Ame": 0, "Monde": 0}
	_souffle = 3
	_karma = 0
	_blessings = 0
	_is_critical_choice = false
	_critical_used = false
	_quest_history.clear()
	_flux = MerlinConstants.FLUX_START.duplicate()
	_minigames_won = 0
	_oghams_used = 0
	_awen_spent = 0
	_souffle_max = SOUFFLE_MAX
	_shield_corps_used = false
	_shield_monde_used = false
	_free_center_remaining = 0
	_apply_talent_bonuses()
	_card_buffer.clear()
	_quest_active = true
	_is_refilling = false
	_context_history.clear()
	_save_context_history()

	if _quest_title: _quest_title.text = str(_quest.get("title", "?"))
	if _quest_sub: _quest_sub.text = str(_quest.get("subs", ["?"])[0])
	if _quest_progress: _quest_progress.text = "0/%d" % CARDS_PER_QUEST
	_update_aspect_display()

	if _brain_log: _brain_log.text = "%sQuete lancee: %s%s" % [C_ACCENT, _quest.get("title", "?"), C_END]
	_log_brain("%sSous-quete: %s%s" % [C_INFO, _quest.get("subs", ["?"])[0], C_END])

	# Force dual-brain mode (Narrator + Game Master)
	var ai := _get_merlin_ai()
	if ai != null and ai.has_method("set_brain_count"):
		ai.set_brain_count(2)
		_log_brain("%sDual mode force: Narrateur + Maitre du Jeu%s" % [C_OK, C_END])

	# Show loading screen while filling initial buffer
	_phase = Phase.GENERATING
	_is_loading = true
	_loading_flavor_idx = randi() % LOADING_FLAVOR.size()
	_loading_flavor_timer = 0.0
	if _start_overlay: _start_overlay.visible = true
	if _start_btn: _start_btn.visible = false
	if _loading_label:
		_loading_label.visible = true
		_loading_label.text = LOADING_FLAVOR[_loading_flavor_idx]
	if _card_text: _card_text.text = ""
	if _narrator_badge: _narrator_badge.text = ""
	if _effects_rtl: _effects_rtl.text = ""
	_choice_row.visible = false
	_dice_area.visible = false

	_log_brain("%sRemplissage buffer initial (%d cartes)...%s" % [C_INFO, BUFFER_SIZE, C_END])

	# Generate first card (blocking — we need it to start)
	var first_card := await _generate_card()
	_log_brain("%sBuffer 1/%d pret%s" % [C_OK, BUFFER_SIZE, C_END])

	# Stop loading, show first card
	_is_loading = false
	if _loading_label: _loading_label.visible = false
	if _start_overlay: _start_overlay.visible = false
	if _start_btn: _start_btn.visible = true
	_display_card(first_card)

	# Start continuous background refill (fills remaining slots)
	_continuous_refill()


func _advance_quest() -> void:
	_cards_played += 1
	if _quest_progress:
		_quest_progress.text = "%d/%d" % [_cards_played, CARDS_PER_QUEST]

	# Sub-quest progression
	var subs_count: int = maxi(_quest.get("subs", []).size(), 1)
	var sub_threshold: int = maxi(1, int(CARDS_PER_QUEST / float(subs_count)))
	var new_sub: int = mini(int(_cards_played / float(sub_threshold)), subs_count - 1) if sub_threshold > 0 else 0
	if new_sub != _sub_idx:
		_sub_idx = new_sub
		var subs_arr: Array = _quest.get("subs", [])
		if _sub_idx < subs_arr.size():
			if _quest_sub: _quest_sub.text = str(subs_arr[_sub_idx])
			_log_brain("%sSous-quete: %s%s" % [C_INFO, subs_arr[_sub_idx], C_END])
			# Blessing on sub-quest completion
			_blessings = mini(_blessings + 1, BLESSINGS_MAX)
			_log_brain("%sBenediction gagnee (sous-quete) ! Total: %d%s" % [C_CRIT, _blessings, C_END])

	# Check end conditions
	if _cards_played >= CARDS_PER_QUEST:
		_show_quest_end(true)
		return

	for aspect_key in _aspects:
		if abs(_aspects[aspect_key]) >= ASPECT_GAME_OVER:
			_show_quest_end(false)
			return

	if _souffle <= 0:
		_show_quest_end(false)
		return

	# Continue: travel animation, then next card
	_show_travel_then_next_card()


func _show_quest_end(victory: bool) -> void:
	_phase = Phase.QUEST_END
	_quest_active = false
	_card_buffer.clear()
	_choice_row.visible = false
	_dice_area.visible = false

	if victory:
		var karma_txt := ""
		if _karma > 0:
			karma_txt = "  Karma: +%d (audacieux)" % _karma
		elif _karma < 0:
			karma_txt = "  Karma: %d (prudent)" % _karma
		if _card_text:
			_card_text.text = "%sQuete accomplie !%s\n\nTu as traverse les epreuves de \"%s\" avec sagesse.\n\nCorps=%d  Ame=%d  Monde=%d  Souffle=%d%s" % [
				C_OK, C_END, _quest.get("title", "?"), _aspects.Corps, _aspects.Ame, _aspects.Monde, _souffle, karma_txt
			]
		_log_brain("%sVictoire ! Quete terminee en %d cartes%s" % [C_OK, _cards_played, C_END])
	else:
		var reason := "Souffle epuise" if _souffle <= 0 else "Aspect extreme"
		if _card_text:
			_card_text.text = "%sChute...%s\n\n%s.\n\nCorps=%d  Ame=%d  Monde=%d  Souffle=%d" % [
				C_FAIL, C_END, reason, _aspects.Corps, _aspects.Ame, _aspects.Monde, _souffle
			]
		_log_brain("%sChute: %s%s" % [C_FAIL, reason, C_END])

	if _narrator_badge: _narrator_badge.text = ""
	if _effects_rtl: _effects_rtl.text = ""

	# Calculate and apply run rewards (Phase 35)
	var all_balanced: bool = (_aspects.Corps == 0 and _aspects.Ame == 0 and _aspects.Monde == 0)
	var run_data := {
		"victory": victory,
		"flux": _flux.duplicate(),
		"all_balanced": all_balanced,
		"bond": 50,  # Placeholder — will come from bestiole state
		"minigames_won": _minigames_won,
		"oghams_used": _oghams_used,
		"awen_spent": _awen_spent,
		"score": _cards_played * (20 if victory else 10),
		"ending_title": _quest.get("title", "") if not victory else "Victoire",
	}
	var store := get_node_or_null("/root/MerlinStore")
	var rewards_text := ""
	if store and store.has_method("calculate_run_rewards"):
		var rewards: Dictionary = store.calculate_run_rewards(run_data)
		store.apply_run_rewards(rewards)
		# Build summary text
		var ess_parts: Array[String] = []
		for elem in rewards.get("essence", {}):
			var val: int = int(rewards.essence[elem])
			if val > 0:
				ess_parts.append("%s +%d" % [elem, val])
		if ess_parts.size() > 0:
			rewards_text = "\n\n%sEssences gagnees:%s %s" % [C_CRIT, C_END, ", ".join(ess_parts)]
		var frags: int = int(rewards.get("fragments", 0))
		var liens: int = int(rewards.get("liens", 0))
		var gloire: int = int(rewards.get("gloire", 0))
		if frags > 0 or liens > 0 or gloire > 0:
			rewards_text += "\n%sFragments:%s %d | %sLiens:%s %d | %sGloire:%s %d" % [
				C_ACCENT, C_END, frags, C_ACCENT, C_END, liens, C_ACCENT, C_END, gloire
			]
		_log_brain("%sRecompenses appliquees: %d essences, %d frags, %d liens, %d gloire%s" % [
			C_CRIT, ess_parts.size(), frags, liens, gloire, C_END
		])

	# Check bestiole evolution (Phase 35)
	if store and store.has_method("check_bestiole_evolution"):
		var evo_result: Dictionary = store.check_bestiole_evolution()
		if evo_result.get("can_evolve", false):
			store.evolve_bestiole()
			var new_stage: int = int(evo_result.get("next_stage", 2))
			var stage_names := {2: "Compagnon", 3: "Gardien"}
			rewards_text += "\n\n%sBestiole evolue: %s !%s" % [C_CRIT, stage_names.get(new_stage, "?"), C_END]
			_log_brain("%sBestiole evolution: stade %d !%s" % [C_CRIT, new_stage, C_END])

	# Append rewards to end screen text
	if _card_text and rewards_text != "":
		_card_text.text += rewards_text

	# Show restart button
	if _start_overlay: _start_overlay.visible = true
	if _start_btn: _start_btn.text = "Nouvelle Quete"
	if _loading_label: _loading_label.text = ""


# ═══════════════════════════════════════════════════════════════════════════════
# CARD GENERATION (Narrator-only — fast, no GM overhead)
# ═══════════════════════════════════════════════════════════════════════════════

func _generate_and_show_card() -> void:
	_is_loading = true
	if _loading_label:
		_loading_label.text = "Les cerveaux travaillent..."
		_loading_label.visible = true
	if _start_overlay: _start_overlay.visible = true
	if _card_text: _card_text.text = ""
	if _narrator_badge: _narrator_badge.text = ""
	if _effects_rtl: _effects_rtl.text = ""
	_choice_row.visible = false
	_dice_area.visible = false

	var card := await _generate_card()

	_is_loading = false
	if _loading_label: _loading_label.visible = false
	if _start_overlay: _start_overlay.visible = false
	_display_card(card)


func _generate_card() -> Dictionary:
	var ai := _get_merlin_ai()
	if ai == null or not (ai.get("is_ready") == true):
		return _fallback_card()

	# Build compact context using RAG history
	var subs_arr: Array = _quest.get("subs", [])
	var current_sub: String = str(subs_arr[_sub_idx]) if _sub_idx < subs_arr.size() else "?"
	var base_context := "Quete: %s. Etape: %s. Jour %d/%d." % [
		_quest.get("title", "?"), current_sub, _cards_played + 1, CARDS_PER_QUEST
	]
	var state_context := "Corps=%d Ame=%d Monde=%d Souffle=%d Karma=%d." % [
		_aspects.get("Corps", 0), _aspects.get("Ame", 0), _aspects.get("Monde", 0), _souffle, _karma
	]
	var rag_summary := _get_context_summary()
	var flux_context := _get_flux_context_for_llm()
	var context := base_context + " " + state_context
	if flux_context != "":
		context += " " + flux_context
	if rag_summary != "":
		context += " " + rag_summary

	var narrator_system := "Tu es Merlin. Ecris un scenario immersif de 2-3 phrases."
	var gm_system := "Tu es le Maitre du Jeu. Genere 3 choix contextuels adaptes au scenario. Reponds UNIQUEMENT en JSON."
	var gm_input := "Scenario: %s Etat: Corps=%d Ame=%d Monde=%d Souffle=%d. Genere 3 choix + effets + type mini-jeu." % [
		context, _aspects.get("Corps", 0), _aspects.get("Ame", 0), _aspects.get("Monde", 0), _souffle
	]

	var t0 := Time.get_ticks_msec()

	# Try parallel dual-brain generation (Narrator + GM simultaneously)
	if ai.has_method("generate_parallel"):
		_log_brain("%sNarrateur%s + %sMaitre du Jeu%s en parallele..." % [C_NARR, C_END, C_GM, C_END])
		var grammar_path := "res://data/ai/gamemaster_choices.gbnf"
		var grammar_text := ""
		if FileAccess.file_exists(grammar_path):
			var f := FileAccess.open(grammar_path, FileAccess.READ)
			if f:
				grammar_text = f.get_as_text()

		var result: Dictionary = await ai.generate_parallel(
			narrator_system, context,
			gm_system, gm_input,
			grammar_text,
			{"max_tokens": 150},  # narrator overrides
			{"max_tokens": 200},  # gm overrides
		)
		_narrator_ms = Time.get_ticks_msec() - t0
		var parallel_tag: String = " (parallele)" if result.get("parallel", false) else " (sequentiel)"
		_log_brain("%sDual-brain%s — %dms%s" % [C_OK, C_END, _narrator_ms, parallel_tag])

		var narrative_text := _extract_narrative(result.get("narrative", {}))
		var gm_data := _parse_gm_choices(result.get("structured", {}))

		if narrative_text.length() > 5:
			return _build_card_dual(narrative_text, gm_data)

	# Fallback: narrator-only (single brain or no generate_parallel)
	elif ai.has_method("generate_narrative"):
		_log_brain("%sNarrateur%s seul (fallback)..." % [C_NARR, C_END])
		var narr_result: Dictionary = await ai.generate_narrative(narrator_system, context, {"max_tokens": 100})
		_narrator_ms = Time.get_ticks_msec() - t0
		var narrative_text := _extract_narrative(narr_result)
		_log_brain("%sNarrateur%s — %dms" % [C_NARR, C_END, _narrator_ms])
		if narrative_text.length() > 5:
			return _build_card_dual(narrative_text, {})

	elif ai.has_method("generate_with_system"):
		_log_brain("%sNarrateur%s (legacy)..." % [C_NARR, C_END])
		var narr_result: Dictionary = await ai.generate_with_system(narrator_system, context, {"max_tokens": 100, "temperature": 0.7})
		_narrator_ms = Time.get_ticks_msec() - t0
		var narrative_text := _extract_narrative(narr_result)
		_log_brain("%sNarrateur%s — %dms (legacy)" % [C_NARR, C_END, _narrator_ms])
		if narrative_text.length() > 5:
			return _build_card_dual(narrative_text, {})

	return _fallback_card()


func _extract_narrative(result: Dictionary) -> String:
	var text := ""
	if result.has("text"):
		text = str(result.text).strip_edges()
	elif result.has("error"):
		_log_brain("%sErreur Narrateur: %s%s" % [C_FAIL, str(result.error), C_END])
		return ""
	# Clean LLM tokens
	for token in ["<|im_end|>", "<|im_start|>", "<|endoftext|>"]:
		var idx := text.find(token)
		if idx >= 0:
			text = text.substr(0, idx)
	return text.strip_edges()


func _parse_gm_choices(result: Dictionary) -> Dictionary:
	if result.has("error"):
		_log_brain("%sErreur GM: %s%s" % [C_FAIL, str(result.error), C_END])
		return {}
	if not result.has("text"):
		return {}

	var raw: String = str(result.text).strip_edges()
	_log_brain("%sGM brut:%s %s" % [C_GM, C_END, raw.substr(0, 80)])

	# Try JSON parse
	var json := JSON.new()
	if json.parse(raw) != OK:
		_log_brain("%sGM JSON invalide%s" % [C_WARN, C_END])
		return {}

	var data: Variant = json.data
	if not data is Dictionary:
		return {}

	# Validate expected structure
	var gm: Dictionary = data as Dictionary
	if not gm.has("labels") or not gm.has("options"):
		_log_brain("%sGM structure incomplete%s" % [C_WARN, C_END])
		return {}

	var labels: Variant = gm.get("labels")
	if labels is Array and labels.size() >= 3:
		_log_brain("%sGM labels:%s %s | %s | %s" % [C_GM, C_END, str(labels[0]), str(labels[1]), str(labels[2])])

	return gm


func _build_card_dual(narrative: String, gm_data: Dictionary) -> Dictionary:
	var text := narrative
	if text.length() < 5:
		text = str(FALLBACK_CARDS[randi() % FALLBACK_CARDS.size()].get("text", "..."))

	# Labels: prefer GM contextual labels, fallback to generic
	var labels: Array = []
	var gm_labels: Variant = gm_data.get("labels", [])
	if gm_labels is Array and gm_labels.size() >= 3:
		labels = [str(gm_labels[0]), str(gm_labels[1]), str(gm_labels[2])]
	else:
		labels = CHOICE_LABELS_FALLBACK[randi() % CHOICE_LABELS_FALLBACK.size()]

	# Effects: prefer GM structured effects, fallback to heuristic
	var effects := _generate_balanced_effects()
	var gm_options: Variant = gm_data.get("options", [])
	if gm_options is Array and gm_options.size() >= 3:
		var gm_fx := _convert_gm_effects(gm_options)
		if not gm_fx.is_empty():
			effects = gm_fx
			_log_brain("%sGM effets utilises%s" % [C_GM, C_END])

	# Minigame hint from GM
	var minigame_hint: String = str(gm_data.get("minigame", ""))

	return {
		"text": text,
		"left_label": labels[0],
		"center_label": labels[1],
		"right_label": labels[2],
		"effects": effects,
		"narrator_ms": _narrator_ms,
		"minigame_hint": minigame_hint,
	}


func _convert_gm_effects(options: Array) -> Dictionary:
	# Convert GM JSON effects to our format {left: {aspect: val}, center: {...}, right: {...}}
	var dirs := ["left", "center", "right"]
	var result := {}
	for i in range(mini(options.size(), 3)):
		var opt: Variant = options[i]
		if not opt is Dictionary:
			return {}
		var fx := {}
		# Cost
		if opt.has("cost"):
			fx["cost"] = int(opt.cost)
		# Effects array
		var efx: Variant = opt.get("effects", [])
		if efx is Array:
			for e in efx:
				if not e is Dictionary:
					continue
				var etype: String = str(e.get("type", ""))
				match etype:
					"SHIFT_ASPECT":
						var aspect: String = str(e.get("aspect", ""))
						var dir: String = str(e.get("direction", "up"))
						if _aspects.has(aspect):
							fx[aspect] = 1 if dir == "up" else -1
					"ADD_KARMA":
						pass  # Karma handled by choice+outcome, not effects
					"USE_SOUFFLE":
						fx["cost"] = fx.get("cost", 0) + absi(int(e.get("amount", 1)))
					"ADD_SOUFFLE":
						fx["cost"] = fx.get("cost", 0) - absi(int(e.get("amount", 1)))
		result[dirs[i]] = fx
	return result


func _generate_balanced_effects() -> Dictionary:
	# Intelligent heuristic effects based on current game state
	var aspects_keys := ["Corps", "Ame", "Monde"]

	# Find weakest and strongest aspects for balancing
	var weakest := "Corps"
	var strongest := "Corps"
	for key in aspects_keys:
		if _aspects[key] < _aspects[weakest]:
			weakest = key
		if _aspects[key] > _aspects[strongest]:
			strongest = key

	# Pick a random third aspect
	var other: String = aspects_keys[randi() % 3]
	while other == weakest and aspects_keys.size() > 1:
		other = aspects_keys[randi() % 3]

	# Effect magnitude scales with distance from 0 — wider range allows bigger swings
	var magnitude: int = 1
	if abs(_aspects[strongest]) >= ASPECT_DANGER or abs(_aspects[weakest]) >= ASPECT_DANGER:
		magnitude = 2  # Bigger swings when danger zone is near (more dramatic)

	# Left (cautious): small safe push toward balance
	# Center (balanced): costs Souffle but helps weakest
	# Right (bold): big swing — risk of destabilizing
	return {
		"left": {other: [-1, 1][randi() % 2]},
		"center": {weakest: magnitude, "cost": 1},
		"right": {strongest: -magnitude, weakest: magnitude},
	}


func _fallback_card() -> Dictionary:
	var fb: Dictionary = FALLBACK_CARDS[randi() % FALLBACK_CARDS.size()]
	_narrator_ms = 0
	_log_brain("%sFallback carte (LLM indisponible)%s" % [C_WARN, C_END])
	return {
		"text": str(fb.get("text", "...")),
		"left_label": str(fb.get("left", "Gauche")),
		"center_label": str(fb.get("center", "Centre")),
		"right_label": str(fb.get("right", "Droite")),
		"effects": _generate_balanced_effects(),
		"narrator_ms": 0,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# CARD DISPLAY (effects HIDDEN — RPG style)
# ═══════════════════════════════════════════════════════════════════════════════

func _display_card(card: Dictionary) -> void:
	_current_card = card
	_phase = Phase.CARD_SHOWN

	if not _card_panel:
		return

	# Reset critical choice style from previous card
	if _card_panel.has_theme_stylebox_override("panel"):
		var orig_style := StyleBoxFlat.new()
		orig_style.bg_color = PALETTE.paper_warm
		orig_style.border_color = PALETTE.ink_faded
		orig_style.set_border_width_all(1)
		orig_style.set_corner_radius_all(6)
		orig_style.shadow_color = PALETTE.shadow
		orig_style.shadow_size = 12
		orig_style.shadow_offset = Vector2(0, 4)
		orig_style.set_content_margin_all(20)
		_card_panel.add_theme_stylebox_override("panel", orig_style)
	_card_panel.modulate = Color.WHITE

	# --- Critical choice detection ---
	_is_critical_choice = false
	if _cards_played >= 3 and not _critical_used:
		var trigger_critical := false
		# Force if karma extreme
		if abs(_karma) >= 5:
			trigger_critical = true
		# Force if 2+ aspects in danger zone
		var danger_count: int = 0
		for key in _aspects:
			if abs(_aspects[key]) >= ASPECT_DANGER:
				danger_count += 1
		if danger_count >= 2:
			trigger_critical = true
		# 15% random chance
		if not trigger_critical and randf() < 0.15:
			trigger_critical = true
		if trigger_critical:
			_is_critical_choice = true
			_critical_used = true
			_log_brain("%sChoix Critique !%s" % [C_CRIT, C_END])
			var sfx := get_node_or_null("/root/SFXManager")
			if sfx and sfx.has_method("play"):
				sfx.play("critical_alert")

	# SFX: card draw
	var card_sfx := get_node_or_null("/root/SFXManager")
	if card_sfx and card_sfx.has_method("play"):
		card_sfx.play("card_draw")

	# Animate card in (deparcheminement: scaleY 0->1 + fade)
	_card_panel.visible = true
	_card_panel.modulate.a = 0.0
	_card_panel.pivot_offset = Vector2(_card_panel.size.x / 2.0, 0)
	_card_panel.scale = Vector2(1.0, 0.0)
	var orig_x: float = _card_panel.position.x
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card_panel, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(_card_panel, "scale", Vector2(1.0, 1.0), 0.5)

	# Critical choice: golden pulsing border
	if _is_critical_choice:
		var panel_style: StyleBoxFlat = _card_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if panel_style:
			var crit_style := panel_style.duplicate() as StyleBoxFlat
			crit_style.border_color = PALETTE.celtic_gold
			crit_style.set_border_width_all(3)
			_card_panel.add_theme_stylebox_override("panel", crit_style)
		# Pulsing gold border animation
		var pulse_tw := create_tween().set_loops(0)
		pulse_tw.tween_property(_card_panel, "modulate", Color(1.0, 0.95, 0.8, 1.0), 0.6)
		pulse_tw.tween_property(_card_panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.6)

	# Card text
	if _card_text: _card_text.text = str(card.get("text", "..."))

	# Narrator badge
	var n_ms: int = int(card.get("narrator_ms", 0))
	if _narrator_badge:
		var badge_text := ("Narrateur — %dms" % n_ms) if n_ms > 0 else "Narrateur — fallback"
		if _is_critical_choice:
			badge_text += "  ✦ CHOIX CRITIQUE ✦"
		_narrator_badge.text = badge_text

	# Choice labels — NO effects shown (hidden until dice roll)
	if _choice_left: _choice_left.text = str(card.get("left_label", "Gauche"))
	if _choice_center: _choice_center.text = str(card.get("center_label", "Centre"))
	if _choice_right: _choice_right.text = str(card.get("right_label", "Droite"))

	# Show choices with cascade animation
	_choice_row.visible = true
	_dice_area.visible = false
	if _choice_left:
		_choice_left.visible = true
		_choice_left.disabled = false
		_choice_left.modulate.a = 0.0
	if _choice_center:
		_choice_center.visible = true
		_choice_center.disabled = false
		_choice_center.modulate.a = 0.0
	if _choice_right:
		_choice_right.visible = true
		_choice_right.disabled = false
		_choice_right.modulate.a = 0.0

	var tw2 := create_tween()
	tw2.tween_property(_choice_left, "modulate:a", 1.0, 0.2).set_delay(0.3)
	tw2.tween_property(_choice_center, "modulate:a", 1.0, 0.2).set_delay(0.1)
	tw2.tween_property(_choice_right, "modulate:a", 1.0, 0.2).set_delay(0.1)

	if _effects_rtl: _effects_rtl.text = ""

	# Buffer refill triggers automatically via _continuous_refill()


# ═══════════════════════════════════════════════════════════════════════════════
# CHOICE → DICE ROLL → EFFECTS (RPG resolution)
# ═══════════════════════════════════════════════════════════════════════════════

func _on_choice(direction: String) -> void:
	if _phase != Phase.CARD_SHOWN:
		return

	_phase = Phase.DICE_ROLLING
	_pending_choice = direction
	_pending_fx = _current_card.get("effects", {}).get(direction, {})
	_dice_dc = _get_dc_for_direction(direction)

	_log_brain("%sChoix: %s (DC %d)%s" % [C_ACCENT, direction, _dice_dc, C_END])

	# Update Flux based on choice direction (Phase 35)
	_update_flux(direction)

	# Decide: mini-game or standard dice roll
	var use_minigame: bool = false
	var minigame_chance: float = 0.7  # 70% base chance
	if _is_critical_choice:
		minigame_chance = 1.0  # 100% on critical choice
	if randf() < minigame_chance and _cards_played >= 1:
		use_minigame = true

	if use_minigame:
		_launch_minigame(direction)
	else:
		_launch_dice_roll()


func _launch_dice_roll() -> void:
	# Fade out choice buttons, show dice area
	var tw := create_tween()
	tw.tween_property(_choice_row, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		_choice_row.visible = false
		_choice_row.modulate.a = 1.0
		_dice_area.visible = true
		_dice_area.modulate.a = 0.0
		_dice_dc_label.text = "Difficulte: %d" % _dice_dc
		_dice_result_label.text = ""
		_dice_display.text = "?"
		_dice_display.add_theme_color_override("font_color", PALETTE.ink)
		# Start dice roll
		var tw2 := create_tween()
		tw2.tween_property(_dice_area, "modulate:a", 1.0, 0.3)
		tw2.tween_callback(_start_dice_roll)
	)


func _launch_minigame(direction: String) -> void:
	# Detect field from narrative text + GM hint
	var narrative: String = str(_current_card.get("text", ""))
	var gm_hint: String = str(_current_card.get("minigame_hint", ""))
	var field: String = _MiniGameRegistry.detect_field(narrative, gm_hint)

	# Difficulty based on DC + karma influence
	var base_diff: int = clampi(_dice_dc / 2, 1, 10)
	if _is_critical_choice:
		base_diff = mini(base_diff + 3, 10)

	# Ogham modifiers (placeholder — will be filled from bestiole skills)
	var modifiers := {}
	var ogham_bonus: int = _MiniGameRegistry.get_ogham_bonus("", field)
	if ogham_bonus > 0:
		modifiers["score_bonus"] = ogham_bonus

	_log_brain("%sMini-jeu:%s %s (diff %d)%s" % [C_INFO, C_END, field, base_diff, C_END])

	# Create mini-game
	var game = _MiniGameRegistry.create_minigame(field, base_diff, modifiers)
	if game == null:
		_log_brain("%sMini-jeu creation echouee — fallback de%s" % [C_WARN, C_END])
		_launch_dice_roll()
		return

	# Hide choice buttons
	_choice_row.visible = false

	# SFX
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_start")

	# Add mini-game overlay
	add_child(game)
	game.game_completed.connect(_on_minigame_completed)
	game.start()


func _on_minigame_completed(result: Dictionary) -> void:
	var score: int = int(result.get("score", 50))
	var elapsed: int = int(result.get("time_ms", 0))
	var mg_success: bool = bool(result.get("success", false))
	if mg_success:
		_minigames_won += 1

	# Convert score to D20
	_dice_target = _MiniGameBase.score_to_d20(score)
	_log_brain("%sMini-jeu termine:%s score=%d → D20=%d (%dms)" % [C_OK, C_END, score, _dice_target, elapsed])

	# Show dice confirmation with the converted result
	_dice_area.visible = true
	_dice_dc_label.text = "Difficulte: %d" % _dice_dc
	_dice_result_label.text = ""
	if _dice_display:
		_dice_display.text = str(_dice_target)
		var glow_color := PALETTE.celtic_gold
		if _dice_target == 1:
			glow_color = PALETTE.red
		elif _dice_target >= _dice_dc:
			glow_color = PALETTE.green if _dice_target < 20 else PALETTE.celtic_gold
		else:
			glow_color = PALETTE.red
		_dice_display.add_theme_color_override("font_color", glow_color)
		_dice_display.rotation = 0.0
		# Bounce animation
		_dice_display.pivot_offset = _dice_display.size / 2.0
		var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_dice_display, "scale", Vector2(1.3, 1.3), 0.15)
		tw.tween_property(_dice_display, "scale", Vector2(1.0, 1.0), 0.25)

	# Small delay for the player to see the D20 result, then settle
	await get_tree().create_timer(0.6).timeout
	_on_choice_dice_settled()


func _start_dice_roll() -> void:
	_dice_target = randi_range(1, 20)
	_dice_rolling = true
	_dice_timer = 0.0
	_dice_last_cycle = 0.0
	_log_brain("%sDe lance...%s" % [C_INFO, C_END])
	# SFX choreography: shake at start, roll at 0.3s
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("dice_shake")
		get_tree().create_timer(0.3).timeout.connect(func(): sfx.play("dice_roll"))


func _on_choice_dice_settled() -> void:
	var roll: int = _dice_target
	var dc: int = _dice_dc

	# SFX: dice lands
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("dice_land")

	# Determine outcome
	var outcome := ""
	var final_fx := {}

	if roll == 20:
		# Critical success
		outcome = "critical_success"
		final_fx = _apply_crit_success(_pending_fx)
		_dice_result_label.text = "Coup Critique !"
		_dice_result_label.add_theme_color_override("font_color", PALETTE.celtic_gold)
		_log_brain("%sCritique ! D20 = 20%s" % [C_CRIT, C_END])
	elif roll >= dc:
		# Success
		outcome = "success"
		final_fx = _pending_fx.duplicate()
		_dice_result_label.text = "Reussite ! (%d >= %d)" % [roll, dc]
		_dice_result_label.add_theme_color_override("font_color", PALETTE.green)
		_log_brain("%sReussite: %d >= DC %d%s" % [C_OK, roll, dc, C_END])
	elif roll > 1:
		# Failure
		outcome = "failure"
		final_fx = _apply_failure(_pending_fx)
		_dice_result_label.text = "Echec... (%d < %d)" % [roll, dc]
		_dice_result_label.add_theme_color_override("font_color", PALETTE.red)
		_log_brain("%sEchec: %d < DC %d%s" % [C_FAIL, roll, dc, C_END])
	else:
		# Critical failure (nat 1)
		outcome = "critical_failure"
		final_fx = _apply_crit_failure(_pending_fx)
		_dice_result_label.text = "Echec Critique !"
		_dice_result_label.add_theme_color_override("font_color", PALETTE.red)
		_log_brain("%sEchec Critique ! D20 = 1%s" % [C_FAIL, C_END])

	# Talent: feuillage_7 — Negative effects -30%
	var _t_store := get_node_or_null("/root/MerlinStore")
	if _t_store and _t_store.is_talent_active("feuillage_7"):
		for key in final_fx:
			if _aspects.has(key) and int(final_fx[key]) < 0:
				final_fx[key] = int(ceili(float(final_fx[key]) * 0.7))

	# Talent: feuillage_2 — Free center (no Souffle cost, 1/run)
	if _pending_choice == "center" and _free_center_remaining > 0 and final_fx.has("cost"):
		final_fx["cost"] = 0
		_free_center_remaining -= 1
		_log_brain("%sTalent: Centre gratuit utilise !%s" % [C_OK, C_END])

	# Apply effects to game state
	for key in final_fx:
		if key == "cost":
			_souffle = maxi(0, _souffle - int(final_fx[key]))
		elif _aspects.has(key):
			var old_val: int = _aspects[key]
			var new_val: int = clampi(old_val + int(final_fx[key]), ASPECT_MIN, ASPECT_MAX)

			# Talent shields (Phase 35)
			if key == "Corps" and new_val < old_val and not _shield_corps_used:
				if _t_store and _t_store.is_talent_active("racines_2"):
					new_val = old_val
					_shield_corps_used = true
					_log_brain("%sTalent: Endurance Naturelle protege Corps !%s" % [C_OK, C_END])
			if key == "Monde" and new_val > old_val and not _shield_monde_used:
				if _t_store and _t_store.is_talent_active("feuillage_1"):
					new_val = old_val
					_shield_monde_used = true
					_log_brain("%sTalent: Diplomatie Innee protege Monde !%s" % [C_OK, C_END])

			# Blessing absorbs game over
			if abs(new_val) >= ASPECT_GAME_OVER and _blessings > 0:
				_blessings -= 1
				new_val = ASPECT_DANGER * signi(new_val)
				_log_brain("%sBenediction consommee ! %s protege%s" % [C_CRIT, key, C_END])
			_aspects[key] = new_val

	# Karma update based on choice + outcome
	if outcome == "critical_success":
		_karma = clampi(_karma + 2, KARMA_MIN, KARMA_MAX)
		_blessings = mini(_blessings + 1, BLESSINGS_MAX)
		_souffle = mini(_souffle + 2, _souffle_max)
	elif outcome == "critical_failure":
		_karma = clampi(_karma - 2, KARMA_MIN, KARMA_MAX)
	elif outcome == "success":
		if _pending_choice == "right":
			_karma = clampi(_karma + 1, KARMA_MIN, KARMA_MAX)
		elif _pending_choice == "left":
			_karma = clampi(_karma - 1, KARMA_MIN, KARMA_MAX)
		_souffle = mini(_souffle + 1, _souffle_max)

	# Equilibrium bonus: if all aspects at 0, gain Souffle
	if _aspects.Corps == 0 and _aspects.Ame == 0 and _aspects.Monde == 0:
		var eq_bonus: int = 1
		var _ms := get_node_or_null("/root/MerlinStore")
		if _ms and _ms.is_talent_active("racines_5"):
			eq_bonus = 2
		_souffle = mini(_souffle + eq_bonus, _souffle_max)
		_log_brain("%sEquilibre parfait ! Souffle +%d%s" % [C_OK, eq_bonus, C_END])

	# Record quest history
	_quest_history.append({
		"card_idx": _cards_played,
		"choice": _pending_choice,
		"outcome": outcome,
		"aspects_after": _aspects.duplicate(),
	})

	_update_aspect_display()

	# Show effects with animation
	if _effects_rtl:
		_effects_rtl.text = _format_revealed_effects(outcome, final_fx)

	# Write to RAG context
	var choice_label := ""
	match _pending_choice:
		"left": choice_label = str(_current_card.get("left_label", "gauche"))
		"center": choice_label = str(_current_card.get("center_label", "centre"))
		"right": choice_label = str(_current_card.get("right_label", "droite"))
	_write_context_entry("Choix: %s (%s, D20=%d vs DC%d)" % [choice_label, outcome, roll, dc])

	# SFX outcome
	if sfx and sfx.has_method("play"):
		match outcome:
			"critical_success": sfx.play("dice_crit_success")
			"success": sfx.play("aspect_up")
			"failure": sfx.play("aspect_down")
			"critical_failure": sfx.play("dice_crit_fail")

	# --- Narrative reaction text ---
	var reaction_pool: Array = []
	match outcome:
		"critical_success": reaction_pool = REACTIONS_CRIT_SUCCESS
		"success": reaction_pool = REACTIONS_SUCCESS
		"failure": reaction_pool = REACTIONS_FAILURE
		"critical_failure": reaction_pool = REACTIONS_CRIT_FAILURE
	if reaction_pool.size() > 0 and _card_text:
		var raw: String = reaction_pool[randi() % reaction_pool.size()]
		var reaction_text: String = raw.replace("{choice}", choice_label)
		# Color based on outcome
		var reaction_color := C_OK if outcome.begins_with("success") or outcome == "critical_success" else C_FAIL
		_card_text.text = "%s%s%s" % [reaction_color, reaction_text, C_END]

	# --- Dice particles VFX ---
	if _dice_display:
		_spawn_dice_particles(outcome)

	# --- Card panel animation (shake on fail, pulse on success) ---
	if _card_panel:
		_animate_card_outcome(outcome)

	_phase = Phase.EFFECTS_REVEALED

	# Wait then advance (longer to read reaction text)
	await get_tree().create_timer(3.5).timeout
	_advance_quest()


func _get_dc_for_direction(direction: String) -> int:
	var base_dc: int = DC_CENTER
	match direction:
		"left": base_dc = DC_LEFT
		"center": base_dc = DC_CENTER
		"right": base_dc = DC_RIGHT

	# Adaptive difficulty from quest history
	var modifier: int = 0
	if _quest_history.size() >= 3:
		var last_3 := _quest_history.slice(-3)
		var consecutive_fails: int = 0
		var consecutive_wins: int = 0
		for entry in last_3:
			if entry.get("outcome", "") == "failure" or entry.get("outcome", "") == "critical_failure":
				consecutive_fails += 1
			elif entry.get("outcome", "") == "success" or entry.get("outcome", "") == "critical_success":
				consecutive_wins += 1
		if consecutive_fails >= 3:
			modifier = -4  # Pity mode
			_log_brain("%sMode indulgent actif (DC -4)%s" % [C_INFO, C_END])
			_souffle = mini(_souffle + 1, _souffle_max)
		elif consecutive_wins >= 3:
			modifier = 2  # Harder

	# Critical choice modifier (talent feuillage_4 reduces from +4 to +2)
	if _is_critical_choice:
		var crit_penalty: int = 4
		var _dc_store := get_node_or_null("/root/MerlinStore")
		if _dc_store and _dc_store.is_talent_active("feuillage_4"):
			crit_penalty = 2
		modifier += crit_penalty

	# Flux Lien (difficulty) modifier (Phase 35)
	var lien_val: int = int(_flux.get("lien", 40))
	if lien_val <= 30:
		modifier -= 2   # Calme: easier
	elif lien_val >= 70:
		modifier += 3   # Brutal: harder

	return clampi(base_dc + modifier, 2, 19)


# ═══════════════════════════════════════════════════════════════════════════════
# FLUX SYSTEM — Hidden Energy Balance (Phase 35)
# ═══════════════════════════════════════════════════════════════════════════════

func _update_flux(direction: String) -> void:
	var delta: Dictionary = MerlinConstants.FLUX_CHOICE_DELTA.get(direction, {})
	for axis in delta:
		_flux[axis] = clampi(int(_flux.get(axis, 50)) + int(delta[axis]),
			MerlinConstants.FLUX_MIN, MerlinConstants.FLUX_MAX)

	# Passive Aspect influence on Flux
	for aspect_name in _aspects:
		var offset_data: Dictionary = MerlinConstants.FLUX_ASPECT_OFFSET.get(aspect_name, {})
		if offset_data.is_empty():
			continue
		var flux_axis: String = str(offset_data.get("flux", ""))
		var aspect_val: int = _aspects[aspect_name]
		var offset: int = int(offset_data.get(aspect_val, 0))
		if offset != 0:
			# Apply fractional offset (divide by cards to prevent runaway)
			var scaled: int = clampi(int(offset / maxi(_cards_played, 3)), -5, 5)
			_flux[flux_axis] = clampi(int(_flux.get(flux_axis, 50)) + scaled,
				MerlinConstants.FLUX_MIN, MerlinConstants.FLUX_MAX)


func _get_flux_tier(axis: String) -> String:
	var val: int = int(_flux.get(axis, 50))
	var tiers: Dictionary = MerlinConstants.FLUX_TIERS.get(axis, {})
	for tier_name in tiers:
		var tier_data: Dictionary = tiers[tier_name]
		if val >= int(tier_data.get("min", 0)) and val <= int(tier_data.get("max", 100)):
			return tier_name
	return "neutre"


func _get_flux_context_for_llm() -> String:
	var terre_tier: String = _get_flux_tier("terre")
	var esprit_tier: String = _get_flux_tier("esprit")
	var lien_tier: String = _get_flux_tier("lien")

	var hints: Array[String] = []
	var terre_hint: String = str(MerlinConstants.FLUX_HINTS.get("terre", {}).get(terre_tier, ""))
	var esprit_hint: String = str(MerlinConstants.FLUX_HINTS.get("esprit", {}).get(esprit_tier, ""))
	var lien_hint: String = str(MerlinConstants.FLUX_HINTS.get("lien", {}).get(lien_tier, ""))
	if terre_hint != "":
		hints.append(terre_hint)
	if esprit_hint != "":
		hints.append(esprit_hint)
	if lien_hint != "":
		hints.append(lien_hint)

	return " ".join(hints) if hints.size() > 0 else ""


# ═══════════════════════════════════════════════════════════════════════════════
# TALENT BONUSES — Applied at start of each run (Phase 35)
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_talent_bonuses() -> void:
	var ms := get_node_or_null("/root/MerlinStore")
	if ms == null:
		return

	# racines_1: +1 Souffle at start
	if ms.is_talent_active("racines_1"):
		_souffle += 1
		_log_brain("%sTalent: Souffle Fortifie (+1 Souffle)%s" % [C_OK, C_END])

	# racines_3: +1 Blessing at start
	if ms.is_talent_active("racines_3"):
		_blessings += 1
		_log_brain("%sTalent: Peau de Chene (+1 Benediction)%s" % [C_OK, C_END])

	# racines_6: +2 Souffle max
	if ms.is_talent_active("racines_6"):
		_souffle_max += 2
		_log_brain("%sTalent: Reservoir Vital (Souffle max +2 = %d)%s" % [C_OK, _souffle_max, C_END])

	# feuillage_2: 1 free center per run
	if ms.is_talent_active("feuillage_2"):
		_free_center_remaining = 1
		_log_brain("%sTalent: Flux Harmonieux (1 Centre gratuit)%s" % [C_OK, C_END])

	# tronc_1: Flux starts at 50/50/50
	if ms.is_talent_active("tronc_1"):
		_flux = {"terre": 50, "esprit": 50, "lien": 50}
		_log_brain("%sTalent: Equilibre des Feux (Flux 50/50/50)%s" % [C_OK, C_END])


func _apply_crit_success(base_fx: Dictionary) -> Dictionary:
	var fx := {}
	for key in base_fx:
		if key == "cost":
			fx[key] = 0  # No cost on critical success
		else:
			var val: int = int(base_fx[key])
			var boosted: int = val * 2 if val > 0 else 1
			# Safe-cap: never push an aspect to game over from a crit
			if _aspects.has(key):
				var current: int = _aspects[key]
				var projected: int = current + boosted
				if abs(projected) >= ASPECT_GAME_OVER:
					boosted = signi(boosted) * maxi(0, ASPECT_GAME_OVER - 1 - abs(current))
			fx[key] = boosted
	return fx


func _apply_failure(base_fx: Dictionary) -> Dictionary:
	var fx := {}
	for key in base_fx:
		if key == "cost":
			fx[key] = int(base_fx[key])  # Still pay cost
		else:
			fx[key] = -int(base_fx[key])  # Reverse effects
	return fx


func _apply_crit_failure(base_fx: Dictionary) -> Dictionary:
	var fx := {}
	for key in base_fx:
		if key == "cost":
			fx[key] = int(base_fx[key]) + 1  # Extra cost
		else:
			fx[key] = -absi(int(base_fx[key])) - 1  # Worse negative
	# Always lose 1 Souffle on crit fail
	if not fx.has("cost"):
		fx["cost"] = 1
	return fx


func _animate_card_outcome(outcome: String) -> void:
	var original_pos: Vector2 = _card_panel.position
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_ELASTIC)

	match outcome:
		"critical_success":
			# Golden pulse — scale up then back
			_card_panel.pivot_offset = _card_panel.size / 2.0
			tw.tween_property(_card_panel, "scale", Vector2(1.08, 1.08), 0.25)
			tw.tween_property(_card_panel, "scale", Vector2(1.0, 1.0), 0.35)
		"success":
			# Gentle glow pulse
			_card_panel.pivot_offset = _card_panel.size / 2.0
			tw.tween_property(_card_panel, "scale", Vector2(1.04, 1.04), 0.2)
			tw.tween_property(_card_panel, "scale", Vector2(1.0, 1.0), 0.3)
		"failure":
			# Shake left-right
			tw.set_trans(Tween.TRANS_SINE)
			tw.set_ease(Tween.EASE_IN_OUT)
			for i in range(3):
				tw.tween_property(_card_panel, "position:x", original_pos.x + 8.0, 0.05)
				tw.tween_property(_card_panel, "position:x", original_pos.x - 8.0, 0.05)
			tw.tween_property(_card_panel, "position:x", original_pos.x, 0.05)
		"critical_failure":
			# Violent shake + slight scale down
			tw.set_trans(Tween.TRANS_SINE)
			tw.set_ease(Tween.EASE_IN_OUT)
			for i in range(5):
				tw.tween_property(_card_panel, "position:x", original_pos.x + 14.0, 0.04)
				tw.tween_property(_card_panel, "position:x", original_pos.x - 14.0, 0.04)
			tw.tween_property(_card_panel, "position:x", original_pos.x, 0.04)
			tw.tween_property(_card_panel, "scale", Vector2(0.97, 0.97), 0.15)
			tw.tween_property(_card_panel, "scale", Vector2(1.0, 1.0), 0.2)


func _spawn_dice_particles(outcome: String) -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 1.0
	particles.speed_scale = 1.5

	# Position at dice display center
	var dice_center := _dice_display.global_position + _dice_display.size / 2.0
	particles.global_position = dice_center

	match outcome:
		"critical_success":
			particles.amount = 40
			particles.color = Color(0.85, 0.72, 0.25)  # Gold
			particles.direction = Vector2(0, -1)
			particles.spread = 120.0
			particles.initial_velocity_min = 80.0
			particles.initial_velocity_max = 180.0
			particles.gravity = Vector2(0, -20)
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 4.0
		"success":
			particles.amount = 15
			particles.color = Color(0.3, 0.7, 0.3)  # Green
			particles.direction = Vector2(0, -1)
			particles.spread = 90.0
			particles.initial_velocity_min = 40.0
			particles.initial_velocity_max = 100.0
			particles.gravity = Vector2(0, 30)
			particles.scale_amount_min = 1.5
			particles.scale_amount_max = 3.0
		"failure":
			particles.amount = 20
			particles.color = Color(0.7, 0.25, 0.15)  # Red
			particles.direction = Vector2(0, 1)
			particles.spread = 60.0
			particles.initial_velocity_min = 30.0
			particles.initial_velocity_max = 80.0
			particles.gravity = Vector2(0, 120)
			particles.scale_amount_min = 1.0
			particles.scale_amount_max = 2.5
		"critical_failure":
			particles.amount = 30
			particles.color = Color(0.3, 0.2, 0.15)  # Dark smoke
			particles.direction = Vector2(0, -1)
			particles.spread = 180.0
			particles.initial_velocity_min = 20.0
			particles.initial_velocity_max = 60.0
			particles.gravity = Vector2(0, 50)
			particles.scale_amount_min = 3.0
			particles.scale_amount_max = 6.0

	get_tree().root.add_child(particles)
	particles.emitting = true
	# Auto-cleanup after particles finish
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


func _format_revealed_effects(outcome: String, fx: Dictionary) -> String:
	var parts := PackedStringArray()
	var prefix := ""

	match outcome:
		"critical_success":
			prefix = "%sCoup Critique !%s " % [C_CRIT, C_END]
		"success":
			prefix = "%sReussite:%s " % [C_OK, C_END]
		"failure":
			prefix = "%sEchec:%s " % [C_FAIL, C_END]
		"critical_failure":
			prefix = "%sEchec Critique !%s " % [C_FAIL, C_END]

	for key in fx:
		var val: int = int(fx[key])
		if key == "cost" and val > 0:
			parts.append("%sSouffle -%d%s" % [C_WARN, val, C_END])
		elif val > 0:
			parts.append("%s%s +%d%s" % [C_OK, key, val, C_END])
		elif val < 0:
			parts.append("%s%s %d%s" % [C_FAIL, key, val, C_END])

	if parts.size() > 0:
		return prefix + ", ".join(parts)
	return prefix + "Aucun effet."


# ═══════════════════════════════════════════════════════════════════════════════
# TRAVEL ANIMATION (between cards)
# ═══════════════════════════════════════════════════════════════════════════════

func _show_travel_then_next_card() -> void:
	_phase = Phase.TRAVELING

	# Pick travel text adapted to recent outcomes
	var travel_text: String = TRAVEL_TEXTS[randi() % TRAVEL_TEXTS.size()]
	if _quest_history.size() >= 2:
		var last: Dictionary = _quest_history[-1]
		var last_outcome: String = str(last.get("outcome", ""))
		if last_outcome == "critical_success":
			travel_text = "La lumiere guide tes pas avec confiance..."
		elif last_outcome == "critical_failure":
			travel_text = "Les ombres s'epaississent sur le sentier..."
		elif last_outcome == "failure":
			travel_text = "Le chemin se fait plus incertain..."
	# Danger zone warning
	var danger_aspects := PackedStringArray()
	for key in _aspects:
		if abs(_aspects[key]) >= ASPECT_DANGER:
			danger_aspects.append(key)
	if danger_aspects.size() > 0:
		travel_text = "Les forces de %s vacillent... prudence." % ", ".join(danger_aspects)
	_travel_label.text = travel_text
	_travel_overlay.visible = true
	_travel_overlay.modulate.a = 0.0

	# SFX: mist/whoosh for travel
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("mist_breath")

	# Fade in fog
	var tw := create_tween()
	tw.tween_property(_travel_overlay, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.2)
	tw.tween_property(_travel_overlay, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		_travel_overlay.visible = false
	)
	await tw.finished

	# Pop from buffer if available, otherwise generate on-demand
	var next := _pop_card_from_buffer()
	if not next.is_empty():
		_log_brain("%sBuffer pop (%d restant)%s" % [C_OK, _card_buffer.size(), C_END])
		_display_card(next)
	else:
		_log_brain("%sBuffer vide — generation a la demande%s" % [C_WARN, C_END])
		_phase = Phase.GENERATING
		_generate_and_show_card()


# ═══════════════════════════════════════════════════════════════════════════════
# ASPECT DISPLAY
# ═══════════════════════════════════════════════════════════════════════════════

func _update_aspect_display() -> void:
	for aspect_key in _aspects:
		if not _aspect_bars.has(aspect_key):
			continue
		var val: int = _aspects[aspect_key]
		var data: Dictionary = _aspect_bars[aspect_key]
		var bar_bg: ColorRect = data.bg
		var bar_fill: ColorRect = data.fill
		var val_lbl: Label = data.val

		val_lbl.text = "%+d" % val if val != 0 else "0"

		# Map [-ASPECT_MAX..+ASPECT_MAX] to bar width (center = 50%)
		var range_total: float = float(ASPECT_MAX - ASPECT_MIN)
		var pct: float = (val - ASPECT_MIN) / range_total
		var max_w: float = bar_bg.custom_minimum_size.x
		# Tween the bar smoothly
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(bar_fill, "size:x", pct * max_w, 0.3)

		# Color: green at center, orange at danger, red at game over
		if abs(val) >= ASPECT_GAME_OVER:
			bar_fill.color = PALETTE.red
			val_lbl.add_theme_color_override("font_color", PALETTE.red)
		elif abs(val) >= ASPECT_DANGER:
			bar_fill.color = Color(0.85, 0.55, 0.15)  # Orange warning
			val_lbl.add_theme_color_override("font_color", Color(0.85, 0.55, 0.15))
		elif abs(val) >= 1:
			bar_fill.color = PALETTE.accent
			val_lbl.add_theme_color_override("font_color", PALETTE.ink)
		else:
			bar_fill.color = PALETTE.green
			val_lbl.add_theme_color_override("font_color", PALETTE.green)

	# Souffle dots (max _souffle_max)
	var dots := ""
	for i in range(_souffle):
		dots += " ◆"
	for i in range(maxi(0, _souffle_max - _souffle)):
		dots += " ◇"
	# Karma indicator
	var karma_str := ""
	if _karma > 0:
		karma_str = "  Karma: %s+%d%s" % [C_OK, _karma, C_END]
	elif _karma < 0:
		karma_str = "  Karma: %s%d%s" % [C_FAIL, _karma, C_END]
	# Blessings indicator
	var bless_str := ""
	for i in range(_blessings):
		bless_str += " ✦"
	if _souffle_dots:
		var base_text := "Souffle:%s" % dots
		if bless_str != "":
			base_text += "  Benedictions:%s" % bless_str
		_souffle_dots.text = base_text


# ═══════════════════════════════════════════════════════════════════════════════
# CARD BUFFER — continuous pre-generation (replaces prefetch)
# ═══════════════════════════════════════════════════════════════════════════════

func _pop_card_from_buffer() -> Dictionary:
	if _card_buffer.is_empty():
		return {}
	var card: Dictionary = _card_buffer.pop_front()
	# Trigger refill if buffer depleted
	if not _is_refilling and _quest_active:
		_continuous_refill()
	return card


func _continuous_refill() -> void:
	if _is_refilling or not _quest_active:
		return
	_is_refilling = true
	_log_brain("%sBuffer refill demarre (cible: %d)%s" % [C_INFO, BUFFER_SIZE, C_END])

	while _quest_active and _card_buffer.size() < BUFFER_SIZE:
		var t0 := Time.get_ticks_msec()
		var card := await _generate_card()
		var elapsed := Time.get_ticks_msec() - t0

		if not _quest_active:
			break

		_card_buffer.append(card)
		_log_brain("%sBuffer +1 → %d/%d (%dms)%s" % [C_OK, _card_buffer.size(), BUFFER_SIZE, elapsed, C_END])

	_is_refilling = false
	if _quest_active:
		_log_brain("%sBuffer plein (%d/%d)%s" % [C_OK, _card_buffer.size(), BUFFER_SIZE, C_END])


# ═══════════════════════════════════════════════════════════════════════════════
# RAG CONTEXT (file-based, prevents prompt bloat)
# ═══════════════════════════════════════════════════════════════════════════════

func _write_context_entry(entry: String) -> void:
	_context_history.append(entry)
	if _context_history.size() > CONTEXT_MAX_ENTRIES:
		_context_history = _context_history.slice(-CONTEXT_MAX_ENTRIES)
	_save_context_history()


func _save_context_history() -> void:
	var file := FileAccess.open(CONTEXT_FILE, FileAccess.WRITE)
	if file:
		for line in _context_history:
			file.store_line(line)


func _load_context_history() -> void:
	_context_history.clear()
	if not FileAccess.file_exists(CONTEXT_FILE):
		return
	var file := FileAccess.open(CONTEXT_FILE, FileAccess.READ)
	if file:
		while not file.eof_reached():
			var line := file.get_line().strip_edges()
			if line != "":
				_context_history.append(line)


func _get_context_summary() -> String:
	if _context_history.is_empty():
		return ""
	var recent := PackedStringArray()
	for entry in _context_history:
		recent.append(entry)
	return "Recemment: " + ". ".join(recent)


# ═══════════════════════════════════════════════════════════════════════════════
# BRAIN MONITOR
# ═══════════════════════════════════════════════════════════════════════════════

func _update_monitor() -> void:
	if _brain_bar_fills.size() < 4 or _brain_bar_labels.size() < 4:
		return
	var ai := _get_merlin_ai()
	if ai == null:
		if _monitor_summary:
			_monitor_summary.text = "%sMerlinAI non disponible%s" % [C_FAIL, C_END]
		for i in range(4):
			_brain_bar_labels[i].add_theme_color_override("font_color", PALETTE.ink_faded)
			_brain_bar_fills[i].size.x = 0
		return

	var info: Dictionary = ai.get_model_info() if ai.has_method("get_model_info") else {}
	var brain_count: int = info.get("brain_count", 0)
	var pool_idle: int = info.get("pool_idle", 0)
	var pool_total: int = info.get("pool_workers", 0)

	var busy := [false, false, false, false]
	if ai.get("_primary_narrator_busy") != null:
		busy[0] = ai._primary_narrator_busy
	if ai.get("_primary_gm_busy") != null:
		busy[1] = ai._primary_gm_busy
	if ai.get("_pool_busy") != null:
		for i in range(mini(ai._pool_busy.size(), 2)):
			busy[2 + i] = ai._pool_busy[i]

	for i in range(4):
		var loaded: bool = i < brain_count
		var parent_bar: ColorRect = _brain_bar_fills[i].get_parent() as ColorRect
		var max_w: float = parent_bar.size.x if parent_bar else 80.0

		if loaded:
			_brain_bar_labels[i].add_theme_color_override("font_color", PALETTE.ink_soft)
			if busy[i]:
				_brain_bar_fills[i].color = PALETTE.red
				_brain_bar_fills[i].size.x = max_w
			else:
				_brain_bar_fills[i].color = PALETTE.green
				_brain_bar_fills[i].size.x = max_w * 0.15
		else:
			_brain_bar_labels[i].add_theme_color_override("font_color", PALETTE.ink_faded)
			_brain_bar_fills[i].size.x = 0

	var active_bg: int = ai._active_bg_tasks.size() if ai.get("_active_bg_tasks") != null else 0
	var buf_count: int = _card_buffer.size()
	var buf_color: String = C_OK if buf_count >= BUFFER_SIZE else (C_WARN if buf_count > 0 else C_FAIL)
	var refill_tag: String = " (refill...)" if _is_refilling else ""
	# Karma + Blessings display
	var karma_tag := ""
	if _karma > 0:
		karma_tag = " | %sKarma:%s %s+%d%s" % [C_ACCENT, C_END, C_OK, _karma, C_END]
	elif _karma < 0:
		karma_tag = " | %sKarma:%s %s%d%s" % [C_ACCENT, C_END, C_FAIL, _karma, C_END]
	var bless_tag := ""
	if _blessings > 0:
		bless_tag = " | %sBenedictions:%s %s%d%s" % [C_ACCENT, C_END, C_CRIT, _blessings, C_END]

	# Flux monitoring (Phase 35)
	var flux_tag := "\n%sFlux:%s T:%d E:%d L:%d (%s/%s/%s)" % [
		C_INFO, C_END,
		int(_flux.get("terre", 50)), int(_flux.get("esprit", 30)), int(_flux.get("lien", 40)),
		_get_flux_tier("terre").left(3), _get_flux_tier("esprit").left(3), _get_flux_tier("lien").left(3),
	]

	if _monitor_summary:
		_monitor_summary.text = "%sMode:%s %s | %sCerveaux:%s %d | %sPool:%s %d/%d | %sBG:%s %d\n%sBuffer:%s %s%d/%d%s%s%s%s%s" % [
			C_ACCENT, C_END, info.get("brain_mode", "?"),
			C_ACCENT, C_END, brain_count,
			C_ACCENT, C_END, pool_idle, pool_total,
			C_ACCENT, C_END, active_bg,
			C_ACCENT, C_END, buf_color, buf_count, BUFFER_SIZE, C_END, refill_tag,
			karma_tag, bless_tag, flux_tag,
		]


func _get_merlin_ai() -> Node:
	if _merlin_ai == null:
		_merlin_ai = get_node_or_null("/root/MerlinAI")
	return _merlin_ai
