class_name CardSceneCompositor
extends Control
## Layered sprite compositor for card illustrations.
## Assembles 4 layers (sky + terrain + subject + atmosphere) driven by visual_tags,
## biome, season, and card type. Replaces PixelSceneCompositor when feature flag active.

const PARALLAX_MAX_SHIFT := 8.0
const LAYER_STAGGER_DELAY := 0.08
const LAYER_SLIDE_OFFSET := 10.0
const IDLE_UPDATE_INTERVAL := 0.016  ## ~60 Hz

# ── Layer nodes ────────────────────────────────────────────────────────────────
var _layer_container: Control = null
var _layer_nodes: Array[Control] = []  ## TextureRect or ColorRect per layer
var _layer_configs: Array[CardLayer] = []
var _layer_base_positions: Array[Vector2] = []

# ── State ──────────────────────────────────────────────────────────────────────
var _target_size: Vector2 = Vector2(440.0, 220.0)
var _current_biome: String = ""
var _current_season: String = ""
var _current_period: String = "jour"
var _current_weather: String = "clair"
var _idle_time: float = 0.0
var _idle_active: bool = false
var _reveal_tween: Tween = null
var _subject_seed: int = 0

# ── Atmosphere particles ───────────────────────────────────────────────────────
var _particles_node: CPUParticles2D = null
var _overlay_node: ColorRect = null
var _overlay_pulse_period: float = 0.0
var _overlay_pulse_amplitude: float = 0.0
var _overlay_base_alpha: float = 0.0

# ── Shader cache ───────────────────────────────────────────────────────────────
var _sky_shader: Shader = null
var _silhouette_shader: Shader = null

# ── Subject texture (SpriteFactory handles caching) ──────────────────────────


func setup(p_size: Vector2) -> void:
	_target_size = p_size
	custom_minimum_size = p_size
	size = p_size
	clip_contents = true

	_layer_container = Control.new()
	_layer_container.name = "LayerContainer"
	_layer_container.set_anchors_preset(PRESET_FULL_RECT)
	_layer_container.clip_contents = true
	add_child(_layer_container)

	# Pre-load shaders
	_sky_shader = _load_shader("res://shaders/card_sky.gdshader")
	_silhouette_shader = _load_shader("res://shaders/card_silhouette.gdshader")


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func compose_layers(visual_tags: Array, biome: String, season: String,
		_card_type: String = "narrative", period: String = "jour",
		weather: String = "clair") -> void:
	## Select layers based on tags + biome + period + weather. Does not build scene yet.
	_current_biome = biome
	_current_season = season
	_current_period = period
	_current_weather = weather
	_layer_configs.clear()
	_subject_seed = str(visual_tags).hash() & 0x7FFFFFFF

	print("[CardCompositor] compose_layers: tags=%s biome=%s period=%s weather=%s season=%s" % [
		str(visual_tags), biome, period, weather, season])

	# Resolve modifier hints (expand tags with subject boosts)
	var expanded_tags: Array = visual_tags.duplicate()
	var subject_boosts: Array = []

	# Override period from tags (nocturne → nuit)
	var effective_period: String = period
	for tag in visual_tags:
		var hint: Dictionary = LayeredSceneData.MODIFIER_LAYER_HINTS.get(tag, {})
		if not hint.is_empty():
			if hint.has("sky_variant"):
				var variant: String = str(hint.sky_variant)
				if variant == "night":
					effective_period = "nuit"
			if hint.has("subject_boost"):
				var boosts: Array = hint.subject_boost
				subject_boosts.append_array(boosts)

	# Layer 0: Sky (parametric from AmbianceData)
	var sky_config := _select_sky_parametric(biome, effective_period, weather, season)
	print("[CardCompositor] sky_config: %s" % ("OK" if sky_config != null else "NULL"))
	if sky_config != null:
		_layer_configs.append(sky_config)

	# Layer 1: Terrain (parametric from AmbianceData)
	var terrain_config := _select_terrain_parametric(biome, effective_period, weather)
	print("[CardCompositor] terrain_config: %s" % ("OK" if terrain_config != null else "NULL"))
	if terrain_config != null:
		_layer_configs.append(terrain_config)

	# Layer 2: Subject (visual_tags primary driver via SpriteFactory)
	var combined_tags: Array = expanded_tags.duplicate()
	combined_tags.append_array(subject_boosts)
	var subject_config := _select_subject(combined_tags, biome)
	print("[CardCompositor] subject_config: %s" % ("OK" if subject_config != null else "NULL"))
	if subject_config != null:
		_layer_configs.append(subject_config)

	# Layer 3: Atmosphere (parametric from AmbianceData)
	var atmo_config := _select_atmo_parametric(biome, effective_period, weather, expanded_tags)
	print("[CardCompositor] atmo_config: %s" % ("OK" if atmo_config != null else "NULL"))
	if atmo_config != null:
		_layer_configs.append(atmo_config)

	print("[CardCompositor] Total configs: %d" % _layer_configs.size())


func build_scene(animated: bool = true) -> void:
	## Create visual nodes from _layer_configs and optionally animate reveal.
	clear_scene()
	_layer_nodes.clear()
	_layer_base_positions.clear()

	# Ensure layer container is properly sized
	_layer_container.size = _target_size
	_layer_container.position = Vector2.ZERO

	print("[CardCompositor] Building %d layers (target: %s)" % [_layer_configs.size(), str(_target_size)])
	for config in _layer_configs:
		var node: Control = _create_layer_node(config)
		if node != null:
			_layer_container.add_child(node)
			_layer_nodes.append(node)
			_layer_base_positions.append(node.position)
			print("  Layer %d: %s at pos=%s size=%s" % [
				config.type, node.name, str(node.position), str(node.size)])
		else:
			print("  Layer %d: FAILED to create node" % config.type)

	if animated:
		_animate_layer_reveal()
	else:
		_idle_active = true


func clear_scene() -> void:
	## Remove all layer nodes and reset state.
	_idle_active = false
	_idle_time = 0.0
	if _reveal_tween and _reveal_tween.is_valid():
		_reveal_tween.kill()
		_reveal_tween = null
	if _particles_node and is_instance_valid(_particles_node):
		_particles_node.emitting = false
		_particles_node.queue_free()
		_particles_node = null
	if _overlay_node and is_instance_valid(_overlay_node):
		_overlay_node.queue_free()
		_overlay_node = null
	for node in _layer_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_layer_nodes.clear()
	_layer_base_positions.clear()


func apply_parallax(tilt: Vector2) -> void:
	## Offset each layer by tilt * parallax_factor for depth effect.
	for i in range(_layer_nodes.size()):
		if i >= _layer_configs.size() or i >= _layer_base_positions.size():
			break
		var node: Control = _layer_nodes[i]
		if not is_instance_valid(node):
			continue
		var depth: float = _layer_configs[i].parallax_factor
		node.position = _layer_base_positions[i] + tilt * depth * PARALLAX_MAX_SHIFT


# ═══════════════════════════════════════════════════════════════════════════════
# LAYER SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

func _select_sky_parametric(biome: String, period: String,
		weather: String, season: String) -> CardLayer:
	## Compute sky gradient from AmbianceData parametric system.
	var sky_data: Dictionary = AmbianceData.compute_sky(biome, period, weather, season)
	var layer := CardLayer.create_shader(CardLayer.Type.SKY, 0.0, null)
	layer.idle_motion = sky_data  ## Repurpose to carry gradient + weather data
	return layer


func _select_terrain_parametric(biome: String, period: String,
		weather: String) -> CardLayer:
	## Compute terrain silhouette from AmbianceData parametric system.
	var terrain_data: Dictionary = AmbianceData.compute_terrain(biome, period, weather)
	var layer := CardLayer.create_shader(CardLayer.Type.TERRAIN, 0.3, null)
	layer.particles_config = terrain_data  ## Repurpose to carry shader params
	return layer


func _select_subject(tags: Array, biome: String) -> CardLayer:
	## Use SpriteFactory to pick the best tag and generate procedural sprite.
	var best_tag: String = SpriteFactory.get_best_subject_tag(tags, biome)
	if best_tag.is_empty():
		return null

	var layer := CardLayer.create(CardLayer.Type.SUBJECT, 0.6)
	layer.tags = tags
	layer.display_size = Vector2(128.0, 128.0)  ## 32x32 upscaled 4x
	layer.anchor = Vector2(0.5, 0.75)
	layer.idle_motion = {"type": "breathe", "amplitude": 1.005, "period": 4.0}
	layer.texture_path = best_tag  ## Tag key for SpriteFactory.generate()
	return layer


func _select_atmo_parametric(biome: String, period: String,
		weather: String, tags: Array) -> CardLayer:
	## Compute atmosphere from AmbianceData parametric system.
	## Falls back to tag-based LayeredSceneData lookup for modifier-forced atmospheres.
	var forced_key: String = ""
	for tag in tags:
		var hint: Dictionary = LayeredSceneData.MODIFIER_LAYER_HINTS.get(tag, {})
		if hint.has("atmo_key"):
			forced_key = str(hint.atmo_key)

	# If a modifier forces a specific atmosphere (danger_pulse, sacred_light),
	# use the static lookup; otherwise use parametric weather-aware atmosphere
	if not forced_key.is_empty() and LayeredSceneData.ATMOSPHERES.has(forced_key):
		var forced_data: Dictionary = LayeredSceneData.ATMOSPHERES[forced_key]
		var forced_layer := CardLayer.create(CardLayer.Type.ATMOSPHERE, 1.0)
		forced_layer.tags = forced_data.get("tags", [])
		forced_layer.particles_config = forced_data
		return forced_layer

	var atmo_data: Dictionary = AmbianceData.compute_atmosphere(biome, period, weather)
	var layer := CardLayer.create(CardLayer.Type.ATMOSPHERE, 1.0)
	layer.particles_config = atmo_data
	return layer


# ═══════════════════════════════════════════════════════════════════════════════
# NODE CREATION
# ═══════════════════════════════════════════════════════════════════════════════

func _create_layer_node(config: CardLayer) -> Control:
	match config.type:
		CardLayer.Type.SKY:
			return _create_sky_node(config)
		CardLayer.Type.TERRAIN:
			return _create_terrain_node(config)
		CardLayer.Type.SUBJECT:
			return _create_subject_node(config)
		CardLayer.Type.ATMOSPHERE:
			return _create_atmosphere_node(config)
	return null


func _create_sky_node(config: CardLayer) -> ColorRect:
	## Create procedural sky gradient via shader or fallback to solid color.
	var sky_data: Dictionary = config.idle_motion  ## Carries gradient data
	var rect := ColorRect.new()
	rect.name = "SkyLayer"
	rect.size = _target_size
	rect.position = Vector2.ZERO

	if _sky_shader:
		var mat := ShaderMaterial.new()
		mat.shader = _sky_shader
		# Gradient colors (already computed by AmbianceData with period+weather+season applied)
		mat.set_shader_parameter("top_color", sky_data.get("top_color", MerlinVisual.CRT_PALETTE["sky_top"]))
		mat.set_shader_parameter("mid_color", sky_data.get("mid_color", MerlinVisual.CRT_PALETTE["sky_mid"]))
		mat.set_shader_parameter("bottom_color", sky_data.get("bottom_color", MerlinVisual.CRT_PALETTE["sky_bottom"]))
		mat.set_shader_parameter("mid_position", sky_data.get("mid_position", 0.45))
		# Season tint already baked into colors by AmbianceData, pass neutral
		mat.set_shader_parameter("season_tint", Color(1, 1, 1))
		# Weather uniforms
		mat.set_shader_parameter("fog_density", sky_data.get("fog_density", 0.0))
		mat.set_shader_parameter("fog_color", sky_data.get("fog_color", MerlinVisual.CRT_PALETTE["sky_fog"]))
		mat.set_shader_parameter("cloud_cover", sky_data.get("cloud_cover", 0.0))
		mat.set_shader_parameter("rain_intensity", sky_data.get("rain_intensity", 0.0))
		rect.material = mat
	else:
		# Fallback: solid mid color
		rect.color = sky_data.get("mid_color", MerlinVisual.CRT_PALETTE["sky_mid"])

	config.idle_motion = {}  ## Reset after extracting gradient data
	return rect


func _create_terrain_node(config: CardLayer) -> ColorRect:
	## Create terrain silhouette via shader or fallback to flat band.
	var mid_data: Dictionary = config.particles_config
	var rect := ColorRect.new()
	rect.name = "TerrainLayer"
	rect.size = _target_size
	rect.position = Vector2.ZERO

	if _silhouette_shader:
		var mat := ShaderMaterial.new()
		mat.shader = _silhouette_shader
		mat.set_shader_parameter("silhouette_color", mid_data.get("silhouette_color", MerlinVisual.CRT_PALETTE["silhouette"]))
		mat.set_shader_parameter("height_base", mid_data.get("height_base", 0.55))
		mat.set_shader_parameter("height_variation", mid_data.get("height_variation", 0.20))
		mat.set_shader_parameter("roughness", mid_data.get("roughness", 0.65))
		mat.set_shader_parameter("density", mid_data.get("density", 0.80))
		mat.set_shader_parameter("time_offset", randf() * 100.0)
		rect.material = mat
	else:
		# Fallback: colored band in lower portion
		var h_base: float = mid_data.get("height_base", 0.55)
		rect.color = mid_data.get("silhouette_color", MerlinVisual.CRT_PALETTE["silhouette"])
		rect.position.y = _target_size.y * h_base
		rect.size.y = _target_size.y * (1.0 - h_base)

	config.particles_config = {}  ## Reset after extracting shader params
	return rect


func _create_subject_node(config: CardLayer) -> TextureRect:
	## Create subject sprite via SpriteFactory procedural generation.
	var tag: String = config.texture_path  ## Contains the best tag
	var texture: ImageTexture = SpriteFactory.generate(
		tag, _current_biome, _subject_seed, _current_season)
	if texture == null:
		return null

	var tex_rect := TextureRect.new()
	tex_rect.name = "SubjectLayer"
	tex_rect.texture = texture
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = config.display_size
	tex_rect.size = config.display_size

	# Position based on anchor
	var x: float = (_target_size.x - config.display_size.x) * config.anchor.x
	var y: float = (_target_size.y - config.display_size.y) * config.anchor.y
	tex_rect.position = Vector2(x, y)

	return tex_rect


func _create_atmosphere_node(config: CardLayer) -> Control:
	## Create atmosphere: particles + optional period overlay (dawn/dusk/night tint).
	var atmo_data: Dictionary = config.particles_config
	var atmo_type: String = str(atmo_data.get("type", "particles"))

	# Main atmosphere layer
	var main_node: Control = null
	if atmo_type == "overlay":
		main_node = _create_overlay(atmo_data)
	else:
		main_node = _create_particles(atmo_data)

	# Period overlay (dawn warmth, night vignette) — layered on top
	var period_hint: Dictionary = atmo_data.get("period_overlay", {})
	if not period_hint.is_empty() and main_node != null:
		var overlay := _create_overlay(period_hint)
		if overlay != null:
			overlay.name = "PeriodOverlay"
			# Wrap both in a container
			var wrapper := Control.new()
			wrapper.name = "AtmosphereGroup"
			wrapper.size = _target_size
			wrapper.position = Vector2.ZERO
			if main_node.get_parent() == null:
				wrapper.add_child(main_node)
			wrapper.add_child(overlay)
			return wrapper

	return main_node


func _create_overlay(atmo_data: Dictionary) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "AtmosphereOverlay"
	rect.size = _target_size
	rect.position = Vector2.ZERO
	var base_color: Color = atmo_data.get("overlay_color", Color(0, 0, 0, 0.1))
	rect.color = base_color
	_overlay_node = rect
	_overlay_base_alpha = base_color.a
	_overlay_pulse_period = float(atmo_data.get("pulse_period", 0.0))
	_overlay_pulse_amplitude = float(atmo_data.get("pulse_amplitude", 0.0))
	return rect


func _create_particles(atmo_data: Dictionary) -> Control:
	## Wrap CPUParticles2D in a Control for consistent positioning.
	var wrapper := Control.new()
	wrapper.name = "AtmosphereParticles"
	wrapper.size = _target_size
	wrapper.position = Vector2.ZERO

	var particles := CPUParticles2D.new()
	particles.name = "Particles"
	particles.emitting = false  ## Start after reveal animation
	particles.amount = int(atmo_data.get("count", 25))
	particles.lifetime = 3.0
	particles.one_shot = false
	particles.explosiveness = 0.0

	# Emission area
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = _target_size * 0.5

	# Position at center of illustration
	particles.position = _target_size * 0.5

	# Direction + speed
	var direction: Vector2 = atmo_data.get("direction", Vector2(1, 0))
	particles.direction = direction
	var speed_range: Vector2 = atmo_data.get("speed_range", Vector2(2, 8))
	particles.initial_velocity_min = speed_range.x
	particles.initial_velocity_max = speed_range.y
	particles.spread = 30.0

	# Size
	var size_range: Vector2 = atmo_data.get("size_range", Vector2(5, 20))
	particles.scale_amount_min = size_range.x / 10.0
	particles.scale_amount_max = size_range.y / 10.0

	# Color
	var color: Color = atmo_data.get("color", MerlinVisual.CRT_PALETTE["atmo_particle"])
	particles.color = color

	# Gravity off for floating effect
	particles.gravity = Vector2.ZERO

	wrapper.add_child(particles)
	_particles_node = particles
	return wrapper


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATION — Reveal + Idle
# ═══════════════════════════════════════════════════════════════════════════════

func _animate_layer_reveal() -> void:
	## Staggered fade-in + slide-up for each layer.
	if _layer_nodes.is_empty():
		_idle_active = true
		return

	# Hide all layers initially
	for node in _layer_nodes:
		if is_instance_valid(node):
			node.modulate.a = 0.0
			node.position.y += LAYER_SLIDE_OFFSET

	_reveal_tween = create_tween()
	_reveal_tween.set_parallel(true)

	for i in range(_layer_nodes.size()):
		var node: Control = _layer_nodes[i]
		if not is_instance_valid(node):
			continue
		var delay: float = float(i) * LAYER_STAGGER_DELAY
		var target_y: float = _layer_base_positions[i].y
		_reveal_tween.tween_property(node, "modulate:a", 1.0, 0.25) \
			.set_delay(delay)
		_reveal_tween.tween_property(node, "position:y", target_y, 0.30) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
			.set_delay(delay)

	# After reveal completes, enable idle + start particles
	_reveal_tween.chain().tween_callback(_on_reveal_complete)


func _on_reveal_complete() -> void:
	_idle_active = true
	if _particles_node and is_instance_valid(_particles_node):
		_particles_node.emitting = true


func _process(delta: float) -> void:
	if not _idle_active:
		return

	_idle_time += delta

	# Per-layer idle motion
	for i in range(_layer_nodes.size()):
		if i >= _layer_configs.size():
			break
		var node: Control = _layer_nodes[i]
		if not is_instance_valid(node):
			continue
		var config: CardLayer = _layer_configs[i]
		var motion: Dictionary = config.idle_motion
		if motion.is_empty():
			continue

		var motion_type: String = str(motion.get("type", "none"))
		var amplitude: float = float(motion.get("amplitude", 0.0))
		var period: float = maxf(float(motion.get("period", 1.0)), 0.1)

		match motion_type:
			"sway":
				var offset_x: float = sin(_idle_time * TAU / period) * amplitude
				node.position.x = _layer_base_positions[i].x + offset_x
			"breathe":
				var scale_val: float = 1.0 + (sin(_idle_time * TAU / period) + 1.0) * 0.5 * (amplitude - 1.0)
				node.scale = Vector2(scale_val, scale_val)
			"drift":
				var offset_x: float = sin(_idle_time * TAU / period) * amplitude
				var offset_y: float = cos(_idle_time * TAU / period * 0.7) * amplitude * 0.5
				node.position.x = _layer_base_positions[i].x + offset_x
				node.position.y = _layer_base_positions[i].y + offset_y

	# Overlay pulse
	if _overlay_node and is_instance_valid(_overlay_node) and _overlay_pulse_period > 0.0:
		var pulse: float = sin(_idle_time * TAU / _overlay_pulse_period)
		var alpha: float = _overlay_base_alpha + pulse * _overlay_pulse_amplitude
		_overlay_node.color.a = clampf(alpha, 0.0, 0.5)


# ═══════════════════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

func _load_shader(path: String) -> Shader:
	if ResourceLoader.exists(path):
		return load(path) as Shader
	return null


func _biome_to_short(biome: String) -> String:
	match biome:
		"foret_broceliande": return "broceliande"
		"landes_bruyere": return "landes"
		"cotes_sauvages": return "cotes"
		"villages_celtes": return "villages"
		"cercles_pierres": return "cercles"
		"marais_korrigans": return "marais"
		"collines_dolmens": return "collines"
		"iles_mystiques": return "iles"
		_: return "broceliande"
