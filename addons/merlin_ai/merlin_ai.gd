extends Node

signal response_received(response: Dictionary)
signal action_executed(action: Dictionary)
signal error_occurred(message: String)
signal status_changed(status_text: String, detail_text: String, progress_value: float)
signal ready_changed(is_ready: bool)
signal log_updated(log_text: String)

# ARCHITECTURE MULTI-BRAIN HETEROGENE — Qwen 3.5 family (0.8B/2B/4B)
# Phase 33: Chaque cerveau utilise un modele different, optimise pour son role
# Brain 1 = Narrator (4B creatif), Brain 2 = Game Master (2B logique + thinking)
# Brain 3-4 = Worker Pool / Judge (0.8B — taches de fond / evaluation)
# SINGLE+ mode: time-sharing (un seul modele en RAM, swap Ollama)
const MODEL_FILE := "res://addons/merlin_llm/models/qwen3.5-4b-q4_k_m.gguf"
const MODEL_CANDIDATES := [MODEL_FILE]
const FastRoute = preload("res://addons/merlin_ai/fast_route.gd")
const OllamaBackendScript = preload("res://addons/merlin_ai/ollama_backend.gd")
const GroqBackendScript = preload("res://addons/merlin_ai/groq_backend.gd")
const BitNetBackendScript = preload("res://addons/merlin_ai/bitnet_backend.gd")
const BrainProcessManagerScript = preload("res://addons/merlin_ai/brain_process_manager.gd")
const BrainSwarmSchedulerScript = preload("res://addons/merlin_ai/brain_swarm_scheduler.gd")

# Backend type tracking
enum BackendType { NONE, OLLAMA, GROQ, BITNET, MERLIN_LLM }
var active_backend: int = BackendType.NONE
var _brain_process_manager: BrainProcessManager = null  # Auto-spawn manager (Phase 2)
var _swarm_scheduler: BrainSwarmScheduler = null          # Smart allocation (Phase 3)

const PROMPTS_PATH := "res://data/ai/config/prompts.json"
const PROMPT_TEMPLATES_PATH := "res://data/ai/config/prompt_templates.json"
const SCENE_PROFILES_PATH := "res://data/ai/config/scene_profiles.json"
const PERSONA_CONFIG_PATH := "res://data/ai/config/merlin_persona.json"

# ═══════════════════════════════════════════════════════════════════════════════
# BRAIN CONFIGURATION — Adaptatif selon plateforme (Qwen 3.5 heterogene)
# ═══════════════════════════════════════════════════════════════════════════════
# NANO:        0.8B all roles (ultra-low, 4 GB RAM)
# SINGLE:      2B all roles (6 GB RAM)
# SINGLE+:     4B Narrator + 2B GM, time-sharing (7 GB RAM, 4 threads)
# DUAL:        4B + 2B parallel (12 GB RAM, 6 threads)
# TRIPLE:      4B + 2B + 0.8B Worker (14 GB RAM, 8 threads)
# QUAD:        4B + 2B + 0.8B Judge + 0.8B Worker (16 GB RAM, 8 threads)

const BRAIN_SINGLE := 1   # Legacy compat
const BRAIN_DUAL := 2
const BRAIN_TRIPLE := 3
const BRAIN_QUAD := 4
const BRAIN_MAX := BRAIN_QUAD

# Profile auto-detected from BrainSwarmConfig
var _active_profile_id: int = BrainSwarmConfig.Profile.SINGLE
var _is_time_sharing: bool = false  # True for SINGLE+ (one model at a time)

var brain_count: int = 0  # Actual loaded count (set by _init_local_models)
var _target_brain_count: int = 0  # Requested count (0 = auto-detect)

var rag_manager: RAGManager

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
var narrator_params := {"temperature": 0.70, "top_p": 0.90, "max_tokens": 180, "top_k": 40, "repetition_penalty": 1.45}
# Game Master: effects JSON, balance, rules, structured output (tighter for speed)
var gamemaster_params := {"temperature": 0.15, "top_p": 0.8, "max_tokens": 80, "top_k": 15, "repetition_penalty": 1.0}

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
const LLM_POLL_TIMEOUT_MS := 25000         # 25s — warm gen ~7s, first-after-warmup ~20s
const LLM_POLL_TIMEOUT_FIRST_MS := 90000   # 90s — cold start loads 1GB model into RAM
var _first_generation_done := false

# Backward-compatible aliases (router = narrator, executor = gamemaster)
var router_params: Dictionary:
	get: return narrator_params
	set(v): narrator_params = v
var executor_params: Dictionary:
	get: return gamemaster_params
	set(v): gamemaster_params = v

# Prompt templates (loaded from prompt_templates.json)
var prompt_templates: Dictionary = {}
var _scene_profiles: Dictionary = {}
var _scene_context: Dictionary = {}

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
const SESSION_HISTORY_LIMIT := 48

# Persona config (loaded from merlin_persona.json)
var persona_config: Dictionary = {}
var _persona_forbidden_words: PackedStringArray = []
var _persona_few_shots: Array = []
const PERSONA_DRIFT_THRESHOLD := 3  # Consecutive responses without Celtic vocabulary
const SESSION_PERSIST_PATH := "user://ai/memory/llm_session_history.json"
const SESSION_PERSIST_LIMIT := 50
const STREAM_CHUNK_TOKENS := 32
const STREAM_MAX_ROUNDS := 4
var stats := {
	"last_ttft_ms": 0,
	"last_total_ms": 0,
	"avg_ttft_ms": 0.0,
	"avg_total_ms": 0.0,
	"llm_calls": 0
}

var _warmup_started := false
var _warmup_attempt_time := 0

func _ready() -> void:
	set_process(false)  # Enabled when background tasks are active
	rag_manager = RAGManager.new()
	add_child(rag_manager)
	_load_prompts()
	_load_prompt_templates()
	_load_scene_profiles()
	_load_persona_config()
	_load_brain_config()
	# Models loaded on demand via start_warmup() — not at autoload time
	load_session_history()


func _load_brain_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return  # No saved config — auto-detect will be used
	var saved: int = cfg.get_value("ai", "brain_count", 0)
	if saved > 0:
		set_brain_count(saved)
		_log("Brain config loaded from settings: %d cerveaux" % saved)


## Start LLM model loading. Call from MenuPrincipal on "Nouvelle Partie"/"Continuer".
## Emits status_changed during loading and ready_changed(true) when done.
func start_warmup() -> void:
	if is_ready:
		return
	if _warmup_started:
		# Allow retry after 30s if previous attempt failed
		if not is_ready and Time.get_ticks_msec() - _warmup_attempt_time > 30000:
			print("[MerlinAI] Previous warmup failed, retrying...")
			_warmup_started = false
		else:
			return
	_warmup_started = true
	_warmup_attempt_time = Time.get_ticks_msec()
	_init_local_models()


func _exit_tree() -> void:
	save_session_history()
	# Clean shutdown of BitNet swarm
	if _swarm_scheduler != null:
		_swarm_scheduler.clear()
		_swarm_scheduler = null
	if _brain_process_manager != null:
		_brain_process_manager.stop_all()
		_brain_process_manager = null


func cancel_current_generation() -> void:
	## Cancel any in-progress LLM generation (prefetch or otherwise).
	## Called by MOS when generate_card() needs to reclaim the LLM.
	if narrator_llm and narrator_llm.has_method("is_generating_now") and narrator_llm.is_generating_now():
		print("[MerlinAI] cancel_current_generation: narrator LLM busy, cancelling")
		if narrator_llm.has_method("cancel_generation"):
			narrator_llm.cancel_generation()

func is_llm_busy() -> bool:
	## Check if the LLM is currently generating.
	if narrator_llm and narrator_llm.has_method("is_generating_now"):
		return narrator_llm.is_generating_now()
	return false

## Swap Ollama model for time-sharing mode (SINGLE+).
## Changes the model tag and context size on the shared LLM instance.
func _swap_model_for_role(llm: Object, role: String) -> void:
	if not _is_time_sharing or not (llm is OllamaBackend):
		return
	var brain_cfg: Dictionary = BrainSwarmConfig.get_brain_config(_active_profile_id, role)
	if brain_cfg.is_empty():
		return
	var target_tag: String = str(brain_cfg.get("ollama_tag", ""))
	var target_ctx: int = int(brain_cfg.get("n_ctx", 4096))
	var target_thinking: bool = bool(brain_cfg.get("thinking", false))
	if target_tag != "" and llm.model != target_tag:
		_log("Time-sharing: swapping model %s -> %s" % [llm.model, target_tag])
		llm.model = target_tag
		llm.set_context_size(target_ctx)
		llm.thinking_mode = target_thinking


func _run_llm(llm: Object, prompt: String, params: Dictionary) -> Dictionary:
	if llm == null:
		return {"error": "LLM manquant"}
	if not llm.has_method("generate_async") or not llm.has_method("poll_result"):
		return {"error": "LLM interface incomplete (missing generate_async/poll_result)"}

	# Time-sharing: swap model based on role hint in params
	var role_hint: String = str(params.get("_brain_role", ""))
	if role_hint != "":
		_swap_model_for_role(llm, role_hint)

	# Pre-flight: if LLM is stuck generating from a previous call, wait or cancel
	if llm.has_method("is_generating_now") and llm.is_generating_now():
		print("[MerlinAI] WARNING: LLM already generating, waiting up to 5s...")
		var wait_start := Time.get_ticks_msec()
		while llm.is_generating_now() and (Time.get_ticks_msec() - wait_start) < 5000:
			llm.poll_result()
			await get_tree().process_frame
		if llm.is_generating_now():
			print("[MerlinAI] LLM stuck — calling cancel_generation()")
			if llm.has_method("cancel_generation"):
				llm.cancel_generation()
			await get_tree().create_timer(0.1).timeout

	var start_time := Time.get_ticks_msec()
	var ttft := 0
	var first_token_received := false
	if llm.has_method("set_sampling_params"):
		llm.set_sampling_params(float(params.temperature), float(params.top_p), int(params.max_tokens))
	if llm.has_method("set_advanced_sampling"):
		var top_k := int(params.get("top_k", 40))
		var rep_penalty := float(params.get("repetition_penalty", 1.3))
		llm.set_advanced_sampling(top_k, rep_penalty)

	var state := {"done": false, "result": {}}
	print("[MerlinAI] LLM generate_async: prompt=%d chars, max_tokens=%d" % [prompt.length(), int(params.max_tokens)])

	llm.generate_async(prompt, func(res: Dictionary) -> void:
		if not first_token_received:
			ttft = Time.get_ticks_msec() - start_time
			first_token_received = true
		state.result = res
		state.done = true
	)

	# Determine timeout (more generous for first/cold start generation)
	var timeout_ms: int = LLM_POLL_TIMEOUT_FIRST_MS if not _first_generation_done else LLM_POLL_TIMEOUT_MS

	# Adaptive polling with timeout and progress logging
	var poll_count := 0
	var last_progress_log := start_time
	while not state.done:
		llm.poll_result()
		if state.done:
			break

		var elapsed := Time.get_ticks_msec() - start_time

		# Timeout check
		if elapsed > timeout_ms:
			print("[MerlinAI] ERROR: LLM poll timeout after %dms (limit=%dms, polls=%d)" % [elapsed, timeout_ms, poll_count])
			if llm.has_method("cancel_generation"):
				llm.cancel_generation()
				print("[MerlinAI]   Cancelled stuck generation")
			return {"error": "LLM timeout (%dms)" % elapsed}

		# Progress logging every 10s
		if elapsed - (last_progress_log - start_time) > 10000:
			var still_gen: bool = llm.is_generating_now() if llm.has_method("is_generating_now") else false
			print("[MerlinAI] LLM polling: %dms elapsed, polls=%d, is_generating=%s" % [elapsed, poll_count, str(still_gen)])
			last_progress_log = Time.get_ticks_msec()

		poll_count += 1
		if poll_count < 10:
			await get_tree().process_frame
		else:
			await get_tree().create_timer(0.05).timeout  # 50ms backoff

	_first_generation_done = true
	var total_time := Time.get_ticks_msec() - start_time
	stats.last_ttft_ms = ttft
	stats.last_total_ms = total_time
	stats.llm_calls += 1
	stats.avg_ttft_ms = (stats.avg_ttft_ms * (stats.llm_calls - 1) + ttft) / float(stats.llm_calls)
	stats.avg_total_ms = (stats.avg_total_ms * (stats.llm_calls - 1) + total_time) / float(stats.llm_calls)
	print("[MerlinAI] LLM done: TTFT=%dms Total=%dms polls=%d" % [ttft, total_time, poll_count])

	if state.result.is_empty():
		print("[MerlinAI] WARNING: LLM returned empty result after %dms" % total_time)
		return {"error": "LLM returned empty result"}

	return state.result

func _load_prompts() -> void:
	if FileAccess.file_exists(PROMPTS_PATH):
		var file = FileAccess.open(PROMPTS_PATH, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(data) == TYPE_DICTIONARY:
			prompts = data

func _load_persona_config() -> void:
	if not FileAccess.file_exists(PERSONA_CONFIG_PATH):
		_log("Persona config not found: %s" % PERSONA_CONFIG_PATH)
		return
	var file := FileAccess.open(PERSONA_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		persona_config = data
		_persona_few_shots = data.get("few_shot", [])
		var forbidden: Array = data.get("forbidden_words", [])
		_persona_forbidden_words.clear()
		for word in forbidden:
			_persona_forbidden_words.append(str(word).to_lower())
		_log("Persona config loaded: %d few-shots, %d forbidden words" % [_persona_few_shots.size(), _persona_forbidden_words.size()])


## Build ChatML few-shot block from persona config (2-3 random examples)
func _build_few_shot_chatml() -> String:
	if _persona_few_shots.is_empty():
		return ""
	var count: int = mini(3, _persona_few_shots.size())
	var indices: Array = range(_persona_few_shots.size())
	indices.shuffle()
	var selected: Array = indices.slice(0, count)
	var parts: PackedStringArray = []
	for idx in selected:
		var fs: Dictionary = _persona_few_shots[idx]
		var user_text: String = str(fs.get("user", ""))
		var assistant_text: String = str(fs.get("assistant", ""))
		if user_text != "" and assistant_text != "":
			parts.append("<|im_start|>user\n%s<|im_end|>" % user_text)
			parts.append("<|im_start|>assistant\n%s<|im_end|>" % assistant_text)
	return "\n".join(parts)


## Check persona compliance of a response (forbidden words, English, length)
func check_persona_compliance(response: String) -> Dictionary:
	var violations: PackedStringArray = []
	var response_lower := response.to_lower()
	for word in _persona_forbidden_words:
		if response_lower.find(word) != -1:
			violations.append("Mot interdit: '%s'" % word)
	var english_markers := [" the ", " is ", " are ", " you ", " i am ", " hello ", " please ", " thank "]
	for marker in english_markers:
		if response_lower.find(marker) != -1:
			violations.append("Anglais detecte: '%s'" % marker.strip_edges())
	if response.length() > 500:
		violations.append("Trop long: %d chars" % response.length())
	var score: float = maxf(0.0, 1.0 - violations.size() * 0.25)
	return {"valid": violations.is_empty(), "violations": violations, "score": score}


func _load_scene_profiles() -> void:
	_scene_profiles.clear()
	if not FileAccess.file_exists(SCENE_PROFILES_PATH):
		return
	var file := FileAccess.open(SCENE_PROFILES_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_scene_profiles = parsed
		_log("Scene profiles loaded: %d" % _scene_profiles.size())

func set_scene_context(scene_id: String, overrides: Dictionary = {}) -> void:
	var normalized_id := scene_id.strip_edges()
	if normalized_id == "":
		clear_scene_context()
		return
	var merged: Dictionary = {}
	if _scene_profiles.has("default") and _scene_profiles["default"] is Dictionary:
		merged = _scene_profiles["default"].duplicate(true)
	if _scene_profiles.has(normalized_id) and _scene_profiles[normalized_id] is Dictionary:
		merged = _deep_merge_dict(merged, _scene_profiles[normalized_id])
	if not overrides.is_empty():
		merged = _deep_merge_dict(merged, overrides)
	merged["scene_id"] = normalized_id
	_scene_context = merged
	if rag_manager and rag_manager.has_method("set_scene_context"):
		rag_manager.set_scene_context(_scene_context)
	_log("Scene context active: %s" % normalized_id)

func clear_scene_context() -> void:
	_scene_context.clear()
	if rag_manager and rag_manager.has_method("clear_scene_context"):
		rag_manager.clear_scene_context()

func get_scene_context() -> Dictionary:
	return _scene_context.duplicate(true)

func _deep_merge_dict(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var merged: Dictionary = base.duplicate(true)
	for key in overlay.keys():
		var value = overlay[key]
		if merged.has(key) and merged[key] is Dictionary and value is Dictionary:
			merged[key] = _deep_merge_dict(merged[key], value)
		else:
			merged[key] = value
	return merged

func _resolve_scene_context(channel: String) -> Dictionary:
	if _scene_context.is_empty():
		return {}
	var resolved: Dictionary = _scene_context.duplicate(true)
	var channels = _scene_context.get("channels", {})
	if channels is Dictionary and channels.has(channel) and channels[channel] is Dictionary:
		resolved = _deep_merge_dict(resolved, channels[channel])
	return resolved

func _to_string_list(value) -> PackedStringArray:
	var out: PackedStringArray = []
	if value is PackedStringArray:
		return value
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if text != "":
				out.append(text)
	return out

func _build_scene_contract_lines(channel: String) -> PackedStringArray:
	var context := _resolve_scene_context(channel)
	var lines: PackedStringArray = []
	if context.is_empty():
		return lines
	var scene_id := str(context.get("scene_id", ""))
	if scene_id != "":
		lines.append("Scene active: %s" % scene_id)
	var phase := str(context.get("phase", ""))
	if phase != "":
		lines.append("Phase: %s" % phase)
	var intent := str(context.get("intent", ""))
	if intent != "":
		lines.append("Objectif narratif: %s" % intent)
	var tone_target := str(context.get("tone_target", ""))
	if tone_target != "":
		lines.append("Ton cible: %s" % tone_target)
	var allowed := _to_string_list(context.get("allowed_topics", []))
	if not allowed.is_empty():
		lines.append("Sujets autorises: %s" % ", ".join(allowed))
	var forbidden := _to_string_list(context.get("forbidden_topics", []))
	if not forbidden.is_empty():
		lines.append("Sujets interdits: %s" % ", ".join(forbidden))
	var must_ref := _to_string_list(context.get("must_reference", []))
	if not must_ref.is_empty():
		lines.append("References obligatoires: %s" % ", ".join(must_ref))
	var guardrails := _to_string_list(context.get("response_guardrails", []))
	if not guardrails.is_empty():
		lines.append("Garde-fous: %s" % " | ".join(guardrails))
	var limits := context.get("response_limits", {})
	if limits is Dictionary and not limits.is_empty():
		var max_sentences: int = int(limits.get("max_sentences", 0))
		if max_sentences > 0:
			lines.append("Limite: %d phrases maximum." % max_sentences)
		var max_words: int = int(limits.get("max_words", 0))
		if max_words > 0:
			lines.append("Limite: %d mots maximum." % max_words)
		var style := str(limits.get("style", ""))
		if style != "":
			lines.append("Style attendu: %s" % style)
	return lines

func _augment_system_prompt_with_scene(system_prompt: String, channel: String, params_override: Dictionary = {}) -> String:
	if bool(params_override.get("skip_scene_contract", false)):
		return system_prompt
	var lines := _build_scene_contract_lines(channel)
	if lines.is_empty():
		return system_prompt
	var contract := "[CONTRAT_SCENE]\n%s\nRespecte strictement ce contrat. Si la demande sort du cadre, recentre-toi sur la scene active." % "\n".join(lines)
	if system_prompt.strip_edges() == "":
		return contract
	return system_prompt.strip_edges() + "\n\n" + contract

func _init_local_models() -> void:
	print("[MerlinAI] _init_local_models() starting...")
	_set_status("Connexion: ...", "Preparation des modeles", 5.0)

	# Determine how many brains to load
	var target: int = _target_brain_count if _target_brain_count > 0 else _detect_optimal_brains()
	target = clampi(target, BRAIN_SINGLE, BRAIN_MAX)
	_log("Target brains: %d" % target)

	# ── Strategy 1: Try Ollama backend (skip in web — CORS blocked) ──────────
	if not OS.has_feature("web"):
		if await _try_init_ollama(target):
			return

	# ── Strategy 2: Try Groq cloud API (primary for web export) ─────────
	if await _try_init_groq():
		return

	# ── Strategy 3: Try BitNet swarm (llama-server.exe instances) ─────────
	if await _try_init_bitnet(target):
		return

	# ── Strategy 4: Fallback to MerlinLLM (C++ GDExtension) ───────────────
	await _try_init_merlin_llm(target)


func _try_init_ollama(target: int) -> bool:
	_set_status("Connexion: ...", "Detection Ollama...", 10.0)
	var ollama_test := OllamaBackendScript.new()
	if not ollama_test.check_available():
		_log("Ollama: non disponible (ollama serve non lance?)")
		return false

	# ── Profile selection: respect target if user-set, else auto-detect HW ─
	var available_ram := _estimate_available_ram_mb()
	var cpu_threads := OS.get_processor_count()
	if target > 0:
		# User-driven via settings.cfg [ai] brain_count — overrides HW autodetect
		match target:
			1: _active_profile_id = BrainSwarmConfig.Profile.SINGLE
			2: _active_profile_id = BrainSwarmConfig.Profile.DUAL
			3: _active_profile_id = BrainSwarmConfig.Profile.TRIPLE
			4: _active_profile_id = BrainSwarmConfig.Profile.QUAD
			_: _active_profile_id = BrainSwarmConfig.Profile.SINGLE
	else:
		_active_profile_id = BrainSwarmConfig.detect_profile(available_ram, cpu_threads)
	_is_time_sharing = BrainSwarmConfig.is_time_sharing(_active_profile_id)
	var profile: Dictionary = BrainSwarmConfig.get_profile(_active_profile_id)
	var profile_name: String = str(profile.get("name", "Unknown"))
	_log("Ollama: detected profile '%s' (RAM: %d MB, CPU: %d threads)" % [profile_name, available_ram, cpu_threads])

	# ── Verify required models are available ──────────────────────────────
	var required_models: Array = BrainSwarmConfig.get_required_models(_active_profile_id)
	for model_tag in required_models:
		ollama_test.model = model_tag
		if not ollama_test.check_model_available():
			_log("Ollama: modele '%s' non trouve — run: ollama pull %s" % [model_tag, model_tag])
			# Fallback: try smaller profile
			if _active_profile_id > BrainSwarmConfig.Profile.NANO:
				_active_profile_id = BrainSwarmConfig.Profile.SINGLE
				_is_time_sharing = false
				_log("Ollama: fallback to SINGLE profile")
				required_models = BrainSwarmConfig.get_required_models(_active_profile_id)
				var fallback_ok := true
				for ft in required_models:
					ollama_test.model = ft
					if not ollama_test.check_model_available():
						fallback_ok = false
						break
				if not fallback_ok:
					_log("Ollama: aucun modele disponible")
					return false
			else:
				return false
	_log("Ollama: tous les modeles requis sont disponibles")

	brain_count = 0

	# ── Brain 1: Narrator via Ollama ──────────────────────────────────────
	var narrator_cfg: Dictionary = BrainSwarmConfig.get_brain_config(_active_profile_id, "narrator")
	var narrator_tag: String = str(narrator_cfg.get("ollama_tag", OllamaBackendScript.DEFAULT_MODEL))
	var narrator_ctx: int = int(narrator_cfg.get("n_ctx", 4096))
	_set_status("Connexion: ...", "Ollama Brain 1/Narrator (%s)" % narrator_tag, 30.0)
	narrator_llm = OllamaBackendScript.new()
	narrator_llm.model = narrator_tag
	narrator_llm.set_context_size(narrator_ctx)
	brain_count = 1
	gamemaster_llm = narrator_llm  # Default: shared (NANO/SINGLE)
	_log("Brain 1 (Narrator) -> Ollama %s (ctx=%d)" % [narrator_tag, narrator_ctx])

	# ── Brain 2: Game Master via Ollama (separate model if SINGLE+/DUAL+) ─
	var gm_cfg: Dictionary = BrainSwarmConfig.get_brain_config(_active_profile_id, "gamemaster")
	if not gm_cfg.is_empty():
		var gm_tag: String = str(gm_cfg.get("ollama_tag", narrator_tag))
		var gm_ctx: int = int(gm_cfg.get("n_ctx", 4096))
		var gm_thinking: bool = bool(gm_cfg.get("thinking", false))
		_set_status("Connexion: ...", "Ollama Brain 2/GM (%s)" % gm_tag, 50.0)

		if _is_time_sharing:
			# SINGLE+ mode: reuse same OllamaBackend instance, swap model per call
			# GM uses the same instance but we store the config for runtime swap
			gamemaster_llm = narrator_llm  # Same instance, model swapped at generation time
			_log("Brain 2 (GM) -> time-sharing, will swap to %s (thinking=%s)" % [gm_tag, str(gm_thinking)])
		else:
			# DUAL+ mode: separate instance for parallel generation
			gamemaster_llm = OllamaBackendScript.new()
			gamemaster_llm.model = gm_tag
			gamemaster_llm.set_context_size(gm_ctx)
			gamemaster_llm.thinking_mode = gm_thinking
			_log("Brain 2 (GM) -> Ollama %s (ctx=%d, thinking=%s)" % [gm_tag, gm_ctx, str(gm_thinking)])
		brain_count = 2

	active_backend = BackendType.OLLAMA
	var mode_name := _get_brain_mode_name()

	# Warmup: primes Ollama model (loads into RAM if cold)
	_set_status("Connexion: ...", "Warmup Ollama (chargement modele %s)" % narrator_tag, 90.0)
	_log("Starting warmup generation (Ollama, %s)..." % narrator_tag)
	await _warmup_generate()

	var ram_peak: int = BrainSwarmConfig.get_peak_ram_mb(_active_profile_id)
	var ts_label := " [time-sharing]" if _is_time_sharing else ""
	_set_status("Connexion: OK", "Ollama %s (%d cerveaux, ~%d MB)%s" % [mode_name, brain_count, ram_peak, ts_label], 100.0)
	is_ready = true
	ready_changed.emit(true)
	_log("Backend: Ollama | %d brains | %s | ~%d MB RAM%s" % [brain_count, mode_name, ram_peak, ts_label])
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# BITNET SWARM — Multiple llama-server.exe instances on different ports
# ═══════════════════════════════════════════════════════════════════════════════
# Port map:
#   8081 = Brain 1 (Narrator, typically Falcon3-7B-1.58bit)
#   8082 = Brain 2 (Game Master, typically BitNet-2B4T)
#   8083 = Brain 3 (Worker, typically BitNet-2B4T)
#   8084 = Brain 4 (Worker, typically BitNet-2B4T)
# Mode 1: Servers pre-launched externally (tools/start_bitnet_brains.ps1)
# Mode 2: Auto-spawn via BrainProcessManager (if llama-server.exe found on disk)

const BITNET_BASE_PORT := 8081
const BITNET_MAX_BRAINS := 4
const BITNET_BRAIN_ROLES := ["narrator", "gamemaster", "worker", "worker"]

# Auto-spawn paths (searched in order)
const BITNET_SERVER_CANDIDATES := [
	"C:/Users/PGNK2128/BitNet/build/bin/llama-server.exe",  # Dev machine
	"res://bin/llama-server.exe",  # Bundled with game (future)
]
const BITNET_MODEL_CANDIDATES := {
	"narrator": [
		"C:/Users/PGNK2128/BitNet/models/Falcon3-7B-Instruct-1.58bit/ggml-model-i2_s.gguf",
		"C:/Users/PGNK2128/BitNet/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf",
	],
	"gamemaster": [
		"C:/Users/PGNK2128/BitNet/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf",
	],
	"worker": [
		"C:/Users/PGNK2128/BitNet/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf",
	],
}
# ═══════════════════════════════════════════════════════════════════════════════
# GROQ CLOUD — Fallback when no local LLM available (web export)
# ═══════════════════════════════════════════════════════════════════════════════

func _try_init_groq() -> bool:
	_set_status("Connexion: ...", "Detection Groq Cloud API...", 10.0)
	var groq_narrator := GroqBackendScript.new("narrator")
	if not groq_narrator.check_available():
		_log("Groq: pas de cle API (GROQ_API_KEY ou ProjectSettings merlin/groq_api_key)")
		return false

	_log("Groq: API key trouvee, initialisation cloud LLM...")

	# Narrator: llama-3.3-70b-versatile
	narrator_llm = groq_narrator
	narrator_llm.set_sampling_params(0.8, 0.9, 512)
	brain_count = 1

	# GM: llama-3.1-8b-instant (fast, structured output)
	var groq_gm := GroqBackendScript.new("gm")
	groq_gm.set_sampling_params(0.6, 0.85, 256)
	gamemaster_llm = groq_gm
	brain_count = 2

	active_backend = BackendType.GROQ
	_set_status("Connexion: OK", "Groq Cloud (Narrator 70b + GM 8b)", 100.0)
	is_ready = true
	ready_changed.emit(true)
	_log("Backend: Groq Cloud | 2 brains | Narrator=llama-3.3-70b | GM=llama-3.1-8b")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# BITNET SWARM — Multiple llama-server.exe instances on different ports
# ═══════════════════════════════════════════════════════════════════════════════

# Thread and context budget per role
const BITNET_BRAIN_PARAMS := {
	"narrator":    {"threads": 3, "n_ctx": 1024},
	"gamemaster":  {"threads": 2, "n_ctx": 512},
	"worker":      {"threads": 2, "n_ctx": 512},
}

func _try_init_bitnet(target: int) -> bool:
	_set_status("Connexion: ...", "Detection BitNet swarm...", 10.0)

	# ── Mode 1: Check if servers are already running ──────────────────────
	var probe := BitNetBackendScript.new()
	probe.port = BITNET_BASE_PORT
	if probe.check_available():
		_log("BitNet: llama-server detecte sur port %d (mode manuel)" % BITNET_BASE_PORT)
		return await _init_bitnet_from_running_servers(target)

	# ── Mode 2: Auto-spawn via BrainProcessManager ───────────────────────
	_log("BitNet: aucun serveur sur port %d, tentative auto-spawn..." % BITNET_BASE_PORT)
	return await _init_bitnet_auto_spawn(target)


## Mode 1: Connect to pre-launched llama-server instances (manual/debug).
func _init_bitnet_from_running_servers(target: int) -> bool:
	brain_count = 0

	# Brain 1: Narrator
	_set_status("Connexion: ...", "BitNet Brain 1/Narrator (port %d)" % BITNET_BASE_PORT, 30.0)
	narrator_llm = BitNetBackendScript.new()
	narrator_llm.port = BITNET_BASE_PORT
	narrator_llm.brain_role = "narrator"
	narrator_llm.set_sampling_params(narrator_params.temperature, narrator_params.top_p, narrator_params.max_tokens)
	narrator_llm.set_advanced_sampling(narrator_params.top_k, narrator_params.repetition_penalty)
	brain_count = 1
	gamemaster_llm = narrator_llm
	_log("Brain 1 (Narrator) -> BitNet port %d" % BITNET_BASE_PORT)

	# Brain 2+: Probe additional ports
	var max_probe: int = mini(target, BITNET_MAX_BRAINS)
	for i in range(1, max_probe):
		var port: int = BITNET_BASE_PORT + i
		var role: String = BITNET_BRAIN_ROLES[i] if i < BITNET_BRAIN_ROLES.size() else "worker"
		_set_status("Connexion: ...", "BitNet Brain %d/%s (port %d)" % [i + 1, role, port], 30.0 + i * 15.0)

		var brain := BitNetBackendScript.new()
		brain.port = port
		brain.brain_role = role
		if not brain.check_available():
			_log("BitNet Brain %d: port %d non disponible — arret scan" % [i + 1, port])
			break
		_assign_bitnet_brain(brain, role, i + 1, port)
		brain_count += 1

	return await _finalize_bitnet_init()


## Mode 2: Auto-spawn llama-server.exe processes, then connect.
func _init_bitnet_auto_spawn(target: int) -> bool:
	# Find llama-server.exe
	var server_path := _find_bitnet_server()
	if server_path == "":
		_log("BitNet: llama-server.exe introuvable")
		return false

	# Build brain definitions
	var brain_defs: Array = []
	var max_brains: int = mini(target, BITNET_MAX_BRAINS)
	for i in range(max_brains):
		var role: String = BITNET_BRAIN_ROLES[i] if i < BITNET_BRAIN_ROLES.size() else "worker"
		var model_path := _find_bitnet_model(role)
		if model_path == "":
			_log("BitNet: modele introuvable pour role '%s' — arret a %d brains" % [role, i])
			break
		var params: Dictionary = BITNET_BRAIN_PARAMS.get(role, {"threads": 2, "n_ctx": 512})
		brain_defs.append({
			"role": role,
			"model": model_path,
			"threads": params.threads,
			"n_ctx": params.n_ctx,
		})

	if brain_defs.is_empty():
		_log("BitNet: aucune config de brain valide")
		return false

	# Spawn processes
	_set_status("Connexion: ...", "BitNet auto-spawn (%d brains)..." % brain_defs.size(), 20.0)
	_brain_process_manager = BrainProcessManagerScript.new()
	_brain_process_manager.configure(server_path, brain_defs)
	var started: int = _brain_process_manager.start_all()
	if started == 0:
		_log("BitNet: echec spawn — aucun process demarre")
		_brain_process_manager = null
		return false
	_log("BitNet: %d/%d process demarres, attente health..." % [started, brain_defs.size()])

	# Wait for health
	_set_status("Connexion: ...", "BitNet: chargement modeles...", 40.0)
	var healthy: int = _brain_process_manager.wait_for_healthy()
	if healthy == 0:
		_log("BitNet: aucun brain healthy apres timeout — arret")
		_brain_process_manager.stop_all()
		_brain_process_manager = null
		return false
	_log("BitNet: %d brains healthy" % healthy)

	# Create backends from healthy brains
	brain_count = 0
	for i in range(brain_defs.size()):
		var info: Array = _brain_process_manager.get_brain_info()
		if i >= info.size() or not info[i].get("running", false):
			continue
		var backend: Object = _brain_process_manager.create_backend(i)
		if backend == null:
			continue
		var role: String = brain_defs[i].role
		var port: int = BrainProcessManagerScript.BASE_PORT + i
		if brain_count == 0:
			# First healthy brain = Narrator
			narrator_llm = backend
			narrator_llm.set_sampling_params(narrator_params.temperature, narrator_params.top_p, narrator_params.max_tokens)
			narrator_llm.set_advanced_sampling(narrator_params.top_k, narrator_params.repetition_penalty)
			gamemaster_llm = narrator_llm
			brain_count = 1
			_log("Brain 1 (Narrator) -> BitNet auto port %d" % port)
		else:
			_assign_bitnet_brain(backend, role, brain_count + 1, port)
			brain_count += 1

	if brain_count == 0:
		_brain_process_manager.stop_all()
		_brain_process_manager = null
		return false

	return await _finalize_bitnet_init()


## Assign a brain backend to its role (shared by Mode 1 and Mode 2).
func _assign_bitnet_brain(brain: Object, role: String, brain_num: int, port: int) -> void:
	if role == "gamemaster":
		gamemaster_llm = brain
		brain.set_sampling_params(gamemaster_params.temperature, gamemaster_params.top_p, gamemaster_params.max_tokens)
		brain.set_advanced_sampling(gamemaster_params.top_k, gamemaster_params.repetition_penalty)
		_log("Brain %d (Game Master) -> BitNet port %d" % [brain_num, port])
	else:
		_pool_workers.append(brain)
		_pool_busy.append(false)
		brain.set_sampling_params(gamemaster_params.temperature, gamemaster_params.top_p, gamemaster_params.max_tokens)
		brain.set_advanced_sampling(gamemaster_params.top_k, gamemaster_params.repetition_penalty)
		_log("Brain %d (Worker) -> BitNet port %d" % [brain_num, port])


## Finalize BitNet init: warmup + status update.
func _finalize_bitnet_init() -> bool:
	active_backend = BackendType.BITNET
	var mode_name := _get_brain_mode_name()
	var spawn_mode := "auto-spawn" if _brain_process_manager != null else "manuel"

	# ── Initialize swarm scheduler (Phase 3) ──────────────────────────────
	_swarm_scheduler = BrainSwarmSchedulerScript.new()
	# Register narrator (always present)
	var narrator_size := _detect_model_size(narrator_llm)
	_swarm_scheduler.register_brain(narrator_llm, "narrator", narrator_size)
	# Register gamemaster (if distinct)
	if gamemaster_llm != narrator_llm:
		var gm_size := _detect_model_size(gamemaster_llm)
		_swarm_scheduler.register_brain(gamemaster_llm, "gamemaster", gm_size)
	# Register pool workers
	for worker in _pool_workers:
		var w_size := _detect_model_size(worker)
		_swarm_scheduler.register_brain(worker, "worker", w_size)
	_log("Scheduler initialized: %d brains, tier=%s" % [_swarm_scheduler.get_total_count(), _swarm_scheduler.get_tier_name()])

	_set_status("Connexion: ...", "Warmup BitNet (Narrator)", 90.0)
	_log("Starting warmup generation (BitNet %s)..." % spawn_mode)
	await _warmup_generate()

	_set_status("Connexion: OK", "BitNet %s (%d cerveaux, %s)" % [mode_name, brain_count, spawn_mode], 100.0)
	is_ready = true
	ready_changed.emit(true)
	_log("Backend: BitNet swarm | %d brains | %s | %s" % [brain_count, mode_name, spawn_mode])
	return true


## Detect model size from backend for scheduler timeout calibration.
func _detect_model_size(llm: Object) -> String:
	if llm is BitNetBackendScript:
		# Port 8081 = typically Falcon3-7B (large), others = BitNet-2B4T (small)
		if llm.port == BITNET_BASE_PORT:
			return "large"  # Narrator brain, potentially Falcon3-7B
	return "small"


func _find_bitnet_server() -> String:
	for candidate in BITNET_SERVER_CANDIDATES:
		var path: String = candidate
		if path.begins_with("res://"):
			path = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			_log("BitNet: llama-server found at %s" % path)
			return path
	return ""


func _find_bitnet_model(role: String) -> String:
	var candidates: Array = BITNET_MODEL_CANDIDATES.get(role, [])
	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


func _try_init_merlin_llm(target: int) -> void:
	if not ClassDB.class_exists("MerlinLLM"):
		_set_status("Connexion: OFF", "Ni Ollama ni MerlinLLM disponibles", 0.0)
		_log("MerlinLLM: classe absente (GDExtension non chargee)")
		ready_changed.emit(false)
		return
	model_file_used = _resolve_model_file(MODEL_CANDIDATES)
	if model_file_used == "":
		_set_status("Connexion: OFF", "Modele GGUF manquant", 0.0)
		ready_changed.emit(false)
		return

	var model_path := _to_fs_path(model_file_used)
	brain_count = 0

	# ── Brain 1: Narrator (always loaded) ──────────────────────────────────
	_set_status("Connexion: ...", "Chargement Brain 1/Narrator (C++)", 10.0)
	narrator_llm = ClassDB.instantiate("MerlinLLM")
	var narrator_err = narrator_llm.load_model(model_path)
	if narrator_err != OK:
		_log("Brain 1 (Narrator) load err: " + str(narrator_err))
		_set_status("Connexion: OFF", "Erreur chargement Brain 1", 0.0)
		ready_changed.emit(false)
		return
	brain_count = 1
	gamemaster_llm = narrator_llm
	_log("Brain 1 (Narrator) -> MerlinLLM")
	_load_narrator_lora()

	# ── Brain 2: disabled for MerlinLLM (NobodyWho segfault) ──────────────
	# Multi-brain MerlinLLM disabled due to GDExtension instability.
	# Use Ollama for multi-brain support.
	if target >= BRAIN_DUAL:
		_log("Brain 2: MerlinLLM multi-instance desactive (segfault). Lancez 'ollama serve' pour multi-brain.")

	# ── Worker Pool: disabled for MerlinLLM ───────────────────────────────
	_pool_workers.clear()
	_pool_busy.clear()

	active_backend = BackendType.MERLIN_LLM
	var ram_estimate: int = brain_count * 1200  # MerlinLLM: ~1.2 GB per brain (legacy)
	var mode_name := _get_brain_mode_name()
	_set_status("Connexion: ...", "Warmup generation (CPU cache prime)", 95.0)
	_log("Starting warmup generation (MerlinLLM C++)...")
	await _warmup_generate()
	_set_status("Connexion: OK", "MerlinLLM %s (%d cerveau, ~%d MB)" % [mode_name, brain_count, ram_estimate], 100.0)
	is_ready = true
	ready_changed.emit(true)
	_log("Backend: MerlinLLM | %d brain | %s | ~%d MB RAM" % [brain_count, mode_name, ram_estimate])


func _detect_optimal_brains() -> int:
	# Legacy compat: map profile to brain count
	var available_ram := _estimate_available_ram_mb()
	var cpu_threads := OS.get_processor_count()
	var profile_id: int = BrainSwarmConfig.detect_profile(available_ram, cpu_threads)
	var profile: Dictionary = BrainSwarmConfig.get_profile(profile_id)
	var brain_list: Array = profile.get("brains", [])
	return maxi(brain_list.size(), 1)


## Estimate available RAM in MB (total system RAM minus OS/Godot overhead).
func _estimate_available_ram_mb() -> int:
	# OS.get_static_memory_usage() gives Godot process memory
	# For total system RAM, use a conservative estimate
	# Godot 4 doesn't expose total system RAM directly
	# Use a heuristic: check processor count as proxy for machine class
	var cpu_count: int = OS.get_processor_count()
	# Conservative estimates based on typical hardware
	if cpu_count >= 16:
		return 32000  # Likely 32+ GB machine
	elif cpu_count >= 8:
		return 16000  # Likely 16 GB machine
	elif cpu_count >= 6:
		return 12000  # Likely 12-16 GB machine
	elif cpu_count >= 4:
		return 8000   # Likely 8 GB machine
	return 4000       # Ultra-low-end


func _warmup_generate() -> void:
	## Short warmup generation to prime llama.cpp KV cache + CPU caches.
	## Generates ~10 tokens with a minimal prompt, then discards the result.
	if narrator_llm == null or not narrator_llm.has_method("generate_async"):
		return
	var warmup_prompt := "<|im_start|>system\nTu es Merlin.\n<|im_end|>\n<|im_start|>user\nBonjour.\n<|im_end|>\n<|im_start|>assistant\n"
	if narrator_llm.has_method("set_sampling_params"):
		narrator_llm.set_sampling_params(0.1, 0.9, 10)  # Very few tokens
	var warmup_done := {"done": false}
	var warmup_start := Time.get_ticks_msec()
	narrator_llm.generate_async(warmup_prompt, func(_res: Dictionary) -> void:
		warmup_done.done = true
	)
	# Poll until done or 60s timeout
	while not warmup_done.done:
		narrator_llm.poll_result()
		if warmup_done.done:
			break
		if Time.get_ticks_msec() - warmup_start > 60000:
			print("[MerlinAI] Warmup timeout (60s), cancelling")
			if narrator_llm.has_method("cancel_generation"):
				narrator_llm.cancel_generation()
			break
		await get_tree().create_timer(0.05).timeout
	var warmup_elapsed := Time.get_ticks_msec() - warmup_start
	print("[MerlinAI] Warmup generation completed in %dms" % warmup_elapsed)
	_first_generation_done = true  # Mark as warm — use normal timeout from now on


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
	# Use profile name if available (Qwen 3.5 architecture)
	if active_backend == BackendType.OLLAMA:
		return BrainSwarmConfig.get_profile_name(_active_profile_id)
	# Legacy fallback for BitNet/MerlinLLM
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
		print("[MerlinAI] ensure_ready: not ready, triggering warmup")
		start_warmup()

func generate_with_system(system_prompt: String, user_input: String, params_override: Dictionary = {}) -> Dictionary:
	if not is_ready:
		return {"error": "LLM non pret"}
	system_prompt = _inject_language_directive(system_prompt)
	var scoped_system_prompt := _augment_system_prompt_with_scene(system_prompt, "general", params_override)
	# Inject few-shots for narrator (non-grammar) calls to reinforce persona
	var has_grammar: bool = params_override.has("grammar") and str(params_override.get("grammar", "")) != ""
	var few_shot_block := "" if has_grammar else _build_few_shot_chatml()
	var prompt: String
	if few_shot_block != "":
		prompt = "<|im_start|>system\n%s<|im_end|>\n%s\n<|im_start|>user\n%s<|im_end|>\n<|im_start|>assistant\n" % [scoped_system_prompt, few_shot_block, user_input]
	else:
		var template = prompts.get("executor_template", "{system}\n{input}")
		prompt = template.format({"system": scoped_system_prompt, "input": user_input})
	# Use gamemaster for grammar-constrained, narrator otherwise
	var target_llm: Object = gamemaster_llm if has_grammar else narrator_llm
	var params: Dictionary = (gamemaster_params if has_grammar else narrator_params).duplicate(true)
	for key in params_override.keys():
		params[key] = params_override[key]
	params.erase("skip_scene_contract")
	var cache_key = _make_cache_key(scoped_system_prompt, user_input, params)
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
	system_prompt = _inject_language_directive(system_prompt)
	var scoped_system_prompt := _augment_system_prompt_with_scene(system_prompt, "stream", params_override)
	var template = prompts.get("executor_template", "{system}\n{input}")
	var base_prompt = template.format({"system": scoped_system_prompt, "input": user_input})
	var params_base = narrator_params.duplicate(true)
	for key in params_override.keys():
		params_base[key] = params_override[key]
	params_base.erase("skip_scene_contract")
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

## Genere en streaming natif HTTP (NDJSON token-by-token).
## on_chunk(token: String, is_done: bool) est appele pour chaque token.
## Requiert que narrator_llm soit un OllamaBackend avec generate_stream_async.
func generate_with_native_stream(system_prompt: String, user_input: String, params_override: Dictionary = {}, on_chunk: Callable = Callable()) -> Dictionary:
	if not is_ready:
		return {"error": "LLM non pret"}
	if narrator_llm == null:
		return {"error": "Narrator LLM non charge"}
	if not narrator_llm.has_method("generate_stream_async"):
		# Fallback to old looped streaming if backend doesn't support native stream.
		return await generate_with_system_stream(system_prompt, user_input, params_override, on_chunk)

	system_prompt = _inject_language_directive(system_prompt)
	var scoped_system_prompt := _augment_system_prompt_with_scene(system_prompt, "stream", params_override)
	var template: String = prompts.get("executor_template", "{system}\n{input}")
	var prompt: String = template.format({"system": scoped_system_prompt, "input": user_input})

	# Apply params to the backend.
	var params: Dictionary = narrator_params.duplicate(true)
	for key in params_override.keys():
		params[key] = params_override[key]
	if params.has("temperature"):
		narrator_llm.set_sampling_params(float(params.temperature), float(params.get("top_p", 0.9)), int(params.get("max_tokens", 256)))

	# Start streaming.
	narrator_llm.generate_stream_async(prompt)

	# Poll loop — drain chunks and forward to callback.
	var timeout_ms: int = int(params.get("timeout_ms", 60000))
	var start_time: int = Time.get_ticks_msec()
	var collected: String = ""
	var poll_count: int = 0

	while true:
		var stream_data: Dictionary = narrator_llm.poll_stream()
		var chunks: Array = stream_data.get("chunks", [])
		for token in chunks:
			collected += str(token)
			if on_chunk.is_valid():
				on_chunk.call(str(token), false)

		if stream_data.get("done", false):
			break
		if stream_data.has("error"):
			if on_chunk.is_valid():
				on_chunk.call("", true)
			return {"error": stream_data["error"], "text": collected}

		var elapsed: int = Time.get_ticks_msec() - start_time
		if elapsed > timeout_ms:
			if narrator_llm.has_method("cancel_generation"):
				narrator_llm.cancel_generation()
			if on_chunk.is_valid():
				on_chunk.call("", true)
			return {"error": "Stream timeout", "text": collected}

		poll_count += 1
		if poll_count < 10:
			await get_tree().process_frame
		else:
			await get_tree().create_timer(0.03).timeout

	if on_chunk.is_valid():
		on_chunk.call("", true)
	var final_text: String = clean_response(collected)
	return {"text": final_text}


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
	var backend_name: String = "unknown"
	match active_backend:
		BackendType.OLLAMA: backend_name = "ollama"
		BackendType.BITNET: backend_name = "bitnet"
		BackendType.MERLIN_LLM: backend_name = "merlin_llm"
	var info := {
		"model": model_file_used,
		"backend": backend_name,
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
	# Merge BitNet-specific stats if available
	if active_backend == BackendType.BITNET and narrator_llm is BitNetBackendScript:
		info["narrator_stats"] = narrator_llm.stats.duplicate()
		if gamemaster_llm != narrator_llm and gamemaster_llm is BitNetBackendScript:
			info["gamemaster_stats"] = gamemaster_llm.stats.duplicate()
	return info

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
	print("[MerlinAI] %s" % message)
	log_entries.append(line)
	if log_entries.size() > 200:
		log_entries = log_entries.slice(log_entries.size() - 200, log_entries.size())

func _resolve_model_file(candidates: Array) -> String:
	for path in candidates:
		if FileAccess.file_exists(path):
			return path
	return ""

func _inject_language_directive(prompt: String) -> String:
	## Replace {language_directive} placeholder with locale-aware LLM directive.
	if "{language_directive}" not in prompt:
		return prompt
	var locale_mgr = get_node_or_null("/root/LocaleManager")
	var directive: String = ""
	if locale_mgr and locale_mgr.has_method("get_llm_directive"):
		directive = locale_mgr.get_llm_directive()
	return prompt.replace("{language_directive}", directive)


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
	system_prompt = _inject_language_directive(system_prompt)
	var scoped_system_prompt := _augment_system_prompt_with_scene(system_prompt, "narrative", params_override)
	var template: String = prompts.get("executor_template", "{system}\n{input}")
	var prompt: String = template.format({"system": scoped_system_prompt, "input": user_input})
	var params: Dictionary = narrator_params.duplicate(true)
	for key in params_override.keys():
		params[key] = params_override[key]
	params.erase("grammar")
	params.erase("skip_scene_contract")
	params["_brain_role"] = "narrator"
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
	var scoped_system_prompt := _augment_system_prompt_with_scene(system_prompt, "structured", params_override)
	var template: String = prompts.get("executor_template", "{system}\n{input}")
	var prompt: String = template.format({"system": scoped_system_prompt, "input": user_input})
	var params: Dictionary = gamemaster_params.duplicate(true)
	for key in params_override.keys():
		params[key] = params_override[key]
	params.erase("skip_scene_contract")
	params["_brain_role"] = "gamemaster"
	# Grammar constraint: OllamaBackend.set_grammar() is a no-op (Ollama has no GBNF support).
	# JSON structure is enforced via few-shot schema examples in the system prompt instead.
	if grammar != "" and gamemaster_llm.has_method("set_grammar"):
		gamemaster_llm.set_grammar(grammar, "root")
		_log("Game Master: grammar param received — Ollama backend uses example-driven JSON constraint (no GBNF)")
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
	var scoped_narrator_system := _augment_system_prompt_with_scene(narrator_system, "narrative", narrator_overrides)
	var scoped_gm_system := _augment_system_prompt_with_scene(gm_system, "structured", gm_overrides)
	var template: String = prompts.get("executor_template", "{system}\n{input}")
	var narrator_prompt: String = template.format({"system": scoped_narrator_system, "input": narrator_input})
	var gm_prompt: String = template.format({"system": scoped_gm_system, "input": gm_input})

	var n_params: Dictionary = narrator_params.duplicate(true)
	for key in narrator_overrides.keys():
		n_params[key] = narrator_overrides[key]
	n_params.erase("grammar")
	n_params.erase("skip_scene_contract")

	var gm_params: Dictionary = gamemaster_params.duplicate(true)
	for key in gm_overrides.keys():
		gm_params[key] = gm_overrides[key]
	gm_params.erase("skip_scene_contract")

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

# ═══════════════════════════════════════════════════════════════════════════════
# SEQUENTIAL PIPELINE (P1.5) — narrator(card_full) → parse → gm(effects)
# ═══════════════════════════════════════════════════════════════════════════════

## Generate a complete card via the sequential pipeline.
## Step 1: Narrator generates scenario text + A/B/C labels in one call.
## Step 2: Parse the labels from the narrator output.
## Step 3: Game Master generates JSON effects for the 3 options.
## Returns a card dictionary: {text, options: [{label, effects}], tags, ...}
func generate_sequential(context: Dictionary) -> Dictionary:
	if not is_ready or narrator_llm == null:
		return {"error": "LLM non pret"}

	var start_time := Time.get_ticks_msec()

	# ── Step 1: Narrator generates full card (text + labels) ────────────
	var card_template: Dictionary = prompt_templates.get("sequential_card_full", {})
	if card_template.is_empty():
		return {"error": "Template sequential_card_full introuvable"}

	var system_prompt: String = str(card_template.get("system", ""))
	var user_template: String = str(card_template.get("user_template", ""))
	var narrator_max_tokens: int = int(card_template.get("max_tokens", 200))

	# Fill user template with context variables
	var user_prompt := _fill_sequential_template(user_template, context)

	_primary_narrator_busy = true
	_narrator_busy_since = Time.get_ticks_msec()

	var narrator_result: Dictionary = await generate_with_system(
		system_prompt, user_prompt,
		{"max_tokens": narrator_max_tokens, "temperature": float(context.get("temperature", 0.7))}
	)

	_primary_narrator_busy = false
	_narrator_busy_since = 0

	if narrator_result.has("error"):
		print("[MerlinAI] SEQ Step 1 (narrator): error — %s" % str(narrator_result.error))
		return {"error": "SEQ narrator failed: %s" % str(narrator_result.error)}

	var narrator_text: String = str(narrator_result.get("text", ""))
	if narrator_text.strip_edges().length() < 15:
		print("[MerlinAI] SEQ Step 1: narrator text too short (%d chars)" % narrator_text.length())
		return {"error": "SEQ narrator text too short"}

	var step1_ms := Time.get_ticks_msec() - start_time
	print("[MerlinAI] SEQ Step 1 (narrator): %d chars in %dms" % [narrator_text.length(), step1_ms])

	# ── Step 2: Parse labels from narrator output ───────────────────────
	var parsed := _parse_sequential_labels(narrator_text)
	var narrative: String = parsed.get("narrative", narrator_text)
	var labels: Array = parsed.get("labels", [])

	# Pad to 3 labels with fallbacks if narrator missed some
	var fallback_labels := [tr("FALLBACK_CAUTIOUS"), tr("FALLBACK_OBSERVE"), tr("FALLBACK_ACT")]
	while labels.size() < 3:
		labels.append(fallback_labels[labels.size()])

	print("[MerlinAI] SEQ Step 2 (parse): %d labels extracted" % parsed.get("labels", []).size())

	# ── Step 3: Game Master generates effects JSON ──────────────────────
	var effects_template: Dictionary = prompt_templates.get("sequential_gm_effects", {})
	var effects_per_option: Array = [[], [], []]

	if not effects_template.is_empty() and gamemaster_llm != null:
		var gm_system: String = str(effects_template.get("system", ""))
		var gm_user_template: String = str(effects_template.get("user_template", ""))
		var gm_max_tokens: int = int(effects_template.get("max_tokens", 120))
		var gm_temp: float = float(effects_template.get("temperature", 0.15))

		# Fill GM template
		var gm_context := context.duplicate(true)
		gm_context["scenario_text"] = narrative
		gm_context["label_a"] = labels[0]
		gm_context["label_b"] = labels[1]
		gm_context["label_c"] = labels[2]
		var gm_user := _fill_sequential_template(gm_user_template, gm_context)

		_primary_gm_busy = true
		_gm_busy_since = Time.get_ticks_msec()

		var gm_result: Dictionary = await generate_with_system(
			gm_system, gm_user,
			{"max_tokens": gm_max_tokens, "temperature": gm_temp}
		)

		_primary_gm_busy = false
		_gm_busy_since = 0

		var gm_ms := Time.get_ticks_msec() - start_time - step1_ms
		if not gm_result.has("error"):
			var gm_text: String = str(gm_result.get("text", ""))
			effects_per_option = _parse_sequential_effects(gm_text)
			print("[MerlinAI] SEQ Step 3 (GM effects): parsed in %dms" % gm_ms)
		else:
			print("[MerlinAI] SEQ Step 3 (GM effects): error — %s (using defaults)" % str(gm_result.error))
	else:
		print("[MerlinAI] SEQ Step 3: no GM template or LLM, using default effects")

	# ── Step 4: Assemble card ───────────────────────────────────────────
	var options: Array = []
	var default_effects := [
		[{"type": "HEAL_LIFE", "amount": 5}],
		[{"type": "ADD_KARMA", "amount": 3}],
		[{"type": "DAMAGE_LIFE", "amount": 3}],
	]
	for i in range(3):
		var effects: Array = effects_per_option[i] if i < effects_per_option.size() and not effects_per_option[i].is_empty() else default_effects[i]
		var opt: Dictionary = {
			"label": labels[i],
			"effects": effects,
		}
		if i == 1:
			opt["cost"] = 1  # Centre costs Souffle
		options.append(opt)

	var total_ms := Time.get_ticks_msec() - start_time
	print("[MerlinAI] SEQ pipeline complete: %dms total" % total_ms)

	return {
		"text": narrative,
		"speaker": "merlin",
		"options": options,
		"tags": ["llm_generated", "sequential_pipeline"],
		"_generated_by": "sequential_pipeline",
		"_strategy": "sequential",
		"_generation_time_ms": total_ms,
	}


## Generate a consequence text after the player's choice (P1.5 Step 4).
func generate_sequential_consequence(context: Dictionary) -> Dictionary:
	if not is_ready or narrator_llm == null:
		return {"error": "LLM non pret"}

	var cons_template: Dictionary = prompt_templates.get("sequential_consequences", {})
	if cons_template.is_empty():
		return {"error": "Template sequential_consequences introuvable"}

	var system_prompt: String = str(cons_template.get("system", ""))
	var user_template: String = str(cons_template.get("user_template", ""))
	var max_tokens: int = int(cons_template.get("max_tokens", 50))
	var temp: float = float(cons_template.get("temperature", 0.65))

	var user_prompt := _fill_sequential_template(user_template, context)

	var result: Dictionary = await generate_with_system(
		system_prompt, user_prompt,
		{"max_tokens": max_tokens, "temperature": temp}
	)

	if result.has("error"):
		return result

	return {"text": str(result.get("text", "")), "source": "sequential_consequence"}


## Fill a template string with context variables. Unresolved placeholders become empty.
func _fill_sequential_template(template: String, context: Dictionary) -> String:
	var result := template
	for key in context.keys():
		var value = context[key]
		var placeholder := "{%s}" % key
		if result.find(placeholder) != -1:
			result = result.replace(placeholder, str(value))
	# Clean remaining unresolved placeholders (optional context vars)
	var rx := RegEx.new()
	rx.compile("\\{[a-z_]+\\}")
	result = rx.sub(result, "", true)
	return result


## Parse narrator output to extract narrative text and A/B/C labels.
func _parse_sequential_labels(text: String) -> Dictionary:
	# Permissive regex: A), **A)**, A:, Action A:, - **B**:, 1), etc.
	var rx := RegEx.new()
	rx.compile("(?m)^\\s*(?:[-*]\\s*)?\\*{0,2}(?:(?:Action\\s+)?[A-C][):.\\]]|[1-3][.)])\\*{0,2}[:\\s]+(.+)")
	var matches := rx.search_all(text)

	var labels: Array = []
	for m in matches:
		var label := m.get_string(1).strip_edges().replace("**", "").replace("*", "")
		# Strip sequel hooks (e.g. " -> consequence")
		var arrow_pos := label.find(" -> ")
		if arrow_pos > 0:
			label = label.substr(0, arrow_pos).strip_edges()
		if label.length() > 2 and label.length() < 120:
			labels.append(label)

	# Extract narrative = everything before first choice
	var rx2 := RegEx.new()
	rx2.compile("(?m)^\\s*(?:[-*]\\s*)?\\*{0,2}(?:(?:Action\\s+)?[A-C][):.\\]]|[1-3][.)])\\*{0,2}[:\\s]+")
	var first_choice := rx2.search(text)
	var narrative := text.strip_edges()
	if first_choice:
		narrative = text.substr(0, first_choice.get_start()).strip_edges()
	narrative = narrative.replace("**", "").replace("*", "")

	return {"narrative": narrative, "labels": labels}


## Parse GM effects JSON: [[effets_A], [effets_B], [effets_C]]
func _parse_sequential_effects(text: String) -> Array:
	var default_effects: Array = [[], [], []]

	# Try to find JSON array in the text
	var json_start := text.find("[")
	var json_end := text.rfind("]")
	if json_start == -1 or json_end <= json_start:
		print("[MerlinAI] SEQ effects parse: no JSON array found")
		return default_effects

	var json_text := text.substr(json_start, json_end - json_start + 1)
	var parsed = JSON.parse_string(json_text)

	if not parsed is Array or parsed.size() < 3:
		print("[MerlinAI] SEQ effects parse: invalid structure (expected array of 3)")
		return default_effects

	var result: Array = [[], [], []]
	for i in range(3):
		if i >= parsed.size():
			break
		var option_effects = parsed[i]
		if not option_effects is Array:
			continue
		for eff in option_effects:
			if not eff is Dictionary:
				continue
			var effect_type: String = str(eff.get("type", ""))
			if effect_type.is_empty():
				continue
			var normalized: Dictionary = {"type": effect_type}
			# Copy known fields
			if eff.has("aspect"):
				normalized["aspect"] = str(eff.aspect)
			if eff.has("direction"):
				normalized["direction"] = str(eff.direction)
			if eff.has("amount"):
				normalized["amount"] = int(eff.amount)
			result[i].append(normalized)

	return result


## Generate a card using the worker pool (await-based).
## Uses pool worker if available, else falls back to idle primary brain.
func generate_prefetch(system_prompt: String, user_input: String, params_override: Dictionary = {}) -> Dictionary:
	if not is_ready:
		return {"error": "LLM non pret"}
	var target_llm: Object = _lease_bg_brain()
	if target_llm == null:
		return {"error": "Tous les cerveaux occupes"}
	var scoped_system_prompt := _augment_system_prompt_with_scene(system_prompt, "prefetch", params_override)
	var template: String = prompts.get("executor_template", "{system}\n{input}")
	var prompt: String = template.format({"system": scoped_system_prompt, "input": user_input})
	var params: Dictionary = narrator_params.duplicate(true)
	for key in params_override.keys():
		params[key] = params_override[key]
	params.erase("grammar")
	params.erase("skip_scene_contract")
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
	var scoped_system_prompt := _augment_system_prompt_with_scene(system_prompt, "voice", params_override)
	var template: String = prompts.get("executor_template", "{system}\n{input}")
	var prompt: String = template.format({"system": scoped_system_prompt, "input": user_input})
	var params: Dictionary = narrator_params.duplicate(true)
	params["max_tokens"] = 64
	params["temperature"] = 0.6
	for key in params_override.keys():
		params[key] = params_override[key]
	params.erase("grammar")
	params.erase("skip_scene_contract")
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
	# ── Scheduler timeout check (BitNet swarm) ────────────────────────────
	if _swarm_scheduler != null:
		_swarm_scheduler.check_timeouts()
		# Also poll health from BrainProcessManager (if auto-spawned)
		if _brain_process_manager != null:
			var health_results: Array = _brain_process_manager.poll_health()
			if not health_results.is_empty():
				var brain_info: Array = _brain_process_manager.get_brain_info()
				for i in range(health_results.size()):
					if not health_results[i] and i < brain_info.size() and not brain_info[i].get("running", false):
						# Brain crashed — mark dead in scheduler
						var dead_backend: Object = _brain_process_manager.create_backend(i)
						if dead_backend != null:
							_swarm_scheduler.mark_brain_dead(dead_backend)
						_log("Brain %d crashed — scheduler degraded to %s" % [i + 1, _swarm_scheduler.get_tier_name()])
	else:
		# ── Legacy timeout check (Ollama / MerlinLLM) ─────────────────────
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
	var params: Dictionary = task.params.duplicate(true)
	var scoped_system := _augment_system_prompt_with_scene(str(task.system), str(task.type), params)
	params.erase("skip_scene_contract")
	var prompt: String = template.format({"system": scoped_system, "input": task.input})
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
## task_role: hint for affinity ("narrator", "gamemaster", "worker").
## priority: BrainSwarmScheduler.Priority value (default NORMAL).
func _lease_bg_brain(task_role: String = "", priority: int = 2) -> Object:
	# ── Scheduler path (BitNet swarm) ─────────────────────────────────────
	if _swarm_scheduler != null:
		return _swarm_scheduler.request_brain(task_role, priority)

	# ── Legacy path (Ollama / MerlinLLM — unchanged) ─────────────────────
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
	# ── Scheduler path ────────────────────────────────────────────────────
	if _swarm_scheduler != null:
		_swarm_scheduler.release_brain(llm)
		return

	# ── Legacy path ───────────────────────────────────────────────────────
	for i in range(_pool_workers.size()):
		if _pool_workers[i] == llm:
			_pool_busy[i] = false
			return
	if llm == narrator_llm:
		_primary_narrator_busy = false
	elif llm == gamemaster_llm:
		_primary_gm_busy = false
