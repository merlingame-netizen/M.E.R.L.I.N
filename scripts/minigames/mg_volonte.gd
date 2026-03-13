## MG_VOLONTE — Volonté (Esprit)
## Distractors flash on screen. Player must ONLY press the correct symbol.
## 6 rounds: 1 correct prompt + N distractors. Wrong press = penalty.

extends MiniGameBase

const SYMBOLS := ["◆", "◇", "●", "○", "▲", "△", "■", "□"]
const ROUND_COUNT: int = 6

var _target_symbol: String = ""
var _current_round: int = 0
var _hits: int = 0
var _misses: int = 0
var _round_active: bool = false
var _round_timer: float = 0.0
var _round_delay: float = 2.5

var _target_label: Label
var _display_label: Label
var _status_label: Label
var _feedback_label: Label
var _buttons: Array[Button] = []


func _on_start() -> void:
	_build_overlay()

	_round_delay = 3.0 - (_difficulty * 0.15)
	_round_delay = maxf(_round_delay, 1.2)

	# Pick a target symbol for the whole game
	_target_symbol = SYMBOLS[randi() % SYMBOLS.size()]

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -240
	vbox.offset_top = -240
	vbox.offset_right = 240
	vbox.offset_bottom = 240
	vbox.add_theme_constant_override("separation", 15)
	add_child(vbox)

	var title := _make_label("VOLONTÉ", 28, MG_PALETTE.accent)
	vbox.add_child(title)

	_target_label = _make_label("Clique UNIQUEMENT sur: %s" % _target_symbol, 18, MG_PALETTE.gold)
	vbox.add_child(_target_label)

	_status_label = _make_label("Prépare-toi...", 18, MG_PALETTE.ink)
	vbox.add_child(_status_label)

	_display_label = _make_label("", 64, MG_PALETTE.ink)
	_display_label.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(_display_label)

	# 3 buttons with symbols (shuffled each round)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	for i in range(3):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(100, 80)
		btn.add_theme_font_size_override("font_size", 40)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(_on_button_pressed.bind(i))
		_buttons.append(btn)
		hbox.add_child(btn)

	_feedback_label = _make_label("", 20, MG_PALETTE.green)
	vbox.add_child(_feedback_label)

	await get_tree().create_timer(1.0).timeout
	_next_round()


func _next_round() -> void:
	_current_round += 1

	if _current_round > ROUND_COUNT:
		_finish_game()
		return

	_status_label.text = "Round %d/%d" % [_current_round, ROUND_COUNT]
	_feedback_label.text = ""

	# Decide if this round has the target (70% chance)
	var has_target: bool = randf() < 0.7

	# Build button symbols
	var btn_symbols: Array[String] = []
	if has_target:
		btn_symbols.append(_target_symbol)
		# Add 2 distractors
		while btn_symbols.size() < 3:
			var s: String = SYMBOLS[randi() % SYMBOLS.size()]
			if s != _target_symbol:
				btn_symbols.append(s)
	else:
		# All distractors
		while btn_symbols.size() < 3:
			var s: String = SYMBOLS[randi() % SYMBOLS.size()]
			if s != _target_symbol and not btn_symbols.has(s):
				btn_symbols.append(s)

	btn_symbols.shuffle()

	for i in range(3):
		_buttons[i].text = btn_symbols[i]
		_buttons[i].disabled = false
		_buttons[i].modulate = Color.WHITE

	# Flash the big display
	_display_label.text = btn_symbols[randi() % 3]
	_display_label.modulate = MG_PALETTE.accent

	_round_active = true
	_round_timer = _round_delay


func _process(delta: float) -> void:
	if _finished or not _round_active:
		return

	_round_timer -= delta

	if _round_timer <= 0:
		_round_active = false
		# Timeout: if target was present, it's a miss
		var target_present: bool = false
		for btn in _buttons:
			if btn.text == _target_symbol:
				target_present = true
				break

		if target_present:
			_feedback_label.text = "Trop lent!"
			_feedback_label.modulate = MG_PALETTE.red
		else:
			# Correctly abstained
			_hits += 1
			_feedback_label.text = "Bien! Pas de cible."
			_feedback_label.modulate = MG_PALETTE.green

		await get_tree().create_timer(0.5).timeout
		if not _finished:
			_next_round()


func _on_button_pressed(index: int) -> void:
	if not _round_active:
		return

	_round_active = false
	var pressed_symbol: String = _buttons[index].text

	if pressed_symbol == _target_symbol:
		_hits += 1
		_buttons[index].modulate = MG_PALETTE.green
		_feedback_label.text = "Correct!"
		_feedback_label.modulate = MG_PALETTE.green
	else:
		_misses += 1
		_buttons[index].modulate = MG_PALETTE.red
		_feedback_label.text = "Mauvais symbole!"
		_feedback_label.modulate = MG_PALETTE.red

	for btn in _buttons:
		btn.disabled = true

	await get_tree().create_timer(0.5).timeout
	if not _finished:
		_next_round()


func _on_key_pressed(keycode: int) -> void:
	if not _round_active:
		return

	if keycode >= KEY_1 and keycode <= KEY_3:
		var idx: int = keycode - KEY_1
		if idx < _buttons.size():
			_on_button_pressed(idx)


func _finish_game() -> void:
	if _finished:
		return
	var accuracy: float = float(_hits) / float(ROUND_COUNT)
	var miss_penalty: int = _misses * 8
	var score: int = clampi(int(accuracy * 100.0) - miss_penalty, 0, 100)
	var success: bool = score >= 50

	_display_label.text = "%d/%d" % [_hits, ROUND_COUNT]
	_status_label.text = "Concentré! (%d pts)" % score if success else "Distrait... (%d pts)" % score
	_status_label.modulate = MG_PALETTE.green if success else MG_PALETTE.red

	await get_tree().create_timer(1.0).timeout
	_complete(success, score)
