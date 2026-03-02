extends Control
## Animated pixel matrix background — 3D depth waves with ogham symbol convergence.
## Full-screen grid of pixels at varying depths that undulate visibly.
## Periodically, nearby pixels converge to form celtic/ogham symbols.

# Grid
const CELL := 8
const GAP := 1
const DRAW_SIZE: float = CELL - GAP

# Wave parameters — amplified for visible undulation
const W1_SPEED := 0.8
const W1_XFREQ := 0.13
const W1_YFREQ := 0.04
const W1_AMP := 6.0

const W2_SPEED := 1.1
const W2_XFREQ := 0.07
const W2_YFREQ := -0.025
const W2_AMP := 4.0

# Depth breathing (size oscillation)
const DEPTH_SPEED := 0.4
const DEPTH_FREQ := 0.09
const SIZE_VAR := 2.5

# Depth 3D layer factors (0.0 = far, 1.0 = near)
const DEPTH_SIZE_MIN := 0.4
const DEPTH_SIZE_MAX := 1.3
const DEPTH_BRIGHT_MIN := 0.3
const DEPTH_BRIGHT_MAX := 1.2
const DEPTH_WAVE_MIN := 0.4
const DEPTH_WAVE_MAX := 1.6
const DEPTH_ALPHA_MIN := 0.4
const DEPTH_ALPHA_MAX := 1.0

# Symbol timing — convergence lifecycle
const SYM_MIN_INTERVAL := 3.0
const SYM_MAX_INTERVAL := 5.5
const SYM_CONVERGE := 1.2
const SYM_HOLD := 2.0
const SYM_DISPERSE := 1.5
const SYM_MAX := 3
const SYM_PULL_RADIUS := 5  # grid cells — how far pixels get pulled from

# State
var _time := 0.0
var _cols := 0
var _rows := 0
var _phases: PackedFloat32Array
var _depths: PackedFloat32Array
# Pre-computed depth-scaled factors (avoid lerpf per pixel per frame)
var _d_sizes: PackedFloat32Array   # size multiplier
var _d_brights: PackedFloat32Array # brightness multiplier
var _d_waves: PackedFloat32Array   # wave amplitude multiplier
var _d_alphas: PackedFloat32Array  # alpha
var _active_symbols: Array = []
var _next_sym_at := 1.5

# Configurable palette
var _color_dark := Color(0.02, 0.06, 0.03)
var _color_mid := Color(0.05, 0.13, 0.06)
var _color_glow := Color(0.18, 0.9, 0.35)

# Ogham patterns (offsets from anchor [col, row])
var _patterns: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -2

	var vs := get_viewport_rect().size
	if vs.x < 1.0:
		vs = Vector2(800, 600)
	_cols = ceili(vs.x / float(CELL)) + 2
	_rows = ceili(vs.y / float(CELL)) + 2

	var total_cells: int = _cols * _rows

	# Random phase per cell for variety
	_phases.resize(total_cells)
	for i in range(total_cells):
		_phases[i] = randf() * TAU

	# Depth layer per cell (0.0 = far background, 1.0 = near foreground)
	# Use smoothed noise-like distribution based on phase
	_depths.resize(total_cells)
	for i in range(total_cells):
		# Map phase to depth with some spatial coherence
		var base_depth: float = (_phases[i] / TAU)
		# Add spatial gradient (bottom = slightly nearer for natural perspective)
		@warning_ignore("integer_division")
		var row_factor: float = float(i / _cols) / maxf(float(_rows - 1), 1.0)
		_depths[i] = clampf(base_depth * 0.7 + row_factor * 0.3, 0.0, 1.0)

	# Pre-compute depth-scaled factors (avoids 4 lerpf per pixel per frame)
	_d_sizes.resize(total_cells)
	_d_brights.resize(total_cells)
	_d_waves.resize(total_cells)
	_d_alphas.resize(total_cells)
	for i in range(total_cells):
		var dp: float = _depths[i]
		_d_sizes[i] = lerpf(DEPTH_SIZE_MIN, DEPTH_SIZE_MAX, dp)
		_d_brights[i] = lerpf(DEPTH_BRIGHT_MIN, DEPTH_BRIGHT_MAX, dp)
		_d_waves[i] = lerpf(DEPTH_WAVE_MIN, DEPTH_WAVE_MAX, dp)
		_d_alphas[i] = lerpf(DEPTH_ALPHA_MIN, DEPTH_ALPHA_MAX, dp)

	_init_patterns()


func _init_patterns() -> void:
	# Ogham stem (vertical line, 7 cells tall)
	var stem: Array = []
	for r in range(7):
		stem.append([0, r])

	# Group 1 — right strokes (Beith, Luis, Fearn, Sail)
	_patterns.append(stem + [[1, 1]])
	_patterns.append(stem + [[1, 1], [1, 3]])
	_patterns.append(stem + [[1, 1], [1, 3], [1, 5]])
	_patterns.append(stem + [[1, 0], [1, 2], [1, 4], [1, 6]])

	# Group 2 — left strokes (Duir, Tinne)
	_patterns.append(stem + [[-1, 1], [-1, 3]])
	_patterns.append(stem + [[-1, 1], [-1, 3], [-1, 5]])

	# Group 3 — both sides (Muin, Gort)
	_patterns.append(stem + [[1, 2], [-1, 2]])
	_patterns.append(stem + [[1, 1], [-1, 1], [1, 4], [-1, 4]])

	# Group 4 — perpendicular (Ailm)
	_patterns.append(stem + [[1, 2], [-1, 2], [1, 4], [-1, 4], [1, 6], [-1, 6]])

	# Celtic cross
	_patterns.append([
		[-2, 0], [-1, 0], [0, 0], [1, 0], [2, 0],
		[0, -2], [0, -1], [0, 1], [0, 2],
	])
	# Diamond
	_patterns.append([
		[0, -2], [0, 2], [-1, -1], [-1, 1], [1, -1], [1, 1], [0, 0],
	])
	# Triskel (3-arm spiral)
	_patterns.append([
		[0, 0], [1, 0], [2, 0], [0, -1], [0, -2],
		[-1, 0], [-2, 0], [0, 1], [0, 2],
		[1, 1], [-1, -1], [-1, 1], [1, -1],
	])


func set_palette(dark: Color, mid: Color, glow: Color) -> void:
	_color_dark = dark
	_color_mid = mid
	_color_glow = glow


func _process(delta: float) -> void:
	_time += delta

	# Symbol lifecycle
	_next_sym_at -= delta
	if _next_sym_at <= 0.0 and _active_symbols.size() < SYM_MAX:
		_spawn_symbol()
		_next_sym_at = randf_range(SYM_MIN_INTERVAL, SYM_MAX_INTERVAL)

	# Age symbols, remove expired
	var i := _active_symbols.size() - 1
	var total_dur: float = SYM_CONVERGE + SYM_HOLD + SYM_DISPERSE
	while i >= 0:
		_active_symbols[i].age += delta
		if _active_symbols[i].age >= total_dur:
			_active_symbols.remove_at(i)
		i -= 1

	queue_redraw()


func _spawn_symbol() -> void:
	var margin := 6
	_active_symbols.append({
		"col": randi_range(margin, maxi(_cols - margin, margin + 1)),
		"row": randi_range(margin, maxi(_rows - margin, margin + 1)),
		"pattern": _patterns[randi() % _patterns.size()],
		"age": 0.0,
	})


# Returns {progress: 0-1, phase: "converge"/"hold"/"disperse", glow: 0-1}
func _sym_state(age: float) -> Dictionary:
	if age < SYM_CONVERGE:
		var t: float = age / SYM_CONVERGE
		# Ease-in: slow start, accelerating snap into place
		var eased: float = t * t * t
		return {"progress": eased, "phase": "converge", "glow": eased * 0.6}
	if age < SYM_CONVERGE + SYM_HOLD:
		var hold_t: float = (age - SYM_CONVERGE) / SYM_HOLD
		# Pulse during hold
		var pulse: float = 0.85 + 0.15 * sin(hold_t * TAU * 2.0)
		return {"progress": 1.0, "phase": "hold", "glow": pulse}
	var t: float = (age - SYM_CONVERGE - SYM_HOLD) / SYM_DISPERSE
	t = minf(t, 1.0)
	# Ease-out: fast scatter, then slow
	var eased: float = 1.0 - (1.0 - t) * (1.0 - t)
	return {"progress": 1.0 - eased, "phase": "disperse", "glow": (1.0 - eased) * 0.7}


func _draw() -> void:
	var ds: float = DRAW_SIZE

	# Build convergence overrides: {cell_idx: {dx, dy, glow}}
	# dx/dy = pixel offset toward symbol target position (in pixels)
	var overrides := {}
	for sym in _active_symbols:
		var state: Dictionary = _sym_state(sym.age)
		var progress: float = state.progress
		var glow: float = state.glow

		for off in sym.pattern:
			var target_c: int = sym.col + int(off[0])
			var target_r: int = sym.row + int(off[1])
			if target_c < 0 or target_c >= _cols or target_r < 0 or target_r >= _rows:
				continue

			# Find the nearest grid cell to pull from (within SYM_PULL_RADIUS)
			# Each pattern pixel pulls the closest non-target cell toward it
			var target_key: int = target_r * _cols + target_c

			# Source cell = offset from anchor in pull direction (farther out)
			var pull_dir_c: int = int(off[0])
			var pull_dir_r: int = int(off[1])
			# Source is SYM_PULL_RADIUS cells further out from the anchor
			var src_c: int = target_c + pull_dir_c * SYM_PULL_RADIUS
			var src_r: int = target_r + pull_dir_r * SYM_PULL_RADIUS
			# Clamp source to grid
			src_c = clampi(src_c, 0, _cols - 1)
			src_r = clampi(src_r, 0, _rows - 1)
			var src_key: int = src_r * _cols + src_c

			# Displacement in pixels from source toward target
			var dx_px: float = float(target_c - src_c) * CELL * progress
			var dy_px: float = float(target_r - src_r) * CELL * progress

			# Store override for the source cell
			var prev_glow: float = overrides.get(src_key, {}).get("glow", 0.0)
			if glow > prev_glow:
				overrides[src_key] = {"dx": dx_px, "dy": dy_px, "glow": glow}

			# Also glow the target cell itself during hold/disperse
			if progress > 0.8:
				var tgt_prev: float = overrides.get(target_key, {}).get("glow", 0.0)
				if glow > tgt_prev:
					overrides[target_key] = {"dx": 0.0, "dy": 0.0, "glow": glow}

	# Pre-compute per-column wave component (row-independent part)
	var w1_col := PackedFloat32Array()
	w1_col.resize(_cols)
	var w2_col := PackedFloat32Array()
	w2_col.resize(_cols)
	var t1: float = _time * W1_SPEED
	var t2: float = _time * W2_SPEED
	for col in range(_cols):
		w1_col[col] = col * W1_XFREQ
		w2_col[col] = col * W2_XFREQ

	var inv_rows: float = 1.0 / maxf(float(_rows - 1), 1.0)
	var brightness_time: float = _time * 0.3
	var depth_time: float = _time * DEPTH_SPEED

	for row in range(_rows):
		var row_t: float = float(row) * inv_rows
		var row_w1: float = row * W1_YFREQ
		var row_w2: float = row * W2_YFREQ
		var row_base_y: float = row * CELL
		var base_color: Color = _color_dark.lerp(_color_mid, row_t * 0.5)
		var row_idx_base: int = row * _cols

		for col in range(_cols):
			var idx: int = row_idx_base + col
			var ph: float = _phases[idx]

			# --- C1: Pre-computed depth factors (no lerpf per frame) ---
			var d_sz: float = _d_sizes[idx]
			var d_br: float = _d_brights[idx]
			var d_wv: float = _d_waves[idx]
			var d_al: float = _d_alphas[idx]

			# --- C2: Amplified dual wave vertical offset, scaled by depth ---
			var wy: float = sin(t1 + w1_col[col] + row_w1) * W1_AMP * d_wv
			wy += sin(t2 + w2_col[col] + row_w2 + ph) * W2_AMP * d_wv

			# Depth breathing (size), scaled by depth
			var breath: float = sin(depth_time + col * DEPTH_FREQ + ph * 0.5)
			var sz: float = ds * d_sz + breath * SIZE_VAR * d_sz

			# Position (centered within cell)
			var half_diff: float = (ds - sz) * 0.5
			var x: float = col * CELL + half_diff
			var y: float = row_base_y + wy + half_diff

			# --- C3: Convergence displacement ---
			if overrides.has(idx):
				var ov: Dictionary = overrides[idx]
				x += ov.dx
				y += ov.dy

			# Color with depth-modulated brightness
			var bright: float = d_br
			bright *= 0.85 + 0.15 * sin(brightness_time + col * 0.05 + row * 0.03 + ph)
			var color := Color(
				base_color.r * bright,
				base_color.g * bright,
				base_color.b * bright,
				d_al
			)

			# Symbol glow overlay (from convergence)
			if overrides.has(idx):
				color = color.lerp(_color_glow, overrides[idx].glow * 0.9)

			draw_rect(Rect2(x, y, maxf(sz, 1.0), maxf(sz, 1.0)), color)
