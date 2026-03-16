## PixelTransition — Universal pixel-formation scene transition system
## CanvasLayer autoload that intercepts scene changes and animates them as:
##   EXIT:  each UI element independently decomposes into pixels that scatter upward
##   ENTER: each UI element independently assembles from falling pixels
## Elements are discovered by walking the scene tree — each gets its own stagger delay,
## so panels, buttons, labels, sprites all materialize one by one.
## Uses _draw() + PackedFloat32Array for high-performance rendering (9000+ pixels).

extends CanvasLayer

signal transition_started(scene_path: String)
signal exit_complete
signal enter_complete
signal transition_complete(scene_path: String)


# ═══════════════════════════════════════════════════════════════════════════════
# STATE MACHINE
# ═══════════════════════════════════════════════════════════════════════════════

enum State { IDLE, EXITING, BLACK, ENTERING }

var _state: int = State.IDLE
var _target_scene: String = ""
var _profile: Dictionary = {}


# ═══════════════════════════════════════════════════════════════════════════════
# RENDERING NODES
# ═══════════════════════════════════════════════════════════════════════════════

var _canvas: Control
var _bg_rect: ColorRect


# ═══════════════════════════════════════════════════════════════════════════════
# PIXEL GRID DATA (flat arrays — element stagger via _elem_delay)
# ═══════════════════════════════════════════════════════════════════════════════

var _pixel_count: int = 0
var _block_size: float = 10.0

# Color data (per pixel)
var _colors_r: PackedFloat32Array
var _colors_g: PackedFloat32Array
var _colors_b: PackedFloat32Array

# Grid target positions (screen-space)
var _grid_x: PackedFloat32Array
var _grid_y: PackedFloat32Array

# Animation working arrays
var _cur_x: PackedFloat32Array
var _cur_y: PackedFloat32Array
var _cur_a: PackedFloat32Array
var _from_x: PackedFloat32Array
var _from_y: PackedFloat32Array
var _to_x: PackedFloat32Array
var _to_y: PackedFloat32Array
var _delay: PackedFloat32Array       # Total delay = element_delay + pixel_delay

# Per-pixel element tagging
var _elem_id: PackedInt32Array       # Which element this pixel belongs to

# Element data
var _element_count: int = 0
var _element_rects: Array[Rect2] = []   # Screen rects of each element
var _element_centers: Array[Vector2] = [] # Centers for per-element cascade

# Timing
var _elapsed: float = 0.0
var _total_duration: float = 0.8
var _max_delay: float = 0.0
var _input_unlocked: bool = true

# Frame counting for scene load
var _frames_waited: int = 0
var _waiting_for_render: bool = false

# Element stagger config
const ELEMENT_STAGGER := 0.08     # Delay between each element group (seconds)
const MIN_ELEMENT_AREA := 400.0   # Skip elements smaller than this (px^2)


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS

	_bg_rect = ColorRect.new()
	_bg_rect.name = "TransitionBG"
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = MerlinVisual.CRT_PALETTE["transition_bg"]
	_bg_rect.visible = false
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)

	_canvas = Control.new()
	_canvas.name = "TransitionCanvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.visible = false
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_pixels)
	add_child(_canvas)

	get_viewport().size_changed.connect(_on_viewport_resized)


func _process(delta: float) -> void:
	if _waiting_for_render:
		_frames_waited += 1
		if _frames_waited >= 3:
			_waiting_for_render = false
			_capture_and_start_enter()
		return

	match _state:
		State.EXITING:
			_tick_exit(delta)
		State.ENTERING:
			_tick_enter(delta)


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Main API — call instead of get_tree().change_scene_to_file()
func transition_to(scene_path: String, custom_profile: Dictionary = {}) -> void:
	if _state != State.IDLE:
		push_warning("PixelTransition: already transitioning, ignoring %s" % scene_path)
		return
	if scene_path.is_empty():
		push_error("PixelTransition: empty scene_path")
		return

	_target_scene = scene_path
	_profile = PixelTransitionConfig.get_profile(scene_path)
	for key: String in custom_profile:
		_profile[key] = custom_profile[key]

	transition_started.emit(scene_path)

	var skip_exit: bool = _profile.get("skip_exit", false)
	var skip_enter: bool = _profile.get("skip_enter", false)

	if skip_exit and skip_enter:
		get_tree().change_scene_to_file(scene_path)
		transition_complete.emit(scene_path)
		return

	if skip_exit:
		_show_black_screen()
		get_tree().change_scene_to_file(_target_scene)
		if skip_enter:
			_hide_overlay()
			transition_complete.emit(scene_path)
		else:
			_start_waiting_for_render()
		return

	_start_exit()


## Instant scene change with no animation (for debug tools)
func transition_instant(scene_path: String) -> void:
	if _state != State.IDLE:
		_force_complete()
	get_tree().change_scene_to_file(scene_path)


## Returns true if a transition is in progress
func is_transitioning() -> bool:
	return _state != State.IDLE


## Skip current animation immediately
func skip() -> void:
	if _state != State.IDLE:
		_force_complete()


# ═══════════════════════════════════════════════════════════════════════════════
# ELEMENT DISCOVERY — Walk scene tree to find independent UI elements
# ═══════════════════════════════════════════════════════════════════════════════

func _collect_elements_from_scene() -> void:
	_element_rects.clear()
	_element_centers.clear()
	_element_count = 0

	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return

	var vp_rect: Rect2 = get_viewport().get_visible_rect()
	var raw_rects: Array[Rect2] = []

	_walk_tree(scene_root, vp_rect, raw_rects)

	# Sort elements by vertical position then horizontal (top-to-bottom, left-to-right)
	# This gives a natural reading order for stagger
	raw_rects.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		var ay: float = a.position.y + a.size.y * 0.5
		var by: float = b.position.y + b.size.y * 0.5
		if absf(ay - by) > 20.0:
			return ay < by
		return a.position.x < b.position.x
	)

	# Merge overlapping rects to avoid duplicate coverage
	for rect: Rect2 in raw_rects:
		var merged: bool = false
		for ei in range(_element_rects.size()):
			if _element_rects[ei].intersects(rect):
				var overlap: Rect2 = _element_rects[ei].intersection(rect)
				var overlap_area: float = overlap.size.x * overlap.size.y
				var rect_area: float = rect.size.x * rect.size.y
				# Merge if >50% overlapping
				if rect_area > 0.0 and overlap_area / rect_area > 0.5:
					_element_rects[ei] = _element_rects[ei].merge(rect)
					_element_centers[ei] = _element_rects[ei].get_center()
					merged = true
					break
		if not merged:
			_element_rects.append(rect)
			_element_centers.append(rect.get_center())

	_element_count = _element_rects.size()


func _walk_tree(node: Node, vp_rect: Rect2, out_rects: Array[Rect2]) -> void:
	# Skip our own overlay nodes
	if node == _bg_rect or node == _canvas or node is CanvasLayer:
		return

	var is_leaf_element: bool = false

	if node is Control:
		var ctrl: Control = node as Control
		if ctrl.visible and ctrl.modulate.a > 0.1:
			var rect: Rect2 = ctrl.get_global_rect()
			var area: float = rect.size.x * rect.size.y
			# Only include elements with actual visual content and sufficient size
			if area >= MIN_ELEMENT_AREA and vp_rect.intersects(rect):
				# Leaf elements: buttons, labels, textures, panels with style
				if _is_visual_leaf(ctrl):
					# Clip to viewport
					var clipped: Rect2 = vp_rect.intersection(rect)
					if clipped.size.x > 4.0 and clipped.size.y > 4.0:
						out_rects.append(clipped)
						is_leaf_element = true

	if node is Sprite2D:
		var spr: Sprite2D = node as Sprite2D
		if spr.visible and spr.texture:
			var tex_size: Vector2 = spr.texture.get_size() * spr.scale
			var pos: Vector2 = spr.global_position - tex_size * 0.5
			var rect := Rect2(pos, tex_size)
			if rect.size.x * rect.size.y >= MIN_ELEMENT_AREA and vp_rect.intersects(rect):
				out_rects.append(vp_rect.intersection(rect))
				is_leaf_element = true

	# Don't recurse into visual leaves (their children are part of the element)
	if not is_leaf_element:
		for child: Node in node.get_children():
			_walk_tree(child, vp_rect, out_rects)


func _is_visual_leaf(ctrl: Control) -> bool:
	## BLACKLIST approach — any visible Control is a visual element UNLESS it's
	## a pure layout container. This ensures ALL future custom Controls inherit
	## the pixel-transition behavior automatically without manual registration.

	# --- Exclusion: pure layout containers (invisible wrappers) ---
	if ctrl is BoxContainer:      # VBoxContainer, HBoxContainer
		return false
	if ctrl is GridContainer:
		return false
	if ctrl is FlowContainer:     # HFlowContainer, VFlowContainer
		return false
	if ctrl is SplitContainer:    # HSplitContainer, VSplitContainer
		return false
	if ctrl is MarginContainer:
		return false
	if ctrl is CenterContainer:
		return false
	if ctrl is AspectRatioContainer:
		return false
	if ctrl is SubViewportContainer:
		return false
	if ctrl is ScrollContainer:
		return false
	if ctrl is TabContainer:
		# TabContainer itself is a layout wrapper; individual tabs are leaves
		return false

	# --- Exclusion: empty content (skip blank labels, transparent rects) ---
	if ctrl is Label and ctrl.text.length() == 0:
		return false
	if ctrl is RichTextLabel and ctrl.text.length() == 0:
		return false
	if ctrl is TextureRect and ctrl.texture == null:
		return false
	if ctrl is ColorRect and ctrl.color.a < 0.1:
		return false

	# --- Everything else is a visual leaf ---
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SCREEN CAPTURE + PER-ELEMENT PIXEL SAMPLING
# ═══════════════════════════════════════════════════════════════════════════════

func _capture_screen_now() -> Image:
	return get_viewport().get_texture().get_image()


func _sample_pixels_per_element(image: Image, block_sz: int) -> void:
	_block_size = float(block_sz)
	var vp_w: int = image.get_width()
	var vp_h: int = image.get_height()

	var grid_cols: int = ceili(float(vp_w) / _block_size)
	var grid_rows: int = ceili(float(vp_h) / _block_size)
	var max_pixels: int = grid_cols * grid_rows

	# Pre-allocate temporary arrays
	var tmp_r := PackedFloat32Array()
	var tmp_g := PackedFloat32Array()
	var tmp_b := PackedFloat32Array()
	var tmp_gx := PackedFloat32Array()
	var tmp_gy := PackedFloat32Array()
	var tmp_eid := PackedInt32Array()
	tmp_r.resize(max_pixels)
	tmp_g.resize(max_pixels)
	tmp_b.resize(max_pixels)
	tmp_gx.resize(max_pixels)
	tmp_gy.resize(max_pixels)
	tmp_eid.resize(max_pixels)

	var count: int = 0
	var half: float = _block_size * 0.5

	for row in range(grid_rows):
		var py: float = row * _block_size
		var sy: int = mini(int(py + half), vp_h - 1)
		for col in range(grid_cols):
			var px: float = col * _block_size
			var sx: int = mini(int(px + half), vp_w - 1)
			var c: Color = image.get_pixel(sx, sy)
			if c.a < 0.05:
				continue
			if c.r < 0.03 and c.g < 0.03 and c.b < 0.03:
				continue

			# Find which element this pixel belongs to (last match = frontmost)
			var eid: int = -1
			var pixel_center := Vector2(px + half, py + half)
			for ei in range(_element_count - 1, -1, -1):
				if _element_rects[ei].has_point(pixel_center):
					eid = ei
					break

			# Pixels not in any element get element -1 (background)
			# They still animate but with the earliest stagger
			tmp_r[count] = c.r
			tmp_g[count] = c.g
			tmp_b[count] = c.b
			tmp_gx[count] = px
			tmp_gy[count] = py
			tmp_eid[count] = eid
			count += 1

	_pixel_count = count
	_colors_r = tmp_r.slice(0, count)
	_colors_g = tmp_g.slice(0, count)
	_colors_b = tmp_b.slice(0, count)
	_grid_x = tmp_gx.slice(0, count)
	_grid_y = tmp_gy.slice(0, count)
	_elem_id = tmp_eid.slice(0, count)

	# Allocate working arrays
	_cur_x = PackedFloat32Array()
	_cur_y = PackedFloat32Array()
	_cur_a = PackedFloat32Array()
	_from_x = PackedFloat32Array()
	_from_y = PackedFloat32Array()
	_to_x = PackedFloat32Array()
	_to_y = PackedFloat32Array()
	_delay = PackedFloat32Array()
	_cur_x.resize(count)
	_cur_y.resize(count)
	_cur_a.resize(count)
	_from_x.resize(count)
	_from_y.resize(count)
	_to_x.resize(count)
	_to_y.resize(count)
	_delay.resize(count)


# ═══════════════════════════════════════════════════════════════════════════════
# EXIT ANIMATION (each element scatters independently)
# ═══════════════════════════════════════════════════════════════════════════════

func _start_exit() -> void:
	_canvas.visible = false
	_bg_rect.visible = false

	# Collect elements from CURRENT scene before capture
	_collect_elements_from_scene()

	var image: Image = _capture_screen_now()
	var block_sz: int = _profile.get("block_size", 10)
	_sample_pixels_per_element(image, block_sz)

	if _pixel_count == 0:
		_show_black_screen()
		_load_next_scene()
		return

	var scatter_x: float = _profile.get("exit_scatter_x", 60.0)
	var scatter_y_min: float = _profile.get("exit_scatter_y_min", -80.0)
	var scatter_y_max: float = _profile.get("exit_scatter_y_max", -200.0)
	var batch_sz: int = _profile.get("batch_size", 8)
	var batch_delay: float = _profile.get("batch_delay", 0.012)
	_total_duration = _profile.get("exit_duration", 0.6)
	var cascade_mode: String = _profile.get("cascade_mode", "rain")
	var row_stagger: float = _profile.get("row_stagger", 0.005)
	var rain_jitter: float = _profile.get("rain_jitter", 0.012)

	# Viewport height for row-ratio calculation
	var vp_h: float = maxf(float(get_viewport().get_visible_rect().size.y), 1.0)
	var total_rows: float = ceilf(vp_h / _block_size)

	# Legacy element delays (only used in "element_batch" mode)
	var element_delays: PackedFloat32Array = PackedFloat32Array()
	element_delays.resize(maxi(_element_count, 1))
	for ei in range(_element_count):
		element_delays[ei] = float(_element_count - 1 - ei) * ELEMENT_STAGGER

	var elem_pixel_idx: PackedInt32Array = PackedInt32Array()
	elem_pixel_idx.resize(maxi(_element_count + 1, 2))
	elem_pixel_idx.fill(0)

	_max_delay = 0.0
	for i in range(_pixel_count):
		var eid: int = _elem_id[i]
		_from_x[i] = _grid_x[i]
		_from_y[i] = _grid_y[i]
		_to_x[i] = _grid_x[i] + randf_range(-scatter_x, scatter_x)
		_to_y[i] = _grid_y[i] + randf_range(scatter_y_min, scatter_y_max)
		_cur_x[i] = _grid_x[i]
		_cur_y[i] = _grid_y[i]
		_cur_a[i] = 1.0

		var total_d: float = 0.0
		if cascade_mode == "rain":
			# Rain mode: bottom rows scatter first (reverse rain curtain)
			var row_ratio: float = 1.0 - (_grid_y[i] / vp_h)
			total_d = row_ratio * row_stagger * total_rows + randf_range(0.0, rain_jitter)
		else:
			# Legacy element_batch mode
			var elem_base: float = 0.0
			if eid >= 0 and eid < _element_count:
				elem_base = element_delays[eid]
			var safe_eid: int = eid + 1 if eid >= 0 else 0
			if safe_eid >= elem_pixel_idx.size():
				safe_eid = 0
			var pixel_in_elem: int = elem_pixel_idx[safe_eid]
			elem_pixel_idx[safe_eid] = pixel_in_elem + 1
			@warning_ignore("integer_division")
			var pixel_delay: float = float(pixel_in_elem / batch_sz) * batch_delay
			total_d = elem_base + pixel_delay

		_delay[i] = total_d
		if total_d > _max_delay:
			_max_delay = total_d

	_elapsed = 0.0
	_input_unlocked = false
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.visible = true
	_bg_rect.visible = true
	_state = State.EXITING

	var sfx_name: String = _profile.get("sfx_scatter", "")
	if sfx_name != "" and is_instance_valid(SFXManager):
		SFXManager.play(sfx_name)


func _tick_exit(delta: float) -> void:
	_elapsed += delta
	var all_done: bool = true
	var pixel_dur: float = _total_duration * 0.5

	for i in range(_pixel_count):
		var t: float = (_elapsed - _delay[i]) / pixel_dur
		if t < 0.0:
			all_done = false
			continue
		if t >= 1.0:
			_cur_x[i] = _to_x[i]
			_cur_y[i] = _to_y[i]
			_cur_a[i] = 0.0
			continue
		all_done = false
		var e: float = _ease_quad_out(t)
		_cur_x[i] = lerpf(_from_x[i], _to_x[i], e)
		_cur_y[i] = lerpf(_from_y[i], _to_y[i], e)
		_cur_a[i] = 1.0 - t

	_canvas.queue_redraw()

	if all_done or _elapsed >= (_total_duration + _max_delay + 0.2):
		exit_complete.emit()
		_show_black_screen()
		_load_next_scene()


# ═══════════════════════════════════════════════════════════════════════════════
# SCENE LOADING
# ═══════════════════════════════════════════════════════════════════════════════

func _show_black_screen() -> void:
	_bg_rect.color = _profile.get("bg_color", MerlinVisual.CRT_PALETTE["transition_bg"])
	_bg_rect.visible = true
	_canvas.visible = false
	_state = State.BLACK


func _load_next_scene() -> void:
	_state = State.BLACK
	get_tree().change_scene_to_file(_target_scene)

	var skip_enter: bool = _profile.get("skip_enter", false)
	if skip_enter:
		_hide_overlay()
		transition_complete.emit(_target_scene)
		return

	_start_waiting_for_render()


func _start_waiting_for_render() -> void:
	_frames_waited = 0
	_waiting_for_render = true


func _capture_and_start_enter() -> void:
	_canvas.visible = false
	_bg_rect.visible = false

	await get_tree().process_frame

	# Collect elements from NEW scene
	_collect_elements_from_scene()

	var image: Image = _capture_screen_now()
	var block_sz: int = _profile.get("block_size", 10)
	_sample_pixels_per_element(image, block_sz)

	if _pixel_count == 0:
		await get_tree().process_frame
		await get_tree().process_frame
		_collect_elements_from_scene()
		image = _capture_screen_now()
		_sample_pixels_per_element(image, block_sz)

	if _pixel_count == 0:
		_hide_overlay()
		transition_complete.emit(_target_scene)
		return

	_start_enter()


# ═══════════════════════════════════════════════════════════════════════════════
# ENTER ANIMATION (each element assembles independently)
# ═══════════════════════════════════════════════════════════════════════════════

func _start_enter() -> void:
	var spawn_x: float = _profile.get("enter_spawn_x", 40.0)
	var spawn_y_min: float = _profile.get("enter_spawn_y_min", -60.0)
	var spawn_y_max: float = _profile.get("enter_spawn_y_max", -180.0)
	var batch_sz: int = _profile.get("batch_size", 8)
	var batch_delay: float = _profile.get("batch_delay", 0.012)
	_total_duration = _profile.get("enter_duration", 0.8)
	var cascade_mode: String = _profile.get("cascade_mode", "rain")
	var row_stagger: float = _profile.get("row_stagger", 0.005)
	var rain_jitter: float = _profile.get("rain_jitter", 0.012)

	# Viewport height for row-ratio calculation
	var vp_h: float = maxf(float(get_viewport().get_visible_rect().size.y), 1.0)
	var total_rows: float = ceilf(vp_h / _block_size)

	# Legacy element delays (only used in "element_batch" mode)
	var element_delays: PackedFloat32Array = PackedFloat32Array()
	element_delays.resize(maxi(_element_count, 1))
	for ei in range(_element_count):
		element_delays[ei] = float(ei + 1) * ELEMENT_STAGGER

	var elem_pixel_idx: PackedInt32Array = PackedInt32Array()
	elem_pixel_idx.resize(maxi(_element_count + 1, 2))
	elem_pixel_idx.fill(0)

	_max_delay = 0.0
	for i in range(_pixel_count):
		var eid: int = _elem_id[i]

		# Spawn from above with scatter
		_from_x[i] = _grid_x[i] + randf_range(-spawn_x, spawn_x)
		_from_y[i] = _grid_y[i] + randf_range(spawn_y_min, spawn_y_max)
		_to_x[i] = _grid_x[i]
		_to_y[i] = _grid_y[i]
		_cur_x[i] = _from_x[i]
		_cur_y[i] = _from_y[i]
		_cur_a[i] = 0.0

		var total_d: float = 0.0
		if cascade_mode == "rain":
			# Rain mode: top rows arrive first (progressive curtain from top)
			var row_ratio: float = _grid_y[i] / vp_h
			total_d = row_ratio * row_stagger * total_rows + randf_range(0.0, rain_jitter)
		else:
			# Legacy element_batch mode
			var elem_base: float = 0.0
			if eid >= 0 and eid < _element_count:
				elem_base = element_delays[eid]
			var safe_eid: int = eid + 1 if eid >= 0 else 0
			if safe_eid >= elem_pixel_idx.size():
				safe_eid = 0
			var pixel_in_elem: int = elem_pixel_idx[safe_eid]
			elem_pixel_idx[safe_eid] = pixel_in_elem + 1
			@warning_ignore("integer_division")
			var pixel_delay: float = float(pixel_in_elem / batch_sz) * batch_delay
			total_d = elem_base + pixel_delay

		_delay[i] = total_d
		if total_d > _max_delay:
			_max_delay = total_d

	_elapsed = 0.0
	_input_unlocked = false
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg_rect.visible = true
	_canvas.visible = true
	_state = State.ENTERING

	var sfx_name: String = _profile.get("sfx_assemble", "")
	if sfx_name != "" and is_instance_valid(SFXManager):
		SFXManager.play(sfx_name)


func _tick_enter(delta: float) -> void:
	_elapsed += delta
	var all_done: bool = true
	var pixel_dur: float = _total_duration * 0.5
	var unlock_at: float = _profile.get("input_unlock_progress", 0.7)

	var completed_count: int = 0
	for i in range(_pixel_count):
		var t: float = (_elapsed - _delay[i]) / pixel_dur
		if t < 0.0:
			all_done = false
			continue
		if t >= 1.0:
			_cur_x[i] = _to_x[i]
			_cur_y[i] = _to_y[i]
			_cur_a[i] = 1.0
			completed_count += 1
			continue
		all_done = false
		var e: float = _ease_back_out(t)
		_cur_x[i] = lerpf(_from_x[i], _to_x[i], e)
		_cur_y[i] = lerpf(_from_y[i], _to_y[i], e)
		_cur_a[i] = minf(t / 0.15, 1.0)

	if not _input_unlocked and _pixel_count > 0:
		var progress: float = float(completed_count) / float(_pixel_count)
		if progress >= unlock_at:
			_input_unlocked = true
			_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_canvas.queue_redraw()

	if all_done or _elapsed >= (_total_duration + _max_delay + 0.2):
		_finish_enter()


func _finish_enter() -> void:
	enter_complete.emit()
	_hide_overlay()
	transition_complete.emit(_target_scene)


# ═══════════════════════════════════════════════════════════════════════════════
# DRAWING
# ═══════════════════════════════════════════════════════════════════════════════

func _draw_pixels() -> void:
	var bs: float = _block_size
	for i in range(_pixel_count):
		var a: float = _cur_a[i]
		if a < 0.01:
			continue
		var c := Color(_colors_r[i], _colors_g[i], _colors_b[i], a)
		_canvas.draw_rect(Rect2(_cur_x[i], _cur_y[i], bs, bs), c)


# ═══════════════════════════════════════════════════════════════════════════════
# EASING FUNCTIONS (from pixel_merlin_portrait.gd)
# ═══════════════════════════════════════════════════════════════════════════════

static func _ease_back_out(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)


static func _ease_quad_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY
# ═══════════════════════════════════════════════════════════════════════════════

func _hide_overlay() -> void:
	_canvas.visible = false
	_bg_rect.visible = false
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_input_unlocked = true
	_state = State.IDLE
	_cleanup()


func _force_complete() -> void:
	_waiting_for_render = false
	_hide_overlay()
	if _target_scene != "" and _state != State.IDLE:
		transition_complete.emit(_target_scene)


func _cleanup() -> void:
	_colors_r = PackedFloat32Array()
	_colors_g = PackedFloat32Array()
	_colors_b = PackedFloat32Array()
	_grid_x = PackedFloat32Array()
	_grid_y = PackedFloat32Array()
	_cur_x = PackedFloat32Array()
	_cur_y = PackedFloat32Array()
	_cur_a = PackedFloat32Array()
	_from_x = PackedFloat32Array()
	_from_y = PackedFloat32Array()
	_to_x = PackedFloat32Array()
	_to_y = PackedFloat32Array()
	_delay = PackedFloat32Array()
	_elem_id = PackedInt32Array()
	_element_rects.clear()
	_element_centers.clear()
	_element_count = 0
	_pixel_count = 0
	_canvas.queue_redraw()


func _on_viewport_resized() -> void:
	if _state != State.IDLE:
		_force_complete()


func _unhandled_input(event: InputEvent) -> void:
	if _state == State.ENTERING and event is InputEventMouseButton:
		if event.pressed:
			_force_complete()
			get_viewport().set_input_as_handled()
