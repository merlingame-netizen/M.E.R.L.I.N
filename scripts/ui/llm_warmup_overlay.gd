## ═══════════════════════════════════════════════════════════════════════════════
## LLM Warm-up Overlay — Animated loading screen during brain initialization
## ═══════════════════════════════════════════════════════════════════════════════
## Shows a parchment overlay with progress bar while MerlinAI loads models.
## Connects to MerlinAI.status_changed for progress and ready_changed for dismissal.
## Auto-fades and frees itself once ready.
## ═══════════════════════════════════════════════════════════════════════════════

extends CanvasLayer

const WARMUP_MESSAGES := [
	"Les cerveaux de M.E.R.L.I.N. s'eveillent...",
	"Les runes s'illuminent...",
	"La brume se dissipe...",
	"Les esprits se rassemblent...",
]

@onready var _container: Control = $Container
@onready var _bg: ColorRect = $Container/BG
@onready var _spinner_label: Label = $Container/SpinnerLabel
@onready var _title_label: Label = $Container/TitleLabel
@onready var _detail_label: Label = $Container/DetailLabel
@onready var _progress_bar: ColorRect = $Container/ProgressBar
@onready var _progress_fill: ColorRect = $Container/ProgressBar/ProgressFill
var _merlin_ai: Node
var _spinner_angle: float = 0.0
var _dismissed: bool = false

const SPINNER_CHARS := ["\u25d0", "\u25d3", "\u25d1", "\u25d2"]


func _ready() -> void:
	_merlin_ai = Engine.get_singleton("MerlinAI") if Engine.has_singleton("MerlinAI") else null
	if _merlin_ai == null:
		var root := get_tree().root if get_tree() else null
		if root:
			_merlin_ai = root.get_node_or_null("MerlinAI")

	_configure_ui()
	_connect_signals()

	# If already ready, dismiss immediately
	if _merlin_ai and _merlin_ai.is_ready:
		_dismiss()


func _configure_ui() -> void:
	# Runtime color overrides (depend on MerlinVisual palette)
	_bg.color = Color(MerlinVisual.CRT_PALETTE.bg_panel.r, MerlinVisual.CRT_PALETTE.bg_panel.g, MerlinVisual.CRT_PALETTE.bg_panel.b, 0.94)
	_title_label.text = WARMUP_MESSAGES[randi() % WARMUP_MESSAGES.size()]
	_title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	_spinner_label.text = SPINNER_CHARS[0]
	_spinner_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	_detail_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	_progress_bar.color = MerlinVisual.CRT_PALETTE.bg_panel
	_progress_fill.color = MerlinVisual.CRT_PALETTE.amber

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
