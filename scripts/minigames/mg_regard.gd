## MG_REGARD — Regard Acéré (Perception)
## Memory sequence: symbols flash in order, player must reproduce the sequence.
## Sequence length = 3 + difficulty/3. Score based on correct symbols in order.

extends MiniGameBase

const SYMBOLS := ["◆", "●", "▲", "■", "★"]

var _sequence: Array[int] = []
var _player_sequence: Array[int] = []
var _seq_length: int = 3
var _showing: bool = false
var _inputting: bool = false
var _current_show: int = 0

var _symbol_buttons: Array[Button] = []
var _display_label: Label
var _status_label: Label
var _feedback_label: Label


func _on_start() -> void:
	_build_overlay()

	_seq_length = 3 + int(_difficulty / 3.0)
	_seq_length = mini(_seq_length, 7)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -240
	vbox.offset_top = -240
	vbox.offset_right = 240
	vbox.offset_bottom = 240
	vbox.add_theme_constant_override("separation", 15)
	add_child(vbox)

	var title := _make_label("REGARD ACÉRÉ", 28, MG_PALETTE.accent)
	vbox.add_child(title)

	var subtitle := _make_label("Mémorise la séquence, puis reproduis-la!", 14)
	vbox.add_child(subtitle)

	_status_label = _make_label("Observe la séquence...", 20, MG_PALETTE.ink)
	vbox.add_child(_status_label)

	_display_label = _make_label("", 56, MG_PALETTE.gold)
	_display_label.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(_display_label)

	# Symbol buttons
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	for i in range(SYMBOLS.size()):
		var btn := Button.new()
		btn.text = SYMBOLS[i]
		btn.custom_minimum_size = Vector2(70, 70)
		btn.add_theme_font_size_override("font_size", 36)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(_on_symbol_pressed.bind(i))
		btn.disabled = true
		_symbol_buttons.append(btn)
		hbox.add_child(btn)

	_feedback_label = _make_label("", 18, MG_PALETTE.green)
	vbox.add_child(_feedback_label)

	# Generate sequence
	for n in range(_seq_length):
		_sequence.append(randi() % SYMBOLS.size())

	await get_tree().create_timer(0.8).timeout
	_show_sequence()


func _show_sequence() -> void:
	_showing = true

	for i in range(_sequence.size()):
		if _finished:
			return
		_display_label.text = SYMBOLS[_sequence[i]]
		_display_label.modulate = MG_PALETTE.gold

		# Highlight the corresponding button
		_symbol_buttons[_sequence[i]].modulate = MG_PALETTE.gold

		var show_time: float = 0.8 - (_difficulty * 0.03)
		show_time = maxf(show_time, 0.35)
		await get_tree().create_timer(show_time).timeout

		_display_label.modulate = Color(1, 1, 1, 0.3)
		_symbol_buttons[_sequence[i]].modulate = Color.WHITE

		await get_tree().create_timer(0.2).timeout

	_showing = false
	_inputting = true
	_display_label.text = "?"
	_display_label.modulate = Color.WHITE
	_status_label.text = "À toi! (%d symboles)" % _seq_length

	for btn in _symbol_buttons:
		btn.disabled = false


func _on_symbol_pressed(index: int) -> void:
	if not _inputting:
		return

	_player_sequence.append(index)
	var pos: int = _player_sequence.size() - 1

	# Check if correct so far
	if _sequence[pos] == index:
		_symbol_buttons[index].modulate = MG_PALETTE.green
		_feedback_label.text = "%d/%d" % [_player_sequence.size(), _seq_length]
		_feedback_label.modulate = MG_PALETTE.green
	else:
		_symbol_buttons[index].modulate = MG_PALETTE.red
		_feedback_label.text = "Erreur au symbole %d!" % (pos + 1)
		_feedback_label.modulate = MG_PALETTE.red

	# Brief flash then reset
	await get_tree().create_timer(0.3).timeout
	_symbol_buttons[index].modulate = Color.WHITE

	# Check if done
	if _player_sequence.size() >= _seq_length:
		_inputting = false
		_finish_game()


func _on_key_pressed(keycode: int) -> void:
	if not _inputting:
		return

	if keycode >= KEY_1 and keycode <= KEY_5:
		var idx: int = keycode - KEY_1
		if idx < _symbol_buttons.size():
			_on_symbol_pressed(idx)


func _finish_game() -> void:
	if _finished:
		return
	for btn in _symbol_buttons:
		btn.disabled = true

	# Count correct in sequence
	var correct: int = 0
	for i in range(_seq_length):
		if i < _player_sequence.size() and _player_sequence[i] == _sequence[i]:
			correct += 1
		else:
			break  # Stop at first error (sequence must be in order)

	var score: int = clampi(int(float(correct) / float(_seq_length) * 100.0), 0, 100)
	var success: bool = correct >= _seq_length - 1  # Allow 1 mistake

	_display_label.text = "%d/%d" % [correct, _seq_length]
	_status_label.text = "Mémorisé! (%d pts)" % score if success else "Oublié... (%d pts)" % score
	_status_label.modulate = MG_PALETTE.green if success else MG_PALETTE.red

	await get_tree().create_timer(1.0).timeout
	_complete(success, score)
