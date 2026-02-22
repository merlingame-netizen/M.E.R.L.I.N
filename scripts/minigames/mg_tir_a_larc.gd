## Tir à l'Arc — Oscillating target mini-game (finesse)
## Target moves left-right. Click to fire. Distance from center = score.

extends MiniGameBase

var _oscillating: bool = false
var _target_position: float = 0.5  # 0.0 to 1.0
var _oscillation_speed: float = 1.0  # units per second
var _oscillation_direction: float = 1.0
var _target_size: float = 0.3  # width of target zone
var _fired: bool = false

var _title_label: Label
var _target_display: Control
var _target_marker: ColorRect
var _fire_button: Button
var _result_label: Label


func _on_start() -> void:
	_build_overlay()

	# Adjust difficulty
	_oscillation_speed = lerp(0.5, 2.5, (_difficulty - 1) / 9.0)
	_target_size = lerp(0.4, 0.15, (_difficulty - 1) / 9.0)

	# Container
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(get_viewport_rect().size.x / 2 - 220, get_viewport_rect().size.y / 2 - 160)
	vbox.custom_minimum_size = Vector2(440, 320)
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	# Title
	_title_label = _make_label("Tir à l'Arc", 28, MG_PALETTE.gold)
	vbox.add_child(_title_label)

	# Instructions
	var instructions := _make_label("Visez le centre! Cliquez pour tirer.", 18, MG_PALETTE.accent)
	vbox.add_child(instructions)

	# Target display area
	_target_display = Control.new()
	_target_display.custom_minimum_size = Vector2(400, 80)
	vbox.add_child(_target_display)

	# Target background
	var bg := ColorRect.new()
	bg.color = MG_PALETTE.paper
	bg.size = Vector2(400, 80)
	_target_display.add_child(bg)

	# Center line
	var center_line := ColorRect.new()
	center_line.color = MG_PALETTE.gold
	center_line.position = Vector2(197, 0)
	center_line.size = Vector2(6, 80)
	_target_display.add_child(center_line)

	# Moving marker
	_target_marker = ColorRect.new()
	_target_marker.color = MG_PALETTE.red
	_target_marker.size = Vector2(12, 70)
	_target_marker.position = Vector2(194, 5)
	_target_display.add_child(_target_marker)

	# Fire button
	_fire_button = _make_button("TIRER!", _on_fire_clicked)
	_fire_button.custom_minimum_size = Vector2(200, 50)
	vbox.add_child(_fire_button)

	# Result label
	_result_label = _make_label("", 20, MG_PALETTE.ink)
	vbox.add_child(_result_label)

	# Start oscillation
	_oscillating = true
	_target_position = 0.5


func _process(delta: float) -> void:
	if not _oscillating:
		return

	# Oscillate target
	_target_position += _oscillation_direction * _oscillation_speed * delta

	if _target_position >= 1.0:
		_target_position = 1.0
		_oscillation_direction = -1.0
	elif _target_position <= 0.0:
		_target_position = 0.0
		_oscillation_direction = 1.0

	# Update marker position
	var x_pos: float = _target_position * 376.0  # 400 - 24 (marker width + padding)
	_target_marker.position.x = x_pos


func _on_key_pressed(keycode: int) -> void:
	if keycode == KEY_SPACE or keycode == KEY_ENTER:
		_on_fire_clicked()


func _on_fire_clicked() -> void:
	if _fired or not _oscillating:
		return

	_fired = true
	_oscillating = false
	_fire_button.disabled = true

	# Calculate distance from center (0.5)
	var distance_from_center: float = abs(_target_position - 0.5)

	# Score based on proximity (closer = higher)
	# Perfect center = 100, edge = 0
	var score: int = int((1.0 - (distance_from_center * 2.0)) * 100.0)
	score = clampi(score, 0, 100)

	# Determine success (within target zone)
	var success: bool = distance_from_center <= (_target_size / 2.0)

	# Visual feedback
	_target_marker.color = MG_PALETTE.green if success else MG_PALETTE.red

	if score >= 90:
		_result_label.text = "Tir parfait! (%d pts)" % score
		_result_label.add_theme_color_override("font_color", MG_PALETTE.green)
	elif score >= 60:
		_result_label.text = "Bien visé! (%d pts)" % score
		_result_label.add_theme_color_override("font_color", MG_PALETTE.accent)
	else:
		_result_label.text = "Raté... (%d pts)" % score
		_result_label.add_theme_color_override("font_color", MG_PALETTE.red)

	# SFX
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_tick")

	await get_tree().create_timer(1.5).timeout
	_complete(success, score)
