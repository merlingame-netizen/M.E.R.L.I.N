## ═══════════════════════════════════════════════════════════════════════════════
## BiomeParticles — Procedural GPU particle systems for biome atmosphere
## ═══════════════════════════════════════════════════════════════════════════════
## Manages GPUParticles3D nodes for atmospheric effects (rain, fireflies, mist,
## snow, leaves, embers, spores). Each biome maps to one or more particle
## presets. All effects are fully procedural via ParticleProcessMaterial.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node3D
class_name BiomeParticles


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ═══════════════════════════════════════════════════════════════════════════════

signal particles_started(biome_id: String)
signal particles_stopped()


# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const VALID_PARTICLE_TYPES: Array[String] = [
	"rain", "fireflies", "mist", "snow", "leaves", "embers", "spores", "none",
]

const FADE_OUT_DURATION: float = 1.5
const DEFAULT_INTENSITY: float = 1.0
const MIN_INTENSITY: float = 0.0
const MAX_INTENSITY: float = 1.0

## Biome to particle type(s) mapping.
## Each biome maps to an array of particle type strings.
const BIOME_PARTICLE_MAP: Dictionary = {
	"foret_broceliande": ["mist", "fireflies"],
	"landes_bruyere": ["fireflies"],
	"cotes_sauvages": ["rain"],
	"marais_korrigans": ["mist"],
	"collines_dolmens": ["leaves"],
	"iles_mystiques": ["rain", "mist"],
	"cercles_pierres": ["embers"],
	"villages_celtes": ["leaves"],  # optional leaves
}

const DEFAULT_BIOME_PARTICLES: Array[String] = ["mist"]


# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _active_particles: Array[GPUParticles3D] = []
var _active_types: Array[String] = []
var _current_biome_id: String = ""
var _current_intensity: float = DEFAULT_INTENSITY
var _base_amounts: Dictionary = {}  # GPUParticles3D -> int (original amount)
var _fade_tween: Tween = null


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Creates and configures particle systems for the given biome.
## Clears any previously active particles first.
func setup_for_biome(biome_id: String) -> void:
	_clear_active_particles()

	_current_biome_id = biome_id
	_current_intensity = DEFAULT_INTENSITY

	var types: Array = _get_particle_types_for_biome(biome_id)

	for particle_type: String in types:
		if particle_type == "none":
			continue
		var particles: GPUParticles3D = _create_particle_system(particle_type)
		if particles != null:
			add_child(particles)
			_active_particles.append(particles)
			_active_types.append(particle_type)
			_base_amounts[particles] = particles.amount

	particles_started.emit(biome_id)


## Scales emission rate for all active particle systems.
## Factor is clamped to [0.0, 1.0].
func set_intensity(factor: float) -> void:
	_current_intensity = clampf(factor, MIN_INTENSITY, MAX_INTENSITY)

	for particles: GPUParticles3D in _active_particles:
		if not is_instance_valid(particles):
			continue
		var base_amount: int = _base_amounts.get(particles, particles.amount)
		var scaled: int = maxi(1, int(base_amount * _current_intensity))
		particles.amount = scaled

		if _current_intensity <= 0.0:
			particles.emitting = false
		else:
			particles.emitting = true


## Graceful fade-out: tweens intensity to 0 then removes particles.
func stop() -> void:
	if _active_particles.is_empty():
		particles_stopped.emit()
		return

	_kill_fade_tween()

	_fade_tween = create_tween()
	_fade_tween.tween_method(_fade_intensity, _current_intensity, 0.0, FADE_OUT_DURATION)
	_fade_tween.tween_callback(_on_fade_complete)


## Returns a comma-separated string of active particle type names.
## Returns "none" if no particles are active.
func get_active_type() -> String:
	if _active_types.is_empty():
		return "none"
	return ",".join(_active_types)


## Returns the current biome ID.
func get_current_biome_id() -> String:
	return _current_biome_id


## Returns the current intensity value.
func get_intensity() -> float:
	return _current_intensity


## Returns true if any particle systems are currently active and emitting.
func is_active() -> bool:
	for particles: GPUParticles3D in _active_particles:
		if is_instance_valid(particles) and particles.emitting:
			return true
	return false


## Returns the list of particle type strings for a given biome.
## Falls back to DEFAULT_BIOME_PARTICLES for unknown biomes.
static func get_particle_types_for_biome(biome_id: String) -> Array:
	if BIOME_PARTICLE_MAP.has(biome_id):
		return BIOME_PARTICLE_MAP[biome_id]
	return DEFAULT_BIOME_PARTICLES.duplicate()


## Returns true if the given particle type string is valid.
static func is_valid_particle_type(particle_type: String) -> bool:
	return particle_type in VALID_PARTICLE_TYPES


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — Particle type resolution
# ═══════════════════════════════════════════════════════════════════════════════

func _get_particle_types_for_biome(biome_id: String) -> Array:
	return BiomeParticles.get_particle_types_for_biome(biome_id)


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — Particle system factory
# ═══════════════════════════════════════════════════════════════════════════════

func _create_particle_system(particle_type: String) -> GPUParticles3D:
	if not is_valid_particle_type(particle_type) or particle_type == "none":
		push_warning("BiomeParticles: invalid particle type '%s'" % particle_type)
		return null

	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Particles_%s" % particle_type

	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()

	match particle_type:
		"rain":
			_configure_rain(particles, material)
		"fireflies":
			_configure_fireflies(particles, material)
		"mist":
			_configure_mist(particles, material)
		"snow":
			_configure_snow(particles, material)
		"leaves":
			_configure_leaves(particles, material)
		"embers":
			_configure_embers(particles, material)
		"spores":
			_configure_spores(particles, material)

	particles.process_material = material
	particles.emitting = true

	return particles


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — Particle presets (all procedural, no imported assets)
# ═══════════════════════════════════════════════════════════════════════════════

## Rain: vertical falling drops, grey-blue, moderate density, slight wind angle
func _configure_rain(p: GPUParticles3D, mat: ParticleProcessMaterial) -> void:
	p.amount = 200
	p.lifetime = 1.2
	p.visibility_aabb = AABB(Vector3(-10, -2, -10), Vector3(20, 15, 20))

	# Emission: box overhead
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(10.0, 0.5, 10.0)

	# Direction: downward with slight wind angle
	mat.direction = Vector3(0.15, -1.0, 0.05)
	mat.spread = 5.0

	# Velocity
	mat.initial_velocity_min = 12.0
	mat.initial_velocity_max = 16.0

	# Gravity
	mat.gravity = Vector3(0.3, -9.8, 0.0)

	# Scale: thin streaks
	mat.scale_min = 0.02
	mat.scale_max = 0.04

	# Color: grey-blue, semi-transparent
	mat.color = Color(0.6, 0.65, 0.8, 0.5)

	# Draw pass: small mesh
	p.draw_pass_1 = _create_particle_mesh(Vector3(0.01, 0.15, 0.01))


## Fireflies: slow-moving yellow-green dots, pulsing alpha, low density
func _configure_fireflies(p: GPUParticles3D, mat: ParticleProcessMaterial) -> void:
	p.amount = 30
	p.lifetime = 4.0
	p.visibility_aabb = AABB(Vector3(-8, -1, -8), Vector3(16, 6, 16))

	# Emission: sphere around player
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 8.0

	# Direction: random orbits (mostly upward drift)
	mat.direction = Vector3(0.0, 0.3, 0.0)
	mat.spread = 180.0

	# Velocity: slow movement
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.8

	# Gravity: slight upward float
	mat.gravity = Vector3(0.0, -0.3, 0.0)

	# Scale: small glowing dots
	mat.scale_min = 0.04
	mat.scale_max = 0.08

	# Color: yellow-green glow with pulsing via color ramp
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.7, 1.0, 0.3, 0.0))
	gradient.add_point(0.15, Color(0.8, 1.0, 0.4, 0.9))
	gradient.add_point(0.5, Color(0.9, 1.0, 0.5, 0.3))
	gradient.add_point(0.85, Color(0.8, 1.0, 0.4, 0.9))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.7, 1.0, 0.3, 0.0))
	var color_ramp: GradientTexture1D = GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	# Draw pass
	p.draw_pass_1 = _create_particle_mesh(Vector3(0.06, 0.06, 0.06))


## Mist: large soft white particles, slow horizontal drift, very slow alpha cycle
func _configure_mist(p: GPUParticles3D, mat: ParticleProcessMaterial) -> void:
	p.amount = 40
	p.lifetime = 6.0
	p.visibility_aabb = AABB(Vector3(-12, -1, -12), Vector3(24, 5, 24))

	# Emission: wide box at ground level
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(12.0, 0.5, 12.0)

	# Direction: slow horizontal drift
	mat.direction = Vector3(1.0, 0.1, 0.3)
	mat.spread = 30.0

	# Velocity: very slow
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 0.8

	# Gravity: near-zero, slight upward
	mat.gravity = Vector3(0.0, 0.1, 0.0)

	# Scale: large soft volumes
	mat.scale_min = 1.5
	mat.scale_max = 3.0

	# Color: white fog with slow alpha cycle
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.9, 0.92, 0.95, 0.0))
	gradient.add_point(0.2, Color(0.9, 0.92, 0.95, 0.15))
	gradient.add_point(0.5, Color(0.9, 0.92, 0.95, 0.25))
	gradient.add_point(0.8, Color(0.9, 0.92, 0.95, 0.15))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.9, 0.92, 0.95, 0.0))
	var color_ramp: GradientTexture1D = GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	# Draw pass: large quad
	p.draw_pass_1 = _create_particle_mesh(Vector3(2.0, 2.0, 0.01))


## Snow: gentle falling white flakes, slight sway, lower density than rain
func _configure_snow(p: GPUParticles3D, mat: ParticleProcessMaterial) -> void:
	p.amount = 100
	p.lifetime = 3.0
	p.visibility_aabb = AABB(Vector3(-10, -2, -10), Vector3(20, 15, 20))

	# Emission: box overhead
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(10.0, 0.5, 10.0)

	# Direction: downward with slight sway
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 15.0

	# Velocity: gentle fall
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 3.0

	# Gravity: light downward pull
	mat.gravity = Vector3(0.2, -1.5, 0.1)

	# Scale: small flakes
	mat.scale_min = 0.03
	mat.scale_max = 0.07

	# Color: white with soft alpha
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.1, Color(1.0, 1.0, 1.0, 0.7))
	gradient.add_point(0.8, Color(0.95, 0.95, 1.0, 0.7))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.95, 0.95, 1.0, 0.0))
	var color_ramp: GradientTexture1D = GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	# Draw pass
	p.draw_pass_1 = _create_particle_mesh(Vector3(0.05, 0.05, 0.01))


## Leaves: brown/orange falling particles, tumble rotation, seasonal
func _configure_leaves(p: GPUParticles3D, mat: ParticleProcessMaterial) -> void:
	p.amount = 25
	p.lifetime = 4.0
	p.visibility_aabb = AABB(Vector3(-10, -2, -10), Vector3(20, 12, 20))

	# Emission: overhead box
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(8.0, 1.0, 8.0)

	# Direction: downward with lateral drift
	mat.direction = Vector3(0.3, -1.0, 0.2)
	mat.spread = 25.0

	# Velocity
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 2.5

	# Gravity: gentle pull with wind
	mat.gravity = Vector3(0.5, -2.0, 0.3)

	# Scale: leaf-sized
	mat.scale_min = 0.05
	mat.scale_max = 0.10

	# Angular velocity: tumbling
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0

	# Color: brown/orange autumn
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.7, 0.45, 0.15, 0.0))
	gradient.add_point(0.1, Color(0.75, 0.5, 0.2, 0.8))
	gradient.add_point(0.5, Color(0.65, 0.4, 0.1, 0.9))
	gradient.add_point(0.9, Color(0.5, 0.3, 0.1, 0.6))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.4, 0.25, 0.05, 0.0))
	var color_ramp: GradientTexture1D = GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	# Draw pass: flat leaf shape
	p.draw_pass_1 = _create_particle_mesh(Vector3(0.08, 0.04, 0.01))


## Embers: rising orange-red sparks, upward velocity, short lifetime
func _configure_embers(p: GPUParticles3D, mat: ParticleProcessMaterial) -> void:
	p.amount = 50
	p.lifetime = 2.0
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 10, 12))

	# Emission: ring at ground level
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 5.0

	# Direction: upward with spread
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 25.0

	# Velocity: moderate rise
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.5

	# Gravity: slight counter-gravity (embers rise)
	mat.gravity = Vector3(0.1, -1.0, 0.05)

	# Scale: tiny sparks
	mat.scale_min = 0.02
	mat.scale_max = 0.05

	# Color: orange-red fading to dark
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.8, 0.2, 0.9))
	gradient.add_point(0.3, Color(1.0, 0.5, 0.1, 0.8))
	gradient.add_point(0.7, Color(0.8, 0.2, 0.05, 0.5))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.4, 0.1, 0.0, 0.0))
	var color_ramp: GradientTexture1D = GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	# Draw pass
	p.draw_pass_1 = _create_particle_mesh(Vector3(0.03, 0.03, 0.03))


## Spores: tiny green particles, floating upward, very slow
func _configure_spores(p: GPUParticles3D, mat: ParticleProcessMaterial) -> void:
	p.amount = 20
	p.lifetime = 5.0
	p.visibility_aabb = AABB(Vector3(-8, -1, -8), Vector3(16, 8, 16))

	# Emission: ground-level sphere
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 6.0

	# Direction: upward float
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 40.0

	# Velocity: very slow
	mat.initial_velocity_min = 0.1
	mat.initial_velocity_max = 0.5

	# Gravity: negative (float up gently)
	mat.gravity = Vector3(0.0, -0.2, 0.0)

	# Scale: tiny
	mat.scale_min = 0.015
	mat.scale_max = 0.035

	# Color: green with slow fade
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.4, 0.8, 0.3, 0.0))
	gradient.add_point(0.2, Color(0.5, 0.9, 0.4, 0.5))
	gradient.add_point(0.6, Color(0.45, 0.85, 0.35, 0.6))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.3, 0.7, 0.2, 0.0))
	var color_ramp: GradientTexture1D = GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	# Draw pass
	p.draw_pass_1 = _create_particle_mesh(Vector3(0.025, 0.025, 0.025))


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — Mesh helper
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a simple BoxMesh for particle draw passes.
func _create_particle_mesh(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — Cleanup and fade
# ═══════════════════════════════════════════════════════════════════════════════

func _clear_active_particles() -> void:
	_kill_fade_tween()

	for particles: GPUParticles3D in _active_particles:
		if is_instance_valid(particles):
			particles.emitting = false
			particles.queue_free()

	_active_particles.clear()
	_active_types.clear()
	_base_amounts.clear()
	_current_biome_id = ""
	_current_intensity = DEFAULT_INTENSITY


func _fade_intensity(value: float) -> void:
	set_intensity(value)


func _on_fade_complete() -> void:
	_clear_active_particles()
	particles_stopped.emit()


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null
