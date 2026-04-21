class_name OghamEquipPanel
extends Control

## Pre-run Ogham selection overlay — CRT-styled card grid
## Player picks one Ogham to equip before entering the biome

signal ogham_selected(ogham_key: String)
signal panel_dismissed

# === VISUAL ===

const CARD_W := 76.0
const CARD_H := 100.0
const CARD_GAP := 10.0
const MAX_PER_ROW := 6
const STAGGER := 0.04
const OPEN_DUR := 0.22
const CLOSE_DUR := 0.14

const CATEGORY_ACCENT := {
	"reveal": "cyan",
	"protection": "phosphor",
	"boost": "amber",
	"narratif": "cyan_bright",
	"recovery": "phosphor_dim",
	"special": "danger",
}

# === STATE ===

var _is_open := false
var _oghams: Array = []
var _rects: Array[Rect2] = []
var _scales: Array[float] = []
var _hovered: int = -1

# === LIFECYCLE ===

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func _draw() -> void:
	if not _is_open:
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.55), true)

	var font: Font = MerlinVisual.get_font("body")
	var title := "Choisir ton Ogham"
	var ts: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 26)
	var tp := Vector2((size.x - ts.x) * 0.5, size.y * 0.28)
	draw_string(font, tp + Vector2(1, 1), title, HORIZONTAL_ALIGNMENT_CENTER, -1, 26, MerlinVisual.CRT_PALETTE["bg_deep"])
	draw_string(font, tp, title, HORIZONTAL_ALIGNMENT_CENTER, -1, 26, MerlinVisual.CRT_PALETTE["phosphor_bright"])

	for i in _oghams.size():
		_draw_card(i)

func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(mb.position)
			accept_event()
	elif event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event.is_action_pressed("ui_cancel"):
		panel_dismissed.emit()
		close()
		accept_event()

# === PUBLIC API ===

func open(oghams: Array) -> void:
	if _is_open:
		return
	_oghams = oghams
	if _oghams.is_empty():
		_oghams = MerlinConstants.OGHAM_STARTER_SKILLS.duplicate()
	_is_open = true
	_hovered = -1
	visible = true
	_layout_cards()
	_scales.resize(_oghams.size())
	for i in _oghams.size():
		_scales[i] = 0.0
	_animate_open()

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_hovered = -1
	_animate_close()

func is_open() -> bool:
	return _is_open

# === LAYOUT ===

func _layout_cards() -> void:
	_rects.clear()
	var count: int = _oghams.size()
	var base_y: float = size.y * 0.35

	for i in count:
		var row: int = i / MAX_PER_ROW
		var col: int = i % MAX_PER_ROW
		var items_in_row: int = mini(MAX_PER_ROW, count - row * MAX_PER_ROW)
		var rw: float = items_in_row * CARD_W + (items_in_row - 1) * CARD_GAP
		var rx: float = (size.x - rw) * 0.5
		var x: float = rx + col * (CARD_W + CARD_GAP)
		var y: float = base_y + row * (CARD_H + CARD_GAP)
		_rects.append(Rect2(Vector2(x, y), Vector2(CARD_W, CARD_H)))

# === ANIMATION ===

func _animate_open() -> void:
	for i in _oghams.size():
		_tween_card_in(i, i * STAGGER)

func _tween_card_in(idx: int, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	var tw := create_tween()
	tw.set_trans(MerlinVisual.TRANS_UI)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_method(
		func(v: float) -> void:
			_scales[idx] = v
			queue_redraw(),
		0.0,
		1.0,
		OPEN_DUR
	)

func _animate_close() -> void:
	var tw := create_tween()
	tw.set_trans(MerlinVisual.TRANS_UI)
	tw.set_ease(MerlinVisual.EASING_UI)
	for i in _oghams.size():
		tw.parallel().tween_method(
			func(v: float) -> void:
				_scales[i] = v
				queue_redraw(),
			_scales[i],
			0.0,
			CLOSE_DUR
		)
	await tw.finished
	visible = false

# === INPUT ===

func _handle_click(pos: Vector2) -> void:
	for i in _rects.size():
		if _rects[i].has_point(pos) and _scales[i] > 0.5:
			SFXManager.play("ogham_chime")
			ogham_selected.emit(_oghams[i])
			close()
			return
	panel_dismissed.emit()
	close()

func _update_hover(pos: Vector2) -> void:
	var prev := _hovered
	_hovered = -1
	for i in _rects.size():
		if _rects[i].has_point(pos):
			_hovered = i
			break
	if prev != _hovered:
		if _hovered >= 0:
			SFXManager.play("hover")
		queue_redraw()

# === DRAWING ===

func _draw_card(idx: int) -> void:
	if _scales[idx] <= 0.01:
		return

	var key: String = _oghams[idx]
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(key, {})
	var rect: Rect2 = _rects[idx]
	var s: float = _scales[idx]
	var hov: bool = idx == _hovered

	var center := rect.get_center()
	var ss := rect.size * s
	var sr := Rect2(center - ss * 0.5, ss)

	# Card bg
	var c_bg: Color = MerlinVisual.CRT_PALETTE["bg_highlight"] if hov else MerlinVisual.CRT_PALETTE["bg_panel"]
	draw_rect(sr, c_bg, true)

	# Border — category accent
	var cat: String = str(spec.get("category", "special"))
	var accent_key: String = CATEGORY_ACCENT.get(cat, "phosphor")
	var c_accent: Color = MerlinVisual.CRT_PALETTE[accent_key]
	var border_alpha: float = 1.0 if hov else 0.5
	draw_rect(sr, Color(c_accent.r, c_accent.g, c_accent.b, border_alpha), false, 2.0 if hov else 1.0)

	var font: Font = MerlinVisual.get_font("body")

	# Ogham unicode glyph
	var glyph: String = str(spec.get("unicode", "?"))
	var g_sz: int = int(22 * s)
	var g_w: Vector2 = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, g_sz)
	var g_pos := Vector2(sr.position.x + (sr.size.x - g_w.x) * 0.5, sr.position.y + 28 * s)
	draw_string(font, g_pos, glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, g_sz, c_accent)

	# Name
	var nm: String = str(spec.get("name", key))
	var n_sz: int = int(13 * s)
	var n_w: Vector2 = font.get_string_size(nm, HORIZONTAL_ALIGNMENT_CENTER, -1, n_sz)
	var n_pos := Vector2(sr.position.x + (sr.size.x - n_w.x) * 0.5, sr.position.y + 50 * s)
	var c_nm: Color = MerlinVisual.GBC["white"] if hov else Color(1.0, 1.0, 1.0, 0.75)
	draw_string(font, n_pos, nm, HORIZONTAL_ALIGNMENT_CENTER, -1, n_sz, c_nm)

	# Category tag
	var cat_label: String = cat.substr(0, 1).to_upper() + cat.substr(1)
	var ct_sz: int = int(10 * s)
	var ct_w: Vector2 = font.get_string_size(cat_label, HORIZONTAL_ALIGNMENT_CENTER, -1, ct_sz)
	var ct_pos := Vector2(sr.position.x + (sr.size.x - ct_w.x) * 0.5, sr.position.y + 66 * s)
	draw_string(font, ct_pos, cat_label, HORIZONTAL_ALIGNMENT_CENTER, -1, ct_sz, Color(c_accent.r, c_accent.g, c_accent.b, 0.6))

	# Cooldown
	var cd: int = int(spec.get("cooldown", 3))
	var cd_text := "CD %d" % cd
	var cd_sz: int = int(10 * s)
	var cd_w: Vector2 = font.get_string_size(cd_text, HORIZONTAL_ALIGNMENT_CENTER, -1, cd_sz)
	var cd_pos := Vector2(sr.position.x + (sr.size.x - cd_w.x) * 0.5, sr.position.y + sr.size.y - 6 * s)
	draw_string(font, cd_pos, cd_text, HORIZONTAL_ALIGNMENT_CENTER, -1, cd_sz, MerlinVisual.CRT_PALETTE["phosphor_dim"])

	# Hover glow
	if hov:
		var glow := Color(c_accent.r, c_accent.g, c_accent.b, 0.08)
		draw_rect(sr, glow, true)
