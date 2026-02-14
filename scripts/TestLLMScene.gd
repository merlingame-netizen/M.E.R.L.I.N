extends Control

const DEFAULT_PROJECT_DIR := "res://addons/merlin_llm/models"
const DEFAULT_EXTERNAL_DIR := "C:/models/trinity-nano"

const PROMPT_MAX_CHARS := 320
const MAX_RESPONSE_WORDS := 80
const MODEL_FILES := {
	"default": "ministral-3b-instruct.gguf",
}
const MODEL_ORDER := ["Q4_K_M"]

const MERLIN_SYSTEM_PROMPT := """Tu es Merlin, le druide sage et bienveillant du jeu DRU.
Tu parles uniquement en francais. Tu restes dans le role de Merlin.
Style: reponses courtes, claires, chaleureuses."""

const SHORT_RESPONSE_RULES := """Regles:
- 1 a 3 phrases, max 60 mots.
- Evite les listes longues.
- Ton calme et guide."""

const USE_CASES := [
	{"name": "Salutation", "prompt": "Salue le joueur et propose un petit conseil.", "bubble": true},
	{"name": "Indice quete", "prompt": "Donne un indice tres court pour trouver un Ogham perdu.", "bubble": true},
	{"name": "Dialogue court", "prompt": "Reponds en une phrase courte a: 'J'ai peur d'entrer dans la foret.'", "bubble": true}
]

const TYPEWRITER_CHARS_PER_SEC := 60.0
const TYPEWRITER_CHUNK_SIZE := 3

@onready var model_option: OptionButton = $Margin/MainVBox/ModelRow/ModelOption
@onready var base_dir_edit: LineEdit = $Margin/MainVBox/DirRow/BaseDirEdit
@onready var resolved_label: Label = $Margin/MainVBox/ResolvedLabel
@onready var prompt_edit: TextEdit = $Margin/MainVBox/PromptEdit
@onready var prompt_count_label: Label = $Margin/MainVBox/PromptMetaRow/PromptCountLabel
@onready var bubble_toggle: CheckBox = $Margin/MainVBox/PromptMetaRow/BubbleToggle
@onready var output_edit: TextEdit = $Margin/MainVBox/OutputTabs/TextOutput/OutputMargin/OutputEdit
@onready var bubbles_vbox: VBoxContainer = $Margin/MainVBox/OutputTabs/BubblesOutput/BubblesMargin/BubblesScroll/BubblesVBox
@onready var status_label: Label = $Margin/MainVBox/StatusLabel
@onready var metrics_edit: TextEdit = $Margin/MainVBox/MetricsPanel/MetricsMargin/MetricsEdit
@onready var max_tokens_spin: SpinBox = $Margin/MainVBox/ParamsRow/MaxTokensSpin
@onready var temp_spin: SpinBox = $Margin/MainVBox/ParamsRow/TempSpin
@onready var top_p_spin: SpinBox = $Margin/MainVBox/ParamsRow/TopPSpin
@onready var top_k_spin: SpinBox = $Margin/MainVBox/ParamsRow/TopKSpin
@onready var generate_button: Button = $Margin/MainVBox/ButtonsRow/GenerateButton
@onready var run_all_button: Button = $Margin/MainVBox/ButtonsRow/RunAllButton
@onready var clear_button: Button = $Margin/MainVBox/ButtonsRow/ClearButton
@onready var use_external_button: Button = $Margin/MainVBox/ModelRow/UseExternalButton

var _models_cache: Dictionary = {}
var _is_generating := false
var _is_typing := false
var _cancel_typing := false
var _sentence_regex: RegEx = RegEx.new()

func _ready() -> void:
	_sentence_regex.compile("[^.!?]+[.!?]?")
	_setup_ui()
	_update_resolved_path()

func _setup_ui() -> void:
	model_option.clear()
	model_option.add_item("Q4_K_M")
	model_option.add_item("Q5_K_M")
	model_option.add_item("Q8_0")
	model_option.select(0)
	base_dir_edit.text = DEFAULT_PROJECT_DIR
	prompt_edit.text = "Write a short story about Einstein."
	prompt_edit.placeholder_text = "Ecris une demande courte (max %d caracteres)..." % PROMPT_MAX_CHARS
	_update_prompt_count()
	status_label.text = "Ready."
	output_edit.text = ""
	metrics_edit.text = ""
	generate_button.pressed.connect(_on_generate_pressed)
	run_all_button.pressed.connect(_on_run_all_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	use_external_button.pressed.connect(_on_use_external_pressed)
	model_option.item_selected.connect(_on_model_selected)
	base_dir_edit.text_changed.connect(_on_base_dir_changed)
	prompt_edit.text_changed.connect(_on_prompt_changed)
	bubble_toggle.toggled.connect(_on_bubble_toggled)
	max_tokens_spin.value = 160
	temp_spin.value = 0.6
	top_p_spin.value = 0.9
	top_k_spin.value = 50

func _on_model_selected(_index: int) -> void:
	_update_resolved_path()

func _on_base_dir_changed(_text: String) -> void:
	_update_resolved_path()

func _on_use_external_pressed() -> void:
	base_dir_edit.text = DEFAULT_EXTERNAL_DIR
	_update_resolved_path()

func _on_clear_pressed() -> void:
	_cancel_typing = true
	_is_typing = false
	output_edit.text = ""
	_clear_bubbles()
	status_label.text = "Cleared."

func _on_generate_pressed() -> void:
	if _is_generating:
		return
	_cancel_typing = true
	var prompt = prompt_edit.text.strip_edges()
	if prompt == "":
		status_label.text = "Prompt is empty."
		return
	var model_path = _resolve_model_path()
	if model_path == "":
		status_label.text = "Model not found. Check base dir and file."
		return
	if not ClassDB.class_exists("MerlinLLM"):
		status_label.text = "MerlinLLM class missing (GDExtension not loaded)."
		return
	status_label.text = "Generating..."
	_is_generating = true
	_cancel_typing = false
	output_edit.text = ""
	_set_buttons_enabled(false)
	var result := await _generate_once(prompt, bubble_toggle.button_pressed)
	if result.has("error"):
		status_label.text = "Error: " + str(result.error)
		_set_buttons_enabled(true)
		_is_generating = false
		return
	var text: String = str(result.text)
	status_label.text = "Typing..."
	await _type_out(text)
	if bubble_toggle.button_pressed:
		_render_bubbles(text)
	if not _cancel_typing and not result.has("error"):
		status_label.text = "Done."
	_update_metrics(result)
	_set_buttons_enabled(true)
	_is_generating = false

func _on_run_all_pressed() -> void:
	if _is_generating:
		return
	_cancel_typing = true
	_set_buttons_enabled(false)
	metrics_edit.text = ""
	output_edit.text = ""
	_clear_bubbles()
	_is_generating = true
	for idx in range(MODEL_ORDER.size()):
		var model_key: String = MODEL_ORDER[idx]
		model_option.select(idx)
		_update_resolved_path()
		for use_case in USE_CASES:
			var case_name = str(use_case.get("name", "Case"))
			var prompt = str(use_case.get("prompt", ""))
			var bubble_mode = bool(use_case.get("bubble", false))
			status_label.text = "Testing %s / %s..." % [model_key, case_name]
			var result := await _generate_once(prompt, bubble_mode)
			_append_metrics(model_key, case_name, result)
	status_label.text = "Batch tests done."
	_is_generating = false
	_set_buttons_enabled(true)

func _resolve_model_path() -> String:
	var base_dir = base_dir_edit.text.strip_edges()
	if base_dir == "":
		return ""
	var key = model_option.get_item_text(model_option.selected)
	if not MODEL_FILES.has(key):
		return ""
	var file_name: String = MODEL_FILES[key]
	var path = base_dir.path_join(file_name)
	if FileAccess.file_exists(path):
		return path
	return ""

func _update_resolved_path() -> void:
	var path = _resolve_model_path()
	if path == "":
		resolved_label.text = "Resolved: (missing)"
	else:
		resolved_label.text = "Resolved: " + path

func _get_or_load_model(model_path: String) -> Object:
	if _models_cache.has(model_path):
		return _models_cache[model_path]
	var llm = ClassDB.instantiate("MerlinLLM")
	var err = llm.load_model(ProjectSettings.globalize_path(model_path))
	if typeof(err) == TYPE_INT and int(err) != OK:
		return null
	_models_cache[model_path] = llm
	return llm

func _apply_sampling(llm: Object) -> void:
	var max_tokens = int(max_tokens_spin.value)
	var temp = float(temp_spin.value)
	var top_p = float(top_p_spin.value)
	var top_k = int(top_k_spin.value)
	if llm.has_method("set_sampling_params"):
		llm.set_sampling_params(temp, top_p, max_tokens)
	if llm.has_method("set_advanced_sampling"):
		llm.set_advanced_sampling(top_k, 1.1)

func _format_prompt(user_prompt: String, bubble_mode: bool) -> String:
	var system = MERLIN_SYSTEM_PROMPT + "\n" + SHORT_RESPONSE_RULES
	if bubble_mode:
		system += "\nEcris 2 a 4 bulles courtes, separees par des sauts de ligne."
	var limited = _limit_prompt(user_prompt)
	return "<|im_start|>system\n" + system + "<|im_end|>\n<|im_start|>user\n" + limited + "<|im_end|>\n<|im_start|>assistant\n"

func _extract_text(result) -> String:
	if typeof(result) == TYPE_DICTIONARY:
		if result.has("text"):
			return str(result.text)
		if result.has("lines") and result.lines.size() > 0:
			return str(result.lines[0])
	return str(result)

func _type_out(text: String) -> void:
	_cancel_typing = false
	_is_typing = true
	output_edit.text = ""
	if text == "":
		_is_typing = false
		return
	var delay := 1.0 / TYPEWRITER_CHARS_PER_SEC
	var i := 0
	var total := text.length()
	while i < total and not _cancel_typing:
		var chunk: int = int(min(TYPEWRITER_CHUNK_SIZE, total - i))
		output_edit.text += text.substr(i, chunk)
		i += chunk
		output_edit.scroll_vertical = output_edit.get_line_count()
		await get_tree().create_timer(delay).timeout
	if not _cancel_typing:
		output_edit.text = text
	_is_typing = false

func _on_prompt_changed() -> void:
	var text = prompt_edit.text
	if text.length() > PROMPT_MAX_CHARS:
		prompt_edit.text = text.substr(0, PROMPT_MAX_CHARS)
		prompt_edit.set_caret_line(prompt_edit.get_line_count() - 1)
		prompt_edit.set_caret_column(prompt_edit.get_line(prompt_edit.get_line_count() - 1).length())
	_update_prompt_count()

func _on_bubble_toggled(_pressed: bool) -> void:
	if not bubble_toggle.button_pressed:
		_clear_bubbles()

func _update_prompt_count() -> void:
	prompt_count_label.text = "%d / %d" % [prompt_edit.text.length(), PROMPT_MAX_CHARS]

func _limit_prompt(text: String) -> String:
	if text.length() <= PROMPT_MAX_CHARS:
		return text
	return text.substr(0, PROMPT_MAX_CHARS)

func _post_process_text(text: String) -> String:
	var cleaned = text.strip_edges()
	cleaned = cleaned.replace("<|im_start|>", "")
	cleaned = cleaned.replace("<|im_end|>", "")
	cleaned = cleaned.replace("<|eot_id|>", "")
	cleaned = cleaned.replace("assistant:", "").strip_edges()
	var words = cleaned.split(" ", false)
	if words.size() > MAX_RESPONSE_WORDS:
		words = words.slice(0, MAX_RESPONSE_WORDS)
		cleaned = " ".join(words) + "..."
	return cleaned

func _render_bubbles(text: String) -> void:
	_clear_bubbles()
	var lines: Array = _split_into_bubbles(text)
	for line in lines:
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 36)
		var label = Label.new()
		label.text = str(line)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 14)
		panel.add_child(label)
		bubbles_vbox.add_child(panel)

func _clear_bubbles() -> void:
	for child in bubbles_vbox.get_children():
		child.queue_free()

func _split_into_bubbles(text: String) -> Array:
	var cleaned = text.strip_edges()
	if cleaned == "":
		return []
	var lines = cleaned.split("\n", false)
	var bubbles: Array = []
	for line in lines:
		var trimmed = str(line).strip_edges()
		if trimmed == "":
			continue
		if trimmed.find(".") != -1 or trimmed.find("!") != -1 or trimmed.find("?") != -1:
			for m in _sentence_regex.search_all(trimmed):
				var sentence = m.get_string().strip_edges()
				if sentence != "":
					bubbles.append(sentence)
		else:
			bubbles.append(trimmed)
	return bubbles

func _generate_once(prompt: String, bubble_mode: bool) -> Dictionary:
	var model_path = _resolve_model_path()
	if model_path == "":
		return {"error": "Model not found"}
	var llm = _get_or_load_model(model_path)
	if llm == null:
		return {"error": "Failed to load model"}
	var formatted_prompt = _format_prompt(prompt, bubble_mode)
	_apply_sampling(llm)
	var start_ms = Time.get_ticks_msec()
	var state := {"done": false, "result": {}}
	llm.generate_async(formatted_prompt, func(res):
		state.result = res
		state.done = true
	)
	while not state.done:
		llm.poll_result()
		await get_tree().process_frame
	var elapsed = Time.get_ticks_msec() - start_ms
	var raw_text := _extract_text(state.result)
	var final_text := _post_process_text(raw_text)
	var perf := _capture_perf()
	return {"text": final_text, "elapsed_ms": elapsed, "perf": perf}

func _update_metrics(result: Dictionary) -> void:
	metrics_edit.text = _format_metrics_line("Interactive", result)

func _append_metrics(model_key: String, case_name: String, result: Dictionary) -> void:
	var line = _format_metrics_line("%s | %s" % [model_key, case_name], result)
	metrics_edit.text += line + "\n"

func _format_metrics_line(label: String, result: Dictionary) -> String:
	if result.has("error"):
		return "%s | ERROR: %s" % [label, str(result.error)]
	var elapsed = int(result.get("elapsed_ms", 0))
	var perf: Dictionary = result.get("perf", {})
	var cpu_ms = _fmt_number(perf.get("cpu_ms", null))
	var gpu_mem = _fmt_number(perf.get("gpu_mem_mb", null))
	var draw_calls = _fmt_number(perf.get("draw_calls", null))
	var fps = _fmt_number(perf.get("fps", null))
	return "%s | latency=%dms | cpu(ms)=%s | gpu_mem(MB)=%s | draw_calls=%s | fps=%s" % [label, elapsed, cpu_ms, gpu_mem, draw_calls, fps]

func _fmt_number(value) -> String:
	if value == null:
		return "n/a"
	return "%.2f" % float(value)

func _capture_perf() -> Dictionary:
	var snapshot: Dictionary = {}
	if not Performance.has_method("get_monitor"):
		return snapshot
	# TIME_PROCESS is in seconds; convert to ms.
	var cpu_sec = Performance.get_monitor(Performance.TIME_PROCESS)
	if cpu_sec >= 0.0:
		snapshot.cpu_ms = cpu_sec * 1000.0
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	if fps >= 0.0:
		snapshot.fps = fps
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if draw_calls >= 0.0:
		snapshot.draw_calls = draw_calls
	var gpu_mem = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	if gpu_mem >= 0.0:
		snapshot.gpu_mem_mb = gpu_mem / (1024.0 * 1024.0)
	return snapshot

func _set_buttons_enabled(enabled: bool) -> void:
	generate_button.disabled = not enabled
	run_all_button.disabled = not enabled
	clear_button.disabled = not enabled
	use_external_button.disabled = not enabled
