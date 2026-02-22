## PixelContentAnimator — Intra-scene pixel rain animations for Controls
## Captures a Control's visual via SubViewport, decomposes into blocks,
## and animates them as falling/rising pixel rain.
## Uses _draw() + PackedFloat32Array for high-performance rendering.

extends Node

signal animation_complete(target: Control, mode: String)


# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

const DEFAULT_CONFIG := {
	"block_size": 8,
	"duration": 0.35,
	"row_stagger": 0.004,
	"jitter": 0.01,
	"scatter_x": 20.0,
	"scatter_y_min": -30.0,
	"scatter_y_max": -80.0,
	"easing": "back_out",
	"inter_delay": 0.08,
	"sfx": "",
}

enum Mode { REVEAL, DISSOLVE }


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATION JOB
# ═══════════════════════════════════════════════════════════════════════════════

class AnimJob extends RefCounted:
	var target: Control
	var canvas: Control
	var mode: int
	var pixel_count: int = 0
	var block_size: float = 8.0

	# Color data
	var colors_r: PackedFloat32Array
	var colors_g: PackedFloat32Array
	var colors_b: PackedFloat32Array

	# Grid positions (local to canvas)
	var grid_x: PackedFloat32Array
	var grid_y: PackedFloat32Array

	# Animation working arrays
	var cur_x: PackedFloat32Array
	var cur_y: PackedFloat32Array
	var cur_a: PackedFloat32Array
	var from_x: PackedFloat32Array
	var from_y: PackedFloat32Array
	var to_x: PackedFloat32Array
	var to_y: PackedFloat32Array
	var delay: PackedFloat32Array

	# Timing
	var elapsed: float = 0.0
	var total_duration: float = 0.35
	var pixel_dur: float = 0.2
	var max_delay: float = 0.0
	var easing_fn: String = "back_out"
	var completed: bool = false

	func resize(count: int) -> void:
		pixel_count = count
		colors_r.resize(count)
		colors_g.resize(count)
		colors_b.resize(count)
		grid_x.resize(count)
		grid_y.resize(count)
		cur_x.resize(count)
		cur_y.resize(count)
		cur_a.resize(count)
		from_x.resize(count)
		from_y.resize(count)
		to_x.resize(count)
		to_y.resize(count)
		delay.resize(count)


# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _active_jobs: Dictionary = {}  # int (instance_id) -> AnimJob


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _active_jobs.is_empty():
		return

	var finished_ids: Array[int] = []
	for id: int in _active_jobs:
		var job: AnimJob = _active_jobs[id]
		if not is_instance_valid(job.target) or not is_instance_valid(job.canvas):
			finished_ids.append(id)
			continue

		_tick_job(job, delta)

		if job.completed:
			finished_ids.append(id)

	for id: int in finished_ids:
		_finish_job(id)


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Reveal: pixels rain from above to form the content of target.
## Target should start hidden (modulate.a = 0) or will be hidden automatically.
func reveal(target: Control, config: Dictionary = {}) -> void:
	if not _validate_target(target):
		return
	cancel(target)
	_start_animation(target, Mode.REVEAL, config)


## Dissolve: pixels scatter upward from the target, leaving it hidden.
func dissolve(target: Control, config: Dictionary = {}) -> void:
	if not _validate_target(target):
		return
	cancel(target)
	_start_animation(target, Mode.DISSOLVE, config)


## Swap: dissolve current content, call update_fn, then reveal new content.
func swap(target: Control, update_fn: Callable, config: Dictionary = {}) -> void:
	if not _validate_target(target):
		return
	cancel(target)

	# Dissolve first
	_start_animation(target, Mode.DISSOLVE, config)
	var tid: int = target.get_instance_id()

	# Wait for dissolve to complete, then update and reveal
	await animation_complete
	if not is_instance_valid(target):
		return
	update_fn.call()
	await get_tree().process_frame
	_start_animation(target, Mode.REVEAL, config)


## Batch reveal with stagger between targets.
func reveal_group(targets: Array[Control], config: Dictionary = {}) -> void:
	var inter_delay: float = _get_config(config, "inter_delay")
	for i in range(targets.size()):
		var t: Control = targets[i]
		if not is_instance_valid(t) or not t.is_inside_tree():
			continue
		if i > 0 and inter_delay > 0.0:
			await get_tree().create_timer(inter_delay).timeout
		reveal(t, config)


## Batch dissolve with stagger between targets.
func dissolve_group(targets: Array[Control], config: Dictionary = {}) -> void:
	var inter_delay: float = _get_config(config, "inter_delay")
	for i in range(targets.size()):
		var t: Control = targets[i]
		if not is_instance_valid(t) or not t.is_inside_tree():
			continue
		if i > 0 and inter_delay > 0.0:
			await get_tree().create_timer(inter_delay).timeout
		dissolve(t, config)


## Cancel animation on a specific target.
func cancel(target: Control) -> void:
	if not is_instance_valid(target):
		return
	var tid: int = target.get_instance_id()
	if _active_jobs.has(tid):
		_cleanup_job(tid)


## Cancel all running animations.
func cancel_all() -> void:
	var ids: Array = _active_jobs.keys().duplicate()
	for id: int in ids:
		_cleanup_job(id)


## Check if target is currently animating.
func is_animating(target: Control) -> bool:
	if not is_instance_valid(target):
		return false
	return _active_jobs.has(target.get_instance_id())


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATION CORE
# ═══════════════════════════════════════════════════════════════════════════════

func _start_animation(target: Control, mode: int, config: Dictionary) -> void:
	var block_size: float = _get_config(config, "block_size")
	var duration: float = _get_config(config, "duration")
	var row_stagger: float = _get_config(config, "row_stagger")
	var jitter: float = _get_config(config, "jitter")
	var scatter_x: float = _get_config(config, "scatter_x")
	var scatter_y_min: float = _get_config(config, "scatter_y_min")
	var scatter_y_max: float = _get_config(config, "scatter_y_max")
	var easing: String = _get_config(config, "easing")
	var sfx_name: String = _get_config(config, "sfx")

	# Capture the target's visual
	var image: Image = await _capture_control(target, mode)
	if image == null or not is_instance_valid(target):
		# Capture failed — just toggle visibility
		if is_instance_valid(target):
			target.modulate.a = 1.0 if mode == Mode.REVEAL else 0.0
		return

	# Sample blocks from image
	var job := AnimJob.new()
	job.target = target
	job.mode = mode
	job.block_size = block_size
	job.total_duration = duration
	job.pixel_dur = duration * 0.6
	job.easing_fn = easing

	_sample_blocks(image, job, block_size)

	if job.pixel_count == 0:
		target.modulate.a = 1.0 if mode == Mode.REVEAL else 0.0
		animation_complete.emit(target, "reveal" if mode == Mode.REVEAL else "dissolve")
		return

	# Create canvas overlay as sibling
	var canvas := Control.new()
	canvas.name = "_PixelAnim_%d" % target.get_instance_id()
	canvas.position = target.position
	canvas.size = target.size
	canvas.z_index = target.z_index + 1
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.clip_contents = false
	job.canvas = canvas

	# Connect draw callback
	canvas.draw.connect(func(): _draw_job(job))

	# Add canvas to same parent
	var parent: Node = target.get_parent()
	if parent:
		parent.add_child(canvas)
		# Move canvas right after target for correct z-order
		parent.move_child(canvas, target.get_index() + 1)

	# Hide original target
	target.modulate.a = 0.0

	# Compute animation trajectories
	var target_h: float = maxf(target.size.y, 1.0)
	var total_rows: float = ceilf(target_h / block_size)
	job.max_delay = 0.0

	for i in range(job.pixel_count):
		var gx: float = job.grid_x[i]
		var gy: float = job.grid_y[i]

		if mode == Mode.REVEAL:
			# Spawn from above, fall to grid position
			job.from_x[i] = gx + randf_range(-scatter_x, scatter_x)
			job.from_y[i] = gy + randf_range(scatter_y_min, scatter_y_max)
			job.to_x[i] = gx
			job.to_y[i] = gy
			job.cur_x[i] = job.from_x[i]
			job.cur_y[i] = job.from_y[i]
			job.cur_a[i] = 0.0
			# Top rows arrive first
			var row_ratio: float = gy / target_h
			job.delay[i] = row_ratio * row_stagger * total_rows + randf_range(0.0, jitter)
		else:
			# Start at grid position, scatter upward
			job.from_x[i] = gx
			job.from_y[i] = gy
			job.to_x[i] = gx + randf_range(-scatter_x, scatter_x)
			job.to_y[i] = gy + randf_range(scatter_y_min, scatter_y_max)
			job.cur_x[i] = gx
			job.cur_y[i] = gy
			job.cur_a[i] = 1.0
			# Bottom rows scatter first (reverse rain)
			var row_ratio: float = 1.0 - (gy / target_h)
			job.delay[i] = row_ratio * row_stagger * total_rows + randf_range(0.0, jitter)

		if job.delay[i] > job.max_delay:
			job.max_delay = job.delay[i]

	job.elapsed = 0.0
	job.completed = false

	var tid: int = target.get_instance_id()
	_active_jobs[tid] = job

	# Play SFX
	if sfx_name != "":
		var sfx_mgr: Node = get_node_or_null("/root/SFXManager")
		if sfx_mgr:
			sfx_mgr.play(sfx_name)

	canvas.queue_redraw()


func _tick_job(job: AnimJob, delta: float) -> void:
	job.elapsed += delta
	var all_done: bool = true

	for i in range(job.pixel_count):
		var t: float = (job.elapsed - job.delay[i]) / job.pixel_dur
		if t < 0.0:
			all_done = false
			continue
		if t >= 1.0:
			job.cur_x[i] = job.to_x[i]
			job.cur_y[i] = job.to_y[i]
			job.cur_a[i] = 1.0 if job.mode == Mode.REVEAL else 0.0
			continue

		all_done = false
		var e: float = _apply_easing(t, job.easing_fn)
		job.cur_x[i] = lerpf(job.from_x[i], job.to_x[i], e)
		job.cur_y[i] = lerpf(job.from_y[i], job.to_y[i], e)

		if job.mode == Mode.REVEAL:
			job.cur_a[i] = minf(t / 0.15, 1.0)
		else:
			job.cur_a[i] = 1.0 - t

	if is_instance_valid(job.canvas):
		job.canvas.queue_redraw()

	if all_done or job.elapsed >= (job.total_duration + job.max_delay + 0.1):
		job.completed = true


func _draw_job(job: AnimJob) -> void:
	var bs: float = job.block_size
	var canvas: Control = job.canvas
	if not is_instance_valid(canvas):
		return

	for i in range(job.pixel_count):
		var a: float = job.cur_a[i]
		if a < 0.01:
			continue
		var c := Color(job.colors_r[i], job.colors_g[i], job.colors_b[i], a)
		canvas.draw_rect(Rect2(job.cur_x[i], job.cur_y[i], bs, bs), c)


# ═══════════════════════════════════════════════════════════════════════════════
# CAPTURE
# ═══════════════════════════════════════════════════════════════════════════════

func _capture_control(target: Control, mode: int) -> Image:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return null

	var target_size: Vector2i = Vector2i(ceili(target.size.x), ceili(target.size.y))
	if target_size.x < 2 or target_size.y < 2:
		return null

	# For dissolve, target is visible — capture directly
	# For reveal, target may be hidden — temporarily make clone visible
	var svp := SubViewport.new()
	svp.size = target_size
	svp.transparent_bg = true
	svp.render_target_update_mode = SubViewport.UPDATE_ONCE
	svp.gui_disable_input = true

	# Duplicate the target for clean capture
	var clone: Control = target.duplicate()
	clone.position = Vector2.ZERO
	clone.modulate = Color.WHITE
	clone.visible = true
	svp.add_child(clone)

	add_child(svp)
	await RenderingServer.frame_post_draw

	var image: Image = null
	if is_instance_valid(svp):
		var tex: ViewportTexture = svp.get_texture()
		if tex:
			image = tex.get_image()
		svp.queue_free()

	return image


# ═══════════════════════════════════════════════════════════════════════════════
# BLOCK SAMPLING
# ═══════════════════════════════════════════════════════════════════════════════

func _sample_blocks(image: Image, job: AnimJob, block_size: float) -> void:
	var img_w: int = image.get_width()
	var img_h: int = image.get_height()
	var bs: int = maxi(int(block_size), 2)
	var cols: int = ceili(float(img_w) / float(bs))
	var rows: int = ceili(float(img_h) / float(bs))
	var max_count: int = cols * rows

	# Temporary collection arrays
	var tmp_r := PackedFloat32Array()
	var tmp_g := PackedFloat32Array()
	var tmp_b := PackedFloat32Array()
	var tmp_gx := PackedFloat32Array()
	var tmp_gy := PackedFloat32Array()
	tmp_r.resize(max_count)
	tmp_g.resize(max_count)
	tmp_b.resize(max_count)
	tmp_gx.resize(max_count)
	tmp_gy.resize(max_count)

	var count: int = 0
	for row in range(rows):
		for col in range(cols):
			# Sample center pixel of block
			var sx: int = mini(col * bs + bs / 2, img_w - 1)
			var sy: int = mini(row * bs + bs / 2, img_h - 1)
			var pixel: Color = image.get_pixel(sx, sy)

			# Skip transparent or near-black transparent pixels
			if pixel.a < 0.1:
				continue

			tmp_r[count] = pixel.r
			tmp_g[count] = pixel.g
			tmp_b[count] = pixel.b
			tmp_gx[count] = float(col * bs)
			tmp_gy[count] = float(row * bs)
			count += 1

	# Resize job arrays to actual count
	job.resize(count)
	for i in range(count):
		job.colors_r[i] = tmp_r[i]
		job.colors_g[i] = tmp_g[i]
		job.colors_b[i] = tmp_b[i]
		job.grid_x[i] = tmp_gx[i]
		job.grid_y[i] = tmp_gy[i]


# ═══════════════════════════════════════════════════════════════════════════════
# EASING
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_easing(t: float, fn_name: String) -> float:
	match fn_name:
		"back_out":
			return _ease_back_out(t)
		"quad_out":
			return _ease_quad_out(t)
		"cubic_out":
			return _ease_cubic_out(t)
		_:
			return _ease_back_out(t)


func _ease_back_out(t: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	var tm: float = t - 1.0
	return 1.0 + c3 * tm * tm * tm + c1 * tm * tm


func _ease_quad_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


func _ease_cubic_out(t: float) -> float:
	var tm: float = 1.0 - t
	return 1.0 - tm * tm * tm


# ═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
# ═══════════════════════════════════════════════════════════════════════════════

func _finish_job(id: int) -> void:
	if not _active_jobs.has(id):
		return

	var job: AnimJob = _active_jobs[id]
	var target: Control = job.target
	var mode_name: String = "reveal" if job.mode == Mode.REVEAL else "dissolve"

	# Restore target visibility
	if is_instance_valid(target):
		target.modulate.a = 1.0 if job.mode == Mode.REVEAL else 0.0

	# Remove canvas
	if is_instance_valid(job.canvas):
		job.canvas.queue_free()

	_active_jobs.erase(id)
	animation_complete.emit(target, mode_name)


func _cleanup_job(id: int) -> void:
	if not _active_jobs.has(id):
		return

	var job: AnimJob = _active_jobs[id]

	# Restore target (show for reveal, keep hidden for dissolve)
	if is_instance_valid(job.target):
		if job.mode == Mode.REVEAL:
			job.target.modulate.a = 1.0
		# For dissolve cancel, keep current alpha (don't force hidden)

	if is_instance_valid(job.canvas):
		job.canvas.queue_free()

	_active_jobs.erase(id)


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _validate_target(target: Control) -> bool:
	if not is_instance_valid(target):
		push_warning("PixelContentAnimator: target is not valid")
		return false
	if not target.is_inside_tree():
		push_warning("PixelContentAnimator: target not in tree")
		return false
	if target.size.x < 4.0 or target.size.y < 4.0:
		push_warning("PixelContentAnimator: target too small (%s)" % str(target.size))
		return false
	return true


func _get_config(config: Dictionary, key: String) -> Variant:
	if config.has(key):
		return config[key]
	return DEFAULT_CONFIG[key]


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		cancel_all()
