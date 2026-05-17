## ModelsConfig — Central role→model mapping (Gemma 4 active, Qwen legacy fallback)
##
## Source de verite unique pour le mapping role→modele Ollama.
## Phase 33+ Gemma 4 migration: switch active family via `use_legacy_qwen` flag.
##
## Roles supportes:
##   - judge       : 0.8B class — Worker/Judge tasks (fast verdicts, classification)
##   - gamemaster  : 2B  class — JSON/effects/structured output (GBNF-style)
##   - narrator    : 4B  class — Creative prose, dialogue, Merlin voice
##   - dev_heavy   : 31B dense — Offline dev tooling only (QUAD heavy)
##
## Families:
##   gemma4   : default (April 2026, Apache 2.0, 256K ctx, multimodal text+image+audio)
##   qwen35   : legacy fallback (use_legacy_qwen=true)
##
## Usage:
##   var tag := ModelsConfig.tag_for_role("narrator")        # → "gemma4:26b-a4b"
##   var ctx := ModelsConfig.context_for_role("gamemaster")  # → 8192
##   var fam := ModelsConfig.family_for_tag("gemma4:e4b")    # → "gemma4"
extends RefCounted
class_name ModelsConfig

# ── Config flag ───────────────────────────────────────────────────────────────
# Set to true to fall back to Qwen 3.5 family (e.g. if Gemma 4 not pulled yet).
# Read from project settings at runtime via load_settings().
static var use_legacy_qwen: bool = false

# ── Gemma 4 family (default, April 2026) ─────────────────────────────────────
# Naming follows Ollama tag conventions (gemma4:<size>).
# E-variants (E2B/E4B) are "Effective" mobile-optimised builds (per-token compute trimmed).
# 26b-a4b is MoE: 26B total params, ~3.8B activated per token (latency of a 4B dense).
# 31b is dense, dev-only (heavy QUAD profile).
const GEMMA4_JUDGE := "gemma4:e2b"          # Q4, ~1.6 GB RAM
const GEMMA4_GAMEMASTER := "gemma4:e4b"     # Q4, ~3.0 GB RAM, multimodal-capable
const GEMMA4_NARRATOR := "gemma4:26b-a4b"   # MoE Q4, ~14 GB RAM (3.8B active)
const GEMMA4_DEV_HEAVY := "gemma4:31b"      # Dense Q4, ~18 GB RAM (offline tooling)

# ── Qwen 3.5 legacy family (fallback) ────────────────────────────────────────
const QWEN35_JUDGE := "qwen3.5:0.8b"
const QWEN35_GAMEMASTER := "qwen3.5:2b"
const QWEN35_NARRATOR := "qwen3.5:4b"

# ── Role → tag mapping per family ────────────────────────────────────────────
const ROLE_MAP := {
	"gemma4": {
		"judge": GEMMA4_JUDGE,
		"worker": GEMMA4_JUDGE,        # Worker uses same 0.8B-class as Judge
		"gamemaster": GEMMA4_GAMEMASTER,
		"narrator": GEMMA4_NARRATOR,
		"dev_heavy": GEMMA4_DEV_HEAVY,
	},
	"qwen35": {
		"judge": QWEN35_JUDGE,
		"worker": QWEN35_JUDGE,
		"gamemaster": QWEN35_GAMEMASTER,
		"narrator": QWEN35_NARRATOR,
		"dev_heavy": QWEN35_NARRATOR,  # Qwen has no 31B equivalent on the legacy path
	},
}

# ── Context window defaults per role (tokens) ────────────────────────────────
# Gemma 4 supports up to 256K, but we cap for latency/RAM sanity.
const CONTEXT_MAP := {
	"judge": 2048,
	"worker": 2048,
	"gamemaster": 8192,    # Was 4096 on Qwen; Gemma 4 E4B handles 8K comfortably
	"narrator": 8192,
	"dev_heavy": 16384,
}

# ── RAM estimates per role (MB, Q4 + KV cache) ───────────────────────────────
# Adjusted for Gemma 4. Qwen 3.5 estimates kept in BrainSwarmConfig.RAM_BY_MODEL.
const RAM_BY_ROLE_GEMMA4 := {
	"judge": 1600,
	"worker": 1600,
	"gamemaster": 3000,
	"narrator": 14000,   # MoE: 26B params resident, ~3.8B active per token
	"dev_heavy": 18000,
}
const RAM_BY_ROLE_QWEN35 := {
	"judge": 800,
	"worker": 800,
	"gamemaster": 1800,
	"narrator": 3200,
	"dev_heavy": 3200,
}

# ── Public API ───────────────────────────────────────────────────────────────

## Returns the active family ("gemma4" or "qwen35").
static func active_family() -> String:
	return "qwen35" if use_legacy_qwen else "gemma4"


## Returns the Ollama tag for a given role in the active family.
static func tag_for_role(role: String) -> String:
	var fam: String = active_family()
	var role_lc: String = role.to_lower()
	if not ROLE_MAP.has(fam):
		return ""
	var fam_map: Dictionary = ROLE_MAP[fam]
	if fam_map.has(role_lc):
		return str(fam_map[role_lc])
	# Fallback chain: unknown role → gamemaster (sensible default)
	return str(fam_map.get("gamemaster", ""))


## Returns the recommended context size for a given role.
static func context_for_role(role: String) -> int:
	return int(CONTEXT_MAP.get(role.to_lower(), 4096))


## Returns the RAM estimate (MB) for a role under the active family.
static func ram_mb_for_role(role: String) -> int:
	var table: Dictionary = RAM_BY_ROLE_GEMMA4 if active_family() == "gemma4" else RAM_BY_ROLE_QWEN35
	return int(table.get(role.to_lower(), 2000))


## Identify the model family from an Ollama tag.
## Returns "gemma4", "qwen35", "qwen25", or "unknown".
static func family_for_tag(tag: String) -> String:
	var t: String = tag.to_lower()
	if t.begins_with("gemma4") or t.begins_with("gemma:4") or t.begins_with("gemma-4"):
		return "gemma4"
	if t.begins_with("qwen3.5") or t.begins_with("qwen35"):
		return "qwen35"
	if t.begins_with("qwen2.5") or t.begins_with("qwen25"):
		return "qwen25"
	return "unknown"


## True if the tag belongs to a Gemma family (uses <start_of_turn>/<end_of_turn>).
static func is_gemma_tag(tag: String) -> bool:
	return family_for_tag(tag) == "gemma4"


## True if the tag belongs to a Qwen family (uses ChatML <|im_start|>/<|im_end|>).
static func is_qwen_tag(tag: String) -> bool:
	var fam: String = family_for_tag(tag)
	return fam == "qwen35" or fam == "qwen25"


## Load `use_legacy_qwen` from project settings (config/llm/use_legacy_qwen).
## Call once at MerlinAI._ready() before initialising backends.
static func load_settings() -> void:
	if ProjectSettings.has_setting("merlin/llm/use_legacy_qwen"):
		use_legacy_qwen = bool(ProjectSettings.get_setting("merlin/llm/use_legacy_qwen"))


## Dump current mapping for diagnostics.
static func describe() -> Dictionary:
	return {
		"family": active_family(),
		"use_legacy_qwen": use_legacy_qwen,
		"mapping": ROLE_MAP[active_family()],
	}
