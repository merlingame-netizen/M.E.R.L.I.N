extends RefCounted
## BrocAutowalk — Guided FPS auto-walk along path waypoints.
## Catmull-Rom interpolation, smooth camera look-ahead, head bob.
## Encounter stops: pauses at designated waypoints, emits callback.

var _path_points: PackedVector3Array
var _player: CharacterBody3D
var _head: Node3D
var _camera: Camera3D

var _active: bool = true  # Auto-start enabled
var _waypoint_idx: int = 0
var _segment_t: float = 0.0
var _speed: float = 2.0
var _base_speed: float = 2.0
var _bob_time: float = 0.0
var _zone_centers: Array[Vector3] = []
# C29 — Smooth stop/resume blend so the player doesn't go from 2 m/s to a hard
# stop (and back) when a card opens/closes. 0 = halted, 1 = full speed.
var _motion_blend: float = 1.0
var _motion_target: float = 1.0
const MOTION_LERP_RATE: float = 5.0  # ~0.4s to ramp 0↔1

# Encounter system — stops at specific waypoints
var _encounter_indices: Array[int] = []  # waypoint indices where encounters trigger
var _encounter_callback: Callable = Callable()  # called with encounter index
var _run_complete_callback: Callable = Callable()  # called when path ends
var _next_encounter: int = 0  # index into _encounter_indices
var _stopped: bool = false

const BOB_AMOUNT: float = 0.035
const BOB_SPEED: float = 7.0
const LOOK_AHEAD: int = 4
const LERP_WEIGHT: float = 0.03

# Speed multipliers per zone (slower at sacred/contemplative sites)
const ZONE_SPEED_MULT: Array[float] = [
	1.0,  # Z0 Lisiere — normal
	0.9,  # Z1 Dense — slightly slower
	0.7,  # Z2 Dolmen — sacred site
	0.8,  # Z3 Mare — contemplative
	0.9,  # Z4 Profonde — mysterious
	0.8,  # Z5 Fontaine — sacred spring
	0.5,  # Z6 Cercle — climax, very slow
]


func _init(
	path_points: PackedVector3Array,
	player: CharacterBody3D,
	head: Node3D,
	camera: Camera3D,
	zone_centers: Array[Vector3] = []
) -> void:
	_path_points = path_points
	_player = player
	_head = head
	_camera = camera
	_zone_centers = zone_centers


func is_active() -> bool:
	return _active and not _stopped


func toggle() -> void:
	_active = not _active
	if _active:
		_waypoint_idx = _find_nearest_waypoint(_player.global_position)
		_segment_t = 0.0
		_stopped = false
	else:
		_player.velocity = Vector3.ZERO


## Set up encounter stops at specific waypoint indices.
## callback receives the encounter number (0-based).
func set_encounters(indices: Array[int], callback: Callable) -> void:
	_encounter_indices = indices
	_encounter_callback = callback
	_next_encounter = 0
	_stopped = false


## Resume walking after an encounter is resolved.
func resume_after_encounter() -> void:
	_stopped = false


## C29 — Smoothly ramp speed to 0 (~0.4s). Use when an event overlay opens so
## the player isn't yanked from full speed to a hard stop.
##
## Note: update() is skipped while the overlay is active (caller's invariant),
## so we snap _motion_blend = 0 here to keep the state consistent with intent.
## Otherwise the blend would freeze at 1.0 during the overlay and soft_resume
## would be a no-op. Reviewed: code-reviewer 2026-04-26 MEDIUM #1.
func soft_stop() -> void:
	_motion_target = 0.0
	_motion_blend = 0.0


## C29 — Smoothly ramp speed back to 1.0 (~0.4s) after the overlay closes.
## Resumes from whatever blend the previous soft_stop snapped (typically 0).
func soft_resume() -> void:
	_motion_target = 1.0


## Set callback for when the path ends (run complete).
func set_run_complete_callback(callback: Callable) -> void:
	_run_complete_callback = callback


func update(delta: float) -> void:
	if not _active:
		return
	if _path_points.size() < 2:
		return

	# C29 — Smoothly blend toward _motion_target so card open/close ramps speed
	# instead of a hard stop. lerpf is frame-rate-aware via delta.
	_motion_blend = lerpf(_motion_blend, _motion_target, clampf(MOTION_LERP_RATE * delta, 0.0, 1.0))

	# Adaptive speed based on nearest zone, scaled by the soft-motion blend.
	_speed = _base_speed * _get_zone_speed_mult() * _motion_blend

	var seg_len: float = _segment_length()
	if seg_len < 0.01:
		_advance_waypoint()
		return

	# Below 5% blend is effectively halted — skip path advance to avoid jitter.
	if _motion_blend < 0.05:
		# Still slerp the camera basis below; just don't progress along path.
		var pos_only: Vector3 = _catmull_rom_point(_waypoint_idx, _segment_t)
		pos_only.y = _player.global_position.y
		_player.global_position = pos_only
		return

	_segment_t += (_speed * delta) / seg_len
	while _segment_t >= 1.0:
		_segment_t -= 1.0
		_advance_waypoint()
		if _waypoint_idx == 0:
			break

	# Catmull-Rom position
	var pos: Vector3 = _catmull_rom_point(_waypoint_idx, _segment_t)
	pos.y = _player.global_position.y  # Keep on ground
	_player.global_position = pos

	# Look-ahead target (slight downward bias to see path/ground)
	var look_idx: int = mini(_waypoint_idx + LOOK_AHEAD, _path_points.size() - 1)
	var look_target: Vector3 = _path_points[look_idx]
	look_target.y = pos.y + 1.2  # Below eye level (1.6) to see path/ground ahead

	var current_basis: Basis = _player.global_transform.basis
	var target_dir: Vector3 = (look_target - pos).normalized()
	if target_dir.length_squared() > 0.001:
		var target_transform: Transform3D = _player.global_transform.looking_at(pos + target_dir, Vector3.UP)
		_player.global_transform.basis = current_basis.slerp(target_transform.basis, LERP_WEIGHT)

	# Head bob disabled (user feedback "trop de head bobbing"). Camera stays steady.
	_head.position.y = 1.6
	_head.position.x = 0.0


func _advance_waypoint() -> void:
	_waypoint_idx += 1
	_segment_t = 0.0
	if _waypoint_idx >= _path_points.size() - 1:
		_waypoint_idx = _path_points.size() - 2  # Stop at end, don't loop
		_stopped = true
		if _run_complete_callback.is_valid():
			_run_complete_callback.call()
		return

	# Check encounter stops
	if _next_encounter < _encounter_indices.size():
		if _waypoint_idx >= _encounter_indices[_next_encounter]:
			_stopped = true
			var enc_idx: int = _next_encounter
			_next_encounter += 1
			if _encounter_callback.is_valid():
				_encounter_callback.call(enc_idx)


func _segment_length() -> float:
	var a: int = _waypoint_idx
	var b: int = mini(a + 1, _path_points.size() - 1)
	return _path_points[a].distance_to(_path_points[b])


func _catmull_rom_point(idx: int, t: float) -> Vector3:
	var count: int = _path_points.size()
	var p0: Vector3 = _path_points[maxi(idx - 1, 0)]
	var p1: Vector3 = _path_points[idx]
	var p2: Vector3 = _path_points[mini(idx + 1, count - 1)]
	var p3: Vector3 = _path_points[mini(idx + 2, count - 1)]

	var t2: float = t * t
	var t3: float = t2 * t

	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


func _find_nearest_waypoint(pos: Vector3) -> int:
	var best_idx: int = 0
	var best_dist: float = INF
	for i in _path_points.size():
		var d: float = pos.distance_squared_to(_path_points[i])
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx


func _get_zone_speed_mult() -> float:
	if _zone_centers.is_empty():
		return 1.0
	var pos: Vector3 = _player.global_position
	var best_zi: int = 0
	var best_d: float = INF
	for zi in _zone_centers.size():
		var d: float = Vector2(pos.x - _zone_centers[zi].x, pos.z - _zone_centers[zi].z).length_squared()
		if d < best_d:
			best_d = d
			best_zi = zi
	if best_zi < ZONE_SPEED_MULT.size():
		return ZONE_SPEED_MULT[best_zi]
	return 1.0
