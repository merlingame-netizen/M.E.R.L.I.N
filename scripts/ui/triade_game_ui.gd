## ═══════════════════════════════════════════════════════════════════════════════
## TRIADE Game UI — Main Gameplay Interface (v0.3.0)
## ═══════════════════════════════════════════════════════════════════════════════
## UI for TRIADE system: 3 Aspects, 3 States, 3 Options per card.
## Celtic symbols: Sanglier (Corps), Corbeau (Ame), Cerf (Monde)
## ═══════════════════════════════════════════════════════════════════════════════

extends Control
class_name TriadeGameUI

signal option_chosen(option: int)  # 0=LEFT, 1=CENTER, 2=RIGHT
signal skill_activated(skill_id: String)
signal pause_requested

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

const ASPECT_ICONS := {
	"Corps": "🐗",  # Sanglier
	"Ame": "🐦‍⬛",  # Corbeau
	"Monde": "🦌",  # Cerf
}

const ASPECT_COLORS := {
	"Corps": Color(0.8, 0.4, 0.2),   # Orange-brown (earth)
	"Ame": Color(0.5, 0.3, 0.7),     # Purple (spirit)
	"Monde": Color(0.3, 0.6, 0.4),   # Green (nature)
}

const STATE_LABELS := {
	DruConstants.AspectState.BAS: "▼",
	DruConstants.AspectState.EQUILIBRE: "●",
	DruConstants.AspectState.HAUT: "▲",
}

const SOUFFLE_ICON := "🌀"
const SOUFFLE_EMPTY := "○"

const OPTION_KEYS := {
	DruConstants.CardOption.LEFT: "A",
	DruConstants.CardOption.CENTER: "B",
	DruConstants.CardOption.RIGHT: "C",
}

# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCES (set by scene or dynamically created)
# ═══════════════════════════════════════════════════════════════════════════════

var aspect_panel: Control
var aspect_displays: Dictionary = {}  # {"Corps": {container, icon, state_indicator}}

var souffle_panel: Control
var souffle_display: HBoxContainer

var card_container: Control
var card_panel: Panel
var card_text: RichTextLabel
var card_speaker: Label

var options_container: HBoxContainer
var option_buttons: Array[Button] = []
var option_labels: Array[Label] = []

var info_panel: Control
var mission_label: Label
var cards_label: Label

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var current_card: Dictionary = {}
var current_aspects: Dictionary = {}
var current_souffle: int = 3

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_setup_ui()
	_update_aspects({
		"Corps": DruConstants.AspectState.EQUILIBRE,
		"Ame": DruConstants.AspectState.EQUILIBRE,
		"Monde": DruConstants.AspectState.EQUILIBRE,
	})
	_update_souffle(DruConstants.SOUFFLE_START)


func _setup_ui() -> void:
	# Main layout
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# Top bar: Aspects + Souffle
	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", 30)
	main_vbox.add_child(top_bar)

	_create_aspect_displays(top_bar)
	_create_souffle_display(top_bar)

	# Spacer
	var spacer1 := Control.new()
	spacer1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer1)

	# Card area
	_create_card_display(main_vbox)

	# Spacer
	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer2)

	# Options bar (3 buttons)
	_create_options_bar(main_vbox)

	# Bottom info bar
	_create_info_bar(main_vbox)


func _create_aspect_displays(parent: Control) -> void:
	aspect_panel = HBoxContainer.new()
	aspect_panel.add_theme_constant_override("separation", 20)
	parent.add_child(aspect_panel)

	for aspect in DruConstants.TRIADE_ASPECTS:
		var container := VBoxContainer.new()
		container.alignment = BoxContainer.ALIGNMENT_CENTER

		# Animal icon
		var icon := Label.new()
		icon.text = ASPECT_ICONS.get(aspect, "?")
		icon.add_theme_font_size_override("font_size", 32)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(icon)

		# Aspect name
		var name_label := Label.new()
		name_label.text = aspect
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", ASPECT_COLORS.get(aspect, Color.WHITE))
		container.add_child(name_label)

		# State indicator (3 circles)
		var state_container := HBoxContainer.new()
		state_container.alignment = BoxContainer.ALIGNMENT_CENTER
		state_container.add_theme_constant_override("separation", 4)

		for i in range(3):  # -1, 0, 1 mapped to 0, 1, 2
			var circle := Label.new()
			circle.text = "○"
			circle.add_theme_font_size_override("font_size", 16)
			circle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			state_container.add_child(circle)

		container.add_child(state_container)

		# State name
		var state_name := Label.new()
		state_name.text = "Equilibre"
		state_name.add_theme_font_size_override("font_size", 12)
		state_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_name.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		container.add_child(state_name)

		aspect_panel.add_child(container)

		aspect_displays[aspect] = {
			"container": container,
			"icon": icon,
			"state_container": state_container,
			"state_name": state_name,
		}


func _create_souffle_display(parent: Control) -> void:
	souffle_panel = VBoxContainer.new()
	souffle_panel.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := Label.new()
	title.text = "Souffle"
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	souffle_panel.add_child(title)

	souffle_display = HBoxContainer.new()
	souffle_display.alignment = BoxContainer.ALIGNMENT_CENTER
	souffle_display.add_theme_constant_override("separation", 4)

	for i in range(DruConstants.SOUFFLE_MAX):
		var icon := Label.new()
		icon.text = SOUFFLE_EMPTY
		icon.add_theme_font_size_override("font_size", 20)
		souffle_display.add_child(icon)

	souffle_panel.add_child(souffle_display)
	parent.add_child(souffle_panel)


func _create_card_display(parent: Control) -> void:
	card_container = CenterContainer.new()
	card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	card_panel = Panel.new()
	card_panel.custom_minimum_size = Vector2(400, 250)

	var card_vbox := VBoxContainer.new()
	card_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_vbox.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.add_child(card_vbox)
	card_panel.add_child(margin)

	# Speaker
	card_speaker = Label.new()
	card_speaker.text = "MERLIN"
	card_speaker.add_theme_font_size_override("font_size", 18)
	card_speaker.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	card_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(card_speaker)

	# Card text
	card_text = RichTextLabel.new()
	card_text.text = "Le vent souffle sur les landes..."
	card_text.bbcode_enabled = true
	card_text.fit_content = true
	card_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_text.add_theme_font_size_override("normal_font_size", 16)
	card_vbox.add_child(card_text)

	card_container.add_child(card_panel)
	parent.add_child(card_container)


func _create_options_bar(parent: Control) -> void:
	options_container = HBoxContainer.new()
	options_container.alignment = BoxContainer.ALIGNMENT_CENTER
	options_container.add_theme_constant_override("separation", 20)
	parent.add_child(options_container)

	var option_configs := [
		{"key": "A", "pos": "left", "color": Color(0.4, 0.6, 0.8)},
		{"key": "B", "pos": "center", "color": Color(0.8, 0.7, 0.3)},
		{"key": "C", "pos": "right", "color": Color(0.8, 0.4, 0.4)},
	]

	for i in range(3):
		var config = option_configs[i]
		var option_vbox := VBoxContainer.new()
		option_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

		# Option label
		var label := Label.new()
		label.text = "Option"
		label.add_theme_font_size_override("font_size", 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		option_labels.append(label)
		option_vbox.add_child(label)

		# Button
		var btn := Button.new()
		btn.text = "[%s] CHOISIR" % config["key"]
		btn.custom_minimum_size = Vector2(120, 50)
		btn.add_theme_color_override("font_color", config["color"])
		btn.pressed.connect(_on_option_pressed.bind(i))
		option_buttons.append(btn)
		option_vbox.add_child(btn)

		# Cost indicator (for center)
		if i == 1:  # Center
			var cost := Label.new()
			cost.text = "(1 %s)" % SOUFFLE_ICON
			cost.add_theme_font_size_override("font_size", 11)
			cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cost.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			option_vbox.add_child(cost)

		options_container.add_child(option_vbox)


func _create_info_bar(parent: Control) -> void:
	info_panel = HBoxContainer.new()
	info_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	info_panel.add_theme_constant_override("separation", 40)

	mission_label = Label.new()
	mission_label.text = "Mission: ???"
	mission_label.add_theme_font_size_override("font_size", 14)
	info_panel.add_child(mission_label)

	cards_label = Label.new()
	cards_label.text = "Cartes: 0"
	cards_label.add_theme_font_size_override("font_size", 14)
	info_panel.add_child(cards_label)

	parent.add_child(info_panel)


# ═══════════════════════════════════════════════════════════════════════════════
# UPDATE METHODS
# ═══════════════════════════════════════════════════════════════════════════════

func update_aspects(aspects: Dictionary) -> void:
	_update_aspects(aspects)


func _update_aspects(aspects: Dictionary) -> void:
	current_aspects = aspects

	for aspect in DruConstants.TRIADE_ASPECTS:
		var display = aspect_displays.get(aspect, {})
		if display.is_empty():
			continue

		var aspect_state: int = int(aspects.get(aspect, DruConstants.AspectState.EQUILIBRE))

		# Update state indicator circles
		var state_container: HBoxContainer = display.get("state_container")
		if state_container:
			for i in range(3):
				var circle: Label = state_container.get_child(i) as Label
				if circle:
					var target_state: int = i - 1  # -1, 0, 1
					if target_state == aspect_state:
						circle.text = "●"
						circle.add_theme_color_override("font_color", ASPECT_COLORS.get(aspect, Color.WHITE))
					else:
						circle.text = "○"
						circle.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

		# Update state name
		var state_name: Label = display.get("state_name")
		if state_name:
			var info = DruConstants.TRIADE_ASPECT_INFO.get(aspect, {})
			var states = info.get("states", {})
			state_name.text = str(states.get(aspect_state, "???"))

			# Color based on extreme state
			if aspect_state == DruConstants.AspectState.EQUILIBRE:
				state_name.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			else:
				state_name.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))

		# Animate icon if extreme
		var icon: Label = display.get("icon")
		if icon:
			if aspect_state != DruConstants.AspectState.EQUILIBRE:
				# Pulse effect for extreme states
				var tween := create_tween()
				tween.set_loops(2)
				tween.tween_property(icon, "modulate:a", 0.5, 0.3)
				tween.tween_property(icon, "modulate:a", 1.0, 0.3)


func update_souffle(souffle: int) -> void:
	_update_souffle(souffle)


func _update_souffle(souffle: int) -> void:
	current_souffle = souffle

	if not souffle_display:
		return

	for i in range(DruConstants.SOUFFLE_MAX):
		var icon: Label = souffle_display.get_child(i) as Label
		if icon:
			if i < souffle:
				icon.text = SOUFFLE_ICON
				icon.add_theme_color_override("font_color", Color(0.3, 0.7, 0.9))
			else:
				icon.text = SOUFFLE_EMPTY
				icon.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

	# Update center button based on souffle
	if option_buttons.size() > 1:
		var center_btn := option_buttons[1]
		if souffle < DruConstants.SOUFFLE_CENTER_COST:
			center_btn.text = "[B] RISQUE!"
			center_btn.add_theme_color_override("font_color", Color(0.9, 0.4, 0.2))
		else:
			center_btn.text = "[B] CHOISIR"
			center_btn.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))


func display_card(card: Dictionary) -> void:
	current_card = card

	# Update text
	if card_text:
		card_text.text = card.get("text", "...")

	# Update speaker
	if card_speaker:
		var speaker: String = card.get("speaker", "")
		card_speaker.text = speaker
		card_speaker.visible = not speaker.is_empty()

	# Update options
	var options: Array = card.get("options", [])
	for i in range(mini(options.size(), 3)):
		var option: Dictionary = options[i]
		if i < option_labels.size():
			option_labels[i].text = option.get("label", "...")
		if i < option_buttons.size():
			var cost: int = int(option.get("cost", 0))
			var key: String = OPTION_KEYS.get(i, "?")
			if cost > 0:
				option_buttons[i].text = "[%s] %s" % [key, option.get("label", "?")]
			else:
				option_buttons[i].text = "[%s] %s" % [key, option.get("label", "?")]


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


# ═══════════════════════════════════════════════════════════════════════════════
# INPUT HANDLING
# ═══════════════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		pause_requested.emit()
		return

	# Keyboard shortcuts for options
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_A, KEY_LEFT:
				_on_option_pressed(DruConstants.CardOption.LEFT)
			KEY_B, KEY_UP:
				_on_option_pressed(DruConstants.CardOption.CENTER)
			KEY_C, KEY_RIGHT:
				_on_option_pressed(DruConstants.CardOption.RIGHT)


func _on_option_pressed(option: int) -> void:
	if current_card.is_empty():
		return

	# Animate button
	if option < option_buttons.size():
		var btn := option_buttons[option]
		var tween := create_tween()
		tween.tween_property(btn, "modulate", Color(1.5, 1.5, 1.5), 0.1)
		tween.tween_property(btn, "modulate", Color.WHITE, 0.1)

	option_chosen.emit(option)


# ═══════════════════════════════════════════════════════════════════════════════
# END SCREEN
# ═══════════════════════════════════════════════════════════════════════════════

func show_end_screen(ending: Dictionary) -> void:
	# Hide main UI
	if card_container:
		card_container.visible = false
	if options_container:
		options_container.visible = false

	# Create overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	center.add_child(vbox)

	# Ending title
	var title := Label.new()
	var ending_data: Dictionary = ending.get("ending", {})
	title.text = ending_data.get("title", "Fin")
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Color based on victory
	if ending.get("victory", false):
		title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		title.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))

	vbox.add_child(title)

	# Ending text
	if ending_data.has("text"):
		var text := Label.new()
		text.text = ending_data.get("text", "")
		text.add_theme_font_size_override("font_size", 16)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size.x = 400
		vbox.add_child(text)

	# Score
	var score := Label.new()
	score.text = "Score: %d" % ending.get("score", 0)
	score.add_theme_font_size_override("font_size", 24)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	vbox.add_child(score)

	# Stats
	var stats := Label.new()
	stats.text = "Cartes: %d | Jours: %d" % [
		ending.get("cards_played", 0),
		ending.get("days_survived", 1)
	]
	stats.add_theme_font_size_override("font_size", 14)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)

	# Aspects final state
	var aspects_label := Label.new()
	var aspects_text := "Aspects finaux: "
	for aspect in DruConstants.TRIADE_ASPECTS:
		var state_val: int = current_aspects.get(aspect, 0)
		var info = DruConstants.TRIADE_ASPECT_INFO.get(aspect, {})
		var states = info.get("states", {})
		aspects_text += "%s %s (%s) | " % [ASPECT_ICONS.get(aspect, "?"), aspect, states.get(state_val, "?")]
	aspects_label.text = aspects_text.trim_suffix(" | ")
	aspects_label.add_theme_font_size_override("font_size", 12)
	aspects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(aspects_label)

	# Return button
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	vbox.add_child(spacer)

	var btn := Button.new()
	btn.text = "Retour au menu"
	btn.custom_minimum_size = Vector2(200, 50)
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn"))
	vbox.add_child(btn)
