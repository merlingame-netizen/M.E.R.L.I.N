## MG_MEDITATION — Méditation (Esprit)
## A wandering cursor moves randomly. Player holds SPACE to focus it toward center.
## Score = time spent in the center zone over 6 seconds.

extends MiniGameBase

var _cursor_pos: Vector2 = Vector2(0.5, 0.5)
var _drift_speed: float = 0.15
var _focus_strength: float = 0.3
var _holding: bool = false
var _time_left: float = 6.0
var _max_time: float = 6.0
var _time_in_zone: float = 0.0
var _drift_angle: float = 0.0
var _drift_change_timer: float = 0.0

var _cursor_rect: ColorRect
var _zone_rect: ColorRect
var _arena_rect: ColorRect
var _timer_label: Label
var _status_label: Label

const ARENA_SIZE: float = 250.0
const CURSOR_SIZE: float = 16.0
const ZONE_RADIUS: float = 0.2


func _on_start() -> void:
	_build_overlay()

	_drift_speed = 0.1 + (_difficulty * 0.025)
	_focus_strength = 0.4 - (_difficulty * 0.015)
	_focus_strength = maxf(_focus_strength, 0.15)
	_max_time = 7.0 - (_difficulty * 0.15)
	_max_time = maxf(_max_time, 4.0)
	_time_left = _max_time

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -200
	vbox.offset_top = -240
	vbox.offset_right = 200
	vbox.offset_bottom = 240
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	var title := _make_label("MÉDITATION", 28, MG_PALETTE.accent)
	vbox.add_child(title)

	var subtitle := _make_label("Maintiens ESPACE pour recentrer l'esprit", 14)
	vbox.add_child(subtitle)

	_timer_label = _make_label("Temps: %.1f s" % _time_left, 18, MG_PALETTE.gold)
	vbox.add_child(_timer_label)

	# Arena
	var arena_center := CenterContainer.new()
	arena_center.custom_minimum_size = Vector2(ARENA_SIZE + 20, ARENA_SIZE + 20)
	vbox.add_child(arena_center)

	var arena_container := Control.new()
	arena_container.custom_minimum_size = Vector2(ARENA_SIZE, ARENA_SIZE)
	arena_center.add_child(arena_container)

	_arena_rect = ColorRect.new()
	_arena_rect.color = MG_PALETTE.paper
	_arena_rect.position = Vector2.ZERO
	_arena_rect.size = Vector2(ARENA_SIZE, ARENA_SIZE)
	arena_container.add_child(_arena_rect)

	# Center zone indicator
	var zone_size: float = ZONE_RADIUS * 2.0 * ARENA_SIZE
	_zone_rect = ColorRect.new()
	_zone_rect.color = Color(MG_PALETTE.gold.r, MG_PALETTE.gold.g, MG_PALETTE.gold.b, 0.2)
	_zone_rect.position = Vector2((ARENA_SIZE - zone_size) / 2.0, (ARENA_SIZE - zone_size) / 2.0)
	_zone_rect.size = Vector2(zone_size, zone_size)
	arena_container.add_child(_zone_rect)

	# Cursor
	_cursor_rect = ColorRect.new()
	_cursor_rect.color = MG_PALETTE.green
	_cursor_rect.size = Vector2(CURSOR_SIZE, CURSOR_SIZE)
	_cursor_rect.position = Vector2(ARENA_SIZE / 2.0 - CURSOR_SIZE / 2.0, ARENA_SIZE / 2.0 - CURSOR_SIZE / 2.0)
	arena_container.add_child(_cursor_rect)

	_status_label = _make_label("", 18, MG_PALETTE.green)
	vbox.add_child(_status_label)


func _process(delta: float) -> void:
	if _finished:
		return

	_time_left -= delta
	_timer_label.text = "Temps: %.1f s" % maxf(_time_left, 0.0)

	# Random drift direction changes
	_drift_change_timer -= delta
	if _drift_change_timer <= 0:
		_drift_angle = randf() * TAU
		_drift_change_timer = 0.3 + randf() * 0.5

	# Apply drift (always pushing away from center)
	_cursor_pos.x += cos(_drift_angle) * _drift_speed * delta
	_cursor_pos.y += sin(_drift_angle) * _drift_speed * delta

	# Apply focus (holding pulls toward center)
	if _holding:
		var to_center := Vector2(0.5, 0.5) - _cursor_pos
		_cursor_pos += to_center * _focus_strength * delta

	# Clamp to arena
	_cursor_pos.x = clampf(_cursor_pos.x, 0.05, 0.95)
	_cursor_pos.y = clampf(_cursor_pos.y, 0.05, 0.95)

	# Update cursor visual
	_cursor_rect.position = Vector2(
		_cursor_pos.x * ARENA_SIZE - CURSOR_SIZE / 2.0,
		_cursor_pos.y * ARENA_SIZE - CURSOR_SIZE / 2.0
	)

	# Check if in zone
	var dist_from_center: float = (_cursor_pos - Vector2(0.5, 0.5)).length()
	if dist_from_center <= ZONE_RADIUS:
		_time_in_zone += delta
		_cursor_rect.color = MG_PALETTE.gold
	else:
		_cursor_rect.color = MG_PALETTE.green if _holding else MG_PALETTE.red

	if _time_left <= 0:
		_end_game()


func _on_key_pressed(keycode: int) -> void:
	if keycode == KEY_SPACE:
		_holding = true


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return

	if event is InputEventKey and not event.pressed and event.keycode == KEY_SPACE:
		_holding = false
		return

	super._unhandled_input(event)


func _end_game() -> void:
	if _finished:
		return
	var zone_ratio: float = clampf(_time_in_zone / _max_time, 0.0, 1.0)
	var score: int = clampi(int(zone_ratio * 100.0), 0, 100)
	var success: bool = score >= 40

	_status_label.text = "Centré! (%d pts)" % score if success else "Dispersé... (%d pts)" % score
	_status_label.modulate = MG_PALETTE.green if success else MG_PALETTE.red

	await get_tree().create_timer(1.0).timeout
	_complete(success, score)
