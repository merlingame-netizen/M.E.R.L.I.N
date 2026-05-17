## BrainSwarmConfig — Hardware profiles multi-brain (Gemma 4 primary, Qwen 3.5 legacy)
##
## Defines brain configurations for different hardware tiers.
## Heterogeneous models: each brain uses a different Gemma 4 size (or Qwen if legacy).
## Used by merlin_ai.gd to auto-detect or manually select the best profile.
##
## Mapping Gemma 4 (default, avril 2026, Apache 2.0, contexte 256K) :
##   - Edge 2B (E2B)      -> Judge / Worker / mobile high
##   - Edge 4B (E4B)      -> Game Master / mobile mid (default SINGLE)
##   - MoE 26B-A4B        -> Narrator (4B active params, 26B total)
##   - Dense 31B          -> Offline heavy (premium desktop only)
##
## Tiers:
##   NANO        — E2B all roles (ultra-low RAM ~1 GB)
##   SINGLE      — E4B all roles (~2.5 GB resident)
##   SINGLE_PLUS — 26B-A4B Narrator / E4B GM via time-sharing
##   DUAL        — 26B-A4B + E4B parallel
##   TRIPLE      — 26B-A4B + E4B + E2B Worker
##   QUAD        — 26B-A4B + E4B + E2B Judge + E2B Worker
##   OFFLINE_HEAVY — 31B dense (workstation-class only)
extends RefCounted
class_name BrainSwarmConfig

# ── Profile Names ─────────────────────────────────────────────────────────────
enum Profile { NANO, SINGLE, SINGLE_PLUS, DUAL, TRIPLE, QUAD, OFFLINE_HEAVY, MOBILE_LOW, MOBILE_MID, MOBILE_HIGH }

# ── Ollama Model Tags — Gemma 4 (default) ────────────────────────────────────
const MODEL_GEMMA4_E2B     := "gemma4:e2b"
const MODEL_GEMMA4_E4B     := "gemma4:e4b"
const MODEL_GEMMA4_26B_A4B := "gemma4:26b-a4b"
const MODEL_GEMMA4_31B     := "gemma4:31b"

# ── Ollama Model Tags — Qwen legacy (use_legacy_qwen=true) ───────────────────
const MODEL_QWEN35_4B  := "qwen3.5:4b"
const MODEL_QWEN35_2B  := "qwen3.5:2b"
const MODEL_QWEN35_08B := "qwen3.5:0.8b"
const MODEL_QWEN25_1_5B := "qwen2.5:1.5b"

# ── Mobile model file paths (ARM64 via merlin_llm GDExtension, NOT Ollama) ──
# Default: Gemma 4 GGUF. Qwen/Llama 3.2 kept as legacy fallbacks.
const MODEL_FILE_GEMMA4_E2B  := "gemma4-e2b-q4_k_m.gguf"        # ~700 MB — entry mobile (default)
const MODEL_FILE_GEMMA4_E4B  := "gemma4-e4b-q4_k_m.gguf"        # ~2.0 GB — mid/high mobile (default)
const MODEL_FILE_LLAMA32_1B  := "llama3.2-1b-q4_k_s.gguf"       # legacy
const MODEL_FILE_QWEN25_15B  := "qwen2.5-1.5b-q4_k_m.gguf"      # legacy
const MODEL_FILE_LLAMA32_3B  := "llama3.2-3b-q4_k_m.gguf"       # legacy

# ── RAM estimates per model_key (Q4 quantization, includes KV cache) ─────────
# Keyed by `model_key` (NOT by `ollama_tag` / `model_file`).
const RAM_BY_MODEL := {
	# Gemma 4 (primary)
	"gemma4_e2b":     900,
	"gemma4_e4b":    2000,
	"gemma4_26b_a4b":4200,
	"gemma4_31b":   17000,
	"gemma4_e2b_mobile":  800,
	"gemma4_e4b_mobile": 2000,
	# Qwen / Llama legacy
	"qwen35_4b": 3200,
	"qwen35_2b": 1800,
	"qwen35_0.8b": 800,
	"qwen25_1.5b": 1200,
	"llama32_1b_mobile": 700,
	"qwen25_1.5b_mobile": 1400,
	"llama32_3b_mobile": 2500,
}

# ── Profile Definitions ──────────────────────────────────────────────────────
# Each brain: {role, model_key, ollama_tag, n_ctx, ram_mb, thinking}
## Profile definitions. Switch Gemma 4 <-> Qwen via the use_legacy_qwen flag
## (resolved in get_profile() through _swap_for_legacy_if_needed()).
const PROFILES := {
	Profile.NANO: {
		"name": "Nano (Gemma 4 E2B all roles)",
		"mode": "resident",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_e2b", "ollama_tag": MODEL_GEMMA4_E2B, "n_ctx": 4096, "ram_mb": 900, "thinking": false},
		],
		"total_ram_mb": 900,
		"min_threads": 2,
		"min_ram_mb": 4000,
		"prefetch_depth": 0,
	},
	Profile.SINGLE: {
		"name": "Single (Gemma 4 E4B all roles)",
		"mode": "resident",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_e4b", "ollama_tag": MODEL_GEMMA4_E4B, "n_ctx": 8192, "ram_mb": 2000, "thinking": false},
		],
		"total_ram_mb": 2000,
		"min_threads": 4,
		"min_ram_mb": 6000,
		"prefetch_depth": 1,
	},
	Profile.SINGLE_PLUS: {
		"name": "Single+ (26B-A4B Narrator / E4B GM, time-sharing)",
		"mode": "time_sharing",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_26b_a4b", "ollama_tag": MODEL_GEMMA4_26B_A4B, "n_ctx": 16384, "ram_mb": 4200, "thinking": false},
			{"role": "gamemaster", "model_key": "gemma4_e4b", "ollama_tag": MODEL_GEMMA4_E4B, "n_ctx": 8192, "ram_mb": 2000, "thinking": false},
		],
		"total_ram_mb": 4200,  # Peak RAM = largest model only (time-sharing)
		"min_threads": 4,
		"min_ram_mb": 8000,
		"prefetch_depth": 1,
	},
	Profile.DUAL: {
		"name": "Dual (26B-A4B Narrator + E4B GM parallel)",
		"mode": "parallel",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_26b_a4b", "ollama_tag": MODEL_GEMMA4_26B_A4B, "n_ctx": 16384, "ram_mb": 4200, "thinking": false},
			{"role": "gamemaster", "model_key": "gemma4_e4b", "ollama_tag": MODEL_GEMMA4_E4B, "n_ctx": 8192, "ram_mb": 2000, "thinking": false},
		],
		"total_ram_mb": 6400,  # Both loaded simultaneously
		"min_threads": 6,
		"min_ram_mb": 12000,
		"prefetch_depth": 1,
	},
	Profile.TRIPLE: {
		"name": "Triple (26B-A4B + E4B + E2B Worker)",
		"mode": "parallel",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_26b_a4b", "ollama_tag": MODEL_GEMMA4_26B_A4B, "n_ctx": 16384, "ram_mb": 4200, "thinking": false},
			{"role": "gamemaster", "model_key": "gemma4_e4b", "ollama_tag": MODEL_GEMMA4_E4B, "n_ctx": 8192, "ram_mb": 2000, "thinking": false},
			{"role": "worker", "model_key": "gemma4_e2b", "ollama_tag": MODEL_GEMMA4_E2B, "n_ctx": 2048, "ram_mb": 900, "thinking": false},
		],
		"total_ram_mb": 7300,
		"min_threads": 8,
		"min_ram_mb": 14000,
		"prefetch_depth": 2,
	},
	Profile.QUAD: {
		"name": "Quad (26B-A4B + E4B + E2B Judge + E2B Worker)",
		"mode": "parallel",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_26b_a4b", "ollama_tag": MODEL_GEMMA4_26B_A4B, "n_ctx": 16384, "ram_mb": 4200, "thinking": false},
			{"role": "gamemaster", "model_key": "gemma4_e4b", "ollama_tag": MODEL_GEMMA4_E4B, "n_ctx": 8192, "ram_mb": 2000, "thinking": false},
			{"role": "judge", "model_key": "gemma4_e2b", "ollama_tag": MODEL_GEMMA4_E2B, "n_ctx": 4096, "ram_mb": 900, "thinking": false},
			{"role": "worker", "model_key": "gemma4_e2b", "ollama_tag": MODEL_GEMMA4_E2B, "n_ctx": 2048, "ram_mb": 900, "thinking": false},
		],
		"total_ram_mb": 8200,
		"min_threads": 8,
		"min_ram_mb": 16000,
		"prefetch_depth": 3,
	},
	Profile.OFFLINE_HEAVY: {
		"name": "Offline Heavy (Gemma 4 31B Dense — workstation)",
		"mode": "resident",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_31b", "ollama_tag": MODEL_GEMMA4_31B, "n_ctx": 32768, "ram_mb": 17000, "thinking": false},
		],
		"total_ram_mb": 17000,
		"min_threads": 16,
		"min_ram_mb": 32000,
		"prefetch_depth": 2,
	},
	# ── MOBILE TIERS — single brain strict, ARM64 via merlin_llm GDExtension ──
	# Backend = "merlin_llm_native" (NOT Ollama HTTP). Cross-compile required.
	# No multi-instance on mobile (battery/RAM/thermal constraints).
	# Mobile brains use `model_file` (.gguf path) instead of `ollama_tag`.
	# Default Gemma 4 GGUFs; legacy Llama/Qwen kept inside RAM_BY_MODEL for swap.
	Profile.MOBILE_LOW: {
		"name": "Mobile Low (Gemma 4 E2B)",
		"mode": "resident",
		"platform": "mobile",
		"backend": "merlin_llm_native",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_e2b_mobile", "model_file": MODEL_FILE_GEMMA4_E2B, "ollama_tag": "", "n_ctx": 1536, "ram_mb": 800, "thinking": false},
		],
		"total_ram_mb": 800,
		"min_threads": 4,
		"min_ram_mb": 3000,
		"prefetch_depth": 0,
	},
	Profile.MOBILE_MID: {
		"name": "Mobile Mid (Gemma 4 E4B Q4)",
		"mode": "resident",
		"platform": "mobile",
		"backend": "merlin_llm_native",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_e4b_mobile", "model_file": MODEL_FILE_GEMMA4_E4B, "ollama_tag": "", "n_ctx": 2048, "ram_mb": 2000, "thinking": false},
		],
		"total_ram_mb": 2000,
		"min_threads": 6,
		"min_ram_mb": 6000,
		"prefetch_depth": 0,
	},
	Profile.MOBILE_HIGH: {
		"name": "Mobile High (Gemma 4 E4B Q4 + speculative)",
		"mode": "resident",
		"platform": "mobile",
		"backend": "merlin_llm_native",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_e4b_mobile", "model_file": MODEL_FILE_GEMMA4_E4B, "ollama_tag": "", "n_ctx": 4096, "ram_mb": 2000, "thinking": false},
		],
		"total_ram_mb": 2000,
		"min_threads": 6,
		"min_ram_mb": 7000,
		"prefetch_depth": 0,
	},
}

# ── Legacy Qwen profile overrides (applied via _swap_for_legacy_if_needed) ───
# Used when ProjectSettings ai/use_legacy_qwen == true.
const PROFILES_LEGACY_QWEN := {
	Profile.NANO: {
		"name": "Nano (Qwen 3.5 0.8B all roles) [legacy]",
		"brains": [
			{"role": "narrator", "model_key": "qwen35_0.8b", "ollama_tag": MODEL_QWEN35_08B, "n_ctx": 2048, "ram_mb": 800, "thinking": false},
		],
		"total_ram_mb": 800,
	},
	Profile.SINGLE: {
		"name": "Single (Qwen 3.5 2B all roles) [legacy]",
		"brains": [
			{"role": "narrator", "model_key": "qwen35_2b", "ollama_tag": MODEL_QWEN35_2B, "n_ctx": 4096, "ram_mb": 1800, "thinking": false},
		],
		"total_ram_mb": 1800,
	},
	Profile.SINGLE_PLUS: {
		"name": "Single+ (Qwen 4B/2B time-sharing) [legacy]",
		"brains": [
			{"role": "narrator", "model_key": "qwen35_4b", "ollama_tag": MODEL_QWEN35_4B, "n_ctx": 8192, "ram_mb": 3200, "thinking": false},
			{"role": "gamemaster", "model_key": "qwen35_2b", "ollama_tag": MODEL_QWEN35_2B, "n_ctx": 4096, "ram_mb": 1800, "thinking": true},
		],
		"total_ram_mb": 3200,
	},
	Profile.DUAL: {
		"name": "Dual (Qwen 4B + 2B) [legacy]",
		"brains": [
			{"role": "narrator", "model_key": "qwen35_4b", "ollama_tag": MODEL_QWEN35_4B, "n_ctx": 8192, "ram_mb": 3200, "thinking": false},
			{"role": "gamemaster", "model_key": "qwen35_2b", "ollama_tag": MODEL_QWEN35_2B, "n_ctx": 4096, "ram_mb": 1800, "thinking": true},
		],
		"total_ram_mb": 5000,
	},
	Profile.TRIPLE: {
		"name": "Triple (Qwen 4B + 2B + 0.8B) [legacy]",
		"brains": [
			{"role": "narrator", "model_key": "qwen35_4b", "ollama_tag": MODEL_QWEN35_4B, "n_ctx": 8192, "ram_mb": 3200, "thinking": false},
			{"role": "gamemaster", "model_key": "qwen35_2b", "ollama_tag": MODEL_QWEN35_2B, "n_ctx": 4096, "ram_mb": 1800, "thinking": true},
			{"role": "worker", "model_key": "qwen35_0.8b", "ollama_tag": MODEL_QWEN35_08B, "n_ctx": 2048, "ram_mb": 800, "thinking": false},
		],
		"total_ram_mb": 5800,
	},
	Profile.QUAD: {
		"name": "Quad (Qwen 4B + 2B + 2x 0.8B) [legacy]",
		"brains": [
			{"role": "narrator", "model_key": "qwen35_4b", "ollama_tag": MODEL_QWEN35_4B, "n_ctx": 8192, "ram_mb": 3200, "thinking": false},
			{"role": "gamemaster", "model_key": "qwen35_2b", "ollama_tag": MODEL_QWEN35_2B, "n_ctx": 4096, "ram_mb": 1800, "thinking": true},
			{"role": "judge", "model_key": "qwen35_0.8b", "ollama_tag": MODEL_QWEN35_08B, "n_ctx": 2048, "ram_mb": 800, "thinking": true},
			{"role": "worker", "model_key": "qwen35_0.8b", "ollama_tag": MODEL_QWEN35_08B, "n_ctx": 2048, "ram_mb": 800, "thinking": false},
		],
		"total_ram_mb": 6600,
	},
	Profile.MOBILE_LOW: {
		"name": "Mobile Low (Llama 3.2 1B) [legacy]",
		"brains": [
			{"role": "narrator", "model_key": "llama32_1b_mobile", "model_file": MODEL_FILE_LLAMA32_1B, "ollama_tag": "", "n_ctx": 1024, "ram_mb": 700, "thinking": false},
		],
		"total_ram_mb": 700,
	},
	Profile.MOBILE_MID: {
		"name": "Mobile Mid (Qwen 2.5 1.5B) [legacy]",
		"brains": [
			{"role": "narrator", "model_key": "qwen25_1.5b_mobile", "model_file": MODEL_FILE_QWEN25_15B, "ollama_tag": "", "n_ctx": 2048, "ram_mb": 1400, "thinking": false},
		],
		"total_ram_mb": 1400,
	},
	Profile.MOBILE_HIGH: {
		"name": "Mobile High (Llama 3.2 3B) [legacy]",
		"brains": [
			{"role": "narrator", "model_key": "llama32_3b_mobile", "model_file": MODEL_FILE_LLAMA32_3B, "ollama_tag": "", "n_ctx": 2048, "ram_mb": 2500, "thinking": false},
		],
		"total_ram_mb": 2500,
	},
}


## True when the project is configured to fall back to the Qwen lineage.
static func _use_legacy_qwen() -> bool:
	return ProjectSettings.has_setting("ai/use_legacy_qwen") and bool(ProjectSettings.get_setting("ai/use_legacy_qwen", false))


## Internal: merge a Gemma 4 profile with its Qwen legacy override (brains + name + ram).
static func _swap_for_legacy_if_needed(profile: Dictionary, profile_id: int) -> Dictionary:
	if not _use_legacy_qwen():
		return profile
	if not PROFILES_LEGACY_QWEN.has(profile_id):
		return profile
	var override: Dictionary = PROFILES_LEGACY_QWEN[profile_id]
	var merged: Dictionary = profile.duplicate(true)
	for k in override.keys():
		merged[k] = override[k]
	return merged


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
## OFFLINE_HEAVY is NOT auto-selected — must be opted-in (workstation only).
static func detect_profile(available_ram_mb: int, cpu_threads: int) -> int:
	for profile_id in [Profile.QUAD, Profile.TRIPLE, Profile.DUAL, Profile.SINGLE_PLUS, Profile.SINGLE, Profile.NANO]:
		var profile: Dictionary = PROFILES[profile_id]
		if available_ram_mb >= int(profile.min_ram_mb) and cpu_threads >= int(profile.min_threads):
			return profile_id
	return Profile.NANO


## Get profile definition by ID. Honors ai/use_legacy_qwen for Qwen rollback.
static func get_profile(profile_id: int) -> Dictionary:
	var base: Dictionary = PROFILES.get(profile_id, PROFILES[Profile.NANO])
	return _swap_for_legacy_if_needed(base, profile_id)


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


## Get the Ollama model tag for a specific brain role in a profile.
static func get_model_for_role(profile_id: int, role: String) -> String:
	var profile: Dictionary = get_profile(profile_id)
	var brain_list: Array = profile.get("brains", [])
	for brain_cfg in brain_list:
		if str(brain_cfg.get("role", "")) == role:
			return str(brain_cfg.get("ollama_tag", ""))
	# Fallback: use first brain's model (SINGLE/NANO mode)
	if brain_list.size() > 0:
		return str(brain_list[0].get("ollama_tag", ""))
	return ""


## Get brain config for a specific role.
static func get_brain_config(profile_id: int, role: String) -> Dictionary:
	var profile: Dictionary = get_profile(profile_id)
	var brain_list: Array = profile.get("brains", [])
	for brain_cfg in brain_list:
		if str(brain_cfg.get("role", "")) == role:
			return brain_cfg
	return {}


## Get all unique Ollama model tags needed for a profile (for pre-pulling).
static func get_required_models(profile_id: int) -> Array:
	var profile: Dictionary = get_profile(profile_id)
	var brain_list: Array = profile.get("brains", [])
	var models: Array = []
	for brain_cfg in brain_list:
		var tag: String = str(brain_cfg.get("ollama_tag", ""))
		if tag != "" and tag not in models:
			models.append(tag)
	return models


## Get RAM estimate for the peak usage of a profile.
static func get_peak_ram_mb(profile_id: int) -> int:
	var profile: Dictionary = get_profile(profile_id)
	return int(profile.get("total_ram_mb", 800))
