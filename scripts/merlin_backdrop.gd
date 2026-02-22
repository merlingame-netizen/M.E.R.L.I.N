extends CanvasLayer

const PAPER_TINT_BASE := Color(0.96, 0.92, 0.84, 1.0)
const PAPER_TINT_VARIANCE := 0.015

var background: ColorRect
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	layer = -100
	rng.randomize()
	background = ColorRect.new()
	background.name = "MerlinBackdrop"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := load("res://shaders/merlin_paper.gdshader") as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var tint := Color(
			PAPER_TINT_BASE.r + rng.randf_range(-PAPER_TINT_VARIANCE, PAPER_TINT_VARIANCE),
			PAPER_TINT_BASE.g + rng.randf_range(-PAPER_TINT_VARIANCE, PAPER_TINT_VARIANCE),
			PAPER_TINT_BASE.b + rng.randf_range(-PAPER_TINT_VARIANCE, PAPER_TINT_VARIANCE),
			1.0
		)
		mat.set_shader_parameter("paper_tint", tint)
		mat.set_shader_parameter("grain_strength", 0.04)
		mat.set_shader_parameter("vignette_strength", 0.12)
		mat.set_shader_parameter("vignette_softness", 0.55)
		mat.set_shader_parameter("warp_strength", 0.0018)
		background.material = mat
	background.color = PAPER_TINT_BASE
	add_child(background)
