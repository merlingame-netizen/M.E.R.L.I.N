extends Node

signal breakpoint_changed(is_mobile: bool)
signal orientation_changed(is_portrait: bool)
signal swipe_detected(direction: Vector2)

const REFERENCE_WIDTH := 1280.0
const REFERENCE_HEIGHT := 720.0
const MOBILE_BREAKPOINT := 560.0
const TABLET_BREAKPOINT := 900.0
const MIN_TOUCH_TARGET := 48
const SWIPE_THRESHOLD := 50.0
const SWIPE_MAX_TIME := 0.4

var scale_factor: float = 1.0
var font_scale: float = 1.0
var is_mobile: bool = false
var is_tablet: bool = false
var is_portrait: bool = false
var safe_area: Rect2i = Rect2i()

var _touch_start: Vector2 = Vector2.ZERO
var _touch_time: float = 0.0
var _touch_active: bool = false
var _last_is_mobile: bool = false
var _last_is_portrait: bool = false


func _ready() -> void:
	_update_metrics()
	get_viewport().size_changed.connect(_on_viewport_changed)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_touch_start = touch.position
			_touch_time = 0.0
			_touch_active = true
		elif _touch_active:
			_touch_active = false
			var delta: Vector2 = touch.position - _touch_start
			if delta.length() >= SWIPE_THRESHOLD and _touch_time <= SWIPE_MAX_TIME:
				swipe_detected.emit(delta.normalized())
	elif event is InputEventMouseButton and is_mobile:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_touch_start = mb.position
				_touch_time = 0.0
				_touch_active = true
			elif _touch_active:
				_touch_active = false
				var delta: Vector2 = mb.position - _touch_start
				if delta.length() >= SWIPE_THRESHOLD and _touch_time <= SWIPE_MAX_TIME:
					swipe_detected.emit(delta.normalized())


func _process(delta: float) -> void:
	if _touch_active:
		_touch_time += delta


func _on_viewport_changed() -> void:
	_update_metrics()


func _update_metrics() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	scale_factor = minf(vp_size.x / REFERENCE_WIDTH, vp_size.y / REFERENCE_HEIGHT)
	font_scale = clampf(vp_size.x / REFERENCE_WIDTH, 0.6, 1.5)

	is_mobile = vp_size.x <= MOBILE_BREAKPOINT
	is_tablet = vp_size.x > MOBILE_BREAKPOINT and vp_size.x <= TABLET_BREAKPOINT
	is_portrait = vp_size.y > vp_size.x

	safe_area = DisplayServer.get_display_safe_area()

	if is_mobile != _last_is_mobile:
		_last_is_mobile = is_mobile
		breakpoint_changed.emit(is_mobile)
	if is_portrait != _last_is_portrait:
		_last_is_portrait = is_portrait
		orientation_changed.emit(is_portrait)


func scaled(base_size: float) -> float:
	return maxf(roundi(base_size * font_scale), 8.0)


func scaled_i(base_size: int) -> int:
	return maxi(roundi(float(base_size) * font_scale), 8)


func scaled_vec(base: Vector2) -> Vector2:
	return Vector2(base.x * scale_factor, base.y * scale_factor)


func get_safe_margin_top() -> float:
	if safe_area.position.y > 0:
		return float(safe_area.position.y)
	return 0.0


func get_safe_margin_bottom() -> float:
	var screen_h: int = DisplayServer.screen_get_size().y
	var safe_bottom: int = safe_area.position.y + safe_area.size.y
	if safe_bottom > 0 and safe_bottom < screen_h:
		return float(screen_h - safe_bottom)
	return 0.0


func get_content_width(viewport_size: Vector2, max_width: float = 480.0) -> float:
	if is_mobile:
		return viewport_size.x * 0.94
	if is_tablet:
		return minf(max_width, viewport_size.x * 0.88)
	return minf(max_width, viewport_size.x * 0.85)


func apply_touch_margins(control: Control) -> void:
	if control.custom_minimum_size.y < MIN_TOUCH_TARGET:
		control.custom_minimum_size.y = MIN_TOUCH_TARGET
	if is_mobile:
		control.custom_minimum_size.y = maxi(int(control.custom_minimum_size.y), 56)


func get_font_size(base: int) -> int:
	if is_mobile:
		return maxi(roundi(float(base) * clampf(font_scale, 0.75, 1.1)), 10)
	return maxi(roundi(float(base) * font_scale), 8)


func get_spacing() -> float:
	if is_mobile:
		return 6.0
	if is_tablet:
		return 10.0
	return 12.0
