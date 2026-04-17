## RetroRenderPipeline — Unified PSX/N64 retro post-processing (Autoload)
##
## CanvasLayer (layer 98) that applies PS1-era color reduction, dithering,
## time-of-day tinting, and seasonal color grading to ALL scenes.
##
## Sits below ScreenFrame (99) and CRT (100) in the visual stack:
##   Game output → PSX retro (98) → Celtic border (99) → CRT mood (100)
##
## Reads time/season from GameTimeManager and period from DayNightManager.
## Updates shader uniforms every frame for smooth transitions.
##
## Usage:
##   RetroRenderPipeline.set_preset("full")  # off / subtle / full
##   RetroRenderPipeline.set_biome_tint(Color(1.1, 0.9, 0.85))

extends CanvasLayer

signal preset_changed(preset_name: String)

enum Preset { OFF, SUBTLE, FULL }

const SHADER_PATH := "res://shaders/retro_psx_post.gdshader"

const PRESET_CONFIGS: Dictionary = {
	"off": {
		"intensity": 0.0,
		"color_depth": 64.0,
		"dither_strength": 0.0,
		"grain_amount": 0.0,
		"pixel_scale": 1.0,
	},
	"subtle": {
		"intensity": 0.6,
		"color_depth": 32.0,
		"dither_strength": 0.25,
		"grain_amount": 0.02,
		"pixel_scale": 1.0,
	},
	"full": {
		"intensity": 1.0,
		"color_depth": 24.0,
		"dither_strength": 0.35,
		"grain_amount": 0.035,
		"pixel_scale": 1.5,
	},
}

const SEASON_GRADES: Dictionary = {
	"printemps": Vector3(1.02, 1.07, 1.00),
	"ete": Vector3(1.08, 1.04, 0.95),
	"automne": Vector3(1.10, 0.92, 0.82),
	"hiver": Vector3(0.84, 0.90, 1.08),
}

const PERIOD_TINTS: Dictionary = {
	"night":     Color(0.10, 0.12, 0.25, 0.35),
	"dawn":      Color(0.45, 0.28, 0.15, 0.20),
	"morning":   Color(0.95, 0.90, 0.80, 0.05),
	"midday":    Color(1.0, 1.0, 0.95, 0.0),
	"afternoon": Color(0.90, 0.82, 0.65, 0.08),
	"dusk":      Color(0.55, 0.25, 0.10, 0.25),
	"evening":   Color(0.20, 0.15, 0.28, 0.30),
}

var _rect: ColorRect
var _material: ShaderMaterial
var _current_preset: String = "subtle"
var _biome_tint_override: Color = Color.WHITE
var _has_biome_override: bool = false
var _target_tint: Color = Color(1.0, 1.0, 0.95, 0.0)
var _current_tint: Color = Color(1.0, 1.0, 0.95, 0.0)
var _target_season: Vector3 = Vector3(1.0, 1.0, 1.0)
var _current_season: Vector3 = Vector3(1.0, 1.0, 1.0)

const TINT_LERP_SPEED := 1.5


func _ready() -> void:
	layer = 98
	_build_overlay()
	_connect_signals()
	_apply_preset(_current_preset)
	_sync_time_and_season()


func _process(delta: float) -> void:
	if _material == null:
		return
	_current_tint = _current_tint.lerp(_target_tint, delta * TINT_LERP_SPEED)
	_current_season = _current_season.lerp(_target_season, delta * TINT_LERP_SPEED)
	_material.set_shader_parameter("time_tint", _current_tint)
	_material.set_shader_parameter("season_grade", Color(_current_season.x, _current_season.y, _current_season.z))
	_material.set_shader_parameter("time_offset", fmod(Time.get_ticks_msec() / 1000.0, 1000.0))


func set_preset(preset_name: String) -> void:
	if not PRESET_CONFIGS.has(preset_name):
		push_warning("[RetroRenderPipeline] Unknown preset: %s" % preset_name)
		return
	_current_preset = preset_name
	_apply_preset(preset_name)
	preset_changed.emit(preset_name)


func get_preset() -> String:
	return _current_preset


func set_biome_tint(tint: Color) -> void:
	_biome_tint_override = tint
	_has_biome_override = true
	_update_season_target()


func clear_biome_tint() -> void:
	_has_biome_override = false
	_update_season_target()


func set_intensity(value: float) -> void:
	if _material:
		_material.set_shader_parameter("intensity", clampf(value, 0.0, 1.0))


func _build_overlay() -> void:
	var shader: Shader = null
	if ResourceLoader.exists(SHADER_PATH):
		shader = load(SHADER_PATH) as Shader
	if shader == null:
		push_warning("[RetroRenderPipeline] Shader not found: %s" % SHADER_PATH)
		return

	_material = ShaderMaterial.new()
	_material.shader = shader

	_rect = ColorRect.new()
	_rect.name = "RetroPSXRect"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)


func _connect_signals() -> void:
	var dnm: Node = get_node_or_null("/root/DayNightManager")
	if dnm and dnm.has_signal("period_changed"):
		dnm.period_changed.connect(_on_period_changed)

	var gtm: Node = get_node_or_null("/root/GameTimeManager")
	if gtm and gtm.has_signal("season_changed"):
		gtm.season_changed.connect(_on_season_changed)


func _apply_preset(preset_name: String) -> void:
	if _material == null:
		return
	var cfg: Dictionary = PRESET_CONFIGS.get(preset_name, PRESET_CONFIGS["subtle"])
	for key: String in cfg:
		_material.set_shader_parameter(key, cfg[key])


func _sync_time_and_season() -> void:
	var dnm: Node = get_node_or_null("/root/DayNightManager")
	if dnm and dnm.has_method("get_time_of_day"):
		var period: String = dnm.get_time_of_day()
		_on_period_changed(period)

	var gtm: Node = get_node_or_null("/root/GameTimeManager")
	if gtm:
		var season: String = gtm.get("current_season") if gtm.get("current_season") else "printemps"
		_on_season_changed(season)


func _on_period_changed(period: String) -> void:
	_target_tint = PERIOD_TINTS.get(period, Color(1.0, 1.0, 0.95, 0.0))


func _on_season_changed(_season: String) -> void:
	_update_season_target()


func _update_season_target() -> void:
	if _has_biome_override:
		_target_season = Vector3(_biome_tint_override.r, _biome_tint_override.g, _biome_tint_override.b)
		return
	var gtm: Node = get_node_or_null("/root/GameTimeManager")
	var season: String = "printemps"
	if gtm:
		season = gtm.get("current_season") if gtm.get("current_season") else "printemps"
	var grade: Vector3 = SEASON_GRADES.get(season, Vector3(1.0, 1.0, 1.0))
	_target_season = grade
