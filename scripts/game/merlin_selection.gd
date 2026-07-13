extends Control
## MerlinSelection — écran de sélection (bible R56). Merlin propose 3 sentiers (titre + pitch),
## le joueur en CHOISIT un MANUELLEMENT → montage (squelette + arc) → scène de jeu.
## v10.19 (user 2026-06-29) : les 3 TITRES sont FORCÉMENT LLM — montage « Merlin rêve les sentiers »
## ultra-animé tant qu'ils ne sont pas prêts (filet ~75 s + skip après 20 s). Le pick lance la
## transition « zoom vers Merlin qui parle » (montage du scénario).

const COL_BG: Color = MerlinVisual.BG_DEEP
const COL_SURFACE: Color = MerlinVisual.SURFACE
const COL_TEXT: Color = MerlinVisual.CREAM
const COL_GOLD: Color = MerlinVisual.GOLD
const COL_DIM: Color = MerlinVisual.DIM_WARM

const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"
const MENU_SCENE: String = "res://scenes/MerlinMenu.tscn"
const GAME_MUSIC: String = "res://music/loop/VOYAGEUR - INTRO (Tri Martolod) (Remastered).mp3-loop.wav"

const TITLES_CAP_S: float = 75.0    # filet dur : au-delà, on accepte le fallback (jamais d'attente infinie)
const SKIP_REVEAL_S: float = 3.0    # affordance « passer » révélée vite (user : on doit pouvoir skipper)

var _cards_box: HBoxContainer
var _title_lbl: Label
var _back_btn: Button
var _overlay: Panel
var _overlay_art: MerlinSceneArt
var _overlay_lbl: Label
var _overlay_skip_lbl: Label
var _busy: bool = false
var _overlay_dots_tw: Tween = null
var _overlay_pulse_tw: Tween = null
var _overlay_base_txt: String = ""
var _overlay_skipped: bool = false
var _overlay_skip_shown: bool = false


func _ready() -> void:
	_build_ui()
	_animate_entrance()
	_setup_music()
	call_deferred("_load_selection")


func _setup_music() -> void:
	if not ResourceLoader.exists(GAME_MUSIC):
		return
	var stream: AudioStream = load(GAME_MUSIC)
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
	MerlinAudio.play_music(stream, 1.5)


func _load_selection() -> void:
	var sc: Node = get_node("/root/MerlinScenario")
	_show_overlay("Merlin rêve les trois sentiers")
	# Titres FORCÉMENT LLM : on attend que la sélection soit prête (montage animé), filet TITLES_CAP_S
	# + skip après SKIP_REVEAL_S. take_selection() ne sert ensuite plus que de récupérateur.
	await _force_wait_titles(sc)
	var sels: Array = await sc.take_selection()
	_hide_overlay()
	if not is_inside_tree():
		return
	for s in sels:
		_add_parchemin(str(s.get("title", "?")), str(s.get("pitch", "")))


# Attend les titres LLM (montage). Sort quand prêt, ou au skip (20 s+), ou au cap dur (75 s).
func _force_wait_titles(sc: Node) -> void:
	var t0: int = Time.get_ticks_msec()
	while is_inside_tree():
		if sc.has_method("is_selection_ready") and sc.is_selection_ready():
			return
		var elapsed: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if elapsed >= TITLES_CAP_S or _overlay_skipped:
			return
		if elapsed >= SKIP_REVEAL_S and not _overlay_skip_shown:
			_reveal_overlay_skip()
		# Robustesse : relance la pré-gen si elle n'a pas démarré (modèle prêt plus tard que le menu).
		if sc.has_method("ensure_selection_prefetch"):
			sc.ensure_selection_prefetch()
		await get_tree().create_timer(0.25).timeout


# v10.22 (QA user, screenshot) — carte À LA CHARTE du menu : hauteur AJUSTÉE AU CONTENU (fini le panneau
# 560px aux 2/3 vide), ornement triskèle sous le titre (langage du menu), pitch centré, bouton collé au
# texte. La carte se centre verticalement dans la rangée (SHRINK_CENTER).
func _add_parchemin(title: String, pitch: String) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)  # hauteur = contenu
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _surface_style())
	var marg: MarginContainer = MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		marg.add_theme_constant_override(side, 30)
	marg.add_theme_constant_override("margin_top", 26)
	marg.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(marg)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	marg.add_child(v)

	var t: Label = Label.new()
	t.text = title
	t.add_theme_color_override("font_color", COL_GOLD)
	t.add_theme_font_size_override("font_size", 30)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)

	v.add_child(MerlinOrnament.triskele_rule(18.0))  # ornement du menu — même langage partout (R125)

	var p: Label = Label.new()
	p.text = pitch
	p.add_theme_color_override("font_color", COL_TEXT)
	p.add_theme_font_size_override("font_size", 22)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(p)

	var sp: Control = Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)

	var b: Button = Button.new()
	b.text = "Suivre ce sentier"
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 22)
	MerlinVisual.apply_button_da(b)
	b.pressed.connect(_on_pick.bind(title, pitch))
	MerlinVisual.connect_button_feedback(b)
	v.add_child(b)

	_cards_box.add_child(panel)
	_card_in(panel, 0.10 + 0.14 * float(_cards_box.get_child_count() - 1))


# Entrée de parchemin : pop d'échelle + fondu (juice renforcé, user 2026-06-29). Pas de position
# (l'HBox la pilote) → on anime modulate + scale (que le conteneur ne réécrit pas).
func _card_in(node: Control, delay: float) -> void:
	node.modulate.a = 0.0
	node.scale = Vector2(0.90, 0.90)
	var m: float = MerlinVisual.motion()
	var tw: Tween = node.create_tween()
	tw.tween_interval(maxf(delay, 0.001))
	# v10.22 : pivot posé APRÈS layout (hauteur = contenu → custom_minimum_size.y vaut 0 désormais).
	tw.tween_callback(func() -> void: node.pivot_offset = node.size * 0.5)
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, 0.45 * m).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "scale", Vector2.ONE, 0.55 * m).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_pick(title: String, pitch: String) -> void:
	if _busy:
		return
	_busy = true
	# Squelette INSTANTANÉ (le pitch est le synopsis) → bascule immédiate vers le jeu.
	var skel: Dictionary = get_node("/root/MerlinScenario").build_skeleton(title, pitch)
	get_node("/root/MerlinRun").new_run(skel)
	# Arc narratif LLM en arrière-plan (fire-and-forget) ; l'interstitiel in-game (R111) le couvre.
	get_node("/root/MerlinScenario").prepare_arc(skel)
	# v10.19 - montage du scénario : transition « zoom vers Merlin ». Vague D (D1) : plus de caption
	# CANNÉE (« Le sentier se dessine sous mes doigts… ») - on garde le montage VISUEL (voile + zoom
	# vers Merlin), sans bulle de texte (réplique vide → change_scene_merlin n'affiche aucun panneau).
	MerlinTransition.change_scene_merlin(GAME_SCENE, "")


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# v10.20 — fond SCÈNE VIVANTE (DA alignée sur le menu, user 2026-06-29) : même monde, dimmé.
	add_child(MerlinOrnament.scene_backdrop(0.40))

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 40)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	margin.add_child(root)

	_title_lbl = Label.new()
	_title_lbl.text = "Choisis ton chemin"
	_title_lbl.add_theme_color_override("font_color", COL_GOLD)
	_title_lbl.add_theme_font_size_override("font_size", 46)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title_lbl)
	# Filet + triskèle or (signature DA du menu).
	var rule: HBoxContainer = MerlinOrnament.triskele_rule(24.0)
	root.add_child(rule)
	MerlinOrnament.spin_triskele(rule)

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 24)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_cards_box)

	_back_btn = Button.new()
	_back_btn.text = "◀ Retour"
	_back_btn.custom_minimum_size = Vector2(140, 44)
	MerlinVisual.apply_button_da(_back_btn)
	_back_btn.pressed.connect(_on_back)
	root.add_child(_back_btn)
	MerlinVisual.connect_button_feedback(_back_btn)

	# --- Overlay « montage réflexion de Merlin » (ultra-animé) ---
	_overlay = Panel.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ov_sb: StyleBoxFlat = StyleBoxFlat.new()
	ov_sb.bg_color = Color(MerlinVisual.BG_DEEP.r, MerlinVisual.BG_DEEP.g, MerlinVisual.BG_DEEP.b, 0.96)
	_overlay.add_theme_stylebox_override("panel", ov_sb)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)
	# Scène vivante de Merlin (réflexion) en fond du montage, atténuée pour la lisibilité du texte.
	_overlay_art = MerlinSceneArt.new()
	_overlay_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_art.modulate.a = 0.5
	_overlay.add_child(_overlay_art)
	_overlay_art.set_menu_decor(true)
	_overlay_art.set_beat("Rencontre")
	_overlay_art.set_season(MerlinSceneArt.season_for_now())
	_overlay_art.set_biome(str(get_node("/root/MerlinRun").biome))  # v10.22 : même monde que la run
	var hour: int = int(Time.get_datetime_dict_from_system().get("hour", 21))
	if OS.has_environment("MERLIN_TOD_HOUR"):
		hour = int(OS.get_environment("MERLIN_TOD_HOUR"))
	_overlay_art.set_time_of_day(hour)
	_overlay_art.set_animated(true)
	_overlay_lbl = Label.new()
	_overlay_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_lbl.add_theme_color_override("font_color", COL_GOLD)
	_overlay_lbl.add_theme_font_size_override("font_size", 40)
	_overlay_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE  # laisse les clics atteindre gui_input (skip)
	_overlay.add_child(_overlay_lbl)
	_overlay_skip_lbl = Label.new()
	_overlay_skip_lbl.anchor_left = 0.0
	_overlay_skip_lbl.anchor_right = 1.0
	_overlay_skip_lbl.anchor_top = 1.0
	_overlay_skip_lbl.anchor_bottom = 1.0
	_overlay_skip_lbl.offset_top = -64.0
	_overlay_skip_lbl.offset_bottom = -32.0
	_overlay_skip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_skip_lbl.add_theme_color_override("font_color", COL_DIM)
	_overlay_skip_lbl.add_theme_font_size_override("font_size", 18)
	_overlay_skip_lbl.text = "▶ clic pour passer"
	_overlay_skip_lbl.visible = false
	_overlay_skip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_overlay_skip_lbl)
	_overlay.visible = false


func _on_back() -> void:
	MerlinTransition.change_scene(MENU_SCENE)


func _show_overlay(txt: String) -> void:
	_overlay.visible = true
	_overlay_base_txt = txt
	_overlay_lbl.text = txt
	if _overlay_art != null:
		_overlay_art.set_thinking(true)  # mote « Merlin réfléchit »
	# Pulse de la légende (respiration) — « ultra animé ».
	if _overlay_pulse_tw != null and _overlay_pulse_tw.is_valid():
		_overlay_pulse_tw.kill()
	if not MerlinVisual.reduced_motion:
		_overlay_pulse_tw = create_tween().set_loops()
		_overlay_pulse_tw.tween_property(_overlay_lbl, "modulate:a", 0.55, 1.1).set_trans(Tween.TRANS_SINE)
		_overlay_pulse_tw.tween_property(_overlay_lbl, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	if _overlay_dots_tw != null and _overlay_dots_tw.is_valid():
		_overlay_dots_tw.kill()
	_overlay_dots_tw = create_tween().set_loops()
	for suffix in ["", "  ·", "  · ·", "  · · ·"]:
		_overlay_dots_tw.tween_callback(_set_overlay_suffix.bind(suffix))
		_overlay_dots_tw.tween_interval(0.4)
	# Note (user 2026-06-30) : le « son de point » (quill_tick toutes les 0.6 s) est RETIRÉ — jugé inutile.
	# Les points « … » restent purement visuels.


func _set_overlay_suffix(suffix: String) -> void:
	if _overlay_lbl != null:
		_overlay_lbl.text = _overlay_base_txt + suffix


func _reveal_overlay_skip() -> void:
	_overlay_skip_shown = true
	if _overlay_skip_lbl != null:
		_overlay_skip_lbl.visible = true
		_overlay_skip_lbl.modulate.a = 0.0
		create_tween().tween_property(_overlay_skip_lbl, "modulate:a", 1.0, 0.4)


func _on_overlay_input(event: InputEvent) -> void:
	# Skip autorisé uniquement APRÈS la révélation de l'affordance (≥20 s) → respecte « titres forcément
	# générés » tout en évitant de piéger le joueur si le modèle est absent.
	if _overlay_skip_shown and event is InputEventMouseButton and event.pressed:
		_overlay_skipped = true


func _hide_overlay() -> void:
	_overlay.visible = false
	if _overlay_art != null:
		_overlay_art.set_thinking(false)
		_overlay_art.set_animated(false)  # stoppe les redraws du décor une fois le montage fini
	for tw in [_overlay_dots_tw, _overlay_pulse_tw]:
		if tw != null and tw.is_valid():
			tw.kill()
	_overlay_dots_tw = null
	_overlay_pulse_tw = null


func _animate_entrance() -> void:
	_fade_in(_title_lbl, 0.00, 0.45)
	_fade_in(_cards_box, 0.20, 0.50)
	_fade_in(_back_btn, 0.55, 0.35)


func _fade_in(node: CanvasItem, delay: float, dur: float) -> void:
	node.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_interval(maxf(delay, 0.001))
	tw.tween_property(node, "modulate:a", 1.0, dur * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _surface_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_SURFACE
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(20)
	return sb
