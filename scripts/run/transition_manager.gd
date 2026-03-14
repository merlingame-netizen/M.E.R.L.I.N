## ═══════════════════════════════════════════════════════════════════════════════
## Transition Manager — Fade transitions between 3D walk, card, and minigame
## ═══════════════════════════════════════════════════════════════════════════════
## Phase 6 (DEV_PLAN_V2.5). Manages screen fades and input locking
## during transitions: 3D → card → minigame → 3D.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name TransitionManager

signal fade_started(target: String)
signal fade_completed(target: String)
signal inputs_disabled()
signal inputs_enabled()

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

const DEFAULT_FADE_DURATION: float = 1.0
const FADE_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _fade_overlay: ColorRect = null
var _is_fading: bool = false
var _inputs_locked: bool = false
var _current_tween: Tween = null


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP — Call after adding to scene tree
# ═══════════════════════════════════════════════════════════════════════════════

func setup_overlay(parent: Control) -> void:
	if _fade_overlay != null:
		return
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_fade_overlay.z_index = 100
	parent.add_child(_fade_overlay)


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — Fade transitions
# ═══════════════════════════════════════════════════════════════════════════════

func fade_to_card(duration: float = DEFAULT_FADE_DURATION) -> void:
	await _fade_out_in("card", duration)


func fade_to_3d(duration: float = DEFAULT_FADE_DURATION) -> void:
	await _fade_out_in("3d", duration)


func fade_to_minigame(duration: float = DEFAULT_FADE_DURATION) -> void:
	await _fade_out_in("minigame", duration)


func disable_inputs() -> void:
	if _inputs_locked:
		return
	_inputs_locked = true
	if _fade_overlay:
		_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	inputs_disabled.emit()


func enable_inputs() -> void:
	if not _inputs_locked:
		return
	_inputs_locked = false
	if _fade_overlay:
		_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inputs_enabled.emit()


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL — Fade mechanics
# ═══════════════════════════════════════════════════════════════════════════════

func _fade_out_in(target: String, duration: float) -> void:
	if _is_fading:
		return
	_is_fading = true
	disable_inputs()
	fade_started.emit(target)

	var half: float = duration * 0.5

	# Fade out (to black)
	await _animate_alpha(1.0, half)

	# Mid-point: scene switch happens here (caller awaits this)
	fade_completed.emit(target)

	# Fade in (from black)
	await _animate_alpha(0.0, half)

	enable_inputs()
	_is_fading = false


func _animate_alpha(target_alpha: float, duration: float) -> void:
	if _fade_overlay == null:
		return
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_current_tween = create_tween()
	_current_tween.tween_property(_fade_overlay, "color:a", target_alpha, duration)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_CUBIC)
	await _current_tween.finished


# ═══════════════════════════════════════════════════════════════════════════════
# QUERIES
# ═══════════════════════════════════════════════════════════════════════════════

func is_fading() -> bool:
	return _is_fading


func are_inputs_locked() -> bool:
	return _inputs_locked
