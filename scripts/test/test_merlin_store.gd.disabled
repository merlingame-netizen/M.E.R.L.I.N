## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinStore v2.5
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: life_essence, ogham activation, run lifecycle, anam rewards,
## faction reputation delta, talent unlocking.
## ═══════════════════════════════════════════════════════════════════════════════

extends GutTest

var store: Node


func before_each() -> void:
	store = preload("res://scripts/merlin/merlin_store.gd").new()
	add_child(store)
	if store.has_method("dispatch"):
		store.dispatch({"type": "START_RUN", "biome": "foret_broceliande", "ogham": "beith"})


func after_each() -> void:
	if is_instance_valid(store):
		store.queue_free()
	store = null


# ═══════════════════════════════════════════════════════════════════════════════
# LIFE ESSENCE
# ═══════════════════════════════════════════════════════════════════════════════

func test_life_essence_initial_value() -> void:
	var run: Dictionary = store.state.get("run", {})
	var life: int = int(run.get("life_essence", -1))
	assert_eq(life, MerlinConstants.LIFE_ESSENCE_START, "Life should start at LIFE_ESSENCE_START")


func test_heal_life_clamped_at_max() -> void:
	if not store.has_method("_heal_life"):
		pending("_heal_life not exposed")
		return
	# Set life to max - 5
	store.state["run"]["life_essence"] = MerlinConstants.LIFE_ESSENCE_MAX - 5
	store._heal_life(20)
	var life: int = int(store.state["run"].get("life_essence", 0))
	assert_eq(life, MerlinConstants.LIFE_ESSENCE_MAX, "Life should be clamped at max")


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM ACTIVATION
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_activation_sets_cooldown() -> void:
	if not store.has_method("activate_ogham"):
		pending("activate_ogham not exposed")
		return
	var result: Dictionary = store.activate_ogham("beith")
	assert_true(result.get("ok", false), "Ogham activation should succeed")
	var oghams: Dictionary = store.state.get("oghams", {})
	var cd: int = int(oghams.get("cooldowns", {}).get("beith", 0))
	assert_gt(cd, 0, "Cooldown should be set after activation")


func test_ogham_on_cooldown_rejected() -> void:
	if not store.has_method("activate_ogham"):
		pending("activate_ogham not exposed")
		return
	store.activate_ogham("beith")
	var result: Dictionary = store.activate_ogham("beith")
	assert_false(result.get("ok", true), "Second activation should fail (on cooldown)")


func test_tick_cooldowns_decrements() -> void:
	if not store.has_method("tick_cooldowns"):
		pending("tick_cooldowns not exposed")
		return
	if store.has_method("activate_ogham"):
		store.activate_ogham("beith")
	var oghams: Dictionary = store.state.get("oghams", {})
	var before: int = int(oghams.get("cooldowns", {}).get("beith", 0))
	store.tick_cooldowns()
	var after: int = int(oghams.get("cooldowns", {}).get("beith", 0))
	assert_lt(after, before, "Cooldown should decrease after tick")


# ═══════════════════════════════════════════════════════════════════════════════
# ANAM REWARDS
# ═══════════════════════════════════════════════════════════════════════════════

func test_calculate_run_rewards_base() -> void:
	if not store.has_method("calculate_run_rewards"):
		pending("calculate_run_rewards not exposed")
		return
	var run_data: Dictionary = {
		"cards_played": 10,
		"minigames_won": 0,
		"faction_rep_delta": {},
		"reason": "death",
	}
	var result: Dictionary = store.calculate_run_rewards(run_data)
	assert_true(result.has("anam"), "Result should have anam")
	assert_gte(int(result.get("anam", 0)), MerlinConstants.ANAM_BASE_REWARD, "Base reward at minimum")


func test_calculate_run_rewards_with_minigames() -> void:
	if not store.has_method("calculate_run_rewards"):
		pending("calculate_run_rewards not exposed")
		return
	var run_data: Dictionary = {
		"cards_played": 15,
		"minigames_won": 5,
		"faction_rep_delta": {},
		"reason": "convergence",
	}
	var result: Dictionary = store.calculate_run_rewards(run_data)
	var anam: int = int(result.get("anam", 0))
	var expected_min: int = MerlinConstants.ANAM_BASE_REWARD + MerlinConstants.ANAM_VICTORY_BONUS + 5 * MerlinConstants.ANAM_PER_MINIGAME
	assert_gte(anam, expected_min, "Victory + minigames should give more anam")


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT ENGINE — scale_and_cap
# ═══════════════════════════════════════════════════════════════════════════════

func test_scale_and_cap_positive_multiplier() -> void:
	var result: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 10, 1.5)
	assert_eq(result, 15, "10 * 1.5 = 15")


func test_scale_and_cap_negative_multiplier() -> void:
	var result: int = MerlinEffectEngine.scale_and_cap("DAMAGE_LIFE", 5, -1.0)
	assert_eq(result, -5, "5 * -1.0 = -5 (negative multiplier inverts)")


func test_scale_and_cap_zero() -> void:
	var result: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 0, 1.5)
	assert_eq(result, 0, "0 * anything = 0")


func test_get_multiplier_echec_critique() -> void:
	var result: float = MerlinEffectEngine.get_multiplier(0)
	assert_lt(result, 0.0, "Score 0 should give negative multiplier (echec critique)")


func test_get_multiplier_reussite() -> void:
	var result: float = MerlinEffectEngine.get_multiplier(80)
	assert_gt(result, 0.5, "Score 80 should give positive multiplier >= 0.5")


func test_get_multiplier_triomphe() -> void:
	var result: float = MerlinEffectEngine.get_multiplier(95)
	assert_gte(result, 1.5, "Score 95 should give triomphe multiplier >= 1.5")


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT ENGINE — validate + apply
# ═══════════════════════════════════════════════════════════════════════════════

func test_effect_engine_validate_valid() -> void:
	var engine: MerlinEffectEngine = MerlinEffectEngine.new()
	assert_true(engine.validate_effect("HEAL_LIFE:5"), "HEAL_LIFE:5 should be valid")
	assert_true(engine.validate_effect("ADD_REPUTATION:druides:10"), "ADD_REPUTATION:druides:10 should be valid")
	assert_true(engine.validate_effect("CREATE_PROMISE:oath_001:5:desc"), "CREATE_PROMISE should be valid")


func test_effect_engine_validate_invalid() -> void:
	var engine: MerlinEffectEngine = MerlinEffectEngine.new()
	assert_false(engine.validate_effect("FAKE_EFFECT:1"), "Unknown effect should be invalid")
	assert_false(engine.validate_effect("HEAL_LIFE"), "Missing args should be invalid")
	assert_false(engine.validate_effect("ADD_REPUTATION:druides"), "Missing second arg should be invalid")


func test_effect_engine_apply_heal() -> void:
	var engine: MerlinEffectEngine = MerlinEffectEngine.new()
	var state: Dictionary = {"run": {"life_essence": 50, "life_max": 100}}
	var result: Dictionary = engine.apply_effects(state, ["HEAL_LIFE:10"], "TEST")
	assert_eq(result["applied"].size(), 1, "Should apply 1 effect")
	assert_eq(result["rejected"].size(), 0, "No rejected effects")


func test_effect_engine_apply_damage() -> void:
	var engine: MerlinEffectEngine = MerlinEffectEngine.new()
	var state: Dictionary = {"run": {"life_essence": 50, "life_max": 100}}
	var result: Dictionary = engine.apply_effects(state, ["DAMAGE_LIFE:10"], "TEST")
	assert_eq(result["applied"].size(), 1, "Should apply 1 effect")
	var life: int = int(state.get("run", {}).get("life_essence", 0))
	assert_eq(life, 40, "Life should be 50 - 10 = 40")


func test_effect_engine_apply_reputation() -> void:
	var engine: MerlinEffectEngine = MerlinEffectEngine.new()
	var state: Dictionary = {"run": {"faction_rep": {"druides": 10.0}}}
	var result: Dictionary = engine.apply_effects(state, ["ADD_REPUTATION:druides:15"], "TEST")
	assert_eq(result["applied"].size(), 1, "Should apply 1 effect")


# ═══════════════════════════════════════════════════════════════════════════════
# TUTORIAL MANAGER
# ═══════════════════════════════════════════════════════════════════════════════

func test_tutorial_first_run_injects() -> void:
	var tm: TutorialManager = TutorialManager.new()
	tm.setup({"total_runs": 0})
	assert_true(tm.is_first_run(), "Should be first run with total_runs=0")
	assert_true(tm.should_inject_tutorial_card(0), "Should inject card 0 on first run")
	assert_true(tm.should_inject_tutorial_card(1), "Should inject card 1 on first run")
	assert_true(tm.should_inject_tutorial_card(2), "Should inject card 2 on first run")
	assert_false(tm.should_inject_tutorial_card(3), "Should NOT inject card 3 (only 3 tutorial cards)")


func test_tutorial_not_first_run() -> void:
	var tm: TutorialManager = TutorialManager.new()
	tm.setup({"total_runs": 5})
	assert_false(tm.is_first_run(), "Should not be first run with total_runs=5")
	assert_false(tm.should_inject_tutorial_card(0), "Should not inject on non-first run")


func test_tutorial_tooltip_shown_once() -> void:
	var tm: TutorialManager = TutorialManager.new()
	tm.setup({"total_runs": 0})
	var shown1: bool = tm.show_tooltip("choose_option")
	assert_true(shown1, "First show should succeed")
	var shown2: bool = tm.show_tooltip("choose_option")
	assert_false(shown2, "Second show should fail (already shown)")


func test_tutorial_tooltip_persisted_in_flags() -> void:
	var tm: TutorialManager = TutorialManager.new()
	tm.setup({"total_runs": 0})
	tm.show_tooltip("choose_option")
	tm.show_tooltip("ogham_activation")
	var flags: Dictionary = tm.get_tutorial_flags()
	assert_true(flags.get("choose_option", false), "Flag should be set")
	assert_true(flags.get("ogham_activation", false), "Flag should be set")
	assert_false(flags.get("minigame_intro", false), "Unseen tooltip flag should be false")


func test_tutorial_contextual_tooltip() -> void:
	var tm: TutorialManager = TutorialManager.new()
	tm.setup({"total_runs": 0})
	assert_true(tm.try_contextual_tooltip("promise_card"), "promise_card context should show tooltip")
	assert_false(tm.try_contextual_tooltip("promise_card"), "Second call should return false")
	assert_true(tm.try_contextual_tooltip("life_low"), "life_low context should show tooltip")


func test_tutorial_get_card_returns_valid() -> void:
	var tm: TutorialManager = TutorialManager.new()
	tm.setup({"total_runs": 0})
	var card: Dictionary = tm.get_tutorial_card(0)
	assert_false(card.is_empty(), "Card should not be empty")
	assert_eq(str(card.get("id", "")), "tutorial_001", "First card should be tutorial_001")
	var options: Array = card.get("options", [])
	assert_eq(options.size(), 3, "Tutorial card should have 3 options")


func test_tutorial_get_card_out_of_bounds() -> void:
	var tm: TutorialManager = TutorialManager.new()
	tm.setup({"total_runs": 0})
	var card: Dictionary = tm.get_tutorial_card(99)
	assert_true(card.is_empty(), "Out of bounds card should be empty")


func test_tutorial_save_to_profile() -> void:
	var tm: TutorialManager = TutorialManager.new()
	tm.setup({"total_runs": 0})
	tm.show_tooltip("choose_option")
	var profile: Dictionary = {}
	tm.save_to_profile(profile)
	assert_true(profile.has("tutorial_flags"), "Profile should have tutorial_flags")
	assert_true(profile["tutorial_flags"].get("choose_option", false), "Flag should be persisted")
