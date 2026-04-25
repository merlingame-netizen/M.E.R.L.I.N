## ScreenFrame — Persistent pixel-art + Celtic border overlay
## Autoload CanvasLayer (layer 99) visible on ALL scenes from IntroCeltOS onward.
## Draws a procedural border with Celtic knot corners and pixel-art edges.
## Integrates the LLM status crystal icon in bottom-left corner.

extends CanvasLayer

# --- Configuration ---
const BORDER_WIDTH := 12
const CORNER_SIZE := 24
const PULSE_DURATION := 2.0

# --- State ---
var _frame_container: Control
var _corners: Array[Control] = []
var _borders: Array[ColorRect] = []
var _biome_tint: Color = Color.WHITE
var _llm_icon: Control = null

# --- Corner indices ---
enum Corner { TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }


func _ready() -> void:
	layer = 99
	# Demo mode hides the green frame border (clean, immersive PS1 view).
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--demo") or OS.has_environment("MERLIN_DEMO"):
		visible = false
		return
	_build_frame()
	_build_llm_icon()
	# Connect to biome changes if WorldMapSystem exists
	var wms := get_node_or_null("/root/WorldMapSystem")
	if wms and wms.has_signal("biome_changed"):
		wms.biome_changed.connect(_on_biome_changed)


func _build_frame() -> void:
	_frame_container = Control.new()
	_frame_container.name = "FrameContainer"
	_frame_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame_container)

	var border_color: Color = MerlinVisual.CRT_PALETTE["border"]
	var bg_deep: Color = MerlinVisual.CRT_PALETTE["bg_deep"]

	# --- 4 border edges ---
	# Top
	var top := _make_border_rect()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = BORDER_WIDTH
	top.color = bg_deep
	_frame_container.add_child(top)
	_borders.append(top)

	# Bottom
	var bottom := _make_border_rect()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -BORDER_WIDTH
	bottom.color = bg_deep
	_frame_container.add_child(bottom)
	_borders.append(bottom)

	# Left
	var left := _make_border_rect()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_right = BORDER_WIDTH
	left.color = bg_deep
	_frame_container.add_child(left)
	_borders.append(left)

	# Right
	var right := _make_border_rect()
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -BORDER_WIDTH
	right.color = bg_deep
	_frame_container.add_child(right)
	_borders.append(right)

	# --- Inner border lines (1px accent) ---
	_add_inner_line("top", border_color)
	_add_inner_line("bottom", border_color)
	_add_inner_line("left", border_color)
	_add_inner_line("right", border_color)

	# --- 4 Celtic knot corners (procedural pixel-art) ---
	for i in 4:
		var corner := _make_celtic_corner(i as Corner)
		_frame_container.add_child(corner)
		_corners.append(corner)


func _make_border_rect() -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _add_inner_line(side: String, line_color: Color) -> void:
	var line := ColorRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = line_color

	match side:
		"top":
			line.set_anchors_preset(Control.PRESET_TOP_WIDE)
			line.offset_top = BORDER_WIDTH
			line.offset_bottom = BORDER_WIDTH + 1
		"bottom":
			line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			line.offset_top = -(BORDER_WIDTH + 1)
			line.offset_bottom = -BORDER_WIDTH
		"left":
			line.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			line.offset_left = BORDER_WIDTH
			line.offset_right = BORDER_WIDTH + 1
		"right":
			line.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
			line.offset_left = -(BORDER_WIDTH + 1)
			line.offset_right = -BORDER_WIDTH

	_frame_container.add_child(line)


func _make_celtic_corner(corner_idx: int) -> Control:
	var container := Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.custom_minimum_size = Vector2(CORNER_SIZE, CORNER_SIZE)

	# Position based on corner
	match corner_idx:
		Corner.TOP_LEFT:
			container.set_anchors_preset(Control.PRESET_TOP_LEFT)
			container.offset_right = CORNER_SIZE
			container.offset_bottom = CORNER_SIZE
		Corner.TOP_RIGHT:
			container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			container.offset_left = -CORNER_SIZE
			container.offset_bottom = CORNER_SIZE
		Corner.BOTTOM_LEFT:
			container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			container.offset_right = CORNER_SIZE
			container.offset_top = -CORNER_SIZE
		Corner.BOTTOM_RIGHT:
			container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			container.offset_left = -CORNER_SIZE
			container.offset_top = -CORNER_SIZE

	# Draw Celtic knot pattern procedurally
	var knot := _CelticKnotDraw.new()
	knot.corner_index = corner_idx
	knot.set_anchors_preset(Control.PRESET_FULL_RECT)
	knot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(knot)

	return container


# --- LLM Status Crystal Icon (bottom-left, inside border) ---
func _build_llm_icon() -> void:
	_llm_icon = _LLMCrystalIcon.new()
	_llm_icon.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_llm_icon.offset_left = 0
	_llm_icon.offset_top = -(BORDER_WIDTH)
	_llm_icon.offset_right = BORDER_WIDTH
	_llm_icon.offset_bottom = 0
	_llm_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_llm_icon.tooltip_text = "LLM: Initialisation..."
	_frame_container.add_child(_llm_icon)

	# Connect to MerlinAI signals
	var mai := get_node_or_null("/root/MerlinAI")
	if mai:
		if mai.has_signal("status_changed"):
			mai.status_changed.connect(_on_llm_status_changed)
		if mai.has_signal("ready_changed"):
			mai.ready_changed.connect(_on_llm_ready_changed)


# --- Public API ---

func set_biome_tint(color: Color) -> void:
	_biome_tint = color
	var border_color: Color = MerlinVisual.CRT_PALETTE["border"]
	var tinted: Color = border_color.lerp(color, 0.25)
	for line in _frame_container.get_children():
		if line is ColorRect and line.color != MerlinVisual.CRT_PALETTE["bg_deep"]:
			line.color = tinted


func pulse_corner(corner_idx: int) -> void:
	if corner_idx < 0 or corner_idx >= _corners.size():
		return
	var corner: Control = _corners[corner_idx]
	var tween := create_tween()
	tween.tween_property(corner, "modulate", Color(1.5, 1.5, 1.5), 0.3)
	tween.tween_property(corner, "modulate", Color.WHITE, 0.7)


# --- Signal handlers ---

func _on_biome_changed(biome_data: Dictionary) -> void:
	if biome_data.has("color"):
		set_biome_tint(biome_data["color"])


func _on_llm_status_changed(status_text: String, detail_text: String, progress_value: float) -> void:
	if _llm_icon and _llm_icon.has_method("update_status"):
		_llm_icon.update_status(status_text, detail_text, progress_value)


func _on_llm_ready_changed(is_ready: bool) -> void:
	if _llm_icon and _llm_icon.has_method("set_ready"):
		_llm_icon.set_ready(is_ready)


# ═══════════════════════════════════════════════════════════════════════════════
# Inner class: Celtic Knot Corner (procedural pixel-art)
# ═══════════════════════════════════════════════════════════════════════════════

class _CelticKnotDraw extends Control:
	var corner_index: int = 0

	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		if s < 4:
			return
		var amber: Color = MerlinVisual.CRT_PALETTE["amber_dim"]
		var cyan: Color = MerlinVisual.CRT_PALETTE["cyan_dim"]
		var border_c: Color = MerlinVisual.CRT_PALETTE["border_bright"]

		# Draw interlocking arcs (simplified Celtic knot)
		var px: float = s / 8.0
		var half: float = s / 2.0

		# Rotate coordinates based on corner
		var flip_x: bool = corner_index == Corner.TOP_RIGHT or corner_index == Corner.BOTTOM_RIGHT
		var flip_y: bool = corner_index == Corner.BOTTOM_LEFT or corner_index == Corner.BOTTOM_RIGHT

		# Outer arc (amber)
		_draw_knot_arc(px, half, s, amber, flip_x, flip_y)
		# Inner arc (cyan)
		_draw_knot_arc(px * 1.5, half * 0.7, s * 0.7, cyan, flip_x, flip_y)
		# Border accent dots at the tips
		_draw_accent_dots(px, s, border_c, flip_x, flip_y)

	func _draw_knot_arc(thickness: float, radius: float, extent: float, color: Color, fx: bool, fy: bool) -> void:
		var points: PackedVector2Array = []
		var cx: float = 0.0 if not fx else extent
		var cy: float = 0.0 if not fy else extent
		for i in range(0, 7):
			var angle: float = (float(i) / 6.0) * PI * 0.5
			if fx:
				angle = PI - angle
			if fy:
				angle = -angle
			var px: float = cx + cos(angle) * radius
			var py: float = cy + sin(angle) * radius
			points.append(Vector2(px, py))
		if points.size() >= 2:
			draw_polyline(points, color, thickness, true)

	func _draw_accent_dots(px: float, s: float, color: Color, fx: bool, fy: bool) -> void:
		# Small dots at knot intersections
		var dot_size: float = px * 0.8
		var positions: Array[Vector2] = [
			Vector2(px * 2, px * 2),
			Vector2(s * 0.4, px * 2),
			Vector2(px * 2, s * 0.4),
		]
		for pos in positions:
			var final_pos := pos
			if fx:
				final_pos.x = s - final_pos.x
			if fy:
				final_pos.y = s - final_pos.y
			draw_circle(final_pos, dot_size, color)


# ═══════════════════════════════════════════════════════════════════════════════
# Inner class: LLM Crystal Status Icon (procedural pixel-art, animated)
# ═══════════════════════════════════════════════════════════════════════════════

class _LLMCrystalIcon extends Control:
	enum State { DISCONNECTED, WARMUP, READY, GENERATING, ERROR }

	var current_state: State = State.DISCONNECTED
	var _pulse_phase: float = 0.0
	var _warmup_progress: float = 0.0
	var _blink_on: bool = true
	var _blink_timer: float = 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(BORDER_WIDTH, BORDER_WIDTH)

	func _process(delta: float) -> void:
		_pulse_phase += delta
		match current_state:
			State.READY:
				queue_redraw()
			State.GENERATING:
				queue_redraw()
			State.ERROR:
				_blink_timer += delta
				if _blink_timer > 0.3:
					_blink_timer = 0.0
					_blink_on = not _blink_on
					queue_redraw()
			State.WARMUP:
				queue_redraw()

	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		var cx: float = s * 0.5
		var cy: float = s * 0.5
		var r: float = s * 0.35

		var base_color: Color
		var glow_alpha: float = 0.0

		match current_state:
			State.DISCONNECTED:
				base_color = MerlinVisual.CRT_PALETTE["inactive"]
			State.WARMUP:
				base_color = MerlinVisual.CRT_PALETTE["amber_dim"]
				# Fill effect bottom-up
				var fill_y: float = cy + r - (_warmup_progress / 100.0) * r * 2
				var fill_color: Color = MerlinVisual.CRT_PALETTE["amber"]
				draw_rect(Rect2(cx - r, fill_y, r * 2, cy + r - fill_y), fill_color)
			State.READY:
				base_color = MerlinVisual.CRT_PALETTE["cyan"]
				glow_alpha = 0.15 + sin(_pulse_phase * PI / PULSE_DURATION) * 0.1
			State.GENERATING:
				base_color = MerlinVisual.CRT_PALETTE["amber"]
				glow_alpha = 0.2 + sin(_pulse_phase * PI * 4.0) * 0.15
			State.ERROR:
				base_color = MerlinVisual.CRT_PALETTE["danger"] if _blink_on else MerlinVisual.CRT_PALETTE["inactive"]

		# Draw diamond shape (crystal)
		var points := PackedVector2Array([
			Vector2(cx, cy - r),       # top
			Vector2(cx + r * 0.7, cy), # right
			Vector2(cx, cy + r),       # bottom
			Vector2(cx - r * 0.7, cy), # left
		])
		draw_colored_polygon(points, base_color)

		# Glow effect for active states
		if glow_alpha > 0.0:
			var glow_color := Color(base_color.r, base_color.g, base_color.b, glow_alpha)
			draw_circle(Vector2(cx, cy), r * 1.3, glow_color)

		# Inner highlight
		var highlight := Color(1.0, 1.0, 1.0, 0.15)
		var inner := PackedVector2Array([
			Vector2(cx, cy - r * 0.4),
			Vector2(cx + r * 0.25, cy - r * 0.1),
			Vector2(cx, cy + r * 0.1),
			Vector2(cx - r * 0.25, cy - r * 0.1),
		])
		draw_colored_polygon(inner, highlight)

	func update_status(status_text: String, _detail_text: String, progress_value: float) -> void:
		_warmup_progress = progress_value
		if "OK" in status_text:
			current_state = State.READY
		elif "Erreur" in status_text or "ERROR" in status_text:
			current_state = State.ERROR
		elif progress_value > 0.0 and progress_value < 100.0:
			current_state = State.WARMUP
		tooltip_text = status_text + "\n" + _detail_text
		queue_redraw()

	func set_ready(is_ready: bool) -> void:
		if is_ready:
			current_state = State.READY
		elif current_state == State.READY:
			current_state = State.DISCONNECTED
		queue_redraw()

	func set_generating(generating: bool) -> void:
		if generating:
			current_state = State.GENERATING
		elif current_state == State.GENERATING:
			current_state = State.READY
		queue_redraw()
