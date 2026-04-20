## DayNightManager — Global day/night cycle with procedural sky shader.
##
## Autoload singleton that manages time-of-day visuals for all 3D scenes.
## Reads system clock to determine one of 7 periods (night, dawn, morning,
## midday, afternoon, dusk, evening), then provides:
##   - ProceduralSkyMaterial configured per period
##   - DirectionalLight3D sun color, energy, angle
##   - Environment ambient, fog, background settings
##
## Usage from any 3D scene:
##   # After creating your SubViewport + Environment:
##   DayNightManager.apply_to_environment(my_environment)
##   var sun_cfg: Dictionary = DayNightManager.get_sun_config()
##   my_sun.light_color = sun_cfg.color
##   my_sun.light_energy = sun_cfg.energy
##   my_sun.rotation_degrees = sun_cfg.angle
##
##   # Or for a complete SubViewport setup (creates WorldEnvironment + sun):
##   DayNightManager.apply_to_viewport(my_subviewport)
##
## Integration with other scenes:
##   HubAntre, TransitionBiome, Run3D — call apply_to_viewport(subviewport)
##   or apply_to_environment(env) + get_sun_config() for fine-grained control.
##   The manager does NOT auto-update; scenes should call apply methods on
##   _ready() and optionally connect to the period_changed signal for live
##   transitions during long sessions.

extends Node

# ═══════════════════════════════════════════════════════════════
# SIGNALS
# ═══════════════════════════════════════════════════════════════

## Emitted when the visual period changes (e.g. "morning" -> "midday").
signal period_changed(new_period: String)

# ═══════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════

var _current_period: String = ""
var _check_timer: Timer

## Tracked viewports for optional live-update
var _tracked_viewports: Array[SubViewport] = []

# ═══════════════════════════════════════════════════════════════
# TIME PERIOD CONFIGURATIONS — Celtic atmosphere
# ═══════════════════════════════════════════════════════════════
#
# Each period defines the full visual state:
#   sky_top_color       — ProceduralSkyMaterial top color (zenith)
#   sky_horizon_color   — ProceduralSkyMaterial horizon color
#   sky_bottom_color    — ProceduralSkyMaterial ground bottom color
#   sky_curve           — ProceduralSkyMaterial sky curve (gradient shape)
#   sun_color           — DirectionalLight3D light_color
#   sun_energy          — DirectionalLight3D light_energy
#   sun_angle           — DirectionalLight3D rotation_degrees (Vector3)
#   ambient_color       — Environment ambient_light_color
#   ambient_energy      — Environment ambient_light_energy
#   fog_color           — Environment fog_light_color
#   fog_density         — Environment fog_density
#   fog_sky_affect      — Environment fog_sky_affect
#   glow_intensity      — Environment glow_intensity
#   glow_bloom          — Environment glow_bloom
# ═══════════════════════════════════════════════════════════════

const PERIOD_CONFIGS: Dictionary = {
	"night": {
		"sky_top_color": Color(0.02, 0.02, 0.08),
		"sky_horizon_color": Color(0.05, 0.04, 0.12),
		"sky_bottom_color": Color(0.01, 0.01, 0.04),
		"sky_curve": 0.15,
		"sun_color": Color(0.18, 0.16, 0.30),
		"sun_energy": 0.15,
		"sun_angle": Vector3(-15.0, -60.0, 0.0),
		"ambient_color": Color(0.06, 0.05, 0.14),
		"ambient_energy": 0.25,
		"fog_color": Color(0.04, 0.03, 0.09),
		"fog_density": 0.020,
		"fog_sky_affect": 0.8,
		"glow_intensity": 0.15,
		"glow_bloom": 0.05,
	},
	"dawn": {
		"sky_top_color": Color(0.20, 0.10, 0.30),
		"sky_horizon_color": Color(0.90, 0.45, 0.20),
		"sky_bottom_color": Color(0.08, 0.04, 0.06),
		"sky_curve": 0.20,
		"sun_color": Color(0.95, 0.55, 0.25),
		"sun_energy": 0.45,
		"sun_angle": Vector3(-5.0, -80.0, 0.0),
		"ambient_color": Color(0.22, 0.14, 0.12),
		"ambient_energy": 0.35,
		"fog_color": Color(0.25, 0.15, 0.10),
		"fog_density": 0.025,
		"fog_sky_affect": 0.6,
		"glow_intensity": 0.25,
		"glow_bloom": 0.12,
	},
	"morning": {
		"sky_top_color": Color(0.30, 0.50, 0.80),
		"sky_horizon_color": Color(0.70, 0.75, 0.85),
		"sky_bottom_color": Color(0.15, 0.18, 0.12),
		"sky_curve": 0.25,
		"sun_color": Color(0.95, 0.85, 0.65),
		"sun_energy": 0.70,
		"sun_angle": Vector3(-25.0, -50.0, 0.0),
		"ambient_color": Color(0.20, 0.18, 0.15),
		"ambient_energy": 0.45,
		"fog_color": Color(0.18, 0.16, 0.14),
		"fog_density": 0.010,
		"fog_sky_affect": 0.4,
		"glow_intensity": 0.20,
		"glow_bloom": 0.08,
	},
	"midday": {
		"sky_top_color": Color(0.25, 0.55, 0.90),
		"sky_horizon_color": Color(0.65, 0.78, 0.92),
		"sky_bottom_color": Color(0.18, 0.22, 0.14),
		"sky_curve": 0.30,
		"sun_color": Color(1.0, 0.95, 0.88),
		"sun_energy": 0.90,
		"sun_angle": Vector3(-60.0, -30.0, 0.0),
		"ambient_color": Color(0.25, 0.23, 0.20),
		"ambient_energy": 0.50,
		"fog_color": Color(0.20, 0.18, 0.15),
		"fog_density": 0.005,
		"fog_sky_affect": 0.3,
		"glow_intensity": 0.18,
		"glow_bloom": 0.06,
	},
	"afternoon": {
		"sky_top_color": Color(0.28, 0.50, 0.82),
		"sky_horizon_color": Color(0.75, 0.70, 0.55),
		"sky_bottom_color": Color(0.16, 0.18, 0.10),
		"sky_curve": 0.25,
		"sun_color": Color(0.95, 0.80, 0.50),
		"sun_energy": 0.75,
		"sun_angle": Vector3(-40.0, 30.0, 0.0),
		"ambient_color": Color(0.22, 0.18, 0.14),
		"ambient_energy": 0.45,
		"fog_color": Color(0.18, 0.14, 0.10),
		"fog_density": 0.008,
		"fog_sky_affect": 0.4,
		"glow_intensity": 0.22,
		"glow_bloom": 0.08,
	},
	"dusk": {
		"sky_top_color": Color(0.15, 0.08, 0.25),
		"sky_horizon_color": Color(0.85, 0.30, 0.12),
		"sky_bottom_color": Color(0.06, 0.03, 0.04),
		"sky_curve": 0.20,
		"sun_color": Color(0.90, 0.35, 0.15),
		"sun_energy": 0.45,
		"sun_angle": Vector3(-8.0, 70.0, 0.0),
		"ambient_color": Color(0.18, 0.10, 0.12),
		"ambient_energy": 0.30,
		"fog_color": Color(0.22, 0.10, 0.08),
		"fog_density": 0.018,
		"fog_sky_affect": 0.6,
		"glow_intensity": 0.30,
		"glow_bloom": 0.15,
	},
	"evening": {
		"sky_top_color": Color(0.06, 0.04, 0.15),
		"sky_horizon_color": Color(0.12, 0.08, 0.22),
		"sky_bottom_color": Color(0.03, 0.02, 0.06),
		"sky_curve": 0.18,
		"sun_color": Color(0.30, 0.25, 0.50),
		"sun_energy": 0.30,
		"sun_angle": Vector3(-20.0, -55.0, 0.0),
		"ambient_color": Color(0.10, 0.08, 0.16),
		"ambient_energy": 0.30,
		"fog_color": Color(0.08, 0.06, 0.14),
		"fog_density": 0.015,
		"fog_sky_affect": 0.7,
		"glow_intensity": 0.20,
		"glow_bloom": 0.08,
	},
}


# ═══════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	_current_period = _compute_period_from_clock()

	# Periodic check every 60 seconds for period transitions
	_check_timer = Timer.new()
	_check_timer.wait_time = 60.0
	_check_timer.autostart = true
	_check_timer.timeout.connect(_on_check_timeout)
	add_child(_check_timer)

	print("[DayNightManager] Ready — period: %s" % _current_period)


# ═══════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════

func get_time_of_day() -> String:
	## Returns the current visual period key.
	## One of: "night", "dawn", "morning", "midday", "afternoon", "dusk", "evening"
	return _current_period


func get_sun_config() -> Dictionary:
	## Returns a dictionary with sun properties for the current period:
	##   { "color": Color, "energy": float, "angle": Vector3 }
	## Use to configure a DirectionalLight3D:
	##   var cfg: Dictionary = DayNightManager.get_sun_config()
	##   sun.light_color = cfg.color
	##   sun.light_energy = cfg.energy
	##   sun.rotation_degrees = cfg.angle
	var cfg: Dictionary = _get_current_config()
	return {
		"color": cfg.get("sun_color", Color(1.0, 0.95, 0.85)),
		"energy": cfg.get("sun_energy", 0.7),
		"angle": cfg.get("sun_angle", Vector3(-45.0, -45.0, 0.0)),
	}


func get_fill_light_config() -> Dictionary:
	## Returns suggested fill light settings for the current period:
	##   { "color": Color, "energy": float }
	## Derived from ambient color with a slight warm shift.
	var cfg: Dictionary = _get_current_config()
	var ambient_col: Color = cfg.get("ambient_color", Color(0.2, 0.18, 0.15))
	var sun_col: Color = cfg.get("sun_color", Color(1.0, 0.95, 0.85))
	# Fill light: blend of ambient and sun, slightly dimmer
	var fill_color: Color = ambient_col.lerp(sun_col, 0.4)
	var fill_energy: float = cfg.get("sun_energy", 0.7) * 0.8
	return {
		"color": fill_color,
		"energy": fill_energy,
	}


func apply_to_environment(env: Environment) -> void:
	## Configures an Environment with procedural sky, ambient light, fog,
	## and glow for the current time of day. Call once on scene setup
	## or when period_changed fires.
	##
	## This sets background_mode to BG_SKY with a ProceduralSkyMaterial.
	var cfg: Dictionary = _get_current_config()

	# --- Sky ---
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = cfg.get("sky_top_color", Color(0.25, 0.55, 0.90))
	sky_material.sky_horizon_color = cfg.get("sky_horizon_color", Color(0.65, 0.78, 0.92))
	sky_material.sky_curve = cfg.get("sky_curve", 0.25)
	sky_material.ground_bottom_color = cfg.get("sky_bottom_color", Color(0.18, 0.22, 0.14))
	sky_material.ground_horizon_color = cfg.get("sky_horizon_color", Color(0.65, 0.78, 0.92))
	sky_material.ground_curve = cfg.get("sky_curve", 0.25)
	sky_material.sun_angle_max = 30.0
	sky_material.sun_curve = 0.15

	# Tint sun disc in the sky material to match our sun color
	var sun_col: Color = cfg.get("sun_color", Color(1.0, 0.95, 0.85))
	sky_material.sky_energy_multiplier = clampf(cfg.get("sun_energy", 0.7), 0.3, 1.2)

	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	env.background_mode = Environment.BG_SKY
	env.sky = sky

	# --- Ambient ---
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = cfg.get("ambient_color", Color(0.2, 0.18, 0.15))
	env.ambient_light_energy = cfg.get("ambient_energy", 0.45)
	env.ambient_light_sky_contribution = 0.5

	# --- Fog ---
	env.fog_enabled = true
	env.fog_light_color = cfg.get("fog_color", Color(0.15, 0.13, 0.10))
	env.fog_density = cfg.get("fog_density", 0.01)
	env.fog_sky_affect = cfg.get("fog_sky_affect", 0.4)
	env.fog_light_energy = clampf(cfg.get("sun_energy", 0.7) * 0.6, 0.1, 0.8)

	# --- Tone mapping (GL Compat uses FILMIC, not ACES) ---
	env.tonemap_mode = Environment.TONE_MAP_FILMIC

	# --- Glow ---
	env.glow_enabled = true
	env.glow_intensity = cfg.get("glow_intensity", 0.2)
	env.glow_bloom = cfg.get("glow_bloom", 0.08)


func apply_to_viewport(viewport: SubViewport) -> void:
	## Complete setup: creates WorldEnvironment + DirectionalLight3D in the
	## given SubViewport, fully configured for the current time of day.
	## Tracks the viewport for live-update on period change.
	##
	## Usage from any 3D scene:
	##   var vp: SubViewport = SubViewport.new()
	##   # ... configure size, msaa, etc ...
	##   DayNightManager.apply_to_viewport(vp)

	# Check if already has a WorldEnvironment — update it instead of duplicating
	var world_env: WorldEnvironment = null
	for child in viewport.get_children():
		if child is WorldEnvironment:
			world_env = child as WorldEnvironment
			break

	if world_env == null:
		world_env = WorldEnvironment.new()
		world_env.name = "DayNightWorldEnv"
		world_env.environment = Environment.new()
		viewport.add_child(world_env)

	apply_to_environment(world_env.environment)

	# Check if already has a DirectionalLight3D sun — update or create
	var sun: DirectionalLight3D = null
	for child in viewport.get_children():
		if child is DirectionalLight3D and child.name == "DayNightSun":
			sun = child as DirectionalLight3D
			break

	if sun == null:
		sun = DirectionalLight3D.new()
		sun.name = "DayNightSun"
		sun.shadow_enabled = true
		viewport.add_child(sun)

	var sun_cfg: Dictionary = get_sun_config()
	sun.light_color = sun_cfg.get("color", Color.WHITE)
	sun.light_energy = sun_cfg.get("energy", 0.7)
	sun.rotation_degrees = sun_cfg.get("angle", Vector3(-45.0, -45.0, 0.0))

	# Track for live updates
	if viewport not in _tracked_viewports:
		_tracked_viewports.append(viewport)


func remove_viewport(viewport: SubViewport) -> void:
	## Stop tracking a viewport for live updates. Call when the scene exits.
	_tracked_viewports.erase(viewport)


func get_period_config(period_name: String) -> Dictionary:
	## Returns the full configuration dictionary for a specific period.
	## Useful for previewing or interpolating between periods.
	return PERIOD_CONFIGS.get(period_name, PERIOD_CONFIGS["midday"]).duplicate()


func force_period(period_name: String) -> void:
	## Override the current period (useful for testing/debug).
	## Pass "" to return to system-clock-based detection.
	if period_name == "":
		_current_period = _compute_period_from_clock()
	elif period_name in PERIOD_CONFIGS:
		_current_period = period_name
	else:
		push_warning("[DayNightManager] Unknown period: %s" % period_name)
		return
	period_changed.emit(_current_period)
	_refresh_tracked_viewports()


# ═══════════════════════════════════════════════════════════════
# PRIVATE HELPERS
# ═══════════════════════════════════════════════════════════════

func _compute_period_from_clock() -> String:
	## Maps system hour to one of 7 visual periods.
	var hour: int = Time.get_datetime_dict_from_system().get("hour", 12)
	if hour < 5:
		return "night"
	if hour < 7:
		return "dawn"
	if hour < 10:
		return "morning"
	if hour < 14:
		return "midday"
	if hour < 17:
		return "afternoon"
	if hour < 20:
		return "dusk"
	if hour < 22:
		return "evening"
	return "night"


func _get_current_config() -> Dictionary:
	## Returns the configuration dictionary for the current period.
	return PERIOD_CONFIGS.get(_current_period, PERIOD_CONFIGS["midday"])


func _on_check_timeout() -> void:
	## Periodic re-check: detect period transitions and update tracked viewports.
	var new_period: String = _compute_period_from_clock()
	if new_period != _current_period:
		var old_period: String = _current_period
		_current_period = new_period
		print("[DayNightManager] Period changed: %s -> %s" % [old_period, new_period])
		period_changed.emit(_current_period)
		_refresh_tracked_viewports()


func _refresh_tracked_viewports() -> void:
	## Re-apply lighting to all tracked viewports after a period change.
	var stale: Array[SubViewport] = []
	for vp in _tracked_viewports:
		if is_instance_valid(vp):
			apply_to_viewport(vp)
		else:
			stale.append(vp)

	# Clean up freed viewports
	for vp in stale:
		_tracked_viewports.erase(vp)
