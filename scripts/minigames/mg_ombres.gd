## MG_OMBRES — Ombres Furtives (Perception)
## Shadows appear briefly in one of 4 quadrants. Player must click the right one.
## 5 rounds. Score = correct guesses + reaction speed bonus.

extends MiniGameBase

const ROUND_COUNT: int = 5
const QUADRANT_NAMES := ["haut-gauche", "haut-droit", "bas-gauche", "bas-droit"]

var _current_round: int = 0
var _correct_quadrant: int = -1
var _hits: int = 0
var _total_reaction_ms: int = 0
var _round_start_ms: int = 0
var _flash_duration: float = 0.8
var _waiting_input: bool = false

var _quadrant_buttons: Array[Button] = []
var _status_label: Label
var _feedback_label: Label


func _on_start() -> void:
	_build_overlay()

	_flash_duration = 1.0 - (_difficulty * 0.06)
	_flash_duration = maxf(_flash_duration, 0.25)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -220
	vbox.offset_top = -240
	vbox.offset_right = 220
	vbox.offset_bottom = 240
	vbox.add_theme_constant_override("separation", 15)
	add_child(vbox)

	var title := _make_label("OMBRES FURTIVES", 28, MG_PALETTE.accent)
	vbox.add_child(title)

	var subtitle := _make_label("Où est passée l'ombre?", 16)
	vbox.add_child(subtitle)

	_status_label = _make_label("Observe...", 20, MG_PALETTE.ink)
	vbox.add_child(_status_label)

	# 2x2 grid of quadrants
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)

	for i in range(4):
		var btn := Button.new()
		btn.text = QUADRANT_NAMES[i]
		btn.custom_minimum_size = Vector2(160, 100)
		btn.add_theme_font_size_override("font_size", 16)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(_on_quadrant_pressed.bind(i))
		_quadrant_buttons.append(btn)
		grid.add_child(btn)

	_feedback_label = _make_label("", 20, MG_PALETTE.green)
	vbox.add_child(_feedback_label)

	await get_tree().create_timer(1.0).timeout
	_next_round()


func _next_round() -> void:
	_current_round += 1

	if _current_round > ROUND_COUNT:
		_finish_game()
		return

	_status_label.text = "Round %d/%d — Observe!" % [_current_round, ROUND_COUNT]
	_feedback_label.text = ""
	_waiting_input = false

	# Reset button colors
	for btn in _quadrant_buttons:
		btn.modulate = Color.WHITE
		btn.disabled = true

	# Flash a random quadrant
	_correct_quadrant = randi() % 4
	_quadrant_buttons[_correct_quadrant].modulate = MG_PALETTE.gold

	await get_tree().create_timer(_flash_duration).timeout

	# Hide flash
	_quadrant_buttons[_correct_quadrant].modulate = Color.WHITE

	# Brief blank pause (harder to remember)
	var blank_pause: float = 0.3 + (_difficulty * 0.05)
	await get_tree().create_timer(blank_pause).timeout

	# Enable buttons for answer
	_status_label.text = "Où était l'ombre?"
	for btn in _quadrant_buttons:
		btn.disabled = false
	_round_start_ms = Time.get_ticks_msec()
	_waiting_input = true


func _on_quadrant_pressed(index: int) -> void:
	if not _waiting_input:
		return

	_waiting_input = false
	var reaction_ms: int = Time.get_ticks_msec() - _round_start_ms

	for btn in _quadrant_buttons:
		btn.disabled = true

	if index == _correct_quadrant:
		_hits += 1
		_total_reaction_ms += reaction_ms
		_quadrant_buttons[index].modulate = MG_PALETTE.green
		_feedback_label.text = "Correct! (%d ms)" % reaction_ms
		_feedback_label.modulate = MG_PALETTE.green
	else:
		_quadrant_buttons[index].modulate = MG_PALETTE.red
		_quadrant_buttons[_correct_quadrant].modulate = MG_PALETTE.gold
		_feedback_label.text = "Raté!"
		_feedback_label.modulate = MG_PALETTE.red

	await get_tree().create_timer(0.7).timeout
	_next_round()


func _on_key_pressed(keycode: int) -> void:
	if not _waiting_input:
		return

	# Numpad layout: 7=TL, 9=TR, 1=BL, 3=BR or 1-4 sequential
	match keycode:
		KEY_1:
			_on_quadrant_pressed(0)
		KEY_2:
			_on_quadrant_pressed(1)
		KEY_3:
			_on_quadrant_pressed(2)
		KEY_4:
			_on_quadrant_pressed(3)


func _finish_game() -> void:
	var base_score: int = int(float(_hits) / float(ROUND_COUNT) * 80.0)

	var speed_bonus: int = 0
	if _hits > 0:
		var avg_ms: float = float(_total_reaction_ms) / float(_hits)
		speed_bonus = clampi(int(20.0 - avg_ms / 75.0), 0, 20)

	var score: int = clampi(base_score + speed_bonus, 0, 100)
	var success: bool = _hits >= 3

	_status_label.text = "Perçu! (%d pts)" % score if success else "Aveugle... (%d pts)" % score
	_status_label.modulate = MG_PALETTE.green if success else MG_PALETTE.red

	await get_tree().create_timer(1.0).timeout
	_complete(success, score)
