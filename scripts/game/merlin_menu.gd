extends Control
## MerlinMenu — écran-titre (bible R73). Nouvelle partie / Continuer / Options / Quitter
## + accès console debug Gemma (jalon 0). Palette parchemin sombre (R70).

const COL_BG: Color = Color("14100C")
const COL_TEXT: Color = Color("E8DCC0")
const COL_GOLD: Color = Color("C9A24B")
const COL_DIM: Color = Color("9C8C6A")

const SELECTION_SCENE: String = "res://scenes/MerlinSelection.tscn"
const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"
const OPTIONS_SCENE: String = "res://scenes/MerlinOptions.tscn"
const CONSOLE_SCENE: String = "res://scenes/GemmaConsole.tscn"


func _ready() -> void:
	_build_ui()
	# Le LLM chauffe + pré-génère les 3 scénarios DÈS le menu (avant le clic Nouvelle Partie).
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null:
		if mn.is_ready():
			_trigger_warmup()
		elif not mn.model_ready.is_connected(_trigger_warmup):
			mn.model_ready.connect(_trigger_warmup)


func _trigger_warmup() -> void:
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	if sc != null:
		sc.warmup_and_prefetch_selection()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center: VBoxContainer = VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	center.anchor_left = 0.5
	center.anchor_top = 0.5
	center.anchor_right = 0.5
	center.anchor_bottom = 0.5
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(center)

	var title: Label = Label.new()
	title.text = "M.E.R.L.I.N."
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)

	var sub: Label = Label.new()
	sub.text = "Brocéliande — un voyageur, une forêt qui rêve, un Graal."
	sub.add_theme_color_override("font_color", COL_DIM)
	sub.add_theme_font_size_override("font_size", 17)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(sub)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	center.add_child(spacer)

	center.add_child(_menu_button("Nouvelle partie", _on_new))
	var cont_btn: Button = _menu_button("Continuer", _on_continue)
	cont_btn.disabled = not get_node("/root/MerlinRun").has_save()
	center.add_child(cont_btn)
	center.add_child(_menu_button("Options", _on_options))
	center.add_child(_menu_button("Console Gemma (debug)", _on_console))
	center.add_child(_menu_button("Quitter", _on_quit))


func _menu_button(txt: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(360, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b


func _on_new() -> void:
	MerlinTransition.change_scene(SELECTION_SCENE)


func _on_continue() -> void:
	var run: Node = get_node("/root/MerlinRun")
	if run.has_save() and run.load_run():
		MerlinTransition.change_scene(GAME_SCENE)


func _on_options() -> void:
	if ResourceLoader.exists(OPTIONS_SCENE):
		MerlinTransition.change_scene(OPTIONS_SCENE)


func _on_console() -> void:
	if ResourceLoader.exists(CONSOLE_SCENE):
		MerlinTransition.change_scene(CONSOLE_SCENE)


func _on_quit() -> void:
	get_tree().quit()
