## BestioleCreature — Procedural white blob companion, Rain World-inspired.
## Pure _draw() rendering, no child nodes. High-resolution procedural ellipse with
## organic wobble deformation, spring squash/stretch, bunny-hop wandering,
## expressive 3x3 blue eyes, pixel particle effects, and trail afterimages.
## The creature roams freely across its parent's bounds.

class_name BestioleCreature
extends Control

signal assembly_complete
signal creature_clicked
signal state_changed(new_state: String)

# ═══════════════════════════════════════════════════════════════════════════════
# PALETTE
# ═══════════════════════════════════════════════════════════════════════════════

const COL_OUTLINE := Color(0.68, 0.71, 0.78)
const COL_BODY := Color(0.93, 0.94, 0.97)
const COL_HIGHLIGHT := Color(1.0, 1.0, 1.0)
const COL_SHADOW := Color(0.84, 0.86, 0.91)
const COL_INNER_GLOW := Color(0.95, 0.96, 1.0)
const COL_SCLERA := Color(1.0, 1.0, 1.0)
const COL_IRIS := Color(0.28, 0.52, 0.94)
const COL_IRIS_BRIGHT := Color(0.50, 0.70, 1.0)
const COL_PUPIL := Color(0.08, 0.12, 0.28)

# ═══════════════════════════════════════════════════════════════════════════════
# SHAPE — Higher radius = more pixels in the blob
# ═══════════════════════════════════════════════════════════════════════════════

const BASE_RADIUS := 14.0
const DEFAULT_SIZE := 200.0

# ═══════════════════════════════════════════════════════════════════════════════
# PHYSICS
# ═══════════════════════════════════════════════════════════════════════════════

const MOVE_ACCEL := 360.0
const MAX_SPEED := 125.0
const FRICTION := 0.87
const JUMP_VEL := -230.0
const GRAVITY := 520.0
const BOUNCE_FACTOR := 0.45
const HOP_CHANCE := 0.07
const HOP_STRENGTH := 0.38

# Squash/stretch spring
const SS_K := 24.0
const SS_DAMP := 0.75

# ═══════════════════════════════════════════════════════════════════════════════
# WOBBLE — Organic sin-based edge deformation
# ═══════════════════════════════════════════════════════════════════════════════

const WOBBLE_A1 := 0.07
const WOBBLE_F1 := 3.0
const WOBBLE_S1 := 4.5
const WOBBLE_A2 := 0.04
const WOBBLE_F2 := 5.0
const WOBBLE_S2 := -3.2
const WOBBLE_A3 := 0.025
const WOBBLE_F3 := 8.0
const WOBBLE_S3 := 7.5
const WOBBLE_VEL_AMP := 0.06

# ═══════════════════════════════════════════════════════════════════════════════
# EYES — 3x3 sclera, 2x1 iris, pupil highlight
# ═══════════════════════════════════════════════════════════════════════════════

const EYE_L := Vector2(-6, -4)
const EYE_R := Vector2(2, -4)
const EYE_W := 3
const EYE_H := 3
const IRIS_W := 2
const BLINK_MIN := 1.8
const BLINK_MAX := 4.5
const BLINK_DUR := 0.09
const DOUBLE_BLINK_CHANCE := 0.25

# ═══════════════════════════════════════════════════════════════════════════════
# STATE TIMINGS
# ═══════════════════════════════════════════════════════════════════════════════

const T_IDLE_MIN := 1.0
const T_IDLE_MAX := 3.2
const T_CURIOUS := 2.5
const T_SLEEPY := 6.5
const T_LAND := 0.18
const T_STARTLE := 0.32
const ARRIVE_DIST := 15.0
const JUMP_CHANCE := 0.15
const SLEEPY_CHANCE := 0.06
const FIDGET_CHANCE := 8.0

enum CreatureState { IDLE, WANDER, CURIOUS, JUMP, LAND, SLEEPY, STARTLED }

# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES
# ═══════════════════════════════════════════════════════════════════════════════

var _px: float = 6.0
var _assembled: bool = false

# Position & velocity
var _pos: Vector2 = Vector2.ZERO
var _vel: Vector2 = Vector2.ZERO
var _grounded: bool = true

# Squash/stretch
var _ss: Vector2 = Vector2(1.0, 1.0)
var _ss_vel: Vector2 = Vector2.ZERO

# Tilt
var _tilt: float = 0.0
var _tilt_target: float = 0.0

# Eyes
var _look: Vector2 = Vector2.ZERO
var _look_target: Vector2 = Vector2.ZERO
var _blink_timer: float = 3.0
var _blinking: bool = false
var _blink_t: float = 0.0
var _eye_open: float = 1.0
var _double_blink_pending: bool = false
var _squint: float = 0.0

# State machine
var _state: CreatureState = CreatureState.IDLE
var _timer: float = 0.0
var _wander_target: Vector2 = Vector2.ZERO
var _idle_look_t: float = 0.0
var _facing: float = 1.0

# Animation clocks
var _breath_t: float = 0.0
var _wobble_t: float = 0.0

# Pop-in assembly
var _pop: float = 0.0
var _pop_v: float = 0.0
var _popping: bool = false

# Trail afterimages
var _trail: Array[Vector2] = []
const TRAIL_LEN := 8
const TRAIL_INTERVAL := 0.025
var _trail_timer: float = 0.0

# Pixel particles
var _particles: Array = []
const MAX_PARTICLES := 40

# Gameplay
var _bond_level: int = 0
var _awen: int = 0


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(target_size: float = DEFAULT_SIZE) -> void:
	_px = target_size / (BASE_RADIUS * 2.0 + 2.0)
	mouse_filter = Control.MOUSE_FILTER_PASS


func assemble(instant: bool = false) -> void:
	_assembled = false
	_state = CreatureState.IDLE
	_timer = randf_range(T_IDLE_MIN, T_IDLE_MAX)
	_blink_timer = randf_range(BLINK_MIN, BLINK_MAX)
	_breath_t = 0.0
	_wobble_t = randf() * TAU
	_vel = Vector2.ZERO
	_ss = Vector2(1.0, 1.0)
	_ss_vel = Vector2.ZERO
	_tilt = 0.0
	_look = Vector2.ZERO
	_eye_open = 1.0
	_squint = 0.0
	_double_blink_pending = false
	_trail.clear()
	_particles.clear()
	_facing = 1.0
	_grounded = true

	var sz := _get_bounds()
	_pos = Vector2(sz.x * 0.5, sz.y * 0.65)

	if instant:
		_pop = 1.0
		_assembled = true
		assembly_complete.emit()
		return

	_pop = 0.0
	_pop_v = 0.0
	_popping = true


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if _popping:
		_update_pop(delta)
		queue_redraw()
		return
	if not _assembled:
		return

	_breath_t += delta
	_wobble_t += delta
	_update_state(delta)
	_update_physics(delta)
	_update_ss(delta)
	_update_tilt(delta)
	_update_eyes(delta)
	_update_trail(delta)
	_update_particles(delta)
	queue_redraw()


func _update_pop(delta: float) -> void:
	var f := (1.0 - _pop) * 35.0
	_pop_v = (_pop_v + f * delta) * 0.79
	_pop += _pop_v * delta
	if _pop > 0.97 and absf(_pop_v) < 0.3:
		_pop = 1.0
		_popping = false
		_assembled = true
		var burst_y := _pos + Vector2(0.0, BASE_RADIUS * _px * 0.4)
		_spawn_particles(burst_y, 8, 70.0, COL_HIGHLIGHT)
		assembly_complete.emit()


# ═══════════════════════════════════════════════════════════════════════════════
# STATE MACHINE
# ═══════════════════════════════════════════════════════════════════════════════

func _update_state(delta: float) -> void:
	_timer -= delta
	match _state:
		CreatureState.IDLE:
			_update_idle(delta)
		CreatureState.WANDER:
			_update_wander(delta)
		CreatureState.CURIOUS:
			_update_curious(delta)
		CreatureState.JUMP:
			_update_jump()
		CreatureState.LAND:
			if _timer <= 0.0:
				_enter_state(CreatureState.IDLE)
		CreatureState.SLEEPY:
			_update_sleepy(delta)
		CreatureState.STARTLED:
			if _timer <= 0.0:
				_enter_state(CreatureState.IDLE)


func _enter_state(new_state: CreatureState) -> void:
	_state = new_state
	match new_state:
		CreatureState.IDLE:
			_timer = randf_range(T_IDLE_MIN, T_IDLE_MAX)
			_idle_look_t = randf_range(0.4, 1.2)
			_ss_vel += Vector2(0.0, -2.0)
			_squint = 0.0
		CreatureState.WANDER:
			_pick_target()
			_squint = 0.0
		CreatureState.CURIOUS:
			_timer = T_CURIOUS
			_squint = 0.3
		CreatureState.JUMP:
			_vel.y = JUMP_VEL
			_grounded = false
			_ss_vel = Vector2(4.5, -5.5)
			var dust_y := _pos + Vector2(0.0, BASE_RADIUS * _px * 0.4)
			_spawn_particles(dust_y, 5, 50.0, COL_SHADOW)
		CreatureState.LAND:
			_timer = T_LAND
			_vel.x *= 0.45
			_ss_vel = Vector2(-5.0, 7.0)
			var dust_y := _pos + Vector2(0.0, BASE_RADIUS * _px * 0.5)
			_spawn_particles(dust_y, 10, 80.0, COL_OUTLINE)
		CreatureState.SLEEPY:
			_timer = T_SLEEPY
		CreatureState.STARTLED:
			_timer = T_STARTLE
			_vel.y = JUMP_VEL * 0.7
			_vel.x += (randf() - 0.5) * 160.0
			_grounded = false
			_ss_vel = Vector2(4.0, -5.0)
			_spawn_particles(_pos, 12, 90.0, COL_IRIS_BRIGHT)
	state_changed.emit(_get_state_name())


func _update_idle(delta: float) -> void:
	# Random look direction
	_idle_look_t -= delta
	if _idle_look_t <= 0.0:
		_look_target = Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5))
		_idle_look_t = randf_range(0.5, 1.5)

	# Fidget — micro weight-shifts and wiggles
	if randf() < FIDGET_CHANCE * delta:
		_ss_vel += Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6))
		_vel.x += randf_range(-18.0, 18.0)

	# Micro-hop in place (restless energy)
	if _grounded and randf() < 0.01:
		_vel.y = JUMP_VEL * 0.12
		_grounded = false
		_ss_vel += Vector2(0.6, -0.9)

	# Mouse proximity triggers curiosity
	var mouse := get_local_mouse_position()
	if _pos.distance_to(mouse) < _px * BASE_RADIUS * 3.5:
		_enter_state(CreatureState.CURIOUS)
		return

	if _timer <= 0.0:
		var roll := randf()
		if roll < JUMP_CHANCE:
			_enter_state(CreatureState.JUMP)
		elif roll < JUMP_CHANCE + SLEEPY_CHANCE:
			_enter_state(CreatureState.SLEEPY)
		else:
			_enter_state(CreatureState.WANDER)


func _update_wander(delta: float) -> void:
	var diff := _wander_target - _pos
	var dist := diff.length()

	if dist < ARRIVE_DIST:
		_enter_state(CreatureState.IDLE)
		return

	var dir := diff.normalized()
	_facing = 1.0 if dir.x >= 0.0 else -1.0
	_look_target = dir

	# Bunny-hop movement
	if _grounded:
		_vel.x += dir.x * MOVE_ACCEL * delta
		if randf() < HOP_CHANCE:
			_vel.y = JUMP_VEL * HOP_STRENGTH
			_grounded = false
			_ss_vel += Vector2(1.8, -2.5)

	# Mouse proximity
	var mouse := get_local_mouse_position()
	if _pos.distance_to(mouse) < _px * BASE_RADIUS * 3.0:
		_enter_state(CreatureState.CURIOUS)


func _update_curious(delta: float) -> void:
	var mouse := get_local_mouse_position()
	var to_mouse := mouse - _pos
	_look_target = to_mouse.normalized()
	_tilt_target = clampf(to_mouse.x * 0.001, -0.2, 0.2)

	if to_mouse.length() > _px * BASE_RADIUS * 6.0:
		_enter_state(CreatureState.IDLE)
		return

	# Drift toward mouse
	if _grounded:
		_vel.x += to_mouse.normalized().x * MOVE_ACCEL * 0.2 * delta
		# Excited micro-hop
		if randf() < 0.015:
			_vel.y = JUMP_VEL * 0.14
			_grounded = false
			_ss_vel += Vector2(0.5, -0.7)

	if _timer <= 0.0:
		_enter_state(CreatureState.WANDER)


func _update_jump() -> void:
	if _grounded:
		_enter_state(CreatureState.LAND)


func _update_sleepy(delta: float) -> void:
	_eye_open = lerpf(_eye_open, 0.18, delta * 2.5)
	_look_target = Vector2(0.0, 0.3)

	# Gentle drowsy sway
	_vel.x += sin(_breath_t * 1.5) * 6.0 * delta

	# Occasional micro-nod
	if randf() < 0.005:
		_ss_vel.y += 1.5

	var mouse := get_local_mouse_position()
	if _pos.distance_to(mouse) < _px * BASE_RADIUS * 2.5:
		_enter_state(CreatureState.CURIOUS)
		return

	if _timer <= 0.0:
		_enter_state(CreatureState.IDLE)


# ═══════════════════════════════════════════════════════════════════════════════
# PHYSICS
# ═══════════════════════════════════════════════════════════════════════════════

func _update_physics(delta: float) -> void:
	if not _grounded:
		_vel.y += GRAVITY * delta

	_vel.x *= FRICTION
	if _grounded:
		_vel.y *= 0.9

	if _vel.length() > MAX_SPEED * 2.5:
		_vel = _vel.normalized() * MAX_SPEED * 2.5

	_pos += _vel * delta

	var margin := _px * BASE_RADIUS
	var sz := _get_bounds()

	# Ground
	var ground := sz.y - margin - 20.0
	if _pos.y >= ground:
		_pos.y = ground
		if _vel.y > 60.0:
			_ss_vel.y += _vel.y * 0.02
			_ss_vel.x -= _vel.y * 0.012
			var count := int(clampf(_vel.y * 0.04, 2.0, 10.0))
			var dust_pos := _pos + Vector2(0.0, margin * 0.4)
			_spawn_particles(dust_pos, count, 55.0, COL_SHADOW)
		_vel.y *= -BOUNCE_FACTOR
		if absf(_vel.y) < 35.0:
			_vel.y = 0.0
			_grounded = true
		if not _grounded and _state == CreatureState.JUMP:
			_grounded = true

	# Ceiling
	if _pos.y < margin:
		_pos.y = margin
		_vel.y *= -BOUNCE_FACTOR

	# Walls
	if _pos.x < margin:
		_pos.x = margin
		_vel.x *= -BOUNCE_FACTOR
		_facing = 1.0
		if absf(_vel.x) > 25.0:
			_spawn_particles(_pos - Vector2(margin * 0.3, 0.0), 3, 35.0, COL_OUTLINE)
	elif _pos.x > sz.x - margin:
		_pos.x = sz.x - margin
		_vel.x *= -BOUNCE_FACTOR
		_facing = -1.0
		if absf(_vel.x) > 25.0:
			_spawn_particles(_pos + Vector2(margin * 0.3, 0.0), 3, 35.0, COL_OUTLINE)


func _update_ss(delta: float) -> void:
	var target := Vector2(1.0, 1.0)

	# Speed-based deformation (stretch in dominant direction)
	var spd := _vel.length()
	if spd > 25.0:
		var sf := clampf(spd / MAX_SPEED, 0.0, 0.6)
		if absf(_vel.x) > absf(_vel.y):
			target.x += sf * 0.18
			target.y -= sf * 0.12
		else:
			target.y += sf * 0.18
			target.x -= sf * 0.12

	var force := (target - _ss) * SS_K
	_ss_vel = (_ss_vel + force * delta) * SS_DAMP
	_ss += _ss_vel * delta

	# Volume preservation: sx * sy ~ 1
	var vol := _ss.x * _ss.y
	if vol > 0.01:
		var correction := 1.0 / sqrt(vol)
		_ss *= correction


func _update_tilt(delta: float) -> void:
	if _state != CreatureState.CURIOUS:
		_tilt_target = _vel.x * -0.001
	_tilt = lerpf(_tilt, _tilt_target, delta * 7.0)


# ═══════════════════════════════════════════════════════════════════════════════
# EYES
# ═══════════════════════════════════════════════════════════════════════════════

func _update_eyes(delta: float) -> void:
	# Blink timer
	_blink_timer -= delta
	if _blink_timer <= 0.0 and not _blinking:
		_blinking = true
		_blink_t = BLINK_DUR
		if _double_blink_pending:
			_double_blink_pending = false
			_blink_timer = randf_range(BLINK_MIN, BLINK_MAX)
		elif randf() < DOUBLE_BLINK_CHANCE:
			_double_blink_pending = true
			_blink_timer = 0.16
		else:
			_blink_timer = randf_range(BLINK_MIN, BLINK_MAX)

	if _blinking:
		_blink_t -= delta
		if _blink_t <= 0.0:
			_blinking = false

	# Eye openness target
	var target_open := 0.0 if _blinking else 1.0
	if _state == CreatureState.SLEEPY:
		target_open = 0.18
	elif _state == CreatureState.STARTLED:
		target_open = 1.0
	_eye_open = lerpf(_eye_open, target_open, delta * 20.0)

	# Squint during curiosity
	var squint_target := 0.3 if _state == CreatureState.CURIOUS else 0.0
	_squint = lerpf(_squint, squint_target, delta * 5.0)

	_look = _look.lerp(_look_target, delta * 10.0)


# ═══════════════════════════════════════════════════════════════════════════════
# TRAIL
# ═══════════════════════════════════════════════════════════════════════════════

func _update_trail(delta: float) -> void:
	_trail_timer -= delta
	if _trail_timer <= 0.0 and _vel.length() > 25.0:
		_trail.append(Vector2(_pos.x, _pos.y))
		if _trail.size() > TRAIL_LEN:
			_trail.remove_at(0)
		_trail_timer = TRAIL_INTERVAL
	elif _vel.length() <= 25.0 and _trail.size() > 0:
		_trail.remove_at(0)


# ═══════════════════════════════════════════════════════════════════════════════
# PARTICLES
# ═══════════════════════════════════════════════════════════════════════════════

func _spawn_particles(origin: Vector2, count: int, spread: float, col_base: Color) -> void:
	var room := MAX_PARTICLES - _particles.size()
	var n := mini(count, room)
	for i in range(n):
		_particles.append({
			"px": Vector2(origin.x, origin.y),
			"vl": Vector2(randf_range(-spread, spread), randf_range(-spread * 1.8, -spread * 0.15)),
			"li": randf_range(0.35, 0.85),
			"cl": Color(col_base.r, col_base.g, col_base.b, col_base.a),
		})


func _update_particles(delta: float) -> void:
	var i := _particles.size() - 1
	while i >= 0:
		var p: Dictionary = _particles[i]
		var v: Vector2 = p["vl"]
		p["vl"] = Vector2(v.x * 0.97, v.y + 240.0 * delta)
		var pos: Vector2 = p["px"]
		p["px"] = pos + p["vl"] * delta
		p["li"] = p["li"] - delta
		if p["li"] <= 0.0:
			_particles.remove_at(i)
		i -= 1


# ═══════════════════════════════════════════════════════════════════════════════
# RENDER
# ═══════════════════════════════════════════════════════════════════════════════

func _draw() -> void:
	if not _assembled and not _popping:
		return

	var px := _px
	var sf := _pop if _popping else 1.0

	# Breathing oscillation
	var breath := sin(_breath_t * 2.8) * 0.04
	var sx := _ss.x * sf * (1.0 - breath * 0.4)
	var sy := _ss.y * sf * (1.0 + breath)

	var rx := BASE_RADIUS * sx
	var ry := BASE_RADIUS * sy

	# Trail afterimages (drawn first, behind main blob)
	for i in range(_trail.size()):
		var tp: Vector2 = _trail[i]
		var alpha := float(i + 1) / float(_trail.size() + 1) * 0.2
		var tr := BASE_RADIUS * sf * 0.78
		_draw_blob_at(tp, tr, tr, 0.0, px, alpha, false)

	# Particles (behind blob)
	_draw_particles(px)

	# Main blob with organic wobble
	_draw_blob_at(_pos, rx, ry, _tilt, px, 1.0, true)

	# Eyes
	if _eye_open > 0.04 and sf > 0.3:
		_draw_eyes(px)


func _draw_blob_at(center: Vector2, rx: float, ry: float, tilt: float, px: float, alpha: float, with_wobble: bool) -> void:
	var scan := int(ceilf(maxf(rx, ry))) + 2
	var cx := floorf(center.x / px) * px
	var cy := floorf(center.y / px) * px

	for gy in range(-scan, scan + 1):
		for gx in range(-scan, scan + 1):
			var rel := Vector2(float(gx), float(gy))
			if absf(tilt) > 0.001:
				rel = rel.rotated(-tilt)

			var nx := rel.x / rx if rx > 0.1 else 99.0
			var ny := rel.y / ry if ry > 0.1 else 99.0
			var d := nx * nx + ny * ny

			# Organic wobble — multiple sin waves distort the boundary
			if with_wobble and d > 0.45:
				var angle := atan2(ny, nx)
				var w := sin(angle * WOBBLE_F1 + _wobble_t * WOBBLE_S1) * WOBBLE_A1
				w += sin(angle * WOBBLE_F2 + _wobble_t * WOBBLE_S2) * WOBBLE_A2
				w += sin(angle * WOBBLE_F3 + _wobble_t * WOBBLE_S3) * WOBBLE_A3
				# Velocity-driven extra wobble
				var spd_r := clampf(_vel.length() / MAX_SPEED, 0.0, 1.0)
				w += sin(angle * 2.0 + _wobble_t * 9.0) * WOBBLE_VEL_AMP * spd_r
				d += w

			if d > 1.0:
				continue

			# Shading with inner glow zone
			var col: Color
			if d > 0.72:
				col = COL_OUTLINE
			elif d > 0.58 and ny > 0.2:
				col = COL_SHADOW
			elif ny < -0.35 and d < 0.36:
				col = COL_HIGHLIGHT
			elif d < 0.15:
				col = COL_INNER_GLOW
			elif ny > 0.25:
				col = COL_SHADOW
			else:
				col = COL_BODY

			if alpha < 1.0:
				col = Color(col.r, col.g, col.b, col.a * alpha)

			draw_rect(Rect2(cx + gx * px, cy + gy * px, px, px), col)


func _draw_eyes(px: float) -> void:
	var cx := floorf(_pos.x / px) * px
	var cy := floorf(_pos.y / px) * px

	var el_x := cx + floorf(EYE_L.x * _ss.x) * px
	var el_y := cy + floorf(EYE_L.y * _ss.y) * px
	var er_x := cx + floorf(EYE_R.x * _ss.x) * px
	var er_y := cy + floorf(EYE_R.y * _ss.y) * px

	_draw_single_eye(el_x, el_y, px)
	_draw_single_eye(er_x, er_y, px)


func _draw_single_eye(ex: float, ey: float, px: float) -> void:
	var a := _eye_open
	if a < 0.04:
		# Closed — thin slit line
		var sc := Color(COL_OUTLINE.r, COL_OUTLINE.g, COL_OUTLINE.b, 0.5)
		draw_rect(Rect2(ex, ey + px, px * float(EYE_W), px), sc)
		return

	# How many rows visible (close from top)
	var raw_rows := float(EYE_H) * clampf(a - _squint * 0.3, 0.15, 1.0)
	var rows_visible := clampi(int(roundf(raw_rows)), 1, EYE_H)
	var y_off := EYE_H - rows_visible

	var sc := Color(COL_SCLERA.r, COL_SCLERA.g, COL_SCLERA.b, minf(a * 1.5, 1.0))

	# Sclera (3xN visible rows)
	for row in range(rows_visible):
		for ci in range(EYE_W):
			draw_rect(Rect2(ex + ci * px, ey + (y_off + row) * px, px, px), sc)

	# Iris (2x1 wide, shifts with look direction)
	if a > 0.2:
		var ix: int = 0
		if _look.x > 0.25:
			ix = 1
		elif _look.x < -0.25:
			ix = 0
		else:
			ix = 1 if _facing > 0.0 else 0

		var iy := y_off + int(float(rows_visible) * 0.5)
		if rows_visible >= 2:
			if _look.y < -0.3:
				iy = y_off
			elif _look.y > 0.3:
				iy = y_off + rows_visible - 1

		var ic := Color(COL_IRIS.r, COL_IRIS.g, COL_IRIS.b, minf(a * 1.5, 1.0))
		draw_rect(Rect2(ex + ix * px, ey + iy * px, px * float(IRIS_W), px), ic)

		# Pupil highlight (1px bright spot, top-left of iris)
		if a > 0.5:
			var hc := Color(1.0, 1.0, 1.0, a * 0.7)
			draw_rect(Rect2(ex + ix * px, ey + iy * px, px, px), hc)


func _draw_particles(px: float) -> void:
	for p in _particles:
		var life: float = p["li"]
		var a := clampf(life * 2.5, 0.0, 1.0)
		var col: Color = p["cl"]
		col = Color(col.r, col.g, col.b, a)
		var pos: Vector2 = p["px"]
		var ppx := floorf(pos.x / px) * px
		var ppy := floorf(pos.y / px) * px
		draw_rect(Rect2(ppx, ppy, px, px), col)


# ═══════════════════════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════════════════════

func _gui_input(event: InputEvent) -> void:
	if not _assembled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var dist := _pos.distance_to(event.position)
		if dist < BASE_RADIUS * _px * 1.4:
			creature_clicked.emit()
			if _state != CreatureState.STARTLED:
				_enter_state(CreatureState.STARTLED)


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func trigger_reaction(event_name: String, _data: Dictionary = {}) -> void:
	if not _assembled:
		return
	match event_name:
		"click", "pet":
			if _state != CreatureState.STARTLED:
				_enter_state(CreatureState.STARTLED)
		"mouse_enter":
			if _state != CreatureState.STARTLED:
				_enter_state(CreatureState.CURIOUS)
		"mouse_exit":
			if _state == CreatureState.CURIOUS:
				_enter_state(CreatureState.IDLE)
		"sleep":
			_enter_state(CreatureState.SLEEPY)
		"wake":
			_enter_state(CreatureState.IDLE)
		"jump":
			_enter_state(CreatureState.JUMP)


func set_bond_level(level: int) -> void:
	_bond_level = clampi(level, 0, 10)


func set_awen(awen_val: int) -> void:
	_awen = clampi(awen_val, 0, 7)


func get_state() -> CreatureState:
	return _state


func get_state_name() -> String:
	return _get_state_name()


func is_assembled() -> bool:
	return _assembled


func look_at_position(target_pos: Vector2) -> void:
	## Make the creature look toward a world position and become curious.
	if not _assembled:
		return
	var dir := (target_pos - _pos).normalized()
	_look_target = dir
	if _state == CreatureState.IDLE or _state == CreatureState.SLEEPY:
		_enter_state(CreatureState.CURIOUS)


func set_aura_tint(tint: Color) -> void:
	## Apply a subtle color tint to the creature (for aspect display).
	## Pass Color.WHITE for neutral (no tint).
	modulate = tint


func get_position_center() -> Vector2:
	## Return the creature's current position in local coordinates.
	return _pos


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _pick_target() -> void:
	var margin := _px * BASE_RADIUS + 30.0
	var sz := _get_bounds()
	_wander_target = Vector2(
		randf_range(margin, sz.x - margin),
		randf_range(sz.y * 0.35, sz.y - margin - 20.0)
	)


func _get_bounds() -> Vector2:
	var sz := size
	if sz.x < 10.0 or sz.y < 10.0:
		return Vector2(800.0, 600.0)
	return sz


func _get_state_name() -> String:
	match _state:
		CreatureState.IDLE: return "idle"
		CreatureState.WANDER: return "wander"
		CreatureState.CURIOUS: return "curious"
		CreatureState.JUMP: return "jump"
		CreatureState.LAND: return "land"
		CreatureState.SLEEPY: return "sleepy"
		CreatureState.STARTLED: return "startled"
	return "unknown"
