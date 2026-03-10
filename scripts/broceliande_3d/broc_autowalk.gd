extends RefCounted
## BrocAutowalk — Guided FPS auto-walk along path waypoints.
## Catmull-Rom interpolation, smooth camera look-ahead, head bob.

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
	return _active


func toggle() -> void:
	_active = not _active
	if _active:
		# Find nearest waypoint to current player position
		_waypoint_idx = _find_nearest_waypoint(_player.global_position)
		_segment_t = 0.0
	else:
		# Zero velocity to prevent lurch on resume of manual control
		_player.velocity = Vector3.ZERO


func update(delta: float) -> void:
	if not _active:
		return
	if _path_points.size() < 2:
		return

	# Adaptive speed based on nearest zone
	_speed = _base_speed * _get_zone_speed_mult()

	var seg_len: float = _segment_length()
	if seg_len < 0.01:
		_advance_waypoint()
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

	# Head bob
	_bob_time += delta * BOB_SPEED
	_head.position.y = 1.6 + sin(_bob_time) * BOB_AMOUNT
	_head.position.x = cos(_bob_time * 0.5) * BOB_AMOUNT * 0.5


func _advance_waypoint() -> void:
	_waypoint_idx += 1
	_segment_t = 0.0
	if _waypoint_idx >= _path_points.size() - 1:
		_waypoint_idx = 0  # Loop


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
