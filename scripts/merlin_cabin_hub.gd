extends Node
## MerlinCabinHub — 3D interior scene: Merlin's cabin between runs.
## Tapestry (talent tree), wall map (biome choice), Merlin NPC (LLM dialogue).
## Post-run: stats display, Anam rewards, progression.

const FOREST_SCENE: String = "res://scenes/BroceliandeForest3D.tscn"
const MENU_SCENE: String = "res://scenes/Menu3DPC.tscn"

var _world: Node3D
var _camera: Camera3D
var _ui_layer: CanvasLayer
var _orbit_angle: float = 0.0


func _ready() -> void:
	_build_3d_cabin()
	_build_ui_overlay()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(delta: float) -> void:
	# Gentle camera sway inside cabin
	_orbit_angle += delta * 0.05
	if is_instance_valid(_camera):
		_camera.position.x = sin(_orbit_angle) * 0.3
		_camera.position.y = 2.0 + sin(_orbit_angle * 0.7) * 0.1
		_camera.look_at(Vector3(0, 1.5, -2), Vector3.UP)


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

	# Tapestry talent tree (back wall — SubViewport rendered to Quad3D)
	var tap_viewport: TapestryTalentTree = TapestryTalentTree.new()
	add_child(tap_viewport)

	var tapestry: MeshInstance3D = MeshInstance3D.new()
	var tap_mesh: QuadMesh = QuadMesh.new()
	tap_mesh.size = Vector2(3.0, 2.3)
	tapestry.mesh = tap_mesh
	tapestry.position = Vector3(1.5, 2.2, -3.9)
	var tap_mat: StandardMaterial3D = StandardMaterial3D.new()
	tap_mat.albedo_texture = tap_viewport.get_texture()
	tap_mat.roughness = 1.0
	tap_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tapestry.material_override = tap_mat
	_world.add_child(tapestry)

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

	# Bottom buttons
	var btn_box: HBoxContainer = HBoxContainer.new()
	btn_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	btn_box.offset_top = -60; btn_box.offset_bottom = -12
	btn_box.offset_left = 100; btn_box.offset_right = -100
	btn_box.add_theme_constant_override("separation", 20)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_ui_layer.add_child(btn_box)

	var btn_data: Array[Dictionary] = [
		{"text": "Nouvelle Quete", "action": "quest"},
		{"text": "Tapisserie", "action": "tapestry"},
		{"text": "Carte du Monde", "action": "map"},
		{"text": "Retour", "action": "menu"},
	]
	for bd in btn_data:
		var btn: Button = Button.new()
		btn.text = str(bd["text"])
		btn.custom_minimum_size = Vector2(0, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if font: btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", pal.get("phosphor", Color(0.2, 1.0, 0.4)))
		var s: StyleBoxFlat = StyleBoxFlat.new()
		s.bg_color = Color(0.02, 0.04, 0.02, 0.8)
		s.border_color = pal.get("phosphor_dim", Color(0.12, 0.6, 0.24))
		s.set_border_width_all(1)
		s.set_corner_radius_all(4)
		s.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", s)
		btn.pressed.connect(_on_hub_action.bind(str(bd["action"])))
		btn_box.add_child(btn)


func _on_hub_action(action: String) -> void:
	if is_instance_valid(SFXManager):
		SFXManager.play("click")
	match action:
		"quest":
			_show_book_cinematic_then_forest()
		"tapestry":
			print("[Cabin] Tapestry (talent tree) — TODO")
		"map":
			print("[Cabin] World map — TODO")
		"menu":
			PixelTransition.transition_to(MENU_SCENE)


func _show_book_cinematic_then_forest() -> void:
	var cinematic: BookCinematic = BookCinematic.new()
	cinematic.set_intro("Broceliande", "Les brumes de Broceliande se levent lentement, devoilant les racines noueuses des chenes millenaires. Au loin, une lueur ambre pulse — le Nemeton, coeur sacre de la foret. Le sentier s'ouvre devant toi, etroit et sinueux. Merlin murmure dans le vent: 'Les signes te guideront, mais chaque choix porte son ombre.' Des champignons phosphorescents dessinent un chemin entre les pierres dressees. La foret attend.")
	add_child(cinematic)
	cinematic.cinematic_complete.connect(func():
		PixelTransition.transition_to(FOREST_SCENE)
	)
