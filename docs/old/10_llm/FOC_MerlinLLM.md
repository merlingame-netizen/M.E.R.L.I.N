# FOC - Merlin LLM (Godot)

Document de synthese + scripts integres, pret a deposer.

## Contexte
- LLM local sans serveur HTTP (GDExtension MerlinLLM)
- Router: Llama 3.2 3B (GGUF)
- Executor: Qwen 2.5 7B (GGUF)
- UI Test: scene TestMerlinGBA

## Scripts integres
### addons/merlin_ai/merlin_ai.gd
```gdscript
extends Node

signal response_received(response: Dictionary)
signal action_executed(action: Dictionary)
signal error_occurred(message: String)
signal status_changed(status_text: String, detail_text: String, progress_value: float)
signal ready_changed(is_ready: bool)
signal log_updated(log_text: String)

const ROUTER_FILE := "res://addons/merlin_llm/models/llama-3.2-3b-instruct-q6_k.gguf"
const EXECUTOR_FILE := "res://addons/merlin_llm/models/qwen2.5-7b-instruct-q5_k_m.gguf"

const PROMPTS_PATH := "res://data/ai/config/prompts.json"
const ACTIONS_PATH := "res://data/ai/config/actions.json"

var rag_manager: RAGManager
var action_validator: ActionValidator
var game_state_sync: GameStateSync

var router_llm: Object = null
var executor_llm: Object = null
var router_params := {"temperature": 0.3, "top_p": 0.9, "max_tokens": 64}
var executor_params := {"temperature": 0.7, "top_p": 0.9, "max_tokens": 512}

var prompts: Dictionary = {}
var is_ready := false
var status_text := "Connexion: OFF"
var detail_text := "Initialisation..."
var progress_value := 0.0
var log_entries: Array[String] = []
var _last_log_line := ""

func _ready() -> void:
	rag_manager = RAGManager.new()
	action_validator = ActionValidator.new()
	game_state_sync = GameStateSync.new()
	add_child(rag_manager)
	add_child(action_validator)
	add_child(game_state_sync)
	_load_prompts()
	_init_local_models()

func process_player_input(input_text: String) -> void:
	if not is_ready:
		_set_status("Connexion: OFF", "Modeles non charges", 0.0)
		error_occurred.emit("Modeles non charges")
		return
	var category = await _route_input(input_text)
	var context = await rag_manager.get_relevant_context(input_text, category)
	var result = await _execute_with_context(input_text, context, category)
	if result.has("action") and result.action != null:
		var validated = action_validator.validate(result.action)
		if validated.valid:
			game_state_sync.apply_action(result.action)
			action_executed.emit(result.action)
		else:
			_log("Action invalide: " + JSON.stringify(validated.errors))
	rag_manager.add_to_history(input_text, str(result.get("response", "")))
	response_received.emit(result)

func debug_route_input(input_text: String) -> String:
	if not is_ready:
		return "LLM non pret"
	return await _route_input(input_text)

func debug_execute_input(input_text: String) -> Dictionary:
	if not is_ready:
		return {"response": "LLM non pret", "action": null}
	var category = await _route_input(input_text)
	var context = await rag_manager.get_relevant_context(input_text, category)
	return await _execute_with_context(input_text, context, category)

func _route_input(input_text: String) -> String:
	var system = prompts.get("router_system", "")
	var template = prompts.get("router_template", "{input}")
	var prompt = template.format({"system": system, "input": input_text})
	var result = await _run_llm(router_llm, prompt, router_params)
	if result.has("error"):
		_log("Routeur erreur: " + str(result.error))
		return "dialogue"
	return _parse_category(str(result.get("text", "")))

func _execute_with_context(input_text: String, context: Dictionary, category: String) -> Dictionary:
	var system = prompts.get("executor_system", "")
	var template = prompts.get("executor_template", "{input}")
	var actions = _get_actions_blob(category)
	var sys = system.format({"actions": actions, "context": JSON.stringify(context)})
	var prompt = template.format({"system": sys, "input": input_text})
	var result = await _run_llm(executor_llm, prompt, executor_params)
	if result.has("error"):
		return {"response": "Erreur executeur: " + str(result.error), "action": null}
	return _parse_executor_response(str(result.get("text", "")))

func _run_llm(llm: Object, prompt: String, params: Dictionary) -> Dictionary:
	if llm == null:
		return {"error": "LLM manquant"}
	if llm.has_method("set_sampling_params"):
		llm.set_sampling_params(float(params.temperature), float(params.top_p), int(params.max_tokens))
	var state = {"done": false, "result": {}}
	llm.generate_async(prompt, func(res):
		state.result = res
		state.done = true
	)
	while not state.done:
		llm.poll_result()
		await get_tree().process_frame
	return state.result

func _parse_category(response: String) -> String:
	var clean = response.strip_edges().to_lower()
	var allowed = ["combat", "dialogue", "exploration", "inventaire", "magie", "quete"]
	for c in allowed:
		if clean.find(c) != -1:
			return c
	return "dialogue"

func _parse_executor_response(response: String) -> Dictionary:
	var json = JSON.new()
	if json.parse(response) == OK and json.data is Dictionary:
		return json.data
	return {"response": response, "action": null}

func _get_actions_blob(category: String) -> String:
	if FileAccess.file_exists(ACTIONS_PATH):
		var file = FileAccess.open(ACTIONS_PATH, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(data) == TYPE_DICTIONARY and data.has("categories") and data.categories.has(category):
			return JSON.stringify(data.categories[category])
	return "{}"

func _load_prompts() -> void:
	if FileAccess.file_exists(PROMPTS_PATH):
		var file = FileAccess.open(PROMPTS_PATH, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(data) == TYPE_DICTIONARY:
			prompts = data

func _init_local_models() -> void:
	_set_status("Connexion: ...", "Preparation des modeles", 5.0)
	if not ClassDB.class_exists("MerlinLLM"):
		_set_status("Connexion: OFF", "Classe MerlinLLM absente (GDExtension)", 0.0)
		ready_changed.emit(false)
		return
	if not FileAccess.file_exists(ROUTER_FILE):
		_set_status("Connexion: OFF", "Router manquant: " + ROUTER_FILE, 0.0)
		ready_changed.emit(false)
		return
	if not FileAccess.file_exists(EXECUTOR_FILE):
		_set_status("Connexion: OFF", "Executor manquant: " + EXECUTOR_FILE, 0.0)
		ready_changed.emit(false)
		return
	_set_status("Connexion: ...", "Chargement routeur", 15.0)
	router_llm = ClassDB.instantiate("MerlinLLM")
	var router_path = _to_fs_path(ROUTER_FILE)
	var router_err = router_llm.load_model(router_path)
	_set_status("Connexion: ...", "Chargement executeur", 60.0)
	executor_llm = ClassDB.instantiate("MerlinLLM")
	var exec_path = _to_fs_path(EXECUTOR_FILE)
	var exec_err = executor_llm.load_model(exec_path)
	if router_err != OK or exec_err != OK:
		_log("Router load err: " + str(router_err) + " path=" + router_path)
		_log("Executor load err: " + str(exec_err) + " path=" + exec_path)
		_set_status("Connexion: OFF", "Erreur chargement modele", 0.0)
		ready_changed.emit(false)
		return
	_set_status("Connexion: OK", "Modeles charges", 100.0)
	is_ready = true
	ready_changed.emit(true)
	_log("Router OK: " + ROUTER_FILE)
	_log("Executor OK: " + EXECUTOR_FILE)

func _to_fs_path(path: String) -> String:
	return ProjectSettings.globalize_path(path)

func reload_models() -> void:
	_init_local_models()

func ensure_ready() -> void:
	if not is_ready:
		_init_local_models()

func generate_with_system(system_prompt: String, user_input: String, params_override: Dictionary = {}) -> Dictionary:
	if not is_ready:
		return {"error": "LLM non pret"}
	var template = prompts.get("executor_template", "{system}\n{input}")
	var prompt = template.format({"system": system_prompt, "input": user_input})
	var params = executor_params.duplicate(true)
	for key in params_override.keys():
		params[key] = params_override[key]
	return await _run_llm(executor_llm, prompt, params)

func set_router_params(temp: float, top_p: float, max_tokens: int) -> void:
	router_params.temperature = temp
	router_params.top_p = top_p
	router_params.max_tokens = max_tokens
	_log("Router params: T=" + str(temp) + " top_p=" + str(top_p) + " max=" + str(max_tokens))

func set_executor_params(temp: float, top_p: float, max_tokens: int) -> void:
	executor_params.temperature = temp
	executor_params.top_p = top_p
	executor_params.max_tokens = max_tokens
	_log("Executor params: T=" + str(temp) + " top_p=" + str(top_p) + " max=" + str(max_tokens))

func get_router_params() -> Dictionary:
	return router_params.duplicate(true)

func get_executor_params() -> Dictionary:
	return executor_params.duplicate(true)

func get_status() -> Dictionary:
	return {"status": status_text, "detail": detail_text, "progress": progress_value, "ready": is_ready}

func get_log_text() -> String:
	return "\n".join(log_entries)

func _set_status(status: String, detail: String, progress: float) -> void:
	status_text = status
	detail_text = detail
	progress_value = clampf(progress, 0.0, 100.0)
	_log(status + " | " + detail)
	status_changed.emit(status_text, detail_text, progress_value)
	log_updated.emit(get_log_text())

func _log(message: String) -> void:
	var now = Time.get_datetime_dict_from_system()
	var stamp = "%02d:%02d:%02d" % [now.hour, now.minute, now.second]
	var line = stamp + " - " + message
	if line == _last_log_line:
		return
	_last_log_line = line
	log_entries.append(line)
	if log_entries.size() > 200:
		log_entries = log_entries.slice(log_entries.size() - 200, log_entries.size())

```

### addons/merlin_ai/llm_client.gd
```gdscript
extends Node
class_name LLMClient

signal request_completed(response: String)
signal request_failed(error: String)

var _models: Dictionary = {}

func complete(prompt: String, model_path: String, max_tokens: int = 256) -> String:
	if not ClassDB.class_exists("MerlinLLM"):
		request_failed.emit("MerlinLLM indisponible (GDExtension manquante)")
		return ""
	if not FileAccess.file_exists(model_path):
		request_failed.emit("Modele introuvable: " + model_path)
		return ""
	var llm: Object = _get_or_load_model(model_path)
	if llm == null:
		request_failed.emit("Impossible de charger le modele")
		return ""
	if llm.has_method("set_sampling_params"):
		llm.set_sampling_params(0.7, 0.9, max_tokens)
	var state := {"done": false, "result": {}}
	llm.generate_async(prompt, func(res):
		state.result = res
		state.done = true
	)
	while not state.done:
		llm.poll_result()
		await get_tree().process_frame
	var text := _extract_text(state.result)
	request_completed.emit(text)
	return text

func ping(model_path: String) -> bool:
	return ClassDB.class_exists("MerlinLLM") and FileAccess.file_exists(model_path)

func _get_or_load_model(model_path: String) -> Object:
	if _models.has(model_path):
		return _models[model_path]
	var llm = ClassDB.instantiate("MerlinLLM")
	var err = llm.load_model(_to_fs_path(model_path))
	if typeof(err) == TYPE_INT and int(err) != OK:
		return null
	_models[model_path] = llm
	return llm

func _extract_text(result) -> String:
	if typeof(result) == TYPE_DICTIONARY:
		if result.has("text"):
			return str(result.text)
		if result.has("lines") and result.lines.size() > 0:
			return str(result.lines[0])
	return str(result)

func _to_fs_path(path: String) -> String:
	return ProjectSettings.globalize_path(path)

```

### addons/merlin_ai/rag_manager.gd
```gdscript
extends Node
class_name RAGManager

const HISTORY_PATH := "user://ai/memory/history.json"
const WORLD_STATE_PATH := "user://ai/memory/world_state.json"
const EVENTS_PATH := "user://ai/memory/events.json"
const MAX_HISTORY_ITEMS := 100

var history: Array = []
var world_state: Dictionary = {}
var actions_by_category: Dictionary = {}

func _ready() -> void:
	_ensure_storage()
	_load_history()
	_load_world_state()
	_load_actions()

func get_relevant_context(query: String, category: String) -> Dictionary:
	var context = {
		"recent_history": _get_recent_history(5),
		"relevant_history": _search_history(query, 3),
		"world_state_subset": _get_relevant_state(query),
		"available_actions": _get_actions_for_category(category)
	}
	return context

func _get_recent_history(count: int) -> Array:
	return history.slice(-count) if history.size() >= count else history

func _search_history(query: String, count: int) -> Array:
	var keywords = query.to_lower().split(" ")
	var scored: Array = []
	for item in history:
		var score = 0
		var text = (str(item.get("input", "")) + " " + str(item.get("response", ""))).to_lower()
		for kw in keywords:
			if kw.length() > 3 and text.contains(kw):
				score += 1
		if score > 0:
			scored.append({"item": item, "score": score})
	scored.sort_custom(func(a, b): return a.score > b.score)
	return scored.slice(0, count).map(func(x): return x.item)

func _get_relevant_state(_query: String) -> Dictionary:
	return world_state

func _get_actions_for_category(category: String) -> Array:
	if actions_by_category.has(category):
		return actions_by_category[category]
	return []

func add_to_history(input: String, response: String) -> void:
	history.append({
		"timestamp": Time.get_unix_time_from_system(),
		"input": input,
		"response": response
	})
	if history.size() > MAX_HISTORY_ITEMS:
		history = history.slice(-MAX_HISTORY_ITEMS)
	_save_history()

func update_world_state(key: String, value) -> void:
	world_state[key] = value
	_save_world_state()

func _load_actions() -> void:
	var path = "res://data/ai/config/actions.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(data) == TYPE_DICTIONARY and data.has("categories"):
			actions_by_category = data.categories

func _save_history() -> void:
	var file = FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(history))
	file.close()

func _load_history() -> void:
	if FileAccess.file_exists(HISTORY_PATH):
		var file = FileAccess.open(HISTORY_PATH, FileAccess.READ)
		history = JSON.parse_string(file.get_as_text())
		file.close()

func _save_world_state() -> void:
	var file = FileAccess.open(WORLD_STATE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(world_state))
	file.close()

func _load_world_state() -> void:
	if FileAccess.file_exists(WORLD_STATE_PATH):
		var file = FileAccess.open(WORLD_STATE_PATH, FileAccess.READ)
		world_state = JSON.parse_string(file.get_as_text())
		file.close()

func _ensure_storage() -> void:
	var base_dir = "user://ai/memory"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))

```

### addons/merlin_ai/action_validator.gd
```gdscript
extends Node
class_name ActionValidator

var actions_schema: Dictionary = {}
var game_state_ref: Dictionary = {}

func _ready() -> void:
	_load_actions_schema()

func validate(action: Dictionary) -> Dictionary:
	var result = {"valid": false, "errors": []}
	if not action.has("type"):
		result.errors.append("Missing action type")
		return result
	var action_type = action.type
	if not actions_schema.has(action_type):
		result.errors.append("Unknown action type: " + str(action_type))
		return result
	var schema = actions_schema[action_type]
	if schema.has("params"):
		for param in schema.params:
			if not action.has("params") or not action.params.has(param):
				result.errors.append("Missing param: " + str(param))
	if schema.has("conditions"):
		for condition in schema.conditions:
			if not _check_condition(condition, action):
				result.errors.append("Condition failed: " + str(condition))
	result.valid = result.errors.is_empty()
	return result

func _check_condition(condition: String, action: Dictionary) -> bool:
	match condition:
		"target_in_range":
			return _check_target_in_range(str(action.params.get("target_id", "")))
		"has_mana":
			return int(game_state_ref.get("player_mana", 0)) > 0
		"spell_known":
			return action.params.get("spell_id", "") in game_state_ref.get("known_spells", [])
		_:
			return true

func _check_target_in_range(_target_id: String) -> bool:
	return true

func _load_actions_schema() -> void:
	var path = "res://data/ai/config/actions.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(data) == TYPE_DICTIONARY and data.has("categories"):
			for cat in data.categories.keys():
				var items: Dictionary = data.categories[cat]
				for key in items.keys():
					actions_schema[key] = items[key]

```

### addons/merlin_ai/game_state_sync.gd
```gdscript
extends Node
class_name GameStateSync

var state: Dictionary = {}

func apply_action(action: Dictionary) -> void:
	# Placeholder: hook into your game systems.
	state["last_action"] = action

```

### scripts/TestMerlinGBA.gd
```gdscript
extends Control

# Minimal Test Merlin GBA: simple dialogue + knowledge test.

const SYSTEM_DIALOGUE := "Tu es Merlin, druide de Broceliande. Reponds en francais sans accents, ASCII uniquement. Une phrase courte (max 120 caracteres). Ton celtique, bienveillant, un peu espiegle. Pas d anglais, pas de balises, pas de tokens."
const SYSTEM_KNOWLEDGE := "Tu es un assistant factuel. Reponds en francais simple et court (max 110 caracteres). Si tu ne sais pas, dis-le. Pas d anglais, pas de balises."
const HISTORY_LIMIT := 6
const LOADING_FRAMES := [" .", " ..", " ..."]

@onready var llm_title: Label = $LLMPanel/LLMVBox/TitleLabel
@onready var status_label: Label = $LLMPanel/LLMVBox/StatusLabel
@onready var detail_label: Label = $LLMPanel/LLMVBox/DetailLabel
@onready var progress_bar: ProgressBar = $LLMPanel/LLMVBox/ProgressBar
@onready var reload_button: Button = $LLMPanel/LLMVBox/ButtonsRow/ReloadButton
@onready var copy_button: Button = $LLMPanel/LLMVBox/ButtonsRow/CopyButton
@onready var diag_button: Button = $LLMPanel/LLMVBox/ButtonsRow/DiagButton
@onready var log_text: TextEdit = $LLMPanel/LLMVBox/LogText

@onready var chat_text: RichTextLabel = $ChatPanel/ChatVBox/ChatScroll/ChatText
@onready var mode_option: OptionButton = $InputPanel/InputHBox/ModeOption
@onready var input_field: LineEdit = $InputPanel/InputHBox/InputField
@onready var send_button: Button = $InputPanel/InputHBox/SendButton
@onready var clear_button: Button = $InputPanel/InputHBox/ClearButton

var merlin_ai: Node = null
var history: Array = []
var is_busy := false
var chat_lines: Array[String] = []
var loading_timer: Timer = null
var loading_active := false
var loading_index := -1
var loading_tick := 0
var loading_stamp := ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bind_merlin_ai()
	_setup_mode()
	_bind_ui()
	if llm_title:
		llm_title.text = "LLM Router: Llama 3.2 3B\nLLM Exec: Qwen 2.5 7B"
	if chat_text:
		chat_text.bbcode_enabled = true
		chat_text.add_theme_color_override("default_color", Color(0.95, 0.92, 0.86))
		chat_text.add_theme_font_size_override("normal_font_size", 14)
	else:
		push_warning("ChatText introuvable dans TestMerlinGBA.")
	if input_field:
		input_field.editable = true
		input_field.grab_focus()
	_init_loading_timer()
	_append_chat("[i]Pret. Ecris une question pour Merlin.[/i]")
	_run_diagnostic(false)

func _bind_merlin_ai() -> void:
	merlin_ai = get_node_or_null("/root/MerlinAI")
	if merlin_ai:
		merlin_ai.status_changed.connect(_on_llm_status_changed)
		if merlin_ai.has_signal("log_updated"):
			merlin_ai.log_updated.connect(_on_llm_log_updated)
		var status: Dictionary = merlin_ai.get_status()
		_on_llm_status_changed(str(status.status), str(status.detail), float(status.progress))
		if merlin_ai.has_method("get_log_text"):
			_on_llm_log_updated(merlin_ai.get_log_text())
	else:
		_on_llm_status_changed("Connexion: OFF", "MerlinAI introuvable", 0.0)

func _setup_mode() -> void:
	mode_option.clear()
	mode_option.add_item("Dialogue Merlin")
	mode_option.add_item("Test connaissances")
	mode_option.select(0)

func _bind_ui() -> void:
	if send_button:
		send_button.pressed.connect(_on_send_pressed)
	if input_field:
		input_field.text_submitted.connect(_on_text_submitted)
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
	if reload_button:
		reload_button.pressed.connect(_on_reload_pressed)
	if copy_button:
		copy_button.pressed.connect(_on_copy_pressed)
	if diag_button:
		diag_button.pressed.connect(_on_diag_pressed)
	if send_button:
		send_button.disabled = false
	if clear_button:
		clear_button.disabled = false

func _on_llm_status_changed(status_text: String, detail_text: String, progress_value: float) -> void:
	status_label.text = status_text
	detail_label.text = detail_text
	progress_bar.value = clampf(progress_value, 0.0, 100.0)

func _on_llm_log_updated(text: String) -> void:
	log_text.text = text
	log_text.scroll_vertical = log_text.get_line_count()

func _on_reload_pressed() -> void:
	if merlin_ai and merlin_ai.has_method("reload_models"):
		merlin_ai.reload_models()

func _on_copy_pressed() -> void:
	if merlin_ai and merlin_ai.has_method("get_log_text"):
		DisplayServer.clipboard_set(merlin_ai.get_log_text())

func _on_text_submitted(_text: String) -> void:
	await _on_send_pressed()

func _on_send_pressed() -> void:
	var text = input_field.text.strip_edges()
	if text == "":
		return
	input_field.text = ""
	await _send_message(text)

func _on_clear_pressed() -> void:
	history.clear()
	chat_lines.clear()
	if chat_text:
		chat_text.clear()
	_append_chat("[i]Historique efface.[/i]")

func _send_message(text: String) -> void:
	if is_busy:
		return
	if merlin_ai == null:
		_append_chat(_stamp() + " [color=red]MerlinAI indisponible.[/color]")
		return
	is_busy = true
	_set_input_busy(true)
	_append_chat(_stamp() + " [b]Vous:[/b] " + text)
	_start_loading()
	var system_prompt = SYSTEM_DIALOGUE
	var complex = _is_complex_request(text)
	var params := {"temperature": 0.35, "top_p": 0.75, "max_tokens": 96}
	if mode_option.selected == 1:
		system_prompt = SYSTEM_KNOWLEDGE
		params.temperature = 0.1
		params.top_p = 0.6
		params.max_tokens = 64
	if complex:
		system_prompt += " Si la question demande des details, reponds: 'Bien sur, mon ami, les voici:' puis 3 a 6 points numerotes sur une ligne chacun."
		params.max_tokens = 220

	var prompt = _build_prompt(text)
	var result: Dictionary = await merlin_ai.generate_with_system(system_prompt, prompt, params)
	var answer = _clean_response(_extract_text(result), complex)
	if answer == "":
		answer = "(reponse vide)"
	if complex:
		var lines = _split_multiline(answer)
		if lines.size() == 0:
			lines = [answer]
		_finish_loading(lines[0])
		for i in range(1, lines.size()):
			await get_tree().create_timer(0.12).timeout
			_append_chat(_stamp() + " [b]Merlin:[/b] " + lines[i])
		answer = "\n".join(lines)
	else:
		_finish_loading(answer)
	if result.has("error"):
		_append_chat(_stamp() + " [color=red]Erreur LLM: " + str(result.error) + "[/color]")
	_push_history("user", text)
	_push_history("assistant", answer)
	is_busy = false
	_set_input_busy(false)

func _build_prompt(latest: String) -> String:
	var lines: Array[String] = []
	for item in history:
		var prefix = "M:" if item.role == "assistant" else "U:"
		lines.append(prefix + " " + item.content)
	lines.append("U: " + latest)
	return "\n".join(lines)

func _push_history(role: String, content: String) -> void:
	history.append({"role": role, "content": content})
	if history.size() > HISTORY_LIMIT:
		history = history.slice(history.size() - HISTORY_LIMIT, history.size())

func _extract_text(result: Dictionary) -> String:
	if result.has("error"):
		return "Erreur: " + str(result.error)
	if result.has("text"):
		return str(result.text).strip_edges()
	if result.has("lines") and result.lines is Array and result.lines.size() > 0:
		return str(result.lines[0]).strip_edges()
	return str(result).strip_edges()

func _append_chat(line: String) -> void:
	if chat_text == null:
		return
	chat_lines.append(line)
	_refresh_chat()

func _set_chat_line(index: int, line: String) -> void:
	if chat_text == null:
		return
	if index < 0 or index >= chat_lines.size():
		return
	chat_lines[index] = line
	_refresh_chat()

func _refresh_chat() -> void:
	if chat_text == null:
		return
	if chat_lines.size() > 200:
		var start = max(0, chat_lines.size() - 200)
		chat_lines = chat_lines.slice(start, chat_lines.size())
		if loading_index >= 0:
			loading_index = max(-1, loading_index - start)
	var joined = "\n".join(chat_lines)
	chat_text.clear()
	chat_text.parse_bbcode(joined)
	chat_text.scroll_to_line(chat_text.get_line_count())

func _clean_response(text: String, allow_multi: bool = false) -> String:
	var cleaned = text
	# Remove common chat template tokens
	cleaned = cleaned.replace("<|im_start|>", "")
	cleaned = cleaned.replace("<|im_end|>", "")
	cleaned = cleaned.replace("<|endoftext|>", "")
	cleaned = cleaned.replace("<|eot_id|>", "")
	# Truncate if the model leaks a new role
	var role_markers = ["Human:", "User:", "Assistant:"]
	for marker in role_markers:
		var idx = cleaned.find(marker)
		if idx != -1:
			cleaned = cleaned.substr(0, idx).strip_edges()
	# Remove stray role prefixes
	var lines = cleaned.split("\n")
	var kept: Array[String] = []
	for line in lines:
		var l = line.strip_edges()
		if l == "":
			continue
		if l.begins_with("Human:") or l.begins_with("Assistant:") or l.begins_with("User:"):
			l = l.substr(l.find(":") + 1).strip_edges()
		if l.contains("<|"):
			continue
		kept.append(l)
	cleaned = " ".join(kept).strip_edges()
	if allow_multi:
		cleaned = _force_numbered_lines(cleaned)
	else:
		# Keep only the first sentence
		cleaned = _first_sentence(cleaned)
	# Hard cap length
	if cleaned.length() > 240 and allow_multi:
		cleaned = cleaned.substr(0, 240).strip_edges()
	elif cleaned.length() > 140:
		cleaned = cleaned.substr(0, 140).strip_edges()
	cleaned = _ascii_only(cleaned)
	if _looks_english(cleaned):
		cleaned = "Je parle en francais. Pose ta question, voyageur."
	return cleaned

func _force_numbered_lines(text: String) -> String:
	var out = text
	if not out.to_lower().begins_with("bien sur"):
		out = "Bien sur, mon ami, les voici: " + out
	for i in range(1, 10):
		out = out.replace(" %d)" % i, "\n%d)" % i)
		out = out.replace(" %d." % i, "\n%d." % i)
	return out

func _split_multiline(text: String) -> Array[String]:
	var parts = text.split("\n")
	var cleaned: Array[String] = []
	for p in parts:
		var line = p.strip_edges()
		if line == "":
			continue
		cleaned.append(line)
	return cleaned

func _first_sentence(text: String) -> String:
	var best_idx := -1
	for sep in [".", "!", "?"]:
		var idx = text.find(sep)
		if idx != -1 and (best_idx == -1 or idx < best_idx):
			best_idx = idx
	if best_idx != -1:
		return text.substr(0, best_idx + 1).strip_edges()
	return text.strip_edges()

func _ascii_only(text: String) -> String:
	var out := ""
	for i in text.length():
		var code = text.unicode_at(i)
		if code >= 32 and code <= 126:
			out += text[i]
	return out

func _looks_english(text: String) -> bool:
	var lower = text.to_lower()
	var markers = [" the ", " and ", " you ", " your ", " can you", " article", "summary", "summarize", "renewable"]
	for m in markers:
		if lower.find(m) != -1:
			return true
	return false

func _is_complex_request(text: String) -> bool:
	var t = text.to_lower()
	var keywords = ["regles", "explique", "expliquer", "details", "detail", "liste", "exemples", "plusieurs", "etapes", "comment", "pourquoi", "donne"]
	for k in keywords:
		if t.find(k) != -1:
			return true
	return t.length() > 70

func _stamp() -> String:
	var now = Time.get_datetime_dict_from_system()
	return "[%02d:%02d:%02d]" % [now.hour, now.minute, now.second]

func _init_loading_timer() -> void:
	if loading_timer != null:
		return
	loading_timer = Timer.new()
	loading_timer.wait_time = 0.35
	loading_timer.one_shot = false
	add_child(loading_timer)
	loading_timer.timeout.connect(_on_loading_tick)

func _start_loading() -> void:
	loading_active = true
	loading_tick = 0
	loading_stamp = _stamp()
	var line = loading_stamp + " [b]Merlin:[/b]" + LOADING_FRAMES[loading_tick]
	_append_chat(line)
	loading_index = chat_lines.size() - 1
	if loading_timer:
		loading_timer.start()

func _on_loading_tick() -> void:
	if not loading_active:
		return
	loading_tick = (loading_tick + 1) % LOADING_FRAMES.size()
	var line = loading_stamp + " [b]Merlin:[/b]" + LOADING_FRAMES[loading_tick]
	_set_chat_line(loading_index, line)

func _finish_loading(answer: String) -> void:
	loading_active = false
	if loading_timer:
		loading_timer.stop()
	if loading_index == -1:
		_append_chat(_stamp() + " [b]Merlin:[/b] " + answer)
	else:
		_set_chat_line(loading_index, _stamp() + " [b]Merlin:[/b] " + answer)
	loading_index = -1

func _set_input_busy(flag: bool) -> void:
	if input_field:
		input_field.editable = not flag
	if send_button:
		send_button.disabled = flag

func _on_diag_pressed() -> void:
	_run_diagnostic(true)

func _run_diagnostic(verbose: bool) -> void:
	var lines: Array[String] = []
	lines.append("[b]Diagnostic MerlinAI[/b]")
	lines.append("MerlinAI present: " + str(merlin_ai != null))
	if merlin_ai:
		var status: Dictionary = merlin_ai.get_status()
		lines.append("Status: " + str(status.get("status", "")))
		lines.append("Detail: " + str(status.get("detail", "")))
		lines.append("Ready: " + str(status.get("ready", false)))
	var router_path = "res://addons/merlin_llm/models/llama-3.2-3b-instruct-q6_k.gguf"
	var exec_path = "res://addons/merlin_llm/models/qwen2.5-7b-instruct-q5_k_m.gguf"
	lines.append("Router file: " + str(FileAccess.file_exists(router_path)))
	lines.append("Exec file: " + str(FileAccess.file_exists(exec_path)))
	lines.append("Router abs: " + ProjectSettings.globalize_path(router_path))
	lines.append("Exec abs: " + ProjectSettings.globalize_path(exec_path))
	_append_chat("\n".join(lines))

```

## Modeles attendus
- res://addons/merlin_llm/models/llama-3.2-3b-instruct-q6_k.gguf
- res://addons/merlin_llm/models/qwen2.5-7b-instruct-q5_k_m.gguf

## Notes d execution
- Autoload: MerlinAI (addons/merlin_ai/merlin_ai.gd)
- Scene de test: TestMerlinGBA.tscn + scripts/TestMerlinGBA.gd

