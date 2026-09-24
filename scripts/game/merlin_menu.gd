extends Control
## MerlinMenu — DA v8 "Seuil entre les mondes" : panneau latéral Claude-style à gauche,
## MerlinSceneArt à droite (~62 %), MerlinOrb coin haut-droit, carte-réponse Merlin bas-droit,
## pilule de biome bas-centre. Entrée en cascade, woodcut boil, voix LLM.

const COL_BG: Color = MerlinVisual.BG_PAGE
const COL_BG_DEEP: Color = MerlinVisual.BG_DEEP
const COL_CREAM: Color = MerlinVisual.CREAM
const COL_GOLD: Color = MerlinVisual.GOLD
const COL_GOLD_D: Color = MerlinVisual.GOLD_DARK
const COL_DIM: Color = MerlinVisual.INK_DIM
const COL_DIM_W: Color = MerlinVisual.DIM_WARM
const COL_INK: Color = MerlinVisual.INK
const COL_GREEN: Color = MerlinVisual.GREEN
const COL_CYAN: Color = MerlinVisual.MACHINE_CYAN
const COL_SURFACE: Color = MerlinVisual.SURFACE

const ORB_SCENE: String = "res://scenes/MerlinOrb.tscn"
const SELECTION_SCENE: String = "res://scenes/MerlinSelection.tscn"
const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"

const THEME_WAV: String = "res://music/theme/merlin_main_theme.wav"
const MUSIC_DB: float = -10.0
const MUSIC_FADE_IN: float = 3.0
const MUSIC_FADE_OUT: float = 0.22

var _rows: Array[Dictionary] = []  # [{btn, glyph, lbl, kbd_lbl, key}]
var _title: Label
var _subtitle: Label
var _tris: MerlinGlyph
var _scene_art: MerlinSceneArt
var _left: VBoxContainer = null       # colonne gauche (panneau Claude-style)
var _panel: PanelContainer = null     # le PanelContainer qui porte le panneau
var _orb: Node = null                 # MerlinOrb (SubViewportContainer)
var _response_card: PanelContainer = null
var _status_dot: ColorRect = null
var _status_lbl: Label = null
var _model_pulse_tw: Tween = null

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
var _last_focus_box: Control = null
var _walk_acc: float = 0.0
var _walk_idx: int = 0

# v10.19 — VOIX DE MERLIN.
const HOVER_BTNS: Array = ["CONTINUER", "NOUVELLE PARTIE", "OPTIONS"]
var _voice: MerlinMenuVoice = null
var _bubble: MerlinSpeechBubble = null
var _chron: Dictionary = {}
var _speak_acc: float = 0.0
var _next_speak: float = 3.0
var _voice_test: bool = false
var _voice_test_done: bool = false
var _voice_test_acc: float = 0.0
var _autoclick_done: bool = false
var _autoclick_acc: float = 0.0

# Typewriter state for response card
var _card_text_full: String = ""
var _card_text_idx: int = 0
var _card_tw_acc: float = 0.0
var _card_typing: bool = false


func _ready() -> void:
	MerlinVisual.load_prefs()
	_build_ui()
	_setup_music()
	_animate_entrance()
	_start_idle_anims()
	_scene_art.set_mote_density(1.05)
	var tod_hour: int = int(Time.get_datetime_dict_from_system().get("hour", 21))
	if OS.has_environment("MERLIN_TOD_HOUR"):
		tod_hour = int(OS.get_environment("MERLIN_TOD_HOUR"))
	_scene_art.set_time_of_day(tod_hour)
	_scene_art.set_season(MerlinSceneArt.season_for_now())
	_setup_dev_capture()
	_setup_voice()
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null:
		if mn.is_ready():
			_set_model_awake()
		elif not mn.model_ready.is_connected(_set_model_awake):
			mn.model_ready.connect(_set_model_awake)


# ============================== VOIX DE MERLIN ==============================


func _setup_voice() -> void:
	_voice_test = OS.has_environment("MERLIN_VOICE_TEST")
	_chron = MerlinChronicle.read()
	MerlinChronicle.touch_seen()
	_bubble = MerlinSpeechBubble.new()
	_bubble.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_bubble)
	_voice = MerlinMenuVoice.new()
	add_child(_voice)
	_voice.setup(_voice_prefix(), _build_voice_ctx())
	_voice.start()


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


func _origine_de_merlin() -> Vector2:
	var h: Dictionary = _head_screen()
	if h.is_empty():
		return Vector2(-1.0, -1.0)
	return h["pos"]


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
		_say(l)


func _exit_tree() -> void:
	if _voice != null:
		_voice.stop()


# ============================== UI (DA v8 — Claude-style panel) ==============================


func _build_ui() -> void:
	# --- Fond page ---
	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# --- Scène en silhouettes à droite (~62 %) ---
	_scene_art = MerlinSceneArt.new()
	_scene_art.anchor_left = 0.38
	_scene_art.anchor_right = 1.0
	_scene_art.anchor_top = 0.0
	_scene_art.anchor_bottom = 1.0
	_scene_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene_art)
	_scene_art.set_menu_decor(true)
	_scene_art.set_beat("Rencontre")
	_scene_art.set_animated(true)
	_scene_art.set_biome("")

	# --- MerlinOrb (petit 128x128, coin haut-droit de la zone scène) ---
	if ResourceLoader.exists(ORB_SCENE):
		var orb_scene: PackedScene = load(ORB_SCENE)
		if orb_scene != null:
			_orb = orb_scene.instantiate()
			_orb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			_orb.offset_left = -160
			_orb.offset_top = 24
			_orb.offset_right = -32
			_orb.offset_bottom = 152
			_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_orb)

	# --- Panneau latéral Claude-style (gauche, ~38 %) ---
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 0.38
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 0
	_panel.offset_top = 0
	_panel.offset_right = 0
	_panel.offset_bottom = 0
	_panel.add_theme_stylebox_override("panel", MerlinClaudeUI.panel_style())
	add_child(_panel)

	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 6)
	_left.set_anchors_preset(Control.PRESET_FULL_RECT)
	_left.offset_left = 36
	_left.offset_top = 48
	_left.offset_right = -20
	_left.offset_bottom = -24
	_panel.add_child(_left)

	# Titre M.E.R.L.I.N en IM Fell, or, breathing
	_title = Label.new()
	_title.text = "M·E·R·L·I·N"
	_title.add_theme_color_override("font_color", COL_GOLD)
	_title.add_theme_font_size_override("font_size", 52)
	var fnt_title: FontFile = _load_claude_font(MerlinVisual.FONT_IM_FELL)
	if fnt_title != null:
		_title.add_theme_font_override("font", fnt_title)
	_left.add_child(_title)

	# Sous-titre en EB Garamond Italic, dim
	_subtitle = Label.new()
	_subtitle.text = "Le seuil entre les mondes"
	_subtitle.add_theme_color_override("font_color", COL_DIM_W)
	_subtitle.add_theme_font_size_override("font_size", 20)
	var fnt_sub: FontFile = _load_claude_font(MerlinVisual.FONT_EB_GARAMOND_ITALIC)
	if fnt_sub != null:
		_subtitle.add_theme_font_override("font", fnt_sub)
	_left.add_child(_subtitle)

	# Filet + triskele
	var rule_box: HBoxContainer = HBoxContainer.new()
	rule_box.add_theme_constant_override("separation", 8)
	rule_box.custom_minimum_size = Vector2(0, 18)
	rule_box.add_child(_hline())
	_tris = _icon("triskele", COL_GOLD, Vector2(18, 18), 1.4)
	_tris.pivot_offset = Vector2(9, 9)
	rule_box.add_child(_tris)
	rule_box.add_child(_hline())
	_left.add_child(rule_box)

	# Fragments du Graal preamble
	var frag_n: int = int(MerlinChronicle.read().get("graal_fragments", 0))
	if frag_n > 0:
		var pre: Label = Label.new()
		pre.text = _fragments_preamble(frag_n)
		pre.add_theme_color_override("font_color", COL_DIM)
		pre.add_theme_font_size_override("font_size", 15)
		pre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_left.add_child(pre)

	var gap1: Control = Control.new()
	gap1.custom_minimum_size = Vector2(0, 10)
	_left.add_child(gap1)

	# --- Menu rows Claude-style ---
	var has_save: bool = get_node("/root/MerlinRun").has_save()
	var menu: VBoxContainer = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 2)
	_left.add_child(menu)
	menu.add_child(_menu_row("burst", "Nouveau récit", "N", _on_new, true))
	menu.add_child(_menu_row("spark", "Reprendre", "R", _on_continue, has_save))
	menu.add_child(_menu_row("cards", "Sentiers", "S", _on_sentiers, not MerlinSentier.liste().is_empty()))
	menu.add_child(_menu_row("book", "Chroniques", "C", _on_chronicles, true))
	menu.add_child(_menu_row("target", "Options", ",", _on_options, true))

	# --- Recents ---
	_build_recents()

	# --- Spacer ---
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left.add_child(spacer)

	# --- Status bar (Gemma 4 . local . pret) ---
	_build_status_bar()

	# Separator before quit
	_left.add_child(_hline())

	# Quitter
	var quit_box: VBoxContainer = VBoxContainer.new()
	quit_box.add_theme_constant_override("separation", 0)
	quit_box.add_child(_menu_row("cross", "Quitter", "Q", _on_quit, true))
	_left.add_child(quit_box)

	# --- Carte-reponse Merlin (bas-droit) ---
	_response_card = MerlinClaudeUI.make_response_card()
	_response_card.anchor_left = 0.52
	_response_card.anchor_right = 0.96
	_response_card.anchor_top = 1.0
	_response_card.anchor_bottom = 1.0
	_response_card.offset_top = -180
	_response_card.offset_bottom = -24
	_response_card.offset_left = 0
	_response_card.offset_right = 0
	_response_card.visible = false
	_response_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_response_card)

	# Focus initial : Reprendre si sauvegarde, sinon Nouveau recit
	var first_idx: int = 1 if has_save else 0
	if first_idx < _rows.size():
		(_rows[first_idx]["btn"] as Button).call_deferred("grab_focus")


func _menu_row(glyph_key: String, label_txt: String, kbd_hint: String, cb: Callable, enabled: bool) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	btn.disabled = not enabled
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, empty)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW

	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn.add_child(row)

	# MerlinGlyph icon (24x24)
	var g: MerlinGlyph = MerlinGlyph.new()
	g.custom_minimum_size = Vector2(24, 24)
	g.setup(glyph_key, COL_DIM_W if enabled else COL_DIM, 1.8)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(g)

	# Label (DM Sans)
	var lbl: Label = Label.new()
	lbl.text = label_txt
	lbl.add_theme_color_override("font_color", COL_CREAM if enabled else COL_DIM)
	lbl.add_theme_font_size_override("font_size", MerlinVisual.FS_BTN)
	var fnt_ui: FontFile = _load_claude_font(MerlinVisual.FONT_DM_SANS)
	if fnt_ui != null:
		lbl.add_theme_font_override("font", fnt_ui)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	# Spacer
	var sp: Control = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)

	# Kbd hint (hidden by default, shown on hover/focus)
	var kbd_lbl: Label = Label.new()
	kbd_lbl.text = kbd_hint
	kbd_lbl.add_theme_color_override("font_color", COL_DIM)
	kbd_lbl.add_theme_font_size_override("font_size", MerlinVisual.FS_HINT)
	var fnt_kbd: FontFile = _load_claude_font(MerlinVisual.FONT_DM_SANS)
	if fnt_kbd != null:
		kbd_lbl.add_theme_font_override("font", fnt_kbd)
	kbd_lbl.modulate.a = 0.0
	kbd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(kbd_lbl)

	var data: Dictionary = {"btn": btn, "glyph": g, "lbl": lbl, "kbd_lbl": kbd_lbl, "key": glyph_key}
	_rows.append(data)
	if enabled:
		if cb.is_valid():
			btn.pressed.connect(cb)
		btn.pressed.connect(_play_press_tick)
		btn.focus_entered.connect(_on_row_focus.bind(data, true))
		btn.focus_exited.connect(_on_row_focus.bind(data, false))
		btn.mouse_entered.connect(btn.grab_focus)
	return btn


func _play_press_tick() -> void:
	var a: Node = get_node_or_null("/root/MerlinAudio")
	if a != null and a.has_method("play_sfx"):
		a.play_sfx("button_tap", randf_range(0.97, 1.05))


func _on_row_focus(data: Dictionary, on: bool) -> void:
	if on:
		_maybe_hover_voice(data)
	var g: MerlinGlyph = data["glyph"] as MerlinGlyph
	var lbl: Label = data["lbl"] as Label
	var kbd: Label = data["kbd_lbl"] as Label
	if on:
		g.setup(str(data["key"]), COL_GOLD, 1.8)
		lbl.add_theme_color_override("font_color", COL_GOLD)
		# Kbd hint fade in
		var tw_k: Tween = create_tween()
		tw_k.tween_property(kbd, "modulate:a", 1.0, 0.15 * MerlinVisual.motion())
		# Subtle scale feedback
		var btn_ctrl: Button = data["btn"] as Button
		btn_ctrl.pivot_offset = btn_ctrl.size * 0.5
		var tw_s: Tween = create_tween()
		tw_s.tween_property(btn_ctrl, "scale", Vector2(0.985, 0.985), MerlinVisual.DUR_TAP_DOWN * MerlinVisual.motion()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_s.tween_property(btn_ctrl, "scale", Vector2.ONE, MerlinVisual.DUR_TAP_UP * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_last_focus_box = btn_ctrl
	else:
		var btn_d: Button = data["btn"] as Button
		var is_enabled: bool = not btn_d.disabled
		g.setup(str(data["key"]), COL_DIM_W if is_enabled else COL_DIM, 1.8)
		lbl.add_theme_color_override("font_color", COL_CREAM if is_enabled else COL_DIM)
		var tw_ko: Tween = create_tween()
		tw_ko.tween_property(kbd, "modulate:a", 0.0, 0.15 * MerlinVisual.motion())


func _load_claude_font(path: String) -> FontFile:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is FontFile:
			return res as FontFile
	return null


func _build_recents() -> void:
	var pages: Array = MerlinJournal.liste()
	if pages.is_empty():
		return
	var section_gap: Control = Control.new()
	section_gap.custom_minimum_size = Vector2(0, 8)
	_left.add_child(section_gap)
	_left.add_child(MerlinClaudeUI.make_section_title("Récents"))
	var count: int = mini(3, pages.size())
	for i in count:
		var pg: Dictionary = pages[i] as Dictionary
		var titre: String = str(pg.get("titre", ""))
		if titre == "":
			titre = "Traversée sans titre"
		var date_str: String = _chro_date(str(pg.get("iso", "")))
		var row: PanelContainer = MerlinClaudeUI.make_list_row(
			titre.substr(0, 30),
			"%s · %d beats" % [date_str, int(pg.get("beats", 0))],
			"",
			"✦"
		)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_left.add_child(row)


func _build_status_bar() -> void:
	var mn: Node = get_node_or_null("/root/MerlinNative")
	var is_ready: bool = mn != null and mn.is_ready()
	var status_text: String = "prêt" if is_ready else "s'éveille…"
	var hb: HBoxContainer = MerlinClaudeUI.make_status_bar("Gemma 4", "local · " + status_text, is_ready)
	_left.add_child(hb)
	# Find the dot and label children via meta for later update
	for ch in hb.get_children():
		if ch is ColorRect and ch.has_meta("_status_dot"):
			_status_dot = ch as ColorRect
		if ch is Label and ch.has_meta("_status_label"):
			_status_lbl = ch as Label
	# Pulse animation if not ready
	if not is_ready and _status_lbl != null:
		_model_pulse_tw = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_model_pulse_tw.tween_property(_status_lbl, "modulate:a", 0.35, 1.1)
		_model_pulse_tw.tween_property(_status_lbl, "modulate:a", 1.0, 1.1)


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
		["Brocéliande : un sort, une voie, un prix.", 16, COL_DIM],
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


func _set_model_awake() -> void:
	if _model_pulse_tw != null and _model_pulse_tw.is_valid():
		_model_pulse_tw.kill()
	_model_pulse_tw = null
	if _status_dot != null:
		_status_dot.color = COL_GREEN
	if _status_lbl != null:
		_status_lbl.modulate.a = 1.0
		_status_lbl.text = "Gemma 4 · local · prêt"
		_status_lbl.add_theme_color_override("font_color", COL_DIM_W)
		var t: Tween = _status_lbl.create_tween()
		t.tween_interval(2.5)
		t.tween_property(_status_lbl, "modulate:a", 0.6, 0.8)


# ============================== SMALL HELPERS ==============================


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


func _animate_entrance() -> void:
	# Pre-mask everything for the cascade
	var to_mask: Array = [_title, _subtitle, _scene_art]
	if _panel != null:
		to_mask.append(_panel)
	if _response_card != null:
		to_mask.append(_response_card)
	if _orb != null:
		to_mask.append(_orb as CanvasItem)
	for n in to_mask:
		if n != null and n is CanvasItem:
			(n as CanvasItem).modulate.a = 0.0
	for d in _rows:
		(d["btn"] as CanvasItem).modulate.a = 0.0
	await get_tree().process_frame

	# Camera: slight zoom-settle on the scene art
	_scene_art.pivot_offset = _scene_art.size * 0.5
	_scene_art.scale = Vector2(1.06, 1.06)
	var cam: Tween = create_tween().set_parallel(true)
	cam.tween_property(_scene_art, "scale", Vector2.ONE, 0.95 * MerlinVisual.motion()).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	cam.tween_property(_scene_art, "modulate:a", 1.0, 0.85 * MerlinVisual.motion())

	# Panel slide-in from left + fade
	if _panel != null:
		var panel_rest: Vector2 = _panel.position
		_panel.position = panel_rest - Vector2(50.0, 0.0)
		var ptw: Tween = create_tween().set_parallel(true)
		ptw.tween_property(_panel, "position", panel_rest, 0.55 * MerlinVisual.motion()).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ptw.tween_property(_panel, "modulate:a", 1.0, 0.50 * MerlinVisual.motion())

	# Title and subtitle stagger
	_fade_in(_title, 0.05, 0.45)
	_fade_in(_subtitle, 0.15, 0.40)

	# Menu rows stagger
	for i in _rows.size():
		_fade_in(_rows[i]["btn"], 0.25 + 0.06 * float(i), 0.36)

	# Orb
	if _orb != null:
		_fade_in(_orb as CanvasItem, 0.6, 0.5)


func _fade_in(node: CanvasItem, delay: float, dur: float) -> void:
	node.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_interval(maxf(delay, 0.001))
	tw.tween_property(node, "modulate:a", 1.0, dur * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _start_idle_anims() -> void:
	# Triskele rotation
	var rot: Tween = create_tween().set_loops()
	rot.tween_property(_tris, "rotation", TAU, 24.0).from(0.0)
	# Title breathing: gold luminance pulse
	if _title != null and not MerlinVisual.reduced_motion:
		var col_bright: Color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 1.0).lerp(COL_CREAM, 0.5)
		var tb: Tween = create_tween().set_loops()
		var half: float = MerlinVisual.DUR_BREATHE * MerlinVisual.motion()
		tb.tween_property(_title, "modulate", Color(col_bright.r, col_bright.g, col_bright.b, 1.0), half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tb.tween_property(_title, "modulate", Color.WHITE, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Locked shimmer on disabled rows + attention nudge on first active
	for d in _rows:
		if (d["btn"] as Button).disabled:
			MerlinMenuFx.locked_shimmer(d.get("glyph") as CanvasItem)
	var first_active: Control = null
	for d in _rows:
		if not (d["btn"] as Button).disabled:
			first_active = d.get("btn") as Control
			break
	if first_active != null:
		var nudge_t: Tween = create_tween()
		nudge_t.tween_interval(5.0)
		nudge_t.tween_callback(MerlinMenuFx.attention_nudge.bind(first_active))


# ====================== AMBIANCE (Phase 1, v10.18) ======================


func _process(delta: float) -> void:
	# Woodcut boil tick
	MerlinWoodcut.tick_boil(delta)

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
	# Response card typewriter tick
	if _card_typing and _response_card != null and _response_card.visible:
		_card_tw_acc += delta
		if _card_tw_acc >= 0.03:
			_card_tw_acc = 0.0
			if _card_text_idx < _card_text_full.length():
				_card_text_idx += 1
				var body_node: RichTextLabel = _find_card_body()
				if body_node != null:
					body_node.text = _card_text_full.substr(0, _card_text_idx)
			else:
				_card_typing = false
	# Dev environment overrides
	if _scene_art != null and OS.has_environment("MERLIN_EYE_MOOD"):
		_scene_art.set_eye_mood(OS.get_environment("MERLIN_EYE_MOOD"))
	if not _autoclick_done and OS.has_environment("MERLIN_AUTOCLICK"):
		_autoclick_acc += delta
		if _autoclick_acc >= 2.0:
			_autoclick_done = true
			_on_new()
	_maybe_capture()
	if not _cap_dir.is_empty():
		_demo_walk(delta)


func _find_card_body() -> RichTextLabel:
	if _response_card == null:
		return null
	# Traverse the card looking for the _card_body meta
	return _find_meta_child(_response_card, "_card_body") as RichTextLabel


func _find_meta_child(node: Node, meta_key: String) -> Node:
	if node.has_meta(meta_key):
		return node
	for ch in node.get_children():
		var found: Node = _find_meta_child(ch, meta_key)
		if found != null:
			return found
	return null


func _tick_voice(delta: float) -> void:
	if _bubble == null:
		return
	if _voice_test and not _voice_test_done:
		_voice_test_acc += delta
		if _voice_test_acc >= 1.2:
			_voice_test_done = true
			_say("Ah… te revoilà, Voyageur ? La brume gardait ta place au chaud.")
		return
	if _voice == null:
		return
	_speak_acc += delta
	if not _bubble.is_active() and _voice.has_ready() and _speak_acc >= _next_speak:
		_speak_acc = 0.0
		_next_speak = randf_range(14.0, 20.0)
		_say(_voice.take_thought())


func _say(line: String) -> void:
	if line.strip_edges().is_empty():
		return
	var mood: String = MerlinSceneArt.mood_for_text(line)
	if _scene_art != null:
		_scene_art.set_eye_mood(mood)
		_scene_art.set_posture("pensee", 4.0)
	_bubble.show_line(line, Callable(self, "_head_screen"), mood, true)
	# Populate response card with typewriter effect
	if _response_card != null:
		_response_card.visible = true
		_response_card.modulate.a = 0.0
		var tw_card: Tween = create_tween()
		tw_card.tween_property(_response_card, "modulate:a", 1.0, 0.25 * MerlinVisual.motion())
		_card_text_full = line
		_card_text_idx = 0
		_card_tw_acc = 0.0
		_card_typing = true
		var body_node: RichTextLabel = _find_card_body()
		if body_node != null:
			body_node.text = ""


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
		_scene_art.set_parallax(norm * 9.0)
	var inside: bool = art_rect.has_point(mouse)
	_scene_art.set_cursor(mouse - art_rect.position, inside)


# ============================== DEV CAPTURE ==============================


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
	_show_biome_choice()


var _biome_layer: Control = null


func _show_biome_choice() -> void:
	if _biome_layer != null:
		return
	_biome_layer = Control.new()
	_biome_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_biome_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_biome_layer)
	var dim: ColorRect = ColorRect.new()
	dim.color = MerlinVisual.DIM_LIGHT
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_biome_layer.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_biome_layer.add_child(center)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	center.add_child(col)
	var title_l: Label = Label.new()
	title_l.text = "Où le chemin commence-t-il ?"
	title_l.add_theme_color_override("font_color", MerlinVisual.GOLD)
	title_l.add_theme_font_size_override("font_size", 30)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title_l)
	col.add_child(MerlinOrnament.triskele_rule(16.0))

	# 8 biomes in a 4x2 grid of menhir-style cards
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	col.add_child(grid)

	var biome_count: int = MerlinVisual.BIOME_IDS.size()
	for bi in biome_count:
		var bio_id: String = str(MerlinVisual.BIOME_IDS[bi])
		var bio_name: String = str(MerlinVisual.BIOME_NAMES[bi])
		var bio_col: Color = MerlinVisual.BIOME_COLORS[bi] as Color
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(200, 120)
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sb2: StyleBoxFlat = StyleBoxFlat.new()
		sb2.bg_color = MerlinVisual.SURFACE
		sb2.set_border_width_all(2)
		sb2.border_color = bio_col
		sb2.set_corner_radius_all(8)
		sb2.set_content_margin_all(14)
		card.add_theme_stylebox_override("panel", sb2)
		var cv2: VBoxContainer = VBoxContainer.new()
		cv2.add_theme_constant_override("separation", 8)
		card.add_child(cv2)
		# Menhir accent bar at top
		var accent: ColorRect = ColorRect.new()
		accent.custom_minimum_size = Vector2(40, 3)
		accent.color = bio_col
		cv2.add_child(accent)
		var ct: Label = Label.new()
		ct.text = bio_name
		ct.add_theme_color_override("font_color", bio_col)
		ct.add_theme_font_size_override("font_size", 20)
		ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ct.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv2.add_child(ct)
		var cb: Button = Button.new()
		cb.text = "Entrer"
		cb.custom_minimum_size = Vector2(0, 40)
		cb.add_theme_font_size_override("font_size", 17)
		MerlinVisual.apply_button_da(cb)
		cb.pressed.connect(_on_biome_picked.bind(bio_id))
		MerlinVisual.connect_button_feedback(cb)
		cv2.add_child(cb)
		grid.add_child(card)
	_biome_layer.modulate.a = 0.0
	_biome_layer.create_tween().tween_property(_biome_layer, "modulate:a", 1.0, 0.30 * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)


func _on_biome_picked(bio: String) -> void:
	if _biome_layer == null:
		return
	var layer: Control = _biome_layer
	_biome_layer = null
	var run: Node = get_node("/root/MerlinRun")
	run.biome = bio
	_stop_voice()
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	if sc != null and sc.has_method("invalidate_selection"):
		sc.invalidate_selection()
		if sc.has_method("warmup_and_prefetch_selection"):
			sc.warmup_and_prefetch_selection()
	var m: float = MerlinVisual.motion()
	var out_tw: Tween = layer.create_tween()
	out_tw.tween_property(layer, "modulate:a", 0.0, 0.25 * m).set_trans(Tween.TRANS_SINE)
	out_tw.tween_callback(layer.queue_free)
	if _scene_art != null:
		_scene_art.set_biome(bio)
		_scene_art.set_decor_reveal(0.0)
		var pop: Tween = create_tween()
		pop.tween_method(_scene_art.set_decor_reveal, 0.0, 1.0, 2.0 * m).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop.tween_callback(_scene_art.trigger_gust)
		pop.tween_callback(_scene_art.flash_moon)
		pop.tween_interval(0.5 * m)
		pop.tween_callback(func() -> void:
			_stop_voice()
			MerlinTransition.change_scene(SELECTION_SCENE, "", "depuis", _origine_de_merlin()))
	else:
		_stop_voice()
		MerlinTransition.change_scene(SELECTION_SCENE, "", "depuis", _origine_de_merlin())


func _on_continue() -> void:
	var run: Node = get_node("/root/MerlinRun")
	if run.has_save() and run.load_run():
		_confirm_row("spark")
		_stop_voice()
		MerlinTransition.change_scene(GAME_SCENE, "", "haut")


func _stop_voice() -> void:
	if _voice != null:
		_voice.stop()


func _confirm_row(key: String) -> void:
	for d in _rows:
		if str(d.get("key")) == key:
			MerlinMenuFx.confirm(d.get("lbl") as Label, d.get("btn") as Control)
			return


func _on_options() -> void:
	MerlinOptions.toggle()


func _on_quit() -> void:
	get_tree().quit()


# ============================== SENTIERS ==============================


func _on_sentiers() -> void:
	if get_node_or_null("SentiersOverlay") != null:
		return  # garde de ré-entrance (pas d'empilement de voiles)
	var layer: Control = Control.new()
	layer.name = "SentiersOverlay"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	var dim: ColorRect = ColorRect.new()
	dim.color = MerlinVisual.DIM_MODAL
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	# SEUL LE FOND FERME : le panneau porte des lignes cliquables.
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			layer.queue_free())
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panneau"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 540)
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = MerlinVisual.PANEL
	psb.border_color = MerlinVisual.BORDER_BRUN
	psb.set_border_width_all(2)
	psb.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", psb)
	layer.add_child(panel)
	_sentiers_liste(panel, layer)


func _sentiers_liste(panel: PanelContainer, layer: Control) -> void:
	_vider(panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(_chro_ligne("SENTIERS", 34, COL_GOLD))
	v.add_child(_chro_ligne("Des traversées écrites à la main. La prose y est déjà posée : "
		+ "rien à attendre, et le dé décide comme partout ailleurs.", 16, COL_DIM))
	v.add_child(HSeparator.new())
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	v.add_child(scroll)
	var liste: VBoxContainer = VBoxContainer.new()
	liste.add_theme_constant_override("separation", 12)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(liste)
	for cle in MerlinSentier.liste():
		var r: Dictionary = MerlinSentier.resume(str(cle))
		if r.is_empty():
			continue  # un sentier illisible ne s'affiche pas : on ne propose pas ce qu'on ne peut pas jouer
		liste.add_child(_sentier_ligne(r, layer))
	v.add_child(HSeparator.new())
	v.add_child(_chro_bouton("← Retour", func() -> void: layer.queue_free()))


func _sentier_ligne(r: Dictionary, layer: Control) -> Control:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(0, 86)   # cible tactile >= 44 px
	b.flat = true
	b.clip_contents = true
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func() -> void: _lancer_le_sentier(str(r.get("cle", "")), layer))
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var titre: Label = MerlinVisual.make_label(COL_GOLD, 20)
	titre.text = "%s  ·  %s  ·  %d beats" % [str(r.get("titre", "")), str(r.get("biome_nom", "")),
		int(r.get("beats", 0))]
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(titre)
	var ouverture: Label = MerlinVisual.make_label(COL_DIM, 15)
	ouverture.text = str(r.get("ouverture", ""))
	ouverture.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ouverture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(ouverture)
	return b


func _lancer_le_sentier(cle: String, layer: Control) -> void:
	var s: Dictionary = MerlinSentier.charger(cle)
	if s.is_empty():
		return  # illisible
	var run: Node = get_node("/root/MerlinRun")
	run.biome = str(s.get("biome", run.biome))
	run.new_run(s)
	layer.queue_free()
	_stop_voice()
	MerlinTransition.change_scene(GAME_SCENE, "", "haut")


# ============================== CHRONIQUES ==============================


func _on_chronicles() -> void:
	if get_node_or_null("ChroniclesOverlay") != null:
		return  # garde de ré-entrance (pas d'empilement de voiles)
	var layer: Control = Control.new()
	layer.name = "ChroniclesOverlay"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	var dim: ColorRect = ColorRect.new()
	dim.color = MerlinVisual.DIM_MODAL
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			layer.queue_free())
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panneau"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720, 520)
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = MerlinVisual.SURFACE
	psb.set_corner_radius_all(10)
	psb.set_border_width_all(2)
	psb.border_color = COL_GOLD
	psb.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", psb)
	layer.add_child(panel)
	_chroniques_liste(panel)
	layer.modulate.a = 0.0
	var tw: Tween = layer.create_tween()
	tw.tween_property(layer, "modulate:a", 1.0, MerlinVisual.DUR_VEIL_IN * MerlinVisual.motion())


func _chroniques_liste(panel: PanelContainer) -> void:
	_vider(panel)
	var c: Dictionary = MerlinChronicle.read()
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(_chro_ligne("CHRONIQUES", 34, COL_GOLD))
	var runs: int = int(c.get("runs_played", 0))
	if runs > 0:
		v.add_child(_chro_ligne("Traversées : %d  ·  Accomplies %d  ·  Perdues %d  ·  Corrompues %d"
			% [runs, int(c.get("wins", 0)), int(c.get("deaths", 0)), int(c.get("corrupted", 0))],
			17, COL_DIM))
	v.add_child(_chro_ligne("✦ Fragments du Graal : %d / %d"
		% [int(c.get("graal_fragments", 0)), MerlinChronicle.GRAAL_TOTAL], 19, COL_GOLD))
	v.add_child(HSeparator.new())

	var pages: Array = MerlinJournal.liste()
	if pages.is_empty():
		v.add_child(_chro_ligne("Aucune traversée enregistrée pour l'instant.", 18, COL_CREAM))
		v.add_child(_chro_ligne("Le journal note chaque traversée à partir de maintenant ; "
			+ "celles d'avant n'ont pas été gardées.", 15, COL_DIM))
	else:
		v.add_child(_chro_ligne("%d traversée(s) gardée(s) — la plus récente en tête."
			% pages.size(), 15, COL_DIM))
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(660, 330)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		v.add_child(scroll)
		var col: VBoxContainer = VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(col)
		for pg in pages:
			col.add_child(_chro_rangee(pg as Dictionary, panel))
	v.add_child(_chro_ligne("cliquer hors du cadre pour fermer", 13, COL_DIM))


func _chro_rangee(pg: Dictionary, panel: PanelContainer) -> Control:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(0, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.add_theme_color_override("font_color", COL_CREAM)
	b.add_theme_color_override("font_hover_color", COL_GOLD)
	b.add_theme_font_size_override("font_size", 16)
	var titre: String = str(pg.get("titre", ""))
	if titre == "":
		titre = "Traversée sans titre"
	b.text = "%s   %s   ·   %d beats · %s · %d signes" % [
		_chro_date(str(pg.get("iso", ""))), titre.substr(0, 34),
		int(pg.get("beats", 0)), _chro_fin(str(pg.get("fin", ""))), int(pg.get("signes", 0))]
	var id: String = str(pg.get("id", ""))
	b.pressed.connect(func() -> void: _chroniques_detail(panel, id))
	return b


func _chroniques_detail(panel: PanelContainer, id: String) -> void:
	var q: Dictionary = MerlinJournal.lire(id)
	_vider(panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	if q.is_empty():
		v.add_child(_chro_ligne("Cette chronique est illisible.", 20, COL_GOLD))
		v.add_child(_chro_bouton("← retour", func() -> void: _chroniques_liste(panel)))
		return
	var fin: Dictionary = q.get("fin", {}) as Dictionary
	var titre: String = str(q.get("titre", ""))
	v.add_child(_chro_ligne(titre if titre != "" else "Traversée", 26, COL_GOLD))
	v.add_child(_chro_ligne("%s  ·  %s  ·  intégrité %d  ·  corruption %d" % [
		_chro_date(str(q.get("debut_iso", ""))), _chro_fin(str(fin.get("type", ""))),
		int(fin.get("integrite", 0)), int(fin.get("corruption", 0))], 15, COL_DIM))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(660, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	for bt in (q.get("beats", []) as Array):
		var d: Dictionary = bt as Dictionary
		var tete: String = "beat %d · %s" % [int(d.get("n", 0)), str(d.get("type", ""))]
		if str(d.get("degre", "")) != "":
			tete += " · %s" % str(d.get("degre", ""))
		if str(d.get("action", "")) != "":
			tete += " · %s avec %s" % [str(d.get("action", "")), str(d.get("trait", ""))]
		col.add_child(_chro_ligne(tete, 14, COL_GOLD))
		col.add_child(_chro_prose(str(d.get("scene", "")), COL_CREAM))
		if str(d.get("issue", "")) != "":
			col.add_child(_chro_prose(str(d.get("issue", "")), COL_DIM))
	v.add_child(_chro_bouton("← retour à la liste", func() -> void: _chroniques_liste(panel)))


func _chro_ligne(txt: String, taille: int, coul: Color) -> Label:
	var l: Label = Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", coul)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _chro_prose(txt: String, coul: Color) -> RichTextLabel:
	var r: RichTextLabel = RichTextLabel.new()
	r.bbcode_enabled = true
	r.text = txt
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", 16)
	r.add_theme_color_override("default_color", coul)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


func _chro_bouton(txt: String, quoi: Callable) -> Button:
	var b: Button = Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 44)
	b.flat = true
	b.add_theme_color_override("font_color", COL_GOLD)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(quoi)
	return b


func _vider(n: Node) -> void:
	for e in n.get_children():
		n.remove_child(e)
		e.queue_free()


func _chro_date(iso: String) -> String:
	if iso.length() < 16:
		return iso
	return "%s/%s %s" % [iso.substr(8, 2), iso.substr(5, 2), iso.substr(11, 5)]


func _chro_fin(t: String) -> String:
	match t:
		"accomplissement":
			return "accomplie"
		"mort":
			return "perdue"
		"corrompu":
			return "corrompue"
		"":
			return "interrompue"
		_:
			return t


func _fragments_preamble(n: int) -> String:
	if n <= 0:
		return ""
	var words: Array = ["", "un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf", "dix", "onze", "douze"]
	var num: String = str(words[n]) if n < words.size() else str(n)
	var noun: String = "éclat déjà arraché" if n == 1 else "éclats déjà arrachés"
	var line: String = "%s %s à la brume." % [num, noun]
	return line.substr(0, 1).to_upper() + line.substr(1)
