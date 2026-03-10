extends RefCounted
## BrocEvents — Random atmospheric events during forest walk.
## 8 event types triggered by timer (20-45s) or zone change.

var _forest_root: Node3D
var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _timer: float = 0.0
var _cooldown: float = 0.0
var _next_interval: float = 25.0
var _last_zone: int = -1
var _active_event: Dictionary = {}  # {type, timer, nodes}

const EVENT_MESSAGES: Array[String] = [
	"Une brise magique souffle entre les arbres...",
	"Une luciole geante passe devant vous...",
	"Un murmure ancien resonne dans la foret...",
	"Une eclaircie soudaine illumine la clairiere...",
	"Une brume epaisse envahit les sous-bois...",
	"Un cercle de champignons apparait...",
	"Une pierre brille d'une lueur mystique...",
	"Une ombre furtive traverse au loin...",
]


func _init(forest_root: Node3D, env: WorldEnvironment, sun: DirectionalLight3D) -> void:
	_forest_root = forest_root
	_env = env
	_sun = sun
	_rng.randomize()
	_next_interval = _rng.randf_range(20.0, 45.0)


func update(delta: float, player_pos: Vector3, current_zone: int, day_time: float) -> String:
	var result: String = ""

	# Update active event
	if not _active_event.is_empty():
		_active_event["timer"] -= delta
		_update_active_event(delta, player_pos)
		if _active_event["timer"] <= 0.0:
			_cleanup_event()

	# Check zone change trigger
	if current_zone != _last_zone and _last_zone >= 0 and _cooldown <= 0.0:
		_last_zone = current_zone
		result = _trigger_random_event(player_pos, day_time)
		_cooldown = 8.0
		return result
	_last_zone = current_zone

	# Timer trigger
	_cooldown = maxf(_cooldown - delta, 0.0)
	_timer += delta
	if _timer >= _next_interval and _cooldown <= 0.0:
		_timer = 0.0
		_next_interval = _rng.randf_range(20.0, 45.0)
		result = _trigger_random_event(player_pos, day_time)
		_cooldown = 8.0

	return result


func _trigger_random_event(player_pos: Vector3, day_time: float) -> String:
	if not _active_event.is_empty():
		return ""

	var event_type: int = _rng.randi_range(0, 7)

	match event_type:
		0: _event_magic_breeze(player_pos)
		1: _event_giant_firefly(player_pos)
		2: pass  # Murmure — message only
		3: _event_sunburst()
		4: _event_thick_mist()
		5: _event_mushroom_circle(player_pos)
		6: _event_glowing_stone(player_pos)
		7: _event_shadow(player_pos)

	_active_event = {"type": event_type, "timer": _get_event_duration(event_type), "nodes": []}
	print("[BrocEvents] Triggered: %s" % EVENT_MESSAGES[event_type])
	return EVENT_MESSAGES[event_type]


func _get_event_duration(event_type: int) -> float:
	match event_type:
		0: return 4.0   # breeze
		1: return 3.0   # firefly
		2: return 2.0   # murmure
		3: return 5.0   # sunburst
		4: return 8.0   # mist
		5: return 10.0  # mushroom circle
		6: return 4.0   # glowing stone
		7: return 2.5   # shadow
	return 3.0


func _event_magic_breeze(player_pos: Vector3) -> void:
	# Spawn wind particles (subtle light moving sideways)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(0.7, 0.9, 0.6)
	light.light_energy = 0.4
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.position = player_pos + Vector3(_rng.randf_range(-3.0, 3.0), 1.5, _rng.randf_range(-3.0, 3.0))
	_forest_root.add_child(light)
	_active_event["nodes"] = [light]


func _event_giant_firefly(player_pos: Vector3) -> void:
	var orb: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	mesh.radial_segments = 8
	mesh.rings = 4
	orb.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 1.0, 0.3, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.5, 1.0, 0.3)
	mat.emission_energy_multiplier = 5.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb.material_override = mat
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.position = player_pos + Vector3(2.0, 1.0, -3.0)
	_forest_root.add_child(orb)

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(0.5, 1.0, 0.3)
	light.light_energy = 0.6
	light.omni_range = 4.0
	light.shadow_enabled = false
	light.position = orb.position
	_forest_root.add_child(light)

	_active_event["nodes"] = [orb, light]
	_active_event["start_pos"] = orb.position
	_active_event["end_pos"] = player_pos + Vector3(-4.0, 2.5, 5.0)


func _event_sunburst() -> void:
	_active_event["original_energy"] = _sun.light_energy


func _event_thick_mist() -> void:
	if _env and _env.environment:
		_active_event["original_density"] = _env.environment.fog_density


func _event_mushroom_circle(player_pos: Vector3) -> void:
	var nodes: Array = []
	var center: Vector3 = player_pos + Vector3(_rng.randf_range(-5.0, 5.0), 0.0, _rng.randf_range(-5.0, 5.0))
	for i in range(8):
		var angle: float = float(i) * TAU / 8.0
		var pos: Vector3 = center + Vector3(cos(angle) * 1.5, 0.0, sin(angle) * 1.5)
		var mush: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.height = 0.3
		mesh.bottom_radius = 0.08
		mesh.top_radius = 0.15
		mesh.radial_segments = 6
		mush.mesh = mesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.3, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.4, 0.2)
		mat.emission_energy_multiplier = 1.5
		mush.material_override = mat
		mush.position = pos
		mush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_forest_root.add_child(mush)
		nodes.append(mush)
	_active_event["nodes"] = nodes


func _event_glowing_stone(player_pos: Vector3) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(0.3, 0.5, 0.9)
	light.light_energy = 0.8
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.position = player_pos + Vector3(_rng.randf_range(-4.0, 4.0), 0.3, _rng.randf_range(-4.0, 4.0))
	_forest_root.add_child(light)
	_active_event["nodes"] = [light]


func _event_shadow(player_pos: Vector3) -> void:
	var shadow: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.4, 1.8, 0.3)
	shadow.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.08, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = player_pos + Vector3(15.0, 0.9, _rng.randf_range(-5.0, 5.0))
	_forest_root.add_child(shadow)
	_active_event["nodes"] = [shadow]
	_active_event["start_pos"] = shadow.position
	_active_event["end_pos"] = shadow.position + Vector3(-30.0, 0.0, _rng.randf_range(-3.0, 3.0))


func _update_active_event(delta: float, player_pos: Vector3) -> void:
	var event_type: int = _active_event.get("type", -1)
	var duration: float = _get_event_duration(event_type)
	var elapsed: float = duration - _active_event["timer"]
	var progress: float = clampf(elapsed / duration, 0.0, 1.0)

	match event_type:
		1:  # Giant firefly — move from start to end
			if _active_event.has("start_pos") and _active_event.has("end_pos"):
				var pos: Vector3 = (_active_event["start_pos"] as Vector3).lerp(_active_event["end_pos"] as Vector3, progress)
				pos.y += sin(elapsed * 4.0) * 0.3
				var nodes: Array = _active_event.get("nodes", [])
				for n in nodes:
					if is_instance_valid(n):
						(n as Node3D).position = pos
		3:  # Sunburst — boost sun energy then fade
			var boost: float = sin(progress * PI) * 1.5
			_sun.light_energy = (_active_event.get("original_energy", 1.0) as float) + boost
		4:  # Thick mist — increase fog then fade
			if _env and _env.environment:
				var base: float = _active_event.get("original_density", 0.025) as float
				var extra: float = sin(progress * PI) * 0.03
				_env.environment.fog_density = base + extra
		7:  # Shadow — move across
			if _active_event.has("start_pos") and _active_event.has("end_pos"):
				var pos: Vector3 = (_active_event["start_pos"] as Vector3).lerp(_active_event["end_pos"] as Vector3, progress)
				var nodes: Array = _active_event.get("nodes", [])
				for n in nodes:
					if is_instance_valid(n):
						(n as Node3D).position = pos


func _cleanup_event() -> void:
	var event_type: int = _active_event.get("type", -1)

	# Restore sun/fog if needed
	if event_type == 3 and _active_event.has("original_energy"):
		_sun.light_energy = _active_event["original_energy"] as float
	if event_type == 4 and _env and _env.environment and _active_event.has("original_density"):
		_env.environment.fog_density = _active_event["original_density"] as float

	# Remove spawned nodes
	var nodes: Array = _active_event.get("nodes", [])
	for n in nodes:
		if is_instance_valid(n):
			(n as Node3D).queue_free()

	_active_event = {}
