extends Node3D
class_name MerlinHouseAnimations

## Animation controller for Merlin's House menu scene
## Controls all atmospheric effects, lighting animations, and object movements

# Animation parameters
@export_group("Fire Animation")
@export var fire_flicker_speed: float = 8.0
@export var fire_flicker_intensity: float = 0.4
@export var fire_base_energy: float = 3.5

@export_group("Runes Animation")
@export var runes_rotation_speed: float = 15.0
@export var runes_float_speed: float = 1.5
@export var runes_float_amplitude: float = 0.15

@export_group("Candle Animation")
@export var candle_flicker_speed: float = 12.0
@export var candle_flicker_intensity: float = 0.25

@export_group("Cauldron Animation")
@export var cauldron_bubble_speed: float = 2.0
@export var cauldron_glow_intensity: float = 0.3

@export_group("Crystal Animation")
@export var crystal_pulse_speed: float = 2.0
@export var crystal_pulse_min: float = 0.4
@export var crystal_pulse_max: float = 0.8

@export_group("Atmosphere")
@export var dust_drift_speed: float = 0.5
@export var fog_movement_speed: float = 0.3

# Node references
var fire_light: OmniLight3D
var candle_lights: Array[OmniLight3D] = []
var runes_container: Node3D
var rune_nodes: Array[Node3D] = []
var cauldron_light: OmniLight3D
var cauldron_liquid: MeshInstance3D
var crystal_light: OmniLight3D
var skull_eyes: Array[MeshInstance3D] = []
var skull_light: OmniLight3D
var globe_sphere: MeshInstance3D

# Animation state
var time_elapsed: float = 0.0
var fire_noise_offset: float = 0.0
var runes_base_positions: Array[Vector3] = []

func _ready() -> void:
	_find_animated_nodes()
	_store_initial_positions()
	print("Merlin House Animations initialized")

func _find_animated_nodes() -> void:
	# Find fire light
	fire_light = _find_node_recursive(self, "FireLight") as OmniLight3D
	
	# Find candle lights
	for i in range(2):
		var candle_light = _find_node_recursive(self, "Candle" + str(i + 1) + "/FlameLight") as OmniLight3D
		if candle_light:
			candle_lights.append(candle_light)
	
	# Find runes
	runes_container = _find_node_recursive(self, "FloatingRunes") as Node3D
	if runes_container:
		for i in range(5):
			var rune = runes_container.get_node_or_null("Rune" + str(i))
			if rune:
				rune_nodes.append(rune)
	
	# Find cauldron elements
	cauldron_light = _find_node_recursive(self, "CauldronLight") as OmniLight3D
	cauldron_liquid = _find_node_recursive(self, "MagicLiquid") as MeshInstance3D
	
	# Find crystal light
	crystal_light = _find_node_recursive(self, "CrystalLight") as OmniLight3D
	
	# Find skull elements
	skull_light = _find_node_recursive(self, "SkullGlow") as OmniLight3D
	var eye1 = _find_node_recursive(self, "Eye1") as MeshInstance3D
	var eye2 = _find_node_recursive(self, "Eye2") as MeshInstance3D
	if eye1:
		skull_eyes.append(eye1)
	if eye2:
		skull_eyes.append(eye2)
	
	# Find globe
	globe_sphere = _find_node_recursive(self, "CelestialGlobe/Sphere") as MeshInstance3D

func _find_node_recursive(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	
	# Check if it's a path
	if "/" in node_name:
		return node.get_node_or_null(node_name)
	
	for child in node.get_children():
		var found = _find_node_recursive(child, node_name)
		if found:
			return found
	return null

func _store_initial_positions() -> void:
	for rune in rune_nodes:
		runes_base_positions.append(rune.position)

func _process(delta: float) -> void:
	time_elapsed += delta
	fire_noise_offset += delta * fire_flicker_speed
	
	_animate_fire(delta)
	_animate_candles(delta)
	_animate_runes(delta)
	_animate_cauldron(delta)
	_animate_crystal(delta)
	_animate_skull(delta)
	_animate_globe(delta)

func _animate_fire(delta: float) -> void:
	if not fire_light:
		return
	
	# Complex flickering using multiple sine waves
	var flicker = sin(fire_noise_offset) * 0.3
	flicker += sin(fire_noise_offset * 1.7) * 0.2
	flicker += sin(fire_noise_offset * 2.3) * 0.15
	flicker += sin(fire_noise_offset * 3.1) * 0.1
	
	fire_light.light_energy = fire_base_energy + flicker * fire_flicker_intensity * fire_base_energy
	
	# Subtle color variation
	var color_shift = (sin(time_elapsed * 3.0) + 1.0) * 0.5
	fire_light.light_color = Color(1.0, 0.45 + color_shift * 0.1, 0.1 + color_shift * 0.05)

func _animate_candles(delta: float) -> void:
	for i in range(candle_lights.size()):
		var light = candle_lights[i]
		if not light:
			continue
		
		# Each candle has slightly different flicker pattern
		var offset = i * 1.5
		var flicker = sin(time_elapsed * candle_flicker_speed + offset) * 0.4
		flicker += sin(time_elapsed * candle_flicker_speed * 1.3 + offset) * 0.3
		flicker += sin(time_elapsed * candle_flicker_speed * 2.1 + offset) * 0.2
		
		var base_energy = 0.8 - i * 0.1
		light.light_energy = base_energy + flicker * candle_flicker_intensity

func _animate_runes(delta: float) -> void:
	if not runes_container:
		return
	
	# Rotate the entire runes container
	runes_container.rotation_degrees.y += runes_rotation_speed * delta
	
	# Float each rune individually
	for i in range(rune_nodes.size()):
		if i >= runes_base_positions.size():
			continue
		
		var rune = rune_nodes[i]
		var base_pos = runes_base_positions[i]
		var phase_offset = i * 1.2
		
		# Floating motion
		var float_y = sin(time_elapsed * runes_float_speed + phase_offset) * runes_float_amplitude
		var float_x = cos(time_elapsed * runes_float_speed * 0.7 + phase_offset) * runes_float_amplitude * 0.3
		
		rune.position = base_pos + Vector3(float_x, float_y, 0)
		
		# Individual rotation
		rune.rotation_degrees.y += 30.0 * delta
		rune.rotation_degrees.x = sin(time_elapsed * 0.8 + phase_offset) * 10.0

func _animate_cauldron(delta: float) -> void:
	if cauldron_light:
		# Pulsing glow
		var pulse = (sin(time_elapsed * cauldron_bubble_speed) + 1.0) * 0.5
		cauldron_light.light_energy = 0.8 + pulse * cauldron_glow_intensity
	
	if cauldron_liquid:
		# Bubbling effect - slight scale variation
		var bubble = sin(time_elapsed * cauldron_bubble_speed * 2.0) * 0.02
		cauldron_liquid.scale = Vector3(1.0, 1.0 + bubble, 1.0)

func _animate_crystal(delta: float) -> void:
	if not crystal_light:
		return
	
	# Smooth pulsing
	var pulse = (sin(time_elapsed * crystal_pulse_speed) + 1.0) * 0.5
	crystal_light.light_energy = lerp(crystal_pulse_min, crystal_pulse_max, pulse)

func _animate_skull(delta: float) -> void:
	if skull_light:
		# Eerie pulsing
		var pulse = (sin(time_elapsed * 1.5) + 1.0) * 0.5
		skull_light.light_energy = 0.3 + pulse * 0.3
	
	# Eye glow variation
	for i in range(skull_eyes.size()):
		var eye = skull_eyes[i]
		if eye and eye.material_override:
			var mat = eye.material_override as StandardMaterial3D
			if mat:
				var intensity = 1.5 + sin(time_elapsed * 2.0 + i * 0.5) * 0.5
				mat.emission_energy_multiplier = intensity

func _animate_globe(delta: float) -> void:
	if globe_sphere:
		# Slow rotation
		globe_sphere.rotation_degrees.y += 5.0 * delta
		globe_sphere.rotation_degrees.x = sin(time_elapsed * 0.3) * 5.0
