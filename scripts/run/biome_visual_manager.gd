## ═══════════════════════════════════════════════════════════════════════════════
## BiomeVisualManager — Tweens 3D environment properties for biome transitions
## ═══════════════════════════════════════════════════════════════════════════════
## Reads a BiomeConfig preset and smoothly transitions the Environment node
## (sky, fog, ambient light) and ground material over a configurable duration.
## Emits biome_transition_complete when the tween finishes.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name BiomeVisualManager


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ═══════════════════════════════════════════════════════════════════════════════

signal biome_transition_complete(biome_id: String)


# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const DEFAULT_TRANSITION_DURATION: float = 1.0
const MIN_TRANSITION_DURATION: float = 0.05


# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _current_biome_id: String = ""
var _active_tween: Tween = null


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the currently applied biome ID (empty string if none applied yet).
func get_current_biome_id() -> String:
	return _current_biome_id


## Apply a biome's visual config to the given Environment and world node.
## Tweens all properties over `duration` seconds. If a transition is already
## running, it is killed and replaced by the new one.
## @param biome_id: Key from MerlinConstants.BIOME_KEYS
## @param environment: The Environment resource to modify
## @param world_node: The Node3D root that may contain ground MeshInstance3D
## @param duration: Transition time in seconds (default 1.0)
func apply_biome(
	biome_id: String,
	environment: Environment,
	world_node: Node3D,
	duration: float = DEFAULT_TRANSITION_DURATION,
) -> void:
	if environment == null:
		push_warning("BiomeVisualManager: environment is null, skipping apply_biome")
		return

	var config: BiomeConfig = BiomeConfig.get_config(biome_id)
	var safe_duration: float = maxf(duration, MIN_TRANSITION_DURATION)

	# Kill any in-progress transition
	_kill_active_tween()

	_current_biome_id = biome_id

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	_active_tween = tween

	# --- Sky ---
	_tween_sky(tween, environment, config, safe_duration)

	# --- Fog ---
	_tween_fog(tween, environment, config, safe_duration)

	# --- Ambient light ---
	_tween_ambient(tween, environment, config, safe_duration)

	# --- Ground material ---
	if world_node != null:
		_tween_ground(tween, world_node, config, safe_duration)

	# Completion callback (must be chained after parallel group)
	var callback_tween: Tween = create_tween()
	callback_tween.tween_interval(safe_duration)
	callback_tween.tween_callback(_on_transition_finished.bind(biome_id))


## Immediately apply a biome without tweening (useful for initialization).
## @param biome_id: Key from MerlinConstants.BIOME_KEYS
## @param environment: The Environment resource to modify
## @param world_node: The Node3D root (optional)
func apply_biome_instant(
	biome_id: String,
	environment: Environment,
	world_node: Node3D,
) -> void:
	if environment == null:
		push_warning("BiomeVisualManager: environment is null, skipping apply_biome_instant")
		return

	_kill_active_tween()

	var config: BiomeConfig = BiomeConfig.get_config(biome_id)
	_current_biome_id = biome_id

	# Sky
	if environment.background_mode == Environment.BG_COLOR:
		environment.background_color = config.sky_color
	environment.sky_rotation = Vector3.ZERO

	# Fog
	environment.fog_enabled = config.fog_density > 0.0
	environment.fog_light_color = config.fog_color
	environment.fog_density = config.fog_density

	# Ambient
	environment.ambient_light_color = config.ambient_light_color
	environment.ambient_light_energy = config.ambient_light_energy

	# Ground
	if world_node != null:
		_apply_ground_color_instant(world_node, config.ground_color)

	biome_transition_complete.emit(biome_id)


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — Tween helpers
# ═══════════════════════════════════════════════════════════════════════════════

func _tween_sky(tween: Tween, env: Environment, config: BiomeConfig, duration: float) -> void:
	if env.background_mode == Environment.BG_COLOR:
		tween.tween_property(env, "background_color", config.sky_color, duration)


func _tween_fog(tween: Tween, env: Environment, config: BiomeConfig, duration: float) -> void:
	if not env.fog_enabled and config.fog_density > 0.0:
		env.fog_enabled = true
	tween.tween_property(env, "fog_light_color", config.fog_color, duration)
	tween.tween_property(env, "fog_density", config.fog_density, duration)


func _tween_ambient(tween: Tween, env: Environment, config: BiomeConfig, duration: float) -> void:
	tween.tween_property(env, "ambient_light_color", config.ambient_light_color, duration)
	tween.tween_property(env, "ambient_light_energy", config.ambient_light_energy, duration)


func _tween_ground(tween: Tween, world_node: Node3D, config: BiomeConfig, duration: float) -> void:
	var ground: MeshInstance3D = _find_ground_mesh(world_node)
	if ground == null:
		return

	var mat: Material = ground.get_surface_override_material(0)
	if mat == null:
		mat = ground.mesh.surface_get_material(0) if ground.mesh != null else null
	if mat == null:
		return

	if mat is StandardMaterial3D:
		var std_mat: StandardMaterial3D = mat as StandardMaterial3D
		tween.tween_property(std_mat, "albedo_color", config.ground_color, duration)


func _apply_ground_color_instant(world_node: Node3D, color: Color) -> void:
	var ground: MeshInstance3D = _find_ground_mesh(world_node)
	if ground == null:
		return

	var mat: Material = ground.get_surface_override_material(0)
	if mat == null:
		mat = ground.mesh.surface_get_material(0) if ground.mesh != null else null
	if mat == null:
		return

	if mat is StandardMaterial3D:
		var std_mat: StandardMaterial3D = mat as StandardMaterial3D
		std_mat.albedo_color = color


func _find_ground_mesh(world_node: Node3D) -> MeshInstance3D:
	# Search for a child node named "Ground", "Terrain", or "Floor"
	for name_candidate: String in ["Ground", "Terrain", "Floor"]:
		var node: Node = world_node.find_child(name_candidate, true, false)
		if node is MeshInstance3D:
			return node as MeshInstance3D
	# Fallback: first MeshInstance3D child with "ground" in name (case-insensitive)
	for child: Node in world_node.get_children():
		if child is MeshInstance3D and child.name.to_lower().contains("ground"):
			return child as MeshInstance3D
	return null


func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null


func _on_transition_finished(biome_id: String) -> void:
	_active_tween = null
	biome_transition_complete.emit(biome_id)
