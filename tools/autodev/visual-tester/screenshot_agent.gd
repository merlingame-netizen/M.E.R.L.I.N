## ScreenshotAgent — Automated Screenshot Capture (Autoload for testing)
## Captures viewport screenshots at regular intervals for visual QA.
## Activated via command line: godot --path . -s tools/autodev/visual-tester/screenshot_agent.gd
## Or added as autoload during test sessions.
extends Node

const OUTPUT_DIR := "res://scene_screenshots/"
const CAPTURE_INTERVAL := 2.0  # seconds between captures
const MAX_SCREENSHOTS := 20  # max per session
const METADATA_FILE := "res://scene_screenshots/session_meta.json"

var _timer: float = 0.0
var _capture_count: int = 0
var _session_id: String = ""
var _scene_name: String = ""
var _screenshots: Array = []
var _start_time: float = 0.0


func _ready() -> void:
	_session_id = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	_scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename() if get_tree().current_scene else "unknown"
	_start_time = Time.get_ticks_msec() / 1000.0

	# Ensure output directory exists
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	# Take initial screenshot after scene is fully loaded
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_screenshot("initial")


func _process(delta: float) -> void:
	if _capture_count >= MAX_SCREENSHOTS:
		return
	_timer += delta
	if _timer >= CAPTURE_INTERVAL:
		_timer = 0.0
		_capture_screenshot("auto_%02d" % _capture_count)


func _capture_screenshot(label: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		push_warning("[ScreenshotAgent] Failed to capture viewport")
		return

	var filename: String = "%s_%s_%s.png" % [_scene_name, _session_id, label]
	var filepath: String = OUTPUT_DIR + filename
	var err: Error = image.save_png(filepath)

	if err != OK:
		push_warning("[ScreenshotAgent] Failed to save: %s (error %d)" % [filepath, err])
		return

	_capture_count += 1
	var entry: Dictionary = {
		"filename": filename,
		"label": label,
		"timestamp": Time.get_datetime_string_from_system(),
		"elapsed_seconds": (Time.get_ticks_msec() / 1000.0) - _start_time,
		"viewport_size": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"scene": _scene_name,
	}
	_screenshots.append(entry)

	# Write metadata after each capture
	_write_metadata()


func _write_metadata() -> void:
	var meta: Dictionary = {
		"session_id": _session_id,
		"scene": _scene_name,
		"started_at": Time.get_datetime_string_from_system(),
		"screenshot_count": _capture_count,
		"screenshots": _screenshots,
	}
	var file := FileAccess.open(METADATA_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(meta, "  "))
