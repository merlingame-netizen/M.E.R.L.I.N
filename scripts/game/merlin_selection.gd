extends Control
## MerlinSelection — écran de sélection (bible R56). Merlin propose 3 scénarios (titre + pitch),
## le joueur en choisit un → "Merlin écrit" (squelette) → démarre la run → scène de jeu.

const COL_BG: Color = MerlinVisual.BG_DEEP
const COL_SURFACE: Color = MerlinVisual.SURFACE
const COL_TEXT: Color = MerlinVisual.CREAM
const COL_GOLD: Color = MerlinVisual.GOLD
const COL_DIM: Color = MerlinVisual.DIM_WARM

const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"
const MENU_SCENE: String = "res://scenes/MerlinMenu.tscn"

var _cards_box: HBoxContainer
var _overlay: Panel
var _overlay_lbl: Label
var _busy: bool = false
# v10/H2 (audit UX bible §21.1 ÉVIDENT) : feedback visuel d'attente bornée (8 s budget côté
# MerlinScenario.take_selection). (user 2026-05-31 /goal)
var _overlay_dots_tw: Tween = null
var _overlay_base_txt: String = ""


func _ready() -> void:
	_build_ui()
	call_deferred("_load_selection")


func _load_selection() -> void:
	_show_overlay("Merlin rêve trois sentiers…")
	# Récupère les scénarios pré-générés depuis le menu (instantané si prêts).
	var sels: Array = await get_node("/root/MerlinScenario").take_selection()
	_hide_overlay()
	for s in sels:
		_add_parchemin(str(s.get("title", "?")), str(s.get("pitch", "")))


func _add_parchemin(title: String, pitch: String) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 560)  # parchemins agrandis (user 2026-06-06 : scale tout)
	panel.add_theme_stylebox_override("panel", _surface_style())
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var t: Label = Label.new()
	t.text = title
	t.add_theme_color_override("font_color", COL_GOLD)
	t.add_theme_font_size_override("font_size", 34)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)

	var p: Label = Label.new()
	p.text = pitch
	p.add_theme_color_override("font_color", COL_TEXT)
	p.add_theme_font_size_override("font_size", 24)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(p)

	var b: Button = Button.new()
	b.text = "Suivre ce sentier"
	b.custom_minimum_size = Vector2(0, 62)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(_on_pick.bind(title, pitch))
	v.add_child(b)

	_cards_box.add_child(panel)


func _on_pick(title: String, pitch: String) -> void:
	if _busy:
		return
	_busy = true
	# Squelette INSTANTANÉ (le pitch est le synopsis) → bascule immédiate vers le jeu.
	var skel: Dictionary = get_node("/root/MerlinScenario").build_skeleton(title, pitch)
	get_node("/root/MerlinRun").new_run(skel)
	# Arc narratif LLM en arrière-plan (fire-and-forget) : génère pendant la transition + l'intro ;
	# swappe l'arc fallback cohérent avant le beat 1 si prêt à temps (user 2026-06-07).
	get_node("/root/MerlinScenario").prepare_arc(skel)
	MerlinTransition.change_scene(GAME_SCENE)


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 40)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	margin.add_child(root)

	var title: Label = Label.new()
	title.text = "Choisis ton chemin"
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 24)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_cards_box)

	var back: Button = Button.new()
	back.text = "◀ Retour"
	back.custom_minimum_size = Vector2(140, 44)
	back.pressed.connect(_on_back)
	root.add_child(back)

	_overlay = Panel.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ov_sb: StyleBoxFlat = StyleBoxFlat.new()
	ov_sb.bg_color = Color(0.08, 0.06, 0.05, 0.92)
	_overlay.add_theme_stylebox_override("panel", ov_sb)
	add_child(_overlay)
	_overlay_lbl = Label.new()
	_overlay_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_overlay_lbl.add_theme_color_override("font_color", COL_GOLD)
	_overlay_lbl.add_theme_font_size_override("font_size", 38)
	_overlay.add_child(_overlay_lbl)
	_overlay.visible = false


func _on_back() -> void:
	MerlinTransition.change_scene(MENU_SCENE)


func _show_overlay(txt: String) -> void:
	_overlay.visible = true
	# v10/H2 : on garde le texte de base et on anime un suffixe de dots cycliques (·  ··  ···)
	# pour signifier l'activité d'attente. Tween en boucle, cleanup garanti dans _hide_overlay.
	_overlay_base_txt = txt
	_overlay_lbl.text = txt
	if _overlay_dots_tw != null and _overlay_dots_tw.is_valid():
		_overlay_dots_tw.kill()
	_overlay_dots_tw = create_tween().set_loops()
	for suffix in ["", "  ·", "  · ·", "  · · ·"]:
		_overlay_dots_tw.tween_callback(_set_overlay_suffix.bind(suffix))
		_overlay_dots_tw.tween_interval(0.4)


func _set_overlay_suffix(suffix: String) -> void:
	if _overlay_lbl != null:
		_overlay_lbl.text = _overlay_base_txt + suffix


func _hide_overlay() -> void:
	_overlay.visible = false
	if _overlay_dots_tw != null and _overlay_dots_tw.is_valid():
		_overlay_dots_tw.kill()
	_overlay_dots_tw = null


func _surface_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_SURFACE
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(20)
	return sb
