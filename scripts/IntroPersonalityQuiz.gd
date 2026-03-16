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

# PALETTE constant removed — using MerlinVisual.CRT_PALETTE autoload

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

# Data moved to QuizData class (quiz_data.gd)
const PERSONALITY_AXES := QuizData.PERSONALITY_AXES
const ARCHETYPES := QuizData.ARCHETYPES
const QUESTIONS := QuizData.QUESTIONS

# =============================================================================
# VARIABLES
# =============================================================================

var current_question_index := 0
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
var _hover_tweens: Dictionary = {}
var _skip_modal_tween: Tween

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_load_fonts()
	_build_ui()
	_build_skip_button()
	_start_intro()


func _load_fonts() -> void:
	title_font = MerlinVisual.get_font("title")
	body_font = MerlinVisual.get_font("body")
	if body_font == null:
		body_font = title_font


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background - pure black
	background = ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = MerlinVisual.CRT_PALETTE.bg_deep
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
	var question_color: Color = MerlinVisual.CRT_PALETTE["phosphor_bright"]
	question_label.add_theme_color_override("font_color", question_color)
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
	var progress_color: Color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
	progress_label.add_theme_color_override("font_color", progress_color)
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
	var skip_font_color: Color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
	skip_button.add_theme_color_override("font_color", skip_font_color)
	skip_button.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE.amber)
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
	var modal_bg: Color = MerlinVisual.CRT_PALETTE["bg_dark"]
	modal_style.bg_color = Color(modal_bg.r, modal_bg.g, modal_bg.b, 0.95)
	modal_style.set_border_width_all(2)
	modal_style.border_color = MerlinVisual.CRT_PALETTE.amber
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
	var modal_title_color: Color = MerlinVisual.CRT_PALETTE["phosphor_bright"]
	modal_title.add_theme_color_override("font_color", modal_title_color)
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
	var menu_btn_color: Color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
	var menu_btn_hover: Color = MerlinVisual.CRT_PALETTE["phosphor_bright"]
	menu_btn.add_theme_color_override("font_color", menu_btn_color)
	menu_btn.add_theme_color_override("font_hover_color", menu_btn_hover)
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
	continue_btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	continue_btn.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE.choice_hover)
	continue_btn.pressed.connect(_skip_to_next_scene)
	buttons_hbox.add_child(continue_btn)

	# Cancel hint
	var cancel_hint := Label.new()
	cancel_hint.text = "(Echap pour annuler)"
	cancel_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cancel_hint.add_theme_font_size_override("font_size", 12)
	var cancel_hint_color: Color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
	cancel_hint.add_theme_color_override("font_color", cancel_hint_color)
	modal_vbox.add_child(cancel_hint)


func _show_skip_modal() -> void:
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click")
	skip_modal_visible = true
	skip_modal.visible = true
	skip_modal.modulate.a = 0
	if _skip_modal_tween:
		_skip_modal_tween.kill()
	_skip_modal_tween = create_tween()
	_skip_modal_tween.tween_property(skip_modal, "modulate:a", 1.0, 0.2)


func _hide_skip_modal() -> void:
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("click")
	skip_modal_visible = false
	if _skip_modal_tween:
		_skip_modal_tween.kill()
	_skip_modal_tween = create_tween()
	_skip_modal_tween.tween_property(skip_modal, "modulate:a", 0.0, 0.15)
	_skip_modal_tween.tween_callback(func(): skip_modal.visible = false)


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
		PixelTransition.transition_to(MENU_SCENE)
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

	# Set question text (hidden initially)
	question_label.text = question.text
	question_label.modulate.a = 0.0
	progress_label.modulate.a = 0.0

	if active_tween:
		active_tween.kill()

	# Pixel reveal question + progress
	var pca: Node = get_node_or_null("/root/PixelContentAnimator")
	if pca:
		await get_tree().process_frame
		pca.reveal(question_label, {"duration": 0.4, "block_size": 8})
		pca.reveal(progress_label, {"duration": 0.3, "block_size": 6})
	else:
		question_label.modulate.a = 1.0
		progress_label.modulate.a = 0.5

	# Wait then show choices
	await get_tree().create_timer(QUESTION_DELAY).timeout

	# Create choice buttons
	var choices: Array = question.choices
	var btns_to_reveal: Array[Control] = []
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var btn := _create_choice_button(choice.text, i)
		btn.modulate.a = 0.0
		choices_container.add_child(btn)
		choice_buttons.append(btn)
		btns_to_reveal.append(btn)

	# Pixel reveal choice buttons as a group
	if pca:
		await get_tree().process_frame
		pca.reveal_group(btns_to_reveal, {"duration": 0.3, "block_size": 8, "inter_delay": 0.1})
	else:
		for btn in btns_to_reveal:
			btn.modulate.a = 1.0


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
	btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.choice_normal)
	btn.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE.choice_hover)
	btn.add_theme_color_override("font_pressed_color", MerlinVisual.CRT_PALETTE.choice_selected)

	# Connect signals
	btn.pressed.connect(func(): _on_choice_selected(index))
	btn.mouse_entered.connect(func(): _on_choice_hover(btn, true))
	btn.mouse_exited.connect(func(): _on_choice_hover(btn, false))

	return btn


func _on_choice_hover(btn: Button, hovering: bool) -> void:
	if _hover_tweens.has(btn) and _hover_tweens[btn]:
		_hover_tweens[btn].kill()
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tweens[btn] = tween
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

	# Flash selected button
	var selected_btn: Button = choice_buttons[choice_index]
	selected_btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.choice_selected)

	# Pixel dissolve all
	var pca: Node = get_node_or_null("/root/PixelContentAnimator")
	if pca:
		pca.dissolve(question_label, {"duration": 0.35, "block_size": 8})
		pca.dissolve(progress_label, {"duration": 0.25, "block_size": 6})
		var btns_arr: Array[Control] = []
		for btn in choice_buttons:
			btns_arr.append(btn)
		pca.dissolve_group(btns_arr, {"duration": 0.25, "block_size": 8, "inter_delay": 0.05})
		# Wait for dissolve to finish
		await get_tree().create_timer(0.5).timeout
	else:
		if active_tween:
			active_tween.kill()
		active_tween = create_tween()
		active_tween.tween_property(question_label, "modulate:a", 0.0, 0.4)
		active_tween.parallel().tween_property(progress_label, "modulate:a", 0.0, 0.4)
		for btn in choice_buttons:
			active_tween.parallel().tween_property(btn, "modulate:a", 0.0, 0.3)
		await active_tween.finished

	# Next question or complete
	is_transitioning = false
	var sfx_mgr := get_node_or_null("/root/SFXManager")
	if sfx_mgr:
		sfx_mgr.play("question_transition")
	_show_question(current_question_index + 1)


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

	var pca: Node = get_node_or_null("/root/PixelContentAnimator")
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("result_reveal")

	# Phase 1: "Les brumes connaissent..."
	question_label.text = "Les brumes connaissent ton coeur..."
	question_label.modulate.a = 0.0
	await get_tree().process_frame
	if pca:
		pca.reveal(question_label, {"duration": 0.5, "block_size": 8})
	else:
		question_label.modulate.a = 1.0
	await get_tree().create_timer(1.5).timeout
	if pca:
		pca.dissolve(question_label, {"duration": 0.4, "block_size": 8})
	else:
		question_label.modulate.a = 0.0
	await get_tree().create_timer(0.5).timeout

	# Phase 2: Archetype title
	question_label.text = archetype_title
	question_label.add_theme_font_size_override("font_size", 42)
	question_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	question_label.modulate.a = 0.0
	if sfx:
		sfx.play("magic_reveal")
	await get_tree().process_frame
	if pca:
		pca.reveal(question_label, {"duration": 0.5, "block_size": 6})
	else:
		question_label.modulate.a = 1.0
	await get_tree().create_timer(2.0).timeout
	if pca:
		pca.dissolve(question_label, {"duration": 0.4, "block_size": 6})
	else:
		question_label.modulate.a = 0.0
	await get_tree().create_timer(0.5).timeout

	# Phase 3: Description
	question_label.text = archetype_desc
	question_label.add_theme_font_size_override("font_size", 24)
	var desc_color: Color = MerlinVisual.CRT_PALETTE["phosphor_bright"]
	question_label.add_theme_color_override("font_color", desc_color)
	question_label.modulate.a = 0.0
	await get_tree().process_frame
	if pca:
		pca.reveal(question_label, {"duration": 0.5, "block_size": 8})
	else:
		question_label.modulate.a = 1.0
	await get_tree().create_timer(3.0).timeout

	# Phase 4: Traits summary
	if traits.size() > 0:
		var traits_text := "Tes traits:\n" + ", ".join(traits)
		if pca:
			pca.dissolve(question_label, {"duration": 0.4, "block_size": 8})
		else:
			question_label.modulate.a = 0.0
		await get_tree().create_timer(0.5).timeout
		question_label.text = traits_text
		question_label.add_theme_font_size_override("font_size", 20)
		var traits_color: Color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
		question_label.add_theme_color_override("font_color", traits_color)
		question_label.modulate.a = 0.0
		await get_tree().process_frame
		if pca:
			pca.reveal(question_label, {"duration": 0.5, "block_size": 8})
		else:
			question_label.modulate.a = 1.0
		await get_tree().create_timer(2.0).timeout

	# Final dissolve and transition
	if pca:
		pca.dissolve(question_label, {"duration": 0.5, "block_size": 8})
	else:
		question_label.modulate.a = 0.0
	await get_tree().create_timer(FADE_DURATION).timeout
	_transition_to_next_scene()


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
		PixelTransition.transition_to(NEXT_SCENE)
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
