## DemoOnboarding — Progressive narrative UI construction (LLM-driven feel).
##
## After IntroCeltOS, this scene plays an "awakening sequence" where Merlin
## (the narrator) speaks and the game UI/UX appears element by element, as if
## generated live by an LLM. Then the 3D forest fades in behind, and the first
## tutorial card explains the mechanics.
##
## Flow (~30s total):
##   0.0s  black screen, faint cursor
##   1.0s  narrator typewriter: "Tu eveilles dans un monde qui se souvient..."
##   3.5s  HUD title fades in: "M.E.R.L.I.N. — Le Jeu des Oghams"
##   6.0s  narrator: "Ta vie tient en cent souffles..." → LifeBar appears
##   9.0s  narrator: "Cinq factions celtiques t'observent..." → Faction badges fade in
##   12.0s narrator: "Les Oghams sont des sorts gravés dans la mémoire..." → Ogham slots
##   15.0s narrator: "Le sentier de Brocéliande s'ouvre devant toi..." → Forest 3D fades in
##   20.0s narrator: "Une présence te regarde..." → First card appears with 3 choices
##   25.0s tutorial hint above buttons: "Choisis A, B ou C"
extends Control

const NARRATION_LINES: Array[Dictionary] = [
	# Merlin l'enchanteur farfelu dessine le monde devant tes yeux
	{"t": 0.5,  "text": "Hoooo ! Te voila ! Bonjour, bonjour, c'est moi, Merlin !", "spawn": "title"},
	{"t": 3.0,  "text": "Attends-moi un instant, je n'ai meme pas encore... pose mon chapeau !", "spawn": ""},
	{"t": 6.0,  "text": "Bon, on va te faire un petit monde, hein ? Tu vas voir, c'est rigolo.", "spawn": ""},
	{"t": 9.0,  "text": "D'abord, du sol ! Une bonne terre noire, tac !", "spawn": "forest_ground"},
	{"t": 12.0, "text": "Un beau vieux chene, parce que sans chene, c'est pas la Bretagne !", "spawn": "forest_oak"},
	{"t": 15.0, "text": "Un menhir grave d'oghams, hop, et un dolmen pour les anciens !", "spawn": "forest_megaliths"},
	{"t": 18.0, "text": "Quelques arbres pour faire joli, abracadabra forestada !", "spawn": "forest_trees"},
	{"t": 21.0, "text": "Une brume verte, evidemment ! C'est mystique, faut que ca brouille !", "spawn": "forest_fog"},
	{"t": 24.0, "text": "Un corbeau qui s'envole, cra cra ! Il connait tous les secrets, lui...", "spawn": "forest_raven"},
	{"t": 27.0, "text": "Maintenant tes outils — ta vie, cent souffles bien sacres :", "spawn": "life"},
	{"t": 30.0, "text": "Cinq Clans celtiques, vise-moi ces tetes d'animaux totems !", "spawn": "factions"},
	{"t": 33.0, "text": "Et trois Oghams, des sorts graves... je t'expliquerai plus tard, mhm.", "spawn": "oghams"},
	{"t": 36.0, "text": "Bon, je t'envoie marcher sur le sentier ! Bouge un peu, mon gaillard !", "spawn": "walker_start"},
	{"t": 39.0, "text": "Oh ! Une presence ! Elle veut te parler. C'est genre une carte d'evenement !", "spawn": "card"},
	{"t": 43.0, "text": "Tu choisis A, B ou C. Le souffle decide ! Allez, fais ton choix...", "spawn": "tutorial_done"},
]

const NARRATION_FONT_COLOR := Color(0.86, 0.72, 0.42)  # celtic_gold
const TYPEWRITER_CHAR_DELAY := 0.04
const FOREST_SCENE_PATH := "res://scenes/BKForestRail.tscn"

var _narrator_label: RichTextLabel
var _title_label: Label
var _life_panel: VBoxContainer
var _life_bar: ProgressBar
var _life_value: Label
var _factions_row: HBoxContainer
var _ogham_row: HBoxContainer
var _card_panel: PanelContainer
var _card_text: Label
var _tutorial_hint: Label
var _btn_a: Button
var _btn_b: Button
var _btn_c: Button
var _forest_layer: Control
var _forest_instance: Node = null
var _line_index: int = 0
var _start_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_layout()
	_start_time = Time.get_ticks_msec() / 1000.0
	_run_sequence()


func _build_layout() -> void:
	# Black background
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Forest 3D layer (instanciated later)
	_forest_layer = Control.new()
	_forest_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_forest_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_forest_layer.modulate = Color(1, 1, 1, 0)
	add_child(_forest_layer)

	# Top title (hidden initially)
	_title_label = Label.new()
	_title_label.text = "M.E.R.L.I.N.  —  Le Jeu des Oghams"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
	_title_label.position = Vector2(40, 36)
	_title_label.modulate = Color(1, 1, 1, 0)
	add_child(_title_label)

	# Narrator typewriter (bottom-center, large band)
	_narrator_label = RichTextLabel.new()
	_narrator_label.bbcode_enabled = true
	_narrator_label.fit_content = true
	_narrator_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_narrator_label.offset_left = 80
	_narrator_label.offset_right = -80
	_narrator_label.offset_top = -180
	_narrator_label.offset_bottom = -80
	_narrator_label.add_theme_font_size_override("normal_font_size", 22)
	_narrator_label.add_theme_color_override("default_color", NARRATION_FONT_COLOR)
	add_child(_narrator_label)

	# Life panel (top-left, hidden initially)
	_life_panel = VBoxContainer.new()
	_life_panel.position = Vector2(40, 90)
	_life_panel.modulate = Color(1, 1, 1, 0)
	add_child(_life_panel)

	var life_title := Label.new()
	life_title.text = "VIE"
	life_title.add_theme_font_size_override("font_size", 14)
	life_title.add_theme_color_override("font_color", Color(0.62, 0.78, 0.58))
	_life_panel.add_child(life_title)

	_life_bar = ProgressBar.new()
	_life_bar.custom_minimum_size = Vector2(220, 14)
	_life_bar.max_value = 100
	_life_bar.value = 100
	_life_bar.show_percentage = false
	_life_panel.add_child(_life_bar)

	_life_value = Label.new()
	_life_value.text = "100 / 100"
	_life_value.add_theme_font_size_override("font_size", 12)
	_life_value.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
	_life_panel.add_child(_life_value)

	# Factions row (top-left below life)
	_factions_row = HBoxContainer.new()
	_factions_row.position = Vector2(40, 170)
	_factions_row.modulate = Color(1, 1, 1, 0)
	_factions_row.add_theme_constant_override("separation", 12)
	add_child(_factions_row)
	for clan in ["Corbeau", "Cerf", "Loup", "Saumon", "Ours"]:
		var badge := Label.new()
		badge.text = "[ " + clan + " ]"
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", Color(0.78, 0.62, 0.36))
		_factions_row.add_child(badge)

	# Ogham slots (top-right)
	_ogham_row = HBoxContainer.new()
	_ogham_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_ogham_row.offset_left = -380
	_ogham_row.offset_top = 90
	_ogham_row.offset_right = -40
	_ogham_row.offset_bottom = 130
	_ogham_row.modulate = Color(1, 1, 1, 0)
	_ogham_row.add_theme_constant_override("separation", 8)
	add_child(_ogham_row)
	for sigil in ["᚛", "᚜", "ᚒ"]:
		var slot := Label.new()
		slot.text = sigil
		slot.add_theme_font_size_override("font_size", 28)
		slot.add_theme_color_override("font_color", Color(0.86, 0.72, 0.42))
		_ogham_row.add_child(slot)

	# Card panel (center, hidden initially)
	_card_panel = PanelContainer.new()
	_card_panel.set_anchors_preset(Control.PRESET_CENTER)
	_card_panel.custom_minimum_size = Vector2(720, 200)
	_card_panel.size = Vector2(720, 200)
	_card_panel.position = Vector2(-360, -260)
	_card_panel.modulate = Color(1, 1, 1, 0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.05, 0.04, 0.90)
	card_style.border_color = Color(0.86, 0.72, 0.42, 0.85)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(20)
	_card_panel.add_theme_stylebox_override("panel", card_style)
	add_child(_card_panel)

	_card_text = Label.new()
	_card_text.text = "Une presence te regarde a travers les fougeres.\nLes pierres dressees vibrent doucement.\nLe vent porte un nom : Cernunnos."
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.add_theme_font_size_override("font_size", 18)
	_card_text.add_theme_color_override("font_color", Color(0.92, 0.86, 0.74))
	_card_panel.add_child(_card_text)

	# Buttons row (below card, hidden initially)
	var btn_row := HBoxContainer.new()
	btn_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	btn_row.offset_left = -340
	btn_row.offset_top = -80
	btn_row.offset_right = 340
	btn_row.offset_bottom = -30
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.modulate = Color(1, 1, 1, 0)
	add_child(btn_row)

	_btn_a = _make_choice_button("A — Observer la presence", Color(0.45, 0.85, 0.55))
	_btn_b = _make_choice_button("B — Approcher en silence", Color(0.95, 0.78, 0.42))
	_btn_c = _make_choice_button("C — Reculer doucement", Color(0.95, 0.45, 0.45))
	btn_row.add_child(_btn_a)
	btn_row.add_child(_btn_b)
	btn_row.add_child(_btn_c)

	# Tutorial hint
	_tutorial_hint = Label.new()
	_tutorial_hint.text = "[ Tutoriel — Choisis A, B ou C ]"
	_tutorial_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tutorial_hint.offset_left = -200
	_tutorial_hint.offset_top = -20
	_tutorial_hint.offset_right = 200
	_tutorial_hint.offset_bottom = 0
	_tutorial_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_hint.add_theme_font_size_override("font_size", 14)
	_tutorial_hint.add_theme_color_override("font_color", Color(0.62, 0.78, 0.58))
	_tutorial_hint.modulate = Color(1, 1, 1, 0)
	add_child(_tutorial_hint)

	# Track which row is which (for reveals)
	_btn_a.get_parent().name = "ChoiceRow"


func _make_choice_button(text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 48)
	b.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.04, 0.92)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	(hover as StyleBoxFlat).bg_color = Color(accent.r * 0.2, accent.g * 0.2, accent.b * 0.2, 0.95)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_color_override("font_color", accent)
	b.pressed.connect(_on_choice_pressed.bind(text))
	return b


func _run_sequence() -> void:
	for line_data in NARRATION_LINES:
		var t: float = float(line_data.t)
		var line_text: String = str(line_data.text)
		var spawn: String = str(line_data.spawn)
		var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _start_time
		var wait: float = t - elapsed
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
		await _typewriter_line(line_text)
		_handle_spawn(spawn)


func _typewriter_line(line_text: String) -> void:
	var prefix := "[color=#888]>[/color] "
	_narrator_label.text = prefix
	for i in range(line_text.length()):
		_narrator_label.text = prefix + line_text.substr(0, i + 1)
		await get_tree().create_timer(TYPEWRITER_CHAR_DELAY).timeout
	await get_tree().create_timer(0.4).timeout


func _handle_spawn(spawn: String) -> void:
	match spawn:
		"title":
			_fade_in_node(_title_label, 0.6)
		"life":
			_fade_in_node(_life_panel, 0.5)
		"factions":
			_fade_in_node(_factions_row, 0.5)
		"oghams":
			_fade_in_node(_ogham_row, 0.5)
		"forest_ground":
			_instantiate_forest_layer()
			_reveal_forest_asset("Ground")
			_reveal_forest_asset("Floor")
		"forest_oak":
			_reveal_forest_asset("MerlinOak")
		"forest_megaliths":
			_reveal_forest_asset("MenhirOgham")
			_reveal_forest_asset("Dolmen")
			_reveal_forest_asset("DruidAltar")
			_reveal_forest_asset("Menhir")
		"forest_trees":
			for n in ["Tree_A_01", "Tree_A_02", "Tree_B_01", "Tree_B_02",
					"Tree_C_01", "Tree_C_02", "Tree_D_01",
					"FallenTrunk", "GiantMushroom", "BKMushroom_01", "BKMushroom_02"]:
				_reveal_forest_asset(n)
		"forest_fog":
			_enable_forest_fog()
		"forest_raven":
			_reveal_forest_asset("GiantRaven")
		"walker_start":
			_start_forest_walk()
		"card":
			_fade_in_node(_card_panel, 0.6)
			_fade_in_node(_btn_a.get_parent(), 0.6)
		"tutorial_done":
			_fade_in_node(_tutorial_hint, 0.4)
		_:
			pass


func _fade_in_node(node: CanvasItem, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)


func _instantiate_forest_layer() -> void:
	if _forest_instance != null:
		return
	var packed: PackedScene = load(FOREST_SCENE_PATH)
	if packed == null:
		push_warning("[DemoOnboarding] Cannot load " + FOREST_SCENE_PATH)
		return
	_forest_instance = packed.instantiate()
	_forest_layer.add_child(_forest_instance)
	# Hide the rail's own HUD (we provide our own narrative HUD)
	var rail_hud: Node = _forest_instance.get_node_or_null("HUD")
	if rail_hud:
		rail_hud.visible = false
	# Hide all forest assets initially — Merlin will reveal them one by one
	var forest_node: Node = _forest_instance.get_node_or_null("Forest")
	if forest_node:
		for child in forest_node.get_children():
			if child is Node3D:
				child.visible = false
	# Pause auto-walk until "walker_start" spawn step
	var walker_anim: AnimationPlayer = _forest_instance.get_node_or_null("WalkerAnimation")
	if walker_anim:
		walker_anim.pause()
	# Soft fade-in of the layer (the world appears, but assets are hidden)
	_fade_in_node(_forest_layer, 1.0)


func _reveal_forest_asset(asset_name: String) -> void:
	if _forest_instance == null:
		return
	var forest_node: Node = _forest_instance.get_node_or_null("Forest")
	if forest_node == null:
		return
	var asset: Node = forest_node.get_node_or_null(asset_name)
	if asset == null or not (asset is Node3D):
		return
	asset.visible = true
	# "Pop in" feel: scale from 0 to 1 with a tiny back-bounce
	var node3d: Node3D = asset
	var target_scale: Vector3 = node3d.scale
	node3d.scale = target_scale * 0.01
	var tw := create_tween()
	tw.tween_property(node3d, "scale", target_scale, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _enable_forest_fog() -> void:
	if _forest_instance == null:
		return
	var we: WorldEnvironment = _forest_instance.get_node_or_null("WorldEnvironment")
	if we == null or we.environment == null:
		return
	# Soft animated fog density bump for the "Merlin sprinkles fog" feel
	var env: Environment = we.environment
	var start_density: float = env.fog_density
	env.fog_density = 0.0
	var tw := create_tween()
	tw.tween_property(env, "fog_density", start_density, 1.6).set_trans(Tween.TRANS_SINE)


func _start_forest_walk() -> void:
	if _forest_instance == null:
		return
	var walker_anim: AnimationPlayer = _forest_instance.get_node_or_null("WalkerAnimation")
	if walker_anim == null:
		return
	walker_anim.play(&"auto_walk")


func _on_choice_pressed(choice_label: String) -> void:
	_tutorial_hint.text = "[ " + choice_label.split(" — ")[0] + " choisi — la suite arrive bientot... ]"
	# Future: handoff to MerlinGame proper run loop
