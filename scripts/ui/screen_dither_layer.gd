## CRTLayer — Global CRT terminal post-process effect
## Unified post-process combining distortion + dithering + scanlines + phosphor.
## Replaces the old ScreenDitherLayer (parchment dither) with CRT terminal aesthetic.
## Autoload: ScreenDither (project.godot)

class_name CRTLayer
extends CanvasLayer

const CRT_SHADER := preload("res://shaders/crt_terminal.gdshader")

# CRT preset profiles
const CRT_PRESETS := {
	"off": {
		"global_intensity": 0.0,
	},
	"subtle": {
		"global_intensity": 0.4,
		"curvature": 0.02,
		"scanline_opacity": 0.10,
		"dither_strength": 0.2,
		"phosphor_glow": 0.08,
		"tint_blend": 0.04,
	},
	"medium": {
		"global_intensity": 0.6,
		"curvature": 0.04,
		"scanline_opacity": 0.18,
		"dither_strength": 0.3,
		"phosphor_glow": 0.12,
		"tint_blend": 0.06,
	},
	"heavy": {
		"global_intensity": 0.85,
		"curvature": 0.07,
		"scanline_opacity": 0.28,
		"dither_strength": 0.45,
		"phosphor_glow": 0.18,
		"tint_blend": 0.10,
	},
}

var _rect: ColorRect
var _material: ShaderMaterial
var _current_preset: String = "medium"


func _ready() -> void:
	layer = 100
	_material = ShaderMaterial.new()
	_material.shader = CRT_SHADER

	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)

	# Apply default preset
	set_crt_preset("medium")


# === PUBLIC API — Legacy compatible ===

func set_dither_strength(value: float) -> void:
	_material.set_shader_parameter("dither_strength", value)


func set_color_levels(value: float) -> void:
	_material.set_shader_parameter("color_levels", value)


func set_tint_blend(value: float) -> void:
	_material.set_shader_parameter("tint_blend", value)


func set_pixel_scale(_value: float) -> void:
	pass  # No longer used in unified shader


func set_intensity(value: float) -> void:
	_material.set_shader_parameter("global_intensity", value)


func set_enabled(enabled: bool) -> void:
	visible = enabled


# === NEW CRT API ===

## Set the phosphor tint color (biome-driven)
func set_phosphor_tint(color: Color) -> void:
	_material.set_shader_parameter("phosphor_tint", color)


## Set CRT screen curvature
func set_curvature(value: float) -> void:
	_material.set_shader_parameter("curvature", value)


## Set scanline visibility
func set_scanline_opacity(value: float) -> void:
	_material.set_shader_parameter("scanline_opacity", value)


## Set phosphor glow intensity
func set_phosphor_glow(value: float) -> void:
	_material.set_shader_parameter("phosphor_glow", value)


## Apply a CRT preset ("off", "subtle", "medium", "heavy")
func set_crt_preset(preset_name: String) -> void:
	var preset: Dictionary = CRT_PRESETS.get(preset_name, CRT_PRESETS["medium"])
	_current_preset = preset_name
	for param_name: String in preset:
		_material.set_shader_parameter(param_name, preset[param_name])


## Get the current CRT preset name
func get_crt_preset() -> String:
	return _current_preset


## Set any shader parameter directly (used by ScreenEffects mood system)
func set_shader_parameter(param_name: String, value: Variant) -> void:
	if _material:
		_material.set_shader_parameter(param_name, value)


## Get any shader parameter value
func get_shader_parameter(param_name: String) -> Variant:
	if _material:
		return _material.get_shader_parameter(param_name)
	return null


## Smoothly tween a shader parameter
func tween_parameter(param_name: String, from: float, to: float, duration: float) -> Tween:
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(v: float) -> void: set_shader_parameter(param_name, v), from, to, duration)
	return tw
