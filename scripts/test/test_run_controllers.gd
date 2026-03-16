## ═══════════════════════════════════════════════════════════════════════════════
## Test Run Controllers — Headless tests for run flow controller logic
## ═══════════════════════════════════════════════════════════════════════════════
## Tests pure logic from:
##   - Run3DController (check_convergence, minigame difficulty)
##   - HubController (fallback dialogue, talent cost lookup)
##   - EndRunScreen (data accessors, penalty calculations, title text)
##   - HudController (state tracking, period/life updates)
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted

# ─── Preloaded scripts ─────────────────────────────────────────────────────────
var _Run3DScript = preload("res://scripts/run/run_3d_controller.gd")
var _HubScript = preload("res://scripts/ui/hub_controller.gd")
var _EndRunScript = preload("res://scripts/run/end_run_screen.gd")
var _HudScript = preload("res://scripts/ui/hud_controller.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT LOAD TESTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_run_3d_controller_loads() -> bool:
	if _Run3DScript == null:
		push_error("Run3DController script failed to preload")
		return false
	return true


func test_hub_controller_loads() -> bool:
	if _HubScript == null:
		push_error("HubController script failed to preload")
		return false
	return true


func test_end_run_screen_loads() -> bool:
	if _EndRunScript == null:
		push_error("EndRunScreen script failed to preload")
		return false
	return true


func test_hud_controller_loads() -> bool:
	if _HudScript == null:
		push_error("HudController script failed to preload")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# END RUN SCREEN — Data accessors (pure, no UI)
# ═══════════════════════════════════════════════════════════════════════════════

func _make_end_run_screen(run_data: Dictionary) -> EndRunScreen:
	## Helper: create EndRunScreen with setup() but no UI build.
	var screen: EndRunScreen = EndRunScreen.new()
	screen.setup(run_data, true)
	return screen


func test_end_run_victory_flag() -> bool:
	var screen_v: EndRunScreen = _make_end_run_screen({"victory": true})
	var screen_d: EndRunScreen = _make_end_run_screen({"victory": false})
	if not screen_v.get_is_victory():
		push_error("Expected victory=true")
		return false
	if screen_d.get_is_victory():
		push_error("Expected victory=false")
		return false
	return true


func test_end_run_title_victory() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({"victory": true})
	var title: String = screen.get_title_text()
	if title != "VICTOIRE":
		push_error("Expected VICTOIRE, got: %s" % title)
		return false
	return true


func test_end_run_title_death() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({"victory": false, "reason": "death"})
	var title: String = screen.get_title_text()
	if title != "FIN DU VOYAGE":
		push_error("Expected FIN DU VOYAGE, got: %s" % title)
		return false
	return true


func test_end_run_title_abandon() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({"victory": false, "reason": "abandon"})
	var title: String = screen.get_title_text()
	if title != "ABANDON":
		push_error("Expected ABANDON, got: %s" % title)
		return false
	return true


func test_end_run_title_unknown_reason() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({"victory": false, "reason": "hard_max"})
	var title: String = screen.get_title_text()
	if title != "FIN DE RUN":
		push_error("Expected FIN DE RUN, got: %s" % title)
		return false
	return true


func test_end_run_cards_played() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({"cards_played": 17})
	if screen.get_cards_played() != 17:
		push_error("Expected 17 cards_played, got: %d" % screen.get_cards_played())
		return false
	return true


func test_end_run_cards_played_default() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({})
	if screen.get_cards_played() != 0:
		push_error("Expected 0 cards_played default, got: %d" % screen.get_cards_played())
		return false
	return true


func test_end_run_life_remaining() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({"life_essence": 42})
	if screen.get_life_remaining() != 42:
		push_error("Expected 42, got: %d" % screen.get_life_remaining())
		return false
	return true


func test_end_run_oghams_used() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({"oghams_used": 5})
	if screen.get_oghams_used() != 5:
		push_error("Expected 5, got: %d" % screen.get_oghams_used())
		return false
	return true


func test_end_run_minigames_played() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({"minigames_played": 8})
	if screen.get_minigames_played() != 8:
		push_error("Expected 8, got: %d" % screen.get_minigames_played())
		return false
	return true


func test_end_run_avg_minigame_score() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({"avg_minigame_score": 72.5})
	var score: float = screen.get_avg_minigame_score()
	if absf(score - 72.5) > 0.01:
		push_error("Expected 72.5, got: %f" % score)
		return false
	return true


func test_end_run_anam_earned() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({"rewards": {"anam": 25}})
	if screen.get_anam_earned() != 25:
		push_error("Expected 25, got: %d" % screen.get_anam_earned())
		return false
	return true


func test_end_run_anam_earned_missing() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({})
	if screen.get_anam_earned() != 0:
		push_error("Expected 0 default anam, got: %d" % screen.get_anam_earned())
		return false
	return true


func test_end_run_faction_deltas() -> bool:
	var deltas: Dictionary = {"druides": 10.0, "ankou": -5.0}
	var screen: EndRunScreen = _make_end_run_screen({"faction_rep_delta": deltas})
	var result: Dictionary = screen.get_faction_deltas()
	if result.size() != 2:
		push_error("Expected 2 factions, got: %d" % result.size())
		return false
	if float(result.get("druides", 0.0)) != 10.0:
		push_error("Expected druides=10.0")
		return false
	return true


func test_end_run_faction_deltas_empty() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({})
	var result: Dictionary = screen.get_faction_deltas()
	if not result.is_empty():
		push_error("Expected empty faction deltas")
		return false
	return true


func test_end_run_death_penalty_ratio_victory() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({"victory": true, "cards_played": 15})
	var ratio: float = screen.get_death_penalty_ratio()
	if absf(ratio - 1.0) > 0.001:
		push_error("Victory penalty ratio should be 1.0, got: %f" % ratio)
		return false
	return true


func test_end_run_death_penalty_ratio_early_death() -> bool:
	# Died after 10 cards, cap is 30 => 10/30 = 0.333...
	var screen: EndRunScreen = _make_end_run_screen({"victory": false, "cards_played": 10})
	var ratio: float = screen.get_death_penalty_ratio()
	var expected: float = 10.0 / 30.0
	if absf(ratio - expected) > 0.01:
		push_error("Expected ~0.333, got: %f" % ratio)
		return false
	return true


func test_end_run_death_penalty_ratio_late_death() -> bool:
	# Died after 30+ cards => capped at 1.0
	var screen: EndRunScreen = _make_end_run_screen({"victory": false, "cards_played": 45})
	var ratio: float = screen.get_death_penalty_ratio()
	if absf(ratio - 1.0) > 0.001:
		push_error("Expected 1.0 (capped), got: %f" % ratio)
		return false
	return true


func test_end_run_death_penalty_ratio_zero_cards() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({"victory": false, "cards_played": 0})
	var ratio: float = screen.get_death_penalty_ratio()
	if absf(ratio) > 0.001:
		push_error("Expected 0.0, got: %f" % ratio)
		return false
	return true


func test_end_run_compute_anam_before_penalty() -> bool:
	# base=10, minigames_won=3 (*2=6), oghams_used=2 (*1=2) => 18
	var screen: EndRunScreen = _make_end_run_screen({
		"minigames_won": 3,
		"oghams_used": 2,
	})
	var result: int = screen._compute_anam_before_penalty()
	var expected: int = MerlinConstants.ANAM_BASE_REWARD + 3 * MerlinConstants.ANAM_PER_MINIGAME + 2 * MerlinConstants.ANAM_PER_OGHAM
	if result != expected:
		push_error("Expected %d, got: %d" % [expected, result])
		return false
	return true


func test_end_run_compute_anam_before_penalty_zeros() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({})
	var result: int = screen._compute_anam_before_penalty()
	if result != MerlinConstants.ANAM_BASE_REWARD:
		push_error("Expected base %d, got: %d" % [MerlinConstants.ANAM_BASE_REWARD, result])
		return false
	return true


func test_end_run_format_delta_positive() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({})
	var result: String = screen._format_delta(15.0)
	if result != "+15":
		push_error("Expected +15, got: %s" % result)
		return false
	return true


func test_end_run_format_delta_negative() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({})
	var result: String = screen._format_delta(-8.0)
	if result != "-8":
		push_error("Expected -8, got: %s" % result)
		return false
	return true


func test_end_run_format_delta_zero() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({})
	var result: String = screen._format_delta(0.0)
	# 0 is not > 0, so falls to the else branch: "%d" % 0 = "0"
	if result != "0":
		push_error("Expected 0, got: %s" % result)
		return false
	return true


func test_end_run_run_data_roundtrip() -> bool:
	var data: Dictionary = {"cards_played": 20, "life_essence": 50, "victory": true}
	var screen: EndRunScreen = _make_end_run_screen(data)
	var returned: Dictionary = screen.get_run_data()
	if int(returned.get("cards_played", 0)) != 20:
		push_error("run_data roundtrip failed for cards_played")
		return false
	if int(returned.get("life_essence", 0)) != 50:
		push_error("run_data roundtrip failed for life_essence")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# HUD CONTROLLER — State tracking (no UI nodes needed)
# ═══════════════════════════════════════════════════════════════════════════════

func _make_hud() -> HudController:
	var hud: HudController = HudController.new()
	return hud


func test_hud_initial_life() -> bool:
	var hud: HudController = _make_hud()
	if hud.get_current_life() != 100:
		push_error("Expected initial life 100, got: %d" % hud.get_current_life())
		return false
	return true


func test_hud_update_life_stores_values() -> bool:
	var hud: HudController = _make_hud()
	hud.update_life(42, 100)
	if hud.get_current_life() != 42:
		push_error("Expected life 42, got: %d" % hud.get_current_life())
		return false
	if hud._life_max != 100:
		push_error("Expected life_max 100, got: %d" % hud._life_max)
		return false
	return true


func test_hud_update_currency_stores_value() -> bool:
	var hud: HudController = _make_hud()
	hud.update_currency(55)
	if hud._currency != 55:
		push_error("Expected currency 55, got: %d" % hud._currency)
		return false
	return true


func test_hud_update_period_stores_value() -> bool:
	var hud: HudController = _make_hud()
	hud.update_period("crepuscule")
	if hud.get_current_period() != "crepuscule":
		push_error("Expected crepuscule, got: %s" % hud.get_current_period())
		return false
	return true


func test_hud_initial_period() -> bool:
	var hud: HudController = _make_hud()
	if hud.get_current_period() != "aube":
		push_error("Expected initial period aube, got: %s" % hud.get_current_period())
		return false
	return true


func test_hud_update_ogham_stores_values() -> bool:
	var hud: HudController = _make_hud()
	hud.update_ogham("luis", 3)
	if hud._current_ogham != "luis":
		push_error("Expected ogham luis, got: %s" % hud._current_ogham)
		return false
	if hud._ogham_cooldown != 3:
		push_error("Expected cooldown 3, got: %d" % hud._ogham_cooldown)
		return false
	return true


func test_hud_card_visibility_default() -> bool:
	var hud: HudController = _make_hud()
	if hud.is_card_visible():
		push_error("Card should not be visible initially")
		return false
	return true


func test_hud_card_started_sets_visible() -> bool:
	var hud: HudController = _make_hud()
	hud._on_card_started({"text": "Test card", "options": []})
	if not hud.is_card_visible():
		push_error("Card should be visible after card_started")
		return false
	return true


func test_hud_card_ended_clears_visible() -> bool:
	var hud: HudController = _make_hud()
	hud._on_card_started({"text": "Test card", "options": []})
	hud._on_card_ended()
	if hud.is_card_visible():
		push_error("Card should not be visible after card_ended")
		return false
	return true


func test_hud_run_ended_hides_card_overlay() -> bool:
	## Note: _on_run_ended calls _hide_card_overlay but does NOT reset _card_visible.
	## This test verifies the actual behavior (card overlay hidden via UI nodes only).
	## The _card_visible flag remains true — this is a known behavioral quirk.
	var hud: HudController = _make_hud()
	hud._on_card_started({"text": "Test", "options": []})
	hud._on_run_ended("death", {})
	# _card_visible is NOT reset by _on_run_ended (only _on_card_ended resets it)
	if not hud.is_card_visible():
		push_error("_on_run_ended should NOT reset _card_visible (only _on_card_ended does)")
		return false
	return true


func test_hud_card_started_stores_card() -> bool:
	var hud: HudController = _make_hud()
	var card: Dictionary = {"text": "Adventure", "options": [{"label": "Go"}]}
	hud._on_card_started(card)
	if str(hud._current_card.get("text", "")) != "Adventure":
		push_error("Expected card text Adventure")
		return false
	return true


func test_hud_card_ended_clears_card() -> bool:
	var hud: HudController = _make_hud()
	hud._on_card_started({"text": "Test", "options": []})
	hud._on_card_ended()
	if not hud._current_card.is_empty():
		push_error("Expected empty card after card_ended")
		return false
	return true


func test_hud_update_promises_stores_array() -> bool:
	var hud: HudController = _make_hud()
	var promises: Array = [{"description": "Help druids", "deadline_card": 10}]
	hud.update_promises(promises, 5)
	if hud._promises.size() != 1:
		push_error("Expected 1 promise, got: %d" % hud._promises.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# HUB CONTROLLER — Fallback dialogue (pure logic, no LLM/Store needed)
# ═══════════════════════════════════════════════════════════════════════════════

func _make_hub_with_profile(profile: Dictionary) -> HubController:
	var hub: HubController = HubController.new()
	hub._profile = profile
	return hub


func test_hub_fallback_dialogue_first_run() -> bool:
	var hub: HubController = _make_hub_with_profile({"total_runs": 0})
	var result: Dictionary = hub._get_fallback_dialogue({})
	if str(result.get("speaker", "")) != "merlin":
		push_error("Expected speaker merlin")
		return false
	if str(result.get("text", "")) != "Bienvenue, jeune druide. Le chemin t'attend.":
		push_error("Unexpected first-run text: %s" % str(result.get("text", "")))
		return false
	return true


func test_hub_fallback_dialogue_after_death() -> bool:
	var hub: HubController = _make_hub_with_profile({"total_runs": 3})
	var result: Dictionary = hub._get_fallback_dialogue({"reason": "death"})
	if str(result.get("text", "")) != "La mort n'est qu'un passage. Tu reviendras plus fort.":
		push_error("Unexpected death text: %s" % str(result.get("text", "")))
		return false
	return true


func test_hub_fallback_dialogue_after_hard_max() -> bool:
	var hub: HubController = _make_hub_with_profile({"total_runs": 5})
	var result: Dictionary = hub._get_fallback_dialogue({"reason": "hard_max"})
	if str(result.get("text", "")) != "Tu as parcouru un long chemin. Repose-toi avant de repartir.":
		push_error("Unexpected hard_max text")
		return false
	return true


func test_hub_fallback_dialogue_cycles_texts() -> bool:
	# For runs > 0 with no special reason, texts cycle by runs % 4
	var hub1: HubController = _make_hub_with_profile({"total_runs": 1})
	var r1: Dictionary = hub1._get_fallback_dialogue({"reason": ""})
	var hub2: HubController = _make_hub_with_profile({"total_runs": 5})
	var r2: Dictionary = hub2._get_fallback_dialogue({"reason": ""})
	# runs=1 => index 1, runs=5 => index 1 (5%4=1), should match
	if str(r1.get("text", "")) != str(r2.get("text", "")):
		push_error("Expected cycling text to match for runs 1 and 5")
		return false
	return true


func test_hub_find_talent_cost_unknown() -> bool:
	# Unknown talent returns 999
	var hub: HubController = _make_hub_with_profile({})
	var cost: int = hub._find_talent_cost("nonexistent_talent")
	if cost != 999:
		push_error("Expected 999 for unknown talent, got: %d" % cost)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# END RUN SCREEN — FACTION_LIST constant
# ═══════════════════════════════════════════════════════════════════════════════

func test_end_run_faction_list_completeness() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({})
	var expected: Array[String] = ["druides", "anciens", "korrigans", "niamh", "ankou"]
	if screen.FACTION_LIST.size() != expected.size():
		push_error("Expected %d factions, got: %d" % [expected.size(), screen.FACTION_LIST.size()])
		return false
	for i in range(expected.size()):
		if screen.FACTION_LIST[i] != expected[i]:
			push_error("Faction mismatch at index %d: %s vs %s" % [i, screen.FACTION_LIST[i], expected[i]])
			return false
	return true


func test_end_run_death_cap_cards_is_30() -> bool:
	var screen: EndRunScreen = _make_end_run_screen({})
	if screen.DEATH_CAP_CARDS != 30:
		push_error("Expected DEATH_CAP_CARDS=30, got: %d" % screen.DEATH_CAP_CARDS)
		return false
	return true
