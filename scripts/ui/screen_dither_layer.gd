## ScreenDitherLayer — Global post-process dither effect
## Add as child of any scene or use as autoload for persistent effect.
## Renders a full-screen Bayer dithering + warm parchment tint.

class_name ScreenDitherLayer
extends CanvasLayer

const DITHER_SHADER := preload("res://shaders/screen_dither.gdshader")

var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 100
	_material = ShaderMaterial.new()
	_material.shader = DITHER_SHADER

	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)


func set_dither_strength(value: float) -> void:
	_material.set_shader_parameter("dither_strength", value)


func set_color_levels(value: float) -> void:
	_material.set_shader_parameter("color_levels", value)


func set_tint_blend(value: float) -> void:
	_material.set_shader_parameter("tint_blend", value)


func set_pixel_scale(value: float) -> void:
	_material.set_shader_parameter("pixel_scale", value)


func set_intensity(value: float) -> void:
	_material.set_shader_parameter("intensity", value)


func set_enabled(enabled: bool) -> void:
	visible = enabled
