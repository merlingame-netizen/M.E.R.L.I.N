## Scene Screenshot Tool — runs headless, captures each scene after 2s
## Usage: Godot --headless --script res://scripts/tools/screenshot_scenes.gd
## Or run the scene ScreenshotTool.tscn in editor for windowed captures

extends SceneTree

const OUTPUT_DIR = "user://scene_screenshots/"
const WAIT_FRAMES = 120  # ~2 seconds at 60fps

var scenes_to_capture: Array[String] = [
	# Active scenes
	"res://scenes/Menu3DPC.tscn",
	"res://scenes/MerlinGame.tscn",
	"res://scenes/MerlinCabinHub.tscn",
	"res://scenes/BroceliandeForest3D.tscn",
	"res://scenes/ui/MerlinGameUI.tscn",
	"res://scenes/ui/LLMWarmupOverlay.tscn",
	"res://scenes/test/TestCardLayers.tscn",
	# Archive scenes (substantial ones)
	"res://archive/scenes/TestTaniere.tscn",
	"res://archive/scenes/TestJDRMerlin.tscn",
	"res://archive/scenes/TestAntreMerlin.tscn",
	"res://archive/scenes/TestMerlinVoice.tscn",
	"res://archive/scenes/IntroMerlinDialogue.tscn",
	"res://archive/scenes/MerlinTest.tscn",
	"res://archive/scenes/TestLLMScene.tscn",
	"res://archive/scenes/SceneBroceliandeFPS.tscn",
	"res://archive/scenes/TestMerlinGBA.tscn",
	"res://archive/scenes/TestMerlin.tscn",
	"res://archive/scenes/TestAventure.tscn",
	"res://archive/scenes/MenuPrincipal.tscn",
	"res://archive/scenes/GameMain.tscn",
	"res://archive/scenes/TestRobotVoice.tscn",
	# Archive unused (feature-rich ones)
	"res://archive/scenes_unused/MenuOptions.tscn",
	"res://archive/scenes_unused/Collection.tscn",
	"res://archive/scenes_unused/MapMonde.tscn",
	"res://archive/scenes_unused/Calendar.tscn",
	"res://archive/scenes_unused/MenuPrincipal.tscn",
	"res://archive/scenes_unused/SceneRencontreMerlin.tscn",
	"res://archive/scenes_unused/ArbreDeVie.tscn",
	"res://archive/scenes_unused/TransitionBiome.tscn",
	"res://archive/scenes_unused/SelectionSauvegarde.tscn",
]

var _current_index := 0
var _frame_count := 0
var _capturing := false

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

func _process(_delta: float) -> bool:
	if not _capturing:
		if _current_index >= scenes_to_capture.size():
			print("[ScreenshotTool] All done! %d scenes captured." % scenes_to_capture.size())
			print("[ScreenshotTool] Output: %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
			quit()
			return true

		var scene_path = scenes_to_capture[_current_index]
		print("[ScreenshotTool] Loading %d/%d: %s" % [_current_index + 1, scenes_to_capture.size(), scene_path])

		if not ResourceLoader.exists(scene_path):
			print("[ScreenshotTool] SKIP (not found): %s" % scene_path)
			_current_index += 1
			return false

		var packed = load(scene_path) as PackedScene
		if packed == null:
			print("[ScreenshotTool] SKIP (load failed): %s" % scene_path)
			_current_index += 1
			return false

		# Clear current scene
		if current_scene:
			current_scene.queue_free()

		var instance = packed.instantiate()
		root.add_child(instance)
		current_scene = instance
		_frame_count = 0
		_capturing = true
		return false

	_frame_count += 1
	if _frame_count >= WAIT_FRAMES:
		_take_screenshot()
		_capturing = false
		_current_index += 1

	return false

func _take_screenshot() -> void:
	var scene_path = scenes_to_capture[_current_index]
	var filename = scene_path.get_file().get_basename() + ".png"
	# Prefix with folder for disambiguation
	if "scenes_unused" in scene_path:
		filename = "unused_" + filename
	elif "archive" in scene_path:
		filename = "archive_" + filename

	var image = root.get_viewport().get_texture().get_image()
	if image == null:
		print("[ScreenshotTool] WARN: null image for %s" % scene_path)
		return

	var save_path = OUTPUT_DIR + filename
	var err = image.save_png(save_path)
	if err == OK:
		print("[ScreenshotTool] Saved: %s" % save_path)
	else:
		print("[ScreenshotTool] ERROR saving %s: %d" % [save_path, err])
