## ═══════════════════════════════════════════════════════════════════════════════
## WalkEventOverlay — Darkened overlay with typewriter text + 3 choice buttons
## ═══════════════════════════════════════════════════════════════════════════════
## Displayed over the 3D viewport during LLM-generated events.
## Player movement freezes while active. CRT phosphor aesthetic.
## ═══════════════════════════════════════════════════════════════════════════════

extends CanvasLayer

const _persona_anim := preload("res://scripts/ui/anim/persona_ui_anim.gd")

signal choice_selected(option: int)  # 0=A, 1=B, 2=C
signal overlay_closed

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

const FADE_DURATION: float = 0.4
const DIMMER_ALPHA: float = 0.75
const TYPEWRITER_SPEED: float = 40.0  # chars per second
const BUTTON_APPEAR_DELAY: float = 0.15  # after text done
const FONT_SIZE_TEXT: int = 18
const FONT_SIZE_BUTTON: int = 16

# ═══════════════════════════════════════════════════════════════════════════════
# NODES (built in _ready)
# ═══════════════════════════════════════════════════════════════════════════════

var _dimmer: ColorRect
var _text_label: RichTextLabel
var _button_container: HBoxContainer
var _buttons: Array[Button] = []
var _root: Control
var _card: PanelContainer  # parchment card that animates in/out (3D-ish entry)

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _active: bool = false
var _typing: bool = false
var _visible_chars: int = 0
var _total_chars: int = 0
var _type_timer: float = 0.0
var _current_labels: Array[String] = []
var _fade_tween: Tween
var _auto_respond_timer: float = 0.0
const AUTO_RESPOND_TIMEOUT: float = 30.0  # Auto-select option A after 30s (for auto-test)

# C19 — card dynamism: mouse parallax + idle tilt
var _card_anchor_pos: Vector2 = Vector2.ZERO  # remembered post-entry position for parallax
var _entry_done: bool = false  # gate parallax until entry tween settles
var _ornaments: Array[Label] = []
var _ornament_tweens: Array[Tween] = []
var _button_tweens: Array[Tween] = []  # per-button punch tween — killed before re-fire
const PARALLAX_MAX_OFFSET: float = 5.0  # px — how far the card drifts toward mouse
const PARALLAX_LERP: float = 6.0  # responsiveness


func _ready() -> void:
	layer = 10
	_build_ui()
	_hide_immediate()


func _process(delta: float) -> void:
	# Auto-respond if overlay idle too long (for headless/auto-test)
	if _active and not _typing and _button_container.visible:
		_auto_respond_timer += delta
		if _auto_respond_timer >= AUTO_RESPOND_TIMEOUT:
			_auto_respond_timer = 0.0
			_on_button_pressed(0)  # Auto-select option A
			return
	# C19 — mouse parallax: card drifts subtly toward cursor (only after entry settles).
	if _active and _entry_done and is_instance_valid(_card) and _card_anchor_pos != Vector2.ZERO:
		var vp: Viewport = get_viewport()
		if vp:
			var mp: Vector2 = vp.get_mouse_position()
			var screen: Vector2 = vp.get_visible_rect().size
			var center: Vector2 = screen * 0.5
			var off: Vector2 = ((mp - center) / center).clamp(Vector2(-1, -1), Vector2(1, 1)) * PARALLAX_MAX_OFFSET
			_card.position = _card.position.lerp(_card_anchor_pos + off, clampf(PARALLAX_LERP * delta, 0.0, 1.0))
	if not _typing:
		return
	_type_timer += delta * TYPEWRITER_SPEED
	var new_count: int = int(_type_timer)
	if new_count > _total_chars:
		new_count = _total_chars
	if new_count != _visible_chars:
		_visible_chars = new_count
		_text_label.visible_characters = _visible_chars
	if _visible_chars >= _total_chars:
		_typing = false
		_show_buttons_delayed()


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func show_event(text: String, labels: Array[String]) -> void:
	if _active:
		return
	_active = true
	_current_labels = labels
	_auto_respond_timer = 0.0
	# Telemetry: card shown — text length, risk_hint detected from labels metadata.
	var ml_root: SceneTree = Engine.get_main_loop() as SceneTree
	var metrics_root: Node = ml_root.root.get_node_or_null("MerlinMetrics") if ml_root else null
	if metrics_root and metrics_root.has_method("card_shown"):
		metrics_root.card_shown(text.length(), false, labels.size())
	# Track time for choice_latency on click.
	set_meta("show_time_ms", Time.get_ticks_msec())

	# Reset text
	_text_label.text = text
	_total_chars = text.length()
	_visible_chars = 0
	_type_timer = 0.0
	_text_label.visible_characters = 0
	_text_label.visible = true

	# Hide buttons until text finishes
	_button_container.visible = false
	for i in _buttons.size():
		if i < labels.size():
			_buttons[i].text = "[%s] %s" % [["A", "B", "C"][i], labels[i]]
			_buttons[i].visible = true
		else:
			_buttons[i].visible = false

	# Soft vignette + animated card scale-in (no fly-from-side, just clean center pop)
	_root.visible = true
	_dimmer.color.a = 0.0
	# Compute centered position from the actual viewport size (avoids PRESET-based bugs).
	# Persona-style slash-entry: card flies in tilted from top-left with bounce.
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_entry_done = false
	_fade_tween = create_tween()
	_fade_tween.tween_property(_dimmer, "color:a", DIMMER_ALPHA, FADE_DURATION * 0.6)
	if is_instance_valid(_card):
		var vp: Viewport = get_viewport()
		var screen_size: Vector2 = vp.get_visible_rect().size if vp else Vector2(1280, 720)
		_card_anchor_pos = (screen_size - _card.size) * 0.5
		_persona_anim.slash_entry(_card, screen_size)
		# Enable parallax + ornament pulse after the entry tween settles (~0.5s).
		var settle: Tween = create_tween()
		settle.tween_interval(0.5)
		settle.tween_callback(func() -> void:
			_entry_done = true
			_start_ornament_pulse()
		)
	_fade_tween.tween_callback(func() -> void: _typing = true)


## Show a resolution narrative AFTER a choice has been made (RPG test result).
## The text is typed in place of the choice text, buttons hidden, then auto-closes.
func show_resolution(resolution_text: String) -> void:
	if not _active:
		return
	_typing = false
	_button_container.visible = false
	# Replace text + restart typewriter for the resolution narration.
	_text_label.text = resolution_text
	_total_chars = resolution_text.length()
	_visible_chars = 0
	_type_timer = 0.0
	_text_label.visible_characters = 0
	_typing = true
	# Auto-close after the text finishes typing + 1.8s read time.
	var typing_dur: float = float(_total_chars) / TYPEWRITER_SPEED if TYPEWRITER_SPEED > 0 else 1.0
	var hold: float = 1.8
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_interval(typing_dur + hold)
	_fade_tween.tween_callback(close_overlay)


func close_overlay() -> void:
	if not _active:
		return
	_typing = false
	_entry_done = false  # disable parallax during exit so it doesn't fight slash_exit
	_button_container.visible = false
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_kill_ornament_tweens()
	# Persona-style slash-exit: card flies down-right with tilt + fade.
	if is_instance_valid(_card):
		_persona_anim.slash_exit(_card)
	_fade_tween = create_tween()
	_fade_tween.tween_interval(0.30)
	_fade_tween.tween_property(_dimmer, "color:a", 0.0, FADE_DURATION * 0.6)
	_fade_tween.tween_callback(_on_fade_out_done)


func is_active() -> bool:
	return _active


func skip_typewriter() -> void:
	if _typing:
		_typing = false
		_visible_chars = _total_chars
		_text_label.visible_characters = _total_chars
		_show_buttons_delayed()


# ═══════════════════════════════════════════════════════════════════════════════
# BUILD UI
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var font: Font = MerlinVisual.get_font("terminal")
	var pal: Dictionary = MerlinVisual.CRT_PALETTE

	# Root control (full screen)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Soft vignette (radial-ish via faint color rect — much lighter than the old full dimmer)
	_dimmer = ColorRect.new()
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmer.color = Color(0.0, 0.0, 0.0, 0.0)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dimmer)

	# === PARCHMENT CARD (centered, animated entry) ===
	# Use TOP_LEFT preset + absolute size; centered manually in show_event from viewport size.
	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_card.custom_minimum_size = Vector2(680, 360)
	_card.size = Vector2(680, 360)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_card)

	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.92, 0.83, 0.65)  # cream parchment
	card_style.border_color = Color(0.45, 0.30, 0.15)  # ink brown border
	card_style.set_border_width_all(3)
	card_style.set_corner_radius_all(8)
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	card_style.shadow_size = 18
	card_style.shadow_offset = Vector2(0, 8)
	card_style.set_content_margin_all(28)
	_card.add_theme_stylebox_override("panel", card_style)

	# Decorative corner ornaments — stored for C19 ambient pulse animation.
	_ornaments.clear()
	for corner_pos in [Vector2(8, 4), Vector2(652, 4), Vector2(8, 332), Vector2(652, 332)]:
		var orn: Label = Label.new()
		orn.text = "❦"
		orn.add_theme_font_size_override("font_size", 22)
		orn.add_theme_color_override("font_color", Color(0.45, 0.28, 0.12))
		orn.size = Vector2(22, 22)
		orn.position = corner_pos
		orn.pivot_offset = orn.size * 0.5
		_card.add_child(orn)
		_ornaments.append(orn)

	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	card_vbox.add_theme_constant_override("separation", 14)
	_card.add_child(card_vbox)

	# Narrative text — ink on parchment
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_override("normal_font", font)
	_text_label.add_theme_font_size_override("normal_font_size", FONT_SIZE_TEXT)
	_text_label.add_theme_color_override("default_color", Color(0.22, 0.13, 0.07))
	_text_label.visible_characters = 0
	card_vbox.add_child(_text_label)

	# Ornamented separator (◆ ─── ◆)
	var sep_row: HBoxContainer = HBoxContainer.new()
	sep_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sep_row.add_theme_constant_override("separation", 6)
	card_vbox.add_child(sep_row)
	for sym in ["◆", "─────", "◆"]:
		var sym_lbl: Label = Label.new()
		sym_lbl.text = sym
		sym_lbl.add_theme_font_size_override("font_size", 14)
		sym_lbl.add_theme_color_override("font_color", Color(0.45, 0.28, 0.12))
		sep_row.add_child(sym_lbl)

	# Button row (parchment-style choices)
	_button_container = HBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 20)
	_button_container.visible = false
	card_vbox.add_child(_button_container)

	_button_tweens.resize(3)
	for i in 3:
		var btn: Button = _create_choice_button(font, pal, i)
		_button_container.add_child(btn)
		_buttons.append(btn)
		# C19 — Persona-style hover punch on each choice button.
		btn.mouse_entered.connect(_on_button_hover.bind(i))


func _create_choice_button(font: Font, _pal: Dictionary, index: int) -> Button:
	# Parchment-styled choice buttons (ink on cream, sepia hover, gold pressed)
	var btn: Button = Button.new()
	btn.text = "[%s] ..." % ["A", "B", "C"][index]
	btn.custom_minimum_size = Vector2(170.0, 42.0)
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_BUTTON)
	btn.add_theme_color_override("font_color", Color(0.22, 0.13, 0.07))
	btn.add_theme_color_override("font_hover_color", Color(0.55, 0.20, 0.10))
	btn.add_theme_color_override("font_pressed_color", Color(0.65, 0.13, 0.10))

	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.84, 0.74, 0.55)  # darker parchment for contrast on the card
	style_normal.border_color = Color(0.45, 0.28, 0.12)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(4)
	style_normal.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover: StyleBoxFlat = style_normal.duplicate()
	style_hover.bg_color = Color(0.78, 0.65, 0.45)
	style_hover.border_color = Color(0.55, 0.20, 0.10)
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed: StyleBoxFlat = style_normal.duplicate()
	style_pressed.bg_color = Color(0.65, 0.13, 0.10)
	style_pressed.border_color = Color(0.30, 0.08, 0.05)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.pressed.connect(_on_button_pressed.bind(index))
	return btn


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL
# ═══════════════════════════════════════════════════════════════════════════════

func _hide_immediate() -> void:
	# Mirrors close_overlay's cleanup: kill any orphan ornament/punch tweens
	# so a future show_event starts from a clean slate (HIGH from code-review).
	_entry_done = false
	_kill_ornament_tweens()
	for t in _button_tweens:
		if t and t.is_valid():
			t.kill()
	_root.visible = false
	_active = false
	_typing = false


func _show_buttons_delayed() -> void:
	var tw: Tween = create_tween()
	tw.tween_interval(BUTTON_APPEAR_DELAY)
	tw.tween_callback(func() -> void:
		_button_container.visible = true
		# Staggered slide-in + scale for each button
		var stagger: float = 0.0
		for btn in _buttons:
			if not btn.visible:
				continue
			btn.pivot_offset = btn.size * 0.5
			btn.modulate.a = 0.0
			btn.scale = Vector2(0.8, 0.8)
			btn.position.y += 20.0
			var entry: Tween = btn.create_tween()
			entry.set_parallel(true)
			entry.tween_property(btn, "modulate:a", 1.0, 0.25).set_delay(stagger)
			entry.tween_property(btn, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(stagger)
			entry.tween_property(btn, "position:y", btn.position.y - 20.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(stagger)
			stagger += 0.12
		# Keyboard focus on first button after animation
		if _buttons.size() > 0 and _buttons[0].visible:
			var focus_tw: Tween = create_tween()
			focus_tw.tween_interval(stagger + 0.15)
			focus_tw.tween_callback(func() -> void:
				if _buttons[0].is_inside_tree():
					_buttons[0].grab_focus()
			)
	)


func _on_button_pressed(index: int) -> void:
	if not _active:
		return
	# C19 — punch + color burst on selection for tactile feedback.
	if index >= 0 and index < _buttons.size() and is_instance_valid(_buttons[index]):
		_play_button_punch(index, 1.18)
		_persona_anim.color_burst(_buttons[index], Color(0.92, 0.83, 0.65))
	choice_selected.emit(index)
	close_overlay()


func _on_button_hover(index: int) -> void:
	if not _active or index < 0 or index >= _buttons.size():
		return
	var btn: Button = _buttons[index]
	if not is_instance_valid(btn) or not btn.visible:
		return
	# Light-touch hover: a tiny scale punch (1.06) — barely felt, but registers.
	_play_button_punch(index, 1.06)


func _play_button_punch(index: int, intensity: float) -> void:
	# Kill any prior punch on this button so rapid re-hover doesn't stack
	# concurrent scale tweens (HIGH from code-review).
	if index < _button_tweens.size():
		var prev: Tween = _button_tweens[index]
		if prev and prev.is_valid():
			prev.kill()
		_button_tweens[index] = _persona_anim.punch(_buttons[index], intensity)


func _start_ornament_pulse() -> void:
	# Slow, sleepy breathing for the four parchment corner ornaments.
	# Stops on close_overlay via _kill_ornament_tweens.
	_kill_ornament_tweens()
	for i in _ornaments.size():
		var orn: Label = _ornaments[i]
		if not is_instance_valid(orn):
			continue
		var phase: float = float(i) * 0.4  # stagger so they don't all pulse together
		var period: float = 3.2
		var t: Tween = orn.create_tween().set_loops()
		t.tween_interval(phase)
		t.tween_property(orn, "scale", Vector2(1.18, 1.18), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(orn, "scale", Vector2(1.0, 1.0), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_ornament_tweens.append(t)


func _kill_ornament_tweens() -> void:
	for t in _ornament_tweens:
		if t and t.is_valid():
			t.kill()
	_ornament_tweens.clear()


func _on_fade_out_done() -> void:
	_root.visible = false
	_active = false
	overlay_closed.emit()
