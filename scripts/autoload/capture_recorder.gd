extends Node
## CaptureRecorder — Periodic viewport screenshots (autoload, env-gated).
##
## Activation:
##   MERLIN_CAPTURE_DIR=/abs/path/  godot --path . scene.tscn --quit-after 30
##
## Optional env vars:
##   MERLIN_CAPTURE_INTERVAL_MS  (default 200)
##   MERLIN_CAPTURE_MAX_FRAMES   (default 200)
##
## Saves frame_0000.png, frame_0001.png, … to MERLIN_CAPTURE_DIR.
## When the env var is empty, this autoload disables itself and does nothing.

var _enabled: bool = false
var _out_dir: String = ""
var _interval_ms: int = 200
var _max_frames: int = 200
var _frame_count: int = 0
var _accum_ms: int = 0
var _last_tick_ms: int = 0


func _ready() -> void:
	set_process(false)  # Timer drives capture, not _process
	_out_dir = OS.get_environment("MERLIN_CAPTURE_DIR")
	if _out_dir.is_empty():
		return
	# Read optional knobs
	var interval_env: String = OS.get_environment("MERLIN_CAPTURE_INTERVAL_MS")
	if not interval_env.is_empty() and interval_env.is_valid_int():
		_interval_ms = max(50, int(interval_env))
	var max_env: String = OS.get_environment("MERLIN_CAPTURE_MAX_FRAMES")
	if not max_env.is_empty() and max_env.is_valid_int():
		_max_frames = max(1, int(max_env))
	# Ensure output dir exists
	if not DirAccess.dir_exists_absolute(_out_dir):
		var err := DirAccess.make_dir_recursive_absolute(_out_dir)
		if err != OK:
			push_warning("[CaptureRecorder] Cannot create dir '%s' err=%d — disabled" % [_out_dir, err])
			return
	_enabled = true
	_last_tick_ms = Time.get_ticks_msec()
	# Timer-driven capture: independent of frame rate / scene _process.
	var t: Timer = Timer.new()
	t.name = "CaptureTimer"
	t.wait_time = float(_interval_ms) / 1000.0
	t.one_shot = false
	t.autostart = true
	t.process_callback = Timer.TIMER_PROCESS_IDLE
	add_child(t)
	t.timeout.connect(_on_capture_tick)
	print("[CaptureRecorder] active dir=%s interval=%dms max=%d (Timer-driven)" % [_out_dir, _interval_ms, _max_frames])


func _on_capture_tick() -> void:
	print("[CaptureRecorder] TICK at %dms (count=%d)" % [Time.get_ticks_msec(), _frame_count])
	if not _enabled:
		return
	if _frame_count >= _max_frames:
		_enabled = false
		print("[CaptureRecorder] max frames reached (%d) — stopped at %dms" % [_max_frames, Time.get_ticks_msec()])
		return
	_capture_frame()


# _process is disabled — Timer drives capture, see _on_capture_tick.


func _capture_frame() -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var tex: ViewportTexture = vp.get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	# Downscale aggressively to keep disk + token cost manageable for visual review.
	if img.get_width() > 480:
		var ratio: float = 480.0 / float(img.get_width())
		img.resize(480, int(float(img.get_height()) * ratio), Image.INTERPOLATE_BILINEAR)
	var fname: String = "%s/frame_%04d.png" % [_out_dir, _frame_count]
	var save_err: Error = img.save_png(fname)
	if save_err != OK:
		push_warning("[CaptureRecorder] save_png failed err=%d at %s" % [save_err, fname])
	_frame_count += 1
