@tool
extends FogVolume

## PS1-style volumetric fog effect
## Creates a subtle, layered fog that responds to light

@export_group("Fog Appearance")
@export var fog_density: float = 0.15:
	set(value):
		fog_density = value
		_update_fog_material()
@export var fog_albedo: Color = Color(0.7, 0.75, 0.85, 1.0):
	set(value):
		fog_albedo = value
		_update_fog_material()
@export var fog_emission: Color = Color(0.05, 0.04, 0.06, 1.0):
	set(value):
		fog_emission = value
		_update_fog_material()

@export_group("PS1 Style Settings")
@export var height_falloff: float = 2.0:
	set(value):
		height_falloff = value
		_update_fog_material()
@export var edge_fade: float = 0.3:
	set(value):
		edge_fade = value
		_update_fog_material()

var _fog_material: FogMaterial

func _ready() -> void:
	_create_fog_material()
	_setup_environment_fog()

func _create_fog_material() -> void:
	_fog_material = FogMaterial.new()
	_update_fog_material()
	material = _fog_material

func _update_fog_material() -> void:
	if _fog_material == null:
		return
	
	_fog_material.density = fog_density
	_fog_material.albedo = fog_albedo
	_fog_material.emission = fog_emission
	_fog_material.height_falloff = height_falloff
	_fog_material.edge_fade = edge_fade

func _setup_environment_fog() -> void:
	# Find WorldEnvironment and enable volumetric fog
	var world_env = get_tree().root.find_child("WorldEnvironment", true, false)
	if world_env and world_env is WorldEnvironment:
		var env = world_env.environment
		if env:
			# Enable volumetric fog in environment
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = 0.02
			env.volumetric_fog_albedo = Color(0.8, 0.85, 0.9)
			env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
			env.volumetric_fog_emission_energy = 0.0
			env.volumetric_fog_anisotropy = 0.3
			env.volumetric_fog_length = 64.0
			env.volumetric_fog_detail_spread = 2.0
			env.volumetric_fog_gi_inject = 0.5
			env.volumetric_fog_temporal_reprojection_enabled = true
			env.volumetric_fog_temporal_reprojection_amount = 0.9
			print("[VolumetricFog] Environment fog enabled")
