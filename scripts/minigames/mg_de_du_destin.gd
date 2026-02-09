## De du Destin — D20 mini-game (chance)
## Player clicks to stop a cycling number. Higher difficulty = faster cycling.

extends MiniGameBase

var _cycling: bool = false
var _current_value: int = 1
var _cycle_speed: float = 0.1  # seconds per tick
var _elapsed: float = 0.0
var _number_label: Label
var _click_button: Button


func _on_start() -> void:
	_build_overlay()

	# Adjust speed based on difficulty
	_cycle_speed = lerp(0.15, 0.03, (_difficulty - 1) / 9.0)

	# Container
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(get_viewport_rect().size.x / 2 - 150, get_viewport_rect().size.y / 2 - 120)
	vbox.custom_minimum_size = Vector2(300, 240)
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	# Title
	var title := _make_label("Dé du Destin", 28, MG_PALETTE.gold)
	vbox.add_child(title)

	# Instructions
	var instructions := _make_label("Le dé tourne... Cliquez pour arrêter!", 18, MG_PALETTE.accent)
	vbox.add_child(instructions)

	# Big number display
	_number_label = _make_label("1", 72, MG_PALETTE.red)
	vbox.add_child(_number_label)

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

		# Tick sound
		var sfx := get_node_or_null("/root/SFXManager")
		if sfx and sfx.has_method("play"):
			sfx.play("minigame_tick")


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

	# Visual feedback
	_number_label.add_theme_color_override("font_color", MG_PALETTE.green if success else MG_PALETTE.red)

	# Wait a moment before completing
	await get_tree().create_timer(1.2).timeout
	_complete(success, score)
