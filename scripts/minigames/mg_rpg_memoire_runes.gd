extends MiniGameBase
## RPG Memoire des Runes — Esprit test. 4-6 oghams flash 1.5s, then disappear.
## Player must click them back in order from a 6-button candidate row.
## Score 0-100 = % of correct sequence.

const REVEAL_DURATION_S: float = 1.5
const RUNE_CANDIDATES: Array[String] = ["ᚐ", "ᚁ", "ᚂ", "ᚃ", "ᚄ", "ᚅ", "ᚆ", "ᚇ"]

var _sequence: Array[String] = []
var _player_input: Array[String] = []
var _phase_reveal: bool = true
var _reveal_label: Label
var _input_label: Label
var _candidates_row: HBoxContainer


func _on_start() -> void:
	# Difficulty 1-10 → 4 runes (easy) up to 7 (hard)
	var seq_len: int = clampi(3 + int(_difficulty / 3), 4, 7)
	for i in seq_len:
		_sequence.append(RUNE_CANDIDATES[randi() % RUNE_CANDIDATES.size()])
	_build()
	# Reveal phase
	_reveal_label.text = " ".join(_sequence)
	await get_tree().create_timer(REVEAL_DURATION_S).timeout
	if _finished:
		return
	# Hide and switch to input phase
	_phase_reveal = false
	_reveal_label.text = ""
	_input_label.text = "Retape la sequence :"
	_candidates_row.visible = true


func _build() -> void:
	if not _in_card_mode:
		_build_overlay()
	custom_minimum_size = Vector2(0, 130)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	_input_label = Label.new()
	_input_label.text = "Memorise..."
	_input_label.add_theme_font_size_override("font_size", 13)
	_input_label.add_theme_color_override("font_color", Color(0.45, 0.30, 0.15))
	_input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_input_label)
	_reveal_label = Label.new()
	_reveal_label.add_theme_font_size_override("font_size", 32)
	_reveal_label.add_theme_color_override("font_color", Color(0.65, 0.13, 0.10))
	_reveal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_reveal_label)
	_candidates_row = HBoxContainer.new()
	_candidates_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_candidates_row.add_theme_constant_override("separation", 8)
	_candidates_row.visible = false
	vbox.add_child(_candidates_row)
	for rune in RUNE_CANDIDATES:
		var b: Button = Button.new()
		b.text = rune
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", Color(0.22, 0.13, 0.07))
		b.custom_minimum_size = Vector2(40, 40)
		var s: StyleBoxFlat = StyleBoxFlat.new()
		s.bg_color = Color(0.84, 0.74, 0.55)
		s.border_color = Color(0.45, 0.28, 0.12)
		s.set_border_width_all(2)
		s.set_corner_radius_all(4)
		b.add_theme_stylebox_override("normal", s)
		b.pressed.connect(_on_rune_pressed.bind(rune))
		_candidates_row.add_child(b)


func _on_rune_pressed(rune: String) -> void:
	if _phase_reveal or _finished:
		return
	_player_input.append(rune)
	_input_label.text = "Saisi : %s" % " ".join(_player_input)
	if _player_input.size() >= _sequence.size():
		_finalize()


func _finalize() -> void:
	var correct: int = 0
	for i in mini(_player_input.size(), _sequence.size()):
		if _player_input[i] == _sequence[i]:
			correct += 1
	var score: int = int(round(float(correct) / float(_sequence.size()) * 100.0))
	var success: bool = correct == _sequence.size()
	_complete(success, score)
