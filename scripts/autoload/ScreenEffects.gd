extends CanvasLayer
class_name ScreenEffectsManager
## ScreenEffects - Global screen distortion overlay
## Autoload singleton that applies subtle screen imperfections to the entire game
##
## Usage:
##   ScreenEffects.enable()
##   ScreenEffects.disable()
##   ScreenEffects.set_intensity(0.5)
##   ScreenEffects.set_effect("chromatic", false)

# === SIGNALS ===
signal effects_enabled
signal effects_disabled
signal intensity_changed(new_intensity: float)

# === CONSTANTS ===
const SHADER_PATH := "res://shaders/screen_distortion.gdshader"
const FADE_DURATION := 0.3

# === NODES ===
var _overlay: ColorRect
var _shader_material: ShaderMaterial
var _tween: Tween

# === STATE ===
var _enabled: bool = true
var _current_intensity: float = 1.0

# === EFFECT NAMES ===
const EFFECT_NAMES: Array[String] = [
	"chromatic",
	"scanline",
	"glitch",
	"barrel",
	"color_shift",
	"noise",
	"vignette",
	"flicker"
]

# === LIFECYCLE ===

func _ready() -> void:
	# Set layer to render on top of everything
	layer = 100

	_create_overlay()
	_load_shader()


func _create_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "DistortionOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Cover entire screen
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.offset_left = 0
	_overlay.offset_top = 0
	_overlay.offset_right = 0
	_overlay.offset_bottom = 0

	add_child(_overlay)


func _load_shader() -> void:
	var shader := load(SHADER_PATH) as Shader
	if shader == null:
		push_error("ScreenEffects: Could not load shader at %s" % SHADER_PATH)
		return

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_overlay.material = _shader_material


# === PUBLIC API ===

## Enable the screen effects with optional fade
func enable(fade: bool = true) -> void:
	if _enabled:
		return

	_enabled = true

	if fade and _shader_material:
		_fade_intensity(0.0, _current_intensity, FADE_DURATION)
	elif _shader_material:
		_shader_material.set_shader_parameter("global_intensity", _current_intensity)

	effects_enabled.emit()


## Disable the screen effects with optional fade
func disable(fade: bool = true) -> void:
	if not _enabled:
		return

	_enabled = false

	if fade and _shader_material:
		_fade_intensity(_current_intensity, 0.0, FADE_DURATION)
	elif _shader_material:
		_shader_material.set_shader_parameter("global_intensity", 0.0)

	effects_disabled.emit()


## Toggle effects on/off
func toggle(fade: bool = true) -> void:
	if _enabled:
		disable(fade)
	else:
		enable(fade)


## Check if effects are enabled
func is_enabled() -> bool:
	return _enabled


## Set global intensity (0.0 to 1.0)
func set_intensity(intensity: float, fade: bool = false) -> void:
	var new_intensity := clampf(intensity, 0.0, 1.0)

	if fade and _shader_material:
		_fade_intensity(_current_intensity, new_intensity, FADE_DURATION)
	elif _shader_material:
		_shader_material.set_shader_parameter("global_intensity", new_intensity)

	_current_intensity = new_intensity
	intensity_changed.emit(_current_intensity)


## Get current global intensity
func get_intensity() -> float:
	return _current_intensity


## Enable/disable a specific effect
## effect_name: "chromatic", "scanline", "glitch", "barrel", "color_shift", "noise", "vignette", "flicker"
func set_effect(effect_name: String, enabled: bool) -> void:
	if _shader_material == null:
		return

	var param_name := _get_effect_param_name(effect_name)
	if param_name.is_empty():
		push_warning("ScreenEffects: Unknown effect name '%s'" % effect_name)
		return

	_shader_material.set_shader_parameter(param_name, enabled)


## Check if a specific effect is enabled
func is_effect_enabled(effect_name: String) -> bool:
	if _shader_material == null:
		return false

	var param_name := _get_effect_param_name(effect_name)
	if param_name.is_empty():
		return false

	return _shader_material.get_shader_parameter(param_name)


## Set a specific shader parameter directly
func set_parameter(param_name: String, value: Variant) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter(param_name, value)


## Get a shader parameter value
func get_parameter(param_name: String) -> Variant:
	if _shader_material:
		return _shader_material.get_shader_parameter(param_name)
	return null


## Apply a preset configuration
func apply_preset(preset_name: String) -> void:
	match preset_name:
		"off":
			disable(false)

		"subtle":
			# Very subtle, barely noticeable (default)
			_apply_preset_values({
				"global_intensity": 1.0,
				"chromatic_intensity": 0.002,
				"scanline_wobble_intensity": 0.0008,
				"glitch_probability": 0.008,
				"barrel_intensity": 0.015,
				"color_shift_intensity": 0.003,
				"noise_intensity": 0.02,
				"vignette_intensity": 0.12,
				"flicker_intensity": 0.008
			})

		"medium":
			# More noticeable but not distracting
			_apply_preset_values({
				"global_intensity": 1.0,
				"chromatic_intensity": 0.004,
				"scanline_wobble_intensity": 0.0015,
				"glitch_probability": 0.02,
				"barrel_intensity": 0.025,
				"color_shift_intensity": 0.005,
				"noise_intensity": 0.035,
				"vignette_intensity": 0.18,
				"flicker_intensity": 0.015
			})

		"intense":
			# Clearly visible retro/VHS feel
			_apply_preset_values({
				"global_intensity": 1.0,
				"chromatic_intensity": 0.008,
				"scanline_wobble_intensity": 0.003,
				"glitch_probability": 0.05,
				"barrel_intensity": 0.04,
				"color_shift_intensity": 0.01,
				"noise_intensity": 0.06,
				"vignette_intensity": 0.25,
				"flicker_intensity": 0.025
			})

		"mobile":
			# Optimized for mobile - fewer effects, lower intensity
			_apply_preset_values({
				"global_intensity": 0.8,
				"chromatic_enabled": false,
				"scanline_enabled": false,
				"glitch_enabled": true,
				"glitch_probability": 0.005,
				"barrel_enabled": true,
				"barrel_intensity": 0.01,
				"color_shift_enabled": false,
				"noise_enabled": true,
				"noise_intensity": 0.015,
				"vignette_enabled": true,
				"vignette_intensity": 0.1,
				"flicker_enabled": false
			})

		"glitch_heavy":
			# For dramatic moments
			_apply_preset_values({
				"global_intensity": 1.0,
				"glitch_probability": 0.15,
				"glitch_intensity": 0.015,
				"chromatic_intensity": 0.006,
				"noise_intensity": 0.05
			})

		_:
			push_warning("ScreenEffects: Unknown preset '%s'" % preset_name)


## Temporarily increase glitch intensity for dramatic moments
func glitch_pulse(duration: float = 0.5, intensity: float = 0.1) -> void:
	if _shader_material == null:
		return

	var original_prob: float = _shader_material.get_shader_parameter("glitch_probability")
	var original_int: float = _shader_material.get_shader_parameter("glitch_intensity")

	_shader_material.set_shader_parameter("glitch_probability", intensity)
	_shader_material.set_shader_parameter("glitch_intensity", 0.02)

	await get_tree().create_timer(duration).timeout

	_shader_material.set_shader_parameter("glitch_probability", original_prob)
	_shader_material.set_shader_parameter("glitch_intensity", original_int)


# === PRIVATE HELPERS ===

func _get_effect_param_name(effect_name: String) -> String:
	match effect_name:
		"chromatic": return "chromatic_enabled"
		"scanline": return "scanline_enabled"
		"glitch": return "glitch_enabled"
		"barrel": return "barrel_enabled"
		"color_shift": return "color_shift_enabled"
		"noise": return "noise_enabled"
		"vignette": return "vignette_enabled"
		"flicker": return "flicker_enabled"
		_: return ""


func _fade_intensity(from: float, to: float, duration: float) -> void:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUAD)

	# Animate via callback since we're setting shader params
	_tween.tween_method(_set_shader_intensity, from, to, duration)


func _set_shader_intensity(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("global_intensity", value)


func _apply_preset_values(values: Dictionary) -> void:
	if _shader_material == null:
		return

	for param_name: String in values:
		_shader_material.set_shader_parameter(param_name, values[param_name])

	if values.has("global_intensity"):
		_current_intensity = values["global_intensity"]

	if not _enabled:
		enable(false)
