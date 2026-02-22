## De du Destin — D20 mini-game (chance)
## Player clicks to stop a cycling number. Higher difficulty = faster cycling.
## Visual: styled dice frame with wobble during cycling and elastic bounce on stop.

extends MiniGameBase

var _cycling: bool = false
var _current_value: int = 1
var _cycle_speed: float = 0.1  # seconds per tick
var _elapsed: float = 0.0
var _number_label: Label
var _click_button: Button
var _dice_frame: PanelContainer


func _on_start() -> void:
	_build_overlay()

	# Adjust speed based on difficulty
	_cycle_speed = lerp(0.15, 0.03, (_difficulty - 1) / 9.0)

	# Centered container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 340)
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# Title
	var title := _make_label("Dé du Destin", 28, MG_PALETTE.gold)
	vbox.add_child(title)

	# Instructions
	var instructions := _make_label("Le dé tourne... Cliquez pour arrêter!", 18, MG_PALETTE.accent)
	vbox.add_child(instructions)

	# Visual dice frame
	var dice_center := CenterContainer.new()
	dice_center.custom_minimum_size = Vector2(120, 120)
	vbox.add_child(dice_center)

	_dice_frame = PanelContainer.new()
	_dice_frame.custom_minimum_size = Vector2(100, 100)
	var style := StyleBoxFlat.new()
	style.bg_color = MG_PALETTE.paper
	style.border_color = MG_PALETTE.accent
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 3)
	_dice_frame.add_theme_stylebox_override("panel", style)
	_dice_frame.pivot_offset = Vector2(50, 50)
	dice_center.add_child(_dice_frame)

	_number_label = Label.new()
	_number_label.text = "1"
	_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number_label.add_theme_font_size_override("font_size", 56)
	_number_label.add_theme_color_override("font_color", MG_PALETTE.ink)
	_number_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dice_frame.add_child(_number_label)

	# Stop button
	_click_button = _make_button("ARRÊTER LE DÉ", _on_stop_clicked)
	_click_button.custom_minimum_size = Vector2(220, 50)
	vbox.add_child(_click_button)

	# Start cycling
	_cycling = true
	_current_value = randi_range(1, 20)


func _process(delta: float) -> void:
	if not _cycling:
		return

	_elapsed += delta

	if _elapsed >= _cycle_speed:
		_elapsed = 0.0
		_current_value = randi_range(1, 20)
		_number_label.text = str(_current_value)

		# Dice wobble animation
		if _dice_frame and is_instance_valid(_dice_frame):
			_dice_frame.rotation = randf_range(-0.1, 0.1)

		# Tick sound
		var sfx := get_node_or_null("/root/SFXManager")
		if sfx and sfx.has_method("play"):
			sfx.play("minigame_tick")


func _on_key_pressed(keycode: int) -> void:
	if keycode == KEY_SPACE or keycode == KEY_ENTER:
		_on_stop_clicked()


func _on_stop_clicked() -> void:
	if not _cycling:
		return

	_cycling = false
	_click_button.disabled = true
	_click_button.text = "Résultat: %d" % _current_value

	# Score = number * 5 (max 100)
	var score: int = _current_value * 5

	# Success if >= 50 (i.e., rolled 10+)
	var success: bool = score >= 50

	# Visual feedback: color + slam bounce on dice frame
	var result_color: Color = MG_PALETTE.green if success else MG_PALETTE.red
	_number_label.add_theme_color_override("font_color", result_color)

	if _dice_frame and is_instance_valid(_dice_frame):
		_dice_frame.rotation = 0.0
		var frame_style: StyleBoxFlat = _dice_frame.get_theme_stylebox("panel") as StyleBoxFlat
		if frame_style:
			frame_style.border_color = result_color
		# Elastic slam bounce
		var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_dice_frame, "scale", Vector2(1.25, 1.25), 0.15)
		tw.tween_property(_dice_frame, "scale", Vector2(1.0, 1.0), 0.35)
		await tw.finished
	else:
		await get_tree().create_timer(0.5).timeout

	# Wait a moment before completing
	await get_tree().create_timer(0.7).timeout
	_complete(success, score)
