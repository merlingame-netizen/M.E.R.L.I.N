## BrainSwarmConfig — Hardware profiles for BitNet brain swarm
##
## Defines brain configurations for different hardware tiers.
## Used by merlin_ai.gd to auto-detect or manually select the best profile.
extends RefCounted
class_name BrainSwarmConfig

# ── Profile Names ─────────────────────────────────────────────────────────────
enum Profile { SINGLE, LAPTOP_2, LAPTOP_4, DESKTOP_6, DESKTOP_8 }

# ── Model Paths (auto-detected) ──────────────────────────────────────────────
const MODEL_FALCON_7B := "Falcon3-7B-Instruct-1.58bit/ggml-model-i2_s.gguf"
const MODEL_BITNET_2B := "BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf"

# ── Profile Definitions ──────────────────────────────────────────────────────
# Each brain: {role, model_key, threads, n_ctx, ram_mb}
const PROFILES := {
	Profile.SINGLE: {
		"name": "Single (Narrator only)",
		"brains": [
			{"role": "narrator", "model_key": "falcon_7b", "threads": 4, "n_ctx": 1024, "ram_mb": 3300},
		],
		"total_ram_mb": 3300,
		"min_threads": 4,
		"prefetch_depth": 1,
	},
	Profile.LAPTOP_2: {
		"name": "Dual (Narrator + GM)",
		"brains": [
			{"role": "narrator", "model_key": "falcon_7b", "threads": 3, "n_ctx": 1024, "ram_mb": 3300},
			{"role": "gamemaster", "model_key": "bitnet_2b", "threads": 2, "n_ctx": 512, "ram_mb": 1900},
		],
		"total_ram_mb": 5200,
		"min_threads": 6,
		"prefetch_depth": 1,
	},
	Profile.LAPTOP_4: {
		"name": "Quad (Narrator + GM + 2 Workers)",
		"brains": [
			{"role": "narrator", "model_key": "falcon_7b", "threads": 3, "n_ctx": 1024, "ram_mb": 3300},
			{"role": "gamemaster", "model_key": "bitnet_2b", "threads": 2, "n_ctx": 512, "ram_mb": 1900},
			{"role": "worker", "model_key": "bitnet_2b", "threads": 2, "n_ctx": 512, "ram_mb": 1900},
			{"role": "worker", "model_key": "bitnet_2b", "threads": 1, "n_ctx": 256, "ram_mb": 1900},
		],
		"total_ram_mb": 9000,
		"min_threads": 8,
		"prefetch_depth": 3,
	},
	Profile.DESKTOP_6: {
		"name": "Hexa (2x Narrator + GM + Judge + 2 Workers)",
		"brains": [
			{"role": "narrator", "model_key": "falcon_7b", "threads": 4, "n_ctx": 2048, "ram_mb": 3300},
			{"role": "narrator", "model_key": "falcon_7b", "threads": 4, "n_ctx": 2048, "ram_mb": 3300},
			{"role": "gamemaster", "model_key": "bitnet_2b", "threads": 2, "n_ctx": 512, "ram_mb": 1900},
			{"role": "judge", "model_key": "falcon_7b", "threads": 3, "n_ctx": 1024, "ram_mb": 3300},
			{"role": "worker", "model_key": "bitnet_2b", "threads": 2, "n_ctx": 512, "ram_mb": 1900},
			{"role": "worker", "model_key": "bitnet_2b", "threads": 2, "n_ctx": 512, "ram_mb": 1900},
		],
		"total_ram_mb": 15600,
		"min_threads": 16,
		"prefetch_depth": 3,
	},
	Profile.DESKTOP_8: {
		"name": "Octa (2x Narrator + GM + Judge + Voice + 3 Workers)",
		"brains": [
			{"role": "narrator", "model_key": "falcon_7b", "threads": 4, "n_ctx": 2048, "ram_mb": 3300},
			{"role": "narrator", "model_key": "falcon_7b", "threads": 4, "n_ctx": 2048, "ram_mb": 3300},
			{"role": "gamemaster", "model_key": "bitnet_2b", "threads": 2, "n_ctx": 512, "ram_mb": 1900},
			{"role": "judge", "model_key": "falcon_7b", "threads": 3, "n_ctx": 1024, "ram_mb": 3300},
			{"role": "voice", "model_key": "bitnet_2b", "threads": 1, "n_ctx": 256, "ram_mb": 1900},
			{"role": "worker", "model_key": "bitnet_2b", "threads": 2, "n_ctx": 512, "ram_mb": 1900},
			{"role": "worker", "model_key": "bitnet_2b", "threads": 2, "n_ctx": 512, "ram_mb": 1900},
			{"role": "worker", "model_key": "bitnet_2b", "threads": 2, "n_ctx": 512, "ram_mb": 1900},
		],
		"total_ram_mb": 21400,
		"min_threads": 20,
		"prefetch_depth": 3,
	},
}


## Auto-detect the best profile based on available hardware.
static func detect_profile(available_ram_mb: int, cpu_threads: int) -> int:
	# Check from largest to smallest
	for profile_id in [Profile.DESKTOP_8, Profile.DESKTOP_6, Profile.LAPTOP_4, Profile.LAPTOP_2, Profile.SINGLE]:
		var profile: Dictionary = PROFILES[profile_id]
		# Need RAM for brains + ~4 GB for OS/Godot
		var needed_ram: int = profile.total_ram_mb + 4000
		var needed_threads: int = profile.min_threads
		if available_ram_mb >= needed_ram and cpu_threads >= needed_threads:
			return profile_id
	return Profile.SINGLE


## Get profile definition by ID.
static func get_profile(profile_id: int) -> Dictionary:
	return PROFILES.get(profile_id, PROFILES[Profile.SINGLE])


## Get the prefetch depth for a profile.
static func get_prefetch_depth(profile_id: int) -> int:
	var profile: Dictionary = get_profile(profile_id)
	return int(profile.get("prefetch_depth", 1))


## Get profile name for display.
static func get_profile_name(profile_id: int) -> String:
	var profile: Dictionary = get_profile(profile_id)
	return str(profile.get("name", "Unknown"))


## Resolve model_key to actual file path.
## model_base_dir: directory containing model subdirectories.
static func resolve_model_path(model_key: String, model_base_dir: String) -> String:
	var filename: String = ""
	match model_key:
		"falcon_7b":
			filename = MODEL_FALCON_7B
		"bitnet_2b":
			filename = MODEL_BITNET_2B
		_:
			return ""
	var full_path: String = model_base_dir.path_join(filename)
	if FileAccess.file_exists(full_path):
		return full_path
	return ""


## Build brain_defs array for BrainProcessManager from a profile.
## model_base_dir: e.g., "C:/Users/PGNK2128/BitNet/models"
static func build_brain_defs(profile_id: int, model_base_dir: String) -> Array:
	var profile: Dictionary = get_profile(profile_id)
	var defs: Array = []
	var brain_list: Array = profile.get("brains", [])
	for brain_cfg in brain_list:
		var model_key: String = str(brain_cfg.get("model_key", ""))
		var model_path := resolve_model_path(model_key, model_base_dir)
		if model_path == "":
			continue  # Model not available — skip this brain
		defs.append({
			"role": str(brain_cfg.get("role", "worker")),
			"model": model_path,
			"threads": int(brain_cfg.get("threads", 2)),
			"n_ctx": int(brain_cfg.get("n_ctx", 512)),
		})
	return defs
