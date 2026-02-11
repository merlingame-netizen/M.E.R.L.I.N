## ═══════════════════════════════════════════════════════════════════════════════
## LLM Warm-up Overlay — Animated loading screen during brain initialization
## ═══════════════════════════════════════════════════════════════════════════════
## Shows a parchment overlay with progress bar while MerlinAI loads models.
## Connects to MerlinAI.status_changed for progress and ready_changed for dismissal.
## Auto-fades and frees itself once ready.
## ═══════════════════════════════════════════════════════════════════════════════

extends CanvasLayer

const PALETTE := {
	"paper": Color(0.965, 0.945, 0.905),
	"ink": Color(0.22, 0.18, 0.14),
	"ink_soft": Color(0.38, 0.32, 0.26),
	"accent": Color(0.58, 0.44, 0.26),
	"accent_soft": Color(0.65, 0.52, 0.34),
	"bar_bg": Color(0.90, 0.88, 0.84),
}

const WARMUP_MESSAGES := [
	"Les cerveaux de M.E.R.L.I.N. s'eveillent...",
	"Les runes s'illuminent...",
	"La brume se dissipe...",
	"Les esprits se rassemblent...",
]

var _bg: ColorRect
var _title_label: Label
var _detail_label: Label
var _progress_bar: ColorRect
var _progress_fill: ColorRect
var _spinner_label: Label
var _container: Control
var _merlin_ai: Node
var _spinner_angle: float = 0.0
var _dismissed: bool = false

const SPINNER_CHARS := ["◐", "◓", "◑", "◒"]


func _ready() -> void:
	layer = 100
	_merlin_ai = Engine.get_singleton("MerlinAI") if Engine.has_singleton("MerlinAI") else null
	if _merlin_ai == null:
		var root := get_tree().root if get_tree() else null
		if root:
			_merlin_ai = root.get_node_or_null("MerlinAI")

	_build_ui()
	_connect_signals()

	# If already ready, dismiss immediately
	if _merlin_ai and _merlin_ai.is_ready:
		_dismiss()


func _build_ui() -> void:
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_container)

	# Semi-opaque parchment background
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(PALETTE.paper.r, PALETTE.paper.g, PALETTE.paper.b, 0.94)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(_bg)

	# Title
	_title_label = Label.new()
	_title_label.text = WARMUP_MESSAGES[randi() % WARMUP_MESSAGES.size()]
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", PALETTE.ink)
	_container.add_child(_title_label)

	# Spinner
	_spinner_label = Label.new()
	_spinner_label.text = SPINNER_CHARS[0]
	_spinner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spinner_label.add_theme_font_size_override("font_size", 32)
	_spinner_label.add_theme_color_override("font_color", PALETTE.accent)
	_container.add_child(_spinner_label)

	# Detail (brain being loaded)
	_detail_label = Label.new()
	_detail_label.text = "Preparation..."
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.add_theme_font_size_override("font_size", 14)
	_detail_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	_container.add_child(_detail_label)

	# Progress bar background
	_progress_bar = ColorRect.new()
	_progress_bar.color = PALETTE.bar_bg
	_container.add_child(_progress_bar)

	# Progress bar fill
	_progress_fill = ColorRect.new()
	_progress_fill.color = PALETTE.accent
	_progress_bar.add_child(_progress_fill)

	_layout()
	_container.resized.connect(_layout)


func _layout() -> void:
	var vp := _container.size
	if vp == Vector2.ZERO:
		vp = Vector2(1152, 648)

	var cx := vp.x * 0.5
	var cy := vp.y * 0.5

	# Spinner above title
	_spinner_label.size = Vector2(60, 40)
	_spinner_label.position = Vector2(cx - 30, cy - 60)

	# Title centered
	_title_label.size = Vector2(vp.x * 0.8, 30)
	_title_label.position = Vector2(vp.x * 0.1, cy - 15)

	# Detail below title
	_detail_label.size = Vector2(vp.x * 0.8, 24)
	_detail_label.position = Vector2(vp.x * 0.1, cy + 20)

	# Progress bar below detail
	var bar_w := minf(400.0, vp.x * 0.6)
	var bar_h := 6.0
	_progress_bar.size = Vector2(bar_w, bar_h)
	_progress_bar.position = Vector2(cx - bar_w * 0.5, cy + 55)
	_progress_fill.size = Vector2(0, bar_h)
	_progress_fill.position = Vector2.ZERO


func _connect_signals() -> void:
	if _merlin_ai == null:
		return
	if _merlin_ai.has_signal("status_changed"):
		_merlin_ai.status_changed.connect(_on_status_changed)
	if _merlin_ai.has_signal("ready_changed"):
		_merlin_ai.ready_changed.connect(_on_ready_changed)


func _on_status_changed(status_text: String, detail_text: String, progress: float) -> void:
	if _detail_label:
		_detail_label.text = detail_text
	if _progress_fill and _progress_bar:
		var fill_w: float = _progress_bar.size.x * clampf(progress / 100.0, 0.0, 1.0)
		var tw := create_tween()
		tw.tween_property(_progress_fill, "size:x", fill_w, 0.3).set_trans(Tween.TRANS_SINE)


func _on_ready_changed(ready: bool) -> void:
	if ready:
		_dismiss()


func _process(delta: float) -> void:
	if _dismissed:
		return
	_spinner_angle += delta * 4.0
	var idx := int(_spinner_angle) % SPINNER_CHARS.size()
	if _spinner_label:
		_spinner_label.text = SPINNER_CHARS[idx]


func _dismiss() -> void:
	if _dismissed:
		return
	_dismissed = true
	set_process(false)

	# Disconnect signals
	if _merlin_ai:
		if _merlin_ai.has_signal("status_changed") and _merlin_ai.status_changed.is_connected(_on_status_changed):
			_merlin_ai.status_changed.disconnect(_on_status_changed)
		if _merlin_ai.has_signal("ready_changed") and _merlin_ai.ready_changed.is_connected(_on_ready_changed):
			_merlin_ai.ready_changed.disconnect(_on_ready_changed)

	# Fill progress to 100%
	if _progress_fill and _progress_bar:
		_progress_fill.size.x = _progress_bar.size.x
	if _detail_label:
		_detail_label.text = "M.E.R.L.I.N. est pret."

	# Fade out
	if not is_inside_tree():
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(_container, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(queue_free)
