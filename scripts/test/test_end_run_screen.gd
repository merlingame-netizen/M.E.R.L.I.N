## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — EndRunScreen + JourneyMapDisplay
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: data binding, death vs victory display, anam penalty display,
## signal emission, journey map entries, faction delta formatting.
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# TEST DATA FACTORIES
# ═══════════════════════════════════════════════════════════════════════════════

func _make_victory_data() -> Dictionary:
	return {
		"victory": true,
		"reason": "mission_complete",
		"cards_played": 22,
		"life_essence": 45,
		"life_max": 100,
		"biome": "broceliande",
		"biome_currency": 38,
		"oghams_used": 3,
		"minigames_played": 18,
		"minigames_won": 12,
		"avg_minigame_score": 72.5,
		"faction_rep_delta": {
			"druides": 15.0,
			"anciens": -5.0,
			"korrigans": 0.0,
			"niamh": 8.0,
			"ankou": 0.0,
		},
		"story_log": [
			{"text": "Un druide vous accueille", "choice": "Saluer", "card_idx": 1},
			{"text": "La foret murmure", "choice": "Ecouter", "card_idx": 2},
		],
		"rewards": {"anam": 35, "victory": true, "cards_played": 22, "minigames_won": 12, "oghams_used": 3},
	}


func _make_death_data() -> Dictionary:
	return {
		"victory": false,
		"reason": "death",
		"cards_played": 10,
		"life_essence": 0,
		"life_max": 100,
		"biome": "broceliande",
		"biome_currency": 12,
		"oghams_used": 1,
		"minigames_played": 8,
		"minigames_won": 4,
		"avg_minigame_score": 55.0,
		"faction_rep_delta": {
			"druides": 5.0,
			"anciens": 0.0,
			"korrigans": -3.0,
			"niamh": 0.0,
			"ankou": 10.0,
		},
		"story_log": [
			{"text": "Un sentier sombre", "choice": "Avancer", "card_idx": 1},
		],
		"rewards": {"anam": 8, "victory": false, "cards_played": 10, "minigames_won": 4, "oghams_used": 1},
	}


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 1: Victory data binding
# ═══════════════════════════════════════════════════════════════════════════════

func test_victory_data_binding() -> bool:
	var screen: EndRunScreen = EndRunScreen.new()
	var data: Dictionary = _make_victory_data()
	screen.setup(data, true)

	if not screen.get_is_victory():
		push_error("Victory: expected is_victory=true")
		return false
	if screen.get_cards_played() != 22:
		push_error("Victory: expected cards_played=22, got %d" % screen.get_cards_played())
		return false
	if screen.get_life_remaining() != 45:
		push_error("Victory: expected life=45, got %d" % screen.get_life_remaining())
		return false
	if screen.get_oghams_used() != 3:
		push_error("Victory: expected oghams_used=3, got %d" % screen.get_oghams_used())
		return false
	if screen.get_anam_earned() != 35:
		push_error("Victory: expected anam=35, got %d" % screen.get_anam_earned())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 2: Death data binding
# ═══════════════════════════════════════════════════════════════════════════════

func test_death_data_binding() -> bool:
	var screen: EndRunScreen = EndRunScreen.new()
	var data: Dictionary = _make_death_data()
	screen.setup(data, true)

	if screen.get_is_victory():
		push_error("Death: expected is_victory=false")
		return false
	if screen.get_life_remaining() != 0:
		push_error("Death: expected life=0, got %d" % screen.get_life_remaining())
		return false
	if screen.get_cards_played() != 10:
		push_error("Death: expected cards_played=10, got %d" % screen.get_cards_played())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 3: Death vs victory title text
# ═══════════════════════════════════════════════════════════════════════════════

func test_title_text_victory_vs_death() -> bool:
	var victory_screen: EndRunScreen = EndRunScreen.new()
	victory_screen.setup(_make_victory_data(), true)
	var victory_title: String = victory_screen.get_title_text()
	if victory_title != "VICTOIRE":
		push_error("Title victory: expected 'VICTOIRE', got '%s'" % victory_title)
		return false

	var death_screen: EndRunScreen = EndRunScreen.new()
	death_screen.setup(_make_death_data(), true)
	var death_title: String = death_screen.get_title_text()
	if death_title != "FIN DU VOYAGE":
		push_error("Title death: expected 'FIN DU VOYAGE', got '%s'" % death_title)
		return false

	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 4: Anam death penalty ratio
# ═══════════════════════════════════════════════════════════════════════════════

func test_anam_death_penalty_ratio() -> bool:
	# Victory: ratio should be 1.0 (no penalty)
	var victory_screen: EndRunScreen = EndRunScreen.new()
	victory_screen.setup(_make_victory_data(), true)
	var victory_ratio: float = victory_screen.get_death_penalty_ratio()
	if absf(victory_ratio - 1.0) > 0.01:
		push_error("Penalty ratio victory: expected 1.0, got %.2f" % victory_ratio)
		return false

	# Death with 10 cards: ratio = 10/30 = 0.333
	var death_screen: EndRunScreen = EndRunScreen.new()
	death_screen.setup(_make_death_data(), true)
	var death_ratio: float = death_screen.get_death_penalty_ratio()
	var expected_ratio: float = 10.0 / 30.0
	if absf(death_ratio - expected_ratio) > 0.02:
		push_error("Penalty ratio death: expected %.3f, got %.3f" % [expected_ratio, death_ratio])
		return false

	# Death with 30+ cards: ratio capped at 1.0
	var capped_data: Dictionary = _make_death_data()
	capped_data["cards_played"] = 40
	var capped_screen: EndRunScreen = EndRunScreen.new()
	capped_screen.setup(capped_data, true)
	var capped_ratio: float = capped_screen.get_death_penalty_ratio()
	if absf(capped_ratio - 1.0) > 0.01:
		push_error("Penalty ratio capped: expected 1.0, got %.2f" % capped_ratio)
		return false

	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 5: Signal emission (hub_requested)
# ═══════════════════════════════════════════════════════════════════════════════

func test_hub_requested_signal() -> bool:
	var screen: EndRunScreen = EndRunScreen.new()
	screen.setup(_make_victory_data(), true)

	var signal_received: Array = [false]
	screen.hub_requested.connect(func() -> void: signal_received[0] = true)

	# Simulate button press
	screen._on_continue_pressed()

	if not signal_received[0]:
		push_error("hub_requested signal was not emitted")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 6: Faction deltas accessor
# ═══════════════════════════════════════════════════════════════════════════════

func test_faction_deltas() -> bool:
	var screen: EndRunScreen = EndRunScreen.new()
	var data: Dictionary = _make_victory_data()
	screen.setup(data, true)

	var deltas: Dictionary = screen.get_faction_deltas()
	if deltas.is_empty():
		push_error("Faction deltas should not be empty")
		return false
	if absf(float(deltas.get("druides", 0.0)) - 15.0) > 0.01:
		push_error("Faction delta druides: expected 15.0, got %.1f" % float(deltas.get("druides", 0.0)))
		return false
	if absf(float(deltas.get("anciens", 0.0)) - (-5.0)) > 0.01:
		push_error("Faction delta anciens: expected -5.0, got %.1f" % float(deltas.get("anciens", 0.0)))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 7: Minigame stats accessor
# ═══════════════════════════════════════════════════════════════════════════════

func test_minigame_stats() -> bool:
	var screen: EndRunScreen = EndRunScreen.new()
	screen.setup(_make_victory_data(), true)

	if screen.get_minigames_played() != 18:
		push_error("Minigames played: expected 18, got %d" % screen.get_minigames_played())
		return false
	if absf(screen.get_avg_minigame_score() - 72.5) > 0.1:
		push_error("Avg score: expected 72.5, got %.1f" % screen.get_avg_minigame_score())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 8: JourneyMapDisplay entry count
# ═══════════════════════════════════════════════════════════════════════════════

func test_journey_map_entry_count() -> bool:
	var journey: JourneyMapDisplay = JourneyMapDisplay.new()
	var log: Array = [
		{"text": "Carte 1", "choice": "A", "card_idx": 1},
		{"text": "Carte 2", "choice": "B", "card_idx": 2},
		{"text": "Carte 3", "choice": "C", "card_idx": 3},
	]
	journey.setup(log, true, true)

	if journey.get_entry_count() != 3:
		push_error("Journey map: expected 3 entries, got %d" % journey.get_entry_count())
		return false
	if not journey.get_is_victory():
		push_error("Journey map: expected is_victory=true")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 9: JourneyMapDisplay scrolling with many entries
# ═══════════════════════════════════════════════════════════════════════════════

func test_journey_map_scroll_overflow() -> bool:
	var journey: JourneyMapDisplay = JourneyMapDisplay.new()
	var log: Array = []
	for i in 20:
		log.append({"text": "Carte %d" % (i + 1), "choice": "X", "card_idx": i + 1})
	journey.setup(log, false, true)

	if journey.get_entry_count() != 20:
		push_error("Journey scroll: expected 20 total entries, got %d" % journey.get_entry_count())
		return false

	var visible: Array = journey.get_visible_entries()
	if visible.size() != JourneyMapDisplay.MAX_VISIBLE_NODES:
		push_error("Journey scroll: expected %d visible, got %d" % [JourneyMapDisplay.MAX_VISIBLE_NODES, visible.size()])
		return false

	# Last visible entry should be the last entry overall
	var last_visible: Dictionary = visible[visible.size() - 1]
	if int(last_visible.get("card_idx", 0)) != 20:
		push_error("Journey scroll: last visible should be card_idx=20, got %d" % int(last_visible.get("card_idx", 0)))
		return false

	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 10: JourneyMapDisplay empty log
# ═══════════════════════════════════════════════════════════════════════════════

func test_journey_map_empty() -> bool:
	var journey: JourneyMapDisplay = JourneyMapDisplay.new()
	journey.setup([], false, true)

	if journey.get_entry_count() != 0:
		push_error("Journey empty: expected 0 entries, got %d" % journey.get_entry_count())
		return false

	var visible: Array = journey.get_visible_entries()
	if not visible.is_empty():
		push_error("Journey empty: visible should be empty")
		return false

	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 11: Abandon reason title
# ═══════════════════════════════════════════════════════════════════════════════

func test_abandon_title() -> bool:
	var screen: EndRunScreen = EndRunScreen.new()
	var data: Dictionary = _make_death_data()
	data["reason"] = "abandon"
	screen.setup(data, true)

	var title: String = screen.get_title_text()
	if title != "ABANDON":
		push_error("Abandon title: expected 'ABANDON', got '%s'" % title)
		return false
	return true
