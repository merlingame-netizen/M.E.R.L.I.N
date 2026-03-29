extends CanvasLayer
## BookCinematic — Double scroll intro (ported from Three.js book_cinematic.js v10)
## LEFT scroll: intro narrative text (quill writes)
## RIGHT scroll: abstract map with glowing dots + organic trail
## Events drive the map. NO timers — player clicks to advance.

class_name BookCinematic

signal cinematic_complete

enum State { SCROLL_APPEAR, SCROLL_UNROLL, WRITE_STORY, WAIT_ENTER, DIVE, DONE }

# --- Config ---
const CHARS_PER_SECOND: float = 55.0  # Faster text for better pacing
const TRAIL_SPEED: float = 0.4
const FALLBACK_INTRO: String = "Les brumes de Broceliande se levent lentement, devoilant les racines noueuses des chenes millenaires. Au loin, une lueur ambre pulse — le Nemeton, coeur sacre de la foret. Les korrigans ont laisse des traces dans la rosee. Le sentier s'ouvre devant toi, etroit et sinueux. Merlin murmure dans le vent: 'Les signes te guideront, mais chaque choix porte son ombre.' Des champignons phosphorescents dessinent un chemin entre les pierres dressees. La foret attend."

# --- State ---
var _state: State = State.SCROLL_APPEAR
var _t: float = 0.0
var _char_index: float = 0.0
var _trail_progress: float = 0.0
var _intro_text: String = ""
var _title: String = "Broceliande"
var _dots: Array[Vector2] = []
var _branches: Array[Dictionary] = []

# --- UI refs ---
var _bg: ColorRect
var _left_panel: PanelContainer
var _right_panel: PanelContainer
var _text_label: RichTextLabel
var _enter_btn: Button
var _skip_btn: Button
var _map_canvas: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_build_organic_path(10)
	_state = State.SCROLL_APPEAR
	_t = 0.0


func set_intro(title: String, text: String) -> void:
	_title = title if not title.is_empty() else "Broceliande"
	_intro_text = text if not text.is_empty() else FALLBACK_INTRO


func _process(delta: float) -> void:
	if _state == State.DONE:
		return
	_t += delta

	match _state:
		State.SCROLL_APPEAR:
			# Fade in (1.5s)
			var alpha: float = clampf(_t / 0.8, 0.0, 1.0)
			_bg.color.a = alpha * 0.92
			_left_panel.modulate.a = alpha
			_right_panel.modulate.a = alpha
			if _t >= 0.8:
				_state = State.SCROLL_UNROLL; _t = 0.0
				SFXManager.play("card_draw") if is_instance_valid(SFXManager) else null

		State.SCROLL_UNROLL:
			# Grow panels (1s)
			var e: float = clampf(_t / 0.6, 0.0, 1.0)
			# Panels expand via anchor
			_left_panel.anchor_bottom = 0.08 + e * 0.82
			_right_panel.anchor_bottom = 0.08 + e * 0.82
			if _t >= 0.6:
				_state = State.WRITE_STORY; _t = 0.0; _char_index = 0.0
				SFXManager.play("card_reveal") if is_instance_valid(SFXManager) else null

		State.WRITE_STORY:
			var text: String = _intro_text if not _intro_text.is_empty() else FALLBACK_INTRO
			_char_index = minf(_char_index + delta * CHARS_PER_SECOND, float(text.length()))
			_text_label.visible_characters = int(_char_index)

			# Trail syncs with text progress
			var text_progress: float = _char_index / maxf(float(text.length()), 1.0)
			_trail_progress = minf(text_progress, 1.0)
			_map_canvas.queue_redraw()

			# Show enter button when text done
			if _char_index >= float(text.length()) - 1.0:
				_enter_btn.visible = true

		State.WAIT_ENTER:
			pass  # Button handles

		State.DIVE:
			# Fade out (1.5s)
			var fade: float = clampf(_t / 0.8, 0.0, 1.0)
			_bg.color.a = (1.0 - fade) * 0.92
			_left_panel.modulate.a = 1.0 - fade
			_right_panel.modulate.a = 1.0 - fade
			_enter_btn.modulate.a = 1.0 - fade
			if _t >= 0.8:
				_state = State.DONE
				cinematic_complete.emit()
				queue_free()


func skip() -> void:
	_state = State.DONE
	cinematic_complete.emit()
	queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Dark background
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.03, 0.04, 0.03, 0.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	var font: Font = MerlinVisual.get_font("terminal") if is_instance_valid(MerlinVisual) else null

	# ── LEFT SCROLL (intro text) ──────────────────────────────────────────
	_left_panel = PanelContainer.new()
	_left_panel.anchor_left = 0.03; _left_panel.anchor_right = 0.48
	_left_panel.anchor_top = 0.08; _left_panel.anchor_bottom = 0.08  # grows via unroll
	_left_panel.modulate.a = 0.0
	var left_style: StyleBoxFlat = StyleBoxFlat.new()
	left_style.bg_color = Color(0.93, 0.90, 0.82)  # Parchment
	left_style.border_color = Color(0.7, 0.6, 0.4)
	left_style.set_border_width_all(2)
	left_style.set_corner_radius_all(4)
	left_style.set_content_margin_all(20)
	_left_panel.add_theme_stylebox_override("panel", left_style)
	add_child(_left_panel)

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_left_panel.add_child(left_vbox)

	# Title
	var title_lbl: Label = Label.new()
	title_lbl.text = _title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font: title_lbl.add_theme_font_override("font", font)
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(0.15, 0.08, 0.02))
	left_vbox.add_child(title_lbl)

	# Separator
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	left_vbox.add_child(sep)

	# Text body
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.scroll_active = true
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.visible_characters = 0
	_text_label.text = _intro_text if not _intro_text.is_empty() else FALLBACK_INTRO
	if font: _text_label.add_theme_font_override("normal_font", font)
	_text_label.add_theme_font_size_override("normal_font_size", 16)
	_text_label.add_theme_color_override("default_color", Color(0.12, 0.08, 0.03))
	left_vbox.add_child(_text_label)

	# ── RIGHT SCROLL (map) ────────────────────────────────────────────────
	_right_panel = PanelContainer.new()
	_right_panel.anchor_left = 0.52; _right_panel.anchor_right = 0.97
	_right_panel.anchor_top = 0.08; _right_panel.anchor_bottom = 0.08
	_right_panel.modulate.a = 0.0
	var right_style: StyleBoxFlat = left_style.duplicate()
	right_style.bg_color = Color(0.91, 0.88, 0.80)
	_right_panel.add_theme_stylebox_override("panel", right_style)
	add_child(_right_panel)

	# Map canvas (custom draw)
	_map_canvas = Control.new()
	_map_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_canvas.draw.connect(_draw_map)
	_right_panel.add_child(_map_canvas)

	# ── BUTTONS ───────────────────────────────────────────────────────────
	_enter_btn = Button.new()
	_enter_btn.text = "Entrer dans la foret  \u25B6"
	_enter_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_enter_btn.offset_top = -60; _enter_btn.offset_bottom = -20
	_enter_btn.offset_left = -120; _enter_btn.offset_right = 120
	if font: _enter_btn.add_theme_font_override("font", font)
	_enter_btn.add_theme_font_size_override("font_size", 18)
	_enter_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.02, 0.04, 0.02, 0.9)
	btn_style.border_color = Color(0.2, 1.0, 0.4, 0.5)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(10)
	_enter_btn.add_theme_stylebox_override("normal", btn_style)
	_enter_btn.visible = false
	_enter_btn.pressed.connect(func():
		_enter_btn.visible = false
		_state = State.DIVE; _t = 0.0
		if is_instance_valid(SFXManager): SFXManager.play("confirm")
	)
	add_child(_enter_btn)

	_skip_btn = Button.new()
	_skip_btn.text = "Passer \u25B6\u25B6"
	_skip_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_btn.offset_top = -44; _skip_btn.offset_bottom = -8
	_skip_btn.offset_left = -110; _skip_btn.offset_right = -8
	if font: _skip_btn.add_theme_font_override("font", font)
	_skip_btn.add_theme_font_size_override("font_size", 15)
	_skip_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	var skip_style: StyleBoxFlat = StyleBoxFlat.new()
	skip_style.bg_color = Color(0, 0, 0, 0.3)
	skip_style.set_corner_radius_all(4)
	_skip_btn.add_theme_stylebox_override("normal", skip_style)
	_skip_btn.pressed.connect(skip)
	add_child(_skip_btn)


# ═══════════════════════════════════════════════════════════════════════════════
# MAP DRAWING
# ═══════════════════════════════════════════════════════════════════════════════

func _build_organic_path(count: int) -> void:
	_dots.clear()
	_branches.clear()
	var cx: float = 0.45 + randf() * 0.1
	var cy: float = 0.88
	var prev_angle: float = -PI / 2.0

	for i in count:
		_dots.append(Vector2(cx, cy))
		var side_force: float = sin(float(i) * 1.1) * 0.6
		var jitter: float = (randf() - 0.5) * 1.4 + side_force
		prev_angle = prev_angle * 0.5 + (-PI / 2.0 + jitter) * 0.5
		var step: float = (0.62 / float(count)) + (randf() - 0.5) * 0.03
		cx = clampf(cx + cos(prev_angle) * step * 1.0, 0.1, 0.9)
		cy = clampf(minf(cy - 0.008, cy + sin(prev_angle) * step * 1.1), 0.06, cy)

		# Fork branches
		if i > 0 and i % 3 == 1 and randf() > 0.3:
			var bside: float = 1.0 if i % 2 == 0 else -1.0
			var bx: float = clampf(cx + bside * (0.06 + randf() * 0.08), 0.08, 0.92)
			var by: float = cy + (randf() - 0.5) * 0.04
			_branches.append({"from": i, "x": bx, "y": by})


func _draw_map() -> void:
	var canvas: Control = _map_canvas
	var sz: Vector2 = canvas.size
	if sz.x < 10.0 or sz.y < 10.0:
		return
	var margin: float = sz.x * 0.08

	# Title
	var font: Font = MerlinVisual.get_font("terminal") if is_instance_valid(MerlinVisual) else ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(sz.x / 2.0 - 60.0, 20.0), "Carte de la Quete", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.25, 0.18, 0.08))

	# Trail segments
	var total_segs: int = _dots.size() - 1
	var segs_to_show: int = int(_trail_progress * float(total_segs))

	for i in mini(segs_to_show, total_segs):
		var d0: Vector2 = _dots[i]
		var d1: Vector2 = _dots[i + 1]
		var p0: Vector2 = Vector2(margin + d0.x * (sz.x - margin * 2.0), 30.0 + d0.y * (sz.y - 50.0))
		var p1: Vector2 = Vector2(margin + d1.x * (sz.x - margin * 2.0), 30.0 + d1.y * (sz.y - 50.0))
		# Organic curve offset
		var mid: Vector2 = (p0 + p1) / 2.0
		var perp: Vector2 = Vector2(-(p1.y - p0.y), p1.x - p0.x).normalized()
		var offset: float = (10.0 + float(i % 3) * 5.0) * (1.0 if i % 2 == 0 else -1.0)
		# Draw as 3-segment polyline approximating a curve
		var cp: Vector2 = mid + perp * offset
		canvas.draw_line(p0, cp, Color(0.35, 0.28, 0.12), 2.0)
		canvas.draw_line(cp, p1, Color(0.35, 0.28, 0.12), 2.0)

	# Dots
	for i in _dots.size():
		var d: Vector2 = _dots[i]
		var px: float = margin + d.x * (sz.x - margin * 2.0)
		var py: float = 30.0 + d.y * (sz.y - 50.0)
		var reached: bool = i <= segs_to_show

		if reached:
			# Glowing dot
			var pulse: float = 0.7 + 0.3 * sin(_t * 3.0 + float(i) * 0.8)
			canvas.draw_circle(Vector2(px, py), 10.0, Color(1.0, 0.75, 0.25, 0.08 * pulse))
			canvas.draw_circle(Vector2(px, py), 6.0, Color(1.0, 0.8, 0.3, 0.15 * pulse))
			var core_color: Color = Color(0.8, 0.15, 0.1) if i == 0 else Color(1.0, 0.75, 0.25, 0.6 + 0.3 * pulse)
			canvas.draw_circle(Vector2(px, py), 3.5, core_color)
		else:
			canvas.draw_circle(Vector2(px, py), 2.5, Color(0.4, 0.3, 0.2, 0.15))

	# Branch forks
	for br in _branches:
		var from_idx: int = int(br["from"])
		if from_idx > segs_to_show or from_idx >= _dots.size():
			continue
		var fd: Vector2 = _dots[from_idx]
		var fp: Vector2 = Vector2(margin + fd.x * (sz.x - margin * 2.0), 30.0 + fd.y * (sz.y - 50.0))
		var bp: Vector2 = Vector2(margin + float(br["x"]) * (sz.x - margin * 2.0), 30.0 + float(br["y"]) * (sz.y - 50.0))
		canvas.draw_dashed_line(fp, bp, Color(0.35, 0.25, 0.15, 0.2), 1.5, 4.0)
		canvas.draw_circle(bp, 2.0, Color(0.5, 0.35, 0.2, 0.2))
