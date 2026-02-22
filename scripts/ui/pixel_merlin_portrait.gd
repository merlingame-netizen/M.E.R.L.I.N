## PixelMerlinPortrait — PNG-based pixel portrait with rain reconstitution
## Loads actual sprite PNG, auto-detects art pixel grid, animates assembly.
## Drop-in replacement: same class_name, signals, and public API.

class_name PixelMerlinPortrait
extends Control

signal assembly_complete
signal disassembly_complete

# ═══════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════

const DEFAULT_SPRITE := "res://Assets/Sprite/M.E.R.L.I.N.png"
const DEFAULT_TARGET_SIZE := 192.0
const MAX_GRID := 64
const ALPHA_THRESHOLD := 0.1
const COLOR_TOLERANCE := 0.05

# Assembly cascade timing
const BATCH_SIZE := 6
const BATCH_DELAY := 0.02
const PIXEL_DURATION := 0.25
const FADE_IN_FRACTION := 0.15
const SCATTER_X := 30.0
const SCATTER_Y_MIN := 60.0
const SCATTER_Y_MAX := 160.0

# Disassembly timing
const DIS_MOVE_DURATION := 0.3
const DIS_FADE_DURATION := 0.25
const DIS_SETTLE_TIME := 0.4

# Idle animation
const BREATHE_SPEED := 1.4
const BREATHE_AMP := 1.5
const BLINK_DURATION := 0.12
const BLINK_MIN := 2.5
const BLINK_MAX := 5.0
const GLOW_SPEED := 3.2
const GLOW_BASE := 0.7
const GLOW_RANGE := 0.3

# Eye detection thresholds (bright blue pixels)
const EYE_HUE_LO := 0.5
const EYE_HUE_HI := 0.7
const EYE_SAT_MIN := 0.4
const EYE_VAL_MIN := 0.6

# ═══════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════

enum Phase { IDLE, ASSEMBLING, ASSEMBLED, DISASSEMBLING }

var pixel_size: float = 14.0
var assembled: bool = false

var _phase: int = Phase.IDLE
var _pixel_count: int = 0
var _grid_w: int = 0
var _grid_h: int = 0

# Permanent pixel data (never modified after extraction)
var _colors: PackedColorArray
var _grid_x: PackedFloat32Array
var _grid_y: PackedFloat32Array
var _is_eye: Array[bool] = []
var _is_glow: Array[bool] = []

# Animation working arrays
var _cur_x: PackedFloat32Array
var _cur_y: PackedFloat32Array
var _cur_a: PackedFloat32Array
var _from_x: PackedFloat32Array
var _from_y: PackedFloat32Array
var _to_x: PackedFloat32Array
var _to_y: PackedFloat32Array
var _delay: PackedFloat32Array

# Timing
var _elapsed: float = 0.0

# Idle state
var _idle_active: bool = false
var _breathe_t: float = 0.0
var _glow_t: float = 0.0
var _blink_timer: float = 0.0
var _blink_interval: float = 3.5
var _is_blinking: bool = false
var _eye_alpha: float = 1.0

# Mood
var _mood_tint: Color = Color.WHITE


# ═══════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════

func setup(target_size: float = DEFAULT_TARGET_SIZE, _season: String = "") -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var image := _load_sprite_image()
	if image == null:
		push_warning("PixelMerlinPortrait: sprite not found at " + DEFAULT_SPRITE)
		return

	var block_size := _detect_block_size(image)
	_grid_w = int(float(image.get_width()) / float(block_size))
	_grid_h = int(float(image.get_height()) / float(block_size))

	# Cap grid to MAX_GRID
	if _grid_w > MAX_GRID or _grid_h > MAX_GRID:
		var img_max := maxi(image.get_width(), image.get_height())
		block_size = ceili(float(img_max) / float(MAX_GRID))
		_grid_w = int(float(image.get_width()) / float(block_size))
		_grid_h = int(float(image.get_height()) / float(block_size))

	pixel_size = target_size / float(maxi(_grid_w, _grid_h))

	custom_minimum_size = Vector2(_grid_w * pixel_size, _grid_h * pixel_size)
	size = custom_minimum_size

	_extract_pixels(image, block_size)


func _load_sprite_image() -> Image:
	if not ResourceLoader.exists(DEFAULT_SPRITE):
		return null
	var tex: Texture2D = load(DEFAULT_SPRITE)
	if tex == null:
		return null
	return tex.get_image()


# ═══════════════════════════════════════════════════════════════════
# AUTO-DETECTION — Art pixel block size via GCD of uniform runs
# ═══════════════════════════════════════════════════════════════════

func _detect_block_size(image: Image) -> int:
	var w := image.get_width()
	var h := image.get_height()
	if w == 0 or h == 0:
		return 1

	var runs: Array[int] = []
	var step_h := maxi(1, int(float(h) / 20.0))
	var step_w := maxi(1, int(float(w) / 20.0))

	# Horizontal scan on sampled rows
	for row in range(0, h, step_h):
		var prev := Color.TRANSPARENT
		var run := 0
		for x in range(w):
			var c := image.get_pixel(x, row)
			if c.a < ALPHA_THRESHOLD:
				if run > 1:
					runs.append(run)
				run = 0
				prev = Color.TRANSPARENT
				continue
			if _colors_match(c, prev):
				run += 1
			else:
				if run > 1:
					runs.append(run)
				prev = c
				run = 1
		if run > 1:
			runs.append(run)

	# Vertical scan on sampled columns
	for col in range(0, w, step_w):
		var prev := Color.TRANSPARENT
		var run := 0
		for y in range(h):
			var c := image.get_pixel(col, y)
			if c.a < ALPHA_THRESHOLD:
				if run > 1:
					runs.append(run)
				run = 0
				prev = Color.TRANSPARENT
				continue
			if _colors_match(c, prev):
				run += 1
			else:
				if run > 1:
					runs.append(run)
				prev = c
				run = 1
		if run > 1:
			runs.append(run)

	if runs.is_empty():
		return maxi(1, ceili(float(w) / float(MAX_GRID)))

	var result := runs[0]
	for i in range(1, runs.size()):
		result = _gcd(result, runs[i])
		if result <= 1:
			break

	result = maxi(result, 1)
	if int(float(w) / float(result)) > MAX_GRID:
		result = ceili(float(w) / float(MAX_GRID))

	return result


static func _colors_match(a: Color, b: Color) -> bool:
	if b.a < 0.01:
		return false
	return absf(a.r - b.r) < COLOR_TOLERANCE \
		and absf(a.g - b.g) < COLOR_TOLERANCE \
		and absf(a.b - b.b) < COLOR_TOLERANCE \
		and absf(a.a - b.a) < COLOR_TOLERANCE


static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a


# ═══════════════════════════════════════════════════════════════════
# PIXEL EXTRACTION — Sample grid cells from image
# ═══════════════════════════════════════════════════════════════════

func _extract_pixels(image: Image, block_size: int) -> void:
	var tc := PackedColorArray()
	var tgx := PackedFloat32Array()
	var tgy := PackedFloat32Array()
	var t_eye: Array[bool] = []
	var t_glow: Array[bool] = []

	var half := int(float(block_size) / 2.0)
	var max_x := image.get_width() - 1
	var max_y := image.get_height() - 1

	for row in range(_grid_h):
		for col in range(_grid_w):
			var sx := mini(col * block_size + half, max_x)
			var sy := mini(row * block_size + half, max_y)
			var c := image.get_pixel(sx, sy)
			if c.a < ALPHA_THRESHOLD:
				continue

			tc.append(c)
			tgx.append(col * pixel_size)
			tgy.append(row * pixel_size)

			var is_eye := c.h >= EYE_HUE_LO and c.h <= EYE_HUE_HI \
				and c.s >= EYE_SAT_MIN and c.v >= EYE_VAL_MIN
			t_eye.append(is_eye)
			t_glow.append(c.v > 0.8 and c.s > 0.3)

	_colors = tc
	_grid_x = tgx
	_grid_y = tgy
	_is_eye = t_eye
	_is_glow = t_glow
	_pixel_count = _colors.size()

	# Pre-allocate working arrays
	_cur_x = PackedFloat32Array()
	_cur_y = PackedFloat32Array()
	_cur_a = PackedFloat32Array()
	_from_x = PackedFloat32Array()
	_from_y = PackedFloat32Array()
	_to_x = PackedFloat32Array()
	_to_y = PackedFloat32Array()
	_delay = PackedFloat32Array()
	_cur_x.resize(_pixel_count)
	_cur_y.resize(_pixel_count)
	_cur_a.resize(_pixel_count)
	_from_x.resize(_pixel_count)
	_from_y.resize(_pixel_count)
	_to_x.resize(_pixel_count)
	_to_y.resize(_pixel_count)
	_delay.resize(_pixel_count)


# ═══════════════════════════════════════════════════════════════════
# ASSEMBLY — Rain reconstitution cascade
# ═══════════════════════════════════════════════════════════════════

func assemble(instant: bool = false) -> void:
	assembled = false
	_idle_active = false

	if _pixel_count == 0:
		assembled = true
		_idle_active = true
		assembly_complete.emit()
		return

	if instant:
		for i in range(_pixel_count):
			_cur_x[i] = _grid_x[i]
			_cur_y[i] = _grid_y[i]
			_cur_a[i] = 1.0
		assembled = true
		_idle_active = true
		_phase = Phase.ASSEMBLED
		queue_redraw()
		assembly_complete.emit()
		return

	# Shuffled order for staggered arrival
	var order: Array[int] = []
	order.resize(_pixel_count)
	for i in range(_pixel_count):
		order[i] = i
	order.shuffle()

	for batch_idx in range(order.size()):
		var i: int = order[batch_idx]
		_delay[i] = float(int(float(batch_idx) / float(BATCH_SIZE))) * BATCH_DELAY
		_from_x[i] = _grid_x[i] + randf_range(-SCATTER_X, SCATTER_X)
		_from_y[i] = _grid_y[i] - randf_range(SCATTER_Y_MIN, SCATTER_Y_MAX)
		_to_x[i] = _grid_x[i]
		_to_y[i] = _grid_y[i]
		_cur_x[i] = _from_x[i]
		_cur_y[i] = _from_y[i]
		_cur_a[i] = 0.0

	_elapsed = 0.0
	_phase = Phase.ASSEMBLING
	queue_redraw()

	await assembly_complete


func disassemble() -> void:
	if _pixel_count == 0:
		disassembly_complete.emit()
		return

	_idle_active = false

	for i in range(_pixel_count):
		_from_x[i] = _grid_x[i]
		_from_y[i] = _grid_y[i]
		_to_x[i] = _grid_x[i] + randf_range(-40.0, 40.0)
		_to_y[i] = _grid_y[i] + randf_range(-60.0, -15.0)
		_delay[i] = 0.0
		_cur_a[i] = 1.0

	_elapsed = 0.0
	_phase = Phase.DISASSEMBLING
	queue_redraw()

	await disassembly_complete


# ═══════════════════════════════════════════════════════════════════
# EASING — Manual implementations for _draw-based animation
# ═══════════════════════════════════════════════════════════════════

static func _ease_back_out(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)


static func _ease_quad_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


# ═══════════════════════════════════════════════════════════════════
# PROCESS — Animate pixels each frame
# ═══════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	match _phase:
		Phase.ASSEMBLING:
			_tick_assembly(delta)
		Phase.DISASSEMBLING:
			_tick_disassembly(delta)
		Phase.ASSEMBLED:
			_tick_idle(delta)


func _tick_assembly(delta: float) -> void:
	_elapsed += delta
	var all_done := true

	for i in range(_pixel_count):
		var t := (_elapsed - _delay[i]) / PIXEL_DURATION
		if t < 0.0:
			all_done = false
			continue
		if t >= 1.0:
			_cur_x[i] = _to_x[i]
			_cur_y[i] = _to_y[i]
			_cur_a[i] = 1.0
			continue
		all_done = false
		var e := _ease_back_out(t)
		_cur_x[i] = lerpf(_from_x[i], _to_x[i], e)
		_cur_y[i] = lerpf(_from_y[i], _to_y[i], e)
		_cur_a[i] = minf(t / FADE_IN_FRACTION, 1.0)

	queue_redraw()

	if all_done:
		assembled = true
		_idle_active = true
		_phase = Phase.ASSEMBLED
		assembly_complete.emit()


func _tick_disassembly(delta: float) -> void:
	_elapsed += delta
	var t_move := minf(_elapsed / DIS_MOVE_DURATION, 1.0)
	var t_fade := minf(_elapsed / DIS_FADE_DURATION, 1.0)
	var e_move := _ease_quad_out(t_move)

	for i in range(_pixel_count):
		_cur_x[i] = lerpf(_from_x[i], _to_x[i], e_move)
		_cur_y[i] = lerpf(_from_y[i], _to_y[i], e_move)
		_cur_a[i] = 1.0 - t_fade

	queue_redraw()

	if _elapsed >= DIS_SETTLE_TIME:
		assembled = false
		_phase = Phase.IDLE
		disassembly_complete.emit()


func _tick_idle(delta: float) -> void:
	if not _idle_active:
		return

	_breathe_t += delta
	_glow_t += delta

	# Blink timer
	_blink_timer += delta
	if not _is_blinking and _blink_timer >= _blink_interval:
		_is_blinking = true
		_eye_alpha = 0.0
		_blink_timer = 0.0
		_blink_interval = randf_range(BLINK_MIN, BLINK_MAX)
		if is_inside_tree():
			var tw := create_tween()
			tw.tween_interval(BLINK_DURATION)
			tw.tween_callback(_end_blink)

	queue_redraw()


func _end_blink() -> void:
	_eye_alpha = 1.0
	_is_blinking = false
	queue_redraw()


# ═══════════════════════════════════════════════════════════════════
# DRAW — Render all pixels via draw_rect (no child nodes)
# ═══════════════════════════════════════════════════════════════════

func _draw() -> void:
	if _pixel_count == 0:
		return

	# Breathing offset (only when assembled + idle)
	var breath_y := 0.0
	if _phase == Phase.ASSEMBLED and _idle_active:
		breath_y = sin(_breathe_t * BREATHE_SPEED) * BREATHE_AMP

	# Glow pulse factor
	var glow := GLOW_BASE + sin(_glow_t * GLOW_SPEED) * GLOW_RANGE

	var ps := pixel_size
	var tint := _mood_tint

	for i in range(_pixel_count):
		var a := _cur_a[i]
		if a < 0.01:
			continue

		var px := _cur_x[i]
		var py := _cur_y[i] + breath_y
		var c := _colors[i]

		# Eye blink override
		if _is_eye[i]:
			a *= _eye_alpha

		# Glow pulse on bright pixels (only when assembled)
		if _is_glow[i] and _phase == Phase.ASSEMBLED:
			c = Color(
				minf(c.r * (0.8 + glow * 0.25), 1.0),
				minf(c.g * (0.9 + glow * 0.15), 1.0),
				c.b, a)
		else:
			c = Color(c.r, c.g, c.b, a)

		# Mood tint
		c = Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)

		draw_rect(Rect2(px, py, ps, ps), c)


# ═══════════════════════════════════════════════════════════════════
# MOOD
# ═══════════════════════════════════════════════════════════════════

func set_mood(mood: String) -> void:
	match mood:
		"amuse": _mood_tint = Color(1.05, 1.0, 0.95)
		"pensif": _mood_tint = Color(0.92, 0.92, 1.0)
		"serieux": _mood_tint = Color(0.88, 0.88, 0.95)
		"warm": _mood_tint = Color(1.0, 0.98, 0.92)
		_: _mood_tint = Color.WHITE
	queue_redraw()


func set_season(_s: String) -> void:
	pass  # PNG-based: sprite colors are intrinsic, no season override needed
