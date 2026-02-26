class_name HubHotspot
extends Control

## Procedural pixel art hotspot button for M.E.R.L.I.N. hub
## Draws circular button with icon, glow, hover animations, and label

signal hotspot_hovered(hotspot_name: String)
signal hotspot_pressed(hotspot_name: String)

enum IconType {
	MOON,
	TREE,
	BOOK,
	GEAR,
	COMPASS
}

## Configuration
var icon_type: IconType = IconType.MOON
var hotspot_name: String = ""
var label_text: String = ""
var accent_color: Color = Color.WHITE

## State
var _is_hovered: bool = false
var _is_pressed: bool = false
var _is_disabled: bool = false

## Animation
var _current_scale: float = 1.0
var _target_scale: float = 1.0
var _breathing_phase: float = 0.0
var _glow_alpha: float = 0.0
var _label_alpha: float = 0.0
var _label_offset: float = 0.0

## Particles
var _particles: Array = []

## Constants
const CIRCLE_RADIUS: float = 28.0
const ICON_SIZE: int = 16
const PIXEL_SIZE: int = 2
const GLOW_RADIUS: float = 36.0
const LABEL_Y_OFFSET: float = 40.0
const PARTICLE_COUNT: int = 6
const PARTICLE_LIFETIME: float = 0.8

func _init() -> void:
	custom_minimum_size = Vector2(64, 80)
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(p_icon_type: IconType, p_hotspot_name: String, p_label_text: String, p_accent_color: Color) -> void:
	icon_type = p_icon_type
	hotspot_name = p_hotspot_name
	label_text = p_label_text
	accent_color = p_accent_color
	queue_redraw()

func set_disabled(disabled: bool) -> void:
	_is_disabled = disabled
	mouse_filter = Control.MOUSE_FILTER_IGNORE if disabled else Control.MOUSE_FILTER_STOP
	queue_redraw()

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	if _is_disabled:
		return

	# Breathing animation
	_breathing_phase += delta * TAU / 5.0
	if _breathing_phase > TAU:
		_breathing_phase -= TAU

	# Scale lerp
	_current_scale = lerpf(_current_scale, _target_scale, delta * 10.0)

	# Hover effects
	if _is_hovered:
		_glow_alpha = lerpf(_glow_alpha, 0.3, delta * 8.0)
		_label_alpha = lerpf(_label_alpha, 1.0, delta * 10.0)
		_label_offset = lerpf(_label_offset, -4.0, delta * 10.0)
	else:
		_glow_alpha = lerpf(_glow_alpha, 0.0, delta * 8.0)
		_label_alpha = lerpf(_label_alpha, 0.6, delta * 10.0)  # Label permanent (60% alpha au repos)
		_label_offset = lerpf(_label_offset, 0.0, delta * 10.0)

	# Update particles
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p.px += p.vl * delta
		p.li -= delta
		if p.li <= 0.0:
			_particles.remove_at(i)

	queue_redraw()

func _draw() -> void:
	var center: Vector2 = Vector2(32, 32)

	# Apply breathing + scale
	var breathing_scale: float = 1.0 + sin(_breathing_phase) * 0.005
	var final_scale: float = _current_scale * breathing_scale

	# Glow halo
	if _glow_alpha > 0.01:
		var glow_color: Color = accent_color
		glow_color.a = _glow_alpha
		draw_circle(center, GLOW_RADIUS * final_scale, glow_color)

	# Background circle
	var bg_color: Color = MerlinVisual.CRT_PALETTE["bg_dark"]
	var outline_color: Color = accent_color.darkened(0.4)
	draw_circle(center, CIRCLE_RADIUS * final_scale, bg_color)
	draw_arc(center, CIRCLE_RADIUS * final_scale, 0, TAU, 32, outline_color, 1.0)

	# Icon
	_draw_icon(center, final_scale)

	# Label
	if _label_alpha > 0.01:
		var font: Font = MerlinVisual.get_font("body")
		var label_pos: Vector2 = Vector2(32, LABEL_Y_OFFSET + _label_offset)
		var label_color: Color = MerlinVisual.CRT_PALETTE["phosphor"]
		label_color.a = _label_alpha
		draw_string(font, label_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, MerlinVisual.CAPTION_SIZE, label_color)

	# Particles
	for p in _particles:
		var particle_alpha: float = p.li / PARTICLE_LIFETIME
		var particle_color: Color = p.cl
		particle_color.a = particle_alpha
		draw_rect(Rect2(p.px, Vector2(2, 2)), particle_color)

	# Disabled overlay
	if _is_disabled:
		modulate.a = 0.3
	else:
		modulate.a = 1.0

func _draw_icon(center: Vector2, scale: float) -> void:
	var pixels: Array = _get_icon_pixels()
	var offset: Vector2 = center - Vector2(ICON_SIZE, ICON_SIZE) * 0.5 * PIXEL_SIZE * scale

	var color_outline: Color = accent_color.darkened(0.4)
	var color_fill: Color = accent_color
	var color_highlight: Color = accent_color.lightened(0.4)

	for p in pixels:
		var x: int = p.x
		var y: int = p.y
		var c: int = p.c

		var color: Color = Color.TRANSPARENT
		if c == 0:
			color = color_outline
		elif c == 1:
			color = color_fill
		elif c == 2:
			color = color_highlight

		if color.a > 0:
			var rect_pos: Vector2 = offset + Vector2(x, y) * PIXEL_SIZE * scale
			var rect_size: Vector2 = Vector2(PIXEL_SIZE, PIXEL_SIZE) * scale
			draw_rect(Rect2(rect_pos, rect_size), color)

func _get_icon_pixels() -> Array:
	match icon_type:
		IconType.MOON:
			return _moon_pixels()
		IconType.TREE:
			return _tree_pixels()
		IconType.BOOK:
			return _book_pixels()
		IconType.GEAR:
			return _gear_pixels()
		IconType.COMPASS:
			return _compass_pixels()
	return []

func _moon_pixels() -> Array:
	var pixels: Array = []
	# Outer circle
	for y in range(16):
		for x in range(16):
			var dx: float = x - 8.0
			var dy: float = y - 8.0
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < 5.5 and dist > 4.5:
				pixels.append({x = x, y = y, c = 0})
			elif dist <= 4.5:
				# Check if inside inner offset circle (crescent cutout)
				var dx2: float = x - 10.0
				var dy2: float = y - 8.0
				var dist2: float = sqrt(dx2 * dx2 + dy2 * dy2)
				if dist2 > 4.0:
					pixels.append({x = x, y = y, c = 1})
	return pixels

func _tree_pixels() -> Array:
	var pixels: Array = []
	# Trunk (bottom half, center 2px wide)
	for y in range(10, 16):
		pixels.append({x = 7, y = y, c = 0})
		pixels.append({x = 8, y = y, c = 0})
	# Crown (circle top half)
	for y in range(16):
		for x in range(16):
			var dx: float = x - 8.0
			var dy: float = y - 6.0
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < 4.5 and dist > 3.5:
				pixels.append({x = x, y = y, c = 0})
			elif dist <= 3.5:
				pixels.append({x = x, y = y, c = 2})
	return pixels

func _book_pixels() -> Array:
	var pixels: Array = []
	# Left page
	for y in range(3, 13):
		for x in range(2, 7):
			if y == 3 or y == 12 or x == 2 or x == 6:
				pixels.append({x = x, y = y, c = 0})
			else:
				pixels.append({x = x, y = y, c = 1})
	# Right page
	for y in range(3, 13):
		for x in range(9, 14):
			if y == 3 or y == 12 or x == 9 or x == 13:
				pixels.append({x = x, y = y, c = 0})
			else:
				pixels.append({x = x, y = y, c = 1})
	# Spine
	for y in range(3, 13):
		pixels.append({x = 8, y = y, c = 0})
	return pixels

func _gear_pixels() -> Array:
	var pixels: Array = []
	var center_x: float = 8.0
	var center_y: float = 8.0
	# Teeth (6 rectangular teeth at 60-degree intervals)
	for i in range(6):
		var angle: float = float(i) * TAU / 6.0
		var tooth_x: int = int(center_x + cos(angle) * 6.0)
		var tooth_y: int = int(center_y + sin(angle) * 6.0)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var px: int = tooth_x + dx
				var py: int = tooth_y + dy
				if px >= 0 and px < 16 and py >= 0 and py < 16:
					pixels.append({x = px, y = py, c = 0})
	# Inner circle
	for y in range(16):
		for x in range(16):
			var dx: float = x - center_x
			var dy: float = y - center_y
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < 3.5:
				pixels.append({x = x, y = y, c = 1})
	return pixels

func _compass_pixels() -> Array:
	var pixels: Array = []
	# Cross shape
	for y in range(16):
		pixels.append({x = 8, y = y, c = 0})
	for x in range(16):
		pixels.append({x = x, y = 8, c = 0})
	# Arrow pointing up
	pixels.append({x = 7, y = 2, c = 2})
	pixels.append({x = 8, y = 1, c = 2})
	pixels.append({x = 9, y = 2, c = 2})
	# Outer circle
	for y in range(16):
		for x in range(16):
			var dx: float = x - 8.0
			var dy: float = y - 8.0
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist > 6.5 and dist < 7.5:
				pixels.append({x = x, y = y, c = 0})
	return pixels

func _gui_input(event: InputEvent) -> void:
	if _is_disabled:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _is_point_inside(mb.position):
					_on_press()
			else:
				if _is_pressed:
					_on_release()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_on_hover_enter()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_on_hover_exit()

func _is_point_inside(point: Vector2) -> bool:
	var center: Vector2 = Vector2(32, 32)
	var dist: float = center.distance_to(point)
	return dist <= CIRCLE_RADIUS

func _on_hover_enter() -> void:
	if _is_disabled:
		return
	_is_hovered = true
	_target_scale = 1.2
	hotspot_hovered.emit(hotspot_name)

func _on_hover_exit() -> void:
	_is_hovered = false
	_target_scale = 1.0

func _on_press() -> void:
	_is_pressed = true
	_target_scale = 0.92

func _on_release() -> void:
	_is_pressed = false
	_target_scale = 1.2 if _is_hovered else 1.0
	_spawn_particles()
	hotspot_pressed.emit(hotspot_name)

func _spawn_particles() -> void:
	var center: Vector2 = Vector2(32, 32)
	for i in range(PARTICLE_COUNT):
		var angle: float = float(i) * TAU / float(PARTICLE_COUNT)
		var velocity: Vector2 = Vector2(cos(angle), sin(angle)) * 60.0
		_particles.append({
			px = center,
			vl = velocity,
			li = PARTICLE_LIFETIME,
			cl = accent_color
		})
