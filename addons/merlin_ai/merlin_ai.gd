extends Node

signal response_received(response: Dictionary)
signal action_executed(action: Dictionary)
signal error_occurred(message: String)
signal status_changed(status_text: String, detail_text: String, progress_value: float)
signal ready_changed(is_ready: bool)
signal log_updated(log_text: String)

# ARCHITECTURE SIMPLIFIEE
# Router + executor = meme modele 3B (gain d'espace)
const ROUTER_FILE := "res://addons/merlin_llm/models/qwen2.5-3b-instruct-q4_k_m.gguf"
const EXECUTOR_FILE := "res://addons/merlin_llm/models/qwen2.5-3b-instruct-q4_k_m.gguf"
# IMPORTANT: modele unique (pas de fallback)
const ROUTER_CANDIDATES := [
    ROUTER_FILE
]
const EXECUTOR_CANDIDATES := [
    EXECUTOR_FILE
]
const FastRoute = preload("res://addons/merlin_ai/fast_route.gd")

const PROMPTS_PATH := "res://data/ai/config/prompts.json"
const ACTIONS_PATH := "res://data/ai/config/actions.json"

var rag_manager: RAGManager
var action_validator: ActionValidator
var game_state_sync: GameStateSync

var router_llm: Object = null
var executor_llm: Object = null
# Paramètres alignés avec Colab (Qwen 3B optimal)
var router_params := {"temperature": 0.6, "top_p": 0.9, "max_tokens": 128, "top_k": 50, "repetition_penalty": 1.1}
var executor_params := {"temperature": 0.7, "top_p": 0.9, "max_tokens": 512, "top_k": 50, "repetition_penalty": 1.1}

var prompts: Dictionary = {}
var is_ready := false
var status_text := "Connexion: OFF"
var detail_text := "Initialisation..."
var progress_value := 0.0
var log_entries: Array[String] = []
var _last_log_line := ""
var router_file_used := ROUTER_FILE
var executor_file_used := EXECUTOR_FILE
var response_cache: Dictionary = {}
const RESPONSE_CACHE_LIMIT := 50
var session_contexts: Dictionary = {}
const SESSION_HISTORY_LIMIT := 12
const STREAM_CHUNK_TOKENS := 32
const STREAM_MAX_ROUNDS := 6
var stats := {
	"fast_route_hits": 0,
	"fast_route_suggests": 0,
	"llm_route_calls": 0,
	"total_requests": 0,
	"last_ttft_ms": 0,
	"last_total_ms": 0,
	"avg_ttft_ms": 0.0,
	"avg_total_ms": 0.0,
	"llm_calls": 0
}

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
	stats.total_requests += 1
	if not is_ready:
		_set_status("Connexion: OFF", "Modeles non charges", 0.0)
		error_occurred.emit("Modeles non charges")
		return
	var fast_result := FastRoute.classify(input_text)
	var category: String
	if fast_result.confidence >= 0.6:
		category = fast_result.category
		stats.fast_route_hits += 1
		_log("FastRoute: '%s' -> %s (%.0f%%)" % [input_text.substr(0, 30), category, fast_result.confidence * 100.0])
	elif fast_result.confidence >= 0.3:
		category = fast_result.category
		stats.fast_route_suggests += 1
		_log("FastRoute suggest: '%s' -> %s (%.0f%%)" % [input_text.substr(0, 30), category, fast_result.confidence * 100.0])
	else:
		category = await _route_input(input_text)
		stats.llm_route_calls += 1
		_log("LLM Route: '%s' -> %s" % [input_text.substr(0, 30), category])
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

func get_routing_stats() -> Dictionary:
	var total = stats.total_requests
	if total == 0:
		return stats.duplicate(true)
	var result = stats.duplicate(true)
	result["fast_route_rate"] = "%.1f%%" % ((stats.fast_route_hits + stats.fast_route_suggests) / float(total) * 100.0)
	result["llm_route_rate"] = "%.1f%%" % (stats.llm_route_calls / float(total) * 100.0)
	return result

func reset_routing_stats() -> void:
	stats = {
		"fast_route_hits": 0,
		"fast_route_suggests": 0,
		"llm_route_calls": 0,
		"total_requests": 0,
		"last_ttft_ms": 0,
		"last_total_ms": 0,
		"avg_ttft_ms": 0.0,
		"avg_total_ms": 0.0,
		"llm_calls": 0
	}

func get_performance_stats() -> Dictionary:
	return {
		"last_ttft_ms": stats.last_ttft_ms,
		"last_total_ms": stats.last_total_ms,
		"avg_ttft_ms": "%.1f" % stats.avg_ttft_ms,
		"avg_total_ms": "%.1f" % stats.avg_total_ms,
		"llm_calls": stats.llm_calls,
		"tokens_per_sec": "%.1f" % (1000.0 / stats.avg_total_ms) if stats.avg_total_ms > 0 else "N/A"
	}

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
	# Prompt simplifie pour les petits modeles
	var system = prompts.get("executor_system", "Tu es Merlin, un sage druide. Reponds brievement.")
	var template = prompts.get("executor_template", "<|im_start|>system\n{system}<|im_end|>\n<|im_start|>user\n{input}<|im_end|>\n<|im_start|>assistant\n")
	var prompt = template.format({"system": system, "input": input_text})
	_log("Prompt envoye: " + prompt.substr(0, 100) + "...")
	var result = await _run_llm(executor_llm, prompt, executor_params)
	if result.has("error"):
		return {"response": "Erreur executeur: " + str(result.error), "action": null}
	var text = str(result.get("text", "")).strip_edges()
	_log("Reponse brute: " + text.substr(0, 100) + "...")
	return {"response": text, "action": null}

func _run_llm(llm: Object, prompt: String, params: Dictionary) -> Dictionary:
	if llm == null:
		return {"error": "LLM manquant"}
	var start_time = Time.get_ticks_msec()
	var ttft = 0
	var first_token_received = false
	if llm.has_method("set_sampling_params"):
		llm.set_sampling_params(float(params.temperature), float(params.top_p), int(params.max_tokens))
	# Nouveaux paramètres avancés (top_k, repetition_penalty)
	if llm.has_method("set_advanced_sampling"):
		var top_k = int(params.get("top_k", 50))
		var rep_penalty = float(params.get("repetition_penalty", 1.1))
		llm.set_advanced_sampling(top_k, rep_penalty)
	var state = {"done": false, "result": {}}
	llm.generate_async(prompt, func(res):
		if not first_token_received:
			ttft = Time.get_ticks_msec() - start_time
			first_token_received = true
		state.result = res
		state.done = true
	)
	while not state.done:
		llm.poll_result()
		await get_tree().process_frame
	var total_time = Time.get_ticks_msec() - start_time
	stats.last_ttft_ms = ttft
	stats.last_total_ms = total_time
	stats.llm_calls += 1
	stats.avg_ttft_ms = (stats.avg_ttft_ms * (stats.llm_calls - 1) + ttft) / float(stats.llm_calls)
	stats.avg_total_ms = (stats.avg_total_ms * (stats.llm_calls - 1) + total_time) / float(stats.llm_calls)
	_log("LLM timing: TTFT=%dms Total=%dms Tokens=%d" % [ttft, total_time, int(params.max_tokens)])
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
	router_file_used = _resolve_model_file(ROUTER_CANDIDATES)
	executor_file_used = _resolve_model_file(EXECUTOR_CANDIDATES)
	if router_file_used == "":
		_set_status("Connexion: OFF", "Router manquant (aucun modele)", 0.0)
		ready_changed.emit(false)
		return
	if executor_file_used == "":
		_set_status("Connexion: OFF", "Executor manquant (aucun modele)", 0.0)
		ready_changed.emit(false)
		return
	_set_status("Connexion: ...", "Chargement routeur", 15.0)
	router_llm = ClassDB.instantiate("MerlinLLM")
	var router_path = _to_fs_path(router_file_used)
	var router_err = router_llm.load_model(router_path)
	_set_status("Connexion: ...", "Chargement executeur", 60.0)
	executor_llm = ClassDB.instantiate("MerlinLLM")
	var exec_path = _to_fs_path(executor_file_used)
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
	_log("Router OK: " + router_file_used)
	_log("Executor OK: " + executor_file_used)

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
	var cache_key = _make_cache_key(system_prompt, user_input, params)
	if response_cache.has(cache_key):
		var cached = response_cache[cache_key]
		cached["source"] = "cache"
		return cached
	var result = await _run_llm(executor_llm, prompt, params)
	_store_cache(cache_key, result)
	return result

func generate_with_system_stream(system_prompt: String, user_input: String, params_override: Dictionary = {}, on_chunk: Callable = Callable()) -> Dictionary:
	if not is_ready:
		return {"error": "LLM non pret"}
	var template = prompts.get("executor_template", "{system}\n{input}")
	var base_prompt = template.format({"system": system_prompt, "input": user_input})
	var params_base = executor_params.duplicate(true)
	for key in params_override.keys():
		params_base[key] = params_override[key]
	var remaining = int(params_base.get("max_tokens", executor_params.max_tokens))
	var collected := ""
	var rounds := 0
	while remaining > 0 and rounds < STREAM_MAX_ROUNDS:
		var params = params_base.duplicate(true)
		params.max_tokens = min(STREAM_CHUNK_TOKENS, remaining)
		var prompt = base_prompt
		if collected != "":
			var tail = collected
			if tail.length() > 400:
				tail = tail.substr(tail.length() - 400, 400)
			prompt = base_prompt + "\n\nSuite (continue en francais, sans repeter):\n" + tail
		var result = await _run_llm(executor_llm, prompt, params)
		var text = str(result.get("text", "")).strip_edges()
		if text == "":
			break
		collected += text
		if on_chunk.is_valid():
			on_chunk.call(text, false)
		if _looks_complete(collected):
			break
		remaining -= params.max_tokens
		rounds += 1
	if on_chunk.is_valid():
		on_chunk.call("", true)
	return {"text": collected}

## Génère une réponse rapide avec le Router LLM (3B) - utilisé pour générer des choix de joueur
func generate_with_router(system_prompt: String, user_input: String, params_override: Dictionary = {}) -> Dictionary:
	if not is_ready:
		return {"error": "LLM non pret"}
	if router_llm == null:
		return {"error": "Router LLM non charge"}
	var template = prompts.get("executor_template", "{system}\n{input}")
	var prompt = template.format({"system": system_prompt, "input": user_input})
	var params = router_params.duplicate(true)
	for key in params_override.keys():
		params[key] = params_override[key]
	return await _run_llm(router_llm, prompt, params)

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

func get_model_info() -> Dictionary:
	return {
		"router": router_file_used,
		"executor": executor_file_used
	}

func get_log_text() -> String:
	return "\n".join(log_entries)

func clear_response_cache() -> void:
	response_cache.clear()

func add_session_entry(session_id: String, role: String, content: String, channel: String = "default") -> void:
	if session_id == "":
		return
	var session_map = _ensure_session_map(session_id)
	if not session_map.has(channel):
		session_map[channel] = []
	var arr: Array = session_map[channel]
	arr.append({"role": role, "content": content})
	if arr.size() > SESSION_HISTORY_LIMIT:
		arr = arr.slice(arr.size() - SESSION_HISTORY_LIMIT, arr.size())
	session_map[channel] = arr
	session_contexts[session_id] = session_map

func get_session_context(session_id: String, limit: int = 6, channel: String = "default") -> Array:
	var session_map = _ensure_session_map(session_id)
	var arr: Array = session_map.get(channel, [])
	if limit <= 0 or arr.is_empty():
		return []
	if arr.size() <= limit:
		return arr
	return arr.slice(arr.size() - limit, arr.size())

func get_session_channels(session_id: String) -> Array:
	var session_map = _ensure_session_map(session_id)
	return session_map.keys()

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

func _resolve_model_file(candidates: Array) -> String:
	for path in candidates:
		if FileAccess.file_exists(path):
			return path
	return ""

func _make_cache_key(system_prompt: String, user_input: String, params: Dictionary) -> String:
	var base = system_prompt + "\n" + user_input + "\n" + JSON.stringify(params)
	return str(base.hash())

func _store_cache(key: String, value: Dictionary) -> void:
	response_cache[key] = value
	if response_cache.size() > RESPONSE_CACHE_LIMIT:
		var keys = response_cache.keys()
		response_cache.erase(keys[0])

func _ensure_session_map(session_id: String) -> Dictionary:
	var entry = session_contexts.get(session_id, null)
	if entry == null:
		entry = {"default": []}
	elif entry is Array:
		entry = {"default": entry}
	elif typeof(entry) != TYPE_DICTIONARY:
		entry = {"default": []}
	session_contexts[session_id] = entry
	return entry

func _looks_complete(text: String) -> bool:
	var trimmed = text.strip_edges()
	if trimmed.length() < 60:
		return false
	if trimmed.find("\n") != -1:
		return true
	if trimmed.ends_with(".") or trimmed.ends_with("!") or trimmed.ends_with("?"):
		return true
	return false
