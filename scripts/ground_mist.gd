@tool
extends FogVolume

## Dense ground mist layer - PS1 style
## Creates thick fog crawling along the floor

@export var mist_density: float = 0.35
@export var mist_color: Color = Color(0.6, 0.65, 0.75, 1.0)

var _material: FogMaterial

func _ready() -> void:
	_material = FogMaterial.new()
	_material.density = mist_density
	_material.albedo = mist_color
	_material.emission = Color(0.02, 0.02, 0.03)
	_material.height_falloff = 4.0  # Strong falloff to stay low
	_material.edge_fade = 0.5
	material = _material
