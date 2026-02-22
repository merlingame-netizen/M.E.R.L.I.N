extends CanvasLayer
## Barre de statut LLM globale - visible sur tous les ecrans
## Autoload: affiche le statut du LLM en bas au centre + selecteur de modele


const TRINITY_MODELS := {
	"default": {"file": "qwen2.5-3b-instruct-q4_k_m.gguf", "desc": "M.E.R.L.I.N.-3B (defaut)"},
}

const MODEL_DIRS := [
	"res://addons/merlin_llm/models",
	"C:/models/trinity-nano",
]

@onready var status_panel: PanelContainer = $Container/StatusPanel
@onready var status_label: Label = $Container/StatusPanel/VBox/HBox/StatusLabel
@onready var _status_icon: Label = $Container/StatusPanel/VBox/HBox/StatusIcon
@onready var model_button: Button = $Container/StatusPanel/VBox/HBox/ModelButton
@onready var model_popup: PopupMenu = $ModelPopup
@onready var progress_bar: ProgressBar = $Container/StatusPanel/VBox/ProgressBar
var warmup_done := false
var current_model_path := ""
var _llm_cache: Object = null

func _ready() -> void:
	_configure_ui()
	_scan_models()
	# Connecter aux signaux MerlinAI si disponible
	if Engine.has_singleton("MerlinAI") or has_node("/root/MerlinAI"):
		var merlin = get_node_or_null("/root/MerlinAI")
		if merlin:
			if merlin.has_signal("status_changed"):
				merlin.status_changed.connect(_on_merlin_status_changed)
			if merlin.has_signal("ready_changed"):
				merlin.ready_changed.connect(_on_merlin_ready_changed)
	# Warmup differe — declenche depuis MenuPrincipal quand le joueur lance une partie
	# (ne pas charger 3.3 Go au demarrage, ca bloque le thread principal)


func _configure_ui() -> void:
	# Panel style (runtime-dependent on MerlinVisual)
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.LLM_STATUS.bg
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	status_panel.add_theme_stylebox_override("panel", style)

	# Color overrides
	_status_icon.add_theme_color_override("font_color", MerlinVisual.LLM_STATUS.warning)
	status_label.add_theme_color_override("font_color", MerlinVisual.LLM_STATUS.text)

	# Model button style
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = MerlinVisual.LLM_STATUS.bg_hover
	btn_style.set_corner_radius_all(4)
	model_button.add_theme_stylebox_override("normal", btn_style)
	model_button.add_theme_stylebox_override("hover", btn_style)
	model_button.add_theme_stylebox_override("pressed", btn_style)

	# Signal connections
	model_button.pressed.connect(_on_model_button_pressed)
	model_popup.id_pressed.connect(_on_model_selected)


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

	_update_status("Prechauffement...", MerlinVisual.LLM_STATUS.warning, 10)

	if not ClassDB.class_exists("MerlinLLM"):
		_update_status("MerlinLLM indisponible", MerlinVisual.LLM_STATUS.error, 0)
		return

	var llm := _get_or_load_model(current_model_path)
	if llm == null:
		_update_status("Erreur chargement", MerlinVisual.LLM_STATUS.error, 0)
		return

	_update_status("Chargement GPU...", MerlinVisual.LLM_STATUS.warning, 30)

	# Warmup minimal (1 token, juste pour primer le modele)
	if llm.has_method("set_sampling_params"):
		llm.set_sampling_params(0.1, 0.5, 1)

	var state := {"done": false}
	llm.generate_async("ok", func(_res):
		state.done = true
	)

	# Timeout + polling adaptatif (Godot Expert + Lead Godot)
	var timeout_ms := 30000  # 30 secondes max
	var start_time := Time.get_ticks_msec()
	var poll_count := 0

	while not state.done:
		if Time.get_ticks_msec() - start_time > timeout_ms:
			_update_status("Timeout warmup", MerlinVisual.LLM_STATUS.error, 0)
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
	_update_status("LLM Pret", MerlinVisual.LLM_STATUS.success, 100)


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
	if _status_icon:
		_status_icon.add_theme_color_override("font_color", color)
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
	var color: Color = MerlinVisual.LLM_STATUS.text
	if "OK" in status:
		color = MerlinVisual.LLM_STATUS.success
	elif "OFF" in status:
		color = MerlinVisual.LLM_STATUS.error
	elif "..." in status:
		color = MerlinVisual.LLM_STATUS.warning
	_update_status(detail, color, progress)


func _on_merlin_ready_changed(ready_state: bool) -> void:
	if ready_state:
		_update_status("LLM Pret", MerlinVisual.LLM_STATUS.success, 100)
	else:
		_update_status("LLM Deconnecte", MerlinVisual.LLM_STATUS.error, 0)


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
