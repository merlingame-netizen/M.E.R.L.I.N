extends "res://scripts/MenuPrincipalMerlin.gd"

const WEATHER_CLEAR := "clear"
const WEATHER_CLOUDY := "cloudy"
const WEATHER_RAIN := "rain"
const WEATHER_STORM := "storm"
const WEATHER_MIST := "mist"
const WEATHER_SNOW := "snow"

var _bg_rng := RandomNumberGenerator.new()
var _bg_container: SubViewportContainer
var _bg_viewport: SubViewport
var _bg_root: Node3D
var _bg_environment: Environment
var _bg_sky: Sky
var _bg_sky_material: ProceduralSkyMaterial
var _use_volumetric_fog: bool = false
var _blue_sun: DirectionalLight3D
var _moon_light: DirectionalLight3D
var _bg_camera: Camera3D
var _moon_ray_layer: Control
var _moon_rays: Array[ColorRect] = []
var _moon_glow: Panel

var _cloud_root: Node3D
var _cloud_mesh_material: StandardMaterial3D
var _cloud_nodes: Array[MeshInstance3D] = []
var _cloud_scroll_speed: float = 0.8

var _seasonal_particles: GPUParticles3D
var _clock_panel: PanelContainer
var _tower_root: Node3D
var _tower_ground_position: Vector3 = Vector3(58.0, 0.0, -8.0)
var _tower_target: Vector3 = Vector3(58.0, 18.0, -8.0)
var _camera_focus_target: Vector3 = Vector3(30.0, 14.0, -10.0)
var _tower_key_light: SpotLight3D
var _tower_window_light: OmniLight3D
var _tower_window_beams: Array[SpotLight3D] = []
var _tower_smoke: GPUParticles3D
var _forest_animals: Array[Node3D] = []

var _rain_particles: GPUParticles3D
var _snow_particles: GPUParticles3D
var _storm_light: OmniLight3D

var _weather_mode: String = ""
var _weather_check_timer: float = 0.0
var _storm_flash_timer: float = 0.0
var _weather_light_factor: float = 1.0
var _weather_tween: Tween


func _build_parchment_background() -> void:
	_bg_rng.seed = 0x0B0C311
	_build_3d_background()

	parchment_background = ColorRect.new()
	parchment_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	parchment_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parchment_background.color = Color(0.02, 0.05, 0.08, 0.14)
	add_child(parchment_background)

	_build_moon_rays_layer()


func _build_time_tint_layer() -> void:
	if time_tint_layer and is_instance_valid(time_tint_layer):
		time_tint_layer.queue_free()
	time_tint_layer = ColorRect.new()
	time_tint_layer.name = "TimeTintLayer"
	time_tint_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	time_tint_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_tint_layer.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(time_tint_layer)

	# Keep the menu panel/buttons visually stable: tint only the 3D background.
	if _bg_container and is_instance_valid(_bg_container):
		move_child(time_tint_layer, _bg_container.get_index() + 1)
	elif parchment_background and is_instance_valid(parchment_background):
		move_child(time_tint_layer, parchment_background.get_index())
	if _moon_ray_layer and is_instance_valid(_moon_ray_layer):
		var moon_layer_index := time_tint_layer.get_index() + 1
		if _clock_panel and is_instance_valid(_clock_panel):
			moon_layer_index = _clock_panel.get_index()
		elif card and is_instance_valid(card):
			moon_layer_index = card.get_index()
		move_child(_moon_ray_layer, moon_layer_index)

	_update_time_tint()


func _build_clock() -> void:
	if _clock_panel and is_instance_valid(_clock_panel):
		_clock_panel.queue_free()

	_clock_panel = PanelContainer.new()
	_clock_panel.name = "ClockPanel"
	_clock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clock_panel)

	clock_label = Label.new()
	clock_label.name = "ClockLabel"
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_panel.add_child(clock_label)
	_update_clock_text()


func _apply_clock_style() -> void:
	if _clock_panel:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = MerlinVisual.PALETTE.paper_warm
		panel_style.border_color = Color(0.56, 0.42, 0.24, 0.90)
		panel_style.border_width_left = 2
		panel_style.border_width_top = 2
		panel_style.border_width_right = 2
		panel_style.border_width_bottom = 2
		panel_style.corner_radius_top_left = 14
		panel_style.corner_radius_top_right = 14
		panel_style.corner_radius_bottom_left = 14
		panel_style.corner_radius_bottom_right = 14
		panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
		panel_style.shadow_size = 8
		panel_style.shadow_offset = Vector2(0.0, 2.0)
		panel_style.content_margin_left = 10
		panel_style.content_margin_top = 6
		panel_style.content_margin_right = 10
		panel_style.content_margin_bottom = 6
		_clock_panel.add_theme_stylebox_override("panel", panel_style)
		_clock_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if not clock_label:
		return
	if body_font:
		clock_label.add_theme_font_override("font", body_font)
	clock_label.add_theme_font_size_override("font_size", 24)
	clock_label.add_theme_color_override("font_color", MerlinVisual.PALETTE.ink)
	clock_label.add_theme_color_override("font_outline_color", Color(0.98, 0.96, 0.90, 0.58))
	clock_label.add_theme_constant_override("outline_size", 1)
	clock_label.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _layout_clock() -> void:
	if _clock_panel:
		_clock_panel.position = Vector2(CORNER_BUTTON_MARGIN, 14.0)
		_clock_panel.size = Vector2(260.0, 84.0)
		if clock_label:
			clock_label.position = Vector2(12.0, 8.0)
			clock_label.size = _clock_panel.size - Vector2(24.0, 16.0)


func _apply_corner_button_style(btn: Button) -> void:
	if btn == null:
		return

	btn.flat = false
	btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", MerlinVisual.PALETTE.ink)
	btn.add_theme_color_override("font_hover_color", MerlinVisual.PALETTE.accent)
	btn.add_theme_color_override("font_pressed_color", MerlinVisual.PALETTE.accent)
	btn.pivot_offset = CORNER_BUTTON_SIZE * 0.5

	var normal := StyleBoxFlat.new()
	normal.bg_color = MerlinVisual.PALETTE.paper_warm
	normal.border_color = Color(0.56, 0.42, 0.24, 0.88)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 16
	normal.corner_radius_top_right = 16
	normal.corner_radius_bottom_left = 16
	normal.corner_radius_bottom_right = 16
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0.0, 2.0)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.98, 0.95, 0.90, 1.0)
	hover.border_color = Color(0.64, 0.49, 0.28, 1.0)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.90, 0.84, 0.74, 1.0)
	pressed.border_color = Color(0.62, 0.48, 0.28, 1.0)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", normal)


func _build_moon_rays_layer() -> void:
	if _moon_ray_layer and is_instance_valid(_moon_ray_layer):
		_moon_ray_layer.queue_free()

	_moon_ray_layer = Control.new()
	_moon_ray_layer.name = "MoonRaysLayer"
	_moon_ray_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_moon_ray_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_moon_ray_layer)

	_moon_rays.clear()
	for i in range(8):
		var ray := ColorRect.new()
		ray.name = "MoonRay%d" % i
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ray.color = Color(0.66, 0.54, 0.98, 0.0)
		ray.pivot_offset = Vector2(4.0, 0.0)
		_moon_ray_layer.add_child(ray)
		_moon_rays.append(ray)

	_moon_glow = Panel.new()
	_moon_glow.name = "MoonGlow"
	_moon_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(0.68, 0.56, 0.98, 0.28)
	glow_style.corner_radius_top_left = 60
	glow_style.corner_radius_top_right = 60
	glow_style.corner_radius_bottom_left = 60
	glow_style.corner_radius_bottom_right = 60
	_moon_glow.add_theme_stylebox_override("panel", glow_style)
	_moon_ray_layer.add_child(_moon_glow)

	if time_tint_layer and is_instance_valid(time_tint_layer):
		move_child(_moon_ray_layer, time_tint_layer.get_index() + 1)
	elif _bg_container and is_instance_valid(_bg_container):
		move_child(_moon_ray_layer, _bg_container.get_index() + 2)

	_layout_moon_rays()


func _moon_anchor_for_time(time_float: float, rect_size: Vector2) -> Vector2:
	var orbit := fposmod((time_float + 12.0) / 24.0, 1.0)
	var x := rect_size.x * (0.68 + sin(orbit * TAU) * 0.16)
	var y_wave := 0.12 + (1.0 - cos(orbit * TAU)) * 0.06
	return Vector2(clampf(x, rect_size.x * 0.18, rect_size.x * 0.90), rect_size.y * y_wave)


func _layout_moon_rays() -> void:
	if _moon_ray_layer == null:
		return
	var rect_size := get_viewport_rect().size
	if rect_size.x <= 2.0 or rect_size.y <= 2.0:
		return

	var moon_anchor := _moon_anchor_for_time(_current_time_float(), rect_size)
	var ray_count: int = _moon_rays.size()
	var max_index: int = maxi(1, ray_count - 1)
	for i in range(ray_count):
		var ray: ColorRect = _moon_rays[i]
		if ray == null:
			continue
		var ratio := float(i) / float(max_index)
		var width := lerpf(3.0, 16.0, ratio)
		var length := lerpf(rect_size.y * 0.28, rect_size.y * 0.94, ratio)
		ray.position = moon_anchor + Vector2(-width * 0.5, 0.0)
		ray.size = Vector2(width, length)
		ray.rotation_degrees = lerpf(-34.0, 36.0, ratio) + sin(float(i) * 1.7) * 3.0

	if _moon_glow:
		_moon_glow.position = moon_anchor - Vector2(52.0, 52.0)
		_moon_glow.size = Vector2(104.0, 104.0)


func _update_moon_rays(daylight: float) -> void:
	if _moon_ray_layer == null:
		return

	var weather_penalty := 0.0
	match _weather_mode:
		WEATHER_STORM:
			weather_penalty = 0.24
		WEATHER_RAIN:
			weather_penalty = 0.12
		WEATHER_CLOUDY:
			weather_penalty = 0.07
		WEATHER_MIST:
			weather_penalty = 0.15
		_:
			weather_penalty = 0.0

	var night := clampf(1.0 - daylight, 0.0, 1.0)
	var visibility := clampf((night - 0.14) * 1.2 - weather_penalty, 0.0, 1.0)
	var pulse := 0.90 + sin(float(Time.get_ticks_msec()) * 0.0016) * 0.10
	var ray_count: int = _moon_rays.size()
	var max_index: int = maxi(1, ray_count - 1)
	for i in range(ray_count):
		var ray: ColorRect = _moon_rays[i]
		if ray == null:
			continue
		var ratio := float(i) / float(max_index)
		ray.color = Color(0.66, 0.54, 0.98, visibility * (0.08 + ratio * 0.14) * pulse)

	if _moon_glow:
		_moon_glow.modulate = Color(1.0, 1.0, 1.0, visibility * (0.52 + 0.24 * pulse))

	_layout_moon_rays()


func _build_mist_layer() -> void:
	mist_layer = ColorRect.new()
	mist_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	mist_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mist_layer.color = Color(0.02, 0.02, 0.02, 1.0)
	mist_layer.modulate.a = 0.0
	add_child(mist_layer)


func _start_mist_animation() -> void:
	if mist_layer == null:
		return
	if _mist_tween:
		_mist_tween.kill()
	_mist_tween = create_tween().set_loops()
	_mist_tween.tween_property(mist_layer, "color", Color(0.03, 0.03, 0.03, 1.0), 6.2).set_trans(Tween.TRANS_SINE)
	_mist_tween.tween_property(mist_layer, "color", Color(0.07, 0.07, 0.08, 1.0), 6.2).set_trans(Tween.TRANS_SINE)


func _build_seasonal_effects() -> void:
	if _bg_root == null:
		return
	_seasonal_particles = GPUParticles3D.new()
	_seasonal_particles.amount = 820
	_seasonal_particles.lifetime = 4.8
	_seasonal_particles.preprocess = 1.2
	_seasonal_particles.one_shot = false
	_seasonal_particles.emitting = true
	_seasonal_particles.position = Vector3(0.0, 26.0, 4.0)
	_seasonal_particles.visibility_aabb = AABB(Vector3(-190.0, -18.0, -150.0), Vector3(380.0, 120.0, 280.0))
	var particle_mesh := QuadMesh.new()
	particle_mesh.size = Vector2(0.14, 0.14)
	_seasonal_particles.draw_pass_1 = particle_mesh
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(180.0, 1.0, 120.0)
	proc.direction = Vector3(0.0, -1.0, 0.0)
	proc.spread = 42.0
	proc.gravity = Vector3(0.0, -5.0, 0.0)
	proc.initial_velocity_min = 1.4
	proc.initial_velocity_max = 5.0
	proc.angular_velocity_min = -1.4
	proc.angular_velocity_max = 1.6
	proc.scale_min = 0.35
	proc.scale_max = 0.82
	proc.color = Color(0.78, 0.56, 0.28, 0.66)
	_seasonal_particles.process_material = proc
	_bg_root.add_child(_seasonal_particles)


func _process_seasonal_effects(_delta: float) -> void:
	if _seasonal_particles == null:
		return
	var proc := _seasonal_particles.process_material as ParticleProcessMaterial
	if proc == null:
		return
	match current_season:
		"HIVER":
			_seasonal_particles.amount = 420
			proc.gravity = Vector3(0.0, -2.8, 0.0)
			proc.initial_velocity_min = 1.0
			proc.initial_velocity_max = 2.8
			proc.spread = 20.0
			proc.color = Color(0.90, 0.95, 1.0, 0.72)
		"PRINTEMPS":
			_seasonal_particles.amount = 760
			proc.gravity = Vector3(0.0, -4.0, 0.0)
			proc.initial_velocity_min = 1.2
			proc.initial_velocity_max = 4.2
			proc.spread = 34.0
			proc.color = Color(0.95, 0.76, 0.86, 0.58)
		"AUTOMNE":
			_seasonal_particles.amount = 980
			proc.gravity = Vector3(0.0, -6.4, 0.0)
			proc.initial_velocity_min = 1.6
			proc.initial_velocity_max = 6.2
			proc.spread = 52.0
			proc.color = Color(0.82, 0.54, 0.24, 0.72)
		_:
			_seasonal_particles.amount = 620
			proc.gravity = Vector3(0.0, -3.0, 0.0)
			proc.initial_velocity_min = 0.8
			proc.initial_velocity_max = 2.2
			proc.spread = 24.0
			proc.color = Color(0.78, 0.86, 0.98, 0.34)


func _process(delta: float) -> void:
	super(delta)
	_update_solar_cycle()
	_animate_clouds(delta)
	_animate_forest_animals(delta)
	_update_weather_schedule(delta)
	_process_storm_flash(delta)


func _on_resized() -> void:
	super()
	_resize_background_viewport()
	_layout_moon_rays()


func _build_3d_background() -> void:
	_bg_container = SubViewportContainer.new()
	_bg_container.name = "Menu3DBackground"
	_bg_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_container.stretch = false
	_bg_container.stretch_shrink = 1
	add_child(_bg_container)

	_bg_viewport = SubViewport.new()
	_bg_viewport.name = "Menu3DViewport"
	_bg_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_bg_viewport.msaa_3d = Viewport.MSAA_2X
	_bg_container.add_child(_bg_viewport)

	_bg_root = Node3D.new()
	_bg_root.name = "WorldRoot"
	_bg_viewport.add_child(_bg_root)

	_setup_environment()
	_build_camera()
	_build_terrain()
	_build_mountains()
	_build_forest()
	_build_watchtower_setpiece()
	_spawn_forest_animals()
	_build_clouds()
	_build_weather_emitters()
	_resize_background_viewport()
	_layout_moon_rays()
	var initial_hour: int = int(Time.get_time_dict_from_system().hour)
	_apply_weather_for_hour(initial_hour, true)
	_update_solar_cycle()


func _resize_background_viewport() -> void:
	if _bg_viewport == null:
		return
	var vs := get_viewport_rect().size
	_bg_viewport.size = Vector2i(maxi(1, int(vs.x)), maxi(1, int(vs.y)))


func _setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	_bg_environment = Environment.new()
	_bg_environment.background_mode = Environment.BG_SKY
	_bg_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_bg_environment.ambient_light_energy = 0.9
	_bg_environment.fog_enabled = true
	_bg_environment.fog_density = 0.008
	_bg_environment.fog_light_color = Color(0.26, 0.27, 0.30)
	_use_volumetric_fog = _supports_volumetric_fog()
	_bg_environment.set("volumetric_fog_enabled", _use_volumetric_fog)
	if _use_volumetric_fog:
		_bg_environment.set("volumetric_fog_density", 0.034)
		_bg_environment.set("volumetric_fog_albedo", Color(0.18, 0.19, 0.22))
		_bg_environment.set("volumetric_fog_emission", Color(0.00, 0.00, 0.00))

	_bg_sky = Sky.new()
	_bg_sky_material = ProceduralSkyMaterial.new()
	_bg_sky_material.sky_top_color = Color(0.06, 0.08, 0.12)
	_bg_sky_material.sky_horizon_color = Color(0.10, 0.12, 0.16)
	_bg_sky_material.ground_bottom_color = Color(0.02, 0.02, 0.03)
	_bg_sky_material.ground_horizon_color = Color(0.08, 0.09, 0.10)
	_bg_sky.sky_material = _bg_sky_material
	_bg_environment.sky = _bg_sky

	world_env.environment = _bg_environment
	_bg_root.add_child(world_env)

	_blue_sun = DirectionalLight3D.new()
	_blue_sun.name = "BlueSun"
	_blue_sun.light_color = Color(0.35, 0.64, 1.0)
	_blue_sun.light_energy = 1.35
	_blue_sun.shadow_enabled = true
	_blue_sun.shadow_blur = 0.8
	_bg_root.add_child(_blue_sun)

	_moon_light = DirectionalLight3D.new()
	_moon_light.name = "MoonLight"
	_moon_light.light_color = Color(0.70, 0.56, 0.92)
	_moon_light.light_energy = 0.0
	_moon_light.shadow_enabled = true
	_moon_light.shadow_blur = 1.0
	_bg_root.add_child(_moon_light)

	_storm_light = OmniLight3D.new()
	_storm_light.light_color = Color(0.55, 0.72, 1.0)
	_storm_light.light_energy = 0.0
	_storm_light.omni_range = 340.0
	_storm_light.position = Vector3(0.0, 82.0, 0.0)
	_bg_root.add_child(_storm_light)

	_tower_key_light = SpotLight3D.new()
	_tower_key_light.light_color = Color(0.76, 0.72, 0.66)
	_tower_key_light.light_energy = 1.1
	_tower_key_light.spot_range = 180.0
	_tower_key_light.spot_angle = 38.0
	_tower_key_light.position = Vector3(74.0, 44.0, 42.0)
	_tower_key_light.shadow_enabled = true
	_bg_root.add_child(_tower_key_light)

	_tower_window_light = OmniLight3D.new()
	_tower_window_light.light_color = Color(1.0, 0.80, 0.58)
	_tower_window_light.light_energy = 3.2
	_tower_window_light.omni_range = 74.0
	_tower_window_light.position = Vector3(58.0, 20.0, -10.0)
	_bg_root.add_child(_tower_window_light)


func _build_camera() -> void:
	_bg_camera = Camera3D.new()
	_bg_camera.name = "BackgroundCamera"
	_bg_camera.current = true
	_bg_camera.fov = 54.0
	_bg_camera.position = Vector3(-10.0, 22.0, 74.0)
	_bg_root.add_child(_bg_camera)
	_bg_camera.look_at(_camera_focus_target, Vector3.UP)


func _build_terrain() -> void:
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(420.0, 420.0)
	ground.mesh = ground_mesh

	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.08, 0.19, 0.11)
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	_bg_root.add_child(ground)

	var lake := MeshInstance3D.new()
	var lake_mesh := PlaneMesh.new()
	lake_mesh.size = Vector2(130.0, 75.0)
	lake.mesh = lake_mesh
	lake.position = Vector3(-24.0, 0.16, -18.0)
	lake.rotation_degrees = Vector3(0.0, -20.0, 0.0)

	var lake_material := StandardMaterial3D.new()
	lake_material.albedo_color = Color(0.07, 0.23, 0.42, 0.62)
	lake_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lake_material.roughness = 0.18
	lake_material.metallic = 0.08
	lake.material_override = lake_material
	_bg_root.add_child(lake)


func _build_mountains() -> void:
	var mountain_material := StandardMaterial3D.new()
	mountain_material.albedo_color = Color(0.10, 0.13, 0.16)
	mountain_material.roughness = 1.0

	for i in range(22):
		var angle := _bg_rng.randf_range(0.0, TAU)
		var radius := _bg_rng.randf_range(145.0, 188.0)
		var mountain := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = _bg_rng.randf_range(9.0, 20.0)
		mesh.height = mesh.radius * 1.35
		mesh.radial_segments = 10
		mesh.rings = 5
		mountain.mesh = mesh
		mountain.material_override = mountain_material
		mountain.position = Vector3(cos(angle) * radius, _bg_rng.randf_range(3.0, 8.5), sin(angle) * radius)
		mountain.scale = Vector3(_bg_rng.randf_range(1.5, 2.7), _bg_rng.randf_range(0.6, 1.1), _bg_rng.randf_range(1.5, 2.8))
		_bg_root.add_child(mountain)


func _build_forest() -> void:
	for i in range(150):
		var inner_pos := _random_forest_position(24.0, 86.0)
		if _is_in_tower_clear_zone(inner_pos):
			continue
		_spawn_tree(inner_pos, _bg_rng.randf_range(0.82, 1.28))
	for i in range(230):
		var outer_pos := _random_forest_position(86.0, 178.0)
		if _is_in_tower_clear_zone(outer_pos):
			continue
		_spawn_tree(outer_pos, _bg_rng.randf_range(0.92, 1.52))
	for i in range(120):
		var rock_pos := _random_forest_position(28.0, 170.0)
		if _is_in_tower_clear_zone(rock_pos):
			continue
		_spawn_rock(rock_pos, _bg_rng.randf_range(0.7, 1.6))


func _build_watchtower_setpiece() -> void:
	_tower_root = Node3D.new()
	_tower_root.position = _tower_ground_position
	_bg_root.add_child(_tower_root)
	_tower_window_beams.clear()

	var cliff := MeshInstance3D.new()
	var cliff_mesh := CylinderMesh.new()
	cliff_mesh.height = 4.2
	cliff_mesh.bottom_radius = 8.2
	cliff_mesh.top_radius = 6.8
	cliff_mesh.radial_segments = 8
	cliff.mesh = cliff_mesh
	cliff.position.y = 2.0
	var cliff_mat := StandardMaterial3D.new()
	cliff_mat.albedo_color = Color(0.15, 0.17, 0.19)
	cliff_mat.roughness = 1.0
	cliff.material_override = cliff_mat
	_tower_root.add_child(cliff)

	var tower := MeshInstance3D.new()
	var tower_mesh := CylinderMesh.new()
	tower_mesh.height = 15.8
	tower_mesh.bottom_radius = 2.9
	tower_mesh.top_radius = 2.3
	tower_mesh.radial_segments = 7
	tower.mesh = tower_mesh
	tower.position.y = 9.6
	var tower_mat := StandardMaterial3D.new()
	tower_mat.albedo_color = Color(0.34, 0.35, 0.38)
	tower_mat.roughness = 1.0
	tower.material_override = tower_mat
	_tower_root.add_child(tower)

	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(8.4, 5.4, 7.2)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0.0, 18.8, 0.0)
	var cabin_mat := StandardMaterial3D.new()
	cabin_mat.albedo_color = Color(0.28, 0.22, 0.17)
	cabin_mat.roughness = 1.0
	cabin.material_override = cabin_mat
	_tower_root.add_child(cabin)

	var roof := MeshInstance3D.new()
	var roof_mesh := CylinderMesh.new()
	roof_mesh.height = 4.8
	roof_mesh.bottom_radius = 5.2
	roof_mesh.top_radius = 0.0
	roof_mesh.radial_segments = 7
	roof.mesh = roof_mesh
	roof.position = Vector3(0.0, 23.8, 0.0)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.08, 0.11, 0.22)
	roof_mat.roughness = 1.0
	roof.material_override = roof_mat
	_tower_root.add_child(roof)

	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(2.2, 1.6, 0.24)
	var window_mat := StandardMaterial3D.new()
	window_mat.albedo_color = Color(1.0, 0.82, 0.64)
	window_mat.emission_enabled = true
	window_mat.emission = Color(1.0, 0.74, 0.46)
	window_mat.emission_energy_multiplier = 6.8
	window_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	window_mat.roughness = 0.25

	var window_offsets: Array[Vector3] = [
		Vector3(0.0, 19.2, 3.7),
		Vector3(2.8, 19.0, 1.4),
		Vector3(-2.8, 19.0, 1.4),
	]
	var beam_dirs: Array[Vector3] = [
		Vector3(0.0, -0.08, 1.0),
		Vector3(0.44, -0.08, 0.90),
		Vector3(-0.44, -0.08, 0.90),
	]
	for i in range(window_offsets.size()):
		var offset: Vector3 = window_offsets[i]
		var window := MeshInstance3D.new()
		window.mesh = window_mesh
		window.position = offset
		if absf(offset.x) > 0.1:
			window.rotation_degrees.y = 35.0 if offset.x > 0.0 else -35.0
		window.material_override = window_mat
		_tower_root.add_child(window)

		var beam := SpotLight3D.new()
		beam.light_color = Color(1.0, 0.78, 0.56)
		beam.light_energy = 0.0
		beam.spot_range = 46.0
		beam.spot_angle = 42.0
		beam.shadow_enabled = false
		beam.position = offset + Vector3(0.0, 0.0, 0.18)
		_tower_root.add_child(beam)
		var target := _tower_root.to_global(offset + beam_dirs[i] * 28.0)
		beam.look_at(target, Vector3.UP)
		_tower_window_beams.append(beam)

	var chimney := MeshInstance3D.new()
	var chimney_mesh := CylinderMesh.new()
	chimney_mesh.height = 3.4
	chimney_mesh.bottom_radius = 0.38
	chimney_mesh.top_radius = 0.30
	chimney_mesh.radial_segments = 6
	chimney.mesh = chimney_mesh
	chimney.position = Vector3(1.7, 25.3, -1.1)
	var chimney_mat := StandardMaterial3D.new()
	chimney_mat.albedo_color = Color(0.17, 0.18, 0.20)
	chimney_mat.roughness = 1.0
	chimney.material_override = chimney_mat
	_tower_root.add_child(chimney)

	_tower_smoke = GPUParticles3D.new()
	_tower_smoke.amount = 760
	_tower_smoke.lifetime = 4.6
	_tower_smoke.preprocess = 1.4
	_tower_smoke.one_shot = false
	_tower_smoke.emitting = true
	_tower_smoke.position = chimney.position + Vector3(0.0, 1.9, 0.0)
	_tower_smoke.visibility_aabb = AABB(Vector3(-32.0, -2.0, -32.0), Vector3(64.0, 84.0, 64.0))
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.22
	smoke_mesh.height = 0.44
	smoke_mesh.radial_segments = 6
	smoke_mesh.rings = 4
	_tower_smoke.draw_pass_1 = smoke_mesh
	var smoke_proc := ParticleProcessMaterial.new()
	smoke_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	smoke_proc.emission_box_extents = Vector3(0.18, 0.1, 0.18)
	smoke_proc.direction = Vector3(0.0, 1.0, 0.0)
	smoke_proc.spread = 28.0
	smoke_proc.gravity = Vector3(0.0, 1.6, 0.0)
	smoke_proc.initial_velocity_min = 0.8
	smoke_proc.initial_velocity_max = 2.4
	smoke_proc.scale_min = 0.55
	smoke_proc.scale_max = 1.42
	smoke_proc.color = Color(0.62, 0.68, 0.76, 0.38)
	_tower_smoke.process_material = smoke_proc
	_tower_root.add_child(_tower_smoke)

	_tower_target = _tower_root.global_position + Vector3(0.0, 18.5, 0.0)
	_camera_focus_target = _tower_target + Vector3(-28.0, -3.0, -2.0)
	if _tower_window_light:
		_tower_window_light.position = _tower_root.global_position + Vector3(0.0, 19.4, 2.6)
	if _tower_key_light:
		_tower_key_light.look_at(_tower_target, Vector3.UP)
	if _bg_camera:
		_bg_camera.look_at(_camera_focus_target, Vector3.UP)


func _random_forest_position(min_radius: float, max_radius: float) -> Vector3:
	var angle := _bg_rng.randf_range(0.0, TAU)
	var radius := _bg_rng.randf_range(min_radius, max_radius)
	var y := _bg_rng.randf_range(-0.2, 0.45)
	return Vector3(cos(angle) * radius, y, sin(angle) * radius)


func _is_in_tower_clear_zone(pos: Vector3) -> bool:
	var delta := Vector2(pos.x - _tower_ground_position.x, pos.z - _tower_ground_position.z)
	return delta.length() < 26.0


func _spawn_tree(base_pos: Vector3, scale_factor: float) -> void:
	var tree_root := Node3D.new()
	tree_root.position = base_pos
	tree_root.rotation_degrees.y = _bg_rng.randf_range(0.0, 360.0)
	_bg_root.add_child(tree_root)

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.height = 2.2 * scale_factor
	trunk_mesh.bottom_radius = 0.18 * scale_factor
	trunk_mesh.top_radius = 0.14 * scale_factor
	trunk_mesh.radial_segments = 6
	trunk.mesh = trunk_mesh
	trunk.position.y = trunk_mesh.height * 0.5

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.22, 0.15, 0.09)
	trunk_mat.roughness = 1.0
	trunk.material_override = trunk_mat
	tree_root.add_child(trunk)

	for layer in range(3):
		var crown := MeshInstance3D.new()
		var crown_mesh := CylinderMesh.new()
		crown_mesh.height = (1.1 - float(layer) * 0.13) * scale_factor
		crown_mesh.bottom_radius = (1.00 - float(layer) * 0.19) * scale_factor
		crown_mesh.top_radius = 0.0
		crown_mesh.radial_segments = 6
		crown.mesh = crown_mesh
		crown.position.y = trunk_mesh.height + 0.32 + float(layer) * 0.58

		var tint := _bg_rng.randf_range(-0.04, 0.07)
		var crown_mat := StandardMaterial3D.new()
		crown_mat.albedo_color = Color(0.08 + tint, 0.30 + tint, 0.14 + tint * 0.45)
		crown_mat.roughness = 1.0
		crown.material_override = crown_mat
		tree_root.add_child(crown)


func _spawn_rock(base_pos: Vector3, scale_factor: float) -> void:
	var rock := MeshInstance3D.new()
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.75 * scale_factor
	rock_mesh.height = 0.95 * scale_factor
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 4
	rock.mesh = rock_mesh
	rock.position = base_pos + Vector3(0.0, 0.33 * scale_factor, 0.0)
	rock.scale = Vector3(_bg_rng.randf_range(0.7, 1.25), _bg_rng.randf_range(0.45, 0.95), _bg_rng.randf_range(0.8, 1.35))

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.25, 0.27, 0.29)
	rock_mat.roughness = 1.0
	rock.material_override = rock_mat
	_bg_root.add_child(rock)


func _spawn_forest_animals() -> void:
	_forest_animals.clear()
	for i in range(5):
		var animal := Node3D.new()
		animal.visible = false
		animal.position = Vector3(0.0, 0.35, _bg_rng.randf_range(24.0, 74.0))
		animal.set_meta("speed", _bg_rng.randf_range(4.8, 8.6))
		animal.set_meta("dir", 1.0 if _bg_rng.randf() < 0.5 else -1.0)
		animal.set_meta("cooldown", _bg_rng.randf_range(0.8, 6.4))
		_bg_root.add_child(animal)
		_forest_animals.append(animal)

		var body := MeshInstance3D.new()
		var body_mesh := BoxMesh.new()
		body_mesh.size = Vector3(1.5, 0.8, 0.6)
		body.mesh = body_mesh
		var body_mat := StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.26, 0.19, 0.13)
		body_mat.roughness = 1.0
		body.material_override = body_mat
		animal.add_child(body)

		var neck := MeshInstance3D.new()
		var neck_mesh := BoxMesh.new()
		neck_mesh.size = Vector3(0.25, 0.7, 0.22)
		neck.mesh = neck_mesh
		neck.position = Vector3(0.72, 0.46, 0.0)
		neck.material_override = body_mat
		animal.add_child(neck)

		var head := MeshInstance3D.new()
		var head_mesh := BoxMesh.new()
		head_mesh.size = Vector3(0.42, 0.24, 0.24)
		head.mesh = head_mesh
		head.position = Vector3(0.98, 0.74, 0.0)
		head.material_override = body_mat
		animal.add_child(head)


func _animate_forest_animals(delta: float) -> void:
	if _forest_animals.is_empty():
		return
	for animal in _forest_animals:
		if animal == null:
			continue

		if not animal.visible:
			var cooldown := float(animal.get_meta("cooldown", 0.0)) - delta
			if cooldown <= 0.0:
				var start_left := _bg_rng.randf() < 0.5
				var dir := 1.0 if start_left else -1.0
				animal.visible = true
				animal.set_meta("dir", dir)
				animal.set_meta("speed", _bg_rng.randf_range(4.8, 8.6))
				animal.position = Vector3(-158.0 if start_left else 158.0, 0.35, _bg_rng.randf_range(24.0, 74.0))
				animal.rotation_degrees.y = 0.0 if dir > 0.0 else 180.0
			else:
				animal.set_meta("cooldown", cooldown)
			continue

		var speed := float(animal.get_meta("speed", 5.4))
		var dir := float(animal.get_meta("dir", 1.0))
		var pos := animal.position
		pos.x += speed * dir * delta
		animal.position = pos
		animal.rotation_degrees.y = 0.0 if dir > 0.0 else 180.0

		if pos.x > 166.0 or pos.x < -166.0:
			animal.visible = false
			animal.set_meta("cooldown", _bg_rng.randf_range(4.0, 11.0))


func _build_clouds() -> void:
	_cloud_root = Node3D.new()
	_cloud_root.name = "CloudRoot"
	_bg_root.add_child(_cloud_root)

	_cloud_mesh_material = StandardMaterial3D.new()
	_cloud_mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cloud_mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_mesh_material.albedo_color = Color(0.86, 0.92, 1.0, 0.38)

	for i in range(24):
		var cloud := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = _bg_rng.randf_range(1.2, 2.6)
		mesh.height = mesh.radius * 1.2
		mesh.radial_segments = 10
		mesh.rings = 5
		cloud.mesh = mesh
		cloud.material_override = _cloud_mesh_material
		cloud.position = Vector3(
			_bg_rng.randf_range(-190.0, 190.0),
			_bg_rng.randf_range(35.0, 62.0),
			_bg_rng.randf_range(-180.0, 130.0)
		)
		cloud.scale = Vector3(_bg_rng.randf_range(2.6, 7.8), _bg_rng.randf_range(0.35, 1.05), _bg_rng.randf_range(1.6, 3.9))
		cloud.set_meta("speed", _bg_rng.randf_range(0.6, 1.8))
		cloud.set_meta("phase", _bg_rng.randf_range(0.0, TAU))
		_cloud_root.add_child(cloud)
		_cloud_nodes.append(cloud)


func _build_weather_emitters() -> void:
	_rain_particles = GPUParticles3D.new()
	_rain_particles.name = "Rain"
	_rain_particles.amount = 5200
	_rain_particles.lifetime = 2.2
	_rain_particles.preprocess = 1.5
	_rain_particles.one_shot = false
	_rain_particles.emitting = false
	_rain_particles.visibility_aabb = AABB(Vector3(-150.0, -20.0, -150.0), Vector3(300.0, 140.0, 300.0))
	_rain_particles.position = Vector3(0.0, 60.0, 0.0)

	var rain_mesh := QuadMesh.new()
	rain_mesh.size = Vector2(0.05, 0.65)
	_rain_particles.draw_pass_1 = rain_mesh

	var rain_process := ParticleProcessMaterial.new()
	rain_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_process.emission_box_extents = Vector3(130.0, 1.0, 130.0)
	rain_process.direction = Vector3(0.0, -1.0, 0.0)
	rain_process.spread = 8.0
	rain_process.gravity = Vector3(0.0, -34.0, 0.0)
	rain_process.initial_velocity_min = 24.0
	rain_process.initial_velocity_max = 36.0
	rain_process.scale_min = 0.18
	rain_process.scale_max = 0.36
	rain_process.color = Color(0.60, 0.78, 1.0, 0.52)
	_rain_particles.process_material = rain_process
	_bg_root.add_child(_rain_particles)

	_snow_particles = GPUParticles3D.new()
	_snow_particles.name = "Snow"
	_snow_particles.amount = 1800
	_snow_particles.lifetime = 6.0
	_snow_particles.preprocess = 1.0
	_snow_particles.one_shot = false
	_snow_particles.emitting = false
	_snow_particles.visibility_aabb = AABB(Vector3(-150.0, -20.0, -150.0), Vector3(300.0, 140.0, 300.0))
	_snow_particles.position = Vector3(0.0, 60.0, 0.0)

	var snow_mesh := SphereMesh.new()
	snow_mesh.radius = 0.06
	snow_mesh.height = 0.12
	snow_mesh.radial_segments = 6
	snow_mesh.rings = 4
	_snow_particles.draw_pass_1 = snow_mesh

	var snow_process := ParticleProcessMaterial.new()
	snow_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	snow_process.emission_box_extents = Vector3(130.0, 1.0, 130.0)
	snow_process.direction = Vector3(0.0, -1.0, 0.0)
	snow_process.spread = 30.0
	snow_process.gravity = Vector3(0.0, -4.6, 0.0)
	snow_process.initial_velocity_min = 2.2
	snow_process.initial_velocity_max = 5.2
	snow_process.scale_min = 0.24
	snow_process.scale_max = 0.58
	snow_process.color = Color(0.90, 0.95, 1.0, 0.74)
	_snow_particles.process_material = snow_process
	_bg_root.add_child(_snow_particles)


func _update_solar_cycle() -> void:
	if _blue_sun == null:
		return
	var time_float := _current_time_float()
	var daylight := _daylight_from_time(time_float)
	var night: float = 1.0 - daylight
	var azimuth: float = wrapf((time_float / 24.0) * 360.0 + 34.0, 0.0, 360.0)
	var sun_pitch := lerpf(86.0, -14.0, daylight)

	_blue_sun.rotation_degrees = Vector3(sun_pitch, azimuth, 0.0)
	_blue_sun.light_color = Color(0.18, 0.30, 0.56).lerp(Color(0.34, 0.64, 1.0), daylight)
	_blue_sun.light_energy = lerpf(0.0, 1.45, daylight) * _weather_light_factor

	if _moon_light:
		_moon_light.rotation_degrees = Vector3(-sun_pitch, wrapf(azimuth + 180.0, 0.0, 360.0), 0.0)
		_moon_light.light_color = Color(0.62, 0.48, 0.94).lerp(Color(0.82, 0.68, 1.0), night)
		_moon_light.light_energy = lerpf(0.0, 2.25, night) * clampf(_weather_light_factor + 0.20, 0.46, 1.12)

	if _bg_sky_material:
		_bg_sky_material.sky_top_color = Color(0.01, 0.01, 0.03).lerp(Color(0.12, 0.22, 0.38), daylight)
		_bg_sky_material.sky_horizon_color = Color(0.03, 0.03, 0.05).lerp(Color(0.26, 0.34, 0.42), daylight)
		_bg_sky_material.ground_horizon_color = Color(0.03, 0.03, 0.04).lerp(Color(0.18, 0.20, 0.22), daylight)
		_bg_sky_material.ground_bottom_color = Color(0.01, 0.01, 0.02).lerp(Color(0.09, 0.10, 0.11), daylight)

	if _bg_environment:
		_bg_environment.ambient_light_energy = lerpf(0.06, 0.90, daylight) * _weather_light_factor
		if _use_volumetric_fog:
			_bg_environment.set("volumetric_fog_albedo", Color(0.07, 0.07, 0.08).lerp(Color(0.28, 0.30, 0.34), daylight))
			_bg_environment.set("volumetric_fog_emission", Color(0.0, 0.0, 0.0))

	if _tower_key_light:
		_tower_key_light.look_at(_tower_target, Vector3.UP)
		_tower_key_light.light_color = Color(0.88, 0.82, 0.72).lerp(Color(0.74, 0.78, 0.82), daylight)
		_tower_key_light.light_energy = lerpf(1.1, 0.34, daylight) * _weather_light_factor

	if _tower_window_light:
		var flicker := 0.92 + sin(float(Time.get_ticks_msec()) * 0.0042) * 0.08
		_tower_window_light.light_color = Color(1.0, 0.78, 0.50).lerp(Color(1.0, 0.88, 0.74), daylight * 0.9)
		_tower_window_light.light_energy = lerpf(6.2, 0.55, daylight) * clampf(_weather_light_factor + 0.08, 0.56, 1.12) * flicker
		for beam in _tower_window_beams:
			if beam == null:
				continue
			beam.light_color = _tower_window_light.light_color
			beam.light_energy = _tower_window_light.light_energy * 0.62

	if _tower_smoke:
		var smoke_proc := _tower_smoke.process_material as ParticleProcessMaterial
		if smoke_proc:
			smoke_proc.color = Color(0.66, 0.70, 0.78, lerpf(0.46, 0.30, daylight))
		_tower_smoke.amount = int(lerpf(840.0, 520.0, daylight))
		_tower_smoke.emitting = night > 0.08

	_apply_night_filter(daylight)
	_update_moon_rays(daylight)


func _update_time_tint() -> void:
	if time_tint_layer == null:
		return
	var daylight := _daylight_from_time(_current_time_float())
	var target := Color(0.0, 0.0, 0.0, _night_filter_alpha_for(daylight))
	if _time_tint_tween:
		_time_tint_tween.kill()
	_time_tint_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_time_tint_tween.tween_property(time_tint_layer, "color", target, 1.2)


func _current_time_float() -> float:
	var t: Dictionary = Time.get_time_dict_from_system()
	return float(t.hour) + float(t.minute) / 60.0 + float(t.second) / 3600.0


func _daylight_from_time(time_float: float) -> float:
	var orbit: float = (time_float / 24.0) * TAU
	var altitude: float = sin(orbit - PI * 0.5)
	return clampf((altitude + 0.12) / 1.12, 0.0, 1.0)


func _night_filter_alpha_for(daylight: float) -> float:
	var weather_boost := 0.0
	match _weather_mode:
		WEATHER_CLOUDY:
			weather_boost = 0.03
		WEATHER_RAIN:
			weather_boost = 0.07
		WEATHER_STORM:
			weather_boost = 0.10
		WEATHER_MIST:
			weather_boost = 0.06
		_:
			weather_boost = 0.0
	return clampf(lerpf(0.01, 0.70, 1.0 - daylight) + weather_boost, 0.0, 0.78)


func _apply_night_filter(daylight: float) -> void:
	if time_tint_layer == null:
		return
	var target := Color(0.0, 0.0, 0.0, _night_filter_alpha_for(daylight))
	time_tint_layer.color = time_tint_layer.color.lerp(target, 0.09)


func _animate_clouds(delta: float) -> void:
	if _cloud_nodes.is_empty():
		return
	var wave_time: float = float(Time.get_ticks_msec()) * 0.001
	for cloud in _cloud_nodes:
		if cloud == null:
			continue
		var speed: float = float(cloud.get_meta("speed"))
		var phase: float = float(cloud.get_meta("phase"))
		var pos: Vector3 = cloud.position
		pos.x += speed * _cloud_scroll_speed * delta
		pos.y += sin(wave_time * 0.14 + phase) * 0.025
		if pos.x > 205.0:
			pos.x = -205.0
		cloud.position = pos


func _update_weather_schedule(delta: float) -> void:
	_weather_check_timer += delta
	if _weather_check_timer < 1.0:
		return
	_weather_check_timer = 0.0
	var hour: int = int(Time.get_time_dict_from_system().hour)
	var target_mode := _weather_mode_for_hour(hour)
	if target_mode != _weather_mode:
		_apply_weather_for_hour(hour, false)


func _weather_mode_for_hour(hour: int) -> String:
	var season := _weather_season_key()
	var roll := _weather_roll_for_hour(hour)
	var options: Array[Dictionary] = []

	match season:
		"winter":
			if hour < 6:
				options = [
					{"mode": WEATHER_MIST, "weight": 0.34},
					{"mode": WEATHER_CLOUDY, "weight": 0.30},
					{"mode": WEATHER_SNOW, "weight": 0.30},
					{"mode": WEATHER_CLEAR, "weight": 0.06},
				]
			elif hour < 12:
				options = [
					{"mode": WEATHER_CLOUDY, "weight": 0.40},
					{"mode": WEATHER_SNOW, "weight": 0.24},
					{"mode": WEATHER_CLEAR, "weight": 0.26},
					{"mode": WEATHER_RAIN, "weight": 0.10},
				]
			elif hour < 18:
				options = [
					{"mode": WEATHER_CLEAR, "weight": 0.32},
					{"mode": WEATHER_CLOUDY, "weight": 0.34},
					{"mode": WEATHER_SNOW, "weight": 0.18},
					{"mode": WEATHER_RAIN, "weight": 0.12},
					{"mode": WEATHER_STORM, "weight": 0.04},
				]
			else:
				options = [
					{"mode": WEATHER_CLOUDY, "weight": 0.36},
					{"mode": WEATHER_MIST, "weight": 0.30},
					{"mode": WEATHER_SNOW, "weight": 0.24},
					{"mode": WEATHER_CLEAR, "weight": 0.10},
				]
		"spring":
			if hour < 7:
				options = [
					{"mode": WEATHER_MIST, "weight": 0.38},
					{"mode": WEATHER_CLOUDY, "weight": 0.28},
					{"mode": WEATHER_CLEAR, "weight": 0.24},
					{"mode": WEATHER_RAIN, "weight": 0.10},
				]
			elif hour < 15:
				options = [
					{"mode": WEATHER_CLEAR, "weight": 0.42},
					{"mode": WEATHER_CLOUDY, "weight": 0.30},
					{"mode": WEATHER_RAIN, "weight": 0.22},
					{"mode": WEATHER_STORM, "weight": 0.06},
				]
			else:
				options = [
					{"mode": WEATHER_CLOUDY, "weight": 0.36},
					{"mode": WEATHER_CLEAR, "weight": 0.30},
					{"mode": WEATHER_RAIN, "weight": 0.24},
					{"mode": WEATHER_STORM, "weight": 0.10},
				]
		"summer":
			if hour < 8:
				options = [
					{"mode": WEATHER_MIST, "weight": 0.22},
					{"mode": WEATHER_CLEAR, "weight": 0.54},
					{"mode": WEATHER_CLOUDY, "weight": 0.20},
					{"mode": WEATHER_RAIN, "weight": 0.04},
				]
			elif hour < 17:
				options = [
					{"mode": WEATHER_CLEAR, "weight": 0.60},
					{"mode": WEATHER_CLOUDY, "weight": 0.25},
					{"mode": WEATHER_RAIN, "weight": 0.12},
					{"mode": WEATHER_STORM, "weight": 0.03},
				]
			else:
				options = [
					{"mode": WEATHER_CLEAR, "weight": 0.38},
					{"mode": WEATHER_CLOUDY, "weight": 0.30},
					{"mode": WEATHER_RAIN, "weight": 0.20},
					{"mode": WEATHER_STORM, "weight": 0.12},
				]
		_:
			if hour < 7:
				options = [
					{"mode": WEATHER_MIST, "weight": 0.34},
					{"mode": WEATHER_CLOUDY, "weight": 0.30},
					{"mode": WEATHER_CLEAR, "weight": 0.20},
					{"mode": WEATHER_RAIN, "weight": 0.16},
				]
			elif hour < 16:
				options = [
					{"mode": WEATHER_CLOUDY, "weight": 0.34},
					{"mode": WEATHER_CLEAR, "weight": 0.28},
					{"mode": WEATHER_RAIN, "weight": 0.26},
					{"mode": WEATHER_STORM, "weight": 0.12},
				]
			else:
				options = [
					{"mode": WEATHER_CLOUDY, "weight": 0.32},
					{"mode": WEATHER_RAIN, "weight": 0.30},
					{"mode": WEATHER_STORM, "weight": 0.18},
					{"mode": WEATHER_MIST, "weight": 0.12},
					{"mode": WEATHER_CLEAR, "weight": 0.08},
				]

	return _pick_weighted_weather(options, roll)


func _weather_season_key() -> String:
	var month: int = int(Time.get_date_dict_from_system().month)
	if month >= 3 and month <= 5:
		return "spring"
	if month >= 6 and month <= 8:
		return "summer"
	if month >= 9 and month <= 11:
		return "autumn"
	return "winter"


func _weather_roll_for_hour(hour: int) -> float:
	var date: Dictionary = Time.get_date_dict_from_system()
	var seed := int(date.year) * 100000 + int(date.month) * 3100 + int(date.day) * 100 + hour
	var noise: float = absf(sin(float(seed) * 12.9898) * 43758.5453)
	return noise - floor(noise)


func _pick_weighted_weather(options: Array[Dictionary], roll: float) -> String:
	if options.is_empty():
		return WEATHER_CLEAR
	var total_weight: float = 0.0
	for opt: Dictionary in options:
		total_weight += float(opt.get("weight", 1.0))
	if total_weight <= 0.0:
		return str(options[0].get("mode", WEATHER_CLEAR))
	var cursor: float = roll * total_weight
	for opt: Dictionary in options:
		cursor -= float(opt.get("weight", 1.0))
		if cursor <= 0.0:
			return str(opt.get("mode", WEATHER_CLEAR))
	return str(options[options.size() - 1].get("mode", WEATHER_CLEAR))


func _apply_weather_for_hour(hour: int, instant: bool) -> void:
	_apply_weather_mode(_weather_mode_for_hour(hour), instant)


func _apply_weather_mode(mode: String, instant: bool) -> void:
	_weather_mode = mode
	var fog_density := 0.006
	var fog_color := Color(0.30, 0.31, 0.34)
	var volumetric_density := 0.034
	var mist_alpha := 0.05
	var cloud_tint := Color(0.86, 0.87, 0.90, 0.38)
	_cloud_scroll_speed = 0.8
	_weather_light_factor = 1.0

	var enable_rain := false
	var enable_snow := false
	var rain_amount := 4400
	var snow_amount := 1600

	match mode:
		WEATHER_CLEAR:
			fog_density = 0.003
			fog_color = Color(0.38, 0.40, 0.44)
			volumetric_density = 0.020
			mist_alpha = 0.02
			cloud_tint = Color(0.90, 0.90, 0.90, 0.24)
			_cloud_scroll_speed = 0.6
			_weather_light_factor = 1.0
		WEATHER_CLOUDY:
			fog_density = 0.008
			fog_color = Color(0.30, 0.31, 0.34)
			volumetric_density = 0.032
			mist_alpha = 0.08
			cloud_tint = Color(0.66, 0.67, 0.70, 0.50)
			_cloud_scroll_speed = 1.1
			_weather_light_factor = 0.84
		WEATHER_RAIN:
			fog_density = 0.014
			fog_color = Color(0.22, 0.23, 0.25)
			volumetric_density = 0.044
			mist_alpha = 0.16
			cloud_tint = Color(0.52, 0.54, 0.58, 0.60)
			_cloud_scroll_speed = 1.8
			_weather_light_factor = 0.66
			enable_rain = true
			rain_amount = 4800
		WEATHER_STORM:
			fog_density = 0.019
			fog_color = Color(0.12, 0.13, 0.14)
			volumetric_density = 0.060
			mist_alpha = 0.24
			cloud_tint = Color(0.38, 0.40, 0.42, 0.68)
			_cloud_scroll_speed = 2.5
			_weather_light_factor = 0.50
			enable_rain = true
			rain_amount = 6500
		WEATHER_MIST:
			fog_density = 0.024
			fog_color = Color(0.24, 0.25, 0.26)
			volumetric_density = 0.072
			mist_alpha = 0.33
			cloud_tint = Color(0.72, 0.74, 0.76, 0.54)
			_cloud_scroll_speed = 0.45
			_weather_light_factor = 0.60
		WEATHER_SNOW:
			fog_density = 0.017
			fog_color = Color(0.36, 0.38, 0.42)
			volumetric_density = 0.052
			mist_alpha = 0.20
			cloud_tint = Color(0.82, 0.84, 0.88, 0.50)
			_cloud_scroll_speed = 0.65
			_weather_light_factor = 0.74
			enable_snow = true
			snow_amount = 2100

	if _rain_particles:
		_rain_particles.amount = rain_amount
		_rain_particles.emitting = enable_rain
	if _snow_particles:
		_snow_particles.amount = snow_amount
		_snow_particles.emitting = enable_snow

	if _cloud_mesh_material:
		_cloud_mesh_material.albedo_color = cloud_tint

	if _storm_light and mode != WEATHER_STORM:
		_storm_light.light_energy = 0.0

	if instant:
		if _bg_environment:
			_bg_environment.fog_density = fog_density
			_bg_environment.fog_light_color = fog_color
			if _use_volumetric_fog:
				_bg_environment.set("volumetric_fog_density", volumetric_density)
				_bg_environment.set("volumetric_fog_albedo", fog_color)
		if mist_layer:
			mist_layer.modulate.a = mist_alpha
	else:
		if _weather_tween:
			_weather_tween.kill()
		_weather_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if _bg_environment:
			_weather_tween.tween_property(_bg_environment, "fog_density", fog_density, 2.4)
			_weather_tween.parallel().tween_property(_bg_environment, "fog_light_color", fog_color, 2.4)
		if mist_layer:
			_weather_tween.parallel().tween_property(mist_layer, "modulate:a", mist_alpha, 2.4)
		if _bg_environment and _use_volumetric_fog:
			_bg_environment.set("volumetric_fog_density", volumetric_density)
			_bg_environment.set("volumetric_fog_albedo", fog_color)

	if _tower_smoke and is_instance_valid(_tower_smoke):
		_tower_smoke.emitting = mode != WEATHER_STORM


func _process_storm_flash(delta: float) -> void:
	if _storm_light == null:
		return
	if _weather_mode != WEATHER_STORM:
		_storm_light.light_energy = move_toward(_storm_light.light_energy, 0.0, delta * 10.0)
		return

	_storm_flash_timer -= delta
	if _storm_flash_timer <= 0.0:
		_trigger_storm_flash()
		_storm_flash_timer = _bg_rng.randf_range(2.1, 6.8)

	_storm_light.light_energy = move_toward(_storm_light.light_energy, 0.0, delta * 20.0)


func _trigger_storm_flash() -> void:
	if _storm_light == null:
		return
	_storm_light.light_energy = _bg_rng.randf_range(2.0, 4.2)


func _supports_volumetric_fog() -> bool:
	var renderer_method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	return renderer_method == "forward_plus"
