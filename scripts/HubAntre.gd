## =============================================================================
## HubAntre -- L'Antre Vivant (Spatial Hub)
## =============================================================================
## Immersive spatial hub with procedural pixel art UI.
## 4 hotspots, MerlinBubble greeting,
## PARTIR button -> BiomeRadial -> adventure launch.
## Zero permanent text. All animated.
## =============================================================================

extends Control

# =============================================================================
# SCENE NAVIGATION
# =============================================================================

const SCENE_TRANSITION := "res://scenes/TransitionBiome.tscn"
const SCENE_FOREST := "res://scenes/BroceliandeForest3D.tscn"
const SCENE_OPTIONS := "res://scenes/MenuOptions.tscn"
const SCENE_CALENDAR := "res://scenes/Calendar.tscn"
const SCENE_COLLECTION := "res://scenes/Collection.tscn"
const SCENE_ARBRE := "res://scenes/ArbreDeVie.tscn"
const SCENE_MENU := "res://scenes/Menu3DPC.tscn"
const SCENE_MAPMONDE := "res://scenes/MapMonde.tscn"

# =============================================================================
# BIOME DATA -- 7 Sanctuaires de Bretagne
# =============================================================================

var BIOME_DATA := {
	"foret_broceliande": {
		"name": "Foret de Broceliande",
		"subtitle": "Mystere et magie ancestrale",
		"color": MerlinVisual.GBC.grass_dark,
		"ogham": "duir",
		"guardian": "Maelgwn",
		"season": "automne",
		"difficulty_label": "Normal",
	},
	"landes_bruyere": {
		"name": "Landes de Bruyere",
		"subtitle": "Solitude et endurance",
		"color": MerlinVisual.CRT_PALETTE.phosphor_dim,
		"ogham": "onn",
		"guardian": "Talwen",
		"season": "hiver",
		"difficulty_label": "Difficile",
	},
	"cotes_sauvages": {
		"name": "Cotes Sauvages",
		"subtitle": "L'ocean murmurant",
		"color": MerlinVisual.GBC.water,
		"ogham": "nuin",
		"guardian": "Bran",
		"season": "ete",
		"difficulty_label": "Normal",
	},
	"villages_celtes": {
		"name": "Villages Celtes",
		"subtitle": "Flammes obstinees de l'humanite",
		"color": MerlinVisual.GBC.fire,
		"ogham": "gort",
		"guardian": "Azenor",
		"season": "printemps",
		"difficulty_label": "Facile",
	},
	"cercles_pierres": {
		"name": "Cercles de Pierres",
		"subtitle": "Ou le temps hesite",
		"color": MerlinVisual.CRT_PALETTE.inactive,
		"ogham": "huath",
		"guardian": "Keridwen",
		"season": "samhain",
		"difficulty_label": "Difficile",
	},
	"marais_korrigans": {
		"name": "Marais des Korrigans",
		"subtitle": "Deception et feux follets",
		"color": MerlinVisual.GBC.grass_dark,
		"ogham": "muin",
		"guardian": "Gwydion",
		"season": "lughnasadh",
		"difficulty_label": "Tres difficile",
	},
	"collines_dolmens": {
		"name": "Collines aux Dolmens",
		"subtitle": "Les os de la terre",
		"color": MerlinVisual.CRT_PALETTE.border_bright,
		"ogham": "ioho",
		"guardian": "Elouan",
		"season": "yule",
		"difficulty_label": "Normal",
	},
	"iles_mystiques": {
		"name": "Iles Mystiques",
		"subtitle": "Au-dela des brumes",
		"color": MerlinVisual.CRT_PALETTE["biome_iles"],
		"ogham": "ailm",
		"guardian": "Morgane",
		"season": "samhain",
		"difficulty_label": "Legendaire",
	},
}

# =============================================================================
# BIOME MISSIONS -- Procedural mission pool per biome
# =============================================================================

const BIOME_MISSIONS := {
	"foret_broceliande": [
		{"type": "discovery", "target": "Trouver la Source de Barenton", "total": 8},
		{"type": "alliance", "target": "Ecouter les murmures des arbres anciens", "total": 6},
	],
	"landes_bruyere": [
		{"type": "survival", "target": "Traverser les landes sans faillir", "total": 10},
		{"type": "recovery", "target": "Rallumer le feu de Talwen", "total": 7},
	],
	"cotes_sauvages": [
		{"type": "discovery", "target": "Dechiffrer les vagues de Bran", "total": 8},
		{"type": "alliance", "target": "Calmer les marees errantes", "total": 6},
	],
	"villages_celtes": [
		{"type": "alliance", "target": "Reunir les villages epars", "total": 9},
		{"type": "recovery", "target": "Soigner les fievres d'Azenor", "total": 7},
	],
	"cercles_pierres": [
		{"type": "discovery", "target": "Reveler le chant des menhirs", "total": 8},
		{"type": "survival", "target": "Resister au silence de Keridwen", "total": 10},
	],
	"marais_korrigans": [
		{"type": "survival", "target": "Echapper aux feux follets", "total": 12},
		{"type": "discovery", "target": "Percer les illusions de Gwydion", "total": 8},
	],
	"collines_dolmens": [
		{"type": "recovery", "target": "Apaiser les ancetres d'Elouan", "total": 9},
		{"type": "alliance", "target": "Restaurer les liens ancestraux", "total": 7},
	],
	"iles_mystiques": [
		{"type": "discovery", "target": "Trouver le passage vers Avalon", "total": 12},
		{"type": "survival", "target": "Resister aux chants des selkies", "total": 10},
	],
}

# =============================================================================
# MERLIN GREETINGS -- Contextual dialogue lines
# =============================================================================

const MERLIN_GREETINGS := {
	"first_hub": [
		"Bienvenue, %s. Le feu t'attendait.",
		"Entre, %s. Le feu ronronne.",
	],
	"return": [
		"Te revoila, %s !",
		"De retour, %s.",
		"Ah, %s. Toujours debout.",
	],
	"after_fall": [
		"Chaque chute enseigne, %s.",
		"Encore toi, %s ? Bien.",
		"On se releve, %s.",
	],
	"veteran": [
		"Tu connais le chemin, %s.",
		"%s. Qui guide qui ?",
		"Les pierres te reconnaissent, %s.",
	],
}

# =============================================================================
# HOTSPOT CONFIG (icon indices: 0=MOON, 1=TREE, 2=BOOK, 3=GEAR, 4=COMPASS)
# =============================================================================

const HOTSPOT_DEFS := [
	# 2 coins : Calendar (haut-gauche) + Options (haut-droite)
	{"name": "calendar",   "icon": 0, "label": "Calendrier",  "palette_key": "amber_bright", "ratio": Vector2(0.04, 0.06)},
	{"name": "options",    "icon": 3, "label": "Options",      "palette_key": "phosphor_dim", "ratio": Vector2(0.88, 0.06)},
	# 4 centraux : Arbre de Vie | Memoires | Collection | Journal
	{"name": "arbre",      "icon": 1, "label": "Arbre de Vie", "palette_key": "phosphor_dim", "ratio": Vector2(0.15, 0.38)},
	{"name": "memoires",   "icon": 4, "label": "Memoires",     "palette_key": "cyan_dim",     "ratio": Vector2(0.38, 0.38)},
	{"name": "collection", "icon": 2, "label": "Collection",   "palette_key": "amber_dim",    "ratio": Vector2(0.61, 0.38)},
	{"name": "journal",    "icon": 5, "label": "Vies Passees", "palette_key": "amber_dim",    "ratio": Vector2(0.84, 0.38)},
]

# =============================================================================
# SCENE NODES (from .tscn)
# =============================================================================

@onready var parchment_bg: ColorRect = $ParchmentBg
@onready var mist_layer: ColorRect = $MistLayer

# =============================================================================
# DYNAMIC NODES
# =============================================================================

var _bubble: MerlinBubble = null
var _radial: BiomeRadial = null
var _partir_btn: Button = null
var _hotspots: Array = []
var _chronicle_label: Label = null
var _meta_label: Label = null
var _scanline_overlay: ColorRect = null
var _ambient_particles: Array = []
var _ambient_t: float = 0.0
var _tour: HubAntreTour = null

# =============================================================================
# STATE
# =============================================================================

var store: MerlinStore = null
var selected_biome: String = ""
var chronicle_name: String = "Voyageur"
var player_class: String = "eclaireur"
var _current_mission: Dictionary = {}
var _is_first_hub: bool = true
var _passive_llm_pending: bool = false
var _mist_tween: Tween
var _partir_hover_tween: Tween

# Status dashboard
var _dashboard_panel: PanelContainer = null
var _faction_bars: Array = []
var _anam_label_dash: Label = null
var _oghams_label: Label = null

# Audio
var voicebox: Node = null
var voice_ready: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_connect_store()
	_load_player_data()
	_configure_background()
	_create_scanline_overlay()
	_create_chronicle_header()
	_create_status_dashboard()
	_create_hotspots()
	_create_partir_button()
	_create_bubble()
	_create_radial()
	_setup_voicebox()
	_sync_from_state()

	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("warm")

	resized.connect(_layout_all)
	_start_mist_animation()
	_play_entry_animation.call_deferred()

	await get_tree().create_timer(1.2).timeout
	if _is_first_hub:
		_show_first_time_welcome()
	else:
		_show_greeting()

	# Hub guided tour for first-time players (after IntroTutorial)
	var gm_tour := get_node_or_null("/root/GameManager")
	if gm_tour and gm_tour.flags.get("hub_tour_pending", false):
		_tour = HubAntreTour.new(self)
		_tour.run_tour.call_deferred(_hotspots, _partir_btn, _bubble, chronicle_name)


# =============================================================================
# SETUP
# =============================================================================

func _connect_store() -> void:
	store = get_node_or_null("/root/MerlinStore")
	if store and store.has_signal("reputation_changed"):
		store.reputation_changed.connect(_on_reputation_changed)


func _load_player_data() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var run_data = gm.get("run")
		if run_data is Dictionary:
			var profile: Dictionary = run_data.get("traveler_profile", {})
			player_class = profile.get("class", "eclaireur")
			chronicle_name = run_data.get("chronicle_name", "Voyageur")

	selected_biome = ""

	if store:
		_is_first_hub = not store.state.get("flags", {}).get("hub_visited", false)


func _configure_background() -> void:
	parchment_bg.material = null
	parchment_bg.color = MerlinVisual.CRT_PALETTE.bg_dark
	mist_layer.color = MerlinVisual.CRT_PALETTE.mist
	_apply_day_night_tint()


func _setup_voicebox() -> void:
	var vb_path := "res://addons/acvoicebox/acvoicebox.tscn"
	if not ResourceLoader.exists(vb_path):
		return
	var vb_scene: PackedScene = load(vb_path)
	if vb_scene == null:
		return
	voicebox = vb_scene.instantiate()
	voicebox.set("pitch", 2.5)
	voicebox.set("pitch_variation", 0.12)
	voicebox.set("speed_scale", 0.65)
	add_child(voicebox)
	voice_ready = true


func _sync_from_state() -> void:
	if store == null:
		return
	if not store.state.has("flags"):
		store.state["flags"] = {}
	store.state["flags"]["hub_visited"] = true


func _apply_day_night_tint() -> void:
	## Tint background and mist based on DayNightManager time of day.
	var dnm: Node = get_node_or_null("/root/DayNightManager")
	if dnm == null:
		return
	var period: String = dnm.get_time_of_day()
	var cfg: Dictionary = dnm.get_period_config(period)
	# Blend the ambient color into the background for a subtle time-of-day feel
	var ambient_col: Color = cfg.get("ambient_color", Color(0.2, 0.18, 0.15))
	var base_bg: Color = MerlinVisual.CRT_PALETTE.bg_dark
	parchment_bg.color = base_bg.lerp(ambient_col, 0.25)
	# Tint mist layer with fog color
	var fog_col: Color = cfg.get("fog_color", Color(0.15, 0.13, 0.10))
	var base_mist: Color = MerlinVisual.CRT_PALETTE.mist
	mist_layer.color = base_mist.lerp(fog_col, 0.3)
	# Connect to period_changed for live updates during long sessions
	if not dnm.period_changed.is_connected(_on_day_night_period_changed):
		dnm.period_changed.connect(_on_day_night_period_changed)


func _on_day_night_period_changed(_new_period: String) -> void:
	_apply_day_night_tint()


func _process(delta: float) -> void:
	_ambient_t += delta
	# Spawn ambient particles
	if randf() < 0.08:
		_spawn_ambient_particle()
	# Update ambient particles
	var i: int = _ambient_particles.size() - 1
	while i >= 0:
		var p: Dictionary = _ambient_particles[i]
		p["y"] = p["y"] - p["speed"] * delta
		p["x"] = p["x"] + sin(_ambient_t * p["freq"] + p["phase"]) * 8.0 * delta
		p["life"] = p["life"] - delta
		if p["life"] <= 0.0:
			_ambient_particles.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	# Ambient floating particles (drawn on top of bg, below UI)
	for p: Dictionary in _ambient_particles:
		var alpha: float = clampf(p["life"] * 0.5, 0.0, 0.12)
		var c: Color = p["color"]
		c.a = alpha
		draw_rect(Rect2(p["x"], p["y"], 2.0, 2.0), c)

	# Scanline effect (CRT horizontal lines)
	if _scanline_overlay == null:
		var vp: Vector2 = get_viewport_rect().size
		for sy in range(0, int(vp.y), 3):
			draw_line(
				Vector2(0.0, float(sy)),
				Vector2(vp.x, float(sy)),
				MerlinVisual.CRT_PALETTE["scanline"],
				1.0
			)


func _spawn_ambient_particle() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var colors: Array = [
		MerlinVisual.CRT_PALETTE["phosphor_glow"],
		MerlinVisual.CRT_PALETTE["cyan_dim"],
		MerlinVisual.CRT_PALETTE["amber_dim"],
	]
	_ambient_particles.append({
		"x": randf() * vp.x,
		"y": vp.y + 4.0,
		"speed": randf_range(12.0, 30.0),
		"life": randf_range(4.0, 10.0),
		"freq": randf_range(0.5, 2.0),
		"phase": randf() * TAU,
		"color": colors[randi() % colors.size()],
	})
	# Cap particles
	if _ambient_particles.size() > 30:
		_ambient_particles.remove_at(0)



# =============================================================================
# CREATE COMPONENTS — HUD & Overlays
# =============================================================================

func _create_scanline_overlay() -> void:
	_scanline_overlay = ColorRect.new()
	_scanline_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scanline_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scanline_overlay.color = Color.TRANSPARENT
	add_child(_scanline_overlay)


func _create_chronicle_header() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var font: Font = MerlinVisual.get_font("title")

	# Chronicle name (player name)
	_chronicle_label = Label.new()
	_chronicle_label.text = chronicle_name
	_chronicle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		_chronicle_label.add_theme_font_override("font", font)
	_chronicle_label.add_theme_font_size_override("font_size", MerlinVisual.responsive_size(MerlinVisual.TITLE_SMALL))
	_chronicle_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["amber"])
	_chronicle_label.position = Vector2(0.0, 12.0)
	_chronicle_label.size = Vector2(vp.x, 40.0)
	add_child(_chronicle_label)

	# Meta info (runs, class)
	_meta_label = Label.new()
	var total_runs: int = 0
	if store:
		total_runs = int(store.state.get("meta", {}).get("total_runs", 0))
	var class_label: String = player_class.capitalize()
	_meta_label.text = "%s  |  Runs: %d" % [class_label, total_runs]
	_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body_font: Font = MerlinVisual.get_font("body")
	if body_font:
		_meta_label.add_theme_font_override("font", body_font)
	_meta_label.add_theme_font_size_override("font_size", MerlinVisual.responsive_size(MerlinVisual.CAPTION_SIZE))
	_meta_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])
	_meta_label.position = Vector2(0.0, 48.0)
	_meta_label.size = Vector2(vp.x, 20.0)
	add_child(_meta_label)



# =============================================================================
# CREATE COMPONENTS — Scene Elements
# =============================================================================

func _create_hotspots() -> void:
	var vp := get_viewport_rect().size
	for def in HOTSPOT_DEFS:
		var hs := HubHotspot.new()
		var icon_type: int = def["icon"]
		hs.setup(icon_type, def["name"], def["label"], MerlinVisual.CRT_PALETTE[def["palette_key"]])
		hs.tooltip_text = def["label"]
		hs.position = vp * Vector2(def["ratio"])
		add_child(hs)
		hs.hotspot_hovered.connect(_on_hotspot_hovered)
		hs.hotspot_pressed.connect(_on_hotspot_pressed)
		_hotspots.append(hs)


func _create_partir_button() -> void:
	_partir_btn = Button.new()
	_partir_btn.text = "PARTIR EN AVENTURE"
	# La taille réelle est définie dans _layout_partir() (80% viewport)
	_partir_btn.custom_minimum_size = Vector2(300, 60)

	var font: Font = MerlinVisual.get_font("title")
	if font:
		_partir_btn.add_theme_font_override("font", font)
	_partir_btn.add_theme_font_size_override("font_size", 18)
	_style_partir_button()

	add_child(_partir_btn)
	_partir_btn.pressed.connect(_on_partir_pressed)
	_partir_btn.mouse_entered.connect(func():
		SFXManager.play("hover")
		if _partir_hover_tween:
			_partir_hover_tween.kill()
		_partir_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_partir_hover_tween.tween_property(_partir_btn, "scale", Vector2(1.08, 1.08), 0.12)
	)
	_partir_btn.mouse_exited.connect(func():
		if _partir_hover_tween:
			_partir_hover_tween.kill()
		_partir_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_partir_hover_tween.tween_property(_partir_btn, "scale", Vector2(1.0, 1.0), 0.12)
	)

	_layout_partir()


func _style_partir_button() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE["amber"]
	style.border_color = MerlinVisual.CRT_PALETTE["amber_bright"]
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)  # CRT: sharp terminal corners
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = MerlinVisual.CRT_PALETTE["shadow"]
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	_partir_btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = MerlinVisual.CRT_PALETTE["amber_dim"]
	hover.border_color = MerlinVisual.CRT_PALETTE["phosphor"]
	hover.shadow_size = 10
	_partir_btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = MerlinVisual.CRT_PALETTE["amber_bright"]
	pressed.shadow_size = 2
	_partir_btn.add_theme_stylebox_override("pressed", pressed)

	_partir_btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["bg_deep"])
	_partir_btn.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE["bg_deep"])
	_partir_btn.add_theme_color_override("font_pressed_color", MerlinVisual.CRT_PALETTE["bg_deep"])


func _create_bubble() -> void:
	_bubble = MerlinBubble.new()
	add_child(_bubble)


func _create_radial() -> void:
	_radial = BiomeRadial.new()
	add_child(_radial)
	_radial.biome_selected.connect(_on_radial_biome_selected)
	_radial.radial_dismissed.connect(_on_radial_dismissed)


# =============================================================================
# STATUS DASHBOARD — Faction rep mini-bars + Anam + Runes
# =============================================================================

func _create_status_dashboard() -> void:
	_dashboard_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	var bg: Color = MerlinVisual.CRT_PALETTE["bg_deep"]
	style.bg_color = Color(bg.r, bg.g, bg.b, 0.88)
	style.border_color = MerlinVisual.CRT_PALETTE["border"]
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_dashboard_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)

	var factions: Array[String] = MerlinReputationSystem.FACTIONS
	for faction in factions:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		var faction_color: Color = MerlinVisual.CRT_PALETTE.get("faction_" + faction, MerlinVisual.CRT_PALETTE["phosphor"])

		var name_lbl := Label.new()
		name_lbl.text = faction.substr(0, 3).to_upper()
		name_lbl.custom_minimum_size.x = MerlinVisual.responsive_size(30)
		name_lbl.add_theme_color_override("font_color", faction_color)
		MerlinVisual.apply_responsive_font(name_lbl, MerlinVisual.CAPTION_SMALL, "terminal")
		hbox.add_child(name_lbl)

		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = float(MerlinConstants.FACTION_SCORE_START)
		bar.custom_minimum_size = Vector2(MerlinVisual.responsive_size(80), MerlinVisual.responsive_size(8))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.show_percentage = false
		MerlinVisual.apply_bar_theme(bar, "faction_" + faction)
		hbox.add_child(bar)

		var val_lbl := Label.new()
		val_lbl.text = str(MerlinConstants.FACTION_SCORE_START)
		val_lbl.custom_minimum_size.x = MerlinVisual.responsive_size(22)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])
		MerlinVisual.apply_responsive_font(val_lbl, MerlinVisual.CAPTION_SMALL, "terminal")
		hbox.add_child(val_lbl)

		var tier_lbl := Label.new()
		tier_lbl.text = "N"
		tier_lbl.custom_minimum_size.x = MerlinVisual.responsive_size(14)
		tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_lbl.add_theme_color_override("font_color", faction_color)
		MerlinVisual.apply_responsive_font(tier_lbl, MerlinVisual.CAPTION_TINY, "terminal")
		hbox.add_child(tier_lbl)

		vbox.add_child(hbox)
		_faction_bars.append({"bar": bar, "value": val_lbl, "tier": tier_lbl})

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color.TRANSPARENT
	sep_style.border_width_bottom = 1
	sep_style.border_color = MerlinVisual.CRT_PALETTE["line"]
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)

	_anam_label_dash = Label.new()
	_anam_label_dash.text = "Anam: 0"
	_anam_label_dash.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["amber"])
	MerlinVisual.apply_responsive_font(_anam_label_dash, MerlinVisual.CAPTION_SIZE, "terminal")
	bottom.add_child(_anam_label_dash)

	_oghams_label = Label.new()
	_oghams_label.text = "Runes: ---"
	_oghams_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["cyan_dim"])
	MerlinVisual.apply_responsive_font(_oghams_label, MerlinVisual.CAPTION_SIZE, "terminal")
	bottom.add_child(_oghams_label)

	vbox.add_child(bottom)
	_dashboard_panel.add_child(vbox)
	add_child(_dashboard_panel)
	_update_dashboard_data()


func _update_dashboard_data() -> void:
	if store == null:
		return
	var meta: Dictionary = store.state.get("meta", {})
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	var factions: Array[String] = MerlinReputationSystem.FACTIONS

	for i in factions.size():
		if i >= _faction_bars.size():
			break
		var faction: String = factions[i]
		var val: float = float(faction_rep.get(faction, MerlinConstants.FACTION_SCORE_START))
		var entry: Dictionary = _faction_bars[i]
		entry["bar"].value = val
		entry["value"].text = str(int(val))
		entry["tier"].text = _get_tier_abbrev(val)

	var anam: int = int(meta.get("anam", 0))
	if _anam_label_dash:
		_anam_label_dash.text = "Anam: %d" % anam

	var oghams: Dictionary = store.state.get("oghams", {})
	var equipped: Array = oghams.get("skills_equipped", [])
	if _oghams_label:
		if equipped.is_empty():
			_oghams_label.text = "Runes: ---"
		else:
			var names: Array[String] = []
			for o in equipped:
				names.append(str(o).substr(0, 4).capitalize())
			_oghams_label.text = "Runes: %s" % ", ".join(names)


static func _get_tier_abbrev(value: float) -> String:
	if value >= 80.0:
		return "H"
	if value >= 50.0:
		return "S"
	if value >= 20.0:
		return "N"
	if value >= 5.0:
		return "M"
	return "X"


func _layout_dashboard(vp: Vector2, mr: Node, safe_top: float) -> void:
	if _dashboard_panel == null:
		return
	var is_compact: bool = mr != null and mr.is_mobile
	var panel_w: float = minf(vp.x * 0.65, 360.0)
	if is_compact:
		panel_w = vp.x * 0.90
	_dashboard_panel.position = Vector2((vp.x - panel_w) * 0.5, 74.0 + safe_top)
	_dashboard_panel.custom_minimum_size.x = panel_w
	_dashboard_panel.size.x = panel_w


func _on_reputation_changed(_faction: String, _value: float, _delta: float) -> void:
	_update_dashboard_data()


# =============================================================================
# LAYOUT
# =============================================================================

func _layout_all() -> void:
	var vp := get_viewport_rect().size
	var mr: Node = get_node_or_null("/root/MerlinResponsive")
	var safe_top: float = mr.get_safe_margin_top() if mr else 0.0
	for i in _hotspots.size():
		var def: Dictionary = HOTSPOT_DEFS[i]
		var pos: Vector2 = vp * Vector2(def["ratio"])
		if mr and mr.is_mobile:
			pos.y = maxf(pos.y, safe_top + 60.0)
		_hotspots[i].position = pos
	_layout_partir()
	if _chronicle_label:
		_chronicle_label.size.x = vp.x
		_chronicle_label.position.y = 12.0 + safe_top
	if _meta_label:
		_meta_label.size.x = vp.x
		_meta_label.position.y = 48.0 + safe_top
	_layout_dashboard(vp, mr, safe_top)


func _layout_partir() -> void:
	if _partir_btn == null:
		return
	var vp := get_viewport_rect().size
	var mr: Node = get_node_or_null("/root/MerlinResponsive")
	var safe_bottom: float = mr.get_safe_margin_bottom() if mr else 0.0
	var is_compact: bool = mr != null and mr.is_mobile
	var btn_w: float = vp.x * (0.92 if is_compact else 0.80)
	var btn_h: float = 68.0 if is_compact else 60.0
	_partir_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	_partir_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
	_partir_btn.position = Vector2(
		(vp.x - btn_w) * 0.5,
		vp.y - btn_h - 20.0 - safe_bottom
	)


# =============================================================================
# INTERACTIONS
# =============================================================================

func _on_hotspot_hovered(hotspot_name: String) -> void:
	SFXManager.play("hover")


func _on_hotspot_pressed(hotspot_name: String) -> void:
	SFXManager.play("click")
	_store_return_scene()
	match hotspot_name:
		"calendar":
			SFXManager.play("whoosh")
			PixelTransition.transition_to(SCENE_CALENDAR)
		"options":
			SFXManager.play("whoosh")
			PixelTransition.transition_to(SCENE_OPTIONS)
		"arbre":
			SFXManager.play("whoosh")
			PixelTransition.transition_to(SCENE_ARBRE)
		"collection":
			SFXManager.play("whoosh")
			PixelTransition.transition_to(SCENE_COLLECTION)
		"memoires":
			# Whisper memories — collected meta-narrative breadcrumbs
			SFXManager.play("ogham_chime")
			_show_memoires_panel()
		"journal":
			# Cross-run history — vies passees
			SFXManager.play("whoosh")
			_show_journal_panel()


func _on_partir_pressed() -> void:
	SFXManager.play("partir_fanfare")
	# For now: only Broceliande is available — skip radial, launch directly
	selected_biome = "foret_broceliande"
	_generate_mission()
	_launch_adventure()


func _on_radial_biome_selected(biome_key: String) -> void:
	SFXManager.play("choice_select")
	SFXManager.play("ogham_chime")
	var wms: Node = get_node_or_null("/root/WorldMapSystem")
	if wms and wms.has_method("is_biome_accessible"):
		if not wms.is_biome_accessible(biome_key):
			SFXManager.play("hover")
			return

	selected_biome = biome_key
	_generate_mission()

	var biome_name: String = BIOME_DATA.get(biome_key, {}).get("name", biome_key)
	_request_merlin_passive_comment("destination: %s" % biome_name)

	_launch_adventure()


func _on_radial_dismissed() -> void:
	pass


func _generate_mission() -> void:
	var missions: Array = BIOME_MISSIONS.get(selected_biome, [])
	if missions.size() > 0:
		_current_mission = missions[randi() % missions.size()].duplicate()
		_current_mission["progress"] = 0
	else:
		_current_mission = {"type": "exploration", "target": "Explorer ce sanctuaire", "total": 8, "progress": 0}


func _launch_adventure() -> void:
	SFXManager.play("whoosh")

	var wms: Node = get_node_or_null("/root/WorldMapSystem")
	if wms and wms.has_method("select_biome"):
		wms.select_biome(selected_biome)

	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var biome_data: Dictionary = BIOME_DATA.get(selected_biome, {})
		var run_data = gm.get("run")
		if not run_data is Dictionary:
			run_data = {}
		run_data["biome"] = {
			"id": selected_biome,
			"name": biome_data.get("name", "Inconnu"),
			"color": biome_data.get("color", Color.WHITE),
			"ogham_dominant": biome_data.get("ogham", ""),
			"gardien": biome_data.get("guardian", ""),
			"season_forte": biome_data.get("season", ""),
		}
		run_data["current_biome"] = selected_biome
		if not _current_mission.is_empty():
			run_data["mission_template"] = _current_mission.duplicate()
		gm.set("run", run_data)

	if store:
		var run: Dictionary = store.state.get("run", {})
		var mission: Dictionary = run.get("mission", {})
		if not _current_mission.is_empty():
			mission["type"] = _current_mission.get("type", "")
			mission["target"] = _current_mission.get("target", "")
			mission["total"] = _current_mission.get("total", 8)
			mission["progress"] = 0
			mission["revealed"] = true
		run["mission"] = mission
		store.state["run"] = run

	_quick_save()
	var gfc: Node = get_node_or_null("/root/GameFlow")
	if gfc and gfc.has_method("request_run"):
		gfc.request_run(selected_biome)
	else:
		PixelTransition.transition_to(SCENE_FOREST)


func _store_return_scene() -> void:
	var se := get_node_or_null("/root/ScreenEffects")
	if se:
		se.return_scene = get_tree().current_scene.scene_file_path


# =============================================================================
# MERLIN DIALOGUE
# =============================================================================

func _show_first_time_welcome() -> void:
	## Cinematic first-time welcome: Merlin explains game concepts step by step.
	if _bubble == null:
		return
	var welcome_lines: Array[String] = [
		"Bienvenue, voyageur. Je suis Merlin.",
		"Tu te trouves dans mon antre, entre les mondes.",
		"Dehors, la foret de Broceliande t'attend.",
		"Tu y marcheras, et des rencontres viendront a toi sous forme de cartes.",
		"Chaque carte te propose trois choix. Choisis selon ton instinct.",
		"Un defi t'eprouvera ensuite — un minijeu qui teste ta finesse.",
		"Ton score determine la puissance des effets de ton choix.",
		"Garde un oeil sur ta vitalite. Si elle tombe a zero... la boucle recommence.",
		"Quand tu seras pret, appuie sur PARTIR. Broceliande t'attend.",
	]
	for i in range(welcome_lines.size()):
		_bubble.show_message(welcome_lines[i], 4.5)
		await get_tree().create_timer(5.0).timeout
		if not is_inside_tree():
			return


func _show_greeting() -> void:
	if _bubble == null:
		return
	var text := _get_greeting_text()
	_bubble.show_message(text, 5.0)


func _get_greeting_text() -> String:
	var pool: Array
	var total_runs: int = 0
	var last_ending: String = ""

	if store:
		var meta: Dictionary = store.state.get("meta", {})
		total_runs = meta.get("total_runs", 0)
		var endings: Array = meta.get("endings_seen", [])
		if endings.size() > 0:
			last_ending = str(endings[-1])

	if _is_first_hub:
		pool = MERLIN_GREETINGS.get("first_hub", ["Bienvenue, %s."])
	elif total_runs > 5:
		pool = MERLIN_GREETINGS.get("veteran", ["Te revoila, %s."])
	elif last_ending != "":
		pool = MERLIN_GREETINGS.get("after_fall", ["La boucle tourne, %s."])
	else:
		pool = MERLIN_GREETINGS.get("return", ["Te revoila, %s."])

	var template: String = pool[randi() % pool.size()]
	var name: String = chronicle_name.strip_edges()
	if name == "":
		template = template.replace(", %s", "").replace(" %s", "").replace("%s", "")
		return template
	return template % name


func _request_merlin_passive_comment(context: String) -> void:
	var merlin_node := get_node_or_null("/root/MerlinAI")
	if merlin_node == null or not merlin_node.get("is_ready"):
		return
	if _passive_llm_pending:
		return
	if not merlin_node.has_method("generate_voice"):
		return

	_passive_llm_pending = true
	var system := "Tu es Merlin le druide. Commente le choix du joueur en 1 phrase courte (10 mots max). Ton bienveillant ou espiegle. Francais."
	var user_input := "Le joueur prepare: %s" % context

	var result: Dictionary = await merlin_node.generate_voice(system, user_input, {"max_tokens": 30, "temperature": 0.8})
	_passive_llm_pending = false

	if result.has("error") or not is_inside_tree():
		return
	var text: String = str(result.get("text", "")).strip_edges()
	if text.length() < 5 or text.length() > 80:
		return

	if _bubble and is_instance_valid(_bubble):
		_bubble.show_message(text, 4.0)


# =============================================================================
# SAVE
# =============================================================================

func _quick_save() -> void:
	if store == null:
		return
	store.save_system.save_profile(store.state.get("meta", {}))


# =============================================================================
# ANIMATIONS
# =============================================================================

func _start_mist_animation() -> void:
	if mist_layer == null or not is_instance_valid(mist_layer):
		return
	if _mist_tween:
		_mist_tween.kill()
	_mist_tween = create_tween().set_loops()
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.25, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.05, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_entry_animation() -> void:
	SFXManager.play("hub_enter")
	SFXManager.play("scene_transition")

	# Start everything invisible
	if _dashboard_panel:
		_dashboard_panel.modulate.a = 0.0
	for hs in _hotspots:
		hs.modulate.a = 0.0
	if _partir_btn:
		_partir_btn.modulate.a = 0.0
		_partir_btn.scale = Vector2(0.5, 0.5)
	if _chronicle_label:
		_chronicle_label.modulate.a = 0.0
	if _meta_label:
		_meta_label.modulate.a = 0.0

	await get_tree().process_frame

	var pca: Node = get_node_or_null("/root/PixelContentAnimator")

	# Chronicle header fade-in (first element to appear)
	if _chronicle_label:
		MerlinVisual.phosphor_reveal(_chronicle_label, 0.5)
	await get_tree().create_timer(0.15).timeout
	if _meta_label:
		var tw := create_tween()
		tw.tween_property(_meta_label, "modulate:a", 1.0, 0.3)

	# Dashboard fade-in
	if _dashboard_panel:
		await get_tree().create_timer(0.1).timeout
		var tw_dash := create_tween()
		tw_dash.tween_property(_dashboard_panel, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Stagger hotspots reveal
	for i in _hotspots.size():
		var hs: Control = _hotspots[i]
		await get_tree().create_timer(0.12).timeout
		if pca:
			pca.reveal(hs, {"duration": 0.35, "block_size": 6})
		else:
			var tw := create_tween()
			tw.tween_property(hs, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# PARTIR button entrance
	await get_tree().create_timer(0.2).timeout
	if _partir_btn:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_partir_btn, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_partir_btn, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# =============================================================================
# MEMOIRES — Whisper collection display
# =============================================================================

func _show_memoires_panel() -> void:
	var whispers_seen: Array = []
	if store and "state" in store:
		whispers_seen = store.state.get("meta", {}).get("whispers_seen", [])

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE["bg_deep"]
	style.border_color = MerlinVisual.CRT_PALETTE["cyan_dim"]
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	var title := Label.new()
	title.text = "Memoires (%d/13)" % whispers_seen.size()
	title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["cyan"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if whispers_seen.is_empty():
		var hint := Label.new()
		hint.text = "Aucune memoire collectee.\nContinuez a jouer..."
		hint.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(hint)
	else:
		for wid in whispers_seen:
			var entry := Label.new()
			entry.text = "* %s" % str(wid).replace("whisper_", "").replace("_", " ").capitalize()
			entry.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor"])
			vbox.add_child(entry)

	var close := Button.new()
	close.text = "Fermer"
	close.pressed.connect(func(): panel.queue_free())
	vbox.add_child(close)

	panel.add_child(vbox)
	var vp := get_viewport_rect().size
	panel.position = vp * 0.15
	panel.size = vp * 0.7
	add_child(panel)


# =============================================================================
# JOURNAL — Cross-run history display
# =============================================================================

func _show_journal_panel() -> void:
	var run_history: Array = []
	var total_runs: int = 0
	if store and "state" in store:
		run_history = store.state.get("meta", {}).get("run_history", [])
		total_runs = int(store.state.get("meta", {}).get("total_runs", 0))

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE["bg_deep"]
	style.border_color = MerlinVisual.CRT_PALETTE["amber_dim"]
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	var title := Label.new()
	title.text = "Vies Passees (%d runs)" % total_runs
	title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["amber_bright"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if run_history.is_empty():
		var hint := Label.new()
		hint.text = "Aucune vie passee.\nTerminez un run pour commencer le journal."
		hint.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(hint)
	else:
		for i in range(mini(run_history.size(), 10)):
			var run: Dictionary = run_history[run_history.size() - 1 - i]
			var entry := Label.new()
			entry.text = "Vie %d: %s — %d cartes — %s" % [
				total_runs - i,
				str(run.get("biome", "?")).replace("_", " ").capitalize(),
				int(run.get("cards_played", 0)),
				str(run.get("ending", "mort")),
			]
			entry.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor"])
			vbox.add_child(entry)

	var close := Button.new()
	close.text = "Fermer"
	close.pressed.connect(func(): panel.queue_free())
	vbox.add_child(close)

	panel.add_child(vbox)
	var vp := get_viewport_rect().size
	panel.position = vp * 0.15
	panel.size = vp * 0.7
	add_child(panel)

