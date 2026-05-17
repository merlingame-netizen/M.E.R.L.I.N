## ModelsConfig — Central LLM model registry (Gemma 4 primary, Qwen 3.5 legacy)
##
## Source de verite unique pour le mapping role -> modele.
## Bascule via le flag `use_legacy_qwen` (project settings ai/use_legacy_qwen).
##
## Mapping (Gemma 4, avril 2026, Apache 2.0, contexte 256K) :
##   judge / worker  (0.8B class)  -> gemma4:e2b      (~700 MB Q4)
##   gamemaster      (2B class)    -> gemma4:e4b      (~2.0 GB Q4)
##   narrator        (4B class)    -> gemma4:26b-a4b  (~4.2 GB Q4, MoE 4B active)
##   offline_heavy   (premium)     -> gemma4:31b      (~17 GB Q4 dense)
##
## Mapping legacy (Qwen 3.5 / Qwen 2.5) preserve pour `use_legacy_qwen=true`.
##
## Chat template Gemma 4 differs from Qwen ChatML:
##   Qwen:  <|im_start|>system\n...<|im_end|>\n<|im_start|>user\n...<|im_end|>\n
##   Gemma: <bos><start_of_turn>user\n{system}\n\n{user}<end_of_turn>\n<start_of_turn>model\n
##   -> Ollama handles this server-side via the model's TEMPLATE; raw mode bypasses it.
##      Quand `use_legacy_qwen=false`, prefer raw=false (laisser Ollama appliquer le TEMPLATE),
##      OU formatter cote Godot via build_gemma_prompt().
extends RefCounted
class_name ModelsConfig

# ── Project settings key ─────────────────────────────────────────────────────
const SETTING_LEGACY_QWEN := "ai/use_legacy_qwen"

# ── Primary mapping — Gemma 4 family (default) ───────────────────────────────
const GEMMA4_E2B       := "gemma4:e2b"        # Edge 2B    — judge / worker
const GEMMA4_E4B       := "gemma4:e4b"        # Edge 4B    — gamemaster (default SINGLE)
const GEMMA4_26B_A4B   := "gemma4:26b-a4b"    # MoE 26B/4B — narrator
const GEMMA4_31B       := "gemma4:31b"        # Dense 31B  — offline heavy

# ── Legacy mapping — Qwen 3.5 / Qwen 2.5 family ──────────────────────────────
const QWEN35_08B       := "qwen3.5:0.8b"
const QWEN35_2B        := "qwen3.5:2b"
const QWEN35_4B        := "qwen3.5:4b"
const QWEN25_15B       := "qwen2.5:1.5b"

# ── Mobile GGUF files (ARM64 via merlin_llm GDExtension, NOT Ollama) ─────────
const GEMMA4_E2B_GGUF  := "gemma4-e2b-q4_k_m.gguf"          # ~700 MB — entry mobile
const GEMMA4_E4B_GGUF  := "gemma4-e4b-q4_k_m.gguf"          # ~2.0 GB — mid mobile
const LLAMA32_1B_GGUF  := "llama3.2-1b-q4_k_s.gguf"         # legacy fallback
const QWEN25_15B_GGUF  := "qwen2.5-1.5b-q4_k_m.gguf"        # legacy fallback

# ── Role -> model_key mapping ────────────────────────────────────────────────
# Lookup: get_model_for_role(role, use_legacy_qwen) -> Ollama tag.
const ROLE_MAP_GEMMA4 := {
	"judge":      {"tag": GEMMA4_E2B,     "ram_mb":  900, "context_default":  4096, "thinking": true},
	"worker":     {"tag": GEMMA4_E2B,     "ram_mb":  900, "context_default":  2048, "thinking": false},
	"gamemaster": {"tag": GEMMA4_E4B,     "ram_mb": 2000, "context_default":  8192, "thinking": true},
	"narrator":   {"tag": GEMMA4_26B_A4B, "ram_mb": 4200, "context_default": 16384, "thinking": false},
	"offline_heavy": {"tag": GEMMA4_31B,  "ram_mb":17000, "context_default": 32768, "thinking": false},
}

const ROLE_MAP_QWEN := {
	"judge":      {"tag": QWEN35_08B, "ram_mb":  800, "context_default": 2048, "thinking": true},
	"worker":     {"tag": QWEN35_08B, "ram_mb":  800, "context_default": 2048, "thinking": false},
	"gamemaster": {"tag": QWEN35_2B,  "ram_mb": 1800, "context_default": 4096, "thinking": true},
	"narrator":   {"tag": QWEN35_4B,  "ram_mb": 3200, "context_default": 8192, "thinking": false},
	"offline_heavy": {"tag": QWEN35_4B, "ram_mb": 3200, "context_default": 8192, "thinking": false},
}


## True if the legacy Qwen mapping should be used (project setting or override).
static func use_legacy_qwen() -> bool:
	if ProjectSettings.has_setting(SETTING_LEGACY_QWEN):
		return bool(ProjectSettings.get_setting(SETTING_LEGACY_QWEN, false))
	return false


## Return the active role map (Gemma 4 or Qwen legacy).
static func active_role_map() -> Dictionary:
	return ROLE_MAP_QWEN if use_legacy_qwen() else ROLE_MAP_GEMMA4


## Lookup an Ollama tag for a logical role.
##   role: "judge" | "worker" | "gamemaster" | "narrator" | "offline_heavy"
static func get_tag_for_role(role: String) -> String:
	var m: Dictionary = active_role_map()
	if m.has(role):
		return str(m[role].tag)
	# Fallback: gamemaster (default mid-tier)
	return str(m.get("gamemaster", {"tag": GEMMA4_E4B}).tag)


## Full role config (tag, ram_mb, context_default, thinking).
static func get_role_config(role: String) -> Dictionary:
	var m: Dictionary = active_role_map()
	if m.has(role):
		return (m[role] as Dictionary).duplicate(true)
	return {}


## Build a Gemma chat-template prompt (used when raw=true with Gemma models).
## Gemma 4 keeps the Gemma 1/2/3 template:
##   <bos><start_of_turn>user\n{system}\n\n{prompt}<end_of_turn>\n<start_of_turn>model\n
static func build_gemma_prompt(system_prompt: String, user_prompt: String) -> String:
	var sys: String = system_prompt.strip_edges()
	var usr: String = user_prompt.strip_edges()
	if sys != "":
		return "<bos><start_of_turn>user\n%s\n\n%s<end_of_turn>\n<start_of_turn>model\n" % [sys, usr]
	return "<bos><start_of_turn>user\n%s<end_of_turn>\n<start_of_turn>model\n" % usr


## Build a Qwen ChatML prompt (legacy).
static func build_qwen_prompt(system_prompt: String, user_prompt: String) -> String:
	return "<|im_start|>system\n%s<|im_end|>\n<|im_start|>user\n%s<|im_end|>\n<|im_start|>assistant\n" % [system_prompt, user_prompt]


## Convenience: format a system+user prompt with the active model family's template.
static func build_prompt(system_prompt: String, user_prompt: String) -> String:
	return build_qwen_prompt(system_prompt, user_prompt) if use_legacy_qwen() else build_gemma_prompt(system_prompt, user_prompt)


## True if the currently active family natively supports thinking tags.
## - Qwen 3.5: <think>...</think>
## - Gemma 4 : pas de thinking tags publics; champ `think` Ollama no-op cote serveur.
static func family_supports_thinking() -> bool:
	return use_legacy_qwen()


## Required Ollama tags for a list of roles (deduped) — for pre-pull.
static func required_tags_for_roles(roles: Array) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for r in roles:
		var tag: String = get_tag_for_role(str(r))
		if tag != "" and not seen.has(tag):
			seen[tag] = true
			out.append(tag)
	return out
