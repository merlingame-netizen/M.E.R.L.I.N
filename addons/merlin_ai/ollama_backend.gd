## OllamaBackend — remplacant de MerlinLLM via l'API HTTP d'Ollama
##
## Utilise /api/chat avec un tableau de messages {role, content}. C'est Ollama
## qui applique le gabarit de chat propre a CHAQUE modele — Gemma
## (<start_of_turn>), Qwen (<|im_start|>) ou autre. Le jeu n'a plus a le savoir.
##
## Ce backend ecrivait auparavant du ChatML a la main et envoyait
## /api/generate avec raw=true, ce qui disait explicitement a Ollama de NE PAS
## appliquer le gabarit du modele. Changer de famille de modele produisait alors
## une prose degradee sans qu'aucune erreur ne le signale.
##
## Interface 100% compatible _run_llm (generate_async/poll_result/cancel/sampling).
## Multi-instance safe: chaque OllamaBackend est independant (Ollama gere le multi-slot).
## Supporte modeles heterogenes: chaque instance peut utiliser un modele different.
## Supporte le thinking mode: strip automatique des tags <think>.
extends RefCounted
class_name OllamaBackend

const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 11434
const DEFAULT_MODEL := "gemma4:e4b-it-qat"
const CONNECT_TIMEOUT_MS := 5000
const READ_TIMEOUT_MS := 60000

# ── Registre des modeles (famille Gemma 4) ───────────────────────────────────
const MODEL_REGISTRY := {
	"gemma4_26b": {"tag": "gemma4:26b-a4b-it-qat", "ram_mb": 16000, "context_default": 8192},
	"gemma4_12b": {"tag": "gemma4:12b-it-qat", "ram_mb": 7200, "context_default": 8192},
	"gemma4_e4b": {"tag": "gemma4:e4b-it-qat", "ram_mb": 6100, "context_default": 4096},
	"gemma4_e2b": {"tag": "gemma4:e2b-it-qat", "ram_mb": 3000, "context_default": 4096},
	"gemma4_31b": {"tag": "gemma4:31b-it-qat", "ram_mb": 19000, "context_default": 8192},
}

# ── Config ────────────────────────────────────────────────────────────────────
var host: String = DEFAULT_HOST
var port: int = DEFAULT_PORT
var model: String = DEFAULT_MODEL
var thinking_mode: bool = false  # active le raisonnement <think> (retire de la sortie)

# ── Messages neutres, poses avant l'appel (cf. set_messages) ─────────────────
# Tableau de {role, content} avec role dans {system, user, assistant}.
# Vide = le prompt passe a generate_async devient un unique message user.
var _messages: Array = []

# ── Contrainte de format JSON (cf. set_grammar / set_json_schema) ────────────
# null           = aucune contrainte
# "json"         = JSON syntaxiquement valide exige
# Dictionary     = schema JSON complet, Ollama contraint le decodage dessus
var _format_constraint: Variant = null

# ── Sampling params (set via set_sampling_params / set_advanced_sampling) ─────
var _temperature: float = 0.7
var _top_p: float = 0.9
var _max_tokens: int = 256
var _top_k: int = 50
var _repetition_penalty: float = 1.1
var _num_ctx: int = 4096

# ── Internal state ───────────────────────────────────────────────────────────
var _thread: Thread = null
var _is_generating: bool = false
var _cancel_requested: bool = false
var _mutex := Mutex.new()
var _result_ready: bool = false
var _pending_result: Dictionary = {}
var _pending_callback: Callable = Callable()

# ── Streaming state ─────────────────────────────────────────────────────────
var _stream_chunks: Array[String] = []
var _stream_done: bool = false
var _stream_full_text: String = ""

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
# PUBLIC API — Compatible avec MerlinLLM interface
# ═══════════════════════════════════════════════════════════════════════════════

## Verifie si Ollama est accessible (GET /api/tags).
## Appel bloquant (utiliser avant _init_local_models, pas en boucle).
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
	err = client.request(HTTPClient.METHOD_GET, "/api/tags", [])
	if err != OK:
		return false
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
		if Time.get_ticks_msec() - start > CONNECT_TIMEOUT_MS:
			return false
	if not client.has_response():
		return false
	return client.get_response_code() == 200


## Verifie si le modele cible est disponible dans Ollama.
func check_model_available() -> bool:
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
	err = client.request(HTTPClient.METHOD_GET, "/api/tags", [])
	if err != OK:
		return false
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
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
	var models: Array = data.get("models", [])
	for m in models:
		var name: String = str(m.get("name", ""))
		if name == model or name.begins_with(model.split(":")[0]):
			return true
	return false


## Liste les modeles reellement installes sur la machine (GET /api/tags).
## Sert au selecteur du menu options : on propose ce qui EXISTE, pas une liste
## ecrite en dur qui mentirait des que l'utilisateur installe autre chose.
## Retourne [] si Ollama ne repond pas.
func list_installed_models() -> Array[String]:
	var out: Array[String] = []
	var client := HTTPClient.new()
	if client.connect_to_host(host, port) != OK:
		return out
	var start := Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_CONNECTING \
			or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
		if Time.get_ticks_msec() - start > CONNECT_TIMEOUT_MS:
			return out
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return out
	if client.request(HTTPClient.METHOD_GET, "/api/tags", []) != OK:
		return out
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
	if not client.has_response() or client.get_response_code() != 200:
		return out
	var body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			body.append_array(chunk)
		OS.delay_msec(1)
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return out
	var data: Dictionary = json.data if json.data is Dictionary else {}
	for m in (data.get("models", []) as Array):
		var n: String = str((m as Dictionary).get("name", ""))
		if n != "":
			out.append(n)
	out.sort()
	return out


## Lance la generation asynchrone (non-bloquant). Le callback recoit {"text": ...} ou {"error": ...}.
func generate_async(prompt: String, callback: Callable) -> void:
	if _is_generating:
		if callback.is_valid():
			callback.call({"error": "Already generating"})
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
	_thread.start(_blocking_generate.bind(_consommer_messages(prompt)))


## Verifie si la generation est terminee. Si oui, appelle le callback et retourne true.
func poll_result() -> bool:
	_mutex.lock()
	var ready: bool = _result_ready
	_mutex.unlock()

	if not ready:
		return false

	# Consume result
	_mutex.lock()
	_result_ready = false
	var result: Dictionary = _pending_result.duplicate(true)
	_mutex.unlock()

	_is_generating = false

	if _pending_callback.is_valid():
		_pending_callback.call(result)
		_pending_callback = Callable()

	# Clean up thread
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
	_mutex.lock()
	_stream_done = true
	_mutex.unlock()


# ═══════════════════════════════════════════════════════════════════════════════
# STREAMING API — Token-by-token via NDJSON
# ═══════════════════════════════════════════════════════════════════════════════

## Lance une generation en streaming. Les tokens arrivent dans _stream_chunks.
## Appeler poll_stream() depuis le main thread pour recuperer les chunks.
func generate_stream_async(prompt: String) -> void:
	if _is_generating:
		push_warning("[OllamaBackend] Already generating — ignoring stream request")
		return

	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null

	_is_generating = true
	_cancel_requested = false

	_mutex.lock()
	_stream_chunks.clear()
	_stream_done = false
	_stream_full_text = ""
	_result_ready = false
	_pending_result = {}
	_mutex.unlock()

	_thread = Thread.new()
	_thread.start(_blocking_stream.bind(_consommer_messages(prompt)))


## Recupere les tokens accumules depuis le dernier appel. Non-bloquant.
## Retourne {"chunks": Array[String], "done": bool, "full_text": String, "error": String}
func poll_stream() -> Dictionary:
	_mutex.lock()
	var chunks: Array[String] = _stream_chunks.duplicate()
	_stream_chunks.clear()
	var done: bool = _stream_done
	var full: String = _stream_full_text
	var result: Dictionary = _pending_result.duplicate(true) if _result_ready else {}
	_mutex.unlock()

	if done and _thread != null and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null
		_is_generating = false

	var out: Dictionary = {"chunks": chunks, "done": done, "full_text": full}
	if result.has("error"):
		out["error"] = result["error"]
	return out


func _blocking_stream(messages: Array) -> void:
	var start_ms := Time.get_ticks_msec()
	var body_str := JSON.stringify(_construire_payload(messages, true))

	# Connect.
	var client := HTTPClient.new()
	var err := client.connect_to_host(host, port)
	if err != OK:
		_store_stream_error("Ollama connect failed: %s" % error_string(err))
		return

	var connect_start := Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
		if _cancel_requested:
			_store_stream_error("Cancelled")
			return
		if Time.get_ticks_msec() - connect_start > CONNECT_TIMEOUT_MS:
			_store_stream_error("Ollama connect timeout")
			return

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		_store_stream_error("Ollama status: %d" % client.get_status())
		return

	# Send POST.
	var headers := [
		"Content-Type: application/json",
		"Content-Length: %d" % body_str.to_utf8_buffer().size(),
	]
	err = client.request(HTTPClient.METHOD_POST, "/api/chat", headers, body_str)
	if err != OK:
		_store_stream_error("Ollama request failed: %s" % error_string(err))
		return

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
		if _cancel_requested:
			_store_stream_error("Cancelled")
			return

	if not client.has_response():
		_store_stream_error("Ollama no response")
		return

	var status_code: int = client.get_response_code()
	if status_code != 200:
		_store_stream_error("Ollama HTTP %d" % status_code)
		return

	# Read NDJSON stream line by line.
	var accumulated_text: String = ""
	var line_buffer: String = ""
	var first_token_ms: int = -1  # TTFT: time to first non-empty token

	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			line_buffer += chunk.get_string_from_utf8()
			# Process complete lines.
			while "\n" in line_buffer:
				var nl_pos: int = line_buffer.find("\n")
				var line: String = line_buffer.substr(0, nl_pos).strip_edges()
				line_buffer = line_buffer.substr(nl_pos + 1)
				if line == "":
					continue
				var json := JSON.new()
				if json.parse(line) != OK:
					continue
				var obj: Dictionary = json.data if json.data is Dictionary else {}
				var token: String = _texte_de_reponse(obj)
				if token != "":
					if first_token_ms < 0:
						first_token_ms = Time.get_ticks_msec() - start_ms
					accumulated_text += token
					_mutex.lock()
					_stream_chunks.append(token)
					_stream_full_text = accumulated_text
					_mutex.unlock()
				if obj.get("done", false):
					# Strip think tags.
					if "<think>" in accumulated_text:
						accumulated_text = _strip_thinking_tags(accumulated_text)
					var total_ms: int = Time.get_ticks_msec() - start_ms
					var eval_count: int = int(obj.get("eval_count", 0))
					var eval_ns: int = int(obj.get("eval_duration", 0))
					var tps: float = eval_count / (eval_ns / 1e9) if eval_ns > 0 else 0.0
					_update_stats(total_ms, eval_count, tps, first_token_ms)
					_mutex.lock()
					_stream_full_text = accumulated_text.strip_edges()
					_stream_done = true
					_pending_result = {"text": accumulated_text.strip_edges()}
					_result_ready = true
					_mutex.unlock()
					return
		else:
			OS.delay_msec(5)
		if _cancel_requested:
			_store_stream_error("Cancelled")
			return
		if Time.get_ticks_msec() - start_ms > READ_TIMEOUT_MS:
			_store_stream_error("Ollama stream read timeout")
			return

	# If we exit the loop without done=true, finalize.
	if accumulated_text.strip_edges() != "":
		if "<think>" in accumulated_text:
			accumulated_text = _strip_thinking_tags(accumulated_text)
		var total_ms: int = Time.get_ticks_msec() - start_ms
		_update_stats(total_ms, 0, 0.0, first_token_ms)
		_mutex.lock()
		_stream_full_text = accumulated_text.strip_edges()
		_stream_done = true
		_pending_result = {"text": accumulated_text.strip_edges()}
		_result_ready = true
		_mutex.unlock()
	else:
		_store_stream_error("Ollama stream empty response")


func _store_stream_error(msg: String) -> void:
	_mutex.lock()
	_stream_done = true
	_pending_result = {"error": msg}
	_result_ready = true
	_mutex.unlock()


## Configure les parametres de sampling (compatible MerlinLLM).
func set_sampling_params(p_temperature: float, p_top_p: float, p_max_tokens: int) -> void:
	_temperature = clampf(p_temperature, 0.1, 2.0)
	_top_p = clampf(p_top_p, 0.05, 1.0)
	if p_max_tokens > 0:
		_max_tokens = p_max_tokens


## Configure les parametres avances (compatible MerlinLLM).
func set_advanced_sampling(p_top_k: int, p_repetition_penalty: float) -> void:
	_top_k = clampi(p_top_k, 0, 100)
	_repetition_penalty = clampf(p_repetition_penalty, 1.0, 2.0)


## Pose les messages du prochain appel, sous forme neutre.
##
## `messages` : Array de {role, content}, role dans {system, user, assistant}.
## Ils sont CONSOMMES par la generation suivante — un appel qui n'en pose pas
## repart d'un simple message user, sans heriter des precedents.
func set_messages(messages: Array) -> void:
	_messages.clear()
	for m in messages:
		if not (m is Dictionary):
			continue
		var role: String = str(m.get("role", "user"))
		var content: String = str(m.get("content", ""))
		if content.strip_edges().is_empty():
			continue
		if role not in ["system", "user", "assistant"]:
			role = "user"
		_messages.append({"role": role, "content": content})


func clear_messages() -> void:
	_messages.clear()


## Contraint la sortie a du JSON.
##
## Historiquement un no-op : « Ollama ne supporte pas GBNF ». C'est vrai, mais
## Ollama accepte un parametre `format` — soit "json", soit un schema JSON
## complet sur lequel il contraint le decodage. Gemma 4 sait s'y conformer
## nativement a toutes les tailles.
##
## `grammar` peut donc etre :
##   - un schema JSON (texte parsable en Dictionary) -> contrainte complete ;
##   - une grammaire GBNF (les appelants historiques) -> on retombe sur "json",
##     qui garantit au moins une syntaxe valide. C'est moins que le schema,
##     mais infiniment plus que l'ancien no-op.
func set_grammar(grammar: String, _root: String = "root") -> void:
	if grammar.strip_edges().is_empty():
		_format_constraint = null
		return
	var parsed: Variant = JSON.parse_string(grammar)
	if parsed is Dictionary and (parsed as Dictionary).has("type"):
		_format_constraint = parsed
	else:
		_format_constraint = "json"


## Contrainte de decodage sur un schema JSON explicite (voie preferee).
func set_json_schema(schema: Dictionary) -> void:
	_format_constraint = schema if not schema.is_empty() else null


func clear_grammar() -> void:
	_format_constraint = null


## Configure la taille du contexte (passee a Ollama via options.num_ctx).
func set_context_size(p_n_ctx: int) -> void:
	_num_ctx = clampi(p_n_ctx, 512, 131072)  # Gemma 4 monte bien plus haut


## Messages effectifs pour un appel, et remise a zero de l'etat pose.
func _consommer_messages(prompt: String) -> Array:
	if _messages.is_empty():
		return [{"role": "user", "content": prompt}]
	var out: Array = _messages.duplicate(true)
	_messages.clear()
	return out


## Corps de la requete /api/chat, commun au bloquant et au streaming.
func _construire_payload(messages: Array, streaming: bool) -> Dictionary:
	var payload := {
		"model": model,
		"messages": messages,
		"stream": streaming,
		"options": {
			"temperature": _temperature,
			"top_p": _top_p,
			"top_k": _top_k,
			"repeat_penalty": _repetition_penalty,
			"num_predict": _max_tokens,
			"num_ctx": _num_ctx,
		},
	}
	# `think` doit TOUJOURS etre pose, jamais seulement quand on veut la reflexion.
	# Mesure sur la VM (gemma4, 2026-08-12) : champ absent = meme comportement que
	# think=true — le modele consomme tout son budget en reflexion interne et rend
	# une reponse VIDE (eval_count=60, done_reason="length", response=""). Avec
	# think=false explicite : reponse immediate, done_reason="stop".
	payload["think"] = thinking_mode
	if _format_constraint != null:
		payload["format"] = _format_constraint
	return payload


## Texte d'une reponse /api/chat : {"message": {"role":..., "content":...}}.
## Tolere l'ancienne forme /api/generate ({"response": ...}) au cas ou.
static func _texte_de_reponse(obj: Dictionary) -> String:
	var message: Variant = obj.get("message", null)
	if message is Dictionary:
		return str((message as Dictionary).get("content", ""))
	return str(obj.get("response", ""))


## Resolve a model registry key to an Ollama tag and configure defaults.
func configure_from_registry(model_key: String) -> bool:
	if model_key not in MODEL_REGISTRY:
		return false
	var entry: Dictionary = MODEL_REGISTRY[model_key]
	model = str(entry.tag)
	_num_ctx = int(entry.context_default)
	return true


## No-op: Ollama gere les threads en interne.
func set_thread_count(_gen_threads: int, _batch_threads: int) -> void:
	pass


## Compatibility: no model file needed (Ollama manages models).
func load_model(_path: String) -> int:
	if check_available() and check_model_available():
		return OK
	return ERR_CANT_CONNECT


## Retourne des infos sur la configuration.
func get_model_info() -> Dictionary:
	var info := {
		"backend": "ollama",
		"host": "%s:%d" % [host, port],
		"model": model,
		"n_ctx": _num_ctx,
		"max_tokens": _max_tokens,
		"model_loaded": _is_generating or check_available(),
	}
	info.merge(stats)
	return info


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — Thread-based blocking HTTP request
# ═══════════════════════════════════════════════════════════════════════════════

func _blocking_generate(messages: Array) -> void:
	var start_ms := Time.get_ticks_msec()
	var result := {}
	var body_str := JSON.stringify(_construire_payload(messages, false))

	# Connect
	var client := HTTPClient.new()
	var err := client.connect_to_host(host, port)
	if err != OK:
		result = {"error": "Ollama connect failed: %s" % error_string(err)}
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
			result = {"error": "Ollama connect timeout"}
			_store_result(result, start_ms)
			return

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		result = {"error": "Ollama status: %d" % client.get_status()}
		_store_result(result, start_ms)
		return

	# Send POST /api/chat
	var headers := [
		"Content-Type: application/json",
		"Content-Length: %d" % body_str.to_utf8_buffer().size(),
	]
	err = client.request(HTTPClient.METHOD_POST, "/api/chat", headers, body_str)
	if err != OK:
		result = {"error": "Ollama request failed: %s" % error_string(err)}
		_store_result(result, start_ms)
		return

	# Wait for response headers
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
		if _cancel_requested:
			result = {"error": "Cancelled"}
			_store_result(result, start_ms)
			return

	if not client.has_response():
		result = {"error": "Ollama no response"}
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
		else:
			OS.delay_msec(5)
		if _cancel_requested:
			result = {"error": "Cancelled"}
			_store_result(result, start_ms)
			return
		if Time.get_ticks_msec() - start_ms > READ_TIMEOUT_MS:
			result = {"error": "Ollama read timeout (%dms)" % READ_TIMEOUT_MS}
			_store_result(result, start_ms)
			return

	if status_code != 200:
		result = {"error": "Ollama HTTP %d: %s" % [status_code, response_body.get_string_from_utf8().left(200)]}
		_store_result(result, start_ms)
		return

	# Parse JSON response
	var json := JSON.new()
	var parse_err := json.parse(response_body.get_string_from_utf8())
	if parse_err != OK:
		result = {"error": "Ollama JSON parse error: %s" % json.get_error_message()}
		_store_result(result, start_ms)
		return

	var data: Dictionary = json.data if json.data is Dictionary else {}
	var text: String = _texte_de_reponse(data).strip_edges()

	# Strip <think>...</think> tags — certains modeles en emettent sans thinking_mode
	if "<think>" in text:
		text = _strip_thinking_tags(text)

	if text == "":
		result = {"error": "Ollama empty response"}
		_store_result(result, start_ms)
		return

	# Build result with metrics
	var total_ms: int = Time.get_ticks_msec() - start_ms
	var eval_count: int = int(data.get("eval_count", 0))
	var eval_duration_ns: int = int(data.get("eval_duration", 0))
	var tok_per_sec: float = 0.0
	if eval_duration_ns > 0:
		tok_per_sec = eval_count / (eval_duration_ns / 1e9)

	result = {"text": text}
	_update_stats(total_ms, eval_count, tok_per_sec)
	_store_result(result, start_ms)


func _store_result(result: Dictionary, _start_ms: int) -> void:
	_mutex.lock()
	_pending_result = result
	_result_ready = true
	_mutex.unlock()


func _update_stats(total_ms: int, eval_count: int, tok_per_sec: float, ttft_ms: int = -1) -> void:
	_mutex.lock()
	stats.last_total_ms = total_ms
	stats.last_eval_count = eval_count
	stats.last_tok_per_sec = tok_per_sec
	# ttft_ms: -1 means non-streaming (bulk response) — use total_ms as TTFT proxy
	stats.last_ttft_ms = ttft_ms if ttft_ms >= 0 else total_ms
	stats.llm_calls += 1
	if stats.llm_calls == 1:
		stats.avg_total_ms = float(total_ms)
		stats.avg_tok_per_sec = tok_per_sec
	else:
		var n: float = float(stats.llm_calls)
		stats.avg_total_ms = (stats.avg_total_ms * (n - 1.0) + float(total_ms)) / n
		stats.avg_tok_per_sec = (stats.avg_tok_per_sec * (n - 1.0) + tok_per_sec) / n
	_mutex.unlock()


## Strip <think>...</think> reasoning tags from Qwen 3.5 thinking mode output.
## Preserves the actual response text after the closing </think> tag.
static func _strip_thinking_tags(text: String) -> String:
	var think_end := text.find("</think>")
	if think_end >= 0:
		return text.substr(think_end + 8).strip_edges()
	# Unclosed <think> tag — strip everything from <think> onward
	var think_start := text.find("<think>")
	if think_start >= 0:
		return text.substr(0, think_start).strip_edges()
	return text
