extends CanvasLayer

## MerlinBackdrop — Global background autoload (layer -100).
## Renders a deep CRT terminal black behind all scenes.

var background: ColorRect

func _ready() -> void:
	layer = -100
	background = ColorRect.new()
	background.name = "MerlinBackdrop"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = MerlinVisual.CRT_PALETTE.bg_deep
	add_child(background)
