extends "res://scripts/MenuPrincipal3DWeather.gd"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_rng.seed = 0x0B0C311
	_build_parchment_background()
	_build_time_tint_layer()
	_build_mist_layer()
	_start_mist_animation()
	_resize_background_viewport()
	_layout_moon_rays()
	resized.connect(_on_resized)


func _process(delta: float) -> void:
	_update_solar_cycle()
	_animate_clouds(delta)
	_animate_forest_animals(delta)
	_update_weather_schedule(delta)
	_process_storm_flash(delta)


func _on_resized() -> void:
	_resize_background_viewport()
	_layout_moon_rays()


func _input(_event: InputEvent) -> void:
	# Background-only helper: no input handling.
	pass
