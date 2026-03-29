extends Node
## BrocAerialDescent — Cinematic aerial descent before auto-walk begins.
##
## Extends Node (not RefCounted) so that create_tween() is available.
##
## Three phases (mirrors the Three.js _aerialDescent in game_scene_3d.js):
##   Phase A (0.8 s) — hover above terrain with a gentle orbit arc
##   Phase B (2.0 s) — spiral descent, smoothstep easing, FOV 85 -> 65
##   Phase C         — snap camera to path start, restore fog, emit signal
##
## Usage:
##   var descent: BrocAerialDescent = BrocAerialDescent.new(
##       camera, path_points, zone_centers, biome_key, world_env)
##   descent.descent_complete.connect(_on_aerial_done)
##   add_child(descent)   # must be in the tree before calling start()
##   descent.start()
##
## The caller is responsible for pausing _autowalk before calling start() and
## for calling _autowalk.resume_after_encounter() (or equivalent) inside the
## descent_complete handler.  The node removes itself from the tree via
## queue_free() after Phase C so no cleanup is needed by the caller.

signal descent_complete  # emitted when Phase C finishes

# --------------------------------------------------------------------------- #
# Per-biome aerial heights (keep terrain visible through fog)
# Keys must match BiomeWalkConfigs keys exactly.
const AERIAL_HEIGHTS: Dictionary = {
	"foret_broceliande": 30.0,
	"landes_bruyere":    25.0,
	"cotes_sauvages":    35.0,
	"collines_dolmens":  32.0,
	"cercles_pierres":   28.0,
	"villages_celtes":   22.0,
	"marais_korrigans":  30.0,
	"iles_mystiques":    22.0,
}

const HOVER_DURATION:   float = 0.8   # seconds — Phase A
const DESCENT_DURATION: float = 2.0   # seconds — Phase B
const FOV_START:        float = 85.0  # Phase A/B start FOV
const FOV_END:          float = 65.0  # Phase C landing FOV (autowalk default)
const FOG_AERIAL_SCALE: float = 0.3   # fog_density multiplier during aerial phase
const SPIRAL_SWEEPS:    float = 1.5   # PI multiplier -> 270-degree sweep
const SPIRAL_RADIUS:    float = 6.0   # max spiral XZ radius at t=0
const HOVER_ORBIT_AMP:  float = 2.0   # XZ amplitude of hover orbit
const HOVER_ANGLE_MAX:  float = 0.2   # radians swept during hover
const EYE_HEIGHT:       float = 1.7   # camera Y above ground_y on landing

# --------------------------------------------------------------------------- #
# Constructor arguments
var _camera:       Camera3D
var _path_points:  PackedVector3Array
var _zone_centers: Array[Vector3]
var _biome_key:    String
var _world_env:    WorldEnvironment  # may be null — guarded everywhere

# Geometry, computed once in _prepare()
var _aerial_pos:       Vector3
var _ground_y:         float
var _start_pos:        Vector3  # path_points[0]
var _path_mid:         Vector3  # look-anchor during hover (15% along path)
var _look_target:      Vector3  # final walk look-ahead (5% along path, ~eye height)
var _orig_fog_density: float

# Per-phase working storage (needed because tween_method delivers only one float)
var _phase_a_origin:  Vector3  # aerial_pos captured at Phase A start
var _phase_b_from:    Vector3  # camera position at Phase B start
var _phase_b_to:      Vector3  # landing position for Phase B

var _running: bool = false

# --------------------------------------------------------------------------- #

func _init(
	camera:       Camera3D,
	path_points:  PackedVector3Array,
	zone_centers: Array[Vector3],
	biome_key:    String,
	world_env:    WorldEnvironment
) -> void:
	_camera       = camera
	_path_points  = path_points
	_zone_centers = zone_centers
	_biome_key    = biome_key
	_world_env    = world_env


## Begin the aerial descent sequence.
## Re-entrant calls are ignored (safe to call from async contexts).
func start() -> void:
	if _running:
		return
	if _path_points.is_empty():
		push_warning("[BrocAerialDescent] No path points — emitting descent_complete immediately")
		descent_complete.emit()
		return
	if not is_instance_valid(_camera):
		push_warning("[BrocAerialDescent] Camera is invalid — skipping aerial")
		descent_complete.emit()
		return

	_running = true
	_prepare()
	_run_phase_a()


# --------------------------------------------------------------------------- #
# Internal — setup
# --------------------------------------------------------------------------- #

## Compute geometry and initialise the renderer state for the aerial view.
func _prepare() -> void:
	_start_pos = _path_points[0]
	_ground_y  = _start_pos.y

	# _path_mid: horizon anchor seen from altitude (15% along the path)
	_path_mid = _sample_path(0.15)

	# _look_target: the point the camera looks toward after landing (5% ahead)
	_look_target   = _sample_path(0.05)
	_look_target.y = _ground_y + 1.0

	# Biome aerial height and offset
	var aerial_h: float     = AERIAL_HEIGHTS.get(_biome_key, 30.0) as float
	var offset_scale: float = aerial_h / 30.0

	_aerial_pos = Vector3(
		_start_pos.x + 8.0 * offset_scale,
		_ground_y + aerial_h,
		_start_pos.z + 12.0 * offset_scale
	)

	# Cache original fog density before we touch it
	if is_instance_valid(_world_env) and _world_env.environment != null:
		_orig_fog_density = _world_env.environment.fog_density
	else:
		_orig_fog_density = 0.0

	# Place camera at aerial position, reduce fog, set wide FOV
	_camera.global_position = _aerial_pos
	_camera.fov = FOV_START
	_set_fog(_orig_fog_density * FOG_AERIAL_SCALE)

	# Point camera at the terrain overview (slightly above ground level)
	_camera.look_at(Vector3(_path_mid.x, _ground_y + 1.0, _path_mid.z), Vector3.UP)


# --------------------------------------------------------------------------- #
# Internal — phases
# --------------------------------------------------------------------------- #

## Phase A: 0.8 s gentle orbit hover at aerial height.
func _run_phase_a() -> void:
	_phase_a_origin = _aerial_pos

	var tween: Tween = _camera.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	# tween_method delivers a single interpolated float to the callback.
	# _step_phase_a reads instance vars for everything else.
	tween.tween_method(_step_phase_a, 0.0, 1.0, HOVER_DURATION)
	tween.tween_callback(_run_phase_b)


## Per-frame callback for Phase A. t in [0, 1] delivered by Tween.
func _step_phase_a(t: float) -> void:
	var angle: float = t * HOVER_ANGLE_MAX
	_camera.global_position = Vector3(
		_phase_a_origin.x + sin(angle) * HOVER_ORBIT_AMP,
		_phase_a_origin.y,
		_phase_a_origin.z + cos(angle) * HOVER_ORBIT_AMP
	)
	_camera.look_at(Vector3(_path_mid.x, _ground_y, _path_mid.z), Vector3.UP)


## Phase B: 2.0 s spiral descent with smoothstep + FOV/fog animation.
func _run_phase_b() -> void:
	_phase_b_from = _camera.global_position
	_phase_b_to   = Vector3(_start_pos.x, _ground_y + EYE_HEIGHT, _start_pos.z)

	var tween: Tween = _camera.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_method(_step_phase_b, 0.0, 1.0, DESCENT_DURATION)
	tween.tween_callback(_run_phase_c)


## Per-frame callback for Phase B. t in [0, 1] delivered by Tween.
func _step_phase_b(t: float) -> void:
	# Smoothstep easing — symmetric S-curve, no stall at either end
	var e: float = t * t * (3.0 - 2.0 * t)

	# Spiral XZ offset: full radius at t=0, zero at t=1, 270-degree sweep
	var spiral_angle: float  = t * PI * SPIRAL_SWEEPS
	var spiral_radius: float = (1.0 - t) * SPIRAL_RADIUS

	_camera.global_position = Vector3(
		_phase_b_from.x + (_phase_b_to.x - _phase_b_from.x) * e + sin(spiral_angle) * spiral_radius,
		_phase_b_from.y + (_phase_b_to.y - _phase_b_from.y) * e,
		_phase_b_from.z + (_phase_b_to.z - _phase_b_from.z) * e + cos(spiral_angle) * spiral_radius
	)

	# FOV: 85 -> 65 eased with smoothstep
	_camera.fov = FOV_START - (FOV_START - FOV_END) * e

	# Fog: gradually restore from 30% -> 100% of original density
	_set_fog(_orig_fog_density * (FOG_AERIAL_SCALE + (1.0 - FOG_AERIAL_SCALE) * e))

	# Look target: blends from terrain overview (_path_mid) to walk look-ahead
	_camera.look_at(
		Vector3(
			_path_mid.x    + (_look_target.x - _path_mid.x)    * e,
			(_ground_y + 1.0) + (_look_target.y - _ground_y - 1.0) * e,
			_path_mid.z    + (_look_target.z - _path_mid.z)    * e
		),
		Vector3.UP
	)


## Phase C: hard snap, full fog restore, signal emission.
func _run_phase_c() -> void:
	# Snap to landing position — eliminates floating-point drift from tween end
	_camera.global_position = Vector3(_start_pos.x, _ground_y + EYE_HEIGHT, _start_pos.z)
	_camera.fov = FOV_END
	_camera.look_at(_look_target, Vector3.UP)

	# Unconditionally restore fog to its original value
	_set_fog(_orig_fog_density)

	_running = false
	descent_complete.emit()
	queue_free()


# --------------------------------------------------------------------------- #
# Utilities
# --------------------------------------------------------------------------- #

## Write fog density to WorldEnvironment if it exists.
func _set_fog(density: float) -> void:
	if is_instance_valid(_world_env) and _world_env.environment != null:
		_world_env.environment.fog_density = density


## Sample the path at fractional position [0, 1] using linear interpolation.
## Catmull-Rom (BrocAutowalk) is overkill for cinematic anchor points.
func _sample_path(frac: float) -> Vector3:
	var n: int = _path_points.size()
	if n == 0:
		return Vector3.ZERO
	if n == 1:
		return _path_points[0]

	var clamped: float  = clampf(frac, 0.0, 1.0)
	var fi: float       = clamped * float(n - 1)
	var ia: int         = int(fi)
	var ib: int         = mini(ia + 1, n - 1)
	var lt: float       = fi - float(ia)
	return _path_points[ia].lerp(_path_points[ib], lt)
