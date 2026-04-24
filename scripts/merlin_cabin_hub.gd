## ═══════════════════════════════════════════════════════════════════════════════
## MerlinCabinHub — First-person PS1-era cabin hub (M.E.R.L.I.N.)
## ═══════════════════════════════════════════════════════════════════════════════
## The player walks inside Merlin's cabin using an FPS rig (WASD + mouse-look).
## Interactive objects (detected via raycast hit + E key):
##   • wall_map       → emits run_requested(biome, oghams) to start a run
##   • tapestry       → emits talent_tree_requested
##   • door           → emits quit_requested (back to menu/exit)
##   • cauldron       → future dialogue with Merlin
##
## Signals match the contract expected by GameFlowController.wire_hub().
## ═══════════════════════════════════════════════════════════════════════════════
extends Node3D
class_name MerlinCabinHub

const FOREST_SCENE: String = "res://scenes/BroceliandeForest3D.tscn"
const MENU_SCENE: String = "res://scenes/Menu3DPC.tscn"
const FPS_RIG_SCENE: String = "res://scenes/fps/FpsRig.tscn"

# Hub contract signals (consumed by GameFlow.wire_hub)
signal run_requested(biome_id: String, selected_oghams: Array)
signal talent_tree_requested()
signal quit_requested()

var _world: Node3D
var _rig: Node  # FpsCameraController (CharacterBody3D)
var _ui_layer: CanvasLayer
var _hint_label: Label
var _selected_biome: String = "foret_broceliande"
var _selected_oghams: Array = ["beith"]


func _ready() -> void:
	_build_world()
	_spawn_fps_rig()
	_build_ui_overlay()
	_register_with_gameflow()


func _register_with_gameflow() -> void:
	var gf: Node = get_node_or_null("/root/GameFlow")
	if gf != null and gf.has_method("wire_hub"):
		gf.wire_hub(self)
	# Also pull equipped oghams from store
	var store: Node = get_node_or_null("/root/MerlinStore")
	if store != null and "state" in store:
		var st: Dictionary = store.state
		var oghams: Dictionary = st.get("oghams", {})
		var equipped: Array = oghams.get("skills_equipped", [])
		if equipped.size() > 0:
			_selected_oghams = equipped.duplicate()


func _build_world() -> void:
	_world = Node3D.new()
	_world.name = "CabinWorld"
	add_child(_world)

	# ─── ENVIRONMENT ──────────────────────────────────────────────────────────
	var env_res: Environment = Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.04, 0.03, 0.02)
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.15, 0.12, 0.08)
	env_res.ambient_light_energy = 0.6
	env_res.fog_enabled = true
	env_res.fog_light_color = Color(0.08, 0.06, 0.04)
	env_res.fog_density = 0.03
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env_res
	_world.add_child(world_env)

	# ─── LIGHTS ───────────────────────────────────────────────────────────────
	var fire: OmniLight3D = OmniLight3D.new()
	fire.position = Vector3(-1.0, 1.5, -2.0)
	fire.light_color = Color(1.0, 0.7, 0.3)
	fire.light_energy = 2.5
	fire.omni_range = 8.0
	_world.add_child(fire)

	var fill: OmniLight3D = OmniLight3D.new()
	fill.position = Vector3(2.0, 2.5, 0.0)
	fill.light_color = Color(0.3, 0.4, 0.6)
	fill.light_energy = 0.5
	fill.omni_range = 6.0
	_world.add_child(fill)

	# ─── GEOMETRY + STATIC BODIES ──────────────────────────────────────────────
	# Floor (walkable)
	_add_static_box(Vector3(0, -0.1, 0), Vector3(10, 0.2, 10), Color(0.15, 0.10, 0.06), "")
	# Walls (enclosure, collide)
	_add_static_box(Vector3(0, 2, -4.5), Vector3(10, 4, 0.2), Color(0.12, 0.08, 0.05), "")  # back
	_add_static_box(Vector3(0, 2, 4.5), Vector3(10, 4, 0.2), Color(0.12, 0.08, 0.05), "")   # front
	_add_static_box(Vector3(-4.5, 2, 0), Vector3(0.2, 4, 10), Color(0.10, 0.07, 0.04), "")  # left
	_add_static_box(Vector3(4.5, 2, 0), Vector3(0.2, 4, 10), Color(0.10, 0.07, 0.04), "")   # right
	_add_static_box(Vector3(0, 4, 0), Vector3(10, 0.15, 10), Color(0.08, 0.06, 0.03), "")   # ceiling

	# ─── INTERACTIVE OBJECTS ──────────────────────────────────────────────────
	# Wall map — tall panel on left wall, interact_id "wall_map"
	_add_static_box(Vector3(-4.30, 2.0, -1.0), Vector3(0.2, 2.0, 2.5),
		Color(0.85, 0.80, 0.65), "wall_map")

	# Tapestry — on back wall, interact_id "tapestry"
	_add_static_box(Vector3(1.5, 2.2, -4.30), Vector3(3.0, 2.3, 0.15),
		Color(0.5, 0.15, 0.20), "tapestry")

	# Cauldron — spherical center piece, interact_id "cauldron"
	_add_interactive_sphere(Vector3(-1.0, 0.4, -2.5), 0.5,
		Color(0.15, 0.15, 0.15), "cauldron")

	# Door — front wall, interact_id "door" (exit to menu)
	_add_static_box(Vector3(0, 1.2, 4.35), Vector3(1.2, 2.4, 0.15),
		Color(0.25, 0.15, 0.08), "door")

	# Fairy lanterns (atmosphere, no interaction)
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
			randf_range(-3.0, 3.0))
		_world.add_child(lantern)


## Adds a solid box with collision. If interact_id is non-empty, the collision
## body carries metadata so the FPS raycast can pick it up.
func _add_static_box(pos: Vector3, sz: Vector3, color: Color, interact_id: String) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	if not interact_id.is_empty():
		body.set_meta("interact_id", interact_id)
	_world.add_child(body)

	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = sz
	cs.shape = bs
	body.add_child(cs)

	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)


func _add_interactive_sphere(pos: Vector3, radius: float, color: Color, interact_id: String) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	body.set_meta("interact_id", interact_id)
	_world.add_child(body)

	var cs: CollisionShape3D = CollisionShape3D.new()
	var ss: SphereShape3D = SphereShape3D.new()
	ss.radius = radius
	cs.shape = ss
	body.add_child(cs)

	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.7
	mat.roughness = 0.4
	mi.material_override = mat
	body.add_child(mi)


func _spawn_fps_rig() -> void:
	var rig_scene: PackedScene = load(FPS_RIG_SCENE)
	if rig_scene == null:
		push_error("[CabinHub] Cannot load FpsRig scene")
		return
	_rig = rig_scene.instantiate()
	_rig.position = Vector3(0, 0.1, 2.5)  # near front door, looking in
	_rig.set_bounds(Vector3(-4.0, 0.0, -4.0), Vector3(4.0, 3.0, 4.0))
	add_child(_rig)

	# Wire interaction signals
	if _rig.has_signal("interaction_hovered"):
		_rig.connect("interaction_hovered", _on_hovered)
	if _rig.has_signal("interaction_lost"):
		_rig.connect("interaction_lost", _on_hover_lost)
	if _rig.has_signal("interaction_triggered"):
		_rig.connect("interaction_triggered", _on_interact)


func _build_ui_overlay() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	var font: Font = MerlinVisual.get_font("terminal") if Engine.has_singleton("MerlinVisual") or is_instance_valid(MerlinVisual) else null
	var pal: Dictionary = {}
	if Engine.has_singleton("MerlinVisual") or is_instance_valid(MerlinVisual):
		pal = MerlinVisual.CRT_PALETTE

	# Title (top)
	var title: Label = Label.new()
	title.text = "L'Antre de Merlin"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.offset_top = 20
	if font: title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", pal.get("amber", Color(1.0, 0.75, 0.2)))
	_ui_layer.add_child(title)

	# Interaction hint (center, appears when raycast hits interactable)
	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_CENTER)
	_hint_label.offset_top = 40
	_hint_label.offset_left = -200
	_hint_label.offset_right = 200
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.visible = false
	if font: _hint_label.add_theme_font_override("font", font)
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", pal.get("phosphor", Color(0.2, 1.0, 0.4)))
	_ui_layer.add_child(_hint_label)

	# Crosshair (center dot)
	var ch: Panel = Panel.new()
	ch.set_anchors_preset(Control.PRESET_CENTER)
	ch.offset_left = -2; ch.offset_top = -2
	ch.offset_right = 2; ch.offset_bottom = 2
	var ch_style: StyleBoxFlat = StyleBoxFlat.new()
	ch_style.bg_color = Color(pal.get("phosphor", Color(0.2, 1.0, 0.4)))
	ch.add_theme_stylebox_override("panel", ch_style)
	_ui_layer.add_child(ch)

	# Bottom help
	var help: Label = Label.new()
	help.text = "[WASD] marcher  [Souris] regarder  [E] interagir  [Echap] liberer la souris"
	help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.offset_bottom = -12
	help.offset_top = -30
	if font: help.add_theme_font_override("font", font)
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", pal.get("phosphor_dim", Color(0.12, 0.6, 0.24)))
	_ui_layer.add_child(help)


func _on_hovered(interact_id: String, _target: Node) -> void:
	var prompt: String = ""
	match interact_id:
		"wall_map":
			prompt = "> Carte de Broceliande  [E] partir en quete"
		"tapestry":
			prompt = "> Tapisserie des Talents  [E] consulter"
		"cauldron":
			prompt = "> Chaudron  [E] (bientot)"
		"door":
			prompt = "> Porte de sortie  [E] retour au menu"
		_:
			prompt = "> %s  [E]" % interact_id
	_hint_label.text = prompt
	_hint_label.visible = true


func _on_hover_lost() -> void:
	_hint_label.visible = false


func _on_interact(interact_id: String, _target: Node) -> void:
	match interact_id:
		"wall_map":
			# Liberate mouse and emit run request
			if _rig != null and _rig.has_method("set_mouse_captured"):
				_rig.set_mouse_captured(false)
			run_requested.emit(_selected_biome, _selected_oghams)
		"tapestry":
			talent_tree_requested.emit()
		"door":
			quit_requested.emit()
		"cauldron":
			pass  # TODO: Merlin dialogue
