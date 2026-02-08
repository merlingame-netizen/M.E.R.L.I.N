extends ColorRect
class_name PS1ShaderController

## === PARAMÈTRES PS1 EXPOSÉS ===

@export_group("Pixelisation")
@export_range(1.0, 10.0) var pixel_size: float = 3.0:
	set(v):
		pixel_size = v
		_update()

@export_range(8.0, 64.0) var color_depth: float = 24.0:
	set(v):
		color_depth = v
		_update()

@export_group("Effets PS1")
@export_range(0.0, 0.05) var dither_strength: float = 0.025:
	set(v):
		dither_strength = v
		_update()

@export_range(0.0, 0.005) var wobble_intensity: float = 0.0015:
	set(v):
		wobble_intensity = v
		_update()

@export_range(0.0, 0.3) var scanline_strength: float = 0.08:
	set(v):
		scanline_strength = v
		_update()

@export_group("Post-Process")
@export_range(0.0, 0.6) var vignette_strength: float = 0.25:
	set(v):
		vignette_strength = v
		_update()

@export_range(0.7, 1.4) var saturation_boost: float = 1.1:
	set(v):
		saturation_boost = v
		_update()

@export_range(0.7, 1.4) var contrast: float = 1.08:
	set(v):
		contrast = v
		_update()

@export_group("Contrôles")
@export var shader_enabled: bool = true:
	set(v):
		shader_enabled = v
		visible = v

func _ready() -> void:
	_update()

func _update() -> void:
	if material and material is ShaderMaterial:
		var mat := material as ShaderMaterial
		mat.set_shader_parameter("pixel_size", pixel_size)
		mat.set_shader_parameter("color_depth", color_depth)
		mat.set_shader_parameter("dither_strength", dither_strength)
		mat.set_shader_parameter("wobble_intensity", wobble_intensity)
		mat.set_shader_parameter("scanline_strength", scanline_strength)
		mat.set_shader_parameter("vignette_strength", vignette_strength)
		mat.set_shader_parameter("saturation_boost", saturation_boost)
		mat.set_shader_parameter("contrast", contrast)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_P:
				shader_enabled = !shader_enabled
				print("Shader PS1: ", "ON" if shader_enabled else "OFF")
			KEY_PAGEUP:
				pixel_size = min(pixel_size + 0.5, 10.0)
				print("Pixel size: %.1f" % pixel_size)
			KEY_PAGEDOWN:
				pixel_size = max(pixel_size - 0.5, 1.0)
				print("Pixel size: %.1f" % pixel_size)
			KEY_HOME:
				color_depth = min(color_depth + 4.0, 64.0)
				print("Color depth: %.0f" % color_depth)
			KEY_END:
				color_depth = max(color_depth - 4.0, 8.0)
				print("Color depth: %.0f" % color_depth)
			KEY_INSERT:
				wobble_intensity = 0.003 if wobble_intensity < 0.002 else 0.0
				print("Wobble: ", "ON" if wobble_intensity > 0 else "OFF")
