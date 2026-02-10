extends Control

@onready var status_label: Label = $Main/Top/StatusLabel
@onready var detail_label: Label = $Main/Top/DetailLabel
@onready var progress_bar: ProgressBar = $Main/Top/ProgressBar
@onready var log_text: TextEdit = $Main/Logs/LogText
@onready var copy_button: Button = $Main/Logs/CopyButton
@onready var reload_button: Button = $Main/Top/ReloadButton

@onready var router_temp: SpinBox = $Main/Params/RouterBox/RouterVBox/TempRow/TempSpin
@onready var router_top_p: SpinBox = $Main/Params/RouterBox/RouterVBox/TopPRow/TopPSpin
@onready var router_max: SpinBox = $Main/Params/RouterBox/RouterVBox/MaxRow/MaxTokensSpin

@onready var exec_temp: SpinBox = $Main/Params/ExecutorBox/ExecutorVBox/TempRow/TempSpin
@onready var exec_top_p: SpinBox = $Main/Params/ExecutorBox/ExecutorVBox/TopPRow/TopPSpin
@onready var exec_max: SpinBox = $Main/Params/ExecutorBox/ExecutorVBox/MaxRow/MaxTokensSpin

@onready var prompt_field: LineEdit = $Main/Prompt/PromptField
@onready var route_button: Button = $Main/Prompt/PromptButtons/RouteButton
@onready var execute_button: Button = $Main/Prompt/PromptButtons/ExecuteButton
@onready var output_text: RichTextLabel = $Main/Prompt/OutputText

var merlin_ai: Node = null

func _ready() -> void:
	merlin_ai = get_node_or_null("/root/MerlinAI")
	if merlin_ai:
		merlin_ai.status_changed.connect(_on_status_changed)
		merlin_ai.log_updated.connect(_on_log_updated)
		var status: Dictionary = merlin_ai.get_status()
		_on_status_changed(str(status.status), str(status.detail), float(status.progress))
		_on_log_updated(merlin_ai.get_log_text())
		_load_params()
	copy_button.pressed.connect(_on_copy_pressed)
	reload_button.pressed.connect(_on_reload_pressed)
	route_button.pressed.connect(_on_route_pressed)
	execute_button.pressed.connect(_on_execute_pressed)

func _load_params() -> void:
	if not merlin_ai:
		return
	var router = merlin_ai.get_router_params()
	var exec = merlin_ai.get_executor_params()
	router_temp.value = float(router.temperature)
	router_top_p.value = float(router.top_p)
	router_max.value = int(router.max_tokens)
	exec_temp.value = float(exec.temperature)
	exec_top_p.value = float(exec.top_p)
	exec_max.value = int(exec.max_tokens)

func _on_status_changed(status_text: String, detail_text: String, progress_value: float) -> void:
	status_label.text = status_text
	detail_label.text = detail_text
	progress_bar.value = clampf(progress_value, 0.0, 100.0)

func _on_log_updated(text: String) -> void:
	log_text.text = text
	log_text.scroll_vertical = log_text.get_line_count()

func _on_copy_pressed() -> void:
	if merlin_ai and merlin_ai.has_method("get_log_text"):
		DisplayServer.clipboard_set(merlin_ai.get_log_text())

func _on_reload_pressed() -> void:
	if merlin_ai and merlin_ai.has_method("reload_models"):
		merlin_ai.reload_models()

func _apply_params() -> void:
	if not merlin_ai:
		return
	merlin_ai.set_router_params(router_temp.value, router_top_p.value, int(router_max.value))
	merlin_ai.set_executor_params(exec_temp.value, exec_top_p.value, int(exec_max.value))

func _on_route_pressed() -> void:
	_apply_params()
	output_text.text = "[i]Routeur en cours...[/i]"
	var text = prompt_field.text.strip_edges()
	if text == "":
		return
	var category = await merlin_ai.debug_route_input(text)
	output_text.text = "[b]Categorie:[/b] " + str(category)

func _on_execute_pressed() -> void:
	_apply_params()
	output_text.text = "[i]Executeur en cours...[/i]"
	var text = prompt_field.text.strip_edges()
	if text == "":
		return
	var result: Dictionary = await merlin_ai.debug_execute_input(text)
	output_text.text = "[b]Response:[/b]\n" + str(result.get("response", "")) + "\n\n[b]Action:[/b]\n" + str(result.get("action", null))
