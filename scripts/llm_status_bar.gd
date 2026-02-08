extends CanvasLayer
## Barre de statut LLM globale - visible sur tous les ecrans
## Autoload: affiche le statut du LLM en bas au centre + selecteur de modele

const PALETTE := {
	"bg": Color(0.08, 0.09, 0.11, 0.92),
	"bg_hover": Color(0.12, 0.14, 0.18, 0.95),
	"text": Color(0.85, 0.82, 0.72),
	"text_dim": Color(0.55, 0.52, 0.48),
	"accent": Color(0.74, 0.66, 0.45),
	"success": Color(0.4, 0.75, 0.45),
	"warning": Color(0.85, 0.65, 0.25),
	"error": Color(0.85, 0.35, 0.35),
}

const TRINITY_MODELS := {
	"Q4_K_M": {"file": "Trinity-Nano-Preview-Q4_K_M.gguf", "desc": "Rapide"},
	"Q5_K_M": {"file": "Trinity-Nano-Preview-Q5_K_M.gguf", "desc": "Equilibre"},
	"Q8_0": {"file": "Trinity-Nano-Preview-Q8_0.gguf", "desc": "Qualite"},
}

const MODEL_DIRS := [
	"res://addons/merlin_llm/models",
	"C:/models/trinity-nano",
]

var status_panel: PanelContainer
var status_label: Label
var model_button: Button
var model_popup: PopupMenu
var progress_bar: ProgressBar
var warmup_done := false
var current_model_path := ""
var _llm_cache: Object = null

func _ready() -> void:
	layer = 100  # Au dessus de tout
	_build_ui()
	_scan_models()
	# Connecter aux signaux MerlinAI si disponible
	if Engine.has_singleton("MerlinAI") or has_node("/root/MerlinAI"):
		var merlin = get_node_or_null("/root/MerlinAI")
		if merlin:
			if merlin.has_signal("status_changed"):
				merlin.status_changed.connect(_on_merlin_status_changed)
			if merlin.has_signal("ready_changed"):
				merlin.ready_changed.connect(_on_merlin_ready_changed)
	# Prechauffement au demarrage
	_warmup_model.call_deferred()


func _build_ui() -> void:
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	status_panel = PanelContainer.new()
	# Centre bas de l'ecran
	status_panel.anchor_left = 0.5
	status_panel.anchor_right = 0.5
	status_panel.anchor_top = 1.0
	status_panel.anchor_bottom = 1.0
	status_panel.offset_left = -140  # Moitie de la largeur (280/2)
	status_panel.offset_right = 140
	status_panel.offset_top = -56
	status_panel.offset_bottom = -12
	container.add_child(status_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.bg
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	status_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	status_panel.add_child(vbox)

	# Ligne 1: Status + bouton modele
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	var status_icon := Label.new()
	status_icon.text = "●"
	status_icon.name = "StatusIcon"
	status_icon.add_theme_color_override("font_color", PALETTE.warning)
	status_icon.add_theme_font_size_override("font_size", 12)
	hbox.add_child(status_icon)

	status_label = Label.new()
	status_label.text = "LLM: Initialisation..."
	status_label.add_theme_color_override("font_color", PALETTE.text)
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(status_label)

	model_button = Button.new()
	model_button.text = "▼"
	model_button.custom_minimum_size = Vector2(28, 24)
	model_button.add_theme_font_size_override("font_size", 10)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = PALETTE.bg_hover
	btn_style.set_corner_radius_all(4)
	model_button.add_theme_stylebox_override("normal", btn_style)
	model_button.add_theme_stylebox_override("hover", btn_style)
	model_button.add_theme_stylebox_override("pressed", btn_style)
	model_button.pressed.connect(_on_model_button_pressed)
	hbox.add_child(model_button)

	# Ligne 2: Barre de progression
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 6)
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.show_percentage = false
	vbox.add_child(progress_bar)

	# Popup menu pour les modeles
	model_popup = PopupMenu.new()
	model_popup.id_pressed.connect(_on_model_selected)
	add_child(model_popup)


func _scan_models() -> void:
	model_popup.clear()
	var idx := 0
	for model_key in TRINITY_MODELS:
		var model_info: Dictionary = TRINITY_MODELS[model_key]
		for dir in MODEL_DIRS:
			var path: String = dir.path_join(str(model_info.file))
			if FileAccess.file_exists(path):
				model_popup.add_item("%s (%s)" % [model_key, model_info.desc], idx)
				model_popup.set_item_metadata(idx, path)
				if current_model_path.is_empty():
					current_model_path = path
				idx += 1
				break


func _warmup_model() -> void:
	if warmup_done or current_model_path.is_empty():
		return

	_update_status("Prechauffement...", PALETTE.warning, 10)

	if not ClassDB.class_exists("MerlinLLM"):
		_update_status("MerlinLLM indisponible", PALETTE.error, 0)
		return

	var llm := _get_or_load_model(current_model_path)
	if llm == null:
		_update_status("Erreur chargement", PALETTE.error, 0)
		return

	_update_status("Chargement GPU...", PALETTE.warning, 30)

	# Court prompt de warmup (10 tokens pour mieux primer le GPU)
	if llm.has_method("set_sampling_params"):
		llm.set_sampling_params(0.1, 0.5, 10)

	var state := {"done": false}
	llm.generate_async("Bonjour, dis une phrase.", func(_res):
		state.done = true
	)

	# Timeout + polling adaptatif (Godot Expert + Lead Godot)
	var timeout_ms := 30000  # 30 secondes max
	var start_time := Time.get_ticks_msec()
	var poll_count := 0

	while not state.done:
		if Time.get_ticks_msec() - start_time > timeout_ms:
			_update_status("Timeout warmup", PALETTE.error, 0)
			return
		llm.poll_result()
		poll_count += 1
		# Polling adaptatif: rapide au début, puis ralentit
		if poll_count < 5:
			await get_tree().process_frame
		elif poll_count < 20:
			await get_tree().create_timer(0.03).timeout
		else:
			await get_tree().create_timer(0.1).timeout

	warmup_done = true
	_update_status("LLM Pret", PALETTE.success, 100)


func _get_or_load_model(path: String) -> Object:
	if _llm_cache != null:
		return _llm_cache

	var llm = ClassDB.instantiate("MerlinLLM")
	var fs_path := ProjectSettings.globalize_path(path)
	var err = llm.load_model(fs_path)
	if typeof(err) == TYPE_INT and int(err) != OK:
		return null

	_llm_cache = llm
	return llm


func _update_status(text: String, color: Color, progress: float) -> void:
	status_label.text = text
	var icon := status_panel.get_node_or_null("VBoxContainer/HBoxContainer/StatusIcon")
	if icon:
		icon.add_theme_color_override("font_color", color)
	progress_bar.value = progress


func _on_model_button_pressed() -> void:
	var pos := model_button.global_position
	pos.y -= model_popup.size.y + 4
	model_popup.position = Vector2i(int(pos.x), int(pos.y))
	model_popup.popup()


func _on_model_selected(id: int) -> void:
	var new_path: String = model_popup.get_item_metadata(id)
	if new_path != current_model_path:
		current_model_path = new_path
		warmup_done = false
		_llm_cache = null
		_warmup_model()


func _on_merlin_status_changed(status: String, detail: String, progress: float) -> void:
	var color := PALETTE.text
	if "OK" in status:
		color = PALETTE.success
	elif "OFF" in status:
		color = PALETTE.error
	elif "..." in status:
		color = PALETTE.warning
	_update_status(detail, color, progress)


func _on_merlin_ready_changed(ready_state: bool) -> void:
	if ready_state:
		_update_status("LLM Pret", PALETTE.success, 100)
	else:
		_update_status("LLM Deconnecte", PALETTE.error, 0)


## API publique pour obtenir le LLM prechauffe
func get_llm() -> Object:
	if _llm_cache == null and not current_model_path.is_empty():
		_llm_cache = _get_or_load_model(current_model_path)
	return _llm_cache


## API publique pour savoir si le LLM est pret
func is_ready() -> bool:
	return warmup_done and _llm_cache != null


## API publique pour obtenir le chemin du modele actuel
func get_model_path() -> String:
	return current_model_path


## Cleanup des signaux et cache (Lead Godot)
func _exit_tree() -> void:
	# Deconnecter signaux MerlinAI
	var merlin = get_node_or_null("/root/MerlinAI")
	if merlin:
		if merlin.has_signal("status_changed") and merlin.status_changed.is_connected(_on_merlin_status_changed):
			merlin.status_changed.disconnect(_on_merlin_status_changed)
		if merlin.has_signal("ready_changed") and merlin.ready_changed.is_connected(_on_merlin_ready_changed):
			merlin.ready_changed.disconnect(_on_merlin_ready_changed)
	# Cleanup du cache LLM
	if _llm_cache != null and _llm_cache.has_method("unload_model"):
		_llm_cache.unload_model()
	_llm_cache = null
