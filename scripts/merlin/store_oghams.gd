## ═══════════════════════════════════════════════════════════════════════════════
## Store Oghams — Ogham activation, effects, cooldowns, economy
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_store.gd — pure delegation, no behavior changes.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name StoreOghams


## Activate an Ogham skill and apply cooldown. Returns result dict.
## Caller must emit ogham_activated signal and call apply_ogham_effect.
static func use_ogham(state: Dictionary, skill_id: String) -> Dictionary:
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(skill_id, {})
	if spec.is_empty():
		return {"ok": false, "error": "Unknown ogham: " + skill_id}

	var oghams: Dictionary = state.get("oghams", {})
	var cooldowns: Dictionary = oghams.get("skill_cooldowns", {})
	var remaining: int = int(cooldowns.get(skill_id, 0))
	if remaining > 0:
		return {"ok": false, "error": "On cooldown", "remaining": remaining}

	var unlocked: Array = oghams.get("skills_unlocked", [])
	var is_starter: bool = bool(spec.get("starter", false))
	if not is_starter and not unlocked.has(skill_id):
		return {"ok": false, "error": "Skill not unlocked"}

	cooldowns[skill_id] = int(spec.get("cooldown", 3))
	oghams["skill_cooldowns"] = cooldowns
	state["oghams"] = oghams

	return {
		"ok": true,
		"skill_id": skill_id,
		"effect": spec.get("effect", ""),
		"spec": spec,
	}


## Apply the actual Ogham effect on the game state.
## heal_func: Callable that takes (amount: int) -> Dictionary
## Protection/modifier oghams (block_first_negative, cancel_all_negatives, reduce_high_damage,
## double_positives, invert_effects) are handled at step 8 of MerlinEffectEngine.process_card()
## via _filter_protection() — they need no state mutation here.
static func apply_ogham_effect(_skill_id: String, spec: Dictionary, state: Dictionary, heal_func: Callable) -> void:
	var effect_id: String = str(spec.get("effect", ""))
	var params: Dictionary = spec.get("effect_params", {})
	match effect_id:
		"heal_immediate":
			heal_func.call(int(params.get("amount", 10)))
		"heal_and_cost":
			heal_func.call(int(params.get("heal", 18)))
			var run: Dictionary = state.get("run", {})
			var currency: int = int(run.get("biome_currency", 0))
			run["biome_currency"] = maxi(0, currency - int(params.get("currency_cost", 5)))
			state["run"] = run
		"add_biome_currency":
			var run: Dictionary = state.get("run", {})
			var currency: int = int(run.get("biome_currency", 0))
			run["biome_currency"] = currency + int(params.get("amount", 10))
			state["run"] = run
		"currency_and_heal":
			heal_func.call(int(params.get("heal", 3)))
			var run: Dictionary = state.get("run", {})
			var currency: int = int(run.get("biome_currency", 0))
			run["biome_currency"] = currency + int(params.get("currency", 8))
			state["run"] = run
		"block_first_negative", "cancel_all_negatives", "reduce_high_damage", \
		"double_positives", "invert_effects", \
		"reveal_one_option", "reveal_all_options", "predict_next", \
		"replace_worst_option", "regenerate_all_options", "full_reroll", "force_twist", "sacrifice_trade":
			pass


## Decrement all Ogham cooldowns by 1. Call after each card resolved.
static func tick_cooldowns(state: Dictionary) -> void:
	var oghams: Dictionary = state.get("oghams", {})
	var cooldowns: Dictionary = oghams.get("skill_cooldowns", {})
	var to_remove: Array = []
	for skill_id in cooldowns:
		cooldowns[skill_id] = maxi(int(cooldowns[skill_id]) - 1, 0)
		if int(cooldowns[skill_id]) <= 0:
			to_remove.append(skill_id)
	for skill_id in to_remove:
		cooldowns.erase(skill_id)
	oghams["skill_cooldowns"] = cooldowns
	state["oghams"] = oghams


static func can_use_ogham(state: Dictionary, skill_id: String) -> bool:
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(skill_id, {})
	if spec.is_empty():
		return false
	var oghams: Dictionary = state.get("oghams", {})
	var cooldowns: Dictionary = oghams.get("skill_cooldowns", {})
	if int(cooldowns.get(skill_id, 0)) > 0:
		return false
	var is_starter: bool = bool(spec.get("starter", false))
	if not is_starter:
		var unlocked: Array = oghams.get("skills_unlocked", [])
		if not unlocked.has(skill_id):
			return false
	return true


static func get_available_oghams(state: Dictionary) -> Array:
	var available: Array = []
	for skill_id in MerlinConstants.OGHAM_FULL_SPECS:
		if can_use_ogham(state, skill_id):
			available.append(skill_id)
	return available


## Get effective Ogham cost (with discovery discount).
static func get_ogham_cost(state: Dictionary, ogham_id: String) -> int:
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
	var base_cost: int = int(spec.get("cost_anam", 0))
	var discounts: Dictionary = state.get("meta", {}).get("ogham_discounts", {})
	if discounts.has(ogham_id):
		return int(discounts[ogham_id])
	return base_cost


static func apply_ogham_discount(state: Dictionary, ogham_id: String) -> void:
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
	var base_cost: int = int(spec.get("cost_anam", 0))
	var meta: Dictionary = state.get("meta", {})
	var discounts: Dictionary = meta.get("ogham_discounts", {})
	discounts[ogham_id] = int(float(base_cost) * 0.5)
	meta["ogham_discounts"] = discounts
	state["meta"] = meta


static func buy_ogham(state: Dictionary, ogham_id: String, save_system: MerlinSaveSystem) -> Dictionary:
	var meta: Dictionary = state.get("meta", {})
	var oghams: Dictionary = meta.get("oghams", {})
	var owned: Array = oghams.get("owned", [])
	if owned.has(ogham_id):
		return {"ok": false, "error": "already_owned"}
	var cost: int = get_ogham_cost(state, ogham_id)
	var anam: int = int(meta.get("anam", 0))
	if anam < cost:
		return {"ok": false, "error": "insufficient_anam"}
	meta["anam"] = anam - cost
	owned.append(ogham_id)
	oghams["owned"] = owned
	meta["oghams"] = oghams
	state["meta"] = meta
	save_system.save_profile(meta)
	return {"ok": true, "ogham_id": ogham_id, "cost": cost}
