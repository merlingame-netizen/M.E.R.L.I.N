extends Control
## MerlinOptions — écran Options (bible R74). MVP : contrôles présents + retour.
## (Câblage effectif audio/vitesse/accessibilité = polish post-MVP.)

const COL_BG: Color = MerlinVisual.BG_DEEP
const COL_TEXT: Color = MerlinVisual.CREAM
const COL_GOLD: Color = MerlinVisual.GOLD
const COL_DIM: Color = MerlinVisual.DIM_WARM

const MENU_SCENE: String = "res://scenes/MerlinMenu.tscn"

var _vol_master: HSlider
var _vol_music: HSlider
var _vol_sfx: HSlider
var _title_lbl: Label
var _back_btn: Button
var _option_rows: Array[Control] = []


func _ready() -> void:
	MerlinVisual.load_prefs()
	_build_ui()
	_vol_master.value = MerlinAudio.master_vol * 100.0
	_vol_music.value = MerlinAudio.music_vol * 100.0
	_vol_sfx.value = MerlinAudio.sfx_vol * 100.0


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 48)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	_title_lbl = Label.new()
	_title_lbl.text = "Options"
	_title_lbl.add_theme_color_override("font_color", COL_GOLD)
	_title_lbl.add_theme_font_size_override("font_size", 34)
	root.add_child(_title_lbl)

	_vol_master = _slider_row("Volume Maître", 80, root)
	_vol_master.value_changed.connect(func(v: float) -> void: MerlinAudio.set_bus_volume("Master", v / 100.0))
	_vol_music = _slider_row("Musique", 70, root)
	_vol_music.value_changed.connect(func(v: float) -> void: MerlinAudio.set_bus_volume("Music", v / 100.0))
	_vol_sfx = _slider_row("Effets sonores", 80, root)
	_vol_sfx.value_changed.connect(func(v: float) -> void: MerlinAudio.set_bus_volume("SFX", v / 100.0))
	_slider_row("Vitesse du texte", 60, root)
	# v10.13.1 — reduce-motion CÂBLÉ (BIBLE §23 R118/R74) : persiste + alimente MerlinVisual.
	var reduce: CheckButton = _check_row("Réduire les animations / glitch", MerlinVisual.reduced_motion)
	reduce.toggled.connect(func(on: bool) -> void:
		MerlinVisual.reduced_motion = on
		MerlinVisual.save_prefs())
	root.add_child(reduce)
	root.add_child(_check_row("Contraste renforcé", false))
	root.add_child(_check_row("Police lisible (dys)", false))

	var lang: Label = Label.new()
	lang.text = "Langue : Français (multi-langue = post-MVP)"
	lang.add_theme_color_override("font_color", COL_DIM)
	lang.add_theme_font_size_override("font_size", 15)
	root.add_child(lang)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	_back_btn = Button.new()
	_back_btn.text = "◀ Retour"
	_back_btn.custom_minimum_size = Vector2(160, 48)
	_back_btn.pressed.connect(_on_back)
	root.add_child(_back_btn)
	MerlinVisual.connect_button_feedback(_back_btn)
	_animate_entrance()


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
	_option_rows.append(row)
	return s


func _check_row(label: String, on: bool) -> CheckButton:
	var c: CheckButton = CheckButton.new()
	c.text = label
	c.button_pressed = on
	c.custom_minimum_size = Vector2(0, 44)
	c.add_theme_color_override("font_color", COL_TEXT)
	return c


func _animate_entrance() -> void:
	_fade_in(_title_lbl, 0.00, 0.40)
	for i in _option_rows.size():
		_fade_in(_option_rows[i], 0.15 + 0.08 * float(i), 0.35)
	_fade_in(_back_btn, 0.60, 0.35)


func _fade_in(node: CanvasItem, delay: float, dur: float) -> void:
	node.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_interval(maxf(delay, 0.001))
	tw.tween_property(node, "modulate:a", 1.0, dur * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_back() -> void:
	MerlinTransition.change_scene(MENU_SCENE)
