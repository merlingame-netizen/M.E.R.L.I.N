extends Control

@export var base_resolution := Vector2i(320, 180)

@onready var viewport := $GameViewport
@onready var view := $ViewportView

func _ready():
	if viewport:
		viewport.size = base_resolution
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	view.texture = viewport.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_update_view()
	get_viewport().size_changed.connect(_update_view)
	_update_shader_params()

func _update_view():
	var screen_size = get_viewport_rect().size
	var scale = floor(min(screen_size.x / base_resolution.x, screen_size.y / base_resolution.y))
	if scale < 1:
		scale = 1
	var size = Vector2(base_resolution.x * scale, base_resolution.y * scale)
	view.size = size
	view.position = (screen_size - size) * 0.5
	_update_shader_params()

func _update_shader_params():
	if view.material and view.material is ShaderMaterial:
		var mat = view.material as ShaderMaterial
		mat.set_shader_parameter("render_size", Vector2(base_resolution.x, base_resolution.y))
		mat.set_shader_parameter("screen_size", get_viewport_rect().size)

func _unhandled_input(event):
	if viewport:
		viewport.push_input(event)
