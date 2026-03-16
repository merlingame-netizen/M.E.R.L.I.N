## ═══════════════════════════════════════════════════════════════════════════════
## Transition Biome — Weather System Module
## ═══════════════════════════════════════════════════════════════════════════════
## Weather overlay, solar clock, time-of-day logic.
## ═══════════════════════════════════════════════════════════════════════════════

class_name TransitionBiomeWeather
extends RefCounted

const WEATHER_CLEAR := "clear"
const WEATHER_CLOUDY := "cloudy"
const WEATHER_RAIN := "rain"
const WEATHER_STORM := "storm"
const WEATHER_MIST := "mist"
const WEATHER_SNOW := "snow"

var weather_mode: String = ""
var weather_light_factor: float = 1.0
var storm_flash_timer: float = 0.0
var _weather_rng := RandomNumberGenerator.new()
var _weather_tween: Tween


func _init() -> void:
	_weather_rng.seed = int(Time.get_unix_time_from_system())


func get_time_of_day_label(hour: int) -> String:
	if hour >= 6 and hour < 12:   return "Matin"
	if hour >= 12 and hour < 18:  return "Après-midi"
	if hour >= 18 and hour < 22:  return "Soir"
	return "Nuit"


func get_current_season() -> String:
	var month: int = Time.get_datetime_dict_from_system().get("month", 1)
	if month >= 3 and month <= 5: return "printemps"
	if month >= 6 and month <= 8: return "ete"
	if month >= 9 and month <= 11: return "automne"
	return "hiver"


func current_time_float() -> float:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	return float(now.get("hour", 12)) + float(now.get("minute", 0)) / 60.0 + float(now.get("second", 0)) / 3600.0


func is_moon_hour(time_float: float) -> bool:
	var hour := int(floor(fposmod(time_float, 24.0)))
	return hour >= 22 or hour < 6


func weather_mode_for_hour(hour: int) -> String:
	if hour >= 0 and hour < 5:
		return WEATHER_MIST
	if hour >= 5 and hour < 9:
		return WEATHER_CLEAR
	if hour >= 9 and hour < 13:
		return WEATHER_CLOUDY
	if hour >= 13 and hour < 17:
		return WEATHER_RAIN
	if hour >= 17 and hour < 21:
		return WEATHER_STORM
	if hour >= 21 and hour < 23:
		return WEATHER_CLOUDY
	return WEATHER_SNOW


func apply_weather_for_hour(hour: int, instant: bool, host: Control, weather_overlay: ColorRect, pixel_container: Control) -> void:
	apply_weather_mode(weather_mode_for_hour(hour), instant, host, weather_overlay, pixel_container)


func apply_weather_mode(mode: String, instant: bool, host: Control, weather_overlay: ColorRect, pixel_container: Control) -> void:
	weather_mode = mode
	var overlay_base: Color = MerlinVisual.CRT_PALETTE.phosphor
	var target_overlay := Color(overlay_base.r, overlay_base.g, overlay_base.b, 0.06)
	weather_light_factor = 1.0

	match mode:
		WEATHER_CLEAR:
			target_overlay = Color(overlay_base.r * 0.7, overlay_base.g * 1.1, overlay_base.b * 1.35, 0.04)
			weather_light_factor = 1.0
		WEATHER_CLOUDY:
			target_overlay = Color(overlay_base.r * 0.8, overlay_base.g * 1.1, overlay_base.b * 1.2, 0.12)
			weather_light_factor = 0.9
		WEATHER_RAIN:
			target_overlay = Color(overlay_base.r * 0.7, overlay_base.g * 0.9, overlay_base.b * 1.05, 0.20)
			weather_light_factor = 0.78
		WEATHER_STORM:
			target_overlay = Color(overlay_base.r * 0.45, overlay_base.g * 0.65, overlay_base.b * 0.78, 0.28)
			weather_light_factor = 0.62
			storm_flash_timer = _weather_rng.randf_range(1.2, 3.3)
		WEATHER_MIST:
			target_overlay = Color(overlay_base.r, overlay_base.g * 1.15, overlay_base.b * 1.05, 0.18)
			weather_light_factor = 0.72
		WEATHER_SNOW:
			target_overlay = Color(overlay_base.r * 1.1, overlay_base.g * 1.3, overlay_base.b * 1.35, 0.16)
			weather_light_factor = 0.8

	var light_color := Color(
		clampf(weather_light_factor * 1.03, 0.60, 1.1),
		clampf(weather_light_factor, 0.56, 1.06),
		clampf(weather_light_factor * 1.08, 0.62, 1.14),
		1.0
	)

	if instant:
		if weather_overlay and is_instance_valid(weather_overlay):
			weather_overlay.color = target_overlay
		if pixel_container and is_instance_valid(pixel_container):
			pixel_container.modulate = light_color
	else:
		if _weather_tween:
			_weather_tween.kill()
		_weather_tween = host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if weather_overlay and is_instance_valid(weather_overlay):
			_weather_tween.tween_property(weather_overlay, "color", target_overlay, 1.2)
		if pixel_container and is_instance_valid(pixel_container):
			_weather_tween.parallel().tween_property(pixel_container, "modulate", light_color, 1.2)


func process_storm_flash(delta: float, weather_overlay: ColorRect) -> void:
	if weather_mode != WEATHER_STORM:
		return
	storm_flash_timer -= delta
	if storm_flash_timer <= 0.0 and weather_overlay and is_instance_valid(weather_overlay):
		var flash_strength := _weather_rng.randf_range(0.06, 0.16)
		weather_overlay.color = weather_overlay.color.lightened(flash_strength)
		storm_flash_timer = _weather_rng.randf_range(1.8, 4.8)


func configure_weather_system(weather_overlay: ColorRect, clock_panel: PanelContainer, clock_label: Label, host: Control, pixel_container: Control) -> void:
	var base_overlay: Color = MerlinVisual.CRT_PALETTE.phosphor
	weather_overlay.color = Color(base_overlay.r, base_overlay.g, base_overlay.b, 0.06)

	# Style clock panel
	var clock_style := StyleBoxFlat.new()
	var clock_bg: Color = MerlinVisual.CRT_PALETTE.bg_dark
	var clock_border: Color = MerlinVisual.CRT_PALETTE.border
	clock_style.bg_color = Color(clock_bg.r, clock_bg.g, clock_bg.b, 0.9)
	clock_style.border_color = Color(clock_border.r, clock_border.g, clock_border.b, 0.85)
	clock_style.set_border_width_all(1)
	clock_style.set_corner_radius_all(6)
	clock_style.content_margin_left = 10
	clock_style.content_margin_right = 10
	clock_style.content_margin_top = 4
	clock_style.content_margin_bottom = 3
	clock_panel.add_theme_stylebox_override("panel", clock_style)

	# Style clock label
	clock_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)

	layout_solar_arc_geometry(clock_panel, host)
	var initial_hour := int(Time.get_datetime_dict_from_system().get("hour", 12))
	apply_weather_for_hour(initial_hour, true, host, weather_overlay, pixel_container)
	update_solar_clock(clock_panel, clock_label, host)


func layout_solar_arc_geometry(clock_panel: PanelContainer, host: Control) -> void:
	var vs := host.get_viewport_rect().size
	if clock_panel and is_instance_valid(clock_panel):
		clock_panel.position = Vector2(vs.x * 0.5 - 52.0, 22.0)


func update_solar_clock(clock_panel: PanelContainer, clock_label: Label, host: Control) -> void:
	layout_solar_arc_geometry(clock_panel, host)
	var now: Dictionary = Time.get_datetime_dict_from_system()
	if clock_label and is_instance_valid(clock_label):
		clock_label.text = get_time_of_day_label(int(now.get("hour", 12)))


func sun_position_for_time(time_float: float, host: Control, landscape_origin: Vector2, pixel_size: float) -> Vector2:
	var vs := host.get_viewport_rect().size
	var t := clampf(fposmod(time_float, 24.0) / 24.0, 0.0, 1.0)
	var margin := clampf(vs.x * 0.06, 40.0, 140.0)
	var x := lerpf(margin, vs.x - margin, t)
	var y := clampf(vs.y * 0.14, 48.0, 126.0)
	if landscape_origin != Vector2.ZERO and pixel_size > 0.0:
		var landscape_top := landscape_origin.y - pixel_size * 0.7
		y = minf(y, maxf(40.0, landscape_top - 18.0))
	return Vector2(x, y)
