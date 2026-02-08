extends Control

# Références aux nœuds
@onready var resolution_option = $ScrollContainer/OptionsContainer/ResolutionRow/ResolutionOption
@onready var display_mode_option = $ScrollContainer/OptionsContainer/DisplayModeRow/DisplayModeOption
@onready var vsync_check = $ScrollContainer/OptionsContainer/VSyncRow/VSyncCheck
@onready var fps_option = $ScrollContainer/OptionsContainer/FPSRow/FPSOption

@onready var master_slider = $ScrollContainer/OptionsContainer/MasterVolumeRow/MasterVolumeSlider
@onready var master_value = $ScrollContainer/OptionsContainer/MasterVolumeRow/MasterVolumeValue
@onready var music_slider = $ScrollContainer/OptionsContainer/MusicVolumeRow/MusicVolumeSlider
@onready var music_value = $ScrollContainer/OptionsContainer/MusicVolumeRow/MusicVolumeValue
@onready var sfx_slider = $ScrollContainer/OptionsContainer/SFXVolumeRow/SFXVolumeSlider
@onready var sfx_value = $ScrollContainer/OptionsContainer/SFXVolumeRow/SFXVolumeValue

@onready var btn_apply = $ButtonsContainer/BtnAppliquer
@onready var btn_reset = $ButtonsContainer/BtnReinitialiser
@onready var btn_back = $ButtonsContainer/BtnRetour

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
	"calendar_override": false,  # Use custom date
	"calendar_day": 1,
	"calendar_month": 1,
	"calendar_year": 2026,
}

# Calendar date spinboxes (created dynamically)
var calendar_day_spin: SpinBox
var calendar_month_spin: SpinBox
var calendar_year_spin: SpinBox
var calendar_override_check: CheckBox

# Configuration actuelle
var current_config = {}

# Chemin du fichier de configuration
const CONFIG_PATH = "user://settings.cfg"

func _ready():
	# Charger la configuration
	load_settings()

	# Build calendar date UI
	_build_calendar_options()

	# Appliquer les valeurs actuelles aux contrôles
	apply_to_ui()

	# Connecter les signaux
	connect_signals()


func _build_calendar_options() -> void:
	# Find the options container
	var options_container = get_node_or_null("ScrollContainer/OptionsContainer")
	if not options_container:
		return

	# Create calendar section
	var calendar_section := VBoxContainer.new()
	calendar_section.name = "CalendarSection"
	calendar_section.add_theme_constant_override("separation", 8)
	options_container.add_child(calendar_section)

	# Section header
	var header := Label.new()
	header.text = "=== Calendrier ==="
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	calendar_section.add_child(header)

	# Override checkbox row
	var override_row := HBoxContainer.new()
	override_row.add_theme_constant_override("separation", 12)
	calendar_section.add_child(override_row)

	var override_label := Label.new()
	override_label.text = "Date personnalisee:"
	override_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	override_row.add_child(override_label)

	calendar_override_check = CheckBox.new()
	calendar_override_check.button_pressed = current_config.get("calendar_override", false)
	calendar_override_check.toggled.connect(_on_calendar_override_toggled)
	override_row.add_child(calendar_override_check)

	# Date row
	var date_row := HBoxContainer.new()
	date_row.add_theme_constant_override("separation", 8)
	calendar_section.add_child(date_row)

	var day_label := Label.new()
	day_label.text = "Jour:"
	date_row.add_child(day_label)

	calendar_day_spin = SpinBox.new()
	calendar_day_spin.min_value = 1
	calendar_day_spin.max_value = 31
	calendar_day_spin.value = current_config.get("calendar_day", 1)
	calendar_day_spin.value_changed.connect(_on_calendar_day_changed)
	date_row.add_child(calendar_day_spin)

	var month_label := Label.new()
	month_label.text = "Mois:"
	date_row.add_child(month_label)

	calendar_month_spin = SpinBox.new()
	calendar_month_spin.min_value = 1
	calendar_month_spin.max_value = 12
	calendar_month_spin.value = current_config.get("calendar_month", 1)
	calendar_month_spin.value_changed.connect(_on_calendar_month_changed)
	date_row.add_child(calendar_month_spin)

	var year_label := Label.new()
	year_label.text = "Annee:"
	date_row.add_child(year_label)

	calendar_year_spin = SpinBox.new()
	calendar_year_spin.min_value = 2020
	calendar_year_spin.max_value = 2100
	calendar_year_spin.value = current_config.get("calendar_year", 2026)
	calendar_year_spin.value_changed.connect(_on_calendar_year_changed)
	date_row.add_child(calendar_year_spin)

	# Update enabled state
	_update_calendar_ui_enabled()


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
	btn_apply.pressed.connect(_on_apply_pressed)
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
			"calendar_override": config.get_value("calendar", "override", default_config.calendar_override),
			"calendar_day": config.get_value("calendar", "day", default_config.calendar_day),
			"calendar_month": config.get_value("calendar", "month", default_config.calendar_month),
			"calendar_year": config.get_value("calendar", "year", default_config.calendar_year),
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

	# Sauvegarder la configuration calendrier
	config.set_value("calendar", "override", current_config.calendar_override)
	config.set_value("calendar", "day", current_config.calendar_day)
	config.set_value("calendar", "month", current_config.calendar_month)
	config.set_value("calendar", "year", current_config.calendar_year)

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
func _on_apply_pressed():
	apply_settings()
	save_settings()
	print("✓ Paramètres appliqués et sauvegardés")

func _on_reset_pressed():
	# Réinitialiser aux valeurs par défaut
	current_config = default_config.duplicate()
	apply_to_ui()
	apply_settings()
	save_settings()
	print("✓ Paramètres réinitialisés")

func _on_back_pressed():
	# Retour au menu principal
	get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn")
