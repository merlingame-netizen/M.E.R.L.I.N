@tool
extends Node3D

## Exterior window with dynamic sunlight and view
## Creates a realistic window with light rays and exterior backdrop

@export_group("Window Dimensions")
@export var window_width: float = 1.2
@export var window_height: float = 1.6
@export var frame_thickness: float = 0.08
@export var frame_depth: float = 0.15

@export_group("Light Settings")
@export var sun_color: Color = Color(1.0, 0.95, 0.8):
	set(value):
		sun_color = value
		_update_light()
@export var sun_energy: float = 3.5:
	set(value):
		sun_energy = value
		_update_light()
@export var light_animation: bool = true
@export var flicker_intensity: float = 0.1

@export_group("Exterior View")
@export var sky_color: Color = Color(0.4, 0.6, 0.9)
@export var forest_color: Color = Color(0.15, 0.35, 0.15)

var _frame_mesh: MeshInstance3D
var _glass_mesh: MeshInstance3D
var _sun_light: SpotLight3D
var _exterior_backdrop: MeshInstance3D
var _time: float = 0.0
var _base_energy: float

func _ready() -> void:
	_setup_window_frame()
	_setup_glass()
	_setup_exterior_backdrop()
	_setup_light()
	_base_energy = sun_energy

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() and light_animation:
		_animate_light(delta)

func _setup_window_frame() -> void:
	_frame_mesh = get_node_or_null("WindowFrame") as MeshInstance3D
	if not _frame_mesh:
		return
	
	# Create window frame using CSG-like approach with boxes
	var frame_mat = StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.35, 0.25, 0.15)  # Dark wood
	frame_mat.roughness = 0.8
	
	# Main frame outline
	var outer_box = BoxMesh.new()
	outer_box.size = Vector3(window_width + frame_thickness * 2, window_height + frame_thickness * 2, frame_depth)
	_frame_mesh.mesh = outer_box
	_frame_mesh.material_override = frame_mat
	
	# Create cross beams
	_create_cross_beam(Vector3(0, 0, 0))  # Horizontal center
	_create_cross_beam(Vector3(0, 0, 0), true)  # Vertical center

func _create_cross_beam(pos: Vector3, vertical: bool = false) -> void:
	var beam = MeshInstance3D.new()
	var beam_mesh = BoxMesh.new()
	
	if vertical:
		beam_mesh.size = Vector3(frame_thickness * 0.6, window_height, frame_depth * 0.8)
	else:
		beam_mesh.size = Vector3(window_width, frame_thickness * 0.6, frame_depth * 0.8)
	
	beam.mesh = beam_mesh
	beam.position = pos
	
	var beam_mat = StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.3, 0.22, 0.12)
	beam_mat.roughness = 0.85
	beam.material_override = beam_mat
	
	add_child(beam)

func _setup_glass() -> void:
	_glass_mesh = get_node_or_null("WindowGlass") as MeshInstance3D
	if not _glass_mesh:
		return
	
	var glass_mesh_inst = QuadMesh.new()
	glass_mesh_inst.size = Vector2(window_width - 0.05, window_height - 0.05)
	_glass_mesh.mesh = glass_mesh_inst
	_glass_mesh.position = Vector3(0.02, 0, 0)
	
	# Glass material with slight tint
	var glass_mat = StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.15)
	glass_mat.roughness = 0.1
	glass_mat.metallic = 0.1
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glass_mesh.material_override = glass_mat

func _setup_exterior_backdrop() -> void:
	# Create a backdrop showing forest/sky through window
	_exterior_backdrop = MeshInstance3D.new()
	_exterior_backdrop.name = "ExteriorBackdrop"
	
	var backdrop_mesh = QuadMesh.new()
	backdrop_mesh.size = Vector2(window_width * 3, window_height * 2)
	_exterior_backdrop.mesh = backdrop_mesh
	_exterior_backdrop.position = Vector3(-0.5, 0, 0)
	
	# Gradient material simulating forest and sky
	var backdrop_mat = StandardMaterial3D.new()
	backdrop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	backdrop_mat.albedo_color = sky_color.lerp(forest_color, 0.3)
	backdrop_mat.emission_enabled = true
	backdrop_mat.emission = sky_color
	backdrop_mat.emission_energy_multiplier = 0.8
	_exterior_backdrop.material_override = backdrop_mat
	
	add_child(_exterior_backdrop)

func _setup_light() -> void:
	_sun_light = get_node_or_null("SunLight") as SpotLight3D
	if not _sun_light:
		return
	
	_sun_light.light_color = sun_color
	_sun_light.light_energy = sun_energy
	_sun_light.shadow_enabled = true
	_sun_light.shadow_bias = 0.02
	
	# Volumetric fog interaction
	_sun_light.light_volumetric_fog_energy = 2.0

func _update_light() -> void:
	if _sun_light:
		_sun_light.light_color = sun_color
		_sun_light.light_energy = sun_energy

func _animate_light(delta: float) -> void:
	if not _sun_light:
		return
	
	_time += delta
	
	# Subtle cloud passing effect
	var cloud_factor = sin(_time * 0.3) * 0.5 + 0.5
	cloud_factor = cloud_factor * flicker_intensity
	
	# Gentle flicker from leaves/branches
	var leaf_flicker = sin(_time * 2.5) * sin(_time * 3.7) * 0.05
	
	_sun_light.light_energy = _base_energy * (1.0 - cloud_factor + leaf_flicker)
