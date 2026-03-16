## De du Destin — Dice of destiny mini-game (chance)
## Roll a D6 and predict high/low. Score = correct predictions / total * 100.

extends MiniGameBase

var _total_rounds: int = 3
var _current_round: int = 0
var _correct: int = 0
var _waiting: bool = false

var _title_label: Label
var _round_label: Label
var _dice_label: Label
var _high_btn: Button
var _low_btn: Button


func _on_start() -> void:
	_build_overlay()
	_total_rounds = 3 + int((_difficulty - 1) / 3.0)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 6
	vbox.offset_right = -10
	vbox.offset_bottom = -6
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "De du Destin"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_round_label = Label.new()
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_round_label)

	_dice_label = Label.new()
	_dice_label.text = "?"
	_dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_dice_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	_high_btn = Button.new()
	_high_btn.text = "Haut (4-6)"
	_high_btn.pressed.connect(_on_choice.bind("high"))
	btn_row.add_child(_high_btn)

	_low_btn = Button.new()
	_low_btn.text = "Bas (1-3)"
	_low_btn.pressed.connect(_on_choice.bind("low"))
	btn_row.add_child(_low_btn)

	_next_round()


func _next_round() -> void:
	_current_round += 1
	if _current_round > _total_rounds:
		_finish()
		return
	_round_label.text = "Tour %d / %d" % [_current_round, _total_rounds]
	_dice_label.text = "?"
	_high_btn.disabled = false
	_low_btn.disabled = false
	_waiting = false


func _on_choice(choice: String) -> void:
	if _waiting:
		return
	_waiting = true
	_high_btn.disabled = true
	_low_btn.disabled = true

	var roll: int = randi_range(1, 6)
	_dice_label.text = str(roll)

	var is_high: bool = roll >= 4
	var correct: bool = (choice == "high" and is_high) or (choice == "low" and not is_high)
	if correct:
		_correct += 1

	SFXManager.play("dice_land")
	await get_tree().create_timer(0.8).timeout
	_next_round()


func _finish() -> void:
	var score: int = int(float(_correct) / float(_total_rounds) * 100.0)
	_complete(score)
