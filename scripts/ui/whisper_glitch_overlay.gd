## =====================================================================
## WhisperGlitchOverlay — Subtle visual glitch when whisper cards appear
## =====================================================================
## Attach to a ColorRect with whisper_glitch.gdshader material.
## Call trigger() when a whisper card is displayed.
## The glitch fades in briefly (0.3s), holds (0.5s), then fades out (0.5s).
## Designed to feel like reality "stuttering" — not a full glitch.
## =====================================================================

extends ColorRect
class_name WhisperGlitchOverlay


const FADE_IN_DURATION := 0.3
const HOLD_DURATION := 0.5
const FADE_OUT_DURATION := 0.5
const MAX_INTENSITY := 0.6


var _tween: Tween = null
var _is_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func trigger() -> void:
	if _is_active:
		return
	_is_active = true
	visible = true

	if _tween and _tween.is_valid():
		_tween.kill()

	_set_intensity(0.0)
	_tween = create_tween()
	# Fade in
	_tween.tween_method(_set_intensity, 0.0, MAX_INTENSITY, FADE_IN_DURATION)
	# Hold
	_tween.tween_interval(HOLD_DURATION)
	# Fade out
	_tween.tween_method(_set_intensity, MAX_INTENSITY, 0.0, FADE_OUT_DURATION)
	_tween.tween_callback(_on_complete)


func _set_intensity(value: float) -> void:
	if material and material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("intensity", value)


func _on_complete() -> void:
	_is_active = false
	visible = false


func is_glitching() -> bool:
	return _is_active
