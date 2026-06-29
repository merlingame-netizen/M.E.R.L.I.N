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

const SELECTION_SCENE: String = "res://scenes/MerlinSelection.tscn"
const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"

const THEME_WAV: String = "res://music/theme/merlin_main_theme.wav"
const MUSIC_DB: float = -10.0       # volume cible du thème (ambient discret)
const MUSIC_FADE_IN: float = 3.0    # fondu d'entrée long (ambient)
const MUSIC_FADE_OUT: float = 0.22  # calé sur MerlinTransition.DUR

var _rows: Array[Dictionary] = []  # [{btn, glyph, lbl, disc, icon_box, pop_tw, key}]
var _title: Label
var _tris: MerlinGlyph
var _scene_art: MerlinSceneArt
var _left: VBoxContainer = null  # colonne gauche (pour le slide d'entrée)
var _bottom_bar: HBoxContainer
var _rule_box: HBoxContainer
var _model_lbl: Label = null      # v10.13 (B1) : indicateur d'éveil du modèle (barre du bas)
var _model_pulse_tw: Tween = null # pulse discret pendant le chargement (modulate sine)

# v10.18 — Phase 1 : driver d'ambiance (souffle, parallaxe, aura curseur) + capture dev (env-gated).
var _gust_timer: float = 0.0
var _next_gust: float = 9.0
var _moon_timer: float = 0.0
var _next_moon: float = 14.0
var _parallax_acc: float = 0.0
var _cap_dir: String = ""
var _cap_iv_ms: int = 250
var _cap_max: int = 40
var _cap_count: int = 0
var _cap_last: int = 0
var _cap_boot: int = 0
var _last_focus_box: Control = null  # v10.18 — pour la comète de navigation
var _walk_acc: float = 0.0           # dev : focus-walk pendant la capture
var _walk_idx: int = 0

# v10.19 — VOIX DE MERLIN (user 2026-06-29) : bulles de pensée LLM au-dessus de sa tête.
const HOVER_BTNS: Array = ["CONTINUER", "NOUVELLE PARTIE", "OPTIONS"]
var _voice: MerlinMenuVoice = null
var _bubble: MerlinSpeechBubble = null
var _chron: Dictionary = {}
var _speak_acc: float = 0.0
var _next_speak: float = 3.0         # 1re prise de parole dès qu'une pensée est prête
var _voice_test: bool = false        # dev : MERLIN_VOICE_TEST → bulle factice instantanée (rendu)
var _voice_test_done: bool = false
var _voice_test_acc: float = 0.0
var _autoclick_done: bool = false    # dev : MERLIN_AUTOCLICK → déclenche Nouvelle Partie (capture transition)
var _autoclick_acc: float = 0.0


func _ready() -> void:
	MerlinVisual.load_prefs()  # v10.13.1 — préférences a11y (reduce-motion) chargées dès l'entrée
	_build_ui()
	_setup_music()
	_animate_entrance()
	_start_idle_anims()
	_scene_art.set_mote_density(1.05)  # scène plus subtile (user 2026-06-29) : motes à peine au-dessus du canon
	# Le menu change selon l'heure RÉELLE ; override dev MERLIN_TOD_HOUR pour capturer les 4 variantes.
	var tod_hour: int = int(Time.get_datetime_dict_from_system().get("hour", 21))
	if OS.has_environment("MERLIN_TOD_HOUR"):
		tod_hour = int(OS.get_environment("MERLIN_TOD_HOUR"))
	_scene_art.set_time_of_day(tod_hour)
	_scene_art.set_season(MerlinSceneArt.season_for_now())  # v10.18 : décor saisonnier (cohérent avec le boot)
	_setup_dev_capture()
	_setup_voice()
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


# v10.19 — Voix de Merlin : bulle suivi-tête + ordonnanceur LLM (cède la priorité aux scénarios).
func _setup_voice() -> void:
	_voice_test = OS.has_environment("MERLIN_VOICE_TEST")
	_chron = MerlinChronicle.read()
	MerlinChronicle.touch_seen()  # horodate CETTE visite (après lecture du « depuis la dernière fois »)
	_bubble = MerlinSpeechBubble.new()
	_bubble.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_bubble)  # au-dessus de _scene_art (ajouté après) ; sous d'éventuels modaux
	_voice = MerlinMenuVoice.new()
	add_child(_voice)
	_voice.setup(_voice_prefix(), _build_voice_ctx())
	_voice.start()


# Préfixe voix enrichi par la persona (via l'autoload MerlinScenario), sinon la constante canon.
func _voice_prefix() -> String:
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	if sc != null and sc.has_method("_voice_prefix"):
		return str(sc._voice_prefix())
	return MerlinPromptBuilder.MERLIN_VOICE_PREFIX


func _build_voice_ctx() -> Dictionary:
	var hour: int = int(Time.get_datetime_dict_from_system().get("hour", 21))
	if OS.has_environment("MERLIN_TOD_HOUR"):
		hour = int(OS.get_environment("MERLIN_TOD_HOUR"))
	var ctx: Dictionary = _chron.duplicate()
	ctx["tod"] = _tod_label(hour)
	ctx["saison"] = _saison_label(MerlinSceneArt.season_for_now())
	ctx["hover_buttons"] = HOVER_BTNS
	return ctx


func _tod_label(hour: int) -> String:
	if hour >= 5 and hour < 9:
		return "à l'aube"
	elif hour >= 9 and hour < 17:
		return "en plein jour"
	elif hour >= 17 and hour < 21:
		return "au crépuscule"
	return "dans la nuit"


func _saison_label(key: String) -> String:
	match key:
		"printemps": return "au printemps"
		"ete": return "en été"
		"automne": return "en automne"
		"hiver": return "en hiver"
	return ""


# Position ÉCRAN de la tête de Merlin (lue live dans MerlinSceneArt) pour ancrer la bulle au-dessus.
func _head_screen() -> Dictionary:
	if _scene_art == null or not is_instance_valid(_scene_art):
		return {}
	var h: Vector2 = _scene_art._fig_head
	if h == Vector2.ZERO:
		return {}
	return {"pos": _scene_art.global_position + h, "hr": _scene_art._fig_hr}


func _btn_name_for_key(key: String) -> String:
	match key:
		"spark": return "CONTINUER"
		"burst": return "NOUVELLE PARTIE"
		"target": return "OPTIONS"
	return ""


func _maybe_hover_voice(data: Dictionary) -> void:
	if _voice == null or _bubble == null or _bubble.is_active():
		return
	var btn_name: String = _btn_name_for_key(str(data.get("key", "")))
	if btn_name == "":
		return
	var l: String = _voice.hover_line(btn_name)
	if l != "":
		_bubble.show_line(l, Callable(self, "_head_screen"))


func _exit_tree() -> void:
	if _voice != null:
		_voice.stop()


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
	_left = left

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
	# v10.18 — Halo de focus (derrière le disque, invisible au repos).
	var halo: TextureRect = TextureRect.new()
	halo.texture = _radial_glow_tex()
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.set_anchors_preset(Control.PRESET_FULL_RECT)
	halo.offset_left = -18
	halo.offset_top = -18
	halo.offset_right = 18
	halo.offset_bottom = 18
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.modulate.a = 0.0
	icon_box.add_child(halo)
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

	var data: Dictionary = {"btn": btn, "glyph": g, "lbl": lbl, "disc": disc, "icon_box": icon_box, "key": glyph_key, "halo": halo, "line": line}
	_rows.append(data)
	if enabled:
		if cb.is_valid():
			btn.pressed.connect(cb)
		btn.pressed.connect(_play_press_tick)  # clic audible (feedback net, user 2026-06-29)
		btn.focus_entered.connect(_on_row_focus.bind(data, true))
		btn.focus_exited.connect(_on_row_focus.bind(data, false))
		btn.mouse_entered.connect(btn.grab_focus)  # survol = focus (highlight unifié)
	return btn


# Tick sonore au clic d'une ligne de menu (feedback « net »). Null-safe (MerlinAudio = autoload).
func _play_press_tick() -> void:
	var a: Node = get_node_or_null("/root/MerlinAudio")
	if a != null and a.has_method("play_sfx"):
		a.play_sfx("button_tap", randf_range(0.97, 1.05))


func _on_row_focus(data: Dictionary, on: bool) -> void:
	if on:
		_maybe_hover_voice(data)  # v10.19 : Merlin commente le bouton survolé (si une réplique est prête)
	(data["disc"] as Panel).add_theme_stylebox_override("panel", _disc_style(on))
	(data["glyph"] as MerlinGlyph).setup(str(data["key"]), COL_BG if on else COL_DIM, 1.8)
	(data["lbl"] as Label).add_theme_color_override("font_color", COL_GOLD if on else COL_CREAM)
	MerlinMenuFx.focus_halo(data.get("halo") as CanvasItem, on)
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
		tw.tween_property(box, "scale", Vector2(1.16, 1.16), MerlinVisual.DUR_TAP_DOWN * MerlinVisual.motion()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(box, "scale", Vector2.ONE, MerlinVisual.DUR_TAP_UP * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# v10.18 — charge du trait + comète de navigation depuis la rangée précédente.
		MerlinMenuFx.connector_charge(data.get("line") as ColorRect)
		MerlinMenuFx.comet(_last_focus_box, box, self)
		_last_focus_box = box


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


# v10.18 — Texture radiale dorée pour le halo de focus (or au centre → transparent).
func _radial_glow_tex() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.8))
	g.set_color(1, Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.0))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.width = 96
	t.height = 96
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


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

	# v10.18 (user 2026-06-29) — la couronne devient un VRAI bouton « À PROPOS » (identité/version) ;
	# les ornements sans rôle (compas, œil, points, traits) sont retirés (pilier MINIMAL §23).
	_bottom_bar.add_child(_about_button())

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_bar.add_child(spacer)

	# Indicateur d'éveil du modèle (droite) — « ✦ Merlin s'éveille… » (pulse) puis « ✦ Merlin veille » (or).
	_model_lbl = Label.new()
	_model_lbl.text = "✦ Merlin s'éveille…"
	_model_lbl.add_theme_color_override("font_color", COL_DIM)
	_model_lbl.add_theme_font_size_override("font_size", 18)
	_model_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bottom_bar.add_child(_model_lbl)
	_model_pulse_tw = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_model_pulse_tw.tween_property(_model_lbl, "modulate:a", 0.35, 1.1)
	_model_pulse_tw.tween_property(_model_lbl, "modulate:a", 1.0, 1.1)


# Bouton « À PROPOS » du bandeau bas : couronne + libellé, ouvre une fiche identité/version (vrai bouton).
func _about_button() -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(150, 32)
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, empty)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)
	row.add_child(_icon("crown", COL_GOLD, Vector2(22, 22), 1.6))
	var lbl: Label = Label.new()
	lbl.text = "À PROPOS"
	lbl.add_theme_color_override("font_color", COL_DIM)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	# Feedback survol/focus net : libellé or au survol, retour au repos (≤100ms, pilier ÉVIDENT).
	btn.mouse_entered.connect(func() -> void: btn.grab_focus())
	btn.focus_entered.connect(func() -> void: lbl.add_theme_color_override("font_color", COL_GOLD))
	btn.focus_exited.connect(func() -> void: lbl.add_theme_color_override("font_color", COL_DIM))
	btn.pressed.connect(_show_about)
	return btn


# Fiche « À propos » : identité du jeu + version + pitch. Overlay sobre, clic n'importe où = fermer.
func _show_about() -> void:
	var layer: Control = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	var dim: ColorRect = ColorRect.new()
	dim.color = MerlinVisual.DIM_MODAL
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460, 0)
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = MerlinVisual.SURFACE
	psb.set_corner_radius_all(10)
	psb.set_border_width_all(2)
	psb.border_color = COL_GOLD
	psb.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", psb)
	layer.add_child(panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var lines: Array = [
		["M·E·R·L·I·N", 40, COL_GOLD],
		["Deck-building narratif celtique", 21, COL_CREAM],
		["Brocéliande — un sort, une voie, un prix.", 16, COL_DIM],
		["v10.18 · 100% local · Gemma 4 E2B natif", 15, COL_DIM],
		["", 6, COL_DIM],
		["cliquer pour fermer", 14, COL_DIM],
	]
	for ln in lines:
		var l: Label = Label.new()
		l.text = str(ln[0])
		l.add_theme_font_size_override("font_size", int(ln[1]))
		l.add_theme_color_override("font_color", ln[2] as Color)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	layer.modulate.a = 0.0
	var tw: Tween = layer.create_tween()
	tw.tween_property(layer, "modulate:a", 1.0, MerlinVisual.DUR_VEIL_IN * MerlinVisual.motion())
	layer.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			layer.queue_free())


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
	# v10.18 (user 2026-06-29) — entrée DYNAMIQUE : caméra zoom-settle sur la scène, colonne gauche qui
	# SLIDE depuis la gauche (+ fondus stagger), bandeau bas qui slide-up. Épuré mais vivant.
	# Pré-masque pour éviter le flash avant le calcul de layout (1 frame).
	for n in [_title, _rule_box, _scene_art, _bottom_bar]:
		(n as CanvasItem).modulate.a = 0.0
	for d in _rows:
		(d["btn"] as CanvasItem).modulate.a = 0.0
	await get_tree().process_frame  # tailles/positions des containers calculées

	# Caméra : léger zoom-settle (pull-in) + fondu de la scène (pivot = centre).
	_scene_art.pivot_offset = _scene_art.size * 0.5
	_scene_art.scale = Vector2(1.06, 1.06)
	var cam: Tween = create_tween().set_parallel(true)
	cam.tween_property(_scene_art, "scale", Vector2.ONE, 0.95 * MerlinVisual.motion()).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	cam.tween_property(_scene_art, "modulate:a", 1.0, 0.85 * MerlinVisual.motion())

	# Colonne gauche : SLIDE depuis la gauche (bloc) ; les éléments fondent en stagger par-dessus.
	if _left != null:
		var left_rest: Vector2 = _left.position
		_left.position = left_rest - Vector2(44.0, 0.0)
		create_tween().tween_property(_left, "position", left_rest, 0.55 * MerlinVisual.motion()).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_in(_title, 0.00, 0.45)
	_fade_in(_rule_box, 0.12, 0.40)
	for i in _rows.size():
		_fade_in(_rows[i]["btn"], 0.22 + 0.06 * float(i), 0.36)

	# Bandeau bas : slide-up + fondu (après les boutons).
	var bb_rest: Vector2 = _bottom_bar.position
	_bottom_bar.position = bb_rest + Vector2(0.0, 18.0)
	var bs: Tween = create_tween().set_parallel(true)
	bs.tween_property(_bottom_bar, "position", bb_rest, 0.5 * MerlinVisual.motion()).set_delay(0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bs.tween_property(_bottom_bar, "modulate:a", 1.0, 0.45 * MerlinVisual.motion()).set_delay(0.5)


func _fade_in(node: CanvasItem, delay: float, dur: float) -> void:
	node.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_interval(maxf(delay, 0.001))
	tw.tween_property(node, "modulate:a", 1.0, dur * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Animations d'attente continues : triskèle rotative, runes qui respirent (déphasées),
## titre qui pulse (v10.15 — or lumineux).
func _start_idle_anims() -> void:
	var rot: Tween = create_tween().set_loops()
	rot.tween_property(_tris, "rotation", TAU, 24.0).from(0.0)
	# v10.15 — Title breathing : le wordmark pulse entre crème et or (luminance warm).
	if _title != null and not MerlinVisual.reduced_motion:
		var col_bright: Color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 1.0).lerp(COL_CREAM, 0.5)
		var tb: Tween = create_tween().set_loops()
		var half: float = MerlinVisual.DUR_BREATHE * MerlinVisual.motion()
		tb.tween_property(_title, "modulate", Color(col_bright.r, col_bright.g, col_bright.b, 1.0), half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tb.tween_property(_title, "modulate", Color.WHITE, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# v10.18 — Shimmer ténu sur les rangées désactivées + invitation idle sur la 1re active.
	for d in _rows:
		if (d["btn"] as Button).disabled:
			MerlinMenuFx.locked_shimmer(d.get("disc") as CanvasItem)
	var first_active: Control = null
	for d in _rows:
		if not (d["btn"] as Button).disabled:
			first_active = d.get("icon_box") as Control
			break
	if first_active != null:
		var nudge_t: Tween = create_tween()
		nudge_t.tween_interval(5.0)
		nudge_t.tween_callback(MerlinMenuFx.attention_nudge.bind(first_active))


# ====================== AMBIANCE (Phase 1, v10.18) ======================
## Pilote le décor vivant : souffle de forêt périodique, pulse rare de l'orbe,
## parallaxe + aura de curseur (throttlés 30fps, désactivés en reduced_motion).
func _process(delta: float) -> void:
	if _scene_art == null:
		return
	_gust_timer += delta
	if _gust_timer >= _next_gust:
		_gust_timer = 0.0
		_next_gust = randf_range(9.0, 16.0)
		_scene_art.trigger_gust()
	_moon_timer += delta
	if _moon_timer >= _next_moon:
		_moon_timer = 0.0
		_next_moon = randf_range(12.0, 22.0)
		_scene_art.moon_pulse()
	_parallax_acc += delta
	if _parallax_acc >= 1.0 / 30.0:
		_parallax_acc = 0.0
		_update_parallax_cursor()
	_tick_voice(delta)
	# Dev (MERLIN_AUTOCLICK) : déclenche Nouvelle Partie après ~2s pour capturer la transition zoom-parole.
	if not _autoclick_done and OS.has_environment("MERLIN_AUTOCLICK"):
		_autoclick_acc += delta
		if _autoclick_acc >= 2.0:
			_autoclick_done = true
			_on_new()
	_maybe_capture()
	if not _cap_dir.is_empty():
		_demo_walk(delta)


# Cadence de prise de parole : affiche une pensée prête quand la bulle est libre + le délai écoulé.
func _tick_voice(delta: float) -> void:
	if _bubble == null:
		return
	# Dev (env MERLIN_VOICE_TEST) : bulle factice instantanée pour valider le rendu sans attendre le LLM.
	if _voice_test and not _voice_test_done:
		_voice_test_acc += delta
		if _voice_test_acc >= 1.2:
			_voice_test_done = true
			_bubble.show_line("Ah… te revoilà, Voyageur. La brume gardait ta place au chaud.", Callable(self, "_head_screen"))
		return
	if _voice == null:
		return
	_speak_acc += delta
	if not _bubble.is_active() and _voice.has_ready() and _speak_acc >= _next_speak:
		_speak_acc = 0.0
		_next_speak = randf_range(14.0, 20.0)  # cadence modérée
		_bubble.show_line(_voice.take_thought(), Callable(self, "_head_screen"))


func _update_parallax_cursor() -> void:
	var art_rect: Rect2 = _scene_art.get_global_rect()
	if art_rect.size.x < 4.0 or art_rect.size.y < 4.0:
		return
	var mouse: Vector2 = get_global_mouse_position()
	if not MerlinVisual.reduced_motion:
		var center: Vector2 = art_rect.position + art_rect.size * 0.5
		var norm: Vector2 = (mouse - center) / (art_rect.size * 0.5)
		norm.x = clampf(norm.x, -1.0, 1.0)
		norm.y = clampf(norm.y, -1.0, 1.0)
		_scene_art.set_parallax(norm * 9.0)  # v10.18 : réactivité curseur renforcée (user 2026-06-29)
	var inside: bool = art_rect.has_point(mouse)
	_scene_art.set_cursor(mouse - art_rect.position, inside)


# Capture dev (env-gated MERLIN_CAPTURE_DIR) — jamais active en prod. Motif de l'ancien CaptureRecorder.
func _setup_dev_capture() -> void:
	_cap_dir = OS.get_environment("MERLIN_CAPTURE_DIR")
	if _cap_dir.is_empty():
		return
	var iv: String = OS.get_environment("MERLIN_CAPTURE_INTERVAL_MS")
	if not iv.is_empty() and iv.is_valid_int():
		_cap_iv_ms = maxi(50, int(iv))
	var mx: String = OS.get_environment("MERLIN_CAPTURE_MAX_FRAMES")
	if not mx.is_empty() and mx.is_valid_int():
		_cap_max = maxi(1, int(mx))
	if not DirAccess.dir_exists_absolute(_cap_dir):
		DirAccess.make_dir_recursive_absolute(_cap_dir)
	_cap_last = Time.get_ticks_msec() - _cap_iv_ms


func _maybe_capture() -> void:
	if _cap_dir.is_empty():
		return
	if _cap_boot < 3:
		_cap_boot += 1
		return
	var now: int = Time.get_ticks_msec()
	if now - _cap_last < _cap_iv_ms:
		return
	_cap_last = now
	if _cap_count >= _cap_max:
		return
	var tex: ViewportTexture = get_viewport().get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	if img.get_width() > 640:
		var ratio: float = 640.0 / float(img.get_width())
		img.resize(640, int(float(img.get_height()) * ratio), Image.INTERPOLATE_BILINEAR)
	img.save_png("%s/frame_%04d.png" % [_cap_dir, _cap_count])
	_cap_count += 1


# Dev uniquement (pendant la capture) : promène le focus pour exercer halo/comète/charge.
func _demo_walk(delta: float) -> void:
	_walk_acc += delta
	if _walk_acc < 1.4:
		return
	_walk_acc = 0.0
	for step in _rows.size():
		_walk_idx = (_walk_idx + 1) % _rows.size()
		var b: Button = _rows[_walk_idx]["btn"]
		if not b.disabled:
			b.grab_focus()
			break


# ============================== MUSIQUE ==============================


func _setup_music() -> void:
	if not ResourceLoader.exists(THEME_WAV):
		return
	var stream: AudioStream = load(THEME_WAV)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		if wav.format != AudioStreamWAV.FORMAT_IMA_ADPCM:
			var bytes_per_sample: int = 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var channels: int = 2 if wav.stereo else 1
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.data.size() / float(bytes_per_sample * channels))
	MerlinAudio.play_music(stream, MUSIC_FADE_IN)


# ============================== NAVIGATION ==============================


func _on_new() -> void:
	_confirm_row("burst")
	# v10.19 — transition « zoom vers Merlin qui parle » (réplique pré-fetchée) → sélection.
	var line: String = _depart_line()
	MerlinTransition.change_scene_merlin(SELECTION_SCENE, line)


func _on_continue() -> void:
	var run: Node = get_node("/root/MerlinRun")
	if run.has_save() and run.load_run():
		_confirm_row("spark")
		var line: String = _depart_line()
		MerlinTransition.change_scene_merlin(GAME_SCENE, line)


# Réplique de départ (pré-générée par la voix) + on coupe la voix du menu (single-flight : la scène
# suivante a besoin du moteur, et le menu va être quitté). Filet "" → la transition met sa réplique.
func _depart_line() -> String:
	var line: String = ""
	if _voice != null:
		line = _voice.take_depart()
		_voice.stop()
	return line


# v10.18 — Retour de confirmation (anneau qui s'évase + flash) sur la rangée d'une clé donnée.
func _confirm_row(key: String) -> void:
	for d in _rows:
		if str(d.get("key")) == key:
			MerlinMenuFx.confirm(d.get("lbl") as Label, d.get("icon_box") as Control)
			return


func _on_options() -> void:
	MerlinOptions.toggle()


func _on_quit() -> void:
	get_tree().quit()
