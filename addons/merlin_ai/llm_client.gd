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
