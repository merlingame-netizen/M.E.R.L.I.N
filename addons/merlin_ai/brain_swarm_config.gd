## BrainSwarmConfig — Hardware profiles for the multi-brain architecture
##
## Phase 33+ Gemma 4 migration (April 2026):
##   - Active family: Gemma 4 (Apache 2.0, 256K context, multimodal)
##   - Legacy Qwen 3.5 retained behind ModelsConfig.use_legacy_qwen flag
##   - Mobile profiles still use Llama/Qwen GGUF via merlin_llm GDExtension
##
## Tiers (desktop):
##   NANO        — 0.8B-class all roles (ultra-low RAM)
##   SINGLE      — 2B-class all roles (one model resident)
##   SINGLE_PLUS — Narrator + GM via time-sharing
##   DUAL        — Narrator + GM parallel
##   TRIPLE      — Narrator + GM + Worker
##   QUAD        — Narrator + GM + Judge + Worker
extends RefCounted
class_name BrainSwarmConfig

const ModelsConfigScript = preload("res://addons/merlin_ai/models_config.gd")

# ── Profile Names ─────────────────────────────────────────────────────────────
enum Profile { NANO, SINGLE, SINGLE_PLUS, DUAL, TRIPLE, QUAD, MOBILE_LOW, MOBILE_MID, MOBILE_HIGH }

# ── Ollama Model Tags (Gemma 4 — active family) ──────────────────────────────
const MODEL_GEMMA4_E2B := "gemma4:e2b"
const MODEL_GEMMA4_E4B := "gemma4:e4b"
const MODEL_GEMMA4_26B_A4B := "gemma4:26b-a4b"
const MODEL_GEMMA4_31B := "gemma4:31b"

# ── Ollama Model Tags (Qwen 3.5 — legacy fallback) ───────────────────────────
const MODEL_QWEN35_4B := "qwen3.5:4b"
const MODEL_QWEN35_2B := "qwen3.5:2b"
const MODEL_QWEN35_08B := "qwen3.5:0.8b"
const MODEL_QWEN25_1_5B := "qwen2.5:1.5b"

# ── Mobile model file paths (ARM64 via merlin_llm GDExtension recompiled, NOT Ollama) ─
# These are .gguf filenames in addons/merlin_llm/models/ — NOT Ollama tags.
# Loaded directly via merlin_llm GDExtension on Android/iOS (no Ollama daemon).
const MODEL_FILE_LLAMA32_1B := "llama3.2-1b-q4_k_s.gguf"        # ~700 MB — entry mobile
const MODEL_FILE_QWEN25_15B := "qwen2.5-1.5b-q4_k_m.gguf"       # ~1.4 GB — mid mobile
const MODEL_FILE_LLAMA32_3B := "llama3.2-3b-q4_k_m.gguf"        # ~2.5 GB — high mobile
const MODEL_FILE_GEMMA4_E2B := "gemma4-e2b-q4_k_m.gguf"         # ~1.6 GB — mobile target

# ── RAM estimates per model_key (Q4 quantization, includes KV cache) ─────────
const RAM_BY_MODEL := {
	# Gemma 4 (active)
	"gemma4_e2b": 1600,
	"gemma4_e4b": 3000,
	"gemma4_26b_a4b": 14000,  # MoE: 26B params resident, ~3.8B activated/token
	"gemma4_31b": 18000,
	# Qwen 3.5 (legacy)
	"qwen35_4b": 3200,
	"qwen35_2b": 1800,
	"qwen35_0.8b": 800,
	"qwen25_1.5b": 1200,
	# Mobile (GGUF via merlin_llm)
	"llama32_1b_mobile": 700,
	"qwen25_1.5b_mobile": 1400,
	"llama32_3b_mobile": 2500,
	"gemma4_e2b_mobile": 1600,
}

# ── Profile Definitions ──────────────────────────────────────────────────────
# Each brain: {role, model_key, ollama_tag, n_ctx, ram_mb, thinking}
const PROFILES := {
	Profile.NANO: {
		"name": "Nano (Gemma 4 E2B all roles)",
		"mode": "resident",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_e2b", "ollama_tag": MODEL_GEMMA4_E2B, "n_ctx": 2048, "ram_mb": 1600, "thinking": false},
		],
		"total_ram_mb": 1600,
		"min_threads": 2,
		"min_ram_mb": 4000,
		"prefetch_depth": 0,
	},
	Profile.SINGLE: {
		"name": "Single (Gemma 4 E4B all roles)",
		"mode": "resident",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_e4b", "ollama_tag": MODEL_GEMMA4_E4B, "n_ctx": 8192, "ram_mb": 3000, "thinking": false},
		],
		"total_ram_mb": 3000,
		"min_threads": 4,
		"min_ram_mb": 8000,
		"prefetch_depth": 1,
	},
	Profile.SINGLE_PLUS: {
		"name": "Single+ (Gemma 4 26B-A4B Narrator / E4B GM, time-sharing)",
		"mode": "time_sharing",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_26b_a4b", "ollama_tag": MODEL_GEMMA4_26B_A4B, "n_ctx": 8192, "ram_mb": 14000, "thinking": false},
			{"role": "gamemaster", "model_key": "gemma4_e4b", "ollama_tag": MODEL_GEMMA4_E4B, "n_ctx": 8192, "ram_mb": 3000, "thinking": true},
		],
		"total_ram_mb": 14000,  # Peak RAM = largest model only (time-sharing)
		"min_threads": 6,
		"min_ram_mb": 20000,
		"prefetch_depth": 1,
	},
	Profile.DUAL: {
		"name": "Dual (Gemma 4 26B-A4B Narrator + E4B GM parallel)",
		"mode": "parallel",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_26b_a4b", "ollama_tag": MODEL_GEMMA4_26B_A4B, "n_ctx": 8192, "ram_mb": 14000, "thinking": false},
			{"role": "gamemaster", "model_key": "gemma4_e4b", "ollama_tag": MODEL_GEMMA4_E4B, "n_ctx": 8192, "ram_mb": 3000, "thinking": true},
		],
		"total_ram_mb": 17000,  # Both loaded simultaneously
		"min_threads": 8,
		"min_ram_mb": 24000,
		"prefetch_depth": 1,
	},
	Profile.TRIPLE: {
		"name": "Triple (26B-A4B + E4B + E2B Worker)",
		"mode": "parallel",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_26b_a4b", "ollama_tag": MODEL_GEMMA4_26B_A4B, "n_ctx": 8192, "ram_mb": 14000, "thinking": false},
			{"role": "gamemaster", "model_key": "gemma4_e4b", "ollama_tag": MODEL_GEMMA4_E4B, "n_ctx": 8192, "ram_mb": 3000, "thinking": true},
			{"role": "worker", "model_key": "gemma4_e2b", "ollama_tag": MODEL_GEMMA4_E2B, "n_ctx": 2048, "ram_mb": 1600, "thinking": false},
		],
		"total_ram_mb": 18600,
		"min_threads": 10,
		"min_ram_mb": 28000,
		"prefetch_depth": 2,
	},
	Profile.QUAD: {
		"name": "Quad (26B-A4B + E4B + E2B Judge + E2B Worker, includes Gemma 4 31B dev_heavy option)",
		"mode": "parallel",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_26b_a4b", "ollama_tag": MODEL_GEMMA4_26B_A4B, "n_ctx": 8192, "ram_mb": 14000, "thinking": false},
			{"role": "gamemaster", "model_key": "gemma4_e4b", "ollama_tag": MODEL_GEMMA4_E4B, "n_ctx": 8192, "ram_mb": 3000, "thinking": true},
			{"role": "judge", "model_key": "gemma4_e2b", "ollama_tag": MODEL_GEMMA4_E2B, "n_ctx": 2048, "ram_mb": 1600, "thinking": true},
			{"role": "worker", "model_key": "gemma4_e2b", "ollama_tag": MODEL_GEMMA4_E2B, "n_ctx": 2048, "ram_mb": 1600, "thinking": false},
		],
		"total_ram_mb": 20200,
		"min_threads": 12,
		"min_ram_mb": 32000,
		"prefetch_depth": 3,
	},
	# ── MOBILE TIERS — single brain strict, ARM64 via merlin_llm GDExtension ──
	# Backend = "merlin_llm_native" (NOT Ollama HTTP). Cross-compile required.
	# No multi-instance on mobile (battery/RAM/thermal constraints).
	# Mobile brains use `model_file` (.gguf path) instead of `ollama_tag`.
	# `ollama_tag` set to "" on mobile to make it explicit that no Ollama is involved.
	Profile.MOBILE_LOW: {
		"name": "Mobile Low (Llama 3.2 1B)",
		"mode": "resident",
		"platform": "mobile",
		"backend": "merlin_llm_native",
		"brains": [
			{"role": "narrator", "model_key": "llama32_1b_mobile", "model_file": MODEL_FILE_LLAMA32_1B, "ollama_tag": "", "n_ctx": 1024, "ram_mb": 700, "thinking": false},
		],
		"total_ram_mb": 700,
		"min_threads": 4,
		"min_ram_mb": 3000,
		"prefetch_depth": 0,
	},
	Profile.MOBILE_MID: {
		"name": "Mobile Mid (Qwen 2.5 1.5B)",
		"mode": "resident",
		"platform": "mobile",
		"backend": "merlin_llm_native",
		"brains": [
			{"role": "narrator", "model_key": "qwen25_1.5b_mobile", "model_file": MODEL_FILE_QWEN25_15B, "ollama_tag": "", "n_ctx": 2048, "ram_mb": 1400, "thinking": false},
		],
		"total_ram_mb": 1400,
		"min_threads": 6,
		"min_ram_mb": 5000,
		"prefetch_depth": 0,
	},
	Profile.MOBILE_HIGH: {
		"name": "Mobile High (Llama 3.2 3B)",
		"mode": "resident",
		"platform": "mobile",
		"backend": "merlin_llm_native",
		"brains": [
			{"role": "narrator", "model_key": "llama32_3b_mobile", "model_file": MODEL_FILE_LLAMA32_3B, "ollama_tag": "", "n_ctx": 2048, "ram_mb": 2500, "thinking": false},
		],
		"total_ram_mb": 2500,
		"min_threads": 6,
		"min_ram_mb": 7000,
		"prefetch_depth": 0,
	},
}


## Get the mobile model file path for a brain role in a profile.
## Returns "" if not a mobile profile or role not found.
static func get_model_file_for_role(profile_id: int, role: String) -> String:
	var profile: Dictionary = get_profile(profile_id)
	var brain_list: Array = profile.get("brains", [])
	for brain_cfg in brain_list:
		if str(brain_cfg.get("role", "")) == role:
			return str(brain_cfg.get("model_file", ""))
	if brain_list.size() > 0:
		return str(brain_list[0].get("model_file", ""))
	return ""


## Auto-detect mobile profile based on available RAM + threads.
## Returns MOBILE_HIGH > MOBILE_MID > MOBILE_LOW (largest that fits).
## Use this on mobile platforms (Android/iOS); use detect_profile() on desktop.
static func detect_profile_mobile(available_ram_mb: int, cpu_threads: int) -> int:
	for profile_id in [Profile.MOBILE_HIGH, Profile.MOBILE_MID, Profile.MOBILE_LOW]:
		var profile: Dictionary = PROFILES[profile_id]
		if available_ram_mb >= int(profile.min_ram_mb) and cpu_threads >= int(profile.min_threads):
			return profile_id
	return Profile.MOBILE_LOW  # Fallback (always works on min mobile)


## True if profile is targeted at mobile platforms (Android/iOS).
static func is_mobile_profile(profile_id: int) -> bool:
	var profile: Dictionary = get_profile(profile_id)
	return str(profile.get("platform", "desktop")) == "mobile"


## Get backend hint for a profile ("ollama_http" or "merlin_llm_native").
static func get_backend_hint(profile_id: int) -> String:
	var profile: Dictionary = get_profile(profile_id)
	return str(profile.get("backend", "ollama_http"))


## Auto-detect the best profile based on available hardware.
## Checks from largest to smallest, picks the biggest that fits.
static func detect_profile(available_ram_mb: int, cpu_threads: int) -> int:
	for profile_id in [Profile.QUAD, Profile.TRIPLE, Profile.DUAL, Profile.SINGLE_PLUS, Profile.SINGLE, Profile.NANO]:
		var profile: Dictionary = PROFILES[profile_id]
		if available_ram_mb >= int(profile.min_ram_mb) and cpu_threads >= int(profile.min_threads):
			return profile_id
	return Profile.NANO


## Get profile definition by ID.
static func get_profile(profile_id: int) -> Dictionary:
	return PROFILES.get(profile_id, PROFILES[Profile.NANO])


## Get the prefetch depth for a profile.
static func get_prefetch_depth(profile_id: int) -> int:
	var profile: Dictionary = get_profile(profile_id)
	return int(profile.get("prefetch_depth", 0))


## Get profile name for display.
static func get_profile_name(profile_id: int) -> String:
	var profile: Dictionary = get_profile(profile_id)
	return str(profile.get("name", "Unknown"))


## Check if a profile uses time-sharing mode (one model at a time).
static func is_time_sharing(profile_id: int) -> bool:
	var profile: Dictionary = get_profile(profile_id)
	return str(profile.get("mode", "resident")) == "time_sharing"


# ── Gemma 4 → Qwen 3.5 legacy translation table ──────────────────────────────
# Used when ModelsConfig.use_legacy_qwen is true. Maps Gemma 4 model_key/tag
# back to the Qwen 3.5 equivalent so callers don't need to branch on family.
const QWEN_LEGACY_MAP := {
	"gemma4_e2b":     {"model_key": "qwen35_0.8b",  "ollama_tag": MODEL_QWEN35_08B, "ram_mb": 800},
	"gemma4_e4b":     {"model_key": "qwen35_2b",    "ollama_tag": MODEL_QWEN35_2B,  "ram_mb": 1800},
	"gemma4_26b_a4b": {"model_key": "qwen35_4b",    "ollama_tag": MODEL_QWEN35_4B,  "ram_mb": 3200},
	"gemma4_31b":     {"model_key": "qwen35_4b",    "ollama_tag": MODEL_QWEN35_4B,  "ram_mb": 3200},
}


## Translate a brain config to Qwen 3.5 legacy if `use_legacy_qwen` is true.
static func _maybe_legacy(brain_cfg: Dictionary) -> Dictionary:
	if not ModelsConfigScript.use_legacy_qwen:
		return brain_cfg
	var key: String = str(brain_cfg.get("model_key", ""))
	if not QWEN_LEGACY_MAP.has(key):
		return brain_cfg
	var legacy: Dictionary = QWEN_LEGACY_MAP[key]
	var out: Dictionary = brain_cfg.duplicate(true)
	out["model_key"] = legacy.model_key
	out["ollama_tag"] = legacy.ollama_tag
	out["ram_mb"] = legacy.ram_mb
	return out


## Get the Ollama model tag for a specific brain role in a profile.
static func get_model_for_role(profile_id: int, role: String) -> String:
	var profile: Dictionary = get_profile(profile_id)
	var brain_list: Array = profile.get("brains", [])
	for brain_cfg in brain_list:
		if str(brain_cfg.get("role", "")) == role:
			return str(_maybe_legacy(brain_cfg).get("ollama_tag", ""))
	if brain_list.size() > 0:
		return str(_maybe_legacy(brain_list[0]).get("ollama_tag", ""))
	return ""


## Get brain config for a specific role.
static func get_brain_config(profile_id: int, role: String) -> Dictionary:
	var profile: Dictionary = get_profile(profile_id)
	var brain_list: Array = profile.get("brains", [])
	for brain_cfg in brain_list:
		if str(brain_cfg.get("role", "")) == role:
			return _maybe_legacy(brain_cfg)
	return {}


## Get all unique Ollama model tags needed for a profile (for pre-pulling).
static func get_required_models(profile_id: int) -> Array:
	var profile: Dictionary = get_profile(profile_id)
	var brain_list: Array = profile.get("brains", [])
	var models: Array = []
	for brain_cfg in brain_list:
		var tag: String = str(_maybe_legacy(brain_cfg).get("ollama_tag", ""))
		if tag != "" and tag not in models:
			models.append(tag)
	return models


## Get RAM estimate for the peak usage of a profile.
static func get_peak_ram_mb(profile_id: int) -> int:
	var profile: Dictionary = get_profile(profile_id)
	return int(profile.get("total_ram_mb", 800))
