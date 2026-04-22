extends CanvasLayer
## SeasonalAtmosphere — Global seasonal particle overlay + CRT color grading.
## Persistent across all scenes. Connects to GameTimeManager for season/period.
## Uses seasonal_particles.gdshader for 2D particle effects (petals, leaves, snow).
## Drives seasonal fog/tint modulation on ScreenDither (CRTLayer).

const SHADER_PATH: String = "res://shaders/seasonal_particles.gdshader"

const SEASON_TO_INT: Dictionary = {
	"printemps": 0,
	"ete": 1,
	"automne": 2,
	"hiver": 3,
}

const PARTICLE_COLORS: Dictionary = {
	"printemps": Color(1.0, 0.85, 0.90, 0.6),
	"ete": Color(1.0, 1.0, 0.8, 0.2),
	"automne": Color(0.85, 0.55, 0.15, 0.7),
	"hiver": Color(0.95, 0.97, 1.0, 0.8),
}

const PARTICLE_DENSITIES: Dictionary = {
	"printemps": 0.3,
	"ete": 0.12,
	"automne": 0.35,
	"hiver": 0.4,
}

const NIGHT_DENSITY_MULT: float = 0.6
const DAWN_DUSK_DENSITY_MULT: float = 1.2

var _overlay: ColorRect
var _shader_mat: ShaderMaterial
var _current_season: String = "printemps"
var _current_period: String = "matin"
var _base_density: float = 0.3
var _active: bool = true
var _transition_tween: Tween


func _ready() -> void:
	layer = 2
	_build_overlay()
	_connect_time_manager()


func _build_overlay() -> void:
	if not ResourceLoader.exists(SHADER_PATH):
		push_warning("[SeasonalAtmosphere] Shader not found: %s" % SHADER_PATH)
		return

	var shader: Shader = load(SHADER_PATH)
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader

	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.material = _shader_mat
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	_apply_season("printemps")


func _connect_time_manager() -> void:
	var gtm: Node = get_node_or_null("/root/GameTimeManager")
	if not gtm:
		call_deferred("_connect_time_manager_deferred")
		return
	_wire_signals(gtm)


func _connect_time_manager_deferred() -> void:
	var gtm: Node = get_node_or_null("/root/GameTimeManager")
	if not gtm:
		push_warning("[SeasonalAtmosphere] GameTimeManager not found")
		return
	_wire_signals(gtm)


func _wire_signals(gtm: Node) -> void:
	if gtm.has_signal("season_changed") and not gtm.is_connected("season_changed", _on_season_changed):
		gtm.season_changed.connect(_on_season_changed)
	if gtm.has_signal("period_changed") and not gtm.is_connected("period_changed", _on_period_changed):
		gtm.period_changed.connect(_on_period_changed)

	if gtm.has_method("get_season"):
		_on_season_changed(gtm.get_season())
	elif "current_season" in gtm:
		_on_season_changed(gtm.current_season)

	if gtm.has_method("get_period"):
		_on_period_changed(gtm.get_period())
	elif "_current_period" in gtm:
		_on_period_changed(gtm._current_period)


func _on_season_changed(season: String) -> void:
	if season == _current_season:
		return
	_current_season = season
	_animate_season_transition(season)
	_update_crt_season(season)


func _on_period_changed(period: String) -> void:
	_current_period = period
	_update_density_for_period()


func _animate_season_transition(season: String) -> void:
	if _transition_tween and _transition_tween.is_running():
		_transition_tween.kill()

	var target_color: Color = PARTICLE_COLORS.get(season, Color.WHITE)
	var target_density: float = PARTICLE_DENSITIES.get(season, 0.3)
	var season_int: int = SEASON_TO_INT.get(season, 0)

	if not _shader_mat:
		return

	_shader_mat.set_shader_parameter("season_type", season_int)

	var current_color: Variant = _shader_mat.get_shader_parameter("particle_color")
	if current_color == null:
		current_color = Color.WHITE

	_transition_tween = create_tween()
	_transition_tween.set_ease(Tween.EASE_IN_OUT)
	_transition_tween.set_trans(Tween.TRANS_SINE)
	_transition_tween.set_parallel(true)

	_transition_tween.tween_method(
		func(c: Color) -> void: _shader_mat.set_shader_parameter("particle_color", c),
		current_color as Color, target_color, 2.0
	)

	_base_density = target_density
	var period_mult: float = _get_period_density_mult()
	_transition_tween.tween_method(
		func(d: float) -> void: _shader_mat.set_shader_parameter("particle_density", d),
		_shader_mat.get_shader_parameter("particle_density") as float,
		target_density * period_mult, 2.0
	)


func _apply_season(season: String) -> void:
	_current_season = season
	if not _shader_mat:
		return

	var season_int: int = SEASON_TO_INT.get(season, 0)
	var color: Color = PARTICLE_COLORS.get(season, Color.WHITE)
	var density: float = PARTICLE_DENSITIES.get(season, 0.3)

	_shader_mat.set_shader_parameter("season_type", season_int)
	_shader_mat.set_shader_parameter("particle_color", color)
	_shader_mat.set_shader_parameter("particle_density", density)
	_shader_mat.set_shader_parameter("animation_speed", 1.0)
	_base_density = density
	_update_crt_season(season)


func _update_density_for_period() -> void:
	if not _shader_mat:
		return
	var mult: float = _get_period_density_mult()
	_shader_mat.set_shader_parameter("particle_density", _base_density * mult)


func _get_period_density_mult() -> float:
	match _current_period:
		"nuit", "Nuit", "night":
			return NIGHT_DENSITY_MULT
		"aube", "Aube", "dawn", "crepuscule", "Crepuscule", "dusk":
			return DAWN_DUSK_DENSITY_MULT
		_:
			return 1.0


func _update_crt_season(season: String) -> void:
	var dither: Node = get_node_or_null("/root/ScreenDither")
	if dither and dither.has_method("set_season_modulation"):
		dither.set_season_modulation(season)


func set_enabled(enabled: bool) -> void:
	_active = enabled
	visible = enabled


func pause() -> void:
	if _overlay:
		_overlay.visible = false


func resume() -> void:
	if _overlay and _active:
		_overlay.visible = true


func force_season(season: String) -> void:
	_apply_season(season)
	_update_crt_season(season)


func get_current_season() -> String:
	return _current_season
