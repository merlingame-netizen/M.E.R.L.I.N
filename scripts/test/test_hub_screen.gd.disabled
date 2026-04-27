## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — HubScreen + FactionRepBar
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: data binding, biome unlock display, ogham selection max 3,
## signal emission, faction bars, edge cases.
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# TEST DATA FACTORIES
# ═══════════════════════════════════════════════════════════════════════════════

func _make_hub_data() -> Dictionary:
	return {
		"player_name": "Gwydion",
		"anam": 42,
		"total_runs": 5,
		"maturity_score": 30,
		"faction_rep": {
			"druides": 55.0,
			"anciens": 20.0,
			"korrigans": 80.0,
			"niamh": 10.0,
			"ankou": 0.0,
		},
		"unlocked_oghams": ["beith", "luis", "quert", "duir", "tinne"],
		"selected_oghams": ["beith"],
		"biomes": [
			{"id": "foret_broceliande", "name": "Foret de Broceliande", "threshold": 0},
			{"id": "landes_bruyere", "name": "Landes de Bruyere", "threshold": 15},
			{"id": "cotes_sauvages", "name": "Cotes Sauvages", "threshold": 15},
		],
		"locked_biomes": [
			{"id": "villages_celtes", "name": "Villages Celtes", "threshold": 25},
			{"id": "cercles_pierres", "name": "Cercles de Pierres", "threshold": 30},
			{"id": "iles_mystiques", "name": "Iles Mystiques", "threshold": 75},
		],
	}


func _make_empty_data() -> Dictionary:
	return {
		"player_name": "",
		"anam": 0,
		"total_runs": 0,
		"maturity_score": 0,
		"faction_rep": {},
		"unlocked_oghams": [],
		"selected_oghams": [],
		"biomes": [],
		"locked_biomes": [],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 1: Header data binding
# ═══════════════════════════════════════════════════════════════════════════════

func test_header_data_binding() -> bool:
	var screen: HubScreen = HubScreen.new()
	var data: Dictionary = _make_hub_data()
	screen.setup(data)

	if screen._player_name != "Gwydion":
		push_error("Expected player name 'Gwydion', got '%s'" % screen._player_name)
		return false
	if screen._anam != 42:
		push_error("Expected anam 42, got %d" % screen._anam)
		return false
	if screen._total_runs != 5:
		push_error("Expected 5 runs, got %d" % screen._total_runs)
		return false
	if screen._maturity_score != 30:
		push_error("Expected maturity 30, got %d" % screen._maturity_score)
		return false

	screen.free()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 2: Faction reputation binding
# ═══════════════════════════════════════════════════════════════════════════════

func test_faction_rep_binding() -> bool:
	var screen: HubScreen = HubScreen.new()
	var data: Dictionary = _make_hub_data()
	screen.setup(data)

	var rep: Dictionary = screen._faction_rep
	if abs(float(rep.get("druides", 0)) - 55.0) > 0.01:
		push_error("Expected druides rep 55.0, got %f" % float(rep.get("druides", 0)))
		return false
	if abs(float(rep.get("korrigans", 0)) - 80.0) > 0.01:
		push_error("Expected korrigans rep 80.0, got %f" % float(rep.get("korrigans", 0)))
		return false
	if abs(float(rep.get("ankou", 0)) - 0.0) > 0.01:
		push_error("Expected ankou rep 0.0, got %f" % float(rep.get("ankou", 0)))
		return false

	screen.free()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 3: Biome unlock display (available vs locked)
# ═══════════════════════════════════════════════════════════════════════════════

func test_biome_unlock_display() -> bool:
	var screen: HubScreen = HubScreen.new()
	var data: Dictionary = _make_hub_data()
	screen.setup(data)

	if screen._biomes_data.size() != 3:
		push_error("Expected 3 available biomes, got %d" % screen._biomes_data.size())
		return false
	if screen._locked_biomes.size() != 3:
		push_error("Expected 3 locked biomes, got %d" % screen._locked_biomes.size())
		return false

	# Check locked biome detection
	if not screen._is_biome_locked("iles_mystiques"):
		push_error("iles_mystiques should be locked")
		return false
	if screen._is_biome_locked("foret_broceliande"):
		push_error("foret_broceliande should NOT be locked")
		return false

	screen.free()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 4: Biome selection
# ═══════════════════════════════════════════════════════════════════════════════

func test_biome_selection() -> bool:
	var screen: HubScreen = HubScreen.new()
	var data: Dictionary = _make_hub_data()
	screen.setup(data)

	# Default selection = first available
	if screen.get_selected_biome() != "foret_broceliande":
		push_error("Expected default biome 'foret_broceliande', got '%s'" % screen.get_selected_biome())
		return false

	# Select another available biome
	screen.select_biome("landes_bruyere")
	if screen.get_selected_biome() != "landes_bruyere":
		push_error("Expected 'landes_bruyere' after selection, got '%s'" % screen.get_selected_biome())
		return false

	# Attempt to select a locked biome — should be rejected
	screen.select_biome("iles_mystiques")
	if screen.get_selected_biome() != "landes_bruyere":
		push_error("Locked biome selection should be rejected")
		return false

	screen.free()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 5: Ogham selection max 3
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_selection_max_three() -> bool:
	var screen: HubScreen = HubScreen.new()
	var data: Dictionary = _make_hub_data()
	data["selected_oghams"] = []
	screen.setup(data)

	# Select 3 oghams
	var result1: bool = screen.toggle_ogham("beith")
	var result2: bool = screen.toggle_ogham("luis")
	var result3: bool = screen.toggle_ogham("quert")

	if not result1 or not result2 or not result3:
		push_error("First 3 ogham selections should succeed")
		return false

	if screen.get_ogham_count() != 3:
		push_error("Expected 3 oghams selected, got %d" % screen.get_ogham_count())
		return false

	# Attempt 4th selection — should fail
	var result4: bool = screen.toggle_ogham("duir")
	if result4:
		push_error("4th ogham selection should be rejected (max 3)")
		return false

	if screen.get_ogham_count() != 3:
		push_error("Count should still be 3 after rejected 4th, got %d" % screen.get_ogham_count())
		return false

	screen.free()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 6: Ogham toggle deselect
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_toggle_deselect() -> bool:
	var screen: HubScreen = HubScreen.new()
	var data: Dictionary = _make_hub_data()
	data["selected_oghams"] = ["beith", "luis"]
	screen.setup(data)

	if screen.get_ogham_count() != 2:
		push_error("Expected 2 initial oghams, got %d" % screen.get_ogham_count())
		return false

	# Deselect one
	var result: bool = screen.toggle_ogham("beith")
	if not result:
		push_error("Deselection should succeed")
		return false

	if screen.get_ogham_count() != 1:
		push_error("Expected 1 ogham after deselect, got %d" % screen.get_ogham_count())
		return false

	if screen.is_ogham_selected("beith"):
		push_error("beith should no longer be selected")
		return false

	screen.free()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 7: Ogham selection — unlocked only
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_unlocked_only() -> bool:
	var screen: HubScreen = HubScreen.new()
	var data: Dictionary = _make_hub_data()
	data["selected_oghams"] = []
	screen.setup(data)

	# Try selecting an ogham that is NOT in unlocked_oghams
	var result: bool = screen.toggle_ogham("ioho")
	if result:
		push_error("Selecting a locked ogham should fail")
		return false

	if screen.get_ogham_count() != 0:
		push_error("No ogham should be selected")
		return false

	screen.free()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 8: Can start run validation
# ═══════════════════════════════════════════════════════════════════════════════

func test_can_start_run() -> bool:
	var screen: HubScreen = HubScreen.new()

	# Empty data — no biome, no oghams
	var empty: Dictionary = _make_empty_data()
	screen.setup(empty)

	if screen.can_start_run():
		push_error("Should not be able to start run with no biome or oghams")
		return false

	# Valid data
	var data: Dictionary = _make_hub_data()
	screen.setup(data)

	if not screen.can_start_run():
		push_error("Should be able to start run with biome and ogham selected")
		return false

	screen.free()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 9: Signal emission — run_requested
# ═══════════════════════════════════════════════════════════════════════════════

func test_run_requested_signal() -> bool:
	var screen: HubScreen = HubScreen.new()
	var data: Dictionary = _make_hub_data()
	screen.setup(data)

	var signal_received: Array = [false]
	var signal_biome: Array = [""]
	var signal_oghams: Array = [[]]

	screen.run_requested.connect(func(biome_id: String, oghams: Array) -> void:
		signal_received[0] = true
		signal_biome[0] = biome_id
		signal_oghams[0] = oghams
	)

	screen._on_start_pressed()

	if not signal_received[0]:
		push_error("run_requested signal should have been emitted")
		return false

	if signal_biome[0] != "foret_broceliande":
		push_error("Expected biome 'foret_broceliande', got '%s'" % signal_biome[0])
		return false

	if signal_oghams[0].size() != 1 or signal_oghams[0][0] != "beith":
		push_error("Expected oghams ['beith'], got %s" % str(signal_oghams[0]))
		return false

	screen.free()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 10: Signal emission — talent_tree_requested
# ═══════════════════════════════════════════════════════════════════════════════

func test_talent_tree_signal() -> bool:
	var screen: HubScreen = HubScreen.new()
	var data: Dictionary = _make_hub_data()
	screen.setup(data)

	var received: Array = [false]
	screen.talent_tree_requested.connect(func() -> void:
		received[0] = true
	)

	screen._on_talent_pressed()

	if not received[0]:
		push_error("talent_tree_requested signal should have been emitted")
		return false

	screen.free()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 11: Signal emission — quit_requested
# ═══════════════════════════════════════════════════════════════════════════════

func test_quit_signal() -> bool:
	var screen: HubScreen = HubScreen.new()
	var data: Dictionary = _make_hub_data()
	screen.setup(data)

	var received: Array = [false]
	screen.quit_requested.connect(func() -> void:
		received[0] = true
	)

	screen._on_quit_pressed()

	if not received[0]:
		push_error("quit_requested signal should have been emitted")
		return false

	screen.free()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 12: FactionRepBar — update and value
# ═══════════════════════════════════════════════════════════════════════════════

func test_faction_bar_update() -> bool:
	var bar: FactionRepBar = FactionRepBar.new()
	bar.update("druides", 55.0)

	if bar.get_faction_id() != "druides":
		push_error("Expected faction_id 'druides', got '%s'" % bar.get_faction_id())
		return false
	if abs(bar.get_value() - 55.0) > 0.01:
		push_error("Expected value 55.0, got %f" % bar.get_value())
		return false
	if bar.get_tier() != "Sympathisant":
		push_error("Expected tier 'Sympathisant' for 55, got '%s'" % bar.get_tier())
		return false

	bar.free()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 13: FactionRepBar — tier thresholds
# ═══════════════════════════════════════════════════════════════════════════════

func test_faction_bar_tiers() -> bool:
	var bar: FactionRepBar = FactionRepBar.new()

	bar.update("ankou", 0.0)
	if bar.get_tier() != "Hostile":
		push_error("Expected 'Hostile' for 0, got '%s'" % bar.get_tier())
		return false

	bar.update("ankou", 5.0)
	if bar.get_tier() != "Mefiant":
		push_error("Expected 'Mefiant' for 5, got '%s'" % bar.get_tier())
		return false

	bar.update("ankou", 20.0)
	if bar.get_tier() != "Neutre":
		push_error("Expected 'Neutre' for 20, got '%s'" % bar.get_tier())
		return false

	bar.update("ankou", 50.0)
	if bar.get_tier() != "Sympathisant":
		push_error("Expected 'Sympathisant' for 50, got '%s'" % bar.get_tier())
		return false

	bar.update("ankou", 80.0)
	if bar.get_tier() != "Honore":
		push_error("Expected 'Honore' for 80, got '%s'" % bar.get_tier())
		return false

	bar.free()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 14: FactionRepBar — value clamping
# ═══════════════════════════════════════════════════════════════════════════════

func test_faction_bar_clamping() -> bool:
	var bar: FactionRepBar = FactionRepBar.new()

	bar.update("niamh", -20.0)
	if abs(bar.get_value() - 0.0) > 0.01:
		push_error("Negative value should clamp to 0, got %f" % bar.get_value())
		return false

	bar.update("niamh", 150.0)
	if abs(bar.get_value() - 100.0) > 0.01:
		push_error("Value > 100 should clamp to 100, got %f" % bar.get_value())
		return false

	bar.free()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 15: Ogham selection overflow trim on setup
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_overflow_trim() -> bool:
	var screen: HubScreen = HubScreen.new()
	var data: Dictionary = _make_hub_data()
	data["selected_oghams"] = ["beith", "luis", "quert", "duir", "tinne"]
	screen.setup(data)

	if screen.get_ogham_count() != 3:
		push_error("Overflow oghams should be trimmed to 3, got %d" % screen.get_ogham_count())
		return false

	screen.free()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUNNER
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> Dictionary:
	var tests: Array = [
		"test_header_data_binding",
		"test_faction_rep_binding",
		"test_biome_unlock_display",
		"test_biome_selection",
		"test_ogham_selection_max_three",
		"test_ogham_toggle_deselect",
		"test_ogham_unlocked_only",
		"test_can_start_run",
		"test_run_requested_signal",
		"test_talent_tree_signal",
		"test_quit_signal",
		"test_faction_bar_update",
		"test_faction_bar_tiers",
		"test_faction_bar_clamping",
		"test_ogham_overflow_trim",
	]

	var passed: int = 0
	var failed: int = 0
	var results: Array = []

	for test_name in tests:
		var ok: bool = call(test_name)
		if ok:
			passed += 1
			results.append({"name": test_name, "status": "PASS"})
		else:
			failed += 1
			results.append({"name": test_name, "status": "FAIL"})

	return {
		"total": tests.size(),
		"passed": passed,
		"failed": failed,
		"results": results,
	}
