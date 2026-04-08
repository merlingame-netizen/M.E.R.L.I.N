extends Node
## Single-scene screenshot: Menu3DPC only
## Captures after 4s wait (boot sequence needs time)

const OUTPUT_PATH := "C:/Users/PGNK2128/Godot-MCP/tools/autodev/captures/menu_n64_current.png"
const WAIT_SEC := 4.0

var _child: Node = null
var _timer: float = 0.0
var _done := false

func _ready() -> void:
	print("=== MENU SCREENSHOT CAPTURE ===")
	var packed := load("res://scenes/Menu3DPC.tscn") as PackedScene
	if packed == null:
		print("ERROR: Cannot load Menu3DPC.tscn")
		get_tree().quit()
		return
	_child = packed.instantiate()
	add_child(_child)

func _process(delta: float) -> void:
	if _done:
		return
	_timer += delta
	if _timer >= WAIT_SEC:
		_done = true
		var image := get_viewport().get_texture().get_image()
		if image == null:
			print("ERROR: null image")
			get_tree().quit()
			return
		var err := image.save_png(OUTPUT_PATH)
		if err == OK:
			print("Screenshot saved: %s" % OUTPUT_PATH)
		else:
			print("ERROR: save failed (%d)" % err)
		get_tree().quit()
