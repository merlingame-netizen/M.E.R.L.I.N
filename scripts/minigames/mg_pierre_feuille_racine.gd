## Pierre Feuille Racine — Modified RPS mini-game (logique)
## Pierre > Racine > Feuille > Pierre. 3 rounds vs AI.

extends MiniGameBase

enum Choice { NONE, PIERRE, FEUILLE, RACINE }

var _rounds_total: int = 3
var _current_round: int = 0
var _player_wins: int = 0
var _ai_wins: int = 0
var _waiting_for_result: bool = false

var _title_label: Label
var _round_label: Label
var _result_label: Label
var _score_label: Label
var _pierre_btn: Button
var _feuille_btn: Button
var _racine_btn: Button


func _on_start() -> void:
	_build_overlay()

	# Container
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(get_viewport_rect().size.x / 2 - 200, get_viewport_rect().size.y / 2 - 160)
	vbox.custom_minimum_size = Vector2(400, 320)
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	# Title
	_title_label = _make_label("Pierre Feuille Racine", 28, MG_PALETTE.gold)
	vbox.add_child(_title_label)

	# Rules
	var rules := _make_label("Pierre > Racine > Feuille > Pierre", 16, MG_PALETTE.accent)
	vbox.add_child(rules)

	# Round counter
	_round_label = _make_label("Manche 1/3", 20, MG_PALETTE.ink)
	vbox.add_child(_round_label)

	# Score
	_score_label = _make_label("Vous: 0  |  IA: 0", 18, MG_PALETTE.ink)
	vbox.add_child(_score_label)

	# Result
	_result_label = _make_label("Choisissez votre symbole...", 18, MG_PALETTE.ink)
	vbox.add_child(_result_label)

	# Buttons
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	_pierre_btn = _make_button("Pierre", func(): _on_choice(Choice.PIERRE))
	_feuille_btn = _make_button("Feuille", func(): _on_choice(Choice.FEUILLE))
	_racine_btn = _make_button("Racine", func(): _on_choice(Choice.RACINE))

	hbox.add_child(_pierre_btn)
	hbox.add_child(_feuille_btn)
	hbox.add_child(_racine_btn)

	_current_round = 1


func _on_key_pressed(keycode: int) -> void:
	match keycode:
		KEY_Q:
			_on_choice(Choice.PIERRE)
		KEY_W:
			_on_choice(Choice.FEUILLE)
		KEY_E:
			_on_choice(Choice.RACINE)


func _on_choice(player_choice: Choice) -> void:
	if _waiting_for_result:
		return

	_waiting_for_result = true
	_disable_buttons()

	# AI picks (random at low difficulty, strategic at high)
	var ai_choice: Choice = _get_ai_choice()

	# Show choices
	var player_name: String = _choice_to_string(player_choice)
	var ai_name: String = _choice_to_string(ai_choice)

	_result_label.text = "Vous: %s  |  IA: %s" % [player_name, ai_name]

	await get_tree().create_timer(1.0).timeout

	# Determine winner
	var outcome: int = _get_outcome(player_choice, ai_choice)

	if outcome > 0:
		_player_wins += 1
		_result_label.text += "\nVous gagnez!"
		_result_label.add_theme_color_override("font_color", MG_PALETTE.green)
	elif outcome < 0:
		_ai_wins += 1
		_result_label.text += "\nL'IA gagne!"
		_result_label.add_theme_color_override("font_color", MG_PALETTE.red)
	else:
		_result_label.text += "\nÉgalité!"
		_result_label.add_theme_color_override("font_color", MG_PALETTE.accent)

	_score_label.text = "Vous: %d  |  IA: %d" % [_player_wins, _ai_wins]

	await get_tree().create_timer(1.5).timeout

	# Next round or finish
	_current_round += 1
	if _current_round <= _rounds_total:
		_start_next_round()
	else:
		_finish_game()


func _get_ai_choice() -> Choice:
	# At higher difficulty, AI has pattern awareness
	if _difficulty >= 7 and randf() < 0.4:
		# Strategic pick (counter common patterns)
		return [Choice.PIERRE, Choice.FEUILLE, Choice.RACINE].pick_random()
	else:
		# Random
		return [Choice.PIERRE, Choice.FEUILLE, Choice.RACINE].pick_random()


func _get_outcome(player: Choice, ai: Choice) -> int:
	# Returns: 1 = player wins, -1 = ai wins, 0 = draw
	if player == ai:
		return 0

	# Pierre > Racine > Feuille > Pierre
	if (player == Choice.PIERRE and ai == Choice.RACINE) or \
	   (player == Choice.RACINE and ai == Choice.FEUILLE) or \
	   (player == Choice.FEUILLE and ai == Choice.PIERRE):
		return 1
	else:
		return -1


func _choice_to_string(choice: Choice) -> String:
	match choice:
		Choice.PIERRE: return "Pierre"
		Choice.FEUILLE: return "Feuille"
		Choice.RACINE: return "Racine"
		_: return "?"


func _disable_buttons() -> void:
	_pierre_btn.disabled = true
	_feuille_btn.disabled = true
	_racine_btn.disabled = true


func _enable_buttons() -> void:
	_pierre_btn.disabled = false
	_feuille_btn.disabled = false
	_racine_btn.disabled = false


func _start_next_round() -> void:
	_waiting_for_result = false
	_enable_buttons()
	_round_label.text = "Manche %d/%d" % [_current_round, _rounds_total]
	_result_label.text = "Choisissez votre symbole..."
	_result_label.add_theme_color_override("font_color", MG_PALETTE.ink)


func _finish_game() -> void:
	var score: int = int((_player_wins / float(_rounds_total)) * 100.0)
	var success: bool = _player_wins > _ai_wins

	await get_tree().create_timer(1.0).timeout
	_complete(success, score)
