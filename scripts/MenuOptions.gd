extends Control

# Références aux nœuds (via MainLayout/VBox)
@onready var resolution_option = $MainLayout/VBox/ScrollContainer/OptionsContainer/ResolutionRow/ResolutionOption
@onready var display_mode_option = $MainLayout/VBox/ScrollContainer/OptionsContainer/DisplayModeRow/DisplayModeOption
@onready var vsync_check = $MainLayout/VBox/ScrollContainer/OptionsContainer/VSyncRow/VSyncCheck
@onready var fps_option = $MainLayout/VBox/ScrollContainer/OptionsContainer/FPSRow/FPSOption

@onready var master_slider = $MainLayout/VBox/ScrollContainer/OptionsContainer/MasterVolumeRow/MasterVolumeSlider
@onready var master_value = $MainLayout/VBox/ScrollContainer/OptionsContainer/MasterVolumeRow/MasterVolumeValue
@onready var music_slider = $MainLayout/VBox/ScrollContainer/OptionsContainer/MusicVolumeRow/MusicVolumeSlider
@onready var music_value = $MainLayout/VBox/ScrollContainer/OptionsContainer/MusicVolumeRow/MusicVolumeValue
@onready var sfx_slider = $MainLayout/VBox/ScrollContainer/OptionsContainer/SFXVolumeRow/SFXVolumeSlider
@onready var sfx_value = $MainLayout/VBox/ScrollContainer/OptionsContainer/SFXVolumeRow/SFXVolumeValue

@onready var btn_reset = $MainLayout/VBox/ButtonsContainer/BtnReinitialiser
@onready var btn_back = $MainLayout/VBox/ButtonsContainer/BtnRetour

# Constantes de résolution
const RESOLUTIONS = [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1366, 768),
	Vector2i(1280, 720),
	Vector2i(1152, 648)
]

# Configuration par défaut
var default_config = {
	"resolution": 4,  # 1152x648
	"display_mode": 1,  # Fenêtré
	"vsync": true,
	"fps_limit": 1,  # 60 FPS
	"master_volume": 80,
	"music_volume": 70,
	"sfx_volume": 75,
	"voice_mode": 0,  # 0=Voix Parlee, 1=Voix Robot, 2=Desactivee
	"voice_bank": "default",
	"voice_preset": "Merlin",
	"calendar_override": false,  # Use custom date
	"calendar_day": 1,
	"calendar_month": 1,
	"calendar_year": 2026,
	"brain_count": 0,  # 0=Auto, 2=Dual, 3=Triple
	# Palier de generation. "" = detection selon la RAM physique de la machine.
	# Sinon "leger" / "moyen" / "eleve" (cf. BrainSwarmConfig.Profile).
	"llm_tier": "",
	# "" = laisser le palier decider. Sinon, le tag exact d'un modele installe
	# (ex. "gemma4:12b-it-qat"). Ce choix pilote TOUTE la generation : titres,
	# intro, squelette de scenario et cartes passent par le meme modele.
	#
	# Preseance : llm_model (s'il est renseigne) > llm_tier > detection RAM.
	"llm_model": "",
}

# Calendar controls (scene nodes)
@onready var calendar_override_check: CheckBox = $MainLayout/VBox/ScrollContainer/OptionsContainer/CalendarSection/OverrideRow/CalendarOverrideCheck
@onready var calendar_day_spin: SpinBox = $MainLayout/VBox/ScrollContainer/OptionsContainer/CalendarSection/DateRow/CalendarDaySpin
@onready var calendar_month_spin: SpinBox = $MainLayout/VBox/ScrollContainer/OptionsContainer/CalendarSection/DateRow/CalendarMonthSpin
@onready var calendar_year_spin: SpinBox = $MainLayout/VBox/ScrollContainer/OptionsContainer/CalendarSection/DateRow/CalendarYearSpin

# Language selector (scene node)
@onready var language_option: OptionButton = $MainLayout/VBox/ScrollContainer/OptionsContainer/LanguageSection/LanguageRow/LanguageOption

# Voice controls (scene nodes)
@onready var voice_mode_option: OptionButton = $MainLayout/VBox/ScrollContainer/OptionsContainer/VoiceSection/VoiceModeRow/VoiceModeOption
@onready var voice_bank_option: OptionButton = $MainLayout/VBox/ScrollContainer/OptionsContainer/VoiceSection/VoiceBankRow/VoiceBankOption
@onready var voice_preset_option: OptionButton = $MainLayout/VBox/ScrollContainer/OptionsContainer/VoiceSection/VoicePresetRow/VoicePresetOption

# IA controls (scene nodes)
@onready var brain_count_option: OptionButton = $MainLayout/VBox/ScrollContainer/OptionsContainer/IASection/BrainRow/BrainCountOption
@onready var tier_option: OptionButton = $MainLayout/VBox/ScrollContainer/OptionsContainer/IASection/TierRow/TierOption
@onready var model_option: OptionButton = $MainLayout/VBox/ScrollContainer/OptionsContainer/IASection/ModelRow/ModelOption
@onready var model_info_label: Label = $MainLayout/VBox/ScrollContainer/OptionsContainer/IASection/ModelInfoLabel
@onready var brain_info_label: Label = $MainLayout/VBox/ScrollContainer/OptionsContainer/IASection/BrainInfoLabel

# Configuration actuelle
var current_config = {}

# Chemin du fichier de configuration
const CONFIG_PATH = "user://settings.cfg"

func _ready():
	load_settings()
	_configure_calendar_options()
	_configure_language_options()
	_configure_voice_options()
	_configure_ia_options()
	apply_to_ui()
	connect_signals()


func _configure_calendar_options() -> void:
	# Per-node null guards — partial scene support. The .tscn currently only
	# contains CalendarOverrideCheck/DaySpin/MonthSpin (no YearSpin yet); these
	# guards prevent SCRIPT ERROR null-instance crashes while the scene is
	# being expanded incrementally. Guards mirror the style already used in
	# `apply_to_ui` and `_update_calendar_ui_enabled`.
	if calendar_day_spin:
		calendar_day_spin.min_value = 1
		calendar_day_spin.max_value = 31
		calendar_day_spin.value_changed.connect(_on_calendar_day_changed)
	if calendar_month_spin:
		calendar_month_spin.min_value = 1
		calendar_month_spin.max_value = 12
		calendar_month_spin.value_changed.connect(_on_calendar_month_changed)
	if calendar_year_spin:
		calendar_year_spin.min_value = 2020
		calendar_year_spin.max_value = 2100
		calendar_year_spin.value_changed.connect(_on_calendar_year_changed)
	if calendar_override_check:
		calendar_override_check.toggled.connect(_on_calendar_override_toggled)


func _configure_language_options() -> void:
	# Early return if LanguageOption is missing from .tscn (LanguageSection
	# container not yet added to the scene). Same defensive style as
	# `apply_to_ui` voice/IA guards.
	if language_option == null:
		return
	var locale_mgr = get_node_or_null("/root/LocaleManager")
	var codes: Array = []
	if locale_mgr:
		codes = locale_mgr.get_supported_codes()
	else:
		codes = ["fr", "en", "es", "it", "pt", "zh", "ja"]
	var labels := {
		"fr": "Francais", "en": "English", "es": "Espanol",
		"it": "Italiano", "pt": "Portugues", "zh": "中文", "ja": "日本語"
	}
	for code in codes:
		language_option.add_item(labels.get(code, code))
		language_option.set_item_metadata(language_option.item_count - 1, code)

	var current_lang: String = "fr"
	if locale_mgr:
		current_lang = locale_mgr.get_language()
	for i in range(language_option.item_count):
		if language_option.get_item_metadata(i) == current_lang:
			language_option.selected = i
			break
	language_option.item_selected.connect(_on_language_changed)


func _configure_voice_options() -> void:
	# Early return if VoiceMode is missing from .tscn (VoiceSection container
	# not yet added to the scene).
	if voice_mode_option == null:
		_update_voice_ui_enabled()
		return
	# Populate voice mode (3 items, node already in scene)
	voice_mode_option.add_item(tr("VOICE_SPOKEN"))    # 0 = AC_VOICE
	voice_mode_option.add_item(tr("VOICE_ROBOT"))    # 1 = DIGITAL_VOICE
	voice_mode_option.add_item(tr("VOICE_DISABLED")) # 2 = OFF
	voice_mode_option.add_item("Conteur (voix TTS)") # 3 = NARRATOR_TTS (vraie voix d'homme)
	voice_mode_option.selected = current_config.get("voice_mode", 0)
	voice_mode_option.item_selected.connect(_on_voice_mode_changed)

	# Populate sound banks (9 banks with metadata) — guard if VoiceBank node missing
	if voice_bank_option:
		var bank_names := ["default", "high", "low", "lowest", "med", "robot", "glitch", "whisper", "droid"]
		var bank_keys := {
			"default": "VOICE_BANK_CLASSIC", "high": "VOICE_BANK_HIGH", "low": "VOICE_BANK_LOW",
			"lowest": "VOICE_BANK_VERY_LOW", "med": "VOICE_BANK_MEDIUM", "robot": "VOICE_BANK_ROBOT_BEEP",
			"glitch": "VOICE_BANK_GLITCH", "whisper": "VOICE_BANK_WHISPER", "droid": "VOICE_BANK_DROID",
		}
		for bname in bank_names:
			voice_bank_option.add_item(tr(bank_keys.get(bname, bname)))
			voice_bank_option.set_item_metadata(voice_bank_option.item_count - 1, bname)
		var cur_bank: String = current_config.get("voice_bank", "default")
		for i in range(voice_bank_option.item_count):
			if voice_bank_option.get_item_metadata(i) == cur_bank:
				voice_bank_option.selected = i
				break
		voice_bank_option.item_selected.connect(_on_voice_bank_changed)

	# Populate voice presets (12 items) — guard if VoicePreset node missing
	if voice_preset_option:
		var preset_keys := ["Merlin", "VOICE_PRESET_SOFT", "VOICE_PRESET_QUILL", "VOICE_PRESET_CRYSTAL", "VOICE_PRESET_ANCIENT", "VOICE_PRESET_NORMAL", "VOICE_PRESET_HIGH", "VOICE_PRESET_LOW", "VOICE_PRESET_CHILD", "VOICE_PRESET_WISE", "VOICE_PRESET_JOYFUL", "VOICE_PRESET_MYSTERIOUS"]
		for pkey in preset_keys:
			voice_preset_option.add_item(tr(pkey))
		var cur_preset: String = current_config.get("voice_preset", "Merlin")
		for i in range(voice_preset_option.item_count):
			if voice_preset_option.get_item_text(i) == cur_preset:
				voice_preset_option.selected = i
				break
		voice_preset_option.item_selected.connect(_on_voice_preset_changed)

	_update_voice_ui_enabled()


func _update_voice_ui_enabled() -> void:
	var mode: int = current_config.get("voice_mode", 0)
	# Bank and preset only for Voix Parlee (mode 0)
	if voice_bank_option:
		voice_bank_option.disabled = (mode != 0)
	if voice_preset_option:
		voice_preset_option.disabled = (mode != 0)


func _on_voice_mode_changed(index: int) -> void:
	current_config["voice_mode"] = index
	var mv = get_node_or_null("/root/MerlinVoice")
	if mv and mv.has_method("set_voice_mode"):
		mv.set_voice_mode(index)  # apply live (0=AC,1=Digital,2=Off,3=Conteur TTS)
	_update_voice_ui_enabled()


func _on_voice_bank_changed(index: int) -> void:
	var bank_name: String = voice_bank_option.get_item_metadata(index)
	current_config["voice_bank"] = bank_name


func _on_voice_preset_changed(index: int) -> void:
	current_config["voice_preset"] = voice_preset_option.get_item_text(index)


const BRAIN_OPTIONS := [
	{"value": 0, "label_key": "BRAIN_AUTO", "info_key": "BRAIN_AUTO_INFO"},
	{"value": 2, "label_key": "BRAIN_DUAL", "info_key": "BRAIN_DUAL_INFO"},
	{"value": 3, "label_key": "BRAIN_TRIPLE", "info_key": "BRAIN_TRIPLE_INFO"},
]



func _configure_ia_options() -> void:
	# Early return if BrainCountOption is missing from .tscn (IASection container
	# not yet added to the scene). Guards mirror voice/language style.
	if brain_count_option == null:
		return
	# Populate brain count options (node now confirmed present)
	for opt in BRAIN_OPTIONS:
		brain_count_option.add_item(tr(opt["label_key"]))
		brain_count_option.set_item_metadata(brain_count_option.item_count - 1, opt["value"])
	var cur_brain: int = current_config.get("brain_count", 0)
	for i in range(brain_count_option.item_count):
		if int(brain_count_option.get_item_metadata(i)) == cur_brain:
			brain_count_option.selected = i
			break
	brain_count_option.item_selected.connect(_on_brain_count_changed)
	_configure_tier_options()
	_configure_model_options()

	# Configure info label styling — separate guard since BrainInfoLabel sits
	# in IASection but is independent of BrainCountOption resolution.
	if brain_info_label:
		brain_info_label.add_theme_font_size_override("font_size", 14)
		brain_info_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
		brain_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_brain_info_label()


## Les trois paliers de generation, plus la detection automatique.
##
## Le palier fixe la TAILLE du modele selon la machine. Le selecteur en dessous
## fixe un modele PRECIS. Preseance : un modele choisi explicitement l'emporte
## sur le palier, et le palier l'emporte sur la detection.
const TIER_OPTIONS := [
	{"value": "", "label": "Automatique (selon la machine)"},
	{"value": "leger", "label": "Leger — machine limitee"},
	{"value": "moyen", "label": "Moyen — 16 Go de memoire"},
	{"value": "eleve", "label": "Eleve — 32 Go et plus"},
]


func _configure_tier_options() -> void:
	if tier_option == null:
		return
	tier_option.clear()
	for opt in TIER_OPTIONS:
		tier_option.add_item(tr(str(opt["label"])))
		tier_option.set_item_metadata(tier_option.item_count - 1, str(opt["value"]))

	var choisi: String = str(current_config.get("llm_tier", ""))
	tier_option.selected = 0
	for i in range(tier_option.item_count):
		if str(tier_option.get_item_metadata(i)) == choisi:
			tier_option.selected = i
			break
	tier_option.item_selected.connect(_on_tier_changed)


func _on_tier_changed(index: int) -> void:
	current_config["llm_tier"] = str(tier_option.get_item_metadata(index))
	_update_model_info_label(maxi(model_option.item_count - 1, 0) if model_option else 0)


## Modele du palier, et commande a taper s'il manque.
## Retourne "" quand le palier est en detection automatique.
func _modele_du_palier(tier: String) -> String:
	var pid: int = BrainSwarmConfig.profile_from_name(tier)
	if pid < 0:
		return ""
	return BrainSwarmConfig.get_model_for_role(pid, "narrator")


## Selecteur du modele qui ecrit le jeu. On propose ce qui est REELLEMENT
## installe (Ollama /api/tags) plutot qu'une liste ecrite en dur : elle
## mentirait des que l'utilisateur installe ou retire un modele.
func _configure_model_options() -> void:
	if model_option == null:
		return
	model_option.clear()
	model_option.add_item(tr("Automatique (recommande)"))
	model_option.set_item_metadata(0, "")

	var installes: Array = []
	var ai: Node = get_node_or_null("/root/MerlinAI")
	if ai and ai.has_method("list_installed_models"):
		installes = ai.call("list_installed_models")

	for nom in installes:
		model_option.add_item(str(nom))
		model_option.set_item_metadata(model_option.item_count - 1, str(nom))

	var choisi: String = str(current_config.get("llm_model", ""))
	model_option.selected = 0
	for i in range(model_option.item_count):
		if str(model_option.get_item_metadata(i)) == choisi:
			model_option.selected = i
			break

	if model_info_label:
		model_info_label.add_theme_font_size_override("font_size", 14)
		model_info_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
		model_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_model_info_label(installes.size())
	model_option.item_selected.connect(_on_model_changed)


func _on_model_changed(index: int) -> void:
	current_config["llm_model"] = str(model_option.get_item_metadata(index))
	_update_model_info_label(maxi(model_option.item_count - 1, 0))


func _update_model_info_label(nb_installes: int) -> void:
	if model_info_label == null:
		return
	if nb_installes <= 0:
		model_info_label.text = tr(
			"Aucun modele detecte. Merlin utilisera les scenarios ecrits d'avance.")
		return

	# Un modele designe explicitement l'emporte sur le palier : le dire, sinon
	# le joueur croit changer de palier alors que son choix de modele decide.
	var choisi: String = str(current_config.get("llm_model", ""))
	if choisi != "":
		model_info_label.text = tr(
			"Titres, intro, scenario et cartes seront ecrits par %s. Ce choix l'emporte sur le palier.") % choisi
		return

	var tier: String = str(current_config.get("llm_tier", ""))
	if tier == "":
		model_info_label.text = tr(
			"Merlin choisit le palier selon la memoire de la machine. %d modeles detectes.") % nb_installes
		return

	var attendu: String = _modele_du_palier(tier)
	if attendu != "" and not _modele_est_installe(attendu):
		model_info_label.text = tr(
			"Palier %s : le modele %s n'est pas installe. Lance :  ollama pull %s") % [tier, attendu, attendu]
	else:
		model_info_label.text = tr("Palier %s : Merlin ecrira avec %s.") % [tier, attendu]


func _modele_est_installe(tag: String) -> bool:
	if model_option == null:
		return false
	for i in range(model_option.item_count):
		if str(model_option.get_item_metadata(i)) == tag:
			return true
	return false


func _on_brain_count_changed(index: int) -> void:
	var value: int = int(brain_count_option.get_item_metadata(index))
	current_config["brain_count"] = value
	_update_brain_info_label()





func _update_brain_info_label() -> void:
	if brain_info_label == null:
		return
	var cur_brain: int = current_config.get("brain_count", 0)
	for opt in BRAIN_OPTIONS:
		if int(opt["value"]) == cur_brain:
			brain_info_label.text = tr(opt["info_key"])
			return
	brain_info_label.text = ""


func _on_language_changed(index: int) -> void:
	var code: String = language_option.get_item_metadata(index)
	var locale_mgr = get_node_or_null("/root/LocaleManager")
	if locale_mgr:
		locale_mgr.set_language(code)
	# Refresh dynamically populated option buttons with new translations
	_refresh_translated_options()


func _refresh_translated_options() -> void:
	# Re-populate voice mode
	var vm_sel: int = voice_mode_option.selected
	voice_mode_option.clear()
	voice_mode_option.add_item(tr("VOICE_SPOKEN"))
	voice_mode_option.add_item(tr("VOICE_ROBOT"))
	voice_mode_option.add_item(tr("VOICE_DISABLED"))
	voice_mode_option.selected = vm_sel

	# Re-populate voice banks
	var vb_sel: int = voice_bank_option.selected
	var bank_names := ["default", "high", "low", "lowest", "med", "robot", "glitch", "whisper", "droid"]
	var bank_keys := {
		"default": "VOICE_BANK_CLASSIC", "high": "VOICE_BANK_HIGH", "low": "VOICE_BANK_LOW",
		"lowest": "VOICE_BANK_VERY_LOW", "med": "VOICE_BANK_MEDIUM", "robot": "VOICE_BANK_ROBOT_BEEP",
		"glitch": "VOICE_BANK_GLITCH", "whisper": "VOICE_BANK_WHISPER", "droid": "VOICE_BANK_DROID",
	}
	voice_bank_option.clear()
	for bname in bank_names:
		voice_bank_option.add_item(tr(bank_keys.get(bname, bname)))
		voice_bank_option.set_item_metadata(voice_bank_option.item_count - 1, bname)
	voice_bank_option.selected = vb_sel

	# Re-populate voice presets
	var vp_sel: int = voice_preset_option.selected
	var preset_keys := ["Merlin", "VOICE_PRESET_SOFT", "VOICE_PRESET_QUILL", "VOICE_PRESET_CRYSTAL", "VOICE_PRESET_ANCIENT", "VOICE_PRESET_NORMAL", "VOICE_PRESET_HIGH", "VOICE_PRESET_LOW", "VOICE_PRESET_CHILD", "VOICE_PRESET_WISE", "VOICE_PRESET_JOYFUL", "VOICE_PRESET_MYSTERIOUS"]
	voice_preset_option.clear()
	for pkey in preset_keys:
		voice_preset_option.add_item(tr(pkey))
	voice_preset_option.selected = vp_sel

	# Re-populate brain options
	var bc_sel: int = brain_count_option.selected
	brain_count_option.clear()
	for opt in BRAIN_OPTIONS:
		brain_count_option.add_item(tr(opt["label_key"]))
		brain_count_option.set_item_metadata(brain_count_option.item_count - 1, opt["value"])
	brain_count_option.selected = bc_sel
	_update_brain_info_label()


func _update_calendar_ui_enabled() -> void:
	var enabled: bool = current_config.get("calendar_override", false)
	if calendar_day_spin:
		calendar_day_spin.editable = enabled
	if calendar_month_spin:
		calendar_month_spin.editable = enabled
	if calendar_year_spin:
		calendar_year_spin.editable = enabled


func _on_calendar_override_toggled(pressed: bool) -> void:
	current_config["calendar_override"] = pressed
	_update_calendar_ui_enabled()


func _on_calendar_day_changed(value: float) -> void:
	current_config["calendar_day"] = int(value)


func _on_calendar_month_changed(value: float) -> void:
	current_config["calendar_month"] = int(value)


func _on_calendar_year_changed(value: float) -> void:
	current_config["calendar_year"] = int(value)

func connect_signals():
	# Sliders de volume
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	# Boutons
	btn_reset.pressed.connect(_on_reset_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	
	# Options
	resolution_option.item_selected.connect(_on_resolution_changed)
	display_mode_option.item_selected.connect(_on_display_mode_changed)
	vsync_check.toggled.connect(_on_vsync_toggled)
	fps_option.item_selected.connect(_on_fps_changed)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)

	if err == OK:
		# Charger depuis le fichier
		current_config = {
			"resolution": config.get_value("video", "resolution", default_config.resolution),
			"display_mode": config.get_value("video", "display_mode", default_config.display_mode),
			"vsync": config.get_value("video", "vsync", default_config.vsync),
			"fps_limit": config.get_value("video", "fps_limit", default_config.fps_limit),
			"master_volume": config.get_value("audio", "master_volume", default_config.master_volume),
			"music_volume": config.get_value("audio", "music_volume", default_config.music_volume),
			"sfx_volume": config.get_value("audio", "sfx_volume", default_config.sfx_volume),
			"voice_mode": config.get_value("voice", "mode", default_config.voice_mode),
			"voice_bank": config.get_value("voice", "bank", default_config.voice_bank),
			"voice_preset": config.get_value("voice", "preset", default_config.voice_preset),
			"calendar_override": config.get_value("calendar", "override", default_config.calendar_override),
			"calendar_day": config.get_value("calendar", "day", default_config.calendar_day),
			"calendar_month": config.get_value("calendar", "month", default_config.calendar_month),
			"calendar_year": config.get_value("calendar", "year", default_config.calendar_year),
			"brain_count": config.get_value("ai", "brain_count", default_config.brain_count),
			# Section [options] : lue aussi par MerlinAI au demarrage.
			"llm_tier": config.get_value("options", "llm_tier", default_config.llm_tier),
			"llm_model": config.get_value("options", "llm_model", default_config.llm_model),
		}
	else:
		# Utiliser les valeurs par défaut
		current_config = default_config.duplicate()

func save_settings():
	var config = ConfigFile.new()

	# Sauvegarder la configuration video
	config.set_value("video", "resolution", current_config.resolution)
	config.set_value("video", "display_mode", current_config.display_mode)
	config.set_value("video", "vsync", current_config.vsync)
	config.set_value("video", "fps_limit", current_config.fps_limit)

	# Sauvegarder la configuration audio
	config.set_value("audio", "master_volume", current_config.master_volume)
	config.set_value("audio", "music_volume", current_config.music_volume)
	config.set_value("audio", "sfx_volume", current_config.sfx_volume)

	# Sauvegarder la configuration voix
	config.set_value("voice", "mode", current_config.get("voice_mode", 0))
	config.set_value("voice", "bank", current_config.get("voice_bank", "default"))
	config.set_value("voice", "preset", current_config.get("voice_preset", "Merlin"))

	# Sauvegarder la configuration calendrier
	config.set_value("calendar", "override", current_config.calendar_override)
	config.set_value("calendar", "day", current_config.calendar_day)
	config.set_value("calendar", "month", current_config.calendar_month)
	config.set_value("calendar", "year", current_config.calendar_year)

	# Sauvegarder la configuration IA
	config.set_value("ai", "brain_count", current_config.get("brain_count", 0))

	# Palier et modele — section [options], celle que MerlinAI relit au
	# demarrage (cf. _palier_choisi_par_le_joueur / _modele_choisi_par_le_joueur).
	config.set_value("options", "llm_tier", current_config.get("llm_tier", ""))
	config.set_value("options", "llm_model", current_config.get("llm_model", ""))

	config.save(CONFIG_PATH)

func apply_to_ui():
	# Appliquer les valeurs aux contrôles UI
	resolution_option.selected = current_config.resolution
	display_mode_option.selected = current_config.display_mode
	vsync_check.button_pressed = current_config.vsync
	fps_option.selected = current_config.fps_limit

	master_slider.value = current_config.master_volume
	master_value.text = str(current_config.master_volume) + "%"

	music_slider.value = current_config.music_volume
	music_value.text = str(current_config.music_volume) + "%"

	sfx_slider.value = current_config.sfx_volume
	sfx_value.text = str(current_config.sfx_volume) + "%"

	# Appliquer les valeurs voix
	if voice_mode_option:
		voice_mode_option.selected = current_config.get("voice_mode", 0)
	if voice_bank_option:
		var bank: String = current_config.get("voice_bank", "default")
		for i in range(voice_bank_option.item_count):
			if voice_bank_option.get_item_metadata(i) == bank:
				voice_bank_option.selected = i
				break
	if voice_preset_option:
		var preset: String = current_config.get("voice_preset", "Merlin")
		for i in range(voice_preset_option.item_count):
			if voice_preset_option.get_item_text(i) == preset:
				voice_preset_option.selected = i
				break
	_update_voice_ui_enabled()

	# Appliquer les valeurs IA
	if brain_count_option:
		var cur_brain: int = current_config.get("brain_count", 0)
		for i in range(brain_count_option.item_count):
			if int(brain_count_option.get_item_metadata(i)) == cur_brain:
				brain_count_option.selected = i
				break
	_update_brain_info_label()

	# Palier et modele — sans ca, une remise a zero laisserait les deux menus
	# afficher l'ancien choix alors que la configuration est revenue au defaut.
	if tier_option:
		var cur_tier: String = str(current_config.get("llm_tier", ""))
		for i in range(tier_option.item_count):
			if str(tier_option.get_item_metadata(i)) == cur_tier:
				tier_option.selected = i
				break
	if model_option:
		var cur_model: String = str(current_config.get("llm_model", ""))
		model_option.selected = 0
		for i in range(model_option.item_count):
			if str(model_option.get_item_metadata(i)) == cur_model:
				model_option.selected = i
				break
		_update_model_info_label(maxi(model_option.item_count - 1, 0))

	# Appliquer les valeurs du calendrier
	if calendar_override_check:
		calendar_override_check.button_pressed = current_config.get("calendar_override", false)
	if calendar_day_spin:
		calendar_day_spin.value = current_config.get("calendar_day", 1)
	if calendar_month_spin:
		calendar_month_spin.value = current_config.get("calendar_month", 1)
	if calendar_year_spin:
		calendar_year_spin.value = current_config.get("calendar_year", 2026)
	_update_calendar_ui_enabled()

func apply_settings():
	# Appliquer la résolution
	var resolution = RESOLUTIONS[current_config.resolution]
	get_window().size = resolution
	
	# Centrer la fenêtre
	var screen_size = DisplayServer.screen_get_size()
	var window_size = get_window().size
	get_window().position = (screen_size - window_size) / 2
	
	# Appliquer le mode d'affichage
	match current_config.display_mode:
		0:  # Plein écran
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		1:  # Fenêtré
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		2:  # Borderless
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	# Appliquer VSync
	if current_config.vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	# Appliquer la limite FPS
	match current_config.fps_limit:
		0:  # 30 FPS
			Engine.max_fps = 30
		1:  # 60 FPS
			Engine.max_fps = 60
		2:  # 120 FPS
			Engine.max_fps = 120
		3:  # Illimité
			Engine.max_fps = 0
	
	# Appliquer les volumes audio
	apply_audio_volumes()

func apply_audio_volumes():
	# Convertir les valeurs de pourcentage en décibels
	var master_db = linear_to_db(current_config.master_volume / 100.0)
	var music_db = linear_to_db(current_config.music_volume / 100.0)
	var sfx_db = linear_to_db(current_config.sfx_volume / 100.0)
	
	# Appliquer aux bus audio
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), master_db)
	
	# Vérifier si les bus existent avant de les configurer
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx, music_db)
	
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, sfx_db)

# Callbacks pour les contrôles
func _on_master_volume_changed(value):
	current_config.master_volume = int(value)
	master_value.text = str(int(value)) + "%"
	apply_audio_volumes()

func _on_music_volume_changed(value):
	current_config.music_volume = int(value)
	music_value.text = str(int(value)) + "%"
	apply_audio_volumes()

func _on_sfx_volume_changed(value):
	current_config.sfx_volume = int(value)
	sfx_value.text = str(int(value)) + "%"
	apply_audio_volumes()

func _on_resolution_changed(index):
	current_config.resolution = index

func _on_display_mode_changed(index):
	current_config.display_mode = index

func _on_vsync_toggled(pressed):
	current_config.vsync = pressed

func _on_fps_changed(index):
	current_config.fps_limit = index

# Callbacks pour les boutons
func _apply_brain_count() -> void:
	var mai = get_node_or_null("/root/MerlinAI")
	if mai == null:
		return
	var target: int = current_config.get("brain_count", 0)
	var current_target: int = mai._target_brain_count if "_target_brain_count" in mai else -1
	if target == current_target:
		return
	mai.set_brain_count(target)
	# Reload models only if warmup already happened (avoid cold reload at boot)
	if mai.is_ready:
		mai.reload_models()

func _on_reset_pressed():
	# Réinitialiser aux valeurs par défaut
	current_config = default_config.duplicate()
	apply_to_ui()
	apply_settings()
	save_settings()
	print("✓ Paramètres réinitialisés")

func _on_back_pressed():
	# Auto-apply + save on exit (modern UX: no separate "Apply" button)
	apply_settings()
	save_settings()
	_apply_brain_count()
	var se := get_node_or_null("/root/ScreenEffects")
	var target: String = se.return_scene if se and se.return_scene != "" else "res://scenes/MerlinCabinHub.tscn"
	PixelTransition.transition_to(target)
