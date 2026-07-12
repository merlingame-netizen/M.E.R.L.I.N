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
var _tuto_btn: Button = null  # N4-TUTO : « Revoir le guide de Merlin » (ré-arme pour la prochaine run)
var _tw: Tween = null
var _init_sliders: bool = false

const TUTO_BTN_IDLE: String = "Revoir le guide de Merlin"
const TUTO_BTN_ARMED: String = "Le guide t'attendra à la prochaine traversée"


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
	_refresh_tuto_btn()  # N4-TUTO : reflète l'état ré-armé (persisté chronique) à chaque ouverture
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

	# P3 (chantier 2, CDC-UX-06) — PACK LECTURE : vitesse du typewriter + taille du récit. Persistés
	# via MerlinVisual (section [reading]), appliqués live au prochain texte de MerlinGame/MerlinEnd.
	_segmented_row("Vitesse du texte", MerlinVisual.TW_LABELS,
		func() -> int: return MerlinVisual.typewriter_speed,
		func(i: int) -> void:
			MerlinVisual.typewriter_speed = i
			MerlinVisual.save_prefs(), vbox)
	_segmented_row("Taille du texte", MerlinVisual.TEXT_LABELS,
		func() -> int: return MerlinVisual.text_scale,
		func(i: int) -> void:
			MerlinVisual.text_scale = i
			MerlinVisual.save_prefs(), vbox)

	# N4-TUTO : rejouer le guide de première traversée. RÉ-ARME la proposition pour la PROCHAINE
	# run (le guide ne se relance JAMAIS seul en cours de partie). État relu à chaque ouverture.
	_tuto_btn = Button.new()
	_tuto_btn.text = TUTO_BTN_IDLE
	_tuto_btn.custom_minimum_size = Vector2(420, 48)  # ≥44 px (pilier TACTILE)
	_tuto_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tuto_btn.add_theme_font_size_override("font_size", 17)
	MerlinVisual.apply_button_da(_tuto_btn)
	MerlinVisual.connect_button_feedback(_tuto_btn)
	_tuto_btn.pressed.connect(_on_tuto_rearm)
	vbox.add_child(_tuto_btn)

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


# N4-TUTO : clic = ré-armement persisté (MerlinChronicle) + confirmation SUR le bouton (un seul
# endroit, pilier MINIMAL). Redevient cliquable si la proposition a été consommée entre-temps.
func _on_tuto_rearm() -> void:
	MerlinChronicle.rearm_tuto()
	_refresh_tuto_btn()


func _refresh_tuto_btn() -> void:
	if _tuto_btn == null or not is_instance_valid(_tuto_btn):
		return
	var armed: bool = bool(MerlinChronicle.read().get("tuto_rearmed", false))
	_tuto_btn.disabled = armed
	_tuto_btn.text = TUTO_BTN_ARMED if armed else TUTO_BTN_IDLE


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


# P3 (chantier 2) — segmented control : libellé + rangée de boutons dont UN est actif (bordure GOLD
# + fond éclairci). Zéro hover-only (l'état actif est PERSISTANT), cibles ≥44 px (pilier TACTILE).
# get_idx lit la valeur courante ; set_idx la pose (persistance côté appelant). Un refresh local
# rejoue les styles après chaque clic (l'info « quelle option est active » vit à UN endroit : le bouton).
func _segmented_row(label_txt: String, options: Array, get_idx: Callable, set_idx: Callable, parent: Control) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l: Label = Label.new()
	l.text = label_txt
	l.custom_minimum_size = Vector2(280, 0)
	l.add_theme_color_override("font_color", COL_TEXT)
	l.add_theme_font_size_override("font_size", 17)
	row.add_child(l)
	var seg: HBoxContainer = HBoxContainer.new()
	seg.add_theme_constant_override("separation", 8)
	var btns: Array = []
	for i in options.size():
		var b: Button = Button.new()
		b.text = str(options[i])
		b.custom_minimum_size = Vector2(96, 44)  # ≥44 px (pilier TACTILE)
		b.add_theme_font_size_override("font_size", 16)
		MerlinVisual.apply_button_da(b)
		MerlinVisual.connect_button_feedback(b)
		seg.add_child(b)
		btns.append(b)
	var refresh: Callable = func() -> void:
		var cur: int = clampi(int(get_idx.call()), 0, btns.size() - 1)
		for j in btns.size():
			var bb: Button = btns[j]
			var active: bool = j == cur
			# Revue design BLOCKER : override des 4 slots (normal/hover/pressed/focus). Sinon le survol
			# d'une option INACTIVE lui donne l'allure « selectionnee » (apply_button_da met hover=GOLD
			# pour toutes). La selection (bordure GOLD + fond eclairci) devient immunisee au hover ; le
			# seul canal de survol restant est la luminosite x1.06 de connect_button_feedback (dimension
			# distincte, n'imite jamais la selection).
			var box: StyleBoxFlat = MerlinVisual.button_style_hover() if active else MerlinVisual.button_style_normal()
			var fc: Color = COL_TEXT if active else COL_GOLD
			for slot in ["normal", "hover", "pressed", "focus"]:
				bb.add_theme_stylebox_override(slot, box)
			for col_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				bb.add_theme_color_override(col_name, fc)
	for i in options.size():
		(btns[i] as Button).pressed.connect(func() -> void:
			set_idx.call(i)
			refresh.call())
	refresh.call()
	row.add_child(seg)
	parent.add_child(row)


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
