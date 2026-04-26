extends Node
## MerlinCabinHub — 3D interior scene: Merlin's cabin between runs.
## Tapestry (talent tree), wall map (biome choice), Merlin NPC (LLM dialogue).
## Post-run: stats display, Anam rewards, progression.

const FOREST_SCENE: String = "res://scenes/BroceliandeForest3D.tscn"
const MENU_SCENE: String = "res://scenes/MerlinCabinHub.tscn"

var _world: Node3D
var _camera: Camera3D
var _ui_layer: CanvasLayer
var _hint_label: Label
# FPS look state (camera rotation only — position is fixed)
var _yaw: float = 0.0     # horizontal rotation (radians)
var _pitch: float = 0.0   # vertical rotation (radians, clamped)
const MOUSE_SENS: float = 0.0025
const PITCH_LIMIT: float = 0.7  # ~40 deg up/down
const CAMERA_POS: Vector3 = Vector3(0, 2.0, 1.5)  # Standing FPS height in cabin
# Hover state for click feedback
var _hovered_target: String = ""


func _ready() -> void:
	_build_3d_cabin()
	_build_ui_overlay()
	# FPS hub: mouse captured for look, click to interact.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	# Mouse look: rotate camera in place (position locked).
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event
		_yaw -= mm.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - mm.relative.y * MOUSE_SENS, -PITCH_LIMIT, PITCH_LIMIT)
		if is_instance_valid(_camera):
			_camera.transform.basis = Basis()
			_camera.rotate_y(_yaw)
			_camera.rotate_object_local(Vector3.RIGHT, _pitch)
	# ESC to release mouse (debug / quitting).
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)
	# Click: interact with whatever the camera is centered on (raycast from camera).
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_try_interact()


func _process(_delta: float) -> void:
	# Camera position is fixed; orientation is driven by mouse via _input.
	if is_instance_valid(_camera):
		_camera.position = CAMERA_POS
	_update_crosshair_hover()


func _build_3d_cabin() -> void:
	_world = Node3D.new()
	_world.name = "CabinWorld"
	add_child(_world)

	# Camera
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 2.0, 3.0)
	_camera.fov = 55
	_world.add_child(_camera)

	# Environment
	var env_res: Environment = Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.04, 0.03, 0.02)
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.15, 0.12, 0.08)
	env_res.ambient_light_energy = 0.5
	env_res.fog_enabled = true
	env_res.fog_light_color = Color(0.08, 0.06, 0.04)
	env_res.fog_density = 0.02
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env_res
	_world.add_child(world_env)

	# Warm firelight
	var fire_light: OmniLight3D = OmniLight3D.new()
	fire_light.position = Vector3(-1.0, 1.5, -2.0)
	fire_light.light_color = Color(1.0, 0.7, 0.3)
	fire_light.light_energy = 2.5
	fire_light.omni_range = 8.0
	fire_light.shadow_enabled = true
	_world.add_child(fire_light)

	# Fire particles (dust motes in firelight)
	var fire_particles: GPUParticles3D = GPUParticles3D.new()
	fire_particles.position = Vector3(-1.0, 1.8, -2.0)
	fire_particles.amount = 20
	fire_particles.lifetime = 4.0
	fire_particles.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 3, 4))
	var pmat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 1.5
	pmat.gravity = Vector3(0, 0.1, 0)
	pmat.initial_velocity_min = 0.05
	pmat.initial_velocity_max = 0.15
	pmat.scale_min = 0.02
	pmat.scale_max = 0.06
	pmat.color = Color(1.0, 0.85, 0.5, 0.3)
	fire_particles.process_material = pmat
	var pmesh: SphereMesh = SphereMesh.new()
	pmesh.radius = 0.02
	pmesh.height = 0.04
	fire_particles.draw_pass_1 = pmesh
	_world.add_child(fire_particles)

	# Ambient fill
	var fill: OmniLight3D = OmniLight3D.new()
	fill.position = Vector3(2.0, 2.5, 0.0)
	fill.light_color = Color(0.3, 0.4, 0.6)
	fill.light_energy = 0.5
	fill.omni_range = 6.0
	_world.add_child(fill)

	# Floor
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mesh.mesh = plane
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.15, 0.10, 0.06)
	floor_mat.roughness = 0.9
	floor_mesh.material_override = floor_mat
	_world.add_child(floor_mesh)

	# Walls (simple boxes)
	_add_wall(Vector3(0, 2, -4), Vector3(8, 4, 0.2), Color(0.12, 0.08, 0.05))  # Back
	_add_wall(Vector3(-4, 2, 0), Vector3(0.2, 4, 8), Color(0.10, 0.07, 0.04))  # Left
	_add_wall(Vector3(4, 2, 0), Vector3(0.2, 4, 8), Color(0.10, 0.07, 0.04))   # Right
	_add_wall(Vector3(0, 4, 0), Vector3(8, 0.15, 8), Color(0.08, 0.06, 0.03))  # Ceiling

	# Cauldron (center-back)
	var cauldron: MeshInstance3D = MeshInstance3D.new()
	var cauldron_mesh: SphereMesh = SphereMesh.new()
	cauldron_mesh.radius = 0.4
	cauldron_mesh.height = 0.5
	cauldron.mesh = cauldron_mesh
	cauldron.position = Vector3(-1.0, 0.4, -2.5)
	var cauldron_mat: StandardMaterial3D = StandardMaterial3D.new()
	cauldron_mat.albedo_color = Color(0.15, 0.15, 0.15)
	cauldron_mat.metallic = 0.8
	cauldron.material_override = cauldron_mat
	_world.add_child(cauldron)
	_make_interactable(cauldron, Vector3(0.4, 0.4, 0.4), "cauldron")

	# Cristal d'Anam (small floating glowing crystal — placeholder for Anam stat)
	var crystal: MeshInstance3D = MeshInstance3D.new()
	var crystal_mesh: PrismMesh = PrismMesh.new()
	crystal_mesh.size = Vector3(0.18, 0.45, 0.18)
	crystal.mesh = crystal_mesh
	crystal.position = Vector3(2.2, 1.2, -2.0)
	var crystal_mat: StandardMaterial3D = StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(0.55, 0.42, 0.78)
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color(0.45, 0.32, 0.78)
	crystal_mat.emission_energy_multiplier = 1.8
	crystal.material_override = crystal_mat
	_world.add_child(crystal)
	_make_interactable(crystal, Vector3(0.18, 0.30, 0.18), "cauldron")

	# Tapestry placeholder (talent tree removed in demo cleanup 2026-04-25 — solid colored quad)
	var tapestry: MeshInstance3D = MeshInstance3D.new()
	var tap_mesh: QuadMesh = QuadMesh.new()
	tap_mesh.size = Vector2(3.0, 2.3)
	tapestry.mesh = tap_mesh
	tapestry.position = Vector3(1.5, 2.2, -3.9)
	var tap_mat: StandardMaterial3D = StandardMaterial3D.new()
	tap_mat.albedo_color = Color(0.35, 0.20, 0.10)  # Dark woven brown
	tap_mat.roughness = 1.0
	tapestry.material_override = tap_mat
	_world.add_child(tapestry)
	_make_interactable(tapestry, Vector3(1.5, 1.15, 0.1), "tapestry")

	# Wall map (left wall — biome selection via SubViewport)
	var map_viewport: SubViewport = SubViewport.new()
	map_viewport.size = Vector2i(400, 320)
	map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	map_viewport.transparent_bg = true
	add_child(map_viewport)

	var map_canvas: Control = Control.new()
	map_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_canvas.draw.connect(_draw_biome_map.bind(map_canvas))
	map_viewport.add_child(map_canvas)

	var wall_map: MeshInstance3D = MeshInstance3D.new()
	var map_mesh: QuadMesh = QuadMesh.new()
	map_mesh.size = Vector2(2.5, 2.0)
	wall_map.mesh = map_mesh
	wall_map.position = Vector3(-3.9, 2.0, -1.0)
	wall_map.rotation.y = PI / 2.0
	var map_mat: StandardMaterial3D = StandardMaterial3D.new()
	map_mat.albedo_texture = map_viewport.get_texture()
	map_mat.roughness = 1.0
	map_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wall_map.material_override = map_mat
	_world.add_child(wall_map)
	_make_interactable(wall_map, Vector3(1.25, 1.0, 0.1), "map")

	# Fairy lanterns (atmospheric)
	for i in 4:
		var lantern: MeshInstance3D = MeshInstance3D.new()
		var lm: SphereMesh = SphereMesh.new()
		lm.radius = 0.08
		lantern.mesh = lm
		var lmat: StandardMaterial3D = StandardMaterial3D.new()
		lmat.albedo_color = Color(0.3, 1.0, 0.5)
		lmat.emission_enabled = true
		lmat.emission = Color(0.2, 0.8, 0.4)
		lmat.emission_energy_multiplier = 2.0
		lantern.material_override = lmat
		lantern.position = Vector3(
			randf_range(-3.0, 3.0),
			randf_range(2.5, 3.5),
			randf_range(-3.0, 1.0)
		)
		_world.add_child(lantern)


func _add_wall(pos: Vector3, sz: Vector3, color: Color) -> void:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = sz
	mesh_inst.mesh = box
	mesh_inst.position = pos
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(mesh_inst)


func _draw_biome_map(canvas: Control) -> void:
	var sz: Vector2 = canvas.size
	# Parchment background
	canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.85, 0.80, 0.65), true)
	# Title
	canvas.draw_string(ThemeDB.fallback_font, Vector2(120, 25), "Carte de Broceliande", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.3, 0.2, 0.1))

	# 8 biome regions as circles on the map
	var biomes: Array[Dictionary] = [
		{"name": "Broceliande", "pos": Vector2(200, 150), "color": Color(0.2, 0.5, 0.15), "unlocked": true},
		{"name": "Landes", "pos": Vector2(100, 100), "color": Color(0.5, 0.4, 0.2), "unlocked": false},
		{"name": "Cotes", "pos": Vector2(320, 80), "color": Color(0.2, 0.4, 0.7), "unlocked": false},
		{"name": "Monts", "pos": Vector2(80, 220), "color": Color(0.4, 0.35, 0.3), "unlocked": false},
		{"name": "Ile de Sein", "pos": Vector2(50, 160), "color": Color(0.3, 0.5, 0.6), "unlocked": false},
		{"name": "Huelgoat", "pos": Vector2(280, 200), "color": Color(0.15, 0.4, 0.12), "unlocked": false},
		{"name": "Ecosse", "pos": Vector2(340, 250), "color": Color(0.35, 0.3, 0.25), "unlocked": false},
		{"name": "Iles Mystiques", "pos": Vector2(160, 270), "color": Color(0.4, 0.2, 0.5), "unlocked": false},
	]

	# Draw connections
	for i in biomes.size():
		for j in range(i + 1, mini(i + 3, biomes.size())):
			var c1: Color = Color(0.6, 0.5, 0.3, 0.2)
			canvas.draw_line(biomes[i]["pos"] as Vector2, biomes[j]["pos"] as Vector2, c1, 1.0)

	# Draw biome dots
	for b in biomes:
		var pos: Vector2 = b["pos"] as Vector2
		var col: Color = b["color"] as Color
		var unlocked: bool = b["unlocked"] as bool
		if unlocked:
			canvas.draw_circle(pos, 18, Color(col.r, col.g, col.b, 0.15))
			canvas.draw_circle(pos, 12, col)
			canvas.draw_string(ThemeDB.fallback_font, pos + Vector2(-25, 22), str(b["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.2, 0.1))
		else:
			canvas.draw_circle(pos, 8, Color(0.4, 0.35, 0.25, 0.3))
			canvas.draw_string(ThemeDB.fallback_font, pos + Vector2(-8, 18), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.35, 0.25, 0.4))

	# Compass
	canvas.draw_string(ThemeDB.fallback_font, Vector2(370, 50), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.3, 0.2))


func _build_ui_overlay() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	var font: Font = MerlinVisual.get_font("terminal") if is_instance_valid(MerlinVisual) else null
	var pal: Dictionary = MerlinVisual.CRT_PALETTE if is_instance_valid(MerlinVisual) else {}

	# Title
	var title: Label = Label.new()
	title.text = "L'Antre de Merlin"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.offset_top = 20
	if font: title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", pal.get("amber", Color(1.0, 0.75, 0.2)))
	_ui_layer.add_child(title)

	# Merlin greeting (typewriter effect)
	var greeting_quotes: Array[String] = [
		"Bienvenue, voyageur. Les pierres m'ont parle de ta venue.",
		"Ah, te voila. La foret t'attendait, comme toujours.",
		"Entre, entre. Le chaudron est chaud et les etoiles sont alignees.",
		"Je sentais ta presence dans les ley lines. Assieds-toi.",
		"Les korrigans m'ont prevenu. Tu cherches les Runes, n'est-ce pas ?",
	]
	var greeting: Label = Label.new()
	greeting.text = greeting_quotes[randi() % greeting_quotes.size()]
	greeting.set_anchors_preset(Control.PRESET_TOP_WIDE)
	greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	greeting.offset_top = 55
	greeting.autowrap_mode = TextServer.AUTOWRAP_WORD
	if font: greeting.add_theme_font_override("font", font)
	greeting.add_theme_font_size_override("font_size", 15)
	greeting.add_theme_color_override("font_color", pal.get("phosphor_dim", Color(0.12, 0.6, 0.24)))
	_ui_layer.add_child(greeting)

	# Crosshair (small dot at center)
	var cross: Label = Label.new()
	cross.text = "+"
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.offset_left = -8
	cross.offset_top = -16
	cross.offset_right = 8
	cross.offset_bottom = 16
	cross.add_theme_font_size_override("font_size", 26)
	cross.add_theme_color_override("font_color", pal.get("phosphor", Color(0.2, 1.0, 0.4)))
	cross.modulate.a = 0.55
	_ui_layer.add_child(cross)

	# Hint label below crosshair (shows hovered interactable / flash messages)
	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_CENTER)
	_hint_label.offset_top = 22
	_hint_label.offset_bottom = 60
	_hint_label.offset_left = -360
	_hint_label.offset_right = 360
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font: _hint_label.add_theme_font_override("font", font)
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", pal.get("amber", Color(1.0, 0.75, 0.2)))
	_hint_label.text = ""
	_ui_layer.add_child(_hint_label)

	# Bottom controls hint
	var ctl_hint: Label = Label.new()
	ctl_hint.text = "Souris : regarder    Clic gauche : interagir    Echap : liberer souris"
	ctl_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ctl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctl_hint.offset_top = -36
	ctl_hint.offset_bottom = -10
	if font: ctl_hint.add_theme_font_override("font", font)
	ctl_hint.add_theme_font_size_override("font_size", 12)
	ctl_hint.add_theme_color_override("font_color", pal.get("phosphor_dim", Color(0.12, 0.6, 0.24)))
	ctl_hint.modulate.a = 0.7
	_ui_layer.add_child(ctl_hint)


func _on_hub_action(action: String) -> void:
	if is_instance_valid(SFXManager):
		SFXManager.play("click")
	match action:
		"quest", "map":
			_show_book_cinematic_then_forest()
		"tapestry":
			# Display unlocked traits + stats from the save profile.
			var trait_summary: String = _build_trait_summary_from_save()
			_flash_hint(trait_summary)
		"cauldron":
			# Display Anam + total runs + tutorial status from save profile.
			var save_summary: String = _build_save_summary()
			_flash_hint(save_summary)
		"menu":
			PixelTransition.transition_to(MENU_SCENE)


## Read save profile and return a one-line summary for the cauldron tooltip.
func _build_save_summary() -> String:
	var save_path := "user://merlin_profile.json"
	if not FileAccess.file_exists(save_path):
		return "Cristal vide. Aucun voyage encore."
	var f: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return "Cristal silencieux."
	var raw: String = f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK or not (json.data is Dictionary):
		return "Cristal silencieux."
	var data: Dictionary = json.data as Dictionary
	var meta: Dictionary = data.get("meta", {}) as Dictionary
	var anam: int = int(meta.get("anam", 0))
	var total: int = int(meta.get("total_runs", 0))
	var tuto: bool = bool(meta.get("tutorial_completed", false))
	if total == 0:
		return "Anam: %d — Tu n'as pas encore franchi le seuil." % anam
	return "Anam: %d  •  Voyages: %d  •  %s" % [anam, total, ("seuil franchi" if tuto else "tuto en attente")]


## Read save profile and return trait summary (count + first 2 keys).
func _build_trait_summary_from_save() -> String:
	var save_path := "user://merlin_profile.json"
	if not FileAccess.file_exists(save_path):
		return "Tapisserie vierge."
	var f: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return "Tapisserie en sommeil."
	var raw: String = f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK or not (json.data is Dictionary):
		return "Tapisserie en sommeil."
	var data: Dictionary = json.data as Dictionary
	# Traits live under player.traits in the runtime state, but on disk they may be
	# under top-level "player" or absent (legacy saves).
	var player: Dictionary = data.get("player", {}) as Dictionary
	var traits: Array = player.get("traits", []) as Array
	if traits.is_empty():
		return "Tapisserie : aucun fil tisse encore."
	var traits_str: String = ", ".join(traits.slice(0, 3))
	return "Tapisserie : %d fil%s — %s" % [traits.size(), ("s" if traits.size() > 1 else ""), traits_str]


# ═══════════════════════════════════════════════════════════════════════════════
# FPS interaction — raycast from camera, click to trigger registered action
# ═══════════════════════════════════════════════════════════════════════════════

func _make_interactable(node: Node3D, half_extents: Vector3, action_id: String) -> void:
	# Wrap a MeshInstance3D (or any Node3D) in a StaticBody3D so a raycast can hit it.
	var body: StaticBody3D = StaticBody3D.new()
	body.set_meta("action", action_id)
	body.collision_layer = 1
	body.collision_mask = 0
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = half_extents * 2.0
	col.shape = shape
	body.add_child(col)
	# Insert body as child of node's parent at node's transform so raycasts hit at the same spot.
	body.transform = node.transform
	if node.get_parent():
		node.get_parent().add_child(body)


func _try_interact() -> void:
	var hit: Dictionary = _raycast_from_camera()
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider")
	if collider and collider.has_meta("action"):
		_on_hub_action(str(collider.get_meta("action")))


func _update_crosshair_hover() -> void:
	var hit: Dictionary = _raycast_from_camera()
	var new_target: String = ""
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider and collider.has_meta("action"):
			new_target = str(collider.get_meta("action"))
	if new_target == _hovered_target:
		return
	_hovered_target = new_target
	if is_instance_valid(_hint_label):
		match new_target:
			"quest", "map":  _hint_label.text = "[ Carte de Broceliande — clic pour partir ]"
			"tapestry":      _hint_label.text = "[ Tapisserie des Talents ]"
			"cauldron":      _hint_label.text = "[ Cristal d'Anam ]"
			_:               _hint_label.text = ""


func _raycast_from_camera() -> Dictionary:
	if not is_instance_valid(_camera):
		return {}
	var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var from: Vector3 = _camera.global_position
	var to: Vector3 = from + (-_camera.global_transform.basis.z) * 6.0
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	return space.intersect_ray(q)


func _flash_hint(text: String) -> void:
	if not is_instance_valid(_hint_label):
		return
	_hint_label.text = text
	# Restore based on hover after 2.5s.
	await get_tree().create_timer(2.5).timeout
	_hovered_target = "_dirty"  # force refresh on next process tick


func _read_anam_from_save() -> int:
	var path := "user://merlin_profile.json"
	if not FileAccess.file_exists(path):
		return 0
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var raw: String = f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK or not (json.data is Dictionary):
		return 0
	var data: Dictionary = json.data as Dictionary
	var meta: Dictionary = data.get("meta", {}) as Dictionary
	return int(meta.get("anam", 0))


func _show_book_cinematic_then_forest() -> void:
	var cinematic: BookCinematic = BookCinematic.new()
	cinematic.set_intro("Broceliande", "Les brumes de Broceliande se levent lentement, devoilant les racines noueuses des chenes millenaires. Au loin, une lueur ambre pulse — le Nemeton, coeur sacre de la foret. Le sentier s'ouvre devant toi, etroit et sinueux. Merlin murmure dans le vent: 'Les signes te guideront, mais chaque choix porte son ombre.' Des champignons phosphorescents dessinent un chemin entre les pierres dressees. La foret attend.")
	add_child(cinematic)
	cinematic.cinematic_complete.connect(func():
		PixelTransition.transition_to(FOREST_SCENE)
	)
