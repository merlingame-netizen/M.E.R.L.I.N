## Joute Verbale — Verbal duel mini-game (bluff)
## Attaque > Ruse > Défense > Attaque. 3 rounds. AI adapts at higher difficulty.

extends MiniGameBase

enum Action { NONE, ATTAQUE, RUSE, DEFENSE }

var _rounds_total: int = 3
var _current_round: int = 0
var _player_wins: int = 0
var _ai_wins: int = 0
var _waiting_for_result: bool = false
var _ai_previous_choices: Array[Action] = []
var _player_previous_choices: Array[Action] = []

var _title_label: Label
var _round_label: Label
var _result_label: Label
var _score_label: Label
var _attaque_btn: Button
var _ruse_btn: Button
var _defense_btn: Button


func _on_start() -> void:
	_build_overlay()

	# Container
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(get_viewport_rect().size.x / 2 - 200, get_viewport_rect().size.y / 2 - 170)
	vbox.custom_minimum_size = Vector2(400, 340)
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	# Title
	_title_label = _make_label("Joute Verbale", 28, MG_PALETTE.gold)
	vbox.add_child(_title_label)

	# Rules
	var rules := _make_label("Attaque > Ruse > Défense > Attaque", 16, MG_PALETTE.accent)
	vbox.add_child(rules)

	# Round counter
	_round_label = _make_label("Manche 1/3", 20, MG_PALETTE.ink)
	vbox.add_child(_round_label)

	# Score
	_score_label = _make_label("Vous: 0  |  Adversaire: 0", 18, MG_PALETTE.ink)
	vbox.add_child(_score_label)

	# Result
	_result_label = _make_label("Choisissez votre stratégie...", 18, MG_PALETTE.ink)
	vbox.add_child(_result_label)

	# Buttons
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	_attaque_btn = _make_button("Attaque", func(): _on_choice(Action.ATTAQUE))
	_ruse_btn = _make_button("Ruse", func(): _on_choice(Action.RUSE))
	_defense_btn = _make_button("Défense", func(): _on_choice(Action.DEFENSE))

	hbox.add_child(_attaque_btn)
	hbox.add_child(_ruse_btn)
	hbox.add_child(_defense_btn)

	_current_round = 1


func _on_choice(player_action: Action) -> void:
	if _waiting_for_result:
		return

	_waiting_for_result = true
	_disable_buttons()

	# AI picks (adaptive at high difficulty)
	var ai_action: Action = _get_ai_action()

	# Store choices for AI learning
	_player_previous_choices.append(player_action)
	_ai_previous_choices.append(ai_action)

	# Show choices
	var player_name: String = _action_to_string(player_action)
	var ai_name: String = _action_to_string(ai_action)

	_result_label.text = "Vous: %s  |  Adversaire: %s" % [player_name, ai_name]

	await get_tree().create_timer(1.0).timeout

	# Determine winner
	var outcome: int = _get_outcome(player_action, ai_action)

	if outcome > 0:
		_player_wins += 1
		_result_label.text += "\nVous dominez le débat!"
		_result_label.add_theme_color_override("font_color", MG_PALETTE.green)
	elif outcome < 0:
		_ai_wins += 1
		_result_label.text += "\nVous êtes déstabilisé!"
		_result_label.add_theme_color_override("font_color", MG_PALETTE.red)
	else:
		_result_label.text += "\nÉchange équilibré!"
		_result_label.add_theme_color_override("font_color", MG_PALETTE.accent)

	_score_label.text = "Vous: %d  |  Adversaire: %d" % [_player_wins, _ai_wins]

	# SFX
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_tick")

	await get_tree().create_timer(1.5).timeout

	# Next round or finish
	_current_round += 1
	if _current_round <= _rounds_total:
		_start_next_round()
	else:
		_finish_game()


func _get_ai_action() -> Action:
	# At low difficulty, random
	if _difficulty <= 3:
		return [Action.ATTAQUE, Action.RUSE, Action.DEFENSE].pick_random()

	# At medium difficulty, slight counter-tendency
	if _difficulty <= 6:
		if _player_previous_choices.size() > 0 and randf() < 0.3:
			var last_player_action: Action = _player_previous_choices[-1]
			return _get_counter_action(last_player_action)
		else:
			return [Action.ATTAQUE, Action.RUSE, Action.DEFENSE].pick_random()

	# At high difficulty, adaptive AI
	if _player_previous_choices.size() > 0 and randf() < 0.6:
		var last_player_action: Action = _player_previous_choices[-1]
		return _get_counter_action(last_player_action)
	else:
		return [Action.ATTAQUE, Action.RUSE, Action.DEFENSE].pick_random()


func _get_counter_action(action: Action) -> Action:
	# Returns the action that beats the given action
	match action:
		Action.ATTAQUE: return Action.DEFENSE
		Action.RUSE: return Action.ATTAQUE
		Action.DEFENSE: return Action.RUSE
		_: return Action.ATTAQUE


func _get_outcome(player: Action, ai: Action) -> int:
	# Returns: 1 = player wins, -1 = ai wins, 0 = draw
	if player == ai:
		return 0

	# Attaque > Ruse > Défense > Attaque
	if (player == Action.ATTAQUE and ai == Action.RUSE) or \
	   (player == Action.RUSE and ai == Action.DEFENSE) or \
	   (player == Action.DEFENSE and ai == Action.ATTAQUE):
		return 1
	else:
		return -1


func _action_to_string(action: Action) -> String:
	match action:
		Action.ATTAQUE: return "Attaque"
		Action.RUSE: return "Ruse"
		Action.DEFENSE: return "Défense"
		_: return "?"


func _disable_buttons() -> void:
	_attaque_btn.disabled = true
	_ruse_btn.disabled = true
	_defense_btn.disabled = true


func _enable_buttons() -> void:
	_attaque_btn.disabled = false
	_ruse_btn.disabled = false
	_defense_btn.disabled = false


func _start_next_round() -> void:
	_waiting_for_result = false
	_enable_buttons()
	_round_label.text = "Manche %d/%d" % [_current_round, _rounds_total]
	_result_label.text = "Choisissez votre stratégie..."
	_result_label.add_theme_color_override("font_color", MG_PALETTE.ink)


func _finish_game() -> void:
	var score: int = int((_player_wins / float(_rounds_total)) * 100.0)
	var success: bool = _player_wins > _ai_wins

	await get_tree().create_timer(1.0).timeout
	_complete(success, score)
