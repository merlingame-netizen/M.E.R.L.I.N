extends CanvasLayer
## MerlinOptions — overlay superpose (musique ininterrompue).
## Autoload. API : toggle(), is_open().

const COL_BG: Color = MerlinVisual.BG_DEEP
const COL_TEXT: Color = MerlinVisual.CREAM
const COL_GOLD: Color = MerlinVisual.GOLD
const COL_DIM: Color = MerlinVisual.DIM_WARM
const DUR_IN: float = MerlinVisual.DUR_PANEL_OPEN
const DUR_OUT: float = MerlinVisual.DUR_VEIL_IN

var _dim: ColorRect
var _panel: MarginContainer
var _vol_master: HSlider
var _vol_music: HSlider
var _vol_sfx: HSlider
var _vol_voice: HSlider
var _title_lbl: Label
var _back_btn: Button
var _tw: Tween = null
var _init_sliders: bool = false


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func toggle() -> void:
	if visible:
		_close()
	else:
		_open()


func is_open() -> bool:
	return visible


func _open() -> void:
	_init_sliders = true
	_vol_master.value = MerlinAudio.master_vol * 100.0
	_vol_music.value = MerlinAudio.music_vol * 100.0
	_vol_sfx.value = MerlinAudio.sfx_vol * 100.0
	_vol_voice.value = MerlinAudio.voice_vol * 100.0
	_init_sliders = false
	visible = true
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(1.0, 0.85)
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var d: float = DUR_IN * MerlinVisual.motion()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(_dim, "modulate:a", 1.0, d).set_trans(Tween.TRANS_SINE)
	_tw.tween_property(_panel, "modulate:a", 1.0, d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_panel, "scale", Vector2.ONE, d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	MerlinAudio.play_sfx("button_tap")


func _close() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var d: float = DUR_OUT * MerlinVisual.motion()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(_dim, "modulate:a", 0.0, d).set_trans(Tween.TRANS_SINE)
	_tw.tween_property(_panel, "modulate:a", 0.0, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.tween_property(_panel, "scale", Vector2(1.0, 0.85), d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _tw.finished
	visible = false
	MerlinAudio.play_sfx("button_tap")


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_dim = ColorRect.new()
	_dim.color = MerlinVisual.DIM_OPTIONS
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_dim)

	_panel = MarginContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right"]:
		_panel.add_theme_constant_override(m, 120)
	for m in ["margin_top", "margin_bottom"]:
		_panel.add_theme_constant_override(m, 80)
	root.add_child(_panel)
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size * 0.5)

	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(bg)

	var inner: MarginContainer = MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		inner.add_theme_constant_override(m, 40)
	_panel.add_child(inner)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	inner.add_child(vbox)

	_title_lbl = Label.new()
	_title_lbl.text = "Options"
	_title_lbl.add_theme_color_override("font_color", COL_GOLD)
	_title_lbl.add_theme_font_size_override("font_size", 34)
	vbox.add_child(_title_lbl)
	# Filet + triskèle or (DA alignée sur le menu, user 2026-06-29).
	var rule: HBoxContainer = MerlinOrnament.triskele_rule(22.0)
	vbox.add_child(rule)
	MerlinOrnament.spin_triskele(rule)

	_vol_master = _slider_row("Volume Maître", 80, vbox)
	_vol_master.value_changed.connect(func(v: float) -> void:
		if not _init_sliders: MerlinAudio.set_bus_volume("Master", v / 100.0))
	_vol_music = _slider_row("Musique", 70, vbox)
	_vol_music.value_changed.connect(func(v: float) -> void:
		if not _init_sliders: MerlinAudio.set_bus_volume("Music", v / 100.0))
	_vol_sfx = _slider_row("Effets sonores", 80, vbox)
	_vol_sfx.value_changed.connect(func(v: float) -> void:
		if not _init_sliders: MerlinAudio.set_bus_volume("SFX", v / 100.0))
	_vol_voice = _slider_row("Voix de Merlin (volume)", 70, vbox)
	_vol_voice.value_changed.connect(func(v: float) -> void:
		if not _init_sliders: MerlinAudio.set_voice_vol(v / 100.0))

	MerlinVisual.load_prefs()
	var reduce: CheckButton = _check_row("Réduire les animations / glitch", MerlinVisual.reduced_motion)
	reduce.toggled.connect(func(on: bool) -> void:
		MerlinVisual.reduced_motion = on
		MerlinVisual.save_prefs())
	vbox.add_child(reduce)

	# Voix de Merlin (bulles de pensée au menu) — user 2026-06-29. Simple interrupteur on/off.
	var voice_chk: CheckButton = _check_row("Voix de Merlin (bulles au menu)", MerlinVoicePrefs.is_enabled())
	voice_chk.toggled.connect(func(on: bool) -> void: MerlinVoicePrefs.set_enabled(on))
	vbox.add_child(voice_chk)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	_back_btn = Button.new()
	_back_btn.text = "◀ Fermer"
	_back_btn.custom_minimum_size = Vector2(160, 48)
	MerlinVisual.apply_button_da(_back_btn)
	_back_btn.pressed.connect(toggle)
	vbox.add_child(_back_btn)
	MerlinVisual.connect_button_feedback(_back_btn)


func _slider_row(label: String, value: float, parent: Control) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var l: Label = Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(280, 0)
	l.add_theme_color_override("font_color", COL_TEXT)
	l.add_theme_font_size_override("font_size", 17)
	row.add_child(l)
	var s: HSlider = HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.value = value
	s.custom_minimum_size = Vector2(320, 44)
	row.add_child(s)
	parent.add_child(row)
	return s


func _check_row(label: String, on: bool) -> CheckButton:
	var c: CheckButton = CheckButton.new()
	c.text = label
	c.button_pressed = on
	c.custom_minimum_size = Vector2(0, 44)
	c.add_theme_color_override("font_color", COL_TEXT)
	return c


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()
