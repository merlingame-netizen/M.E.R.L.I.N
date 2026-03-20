## Screenshot Runner — Loads a scene, waits for rendering, captures viewport to PNG, quits.
## Usage: godot --path . --rendering-driver opengl3 --resolution 800x600
##        --quit-after 10 res://scenes/ScreenshotRunner.tscn
## Config: reads user://screenshot_config.json for scene_path and output_path.

extends Node

const SETTLE_SECONDS := 5.0
const FALLBACK_OUTPUT := "user://screenshot.png"

var _target_scene_path: String = ""
var _output_path: String = ""


func _ready() -> void:
	var config: Dictionary = _load_config()
	_target_scene_path = str(config.get("scene_path", ""))
	_output_path = str(config.get("output_path", FALLBACK_OUTPUT))

	if _target_scene_path.is_empty():
		printerr("[SCREENSHOT] No scene_path in config")
		get_tree().quit(1)
		return

	print("[SCREENSHOT] Loading: %s" % _target_scene_path)
	print("[SCREENSHOT] Output:  %s" % _output_path)

	var packed: PackedScene = load(_target_scene_path)
	if packed == null:
		printerr("[SCREENSHOT] Cannot load scene: %s" % _target_scene_path)
		get_tree().quit(1)
		return

	var instance: Node = packed.instantiate()
	add_child(instance)

	# Ensure any Camera3D in the scene is active
	await get_tree().process_frame
	var cam: Camera3D = _find_camera(instance)
	if cam:
		cam.make_current()
		print("[SCREENSHOT] Camera found: %s — made current" % cam.get_path())
	else:
		print("[SCREENSHOT] WARNING: No Camera3D found in scene")

	# Wait for scene to settle (animations, shaders, layout)
	await get_tree().create_timer(SETTLE_SECONDS).timeout

	# Capture viewport
	_capture_and_save()


func _capture_and_save() -> void:
	# Wait multiple frames to ensure 3D rendering is flushed to viewport texture
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var viewport: Viewport = get_viewport()
	if viewport == null:
		printerr("[SCREENSHOT] No viewport available")
		_write_result("error", "No viewport")
		get_tree().quit(1)
		return

	var tex: ViewportTexture = viewport.get_texture()
	if tex == null:
		printerr("[SCREENSHOT] Viewport texture is null (headless mode?)")
		_write_result("error", "Null texture — likely headless mode")
		get_tree().quit(1)
		return

	var image: Image = tex.get_image()
	if image == null:
		printerr("[SCREENSHOT] get_image() returned null")
		_write_result("error", "Null image")
		get_tree().quit(1)
		return

	var err: int = image.save_png(_output_path)
	if err != OK:
		printerr("[SCREENSHOT] save_png failed: error %d" % err)
		_write_result("error", "save_png error %d" % err)
		get_tree().quit(1)
		return

	var size_bytes: int = 0
	if FileAccess.file_exists(_output_path):
		var f: FileAccess = FileAccess.open(_output_path, FileAccess.READ)
		if f:
			size_bytes = f.get_length()
			f.close()

	print("[SCREENSHOT] Saved: %s (%d bytes, %dx%d)" % [
		_output_path, size_bytes, image.get_width(), image.get_height()])
	_write_result("ok", "", size_bytes, image.get_width(), image.get_height())
	get_tree().quit(0)


func _load_config() -> Dictionary:
	var config_path: String = "user://screenshot_config.json"
	if not FileAccess.file_exists(config_path):
		printerr("[SCREENSHOT] Config not found: %s" % config_path)
		return {}
	var f: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		printerr("[SCREENSHOT] Invalid JSON in config")
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


func _write_result(status: String, error_msg: String = "",
		size_bytes: int = 0, width: int = 0, height: int = 0) -> void:
	var result: Dictionary = {
		"scene_path": _target_scene_path,
		"output_path": _output_path,
		"status": status,
		"error": error_msg,
		"size_bytes": size_bytes,
		"width": width,
		"height": height,
		"timestamp": Time.get_datetime_string_from_system(),
	}
	var f: FileAccess = FileAccess.open("user://screenshot_result.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(result, "\t"))
		f.close()


func _find_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node as Camera3D
	for child in node.get_children():
		var found: Camera3D = _find_camera(child)
		if found:
			return found
	return null
