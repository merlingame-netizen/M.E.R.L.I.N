extends Node

signal response_received(response: Dictionary)
signal action_executed(action: Dictionary)
signal error_occurred(message: String)
signal status_changed(status_text: String, detail_text: String, progress_value: float)
signal ready_changed(is_ready: bool)
signal log_updated(log_text: String)

# ARCHITECTURE MULTI-BRAIN + WORKER POOL — Qwen2.5-3B-Instruct (1 a 4 cerveaux)
# Phase 32: Instances specialisees, meme modele, configs differentes
# Brain 1 = Narrator (creatif), Brain 2 = Game Master (logique)
# Brain 3-4 = Worker Pool (prefetch, voice, balance — taches de fond)
const MODEL_FILE := "res://addons/merlin_llm/models/qwen2.5-3b-instruct-q4_k_m.gguf"
const MODEL_CANDIDATES := [MODEL_FILE]
const FastRoute = preload("res://addons/merlin_ai/fast_route.gd")

const PROMPTS_PATH := "res://data/ai/config/prompts.json"
const PROMPT_TEMPLATES_PATH := "res://data/ai/config/prompt_templates.json"
const ACTIONS_PATH := "res://data/ai/config/actions.json"

# ═══════════════════════════════════════════════════════════════════════════════
# BRAIN CONFIGURATION — Adaptatif selon plateforme
# ═══════════════════════════════════════════════════════════════════════════════
# 1 cerveau:  Mobile/Web (4-8 GB RAM)   — tout sequentiel
# 2 cerveaux: Desktop (16+ GB RAM)      — Narrator + GM parallele, pool sur idle
# 3 cerveaux: Desktop+ (32+ GB RAM)     — + 1 Worker dedie
# 4 cerveaux: Desktop Ultra (32+ GB RAM, 16+ threads) — + 2 Workers dedies

const BRAIN_SINGLE := 1   # ~2.5 GB RAM
const BRAIN_DUAL := 2     # ~4.5 GB RAM
const BRAIN_TRIPLE := 3   # ~6.5 GB RAM
const BRAIN_QUAD := 4     # ~8.8 GB RAM
const BRAIN_MAX := BRAIN_QUAD

# RAM par instance Qwen2.5-3B Q4_K_M
const RAM_PER_BRAIN_MB := 2200  # ~2.2 GB modele + KV cache

var brain_count: int = 0  # Actual loaded count (set by _init_local_models)
var _target_brain_count: int = 0  # Requested count (0 = auto-detect)

var rag_manager: RAGManager
var action_validator: ActionValidator
var game_state_sync: GameStateSync

# ── Primary Brain Instances (always dedicated to their role) ───────────────
var narrator_llm: Object = null      # Brain 1: Creative (toujours present)
var gamemaster_llm: Object = null    # Brain 2: Logic/JSON (desktop+)

# ── LoRA Adapters — Style specialization for Narrator brain ────────────────
const LORA_ADAPTER_DIR := "res://addons/merlin_llm/adapters/"
const LORA_NARRATOR_FILE := "merlin_narrator_lora.gguf"
var _narrator_lora_loaded := false
var _lora_adapters: Dictionary = {}  # tone_name -> adapter_id
var _current_lora_tone := ""

# Narrator: creative text, scenarios, dialogue, Merlin voice
var narrator_params := {"temperature": 0.75, "top_p": 0.92, "max_tokens": 200, "top_k": 40, "repetition_penalty": 1.35}
# Game Master: effects JSON, balance, rules, structured output (tighter for speed)
var gamemaster_params := {"temperature": 0.15, "top_p": 0.8, "max_tokens": 130, "top_k": 15, "repetition_penalty": 1.0}

# ── Worker Pool (Brain 3+) — background tasks ─────────────────────────────
# With 2 brains: primary brains handle bg tasks when idle (transparent)
# With 3-4 brains: dedicated pool workers, primary brains stay free
var _pool_workers: Array = []       # LLM instances (Brain 3, 4)
var _pool_busy: Array = []          # Busy state per pool worker
var _primary_narrator_busy := false # True during generate_narrative/parallel
var _primary_gm_busy := false       # True during generate_structured/parallel
var _narrator_busy_since := 0       # Timestamp (ms) when narrator became busy
var _gm_busy_since := 0             # Timestamp (ms) when GM became busy
const BRAIN_BUSY_TIMEOUT_MS := 60000  # 60s — force release if brain stuck

# Background task system (fire-and-forget via _process polling)
var _active_bg_tasks: Array = []    # Running: {type, llm, state, callback, params, start_time}
var _bg_queue: Array = []           # Pending: {type, system, input, params, callback, priority}
signal background_task_completed(task_type: String, result: Dictionary)

const TASK_PREFETCH := "prefetch"
const TASK_VOICE := "voice"
const TASK_BALANCE := "balance"
const TASK_PRIORITIES := {"prefetch": 0, "voice": 1, "balance": 2}
const BG_QUEUE_MAX_SIZE := 100      # Max pending tasks (prevents OOM)
const BG_TASK_TIMEOUT_MS := 30000   # 30s timeout for stuck bg tasks

# Backward-compatible aliases (router = narrator, executor = gamemaster)
var router_params: Dictionary:
	get: return narrator_params
	set(v): narrator_params = v
var executor_params: Dictionary:
	get: return gamemaster_params
	set(v): gamemaster_params = v

# Prompt templates (loaded from prompt_templates.json)
var prompt_templates: Dictionary = {}

var prompts: Dictionary = {}
var is_ready := false
var status_text := "Connexion: OFF"
var detail_text := "Initialisation..."
var progress_value := 0.0
var log_entries: Array[String] = []
var _last_log_line := ""
var model_file_used := MODEL_FILE
var response_cache: Dictionary = {}
const RESPONSE_CACHE_LIMIT := 200
var session_contexts: Dictionary = {}
const SESSION_HISTORY_LIMIT := 24
const SESSION_PERSIST_PATH := "user://ai/memory/llm_session_history.json"
const SESSION_PERSIST_LIMIT := 50
const STREAM_CHUNK_TOKENS := 32
const STREAM_MAX_ROUNDS := 4
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

var _warmup_started := false

func _ready() -> void:
	set_process(false)  # Enabled when background tasks are active
	rag_manager = RAGManager.new()
	action_validator = ActionValidator.new()
	game_state_sync = GameStateSync.new()
	add_child(rag_manager)
	add_child(action_validator)
	add_child(game_state_sync)
	_load_prompts()
	_load_prompt_templates()
	# Models loaded on demand via start_warmup() — not at autoload time
	load_session_history()


## Start LLM model loading. Call from MenuPrincipal on "Nouvelle Partie"/"Continuer".
## Emits status_changed during loading and ready_changed(true) when done.
func start_warmup() -> void:
	if _warmup_started or is_ready:
		return
	_warmup_started = true
	_init_local_models()


func _exit_tree() -> void:
	save_session_history()


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
	var result = await _run_llm(narrator_llm, prompt, narrator_params)
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
	var result = await _run_llm(narrator_llm, prompt, narrator_params)
	if result.has("error"):
		return {"response": "Erreur executeur: " + str(result.error), "action": null}
	var text := clean_response(str(result.get("text", "")))
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
	if llm.has_method("set_advanced_sampling"):
		var top_k = int(params.get("top_k", 40))
		var rep_penalty = float(params.get("repetition_penalty", 1.3))
		llm.set_advanced_sampling(top_k, rep_penalty)
	var state = {"done": false, "result": {}}
	llm.generate_async(prompt, func(res):
		if not first_token_received:
			ttft = Time.get_ticks_msec() - start_time
			first_token_received = true
		state.result = res
		state.done = true
	)
	# Adaptive polling: instant exit on done, then back off to save CPU
	var poll_count := 0
	while not state.done:
		llm.poll_result()
		if state.done:
			break
		poll_count += 1
		if poll_count < 10:
			await get_tree().process_frame
		else:
			await get_tree().create_timer(0.01).timeout
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
	model_file_used = _resolve_model_file(MODEL_CANDIDATES)
	if model_file_used == "":
		_set_status("Connexion: OFF", "Modele manquant (aucun GGUF)", 0.0)
		ready_changed.emit(false)
		return

	# Determine how many brains to load
	var target: int = _target_brain_count if _target_brain_count > 0 else detect_optimal_brains()
	_log("Target brains: %d (requested=%d, auto=%d)" % [target, _target_brain_count, detect_optimal_brains()])

	var model_path := _to_fs_path(model_file_used)
	brain_count = 0

	# ── Brain 1: Narrator (always loaded) ──────────────────────────────────
	_set_status("Connexion: ...", "Chargement Brain 1/Narrator", 10.0)
	narrator_llm = ClassDB.instantiate("MerlinLLM")
	var narrator_err = narrator_llm.load_model(model_path)
	if narrator_err != OK:
		_log("Brain 1 (Narrator) load err: " + str(narrator_err))
		_set_status("Connexion: OFF", "Erreur chargement Brain 1", 0.0)
		ready_changed.emit(false)
		return
	brain_count = 1
	# In single-brain mode, narrator handles everything
	gamemaster_llm = narrator_llm
	_log("Brain 1 (Narrator) loaded")
	# Load LoRA adapter for Narrator (style specialization)
	_load_narrator_lora()

	# ── Brain 2: Game Master (desktop + high-end mobile) ───────────────────
	if target >= BRAIN_DUAL:
		_set_status("Connexion: ...", "Chargement Brain 2/Game Master", 40.0)
		var gm_instance = ClassDB.instantiate("MerlinLLM")
		var gm_err = gm_instance.load_model(model_path)
		if gm_err == OK:
			gamemaster_llm = gm_instance
			brain_count = 2
			_log("Brain 2 (Game Master) loaded")
		else:
			_log("Brain 2 (Game Master) failed — staying at 1 brain")

	# ── Brain 3-4: Worker Pool (background tasks) ─────────────────────────
	_pool_workers.clear()
	_pool_busy.clear()
	var pool_names := ["Worker A", "Worker B"]
	for i in range(2):
		var pool_brain_num: int = 3 + i
		if target >= pool_brain_num and brain_count >= pool_brain_num - 1:
			var progress_pct: float = 50.0 + i * 20.0
			_set_status("Connexion: ...", "Chargement Brain %d/%s" % [pool_brain_num, pool_names[i]], progress_pct)
			var pw_instance = ClassDB.instantiate("MerlinLLM")
			var pw_err = pw_instance.load_model(model_path)
			if pw_err == OK:
				_pool_workers.append(pw_instance)
				_pool_busy.append(false)
				brain_count = pool_brain_num
				_log("Brain %d (%s) loaded -> pool" % [pool_brain_num, pool_names[i]])
			else:
				_log("Brain %d (%s) failed — pool stays at %d workers" % [pool_brain_num, pool_names[i], _pool_workers.size()])
				break  # Don't try Brain 4 if Brain 3 failed

	var ram_estimate: int = brain_count * RAM_PER_BRAIN_MB
	var mode_name := _get_brain_mode_name()
	_set_status("Connexion: OK", "%s (%d cerveaux, ~%d MB)" % [mode_name, brain_count, ram_estimate], 100.0)
	is_ready = true
	ready_changed.emit(true)
	_log("Model OK: %s | %d brains | %s | ~%d MB RAM" % [model_file_used, brain_count, mode_name, ram_estimate])


# ═══════════════════════════════════════════════════════════════════════════════
# LORA ADAPTER MANAGEMENT — Style specialization for Narrator
# ═══════════════════════════════════════════════════════════════════════════════

func _load_narrator_lora() -> void:
	## Load LoRA adapter for the Narrator brain (Celtic narrative style).
	## Supports single adapter or multi-adapter (per-tone) mode.
	if narrator_llm == null or not narrator_llm.has_method("load_lora_adapter"):
		_log("LoRA: MerlinLLM does not support load_lora_adapter — skipping")
		return

	# Try single narrator adapter first
	var single_path := LORA_ADAPTER_DIR + LORA_NARRATOR_FILE
	if FileAccess.file_exists(single_path):
		var fs_path := _to_fs_path(single_path)
		var err = narrator_llm.load_lora_adapter(fs_path, 1.0)
		if err == OK:
			_narrator_lora_loaded = true
			_log("LoRA: Narrator adapter loaded: %s" % LORA_NARRATOR_FILE)
		else:
			_log("LoRA: Narrator adapter load failed (err %d)" % err)
		return

	# Try per-tone adapters (Multi-LoRA mode)
	_load_tone_adapters()


func _load_tone_adapters() -> void:
	## Load tone-specific LoRA adapters for dynamic switching.
	## Files: lora_playful.gguf, lora_melancholy.gguf, etc.
	if narrator_llm == null or not narrator_llm.has_method("load_lora_adapter"):
		return
	var tones := ["playful", "melancholy", "cryptic", "warning", "mysterious", "warm"]
	var loaded := 0
	for tone in tones:
		var path := LORA_ADAPTER_DIR + "lora_%s.gguf" % tone
		if FileAccess.file_exists(path):
			var fs_path := _to_fs_path(path)
			var adapter_id = narrator_llm.load_lora_adapter(fs_path)
			if adapter_id != null and adapter_id >= 0:
				_lora_adapters[tone] = adapter_id
				loaded += 1
				_log("LoRA: Tone adapter '%s' loaded (id=%d)" % [tone, adapter_id])
	if loaded > 0:
		_narrator_lora_loaded = true
		_log("LoRA: Multi-tone mode active (%d adapters)" % loaded)
	else:
		_log("LoRA: No adapters found in %s" % LORA_ADAPTER_DIR)


func set_narrator_tone(tone: String) -> void:
	## Switch the active LoRA adapter based on narrative tone.
	## Called by MerlinOmniscient before each Narrator generation.
	if not _narrator_lora_loaded or _lora_adapters.is_empty():
		return
	if tone == _current_lora_tone:
		return  # Already active
	if narrator_llm == null:
		return
	if _lora_adapters.has(tone):
		if narrator_llm.has_method("set_lora_adapter"):
			narrator_llm.set_lora_adapter(_lora_adapters[tone])
			_current_lora_tone = tone
	else:
		# No adapter for this tone — use base model
		if narrator_llm.has_method("clear_lora_adapter"):
			narrator_llm.clear_lora_adapter()
			_current_lora_tone = ""


func has_lora_adapters() -> bool:
	return _narrator_lora_loaded


## Detect the optimal number of brains based on platform and available resources.
static func detect_optimal_brains() -> int:
	# Mobile: check for mobile/web feature flags
	var is_mobile: bool = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	var is_web: bool = OS.has_feature("web")

	if is_web:
		return 1  # Web = always single brain (WASM limitations)

	if is_mobile:
		# High-end phones 2024+ (8-12 GB RAM) can handle 2 brains
		# But entry-level phones (4 GB) cannot
		# Use processor count as a proxy for device tier
		var cpu_count: int = OS.get_processor_count()
		if cpu_count >= 8:
			return 2  # Flagship: 8+ cores = likely 8-12 GB RAM
		return 1  # Entry/mid-range: single brain

	# Desktop: use processor count as tier indicator — minimum 2 brains
	var cpu_count: int = OS.get_processor_count()
	var detected: int = 1
	if cpu_count >= 16:
		detected = 4  # Ultra desktop: 16+ threads = Ryzen 9/i9 (32+ GB RAM)
	elif cpu_count >= 12:
		detected = 3  # High-end desktop: 12+ threads (32+ GB RAM)
	elif cpu_count >= 6:
		detected = 2  # Mid desktop: 6+ threads (16+ GB RAM)
	# Force minimum 2 brains on desktop (Narrator + Game Master always needed)
	return maxi(2, detected)


## Set the target brain count. Call before _init_local_models() or use reload_models().
## Pass 0 for auto-detection.
func set_brain_count(count: int) -> void:
	_target_brain_count = clampi(count, 0, BRAIN_MAX)
	_log("Brain count target set to: %d (%s)" % [_target_brain_count, "auto" if _target_brain_count == 0 else "manual"])


func _get_brain_mode_name() -> String:
	match brain_count:
		1: return "Single (Narrator seul)"
		2: return "Dual (Narrator + GM)"
		3: return "Triple (Narrator + GM + 1 Worker)"
		4: return "Quad (Narrator + GM + 2 Workers)"
		_: return "Unknown (%d)" % brain_count

func _to_fs_path(path: String) -> String:
	return ProjectSettings.globalize_path(path)

func reload_models() -> void:
	if not _active_bg_tasks.is_empty():
		_log("WARNING: %d bg tasks active — cancelling before reload" % _active_bg_tasks.size())
		for task in _active_bg_tasks:
			_release_bg_brain(task.llm)
		_active_bg_tasks.clear()
		_bg_queue.clear()
		set_process(false)
	_init_local_models()

func ensure_ready() -> void:
	if not is_ready:
		start_warmup()

func generate_with_system(system_prompt: String, user_input: String, params_override: Dictionary = {}) -> Dictionary:
	if not is_ready:
		return {"error": "LLM non pret"}
	var template = prompts.get("executor_template", "{system}\n{input}")
	var prompt = template.format({"system": system_prompt, "input": user_input})
	# Use gamemaster for grammar-constrained, narrator otherwise
	var has_grammar: bool = params_override.has("grammar") and str(params_override.get("grammar", "")) != ""
	var target_llm: Object = gamemaster_llm if has_grammar else narrator_llm
	var params: Dictionary = (gamemaster_params if has_grammar else narrator_params).duplicate(true)
	for key in params_override.keys():
		params[key] = params_override[key]
	var cache_key = _make_cache_key(system_prompt, user_input, params)
	if response_cache.has(cache_key):
		var cached = response_cache[cache_key]
		cached["source"] = "cache"
		return cached
	# Grammar-constrained decoding (Phase 30) — uses Game Master instance
	var grammar_str: String = str(params.get("grammar", ""))
	var grammar_root: String = str(params.get("grammar_root", "root"))
	if grammar_str != "" and target_llm != null and target_llm.has_method("set_grammar"):
		target_llm.set_grammar(grammar_str, grammar_root)
		_log("Grammar constrained decoding active (Game Master)")
	var result = await _run_llm(target_llm, prompt, params)
	# Clear grammar after generation to avoid affecting subsequent calls
	if grammar_str != "" and target_llm != null and target_llm.has_method("clear_grammar"):
		target_llm.clear_grammar()
	if result.has("text"):
		result["text"] = clean_response(str(result.text))
	_store_cache(cache_key, result)
	return result

func generate_with_system_stream(system_prompt: String, user_input: String, params_override: Dictionary = {}, on_chunk: Callable = Callable()) -> Dictionary:
	if not is_ready:
		return {"error": "LLM non pret"}
	var template = prompts.get("executor_template", "{system}\n{input}")
	var base_prompt = template.format({"system": system_prompt, "input": user_input})
	var params_base = narrator_params.duplicate(true)
	for key in params_override.keys():
		params_base[key] = params_override[key]
	var remaining = int(params_base.get("max_tokens", narrator_params.max_tokens))
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
		var result = await _run_llm(narrator_llm, prompt, params)
		var text := clean_response(str(result.get("text", "")))
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
	return {"text": clean_response(collected)}

## Genere une reponse rapide avec le Narrator LLM — utilise pour dialogues, commentaires
func generate_with_router(system_prompt: String, user_input: String, params_override: Dictionary = {}) -> Dictionary:
	if not is_ready:
		return {"error": "LLM non pret"}
	if narrator_llm == null:
		return {"error": "Narrator LLM non charge"}
	var template = prompts.get("executor_template", "{system}\n{input}")
	var prompt = template.format({"system": system_prompt, "input": user_input})
	var params = narrator_params.duplicate(true)
	for key in params_override.keys():
		params[key] = params_override[key]
	var result = await _run_llm(narrator_llm, prompt, params)
	if result.has("text"):
		result["text"] = clean_response(str(result.text))
	return result

func set_router_params(temp: float, top_p: float, max_tokens: int) -> void:
	narrator_params.temperature = temp
	narrator_params.top_p = top_p
	narrator_params.max_tokens = max_tokens
	_log("Narrator params: T=" + str(temp) + " top_p=" + str(top_p) + " max=" + str(max_tokens))

func set_executor_params(temp: float, top_p: float, max_tokens: int) -> void:
	gamemaster_params.temperature = temp
	gamemaster_params.top_p = top_p
	gamemaster_params.max_tokens = max_tokens
	_log("Game Master params: T=" + str(temp) + " top_p=" + str(top_p) + " max=" + str(max_tokens))

func set_narrator_params(temp: float, top_p: float, max_tokens: int) -> void:
	set_router_params(temp, top_p, max_tokens)

func set_gamemaster_params(temp: float, top_p: float, max_tokens: int) -> void:
	set_executor_params(temp, top_p, max_tokens)

func get_router_params() -> Dictionary:
	return narrator_params.duplicate(true)

func get_executor_params() -> Dictionary:
	return gamemaster_params.duplicate(true)

func get_narrator_params() -> Dictionary:
	return narrator_params.duplicate(true)

func get_gamemaster_params() -> Dictionary:
	return gamemaster_params.duplicate(true)

func get_status() -> Dictionary:
	return {"status": status_text, "detail": detail_text, "progress": progress_value, "ready": is_ready}

func get_model_info() -> Dictionary:
	return {
		"model": model_file_used,
		"brain_count": brain_count,
		"brain_mode": _get_brain_mode_name(),
		"pool_workers": _pool_workers.size(),
		"pool_idle": get_pool_idle_count(),
		"dual_mode": brain_count >= 2,
		"has_pool": _pool_workers.size() > 0,
		"narrator": model_file_used,
		"gamemaster": model_file_used,
		# Backward compat
		"router": model_file_used,
		"executor": model_file_used,
		"has_prefetcher": _pool_workers.size() > 0,
	}

func is_dual_mode() -> bool:
	return brain_count >= 2

func has_prefetcher() -> bool:
	return _pool_workers.size() > 0 or not _primary_narrator_busy or not _primary_gm_busy

func has_pool() -> bool:
	return _pool_workers.size() > 0

func get_pool_size() -> int:
	return _pool_workers.size()

func get_pool_idle_count() -> int:
	var count := 0
	for i in range(_pool_busy.size()):
		if not _pool_busy[i]:
			count += 1
	return count

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

func save_session_history() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://ai/memory"))
	var to_save: Dictionary = {}
	for session_id in session_contexts:
		var session_map: Dictionary = _ensure_session_map(session_id)
		var trimmed_map: Dictionary = {}
		for channel in session_map:
			var arr: Array = session_map[channel]
			if arr.size() > SESSION_PERSIST_LIMIT:
				arr = arr.slice(arr.size() - SESSION_PERSIST_LIMIT)
			trimmed_map[channel] = arr
		to_save[session_id] = trimmed_map
	var file := FileAccess.open(SESSION_PERSIST_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(to_save))
		file.close()
		_log("Session history saved (%d sessions)" % to_save.size())


func load_session_history() -> void:
	if not FileAccess.file_exists(SESSION_PERSIST_PATH):
		return
	var file := FileAccess.open(SESSION_PERSIST_PATH, FileAccess.READ)
	if not file:
		return
	var content := file.get_as_text()
	file.close()
	var data = JSON.parse_string(content)
	if typeof(data) != TYPE_DICTIONARY:
		_log("Session history file invalid — skipping load")
		return
	for session_id in data:
		var session_map = data[session_id]
		if typeof(session_map) != TYPE_DICTIONARY:
			continue
		session_contexts[session_id] = session_map
	_log("Session history loaded (%d sessions)" % data.size())


func clear_session_history() -> void:
	session_contexts.clear()
	if FileAccess.file_exists(SESSION_PERSIST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PERSIST_PATH))
	_log("Session history cleared")


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

# ═══════════════════════════════════════════════════════════════════════════════
# DUAL-INSTANCE GENERATION METHODS (Phase 32)
# ═══════════════════════════════════════════════════════════════════════════════

## Generate creative text using the Narrator instance (high temp, free text).
func generate_narrative(system_prompt: String, user_input: String, params_override: Dictionary = {}) -> Dictionary:
	if not is_ready or narrator_llm == null:
		return {"error": "Narrator LLM non pret"}
	_primary_narrator_busy = true
	_narrator_busy_since = Time.get_ticks_msec()
	var template: String = prompts.get("executor_template", "{system}\n{input}")
	var prompt: String = template.format({"system": system_prompt, "input": user_input})
	var params: Dictionary = narrator_params.duplicate(true)
	for key in params_override.keys():
		params[key] = params_override[key]
	# Narrator never uses grammar — free text only
	params.erase("grammar")
	var result: Dictionary = await _run_llm(narrator_llm, prompt, params)
	if result.has("text"):
		result["text"] = clean_response(str(result.text))
	_primary_narrator_busy = false
	_narrator_busy_since = 0
	_dispatch_from_queue()
	return result

## Generate structured output using the Game Master instance (low temp, GBNF grammar).
func generate_structured(system_prompt: String, user_input: String, grammar: String = "", params_override: Dictionary = {}) -> Dictionary:
	if not is_ready or gamemaster_llm == null:
		return {"error": "Game Master LLM non pret"}
	_primary_gm_busy = true
	_gm_busy_since = Time.get_ticks_msec()
	var template: String = prompts.get("executor_template", "{system}\n{input}")
	var prompt: String = template.format({"system": system_prompt, "input": user_input})
	var params: Dictionary = gamemaster_params.duplicate(true)
	for key in params_override.keys():
		params[key] = params_override[key]
	# Apply GBNF grammar if provided
	if grammar != "" and gamemaster_llm.has_method("set_grammar"):
		gamemaster_llm.set_grammar(grammar, "root")
		_log("Game Master: GBNF grammar active (%d chars)" % grammar.length())
	var result: Dictionary = await _run_llm(gamemaster_llm, prompt, params)
	if grammar != "" and gamemaster_llm.has_method("clear_grammar"):
		gamemaster_llm.clear_grammar()
	if result.has("text"):
		result["text"] = clean_response(str(result.text))
	_primary_gm_busy = false
	_gm_busy_since = 0
	_dispatch_from_queue()
	return result

## Generate narrative text + structured effects in PARALLEL using both instances.
## Returns {"narrative": Dictionary, "structured": Dictionary, "parallel": bool}
func generate_parallel(narrator_system: String, narrator_input: String,
		gm_system: String, gm_input: String, grammar: String = "",
		narrator_overrides: Dictionary = {}, gm_overrides: Dictionary = {}) -> Dictionary:
	if not is_ready:
		return {"error": "LLM non pret"}
	if brain_count < 2:
		# Sequential fallback when sharing a single instance
		var narrative: Dictionary = await generate_narrative(narrator_system, narrator_input, narrator_overrides)
		var structured: Dictionary = await generate_structured(gm_system, gm_input, grammar, gm_overrides)
		return {"narrative": narrative, "structured": structured, "parallel": false}

	# TRUE PARALLEL: both instances generate simultaneously on separate threads
	_primary_narrator_busy = true
	_narrator_busy_since = Time.get_ticks_msec()
	_primary_gm_busy = true
	_gm_busy_since = Time.get_ticks_msec()
	var template: String = prompts.get("executor_template", "{system}\n{input}")
	var narrator_prompt: String = template.format({"system": narrator_system, "input": narrator_input})
	var gm_prompt: String = template.format({"system": gm_system, "input": gm_input})

	var n_params: Dictionary = narrator_params.duplicate(true)
	for key in narrator_overrides.keys():
		n_params[key] = narrator_overrides[key]
	n_params.erase("grammar")

	var gm_params: Dictionary = gamemaster_params.duplicate(true)
	for key in gm_overrides.keys():
		gm_params[key] = gm_overrides[key]

	# Apply GBNF grammar to Game Master
	if grammar != "" and gamemaster_llm.has_method("set_grammar"):
		gamemaster_llm.set_grammar(grammar, "root")

	# Set sampling params on both instances
	_apply_sampling(narrator_llm, n_params)
	_apply_sampling(gamemaster_llm, gm_params)

	# Launch both generations simultaneously
	var state := {"narrator_done": false, "gm_done": false, "narrator_result": {}, "gm_result": {}}
	var start_time := Time.get_ticks_msec()

	narrator_llm.generate_async(narrator_prompt, func(res: Dictionary) -> void:
		state.narrator_result = res
		state.narrator_done = true
	)
	gamemaster_llm.generate_async(gm_prompt, func(res: Dictionary) -> void:
		state.gm_result = res
		state.gm_done = true
	)

	# Poll both until done — instant exit on completion
	var poll_count := 0
	while not state.narrator_done or not state.gm_done:
		if not state.narrator_done:
			narrator_llm.poll_result()
		if not state.gm_done:
			gamemaster_llm.poll_result()
		if state.narrator_done and state.gm_done:
			break
		poll_count += 1
		if poll_count < 10:
			await get_tree().process_frame
		else:
			await get_tree().create_timer(0.01).timeout

	var total_time := Time.get_ticks_msec() - start_time
	_log("Parallel generation: %dms (brains=%d)" % [total_time, brain_count])

	# Clear grammar
	if grammar != "" and gamemaster_llm.has_method("clear_grammar"):
		gamemaster_llm.clear_grammar()

	# Clean responses
	var narrative_result: Dictionary = state.narrator_result
	if narrative_result.has("text"):
		narrative_result["text"] = clean_response(str(narrative_result.text))
	var gm_result: Dictionary = state.gm_result
	if gm_result.has("text"):
		gm_result["text"] = clean_response(str(gm_result.text))

	_primary_narrator_busy = false
	_narrator_busy_since = 0
	_primary_gm_busy = false
	_gm_busy_since = 0
	_dispatch_from_queue()
	return {"narrative": narrative_result, "structured": gm_result, "parallel": true, "time_ms": total_time}

## Generate a card using the worker pool (await-based).
## Uses pool worker if available, else falls back to idle primary brain.
func generate_prefetch(system_prompt: String, user_input: String, params_override: Dictionary = {}) -> Dictionary:
	if not is_ready:
		return {"error": "LLM non pret"}
	var target_llm: Object = _lease_bg_brain()
	if target_llm == null:
		return {"error": "Tous les cerveaux occupes"}
	var template: String = prompts.get("executor_template", "{system}\n{input}")
	var prompt: String = template.format({"system": system_prompt, "input": user_input})
	var params: Dictionary = narrator_params.duplicate(true)
	for key in params_override.keys():
		params[key] = params_override[key]
	params.erase("grammar")
	var result: Dictionary = await _run_llm(target_llm, prompt, params)
	_release_bg_brain(target_llm)
	if result.has("text"):
		result["text"] = clean_response(str(result.text))
	result["_pool_brain"] = _pool_workers.has(target_llm)
	return result

## Generate a Merlin voice comment using the pool (await-based).
func generate_voice(system_prompt: String, user_input: String, params_override: Dictionary = {}) -> Dictionary:
	if not is_ready:
		return {"error": "LLM non pret"}
	var target_llm: Object = _lease_bg_brain()
	if target_llm == null:
		return {"error": "Tous les cerveaux occupes"}
	var template: String = prompts.get("executor_template", "{system}\n{input}")
	var prompt: String = template.format({"system": system_prompt, "input": user_input})
	var params: Dictionary = narrator_params.duplicate(true)
	params["max_tokens"] = 64
	params["temperature"] = 0.6
	for key in params_override.keys():
		params[key] = params_override[key]
	params.erase("grammar")
	var result: Dictionary = await _run_llm(target_llm, prompt, params)
	_release_bg_brain(target_llm)
	if result.has("text"):
		result["text"] = clean_response(str(result.text))
	return result

func _apply_sampling(llm: Object, params: Dictionary) -> void:
	if llm == null:
		return
	if llm.has_method("set_sampling_params"):
		llm.set_sampling_params(float(params.temperature), float(params.top_p), int(params.max_tokens))
	if llm.has_method("set_advanced_sampling"):
		llm.set_advanced_sampling(int(params.get("top_k", 40)), float(params.get("repetition_penalty", 1.3)))

# ═══════════════════════════════════════════════════════════════════════════════
# PROMPT TEMPLATE LOADING
# ═══════════════════════════════════════════════════════════════════════════════

func _load_prompt_templates() -> void:
	if FileAccess.file_exists(PROMPT_TEMPLATES_PATH):
		var file := FileAccess.open(PROMPT_TEMPLATES_PATH, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(data) == TYPE_DICTIONARY:
			prompt_templates = data
			_log("Prompt templates loaded: %d templates" % prompt_templates.size())

func get_prompt_template(role: String, task: String) -> Dictionary:
	var key := role + "_" + task
	return prompt_templates.get(key, {})

# ═══════════════════════════════════════════════════════════════════════════════

## Strip ChatML template tokens from raw LLM output
func clean_response(raw: String) -> String:
	var text := raw.strip_edges()
	# Truncate at first template token
	for tok in ["<|im_end|>", "<|im_start|>", "<|endoftext|>", "<|im_end>", "<|im_start>"]:
		var idx := text.find(tok)
		if idx >= 0:
			text = text.substr(0, idx)
	# Regex sweep for remaining variants
	var rx := RegEx.new()
	rx.compile("<\\|?im_(?:end|start)\\|?>")
	text = rx.sub(text, "", true)
	rx.compile("<\\|?endoftext\\|?>")
	text = rx.sub(text, "", true)
	# Strip role prefixes
	for prefix in ["system\n", "user\n", "assistant\n"]:
		if text.begins_with(prefix):
			text = text.substr(prefix.length())
	return text.strip_edges()


func _looks_complete(text: String) -> bool:
	var trimmed = text.strip_edges()
	if trimmed.length() < 60:
		return false
	if trimmed.find("\n") != -1:
		return true
	if trimmed.ends_with(".") or trimmed.ends_with("!") or trimmed.ends_with("?"):
		return true
	return false

# ═══════════════════════════════════════════════════════════════════════════════
# WORKER POOL — Background task management
# ═══════════════════════════════════════════════════════════════════════════════
# With 2 brains: primary brains handle bg tasks BETWEEN card generations
# With 3-4 brains: pool workers handle bg tasks, primary brains stay free

func _process(_delta: float) -> void:
	## Poll active background tasks (fire-and-forget mode).
	# Brain busy timeout — prevent deadlock if a brain crashes
	var now_check := Time.get_ticks_msec()
	if _primary_narrator_busy and _narrator_busy_since > 0 and now_check - _narrator_busy_since > BRAIN_BUSY_TIMEOUT_MS:
		_primary_narrator_busy = false
		_narrator_busy_since = 0
		_log("Narrator busy timeout (%ds) — force release" % [BRAIN_BUSY_TIMEOUT_MS / 1000])
	if _primary_gm_busy and _gm_busy_since > 0 and now_check - _gm_busy_since > BRAIN_BUSY_TIMEOUT_MS:
		_primary_gm_busy = false
		_gm_busy_since = 0
		_log("GM busy timeout (%ds) — force release" % [BRAIN_BUSY_TIMEOUT_MS / 1000])

	if _active_bg_tasks.is_empty() and _bg_queue.is_empty():
		set_process(false)
		return

	# Poll all active tasks
	var completed_indices: Array[int] = []
	var now_ms := Time.get_ticks_msec()
	for i in range(_active_bg_tasks.size()):
		var task: Dictionary = _active_bg_tasks[i]
		if task.state.done:
			completed_indices.append(i)
		elif now_ms - int(task.get("start_time", now_ms)) > BG_TASK_TIMEOUT_MS:
			_log("BG task '%s' timed out after %dms — releasing brain" % [str(task.type), BG_TASK_TIMEOUT_MS])
			completed_indices.append(i)
		elif is_instance_valid(task.llm):
			task.llm.poll_result()
		else:
			_log("BG task '%s' — brain instance invalid — releasing" % str(task.type))
			completed_indices.append(i)

	# Process completed (reverse for safe removal)
	for i in range(completed_indices.size() - 1, -1, -1):
		var idx: int = completed_indices[i]
		var task: Dictionary = _active_bg_tasks[idx]
		_active_bg_tasks.remove_at(idx)
		_release_bg_brain(task.llm)
		var result: Dictionary = task.state.result
		if result.has("text"):
			result["text"] = clean_response(str(result.text))
		if task.has("callback") and task.callback is Callable and task.callback.is_valid():
			task.callback.call(result)
		background_task_completed.emit(str(task.type), result)
		_log("BG task '%s' completed" % str(task.type))

	# Dispatch queued tasks
	_dispatch_from_queue()


## Submit a fire-and-forget background task (no await needed).
## callback receives Dictionary result when done.
func submit_background_task(task_type: String, system_prompt: String,
		user_input: String, params: Dictionary = {},
		callback: Callable = Callable()) -> bool:
	if not is_ready:
		return false
	var priority: int = TASK_PRIORITIES.get(task_type, 10)
	var task := {
		"type": task_type,
		"system": system_prompt,
		"input": user_input,
		"params": params,
		"callback": callback,
		"priority": priority,
	}
	# Try immediate dispatch
	var llm: Object = _lease_bg_brain()
	if llm != null:
		_fire_bg_task(task, llm)
		return true
	# Queue for later (with size limit)
	if _bg_queue.size() >= BG_QUEUE_MAX_SIZE:
		_log("BG queue full (%d tasks), dropping oldest" % _bg_queue.size())
		_bg_queue.pop_front()
	_bg_queue.append(task)
	_bg_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.priority) < int(b.priority)
	)
	_log("BG task '%s' queued (queue=%d)" % [task_type, _bg_queue.size()])
	set_process(true)
	return false


## Submit a balance check as fire-and-forget background task.
func submit_balance_check(system_prompt: String, user_input: String,
		callback: Callable = Callable()) -> bool:
	return submit_background_task(TASK_BALANCE, system_prompt, user_input,
		{"max_tokens": 100, "temperature": 0.15}, callback)


func _fire_bg_task(task: Dictionary, llm: Object) -> void:
	## Launch a background task on the given brain (fire-and-forget).
	var template: String = prompts.get("executor_template", "{system}\n{input}")
	var prompt: String = template.format({"system": task.system, "input": task.input})
	var params: Dictionary = task.params
	_apply_sampling(llm, params)
	# Grammar
	var grammar_str: String = str(params.get("grammar", ""))
	if grammar_str != "" and llm.has_method("set_grammar"):
		llm.set_grammar(grammar_str, "root")
	var state := {"done": false, "result": {}}
	llm.generate_async(prompt, func(res: Dictionary) -> void:
		state.result = res
		state.done = true
		if grammar_str != "" and llm.has_method("clear_grammar"):
			llm.clear_grammar()
	)
	var active := {
		"type": task.type,
		"llm": llm,
		"state": state,
		"callback": task.get("callback", Callable()),
		"params": params,
		"start_time": Time.get_ticks_msec(),
	}
	_active_bg_tasks.append(active)
	set_process(true)  # Enable polling
	_log("BG task '%s' dispatched (active=%d)" % [str(task.type), _active_bg_tasks.size()])


func _dispatch_from_queue() -> void:
	## Dispatch queued tasks to available brains.
	while not _bg_queue.is_empty():
		var llm: Object = _lease_bg_brain()
		if llm == null:
			break  # No idle brain available
		var task: Dictionary = _bg_queue.pop_front()
		_fire_bg_task(task, llm)


## Lease an idle brain for background work. Returns null if all busy.
## Priority: pool workers first, then idle primary brains.
func _lease_bg_brain() -> Object:
	# 1. Pool workers (dedicated, always preferred)
	for i in range(_pool_workers.size()):
		if not _pool_busy[i] and is_instance_valid(_pool_workers[i]):
			_pool_busy[i] = true
			return _pool_workers[i]
	# 2. Primary Narrator (only if not doing a primary task)
	if not _primary_narrator_busy and narrator_llm != null and is_instance_valid(narrator_llm):
		_primary_narrator_busy = true
		return narrator_llm
	# 3. Primary Game Master (only if distinct and not busy)
	if not _primary_gm_busy and gamemaster_llm != null and gamemaster_llm != narrator_llm and is_instance_valid(gamemaster_llm):
		_primary_gm_busy = true
		return gamemaster_llm
	return null


## Release a brain back to the pool after background work.
func _release_bg_brain(llm: Object) -> void:
	for i in range(_pool_workers.size()):
		if _pool_workers[i] == llm:
			_pool_busy[i] = false
			return
	if llm == narrator_llm:
		_primary_narrator_busy = false
	elif llm == gamemaster_llm:
		_primary_gm_busy = false
