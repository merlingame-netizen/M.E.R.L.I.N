## CRTLayer — Global CRT terminal post-process effect
## Unified post-process combining distortion + dithering + scanlines + phosphor.
## Replaces the old ScreenDitherLayer (parchment dither) with CRT terminal aesthetic.
## Autoload: ScreenDither (project.godot)

class_name CRTLayer
extends CanvasLayer

const CRT_SHADER := preload("res://shaders/crt_terminal.gdshader")
const PSX_SHADER := preload("res://shaders/retro_psx_post.gdshader")

enum RenderMode { CRT, PSX }

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

const PSX_PRESETS := {
	"off": {"global_intensity": 0.0},
	"subtle": {
		"global_intensity": 0.5,
		"pixel_size": 2.0,
		"color_depth": 48.0,
		"dither_strength": 0.25,
		"scanline_opacity": 0.04,
		"scanline_count": 240.0,
		"saturation_boost": 1.10,
		"contrast": 1.03,
		"curvature": 0.01,
		"vignette_intensity": 0.08,
		"tint_blend": 0.04,
	},
	"medium": {
		"global_intensity": 0.7,
		"pixel_size": 3.0,
		"color_depth": 32.0,
		"dither_strength": 0.35,
		"scanline_opacity": 0.08,
		"scanline_count": 240.0,
		"saturation_boost": 1.15,
		"contrast": 1.05,
		"curvature": 0.02,
		"vignette_intensity": 0.12,
		"tint_blend": 0.06,
	},
	"heavy": {
		"global_intensity": 0.9,
		"pixel_size": 4.0,
		"color_depth": 24.0,
		"dither_strength": 0.45,
		"scanline_opacity": 0.12,
		"scanline_count": 200.0,
		"saturation_boost": 1.20,
		"contrast": 1.08,
		"curvature": 0.03,
		"vignette_intensity": 0.16,
		"tint_blend": 0.08,
	},
}

const PSX_BIOME_PROFILES := {
	"broceliande": {
		"tint_color": Color(0.92, 1.0, 0.88),
		"fog_color": Color(0.08, 0.12, 0.06),
		"fog_blend": 0.03,
	},
	"landes": {
		"tint_color": Color(1.0, 0.95, 0.85),
		"fog_color": Color(0.18, 0.14, 0.08),
		"fog_blend": 0.04,
	},
	"cotes": {
		"tint_color": Color(0.90, 0.95, 1.0),
		"fog_color": Color(0.10, 0.14, 0.20),
		"fog_blend": 0.05,
	},
	"villages": {
		"tint_color": Color(1.0, 0.97, 0.92),
		"fog_color": Color(0.15, 0.12, 0.10),
		"fog_blend": 0.02,
	},
	"cercles": {
		"tint_color": Color(0.88, 0.86, 0.96),
		"fog_color": Color(0.06, 0.04, 0.12),
		"fog_blend": 0.06,
	},
	"marais": {
		"tint_color": Color(0.88, 0.96, 0.84),
		"fog_color": Color(0.06, 0.10, 0.05),
		"fog_blend": 0.07,
	},
	"collines": {
		"tint_color": Color(0.98, 0.96, 0.88),
		"fog_color": Color(0.14, 0.12, 0.06),
		"fog_blend": 0.03,
	},
	"iles": {
		"tint_color": Color(0.90, 0.94, 1.0),
		"fog_color": Color(0.08, 0.10, 0.18),
		"fog_blend": 0.05,
	},
}

var _rect: ColorRect
var _material: ShaderMaterial
var _current_preset: String = "medium"
var _render_mode: int = RenderMode.PSX
var _current_biome: String = ""
var _transition_tween: Tween


const _PERIOD_TIME_MAP := {
	"night": 0.05, "dawn": 0.22, "morning": 0.35,
	"midday": 0.50, "afternoon": 0.62, "dusk": 0.78, "evening": 0.88,
}


func _ready() -> void:
	layer = 100
	_material = ShaderMaterial.new()
	_material.shader = PSX_SHADER

	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)

	set_psx_preset("medium")

	var dnm: Node = get_node_or_null("/root/DayNightManager")
	if dnm and dnm.has_signal("period_changed"):
		dnm.period_changed.connect(_on_period_changed)
		if dnm.has_method("get_time_of_day"):
			_on_period_changed(dnm.get_time_of_day())


func _on_period_changed(period: String) -> void:
	var t: float = _PERIOD_TIME_MAP.get(period, 0.5)
	set_time_tint(t)


# === PUBLIC API — Legacy compatible ===

func set_dither_strength(value: float) -> void:
	_material.set_shader_parameter("dither_strength", value)


func set_color_levels(value: float) -> void:
	if _render_mode == RenderMode.PSX:
		_material.set_shader_parameter("color_depth", value)
	else:
		_material.set_shader_parameter("color_levels", value)


func set_tint_blend(value: float) -> void:
	_material.set_shader_parameter("tint_blend", value)


func set_pixel_scale(_value: float) -> void:
	pass  # No longer used in unified shader


func set_intensity(value: float) -> void:
	_material.set_shader_parameter("global_intensity", value)


func set_enabled(enabled: bool) -> void:
	visible = enabled
	if _rect:
		_rect.visible = enabled


# === NEW CRT API ===

## Set the phosphor/biome tint color
func set_phosphor_tint(color: Color) -> void:
	if _render_mode == RenderMode.PSX:
		_material.set_shader_parameter("tint_color", color)
	else:
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


# === PSX RETRO MODE API ===

func set_render_mode(mode: int) -> void:
	if mode == _render_mode:
		return
	_render_mode = mode
	match mode:
		RenderMode.CRT:
			_material.shader = CRT_SHADER
			set_crt_preset(_current_preset)
		RenderMode.PSX:
			_material.shader = PSX_SHADER
			set_psx_preset(_current_preset)


func get_render_mode() -> int:
	return _render_mode


func set_psx_preset(preset_name: String) -> void:
	var preset: Dictionary = PSX_PRESETS.get(preset_name, PSX_PRESETS["medium"])
	_current_preset = preset_name
	if _render_mode != RenderMode.PSX:
		set_render_mode(RenderMode.PSX)
		return
	for param_name: String in preset:
		_material.set_shader_parameter(param_name, preset[param_name])
	if _current_biome != "":
		_apply_biome_colors(_current_biome)


func set_biome(biome_key: String, animate: bool = true) -> void:
	_current_biome = biome_key
	if _render_mode != RenderMode.PSX:
		return
	if animate:
		_animate_biome_transition(biome_key)
	else:
		_apply_biome_colors(biome_key)


func set_time_tint(time_normalized: float) -> void:
	if _render_mode != RenderMode.PSX:
		return
	var warmth: float = 0.0
	if time_normalized < 0.25:
		warmth = lerp(0.04, 0.0, time_normalized / 0.25)
	elif time_normalized < 0.5:
		warmth = 0.0
	elif time_normalized < 0.75:
		warmth = lerp(0.0, 0.06, (time_normalized - 0.5) / 0.25)
	else:
		warmth = lerp(0.06, 0.04, (time_normalized - 0.75) / 0.25)

	var dawn_dusk: Color = Color(1.0, 0.92 - warmth, 0.82 - warmth * 2.0)
	var night: Color = Color(0.85, 0.88, 1.0)
	var day: Color = Color(1.0, 0.98, 0.95)

	var tint: Color
	if time_normalized < 0.2:
		tint = night.lerp(dawn_dusk, time_normalized / 0.2)
	elif time_normalized < 0.35:
		tint = dawn_dusk.lerp(day, (time_normalized - 0.2) / 0.15)
	elif time_normalized < 0.7:
		tint = day
	elif time_normalized < 0.85:
		tint = day.lerp(dawn_dusk, (time_normalized - 0.7) / 0.15)
	else:
		tint = dawn_dusk.lerp(night, (time_normalized - 0.85) / 0.15)

	_material.set_shader_parameter("tint_color", tint)


func _apply_biome_colors(biome_key: String) -> void:
	var profile: Dictionary = PSX_BIOME_PROFILES.get(biome_key, {})
	for param_name: String in profile:
		_material.set_shader_parameter(param_name, profile[param_name])


func _animate_biome_transition(biome_key: String) -> void:
	if _transition_tween and _transition_tween.is_running():
		_transition_tween.kill()
	var profile: Dictionary = PSX_BIOME_PROFILES.get(biome_key, {})
	if profile.is_empty():
		return
	_transition_tween = create_tween()
	_transition_tween.set_ease(Tween.EASE_IN_OUT)
	_transition_tween.set_trans(Tween.TRANS_SINE)
	_transition_tween.set_parallel(true)
	for param_name: String in profile:
		var target: Variant = profile[param_name]
		var current: Variant = _material.get_shader_parameter(param_name)
		if current == null:
			_material.set_shader_parameter(param_name, target)
			continue
		if target is Color and current is Color:
			_transition_tween.tween_method(
				func(v: Color) -> void: _material.set_shader_parameter(param_name, v),
				current as Color, target as Color, 1.2
			)
		elif target is float and current is float:
			_transition_tween.tween_method(
				func(v: float) -> void: _material.set_shader_parameter(param_name, v),
				current as float, target as float, 1.2
			)
