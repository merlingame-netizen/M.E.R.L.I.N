## ═══════════════════════════════════════════════════════════════════════════════
## FpsCameraController — PS1-era first-person rig (M.E.R.L.I.N.)
## ═══════════════════════════════════════════════════════════════════════════════
## A self-contained CharacterBody3D with mouse-look (yaw on body, pitch on head)
## WASD planar movement, Escape to release/recapture the cursor, and an
## interaction raycast that queries collision metadata for an `interact_id`.
##
## Designed to be reused across:
##   • Menu3DPC      (cabin exterior — slow walk)
##   • MerlinCabinHub (interior — slow walk, lots of small interactions)
##   • Run3D / Forest (faster walk)
##
## The script auto-creates child nodes (Head, Camera3D, RayCast3D, CollisionShape3D)
## if the scene does not provide them, so it works as a "drop-in" or scene-rigged.
## ═══════════════════════════════════════════════════════════════════════════════
extends CharacterBody3D
class_name FpsCameraController

# ─── SIGNALS ───────────────────────────────────────────────────────────────────
signal interaction_hovered(interact_id: String, target: Node)
signal interaction_lost
signal interaction_triggered(interact_id: String, target: Node)
signal mouse_capture_changed(captured: bool)

# ─── EXPORTS ───────────────────────────────────────────────────────────────────
## Movement speed (m/s). Cabin ≈ 1.5, biome ≈ 3.5.
@export var move_speed: float = 1.8
## Mouse sensitivity (radians per pixel of relative mouse motion).
@export var mouse_sensitivity: float = 0.0024
## Pitch clamp in degrees, [min, max].
@export var pitch_limits_deg: Vector2 = Vector2(-70.0, 70.0)
## Length of the interaction raycast (in meters).
@export var interact_distance: float = 2.5
## Bounding box constraining player position. If size == 0, no clamping.
@export var bounds_min: Vector3 = Vector3.ZERO
@export var bounds_max: Vector3 = Vector3.ZERO
## Eye height above the body origin.
@export var eye_height: float = 1.55
## Capture mouse on _ready. Disable for menu-style scenes that need a free cursor.
@export var capture_on_ready: bool = true
## Apply gentle head bob while moving (PS1 era was very subtle).
@export var head_bob_amount: float = 0.02
@export var head_bob_speed: float = 6.0

# ─── INPUT ACTIONS ─────────────────────────────────────────────────────────────
const ACT_FWD: StringName = &"fps_move_forward"
const ACT_BACK: StringName = &"fps_move_back"
const ACT_LEFT: StringName = &"fps_move_left"
const ACT_RIGHT: StringName = &"fps_move_right"
const ACT_INTERACT: StringName = &"fps_interact"
const ACT_TOGGLE_MOUSE: StringName = &"fps_toggle_mouse"

# ─── INTERNAL NODES ────────────────────────────────────────────────────────────
var _head: Node3D
var _camera: Camera3D
var _ray: RayCast3D
var _collision_shape: CollisionShape3D

# ─── STATE ─────────────────────────────────────────────────────────────────────
var _pitch: float = 0.0
var _bob_phase: float = 0.0
var _hovered_id: String = ""
var _hovered_target: Node = null
var _movement_enabled: bool = true


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_ensure_actions()
	_ensure_rig()
	if capture_on_ready:
		set_mouse_captured(true)


func _exit_tree() -> void:
	# Politely return cursor to visible on exit so menus don't break.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# ═══════════════════════════════════════════════════════════════════════════════
# RIG CONSTRUCTION (auto-create children if missing)
# ═══════════════════════════════════════════════════════════════════════════════
func _ensure_rig() -> void:
	# Collision body — small upright capsule.
	_collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "CollisionShape3D"
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.height = 1.7
		cap.radius = 0.30
		_collision_shape.shape = cap
		_collision_shape.position = Vector3(0, 0.85, 0)
		add_child(_collision_shape)

	# Head pivot — rotates on X (pitch).
	_head = get_node_or_null("Head") as Node3D
	if _head == null:
		_head = Node3D.new()
		_head.name = "Head"
		_head.position = Vector3(0, eye_height, 0)
		add_child(_head)

	# Camera child of Head.
	_camera = _head.get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "Camera3D"
		_camera.fov = 70.0
		_camera.near = 0.05
		_camera.far = 200.0
		_head.add_child(_camera)

	# Interaction raycast attached to camera.
	_ray = _camera.get_node_or_null("RayCast3D") as RayCast3D
	if _ray == null:
		_ray = RayCast3D.new()
		_ray.name = "RayCast3D"
		_ray.target_position = Vector3(0, 0, -interact_distance)
		_ray.collide_with_bodies = true
		_ray.collide_with_areas = true
		_camera.add_child(_ray)
	else:
		_ray.target_position = Vector3(0, 0, -interact_distance)


# ═══════════════════════════════════════════════════════════════════════════════
# INPUT ACTIONS
# ═══════════════════════════════════════════════════════════════════════════════
func _ensure_actions() -> void:
	_bind(ACT_FWD, [KEY_W, KEY_UP])
	_bind(ACT_BACK, [KEY_S, KEY_DOWN])
	_bind(ACT_LEFT, [KEY_A, KEY_LEFT])
	_bind(ACT_RIGHT, [KEY_D, KEY_RIGHT])
	_bind(ACT_INTERACT, [KEY_E, KEY_ENTER, KEY_SPACE])
	_bind(ACT_TOGGLE_MOUSE, [KEY_ESCAPE])


func _bind(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var existing: Dictionary = {}
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			existing[(ev as InputEventKey).physical_keycode] = true
	for k in keys:
		if not existing.has(k):
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


# ═══════════════════════════════════════════════════════════════════════════════
# INPUT HANDLING
# ═══════════════════════════════════════════════════════════════════════════════
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACT_TOGGLE_MOUSE):
		set_mouse_captured(Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED)
		return
	if event.is_action_pressed(ACT_INTERACT):
		_try_trigger_interaction()
		return
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			return
		var m: InputEventMouseMotion = event
		# Yaw on body, pitch on head — classic FPS layout.
		rotate_y(-m.relative.x * mouse_sensitivity)
		_pitch = clamp(
			_pitch - m.relative.y * mouse_sensitivity,
			deg_to_rad(pitch_limits_deg.x),
			deg_to_rad(pitch_limits_deg.y))
		if _head:
			_head.rotation.x = _pitch


# ═══════════════════════════════════════════════════════════════════════════════
# PHYSICS
# ═══════════════════════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	if not _movement_enabled:
		velocity = Vector3.ZERO
		_update_interaction_ray()
		return

	var input_dir: Vector2 = Vector2(
		Input.get_action_strength(ACT_RIGHT) - Input.get_action_strength(ACT_LEFT),
		Input.get_action_strength(ACT_BACK) - Input.get_action_strength(ACT_FWD)
	)

	# Translate input into world-space velocity using body basis.
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	# Simple gravity so the player rests on floors / CSG.
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	_apply_bounds()
	_apply_head_bob(delta, input_dir.length())
	_update_interaction_ray()


func _apply_bounds() -> void:
	# If bounds_max == bounds_min (default), do nothing.
	if bounds_min == bounds_max:
		return
	global_position = global_position.clamp(bounds_min, bounds_max)


func _apply_head_bob(delta: float, input_strength: float) -> void:
	if _head == null:
		return
	if input_strength > 0.05 and is_on_floor():
		_bob_phase += delta * head_bob_speed
		_head.position.y = eye_height + sin(_bob_phase) * head_bob_amount
	else:
		_bob_phase = lerpf(_bob_phase, 0.0, 0.1)
		_head.position.y = lerpf(_head.position.y, eye_height, 0.2)


# ═══════════════════════════════════════════════════════════════════════════════
# INTERACTION
# ═══════════════════════════════════════════════════════════════════════════════
func _update_interaction_ray() -> void:
	if _ray == null:
		return
	_ray.force_raycast_update()
	if _ray.is_colliding():
		var collider: Node = _ray.get_collider()
		var id: String = _resolve_interact_id(collider)
		if id.is_empty():
			_clear_hover()
			return
		if id != _hovered_id:
			_hovered_id = id
			_hovered_target = collider
			interaction_hovered.emit(id, collider)
	else:
		_clear_hover()


func _clear_hover() -> void:
	if _hovered_id.is_empty():
		return
	_hovered_id = ""
	_hovered_target = null
	interaction_lost.emit()


func _resolve_interact_id(target: Node) -> String:
	# Walk up the parent chain looking for a node carrying meta `interact_id`.
	var cur: Node = target
	while cur != null:
		if cur.has_meta("interact_id"):
			return str(cur.get_meta("interact_id"))
		# Convention: parent of a CollisionObject3D often holds the ID.
		cur = cur.get_parent()
	return ""


func _try_trigger_interaction() -> void:
	if _hovered_id.is_empty():
		return
	interaction_triggered.emit(_hovered_id, _hovered_target)


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════
func set_mouse_captured(captured: bool) -> void:
	if captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_capture_changed.emit(captured)


func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled


func set_bounds(min_corner: Vector3, max_corner: Vector3) -> void:
	bounds_min = min_corner
	bounds_max = max_corner


func get_camera() -> Camera3D:
	return _camera


func get_head() -> Node3D:
	return _head


func get_hovered_interact_id() -> String:
	return _hovered_id
