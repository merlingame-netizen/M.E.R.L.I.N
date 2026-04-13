## InputAdapter — Unified Input Abstraction (Autoload Singleton)
## Translates touch/mouse/gamepad inputs into unified game actions.
## All game code should use InputAdapter instead of raw Input checks.
extends Node

signal input_method_changed(method: String)  # "touch", "mouse", "gamepad"

enum InputMethod { MOUSE, TOUCH, GAMEPAD }

var current_method: InputMethod = InputMethod.MOUSE
var _last_method_name: String = "mouse"

## Touch-specific state
var touch_active: bool = false
var touch_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_detect_initial_method()


func _input(event: InputEvent) -> void:
	var new_method: InputMethod = current_method

	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		new_method = InputMethod.TOUCH
		if event is InputEventScreenTouch:
			touch_active = event.pressed
			touch_position = event.position
		elif event is InputEventScreenDrag:
			touch_position = event.position
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		new_method = InputMethod.MOUSE
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		new_method = InputMethod.GAMEPAD

	if new_method != current_method:
		current_method = new_method
		var method_name: String = _method_to_string(new_method)
		if method_name != _last_method_name:
			_last_method_name = method_name
			input_method_changed.emit(method_name)


## Returns true if touch is the active input method.
func is_touch() -> bool:
	return current_method == InputMethod.TOUCH


## Returns true if gamepad is the active input method.
func is_gamepad() -> bool:
	return current_method == InputMethod.GAMEPAD


## Returns true if mouse/keyboard is the active input method.
func is_mouse() -> bool:
	return current_method == InputMethod.MOUSE


## Get the current input method as a string.
func get_method_name() -> String:
	return _last_method_name


## Get recommended minimum touch target size in pixels.
func get_min_touch_target() -> float:
	if is_touch():
		return 44.0  # WCAG minimum
	return 24.0  # Mouse precision


func _detect_initial_method() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		current_method = InputMethod.TOUCH
		_last_method_name = "touch"
	elif Input.get_connected_joypads().size() > 0:
		current_method = InputMethod.GAMEPAD
		_last_method_name = "gamepad"
	else:
		current_method = InputMethod.MOUSE
		_last_method_name = "mouse"


func _method_to_string(method: InputMethod) -> String:
	match method:
		InputMethod.MOUSE:
			return "mouse"
		InputMethod.TOUCH:
			return "touch"
		InputMethod.GAMEPAD:
			return "gamepad"
	return "mouse"
