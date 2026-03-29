## GroqBackend — Cloud LLM backend using Groq API (OpenAI-compatible)
##
## Drop-in replacement for OllamaBackend when no local Ollama is available.
## Uses Groq API with Llama 3.3-70b (narrator) or Llama 3.1-8b-instant (GM).
## Interface: generate_async(prompt, callback) + poll_result() + set_sampling_params()
## Thread-safe: runs HTTP request in background thread.
extends RefCounted
class_name GroqBackend

const API_URL := "https://api.groq.com/openai/v1/chat/completions"
const CONNECT_TIMEOUT_MS := 10000
const READ_TIMEOUT_MS := 30000

# Models — Groq Llama family
const MODEL_REGISTRY := {
	"narrator": "llama-3.3-70b-versatile",
	"gm": "llama-3.1-8b-instant",
	"worker": "llama-3.1-8b-instant",
}

# ── Config ────────────────────────────────────────────────────────────────────
var api_key: String = ""
var model: String = "llama-3.3-70b-versatile"
var role: String = "narrator"  # narrator | gm | worker

# ── Sampling ──────────────────────────────────────────────────────────────────
var _temperature: float = 0.7
var _top_p: float = 0.9
var _max_tokens: int = 512

# ── Internal state ───────────────────────────────────────────────────────────
var _thread: Thread = null
var _is_generating: bool = false
var _cancel_requested: bool = false
var _mutex := Mutex.new()
var _result_ready: bool = false
var _pending_result: Dictionary = {}
var _pending_callback: Callable = Callable()

# ── Stats ────────────────────────────────────────────────────────────────────
var stats := {
	"last_total_ms": 0,
	"last_tok_per_sec": 0.0,
	"llm_calls": 0,
}


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — Compatible with OllamaBackend interface
# ═══════════════════════════════════════════════════════════════════════════════

func _init(p_role: String = "narrator", p_api_key: String = "") -> void:
	role = p_role
	model = MODEL_REGISTRY.get(p_role, MODEL_REGISTRY["narrator"])
	api_key = p_api_key
	if api_key.is_empty():
		# Try ProjectSettings, then env var, then JS bridge (web export)
		api_key = ProjectSettings.get_setting("merlin/groq_api_key", "")
	if api_key.is_empty():
		api_key = OS.get_environment("GROQ_API_KEY")
	if api_key.is_empty() and OS.has_feature("web"):
		# Web export: try reading from URL parameter ?groq_key=...
		var js_result = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('groq_key') || ''")
		if js_result is String and not (js_result as String).is_empty():
			api_key = js_result as String


## Check if Groq API is reachable (non-blocking quick test).
func check_available() -> bool:
	return not api_key.is_empty()


## Not applicable for cloud — always returns true if API key set.
func check_model_available() -> bool:
	return not api_key.is_empty()


## Async generation — runs HTTP request in background thread.
## Prompt format: ChatML-style string (system + user already formatted).
## The prompt is split on <|im_start|> tags into messages array.
func generate_async(prompt: String, callback: Callable) -> void:
	if _is_generating:
		if callback.is_valid():
			callback.call({"error": "Already generating"})
		return

	if api_key.is_empty():
		if callback.is_valid():
			callback.call({"error": "No Groq API key configured"})
		return

	# Clean up previous thread
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null

	_is_generating = true
	_cancel_requested = false
	_pending_callback = callback

	_mutex.lock()
	_result_ready = false
	_pending_result = {}
	_mutex.unlock()

	_thread = Thread.new()
	_thread.start(_blocking_generate.bind(prompt))


## Check if generation is complete. If so, calls callback and returns true.
func poll_result() -> bool:
	_mutex.lock()
	var ready: bool = _result_ready
	_mutex.unlock()

	if not ready:
		return false

	_mutex.lock()
	_result_ready = false
	var result: Dictionary = _pending_result.duplicate(true)
	_mutex.unlock()

	_is_generating = false

	if _pending_callback.is_valid():
		_pending_callback.call(result)
		_pending_callback = Callable()

	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null

	return true


func is_generating_now() -> bool:
	return _is_generating


func cancel_generation() -> void:
	_cancel_requested = true
	_is_generating = false


func set_sampling_params(p_temperature: float, p_top_p: float, p_max_tokens: int) -> void:
	_temperature = clampf(p_temperature, 0.1, 2.0)
	_top_p = clampf(p_top_p, 0.05, 1.0)
	if p_max_tokens > 0:
		_max_tokens = p_max_tokens


func set_advanced_sampling(params: Dictionary) -> void:
	if params.has("temperature"):
		_temperature = clampf(float(params["temperature"]), 0.1, 2.0)
	if params.has("top_p"):
		_top_p = clampf(float(params["top_p"]), 0.05, 1.0)
	if params.has("max_tokens"):
		_max_tokens = int(params["max_tokens"])


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — Background thread HTTP request
# ═══════════════════════════════════════════════════════════════════════════════

func _blocking_generate(prompt: String) -> void:
	var start_ms := Time.get_ticks_msec()
	var result := {}

	# Parse ChatML prompt into messages array
	var messages: Array = _parse_chatml_to_messages(prompt)
	if messages.is_empty():
		messages = [{"role": "user", "content": prompt}]

	var payload := {
		"model": model,
		"messages": messages,
		"temperature": _temperature,
		"top_p": _top_p,
		"max_tokens": _max_tokens,
		"stream": false,
	}
	var body_str := JSON.stringify(payload)

	# Connect to Groq API via HTTPS
	var client := HTTPClient.new()
	var err := client.connect_to_host("api.groq.com", 443, TLSOptions.client())
	if err != OK:
		result = {"error": "Groq connect failed: %s" % error_string(err)}
		_store_result(result, start_ms)
		return

	var connect_start := Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
		if _cancel_requested:
			result = {"error": "Cancelled"}
			_store_result(result, start_ms)
			return
		if Time.get_ticks_msec() - connect_start > CONNECT_TIMEOUT_MS:
			result = {"error": "Groq connect timeout"}
			_store_result(result, start_ms)
			return

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		result = {"error": "Groq status: %d" % client.get_status()}
		_store_result(result, start_ms)
		return

	# Send POST /openai/v1/chat/completions
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key,
		"Content-Length: %d" % body_str.to_utf8_buffer().size(),
	]
	err = client.request(HTTPClient.METHOD_POST, "/openai/v1/chat/completions", headers, body_str)
	if err != OK:
		result = {"error": "Groq request failed: %s" % error_string(err)}
		_store_result(result, start_ms)
		return

	# Wait for response
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
		if _cancel_requested:
			result = {"error": "Cancelled"}
			_store_result(result, start_ms)
			return

	if not client.has_response():
		result = {"error": "Groq no response"}
		_store_result(result, start_ms)
		return

	var status_code: int = client.get_response_code()

	# Read response body
	var response_body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			response_body.append_array(chunk)
		OS.delay_msec(1)
		if _cancel_requested:
			result = {"error": "Cancelled"}
			_store_result(result, start_ms)
			return
		if Time.get_ticks_msec() - start_ms > READ_TIMEOUT_MS:
			result = {"error": "Groq read timeout"}
			_store_result(result, start_ms)
			return

	var response_str := response_body.get_string_from_utf8()

	if status_code != 200:
		result = {"error": "Groq HTTP %d: %s" % [status_code, response_str.substr(0, 200)]}
		_store_result(result, start_ms)
		return

	# Parse JSON response
	var json := JSON.new()
	if json.parse(response_str) != OK:
		result = {"error": "Groq JSON parse failed"}
		_store_result(result, start_ms)
		return

	var data: Dictionary = json.data if json.data is Dictionary else {}
	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		result = {"error": "Groq empty response"}
		_store_result(result, start_ms)
		return

	var message: Dictionary = choices[0].get("message", {})
	var content: String = str(message.get("content", ""))

	# Usage stats
	var usage: Dictionary = data.get("usage", {})
	var total_tokens: int = int(usage.get("total_tokens", 0))
	var elapsed_ms: int = Time.get_ticks_msec() - start_ms

	result = {
		"response": content,
		"total_duration_ms": elapsed_ms,
		"eval_count": total_tokens,
		"model": model,
	}

	_store_result(result, start_ms)


func _store_result(result: Dictionary, start_ms: int) -> void:
	var elapsed: int = Time.get_ticks_msec() - start_ms
	stats["last_total_ms"] = elapsed
	stats["llm_calls"] += 1
	if result.has("eval_count") and elapsed > 0:
		stats["last_tok_per_sec"] = float(result["eval_count"]) / (float(elapsed) / 1000.0)

	_mutex.lock()
	_pending_result = result
	_result_ready = true
	_mutex.unlock()


## Parse ChatML-formatted prompt into Groq messages array.
## Format: <|im_start|>system\n...<|im_end|>\n<|im_start|>user\n...<|im_end|>
func _parse_chatml_to_messages(prompt: String) -> Array:
	var messages: Array = []
	var parts := prompt.split("<|im_start|>")
	for part in parts:
		var trimmed := part.strip_edges()
		if trimmed.is_empty():
			continue
		# Remove trailing <|im_end|>
		trimmed = trimmed.replace("<|im_end|>", "").strip_edges()
		# First line is the role
		var newline_idx := trimmed.find("\n")
		if newline_idx < 0:
			continue
		var msg_role := trimmed.substr(0, newline_idx).strip_edges()
		var msg_content := trimmed.substr(newline_idx + 1).strip_edges()
		if msg_role in ["system", "user", "assistant"] and not msg_content.is_empty():
			messages.append({"role": msg_role, "content": msg_content})
	return messages
