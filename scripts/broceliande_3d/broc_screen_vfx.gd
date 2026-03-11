## ═══════════════════════════════════════════════════════════════════════════════
## BrocScreenVfx — Screen-space effects (shake, flash, glitch, vignette, particles)
## ═══════════════════════════════════════════════════════════════════════════════
## Mixed canvas overlay (shader) + viewport offset (shake).
## Single shader with multi-effect uniforms. GPU particle bursts at player pos.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted

var _viewport_container: SubViewportContainer
var _overlay_layer: CanvasLayer
var _overlay_rect: ColorRect
var _shader_mat: ShaderMaterial
var _forest_root: Node3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Active effect timers: { effect_name -> { timer, duration, intensity, ... } }
var _active_effects: Dictionary = {}

## Screen shake state
var _shake_offset: Vector2 = Vector2.ZERO
var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0
var _shake_decay: float = 5.0

## Particle burst nodes (auto-freed)
var _burst_nodes: Array[Node3D] = []

const SHADER_PATH: String = "res://shaders/screen_vfx.gdshader"


func setup(viewport_container: SubViewportContainer, parent: Node, forest_root: Node3D) -> void:
	_viewport_container = viewport_container
	_forest_root = forest_root
	_rng.randomize()

	# Canvas overlay layer (above everything except event overlay)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 15
	parent.add_child(_overlay_layer)

	_overlay_rect = ColorRect.new()
	_overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_rect.color = Color(0, 0, 0, 0)  # Transparent — used for flash/vignette effects only
	# NOTE: shader removed — screen_vfx.gdshader reads TEXTURE which defaults to white
	# on a plain ColorRect without a SubViewport texture source. Effects use color modulation only.

	_overlay_layer.add_child(_overlay_rect)
	print("[BrocScreenVfx] Screen effects ready")


func update(delta: float) -> void:
	_update_shake(delta)
	_update_effects(delta)
	_cleanup_bursts()


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func trigger(effect_name: String, intensity: float = 1.0, duration: float = 0.5) -> void:
	match effect_name:
		"shake":
			_shake_intensity = intensity * 8.0
			_shake_timer = duration
		"flash":
			_set_shader("flash_alpha", intensity * 0.8)
			_active_effects["flash"] = {"timer": duration, "duration": duration, "param": "flash_alpha", "from": intensity * 0.8, "to": 0.0}
		"flash_red":
			_set_shader("flash_alpha", intensity * 0.6)
			_set_shader("flash_color", Color(0.9, 0.15, 0.1, 1.0))
			_active_effects["flash_red"] = {"timer": duration, "duration": duration, "param": "flash_alpha", "from": intensity * 0.6, "to": 0.0}
		"vignette":
			_set_shader("vignette_intensity", intensity * 1.2)
			_active_effects["vignette"] = {"timer": duration, "duration": duration, "param": "vignette_intensity", "from": intensity * 1.2, "to": 0.0}
		"vignette_red":
			_set_shader("vignette_intensity", intensity * 1.0)
			_set_shader("vignette_color", Color(0.5, 0.0, 0.0, 1.0))
			_active_effects["vignette_red"] = {"timer": duration, "duration": duration, "param": "vignette_intensity", "from": intensity * 1.0, "to": 0.0}
		"vignette_gold":
			_set_shader("vignette_intensity", intensity * 0.8)
			_set_shader("vignette_color", Color(0.6, 0.45, 0.1, 1.0))
			_active_effects["vignette_gold"] = {"timer": duration, "duration": duration, "param": "vignette_intensity", "from": intensity * 0.8, "to": 0.0}
		"glitch":
			_set_shader("glitch_amount", intensity * 0.8)
			_set_shader("scanline_intensity", intensity * 0.5)
			_active_effects["glitch"] = {"timer": duration, "duration": duration, "param": "glitch_amount", "from": intensity * 0.8, "to": 0.0}
			_active_effects["glitch_scan"] = {"timer": duration, "duration": duration, "param": "scanline_intensity", "from": intensity * 0.5, "to": 0.0}
		"desaturate":
			_set_shader("desaturation", intensity * 0.7)
			_active_effects["desaturate"] = {"timer": duration, "duration": duration, "param": "desaturation", "from": intensity * 0.7, "to": 0.0}
		"hue_green":
			_set_shader("hue_shift", intensity * 0.15)
			_active_effects["hue_green"] = {"timer": duration, "duration": duration, "param": "hue_shift", "from": intensity * 0.15, "to": 0.0}
		"hue_blue":
			_set_shader("hue_shift", intensity * -0.15)
			_active_effects["hue_blue"] = {"timer": duration, "duration": duration, "param": "hue_shift", "from": intensity * -0.15, "to": 0.0}


func trigger_burst(burst_type: String, pos: Vector3) -> void:
	if not _forest_root:
		return
	match burst_type:
		"sparkle":
			_spawn_burst(pos, Color(0.95, 0.90, 0.60), 30, 2.0, Vector3(0.5, 1.5, 0.5))
		"ember":
			_spawn_burst(pos, Color(1.0, 0.4, 0.1), 20, 3.0, Vector3(1.0, 2.0, 1.0))
		"pollen":
			_spawn_burst(pos, Color(0.8, 0.9, 0.3), 40, 2.5, Vector3(2.0, 1.0, 2.0))
		"water":
			_spawn_burst(pos, Color(0.3, 0.6, 0.9), 25, 1.5, Vector3(1.5, 0.5, 1.5))
		"leaves":
			_spawn_burst(pos, Color(0.7, 0.5, 0.15), 35, 3.0, Vector3(2.0, 2.0, 2.0))


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL
# ═══════════════════════════════════════════════════════════════════════════════

func _update_shake(delta: float) -> void:
	if _shake_timer <= 0.0:
		if _shake_offset.length() > 0.01:
			_shake_offset = _shake_offset.lerp(Vector2.ZERO, _shake_decay * delta)
			if _viewport_container:
				_viewport_container.position = _shake_offset
		return

	_shake_timer -= delta
	var t: float = _shake_timer / maxf(_shake_timer + delta, 0.01)
	var current_intensity: float = _shake_intensity * t
	_shake_offset = Vector2(
		_rng.randf_range(-current_intensity, current_intensity),
		_rng.randf_range(-current_intensity, current_intensity)
	)
	if _viewport_container:
		_viewport_container.position = _shake_offset

	if _shake_timer <= 0.0:
		_shake_offset = Vector2.ZERO
		if _viewport_container:
			_viewport_container.position = Vector2.ZERO


func _update_effects(delta: float) -> void:
	var expired: Array[String] = []
	for key: String in _active_effects:
		var eff: Dictionary = _active_effects[key]
		eff["timer"] = float(eff["timer"]) - delta
		if float(eff["timer"]) <= 0.0:
			_set_shader(eff["param"] as String, float(eff["to"]))
			expired.append(key)
		else:
			# Lerp toward target
			var progress: float = 1.0 - float(eff["timer"]) / maxf(float(eff.get("duration", 1.0)), 0.01)
			var val: float = lerpf(float(eff["from"]), float(eff["to"]), progress)
			_set_shader(eff["param"] as String, val)
	for key in expired:
		_active_effects.erase(key)
		# Reset flash color to white after flash effects
		if key.begins_with("flash"):
			_set_shader("flash_color", Color(1.0, 1.0, 1.0, 1.0))
		if key.begins_with("vignette"):
			_set_shader("vignette_color", Color(0.0, 0.0, 0.0, 1.0))


func _set_shader(param: String, value: Variant) -> void:
	if _shader_mat:
		_shader_mat.set_shader_parameter(param, value)


func _spawn_burst(pos: Vector3, color: Color, amount: int, lifetime: float, spread: Vector3) -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.position = pos + Vector3(0.0, 0.8, 0.0)

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 45.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 2.0
	mat.gravity = Vector3(0.0, -1.5, 0.0)
	mat.scale_min = 0.02
	mat.scale_max = 0.06
	mat.color = color
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = spread
	particles.process_material = mat

	# Simple mesh for particles
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	mesh.radial_segments = 4
	mesh.rings = 2
	particles.draw_pass_1 = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_forest_root.add_child(particles)
	_burst_nodes.append(particles)


func _cleanup_bursts() -> void:
	var i: int = _burst_nodes.size() - 1
	while i >= 0:
		var node: Node3D = _burst_nodes[i]
		if not is_instance_valid(node):
			_burst_nodes.remove_at(i)
		elif node is GPUParticles3D and not (node as GPUParticles3D).emitting:
			node.queue_free()
			_burst_nodes.remove_at(i)
		i -= 1
