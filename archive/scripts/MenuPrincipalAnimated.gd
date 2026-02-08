extends Control

# Script-driven menu principal (retro GBA) avec animations et rendu dynamique.

const PALETTE := {
	"bg_deep": Color(0.02, 0.04, 0.08),
	"bg_mid": Color(0.08, 0.12, 0.18),
	"bg_light": Color(0.12, 0.18, 0.28),
	"gold": Color(0.85, 0.70, 0.30),
	"gold_bright": Color(0.98, 0.88, 0.45),
	"gold_dark": Color(0.55, 0.42, 0.15),
	"green": Color(0.25, 0.65, 0.40),
	"green_dark": Color(0.12, 0.35, 0.20),
	"blue": Color(0.30, 0.50, 0.75),
	"cream": Color(0.97, 0.94, 0.88),
	"ink": Color(0.08, 0.09, 0.12),
	"wood": Color(0.43, 0.30, 0.20),
	"wood_dark": Color(0.28, 0.20, 0.12),
}

const PIXEL_SIZE := 4
const DAY_ARC_TITLE_MARGIN := 60.0  # Marge au-dessus du titre pour l'arc
const ORB_MENU_SIZE := 18.0
const ORB_INTRO_TRANSITION_DURATION := 1.35
const MENU_ITEMS := [
	{"name": "BtnNouvelle", "text": "Nouvelle Partie", "scene": "res://scenes/IntroMerlinDialogue.tscn"},
	{"name": "BtnContinuer", "text": "Continuer", "scene": "res://scenes/SelectionSauvegarde.tscn"},
	{"name": "BtnOptions", "text": "Options", "scene": ""},
	{"name": "BtnTest", "text": "Test Merlin", "scene": "res://scenes/MerlinTest.tscn"},
	{"name": "BtnTestJDR", "text": "Test JDR Merlin", "scene": "res://scenes/TestJDRMerlin.tscn"},
	{"name": "BtnTestCombat", "text": "Test Combat", "scene": "res://scenes/TestCombat.tscn"},
	{"name": "BtnTestAventure", "text": "Test Aventure", "scene": "res://scenes/TestAventure.tscn"},
	{"name": "BtnTestAntre", "text": "Test Antre Merlin", "scene": "res://scenes/TestAntreMerlin.tscn"},
	{"name": "BtnTestMerlinVoice", "text": "Test LLM + Voix", "scene": "res://scenes/TestMerlinVoice.tscn"},
	{"name": "BtnQuitter", "text": "Quitter", "scene": "__quit__"},
]
const TOP_ICON_SIZE := Vector2(44, 44)
const TOP_ICON_MARGIN := Vector2(24, 18)
const TOP_ICON_GAP := 10.0

const BRETON_DAYS := ["Sul", "Lun", "Meurzh", "Merc'her", "Yaou", "Gwener", "Sadorn"]
const BRETON_MONTHS := ["Genver", "C'hwevrer", "Meurzh", "Ebrel", "Mae", "Mezheven", "Gouere", "Eost", "Gwengolo", "Here", "Du", "Kerzu"]

const TREE_ART := [
	".............LLLLLL.............",
	"............LLLLLLLL............",
	"...........LLLLLLLLLL...........",
	"..........LLLLLLLLLLLL..........",
	".........LLLLLLLLLLLLLL.........",
	"........LLLLLLLLLLLLLLLL........",
	".......LLLLLLLLLLLLLLLLLL.......",
	"......LLLLLLLLLLLLLLLLLLLL......",
	"......LLLLLLTTTTTTLLLLLLL.......",
	".......LLLLTTTTTTTTLLLLL........",
	"........LLLTTTTTTTTLLL..........",
	".........LLTTTTTTTTLL...........",
	"..........LTTTTTTTTL............",
	"..........TTTTTTTTTT............",
	"..........TTTTTTTTTT............",
	".........TTTTTTTTTTTT...........",
	"........TTTTTTTTTTTTTT..........",
	".......TTTTTTTTTTTTTTTT.........",
	"......TTTTTTTTTTTTTTTTTT........",
	".....TTTTTTTTTTTTTTTTTTTT.......",
	"......TTTTTT....TTTTTT..........",
	".....TTTTT......TTTTTT..........",
	"....TTTTT........TTTTTT.........",
	"...TTTTT..........TTTTTT........",
	"...TTTTT..........TTTTTT........",
	"...TTTTT..........TTTTTT........",
]

const CABIN_ART := [
	"...........RRRRRRR...........",
	"..........RRRRRRRRR..........",
	".........RRRRRRRRRRR.........",
	"........RRRRRRRRRRRRR........",
	".......RRRRRRRRRRRRRRR.......",
	"......RRRRRRRRRRRRRRRRR......",
	".....RRRRRRRRRRCRRRRRRRR.....",
	"....RRRRRRRRRRCCCRRRRRRRR....",
	"...RRRRRRRRRRRCCCCRRRRRRRR...",
	"...RRRRRRRRRRRCCCCRRRRRRRR...",
	"....WWWWWWWWWWWWWWWWWWWWW....",
	"....WWWWWWWWWWWWWWWWWWWWW....",
	"...WWWOOOWWWWWWWOOOWWWWWW...",
	"...WWWOOOWWWWWWWOOOWWWWWW...",
	"...WWWWWWWDDDDWWWWWWWWWWW...",
	"...WWWWWWWDDDDWWWWWWWWWWW...",
	"...WWWWWWWDDDDWWWWWWWWWWW...",
	"...WWWWWWWWWWWWWWWWWWWWWW...",
	"....WWWWWWWWWWWWWWWWWWWW....",
	".....WWWWWWWWWWWWWWWWWW.....",
	"......WWWWWWWWWWWWWWWW......",
]

# Spell Book pixel art - Open grimoire with mystical pages
const BOOK_COVER_LEFT := [
	"BBBBBBBBBBBBBBBB",
	"BLLLLLLLLLLLLLLB",
	"BLCCCCCCCCCCCLB",
	"BLCCCCCCCCCCCLB",
	"BLCCCCCCCCCCCLB",
	"BLCCCCCCCCCCCLB",
	"BLCCCCCCCCCCCLB",
	"BLCCCCCCCCCCCLB",
	"BLCCCCCCCCCCCLB",
	"BLCCCCCCCCCCCLB",
	"BLLLLLLLLLLLLLLB",
	"BBBBBBBBBBBBBBBB",
	"BSSSSSSSSSSSSSSSB",
]

const BOOK_COVER_RIGHT := [
	"BBBBBBBBBBBBBBBB",
	"BLLLLLLLLLLLLLLB",
	"BLPPPPPPPPPPPLB",
	"BLPPPPPPPPPPPLB",
	"BLPPPPPPPPPPPLB",
	"BLPPPPPPPPPPPLB",
	"BLPPPPPPPPPPPLB",
	"BLPPPPPPPPPPPLB",
	"BLPPPPPPPPPPPLB",
	"BLPPPPPPPPPPPLB",
	"BLLLLLLLLLLLLLLB",
	"BBBBBBBBBBBBBBBB",
	"BSSSSSSSSSSSSSSSB",
]

# Rune symbols for page decoration - Ogham inspired
const RUNE_PATTERNS := [
	["..X..", ".X.X.", "X.X.X", ".X.X.", "..X.."],  # Beith (Birch)
	["X.X.X", ".XXX.", "..X..", ".XXX.", "X.X.X"],  # Luis (Rowan)
	[".XXX.", "X...X", "XXXXX", "X...X", ".XXX."],  # Nion (Ash)
	["..X..", ".XXX.", "XXXXX", ".XXX.", "..X.."],  # Fearn (Alder)
	["X...X", "XX.XX", "X.X.X", "XX.XX", "X...X"],  # Saille (Willow)
	["XXXXX", "..X..", "XXXXX", "..X..", "XXXXX"],  # Huath (Hawthorn)
	[".X.X.", "XXXXX", ".X.X.", "XXXXX", ".X.X."],  # Duir (Oak)
	["X..X.", ".XX..", "..XX.", ".XX..", "X..X."],  # Tinne (Holly)
]

# Celtic knot corner decoration - more elaborate
const CELTIC_CORNER := [
	"..XXXXXX..",
	".X......X.",
	"X..XXXX..X",
	"X.X....X.X",
	"X.X.XX.X.X",
	"X.X.XX.X.X",
	"X.X....X.X",
	"X..XXXX..X",
	".X......X.",
	"..XXXXXX..",
]

# Celtic border pattern
const CELTIC_BORDER := [
	"X.X.X.X.X",
	".X...X...",
	"X.X.X.X.X",
]

# Triquetra symbol (Celtic trinity knot)
const TRIQUETRA := [
	"...XXX...",
	"..X...X..",
	".X.....X.",
	"X..XXX..X",
	"X.X...X.X",
	"X.X...X.X",
	".XX...XX.",
	"..XXXXX..",
	"...X.X...",
]

# Book variables
var book_page_turn_progress := 0.0
var book_page_turn_direction := 1
var book_page_turn_speed := 0.004
var book_current_page := 0
var book_hover_offset := 0.0
var book_dust_particles: Array[Dictionary] = []
var book_magic_symbols: Array[Dictionary] = []
var book_ink_reveal_progress := 0.0
var book_last_page_change := 0.0

var background: ColorRect
var title_label: Label
var subtitle_label: Label
var vbox: VBoxContainer
var buttons: Array[Button] = []
var llm_status_label: Label
var llm_reload_button: Button
var llm_manager: Node = null
var llm_boot_backdrop: ColorRect
var llm_boot_overlay: PanelContainer
var llm_boot_vbox: VBoxContainer
var llm_boot_title: Label
var llm_boot_status: Label
var llm_boot_detail: Label
var llm_boot_progress: ProgressBar
var llm_boot_copy: Button
var llm_boot_logs: TextEdit
var llm_ready_cached := false
var collection_button: Button
var save_book_button: Button
var menu_icon_button: Button
var menu_icon_texture: Texture2D
var book_icon_texture: Texture2D
var overlay_backdrop: ColorRect
var collection_overlay: PanelContainer
var calendar_overlay: PanelContainer
var overlay_back_button: Button
var overlay_active := ""
var clock_rect := Rect2()

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# CALENDRIER ANIMÃ‰ - Variables
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
const CALENDAR_JSON_PATH := "res://docs/40_world_rules/calendar_2026.json"

var calendar_open := false
var calendar_anim_progress := 0.0
var calendar_current_month := 0
var calendar_current_year := 0
var calendar_day_rects: Array[Rect2] = []
var calendar_prev_btn_rect := Rect2()
var calendar_next_btn_rect := Rect2()
var calendar_hovered_day := -1
var calendar_page_flip_progress := 0.0
var calendar_page_flip_direction := 0  # -1 = prev, 1 = next
var calendar_shake_offset := Vector2.ZERO
var calendar_dust_particles: Array[Dictionary] = []
var calendar_ink_drips: Array[Dictionary] = []
var calendar_events_by_date: Dictionary = {}  # Format: "2026-01-05" -> event dict
var calendar_json_loaded := false

const SEASON_COLORS := {
	"winter": Color(0.5, 0.7, 0.95),
	"spring": Color(0.5, 0.9, 0.5),
	"summer": Color(1.0, 0.85, 0.4),
	"autumn": Color(0.9, 0.5, 0.3)
}

# Ã‰vÃ©nements du calendrier (jour du mois -> description)
const CALENDAR_EVENTS := {
	1: {"name": "Samhain", "icon": "ðŸŒ™", "color_key": "gold"},
	8: {"name": "Lune Noire", "icon": "ðŸŒ‘", "color_key": "blue"},
	15: {"name": "Pleine Lune", "icon": "ðŸŒ•", "color_key": "cream"},
	21: {"name": "Solstice", "icon": "â˜€", "color_key": "gold_bright"},
	25: {"name": "FÃªte des Druides", "icon": "ðŸŒ¿", "color_key": "green"},
}

const CALENDAR_MONTH_NAMES := ["Janvier", "FÃ©vrier", "Mars", "Avril", "Mai", "Juin",
	"Juillet", "AoÃ»t", "Septembre", "Octobre", "Novembre", "DÃ©cembre"]

const CALENDAR_DAY_NAMES := ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]

var time_elapsed := 0.0
var mouse_pos := Vector2.ZERO
var menu_intro_time := 0.0
var menu_intro_done := false
var menu_intro_pending := false

const BOOT_PHASE_LINES := 0
const BOOT_PHASE_FADE := 1
const BOOT_PHASE_POWER_OFF := 2
const BOOT_PHASE_MENU := 3
const BOOT_PHASE_DONE := 4

const BOOT_FONT_SIZE := 14
const BOOT_LINE_DELAY := 0.12
const BOOT_HOLD_TIME := 0.6
const BOOT_FADE_TIME := 0.6
const BOOT_POWER_TIME := 0.4
const BOOT_MENU_FADE_TIME := 0.6

const BOOT_LINES := [
	"MERLIN/OS v0.9.3",
	"Kernel ................. OK",
	"Bus mana ............... OK",
	"Modules lore ........... OK",
	"Memoires ............... OK",
	"Arc runtime ............ OK",
	"Chrono sync ............ OK",
	"Compilers .............. OK",
	"Glyph cache ............ OK",
	"Audio glyphs ........... OK",
	"Shaders ................ OK",
	"Boot sequence complete."
]

var boot_phase := BOOT_PHASE_LINES
var boot_line_timer := 0.0
var boot_hold_timer := 0.0
var boot_visible_lines := 0
var boot_fade := 0.0
var boot_power := 0.0
var boot_menu_fade := 1.0

# Time of day (sun + sky tint)
var sun_pos := Vector2.ZERO
var sun_color := Color(1, 0.9, 0.7)
var sun_alpha := 0.0
var sky_tint := Color(0.1, 0.12, 0.18)
var day_time := 0.0
var sky_top_color := Color(0.05, 0.08, 0.16)
var sky_horizon_color := Color(0.12, 0.18, 0.28)
var sky_mid_color := Color(0.08, 0.12, 0.2)
var night_factor := 0.0
var orb_light_pos := Vector2.ZERO
var orb_light_strength := 0.0
var day_arc_center := Vector2.ZERO
var day_arc_radius := 0.0
var orb_render_pos := Vector2.ZERO
var orb_render_size := ORB_MENU_SIZE
var orb_render_color := Color(0.3, 0.55, 1.0)
var orb_render_intensity := 0.0
var orb_intro_active := false
var orb_intro_progress := 0.0
var orb_intro_start_pos := Vector2.ZERO
var orb_intro_start_size := ORB_MENU_SIZE
var force_grass_plain := false  # Enable seasonal terrain with coastal elements
var minimal_background_mode := false  # Full background with terrain and arc
var _last_time_bucket := -1
var season := "winter"
var season_tint := Color(0.8, 0.9, 1.0)
var weather_state := "snow"
var weather_particles: Array[Dictionary] = []
var weather_rng := RandomNumberGenerator.new()
var _last_weather_bucket := -1

var landscape_rng := RandomNumberGenerator.new()
var mountain_layers: Array = []
var forest_layers: Array = []
var star_field: Array = []
var ground_speckles: Array[Dictionary] = []
var parallax_layers: Array[Dictionary] = []

var tree_draw_pos := Vector2.ZERO
var cabin_draw_pos := Vector2.ZERO
var tree_anchor := Vector2.ZERO
var cabin_anchor := Vector2.ZERO
var tree_magic_particles: Array[Dictionary] = []
var smoke_particles: Array[Dictionary] = []
var firefly_particles: Array[Dictionary] = []
var tree_texture: Texture2D
var cabin_texture: Texture2D
var tree_render_size := Vector2.ZERO
var cabin_render_size := Vector2.ZERO
var cabin_chimney_pos := Vector2.ZERO
var tree_intro_alpha := 0.0
var cabin_intro_alpha := 0.0
var _cutout_threshold := 0.9
var _cutout_saturation := 0.08
var _cutout_bg_distance := 0.22

var particles: Array[Dictionary] = []
var cursor_trail: Array[Dictionary] = []
var cursor_magic_particles: Array[Dictionary] = []
var hovered_button: Button = null

var celtic_font: Font
var celtic_font_thin: Font

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	_ensure_core_nodes()
	_load_fonts()
	_setup_ui()
	_init_particles()
	weather_rng.randomize()
	_init_weather_particles()
	_init_cursor_particles()
	_init_magic_particles()
	_init_smoke_particles()
	_init_fireflies()
	_build_landscape(get_viewport_rect().size)
	resized.connect(_on_menu_resized)
	get_viewport().size_changed.connect(_on_menu_resized)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	call_deferred("_layout_centered")
	call_deferred("_start_menu_intro")
	boot_phase = BOOT_PHASE_DONE
	boot_menu_fade = 0.0
	_init_intro_orb_transition()
	_update_orb_render_state(0.0)
	_bind_llm_manager()
	_load_calendar_json()

func _init_os_boot() -> void:
	boot_phase = BOOT_PHASE_LINES
	boot_line_timer = 0.0
	boot_hold_timer = 0.0
	boot_visible_lines = 0
	boot_fade = 0.0
	boot_power = 0.0
	boot_menu_fade = 1.0
	menu_intro_pending = true
	if title_label:
		title_label.visible = false
		title_label.modulate.a = 0.0
	if subtitle_label:
		subtitle_label.visible = false
		subtitle_label.modulate.a = 0.0
	if vbox:
		vbox.visible = false
	for btn in buttons:
		btn.modulate.a = 0.0
		btn.disabled = true
	if llm_boot_backdrop:
		llm_boot_backdrop.visible = false
	if llm_boot_overlay:
		llm_boot_overlay.visible = false

func _init_intro_orb_transition() -> void:
	if not Engine.has_meta("intro_orb_data"):
		return
	var data = Engine.get_meta("intro_orb_data")
	if data is Dictionary:
		var start_pos = data.get("orb_position", Vector2.ZERO)
		var start_size = float(data.get("orb_size", ORB_MENU_SIZE))
		if start_pos != Vector2.ZERO:
			orb_intro_active = true
			orb_intro_progress = 0.0
			orb_intro_start_pos = start_pos
			orb_intro_start_size = maxf(6.0, start_size)
	# Clean meta to avoid replaying transition
	if Engine.has_method("remove_meta"):
		Engine.remove_meta("intro_orb_data")
	else:
		Engine.set_meta("intro_orb_data", null)

func _ensure_core_nodes() -> void:
	background = get_node_or_null("Background") as ColorRect
	if background == null:
		background = ColorRect.new()
		background.name = "Background"
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(background)
		move_child(background, 0)

	title_label = get_node_or_null("TitleLabel") as Label
	if title_label == null:
		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(title_label)

	subtitle_label = get_node_or_null("SubtitleLabel") as Label
	if subtitle_label == null:
		subtitle_label = Label.new()
		subtitle_label.name = "SubtitleLabel"
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(subtitle_label)

	vbox = get_node_or_null("VBoxContainer") as VBoxContainer
	if vbox == null:
		vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(vbox)

	llm_status_label = get_node_or_null("LLMStatusLabel") as Label
	if llm_status_label == null:
		llm_status_label = Label.new()
		llm_status_label.name = "LLMStatusLabel"
		llm_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		llm_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(llm_status_label)
	llm_status_label.visible = false  # Hidden - LLM status disabled

	llm_reload_button = get_node_or_null("LLMReloadButton") as Button
	if llm_reload_button == null:
		llm_reload_button = Button.new()
		llm_reload_button.name = "LLMReloadButton"
		llm_reload_button.text = "Recharger LLM"
		add_child(llm_reload_button)
	llm_reload_button.visible = false  # Hidden - LLM reload disabled

	llm_boot_backdrop = get_node_or_null("LLMBootBackdrop") as ColorRect
	if llm_boot_backdrop == null:
		llm_boot_backdrop = ColorRect.new()
		llm_boot_backdrop.name = "LLMBootBackdrop"
		llm_boot_backdrop.color = Color(0, 0, 0, 0.65)
		llm_boot_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(llm_boot_backdrop)
		move_child(llm_boot_backdrop, get_child_count() - 1)

	llm_boot_overlay = get_node_or_null("LLMBootOverlay") as PanelContainer
	if llm_boot_overlay == null:
		llm_boot_overlay = PanelContainer.new()
		llm_boot_overlay.name = "LLMBootOverlay"
		llm_boot_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		llm_boot_overlay.top_level = true
		llm_boot_overlay.z_as_relative = false
		llm_boot_overlay.z_index = 200
		add_child(llm_boot_overlay)

	llm_boot_vbox = llm_boot_overlay.get_node_or_null("LLMBootVBox") as VBoxContainer
	if llm_boot_vbox == null:
		llm_boot_vbox = VBoxContainer.new()
		llm_boot_vbox.name = "LLMBootVBox"
		llm_boot_vbox.add_theme_constant_override("separation", 6)
		llm_boot_overlay.add_child(llm_boot_vbox)

	llm_boot_title = llm_boot_vbox.get_node_or_null("LLMBootTitle") as Label
	if llm_boot_title == null:
		llm_boot_title = Label.new()
		llm_boot_title.name = "LLMBootTitle"
		llm_boot_title.text = "Merlin LLM - Diagnostic"
		llm_boot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		llm_boot_vbox.add_child(llm_boot_title)

	llm_boot_status = llm_boot_vbox.get_node_or_null("LLMBootStatus") as Label
	if llm_boot_status == null:
		llm_boot_status = Label.new()
		llm_boot_status.name = "LLMBootStatus"
		llm_boot_status.text = "Connexion: ..."
		llm_boot_vbox.add_child(llm_boot_status)

	llm_boot_detail = llm_boot_vbox.get_node_or_null("LLMBootDetail") as Label
	if llm_boot_detail == null:
		llm_boot_detail = Label.new()
		llm_boot_detail.name = "LLMBootDetail"
		llm_boot_detail.text = "Initialisation..."
		llm_boot_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		llm_boot_vbox.add_child(llm_boot_detail)

	llm_boot_progress = llm_boot_vbox.get_node_or_null("LLMBootProgress") as ProgressBar
	if llm_boot_progress == null:
		llm_boot_progress = ProgressBar.new()
		llm_boot_progress.name = "LLMBootProgress"
		llm_boot_progress.max_value = 100.0
		llm_boot_progress.value = 0.0
		llm_boot_progress.custom_minimum_size = Vector2(0, 10)
		llm_boot_vbox.add_child(llm_boot_progress)

	llm_boot_copy = llm_boot_vbox.get_node_or_null("LLMBootCopy") as Button
	if llm_boot_copy == null:
		llm_boot_copy = Button.new()
		llm_boot_copy.name = "LLMBootCopy"
		llm_boot_copy.text = "Copier backlog"
		llm_boot_vbox.add_child(llm_boot_copy)

	llm_boot_logs = llm_boot_vbox.get_node_or_null("LLMBootLogs") as TextEdit
	if llm_boot_logs == null:
		llm_boot_logs = TextEdit.new()
		llm_boot_logs.name = "LLMBootLogs"
		llm_boot_logs.editable = false
		llm_boot_logs.custom_minimum_size = Vector2(0, 260)
		llm_boot_vbox.add_child(llm_boot_logs)

	collection_button = get_node_or_null("CollectionButton") as Button
	if collection_button == null:
		collection_button = Button.new()
		collection_button.name = "CollectionButton"
		collection_button.text = "Collection"
		add_child(collection_button)
		collection_button.pressed.connect(_open_collection_overlay)

	save_book_button = get_node_or_null("SaveBookButton") as Button
	if save_book_button == null:
		save_book_button = Button.new()
		save_book_button.name = "SaveBookButton"
		save_book_button.text = ""
		save_book_button.focus_mode = Control.FOCUS_NONE
		save_book_button.z_index = 110
		save_book_button.z_as_relative = false
		add_child(save_book_button)
		save_book_button.pressed.connect(_on_save_book_pressed)

	menu_icon_button = get_node_or_null("MenuIconButton") as Button
	if menu_icon_button == null:
		menu_icon_button = Button.new()
		menu_icon_button.name = "MenuIconButton"
		menu_icon_button.text = ""
		menu_icon_button.focus_mode = Control.FOCUS_NONE
		menu_icon_button.z_index = 110
		menu_icon_button.z_as_relative = false
		add_child(menu_icon_button)
		menu_icon_button.pressed.connect(_on_menu_icon_pressed)

	overlay_backdrop = get_node_or_null("OverlayBackdrop") as ColorRect
	if overlay_backdrop == null:
		overlay_backdrop = ColorRect.new()
		overlay_backdrop.name = "OverlayBackdrop"
		overlay_backdrop.color = Color(0, 0, 0, 0.6)
		overlay_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		overlay_backdrop.z_index = 120
		overlay_backdrop.z_as_relative = false
		add_child(overlay_backdrop)

	collection_overlay = _ensure_overlay_panel("CollectionOverlay", "Collection")
	calendar_overlay = _ensure_overlay_panel("CalendarOverlay", "Calendrier des evenements")

	overlay_back_button = get_node_or_null("OverlayBackButton") as Button
	if overlay_back_button == null:
		overlay_back_button = Button.new()
		overlay_back_button.name = "OverlayBackButton"
		overlay_back_button.text = "â† Retour menu"
		overlay_back_button.z_index = 140
		overlay_back_button.z_as_relative = false
		add_child(overlay_back_button)
		overlay_back_button.pressed.connect(_close_overlay)

	# Rebuild menu buttons from MENU_ITEMS to keep order in sync
	var to_remove: Array[Node] = []
	for child in vbox.get_children():
		if child is Button:
			to_remove.append(child)
	for child in to_remove:
		vbox.remove_child(child)
		child.queue_free()
	for item in MENU_ITEMS:
		var btn := Button.new()
		btn.name = item.name
		btn.text = item.text
		btn.custom_minimum_size = Vector2(360, 38)
		vbox.add_child(btn)

func _load_fonts() -> void:
	var font_path = "res://resources/fonts/morris/MorrisRomanBlack.ttf"
	var font_thin_path = "res://resources/fonts/morris/MorrisRomanBlackAlt.ttf"
	if ResourceLoader.exists(font_path):
		celtic_font = load(font_path)
	else:
		celtic_font = ThemeDB.fallback_font
	if ResourceLoader.exists(font_thin_path):
		celtic_font_thin = load(font_thin_path)
	else:
		celtic_font_thin = celtic_font

func _load_scene_assets() -> void:
	var tree_path = "res://Assets/Sprite/Mystical_Tree.png"
	var cabin_path = "res://Assets/Sprite/Merlins_House.png"
	if ResourceLoader.exists(tree_path):
		tree_texture = _load_cutout_texture(tree_path)
	if ResourceLoader.exists(cabin_path):
		cabin_texture = _load_cutout_texture(cabin_path)

func _load_cutout_texture(path: String) -> Texture2D:
	var tex: Texture2D = load(path)
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return tex
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w = img.get_width()
	var h = img.get_height()
	if w == 0 or h == 0:
		return tex
	var bg = _sample_background_color(img)
	var visited := PackedByteArray()
	visited.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in range(w):
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in range(h):
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p = stack.pop_back()
		var idx = p.y * w + p.x
		if visited[idx] == 1:
			continue
		visited[idx] = 1
		var c = img.get_pixel(p.x, p.y)
		if not _is_background_pixel(c, bg):
			continue
		if c.a > 0.0:
			c.a = 0.0
			img.set_pixel(p.x, p.y, c)
		if p.x > 0:
			stack.append(Vector2i(p.x - 1, p.y))
		if p.x < w - 1:
			stack.append(Vector2i(p.x + 1, p.y))
		if p.y > 0:
			stack.append(Vector2i(p.x, p.y - 1))
		if p.y < h - 1:
			stack.append(Vector2i(p.x, p.y + 1))
	return ImageTexture.create_from_image(img)

func _sample_background_color(img: Image) -> Color:
	var w = img.get_width()
	var h = img.get_height()
	if w <= 0 or h <= 0:
		return Color(1, 1, 1, 1)
	var samples = [
		img.get_pixel(0, 0),
		img.get_pixel(w - 1, 0),
		img.get_pixel(0, h - 1),
		img.get_pixel(w - 1, h - 1),
	]
	var avg = Color(0, 0, 0, 1)
	for s in samples:
		avg.r += s.r
		avg.g += s.g
		avg.b += s.b
	var inv = 1.0 / float(samples.size())
	avg.r *= inv
	avg.g *= inv
	avg.b *= inv
	return avg

func _is_background_pixel(c: Color, bg: Color) -> bool:
	if c.a <= 0.0:
		return true
	var diff = abs(c.r - bg.r) + abs(c.g - bg.g) + abs(c.b - bg.b)
	if diff <= _cutout_bg_distance:
		return true
	var max_c = max(c.r, max(c.g, c.b))
	var min_c = min(c.r, min(c.g, c.b))
	var is_bright = max_c >= _cutout_threshold
	var low_sat = (max_c - min_c) <= _cutout_saturation
	return is_bright and low_sat

func _setup_ui() -> void:
	background.color = Color(0, 0, 0, 0)
	background.visible = false
	background.set_anchors_preset(Control.PRESET_FULL_RECT)

	title_label.text = "M.E.R.L.I.N"
	title_label.add_theme_font_override("font", celtic_font)
	title_label.add_theme_font_size_override("font_size", 96)
	title_label.add_theme_color_override("font_color", PALETTE.gold_bright)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title_label.add_theme_constant_override("shadow_offset_x", 4)
	title_label.add_theme_constant_override("shadow_offset_y", 4)

	subtitle_label.text = ""
	subtitle_label.visible = false
	subtitle_label.add_theme_font_override("font", celtic_font_thin)
	subtitle_label.add_theme_font_size_override("font_size", 22)
	subtitle_label.add_theme_color_override("font_color", PALETTE.green)

	vbox.add_theme_constant_override("separation", 10)
	buttons.clear()
	for child in vbox.get_children():
		if child is Button and child.name == "BtnTestAI":
			child.queue_free()
			continue
		if child is Button:
			buttons.append(child)
			_style_button(child)
			child.mouse_entered.connect(_on_button_hover.bind(child))
			child.mouse_exited.connect(_on_button_unhover.bind(child))
			child.pressed.connect(_on_button_pressed.bind(child))
			child.focus_mode = Control.FOCUS_ALL
			child.pivot_offset = child.size / 2.0

	_style_llm_controls()
	_update_llm_boot_state()
	_style_collection_button()
	_style_top_icon_buttons()
	_style_overlay_controls()

func _start_menu_intro() -> void:
	menu_intro_time = 0.0
	menu_intro_done = false
	menu_intro_pending = false
	if title_label:
		title_label.visible = true
	title_label.modulate.a = 0.0
	if vbox:
		vbox.visible = true
	for btn in buttons:
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.92, 0.92)
		btn.disabled = false

func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = PALETTE.ink
	normal.border_color = PALETTE.gold_dark
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)

	var hover := normal.duplicate()
	hover.bg_color = PALETTE.blue.darkened(0.2)
	hover.border_color = PALETTE.gold

	var pressed := normal.duplicate()
	pressed.bg_color = PALETTE.bg_mid
	pressed.border_color = PALETTE.gold_bright

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", PALETTE.cream)
	btn.add_theme_color_override("font_hover_color", PALETTE.gold_bright)
	btn.add_theme_color_override("font_pressed_color", PALETTE.gold_bright)
	btn.add_theme_font_override("font", celtic_font_thin if celtic_font_thin != null else celtic_font)
	btn.add_theme_font_size_override("font_size", 18)

func _style_collection_button() -> void:
	if collection_button == null:
		return
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.border_color = Color(0, 0, 0, 0)
	flat.set_border_width_all(0)
	collection_button.add_theme_stylebox_override("normal", flat)
	collection_button.add_theme_stylebox_override("hover", flat)
	collection_button.add_theme_stylebox_override("pressed", flat)
	collection_button.add_theme_stylebox_override("focus", flat)
	collection_button.add_theme_font_override("font", celtic_font_thin if celtic_font_thin != null else celtic_font)
	collection_button.add_theme_font_size_override("font_size", 18)
	collection_button.add_theme_color_override("font_color", PALETTE.gold_bright)
	collection_button.add_theme_color_override("font_hover_color", PALETTE.gold_bright)
	collection_button.add_theme_color_override("font_pressed_color", PALETTE.gold_bright)

func _style_top_icon_buttons() -> void:
	if menu_icon_texture == null:
		menu_icon_texture = _create_icon_texture("menu", 24, PALETTE.gold_bright)
	if book_icon_texture == null:
		book_icon_texture = _create_icon_texture("book", 24, PALETTE.gold_bright)
	if menu_icon_button:
		_style_icon_button(menu_icon_button, menu_icon_texture)
		menu_icon_button.tooltip_text = "Menu"
	if save_book_button:
		_style_icon_button(save_book_button, book_icon_texture)
		save_book_button.tooltip_text = "Chroniques"

func _style_icon_button(btn: Button, icon_tex: Texture2D) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = Color(0, 0, 0, 0)
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(8)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.08, 0.1, 0.16, 0.7)
	hover.border_color = PALETTE.gold
	hover.set_border_width_all(2)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.12, 0.14, 0.2, 0.85)
	pressed.border_color = PALETTE.gold_bright
	pressed.set_border_width_all(2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.text = ""
	btn.icon = icon_tex

func _create_icon_texture(kind: String, size: int, color: Color) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match kind:
		"menu":
			_fill_icon_rect(img, 4, 6, size - 8, 3, color)
			_fill_icon_rect(img, 4, 11, size - 8, 3, color)
			_fill_icon_rect(img, 4, 16, size - 8, 3, color)
		"book":
			var left := 5
			var right := size - 6
			var top := 5
			var bottom := size - 6
			for x in range(left, right + 1):
				img.set_pixel(x, top, color)
				img.set_pixel(x, bottom, color)
			for y in range(top, bottom + 1):
				img.set_pixel(left, y, color)
				img.set_pixel(right, y, color)
			var spine := int(size * 0.5)
			for y in range(top, bottom + 1):
				img.set_pixel(spine, y, color)
		_:
			_fill_icon_rect(img, 6, 6, size - 12, size - 12, color)
	return ImageTexture.create_from_image(img)

func _fill_icon_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for iy in range(y, y + h):
		for ix in range(x, x + w):
			if ix >= 0 and iy >= 0 and ix < img.get_width() and iy < img.get_height():
				img.set_pixel(ix, iy, color)

func _style_overlay_controls() -> void:
	if overlay_back_button:
		_style_button(overlay_back_button)
		overlay_back_button.add_theme_font_size_override("font_size", 18)
		overlay_back_button.visible = false
	if overlay_backdrop:
		overlay_backdrop.visible = false
	if collection_overlay:
		collection_overlay.visible = false
	if calendar_overlay:
		calendar_overlay.visible = false
	if collection_overlay:
		_style_overlay_panel(collection_overlay)
	if calendar_overlay:
		_style_overlay_panel(calendar_overlay)

func _style_overlay_panel(panel: PanelContainer) -> void:
	if panel == null:
		return
	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color = PALETTE.bg_mid
	panel_bg.border_color = PALETTE.gold_dark
	panel_bg.set_border_width_all(2)
	panel_bg.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", panel_bg)
	var vbox_panel = panel.get_node_or_null("OverlayVBox") as VBoxContainer
	if vbox_panel:
		vbox_panel.position = Vector2(16, 16)
		vbox_panel.custom_minimum_size = panel.size - Vector2(32, 32)
		var title = vbox_panel.get_node_or_null("Title") as Label
		if title:
			title.add_theme_font_override("font", celtic_font)
			title.add_theme_font_size_override("font_size", 26)
			title.add_theme_color_override("font_color", PALETTE.gold_bright)
		var body = vbox_panel.get_node_or_null("Body") as Label
		if body:
			body.add_theme_font_override("font", celtic_font_thin if celtic_font_thin != null else celtic_font)
			body.add_theme_font_size_override("font_size", 16)
			body.add_theme_color_override("font_color", PALETTE.cream)

func _on_menu_resized() -> void:
	call_deferred("_layout_centered")

func _layout_centered() -> void:
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return
	background.size = viewport_size

	var title_size = title_label.get_combined_minimum_size()
	var subtitle_size = Vector2.ZERO
	if subtitle_label.visible and subtitle_label.text != "":
		subtitle_size = subtitle_label.get_combined_minimum_size()
	vbox.queue_sort()
	var vbox_size = vbox.get_combined_minimum_size()
	
	var gap_title = 10.0
	var gap_subtitle = 24.0 if subtitle_size != Vector2.ZERO else 0.0
	var block_height = title_size.y + gap_title + subtitle_size.y + gap_subtitle + vbox_size.y
	var start_y = maxf(24.0, (viewport_size.y - block_height) * 0.5)
	
	title_label.position = Vector2((viewport_size.x - title_size.x) * 0.5, start_y)
	if subtitle_size != Vector2.ZERO:
		subtitle_label.position = Vector2((viewport_size.x - subtitle_size.x) * 0.5, start_y + title_size.y + gap_title)
	vbox.position = Vector2((viewport_size.x - vbox_size.x) * 0.5, start_y + title_size.y + gap_title + subtitle_size.y + gap_subtitle)

	_build_landscape(viewport_size)
	_update_scene_anchors(viewport_size)
	_layout_llm_controls(viewport_size)
	_layout_llm_boot_overlay(viewport_size)
	_layout_collection_button(viewport_size)
	_layout_top_right_buttons(viewport_size)
	_layout_overlays(viewport_size)

func _style_llm_controls() -> void:
	if llm_status_label:
		llm_status_label.add_theme_font_override("font", celtic_font_thin)
		llm_status_label.add_theme_font_size_override("font_size", 16)
		llm_status_label.add_theme_color_override("font_color", PALETTE.gold_bright)
	if llm_reload_button:
		_style_button(llm_reload_button)
		llm_reload_button.add_theme_font_size_override("font_size", 14)
		llm_reload_button.pressed.connect(_on_llm_reload_pressed)
	if llm_boot_overlay:
		var panel_bg := StyleBoxFlat.new()
		panel_bg.bg_color = PALETTE.bg_mid
		panel_bg.border_color = PALETTE.gold_dark
		panel_bg.set_border_width_all(2)
		panel_bg.set_corner_radius_all(8)
		llm_boot_overlay.add_theme_stylebox_override("panel", panel_bg)
	if llm_boot_title:
		llm_boot_title.add_theme_font_override("font", celtic_font)
		llm_boot_title.add_theme_font_size_override("font_size", 24)
		llm_boot_title.add_theme_color_override("font_color", PALETTE.gold_bright)
	if llm_boot_status:
		llm_boot_status.add_theme_font_override("font", celtic_font_thin)
		llm_boot_status.add_theme_font_size_override("font_size", 16)
		llm_boot_status.add_theme_color_override("font_color", PALETTE.cream)
	if llm_boot_detail:
		llm_boot_detail.add_theme_font_override("font", celtic_font_thin)
		llm_boot_detail.add_theme_font_size_override("font_size", 14)
		llm_boot_detail.add_theme_color_override("font_color", PALETTE.cream)
	if llm_boot_copy:
		_style_button(llm_boot_copy)
		llm_boot_copy.add_theme_font_size_override("font_size", 14)
		llm_boot_copy.pressed.connect(_on_llm_boot_copy)
	if llm_boot_logs:
		llm_boot_logs.add_theme_font_override("font", celtic_font_thin)
		llm_boot_logs.add_theme_font_size_override("font_size", 12)

func _layout_llm_controls(viewport_size: Vector2) -> void:
	if llm_status_label:
		var margin = Vector2(16, 16)
		llm_status_label.position = Vector2(viewport_size.x - 360 - margin.x, viewport_size.y - 24 - margin.y)
		llm_status_label.custom_minimum_size = Vector2(360, 24)
	if llm_reload_button:
		llm_reload_button.custom_minimum_size = Vector2(140, 26)
		llm_reload_button.position = Vector2(viewport_size.x - 140 - 16, viewport_size.y - 56 - 16)

func _layout_llm_boot_overlay(viewport_size: Vector2) -> void:
	if llm_boot_backdrop:
		llm_boot_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		llm_boot_backdrop.size = viewport_size
	if llm_boot_overlay:
		var max_w = minf(620.0, viewport_size.x - 48.0)
		var base_h = 520.0
		var max_h = minf(base_h, viewport_size.y - 48.0)
		llm_boot_overlay.size = Vector2(max_w, max_h)
		llm_boot_overlay.position = (viewport_size - llm_boot_overlay.size) * 0.5
		if llm_boot_vbox:
			llm_boot_vbox.position = Vector2(12, 12)
			llm_boot_vbox.custom_minimum_size = llm_boot_overlay.size - Vector2(24, 24)
	if llm_boot_logs:
		llm_boot_logs.visible = true
	if llm_boot_copy:
		llm_boot_copy.visible = true

func _layout_collection_button(viewport_size: Vector2) -> void:
	if collection_button == null:
		return
	var size = Vector2(220, 64)
	collection_button.custom_minimum_size = size
	collection_button.size = size
	collection_button.position = Vector2(viewport_size.x - size.x - 24, viewport_size.y - size.y - 20)

func _layout_top_right_buttons(viewport_size: Vector2) -> void:
	if menu_icon_button:
		menu_icon_button.custom_minimum_size = TOP_ICON_SIZE
		menu_icon_button.size = TOP_ICON_SIZE
		menu_icon_button.position = Vector2(
			viewport_size.x - TOP_ICON_SIZE.x - TOP_ICON_MARGIN.x,
			TOP_ICON_MARGIN.y
		)
	if save_book_button:
		save_book_button.custom_minimum_size = TOP_ICON_SIZE
		save_book_button.size = TOP_ICON_SIZE
		var menu_pos := Vector2(
			viewport_size.x - TOP_ICON_SIZE.x - TOP_ICON_MARGIN.x,
			TOP_ICON_MARGIN.y
		)
		save_book_button.position = menu_pos - Vector2(TOP_ICON_SIZE.x + TOP_ICON_GAP, 0)

func _layout_overlays(viewport_size: Vector2) -> void:
	if overlay_backdrop:
		overlay_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay_backdrop.size = viewport_size
	if overlay_back_button:
		overlay_back_button.custom_minimum_size = Vector2(220, 44)
		overlay_back_button.position = Vector2(24, 24)
	if collection_overlay:
		var size = Vector2(minf(820.0, viewport_size.x - 80.0), minf(520.0, viewport_size.y - 120.0))
		collection_overlay.size = size
		collection_overlay.position = (viewport_size - size) * 0.5
		_layout_overlay_vbox(collection_overlay)
	if calendar_overlay:
		var size = Vector2(minf(820.0, viewport_size.x - 80.0), minf(520.0, viewport_size.y - 120.0))
		calendar_overlay.size = size
		calendar_overlay.position = (viewport_size - size) * 0.5
		_layout_overlay_vbox(calendar_overlay)

func _layout_overlay_vbox(panel: PanelContainer) -> void:
	var vbox_panel = panel.get_node_or_null("OverlayVBox") as VBoxContainer
	if vbox_panel:
		vbox_panel.position = Vector2(16, 16)
		vbox_panel.custom_minimum_size = panel.size - Vector2(32, 32)

func _ensure_overlay_panel(name: String, title: String) -> PanelContainer:
	var panel = get_node_or_null(name) as PanelContainer
	if panel == null:
		panel = PanelContainer.new()
		panel.name = name
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.z_index = 130
		panel.z_as_relative = false
		add_child(panel)
		var vbox_panel := VBoxContainer.new()
		vbox_panel.name = "OverlayVBox"
		vbox_panel.add_theme_constant_override("separation", 12)
		panel.add_child(vbox_panel)
		var title_label := Label.new()
		title_label.name = "Title"
		title_label.text = title
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_panel.add_child(title_label)
		var body := Label.new()
		body.name = "Body"
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.text = _overlay_body_text(name)
		vbox_panel.add_child(body)
	return panel

func _overlay_body_text(name: String) -> String:
	if name == "CalendarOverlay":
		return "Calendrier des evenements\n\n- Jour/Nuit: bonus differents\n- Heures cles: apparition accrue\n- Saison: variations rares\n\nConsulter les alignements et presages."
	return "Collection et hauts-faits\n\n- Defis caches\n- Recompenses utilitaires\n- Progression de Gloire"

func _load_calendar_json() -> void:
	if calendar_json_loaded:
		return
	if not FileAccess.file_exists(CALENDAR_JSON_PATH):
		push_warning("Calendar JSON not found: " + CALENDAR_JSON_PATH)
		return
	var file := FileAccess.open(CALENDAR_JSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("Cannot open calendar JSON")
		return
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		push_warning("Calendar JSON parse error: " + json.get_error_message())
		return
	var data: Dictionary = json.data
	if data.has("events"):
		for event in data.events:
			if event.has("date"):
				calendar_events_by_date[event.date] = event
	calendar_json_loaded = true
	print("Calendar loaded: ", calendar_events_by_date.size(), " events")

func _get_event_for_date(year: int, month: int, day: int) -> Dictionary:
	var date_str := "%04d-%02d-%02d" % [year, month, day]
	if calendar_events_by_date.has(date_str):
		return calendar_events_by_date[date_str]
	return {}

func _open_collection_overlay() -> void:
	_open_overlay("collection")

func _open_calendar_overlay() -> void:
	# Initialiser le calendrier au mois actuel
	var now = Time.get_datetime_dict_from_system()
	calendar_current_month = int(now.month)
	calendar_current_year = int(now.year)
	calendar_open = true
	calendar_anim_progress = 0.0
	calendar_page_flip_progress = 0.0
	calendar_page_flip_direction = 0
	_spawn_calendar_dust()
	_open_overlay("calendar")

func _open_overlay(kind: String) -> void:
	overlay_active = kind
	if overlay_backdrop:
		overlay_backdrop.visible = true
	if overlay_back_button:
		overlay_back_button.visible = true
	if collection_overlay:
		collection_overlay.visible = kind == "collection"
	# Le calendrier utilise le rendu custom, pas le PanelContainer
	if calendar_overlay:
		calendar_overlay.visible = false  # On cache le panel, on dessine nous-mÃªmes
	if collection_button:
		collection_button.disabled = true
	for btn in buttons:
		btn.disabled = true

func _close_overlay() -> void:
	overlay_active = ""
	if overlay_active == "calendar":
		calendar_open = false
	calendar_open = false
	if overlay_backdrop:
		overlay_backdrop.visible = false
	if overlay_back_button:
		overlay_back_button.visible = false
	if collection_overlay:
		collection_overlay.visible = false
	if calendar_overlay:
		calendar_overlay.visible = false
	if collection_button:
		collection_button.disabled = false
	for btn in buttons:
		btn.disabled = false

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# CALENDRIER - Fonctions utilitaires
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

func _get_days_in_month(month: int, year: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			if (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0):
				return 29
			return 28
	return 30

func _get_first_weekday(month: int, year: int) -> int:
	# Algorithme de Zeller pour obtenir le jour de la semaine du 1er du mois
	var q := 1  # jour
	var m := month
	var y := year
	if m < 3:
		m += 12
		y -= 1
	var k: int = y % 100
	var j: int = int(y / 100)
	var h: int = (q + int((13 * (m + 1)) / 5) + k + int(k / 4) + int(j / 4) - 2 * j) % 7
	# Convertir de Zeller (0=Samedi) Ã  notre format (0=Lundi)
	return (h + 5) % 7

func _spawn_calendar_dust() -> void:
	calendar_dust_particles.clear()
	for i in range(25):
		calendar_dust_particles.append({
			"pos": Vector2(randf_range(-200, 200), randf_range(-150, 150)),
			"vel": Vector2(randf_range(-15, 15), randf_range(-30, -10)),
			"size": randf_range(1.0, 3.0),
			"alpha": randf_range(0.3, 0.7),
			"lifetime": randf_range(0.5, 1.5),
			"age": 0.0,
		})

func _navigate_calendar_month(direction: int) -> void:
	calendar_page_flip_direction = direction
	calendar_page_flip_progress = 0.0
	calendar_current_month += direction
	if calendar_current_month > 12:
		calendar_current_month = 1
		calendar_current_year += 1
	elif calendar_current_month < 1:
		calendar_current_month = 12
		calendar_current_year -= 1
	# Effet de tremblement
	calendar_shake_offset = Vector2(direction * 5.0, randf_range(-2, 2))
	_spawn_calendar_dust()

func _bind_llm_manager() -> void:
	if has_node("/root/MerlinAI"):
		llm_manager = get_node("/root/MerlinAI")
	elif has_node("/root/LLMManager"):
		llm_manager = get_node("/root/LLMManager")
	if llm_manager:
		llm_manager.status_changed.connect(_on_llm_status_changed)
		llm_manager.ready_changed.connect(_on_llm_ready_changed)
		if llm_manager.has_signal("log_updated"):
			llm_manager.log_updated.connect(_on_llm_log_updated)
			var status: Dictionary = llm_manager.get_status()
			_on_llm_status_changed(str(status.status), str(status.detail), float(status.progress))
			if llm_manager.has_method("get_log_text"):
				_on_llm_log_updated(llm_manager.get_log_text())
			_update_llm_boot_state()

func _on_llm_status_changed(status_text: String, detail_text: String, _progress: float) -> void:
	if llm_status_label:
		llm_status_label.text = status_text + " - " + detail_text
	if llm_boot_status:
		llm_boot_status.text = status_text
	if llm_boot_detail:
		llm_boot_detail.text = detail_text
	if llm_boot_progress:
		llm_boot_progress.value = clampf(_progress, 0.0, 100.0)
	_update_llm_boot_state()

func _on_llm_ready_changed(_is_ready: bool) -> void:
	_update_llm_boot_state()

func _on_llm_log_updated(text: String) -> void:
	if llm_boot_logs:
		llm_boot_logs.text = text
		llm_boot_logs.scroll_vertical = llm_boot_logs.get_line_count()

func _on_llm_reload_pressed() -> void:
	if llm_manager:
		if llm_manager.has_method("reload_models"):
			llm_manager.reload_models()
		elif llm_manager.has_method("reload_model"):
			llm_manager.reload_model()
		_update_llm_boot_state()

func _on_llm_boot_copy() -> void:
	if llm_manager and llm_manager.has_method("get_log_text"):
		DisplayServer.clipboard_set(llm_manager.get_log_text())
		if llm_boot_detail:
			llm_boot_detail.text = "Backlog copie dans le presse-papiers."

func _update_llm_boot_state() -> void:
	var is_ready_now = true
	if llm_manager and llm_manager.has_method("get_status"):
		var status: Dictionary = llm_manager.get_status()
		is_ready_now = bool(status.get("ready", false))
	if is_ready_now and not llm_ready_cached:
		_start_menu_intro()
		menu_intro_pending = false
	llm_ready_cached = is_ready_now
	if llm_boot_backdrop:
		llm_boot_backdrop.visible = false
	if llm_boot_overlay:
		llm_boot_overlay.visible = false
	if title_label:
		title_label.visible = true
	if subtitle_label:
		subtitle_label.visible = subtitle_label.text != ""
	if vbox:
		vbox.visible = true
	for btn in buttons:
		btn.disabled = false
	if llm_status_label:
		llm_status_label.visible = false
	if llm_reload_button:
		llm_reload_button.visible = false

func _process(delta: float) -> void:
	time_elapsed += delta
	mouse_pos = get_global_mouse_position()
	_update_menu_intro(delta)
	_update_time_of_day()
	_update_orb_render_state(delta)
	_update_particles(delta)
	if not minimal_background_mode:
		_update_weather_particles(delta)
		_update_scene_anchors(get_viewport_rect().size)
		_update_magic_particles(delta)
		_update_smoke_particles(delta)
		_update_fireflies(delta)
	_update_cursor(delta)
	_update_button_animations(delta)
	_update_calendar_animations(delta)
	queue_redraw()

func _update_os_boot(delta: float) -> void:
	if boot_phase == BOOT_PHASE_DONE:
		return
	match boot_phase:
		BOOT_PHASE_LINES:
			boot_line_timer += delta
			if boot_line_timer >= BOOT_LINE_DELAY:
				boot_line_timer = 0.0
				if boot_visible_lines < BOOT_LINES.size():
					boot_visible_lines += 1
			if boot_visible_lines >= BOOT_LINES.size():
				boot_hold_timer += delta
				if boot_hold_timer >= BOOT_HOLD_TIME:
					boot_phase = BOOT_PHASE_FADE
		BOOT_PHASE_FADE:
			boot_fade = min(1.0, boot_fade + delta / BOOT_FADE_TIME)
			if boot_fade >= 1.0:
				boot_phase = BOOT_PHASE_POWER_OFF
		BOOT_PHASE_POWER_OFF:
			boot_power = min(1.0, boot_power + delta / BOOT_POWER_TIME)
			if boot_power >= 1.0:
				boot_phase = BOOT_PHASE_MENU
				if title_label:
					title_label.visible = true
				if vbox:
					vbox.visible = true
				if menu_intro_pending and llm_ready_cached:
					_start_menu_intro()
					menu_intro_pending = false
		BOOT_PHASE_MENU:
			boot_menu_fade = max(0.0, boot_menu_fade - delta / BOOT_MENU_FADE_TIME)
			if boot_menu_fade <= 0.0:
				boot_phase = BOOT_PHASE_DONE
		_:
			pass

func _update_menu_intro(delta: float) -> void:
	if menu_intro_done:
		return
	menu_intro_time += delta
	var title_alpha = clampf(menu_intro_time / 0.6, 0.0, 1.0)
	title_label.modulate.a = title_alpha
	for i in range(buttons.size()):
		var delay = 0.15 * float(i)
		var t = clampf((menu_intro_time - delay) / 0.35, 0.0, 1.0)
		var ease_value = t * t * (3.0 - 2.0 * t)
		buttons[i].modulate.a = ease_value
		buttons[i].scale = Vector2(0.92 + 0.08 * ease_value, 0.92 + 0.08 * ease_value)
	tree_intro_alpha = _intro_ease((menu_intro_time - 0.45) / 0.8)
	cabin_intro_alpha = _intro_ease((menu_intro_time - 0.65) / 0.8)
	if menu_intro_time > 0.15 * float(buttons.size()) + 0.6:
		menu_intro_done = true
		tree_intro_alpha = 1.0
		cabin_intro_alpha = 1.0

func _intro_ease(t: float) -> float:
	var v = clampf(t, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)

func _update_time_of_day() -> void:
	var now = Time.get_datetime_dict_from_system()
	var bucket = int(now.hour) * 60 + int(now.minute)
	if bucket == _last_time_bucket and sun_pos != Vector2.ZERO:
		return
	_last_time_bucket = bucket
	var t = (float(now.hour) + float(now.minute) / 60.0 + float(now.second) / 3600.0) / 24.0
	day_time = t
	var angle = t * TAU - PI / 2.0
	var height = sin(angle)
	var day = clamp((height + 0.1) / 1.1, 0.0, 1.0)
	night_factor = 1.0 - day
	sun_alpha = day
	var viewport_size = get_viewport_rect().size
	sun_pos = Vector2(viewport_size.x * (0.1 + 0.8 * t), viewport_size.y * (0.65 - 0.45 * height))
	var warm = Color(1.0, 0.7, 0.35)
	var noon = Color(1.0, 0.93, 0.75)
	sun_color = warm.lerp(noon, day)
	sky_top_color = _sample_time_gradient(day_time, [
		{"t": 0.0, "c": Color(0.03, 0.04, 0.08)},
		{"t": 0.22, "c": Color(0.24, 0.18, 0.34)},
		{"t": 0.32, "c": Color(0.22, 0.40, 0.70)},
		{"t": 0.50, "c": Color(0.25, 0.55, 0.90)},
		{"t": 0.72, "c": Color(0.28, 0.26, 0.50)},
		{"t": 0.85, "c": Color(0.08, 0.08, 0.12)},
		{"t": 1.0, "c": Color(0.03, 0.04, 0.08)},
	])
	sky_horizon_color = _sample_time_gradient(day_time, [
		{"t": 0.0, "c": Color(0.05, 0.05, 0.08)},
		{"t": 0.22, "c": Color(0.85, 0.50, 0.25)},
		{"t": 0.32, "c": Color(0.55, 0.75, 0.95)},
		{"t": 0.50, "c": Color(0.65, 0.85, 0.98)},
		{"t": 0.72, "c": Color(0.95, 0.55, 0.30)},
		{"t": 0.85, "c": Color(0.10, 0.08, 0.12)},
		{"t": 1.0, "c": Color(0.05, 0.05, 0.08)},
	])
	sky_mid_color = sky_top_color.lerp(sky_horizon_color, 0.55)
	_update_season_and_weather(now)

func _update_orb_render_state(delta: float) -> void:
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0:
		return

	# Calculer la position de l'arc basé sur le titre
	if title_label != null and title_label.visible:
		var title_size = title_label.get_combined_minimum_size()
		var title_center_x = title_label.position.x + title_size.x * 0.5
		var title_center_y = title_label.position.y + title_size.y * 0.5
		# L'arc encadre le titre avec une marge
		day_arc_radius = maxf(title_size.x * 0.7, 180.0)
		# Le centre de l'arc est sous le titre (le titre est au sommet de l'arc)
		day_arc_center = Vector2(title_center_x, title_center_y + day_arc_radius - DAY_ARC_TITLE_MARGIN)
	else:
		# Fallback si le titre n'est pas disponible
		day_arc_radius = viewport_size.x * 0.35
		day_arc_center = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.25)

	var current_hour = _get_current_hour()
	var day_t: float = current_hour / 24.0
	var orb_angle := PI - day_t * PI
	var target_pos := day_arc_center + Vector2(cos(orb_angle), -sin(orb_angle)) * day_arc_radius
	var target_size := ORB_MENU_SIZE

	if orb_intro_active:
		orb_intro_progress = minf(1.0, orb_intro_progress + delta / ORB_INTRO_TRANSITION_DURATION)
		var t := _intro_ease(orb_intro_progress)
		var mid := (orb_intro_start_pos + target_pos) * 0.5
		mid.y -= 60.0
		orb_render_pos = _quadratic_bezier(orb_intro_start_pos, mid, target_pos, t)
		orb_render_size = lerpf(orb_intro_start_size, target_size, t)
		if orb_intro_progress >= 1.0:
			orb_intro_active = false
	else:
		orb_render_pos = target_pos
		orb_render_size = target_size

	orb_render_color = _get_orb_color_for_hour(current_hour)
	orb_render_intensity = _get_orb_glow_intensity(current_hour)
	orb_light_pos = orb_render_pos
	orb_light_strength = orb_render_intensity * 0.65

func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return p0 * (u * u) + p1 * (2.0 * u * t) + p2 * (t * t)

func _sample_time_gradient(t: float, keys: Array) -> Color:
	if keys.is_empty():
		return Color(0, 0, 0)
	var clamped = fposmod(t, 1.0)
	for i in range(keys.size() - 1):
		var a = keys[i]
		var b = keys[i + 1]
		var ta = float(a["t"])
		var tb = float(b["t"])
		if clamped >= ta and clamped <= tb:
			var local = 0.0 if tb == ta else (clamped - ta) / (tb - ta)
			return (a["c"] as Color).lerp(b["c"] as Color, local)
	return keys[keys.size() - 1]["c"] as Color

func _draw() -> void:
	_draw_menu_scene()

func _draw_menu_scene() -> void:
	if minimal_background_mode:
		var viewport_size = get_viewport_rect().size
		if viewport_size.x > 0:
			draw_rect(Rect2(Vector2.ZERO, viewport_size), PALETTE.bg_deep)
		_draw_day_arc(viewport_size)
		_draw_particles()
		_draw_cursor()
		_draw_clock()
		# Dessiner le calendrier animÃ© par-dessus
		if calendar_open or calendar_anim_progress > 0.0:
			_draw_animated_calendar()
		return
	_draw_background()
	_draw_weather()
	_draw_day_arc(get_viewport_rect().size)
	_draw_particles()
	_draw_cursor()
	_draw_clock()
	_draw_collection_icon()
	# Dessiner le calendrier animÃ© par-dessus tout
	if calendar_open or calendar_anim_progress > 0.0:
		_draw_animated_calendar()

func _draw_os_boot(viewport_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0, 0, 0))
	var font: Font = ThemeDB.fallback_font
	if celtic_font_thin != null:
		font = celtic_font_thin
	elif celtic_font != null:
		font = celtic_font
	if font:
		var line_height = BOOT_FONT_SIZE + 6
		var start_x = 24.0
		var start_y = 28.0
		var visible_alpha = 1.0 - boot_fade
		var text_color = Color(0.85, 0.86, 0.82, visible_alpha)
		for i in range(boot_visible_lines):
			var line = BOOT_LINES[i]
			var pos = Vector2(start_x, start_y + float(i) * line_height)
			draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, BOOT_FONT_SIZE, text_color)

	if boot_phase == BOOT_PHASE_FADE:
		_draw_boot_overlay(viewport_size, boot_fade)
	elif boot_phase == BOOT_PHASE_POWER_OFF:
		_draw_boot_overlay(viewport_size, 1.0)
		var line_alpha = 1.0 - boot_power
		var line_len = lerpf(viewport_size.x * 0.9, 0.0, boot_power)
		var line_pos = Vector2((viewport_size.x - line_len) * 0.5, viewport_size.y * 0.5)
		var line_color = Color(0.98, 0.90, 0.70, line_alpha)
		draw_rect(Rect2(line_pos, Vector2(line_len, 2)), line_color)
		draw_rect(Rect2(line_pos - Vector2(0, 2), Vector2(line_len, 6)), Color(0.98, 0.90, 0.70, line_alpha * 0.35))

func _draw_boot_overlay(viewport_size: Vector2, alpha: float) -> void:
	var overlay = Color(0, 0, 0, clampf(alpha, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, viewport_size), overlay)

func _draw_background() -> void:
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0:
		return

	# Dark mystical background
	var bg_dark = Color(0.04, 0.05, 0.08)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), bg_dark)

	# Subtle vignette gradient
	for i in range(8):
		var t = float(i) / 8.0
		var margin = viewport_size * t * 0.15
		var vignette_color = Color(0, 0, 0, 0.08 * (1.0 - t))
		draw_rect(Rect2(margin, viewport_size - margin * 2), vignette_color)

	# Mystical floating particles in background
	_draw_mystical_ambient(viewport_size)

func _draw_mist_bands(viewport_size: Vector2) -> void:
	for i in range(4):
		var speed = 6.0 + i * 3.0
		var band_y = fposmod(time_elapsed * speed + i * 70.0, viewport_size.y + 40.0) - 20.0
		var band_h = 18.0 + i * 3.0
		var alpha = 0.03 + 0.02 * sin(time_elapsed * 0.6 + i)
		var color = PALETTE.bg_light
		color.a = alpha
		draw_rect(Rect2(0, band_y, viewport_size.x, band_h), color)

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# SPELL BOOK DRAWING FUNCTIONS
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

func _draw_mystical_ambient(viewport_size: Vector2) -> void:
	# Floating dust motes in the dark - more particles, better movement
	for i in range(60):
		var seed_val = float(i) * 1.618
		var speed_x = 2 + (i % 4) * 1.5
		var speed_y = 0.8 + (i % 3) * 0.4
		var x = fposmod(seed_val * 137.5 + time_elapsed * speed_x, viewport_size.x)
		var y = fposmod(seed_val * 89.3 - time_elapsed * speed_y * 10, viewport_size.y)
		var particle_size = 1.0 + (i % 4)
		var pulse = 0.5 + 0.5 * sin(time_elapsed * (0.5 + (i % 5) * 0.2) + seed_val)
		var alpha = (0.1 + 0.15 * pulse) * orb_light_strength

		# Color based on distance to orb
		var dist_to_orb = Vector2(x, y).distance_to(orb_light_pos)
		var orb_influence = clampf(1.0 - dist_to_orb / 500.0, 0.0, 1.0)
		var particle_color = PALETTE.blue.lerp(PALETTE.gold_bright, orb_influence * orb_light_strength)
		particle_color.a = alpha * (0.5 + orb_influence * 0.5)

		draw_rect(Rect2(x, y, particle_size, particle_size), particle_color)

	# Mystical fog wisps
	for i in range(5):
		var wisp_y = viewport_size.y * (0.7 + 0.2 * sin(time_elapsed * 0.1 + i * 1.3))
		var wisp_alpha = 0.03 + 0.02 * sin(time_elapsed * 0.3 + i)
		var wisp_color = PALETTE.blue
		wisp_color.a = wisp_alpha
		draw_rect(Rect2(0, wisp_y, viewport_size.x, 40 + i * 10), wisp_color)

func _draw_spell_book(viewport_size: Vector2) -> void:
	# Book breathing/floating animation
	book_hover_offset = sin(time_elapsed * 1.2) * 4 + sin(time_elapsed * 0.7) * 2

	var book_center = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.60 + book_hover_offset)
	var book_width = viewport_size.x * 0.72
	var book_height = viewport_size.y * 0.52
	var px = 4  # Pixel size for book

	# Calculate light from orb
	var light = _orb_light_factor(book_center)
	var light_color = _get_orb_color_for_hour(_get_current_hour())

	# === FLOATING MAGIC SYMBOLS above book ===
	_draw_floating_symbols(book_center, book_width, book_height, light, light_color)

	# === BOOK SHADOW (soft, layered) ===
	for i in range(4):
		var shadow_offset = 8 + i * 4
		var shadow_alpha = 0.15 - i * 0.03
		var shadow_color = Color(0, 0, 0, shadow_alpha)
		draw_rect(Rect2(book_center.x - book_width * 0.46 + shadow_offset,
						book_center.y + book_height * 0.40 + shadow_offset * 0.5,
						book_width * 0.92, book_height * 0.06), shadow_color)

	# === STACKED PAGES (visible from spine) ===
	_draw_page_stack(book_center, book_width, book_height, light, light_color, px)

	# === BOOK SPINE (center, detailed) ===
	_draw_book_spine(book_center, book_width, book_height, light, light_color, px)

	# === LEFT PAGE ===
	_draw_book_page(viewport_size, book_center, book_width, book_height, -1, light, light_color, px)

	# === RIGHT PAGE ===
	_draw_book_page(viewport_size, book_center, book_width, book_height, 1, light, light_color, px)

	# === BOOK COVERS (edges with detail) ===
	_draw_book_covers(book_center, book_width, book_height, light, light_color, px)

	# === PAGE TURNING EFFECT (improved) ===
	_draw_page_turn(book_center, book_width, book_height, light, light_color, px)

	# === MYSTICAL GLOW FROM BOOK ===
	_draw_book_glow(book_center, book_width, book_height, light, light_color)

	# === MAGIC DUST rising from pages ===
	_draw_magic_dust(book_center, book_width, book_height, light, light_color)

func _draw_floating_symbols(center: Vector2, width: float, height: float, light: float, light_color: Color) -> void:
	# Mystical runes floating above the book
	if light < 0.25:
		return

	for i in range(6):
		var seed_val = float(i) * 2.5
		var float_speed = 0.3 + (i % 3) * 0.15
		var orbit_radius = width * (0.15 + i * 0.05)
		var angle = time_elapsed * float_speed + seed_val

		var symbol_x = center.x + cos(angle) * orbit_radius
		var symbol_y = center.y - height * 0.55 - sin(time_elapsed * 0.5 + seed_val) * 20 - i * 15
		var symbol_alpha = light * 0.4 * (0.5 + 0.5 * sin(time_elapsed * 2 + seed_val))

		var symbol_color = light_color
		symbol_color.a = symbol_alpha

		# Draw small rune
		var rune_idx = i % RUNE_PATTERNS.size()
		var rune_scale = 2
		_draw_rune(symbol_x - rune_scale * 2.5, symbol_y, rune_scale, symbol_color, rune_idx)

		# Glow behind symbol
		var glow = symbol_color
		glow.a = symbol_alpha * 0.3
		draw_circle(Vector2(symbol_x, symbol_y + rune_scale * 2), rune_scale * 5, glow)

func _draw_page_stack(center: Vector2, width: float, height: float, light: float, light_color: Color, _px: int) -> void:
	# Visible page edges at the spine
	var page_color = Color(0.95, 0.92, 0.85)
	page_color = page_color.lerp(light_color, light * 0.1)

	var num_pages = 12
	var page_thickness = 1.5

	# Left side pages
	for i in range(num_pages):
		var offset = i * page_thickness
		var shade = page_color.darkened(0.02 * i)
		var y_start = center.y - height * 0.42 + offset * 0.3
		draw_line(Vector2(center.x - width * 0.02 - offset, y_start),
				  Vector2(center.x - width * 0.02 - offset, center.y + height * 0.42 - offset * 0.3),
				  shade, page_thickness)

	# Right side pages
	for i in range(num_pages):
		var offset = i * page_thickness
		var shade = page_color.darkened(0.02 * i)
		var y_start = center.y - height * 0.42 + offset * 0.3
		draw_line(Vector2(center.x + width * 0.02 + offset, y_start),
				  Vector2(center.x + width * 0.02 + offset, center.y + height * 0.42 - offset * 0.3),
				  shade, page_thickness)

func _draw_book_spine(center: Vector2, width: float, height: float, light: float, light_color: Color, px: int) -> void:
	var spine_width = width * 0.045
	var spine_color = Color(0.28, 0.16, 0.08)
	spine_color = spine_color.lerp(light_color, light * 0.12)

	# Main spine
	draw_rect(Rect2(center.x - spine_width * 0.5, center.y - height * 0.44,
					spine_width, height * 0.88), spine_color)

	# Spine ridges (horizontal lines)
	var ridge_color = spine_color.darkened(0.2)
	for i in range(5):
		var ridge_y = center.y - height * 0.35 + i * height * 0.16
		draw_rect(Rect2(center.x - spine_width * 0.5, ridge_y, spine_width, px), ridge_color)

	# Gold decoration on spine
	var gold = PALETTE.gold
	gold = gold.lerp(light_color, light * 0.25)
	gold.a = 0.8
	draw_rect(Rect2(center.x - px, center.y - height * 0.2, px * 2, height * 0.1), gold)
	draw_rect(Rect2(center.x - px, center.y + height * 0.1, px * 2, height * 0.1), gold)

	# Spine highlight
	var highlight = spine_color.lightened(0.15)
	highlight.a = 0.5
	draw_rect(Rect2(center.x - spine_width * 0.5, center.y - height * 0.44, px, height * 0.88), highlight)

func _draw_book_page(_viewport_size: Vector2, center: Vector2, width: float, height: float,
					  side: int, light: float, light_color: Color, px: int) -> void:
	var page_width = width * 0.44
	var page_height = height * 0.85
	var page_x = center.x + (side * width * 0.02) + (side * page_width * 0.5 if side > 0 else -page_width - side * width * 0.02)
	if side < 0:
		page_x = center.x - width * 0.02 - page_width
	else:
		page_x = center.x + width * 0.02
	var page_y = center.y - page_height * 0.5

	# Page base (aged parchment)
	var page_color = Color(0.92, 0.88, 0.78)
	page_color = page_color.lerp(light_color, light * 0.25)

	# Subtle page gradient (darker at edges)
	for i in range(5):
		var t = float(i) / 5.0
		var margin = t * px * 3
		var shade = page_color.lerp(page_color.darkened(0.15), t * 0.5)
		draw_rect(Rect2(page_x + margin * (0.5 if side < 0 else 1.0),
						page_y + margin,
						page_width - margin * 2,
						page_height - margin * 2), shade)

	# Page content - runes and text
	_draw_page_content(page_x, page_y, page_width, page_height, side, light, light_color, px)

	# Page edge shadow (inner)
	var edge_shadow = Color(0.4, 0.35, 0.25, 0.3)
	var edge_width = px * 2
	if side < 0:
		draw_rect(Rect2(page_x + page_width - edge_width, page_y, edge_width, page_height), edge_shadow)
	else:
		draw_rect(Rect2(page_x, page_y, edge_width, page_height), edge_shadow)

func _draw_page_content(page_x: float, page_y: float, page_width: float, page_height: float,
						 side: int, light: float, light_color: Color, px: int) -> void:
	var margin = px * 5
	var content_x = page_x + margin
	var content_y = page_y + margin
	var content_w = page_width - margin * 2
	var content_h = page_height - margin * 2

	# Ink color (changes with light, has warm sepia tone)
	var ink_color = Color(0.18, 0.12, 0.06)
	ink_color = ink_color.lerp(light_color.darkened(0.5), light * 0.15)

	# === ORNATE BORDER ===
	_draw_page_border(content_x, content_y, content_w, content_h, px, ink_color, light, light_color)

	# === CELTIC CORNERS (larger, more detailed) ===
	var corner_size = px * 10
	_draw_celtic_corner(content_x + px * 2, content_y + px * 2, px, ink_color, false, false)
	_draw_celtic_corner(content_x + content_w - corner_size - px * 2, content_y + px * 2, px, ink_color, true, false)
	_draw_celtic_corner(content_x + px * 2, content_y + content_h - corner_size - px * 2, px, ink_color, false, true)
	_draw_celtic_corner(content_x + content_w - corner_size - px * 2, content_y + content_h - corner_size - px * 2, px, ink_color, true, true)

	# === MAIN ILLUMINATED SYMBOL (Triquetra on left, Rune on right) ===
	var symbol_x = content_x + content_w * 0.5
	var symbol_y = content_y + content_h * 0.25

	if side < 0:
		# Left page: Triquetra (Celtic trinity)
		_draw_triquetra(symbol_x - px * 4.5, symbol_y, px * 2, ink_color, light, light_color)
	else:
		# Right page: Ogham rune
		var rune_idx = book_current_page % RUNE_PATTERNS.size()
		var rune_scale = px * 4
		_draw_rune(symbol_x - rune_scale * 2.5, symbol_y, rune_scale, ink_color, rune_idx)

		# Glowing rune when illuminated
		if light > 0.3:
			var glow_color = light_color
			glow_color.a = 0.4 * light * (0.7 + 0.3 * sin(time_elapsed * 2))
			_draw_rune(symbol_x - rune_scale * 2.5 - px, symbol_y - px, rune_scale, glow_color, rune_idx)

	# === TEXT BLOCKS (more realistic layout) ===
	_draw_text_block(content_x, content_y + content_h * 0.48, content_w, content_h * 0.45, px, ink_color, side)

	# === PAGE NUMBER ===
	var page_num_y = content_y + content_h - px * 4
	var page_num_x = content_x + content_w * 0.5 - px * 2
	for i in range(3 + book_current_page % 3):
		draw_rect(Rect2(page_num_x + i * px * 2, page_num_y, px, px * 2), ink_color)

func _draw_page_border(x: float, y: float, w: float, h: float, px: int, color: Color, _light: float, _light_color: Color) -> void:
	# Outer border line
	var border_color = color
	border_color.a = 0.6

	# Top border with pattern
	for i in range(int(w / (px * 3))):
		var bx = x + i * px * 3
		var pattern_offset = (i % 2) * px
		draw_rect(Rect2(bx, y + pattern_offset, px * 2, px), border_color)

	# Bottom border
	for i in range(int(w / (px * 3))):
		var bx = x + i * px * 3
		var pattern_offset = (i % 2) * px
		draw_rect(Rect2(bx, y + h - px - pattern_offset, px * 2, px), border_color)

	# Side borders
	for i in range(int(h / (px * 3))):
		var by = y + i * px * 3
		var pattern_offset = (i % 2) * px
		draw_rect(Rect2(x + pattern_offset, by, px, px * 2), border_color)
		draw_rect(Rect2(x + w - px - pattern_offset, by, px, px * 2), border_color)

func _draw_triquetra(x: float, y: float, px: int, color: Color, light: float, light_color: Color) -> void:
	# Draw triquetra symbol
	for row in range(TRIQUETRA.size()):
		var line: String = TRIQUETRA[row]
		for col in range(line.length()):
			if line[col] == 'X':
				draw_rect(Rect2(x + col * px, y + row * px, px, px), color)

	# Glow effect when lit
	if light > 0.35:
		var glow = light_color
		glow.a = 0.35 * light * (0.6 + 0.4 * sin(time_elapsed * 1.5))
		var center = Vector2(x + px * 4.5, y + px * 4.5)
		draw_circle(center, px * 8, glow)

		# Inner bright glow
		glow.a = 0.2 * light
		draw_circle(center, px * 5, glow)

func _draw_text_block(x: float, y: float, w: float, h: float, px: int, color: Color, side: int) -> void:
	# Animated ink reveal effect
	var reveal = clampf((time_elapsed - book_last_page_change) * 0.5, 0.0, 1.0)

	var line_spacing = px * 3.5
	var num_lines = int(h / line_spacing) - 2

	for i in range(num_lines):
		# Reveal lines progressively
		var line_reveal = clampf((reveal - float(i) * 0.08) * 3.0, 0.0, 1.0)
		if line_reveal <= 0:
			continue

		var line_y = y + i * line_spacing
		var line_indent = px * 2 if i == 0 else 0  # First line indent

		# Variable line lengths for realism
		var line_width_factor = 0.7 + 0.25 * sin(float(i) * 2.1 + float(side) * 1.7 + float(book_current_page))
		var line_width = (w - line_indent - px * 4) * line_width_factor * line_reveal

		var text_color = color
		text_color.a = 0.75 * line_reveal

		# Main text line
		draw_rect(Rect2(x + line_indent + px * 2, line_y, line_width, px * 1.5), text_color)

		# Word gaps (breaks in the line)
		var num_gaps = 2 + i % 3
		for g in range(num_gaps):
			var gap_x = x + line_indent + px * 2 + (line_width / (num_gaps + 1)) * (g + 1)
			var gap_width = px * (2 + g % 2)
			var page_bg = Color(0.92, 0.88, 0.78, 0.9)
			draw_rect(Rect2(gap_x - gap_width * 0.5, line_y, gap_width, px * 1.5), page_bg)

	# Decorative initial letter (drop cap) on first line
	if reveal > 0.3:
		var cap_color = color
		cap_color.a = 0.85 * reveal
		var cap_x = x + px * 2
		var cap_y = y - px
		draw_rect(Rect2(cap_x, cap_y, px * 5, px * 6), cap_color)
		# Hollow center
		var page_bg = Color(0.92, 0.88, 0.78)
		draw_rect(Rect2(cap_x + px, cap_y + px, px * 3, px * 4), page_bg)

func _draw_celtic_corner(x: float, y: float, px: int, color: Color, flip_h: bool, flip_v: bool) -> void:
	for row in range(CELTIC_CORNER.size()):
		var line: String = CELTIC_CORNER[row]
		for col in range(line.length()):
			if line[col] == 'X':
				var draw_x = x + (line.length() - 1 - col if flip_h else col) * px
				var draw_y = y + (CELTIC_CORNER.size() - 1 - row if flip_v else row) * px
				draw_rect(Rect2(draw_x, draw_y, px, px), color)

func _draw_rune(x: float, y: float, px: int, color: Color, pattern_idx: int) -> void:
	var pattern = RUNE_PATTERNS[pattern_idx % RUNE_PATTERNS.size()]
	for row in range(pattern.size()):
		var line: String = pattern[row]
		for col in range(line.length()):
			if line[col] == 'X':
				draw_rect(Rect2(x + col * px, y + row * px, px, px), color)

func _draw_book_covers(center: Vector2, width: float, height: float,
						light: float, light_color: Color, px: int) -> void:
	var cover_color = Color(0.35, 0.20, 0.10)  # Rich leather brown
	cover_color = cover_color.lerp(light_color, light * 0.1)
	var cover_dark = cover_color.darkened(0.3)
	var gold_color = PALETTE.gold
	gold_color = gold_color.lerp(light_color, light * 0.3)

	# Left cover edge
	var left_edge_x = center.x - width * 0.48
	draw_rect(Rect2(left_edge_x, center.y - height * 0.45, px * 4, height * 0.9), cover_color)
	draw_rect(Rect2(left_edge_x, center.y - height * 0.45, px, height * 0.9), cover_dark)
	# Gold decoration on left
	draw_rect(Rect2(left_edge_x + px, center.y - height * 0.35, px * 2, height * 0.1), gold_color)
	draw_rect(Rect2(left_edge_x + px, center.y + height * 0.25, px * 2, height * 0.1), gold_color)

	# Right cover edge
	var right_edge_x = center.x + width * 0.48 - px * 4
	draw_rect(Rect2(right_edge_x, center.y - height * 0.45, px * 4, height * 0.9), cover_color)
	draw_rect(Rect2(right_edge_x + px * 3, center.y - height * 0.45, px, height * 0.9), cover_dark)
	# Gold decoration on right
	draw_rect(Rect2(right_edge_x + px, center.y - height * 0.35, px * 2, height * 0.1), gold_color)
	draw_rect(Rect2(right_edge_x + px, center.y + height * 0.25, px * 2, height * 0.1), gold_color)

	# Top and bottom edges
	draw_rect(Rect2(center.x - width * 0.46, center.y - height * 0.46, width * 0.92, px * 2), cover_dark)
	draw_rect(Rect2(center.x - width * 0.46, center.y + height * 0.44, width * 0.92, px * 2), cover_dark)

func _draw_page_turn(center: Vector2, width: float, height: float,
					  light: float, light_color: Color, _px: int) -> void:
	# Smooth page turning animation with easing
	var turn_speed = book_page_turn_speed * (1.0 + 0.5 * sin(time_elapsed * 0.3))
	book_page_turn_progress += turn_speed * book_page_turn_direction

	if book_page_turn_progress > 1.0:
		book_page_turn_progress = 1.0
		book_page_turn_direction = -1
		book_current_page = (book_current_page + 1) % RUNE_PATTERNS.size()
		book_last_page_change = time_elapsed
	elif book_page_turn_progress < 0.0:
		book_page_turn_progress = 0.0
		book_page_turn_direction = 1
		book_last_page_change = time_elapsed

	# Draw multiple turning pages for depth
	if book_page_turn_progress > 0.03 and book_page_turn_progress < 0.97:
		var page_width = width * 0.43
		var page_height = height * 0.83

		# Draw 3 pages turning together with slight offsets
		for page_layer in range(3):
			var layer_offset = float(page_layer) * 0.05
			var adjusted_progress = clampf(book_page_turn_progress - layer_offset, 0.0, 1.0)

			if adjusted_progress <= 0.02 or adjusted_progress >= 0.98:
				continue

			# Eased turn angle for more natural movement
			var ease_progress = _ease_in_out(adjusted_progress)
			var turn_angle = ease_progress * PI

			# Page curvature
			var curve = sin(turn_angle)
			var lift = sin(turn_angle) * 15  # Page lifts in middle of turn

			# Page position
			var page_x = center.x + cos(turn_angle) * page_width * 0.5 - page_width * 0.5
			var page_y = center.y - page_height * 0.5 - lift

			# Page color with shadow based on angle
			var turn_color = Color(0.94, 0.90, 0.82)
			turn_color = turn_color.lerp(light_color, light * 0.15)
			var shadow_amount = 0.12 * curve * (1.0 + page_layer * 0.3)
			turn_color = turn_color.darkened(shadow_amount)
			turn_color.a = 0.95 - page_layer * 0.1

			# Calculate page shape with curve
			var curve_points := PackedVector2Array()
			var num_points = 12
			for i in range(num_points + 1):
				var t = float(i) / float(num_points)
				var local_curve = sin(t * PI) * curve * page_width * 0.15
				var x_pos = page_x + (page_width - local_curve) * (1.0 - t)
				curve_points.append(Vector2(x_pos, page_y + t * page_height))

			# Close the shape
			for i in range(num_points, -1, -1):
				var t = float(i) / float(num_points)
				var local_curve = sin(t * PI) * curve * page_width * 0.1
				curve_points.append(Vector2(page_x - local_curve * 0.3, page_y + t * page_height))

			draw_polygon(curve_points, PackedColorArray([turn_color]))

			# Page edge highlight
			if page_layer == 0:
				var edge_color = Color(1, 1, 1, 0.4 * curve)
				for i in range(num_points):
					var t1 = float(i) / float(num_points)
					var t2 = float(i + 1) / float(num_points)
					var c1 = sin(t1 * PI) * curve * page_width * 0.15
					var c2 = sin(t2 * PI) * curve * page_width * 0.15
					var p1 = Vector2(page_x + (page_width - c1) * (1.0 - t1), page_y + t1 * page_height)
					var p2 = Vector2(page_x + (page_width - c2) * (1.0 - t2), page_y + t2 * page_height)
					draw_line(p1, p2, edge_color, 1.5)

				# Turning page shadow on the book
				var shadow_color = Color(0, 0, 0, 0.15 * curve)
				draw_rect(Rect2(page_x - 20, page_y + 10, 25, page_height - 20), shadow_color)

func _ease_in_out(t: float) -> float:
	# Smooth ease-in-out function
	if t < 0.5:
		return 2.0 * t * t
	else:
		return 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0

func _draw_book_glow(center: Vector2, width: float, height: float,
					  light: float, light_color: Color) -> void:
	if light < 0.15:
		return

	# Pulsing glow intensity
	var pulse = 0.7 + 0.3 * sin(time_elapsed * 1.5)
	var glow_color = light_color
	glow_color.a = 0.06 * light * pulse

	# Soft radial glow layers
	for i in range(6):
		var glow_size = 1.0 + float(i) * 0.12
		var glow_alpha = glow_color.a * pow(1.0 - float(i) / 6.0, 1.5)
		var gc = glow_color
		gc.a = glow_alpha

		# Slightly oval glow (wider than tall)
		var glow_w = width * 0.55 * glow_size
		var glow_h = height * 0.5 * glow_size
		draw_rect(Rect2(center.x - glow_w, center.y - glow_h, glow_w * 2, glow_h * 2), gc)

	# Light rays emanating from book (subtle)
	if light > 0.4:
		var ray_color = light_color
		ray_color.a = 0.04 * light
		for i in range(8):
			var angle = float(i) * PI / 4.0 + time_elapsed * 0.1
			var ray_length = height * 0.4 * (0.8 + 0.2 * sin(time_elapsed * 2 + float(i)))
			var start = center - Vector2(0, height * 0.1)
			var end_point = start + Vector2(cos(angle), sin(angle) - 0.5) * ray_length
			draw_line(start, end_point, ray_color, 3.0)

func _draw_magic_dust(center: Vector2, width: float, height: float, light: float, light_color: Color) -> void:
	if light < 0.2:
		return

	# Magical particles rising from the book
	for i in range(25):
		var seed_val = float(i) * 1.618 + 0.5
		var lifetime = fposmod(time_elapsed * 0.4 + seed_val * 0.3, 1.0)

		# Particle rises and fades
		var start_x = center.x + sin(seed_val * 5.0) * width * 0.35
		var start_y = center.y + height * 0.1

		var particle_x = start_x + sin(time_elapsed * (0.5 + seed_val * 0.1) + seed_val) * 30
		var particle_y = start_y - lifetime * height * 0.9 - sin(lifetime * PI) * 20

		var particle_alpha = sin(lifetime * PI) * light * 0.7
		var particle_size = 2 + sin(seed_val * 3) * 1.5

		# Color shifts from warm to cool as it rises
		var particle_color = light_color.lerp(PALETTE.gold_bright, lifetime * 0.5)
		particle_color.a = particle_alpha

		draw_rect(Rect2(particle_x, particle_y, particle_size, particle_size), particle_color)

		# Tiny trail
		if particle_alpha > 0.2:
			var trail_color = particle_color
			trail_color.a = particle_alpha * 0.4
			draw_rect(Rect2(particle_x, particle_y + particle_size, particle_size * 0.7, particle_size * 2), trail_color)

			# Small sparkle at particle tip
			var sparkle_alpha = particle_alpha * 0.6 * (0.5 + 0.5 * sin(time_elapsed * 8 + seed_val))
			if sparkle_alpha > 0.15:
				var sparkle_color = light_color.lerp(Color.WHITE, 0.5)
				sparkle_color.a = sparkle_alpha
				draw_rect(Rect2(particle_x - 1, particle_y - 1, 3, 3), sparkle_color)

func _draw_book_particles(viewport_size: Vector2) -> void:
	# Floating dust particles illuminated by the orb
	for i in range(20):
		var seed_val = float(i) * 3.14159
		var x = viewport_size.x * 0.3 + sin(seed_val * 2.1 + time_elapsed * 0.3) * viewport_size.x * 0.4
		var y = viewport_size.y * 0.4 + cos(seed_val * 1.7 + time_elapsed * 0.2) * viewport_size.y * 0.3
		var dist_to_orb = orb_light_pos.distance_to(Vector2(x, y))
		var brightness = clampf(1.0 - dist_to_orb / 400.0, 0.0, 1.0) * orb_light_strength

		if brightness > 0.05:
			var particle_color = PALETTE.gold_bright
			particle_color.a = brightness * 0.5
			draw_rect(Rect2(x, y, 2, 2), particle_color)

func _get_current_hour() -> float:
	var now = Time.get_datetime_dict_from_system()
	return float(now.hour) + float(now.minute) / 60.0 + float(now.second) / 3600.0

func _draw_back_mountain(viewport_size: Vector2) -> void:
	var base_y = viewport_size.y * 0.62
	var peak_y = viewport_size.y * 0.40
	var mountain_base = PALETTE.green_dark.lerp(PALETTE.wood_dark, 0.4)
	if not force_grass_plain:
		mountain_base = mountain_base.lerp(season_tint, 0.12)
	var mountain_color = mountain_base.lerp(PALETTE.bg_mid, 0.25)
	var light = _orb_light_factor(Vector2(viewport_size.x * 0.5, peak_y))
	mountain_color = mountain_color.lerp(PALETTE.gold_bright, light * 0.25)
	mountain_color.a = 0.9
	var shade_color = mountain_color.darkened(0.12)
	var ridge = PackedVector2Array()
	var step = PIXEL_SIZE * 3
	var count = int(ceil(viewport_size.x / step)) + 2
	var current = peak_y
	for i in range(count):
		current += sin(float(i) * 0.6 + time_elapsed * 0.1) * 2.0
		current += randf_range(-2.0, 2.0)
		current = clampf(current, peak_y - 24.0, peak_y + 32.0)
		ridge.append(Vector2(i * step, round(current / PIXEL_SIZE) * PIXEL_SIZE))
	ridge.append(Vector2(viewport_size.x, base_y))
	ridge.append(Vector2(0, base_y))
	draw_polygon(ridge, PackedColorArray([mountain_color]))
	# Snow cap
	var snow_line = PackedVector2Array()
	for i in range(count):
		var x = i * step
		var y = ridge[i].y + 12
		snow_line.append(Vector2(x, y))
	snow_line.append(Vector2(viewport_size.x, base_y))
	snow_line.append(Vector2(0, base_y))
	var snow = PALETTE.cream
	snow.a = 0.25
	draw_polygon(snow_line, PackedColorArray([snow]))
	# Shadow ridge
	var shadow_line = PackedVector2Array()
	for i in range(count):
		var x = i * step
		var y = ridge[i].y + 18 + sin(float(i) * 0.8) * 2.0
		shadow_line.append(Vector2(x, y))
	shadow_line.append(Vector2(viewport_size.x, base_y))
	shadow_line.append(Vector2(0, base_y))
	shade_color.a = 0.35
	draw_polygon(shadow_line, PackedColorArray([shade_color]))

func _draw_rolling_hills(viewport_size: Vector2) -> void:
	var base_y = viewport_size.y * 0.70
	var amplitude = viewport_size.y * 0.06
	var step = PIXEL_SIZE * 4
	var count = int(ceil(viewport_size.x / step)) + 2
	var hill_color = _season_forest_color(0).lerp(PALETTE.bg_mid, 0.2)
	var light = _orb_light_factor(Vector2(viewport_size.x * 0.5, base_y - amplitude))
	hill_color = hill_color.lerp(PALETTE.gold_bright, light * 0.18)
	var points = PackedVector2Array()
	for i in range(count):
		var x = i * step
		var y = base_y - amplitude * (0.4 + 0.6 * sin(float(i) * 0.45 + time_elapsed * 0.1))
		points.append(Vector2(x, round(y / PIXEL_SIZE) * PIXEL_SIZE))
	points.append(Vector2(viewport_size.x, viewport_size.y))
	points.append(Vector2(0, viewport_size.y))
	draw_polygon(points, PackedColorArray([hill_color]))

	var back_color = hill_color.darkened(0.12)
	var back_points = PackedVector2Array()
	for i in range(count):
		var x = i * step
		var y = base_y - amplitude * (0.6 + 0.5 * sin(float(i) * 0.35 + time_elapsed * 0.08 + 1.4))
		back_points.append(Vector2(x, round((y - 14) / PIXEL_SIZE) * PIXEL_SIZE))
	back_points.append(Vector2(viewport_size.x, viewport_size.y))
	back_points.append(Vector2(0, viewport_size.y))
	draw_polygon(back_points, PackedColorArray([back_color]))

func _draw_day_arc(viewport_size: Vector2) -> void:
	if day_arc_radius <= 0.0:
		return

	var arc_center := day_arc_center
	var arc_radius := day_arc_radius

	# Couleur de l'arc - bleu lumineux subtil
	var arc_color := Color(0.35, 0.55, 0.85, 0.4)

	# Dessiner l'arc (demi-cercle superieur) - 90% largeur
	var segments := 64
	var arc_points := PackedVector2Array()
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var angle := PI - t * PI
		var dir := Vector2(cos(angle), -sin(angle))
		arc_points.append(arc_center + dir * arc_radius)
	draw_polyline(arc_points, arc_color, 2.5, true)

	# Glow de l'arc
	var glow_color := Color(0.3, 0.5, 0.9, 0.12)
	for i in range(segments):
		var t := float(i) / float(segments)
		var angle := PI - t * PI
		var dir := Vector2(cos(angle), -sin(angle))
		var p1 := arc_center + dir * (arc_radius - 8)
		var p2 := arc_center + dir * (arc_radius + 8)
		draw_line(p1, p2, glow_color, 12.0)

	# Marqueurs (sans labels d'heures)
	var tick_color := arc_color
	tick_color.a = 0.45
	for h in range(25):
		var t := float(h) / 24.0
		var angle := PI - t * PI
		var dir := Vector2(cos(angle), -sin(angle))
		var is_major := (h % 6 == 0)
		var tick_inner := arc_center + dir * (arc_radius - (8.0 if is_major else 4.0))
		var tick_outer := arc_center + dir * (arc_radius + (10.0 if is_major else 5.0))
		var tick_width := 2.0 if is_major else 1.0
		var tick_alpha := 0.45 if is_major else 0.2
		draw_line(tick_inner, tick_outer, Color(tick_color.r, tick_color.g, tick_color.b, tick_alpha), tick_width, true)

	# Orbe (position animee)
	var orb_pos := orb_render_pos
	var orb_size := orb_render_size
	var orb_color := orb_render_color
	var glow_intensity := orb_render_intensity

	_draw_orb_directional_light(viewport_size, orb_pos, glow_intensity)
	_draw_time_orb(orb_pos, orb_size, orb_color, glow_intensity)
func _draw_orb_directional_light(viewport_size: Vector2, orb_pos: Vector2, intensity: float) -> void:
	if intensity <= 0.05:
		return

	var beam_height := viewport_size.y * 0.32
	var top_width := viewport_size.x * 0.18
	var base_width := viewport_size.x * 0.55
	var steps := 10
	var light_color := Color(0.45, 0.65, 1.0, 0.0)

	# Soft cone light descending from the orb
	for i in range(steps):
		var t := float(i) / float(maxi(steps - 1, 1))
		var w := lerpf(top_width, base_width, t)
		var y := lerpf(orb_pos.y + 8.0, orb_pos.y + beam_height, t)
		var h := beam_height / float(steps)
		var alpha := intensity * (0.18 * (1.0 - t) + 0.02)
		draw_rect(Rect2(orb_pos.x - w * 0.5, y, w, h), Color(light_color.r, light_color.g, light_color.b, alpha))

	# Ambient top wash
	var wash_alpha := intensity * 0.08
	draw_rect(Rect2(0, 0, viewport_size.x, viewport_size.y * 0.16), Color(light_color.r, light_color.g, light_color.b, wash_alpha))
func _draw_time_orb(pos: Vector2, size: float, color: Color, intensity: float) -> void:
	var pulse := 0.85 + 0.15 * sin(time_elapsed * 2.5)
	var actual_size := size * pulse

	# Glow externe (bleu)
	var blue_glow := Color(0.3, 0.55, 1.0)
	for i in range(5):
		var glow_radius := actual_size * (3.5 - float(i) * 0.5)
		var glow_alpha := 0.08 * (1.0 - float(i) * 0.18) * intensity
		draw_circle(pos, glow_radius, Color(blue_glow.r, blue_glow.g, blue_glow.b, glow_alpha))

	# Orbe principal
	var core_color := color.lerp(Color(0.5, 0.7, 1.0), 0.3)
	core_color.a = 0.9
	draw_circle(pos, actual_size, core_color)

	# Coeur lumineux
	var bright_core := Color(0.85, 0.92, 1.0)
	bright_core.a = 0.95 * intensity
	draw_circle(pos, actual_size * 0.55, bright_core)

	# Reflet
	if intensity > 0.3:
		var highlight_pos := pos + Vector2(-actual_size * 0.25, -actual_size * 0.25)
		draw_circle(highlight_pos, actual_size * 0.2, Color(1.0, 1.0, 1.0, 0.5 * intensity * pulse))

func _get_orb_color_for_hour(hour: float) -> Color:
	# Time-based color gradient:
	# 0h: gray-blue (midnight)
	# 2h: blue (blue hour)
	# 6h: white-gray (dawn)
	# 12h: bright white (noon)
	# 18h: black (dusk)
	# 22h: dark blue-gray (night)
	hour = fposmod(hour, 24.0)

	var midnight = Color(0.3, 0.35, 0.5)
	var blue_hour = Color(0.25, 0.45, 0.85)
	var dawn = Color(0.85, 0.85, 0.92)
	var noon = Color(1.0, 0.98, 0.92)
	var dusk = Color(0.08, 0.08, 0.1)
	var night = Color(0.18, 0.22, 0.38)

	if hour < 2.0:
		return midnight.lerp(blue_hour, hour / 2.0)
	elif hour < 6.0:
		return blue_hour.lerp(dawn, (hour - 2.0) / 4.0)
	elif hour < 12.0:
		return dawn.lerp(noon, (hour - 6.0) / 6.0)
	elif hour < 18.0:
		return noon.lerp(dusk, (hour - 12.0) / 6.0)
	elif hour < 22.0:
		return dusk.lerp(night, (hour - 18.0) / 4.0)
	else:
		return night.lerp(midnight, (hour - 22.0) / 2.0)

func _get_orb_glow_intensity(hour: float) -> float:
	# Glow intensity: bright during day, dim at night
	hour = fposmod(hour, 24.0)
	if hour < 6.0:
		return lerpf(0.3, 0.6, hour / 6.0)
	elif hour < 12.0:
		return lerpf(0.6, 1.0, (hour - 6.0) / 6.0)
	elif hour < 18.0:
		return lerpf(1.0, 0.15, (hour - 12.0) / 6.0)
	else:
		return lerpf(0.15, 0.3, (hour - 18.0) / 6.0)

func _draw_orb_glow_timed(pos: Vector2, orb_size: float, color: Color, intensity: float) -> void:
	var pulse = 0.85 + 0.15 * sin(time_elapsed * 2.5)
	var actual_size = orb_size * pulse

	# Outer glow
	var glow_outer = color
	glow_outer.a = 0.12 * intensity
	draw_circle(pos, actual_size * 4.0, glow_outer)

	# Middle glow
	var glow_mid = color
	glow_mid.a = 0.3 * intensity
	draw_circle(pos, actual_size * 2.5, glow_mid)

	# Inner glow
	var glow_inner = color.lerp(Color.WHITE, 0.3)
	glow_inner.a = 0.5 * intensity
	draw_circle(pos, actual_size * 1.5, glow_inner)

	# Core orb
	var core = color
	core.a = 0.95
	draw_circle(pos, actual_size, core)

	# Highlight (only when bright enough)
	if intensity > 0.35:
		var highlight = Color.WHITE
		highlight.a = 0.55 * intensity
		draw_circle(pos - Vector2(actual_size * 0.25, actual_size * 0.25), actual_size * 0.35, highlight)

func _draw_orb_glow(pos: Vector2, orb_size: float, color: Color) -> void:
	_draw_orb_glow_timed(pos, orb_size, color, 1.0)

func _draw_isometric_scene(viewport_size: Vector2) -> void:
	var tile_w = 48.0
	var tile_h = 24.0
	var grid_w = 12
	var grid_h = 8
	var origin = Vector2(viewport_size.x * 0.48, viewport_size.y * 0.70)
	var river_base = float(grid_w) * 0.35
	var water_color = Color(0.20, 0.45, 0.75, 0.85)
	var water_high = Color(0.32, 0.58, 0.88, 0.9)
	var ground_color = _season_ground_color().lerp(PALETTE.bg_light, 0.12)

	for gy in range(grid_h):
		for gx in range(grid_w):
			var center = _iso_to_screen(origin, gx, gy, tile_w, tile_h)
			var river_center = river_base + float(gy) * 0.25 + sin(time_elapsed * 0.25 + float(gy) * 0.6) * 0.6
			var dist = abs(float(gx) - river_center)
			var is_water = dist <= 0.7
			var color = ground_color
			if is_water:
				var shimmer = 0.5 + 0.5 * sin(time_elapsed * 1.2 + float(gx) * 1.4 + float(gy))
				color = water_color.lerp(water_high, shimmer)
			else:
				var shade = 0.06 * sin(float(gx) * 1.4 + float(gy) * 1.9)
				color = color.darkened(clampf(-shade, -0.08, 0.08))
			var tile_light = _orb_light_factor(center)
			color = color.lerp(PALETTE.gold_bright, tile_light * 0.2)
			_draw_iso_tile(center, tile_w, tile_h, color)

	_draw_water_surface(origin, tile_w, tile_h, grid_w, grid_h, river_base)
	_draw_water_mist(origin, tile_w, tile_h, grid_w, grid_h, river_base)
	_draw_river_sparkles(origin, tile_w, tile_h, grid_w, grid_h, river_base)
	# Sea removed for now to keep terrain dominant.

func _iso_to_screen(origin: Vector2, gx: int, gy: int, tile_w: float, tile_h: float) -> Vector2:
	var iso_x = (float(gx) - float(gy)) * tile_w * 0.5
	var iso_y = (float(gx) + float(gy)) * tile_h * 0.5
	return origin + Vector2(iso_x, iso_y)

func _draw_iso_tile(center: Vector2, tile_w: float, tile_h: float, color: Color) -> void:
	var p0 = Vector2(center.x, center.y - tile_h * 0.5)
	var p1 = Vector2(center.x + tile_w * 0.5, center.y)
	var p2 = Vector2(center.x, center.y + tile_h * 0.5)
	var p3 = Vector2(center.x - tile_w * 0.5, center.y)
	draw_polygon(PackedVector2Array([p0, p1, p2, p3]), PackedColorArray([color, color, color, color]))

func _draw_sea(viewport_size: Vector2) -> void:
	var sea_top = viewport_size.y * 0.56
	var sea_left = viewport_size.x * 0.0
	var sea_rect = Rect2(sea_left, sea_top, viewport_size.x - sea_left, viewport_size.y - sea_top)
	var deep = Color(0.08, 0.18, 0.32, 0.9)
	var bright = Color(0.18, 0.34, 0.52, 0.95)
	draw_rect(sea_rect, deep)
	draw_rect(Rect2(sea_left, sea_top, sea_rect.size.x, sea_rect.size.y * 0.35), bright)
	_draw_water_reflection(sea_rect)
	_draw_water_ripples(sea_rect)
	_draw_sea_mist(sea_rect)

func _draw_water_surface(origin: Vector2, tile_w: float, tile_h: float, grid_w: int, grid_h: int, river_base: float) -> void:
	var surface_color = Color(0.60, 0.78, 0.92, 0.28)
	for gy in range(grid_h):
		var river_center = river_base + float(gy) * 0.25 + sin(time_elapsed * 0.25 + float(gy) * 0.6) * 0.6
		for gx in range(grid_w):
			var dist = abs(float(gx) - river_center)
			if dist > 0.9:
				continue
			var center = _iso_to_screen(origin, gx, gy, tile_w, tile_h)
			var ripple = 0.5 + 0.5 * sin(time_elapsed * 3.0 + float(gx) * 1.7 + float(gy) * 1.1)
			var alpha = surface_color.a * (0.6 + 0.4 * ripple)
			var shimmer = surface_color
			shimmer.a = alpha
			var p0 = Vector2(center.x, center.y - tile_h * 0.22)
			var p1 = Vector2(center.x + tile_w * 0.22, center.y)
			var p2 = Vector2(center.x, center.y + tile_h * 0.22)
			var p3 = Vector2(center.x - tile_w * 0.22, center.y)
			draw_polygon(PackedVector2Array([p0, p1, p2, p3]), PackedColorArray([shimmer, shimmer, shimmer, shimmer]))

func _draw_water_mist(origin: Vector2, tile_w: float, tile_h: float, grid_w: int, grid_h: int, river_base: float) -> void:
	var mist_color = Color(0.72, 0.82, 0.95, 0.12)
	for gy in range(grid_h):
		var river_center = river_base + float(gy) * 0.25 + sin(time_elapsed * 0.25 + float(gy) * 0.6) * 0.6
		for gx in range(grid_w):
			var dist = abs(float(gx) - river_center)
			if dist > 0.8:
				continue
			var center = _iso_to_screen(origin, gx, gy, tile_w, tile_h)
			var drift = sin(time_elapsed * 0.7 + float(gx) * 0.9 + float(gy) * 1.2) * 2.0
			var alpha = mist_color.a * (0.6 + 0.4 * sin(time_elapsed * 1.1 + float(gx)))
			var color = mist_color
			color.a = alpha
			var w = tile_w * 0.45
			var h = tile_h * 0.18
			draw_rect(Rect2(center.x - w * 0.5, center.y - h * 0.5 + drift, w, h), color)

func _draw_river_sparkles(origin: Vector2, tile_w: float, tile_h: float, _grid_w: int, grid_h: int, river_base: float) -> void:
	var sparkle_color = Color(0.92, 0.98, 1.0, 0.6)
	var count = 14
	for i in range(count):
		var gy = i % grid_h
		var river_center = river_base + float(gy) * 0.25 + sin(time_elapsed * 0.25 + float(gy) * 0.6) * 0.6
		var gx = int(round(river_center))
		var center = _iso_to_screen(origin, gx, gy, tile_w, tile_h)
		var jitter = sin(time_elapsed * 2.2 + float(i) * 1.7) * 3.0
		var flicker = 0.3 + 0.7 * sin(time_elapsed * 3.1 + float(i))
		var color = sparkle_color
		color.a *= flicker
		draw_rect(Rect2(center.x - 1 + jitter, center.y - 1, 2, 2), color)

func _draw_water_reflection(sea_rect: Rect2) -> void:
	var band_count = 6
	for i in range(band_count):
		var t = float(i) / float(band_count - 1)
		var band_h = sea_rect.size.y / float(band_count)
		var y = sea_rect.position.y + t * (sea_rect.size.y - band_h)
		var wave = 0.5 + 0.5 * sin(time_elapsed * 1.4 + t * 2.6)
		var color = sky_horizon_color.lerp(PALETTE.bg_mid, 0.35)
		color.a = 0.22 * (1.0 - t) * (0.7 + 0.3 * wave)
		var segments = 10
		var seg_w = sea_rect.size.x / float(segments)
		for s in range(segments):
			var offset = sin(time_elapsed * 1.1 + float(s) * 0.9 + t * 3.0) * 3.0
			var x = sea_rect.position.x + float(s) * seg_w + offset
			draw_rect(Rect2(x, y, seg_w + 1, band_h), color)

func _draw_water_ripples(sea_rect: Rect2) -> void:
	var lines = 7
	for i in range(lines):
		var phase = time_elapsed * 1.6 + float(i) * 0.9
		var y = sea_rect.position.y + 10 + i * 12 + sin(phase) * 2.2
		var alpha = 0.18 + 0.08 * sin(phase * 1.3)
		var wave = Color(0.72, 0.85, 0.96, alpha)
		draw_rect(Rect2(sea_rect.position.x + 10, y, sea_rect.size.x - 20, 2), wave)

func _draw_sea_mist(sea_rect: Rect2) -> void:
	var mist_color = Color(0.70, 0.82, 0.95, 0.12)
	var band_h = 18.0
	for i in range(3):
		var drift = sin(time_elapsed * 0.7 + float(i) * 2.1) * 4.0
		var alpha = mist_color.a * (0.7 + 0.3 * sin(time_elapsed * 1.2 + float(i)))
		var color = mist_color
		color.a = alpha
		var y = sea_rect.position.y + 8 + i * (band_h + 4) + drift
		draw_rect(Rect2(sea_rect.position.x + 6, y, sea_rect.size.x - 12, band_h), color)

func _orb_light_factor(pos: Vector2) -> float:
	if orb_light_pos == Vector2.ZERO:
		return 0.0
	var viewport_size = get_viewport_rect().size
	var radius = viewport_size.y * 0.85
	var dist = pos.distance_to(orb_light_pos)
	var falloff = clampf(1.0 - dist / radius, 0.0, 1.0)
	return falloff * orb_light_strength

func _draw_tree(base_pos: Vector2, width: float, height: float, color: Color) -> void:
	var px = PIXEL_SIZE
	var rows = max(1, int(height / px))
	var top_y = base_pos.y - height
	for row in range(rows):
		var t = float(row) / max(1, rows - 1)
		var row_width = lerp(width * 0.2, width, t)
		row_width = max(px, round(row_width / px) * px)
		var x = base_pos.x - row_width * 0.5
		var y = top_y + row * px
		draw_rect(Rect2(x, y, row_width, px + 1), color)
	var trunk_w = max(px, round(width * 0.2 / px) * px)
	var trunk_h = max(px, round(height * 0.2 / px) * px)
	draw_rect(Rect2(base_pos.x - trunk_w * 0.5, base_pos.y - trunk_h, trunk_w, trunk_h + 1), color.darkened(0.2))

func _draw_ground_base(viewport_size: Vector2) -> void:
	var horizon = viewport_size.y * 0.52
	var sea_line = viewport_size.y * 0.72
	var light = _orb_light_factor(Vector2(viewport_size.x * 0.5, horizon))

	# === DISTANT HILLS (silhouettes) ===
	_draw_distant_hills(viewport_size, horizon, light)

	# === MIDGROUND - Coastal meadow ===
	var meadow_color = _season_ground_color()
	meadow_color = meadow_color.lerp(PALETTE.gold_bright, light * 0.15)
	_draw_smooth_terrain(viewport_size, horizon + 20, sea_line - 30, meadow_color, 0.6)

	# === FOREGROUND - Beach/rocks ===
	var sand_color = _season_sand_color()
	sand_color = sand_color.lerp(PALETTE.gold_bright, light * 0.1)
	_draw_beach_strip(viewport_size, sea_line - 30, sea_line, sand_color)

	# === SEA ===
	_draw_stylized_sea(viewport_size, sea_line)

	# === DECORATIVE ELEMENTS ===
	_draw_coastal_details(viewport_size, horizon, sea_line, light)

func _draw_distant_hills(viewport_size: Vector2, base_y: float, light: float) -> void:
	# Layer 1 - Far mountains (very faded)
	var far_color = sky_horizon_color.lerp(season_tint, 0.3)
	far_color = far_color.lerp(PALETTE.gold_bright, light * 0.05)
	far_color.a = 0.6
	_draw_hill_silhouette(viewport_size, base_y - 60, 45, far_color, 0.008, 0.0)

	# Layer 2 - Mid hills
	var mid_color = _season_ground_color().darkened(0.25)
	mid_color = mid_color.lerp(PALETTE.gold_bright, light * 0.08)
	mid_color.a = 0.75
	_draw_hill_silhouette(viewport_size, base_y - 25, 35, mid_color, 0.012, 0.3)

	# Layer 3 - Near hills
	var near_color = _season_ground_color().darkened(0.1)
	near_color = near_color.lerp(PALETTE.gold_bright, light * 0.12)
	_draw_hill_silhouette(viewport_size, base_y, 25, near_color, 0.018, 0.7)

func _draw_hill_silhouette(viewport_size: Vector2, base_y: float, amplitude: float, color: Color, freq: float, phase: float) -> void:
	var points := PackedVector2Array()
	points.append(Vector2(0, viewport_size.y))

	var step = 8.0
	var x = 0.0
	while x <= viewport_size.x:
		var noise1 = sin(x * freq + phase + time_elapsed * 0.02) * amplitude
		var noise2 = sin(x * freq * 2.3 + phase * 1.7) * amplitude * 0.4
		var y = base_y - noise1 - noise2
		points.append(Vector2(x, y))
		x += step

	points.append(Vector2(viewport_size.x, viewport_size.y))
	draw_polygon(points, PackedColorArray([color]))

func _draw_smooth_terrain(viewport_size: Vector2, top_y: float, bottom_y: float, color: Color, variation: float) -> void:
	# Gradient fill with subtle noise
	var steps = 8
	var step_h = (bottom_y - top_y) / steps
	for i in range(steps):
		var y = top_y + i * step_h
		var t = float(i) / steps
		var row_color = color.lerp(color.darkened(0.15), t * variation)
		draw_rect(Rect2(0, y, viewport_size.x, step_h + 1), row_color)

	# Subtle grass texture dots
	var px = 3.0
	for s in ground_speckles:
		if s.pos.y >= top_y and s.pos.y <= bottom_y:
			var c = s.color
			c.a = 0.4
			draw_rect(Rect2(s.pos.x, s.pos.y, px, px), c)

func _draw_beach_strip(viewport_size: Vector2, top_y: float, bottom_y: float, color: Color) -> void:
	# Soft gradient beach
	var steps = 4
	var step_h = (bottom_y - top_y) / steps
	for i in range(steps):
		var y = top_y + i * step_h
		var t = float(i) / steps
		var row_color = color.lerp(color.lightened(0.1), t * 0.5)
		draw_rect(Rect2(0, y, viewport_size.x, step_h + 1), row_color)

func _draw_stylized_sea(viewport_size: Vector2, sea_top: float) -> void:
	var sea_color = _get_sea_color()
	var sea_height = viewport_size.y - sea_top

	# Base sea with gradient
	for i in range(6):
		var t = float(i) / 6.0
		var y = sea_top + t * sea_height
		var h = sea_height / 6.0 + 1
		var row_color = sea_color.lerp(sea_color.darkened(0.3), t)
		draw_rect(Rect2(0, y, viewport_size.x, h), row_color)

	# Elegant wave lines
	var wave_color = sea_color.lightened(0.25)
	wave_color.a = 0.5
	for i in range(4):
		var wave_y = sea_top + 8 + i * 18 + sin(time_elapsed * 0.8 + i * 1.2) * 3
		var points := PackedVector2Array()
		var x = 0.0
		while x <= viewport_size.x:
			var wave_offset = sin(x * 0.015 + time_elapsed * 1.5 + i * 0.8) * 4
			points.append(Vector2(x, wave_y + wave_offset))
			x += 6.0
		if points.size() > 1:
			var line_color = wave_color
			line_color.a = 0.3 + 0.15 * sin(time_elapsed + i)
			draw_polyline(points, line_color, 1.5, true)

	# Foam line at shore
	var foam_y = sea_top + sin(time_elapsed * 1.8) * 2
	var foam_color = Color(1.0, 1.0, 1.0, 0.6)
	draw_line(Vector2(0, foam_y), Vector2(viewport_size.x, foam_y + sin(time_elapsed) * 1.5), foam_color, 2.0, true)

func _draw_coastal_details(viewport_size: Vector2, horizon: float, sea_line: float, light: float) -> void:
	# Small lighthouse silhouette on the right
	var lh_x = viewport_size.x * 0.88
	var lh_y = horizon + 30
	var lh_color = _season_ground_color().darkened(0.2)
	lh_color = lh_color.lerp(PALETTE.gold_bright, light * 0.1)

	# Simple lighthouse shape
	draw_rect(Rect2(lh_x, lh_y, 8, 35), lh_color)  # Tower
	draw_rect(Rect2(lh_x - 2, lh_y - 5, 12, 8), lh_color.lightened(0.15))  # Top
	draw_rect(Rect2(lh_x - 4, lh_y + 35, 16, 6), lh_color.darkened(0.1))  # Base

	# Lamp glow
	var lamp_on = sin(time_elapsed * 2.5) > 0.2
	if lamp_on:
		var lamp_color = PALETTE.gold_bright
		lamp_color.a = 0.7 + 0.2 * sin(time_elapsed * 4)
		draw_circle(Vector2(lh_x + 4, lh_y - 2), 4, lamp_color)
		# Glow
		lamp_color.a = 0.2
		draw_circle(Vector2(lh_x + 4, lh_y - 2), 12, lamp_color)

	# Distant boat silhouette
	var boat_x = fposmod(viewport_size.x * 0.3 + time_elapsed * 8, viewport_size.x + 60) - 30
	var boat_y = sea_line + 25 + sin(time_elapsed * 1.5) * 2
	var boat_color = _get_sea_color().darkened(0.3)
	boat_color.a = 0.7
	# Hull
	draw_rect(Rect2(boat_x, boat_y, 20, 5), boat_color)
	# Sail
	var sail_points := PackedVector2Array([
		Vector2(boat_x + 10, boat_y),
		Vector2(boat_x + 10, boat_y - 15),
		Vector2(boat_x + 20, boat_y - 3)
	])
	var sail_color = Color(0.95, 0.92, 0.88, 0.6)
	draw_polygon(sail_points, PackedColorArray([sail_color]))

func _season_sand_color() -> Color:
	match season:
		"winter":
			return Color(0.78, 0.80, 0.85)  # Snowy/icy sand
		"spring":
			return Color(0.82, 0.76, 0.62)  # Wet sand
		"summer":
			return Color(0.92, 0.85, 0.68)  # Warm golden sand
		"autumn":
			return Color(0.85, 0.75, 0.55)  # Autumn sand
		_:
			return Color(0.88, 0.82, 0.65)

func _get_sea_color() -> Color:
	var base_sea: Color
	match season:
		"winter":
			base_sea = Color(0.25, 0.38, 0.52)  # Cold dark sea
		"spring":
			base_sea = Color(0.22, 0.45, 0.58)  # Fresh blue-green
		"summer":
			base_sea = Color(0.18, 0.52, 0.68)  # Bright turquoise
		"autumn":
			base_sea = Color(0.22, 0.42, 0.55)  # Gray-blue
		_:
			base_sea = Color(0.20, 0.45, 0.60)

	# Tint based on time of day
	if night_factor > 0.5:
		base_sea = base_sea.darkened(0.25 * night_factor)
	return base_sea

func _draw_scene_icons(_viewport_size: Vector2) -> void:
	var tree_slide = (1.0 - tree_intro_alpha) * 60.0
	var cabin_slide = (1.0 - cabin_intro_alpha) * 60.0
	var tree_pos = tree_draw_pos + Vector2(0, tree_slide)
	var cabin_pos = cabin_draw_pos + Vector2(0, cabin_slide)

	if tree_texture != null and cabin_texture != null and tree_render_size != Vector2.ZERO:
		var tree_scale_factor = 0.7 + 0.35 * tree_intro_alpha
		var cabin_scale_factor = 0.7 + 0.35 * cabin_intro_alpha
		var tree_size = tree_render_size * tree_scale_factor
		var cabin_size = cabin_render_size * cabin_scale_factor
		var tree_draw = tree_pos + (tree_render_size - tree_size) * 0.5
		var cabin_draw = cabin_pos + (cabin_render_size - cabin_size) * 0.5
		draw_texture_rect(tree_texture, Rect2(tree_draw, tree_size), false, Color(1, 1, 1, tree_intro_alpha))
		draw_texture_rect(cabin_texture, Rect2(cabin_draw, cabin_size), false, Color(1, 1, 1, cabin_intro_alpha))
		_draw_cabin_snow(cabin_draw, 0, cabin_size)
		_draw_cabin_window_glow(cabin_draw, cabin_size)
		return

	var tree_scale_px = 6
	var cabin_scale_px = 6
	var leaf_color = _season_leaf_color()
	leaf_color = leaf_color.lerp(PALETTE.gold_bright, 0.08 + 0.04 * sin(time_elapsed * 2.0))
	leaf_color.a = tree_intro_alpha
	var trunk_color = PALETTE.wood_dark
	trunk_color.a = tree_intro_alpha
	_draw_pixel_art(TREE_ART, tree_pos, tree_scale_px, {"L": leaf_color, "T": trunk_color})

	var roof_color = PALETTE.gold_dark
	var wall_color = PALETTE.bg_light
	var door_color = PALETTE.wood
	var flicker = 0.2 + 0.25 * sin(time_elapsed * 3.2) + 0.05 * sin(time_elapsed * 11.0)
	var window_color = PALETTE.gold_bright.lerp(PALETTE.blue, flicker)
	roof_color.a = cabin_intro_alpha
	wall_color.a = cabin_intro_alpha
	door_color.a = cabin_intro_alpha
	window_color.a = cabin_intro_alpha
	_draw_pixel_art(CABIN_ART, cabin_pos, cabin_scale_px, {"R": roof_color, "W": wall_color, "D": door_color, "O": window_color, "C": roof_color})
	_draw_cabin_snow(cabin_pos, cabin_scale_px)

func _draw_pixel_art(art: Array, origin: Vector2, scale_px: int, palette: Dictionary) -> void:
	for y in range(art.size()):
		var row: String = art[y]
		for x in range(row.length()):
			var ch = row.substr(x, 1)
			if ch == ".":
				continue
			if not palette.has(ch):
				continue
			var color: Color = palette[ch]
			var px = float(scale_px)
			var pos = origin + Vector2(x * px, y * px)
			draw_rect(Rect2(pos.x, pos.y, px, px), color)

func _art_width(art: Array) -> int:
	var max_len = 0
	for row in art:
		max_len = max(max_len, row.length())
	return max_len

func _season_leaf_color() -> Color:
	match season:
		"winter":
			return Color(0.85, 0.9, 0.95)
		"spring":
			return Color(0.48, 0.82, 0.54)
		"summer":
			return Color(0.78, 0.78, 0.4)
		"autumn":
			return Color(0.92, 0.56, 0.26)
		_:
			return PALETTE.green

func _cabin_chimney_pos() -> Vector2:
	if cabin_chimney_pos != Vector2.ZERO:
		return cabin_chimney_pos
	var cabin_scale = 6
	var cabin_width = _art_width(CABIN_ART) * cabin_scale
	var chimney_offset = Vector2(cabin_width * 0.35, 10)
	return cabin_draw_pos + chimney_offset

func _update_scene_anchors(viewport_size: Vector2) -> void:
	if viewport_size.x <= 0:
		return
	var ground_top = viewport_size.y * 0.74
	if tree_texture != null and cabin_texture != null:
		var tree_scale_tex = (viewport_size.y * 0.58) / max(1.0, tree_texture.get_size().y)
		var cabin_scale_tex = (viewport_size.y * 0.42) / max(1.0, cabin_texture.get_size().y)
		tree_render_size = tree_texture.get_size() * tree_scale_tex
		cabin_render_size = cabin_texture.get_size() * cabin_scale_tex
		tree_draw_pos = Vector2(viewport_size.x * 0.12 - tree_render_size.x * 0.5, ground_top - tree_render_size.y + 4)
		cabin_draw_pos = Vector2(viewport_size.x * 0.88 - cabin_render_size.x * 0.5, ground_top - cabin_render_size.y + 6)
		tree_anchor = tree_draw_pos + Vector2(tree_render_size.x * 0.5, tree_render_size.y * 0.45)
		cabin_anchor = cabin_draw_pos + Vector2(cabin_render_size.x * 0.5, cabin_render_size.y * 0.55)
		cabin_chimney_pos = cabin_draw_pos + Vector2(cabin_render_size.x * 0.22, cabin_render_size.y * 0.1)
		return

	var tree_scale_px = 6
	var cabin_scale_px = 6
	var tree_width = _art_width(TREE_ART) * tree_scale_px
	var tree_height = TREE_ART.size() * tree_scale_px
	var cabin_width = _art_width(CABIN_ART) * cabin_scale_px
	var cabin_height = CABIN_ART.size() * cabin_scale_px
	tree_draw_pos = Vector2(viewport_size.x * 0.14 - tree_width * 0.5, ground_top - tree_height + 6)
	cabin_draw_pos = Vector2(viewport_size.x * 0.86 - cabin_width * 0.5, ground_top - cabin_height + 8)
	tree_anchor = tree_draw_pos + Vector2(tree_width * 0.5, tree_height * 0.35)
	cabin_anchor = cabin_draw_pos + Vector2(cabin_width * 0.35, cabin_height * 0.2)

func _init_particles() -> void:
	particles.clear()
	for i in range(120):
		particles.append({
			"pos": Vector2(randi() % 1200, randi() % 800),
			"vel": Vector2(randf_range(-12, 12), randf_range(-20, -8)),
			"size": randf_range(1, 3),
			"alpha": randf_range(0.2, 0.7),
			"color": i % 3,
			"seed": randf_range(0, 10),
		})

func _update_particles(delta: float) -> void:
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0:
		return
	for p in particles:
		p.pos += p.vel * delta
		if p.pos.y < -20:
			p.pos.y = viewport_size.y + 20
			p.pos.x = randf_range(0, viewport_size.x)
		if p.pos.x < -20:
			p.pos.x = viewport_size.x + 20
		elif p.pos.x > viewport_size.x + 20:
			p.pos.x = -20

func _draw_particles() -> void:
	for p in particles:
		var color = PALETTE.gold_bright
		if p.color == 1:
			color = PALETTE.green
		elif p.color == 2:
			color = PALETTE.blue
		color.a = p.alpha
		var pos = p.pos
		pos.x = round(pos.x / PIXEL_SIZE) * PIXEL_SIZE
		pos.y = round(pos.y / PIXEL_SIZE) * PIXEL_SIZE
		draw_rect(Rect2(pos.x, pos.y, p.size, p.size), color)

func _update_season_and_weather(now: Dictionary) -> void:
	var new_season = _season_from_date(now)
	if new_season != season:
		season = new_season
		season_tint = _season_tint_color(season)
		_build_landscape(get_viewport_rect().size)
		_init_weather_particles()

	var bucket = int(now.hour) * 60 + int(now.minute)
	var weather_bucket = int(floor(bucket / 15.0))
	if weather_bucket != _last_weather_bucket:
		_last_weather_bucket = weather_bucket
		weather_state = _roll_weather()
		_init_weather_particles()

func _season_from_date(now: Dictionary) -> String:
	var m = int(now.month)
	if m == 12 or m <= 2:
		return "winter"
	if m <= 5:
		return "spring"
	if m <= 8:
		return "summer"
	return "autumn"

func _season_tint_color(season_name: String) -> Color:
	match season_name:
		"winter":
			return Color(0.75, 0.86, 1.0)
		"spring":
			return Color(0.78, 0.95, 0.82)
		"summer":
			return Color(1.0, 0.92, 0.75)
		"autumn":
			return Color(0.95, 0.78, 0.6)
		_:
			return Color(1, 1, 1)

func _roll_weather() -> String:
	var roll = weather_rng.randf()
	match season:
		"winter":
			if roll < 0.65:
				return "snow"
			if roll < 0.85:
				return "mist"
			return "clear"
		"spring":
			if roll < 0.35:
				return "rain"
			if roll < 0.6:
				return "mist"
			return "clear"
		"summer":
			if roll < 0.2:
				return "storm"
			if roll < 0.3:
				return "rain"
			return "clear"
		"autumn":
			if roll < 0.4:
				return "rain"
			if roll < 0.6:
				return "mist"
			return "clear"
	return "clear"

func _init_weather_particles() -> void:
	weather_particles.clear()
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0:
		return
	var count = 0
	match weather_state:
		"snow":
			count = 140
		"rain", "storm":
			count = 120
		"mist":
			count = 60
		_:
			count = 0
	for i in range(count):
		var particle_size = randf_range(1.0, 2.0)
		var vel = Vector2(randf_range(-6, 6), randf_range(16, 40))
		if weather_state == "rain" or weather_state == "storm":
			particle_size = randf_range(1.0, 2.5)
			vel = Vector2(randf_range(-10, 10), randf_range(80, 140))
		if weather_state == "mist":
			particle_size = randf_range(2.0, 4.0)
			vel = Vector2(randf_range(-4, 4), randf_range(8, 16))
		weather_particles.append({
			"pos": Vector2(randf_range(0, viewport_size.x), randf_range(0, viewport_size.y)),
			"vel": vel,
			"size": particle_size,
			"alpha": randf_range(0.25, 0.8),
		})

func _update_weather_particles(delta: float) -> void:
	if weather_particles.is_empty():
		return
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0:
		return
	for p in weather_particles:
		p.pos += p.vel * delta
		if p.pos.y > viewport_size.y + 10:
			p.pos.y = -10
			p.pos.x = randf_range(0, viewport_size.x)
		if p.pos.x < -10:
			p.pos.x = viewport_size.x + 10
		elif p.pos.x > viewport_size.x + 10:
			p.pos.x = -10

func _draw_weather() -> void:
	if weather_particles.is_empty():
		return
	var color := PALETTE.cream
	if weather_state == "snow":
		color = Color(0.9, 0.94, 1.0, 0.8)
	elif weather_state == "mist":
		color = Color(0.7, 0.8, 0.9, 0.4)
	elif weather_state == "rain" or weather_state == "storm":
		color = Color(0.6, 0.7, 0.9, 0.7)
	for p in weather_particles:
		var pos = p.pos
		pos.x = round(pos.x / PIXEL_SIZE) * PIXEL_SIZE
		pos.y = round(pos.y / PIXEL_SIZE) * PIXEL_SIZE
		color.a = p.alpha * (0.6 if weather_state == "mist" else 0.9)
		if weather_state == "rain" or weather_state == "storm":
			draw_rect(Rect2(pos.x, pos.y, 1.0, p.size * 3.0), color)
		else:
			draw_rect(Rect2(pos.x, pos.y, p.size, p.size), color)

func _init_cursor_particles() -> void:
	cursor_trail.clear()
	cursor_magic_particles.clear()
	for i in range(14):
		cursor_magic_particles.append({
			"angle": randf_range(0, TAU),
			"distance": randf_range(10, 26),
			"size": randf_range(2, 4),
			"alpha": randf_range(0.4, 0.9),
		})

func _init_magic_particles() -> void:
	tree_magic_particles.clear()
	for i in range(24):
		tree_magic_particles.append({
			"angle": randf_range(0, TAU),
			"radius": randf_range(18, 42),
			"speed": randf_range(0.6, 1.4),
			"size": randf_range(2, 4),
			"alpha": randf_range(0.4, 0.9),
		})

func _init_smoke_particles() -> void:
	smoke_particles.clear()
	for i in range(12):
		_spawn_smoke_particle()

func _init_fireflies() -> void:
	firefly_particles.clear()
	for i in range(26):
		firefly_particles.append({
			"pos": cabin_anchor + Vector2(randf_range(-60, 60), randf_range(-40, 20)),
			"vel": Vector2(randf_range(-10, 10), randf_range(-6, 6)),
			"size": randf_range(1.5, 3.0),
			"alpha": randf_range(0.3, 0.9),
			"phase": randf_range(0, TAU),
		})

func _update_cursor(delta: float) -> void:
	cursor_trail.push_front({"pos": mouse_pos, "size": 6.0})
	if cursor_trail.size() > 18:
		cursor_trail.pop_back()
	for p in cursor_magic_particles:
		p.angle += delta * 1.4

func _update_magic_particles(delta: float) -> void:
	for p in tree_magic_particles:
		p.angle += delta * p.speed * 1.4

func _update_smoke_particles(delta: float) -> void:
	for p in smoke_particles:
		p.pos += p.vel * delta
		p.alpha -= delta * 0.12
		p.size += delta * 0.8
		if p.alpha <= 0.05 or p.pos.y < -20:
			_reset_smoke_particle(p)

func _update_fireflies(delta: float) -> void:
	if cabin_anchor == Vector2.ZERO:
		return
	for p in firefly_particles:
		p.phase += delta * 2.0
		p.pos += p.vel * delta
		if p.pos.x < cabin_anchor.x - 90:
			p.pos.x = cabin_anchor.x + 90
		elif p.pos.x > cabin_anchor.x + 90:
			p.pos.x = cabin_anchor.x - 90
		if p.pos.y < cabin_anchor.y - 70:
			p.pos.y = cabin_anchor.y + 40
		elif p.pos.y > cabin_anchor.y + 40:
			p.pos.y = cabin_anchor.y - 70

func _spawn_smoke_particle() -> void:
	var p = {
		"pos": _cabin_chimney_pos(),
		"vel": Vector2(randf_range(-6, 6), randf_range(-18, -28)),
		"size": randf_range(3.0, 5.0),
		"alpha": randf_range(0.35, 0.6),
	}
	smoke_particles.append(p)

func _reset_smoke_particle(p: Dictionary) -> void:
	p.pos = _cabin_chimney_pos()
	p.vel = Vector2(randf_range(-6, 6), randf_range(-18, -28))
	p.size = randf_range(3.0, 5.0)
	p.alpha = randf_range(0.35, 0.6)

func _draw_cursor() -> void:
	for i in range(cursor_trail.size()):
		var t = 1.0 - float(i) / cursor_trail.size()
		var pos = cursor_trail[i].pos
		pos.x = round(pos.x / PIXEL_SIZE) * PIXEL_SIZE
		pos.y = round(pos.y / PIXEL_SIZE) * PIXEL_SIZE
		var trail_size = cursor_trail[i].size * t
		var color = PALETTE.gold_bright
		color.a = 0.5 * t
		draw_rect(Rect2(pos.x - trail_size * 0.5, pos.y - trail_size * 0.5, trail_size, trail_size), color)

	for p in cursor_magic_particles:
		var orbit = mouse_pos + Vector2(cos(p.angle), sin(p.angle)) * p.distance
		orbit.x = round(orbit.x / PIXEL_SIZE) * PIXEL_SIZE
		orbit.y = round(orbit.y / PIXEL_SIZE) * PIXEL_SIZE
		var c = PALETTE.blue.lerp(PALETTE.gold_bright, 0.5)
		c.a = p.alpha * 0.8
		draw_rect(Rect2(orbit.x, orbit.y, p.size, p.size), c)

func _draw_smoke() -> void:
	if smoke_particles.is_empty():
		return
	if cabin_intro_alpha <= 0.02:
		return
	for p in smoke_particles:
		var pos = p.pos
		pos.x = round(pos.x / 2.0) * 2.0
		pos.y = round(pos.y / 2.0) * 2.0
		var color = Color(0.75, 0.78, 0.85, p.alpha * cabin_intro_alpha)
		draw_rect(Rect2(pos.x - p.size * 0.5, pos.y - p.size * 0.5, p.size, p.size), color)

func _draw_tree_magic() -> void:
	if tree_intro_alpha <= 0.02:
		return
	for p in tree_magic_particles:
		var radius = p.radius + sin(time_elapsed * 1.6 + p.angle) * 3.0
		var pos = tree_anchor + Vector2(cos(p.angle), sin(p.angle)) * radius
		pos.x = round(pos.x / 2.0) * 2.0
		pos.y = round(pos.y / 2.0) * 2.0
		var color = PALETTE.gold_bright.lerp(PALETTE.blue, 0.4)
		color.a = p.alpha * (0.5 + 0.5 * sin(time_elapsed * 2.4 + p.angle)) * tree_intro_alpha
		draw_rect(Rect2(pos.x - p.size * 0.5, pos.y - p.size * 0.5, p.size, p.size), color)

func _draw_tree_ground_glow() -> void:
	if tree_intro_alpha <= 0.02:
		return
	var glow_w = 180.0
	var glow_h = 36.0
	if tree_render_size != Vector2.ZERO:
		glow_w = max(180.0, tree_render_size.x * 0.7)
		glow_h = max(28.0, tree_render_size.y * 0.08)
	var glow_size = Vector2(glow_w, glow_h)
	var pos = tree_anchor + Vector2(-glow_size.x * 0.5, 22)
	var color = PALETTE.green.lerp(PALETTE.gold_bright, 0.3)
	color.a = (0.18 + 0.08 * sin(time_elapsed * 2.0)) * tree_intro_alpha
	draw_rect(Rect2(pos, glow_size), color)

func _draw_fireflies() -> void:
	if cabin_intro_alpha <= 0.02:
		return
	for p in firefly_particles:
		var pos = p.pos
		pos.x = round(pos.x / 2.0) * 2.0
		pos.y = round(pos.y / 2.0) * 2.0
		var color = PALETTE.gold_bright.lerp(PALETTE.green, 0.4)
		color.a = p.alpha * (0.4 + 0.6 * sin(p.phase)) * cabin_intro_alpha
		draw_rect(Rect2(pos.x, pos.y, p.size, p.size), color)

func _draw_cabin_snow(cabin_pos: Vector2, cabin_scale: int, cabin_size: Vector2 = Vector2.ZERO) -> void:
	if season != "winter":
		return
	if cabin_intro_alpha <= 0.02:
		return
	if cabin_size != Vector2.ZERO:
		var snow_y_tex = cabin_pos.y + cabin_size.y * 0.12
		var snow_w = cabin_size.x * 0.6
		draw_rect(Rect2(cabin_pos.x + cabin_size.x * 0.2, snow_y_tex, snow_w, cabin_size.y * 0.06), Color(0.94, 0.97, 1.0, 0.9 * cabin_intro_alpha))
		return
	var roof_width = _art_width(CABIN_ART) * cabin_scale
	var snow_y_px = cabin_pos.y + cabin_scale * 2
	var snow_count = int(ceil(float(roof_width) / float(cabin_scale * 2)))
	for i in range(snow_count):
		var x = cabin_pos.x + i * cabin_scale * 2
		draw_rect(Rect2(x, snow_y_px, cabin_scale, cabin_scale), Color(0.94, 0.97, 1.0, 0.9 * cabin_intro_alpha))

func _draw_cabin_window_glow(cabin_pos: Vector2, cabin_size: Vector2) -> void:
	var glow = PALETTE.gold_bright
	glow.a = (0.25 + 0.15 * sin(time_elapsed * 3.2)) * cabin_intro_alpha
	var glow_pos = cabin_pos + Vector2(cabin_size.x * 0.55, cabin_size.y * 0.55)
	draw_rect(Rect2(glow_pos.x - 10, glow_pos.y - 10, 20, 20), glow)

func _draw_clock() -> void:
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0:
		return

	# Horloge agrandie
	var panel_size = Vector2(280, 200)
	var margin = Vector2(25, 25)
	var pos = Vector2(margin.x, viewport_size.y - panel_size.y - margin.y - 30)
	clock_rect = Rect2(pos, panel_size)

	# Fond semi-transparent avec bordure dorÃ©e
	draw_rect(clock_rect, Color(0.04, 0.05, 0.08, 0.85))
	draw_rect(clock_rect, PALETTE.gold_dark, false, 2.0)

	# Horloge vintage agrandie
	var clock_center = pos + Vector2(panel_size.x * 0.5, 95)
	var clock_radius = 65.0

	# Cercle principal avec glow
	for i in range(3):
		var glow_r = clock_radius + float(3 - i) * 4.0
		var glow_a = 0.08 * (1.0 - float(i) * 0.25)
		draw_circle(clock_center, glow_r, Color(0.4, 0.55, 0.9, glow_a))

	draw_circle(clock_center, clock_radius, Color(0.06, 0.08, 0.12, 0.95))
	draw_arc(clock_center, clock_radius, 0.0, TAU, 32, PALETTE.gold, 3.0, false)
	draw_circle(clock_center, clock_radius - 4.0, Color(0, 0, 0, 0.3))

	# Marques des heures (toutes les heures)
	for i in range(12):
		var mark_angle = -PI / 2 + i * (TAU / 12.0)
		var is_main = (i % 3 == 0)
		var mark_len = 10.0 if is_main else 5.0
		var mark_inner = clock_center + Vector2(cos(mark_angle), sin(mark_angle)) * (clock_radius - mark_len - 4)
		var mark_outer = clock_center + Vector2(cos(mark_angle), sin(mark_angle)) * (clock_radius - 4)
		var mark_color = PALETTE.gold_bright if is_main else PALETTE.gold
		var mark_width = 3.0 if is_main else 1.5
		draw_line(mark_inner, mark_outer, mark_color, mark_width)

	# Aiguilles
	var now = Time.get_datetime_dict_from_system()
	var hour = int(now.hour) % 12
	var minute = int(now.minute)
	var second = int(now.second)
	var hour_angle = -PI / 2 + (float(hour) + float(minute) / 60.0) / 12.0 * TAU
	var minute_angle = -PI / 2 + (float(minute) + float(second) / 60.0) / 60.0 * TAU
	var second_angle = -PI / 2 + float(second) / 60.0 * TAU
	_draw_hand(clock_center, hour_angle, 32.0, PALETTE.cream)
	_draw_hand(clock_center, minute_angle, 48.0, PALETTE.gold_bright)
	_draw_hand(clock_center, second_angle, 55.0, PALETTE.blue)
	draw_circle(clock_center, 5, PALETTE.gold)

	# Date en breton sous l'horloge
	if celtic_font:
		var now_date = Time.get_datetime_dict_from_system()
		var weekday = int(now_date.get("weekday", 0))
		var day = int(now_date.day)
		var month = int(now_date.month)
		var day_name = BRETON_DAYS[clamp(weekday, 0, 6)]
		var month_name = BRETON_MONTHS[clamp(month - 1, 0, 11)]
		var date_text = "%s %d %s" % [day_name, day, month_name]
		var text_y = pos.y + panel_size.y - 25
		draw_string(celtic_font, Vector2(pos.x + panel_size.x * 0.5 - 60, text_y), date_text, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, PALETTE.gold_bright)

	# Indication cliquable
	if celtic_font_thin:
		var hint_text = "Cliquer pour le calendrier"
		var hint_y = pos.y + panel_size.y - 8
		draw_string(celtic_font_thin, Vector2(pos.x + 10, hint_y), hint_text, HORIZONTAL_ALIGNMENT_LEFT, panel_size.x - 20, 11, Color(PALETTE.cream.r, PALETTE.cream.g, PALETTE.cream.b, 0.5))

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# CALENDRIER ANIMÃ‰ - Rendu
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

func _draw_animated_calendar() -> void:
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0:
		return

	var font: Font = celtic_font if celtic_font != null else ThemeDB.fallback_font
	var font_thin = celtic_font_thin if celtic_font_thin else font

	# Animation d'ouverture/fermeture
	var anim_ease = _ease_out_back(calendar_anim_progress)

	# Fond semi-transparent (backdrop)
	var backdrop_alpha = 0.5 * anim_ease
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.02, 0.03, 0.06, backdrop_alpha))

	# Taille AGRANDIE du calendrier
	var cal_width := minf(viewport_size.x * 0.85, 750.0)
	var cal_height := minf(viewport_size.y * 0.85, 620.0)
	var cal_center = viewport_size * 0.5
	var cal_pos = cal_center - Vector2(cal_width, cal_height) * 0.5

	# Appliquer l'animation d'Ã©chelle et de shake
	var scale_factor = anim_ease
	var shake = calendar_shake_offset * (1.0 - calendar_anim_progress)
	cal_pos += shake

	# Si animation pas terminÃ©e, rÃ©duire taille
	if scale_factor < 1.0:
		var scaled_w = cal_width * scale_factor
		var scaled_h = cal_height * scale_factor
		cal_pos = cal_center - Vector2(scaled_w, scaled_h) * 0.5
		cal_width = scaled_w
		cal_height = scaled_h

	# === OMBRE PORTÃ‰E ===
	var shadow_offset = Vector2(8, 12) * scale_factor
	draw_rect(Rect2(cal_pos + shadow_offset, Vector2(cal_width, cal_height)), Color(0, 0, 0, 0.4 * anim_ease))

	# === FOND PAPIER VIEILLI ===
	var paper_color = Color(0.96, 0.93, 0.86)  # Couleur papier jauni
	draw_rect(Rect2(cal_pos, Vector2(cal_width, cal_height)), paper_color)

	# Texture papier (lignes subtiles)
	for i in range(int(cal_height / 3)):
		var line_y = cal_pos.y + i * 3.0
		var line_alpha = 0.03 + 0.02 * sin(i * 0.5)
		draw_line(Vector2(cal_pos.x, line_y), Vector2(cal_pos.x + cal_width, line_y), Color(0.7, 0.65, 0.55, line_alpha))

	# Bords usÃ©s
	_draw_calendar_worn_edges(cal_pos, cal_width, cal_height, anim_ease)

	# === EN-TÃŠTE AVEC MOIS ET NAVIGATION ===
	var header_height := 60.0
	var header_rect = Rect2(cal_pos, Vector2(cal_width, header_height))
	draw_rect(header_rect, Color(0.18, 0.12, 0.08))  # Brun foncÃ© comme une reliure

	# Motif celtique sur l'en-tÃªte
	_draw_calendar_header_pattern(cal_pos, cal_width, header_height, anim_ease)

	# Boutons de navigation
	var btn_size := 40.0
	var btn_margin := 15.0
	calendar_prev_btn_rect = Rect2(cal_pos.x + btn_margin, cal_pos.y + (header_height - btn_size) * 0.5, btn_size, btn_size)
	calendar_next_btn_rect = Rect2(cal_pos.x + cal_width - btn_margin - btn_size, cal_pos.y + (header_height - btn_size) * 0.5, btn_size, btn_size)

	# Dessiner les boutons
	_draw_nav_button(calendar_prev_btn_rect, "<", anim_ease)
	_draw_nav_button(calendar_next_btn_rect, ">", anim_ease)

	# Titre du mois
	if font:
		var month_name = CALENDAR_MONTH_NAMES[clamp(calendar_current_month - 1, 0, 11)]
		var title_text = "%s %d" % [month_name, calendar_current_year]
		var title_pos = Vector2(cal_pos.x + cal_width * 0.5 - 80, cal_pos.y + header_height * 0.65)
		draw_string(font, title_pos, title_text, HORIZONTAL_ALIGNMENT_CENTER, 160, 28, PALETTE.gold_bright)

	# === JOURS DE LA SEMAINE ===
	var days_row_y = cal_pos.y + header_height + 15
	var cell_width = cal_width / 7.0
	if font_thin:
		for i in range(7):
			var day_x = cal_pos.x + i * cell_width + cell_width * 0.5 - 15
			var day_color = PALETTE.ink if i < 5 else Color(0.6, 0.3, 0.2)  # Weekend en rouge-brun
			draw_string(font_thin, Vector2(day_x, days_row_y + 14), CALENDAR_DAY_NAMES[i], HORIZONTAL_ALIGNMENT_CENTER, 30, 14, day_color)

	# Ligne sÃ©paratrice
	draw_line(Vector2(cal_pos.x + 10, days_row_y + 22), Vector2(cal_pos.x + cal_width - 10, days_row_y + 22), Color(0.6, 0.55, 0.45, 0.5), 1.0)

	# === GRILLE DES JOURS (AGRANDIE) ===
	var grid_start_y = days_row_y + 40
	var remaining_height = cal_height - (grid_start_y - cal_pos.y) - 70
	var cell_height: float = remaining_height / 6.0
	var days_in_month = _get_days_in_month(calendar_current_month, calendar_current_year)
	var first_weekday = _get_first_weekday(calendar_current_month, calendar_current_year)

	calendar_day_rects.clear()
	var now = Time.get_datetime_dict_from_system()
	var today = int(now.day)
	var is_current_month = (calendar_current_month == int(now.month) and calendar_current_year == int(now.year))

	var day := 1
	for week in range(6):
		for weekday in range(7):
			var cell_idx = week * 7 + weekday
			var cell_x = cal_pos.x + weekday * cell_width
			var cell_y = grid_start_y + week * cell_height
			var cell_rect = Rect2(cell_x, cell_y, cell_width, cell_height)

			if cell_idx >= first_weekday and day <= days_in_month:
				calendar_day_rects.append(cell_rect)

				# Vérifier événement JSON
				var event_data := _get_event_for_date(calendar_current_year, calendar_current_month, day)
				var has_event := not event_data.is_empty()

				# Fond de la cellule
				var is_today = is_current_month and day == today
				var is_weekend = weekday >= 5
				var is_hovered = calendar_hovered_day == day

				# Fond coloré selon la saison si événement
				if has_event:
					var season_name: String = event_data.get("season", "winter")
					var season_color: Color = SEASON_COLORS.get(season_name, Color(0.5, 0.6, 0.8))
					season_color.a = 0.3
					draw_rect(Rect2(cell_x + 2, cell_y + 2, cell_width - 4, cell_height - 4), season_color)

				if is_today:
					# Jour actuel - cercle dorÃ©
					var circle_center = Vector2(cell_x + cell_width * 0.5, cell_y + cell_height * 0.32)
					draw_circle(circle_center, 24, PALETTE.gold)
					draw_arc(circle_center, 24, 0, TAU, 20, PALETTE.gold_bright, 3.0)
				elif is_hovered:
					# Jour survolÃ©
					draw_rect(Rect2(cell_x + 3, cell_y + 3, cell_width - 6, cell_height - 6), Color(0.95, 0.85, 0.5, 0.4))
					draw_rect(Rect2(cell_x + 3, cell_y + 3, cell_width - 6, cell_height - 6), PALETTE.gold, false, 2.0)

				# NumÃ©ro du jour
				if font_thin:
					var day_str = str(day)
					var day_text_x = cell_x + cell_width * 0.5 - 10
					var day_text_y = cell_y + cell_height * 0.38
					var day_color = PALETTE.cream if is_today else (Color(0.7, 0.35, 0.2) if is_weekend else Color(0.15, 0.12, 0.08))
					var day_size = 24 if is_today else 20
					draw_string(font_thin, Vector2(day_text_x, day_text_y), day_str, HORIZONTAL_ALIGNMENT_CENTER, 28, day_size, day_color)

				# Marqueur d'Ã©vÃ©nement
				if has_event:
					var event_name: String = event_data.get("name", "Evenement")
					var season_name: String = event_data.get("season", "winter")
					var event_color: Color = SEASON_COLORS.get(season_name, PALETTE.gold)
					var marker_pos = Vector2(cell_x + cell_width * 0.5, cell_y + cell_height * 0.58)
					draw_circle(marker_pos, 8, event_color)
					draw_arc(marker_pos, 8, 0, TAU, 12, Color(1, 1, 1, 0.5), 2.0)
					# Petit symbole ou icÃ´ne
					if font_thin:
						var display_name = event_name if event_name.length() <= 14 else event_name.substr(0, 12) + ".."
						var name_y = cell_y + cell_height * 0.82
						draw_string(font_thin, Vector2(cell_x + 4, name_y), display_name, HORIZONTAL_ALIGNMENT_LEFT, cell_width - 8, 11, Color(event_color.r * 0.5, event_color.g * 0.5, event_color.b * 0.5, 1.0))

				day += 1
			else:
				calendar_day_rects.append(Rect2())  # Cellule vide

	# === LÃ‰GENDE DES Ã‰VÃ‰NEMENTS ===
	var legend_y = cal_pos.y + cal_height - 50
	draw_line(Vector2(cal_pos.x + 10, legend_y - 10), Vector2(cal_pos.x + cal_width - 10, legend_y - 10), Color(0.6, 0.55, 0.45, 0.5), 1.0)

	# Afficher les evenements du mois depuis JSON
	if font_thin:
		var legend_x = cal_pos.x + 20
		var events_this_month: Array = []
		for date_key in calendar_events_by_date:
			var parts = date_key.split("-")
			if parts.size() >= 3:
				var ev_year = int(parts[0])
				var ev_month = int(parts[1])
				if ev_year == calendar_current_year and ev_month == calendar_current_month:
					events_this_month.append(calendar_events_by_date[date_key])
		for ev in events_this_month:
			if legend_x > cal_pos.x + cal_width - 140:
				break
			var ev_name: String = ev.get("name", "?")
			var ev_season: String = ev.get("season", "winter")
			var ev_color: Color = SEASON_COLORS.get(ev_season, PALETTE.gold)
			draw_circle(Vector2(legend_x, legend_y + 8), 5, ev_color)
			var short_name = ev_name if ev_name.length() <= 16 else ev_name.substr(0, 14) + ".."
			draw_string(font_thin, Vector2(legend_x + 12, legend_y + 12), short_name, HORIZONTAL_ALIGNMENT_LEFT, 130, 12, Color(0.2, 0.15, 0.1))
			legend_x += 145

	# === PARTICULES DE POUSSIÃˆRE ===
	_draw_calendar_dust(cal_pos, cal_width, cal_height, anim_ease)

	# === EFFET DE PAGE QUI TOURNE ===
	if calendar_page_flip_progress > 0.0 and calendar_page_flip_progress < 1.0:
		_draw_page_flip_effect(cal_pos, cal_width, cal_height)

	# === BORDURE FINALE ===
	draw_rect(Rect2(cal_pos, Vector2(cal_width, cal_height)), PALETTE.gold_dark, false, 2.0)

	# Coins dÃ©coratifs celtiques
	_draw_celtic_corners(cal_pos, cal_width, cal_height, anim_ease)

func _draw_calendar_worn_edges(pos: Vector2, width: float, height: float, alpha: float) -> void:
	# Effet de bords usÃ©s/pliÃ©s
	var worn_color = Color(0.7, 0.65, 0.55, 0.15 * alpha)
	# Coin supÃ©rieur droit pliÃ©
	var fold_size := 25.0
	var fold_points := PackedVector2Array([
		Vector2(pos.x + width - fold_size, pos.y),
		Vector2(pos.x + width, pos.y),
		Vector2(pos.x + width, pos.y + fold_size)
	])
	draw_colored_polygon(fold_points, Color(0.85, 0.80, 0.70))
	draw_polyline(fold_points, Color(0.5, 0.45, 0.35, 0.5), 1.0)

func _draw_calendar_header_pattern(pos: Vector2, width: float, height: float, alpha: float) -> void:
	# Motif de nÅ“uds celtiques simplifiÃ©s sur l'en-tÃªte
	var pattern_color = PALETTE.gold_dark
	pattern_color.a = 0.3 * alpha
	var spacing := 30.0
	for i in range(int(width / spacing)):
		var x = pos.x + i * spacing + 15
		var y = pos.y + height * 0.5
		# Petits losanges
		var diamond := PackedVector2Array([
			Vector2(x, y - 8),
			Vector2(x + 6, y),
			Vector2(x, y + 8),
			Vector2(x - 6, y)
		])
		draw_colored_polygon(diamond, pattern_color)

func _draw_nav_button(rect: Rect2, symbol: String, alpha: float) -> void:
	var is_hovered = rect.has_point(mouse_pos)
	var bg_color = PALETTE.gold if is_hovered else PALETTE.gold_dark
	bg_color.a = alpha

	# Fond du bouton
	draw_rect(rect, bg_color)
	draw_rect(rect, PALETTE.gold_bright if is_hovered else PALETTE.gold, false, 2.0)

	# Symbole
	if celtic_font:
		var text_pos = rect.position + Vector2(rect.size.x * 0.5 - 6, rect.size.y * 0.65)
		draw_string(celtic_font, text_pos, symbol, HORIZONTAL_ALIGNMENT_CENTER, 20, 24, PALETTE.cream if is_hovered else PALETTE.bg_deep)

func _draw_calendar_dust(pos: Vector2, width: float, height: float, alpha: float) -> void:
	var center = pos + Vector2(width, height) * 0.5
	for particle in calendar_dust_particles:
		if particle.age < particle.lifetime:
			var p_alpha = (1.0 - particle.age / particle.lifetime) * particle.alpha * alpha
			var p_pos = center + particle.pos
			draw_circle(p_pos, particle.size, Color(0.8, 0.75, 0.6, p_alpha))

func _draw_page_flip_effect(pos: Vector2, width: float, height: float) -> void:
	# Effet de page qui tourne
	var flip_progress = sin(calendar_page_flip_progress * PI)
	var page_width = width * 0.5 * flip_progress
	var page_x = pos.x + width * 0.5 - page_width * 0.5

	if calendar_page_flip_direction > 0:
		page_x = pos.x + width * 0.5

	var page_color = Color(0.92, 0.88, 0.80, 0.8 * flip_progress)
	draw_rect(Rect2(page_x, pos.y + 60, page_width, height - 60), page_color)

	# Ombre de la page
	var shadow_alpha = 0.3 * flip_progress
	draw_rect(Rect2(page_x + page_width - 5, pos.y + 60, 5, height - 60), Color(0, 0, 0, shadow_alpha))

func _draw_celtic_corners(pos: Vector2, width: float, height: float, alpha: float) -> void:
	var corner_size := 20.0
	var corner_color = PALETTE.gold_dark
	corner_color.a = alpha

	# Coin supÃ©rieur gauche
	_draw_corner_knot(pos + Vector2(10, 10), corner_size, corner_color)
	# Coin supÃ©rieur droit
	_draw_corner_knot(pos + Vector2(width - 30, 10), corner_size, corner_color)
	# Coin infÃ©rieur gauche
	_draw_corner_knot(pos + Vector2(10, height - 30), corner_size, corner_color)
	# Coin infÃ©rieur droit
	_draw_corner_knot(pos + Vector2(width - 30, height - 30), corner_size, corner_color)

func _draw_corner_knot(pos: Vector2, size: float, color: Color) -> void:
	# NÅ“ud celtique simplifiÃ©
	draw_arc(pos + Vector2(size * 0.5, size * 0.5), size * 0.4, 0, TAU, 8, color, 2.0)
	draw_rect(Rect2(pos + Vector2(size * 0.3, size * 0.3), Vector2(size * 0.4, size * 0.4)), color, false, 1.5)

func _ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3) + c1 * pow(t - 1.0, 2)

func _season_short_label(season_name: String) -> String:
	match season_name:
		"winter":
			return "HIV"
		"spring":
			return "PRI"
		"summer":
			return "ETE"
		"autumn":
			return "AUT"
		_:
			return "----"

func _weather_short_label(state: String) -> String:
	match state:
		"snow":
			return "NEIGE"
		"rain":
			return "PLUIE"
		"storm":
			return "ORAGE"
		"mist":
			return "BRUME"
		_:
			return "CLAIR"

func _update_button_animations(_delta: float) -> void:
	for btn in buttons:
		if btn == hovered_button:
			var pulse = 1.0 + sin(time_elapsed * 6.0) * 0.03
			btn.scale = Vector2(pulse, pulse)
		else:
			btn.scale = Vector2(1.0, 1.0)

func _update_calendar_animations(delta: float) -> void:
	# Animation d'ouverture/fermeture
	if calendar_open:
		calendar_anim_progress = minf(1.0, calendar_anim_progress + delta * 4.0)
	else:
		calendar_anim_progress = maxf(0.0, calendar_anim_progress - delta * 5.0)

	# Animation de changement de page
	if calendar_page_flip_progress < 1.0 and calendar_page_flip_direction != 0:
		calendar_page_flip_progress += delta * 3.0
		if calendar_page_flip_progress >= 1.0:
			calendar_page_flip_progress = 1.0
			calendar_page_flip_direction = 0

	# Amortissement du tremblement
	calendar_shake_offset = calendar_shake_offset.lerp(Vector2.ZERO, delta * 10.0)

	# Mise Ã  jour des particules de poussiÃ¨re
	for particle in calendar_dust_particles:
		particle.age += delta
		particle.pos += particle.vel * delta
		particle.vel.y -= 20.0 * delta  # GravitÃ© inversÃ©e (monte)

	# DÃ©tection du jour survolÃ©
	calendar_hovered_day = -1
	if calendar_open and calendar_anim_progress > 0.8:
		var first_weekday = _get_first_weekday(calendar_current_month, calendar_current_year)
		var days_in_month = _get_days_in_month(calendar_current_month, calendar_current_year)
		for i in range(calendar_day_rects.size()):
			var rect = calendar_day_rects[i]
			if rect.size.x > 0 and rect.has_point(mouse_pos):
				var day = i - first_weekday + 1
				if day >= 1 and day <= days_in_month:
					calendar_hovered_day = day
				break

func _on_button_hover(btn: Button) -> void:
	hovered_button = btn

func _on_button_unhover(btn: Button) -> void:
	if hovered_button == btn:
		hovered_button = null

func _on_save_book_pressed() -> void:
	_go_to_scene("res://scenes/SelectionSauvegarde.tscn")

func _on_menu_icon_pressed() -> void:
	_go_to_scene("res://scenes/MenuOptions.tscn")

func _on_button_pressed(btn: Button) -> void:
	for item in MENU_ITEMS:
		if item.name == btn.name:
			if item.scene == "__quit__":
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				get_tree().quit()
				return
			if item.scene == "":
				_show_message("Options a venir...")
				return
			_go_to_scene(item.scene)
			return

func _go_to_scene(scene_path: String) -> void:
	if scene_path == "":
		return
	if not ResourceLoader.exists(scene_path):
		_show_message("Scene introuvable: " + scene_path)
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var err = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		_show_message("Erreur scene: " + str(err))

func _show_message(text: String) -> void:
	var msg := Label.new()
	msg.text = text
	msg.add_theme_font_override("font", celtic_font_thin if celtic_font_thin != null else celtic_font)
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", PALETTE.gold_bright)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.set_anchors_preset(Control.PRESET_CENTER)
	msg.position.y += 220
	msg.modulate.a = 0.0
	add_child(msg)
	var tween = create_tween()
	tween.tween_property(msg, "modulate:a", 1.0, 0.3)
	tween.tween_property(msg, "position:y", msg.position.y - 28, 0.3)
	tween.tween_interval(1.4)
	tween.tween_property(msg, "modulate:a", 0.0, 0.3)
	tween.tween_callback(msg.queue_free)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = event.position

		# Gestion des clics sur le calendrier ouvert
		if calendar_open and calendar_anim_progress > 0.5:
			# Bouton prÃ©cÃ©dent
			if calendar_prev_btn_rect.has_point(pos):
				_navigate_calendar_month(-1)
				return
			# Bouton suivant
			if calendar_next_btn_rect.has_point(pos):
				_navigate_calendar_month(1)
				return
			# Clic sur un jour avec Ã©vÃ©nement
			if calendar_hovered_day > 0 and CALENDAR_EVENTS.has(calendar_hovered_day):
				var event_data = CALENDAR_EVENTS[calendar_hovered_day]
				_show_message("ðŸ“… %s - %s" % [event_data.name, event_data.icon])
				return
			# Clic en dehors du calendrier = fermer
			var viewport_size = get_viewport_rect().size
			var cal_width := 480.0
			var cal_height := 420.0
			var cal_center = viewport_size * 0.5
			var cal_rect = Rect2(cal_center - Vector2(cal_width, cal_height) * 0.5, Vector2(cal_width, cal_height))
			if not cal_rect.has_point(pos):
				_close_overlay()
				return

		# Ouverture du calendrier depuis l'horloge
		if clock_rect.has_point(pos):
			_open_calendar_overlay()
			return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if overlay_active != "":
					_close_overlay()
				else:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
					get_tree().quit()
			KEY_LEFT:
				if calendar_open:
					_navigate_calendar_month(-1)
			KEY_RIGHT:
				if calendar_open:
					_navigate_calendar_month(1)
			KEY_UP, KEY_W:
				if not calendar_open:
					_navigate_buttons(-1)
			KEY_DOWN, KEY_S:
				if not calendar_open:
					_navigate_buttons(1)
			KEY_ENTER, KEY_SPACE:
				if hovered_button and not calendar_open:
					_on_button_pressed(hovered_button)
				elif buttons.size() > 0 and not calendar_open:
					var focused = get_viewport().gui_get_focus_owner()
					if focused is Button:
						_on_button_pressed(focused)

func _navigate_buttons(direction: int) -> void:
	if buttons.is_empty():
		return
	var current_idx := -1
	if hovered_button:
		current_idx = buttons.find(hovered_button)
	else:
		var focused = get_viewport().gui_get_focus_owner()
		if focused is Button:
			current_idx = buttons.find(focused)
	var new_idx = (current_idx + direction) % buttons.size()
	if new_idx < 0:
		new_idx = buttons.size() - 1
	hovered_button = buttons[new_idx]
	buttons[new_idx].grab_focus()

func _build_landscape(viewport_size: Vector2) -> void:
	if viewport_size.x <= 0:
		return
	landscape_rng.seed = int(viewport_size.x) * 92821 + int(viewport_size.y) * 68917
	mountain_layers.clear()
	forest_layers.clear()
	star_field.clear()
	ground_speckles.clear()
	parallax_layers.clear()
	_build_star_field(viewport_size)
	_build_parallax_layers(viewport_size)
	for i in range(2):
		mountain_layers.append(_build_mountain_layer(viewport_size, i))
	for i in range(2):
		forest_layers.append(_build_forest_layer(viewport_size, i))
	_build_ground_speckles(viewport_size)

func _build_star_field(viewport_size: Vector2) -> void:
	var count = int(clampf(viewport_size.x * viewport_size.y / 18000.0, 40.0, 140.0))
	for i in range(count):
		star_field.append({
			"pos": Vector2(landscape_rng.randf_range(0.0, viewport_size.x), landscape_rng.randf_range(0.0, viewport_size.y * 0.5)),
			"alpha": landscape_rng.randf_range(0.12, 0.4),
			"size": landscape_rng.randf_range(1.0, 2.0),
			"seed": landscape_rng.randf_range(0.0, 10.0),
		})

func _build_parallax_layers(viewport_size: Vector2) -> void:
	for i in range(2):
		parallax_layers.append(_build_parallax_layer(viewport_size, i))

func _build_parallax_layer(viewport_size: Vector2, index: int) -> Dictionary:
	var step = PIXEL_SIZE * (10 - index * 2)
	var base_y = viewport_size.y * (0.52 + index * 0.07)
	var amplitude = viewport_size.y * (0.08 + index * 0.04)
	var count = int(ceil(viewport_size.x / step)) + 6
	var heights: Array = []
	var current = base_y - amplitude * landscape_rng.randf_range(0.2, 0.8)
	var drift = amplitude * 0.06
	for i in range(count):
		current += landscape_rng.randf_range(-drift, drift)
		current = clampf(current, base_y - amplitude, base_y + amplitude * 0.2)
		heights.append(round(current / PIXEL_SIZE) * PIXEL_SIZE)
	var color = PALETTE.bg_mid.lerp(PALETTE.bg_light, 0.12 + index * 0.18)
	var speed = 4.0 + index * 6.0
	return {"step": step, "base_y": base_y, "heights": heights, "color": color, "speed": speed}

func _build_mountain_layer(viewport_size: Vector2, index: int) -> Dictionary:
	var step = PIXEL_SIZE * (5 - index)
	var base_y = viewport_size.y * (0.48 + index * 0.1)
	var amplitude = viewport_size.y * (0.16 + index * 0.05)
	var count = int(ceil(viewport_size.x / step)) + 4
	var heights: Array = []
	var current = base_y - amplitude * landscape_rng.randf_range(0.4, 0.9)
	var drift = amplitude * 0.08
	for i in range(count):
		current += landscape_rng.randf_range(-drift, drift)
		current = clampf(current, base_y - amplitude, base_y + amplitude * 0.2)
		heights.append(round(current / PIXEL_SIZE) * PIXEL_SIZE)
	var color = PALETTE.bg_mid.lerp(PALETTE.green_dark, 0.25 + index * 0.22)
	return {"step": step, "base_y": base_y, "heights": heights, "color": color}

func _build_forest_layer(viewport_size: Vector2, index: int) -> Dictionary:
	var base_y = viewport_size.y * (0.68 + index * 0.08)
	var spacing = PIXEL_SIZE * (10 - index * 2)
	var count = int(ceil(viewport_size.x / spacing)) + 6
	var trees: Array = []
	for i in range(count):
		var x = i * spacing + landscape_rng.randf_range(-spacing * 0.4, spacing * 0.4)
		var height = landscape_rng.randf_range(22.0, 44.0) + index * 8.0
		height = round(height / PIXEL_SIZE) * PIXEL_SIZE
		var width = height * landscape_rng.randf_range(0.5, 0.7)
		width = round(width / PIXEL_SIZE) * PIXEL_SIZE
		trees.append({"x": x, "h": height, "w": width})
	var color = _season_forest_color(index)
	return {"base_y": base_y, "trees": trees, "color": color}

func _build_ground_speckles(viewport_size: Vector2) -> void:
	var count = int(clampf(viewport_size.x / 5.0, 80.0, 200.0))
	for i in range(count):
		var y = randf_range(viewport_size.y * 0.76, viewport_size.y - 6)
		var x = randf_range(0, viewport_size.x)
		var speckle_size = randf_range(1.0, 2.5)
		var color = _season_speckle_color()
		ground_speckles.append({"pos": Vector2(x, y), "size": speckle_size, "color": color})

func _season_ground_color() -> Color:
	if force_grass_plain:
		return Color(0.30, 0.62, 0.36)
	match season:
		"winter":
			return Color(0.82, 0.88, 0.94)
		"spring":
			return Color(0.34, 0.62, 0.36)
		"summer":
			return Color(0.63, 0.62, 0.32)
		"autumn":
			return Color(0.70, 0.42, 0.20)
		_:
			return PALETTE.green_dark

func _season_forest_color(index: int) -> Color:
	var base = PALETTE.green_dark
	if force_grass_plain:
		base = Color(0.22, 0.50, 0.28)
		var tint_plain = 0.10 + index * 0.18
		return base.lerp(PALETTE.bg_mid, tint_plain)
	match season:
		"winter":
			base = Color(0.55, 0.62, 0.68)
		"spring":
			base = Color(0.30, 0.62, 0.36)
		"summer":
			base = Color(0.55, 0.55, 0.32)
		"autumn":
			base = Color(0.62, 0.40, 0.22)
	var tint_season = 0.12 + index * 0.18
	return base.lerp(PALETTE.bg_mid, tint_season)

func _season_speckle_color() -> Color:
	if force_grass_plain:
		return Color(0.42, 0.72, 0.42, 0.85)
	match season:
		"winter":
			return Color(0.92, 0.96, 1.0, 0.9)
		"spring":
			return Color(0.98, 0.76, 0.86, 0.9)
		"summer":
			return Color(0.92, 0.86, 0.55, 0.9)
		"autumn":
			return Color(0.92, 0.56, 0.24, 0.9)
		_:
			return PALETTE.cream

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
func _draw_hand(center: Vector2, angle: float, length: float, color: Color) -> void:
	var steps = int(max(4.0, length))
	for i in range(steps):
		var t = float(i) / float(steps)
		var pos = center + Vector2(cos(angle), sin(angle)) * (t * length)
		pos.x = round(pos.x / 2.0) * 2.0
		pos.y = round(pos.y / 2.0) * 2.0
		draw_rect(Rect2(pos.x - 1, pos.y - 1, 2, 2), color)

func _draw_collection_icon() -> void:
	if collection_button == null:
		return
	var rect = Rect2(collection_button.position, collection_button.size)
	var icon_size = 38.0
	var icon_pos = rect.position + Vector2(6, (rect.size.y - icon_size) * 0.5)
	var bob = sin(time_elapsed * 2.0) * 2.0
	icon_pos.y += bob
	var spine = Color(0.30, 0.18, 0.10, 0.9)
	var page = Color(0.92, 0.88, 0.78, 0.95)
	var cover = PALETTE.gold_dark
	var glow = PALETTE.gold_bright
	draw_rect(Rect2(icon_pos + Vector2(0, 4), Vector2(icon_size, icon_size * 0.6)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(icon_pos, Vector2(icon_size * 0.48, icon_size * 0.7)), page)
	draw_rect(Rect2(icon_pos + Vector2(icon_size * 0.52, 0), Vector2(icon_size * 0.48, icon_size * 0.7)), page)
	draw_rect(Rect2(icon_pos + Vector2(icon_size * 0.46, 0), Vector2(icon_size * 0.08, icon_size * 0.7)), spine)
	draw_rect(Rect2(icon_pos + Vector2(2, icon_size * 0.68), Vector2(icon_size - 4, 4)), cover)
	draw_rect(Rect2(icon_pos + Vector2(icon_size * 0.14, icon_size * 0.16), Vector2(icon_size * 0.2, 2)), glow)
	draw_rect(Rect2(icon_pos + Vector2(icon_size * 0.66, icon_size * 0.16), Vector2(icon_size * 0.2, 2)), glow)
