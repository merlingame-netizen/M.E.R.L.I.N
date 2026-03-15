extends Node
class_name AccessibilitySystem

## Accessibility system — colorblind modes, text scaling, high contrast,
## screen reader hints, reduced motion, with persistence support.

signal settings_changed

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

enum ColorblindMode {
	NONE = 0,
	PROTANOPIA = 1,
	DEUTERANOPIA = 2,
	TRITANOPIA = 3,
}

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const TEXT_SCALE_MIN: float = 0.8
const TEXT_SCALE_MAX: float = 2.0
const TEXT_SCALE_DEFAULT: float = 1.0

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _colorblind_mode: int = ColorblindMode.NONE
var _text_scale: float = TEXT_SCALE_DEFAULT
var _high_contrast: bool = false
var _reduced_motion: bool = false
var _screen_reader_hints: Dictionary = {}

# ---------------------------------------------------------------------------
# Colorblind mode
# ---------------------------------------------------------------------------

func get_colorblind_mode() -> int:
	return _colorblind_mode


func set_colorblind_mode(mode: int) -> void:
	if mode < ColorblindMode.NONE or mode > ColorblindMode.TRITANOPIA:
		push_warning("AccessibilitySystem: invalid colorblind mode %d" % mode)
		return
	if _colorblind_mode == mode:
		return
	_colorblind_mode = mode
	settings_changed.emit()

# ---------------------------------------------------------------------------
# Text scale
# ---------------------------------------------------------------------------

func get_text_scale() -> float:
	return _text_scale


func set_text_scale(value: float) -> void:
	var clamped: float = clampf(value, TEXT_SCALE_MIN, TEXT_SCALE_MAX)
	if is_equal_approx(_text_scale, clamped):
		return
	_text_scale = clamped
	settings_changed.emit()

# ---------------------------------------------------------------------------
# High contrast
# ---------------------------------------------------------------------------

func is_high_contrast() -> bool:
	return _high_contrast


func set_high_contrast(enabled: bool) -> void:
	if _high_contrast == enabled:
		return
	_high_contrast = enabled
	settings_changed.emit()

# ---------------------------------------------------------------------------
# Reduced motion
# ---------------------------------------------------------------------------

func is_reduced_motion() -> bool:
	return _reduced_motion


func set_reduced_motion(enabled: bool) -> void:
	if _reduced_motion == enabled:
		return
	_reduced_motion = enabled
	settings_changed.emit()

# ---------------------------------------------------------------------------
# Screen reader hints
# ---------------------------------------------------------------------------

func set_hint(key: String, text: String) -> void:
	_screen_reader_hints[key] = text


func get_hint(key: String) -> String:
	if _screen_reader_hints.has(key):
		return _screen_reader_hints[key] as String
	return ""


func remove_hint(key: String) -> void:
	_screen_reader_hints.erase(key)


func get_all_hints() -> Dictionary:
	return _screen_reader_hints.duplicate()

# ---------------------------------------------------------------------------
# Color adjustment (simple channel-swap approximation)
# ---------------------------------------------------------------------------

func get_adjusted_color(base_color: Color, mode: int) -> Color:
	match mode:
		ColorblindMode.NONE:
			return base_color

		ColorblindMode.PROTANOPIA:
			# Reduce red perception — shift red towards green/blue
			var r: float = 0.56667 * base_color.g + 0.43333 * base_color.b
			var g: float = 0.55833 * base_color.g + 0.44167 * base_color.b
			var b: float = 0.24167 * base_color.g + 0.75833 * base_color.b
			return Color(r, g, b, base_color.a)

		ColorblindMode.DEUTERANOPIA:
			# Reduce green perception — shift green towards red/blue
			var r: float = 0.625 * base_color.r + 0.375 * base_color.b
			var g: float = 0.7 * base_color.r + 0.3 * base_color.b
			var b: float = 0.3 * base_color.r + 0.7 * base_color.b
			return Color(r, g, b, base_color.a)

		ColorblindMode.TRITANOPIA:
			# Reduce blue perception — shift blue towards red/green
			var r: float = 0.95 * base_color.r + 0.05 * base_color.g
			var g: float = 0.43333 * base_color.r + 0.56667 * base_color.g
			var b: float = 0.475 * base_color.r + 0.525 * base_color.g
			return Color(r, g, b, base_color.a)

		_:
			return base_color

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"colorblind_mode": _colorblind_mode,
		"text_scale": _text_scale,
		"high_contrast": _high_contrast,
		"reduced_motion": _reduced_motion,
		"screen_reader_hints": _screen_reader_hints.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	if data.has("colorblind_mode"):
		var mode: int = int(data["colorblind_mode"])
		if mode >= ColorblindMode.NONE and mode <= ColorblindMode.TRITANOPIA:
			_colorblind_mode = mode

	if data.has("text_scale"):
		_text_scale = clampf(float(data["text_scale"]), TEXT_SCALE_MIN, TEXT_SCALE_MAX)

	if data.has("high_contrast"):
		_high_contrast = bool(data["high_contrast"])

	if data.has("reduced_motion"):
		_reduced_motion = bool(data["reduced_motion"])

	if data.has("screen_reader_hints") and data["screen_reader_hints"] is Dictionary:
		_screen_reader_hints = (data["screen_reader_hints"] as Dictionary).duplicate()

	settings_changed.emit()

# ---------------------------------------------------------------------------
# Reset
# ---------------------------------------------------------------------------

func reset_to_defaults() -> void:
	_colorblind_mode = ColorblindMode.NONE
	_text_scale = TEXT_SCALE_DEFAULT
	_high_contrast = false
	_reduced_motion = false
	_screen_reader_hints.clear()
	settings_changed.emit()
