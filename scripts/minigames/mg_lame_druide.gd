## MG_LAME_DRUIDE — Lame du Druide (Finesse)
## QTE: symbols appear in sequence. Player taps matching buttons in order.
## Timer: 6s total. Higher difficulty = more symbols + less time.

extends MiniGameBase

const SYMBOLS := ["\u25ef", "\u25b3", "\u25a1", "\u25c7"]
var _sequence: Array[String] = []
var _player_input: Array[String] = []
var _timer: float = 6.0
var _sequence_shown: bool = false
var _button_container: HBoxContainer
var _sequence_label: Label
var _timer_label: Label


func _on_start() -> void:
	_build_overlay()

	# Difficulty affects sequence length and time
	var seq_length: int = 3 + int(_difficulty / 3.0)  # 3-6 symbols
	_timer = 7.0 - (_difficulty * 0.25)  # 6.75s to 4.5s

	# Generate sequence
	for i in range(seq_length):
		_sequence.append(SYMBOLS[randi() % SYMBOLS.size()])

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -250
	vbox.offset_top = -200
	vbox.offset_right = 250
	vbox.offset_bottom = 200
	vbox.add_theme_constant_override("separation", 25)
	add_child(vbox)

	# Title
	var title := _make_label("LAME DU DRUIDE", 28, MG_PALETTE.accent)
	vbox.add_child(title)

	var subtitle := _make_label("Mémorise puis reproduis la séquence!", 16)
	vbox.add_child(subtitle)

	# Sequence display
	_sequence_label = _make_label("", 32, MG_PALETTE.gold)
	vbox.add_child(_sequence_label)

	# Timer
	_timer_label = _make_label("", 18, MG_PALETTE.red)
	vbox.add_child(_timer_label)

	# Button container
	_button_container = HBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 12)
	vbox.add_child(_button_container)

	# Create buttons (initially disabled)
	for symbol in SYMBOLS:
		var btn := Button.new()
		btn.text = symbol
		btn.custom_minimum_size = Vector2(70, 70)
		btn.add_theme_font_size_override("font_size", 32)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.disabled = true
		btn.pressed.connect(_on_symbol_pressed.bind(symbol))
		_button_container.add_child(btn)

	_show_sequence()


func _show_sequence() -> void:
	_sequence_label.text = "Regarde bien..."

	await get_tree().create_timer(1.0).timeout

	# Show sequence with delays
	for i in range(_sequence.size()):
		_sequence_label.text = " ".join(_sequence.slice(0, i + 1))

		var sfx := get_node_or_null("/root/SFXManager")
		if sfx and sfx.has_method("play"):
			sfx.play("minigame_tick")

		await get_tree().create_timer(0.6).timeout

	await get_tree().create_timer(0.5).timeout

	# Hide sequence, enable buttons
	_sequence_label.text = "À toi de jouer!"
	_sequence_shown = true

	for btn in _button_container.get_children():
		if btn is Button:
			btn.disabled = false


func _process(delta: float) -> void:
	if not _sequence_shown or _finished:
		return

	_timer -= delta
	_timer_label.text = "Temps: %.1f s" % maxf(_timer, 0.0)

	if _timer <= 0:
		_fail_game()


func _on_key_pressed(keycode: int) -> void:
	# Keys 1-4 map to symbols: 1=circle, 2=triangle, 3=square, 4=diamond
	if keycode >= KEY_1 and keycode <= KEY_4:
		var symbol_index: int = keycode - KEY_1
		if symbol_index < SYMBOLS.size():
			_on_symbol_pressed(SYMBOLS[symbol_index])


func _on_symbol_pressed(symbol: String) -> void:
	if _finished:
		return

	_player_input.append(symbol)
	_sequence_label.text = " ".join(_player_input)

	# Check if correct so far
	var correct_index: int = _player_input.size() - 1
	if correct_index >= _sequence.size() or _player_input[correct_index] != _sequence[correct_index]:
		# Wrong input
		_fail_game()
		return

	# Check if complete
	if _player_input.size() == _sequence.size():
		_succeed_game()


func _succeed_game() -> void:
	_sequence_label.modulate = MG_PALETTE.green

	var sfx := get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_success")

	await get_tree().create_timer(0.5).timeout

	var score: int = 100
	_complete(true, score)


func _fail_game() -> void:
	_sequence_label.modulate = MG_PALETTE.red
	_sequence_label.text = "Raté! Séquence: " + " ".join(_sequence)

	var sfx := get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_fail")

	await get_tree().create_timer(1.5).timeout

	var score: int = int((_player_input.size() / float(_sequence.size())) * 100.0)
	_complete(false, score)
