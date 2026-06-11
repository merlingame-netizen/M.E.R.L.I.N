extends Control
## MerlinMenu — écran-titre, DA flat rétro-minimaliste (mockup validé 2026-05-26).
## Gauche : wordmark M·E·R·L·I·N + filet/triskèle + rangée de runes + liste à icônes (focus or).
## Droite : scène en silhouettes (MerlinSceneArt). Coins : émblèmes-anneaux. Bas : barre ornementale.
## Animé (2026-06-10) : entrée en cascade de fondus, triskèle rotative, runes qui respirent,
## anneaux pulsants, scène vivante (brume/étoiles/halo) + thème ambient celtic (MusicGen) en boucle.

const COL_BG: Color = MerlinVisual.BG_PAGE
const COL_CREAM: Color = MerlinVisual.CREAM
const COL_GOLD: Color = MerlinVisual.GOLD
const COL_DIM: Color = MerlinVisual.INK_DIM
const COL_GREEN: Color = MerlinVisual.GREEN
const COL_VIOLET: Color = MerlinVisual.VIOLET

const SELECTION_SCENE: String = "res://scenes/MerlinSelection.tscn"
const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"
const OPTIONS_SCENE: String = "res://scenes/MerlinOptions.tscn"

const THEME_WAV: String = "res://music/theme/merlin_main_theme.wav"
const MUSIC_DB: float = -10.0       # volume cible du thème (ambient discret)
const MUSIC_FADE_IN: float = 3.0    # fondu d'entrée long (ambient)
const MUSIC_FADE_OUT: float = 0.22  # calé sur MerlinTransition.DUR

var _rows: Array[Dictionary] = []  # [{btn, glyph, lbl, disc, icon_box, pop_tw, key}]
var _title: Label
var _tris: MerlinGlyph
var _runes: Array[MerlinGlyph] = []  # rangée décorative
var _rings: Array[MerlinRingGauge] = []  # émblèmes des coins
var _scene_art: MerlinSceneArt
var _bottom_bar: HBoxContainer
var _rule_box: HBoxContainer
var _music: AudioStreamPlayer
var _model_lbl: Label = null      # v10.13 (B1) : indicateur d'éveil du modèle (barre du bas)
var _model_pulse_tw: Tween = null # pulse discret pendant le chargement (modulate sine)


func _ready() -> void:
	_build_ui()
	_setup_music()
	_animate_entrance()
	_start_idle_anims()
	# Le LLM chauffe + pré-génère les 3 scénarios DÈS le menu (avant le clic Nouvelle Partie).
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null:
		if mn.is_ready():
			_trigger_warmup()
		elif not mn.model_ready.is_connected(_trigger_warmup):
			mn.model_ready.connect(_trigger_warmup)
		# v10.13 (B1) : indicateur d'éveil — « Merlin s'éveille… » pulse, flip or sur model_ready.
		if mn.is_ready():
			_set_model_awake()
		elif not mn.model_ready.is_connected(_set_model_awake):
			mn.model_ready.connect(_set_model_awake)


func _trigger_warmup() -> void:
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	if sc != null:
		sc.warmup_and_prefetch_selection()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# --- Scène en silhouettes à droite (~58%) ---
	_scene_art = MerlinSceneArt.new()
	_scene_art.anchor_left = 0.42
	_scene_art.anchor_right = 1.0
	_scene_art.anchor_top = 0.0
	_scene_art.anchor_bottom = 1.0
	_scene_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene_art)
	_scene_art.set_menu_decor(true)
	_scene_art.set_beat("Rencontre")  # figure encapuchonnée devant la lune
	_scene_art.set_animated(true)     # scène vivante : brume qui dérive, étoiles, halo de lune

	# --- Colonne gauche ---
	var left: VBoxContainer = VBoxContainer.new()
	left.anchor_left = 0.0
	left.anchor_top = 0.0
	left.anchor_right = 0.42
	left.anchor_bottom = 1.0
	left.offset_left = 56
	left.offset_top = 64
	left.offset_right = -16
	left.offset_bottom = -70
	left.add_theme_constant_override("separation", 10)
	add_child(left)

	_title = Label.new()
	_title.text = "M·E·R·L·I·N"
	_title.add_theme_color_override("font_color", COL_GOLD)
	_title.add_theme_font_size_override("font_size", 64)
	left.add_child(_title)

	# Filet + triskèle.
	_rule_box = HBoxContainer.new()
	_rule_box.add_theme_constant_override("separation", 8)
	_rule_box.custom_minimum_size = Vector2(0, 22)
	_rule_box.add_child(_hline())
	_tris = _icon("triskele", COL_GOLD, Vector2(22, 22), 1.6)
	_tris.pivot_offset = Vector2(11, 11)  # rotation autour du centre (22x22)
	_rule_box.add_child(_tris)
	_rule_box.add_child(_hline())
	left.add_child(_rule_box)

	# Rangée de runes décoratives.
	var runes: HBoxContainer = HBoxContainer.new()
	runes.add_theme_constant_override("separation", 16)
	for k in ["rune", "triskele", "burst", "spark", "rift"]:
		var rg: MerlinGlyph = _icon(k, COL_DIM, Vector2(20, 22), 1.5)
		_runes.append(rg)
		runes.add_child(rg)
	left.add_child(runes)

	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 22)
	left.add_child(gap)

	# Liste de menu.
	var has_save: bool = get_node("/root/MerlinRun").has_save()
	var menu: VBoxContainer = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 4)
	left.add_child(menu)
	menu.add_child(_menu_row("spark", "CONTINUER", _on_continue, has_save))
	menu.add_child(_menu_row("burst", "NOUVELLE PARTIE", _on_new, true))
	menu.add_child(_menu_row("book", "CHRONIQUES", Callable(), false))
	menu.add_child(_menu_row("cards", "CARTES", Callable(), false))
	menu.add_child(_menu_row("target", "OPTIONS", _on_options, true))
	menu.add_child(_menu_row("cross", "QUITTER", _on_quit, true))

	# Émblèmes des coins (anneaux partiels + glyphe), comme le mockup.
	_corner_emblem("leaf", COL_GREEN, true)
	_corner_emblem("tree", COL_VIOLET, false)

	_build_bottom_bar()

	# Focus initial : CONTINUER si sauvegarde, sinon NOUVELLE PARTIE.
	var first_idx: int = 0 if has_save else 1
	(_rows[first_idx]["btn"] as Button).call_deferred("grab_focus")


func _menu_row(glyph_key: String, label_txt: String, cb: Callable, enabled: bool) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(520, 66)  # ≥44px (tactile) — agrandi (user 2026-06-06)
	btn.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	btn.disabled = not enabled
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, empty)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW

	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	# Icône dans un disque (disque or plein si sélectionné).
	var icon_box: Control = Control.new()
	icon_box.custom_minimum_size = Vector2(52, 52)
	icon_box.pivot_offset = Vector2(26, 26)  # pop de focus centré
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc: Panel = Panel.new()
	disc.set_anchors_preset(Control.PRESET_FULL_RECT)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_theme_stylebox_override("panel", _disc_style(false))
	icon_box.add_child(disc)
	var g: MerlinGlyph = MerlinGlyph.new()
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.offset_left = 9
	g.offset_top = 9
	g.offset_right = -9
	g.offset_bottom = -9
	g.setup(glyph_key, COL_DIM, 1.8)
	icon_box.add_child(g)
	row.add_child(icon_box)

	var lbl: Label = Label.new()
	lbl.text = _spaced(label_txt)
	lbl.add_theme_color_override("font_color", COL_CREAM if enabled else COL_DIM)
	lbl.add_theme_font_size_override("font_size", 27)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var line: ColorRect = _hline()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)
	row.add_child(_diamond())

	var data: Dictionary = {"btn": btn, "glyph": g, "lbl": lbl, "disc": disc, "icon_box": icon_box, "key": glyph_key}
	_rows.append(data)
	if enabled:
		if cb.is_valid():
			btn.pressed.connect(cb)
		btn.focus_entered.connect(_on_row_focus.bind(data, true))
		btn.focus_exited.connect(_on_row_focus.bind(data, false))
		btn.mouse_entered.connect(btn.grab_focus)  # survol = focus (highlight unifié)
	return btn


func _on_row_focus(data: Dictionary, on: bool) -> void:
	(data["disc"] as Panel).add_theme_stylebox_override("panel", _disc_style(on))
	(data["glyph"] as MerlinGlyph).setup(str(data["key"]), COL_BG if on else COL_DIM, 1.8)
	(data["lbl"] as Label).add_theme_color_override("font_color", COL_GOLD if on else COL_CREAM)
	if on:
		# Pop bref du disque (retour visuel ≤100ms — pilier UX §21.1).
		# Tuer le pop précédent encore en vol (navigation clavier rapide) : évite le wobble.
		var prev: Tween = data.get("pop_tw") as Tween
		if prev != null and prev.is_valid():
			prev.kill()
		var box: Control = data["icon_box"]
		box.scale = Vector2.ONE
		var tw: Tween = create_tween()
		data["pop_tw"] = tw
		tw.tween_property(box, "scale", Vector2(1.10, 1.10), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(box, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _disc_style(selected: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_corner_radius_all(20)
	if selected:
		sb.bg_color = COL_GOLD
	else:
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(1)
		sb.border_color = COL_DIM
	return sb


func _corner_emblem(glyph_key: String, col: Color, is_left: bool) -> void:
	var box: Control = Control.new()
	box.custom_minimum_size = Vector2(64, 64)
	box.size = Vector2(64, 64)
	box.anchor_top = 0.0
	box.anchor_bottom = 0.0
	box.offset_top = 22
	box.offset_bottom = 86
	if is_left:
		box.anchor_left = 0.0
		box.anchor_right = 0.0
		box.offset_left = 28
		box.offset_right = 92
	else:
		box.anchor_left = 1.0
		box.anchor_right = 1.0
		box.offset_left = -92
		box.offset_right = -28
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var ring: MerlinRingGauge = MerlinRingGauge.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.setup(col)
	box.add_child(ring)
	ring.set_ratio(0.0)  # balayé 0 → 0.42 par l'animation d'entrée
	_rings.append(ring)
	var g: MerlinGlyph = MerlinGlyph.new()
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.offset_left = 16
	g.offset_top = 16
	g.offset_right = -16
	g.offset_bottom = -16
	g.setup(glyph_key, col, 1.8)
	box.add_child(g)


func _build_bottom_bar() -> void:
	_bottom_bar = HBoxContainer.new()
	_bottom_bar.anchor_left = 0.0
	_bottom_bar.anchor_right = 1.0
	_bottom_bar.anchor_top = 1.0
	_bottom_bar.anchor_bottom = 1.0
	_bottom_bar.offset_left = 36
	_bottom_bar.offset_right = -36
	_bottom_bar.offset_top = -56
	_bottom_bar.offset_bottom = -22
	_bottom_bar.add_theme_constant_override("separation", 14)
	add_child(_bottom_bar)

	_bottom_bar.add_child(_icon("crown", COL_GOLD, Vector2(24, 24), 1.6))
	_bottom_bar.add_child(_dots(3))
	var sp1: Control = Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_bar.add_child(sp1)
	_bottom_bar.add_child(_hline())
	_bottom_bar.add_child(_icon("compass", COL_GOLD, Vector2(28, 28), 1.6))
	_bottom_bar.add_child(_hline())
	var sp2: Control = Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_bar.add_child(sp2)
	# v10.13 (B1) : indicateur d'éveil du modèle — « ✦ Merlin s'éveille… » (pulse discret) tant que
	# le load bloquant tourne, puis « ✦ Merlin veille » (or) sur model_ready (_set_model_awake).
	_model_lbl = Label.new()
	_model_lbl.text = "✦ Merlin s'éveille…"
	_model_lbl.add_theme_color_override("font_color", COL_DIM)
	_model_lbl.add_theme_font_size_override("font_size", 18)
	_model_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bottom_bar.add_child(_model_lbl)
	_model_pulse_tw = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_model_pulse_tw.tween_property(_model_lbl, "modulate:a", 0.35, 1.1)
	_model_pulse_tw.tween_property(_model_lbl, "modulate:a", 1.0, 1.1)
	_bottom_bar.add_child(_dots(3))
	_bottom_bar.add_child(_icon("eye", COL_GOLD, Vector2(24, 24), 1.6))


# v10.13 (B1) : le modèle est chargé — l'indicateur cesse de pulser et passe à l'or « veille ».
func _set_model_awake() -> void:
	if _model_lbl == null:
		return
	if _model_pulse_tw != null and _model_pulse_tw.is_valid():
		_model_pulse_tw.kill()
	_model_pulse_tw = null
	_model_lbl.modulate.a = 1.0
	_model_lbl.text = "✦ Merlin veille"
	_model_lbl.add_theme_color_override("font_color", COL_GOLD)
	# Audit ux_flow M1 (pilier MINIMAL) : la confirmation est vue 2,5s puis s'efface — pas de badge à vie.
	var t: Tween = _model_lbl.create_tween()
	t.tween_interval(2.5)
	t.tween_property(_model_lbl, "modulate:a", 0.0, 0.8)


func _icon(glyph_key: String, col: Color, sz: Vector2, w: float) -> MerlinGlyph:
	var g: MerlinGlyph = MerlinGlyph.new()
	g.custom_minimum_size = sz
	g.setup(glyph_key, col, w)
	return g


func _hline() -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = COL_DIM
	r.custom_minimum_size = Vector2(24, 1)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


func _diamond() -> Control:
	var d: Panel = Panel.new()
	d.custom_minimum_size = Vector2(8, 8)
	d.size = Vector2(8, 8)
	d.pivot_offset = Vector2(4, 4)
	d.rotation = deg_to_rad(45)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_DIM
	d.add_theme_stylebox_override("panel", sb)
	return d


func _dots(n: int) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for i in n:
		var d: Panel = Panel.new()
		d.custom_minimum_size = Vector2(6, 6)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = COL_DIM
		sb.set_corner_radius_all(3)
		d.add_theme_stylebox_override("panel", sb)
		h.add_child(d)
	return h


func _spaced(s: String) -> String:
	var out: String = ""
	for i in s.length():
		out += s[i]
		if i < s.length() - 1:
			out += " "
	return out


# ============================== ANIMATIONS ==============================


## Entrée en cascade : tout démarre invisible puis fond en fondu, du titre vers le bas.
## Fondus uniquement (pas de slides) : robuste aux re-layouts des containers, DA flat.
func _animate_entrance() -> void:
	_fade_in(_title, 0.00, 0.55)
	_fade_in(_rule_box, 0.18, 0.45)
	for i in _runes.size():
		_fade_in(_runes[i], 0.30 + 0.08 * float(i), 0.40)
	for i in _rows.size():
		_fade_in(_rows[i]["btn"], 0.55 + 0.07 * float(i), 0.40)
	_fade_in(_scene_art, 0.10, 0.90)
	_fade_in(_bottom_bar, 1.00, 0.50)
	for i in _rings.size():
		var ring: MerlinRingGauge = _rings[i]
		var emblem: CanvasItem = ring.get_parent() as CanvasItem
		if emblem != null:
			_fade_in(emblem, 0.35 + 0.15 * float(i), 0.45)
		var tw: Tween = create_tween()
		tw.tween_interval(0.45 + 0.15 * float(i))
		tw.tween_method(ring.set_ratio, 0.0, 0.42, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_pulse_ring.bind(ring))


func _fade_in(node: CanvasItem, delay: float, dur: float) -> void:
	node.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_interval(maxf(delay, 0.001))
	tw.tween_property(node, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Animations d'attente continues : triskèle rotative, runes qui respirent (déphasées).
func _start_idle_anims() -> void:
	var rot: Tween = create_tween().set_loops()
	rot.tween_property(_tris, "rotation", TAU, 24.0).from(0.0)
	for i in _runes.size():
		var tw: Tween = create_tween()
		tw.tween_interval(1.2 + 0.45 * float(i))  # déphasage : respiration organique, pas mécanique
		tw.tween_callback(_breathe_glyph.bind(_runes[i]))


func _breathe_glyph(g: MerlinGlyph) -> void:
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(g, "modulate:a", 0.45, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(g, "modulate:a", 1.0, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Pulsation lente de l'anneau d'un émblème de coin (après le balayage d'entrée).
func _pulse_ring(ring: MerlinRingGauge) -> void:
	var tw: Tween = create_tween().set_loops()
	tw.tween_method(ring.set_ratio, 0.42, 0.30, 3.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(ring.set_ratio, 0.30, 0.42, 3.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ============================== MUSIQUE ==============================


## Thème principal ambient celtic (généré par MusicGen — tools/musicgen_theme.py),
## en boucle parfaite (crossfade intégré au WAV) avec long fondu d'entrée.
func _setup_music() -> void:
	if not ResourceLoader.exists(THEME_WAV):
		return  # thème pas encore généré/importé : menu silencieux, pas d'erreur
	var stream: AudioStream = load(THEME_WAV)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		if wav.format == AudioStreamWAV.FORMAT_IMA_ADPCM:
			# Paquets ADPCM à longueur variable : impossible de calculer loop_end en frames.
			push_warning("[MerlinMenu] WAV ADPCM : boucle auto non configurée (réimporter en PCM)")
		else:
			var bytes_per_sample: int = 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var channels: int = 2 if wav.stereo else 1
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.data.size() / float(bytes_per_sample * channels))
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = -38.0
	add_child(_music)
	_music.play()
	var tw: Tween = create_tween()
	tw.tween_property(_music, "volume_db", MUSIC_DB, MUSIC_FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Fondu de sortie calé sur le fondu au noir de MerlinTransition (fire-and-forget).
func _fade_out_music() -> void:
	if _music == null or not _music.playing:
		return
	var tw: Tween = create_tween()
	tw.tween_property(_music, "volume_db", -40.0, MUSIC_FADE_OUT).set_trans(Tween.TRANS_SINE)


# ============================== NAVIGATION ==============================


func _on_new() -> void:
	_fade_out_music()
	MerlinTransition.change_scene(SELECTION_SCENE)


func _on_continue() -> void:
	var run: Node = get_node("/root/MerlinRun")
	if run.has_save() and run.load_run():
		_fade_out_music()
		MerlinTransition.change_scene(GAME_SCENE)


func _on_options() -> void:
	if ResourceLoader.exists(OPTIONS_SCENE):
		_fade_out_music()
		MerlinTransition.change_scene(OPTIONS_SCENE)


func _on_quit() -> void:
	get_tree().quit()
