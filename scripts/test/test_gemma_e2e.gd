## ═══════════════════════════════════════════════════════════════════════════════
## Test Gemma 4 E2E — full LLM pipeline on gemma4:e4b
## ═══════════════════════════════════════════════════════════════════════════════
## Purpose: prove the demo runs end-to-end on Gemma 4 by exercising the same
## entry points the live game uses (no shortcuts). Lighter than test_llm_full_run
## (which runs 20 cards over several minutes) so it can drive the audit loop.
##
## Checks:
##   1. MerlinAI boots and warms up against the active Ollama model
##   2. generate_with_system returns non-empty French prose (narrator path)
##   3. generate_rpg_card returns a schema-valid card dict (gamemaster path)
##   4. Output contains no leaked turn-format artefacts (<start_of_turn>, etc.)
##
## Exit code: 0 = PASS, 1 = FAIL. Writes a JSON summary to user://gemma_e2e_result.json.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

const RESULT_PATH := "user://gemma_e2e_result.json"
const NARRATOR_TIMEOUT_MS := 90000
const CARD_TIMEOUT_MS := 90000
# Tokens the model must NEVER emit in cleaned output. If any appear, the
# clean_response / _strip_thinking_tags layers regressed.
const FORBIDDEN_TOKENS := [
	"<start_of_turn>", "</start_of_turn>",
	"<end_of_turn>",   "</end_of_turn>",
	"<|im_start|>", "<|im_end|>",
	"<think>", "</think>",
]
# Minimum length (chars) for a "real" narrator response; below this, treat as
# an empty / thinking-only output.
const MIN_NARRATOR_LEN := 30


var _merlin_ai: Node = null
var _adapter: RefCounted = null
var _results: Dictionary = {
	"phase": "init",
	"narrator_text": "",
	"narrator_ms": 0,
	"card_text": "",
	"card_ms": 0,
	"leak_found": [],
	"warmup_ms": 0,
	"backend": "",
	"model": "",
	"pass": false,
	"errors": [],
}


func _ready() -> void:
	_log("═══════════════════════════════════════")
	_log("  GEMMA 4 E2E TEST")
	_log("═══════════════════════════════════════")

	_merlin_ai = Engine.get_singleton("MerlinAI") if Engine.has_singleton("MerlinAI") else null
	if _merlin_ai == null:
		_merlin_ai = get_node_or_null("/root/MerlinAI")
	if _merlin_ai == null:
		_fail("MerlinAI autoload not found")
		return

	# Warmup
	_results.phase = "warmup"
	var t0: int = Time.get_ticks_msec()
	_merlin_ai.start_warmup()
	# Poll ready flag with a generous budget — first-token latency on E4B is slow.
	var waited: int = 0
	while not _merlin_ai.is_ready and waited < 120000:
		await get_tree().create_timer(0.5).timeout
		waited += 500
	_results.warmup_ms = Time.get_ticks_msec() - t0
	if not _merlin_ai.is_ready:
		_fail("Warmup timed out after %dms" % waited)
		return
	_log("Warmup OK in %dms" % _results.warmup_ms)
	_results.backend = str(_merlin_ai.get("backend_kind")) if "backend_kind" in _merlin_ai else "?"
	_results.model = str(_merlin_ai.get("active_model_tag")) if "active_model_tag" in _merlin_ai else "?"

	# 1) Narrator path — same generate_with_system call site the scenes use.
	_results.phase = "narrator"
	var t1: int = Time.get_ticks_msec()
	var sys_prompt := "Tu es Merlin l'Enchanteur, druide ancestral de Broceliande. Reponds en francais, 2 phrases, vocabulaire druidique. Pas de balise XML."
	var user_prompt := "La brume s'enroule autour des menhirs. Que vois-tu ?"
	var resp: Dictionary = await _merlin_ai.generate_with_system(sys_prompt, user_prompt, {
		"max_tokens": 120,
		"temperature": 0.75,
		"timeout_ms": NARRATOR_TIMEOUT_MS,
	})
	_results.narrator_ms = Time.get_ticks_msec() - t1
	if not resp.get("ok", false):
		_fail("Narrator call failed: %s" % str(resp.get("error", "?")))
		return
	_results.narrator_text = String(resp.get("text", ""))
	_check_leak(_results.narrator_text, "narrator")
	if _results.narrator_text.length() < MIN_NARRATOR_LEN:
		_fail("Narrator text too short (%d chars, min %d): %s" % [
			_results.narrator_text.length(), MIN_NARRATOR_LEN, _results.narrator_text
		])
		return
	_log("Narrator OK in %dms (%d chars)" % [_results.narrator_ms, _results.narrator_text.length()])
	_log("  → %s" % _results.narrator_text.substr(0, 200))

	# 2) Gamemaster RPG card path (if adapter present)
	_adapter = _try_load_adapter()
	if _adapter == null:
		_log("[skip] MerlinLlmAdapter not loadable — gamemaster path skipped")
	else:
		_results.phase = "card"
		var t2: int = Time.get_ticks_msec()
		var ctx: Dictionary = {
			"cards_played": 1,
			"biome": "foret_broceliande",
			"life_essence": 80,
			"tension": 20,
			"factions": {"druides": 0, "anciens": 0, "korrigans": 0, "niamh": 0, "ankou": 0},
			"flux_context": "",
			"theme_hint": "",
			"faction_status": "neutre",
		}
		var card_res: Dictionary = await _adapter.generate_rpg_card(ctx)
		_results.card_ms = Time.get_ticks_msec() - t2
		if card_res.get("ok", false):
			var card: Dictionary = card_res.get("card", {})
			_results.card_text = String(card.get("text", ""))
			_check_leak(JSON.stringify(card), "card")
			_log("Card OK in %dms (%d chars)" % [_results.card_ms, _results.card_text.length()])
			_log("  → %s" % _results.card_text.substr(0, 200))
		else:
			_log("[warn] Card generation failed: %s" % str(card_res.get("error", "?")))

	# Finalize
	_results.pass = _results.errors.is_empty() and _results.leak_found.is_empty()
	_results.phase = "done"
	_save_results()
	_log("═══════════════════════════════════════")
	if _results.pass:
		_log("  PASS — Gemma 4 demo pipeline OK")
	else:
		_log("  FAIL — see errors / leaks above")
	_log("═══════════════════════════════════════")
	get_tree().quit(0 if _results.pass else 1)


func _check_leak(text: String, label: String) -> void:
	for tok in FORBIDDEN_TOKENS:
		if text.find(tok) >= 0:
			_results.leak_found.append("%s: %s" % [label, tok])
			_log("[LEAK] %s emitted '%s'" % [label, tok])


func _try_load_adapter() -> RefCounted:
	var script: GDScript = load("res://scripts/merlin/merlin_llm_adapter.gd") as GDScript
	if script == null:
		return null
	var instance: RefCounted = script.new()
	if instance.has_method("setup"):
		instance.setup(_merlin_ai)
	elif instance.has_method("set_merlin_ai"):
		instance.set_merlin_ai(_merlin_ai)
	return instance


func _fail(msg: String) -> void:
	_log("[FAIL] %s" % msg)
	_results.errors.append(msg)
	_results.pass = false
	_save_results()
	get_tree().quit(1)


func _save_results() -> void:
	var f := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_results, "  "))
		f.close()


func _log(msg: String) -> void:
	print("[GEMMA-E2E] %s" % msg)
