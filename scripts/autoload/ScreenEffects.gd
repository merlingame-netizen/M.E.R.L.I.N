extends Node
class_name ScreenEffectsManager
## ScreenEffects — Mood-driven CRT distortion controller
## Autoload singleton that controls the CRT terminal post-process via CRTLayer.
## No longer renders its own overlay — delegates all shader parameters to ScreenDither.
##
## Usage:
##   ScreenEffects.enable()
##   ScreenEffects.disable()
##   ScreenEffects.set_intensity(0.5)
##   ScreenEffects.set_merlin_mood("mystique")

# === SIGNALS ===
signal effects_enabled
signal effects_disabled
signal intensity_changed(new_intensity: float)
signal mood_changed(mood: String)

# === CONSTANTS ===
const FADE_DURATION := 0.3
const MOOD_TRANSITION_DURATION := 0.6

# === MERLIN MOOD PROFILES ===
# Each mood maps to CRT distortion parameters reflecting Merlin's emotional state.
# Merlin is an AI from the future — his emotions ripple through the CRT screen itself.
const MOOD_PROFILES := {
	# Sage: connection claire, Merlin serein — quasi invisible
	"sage": {
		"chromatic_intensity": 0.0005,
		"scanline_wobble_intensity": 0.0002,
		"glitch_probability": 0.003,
		"barrel_intensity": 0.002,
		"color_shift_intensity": 0.0005,
		"noise_intensity": 0.015,
		"vignette_intensity": 0.08,
		"flicker_intensity": 0.004,
	},
	# Amuse/Playful: ecran presque limpide, micro-flicker joyeux
	"amuse": {
		"chromatic_intensity": 0.0003,
		"scanline_wobble_intensity": 0.0001,
		"glitch_probability": 0.001,
		"barrel_intensity": 0.001,
		"color_shift_intensity": 0.0003,
		"noise_intensity": 0.008,
		"vignette_intensity": 0.05,
		"flicker_intensity": 0.012,
	},
	# Mystique: Merlin touche l'au-dela — aberration chromatique, couleurs vibrent
	"mystique": {
		"chromatic_intensity": 0.003,
		"scanline_wobble_intensity": 0.0006,
		"glitch_probability": 0.005,
		"barrel_intensity": 0.003,
		"color_shift_intensity": 0.005,
		"noise_intensity": 0.025,
		"vignette_intensity": 0.14,
		"flicker_intensity": 0.006,
	},
	# Serieux/Warning: connexion instable, Merlin angoisse — glitches lourds
	"serieux": {
		"chromatic_intensity": 0.002,
		"scanline_wobble_intensity": 0.001,
		"glitch_probability": 0.04,
		"glitch_intensity": 0.008,
		"barrel_intensity": 0.008,
		"color_shift_intensity": 0.002,
		"noise_intensity": 0.04,
		"vignette_intensity": 0.20,
		"flicker_intensity": 0.018,
	},
	# Pensif/Melancholy: Merlin se souvient — bruit doux, vignette profonde
	"pensif": {
		"chromatic_intensity": 0.001,
		"scanline_wobble_intensity": 0.0008,
		"glitch_probability": 0.006,
		"barrel_intensity": 0.003,
		"color_shift_intensity": 0.001,
		"noise_intensity": 0.035,
		"vignette_intensity": 0.22,
		"flicker_intensity": 0.005,
	},
	# Warm: Merlin chaleureux — minimal, connexion claire
	"warm": {
		"chromatic_intensity": 0.0004,
		"scanline_wobble_intensity": 0.0002,
		"glitch_probability": 0.002,
		"barrel_intensity": 0.002,
		"color_shift_intensity": 0.0004,
		"noise_intensity": 0.012,
		"vignette_intensity": 0.06,
		"flicker_intensity": 0.006,
	},
	# Cryptic: Merlin cache quelque chose — interferences alternees
	"cryptic": {
		"chromatic_intensity": 0.004,
		"scanline_wobble_intensity": 0.001,
		"glitch_probability": 0.025,
		"glitch_intensity": 0.007,
		"barrel_intensity": 0.005,
		"color_shift_intensity": 0.004,
		"noise_intensity": 0.03,
		"vignette_intensity": 0.16,
		"flicker_intensity": 0.02,
	},
}

# Map ToneController tones to mood names
const TONE_TO_MOOD := {
	"NEUTRAL": "sage",
	"PLAYFUL": "amuse",
	"MYSTERIOUS": "mystique",
	"WARNING": "serieux",
	"MELANCHOLY": "pensif",
	"WARM": "warm",
	"CRYPTIC": "cryptic",
}

# Map MerlinPortraitManager emotions to mood names
const EMOTION_TO_MOOD := {
	"SAGE": "sage",
	"MYSTIQUE": "mystique",
	"SERIEUX": "serieux",
	"AMUSE": "amuse",
	"PENSIF": "pensif",
}

# === STATE ===
var _enabled: bool = true
var _current_intensity: float = 0.6
var _current_mood: String = "sage"
var _mood_tween: Tween
var _fade_tween: Tween

## Scene to return to when pressing Back in sub-menus (Options, Calendar, etc.)
var return_scene: String = ""

# === EFFECT NAMES (kept for API compatibility) ===
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
	# No longer creates its own overlay — CRTLayer handles all rendering
	pass


# === PRIVATE — CRTLayer reference ===

func _get_crt_layer() -> Node:
	return get_node_or_null("/root/ScreenDither")


# === PUBLIC API ===

## Enable the screen effects with optional fade
func enable(fade: bool = true) -> void:
	if _enabled:
		return
	_enabled = true
	var crt := _get_crt_layer()
	if crt == null:
		return

	if fade:
		_fade_intensity(0.0, _current_intensity, FADE_DURATION)
	else:
		crt.set_shader_parameter("global_intensity", _current_intensity)

	effects_enabled.emit()


## Disable the screen effects with optional fade
func disable(fade: bool = true) -> void:
	if not _enabled:
		return
	_enabled = false
	var crt := _get_crt_layer()
	if crt == null:
		return

	if fade:
		_fade_intensity(_current_intensity, 0.0, FADE_DURATION)
	else:
		crt.set_shader_parameter("global_intensity", 0.0)

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
	var crt := _get_crt_layer()

	if fade and crt:
		_fade_intensity(_current_intensity, new_intensity, FADE_DURATION)
	elif crt:
		crt.set_shader_parameter("global_intensity", new_intensity)

	_current_intensity = new_intensity
	intensity_changed.emit(_current_intensity)


## Get current global intensity
func get_intensity() -> float:
	return _current_intensity


## Enable/disable a specific effect
func set_effect(effect_name: String, enabled: bool) -> void:
	var crt := _get_crt_layer()
	if crt == null:
		return

	var param_name := _get_effect_param_name(effect_name)
	if param_name.is_empty():
		push_warning("ScreenEffects: Unknown effect name '%s'" % effect_name)
		return

	crt.set_shader_parameter(param_name, enabled)


## Check if a specific effect is enabled
func is_effect_enabled(effect_name: String) -> bool:
	var crt := _get_crt_layer()
	if crt == null:
		return false

	var param_name := _get_effect_param_name(effect_name)
	if param_name.is_empty():
		return false

	var val = crt.get_shader_parameter(param_name)
	return val if val != null else false


## Set a specific shader parameter directly
func set_parameter(param_name: String, value: Variant) -> void:
	var crt := _get_crt_layer()
	if crt:
		crt.set_shader_parameter(param_name, value)


## Get a shader parameter value
func get_parameter(param_name: String) -> Variant:
	var crt := _get_crt_layer()
	if crt:
		return crt.get_shader_parameter(param_name)
	return null


## Apply a preset configuration
func apply_preset(preset_name: String) -> void:
	match preset_name:
		"off":
			disable(false)

		"subtle":
			_apply_preset_values({
				"global_intensity": 1.0,
				"chromatic_intensity": 0.0008,
				"scanline_wobble_intensity": 0.0004,
				"glitch_probability": 0.008,
				"barrel_intensity": 0.004,
				"color_shift_intensity": 0.001,
				"noise_intensity": 0.02,
				"vignette_intensity": 0.10,
				"flicker_intensity": 0.008
			})

		"medium":
			_apply_preset_values({
				"global_intensity": 1.0,
				"chromatic_intensity": 0.002,
				"scanline_wobble_intensity": 0.0008,
				"glitch_probability": 0.02,
				"barrel_intensity": 0.010,
				"color_shift_intensity": 0.003,
				"noise_intensity": 0.035,
				"vignette_intensity": 0.15,
				"flicker_intensity": 0.015
			})

		"intense":
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
			_apply_preset_values({
				"global_intensity": 1.0,
				"glitch_probability": 0.15,
				"glitch_intensity": 0.015,
				"chromatic_intensity": 0.006,
				"noise_intensity": 0.05
			})

		_:
			push_warning("ScreenEffects: Unknown preset '%s'" % preset_name)


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN MOOD SYSTEM — Screen as emotional membrane
# ═══════════════════════════════════════════════════════════════════════════════

## Set Merlin's mood directly (sage, amuse, mystique, serieux, pensif, warm, cryptic)
## Smoothly transitions the distortion profile over MOOD_TRANSITION_DURATION
func set_merlin_mood(mood_name: String) -> void:
	var crt := _get_crt_layer()
	if crt == null:
		return

	var mood_key := mood_name.to_lower()
	if not MOOD_PROFILES.has(mood_key):
		push_warning("ScreenEffects: Unknown mood '%s'" % mood_name)
		return

	if mood_key == _current_mood:
		return

	_current_mood = mood_key
	var profile: Dictionary = MOOD_PROFILES[mood_key]

	# Kill any ongoing mood transition
	if _mood_tween:
		_mood_tween.kill()

	# Collect valid tweeners
	var tweens_to_add: Array[Dictionary] = []
	for param_name: String in profile:
		var raw_value = crt.get_shader_parameter(param_name)
		if raw_value == null:
			continue
		tweens_to_add.append({
			"param": param_name,
			"from": float(raw_value),
			"to": float(profile[param_name]),
		})

	if tweens_to_add.is_empty():
		mood_changed.emit(mood_key)
		return

	_mood_tween = create_tween()
	_mood_tween.set_ease(Tween.EASE_IN_OUT)
	_mood_tween.set_trans(Tween.TRANS_SINE)
	_mood_tween.set_parallel(true)

	for t in tweens_to_add:
		_mood_tween.tween_method(
			_set_crt_param.bind(t["param"]),
			t["from"],
			t["to"],
			MOOD_TRANSITION_DURATION
		)

	mood_changed.emit(mood_key)


## Set mood from a ToneController tone string (NEUTRAL, PLAYFUL, etc.)
func set_mood_from_tone(tone: String) -> void:
	var mood: String = TONE_TO_MOOD.get(tone.to_upper(), "sage")
	set_merlin_mood(mood)


## Set mood from a MerlinPortraitManager emotion string (SAGE, MYSTIQUE, etc.)
func set_mood_from_emotion(emotion: String) -> void:
	var mood: String = EMOTION_TO_MOOD.get(emotion.to_upper(), "sage")
	set_merlin_mood(mood)


## Get the current mood name
func get_merlin_mood() -> String:
	return _current_mood


## Temporarily spike distortion for narrative shock moments
## Returns to current mood after duration
func narrative_shock(duration: float = 0.4) -> void:
	var crt := _get_crt_layer()
	if crt == null:
		return

	# Save current values
	var saved_glitch_prob: float = crt.get_shader_parameter("glitch_probability")
	var saved_glitch_int: float = crt.get_shader_parameter("glitch_intensity")
	var saved_chromatic: float = crt.get_shader_parameter("chromatic_intensity")
	var saved_barrel: float = crt.get_shader_parameter("barrel_intensity")

	# Spike all distortions
	crt.set_shader_parameter("glitch_probability", 0.2)
	crt.set_shader_parameter("glitch_intensity", 0.015)
	crt.set_shader_parameter("chromatic_intensity", 0.008)
	crt.set_shader_parameter("barrel_intensity", 0.02)

	await get_tree().create_timer(duration).timeout

	# Restore smoothly
	var restore := create_tween().set_parallel(true)
	restore.set_ease(Tween.EASE_OUT)
	restore.set_trans(Tween.TRANS_QUAD)
	restore.tween_method(_set_crt_param.bind("glitch_probability"), 0.2, saved_glitch_prob, 0.3)
	restore.tween_method(_set_crt_param.bind("glitch_intensity"), 0.015, saved_glitch_int, 0.3)
	restore.tween_method(_set_crt_param.bind("chromatic_intensity"), 0.008, saved_chromatic, 0.3)
	restore.tween_method(_set_crt_param.bind("barrel_intensity"), 0.02, saved_barrel, 0.3)


## Temporarily increase glitch intensity for dramatic moments
func glitch_pulse(duration: float = 0.5, intensity: float = 0.1) -> void:
	var crt := _get_crt_layer()
	if crt == null:
		return

	var original_prob: float = crt.get_shader_parameter("glitch_probability")
	var original_int: float = crt.get_shader_parameter("glitch_intensity")

	crt.set_shader_parameter("glitch_probability", intensity)
	crt.set_shader_parameter("glitch_intensity", 0.02)

	await get_tree().create_timer(duration).timeout

	crt.set_shader_parameter("glitch_probability", original_prob)
	crt.set_shader_parameter("glitch_intensity", original_int)


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
	if _fade_tween:
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_OUT)
	_fade_tween.set_trans(Tween.TRANS_QUAD)
	_fade_tween.tween_method(_set_crt_intensity, from, to, duration)


func _set_crt_intensity(value: float) -> void:
	var crt := _get_crt_layer()
	if crt:
		crt.set_shader_parameter("global_intensity", value)


func _set_crt_param(value: float, param_name: String) -> void:
	var crt := _get_crt_layer()
	if crt:
		crt.set_shader_parameter(param_name, value)


func _apply_preset_values(values: Dictionary) -> void:
	var crt := _get_crt_layer()
	if crt == null:
		return

	for param_name: String in values:
		crt.set_shader_parameter(param_name, values[param_name])

	if values.has("global_intensity"):
		_current_intensity = values["global_intensity"]

	if not _enabled:
		enable(false)
