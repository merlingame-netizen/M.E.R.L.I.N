extends Node3D
## BK Test Room — loads GLB assets in a row with floating labels.
## Environment, floor, lighting are native scene nodes.
## Controls: F1=toggle shadows, F2=rotate sun, F3=toggle day/night cycle

@export var sun_path: NodePath
@export var asset_spacing: float = 8.0

const ASSET_BASE: String = "res://Assets/bk_assets/"
const BIOME: String = "foret_broceliande"
const CATEGORIES: Array = [
	"vegetation", "rocks", "structures", "megaliths",
	"collectibles", "characters", "props",
]

var _sun: DirectionalLight3D
var _day_night_active: bool = false
var _sun_angle: float = -50.0


func _ready() -> void:
	# Disable all fullscreen autoload overlays that block 3D rendering
	for autoload_name in ["ScreenFrame", "ScreenDither", "MerlinBackdrop", "ScreenEffects"]:
		var node: Node = get_node_or_null("/root/" + autoload_name)
		if node and node is CanvasLayer:
			node.visible = false

	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	_place_assets_in_row()
	# Light vegetation background via universal MultiMesh system
	var VegMgr = preload("res://scripts/vegetation/vegetation_manager.gd")
	var VegPresets = preload("res://scripts/vegetation/vegetation_presets.gd")
	var _veg: RefCounted = VegMgr.new()
	_veg.setup(self, VegPresets.bk_test_room())


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	match event.keycode:
		KEY_F1:
			# Toggle shadows
			if _sun:
				_sun.shadow_enabled = not _sun.shadow_enabled
				print("[TestRoom] Shadows: ", "ON" if _sun.shadow_enabled else "OFF")
		KEY_F2:
			# Rotate sun 15 degrees
			_sun_angle += 15.0
			if _sun_angle > 0.0:
				_sun_angle = -80.0
			if _sun:
				_sun.rotation_degrees.x = _sun_angle
				print("[TestRoom] Sun angle: ", _sun_angle)
		KEY_F3:
			# Toggle day/night auto-rotation
			_day_night_active = not _day_night_active
			print("[TestRoom] Day/Night cycle: ", "ON" if _day_night_active else "OFF")


func _process(delta: float) -> void:
	if _day_night_active and _sun:
		_sun_angle -= delta * 5.0
		if _sun_angle < -80.0:
			_sun_angle = -10.0
		_sun.rotation_degrees.x = _sun_angle


func _place_assets_in_row() -> void:
	var x_offset: float = 0.0

	for category in CATEGORIES:
		var dir_path: String = ASSET_BASE + category + "/" + BIOME + "/"
		var glb_files: Array = _scan_glb_files(dir_path)

		if glb_files.is_empty():
			continue

		for glb_path in glb_files:
			var scene: PackedScene = load(glb_path) as PackedScene
			if scene == null:
				continue

			var instance: Node3D = scene.instantiate() as Node3D
			if instance == null:
				continue

			instance.position = Vector3(x_offset, 0.0, 0.0)
			var asset_name: String = glb_path.get_file().replace(".glb", "")
			instance.name = asset_name
			add_child(instance)

			# Measure and label
			var aabb: AABB = _get_combined_aabb(instance)
			var top_y: float = aabb.position.y + aabb.size.y
			var height_cm: int = int(aabb.size.y * 100.0)

			var label: Label3D = Label3D.new()
			label.text = category.to_upper() + "\n" + asset_name + "\n" + str(height_cm) + " cm"
			label.position = Vector3(x_offset, top_y + 0.6, 0.0)
			label.pixel_size = 0.008
			label.font_size = 28
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.outline_modulate = Color(0.0, 0.0, 0.0)
			label.outline_size = 6
			label.name = "Label_" + asset_name
			add_child(label)

			print("[TestRoom] ", asset_name, " h=", height_cm, "cm x=", x_offset)
			x_offset += asset_spacing


func _scan_glb_files(dir_path: String) -> Array:
	var files: Array = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return files
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".glb"):
			files.append(dir_path + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files


func _get_combined_aabb(node: Node3D) -> AABB:
	var result: AABB = AABB()
	var found: bool = false
	for child in node.get_children():
		if child is MeshInstance3D:
			var transformed: AABB = child.transform * child.get_aabb()
			if not found:
				result = transformed
				found = true
			else:
				result = result.merge(transformed)
		elif child is Node3D:
			var sub: AABB = _get_combined_aabb(child)
			if sub.size.length() > 0.0:
				if not found:
					result = sub
					found = true
				else:
					result = result.merge(sub)
	if not found:
		result = AABB(Vector3.ZERO, Vector3(1.0, 1.0, 1.0))
	return result
