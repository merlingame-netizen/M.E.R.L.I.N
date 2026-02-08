## ═══════════════════════════════════════════════════════════════════════════════
## Reigns Game UI — Main Gameplay Interface
## ═══════════════════════════════════════════════════════════════════════════════
## Handles the Reigns-style card display and swipe interaction.
## Updated 2026-02-05 for Reigns-style gameplay.
## ═══════════════════════════════════════════════════════════════════════════════

extends Control
class_name ReignsGameUI

signal choice_made(direction: String)
signal skill_activated(skill_id: String)
signal pause_requested

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

const SWIPE_THRESHOLD := 100.0
const SWIPE_MAX_ROTATION := 15.0
const CARD_RETURN_SPEED := 10.0
const GAUGE_ANIMATE_SPEED := 2.0

# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCES
# ═══════════════════════════════════════════════════════════════════════════════

@onready var gauge_vigueur: ProgressBar = $GaugePanel/VigueurBar
@onready var gauge_esprit: ProgressBar = $GaugePanel/EspritBar
@onready var gauge_faveur: ProgressBar = $GaugePanel/FaveurBar
@onready var gauge_ressources: ProgressBar = $GaugePanel/RessourcesBar

@onready var card_container: Control = $CardContainer
@onready var card_panel: Panel = $CardContainer/CardPanel
@onready var card_text: RichTextLabel = $CardContainer/CardPanel/CardText
@onready var card_speaker: Label = $CardContainer/CardPanel/Speaker
@onready var left_label: Label = $CardContainer/LeftLabel
@onready var right_label: Label = $CardContainer/RightLabel
@onready var left_hint: Label = $CardContainer/LeftHint
@onready var right_hint: Label = $CardContainer/RightHint

@onready var bestiole_panel: Panel = $BestiolePanel
@onready var bestiole_bond: Label = $BestiolePanel/BondLabel
@onready var bestiole_mood: Label = $BestiolePanel/MoodLabel
@onready var skill_container: HBoxContainer = $BestiolePanel/SkillContainer

@onready var day_label: Label = $InfoPanel/DayLabel
@onready var cards_label: Label = $InfoPanel/CardsLabel

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var current_card: Dictionary = {}
var is_dragging := false
var drag_start_pos := Vector2.ZERO
var card_original_pos := Vector2.ZERO
var target_gauges: Dictionary = {}
var current_gauges: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Initialize gauges
	current_gauges = {
		"Vigueur": 50.0,
		"Esprit": 50.0,
		"Faveur": 50.0,
		"Ressources": 50.0,
	}
	target_gauges = current_gauges.duplicate()
	_update_gauge_displays()

	# Store original card position
	if card_panel:
		card_original_pos = card_panel.position

	# Hide labels initially
	_set_choice_labels_visible(false)


func _process(delta: float) -> void:
	# Animate gauges
	for gauge_name in current_gauges.keys():
		var current = current_gauges[gauge_name]
		var target = target_gauges.get(gauge_name, current)
		if abs(current - target) > 0.5:
			current_gauges[gauge_name] = lerp(current, target, delta * GAUGE_ANIMATE_SPEED)
	_update_gauge_displays()

	# Return card to center if not dragging
	if not is_dragging and card_panel:
		card_panel.position = card_panel.position.lerp(card_original_pos, delta * CARD_RETURN_SPEED)
		card_panel.rotation = lerp(card_panel.rotation, 0.0, delta * CARD_RETURN_SPEED)
		_update_choice_opacity()


# ═══════════════════════════════════════════════════════════════════════════════
# CARD DISPLAY
# ═══════════════════════════════════════════════════════════════════════════════

func display_card(card: Dictionary) -> void:
	"""Display a new card with text and options."""
	current_card = card

	# Set card text
	if card_text:
		card_text.text = card.get("text", "...")

	# Set speaker
	if card_speaker:
		var speaker = card.get("speaker", "")
		card_speaker.text = speaker if not speaker.is_empty() else ""
		card_speaker.visible = not speaker.is_empty()

	# Set choice labels
	for option in card.get("options", []):
		var direction = option.get("direction", "")
		var label_text = option.get("label", "")
		var hint_text = option.get("preview_hint", "")

		if direction == "left":
			if left_label:
				left_label.text = "< " + label_text
			if left_hint:
				left_hint.text = hint_text
		elif direction == "right":
			if right_label:
				right_label.text = label_text + " >"
			if right_hint:
				right_hint.text = hint_text

	# Reset card position and show labels
	if card_panel:
		card_panel.position = card_original_pos
		card_panel.rotation = 0.0

	_set_choice_labels_visible(true)


func _set_choice_labels_visible(is_visible: bool) -> void:
	if left_label:
		left_label.modulate.a = 1.0 if is_visible else 0.0
	if right_label:
		right_label.modulate.a = 1.0 if is_visible else 0.0
	if left_hint:
		left_hint.modulate.a = 1.0 if is_visible else 0.0
	if right_hint:
		right_hint.modulate.a = 1.0 if is_visible else 0.0


func _update_choice_opacity() -> void:
	"""Update choice label opacity based on card position."""
	if not card_panel:
		return

	var offset = card_panel.position.x - card_original_pos.x
	var normalized = clampf(offset / SWIPE_THRESHOLD, -1.0, 1.0)

	# Left choice becomes visible when swiping left (negative offset)
	if left_label:
		left_label.modulate.a = clampf(-normalized, 0.0, 1.0)
	if left_hint:
		left_hint.modulate.a = clampf(-normalized * 0.7, 0.0, 1.0)

	# Right choice becomes visible when swiping right (positive offset)
	if right_label:
		right_label.modulate.a = clampf(normalized, 0.0, 1.0)
	if right_hint:
		right_hint.modulate.a = clampf(normalized * 0.7, 0.0, 1.0)


# ═══════════════════════════════════════════════════════════════════════════════
# GAUGE DISPLAY
# ═══════════════════════════════════════════════════════════════════════════════

func update_gauges(gauges: Dictionary) -> void:
	"""Set target gauge values for animation."""
	for gauge_name in gauges.keys():
		target_gauges[gauge_name] = float(gauges[gauge_name])


func _update_gauge_displays() -> void:
	"""Update the visual gauge bars."""
	if gauge_vigueur:
		gauge_vigueur.value = current_gauges.get("Vigueur", 50)
		_style_gauge_bar(gauge_vigueur, current_gauges.get("Vigueur", 50))

	if gauge_esprit:
		gauge_esprit.value = current_gauges.get("Esprit", 50)
		_style_gauge_bar(gauge_esprit, current_gauges.get("Esprit", 50))

	if gauge_faveur:
		gauge_faveur.value = current_gauges.get("Faveur", 50)
		_style_gauge_bar(gauge_faveur, current_gauges.get("Faveur", 50))

	if gauge_ressources:
		gauge_ressources.value = current_gauges.get("Ressources", 50)
		_style_gauge_bar(gauge_ressources, current_gauges.get("Ressources", 50))


func _style_gauge_bar(bar: ProgressBar, value: float) -> void:
	"""Apply critical styling to gauge bars."""
	var stylebox = bar.get_theme_stylebox("fill")
	if stylebox is StyleBoxFlat:
		if value <= MerlinConstants.REIGNS_GAUGE_CRITICAL_LOW or value >= MerlinConstants.REIGNS_GAUGE_CRITICAL_HIGH:
			stylebox.bg_color = Color(0.9, 0.2, 0.2)  # Red for critical
		else:
			stylebox.bg_color = Color(0.3, 0.7, 0.3)  # Green for normal


# ═══════════════════════════════════════════════════════════════════════════════
# BESTIOLE DISPLAY
# ═══════════════════════════════════════════════════════════════════════════════

func update_bestiole(bestiole_data: Dictionary) -> void:
	"""Update bestiole status display."""
	if bestiole_bond:
		var bond = int(bestiole_data.get("bond", 50))
		bestiole_bond.text = "Lien: %d%%" % bond

	if bestiole_mood:
		var mood = bestiole_data.get("mood", "neutral")
		bestiole_mood.text = _mood_to_emoji(mood)


func update_skills(skills: Array, cooldowns: Dictionary) -> void:
	"""Update skill buttons display."""
	if not skill_container:
		return

	# Clear existing buttons
	for child in skill_container.get_children():
		child.queue_free()

	# Create skill buttons
	for skill_id in skills:
		var skill_data = MerlinConstants.OGHAM_SKILLS.get(skill_id, {})
		var cooldown = int(cooldowns.get(skill_id, 0))

		var btn = Button.new()
		btn.text = skill_data.get("name", skill_id)
		btn.disabled = cooldown > 0
		btn.tooltip_text = "%s (CD: %d)" % [skill_data.get("effect", ""), cooldown]
		btn.pressed.connect(_on_skill_pressed.bind(skill_id))

		if cooldown > 0:
			btn.text += " (%d)" % cooldown

		skill_container.add_child(btn)


func _mood_to_emoji(mood: String) -> String:
	match mood:
		"happy": return ":)"
		"content": return ":|"
		"tired": return ":/"
		"distressed": return ":("
		_: return ":|"


func _on_skill_pressed(skill_id: String) -> void:
	skill_activated.emit(skill_id)


# ═══════════════════════════════════════════════════════════════════════════════
# INFO DISPLAY
# ═══════════════════════════════════════════════════════════════════════════════

func update_info(day: int, cards_played: int) -> void:
	"""Update day and cards counter."""
	if day_label:
		day_label.text = "Jour %d" % day
	if cards_label:
		cards_label.text = "Cartes: %d" % cards_played


# ═══════════════════════════════════════════════════════════════════════════════
# INPUT HANDLING — Swipe & Click
# ═══════════════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	# Keyboard shortcuts
	if event.is_action_pressed("ui_cancel"):
		pause_requested.emit()
		return

	if event.is_action_pressed("ui_left"):
		_make_choice("left")
		return

	if event.is_action_pressed("ui_right"):
		_make_choice("right")
		return


func _gui_input(event: InputEvent) -> void:
	# Mouse/touch drag
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.position)
			else:
				_end_drag()

	elif event is InputEventMouseMotion and is_dragging:
		_update_drag(event.position)

	# Touch events
	elif event is InputEventScreenTouch:
		if event.pressed:
			_start_drag(event.position)
		else:
			_end_drag()

	elif event is InputEventScreenDrag and is_dragging:
		_update_drag(event.position)


func _start_drag(pos: Vector2) -> void:
	is_dragging = true
	drag_start_pos = pos


func _update_drag(pos: Vector2) -> void:
	if not card_panel:
		return

	var delta = pos - drag_start_pos
	card_panel.position = card_original_pos + Vector2(delta.x, delta.y * 0.3)

	# Rotate based on horizontal movement
	var rotation_factor = clampf(delta.x / SWIPE_THRESHOLD, -1.0, 1.0)
	card_panel.rotation_degrees = rotation_factor * SWIPE_MAX_ROTATION

	_update_choice_opacity()


func _end_drag() -> void:
	if not is_dragging:
		return

	is_dragging = false

	if not card_panel:
		return

	var offset = card_panel.position.x - card_original_pos.x

	if offset < -SWIPE_THRESHOLD:
		_make_choice("left")
	elif offset > SWIPE_THRESHOLD:
		_make_choice("right")
	# else: card returns to center automatically in _process


func _make_choice(direction: String) -> void:
	"""Confirm a choice and emit signal."""
	if current_card.is_empty():
		return

	# Animate card off-screen
	if card_panel:
		var target_x = -500 if direction == "left" else get_viewport_rect().size.x + 500
		var tween = create_tween()
		tween.tween_property(card_panel, "position:x", target_x, 0.2)
		tween.tween_callback(func(): choice_made.emit(direction))
	else:
		choice_made.emit(direction)


# ═══════════════════════════════════════════════════════════════════════════════
# END SCREEN
# ═══════════════════════════════════════════════════════════════════════════════

func show_end_screen(ending: Dictionary) -> void:
	"""Display the run end screen."""
	# Hide card
	if card_container:
		card_container.visible = false

	# Create end screen overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(vbox)

	var title = Label.new()
	title.text = ending.get("ending", {}).get("title", "Fin")
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var text = Label.new()
	text.text = ending.get("ending", {}).get("text", "")
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(text)

	var score = Label.new()
	score.text = "Score: %d" % ending.get("score", 0)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score)

	var stats = Label.new()
	stats.text = "Cartes jouees: %d | Jours: %d" % [
		ending.get("cards_played", 0),
		ending.get("days_survived", 0)
	]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)

	var btn = Button.new()
	btn.text = "Retour au menu"
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn"))
	vbox.add_child(btn)
