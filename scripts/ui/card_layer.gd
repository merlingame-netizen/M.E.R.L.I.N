class_name CardLayer
extends RefCounted
## Lightweight data class representing a single composed layer in the card illustration.
## Built by CardSceneCompositor, consumed by the scene-building step.

## Layer types (ordered back-to-front)
enum Type { SKY, TERRAIN, SUBJECT, ATMOSPHERE }

var type: Type = Type.SKY
var texture_path: String = ""
var shader_material: ShaderMaterial = null  ## For procedural layers (sky, silhouette)
var display_size: Vector2 = Vector2(440.0, 220.0)
var anchor: Vector2 = Vector2(0.5, 0.5)
var parallax_factor: float = 0.0
var tint_blend: float = 0.15
var tags: Array = []
var biomes: Array = []
var idle_motion: Dictionary = {}  ## {"type": "sway"|"breathe"|"drift", "amplitude": float, "period": float}
var particles_config: Dictionary = {}  ## For atmosphere layers: {"type": "fog"|"wisp", "count": int, ...}


static func create(p_type: Type, p_parallax: float) -> CardLayer:
	var layer := CardLayer.new()
	layer.type = p_type
	layer.parallax_factor = p_parallax
	return layer


static func create_shader(p_type: Type, p_parallax: float, p_shader: ShaderMaterial) -> CardLayer:
	var layer := CardLayer.new()
	layer.type = p_type
	layer.parallax_factor = p_parallax
	layer.shader_material = p_shader
	return layer


static func create_texture(p_type: Type, p_parallax: float, p_path: String) -> CardLayer:
	var layer := CardLayer.new()
	layer.type = p_type
	layer.parallax_factor = p_parallax
	layer.texture_path = p_path
	return layer
