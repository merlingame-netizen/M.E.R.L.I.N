extends RefCounted
class_name DruCombatSystem

var _action_resolver: DruActionResolver
var _minigame: DruMiniGameSystem
var _effects: DruEffectEngine
var _rng: DruRng

func setup(action_resolver: DruActionResolver, minigame: DruMiniGameSystem, effects: DruEffectEngine, rng: DruRng) -> void:
	_action_resolver = action_resolver
	_minigame = minigame
	_effects = effects
	_rng = rng


func enter(enemy_pack: Dictionary, state: Dictionary) -> Dictionary:
	var combat = state.get("combat", {})
	combat["enemy"] = enemy_pack.duplicate(true)
	combat["enemy_intent"] = _pick_enemy_intent(enemy_pack)
	state["combat"] = combat
	return combat


func step(verb: String, move: Dictionary, state: Dictionary) -> Dictionary:
	var resolution = _action_resolver.resolve(verb, move.get("name", ""), {
		"state": state,
		"hidden_test": move.get("hidden_test", {}),
		"costs": move.get("cost", {}),
		"gain": move.get("gain", []),
	})

	var test = resolution["hidden_test"]
	var outcome = _minigame.run(str(test.get("type", "DICE")), int(test.get("difficulty", 5)), test.get("modifiers", {}))
	var success = bool(outcome["success"])

	var effects_list = move.get("on_success", []) if success else move.get("on_fail", [])
	var apply_result = _effects.apply_effects(state, effects_list, "PLAYER")

	_update_fail_streak(state, success)
	_reset_one_shot_mods(state)
	_refresh_enemy_intent(state)

	return {
		"ok": true,
		"resolution": resolution,
		"outcome": outcome,
		"effects": apply_result,
		"enemy_intent": state.get("combat", {}).get("enemy_intent", {}),
	}


func exit(state: Dictionary) -> void:
	state["combat"] = {
		"enemy": {},
		"enemy_intent": {},
		"player_statuses": [],
		"enemy_statuses": [],
		"player_buffs": [],
		"enemy_buffs": [],
	}


func _pick_enemy_intent(enemy: Dictionary) -> Dictionary:
	var intents = enemy.get("intents", ["ATTACK", "DEFEND", "SPECIAL"])
	var intent = intents[0] if intents.size() > 0 else "ATTACK"
	if _rng != null and intents.size() > 1:
		intent = intents[_rng.randi_range(0, intents.size() - 1)]
	return {"type": intent}


func _refresh_enemy_intent(state: Dictionary) -> void:
	var combat = state.get("combat", {})
	var enemy = combat.get("enemy", {})
	combat["enemy_intent"] = _pick_enemy_intent(enemy)
	state["combat"] = combat


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
