extends Control
## SceneBroceliandeFPS
## Exploration FPS low-pixel de la foret de Broceliande.
## Objectif: retrouver Merlin dans la foret et interagir avec lui.

const HUB_SCENE := "res://scenes/HubAntre.tscn"

const ACTION_MOVE_FORWARD: StringName = &"broc_move_forward"
const ACTION_MOVE_BACK: StringName = &"broc_move_back"
const ACTION_MOVE_LEFT: StringName = &"broc_move_left"
const ACTION_MOVE_RIGHT: StringName = &"broc_move_right"
const ACTION_INTERACT: StringName = &"broc_interact"
const ACTION_TOGGLE_MOUSE: StringName = &"broc_toggle_mouse"

const MERLIN_SPAWN_POINTS: Array[Vector3] = [
	Vector3(24.0, 0.0, 18.0),
	Vector3(-26.0, 0.0, 22.0),
	Vector3(30.0, 0.0, -20.0),
	Vector3(-22.0, 0.0, -28.0),
	Vector3(8.0, 0.0, 34.0),
	Vector3(-34.0, 0.0, 6.0),
]

const MERLIN_PIXEL_UNIT := 0.12
const MERLIN_PIXEL_DEPTH := 0.08
const MERLIN_FLOAT_AMPLITUDE := 0.08
const MERLIN_FLOAT_SPEED := 1.6

# 12x14 head-only Merlin (hat + dark face + blue eyes + orb)
const MERLIN_PIXEL_GRID := [
	[0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0],
	[0, 0, 0, 0, 1, 1, 1, 2, 2, 0, 0, 0],
	[0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 0, 0],
	[0, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 0],
	[0, 0, 3, 3, 4, 4, 4, 4, 3, 3, 0, 0],
	[0, 0, 3, 7, 4, 4, 4, 7, 3, 3, 0, 0],
	[0, 0, 3, 3, 4, 3, 3, 3, 3, 3, 0, 0],
	[0, 0, 0, 3, 3, 3, 3, 3, 3, 0, 0, 0],
	[0, 0, 0, 0, 3, 3, 3, 3, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
]

const MERLIN_PIXEL_COLORS := {
	1: Color(0.07, 0.12, 0.29),  # hat dark blue
	2: Color(0.12, 0.20, 0.42),  # hat medium blue
	3: Color(0.04, 0.05, 0.08),  # face dark
	4: Color(0.14, 0.15, 0.20),  # face mid shadow
	5: Color(0.03, 0.04, 0.06),  # brim shadow
	6: Color(0.34, 0.72, 1.0),   # orb blue
	7: Color(0.40, 0.84, 1.0),   # eye glow
}

@export var low_pixel_height: int = 240
@export var forest_radius: float = 64.0
@export var tree_count: int = 90
@export var shrub_count: int = 45
@export var rock_count: int = 30
@export var move_speed: float = 6.0
@export var mouse_sensitivity: float = 0.0026
@export var interact_distance: float = 2.6

@onready var viewport_container: SubViewportContainer = $ViewportContainer
@onready var game_viewport: SubViewport = $ViewportContainer/GameViewport
@onready var world_root: Node3D = $ViewportContainer/GameViewport/World3D
@onready var world_environment: WorldEnvironment = $ViewportContainer/GameViewport/World3D/WorldEnvironment
@onready var sun_light: DirectionalLight3D = $ViewportContainer/GameViewport/World3D/SunLight
@onready var forest_root: Node3D = $ViewportContainer/GameViewport/World3D/ForestRoot
@onready var merlin: Node3D = $ViewportContainer/GameViewport/World3D/Merlin
@onready var player: CharacterBody3D = $ViewportContainer/GameViewport/World3D/Player
@onready var player_collision: CollisionShape3D = $ViewportContainer/GameViewport/World3D/Player/CollisionShape3D
@onready var player_head: Node3D = $ViewportContainer/GameViewport/World3D/Player/Head

@onready var objective_label: Label = $HUD/Margin/InfoPanel/VBox/ObjectiveLabel
@onready var status_label: Label = $HUD/Margin/InfoPanel/VBox/StatusLabel
@onready var crosshair: Label = $HUD/Crosshair
@onready var result_panel: PanelContainer = $HUD/ResultPanel
@onready var result_text: Label = $HUD/ResultPanel/ResultMargin/VBox/ResultText
@onready var replay_button: Button = $HUD/ResultPanel/ResultMargin/VBox/Buttons/ReplayButton
@onready var hub_button: Button = $HUD/ResultPanel/ResultMargin/VBox/Buttons/HubButton

var _rng := RandomNumberGenerator.new()
var _gravity: float = 9.8
var _velocity := Vector3.ZERO
var _pitch: float = 0.0
var _merlin_found: bool = false
var _merlin_anchor: Vector3 = Vector3.ZERO
var _merlin_has_anchor: bool = false
var _merlin_float_time: float = 0.0
var _merlin_pixel_rig: Node3D
var _merlin_orb_light: OmniLight3D


func _ready() -> void:
	_rng.randomize()
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

	_ensure_actions()
	_setup_low_pixel_viewport()
	_setup_environment()
	_setup_player()
	_build_ground()
	_build_boundaries()
	_build_forest()
	_spawn_merlin()
	_wire_buttons()
	_update_hud()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_pixel_shrink()


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_TOGGLE_MOUSE):
		_toggle_mouse_mode()
		return

	if event.is_action_pressed(ACTION_INTERACT):
		_try_interact()
		return

	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED or _merlin_found:
			return
		var motion := event as InputEventMouseMotion
		player.rotate_y(-motion.relative.x * mouse_sensitivity)
		_pitch = clamp(_pitch - motion.relative.y * mouse_sensitivity, deg_to_rad(-80.0), deg_to_rad(75.0))
		player_head.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	var axis := Input.get_vector(ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT, ACTION_MOVE_FORWARD, ACTION_MOVE_BACK)
	var move_dir := Vector3.ZERO
	if axis.length() > 0.01 and not _merlin_found and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var yaw_basis := Basis(Vector3.UP, player.rotation.y)
		move_dir = (yaw_basis * Vector3(axis.x, 0.0, axis.y)).normalized()

	var accel := 15.0 if move_dir != Vector3.ZERO else 10.0
	_velocity.x = move_toward(_velocity.x, move_dir.x * move_speed, accel * delta)
	_velocity.z = move_toward(_velocity.z, move_dir.z * move_speed, accel * delta)

	if player.is_on_floor():
		_velocity.y = -0.05
	else:
		_velocity.y -= _gravity * delta

	player.velocity = _velocity
	player.move_and_slide()
	_velocity = player.velocity

	_update_merlin_visual(delta)
	_update_hud()


func _ensure_actions() -> void:
	_add_action_keys(ACTION_MOVE_FORWARD, [KEY_W, KEY_UP])
	_add_action_keys(ACTION_MOVE_BACK, [KEY_S, KEY_DOWN])
	_add_action_keys(ACTION_MOVE_LEFT, [KEY_A, KEY_LEFT])
	_add_action_keys(ACTION_MOVE_RIGHT, [KEY_D, KEY_RIGHT])
	_add_action_keys(ACTION_INTERACT, [KEY_E, KEY_ENTER])
	_add_action_keys(ACTION_TOGGLE_MOUSE, [KEY_ESCAPE])


func _add_action_keys(action_name: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var mapped_keys := {}
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			mapped_keys[key_event.physical_keycode] = true

	for keycode in keys:
		if mapped_keys.has(keycode):
			continue
		var new_event := InputEventKey.new()
		new_event.physical_keycode = keycode
		InputMap.action_add_event(action_name, new_event)
		mapped_keys[keycode] = true


func _setup_low_pixel_viewport() -> void:
	viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_update_pixel_shrink()


func _update_pixel_shrink() -> void:
	var screen_size := get_viewport_rect().size
	if screen_size.y < 1.0:
		return
	var shrink := int(round(screen_size.y / max(1.0, float(low_pixel_height))))
	viewport_container.stretch_shrink = max(shrink, 1)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.11, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.56, 0.45)
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = Color(0.33, 0.43, 0.34)
	env.fog_density = 0.02
	world_environment.environment = env

	sun_light.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun_light.light_color = Color(0.78, 0.88, 0.74)
	sun_light.light_energy = 1.25
	sun_light.shadow_enabled = true


func _setup_player() -> void:
	player.position = Vector3(0.0, 1.2, 0.0)
	player.rotation = Vector3.ZERO
	player_head.rotation = Vector3.ZERO
	_pitch = 0.0

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.2
	player_collision.shape = capsule
	player_collision.position = Vector3(0.0, 0.95, 0.0)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	world_root.add_child(ground)

	var collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(forest_radius * 2.5, 2.0, forest_radius * 2.5)
	collision.shape = ground_shape
	collision.position = Vector3(0.0, -1.0, 0.0)
	ground.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(forest_radius * 2.5, 0.2, forest_radius * 2.5)
	mesh_instance.mesh = ground_mesh
	mesh_instance.position = Vector3(0.0, -0.1, 0.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.09, 0.19, 0.1)
	material.roughness = 1.0
	mesh_instance.material_override = material
	ground.add_child(mesh_instance)


func _build_boundaries() -> void:
	var half := forest_radius + 2.0
	var wall_height := 7.0
	var wall_thickness := 1.0
	_create_wall(Vector3(0.0, wall_height * 0.5, half), Vector3(half * 2.0, wall_height, wall_thickness))
	_create_wall(Vector3(0.0, wall_height * 0.5, -half), Vector3(half * 2.0, wall_height, wall_thickness))
	_create_wall(Vector3(half, wall_height * 0.5, 0.0), Vector3(wall_thickness, wall_height, half * 2.0))
	_create_wall(Vector3(-half, wall_height * 0.5, 0.0), Vector3(wall_thickness, wall_height, half * 2.0))


func _create_wall(wall_position: Vector3, wall_size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.position = wall_position
	world_root.add_child(wall)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = wall_size
	collision.shape = shape
	wall.add_child(collision)


func _build_forest() -> void:
	for i in tree_count:
		var tree_pos := _random_world_position(10.0, forest_radius - 6.0)
		_create_tree(tree_pos, _rng.randf_range(0.8, 1.35))

	for i in shrub_count:
		var shrub_pos := _random_world_position(6.0, forest_radius - 4.0)
		_create_shrub(shrub_pos, _rng.randf_range(0.6, 1.4))

	for i in rock_count:
		var rock_pos := _random_world_position(5.0, forest_radius - 5.0)
		_create_rock(rock_pos, _rng.randf_range(0.5, 1.1))


func _random_world_position(min_distance: float, max_distance: float) -> Vector3:
	var distance := _rng.randf_range(min_distance, max_distance)
	var angle := _rng.randf_range(0.0, TAU)
	return Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)


func _create_tree(tree_pos: Vector3, scale_factor: float) -> void:
	var tree := StaticBody3D.new()
	tree.position = tree_pos
	forest_root.add_child(tree)

	var trunk_height := 2.1 * scale_factor
	var trunk_radius := 0.22 * scale_factor

	var collision := CollisionShape3D.new()
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.height = trunk_height
	trunk_shape.radius = trunk_radius
	collision.shape = trunk_shape
	collision.position = Vector3(0.0, trunk_height * 0.5, 0.0)
	tree.add_child(collision)

	var trunk_mesh_instance := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.height = trunk_height
	trunk_mesh.bottom_radius = trunk_radius
	trunk_mesh.top_radius = trunk_radius * 0.85
	trunk_mesh.radial_segments = 6
	trunk_mesh_instance.mesh = trunk_mesh
	trunk_mesh_instance.position = collision.position

	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.22, 0.14, 0.08)
	trunk_material.roughness = 1.0
	trunk_mesh_instance.material_override = trunk_material
	tree.add_child(trunk_mesh_instance)

	for crown_idx in 3:
		var crown := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.height = (1.1 - crown_idx * 0.12) * scale_factor
		cone.bottom_radius = (1.2 - crown_idx * 0.18) * scale_factor
		cone.top_radius = 0.0
		cone.radial_segments = 6
		crown.mesh = cone
		crown.position = Vector3(0.0, trunk_height + 0.35 + crown_idx * 0.55, 0.0)

		var leaf_tint := _rng.randf_range(-0.03, 0.05)
		var leaf_material := StandardMaterial3D.new()
		leaf_material.albedo_color = Color(0.12 + leaf_tint, 0.31 + leaf_tint, 0.12 + leaf_tint * 0.5)
		leaf_material.roughness = 1.0
		crown.material_override = leaf_material
		tree.add_child(crown)


func _create_shrub(shrub_pos: Vector3, scale_factor: float) -> void:
	var shrub_mesh := MeshInstance3D.new()
	shrub_mesh.position = shrub_pos + Vector3(0.0, 0.35 * scale_factor, 0.0)
	forest_root.add_child(shrub_mesh)

	var sphere := SphereMesh.new()
	sphere.radius = 0.45 * scale_factor
	sphere.height = 0.65 * scale_factor
	sphere.radial_segments = 6
	sphere.rings = 3
	shrub_mesh.mesh = sphere

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.14, 0.36, 0.14)
	material.roughness = 1.0
	shrub_mesh.material_override = material


func _create_rock(rock_pos: Vector3, scale_factor: float) -> void:
	var rock := StaticBody3D.new()
	rock.position = rock_pos
	forest_root.add_child(rock)

	var collision := CollisionShape3D.new()
	var rock_shape := SphereShape3D.new()
	rock_shape.radius = 0.5 * scale_factor
	collision.shape = rock_shape
	collision.position = Vector3(0.0, rock_shape.radius, 0.0)
	rock.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = rock_shape.radius
	sphere.height = rock_shape.radius * 1.6
	sphere.radial_segments = 5
	sphere.rings = 3
	mesh_instance.mesh = sphere
	mesh_instance.position = collision.position
	mesh_instance.scale = Vector3(1.15, 0.75, 0.95)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.33, 0.35, 0.33)
	material.roughness = 1.0
	mesh_instance.material_override = material
	rock.add_child(mesh_instance)


func _spawn_merlin() -> void:
	for child in merlin.get_children():
		child.queue_free()

	var point_index := _rng.randi_range(0, MERLIN_SPAWN_POINTS.size() - 1)
	var spawn_pos: Vector3 = MERLIN_SPAWN_POINTS[point_index]
	spawn_pos.x += _rng.randf_range(-3.0, 3.0)
	spawn_pos.z += _rng.randf_range(-3.0, 3.0)
	_merlin_anchor = spawn_pos
	_merlin_has_anchor = true
	_merlin_float_time = _rng.randf_range(0.0, TAU)
	merlin.position = _merlin_anchor

	_merlin_pixel_rig = Node3D.new()
	_merlin_pixel_rig.name = "PixelRig"
	_merlin_pixel_rig.position = Vector3(0.0, 0.65, 0.0)
	merlin.add_child(_merlin_pixel_rig)

	_build_merlin_pixel_rig(_merlin_pixel_rig)


func _build_merlin_pixel_rig(rig: Node3D) -> void:
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(MERLIN_PIXEL_UNIT, MERLIN_PIXEL_UNIT, MERLIN_PIXEL_DEPTH)

	var pixels: Array[MeshInstance3D] = []
	var grid_h := MERLIN_PIXEL_GRID.size()
	var grid_w := int(MERLIN_PIXEL_GRID[0].size())
	var orb_target := Vector3(0.0, 1.2, 0.0)

	for row in grid_h:
		var row_data: Array = MERLIN_PIXEL_GRID[row]
		for col in row_data.size():
			var color_idx := int(row_data[col])
			if color_idx == 0:
				continue

			var px := MeshInstance3D.new()
			px.mesh = box_mesh
			px.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			px.material_override = _create_merlin_pixel_material(color_idx)

			var target := Vector3(
				(float(col) - (float(grid_w) - 1.0) * 0.5) * MERLIN_PIXEL_UNIT,
				float(grid_h - 1 - row) * MERLIN_PIXEL_UNIT,
				0.0
			)
			px.position = target + Vector3(
				_rng.randf_range(-0.10, 0.10),
				_rng.randf_range(1.2, 2.6),
				_rng.randf_range(-0.08, 0.08)
			)
			px.scale = Vector3.ONE * _rng.randf_range(0.5, 0.85)
			px.set_meta("target_pos", target)
			px.set_meta("row", row)

			rig.add_child(px)
			pixels.append(px)

			if color_idx == 6:
				orb_target = target

	_animate_merlin_pixel_assembly(pixels)

	_merlin_orb_light = OmniLight3D.new()
	_merlin_orb_light.name = "OrbLight"
	_merlin_orb_light.light_color = Color(0.33, 0.73, 1.0)
	_merlin_orb_light.light_energy = 0.8
	_merlin_orb_light.omni_range = 2.4
	_merlin_orb_light.position = orb_target + Vector3(0.0, 0.0, 0.28)
	rig.add_child(_merlin_orb_light)


func _animate_merlin_pixel_assembly(pixels: Array[MeshInstance3D]) -> void:
	var tw := create_tween()
	tw.set_parallel(true)

	for px in pixels:
		if not is_instance_valid(px):
			continue
		var target: Vector3 = px.get_meta("target_pos", px.position)
		var row := int(px.get_meta("row", 0))
		var delay := float(row) * 0.02 + _rng.randf_range(0.0, 0.18)
		var duration := 0.34 + _rng.randf_range(0.12, 0.42)
		tw.tween_property(px, "position", target, duration) \
			.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(px, "scale", Vector3.ONE, duration * 0.9) \
			.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _create_merlin_pixel_material(color_idx: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = MERLIN_PIXEL_COLORS.get(color_idx, Color.WHITE)
	mat.roughness = 1.0
	mat.metallic = 0.0
	if color_idx == 6 or color_idx == 7:
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 1.2 if color_idx == 6 else 1.5
	return mat


func _update_merlin_visual(delta: float) -> void:
	if not _merlin_has_anchor:
		return
	if not is_instance_valid(merlin):
		return

	_merlin_float_time += delta
	merlin.position = _merlin_anchor + Vector3(0.0, sin(_merlin_float_time * MERLIN_FLOAT_SPEED) * MERLIN_FLOAT_AMPLITUDE, 0.0)

	if _merlin_pixel_rig and is_instance_valid(_merlin_pixel_rig) and player and is_instance_valid(player):
		var look_target := Vector3(player.global_position.x, _merlin_pixel_rig.global_position.y, player.global_position.z)
		if _merlin_pixel_rig.global_position.distance_to(look_target) > 0.001:
			_merlin_pixel_rig.look_at(look_target, Vector3.UP)

	if _merlin_orb_light and is_instance_valid(_merlin_orb_light):
		_merlin_orb_light.light_energy = 0.72 + sin(_merlin_float_time * 4.2) * 0.18


func _wire_buttons() -> void:
	if not replay_button.pressed.is_connected(_on_replay_pressed):
		replay_button.pressed.connect(_on_replay_pressed)
	if not hub_button.pressed.is_connected(_on_hub_pressed):
		hub_button.pressed.connect(_on_hub_pressed)


func _toggle_mouse_mode() -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif not _merlin_found:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _try_interact() -> void:
	if _merlin_found:
		return
	var distance := player.global_position.distance_to(merlin.global_position)
	if distance > interact_distance:
		status_label.text = "Aucune presence assez proche. Continue la recherche (%.1f m)." % distance
		return
	_complete_scene()


func _complete_scene() -> void:
	_merlin_found = true
	objective_label.text = "Objectif atteint: Merlin t'a retrouve."
	status_label.text = "Le druide t'ouvre un passage vers l'Antre."
	result_text.text = "Tu as trouve Merlin au coeur de Broceliande.\nLe chemin mystique est desormais revele."
	result_panel.visible = true
	crosshair.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _update_hud() -> void:
	if _merlin_found:
		return

	objective_label.text = "Objectif: localise Merlin dans la foret de Broceliande."

	var delta_vec := merlin.global_position - player.global_position
	var distance := delta_vec.length()
	if distance <= interact_distance:
		status_label.text = "Aura druidique intense. Appuie sur E pour parler a Merlin."
		return

	var forward := -player.global_transform.basis.z
	var right := forward.cross(Vector3.UP).normalized()
	var hint := "droit devant"
	var side := right.dot(delta_vec.normalized())
	if side > 0.2:
		hint = "sur ta droite"
	elif side < -0.2:
		hint = "sur ta gauche"

	status_label.text = "Signal magique %s (%.1f m)." % [hint, distance]


func _on_replay_pressed() -> void:
	get_tree().reload_current_scene()


func _on_hub_pressed() -> void:
	get_tree().change_scene_to_file(HUB_SCENE)
