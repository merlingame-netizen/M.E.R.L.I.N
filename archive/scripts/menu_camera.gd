extends Camera3D

## Camera movement script for MainMenu3D
## Allows smooth orbital movement around the scene

@export_group("Movement Settings")
@export var mouse_sensitivity: float = 0.002
@export var movement_speed: float = 3.0
@export var smooth_speed: float = 5.0
@export var enable_mouse_look: bool = true
@export var enable_keyboard_move: bool = true

@export_group("Orbit Settings")
@export var orbit_center: Vector3 = Vector3(0, 1, 0)
@export var min_distance: float = 2.0
@export var max_distance: float = 8.0
@export var min_pitch: float = -30.0
@export var max_pitch: float = 60.0

@export_group("Auto Rotation")
@export var auto_rotate: bool = true
@export var auto_rotate_speed: float = 0.1
@export var auto_rotate_delay: float = 3.0

var _yaw: float = 0.0
var _pitch: float = 0.0
var _distance: float = 5.0
var _target_position: Vector3
var _target_rotation: Vector3
var _mouse_captured: bool = false
var _last_input_time: float = 0.0
var _idle_time: float = 0.0

func _ready() -> void:
	# Initialize from current camera position
	var offset = global_position - orbit_center
	_distance = offset.length()
	_yaw = atan2(offset.x, offset.z)
	_pitch = asin(offset.y / _distance)
	_target_position = global_position
	_target_rotation = rotation

func _input(event: InputEvent) -> void:
	# Toggle mouse capture with right click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_mouse_captured = true
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_mouse_captured = false
		
		# Zoom with scroll wheel
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clamp(_distance - 0.5, min_distance, max_distance)
			_last_input_time = Time.get_ticks_msec() / 1000.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clamp(_distance + 0.5, min_distance, max_distance)
			_last_input_time = Time.get_ticks_msec() / 1000.0
	
	# Mouse look when captured
	if event is InputEventMouseMotion and _mouse_captured and enable_mouse_look:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		_last_input_time = Time.get_ticks_msec() / 1000.0

func _process(delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	_idle_time = current_time - _last_input_time
	
	# Keyboard movement
	if enable_keyboard_move and not _mouse_captured:
		var input_dir = Vector2.ZERO
		if Input.is_action_pressed("ui_left"):
			input_dir.x -= 1
		if Input.is_action_pressed("ui_right"):
			input_dir.x += 1
		if Input.is_action_pressed("ui_up"):
			input_dir.y -= 1
		if Input.is_action_pressed("ui_down"):
			input_dir.y += 1
		
		if input_dir != Vector2.ZERO:
			_yaw += input_dir.x * movement_speed * delta * 0.5
			_pitch += input_dir.y * movement_speed * delta * 0.3
			_pitch = clamp(_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
			_last_input_time = current_time
	
	# Auto rotation when idle
	if auto_rotate and _idle_time > auto_rotate_delay:
		_yaw += auto_rotate_speed * delta
	
	# Calculate orbital position
	var orbit_offset = Vector3(
		sin(_yaw) * cos(_pitch) * _distance,
		sin(_pitch) * _distance,
		cos(_yaw) * cos(_pitch) * _distance
	)
	
	_target_position = orbit_center + orbit_offset
	
	# Smooth interpolation
	global_position = global_position.lerp(_target_position, smooth_speed * delta)
	
	# Look at center
	look_at(orbit_center, Vector3.UP)
