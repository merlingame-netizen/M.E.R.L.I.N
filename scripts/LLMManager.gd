extends Node

# Global LLM manager (persist across scenes).

signal status_changed(status_text: String, detail_text: String, progress_value: float)
signal ready_changed(is_ready: bool)
signal log_updated(log_text: String)

const MODEL_PATH := "res://addons/merlin_llm/models/qwen2.5-3b-instruct-q4_k_m.gguf"
const RETRY_INTERVAL_SEC := 1.0
const LOG_LIMIT := 200

var llm_node: Object = null
var is_ready := false
var status_text := "Connexion: OFF"
var detail_text := "Initialisation..."
var progress_value := 0.0
var _retry_elapsed := 0.0
var log_entries: Array[String] = []
var _last_log_line := ""

func _ready() -> void:
	set_process(true)
	_init_llm()

func _process(delta: float) -> void:
	if is_ready:
		return
	_retry_elapsed += delta
	if _retry_elapsed >= RETRY_INTERVAL_SEC:
		_retry_elapsed = 0.0
		_init_llm()

func _init_llm() -> void:
	_set_status("Connexion: ...", "Chargement modele", 5.0)
	if not FileAccess.file_exists(MODEL_PATH):
		_set_status("Connexion: OFF", "Modele introuvable: " + MODEL_PATH, 0.0)
		is_ready = false
		ready_changed.emit(false)
		return
	var node: Object = null
	if ClassDB.class_exists("MerlinLLM"):
		node = ClassDB.instantiate("MerlinLLM")
		if node is Node:
			add_child(node)
	else:
		_append_log("MerlinLLM class not registered. GDExtension may be missing or not loaded.")
	if node == null:
		node = _find_existing_llm()
	llm_node = node
	if llm_node != null:
		_apply_config()
		var load_ok = _call_load_model()
		if load_ok:
			_set_status("Connexion: OK", "LLM pret", 100.0)
			is_ready = true
			ready_changed.emit(true)
		else:
			is_ready = false
			ready_changed.emit(false)
	else:
		_set_status("Connexion: OFF", "LLM introuvable", 0.0)
		is_ready = false
		ready_changed.emit(false)

func _find_existing_llm() -> Object:
	var root = get_tree().root
	for child in root.get_children():
		if child == self:
			continue
		if child.has_method("generate"):
			return child
		for sub in child.get_children():
			if sub == self:
				continue
			if sub.has_method("generate"):
				return sub
	return null

func _apply_config() -> void:
	if llm_node == null:
		return
	_set_prop_if_exists(llm_node, "model_path", MODEL_PATH)
	_set_prop_if_exists(llm_node, "n_ctx", 2048)
	_set_prop_if_exists(llm_node, "temperature", 0.8)
	_set_prop_if_exists(llm_node, "top_p", 0.9)
	_set_prop_if_exists(llm_node, "max_tokens", 700)

func _call_load_model() -> bool:
	if llm_node == null:
		return false
	if llm_node.has_method("reload_model"):
		var err = llm_node.call("reload_model", MODEL_PATH)
		return _handle_load_result(err)
	if llm_node.has_method("load_model"):
		var info := _get_method_info(llm_node, "load_model")
		if info.size() > 0 and info.get("args", []).size() >= 1:
			var err = llm_node.call("load_model", MODEL_PATH)
			return _handle_load_result(err)
		else:
			var err = llm_node.call("load_model")
			return _handle_load_result(err)
	return true

func _handle_load_result(err) -> bool:
	if typeof(err) == TYPE_INT:
		var code = int(err)
		if code != OK:
			_set_status("Connexion: OFF", "Erreur load_model: " + str(code), 0.0)
			return false
		return true
	return true

func _get_method_info(obj: Object, method_name: String) -> Dictionary:
	for m in obj.get_method_list():
		if m.name == method_name:
			return m
	return {}

func _set_prop_if_exists(obj: Object, prop: String, value) -> void:
	for item in obj.get_property_list():
		if item.name == prop:
			obj.set(prop, value)
			return

func reload_model() -> void:
	_set_status("Connexion: ...", "Rechargement modele", 5.0)
	is_ready = false
	ready_changed.emit(false)
	if llm_node != null and llm_node is Node:
		llm_node.queue_free()
	llm_node = null
	await get_tree().process_frame
	_init_llm()

func ensure_ready() -> void:
	if not is_ready:
		_init_llm()

func get_llm() -> Object:
	return llm_node

func generate(ctx, callback) -> void:
	if llm_node and llm_node.has_method("generate"):
		llm_node.generate(ctx, callback)
		return
	if typeof(callback) == TYPE_CALLABLE:
		callback.call({"error": "LLM indisponible"})

func is_generating() -> bool:
	if llm_node and llm_node.has_method("is_generating"):
		return llm_node.is_generating()
	return false

func cancel_generation() -> void:
	if llm_node and llm_node.has_method("cancel_generation"):
		llm_node.cancel_generation()

func set_sampling(temp: float, top_p: float) -> void:
	if llm_node and llm_node.has_method("set_sampling"):
		llm_node.set_sampling(temp, top_p)

func set_generation_limits(max_tokens: int, context_size: int) -> void:
	if llm_node and llm_node.has_method("set_generation_limits"):
		llm_node.set_generation_limits(max_tokens, context_size)

func get_status() -> Dictionary:
	return {"status": status_text, "detail": detail_text, "progress": progress_value, "ready": is_ready}

func _set_status(status: String, detail: String, progress: float) -> void:
	status_text = status
	detail_text = detail
	progress_value = clampf(progress, 0.0, 100.0)
	_append_log(status + " | " + detail)
	status_changed.emit(status_text, detail_text, progress_value)

func _append_log(message: String) -> void:
	var now = Time.get_datetime_dict_from_system()
	var stamp = "%02d:%02d:%02d" % [now.hour, now.minute, now.second]
	var line = stamp + " - " + message
	if line == _last_log_line:
		return
	_last_log_line = line
	log_entries.append(line)
	if log_entries.size() > LOG_LIMIT:
		log_entries = log_entries.slice(log_entries.size() - LOG_LIMIT, log_entries.size())
	log_updated.emit(get_log_text())

func get_log_text() -> String:
	return "\n".join(log_entries)
