extends Camera3D
## Ground-clamped walk camera with terrain following.
## WASD on XZ, mouse look, Y follows terrain heightmap + eye_height.

@export var move_speed: float = 6.0
@export var fast_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.002
@export var eye_height: float = 1.7

var _yaw: float = 0.0
var _pitch: float = 0.0
var _captured: bool = false
var _terrain: Node = null  # Reference to scene with get_height()


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_captured = true
	_yaw = rotation.y
	_pitch = rotation.x
	position.y = eye_height


func set_terrain_sampler(terrain_node: Node) -> void:
	_terrain = terrain_node


func _get_terrain_y(x: float, z: float) -> float:
	if _terrain and _terrain.has_method("get_height"):
		return _terrain.get_height(x, z) + eye_height
	return eye_height


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _captured:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_captured = false
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_captured = true

	if event is InputEventMouseMotion and _captured:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, -PI * 0.45, PI * 0.45)
		rotation = Vector3(_pitch, _yaw, 0.0)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			move_speed = minf(move_speed + 1.0, 30.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			move_speed = maxf(move_speed - 1.0, 1.0)
		elif event.button_index == MOUSE_BUTTON_LEFT and not _captured:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_captured = true


func _process(delta: float) -> void:
	if not _captured:
		return

	var speed: float = move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= fast_multiplier

	# Movement on XZ plane (ground-clamped)
	var forward: Vector3 = -transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right: Vector3 = transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var direction: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		direction += forward
	if Input.is_key_pressed(KEY_S):
		direction -= forward
	if Input.is_key_pressed(KEY_A):
		direction -= right
	if Input.is_key_pressed(KEY_D):
		direction += right

	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		position += direction * speed * delta

	# Follow terrain height with smooth interpolation
	var target_y: float = _get_terrain_y(position.x, position.z)
	position.y = lerpf(position.y, target_y, 8.0 * delta)
