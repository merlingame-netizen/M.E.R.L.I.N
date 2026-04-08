## ═══════════════════════════════════════════════════════════════════════════════
## Parchment Display — Pre-run backstory + animated map reveal
## ═══════════════════════════════════════════════════════════════════════════════
## Vertical layout (mobile-first): backstory text on top, parchment map below.
## Celtic medieval aesthetic: MorrisRoman fonts, parchment texture, animated nodes.
## Nodes pulse and sparkle on reveal — NO text labels on the map.
## ═══════════════════════════════════════════════════════════════════════════════

extends Control
class_name ParchmentDisplay

signal animation_finished
signal skip_requested
signal transition_to_map_requested

var _graph: MerlinRunGraph = null

## Animation state.
var _is_animating: bool = false
var _can_skip: bool = false
var _char_index: int = 0
var _time_elapsed: float = 0.0
var _map_started: bool = false
var _cursor_visible: bool = true
var _cursor_blink_time: float = 0.0

## Node animation state.
var _node_reveal_times: Dictionary = {}
var _node_particles: Dictionary = {}
var _pulse_active: bool = false

## Quill animation state.
var _quill_index: int = 0
var _quill_visible: bool = false
var _quill_timer: Timer = null

## Decoration state (spawned by quill).
var _decorations: Array[Dictionary] = []
var _decoration_spawn_counter: int = 0

## Pion drop animation state.
var _pion_animations: Dictionary = {}
var _dust_particles: Dictionary = {}

## Timing.
const CHAR_DELAY: float = 0.022
const PATH_DELAY: float = 0.05
const PULSE_REDRAW_INTERVAL: float = 0.066
const QUILL_DELAY: float = 0.018
const PION_DROP_DURATION: float = 0.45
const PION_DROP_HEIGHT: float = 80.0

## ── Palette ──────────────────────────────────────────────────────────────────
const COL_BG: Color = Color(0.06, 0.04, 0.02)
const COL_BG_TOP: Color = Color(0.10, 0.07, 0.03)
const COL_TITLE: Color = Color(1.0, 0.78, 0.15)
const COL_TEXT: Color = Color(0.92, 0.88, 0.75)
const COL_DIM: Color = Color(0.45, 0.40, 0.30)
const COL_TRAIL: Color = Color(0.35, 0.22, 0.08)
const COL_TRAIL_LIT: Color = Color(0.55, 0.38, 0.15)
const COL_TRAIL_EDGE: Color = Color(0.65, 0.48, 0.22)
const COL_EVENT: Color = Color(1.0, 0.55, 0.1)
const COL_MYSTERY: Color = Color(0.3, 0.7, 1.0)
const COL_REST: Color = Color(0.25, 0.75, 0.35)
const COL_MERLIN: Color = Color(1.0, 0.85, 0.2)
const COL_PROMISE: Color = Color(0.75, 0.4, 0.95)
const COL_MINOR: Color = Color(0.55, 0.50, 0.40)
const COL_DETOUR: Color = Color(0.5, 0.35, 0.15)
const COL_ACCENT: Color = Color(0.85, 0.55, 0.1)

## Pion colors (wood/stone board game look).
const COL_PION_WOOD: Color = Color(0.62, 0.45, 0.25)
const COL_PION_WOOD_DARK: Color = Color(0.42, 0.30, 0.15)
const COL_PION_WOOD_LIGHT: Color = Color(0.78, 0.62, 0.40)
const COL_PION_STONE: Color = Color(0.52, 0.50, 0.48)
const COL_PION_STONE_DARK: Color = Color(0.35, 0.33, 0.30)
const COL_PION_SHADOW: Color = Color(0.15, 0.10, 0.05, 0.35)
const COL_QUILL_INK: Color = Color(0.25, 0.15, 0.05, 0.6)

## Parchment texture colors.
const PARCH_BASE: Color = Color(0.82, 0.74, 0.58)
const PARCH_DARK: Color = Color(0.68, 0.60, 0.44)
const PARCH_STAIN: Color = Color(0.60, 0.52, 0.38)

## UI refs.
var _title_label: Label = null
var _text_label: Label = null
var _cursor_label: Label = null
var _map_canvas: Control = null
var _skip_label: Label = null
var _char_timer: Timer = null
var _pulse_timer: Timer = null

## Fonts.
var _font_title: Font = null
var _font_body: Font = null

## Parchment texture.
var _parchment_tex: ImageTexture = null
var _parchment_tex_size: Vector2i = Vector2i.ZERO

## Map data.
var _trail_points: Array[Vector2] = []
var _node_trail_indices: Dictionary = {}
var _revealed_trail_count: int = 0
var _revealed_node_ids: Array[String] = []
var _node_positions: Dictionary = {}


func _ready() -> void:
	_load_fonts()
	_build_ui()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


func _process(delta: float) -> void:
	_time_elapsed += delta
	_cursor_blink_time += delta
	if _cursor_blink_time >= 0.4:
		_cursor_blink_time = 0.0
		_cursor_visible = not _cursor_visible
		if _cursor_label and _is_animating:
			_cursor_label.visible = _cursor_visible
	# Continuous redraw during animation for sparkle particles.
	if _is_animating and _map_started:
		_map_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _is_animating or not _can_skip:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		_skip()


# ── Fonts ─────────────────────────────────────────────────────────────────

func _load_fonts() -> void:
	_font_title = _try_load_font("res://resources/fonts/morris/MorrisRomanBlack.ttf")
	_font_body = _try_load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf")
	if _font_title == null:
		_font_title = ThemeDB.fallback_font
	if _font_body == null:
		_font_body = ThemeDB.fallback_font


func _try_load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Font:
			return res as Font
	return null


# ── Parchment Texture ─────────────────────────────────────────────────────

func _generate_parchment_texture(w: int, h: int) -> ImageTexture:
	if w < 4 or h < 4:
		return null
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.004
	noise.seed = randi()

	var noise2: FastNoiseLite = FastNoiseLite.new()
	noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise2.frequency = 0.018
	noise2.seed = randi() + 42

	var cx: float = float(w) * 0.5
	var cy: float = float(h) * 0.5

	for y in range(h):
		for x in range(w):
			# Base parchment color with noise variation.
			var n1: float = noise.get_noise_2d(float(x), float(y))
			var brightness: float = 0.90 + n1 * 0.10

			var col: Color = PARCH_BASE * brightness

			# Edge darkening vignette.
			var dx: float = (float(x) - cx) / cx
			var dy: float = (float(y) - cy) / cy
			var dist: float = sqrt(dx * dx + dy * dy)
			col = col * (1.0 - pow(clampf(dist, 0.0, 1.0), 2.5) * 0.25)

			# Age stains.
			var n2: float = noise2.get_noise_2d(float(x), float(y))
			if n2 < -0.25:
				col = col.lerp(PARCH_STAIN, 0.15)

			col.a = 1.0
			img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)


func _ensure_parchment_texture() -> void:
	var sz: Vector2i = Vector2i(int(_map_canvas.size.x), int(_map_canvas.size.y))
	if sz.x < 4 or sz.y < 4:
		sz = Vector2i(640, 400)
	# Only regenerate if size changed significantly.
	if _parchment_tex != null and absf(float(sz.x - _parchment_tex_size.x)) < 50:
		return
	# Generate at half resolution for performance, stretched on draw.
	var half_w: int = maxi(int(sz.x / 2.0), 64)
	var half_h: int = maxi(int(sz.y / 2.0), 64)
	_parchment_tex = _generate_parchment_texture(half_w, half_h)
	_parchment_tex_size = sz


# ── Public ─────────────────────────────────────────────────────────────────

func reveal(graph: MerlinRunGraph) -> void:
	_graph = graph
	if _graph == null:
		animation_finished.emit()
		return

	visible = true
	modulate = Color(1, 1, 1, 0)
	_time_elapsed = 0.0
	_char_index = 0
	_map_started = false
	_revealed_trail_count = 0
	_revealed_node_ids.clear()
	_trail_points.clear()
	_node_trail_indices.clear()
	_node_positions.clear()
	_node_reveal_times.clear()
	_node_particles.clear()
	_decorations.clear()
	_decoration_spawn_counter = 0
	_pion_animations.clear()
	_dust_particles.clear()
	_quill_index = 0
	_quill_visible = false
	_is_animating = true
	_can_skip = false
	_pulse_active = false

	_title_label.text = ""
	_text_label.text = ""
	if _cursor_label:
		_cursor_label.visible = false

	set_process(true)

	# Fade in.
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)
	await tw.finished

	_ensure_parchment_texture()
	_compute_winding_trail()

	# Type title.
	var title: String = _graph.scenario_title
	for i in range(title.length()):
		if not _is_animating:
			break
		_title_label.text = title.substr(0, i + 1)
		await get_tree().create_timer(0.04).timeout
	_title_label.text = title

	await get_tree().create_timer(0.3).timeout
	_can_skip = true
	_skip_label.visible = true
	if _cursor_label:
		_cursor_label.visible = true

	# Start text + map simultaneously.
	_char_timer.start(CHAR_DELAY)
	_map_started = true
	_quill_visible = true
	_quill_timer.start(QUILL_DELAY)


func dismiss() -> void:
	set_process(false)
	_pulse_active = false
	_quill_visible = false
	if _quill_timer:
		_quill_timer.stop()
	if _pulse_timer:
		_pulse_timer.stop()
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	await tw.finished
	visible = false


func _skip() -> void:
	_char_timer.stop()
	if _quill_timer:
		_quill_timer.stop()
	_quill_visible = false
	_is_animating = false
	_map_started = true
	_title_label.text = _graph.scenario_title
	_text_label.text = _graph.scenario_synopsis
	if _cursor_label:
		_cursor_label.visible = false
	_revealed_trail_count = _trail_points.size()
	_quill_index = _trail_points.size()
	_revealed_node_ids.clear()
	for nid in _graph.main_path:
		_revealed_node_ids.append(nid)
		if not _node_reveal_times.has(nid):
			_node_reveal_times[nid] = _time_elapsed
	for nid in _graph.nodes:
		if _graph.nodes[nid].get("is_detour", false):
			_revealed_node_ids.append(nid)
			if not _node_reveal_times.has(nid):
				_node_reveal_times[nid] = _time_elapsed
	_node_particles.clear()
	_pion_animations.clear()
	_map_canvas.queue_redraw()
	_skip_label.visible = false
	# Keep pulse going after skip.
	_pulse_active = true
	_pulse_timer.start(PULSE_REDRAW_INTERVAL)
	set_process(false)
	animation_finished.emit()


# ── Text timer ─────────────────────────────────────────────────────────────

func _on_char_tick() -> void:
	if _graph == null:
		_char_timer.stop()
		return
	var full: String = _graph.scenario_synopsis
	if _char_index >= full.length():
		_char_timer.stop()
		if _cursor_label:
			_cursor_label.visible = false
		_check_done()
		return
	var step: int = 1
	if _char_index + 1 < full.length() and full[_char_index] == " ":
		step = 2
	_char_index = mini(_char_index + step, full.length())
	_text_label.text = full.substr(0, _char_index)


# ── Quill timer (drives trail + node reveal + decorations) ────────────────

func _on_quill_tick() -> void:
	if _trail_points.is_empty():
		_quill_timer.stop()
		_quill_visible = false
		_check_done()
		return
	if _quill_index >= _trail_points.size():
		_quill_timer.stop()
		_quill_visible = false
		# Reveal any remaining nodes.
		for nid in _graph.main_path:
			if not _revealed_node_ids.has(nid):
				_reveal_node_with_drop(nid)
		_map_canvas.queue_redraw()
		_check_done()
		return

	# Advance quill by 3 trail points per tick (smooth movement).
	var batch: int = 3
	for _i in range(batch):
		if _quill_index >= _trail_points.size():
			break
		_quill_index += 1
		_revealed_trail_count = _quill_index

		# Spawn decorations every 4-6 trail points.
		_decoration_spawn_counter += 1
		if _decoration_spawn_counter >= randi_range(4, 6):
			_decoration_spawn_counter = 0
			_spawn_decoration(_trail_points[_quill_index - 1])

		# Check if quill reached a node position.
		for nid in _node_trail_indices:
			if int(_node_trail_indices[nid]) == _quill_index - 1:
				if not _revealed_node_ids.has(nid):
					_reveal_node_with_drop(nid)

	_map_canvas.queue_redraw()


func _reveal_node_with_drop(nid: String) -> void:
	_revealed_node_ids.append(nid)
	_node_reveal_times[nid] = _time_elapsed
	var npos: Vector2 = _node_positions.get(nid, Vector2.ZERO)
	# Start pion drop animation.
	_pion_animations[nid] = {
		"start_time": _time_elapsed,
		"target_pos": npos,
	}
	# Sparkles spawn after drop lands.
	_node_particles[nid] = _spawn_sparkles(npos, randi_range(4, 6))


func _check_done() -> void:
	if _char_timer.is_stopped() and _quill_timer.is_stopped() and _is_animating:
		_is_animating = false
		_skip_label.visible = false
		if _cursor_label:
			_cursor_label.visible = false
		# Switch to pulse-only redraw (low frequency).
		_pulse_active = true
		_pulse_timer.start(PULSE_REDRAW_INTERVAL)
		set_process(false)
		animation_finished.emit()


func _on_pulse_tick() -> void:
	if _pulse_active and _map_canvas:
		_map_canvas.queue_redraw()


# ── Sparkle particles ─────────────────────────────────────────────────────

func _spawn_sparkles(_center: Vector2, count: int) -> Array:
	var particles: Array = []
	for _i in range(count):
		particles.append({
			"dir": Vector2.from_angle(randf() * TAU),
			"speed": randf_range(30.0, 65.0),
			"life": randf_range(0.35, 0.7),
			"size": randf_range(1.5, 3.5),
		})
	return particles


func _draw_sparkles_for_node(nid: String) -> void:
	if not _node_particles.has(nid) or not _node_positions.has(nid):
		return
	var center: Vector2 = _node_positions[nid]
	var reveal_t: float = _node_reveal_times.get(nid, 0.0)
	var age: float = _time_elapsed - reveal_t
	var col: Color = _ncol(str(_graph.nodes.get(nid, {}).get("type", "")), false)
	var all_dead: bool = true

	for p in _node_particles[nid]:
		var t: float = age / float(p["life"])
		if t > 1.0:
			continue
		all_dead = false
		var alpha: float = (1.0 - t) * 0.9
		var offset: Vector2 = p["dir"] * p["speed"] * age
		var sz: float = p["size"] * (1.0 - t * 0.4)
		var spark_col: Color = Color(
			minf(col.r + 0.3, 1.0), minf(col.g + 0.2, 1.0), minf(col.b + 0.1, 1.0), alpha
		)
		_map_canvas.draw_circle(center + offset, sz, spark_col)

	if all_dead:
		_node_particles.erase(nid)


# ── Decorations (spawned by quill along trail) ───────────────────────────

func _spawn_decoration(pos: Vector2) -> void:
	var rng_val: int = abs(int(pos.x * 37.0 + pos.y * 13.0 + _decorations.size() * 7.0))
	# Perpendicular offset (left or right of trail).
	var side: float = 1.0 if (rng_val % 2 == 0) else -1.0
	var offset_dist: float = 15.0 + float(rng_val % 20)
	# Approximate trail tangent from nearby points.
	var tang: Vector2 = Vector2(0, -1)
	if _quill_index > 1 and _quill_index < _trail_points.size():
		tang = (_trail_points[_quill_index - 1] - _trail_points[_quill_index - 2]).normalized()
	var perp: Vector2 = Vector2(-tang.y, tang.x) * side
	var deco_pos: Vector2 = pos + perp * offset_dist

	# Type selection (seeded).
	var type_roll: int = rng_val % 10
	var deco_type: String = "tree"
	if type_roll < 4:
		deco_type = "tree"
	elif type_roll < 6:
		deco_type = "rock"
	elif type_roll < 8:
		deco_type = "bush"
	else:
		deco_type = "mushroom"

	_decorations.append({
		"pos": deco_pos,
		"type": deco_type,
		"size": 1.0 + float(rng_val % 5) * 0.15,
		"rotation": float(rng_val % 360) * PI / 180.0,
	})


func _draw_decorations() -> void:
	for deco in _decorations:
		var pos: Vector2 = deco["pos"]
		var deco_type: String = deco["type"]
		var sz: float = deco["size"]
		match deco_type:
			"tree":
				# Ink tree: trunk + foliage circle.
				var h: float = 6.0 * sz
				var trunk_col: Color = Color(0.32, 0.25, 0.12, 0.4)
				var leaf_col: Color = Color(0.28, 0.40, 0.18, 0.35)
				_map_canvas.draw_line(pos, pos + Vector2(0, -h), trunk_col, 1.2)
				_map_canvas.draw_circle(pos + Vector2(0, -h), 3.0 * sz, leaf_col)
			"rock":
				# Small grey rock.
				var rock_col: Color = Color(0.45, 0.42, 0.38, 0.35)
				_map_canvas.draw_circle(pos, 2.5 * sz, rock_col)
				_map_canvas.draw_circle(pos + Vector2(-0.5, -0.5), 1.5 * sz, Color(0.55, 0.52, 0.48, 0.25))
			"bush":
				# Dark green ovoid bush.
				var bush_col: Color = Color(0.22, 0.35, 0.15, 0.3)
				_map_canvas.draw_circle(pos, 3.0 * sz, bush_col)
				_map_canvas.draw_circle(pos + Vector2(1.5, -0.5), 2.0 * sz, Color(0.30, 0.42, 0.20, 0.25))
			"mushroom":
				# Tiny mushroom dot.
				_map_canvas.draw_circle(pos, 1.5 * sz, Color(0.55, 0.35, 0.20, 0.3))
				_map_canvas.draw_circle(pos + Vector2(0, -1.5 * sz), 2.0 * sz, Color(0.70, 0.30, 0.15, 0.35))


# ── Quill drawing (procedural feather pen) ───────────────────────────────

func _draw_quill() -> void:
	if not _quill_visible or _quill_index < 1 or _quill_index >= _trail_points.size():
		return
	var pos: Vector2 = _trail_points[_quill_index - 1]
	# Tangent for rotation.
	var tang: Vector2 = Vector2(0, -1)
	if _quill_index > 1:
		tang = (_trail_points[_quill_index - 1] - _trail_points[_quill_index - 2]).normalized()
	# Ink drip behind the quill.
	_map_canvas.draw_circle(pos, 2.0, COL_QUILL_INK)

	# Quill body: elongated shape pointing along trail direction.
	var quill_len: float = 22.0
	var quill_w: float = 3.5
	var tip: Vector2 = pos
	var base: Vector2 = pos - tang * quill_len
	var right: Vector2 = Vector2(-tang.y, tang.x)

	# Feather shape (5-point polygon).
	var points: PackedVector2Array = PackedVector2Array([
		tip,
		pos - tang * 4.0 + right * quill_w * 0.4,
		base + right * quill_w,
		base - right * quill_w,
		pos - tang * 4.0 - right * quill_w * 0.4,
	])
	var quill_col: Color = Color(0.85, 0.82, 0.75, 0.9)
	_map_canvas.draw_colored_polygon(points, quill_col)

	# Quill shaft (dark line through center).
	_map_canvas.draw_line(tip, base, Color(0.40, 0.30, 0.15, 0.8), 1.0)

	# Barbule lines on the feather.
	for i in range(3):
		var t: float = 0.4 + float(i) * 0.18
		var bp: Vector2 = tip.lerp(base, t)
		var barb_len: float = quill_w * (0.6 + t * 0.4)
		_map_canvas.draw_line(bp, bp + right * barb_len, Color(0.70, 0.65, 0.55, 0.4), 0.8)
		_map_canvas.draw_line(bp, bp - right * barb_len, Color(0.70, 0.65, 0.55, 0.4), 0.8)

	# Nib tip (dark).
	_map_canvas.draw_circle(tip, 1.5, Color(0.20, 0.12, 0.05, 0.9))


# ── Pion drawing (board game pieces, top-down view) ──────────────────────

func _get_pion_colors(ntype: String) -> Array:
	## Returns [base, ring, center_dot] colors for a pion type.
	if ntype in ["merlin", "mystery"]:
		return [COL_PION_STONE, COL_PION_STONE_DARK, Color(0.65, 0.62, 0.58)]
	return [COL_PION_WOOD, COL_PION_WOOD_DARK, COL_PION_WOOD_LIGHT]


func _get_pion_draw_pos(nid: String) -> Vector2:
	## Returns interpolated position during drop animation.
	var target: Vector2 = _node_positions.get(nid, Vector2.ZERO)
	if not _pion_animations.has(nid):
		return target
	var anim: Dictionary = _pion_animations[nid]
	var elapsed: float = _time_elapsed - float(anim["start_time"])
	if elapsed >= PION_DROP_DURATION:
		# Animation done — spawn dust on first completion frame.
		if _pion_animations.has(nid):
			_pion_animations.erase(nid)
			_dust_particles[nid] = _spawn_dust(target)
		return target
	# Ease-out bounce interpolation.
	var t: float = elapsed / PION_DROP_DURATION
	var bounce_t: float = _ease_out_bounce(t)
	var from_y: float = target.y - PION_DROP_HEIGHT
	return Vector2(target.x, lerpf(from_y, target.y, bounce_t))


func _ease_out_bounce(t: float) -> float:
	if t < 1.0 / 2.75:
		return 7.5625 * t * t
	elif t < 2.0 / 2.75:
		var t2: float = t - 1.5 / 2.75
		return 7.5625 * t2 * t2 + 0.75
	elif t < 2.5 / 2.75:
		var t2: float = t - 2.25 / 2.75
		return 7.5625 * t2 * t2 + 0.9375
	else:
		var t2: float = t - 2.625 / 2.75
		return 7.5625 * t2 * t2 + 0.984375


func _spawn_dust(_pos: Vector2) -> Array:
	var particles: Array = []
	for _i in range(4):
		particles.append({
			"dir": Vector2.from_angle(randf_range(-PI, -0.1)),
			"speed": randf_range(15.0, 40.0),
			"life": randf_range(0.25, 0.5),
			"size": randf_range(1.0, 2.5),
		})
	return particles


func _draw_dust_for_node(nid: String) -> void:
	if not _dust_particles.has(nid) or not _node_positions.has(nid):
		return
	var center: Vector2 = _node_positions[nid]
	var reveal_t: float = _node_reveal_times.get(nid, 0.0)
	var age: float = _time_elapsed - reveal_t - PION_DROP_DURATION
	if age < 0.0:
		return
	var all_dead: bool = true
	for p in _dust_particles[nid]:
		var t: float = age / float(p["life"])
		if t > 1.0:
			continue
		all_dead = false
		var alpha: float = (1.0 - t) * 0.6
		var offset: Vector2 = p["dir"] * p["speed"] * age
		var sz: float = p["size"] * (1.0 - t * 0.3)
		_map_canvas.draw_circle(center + offset, sz, Color(0.55, 0.42, 0.25, alpha))
	if all_dead:
		_dust_particles.erase(nid)


func _draw_pion(nid: String, pos: Vector2, base_radius: float, ntype: String, is_start: bool, is_end: bool) -> void:
	var colors: Array = _get_pion_colors(ntype)
	var base_col: Color = colors[0]
	var ring_col: Color = colors[1]
	var highlight_col: Color = colors[2]

	var r: float = base_radius

	# Pulse animation.
	var age: float = _time_elapsed - _node_reveal_times.get(nid, _time_elapsed)
	var pulse: float = 0.97 + 0.06 * sin(age * 2.0 + float(nid.hash()) * 0.1)
	r *= pulse

	# Shadow (slightly offset).
	_map_canvas.draw_circle(pos + Vector2(2.0, 2.5), r + 1.0, COL_PION_SHADOW)

	# Base disc.
	_map_canvas.draw_circle(pos, r, base_col)

	# Outer ring (carved groove).
	_map_canvas.draw_arc(pos, r - 1.0, 0, TAU, 32, ring_col, 1.5)
	_map_canvas.draw_arc(pos, r + 0.5, 0, TAU, 32, Color(ring_col.r, ring_col.g, ring_col.b, 0.3), 0.8)

	# Inner ring (second groove for larger pions).
	if r >= 9.0:
		_map_canvas.draw_arc(pos, r * 0.55, 0, TAU, 24, ring_col, 1.0)

	# Center mark — subtle symbol per type.
	if is_start:
		# Start: small star shape.
		for i in range(4):
			var a: float = float(i) * PI * 0.5 + age * 0.5
			var tip: Vector2 = pos + Vector2(cos(a), sin(a)) * r * 0.35
			_map_canvas.draw_line(pos, tip, highlight_col, 1.0)
	elif is_end:
		# End: small cross.
		_map_canvas.draw_line(pos + Vector2(-r * 0.3, 0), pos + Vector2(r * 0.3, 0), highlight_col, 1.2)
		_map_canvas.draw_line(pos + Vector2(0, -r * 0.3), pos + Vector2(0, r * 0.3), highlight_col, 1.2)
	else:
		# Default: center dot.
		_map_canvas.draw_circle(pos, r * 0.2, highlight_col)

	# Top-light highlight (3D effect).
	if r >= 6.0:
		_map_canvas.draw_circle(pos + Vector2(-1.0, -1.5), r * 0.28, Color(1, 1, 1, 0.15))


# ── Winding trail (organic random walk) ──────────────────────────────────

func _compute_winding_trail() -> void:
	_trail_points.clear()
	_node_trail_indices.clear()
	_node_positions.clear()
	if _graph == null or _graph.main_path.is_empty():
		return

	var sz: Vector2 = _map_canvas.size if _map_canvas.size.x > 10 else Vector2(400, 500)
	var margin_x: float = 45.0
	var margin_y: float = 35.0
	var n_main: int = _graph.main_path.size()
	var center_x: float = sz.x * 0.5
	var usable_h: float = sz.y - margin_y * 2.0
	var usable_w: float = sz.x - margin_x * 2.0

	# Variable Y spacing (weight-based).
	var weights: Array[float] = []
	var total_weight: float = 0.0
	for i in range(n_main):
		var nid: String = _graph.main_path[i]
		var node: Dictionary = _graph.nodes.get(nid, {})
		var ntype: String = str(node.get("type", "narrative"))
		var w: float = 1.0
		if ntype in ["event", "mystery", "promise"]:
			w = 2.0
		elif ntype == "merlin":
			w = 2.5
		elif ntype == "narrative":
			w = 0.6 + randf() * 0.3
		elif ntype in ["rest", "merchant"]:
			w = 1.0 + randf() * 0.4
		weights.append(w)
		total_weight += w

	var cum: float = 0.0
	var y_positions: Array[float] = []
	for i in range(n_main):
		y_positions.append(sz.y - margin_y - (cum / total_weight) * usable_h)
		cum += weights[i]

	# Random walk X — centered band with moderate serpentine.
	var cur_x: float = center_x + randf_range(-20.0, 20.0)
	var max_step: float = usable_w * 0.20
	var x_margin_inner: float = sz.x * 0.15
	for i in range(n_main):
		var nid: String = _graph.main_path[i]
		var pull: float = (center_x - cur_x) * 0.25
		var step_x: float = randf_range(-max_step, max_step) + pull
		cur_x = clampf(cur_x + step_x, x_margin_inner, sz.x - x_margin_inner)
		_node_positions[nid] = Vector2(cur_x, y_positions[i])

	# Detour nodes.
	for nid in _graph.nodes:
		var node: Dictionary = _graph.nodes[nid]
		if not node.get("is_detour", false):
			continue
		var floor_idx: int = int(node.get("floor", 0))
		var ref_pos: Vector2 = Vector2(center_x, sz.y * 0.5)
		for main_nid in _graph.main_path:
			var mn: Dictionary = _graph.nodes.get(main_nid, {})
			if int(mn.get("floor", -1)) == floor_idx and _node_positions.has(main_nid):
				ref_pos = _node_positions[main_nid]
				break
		var side: float = 1.0 if ref_pos.x < center_x else -1.0
		var det_offset: float = (40.0 + randf() * 20.0) * side
		_node_positions[nid] = Vector2(
			clampf(ref_pos.x + det_offset, margin_x, sz.x - margin_x),
			ref_pos.y + randf_range(-8.0, 8.0)
		)

	# Build trail with varied Bezier curves.
	var segments_per_edge: int = 10
	for i in range(n_main - 1):
		var from_nid: String = _graph.main_path[i]
		var to_nid: String = _graph.main_path[i + 1]
		if not _node_positions.has(from_nid) or not _node_positions.has(to_nid):
			continue
		var p0: Vector2 = _node_positions[from_nid]
		var p1: Vector2 = _node_positions[to_nid]
		if not _node_trail_indices.has(from_nid):
			_node_trail_indices[from_nid] = _trail_points.size()

		var h: int = abs((from_nid + to_nid).hash())
		var curve_roll: float = float(h % 100) / 100.0
		var mid: Vector2 = (p0 + p1) * 0.5
		var dy: float = absf(p1.y - p0.y)
		var perp_x: float = dy * 0.4

		var cp: Vector2
		if curve_roll < 0.20:
			cp = mid + Vector2(randf_range(-15.0, 15.0), 0)
		elif curve_roll < 0.55:
			var sign_f: float = 1.0 if (h % 2 == 0) else -1.0
			cp = mid + Vector2(perp_x * 1.2 * sign_f, randf_range(-dy * 0.1, dy * 0.1))
		else:
			var sign_f: float = 1.0 if (h % 3 == 0) else -1.0
			cp = mid + Vector2(perp_x * 2.5 * sign_f, randf_range(-dy * 0.15, dy * 0.15))
		cp.x = clampf(cp.x, margin_x - 10, sz.x - margin_x + 10)

		for s in range(segments_per_edge):
			var t: float = float(s) / float(segments_per_edge)
			var u: float = 1.0 - t
			_trail_points.append(u * u * p0 + 2.0 * u * t * cp + t * t * p1)

	if n_main > 0:
		var last_nid: String = _graph.main_path[n_main - 1]
		_node_trail_indices[last_nid] = _trail_points.size() - 1
		if _node_positions.has(last_nid):
			_trail_points.append(_node_positions[last_nid])


# ── Map draw (parchment + animated nodes) ────────────────────────────────

func _on_map_draw() -> void:
	if _graph == null:
		return

	# 0. Parchment texture background.
	_ensure_parchment_texture()
	if _parchment_tex:
		_map_canvas.draw_texture_rect(_parchment_tex, Rect2(Vector2.ZERO, _map_canvas.size), false)

	# 1. Terrain glow zones (on parchment, subtler).
	for nid in _revealed_node_ids:
		if not _node_positions.has(nid):
			continue
		var pos: Vector2 = _node_positions[nid]
		var node: Dictionary = _graph.nodes.get(nid, {})
		var ntype: String = str(node.get("type", ""))
		var is_major: bool = ntype in ["event", "mystery", "promise", "merlin"]
		var glow_r: float = 28.0 if is_major else 16.0
		var glow_col: Color = _ncol(ntype, false)
		glow_col.a = 0.08
		_map_canvas.draw_circle(pos, glow_r, glow_col)

	# 2. Mini terrain.
	for nid in _revealed_node_ids:
		if not _node_positions.has(nid):
			continue
		var node: Dictionary = _graph.nodes.get(nid, {})
		_draw_mini_terrain(_node_positions[nid], str(node.get("type", "")))

	# 3. Trail (3-layer: shadow, body, highlight) — ink on parchment.
	if _revealed_trail_count > 1:
		for i in range(1, _revealed_trail_count):
			_map_canvas.draw_line(_trail_points[i - 1], _trail_points[i], COL_TRAIL, 7.0)
		for i in range(1, _revealed_trail_count):
			_map_canvas.draw_line(_trail_points[i - 1], _trail_points[i], COL_TRAIL_LIT, 4.0)
		for i in range(1, _revealed_trail_count):
			_map_canvas.draw_line(_trail_points[i - 1], _trail_points[i], COL_TRAIL_EDGE, 1.5)

	# 4. Detour dashed lines.
	for nid in _revealed_node_ids:
		var node: Dictionary = _graph.nodes.get(nid, {})
		if not node.get("is_detour", false):
			continue
		var det_pos: Vector2 = _node_positions.get(nid, Vector2.ZERO)
		for next_id in node.get("next", []):
			var next_pos: Vector2 = _node_positions.get(str(next_id), Vector2.ZERO)
			if next_pos != Vector2.ZERO:
				_draw_dashed(det_pos, next_pos, COL_DETOUR, 2.0)
		for main_nid in _graph.main_path:
			var mn: Dictionary = _graph.nodes.get(main_nid, {})
			var entry: String = str(mn.get("detour_entry", ""))
			if entry == nid and _node_positions.has(main_nid):
				_draw_dashed(_node_positions[main_nid], det_pos, COL_DETOUR, 2.0)
				break

	# 5. Decorations (drawn between trail and nodes).
	_draw_decorations()

	# 6. Pions (board game pieces with drop animation, NO labels).
	for nid in _revealed_node_ids:
		if not _node_positions.has(nid):
			continue
		var node: Dictionary = _graph.nodes.get(nid, {})
		var ntype: String = str(node.get("type", ""))
		var det: bool = node.get("is_detour", false)
		var is_major: bool = ntype in ["event", "merlin", "mystery", "promise"]

		var base_radius: float = 5.0
		if det:
			base_radius = 4.0
		elif is_major:
			base_radius = 11.0
		else:
			base_radius = 6.0

		# Start/end markers.
		var is_start: bool = (nid == _graph.main_path[0])
		var is_end: bool = (nid == _graph.main_path[_graph.main_path.size() - 1])
		if is_start or is_end:
			base_radius = 13.0

		# Get animated position (drop animation).
		var draw_pos: Vector2 = _get_pion_draw_pos(nid)

		# Draw the pion.
		_draw_pion(nid, draw_pos, base_radius, ntype, is_start, is_end)

		# Sparkle + dust particles.
		_draw_sparkles_for_node(nid)
		_draw_dust_for_node(nid)

	# 7. Quill pen (on top of everything).
	_draw_quill()


func _draw_mini_terrain(pos: Vector2, ntype: String) -> void:
	var seed_val: int = int(absf(pos.x * 100.0 + pos.y * 7.0))
	var rng: int = seed_val
	for _i in range(3):
		rng = absi((rng * 1103515245 + 12345) % 2147483648)
		var angle: float = float(rng % 360) * PI / 180.0
		var dist: float = 18.0 + float(rng % 18)
		var tp: Vector2 = pos + Vector2(cos(angle), sin(angle)) * dist
		rng = absi((rng * 1103515245 + 12345) % 2147483648)
		if ntype in ["narrative", "event", "mystery", ""]:
			# Ink trees on parchment.
			var h: float = 5.0 + float(rng % 4)
			var tree_col: Color = Color(0.30, 0.42, 0.20, 0.35)
			_map_canvas.draw_line(tp, tp + Vector2(0, -h), tree_col, 1.5)
			_map_canvas.draw_circle(tp + Vector2(0, -h), 2.5, tree_col)
		elif ntype in ["rest", "merchant"]:
			_map_canvas.draw_circle(tp, 2.0, Color(0.45, 0.38, 0.25, 0.3))
		elif ntype in ["promise", "merlin"]:
			_map_canvas.draw_circle(tp, 1.5, Color(0.65, 0.50, 0.15, 0.3))


func _draw_dashed(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var segs: int = 6
	for i in range(segs):
		if i % 2 == 0:
			var p0: Vector2 = from.lerp(to, float(i) / float(segs))
			var p1: Vector2 = from.lerp(to, float(i + 1) / float(segs))
			_map_canvas.draw_line(p0, p1, color, width)


func _ncol(ntype: String, det: bool) -> Color:
	if det:
		return COL_DETOUR
	match ntype:
		"event":
			return COL_EVENT
		"mystery":
			return COL_MYSTERY
		"rest", "merchant":
			return COL_REST
		"merlin":
			return COL_MERLIN
		"promise":
			return COL_PROMISE
	return COL_MINOR


# ── UI Build (vertical mobile-first, celtic medieval) ────────────────────

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background.
	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── Top section: backstory text (30% height) ─────────────────────────
	var top_bg: ColorRect = ColorRect.new()
	top_bg.color = COL_BG_TOP
	top_bg.anchor_left = 0.0
	top_bg.anchor_right = 1.0
	top_bg.anchor_top = 0.0
	top_bg.anchor_bottom = 0.30
	add_child(top_bg)

	# Accent line at bottom of text area.
	var accent_line: ColorRect = ColorRect.new()
	accent_line.color = COL_ACCENT
	accent_line.anchor_left = 0.05
	accent_line.anchor_right = 0.95
	accent_line.anchor_top = 0.30
	accent_line.anchor_bottom = 0.30
	accent_line.offset_top = -1
	accent_line.offset_bottom = 1
	add_child(accent_line)

	var top_margin: MarginContainer = MarginContainer.new()
	top_margin.anchor_left = 0.0
	top_margin.anchor_right = 1.0
	top_margin.anchor_top = 0.0
	top_margin.anchor_bottom = 0.30
	top_margin.add_theme_constant_override("margin_left", 40)
	top_margin.add_theme_constant_override("margin_right", 40)
	top_margin.add_theme_constant_override("margin_top", 16)
	top_margin.add_theme_constant_override("margin_bottom", 10)
	add_child(top_margin)

	var top_vbox: VBoxContainer = VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 8)
	top_margin.add_child(top_vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_title_label.add_theme_color_override("font_color", COL_TITLE)
	_title_label.add_theme_font_size_override("font_size", 30)
	if _font_title:
		_title_label.add_theme_font_override("font", _font_title)
	top_vbox.add_child(_title_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.clip_text = true
	_text_label.add_theme_color_override("font_color", COL_TEXT)
	_text_label.add_theme_font_size_override("font_size", 17)
	_text_label.add_theme_constant_override("line_spacing", 6)
	if _font_body:
		_text_label.add_theme_font_override("font", _font_body)
	top_vbox.add_child(_text_label)

	_cursor_label = Label.new()
	_cursor_label.text = "_"
	_cursor_label.add_theme_color_override("font_color", COL_TITLE)
	_cursor_label.add_theme_font_size_override("font_size", 18)
	if _font_body:
		_cursor_label.add_theme_font_override("font", _font_body)
	_cursor_label.visible = false
	top_vbox.add_child(_cursor_label)

	# ── Bottom section: map canvas (70% height) ──────────────────────────
	var map_margin: MarginContainer = MarginContainer.new()
	map_margin.anchor_left = 0.0
	map_margin.anchor_right = 1.0
	map_margin.anchor_top = 0.30
	map_margin.anchor_bottom = 1.0
	map_margin.add_theme_constant_override("margin_left", 15)
	map_margin.add_theme_constant_override("margin_right", 15)
	map_margin.add_theme_constant_override("margin_top", 10)
	map_margin.add_theme_constant_override("margin_bottom", 25)
	add_child(map_margin)

	_map_canvas = Control.new()
	_map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_canvas.draw.connect(_on_map_draw)
	map_margin.add_child(_map_canvas)

	# Skip hint (bottom center).
	_skip_label = Label.new()
	_skip_label.text = "Appuyer pour passer"
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_label.anchor_left = 0.2
	_skip_label.anchor_right = 0.8
	_skip_label.anchor_top = 0.96
	_skip_label.anchor_bottom = 1.0
	_skip_label.add_theme_color_override("font_color", COL_DIM)
	_skip_label.add_theme_font_size_override("font_size", 14)
	if _font_body:
		_skip_label.add_theme_font_override("font", _font_body)
	_skip_label.visible = false
	add_child(_skip_label)

	# Timers.
	_char_timer = Timer.new()
	_char_timer.one_shot = false
	_char_timer.timeout.connect(_on_char_tick)
	add_child(_char_timer)

	_pulse_timer = Timer.new()
	_pulse_timer.one_shot = false
	_pulse_timer.wait_time = PULSE_REDRAW_INTERVAL
	_pulse_timer.timeout.connect(_on_pulse_tick)
	add_child(_pulse_timer)

	_quill_timer = Timer.new()
	_quill_timer.one_shot = false
	_quill_timer.wait_time = QUILL_DELAY
	_quill_timer.timeout.connect(_on_quill_tick)
	add_child(_quill_timer)

	visible = false
