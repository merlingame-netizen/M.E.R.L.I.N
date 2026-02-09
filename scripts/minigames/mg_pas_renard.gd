## MG_PAS_RENARD — Pas du Renard (Finesse)
## Dodge left/right obstacles. 3 obstacles from alternating sides.
## Player clicks L/R arrows. Timer shrinks with difficulty.

extends MiniGameBase

const OBSTACLE_COUNT: int = 3
var _obstacles_dodged: int = 0
var _current_obstacle: int = 0
var _obstacle_side: String = ""  # "left" or "right"
var _obstacle_timer: float = 0.0
var _obstacle_delay: float = 2.0
var _status_label: Label
var _arrow_left: Button
var _arrow_right: Button
var _obstacle_indicator: Label


func _on_start() -> void:
	_build_overlay()

	# Difficulty affects reaction time
	_obstacle_delay = 2.5 - (_difficulty * 0.15)  # 2.35s to 1.0s

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -220
	vbox.offset_top = -220
	vbox.offset_right = 220
	vbox.offset_bottom = 220
	vbox.add_theme_constant_override("separation", 25)
	add_child(vbox)

	# Title
	var title := _make_label("PAS DU RENARD", 28, MG_PALETTE.accent)
	vbox.add_child(title)

	var subtitle := _make_label("Esquive les obstacles!", 16)
	vbox.add_child(subtitle)

	# Status
	_status_label = _make_label("Prépare-toi...", 20, MG_PALETTE.ink)
	vbox.add_child(_status_label)

	# Obstacle indicator (shows which side)
	_obstacle_indicator = _make_label("", 48, MG_PALETTE.red)
	_obstacle_indicator.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(_obstacle_indicator)

	# Arrow buttons
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 40)
	vbox.add_child(btn_container)

	_arrow_left = _make_button("← GAUCHE", _on_dodge.bind("left"))
	_arrow_left.custom_minimum_size = Vector2(150, 60)
	btn_container.add_child(_arrow_left)

	_arrow_right = _make_button("DROITE →", _on_dodge.bind("right"))
	_arrow_right.custom_minimum_size = Vector2(150, 60)
	btn_container.add_child(_arrow_right)

	await get_tree().create_timer(1.0).timeout
	_spawn_obstacle()


func _spawn_obstacle() -> void:
	_current_obstacle += 1

	if _current_obstacle > OBSTACLE_COUNT:
		_finish_game()
		return

	# Alternate sides (with some randomness at high difficulty)
	if _difficulty >= 7:
		_obstacle_side = "left" if randf() > 0.5 else "right"
	else:
		_obstacle_side = "right" if (_current_obstacle % 2 == 0) else "left"

	_obstacle_timer = _obstacle_delay
	_status_label.text = "Obstacle %d/%d" % [_current_obstacle, OBSTACLE_COUNT]

	# Show obstacle
	if _obstacle_side == "left":
		_obstacle_indicator.text = "◄◄◄"
	else:
		_obstacle_indicator.text = "►►►"

	# SFX
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_tick")


func _process(delta: float) -> void:
	if _finished or _current_obstacle == 0:
		return

	_obstacle_timer -= delta

	if _obstacle_timer <= 0:
		# Player didn't dodge in time
		_fail_dodge()


func _on_dodge(direction: String) -> void:
	if _finished or _current_obstacle == 0 or _obstacle_side == "":
		return

	# Disable buttons briefly
	_arrow_left.disabled = true
	_arrow_right.disabled = true

	# Check if correct direction
	var correct_dodge: String = "left" if _obstacle_side == "right" else "right"

	if direction == correct_dodge:
		# Success
		_obstacles_dodged += 1
		_obstacle_indicator.modulate = MG_PALETTE.green
		_obstacle_indicator.text = "✓"

		var sfx := get_node_or_null("/root/SFXManager")
		if sfx and sfx.has_method("play"):
			sfx.play("minigame_success")
	else:
		# Wrong direction
		_obstacle_indicator.modulate = MG_PALETTE.red
		_obstacle_indicator.text = "✗"

		var sfx := get_node_or_null("/root/SFXManager")
		if sfx and sfx.has_method("play"):
			sfx.play("minigame_fail")

	await get_tree().create_timer(0.6).timeout

	_obstacle_indicator.modulate = Color.WHITE
	_obstacle_side = ""

	# Re-enable buttons
	_arrow_left.disabled = false
	_arrow_right.disabled = false

	_spawn_obstacle()


func _fail_dodge() -> void:
	_obstacle_indicator.modulate = MG_PALETTE.red
	_obstacle_indicator.text = "✗ RATÉ"

	var sfx := get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_fail")

	await get_tree().create_timer(0.8).timeout
	_finish_game()


func _finish_game() -> void:
	_arrow_left.disabled = true
	_arrow_right.disabled = true

	var score: int = int((_obstacles_dodged / float(OBSTACLE_COUNT)) * 100.0)
	var success: bool = _obstacles_dodged >= 2

	_complete(success, score)
