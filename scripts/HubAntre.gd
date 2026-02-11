## ═══════════════════════════════════════════════════════════════════════════════
## HubAntre — L'Antre du Dernier Druide (Persistent Hub)
## ═══════════════════════════════════════════════════════════════════════════════
## Central hub scene between runs. From here the player:
##   - Talks to Merlin (contextual dialogue with typewriter + voice)
##   - Views Voyager status (Triade aspects, souffle, day)
##   - Selects a biome on the Brittany map (7 sanctuaries)
##   - Manages Bestiole (care, bond, Oghams equipped)
##   - Views meta-progression (Grimoire summary)
##   - Saves/loads game
##   - Launches the next adventure
## Style: Parchemin Mystique Breton (shared with all scenes)
## ═══════════════════════════════════════════════════════════════════════════════

extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# SCENE NAVIGATION
# ═══════════════════════════════════════════════════════════════════════════════

const SCENE_TRANSITION := "res://scenes/TransitionBiome.tscn"
const SCENE_OPTIONS := "res://scenes/MenuOptions.tscn"
const SCENE_CALENDAR := "res://scenes/Calendar.tscn"
const SCENE_COLLECTION := "res://scenes/Collection.tscn"
const SCENE_MENU := "res://scenes/MenuPrincipal.tscn"
const SCENE_SAVE := "res://scenes/SelectionSauvegarde.tscn"
const SCENE_MAPMONDE := "res://scenes/MapMonde.tscn"

# ═══════════════════════════════════════════════════════════════════════════════
# TYPEWRITER SETTINGS
# ═══════════════════════════════════════════════════════════════════════════════

const TYPEWRITER_DELAY := 0.030
const TYPEWRITER_PUNCT_DELAY := 0.10
const BLIP_FREQ := 880.0
const BLIP_DURATION := 0.018
const BLIP_VOLUME := 0.04

# ═══════════════════════════════════════════════════════════════════════════════
# VISUAL CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const CARD_MAX_WIDTH := 680.0
const PORTRAIT_SIZE := Vector2(160, 200)
const MAX_CARE_ACTIONS := 3

# ═══════════════════════════════════════════════════════════════════════════════
# PALETTE — Parchemin Mystique Breton (shared with all scenes)
# ═══════════════════════════════════════════════════════════════════════════════

const PALETTE := {
	"paper": Color(0.965, 0.945, 0.905),
	"paper_dark": Color(0.935, 0.905, 0.855),
	"paper_warm": Color(0.955, 0.930, 0.890),
	"ink": Color(0.22, 0.18, 0.14),
	"ink_soft": Color(0.38, 0.32, 0.26),
	"ink_faded": Color(0.50, 0.44, 0.38, 0.35),
	"accent": Color(0.58, 0.44, 0.26),
	"accent_soft": Color(0.65, 0.52, 0.34),
	"accent_glow": Color(0.72, 0.58, 0.38, 0.25),
	"shadow": Color(0.25, 0.20, 0.16, 0.18),
	"line": Color(0.40, 0.34, 0.28, 0.12),
	"mist": Color(0.94, 0.92, 0.88, 0.35),
	"ogham_glow": Color(0.45, 0.62, 0.32),
	"bestiole": Color(0.42, 0.60, 0.72),
	"danger": Color(0.72, 0.28, 0.22),
	"success": Color(0.32, 0.58, 0.28),
	"warning": Color(0.72, 0.58, 0.22),
}

# Pixel portrait (replaces PNG assets)
const PIXEL_PORTRAIT_SIZE := Vector2(110, 128)  # 12x14 grid, ~9px/pixel

# ═══════════════════════════════════════════════════════════════════════════════
# BIOME DATA — 7 Sanctuaires de Bretagne
# ═══════════════════════════════════════════════════════════════════════════════

const BIOME_DATA := {
	"foret_broceliande": {
		"name": "Foret de Broceliande",
		"subtitle": "Mystere et magie ancestrale",
		"color": Color(0.30, 0.50, 0.28),
		"ogham": "duir",
		"guardian": "Maelgwn",
		"season": "automne",
		"aspect_hint": "Corps +20%",
		"difficulty_label": "Normal",
	},
	"landes_bruyere": {
		"name": "Landes de Bruyere",
		"subtitle": "Solitude et endurance",
		"color": Color(0.55, 0.40, 0.55),
		"ogham": "onn",
		"guardian": "Talwen",
		"season": "hiver",
		"aspect_hint": "Ame +20%",
		"difficulty_label": "Difficile",
	},
	"cotes_sauvages": {
		"name": "Cotes Sauvages",
		"subtitle": "L'ocean murmurant",
		"color": Color(0.35, 0.50, 0.65),
		"ogham": "nuin",
		"guardian": "Bran",
		"season": "ete",
		"aspect_hint": "Monde +20%",
		"difficulty_label": "Normal",
	},
	"villages_celtes": {
		"name": "Villages Celtes",
		"subtitle": "Flammes obstinees de l'humanite",
		"color": Color(0.60, 0.45, 0.30),
		"ogham": "gort",
		"guardian": "Azenor",
		"season": "printemps",
		"aspect_hint": "Monde +20%",
		"difficulty_label": "Facile",
	},
	"cercles_pierres": {
		"name": "Cercles de Pierres",
		"subtitle": "Ou le temps hesite",
		"color": Color(0.50, 0.50, 0.55),
		"ogham": "huath",
		"guardian": "Keridwen",
		"season": "samhain",
		"aspect_hint": "Ame +40%",
		"difficulty_label": "Difficile",
	},
	"marais_korrigans": {
		"name": "Marais des Korrigans",
		"subtitle": "Deception et feux follets",
		"color": Color(0.30, 0.42, 0.30),
		"ogham": "muin",
		"guardian": "Gwydion",
		"season": "lughnasadh",
		"aspect_hint": "Corps +20%",
		"difficulty_label": "Tres difficile",
	},
	"collines_dolmens": {
		"name": "Collines aux Dolmens",
		"subtitle": "Les os de la terre",
		"color": Color(0.48, 0.55, 0.40),
		"ogham": "ioho",
		"guardian": "Elouan",
		"season": "yule",
		"aspect_hint": "Equilibre",
		"difficulty_label": "Normal",
	},
}

var _biome_system := MerlinBiomeSystem.new()

# ═══════════════════════════════════════════════════════════════════════════════
# BIOME MISSIONS — Procedural mission pool per biome
# ═══════════════════════════════════════════════════════════════════════════════

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
}

# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN GREETINGS — Contextual dialogue lines
# ═══════════════════════════════════════════════════════════════════════════════

const MERLIN_GREETINGS := {
	"first_hub": [
		"Bienvenue dans mon antre, %s. Il est humble, mais les murs se souviennent de tout.",
		"Entre, %s. Le feu t'attendait. Bestiole aussi, d'ailleurs.",
	],
	"return": [
		"Te revoila, %s ! Bestiole s'impatientait.",
		"De retour ! Les murs ont chuchote ton nom, %s.",
		"Ah, %s. Le druide ne dort jamais... et toi non plus, apparemment.",
		"L'antre est toujours ouvert, %s. Le feu ne meurt pas ici.",
	],
	"after_fall": [
		"La boucle tourne, %s. Chaque chute enseigne quelque chose.",
		"Le monde oublie, mais moi je me souviens de tes pas, %s.",
		"Encore toi ? Je plaisante, %s. Bienvenue a nouveau.",
		"Tomber n'est pas echouer, %s. C'est apprendre le sol.",
	],
	"veteran": [
		"Tu connais le chemin mieux que moi, %s.",
		"Les pierres te reconnaissent, %s. Elles murmurent ton histoire.",
		"Combien de fois maintenant ? Non, ne compte pas. Vis, %s.",
		"%s... Parfois je me demande qui guide qui.",
	],
}

# ═══════════════════════════════════════════════════════════════════════════════
# BESTIOLE CARE ACTIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Map positions (proportional 0-1 within the map container) — Brittany shape
const BIOME_MAP_POSITIONS := {
	"cotes_sauvages": Vector2(0.18, 0.10),
	"landes_bruyere": Vector2(0.75, 0.08),
	"foret_broceliande": Vector2(0.10, 0.46),
	"villages_celtes": Vector2(0.48, 0.42),
	"collines_dolmens": Vector2(0.82, 0.48),
	"marais_korrigans": Vector2(0.22, 0.82),
	"cercles_pierres": Vector2(0.68, 0.84),
}

# Paths connecting adjacent biomes on the map
const BIOME_CONNECTIONS: Array[Array] = [
	["cotes_sauvages", "landes_bruyere"],
	["cotes_sauvages", "foret_broceliande"],
	["landes_bruyere", "collines_dolmens"],
	["foret_broceliande", "villages_celtes"],
	["villages_celtes", "collines_dolmens"],
	["foret_broceliande", "marais_korrigans"],
	["villages_celtes", "cercles_pierres"],
	["marais_korrigans", "cercles_pierres"],
]

# Celtic symbols for biome markers
const BIOME_SYMBOLS := {
	"foret_broceliande": "\u2663",      # Club/tree
	"landes_bruyere": "\u2736",          # Star
	"cotes_sauvages": "\u2248",          # Waves
	"villages_celtes": "\u2302",         # House
	"cercles_pierres": "\u25CE",         # Bullseye/circle
	"marais_korrigans": "\u2735",        # Star
	"collines_dolmens": "\u25B2",        # Triangle/mountain
}

const CARE_ACTIONS := {
	"feed": {"label": "Nourrir", "icon": "\u2022", "need": "Hunger", "amount": 20, "bond": 3},
	"play": {"label": "Jouer", "icon": "\u25CB", "need": "Mood", "amount": 20, "bond": 5},
	"groom": {"label": "Soigner", "icon": "\u2736", "need": "Hygiene", "amount": 20, "bond": 2},
	"rest": {"label": "Repos", "icon": "\u223C", "need": "Energy", "amount": 20, "bond": 2, "stress_reduce": 15},
}

# Icon standardization — unified Celtic style
const ICON_STANDARDS := {
	"size": 24.0,
	"line_thickness": 1.5,
	"detail_thickness": 1.0,
	"accent_dot": 2.0,
	"radius_ratio": 0.38,
	"corner_radius": 8,
}

# ═══════════════════════════════════════════════════════════════════════════════
# NODES
# ═══════════════════════════════════════════════════════════════════════════════

var parchment_bg: ColorRect
var mist_layer: ColorRect
var celtic_top: Label
var celtic_bottom: Label
var tab_container: Control  # Holds all pages
var tab_pages: Array[Control] = []  # Array of page Controls
var tab_buttons: Array[Button] = []  # Tab bar buttons
var current_tab: int = 0
var main_vbox: VBoxContainer  # Used within current page
var pixel_portrait: Control  # PixelMerlinPortrait
var merlin_text: RichTextLabel
var merlin_source_badge: PanelContainer
var aspect_labels: Dictionary = {}
var souffle_label: Label
var day_label: Label
var mission_label: Label
var mission_progress_bar: ProgressBar
var biome_buttons: Dictionary = {}
var biome_detail_label: Label
var map_container: Control
var map_paths_node: Control
var time_label: Label
var _map_pulse_tween: Tween
var bestiole_bond_label: Label
var bestiole_awen_label: Label
var bestiole_needs_container: VBoxContainer
var care_buttons: Dictionary = {}
var care_remaining_label: Label
var ogham_container: HBoxContainer
var grimoire_stats_label: Label
var adventure_btn: Button
var save_btn: Button
var bottom_bar: HBoxContainer
var arbre_node_buttons: Dictionary = {}
var arbre_info_label: Label
var arbre_essence_label: Label
var arbre_currency_label: Label
var _arbre_selected_node: String = ""

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var store: MerlinStore = null
var selected_biome: String = ""
var selected_tool: String = ""
var selected_departure_condition: String = ""
var expedition_ready: bool = false
var chronicle_name: String = "Voyageur"
var player_class: String = "eclaireur"
var typing_active: bool = false
var typing_abort: bool = false
var _care_remaining: int = MAX_CARE_ACTIONS
var _mist_tween: Tween
var _current_mission: Dictionary = {}
var _is_first_hub: bool = true

# Expedition UI nodes
var tool_buttons: Dictionary = {}
var departure_buttons: Dictionary = {}
var merlin_reaction_label: RichTextLabel
var destination_display_label: Label
var expedition_check_labels: Array[Label] = []

# Fonts
var title_font: Font
var body_font: Font

# Audio
var audio_player: AudioStreamPlayer
var voicebox: Node = null
var voice_ready: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_load_fonts()
	_connect_store()
	_load_player_data()
	_build_ui()
	_setup_audio()
	_setup_voicebox()
	_sync_from_state()

	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("warm")

	resized.connect(_on_resized)
	_start_mist_animation()
	_play_entry_animation.call_deferred()

	await get_tree().create_timer(1.0).timeout
	_play_merlin_greeting()


func _input(event: InputEvent) -> void:
	if typing_active and event is InputEventMouseButton and event.pressed:
		typing_abort = true

	# Tab navigation via keyboard/gamepad (L1/R1 or Q/E) — 2 tabs: Antre (0), Compagnons (1)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_Q:
				if current_tab > 0:
					_on_tab_pressed(current_tab - 1)
			KEY_E:
				if current_tab < 1:
					_on_tab_pressed(current_tab + 1)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER and current_tab > 0:
			_on_tab_pressed(current_tab - 1)
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER and current_tab < 1:
			_on_tab_pressed(current_tab + 1)


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _load_fonts() -> void:
	title_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlack.otf")
	if title_font == null:
		title_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlack.ttf")
	body_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.otf")
	if body_font == null:
		body_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf")
	if body_font == null:
		body_font = title_font


func _try_load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var f: Resource = load(path)
	if f is Font:
		return f
	return null


func _connect_store() -> void:
	store = get_node_or_null("/root/MerlinStore")


func _load_player_data() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var run_data = gm.get("run")
		if run_data is Dictionary:
			var profile: Dictionary = run_data.get("traveler_profile", {})
			player_class = profile.get("class", "eclaireur")
			chronicle_name = run_data.get("chronicle_name", "Voyageur")
			var biome_info: Dictionary = run_data.get("biome", {})
			if biome_info.has("id"):
				selected_biome = biome_info["id"]

	# Auto-select Broceliande if no biome chosen (first visit)
	if selected_biome == "":
		selected_biome = "foret_broceliande"

	if store:
		_is_first_hub = not store.state.get("flags", {}).get("hub_visited", false)


func _sync_from_state() -> void:
	if store == null:
		return
	_update_aspect_display()
	_update_souffle_display()
	_update_bestiole_display()
	_update_grimoire_display()
	_update_adventure_button()
	if not store.state.has("flags"):
		store.state["flags"] = {}
	store.state["flags"]["hub_visited"] = true


func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Master"
	add_child(audio_player)


func _setup_voicebox() -> void:
	var vb_scene_path := "res://addons/acvoicebox/acvoicebox.tscn"
	if not ResourceLoader.exists(vb_scene_path):
		return
	var vb_scene: PackedScene = load(vb_scene_path)
	if vb_scene == null:
		return
	voicebox = vb_scene.instantiate()
	voicebox.set("pitch", 2.5)
	voicebox.set("pitch_variation", 0.12)
	voicebox.set("speed_scale", 0.65)
	add_child(voicebox)
	voice_ready = true


# ═══════════════════════════════════════════════════════════════════════════════
# UI BUILD — Master orchestrator
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_build_background()
	_build_ornaments()
	_build_scroll_content()
	_build_bottom_bar()
	_layout_ui()


func _build_background() -> void:
	parchment_bg = ColorRect.new()
	parchment_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parchment_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper_shader := load("res://shaders/reigns_paper.gdshader")
	if paper_shader:
		var mat := ShaderMaterial.new()
		mat.shader = paper_shader
		mat.set_shader_parameter("paper_tint", PALETTE.paper)
		mat.set_shader_parameter("grain_strength", 0.025)
		mat.set_shader_parameter("vignette_strength", 0.08)
		mat.set_shader_parameter("vignette_softness", 0.65)
		mat.set_shader_parameter("grain_scale", 1200.0)
		mat.set_shader_parameter("grain_speed", 0.08)
		mat.set_shader_parameter("warp_strength", 0.001)
		parchment_bg.material = mat
	else:
		parchment_bg.color = PALETTE.paper
	add_child(parchment_bg)

	mist_layer = ColorRect.new()
	mist_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	mist_layer.color = PALETTE.mist
	mist_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mist_layer.modulate.a = 0.0
	add_child(mist_layer)


func _build_ornaments() -> void:
	celtic_top = _make_celtic_ornament()
	add_child(celtic_top)
	celtic_bottom = _make_celtic_ornament()
	add_child(celtic_bottom)


func _build_scroll_content() -> void:
	# Tab container holds all pages (no scrolling)
	tab_container = Control.new()
	tab_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab_container.modulate.a = 0.0
	add_child(tab_container)

	# Page 0: Antre — Merlin, Status & Expedition Preparation
	var page1 := _create_page()
	_build_title_section_on(page1)
	_build_merlin_section_on(page1)
	_build_status_section_on(page1)
	_build_expedition_prep_on(page1)
	tab_pages.append(page1)
	tab_container.add_child(page1)

	# Page 1: Compagnons — Bestiole & Grimoire
	var page2 := _create_page()
	_build_bestiole_section_on(page2)
	_build_grimoire_section_on(page2)
	tab_pages.append(page2)
	tab_container.add_child(page2)
	page2.visible = false

	# Set main_vbox to page 1 content for layout compatibility
	main_vbox = page1.get_child(0) as VBoxContainer


func _create_page() -> Control:
	## Creates a page container with a VBoxContainer inside.
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	page.add_child(vbox)

	return page


func _build_title_section_on(page: Control) -> void:
	main_vbox = page.get_child(0) as VBoxContainer
	_build_title_section()


func _build_merlin_section_on(page: Control) -> void:
	main_vbox = page.get_child(0) as VBoxContainer
	_build_merlin_section()


func _build_status_section_on(page: Control) -> void:
	main_vbox = page.get_child(0) as VBoxContainer
	_build_status_section()


func _build_expedition_prep_on(page: Control) -> void:
	main_vbox = page.get_child(0) as VBoxContainer
	_build_expedition_prep_section()


func _build_map_section_on(page: Control) -> void:
	main_vbox = page.get_child(0) as VBoxContainer
	_build_map_section()


func _build_mission_section_on(page: Control) -> void:
	main_vbox = page.get_child(0) as VBoxContainer
	_build_mission_section()


func _build_bestiole_section_on(page: Control) -> void:
	main_vbox = page.get_child(0) as VBoxContainer
	_build_bestiole_section()


func _build_grimoire_section_on(page: Control) -> void:
	main_vbox = page.get_child(0) as VBoxContainer
	_build_grimoire_section()


func _build_arbre_section_on(page: Control) -> void:
	main_vbox = page.get_child(0) as VBoxContainer
	_build_arbre_section()


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION: Title
# ═══════════════════════════════════════════════════════════════════════════════

func _build_title_section() -> void:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "L'Antre du Dernier Druide"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font:
		title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", PALETTE.ink)
	vbox.add_child(title)

	var orn := Label.new()
	orn.text = "\u2500\u2500 \u25C6 \u2500\u2500"
	orn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orn.add_theme_font_size_override("font_size", 10)
	orn.add_theme_color_override("font_color", PALETTE.accent)
	vbox.add_child(orn)


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION: Merlin (Portrait + Dialogue)
# ═══════════════════════════════════════════════════════════════════════════════

func _build_merlin_section() -> void:
	var card := _make_card()
	main_vbox.add_child(card)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	card.add_child(hbox)

	# Pixel Portrait (PixelMerlinPortrait)
	var portrait_center := CenterContainer.new()
	hbox.add_child(portrait_center)

	var PixelMerlinPortraitClass = load("res://scripts/ui/pixel_merlin_portrait.gd")
	if PixelMerlinPortraitClass:
		pixel_portrait = PixelMerlinPortraitClass.new()
		portrait_center.add_child(pixel_portrait)
		pixel_portrait.call("setup", 96.0)  # 12x14 grid, compact
		pixel_portrait.call("assemble", true)  # instant — no animation in Hub
	else:
		# Fallback: empty control
		pixel_portrait = Control.new()
		pixel_portrait.custom_minimum_size = PIXEL_PORTRAIT_SIZE
		portrait_center.add_child(pixel_portrait)

	# Dialogue column
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 8)
	hbox.add_child(text_vbox)

	var name_label := Label.new()
	name_label.text = "Merlin"
	if title_font:
		name_label.add_theme_font_override("font", title_font)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", PALETTE.accent)
	text_vbox.add_child(name_label)

	merlin_text = RichTextLabel.new()
	merlin_text.bbcode_enabled = true
	merlin_text.fit_content = true
	merlin_text.scroll_active = false
	merlin_text.custom_minimum_size = Vector2(240, 40)
	merlin_text.visible_characters = 0
	merlin_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if body_font:
		merlin_text.add_theme_font_override("normal_font", body_font)
	merlin_text.add_theme_font_size_override("normal_font_size", 16)
	merlin_text.add_theme_color_override("default_color", PALETTE.ink)
	text_vbox.add_child(merlin_text)

	merlin_source_badge = LLMSourceBadge.create("static")
	text_vbox.add_child(merlin_source_badge)


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION: Status (Aspects + Souffle + Day)
# ═══════════════════════════════════════════════════════════════════════════════

func _build_status_section() -> void:
	var card := _make_card()
	main_vbox.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var title := _make_section_title("Etat du Voyageur")
	vbox.add_child(title)

	# Aspects row
	var aspects_hbox := HBoxContainer.new()
	aspects_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	aspects_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(aspects_hbox)

	for aspect_name in ["Corps", "Ame", "Monde"]:
		var aspect_vbox := VBoxContainer.new()
		aspect_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		aspect_vbox.add_theme_constant_override("separation", 2)
		aspects_hbox.add_child(aspect_vbox)

		var name_lbl := Label.new()
		name_lbl.text = aspect_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if title_font:
			name_lbl.add_theme_font_override("font", title_font)
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", PALETTE.ink_soft)
		aspect_vbox.add_child(name_lbl)

		var state_lbl := Label.new()
		state_lbl.text = "\u25CF Robuste"
		state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if body_font:
			state_lbl.add_theme_font_override("font", body_font)
		state_lbl.add_theme_font_size_override("font_size", 14)
		state_lbl.add_theme_color_override("font_color", PALETTE.success)
		aspect_vbox.add_child(state_lbl)

		aspect_labels[aspect_name] = state_lbl

	# Souffle + Day row
	var info_hbox := HBoxContainer.new()
	info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_hbox.add_theme_constant_override("separation", 30)
	vbox.add_child(info_hbox)

	souffle_label = Label.new()
	souffle_label.text = "Souffle: \u25CF\u25CF\u25CF\u25CB\u25CB\u25CB\u25CB"
	souffle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if body_font:
		souffle_label.add_theme_font_override("font", body_font)
	souffle_label.add_theme_font_size_override("font_size", 13)
	souffle_label.add_theme_color_override("font_color", PALETTE.ink)
	info_hbox.add_child(souffle_label)

	day_label = Label.new()
	day_label.text = "Jour: 1"
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if body_font:
		day_label.add_theme_font_override("font", body_font)
	day_label.add_theme_font_size_override("font_size", 13)
	day_label.add_theme_color_override("font_color", PALETTE.ink)
	info_hbox.add_child(day_label)


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION: Mission
# ═══════════════════════════════════════════════════════════════════════════════

func _build_mission_section() -> void:
	var card := _make_card()
	main_vbox.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var title := _make_section_title("Mission")
	vbox.add_child(title)

	mission_label = Label.new()
	mission_label.text = "Selectionne un biome pour recevoir ta mission"
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if body_font:
		mission_label.add_theme_font_override("font", body_font)
	mission_label.add_theme_font_size_override("font_size", 16)
	mission_label.add_theme_color_override("font_color", PALETTE.ink)
	vbox.add_child(mission_label)

	mission_progress_bar = ProgressBar.new()
	mission_progress_bar.custom_minimum_size = Vector2(200, 12)
	mission_progress_bar.min_value = 0
	mission_progress_bar.max_value = 1
	mission_progress_bar.value = 0
	mission_progress_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = PALETTE.paper_dark
	bar_bg.set_corner_radius_all(3)
	mission_progress_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = PALETTE.accent
	bar_fill.set_corner_radius_all(3)
	mission_progress_bar.add_theme_stylebox_override("fill", bar_fill)
	mission_progress_bar.visible = false
	vbox.add_child(mission_progress_bar)


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION: Map — 7 Biomes of Celtic Brittany
# ═══════════════════════════════════════════════════════════════════════════════

func _build_map_section() -> void:
	var card := _make_card()
	main_vbox.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Title row with date/time
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 12)
	vbox.add_child(title_row)

	var title := _make_section_title("Carte de Bretagne")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	time_label = Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if body_font:
		time_label.add_theme_font_override("font", body_font)
	time_label.add_theme_font_size_override("font_size", 13)
	time_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	title_row.add_child(time_label)
	_update_time_display()

	# Map container (positioned biomes + path lines)
	map_container = Control.new()
	map_container.custom_minimum_size = Vector2(0, 300)
	map_container.clip_contents = true
	vbox.add_child(map_container)

	# Path lines between biomes (drawn first, behind markers)
	map_paths_node = Control.new()
	map_paths_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_paths_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_container.add_child(map_paths_node)

	for conn in BIOME_CONNECTIONS:
		var line := Line2D.new()
		line.width = 1.5
		line.default_color = Color(PALETTE.ink_faded.r, PALETTE.ink_faded.g, PALETTE.ink_faded.b, 0.25)
		line.antialiased = true
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2.ZERO)
		map_paths_node.add_child(line)

	# Biome markers
	for biome_key in BIOME_MAP_POSITIONS:
		var biome: Dictionary = BIOME_DATA.get(biome_key, {})
		var marker := _create_biome_marker(biome_key, biome)
		biome_buttons[biome_key] = marker
		map_container.add_child(marker)

	# Layout immediately
	_layout_map.call_deferred()

	# Time update timer
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.autostart = true
	timer.timeout.connect(_update_time_display)
	add_child(timer)

	# Biome detail text
	biome_detail_label = Label.new()
	biome_detail_label.text = ""
	biome_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	biome_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if body_font:
		biome_detail_label.add_theme_font_override("font", body_font)
	biome_detail_label.add_theme_font_size_override("font_size", 13)
	biome_detail_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	vbox.add_child(biome_detail_label)

	# MapMonde overlay button
	var map_btn := Button.new()
	map_btn.text = "\u2726 Carte du Monde"
	map_btn.custom_minimum_size = Vector2(200, 40)
	map_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if body_font:
		map_btn.add_theme_font_override("font", body_font)
	map_btn.add_theme_font_size_override("font_size", 14)
	map_btn.add_theme_color_override("font_color", PALETTE.accent)
	map_btn.add_theme_color_override("font_hover_color", PALETTE.accent_glow)
	map_btn.mouse_entered.connect(func(): SFXManager.play("hover"))
	map_btn.pressed.connect(_open_mapmonde_overlay)
	var map_btn_center := CenterContainer.new()
	map_btn_center.add_child(map_btn)
	vbox.add_child(map_btn_center)


func _create_biome_marker(biome_key: String, biome: Dictionary) -> Button:
	var btn := Button.new()
	var symbol: String = BIOME_SYMBOLS.get(biome_key, "\u25CF")
	var biome_name: String = biome.get("name", biome_key)
	btn.text = symbol + "\n" + biome_name
	btn.custom_minimum_size = Vector2(110, 58)
	btn.mouse_entered.connect(func(): SFXManager.play("hover"))
	btn.pressed.connect(_on_biome_selected.bind(biome_key))
	if body_font:
		btn.add_theme_font_override("font", body_font)
	btn.add_theme_font_size_override("font_size", 12)
	btn.clip_text = false
	_style_biome_button(btn, biome, biome_key == selected_biome)
	return btn


func _layout_map() -> void:
	if map_container == null:
		return
	var map_size := map_container.size
	if map_size.x < 10 or map_size.y < 10:
		return

	var btn_half := Vector2(55, 29)

	# Position biome markers
	for biome_key in BIOME_MAP_POSITIONS:
		if not biome_buttons.has(biome_key):
			continue
		var btn: Button = biome_buttons[biome_key]
		var prop: Vector2 = BIOME_MAP_POSITIONS[biome_key]
		btn.position = Vector2(prop.x * map_size.x, prop.y * map_size.y) - btn_half

	# Update path lines
	var line_idx := 0
	for conn in BIOME_CONNECTIONS:
		if line_idx >= map_paths_node.get_child_count():
			break
		var line: Line2D = map_paths_node.get_child(line_idx) as Line2D
		var pos_a: Vector2 = BIOME_MAP_POSITIONS.get(conn[0], Vector2.ZERO)
		var pos_b: Vector2 = BIOME_MAP_POSITIONS.get(conn[1], Vector2.ZERO)
		line.set_point_position(0, Vector2(pos_a.x * map_size.x, pos_a.y * map_size.y))
		line.set_point_position(1, Vector2(pos_b.x * map_size.x, pos_b.y * map_size.y))
		line_idx += 1


func _update_time_display() -> void:
	if time_label == null:
		return
	var day := 1
	if store:
		day = store.state.get("run", {}).get("day", 1)
	var now := Time.get_datetime_dict_from_system()
	var hour: int = now.get("hour", 0)
	var minute: int = now.get("minute", 0)
	time_label.text = "Jour %d \u2014 %02d:%02d" % [day, hour, minute]


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION: Bestiole (Stats + Care + Oghams)
# ═══════════════════════════════════════════════════════════════════════════════

func _build_bestiole_section() -> void:
	var card := _make_card()
	main_vbox.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var title := _make_section_title("Bestiole")
	vbox.add_child(title)

	# Bond + Awen row
	var top_hbox := HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(top_hbox)

	bestiole_bond_label = Label.new()
	bestiole_bond_label.text = "Lien: \u25CF\u25CF\u25CB\u25CB\u25CB Compagnon"
	if body_font:
		bestiole_bond_label.add_theme_font_override("font", body_font)
	bestiole_bond_label.add_theme_font_size_override("font_size", 15)
	bestiole_bond_label.add_theme_color_override("font_color", PALETTE.bestiole)
	top_hbox.add_child(bestiole_bond_label)

	bestiole_awen_label = Label.new()
	bestiole_awen_label.text = "Awen: \u2605\u2605\u2606\u2606\u2606"
	if body_font:
		bestiole_awen_label.add_theme_font_override("font", body_font)
	bestiole_awen_label.add_theme_font_size_override("font_size", 15)
	bestiole_awen_label.add_theme_color_override("font_color", PALETTE.ogham_glow)
	top_hbox.add_child(bestiole_awen_label)

	# Needs display
	bestiole_needs_container = VBoxContainer.new()
	bestiole_needs_container.add_theme_constant_override("separation", 2)
	vbox.add_child(bestiole_needs_container)

	# Care title
	var care_title := Label.new()
	care_title.text = "Prendre soin"
	care_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font:
		care_title.add_theme_font_override("font", title_font)
	care_title.add_theme_font_size_override("font_size", 14)
	care_title.add_theme_color_override("font_color", PALETTE.ink_soft)
	vbox.add_child(care_title)

	# Care action buttons
	var care_hbox := HBoxContainer.new()
	care_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	care_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(care_hbox)

	for action_key in CARE_ACTIONS:
		var action: Dictionary = CARE_ACTIONS[action_key]
		var btn := Button.new()
		btn.text = "%s %s" % [action.get("icon", ""), action.get("label", action_key)]
		btn.custom_minimum_size = Vector2(100, 36)
		btn.mouse_entered.connect(func(): SFXManager.play("hover"))
		btn.pressed.connect(_on_care_action.bind(action_key))
		if body_font:
			btn.add_theme_font_override("font", body_font)
		btn.add_theme_font_size_override("font_size", 13)
		_style_care_button(btn)
		care_buttons[action_key] = btn
		care_hbox.add_child(btn)

	care_remaining_label = Label.new()
	care_remaining_label.text = "Soins restants: %d" % _care_remaining
	care_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if body_font:
		care_remaining_label.add_theme_font_override("font", body_font)
	care_remaining_label.add_theme_font_size_override("font_size", 12)
	care_remaining_label.add_theme_color_override("font_color", PALETTE.ink_faded)
	vbox.add_child(care_remaining_label)

	# Equipped Oghams
	var ogham_title := Label.new()
	ogham_title.text = "Oghams equipes"
	ogham_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font:
		ogham_title.add_theme_font_override("font", title_font)
	ogham_title.add_theme_font_size_override("font_size", 14)
	ogham_title.add_theme_color_override("font_color", PALETTE.ogham_glow)
	vbox.add_child(ogham_title)

	ogham_container = HBoxContainer.new()
	ogham_container.alignment = BoxContainer.ALIGNMENT_CENTER
	ogham_container.add_theme_constant_override("separation", 12)
	vbox.add_child(ogham_container)


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION: Grimoire (Meta-progression summary)
# ═══════════════════════════════════════════════════════════════════════════════

func _build_grimoire_section() -> void:
	var card := _make_card()
	main_vbox.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var title := _make_section_title("Grimoire")
	vbox.add_child(title)

	grimoire_stats_label = Label.new()
	grimoire_stats_label.text = "Runs: 0  \u2502  Fins vues: 0/16  \u2502  Gloire: 0"
	grimoire_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grimoire_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if body_font:
		grimoire_stats_label.add_theme_font_override("font", body_font)
	grimoire_stats_label.add_theme_font_size_override("font_size", 15)
	grimoire_stats_label.add_theme_color_override("font_color", PALETTE.ink)
	vbox.add_child(grimoire_stats_label)

	var collection_btn := Button.new()
	collection_btn.text = "\u25C6 Ouvrir le Grimoire \u25C6"
	collection_btn.custom_minimum_size = Vector2(200, 36)
	collection_btn.mouse_entered.connect(func(): SFXManager.play("hover"))
	collection_btn.pressed.connect(_on_collection_pressed)
	if body_font:
		collection_btn.add_theme_font_override("font", body_font)
	collection_btn.add_theme_font_size_override("font_size", 14)
	_style_nav_button(collection_btn)

	var btn_center := CenterContainer.new()
	btn_center.add_child(collection_btn)
	vbox.add_child(btn_center)


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION: Arbre de Vie (Talent Tree — Phase 35)
# ═══════════════════════════════════════════════════════════════════════════════

const ARBRE_TIER_ORDER := [4, 3, 2, 1]
const ARBRE_TIER_NODES := {
	4: ["racines_8", "tronc_4", "ramures_8", "feuillage_8"],
	3: ["racines_6", "racines_7", "tronc_2", "tronc_3", "ramures_6", "ramures_7", "feuillage_6", "feuillage_7"],
	2: ["racines_4", "racines_5", "tronc_1", "ramures_4", "ramures_5", "feuillage_4", "feuillage_5"],
	1: ["racines_1", "racines_2", "racines_3", "ramures_1", "ramures_2", "ramures_3", "feuillage_1", "feuillage_2", "feuillage_3"],
}

func _build_arbre_section() -> void:
	var card := _make_card()
	main_vbox.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	var title := _make_section_title("Arbre de Vie")
	vbox.add_child(title)

	# Full-screen Arbre de Vie button
	var full_btn := Button.new()
	full_btn.text = "Ouvrir l'Arbre complet"
	full_btn.custom_minimum_size = Vector2(0, 32)
	if body_font:
		full_btn.add_theme_font_override("font", body_font)
	full_btn.add_theme_font_size_override("font_size", 12)
	full_btn.add_theme_color_override("font_color", PALETTE.accent)
	full_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ArbreDeVie.tscn")
	)
	vbox.add_child(full_btn)

	# Tree nodes by tier (top = secrets, bottom = germes)
	for tier in ARBRE_TIER_ORDER:
		var tier_name: String = MerlinConstants.TALENT_TIER_NAMES.get(tier, "?")
		var tier_label := Label.new()
		tier_label.text = tier_name
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if body_font:
			tier_label.add_theme_font_override("font", body_font)
		tier_label.add_theme_font_size_override("font_size", 11)
		tier_label.add_theme_color_override("font_color", PALETTE.ink_faded)
		vbox.add_child(tier_label)

		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 3)
		vbox.add_child(row)

		var node_ids: Array = ARBRE_TIER_NODES.get(tier, [])
		var prev_branch := ""
		for node_id in node_ids:
			var node_data: Dictionary = MerlinConstants.TALENT_NODES.get(node_id, {})
			var branch: String = node_data.get("branch", "")

			# Spacer between branches
			if prev_branch != "" and branch != prev_branch:
				var spacer := Control.new()
				spacer.custom_minimum_size = Vector2(6, 0)
				row.add_child(spacer)
			prev_branch = branch

			var btn := Button.new()
			btn.custom_minimum_size = Vector2(42, 30)
			btn.tooltip_text = _get_arbre_node_tooltip(node_id)
			btn.mouse_entered.connect(_on_arbre_node_hover.bind(node_id))
			btn.pressed.connect(_on_talent_node_pressed.bind(node_id))
			if body_font:
				btn.add_theme_font_override("font", body_font)
			btn.add_theme_font_size_override("font_size", 10)
			arbre_node_buttons[node_id] = btn
			row.add_child(btn)

	# Branch legend
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 20)
	vbox.add_child(legend)

	for item in [["Sanglier", "Corps"], ["Tronc", "Universel"], ["Corbeau", "Ame"], ["Cerf", "Monde"]]:
		var lbl := Label.new()
		lbl.text = item[0]
		if body_font:
			lbl.add_theme_font_override("font", body_font)
		lbl.add_theme_font_size_override("font_size", 11)
		var branch_color: Color = MerlinConstants.TALENT_BRANCH_COLORS.get(item[1], PALETTE.ink_soft)
		lbl.add_theme_color_override("font_color", branch_color)
		legend.add_child(lbl)

	# Node info label (hover detail)
	arbre_info_label = Label.new()
	arbre_info_label.text = "Survole un noeud pour voir ses details"
	arbre_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arbre_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arbre_info_label.custom_minimum_size = Vector2(0, 32)
	if body_font:
		arbre_info_label.add_theme_font_override("font", body_font)
	arbre_info_label.add_theme_font_size_override("font_size", 12)
	arbre_info_label.add_theme_color_override("font_color", PALETTE.ink)
	vbox.add_child(arbre_info_label)

	# Essence display
	arbre_essence_label = Label.new()
	arbre_essence_label.text = ""
	arbre_essence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arbre_essence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if body_font:
		arbre_essence_label.add_theme_font_override("font", body_font)
	arbre_essence_label.add_theme_font_size_override("font_size", 11)
	arbre_essence_label.add_theme_color_override("font_color", PALETTE.accent)
	vbox.add_child(arbre_essence_label)

	# Currency display (fragments, liens, gloire)
	arbre_currency_label = Label.new()
	arbre_currency_label.text = ""
	arbre_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if body_font:
		arbre_currency_label.add_theme_font_override("font", body_font)
	arbre_currency_label.add_theme_font_size_override("font_size", 12)
	arbre_currency_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	vbox.add_child(arbre_currency_label)

	_update_arbre_display()


func _update_arbre_display() -> void:
	if store == null:
		return
	var meta: Dictionary = store.state.get("meta", {})
	var unlocked: Array = meta.get("talent_tree", {}).get("unlocked", [])
	var affordable: Array = store.get_affordable_talents()

	for node_id in arbre_node_buttons:
		var btn: Button = arbre_node_buttons[node_id]
		var node_data: Dictionary = MerlinConstants.TALENT_NODES.get(node_id, {})
		var branch: String = node_data.get("branch", "")
		var branch_color: Color = MerlinConstants.TALENT_BRANCH_COLORS.get(branch, PALETTE.ink_soft)
		var node_name: String = node_data.get("name", node_id)
		var tier: int = node_data.get("tier", 1)

		var is_unlocked: bool = unlocked.has(node_id)
		var is_affordable: bool = affordable.has(node_id)

		# Button text
		if is_unlocked:
			btn.text = "\u2713"
		elif tier == 4 and not is_affordable:
			btn.text = "?"
		else:
			var words: PackedStringArray = node_name.split(" ")
			btn.text = words[0].left(5) if words.size() > 0 else "?"

		btn.tooltip_text = _get_arbre_node_tooltip(node_id)
		_style_arbre_node(btn, branch_color, is_unlocked, is_affordable)

	_update_arbre_info()

	# Essence display
	var essence: Dictionary = meta.get("essence", {})
	var parts: PackedStringArray = []
	for elem in MerlinConstants.ELEMENTS:
		var count: int = essence.get(elem, 0)
		if count > 0:
			parts.append("%s:%d" % [elem.left(4), count])
	if arbre_essence_label:
		arbre_essence_label.text = " | ".join(parts) if parts.size() > 0 else "Aucune essence collectee"

	# Currency display
	var fragments: int = meta.get("ogham_fragments", 0)
	var liens: int = meta.get("liens", 0)
	var gloire: int = meta.get("gloire_points", 0)
	if arbre_currency_label:
		arbre_currency_label.text = "Fragments: %d  |  Liens: %d  |  Gloire: %d" % [fragments, liens, gloire]


func _style_arbre_node(btn: Button, branch_color: Color, is_unlocked: bool, is_affordable: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2

	if is_unlocked:
		style.bg_color = branch_color
		style.border_color = branch_color.darkened(0.3)
		style.set_border_width_all(2)
		btn.add_theme_color_override("font_color", PALETTE.paper)
		btn.add_theme_color_override("font_disabled_color", PALETTE.paper)
		btn.disabled = true
	elif is_affordable:
		style.bg_color = PALETTE.paper_warm
		style.border_color = PALETTE.warning
		style.set_border_width_all(2)
		btn.add_theme_color_override("font_color", PALETTE.ink)
		btn.add_theme_color_override("font_hover_color", PALETTE.warning)
		btn.disabled = false
	else:
		style.bg_color = PALETTE.paper_dark
		style.border_color = PALETTE.ink_faded
		style.set_border_width_all(1)
		btn.add_theme_color_override("font_color", PALETTE.ink_faded)
		btn.add_theme_color_override("font_disabled_color", PALETTE.ink_faded)
		btn.disabled = true

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("disabled", style.duplicate())

	var hover := style.duplicate()
	if is_affordable:
		hover.bg_color = Color(PALETTE.warning.r, PALETTE.warning.g, PALETTE.warning.b, 0.3)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	if is_affordable:
		pressed.bg_color = PALETTE.warning
	btn.add_theme_stylebox_override("pressed", pressed)


func _update_arbre_info() -> void:
	if arbre_info_label == null:
		return
	if _arbre_selected_node == "" or not MerlinConstants.TALENT_NODES.has(_arbre_selected_node):
		arbre_info_label.text = "Survole un noeud pour voir ses details"
		return

	var node: Dictionary = MerlinConstants.TALENT_NODES[_arbre_selected_node]
	var talent_name: String = node.get("name", "?")
	var desc: String = node.get("description", "")
	var cost: Dictionary = node.get("cost", {})
	var cost_parts: PackedStringArray = []
	for c in cost:
		cost_parts.append("%s %s" % [str(cost[c]), c])
	var cost_text: String = ", ".join(cost_parts) if cost_parts.size() > 0 else "Gratuit"

	var status := ""
	if store and store.is_talent_active(_arbre_selected_node):
		status = " [Debloque]"
	elif store and store.can_unlock_talent(_arbre_selected_node):
		status = " [Disponible]"

	arbre_info_label.text = "%s%s — %s (Cout: %s)" % [talent_name, status, desc, cost_text]


func _get_arbre_node_tooltip(node_id: String) -> String:
	var node: Dictionary = MerlinConstants.TALENT_NODES.get(node_id, {})
	var talent_name: String = node.get("name", "?")
	var desc: String = node.get("description", "")
	var lore: String = node.get("lore", "")
	if lore != "":
		return "%s\n%s\n\n%s" % [talent_name, desc, lore]
	return "%s\n%s" % [talent_name, desc]


func _on_arbre_node_hover(node_id: String) -> void:
	SFXManager.play("hover")
	_arbre_selected_node = node_id
	_update_arbre_info()


func _on_talent_node_pressed(node_id: String) -> void:
	if store == null:
		return
	if not store.can_unlock_talent(node_id):
		return
	SFXManager.play("choice_select")
	var result: Dictionary = store.unlock_talent(node_id)
	if result.get("ok", false):
		_update_arbre_display()


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION: Adventure Button (Start run)
# ═══════════════════════════════════════════════════════════════════════════════

func _build_expedition_prep_section() -> void:
	## Streamlined adventure preparation — no numbered steps.
	## All choices visible, Merlin comments via LLM passively.
	var card := _make_card()
	main_vbox.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	var title := _make_section_title("Aventure")
	vbox.add_child(title)

	expedition_check_labels.clear()

	# ── Adventure Button (prominent, at the top) ──
	_build_adventure_button(vbox)

	# ── Merlin Reactive Comment (LLM passive) ──
	merlin_reaction_label = RichTextLabel.new()
	merlin_reaction_label.bbcode_enabled = true
	merlin_reaction_label.fit_content = true
	merlin_reaction_label.scroll_active = false
	merlin_reaction_label.custom_minimum_size = Vector2(0, 0)
	if body_font:
		merlin_reaction_label.add_theme_font_override("normal_font", body_font)
	merlin_reaction_label.add_theme_font_size_override("normal_font_size", 13)
	merlin_reaction_label.add_theme_color_override("default_color", PALETTE.ink_soft)
	merlin_reaction_label.text = ""
	vbox.add_child(merlin_reaction_label)

	# ── Destination ──
	_build_prep_step_destination(vbox)

	# ── Tool Selection ──
	_build_prep_step_tools(vbox)

	# ── Departure Conditions ──
	_build_prep_step_conditions(vbox)

	_update_adventure_button_state()


func _build_prep_step_destination(parent: VBoxContainer) -> void:
	var step_vbox := VBoxContainer.new()
	step_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_vbox.add_theme_constant_override("separation", 4)
	parent.add_child(step_vbox)

	var step_title := Label.new()
	step_title.text = "Destination"
	if title_font:
		step_title.add_theme_font_override("font", title_font)
	step_title.add_theme_font_size_override("font_size", 13)
	step_title.add_theme_color_override("font_color", PALETTE.accent)
	step_vbox.add_child(step_title)

	destination_display_label = Label.new()
	destination_display_label.text = "Aucune destination choisie"
	destination_display_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if body_font:
		destination_display_label.add_theme_font_override("font", body_font)
	destination_display_label.add_theme_font_size_override("font_size", 12)
	destination_display_label.add_theme_color_override("font_color", PALETTE.ink_faded)
	step_vbox.add_child(destination_display_label)

	var map_btn := Button.new()
	map_btn.text = "\u25C6 Voir la Carte"
	map_btn.custom_minimum_size = Vector2(140, 28)
	map_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if body_font:
		map_btn.add_theme_font_override("font", body_font)
	map_btn.add_theme_font_size_override("font_size", 13)
	map_btn.mouse_entered.connect(func(): SFXManager.play("hover"))
	map_btn.pressed.connect(_open_mapmonde_overlay)
	_style_nav_button(map_btn)
	step_vbox.add_child(map_btn)

	# Update display if biome already selected
	if selected_biome != "":
		_update_destination_display()


func _build_prep_step_tools(parent: VBoxContainer) -> void:
	var step_vbox := VBoxContainer.new()
	step_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_vbox.add_theme_constant_override("separation", 4)
	parent.add_child(step_vbox)

	var step_title := Label.new()
	step_title.text = "Outil"
	if title_font:
		step_title.add_theme_font_override("font", title_font)
	step_title.add_theme_font_size_override("font_size", 13)
	step_title.add_theme_color_override("font_color", PALETTE.accent)
	step_vbox.add_child(step_title)

	var tools_flow := HBoxContainer.new()
	tools_flow.alignment = BoxContainer.ALIGNMENT_CENTER
	tools_flow.add_theme_constant_override("separation", 6)
	step_vbox.add_child(tools_flow)

	tool_buttons.clear()
	for tool_id in MerlinConstants.EXPEDITION_TOOLS:
		var tool_data: Dictionary = MerlinConstants.EXPEDITION_TOOLS[tool_id]
		var btn := Button.new()
		btn.text = "%s\n%s" % [tool_data.get("icon", "?"), tool_data.get("name", "")]
		btn.custom_minimum_size = Vector2(80, 38)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.clip_text = false
		if body_font:
			btn.add_theme_font_override("font", body_font)
		btn.add_theme_font_size_override("font_size", 10)
		btn.tooltip_text = tool_data.get("description", "") + "\n" + tool_data.get("bonus", "")
		btn.mouse_entered.connect(func(): SFXManager.play("hover"))
		btn.pressed.connect(_on_tool_selected.bind(tool_id))
		_style_tool_button(btn, false)
		tool_buttons[tool_id] = btn
		tools_flow.add_child(btn)


func _build_prep_step_conditions(parent: VBoxContainer) -> void:
	var step_vbox := VBoxContainer.new()
	step_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_vbox.add_theme_constant_override("separation", 3)
	parent.add_child(step_vbox)

	var step_title := Label.new()
	step_title.text = "Conditions"
	if title_font:
		step_title.add_theme_font_override("font", title_font)
	step_title.add_theme_font_size_override("font_size", 13)
	step_title.add_theme_color_override("font_color", PALETTE.accent)
	step_vbox.add_child(step_title)

	departure_buttons.clear()
	for cond_id in MerlinConstants.DEPARTURE_CONDITIONS:
		var cond: Dictionary = MerlinConstants.DEPARTURE_CONDITIONS[cond_id]
		var btn := Button.new()
		btn.text = "%s %s  —  %s" % [cond.get("icon", ""), cond.get("name", ""), cond.get("effect_label", "")]
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 24)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if body_font:
			btn.add_theme_font_override("font", body_font)
		btn.add_theme_font_size_override("font_size", 11)
		btn.mouse_entered.connect(func(): SFXManager.play("hover"))
		btn.pressed.connect(_on_departure_condition_selected.bind(cond_id))
		_style_condition_button(btn, false)
		departure_buttons[cond_id] = btn
		step_vbox.add_child(btn)


func _build_adventure_button(parent: VBoxContainer) -> void:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(center)

	adventure_btn = Button.new()
	adventure_btn.text = "\u25C7  Incomplet  \u25C7"
	adventure_btn.custom_minimum_size = Vector2(280, 42)
	adventure_btn.disabled = true
	adventure_btn.mouse_entered.connect(func(): SFXManager.play("hover"))
	adventure_btn.pressed.connect(_on_start_adventure)

	if title_font:
		adventure_btn.add_theme_font_override("font", title_font)
	adventure_btn.add_theme_font_size_override("font_size", 20)

	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.accent
	style.border_color = PALETTE.ink
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = PALETTE.shadow
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	adventure_btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = PALETTE.accent_soft
	adventure_btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = PALETTE.ink
	adventure_btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := style.duplicate()
	disabled.bg_color = PALETTE.paper_dark
	disabled.border_color = PALETTE.ink_faded
	adventure_btn.add_theme_stylebox_override("disabled", disabled)

	adventure_btn.add_theme_color_override("font_color", PALETTE.paper)
	adventure_btn.add_theme_color_override("font_hover_color", PALETTE.paper)
	adventure_btn.add_theme_color_override("font_pressed_color", PALETTE.accent_glow)
	adventure_btn.add_theme_color_override("font_disabled_color", PALETTE.ink_faded)

	center.add_child(adventure_btn)


# ── Expedition Selection Handlers ──

func _on_tool_selected(tool_id: String) -> void:
	SFXManager.play("click")
	selected_tool = tool_id
	for tid in tool_buttons:
		_style_tool_button(tool_buttons[tid], tid == selected_tool)
	_update_expedition_checks()
	_update_merlin_reaction()
	_update_adventure_button_state()


func _on_departure_condition_selected(cond_id: String) -> void:
	SFXManager.play("click")
	selected_departure_condition = cond_id
	for cid in departure_buttons:
		var btn: Button = departure_buttons[cid]
		btn.button_pressed = (cid == selected_departure_condition)
		_style_condition_button(btn, cid == selected_departure_condition)
	_update_expedition_checks()
	_update_merlin_reaction()
	_update_adventure_button_state()


func _update_destination_display() -> void:
	if destination_display_label == null:
		return
	if selected_biome == "":
		destination_display_label.text = "Aucune destination choisie"
		destination_display_label.add_theme_color_override("font_color", PALETTE.ink_faded)
	else:
		var biome: Dictionary = BIOME_DATA.get(selected_biome, {})
		var bc: Color = biome.get("color", PALETTE.ink)
		destination_display_label.text = "\u2192 %s  —  %s" % [biome.get("name", "Inconnu"), biome.get("subtitle", "")]
		destination_display_label.add_theme_color_override("font_color", bc)


func _update_expedition_checks() -> void:
	# No more check marks — handled by adventure button state
	_update_adventure_button_state()


func _update_merlin_reaction() -> void:
	if merlin_reaction_label == null:
		return

	# Build context for Merlin's reaction
	var context_parts: PackedStringArray = []
	if selected_biome != "":
		var biome_name: String = BIOME_DATA.get(selected_biome, {}).get("name", selected_biome)
		context_parts.append("destination: %s" % biome_name)
	if selected_tool != "":
		var tool_name: String = MerlinConstants.EXPEDITION_TOOLS.get(selected_tool, {}).get("name", selected_tool)
		context_parts.append("outil: %s" % tool_name)
	if selected_departure_condition != "":
		var cond_name: String = MerlinConstants.DEPARTURE_CONDITIONS.get(selected_departure_condition, {}).get("name", selected_departure_condition)
		context_parts.append("condition: %s" % cond_name)

	if context_parts.is_empty():
		merlin_reaction_label.text = ""
		return

	# Try LLM passive comment (async, non-blocking)
	_request_merlin_passive_comment(", ".join(context_parts))

	# Immediate fallback while LLM generates
	var fallback_lines: PackedStringArray = []
	if selected_tool != "":
		var reaction: String = MerlinConstants.EXPEDITION_MERLIN_REACTIONS.get(selected_tool, "")
		if reaction != "":
			fallback_lines.append("[i]\u00AB %s \u00BB[/i]" % reaction)
	if selected_biome != "" and selected_tool != "" and selected_departure_condition != "":
		fallback_lines.append("[color=#%s][i]\u00AB Tu es pret, Voyageur. \u00BB[/i][/color]" % PALETTE.success.to_html(false))
	merlin_reaction_label.text = "\n".join(fallback_lines)


var _passive_llm_pending: bool = false

func _request_merlin_passive_comment(context: String) -> void:
	## Async LLM call for Merlin's passive commentary. Non-blocking.
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

	# Update merlin reaction with LLM text + auto-fade after 4s
	if merlin_reaction_label and is_instance_valid(merlin_reaction_label):
		merlin_reaction_label.text = "[i]\u00AB %s \u00BB[/i]" % text
		if merlin_source_badge and is_instance_valid(merlin_source_badge):
			LLMSourceBadge.update_badge(merlin_source_badge, "llm")
		# Auto-fade after 4s
		var fade_tw := create_tween()
		fade_tw.tween_interval(4.0)
		fade_tw.tween_property(merlin_reaction_label, "modulate:a", 0.3, 1.0)
		fade_tw.tween_callback(func():
			if merlin_reaction_label and is_instance_valid(merlin_reaction_label):
				merlin_reaction_label.modulate.a = 1.0
		)


func _update_adventure_button_state() -> void:
	expedition_ready = (selected_biome != "" and selected_tool != "" and selected_departure_condition != "")
	if adventure_btn == null:
		return
	if expedition_ready:
		adventure_btn.disabled = false
		var biome: Dictionary = BIOME_DATA.get(selected_biome, {})
		adventure_btn.text = "\u25C6  PARTIR VERS %s  \u25C6" % biome.get("name", "L'INCONNU").to_upper()
	else:
		adventure_btn.disabled = true
		var missing: PackedStringArray = []
		if selected_biome == "":
			missing.append("destination")
		if selected_tool == "":
			missing.append("outil")
		if selected_departure_condition == "":
			missing.append("conditions")
		adventure_btn.text = "\u25C7  Incomplet: %s  \u25C7" % ", ".join(missing)


func _style_tool_button(btn: Button, is_selected: bool) -> void:
	var style := StyleBoxFlat.new()
	if is_selected:
		style.bg_color = PALETTE.accent
		style.border_color = PALETTE.ink
		style.set_border_width_all(2)
		btn.add_theme_color_override("font_color", PALETTE.paper)
	else:
		style.bg_color = PALETTE.paper_dark
		style.border_color = PALETTE.accent_soft
		style.set_border_width_all(1)
		btn.add_theme_color_override("font_color", PALETTE.ink)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = PALETTE.accent_soft if is_selected else PALETTE.accent_glow
	btn.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := style.duplicate()
	pressed_style.bg_color = PALETTE.accent
	btn.add_theme_stylebox_override("pressed", pressed_style)


func _style_condition_button(btn: Button, is_selected: bool) -> void:
	var style := StyleBoxFlat.new()
	if is_selected:
		style.bg_color = Color(PALETTE.accent.r, PALETTE.accent.g, PALETTE.accent.b, 0.25)
		style.border_color = PALETTE.accent
		style.set_border_width_all(1)
		btn.add_theme_color_override("font_color", PALETTE.ink)
	else:
		style.bg_color = Color.TRANSPARENT
		style.border_color = PALETTE.ink_faded
		style.set_border_width_all(1)
		btn.add_theme_color_override("font_color", PALETTE.ink_soft)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = PALETTE.accent_glow
	btn.add_theme_stylebox_override("hover", hover_style)


# ═══════════════════════════════════════════════════════════════════════════════
# BOTTOM BAR — Navigation buttons
# ═══════════════════════════════════════════════════════════════════════════════

func _build_bottom_bar() -> void:
	bottom_bar = HBoxContainer.new()
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_bar.add_theme_constant_override("separation", 4)
	bottom_bar.modulate.a = 0.0
	add_child(bottom_bar)

	# LEFT: Tab buttons (compact)
	var tab_defs := [
		{"label": "Antre", "icon": "merlin"},
		{"label": "Compagnons", "icon": "bestiole"},
	]

	for i in range(tab_defs.size()):
		var btn := Button.new()
		var icon_ctrl := _make_celtic_icon(tab_defs[i]["icon"], 16.0)
		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 3)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon_ctrl)
		var lbl := Label.new()
		lbl.text = tab_defs[i]["label"]
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if body_font:
			lbl.add_theme_font_override("font", body_font)
		lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl)
		btn.add_child(hbox)
		btn.custom_minimum_size = Vector2(100, 36)
		btn.mouse_entered.connect(func(): SFXManager.play("hover"))
		btn.pressed.connect(_on_tab_pressed.bind(i))
		_style_tab_button(btn, i == 0)
		tab_buttons.append(btn)
		bottom_bar.add_child(btn)

	# Flexible spacer between tabs and utility icons
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(spacer)

	# RIGHT: Utility icon buttons (compact)
	var icon_items := [
		{"type": "calendar", "label": "Calendrier", "action": "calendar"},
		{"type": "collection", "label": "Collection", "action": "collection"},
		{"type": "save", "label": "Sauvegarder", "action": "save"},
		{"type": "options", "label": "Options", "action": "options"},
		{"type": "menu", "label": "Menu", "action": "menu"},
	]

	for item in icon_items:
		var btn := Button.new()
		btn.tooltip_text = item["label"]
		btn.custom_minimum_size = Vector2(36, 36)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_icon_button(btn)
		var icon := _make_celtic_icon(item["type"], 18.0)
		icon.position = Vector2(9, 9)
		btn.add_child(icon)

		btn.mouse_entered.connect(_on_icon_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_icon_hover.bind(btn, false))

		match item["action"]:
			"calendar":
				btn.pressed.connect(_on_calendar_pressed)
			"collection":
				btn.pressed.connect(_on_collection_pressed)
			"save":
				btn.pressed.connect(_on_save_pressed)
				save_btn = btn
			"options":
				btn.pressed.connect(_on_options_pressed)
			"menu":
				btn.pressed.connect(_on_menu_pressed)

		bottom_bar.add_child(btn)


func _on_tab_pressed(tab_index: int) -> void:
	## Switch between 2 pages: Antre (0) and Compagnons (1).
	if tab_index == current_tab:
		return
	if tab_index < 0 or tab_index >= tab_pages.size():
		return
	SFXManager.play("click")

	var old_page := tab_pages[current_tab]
	var new_page := tab_pages[tab_index]

	var tw := create_tween()
	tw.tween_property(old_page, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func(): old_page.visible = false)
	tw.tween_callback(func():
		new_page.visible = true
		new_page.modulate.a = 0.0
	)
	tw.tween_property(new_page, "modulate:a", 1.0, 0.2)

	for i in range(tab_buttons.size()):
		_style_tab_button(tab_buttons[i], i == tab_index)

	current_tab = tab_index


func _style_tab_button(btn: Button, is_active: bool) -> void:
	var style := StyleBoxFlat.new()
	if is_active:
		style.bg_color = PALETTE.accent
		style.border_color = PALETTE.ink
		btn.add_theme_color_override("font_color", PALETTE.paper)
	else:
		style.bg_color = PALETTE.paper_warm
		style.border_color = PALETTE.ink_faded
		btn.add_theme_color_override("font_color", PALETTE.ink_soft)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = PALETTE.accent_soft if is_active else PALETTE.paper_dark
	btn.add_theme_stylebox_override("hover", hover_style)


# ═══════════════════════════════════════════════════════════════════════════════
# LAYOUT — Responsive positioning
# ═══════════════════════════════════════════════════════════════════════════════

func _layout_ui() -> void:
	var vp := get_viewport_rect().size
	var margin := 16.0
	var compact: bool = vp.y < 800

	# Ornaments
	celtic_top.position = Vector2(0, margin)
	celtic_top.size = Vector2(vp.x, 24)
	celtic_bottom.position = Vector2(0, vp.y - margin - 24)
	celtic_bottom.size = Vector2(vp.x, 24)

	# Bottom bar
	var bottom_h: float = 40.0 if compact else 48.0
	bottom_bar.position = Vector2(0, vp.y - margin - 28 - bottom_h)
	bottom_bar.size = Vector2(vp.x, bottom_h)

	# Tab content area (between ornaments, above bottom bar — NO scroll)
	var content_top: float = margin + 28
	var content_bottom: float = bottom_bar.position.y - 8
	var content_height: float = content_bottom - content_top

	tab_container.position = Vector2(margin, content_top)
	var tab_size := Vector2(vp.x - margin * 2, content_height)
	tab_container.set_deferred("size", tab_size)

	# Layout each page
	var content_width: float = minf(vp.x - margin * 2 - 16, CARD_MAX_WIDTH)
	var content_offset: float = maxf((tab_size.x - content_width) / 2.0, 0.0)

	for page in tab_pages:
		page.position = Vector2.ZERO
		page.set_deferred("size", tab_size)
		var vbox := page.get_child(0) as VBoxContainer
		if vbox:
			vbox.position = Vector2(content_offset, 0)
			vbox.set_deferred("size", Vector2(content_width, content_height))
			vbox.custom_minimum_size = Vector2(content_width, 0)


func _on_resized() -> void:
	_layout_ui()
	_layout_map()


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN DIALOGUE — Typewriter + Voice
# ═══════════════════════════════════════════════════════════════════════════════

func _play_merlin_greeting() -> void:
	var text := _get_greeting_text()
	merlin_text.text = text
	merlin_text.visible_characters = 0
	typing_active = true
	typing_abort = false

	var total := merlin_text.get_total_character_count()
	for i in range(total):
		if typing_abort:
			merlin_text.visible_characters = -1
			break
		merlin_text.visible_characters = i + 1

		var ch: String = text[mini(i, text.length() - 1)]
		if ch in [".", ",", "!", "?", ":"]:
			_play_blip()
			await get_tree().create_timer(TYPEWRITER_PUNCT_DELAY).timeout
		else:
			if i % 2 == 0:
				_play_blip()
			await get_tree().create_timer(TYPEWRITER_DELAY).timeout

	merlin_text.visible_characters = -1
	typing_active = false


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

	var idx: int = randi() % pool.size()
	return pool[idx] % chronicle_name


func _play_blip() -> void:
	## Soft keyboard click — procedural
	if audio_player == null:
		return
	var sample_rate := 44100.0
	var duration := 0.014
	var num_samples := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_rate)
	stream.stereo = false

	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var freq := randf_range(260.0, 360.0)
	for s in range(num_samples):
		var t := float(s) / sample_rate
		var envelope := exp(-t * 320.0)
		var click := sin(TAU * freq * t) * 0.35
		var noise := randf_range(-1.0, 1.0) * 0.12
		var value := (click + noise) * envelope * 0.25
		var sample_val := int(clampf(value, -1.0, 1.0) * 32767.0)
		data[s * 2] = sample_val & 0xFF
		data[s * 2 + 1] = (sample_val >> 8) & 0xFF

	stream.data = data
	audio_player.stream = stream
	audio_player.volume_db = linear_to_db(BLIP_VOLUME)
	audio_player.play()


# ═══════════════════════════════════════════════════════════════════════════════
# STATE DISPLAY — Update from MerlinStore
# ═══════════════════════════════════════════════════════════════════════════════

func _update_aspect_display() -> void:
	if store == null:
		return
	var aspects: Dictionary = store.state.get("run", {}).get("aspects", {})

	for aspect_name in aspect_labels:
		var label: Label = aspect_labels[aspect_name]
		var state_val: int = aspects.get(aspect_name, 0)
		var info: Dictionary = MerlinConstants.TRIADE_ASPECT_INFO.get(aspect_name, {})
		var states: Dictionary = info.get("states", {})
		var state_name: String = states.get(state_val, "Inconnu")

		var icon := "\u25CF"
		var color: Color = PALETTE.success
		if state_val == -1:
			icon = "\u25BC"
			color = PALETTE.danger
		elif state_val == 1:
			icon = "\u25B2"
			color = PALETTE.warning

		label.text = "%s %s" % [icon, state_name]
		label.add_theme_color_override("font_color", color)


func _update_souffle_display() -> void:
	if store == null or souffle_label == null:
		return
	var souffle: int = store.state.get("run", {}).get("souffle", MerlinConstants.SOUFFLE_START)
	var text := "Souffle: "
	for i in range(MerlinConstants.SOUFFLE_MAX):
		text += "\u25CF" if i < souffle else "\u25CB"
	souffle_label.text = text

	var day: int = store.state.get("run", {}).get("day", 1)
	if day_label:
		day_label.text = "Jour: %d" % day


func _update_mission_display() -> void:
	if mission_label == null:
		return
	if _current_mission.is_empty():
		mission_label.text = "Selectionne un biome pour recevoir ta mission"
		mission_progress_bar.visible = false
		return

	mission_label.text = _current_mission.get("target", "Mission inconnue")
	var total: int = _current_mission.get("total", 1)
	var progress: int = _current_mission.get("progress", 0)
	if total > 0:
		mission_progress_bar.max_value = total
		mission_progress_bar.value = progress
		mission_progress_bar.visible = true
	else:
		mission_progress_bar.visible = false


func _update_biome_selection() -> void:
	# Stop existing pulse
	if _map_pulse_tween:
		_map_pulse_tween.kill()
		_map_pulse_tween = null

	var meta: Dictionary = store.state.get("meta", {}) if store else {}

	for biome_key in biome_buttons:
		var btn: Button = biome_buttons[biome_key]
		var biome: Dictionary = BIOME_DATA.get(biome_key, {})
		var unlocked: bool = _biome_system.is_unlocked(biome_key, meta)
		btn.disabled = not unlocked

		if not unlocked:
			# Locked biome: show lock icon and dim
			btn.modulate = Color(0.5, 0.5, 0.5, 0.6)
			btn.tooltip_text = _biome_system.get_unlock_hint(biome_key)
		else:
			btn.modulate = Color.WHITE
			btn.tooltip_text = ""
			_style_biome_button(btn, biome, biome_key == selected_biome)

		btn.pivot_offset = btn.size * 0.5

		if biome_key == selected_biome and unlocked:
			# Gentle pulse animation on selected marker
			_map_pulse_tween = create_tween().set_loops()
			_map_pulse_tween.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_map_pulse_tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			btn.scale = Vector2(1.0, 1.0)

	# Highlight connected paths
	var line_idx := 0
	if map_paths_node == null:
		return
	for conn in BIOME_CONNECTIONS:
		if line_idx >= map_paths_node.get_child_count():
			break
		var line: Line2D = map_paths_node.get_child(line_idx) as Line2D
		var is_active := selected_biome in conn
		line.default_color = Color(PALETTE.accent.r, PALETTE.accent.g, PALETTE.accent.b, 0.5) if is_active else Color(PALETTE.ink_faded.r, PALETTE.ink_faded.g, PALETTE.ink_faded.b, 0.25)
		line.width = 2.5 if is_active else 1.5
		line_idx += 1

	if selected_biome != "" and BIOME_DATA.has(selected_biome):
		var biome: Dictionary = BIOME_DATA[selected_biome]
		var ogham_name: String = MerlinConstants.OGHAM_SKILLS.get(biome.get("ogham", ""), {}).get("name", "?")
		var aspect_hint: String = biome.get("aspect_hint", "")
		var diff_label: String = biome.get("difficulty_label", "Normal")
		biome_detail_label.text = "%s \u2014 Gardien: %s | Ogham: %s | Saison: %s | %s | %s" % [
			biome.get("subtitle", ""),
			biome.get("guardian", "?"),
			ogham_name,
			biome.get("season", "?"),
			aspect_hint,
			diff_label,
		]
	else:
		biome_detail_label.text = ""


func _update_bestiole_display() -> void:
	if store == null:
		return
	var bestiole: Dictionary = store.state.get("bestiole", {})
	var bond: int = bestiole.get("bond", 50)
	var awen: int = bestiole.get("awen", 2)
	var needs: Dictionary = bestiole.get("needs", {})

	# Evolution stage display (Phase 35)
	var evo_stage: int = 1
	var evo_path: String = ""
	var meta_evo: Dictionary = store.state.get("meta", {}).get("bestiole_evolution", {})
	evo_stage = int(meta_evo.get("stage", 1))
	evo_path = str(meta_evo.get("path", ""))
	var stage_names := {1: "Enfant", 2: "Compagnon", 3: "Gardien"}
	var stage_text: String = stage_names.get(evo_stage, "?")
	if evo_path != "":
		stage_text += " (%s)" % evo_path.capitalize()

	# Bond display
	var tier_name := _get_bond_tier_name(bond)
	var bond_dots := ""
	for i in range(5):
		bond_dots += "\u25CF" if bond >= (i + 1) * 20 else "\u25CB"
	bestiole_bond_label.text = "%s | Lien: %s %s (%d)" % [stage_text, bond_dots, tier_name, bond]

	# Awen display
	var awen_max: int = 5
	var awen_text := "Awen: "
	for i in range(awen_max):
		awen_text += "\u2605" if i < awen else "\u2606"
	bestiole_awen_label.text = awen_text

	# Needs bars
	for child in bestiole_needs_container.get_children():
		child.queue_free()

	var need_labels := {"Hunger": "Faim", "Energy": "Energie", "Hygiene": "Hygiene", "Mood": "Humeur", "Stress": "Stress"}
	for need_key in ["Hunger", "Energy", "Hygiene", "Mood", "Stress"]:
		var value: int = needs.get(need_key, 50)
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)

		var name_lbl := Label.new()
		name_lbl.text = need_labels.get(need_key, need_key)
		name_lbl.custom_minimum_size = Vector2(70, 0)
		if body_font:
			name_lbl.add_theme_font_override("font", body_font)
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", PALETTE.ink_soft)
		hbox.add_child(name_lbl)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(120, 10)
		bar.min_value = 0
		bar.max_value = 100
		bar.value = value
		bar.show_percentage = false

		var bg := StyleBoxFlat.new()
		bg.bg_color = PALETTE.paper_dark
		bg.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("background", bg)

		var fill := StyleBoxFlat.new()
		var bar_color: Color = PALETTE.success
		if need_key == "Stress":
			bar_color = PALETTE.danger if value > 60 else PALETTE.success
		else:
			bar_color = PALETTE.danger if value < 30 else PALETTE.success
		fill.bg_color = bar_color
		fill.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("fill", fill)
		hbox.add_child(bar)

		bestiole_needs_container.add_child(hbox)

	# Oghams equipped
	for child in ogham_container.get_children():
		child.queue_free()

	var equipped: Array = bestiole.get("skills_equipped", [])
	if equipped.size() > 0:
		SFXManager.play("ogham_chime")
	for skill_id in equipped:
		var skill_data: Dictionary = MerlinConstants.OGHAM_SKILLS.get(skill_id, {})
		var ogham_lbl := Label.new()
		ogham_lbl.text = skill_data.get("name", skill_id)
		ogham_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if body_font:
			ogham_lbl.add_theme_font_override("font", body_font)
		ogham_lbl.add_theme_font_size_override("font_size", 14)
		ogham_lbl.add_theme_color_override("font_color", PALETTE.ogham_glow)

		var panel := PanelContainer.new()
		var ps := StyleBoxFlat.new()
		ps.bg_color = PALETTE.paper_dark
		ps.border_color = PALETTE.ogham_glow
		ps.set_border_width_all(1)
		ps.set_corner_radius_all(4)
		ps.content_margin_left = 8
		ps.content_margin_right = 8
		ps.content_margin_top = 4
		ps.content_margin_bottom = 4
		panel.add_theme_stylebox_override("panel", ps)
		panel.add_child(ogham_lbl)
		ogham_container.add_child(panel)

	# Care remaining
	care_remaining_label.text = "Soins restants: %d" % _care_remaining
	for btn_key in care_buttons:
		var btn: Button = care_buttons[btn_key]
		btn.disabled = _care_remaining <= 0


func _update_grimoire_display() -> void:
	if store == null or grimoire_stats_label == null:
		return
	var meta: Dictionary = store.state.get("meta", {})
	var runs: int = meta.get("total_runs", 0)
	var endings: Array = meta.get("endings_seen", [])
	var gloire: int = meta.get("gloire_points", 0)
	var cards: int = meta.get("total_cards_played", 0)
	grimoire_stats_label.text = "Runs: %d  \u2502  Fins: %d/16  \u2502  Cartes: %d  \u2502  Gloire: %d" % [
		runs, endings.size(), cards, gloire
	]


func _update_adventure_button() -> void:
	# Redirect to new expedition system
	_update_expedition_checks()
	_update_adventure_button_state()


# ═══════════════════════════════════════════════════════════════════════════════
# INTERACTIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_biome_selected(biome_key: String) -> void:
	SFXManager.play("choice_select")
	selected_biome = biome_key
	_update_biome_selection()

	# Generate a mission for this biome
	var missions: Array = BIOME_MISSIONS.get(biome_key, [])
	if missions.size() > 0:
		_current_mission = missions[randi() % missions.size()].duplicate()
		_current_mission["progress"] = 0
	else:
		_current_mission = {"type": "exploration", "target": "Explorer ce sanctuaire", "total": 8, "progress": 0}

	_update_mission_display()
	_update_destination_display()
	_update_expedition_checks()
	_update_merlin_reaction()
	_update_adventure_button_state()


func _on_care_action(action_key: String) -> void:
	if _care_remaining <= 0 or store == null:
		return
	SFXManager.play("bestiole_shimmer")

	_care_remaining -= 1
	var action: Dictionary = CARE_ACTIONS.get(action_key, {})
	var bestiole: Dictionary = store.state.get("bestiole", {})
	var needs: Dictionary = bestiole.get("needs", {})
	var bond: int = bestiole.get("bond", 50)

	var need_key: String = action.get("need", "")
	var amount: int = action.get("amount", 0)
	var bond_gain: int = action.get("bond", 0)

	if need_key != "":
		needs[need_key] = mini(needs.get(need_key, 50) + amount, 100)

	if action.has("stress_reduce"):
		needs["Stress"] = maxi(needs.get("Stress", 0) - action["stress_reduce"], 0)

	bond = mini(bond + bond_gain, 100)

	bestiole["needs"] = needs
	bestiole["bond"] = bond
	store.state["bestiole"] = bestiole

	_update_bestiole_display()


func _on_save_pressed() -> void:
	SFXManager.play("click")
	_quick_save()


func _on_options_pressed() -> void:
	SFXManager.play("click")
	_store_return_scene()
	SFXManager.play("whoosh")
	get_tree().change_scene_to_file(SCENE_OPTIONS)


func _on_calendar_pressed() -> void:
	SFXManager.play("click")
	_store_return_scene()
	SFXManager.play("whoosh")
	get_tree().change_scene_to_file(SCENE_CALENDAR)


func _on_collection_pressed() -> void:
	SFXManager.play("click")
	_store_return_scene()
	SFXManager.play("whoosh")
	get_tree().change_scene_to_file(SCENE_COLLECTION)


func _store_return_scene() -> void:
	var se := get_node_or_null("/root/ScreenEffects")
	if se:
		se.return_scene = get_tree().current_scene.scene_file_path


func _open_mapmonde_overlay() -> void:
	SFXManager.play("click")
	if get_node_or_null("MapMondeOverlay"):
		return  # Already open
	var scene_res := load(SCENE_MAPMONDE)
	if scene_res == null:
		push_warning("[HubAntre] MapMonde scene not found: %s" % SCENE_MAPMONDE)
		return
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.name = "MapMondeOverlay"
	overlay.z_index = 100
	add_child(overlay)

	var map_instance: Control = scene_res.instantiate()
	map_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(map_instance)

	# Sync current selection to the map
	if map_instance.has_method("set_selected_biome") and selected_biome != "":
		map_instance.set_selected_biome(selected_biome)

	# Wire biome selection: MapMonde -> HubAntre biome + adventure flow
	if map_instance.has_signal("node_selected"):
		map_instance.node_selected.connect(func(biome_key: String):
			_on_biome_selected(biome_key)
			_update_adventure_button()
		)

	# Override map back button to close overlay instead of changing scene
	if map_instance.has_signal("close_requested"):
		map_instance.close_requested.connect(func(): overlay.queue_free())
	var close_btn := _make_overlay_close_button(overlay)
	overlay.add_child(close_btn)
	SFXManager.play("whoosh")


func _open_arbre_overlay() -> void:
	SFXManager.play("click")
	if get_node_or_null("ArbreOverlay"):
		return  # Already open
	var scene_res := load("res://scenes/ArbreDeVie.tscn")
	if scene_res == null:
		push_warning("[HubAntre] ArbreDeVie scene not found")
		return
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.name = "ArbreOverlay"
	overlay.z_index = 100
	add_child(overlay)

	var arbre_instance: Control = scene_res.instantiate()
	arbre_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(arbre_instance)

	# Override ArbreDeVie back_button to close overlay
	if arbre_instance.get("back_button") and arbre_instance.back_button is Button:
		for conn in arbre_instance.back_button.pressed.get_connections():
			arbre_instance.back_button.pressed.disconnect(conn.callable)
		arbre_instance.back_button.pressed.connect(func():
			SFXManager.play("click")
			overlay.queue_free()
		)
	var close_btn := _make_overlay_close_button(overlay)
	overlay.add_child(close_btn)
	SFXManager.play("whoosh")


func _make_overlay_close_button(overlay: ColorRect) -> Button:
	var close_btn := Button.new()
	close_btn.text = "\u2715"
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.position = Vector2(12, 12)
	close_btn.z_index = 10
	close_btn.pressed.connect(func():
		SFXManager.play("click")
		overlay.queue_free()
	)
	return close_btn


func _on_menu_pressed() -> void:
	SFXManager.play("click")
	SFXManager.play("whoosh")
	get_tree().change_scene_to_file(SCENE_MENU)


func _on_start_adventure() -> void:
	if not expedition_ready:
		return
	SFXManager.play("click")
	SFXManager.play("whoosh")

	# Set biome + expedition data for TransitionBiome
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
		run_data["tool"] = selected_tool
		run_data["departure_condition"] = selected_departure_condition
		if not _current_mission.is_empty():
			run_data["mission_template"] = _current_mission.duplicate()
		gm.set("run", run_data)

	# Update store mission
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

	# Auto-save before adventure
	_quick_save()

	get_tree().change_scene_to_file(SCENE_TRANSITION)


# ═══════════════════════════════════════════════════════════════════════════════
# SAVE SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

func _quick_save() -> void:
	if store == null:
		return
	var save_data := store.state.duplicate(true)
	save_data["timestamp"] = int(Time.get_unix_time_from_system())
	save_data["phase"] = "hub"
	save_data["selected_biome"] = selected_biome

	var success := store.save_system.save_slot(1, save_data)
	if success and save_btn and is_instance_valid(save_btn):
		var original_text: String = save_btn.text
		save_btn.text = "Sauvegarde !"
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(save_btn):
			save_btn.text = original_text


# ═══════════════════════════════════════════════════════════════════════════════
# VISUAL UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

func _make_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.paper_warm
	style.border_color = PALETTE.ink_faded
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.shadow_color = PALETTE.shadow
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	return panel


func _make_section_title(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "\u2500\u2500 %s \u2500\u2500" % text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font:
		lbl.add_theme_font_override("font", title_font)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", PALETTE.accent)
	return lbl


func _make_celtic_ornament() -> Label:
	var lbl := Label.new()
	var pattern := ["\u2500", "\u2022", "\u2500", "\u2500", "\u25C6", "\u2500", "\u2500", "\u2022", "\u2500"]
	var line := ""
	for i in range(40):
		line += pattern[i % pattern.size()]
	lbl.text = line
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", PALETTE.ink_faded)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a = 0.0
	return lbl


func _make_celtic_icon(icon_type: String, sz: float = 24.0) -> Control:
	## Draw-based Celtic icon — standardized line thickness and spacing.
	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(sz, sz)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lw: float = ICON_STANDARDS.line_thickness  # 1.5 — main strokes
	var dw: float = ICON_STANDARDS.detail_thickness  # 1.0 — details
	var ad: float = ICON_STANDARDS.accent_dot  # 2.0 — decorative dots
	ctrl.draw.connect(func():
		var c := sz * 0.5
		var r := sz * ICON_STANDARDS.radius_ratio
		var col: Color = PALETTE.ink
		match icon_type:
			"merlin":
				# Wizard hat silhouette
				ctrl.draw_line(Vector2(c, c - r), Vector2(c - r, c + r), col, lw, true)
				ctrl.draw_line(Vector2(c, c - r), Vector2(c + r, c + r), col, lw, true)
				ctrl.draw_line(Vector2(c - r, c + r), Vector2(c + r, c + r), col, lw, true)
				ctrl.draw_circle(Vector2(c, c - r * 0.6), ad, PALETTE.accent)
			"carte":
				# Compass rose / diamond with cross
				ctrl.draw_line(Vector2(c, c - r), Vector2(c + r, c), col, lw, true)
				ctrl.draw_line(Vector2(c + r, c), Vector2(c, c + r), col, lw, true)
				ctrl.draw_line(Vector2(c, c + r), Vector2(c - r, c), col, lw, true)
				ctrl.draw_line(Vector2(c - r, c), Vector2(c, c - r), col, lw, true)
				ctrl.draw_line(Vector2(c, c - r * 0.4), Vector2(c, c + r * 0.4), col, dw, true)
				ctrl.draw_line(Vector2(c - r * 0.4, c), Vector2(c + r * 0.4, c), col, dw, true)
			"bestiole":
				# Triskelion (3-arm spiral)
				for a in range(3):
					var angle: float = float(a) * TAU / 3.0 - PI / 2.0
					var pts := PackedVector2Array()
					for t in range(8):
						var tt: float = float(t) / 7.0
						var ar: float = r * tt * 0.8
						var aa: float = angle + tt * PI * 0.6
						pts.append(Vector2(c + cos(aa) * ar, c + sin(aa) * ar))
					if pts.size() >= 2:
						ctrl.draw_polyline(pts, col, lw, true)
			"arbre":
				# Stylized tree (trunk + branches)
				ctrl.draw_line(Vector2(c, c + r), Vector2(c, c - r * 0.2), col, lw, true)
				ctrl.draw_line(Vector2(c, c - r * 0.2), Vector2(c - r * 0.7, c - r), col, lw, true)
				ctrl.draw_line(Vector2(c, c - r * 0.2), Vector2(c + r * 0.7, c - r), col, lw, true)
				ctrl.draw_line(Vector2(c, c * 0.6), Vector2(c - r * 0.4, c - r * 0.5), col, dw, true)
				ctrl.draw_line(Vector2(c, c * 0.6), Vector2(c + r * 0.4, c - r * 0.5), col, dw, true)
			"calendar":
				# Celtic lunar wheel — circle + cross
				ctrl.draw_arc(Vector2(c, c), r, 0, TAU, 16, col, lw, true)
				ctrl.draw_line(Vector2(c, c - r), Vector2(c, c + r), col, dw, true)
				ctrl.draw_line(Vector2(c - r, c), Vector2(c + r, c), col, dw, true)
				# 4 phase dots at cardinal points
				for a in range(4):
					var angle: float = float(a) * TAU / 4.0 - PI / 2.0
					ctrl.draw_circle(Vector2(c + cos(angle) * r, c + sin(angle) * r), ad * 0.6, col)
			"collection":
				# Open grimoire (book shape)
				ctrl.draw_rect(Rect2(c - r * 0.7, c - r * 0.6, r * 1.4, r * 1.2), col, false, lw)
				ctrl.draw_line(Vector2(c, c - r * 0.6), Vector2(c, c + r * 0.6), PALETTE.accent, dw, true)
				# 3 text lines
				for i in range(3):
					var y: float = c - r * 0.25 + float(i) * r * 0.35
					ctrl.draw_line(Vector2(c - r * 0.45, y), Vector2(c + r * 0.45, y), Color(col, 0.3), dw * 0.5, true)
			"save":
				# Ogham stone — vertical line + 3 horizontal marks
				ctrl.draw_line(Vector2(c, c - r), Vector2(c, c + r), col, lw, true)
				for i in range(3):
					var y: float = c - r * 0.5 + float(i) * r * 0.5
					ctrl.draw_line(Vector2(c - r * 0.35, y), Vector2(c + r * 0.35, y), col, lw, true)
			"options":
				# Triple spiral (3 arcs, each 120 degrees apart)
				for a in range(3):
					var angle: float = float(a) * TAU / 3.0
					ctrl.draw_arc(Vector2(c + cos(angle) * r * 0.3, c + sin(angle) * r * 0.3),
						r * 0.3, angle, angle + PI, 8, col, lw, true)
			"menu":
				# Three horizontal lines (standardized spacing)
				for i in range(3):
					var y: float = c - r * 0.55 + float(i) * r * 0.55
					ctrl.draw_line(Vector2(c - r, y), Vector2(c + r, y), col, lw, true)
			_:
				# Fallback: simple dot
				ctrl.draw_circle(Vector2(c, c), ad, col)
	)
	return ctrl


func _style_biome_button(btn: Button, biome: Dictionary, is_selected: bool) -> void:
	var biome_color: Color = biome.get("color", PALETTE.ink_soft)

	var style := StyleBoxFlat.new()
	if is_selected:
		style.bg_color = biome_color
		style.border_color = PALETTE.ink
		style.set_border_width_all(2)
		btn.add_theme_color_override("font_color", PALETTE.paper)
		btn.add_theme_color_override("font_hover_color", PALETTE.paper)
	else:
		style.bg_color = PALETTE.paper_dark
		style.border_color = biome_color
		style.set_border_width_all(1)
		btn.add_theme_color_override("font_color", PALETTE.ink)
		btn.add_theme_color_override("font_hover_color", biome_color)

	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	if is_selected:
		hover.bg_color = biome_color.lightened(0.15)
	else:
		hover.bg_color = Color(biome_color.r, biome_color.g, biome_color.b, 0.3)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = biome_color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed)


func _style_care_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.paper_dark
	style.border_color = PALETTE.bestiole
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = Color(PALETTE.bestiole.r, PALETTE.bestiole.g, PALETTE.bestiole.b, 0.2)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = PALETTE.bestiole
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := style.duplicate()
	disabled.bg_color = PALETTE.paper_dark
	disabled.border_color = PALETTE.ink_faded
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", PALETTE.ink)
	btn.add_theme_color_override("font_hover_color", PALETTE.bestiole)
	btn.add_theme_color_override("font_disabled_color", PALETTE.ink_faded)


func _style_nav_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.paper_dark
	style.border_color = PALETTE.accent_soft
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = PALETTE.accent_glow
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = PALETTE.accent
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", PALETTE.ink)
	btn.add_theme_color_override("font_hover_color", PALETTE.accent)


func _style_icon_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.paper_warm
	style.border_color = PALETTE.ink_faded
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = PALETTE.paper_dark
	hover.border_color = PALETTE.accent
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = PALETTE.accent
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", PALETTE.ink)
	btn.add_theme_color_override("font_hover_color", PALETTE.accent)
	btn.add_theme_color_override("font_pressed_color", PALETTE.paper)
	btn.pivot_offset = Vector2(26, 26)


func _on_icon_hover(btn: Button, hovering: bool) -> void:
	SFXManager.play("hover")
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hovering:
		tw.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.1)
	else:
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)


func _get_bond_tier_name(bond: int) -> String:
	if bond >= 91:
		return "Ame Soeur"
	elif bond >= 71:
		return "Lie"
	elif bond >= 51:
		return "Compagnon"
	elif bond >= 31:
		return "Curieux"
	return "Etranger"


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _start_mist_animation() -> void:
	if _mist_tween:
		_mist_tween.kill()
	_mist_tween = create_tween().set_loops()
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.25, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.05, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_entry_animation() -> void:
	SFXManager.play("scene_transition")
	var tween := create_tween()
	tween.tween_property(celtic_top, "modulate:a", 0.6, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(celtic_bottom, "modulate:a", 0.6, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(tab_container, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bottom_bar, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.3)
