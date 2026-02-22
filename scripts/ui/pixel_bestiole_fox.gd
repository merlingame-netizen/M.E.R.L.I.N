class_name PixelBestioleFox
extends Control

signal assembly_complete

const GRID_W := 14
const GRID_H := 10
const DEFAULT_TARGET_SIZE := 150.0

const FOX_GRID := [
	[0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0],
	[0, 0, 1, 2, 2, 1, 0, 1, 2, 2, 1, 0, 0, 0],
	[0, 1, 2, 2, 2, 2, 1, 2, 2, 2, 2, 1, 0, 0],
	[0, 1, 2, 4, 2, 2, 2, 2, 4, 2, 2, 1, 0, 0],
	[1, 2, 2, 2, 2, 5, 2, 2, 2, 2, 2, 2, 1, 0],
	[1, 2, 3, 3, 2, 2, 2, 2, 3, 3, 2, 2, 2, 1],
	[0, 1, 2, 3, 3, 2, 2, 3, 3, 2, 2, 2, 2, 1],
	[0, 0, 1, 2, 2, 2, 3, 3, 2, 2, 2, 2, 2, 1],
	[0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 1, 0],
	[0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0],
]

var _palette: Array[Color] = [
	Color.TRANSPARENT,
	Color(0.18, 0.11, 0.30), # outline violet
	Color(0.46, 0.28, 0.70), # body violet
	Color(0.58, 0.36, 0.82), # body light
	Color(0.32, 0.74, 1.0),  # blue eyes
	Color(0.86, 0.66, 0.96), # nose
]

var _pixel_size: float = 10.0
var _container: Control
var _pixels: Array[ColorRect] = []
var _eye_pixels: Array[ColorRect] = []
var _tail_pixels: Array[ColorRect] = []
var _assembled: bool = false
var _blink_timer: float = 0.0
var _blink_duration: float = 0.0
var _tail_time: float = 0.0
var _bob_time: float = 0.0


func setup(target_size: float = DEFAULT_TARGET_SIZE) -> void:
	_pixel_size = target_size / float(GRID_W)
	custom_minimum_size = Vector2(_pixel_size * GRID_W, _pixel_size * GRID_H)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _container == null:
		_container = Control.new()
		_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_container)
	_clear()


func assemble(instant: bool = false) -> void:
	_clear()
	_assembled = false
	_blink_timer = randf_range(2.0, 4.2)
	_blink_duration = 0.0
	_tail_time = 0.0
	_bob_time = 0.0

	var eye_positions := {
		Vector2i(3, 3): true,
		Vector2i(3, 8): true,
	}
	var tail_positions := {
		Vector2i(5, 13): true,
		Vector2i(6, 13): true,
		Vector2i(7, 13): true,
		Vector2i(7, 12): true,
		Vector2i(8, 12): true,
	}

	var targets: Array[Dictionary] = []
	for row in range(GRID_H):
		var row_data: Array = FOX_GRID[row]
		for col in range(GRID_W):
			var idx := int(row_data[col])
			if idx <= 0 or idx >= _palette.size():
				continue
			targets.append({
				"row": row,
				"col": col,
				"color": _palette[idx],
				"target_pos": Vector2(col * _pixel_size, row * _pixel_size),
				"is_eye": eye_positions.has(Vector2i(row, col)),
				"is_tail": tail_positions.has(Vector2i(row, col)),
			})

	if instant:
		for t in targets:
			_make_pixel(t, true)
		_assembled = true
		assembly_complete.emit()
		return

	targets.shuffle()
	for i in range(targets.size()):
		_make_pixel(targets[i], false)
		if i % 5 == 4:
			await get_tree().create_timer(0.02).timeout

	_assembled = true
	assembly_complete.emit()


func _make_pixel(t: Dictionary, instant: bool) -> void:
	var px := ColorRect.new()
	px.size = Vector2(_pixel_size, _pixel_size)
	px.color = t.color
	px.mouse_filter = Control.MOUSE_FILTER_IGNORE
	px.set_meta("base_pos", t.target_pos)
	px.set_meta("tail_phase", float(t.row + t.col) * 0.45)
	_container.add_child(px)
	_pixels.append(px)

	if t.is_eye:
		_eye_pixels.append(px)
	if t.is_tail:
		_tail_pixels.append(px)

	if instant:
		px.position = t.target_pos
		px.modulate.a = 1.0
		return

	px.position = Vector2(
		t.target_pos.x + randf_range(-26.0, 26.0),
		t.target_pos.y - randf_range(42.0, 130.0)
	)
	px.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(px, "modulate:a", 1.0, 0.05)
	tw.parallel().tween_property(px, "position", t.target_pos, randf_range(0.18, 0.32)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not _assembled:
		return
	_bob_time += delta
	_tail_time += delta
	_blink_timer -= delta

	_container.position.y = sin(_bob_time * 2.2) * 1.8

	for tail_px in _tail_pixels:
		if tail_px == null or not is_instance_valid(tail_px):
			continue
		var base_pos: Vector2 = tail_px.get_meta("base_pos", tail_px.position)
		var phase: float = float(tail_px.get_meta("tail_phase", 0.0))
		var wag := sin(_tail_time * 7.2 + phase) * 1.8
		tail_px.position = base_pos + Vector2(wag, 0.0)

	if _blink_timer <= 0.0 and _blink_duration <= 0.0:
		_blink_duration = 0.13
		_blink_timer = randf_range(2.2, 4.8)

	if _blink_duration > 0.0:
		_blink_duration -= delta
		var blink_alpha := 0.16 if _blink_duration > 0.0 else 1.0
		for eye_px in _eye_pixels:
			if eye_px == null or not is_instance_valid(eye_px):
				continue
			eye_px.modulate.a = blink_alpha
	else:
		for eye_px in _eye_pixels:
			if eye_px == null or not is_instance_valid(eye_px):
				continue
			eye_px.modulate.a = 1.0


func _clear() -> void:
	if _container == null:
		return
	for px in _pixels:
		if is_instance_valid(px):
			px.queue_free()
	_pixels.clear()
	_eye_pixels.clear()
	_tail_pixels.clear()
