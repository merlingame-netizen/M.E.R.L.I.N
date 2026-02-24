extends Control
## Test scene for CardSceneCompositor — layered sprite generation.
## Displays a mock card with text + visual_tags, and the layered illustration.
## Cycle through presets with A/D keys, period with W, weather with E.

const CardSceneCompositorClass = preload("res://scripts/ui/card_scene_compositor.gd")

# ── UI refs ────────────────────────────────────────────────────────────────────
var _compositor = null  ## CardSceneCompositor (untyped for dynamic dispatch)
var _text_label: RichTextLabel = null
var _tags_label: Label = null
var _info_label: Label = null
var _biome_label: Label = null
var _period_label: Label = null

# ── Test presets ───────────────────────────────────────────────────────────────
var _presets: Array[Dictionary] = []
var _current_preset: int = 0

# ── Period / Weather cycling ──────────────────────────────────────────────────
const PERIODS: Array[String] = ["aube", "jour", "crepuscule", "nuit"]
const WEATHERS: Array[String] = ["clair", "brume", "pluie", "orage", "neige"]
var _period_idx: int = 1  ## Start at "jour"
var _weather_idx: int = 0  ## Start at "clair"

func _ready() -> void:
	_build_presets()
	_build_ui()
	_load_preset(0)


func _build_presets() -> void:
	_presets = [
		{
			"name": "Broceliande — Foret brume",
			"text": "Les arbres centenaires murmurent dans la brume matinale. Un sentier sinueux s'enfonce dans l'obscurite verte de Broceliande.",
			"visual_tags": ["foret", "arbres", "brume", "sentier"],
			"biome": "foret_broceliande",
			"season": "automne",
		},
		{
			"name": "Broceliande — Combat loup",
			"text": "Un grondement sourd fait trembler les fougeres. Deux yeux jaunes percent la penombre. Le loup de Broceliande vous a repere.",
			"visual_tags": ["loup", "danger", "combat", "foret"],
			"biome": "foret_broceliande",
			"season": "hiver",
		},
		{
			"name": "Broceliande — Cercle sacre",
			"text": "Les pierres dressees vibrent d'une energie ancienne. L'ogham grave dans la roche s'illumine doucement sous vos doigts.",
			"visual_tags": ["pierres", "sacre", "dolmen", "magie"],
			"biome": "foret_broceliande",
			"season": "printemps",
		},
		{
			"name": "Marais — Brume epaisse",
			"text": "L'eau noire du marais reflete un ciel plombe. Des bulles eclatent a la surface, liberant une odeur de tourbe.",
			"visual_tags": ["marais", "brume", "eau", "mystere"],
			"biome": "marais_korrigans",
			"season": "automne",
		},
		{
			"name": "Marais — Korrigan",
			"text": "Une petite silhouette danse entre les roseaux. Le korrigan vous fait signe d'approcher.",
			"visual_tags": ["korrigan", "rencontre", "danse", "malice"],
			"biome": "marais_korrigans",
			"season": "ete",
		},
		{
			"name": "Marais — Feux-follets nocturne",
			"text": "Des lumieres flottent au-dessus de l'eau stagnante. Les feux-follets vous attirent vers les profondeurs.",
			"visual_tags": ["feux_follets", "nocturne", "spectre", "ame"],
			"biome": "marais_korrigans",
			"season": "hiver",
		},
		{
			"name": "Broceliande — Cerf noble",
			"text": "Le grand cerf blanc emerge de la clairiere. Ses bois portent les runes anciennes des druides.",
			"visual_tags": ["cerf", "noble", "nature", "monde"],
			"biome": "foret_broceliande",
			"season": "printemps",
		},
		{
			"name": "Marais — Pluie rituel",
			"text": "La pluie tombe en rideaux sur le marais. Un autel de pierre affleure, couvert de mousse.",
			"visual_tags": ["pluie", "rituel", "sacre", "autel"],
			"biome": "marais_korrigans",
			"season": "automne",
		},
		{
			"name": "Landes — Druide solitaire",
			"text": "Le druide se dresse au sommet de la lande, sa robe fouettee par le vent. Son baton irradie.",
			"visual_tags": ["druide", "bruyere", "vent", "magie"],
			"biome": "landes_bruyere",
			"season": "automne",
		},
		{
			"name": "Cotes — Barque fantome",
			"text": "Une barque echouee sur les rochers. Le bois est pourri mais des runes brillent encore sur la proue.",
			"visual_tags": ["barque", "roche", "rune", "brume"],
			"biome": "cotes_sauvages",
			"season": "hiver",
		},
		{
			"name": "Villages — Forgeron guerrier",
			"text": "Le forgeron pose son marteau. Les epees qu'il a forgees brillent dans la penombre de l'atelier.",
			"visual_tags": ["guerrier", "epee", "feu", "village"],
			"biome": "villages_celtes",
			"season": "ete",
		},
		{
			"name": "Cercles — Couronne ancienne",
			"text": "Au centre du cercle de pierres, une couronne d'or repose sur un autel. Les ogham s'illuminent.",
			"visual_tags": ["couronne", "menhir", "ogham", "lumiere"],
			"biome": "cercles_pierres",
			"season": "printemps",
		},
		{
			"name": "Collines — Campement nuit",
			"text": "Le feu de camp crepite sous les etoiles. La harpe du barde resonne dans la nuit des collines.",
			"visual_tags": ["camp", "harpe", "feu", "nuit"],
			"biome": "collines_dolmens",
			"season": "ete",
		},
		{
			"name": "Iles — Fee lumineuse",
			"text": "Sur les iles mystiques, des fees dansent au-dessus des eaux. Leur lumiere guide les ames perdues.",
			"visual_tags": ["fee", "lumiere", "eau", "ame"],
			"biome": "iles_mystiques",
			"season": "printemps",
		},
		{
			"name": "Broceliande — Spectre crane",
			"text": "Les ossements craquent sous vos pas. Un spectre se materialise au-dessus du crane ancien.",
			"visual_tags": ["spectre", "crane", "mort", "grimoire"],
			"biome": "foret_broceliande",
			"season": "hiver",
		},
		{
			"name": "Landes — Potion alchimie",
			"text": "La sorciere des landes prepare un breuvage etrange. La potion bouillonne dans le chaudron.",
			"visual_tags": ["potion", "champignon", "bruyere", "lanterne"],
			"biome": "landes_bruyere",
			"season": "automne",
		},
	]


func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = MerlinVisual.CRT_PALETTE.bg_deep
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Main layout: VBox
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.set_anchor_and_offset(SIDE_LEFT, 0, 20)
	vbox.set_anchor_and_offset(SIDE_RIGHT, 1, -20)
	vbox.set_anchor_and_offset(SIDE_TOP, 0, 20)
	vbox.set_anchor_and_offset(SIDE_BOTTOM, 1, -20)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "TEST: CardSceneCompositor — 8 Biomes, Period/Weather"
	title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_bright)
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# Preset info
	_biome_label = Label.new()
	_biome_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	_biome_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_biome_label)

	# Period / Weather label
	_period_label = Label.new()
	_period_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.cyan_bright)
	_period_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_period_label)

	# HBox: illustration + text
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	# Left: illustration panel (card compositor)
	var illo_panel := PanelContainer.new()
	illo_panel.custom_minimum_size = Vector2(460, 240)
	var illo_style := StyleBoxFlat.new()
	illo_style.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
	illo_style.border_color = MerlinVisual.CRT_PALETTE.border
	illo_style.set_border_width_all(2)
	illo_style.set_corner_radius_all(4)
	illo_style.set_content_margin_all(10)
	illo_panel.add_theme_stylebox_override("panel", illo_style)
	hbox.add_child(illo_panel)

	# Compositor inside panel
	_compositor = CardSceneCompositorClass.new()
	_compositor.name = "TestCompositor"
	_compositor.setup(Vector2(440.0, 220.0))
	illo_panel.add_child(_compositor)

	# Right: text panel
	var text_panel := PanelContainer.new()
	text_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	var text_style := StyleBoxFlat.new()
	text_style.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
	text_style.border_color = MerlinVisual.CRT_PALETTE.border
	text_style.set_border_width_all(1)
	text_style.set_corner_radius_all(4)
	text_style.set_content_margin_all(12)
	text_panel.add_theme_stylebox_override("panel", text_style)
	hbox.add_child(text_panel)

	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 8)
	text_panel.add_child(text_vbox)

	var text_header := Label.new()
	text_header.text = "Texte narratif:"
	text_header.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_dim)
	text_header.add_theme_font_size_override("font_size", 13)
	text_vbox.add_child(text_header)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.size_flags_vertical = SIZE_EXPAND_FILL
	_text_label.add_theme_color_override("default_color", MerlinVisual.CRT_PALETTE.phosphor)
	_text_label.add_theme_font_size_override("normal_font_size", 15)
	text_vbox.add_child(_text_label)

	# Tags display
	_tags_label = Label.new()
	_tags_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.cyan)
	_tags_label.add_theme_font_size_override("font_size", 12)
	_tags_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_tags_label)

	# Info label
	_info_label = Label.new()
	_info_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	_info_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_info_label)

	# Navigation buttons row 1
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_hbox)

	var btn_prev := Button.new()
	btn_prev.text = "< Prev (A)"
	btn_prev.pressed.connect(_prev_preset)
	_style_button(btn_prev)
	btn_hbox.add_child(btn_prev)

	var btn_next := Button.new()
	btn_next.text = "Next (D) >"
	btn_next.pressed.connect(_next_preset)
	_style_button(btn_next)
	btn_hbox.add_child(btn_next)

	var btn_reload := Button.new()
	btn_reload.text = "Reload (R)"
	btn_reload.pressed.connect(func() -> void: _load_preset(_current_preset))
	_style_button(btn_reload)
	btn_hbox.add_child(btn_reload)

	var btn_random := Button.new()
	btn_random.text = "Random Tags"
	btn_random.pressed.connect(_random_tags)
	_style_button(btn_random)
	btn_hbox.add_child(btn_random)

	# Row 2: Period / Weather cycle buttons
	var btn_hbox2 := HBoxContainer.new()
	btn_hbox2.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_hbox2)

	var btn_period := Button.new()
	btn_period.text = "Period (W)"
	btn_period.pressed.connect(_cycle_period)
	_style_button(btn_period)
	btn_hbox2.add_child(btn_period)

	var btn_weather := Button.new()
	btn_weather.text = "Weather (E)"
	btn_weather.pressed.connect(_cycle_weather)
	_style_button(btn_weather)
	btn_hbox2.add_child(btn_weather)


func _style_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE.bg_highlight
	style.border_color = MerlinVisual.CRT_PALETTE.phosphor_dim
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	btn.add_theme_font_size_override("font_size", 13)


func _load_preset(idx: int) -> void:
	_current_preset = idx % _presets.size()
	var preset: Dictionary = _presets[_current_preset]
	var cur_period: String = PERIODS[_period_idx]
	var cur_weather: String = WEATHERS[_weather_idx]

	# Update labels
	_biome_label.text = "[%d/%d] %s" % [_current_preset + 1, _presets.size(), str(preset.name)]
	_text_label.text = str(preset.text)

	_period_label.text = "Period: %s  |  Weather: %s  |  Season: %s" % [
		cur_period.to_upper(), cur_weather.to_upper(), str(preset.season)]

	var tags: Array = preset.get("visual_tags", [])
	_tags_label.text = "tags: [%s]  |  biome: %s" % [
		", ".join(tags.map(func(t: Variant) -> String: return str(t))),
		str(preset.biome)]

	# Compose and build layers with period + weather
	_compositor.compose_layers(tags, str(preset.biome), str(preset.season),
		"narrative", cur_period, cur_weather)
	_compositor.build_scene(true)

	# Info about layers generated
	var layer_count: int = _compositor._layer_configs.size()
	var layer_types: Array = []
	for config in _compositor._layer_configs:
		match config.type:
			0: layer_types.append("SKY")
			1: layer_types.append("TERRAIN")
			2: layer_types.append("SUBJECT")
			3: layer_types.append("ATMOSPHERE")
	_info_label.text = "Layers: %d [%s]  |  A/D=preset  W=period  E=weather  R=reload  Space=random" % [
		layer_count, ", ".join(layer_types)]


func _next_preset() -> void:
	_load_preset(_current_preset + 1)


func _prev_preset() -> void:
	_load_preset((_current_preset - 1 + _presets.size()) % _presets.size())


func _cycle_period() -> void:
	_period_idx = (_period_idx + 1) % PERIODS.size()
	_load_preset(_current_preset)


func _cycle_weather() -> void:
	_weather_idx = (_weather_idx + 1) % WEATHERS.size()
	_load_preset(_current_preset)


func _random_tags() -> void:
	## Generate random tag combination from the full vocabulary.
	var all_tags: Array = [
		"foret", "arbres", "brume", "sentier", "loup", "danger", "combat",
		"pierres", "sacre", "dolmen", "magie", "marais", "eau", "mystere",
		"korrigan", "rencontre", "danse", "feux_follets", "nocturne", "spectre",
		"ame", "cerf", "noble", "nature", "monde", "pluie", "rituel", "corbeau",
		"presage", "repos", "feu", "camp", "nuit", "druide", "guerrier",
		"barque", "potion", "harpe", "crane", "fee", "autel", "couronne",
	]
	all_tags.shuffle()
	var count: int = randi_range(2, 5)
	var random_tags: Array = all_tags.slice(0, count)
	var biomes: Array = [
		"foret_broceliande", "marais_korrigans", "landes_bruyere",
		"cotes_sauvages", "villages_celtes", "cercles_pierres",
		"collines_dolmens", "iles_mystiques",
	]
	var seasons: Array = ["printemps", "ete", "automne", "hiver"]

	var preset := {
		"name": "RANDOM — %s" % ", ".join(random_tags.map(func(t: Variant) -> String: return str(t))),
		"text": "Generation aleatoire. Tags: %s" % str(random_tags),
		"visual_tags": random_tags,
		"biome": biomes[randi() % biomes.size()],
		"season": seasons[randi() % seasons.size()],
	}
	_presets.append(preset)
	_load_preset(_presets.size() - 1)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_D, KEY_RIGHT:
				_next_preset()
			KEY_A, KEY_LEFT:
				_prev_preset()
			KEY_W, KEY_UP:
				_cycle_period()
			KEY_E, KEY_DOWN:
				_cycle_weather()
			KEY_R:
				_load_preset(_current_preset)
			KEY_SPACE:
				_random_tags()
			KEY_ESCAPE:
				get_tree().quit()


func _process(_delta: float) -> void:
	## Feed mouse position to compositor for parallax test.
	if _compositor and is_instance_valid(_compositor):
		var mouse_pos: Vector2 = _compositor.get_local_mouse_position()
		var comp_size: Vector2 = _compositor.size
		if comp_size.x > 10.0 and comp_size.y > 10.0:
			var in_bounds := Rect2(Vector2.ZERO, comp_size).has_point(mouse_pos)
			if in_bounds:
				var tilt := Vector2(
					clampf((mouse_pos.x / comp_size.x - 0.5) * 2.0, -1.0, 1.0),
					clampf((mouse_pos.y / comp_size.y - 0.5) * 2.0, -1.0, 1.0))
				_compositor.apply_parallax(tilt)
			else:
				_compositor.apply_parallax(Vector2.ZERO)
