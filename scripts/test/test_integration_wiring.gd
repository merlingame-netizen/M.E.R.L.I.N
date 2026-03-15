## ═══════════════════════════════════════════════════════════════════════════════
## Integration Wiring Tests — Verify game systems are properly wired together
## ═══════════════════════════════════════════════════════════════════════════════
## 16 tests covering: Store→EffectEngine, Constants completeness,
## SaveSystem round-trip, CardSystem validation, system instantiation chain.
## Pattern: extends RefCounted, run_all() → Dictionary {passed, failed, results}.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name TestIntegrationWiring


func run_all() -> Dictionary:
	var results: Array[Dictionary] = []
	var passed: int = 0
	var failed: int = 0

	var test_methods: Array[String] = [
		# Store → EffectEngine wiring (3)
		"test_store_has_effect_engine_reference",
		"test_dispatch_apply_effects_no_crash",
		"test_effect_engine_valid_codes_completeness",
		# Constants completeness (4)
		"test_oghams_has_18_entries",
		"test_biomes_has_8_entries",
		"test_factions_has_5_entries",
		"test_multiplier_table_covers_full_range",
		# Save system round-trip (3)
		"test_save_system_creates_default_profile",
		"test_default_profile_has_required_keys",
		"test_profile_json_round_trip",
		# Card system (3)
		"test_card_system_instantiation",
		"test_card_validation_accepts_valid_card",
		"test_card_validation_rejects_missing_fields",
		# System instantiation chain (3)
		"test_core_systems_instantiation",
		"test_error_handler_health_monitor_wiring",
		"test_accessibility_system_round_trip",
	]

	for method_name in test_methods:
		var ok: bool = call(method_name)
		var entry: Dictionary = {"test": method_name, "passed": ok}
		results.append(entry)
		if ok:
			passed += 1
		else:
			failed += 1

	return {"passed": passed, "failed": failed, "results": results}


# ═══════════════════════════════════════════════════════════════════════════════
# 1. STORE → EFFECT ENGINE WIRING
# ═══════════════════════════════════════════════════════════════════════════════

func test_store_has_effect_engine_reference() -> bool:
	var store: MerlinStore = MerlinStore.new()
	if store.effects == null:
		push_error("MerlinStore.effects is null — EffectEngine not wired")
		store.free()
		return false
	if not (store.effects is MerlinEffectEngine):
		push_error("MerlinStore.effects is not MerlinEffectEngine")
		store.free()
		return false
	store.free()
	return true


func test_dispatch_apply_effects_no_crash() -> bool:
	var engine: MerlinEffectEngine = MerlinEffectEngine.new()
	var state: Dictionary = {
		"run": {
			"life_essence": 50,
			"anam": 0,
		},
		"meta": {
			"faction_rep": {
				"druides": 10, "anciens": 10, "korrigans": 10,
				"niamh": 10, "ankou": 10,
			},
		},
		"effect_log": [],
	}
	var result: Dictionary = engine.apply_effects(state, ["HEAL_LIFE:5"], "TEST")
	if result.get("applied", []).size() != 1:
		push_error("APPLY_EFFECTS: expected 1 applied effect, got %d" % result.get("applied", []).size())
		return false
	return true


func test_effect_engine_valid_codes_completeness() -> bool:
	var required_codes: Array[String] = [
		"ADD_REPUTATION", "HEAL_LIFE", "DAMAGE_LIFE", "ADD_PROMISE", "OFFERING",
	]
	for code in required_codes:
		if not MerlinEffectEngine.VALID_CODES.has(code):
			push_error("EffectEngine.VALID_CODES missing required code: %s" % code)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 2. CONSTANTS COMPLETENESS
# ═══════════════════════════════════════════════════════════════════════════════

func test_oghams_has_18_entries() -> bool:
	var count: int = MerlinConstants.OGHAM_FULL_SPECS.size()
	if count != 18:
		push_error("OGHAM_FULL_SPECS has %d entries, expected 18" % count)
		return false
	return true


func test_biomes_has_8_entries() -> bool:
	var count: int = MerlinConstants.BIOMES.size()
	if count != 8:
		push_error("BIOMES has %d entries, expected 8" % count)
		return false
	return true


func test_factions_has_5_entries() -> bool:
	var count: int = MerlinConstants.FACTIONS.size()
	if count != 5:
		push_error("FACTIONS has %d entries, expected 5" % count)
		return false
	# Verify expected faction names
	var expected: Array[String] = ["druides", "anciens", "korrigans", "niamh", "ankou"]
	for faction in expected:
		if not MerlinConstants.FACTIONS.has(faction):
			push_error("FACTIONS missing expected faction: %s" % faction)
			return false
	return true


func test_multiplier_table_covers_full_range() -> bool:
	var table: Array = MerlinConstants.MULTIPLIER_TABLE
	if table.is_empty():
		push_error("MULTIPLIER_TABLE is empty")
		return false

	# Verify range coverage: 0 to 100 with no gaps
	var first_entry: Dictionary = table[0]
	if int(first_entry.get("range_min", -1)) != 0:
		push_error("MULTIPLIER_TABLE does not start at 0, starts at %d" % int(first_entry.get("range_min", -1)))
		return false

	var last_entry: Dictionary = table[table.size() - 1]
	if int(last_entry.get("range_max", -1)) != 100:
		push_error("MULTIPLIER_TABLE does not end at 100, ends at %d" % int(last_entry.get("range_max", -1)))
		return false

	# Check contiguity: each range_min should be prev range_max + 1
	for i in range(1, table.size()):
		var prev_max: int = int(table[i - 1].get("range_max", -1))
		var curr_min: int = int(table[i].get("range_min", -1))
		if curr_min != prev_max + 1:
			push_error("MULTIPLIER_TABLE gap between entries %d and %d: prev_max=%d, curr_min=%d" % [i - 1, i, prev_max, curr_min])
			return false

	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 3. SAVE SYSTEM ROUND-TRIP
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_system_creates_default_profile() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	if profile.is_empty():
		push_error("Default profile is empty")
		return false
	return true


func test_default_profile_has_required_keys() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	var required_keys: Array[String] = [
		"anam", "total_runs", "faction_rep", "trust_merlin",
		"talent_tree", "oghams", "endings_seen", "arc_tags",
		"biome_runs", "stats",
	]
	for key in required_keys:
		if not profile.has(key):
			push_error("Default profile missing required key: %s" % key)
			return false

	# Verify faction_rep has all 5 factions
	var factions: Dictionary = profile.get("faction_rep", {})
	for faction in MerlinConstants.FACTIONS:
		if not factions.has(faction):
			push_error("Default profile faction_rep missing faction: %s" % faction)
			return false

	# Verify biome_runs has 8 biomes
	var biome_runs: Dictionary = profile.get("biome_runs", {})
	if biome_runs.size() != 8:
		push_error("Default profile biome_runs has %d entries, expected 8" % biome_runs.size())
		return false

	return true


func test_profile_json_round_trip() -> bool:
	var original: Dictionary = MerlinSaveSystem._get_default_profile()
	# Modify some values to ensure round-trip fidelity
	original["anam"] = 42
	original["total_runs"] = 7
	original["faction_rep"]["druides"] = 55.0

	# Serialize to JSON and back
	var json_str: String = JSON.stringify(original)
	if json_str.is_empty():
		push_error("JSON.stringify returned empty string")
		return false

	var parsed = JSON.parse_string(json_str)
	if parsed == null:
		push_error("JSON.parse_string returned null")
		return false
	if not (parsed is Dictionary):
		push_error("Parsed JSON is not Dictionary")
		return false

	var restored: Dictionary = parsed as Dictionary
	if int(restored.get("anam", -1)) != 42:
		push_error("Round-trip anam mismatch: expected 42, got %s" % str(restored.get("anam", "")))
		return false
	if int(restored.get("total_runs", -1)) != 7:
		push_error("Round-trip total_runs mismatch: expected 7, got %s" % str(restored.get("total_runs", "")))
		return false

	var rep: Dictionary = restored.get("faction_rep", {})
	if absf(float(rep.get("druides", 0.0)) - 55.0) > 0.01:
		push_error("Round-trip faction_rep.druides mismatch: expected 55.0, got %s" % str(rep.get("druides", "")))
		return false

	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 4. CARD SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_system_instantiation() -> bool:
	var cs: MerlinCardSystem = MerlinCardSystem.new()
	if cs == null:
		push_error("MerlinCardSystem instantiation returned null")
		return false
	# Verify it can be set up with null dependencies (pure logic mode)
	cs.setup(null, null, null)
	return true


func test_card_validation_accepts_valid_card() -> bool:
	var cs: MerlinCardSystem = MerlinCardSystem.new()
	cs.setup(null, null, null)
	var valid_card: Dictionary = {
		"text": "Un sentier brumeux s'ouvre devant vous dans la foret ancienne.",
		"options": [
			{"label": "Suivre le sentier", "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
			{"label": "Rebrousser chemin", "effects": [{"type": "DAMAGE_LIFE", "amount": 2}]},
			{"label": "Observer les alentours", "effects": []},
		],
		"tags": ["foret", "mystere"],
	}
	var result: Dictionary = cs._validate_card(valid_card)
	if not result.get("valid", false):
		push_error("Valid card rejected: %s" % str(result.get("error", "")))
		return false
	return true


func test_card_validation_rejects_missing_fields() -> bool:
	var cs: MerlinCardSystem = MerlinCardSystem.new()
	cs.setup(null, null, null)

	# Card with no text
	var no_text_card: Dictionary = {
		"options": [
			{"label": "Option A"},
			{"label": "Option B"},
		],
	}
	var result_no_text: Dictionary = cs._validate_card(no_text_card)
	if result_no_text.get("valid", true):
		push_error("Card with no text should be rejected")
		return false

	# Card with empty options
	var no_options_card: Dictionary = {
		"text": "Some narrative text here.",
		"options": [],
	}
	var result_no_opts: Dictionary = cs._validate_card(no_options_card)
	if result_no_opts.get("valid", true):
		push_error("Card with empty options should be rejected")
		return false

	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 5. SYSTEM INSTANTIATION CHAIN
# ═══════════════════════════════════════════════════════════════════════════════

func test_core_systems_instantiation() -> bool:
	# Verify all core RefCounted systems can be created
	var effect_engine: MerlinEffectEngine = MerlinEffectEngine.new()
	if effect_engine == null:
		push_error("MerlinEffectEngine instantiation failed")
		return false

	var save_system: MerlinSaveSystem = MerlinSaveSystem.new()
	if save_system == null:
		push_error("MerlinSaveSystem instantiation failed")
		return false

	var card_system: MerlinCardSystem = MerlinCardSystem.new()
	if card_system == null:
		push_error("MerlinCardSystem instantiation failed")
		return false

	# Verify constants class is accessible
	var ogham_count: int = MerlinConstants.OGHAM_FULL_SPECS.size()
	if ogham_count == 0:
		push_error("MerlinConstants.OGHAM_FULL_SPECS not accessible")
		return false

	return true


func test_error_handler_health_monitor_wiring() -> bool:
	var handler: ErrorHandler = ErrorHandler.new()
	handler._ready()
	var monitor: HealthMonitor = HealthMonitor.new()
	monitor._ready()

	# Wire them together
	monitor.initialize(handler)

	# Report an error and poll
	handler.report("card_system", ErrorHandler.Severity.WARNING, "Test warning")
	monitor.poll()

	# Verify monitor tracked the system
	var statuses: Dictionary = monitor._statuses
	if not statuses.has("card_system"):
		push_error("HealthMonitor did not track card_system after poll")
		handler.clear()
		handler.clear_persisted_log()
		handler.free()
		monitor.free()
		return false

	handler.clear()
	handler.clear_persisted_log()
	handler.free()
	monitor.free()
	return true


func test_accessibility_system_round_trip() -> bool:
	var a11y: AccessibilitySystem = AccessibilitySystem.new()

	# Set non-default values
	a11y.set_colorblind_mode(AccessibilitySystem.ColorblindMode.DEUTERANOPIA)
	a11y.set_text_scale(1.5)
	a11y.set_high_contrast(true)
	a11y.set_reduced_motion(true)
	a11y.set_hint("test_key", "test_value")

	# Serialize
	var data: Dictionary = a11y.to_dict()
	if data.is_empty():
		push_error("AccessibilitySystem.to_dict() returned empty")
		a11y.free()
		return false

	# Create new instance and restore
	var restored: AccessibilitySystem = AccessibilitySystem.new()
	restored.from_dict(data)

	# Verify round-trip
	if restored.get_colorblind_mode() != AccessibilitySystem.ColorblindMode.DEUTERANOPIA:
		push_error("Colorblind mode not restored: expected %d, got %d" % [
			AccessibilitySystem.ColorblindMode.DEUTERANOPIA, restored.get_colorblind_mode()])
		a11y.free()
		restored.free()
		return false

	if not is_equal_approx(restored.get_text_scale(), 1.5):
		push_error("Text scale not restored: expected 1.5, got %f" % restored.get_text_scale())
		a11y.free()
		restored.free()
		return false

	if not restored.is_high_contrast():
		push_error("High contrast not restored")
		a11y.free()
		restored.free()
		return false

	if not restored.is_reduced_motion():
		push_error("Reduced motion not restored")
		a11y.free()
		restored.free()
		return false

	if restored.get_hint("test_key") != "test_value":
		push_error("Screen reader hint not restored")
		a11y.free()
		restored.free()
		return false

	a11y.free()
	restored.free()
	return true
