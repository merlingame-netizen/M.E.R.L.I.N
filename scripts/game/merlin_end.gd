extends Control
## MerlinEnd — écran de fin (bible R69). Épilogue généré (LLM) selon le type de fin
## + état final + bouton Continuer → menu. La run terminée efface sa sauvegarde de reprise.

const COL_BG: Color = Color("14100C")
const COL_SURFACE: Color = Color("2A2018")
const COL_TEXT: Color = Color("E8DCC0")
const COL_GOLD: Color = Color("C9A24B")
const COL_GREEN: Color = Color("7FA65C")
const COL_VIOLET: Color = Color("7B4FA3")
const COL_DIM: Color = Color("9C8C6A")

const MENU_SCENE: String = "res://scenes/MerlinMenu.tscn"

const END_TITLES: Dictionary = {
	"accomplissement": "Accomplissement",
	"mort": "Mort narrative",
	"corrompu": "Bascule corrompue",
}

var _title_lbl: Label
var _epilogue: RichTextLabel
var _state_lbl: Label
var _continue_btn: Button
var _tw: Tween


func _ready() -> void:
	_build_ui()
	call_deferred("_run_end")


func _run_end() -> void:
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
	_bg_epilogue(et, run.to_state_dict())


func _bg_epilogue(et: String, state: Dictionary) -> void:
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	if sc == null:
		return
	var epi: String = await sc.narrate_epilogue(et, state)
	if epi.length() < 10 or not is_inside_tree():
		return
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

	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_SURFACE
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	_epilogue = RichTextLabel.new()
	_epilogue.bbcode_enabled = true
	_epilogue.add_theme_color_override("default_color", COL_TEXT)
	_epilogue.add_theme_font_size_override("normal_font_size", 21)
	panel.add_child(_epilogue)

	_state_lbl = Label.new()
	_state_lbl.add_theme_color_override("font_color", COL_DIM)
	_state_lbl.add_theme_font_size_override("font_size", 16)
	_state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_state_lbl)

	_continue_btn = Button.new()
	_continue_btn.text = "Continuer ▶"
	_continue_btn.custom_minimum_size = Vector2(220, 48)
	_continue_btn.disabled = true
	_continue_btn.pressed.connect(_on_continue)
	root.add_child(_continue_btn)


func _on_continue() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _typewriter(txt: String, animate: bool = true) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null
	_epilogue.text = txt
	if not animate:
		_epilogue.visible_characters = -1  # tout révélé (swap d'enrichissement)
		return
	_epilogue.visible_characters = 0
	var n: int = _epilogue.get_total_character_count()
	if n <= 0:
		return
	_tw = create_tween()
	_tw.tween_property(_epilogue, "visible_characters", n, clampf(float(n) / 55.0, 0.5, 6.0))
