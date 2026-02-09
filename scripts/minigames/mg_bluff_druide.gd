extends MiniGameBase
## Bluff du Druide — Card guessing game with AI deception (bluff-based)

var current_round: int = 0
var total_score: int = 0
var max_rounds: int = 4
var card_is_high: bool = false
var ai_will_lie: bool = false

var round_label: Label
var card_display: Label
var hint_label: Label
var button_high: Button
var button_low: Button

func _on_start() -> void:
	_build_overlay()
	_build_ui()
	_start_round()

func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.position = Vector2(350, 100)
	vbox.custom_minimum_size = Vector2(500, 600)
	add_child(vbox)

	var title: Label = _make_label("Bluff du Druide", 32, MG_PALETTE.gold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_make_spacer(20))

	round_label = _make_label("Manche 1/4", 20, MG_PALETTE.ink)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(round_label)

	vbox.add_child(_make_spacer(40))

	# Card display
	card_display = _make_label("?", 96, MG_PALETTE.accent)
	card_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_display.custom_minimum_size = Vector2(200, 200)
	vbox.add_child(card_display)

	vbox.add_child(_make_spacer(20))

	# Hint label
	hint_label = _make_label("Le druide cache sa carte...", 18, MG_PALETTE.ink)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(450, 60)
	vbox.add_child(hint_label)

	vbox.add_child(_make_spacer(40))

	# Betting buttons
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	button_high = _make_button("HAUT", _on_bet_high)
	button_high.custom_minimum_size = Vector2(180, 60)
	hbox.add_child(button_high)

	hbox.add_child(_make_spacer_h(20))

	button_low = _make_button("BAS", _on_bet_low)
	button_low.custom_minimum_size = Vector2(180, 60)
	hbox.add_child(button_low)

func _make_spacer(height: int) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _make_spacer_h(width: int) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(width, 0)
	return spacer

func _start_round() -> void:
	current_round += 1
	round_label.text = "Manche " + str(current_round) + "/" + str(max_rounds)

	# Generate card
	card_is_high = randf() > 0.5

	# AI decides to lie based on difficulty and round
	ai_will_lie = randf() < (_difficulty / 15.0) and current_round > 1

	# Show hint (truthful or deceptive)
	await get_tree().create_timer(0.5).timeout
	_show_hint()

	# Enable buttons
	button_high.disabled = false
	button_low.disabled = false
	card_display.text = "?"

func _show_hint() -> void:
	if randf() < 0.5 + (_difficulty / 20.0):
		# AI shows the card (or lies about it)
		if ai_will_lie:
			hint_label.text = "Le druide montre : " + ("BAS" if card_is_high else "HAUT") + "... ou pas ?"
			hint_label.modulate = MG_PALETTE.red
		else:
			hint_label.text = "Le druide montre : " + ("HAUT" if card_is_high else "BAS")
			hint_label.modulate = MG_PALETTE.green
	else:
		hint_label.text = "Le druide reste silencieux..."
		hint_label.modulate = MG_PALETTE.ink

func _on_bet_high() -> void:
	_resolve_bet(true)

func _on_bet_low() -> void:
	_resolve_bet(false)

func _resolve_bet(bet_high: bool) -> void:
	button_high.disabled = true
	button_low.disabled = true

	var correct: bool = bet_high == card_is_high
	var points: int = 25 if correct else -15
	total_score += points

	# Reveal card
	card_display.text = "HAUT" if card_is_high else "BAS"
	card_display.modulate = MG_PALETTE.green if correct else MG_PALETTE.red

	hint_label.text = ("Correct ! +" if correct else "Raté... ") + str(points) + " points"
	hint_label.modulate = MG_PALETTE.green if correct else MG_PALETTE.red

	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_success" if correct else "minigame_fail")

	# Next round or finish
	await get_tree().create_timer(2.0).timeout
	if current_round < max_rounds:
		_start_round()
	else:
		_finish_game()

func _finish_game() -> void:
	var final_score: int = maxi(0, total_score)
	_complete(total_score >= 0, final_score)
