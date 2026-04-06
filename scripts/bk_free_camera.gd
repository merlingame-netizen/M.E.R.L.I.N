extends Camera3D
## Free-fly camera for BK Showcase scene.
## WASD + mouse look. Shift = fast, Scroll = speed adjust.

@export var move_speed: float = 5.0
@export var fast_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.002
@export var scroll_step: float = 1.0

var _yaw: float = 0.0
var _pitch: float = 0.0
var _captured: bool = false


func _ready() -> void:
	# Capture mouse on start
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_captured = true
	# Init yaw/pitch from current rotation
	_yaw = rotation.y
	_pitch = rotation.x


func _unhandled_input(event: InputEvent) -> void:
	# Toggle mouse capture with Escape
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _captured:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_captured = false
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_captured = true

	# Mouse look
	if event is InputEventMouseMotion and _captured:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, -PI * 0.49, PI * 0.49)
		rotation = Vector3(_pitch, _yaw, 0.0)

	# Scroll wheel = adjust speed
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			move_speed = minf(move_speed + scroll_step, 50.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			move_speed = maxf(move_speed - scroll_step, 1.0)

	# Click to recapture
	if event is InputEventMouseButton and event.pressed and not _captured:
		if event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_captured = true


func _process(delta: float) -> void:
	if not _captured:
		return

	var speed: float = move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= fast_multiplier

	var direction: Vector3 = Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		direction -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		direction += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		direction -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		direction += transform.basis.x
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_SPACE):
		direction += Vector3.UP
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_CTRL):
		direction -= Vector3.UP

	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		position += direction * speed * delta
