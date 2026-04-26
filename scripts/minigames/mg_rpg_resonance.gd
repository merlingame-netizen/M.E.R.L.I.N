extends MiniGameBase
## RPG Resonance — Coeur test. Hold the cursor inside a slowly drifting target zone.
## A "lien" bar fills while the cursor is inside, drains while outside. Win at >= 75%.

const DURATION_S: float = 7.0
const ZONE_RADIUS: float = 38.0
const FILL_RATE: float = 0.22       # 0..1 per second when inside
const DRAIN_RATE: float = 0.10      # 0..1 per second when outside

var _zone_center: Vector2 = Vector2(160, 60)
var _link: float = 0.0
var _elapsed: float = 0.0
var _zone_label: Label
var _bar: ColorRect
var _bar_fill: ColorRect
var _hint_label: Label


func _on_start() -> void:
	_build()
	set_process(true)


func _build() -> void:
	if not _in_card_mode:
		_build_overlay()
	custom_minimum_size = Vector2(0, 130)
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Hint top
	_hint_label = Label.new()
	_hint_label.text = "Garde le curseur dans le cercle"
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(0.45, 0.30, 0.15))
	_hint_label.position = Vector2(10, 4)
	add_child(_hint_label)
	# Drifting zone visual (label "○")
	_zone_label = Label.new()
	_zone_label.text = "○"
	_zone_label.add_theme_font_size_override("font_size", 64)
	_zone_label.add_theme_color_override("font_color", Color(0.65, 0.13, 0.10, 0.9))
	_zone_label.size = Vector2(64, 64)
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_zone_label)
	# Link bar (track + fill)
	_bar = ColorRect.new()
	_bar.color = Color(0.45, 0.28, 0.12, 0.35)
	_bar.size = Vector2(0, 8)  # set in _process
	_bar.position = Vector2(0, 110)
	add_child(_bar)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.65, 0.13, 0.10)
	_bar_fill.size = Vector2(0, 8)
	_bar_fill.position = Vector2(0, 110)
	add_child(_bar_fill)


func _process(delta: float) -> void:
	if _finished or not _started:
		return
	_elapsed += delta
	# Drifting zone via Lissajous (slow, pleasing motion)
	var w: float = max(size.x, 320.0)
	var h: float = max(size.y, 100.0) - 30.0
	_zone_center.x = w * 0.5 + sin(_elapsed * 0.9) * (w * 0.32)
	_zone_center.y = 50.0 + cos(_elapsed * 0.65) * 22.0
	_zone_label.position = _zone_center - Vector2(32, 32)
	# Cursor distance check
	var mouse_pos: Vector2 = get_local_mouse_position()
	var inside: bool = mouse_pos.distance_to(_zone_center) <= ZONE_RADIUS
	if inside:
		_link = clampf(_link + FILL_RATE * delta, 0.0, 1.0)
		_zone_label.modulate.a = 1.0
	else:
		_link = clampf(_link - DRAIN_RATE * delta, 0.0, 1.0)
		_zone_label.modulate.a = 0.55
	# Update bars
	_bar.size = Vector2(w, 8)
	_bar_fill.size = Vector2(w * _link, 8)
	# End check
	if _elapsed >= DURATION_S:
		_finalize()


func _finalize() -> void:
	var score: int = int(round(_link * 100.0))
	var success: bool = _link >= 0.75
	_complete(success, score)
