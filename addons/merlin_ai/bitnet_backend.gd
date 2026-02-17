## BitNetBackend — Backend for BitNet llama-server.exe instances
##
## Utilise POST /completion (llama.cpp natif) pour la generation.
## Interface 100% compatible OllamaBackend / MerlinLLM.
## Multi-instance safe: chaque BitNetBackend connecte a un process llama-server independant.
extends RefCounted
class_name BitNetBackend

const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 8081
const CONNECT_TIMEOUT_MS := 5000
const READ_TIMEOUT_MS := 90000

# ── Config ────────────────────────────────────────────────────────────────────
var host: String = DEFAULT_HOST
var port: int = DEFAULT_PORT
var brain_role: String = "worker"

# ── Sampling params (set via set_sampling_params / set_advanced_sampling) ─────
var _temperature: float = 0.7
var _top_p: float = 0.9
var _max_tokens: int = 256
var _top_k: int = 50
var _repetition_penalty: float = 1.1
var _num_ctx: int = 512

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
	"last_ttft_ms": 0,
	"last_total_ms": 0,
	"last_eval_count": 0,
	"last_tok_per_sec": 0.0,
	"avg_total_ms": 0.0,
	"avg_tok_per_sec": 0.0,
	"llm_calls": 0,
}


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — Compatible avec OllamaBackend / MerlinLLM interface
# ═══════════════════════════════════════════════════════════════════════════════

## Verifie si le serveur llama-server est accessible (GET /health).
func check_available() -> bool:
	var client := HTTPClient.new()
	var err := client.connect_to_host(host, port)
	if err != OK:
		return false
	var start := Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
		if Time.get_ticks_msec() - start > CONNECT_TIMEOUT_MS:
			return false
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return false
	err = client.request(HTTPClient.METHOD_GET, "/health", [])
	if err != OK:
		return false
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
		if Time.get_ticks_msec() - start > CONNECT_TIMEOUT_MS:
			return false
	if not client.has_response():
		return false
	if client.get_response_code() != 200:
		return false
	var body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			body.append_array(chunk)
		OS.delay_msec(1)
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return false
	var data: Dictionary = json.data if json.data is Dictionary else {}
	return data.get("status", "") == "ok"


## llama-server charge le modele au demarrage — toujours vrai si /health OK.
func check_model_available() -> bool:
	return check_available()


## Lance la generation asynchrone (non-bloquant). Le callback recoit {"text": ...} ou {"error": ...}.
func generate_async(prompt: String, callback: Callable) -> void:
	if _is_generating:
		if callback.is_valid():
			callback.call({"error": "Already generating"})
		return

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


## Verifie si la generation est terminee. Si oui, appelle le callback et retourne true.
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


## Retourne true si une generation est en cours.
func is_generating_now() -> bool:
	return _is_generating


## Annulation cooperative. La requete HTTP en cours sera ignoree.
func cancel_generation() -> void:
	_cancel_requested = true
	_is_generating = false


## Configure les parametres de sampling (compatible MerlinLLM / OllamaBackend).
func set_sampling_params(p_temperature: float, p_top_p: float, p_max_tokens: int) -> void:
	_temperature = clampf(p_temperature, 0.1, 2.0)
	_top_p = clampf(p_top_p, 0.05, 1.0)
	if p_max_tokens > 0:
		_max_tokens = p_max_tokens


## Configure les parametres avances (compatible MerlinLLM / OllamaBackend).
func set_advanced_sampling(p_top_k: int, p_repetition_penalty: float) -> void:
	_top_k = clampi(p_top_k, 0, 100)
	_repetition_penalty = clampf(p_repetition_penalty, 1.0, 2.0)


## No-op: llama-server ne supporte pas GBNF via /completion simple.
func set_grammar(_grammar: String, _root: String = "root") -> void:
	pass


## No-op: voir set_grammar.
func clear_grammar() -> void:
	pass


## Configure la taille du contexte (informationnel — n_ctx fixe au demarrage du serveur).
func set_context_size(p_n_ctx: int) -> void:
	_num_ctx = clampi(p_n_ctx, 256, 32768)


## No-op: les threads sont configures au lancement du process llama-server.
func set_thread_count(_gen_threads: int, _batch_threads: int) -> void:
	pass


## Compatibility: verifie que le serveur est en ligne.
func load_model(_path: String) -> int:
	if check_available():
		return OK
	return ERR_CANT_CONNECT


## Retourne des infos sur la configuration.
func get_model_info() -> Dictionary:
	var info := {
		"backend": "bitnet",
		"host": "%s:%d" % [host, port],
		"brain_role": brain_role,
		"n_ctx": _num_ctx,
		"max_tokens": _max_tokens,
		"model_loaded": _is_generating or check_available(),
	}
	info.merge(stats)
	return info


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — Thread-based blocking HTTP request to llama-server /completion
# ═══════════════════════════════════════════════════════════════════════════════

func _blocking_generate(prompt: String) -> void:
	var start_ms := Time.get_ticks_msec()
	var result := {}

	# llama-server /completion format (llama.cpp natif)
	var payload := {
		"prompt": prompt,
		"n_predict": _max_tokens,
		"temperature": _temperature,
		"top_p": _top_p,
		"top_k": _top_k,
		"repeat_penalty": _repetition_penalty,
		"stream": false,
	}
	var body_str := JSON.stringify(payload)

	# Connect
	var client := HTTPClient.new()
	var err := client.connect_to_host(host, port)
	if err != OK:
		result = {"error": "BitNet connect failed: %s" % error_string(err)}
		_store_result(result)
		return

	var connect_start := Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
		if _cancel_requested:
			result = {"error": "Cancelled"}
			_store_result(result)
			return
		if Time.get_ticks_msec() - connect_start > CONNECT_TIMEOUT_MS:
			result = {"error": "BitNet connect timeout"}
			_store_result(result)
			return

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		result = {"error": "BitNet status: %d" % client.get_status()}
		_store_result(result)
		return

	# Send POST /completion
	var headers := [
		"Content-Type: application/json",
		"Content-Length: %d" % body_str.to_utf8_buffer().size(),
	]
	err = client.request(HTTPClient.METHOD_POST, "/completion", headers, body_str)
	if err != OK:
		result = {"error": "BitNet request failed: %s" % error_string(err)}
		_store_result(result)
		return

	# Wait for response headers
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
		if _cancel_requested:
			result = {"error": "Cancelled"}
			_store_result(result)
			return

	if not client.has_response():
		result = {"error": "BitNet no response"}
		_store_result(result)
		return

	var status_code: int = client.get_response_code()

	# Read response body
	var response_body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			response_body.append_array(chunk)
		else:
			OS.delay_msec(5)
		if _cancel_requested:
			result = {"error": "Cancelled"}
			_store_result(result)
			return
		if Time.get_ticks_msec() - start_ms > READ_TIMEOUT_MS:
			result = {"error": "BitNet read timeout (%dms)" % READ_TIMEOUT_MS}
			_store_result(result)
			return

	if status_code != 200:
		result = {"error": "BitNet HTTP %d: %s" % [status_code, response_body.get_string_from_utf8().left(200)]}
		_store_result(result)
		return

	# Parse JSON response (llama-server /completion format)
	var json := JSON.new()
	var parse_err := json.parse(response_body.get_string_from_utf8())
	if parse_err != OK:
		result = {"error": "BitNet JSON parse error: %s" % json.get_error_message()}
		_store_result(result)
		return

	var data: Dictionary = json.data if json.data is Dictionary else {}
	# llama-server returns "content" (not "response" like Ollama)
	var text: String = str(data.get("content", "")).strip_edges()

	if text == "":
		result = {"error": "BitNet empty response"}
		_store_result(result)
		return

	# Extract timing metrics from llama-server response
	var total_ms: int = Time.get_ticks_msec() - start_ms
	var timings: Dictionary = data.get("timings", {})
	var eval_count: int = int(data.get("tokens_predicted", 0))
	var tok_per_sec: float = float(timings.get("predicted_per_second", 0.0))

	result = {"text": text}
	_update_stats(total_ms, eval_count, tok_per_sec)
	_store_result(result)


func _store_result(result: Dictionary) -> void:
	_mutex.lock()
	_pending_result = result
	_result_ready = true
	_mutex.unlock()


func _update_stats(total_ms: int, eval_count: int, tok_per_sec: float) -> void:
	stats.last_total_ms = total_ms
	stats.last_eval_count = eval_count
	stats.last_tok_per_sec = tok_per_sec
	stats.llm_calls += 1
	if stats.llm_calls == 1:
		stats.avg_total_ms = float(total_ms)
		stats.avg_tok_per_sec = tok_per_sec
	else:
		var n: float = float(stats.llm_calls)
		stats.avg_total_ms = (stats.avg_total_ms * (n - 1.0) + float(total_ms)) / n
		stats.avg_tok_per_sec = (stats.avg_tok_per_sec * (n - 1.0) + tok_per_sec) / n
