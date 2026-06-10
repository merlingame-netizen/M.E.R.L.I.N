extends Control
## MerlinOptions — écran Options (bible R74). MVP : contrôles présents + retour.
## (Câblage effectif audio/vitesse/accessibilité = polish post-MVP.)

const COL_BG: Color = MerlinVisual.BG_DEEP
const COL_TEXT: Color = MerlinVisual.CREAM
const COL_GOLD: Color = MerlinVisual.GOLD
const COL_DIM: Color = MerlinVisual.DIM_WARM

const MENU_SCENE: String = "res://scenes/MerlinMenu.tscn"


func _ready() -> void:
	_build_ui()


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
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var title: Label = Label.new()
	title.text = "Options"
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 34)
	root.add_child(title)

	root.add_child(_slider_row("Volume Maître", 80))
	root.add_child(_slider_row("Musique", 70))
	root.add_child(_slider_row("Effets sonores", 80))
	root.add_child(_slider_row("Vitesse du texte", 60))
	root.add_child(_check_row("Réduire les animations / glitch", false))
	root.add_child(_check_row("Contraste renforcé", false))
	root.add_child(_check_row("Police lisible (dys)", false))

	var lang: Label = Label.new()
	lang.text = "Langue : Français (multi-langue = post-MVP)"
	lang.add_theme_color_override("font_color", COL_DIM)
	lang.add_theme_font_size_override("font_size", 15)
	root.add_child(lang)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	var back: Button = Button.new()
	back.text = "◀ Retour"
	back.custom_minimum_size = Vector2(160, 48)
	back.pressed.connect(_on_back)
	root.add_child(back)


func _slider_row(label: String, value: float) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var l: Label = Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(280, 0)
	l.add_theme_color_override("font_color", COL_TEXT)
	l.add_theme_font_size_override("font_size", 17)
	row.add_child(l)
	var s: HSlider = HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.value = value
	s.custom_minimum_size = Vector2(320, 44)
	row.add_child(s)
	return row


func _check_row(label: String, on: bool) -> CheckButton:
	var c: CheckButton = CheckButton.new()
	c.text = label
	c.button_pressed = on
	c.custom_minimum_size = Vector2(0, 44)
	c.add_theme_color_override("font_color", COL_TEXT)
	return c


func _on_back() -> void:
	MerlinTransition.change_scene(MENU_SCENE)
