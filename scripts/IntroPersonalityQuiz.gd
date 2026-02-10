extends Control
## Pokemon Mystery Dungeon-style personality quiz intro
## Questions fade in from darkness, player choices determine traits
## Placeholder questions - will be LLM-generated later

signal quiz_completed(traits: Dictionary)

# =============================================================================
# CONSTANTS
# =============================================================================

const NEXT_SCENE := "res://scenes/SceneRencontreMerlin.tscn"
const MENU_SCENE := "res://scenes/MenuPrincipal.tscn"

const PALETTE := {
	"bg": Color(0.02, 0.02, 0.04),
	"text": Color(0.92, 0.88, 0.80),
	"text_dim": Color(0.6, 0.55, 0.50),
	"accent": Color(0.85, 0.70, 0.35),
	"choice_normal": Color(0.75, 0.70, 0.65),
	"choice_hover": Color(0.95, 0.90, 0.80),
	"choice_selected": Color(0.85, 0.70, 0.35),
}

const FADE_DURATION := 1.5
const TEXT_FADE_DURATION := 0.8
const QUESTION_DELAY := 0.5
const CHOICE_STAGGER := 0.15

# =============================================================================
# PERSONALITY SYSTEM - 4 Axes
# =============================================================================
# Approche:  prudent (-) ↔ audacieux (+)
# Relation:  solitaire (-) ↔ social (+)
# Esprit:    analytique (-) ↔ intuitif (+)
# Coeur:     pragmatique (-) ↔ compassionnel (+)

const PERSONALITY_AXES := {
	"approche": {"negative": "prudent", "positive": "audacieux", "neutral": "adaptable"},
	"relation": {"negative": "solitaire", "positive": "social", "neutral": "equilibre"},
	"esprit": {"negative": "analytique", "positive": "intuitif", "neutral": "polyvalent"},
	"coeur": {"negative": "pragmatique", "positive": "compassionnel", "neutral": "nuance"},
}

# Personality archetypes based on dominant traits
const ARCHETYPES := {
	"gardien": {
		"pattern": {"approche": -1, "coeur": 1},
		"title": "Le Gardien",
		"desc": "Tu proteges ceux qui ne peuvent se defendre.\nTa prudence cache un coeur immense.",
	},
	"explorateur": {
		"pattern": {"approche": 1, "esprit": 1},
		"title": "L'Explorateur",
		"desc": "Le monde t'appelle et tu reponds.\nTon instinct te guide vers l'inconnu.",
	},
	"sage": {
		"pattern": {"relation": -1, "esprit": -1},
		"title": "Le Sage",
		"desc": "Tu observes, tu analyses, tu comprends.\nLa solitude nourrit ta reflexion.",
	},
	"heros": {
		"pattern": {"approche": 1, "relation": 1},
		"title": "Le Heros",
		"desc": "Tu avances sans peur vers le danger.\nLes autres trouvent force a tes cotes.",
	},
	"guerisseur": {
		"pattern": {"coeur": 1, "relation": 1},
		"title": "Le Guerisseur",
		"desc": "Tu ressens la douleur des autres.\nTa presence apaise les ames troublees.",
	},
	"stratege": {
		"pattern": {"esprit": -1, "approche": -1},
		"title": "Le Stratege",
		"desc": "Chaque action est calculee.\nTu vois dix coups a l'avance.",
	},
	"mystique": {
		"pattern": {"esprit": 1, "relation": -1},
		"title": "Le Mystique",
		"desc": "Tu percois ce que d'autres ignorent.\nLes brumes te murmurent leurs secrets.",
	},
	"guide": {
		"pattern": {"coeur": 1, "esprit": 1},
		"title": "Le Guide",
		"desc": "Ton intuition eclaire le chemin.\nTu menes par l'exemple et la bienveillance.",
	},
}

# 10 Questions for complete personality assessment
const QUESTIONS := [
	# Q1: Approche (prudent vs audacieux)
	{
		"text": "Tu te reveilles dans une foret inconnue.\nLa brume enveloppe tout.\nQue fais-tu en premier?",
		"choices": [
			{"text": "J'observe les environs en silence", "axes": {"approche": -2, "esprit": -1}},
			{"text": "J'appelle pour voir si quelqu'un repond", "axes": {"relation": 2, "approche": 1}},
			{"text": "Je cherche un point haut pour voir plus loin", "axes": {"approche": 1, "esprit": -1}},
			{"text": "Je reste immobile et j'ecoute", "axes": {"approche": -1, "esprit": 1}},
		]
	},
	# Q2: Relation (solitaire vs social)
	{
		"text": "Une voix murmure ton nom depuis les arbres.\nElle semble... familiere.",
		"choices": [
			{"text": "Je m'approche prudemment", "axes": {"approche": -1, "relation": 1}},
			{"text": "Je demande qui est la", "axes": {"approche": 1, "relation": 1}},
			{"text": "Je m'eloigne sans bruit", "axes": {"approche": -1, "relation": -2}},
			{"text": "Je tends l'oreille pour en savoir plus", "axes": {"esprit": 1, "relation": 0}},
		]
	},
	# Q3: Esprit (analytique vs intuitif)
	{
		"text": "Tu trouves un objet brillant au sol.\nIl pulse doucement d'une lueur bleutee.",
		"choices": [
			{"text": "Je le ramasse immediatement", "axes": {"approche": 2, "esprit": 1}},
			{"text": "Je l'examine sans le toucher", "axes": {"approche": -1, "esprit": -2}},
			{"text": "Je le laisse et continue mon chemin", "axes": {"coeur": -1, "approche": 0}},
			{"text": "Je ressens son energie avant de decider", "axes": {"esprit": 2, "coeur": 1}},
		]
	},
	# Q4: Coeur (pragmatique vs compassionnel)
	{
		"text": "Un animal blesse te regarde.\nSes yeux semblent pleins d'intelligence.",
		"choices": [
			{"text": "J'essaie de le soigner", "axes": {"coeur": 2, "relation": 1}},
			{"text": "Je lui parle doucement pour le rassurer", "axes": {"coeur": 1, "esprit": 1}},
			{"text": "Je passe mon chemin, la nature suit son cours", "axes": {"coeur": -2, "approche": 1}},
			{"text": "J'evalue s'il peut m'etre utile", "axes": {"coeur": -1, "esprit": -1}},
		]
	},
	# Q5: Relation (solitaire vs social) - deeper
	{
		"text": "La brume s'ecarte et revele un chemin.\nA gauche, des lumieres et des voix.\nA droite, le silence profond.",
		"choices": [
			{"text": "Je vais vers les lumieres", "axes": {"relation": 2, "approche": 1}},
			{"text": "Je choisis le silence", "axes": {"relation": -2, "esprit": 1}},
			{"text": "J'attends de voir si quelque chose change", "axes": {"approche": -1, "esprit": -1}},
			{"text": "Je crie pour signaler ma presence", "axes": {"relation": 1, "approche": 2}},
		]
	},
	# Q6: Approche in conflict
	{
		"text": "Tu decouvres un campement abandonne.\nUn feu couve encore. Des traces de lutte...",
		"choices": [
			{"text": "Je fouille les restes a la recherche d'indices", "axes": {"esprit": -1, "approche": 1}},
			{"text": "Je pars immediatement, c'est trop dangereux", "axes": {"approche": -2, "coeur": -1}},
			{"text": "Je cherche des survivants aux alentours", "axes": {"coeur": 2, "approche": 1}},
			{"text": "Je m'installe et attends le retour des occupants", "axes": {"relation": 1, "approche": -1}},
		]
	},
	# Q7: Esprit under pressure
	{
		"text": "Un enigme est gravee sur une pierre ancienne.\nElle promet un tresor... ou un piege.",
		"choices": [
			{"text": "J'analyse chaque symbole methodiquement", "axes": {"esprit": -2, "approche": -1}},
			{"text": "Je fais confiance a mon premier instinct", "axes": {"esprit": 2, "approche": 1}},
			{"text": "Je contourne la pierre et ignore l'enigme", "axes": {"coeur": -1, "approche": 0}},
			{"text": "Je cherche quelqu'un pour m'aider", "axes": {"relation": 2, "esprit": 0}},
		]
	},
	# Q8: Coeur in moral dilemma
	{
		"text": "Un voyageur te demande de l'aide.\nMais quelque chose dans son regard te trouble.",
		"choices": [
			{"text": "Je l'aide malgre mes doutes", "axes": {"coeur": 2, "approche": 1}},
			{"text": "Je refuse poliment et m'eloigne", "axes": {"coeur": -1, "approche": -1}},
			{"text": "Je l'interroge avant de decider", "axes": {"esprit": -1, "relation": 1}},
			{"text": "Je fais confiance a mon malaise", "axes": {"esprit": 2, "coeur": 0}},
		]
	},
	# Q9: Mixed - crisis situation
	{
		"text": "Un cri dechire la nuit.\nIl vient de la direction opposee a ton but.",
		"choices": [
			{"text": "Je cours vers le cri sans hesiter", "axes": {"approche": 2, "coeur": 2}},
			{"text": "Je reste sur mon chemin, j'ai une mission", "axes": {"coeur": -2, "esprit": -1}},
			{"text": "J'avance prudemment vers le son", "axes": {"approche": -1, "coeur": 1}},
			{"text": "Je cherche un point d'observation", "axes": {"esprit": -1, "approche": -1}},
		]
	},
	# Q10: Final reflection - self
	{
		"text": "Devant un lac immobile, tu vois ton reflet.\nIl te pose une question muette.\nQui es-tu vraiment?",
		"choices": [
			{"text": "Celui qui protege les autres", "axes": {"coeur": 2, "relation": 1}},
			{"text": "Celui qui cherche la verite", "axes": {"esprit": -1, "approche": 1}},
			{"text": "Celui qui suit son instinct", "axes": {"esprit": 2, "approche": 1}},
			{"text": "Celui qui avance seul dans l'ombre", "axes": {"relation": -2, "approche": -1}},
		]
	},
]

# =============================================================================
# VARIABLES
# =============================================================================

var current_question_index := 0
var collected_traits: Array[String] = []  # Legacy, kept for compatibility
var axis_scores := {"approche": 0, "relation": 0, "esprit": 0, "coeur": 0}
var is_transitioning := false

var background: ColorRect
var question_label: Label
var choices_container: VBoxContainer
var choice_buttons: Array[Button] = []
var progress_label: Label
var skip_button: Button
var skip_modal: PanelContainer
var skip_modal_visible := false

var title_font: Font
var body_font: Font

var active_tween: Tween

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_load_fonts()
	_build_ui()
	_build_skip_button()
	_start_intro()


func _load_fonts() -> void:
	var font_paths := [
		"res://resources/fonts/morris/MorrisRomanBlack.otf",
		"res://resources/fonts/morris/MorrisRomanBlack.ttf",
	]
	for path in font_paths:
		if ResourceLoader.exists(path):
			title_font = load(path)
			break

	var body_paths := [
		"res://resources/fonts/morris/MorrisRomanBlackAlt.otf",
		"res://resources/fonts/morris/MorrisRomanBlackAlt.ttf",
	]
	for path in body_paths:
		if ResourceLoader.exists(path):
			body_font = load(path)
			break

	if body_font == null:
		body_font = title_font


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background - pure black
	background = ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = PALETTE.bg
	add_child(background)

	# Center container for content
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 40)
	vbox.custom_minimum_size = Vector2(800, 0)
	center.add_child(vbox)

	# Question label
	question_label = Label.new()
	question_label.name = "QuestionLabel"
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.custom_minimum_size = Vector2(700, 150)
	if title_font:
		question_label.add_theme_font_override("font", title_font)
	question_label.add_theme_font_size_override("font_size", 28)
	question_label.add_theme_color_override("font_color", PALETTE.text)
	question_label.modulate.a = 0
	vbox.add_child(question_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Choices container
	choices_container = VBoxContainer.new()
	choices_container.name = "ChoicesContainer"
	choices_container.alignment = BoxContainer.ALIGNMENT_CENTER
	choices_container.add_theme_constant_override("separation", 16)
	vbox.add_child(choices_container)

	# Progress indicator (bottom)
	progress_label = Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	progress_label.offset_top = -50
	progress_label.offset_bottom = -20
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if body_font:
		progress_label.add_theme_font_override("font", body_font)
	progress_label.add_theme_font_size_override("font_size", 14)
	progress_label.add_theme_color_override("font_color", PALETTE.text_dim)
	progress_label.modulate.a = 0
	add_child(progress_label)


# =============================================================================
# SKIP BUTTON & MODAL
# =============================================================================

func _build_skip_button() -> void:
	# Skip button in top-right corner
	skip_button = Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = "Passer ▸"
	skip_button.flat = true
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_button.offset_left = -120
	skip_button.offset_right = -20
	skip_button.offset_top = 20
	skip_button.offset_bottom = 50
	if body_font:
		skip_button.add_theme_font_override("font", body_font)
	skip_button.add_theme_font_size_override("font_size", 16)
	skip_button.add_theme_color_override("font_color", PALETTE.text_dim)
	skip_button.add_theme_color_override("font_hover_color", PALETTE.accent)
	skip_button.pressed.connect(_show_skip_modal)
	add_child(skip_button)

	# Skip modal (hidden by default)
	skip_modal = PanelContainer.new()
	skip_modal.name = "SkipModal"
	skip_modal.visible = false
	skip_modal.set_anchors_preset(Control.PRESET_CENTER)
	skip_modal.offset_left = -160
	skip_modal.offset_right = 160
	skip_modal.offset_top = -80
	skip_modal.offset_bottom = 80

	var modal_style := StyleBoxFlat.new()
	modal_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	modal_style.set_border_width_all(2)
	modal_style.border_color = PALETTE.accent
	modal_style.set_corner_radius_all(8)
	modal_style.content_margin_left = 24
	modal_style.content_margin_right = 24
	modal_style.content_margin_top = 20
	modal_style.content_margin_bottom = 20
	skip_modal.add_theme_stylebox_override("panel", modal_style)
	add_child(skip_modal)

	var modal_vbox := VBoxContainer.new()
	modal_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_vbox.add_theme_constant_override("separation", 16)
	skip_modal.add_child(modal_vbox)

	var modal_title := Label.new()
	modal_title.text = "Passer le questionnaire?"
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if body_font:
		modal_title.add_theme_font_override("font", body_font)
	modal_title.add_theme_font_size_override("font_size", 18)
	modal_title.add_theme_color_override("font_color", PALETTE.text)
	modal_vbox.add_child(modal_title)

	var buttons_hbox := HBoxContainer.new()
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_hbox.add_theme_constant_override("separation", 20)
	modal_vbox.add_child(buttons_hbox)

	# Menu button
	var menu_btn := Button.new()
	menu_btn.text = "◀ Menu"
	menu_btn.flat = true
	menu_btn.focus_mode = Control.FOCUS_NONE
	menu_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	menu_btn.custom_minimum_size = Vector2(100, 40)
	if body_font:
		menu_btn.add_theme_font_override("font", body_font)
	menu_btn.add_theme_font_size_override("font_size", 16)
	menu_btn.add_theme_color_override("font_color", PALETTE.text_dim)
	menu_btn.add_theme_color_override("font_hover_color", PALETTE.text)
	menu_btn.pressed.connect(_skip_to_menu)
	buttons_hbox.add_child(menu_btn)

	# Continue button
	var continue_btn := Button.new()
	continue_btn.text = "Continuer ▸"
	continue_btn.flat = true
	continue_btn.focus_mode = Control.FOCUS_NONE
	continue_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	continue_btn.custom_minimum_size = Vector2(120, 40)
	if body_font:
		continue_btn.add_theme_font_override("font", body_font)
	continue_btn.add_theme_font_size_override("font_size", 16)
	continue_btn.add_theme_color_override("font_color", PALETTE.accent)
	continue_btn.add_theme_color_override("font_hover_color", PALETTE.choice_hover)
	continue_btn.pressed.connect(_skip_to_next_scene)
	buttons_hbox.add_child(continue_btn)

	# Cancel hint
	var cancel_hint := Label.new()
	cancel_hint.text = "(Echap pour annuler)"
	cancel_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cancel_hint.add_theme_font_size_override("font_size", 12)
	cancel_hint.add_theme_color_override("font_color", PALETTE.text_dim)
	modal_vbox.add_child(cancel_hint)


func _show_skip_modal() -> void:
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click")
	skip_modal_visible = true
	skip_modal.visible = true
	skip_modal.modulate.a = 0
	var tween := create_tween()
	tween.tween_property(skip_modal, "modulate:a", 1.0, 0.2)


func _hide_skip_modal() -> void:
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click")
	skip_modal_visible = false
	var tween := create_tween()
	tween.tween_property(skip_modal, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): skip_modal.visible = false)


func _skip_to_menu() -> void:
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click")
	_hide_skip_modal()
	if active_tween:
		active_tween.kill()
	active_tween = create_tween()
	active_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	active_tween.tween_callback(func():
		get_tree().change_scene_to_file(MENU_SCENE)
	)


func _skip_to_next_scene() -> void:
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click")
	_hide_skip_modal()
	# Set default personality for skipped quiz
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		var default_personality := {
			"archetype_id": "explorateur",
			"archetype_title": "L'Explorateur",
			"archetype_desc": "Le monde t'appelle et tu reponds.",
			"axis_scores": {"approche": 0, "relation": 0, "esprit": 0, "coeur": 0},
			"axis_positions": {"approche": 0.0, "relation": 0.0, "esprit": 0.0, "coeur": 0.0},
			"axis_labels": {"approche": "adaptable", "relation": "equilibre", "esprit": "polyvalent", "coeur": "nuance"},
			"dominant_traits": [],
		}
		if game_manager.has_method("set"):
			game_manager.set("player_traits", default_personality)
	_transition_to_next_scene()


# =============================================================================
# INTRO FLOW
# =============================================================================

func _start_intro() -> void:
	# Initial black screen pause
	await get_tree().create_timer(FADE_DURATION).timeout

	# Show first question
	_show_question(0)


func _show_question(index: int) -> void:
	if index >= QUESTIONS.size():
		_complete_quiz()
		return

	current_question_index = index
	var question: Dictionary = QUESTIONS[index]

	# Clear previous choices
	for btn in choice_buttons:
		btn.queue_free()
	choice_buttons.clear()

	# Update progress
	progress_label.text = "%d / %d" % [index + 1, QUESTIONS.size()]

	# Fade in question text
	question_label.text = question.text

	if active_tween:
		active_tween.kill()
	active_tween = create_tween()

	# Fade in question
	active_tween.tween_property(question_label, "modulate:a", 1.0, TEXT_FADE_DURATION)
	active_tween.parallel().tween_property(progress_label, "modulate:a", 0.5, TEXT_FADE_DURATION)

	# Wait then show choices
	active_tween.tween_interval(QUESTION_DELAY)

	# Create choice buttons
	var choices: Array = question.choices
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var btn := _create_choice_button(choice.text, i)
		btn.modulate.a = 0
		choices_container.add_child(btn)
		choice_buttons.append(btn)

		# Stagger fade in
		active_tween.tween_property(btn, "modulate:a", 1.0, 0.3).set_delay(i * CHOICE_STAGGER)


func _create_choice_button(text: String, index: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = Vector2(600, 50)

	# Style
	if body_font:
		btn.add_theme_font_override("font", body_font)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", PALETTE.choice_normal)
	btn.add_theme_color_override("font_hover_color", PALETTE.choice_hover)
	btn.add_theme_color_override("font_pressed_color", PALETTE.choice_selected)

	# Connect signals
	btn.pressed.connect(func(): _on_choice_selected(index))
	btn.mouse_entered.connect(func(): _on_choice_hover(btn, true))
	btn.mouse_exited.connect(func(): _on_choice_hover(btn, false))

	return btn


func _on_choice_hover(btn: Button, hovering: bool) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hovering:
		var sfx := get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play("choice_hover")
		tween.tween_property(btn, "scale", Vector2(1.02, 1.02), 0.1)
	else:
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)


func _on_choice_selected(choice_index: int) -> void:
	if is_transitioning:
		return
	is_transitioning = true

	var sfx := get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("choice_select")

	var question: Dictionary = QUESTIONS[current_question_index]
	var choice: Dictionary = question.choices[choice_index]

	# Collect axis scores (new system)
	if choice.has("axes"):
		for axis in choice.axes:
			if axis_scores.has(axis):
				axis_scores[axis] += choice.axes[axis]

	# Legacy trait collection for backward compatibility
	if choice.has("traits"):
		for t in choice.traits:
			if not collected_traits.has(t):
				collected_traits.append(t)

	# Flash selected button
	var selected_btn: Button = choice_buttons[choice_index]
	selected_btn.add_theme_color_override("font_color", PALETTE.choice_selected)

	# Fade out all
	if active_tween:
		active_tween.kill()
	active_tween = create_tween()
	active_tween.tween_property(question_label, "modulate:a", 0.0, 0.4)
	active_tween.parallel().tween_property(progress_label, "modulate:a", 0.0, 0.4)

	for btn in choice_buttons:
		active_tween.parallel().tween_property(btn, "modulate:a", 0.0, 0.3)

	# Next question or complete
	active_tween.tween_interval(0.3)
	active_tween.tween_callback(func():
		is_transitioning = false
		var sfx_mgr := get_node_or_null("/root/SFXManager")
		if sfx_mgr:
			sfx_mgr.play("question_transition")
		_show_question(current_question_index + 1)
	)


# =============================================================================
# COMPLETION
# =============================================================================

func _complete_quiz() -> void:
	# Build traits dictionary
	var personality := _calculate_personality()

	# Store in autoload if available
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		if not game_manager.get("player_traits"):
			game_manager.set("player_traits", personality)
		else:
			game_manager.player_traits = personality

	# Emit signal
	quiz_completed.emit(personality)

	# Show archetype reveal
	_show_personality_reveal(personality)


func _show_personality_reveal(personality: Dictionary) -> void:
	var archetype_title: String = personality.archetype_title
	var archetype_desc: String = personality.archetype_desc
	var traits: Array = personality.dominant_traits

	# Phase 1: "Les brumes connaissent..."
	question_label.text = "Les brumes connaissent ton coeur..."

	var sfx := get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("result_reveal")

	if active_tween:
		active_tween.kill()
	active_tween = create_tween()
	active_tween.tween_property(question_label, "modulate:a", 1.0, TEXT_FADE_DURATION)
	active_tween.tween_interval(1.5)
	active_tween.tween_property(question_label, "modulate:a", 0.0, 0.5)

	# Phase 2: Archetype title
	active_tween.tween_callback(func():
		question_label.text = archetype_title
		question_label.add_theme_font_size_override("font_size", 42)
		question_label.add_theme_color_override("font_color", PALETTE.accent)
		var sfx_mgr := get_node_or_null("/root/SFXManager")
		if sfx_mgr:
			sfx_mgr.play("magic_reveal")
	)
	active_tween.tween_property(question_label, "modulate:a", 1.0, TEXT_FADE_DURATION)
	active_tween.tween_interval(2.0)
	active_tween.tween_property(question_label, "modulate:a", 0.0, 0.5)

	# Phase 3: Description
	active_tween.tween_callback(func():
		question_label.text = archetype_desc
		question_label.add_theme_font_size_override("font_size", 24)
		question_label.add_theme_color_override("font_color", PALETTE.text)
	)
	active_tween.tween_property(question_label, "modulate:a", 1.0, TEXT_FADE_DURATION)
	active_tween.tween_interval(3.0)

	# Phase 4: Traits summary
	if traits.size() > 0:
		var traits_text := "Tes traits:\n" + ", ".join(traits)
		active_tween.tween_property(question_label, "modulate:a", 0.0, 0.5)
		active_tween.tween_callback(func():
			question_label.text = traits_text
			question_label.add_theme_font_size_override("font_size", 20)
			question_label.add_theme_color_override("font_color", PALETTE.text_dim)
		)
		active_tween.tween_property(question_label, "modulate:a", 1.0, TEXT_FADE_DURATION)
		active_tween.tween_interval(2.0)

	# Final fade and transition
	active_tween.tween_property(question_label, "modulate:a", 0.0, FADE_DURATION)
	active_tween.tween_callback(_transition_to_next_scene)


func _calculate_personality() -> Dictionary:
	# Calculate axis positions (-1 to +1 normalized)
	var axis_positions := {}
	var axis_labels := {}

	for axis in axis_scores:
		var score: int = axis_scores[axis]
		# Normalize to -1 to +1 range (max possible is ~20 per axis)
		var normalized: float = clampf(float(score) / 10.0, -1.0, 1.0)
		axis_positions[axis] = normalized

		# Determine label based on position
		var axis_data: Dictionary = PERSONALITY_AXES[axis]
		if normalized < -0.3:
			axis_labels[axis] = axis_data.negative
		elif normalized > 0.3:
			axis_labels[axis] = axis_data.positive
		else:
			axis_labels[axis] = axis_data.neutral

	# Find matching archetype
	var best_archetype := "explorateur"  # Default
	var best_score := -999.0

	for archetype_id in ARCHETYPES:
		var archetype: Dictionary = ARCHETYPES[archetype_id]
		var pattern: Dictionary = archetype.pattern
		var match_score := 0.0

		for axis in pattern:
			var target: int = pattern[axis]
			var actual: float = axis_positions[axis]
			# Score based on alignment with pattern
			match_score += actual * float(target)

		if match_score > best_score:
			best_score = match_score
			best_archetype = archetype_id

	var archetype_data: Dictionary = ARCHETYPES[best_archetype]

	return {
		"archetype_id": best_archetype,
		"archetype_title": archetype_data.title,
		"archetype_desc": archetype_data.desc,
		"axis_scores": axis_scores.duplicate(),
		"axis_positions": axis_positions,
		"axis_labels": axis_labels,
		"dominant_traits": _get_dominant_traits(axis_labels),
	}


func _get_dominant_traits(axis_labels: Dictionary) -> Array[String]:
	var traits: Array[String] = []
	for axis in axis_labels:
		var label: String = axis_labels[axis]
		if label != "adaptable" and label != "equilibre" and label != "polyvalent" and label != "nuance":
			traits.append(label)
	return traits


func _transition_to_next_scene() -> void:
	# Fade to black then change scene
	if active_tween:
		active_tween.kill()
	active_tween = create_tween()
	active_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	active_tween.tween_callback(func():
		get_tree().change_scene_to_file(NEXT_SCENE)
	)


# =============================================================================
# INPUT
# =============================================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if skip_modal_visible:
			# Close modal if open
			_hide_skip_modal()
		else:
			# Show skip modal
			_show_skip_modal()
