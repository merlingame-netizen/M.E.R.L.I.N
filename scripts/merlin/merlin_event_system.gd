extends RefCounted
class_name MerlinEventSystem

var _action_resolver: MerlinActionResolver
var _minigame: MerlinMiniGameSystem
var _effects: MerlinEffectEngine
var _llm: MerlinLlmAdapter

func setup(action_resolver: MerlinActionResolver, minigame: MerlinMiniGameSystem, effects: MerlinEffectEngine, llm: MerlinLlmAdapter) -> void:
	_action_resolver = action_resolver
	_minigame = minigame
	_effects = effects
	_llm = llm


func run_scene(scene: Dictionary, verb: String, choice_index: int, state: Dictionary) -> Dictionary:
	var validation = _llm.validate_scene(scene, _effects)
	if not validation["ok"]:
		return {"ok": false, "errors": validation["errors"]}

	var clean_scene = validation["scene"]
	var choices = clean_scene["choices"].get(verb, [])
	if choice_index < 0 or choice_index >= choices.size():
		return {"ok": false, "errors": ["Choice index out of range"]}

	var choice = choices[choice_index]
	var resolution = _action_resolver.resolve(verb, choice.get("label", ""), {
		"state": state,
		"hidden_test": choice.get("hidden_test", {}),
		"merlin_style": choice.get("merlin_style", ""),
		"costs": choice.get("costs", {}),
		"gain": choice.get("gain", []),
	})

	var test = resolution["hidden_test"]
	var outcome = _minigame.run(str(test.get("type", "DICE")), int(test.get("difficulty", 5)), test.get("modifiers", {}))
	var success = bool(outcome["success"])

	var run = state.get("run", {})
	if run.get("force_soft_success", false) and not success:
		success = true
		outcome["soft_success"] = true
		run["force_soft_success"] = false
		state["run"] = run

	var effects_list = choice.get("on_success", []) if success else choice.get("on_fail", [])
	var apply_result = _effects.apply_effects(state, effects_list, "LLM")

	_update_fail_streak(state, success)
	_reset_one_shot_mods(state)

	return {
		"ok": true,
		"scene_id": clean_scene.get("scene_id", ""),
		"resolution": resolution,
		"outcome": outcome,
		"effects": apply_result,
	}


func _update_fail_streak(state: Dictionary, success: bool) -> void:
	var run = state.get("run", {})
	if success:
		run["fail_streak"] = 0
	else:
		run["fail_streak"] = int(run.get("fail_streak", 0)) + 1
	state["run"] = run


func _reset_one_shot_mods(state: Dictionary) -> void:
	var run = state.get("run", {})
	run["difficulty_mod_next"] = 0
	state["run"] = run
