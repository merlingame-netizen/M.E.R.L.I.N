extends Control
## MerlinSelection — écran de sélection (bible R56). Merlin propose 3 scénarios (titre + pitch),
## le joueur en choisit un → "Merlin écrit" (squelette) → démarre la run → scène de jeu.

const COL_BG: Color = Color("14100C")
const COL_SURFACE: Color = Color("2A2018")
const COL_TEXT: Color = Color("E8DCC0")
const COL_GOLD: Color = Color("C9A24B")
const COL_DIM: Color = Color("9C8C6A")

const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"
const MENU_SCENE: String = "res://scenes/MerlinMenu.tscn"

var _cards_box: HBoxContainer
var _overlay: Panel
var _overlay_lbl: Label
var _busy: bool = false


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
	panel.custom_minimum_size = Vector2(360, 420)
	panel.add_theme_stylebox_override("panel", _surface_style())
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var t: Label = Label.new()
	t.text = title
	t.add_theme_color_override("font_color", COL_GOLD)
	t.add_theme_font_size_override("font_size", 24)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)

	var p: Label = Label.new()
	p.text = pitch
	p.add_theme_color_override("font_color", COL_TEXT)
	p.add_theme_font_size_override("font_size", 16)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(p)

	var b: Button = Button.new()
	b.text = "Suivre ce sentier"
	b.custom_minimum_size = Vector2(0, 48)
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
	get_tree().change_scene_to_file(GAME_SCENE)


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
	title.add_theme_font_size_override("font_size", 34)
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
	_overlay_lbl.add_theme_font_size_override("font_size", 26)
	_overlay.add_child(_overlay_lbl)
	_overlay.visible = false


func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _show_overlay(txt: String) -> void:
	_overlay.visible = true
	_overlay_lbl.text = txt


func _hide_overlay() -> void:
	_overlay.visible = false


func _surface_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_SURFACE
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(20)
	return sb
