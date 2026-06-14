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
	_title_lbl.text = END_TITLES.get(et, "Fin")
	_title_lbl.add_theme_color_override("font_color", _end_color(et))
	_state_lbl.text = "Intégrité finale : %d/10    ·    Corruption finale : %d" % [run.integrite, run.corruption]

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
	_caret.add_theme_color_override("font_color", Color("8A6A2E"))
	_caret.add_theme_font_size_override("font_size", 20)
	_caret.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caret.visible = false
	root.add_child(_caret)

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
	_continue_btn.pressed.connect(_on_continue)
	MerlinVisual.connect_button_feedback(_continue_btn)
	root.add_child(_continue_btn)
	_animate_entrance()


func _on_continue() -> void:
	MerlinTransition.change_scene(MENU_SCENE)


func _typewriter(txt: String, animate: bool = true) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null
	_can_advance = false
	_set_caret(false)
	_epilogue.text = txt
	if not animate:
		_epilogue.visible_characters = -1  # tout révélé (swap d'enrichissement LLM)
		_on_typewriter_done()
		return
	_epilogue.visible_characters = 0
	var n: int = _epilogue.get_total_character_count()
	if n <= 0:
		_on_typewriter_done()
		return
	var dur: float = clampf(float(n) / 30.0, 0.8, 10.0)
	_tw = create_tween()
	_tw.tween_property(_epilogue, "visible_characters", n, dur)
	_tw.tween_callback(_on_typewriter_done)
	if _quill_tw != null and _quill_tw.is_valid():
		_quill_tw.kill()
	var tick_interval: float = dur / maxf(float(n), 1.0) * 3.0
	var tick_count: int = maxi(n / 3, 1)
	_quill_tw = create_tween()
	for i in tick_count:
		_quill_tw.tween_interval(tick_interval)
		_quill_tw.tween_callback(func() -> void: MerlinAudio.play_sfx("quill_tick", randf_range(0.92, 1.08)))


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
		_caret_tw.tween_property(_caret, "modulate:a", 0.18, 0.6).set_trans(Tween.TRANS_SINE)
		_caret_tw.tween_property(_caret, "modulate:a", 0.65, 0.6).set_trans(Tween.TRANS_SINE)


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
	_fade_in(_continue_btn, 0.65, 0.40)


func _fade_in(node: CanvasItem, delay: float, dur: float) -> void:
	node.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_interval(maxf(delay, 0.001))
	tw.tween_property(node, "modulate:a", 1.0, dur * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
