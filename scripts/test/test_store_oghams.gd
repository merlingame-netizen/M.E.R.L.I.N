## =============================================================================
## Unit Tests — StoreOghams
## =============================================================================
## Tests: use_ogham, can_use_ogham, get_available_oghams, tick_cooldowns,
## apply_ogham_effect, get_ogham_cost, apply_ogham_discount, buy_ogham.
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted


func _make_state(overrides: Dictionary = {}) -> Dictionary:
	var state: Dictionary = {
		"oghams": {
			"skills_unlocked": [],
			"skill_cooldowns": {},
		},
		"run": {
			"biome_currency": 0,
			"effect_modifier": {},
		},
		"meta": {
			"anam": 0,
			"oghams": {"owned": []},
			"ogham_discounts": {},
		},
	}
	for key in overrides:
		state[key] = overrides[key]
	return state


func _make_state_with_unlocked(skill_ids: Array) -> Dictionary:
	var state: Dictionary = _make_state()
	state["oghams"]["skills_unlocked"] = skill_ids.duplicate()
	return state


# =============================================================================
# USE OGHAM — starter oghams (no unlock needed)
# =============================================================================

func test_use_starter_ogham_ok() -> bool:
	var state: Dictionary = _make_state()
	var result: Dictionary = StoreOghams.use_ogham(state, "beith")
	if not bool(result.get("ok", false)):
		push_error("use_ogham starter 'beith' should succeed, got error: %s" % result.get("error", ""))
		return false
	if str(result.get("skill_id", "")) != "beith":
		push_error("use_ogham: skill_id should be 'beith', got '%s'" % result.get("skill_id", ""))
		return false
	return true


func test_use_starter_sets_cooldown() -> bool:
	var state: Dictionary = _make_state()
	StoreOghams.use_ogham(state, "beith")
	var cd: int = int(state["oghams"]["skill_cooldowns"].get("beith", 0))
	# beith has cooldown: 3
	if cd != 3:
		push_error("use_ogham: beith cooldown should be 3, got %d" % cd)
		return false
	return true


func test_use_ogham_on_cooldown_fails() -> bool:
	var state: Dictionary = _make_state()
	StoreOghams.use_ogham(state, "beith")
	var result: Dictionary = StoreOghams.use_ogham(state, "beith")
	if bool(result.get("ok", true)):
		push_error("use_ogham on cooldown should fail")
		return false
	if str(result.get("error", "")) != "On cooldown":
		push_error("use_ogham on cooldown: expected 'On cooldown', got '%s'" % result.get("error", ""))
		return false
	return true


func test_use_unknown_ogham_fails() -> bool:
	var state: Dictionary = _make_state()
	var result: Dictionary = StoreOghams.use_ogham(state, "nonexistent_ogham")
	if bool(result.get("ok", true)):
		push_error("use_ogham unknown should fail")
		return false
	if not str(result.get("error", "")).begins_with("Unknown ogham"):
		push_error("use_ogham unknown: error should start with 'Unknown ogham'")
		return false
	return true


func test_use_locked_non_starter_fails() -> bool:
	var state: Dictionary = _make_state()
	# "coll" is not a starter and not unlocked
	var result: Dictionary = StoreOghams.use_ogham(state, "coll")
	if bool(result.get("ok", true)):
		push_error("use_ogham locked non-starter should fail")
		return false
	if str(result.get("error", "")) != "Skill not unlocked":
		push_error("use_ogham locked: expected 'Skill not unlocked', got '%s'" % result.get("error", ""))
		return false
	return true


func test_use_unlocked_non_starter_ok() -> bool:
	var state: Dictionary = _make_state_with_unlocked(["coll"])
	var result: Dictionary = StoreOghams.use_ogham(state, "coll")
	if not bool(result.get("ok", false)):
		push_error("use_ogham unlocked 'coll' should succeed, got error: %s" % result.get("error", ""))
		return false
	return true


func test_use_ogham_returns_effect_and_spec() -> bool:
	var state: Dictionary = _make_state()
	var result: Dictionary = StoreOghams.use_ogham(state, "quert")
	if str(result.get("effect", "")) != "heal_immediate":
		push_error("use_ogham quert: effect should be 'heal_immediate', got '%s'" % result.get("effect", ""))
		return false
	if result.get("spec", {}).is_empty():
		push_error("use_ogham quert: spec should not be empty")
		return false
	return true


# =============================================================================
# CAN USE OGHAM
# =============================================================================

func test_can_use_starter_available() -> bool:
	var state: Dictionary = _make_state()
	if not StoreOghams.can_use_ogham(state, "luis"):
		push_error("can_use_ogham: starter 'luis' should be available")
		return false
	return true


func test_can_use_ogham_on_cooldown_false() -> bool:
	var state: Dictionary = _make_state()
	state["oghams"]["skill_cooldowns"]["luis"] = 2
	if StoreOghams.can_use_ogham(state, "luis"):
		push_error("can_use_ogham: 'luis' on cooldown should return false")
		return false
	return true


func test_can_use_ogham_unknown_false() -> bool:
	var state: Dictionary = _make_state()
	if StoreOghams.can_use_ogham(state, "fake_ogham_xyz"):
		push_error("can_use_ogham: unknown ogham should return false")
		return false
	return true


# =============================================================================
# GET AVAILABLE OGHAMS
# =============================================================================

func test_get_available_returns_starters() -> bool:
	var state: Dictionary = _make_state()
	var available: Array = StoreOghams.get_available_oghams(state)
	# Starters: beith, luis, quert
	for starter_id in ["beith", "luis", "quert"]:
		if not available.has(starter_id):
			push_error("get_available_oghams: starter '%s' should be available" % starter_id)
			return false
	return true


func test_get_available_excludes_cooldown() -> bool:
	var state: Dictionary = _make_state()
	state["oghams"]["skill_cooldowns"]["beith"] = 2
	var available: Array = StoreOghams.get_available_oghams(state)
	if available.has("beith"):
		push_error("get_available_oghams: 'beith' on cooldown should not be available")
		return false
	return true


# =============================================================================
# TICK COOLDOWNS
# =============================================================================

func test_tick_cooldowns_decrements() -> bool:
	var state: Dictionary = _make_state()
	state["oghams"]["skill_cooldowns"]["beith"] = 3
	state["oghams"]["skill_cooldowns"]["luis"] = 1
	StoreOghams.tick_cooldowns(state)
	var cds: Dictionary = state["oghams"]["skill_cooldowns"]
	# beith: 3 -> 2 (remains), luis: 1 -> 0 (removed)
	if int(cds.get("beith", -1)) != 2:
		push_error("tick_cooldowns: beith should be 2, got %d" % int(cds.get("beith", -1)))
		return false
	if cds.has("luis"):
		push_error("tick_cooldowns: luis at 0 should be removed")
		return false
	return true


func test_tick_cooldowns_empty_state() -> bool:
	var state: Dictionary = _make_state()
	StoreOghams.tick_cooldowns(state)
	var cds: Dictionary = state["oghams"]["skill_cooldowns"]
	if not cds.is_empty():
		push_error("tick_cooldowns empty: should remain empty")
		return false
	return true


# =============================================================================
# APPLY OGHAM EFFECT — heal_immediate
# =============================================================================

func test_effect_heal_immediate() -> bool:
	var state: Dictionary = _make_state()
	var tracker: Dictionary = {"healed": 0}
	var heal_func: Callable = func(amount: int) -> Dictionary:
		tracker["healed"] = amount
		return {"ok": true}
	var spec: Dictionary = {"effect": "heal_immediate", "effect_params": {"amount": 12}}
	StoreOghams.apply_ogham_effect("duir", spec, state, heal_func)
	if int(tracker["healed"]) != 12:
		push_error("effect heal_immediate: should heal 12, healed %d" % int(tracker["healed"]))
		return false
	return true


# =============================================================================
# APPLY OGHAM EFFECT — block_first_negative
# =============================================================================

func test_effect_block_first_negative() -> bool:
	var state: Dictionary = _make_state()
	var heal_func: Callable = func(_amount: int) -> Dictionary: return {}
	var spec: Dictionary = {"effect": "block_first_negative", "effect_params": {"count": 1}}
	StoreOghams.apply_ogham_effect("luis", spec, state, heal_func)
	var shield: bool = bool(state["run"]["effect_modifier"].get("shield_next_negative", false))
	if not shield:
		push_error("effect block_first_negative: shield_next_negative should be true")
		return false
	return true


# =============================================================================
# APPLY OGHAM EFFECT — add_biome_currency
# =============================================================================

func test_effect_add_biome_currency() -> bool:
	var state: Dictionary = _make_state()
	state["run"]["biome_currency"] = 5
	var heal_func: Callable = func(_amount: int) -> Dictionary: return {}
	var spec: Dictionary = {"effect": "add_biome_currency", "effect_params": {"amount": 10}}
	StoreOghams.apply_ogham_effect("onn", spec, state, heal_func)
	var currency: int = int(state["run"]["biome_currency"])
	if currency != 15:
		push_error("effect add_biome_currency: expected 15, got %d" % currency)
		return false
	return true


# =============================================================================
# APPLY OGHAM EFFECT — heal_and_cost
# =============================================================================

func test_effect_heal_and_cost() -> bool:
	var state: Dictionary = _make_state()
	state["run"]["biome_currency"] = 20
	var tracker: Dictionary = {"healed": 0}
	var heal_func: Callable = func(amount: int) -> Dictionary:
		tracker["healed"] = amount
		return {"ok": true}
	var spec: Dictionary = {"effect": "heal_and_cost", "effect_params": {"heal": 18, "currency_cost": 5}}
	StoreOghams.apply_ogham_effect("ruis", spec, state, heal_func)
	if int(tracker["healed"]) != 18:
		push_error("effect heal_and_cost: should heal 18, healed %d" % int(tracker["healed"]))
		return false
	var currency: int = int(state["run"]["biome_currency"])
	if currency != 15:
		push_error("effect heal_and_cost: currency should be 15, got %d" % currency)
		return false
	return true


# =============================================================================
# APPLY OGHAM EFFECT — double_positives modifier
# =============================================================================

func test_effect_double_positives() -> bool:
	var state: Dictionary = _make_state()
	var heal_func: Callable = func(_amount: int) -> Dictionary: return {}
	var spec: Dictionary = {"effect": "double_positives", "effect_params": {"multiplier": 2.0}}
	StoreOghams.apply_ogham_effect("tinne", spec, state, heal_func)
	var dp: bool = bool(state["run"]["effect_modifier"].get("double_positive", false))
	if not dp:
		push_error("effect double_positives: double_positive modifier should be true")
		return false
	return true


# =============================================================================
# GET OGHAM COST / DISCOUNT
# =============================================================================

func test_get_ogham_cost_base() -> bool:
	var state: Dictionary = _make_state()
	var cost: int = StoreOghams.get_ogham_cost(state, "coll")
	# coll cost_anam = 80
	if cost != 80:
		push_error("get_ogham_cost coll: expected 80, got %d" % cost)
		return false
	return true


func test_apply_discount_halves_cost() -> bool:
	var state: Dictionary = _make_state()
	StoreOghams.apply_ogham_discount(state, "coll")
	var cost: int = StoreOghams.get_ogham_cost(state, "coll")
	# 80 * 0.5 = 40
	if cost != 40:
		push_error("get_ogham_cost after discount: expected 40, got %d" % cost)
		return false
	return true


func test_get_cost_starter_is_zero() -> bool:
	var state: Dictionary = _make_state()
	var cost: int = StoreOghams.get_ogham_cost(state, "beith")
	if cost != 0:
		push_error("get_ogham_cost starter beith: expected 0, got %d" % cost)
		return false
	return true
