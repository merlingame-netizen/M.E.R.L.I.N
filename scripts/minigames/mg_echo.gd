## MG_ECHO — Écho des Pierres (Perception)
## A sound/symbol originates from a direction. Player must identify the source.
## 4 directions, 5 rounds. Visual cue flashes briefly then fades.

extends MiniGameBase

const DIRECTIONS := ["Nord", "Est", "Sud", "Ouest"]
const DIR_ARROWS := ["▲", "►", "▼", "◄"]
const ROUND_COUNT: int = 5

var _current_round: int = 0
var _correct_dir: int = -1
var _hits: int = 0
var _waiting_input: bool = false
var _flash_time: float = 0.6

var _direction_buttons: Array[Button] = []
var _center_label: Label
var _status_label: Label
var _feedback_label: Label


func _on_start() -> void:
	_build_overlay()

	_flash_time = 0.8 - (_difficulty * 0.05)
	_flash_time = maxf(_flash_time, 0.2)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -220
	vbox.offset_top = -240
	vbox.offset_right = 220
	vbox.offset_bottom = 240
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	var title := _make_label("ÉCHO DES PIERRES", 28, MG_PALETTE.accent)
	vbox.add_child(title)

	var subtitle := _make_label("D'où vient l'écho?", 16)
	vbox.add_child(subtitle)

	_status_label = _make_label("Écoute...", 20, MG_PALETTE.ink)
	vbox.add_child(_status_label)

	# Direction layout: N on top, E-W middle, S bottom
	# Top: North
	var north_center := CenterContainer.new()
	north_center.custom_minimum_size = Vector2(200, 70)
	vbox.add_child(north_center)
	var btn_n := _make_dir_button(0)
	_direction_buttons.append(btn_n)
	north_center.add_child(btn_n)

	# Middle: West - Center - East
	var mid_hbox := HBoxContainer.new()
	mid_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mid_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(mid_hbox)

	var btn_w := _make_dir_button(3)
	_direction_buttons.append(btn_w)
	mid_hbox.add_child(btn_w)

	_center_label = Label.new()
	_center_label.text = "◉"
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.add_theme_font_size_override("font_size", 48)
	_center_label.add_theme_color_override("font_color", MG_PALETTE.accent)
	_center_label.custom_minimum_size = Vector2(80, 70)
	mid_hbox.add_child(_center_label)

	var btn_e := _make_dir_button(1)
	_direction_buttons.append(btn_e)
	mid_hbox.add_child(btn_e)

	# Bottom: South
	var south_center := CenterContainer.new()
	south_center.custom_minimum_size = Vector2(200, 70)
	vbox.add_child(south_center)
	var btn_s := _make_dir_button(2)
	_direction_buttons.append(btn_s)
	south_center.add_child(btn_s)

	_feedback_label = _make_label("", 20, MG_PALETTE.green)
	vbox.add_child(_feedback_label)

	# Reorder buttons array to match DIRECTIONS index (N=0, E=1, S=2, W=3)
	_direction_buttons = [btn_n, btn_e, btn_s, btn_w]

	await get_tree().create_timer(0.8).timeout
	_next_round()


func _make_dir_button(dir_index: int) -> Button:
	var btn := Button.new()
	btn.text = "%s %s" % [DIR_ARROWS[dir_index], DIRECTIONS[dir_index]]
	btn.custom_minimum_size = Vector2(120, 60)
	btn.add_theme_font_size_override("font_size", 20)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(_on_dir_pressed.bind(dir_index))
	btn.disabled = true
	return btn


func _next_round() -> void:
	_current_round += 1

	if _current_round > ROUND_COUNT:
		_finish_game()
		return

	_waiting_input = false
	_feedback_label.text = ""
	_status_label.text = "Round %d/%d — Observe!" % [_current_round, ROUND_COUNT]

	for btn in _direction_buttons:
		btn.modulate = Color.WHITE
		btn.disabled = true

	# Flash a random direction
	_correct_dir = randi() % 4
	_direction_buttons[_correct_dir].modulate = MG_PALETTE.gold
	_center_label.text = DIR_ARROWS[_correct_dir]

	await get_tree().create_timer(_flash_time).timeout

	# Hide
	_direction_buttons[_correct_dir].modulate = Color.WHITE
	_center_label.text = "?"

	# Blank pause
	await get_tree().create_timer(0.3).timeout

	# Enable for input
	_status_label.text = "D'où venait l'écho?"
	for btn in _direction_buttons:
		btn.disabled = false
	_waiting_input = true


func _on_dir_pressed(dir_index: int) -> void:
	if not _waiting_input:
		return

	_waiting_input = false

	for btn in _direction_buttons:
		btn.disabled = true

	if dir_index == _correct_dir:
		_hits += 1
		_direction_buttons[dir_index].modulate = MG_PALETTE.green
		_feedback_label.text = "Correct!"
		_feedback_label.modulate = MG_PALETTE.green
	else:
		_direction_buttons[dir_index].modulate = MG_PALETTE.red
		_direction_buttons[_correct_dir].modulate = MG_PALETTE.gold
		_feedback_label.text = "C'était %s!" % DIRECTIONS[_correct_dir]
		_feedback_label.modulate = MG_PALETTE.red

	await get_tree().create_timer(0.6).timeout
	_next_round()


func _on_key_pressed(keycode: int) -> void:
	if not _waiting_input:
		return

	match keycode:
		KEY_UP:
			_on_dir_pressed(0)
		KEY_RIGHT:
			_on_dir_pressed(1)
		KEY_DOWN:
			_on_dir_pressed(2)
		KEY_LEFT:
			_on_dir_pressed(3)


func _finish_game() -> void:
	var score: int = clampi(int(float(_hits) / float(ROUND_COUNT) * 100.0), 0, 100)
	var success: bool = _hits >= 3

	_status_label.text = "Attentif! (%d pts)" % score if success else "Sourd... (%d pts)" % score
	_status_label.modulate = MG_PALETTE.green if success else MG_PALETTE.red

	await get_tree().create_timer(1.0).timeout
	_complete(success, score)
