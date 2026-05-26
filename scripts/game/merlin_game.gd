extends Control
## MerlinGame — boucle de jeu (bible §2, R54/R55/R72). Scène de jeu MVP.
## Situation (LLM prose) → main → combinaison (1 principale + 2 mods) → résolution (CODE)
## → narration (LLM) → beat suivant. Génération SÉQUENTIELLE à la demande (voile "Merlin écrit"),
## sans lookahead (le moteur natif est single-flight). Fallbacks partout → la run se termine toujours.

const COL_BG: Color = Color("14100C")
const COL_SURFACE: Color = Color("2A2018")
const COL_TEXT: Color = Color("E8DCC0")
const COL_GOLD: Color = Color("C9A24B")
const COL_GREEN: Color = Color("7FA65C")
const COL_VIOLET: Color = Color("7B4FA3")
const COL_DIM: Color = Color("9C8C6A")

const DEFAULT_TITLE: String = "Le Sentier des Murmures"
const DEFAULT_PITCH: String = "Un chemin s'ouvre sous les fougères, là où nul n'a marché. La forêt t'y attend, patiente."
const END_SCENE: String = "res://scenes/MerlinEnd.tscn"

var _integrite_lbl: Label
var _corruption_lbl: Label
var _perles_lbl: Label
var _situation_text: RichTextLabel
var _hint_lbl: Label
var _hand_box: HBoxContainer
var _combo_box: HBoxContainer
var _preview_lbl: Label
var _resolve_btn: Button
var _continue_btn: Button
var _overlay: Panel
var _overlay_lbl: Label

var _current_situation: Dictionary = {}
var _combo: Array = []
var _state: int = 0  # 0=loading 1=playing 2=resolving
# Garde anti-clobber : incrémenté à CHAQUE transition d'affichage (nouvelle situation,
# issue affichée, fin de run). Un enrichissement LLM en arrière-plan ne remplace le texte
# QUE si l'epoch n'a pas bougé depuis qu'il a été lancé (sinon le joueur a déjà avancé).
var _scene_epoch: int = 0
var _tw: Tween


func _ready() -> void:
	_build_ui()
	var run: Node = get_node("/root/MerlinRun")
	run.gauges_changed.connect(_on_gauges)
	run.run_ended.connect(_on_run_ended)
	call_deferred("_begin")


func _begin() -> void:
	var run: Node = get_node("/root/MerlinRun")
	if run.scenario.is_empty():
		# Squelette INSTANTANÉ (le pitch est le synopsis) — aucune attente.
		var skel: Dictionary = get_node("/root/MerlinScenario").build_skeleton(DEFAULT_TITLE, DEFAULT_PITCH)
		run.new_run(skel)
	_on_gauges(run.integrite, run.corruption)
	_present_current_beat()


func _present_current_beat() -> void:
	var run: Node = get_node("/root/MerlinRun")
	if run.ended:
		return
	_scene_epoch += 1  # toute issue LLM en vol du beat précédent devient périmée
	var beat: Dictionary = run.current_beat()
	# Situation procédurale INSTANTANÉE (zéro attente). Volontairement PAS d'enrichissement LLM
	# ici : à ~1 tok/s la gen (~40s) ne gagne jamais la course contre la lecture du joueur, et un
	# swap de texte en cours de lecture viole le pilier ÉVIDENT (bible §21.1). Le budget LLM
	# (moteur single-flight) est réservé à l'ISSUE — l'« effet des choix » que le joueur attend.
	_current_situation = get_node("/root/MerlinScenario").build_situation(beat)
	_hide_overlay()
	_show_situation(_current_situation)
	_combo.clear()
	_render_hand()
	_render_combo()
	_state = 1


func _show_situation(situ: Dictionary, animate: bool = true) -> void:
	var run: Node = get_node("/root/MerlinRun")
	var btype: String = str(situ.get("type", ""))
	var marker: String = "[color=#9C8C6A]— %s · beat %d/%d —[/color]\n\n" % [btype, run.beat_index + 1, int(run.scenario.get("total", 5))]
	_typewriter(marker + str(situ.get("narration", "")), animate)
	var reqs: Array = situ.get("required_tags", [])
	_hint_lbl.text = "Ce moment appelle :  " + _format_tags(reqs)


func _format_tags(tags: Array) -> String:
	var parts: PackedStringArray = []
	for t in tags:
		parts.append("‹ %s ›" % str(t))
	return "   ".join(parts)


func _render_hand() -> void:
	for c in _hand_box.get_children():
		c.queue_free()
	var run: Node = get_node("/root/MerlinRun")
	for card in run.hand:
		var b: Button = _make_card_button(card, false)
		b.pressed.connect(_on_hand_card.bind(card))
		_hand_box.add_child(b)


func _render_combo() -> void:
	for c in _combo_box.get_children():
		c.queue_free()
	for i in _combo.size():
		var card: MerlinCard = _combo[i]
		var role: String = "principale" if i == 0 else "modificateur"
		var b: Button = _make_card_button(card, true, role)
		b.pressed.connect(_on_combo_card.bind(card))
		_combo_box.add_child(b)
	_update_preview()


func _make_card_button(card: MerlinCard, _in_combo: bool, role: String = "") -> Button:
	var b: Button = Button.new()
	var tagtxt: String = "[%s]" % ", ".join(card.tags)
	var cost: String = ("  ⚠%d" % card.corruption) if card.corruption > 0 else ""
	var rolet: String = ("  (%s)" % role) if role != "" else ""
	b.text = "%s\n%s%s%s" % [card.card_name, tagtxt, cost, rolet]
	b.custom_minimum_size = Vector2(190, 72)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 13)
	if card.corruption > 0:
		b.add_theme_color_override("font_color", COL_VIOLET)
	return b


func _on_hand_card(card: MerlinCard) -> void:
	if _state != 1 or _combo.size() >= 3 or _combo.has(card):
		return
	_combo.append(card)
	_render_combo()


func _on_combo_card(card: MerlinCard) -> void:
	if _state != 1:
		return
	_combo.erase(card)
	_render_combo()


func _update_preview() -> void:
	if _combo.is_empty():
		_preview_lbl.text = "Pose une carte (la 1ère = action principale)."
		_resolve_btn.disabled = true
		return
	var reqs: Array = _current_situation.get("required_tags", [])
	var res: Dictionary = MerlinResolution.resolve(reqs, _combo, [])
	var cov: Dictionary = res["coverage"]
	var covered: int = cov["covered"].size()
	var total: int = covered + cov["missing"].size()
	_preview_lbl.text = "Couverture %d/%d  ·  degré pressenti : %s  ·  coût Corruption : %d" % [covered, total, str(res["label"]), int(res["corruption_delta"])]
	_resolve_btn.disabled = false


func _on_resolve() -> void:
	if _state != 1 or _combo.is_empty():
		return
	_state = 2
	_resolve_btn.disabled = true
	var run: Node = get_node("/root/MerlinRun")
	var reqs: Array = _current_situation.get("required_tags", [])
	var res: Dictionary = MerlinResolution.resolve(reqs, _combo, [])
	var played_names: Array = []
	for c in _combo:
		played_names.append(c.card_name)

	# Issue procédurale INSTANTANÉE — aucune attente. Le LLM enrichit l'issue en arrière-plan.
	var fallback: String = get_node("/root/MerlinScenario").fallback_resolution(str(res.get("degree", "reussite")))
	run.play_and_discard(_combo)
	run.apply_resolution(res)
	run.faits_marquants.append("%s → %s" % [str(_current_situation.get("type", "")), str(res["label"])])
	if run.faits_marquants.size() > 6:
		run.faits_marquants = run.faits_marquants.slice(run.faits_marquants.size() - 6, run.faits_marquants.size())
	run.summary = fallback

	_scene_epoch += 1
	var ep: int = _scene_epoch
	_combo.clear()
	_render_hand()
	_render_combo()
	_show_resolution(res, fallback, true)
	run.save()

	if not run.ended:
		_continue_btn.visible = true
		_resolve_btn.visible = false
		_bg_resolution(ep, _current_situation, played_names, res)


func _show_resolution(res: Dictionary, narration: String, animate: bool = true) -> void:
	var deg_col: Color = _degree_color(str(res["degree"]))
	if animate:
		_situation_text.text = ""
	_typewriter("[color=#%s]%s[/color]\n\n%s" % [deg_col.to_html(false), str(res["label"]), narration], animate)


# Enrichit l'issue en arrière-plan ; ne remplace QUE si le joueur n'a pas cliqué « Continuer »
# (epoch stable) et que le run n'est pas fini. Jamais bloquant.
func _bg_resolution(ep: int, situ: Dictionary, played: Array, res: Dictionary) -> void:
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	var run: Node = get_node_or_null("/root/MerlinRun")
	if sc == null or run == null:
		return
	if not await _wait_engine_free(ep):
		return
	var prose: String = await sc.narrate_resolution(situ, played, res)
	if ep != _scene_epoch or run.ended or prose.length() < 10 or not is_inside_tree():
		return
	run.summary = prose
	_show_resolution(res, prose, false)  # swap sans ré-animer


func _on_continue() -> void:
	_continue_btn.visible = false
	_resolve_btn.visible = true
	var run: Node = get_node("/root/MerlinRun")
	run.advance_beat()
	if run.ended:
		return
	_present_current_beat()


func _degree_color(degree: String) -> Color:
	match degree:
		"echec": return COL_VIOLET
		"partiel": return COL_DIM
		"eclatante": return COL_GREEN
		_: return COL_GOLD


func _on_gauges(integrite: int, corruption: int) -> void:
	_integrite_lbl.text = "Intégrité  %d/10" % integrite
	_corruption_lbl.text = "Corruption  %d" % corruption
	_corruption_lbl.add_theme_color_override("font_color", COL_VIOLET if corruption > 0 else COL_DIM)
	_render_perles()


func _render_perles() -> void:
	var run: Node = get_node("/root/MerlinRun")
	var total: int = int(run.scenario.get("total", 5))
	var cur: int = run.beat_index
	var s: String = ""
	for i in total:
		s += ("●" if i <= cur else "○") + " "
	_perles_lbl.text = s.strip_edges()


func _on_run_ended(_end_type: String) -> void:
	get_node("/root/MerlinRun").save()
	call_deferred("_goto_end")


func _goto_end() -> void:
	_scene_epoch += 1  # invalide tout enrichissement LLM en vol avant de quitter la scène
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null:
		mn.cancel()
	if ResourceLoader.exists(END_SCENE):
		get_tree().change_scene_to_file(END_SCENE)


func _typewriter(txt: String, animate: bool = true) -> void:
	_kill_tw()
	_situation_text.text = txt
	if not animate:
		_situation_text.visible_characters = -1  # tout révélé (swap d'enrichissement)
		return
	_situation_text.visible_characters = 0
	var n: int = _situation_text.get_total_character_count()
	if n <= 0:
		return
	_tw = create_tween()
	_tw.tween_property(_situation_text, "visible_characters", n, clampf(float(n) / 60.0, 0.4, 5.0))


func _kill_tw() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null


# Attend (en arrière-plan, jamais bloquant pour le joueur) que le moteur LLM se libère.
# Retourne false si la scène a changé (epoch) / run fini / moteur indispo → l'appelant abandonne.
func _wait_engine_free(ep: int) -> bool:
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn == null or not mn.is_ready():
		return false
	var guard: int = 0
	while mn.is_busy() and guard < 6000 and ep == _scene_epoch and is_inside_tree():
		await get_tree().process_frame
		guard += 1
	if not is_inside_tree():
		return false  # scène quittée pendant l'attente (ne pas toucher un nœud en cours de libération)
	var run: Node = get_node_or_null("/root/MerlinRun")
	return ep == _scene_epoch and run != null and not run.ended


func _show_overlay(txt: String) -> void:
	_overlay.visible = true
	_overlay_lbl.text = txt


func _hide_overlay() -> void:
	_overlay.visible = false


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 28)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var hud: HBoxContainer = HBoxContainer.new()
	hud.add_theme_constant_override("separation", 28)
	root.add_child(hud)
	_integrite_lbl = _mk_label(COL_GREEN, 18)
	hud.add_child(_integrite_lbl)
	_corruption_lbl = _mk_label(COL_VIOLET, 18)
	hud.add_child(_corruption_lbl)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(spacer)
	_perles_lbl = _mk_label(COL_GOLD, 18)
	hud.add_child(_perles_lbl)

	var situ_panel: PanelContainer = PanelContainer.new()
	situ_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	situ_panel.add_theme_stylebox_override("panel", _surface_style())
	root.add_child(situ_panel)
	_situation_text = RichTextLabel.new()
	_situation_text.bbcode_enabled = true
	_situation_text.add_theme_color_override("default_color", COL_TEXT)
	_situation_text.add_theme_font_size_override("normal_font_size", 20)
	situ_panel.add_child(_situation_text)

	_hint_lbl = _mk_label(COL_GOLD, 15)
	root.add_child(_hint_lbl)

	var combo_panel: PanelContainer = PanelContainer.new()
	combo_panel.add_theme_stylebox_override("panel", _surface_style())
	root.add_child(combo_panel)
	var combo_v: VBoxContainer = VBoxContainer.new()
	combo_v.add_theme_constant_override("separation", 8)
	combo_panel.add_child(combo_v)
	var combo_title: Label = _mk_label(COL_DIM, 14)
	combo_title.text = "Combinaison (clic pour poser / retirer) :"
	combo_v.add_child(combo_title)
	_combo_box = HBoxContainer.new()
	_combo_box.add_theme_constant_override("separation", 10)
	_combo_box.custom_minimum_size = Vector2(0, 78)
	combo_v.add_child(_combo_box)
	_preview_lbl = _mk_label(COL_TEXT, 15)
	combo_v.add_child(_preview_lbl)
	var btn_row: HBoxContainer = HBoxContainer.new()
	combo_v.add_child(btn_row)
	_resolve_btn = Button.new()
	_resolve_btn.text = "Résoudre"
	_resolve_btn.custom_minimum_size = Vector2(160, 48)
	_resolve_btn.pressed.connect(_on_resolve)
	btn_row.add_child(_resolve_btn)
	_continue_btn = Button.new()
	_continue_btn.text = "Continuer ▶"
	_continue_btn.custom_minimum_size = Vector2(160, 48)
	_continue_btn.visible = false
	_continue_btn.pressed.connect(_on_continue)
	btn_row.add_child(_continue_btn)

	var hand_lbl: Label = _mk_label(COL_DIM, 14)
	hand_lbl.text = "Ta main :"
	root.add_child(hand_lbl)
	_hand_box = HBoxContainer.new()
	_hand_box.add_theme_constant_override("separation", 10)
	_hand_box.custom_minimum_size = Vector2(0, 80)
	root.add_child(_hand_box)

	_overlay = Panel.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ov_sb: StyleBoxFlat = StyleBoxFlat.new()
	ov_sb.bg_color = Color(0.08, 0.06, 0.05, 0.92)
	_overlay.add_theme_stylebox_override("panel", ov_sb)
	add_child(_overlay)
	_overlay_lbl = Label.new()
	_overlay_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_overlay_lbl.add_theme_color_override("font_color", COL_GOLD)
	_overlay_lbl.add_theme_font_size_override("font_size", 26)
	_overlay_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_overlay_lbl)
	_overlay.visible = false


func _mk_label(col: Color, fsize: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", fsize)
	return l


func _surface_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_SURFACE
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	return sb
