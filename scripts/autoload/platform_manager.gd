## PlatformManager — Cross-Platform Adaptation (Autoload Singleton)
## Detects platform and adjusts rendering quality, UI scaling, safe areas.
extends Node

signal platform_detected(platform: String)
signal quality_changed(level: String)

enum Platform { PC, MOBILE, WEB, CONSOLE }
enum QualityLevel { LOW, MEDIUM, HIGH }

var current_platform: Platform = Platform.PC
var quality: QualityLevel = QualityLevel.HIGH
var safe_area_margins: Dictionary = { "top": 0, "bottom": 0, "left": 0, "right": 0 }

## Platform feature flags
var has_touch: bool = false
var has_keyboard: bool = true
var has_gamepad: bool = false
var has_mouse: bool = true
var is_mobile: bool = false


func _ready() -> void:
	_detect_platform()
	_apply_quality_preset()
	_detect_safe_area()


## Get the platform name as a string.
func get_platform_name() -> String:
	match current_platform:
		Platform.PC:
			return "pc"
		Platform.MOBILE:
			return "mobile"
		Platform.WEB:
			return "web"
		Platform.CONSOLE:
			return "console"
	return "pc"


## Set quality level manually (for settings menu).
func set_quality(level: QualityLevel) -> void:
	quality = level
	_apply_quality_settings(level)
	quality_changed.emit(_quality_to_string(level))


## Get recommended font size based on platform.
func get_base_font_size() -> int:
	if is_mobile:
		return 18  # Larger for touch screens
	return 14  # Desktop default


## Get recommended UI scale factor.
func get_ui_scale() -> float:
	if is_mobile:
		var screen_size: Vector2 = DisplayServer.screen_get_size()
		var dpi: int = DisplayServer.screen_get_dpi()
		if dpi > 300:
			return 1.5  # High DPI phone
		if screen_size.x < 800:
			return 1.2  # Small phone
		return 1.0
	return 1.0


func _detect_platform() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		current_platform = Platform.MOBILE
		is_mobile = true
		has_touch = true
		has_keyboard = false
		has_mouse = false
	elif OS.has_feature("web"):
		current_platform = Platform.WEB
		# Web could be mobile browser — check viewport
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		if vp_size.x < 800:
			is_mobile = true
			has_touch = true
	else:
		current_platform = Platform.PC
		has_keyboard = true
		has_mouse = true

	has_gamepad = Input.get_connected_joypads().size() > 0
	platform_detected.emit(get_platform_name())


func _apply_quality_preset() -> void:
	if is_mobile:
		set_quality(QualityLevel.LOW)
	elif current_platform == Platform.WEB:
		set_quality(QualityLevel.MEDIUM)
	else:
		set_quality(QualityLevel.HIGH)


func _apply_quality_settings(level: QualityLevel) -> void:
	var vp: Viewport = get_viewport()
	match level:
		QualityLevel.LOW:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		QualityLevel.MEDIUM:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		QualityLevel.HIGH:
			vp.msaa_3d = Viewport.MSAA_4X
			# FXAA is unavailable on the Compatibility renderer (no RenderingDevice).
			# This runtime check is robust against project setting overrides and HW fallbacks.
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if RenderingServer.get_rendering_device() != null else Viewport.SCREEN_SPACE_AA_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(4096, true)


func _detect_safe_area() -> void:
	if not is_mobile:
		return
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	safe_area_margins = {
		"top": safe_rect.position.y,
		"bottom": maxi(0, screen_size.y - safe_rect.position.y - safe_rect.size.y),
		"left": safe_rect.position.x,
		"right": maxi(0, screen_size.x - safe_rect.position.x - safe_rect.size.x),
	}


func _quality_to_string(level: QualityLevel) -> String:
	match level:
		QualityLevel.LOW:
			return "low"
		QualityLevel.MEDIUM:
			return "medium"
		QualityLevel.HIGH:
			return "high"
	return "medium"
