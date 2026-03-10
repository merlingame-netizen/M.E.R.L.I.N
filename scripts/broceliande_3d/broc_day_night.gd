extends RefCounted
## BrocDayNight — Day/night cycle with sun, fog, ambient animation.
## Cycle: 0.0=dawn, 0.25=noon, 0.5=dusk, 0.75=midnight.

var _sun: DirectionalLight3D
var _env: WorldEnvironment
var _time: float = 0.05  # Start just after dawn
var _duration: float = 300.0  # 5 min = 1 full cycle
var _paused: bool = false
var _realtime_mode: bool = true  # Use system clock by default

# Color stops for gradient interpolation
const SUN_COLORS: Array[Color] = [
	Color(1.0, 0.55, 0.25),   # 0.00 dawn — warm orange
	Color(0.85, 0.80, 0.60),  # 0.25 noon — white-yellow
	Color(0.90, 0.35, 0.18),  # 0.50 dusk — deep red-orange
	Color(0.08, 0.10, 0.22),  # 0.75 midnight — dark blue
]

const FOG_COLORS: Array[Color] = [
	Color(0.45, 0.38, 0.28),  # dawn — warm amber fog
	Color(0.35, 0.45, 0.32),  # noon — green-gold (current default)
	Color(0.40, 0.28, 0.22),  # dusk — warm brown
	Color(0.08, 0.12, 0.18),  # midnight — dark blue-grey
]

const SKY_COLORS: Array[Color] = [
	Color(0.55, 0.45, 0.35),  # dawn
	Color(0.50, 0.58, 0.52),  # noon
	Color(0.45, 0.30, 0.28),  # dusk
	Color(0.03, 0.04, 0.08),  # midnight
]

const SUN_ENERGY_STOPS: Array[float] = [0.6, 1.5, 0.5, 0.05]
const SUN_PITCH_STOPS: Array[float] = [-15.0, -75.0, -165.0, -195.0]
const AMBIENT_ENERGY_STOPS: Array[float] = [0.4, 0.7, 0.35, 0.12]


func _init(sun: DirectionalLight3D, env: WorldEnvironment) -> void:
	_sun = sun
	_env = env
	if _realtime_mode:
		_time = _system_time_to_normalized()


func get_time() -> float:
	return _time


func get_is_night() -> bool:
	return _time > 0.6 or _time < 0.1


func set_duration(d: float) -> void:
	_duration = maxf(d, 10.0)


func set_paused(p: bool) -> void:
	_paused = p


func set_realtime(enabled: bool) -> void:
	_realtime_mode = enabled
	if enabled:
		_time = _system_time_to_normalized()


func update(delta: float) -> void:
	if _paused:
		return

	if _realtime_mode:
		_time = _system_time_to_normalized()
	else:
		_time += delta / _duration
		if _time >= 1.0:
			_time -= 1.0

	# Sun rotation
	var pitch: float = _lerp_stops(_time, SUN_PITCH_STOPS)
	_sun.rotation_degrees.x = pitch

	# Sun color & energy
	_sun.light_color = _lerp_color_stops(_time, SUN_COLORS)
	_sun.light_energy = _lerp_stops(_time, SUN_ENERGY_STOPS)

	# Environment
	if _env and _env.environment:
		var env_res: Environment = _env.environment
		env_res.fog_light_color = _lerp_color_stops(_time, FOG_COLORS)
		env_res.background_color = _lerp_color_stops(_time, SKY_COLORS)
		env_res.ambient_light_energy = _lerp_stops(_time, AMBIENT_ENERGY_STOPS)

		# Fog density: thicker at dawn/dusk, thinner at noon
		var density_base: float = 0.025
		var dawn_dusk_boost: float = _dawn_dusk_factor() * 0.015
		env_res.fog_density = density_base + dawn_dusk_boost


func _dawn_dusk_factor() -> float:
	# Returns 0.0-1.0, peaks at dawn (0.0) and dusk (0.5)
	var dawn_dist: float = minf(_time, 1.0 - _time) * 2.0  # 0 at dawn
	var dusk_dist: float = absf(_time - 0.5) * 2.0  # 0 at dusk
	var nearest: float = minf(dawn_dist, dusk_dist)
	return 1.0 - clampf(nearest * 4.0, 0.0, 1.0)


func _lerp_stops(t: float, stops: Array[float]) -> float:
	var count: int = stops.size()
	var segment: float = t * float(count)
	var idx: int = int(segment) % count
	var frac: float = segment - floorf(segment)
	var next_idx: int = (idx + 1) % count
	return lerpf(stops[idx], stops[next_idx], frac)


func _lerp_color_stops(t: float, stops: Array[Color]) -> Color:
	var count: int = stops.size()
	var segment: float = t * float(count)
	var idx: int = int(segment) % count
	var frac: float = segment - floorf(segment)
	var next_idx: int = (idx + 1) % count
	return stops[idx].lerp(stops[next_idx], frac)


func _system_time_to_normalized() -> float:
	## Map system clock to 0.0-1.0: 6h=dawn(0.0), 12h=noon(0.25), 18h=dusk(0.5), 0h=midnight(0.75)
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var hour: float = float(dt["hour"]) + float(dt["minute"]) / 60.0
	return fmod((hour - 6.0) / 24.0 + 1.0, 1.0)
