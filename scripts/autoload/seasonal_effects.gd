## ═══════════════════════════════════════════════════════════════════════════════
## SeasonalEffects — Autoload for seasonal visual effects
## ═══════════════════════════════════════════════════════════════════════════════
## Manages seasonal particle effects (snow, leaves, flowers, heat) on menu scenes.
## Piloted by in-game calendar (not real-world seasons).

extends CanvasLayer

const EFFECT_LAYER := 50  # Between UI and game world

var _particles_container: Control
var _shader_material: ShaderMaterial
var _current_season: String = ""
var _enabled: bool = true

# Season type mapping for shader
const SEASON_SHADER_TYPE := {
	"printemps": 0,  # Spring - flowers
	"ete": 1,        # Summer - heat shimmer
	"automne": 2,    # Autumn - leaves
	"hiver": 3,      # Winter - snow
}

# Season particle settings (color, density)
const SEASON_SETTINGS := {
	"printemps": {"color": Color(0.70, 0.90, 0.60, 0.15), "density": 0.35},
	"ete": {"color": Color(0.95, 0.90, 0.60, 0.12), "density": 0.25},
	"automne": {"color": Color(0.90, 0.70, 0.45, 0.18), "density": 0.45},
	"hiver": {"color": Color(0.80, 0.85, 0.95, 0.20), "density": 0.50},
}


func _ready() -> void:
	layer = EFFECT_LAYER
	name = "SeasonalEffects"

	# Create fullscreen particle overlay
	_particles_container = ColorRect.new()
	_particles_container.name = "ParticlesOverlay"
	_particles_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_particles_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_particles_container.color = Color(1, 1, 1, 1)  # White base for shader
	add_child(_particles_container)

	# Load seasonal shader
	var shader: Shader = load("res://shaders/seasonal_particles.gdshader")
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_particles_container.material = _shader_material

	# Initialize with current season from MerlinVisual
	update_season()


## Update seasonal effect based on in-game calendar
func update_season(season_key: String = "") -> void:
	if season_key.is_empty():
		# Get from calendar if available, fallback to real-world season
		if has_node("/root/Calendar"):
			var calendar: Node = get_node("/root/Calendar")
			if calendar.has_method("get_season"):
				season_key = calendar.get_season()

	if season_key.is_empty():
		# Fallback to MerlinVisual real-world season
		var en_season: String = MerlinVisual.get_current_season()
		season_key = MerlinVisual.SEASON_KEY_MAP.get(en_season, "hiver")

	if season_key == _current_season:
		return

	_current_season = season_key
	_apply_season_shader()


func _apply_season_shader() -> void:
	if not _shader_material:
		return

	var season_type: int = SEASON_SHADER_TYPE.get(_current_season, 3)
	var settings: Dictionary = SEASON_SETTINGS.get(_current_season, SEASON_SETTINGS["hiver"])

	_shader_material.set_shader_parameter("season_type", season_type)
	_shader_material.set_shader_parameter("particle_color", settings["color"])
	_shader_material.set_shader_parameter("particle_density", settings["density"])
	_shader_material.set_shader_parameter("animation_speed", 1.0)

	_particles_container.visible = _enabled


## Enable/disable seasonal effects
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _particles_container:
		_particles_container.visible = enabled


## Check if effects are enabled
func is_enabled() -> bool:
	return _enabled


## Force specific season (for testing or special events)
func set_season(season_key: String) -> void:
	if SEASON_SHADER_TYPE.has(season_key):
		update_season(season_key)


## Get current active season
func get_current_season() -> String:
	return _current_season
