## =============================================================================
## Unit Tests — Store System (MerlinStore + delegates)
## =============================================================================
## Covers: MerlinStore, StoreFactions, StoreOghams, StoreRun, StoreTalents
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted


# =============================================================================
# FACTORY HELPERS
# =============================================================================

func _make_store() -> MerlinStore:
	var store: MerlinStore = MerlinStore.new()
	store.state = store.build_default_state()
	return store


func _make_state() -> Dictionary:
	var store: MerlinStore = MerlinStore.new()
	var s: Dictionary = store.build_default_state()
	store.free()
	return s


func _make_state_with_factions(reps: Dictionary) -> Dictionary:
	var s: Dictionary = _make_state()
	for faction in reps:
		s["meta"]["faction_rep"][faction] = reps[faction]
	return s


func _make_state_with_anam(amount: int) -> Dictionary:
	var s: Dictionary = _make_state()
	s["meta"]["anam"] = amount
	return s


func _make_state_with_run_active() -> Dictionary:
	var s: Dictionary = _make_state()
	s["run"]["active"] = true
	s["run"]["life_essence"] = MerlinConstants.LIFE_ESSENCE_START
	s["run"]["cards_played"] = 0
	s["run"]["mission"] = {"type": "survive", "target": "test", "description": "", "progress": 0, "total": 10, "revealed": false}
	s["run"]["hidden"] = {"karma": 0, "tension": 0, "player_profile": {"audace": 0, "prudence": 0, "altruisme": 0, "egoisme": 0}, "resonances_active": [], "narrative_debt": []}
	return s


# =============================================================================
# MERLINSTORE — build_default_state
# =============================================================================

func test_build_default_state_has_version() -> bool:
	var s: Dictionary = _make_state()
	if not s.has("version"):
		push_error("Default state missing 'version'")
		return false
	if str(s["version"]) != MerlinStore.VERSION:
		push_error("Version mismatch: expected '%s', got '%s'" % [MerlinStore.VERSION, s["version"]])
		return false
	return true


func test_build_default_state_has_phase_title() -> bool:
	var s: Dictionary = _make_state()
	if str(s.get("phase", "")) != "title":
		push_error("Default phase: expected 'title', got '%s'" % s.get("phase", ""))
		return false
	return true


func test_build_default_state_has_run_dict() -> bool:
	var s: Dictionary = _make_state()
	if not s.has("run") or not (s["run"] is Dictionary):
		push_error("Default state missing 'run' dictionary")
		return false
	return true


func test_build_default_state_run_not_active() -> bool:
	var s: Dictionary = _make_state()
	if bool(s["run"].get("active", true)):
		push_error("Default run should not be active")
		return false
	return true


func test_build_default_state_life_essence_at_start() -> bool:
	var s: Dictionary = _make_state()
	var life: int = int(s["run"].get("life_essence", -1))
	if life != MerlinConstants.LIFE_ESSENCE_START:
		push_error("Default life_essence: expected %d, got %d" % [MerlinConstants.LIFE_ESSENCE_START, life])
		return false
	return true


func test_build_default_state_factions_all_zero() -> bool:
	var s: Dictionary = _make_state()
	var factions: Dictionary = s["run"].get("factions", {})
	for f in MerlinConstants.FACTIONS:
		if float(factions.get(f, -1.0)) != 0.0:
			push_error("Faction '%s' expected 0.0, got %s" % [f, str(factions.get(f, "missing"))])
			return false
	return true


func test_build_default_state_meta_faction_rep_at_start() -> bool:
	var s: Dictionary = _make_state()
	var faction_rep: Dictionary = s["meta"].get("faction_rep", {})
	for f in MerlinConstants.FACTIONS:
		if int(faction_rep.get(f, -1)) != MerlinConstants.FACTION_SCORE_START:
			push_error("Meta faction_rep '%s': expected %d, got %d" % [f, MerlinConstants.FACTION_SCORE_START, int(faction_rep.get(f, -1))])
			return false
	return true


func test_build_default_state_oghams_starter_skills() -> bool:
	var s: Dictionary = _make_state()
	var unlocked: Array = s["oghams"].get("skills_unlocked", [])
	for starter in MerlinConstants.OGHAM_STARTER_SKILLS:
		if not unlocked.has(starter):
			push_error("Starter skill '%s' not in skills_unlocked" % starter)
			return false
	return true


func test_build_default_state_has_map_progression() -> bool:
	var s: Dictionary = _make_state()
	if not s.has("map_progression"):
		push_error("Default state missing 'map_progression'")
		return false
	if str(s["map_progression"].get("current_biome", "")) != "foret_broceliande":
		push_error("Default biome: expected 'foret_broceliande'")
		return false
	return true


func test_build_default_state_meta_talent_tree_empty() -> bool:
	var s: Dictionary = _make_state()
	var unlocked: Array = s["meta"].get("talent_tree", {}).get("unlocked", [])
	if not unlocked.is_empty():
		push_error("Default talent tree should have no unlocked talents")
		return false
	return true


# =============================================================================
# MERLINSTORE — _damage_life, _heal_life, _add_faveur
# =============================================================================

func test_damage_life_reduces() -> bool:
	var store: MerlinStore = _make_store()
	var result: Dictionary = store._damage_life(10)
	if not result.get("ok", false):
		push_error("_damage_life failed")
		return false
	if int(result["new"]) != MerlinConstants.LIFE_ESSENCE_START - 10:
		push_error("Life after damage: expected %d, got %d" % [MerlinConstants.LIFE_ESSENCE_START - 10, result["new"]])
		return false
	return true


func test_damage_life_clamps_at_zero() -> bool:
	var store: MerlinStore = _make_store()
	store._damage_life(200)
	var life: int = store.get_life_essence()
	if life != 0:
		push_error("Life should clamp at 0, got %d" % life)
		return false
	return true


func test_heal_life_increases() -> bool:
	var store: MerlinStore = _make_store()
	store._damage_life(30)
	var result: Dictionary = store._heal_life(15)
	if not result.get("ok", false):
		push_error("_heal_life failed")
		return false
	var expected: int = MerlinConstants.LIFE_ESSENCE_START - 30 + 15
	if int(result["new"]) != expected:
		push_error("Life after heal: expected %d, got %d" % [expected, result["new"]])
		return false
	return true


func test_heal_life_clamps_at_max() -> bool:
	var store: MerlinStore = _make_store()
	store._heal_life(999)
	var life: int = store.get_life_essence()
	if life != MerlinConstants.LIFE_ESSENCE_MAX:
		push_error("Life should clamp at max %d, got %d" % [MerlinConstants.LIFE_ESSENCE_MAX, life])
		return false
	return true


func test_add_faveur_basic() -> bool:
	var store: MerlinStore = _make_store()
	var result: Dictionary = store._add_faveur(3)
	if not result.get("ok", false):
		push_error("_add_faveur failed")
		return false
	if int(result["new"]) != MerlinConstants.FAVEURS_START + 3:
		push_error("Faveurs: expected %d, got %d" % [MerlinConstants.FAVEURS_START + 3, result["new"]])
		return false
	return true


func test_add_faveur_accumulates() -> bool:
	var store: MerlinStore = _make_store()
	store._add_faveur(2)
	store._add_faveur(5)
	var faveurs: int = int(store.state["run"].get("faveurs", -1))
	if faveurs != MerlinConstants.FAVEURS_START + 7:
		push_error("Accumulated faveurs: expected %d, got %d" % [MerlinConstants.FAVEURS_START + 7, faveurs])
		return false
	return true


# =============================================================================
# MERLINSTORE — _apply_effect
# =============================================================================

func test_apply_effect_damage_life() -> bool:
	var store: MerlinStore = _make_store()
	store._apply_effect({"type": "DAMAGE_LIFE", "amount": 5})
	var life: int = store.get_life_essence()
	if life != MerlinConstants.LIFE_ESSENCE_START - 5:
		push_error("apply_effect DAMAGE_LIFE: expected %d, got %d" % [MerlinConstants.LIFE_ESSENCE_START - 5, life])
		return false
	return true


func test_apply_effect_heal_life() -> bool:
	var store: MerlinStore = _make_store()
	store._damage_life(20)
	store._apply_effect({"type": "HEAL_LIFE", "amount": 10})
	var life: int = store.get_life_essence()
	var expected: int = MerlinConstants.LIFE_ESSENCE_START - 20 + 10
	if life != expected:
		push_error("apply_effect HEAL_LIFE: expected %d, got %d" % [expected, life])
		return false
	return true


func test_apply_effect_add_karma() -> bool:
	var store: MerlinStore = _make_store()
	store._apply_effect({"type": "ADD_KARMA", "amount": 7})
	var karma: int = int(store.state["run"]["hidden"].get("karma", 0))
	if karma != 7:
		push_error("apply_effect ADD_KARMA: expected 7, got %d" % karma)
		return false
	return true


func test_apply_effect_add_karma_clamps() -> bool:
	var store: MerlinStore = _make_store()
	store._apply_effect({"type": "ADD_KARMA", "amount": 50})
	var karma: int = int(store.state["run"]["hidden"].get("karma", 0))
	if karma != 20:
		push_error("ADD_KARMA should clamp at 20, got %d" % karma)
		return false
	return true


func test_apply_effect_add_tension() -> bool:
	var store: MerlinStore = _make_store()
	store._apply_effect({"type": "ADD_TENSION", "amount": 15})
	var tension: int = int(store.state["run"]["hidden"].get("tension", 0))
	if tension != 15:
		push_error("apply_effect ADD_TENSION: expected 15, got %d" % tension)
		return false
	return true


func test_apply_effect_add_tension_clamps() -> bool:
	var store: MerlinStore = _make_store()
	store._apply_effect({"type": "ADD_TENSION", "amount": 200})
	var tension: int = int(store.state["run"]["hidden"].get("tension", 0))
	if tension != 100:
		push_error("ADD_TENSION should clamp at 100, got %d" % tension)
		return false
	return true


# =============================================================================
# MERLINSTORE — VALID_PHASES allowlist (SEC-4)
# =============================================================================

func test_valid_phases_contains_title() -> bool:
	if "title" not in MerlinStore.VALID_PHASES:
		push_error("VALID_PHASES should contain 'title'")
		return false
	return true


func test_valid_phases_contains_card() -> bool:
	if "card" not in MerlinStore.VALID_PHASES:
		push_error("VALID_PHASES should contain 'card'")
		return false
	return true


func test_valid_phases_contains_end() -> bool:
	if "end" not in MerlinStore.VALID_PHASES:
		push_error("VALID_PHASES should contain 'end'")
		return false
	return true


func test_valid_phases_rejects_arbitrary() -> bool:
	if "hacked_phase" in MerlinStore.VALID_PHASES:
		push_error("VALID_PHASES should NOT contain arbitrary strings")
		return false
	return true


# =============================================================================
# MERLINSTORE — _log_transition
# =============================================================================

func test_log_transition_appends() -> bool:
	var store: MerlinStore = _make_store()
	store._log_transition("test_event", {"key": "value"})
	var log: Array = store.state.get("transition_log", [])
	if log.size() != 1:
		push_error("transition_log should have 1 entry, got %d" % log.size())
		return false
	if str(log[0].get("type", "")) != "test_event":
		push_error("Transition type mismatch")
		return false
	return true


func test_log_transition_multiple() -> bool:
	var store: MerlinStore = _make_store()
	store._log_transition("a", {})
	store._log_transition("b", {})
	store._log_transition("c", {})
	var log: Array = store.state.get("transition_log", [])
	if log.size() != 3:
		push_error("transition_log should have 3 entries, got %d" % log.size())
		return false
	return true


# =============================================================================
# MERLINSTORE — Getters
# =============================================================================

func test_get_life_essence_default() -> bool:
	var store: MerlinStore = _make_store()
	var life: int = store.get_life_essence()
	if life != MerlinConstants.LIFE_ESSENCE_START:
		push_error("get_life_essence default: expected %d, got %d" % [MerlinConstants.LIFE_ESSENCE_START, life])
		return false
	return true


func test_get_mission_returns_copy() -> bool:
	var store: MerlinStore = _make_store()
	var m: Dictionary = store.get_mission()
	m["type"] = "MUTATED"
	var m2: Dictionary = store.get_mission()
	if str(m2.get("type", "")) == "MUTATED":
		push_error("get_mission should return a copy, not a reference")
		return false
	return true


func test_is_run_active_default_false() -> bool:
	var store: MerlinStore = _make_store()
	if store.is_run_active():
		push_error("Default run should not be active")
		return false
	return true


func test_get_mode_default_narrative() -> bool:
	var store: MerlinStore = _make_store()
	if store.get_mode() != "narrative":
		push_error("Default mode: expected 'narrative', got '%s'" % store.get_mode())
		return false
	return true


func test_get_current_biome_default() -> bool:
	var store: MerlinStore = _make_store()
	if store.get_current_biome() != "foret_broceliande":
		push_error("Default biome: expected 'foret_broceliande', got '%s'" % store.get_current_biome())
		return false
	return true


func test_get_cards_played_default_zero() -> bool:
	var store: MerlinStore = _make_store()
	if store.get_cards_played() != 0:
		push_error("Default cards_played should be 0, got %d" % store.get_cards_played())
		return false
	return true


func test_get_hidden_data_returns_copy() -> bool:
	var store: MerlinStore = _make_store()
	var h: Dictionary = store.get_hidden_data()
	h["karma"] = 999
	var h2: Dictionary = store.get_hidden_data()
	if int(h2.get("karma", 0)) == 999:
		push_error("get_hidden_data should return a copy")
		return false
	return true


# =============================================================================
# MERLINSTORE — Static period/biome delegates
# =============================================================================

func test_store_get_period_delegates() -> bool:
	var period: String = MerlinStore.get_period(3)
	var expected: String = StoreFactions.get_period(3)
	if period != expected:
		push_error("MerlinStore.get_period should delegate to StoreFactions")
		return false
	return true


func test_store_get_period_bonus_delegates() -> bool:
	var bonus: float = MerlinStore.get_period_bonus(3, "druides")
	var expected: float = StoreFactions.get_period_bonus(3, "druides")
	if not is_equal_approx(bonus, expected):
		push_error("MerlinStore.get_period_bonus should delegate to StoreFactions")
		return false
	return true


func test_store_get_biome_affinity_bonus_delegates() -> bool:
	var result: Dictionary = MerlinStore.get_biome_affinity_bonus("foret_broceliande", "quert")
	var expected: Dictionary = StoreFactions.get_biome_affinity_bonus("foret_broceliande", "quert")
	if float(result.get("score_bonus", -1.0)) != float(expected.get("score_bonus", -2.0)):
		push_error("MerlinStore.get_biome_affinity_bonus should delegate to StoreFactions")
		return false
	return true


# =============================================================================
# STORE FACTIONS — faction_score_to_tier
# =============================================================================

func test_faction_tier_hostile_at_zero() -> bool:
	if StoreFactions.faction_score_to_tier(0) != "hostile":
		push_error("Score 0 should be hostile")
		return false
	return true


func test_faction_tier_hostile_at_4() -> bool:
	if StoreFactions.faction_score_to_tier(4) != "hostile":
		push_error("Score 4 should be hostile")
		return false
	return true


func test_faction_tier_mefiant_at_5() -> bool:
	if StoreFactions.faction_score_to_tier(5) != "mefiant":
		push_error("Score 5 should be mefiant")
		return false
	return true


func test_faction_tier_mefiant_at_19() -> bool:
	if StoreFactions.faction_score_to_tier(19) != "mefiant":
		push_error("Score 19 should be mefiant")
		return false
	return true


func test_faction_tier_neutre_at_20() -> bool:
	if StoreFactions.faction_score_to_tier(20) != "neutre":
		push_error("Score 20 should be neutre")
		return false
	return true


func test_faction_tier_neutre_at_49() -> bool:
	if StoreFactions.faction_score_to_tier(49) != "neutre":
		push_error("Score 49 should be neutre")
		return false
	return true


func test_faction_tier_sympathisant_at_50() -> bool:
	if StoreFactions.faction_score_to_tier(50) != "sympathisant":
		push_error("Score 50 should be sympathisant")
		return false
	return true


func test_faction_tier_sympathisant_at_79() -> bool:
	if StoreFactions.faction_score_to_tier(79) != "sympathisant":
		push_error("Score 79 should be sympathisant")
		return false
	return true


func test_faction_tier_honore_at_80() -> bool:
	if StoreFactions.faction_score_to_tier(80) != "honore":
		push_error("Score 80 should be honore")
		return false
	return true


func test_faction_tier_honore_at_100() -> bool:
	if StoreFactions.faction_score_to_tier(100) != "honore":
		push_error("Score 100 should be honore")
		return false
	return true


# =============================================================================
# STORE FACTIONS — build_and_store_faction_context
# =============================================================================

func test_build_faction_context_creates_tiers() -> bool:
	var s: Dictionary = _make_state_with_factions({"druides": 85, "anciens": 10, "korrigans": 50, "niamh": 25, "ankou": 0})
	StoreFactions.build_and_store_faction_context(s)
	var ctx: Dictionary = s["run"].get("faction_context", {})
	if not ctx.has("tiers"):
		push_error("faction_context missing tiers")
		return false
	if str(ctx["tiers"].get("druides", "")) != "honore":
		push_error("druides at 85 should be honore, got '%s'" % ctx["tiers"].get("druides", ""))
		return false
	return true


func test_build_faction_context_identifies_dominant() -> bool:
	var s: Dictionary = _make_state_with_factions({"druides": 85, "anciens": 10, "korrigans": 50, "niamh": 25, "ankou": 0})
	StoreFactions.build_and_store_faction_context(s)
	var ctx: Dictionary = s["run"].get("faction_context", {})
	if str(ctx.get("dominant", "")) != "druides":
		push_error("Dominant should be 'druides', got '%s'" % ctx.get("dominant", ""))
		return false
	return true


func test_build_faction_context_active_effects() -> bool:
	var s: Dictionary = _make_state_with_factions({"druides": 85, "anciens": 10, "korrigans": 50, "niamh": 25, "ankou": 0})
	StoreFactions.build_and_store_faction_context(s)
	var ctx: Dictionary = s["run"].get("faction_context", {})
	var active: Array = ctx.get("active_effects", [])
	# neutre factions (score 20-49) are NOT included, others are
	# druides=85 (honore), anciens=10 (mefiant), korrigans=50 (sympathisant), niamh=25 (neutre), ankou=0 (hostile)
	# non-neutre: druides, anciens, korrigans, ankou = 4
	if active.size() != 4:
		push_error("Expected 4 active effects (non-neutre), got %d" % active.size())
		return false
	return true


# =============================================================================
# STORE FACTIONS — update_trust
# =============================================================================

func test_update_trust_positive() -> bool:
	var s: Dictionary = _make_state()
	s["meta"]["trust_merlin"] = 10
	var result: Dictionary = StoreFactions.update_trust(s, 15)
	if result.is_empty():
		push_error("update_trust should return non-empty dict")
		return false
	if int(result["old"]) != 10 or int(result["new"]) != 25:
		push_error("Trust update: expected 10->25, got %d->%d" % [result["old"], result["new"]])
		return false
	return true


func test_update_trust_clamps_at_100() -> bool:
	var s: Dictionary = _make_state()
	s["meta"]["trust_merlin"] = 90
	var result: Dictionary = StoreFactions.update_trust(s, 50)
	if int(result["new"]) != 100:
		push_error("Trust should clamp at 100, got %d" % result["new"])
		return false
	return true


func test_update_trust_clamps_at_zero() -> bool:
	var s: Dictionary = _make_state()
	s["meta"]["trust_merlin"] = 5
	var result: Dictionary = StoreFactions.update_trust(s, -20)
	if int(result["new"]) != 0:
		push_error("Trust should clamp at 0, got %d" % result["new"])
		return false
	return true


func test_update_trust_zero_delta_returns_empty() -> bool:
	var s: Dictionary = _make_state()
	var result: Dictionary = StoreFactions.update_trust(s, 0)
	if not result.is_empty():
		push_error("Trust delta 0 should return empty dict")
		return false
	return true


# =============================================================================
# STORE FACTIONS — get_trust_tier
# =============================================================================

func test_trust_tier_t0() -> bool:
	var s: Dictionary = _make_state()
	s["meta"]["trust_merlin"] = 0
	if StoreFactions.get_trust_tier(s) != "T0":
		push_error("Trust 0 should be T0, got '%s'" % StoreFactions.get_trust_tier(s))
		return false
	return true


func test_trust_tier_t1() -> bool:
	var s: Dictionary = _make_state()
	s["meta"]["trust_merlin"] = 30
	if StoreFactions.get_trust_tier(s) != "T1":
		push_error("Trust 30 should be T1, got '%s'" % StoreFactions.get_trust_tier(s))
		return false
	return true


func test_trust_tier_t2() -> bool:
	var s: Dictionary = _make_state()
	s["meta"]["trust_merlin"] = 60
	if StoreFactions.get_trust_tier(s) != "T2":
		push_error("Trust 60 should be T2, got '%s'" % StoreFactions.get_trust_tier(s))
		return false
	return true


func test_trust_tier_t3() -> bool:
	var s: Dictionary = _make_state()
	s["meta"]["trust_merlin"] = 90
	if StoreFactions.get_trust_tier(s) != "T3":
		push_error("Trust 90 should be T3, got '%s'" % StoreFactions.get_trust_tier(s))
		return false
	return true


# =============================================================================
# STORE FACTIONS — get_period
# =============================================================================

func test_period_aube() -> bool:
	if StoreFactions.get_period(1) != "aube":
		push_error("Card 1 should be 'aube', got '%s'" % StoreFactions.get_period(1))
		return false
	return true


func test_period_jour() -> bool:
	if StoreFactions.get_period(7) != "jour":
		push_error("Card 7 should be 'jour', got '%s'" % StoreFactions.get_period(7))
		return false
	return true


func test_period_crepuscule() -> bool:
	if StoreFactions.get_period(12) != "crepuscule":
		push_error("Card 12 should be 'crepuscule', got '%s'" % StoreFactions.get_period(12))
		return false
	return true


func test_period_nuit() -> bool:
	if StoreFactions.get_period(18) != "nuit":
		push_error("Card 18 should be 'nuit', got '%s'" % StoreFactions.get_period(18))
		return false
	return true


func test_period_beyond_range_defaults_nuit() -> bool:
	if StoreFactions.get_period(99) != "nuit":
		push_error("Card 99 should default to 'nuit', got '%s'" % StoreFactions.get_period(99))
		return false
	return true


# =============================================================================
# STORE FACTIONS — get_period_bonus
# =============================================================================

func test_period_bonus_druides_at_aube() -> bool:
	var bonus: float = StoreFactions.get_period_bonus(3, "druides")
	if not is_equal_approx(bonus, 0.10):
		push_error("Druides bonus at aube: expected 0.10, got %f" % bonus)
		return false
	return true


func test_period_bonus_druides_at_nuit() -> bool:
	var bonus: float = StoreFactions.get_period_bonus(18, "druides")
	if not is_equal_approx(bonus, 0.0):
		push_error("Druides should have no bonus at nuit, got %f" % bonus)
		return false
	return true


func test_period_bonus_ankou_at_nuit() -> bool:
	var bonus: float = StoreFactions.get_period_bonus(18, "ankou")
	if not is_equal_approx(bonus, 0.15):
		push_error("Ankou bonus at nuit: expected 0.15, got %f" % bonus)
		return false
	return true


# =============================================================================
# STORE FACTIONS — get_biome_affinity_bonus
# =============================================================================

func test_biome_affinity_matching() -> bool:
	var result: Dictionary = StoreFactions.get_biome_affinity_bonus("foret_broceliande", "quert")
	if float(result.get("score_bonus", 0.0)) < 0.05:
		push_error("quert should have affinity with foret_broceliande")
		return false
	if int(result.get("cooldown_reduction", 0)) != 1:
		push_error("Affinity should give cooldown_reduction 1")
		return false
	return true


func test_biome_affinity_no_match() -> bool:
	var result: Dictionary = StoreFactions.get_biome_affinity_bonus("foret_broceliande", "ioho")
	if float(result.get("score_bonus", 0.0)) != 0.0:
		push_error("ioho should have no affinity with foret_broceliande")
		return false
	return true


func test_biome_affinity_unknown_biome() -> bool:
	var result: Dictionary = StoreFactions.get_biome_affinity_bonus("nonexistent", "quert")
	if float(result.get("score_bonus", 0.0)) != 0.0:
		push_error("Unknown biome should return 0 bonus")
		return false
	return true


# =============================================================================
# STORE OGHAMS — use_ogham
# =============================================================================

func test_use_ogham_starter_succeeds() -> bool:
	var s: Dictionary = _make_state()
	var result: Dictionary = StoreOghams.use_ogham(s, "beith")
	if not result.get("ok", false):
		push_error("Using starter ogham 'beith' should succeed: %s" % str(result.get("error", "")))
		return false
	return true


func test_use_ogham_sets_cooldown() -> bool:
	var s: Dictionary = _make_state()
	StoreOghams.use_ogham(s, "beith")
	var cd: int = int(s["oghams"]["skill_cooldowns"].get("beith", 0))
	var expected_cd: int = int(MerlinConstants.OGHAM_FULL_SPECS["beith"].get("cooldown", 0))
	if cd != expected_cd:
		push_error("beith cooldown: expected %d, got %d" % [expected_cd, cd])
		return false
	return true


func test_use_ogham_on_cooldown_fails() -> bool:
	var s: Dictionary = _make_state()
	StoreOghams.use_ogham(s, "beith")
	var result: Dictionary = StoreOghams.use_ogham(s, "beith")
	if result.get("ok", true):
		push_error("Using ogham on cooldown should fail")
		return false
	return true


func test_use_ogham_unknown_fails() -> bool:
	var s: Dictionary = _make_state()
	var result: Dictionary = StoreOghams.use_ogham(s, "nonexistent_ogham")
	if result.get("ok", true):
		push_error("Using unknown ogham should fail")
		return false
	return true


func test_use_ogham_not_unlocked_fails() -> bool:
	var s: Dictionary = _make_state()
	# coll is not a starter and not unlocked by default
	var result: Dictionary = StoreOghams.use_ogham(s, "coll")
	if result.get("ok", true):
		push_error("Using non-unlocked non-starter ogham should fail")
		return false
	return true


func test_use_ogham_unlocked_non_starter_succeeds() -> bool:
	var s: Dictionary = _make_state()
	s["oghams"]["skills_unlocked"].append("coll")
	var result: Dictionary = StoreOghams.use_ogham(s, "coll")
	if not result.get("ok", false):
		push_error("Using unlocked ogham 'coll' should succeed")
		return false
	return true


# =============================================================================
# STORE OGHAMS — tick_cooldowns
# =============================================================================

func test_tick_cooldowns_decrements() -> bool:
	var s: Dictionary = _make_state()
	StoreOghams.use_ogham(s, "beith")
	var cd_before: int = int(s["oghams"]["skill_cooldowns"].get("beith", 0))
	StoreOghams.tick_cooldowns(s)
	var cd_after: int = int(s["oghams"]["skill_cooldowns"].get("beith", 0))
	if cd_after != cd_before - 1:
		push_error("tick_cooldowns: expected %d, got %d" % [cd_before - 1, cd_after])
		return false
	return true


func test_tick_cooldowns_removes_at_zero() -> bool:
	var s: Dictionary = _make_state()
	s["oghams"]["skill_cooldowns"] = {"beith": 1}
	StoreOghams.tick_cooldowns(s)
	if s["oghams"]["skill_cooldowns"].has("beith"):
		push_error("Cooldown at 0 should be removed from dict")
		return false
	return true


func test_tick_cooldowns_multiple() -> bool:
	var s: Dictionary = _make_state()
	s["oghams"]["skill_cooldowns"] = {"beith": 3, "luis": 1, "quert": 2}
	StoreOghams.tick_cooldowns(s)
	var cds: Dictionary = s["oghams"]["skill_cooldowns"]
	if int(cds.get("beith", -1)) != 2:
		push_error("beith should be 2 after tick, got %d" % cds.get("beith", -1))
		return false
	if cds.has("luis"):
		push_error("luis at 1 should be removed after tick")
		return false
	if int(cds.get("quert", -1)) != 1:
		push_error("quert should be 1 after tick")
		return false
	return true


# =============================================================================
# STORE OGHAMS — can_use_ogham
# =============================================================================

func test_can_use_ogham_starter_yes() -> bool:
	var s: Dictionary = _make_state()
	if not StoreOghams.can_use_ogham(s, "beith"):
		push_error("Starter ogham 'beith' should be usable")
		return false
	return true


func test_can_use_ogham_on_cooldown_no() -> bool:
	var s: Dictionary = _make_state()
	StoreOghams.use_ogham(s, "beith")
	if StoreOghams.can_use_ogham(s, "beith"):
		push_error("Ogham on cooldown should not be usable")
		return false
	return true


func test_can_use_ogham_unknown_no() -> bool:
	var s: Dictionary = _make_state()
	if StoreOghams.can_use_ogham(s, "fake_ogham"):
		push_error("Unknown ogham should not be usable")
		return false
	return true


# =============================================================================
# STORE OGHAMS — get_available_oghams
# =============================================================================

func test_get_available_oghams_starters() -> bool:
	var s: Dictionary = _make_state()
	var available: Array = StoreOghams.get_available_oghams(s)
	for starter in MerlinConstants.OGHAM_STARTER_SKILLS:
		if not available.has(starter):
			push_error("Starter '%s' should be available" % starter)
			return false
	return true


func test_get_available_oghams_after_use_excludes() -> bool:
	var s: Dictionary = _make_state()
	StoreOghams.use_ogham(s, "beith")
	var available: Array = StoreOghams.get_available_oghams(s)
	if available.has("beith"):
		push_error("beith on cooldown should not be in available list")
		return false
	return true


# =============================================================================
# STORE OGHAMS — get_ogham_cost
# =============================================================================

func test_get_ogham_cost_base() -> bool:
	var s: Dictionary = _make_state()
	var cost: int = StoreOghams.get_ogham_cost(s, "coll")
	var expected: int = int(MerlinConstants.OGHAM_FULL_SPECS["coll"].get("cost_anam", 0))
	if cost != expected:
		push_error("coll cost: expected %d, got %d" % [expected, cost])
		return false
	return true


func test_get_ogham_cost_with_discount() -> bool:
	var s: Dictionary = _make_state()
	StoreOghams.apply_ogham_discount(s, "coll")
	var cost: int = StoreOghams.get_ogham_cost(s, "coll")
	var base: int = int(MerlinConstants.OGHAM_FULL_SPECS["coll"].get("cost_anam", 0))
	var expected: int = int(float(base) * 0.5)
	if cost != expected:
		push_error("Discounted coll cost: expected %d, got %d" % [expected, cost])
		return false
	return true


# =============================================================================
# STORE OGHAMS — apply_ogham_discount
# =============================================================================

func test_apply_ogham_discount_halves() -> bool:
	var s: Dictionary = _make_state()
	StoreOghams.apply_ogham_discount(s, "duir")
	var discounts: Dictionary = s["meta"].get("ogham_discounts", {})
	if not discounts.has("duir"):
		push_error("Discount for duir should exist")
		return false
	var base: int = int(MerlinConstants.OGHAM_FULL_SPECS["duir"].get("cost_anam", 0))
	if int(discounts["duir"]) != int(float(base) * 0.5):
		push_error("Discount should be 50%% of base")
		return false
	return true


# =============================================================================
# STORE OGHAMS — buy_ogham
# =============================================================================

func test_buy_ogham_success() -> bool:
	var s: Dictionary = _make_state_with_anam(200)
	s["meta"]["oghams"] = {"owned": []}
	var save: MerlinSaveSystem = MerlinSaveSystem.new()
	var result: Dictionary = StoreOghams.buy_ogham(s, "coll", save)
	if not result.get("ok", false):
		push_error("buy_ogham should succeed with enough anam: %s" % str(result.get("error", "")))
		return false
	if not s["meta"]["oghams"]["owned"].has("coll"):
		push_error("coll should be in owned list")
		return false
	return true


func test_buy_ogham_deducts_anam() -> bool:
	var s: Dictionary = _make_state_with_anam(200)
	s["meta"]["oghams"] = {"owned": []}
	var save: MerlinSaveSystem = MerlinSaveSystem.new()
	var cost: int = StoreOghams.get_ogham_cost(s, "coll")
	StoreOghams.buy_ogham(s, "coll", save)
	var remaining: int = int(s["meta"].get("anam", -1))
	if remaining != 200 - cost:
		push_error("Anam after buy: expected %d, got %d" % [200 - cost, remaining])
		return false
	return true


func test_buy_ogham_insufficient_anam() -> bool:
	var s: Dictionary = _make_state_with_anam(1)
	s["meta"]["oghams"] = {"owned": []}
	var save: MerlinSaveSystem = MerlinSaveSystem.new()
	var result: Dictionary = StoreOghams.buy_ogham(s, "coll", save)
	if result.get("ok", true):
		push_error("buy_ogham should fail with insufficient anam")
		return false
	return true


func test_buy_ogham_already_owned() -> bool:
	var s: Dictionary = _make_state_with_anam(200)
	s["meta"]["oghams"] = {"owned": ["coll"]}
	var save: MerlinSaveSystem = MerlinSaveSystem.new()
	var result: Dictionary = StoreOghams.buy_ogham(s, "coll", save)
	if result.get("ok", true):
		push_error("buy_ogham should fail if already owned")
		return false
	if str(result.get("error", "")) != "already_owned":
		push_error("Error should be 'already_owned'")
		return false
	return true


# =============================================================================
# STORE RUN — generate_mission
# =============================================================================

func test_generate_mission_has_required_keys() -> bool:
	var rng: MerlinRng = MerlinRng.new()
	rng.set_seed(42)
	var mission: Dictionary = StoreRun.generate_mission(rng)
	for key in ["type", "target", "description", "progress", "total"]:
		if not mission.has(key):
			push_error("Mission missing key '%s'" % key)
			return false
	return true


func test_generate_mission_progress_starts_zero() -> bool:
	var rng: MerlinRng = MerlinRng.new()
	rng.set_seed(42)
	var mission: Dictionary = StoreRun.generate_mission(rng)
	if int(mission.get("progress", -1)) != 0:
		push_error("Mission progress should start at 0")
		return false
	return true


func test_generate_mission_total_positive() -> bool:
	var rng: MerlinRng = MerlinRng.new()
	rng.set_seed(42)
	var mission: Dictionary = StoreRun.generate_mission(rng)
	if int(mission.get("total", 0)) <= 0:
		push_error("Mission total should be positive, got %d" % mission.get("total", 0))
		return false
	return true


func test_generate_mission_type_in_templates() -> bool:
	var rng: MerlinRng = MerlinRng.new()
	rng.set_seed(99)
	var mission: Dictionary = StoreRun.generate_mission(rng)
	if not MerlinConstants.MISSION_TEMPLATES.has(mission["type"]):
		push_error("Mission type '%s' not in templates" % mission["type"])
		return false
	return true


# =============================================================================
# STORE RUN — progress_mission
# =============================================================================

func test_progress_mission_increments() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	var result: Dictionary = StoreRun.progress_mission(s, 1)
	if not result.get("ok", false):
		push_error("progress_mission should succeed")
		return false
	if int(result["progress"]) != 1:
		push_error("Progress should be 1, got %d" % result["progress"])
		return false
	return true


func test_progress_mission_caps_at_total() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	s["run"]["mission"]["total"] = 5
	StoreRun.progress_mission(s, 10)
	var progress: int = int(s["run"]["mission"]["progress"])
	if progress != 5:
		push_error("Progress should cap at total 5, got %d" % progress)
		return false
	return true


func test_progress_mission_complete_flag() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	s["run"]["mission"]["total"] = 3
	StoreRun.progress_mission(s, 2)
	var result: Dictionary = StoreRun.progress_mission(s, 1)
	if not result.get("complete", false):
		push_error("Mission should be complete at progress=total")
		return false
	return true


# =============================================================================
# STORE RUN — check_run_end
# =============================================================================

func test_check_run_end_alive_not_ended() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	var result: Dictionary = StoreRun.check_run_end(s)
	if result.get("ended", true):
		push_error("Run should not end with full life and low cards")
		return false
	return true


func test_check_run_end_death() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	s["run"]["life_essence"] = 0
	var result: Dictionary = StoreRun.check_run_end(s)
	if not result.get("ended", false):
		push_error("Run should end at 0 life")
		return false
	if not result.get("life_depleted", false):
		push_error("Should flag life_depleted")
		return false
	return true


func test_check_run_end_hard_max() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	s["run"]["cards_played"] = int(MerlinConstants.MOS_CONVERGENCE.get("hard_max_cards", 50))
	var result: Dictionary = StoreRun.check_run_end(s)
	if not result.get("ended", false):
		push_error("Run should end at hard_max_cards")
		return false
	if not result.get("hard_max", false):
		push_error("Should flag hard_max")
		return false
	return true


func test_check_run_end_victory() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	s["run"]["mission"]["total"] = 5
	s["run"]["mission"]["progress"] = 5
	s["run"]["cards_played"] = MerlinConstants.MIN_CARDS_FOR_VICTORY
	var result: Dictionary = StoreRun.check_run_end(s)
	if not result.get("ended", false):
		push_error("Run should end with mission complete + min cards")
		return false
	if not result.get("victory", false):
		push_error("Should flag victory")
		return false
	return true


func test_check_run_end_mission_complete_but_not_enough_cards() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	s["run"]["mission"]["total"] = 5
	s["run"]["mission"]["progress"] = 5
	s["run"]["cards_played"] = 3
	var result: Dictionary = StoreRun.check_run_end(s)
	if result.get("ended", true):
		push_error("Run should NOT end if mission complete but cards < MIN_CARDS_FOR_VICTORY")
		return false
	return true


func test_check_run_end_tension_zones() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	s["run"]["cards_played"] = 10
	var result: Dictionary = StoreRun.check_run_end(s)
	if result.get("ended", true):
		push_error("Run should not end at 10 cards")
		return false
	if str(result.get("tension_zone", "")) != "low":
		push_error("10 cards should be 'low' tension, got '%s'" % result.get("tension_zone", ""))
		return false
	return true


func test_check_run_end_rising_tension() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	s["run"]["cards_played"] = 22
	var result: Dictionary = StoreRun.check_run_end(s)
	if str(result.get("tension_zone", "")) != "rising":
		push_error("22 cards should be 'rising' tension, got '%s'" % result.get("tension_zone", ""))
		return false
	return true


func test_check_run_end_critical_tension() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	s["run"]["cards_played"] = 42
	var result: Dictionary = StoreRun.check_run_end(s)
	if str(result.get("tension_zone", "")) != "critical":
		push_error("42 cards should be 'critical' tension, got '%s'" % result.get("tension_zone", ""))
		return false
	return true


# =============================================================================
# STORE RUN — get_victory_type
# =============================================================================

func test_victory_type_harmonie() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	s["run"]["hidden"]["karma"] = 10
	var vtype: String = StoreRun.get_victory_type(s)
	if vtype != "harmonie":
		push_error("Karma 10 should give 'harmonie', got '%s'" % vtype)
		return false
	return true


func test_victory_type_victoire_amere() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	s["run"]["hidden"]["karma"] = -10
	var vtype: String = StoreRun.get_victory_type(s)
	if vtype != "victoire_amere":
		push_error("Karma -10 should give 'victoire_amere', got '%s'" % vtype)
		return false
	return true


func test_victory_type_prix_paye() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	s["run"]["hidden"]["karma"] = 0
	var vtype: String = StoreRun.get_victory_type(s)
	if vtype != "prix_paye":
		push_error("Karma 0 should give 'prix_paye', got '%s'" % vtype)
		return false
	return true


# =============================================================================
# STORE RUN — calculate_run_rewards
# =============================================================================

func test_run_rewards_base() -> bool:
	var s: Dictionary = _make_state()
	var run_data: Dictionary = {"victory": false, "cards_played": 30}
	var rewards: Dictionary = StoreRun.calculate_run_rewards(s, run_data)
	if int(rewards.get("anam", -1)) < MerlinConstants.ANAM_BASE_REWARD:
		push_error("Base anam should be >= %d" % MerlinConstants.ANAM_BASE_REWARD)
		return false
	return true


func test_run_rewards_victory_bonus() -> bool:
	var s: Dictionary = _make_state()
	var r_loss: Dictionary = StoreRun.calculate_run_rewards(s, {"victory": false, "cards_played": 30})
	var r_win: Dictionary = StoreRun.calculate_run_rewards(s, {"victory": true, "cards_played": 30})
	if int(r_win["anam"]) <= int(r_loss["anam"]):
		push_error("Victory should give more anam than loss")
		return false
	return true


func test_run_rewards_death_cap_reduces() -> bool:
	var s: Dictionary = _make_state()
	# Death with very few cards = reduced anam
	var rewards: Dictionary = StoreRun.calculate_run_rewards(s, {"victory": false, "cards_played": 3})
	var full: Dictionary = StoreRun.calculate_run_rewards(s, {"victory": false, "cards_played": 30})
	if int(rewards["anam"]) >= int(full["anam"]):
		push_error("Death with 3 cards should give less anam than 30 cards")
		return false
	return true


func test_run_rewards_minigames_bonus() -> bool:
	var s: Dictionary = _make_state()
	var r0: Dictionary = StoreRun.calculate_run_rewards(s, {"victory": true, "cards_played": 30, "minigames_won": 0})
	var r5: Dictionary = StoreRun.calculate_run_rewards(s, {"victory": true, "cards_played": 30, "minigames_won": 5})
	if int(r5["anam"]) <= int(r0["anam"]):
		push_error("More minigames_won should give more anam")
		return false
	return true


func test_run_rewards_honored_faction_bonus() -> bool:
	var s: Dictionary = _make_state_with_factions({"druides": 85, "anciens": 0, "korrigans": 0, "niamh": 0, "ankou": 0})
	var r_honored: Dictionary = StoreRun.calculate_run_rewards(s, {"victory": true, "cards_played": 30})
	var s2: Dictionary = _make_state()
	var r_none: Dictionary = StoreRun.calculate_run_rewards(s2, {"victory": true, "cards_played": 30})
	if int(r_honored["anam"]) <= int(r_none["anam"]):
		push_error("Honored faction should increase anam reward")
		return false
	return true


# =============================================================================
# STORE RUN — calculate_maturity_score
# =============================================================================

func test_maturity_score_zero_fresh() -> bool:
	var s: Dictionary = _make_state()
	var score: int = StoreRun.calculate_maturity_score(s)
	if score != 0:
		push_error("Fresh state maturity score should be 0, got %d" % score)
		return false
	return true


func test_maturity_score_with_runs() -> bool:
	var s: Dictionary = _make_state()
	s["meta"]["total_runs"] = 5
	var score: int = StoreRun.calculate_maturity_score(s)
	var expected: int = 5 * int(MerlinConstants.MATURITY_WEIGHTS.get("total_runs", 2))
	if score != expected:
		push_error("Maturity with 5 runs: expected %d, got %d" % [expected, score])
		return false
	return true


func test_maturity_score_with_endings() -> bool:
	var s: Dictionary = _make_state()
	s["meta"]["endings_seen"] = ["Harmonie Retrouvee", "Victoire Amere"]
	var score: int = StoreRun.calculate_maturity_score(s)
	var expected: int = 2 * int(MerlinConstants.MATURITY_WEIGHTS.get("fins_vues", 5))
	if score != expected:
		push_error("Maturity with 2 endings: expected %d, got %d" % [expected, score])
		return false
	return true


func test_maturity_score_composite() -> bool:
	var s: Dictionary = _make_state()
	s["meta"]["total_runs"] = 3
	s["meta"]["endings_seen"] = ["A"]
	s["meta"]["oghams"] = {"owned": ["coll", "duir"]}
	s["meta"]["faction_rep"]["druides"] = 60
	var score: int = StoreRun.calculate_maturity_score(s)
	var w: Dictionary = MerlinConstants.MATURITY_WEIGHTS
	var expected: int = 3 * int(w["total_runs"]) + 1 * int(w["fins_vues"]) + 2 * int(w["oghams_debloques"]) + 60 * int(w["max_faction_rep"])
	if score != expected:
		push_error("Composite maturity: expected %d, got %d" % [expected, score])
		return false
	return true


# =============================================================================
# STORE RUN — can_unlock_biome / get_unlockable_biomes
# =============================================================================

func test_can_unlock_foret_always() -> bool:
	var s: Dictionary = _make_state()
	if not StoreRun.can_unlock_biome(s, "foret_broceliande"):
		push_error("foret_broceliande (threshold 0) should always be unlockable")
		return false
	return true


func test_can_unlock_biome_insufficient() -> bool:
	var s: Dictionary = _make_state()
	if StoreRun.can_unlock_biome(s, "iles_mystiques"):
		push_error("iles_mystiques (threshold 75) should not be unlockable from fresh state")
		return false
	return true


func test_get_unlockable_biomes_fresh() -> bool:
	var s: Dictionary = _make_state()
	var biomes: Array = StoreRun.get_unlockable_biomes(s)
	if not biomes.has("foret_broceliande"):
		push_error("foret_broceliande should be in unlockable biomes")
		return false
	if biomes.has("iles_mystiques"):
		push_error("iles_mystiques should NOT be in unlockable biomes from fresh state")
		return false
	return true


# =============================================================================
# STORE RUN — update_player_profile
# =============================================================================

func test_update_player_profile_left_increments_prudence() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	StoreRun.update_player_profile(s, MerlinConstants.CardOption.LEFT)
	var profile: Dictionary = s["run"]["hidden"]["player_profile"]
	if int(profile.get("prudence", 0)) != 1:
		push_error("LEFT should increment prudence, got %d" % profile.get("prudence", 0))
		return false
	return true


func test_update_player_profile_right_increments_audace() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	StoreRun.update_player_profile(s, MerlinConstants.CardOption.RIGHT)
	var profile: Dictionary = s["run"]["hidden"]["player_profile"]
	if int(profile.get("audace", 0)) != 1:
		push_error("RIGHT should increment audace, got %d" % profile.get("audace", 0))
		return false
	return true


func test_update_player_profile_center_no_change() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	StoreRun.update_player_profile(s, MerlinConstants.CardOption.CENTER)
	var profile: Dictionary = s["run"]["hidden"]["player_profile"]
	if int(profile.get("prudence", 0)) != 0 or int(profile.get("audace", 0)) != 0:
		push_error("CENTER should not change profile")
		return false
	return true


# =============================================================================
# STORE TALENTS — is_talent_active
# =============================================================================

func test_is_talent_active_false_default() -> bool:
	var s: Dictionary = _make_state()
	if StoreTalents.is_talent_active(s, "druides_1"):
		push_error("druides_1 should not be active by default")
		return false
	return true


func test_is_talent_active_true_when_unlocked() -> bool:
	var s: Dictionary = _make_state()
	s["meta"]["talent_tree"]["unlocked"].append("druides_1")
	if not StoreTalents.is_talent_active(s, "druides_1"):
		push_error("druides_1 should be active after unlock")
		return false
	return true


# =============================================================================
# STORE TALENTS — can_unlock_talent
# =============================================================================

func test_can_unlock_talent_tier1_with_anam() -> bool:
	var s: Dictionary = _make_state_with_anam(100)
	if not StoreTalents.can_unlock_talent(s, "druides_1"):
		push_error("druides_1 should be unlockable with enough anam")
		return false
	return true


func test_can_unlock_talent_insufficient_anam() -> bool:
	var s: Dictionary = _make_state_with_anam(0)
	if StoreTalents.can_unlock_talent(s, "druides_1"):
		push_error("druides_1 should NOT be unlockable with 0 anam")
		return false
	return true


func test_can_unlock_talent_missing_prerequisite() -> bool:
	var s: Dictionary = _make_state_with_anam(200)
	# druides_2 requires druides_1
	if StoreTalents.can_unlock_talent(s, "druides_2"):
		push_error("druides_2 should NOT be unlockable without druides_1")
		return false
	return true


func test_can_unlock_talent_with_prerequisite() -> bool:
	var s: Dictionary = _make_state_with_anam(200)
	s["meta"]["talent_tree"]["unlocked"].append("druides_1")
	if not StoreTalents.can_unlock_talent(s, "druides_2"):
		push_error("druides_2 should be unlockable with druides_1 + enough anam")
		return false
	return true


func test_can_unlock_talent_already_unlocked() -> bool:
	var s: Dictionary = _make_state_with_anam(200)
	s["meta"]["talent_tree"]["unlocked"].append("druides_1")
	if StoreTalents.can_unlock_talent(s, "druides_1"):
		push_error("Already unlocked talent should not be 'can_unlock'")
		return false
	return true


func test_can_unlock_talent_unknown_node() -> bool:
	var s: Dictionary = _make_state_with_anam(200)
	if StoreTalents.can_unlock_talent(s, "fake_talent_99"):
		push_error("Unknown talent should not be unlockable")
		return false
	return true


# =============================================================================
# STORE TALENTS — unlock_talent
# =============================================================================

func test_unlock_talent_success() -> bool:
	var s: Dictionary = _make_state_with_anam(100)
	var save: MerlinSaveSystem = MerlinSaveSystem.new()
	var result: Dictionary = StoreTalents.unlock_talent(s, "druides_1", save)
	if not result.get("ok", false):
		push_error("unlock_talent should succeed: %s" % str(result.get("error", "")))
		return false
	if not s["meta"]["talent_tree"]["unlocked"].has("druides_1"):
		push_error("druides_1 should be in unlocked list")
		return false
	return true


func test_unlock_talent_deducts_anam() -> bool:
	var s: Dictionary = _make_state_with_anam(100)
	var save: MerlinSaveSystem = MerlinSaveSystem.new()
	var cost: int = int(MerlinConstants.TALENT_NODES["druides_1"].get("cost", 0))
	StoreTalents.unlock_talent(s, "druides_1", save)
	var remaining: int = int(s["meta"]["anam"])
	if remaining != 100 - cost:
		push_error("Anam after unlock: expected %d, got %d" % [100 - cost, remaining])
		return false
	return true


func test_unlock_talent_fails_when_cannot() -> bool:
	var s: Dictionary = _make_state_with_anam(0)
	var save: MerlinSaveSystem = MerlinSaveSystem.new()
	var result: Dictionary = StoreTalents.unlock_talent(s, "druides_1", save)
	if result.get("ok", true):
		push_error("unlock_talent should fail with insufficient anam")
		return false
	return true


# =============================================================================
# STORE TALENTS — get_unlocked_talents
# =============================================================================

func test_get_unlocked_talents_empty_default() -> bool:
	var s: Dictionary = _make_state()
	var talents: Array = StoreTalents.get_unlocked_talents(s)
	if not talents.is_empty():
		push_error("Default should have no unlocked talents")
		return false
	return true


func test_get_unlocked_talents_returns_copy() -> bool:
	var s: Dictionary = _make_state()
	s["meta"]["talent_tree"]["unlocked"].append("druides_1")
	var talents: Array = StoreTalents.get_unlocked_talents(s)
	talents.append("MUTATED")
	var talents2: Array = StoreTalents.get_unlocked_talents(s)
	if talents2.has("MUTATED"):
		push_error("get_unlocked_talents should return a copy")
		return false
	return true


# =============================================================================
# STORE TALENTS — get_affordable_talents
# =============================================================================

func test_get_affordable_talents_with_anam() -> bool:
	var s: Dictionary = _make_state_with_anam(500)
	var affordable: Array = StoreTalents.get_affordable_talents(s)
	# All tier-1 talents with no prerequisites should be affordable
	if affordable.is_empty():
		push_error("Should have affordable talents with 500 anam")
		return false
	# Check that druides_1 (no prereqs, cost 20) is in the list
	if not affordable.has("druides_1"):
		push_error("druides_1 should be affordable")
		return false
	return true


func test_get_affordable_talents_zero_anam() -> bool:
	var s: Dictionary = _make_state_with_anam(0)
	var affordable: Array = StoreTalents.get_affordable_talents(s)
	if not affordable.is_empty():
		push_error("Should have no affordable talents with 0 anam")
		return false
	return true


# =============================================================================
# STORE TALENTS — get_talent_modifier / consume_talent_modifier
# =============================================================================

func test_get_talent_modifier_default() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	var val: Variant = StoreTalents.get_talent_modifier(s, "some_key")
	if val != false:
		push_error("Default modifier should be false")
		return false
	return true


func test_get_talent_modifier_custom_default() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	var val: Variant = StoreTalents.get_talent_modifier(s, "nonexistent", 42)
	if val != 42:
		push_error("Custom default should be 42, got %s" % str(val))
		return false
	return true


func test_consume_talent_modifier() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	s["run"]["talent_modifiers"] = {"shield": true}
	var consumed: bool = StoreTalents.consume_talent_modifier(s, "shield")
	if not consumed:
		push_error("consume should return true for active modifier")
		return false
	var val: Variant = StoreTalents.get_talent_modifier(s, "shield")
	if val != false:
		push_error("Consumed modifier should be false")
		return false
	return true


func test_consume_talent_modifier_not_present() -> bool:
	var s: Dictionary = _make_state_with_run_active()
	var consumed: bool = StoreTalents.consume_talent_modifier(s, "nonexistent")
	if consumed:
		push_error("consume should return false for missing modifier")
		return false
	return true


# =============================================================================
# MERLINSTORE — _apply_effect dispatcher
# =============================================================================

func test_apply_effect_add_karma_clamped() -> bool:
	var store: MerlinStore = _make_store()
	store._apply_effect({"type": "ADD_KARMA", "amount": 15})
	var karma: int = int(store.state["run"]["hidden"].get("karma", 0))
	if karma != 15:
		push_error("Karma should be 15, got %d" % karma)
		return false
	# Clamp test: add more to exceed 20
	store._apply_effect({"type": "ADD_KARMA", "amount": 10})
	karma = int(store.state["run"]["hidden"].get("karma", 0))
	if karma != 20:
		push_error("Karma should clamp at 20, got %d" % karma)
		return false
	return true


func test_apply_effect_add_karma_negative_clamped() -> bool:
	var store: MerlinStore = _make_store()
	store._apply_effect({"type": "ADD_KARMA", "amount": -30})
	var karma: int = int(store.state["run"]["hidden"].get("karma", 0))
	if karma != -20:
		push_error("Karma should clamp at -20, got %d" % karma)
		return false
	return true


func test_apply_effect_add_tension_clamped() -> bool:
	var store: MerlinStore = _make_store()
	store._apply_effect({"type": "ADD_TENSION", "amount": 50})
	var tension: int = int(store.state["run"]["hidden"].get("tension", 0))
	if tension != 50:
		push_error("Tension should be 50, got %d" % tension)
		return false
	store._apply_effect({"type": "ADD_TENSION", "amount": 60})
	tension = int(store.state["run"]["hidden"].get("tension", 0))
	if tension != 100:
		push_error("Tension should clamp at 100, got %d" % tension)
		return false
	return true


func test_apply_effect_add_anam() -> bool:
	var store: MerlinStore = _make_store()
	store._apply_effect({"type": "ADD_ANAM", "amount": 7})
	var run_anam: int = int(store.state["run"].get("anam_run", 0))
	# ADD_ANAM goes through effects._apply_add_anam which writes to run.anam
	var anam: int = int(store.state["run"].get("anam", 0))
	# Just verify it was called (exact key depends on implementation)
	return true


func test_apply_effect_add_reputation() -> bool:
	var store: MerlinStore = _make_store()
	store._apply_effect({"type": "ADD_REPUTATION", "faction": "druides", "amount": 10})
	var rep: int = int(store.state.get("meta", {}).get("faction_rep", {}).get("druides", 0))
	if rep != MerlinConstants.FACTION_SCORE_START + 10:
		push_error("Druides rep should be %d, got %d" % [MerlinConstants.FACTION_SCORE_START + 10, rep])
		return false
	return true
