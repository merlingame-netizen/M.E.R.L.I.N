extends MiniGameBase
## Enigme d'Ogham — Logic pattern puzzle with Ogham symbols (logic-based)

const OGHAMS: Array[String] = ["ᚁ", "ᚂ", "ᚃ", "ᚄ", "ᚅ", "ᚆ", "ᚇ", "ᚈ", "ᚉ", "ᚊ"]

enum PatternType { REPEAT, ALTERNATE, ASCENDING, DESCENDING }

var pattern_sequence: Array[String] = []
var correct_answer: String = ""
var choices: Array[String] = []

var sequence_label: Label
var question_label: Label
var choice_buttons: Array[Button] = []

func _on_start() -> void:
	_build_overlay()
	_generate_pattern()
	_build_ui()

func _generate_pattern() -> void:
	var pattern_type: PatternType

	# Difficulty affects pattern complexity
	if _difficulty <= 3:
		pattern_type = PatternType.REPEAT
	elif _difficulty <= 6:
		pattern_type = [PatternType.REPEAT, PatternType.ALTERNATE][randi() % 2]
	elif _difficulty <= 8:
		pattern_type = [PatternType.ALTERNATE, PatternType.ASCENDING][randi() % 2]
	else:
		pattern_type = [PatternType.ASCENDING, PatternType.DESCENDING][randi() % 2]

	match pattern_type:
		PatternType.REPEAT:
			_generate_repeat_pattern()
		PatternType.ALTERNATE:
			_generate_alternate_pattern()
		PatternType.ASCENDING:
			_generate_ascending_pattern()
		PatternType.DESCENDING:
			_generate_descending_pattern()

	# Generate 2 wrong choices
	choices = [correct_answer]
	while choices.size() < 3:
		var wrong: String = OGHAMS[randi() % OGHAMS.size()]
		if not choices.has(wrong):
			choices.append(wrong)
	choices.shuffle()

func _generate_repeat_pattern() -> void:
	# A A A A ?
	var symbol: String = OGHAMS[randi() % OGHAMS.size()]
	pattern_sequence = [symbol, symbol, symbol, symbol]
	correct_answer = symbol

func _generate_alternate_pattern() -> void:
	# A B A B ?
	var a: String = OGHAMS[randi() % OGHAMS.size()]
	var b: String = OGHAMS[randi() % OGHAMS.size()]
	while b == a:
		b = OGHAMS[randi() % OGHAMS.size()]
	pattern_sequence = [a, b, a, b]
	correct_answer = a

func _generate_ascending_pattern() -> void:
	# Use consecutive Oghams
	var start_idx: int = randi() % (OGHAMS.size() - 5)
	pattern_sequence = [
		OGHAMS[start_idx],
		OGHAMS[start_idx + 1],
		OGHAMS[start_idx + 2],
		OGHAMS[start_idx + 3]
	]
	correct_answer = OGHAMS[start_idx + 4]

func _generate_descending_pattern() -> void:
	# Use consecutive Oghams in reverse
	var start_idx: int = 5 + randi() % (OGHAMS.size() - 5)
	pattern_sequence = [
		OGHAMS[start_idx],
		OGHAMS[start_idx - 1],
		OGHAMS[start_idx - 2],
		OGHAMS[start_idx - 3]
	]
	correct_answer = OGHAMS[start_idx - 4]

func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.position = Vector2(300, 120)
	vbox.custom_minimum_size = Vector2(600, 600)
	add_child(vbox)

	var title: Label = _make_label("Énigme d'Ogham", 32, MG_PALETTE.gold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_make_spacer(30))

	var desc: Label = _make_label("Complétez la séquence d'Oghams.", 20, MG_PALETTE.ink)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	vbox.add_child(_make_spacer(50))

	# Sequence display
	var sequence_text: String = ""
	for symbol in pattern_sequence:
		sequence_text += symbol + "  "
	sequence_text += "?"

	sequence_label = _make_label(sequence_text, 64, MG_PALETTE.accent)
	sequence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sequence_label)

	vbox.add_child(_make_spacer(50))

	question_label = _make_label("Quel est le symbole manquant ?", 22, MG_PALETTE.ink)
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(question_label)

	vbox.add_child(_make_spacer(40))

	# Choice buttons
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	for i in range(3):
		var button: Button = Button.new()
		button.text = choices[i]
		button.custom_minimum_size = Vector2(140, 140)
		button.add_theme_font_size_override("font_size", 56)
		button.add_theme_color_override("font_color", MG_PALETTE.ink)
		button.add_theme_color_override("font_hover_color", MG_PALETTE.accent)
		button.pressed.connect(_on_choice_selected.bind(choices[i]))
		choice_buttons.append(button)
		hbox.add_child(button)

		if i < 2:
			hbox.add_child(_make_spacer_h(20))

func _make_spacer(height: int) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _make_spacer_h(width: int) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(width, 0)
	return spacer

func _on_key_pressed(keycode: int) -> void:
	# Keys 1-3 map to choice buttons left to right
	if keycode >= KEY_1 and keycode <= KEY_3:
		var choice_index: int = keycode - KEY_1
		if choice_index < choice_buttons.size():
			_on_choice_selected(choice_buttons[choice_index].text)


func _on_choice_selected(choice: String) -> void:
	# Disable all buttons
	for button in choice_buttons:
		button.disabled = true

	var correct: bool = choice == correct_answer
	# Capture answer time BEFORE feedback delay (base _complete handles SFX)
	var answer_time_ms: int = Time.get_ticks_msec()

	# Visual feedback
	for button in choice_buttons:
		if button.text == correct_answer:
			button.add_theme_color_override("font_color", MG_PALETTE.green)
		elif button.text == choice and not correct:
			button.add_theme_color_override("font_color", MG_PALETTE.red)

	question_label.text = "Correct !" if correct else "Raté... La réponse était : " + correct_answer
	question_label.modulate = MG_PALETTE.green if correct else MG_PALETTE.red

	await get_tree().create_timer(2.5).timeout

	# Proportional scoring: base 60 for correct + time bonus (up to 40, decays over ~10s)
	# Wrong answer: partial credit 10-30 based on difficulty
	var score: int = 0
	if correct:
		var elapsed_s: float = float(answer_time_ms - _start_time_ms) / 1000.0
		var time_bonus: int = clampi(int(40.0 - elapsed_s * 4.0), 0, 40)
		score = 60 + time_bonus
	else:
		score = clampi(int(_difficulty * 3.0), 10, 30)
	_complete(correct, score)
