extends ColorRect
class_name PixelShaderController

## Taille des pixels (1 = pas de pixelisation, 8 = très pixelisé)
@export_range(1.0, 12.0) var pixel_size: float = 3.0:
	set(value):
		pixel_size = value
		_update_shader()

## Nombre de niveaux de couleur par canal
@export_range(4.0, 32.0) var color_levels: float = 16.0:
	set(value):
		color_levels = value
		_update_shader()

## Force du contour
@export_range(0.0, 1.5) var outline_strength: float = 0.5:
	set(value):
		outline_strength = value
		_update_shader()

## Couleur du contour
@export var outline_color: Color = Color(0.12, 0.06, 0.03, 1.0):
	set(value):
		outline_color = value
		_update_shader()

## Saturation
@export_range(0.5, 2.0) var saturation: float = 1.25:
	set(value):
		saturation = value
		_update_shader()

## Activer/désactiver l'effet
@export var enabled: bool = true:
	set(value):
		enabled = value
		visible = value

func _ready() -> void:
	_update_shader()

func _update_shader() -> void:
	if material and material is ShaderMaterial:
		var mat = material as ShaderMaterial
		mat.set_shader_parameter("pixel_size", pixel_size)
		mat.set_shader_parameter("color_levels", color_levels)
		mat.set_shader_parameter("outline_strength", outline_strength)
		mat.set_shader_parameter("outline_color", outline_color)
		mat.set_shader_parameter("saturation", saturation)

func _input(event: InputEvent) -> void:
	# Touches pour ajuster en temps réel
	if event.is_action_pressed("ui_page_up"):
		pixel_size = min(pixel_size + 1.0, 12.0)
		print("Pixel size: ", pixel_size)
	elif event.is_action_pressed("ui_page_down"):
		pixel_size = max(pixel_size - 1.0, 1.0)
		print("Pixel size: ", pixel_size)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_P:
		enabled = !enabled
		print("Pixel shader: ", "ON" if enabled else "OFF")
