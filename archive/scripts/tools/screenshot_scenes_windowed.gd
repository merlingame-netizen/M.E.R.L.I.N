extends Node
## Windowed Scene Screenshot Tool
## Run this scene (F6 in editor) — it cycles through all scenes,
## waits 2s each for rendering, captures a PNG, then moves on.
## Output: C:/Users/PGNK2128/Godot-MCP/scene_screenshots/

const OUTPUT_DIR := "C:/Users/PGNK2128/Godot-MCP/scene_screenshots/"
const WAIT_SEC := 2.5

var scenes_to_capture: Array[String] = [
	# ── Active scenes ──
	"res://scenes/Menu3DPC.tscn",
	"res://scenes/MerlinGame.tscn",
	"res://scenes/MerlinCabinHub.tscn",
	"res://scenes/BroceliandeForest3D.tscn",
	"res://scenes/ui/MerlinGameUI.tscn",
	"res://scenes/ui/LLMWarmupOverlay.tscn",
	"res://scenes/test/TestCardLayers.tscn",
	# ── Archive (substantial) ──
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
	# ── Archive unused (feature-rich) ──
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

var _index := 0
var _child: Node = null
var _timer: float = 0.0
var _state := "loading"  # loading | waiting | capturing

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	print("=== SCENE SCREENSHOT TOOL ===")
	print("Output: %s" % OUTPUT_DIR)
	print("Scenes: %d" % scenes_to_capture.size())
	print("=============================")
	_load_next()

func _process(delta: float) -> void:
	if _state == "waiting":
		_timer += delta
		if _timer >= WAIT_SEC:
			_state = "capturing"
			_capture()
			_index += 1
			if _index < scenes_to_capture.size():
				_load_next()
			else:
				print("\n=== ALL DONE ===")
				print("Screenshots saved to: %s" % OUTPUT_DIR)
				print("Run scene-viewer-godot.html to browse them.")
				get_tree().quit()

func _load_next() -> void:
	# Remove previous scene
	if _child:
		_child.queue_free()
		_child = null
	# Wait one frame for cleanup
	await get_tree().process_frame

	var path := scenes_to_capture[_index]
	print("[%d/%d] %s" % [_index + 1, scenes_to_capture.size(), path])

	if not ResourceLoader.exists(path):
		print("  SKIP: file not found")
		_index += 1
		if _index < scenes_to_capture.size():
			_load_next()
		else:
			get_tree().quit()
		return

	var packed := load(path) as PackedScene
	if packed == null:
		print("  SKIP: load error")
		_index += 1
		if _index < scenes_to_capture.size():
			_load_next()
		else:
			get_tree().quit()
		return

	_child = packed.instantiate()
	add_child(_child)
	_timer = 0.0
	_state = "waiting"

func _capture() -> void:
	var path := scenes_to_capture[_index]
	var filename := _safe_filename(path)
	var image := get_viewport().get_texture().get_image()
	if image == null:
		print("  WARN: null image")
		return
	var save_path := OUTPUT_DIR + filename
	var err := image.save_png(save_path)
	if err == OK:
		print("  -> %s" % filename)
	else:
		print("  ERROR: save failed (%d)" % err)

func _safe_filename(scene_path: String) -> String:
	var base := scene_path.get_file().get_basename()
	if "scenes_unused" in scene_path:
		return "unused_" + base + ".png"
	elif "archive" in scene_path:
		return "archive_" + base + ".png"
	return base + ".png"
