extends Control
## MerlinEnd — écran de fin (bible R69). Épilogue généré (LLM) selon le type de fin
## + état final + bouton Continuer → menu. La run terminée efface sa sauvegarde de reprise.

const COL_BG: Color = MerlinVisual.BG_DEEP
const COL_SURFACE: Color = MerlinVisual.SURFACE
const COL_TEXT: Color = MerlinVisual.CREAM
const COL_GOLD: Color = MerlinVisual.GOLD
const COL_GREEN: Color = MerlinVisual.GREEN
const COL_VIOLET: Color = MerlinVisual.VIOLET
const COL_DIM: Color = MerlinVisual.DIM_WARM

const MENU_SCENE: String = "res://scenes/MerlinMenu.tscn"

const END_TITLES: Dictionary = {
	"accomplissement": "Accomplissement",
	"mort": "Mort narrative",
	"corrompu": "Bascule corrompue",
}

var _title_lbl: Label
var _epilogue: RichTextLabel
var _epilogue_panel: PanelContainer  # capte le clic pour skip-typewriter / advance (parité merlin_game.gd)
var _state_lbl: Label
var _recap_box: VBoxContainer = null  # P2 (chantier 2) : bloc récap gravure (VOIE + stats + fragment)
var _continue_btn: Button
var _tw: Tween
# v10/C1 (audit UX 4 piliers bible §21) — port du mécanisme epoch + tw guard + caret de merlin_game.gd :
# évite le swap silencieux du texte LLM pendant que le joueur lit le fallback. (user 2026-05-31 /goal)
var _scene_epoch: int = 0  # invalide une réponse LLM si la scène a tourné/changé entre-temps
var _can_advance: bool = false  # vrai après typewriter terminé : le clic avance (parité avec le bouton)
var _caret: Label = null  # ▮ cliquer pour continuer (clignotant, identique merlin_game.gd)
var _caret_tw: Tween = null
var _quill_tw: Tween


func _ready() -> void:
	_build_ui()
	MerlinAudio.stop_music(1.0)
	call_deferred("_run_end")


func _run_end() -> void:
	_scene_epoch += 1
	var ep: int = _scene_epoch
	var run: Node = get_node("/root/MerlinRun")
	var et: String = str(run.end_type)
	if et == "":
		et = "accomplissement"
	MerlinAudio.play_end_stinger(et)  # P3 (chantier 6) : stinger de fin par type de run (à l'entrée de scène)
	_title_lbl.text = END_TITLES.get(et, "Fin")
	_title_lbl.add_theme_color_override("font_color", _end_color(et))
	_state_lbl.text = "Intégrité finale : %d/10    ·    Corruption finale : %d" % [run.integrite, run.corruption]
	_fill_recap(run)  # P2 (chantier 2) : VOIE + récap du build + fragment (l'écran de fin donne envie de relancer)

	# Épilogue procédural INSTANTANÉ, puis enrichissement LLM en arrière-plan (jamais bloquant).
	var sc: Node = get_node("/root/MerlinScenario")
	_typewriter(sc.fallback_epilogue(et))
	run.clear_save()
	_continue_btn.disabled = false
	_bg_epilogue(ep, et, run.to_state_dict())


# Enrichit l'épilogue en arrière-plan ; ne remplace QUE si le typewriter est encore en cours
# (anti-saut de lecture, bible §21.1 pilier ÉVIDENT). Epoch guard pour invalidation si scène changée.
func _bg_epilogue(ep: int, et: String, state: Dictionary) -> void:
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	if sc == null:
		return
	var epi: String = await sc.narrate_epilogue(et, state)
	if ep != _scene_epoch or epi.length() < 10 or not is_inside_tree():
		return
	if _tw != null and _tw.is_valid():
		return  # typewriter encore en cours → ne pas swap (parité merlin_game.gd::_bg_resolution)
	_typewriter(epi, false)  # swap sans ré-animer


func _end_color(et: String) -> Color:
	match et:
		"mort": return COL_VIOLET
		"corrompu": return COL_VIOLET
		_: return COL_GOLD


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# v10.21 (goal uniformisation) — MÊME monde vivant que le menu derrière l'écran de fin (dimmé
	# davantage : le bilan doit dominer, la forêt respire encore derrière — elle a « pris sa part »).
	add_child(MerlinOrnament.scene_backdrop(0.30))

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 48)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	_title_lbl = Label.new()
	_title_lbl.add_theme_color_override("font_color", COL_GOLD)
	_title_lbl.add_theme_font_size_override("font_size", 40)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title_lbl)

	_epilogue_panel = PanelContainer.new()
	_epilogue_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_epilogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # capte le clic pour skip-typewriter / advance
	_epilogue_panel.gui_input.connect(_on_epilogue_click)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_SURFACE
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(24)
	_epilogue_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_epilogue_panel)
	_epilogue = RichTextLabel.new()
	_epilogue.bbcode_enabled = true
	_epilogue.add_theme_color_override("default_color", COL_TEXT)
	_epilogue.add_theme_font_size_override("normal_font_size", 30)
	_epilogue.mouse_filter = Control.MOUSE_FILTER_IGNORE  # laisse le clic passer au panel parent
	_epilogue_panel.add_child(_epilogue)

	# Caret « ▮ cliquer pour continuer » — apparaît clignotant après la fin du typewriter (bible §21.1 ÉVIDENT).
	_caret = Label.new()
	_caret.text = "▮ cliquer pour continuer"
	_caret.add_theme_color_override("font_color", MerlinVisual.GOLD_DARK)
	_caret.add_theme_font_size_override("font_size", 20)
	_caret.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caret.visible = false
	root.add_child(_caret)

	# P2 (chantier 2, CDC-UX-18/GD-40) : bloc RÉCAP gravure entre l'épilogue et l'état final.
	# Peuplé par _fill_recap (données run.end_recap + fragments Chronicle) : VOIE en tête (or),
	# stats sobres, fragment révélé sur accomplissement. L'argument de re-run vit ici.
	var recap_panel: PanelContainer = PanelContainer.new()
	recap_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	recap_panel.custom_minimum_size = Vector2(600, 0)  # P2 : largeur mini (les valeurs de stats ne wrappent plus)
	var rsb: StyleBoxFlat = StyleBoxFlat.new()
	rsb.bg_color = COL_SURFACE
	rsb.set_corner_radius_all(8)
	rsb.set_content_margin_all(18)
	rsb.set_border_width_all(1)
	rsb.border_color = MerlinVisual.BORDER_BRUN
	recap_panel.add_theme_stylebox_override("panel", rsb)
	root.add_child(recap_panel)
	_recap_box = VBoxContainer.new()
	_recap_box.add_theme_constant_override("separation", 10)
	recap_panel.add_child(_recap_box)

	_state_lbl = Label.new()
	_state_lbl.add_theme_color_override("font_color", COL_DIM)
	_state_lbl.add_theme_font_size_override("font_size", 24)
	_state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_state_lbl)

	_continue_btn = Button.new()
	_continue_btn.text = "Continuer ▶"
	_continue_btn.custom_minimum_size = Vector2(300, 64)
	_continue_btn.add_theme_font_size_override("font_size", 24)
	_continue_btn.disabled = true
	MerlinVisual.apply_button_da(_continue_btn)
	_continue_btn.pressed.connect(_on_continue)
	MerlinVisual.connect_button_feedback(_continue_btn)
	root.add_child(_continue_btn)
	_animate_entrance()


func _on_continue() -> void:
	MerlinTransition.change_scene(MENU_SCENE)


# P3 (chantier 2, revue design BLOCKER) : la taille du pack lecture s'applique AUSSI a l'epilogue
# (le plus haut enjeu de lecture de la session). Base 30 conservee au cran Standard ; +delta au cran
# Confort (delta = narrative_font_size() - FS_NARRATIVE). Overrides normal + italiques (prose R140).
func _apply_reading_font() -> void:
	if _epilogue == null:
		return
	var fs: int = 30 + (MerlinVisual.narrative_font_size() - MerlinVisual.FS_NARRATIVE)
	_epilogue.add_theme_font_size_override("normal_font_size", fs)
	_epilogue.add_theme_font_size_override("italics_font_size", fs)
	_epilogue.add_theme_font_size_override("bold_italics_font_size", fs)


func _typewriter(txt: String, animate: bool = true) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null
	_can_advance = false
	_set_caret(false)
	_apply_reading_font()  # P3 (chantier 2) : taille du recit lue live depuis le pack lecture
	_epilogue.text = txt
	# P3 (chantier 2) — « Instantané » du pack lecture : l'épilogue se révèle d'un coup (parité MerlinGame).
	if not animate or MerlinVisual.typewriter_instant():
		_epilogue.visible_characters = -1  # tout révélé (swap d'enrichissement LLM / lecture instantanée)
		_on_typewriter_done()
		return
	_epilogue.visible_characters = 0
	var n: int = _epilogue.get_total_character_count()
	if n <= 0:
		_on_typewriter_done()
		return
	# P3 (chantier 2) — vitesse lue depuis le pack lecture (Lent/Normal/Rapide) au lieu du 30 c/s figé.
	var dur: float = clampf(float(n) / MerlinVisual.typewriter_cps(), 0.8, 10.0)
	_tw = create_tween()
	_tw.tween_property(_epilogue, "visible_characters", n, dur)
	_tw.tween_callback(_on_typewriter_done)
	if _quill_tw != null and _quill_tw.is_valid():
		_quill_tw.kill()
	var tick_interval: float = dur / maxf(float(n), 1.0) * 3.0
	var tick_count: int = maxi(n / 3, 1)
	# v10.20 — l'épilogue est CONTÉ par Merlin → sa VOIX (à la place du quill). user 2026-06-29.
	var mood: String = MerlinSceneArt.mood_for_text(txt)
	var sess: int = MerlinAudio.begin_voice()  # voix unique (anti-superposition)
	_quill_tw = create_tween()
	for i in tick_count:
		_quill_tw.tween_interval(tick_interval)
		_quill_tw.tween_callback(func() -> void: MerlinAudio.play_voice_session(sess, mood))


# === v10/C1 : helpers epoch + caret + skip-typewriter (parité merlin_game.gd) ===

func _on_typewriter_done() -> void:
	# Typewriter terminé : le clic sur la zone récit avance vers le menu (parité bouton Continuer).
	_can_advance = true
	_set_caret(true)


func _set_caret(on: bool) -> void:
	if _caret == null:
		return
	_caret.visible = on
	if _caret_tw != null and _caret_tw.is_valid():
		_caret_tw.kill()
	_caret_tw = null
	if on:
		_caret.modulate.a = 0.65
		_caret_tw = _caret.create_tween().set_loops()
		_caret_tw.tween_property(_caret, "modulate:a", 0.18, MerlinVisual.DUR_CARET_BLINK * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)
		_caret_tw.tween_property(_caret, "modulate:a", 0.65, MerlinVisual.DUR_CARET_BLINK * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)


func _skip_typewriter() -> void:
	if _tw == null or not _tw.is_valid():
		return
	_tw.kill()
	_tw = null
	_epilogue.visible_characters = -1
	_on_typewriter_done()


# Clic sur le panel épilogue : skip si frappe en cours, sinon avance au menu (parité bouton).
func _on_epilogue_click(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _tw != null and _tw.is_valid():
		_skip_typewriter()
	elif _can_advance and not _continue_btn.disabled:
		_on_continue()


func _animate_entrance() -> void:
	_fade_in(_title_lbl, 0.00, 0.50)
	_fade_in(_epilogue_panel, 0.25, 0.55)
	_fade_in(_state_lbl, 0.50, 0.40)
	if _recap_box != null and _recap_box.get_parent() is CanvasItem:
		_fade_in(_recap_box.get_parent() as CanvasItem, 0.55, 0.45)  # P2 : le panneau récap fond avec l'écran
	_fade_in(_continue_btn, 0.72, 0.40)


func _fade_in(node: CanvasItem, delay: float, dur: float) -> void:
	node.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_interval(maxf(delay, 0.001))
	tw.tween_property(node, "modulate:a", 1.0, dur * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# P2 (chantier 2) : joint jusqu'à n éléments d'un tableau (n<=0 : tous). Petit utilitaire de récap.
func _join_str(arr: Array, sep: String, n: int = -1) -> String:
	var parts: PackedStringArray = []
	for x in arr:
		parts.append(str(x))
		if n > 0 and parts.size() >= n:
			break
	return sep.join(parts)


# P2 (chantier 2) : accord FR singulier/pluriel (0 et 1 → singulier, >=2 → pluriel).
func _plur(n: int, sing: String, plur: String) -> String:
	return "%d %s" % [n, sing if n <= 1 else plur]


# P2 (chantier 2) : une ligne du récap (label estompé + valeur crème) dans la grille 2 colonnes.
func _recap_row(grid: GridContainer, label_txt: String, value_txt: String) -> void:
	var l: Label = Label.new()
	l.text = label_txt
	l.add_theme_color_override("font_color", COL_DIM)
	l.add_theme_font_size_override("font_size", 20)
	grid.add_child(l)
	var v: Label = Label.new()
	v.text = value_txt
	v.add_theme_color_override("font_color", COL_TEXT)
	v.add_theme_font_size_override("font_size", 20)
	grid.add_child(v)


# P2 (chantier 2, CDC-UX-18/GD-40) : peuple le bloc récap depuis run.end_recap() + Chronicle. VOIE en
# tête (or, identité de run), stats sobres, faits marquants subtils, fragment du Graal (N/12) révélé
# sur accomplissement. 100% lecture (ne mute rien). Vide → rien de bloquant (l'écran tient seul).
func _fill_recap(run: Node) -> void:
	if _recap_box == null or not is_instance_valid(_recap_box):
		return
	for c in _recap_box.get_children():
		c.queue_free()
	var rec: Dictionary = run.end_recap() if run.has_method("end_recap") else {}
	# VOIE de la Carte Destin (identité de la run) : la reformulation narrative évite le tiret cadratin.
	var voie_v: Variant = rec.get("voie", {})
	if voie_v is Dictionary and not (voie_v as Dictionary).is_empty():
		var voie: Dictionary = voie_v
		var vlbl: Label = Label.new()
		vlbl.text = "Cette nuit, tu as marché %s : %s." % [str(voie.get("nom", "")), str(voie.get("tier", ""))]
		vlbl.add_theme_color_override("font_color", COL_GOLD)
		vlbl.add_theme_font_size_override("font_size", 24)
		vlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_recap_box.add_child(vlbl)
	# Grille de stats sobres (label → valeur) : le résultat mesurable de la run.
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_recap_box.add_child(grid)
	var deg: Dictionary = rec.get("degrees", {}) if rec.get("degrees") is Dictionary else {}
	_recap_row(grid, "Épreuves traversées", str(int(rec.get("beats", 0))))
	_recap_row(grid, "Degrés", "%s · %s · %s · %s" % [
		_plur(int(deg.get("eclatante", 0)), "éclatante", "éclatantes"),
		_plur(int(deg.get("reussite", 0)), "réussite", "réussites"),
		_plur(int(deg.get("partiel", 0)), "partiel", "partiels"),
		_plur(int(deg.get("echec", 0)), "échec", "échecs")])
	_recap_row(grid, "Corruption, au plus fort", str(int(rec.get("corruption_max", 0))))
	_recap_row(grid, "Greffes posées", str(int(rec.get("grafts", 0))))
	var verbs_v: Variant = rec.get("verbs_leveled", [])
	if verbs_v is Array and not (verbs_v as Array).is_empty():
		_recap_row(grid, "Verbes renforcés", _join_str(verbs_v, ", "))
	# Faits marquants (subtil, sous la grille) : la mémoire de ce qui a marqué la traversée.
	var faits_v: Variant = rec.get("faits", [])
	if not (faits_v is Array) or (faits_v as Array).is_empty():
		faits_v = rec.get("cartes_notables", [])
	if faits_v is Array and not (faits_v as Array).is_empty():
		var f: Label = Label.new()
		f.text = "Faits marquants : " + _join_str(faits_v, ", ", 4)
		f.add_theme_color_override("font_color", COL_DIM)
		f.add_theme_font_size_override("font_size", 18)
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_recap_box.add_child(f)
	# Fragment du Graal révélé en scène (accomplissement) : N/12 ancre le but (design F4 / CDC-GD-02).
	if str(run.end_type) == "accomplissement":
		var chron: Dictionary = MerlinChronicle.read()
		var frag: int = int(chron.get("graal_fragments", 0))
		var fl: Label = Label.new()
		fl.text = "✦ Fragment du Graal arraché à la brume · %d/%d" % [frag, MerlinChronicle.GRAAL_TOTAL]
		fl.add_theme_color_override("font_color", COL_GOLD)
		fl.add_theme_font_size_override("font_size", 20)
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_recap_box.add_child(fl)
