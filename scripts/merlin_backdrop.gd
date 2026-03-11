extends CanvasLayer

## MerlinBackdrop — Global background autoload (layer -100).
## Renders a deep CRT terminal black behind all scenes.
## Supports optional animated pixel art biome backdrop (PixelBiomeBackdrop).

const _PixelBiomeBackdropScene := preload("res://scripts/ui/pixel_biome_backdrop.gd")

var background: ColorRect
var _pixel_backdrop: Control = null
var _backdrop_active: bool = false


func _ready() -> void:
	layer = -100
	# Container Control fills viewport (needed: direct CanvasLayer children
	# don't resolve FULL_RECT anchors correctly in GL Compatibility mode)
	var container := Control.new()
	container.name = "BackdropContainer"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	# CRT black fallback (always present underneath)
	background = ColorRect.new()
	background.name = "MerlinBackdrop"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = MerlinVisual.CRT_PALETTE.bg_deep
	container.add_child(background)

	# Pixel biome backdrop (initially hidden, activated via set_biome)
	_pixel_backdrop = _PixelBiomeBackdropScene.new()
	_pixel_backdrop.name = "PixelBiomeBackdrop"
	_pixel_backdrop.visible = false
	container.add_child(_pixel_backdrop)


## Activate biome backdrop with the given biome key.
## Pass "" or an invalid key to deactivate and return to CRT black.
func set_biome(biome_key: String) -> void:
	if biome_key.is_empty():
		_deactivate_backdrop()
		return
	if not MerlinVisual.BIOME_ART_PROFILES.has(biome_key):
		push_warning("MerlinBackdrop: unknown biome '%s', falling back to CRT black" % biome_key)
		_deactivate_backdrop()
		return
	_pixel_backdrop.set_biome(biome_key)
	_pixel_backdrop.visible = true
	_backdrop_active = true


## Set weather effect on the biome backdrop: "clear", "rain", "fog", "snow".
func set_weather(weather: String) -> void:
	if _pixel_backdrop != null:
		_pixel_backdrop.set_weather(weather)


## Deactivate biome backdrop, show only CRT black.
func clear_biome() -> void:
	_deactivate_backdrop()


func _deactivate_backdrop() -> void:
	if _pixel_backdrop != null:
		_pixel_backdrop.visible = false
	_backdrop_active = false
