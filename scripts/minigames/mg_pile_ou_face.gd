## Pile ou Face — Coin flip prediction mini-game (chance)
## Best of N rounds. Score = correct predictions / total * 100.
## Visual: golden coin with vertical flip animation.
## Fully responsive: all elements scale to container size.

extends MiniGameBase

var _total_rounds: int = 3
var _current_round: int = 0
var _correct_predictions: int = 0
var _player_choice: String = ""
var _waiting_for_result: bool = false

var _title_label: Label
var _round_label: Label
var _coin_frame: PanelContainer
var _coin_label: Label
var _coin_area: CenterContainer
var _pile_button: Button
var _face_button: Button


func _on_start() -> void:
	_build_overlay()

	# More rounds at higher difficulty
	_total_rounds = 3 + int((_difficulty - 1) / 3.0)  # 3-6 rounds

	# Main VBox fills parent via anchors (no fixed minimum_size)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 6
	vbox.offset_right = -10
	vbox.offset_bottom = -6
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	# Title
	_title_label = _make_label("Pile ou Face", 22, MG_PALETTE.gold)
	vbox.add_child(_title_label)

	# Round counter
	_round_label = _make_label("Manche 1/%d" % _total_rounds, 16, MG_PALETTE.accent)
	vbox.add_child(_round_label)

	# Instructions
	var instructions := _make_label("Predisez le resultat...", 14, MG_PALETTE.ink)
	vbox.add_child(instructions)

	# Coin area — expands to fill remaining vertical space
	_coin_area = CenterContainer.new()
	_coin_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_coin_area.size_flags_stretch_ratio = 1.0
	vbox.add_child(_coin_area)

	# Coin frame (sized dynamically via resized signal)
	_coin_frame = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE["coin_face"]  # Gold coin
	style.border_color = MerlinVisual.CRT_PALETTE["coin_edge"]  # Darker gold edge
	style.set_border_width_all(3)
	style.set_corner_radius_all(999)  # Large value = always circular
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 3
	style.shadow_offset = Vector2(2, 3)
	_coin_frame.add_theme_stylebox_override("panel", style)
	_coin_area.add_child(_coin_frame)

	_coin_label = Label.new()
	_coin_label.text = "?"
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_label.add_theme_font_size_override("font_size", 20)
	_coin_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["coin_text"])
	_coin_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_coin_frame.add_child(_coin_label)

	# Resize coin when area resizes
	_coin_area.resized.connect(_on_coin_area_resized)

	# Choice buttons — expand horizontally
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	_pile_button = _make_button("PILE", func(): _on_choice("pile"))
	_pile_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_face_button = _make_button("FACE", func(): _on_choice("face"))
	_face_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_pile_button)
	hbox.add_child(_face_button)

	_current_round = 1

	# Initial coin sizing after one frame (layout ready)
	await get_tree().process_frame
	_on_coin_area_resized()


func _on_coin_area_resized() -> void:
	## Dynamically size the coin to fit the available area.
	if not _coin_frame or not is_instance_valid(_coin_frame):
		return
	if not _coin_area or not is_instance_valid(_coin_area):
		return
	var area_size := _coin_area.size
	var coin_side := mini(area_size.x, area_size.y) * 0.75
	coin_side = maxf(coin_side, 40.0)  # Floor: never smaller than 40px
	_coin_frame.custom_minimum_size = Vector2(coin_side, coin_side)
	_coin_frame.pivot_offset = Vector2(coin_side / 2.0, coin_side / 2.0)
	# Scale font to coin
	var font_size := int(coin_side * 0.35)
	_coin_label.add_theme_font_size_override("font_size", clampi(font_size, 12, 36))


func _on_key_pressed(keycode: int) -> void:
	if keycode == KEY_Q:
		_on_choice("pile")
	elif keycode == KEY_E:
		_on_choice("face")


func _on_choice(choice: String) -> void:
	if _waiting_for_result:
		return

	_waiting_for_result = true
	_player_choice = choice
	_pile_button.disabled = true
	_face_button.disabled = true

	# Determine coin result
	var coin_result: String = "pile" if randf() < 0.5 else "face"

	# Coin flip animation
	await _animate_coin_flip(coin_result)

	# Check prediction
	var correct: bool = (_player_choice == coin_result)
	var feedback_color: Color = MG_PALETTE.green if correct else MG_PALETTE.red
	if correct:
		_correct_predictions += 1

	_coin_label.add_theme_color_override("font_color", feedback_color)
	var coin_style: StyleBoxFlat = _coin_frame.get_theme_stylebox("panel") as StyleBoxFlat
	if coin_style:
		coin_style.border_color = feedback_color

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


func _animate_coin_flip(result: String) -> void:
	## Animate coin flip: 3 rapid vertical flips then land on result.
	if not _coin_frame or not is_instance_valid(_coin_frame):
		_coin_label.text = result.to_upper()
		await get_tree().create_timer(0.6).timeout
		return

	var flip_texts: Array = ["?", "!", "?", result.to_upper()]
	for i in range(flip_texts.size()):
		var speed: float = 0.1 + i * 0.05  # Decelerate: 0.1s, 0.15s, 0.2s, 0.25s
		# Squish down (coin seen from edge)
		var tw_down := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw_down.tween_property(_coin_frame, "scale:y", 0.05, speed)
		await tw_down.finished
		# Swap text at midpoint
		_coin_label.text = flip_texts[i]
		# Expand back (coin face visible)
		var tw_up := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw_up.tween_property(_coin_frame, "scale:y", 1.0, speed)
		await tw_up.finished


func _start_next_round() -> void:
	_waiting_for_result = false
	_player_choice = ""
	_pile_button.disabled = false
	_face_button.disabled = false
	_round_label.text = "Manche %d/%d" % [_current_round, _total_rounds]
	_coin_label.text = "?"
	_coin_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["coin_text"])
	# Reset coin border to gold
	var coin_style: StyleBoxFlat = _coin_frame.get_theme_stylebox("panel") as StyleBoxFlat
	if coin_style:
		coin_style.border_color = MerlinVisual.CRT_PALETTE["coin_edge"]


func _finish_game() -> void:
	var score: int = int((_correct_predictions / float(_total_rounds)) * 100.0)
	var success: bool = score >= 50

	_coin_label.text = "%d/%d" % [_correct_predictions, _total_rounds]
	# Scale final score font relative to coin
	var coin_side := _coin_frame.custom_minimum_size.x if _coin_frame else 60.0
	_coin_label.add_theme_font_size_override("font_size", clampi(int(coin_side * 0.28), 12, 28))

	await get_tree().create_timer(1.2).timeout
	_complete(success, score)
