class_name HubTriadeHud
extends Control

## Triade Aspect HUD for HubAntre — Shows Corps/Ame/Monde state
## Procedural CRT-style indicators with animated state labels

signal aspect_hovered(aspect_name: String)

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const ASPECT_SYMBOLS := {
	"Corps": "|",   # Spirale → bar (terminal glyph)
	"Ame": "~",     # Triskell → wave
	"Monde": "+",   # Croix celtique → cross
}

const ASPECT_ANIMAL_KEYS := {
	"Corps": "ANIMAL_BOAR",
	"Ame": "ANIMAL_RAVEN",
	"Monde": "ANIMAL_STAG",
}

const HUD_HEIGHT := 48.0
const BAR_WIDTH := 60.0
const BAR_HEIGHT := 6.0
const INDICATOR_SPACING := 12.0
const BREATHE_SPEED := 2.2

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _aspects: Dictionary = {"Corps": 50, "Ame": 50, "Monde": 50}
var _hovered_aspect: String = ""
var _breathe_t: float = 0.0
var _target_values: Dictionary = {"Corps": 50, "Ame": 50, "Monde": 50}
var _display_values: Dictionary = {"Corps": 50.0, "Ame": 50.0, "Monde": 50.0}

func _init() -> void:
	custom_minimum_size = Vector2(0, HUD_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _process(delta: float) -> void:
	_breathe_t += delta * BREATHE_SPEED
	# Lerp display values toward targets
	for aspect_name: String in _display_values:
		var target: float = float(_target_values.get(aspect_name, 50))
		_display_values[aspect_name] = lerpf(_display_values[aspect_name], target, delta * 4.0)
	queue_redraw()

func update_aspects(aspects: Dictionary) -> void:
	for aspect_name: String in ["Corps", "Ame", "Monde"]:
		var val: int = int(aspects.get(aspect_name, 50))
		_target_values[aspect_name] = val
		_aspects[aspect_name] = val

func _draw() -> void:
	var font: Font = MerlinVisual.get_font("body")
	if font == null:
		return
	var vp_w: float = size.x
	var total_w: float = 3.0 * (BAR_WIDTH + 80.0) + 2.0 * INDICATOR_SPACING
	var start_x: float = (vp_w - total_w) * 0.5
	var y_center: float = HUD_HEIGHT * 0.5

	for i in 3:
		var aspect_name: String = MerlinConstants.TRIADE_ASPECTS[i]
		var x: float = start_x + float(i) * (BAR_WIDTH + 80.0 + INDICATOR_SPACING)
		_draw_aspect_indicator(font, aspect_name, Vector2(x, y_center), i)


func _draw_aspect_indicator(font: Font, aspect_name: String, pos: Vector2, index: int) -> void:
	var c_aspect: Color = MerlinVisual.CRT_ASPECT_COLORS[aspect_name]
	var c_dim: Color = MerlinVisual.CRT_ASPECT_COLORS_DARK[aspect_name]
	var value: float = _display_values.get(aspect_name, 50.0)
	var state: int = _get_aspect_state(int(value))
	var state_label: String = _get_state_label(aspect_name, state)
	var symbol: String = ASPECT_SYMBOLS[aspect_name]

	# Breathing glow for the active indicator
	var breath: float = sin(_breathe_t + float(index) * 1.2) * 0.12 + 0.88
	var c_glow: Color = Color(c_aspect.r, c_aspect.g, c_aspect.b, 0.08 * breath)

	# Background glow
	draw_rect(Rect2(pos.x - 4.0, pos.y - 18.0, BAR_WIDTH + 88.0, 36.0), c_glow)

	# Symbol
	var symbol_color: Color = Color(c_aspect.r, c_aspect.g, c_aspect.b, breath)
	draw_string(font, Vector2(pos.x, pos.y + 5.0), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, MerlinVisual.BODY_SMALL, symbol_color)

	# Aspect name (translated)
	var name_x: float = pos.x + 14.0
	var info: Dictionary = MerlinConstants.TRIADE_ASPECT_INFO.get(aspect_name, {})
	var display_name: String = tr(str(info.get("name_key", aspect_name)))
	draw_string(font, Vector2(name_x, pos.y - 4.0), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, MerlinVisual.CAPTION_SIZE, c_aspect)

	# Bar background
	var bar_x: float = name_x + 50.0
	var bar_y: float = pos.y - BAR_HEIGHT * 0.5
	draw_rect(Rect2(bar_x, bar_y, BAR_WIDTH, BAR_HEIGHT), MerlinVisual.CRT_PALETTE["bg_deep"])
	draw_rect(Rect2(bar_x, bar_y, BAR_WIDTH, BAR_HEIGHT), MerlinVisual.CRT_PALETTE["border"], false, 1.0)

	# Bar fill
	var fill_pct: float = clampf(value / 100.0, 0.0, 1.0)
	var fill_w: float = BAR_WIDTH * fill_pct
	var fill_color: Color
	if state == -1:
		fill_color = MerlinVisual.CRT_PALETTE["danger"]
	elif state == 1:
		fill_color = MerlinVisual.CRT_PALETTE["warning"]
	else:
		fill_color = c_aspect
	draw_rect(Rect2(bar_x, bar_y, fill_w, BAR_HEIGHT), fill_color)

	# State label
	var label_x: float = bar_x + BAR_WIDTH + 6.0
	var label_color: Color
	if state == 0:
		label_color = MerlinVisual.CRT_PALETTE["phosphor_dim"]
	else:
		label_color = Color(fill_color.r, fill_color.g, fill_color.b, 0.85)
	draw_string(font, Vector2(label_x, pos.y + 5.0), state_label, HORIZONTAL_ALIGNMENT_LEFT, -1, MerlinVisual.CAPTION_SIZE, label_color)


func _get_aspect_state(value: int) -> int:
	if value <= 20:
		return -1  # BAS
	elif value >= 80:
		return 1  # HAUT
	return 0  # EQUILIBRE


func _get_state_label(aspect_name: String, state: int) -> String:
	var info: Dictionary = MerlinConstants.TRIADE_ASPECT_INFO.get(aspect_name, {})
	var states: Dictionary = info.get("states", {})
	var key: String = str(states.get(state, "???"))
	return tr(key)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Detect which aspect is hovered based on x position
		var vp_w: float = size.x
		var total_w: float = 3.0 * (BAR_WIDTH + 80.0) + 2.0 * INDICATOR_SPACING
		var start_x: float = (vp_w - total_w) * 0.5
		var mx: float = event.position.x
		for i in 3:
			var x: float = start_x + float(i) * (BAR_WIDTH + 80.0 + INDICATOR_SPACING)
			if mx >= x and mx < x + BAR_WIDTH + 88.0:
				var aspect_name: String = MerlinConstants.TRIADE_ASPECTS[i]
				if aspect_name != _hovered_aspect:
					_hovered_aspect = aspect_name
					aspect_hovered.emit(aspect_name)
				return
		_hovered_aspect = ""
