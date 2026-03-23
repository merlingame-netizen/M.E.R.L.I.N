## AssetViewer3D — Free-look 3D scene to inspect GLB assets
## Controls: WASD move, mouse look, scroll zoom, 1-9 switch category, N/P next/prev asset
## Auto-scans assets/3d_models/ and displays each GLB on a turntable

extends Node

# --- Config ---
const ASSET_BASE: String = "res://assets/3d_models/"
const CATEGORIES: Array[String] = ["broceliande/megaliths", "broceliande/structures", "broceliande/poi", "broceliande/creatures", "broceliande/decor", "vegetation", "terrain", "menu_coast"]
const MOUSE_SENSITIVITY: float = 0.003
const MOVE_SPEED: float = 8.0
const ZOOM_SPEED: float = 2.0

# --- Scene refs ---
var _world: Node3D
var _camera: Camera3D
var _camera_pivot: Node3D
var _current_model: Node3D
var _turntable: Node3D
var _ground: MeshInstance3D
var _ui_layer: CanvasLayer
var _info_label: Label
var _help_label: Label

# --- State ---
var _assets: Array[String] = []  # All GLB paths found
var _current_idx: int = 0
var _category_idx: int = 0
var _cam_yaw: float = 0.0
var _cam_pitch: float = -0.3
var _cam_distance: float = 8.0
var _turntable_speed: float = 0.3
var _mouse_captured: bool = false
var _auto_rotate: bool = true


func _ready() -> void:
	# Kill CRT/screen-texture autoloads (they make 3D invisible in GL Compat)
	for child in get_tree().root.get_children():
		if child == self:
			continue
		if child is CanvasLayer:
			child.visible = false
			for sub in child.get_children():
				if sub is CanvasItem:
					sub.visible = false

	_build_world()
	_build_ui()
	_scan_assets()
	if not _assets.is_empty():
		_load_asset(_assets[0])
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true


func _process(delta: float) -> void:
	# Camera orbit
	_update_camera(delta)

	# Turntable auto-rotate
	if _auto_rotate and _turntable:
		_turntable.rotation.y += _turntable_speed * delta

	# Movement (WASD)
	var move: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move.z -= 1.0
	if Input.is_key_pressed(KEY_S): move.z += 1.0
	if Input.is_key_pressed(KEY_A): move.x -= 1.0
	if Input.is_key_pressed(KEY_D): move.x += 1.0
	if move.length() > 0.01:
		move = move.normalized() * MOVE_SPEED * delta
		var cam_basis: Basis = _camera.global_basis
		_camera_pivot.position += cam_basis * move


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		_cam_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_cam_pitch -= event.relative.y * MOUSE_SENSITIVITY
		_cam_pitch = clampf(_cam_pitch, -1.4, 1.4)

	if event is InputEventMouseButton:
		var mbe: InputEventMouseButton = event as InputEventMouseButton
		if mbe.pressed:
			if mbe.button_index == MOUSE_BUTTON_WHEEL_UP:
				_cam_distance = maxf(1.0, _cam_distance - ZOOM_SPEED)
			elif mbe.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_cam_distance = minf(30.0, _cam_distance + ZOOM_SPEED)

	if event is InputEventKey and event.pressed:
		var ke: InputEventKey = event as InputEventKey
		match ke.keycode:
			KEY_N:
				_next_asset(1)
			KEY_P:
				_next_asset(-1)
			KEY_R:
				_auto_rotate = not _auto_rotate
			KEY_ESCAPE:
				_mouse_captured = not _mouse_captured
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
				var cat: int = ke.keycode - KEY_1
				if cat < CATEGORIES.size():
					_switch_category(cat)


func _update_camera(_delta: float) -> void:
	var offset: Vector3 = Vector3(
		sin(_cam_yaw) * cos(_cam_pitch) * _cam_distance,
		sin(_cam_pitch) * _cam_distance,
		cos(_cam_yaw) * cos(_cam_pitch) * _cam_distance
	)
	_camera.position = offset
	_camera.look_at(Vector3.ZERO, Vector3.UP)


func _build_world() -> void:
	_world = Node3D.new()
	_world.name = "ViewerWorld"
	add_child(_world)

	# Camera pivot (orbits around origin)
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_world.add_child(_camera_pivot)

	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.far = 200.0
	_camera.current = true
	_camera_pivot.add_child(_camera)

	# Environment
	var we: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.38, 0.45)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.90)
	env.ambient_light_energy = 2.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	_world.add_child(we)

	# Key light
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	key.light_energy = 2.5
	key.light_color = Color(0.95, 0.92, 0.85)
	key.shadow_enabled = false
	_world.add_child(key)

	# Fill light
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20.0, -120.0, 0.0)
	fill.light_energy = 0.5
	fill.light_color = Color(0.6, 0.65, 0.8)
	fill.shadow_enabled = false
	_world.add_child(fill)

	# Ground plane (dark grid)
	_ground = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(30.0, 30.0)
	_ground.mesh = pm
	var gmat: StandardMaterial3D = StandardMaterial3D.new()
	gmat.albedo_color = Color(0.30, 0.30, 0.32)
	gmat.roughness = 1.0
	_ground.material_override = gmat
	_ground.position.y = -0.01
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_ground)

	# Turntable node (models attach here)
	_turntable = Node3D.new()
	_turntable.name = "Turntable"
	_world.add_child(_turntable)


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	# Info label (top-left)
	_info_label = Label.new()
	_info_label.position = Vector2(20, 20)
	_info_label.add_theme_font_size_override("font_size", 18)
	_info_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	_ui_layer.add_child(_info_label)

	# Help label (bottom-left)
	_help_label = Label.new()
	_help_label.position = Vector2(20, 560)
	_help_label.add_theme_font_size_override("font_size", 14)
	_help_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_help_label.text = "N/P: next/prev | 1-8: category | R: rotate | WASD: move | Scroll: zoom | ESC: cursor"
	_ui_layer.add_child(_help_label)


func _scan_assets() -> void:
	_assets.clear()
	var dir: DirAccess
	for cat in CATEGORIES:
		var path: String = ASSET_BASE + cat
		dir = DirAccess.open(path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if fname.ends_with(".glb") or fname.ends_with(".gltf"):
				_assets.append(path + "/" + fname)
			fname = dir.get_next()
		dir.list_dir_end()
	_assets.sort()
	print("[AssetViewer] Found %d assets" % _assets.size())


func _load_asset(path: String) -> void:
	# Remove old model
	if _current_model:
		_current_model.queue_free()
		_current_model = null

	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_info_label.text = "FAILED: %s" % path
		return

	_current_model = packed.instantiate() as Node3D
	if _current_model == null:
		_info_label.text = "FAILED instantiate: %s" % path
		return

	_turntable.add_child(_current_model)

	# Auto-center: compute AABB and reposition
	var aabb: AABB = _compute_aabb_recursive(_current_model, _current_model.global_transform)
	if aabb.size.length() < 0.01:
		# Fallback: try VisualInstance3D AABB
		aabb = AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1, 1))
	var center: Vector3 = aabb.position + aabb.size * 0.5
	_current_model.position = -center
	_current_model.position.y += -aabb.position.y  # Sit on ground

	# Auto-zoom based on size (minimum 5.0 for tiny models)
	var max_dim: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	_cam_distance = clampf(max_dim * 2.5, 5.0, 25.0)

	# Update info
	var fname: String = path.get_file()
	var cat: String = path.get_base_dir().replace(ASSET_BASE, "")
	var size_kb: int = 0
	if FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f:
			size_kb = int(f.get_length() / 1024)
			f.close()
	_info_label.text = "[%d/%d] %s\nCategory: %s\nSize: %dKB\nAABB: %.1f x %.1f x %.1f" % [
		_current_idx + 1, _assets.size(), fname, cat, size_kb,
		aabb.size.x, aabb.size.y, aabb.size.z
	]
	print("[AssetViewer] Loaded: %s (%dKB)" % [fname, size_kb])


func _compute_aabb_recursive(node: Node, root_xform: Transform3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	if node is VisualInstance3D:
		var vi: VisualInstance3D = node as VisualInstance3D
		var local_aabb: AABB = vi.get_aabb()
		var xform: Transform3D = vi.global_transform * root_xform.affine_inverse()
		# Transform AABB corners to root space
		for corner_idx in 8:
			var corner: Vector3 = Vector3(
				local_aabb.position.x + local_aabb.size.x * float(corner_idx & 1),
				local_aabb.position.y + local_aabb.size.y * float((corner_idx >> 1) & 1),
				local_aabb.position.z + local_aabb.size.z * float((corner_idx >> 2) & 1)
			)
			var world_corner: Vector3 = xform * corner
			if first:
				result = AABB(world_corner, Vector3.ZERO)
				first = false
			else:
				result = result.expand(world_corner)
	for child in node.get_children():
		var child_aabb: AABB = _compute_aabb_recursive(child, root_xform)
		if child_aabb.size.length() > 0.001:
			if first:
				result = child_aabb
				first = false
			else:
				result = result.merge(child_aabb)
	return result


func _next_asset(direction: int) -> void:
	if _assets.is_empty():
		return
	_current_idx = (_current_idx + direction) % _assets.size()
	if _current_idx < 0:
		_current_idx = _assets.size() - 1
	_load_asset(_assets[_current_idx])


func _switch_category(cat_idx: int) -> void:
	if cat_idx >= CATEGORIES.size():
		return
	_category_idx = cat_idx
	var prefix: String = ASSET_BASE + CATEGORIES[cat_idx]
	# Find first asset in this category
	for i in _assets.size():
		if _assets[i].begins_with(prefix):
			_current_idx = i
			_load_asset(_assets[i])
			return
	_info_label.text = "No assets in: %s" % CATEGORIES[cat_idx]
