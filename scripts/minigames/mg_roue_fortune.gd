extends MiniGameBase
## Roue de Fortune — Spinning wheel mini-game (chance-based)

var wheel_angle: float = 0.0
var wheel_speed: float = 0.0
var is_spinning: bool = false
var segments: Array[int] = []
var wheel_label: Label
var stop_button: Button
var result_label: Label

func _on_start() -> void:
	_build_overlay()
	_setup_segments()
	_build_ui()
	_start_wheel()

func _setup_segments() -> void:
	# Difficulty affects bad segments ratio
	var bad_count: int = mini(1 + int(_difficulty / 3.0), 5)
	segments = [100, 100, 75, 75, 50, 50, 20, 0]

	# Shuffle to randomize positions
	segments.shuffle()

	# Add more bad segments at high difficulty
	if _difficulty >= 7:
		segments[randi() % 8] = 0
	if _difficulty >= 9:
		segments[randi() % 8] = 20

func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.position = Vector2(400, 150)
	vbox.custom_minimum_size = Vector2(400, 500)
	add_child(vbox)

	var title: Label = _make_label("Roue de Fortune", 32, MG_PALETTE.gold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_make_spacer(40))

	# Wheel display
	wheel_label = _make_label("8", 64, MG_PALETTE.accent)
	wheel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wheel_label.custom_minimum_size = Vector2(200, 200)
	vbox.add_child(wheel_label)

	vbox.add_child(_make_spacer(40))

	# Stop button
	stop_button = _make_button("ARRÊTER LA ROUE", _on_stop_pressed)
	stop_button.custom_minimum_size = Vector2(300, 60)
	vbox.add_child(stop_button)

	vbox.add_child(_make_spacer(20))

	# Result label (hidden initially)
	result_label = _make_label("", 24, MG_PALETTE.green)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.visible = false
	vbox.add_child(result_label)

func _make_spacer(height: int) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _start_wheel() -> void:
	is_spinning = true
	wheel_speed = 15.0 + randf() * 5.0
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_start")

func _process(delta: float) -> void:
	if not is_spinning:
		return

	# Update wheel rotation
	wheel_angle += wheel_speed * delta
	if wheel_angle >= TAU:
		wheel_angle -= TAU

	# Calculate current segment
	var segment_index: int = int((wheel_angle / TAU) * 8.0) % 8
	wheel_label.text = str(segment_index + 1)

	# Decelerate if stopped by player
	if wheel_speed > 0.0 and stop_button.disabled:
		wheel_speed -= delta * 8.0
		if wheel_speed <= 0.0:
			wheel_speed = 0.0
			_finish_spin(segment_index)

func _on_key_pressed(keycode: int) -> void:
	if keycode == KEY_SPACE or keycode == KEY_ENTER:
		_on_stop_pressed()


func _on_stop_pressed() -> void:
	stop_button.disabled = true
	stop_button.text = "Ralentissement..."
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_tick")

func _finish_spin(segment_index: int) -> void:
	is_spinning = false
	var score: int = segments[segment_index]

	result_label.text = "Segment " + str(segment_index + 1) + " : " + str(score) + " points !"
	result_label.modulate = MG_PALETTE.green if score > 50 else MG_PALETTE.red if score == 0 else MG_PALETTE.gold
	result_label.visible = true

	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_success" if score > 50 else "minigame_fail")

	# Wait before completing
	await get_tree().create_timer(2.0).timeout
	_complete(score > 0, score)
