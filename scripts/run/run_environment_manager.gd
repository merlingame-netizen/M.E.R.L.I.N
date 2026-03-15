## ═══════════════════════════════════════════════════════════════════════════════
## RunEnvironmentManager — Orchestrates biome visuals, particles, and collectibles
## ═══════════════════════════════════════════════════════════════════════════════
## Phase 6 integration layer. Wires BiomeVisualManager, BiomeParticles, and
## CollectibleSpawner into the run lifecycle. Manages walk segment timing
## (5-15s configurable) and card pause/resume for all visual systems.
##
## Usage:
##   var env_mgr: RunEnvironmentManager = RunEnvironmentManager.new()
##   env_mgr.setup("foret_broceliande", environment_resource, world_node_3d)
##   env_mgr.start()
##   # ... during card display:
##   env_mgr.on_card_start()
##   # ... after card resolution:
##   env_mgr.on_card_end()
##   # ... at run end:
##   env_mgr.cleanup()
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name RunEnvironmentManager


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ═══════════════════════════════════════════════════════════════════════════════

signal environment_ready(biome_id: String)
signal walk_segment_started(duration: float)
signal walk_segment_ended()
signal collectible_spawned(type: String, position: Vector3)


# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS — walk segment timing (Bible s.1.3: 5-15s between cards)
# ═══════════════════════════════════════════════════════════════════════════════

const WALK_DURATION_MIN: float = 5.0
const WALK_DURATION_MAX: float = 15.0
const PARTICLE_DIM_INTENSITY: float = 0.3
const PARTICLE_FULL_INTENSITY: float = 1.0
const AMBIENT_DIM_ENERGY_FACTOR: float = 0.6
const CARD_TRANSITION_DURATION: float = 0.5


# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _biome_id: String = ""
var _environment: Environment = null
var _world_node: Node3D = null

var _visual_manager: BiomeVisualManager = null
var _particles: BiomeParticles = null
var _spawner: CollectibleSpawner = null

var _is_active: bool = false
var _is_card_active: bool = false
var _walk_timer: float = 0.0
var _current_walk_duration: float = 0.0

# Stored ambient energy for restore after card
var _base_ambient_energy: float = 1.0

# Tween for ambient dimming
var _ambient_tween: Tween = null


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP — initialize all visual subsystems for the biome
# ═══════════════════════════════════════════════════════════════════════════════

## Initializes all visual systems for the given biome. Does NOT start them.
## Call start() after setup to begin particles and ambient effects.
## @param biome_id: Key from MerlinConstants.BIOME_KEYS
## @param environment: The Environment resource for the 3D world
## @param world_node: The Node3D root containing ground mesh etc.
func setup(biome_id: String, environment: Environment, world_node: Node3D) -> void:
	_biome_id = biome_id
	_environment = environment
	_world_node = world_node
	_is_active = false
	_is_card_active = false
	_walk_timer = 0.0

	# Create visual manager
	_visual_manager = BiomeVisualManager.new()
	_visual_manager.name = "BiomeVisualManager"
	add_child(_visual_manager)

	# Create particles
	_particles = BiomeParticles.new()
	_particles.name = "BiomeParticles"
	add_child(_particles)

	# Apply biome visuals instantly (no tween on first setup)
	if _environment != null:
		_visual_manager.apply_biome_instant(biome_id, _environment, _world_node)
		_base_ambient_energy = _environment.ambient_light_energy

	# Setup particles for biome (creates GPU particle nodes but does not start yet)
	_particles.setup_for_biome(biome_id)

	environment_ready.emit(biome_id)


## Configures an external CollectibleSpawner to be managed during walk segments.
## The spawner must already be instantiated and added to the scene tree elsewhere.
func set_spawner(spawner: CollectibleSpawner) -> void:
	# Disconnect previous if any
	if _spawner != null and _spawner.collectible_spawned.is_connected(_on_collectible_spawned):
		_spawner.collectible_spawned.disconnect(_on_collectible_spawned)

	_spawner = spawner

	if _spawner != null:
		_spawner.collectible_spawned.connect(_on_collectible_spawned)


# ═══════════════════════════════════════════════════════════════════════════════
# START / STOP — run lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

## Begins particles and ambient effects. Call after setup().
func start() -> void:
	if _biome_id.is_empty():
		push_warning("[RunEnvMgr] Cannot start: no biome set (call setup first)")
		return

	_is_active = true
	_is_card_active = false

	# Ensure particles are emitting at full intensity
	if _particles != null:
		_particles.set_intensity(PARTICLE_FULL_INTENSITY)

	# Start a new walk segment
	_begin_walk_segment()


## Stops all systems gracefully. Safe to call multiple times.
func cleanup() -> void:
	_is_active = false
	_is_card_active = false

	_kill_ambient_tween()

	# Stop particles with fade
	if _particles != null and _particles.is_active():
		_particles.stop()

	# Stop spawner
	if _spawner != null:
		_spawner.stop_spawning()

	_walk_timer = 0.0
	_current_walk_duration = 0.0


# ═══════════════════════════════════════════════════════════════════════════════
# CARD PAUSE / RESUME — dim environment during card display
# ═══════════════════════════════════════════════════════════════════════════════

## Called when a card is displayed. Dims particles and ambient light.
func on_card_start() -> void:
	if not _is_active:
		return

	_is_card_active = true

	# Dim particles
	if _particles != null:
		_particles.set_intensity(PARTICLE_DIM_INTENSITY)

	# Dim ambient light
	_tween_ambient_energy(_base_ambient_energy * AMBIENT_DIM_ENERGY_FACTOR)

	# Pause spawner
	if _spawner != null:
		_spawner.stop_spawning()

	walk_segment_ended.emit()


## Called when card resolution is complete. Restores particles and ambient.
func on_card_end() -> void:
	if not _is_active:
		return

	_is_card_active = false

	# Restore particles
	if _particles != null:
		_particles.set_intensity(PARTICLE_FULL_INTENSITY)

	# Restore ambient light
	_tween_ambient_energy(_base_ambient_energy)

	# Restart walk segment with new duration
	_begin_walk_segment()


# ═══════════════════════════════════════════════════════════════════════════════
# WALK SEGMENT — timing between cards (5-15s)
# ═══════════════════════════════════════════════════════════════════════════════

## Call from _process(delta) or process_tick(delta) to advance walk timer.
## Returns true when the walk segment has completed (time to show a card).
func process_walk(delta: float) -> bool:
	if not _is_active or _is_card_active:
		return false

	_walk_timer += delta

	# Tick spawner during walk
	if _spawner != null:
		_spawner.process_tick(delta)

	if _walk_timer >= _current_walk_duration:
		walk_segment_ended.emit()
		return true

	return false


## Returns the elapsed time in the current walk segment.
func get_walk_elapsed() -> float:
	return _walk_timer


## Returns the total duration of the current walk segment.
func get_walk_duration() -> float:
	return _current_walk_duration


## Returns how much time remains in the current walk segment.
func get_walk_remaining() -> float:
	return maxf(_current_walk_duration - _walk_timer, 0.0)


# ═══════════════════════════════════════════════════════════════════════════════
# QUERIES
# ═══════════════════════════════════════════════════════════════════════════════

func is_active() -> bool:
	return _is_active


func is_card_active() -> bool:
	return _is_card_active


func get_biome_id() -> String:
	return _biome_id


func get_visual_manager() -> BiomeVisualManager:
	return _visual_manager


func get_particles() -> BiomeParticles:
	return _particles


func get_spawner() -> CollectibleSpawner:
	return _spawner


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — walk segment helpers
# ═══════════════════════════════════════════════════════════════════════════════

func _begin_walk_segment() -> void:
	_walk_timer = 0.0
	_current_walk_duration = randf_range(WALK_DURATION_MIN, WALK_DURATION_MAX)

	# Resume spawner with empty run_state (spawner only needs _spawning flag)
	if _spawner != null:
		_spawner.start_spawning({})

	walk_segment_started.emit(_current_walk_duration)


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — ambient light tween
# ═══════════════════════════════════════════════════════════════════════════════

func _tween_ambient_energy(target_energy: float) -> void:
	if _environment == null:
		return

	_kill_ambient_tween()

	_ambient_tween = create_tween()
	_ambient_tween.set_ease(Tween.EASE_IN_OUT)
	_ambient_tween.set_trans(Tween.TRANS_CUBIC)
	_ambient_tween.tween_property(
		_environment, "ambient_light_energy", target_energy, CARD_TRANSITION_DURATION
	)


func _kill_ambient_tween() -> void:
	if _ambient_tween != null and _ambient_tween.is_valid():
		_ambient_tween.kill()
		_ambient_tween = null


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — spawner signal relay
# ═══════════════════════════════════════════════════════════════════════════════

func _on_collectible_spawned(type: String, position: Vector3) -> void:
	collectible_spawned.emit(type, position)
