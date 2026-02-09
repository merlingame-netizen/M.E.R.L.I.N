## Pile ou Face — Coin flip prediction mini-game (chance)
## Best of N rounds. Score = correct predictions / total * 100.

extends MiniGameBase

var _total_rounds: int = 3
var _current_round: int = 0
var _correct_predictions: int = 0
var _player_choice: String = ""
var _waiting_for_result: bool = false

var _title_label: Label
var _round_label: Label
var _result_label: Label
var _pile_button: Button
var _face_button: Button


func _on_start() -> void:
	_build_overlay()

	# More rounds at higher difficulty
	_total_rounds = 3 + int((_difficulty - 1) / 3.0)  # 3-6 rounds

	# Container
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(get_viewport_rect().size.x / 2 - 180, get_viewport_rect().size.y / 2 - 140)
	vbox.custom_minimum_size = Vector2(360, 280)
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)

	# Title
	_title_label = _make_label("Pile ou Face", 28, MG_PALETTE.gold)
	vbox.add_child(_title_label)

	# Round counter
	_round_label = _make_label("Manche 1/%d" % _total_rounds, 20, MG_PALETTE.accent)
	vbox.add_child(_round_label)

	# Instructions
	var instructions := _make_label("Prédisez le résultat...", 18, MG_PALETTE.ink)
	vbox.add_child(instructions)

	# Result display
	_result_label = _make_label("", 22, MG_PALETTE.ink)
	vbox.add_child(_result_label)

	# Buttons
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	_pile_button = _make_button("PILE", func(): _on_choice("pile"))
	_face_button = _make_button("FACE", func(): _on_choice("face"))
	hbox.add_child(_pile_button)
	hbox.add_child(_face_button)

	_current_round = 1


func _on_choice(choice: String) -> void:
	if _waiting_for_result:
		return

	_waiting_for_result = true
	_player_choice = choice
	_pile_button.disabled = true
	_face_button.disabled = true

	# Flip coin
	var coin_result: String = "pile" if randf() < 0.5 else "face"

	# Animate flip (simple text change)
	_result_label.text = "..."
	await get_tree().create_timer(0.3).timeout
	_result_label.text = "..!"
	await get_tree().create_timer(0.3).timeout
	_result_label.text = coin_result.to_upper()

	# Check prediction
	var correct: bool = (_player_choice == coin_result)
	if correct:
		_correct_predictions += 1
		_result_label.add_theme_color_override("font_color", MG_PALETTE.green)
	else:
		_result_label.add_theme_color_override("font_color", MG_PALETTE.red)

	# SFX
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_tick")

	await get_tree().create_timer(1.0).timeout

	# Next round or finish
	_current_round += 1
	if _current_round <= _total_rounds:
		_start_next_round()
	else:
		_finish_game()


func _start_next_round() -> void:
	_waiting_for_result = false
	_player_choice = ""
	_pile_button.disabled = false
	_face_button.disabled = false
	_round_label.text = "Manche %d/%d" % [_current_round, _total_rounds]
	_result_label.text = ""
	_result_label.add_theme_color_override("font_color", MG_PALETTE.ink)


func _finish_game() -> void:
	var score: int = int((_correct_predictions / float(_total_rounds)) * 100.0)
	var success: bool = score >= 50

	_result_label.text = "Score: %d/%d" % [_correct_predictions, _total_rounds]

	await get_tree().create_timer(1.2).timeout
	_complete(success, score)
